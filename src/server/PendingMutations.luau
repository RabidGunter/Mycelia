-- Offline-seller mutation queue per D-19.
--
-- When a buyer purchases from an offline seller, the server writes a
-- mutation record to a separate DataStore keyed on userId. When the seller
-- next loads their Profile, PlayerData.onPlayerAdded calls
-- PendingMutations.drain BEFORE any other startup hook. The queue entry is
-- atomically deleted on successful drain.
--
-- Mutation record schema:
--   { kind = "stall_sale" | "expiry_clear_featured" | "expiry_listing_to_mailbox",
--     listingId?, coinsEarned?, soldAt?, buyerName?, itemId?, qty?,
--     snapshotMicroseconds = math.floor(os.clock() * 1e6) }  -- for ordering during drain
--
-- Multiple mutations per seller are stored as an array under the seller's
-- userId key (read-modify-append-write pattern via UpdateAsync; idempotent
-- merges across concurrent server writes).
--
-- Wave 2b owns the Roblox-bound PlayerData.onPlayerAdded drain hook + the
-- "online vs offline" branching helper Stall.applyToSeller. This module
-- exposes write/peek/drain/_reset; drain is the testable pure helper.
--
-- Spec: docs/specs/player-stalls.md (resolved follow-up via D-19).
-- Plan: 02-CONTEXT.md (D-19).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Exchange = require(ServerScriptService.Server.Exchange)
local Inventory = require(ServerScriptService.Server.Inventory)
local Constants = require(ReplicatedStorage.Shared.Constants)

local PendingMutations = {}

-- ---------- DataStore (lazy init) -----------------------------------------

local PENDING_STORE_NAME = "MyceliaStallPendingMutations_v1"
local pendingStore = nil
do
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, PENDING_STORE_NAME)
	if ok then pendingStore = store end
end

-- In-memory cache for tests + warm reads. Tests use _reset() to clear.
local cache: { [number]: { table } } = {}

-- ---------- Roblox-bound: write -------------------------------------------

-- Append a mutation record to the seller's queue. Uses UpdateAsync for the
-- read-modify-append-write pattern so concurrent writes from different
-- servers don't lose entries. pcall-wrapped — returns false on DataStore
-- failure, true on success or when running outside Studio API access (in
-- which case we cache in-memory only and warn).
function PendingMutations.write(sellerUserId: number, mutation: table): boolean
	if type(sellerUserId) ~= "number" then return false end
	if type(mutation) ~= "table" then return false end
	if type(mutation.kind) ~= "string" then return false end
	mutation.snapshotMicroseconds = mutation.snapshotMicroseconds or math.floor(os.clock() * 1e6)

	-- Cache in memory regardless (peek + drain can use it).
	cache[sellerUserId] = cache[sellerUserId] or {}
	table.insert(cache[sellerUserId], mutation)

	if not pendingStore then
		warn(string.format(
			"[PendingMutations] DataStore unavailable; mutation cached in memory only (sellerUserId=%d, kind=%s)",
			sellerUserId, mutation.kind
		))
		return true
	end

	local key = tostring(sellerUserId)
	local ok = pcall(function()
		pendingStore:UpdateAsync(key, function(existing)
			existing = (type(existing) == "table") and existing or {}
			table.insert(existing, mutation)
			return existing
		end)
	end)
	return ok
end

-- ---------- Test seam: peek the in-memory cache ---------------------------

function PendingMutations.peek(sellerUserId: number): { table }?
	return cache[sellerUserId]
end

-- ---------- Pure helper: drain --------------------------------------------

-- Apply each pending mutation to a loaded `data.stalls`. Pure: takes a list
-- of mutations + a data table; mutates in place. Sorts by snapshotMicroseconds
-- ascending so the earliest mutations apply first.
--
-- Returns: (appliedCount, errors). errors is a list of "i: msg" strings for
-- mutations that failed individually (drained + skipped); the rest still apply.
function PendingMutations.drain(data, mutations): (number, { string })
	if type(data) ~= "table" then return 0, { "drain: data must be a table" } end
	if not data.stalls then return 0, { "drain: data.stalls is nil" } end
	if type(mutations) ~= "table" then return 0, { "drain: mutations must be a table" } end

	-- Sort ascending by snapshotMicroseconds (defaulting to 0 for missing field)
	local sorted = {}
	for i, m in ipairs(mutations) do sorted[i] = m end
	table.sort(sorted, function(a, b)
		return (a.snapshotMicroseconds or 0) < (b.snapshotMicroseconds or 0)
	end)

	local applied = 0
	local errors: { string } = {}

	for i, mutation in ipairs(sorted) do
		local ok, err = pcall(function()
			local kind = mutation.kind
			if kind == "stall_sale" then
				-- Add coins to mailbox; record the sale entry; keep listing removal
				-- as the seller's mutation (caller responsibility decided in Wave 2b).
				data.stalls.mailbox = data.stalls.mailbox or { coins = 0, items = {}, sales = {} }
				data.stalls.mailbox.coins = (data.stalls.mailbox.coins or 0) + (mutation.coinsEarned or 0)
				-- Recent sale entry (newest-first prepend, trim to 50)
				data.stalls.mailbox.sales = data.stalls.mailbox.sales or {}
				table.insert(data.stalls.mailbox.sales, 1, {
					listingId   = mutation.listingId,
					soldAt      = mutation.soldAt,
					buyerName   = mutation.buyerName,
					itemId      = mutation.itemId,
					qty         = mutation.qty,
					coinsEarned = mutation.coinsEarned,
				})
				while #data.stalls.mailbox.sales > 50 do table.remove(data.stalls.mailbox.sales) end
				-- Remove the listing from seller's stalls (they won't have it once
				-- they next load — the buyer already claimed it server-side).
				if mutation.listingId and data.stalls.listings then
					data.stalls.listings[mutation.listingId] = nil
				end

			elseif kind == "expiry_clear_featured" then
				data.stalls.featuredRentExpiresAt = nil

			elseif kind == "expiry_listing_to_mailbox" then
				if mutation.listingId and data.stalls.listings then
					local listing = data.stalls.listings[mutation.listingId]
					if listing then
						-- Add items to mailbox via inline cap-respecting logic.
						-- We don't require Stall here (avoids circular require);
						-- instead inline the simple add-items-to-mailbox routine.
						data.stalls.mailbox = data.stalls.mailbox or { coins = 0, items = {}, sales = {} }
						local mailbox = data.stalls.mailbox
						mailbox.items = mailbox.items or {}
						local itemId = listing.itemId
						local qty = listing.qty
						if mailbox.items[itemId] then
							mailbox.items[itemId] = mailbox.items[itemId] + qty
						else
							-- Cap check (D-11)
							local count = 0
							for _ in pairs(mailbox.items) do count += 1 end
							if count >= Constants.STALL.mailboxItemIdCap then
								-- Overflow — note it; items go to audit when caller sees this
								local prev = mailbox.overflowNotice
								mailbox.overflowNotice = {
									count = ((prev and prev.count) or 0) + 1,
									since = os.time(),
								}
							else
								mailbox.items[itemId] = qty
							end
						end
						data.stalls.listings[mutation.listingId] = nil
					end
				end

			else
				error("unknown mutation kind: " .. tostring(kind))
			end
		end)

		if ok then
			applied += 1
		else
			table.insert(errors, string.format("%d: %s", i, tostring(err)))
		end
	end

	return applied, errors
end

-- ---------- Test-only: clear in-memory cache ------------------------------

function PendingMutations._reset()
	cache = {}
end

return PendingMutations
