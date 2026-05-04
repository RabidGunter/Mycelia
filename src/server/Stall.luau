-- Player Stalls backend — pure helpers (Wave 2a).
--
-- This module is split across two waves:
--   - Wave 2a (THIS file): pure helpers that operate on plain `data` tables.
--     No PlayerData, no remotes, no ProximityPrompt, no DataStore. Tested by
--     StallSpec.luau via TestKit.
--   - Wave 2b: Stall.start() + 6 remote handlers + sweeper task + offline-
--     mutation routing through PendingMutations + ProximityPromptService
--     listener. Lands in a follow-up commit.
--
-- Spec: docs/specs/player-stalls.md.
-- Plan / locked decisions: .planning/phases/02-closed-beta-social-systems-content/02-CONTEXT.md.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Inventory = require(ServerScriptService.Server.Inventory)
local Exchange = require(ServerScriptService.Server.Exchange)

local Stall = {}

-- ---------- Audit kind taxonomy (W-9 — locked) -----------------------------
-- Exactly 7 values. Wave 2b's handlers + sweeper write audit entries with
-- one of these kinds via Exchange.writeAudit(Exchange.buildAuditEntry(kind, payload)).
Stall.AUDIT_KINDS = {
	"stall_purchase",
	"stall_create",
	"stall_cancel",
	"stall_expire",
	"mailbox_overflow",
	"stall_featured_rented",
	"stall_mailbox_claim",
}

-- ---------- Listing id generation (CD-1) -----------------------------------

function Stall.newListingId(): string
	return HttpService:GenerateGUID(false)
end

-- ---------- Internal helpers -----------------------------------------------

-- Count active listings on a `data` table. Defensive against missing fields.
local function listingCount(data): number
	local n = 0
	if data and data.stalls and type(data.stalls.listings) == "table" then
		for _ in pairs(data.stalls.listings) do n += 1 end
	end
	return n
end

-- Count unique item ids in a player's mailbox.items.
local function mailboxIdCount(data): number
	local n = 0
	if data and data.stalls and data.stalls.mailbox and type(data.stalls.mailbox.items) == "table" then
		for _ in pairs(data.stalls.mailbox.items) do n += 1 end
	end
	return n
end

-- True if the player's inventory holds at least `qty` of `itemId`. Mirrors
-- Trade.hasItem's logic but without the tradable check (Stall does that
-- separately to provide a more granular error code).
local function hasInInventory(data, itemId, qty): boolean
	if Species.byId[itemId] then
		return Inventory.count(data.inventory or {}, itemId) >= qty
	end
	local def = Constants.ITEMS[itemId]
	if not def then return false end
	local bucket = data.inventoryByCategory and data.inventoryByCategory[def.category]
	if type(bucket) ~= "table" then return false end
	return (bucket[itemId] or 0) >= qty
end

-- Atomically add items to mailbox; returns (overflowItems table | nil).
-- Per D-20: silent fallback. If adding would exceed the 100-id cap AND the
-- item isn't already in mailbox, the items are returned as overflow (the
-- caller writes them to audit log via writeAudit({ kind = "mailbox_overflow", ... })).
-- Sets data.stalls.mailbox.overflowNotice on overflow.
local function addToMailbox(data, items): { [string]: number }?
	local mailbox = data.stalls.mailbox
	mailbox.items = mailbox.items or {}
	local overflow: { [string]: number } = {}
	local hasOverflow = false

	for itemId, qty in pairs(items) do
		if mailbox.items[itemId] then
			-- Already in mailbox — merge regardless of cap (no new id consumed)
			mailbox.items[itemId] = mailbox.items[itemId] + qty
		else
			-- New id; check cap
			local current = mailboxIdCount(data)
			if current >= Constants.STALL.mailboxItemIdCap then
				overflow[itemId] = qty
				hasOverflow = true
			else
				mailbox.items[itemId] = qty
			end
		end
	end

	if hasOverflow then
		local prev = mailbox.overflowNotice
		local prevCount = (prev and prev.count) or 0
		local addedCount = 0
		for _ in pairs(overflow) do addedCount += 1 end
		mailbox.overflowNotice = { count = prevCount + addedCount, since = os.time() }
		return overflow
	end
	return nil
end

-- ---------- Validation: createListing (D-15) -------------------------------

function Stall.canCreateListing(data, listing): (boolean, string)
	if type(listing) ~= "table" then return false, "INVALID_REQUEST" end
	local itemId = listing.itemId
	local qty = listing.qty
	local unitPrice = listing.unitPrice

	if type(itemId) ~= "string" or itemId == "" then return false, "INVALID_REQUEST" end
	if type(qty) ~= "number" or qty <= 0 or qty ~= math.floor(qty) then
		return false, "INVALID_REQUEST"
	end
	if type(unitPrice) ~= "number"
		or unitPrice < Constants.STALL.minPrice
		or unitPrice > Constants.STALL.maxPrice
		or unitPrice ~= math.floor(unitPrice) then
		return false, "INVALID_PRICE"
	end

	-- Slot cap
	if listingCount(data) >= Constants.STALL.slotCount then
		return false, "SLOT_FULL"
	end

	-- Tradability — mushroom species are always tradable; non-mushroom
	-- items must have Constants.ITEMS[id].tradable ~= false.
	if not Species.byId[itemId] then
		local def = Constants.ITEMS[itemId]
		if not def then return false, "INVALID_REQUEST" end
		if def.tradable == false then return false, "ITEM_NOT_TRADABLE" end
	end

	-- Inventory
	if not hasInInventory(data, itemId, qty) then
		return false, "INSUFFICIENT_INVENTORY"
	end

	return true, "OK"
end

-- ---------- Validation: cancelListing --------------------------------------

function Stall.canCancelListing(data, listingId, callerUserId): (boolean, string)
	if type(listingId) ~= "string" then return false, "INVALID_REQUEST" end
	if not data or not data.stalls or not data.stalls.listings then
		return false, "LISTING_GONE"
	end
	local listing = data.stalls.listings[listingId]
	if not listing then return false, "LISTING_GONE" end
	-- Owner check is the caller's responsibility — this helper takes a caller
	-- userId only so the public API matches the rest of the family. We accept
	-- a nil callerUserId to skip the check (PLAN 02b's handler always passes one).
	if callerUserId ~= nil and listing.ownerUserId and listing.ownerUserId ~= callerUserId then
		return false, "NOT_OWNER"
	end
	return true, "OK"
end

-- ---------- Validation: canBuy (W-8 — separate export) ---------------------

function Stall.canBuy(buyerUserId, sellerUserId, buyerData, listing): (boolean, string)
	if type(buyerUserId) ~= "number" or type(sellerUserId) ~= "number" then
		return false, "INVALID_REQUEST"
	end
	if buyerUserId == sellerUserId then return false, "SELF_PURCHASE" end
	if not listing or type(listing) ~= "table" then return false, "LISTING_GONE" end
	if not buyerData then return false, "INVALID_REQUEST" end
	local total = (listing.unitPrice or 0) * (listing.qty or 0)
	if (buyerData.coins or 0) < total then return false, "INSUFFICIENT_COINS" end
	return true, "OK"
end

-- ---------- Atomic buy (Wave 2a returns the sellerMutation; Wave 2b routes it) -

-- Mutates `buyerData` in place: subtracts coins, adds items via Exchange.
-- Returns (ok, code, sellerMutation). The `sellerMutation` is a record the
-- caller (Wave 2b) routes through Stall.applyToSeller — online via
-- PlayerData.update, offline via PendingMutations.write.
--
-- Mutation kind: "stall_sale" per D-19.
function Stall.executeBuy(buyerData, sellerData, listingId, qty, buyerUserId, sellerUserId, buyerName)
	if not buyerData or not sellerData then return false, "INVALID_REQUEST", nil end
	if not sellerData.stalls or not sellerData.stalls.listings then return false, "LISTING_GONE", nil end
	local listing = sellerData.stalls.listings[listingId]
	if not listing then return false, "LISTING_GONE", nil end

	local buyQty = qty or listing.qty
	if type(buyQty) ~= "number" or buyQty <= 0 or buyQty > listing.qty then
		return false, "INVALID_REQUEST", nil
	end

	local ok, code = Stall.canBuy(buyerUserId, sellerUserId, buyerData, {
		unitPrice = listing.unitPrice,
		qty = buyQty,
	})
	if not ok then return false, code, nil end

	local total = listing.unitPrice * buyQty

	-- Mutate buyer: subtract coins, add items.
	Exchange.applyOneSided(buyerData,
		{ coins = total, items = {} },
		{ coins = 0, items = { [listing.itemId] = buyQty } })

	-- Build seller mutation record (kind = "stall_sale" per D-19).
	local sellerMutation = {
		kind                  = "stall_sale",
		listingId             = listingId,
		coinsEarned           = total,
		soldAt                = os.time(),
		buyerName             = buyerName or "",
		buyerUserId           = buyerUserId,
		itemId                = listing.itemId,
		qty                   = buyQty,
		fullQty               = listing.qty,        -- caller decides whether to delete or decrement
		snapshotMicroseconds  = math.floor(os.clock() * 1e6),
	}

	return true, "OK", sellerMutation
end

-- ---------- Cancel listing (D-20: silent overflow) ------------------------

-- Mutates `data` in place: removes the listing, adds its items to mailbox.
-- On mailbox overflow per D-20, returns overflow items as the third value
-- (caller writes them to audit log via Exchange.writeAudit(kind="mailbox_overflow")).
function Stall.cancelListing(data, listingId, callerUserId): (boolean, string, { [string]: number }?)
	local ok, code = Stall.canCancelListing(data, listingId, callerUserId)
	if not ok then return false, code, nil end

	local listing = data.stalls.listings[listingId]
	local items = { [listing.itemId] = listing.qty }
	local overflow = addToMailbox(data, items)

	-- Remove listing regardless of overflow (D-20: cancel succeeds even on overflow)
	data.stalls.listings[listingId] = nil

	return true, "OK", overflow
end

-- ---------- Expiry sweepers (B-2: pure helpers; Wave 2b wires the loop) ---

-- Returns the list of expired listing ids from data.stalls.listings (where
-- now > expiresAt). Caller iterates and calls cancelListing-equivalent +
-- writeAudit({ kind = "stall_expire", ... }) per id.
function Stall.expirySweep(data, now): { string }
	local expired: { string } = {}
	if not data or not data.stalls or type(data.stalls.listings) ~= "table" then return expired end
	for listingId, listing in pairs(data.stalls.listings) do
		if listing.expiresAt and now > listing.expiresAt then
			table.insert(expired, listingId)
		end
	end
	return expired
end

-- Returns the list of seller userIds whose featured rental has expired.
-- registry shape: { [userId] = { featuredRentExpiresAt = number } }
function Stall.sweepFeaturedExpiry(registry, now): { number }
	local expired: { number } = {}
	if type(registry) ~= "table" then return expired end
	for userId, entry in pairs(registry) do
		if type(entry) == "table" and entry.featuredRentExpiresAt and now > entry.featuredRentExpiresAt then
			table.insert(expired, userId)
		end
	end
	return expired
end

-- ---------- Featured row rental (D-08, D-21) -------------------------------

-- featuredRowState shape:
--   { occupiedSlots = { [slotIndex] = userId }, [userId] = featuredRentExpiresAt }
-- Returns: (ok, code, slotIndex?). slotIndex is the lowest unoccupied 1..featuredSlotCount.
function Stall.canRentFeatured(callerData, featuredRowState, now, callerUserId): (boolean, string, number?)
	if not callerData then return false, "INVALID_REQUEST", nil end
	if (callerData.coins or 0) < Constants.STALL.featuredFee then
		return false, "INSUFFICIENT_COINS", nil
	end
	-- Already-featured check (D-08: 1 featured slot per account).
	local existingExpiry = callerData.stalls and callerData.stalls.featuredRentExpiresAt
	if existingExpiry and existingExpiry > now then
		return false, "ALREADY_FEATURED", nil
	end
	-- Find lowest unoccupied slot
	if type(featuredRowState) ~= "table" then featuredRowState = {} end
	local occupied = featuredRowState.occupiedSlots or {}
	for i = 1, Constants.STALL.featuredSlotCount do
		if not occupied[i] then return true, "OK", i end
	end
	return false, "FEATURED_FULL", nil
end

-- ---------- Mailbox claim (D-20: resets overflowNotice) -------------------

-- Atomically claim mailbox.coins + mailbox.items into data.coins + inventories.
-- Resets mailbox to { coins=0, items={}, sales preserved, overflowNotice=nil }.
-- Returns: (claimedCoins, claimedItems, ok). Caller wraps in PlayerData.update.
function Stall.claimMailbox(data): (number, { [string]: number }, boolean)
	if not data or not data.stalls or not data.stalls.mailbox then
		return 0, {}, false
	end
	local mailbox = data.stalls.mailbox
	local claimedCoins = mailbox.coins or 0
	local claimedItems: { [string]: number } = {}
	for k, v in pairs(mailbox.items or {}) do claimedItems[k] = v end

	-- Apply: route claimedItems through Exchange.applyOneSided so mushroom
	-- species → data.inventory and non-mushroom → inventoryByCategory.
	data.coins = (data.coins or 0) + claimedCoins
	Exchange.applyOneSided(data, { coins = 0, items = {} }, { coins = 0, items = claimedItems })

	-- Reset mailbox (sales feed preserved per D-20; overflowNotice cleared)
	mailbox.coins = 0
	mailbox.items = {}
	mailbox.overflowNotice = nil

	return claimedCoins, claimedItems, true
end

-- ---------- Recent-sales feed (trim to 50) ---------------------------------

function Stall.recordRecentSale(data, saleEntry)
	if not data or not data.stalls or not data.stalls.mailbox then return end
	data.stalls.mailbox.sales = data.stalls.mailbox.sales or {}
	local sales = data.stalls.mailbox.sales
	-- Prepend (newest first)
	table.insert(sales, 1, saleEntry)
	-- Trim to 50
	while #sales > 50 do
		table.remove(sales)
	end
end

-- ---------- Plot Directory (B-6: includes plotPosition) -------------------

-- featuredRegistry shape (built by Wave 2b):
--   { { sellerUserId, sellerName, listingCount, plotPosition: Vector3 }, ... }
-- This pure helper just passes through (defensive sort + filter).
-- Wave 2b's BrowseDirectory handler is what assembles the registry from
-- knownSellers + each seller's plot tile via PlotAnchors.tileIdToPosition.
function Stall.browseDirectory(featuredRegistry): { table }
	if type(featuredRegistry) ~= "table" then return {} end
	local rows = {}
	for _, entry in ipairs(featuredRegistry) do
		if type(entry) == "table" and entry.sellerUserId then
			table.insert(rows, {
				sellerUserId  = entry.sellerUserId,
				sellerName    = entry.sellerName or "",
				listingCount  = entry.listingCount or 0,
				plotPosition  = entry.plotPosition,
			})
		end
	end
	return rows
end

return Stall
