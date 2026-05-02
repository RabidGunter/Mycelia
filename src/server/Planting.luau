-- Plant + ripen lifecycle for plots.
--
-- A plot is a Model with these attributes:
--   isPlot          : bool, "this is a plot"
--   state           : "Empty" | "Growing" | "Ripe"
--   speciesId       : string, "" when Empty
--   plantedAt       : number, os.time()
--   ripeAt          : number, os.time() + species.growthTimeSeconds
--   plantedByUserId : number, UserId of the planter (0 when Empty). Used by
--                     PotionEffects so Hearth Brew accelerates only the
--                     planter's own currently-growing plots.
--   ownerUserId     : number, 0 = community plot (Pre-Alpha default;
--                     reserved for the future per-player plot pass)
--
-- Plots have child ProximityPrompts that are enabled/disabled per state:
--   PlantPrompt    enabled when Empty
--   HarvestPrompt  enabled when Ripe
--
-- The growing/ripe visuals are children of the plot model; we toggle their
-- visibility rather than instancing/destroying — cheaper, and the model
-- stays stable for client-side effects.
--
-- The PlantPrompt on each plot is a *client-only* trigger — it opens the
-- species picker UI on the client. The actual plant action runs through
-- the PlantSpecies RemoteEvent, where the server re-validates everything
-- (species exists, was discovered, plot is empty, player can afford it).

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.Server.PlayerData)
local PotionEffects = require(ServerScriptService.Server.PotionEffects)
local PassiveBonuses = require(ServerScriptService.Server.PassiveBonuses)

local Planting = {}

local activePlots: { Instance } = {}    -- registered with Planting.registerPlot

local function setPromptEnabled(plot: Instance, name: string, enabled: boolean)
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name == name then
			descendant.Enabled = enabled
		end
	end
end

local function setVisualState(plot: Instance, state: string)
	-- Show/hide named child folders by state. MapSetup creates plots with
	-- "EmptyVisual", "GrowingVisual", "RipeVisual" children (each a Model
	-- or Folder of decorative parts).
	for _, name in ipairs({ "EmptyVisual", "GrowingVisual", "RipeVisual" }) do
		local v = plot:FindFirstChild(name)
		if v then
			for _, part in ipairs(v:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = (name == state .. "Visual") and 0 or 1
					part.CanCollide = false
				end
			end
		end
	end
end

-- Server-authoritative plant. Every gate fails silently (returns false) so
-- a tampered client trying to plant something they shouldn't gets a no-op,
-- not a crash. The picker UI shows only valid options, so legit clients
-- never hit the false branches.
local function attemptPlantSpecies(player: Player, plot: Instance, speciesId: string): boolean
	-- Validate plot.
	if not plot or not plot.Parent or not plot:GetAttribute("isPlot") then
		return false
	end
	if plot:GetAttribute("state") ~= "Empty" then
		return false
	end

	-- Validate species.
	local species = Species.byId[speciesId]
	if not species then
		return false
	end

	-- Validate player can afford and has discovered the species.
	local data = PlayerData.get(player)
	if not data then
		return false
	end
	if not data.stats.speciesDiscovered[speciesId] then
		return false
	end
	local cost = Constants.CULTIVATION.plantCost[species.tier]
	if not cost or data.coins < cost then
		return false
	end

	PlayerData.update(player, function(d)
		d.coins -= cost
		d.stats.totalPlanted += 1
	end)

	local now = os.time()
	-- Combined growth multiplier sampled at plant time, locked in for this
	-- plot's lifetime (buffs expiring mid-grow don't slow down already-
	-- planted plots).
	--   * potion `growth` kind   — multiplier (e.g. HearthBrew = 0.7)
	--   * passive `growthSpeed`  — additive bonus (e.g. Spritefly = 0.05),
	--                              applied as (1 - bonus)
	local potionGrowthMul = PotionEffects.growthMultiplier(player)
	local spiritGrowthMul = PassiveBonuses.growthSpeedMultiplier(player)
	plot:SetAttribute("state", "Growing")
	plot:SetAttribute("speciesId", speciesId)
	plot:SetAttribute("plantedAt", now)
	plot:SetAttribute("plantedByUserId", player.UserId)
	plot:SetAttribute("ripeAt",
		now + math.floor(
			species.growthTimeSeconds
			* Constants.CULTIVATION.growthTimeMultiplier
			* potionGrowthMul
			* spiritGrowthMul
		))
	setPromptEnabled(plot, "PlantPrompt", false)
	setPromptEnabled(plot, "HarvestPrompt", false)
	setVisualState(plot, "Growing")
	return true
end

-- Called by Harvesting.PlotHarvested signal: reset visuals + prompts.
local function onPlotHarvested(_player: Player, plot: Instance, _speciesId: string)
	setPromptEnabled(plot, "PlantPrompt", true)
	setPromptEnabled(plot, "HarvestPrompt", false)
	setVisualState(plot, "Empty")
end

-- Called by MapSetup once each plot is built.
function Planting.registerPlot(plot: Instance)
	plot:SetAttribute("state", "Empty")
	plot:SetAttribute("speciesId", "")
	plot:SetAttribute("plantedAt", 0)
	plot:SetAttribute("ripeAt", 0)
	plot:SetAttribute("plantedByUserId", 0)
	plot:SetAttribute("isPlot", true)
	setPromptEnabled(plot, "PlantPrompt", true)
	setPromptEnabled(plot, "HarvestPrompt", false)
	setVisualState(plot, "Empty")
	table.insert(activePlots, plot)
end

-- Ripen check loop. Cheap: just compares two timestamps per plot.
-- Runs ~once a second via Heartbeat accumulator (don't need sub-second
-- precision for growth times measured in minutes).
local function startRipenLoop()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 1 then
			return
		end
		accumulator = 0
		local now = os.time()
		for _, plot in ipairs(activePlots) do
			if plot.Parent and plot:GetAttribute("state") == "Growing" then
				if now >= plot:GetAttribute("ripeAt") then
					plot:SetAttribute("state", "Ripe")
					setPromptEnabled(plot, "HarvestPrompt", true)
					setVisualState(plot, "Ripe")
				end
			end
		end
	end)
end

function Planting.start(harvesting)
	-- The PlantSpecies remote is the single entry point for actually
	-- planting something. Client picker UIs send (plot, speciesId); server
	-- re-validates everything before mutating state.
	Remotes.get(Constants.REMOTES.PlantSpecies).OnServerEvent:Connect(
		function(player: Player, plot: Instance, speciesId: string)
			if typeof(plot) ~= "Instance" or typeof(speciesId) ~= "string" then
				return
			end
			attemptPlantSpecies(player, plot, speciesId)
		end
	)
	-- Hook into Harvesting so plots reset when picked.
	if harvesting and harvesting.PlotHarvested then
		harvesting.PlotHarvested.Event:Connect(onPlotHarvested)
	end
	startRipenLoop()
end

return Planting
