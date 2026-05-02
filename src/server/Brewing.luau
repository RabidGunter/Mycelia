-- Server-authoritative brewing.
--
-- Client sends (method, ingredientIds[]) via the Brew remote. Server:
--   1. Validates method + count (1..5 ingredients).
--   2. Validates every species id is real.
--   3. Validates the player has each ingredient in their inventory.
--   4. Consumes the ingredients (success or fail — failure is a real cost).
--   5. Looks up the recipe. If it matches a known potion, the potion is
--      added to data.potions. If not, the brew fizzles silently.
--   6. Fires BrewCompleted to the client with { success, potionId,
--      isNewDiscovery } so the UI can show the right toast.
--
-- Failed brews intentionally consume ingredients. That's the design-doc
-- engagement loop: experimentation has cost; discovery has weight.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Potions = require(ReplicatedStorage.Shared.Potions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(ServerScriptService.Server.Inventory)
local PlayerData = require(ServerScriptService.Server.PlayerData)

local Brewing = {}

local function isValidMethod(method: string): boolean
	for _, m in ipairs(Recipes.METHODS) do
		if m == method then
			return true
		end
	end
	return false
end

-- Reply to the client whether the brew succeeded, what was produced, and
-- whether it's the first time the player has brewed it.
local function notify(player: Player, success: boolean, potionId: string?, isNewDiscovery: boolean)
	Remotes.get(Constants.REMOTES.BrewCompleted):FireClient(player, {
		success = success,
		potionId = potionId,
		isNewDiscovery = isNewDiscovery,
	})
end

local function attemptBrew(player: Player, method: string, ingredientIds: { string })
	if not isValidMethod(method) then
		return
	end
	if #ingredientIds < 1 or #ingredientIds > 5 then
		return
	end

	-- Tally needed quantities and validate species exist.
	local needed: { [string]: number } = {}
	for _, id in ipairs(ingredientIds) do
		if type(id) ~= "string" or not Species.byId[id] then
			return
		end
		needed[id] = (needed[id] or 0) + 1
	end

	local data = PlayerData.get(player)
	if not data then
		return
	end

	-- Inventory check before consuming.
	for id, count in pairs(needed) do
		if Inventory.count(data.inventory, id) < count then
			return
		end
	end

	local potionId = Recipes.lookup(method, ingredientIds)

	-- Consume ingredients + (on success) deposit the potion.
	-- Single PlayerData.update call so the client receives one
	-- PlayerDataUpdated push instead of two.
	PlayerData.update(player, function(d)
		for id, count in pairs(needed) do
			Inventory.remove(d.inventory, id, count)
		end
		d.stats.totalBrewed = (d.stats.totalBrewed or 0) + 1
		if potionId then
			d.potions[potionId] = (d.potions[potionId] or 0) + 1
		end
	end)

	-- Discovery flag is mutated in a second update so we can report
	-- "isNewDiscovery" accurately to the client (it was true before the
	-- mutation if and only if the flag was unset).
	local isNewDiscovery = false
	if potionId then
		local current = PlayerData.get(player)
		if current and current.stats.potionsDiscovered
			and not current.stats.potionsDiscovered[potionId] then
			isNewDiscovery = true
			PlayerData.update(player, function(d)
				d.stats.potionsDiscovered[potionId] = true
			end)
		end
	end

	notify(player, potionId ~= nil, potionId, isNewDiscovery)
end

function Brewing.start()
	Remotes.get(Constants.REMOTES.Brew).OnServerEvent:Connect(
		function(player: Player, method: any, ingredientIds: any)
			if typeof(method) ~= "string" or typeof(ingredientIds) ~= "table" then
				return
			end
			-- Defensive copy so a malicious client can't keep mutating the
			-- table mid-validation.
			local copy = {}
			for i = 1, math.min(#ingredientIds, 5) do
				copy[i] = ingredientIds[i]
			end
			attemptBrew(player, method, copy)
		end
	)
end

return Brewing
