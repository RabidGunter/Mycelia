-- Trading Post client UI.
--
-- Three pieces of UI rolled into one controller:
--   1. HUD "Trade" button next to the Quest widget — opens a player picker.
--   2. Player picker modal — list of online players with a "Request" button
--      per row. Click → fires RequestTrade.
--   3. Incoming-request toast — short notification with Accept / Decline
--      shown to the target on TradeRequestReceived.
--   4. Trade modal — two-panel side-by-side card with offer slots, coin
--      input, lock + confirm flow. Opens on TradeSessionStarted.
--   5. Item picker submodal — when an empty slot in your offer is clicked.
--
-- Server is authoritative on every state transition. Client only fires
-- intent (UpdateTradeOffer, LockTradeOffer, ConfirmTrade, CancelTrade) and
-- re-renders from TradeOfferUpdated payloads.
--
-- Spec: docs/specs/trading-post.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local UI = Constants.UI
local C = UI.color
local FONT = UI.typography
local SP = UI.space

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- ---------- State --------------------------------------------------------

local latestData: any = { inventory = {}, inventoryByCategory = {}, coins = 0 }
local currentSession: any = nil  -- last clientView payload from server

-- ---------- HUD button ---------------------------------------------------

local hudScreen = Instance.new("ScreenGui")
hudScreen.Name = "TradeHUD"
hudScreen.ResetOnSpawn = false
hudScreen.Parent = playerGui

local tradeBtn = Instance.new("TextButton")
tradeBtn.AnchorPoint = Vector2.new(1, 0)
-- Position below the Quest widget (which sits at top-right with height ~64+SP.md).
tradeBtn.Position = UDim2.new(1, -SP.md, 0, SP.md + 64 + SP.sm)
tradeBtn.Size = UDim2.fromOffset(110, 32)
tradeBtn.BackgroundColor3 = C.surface.panel
tradeBtn.AutoButtonColor = true
tradeBtn.Text = "Trade"
tradeBtn.TextColor3 = C.text.primary
tradeBtn.Font = FONT.button.font
tradeBtn.TextSize = 14
tradeBtn.BorderSizePixel = 0
tradeBtn.Parent = hudScreen
local tradeBtnCorner = Instance.new("UICorner")
tradeBtnCorner.CornerRadius = UDim.new(0, UI.radius.button)
tradeBtnCorner.Parent = tradeBtn
local tradeBtnStroke = Instance.new("UIStroke")
tradeBtnStroke.Color = C.surface.divider
tradeBtnStroke.Thickness = 1
tradeBtnStroke.Parent = tradeBtn

-- ---------- Player picker modal ------------------------------------------

local pickerScreen = Instance.new("ScreenGui")
pickerScreen.Name = "TradePicker"
pickerScreen.ResetOnSpawn = false
pickerScreen.DisplayOrder = 11
pickerScreen.Enabled = false
pickerScreen.IgnoreGuiInset = true
pickerScreen.Parent = playerGui

local pickerOverlay = Instance.new("TextButton")
pickerOverlay.Size = UDim2.fromScale(1, 1)
pickerOverlay.BackgroundColor3 = C.forest.ink
pickerOverlay.BackgroundTransparency = 0.6
pickerOverlay.Text = ""
pickerOverlay.AutoButtonColor = false
pickerOverlay.Parent = pickerScreen

local pickerCard = Instance.new("Frame")
pickerCard.AnchorPoint = Vector2.new(0.5, 0.5)
pickerCard.Position = UDim2.fromScale(0.5, 0.5)
pickerCard.Size = UDim2.new(0.85, 0, 0.7, 0)
pickerCard.BackgroundColor3 = C.surface.panel
pickerCard.BorderSizePixel = 0
pickerCard.Parent = pickerScreen
local pickerCardSize = Instance.new("UISizeConstraint")
pickerCardSize.MaxSize = Vector2.new(420, 540)
pickerCardSize.MinSize = Vector2.new(280, 360)
pickerCardSize.Parent = pickerCard
local pickerCardCorner = Instance.new("UICorner")
pickerCardCorner.CornerRadius = UDim.new(0, UI.radius.card)
pickerCardCorner.Parent = pickerCard
local pickerPad = Instance.new("UIPadding")
pickerPad.PaddingTop = UDim.new(0, SP.lg) pickerPad.PaddingBottom = UDim.new(0, SP.lg)
pickerPad.PaddingLeft = UDim.new(0, SP.lg) pickerPad.PaddingRight = UDim.new(0, SP.lg)
pickerPad.Parent = pickerCard

local pickerTitle = Instance.new("TextLabel")
pickerTitle.Size = UDim2.new(1, 0, 0, 28)
pickerTitle.BackgroundTransparency = 1
pickerTitle.Text = "Trade with…"
pickerTitle.TextColor3 = C.text.primary
pickerTitle.TextXAlignment = Enum.TextXAlignment.Left
pickerTitle.Font = FONT.display.font
pickerTitle.TextSize = 22
pickerTitle.Parent = pickerCard

local pickerList = Instance.new("ScrollingFrame")
pickerList.Position = UDim2.new(0, 0, 0, 36)
pickerList.Size = UDim2.new(1, 0, 1, -36 - 56)
pickerList.BackgroundTransparency = 1
pickerList.BorderSizePixel = 0
pickerList.ScrollBarThickness = 4
pickerList.ScrollBarImageColor3 = C.surface.divider
pickerList.CanvasSize = UDim2.new(0, 0, 0, 0)
pickerList.Parent = pickerCard
local pickerLayout = Instance.new("UIListLayout")
pickerLayout.Padding = UDim.new(0, SP.sm)
pickerLayout.Parent = pickerList
pickerLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	pickerList.CanvasSize = UDim2.new(0, 0, 0, pickerLayout.AbsoluteContentSize.Y)
end)

local pickerClose = Instance.new("TextButton")
pickerClose.AnchorPoint = Vector2.new(0.5, 1)
pickerClose.Position = UDim2.new(0.5, 0, 1, 0)
pickerClose.Size = UDim2.fromOffset(140, 44)
pickerClose.BackgroundColor3 = C.surface.recessed
pickerClose.Text = "Close"
pickerClose.TextColor3 = C.text.primary
pickerClose.Font = FONT.button.font
pickerClose.TextSize = FONT.button.size
pickerClose.BorderSizePixel = 0
pickerClose.Parent = pickerCard
local pickerCloseCorner = Instance.new("UICorner")
pickerCloseCorner.CornerRadius = UDim.new(0, UI.radius.button) pickerCloseCorner.Parent = pickerClose

local function clearPickerList()
	for _, child in ipairs(pickerList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
end

local function refreshPickerList()
	clearPickerList()
	local others = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer then table.insert(others, p) end
	end
	if #others == 0 then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1, 0, 0, 56)
		empty.BackgroundTransparency = 1
		empty.Parent = pickerList
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = "No other players in this server."
		lbl.TextColor3 = C.text.muted
		lbl.Font = FONT.body.font
		lbl.TextSize = FONT.body.size
		lbl.Parent = empty
		return
	end
	for i, p in ipairs(others) do
		local row = Instance.new("Frame")
		row.LayoutOrder = i
		row.Size = UDim2.new(1, 0, 0, 48)
		row.BackgroundColor3 = C.surface.recessed
		row.BorderSizePixel = 0
		row.Parent = pickerList
		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, UI.radius.chip)
		rowCorner.Parent = row
		local rowPad = Instance.new("UIPadding")
		rowPad.PaddingLeft = UDim.new(0, SP.md) rowPad.PaddingRight = UDim.new(0, SP.md)
		rowPad.Parent = row

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -100, 1, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = p.DisplayName .. " (@" .. p.Name .. ")"
		nameLbl.TextColor3 = C.text.primary
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Font = FONT.body.font
		nameLbl.TextSize = FONT.body.size
		nameLbl.Parent = row

		local req = Instance.new("TextButton")
		req.AnchorPoint = Vector2.new(1, 0.5)
		req.Position = UDim2.new(1, 0, 0.5, 0)
		req.Size = UDim2.fromOffset(88, 32)
		req.BackgroundColor3 = C.accent.primary
		req.Text = "Request"
		req.TextColor3 = C.text.onAccent
		req.Font = FONT.button.font
		req.TextSize = 14
		req.BorderSizePixel = 0
		req.Parent = row
		local reqCorner = Instance.new("UICorner")
		reqCorner.CornerRadius = UDim.new(0, UI.radius.button) reqCorner.Parent = req
		req.Activated:Connect(function()
			Remotes.get(Constants.REMOTES.RequestTrade):FireServer(p)
			pickerScreen.Enabled = false
		end)
	end
end

local function openPicker()
	refreshPickerList()
	pickerScreen.Enabled = true
end

tradeBtn.Activated:Connect(openPicker)
pickerOverlay.Activated:Connect(function() pickerScreen.Enabled = false end)
pickerClose.Activated:Connect(function() pickerScreen.Enabled = false end)

-- ---------- Incoming-request toast ---------------------------------------

local toastScreen = Instance.new("ScreenGui")
toastScreen.Name = "TradeToast"
toastScreen.ResetOnSpawn = false
toastScreen.DisplayOrder = 13
toastScreen.IgnoreGuiInset = true
toastScreen.Parent = playerGui

local function showRequestToast(payload)
	local toast = Instance.new("Frame")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, SP.md)
	toast.Size = UDim2.fromOffset(360, 72)
	toast.BackgroundColor3 = C.surface.panel
	toast.BorderSizePixel = 0
	toast.Parent = toastScreen
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, UI.radius.card) corner.Parent = toast
	local stroke = Instance.new("UIStroke") stroke.Color = C.accent.primary stroke.Thickness = 2 stroke.Parent = toast
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, SP.md) pad.PaddingRight = UDim.new(0, SP.md)
	pad.PaddingTop = UDim.new(0, SP.sm) pad.PaddingBottom = UDim.new(0, SP.sm)
	pad.Parent = toast

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -180, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = string.format("%s wants to trade", payload.fromPlayer and payload.fromPlayer.DisplayName or "Someone")
	lbl.TextColor3 = C.text.primary
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Font = FONT.body.font
	lbl.TextSize = FONT.body.size
	lbl.TextWrapped = true
	lbl.Parent = toast

	local function makeBtn(text, color, x)
		local b = Instance.new("TextButton")
		b.AnchorPoint = Vector2.new(1, 0.5)
		b.Position = UDim2.new(1, x, 0.5, 0)
		b.Size = UDim2.fromOffset(72, 36)
		b.BackgroundColor3 = color
		b.Text = text
		b.TextColor3 = C.text.onAccent
		b.Font = FONT.button.font
		b.TextSize = 14
		b.BorderSizePixel = 0
		b.Parent = toast
		local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, UI.radius.button) c.Parent = b
		return b
	end
	local accept = makeBtn("Accept", C.accent.primary, 0)
	local decline = makeBtn("Decline", C.state.error, -80)

	accept.Activated:Connect(function()
		Remotes.get(Constants.REMOTES.RespondToTradeRequest):FireServer(payload.sessionId, true)
		toast:Destroy()
	end)
	decline.Activated:Connect(function()
		Remotes.get(Constants.REMOTES.RespondToTradeRequest):FireServer(payload.sessionId, false)
		toast:Destroy()
	end)

	-- Auto-destroy after request timeout (30s).
	task.delay(30, function() if toast.Parent then toast:Destroy() end end)
end

local function showStatusToast(text: string, success: boolean)
	local toast = Instance.new("TextLabel")
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, SP.md)
	toast.Size = UDim2.fromOffset(320, 48)
	toast.BackgroundColor3 = success and C.state.success or C.state.error
	toast.Text = text
	toast.TextColor3 = C.text.onAccent
	toast.Font = FONT.button.font
	toast.TextSize = FONT.button.size
	toast.BorderSizePixel = 0
	toast.Parent = toastScreen
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, UI.radius.button) corner.Parent = toast
	task.delay(2.5, function() if toast.Parent then toast:Destroy() end end)
end

-- ---------- Trade modal ---------------------------------------------------

local tradeScreen = Instance.new("ScreenGui")
tradeScreen.Name = "TradeUI"
tradeScreen.ResetOnSpawn = false
tradeScreen.DisplayOrder = 12
tradeScreen.Enabled = false
tradeScreen.IgnoreGuiInset = true
tradeScreen.Parent = playerGui

local tradeOverlay = Instance.new("Frame")
tradeOverlay.Size = UDim2.fromScale(1, 1)
tradeOverlay.BackgroundColor3 = C.forest.ink
tradeOverlay.BackgroundTransparency = 0.55
tradeOverlay.BorderSizePixel = 0
tradeOverlay.Parent = tradeScreen

local tradeCard = Instance.new("Frame")
tradeCard.AnchorPoint = Vector2.new(0.5, 0.5)
tradeCard.Position = UDim2.fromScale(0.5, 0.5)
tradeCard.Size = UDim2.new(0.95, 0, 0.85, 0)
tradeCard.BackgroundColor3 = C.surface.panel
tradeCard.BorderSizePixel = 0
tradeCard.Parent = tradeScreen
local tradeCardSize = Instance.new("UISizeConstraint")
tradeCardSize.MaxSize = Vector2.new(720, 560)
tradeCardSize.MinSize = Vector2.new(320, 460)
tradeCardSize.Parent = tradeCard
local tradeCardCorner = Instance.new("UICorner")
tradeCardCorner.CornerRadius = UDim.new(0, UI.radius.card) tradeCardCorner.Parent = tradeCard
local tradeCardPad = Instance.new("UIPadding")
tradeCardPad.PaddingTop = UDim.new(0, SP.lg) tradeCardPad.PaddingBottom = UDim.new(0, SP.lg)
tradeCardPad.PaddingLeft = UDim.new(0, SP.lg) tradeCardPad.PaddingRight = UDim.new(0, SP.lg)
tradeCardPad.Parent = tradeCard

local tradeStatus = Instance.new("TextLabel")
tradeStatus.Size = UDim2.new(1, 0, 0, 28)
tradeStatus.BackgroundTransparency = 1
tradeStatus.Text = "Trading"
tradeStatus.TextColor3 = C.text.primary
tradeStatus.Font = FONT.display.font
tradeStatus.TextSize = 20
tradeStatus.TextXAlignment = Enum.TextXAlignment.Center
tradeStatus.Parent = tradeCard

local panels = Instance.new("Frame")
panels.Position = UDim2.new(0, 0, 0, 36)
panels.Size = UDim2.new(1, 0, 1, -36 - 64)
panels.BackgroundTransparency = 1
panels.Parent = tradeCard
local panelsLayout = Instance.new("UIListLayout")
panelsLayout.FillDirection = Enum.FillDirection.Horizontal
panelsLayout.Padding = UDim.new(0, SP.md)
panelsLayout.Parent = panels

local SLOT_COUNT = 6

local function buildPanel(name, isMine)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.new(0.5, -SP.sm, 1, 0)
	panel.BackgroundColor3 = C.surface.recessed
	panel.BorderSizePixel = 0
	panel.Parent = panels
	local corner = Instance.new("UICorner") corner.CornerRadius = UDim.new(0, UI.radius.chip) corner.Parent = panel
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, SP.md) pad.PaddingBottom = UDim.new(0, SP.md)
	pad.PaddingLeft = UDim.new(0, SP.md) pad.PaddingRight = UDim.new(0, SP.md)
	pad.Parent = panel

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 22)
	header.BackgroundTransparency = 1
	header.Text = isMine and "Your offer" or "Their offer"
	header.TextColor3 = C.text.primary
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Font = FONT.display.font
	header.TextSize = 16
	header.Parent = panel

	local statusLine = Instance.new("TextLabel")
	statusLine.Name = "StatusLine"
	statusLine.Position = UDim2.new(0, 0, 0, 22)
	statusLine.Size = UDim2.new(1, 0, 0, 16)
	statusLine.BackgroundTransparency = 1
	statusLine.Text = "Editing"
	statusLine.TextColor3 = C.text.secondary
	statusLine.TextXAlignment = Enum.TextXAlignment.Left
	statusLine.Font = FONT.caption.font
	statusLine.TextSize = FONT.caption.size
	statusLine.Parent = panel

	local slotsGrid = Instance.new("Frame")
	slotsGrid.Name = "Slots"
	slotsGrid.Position = UDim2.new(0, 0, 0, 44)
	slotsGrid.Size = UDim2.new(1, 0, 0, 100)
	slotsGrid.BackgroundTransparency = 1
	slotsGrid.Parent = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.32, -4, 0.5, -4)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.Parent = slotsGrid

	for i = 1, SLOT_COUNT do
		local slot = Instance.new("TextButton")
		slot.Name = "Slot" .. i
		slot.LayoutOrder = i
		slot.BackgroundColor3 = C.surface.bg
		slot.AutoButtonColor = isMine
		slot.Text = ""
		slot.TextColor3 = C.text.primary
		slot.Font = FONT.body.font
		slot.TextSize = 12
		slot.BorderSizePixel = 0
		slot.Parent = slotsGrid
		local sc = Instance.new("UICorner") sc.CornerRadius = UDim.new(0, UI.radius.chip) sc.Parent = slot
	end

	local coinRow = Instance.new("Frame")
	coinRow.Name = "CoinRow"
	coinRow.Position = UDim2.new(0, 0, 1, -76)
	coinRow.Size = UDim2.new(1, 0, 0, 32)
	coinRow.BackgroundTransparency = 1
	coinRow.Parent = panel

	local coinLabel = Instance.new("TextLabel")
	coinLabel.Size = UDim2.new(0, 60, 1, 0)
	coinLabel.BackgroundTransparency = 1
	coinLabel.Text = "Coins:"
	coinLabel.TextColor3 = C.text.secondary
	coinLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinLabel.Font = FONT.body.font
	coinLabel.TextSize = FONT.body.size
	coinLabel.Parent = coinRow

	if isMine then
		local coinInput = Instance.new("TextBox")
		coinInput.Name = "CoinInput"
		coinInput.Position = UDim2.new(0, 60, 0, 0)
		coinInput.Size = UDim2.new(1, -60, 1, 0)
		coinInput.BackgroundColor3 = C.surface.bg
		coinInput.PlaceholderText = "0"
		coinInput.Text = ""
		coinInput.TextColor3 = C.text.primary
		coinInput.Font = FONT.numeric.font
		coinInput.TextSize = FONT.numeric.size
		coinInput.ClearTextOnFocus = false
		coinInput.BorderSizePixel = 0
		coinInput.Parent = coinRow
		local coinInputCorner = Instance.new("UICorner")
		coinInputCorner.CornerRadius = UDim.new(0, UI.radius.chip) coinInputCorner.Parent = coinInput
	else
		local coinDisplay = Instance.new("TextLabel")
		coinDisplay.Name = "CoinDisplay"
		coinDisplay.Position = UDim2.new(0, 60, 0, 0)
		coinDisplay.Size = UDim2.new(1, -60, 1, 0)
		coinDisplay.BackgroundTransparency = 1
		coinDisplay.Text = "0"
		coinDisplay.TextColor3 = C.accent.gold
		coinDisplay.TextXAlignment = Enum.TextXAlignment.Left
		coinDisplay.Font = FONT.numeric.font
		coinDisplay.TextSize = FONT.numeric.size
		coinDisplay.Parent = coinRow
	end

	local lockBtn = Instance.new("TextButton")
	lockBtn.Name = "LockBtn"
	lockBtn.AnchorPoint = Vector2.new(0, 1)
	lockBtn.Position = UDim2.new(0, 0, 1, 0)
	lockBtn.Size = UDim2.new(1, 0, 0, 36)
	lockBtn.BackgroundColor3 = C.accent.primary
	lockBtn.Text = isMine and "Lock my offer" or "—"
	lockBtn.TextColor3 = C.text.onAccent
	lockBtn.Font = FONT.button.font
	lockBtn.TextSize = FONT.button.size
	lockBtn.BorderSizePixel = 0
	lockBtn.AutoButtonColor = isMine
	lockBtn.Active = isMine
	lockBtn.Parent = panel
	local lockCorner = Instance.new("UICorner")
	lockCorner.CornerRadius = UDim.new(0, UI.radius.button) lockCorner.Parent = lockBtn

	return panel
end

local mePanel = buildPanel("Me", true)
local themPanel = buildPanel("Them", false)

local footer = Instance.new("Frame")
footer.AnchorPoint = Vector2.new(0, 1)
footer.Position = UDim2.new(0, 0, 1, 0)
footer.Size = UDim2.new(1, 0, 0, 56)
footer.BackgroundTransparency = 1
footer.Parent = tradeCard

local footerLayout = Instance.new("UIListLayout")
footerLayout.FillDirection = Enum.FillDirection.Horizontal
footerLayout.Padding = UDim.new(0, SP.md)
footerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
footerLayout.Parent = footer

local function makeFooterBtn(text, primary)
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(140, 44)
	b.BackgroundColor3 = primary and C.accent.primary or C.surface.recessed
	b.Text = text
	b.TextColor3 = primary and C.text.onAccent or C.text.primary
	b.Font = FONT.button.font
	b.TextSize = FONT.button.size
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Parent = footer
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, UI.radius.button) c.Parent = b
	return b
end
local cancelBtn = makeFooterBtn("Cancel", false)
local confirmBtn = makeFooterBtn("Confirm", true)

-- ---------- Trade UI logic ----------------------------------------------

local function panelSlots(panel) return panel:FindFirstChild("Slots") end
local function panelStatus(panel) return panel:FindFirstChild("StatusLine") end
local function panelLock(panel) return panel:FindFirstChild("LockBtn") end
local function panelHeader(panel) return panel:FindFirstChild("Header") end

-- Renders slot text + color + records the displayed itemId on the slot's
-- attribute. Click handlers are wired ONCE at module load below (see
-- wireSlotClicks); they read the attribute at click time. This avoids the
-- connection leak that came from re-Connecting every render.
local function renderSlots(panel, offer, _isMine)
	local slotsContainer = panelSlots(panel)
	if not slotsContainer then return end
	local items = {}
	for itemId, qty in pairs(offer.items or {}) do
		table.insert(items, { id = itemId, qty = qty })
	end
	-- Stable order by itemId so re-renders don't shuffle slots.
	table.sort(items, function(a, b) return a.id < b.id end)

	for i = 1, SLOT_COUNT do
		local slot = slotsContainer:FindFirstChild("Slot" .. i)
		if slot and slot:IsA("TextButton") then
			local item = items[i]
			if item then
				local def = Constants.ITEMS[item.id]
				local species = Species.byId[item.id]
				local name = def and def.displayName or species and species.displayName or item.id
				slot.Text = string.format("%s\n×%d", name, item.qty)
				slot.TextColor3 = C.text.primary
				slot:SetAttribute("OfferItemId", item.id)
			else
				slot.Text = panel == mePanel and "+" or ""
				slot.TextColor3 = C.text.muted
				slot:SetAttribute("OfferItemId", nil)
			end
		end
	end
end

local function renderTradeView(view)
	currentSession = view
	if not view then return end

	local s = view.state
	if s == "Open" then
		tradeStatus.Text = "Trading with " .. (view.them.player and view.them.player.DisplayName or "")
	elseif s == "Locked" then
		local elapsed = os.time() - (view.lockedAt or os.time())
		local remaining = math.max(0, (view.countdownSeconds or 5) - elapsed)
		tradeStatus.Text = string.format("Locked. %ds until you can confirm…", remaining)
	end

	-- Headers + status lines
	panelHeader(mePanel).Text = "Your offer (" .. localPlayer.DisplayName .. ")"
	panelHeader(themPanel).Text = "Their offer (" .. (view.them.player and view.them.player.DisplayName or "—") .. ")"
	panelStatus(mePanel).Text = view.you.confirmed and "Confirmed ✓"
		or view.you.locked and "Locked"
		or "Editing"
	panelStatus(themPanel).Text = view.them.confirmed and "Confirmed ✓"
		or view.them.locked and "Locked"
		or "Editing"
	panelStatus(mePanel).TextColor3 = view.you.confirmed and C.state.success or C.text.secondary
	panelStatus(themPanel).TextColor3 = view.them.confirmed and C.state.success or C.text.secondary

	-- Slots
	renderSlots(mePanel, view.you.offer, true)
	renderSlots(themPanel, view.them.offer, false)

	-- Coins
	local meCoinInput = mePanel:FindFirstChild("CoinRow"):FindFirstChild("CoinInput")
	if meCoinInput and not meCoinInput:IsFocused() then
		meCoinInput.Text = tostring(view.you.offer.coins or 0)
	end
	local themCoinDisplay = themPanel:FindFirstChild("CoinRow"):FindFirstChild("CoinDisplay")
	if themCoinDisplay then
		themCoinDisplay.Text = tostring(view.them.offer.coins or 0)
	end

	-- Lock button
	local lock = panelLock(mePanel)
	if view.you.locked then
		lock.Text = "Locked ✓"
		lock.BackgroundColor3 = C.state.success
	else
		lock.Text = "Lock my offer"
		lock.BackgroundColor3 = C.accent.primary
	end
	local theirLock = panelLock(themPanel)
	theirLock.Text = view.them.locked and "Locked ✓" or "Editing"
	theirLock.BackgroundColor3 = view.them.locked and C.state.success or C.surface.bg
	theirLock.TextColor3 = view.them.locked and C.text.onAccent or C.text.muted

	-- Confirm button
	local readyToConfirm = (s == "Locked")
		and (view.lockedAt and (os.time() - view.lockedAt >= (view.countdownSeconds or 5)))
		and not view.you.confirmed
	confirmBtn.AutoButtonColor = readyToConfirm
	confirmBtn.Active = readyToConfirm
	confirmBtn.BackgroundColor3 = readyToConfirm and C.accent.primary or C.surface.recessed
	confirmBtn.TextColor3 = readyToConfirm and C.text.onAccent or C.text.muted
	confirmBtn.Text = view.you.confirmed and "Confirmed ✓" or "Confirm"
end

-- Wire each of MY 6 slot buttons ONCE at module load. Click reads the
-- slot's `OfferItemId` attribute (set by renderSlots) — empty slot opens
-- the item picker; filled slot removes the item from the offer.
do
	local slotsContainer = panelSlots(mePanel)
	for i = 1, SLOT_COUNT do
		local slot = slotsContainer and slotsContainer:FindFirstChild("Slot" .. i)
		if slot and slot:IsA("TextButton") then
			slot.Activated:Connect(function()
				if not currentSession then return end
				local itemId = slot:GetAttribute("OfferItemId")
				if itemId then
					local newOffer = {
						coins = currentSession.you.offer.coins or 0,
						items = {},
					}
					for k, v in pairs(currentSession.you.offer.items or {}) do
						if k ~= itemId then newOffer.items[k] = v end
					end
					Remotes.get(Constants.REMOTES.UpdateTradeOffer):FireServer(currentSession.sessionId, newOffer)
				else
					_G.MyceliaTradeOpenItemPicker(i)
				end
			end)
		end
	end
end

-- Throttled countdown updater: 10Hz (every 0.1s) is plenty for second-level
-- countdown text. Only updates the status banner + Confirm enabledness — the
-- full renderTradeView runs on actual state changes (TradeOfferUpdated).
local hbAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	if not (tradeScreen.Enabled and currentSession and currentSession.state == "Locked") then
		hbAccumulator = 0
		return
	end
	hbAccumulator += dt
	if hbAccumulator < 0.1 then return end
	hbAccumulator = 0
	local elapsed = os.time() - (currentSession.lockedAt or os.time())
	local remaining = math.max(0, (currentSession.countdownSeconds or 5) - elapsed)
	tradeStatus.Text = string.format("Locked. %ds until you can confirm…", remaining)
	local readyToConfirm = remaining <= 0 and not currentSession.you.confirmed
	confirmBtn.AutoButtonColor = readyToConfirm
	confirmBtn.Active = readyToConfirm
	confirmBtn.BackgroundColor3 = readyToConfirm and C.accent.primary or C.surface.recessed
	confirmBtn.TextColor3 = readyToConfirm and C.text.onAccent or C.text.muted
end)

local meCoinInput = mePanel:FindFirstChild("CoinRow"):FindFirstChild("CoinInput")
if meCoinInput then
	meCoinInput.FocusLost:Connect(function()
		if not currentSession then return end
		local n = tonumber(meCoinInput.Text) or 0
		n = math.max(0, math.floor(n))
		local newOffer = { coins = n, items = {} }
		for k, v in pairs(currentSession.you.offer.items or {}) do newOffer.items[k] = v end
		Remotes.get(Constants.REMOTES.UpdateTradeOffer):FireServer(currentSession.sessionId, newOffer)
	end)
end

panelLock(mePanel).Activated:Connect(function()
	if not currentSession then return end
	if currentSession.you.locked then return end  -- already locked
	Remotes.get(Constants.REMOTES.LockTradeOffer):FireServer(currentSession.sessionId)
end)

confirmBtn.Activated:Connect(function()
	if not currentSession or not confirmBtn.Active then return end
	Remotes.get(Constants.REMOTES.ConfirmTrade):FireServer(currentSession.sessionId)
end)

cancelBtn.Activated:Connect(function()
	if not currentSession then return end
	Remotes.get(Constants.REMOTES.CancelTrade):FireServer(currentSession.sessionId)
end)

local function closeTrade()
	tradeScreen.Enabled = false
	currentSession = nil
end

-- ---------- Item picker submodal ----------------------------------------

local itemPickerScreen = Instance.new("ScreenGui")
itemPickerScreen.Name = "TradeItemPicker"
itemPickerScreen.ResetOnSpawn = false
itemPickerScreen.DisplayOrder = 14
itemPickerScreen.Enabled = false
itemPickerScreen.IgnoreGuiInset = true
itemPickerScreen.Parent = playerGui

local ipOverlay = Instance.new("TextButton")
ipOverlay.Size = UDim2.fromScale(1, 1)
ipOverlay.BackgroundColor3 = C.forest.ink
ipOverlay.BackgroundTransparency = 0.55
ipOverlay.Text = ""
ipOverlay.AutoButtonColor = false
ipOverlay.Parent = itemPickerScreen

local ipCard = Instance.new("Frame")
ipCard.AnchorPoint = Vector2.new(0.5, 0.5)
ipCard.Position = UDim2.fromScale(0.5, 0.5)
ipCard.Size = UDim2.new(0.85, 0, 0.7, 0)
ipCard.BackgroundColor3 = C.surface.panel
ipCard.BorderSizePixel = 0
ipCard.Parent = itemPickerScreen
local ipSize = Instance.new("UISizeConstraint") ipSize.MaxSize = Vector2.new(420, 540) ipSize.MinSize = Vector2.new(280, 360) ipSize.Parent = ipCard
local ipCorner = Instance.new("UICorner") ipCorner.CornerRadius = UDim.new(0, UI.radius.card) ipCorner.Parent = ipCard
local ipPad = Instance.new("UIPadding")
ipPad.PaddingTop = UDim.new(0, SP.lg) ipPad.PaddingBottom = UDim.new(0, SP.lg)
ipPad.PaddingLeft = UDim.new(0, SP.lg) ipPad.PaddingRight = UDim.new(0, SP.lg)
ipPad.Parent = ipCard

local ipTitle = Instance.new("TextLabel")
ipTitle.Size = UDim2.new(1, 0, 0, 28)
ipTitle.BackgroundTransparency = 1
ipTitle.Text = "Add to offer"
ipTitle.TextColor3 = C.text.primary
ipTitle.TextXAlignment = Enum.TextXAlignment.Left
ipTitle.Font = FONT.display.font
ipTitle.TextSize = 22
ipTitle.Parent = ipCard

local ipList = Instance.new("ScrollingFrame")
ipList.Position = UDim2.new(0, 0, 0, 36)
ipList.Size = UDim2.new(1, 0, 1, -36 - 56)
ipList.BackgroundTransparency = 1
ipList.BorderSizePixel = 0
ipList.ScrollBarThickness = 4
ipList.ScrollBarImageColor3 = C.surface.divider
ipList.CanvasSize = UDim2.new(0, 0, 0, 0)
ipList.Parent = ipCard
local ipLayout = Instance.new("UIListLayout")
ipLayout.Padding = UDim.new(0, SP.sm) ipLayout.Parent = ipList
ipLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ipList.CanvasSize = UDim2.new(0, 0, 0, ipLayout.AbsoluteContentSize.Y)
end)

local ipClose = Instance.new("TextButton")
ipClose.AnchorPoint = Vector2.new(0.5, 1)
ipClose.Position = UDim2.new(0.5, 0, 1, 0)
ipClose.Size = UDim2.fromOffset(140, 44)
ipClose.BackgroundColor3 = C.surface.recessed
ipClose.Text = "Cancel"
ipClose.TextColor3 = C.text.primary
ipClose.Font = FONT.button.font
ipClose.TextSize = FONT.button.size
ipClose.BorderSizePixel = 0
ipClose.Parent = ipCard
local ipcc = Instance.new("UICorner") ipcc.CornerRadius = UDim.new(0, UI.radius.button) ipcc.Parent = ipClose
ipClose.Activated:Connect(function() itemPickerScreen.Enabled = false end)
ipOverlay.Activated:Connect(function() itemPickerScreen.Enabled = false end)

local function tradableItems()
	local rows = {}
	-- Mushrooms (always tradable).
	for speciesId, count in pairs(latestData.inventory or {}) do
		if Species.byId[speciesId] and count > 0 then
			-- Subtract any quantity already in our offer.
			local already = (currentSession and currentSession.you.offer.items[speciesId]) or 0
			local available = count - already
			if available > 0 then
				table.insert(rows, { id = speciesId, name = Species.byId[speciesId].displayName, available = available })
			end
		end
	end
	-- Non-mushroom items from inventoryByCategory.
	for cat, bucket in pairs(latestData.inventoryByCategory or {}) do
		for itemId, count in pairs(bucket) do
			local def = Constants.ITEMS[itemId]
			if def and def.tradable ~= false and count > 0 then
				local already = (currentSession and currentSession.you.offer.items[itemId]) or 0
				local available = count - already
				if available > 0 then
					table.insert(rows, { id = itemId, name = def.displayName or itemId, available = available })
				end
			end
		end
	end
	table.sort(rows, function(a, b) return a.name < b.name end)
	return rows
end

local function refreshItemPickerList()
	for _, child in ipairs(ipList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local rows = tradableItems()
	if #rows == 0 then
		local empty = Instance.new("Frame")
		empty.Size = UDim2.new(1, 0, 0, 56)
		empty.BackgroundTransparency = 1
		empty.Parent = ipList
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Text = "Nothing tradable in inventory."
		lbl.TextColor3 = C.text.muted
		lbl.Font = FONT.body.font
		lbl.TextSize = FONT.body.size
		lbl.Parent = empty
		return
	end
	for i, row in ipairs(rows) do
		local r = Instance.new("Frame")
		r.LayoutOrder = i
		r.Size = UDim2.new(1, 0, 0, 48)
		r.BackgroundColor3 = C.surface.recessed
		r.BorderSizePixel = 0
		r.Parent = ipList
		local rc = Instance.new("UICorner") rc.CornerRadius = UDim.new(0, UI.radius.chip) rc.Parent = r
		local rp = Instance.new("UIPadding")
		rp.PaddingLeft = UDim.new(0, SP.md) rp.PaddingRight = UDim.new(0, SP.md)
		rp.Parent = r

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -200, 1, 0)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = row.name .. "  (have " .. row.available .. ")"
		nameLbl.TextColor3 = C.text.primary
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.Font = FONT.body.font
		nameLbl.TextSize = FONT.body.size
		nameLbl.Parent = r

		local qty = 1
		local qtyLbl = Instance.new("TextLabel")
		qtyLbl.AnchorPoint = Vector2.new(1, 0.5)
		qtyLbl.Position = UDim2.new(1, -120, 0.5, 0)
		qtyLbl.Size = UDim2.fromOffset(40, 28)
		qtyLbl.BackgroundTransparency = 1
		qtyLbl.Text = tostring(qty)
		qtyLbl.TextColor3 = C.text.primary
		qtyLbl.Font = FONT.numeric.font
		qtyLbl.TextSize = FONT.numeric.size
		qtyLbl.Parent = r

		local function step(text, dx, delta)
			local b = Instance.new("TextButton")
			b.AnchorPoint = Vector2.new(1, 0.5)
			b.Position = UDim2.new(1, dx, 0.5, 0)
			b.Size = UDim2.fromOffset(28, 28)
			b.BackgroundColor3 = C.surface.bg
			b.Text = text
			b.TextColor3 = C.text.primary
			b.Font = FONT.button.font
			b.TextSize = 14
			b.BorderSizePixel = 0
			b.Parent = r
			local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, UI.radius.chip) c.Parent = b
			b.Activated:Connect(function()
				qty = math.clamp(qty + delta, 1, row.available)
				qtyLbl.Text = tostring(qty)
			end)
		end
		step("-", -156, -1)
		step("+", -88, 1)

		local addBtn = Instance.new("TextButton")
		addBtn.AnchorPoint = Vector2.new(1, 0.5)
		addBtn.Position = UDim2.new(1, 0, 0.5, 0)
		addBtn.Size = UDim2.fromOffset(72, 32)
		addBtn.BackgroundColor3 = C.accent.primary
		addBtn.Text = "Add"
		addBtn.TextColor3 = C.text.onAccent
		addBtn.Font = FONT.button.font
		addBtn.TextSize = 14
		addBtn.BorderSizePixel = 0
		addBtn.Parent = r
		local ac = Instance.new("UICorner") ac.CornerRadius = UDim.new(0, UI.radius.button) ac.Parent = addBtn
		addBtn.Activated:Connect(function()
			if not currentSession then return end
			local newOffer = {
				coins = currentSession.you.offer.coins or 0,
				items = {},
			}
			for k, v in pairs(currentSession.you.offer.items or {}) do
				newOffer.items[k] = v
			end
			newOffer.items[row.id] = (newOffer.items[row.id] or 0) + qty
			Remotes.get(Constants.REMOTES.UpdateTradeOffer):FireServer(currentSession.sessionId, newOffer)
			itemPickerScreen.Enabled = false
		end)
	end
end

_G.MyceliaTradeOpenItemPicker = function(_slotIndex)
	refreshItemPickerList()
	itemPickerScreen.Enabled = true
end

-- ---------- Server hooks --------------------------------------------------

Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(function(data)
	latestData = data or { inventory = {}, inventoryByCategory = {}, coins = 0 }
end)

Remotes.get(Constants.REMOTES.TradeRequestReceived).OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	showRequestToast(payload)
end)

Remotes.get(Constants.REMOTES.TradeSessionStarted).OnClientEvent:Connect(function(view)
	if type(view) ~= "table" then return end
	tradeScreen.Enabled = true
	renderTradeView(view)
end)

Remotes.get(Constants.REMOTES.TradeOfferUpdated).OnClientEvent:Connect(function(view)
	if type(view) ~= "table" then return end
	renderTradeView(view)
end)

Remotes.get(Constants.REMOTES.TradeCompleted).OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then return end
	if payload.success then
		showStatusToast("Trade complete!", true)
	else
		local code = payload.code or "UNKNOWN"
		if code == "DECLINED" then
			showStatusToast("Trade declined.", false)
		elseif code == "USER_CANCELLED" then
			showStatusToast("Trade cancelled.", false)
		elseif code == "REQUEST_TIMEOUT" then
			showStatusToast("Request timed out.", false)
		elseif code == "ALREADY_IN_TRADE" then
			showStatusToast("That player is already trading.", false)
		elseif code == "COOLDOWN" then
			showStatusToast("Wait a moment before requesting another trade.", false)
		elseif code == "PLAYER_DISCONNECTED" then
			showStatusToast("Trade cancelled — player disconnected.", false)
		elseif code == "INSUFFICIENT_INVENTORY" or code == "INSUFFICIENT_COINS" then
			showStatusToast("Trade cancelled — items moved during negotiation.", false)
		else
			showStatusToast("Trade ended: " .. code, false)
		end
	end
	closeTrade()
end)
