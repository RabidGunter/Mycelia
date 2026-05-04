-- Pure helpers shared between Trade.luau (refactored Phase 2) and Stall.luau
-- (new Phase 2). Atomic-execution + audit-log primitives extracted from
-- Trade.luau per docs/specs/player-stalls.md §16 (D-02).
--
-- The `kind` field on audit entries discriminates trade vs stall_purchase vs
-- future kinds (Phase 3 LiveOps event lottery, etc.). Pre-refactor audit
-- entries (Trade flows shipped 2026-05-03 before this extraction) lack `kind`;
-- treat absent kind as legacy = "trade" if a future read-side consumer needs
-- to disambiguate. No migration written — only forward-compat note.
--
-- Pure helpers operate on plain `data` tables (not Player references).
-- Roblox-bound `PlayerData.update` wrapping stays at the call sites in
-- Trade.luau and Stall.luau.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Inventory = require(ServerScriptService.Server.Inventory)

local Exchange = {}

-- ---------- Audit DataStore (lazy init) -----------------------------------

local AUDIT_STORE_NAME = "MyceliaAuditLog_v1"
local auditStore = nil
do
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, AUDIT_STORE_NAME)
	if ok then auditStore = store end
end

-- ---------- Pure helpers --------------------------------------------------

-- Capture a defensive deep copy of the trade-relevant subset of a `data`
-- table. Returns nil for nil input.
function Exchange.snapshotData(data)
	if data == nil then return nil end
	local snap = {
		coins = data.coins,
		inventory = {},
		inventoryByCategory = {},
	}
	for k, v in pairs(data.inventory or {}) do snap.inventory[k] = v end
	for cat, bucket in pairs(data.inventoryByCategory or {}) do
		snap.inventoryByCategory[cat] = {}
		for k, v in pairs(bucket) do snap.inventoryByCategory[cat][k] = v end
	end
	return snap
end

-- In-place restore of `data` from a previously-captured snapshot. Caller
-- wraps in PlayerData.update for replication + persistence. No-op when
-- snapshot is nil.
function Exchange.restoreFromSnapshot(data, snap)
	if snap == nil then return end
	data.coins = snap.coins
	data.inventory = {}
	for k, v in pairs(snap.inventory) do data.inventory[k] = v end
	data.inventoryByCategory = data.inventoryByCategory or {}
	-- Rebuild every category bucket fresh; categories absent from snap are dropped.
	for cat in pairs(data.inventoryByCategory) do
		if snap.inventoryByCategory[cat] == nil then
			data.inventoryByCategory[cat] = nil
		end
	end
	for cat, bucket in pairs(snap.inventoryByCategory) do
		data.inventoryByCategory[cat] = {}
		for k, v in pairs(bucket) do data.inventoryByCategory[cat][k] = v end
	end
end

-- One-sided atomic mutation: subtract `give` items + coins from `data`,
-- add `receive` items + coins. Routes mushroom species (Species.byId
-- membership) to legacy `data.inventory` and everything else (per
-- `Constants.ITEMS[id].category`) to `data.inventoryByCategory[category]`.
-- Pure; caller wraps in PlayerData.update.
--
-- give    = { coins = number, items = { [itemId] = qty } }
-- receive = { coins = number, items = { [itemId] = qty } }
function Exchange.applyOneSided(data, give, receive)
	give = give or { coins = 0, items = {} }
	receive = receive or { coins = 0, items = {} }

	-- Coins
	data.coins = (data.coins or 0) - (give.coins or 0) + (receive.coins or 0)

	-- Subtract `give` items.
	for itemId, qty in pairs(give.items or {}) do
		if Species.byId[itemId] then
			data.inventory = data.inventory or {}
			Inventory.remove(data.inventory, itemId, qty)
		else
			local def = Constants.ITEMS and Constants.ITEMS[itemId]
			if def and data.inventoryByCategory and data.inventoryByCategory[def.category] then
				local bucket = data.inventoryByCategory[def.category]
				bucket[itemId] = (bucket[itemId] or 0) - qty
				if bucket[itemId] <= 0 then bucket[itemId] = nil end
			end
		end
	end

	-- Add `receive` items.
	for itemId, qty in pairs(receive.items or {}) do
		if Species.byId[itemId] then
			data.inventory = data.inventory or {}
			Inventory.add(data.inventory, itemId, qty)
		else
			local def = Constants.ITEMS and Constants.ITEMS[itemId]
			if def then
				local cat = def.category
				data.inventoryByCategory = data.inventoryByCategory or {}
				data.inventoryByCategory[cat] = data.inventoryByCategory[cat] or {}
				local bucket = data.inventoryByCategory[cat]
				bucket[itemId] = (bucket[itemId] or 0) + qty
			end
		end
	end
end

-- Construct an audit entry table. The `kind` field is REQUIRED.
-- Returns: { kind = kind, timestamp = os.time(), <payload fields shallow-merged> }
function Exchange.buildAuditEntry(kind, payload)
	assert(type(kind) == "string", "Exchange.buildAuditEntry: kind must be a string")
	local entry = { kind = kind, timestamp = os.time() }
	if type(payload) == "table" then
		for k, v in pairs(payload) do
			entry[k] = v
		end
	end
	return entry
end

-- ---------- Roblox-bound (DataStore) --------------------------------------

-- Persist an audit entry to MyceliaAuditLog_v1. pcall-wrapped — silent
-- failure on DataStore errors is acceptable per the existing Trade pattern.
-- Key derivation:
--   sessionId present  → "trade_" .. sessionId
--   listingId present  → "stall_" .. listingId
--   else              → kind .. "_" .. timestamp .. "_" .. random
function Exchange.writeAudit(entry)
	if not auditStore then return end
	if type(entry) ~= "table" then return end
	if type(entry.kind) ~= "string" then return end

	local key
	if entry.sessionId then
		key = "trade_" .. tostring(entry.sessionId)
	elseif entry.listingId then
		key = "stall_" .. tostring(entry.listingId)
	else
		key = entry.kind .. "_" .. tostring(entry.timestamp or os.time()) .. "_" .. tostring(math.random(1, 1e9))
	end

	pcall(function()
		auditStore:SetAsync(key, entry)
	end)
end

return Exchange
