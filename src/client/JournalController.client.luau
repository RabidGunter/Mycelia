-- Brewing Journal UI.
--
-- A "Pokedex"-style panel listing every potion in the game catalog. Potions
-- the player has ever brewed (data.stats.potionsDiscovered) are shown with
-- name + description + effect summary + current owned count. Undiscovered
-- potions render as "???" rows with no description so players see the gap
-- without being spoiled.
--
-- Triggered by a "Journal" button in the HUD, sitting next to the Potions
-- button. The two pickers (Potions / Journal) are deliberately separate:
-- Potions = "what can I drink right now"; Journal = "what have I learned".
--
-- Visual style matches PotionController.client.lua / BrewController.client.lua
-- so the three pickers feel like siblings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Potions = require(ReplicatedStorage.Shared.Potions)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local latestData = {
	potions = {},
	stats = { potionsDiscovered = {} },
}

local function discoveredSet(): { [string]: boolean }
	local stats = latestData.stats or {}
	return stats.potionsDiscovered or {}
end

-- ---------- HUD button -----------------------------------------------------

local hudScreen = Instance.new("ScreenGui")
hudScreen.Name = "MyceliaJournalHUD"
hudScreen.ResetOnSpawn = false
hudScreen.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "JournalButton"
openButton.AnchorPoint = Vector2.new(0, 0)
-- Sits next to the Potions button (which is at x=16, width=120). 8px gap.
openButton.Position = UDim2.new(0, 144, 0, 94)
openButton.Size = UDim2.fromOffset(110, 32)
openButton.BackgroundColor3 = Color3.fromRGB(50, 60, 70)
openButton.BorderSizePixel = 0
openButton.Text = "Journal (0/0)"
openButton.TextColor3 = Color3.fromRGB(220, 230, 240)
openButton.Font = Enum.Font.GothamMedium
openButton.TextSize = 14
openButton.AutoButtonColor = true
openButton.Parent = hudScreen

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 8)
openCorner.Parent = openButton

local function refreshButton()
	local discovered = discoveredSet()
	local discoveredCount = 0
	for _ in pairs(discovered) do
		discoveredCount += 1
	end
	openButton.Text = string.format("Journal (%d/%d)", discoveredCount, #Potions.LIST)
end

-- ---------- Picker ---------------------------------------------------------

local pickerScreen = Instance.new("ScreenGui")
pickerScreen.Name = "BrewingJournal"
pickerScreen.ResetOnSpawn = false
pickerScreen.DisplayOrder = 10
pickerScreen.Enabled = false
pickerScreen.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = pickerScreen

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.92, 0, 0.85, 0)
card.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
card.BorderSizePixel = 0
card.Parent = pickerScreen

local cardSize = Instance.new("UISizeConstraint")
cardSize.MaxSize = Vector2.new(440, 620)
cardSize.MinSize = Vector2.new(280, 380)
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
title.Size = UDim2.new(1, 0, 0, 26)
title.BackgroundTransparency = 1
title.Text = "Brewing Journal"
title.TextColor3 = Color3.fromRGB(245, 240, 230)
title.Font = Enum.Font.GothamMedium
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = card

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.new(0, 0, 0, 26)
subtitle.Size = UDim2.new(1, 0, 0, 16)
subtitle.BackgroundTransparency = 1
subtitle.Text = "0 of 0 discovered"
subtitle.TextColor3 = Color3.fromRGB(170, 160, 185)
subtitle.Font = Enum.Font.Gotham
subtitle.TextSize = 12
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = card

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 0, 0, 50)
list.Size = UDim2.new(1, 0, 1, -50 - 52)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.Parent = card

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list
listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	list.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y)
end)

local close = Instance.new("TextButton")
close.AnchorPoint = Vector2.new(0.5, 1)
close.Position = UDim2.new(0.5, 0, 1, 0)
close.Size = UDim2.new(0.5, 0, 0, 40)
close.BackgroundColor3 = Color3.fromRGB(60, 50, 65)
close.Text = "Close"
close.TextColor3 = Color3.fromRGB(245, 240, 230)
close.Font = Enum.Font.GothamMedium
close.TextSize = 16
close.Parent = card
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = close

local function clearList()
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") or (c:IsA("TextLabel") and c.Name == "Empty") then
			c:Destroy()
		end
	end
end

local function effectLine(potionId: string): string?
	local spec = Constants.POTIONS[potionId]
	if not spec then
		return nil
	end
	if spec.kind == "speed" then
		return string.format("Walk speed x%.1f for %ds", spec.magnitude, spec.durationSeconds)
	elseif spec.kind == "growth" then
		return string.format("Plot growth x%.1f for %ds", spec.magnitude, spec.durationSeconds)
	elseif spec.kind == "wildYield" then
		return string.format("Wild yield +%d for %ds", spec.magnitude, spec.durationSeconds)
	end
	return nil
end

local function buildRow(potion, layoutOrder: number, isDiscovered: boolean, ownedCount: number)
	local tier = Tiers[potion.rarity]

	local row = Instance.new("Frame")
	row.Name = "Row_" .. potion.id
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 76)
	row.BackgroundColor3 = isDiscovered
		and Color3.fromRGB(48, 42, 55)
		or Color3.fromRGB(34, 30, 40)
	row.BorderSizePixel = 0
	row.Parent = list

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row

	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingLeft = UDim.new(0, 12)
	rowPad.PaddingRight = UDim.new(0, 12)
	rowPad.PaddingTop = UDim.new(0, 8)
	rowPad.PaddingBottom = UDim.new(0, 8)
	rowPad.Parent = row

	-- Rarity dot.
	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0, 0)
	swatch.Position = UDim2.new(0, 0, 0, 4)
	swatch.Size = UDim2.fromOffset(10, 10)
	swatch.BackgroundColor3 = isDiscovered and tier.displayColor or Color3.fromRGB(80, 75, 90)
	swatch.BorderSizePixel = 0
	swatch.Parent = row
	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = UDim.new(1, 0)
	swatchCorner.Parent = swatch

	local name = Instance.new("TextLabel")
	name.Position = UDim2.new(0, 18, 0, 0)
	name.Size = UDim2.new(1, -18 - 60, 0, 18)
	name.BackgroundTransparency = 1
	name.Text = isDiscovered and potion.displayName or "???"
	name.TextColor3 = isDiscovered
		and Color3.fromRGB(245, 240, 230)
		or Color3.fromRGB(140, 130, 155)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 15
	name.Parent = row

	local rarity = Instance.new("TextLabel")
	rarity.Position = UDim2.new(0, 18, 0, 18)
	rarity.Size = UDim2.new(1, -18 - 60, 0, 14)
	rarity.BackgroundTransparency = 1
	rarity.Text = isDiscovered and potion.rarity or "Unknown"
	rarity.TextColor3 = Color3.fromRGB(170, 160, 185)
	rarity.TextXAlignment = Enum.TextXAlignment.Left
	rarity.Font = Enum.Font.Gotham
	rarity.TextSize = 11
	rarity.Parent = row

	local body = Instance.new("TextLabel")
	body.Position = UDim2.new(0, 0, 0, 36)
	body.Size = UDim2.new(1, 0, 1, -36)
	body.BackgroundTransparency = 1
	body.TextColor3 = isDiscovered
		and Color3.fromRGB(200, 195, 215)
		or Color3.fromRGB(125, 118, 140)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.Font = Enum.Font.Gotham
	body.TextSize = 12
	body.TextWrapped = true
	if isDiscovered then
		local effect = effectLine(potion.id)
		if effect then
			body.Text = potion.description .. "\n" .. effect
		else
			body.Text = potion.description .. "\n(No effect yet.)"
		end
	else
		body.Text = "Brew to discover."
	end
	body.Parent = row

	if isDiscovered then
		local ownedLbl = Instance.new("TextLabel")
		ownedLbl.AnchorPoint = Vector2.new(1, 0)
		ownedLbl.Position = UDim2.new(1, 0, 0, 0)
		ownedLbl.Size = UDim2.fromOffset(56, 32)
		ownedLbl.BackgroundTransparency = 1
		ownedLbl.Text = "Owned " .. tostring(ownedCount)
		ownedLbl.TextColor3 = Color3.fromRGB(220, 210, 235)
		ownedLbl.Font = Enum.Font.GothamBold
		ownedLbl.TextSize = 12
		ownedLbl.TextXAlignment = Enum.TextXAlignment.Right
		ownedLbl.Parent = row
	end
end

local TIER_RANK = {
	Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6,
}

local function repopulate()
	clearList()
	local discovered = discoveredSet()
	local owned = latestData.potions or {}

	-- Sort: discovered first (by rarity then name), then undiscovered (by
	-- rarity then name). Keeps "what you know" at the top while preserving
	-- a stable relative order across openings.
	local entries = {}
	for _, p in ipairs(Potions.LIST) do
		table.insert(entries, p)
	end
	table.sort(entries, function(a, b)
		local aDisc = discovered[a.id] == true
		local bDisc = discovered[b.id] == true
		if aDisc ~= bDisc then
			return aDisc
		end
		local ar = TIER_RANK[a.rarity] or 99
		local br = TIER_RANK[b.rarity] or 99
		if ar ~= br then
			return ar < br
		end
		return a.displayName < b.displayName
	end)

	local discoveredCount = 0
	for _ in pairs(discovered) do
		discoveredCount += 1
	end
	subtitle.Text = string.format("%d of %d discovered", discoveredCount, #Potions.LIST)

	for i, p in ipairs(entries) do
		buildRow(p, i, discovered[p.id] == true, owned[p.id] or 0)
	end
end

local function openPicker()
	repopulate()
	pickerScreen.Enabled = true
end

local function closePicker()
	pickerScreen.Enabled = false
end

openButton.Activated:Connect(openPicker)
close.Activated:Connect(closePicker)
overlay.Activated:Connect(closePicker)

-- ---------- Game state hookup ---------------------------------------------

Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(function(data)
	latestData = data or { potions = {}, stats = { potionsDiscovered = {} } }
	refreshButton()
	if pickerScreen.Enabled then
		repopulate()
	end
end)

refreshButton()
