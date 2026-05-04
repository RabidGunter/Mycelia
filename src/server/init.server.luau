-- Mycelia server entry point. Wires every system together in the right
-- order on game start, registers Player join/leave handlers, and sets up
-- the BindToClose autosave path.
--
-- Lives at ServerScriptService.Server (Rojo-mapped from src/server/init.server.luau).
-- All sibling files (Atmosphere, Brewing, Harvesting, etc.) are children of
-- this Script and are required as ModuleScripts via ServerScriptService.Server.X.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

-- Required for its side effect of creating the Remotes folder under
-- ReplicatedStorage. Other modules require Constants/Remotes too, so this
-- is belt-and-suspenders, but explicit is good in an entry point.
local _Remotes = require(ReplicatedStorage.Shared.Remotes)
local Constants = require(ReplicatedStorage.Shared.Constants)

local PlayerData = require(ServerScriptService.Server.PlayerData)
local Harvesting = require(ServerScriptService.Server.Harvesting)
local Planting = require(ServerScriptService.Server.Planting)
local Shop = require(ServerScriptService.Server.Shop)
local Quest = require(ServerScriptService.Server.Quest)
local Dialogue = require(ServerScriptService.Server.Dialogue)
local Trade = require(ServerScriptService.Server.Trade)
local Brewing = require(ServerScriptService.Server.Brewing)
local PotionEffects = require(ServerScriptService.Server.PotionEffects)
local PassiveBonuses = require(ServerScriptService.Server.PassiveBonuses)
local Spirits = require(ServerScriptService.Server.Spirits)
local WildSpawn = require(ServerScriptService.Server.WildSpawn)
local BiomeBuilder = require(ServerScriptService.Server.BiomeBuilder)
local Travel = require(ServerScriptService.Server.Travel)
local TerrainBuilder = require(ServerScriptService.Server.TerrainBuilder)
local MapSetup = require(ServerScriptService.Server.MapSetup)
local Atmosphere = require(ServerScriptService.Server.Atmosphere)
local Koi = require(ServerScriptService.Server.Koi)
local Trees = require(ServerScriptService.Server.Trees)

print("[Mycelia] Server starting…")

-- 1. Configure lighting + atmosphere first so the moment the world appears,
--    it appears in its intended mood. pcall so a single Lighting property
--    losing its capability (Roblox tightens these from time to time) can't
--    take down the rest of the world build.
do
	local ok, err = pcall(Atmosphere.apply)
	if not ok then
		warn("[Mycelia] Atmosphere failed (continuing without it): " .. tostring(err))
	end
end

-- 2. Paint terrain (Starter Glade). Runs before MapSetup so MapSetup sees
--    the HasHandBuiltGround flag and skips its procedural grass slab. No-op
--    if the user has already flagged hand-built terrain.
-- pcall so a Terrain API hiccup can't take down the rest of the world build;
-- if it fails, MapSetup will still drop a procedural grass slab as backup.
local ok, err = pcall(TerrainBuilder.build)
if not ok then
	warn("[Mycelia] TerrainBuilder failed, falling back to procedural ground: " .. tostring(err))
end

-- 3. Build the world (Parts: spawn pad, witch stall, cauldron, plots,
--    wild-spawn volume). Returns refs the gameplay systems need.
local map = MapSetup.build(Constants.CULTIVATION.startingPlotSize)

-- 4. Start gameplay systems. Order matters: Harvesting first, because
--    Planting and WildSpawn both subscribe to its events.
Harvesting.start()
Planting.start(Harvesting)
Shop.start()
Quest.start(Harvesting)
Dialogue.start()
Trade.start()
Brewing.start()
PotionEffects.start()
PassiveBonuses.start()
Spirits.start()
Travel.start()

-- 4b. Per-biome wild spawn loops. BiomeBuilder ensures each biome has a
--     Workspace.Biomes.<id> Folder + WildSpawnArea Part (procedural
--     fallback when hand-built terrain isn't present), reusing MapSetup's
--     legacy Workspace.WildSpawnArea for StarterGlade so we don't double-
--     spawn. Then one WildSpawn loop runs per biome.
local biomeBuilds = BiomeBuilder.buildAll()
for biomeId, build in pairs(biomeBuilds) do
	if build.area then
		WildSpawn.startBiome(build.config, build.area, Harvesting)
	else
		warn("[Mycelia] No WildSpawnArea for biome " .. biomeId .. " — wild spawn disabled there")
	end
end

-- 5. Register every plot the map built. Each plot becomes Plantable.
for _, plot in ipairs(map.plots) do
	Planting.registerPlot(plot)
end

-- 5b. Spawn koi in the pond (purely decorative; no gameplay effect).
--     pcall so a Mesh API blip can't take down the rest of the server.
do
	local ok, err = pcall(Koi.start)
	if not ok then
		warn("[Mycelia] Koi failed (continuing without them): " .. tostring(err))
	end
end

-- 5c. Scatter pine trees around the biome perimeter. Decorative, raycast-
--     grounded so trees sit on hills/dirt patches naturally. pcall for the
--     same reason as Koi.
do
	local ok, err = pcall(Trees.spawn)
	if not ok then
		warn("[Mycelia] Trees failed (continuing without them): " .. tostring(err))
	end
end

-- 6. Player lifecycle. PlayerData.start() handles PlayerAdded / Removing
--    handlers + already-present players. Autosave + BindToClose shutdown
--    are managed internally by ProfileService — no separate calls needed.
PlayerData.start()

print("[Mycelia] Server ready.")
