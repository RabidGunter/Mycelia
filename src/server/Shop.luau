-- Shop / merchant transaction system. Replaces the Pre-Alpha witch
-- auto-sell with a configurable per-merchant interaction.
--
-- Public API:
--   Shop.priceFor(merchant, itemId)            - per-mushroom unit price
--   Shop.totalSellPrice(merchant, items)       - total payout for a sell request
--   Shop.canSell(merchant, itemId)             - merchant accepts itemId's category?
--   Shop.canBuy(merchant, itemId)              - merchant lists itemId for sale?
--   Shop.validateSell(merchant, items, inv)    - pure (ok, code, breakdown, total)
--   Shop.validateBuy(merchant, items, coins, byCat) - pure (ok, code, breakdown, total)
--   Shop.start()                                - wires remotes + prompt handlers
--
-- Spec: docs/specs/shop-ui.md. Wire-level remote contract:
-- docs/specs/remote-api.md "BuyFromMerchant / SellToMerchant".

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Reputation = require(ReplicatedStorage.Shared.Reputation)
local Inventory = require(ServerScriptService.Server.Inventory)
local PlayerData = require(ServerScriptService.Server.PlayerData)
local Quest = require(ServerScriptService.Server.Quest)

local Shop = {}

-- ---------- Pure helpers ----------------------------------------------------

-- Resolve a merchant's per-unit buy price for a single item. For mushroom
-- ids that means species.baseSellPrice * tier.sellMultiplier * merchant
-- buyMultiplier. Returns 0 for unknown ids (caller validates explicitly).
function Shop.priceFor(merchant, itemId: string): number
	if type(merchant) ~= "table" or type(itemId) ~= "string" then return 0 end
	local species = Species.byId[itemId]
	if not species then return 0 end
	local tier = Tiers[species.tier]
	if not tier then return 0 end
	local raw = species.baseSellPrice * tier.sellMultiplier * (merchant.buyMultiplier or 1)
	return math.floor(raw)
end

-- Summed witch-style payout for an inventory snapshot or sell request.
-- Same shape and semantics as the old Selling.priceOf, except parameterized
-- by merchant config (so future merchants with different multipliers /
-- accepted categories are first-class).
function Shop.totalSellPrice(merchant, items: { [string]: number }): number
	if type(items) ~= "table" then return 0 end
	local total = 0
	for itemId, count in pairs(items) do
		if type(itemId) == "string" and type(count) == "number" and count > 0 then
			local unit = Shop.priceFor(merchant, itemId)
			if unit > 0 then
				total += unit * math.floor(count)
			end
		end
	end
	return total
end

-- True if `itemId` belongs to a category this merchant accepts for sells.
-- Currently only `mushrooms_raw` ships, so the category check resolves via
-- Species.byId membership. Future merchant categories (substrates, spores)
-- read from Constants.ITEMS once that table populates.
function Shop.canSell(merchant, itemId: string): boolean
	if type(merchant) ~= "table" or type(itemId) ~= "string" then return false end
	local categories = merchant.buyCategories
	if type(categories) ~= "table" then return false end
	local species = Species.byId[itemId]
	if species then
		for _, cat in ipairs(categories) do
			if cat == "mushrooms_raw" then return true end
		end
		return false
	end
	-- Future: look up itemId in Constants.ITEMS and check its category here.
	return false
end

function Shop.canBuy(merchant, itemId: string): boolean
	if type(merchant) ~= "table" or type(itemId) ~= "string" then return false end
	local listings = merchant.itemsForSale
	if type(listings) ~= "table" then return false end
	return listings[itemId] ~= nil
end

-- Returns (ok, code, breakdown, total). breakdown is { [itemId]={qty,unit,sub} }
-- so the client can render a per-row receipt without recomputing.
function Shop.validateSell(
	merchant,
	items: { [string]: number },
	inventory: { [string]: number }
): (boolean, string, { [string]: any }, number)
	if type(merchant) ~= "table" then return false, "UNKNOWN_MERCHANT", {}, 0 end
	if type(items) ~= "table" or next(items) == nil then
		return false, "INVALID_REQUEST", {}, 0
	end
	if type(inventory) ~= "table" then return false, "INVALID_REQUEST", {}, 0 end

	local breakdown = {}
	local total = 0

	for itemId, qty in pairs(items) do
		if type(itemId) ~= "string" then return false, "INVALID_REQUEST", {}, 0 end
		if type(qty) ~= "number" or qty <= 0 or qty ~= math.floor(qty) then
			return false, "INVALID_REQUEST", {}, 0
		end
		if not Species.byId[itemId] then
			return false, "UNKNOWN_ITEM", {}, 0
		end
		if not Shop.canSell(merchant, itemId) then
			return false, "CATEGORY_REJECTED", {}, 0
		end
		if Inventory.count(inventory, itemId) < qty then
			return false, "INSUFFICIENT_INVENTORY", {}, 0
		end
		local unit = Shop.priceFor(merchant, itemId)
		local sub = unit * qty
		breakdown[itemId] = { qty = qty, unit = unit, sub = sub }
		total += sub
	end

	return true, "OK", breakdown, total
end

-- Returns (ok, code, breakdown, total). breakdown is { [itemId]={qty,unit,sub} }.
function Shop.validateBuy(
	merchant,
	items: { [string]: number },
	coins: number,
	inventoryByCategory: { [string]: any }
): (boolean, string, { [string]: any }, number)
	if type(merchant) ~= "table" then return false, "UNKNOWN_MERCHANT", {}, 0 end
	if type(items) ~= "table" or next(items) == nil then
		return false, "INVALID_REQUEST", {}, 0
	end
	if type(coins) ~= "number" then coins = 0 end
	if type(inventoryByCategory) ~= "table" then
		inventoryByCategory = {}
	end

	local breakdown = {}
	local total = 0

	for itemId, qty in pairs(items) do
		if type(itemId) ~= "string" then return false, "INVALID_REQUEST", {}, 0 end
		if type(qty) ~= "number" or qty <= 0 or qty ~= math.floor(qty) then
			return false, "INVALID_REQUEST", {}, 0
		end
		local listing = merchant.itemsForSale and merchant.itemsForSale[itemId]
		if not listing then
			return false, "UNKNOWN_ITEM", {}, 0
		end
		local unit = listing.unitPrice
		if type(unit) ~= "number" or unit < 0 then
			return false, "UNKNOWN_ITEM", {}, 0
		end
		local sub = unit * qty
		breakdown[itemId] = { qty = qty, unit = unit, sub = sub, category = listing.category }
		total += sub
	end

	if coins < total then
		return false, "INSUFFICIENT_COINS", breakdown, total
	end

	return true, "OK", breakdown, total
end

-- ---------- Roblox-bound side ----------------------------------------------

-- Find the world Part tagged with `merchantId = npcId`. Used for talk-range
-- validation. Returns nil if the NPC isn't built into the world yet (which
-- is fine — it just means the merchant config exists but the NPC anchor
-- hasn't shipped, so no player can be in range and validation always fails).
local function findMerchantAnchor(npcId: string): BasePart?
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("merchantId") == npcId then
			return descendant
		end
	end
	return nil
end

local function withinTalkRange(player: Player, merchant, npcId: string): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then return false end
	local anchor = findMerchantAnchor(npcId)
	if not anchor then return false end
	local range = merchant.talkRange or Constants.MERCHANT_DEFAULTS.talkRange
	return (hrp.Position - anchor.Position).Magnitude <= range
end

local function fireCompleted(
	player: Player,
	npcId: string,
	success: boolean,
	code: string,
	breakdown: any,
	coinDelta: number?
)
	Remotes.get(Constants.REMOTES.ShopTransactionCompleted):FireClient(player, {
		success = success,
		code = code,
		npcId = npcId,
		breakdown = breakdown,
		coinDelta = coinDelta,
	})
end

local function handleSell(player: Player, npcId: any, items: any)
	if type(npcId) ~= "string" then return end
	local merchant = Constants.MERCHANTS[npcId]
	if not merchant then
		fireCompleted(player, tostring(npcId), false, "UNKNOWN_MERCHANT", nil, nil)
		return
	end
	if not withinTalkRange(player, merchant, npcId) then
		fireCompleted(player, npcId, false, "OUT_OF_RANGE", nil, nil)
		return
	end
	local data = PlayerData.get(player)
	if not data then return end

	local ok, code, breakdown, total = Shop.validateSell(merchant, items, data.inventory)
	if not ok then
		fireCompleted(player, npcId, false, code, breakdown, nil)
		return
	end

	PlayerData.update(player, function(d)
		for itemId, row in pairs(breakdown) do
			Inventory.remove(d.inventory, itemId, row.qty)
			d.stats.totalSold = (d.stats.totalSold or 0) + row.qty
		end
		d.coins = (d.coins or 0) + total
		d.stats.totalCoinsEarned = (d.stats.totalCoinsEarned or 0) + total
	end)

	local repPerCoin = merchant.repPerCoin or Constants.MERCHANT_DEFAULTS.repPerCoin
	if repPerCoin > 0 and total > 0 then
		Reputation.add(player, merchant.reputationKey or npcId, total * repPerCoin)
	end

	-- Quest hook: tutorial quest 3 (the_witch_pays) tracks mushroom-count sold.
	-- Pass the per-merchant payload so future quests can target a specific
	-- merchant or a specific item filter.
	local soldCount = 0
	for _, row in pairs(breakdown) do soldCount += row.qty end
	Quest.onEvent(player, "sell_to_merchant", { npcId = npcId, items = breakdown, count = soldCount })

	fireCompleted(player, npcId, true, "OK", breakdown, total)
end

local function handleBuy(player: Player, npcId: any, items: any)
	if type(npcId) ~= "string" then return end
	local merchant = Constants.MERCHANTS[npcId]
	if not merchant then
		fireCompleted(player, tostring(npcId), false, "UNKNOWN_MERCHANT", nil, nil)
		return
	end
	if not withinTalkRange(player, merchant, npcId) then
		fireCompleted(player, npcId, false, "OUT_OF_RANGE", nil, nil)
		return
	end
	local data = PlayerData.get(player)
	if not data then return end

	local repGate = merchant.repGate or Constants.MERCHANT_DEFAULTS.repGate
	if repGate > 0 then
		local rep = Reputation.get(data, merchant.reputationKey or npcId)
		if rep < repGate then
			fireCompleted(player, npcId, false, "REP_GATE", nil, nil)
			return
		end
	end

	local ok, code, breakdown, total =
		Shop.validateBuy(merchant, items, data.coins or 0, data.inventoryByCategory)
	if not ok then
		fireCompleted(player, npcId, false, code, breakdown, nil)
		return
	end

	PlayerData.update(player, function(d)
		d.coins = (d.coins or 0) - total
		d.inventoryByCategory = d.inventoryByCategory or {}
		for itemId, row in pairs(breakdown) do
			local cat = row.category
			if cat then
				d.inventoryByCategory[cat] = d.inventoryByCategory[cat] or {}
				local bucket = d.inventoryByCategory[cat]
				bucket[itemId] = (bucket[itemId] or 0) + row.qty
			end
		end
	end)

	local repPerCoin = merchant.repPerCoin or Constants.MERCHANT_DEFAULTS.repPerCoin
	if repPerCoin > 0 and total > 0 then
		Reputation.add(player, merchant.reputationKey or npcId, total * repPerCoin)
	end

	fireCompleted(player, npcId, true, "OK", breakdown, -total)
end

-- ProximityPrompt → OpenShop fan-out. The prompt's parent Part advertises
-- which merchant it represents via the `merchantId` attribute. Defers to
-- the Dialogue system if the same Part also carries `dialogueId` — that
-- means the merchant is wrapped in a conversation tree that has its own
-- "Sell" / "Buy" response routing to OpenShop. Substrate Dealer + Spore
-- Merchant don't have dialogue trees (yet), so they go direct-shop.
local function handlePromptTrigger(prompt: ProximityPrompt, player: Player)
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then return end
	if type(part:GetAttribute("dialogueId")) == "string" then return end
	local npcId = part:GetAttribute("merchantId")
	if type(npcId) ~= "string" then return end
	local merchant = Constants.MERCHANTS[npcId]
	if not merchant then
		warn("[Shop] Prompt tagged merchantId=" .. npcId .. " but no MERCHANTS entry")
		return
	end
	Remotes.get(Constants.REMOTES.OpenShop):FireClient(player, {
		npcId = npcId,
	})
end

function Shop.start()
	ProximityPromptService.PromptTriggered:Connect(handlePromptTrigger)
	Remotes.get(Constants.REMOTES.SellToMerchant).OnServerEvent:Connect(handleSell)
	Remotes.get(Constants.REMOTES.BuyFromMerchant).OnServerEvent:Connect(handleBuy)
end

return Shop
