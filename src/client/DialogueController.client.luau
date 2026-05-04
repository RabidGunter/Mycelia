-- Client-side dialogue controller.
--
-- Receives `OpenDialogue({npcId, startNodeId})` from the server when the
-- player triggers an NPC's ProximityPrompt. Walks the local dialogue tree
-- from Dialogues.luau. Each response either navigates to a sibling node
-- (no server round-trip) or fires `DialogueAction` to the server (for
-- side effects like opening a shop).
--
-- Spec: docs/specs/dialogue-system.md.
-- Visual tokens: Constants.UI per docs/specs/visual-language.md.
-- Constructed with plain Roblox Instance code (matches ShopUI / Journal
-- conventions).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dialogues = require(ReplicatedStorage.Shared.Dialogues)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local UI = Constants.UI
local C = UI.color
local FONT = UI.typography
local SP = UI.space

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ---------- State --------------------------------------------------------

local currentNpcId: string? = nil
local currentTree: any = nil
local currentNodeId: string? = nil
local currentAnchor: BasePart? = nil
local latestData: any = nil   -- cached from PlayerDataUpdated; used to evaluate response.condition

-- Walk-away auto-close: end the conversation if the player wanders too far
-- from the NPC anchor. Runs at 4Hz off Heartbeat so it isn't spammy. Range
-- is the merchant talkRange + a few studs of grace so the dialogue doesn't
-- close exactly on the prompt edge.
local WALK_AWAY_RANGE = (Constants.MERCHANT_DEFAULTS and Constants.MERCHANT_DEFAULTS.talkRange or 14) + 4
local CHECK_INTERVAL = 0.25
local walkAwayConn: RBXScriptConnection? = nil
local checkAccumulator = 0

local function findAnchor(npcId: string): BasePart?
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("dialogueId") == npcId then
			return descendant
		end
	end
	return nil
end

-- ---------- ScreenGui ----------------------------------------------------

local screen = Instance.new("ScreenGui")
screen.Name = "DialogueUI"
screen.ResetOnSpawn = false
screen.DisplayOrder = 11   -- below ShopUI (12), above HUD
screen.Enabled = false
screen.IgnoreGuiInset = true
screen.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = C.forest.ink
overlay.BackgroundTransparency = 0.65
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = screen

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 1)
card.Position = UDim2.new(0.5, 0, 1, -SP.lg)
card.Size = UDim2.new(0.92, 0, 0.5, 0)
card.BackgroundColor3 = C.surface.panel
card.BorderSizePixel = 0
card.Parent = screen

local cardSize = Instance.new("UISizeConstraint")
cardSize.MaxSize = Vector2.new(560, 360)
cardSize.MinSize = Vector2.new(280, 240)
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

-- ---------- Header (portrait + speaker name) -----------------------------

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 64)
header.BackgroundTransparency = 1
header.Parent = card

local portrait = Instance.new("Frame")
portrait.AnchorPoint = Vector2.new(0, 0.5)
portrait.Position = UDim2.new(0, 0, 0.5, 0)
portrait.Size = UDim2.fromOffset(56, 56)
portrait.BackgroundColor3 = C.forest.sage
portrait.BorderSizePixel = 0
portrait.Parent = header
local portraitCorner = Instance.new("UICorner")
portraitCorner.CornerRadius = UDim.new(1, 0)
portraitCorner.Parent = portrait

local portraitInitial = Instance.new("TextLabel")
portraitInitial.Size = UDim2.fromScale(1, 1)
portraitInitial.BackgroundTransparency = 1
portraitInitial.Text = "?"
portraitInitial.TextColor3 = C.text.onAccent
portraitInitial.Font = FONT.display.font
portraitInitial.TextSize = 24
portraitInitial.Parent = portrait

local speakerName = Instance.new("TextLabel")
speakerName.Position = UDim2.new(0, 72, 0, 14)
speakerName.Size = UDim2.new(1, -72, 0, 22)
speakerName.BackgroundTransparency = 1
speakerName.Text = ""
speakerName.TextColor3 = C.text.primary
speakerName.TextXAlignment = Enum.TextXAlignment.Left
speakerName.Font = FONT.display.font
speakerName.TextSize = 20
speakerName.Parent = header

local speakerSubtitle = Instance.new("TextLabel")
speakerSubtitle.Position = UDim2.new(0, 72, 0, 36)
speakerSubtitle.Size = UDim2.new(1, -72, 0, 16)
speakerSubtitle.BackgroundTransparency = 1
speakerSubtitle.Text = "speaking…"
speakerSubtitle.TextColor3 = C.text.muted
speakerSubtitle.TextXAlignment = Enum.TextXAlignment.Left
speakerSubtitle.Font = FONT.caption.font
speakerSubtitle.TextSize = FONT.caption.size
speakerSubtitle.Parent = header

-- ---------- Body line ----------------------------------------------------

local lineLabel = Instance.new("TextLabel")
lineLabel.Position = UDim2.new(0, 0, 0, 80)
lineLabel.Size = UDim2.new(1, 0, 0, 80)
lineLabel.BackgroundTransparency = 1
lineLabel.Text = ""
lineLabel.TextColor3 = C.text.primary
lineLabel.TextXAlignment = Enum.TextXAlignment.Left
lineLabel.TextYAlignment = Enum.TextYAlignment.Top
lineLabel.TextWrapped = true
lineLabel.Font = FONT.body.font
lineLabel.TextSize = 16
lineLabel.Parent = card

-- ---------- Response list -----------------------------------------------

local responses = Instance.new("ScrollingFrame")
responses.AnchorPoint = Vector2.new(0, 1)
responses.Position = UDim2.new(0, 0, 1, 0)
responses.Size = UDim2.new(1, 0, 1, -176)  -- fills below the line label
responses.BackgroundTransparency = 1
responses.BorderSizePixel = 0
responses.ScrollBarThickness = 4
responses.ScrollBarImageColor3 = C.surface.divider
responses.CanvasSize = UDim2.new(0, 0, 0, 0)
responses.Parent = card

local responsesLayout = Instance.new("UIListLayout")
responsesLayout.Padding = UDim.new(0, SP.sm)
responsesLayout.SortOrder = Enum.SortOrder.LayoutOrder
responsesLayout.Parent = responses
responsesLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	responses.CanvasSize = UDim2.new(0, 0, 0, responsesLayout.AbsoluteContentSize.Y)
end)

local function clearResponses()
	for _, child in ipairs(responses:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end
end

-- ---------- Forward decl for navigation ---------------------------------

local renderNode

-- ---------- Open / close -------------------------------------------------

local function stopWalkAwayCheck()
	if walkAwayConn then
		walkAwayConn:Disconnect()
		walkAwayConn = nil
	end
end

local function closeDialogue()
	screen.Enabled = false
	currentNpcId = nil
	currentTree = nil
	currentNodeId = nil
	currentAnchor = nil
	clearResponses()
	stopWalkAwayCheck()
end

local function startWalkAwayCheck()
	stopWalkAwayCheck()
	checkAccumulator = 0
	walkAwayConn = RunService.Heartbeat:Connect(function(dt)
		checkAccumulator += dt
		if checkAccumulator < CHECK_INTERVAL then return end
		checkAccumulator = 0
		if not screen.Enabled or not currentAnchor or not currentAnchor.Parent then
			closeDialogue()
			return
		end
		local character = player.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if not hrp or not hrp:IsA("BasePart") then
			-- Player died or character despawned — end the conversation.
			closeDialogue()
			return
		end
		if (hrp.Position - currentAnchor.Position).Magnitude > WALK_AWAY_RANGE then
			closeDialogue()
		end
	end)
end

overlay.Activated:Connect(closeDialogue)

local function buildResponseButton(response, layoutOrder: number)
	local btn = Instance.new("TextButton")
	btn.LayoutOrder = layoutOrder
	btn.Size = UDim2.new(1, 0, 0, 44)
	btn.BackgroundColor3 = C.surface.recessed
	btn.AutoButtonColor = true
	btn.Text = response.text
	btn.TextColor3 = C.text.primary
	btn.Font = FONT.button.font
	btn.TextSize = FONT.button.size
	btn.BorderSizePixel = 0
	btn.Parent = responses
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, UI.radius.button)
	corner.Parent = btn
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, SP.md)
	pad.PaddingRight = UDim.new(0, SP.md)
	pad.Parent = btn

	btn.Activated:Connect(function()
		if not currentNpcId or not currentNodeId then return end
		if response.next and currentTree and currentTree.nodes[response.next] then
			renderNode(response.next)
			return
		end
		if response.action then
			-- For endDialogue, close instantly without server round-trip.
			if response.action.kind == "endDialogue" then
				closeDialogue()
				return
			end
			-- Fire to server for validation + dispatch.
			Remotes.get(Constants.REMOTES.DialogueAction):FireServer(currentNpcId, currentNodeId, response.id)
			-- Most actions transition out of dialogue (open shop, give quest).
			-- Close locally; the server-side action will surface its own UI.
			closeDialogue()
		end
	end)
	return btn
end

renderNode = function(nodeId: string)
	if not currentTree or not currentTree.nodes then return end
	local node = currentTree.nodes[nodeId]
	if not node then
		warn("[Dialogue] Node not found: " .. tostring(nodeId))
		closeDialogue()
		return
	end
	currentNodeId = nodeId
	lineLabel.Text = node.text or ""
	clearResponses()
	if type(node.responses) == "table" then
		local layoutOrder = 1
		for _, r in ipairs(node.responses) do
			-- Hide responses whose condition evaluates false against the
			-- current player data. Responses without a condition are always
			-- shown. Server re-validates on action so this is purely UX.
			local visible = true
			if type(r.condition) == "function" then
				local ok, result = pcall(r.condition, latestData)
				visible = ok and result == true
			end
			if visible then
				buildResponseButton(r, layoutOrder)
				layoutOrder += 1
			end
		end
	end
end

local function openDialogue(npcId: string, startNodeId: string?)
	local tree = Dialogues[npcId]
	if not tree then
		warn("[Dialogue] Unknown NPC: " .. tostring(npcId))
		return
	end
	currentNpcId = npcId
	currentTree = tree
	currentAnchor = findAnchor(npcId)  -- cached for the walk-away check
	speakerName.Text = tree.speakerName or npcId
	-- Portrait: first letter of the speaker name as a placeholder until
	-- real portrait assets ship.
	local nameStr = tree.speakerName or npcId
	portraitInitial.Text = string.sub(nameStr, 1, 1):upper()
	speakerSubtitle.Text = "speaking…"
	screen.Enabled = true
	renderNode(startNodeId or tree.rootNodeId)
	startWalkAwayCheck()
end

-- ---------- Server hooks -------------------------------------------------

Remotes.get(Constants.REMOTES.OpenDialogue).OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" or type(payload.npcId) ~= "string" then return end
	openDialogue(payload.npcId, payload.startNodeId)
end)

-- Cache replicated player data so response.condition closures can read
-- quest state etc. PlayerData arrives via PlayerDataUpdated continuously;
-- if a quest state changes mid-dialogue, re-render the current node so
-- response visibility updates live (e.g., a quest just hit completion
-- threshold while the player is mid-conversation).
Remotes.get(Constants.REMOTES.PlayerDataUpdated).OnClientEvent:Connect(function(data)
	latestData = data
	if screen.Enabled and currentNodeId then
		renderNode(currentNodeId)
	end
end)
