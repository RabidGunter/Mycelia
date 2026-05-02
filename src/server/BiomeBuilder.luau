-- Procedural per-biome world construction.
--
-- For each biome in Constants.BIOMES, ensures `Workspace.Biomes.<biomeId>`
-- exists as a Folder and contains the basic spatial markers (currently:
-- the WildSpawnArea BasePart). Returns a map of biomeId → { area } so the
-- caller (init.server.luau) can wire up per-biome WildSpawn instances.
--
-- Hand-built escape valve per spec: if `Workspace.Biomes.<biomeId>` exists
-- with attribute `BuiltManually = true`, BiomeBuilder leaves it alone and
-- just confirms the WildSpawnArea Part exists by name. Hand-painted terrain
-- + decorations under that Folder are preserved across server starts.
--
-- Phase 1: only spawns the WildSpawnArea Part. SpawnPads, NPC anchors,
-- plot regions are MapSetup's domain (Starter Glade) or to-be-built later
-- (Misty Hollow polish pass).

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)

local BiomeBuilder = {}

local function getBiomesFolder(): Folder
	local folder = Workspace:FindFirstChild("Biomes")
	if folder and folder:IsA("Folder") then
		return folder
	end
	folder = Instance.new("Folder")
	folder.Name = "Biomes"
	folder.Parent = Workspace
	return folder
end

local function buildWildSpawnArea(parent: Instance, biomeConfig)
	local existing = parent:FindFirstChild(biomeConfig.wildSpawnArea)
	if existing and existing:IsA("BasePart") then
		return existing    -- hand-built or previously-built; reuse
	end

	-- Spec calls for a 400x100x400 invisible volume centered on the biome's
	-- spawn point area. Anchored, non-collidable, transparent.
	local area = Instance.new("Part")
	area.Name = biomeConfig.wildSpawnArea
	area.Size = Vector3.new(400, 100, 400)
	-- Sit the volume so its bottom face is at y=0 (mushrooms spawn at the
	-- bottom of the area onto the ground). Center at zoneCenter + (0,50,0).
	area.Position = biomeConfig.zoneCenter + Vector3.new(0, 50, 0)
	area.Anchored = true
	area.CanCollide = false
	area.Transparency = 1
	area.Material = Enum.Material.SmoothPlastic
	area:SetAttribute("biomeId", biomeConfig.id)
	area.Parent = parent
	return area
end

-- Backwards-compat: MapSetup already creates Workspace.WildSpawnArea for
-- the Starter Glade. If we find a legacy area at that location, adopt it
-- as StarterGlade's spawn area and skip creating a duplicate. Returns
-- the BasePart, or nil if no legacy area exists.
local function adoptLegacyStarterGladeArea(): BasePart?
	local legacy = Workspace:FindFirstChild("WildSpawnArea")
	if legacy and legacy:IsA("BasePart") then
		legacy:SetAttribute("biomeId", "StarterGlade")
		return legacy
	end
	return nil
end

-- Build (or detect) every biome in Constants.BIOMES. Returns:
--   { [biomeId] = { config = biomeConfig, area = WildSpawnArea Part } }
function BiomeBuilder.buildAll()
	local biomesFolder = getBiomesFolder()
	local result: { [string]: { config: any, area: BasePart } } = {}

	for biomeId, config in pairs(Constants.BIOMES) do
		local biomeContainer = biomesFolder:FindFirstChild(biomeId)
		local handBuilt = biomeContainer and biomeContainer:GetAttribute("BuiltManually") == true

		if not biomeContainer then
			biomeContainer = Instance.new("Folder")
			biomeContainer.Name = biomeId
			biomeContainer:SetAttribute("BuiltManually", false)
			biomeContainer.Parent = biomesFolder
		end

		local area
		if handBuilt then
			area = biomeContainer:FindFirstChild(config.wildSpawnArea)
			if not area or not area:IsA("BasePart") then
				warn(("[BiomeBuilder] %s is BuiltManually but missing %s — wild spawn disabled"):format(
					biomeId, config.wildSpawnArea
				))
				continue
			end
		else
			-- StarterGlade special case: prefer MapSetup's legacy
			-- Workspace.WildSpawnArea so we don't double-spawn.
			if biomeId == "StarterGlade" then
				area = adoptLegacyStarterGladeArea()
			end
			if not area then
				area = buildWildSpawnArea(biomeContainer, config)
			end
		end

		result[biomeId] = { config = config, area = area }
	end

	return result
end

return BiomeBuilder
