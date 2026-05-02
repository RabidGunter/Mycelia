-- Lighting + atmosphere setup. Called once on server start to give the
-- world a warm-afternoon mood — soft directional sun, slight haze, gentle
-- color correction. All settings replicate to clients automatically since
-- they live on Lighting.
--
-- Skipped if Workspace:GetAttribute("HasHandBuiltAtmosphere") is set, so
-- once you've configured Lighting/Atmosphere/ColorCorrection by hand in
-- Studio you can flip that attribute and MapSetup stops overwriting your
-- choices.
--
-- Tunables are inline rather than in Constants because they're aesthetic
-- choices, not gameplay balance — adjust freely until the look is right.

local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local Atmosphere = {}

local function ensureChild(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

function Atmosphere.apply()
	if Workspace:GetAttribute("HasHandBuiltAtmosphere") then
		return
	end

	-- Sun + ambient: warm late-afternoon. ClockTime ~14.5 puts the sun
	-- slightly past zenith so shadows have direction without being long.
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 1.6
	Lighting.Ambient = Color3.fromRGB(70, 70, 60)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 130, 110)
	Lighting.ShadowSoftness = 0.4
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	-- `Technology` requires the RobloxScript capability that ordinary server
	-- scripts no longer get. Modern Studio defaults to ShadowMap anyway, so
	-- swallow the error and move on.
	pcall(function()
		Lighting.Technology = Enum.Technology.ShadowMap
	end)

	-- Distance fog: visible at the world's edges (our procedural ground is
	-- 400 studs across) without crowding nearby gameplay.
	Lighting.FogStart = 200
	Lighting.FogEnd = 850
	Lighting.FogColor = Color3.fromRGB(190, 180, 160)

	-- Atmosphere instance for the volumetric haze shader. Replaces
	-- Lighting.FogStart/End at higher distances when present.
	local atm = ensureChild(Lighting, "Atmosphere", "MyceliaAtmosphere")
	atm.Density = 0.32
	atm.Offset = 0.25
	atm.Color = Color3.fromRGB(210, 200, 180)
	atm.Decay = Color3.fromRGB(110, 120, 130)
	atm.Glare = 0.15
	atm.Haze = 1.2

	-- Subtle color correction: slight warmth, slight saturation bump.
	-- Strong enough to read as "inviting forest", soft enough not to look
	-- like a filter.
	local cc = ensureChild(Lighting, "ColorCorrectionEffect", "MyceliaColorCorrection")
	cc.Brightness = 0.02
	cc.Contrast = 0.08
	cc.Saturation = 0.1
	cc.TintColor = Color3.fromRGB(255, 248, 235)

	-- Bloom for the cauldron Neon glow + sun glints.
	local bloom = ensureChild(Lighting, "BloomEffect", "MyceliaBloom")
	bloom.Intensity = 0.4
	bloom.Size = 18
	bloom.Threshold = 0.95
end

return Atmosphere
