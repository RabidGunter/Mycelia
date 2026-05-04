-- Server-side dialogue dispatcher.
--
-- Listens for ProximityPrompt triggers on Parts tagged with the
-- `dialogueId` attribute and fires `OpenDialogue` to the player.
--
-- Listens for `DialogueAction(npcId, nodeId, responseId)` from clients,
-- validates the action exists in the dialogue tree at that node, then
-- dispatches to a server-side handler (open shop, give item, etc.).
--
-- Spec: docs/specs/dialogue-system.md.
-- Mutual exclusivity with Shop.luau: a Part with both attributes prefers
-- dialogue (Shop.luau's prompt handler skips dialogue-tagged Parts).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Dialogues = require(ReplicatedStorage.Shared.Dialogues)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Quest = require(ServerScriptService.Server.Quest)
local Travel = require(ServerScriptService.Server.Travel)
local Stall = require(ServerScriptService.Server.Stall)

local Dialogue = {}

-- ---------- Pure helpers ---------------------------------------------------

-- Returns the response table for (npcId, nodeId, responseId), or nil if any
-- of those don't resolve. Used by both the server validator and tests.
function Dialogue.findResponse(npcId: string, nodeId: string, responseId: string)
	local tree = Dialogues[npcId]
	if not tree or type(tree.nodes) ~= "table" then return nil end
	local node = tree.nodes[nodeId]
	if not node or type(node.responses) ~= "table" then return nil end
	for _, r in ipairs(node.responses) do
		if r.id == responseId then return r, node, tree end
	end
	return nil
end

-- True when the (npcId, nodeId, responseId) triple maps to a real response
-- carrying an action (i.e., something the server should execute). Pure.
function Dialogue.canExecuteAction(npcId, nodeId, responseId): boolean
	local r = Dialogue.findResponse(npcId, nodeId, responseId)
	return r ~= nil and r.action ~= nil and type(r.action.kind) == "string"
end

-- ---------- Roblox-bound side ---------------------------------------------

local function findDialogueAnchor(npcId: string): BasePart?
	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant:GetAttribute("dialogueId") == npcId then
			return descendant
		end
	end
	return nil
end

local function withinTalkRange(player: Player, npcId: string): boolean
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then return false end
	local anchor = findDialogueAnchor(npcId)
	if not anchor then return false end
	return (hrp.Position - anchor.Position).Magnitude <= Constants.MERCHANT_DEFAULTS.talkRange
end

-- ---------- Action handlers ------------------------------------------------

-- Each handler receives (player, action, npcId) and applies the side effect.
-- Add a new entry here when extending dialogue.
local ACTION_HANDLERS: { [string]: (Player, any, string) -> () } = {
	openShop = function(player, action, npcId)
		-- Either honor action.npcId (lets dialogue route to a different
		-- merchant if needed) or fall back to the dialogue's own npcId.
		local target = (type(action.npcId) == "string" and action.npcId) or npcId
		if not Constants.MERCHANTS[target] then
			warn("[Dialogue] openShop targets unknown merchant: " .. tostring(target))
			return
		end
		Remotes.get(Constants.REMOTES.OpenShop):FireClient(player, { npcId = target })
	end,
	endDialogue = function(_player, _action, _npcId)
		-- No-op. Client closes its own UI on response click for endDialogue;
		-- this exists so the action.kind is in the known set and the spec
		-- has a documented hook for future "log this conversation ended".
	end,
	startQuest = function(player, action, _npcId)
		if type(action.questId) ~= "string" then return end
		Quest.startQuest(player, action.questId)
	end,
	turnInQuest = function(player, action, _npcId)
		if type(action.questId) ~= "string" then return end
		Quest.turnInQuest(player, action.questId)
	end,
	requestBiomeTravel = function(player, action, _npcId)
		if type(action.biomeId) ~= "string" then return end
		Travel.requestTravel(player, action.biomeId)
	end,
	-- Player Stalls (Phase 2). Dialogue routes the StallManager's "Manage my
	-- stall" / "Open my mailbox" responses to the OpenStallOwnerUI remote;
	-- the "Rent a featured slot" confirmation routes to Stall.requestRentFeatured
	-- (same code path the RentFeaturedSlot remote handler uses — B-6 lock).
	openStallOwnerUI = function(player, action, _npcId)
		local tab = (type(action.tab) == "string") and action.tab or "listings"
		Remotes.get(Constants.REMOTES.OpenStallOwnerUI):FireClient(player, { tab = tab })
	end,
	rentFeaturedSlot = function(player, _action, _npcId)
		Stall.requestRentFeatured(player)
	end,
}

local function handlePromptTrigger(prompt: ProximityPrompt, player: Player)
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then return end
	local npcId = part:GetAttribute("dialogueId")
	if type(npcId) ~= "string" then return end
	local tree = Dialogues[npcId]
	if not tree then
		warn("[Dialogue] Prompt tagged dialogueId=" .. npcId .. " but no Dialogues entry")
		return
	end
	Remotes.get(Constants.REMOTES.OpenDialogue):FireClient(player, {
		npcId = npcId,
		startNodeId = tree.rootNodeId,
	})
end

local function handleAction(player: Player, npcId: any, nodeId: any, responseId: any)
	if type(npcId) ~= "string" or type(nodeId) ~= "string" or type(responseId) ~= "string" then
		return
	end
	local response = Dialogue.findResponse(npcId, nodeId, responseId)
	if not response or not response.action then return end
	if not withinTalkRange(player, npcId) then return end

	local handler = ACTION_HANDLERS[response.action.kind]
	if not handler then
		warn("[Dialogue] Unknown action kind: " .. tostring(response.action.kind))
		return
	end
	handler(player, response.action, npcId)
end

function Dialogue.start()
	ProximityPromptService.PromptTriggered:Connect(handlePromptTrigger)
	Remotes.get(Constants.REMOTES.DialogueAction).OnServerEvent:Connect(handleAction)
end

return Dialogue
