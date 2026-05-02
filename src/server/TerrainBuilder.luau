-- Paints the Starter Glade into Workspace.Terrain on server start.
--
-- Idempotency: same as before — Workspace:GetAttribute("HasHandBuiltGround")
-- is the manual-paint escape valve, and TerrainBuilder also sets it after
-- painting so MapSetup skips the procedural grass slab. Because terrain
-- (and attributes) reset between unsaved Studio play sessions, every fresh
-- Play repaints; saved places persist both terrain and the flag, so the
-- repaint becomes a no-op there.
--
-- World layout (must stay walkable / placeable):
--   SpawnPad ........ (0,    1, 0)
--   Spawn area ...... 25-stud radius around origin, painted Ground
--   Pond ............ centred at (-50, _, 0), radius 22 (west of spawn)
--   Plot row ........ x in [-10.5, 10.5], z = 30 (south of spawn)
--   WildSpawnArea ... centred at (0, 2, -50), 60x60 footprint (north)
--   Mountain ........ centred at (90, _, 0), base radius 45, height ~65
--   Cave tunnel ..... from x=45 to x=80, width 10, height 9, z=0
--   Cave chamber .... centred at (90, _, 0), 25 wide x 12 tall x 25 deep
--   WitchStall ...... inside cave chamber at (~85, 2, -5)
--   Cauldron ........ inside cave chamber at (~92, _, 4)
--
-- Player narrative path: spawn (dirt fantasy clearing) → east on the path
-- → through the cave entrance at the base of the mountain → into the
-- chamber where the witch sells and the cauldron brews. The pond is a
-- side attraction visible from spawn, koi swimming inside.

local Workspace = game:GetService("Workspace")

local TerrainBuilder = {}

local terrain = Workspace.Terrain

-- ---------- Helpers ------------------------------------------------------

local function block(centerX: number, centerY: number, centerZ: number, sizeX: number, sizeY: number, sizeZ: number, material: Enum.Material)
	terrain:FillBlock(
		CFrame.new(centerX, centerY, centerZ),
		Vector3.new(sizeX, sizeY, sizeZ),
		material
	)
end

local function ball(x: number, y: number, z: number, radius: number, material: Enum.Material)
	terrain:FillBall(Vector3.new(x, y, z), radius, material)
end

local function cylinder(x: number, y: number, z: number, height: number, radius: number, material: Enum.Material)
	terrain:FillCylinder(CFrame.new(x, y, z), height, radius, material)
end

-- Place a hemisphere of `material` whose top sits at exactly y = peakHeight.
local function dome(x: number, z: number, radius: number, peakHeight: number, material: Enum.Material)
	ball(x, peakHeight - radius, z, radius, material)
end

-- ---------- Base ---------------------------------------------------------

local MAP_HALF = 250
local DEPTH = 40

local function paintBase()
	block(0, -DEPTH / 2, 0, MAP_HALF * 2, DEPTH, MAP_HALF * 2, Enum.Material.Grass)
end

-- ---------- Exclusion zones ---------------------------------------------
--
-- Several regions need to stay clear of decorative features (hills, rocks,
-- dirt, leafy patches). The wild-mushroom field, the pond bowl, the spawn
-- clearing, and the mountain footprint all paint themselves cleanly and
-- don't want noise on top.

local WILD_AREA = { centerX = 0, centerZ = -50, halfX = 40, halfZ = 40 }

local function inWildArea(x: number, z: number): boolean
	return math.abs(x - WILD_AREA.centerX) < WILD_AREA.halfX
		and math.abs(z - WILD_AREA.centerZ) < WILD_AREA.halfZ
end

local SPAWN_AREA = { centerX = 0, centerZ = 0, radius = 30 }

local function inSpawnArea(x: number, z: number): boolean
	local dx = x - SPAWN_AREA.centerX
	local dz = z - SPAWN_AREA.centerZ
	return (dx * dx + dz * dz) < (SPAWN_AREA.radius * SPAWN_AREA.radius)
end

-- Pond geometry (also referenced by Koi.lua via TerrainBuilder.POND below).
local POND_EXCLUSION = { centerX = -50, centerZ = 0, radius = 28 }    -- pond r=22 + 6 buffer

local function inPondArea(x: number, z: number): boolean
	local dx = x - POND_EXCLUSION.centerX
	local dz = z - POND_EXCLUSION.centerZ
	return (dx * dx + dz * dz) < (POND_EXCLUSION.radius * POND_EXCLUSION.radius)
end

-- Mountain geometry: base of cone at the world surface. Block hills and
-- rock outcrops within the base footprint plus a small skirt so the
-- mountain reads as the dominant feature in its area.
local MOUNTAIN_EXCLUSION = { centerX = 90, centerZ = 0, radius = 55 }    -- mountain base 45 + 10 skirt

local function inMountainArea(x: number, z: number): boolean
	local dx = x - MOUNTAIN_EXCLUSION.centerX
	local dz = z - MOUNTAIN_EXCLUSION.centerZ
	return (dx * dx + dz * dz) < (MOUNTAIN_EXCLUSION.radius * MOUNTAIN_EXCLUSION.radius)
end

local function isExcluded(x: number, z: number): boolean
	return inWildArea(x, z)
		or inSpawnArea(x, z)
		or inPondArea(x, z)
		or inMountainArea(x, z)
end

-- Public re-export so other modules (e.g. Trees.lua) can avoid the same
-- footprints as the procedural terrain features.
TerrainBuilder.isExcluded = isExcluded

-- ---------- Leafy patches -----------------------------------------------

local LEAFY_PATCHES = {
	{ x = -22, z = -12 },
	{ x = 14,  z = 16  },
	{ x = -32, z = 24  },
	{ x = 36,  z = -28 },
	{ x = 4,   z = -68 },
	{ x = -42, z = -52 },
	{ x = 28,  z = -58 },
	{ x = 0,   z = 42  },
	{ x = -8,  z = -38 },
	{ x = 22,  z = 38  },
}

local function paintLeafyPatch(cx: number, cz: number)
	-- Main blob, sunk so only the top scoop shows.
	ball(cx, -2, cz, 8 + math.random() * 3, Enum.Material.LeafyGrass)
	-- Two satellites for an irregular outline.
	for _ = 1, 2 do
		local dx = (math.random() * 2 - 1) * 6
		local dz = (math.random() * 2 - 1) * 6
		ball(cx + dx, -2, cz + dz, 4 + math.random() * 3, Enum.Material.LeafyGrass)
	end
end

local function paintLeafyPatches()
	for _, p in ipairs(LEAFY_PATCHES) do
		if not isExcluded(p.x, p.z) then
			paintLeafyPatch(p.x, p.z)
		end
	end
end

-- ---------- Hills (heightmap via Perlin noise) ---------------------------

-- Walk a grid covering the map's perimeter, sample multi-octave Perlin noise
-- at each cell, and FillBlock a column up to that height. The result is
-- continuous, organic terrain instead of stacked-sphere artifacts. The
-- play area inside PLAY_RADIUS stays flat at y=0; a smoothstep ramp over
-- TRANSITION studs blends the edge so there's no cliff where hills start.
--
-- Cells are 8 studs wide (Roblox terrain voxels are 4 studs; 8 keeps the
-- count manageable while still looking smooth after the engine's voxel
-- smoothing). At ±240 studs that's about 60×60 = 3600 cells, of which
-- maybe half end up tall enough to fill — a few thousand FillBlock calls
-- on server start, well within Roblox's tolerance.
local HEIGHTMAP = {
	step = 8,
	playRadius = 75,    -- inside this, no hills
	transition = 35,    -- soft ramp over 35 studs
	maxHeight = 36,     -- tallest possible peak
	bias = 0.25,        -- positive bias so most cells get *some* height
}

local function sampleHeight(x: number, z: number): number
	-- Multi-octave Perlin: low-freq big shapes + high-freq detail.
	local n = 0
	n = n + math.noise(x * 0.006, z * 0.006, 7)  * 1.0
	n = n + math.noise(x * 0.018, z * 0.018, 13) * 0.4
	n = n + math.noise(x * 0.05,  z * 0.05,  23) * 0.15
	return n
end

local function materialForHeight(x: number, z: number, height: number): Enum.Material
	if height > 28 then
		-- Tallest peaks: rare CrackedLava glints (glowing magma veins) on
		-- top of the standard Slate/Rock mix. ~10% chance per cell where
		-- the noise sample is high enough — sparse, doesn't dominate.
		local glow = math.noise(x * 0.07, z * 0.07, 53)
		if glow > 0.35 then
			return Enum.Material.CrackedLava
		end
		return (math.noise(x * 0.04, z * 0.04, 31) > 0.05)
			and Enum.Material.Slate
			or Enum.Material.Rock
	elseif height > 14 then
		-- Mid elevation: bare ground / grass with occasional Sandstone
		-- weathered patches for warmer fantasy color.
		local sand = math.noise(x * 0.025, z * 0.025, 47)
		if sand > 0.25 then
			return Enum.Material.Sandstone
		end
		return (math.noise(x * 0.03, z * 0.03, 41) > 0.15)
			and Enum.Material.Ground
			or Enum.Material.Grass
	else
		return Enum.Material.Grass
	end
end

local function paintHills()
	local step = HEIGHTMAP.step
	local extent = MAP_HALF - step
	for x = -extent, extent, step do
		for z = -extent, extent, step do
			local dist = math.sqrt(x * x + z * z)
			if dist < HEIGHTMAP.playRadius then
				continue
			end
			-- Wild-mushroom area + pond stay flat even where they would
			-- otherwise catch the hill ramp's edge.
			if isExcluded(x, z) then
				continue
			end

			-- Smoothstep ramp from 0 (at playRadius) to 1 (further out).
			local t = math.clamp(
				(dist - HEIGHTMAP.playRadius) / HEIGHTMAP.transition,
				0,
				1
			)
			local rim = t * t * (3 - 2 * t)

			local n = sampleHeight(x, z)
			local height = math.max(0, (n + HEIGHTMAP.bias) * HEIGHTMAP.maxHeight * rim)

			if height < 1 then
				continue
			end

			local mat = materialForHeight(x, z, height)
			block(x, height / 2, z, step, height, step, mat)
		end
	end
end

-- ---------- Rock outcrops -----------------------------------------------

local OUTCROPS = {
	{ x = -25, z = -88,  base = 6, m = Enum.Material.Rock },
	{ x = 32,  z = -92,  base = 5, m = Enum.Material.Slate },
	{ x = -55, z = -78,  base = 7, m = Enum.Material.Rock },
	{ x = 55,  z = -82,  base = 6, m = Enum.Material.Rock },
	{ x = -70, z = -10,  base = 5, m = Enum.Material.Slate },
	{ x = -68, z = 30,   base = 4, m = Enum.Material.Rock },
	{ x = 68,  z = 22,   base = 5, m = Enum.Material.Slate },
	{ x = 0,   z = -100, base = 6, m = Enum.Material.Rock },
}

local function paintOutcrop(cx: number, cz: number, baseRadius: number, material: Enum.Material)
	-- Largest boulder at the base.
	dome(cx, cz, baseRadius, baseRadius * 0.6, material)
	-- 1-3 stacked smaller boulders, each offset slightly.
	local stack = math.random(1, 3)
	for i = 1, stack do
		local r = baseRadius * (0.7 - i * 0.15)
		if r < 1.5 then
			break
		end
		local angle = math.random() * math.pi * 2
		local off = baseRadius * 0.3
		dome(
			cx + math.cos(angle) * off,
			cz + math.sin(angle) * off,
			r,
			baseRadius * 0.6 + i * (baseRadius * 0.4),
			material
		)
	end
end

local function paintRockOutcrops()
	for _, r in ipairs(OUTCROPS) do
		if not isExcluded(r.x, r.z) then
			paintOutcrop(r.x, r.z, r.base, r.m)
		end
	end
end

-- ---------- Pond ---------------------------------------------------------
--
-- Sits west of the spawn pad. Visible from spawn as a side attraction;
-- koi swim inside (Koi.lua reads center + radius from TerrainBuilder.POND).
-- Don't rename POND without grepping.

TerrainBuilder.POND = {
	centerX = -50,      -- west of spawn (mountain takes the east side)
	centerZ = 0,
	radius = 22,        -- shoreline radius (irregular; this is the "average")
	surfaceY = -0.5,    -- top of the water layer (matches surrounding ground)
	bottomY = -8,       -- mud bed depth
}

local function paintPond()
	local p = TerrainBuilder.POND
	local px, pz, r = p.centerX, p.centerZ, p.radius
	-- Cylindrical carve so the rim stays flat with surrounding terrain.
	-- (Spheres curve up and create mounds above ground.) The irregular
	-- outline comes from per-angle jittered sandstone balls below, not
	-- from asymmetric carve cylinders — that approach in earlier passes
	-- left dry exposed terrain in the lobes.
	local bowlHeight = p.surfaceY - p.bottomY
	local bowlCenterY = (p.surfaceY + p.bottomY) / 2

	-- 1. Carve a single circular bowl.
	cylinder(px, bowlCenterY, pz, bowlHeight, r, Enum.Material.Air)

	-- 2. Mud bed at the bottom — thin cylinder so it doesn't mound up.
	cylinder(px, p.bottomY + 0.75, pz, 1.5, r, Enum.Material.Mud)

	-- 3. Water layer filling the bowl up to surfaceY. Inset by 0.5 studs
	-- so the very edge of the carve stays as a thin grass lip under the
	-- sandstone rim.
	local waterCenterY = (p.surfaceY + p.bottomY + 1.5) / 2
	local waterHeight = p.surfaceY - (p.bottomY + 1.5)
	cylinder(px, waterCenterY, pz, waterHeight, r - 0.5, Enum.Material.Water)

	-- 4. Sandstone shoreline ring all the way around. Each ball's distance
	-- from center is jittered via Perlin noise so the outline isn't a
	-- perfect circle. Sits just below ground level — peeks through as a
	-- sandy beach without towering above the water.
	for i = 1, 24 do
		local angle = (i / 24) * math.pi * 2
		local jitter = math.noise(math.cos(angle) * 2, math.sin(angle) * 2, 23) * 1.8
		local edgeR = r - 0.3 + jitter
		ball(
			px + math.cos(angle) * edgeR,
			-1.5,
			pz + math.sin(angle) * edgeR,
			2.5,
			Enum.Material.Sandstone
		)
	end

	-- 5. A few lily-pad-style small leafy patches floating at the surface.
	for _ = 1, 5 do
		local angle = math.random() * math.pi * 2
		local dist = (r - 6) * math.random()
		ball(
			px + math.cos(angle) * dist,
			p.surfaceY,
			pz + math.sin(angle) * dist,
			1.5,
			Enum.Material.LeafyGrass
		)
	end
end

-- ---------- Spawn area --------------------------------------------------
--
-- The starting clearing is intentionally NOT grass — the player spawns on
-- packed earth with sandstone weathering and a couple of CrackedLava glints
-- to set the fantasy tone. Painted on top of the grass base inside a
-- cylinder centered on the spawn pad.

local function paintSpawnArea()
	local s = SPAWN_AREA
	-- 1. Solid Ground floor across the clearing. Thin (1.5 studs) and
	-- centered just below the surface so the surrounding grass blends in.
	cylinder(s.centerX, -0.75, s.centerZ, 1.5, s.radius, Enum.Material.Ground)

	-- 2. Sandstone weathering patches. Distributed around the clearing
	-- via Perlin noise so the same place ID always lays them in the same
	-- spots.
	for i = 1, 7 do
		local angle = (i / 7) * math.pi * 2
		local r = s.radius * 0.55
		local jx = math.noise(angle * 1.3, 0, 11) * 4
		local jz = math.noise(angle * 1.3, 1, 13) * 4
		ball(
			s.centerX + math.cos(angle) * r + jx,
			-1,
			s.centerZ + math.sin(angle) * r + jz,
			3.5,
			Enum.Material.Sandstone
		)
	end

	-- 3. Mossy LeafyGrass patches scattered around the clearing for cozy
	-- fantasy texture. (Earlier iteration used CrackedLava here but the
	-- glowing magma read as too aggressive against a mushroom-forest theme.)
	for i = 1, 4 do
		local angle = (i / 4) * math.pi * 2 + 0.4
		local r = s.radius * 0.7
		ball(
			s.centerX + math.cos(angle) * r,
			-0.5,
			s.centerZ + math.sin(angle) * r,
			1.8,
			Enum.Material.LeafyGrass
		)
	end
end

-- ---------- Mountain ----------------------------------------------------
--
-- A tall mossy peak east of the spawn area, hollowed out by paintCave to
-- house the witch's chamber. Stacks vertical cylinders from base to peak
-- with per-stack radius jitter so the silhouette isn't a perfect cone.
--
-- Material palette is intentionally warm + mossy to fit Mycelia's cozy
-- fantasy theme — no Rock/Slate/Glacier (those read as cold RPG mountain).
-- Mossy LeafyGrass at the base blends into Sandstone slopes, then lighter
-- Limestone toward the peak.

local MOUNTAIN = {
	centerX = 90,
	centerZ = 0,
	baseRadius = 48,
	peakRadius = 6,
	totalHeight = 65,
	stackHeight = 4,     -- finer stacks = smoother slope
	jitterStuds = 3,     -- ±3-stud per-stack radius variation
}

local function mountainMaterial(t: number): Enum.Material
	-- t = 0 (base) to 1 (peak).
	if t < 0.18 then
		return Enum.Material.LeafyGrass    -- mossy overgrown base
	elseif t < 0.36 then
		return Enum.Material.Grass         -- grassy lower slopes
	elseif t < 0.72 then
		return Enum.Material.Sandstone     -- warm beige middle
	else
		return Enum.Material.Limestone     -- lighter cream peak
	end
end

local function paintMountain()
	local m = MOUNTAIN
	local stackCount = math.ceil(m.totalHeight / m.stackHeight)
	for i = 0, stackCount - 1 do
		local t = i / (stackCount - 1)
		local linearR = m.baseRadius + (m.peakRadius - m.baseRadius) * t
		-- Noise-driven jitter so the silhouette wavers organically rather
		-- than tapering on a perfect line.
		local jitter = math.noise(t * 4, 0, 71) * m.jitterStuds
		local radius = math.max(m.peakRadius, linearR + jitter)
		local centerY = i * m.stackHeight + m.stackHeight / 2
		cylinder(
			m.centerX, centerY, m.centerZ,
			m.stackHeight, radius,
			mountainMaterial(t)
		)
	end

	-- Surface bumps: a handful of randomly-placed boulders bulging out of
	-- the slope for silhouette variety. Skip the western 120° cone (angles
	-- where cos < -0.5) so we don't bury the cave entrance.
	for i = 1, 8 do
		local angle = (i / 8) * math.pi * 2
		if math.cos(angle) < -0.5 then
			continue
		end
		local heightRatio = 0.15 + math.random() * 0.55
		local h = heightRatio * m.totalHeight
		local linearR = m.baseRadius + (m.peakRadius - m.baseRadius) * heightRatio
		local sphereR = 4 + math.random() * 3
		ball(
			m.centerX + math.cos(angle) * linearR,
			h,
			m.centerZ + math.sin(angle) * linearR,
			sphereR,
			mountainMaterial(heightRatio)
		)
	end
end

-- ---------- Cave (tunnel + chamber carved into the mountain) ------------
--
-- The cave is two air pockets carved out of the mountain after it's built:
-- a horizontal tunnel running west-to-east through the mountain's flank,
-- and a wider chamber at the far end where the witch sells and the
-- cauldron brews.
--
-- Floor sits at y=0 to match the surrounding ground (so the player can
-- walk straight in without stepping up). After carving, we paint a thin
-- layer of Ground at y=-0.5 inside the cave footprint so the floor reads
-- as packed dirt rather than the underlying grass.

local CAVE = {
	tunnelStartX = 45,        -- entrance just at mountain edge
	tunnelEndX = 80,          -- merges into chamber
	tunnelWidth = 11,         -- z-axis (slightly wide for arch feel)
	tunnelHeight = 9,
	chamberCenterX = 90,
	chamberCenterZ = 0,
	chamberRadius = 14,       -- round chamber footprint
	chamberHeight = 12,
}

local function paintCave()
	local c = CAVE
	local tunnelLength = c.tunnelEndX - c.tunnelStartX
	local tunnelCenterX = (c.tunnelStartX + c.tunnelEndX) / 2

	-- 1. Tunnel body: rectangular air block.
	block(
		tunnelCenterX, c.tunnelHeight / 2, 0,
		tunnelLength, c.tunnelHeight, c.tunnelWidth,
		Enum.Material.Air
	)

	-- 2. Sphere caps at each end of the tunnel — rounds out the entrance
	-- arch and the tunnel→chamber transition (no harsh box corners).
	ball(c.tunnelStartX, c.tunnelHeight / 2, 0, c.tunnelWidth / 2, Enum.Material.Air)
	ball(c.tunnelEndX, c.tunnelHeight / 2, 0, c.tunnelWidth / 2, Enum.Material.Air)

	-- 3. Chamber: vertical cylinder for a round footprint. Plus a small
	-- side cylinder for an irregular alcove on one wall (the witch's
	-- "back room" feel — not symmetrical).
	cylinder(
		c.chamberCenterX, c.chamberHeight / 2, c.chamberCenterZ,
		c.chamberHeight, c.chamberRadius,
		Enum.Material.Air
	)
	cylinder(
		c.chamberCenterX + 6, c.chamberHeight / 2, c.chamberCenterZ + 8,
		c.chamberHeight, 6,
		Enum.Material.Air
	)

	-- 4. Cave floor: thin Ground slab so the floor reads as packed dirt
	-- consistent with the spawn clearing, not grass or the underlying
	-- mountain rock. Cylinder for the chamber, block for the tunnel.
	cylinder(
		c.chamberCenterX, -0.5, c.chamberCenterZ,
		1, c.chamberRadius + 2,
		Enum.Material.Ground
	)
	block(
		tunnelCenterX, -0.5, 0,
		tunnelLength + 4, 1, c.tunnelWidth + 2,
		Enum.Material.Ground
	)

	-- 5. Cave entrance overgrowth: LeafyGrass mossy patches around the
	-- tunnel mouth so the entrance reads as nature reclaiming the rock,
	-- not a manufactured tunnel. Placed just outside the mountain face.
	for offset = -5, 5, 2 do
		if offset ~= 0 then
			ball(c.tunnelStartX - 2, 0, offset, 2.2, Enum.Material.LeafyGrass)
		end
	end
	-- A pair of moss humps on top of the entrance arch.
	ball(c.tunnelStartX - 1, c.tunnelHeight + 1, -3, 2.5, Enum.Material.LeafyGrass)
	ball(c.tunnelStartX - 1, c.tunnelHeight + 1,  3, 2.5, Enum.Material.LeafyGrass)
end

-- ---------- Paths --------------------------------------------------------

local function paintPath(startX: number, startZ: number, endX: number, endZ: number, width: number)
	local dx = endX - startX
	local dz = endZ - startZ
	local distance = math.sqrt(dx * dx + dz * dz)
	local steps = math.max(1, math.ceil(distance / (width * 0.6)))
	for i = 0, steps do
		local t = i / steps
		local x = startX + dx * t
		local z = startZ + dz * t
		-- Subtle wiggle so the path isn't perfectly straight.
		local wiggle = math.sin(t * math.pi * 3) * width * 0.4
		local perpX, perpZ = -dz / distance, dx / distance
		x = x + perpX * wiggle
		z = z + perpZ * wiggle
		-- Top of ball sits exactly at y=0 -- a worn dirt strip flush with
		-- the surrounding grass.
		ball(x, -width, z, width, Enum.Material.Ground)
	end
end

local function paintPaths()
	paintPath(0, 0, 0, 28, 3)          -- spawn -> plot row
	paintPath(-12, 30, 12, 30, 2)      -- along plot row
	paintPath(0, 0, 45, 0, 3)          -- spawn -> cave entrance
	paintPath(0, 0, -28, 0, 2.5)       -- spawn -> pond approach
end

-- ---------- Dirt + mud patches ------------------------------------------

local DIRT_PATCHES = {
	{ x = -25, z = 5,   r = 4, m = Enum.Material.Ground },
	{ x = 18,  z = -22, r = 3, m = Enum.Material.Ground },
	{ x = -38, z = -38, r = 5, m = Enum.Material.Mud },
	{ x = 42,  z = 8,   r = 3, m = Enum.Material.Ground },
	{ x = -12, z = 18,  r = 2, m = Enum.Material.Ground },
	{ x = 8,   z = -50, r = 4, m = Enum.Material.Mud },
	{ x = -45, z = 0,   r = 3, m = Enum.Material.Mud },
	{ x = -48, z = 20,  r = 3, m = Enum.Material.Mud },
}

local function paintDirtPatches()
	for _, p in ipairs(DIRT_PATCHES) do
		if not isExcluded(p.x, p.z) then
			ball(p.x, -2, p.z, p.r, p.m)
		end
	end
end

-- ---------- Public API ---------------------------------------------------

function TerrainBuilder.build()
	-- Always nuke Studio's default Baseplate Part. It sits at y=0 with a
	-- grey tiled top face; if we leave it intact and then carve into the
	-- terrain (e.g. the pond bowl), the Baseplate's tiled surface shows
	-- through wherever the carve goes below y=0. Destroying it
	-- unconditionally costs nothing when there's nothing to destroy.
	local default = Workspace:FindFirstChild("Baseplate")
	if default and default:IsA("BasePart") then
		default:Destroy()
	end

	if Workspace:GetAttribute("HasHandBuiltGround") then
		return
	end

	-- Seed math.random off the place ID so every server gets the same
	-- procedurally-jittered terrain (no jarring per-Play differences).
	math.randomseed(game.PlaceId == 0 and 1 or game.PlaceId)

	-- Order matters:
	--   1. Base grass slab everywhere.
	--   2. Spawn clearing overpaints the base with Ground + fantasy patches.
	--   3. Decorative scatter (leafy, dirt) — exclusion zones keep them out
	--      of spawn / wild / pond / mountain footprints.
	--   4. Hills (perimeter heightmap) and rock outcrops.
	--   5. Pond (carve+fill).
	--   6. Mountain (stacked rock cylinders) — must come before cave so the
	--      carve has rock to remove.
	--   7. Cave (carve tunnel + chamber out of the mountain, lay dirt floor).
	--   8. Paths painted last so they sit on top of any other features they
	--      cross.
	paintBase()
	paintSpawnArea()
	paintLeafyPatches()
	paintDirtPatches()
	paintHills()
	paintRockOutcrops()
	paintPond()
	paintMountain()
	paintCave()
	paintPaths()

	Workspace:SetAttribute("HasHandBuiltGround", true)
end

return TerrainBuilder
