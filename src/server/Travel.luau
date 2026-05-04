-- Biome travel system. Single-place world, no TeleportService — players
-- move between biomes via direct CFrame teleport of their character to
-- the destination biome's spawnPoint (per ADR 001).
--
-- Server validates renown threshold + travel cost on every request; also
-- sets `biomesUnlocked[biomeId] = true` defensively at travel time so a
-- player whose unlock flag was lost (support intervention, save migration)
-- can still travel as long as they meet the renown gate.
--
-- The current biome is tracked as a Player attribute (`currentBiome`) so
-- other systems (Spirits attraction, future Weather, future Quest gating)
-- can read it cheaply.
--
-- Spec: docs/specs/biome-config.md "Travel NPC".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.Server.PlayerData)

local Travel = {}

-- Pure helper: total renown across all NPC reputation entries.
function Travel.totalRenown(data): number
	if not data or not data.reputation then return 0 end
	local total = 0
	for _, entry in pairs(data.reputation) do
		total = total + (entry.score or 0)
	end
	return total
end

-- Pure helper: can this player travel to this biome? Returns (ok, reason).
function Travel.canTravel(data, biomeId): (boolean, string?)
	local config = Constants.BIOMES[biomeId]
	if not config then
		return false, "unknownBiome"
	end
	if Travel.totalRenown(data) < config.unlockRenown then
		return false, "renownGate"
	end
	if (data.coins or 0) < config.travelCostCoins then
		return false, "insufficientCoins"
	end
	-- Future: extra gates (lunarQuestCompleted etc.) checked here via
	-- config.unlockExtraGate(player) when those quests exist.
	return true, nil
end

-- Roblox-bound: actually move the player + deduct coins + set attribute.
-- Returns (ok, reason).
local function performTravel(player: Player, biomeId: string): (boolean, string?)
	local data = PlayerData.get(player)
	if not data then return false, "noData" end

	local ok, reason = Travel.canTravel(data, biomeId)
	if not ok then return false, reason end

	local config = Constants.BIOMES[biomeId]

	-- Deduct coins + flip biomesUnlocked flag in one PlayerData.update so
	-- the client sees a single replicated change.
	PlayerData.update(player, function(d)
		if config.travelCostCoins > 0 then
			d.coins -= config.travelCostCoins
		end
		d.stats.biomesUnlocked = d.stats.biomesUnlocked or {}
		d.stats.biomesUnlocked[biomeId] = true
	end)

	-- Move the character.
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		hrp.CFrame = CFrame.new(config.spawnPoint + Vector3.new(0, 3, 0))
	end

	player:SetAttribute("currentBiome", biomeId)

	Remotes.get(Constants.REMOTES.BiomeTravelCompleted):FireClient(player, {
		success = true, biomeId = biomeId,
	})
	return true, nil
end

local function handleTravelRequest(player: Player, biomeId: any)
	if typeof(biomeId) ~= "string" then return end
	local ok, reason = performTravel(player, biomeId)
	if not ok then
		Remotes.get(Constants.REMOTES.BiomeTravelCompleted):FireClient(player, {
			success = false, reason = reason,
		})
	end
end

-- Public wrapper: triggered by either the RequestBiomeTravel remote OR a
-- dialogue action (Travel Coordinator NPC). Both paths share identical
-- validation — performTravel is the single source of truth.
function Travel.requestTravel(player: Player, biomeId: string): (boolean, string?)
	return performTravel(player, biomeId)
end

function Travel.start()
	Remotes.get(Constants.REMOTES.RequestBiomeTravel).OnServerEvent:Connect(handleTravelRequest)

	-- Set initial currentBiome attribute on player join. Default StarterGlade
	-- since that's where everyone spawns. PlayerData.start fires PlayerAdded
	-- earlier in init, so this hook is fine to attach late.
	local function stampInitialBiome(player: Player)
		task.wait(0.5)
		if not player:GetAttribute("currentBiome") then
			player:SetAttribute("currentBiome", "StarterGlade")
		end
	end
	Players.PlayerAdded:Connect(stampInitialBiome)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(stampInitialBiome, player)
	end
end

return Travel
