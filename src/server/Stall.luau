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

-- ============================================================================
-- WAVE 2b: Roblox-bound wiring (start, handlers, sweeper, applyToSeller,
-- requestRentFeatured, ProximityPrompt routing).
--
-- Lazy-required modules (declared here to avoid cyclic requires at module load).
-- ============================================================================

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.Server.PlayerData)
local PendingMutations = require(ServerScriptService.Server.PendingMutations)
local PlotAnchors = require(ServerScriptService.Server.PlotAnchors)
local RateLimit = require(ServerScriptService.Server.RateLimit)

-- ---------- Server-memory state -------------------------------------------

-- Featured row allocation. { occupiedSlots = { [slotIndex] = { userId, expiresAt } } }.
-- Server-memory only — lost on restart (acceptable v1; rental fee is small,
-- crashes are rare). Slot stays occupied by userId for the full 24h rental
-- regardless of seller's online/offline state.
Stall.featuredRowState = { occupiedSlots = {} }

local started = false

-- ---------- Audit helper --------------------------------------------------

local function audit(kind: string, payload: table)
	Exchange.writeAudit(Exchange.buildAuditEntry(kind, payload))
end

-- ---------- applyToSeller (D-19 routing) ----------------------------------

-- Routes a sellerMutation to the right destination per online/offline branch.
-- Online: PlayerData.update directly. Offline: PendingMutations.write.
function Stall.applyToSeller(sellerUserId: number, mutation: table): (boolean, string)
	if type(sellerUserId) ~= "number" or type(mutation) ~= "table" then
		return false, "INVALID_REQUEST"
	end
	local sellerPlayer = Players:GetPlayerByUserId(sellerUserId)
	if sellerPlayer then
		-- ONLINE: apply directly
		local sellerData = PlayerData.get(sellerPlayer)
		if not sellerData then
			-- profile mid-load; queue instead
			PendingMutations.write(sellerUserId, mutation)
			return true, "OK"
		end
		PlayerData.update(sellerPlayer, function(d)
			-- Reuse the drain logic for one-mutation list (keeps per-kind
			-- dispatch in one place).
			PendingMutations.drain(d, { mutation })
		end)
		-- Push MailboxUpdated to seller so their UI refreshes
		Remotes.get(Constants.REMOTES.MailboxUpdated):FireClient(sellerPlayer, sellerData.stalls.mailbox)
		return true, "OK"
	else
		-- OFFLINE: queue for next login
		local ok = PendingMutations.write(sellerUserId, mutation)
		return ok, ok and "OK" or "PENDING_WRITE_FAILED"
	end
end

-- ---------- Featured row helpers (server-memory) --------------------------

-- Find the Workspace stall stand Part for a given slot index. Returns nil
-- if not built yet (Studio Play before MapSetup runs, or hand-built world
-- without the standard naming).
local function findFeaturedStandByIndex(slotIndex: number): BasePart?
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("featuredSlotIndex") == slotIndex then
			return descendant
		end
	end
	return nil
end

-- Mirror in-memory featuredRowState onto the Workspace Part: set/clear the
-- stallSellerUserId attribute + enable/disable the StallPrompt accordingly.
-- Called on rent (userId set) and expiry (userId nil).
local function setFeaturedStandOccupant(slotIndex: number, userId: number?)
	local stand = findFeaturedStandByIndex(slotIndex)
	if not stand then return end
	stand:SetAttribute("stallSellerUserId", userId)  -- nil clears the attribute
	local prompt = stand:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = userId ~= nil
	end
end

-- Sweep expired entries from featuredRowState.occupiedSlots + clear the
-- corresponding Workspace stand's attribute + disable its prompt.
local function sweepFeaturedRow(now: number)
	for slotIndex, entry in pairs(Stall.featuredRowState.occupiedSlots) do
		if entry.expiresAt and now > entry.expiresAt then
			Stall.featuredRowState.occupiedSlots[slotIndex] = nil
			setFeaturedStandOccupant(slotIndex, nil)
		end
	end
end

-- Build the featuredRowState snapshot used by canRentFeatured.
-- Returns { occupiedSlots = { [slotIndex] = userId } } (just userId, not the entry table).
local function featuredRowSnapshot(): table
	local snap = { occupiedSlots = {} }
	for slotIndex, entry in pairs(Stall.featuredRowState.occupiedSlots) do
		snap.occupiedSlots[slotIndex] = entry.userId
	end
	return snap
end

-- ---------- requestRentFeatured (B-6 lock — public for dialogue) ---------

function Stall.requestRentFeatured(player: Player): (boolean, string)
	if not player or not player.Parent then return false, "INVALID_REQUEST" end
	local data = PlayerData.get(player)
	if not data then return false, "INVALID_REQUEST" end

	local now = os.time()
	sweepFeaturedRow(now)
	local rowSnap = featuredRowSnapshot()
	local ok, code, slotIndex = Stall.canRentFeatured(data, rowSnap, now, player.UserId)
	if not ok then
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = code, action = "rent_featured",
		})
		return false, code
	end

	-- Atomic: deduct coins + set featuredRentExpiresAt
	local expiresAt = now + Constants.STALL.featuredRentSeconds
	PlayerData.update(player, function(d)
		d.coins = (d.coins or 0) - Constants.STALL.featuredFee
		d.stalls.featuredRentExpiresAt = expiresAt
	end)

	-- Claim slot in server-memory featuredRowState + mirror to the Workspace Part
	-- (sets stallSellerUserId attribute + enables StallPrompt so buyers can interact).
	Stall.featuredRowState.occupiedSlots[slotIndex] = {
		userId    = player.UserId,
		expiresAt = expiresAt,
	}
	setFeaturedStandOccupant(slotIndex, player.UserId)

	audit("stall_featured_rented", {
		sellerUserId = player.UserId,
		slotIndex    = slotIndex,
		fee          = Constants.STALL.featuredFee,
		expiresAt    = expiresAt,
	})

	Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
		success = true, code = "OK", action = "rent_featured", slotIndex = slotIndex,
	})
	return true, "OK"
end

-- ---------- 6 remote handlers --------------------------------------------

local function rateLimited(player, remoteName, action): boolean
	local interval = Constants.STALL.rateLimits[remoteName]
	if not RateLimit.check(player, remoteName, interval or 1) then
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = "RATE_LIMITED", action = action,
		})
		return true
	end
	return false
end

local function handleCreateListing(player: Player, payload)
	if rateLimited(player, "CreateListing", "create") then return end
	if type(payload) ~= "table" then return end

	local data = PlayerData.get(player)
	if not data then return end

	local listing = {
		itemId    = payload.itemId,
		qty       = payload.qty,
		unitPrice = payload.unitPrice,
	}
	local ok, code = Stall.canCreateListing(data, listing)
	if not ok then
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = code, action = "create",
		})
		return
	end

	local listingId = Stall.newListingId()
	local now = os.time()
	local expiresAt = now + Constants.STALL.listingExpirySeconds
	local newListing = {
		itemId    = listing.itemId,
		qty       = listing.qty,
		unitPrice = listing.unitPrice,
		listedAt  = now,
		expiresAt = expiresAt,
		featured  = (data.stalls.featuredRentExpiresAt or 0) > now,
	}

	-- Atomic: escrow items out of inventory, write listing
	PlayerData.update(player, function(d)
		Exchange.applyOneSided(d, { coins = 0, items = { [listing.itemId] = listing.qty } }, { coins = 0, items = {} })
		d.stalls.listings[listingId] = newListing
	end)

	audit("stall_create", {
		listingId    = listingId,
		sellerUserId = player.UserId,
		itemId       = listing.itemId,
		qty          = listing.qty,
		unitPrice    = listing.unitPrice,
		expiresAt    = expiresAt,
	})

	Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
		success = true, code = "OK", action = "create", listingId = listingId,
	})
end

local function handleCancelListing(player: Player, listingId)
	if rateLimited(player, "CancelListing", "cancel") then return end
	if type(listingId) ~= "string" then return end

	local data = PlayerData.get(player)
	if not data then return end

	local ok, code = Stall.canCancelListing(data, listingId, player.UserId)
	if not ok then
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = code, action = "cancel",
		})
		return
	end

	local overflowItems
	PlayerData.update(player, function(d)
		local _, _, overflow = Stall.cancelListing(d, listingId, player.UserId)
		overflowItems = overflow
	end)

	if overflowItems then
		audit("mailbox_overflow", {
			sellerUserId = player.UserId,
			items        = overflowItems,
			reason       = "cancel",
		})
	end
	audit("stall_cancel", {
		listingId    = listingId,
		sellerUserId = player.UserId,
	})

	Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
		success = true, code = "OK", action = "cancel", listingId = listingId,
	})
end

local function handleBuyListing(player: Player, sellerUserId, listingId, qty)
	if rateLimited(player, "BuyListing", "buy") then return end
	if type(sellerUserId) ~= "number" or type(listingId) ~= "string" then return end

	local buyerData = PlayerData.get(player)
	if not buyerData then return end

	-- Fetch seller data: online via PlayerData.get; offline via PendingMutations.peek
	-- isn't enough — we need their current listings. For v1, only ONLINE sellers
	-- can be bought from directly via this remote. Offline seller buys would
	-- require reading their profile from DataStore, which is out of scope for v1.
	-- (Featured directory only shows online sellers per the v1 simplification.)
	local sellerPlayer = Players:GetPlayerByUserId(sellerUserId)
	if not sellerPlayer then
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = "LISTING_GONE", action = "buy",
		})
		return
	end
	local sellerData = PlayerData.get(sellerPlayer)
	if not sellerData then
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = "LISTING_GONE", action = "buy",
		})
		return
	end

	local listing = sellerData.stalls and sellerData.stalls.listings and sellerData.stalls.listings[listingId]
	if not listing then
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = "LISTING_GONE", action = "buy",
		})
		return
	end

	-- Atomic: snapshot buyer → mutate buyer → applyToSeller → on failure restore
	local snap = Exchange.snapshotData(buyerData)
	local buyOk, buyCode, sellerMutation
	PlayerData.update(player, function(d)
		buyOk, buyCode, sellerMutation = Stall.executeBuy(
			d, sellerData, listingId, qty or listing.qty,
			player.UserId, sellerUserId, player.Name
		)
	end)

	if not buyOk then
		PlayerData.update(player, function(d)
			Exchange.restoreFromSnapshot(d, snap)
		end)
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = buyCode, action = "buy",
		})
		return
	end

	-- Apply seller side. For online sellers this is direct PlayerData.update
	-- (and the listing gets removed in PendingMutations.drain dispatch for stall_sale).
	local applyOk = Stall.applyToSeller(sellerUserId, sellerMutation)
	if not applyOk then
		-- Rare: queue write failed and seller is offline. Restore buyer.
		PlayerData.update(player, function(d)
			Exchange.restoreFromSnapshot(d, snap)
		end)
		Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
			success = false, code = "MUTATION_FAILED", action = "buy",
		})
		return
	end

	audit("stall_purchase", {
		listingId    = listingId,
		sellerUserId = sellerUserId,
		buyerUserId  = player.UserId,
		buyerName    = player.Name,
		itemId       = listing.itemId,
		qty          = sellerMutation.qty,
		coinsEarned  = sellerMutation.coinsEarned,
	})

	Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
		success = true, code = "OK", action = "buy",
		listingId = listingId, itemId = listing.itemId, qty = sellerMutation.qty,
	})
end

local function handleRentFeaturedSlot(player: Player)
	if rateLimited(player, "RentFeaturedSlot", "rent_featured") then return end
	Stall.requestRentFeatured(player)
end

local function handleClaimMailbox(player: Player)
	if rateLimited(player, "ClaimMailbox", "claim_mailbox") then return end

	local data = PlayerData.get(player)
	if not data then return end

	local claimedCoins, claimedItems
	PlayerData.update(player, function(d)
		claimedCoins, claimedItems = Stall.claimMailbox(d)
	end)

	audit("stall_mailbox_claim", {
		userId = player.UserId,
		coins  = claimedCoins,
		items  = claimedItems,
	})

	Remotes.get(Constants.REMOTES.MailboxUpdated):FireClient(player, data.stalls.mailbox)
end

local function handleBrowseDirectory(player: Player)
	if rateLimited(player, "BrowseDirectory", "browse") then return end

	local now = os.time()
	sweepFeaturedRow(now)

	-- v1: directory shows ONLINE sellers whose featured rental is active.
	local registry = {}
	for slotIndex, entry in pairs(Stall.featuredRowState.occupiedSlots) do
		local sellerPlayer = Players:GetPlayerByUserId(entry.userId)
		if sellerPlayer then
			local sellerData = PlayerData.get(sellerPlayer)
			if sellerData and sellerData.stalls then
				local listingCount = 0
				for _ in pairs(sellerData.stalls.listings or {}) do listingCount += 1 end
				local plotPosition = sellerData.stalls.plotAnchorId
					and PlotAnchors.tileIdToPosition(sellerData.stalls.plotAnchorId)
					or nil
				table.insert(registry, {
					sellerUserId = entry.userId,
					sellerName   = sellerPlayer.Name,
					listingCount = listingCount,
					plotPosition = plotPosition,
				})
			end
		end
	end

	local rows = Stall.browseDirectory(registry)
	-- Fire BrowseDirectory back to caller as the response
	Remotes.get(Constants.REMOTES.BrowseDirectory):FireClient(player, rows)
end

-- ---------- ProximityPrompt routing ---------------------------------------

local function handlePromptTriggered(prompt: ProximityPrompt, player: Player)
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then return end
	-- Defer to other systems if their attribute is set on the same Part
	if part:GetAttribute("merchantId") then return end
	if part:GetAttribute("dialogueId") then return end

	local sellerUserId = part:GetAttribute("stallSellerUserId")
	if not sellerUserId or type(sellerUserId) ~= "number" then return end

	-- Owner check: if player IS the seller, open Owner UI; else Buyer UI
	if player.UserId == sellerUserId then
		Remotes.get(Constants.REMOTES.OpenStallOwnerUI):FireClient(player, { tab = "listings" })
	else
		local sellerPlayer = Players:GetPlayerByUserId(sellerUserId)
		if not sellerPlayer then
			Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
				success = false, code = "LISTING_GONE", action = "buy",
			})
			return
		end
		local sellerData = PlayerData.get(sellerPlayer)
		Remotes.get(Constants.REMOTES.OpenStallBuyerUI):FireClient(player, {
			sellerUserId = sellerUserId,
			sellerName   = sellerPlayer.Name,
			listings     = sellerData and sellerData.stalls and sellerData.stalls.listings or {},
		})
	end
end

-- ---------- Sweeper task --------------------------------------------------

-- v1: only sweeps ONLINE players. Offline sellers self-sweep on next login
-- via the hook in PlayerData.onPlayerAdded (Wave 2b adds that step).
local function sweepOnlinePlayers(now: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local data = PlayerData.get(player)
		if data and data.stalls then
			-- Listing expiry
			local expired = Stall.expirySweep(data, now)
			if #expired > 0 then
				PlayerData.update(player, function(d)
					for _, listingId in ipairs(expired) do
						local _, _, overflow = Stall.cancelListing(d, listingId, player.UserId)
						if overflow then
							audit("mailbox_overflow", {
								sellerUserId = player.UserId,
								items        = overflow,
								reason       = "expire",
							})
						end
						audit("stall_expire", {
							listingId    = listingId,
							sellerUserId = player.UserId,
						})
					end
				end)
			end
			-- Featured expiry (server-memory + per-player data both reset)
			if data.stalls.featuredRentExpiresAt and now > data.stalls.featuredRentExpiresAt then
				PlayerData.update(player, function(d)
					d.stalls.featuredRentExpiresAt = nil
				end)
			end
		end
	end
	sweepFeaturedRow(now)
end

-- ---------- start() -------------------------------------------------------

function Stall.start()
	if started then return end
	started = true

	Remotes.get(Constants.REMOTES.CreateListing).OnServerEvent:Connect(handleCreateListing)
	Remotes.get(Constants.REMOTES.CancelListing).OnServerEvent:Connect(handleCancelListing)
	Remotes.get(Constants.REMOTES.BuyListing).OnServerEvent:Connect(handleBuyListing)
	Remotes.get(Constants.REMOTES.RentFeaturedSlot).OnServerEvent:Connect(handleRentFeaturedSlot)
	Remotes.get(Constants.REMOTES.ClaimMailbox).OnServerEvent:Connect(handleClaimMailbox)
	Remotes.get(Constants.REMOTES.BrowseDirectory).OnServerEvent:Connect(handleBrowseDirectory)

	ProximityPromptService.PromptTriggered:Connect(handlePromptTriggered)

	-- Sweeper task: every Constants.STALL.expirySweeperIntervalSeconds (60s).
	task.spawn(function()
		while true do
			task.wait(Constants.STALL.expirySweeperIntervalSeconds)
			local ok, err = pcall(sweepOnlinePlayers, os.time())
			if not ok then warn("[Stall] sweeper error: " .. tostring(err)) end
		end
	end)

	print("[Stall] start() complete — 6 handlers + ProximityPrompt + sweeper wired")
end

-- ---------- Self-sweep on player join (called by PlayerData.onPlayerAdded) -

-- Process any expired listings + expired featured rental in the player's
-- profile data. Called BEFORE the PlayerDataUpdated client push so the
-- client's first frame sees the cleaned state. Pure on the data table; no
-- remotes fire from here.
function Stall.selfSweepOnLoad(data, now: number)
	if not data or not data.stalls then return end
	now = now or os.time()
	local expired = Stall.expirySweep(data, now)
	for _, listingId in ipairs(expired) do
		Stall.cancelListing(data, listingId, nil)  -- nil callerUserId skips owner check
		-- We don't audit here (no Player to attribute); audit happens only
		-- when the sweeper or a handler runs. Acceptable for v1.
	end
	if data.stalls.featuredRentExpiresAt and now > data.stalls.featuredRentExpiresAt then
		data.stalls.featuredRentExpiresAt = nil
	end
end

return Stall
