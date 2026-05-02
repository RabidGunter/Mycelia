-- Potion consumption UI.
--
-- A small "Potions" button sits below the coin/inventory chip in the HUD.
-- Tapping it opens a picker listing every potion in the player's inventory:
--   - active potions (have a Constants.POTIONS entry) are tappable; tapping
--     consumes one and applies its effect via the ConsumePotion remote.
--   - inert potions (no entry) are listed greyed out with "no effect yet"
--     so players know they exist but aren't useful in Pre-Alpha.
--
-- Visual style matches BrewController.client.lua so the two pickers feel
-- like siblings.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Potions = require(ReplicatedStorage.Shared.Potions)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local latestData = { potions = {} }

-- ---------- HUD button -----------------------------------------------------

local hudScreen = Instance.new("ScreenGui")
hudScreen.Name = "MyceliaPotionsHUD"
hudScreen.ResetOnSpawn = false
hudScreen.Parent = playerGui

local openButton = Instance.new("TextButton")
openButton.Name = "PotionsButton"
openButton.AnchorPoint = Vector2.new(0, 0)
-- Sit below the 70-tall stats frame from CoinDisplay (which itself starts
-- at y=16 with height 70 → ends at 86). 8px gap below that.
openButton.Position = UDim2.new(0, 16, 0, 94)
openButton.Size = UDim2.fromOffset(120, 32)
openButton.BackgroundColor3 = Color3.fromRGB(60, 50, 70)
openButton.BorderSizePixel = 0
openButton.Text = "Potions (0)"
openButton.TextColor3 = Color3.fromRGB(220, 210, 235)
openButton.Font = Enum.Font.GothamMedium
openButton.TextSize = 14
openButton.AutoButtonColor = true
openButton.Parent = hudScreen

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 8)
openCorner.Parent = openButton

local function totalPotions(): number
	local n = 0
	for _, c in pairs(latestData.potions or {}) do
		n += c
	end
	return n
end

local function refreshButton()
	openButton.Text = string.format("Potions (%d)", totalPotions())
end

-- ---------- Picker ---------------------------------------------------------

local pickerScreen = Instance.new("ScreenGui")
pickerScreen.Name = "PotionPicker"
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
cardSize.MaxSize = Vector2.new(420, 600)
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
title.Text = "Potions"
title.TextColor3 = Color3.fromRGB(245, 240, 230)
title.Font = Enum.Font.GothamMedium
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = card

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.new(0, 0, 0, 36)
list.Size = UDim2.new(1, 0, 1, -36 - 52)
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
		if c:IsA("TextButton") or (c:IsA("TextLabel") and c.Name ~= "Empty") then
			c:Destroy()
		end
	end
	for _, c in ipairs(list:GetChildren()) do
		if c.Name == "Empty" then
			c:Destroy()
		end
	end
end

local function buildRow(potionId: string, count: number, layoutOrder: number)
	local meta = Potions.byId[potionId]
	local effectSpec = Constants.POTIONS[potionId]
	local consumable = effectSpec ~= nil

	local row = Instance.new("TextButton")
	row.Name = "Row_" .. potionId
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = consumable
		and Color3.fromRGB(48, 42, 55)
		or Color3.fromRGB(38, 34, 44)
	row.AutoButtonColor = consumable
	row.Active = consumable
	row.Text = ""
	row.Parent = list

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row

	local rowPad = Instance.new("UIPadding")
	rowPad.PaddingLeft = UDim.new(0, 12)
	rowPad.PaddingRight = UDim.new(0, 12)
	rowPad.PaddingTop = UDim.new(0, 6)
	rowPad.PaddingBottom = UDim.new(0, 6)
	rowPad.Parent = row

	local name = Instance.new("TextLabel")
	name.Size = UDim2.new(1, -60, 0, 20)
	name.BackgroundTransparency = 1
	name.Text = (meta and meta.displayName) or potionId
	name.TextColor3 = consumable
		and Color3.fromRGB(245, 240, 230)
		or Color3.fromRGB(160, 150, 175)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 15
	name.Parent = row

	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.new(0, 0, 0, 22)
	sub.Size = UDim2.new(1, -60, 0, 18)
	sub.BackgroundTransparency = 1
	sub.TextColor3 = Color3.fromRGB(170, 160, 185)
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Font = Enum.Font.Gotham
	sub.TextSize = 12
	sub.TextTruncate = Enum.TextTruncate.AtEnd
	if consumable then
		local kind = effectSpec.kind
		local mag = effectSpec.magnitude
		local secs = effectSpec.durationSeconds
		if kind == "speed" then
			sub.Text = string.format("Walk speed x%.1f for %ds", mag, secs)
		elseif kind == "growth" then
			sub.Text = string.format("Plot growth x%.1f for %ds", mag, secs)
		elseif kind == "wildYield" then
			sub.Text = string.format("Wild yield +%d for %ds", mag, secs)
		else
			sub.Text = (meta and meta.description) or ""
		end
	else
		sub.Text = "No effect yet."
	end
	sub.Parent = row

	local countLbl = Instance.new("TextLabel")
	countLbl.AnchorPoint = Vector2.new(1, 0.5)
	countLbl.Position = UDim2.new(1, 0, 0.5, 0)
	countLbl.Size = UDim2.fromOffset(48, 24)
	countLbl.BackgroundTransparency = 1
	countLbl.Text = "x" .. tostring(count)
	countLbl.TextColor3 = Color3.fromRGB(220, 210, 235)
	countLbl.Font = Enum.Font.GothamBold
	countLbl.TextSize = 16
	countLbl.TextXAlignment = Enum.TextXAlignment.Right
	countLbl.Parent = row

	if consumable then
		row.Activated:Connect(function()
			Remotes.get(Constants.REMOTES.ConsumePotion):FireServer(potionId)
		end)
	end
end

local function repopulate()
	clearList()
	local entries = {}
	for potionId, n in pairs(latestData.potions or {}) do
		if n and n > 0 then
			table.insert(entries, { id = potionId, count = n })
		end
	end
	-- Active potions first, then inert; alphabetical inside each group.
	table.sort(entries, function(a, b)
		local aActive = Constants.POTIONS[a.id] ~= nil
		local bActive = Constants.POTIONS[b.id] ~= nil
		if aActive ~= bActive then
			return aActive
		end
		local aName = (Potions.byId[a.id] and Potions.byId[a.id].displayName) or a.id
		local bName = (Potions.byId[b.id] and Potions.byId[b.id].displayName) or b.id
		return aName < bName
	end)
	if #entries == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Empty"
		empty.Size = UDim2.new(1, 0, 0, 80)
		empty.BackgroundTransparency = 1
		empty.Text = "No potions yet.\nBrew some at the cauldron."
		empty.TextWrapped = true
		empty.TextColor3 = Color3.fromRGB(170, 160, 180)
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 14
		empty.Parent = list
	else
		for i, e in ipairs(entries) do
			buildRow(e.id, e.count, i)
		end
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
	latestData = data or { potions = {} }
	refreshButton()
	if pickerScreen.Enabled then
		repopulate()
	end
end)

refreshButton()
