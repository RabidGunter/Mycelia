-- Wild mushroom spawner. Periodically places mushroom Models inside a
-- BasePart spawn volume until a per-biome cap is reached. When a wild
-- mushroom is harvested (Harvesting.WildHarvested fires), the per-area
-- count drops and the loop refills.
--
-- Phase 1: refactored from single-biome to per-biome. The module exposes
-- WildSpawn.startBiome(biomeConfig, area, harvesting) — call once per
-- biome with that biome's config + the BasePart marking its spawn volume.
-- Each call gets its own active-mushroom list, so multiple biome spawners
-- run independently. The `area` BasePart attribute `biomeId` is also set
-- so harvest paths can know which biome a wild mushroom came from.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Tiers = require(ReplicatedStorage.Shared.Tiers)

local WildSpawn = {}

-- Pure helper: weighted random pick from a list of speciesIds, weighted
-- by each species' tier dropWeight. Returns nil if the list is empty or
-- all entries reference unknown tiers.
local function pickSpeciesFrom(speciesList: { string }): string?
	local totalWeight = 0
	for _, id in ipairs(speciesList) do
		local sp = Species.byId[id]
		local tier = sp and Tiers[sp.tier]
		if tier then
			totalWeight += tier.dropWeight
		end
	end
	if totalWeight <= 0 then
		return nil
	end
	local roll = math.random() * totalWeight
	for _, id in ipairs(speciesList) do
		local sp = Species.byId[id]
		local tier = sp and Tiers[sp.tier]
		if tier then
			roll -= tier.dropWeight
			if roll <= 0 then
				return id
			end
		end
	end
	return speciesList[1]
end

WildSpawn._pickSpeciesFrom = pickSpeciesFrom    -- exposed for tests

local function randomPointInside(area: BasePart): Vector3
	local size = area.Size
	local cf = area.CFrame
	local x = (math.random() - 0.5) * size.X
	local z = (math.random() - 0.5) * size.Z
	local local_ = Vector3.new(x, -size.Y / 2, z)
	return cf:PointToWorldSpace(local_)
end

-- Per-species visual recipe. Anything not listed falls back to a sensible
-- default below. Cap shape is achieved with a SpecialMesh on a Ball Part —
-- the mesh's Scale axes squash/stretch the sphere into domes, buttons,
-- bells, etc. without needing custom asset uploads.
--
-- Fields:
--   capColor   Color3      -- override of tier.displayColor for the cap
--   capScale   Vector3     -- mesh.Scale on the cap; (1,1,1) = sphere,
--                              (1,0.5,1) = squat dome, (0.8,1.2,0.8) = tall.
--   capSize    number      -- diameter in studs (default 2.5)
--   stemHeight number      -- stem length in studs (default 2.5)
--   stemColor  Color3      -- default off-white
--   material   Material    -- cap material (default SmoothPlastic)
--   hasSpots   boolean     -- white spots on top of the cap (Toadstool)
--   glow       boolean     -- attach a PointLight + Neon material to the cap
--   glowColor  Color3      -- light colour (default = capColor)
--   glowRange  number      -- light range in studs (default 8)
local SPECIES_VISUALS: { [string]: any } = {
	-- Common
	BrownCap         = { capColor = Color3.fromRGB(155, 110, 75),  capScale = Vector3.new(1, 0.7, 1), capSize = 2.6 },
	SpottedToadstool = { capColor = Color3.fromRGB(220, 50, 50),   capScale = Vector3.new(1, 0.65, 1), capSize = 3, hasSpots = true },
	FairyCup         = { capColor = Color3.fromRGB(230, 210, 240), capScale = Vector3.new(1, 0.45, 1), capSize = 2.2, stemColor = Color3.fromRGB(245, 235, 225) },
	Mossring         = { capColor = Color3.fromRGB(140, 180, 100), capScale = Vector3.new(1, 0.4, 1),  capSize = 2.4 },
	Buttoncap        = { capColor = Color3.fromRGB(245, 230, 200), capScale = Vector3.new(1, 0.55, 1), capSize = 2.5 },
	Pinwheel         = { capColor = Color3.fromRGB(220, 170, 100), capScale = Vector3.new(1, 0.45, 1), capSize = 2.7 },
	-- Uncommon
	LatticeVeil      = { capColor = Color3.fromRGB(180, 220, 200), capScale = Vector3.new(1, 0.7, 1),  capSize = 2.7, material = Enum.Material.Foil },
	Inkpot           = { capColor = Color3.fromRGB(45, 30, 50),    capScale = Vector3.new(1, 0.85, 1), capSize = 2.5, stemColor = Color3.fromRGB(180, 170, 160) },
	CoralTongue      = { capColor = Color3.fromRGB(255, 130, 110), capScale = Vector3.new(0.7, 1.3, 0.7), capSize = 2.2 },
	Sundrop          = { capColor = Color3.fromRGB(255, 215, 90),  capScale = Vector3.new(1, 0.6, 1),  capSize = 2.6, glow = true, glowColor = Color3.fromRGB(255, 230, 130), glowRange = 6 },
	Hollowstem       = { capColor = Color3.fromRGB(220, 200, 170), capScale = Vector3.new(1, 0.4, 1),  capSize = 2.2, stemHeight = 4 },
	-- Rare
	Glowmoss         = { capColor = Color3.fromRGB(120, 240, 160), capScale = Vector3.new(1, 0.65, 1), capSize = 2.7, material = Enum.Material.Neon, glow = true, glowColor = Color3.fromRGB(140, 255, 190), glowRange = 12 },
	Dewfern          = { capColor = Color3.fromRGB(120, 200, 180), capScale = Vector3.new(1, 0.5, 1),  capSize = 2.6 },
	Whisperbloom     = { capColor = Color3.fromRGB(200, 180, 230), capScale = Vector3.new(1, 0.7, 1),  capSize = 2.7, glow = true, glowColor = Color3.fromRGB(220, 200, 255), glowRange = 8 },
	-- Epic
	CrystalCap       = { capColor = Color3.fromRGB(190, 220, 255), capScale = Vector3.new(1, 0.8, 1),  capSize = 3.2, material = Enum.Material.Glass, glow = true, glowColor = Color3.fromRGB(200, 230, 255), glowRange = 14 },
}

local function visualFor(speciesId: string, tier): { [string]: any }
	local v = SPECIES_VISUALS[speciesId]
	if v then
		return v
	end
	-- Sensible default for unmapped species: simple grey-ish dome tinted
	-- with the tier display colour.
	return {
		capColor = tier.displayColor,
		capScale = Vector3.new(1, 0.6, 1),
		capSize = 2.5,
	}
end

local function addSpotsTo(cap: BasePart, capSize: number, capScaleY: number, model: Instance)
	-- 5-7 small white spheres scattered across the upper hemisphere of the
	-- cap. Sized relative to the cap so big caps get correspondingly big
	-- spots, and offset on a half-circle so they all sit on top.
	local count = math.random(5, 7)
	for i = 1, count do
		local spot = Instance.new("Part")
		spot.Name = "Spot"
		spot.Shape = Enum.PartType.Ball
		spot.Size = Vector3.new(capSize * 0.18, capSize * 0.18, capSize * 0.18)
		spot.Color = Color3.fromRGB(250, 250, 245)
		spot.Material = Enum.Material.SmoothPlastic
		spot.Anchored = true
		spot.CanCollide = false
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local r = capSize * (0.18 + math.random() * 0.22)
		local upOff = capSize * capScaleY * (0.18 + math.random() * 0.18)
		spot.Position = cap.Position + Vector3.new(math.cos(angle) * r, upOff, math.sin(angle) * r)
		spot.Parent = model
	end
end

local function spawnOne(area: BasePart, biomeConfig, activeList: { Instance })
	local speciesId = pickSpeciesFrom(biomeConfig.wildSpawnTable)
	if not speciesId then
		return
	end
	local species = Species.byId[speciesId]
	local tier = Tiers[species.tier]
	local visual = visualFor(speciesId, tier)

	local model = Instance.new("Model")
	model.Name = "Wild_" .. speciesId
	model:SetAttribute("isWildMushroom", true)
	model:SetAttribute("speciesId", speciesId)
	model:SetAttribute("biomeId", biomeConfig.id)

	local stemHeight: number = visual.stemHeight or 2.5
	local stemColor: Color3 = visual.stemColor or Color3.fromRGB(245, 235, 215)
	local capSize: number = visual.capSize or 2.5
	local capScale: Vector3 = visual.capScale or Vector3.new(1, 0.6, 1)
	local capMaterial: Enum.Material = visual.material or Enum.Material.SmoothPlastic

	-- Stem: a slim block. Wider than the previous 0.4 stud so the stem is
	-- legible from a distance.
	local stem = Instance.new("Part")
	stem.Name = "Stem"
	stem.Size = Vector3.new(0.6, stemHeight, 0.6)
	stem.Color = stemColor
	stem.Material = Enum.Material.SmoothPlastic
	stem.Anchored = true
	stem.CanCollide = false
	local pos = randomPointInside(area) + Vector3.new(0, stemHeight / 2, 0)
	stem.CFrame = CFrame.new(pos)
	stem.Parent = model

	-- Cap. A Ball Part with a SpecialMesh that scales the sphere along each
	-- axis — squat domes, tall bells, fluted fans all come from one
	-- primitive plus a Vector3 of scale.
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Shape = Enum.PartType.Ball
	cap.Size = Vector3.new(capSize, capSize, capSize)
	cap.Color = visual.capColor or tier.displayColor
	cap.Material = capMaterial
	cap.Anchored = true
	cap.CanCollide = false
	-- Lift the cap so its bottom sits flush on top of the stem after the
	-- mesh squash (squash factor capScale.Y reduces effective height).
	cap.CFrame = stem.CFrame * CFrame.new(0, stemHeight / 2 + capSize * capScale.Y / 2, 0)
	cap.Parent = model
	model.PrimaryPart = cap

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = capScale
	mesh.Parent = cap

	-- Optional decorations.
	if visual.hasSpots then
		addSpotsTo(cap, capSize, capScale.Y, model)
	end
	if visual.glow then
		local light = Instance.new("PointLight")
		light.Color = visual.glowColor or visual.capColor or tier.displayColor
		light.Range = visual.glowRange or 8
		light.Brightness = 1.6
		light.Shadows = false
		light.Parent = cap
	end

	-- Harvest prompt — keystroke E by default; mobile gets a tap button.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WildHarvestPrompt"
	prompt.ActionText = "Harvest"
	prompt.ObjectText = species.displayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = cap

	model.Parent = Workspace
	table.insert(activeList, model)
end

local function pruneActiveList(activeList: { Instance })
	for i = #activeList, 1, -1 do
		if not activeList[i].Parent then
			table.remove(activeList, i)
		end
	end
end

-- Per-biome refill loop. Multiple of these run in parallel — one per biome
-- the server has built. Each manages its own activeList so caps don't leak
-- across biomes.
function WildSpawn.startBiome(biomeConfig, area: BasePart, harvesting)
	if not biomeConfig or not area then
		warn("[WildSpawn] startBiome called with nil config or area")
		return
	end
	local activeList: { Instance } = {}

	task.spawn(function()
		while true do
			pruneActiveList(activeList)
			if #activeList < biomeConfig.wildSpawnCap then
				spawnOne(area, biomeConfig, activeList)
			end
			task.wait(biomeConfig.wildSpawnInterval)
		end
	end)

	-- Respond instantly to wild harvests in THIS biome (filter by biomeId
	-- attribute on the harvested model). Cuts perceived "where's the next
	-- mushroom?" latency without inflating the spawn rate.
	if harvesting and harvesting.WildHarvested then
		harvesting.WildHarvested.Event:Connect(function(_player, root, _speciesId)
			if root:GetAttribute("biomeId") ~= biomeConfig.id then
				return    -- another biome's harvest; their spawner handles it
			end
			task.wait(0.5)
			pruneActiveList(activeList)
			if #activeList < biomeConfig.wildSpawnCap then
				spawnOne(area, biomeConfig, activeList)
			end
		end)
	end
end

-- Backwards-compat shim. Old call sites pass (area, harvesting) for the
-- single Starter Glade spawner. Routes them through startBiome with the
-- StarterGlade config. Remove this when no callers use the old shape.
function WildSpawn.start(area: BasePart, harvesting)
	WildSpawn.startBiome(Constants.BIOMES.StarterGlade, area, harvesting)
end

return WildSpawn
