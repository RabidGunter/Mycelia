-- Toast for brew results. Three flavors:
--   * isNewDiscovery -> "Discovered: <Potion Name>!"  (gold, larger)
--   * success        -> "Brewed: <Potion Name>"        (gold)
--   * else (fizzle)  -> "The brew fizzles..."          (purple/grey)
--
-- Float-up-and-fade animation pattern; matches the in-Shop toast in
-- ShopUI.client.luau (the Pre-Alpha SellToast was rolled into that UI).

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Potions = require(ReplicatedStorage.Shared.Potions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "BrewToast"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local TOAST_DURATION = 2.0

local function showToast(text: string, color: Color3, big: boolean)
	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = UDim2.fromOffset(420, 70)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = big and Enum.Font.GothamBlack or Enum.Font.GothamBold
	label.TextSize = big and 36 or 28
	label.Parent = screen

	local tween = TweenService:Create(label,
		TweenInfo.new(TOAST_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.fromScale(0.5, 0.30),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end

Remotes.get(Constants.REMOTES.BrewCompleted).OnClientEvent:Connect(function(result)
	if type(result) ~= "table" then
		return
	end

	if not result.success then
		showToast("The brew fizzles…", Color3.fromRGB(180, 170, 200), false)
		return
	end

	local potion = result.potionId and Potions.byId[result.potionId]
	if not potion then
		return
	end

	if result.isNewDiscovery then
		showToast(
			string.format("Discovered: %s!", potion.displayName),
			Color3.fromRGB(255, 220, 80),
			true
		)
	else
		showToast(
			string.format("Brewed: %s", potion.displayName),
			Color3.fromRGB(255, 220, 80),
			false
		)
	end
end)
