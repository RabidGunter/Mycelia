-- Shop UI — shared client component for every merchant interaction.
--
-- Wire flow:
--   1. Server fires OpenShop({npcId}) when player triggers a merchant prompt.
--   2. We open the modal, populate Sell tab with the player's eligible
--      inventory (preselected at full quantity per the "sell all default"
--      UX rule — see docs/specs/shop-ui.md).
--   3. Player confirms → fire SellToMerchant or BuyFromMerchant.
--   4. Server replies ShopTransactionCompleted with breakdown → close +
--      flash a confirmation toast.
--
-- Visual tokens come from Constants.UI (see docs/specs/visual-language.md).
-- Constructed with plain Roblox Instance code to match the existing client
-- conventions (BrewController, JournalController, PotionController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local UI = Constants.UI
local C = UI.color
local FONT = UI.typography
local SP = UI.space

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------- Replicated player data cache ---------------------------------

local latestData: any = { inventory = {}, coins = 0 }
local pendingMerchant: any = nil
local pendingNpcId: string? = nil
local pendingTab: string = "Sell"
local sellQty: { [string]: number } = {}    -- species id -> selected qty
local buyQty: { [string]: number } = {}     -- item id -> selected qty

local function inventoryEntries(merchant)
	local rows = {}
	if not latestData.inventory then return rows end
	-- Witch only buys mushrooms_raw — every species id in `data.inventory`
	-- is eligible. When other categories ship, filter against merchant
	-- config (the server-side Shop.canSell handles the canonical check).
	for speciesId, count in pairs(latestData.inventory) do
		if Species.byId[speciesId] and count > 0 then
			table.insert(rows, { id = speciesId, owned = count })
		end
	end
	table.sort(rows, function(a, b)
		return Species.byId[a.id].displayName < Species.byId[b.id].displayName
	end)
	return rows
end

local function listingEntries(merchant)
	local rows = {}
	if not merchant.itemsForSale then return rows end
	for itemId, listing in pairs(merchant.itemsForSale) do
		table.insert(rows, { id = itemId, listing = listing })
	end
	table.sort(rows, function(a, b)
		return (a.listing.unitPrice or 0) < (b.listing.unitPrice or 0)
	end)
	return rows
end

-- ---------- ScreenGui scaffolding ----------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "ShopUI"
screen.ResetOnSpawn = false
screen.DisplayOrder = 12
screen.Enabled = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

-- Separate always-on ScreenGui for transaction toasts. Lives independent of
-- the modal so closeShop()'s screen.Enabled=false doesn't immediately hide
-- the "+N coins" pop-up that fires alongside it.
local toastScreen = Instance.new("ScreenGui")
toastScreen.Name = "ShopToast"
toastScreen.ResetOnSpawn = false
toastScreen.DisplayOrder = 13       -- above the modal
toastScreen.IgnoreGuiInset = true
toastScreen.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = C.forest.ink
overlay.BackgroundTransparency = 0.55
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = screen

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.92, 0, 0.85, 0)
card.BackgroundColor3 = C.surface.panel
card.BorderSizePixel = 0
card.Parent = screen

local cardSize = Instance.new("UISizeConstraint")
cardSize.MaxSize = Vector2.new(440, 640)
cardSize.MinSize = Vector2.new(280, 420)
cardSize.Parent = card

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, UI.radius.card)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Color = C.surface.divider
cardStroke.Thickness = 1
cardStroke.Parent = card

local cardPad = Instance.new("UIPadding")
cardPad.PaddingTop = UDim.new(0, SP.lg)
cardPad.PaddingBottom = UDim.new(0, SP.lg)
cardPad.PaddingLeft = UDim.new(0, SP.lg)
cardPad.PaddingRight = UDim.new(0, SP.lg)
cardPad.Parent = card

-- ---------- Header -------------------------------------------------------

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "Shop"
title.TextColor3 = C.text.primary
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = FONT.display.font
title.TextSize = 22
title.Parent = card

local subtitle = Instance.new("TextLabel")
subtitle.Position = UDim2.new(0, 0, 0, 32)
subtitle.Size = UDim2.new(1, 0, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = ""
subtitle.TextColor3 = C.text.secondary
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Font = FONT.caption.font
subtitle.TextSize = FONT.caption.size
subtitle.Parent = card

-- ---------- Tabs ---------------------------------------------------------

local tabStrip = Instance.new("Frame")
tabStrip.Position = UDim2.new(0, 0, 0, 56)
tabStrip.Size = UDim2.new(1, 0, 0, 32)
tabStrip.BackgroundTransparency = 1
tabStrip.Parent = card

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, SP.md)
tabLayout.Parent = tabStrip

local function makeTab(name: string)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.fromOffset(80, 32)
	btn.BackgroundTransparency = 1
	btn.Text = name
	btn.TextColor3 = C.text.secondary
	btn.Font = FONT.button.font
	btn.TextSize = FONT.button.size
	btn.AutoButtonColor = false
	btn.Parent = tabStrip
	local underline = Instance.new("Frame")
	underline.Name = "Underline"
	underline.AnchorPoint = Vector2.new(0, 1)
	underline.Position = UDim2.new(0, 0, 1, 0)
	underline.Size = UDim2.new(1, 0, 0, 2)
	underline.BackgroundColor3 = C.accent.primary
	underline.BorderSizePixel = 0
	underline.Visible = false
	underline.Parent = btn
	return btn
end

local sellTab = makeTab("Sell")
local buyTab = makeTab("Buy")

-- ---------- Body (scrolling list) ---------------------------------------

local body = Instance.new("ScrollingFrame")
body.Position = UDim2.new(0, 0, 0, 96)
body.Size = UDim2.new(1, 0, 1, -96 - 96)  -- header+tabs above, footer below
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.ScrollBarImageColor3 = C.surface.divider
body.CanvasSize = UDim2.new(0, 0, 0, 0)
body.Parent = card

local bodyLayout = Instance.new("UIListLayout")
bodyLayout.Padding = UDim.new(0, SP.sm)
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Parent = body
bodyLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	body.CanvasSize = UDim2.new(0, 0, 0, bodyLayout.AbsoluteContentSize.Y)
end)

local function clearBody()
	for _, child in ipairs(body:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
end

-- ---------- Footer (total + buttons) ------------------------------------

local footer = Instance.new("Frame")
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 0, 1, 0)
footer.Size = UDim2.new(1, 0, 0, 88)
footer.BackgroundTransparency = 1
footer.Parent = card

local totalLabel = Instance.new("TextLabel")
totalLabel.Size = UDim2.new(1, 0, 0, 28)
totalLabel.BackgroundTransparency = 1
totalLabel.Text = "Total  0"
totalLabel.TextColor3 = C.accent.gold
totalLabel.TextXAlignment = Enum.TextXAlignment.Right
totalLabel.Font = FONT.numeric.font
totalLabel.TextSize = 18
totalLabel.Parent = footer

local buttonsRow = Instance.new("Frame")
buttonsRow.Position = UDim2.new(0, 0, 0, 36)
buttonsRow.Size = UDim2.new(1, 0, 0, 48)
buttonsRow.BackgroundTransparency = 1
buttonsRow.Parent = footer

local buttonsLayout = Instance.new("UIListLayout")
buttonsLayout.FillDirection = Enum.FillDirection.Horizontal
buttonsLayout.Padding = UDim.new(0, SP.md)
buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
buttonsLayout.Parent = buttonsRow

local function makeButton(text: string, primary: boolean)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(120, 44)
	btn.BackgroundColor3 = primary and C.accent.primary or C.surface.recessed
	btn.Text = text
	btn.TextColor3 = primary and C.text.onAccent or C.text.primary
	btn.Font = FONT.button.font
	btn.TextSize = FONT.button.size
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.Parent = buttonsRow
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI.radius.button)
	corner.Parent = btn
	return btn
end

local cancelBtn = makeButton("Cancel", false)
local confirmBtn = makeButton("Confirm", true)

-- ---------- Toast (briefly shown after a transaction) ------------------

local function showToast(text: string, success: boolean)
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Position = UDim2.fromScale(0.5, 0.4)
	toast.Size = UDim2.fromOffset(280, 56)
	toast.BackgroundColor3 = success and C.state.success or C.state.error
	toast.Text = text
	toast.TextColor3 = C.text.onAccent
	toast.Font = FONT.button.font
	toast.TextSize = FONT.button.size
	toast.BorderSizePixel = 0
	-- Parented to toastScreen (independent of the modal) so closeShop()
	-- doesn't immediately hide it.
	toast.Parent = toastScreen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI.radius.button)
	corner.Parent = toast
	-- Slow the tween so the player has time to read the result.
	local tween = TweenService:Create(toast,
		TweenInfo.new(2.0, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.30), TextTransparency = 1, BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function() toast:Destroy() end)
end

-- ---------- Row builders -------------------------------------------------

local function buildSellRow(speciesId: string, owned: number, layoutOrder: number)
	local species = Species.byId[speciesId]
	if not species then return end
	local rarityColor = UI.rarity[species.tier] or C.forest.sage

	local row = Instance.new("Frame")
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = C.surface.recessed
	row.BorderSizePixel = 0
	row.Parent = body
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI.radius.chip)
	corner.Parent = row
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, SP.md)
	pad.PaddingRight = UDim.new(0, SP.md)
	pad.Parent = row

	local dot = Instance.new("Frame")
	dot.AnchorPoint = Vector2.new(0, 0.5)
	dot.Position = UDim2.new(0, 0, 0.5, 0)
	dot.Size = UDim2.fromOffset(8, 8)
	dot.BackgroundColor3 = rarityColor
	dot.BorderSizePixel = 0
	dot.Parent = row
	local dotCorner = Instance.new("UICorner")
	dotCorner.CornerRadius = UDim.new(1, 0)
	dotCorner.Parent = dot

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Position = UDim2.new(0, 18, 0, 6)
	nameLbl.Size = UDim2.new(1, -180, 0, 18)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = species.displayName
	nameLbl.TextColor3 = C.text.primary
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Font = FONT.body.font
	nameLbl.TextSize = FONT.body.size
	nameLbl.Parent = row

	local ownedLbl = Instance.new("TextLabel")
	ownedLbl.Position = UDim2.new(0, 18, 0, 26)
	ownedLbl.Size = UDim2.new(1, -180, 0, 16)
	ownedLbl.BackgroundTransparency = 1
	ownedLbl.Text = "Owned " .. tostring(owned)
	ownedLbl.TextColor3 = C.text.secondary
	ownedLbl.TextXAlignment = Enum.TextXAlignment.Left
	ownedLbl.Font = FONT.caption.font
	ownedLbl.TextSize = FONT.caption.size
	ownedLbl.Parent = row

	local qtyLabel = Instance.new("TextLabel")
	qtyLabel.AnchorPoint = Vector2.new(1, 0.5)
	qtyLabel.Position = UDim2.new(1, -88, 0.5, 0)
	qtyLabel.Size = UDim2.fromOffset(40, 28)
	qtyLabel.BackgroundTransparency = 1
	qtyLabel.Text = tostring(sellQty[speciesId] or owned)
	qtyLabel.TextColor3 = C.text.primary
	qtyLabel.Font = FONT.numeric.font
	qtyLabel.TextSize = FONT.numeric.size
	qtyLabel.Parent = row

	local function makeStep(text: string, dx: number)
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, dx, 0.5, 0)
		btn.Size = UDim2.fromOffset(28, 28)
		btn.BackgroundColor3 = C.surface.bg
		btn.Text = text
		btn.TextColor3 = C.text.primary
		btn.Font = FONT.button.font
		btn.TextSize = 14
		btn.AutoButtonColor = true
		btn.BorderSizePixel = 0
		btn.Parent = row
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, UI.radius.chip) c.Parent = btn
		return btn
	end

	local minus = makeStep("-", -52)
	local plus  = makeStep("+", 0)

	local function setQty(newQty)
		newQty = math.clamp(math.floor(newQty), 0, owned)
		sellQty[speciesId] = newQty
		qtyLabel.Text = tostring(newQty)
		Shop_recomputeTotal()  -- forward declared below
	end
	minus.Activated:Connect(function() setQty((sellQty[speciesId] or 0) - 1) end)
	plus.Activated:Connect(function() setQty((sellQty[speciesId] or 0) + 1) end)

	-- Default: full inventory preselected (the "sell all default" rule).
	if sellQty[speciesId] == nil then
		sellQty[speciesId] = owned
	end
end

local function buildBuyRow(itemId: string, listing: any, layoutOrder: number)
	local row = Instance.new("Frame")
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = C.surface.recessed
	row.BorderSizePixel = 0
	row.Parent = body
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, UI.radius.chip) corner.Parent = row
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, SP.md) pad.PaddingRight = UDim.new(0, SP.md) pad.Parent = row

	local nameLbl = Instance.new("TextLabel")
	nameLbl.Position = UDim2.new(0, 0, 0, 6)
	nameLbl.Size = UDim2.new(1, -180, 0, 18)
	nameLbl.BackgroundTransparency = 1
	nameLbl.Text = listing.displayName or itemId
	nameLbl.TextColor3 = C.text.primary
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.Font = FONT.body.font
	nameLbl.TextSize = FONT.body.size
	nameLbl.Parent = row

	local priceLbl = Instance.new("TextLabel")
	priceLbl.Position = UDim2.new(0, 0, 0, 26)
	priceLbl.Size = UDim2.new(1, -180, 0, 16)
	priceLbl.BackgroundTransparency = 1
	priceLbl.Text = string.format("%d coins each", listing.unitPrice or 0)
	priceLbl.TextColor3 = C.text.secondary
	priceLbl.TextXAlignment = Enum.TextXAlignment.Left
	priceLbl.Font = FONT.caption.font
	priceLbl.TextSize = FONT.caption.size
	priceLbl.Parent = row

	local qtyLabel = Instance.new("TextLabel")
	qtyLabel.AnchorPoint = Vector2.new(1, 0.5)
	qtyLabel.Position = UDim2.new(1, -88, 0.5, 0)
	qtyLabel.Size = UDim2.fromOffset(40, 28)
	qtyLabel.BackgroundTransparency = 1
	qtyLabel.Text = tostring(buyQty[itemId] or 0)
	qtyLabel.TextColor3 = C.text.primary
	qtyLabel.Font = FONT.numeric.font
	qtyLabel.TextSize = FONT.numeric.size
	qtyLabel.Parent = row

	local function step(text, dx, delta)
		local btn = Instance.new("TextButton")
		btn.AnchorPoint = Vector2.new(1, 0.5)
		btn.Position = UDim2.new(1, dx, 0.5, 0)
		btn.Size = UDim2.fromOffset(28, 28)
		btn.BackgroundColor3 = C.surface.bg
		btn.Text = text
		btn.TextColor3 = C.text.primary
		btn.Font = FONT.button.font
		btn.TextSize = 14
		btn.BorderSizePixel = 0
		btn.Parent = row
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, UI.radius.chip) c.Parent = btn
		btn.Activated:Connect(function()
			local nv = math.max(0, (buyQty[itemId] or 0) + delta)
			buyQty[itemId] = nv
			qtyLabel.Text = tostring(nv)
			Shop_recomputeTotal()
		end)
	end
	step("-", -52, -1)
	step("+", 0, 1)

	if buyQty[itemId] == nil then buyQty[itemId] = 0 end
end

-- ---------- Total recompute + tab switch -------------------------------

local function priceFor(speciesId: string, merchant): number
	local species = Species.byId[speciesId]
	if not species then return 0 end
	local Tiers = require(ReplicatedStorage.Shared.Tiers)
	local tier = Tiers[species.tier]
	if not tier then return 0 end
	return math.floor(species.baseSellPrice * tier.sellMultiplier * (merchant.buyMultiplier or 1))
end

function Shop_recomputeTotal()
	if not pendingMerchant then return end
	local total = 0
	if pendingTab == "Sell" then
		for id, qty in pairs(sellQty) do
			total += priceFor(id, pendingMerchant) * qty
		end
		totalLabel.Text = string.format("Total  +%d", total)
		totalLabel.TextColor3 = C.accent.gold
	else
		for id, qty in pairs(buyQty) do
			local listing = pendingMerchant.itemsForSale and pendingMerchant.itemsForSale[id]
			if listing then total += (listing.unitPrice or 0) * qty end
		end
		totalLabel.Text = string.format("Total  -%d", total)
		totalLabel.TextColor3 = total > (latestData.coins or 0) and C.state.error or C.accent.gold
	end
end

local function setTab(name: string)
	pendingTab = name
	sellTab:FindFirstChild("Underline").Visible = name == "Sell"
	buyTab:FindFirstChild("Underline").Visible = name == "Buy"
	sellTab.TextColor3 = name == "Sell" and C.text.primary or C.text.secondary
	buyTab.TextColor3 = name == "Buy" and C.text.primary or C.text.secondary
	clearBody()
	if name == "Sell" then
		local rows = inventoryEntries(pendingMerchant)
		if #rows == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 56)
			empty.BackgroundTransparency = 1
			empty.Text = "No mushrooms to sell."
			empty.TextColor3 = C.text.muted
			empty.Font = FONT.body.font
			empty.TextSize = FONT.body.size
			empty.Parent = body
		else
			for i, r in ipairs(rows) do buildSellRow(r.id, r.owned, i) end
		end
	else
		local rows = listingEntries(pendingMerchant)
		if #rows == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 56)
			empty.BackgroundTransparency = 1
			empty.Text = "Nothing for sale right now."
			empty.TextColor3 = C.text.muted
			empty.Font = FONT.body.font
			empty.TextSize = FONT.body.size
			empty.Parent = body
		else
			for i, r in ipairs(rows) do buildBuyRow(r.id, r.listing, i) end
		end
	end
	Shop_recomputeTotal()
end

sellTab.Activated:Connect(function() setTab("Sell") end)
buyTab.Activated:Connect(function() setTab("Buy") end)

-- ---------- Open / close -------------------------------------------------

local function openShop(npcId: string)
	local merchant = Constants.MERCHANTS[npcId]
	if not merchant then
		warn("[ShopUI] Unknown merchant: " .. tostring(npcId))
		return
	end
	pendingMerchant = merchant
	pendingNpcId = npcId
	sellQty = {}
	buyQty = {}
	title.Text = merchant.displayName or npcId
	subtitle.Text = merchant.description or ""
	-- Hide Buy tab when no items for sale (witch's case in Phase 2).
	local hasBuy = false
	if merchant.itemsForSale then
		for _ in pairs(merchant.itemsForSale) do hasBuy = true break end
	end
	buyTab.Visible = hasBuy
	setTab("Sell")
	screen.Enabled = true
end

local function closeShop()
	screen.Enabled = false
	pendingMerchant = nil
	pendingNpcId = nil
	sellQty = {}
	buyQty = {}
end

cancelBtn.Activated:Connect(closeShop)
overlay.Activated:Connect(closeShop)

confirmBtn.Activated:Connect(function()
	if not pendingMerchant or not pendingNpcId then return end
	local npcId = pendingNpcId
	if pendingTab == "Sell" then
		local items = {}
		local any = false
		for id, qty in pairs(sellQty) do
			if qty > 0 then items[id] = qty; any = true end
		end
		if not any then return end
		Remotes.get(Constants.REMOTES.SellToMerchant):FireServer(npcId, items)
	else
		local items = {}
		local any = false
		for id, qty in pairs(buyQty) do
			if qty > 0 then items[id] = qty; any = true end
		end
		if not any then return end
		Remotes.get(Constants.REMOTES.BuyFromMerchant):FireServer(npcId, items)
	end
end)

-- ---------- Server hooks -------------------------------------------------

Remotes.get(Constants.REMOTES.OpenShop).OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	openShop(payload.npcId)
end)

Remotes.get(Constants.REMOTES.ShopTransactionCompleted).OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.success then
		local delta = payload.coinDelta or 0
		local sign = delta >= 0 and "+" or "-"
		showToast(string.format("%s%d coins", sign, math.abs(delta)), true)
		closeShop()
	else
		showToast("Transaction failed: " .. tostring(payload.code), false)
	end
end)

Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(function(data)
	latestData = data or { inventory = {}, coins = 0 }
	if screen.Enabled and pendingMerchant then
		-- Refresh row data without resetting user's qty selections.
		setTab(pendingTab)
	end
end)
