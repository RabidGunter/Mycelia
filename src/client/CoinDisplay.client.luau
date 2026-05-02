-- Minimal HUD: shows current coins + total inventory count, top-left of
-- screen. Listens to the PlayerDataUpdated remote for live updates.
--
-- This is intentionally bare — the real UI pass (proper styling, mobile
-- layout, inventory drawer, Pokedex) lands in the next milestone. The
-- goal here is just to confirm visually that the harvest/plant/sell loop
-- is moving numbers around.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "MyceliaHUD"
-- IgnoreGuiInset stays false (default) so the HUD auto-offsets below the
-- Roblox topbar. With IgnoreGuiInset=true, the Coins line was rendering
-- behind the topbar and only Inventory was visible.
screen.ResetOnSpawn = false
screen.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "Stats"
frame.Size = UDim2.new(0, 200, 0, 70)
frame.Position = UDim2.new(0, 16, 0, 16)
frame.BackgroundColor3 = Color3.fromRGB(30, 25, 35)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 0
frame.Parent = screen

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local function makeLabel(name: string, y: number): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name = name
	lbl.Size = UDim2.new(1, -16, 0, 26)
	lbl.Position = UDim2.new(0, 8, 0, y)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(245, 240, 230)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextYAlignment = Enum.TextYAlignment.Center
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 18
	lbl.Parent = frame
	return lbl
end

local coinLbl = makeLabel("Coins", 6)
local invLbl = makeLabel("Inventory", 36)

local function totalItems(inv): number
	local total = 0
	for _, c in pairs(inv) do
		total += c
	end
	return total
end

local function render(data)
	if not data then
		return
	end
	coinLbl.Text = string.format("Coins: %d", data.coins or 0)
	invLbl.Text = string.format("Inventory: %d", totalItems(data.inventory or {}))
end

Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(render)

-- The first PlayerDataUpdated fires on PlayerAdded; that may have
-- happened slightly before this script ran. Render an empty state so the
-- HUD isn't blank in that race window.
render({ coins = 0, inventory = {} })
