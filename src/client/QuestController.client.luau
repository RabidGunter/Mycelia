-- Quest Journal modal + HUD pinned widget.
--
-- Renders two pieces of UI:
--   1. HUD widget (top-right corner) — shows the currently-tracked quest's
--      title + first incomplete objective with progress. Click to open the
--      Journal. Hidden when no active quests.
--   2. Quest Journal modal — three tabs (Active / Completed / Available).
--      Each row: title + description + objective progress + reward summary.
--
-- Reads from the PlayerDataUpdated cache (data.activeQuests + stats.questsCompleted).
-- Reads quest definitions from Quests.luau (shared, pure).
--
-- Spec: docs/specs/quest-system.md.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local UI = Constants.UI
local C = UI.color
local FONT = UI.typography
local SP = UI.space

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local latestData: any = { activeQuests = {}, stats = { questsCompleted = {} } }

-- ---------- Helpers --------------------------------------------------------

local function activeQuestList()
	local list = {}
	if type(latestData.activeQuests) == "table" then
		for questId, state in pairs(latestData.activeQuests) do
			local quest = Quests.byId[questId]
			if quest then table.insert(list, { quest = quest, state = state }) end
		end
	end
	-- Stable sort by quest order in Quests.LIST.
	local order = {}
	for i, q in ipairs(Quests.LIST) do order[q.id] = i end
	table.sort(list, function(a, b) return (order[a.quest.id] or 99) < (order[b.quest.id] or 99) end)
	return list
end

local function completedQuestList()
	local list = {}
	if type(latestData.stats) == "table" and type(latestData.stats.questsCompleted) == "table" then
		for questId, done in pairs(latestData.stats.questsCompleted) do
			if done then
				local quest = Quests.byId[questId]
				if quest then table.insert(list, quest) end
			end
		end
	end
	local order = {}
	for i, q in ipairs(Quests.LIST) do order[q.id] = i end
	table.sort(list, function(a, b) return (order[a.id] or 99) < (order[b.id] or 99) end)
	return list
end

local function availableQuestList()
	local list = {}
	for _, quest in ipairs(Quests.LIST) do
		if Quests.canAccept(latestData, quest.id) then
			table.insert(list, quest)
		end
	end
	return list
end

local function firstIncompleteObjective(quest, state)
	local progress = (state or {}).progress or {}
	for i, obj in ipairs(quest.objectives) do
		if (progress[i] or 0) < obj.count then
			return i, obj, progress[i] or 0
		end
	end
	return nil, nil, nil
end

-- ---------- HUD widget -----------------------------------------------------

local hudScreen = Instance.new("ScreenGui")
hudScreen.Name = "QuestHUD"
hudScreen.ResetOnSpawn = false
hudScreen.Parent = playerGui

local widget = Instance.new("TextButton")
widget.AnchorPoint = Vector2.new(1, 0)
widget.Position = UDim2.new(1, -SP.md, 0, SP.md)
widget.Size = UDim2.fromOffset(220, 64)
widget.BackgroundColor3 = C.surface.panel
widget.AutoButtonColor = false
widget.Text = ""
widget.BorderSizePixel = 0
widget.Visible = false
widget.Parent = hudScreen
local widgetCorner = Instance.new("UICorner")
widgetCorner.CornerRadius = UDim.new(0, UI.radius.card)
widgetCorner.Parent = widget
local widgetStroke = Instance.new("UIStroke")
widgetStroke.Color = C.surface.divider
widgetStroke.Thickness = 1
widgetStroke.Parent = widget
local widgetPad = Instance.new("UIPadding")
widgetPad.PaddingLeft = UDim.new(0, SP.md)
widgetPad.PaddingRight = UDim.new(0, SP.md)
widgetPad.PaddingTop = UDim.new(0, SP.sm)
widgetPad.PaddingBottom = UDim.new(0, SP.sm)
widgetPad.Parent = widget

local widgetTitle = Instance.new("TextLabel")
widgetTitle.Size = UDim2.new(1, 0, 0, 22)
widgetTitle.BackgroundTransparency = 1
widgetTitle.Text = ""
widgetTitle.TextColor3 = C.text.primary
widgetTitle.TextXAlignment = Enum.TextXAlignment.Left
widgetTitle.Font = FONT.display.font
widgetTitle.TextSize = 16
widgetTitle.Parent = widget

local widgetObjective = Instance.new("TextLabel")
widgetObjective.Position = UDim2.new(0, 0, 0, 24)
widgetObjective.Size = UDim2.new(1, 0, 0, 18)
widgetObjective.BackgroundTransparency = 1
widgetObjective.Text = ""
widgetObjective.TextColor3 = C.text.secondary
widgetObjective.TextXAlignment = Enum.TextXAlignment.Left
widgetObjective.Font = FONT.body.font
widgetObjective.TextSize = 13
widgetObjective.Parent = widget

local widgetProgress = Instance.new("TextLabel")
widgetProgress.AnchorPoint = Vector2.new(1, 1)
widgetProgress.Position = UDim2.new(1, 0, 1, 0)
widgetProgress.Size = UDim2.fromOffset(80, 18)
widgetProgress.BackgroundTransparency = 1
widgetProgress.Text = ""
widgetProgress.TextColor3 = C.accent.gold
widgetProgress.TextXAlignment = Enum.TextXAlignment.Right
widgetProgress.Font = FONT.numeric.font
widgetProgress.TextSize = 14
widgetProgress.Parent = widget

local function refreshWidget()
	local active = activeQuestList()
	if #active == 0 then
		widget.Visible = false
		return
	end
	local first = active[1]
	local _i, obj, current = firstIncompleteObjective(first.quest, first.state)
	widget.Visible = true
	widgetTitle.Text = first.quest.title
	if obj then
		widgetObjective.Text = obj.label
		widgetProgress.Text = string.format("%d / %d", current or 0, obj.count)
	else
		-- All objectives complete — quest is ready to turn in.
		widgetObjective.Text = "Ready to turn in"
		widgetProgress.Text = "✓"
		widgetProgress.TextColor3 = C.state.success
	end
end

-- ---------- Journal modal --------------------------------------------------

local journalScreen = Instance.new("ScreenGui")
journalScreen.Name = "QuestJournal"
journalScreen.ResetOnSpawn = false
journalScreen.DisplayOrder = 10
journalScreen.Enabled = false
journalScreen.IgnoreGuiInset = true
journalScreen.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = C.forest.ink
overlay.BackgroundTransparency = 0.55
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = journalScreen

local card = Instance.new("Frame")
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.new(0.92, 0, 0.85, 0)
card.BackgroundColor3 = C.surface.panel
card.BorderSizePixel = 0
card.Parent = journalScreen
local cardSize = Instance.new("UISizeConstraint")
cardSize.MaxSize = Vector2.new(520, 720)
cardSize.MinSize = Vector2.new(280, 420)
cardSize.Parent = card
local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, UI.radius.card)
cardCorner.Parent = card
local cardPad = Instance.new("UIPadding")
cardPad.PaddingTop = UDim.new(0, SP.lg)
cardPad.PaddingBottom = UDim.new(0, SP.lg)
cardPad.PaddingLeft = UDim.new(0, SP.lg)
cardPad.PaddingRight = UDim.new(0, SP.lg)
cardPad.Parent = card

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 32)
title.BackgroundTransparency = 1
title.Text = "Quest Journal"
title.TextColor3 = C.text.primary
title.TextXAlignment = Enum.TextXAlignment.Left
title.Font = FONT.display.font
title.TextSize = 22
title.Parent = card

-- Tabs
local tabStrip = Instance.new("Frame")
tabStrip.Position = UDim2.new(0, 0, 0, 40)
tabStrip.Size = UDim2.new(1, 0, 0, 32)
tabStrip.BackgroundTransparency = 1
tabStrip.Parent = card
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, SP.md)
tabLayout.Parent = tabStrip

local function makeTab(name)
	local btn = Instance.new("TextButton")
	btn.Name = name
	btn.Size = UDim2.fromOffset(96, 32)
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

local activeTab = makeTab("Active")
local completedTab = makeTab("Completed")
local availableTab = makeTab("Available")

local body = Instance.new("ScrollingFrame")
body.Position = UDim2.new(0, 0, 0, 80)
body.Size = UDim2.new(1, 0, 1, -80 - 56)
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

local closeBtn = Instance.new("TextButton")
closeBtn.AnchorPoint = Vector2.new(0.5, 1)
closeBtn.Position = UDim2.new(0.5, 0, 1, 0)
closeBtn.Size = UDim2.fromOffset(160, 44)
closeBtn.BackgroundColor3 = C.surface.recessed
closeBtn.Text = "Close"
closeBtn.TextColor3 = C.text.primary
closeBtn.Font = FONT.button.font
closeBtn.TextSize = FONT.button.size
closeBtn.BorderSizePixel = 0
closeBtn.Parent = card
local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, UI.radius.button)
closeCorner.Parent = closeBtn

local function clearBody()
	for _, c in ipairs(body:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
end

local function rewardsText(rewards)
	local parts = {}
	if type(rewards.coins) == "number" and rewards.coins > 0 then
		table.insert(parts, string.format("%d coins", rewards.coins))
	end
	if type(rewards.items) == "table" then
		for itemId, qty in pairs(rewards.items) do
			table.insert(parts, string.format("%d× %s", qty, itemId))
		end
	end
	if #parts == 0 then return "" end
	return "Reward: " .. table.concat(parts, ", ")
end

local function buildQuestRow(quest, state, kind, layoutOrder)
	local row = Instance.new("Frame")
	row.LayoutOrder = layoutOrder
	row.Size = UDim2.new(1, 0, 0, 100)
	row.BackgroundColor3 = C.surface.recessed
	row.BorderSizePixel = 0
	row.Parent = body
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI.radius.chip)
	corner.Parent = row
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, SP.md)
	pad.PaddingRight = UDim.new(0, SP.md)
	pad.PaddingTop = UDim.new(0, SP.sm)
	pad.PaddingBottom = UDim.new(0, SP.sm)
	pad.Parent = row

	local titleLbl = Instance.new("TextLabel")
	titleLbl.Size = UDim2.new(1, -32, 0, 22)
	titleLbl.BackgroundTransparency = 1
	titleLbl.Text = quest.title
	titleLbl.TextColor3 = C.text.primary
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Font = FONT.display.font
	titleLbl.TextSize = 18
	titleLbl.Parent = row

	if kind == "completed" then
		local check = Instance.new("TextLabel")
		check.AnchorPoint = Vector2.new(1, 0)
		check.Position = UDim2.new(1, 0, 0, 0)
		check.Size = UDim2.fromOffset(24, 22)
		check.BackgroundTransparency = 1
		check.Text = "✓"
		check.TextColor3 = C.state.success
		check.Font = FONT.button.font
		check.TextSize = 18
		check.Parent = row
	end

	local desc = Instance.new("TextLabel")
	desc.Position = UDim2.new(0, 0, 0, 24)
	desc.Size = UDim2.new(1, 0, 0, 32)
	desc.BackgroundTransparency = 1
	desc.Text = quest.description
	desc.TextColor3 = C.text.secondary
	desc.TextXAlignment = Enum.TextXAlignment.Left
	desc.TextYAlignment = Enum.TextYAlignment.Top
	desc.TextWrapped = true
	desc.Font = FONT.body.font
	desc.TextSize = 13
	desc.Parent = row

	local objText = ""
	if kind == "active" then
		local progress = (state or {}).progress or {}
		local lines = {}
		for i, obj in ipairs(quest.objectives) do
			local cur = progress[i] or 0
			local check = (cur >= obj.count) and "✓" or "•"
			table.insert(lines, string.format("  %s %s  %d / %d", check, obj.label, cur, obj.count))
		end
		objText = table.concat(lines, "\n")
	end
	if kind == "available" then
		local lines = {}
		for _, obj in ipairs(quest.objectives) do
			table.insert(lines, "  • " .. obj.label)
		end
		objText = table.concat(lines, "\n")
	end
	if objText ~= "" then
		local objLbl = Instance.new("TextLabel")
		objLbl.Position = UDim2.new(0, 0, 0, 60)
		objLbl.Size = UDim2.new(1, 0, 0, 24)
		objLbl.BackgroundTransparency = 1
		objLbl.Text = objText
		objLbl.TextColor3 = C.text.primary
		objLbl.TextXAlignment = Enum.TextXAlignment.Left
		objLbl.TextYAlignment = Enum.TextYAlignment.Top
		objLbl.Font = FONT.numeric.font
		objLbl.TextSize = 13
		objLbl.Parent = row
	end

	local rewardLbl = Instance.new("TextLabel")
	rewardLbl.AnchorPoint = Vector2.new(1, 1)
	rewardLbl.Position = UDim2.new(1, 0, 1, 0)
	rewardLbl.Size = UDim2.new(1, 0, 0, 16)
	rewardLbl.BackgroundTransparency = 1
	rewardLbl.Text = rewardsText(quest.rewards or {})
	rewardLbl.TextColor3 = C.accent.gold
	rewardLbl.TextXAlignment = Enum.TextXAlignment.Right
	rewardLbl.Font = FONT.caption.font
	rewardLbl.TextSize = FONT.caption.size
	rewardLbl.Parent = row
end

local currentTab = "Active"

local function renderTab(tab)
	currentTab = tab
	activeTab:FindFirstChild("Underline").Visible    = tab == "Active"
	completedTab:FindFirstChild("Underline").Visible = tab == "Completed"
	availableTab:FindFirstChild("Underline").Visible = tab == "Available"
	activeTab.TextColor3    = (tab == "Active")    and C.text.primary or C.text.secondary
	completedTab.TextColor3 = (tab == "Completed") and C.text.primary or C.text.secondary
	availableTab.TextColor3 = (tab == "Available") and C.text.primary or C.text.secondary
	clearBody()
	local rows
	if tab == "Active" then
		rows = activeQuestList()
		if #rows == 0 then
			local empty = Instance.new("Frame")
			empty.Size = UDim2.new(1, 0, 0, 56)
			empty.BackgroundTransparency = 1
			empty.Parent = body
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = "No active quests. Talk to NPCs to find work."
			lbl.TextColor3 = C.text.muted
			lbl.Font = FONT.body.font
			lbl.TextSize = FONT.body.size
			lbl.Parent = empty
		else
			for i, entry in ipairs(rows) do
				buildQuestRow(entry.quest, entry.state, "active", i)
			end
		end
	elseif tab == "Completed" then
		rows = completedQuestList()
		if #rows == 0 then
			local empty = Instance.new("Frame")
			empty.Size = UDim2.new(1, 0, 0, 56)
			empty.BackgroundTransparency = 1
			empty.Parent = body
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = "Nothing finished yet."
			lbl.TextColor3 = C.text.muted
			lbl.Font = FONT.body.font
			lbl.TextSize = FONT.body.size
			lbl.Parent = empty
		else
			for i, q in ipairs(rows) do buildQuestRow(q, nil, "completed", i) end
		end
	else
		rows = availableQuestList()
		if #rows == 0 then
			local empty = Instance.new("Frame")
			empty.Size = UDim2.new(1, 0, 0, 56)
			empty.BackgroundTransparency = 1
			empty.Parent = body
			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.fromScale(1, 1)
			lbl.BackgroundTransparency = 1
			lbl.Text = "No quests available right now."
			lbl.TextColor3 = C.text.muted
			lbl.Font = FONT.body.font
			lbl.TextSize = FONT.body.size
			lbl.Parent = empty
		else
			for i, q in ipairs(rows) do buildQuestRow(q, nil, "available", i) end
		end
	end
end

local function openJournal()
	journalScreen.Enabled = true
	renderTab(currentTab)
end
local function closeJournal()
	journalScreen.Enabled = false
end

activeTab.Activated:Connect(function() renderTab("Active") end)
completedTab.Activated:Connect(function() renderTab("Completed") end)
availableTab.Activated:Connect(function() renderTab("Available") end)
closeBtn.Activated:Connect(closeJournal)
overlay.Activated:Connect(closeJournal)
widget.Activated:Connect(openJournal)

-- ---------- Server hooks --------------------------------------------------

Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(function(data)
	latestData = data or { activeQuests = {}, stats = { questsCompleted = {} } }
	refreshWidget()
	if journalScreen.Enabled then renderTab(currentTab) end
end)

refreshWidget()
