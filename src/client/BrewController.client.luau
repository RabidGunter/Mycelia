-- Brewing UI.
--
-- Triggered by the cauldron's BrewPrompt firing on the client.
-- Players choose:
--   1. A method (Steep, Boil, Ferment, Dry-grind) — exactly one.
--   2. 1–5 ingredients picked from inventory.
-- Then hit Brew. The Brew remote sends (method, ingredientIds[]) to the
-- server, which validates, consumes, and resolves the recipe.
--
-- Layout: stacked sections in a centered card.
--   [Title]
--   [Method buttons row]
--   [Ingredient list — scrolling — tap to add, tap selected to remove one]
--   [Selected ingredients summary]
--   [Brew] [Cancel]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Recipes = require(ReplicatedStorage.Shared.Recipes)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------- Local state ----------------------------------------------------

local latestData = {
	coins = 0,
	inventory = {},
	stats = { speciesDiscovered = {} },
}

-- Currently selected method ("steep" | "boil" | "ferment" | "dry_grind") or nil.
local currentMethod: string? = nil
-- Selected ingredients in pick order, max 5.
local selected: { string } = {}

-- ---------- UI scaffold ----------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "BrewPicker"
screen.ResetOnSpawn = false
screen.DisplayOrder = 10
screen.Enabled = false
screen.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BackgroundTransparency = 0.45
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = screen

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.92, 0, 0.85, 0)
card.BackgroundColor3 = Color3.fromRGB(35, 30, 40)
card.BorderSizePixel = 0
card.Parent = screen

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
title.Text = "Cauldron"
title.TextColor3 = Color3.fromRGB(245, 240, 230)
title.Font = Enum.Font.GothamMedium
title.TextSize = 20
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = card

-- Method buttons row -------------------------------------------------------
local methodRow = Instance.new("Frame")
methodRow.Position = UDim2.new(0, 0, 0, 32)
methodRow.Size = UDim2.new(1, 0, 0, 36)
methodRow.BackgroundTransparency = 1
methodRow.Parent = card

local methodLayout = Instance.new("UIListLayout")
methodLayout.FillDirection = Enum.FillDirection.Horizontal
methodLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
methodLayout.Padding = UDim.new(0, 6)
methodLayout.SortOrder = Enum.SortOrder.LayoutOrder
methodLayout.Parent = methodRow

local methodButtons: { [string]: TextButton } = {}

-- Forward declarations: these are referenced inside makeMethodButton's
-- click handler, but their bodies live below. Declaring them as locals
-- here means the closure captures the upvalue (assigned later) rather
-- than creating a stray global.
local repaintMethods
local repaintBrewButton

local function makeMethodButton(method: string, displayName: string, order: number)
	local btn = Instance.new("TextButton")
	btn.Name = "Method_" .. method
	btn.LayoutOrder = order
	btn.Size = UDim2.new(0.25, -5, 1, 0)
	btn.BackgroundColor3 = Color3.fromRGB(48, 42, 55)
	btn.AutoButtonColor = true
	btn.Text = displayName
	btn.TextColor3 = Color3.fromRGB(180, 170, 190)
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.Parent = methodRow

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn

	btn.Activated:Connect(function()
		currentMethod = method
		repaintMethods()
		repaintBrewButton()
	end)
	return btn
end

-- Ingredient list ----------------------------------------------------------
local ingScroll = Instance.new("ScrollingFrame")
ingScroll.Position = UDim2.new(0, 0, 0, 76)
ingScroll.Size = UDim2.new(1, 0, 1, -76 - 92)    -- leave room for selected + buttons
ingScroll.BackgroundTransparency = 1
ingScroll.BorderSizePixel = 0
ingScroll.ScrollBarThickness = 4
ingScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ingScroll.Parent = card

local ingLayout = Instance.new("UIListLayout")
ingLayout.Padding = UDim.new(0, 4)
ingLayout.SortOrder = Enum.SortOrder.LayoutOrder
ingLayout.Parent = ingScroll
ingLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ingScroll.CanvasSize = UDim2.new(0, 0, 0, ingLayout.AbsoluteContentSize.Y)
end)

-- Selected summary ---------------------------------------------------------
local selectedLabel = Instance.new("TextLabel")
selectedLabel.AnchorPoint = Vector2.new(0, 1)
selectedLabel.Position = UDim2.new(0, 0, 1, -52)
selectedLabel.Size = UDim2.new(1, 0, 0, 36)
selectedLabel.BackgroundColor3 = Color3.fromRGB(28, 24, 32)
selectedLabel.BorderSizePixel = 0
selectedLabel.TextColor3 = Color3.fromRGB(220, 210, 235)
selectedLabel.Font = Enum.Font.Gotham
selectedLabel.TextSize = 13
selectedLabel.TextWrapped = true
selectedLabel.TextXAlignment = Enum.TextXAlignment.Left
selectedLabel.TextYAlignment = Enum.TextYAlignment.Center
selectedLabel.Text = "  Pick 1-5 ingredients"
selectedLabel.Parent = card

local selectedCorner = Instance.new("UICorner")
selectedCorner.CornerRadius = UDim.new(0, 6)
selectedCorner.Parent = selectedLabel

-- Brew + Cancel buttons ----------------------------------------------------
local cancel = Instance.new("TextButton")
cancel.AnchorPoint = Vector2.new(0, 1)
cancel.Position = UDim2.new(0, 0, 1, 0)
cancel.Size = UDim2.new(0.45, 0, 0, 40)
cancel.BackgroundColor3 = Color3.fromRGB(60, 50, 65)
cancel.Text = "Cancel"
cancel.TextColor3 = Color3.fromRGB(245, 240, 230)
cancel.Font = Enum.Font.GothamMedium
cancel.TextSize = 16
cancel.Parent = card
local cancelCorner = Instance.new("UICorner")
cancelCorner.CornerRadius = UDim.new(0, 8)
cancelCorner.Parent = cancel

local brew = Instance.new("TextButton")
brew.AnchorPoint = Vector2.new(1, 1)
brew.Position = UDim2.new(1, 0, 1, 0)
brew.Size = UDim2.new(0.5, 0, 0, 40)
brew.BackgroundColor3 = Color3.fromRGB(120, 60, 140)
brew.Text = "Brew"
brew.TextColor3 = Color3.fromRGB(245, 240, 230)
brew.Font = Enum.Font.GothamBold
brew.TextSize = 16
brew.Parent = card
local brewCorner = Instance.new("UICorner")
brewCorner.CornerRadius = UDim.new(0, 8)
brewCorner.Parent = brew

-- ---------- Repaint helpers ------------------------------------------------

repaintMethods = function()
	for method, btn in pairs(methodButtons) do
		local active = (method == currentMethod)
		btn.BackgroundColor3 = active
			and Color3.fromRGB(120, 60, 140)
			or Color3.fromRGB(48, 42, 55)
		btn.TextColor3 = active
			and Color3.fromRGB(245, 240, 230)
			or Color3.fromRGB(180, 170, 190)
	end
end

local function selectedSummary(): string
	if #selected == 0 then
		return "  Pick 1-5 ingredients"
	end
	local parts = {}
	-- Group by id for readability: "BrownCap x3"
	local counts: { [string]: number } = {}
	local order: { string } = {}
	for _, id in ipairs(selected) do
		if counts[id] == nil then
			counts[id] = 0
			table.insert(order, id)
		end
		counts[id] += 1
	end
	for _, id in ipairs(order) do
		local sp = Species.byId[id]
		if sp then
			if counts[id] == 1 then
				table.insert(parts, sp.displayName)
			else
				table.insert(parts, string.format("%s x%d", sp.displayName, counts[id]))
			end
		end
	end
	return "  " .. table.concat(parts, ", ")
end

repaintBrewButton = function()
	local ready = currentMethod ~= nil and #selected > 0 and #selected <= 5
	brew.AutoButtonColor = ready
	brew.Active = ready
	brew.BackgroundColor3 = ready
		and Color3.fromRGB(120, 60, 140)
		or Color3.fromRGB(60, 50, 65)
	brew.TextColor3 = ready
		and Color3.fromRGB(245, 240, 230)
		or Color3.fromRGB(140, 130, 150)
	selectedLabel.Text = selectedSummary()
end

local function close()
	currentMethod = nil
	selected = {}
	screen.Enabled = false
end

local function clearIngredients()
	for _, c in ipairs(ingScroll:GetChildren()) do
		if c:IsA("TextButton") and c.Name:match("^Ing_") then
			c:Destroy()
		end
	end
end

local function buildIngredientRow(speciesId: string, inventoryCount: number, layoutOrder: number)
	local sp = Species.byId[speciesId]
	if not sp then
		return
	end
	local tier = Tiers[sp.tier]

	local row = Instance.new("TextButton")
	row.Name = "Ing_" .. speciesId
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 44)
	row.BackgroundColor3 = Color3.fromRGB(48, 42, 55)
	row.AutoButtonColor = true
	row.Text = ""
	row.Parent = ingScroll

	local rowCorner = Instance.new("UICorner")
	rowCorner.CornerRadius = UDim.new(0, 6)
	rowCorner.Parent = row

	local swatch = Instance.new("Frame")
	swatch.AnchorPoint = Vector2.new(0, 0.5)
	swatch.Position = UDim2.new(0, 10, 0.5, 0)
	swatch.Size = UDim2.fromOffset(14, 14)
	swatch.BackgroundColor3 = tier.displayColor
	swatch.BorderSizePixel = 0
	swatch.Parent = row
	local swatchCorner = Instance.new("UICorner")
	swatchCorner.CornerRadius = UDim.new(1, 0)
	swatchCorner.Parent = swatch

	local name = Instance.new("TextLabel")
	name.AnchorPoint = Vector2.new(0, 0.5)
	name.Position = UDim2.new(0, 32, 0.5, 0)
	name.Size = UDim2.new(1, -110, 1, 0)
	name.BackgroundTransparency = 1
	name.Text = sp.displayName
	name.TextColor3 = Color3.fromRGB(245, 240, 230)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Font = Enum.Font.GothamMedium
	name.TextSize = 14
	name.Parent = row

	local count = Instance.new("TextLabel")
	count.AnchorPoint = Vector2.new(1, 0.5)
	count.Position = UDim2.new(1, -10, 0.5, 0)
	count.Size = UDim2.fromOffset(80, 24)
	count.BackgroundTransparency = 1
	count.TextColor3 = Color3.fromRGB(180, 170, 190)
	count.Font = Enum.Font.Gotham
	count.TextSize = 13
	count.TextXAlignment = Enum.TextXAlignment.Right
	count.Parent = row

	local function refreshCount()
		local picked = 0
		for _, id in ipairs(selected) do
			if id == speciesId then
				picked += 1
			end
		end
		count.Text = string.format("inv %d / picked %d", inventoryCount, picked)
	end
	refreshCount()

	row.Activated:Connect(function()
		-- Adding logic: if the player has enough, and total picks < 5,
		-- and the row's "picked" count is less than inventory count,
		-- add one. Tapping a row that's at its inventory cap resets it
		-- to zero (lets players un-pick without a separate UI control).
		local picked = 0
		for _, id in ipairs(selected) do
			if id == speciesId then
				picked += 1
			end
		end
		if picked >= inventoryCount or #selected >= 5 then
			-- Reset this row's selections.
			local newSel: { string } = {}
			for _, id in ipairs(selected) do
				if id ~= speciesId then
					table.insert(newSel, id)
				end
			end
			selected = newSel
		else
			table.insert(selected, speciesId)
		end
		refreshCount()
		repaintBrewButton()
	end)
end

local function repopulateIngredients()
	clearIngredients()
	local entries = {}
	for speciesId, n in pairs(latestData.inventory or {}) do
		if Species.byId[speciesId] and n > 0 then
			table.insert(entries, { id = speciesId, count = n })
		end
	end
	-- Sort by display name for predictability.
	table.sort(entries, function(a, b)
		return Species.byId[a.id].displayName < Species.byId[b.id].displayName
	end)
	for i, e in ipairs(entries) do
		buildIngredientRow(e.id, e.count, i)
	end
	if #entries == 0 then
		local empty = Instance.new("TextLabel")
		empty.Name = "Ing_Empty"
		empty.Size = UDim2.new(1, 0, 0, 80)
		empty.BackgroundTransparency = 1
		empty.Text = "No mushrooms in inventory.\nHarvest some to brew."
		empty.TextWrapped = true
		empty.TextColor3 = Color3.fromRGB(170, 160, 180)
		empty.Font = Enum.Font.Gotham
		empty.TextSize = 14
		empty.Parent = ingScroll
	end
end

-- Build method buttons once now that helpers exist.
do
	local order = 1
	for _, method in ipairs(Recipes.METHODS) do
		methodButtons[method] = makeMethodButton(method, Recipes.METHOD_DISPLAY[method] or method, order)
		order += 1
	end
	repaintMethods()
end

-- ---------- Open / close --------------------------------------------------

local function open()
	currentMethod = nil
	selected = {}
	repaintMethods()
	repopulateIngredients()
	repaintBrewButton()
	screen.Enabled = true
end

cancel.Activated:Connect(close)
overlay.Activated:Connect(close)

brew.Activated:Connect(function()
	if currentMethod == nil or #selected == 0 or #selected > 5 then
		return
	end
	-- Snapshot then close. Server is the source of truth; if it fails,
	-- the brew toast will tell the user.
	local methodSnapshot = currentMethod
	local idsSnapshot = table.clone(selected)
	close()
	Remotes.get(Constants.REMOTES.Brew):FireServer(methodSnapshot, idsSnapshot)
end)

-- ---------- Game state hookup ---------------------------------------------

Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(function(data)
	latestData = data
	if screen.Enabled then
		-- Inventory changed while picker is open (e.g. brew result) —
		-- repopulate so picked counts re-validate against the new inv.
		-- Safest: clear selection, re-render. Players will rarely hit
		-- this since brewing closes the picker.
		selected = {}
		repopulateIngredients()
		repaintBrewButton()
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "BrewPrompt" then
		open()
	end
end)
