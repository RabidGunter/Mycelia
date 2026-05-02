-- Koi fish swimming in the pond.
--
-- Each koi is a small anchored Model parented to Workspace.Koi (a folder
-- the module creates). Body is a single Part with a SpecialMesh elongated
-- into a fish-shaped ellipsoid; orientation is locked to the swim
-- direction via CFrame.lookAt so it always reads as "facing forward".
-- A second small Part trails behind for the tail silhouette.
--
-- Movement is a kinematic waypoint loop driven by Heartbeat — pick a
-- random point inside the pond, lerp toward it, pick a new one when
-- close. Subtle Y-bob for life. No physics simulation; we just set
-- CFrames each frame.
--
-- Pond geometry comes from TerrainBuilder.POND so the fish stay where
-- the water actually is. If TerrainBuilder.POND is missing, Koi.start
-- silently does nothing — the pond is decorative, not load-bearing.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

local TerrainBuilder = require(ServerScriptService.Server.TerrainBuilder)

local Koi = {}

-- Tunables ----------------------------------------------------------------

local KOI_COUNT = 6
local SPEED_RANGE = { 2.5, 4.5 }       -- studs per second per fish
local BOB_AMPLITUDE = 0.18              -- vertical wobble amplitude
local BOB_FREQUENCY = { 0.6, 1.4 }      -- per-koi randomized bob speed
local BODY_LENGTH = 3.2                 -- studs along swim axis
local BODY_WIDTH = 1.0                  -- studs sideways
local BODY_HEIGHT = 0.7                 -- studs vertically (thin)
local TAIL_LENGTH = 1.0
local WAYPOINT_REACH = 1.4              -- "I'm here, pick a new target"
local SHORELINE_MARGIN = 4              -- keep koi this far from the rim

-- Classic koi-variety palette. Solid colors only — no textures or decals
-- in this pass; can layer those in later if needed.
local PALETTE = {
	Color3.fromRGB(245, 240, 235),     -- shiro (white)
	Color3.fromRGB(230, 110, 60),      -- yamabuki ogon (orange)
	Color3.fromRGB(190, 40, 40),       -- beni (deep red)
	Color3.fromRGB(35, 30, 30),        -- karasu (black)
	Color3.fromRGB(250, 200, 80),      -- gold
	Color3.fromRGB(220, 180, 200),     -- pale pink
}

-- ---------- Construction -------------------------------------------------

local function makeFishPart(name: string, color: Color3, length: number, width: number, height: number): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	-- Part.Size IS the visible size; SpecialMesh of type Sphere fills it
	-- as an ellipsoid. Setting Part.Shape would force the ball renderer
	-- (which only respects the smallest dimension) and leave you with a
	-- tiny round blob — counterintuitive, but how Roblox parts behave
	-- when Shape and SpecialMesh both want to render.
	p.Size = Vector3.new(width, height, length)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function makeKoi(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "Koi"

	local body = makeFishPart("Body", color, BODY_LENGTH, BODY_WIDTH, BODY_HEIGHT)
	body.Parent = model
	model.PrimaryPart = body

	-- Tail trails behind the body's -Z (which is the swim-forward axis).
	-- Slightly darker shade so it reads as a separate fin.
	local tailColor = Color3.new(color.R * 0.7, color.G * 0.7, color.B * 0.7)
	local tail = makeFishPart("Tail", tailColor, TAIL_LENGTH, BODY_WIDTH * 0.8, BODY_HEIGHT * 0.6)
	tail.Parent = model

	return model
end

-- ---------- Motion -------------------------------------------------------

local activeKoi: { any } = {}

local function pickWaypoint(pond): Vector3
	-- Uniform-random point inside (radius - margin). Square-root keeps the
	-- distribution uniform in area rather than clustered at the center.
	local r = math.sqrt(math.random()) * (pond.radius - SHORELINE_MARGIN)
	local angle = math.random() * math.pi * 2
	return Vector3.new(
		pond.centerX + math.cos(angle) * r,
		pond.surfaceY - 1,    -- swim just below the water surface
		pond.centerZ + math.sin(angle) * r
	)
end

local function spawnKoi(pond)
	local container = Workspace:FindFirstChild("Koi")
	if not container then
		container = Instance.new("Folder")
		container.Name = "Koi"
		container.Parent = Workspace
	end
	-- Wipe any leftover koi from a prior Play (the folder, but not the
	-- pond, persists in the saved place).
	container:ClearAllChildren()

	for i = 1, KOI_COUNT do
		local color = PALETTE[((i - 1) % #PALETTE) + 1]
		local model = makeKoi(color)
		local startPos = pickWaypoint(pond)
		model.PrimaryPart.CFrame = CFrame.new(startPos)
		model.Parent = container

		table.insert(activeKoi, {
			model = model,
			waypoint = pickWaypoint(pond),
			speed = SPEED_RANGE[1] + math.random() * (SPEED_RANGE[2] - SPEED_RANGE[1]),
			bobPhase = math.random() * math.pi * 2,
			bobSpeed = BOB_FREQUENCY[1] + math.random() * (BOB_FREQUENCY[2] - BOB_FREQUENCY[1]),
			swimY = pond.surfaceY - 1,
		})
	end
end

local function tick(pond, dt: number)
	for _, koi in ipairs(activeKoi) do
		local body = koi.model.PrimaryPart
		if not body or not body.Parent then
			continue
		end

		local toward = koi.waypoint - body.Position
		-- Ignore Y for "have I arrived" — the bob can keep us moving
		-- vertically forever otherwise.
		local horizontal = Vector3.new(toward.X, 0, toward.Z)
		if horizontal.Magnitude < WAYPOINT_REACH then
			koi.waypoint = pickWaypoint(pond)
			continue
		end

		local direction = horizontal.Unit
		local newXZ = body.Position + direction * koi.speed * dt

		-- Bob at the surface so each koi has a tiny independent vertical
		-- wobble (sells "alive in water").
		koi.bobPhase = koi.bobPhase + dt * koi.bobSpeed * math.pi * 2
		local y = koi.swimY + math.sin(koi.bobPhase) * BOB_AMPLITUDE

		local newPos = Vector3.new(newXZ.X, y, newXZ.Z)
		-- Body faces swim direction; -Z is the lookAt forward axis, which
		-- we built the mesh's long axis along.
		body.CFrame = CFrame.lookAt(newPos, newPos + direction)

		-- Tail trails behind the body, slightly lower for "swimming through"
		-- effect, and waggles by a small angle keyed off the bob phase.
		local tail = koi.model:FindFirstChild("Tail")
		if tail then
			local waggle = math.sin(koi.bobPhase * 1.6) * 0.25
			tail.CFrame = body.CFrame
				* CFrame.new(0, -0.05, BODY_LENGTH * 0.45 + TAIL_LENGTH * 0.4)
				* CFrame.Angles(0, waggle, 0)
		end
	end
end

-- ---------- Public API ---------------------------------------------------

function Koi.start()
	local pond = TerrainBuilder.POND
	if not pond then
		warn("[Koi] TerrainBuilder.POND missing — koi disabled.")
		return
	end

	spawnKoi(pond)
	RunService.Heartbeat:Connect(function(dt)
		tick(pond, dt)
	end)
end

return Koi
