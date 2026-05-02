-- Active effects HUD strip.
--
-- Listens to ActiveEffectsUpdated for the latest set of running buffs and
-- renders one chip per effect just below the Potions button. Each chip
-- self-decays its countdown via Heartbeat — the server only fires updates
-- on apply / expire / refresh, the client handles the steady tick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screen = Instance.new("ScreenGui")
screen.Name = "MyceliaEffectsHUD"
screen.ResetOnSpawn = false
screen.Parent = playerGui

local strip = Instance.new("Frame")
strip.Name = "EffectsStrip"
-- Sit below the Potions button (y=94, height=32 → ends at 126). 6px gap.
strip.Position = UDim2.new(0, 16, 0, 132)
strip.Size = UDim2.new(0, 200, 0, 0)    -- height is driven by AutomaticSize
strip.AutomaticSize = Enum.AutomaticSize.Y
strip.BackgroundTransparency = 1
strip.BorderSizePixel = 0
strip.Parent = screen

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = strip

-- Most recent server-pushed snapshot. { { kind, magnitude, expiresAt }, ... }
local current: { { kind: string, magnitude: number, expiresAt: number } } = {}
-- chip Frames keyed by kind so we can update them in place each tick.
local chips: { [string]: { frame: Frame, label: TextLabel } } = {}

local KIND_LABEL = {
	speed = "Speed x%.1f",
	growth = "Growth x%.1f",
	wildYield = "Wild Yield +%d",
}

local KIND_COLOR = {
	speed = Color3.fromRGB(80, 130, 200),
	growth = Color3.fromRGB(120, 165, 90),
	wildYield = Color3.fromRGB(190, 145, 80),
}

local function describe(effect): string
	local fmt = KIND_LABEL[effect.kind]
	if not fmt then
		return effect.kind
	end
	return string.format(fmt, effect.magnitude)
end

local function destroyChip(kind: string)
	local chip = chips[kind]
	if not chip then
		return
	end
	chip.frame:Destroy()
	chips[kind] = nil
end

local function ensureChip(kind: string, layoutOrder: number, effect)
	local chip = chips[kind]
	if chip then
		chip.frame.LayoutOrder = layoutOrder
		return chip
	end
	local frame = Instance.new("Frame")
	frame.Name = "Effect_" .. kind
	frame.LayoutOrder = layoutOrder
	frame.Size = UDim2.new(1, 0, 0, 28)
	frame.BackgroundColor3 = KIND_COLOR[kind] or Color3.fromRGB(80, 80, 90)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = strip

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = frame

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 250, 245)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = describe(effect)
	label.Parent = frame

	chip = { frame = frame, label = label }
	chips[kind] = chip
	return chip
end

local function syncChips()
	-- Build set of incoming kinds to know which old chips to drop.
	local incoming: { [string]: boolean } = {}
	for i, effect in ipairs(current) do
		incoming[effect.kind] = true
		ensureChip(effect.kind, i, effect)
	end
	for kind in pairs(chips) do
		if not incoming[kind] then
			destroyChip(kind)
		end
	end
end

local function tickCountdowns()
	if #current == 0 then
		return
	end
	local now = os.time()
	local anyExpired = false
	for _, effect in ipairs(current) do
		local chip = chips[effect.kind]
		if chip then
			local remaining = math.max(0, effect.expiresAt - now)
			if remaining <= 0 then
				anyExpired = true
				chip.label.Text = describe(effect) .. "  0s"
			else
				chip.label.Text = string.format("%s  %ds", describe(effect), remaining)
			end
		end
	end
	-- Note: server is the source of truth for expiry. We don't drop chips
	-- locally on remaining=0 — the server's sweep will fire an update with
	-- the entry removed shortly after. anyExpired is informational only.
	_ = anyExpired
end

Remotes.get(Constants.REMOTES.ActiveEffectsUpdated).OnClientEvent:Connect(function(snapshot)
	current = snapshot or {}
	syncChips()
	tickCountdowns()
end)

RunService.Heartbeat:Connect(function()
	-- Cheap: at most 3 effects, integer-second math, no allocation.
	tickCountdowns()
end)
