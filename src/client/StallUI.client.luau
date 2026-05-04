-- Player Stalls client UI (Wave 3b).
--
-- Three modes share a single modal:
--   1. Owner UI    — opens via OpenStallOwnerUI (server) or via own-plot
--                    ProximityPrompt. 3 tabs: Listings / Mailbox / Featured.
--                    Plus item picker submodal when adding a new listing.
--   2. Buyer UI    — opens via OpenStallBuyerUI when a player triggers
--                    another player's stall stand prompt.
--   3. Plot Directory — opens via HUD "Marketplace" button. 2 tabs:
--                    Featured (rented sellers in the central row) +
--                    Recent Sales (chronological feed of last 20 sales).
--
-- Spec: docs/specs/player-stalls.md.
-- Plan: .planning/phases/02-closed-beta-social-systems-content/02-04-PLAN.md.

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
local STALL = Constants.STALL

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------- Replicated state ----------------------------------------------

local latestData: any = { coins = 0, inventory = {}, inventoryByCategory = {}, stalls = nil }
local lastSeenOverflowSince: number? = nil   -- dedup overflow toast
local currentMode: string? = nil
local currentPayload: any = nil

-- Item picker state. Module-scope so it persists across `setMode("itemPicker")`
-- rebuilds (each rebuild rerenders the row highlight + retains the user's
-- typed qty/price).
local pickerItem: string? = nil
local pickerQty: number = 1
local pickerPrice: number = 10

-- ---------- STALL_ERROR_MESSAGES (W-5) ------------------------------------

local STALL_ERROR_MESSAGES = {
	SLOT_FULL              = "You're already using all 4 listing slots. Cancel one to free space.",
	INSUFFICIENT_INVENTORY = "You don't have enough of that item to list.",
	ITEM_NOT_TRADABLE      = "That item can't be sold at a stall.",
	INVALID_PRICE          = string.format("Price must be between %d and 1,000,000,000 coins.", STALL.minPrice),
	INVALID_REQUEST        = "Something went wrong with that request.",
	LISTING_GONE           = "That listing was already bought or removed.",
	INSUFFICIENT_COINS     = "You don't have enough coins.",
	SELF_PURCHASE          = "You can't buy from your own stall.",
	NOT_OWNER              = "You don't own that listing.",
	FEATURED_FULL          = "All 12 featured slots are taken right now. Try again in a few minutes.",
	ALREADY_FEATURED       = "You already have a featured slot.",
	RATE_LIMITED           = "Slow down a moment, then try again.",
	MUTATION_FAILED        = "Couldn't complete that. Try again in a moment.",
}

-- ---------- ScreenGuis ---------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "StallUI"
screen.ResetOnSpawn = false
screen.DisplayOrder = 12
screen.Enabled = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

local toastScreen = Instance.new("ScreenGui")
toastScreen.Name = "StallToast"
toastScreen.ResetOnSpawn = false
toastScreen.DisplayOrder = 14
toastScreen.IgnoreGuiInset = true
toastScreen.Parent = playerGui

local hudScreen = Instance.new("ScreenGui")
hudScreen.Name = "StallHUD"
hudScreen.ResetOnSpawn = false
hudScreen.DisplayOrder = 6        -- below modals (12+) but above world
hudScreen.IgnoreGuiInset = false
hudScreen.Parent = playerGui

-- ---------- Toast helper -------------------------------------------------

local function showToast(text: string, success: boolean)
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0.5)
	toast.Position = UDim2.fromScale(0.5, 0.4)
	toast.Size = UDim2.fromOffset(320, 56)
	toast.BackgroundColor3 = success and C.state.success or C.state.error
	toast.Text = text
	toast.TextColor3 = C.text.onAccent
	toast.Font = FONT.button.font
	toast.TextSize = FONT.button.size
	toast.TextWrapped = true
	toast.BorderSizePixel = 0
	toast.Parent = toastScreen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI.radius.button)
	corner.Parent = toast
	local tween = TweenService:Create(toast,
		TweenInfo.new(2.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = UDim2.fromScale(0.5, 0.30), TextTransparency = 1, BackgroundTransparency = 1 }
	)
	tween:Play()
	tween.Completed:Connect(function() toast:Destroy() end)
end

local function showError(code: string)
	showToast(STALL_ERROR_MESSAGES[code] or ("Something went wrong: " .. tostring(code)), false)
end

-- ---------- Modal scaffolding --------------------------------------------

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = C.forest.ink
overlay.BackgroundTransparency = 0.55
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = screen

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.92, 0, 0.85, 0)
card.BackgroundColor3 = C.surface.panel
card.BorderSizePixel = 0
card.Parent = screen

local cardSize = Instance.new("UISizeConstraint")
cardSize.MaxSize = Vector2.new(520, 720)
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

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = ""
title.TextColor3 = C.text.primary
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = FONT.display.font
title.TextSize = 22
title.Parent = card

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Position = UDim2.new(0, 0, 0, 32)
subtitle.Size = UDim2.new(1, 0, 0, 18)
subtitle.BackgroundTransparency = 1
subtitle.Text = ""
subtitle.TextColor3 = C.text.secondary
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Font = FONT.caption.font
subtitle.TextSize = FONT.caption.size
subtitle.Parent = card

local closeBtn = Instance.new("TextButton")
closeBtn.Name = "Close"
closeBtn.AnchorPoint = Vector2.new(1, 0)
closeBtn.Position = UDim2.new(1, 0, 0, 0)
closeBtn.Size = UDim2.fromOffset(32, 32)
closeBtn.BackgroundTransparency = 1
closeBtn.Text = "✕"
closeBtn.TextColor3 = C.text.secondary
closeBtn.Font = FONT.button.font
closeBtn.TextSize = 24
closeBtn.AutoButtonColor = false
closeBtn.Parent = card

-- Body container — every mode rebuilds this on entry.
local body = Instance.new("Frame")
body.Name = "Body"
body.Position = UDim2.new(0, 0, 0, 60)
body.Size = UDim2.new(1, 0, 1, -60)
body.BackgroundTransparency = 1
body.Parent = card

local function clearBody()
	for _, child in ipairs(body:GetChildren()) do child:Destroy() end
end

local function closeUI()
	screen.Enabled = false
	currentMode = nil
	currentPayload = nil
end

closeBtn.Activated:Connect(closeUI)
overlay.Activated:Connect(closeUI)

-- ---------- Common widget helpers ----------------------------------------

local function makeButton(parent, text, primary)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(0, 36)
	btn.AutomaticSize = Enum.AutomaticSize.X
	btn.BackgroundColor3 = primary and C.accent.primary or C.surface.divider
	btn.Text = "  " .. text .. "  "
	btn.TextColor3 = primary and C.text.onAccent or C.text.primary
	btn.Font = FONT.button.font
	btn.TextSize = FONT.button.size
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI.radius.button)
	corner.Parent = btn
	return btn
end

local function makeScrollList(parent)
	local sf = Instance.new("ScrollingFrame")
	sf.Size = UDim2.new(1, 0, 1, 0)
	sf.BackgroundTransparency = 1
	sf.BorderSizePixel = 0
	sf.ScrollBarThickness = 4
	sf.ScrollBarImageColor3 = C.surface.divider
	sf.CanvasSize = UDim2.new(0, 0, 0, 0)
	sf.AutomaticCanvasSize = Enum.AutomaticSize.Y
	sf.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, SP.sm)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = sf
	return sf
end

local function formatTimeRemaining(secondsLeft: number): string
	if secondsLeft <= 0 then return "expired" end
	local h = math.floor(secondsLeft / 3600)
	local m = math.floor((secondsLeft % 3600) / 60)
	if h > 0 then
		return string.format("%dh %dm", h, m)
	end
	if m > 0 then
		return string.format("%dm", m)
	end
	return string.format("%ds", math.floor(secondsLeft))
end

local function itemDisplayName(itemId: string): string
	local sp = Species.byId[itemId]
	if sp then return sp.displayName end
	local def = Constants.ITEMS[itemId]
	if def and def.displayName then return def.displayName end
	return itemId
end

-- ---------- Owner UI -----------------------------------------------------

local setMode  -- forward declaration

local function buildOwnerListingsTab()
	local stalls = (latestData and latestData.stalls) or {}
	local listings = stalls.listings or {}

	-- 4-slot grid: 2 columns x 2 rows
	local grid = Instance.new("Frame")
	grid.Size = UDim2.new(1, 0, 1, -8)
	grid.BackgroundTransparency = 1
	grid.Parent = body

	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.new(0.5, -6, 0, 110)
	layout.CellPadding = UDim2.new(0, 8, 0, 8)
	layout.Parent = grid

	-- Collect listings into ordered array (consistent slot positions)
	local listingArray = {}
	for id, listing in pairs(listings) do
		table.insert(listingArray, { id = id, listing = listing })
	end
	table.sort(listingArray, function(a, b)
		return (a.listing.listedAt or 0) < (b.listing.listedAt or 0)
	end)

	for slot = 1, STALL.slotCount do
		local slotFrame = Instance.new("Frame")
		slotFrame.Size = UDim2.new(0, 0, 0, 0)  -- grid layout sizes it
		slotFrame.BackgroundColor3 = C.surface.elevated or C.surface.panel
		slotFrame.BorderSizePixel = 0
		slotFrame.LayoutOrder = slot
		slotFrame.Parent = grid
		local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, UI.radius.button) sc.Parent = slotFrame
		local sp = Instance.new("UIPadding")
		sp.PaddingLeft = UDim.new(0, SP.sm) sp.PaddingRight = UDim.new(0, SP.sm)
		sp.PaddingTop = UDim.new(0, SP.sm) sp.PaddingBottom = UDim.new(0, SP.sm)
		sp.Parent = slotFrame

		local entry = listingArray[slot]
		if entry then
			-- Filled slot
			local nameLbl = Instance.new("TextLabel")
			nameLbl.Size = UDim2.new(1, 0, 0, 18)
			nameLbl.BackgroundTransparency = 1
			nameLbl.Text = itemDisplayName(entry.listing.itemId)
			nameLbl.TextColor3 = C.text.primary
			nameLbl.TextXAlignment = Enum.TextXAlignment.Left
			nameLbl.Font = FONT.button.font
			nameLbl.TextSize = 14
			nameLbl.Parent = slotFrame

			local qtyLbl = Instance.new("TextLabel")
			qtyLbl.Position = UDim2.new(0, 0, 0, 22)
			qtyLbl.Size = UDim2.new(1, 0, 0, 16)
			qtyLbl.BackgroundTransparency = 1
			qtyLbl.Text = string.format("%d × %d coins", entry.listing.qty or 0, entry.listing.unitPrice or 0)
			qtyLbl.TextColor3 = C.accent.gold
			qtyLbl.TextXAlignment = Enum.TextXAlignment.Left
			qtyLbl.Font = FONT.caption.font
			qtyLbl.TextSize = FONT.caption.size
			qtyLbl.Parent = slotFrame

			local timeLbl = Instance.new("TextLabel")
			timeLbl.Position = UDim2.new(0, 0, 0, 42)
			timeLbl.Size = UDim2.new(1, 0, 0, 14)
			timeLbl.BackgroundTransparency = 1
			local secondsLeft = (entry.listing.expiresAt or 0) - os.time()
			timeLbl.Text = "Expires in " .. formatTimeRemaining(secondsLeft)
			timeLbl.TextColor3 = C.text.secondary
			timeLbl.TextXAlignment = Enum.TextXAlignment.Left
			timeLbl.Font = FONT.caption.font
			timeLbl.TextSize = 11
			timeLbl.Parent = slotFrame

			local cancelBtn = makeButton(slotFrame, "Cancel", false)
			cancelBtn.AnchorPoint = Vector2.new(0, 1)
			cancelBtn.Position = UDim2.new(0, 0, 1, 0)
			cancelBtn.Size = UDim2.new(1, 0, 0, 28)
			cancelBtn.Activated:Connect(function()
				Remotes.get(Constants.REMOTES.CancelListing):FireServer(entry.id)
			end)
		else
			-- Empty slot — Add button
			local addBtn = Instance.new("TextButton")
			addBtn.Size = UDim2.new(1, 0, 1, 0)
			addBtn.BackgroundColor3 = C.surface.panel
			addBtn.Text = "+ Add Listing"
			addBtn.TextColor3 = C.text.secondary
			addBtn.Font = FONT.button.font
			addBtn.TextSize = FONT.button.size
			addBtn.AutoButtonColor = true
			addBtn.BorderSizePixel = 0
			addBtn.Parent = slotFrame
			local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0, UI.radius.button) ac.Parent = addBtn
			local stroke = Instance.new("UIStroke")
			stroke.Color = C.surface.divider
			stroke.Thickness = 1
			stroke.Parent = addBtn
			addBtn.Activated:Connect(function()
				setMode("itemPicker")
			end)
		end
	end
end

local function buildOwnerMailboxTab()
	local stalls = (latestData and latestData.stalls) or {}
	local mailbox = stalls.mailbox or { coins = 0, items = {}, sales = {} }

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, -8)
	frame.BackgroundTransparency = 1
	frame.Parent = body

	-- Header: total earnings + claim button
	local coinLbl = Instance.new("TextLabel")
	coinLbl.Size = UDim2.new(1, -120, 0, 40)
	coinLbl.BackgroundTransparency = 1
	coinLbl.Text = string.format("Mailbox: %d coins", mailbox.coins or 0)
	coinLbl.TextColor3 = C.accent.gold
	coinLbl.TextXAlignment = Enum.TextXAlignment.Left
	coinLbl.Font = FONT.button.font
	coinLbl.TextSize = 18
	coinLbl.Parent = frame

	local hasSomething = (mailbox.coins or 0) > 0 or next(mailbox.items or {}) ~= nil
	local claimBtn = makeButton(frame, "Claim All", true)
	claimBtn.AnchorPoint = Vector2.new(1, 0)
	claimBtn.Position = UDim2.new(1, 0, 0, 4)
	claimBtn.Size = UDim2.fromOffset(110, 36)
	claimBtn.AutomaticSize = Enum.AutomaticSize.None
	if not hasSomething then
		claimBtn.BackgroundTransparency = 0.6
		claimBtn.AutoButtonColor = false
	end
	claimBtn.Activated:Connect(function()
		if hasSomething then
			Remotes.get(Constants.REMOTES.ClaimMailbox):FireServer()
		end
	end)

	-- Items in mailbox
	local itemsLbl = Instance.new("TextLabel")
	itemsLbl.Position = UDim2.new(0, 0, 0, 50)
	itemsLbl.Size = UDim2.new(1, 0, 0, 18)
	itemsLbl.BackgroundTransparency = 1
	itemsLbl.Text = "Items waiting:"
	itemsLbl.TextColor3 = C.text.secondary
	itemsLbl.TextXAlignment = Enum.TextXAlignment.Left
	itemsLbl.Font = FONT.caption.font
	itemsLbl.TextSize = FONT.caption.size
	itemsLbl.Parent = frame

	local itemCount = 0
	for _ in pairs(mailbox.items or {}) do itemCount += 1 end
	if itemCount == 0 then
		local emptyLbl = Instance.new("TextLabel")
		emptyLbl.Position = UDim2.new(0, 0, 0, 70)
		emptyLbl.Size = UDim2.new(1, 0, 0, 16)
		emptyLbl.BackgroundTransparency = 1
		emptyLbl.Text = "(none)"
		emptyLbl.TextColor3 = C.text.secondary
		emptyLbl.TextXAlignment = Enum.TextXAlignment.Left
		emptyLbl.Font = FONT.caption.font
		emptyLbl.TextSize = FONT.caption.size
		emptyLbl.Parent = frame
	else
		local listFrame = Instance.new("Frame")
		listFrame.Position = UDim2.new(0, 0, 0, 70)
		listFrame.Size = UDim2.new(1, 0, 0, math.min(itemCount * 18 + 4, 80))
		listFrame.BackgroundTransparency = 1
		listFrame.Parent = frame
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 2)
		layout.Parent = listFrame
		for itemId, qty in pairs(mailbox.items or {}) do
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, 0, 0, 16)
			row.BackgroundTransparency = 1
			row.Text = string.format("• %d × %s", qty, itemDisplayName(itemId))
			row.TextColor3 = C.text.primary
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Font = FONT.caption.font
			row.TextSize = FONT.caption.size
			row.Parent = listFrame
		end
	end

	-- Recent sales feed
	local salesLbl = Instance.new("TextLabel")
	salesLbl.Position = UDim2.new(0, 0, 0, 160)
	salesLbl.Size = UDim2.new(1, 0, 0, 18)
	salesLbl.BackgroundTransparency = 1
	salesLbl.Text = "Recent sales:"
	salesLbl.TextColor3 = C.text.secondary
	salesLbl.TextXAlignment = Enum.TextXAlignment.Left
	salesLbl.Font = FONT.caption.font
	salesLbl.TextSize = FONT.caption.size
	salesLbl.Parent = frame

	local salesScroll = Instance.new("ScrollingFrame")
	salesScroll.Position = UDim2.new(0, 0, 0, 180)
	salesScroll.Size = UDim2.new(1, 0, 1, -180)
	salesScroll.BackgroundTransparency = 1
	salesScroll.BorderSizePixel = 0
	salesScroll.ScrollBarThickness = 4
	salesScroll.ScrollBarImageColor3 = C.surface.divider
	salesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	salesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	salesScroll.Parent = frame
	local salesLayout = Instance.new("UIListLayout") salesLayout.Padding = UDim.new(0, 4) salesLayout.Parent = salesScroll

	local sales = mailbox.sales or {}
	if #sales == 0 then
		local none = Instance.new("TextLabel")
		none.Size = UDim2.new(1, 0, 0, 16)
		none.BackgroundTransparency = 1
		none.Text = "(no sales yet)"
		none.TextColor3 = C.text.secondary
		none.TextXAlignment = Enum.TextXAlignment.Left
		none.Font = FONT.caption.font
		none.TextSize = FONT.caption.size
		none.Parent = salesScroll
	else
		for i, sale in ipairs(sales) do
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, 0, 0, 18)
			row.BackgroundTransparency = 1
			row.Text = string.format("• %s bought %d × %s for %d coins",
				sale.buyerName or "?", sale.qty or 0,
				itemDisplayName(sale.itemId or ""), sale.coinsEarned or 0)
			row.TextColor3 = C.text.primary
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Font = FONT.caption.font
			row.TextSize = FONT.caption.size
			row.LayoutOrder = i
			row.Parent = salesScroll
		end
	end
end

local function buildOwnerFeaturedTab()
	local stalls = (latestData and latestData.stalls) or {}
	local expiresAt = stalls.featuredRentExpiresAt
	local now = os.time()

	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(1, 0, 1, -8)
	frame.BackgroundTransparency = 1
	frame.Parent = body

	if expiresAt and expiresAt > now then
		-- Already featured
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 80)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("Featured slot active.\nTime remaining: %s", formatTimeRemaining(expiresAt - now))
		lbl.TextColor3 = C.accent.gold
		lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.TextYAlignment = Enum.TextYAlignment.Center
		lbl.Font = FONT.button.font
		lbl.TextSize = 18
		lbl.TextWrapped = true
		lbl.Parent = frame

		local note = Instance.new("TextLabel")
		note.Position = UDim2.new(0, 0, 0, 100)
		note.Size = UDim2.new(1, 0, 0, 60)
		note.BackgroundTransparency = 1
		note.Text = "Your stall appears in the central row in the Trading Post zone and in the Marketplace directory."
		note.TextColor3 = C.text.secondary
		note.TextXAlignment = Enum.TextXAlignment.Center
		note.Font = FONT.caption.font
		note.TextSize = FONT.caption.size
		note.TextWrapped = true
		note.Parent = frame
	else
		-- Not featured — offer rent
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 0, 60)
		lbl.BackgroundTransparency = 1
		lbl.Text = string.format("Rent a featured slot for %d coins.\nLasts 24 hours.", STALL.featuredFee)
		lbl.TextColor3 = C.text.primary
		lbl.TextXAlignment = Enum.TextXAlignment.Center
		lbl.TextYAlignment = Enum.TextYAlignment.Center
		lbl.Font = FONT.button.font
		lbl.TextSize = 16
		lbl.TextWrapped = true
		lbl.Parent = frame

		local note = Instance.new("TextLabel")
		note.Position = UDim2.new(0, 0, 0, 70)
		note.Size = UDim2.new(1, 0, 0, 50)
		note.BackgroundTransparency = 1
		note.Text = "Featured stalls appear in the central row + Marketplace directory."
		note.TextColor3 = C.text.secondary
		note.TextXAlignment = Enum.TextXAlignment.Center
		note.Font = FONT.caption.font
		note.TextSize = FONT.caption.size
		note.TextWrapped = true
		note.Parent = frame

		local rentBtn = makeButton(frame, string.format("Rent for %d coins", STALL.featuredFee), true)
		rentBtn.AnchorPoint = Vector2.new(0.5, 0)
		rentBtn.Position = UDim2.new(0.5, 0, 0, 130)
		rentBtn.Size = UDim2.fromOffset(220, 40)
		rentBtn.AutomaticSize = Enum.AutomaticSize.None
		local canAfford = (latestData.coins or 0) >= STALL.featuredFee
		if not canAfford then
			rentBtn.BackgroundTransparency = 0.6
			rentBtn.Text = string.format("Need %d coins", STALL.featuredFee)
			rentBtn.AutoButtonColor = false
		end
		rentBtn.Activated:Connect(function()
			if canAfford then
				Remotes.get(Constants.REMOTES.RentFeaturedSlot):FireServer()
			end
		end)
	end
end

-- Tab strip helper for Owner / Directory views
local function buildTabStrip(parent, tabs, currentTab, onSelect)
	local strip = Instance.new("Frame")
	strip.Size = UDim2.new(1, 0, 0, 32)
	strip.BackgroundTransparency = 1
	strip.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, SP.md)
	layout.Parent = strip
	for _, name in ipairs(tabs) do
		local btn = Instance.new("TextButton")
		btn.Name = name
		btn.AutomaticSize = Enum.AutomaticSize.X
		btn.Size = UDim2.fromOffset(0, 32)
		btn.BackgroundTransparency = 1
		btn.Text = "  " .. name .. "  "
		btn.TextColor3 = (name == currentTab) and C.text.primary or C.text.secondary
		btn.Font = FONT.button.font
		btn.TextSize = FONT.button.size
		btn.AutoButtonColor = false
		btn.Parent = strip
		if name == currentTab then
			local underline = Instance.new("Frame")
			underline.AnchorPoint = Vector2.new(0, 1)
			underline.Position = UDim2.new(0, 0, 1, 0)
			underline.Size = UDim2.new(1, 0, 0, 2)
			underline.BackgroundColor3 = C.accent.primary
			underline.BorderSizePixel = 0
			underline.Parent = btn
		end
		btn.Activated:Connect(function() onSelect(name) end)
	end
	return strip
end

-- Forward declaration — assigned below.
local buildOwner

buildOwner = function(tab)
	clearBody()
	title.Text = "My Stall"
	subtitle.Text = ""

	-- Tab strip at top of body
	local strip = buildTabStrip(body, { "Listings", "Mailbox", "Featured" }, tab or "Listings", function(name)
		setMode("owner", { tab = name })
	end)
	strip.Position = UDim2.new(0, 0, 0, 0)
	strip.Size = UDim2.new(1, 0, 0, 32)

	-- Content container below strip
	local contentFrame = Instance.new("Frame")
	contentFrame.Position = UDim2.new(0, 0, 0, 40)
	contentFrame.Size = UDim2.new(1, 0, 1, -40)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = body

	-- Reparent the tab builders' content into contentFrame by swapping body upvalue.
	local prevParent = body
	-- Each tab builder parents to `body`; redirect by temporarily wrapping.
	local oldBody = body
	body = contentFrame
	if tab == "Mailbox" then
		buildOwnerMailboxTab()
	elseif tab == "Featured" then
		buildOwnerFeaturedTab()
	else
		buildOwnerListingsTab()
	end
	body = oldBody
end

-- ---------- Item picker submodal -----------------------------------------

local function buildItemPicker()
	clearBody()
	title.Text = "Add a listing"
	subtitle.Text = "Pick an item from your inventory"

	local backBtn = makeButton(body, "← Back", false)
	backBtn.Position = UDim2.new(0, 0, 0, 0)
	backBtn.Size = UDim2.fromOffset(80, 28)
	backBtn.AutomaticSize = Enum.AutomaticSize.None
	backBtn.Activated:Connect(function()
		-- Reset picker state when leaving via Back
		pickerItem = nil
		setMode("owner", { tab = "Listings" })
	end)

	local listFrame = Instance.new("ScrollingFrame")
	listFrame.Position = UDim2.new(0, 0, 0, 36)
	listFrame.Size = UDim2.new(1, 0, 1, -150)
	listFrame.BackgroundTransparency = 1
	listFrame.BorderSizePixel = 0
	listFrame.ScrollBarThickness = 4
	listFrame.ScrollBarImageColor3 = C.surface.divider
	listFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	listFrame.Parent = body
	local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 4) layout.Parent = listFrame

	-- Build one row per tradable item the player owns
	local function appendRow(itemId, owned, isMushroom)
		local def = isMushroom and Species.byId[itemId] or Constants.ITEMS[itemId]
		if not def then return end
		if not isMushroom and def.tradable == false then return end

		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 32)
		row.BackgroundColor3 = C.surface.elevated or C.surface.panel
		row.Text = string.format("  %s × %d", def.displayName or itemId, owned)
		row.TextColor3 = (pickerItem == itemId) and C.accent.primary or C.text.primary
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = FONT.button.font
		row.TextSize = FONT.button.size
		row.AutoButtonColor = true
		row.BorderSizePixel = 0
		row.Parent = listFrame
		local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, UI.radius.button) rc.Parent = row
		row.Activated:Connect(function()
			pickerItem = itemId
			pickerQty = math.min(owned, pickerQty)
			-- Refresh
			setMode("itemPicker")
		end)
	end

	-- Mushrooms from legacy inventory
	for itemId, owned in pairs(latestData.inventory or {}) do
		if owned > 0 then appendRow(itemId, owned, true) end
	end
	-- Non-mushroom items from inventoryByCategory
	for cat, bucket in pairs(latestData.inventoryByCategory or {}) do
		for itemId, owned in pairs(bucket) do
			if owned > 0 then appendRow(itemId, owned, false) end
		end
	end

	-- qty + price + list controls at the bottom
	local controls = Instance.new("Frame")
	controls.AnchorPoint = Vector2.new(0, 1)
	controls.Position = UDim2.new(0, 0, 1, 0)
	controls.Size = UDim2.new(1, 0, 0, 100)
	controls.BackgroundTransparency = 1
	controls.Parent = body

	local pickedLbl = Instance.new("TextLabel")
	pickedLbl.Size = UDim2.new(1, 0, 0, 20)
	pickedLbl.BackgroundTransparency = 1
	pickedLbl.Text = pickerItem and ("Selected: " .. itemDisplayName(pickerItem)) or "Pick an item above"
	pickedLbl.TextColor3 = pickerItem and C.text.primary or C.text.secondary
	pickedLbl.TextXAlignment = Enum.TextXAlignment.Left
	pickedLbl.Font = FONT.caption.font
	pickedLbl.TextSize = FONT.caption.size
	pickedLbl.Parent = controls

	-- qty input
	local qtyBox = Instance.new("TextBox")
	qtyBox.Position = UDim2.new(0, 0, 0, 28)
	qtyBox.Size = UDim2.fromOffset(70, 32)
	qtyBox.BackgroundColor3 = C.surface.elevated or C.surface.panel
	qtyBox.PlaceholderText = "qty"
	qtyBox.Text = tostring(pickerQty)
	qtyBox.TextColor3 = C.text.primary
	qtyBox.Font = FONT.button.font
	qtyBox.TextSize = FONT.button.size
	qtyBox.ClearTextOnFocus = false
	qtyBox.Parent = controls
	local qc = Instance.new("UICorner") qc.CornerRadius = UDim.new(0, UI.radius.button) qc.Parent = qtyBox

	local priceBox = Instance.new("TextBox")
	priceBox.Position = UDim2.new(0, 80, 0, 28)
	priceBox.Size = UDim2.fromOffset(110, 32)
	priceBox.BackgroundColor3 = C.surface.elevated or C.surface.panel
	priceBox.PlaceholderText = "price ea."
	priceBox.Text = tostring(pickerPrice)
	priceBox.TextColor3 = C.text.primary
	priceBox.Font = FONT.button.font
	priceBox.TextSize = FONT.button.size
	priceBox.ClearTextOnFocus = false
	priceBox.Parent = controls
	local pc = Instance.new("UICorner") pc.CornerRadius = UDim.new(0, UI.radius.button) pc.Parent = priceBox

	-- Persist typed values to module-scope so they survive the rebuild that
	-- happens when the user clicks a different mushroom row.
	qtyBox.FocusLost:Connect(function()
		local n = tonumber(qtyBox.Text)
		if n and n > 0 then pickerQty = math.floor(n) end
		qtyBox.Text = tostring(pickerQty)
	end)
	priceBox.FocusLost:Connect(function()
		local n = tonumber(priceBox.Text)
		if n and n >= STALL.minPrice then pickerPrice = math.floor(n) end
		priceBox.Text = tostring(pickerPrice)
	end)

	local listBtn = makeButton(controls, "List it", true)
	listBtn.AnchorPoint = Vector2.new(1, 0)
	listBtn.Position = UDim2.new(1, 0, 0, 28)
	listBtn.Size = UDim2.fromOffset(110, 32)
	listBtn.AutomaticSize = Enum.AutomaticSize.None
	listBtn.Activated:Connect(function()
		if not pickerItem then
			showToast("Pick an item first", false)
			return
		end
		-- Read the boxes one final time in case the user typed but didn't blur.
		local qty = tonumber(qtyBox.Text) or pickerQty
		local price = tonumber(priceBox.Text) or pickerPrice
		Remotes.get(Constants.REMOTES.CreateListing):FireServer({
			itemId    = pickerItem,
			qty       = qty,
			unitPrice = price,
		})
		-- Reset picker for next time
		pickerItem = nil
		pickerQty = 1
		pickerPrice = 10
	end)
end

-- ---------- Buyer UI -----------------------------------------------------

local function buildBuyer(payload)
	clearBody()
	local sellerName = (payload and payload.sellerName) or "Stall"
	local listings = (payload and payload.listings) or {}
	title.Text = sellerName .. "'s Stall"
	subtitle.Text = "Pick an item to buy"

	local list = makeScrollList(body)
	list.Position = UDim2.new(0, 0, 0, 0)
	list.Size = UDim2.new(1, 0, 1, 0)

	local count = 0
	for listingId, listing in pairs(listings) do
		count += 1
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 56)
		row.BackgroundColor3 = C.surface.elevated or C.surface.panel
		row.BorderSizePixel = 0
		row.Parent = list
		local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, UI.radius.button) rc.Parent = row
		local rp = Instance.new("UIPadding")
		rp.PaddingLeft = UDim.new(0, SP.md) rp.PaddingRight = UDim.new(0, SP.md)
		rp.PaddingTop = UDim.new(0, SP.sm) rp.PaddingBottom = UDim.new(0, SP.sm)
		rp.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -100, 0, 18)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = itemDisplayName(listing.itemId)
		nameLbl.TextColor3 = C.text.primary
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Font = FONT.button.font
		nameLbl.TextSize = 14
		nameLbl.Parent = row

		local priceLbl = Instance.new("TextLabel")
		priceLbl.Position = UDim2.new(0, 0, 0, 22)
		priceLbl.Size = UDim2.new(1, -100, 0, 16)
		priceLbl.BackgroundTransparency = 1
		priceLbl.Text = string.format("%d × %d coins  (total %d)", listing.qty or 0, listing.unitPrice or 0, (listing.qty or 0) * (listing.unitPrice or 0))
		priceLbl.TextColor3 = C.accent.gold
		priceLbl.TextXAlignment = Enum.TextXAlignment.Left
		priceLbl.Font = FONT.caption.font
		priceLbl.TextSize = FONT.caption.size
		priceLbl.Parent = row

		local buyBtn = makeButton(row, "Buy", true)
		buyBtn.AnchorPoint = Vector2.new(1, 0.5)
		buyBtn.Position = UDim2.new(1, 0, 0.5, 0)
		buyBtn.Size = UDim2.fromOffset(80, 32)
		buyBtn.AutomaticSize = Enum.AutomaticSize.None
		buyBtn.Activated:Connect(function()
			Remotes.get(Constants.REMOTES.BuyListing):FireServer(payload.sellerUserId, listingId, listing.qty)
		end)
	end

	if count == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Text = "This stall is empty."
		empty.TextColor3 = C.text.secondary
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.Font = FONT.caption.font
		empty.TextSize = FONT.caption.size
		empty.Parent = body
	end
end

-- ---------- Plot Directory UI --------------------------------------------

local recentSalesFeed: { table } = {}

local function buildDirectoryFeaturedTab(rows)
	if #rows == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Text = "No featured stalls right now. Talk to the Stall Manager to rent one!"
		empty.TextColor3 = C.text.secondary
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.TextWrapped = true
		empty.Font = FONT.caption.font
		empty.TextSize = FONT.caption.size
		empty.Parent = body
		return
	end
	local list = makeScrollList(body)
	for i, row in ipairs(rows) do
		local item = Instance.new("Frame")
		item.Size = UDim2.new(1, 0, 0, 48)
		item.BackgroundColor3 = C.surface.elevated or C.surface.panel
		item.BorderSizePixel = 0
		item.LayoutOrder = i
		item.Parent = list
		local ic = Instance.new("UICorner") ic.CornerRadius = UDim.new(0, UI.radius.button) ic.Parent = item
		local ip = Instance.new("UIPadding")
		ip.PaddingLeft = UDim.new(0, SP.md) ip.PaddingRight = UDim.new(0, SP.md)
		ip.PaddingTop = UDim.new(0, SP.sm) ip.PaddingBottom = UDim.new(0, SP.sm)
		ip.Parent = item

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -100, 0, 18)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = row.sellerName or "?"
		nameLbl.TextColor3 = C.text.primary
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Font = FONT.button.font
		nameLbl.TextSize = 14
		nameLbl.Parent = item

		local countLbl = Instance.new("TextLabel")
		countLbl.Position = UDim2.new(0, 0, 0, 20)
		countLbl.Size = UDim2.new(1, -100, 0, 14)
		countLbl.BackgroundTransparency = 1
		countLbl.Text = string.format("%d listing%s", row.listingCount or 0, (row.listingCount == 1) and "" or "s")
		countLbl.TextColor3 = C.text.secondary
		countLbl.TextXAlignment = Enum.TextXAlignment.Left
		countLbl.Font = FONT.caption.font
		countLbl.TextSize = FONT.caption.size
		countLbl.Parent = item

		local visitBtn = makeButton(item, "Visit", true)
		visitBtn.AnchorPoint = Vector2.new(1, 0.5)
		visitBtn.Position = UDim2.new(1, 0, 0.5, 0)
		visitBtn.Size = UDim2.fromOffset(80, 32)
		visitBtn.AutomaticSize = Enum.AutomaticSize.None
		visitBtn.Activated:Connect(function()
			-- ADR 001 single-place world: use CFrame teleport, not TeleportService.
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if hrp and row.plotPosition then
				hrp.CFrame = CFrame.new(row.plotPosition + Vector3.new(0, 5, 0))
				closeUI()
			end
		end)
	end
end

local function buildDirectoryRecentTab()
	if #recentSalesFeed == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Text = "No sales in this session yet."
		empty.TextColor3 = C.text.secondary
		empty.TextXAlignment = Enum.TextXAlignment.Center
		empty.Font = FONT.caption.font
		empty.TextSize = FONT.caption.size
		empty.Parent = body
		return
	end
	local list = makeScrollList(body)
	for i, sale in ipairs(recentSalesFeed) do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(1, 0, 0, 18)
		row.BackgroundTransparency = 1
		row.Text = string.format("• %s bought %d × %s for %d coins",
			sale.buyerName or "?", sale.qty or 0,
			itemDisplayName(sale.itemId or ""), sale.coinsEarned or 0)
		row.TextColor3 = C.text.primary
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Font = FONT.caption.font
		row.TextSize = FONT.caption.size
		row.LayoutOrder = i
		row.Parent = list
	end
end

local function buildDirectory(payload, tab)
	clearBody()
	title.Text = "Marketplace"
	subtitle.Text = "Featured stalls + recent sales"

	local strip = buildTabStrip(body, { "Featured", "Recent Sales" }, tab or "Featured", function(name)
		setMode("directory", { rows = (payload and payload.rows) or {}, tab = name })
	end)
	strip.Position = UDim2.new(0, 0, 0, 0)
	strip.Size = UDim2.new(1, 0, 0, 32)

	local contentFrame = Instance.new("Frame")
	contentFrame.Position = UDim2.new(0, 0, 0, 40)
	contentFrame.Size = UDim2.new(1, 0, 1, -40)
	contentFrame.BackgroundTransparency = 1
	contentFrame.Parent = body

	local oldBody = body
	body = contentFrame
	if tab == "Recent Sales" then
		buildDirectoryRecentTab()
	else
		buildDirectoryFeaturedTab((payload and payload.rows) or {})
	end
	body = oldBody
end

-- ---------- Mode switcher ------------------------------------------------

setMode = function(mode, payload)
	currentMode = mode
	currentPayload = payload
	screen.Enabled = true
	if mode == "owner" then
		buildOwner(payload and payload.tab or "Listings")
	elseif mode == "buyer" then
		buildBuyer(payload)
	elseif mode == "directory" then
		buildDirectory(payload, payload and payload.tab or "Featured")
	elseif mode == "itemPicker" then
		buildItemPicker()
	else
		closeUI()
	end
end

-- Refresh open mode when player data changes (so listings/coins/etc update live).
-- Skip itemPicker — rebuilding it mid-typing would wipe the user's qty/price input.
local function refreshIfOpen()
	if currentMode and screen.Enabled and currentMode ~= "itemPicker" then
		setMode(currentMode, currentPayload)
	end
end

-- ---------- HUD Marketplace button ---------------------------------------

local hudBtn = Instance.new("TextButton")
hudBtn.Name = "MarketplaceButton"
hudBtn.AnchorPoint = Vector2.new(1, 0)
hudBtn.Position = UDim2.new(1, -16, 0, 200)  -- right side, below other HUD widgets
hudBtn.Size = UDim2.fromOffset(120, 36)
hudBtn.BackgroundColor3 = C.accent.primary
hudBtn.Text = "🛒 Marketplace"
hudBtn.TextColor3 = C.text.onAccent
hudBtn.Font = FONT.button.font
hudBtn.TextSize = FONT.button.size
hudBtn.AutoButtonColor = true
hudBtn.BorderSizePixel = 0
hudBtn.Parent = hudScreen
local hudCorner = Instance.new("UICorner") hudCorner.CornerRadius = UDim.new(0, UI.radius.button) hudCorner.Parent = hudBtn

hudBtn.Activated:Connect(function()
	-- Fire BrowseDirectory; server replies on the same remote with rows.
	Remotes.get(Constants.REMOTES.BrowseDirectory):FireServer()
end)

-- ---------- Remote handlers ----------------------------------------------

Remotes.get(Constants.REMOTES.OpenStallOwnerUI).OnClientEvent:Connect(function(payload)
	setMode("owner", { tab = (payload and payload.tab) or "Listings" })
end)

Remotes.get(Constants.REMOTES.OpenStallBuyerUI).OnClientEvent:Connect(function(payload)
	setMode("buyer", payload)
end)

Remotes.get(Constants.REMOTES.BrowseDirectory).OnClientEvent:Connect(function(rows)
	-- Update the recent-sales feed from the rows? Server only sends featured rows here.
	-- Recent-sales feed is populated locally via observed StallTransactionCompleted events
	-- (best-effort; server-authoritative recent-feed could be a Phase 3 polish item).
	setMode("directory", { rows = rows or {}, tab = "Featured" })
end)

Remotes.get(Constants.REMOTES.StallTransactionCompleted).OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.success then
		local action = payload.action or ""
		if action == "create" then
			showToast("Listed!", true)
			-- Navigate back to Listings tab so the user immediately sees the
			-- new listing in their stall (the picker doesn't auto-refresh).
			if currentMode == "itemPicker" then
				setMode("owner", { tab = "Listings" })
			end
		elseif action == "cancel" then
			showToast("Listing cancelled.", true)
		elseif action == "buy" then
			showToast(string.format("Bought %d × %s", payload.qty or 0, itemDisplayName(payload.itemId or "")), true)
		elseif action == "rent_featured" then
			showToast("Featured slot rented for 24h!", true)
		else
			showToast("Done.", true)
		end
		-- Local recent-sales feed (best-effort)
		if action == "buy" then
			table.insert(recentSalesFeed, 1, {
				buyerName  = player.Name,
				qty        = payload.qty,
				itemId     = payload.itemId,
				coinsEarned = (payload.qty or 0) * 0,  -- buyer-side doesn't know seller's price; placeholder
			})
			while #recentSalesFeed > 20 do table.remove(recentSalesFeed) end
		end
		refreshIfOpen()
	else
		showError(payload.code or "INVALID_REQUEST")
	end
end)

Remotes.get(Constants.REMOTES.MailboxUpdated).OnClientEvent:Connect(function(_mailbox)
	-- Server pushes the seller's mailbox after a sale or claim. Refresh the
	-- modal if the player is on the Mailbox tab. No standalone toast for
	-- arrivals — use the overflowNotice path for that signal.
	refreshIfOpen()
end)

Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(function(data)
	latestData = data or { coins = 0, inventory = {}, inventoryByCategory = {}, stalls = nil }
	-- D-20: mailbox overflow notice. Show once per change.
	local notice = data and data.stalls and data.stalls.mailbox and data.stalls.mailbox.overflowNotice
	if notice and notice.since and notice.since ~= lastSeenOverflowSince then
		lastSeenOverflowSince = notice.since
		showToast(string.format("%d listing%s went to the audit log — your mailbox was full.",
			notice.count or 0, (notice.count == 1) and "" or "s"), false)
	end
	refreshIfOpen()
end)
