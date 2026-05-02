-- "+N coins" toast that floats up + fades when the player sells at the
-- witch stall. Triggered by the SellCompleted remote (server-fired with
-- the payout amount).
--
-- Each sell creates a fresh TextLabel; tweens are GC'd when the label is
-- destroyed at the end of the animation. No persistent state.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "SellToast"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local TOAST_DURATION = 1.5

Remotes.get(Constants.REMOTES.SellCompleted).OnClientEvent:Connect(function(amount: number)
	if type(amount) ~= "number" or amount <= 0 then
		return
	end

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.45)
	label.Size = UDim2.fromOffset(280, 60)
	label.BackgroundTransparency = 1
	label.Text = string.format("+%d coins", amount)
	label.TextColor3 = Color3.fromRGB(255, 220, 80)
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextSize = 32
	label.Parent = screen

	local tween = TweenService:Create(label,
		TweenInfo.new(TOAST_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Position = UDim2.fromScale(0.5, 0.32),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}
	)
	tween:Play()
	tween.Completed:Connect(function()
		label:Destroy()
	end)
end)
