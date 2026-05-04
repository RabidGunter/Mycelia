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
--   WitchStall   Any BasePart in Workspace named "WitchStall" with the
--                attribute `merchantId = "ForestWitch"` and a ProximityPrompt
--                anywhere in its descendants. Shop.luau dispatches by the
--                merchantId attribute, not the prompt name, so the prompt
--                can be named anything.
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
	local existing = Workspace:FindFirstChild("WitchStall")
	if existing and existing:IsA("BasePart") then
		-- Hand-built: respect the user's prompt setup but ensure the dialogue
		-- attribute is stamped so Dialogue.luau can route prompt triggers.
		-- Strip any legacy merchantId stamp from earlier handoffs — the witch
		-- now goes through dialogue, which has its own "Sell" response.
		if existing:GetAttribute("dialogueId") == nil then
			existing:SetAttribute("dialogueId", "ForestWitch")
		end
		if existing:GetAttribute("merchantId") ~= nil then
			existing:SetAttribute("merchantId", nil)
		end
		return
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
	-- Phase 2 dialogue: the witch greets the player before opening the shop.
	-- The "Sell mushrooms" response in Dialogues.ForestWitch routes to
	-- OpenShop with npcId="ForestWitch".
	stall:SetAttribute("dialogueId", "ForestWitch")
	stall.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DialoguePrompt"
	prompt.ActionText = "Talk to Witch"
	prompt.ObjectText = "Forest Witch"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = stall
end

-- ---------- Secondary merchants -----------------------------------------
-- Phase 2 Shop UI added Substrate Dealer + Spore Merchant. They live near
-- the spawn pad so the tutorial path naturally walks past them. Both share
-- the same anchor pattern as the witch stall: BasePart with merchantId
-- attribute + ProximityPrompt. Shop.luau dispatches by attribute, so these
-- prompts can be named anything; we use generic "ShopPrompt" for symmetry.

local function buildMerchantStall(name: string, merchantId: string, position: Vector3, color: Color3, actionText: string, objectText: string)
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		if existing:GetAttribute("merchantId") == nil then
			existing:SetAttribute("merchantId", merchantId)
		end
		return existing
	end
	local stall = makePart(name, Vector3.new(3, 3, 3), position, color, Enum.Material.Wood)
	stall:SetAttribute("merchantId", merchantId)
	stall.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ShopPrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = stall
	return stall
end

local function buildSubstrateDealer()
	-- Brown crate near spawn for the substrate dealer. Wood + warm earth tone
	-- nods to the cottagecore palette; visual upgrade to a real NPC model
	-- happens in a future polish pass.
	buildMerchantStall(
		"SubstrateDealerStall",
		"SubstrateDealer",
		Vector3.new(15, 2.5, -8),
		Color3.fromRGB(110, 80, 55),
		"Talk to Dealer",
		"Substrate Dealer"
	)
end

local function buildSporeMerchant()
	-- Mossy green box for the spore merchant. Visual hook = "this person sells
	-- mushroom things." Same pattern as substrate dealer.
	buildMerchantStall(
		"SporeMerchantStall",
		"SporeMerchant",
		Vector3.new(-12, 2.5, -8),
		Color3.fromRGB(85, 115, 70),
		"Talk to Merchant",
		"Spore Merchant"
	)
end

-- Generic dialogue-only NPC builder. Same anchor-Part-plus-prompt pattern
-- as merchants but tagged with `dialogueId` instead of `merchantId` so
-- Dialogue.luau handles the prompt trigger.
local function buildDialogueNpc(name, dialogueId, position, color, actionText, objectText)
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		if existing:GetAttribute("dialogueId") == nil then
			existing:SetAttribute("dialogueId", dialogueId)
		end
		return existing
	end
	local anchor = makePart(name, Vector3.new(2.5, 5, 2.5), position, color, Enum.Material.SmoothPlastic)
	anchor:SetAttribute("dialogueId", dialogueId)
	anchor.Parent = Workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DialoguePrompt"
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	return anchor
end

-- Phase 2 Gardener Coach — the tutorial guide. Hands out the 5-quest
-- tutorial sequence via the dialogue system. Anchored on the spawn pad's
-- north side so a fresh player walks past him on first spawn.
local function buildGardenerCoach()
	local existing = Workspace:FindFirstChild("GardenerCoachAnchor")
	if existing and existing:IsA("BasePart") then
		if existing:GetAttribute("dialogueId") == nil then
			existing:SetAttribute("dialogueId", "GardenerCoach")
		end
		return
	end
	local anchor = makePart(
		"GardenerCoachAnchor",
		Vector3.new(2.5, 5, 2.5),
		Vector3.new(0, 3, 8),                    -- just north of spawn pad
		Color3.fromRGB(180, 150, 100),            -- warm tan placeholder
		Enum.Material.SmoothPlastic
	)
	anchor:SetAttribute("dialogueId", "GardenerCoach")
	anchor.Parent = Workspace

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DialoguePrompt"
	prompt.ActionText = "Talk to Coach"
	prompt.ObjectText = "Gardener Coach"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
end

-- Phase 2 launch dialogue NPCs (lore-only + travel-bound). Each is a
-- placeholder colored Part anchored at a sensible spot in the Starter Glade;
-- real character models drop in during a polish pass.

local function buildTravelCoordinator()
	-- Reserved position from Constants.BIOMES.StarterGlade.npcPositions.
	-- Slate-grey to evoke "trail marker / way-finder".
	buildDialogueNpc(
		"TravelCoordinatorAnchor",
		"TravelCoordinator",
		Vector3.new(-15, 2.5, 0),
		Color3.fromRGB(110, 120, 135),
		"Talk to Coordinator",
		"Travel Coordinator"
	)
end

local function buildOldHermit()
	-- Tucked at the western edge of the wild spawn area, between the trees
	-- and the pond. Mossy green-brown — a hermit who's been here a while.
	buildDialogueNpc(
		"OldHermitAnchor",
		"OldHermit",
		Vector3.new(-40, 2.5, -25),
		Color3.fromRGB(85, 90, 70),
		"Talk to Hermit",
		"Old Hermit"
	)
end

local function buildWanderingAlchemist()
	-- Hangs near the cauldron, where the witch tolerates her. Warm purple
	-- to read as "alchemist" alongside the witch's stall purple.
	buildDialogueNpc(
		"WanderingAlchemistAnchor",
		"WanderingAlchemist",
		Vector3.new(78, 2.5, 8),
		Color3.fromRGB(150, 110, 175),
		"Talk to Alchemist",
		"Wandering Alchemist"
	)
end

-- Phase 2 Trading Post placeholder — a simple wooden stand near the spawn
-- pad as a navigation hint. The real Trading Post (zone with portals from
-- every biome, trade-stand props, ambient music) lands in a later commit.
-- Trade backend is reachable from anywhere in the world for now via the
-- HUD "Trade" button, so this Part is purely visual.
local function buildTradingPostMarker()
	if Workspace:FindFirstChild("TradingPostMarker") then return end
	local marker = makePart(
		"TradingPostMarker",
		Vector3.new(6, 0.5, 6),
		Vector3.new(25, 0.5, 0),
		Color3.fromRGB(180, 150, 100),
		Enum.Material.Wood
	)
	marker.Parent = Workspace
	-- Sign post on top.
	local post = makePart(
		"TradingPostSign",
		Vector3.new(0.4, 4, 0.4),
		Vector3.new(25, 2.75, 0),
		Color3.fromRGB(110, 80, 55),
		Enum.Material.Wood
	)
	post.Parent = marker
	local sign = makePart(
		"TradingPostBoard",
		Vector3.new(3, 1.2, 0.2),
		Vector3.new(25, 4.5, 0),
		Color3.fromRGB(110, 80, 55),
		Enum.Material.Wood
	)
	sign.Parent = marker
	local label = Instance.new("SurfaceGui")
	label.Face = Enum.NormalId.Front
	label.LightInfluence = 0
	label.Parent = sign
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 1)
	txt.BackgroundTransparency = 1
	txt.Text = "Trading Post"
	txt.TextColor3 = Color3.fromRGB(245, 235, 215)
	txt.TextScaled = true
	txt.Font = Enum.Font.GothamBold
	txt.Parent = label
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
	buildSubstrateDealer()
	buildSporeMerchant()
	buildGardenerCoach()
	buildTravelCoordinator()
	buildOldHermit()
	buildWanderingAlchemist()
	buildTradingPostMarker()
	buildCauldron()
	local wildSpawnArea = buildWildSpawnArea()
	local plots = buildPlots(plotCount)
	return { wildSpawnArea = wildSpawnArea, plots = plots }
end

return MapSetup
