-- World setup. Builds the Pre-Alpha Starter Glade procedurally so the game
-- runs end-to-end with zero manual placement, but supports a per-piece
-- "hand-built mode" so you can replace pieces in Studio one at a time
-- without losing playability.
--
-- Hand-built contract — drop these into Workspace in Studio and MapSetup
-- will skip the matching procedural piece on the next server start:
--
--   Ground       Any BasePart named "Ground" in Workspace, OR set
--                Workspace:SetAttribute("HasHandBuiltGround", true) when
--                you've painted Workspace.Terrain. Either signal disables
--                the procedural grass slab. (We never touch terrain — your
--                paint is safe.)
--                NOTE: TerrainBuilder.lua runs before MapSetup.build() and
--                paints Starter Glade terrain on first run, then sets
--                HasHandBuiltGround itself. So in practice the procedural
--                grass slab is dead code unless terrain painting is
--                disabled. Kept around as a sanity backup if Terrain ever
--                fails to paint (e.g. on a future engine change).
--
--   SpawnPad     Any SpawnLocation in Workspace. (Studio's default
--                Baseplate ships one with a decorative star Decal; if
--                you want it gone, delete it manually.)
--
--   WildSpawnArea Any BasePart in Workspace named "WildSpawnArea". Should
--                be CanCollide=false and Transparency=1 (it's just an
--                invisible volume the spawner picks random points inside).
--
--   WitchStall   Any instance in Workspace named "WitchStall" containing
--                a ProximityPrompt named "SellPrompt" anywhere in its
--                descendants.
--
--   Cauldron     Any instance in Workspace named "Cauldron" containing
--                a ProximityPrompt named "BrewPrompt" anywhere in its
--                descendants.
--
--   Plots        Any instance in Workspace (or descendant) with attribute
--                isPlot=true. Each must contain ProximityPrompts named
--                "PlantPrompt" and "HarvestPrompt", and optionally the
--                visual folders "EmptyVisual"/"GrowingVisual"/"RipeVisual"
--                that Planting toggles transparency on. If ANY hand-built
--                plot exists, MapSetup skips building procedural plots
--                entirely (no mixing — keeps plot count under your control).
--
-- Coordinates of procedural pieces are clustered around the origin so a
-- default spawn point puts the player in the middle of everything.

local Workspace = game:GetService("Workspace")

local MapSetup = {}

local function makePart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- ---------- Ground -------------------------------------------------------

local function buildGround(): BasePart?
	local hand = Workspace:FindFirstChild("Ground")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	if Workspace:GetAttribute("HasHandBuiltGround") then
		return nil
	end

	-- Studio's "Baseplate" template ships with a giant grey Part named
	-- "Baseplate" at y=0. Removed only when we're about to put down our
	-- procedural Ground (no point destroying it if the user is supplying
	-- their own world).
	local default = Workspace:FindFirstChild("Baseplate")
	if default and default:IsA("BasePart") then
		default:Destroy()
	end

	local ground = makePart(
		"Ground",
		Vector3.new(400, 1, 400),
		Vector3.new(0, -0.5, 0),
		Color3.fromRGB(80, 110, 70),
		Enum.Material.Grass
	)
	ground.Parent = Workspace
	return ground
end

-- ---------- Spawn pad ----------------------------------------------------

local function buildSpawnPad(): SpawnLocation
	-- Use any SpawnLocation already in Workspace as-is.
	for _, child in ipairs(Workspace:GetChildren()) do
		if child:IsA("SpawnLocation") then
			return child
		end
	end
	local sp = Instance.new("SpawnLocation")
	sp.Name = "SpawnPad"
	sp.Size = Vector3.new(8, 1, 8)
	sp.Position = Vector3.new(0, 1, 0)
	sp.Anchored = true
	sp.Neutral = true
	sp.AllowTeamChangeOnTouch = false
	sp.Color = Color3.fromRGB(135, 95, 60)
	sp.Material = Enum.Material.Wood
	sp.Parent = Workspace
	-- Belt-and-suspenders: kill any auto-added Decal/Texture children that
	-- some Studio versions parent to a fresh SpawnLocation.
	for _, child in ipairs(sp:GetChildren()) do
		if child:IsA("Decal") or child:IsA("Texture") then
			child:Destroy()
		end
	end
	return sp
end

-- ---------- Wild spawn area ----------------------------------------------

local function buildWildSpawnArea(): BasePart
	local hand = Workspace:FindFirstChild("WildSpawnArea")
	if hand and hand:IsA("BasePart") then
		return hand
	end
	-- Invisible volume that WildSpawn picks random points inside. Anchored
	-- and non-collidable; mushrooms spawn on its bottom face.
	local area = makePart(
		"WildSpawnArea",
		Vector3.new(60, 4, 60),
		Vector3.new(0, 2, -50),
		Color3.fromRGB(255, 255, 255),
		Enum.Material.SmoothPlastic
	)
	area.Transparency = 1
	area.CanCollide = false
	area.Parent = Workspace
	return area
end

-- ---------- Witch stall --------------------------------------------------

local function buildWitchStall()
	if Workspace:FindFirstChild("WitchStall") then
		return    -- using hand-built (the user's responsibility to add a SellPrompt)
	end
	-- Stand-in for the Forest Witch NPC. Replace with a real character
	-- model in a later milestone. Lives inside the cave chamber that
	-- TerrainBuilder carves into the mountain at (90, _, 0).
	local stall = makePart(
		"WitchStall",
		Vector3.new(4, 4, 4),
		Vector3.new(85, 2, -5),
		Color3.fromRGB(120, 60, 140),
		Enum.Material.Wood
	)
	stall.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SellPrompt"
	prompt.ActionText = "Sell mushrooms"
	prompt.ObjectText = "Forest Witch"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = stall
end

-- ---------- Cauldron ------------------------------------------------------

local function buildCauldron()
	if Workspace:FindFirstChild("Cauldron") then
		return    -- using hand-built (the user's responsibility to add a BrewPrompt)
	end
	-- The cauldron is a small two-part Model: a dark base plus a deep-
	-- purple "liquid" disk on top. Sits a few studs from the witch stall.
	local cauldron = Instance.new("Model")
	cauldron.Name = "Cauldron"

	local base = makePart(
		"Base",
		Vector3.new(3, 2.5, 3),
		Vector3.new(92, 1.25, 4),
		Color3.fromRGB(40, 30, 35),
		Enum.Material.Slate
	)
	base.Shape = Enum.PartType.Cylinder
	-- A horizontal cylinder needs to be rotated to stand on its end.
	base.Orientation = Vector3.new(0, 0, 90)
	base.Parent = cauldron
	cauldron.PrimaryPart = base

	local liquid = makePart(
		"Liquid",
		Vector3.new(0.2, 2.6, 2.6),
		Vector3.new(92, 2.5, 4),
		Color3.fromRGB(90, 50, 130),
		Enum.Material.Neon
	)
	liquid.Shape = Enum.PartType.Cylinder
	liquid.Orientation = Vector3.new(0, 0, 90)
	liquid.Transparency = 0.15
	liquid.Parent = cauldron

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BrewPrompt"
	prompt.ActionText = "Brew"
	prompt.ObjectText = "Cauldron"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	cauldron.Parent = Workspace
end

-- ---------- Plots --------------------------------------------------------

local function findHandBuiltPlots(): { Instance }
	local found = {}
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:GetAttribute("isPlot") then
			table.insert(found, descendant)
		end
	end
	return found
end

-- Build a single plot at the given position. Returns the Model so
-- Planting.registerPlot can hook it.
local function buildPlot(position: Vector3, name: string): Model
	local plot = Instance.new("Model")
	plot.Name = name

	-- Soil base.
	local soil = makePart(
		"Soil",
		Vector3.new(4, 0.4, 4),
		position,
		Color3.fromRGB(80, 55, 40),
		Enum.Material.Ground
	)
	soil.Parent = plot
	plot.PrimaryPart = soil

	-- Visuals (toggled by Planting).
	local emptyVisual = Instance.new("Folder")
	emptyVisual.Name = "EmptyVisual"
	emptyVisual.Parent = plot
	-- Empty looks like bare soil, no extra decoration needed; folder kept
	-- for symmetry so Planting can tweak transparency uniformly.

	local growingVisual = Instance.new("Folder")
	growingVisual.Name = "GrowingVisual"
	growingVisual.Parent = plot
	local sprout = makePart(
		"Sprout",
		Vector3.new(0.5, 0.6, 0.5),
		position + Vector3.new(0, 0.5, 0),
		Color3.fromRGB(120, 180, 90),
		Enum.Material.SmoothPlastic
	)
	sprout.Transparency = 1   -- hidden by default; Planting reveals
	sprout.Parent = growingVisual

	local ripeVisual = Instance.new("Folder")
	ripeVisual.Name = "RipeVisual"
	ripeVisual.Parent = plot
	local stem = makePart(
		"Stem",
		Vector3.new(0.5, 1, 0.5),
		position + Vector3.new(0, 0.7, 0),
		Color3.fromRGB(220, 210, 180),
		Enum.Material.SmoothPlastic
	)
	stem.Transparency = 1
	stem.Parent = ripeVisual
	local cap = Instance.new("Part")
	cap.Name = "Cap"
	cap.Shape = Enum.PartType.Ball
	cap.Size = Vector3.new(1.4, 1.4, 1.4)
	cap.Position = position + Vector3.new(0, 1.4, 0)
	cap.Color = Color3.fromRGB(180, 80, 70)
	cap.Material = Enum.Material.SmoothPlastic
	cap.Anchored = true
	cap.CanCollide = false
	cap.Transparency = 1
	cap.Parent = ripeVisual

	-- Prompts (Plant always present, Harvest enabled when ripe).
	local plant = Instance.new("ProximityPrompt")
	plant.Name = "PlantPrompt"
	plant.ActionText = "Plant"
	plant.ObjectText = "Spore Patch"
	plant.HoldDuration = 0
	plant.MaxActivationDistance = 8
	plant.RequiresLineOfSight = false
	plant.Parent = soil

	local harvest = Instance.new("ProximityPrompt")
	harvest.Name = "HarvestPrompt"
	harvest.ActionText = "Harvest"
	harvest.HoldDuration = 0
	harvest.MaxActivationDistance = 8
	harvest.RequiresLineOfSight = false
	harvest.Parent = soil

	plot:SetAttribute("isPlot", true)
	plot.Parent = Workspace
	return plot
end

local function buildPlots(count: number): { Instance }
	-- Hand-built wins outright (no mixing). If the user has placed any
	-- isPlot=true instances, we use those and skip the procedural row.
	local handBuilt = findHandBuiltPlots()
	if #handBuilt > 0 then
		return handBuilt
	end
	local plots = {}
	local spacing = 7
	for i = 1, count do
		local x = -((count - 1) / 2) * spacing + (i - 1) * spacing
		local plot = buildPlot(Vector3.new(x, 0.2, 30), "Plot_" .. i)
		table.insert(plots, plot)
	end
	return plots
end

-- Public API ------------------------------------------------------------------

function MapSetup.build(plotCount: number): { wildSpawnArea: BasePart, plots: { Instance } }
	buildGround()
	buildSpawnPad()
	buildWitchStall()
	buildCauldron()
	local wildSpawnArea = buildWildSpawnArea()
	local plots = buildPlots(plotCount)
	return { wildSpawnArea = wildSpawnArea, plots = plots }
end

return MapSetup
