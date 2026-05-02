-- Server-authoritative harvest handler.
--
-- Wild mushrooms and ripe planted patches both work the same way: a
-- ProximityPrompt with the right Attribute fires PromptTriggered, we
-- validate, award the species to the player's inventory, and the world
-- model is updated (wild → destroyed, planted patch → reset to Empty).
--
-- All mushroom-bearing instances are tagged with Attributes:
--   isWildMushroom : bool   set on wild-spawn root
--   isPlot         : bool   set on plot root; harvest only valid if state == "Ripe"
--   speciesId      : string the species being harvested
--
-- Pinning the contract to attributes (not naming conventions) means
-- WildSpawn / Planting can change visuals freely.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerScriptService = game:GetService("ServerScriptService")

local Species = require(ReplicatedStorage.Shared.Species)
local Inventory = require(ServerScriptService.Server.Inventory)
local PlayerData = require(ServerScriptService.Server.PlayerData)
local PotionEffects = require(ServerScriptService.Server.PotionEffects)
local PassiveBonuses = require(ServerScriptService.Server.PassiveBonuses)

local Harvesting = {}

-- Other modules can subscribe to these to react to harvests.
-- Used by WildSpawn (to schedule respawn) and Planting (to reset plot).
Harvesting.WildHarvested = Instance.new("BindableEvent")    -- (player, mushroomModel, speciesId)
Harvesting.PlotHarvested = Instance.new("BindableEvent")    -- (player, plotModel, speciesId)

-- Resolve the "owner" Instance carrying our attributes. Prompts are usually
-- parented to a Part inside a Model — walk up until we find one with the
-- attribute we expect.
local function findRoot(prompt: ProximityPrompt, attrName: string): Instance?
	local cur: Instance? = prompt.Parent
	while cur do
		if cur:GetAttribute(attrName) then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

local function harvestWild(player: Player, root: Instance)
	local speciesId = root:GetAttribute("speciesId")
	if not speciesId or not Species.byId[speciesId] then
		warn("[Harvesting] wild mushroom missing/unknown species:", root)
		return
	end
	-- Combined yield: base × spirit bonus (percentage) + potion bonus (flat).
	-- Spirits.Mossling = +5% wildYield (rounds away on a 1-yield base, but
	-- compounds when cultivation depth raises the base). Potion DewdropTonic
	-- adds the configured flat bonus on top.
	local spiritMul = 1 + PassiveBonuses.get(player, "wildYield")
	local yield = math.floor(1 * spiritMul) + PotionEffects.wildYieldBonus(player)
	PlayerData.update(player, function(data)
		Inventory.add(data.inventory, speciesId, yield)
		data.stats.totalHarvested += yield
		data.stats.speciesDiscovered[speciesId] = true
	end)
	Harvesting.WildHarvested:Fire(player, root, speciesId)
	root:Destroy()
end

local function harvestPlot(player: Player, plot: Instance)
	if plot:GetAttribute("state") ~= "Ripe" then
		return
	end
	local speciesId = plot:GetAttribute("speciesId")
	if not speciesId or not Species.byId[speciesId] then
		return
	end
	-- Same combined formula as wild: spirit % bonus on the base (1) plus
	-- potion flat bonus on top. Per-substrate yield + rare-variant rolls
	-- (per ADR 002) land with the cultivation-depth task.
	local spiritMul = 1 + PassiveBonuses.get(player, "harvestYield")
	local yield = math.floor(1 * spiritMul) + PotionEffects.harvestYieldBonus(player)
	PlayerData.update(player, function(data)
		Inventory.add(data.inventory, speciesId, yield)
		data.stats.totalHarvested += yield
		data.stats.speciesDiscovered[speciesId] = true
	end)
	-- Don't destroy the plot. Reset it to Empty so it can be replanted.
	plot:SetAttribute("state", "Empty")
	plot:SetAttribute("speciesId", "")
	plot:SetAttribute("plantedAt", 0)
	plot:SetAttribute("ripeAt", 0)
	plot:SetAttribute("plantedByUserId", 0)
	Harvesting.PlotHarvested:Fire(player, plot, speciesId)
end

function Harvesting.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "WildHarvestPrompt" then
			local root = findRoot(prompt, "isWildMushroom")
			if root then
				harvestWild(player, root)
			end
		elseif prompt.Name == "HarvestPrompt" then
			local plot = findRoot(prompt, "isPlot")
			if plot then
				harvestPlot(player, plot)
			end
		end
	end)
end

return Harvesting
