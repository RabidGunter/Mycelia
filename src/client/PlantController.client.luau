-- Plant species picker.
--
-- When a plot's PlantPrompt fires on the client (LocalPlayer triggered it),
-- open a modal listing every species the player has discovered. Tapping a
-- species row sends (plot, speciesId) over the PlantSpecies remote; the
-- server re-validates and either plants or silently rejects.
--
-- Mobile-first layout: card max-width 360, scrolling list with big tap
-- rows, dim+disable rows the player can't afford. Tap the dim overlay or
-- the Cancel button to close.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------- State ----------------------------------------------------------

-- Latest snapshot of the player's data. Kept in sync via PlayerDataUpdated
-- so affordability re-renders if the player gains coins while the picker
-- is open.
local latestData = {
	coins = 0,
	inventory = {},
	stats = { speciesDiscovered = {} },
}

-- The plot currently being planted into; nil when picker is closed.
local currentPlot: Instance? = nil

-- ---------- UI construction (built once, reused) --------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "PlantPicker"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 10    -- above the HUD
screen.Enabled = false
screen.Parent = playerGui

-- Full-screen tap-to-cancel overlay. Using a TextButton (rather than a
-- Frame) gives us free input handling and proper mouse cursor behavior.
local overlay = Instance.new("TextButton")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = screen

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.9, 0, 0, 480)
card.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
card.BorderSizePixel = 0
card.Parent = screen

local cardSize = Instance.new("UISizeConstraint")
cardSize.MaxSize = Vector2.new(360, 520)
cardSize.MinSize = Vector2.new(280, 320)
cardSize.Parent = card

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 12)
cardCorner.Parent = card

local cardPad = Instance.new("UIPadding")
cardPad.PaddingTop = UDim.new(0, 16)
cardPad.PaddingBottom = UDim.new(0, 16)
cardPad.PaddingLeft = UDim.new(0, 16)
cardPad.PaddingRight = UDim.new(0, 16)
cardPad.Parent = card

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 28)
title.BackgroundTransparency = 1
title.Text = "Plant a species"
title.TextColor3 = Color3.fromRGB(245, 240, 230)
title.Font = Enum.Font.GothamMedium
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = card

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.new(0, 0, 0, 30)
subtitle.Size = UDim2.new(1, 0, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = ""
subtitle.TextColor3 = Color3.fromRGB(170, 160, 180)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 13
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = card

local rows = Instance.new("ScrollingFrame")
rows.Name = "Rows"
rows.Position = UDim2.new(0, 0, 0, 56)
rows.Size = UDim2.new(1, 0, 1, -56 - 48)    -- leave room for cancel
rows.BackgroundTransparency = 1
rows.BorderSizePixel = 0
rows.ScrollBarThickness = 4
rows.CanvasSize = UDim2.new(0, 0, 0, 0)
rows.Parent = card

local rowsLayout = Instance.new("UIListLayout")
rowsLayout.Padding = UDim.new(0, 6)
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Parent = rows
rowsLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	rows.CanvasSize = UDim2.new(0, 0, 0, rowsLayout.AbsoluteContentSize.Y)
end)

-- Empty-state label, shown when discovered species set is empty.
local emptyLabel = Instance.new("TextLabel")
emptyLabel.Name = "Empty"
emptyLabel.Size = UDim2.fromScale(1, 1)
emptyLabel.BackgroundTransparency = 1
emptyLabel.Text = "Harvest a wild mushroom first.\nDiscovered species can be planted."
emptyLabel.TextWrapped = true
emptyLabel.TextColor3 = Color3.fromRGB(170, 160, 180)
emptyLabel.Font = Enum.Font.Gotham
emptyLabel.TextSize = 14
emptyLabel.Visible = false
emptyLabel.Parent = rows

local cancel = Instance.new("TextButton")
cancel.Name = "Cancel"
cancel.AnchorPoint = Vector2.new(0, 1)
cancel.Position = UDim2.new(0, 0, 1, 0)
cancel.Size = UDim2.new(1, 0, 0, 40)
cancel.BackgroundColor3 = Color3.fromRGB(60, 50, 65)
cancel.Text = "Cancel"
cancel.TextColor3 = Color3.fromRGB(245, 240, 230)
cancel.Font = Enum.Font.GothamMedium
cancel.TextSize = 16
cancel.AutoButtonColor = true
cancel.Parent = card

local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 8)
cancelCorner.Parent = cancel

-- ---------- Picker logic ---------------------------------------------------

local TIER_INDEX: { [string]: number } = {}
for i, name in ipairs(Tiers.ORDER) do
	TIER_INDEX[name] = i
end

local function clearRows()
	for _, c in ipairs(rows:GetChildren()) do
		if c:IsA("TextButton") and c.Name:match("^Row_") then
			c:Destroy()
		end
	end
end

local function close()
	currentPlot = nil
	screen.Enabled = false
end

local function buildRow(species, layoutOrder: number)
	local tier = Tiers[species.tier]
	local cost = Constants.CULTIVATION.plantCost[species.tier]
	local affordable = cost ~= nil and latestData.coins >= cost

	local row = Instance.new("TextButton")
	row.Name = "Row_" .. species.id
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Color3.fromRGB(48, 42, 55)
	row.AutoButtonColor = affordable
	row.Text = ""
	row.Active = affordable
	row.Parent = rows

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 8)
	rowCorner.Parent = row

	-- Tier swatch
	local swatch = Instance.new("Frame")
	swatch.Name = "Swatch"
	swatch.AnchorPoint = Vector2.new(0, 0.5)
	swatch.Position = UDim2.new(0, 12, 0.5, 0)
	swatch.Size = UDim2.fromOffset(18, 18)
	swatch.BackgroundColor3 = tier.displayColor
	swatch.BorderSizePixel = 0
	swatch.Parent = row
	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = UDim.new(1, 0)
	swatchCorner.Parent = swatch

	-- Name
	local name = Instance.new("TextLabel")
	name.AnchorPoint = Vector2.new(0, 0)
	name.Position = UDim2.new(0, 42, 0, 8)
	name.Size = UDim2.new(1, -52, 0, 20)
	name.BackgroundTransparency = 1
	name.Text = species.displayName
	name.TextColor3 = affordable and Color3.fromRGB(245, 240, 230) or Color3.fromRGB(140, 135, 145)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 15
	name.Parent = row

	-- Subtitle: "Tier · cost coins"
	local sub = Instance.new("TextLabel")
	sub.AnchorPoint = Vector2.new(0, 0)
	sub.Position = UDim2.new(0, 42, 0, 30)
	sub.Size = UDim2.new(1, -52, 0, 18)
	sub.BackgroundTransparency = 1
	sub.Text = string.format("%s · %d coins", species.tier, cost or 0)
	sub.TextColor3 = affordable and Color3.fromRGB(180, 170, 190) or Color3.fromRGB(110, 105, 115)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.Parent = row

	if affordable then
		row.Activated:Connect(function()
			if not currentPlot then
				return
			end
			Remotes.get(Constants.REMOTES.PlantSpecies):FireServer(currentPlot, species.id)
			close()
		end)
	end
end

local function repopulate()
	clearRows()

	local discovered = (latestData.stats and latestData.stats.speciesDiscovered) or {}
	local list = {}
	for speciesId in pairs(discovered) do
		local sp = Species.byId[speciesId]
		if sp then
			table.insert(list, sp)
		end
	end

	-- Sort: tier ascending (commons first), then by display name.
	table.sort(list, function(a, b)
		local ai = TIER_INDEX[a.tier] or 99
		local bi = TIER_INDEX[b.tier] or 99
		if ai ~= bi then
			return ai < bi
		end
		return a.displayName < b.displayName
	end)

	emptyLabel.Visible = #list == 0
	subtitle.Text = string.format("You have %d coins.", latestData.coins or 0)

	for i, sp in ipairs(list) do
		buildRow(sp, i)
	end
end

local function open(plot: Instance)
	currentPlot = plot
	repopulate()
	screen.Enabled = true
end

cancel.Activated:Connect(close)
overlay.Activated:Connect(close)

-- ---------- Wire to game state --------------------------------------------

Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(function(data)
	latestData = data
	if currentPlot then
		repopulate()    -- live update affordability while picker open
	end
end)

-- Walk from a prompt up to the nearest ancestor with isPlot = true.
local function plotFromPrompt(prompt: ProximityPrompt): Instance?
	local cur: Instance? = prompt.Parent
	while cur do
		if cur:GetAttribute("isPlot") then
			return cur
		end
		cur = cur.Parent
	end
	return nil
end

-- On the client, PromptTriggered only fires for the LocalPlayer, so no
-- per-player filtering needed.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "PlantPrompt" then
		return
	end
	local plot = plotFromPrompt(prompt)
	if plot then
		open(plot)
	end
end)
