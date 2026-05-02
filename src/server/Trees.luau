-- Pine tree forest scattered around the biome perimeter.
--
-- Each tree is a Model parented to Workspace.Trees:
--   - Trunk: a thin tall Block (Wood material, dark brown)
--   - Foliage: 4 stacked vertical cylinders (Grass material, dark green)
--     in decreasing radius from base to top — gives a conical pine
--     silhouette without needing a custom mesh asset.
--
-- Placement: a jittered grid spanning the world. For each candidate cell,
-- skip if inside any TerrainBuilder exclusion zone (spawn / wild / pond /
-- mountain) or near a major path. Then a probability roll decides whether
-- to place a tree there. Each placed tree raycasts down to find the
-- ground (terrain or BasePart) and sits its base on top — so trees that
-- land on hills or dirt patches don't float or sink.
--
-- The whole thing is reseeded off game.PlaceId so the same forest layout
-- recurs every session — players get a stable mental map of "the tall
-- one near the cave entrance," etc.

local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local TerrainBuilder = require(ServerScriptService.Server.TerrainBuilder)

local Trees = {}

-- Tunables ----------------------------------------------------------------

local FOREST = {
	innerRadius = 50,        -- closer than this = clearing, no trees
	outerRadius = 200,        -- further than this = world edge, no trees
	gridSpacing = 22,         -- cell size — smaller = denser
	jitterFraction = 0.6,     -- per-cell positional jitter (0..1 of cell)
	placementChance = 0.45,   -- probability a valid cell gets a tree
}

local TRUNK_COLOR = Color3.fromRGB(78, 52, 36)
local FOLIAGE_COLOR_DARK = Color3.fromRGB(38, 72, 48)
local FOLIAGE_COLOR_LIGHT = Color3.fromRGB(56, 96, 60)

-- ---------- Tree construction --------------------------------------------

local function makePineTree(scale: number, basePos: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "PineTree"

	local trunkHeight = 6 * scale
	local trunkWidth = 1.1 * scale

	local trunk = Instance.new("Part")
	trunk.Name = "Trunk"
	trunk.Anchored = true
	trunk.CanCollide = false    -- player walks through; saves pathing headaches
	trunk.CastShadow = true
	trunk.Material = Enum.Material.Wood
	trunk.Color = TRUNK_COLOR
	trunk.Size = Vector3.new(trunkWidth, trunkHeight, trunkWidth)
	trunk.Position = basePos + Vector3.new(0, trunkHeight / 2, 0)
	trunk.Parent = model
	model.PrimaryPart = trunk

	-- Foliage cones: 4 stacked cylinders, decreasing radius going up. Each
	-- layer is a vertical cylinder (Part.Shape=Cylinder rotated so its long
	-- axis points along world Y).
	local foliageStartY = basePos.Y + trunkHeight * 0.45
	local layerHeight = 2.4 * scale
	local layerOverlap = 0.35    -- fraction of layerHeight that overlaps with the next

	for i = 1, 4 do
		local layer = Instance.new("Part")
		layer.Name = "Foliage_" .. i
		layer.Anchored = true
		layer.CanCollide = false
		layer.CastShadow = true
		layer.Material = Enum.Material.Grass
		-- Slight color variation between layers for visual depth.
		layer.Color = (i % 2 == 0) and FOLIAGE_COLOR_DARK or FOLIAGE_COLOR_LIGHT
		layer.Shape = Enum.PartType.Cylinder
		local layerRadius = (4.6 - (i - 1) * 1.1) * scale
		layer.Size = Vector3.new(layerHeight, layerRadius * 2, layerRadius * 2)
		-- Cylinder default orientation has its long axis on X; rotate Z by
		-- 90° to swing that axis up to world Y.
		layer.Orientation = Vector3.new(0, 0, 90)
		local layerCenterY = foliageStartY
			+ (i - 1) * layerHeight * (1 - layerOverlap)
			+ layerHeight / 2
		layer.Position = Vector3.new(basePos.X, layerCenterY, basePos.Z)
		layer.Parent = model
	end

	return model
end

-- ---------- Placement ----------------------------------------------------

-- Paths Trees should avoid. Tree placement only — these aren't terrain
-- exclusions because the paths themselves overpaint terrain anyway.
local function nearPath(x: number, z: number): boolean
	-- Spawn → plot row (south)
	if math.abs(x) < 5 and z >= -2 and z <= 32 then return true end
	-- Spawn → cave entrance (east)
	if math.abs(z) < 5 and x >= -2 and x <= 48 then return true end
	-- Spawn → pond (west)
	if math.abs(z) < 5 and x >= -32 and x <= 2 then return true end
	-- Plot row alley
	if math.abs(z - 30) < 4 and x >= -14 and x <= 14 then return true end
	return false
end

local function canPlaceTree(x: number, z: number): boolean
	local dist = math.sqrt(x * x + z * z)
	if dist < FOREST.innerRadius or dist > FOREST.outerRadius then
		return false
	end
	if TerrainBuilder.isExcluded(x, z) then return false end
	if nearPath(x, z) then return false end
	return true
end

-- Raycast from above to find where the ground (terrain OR a BasePart)
-- is at (x, z). Returns the Y coordinate of the surface, or 0 if no hit
-- (very rare — would happen only if the world has a hole there).
local function groundHeight(x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Exclude existing trees + koi + plot models so trees ground on the
	-- terrain, not on each other.
	local excludeList = {}
	local treeFolder = Workspace:FindFirstChild("Trees")
	if treeFolder then table.insert(excludeList, treeFolder) end
	local koiFolder = Workspace:FindFirstChild("Koi")
	if koiFolder then table.insert(excludeList, koiFolder) end
	params.FilterDescendantsInstances = excludeList

	local result = Workspace:Raycast(
		Vector3.new(x, 200, z),
		Vector3.new(0, -400, 0),
		params
	)
	if result then
		return result.Position.Y
	end
	return 0
end

-- ---------- Public API ---------------------------------------------------

function Trees.spawn()
	-- Hand-built escape valve: when Workspace.HasHandBuiltTrees is true, we
	-- skip procedural placement entirely. Use this once you've populated
	-- Workspace.Trees with toolbox models you want to keep.
	if Workspace:GetAttribute("HasHandBuiltTrees") then
		return
	end

	-- Reproducible seed so the forest layout is the same every server.
	-- Different seed from TerrainBuilder so the two systems' randomness
	-- doesn't accidentally correlate.
	math.randomseed((game.PlaceId == 0 and 1 or game.PlaceId) + 999)

	local container = Workspace:FindFirstChild("Trees")
	if not container then
		container = Instance.new("Folder")
		container.Name = "Trees"
		container.Parent = Workspace
	end
	-- Only clear our own procedural trees (tagged on the model below). User-
	-- placed models in this folder are left alone, so you can drop a few
	-- toolbox trees here without them getting wiped on Play.
	for _, child in ipairs(container:GetChildren()) do
		if child:GetAttribute("IsProcedural") then
			child:Destroy()
		end
	end

	local placed = 0
	local extent = FOREST.outerRadius
	local spacing = FOREST.gridSpacing
	for cx = -extent, extent, spacing do
		for cz = -extent, extent, spacing do
			-- Per-cell jitter so the grid pattern isn't visible.
			local jx = (math.random() - 0.5) * spacing * FOREST.jitterFraction
			local jz = (math.random() - 0.5) * spacing * FOREST.jitterFraction
			local x, z = cx + jx, cz + jz

			if canPlaceTree(x, z) and math.random() < FOREST.placementChance then
				local scale = 0.7 + math.random() * 0.7    -- 0.7x to 1.4x size
				local y = groundHeight(x, z)
				local tree = makePineTree(scale, Vector3.new(x, y, z))
				tree:SetAttribute("IsProcedural", true)
				tree.Parent = container
				placed += 1
			end
		end
	end

	print(string.format("[Trees] placed %d pine trees", placed))
end

return Trees
