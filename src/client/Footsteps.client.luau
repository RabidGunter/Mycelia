-- Soften default footsteps.
--
-- Roblox's default character has one Running sound (the loud plastic-thud
-- "action_footsteps_plastic.mp3") that plays on every surface — Roblox does
-- not auto-swap it based on Humanoid.FloorMaterial. On our brown-and-green
-- Pre-Alpha world it reads as wood thuds and gets old fast.
--
-- Until the proper terrain pass lands (handoff "What's next" item 4) we
-- just lower the Running sound's volume. Other character sounds (Jumping,
-- Landing, Splash) are left alone.

local Players = game:GetService("Players")

local FOOTSTEP_VOLUME = 0.15    -- default is 0.65 — barely audible at 0.15

local player = Players.LocalPlayer

local function softenRunningSound(character: Model)
	-- The Running sound is created on the character's HumanoidRootPart by
	-- the default RbxCharacterSounds script. That script runs in parallel
	-- with us, so the sound may not exist yet — wait briefly.
	local hrp = character:WaitForChild("HumanoidRootPart", 5)
	if not hrp then
		return
	end
	local running = hrp:WaitForChild("Running", 5)
	if not running or not running:IsA("Sound") then
		return
	end
	running.Volume = FOOTSTEP_VOLUME
end

if player.Character then
	task.spawn(softenRunningSound, player.Character)
end
player.CharacterAdded:Connect(softenRunningSound)
