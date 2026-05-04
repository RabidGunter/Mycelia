-- Server-side quest tracker.
--
-- Connects to gameplay-event sources (Harvesting BindableEvents + minimal
-- direct calls from Brewing/Planting/Shop) and applies progress against
-- every active quest. Lifecycle (start, turn-in) is invoked from Dialogue.luau
-- via action handlers.
--
-- Public API:
--   Quest.start(harvesting)               - wires event listeners. Pass the
--                                            same Harvesting module reference
--                                            init.server.luau already holds.
--   Quest.onEvent(player, kind, payload)  - direct call site for modules
--                                            without BindableEvents (Planting,
--                                            Brewing, Shop, PotionEffects).
--   Quest.startQuest(player, questId)     - dialogue handler entry.
--   Quest.turnInQuest(player, questId)    - dialogue handler entry.
--   Quest.abandonQuest(player, questId)   - exposed for AbandonQuest remote.
--
-- Spec: docs/specs/quest-system.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Quests = require(ReplicatedStorage.Shared.Quests)
local Species = require(ReplicatedStorage.Shared.Species)
local Inventory = require(ServerScriptService.Server.Inventory)
local PlayerData = require(ServerScriptService.Server.PlayerData)

local Quest = {}

-- ---------- Reward delivery ------------------------------------------------

-- Drop a quest reward into the right inventory bucket. Mushroom species ids
-- go into legacy `data.inventory`; everything else routes by Constants.ITEMS
-- category (substrates → inventoryByCategory.substrates, etc.). Mirrors the
-- Phase 2 inventory split (see docs/specs/shop-ui.md).
local function depositReward(data, itemId: string, qty: number)
	if Species.byId[itemId] then
		Inventory.add(data.inventory, itemId, qty)
		return
	end
	local item = Constants.ITEMS[itemId]
	if not item then
		warn("[Quest] Reward references unknown item: " .. itemId)
		return
	end
	local bucket = item.category or "tools"
	data.inventoryByCategory = data.inventoryByCategory or {}
	data.inventoryByCategory[bucket] = data.inventoryByCategory[bucket] or {}
	data.inventoryByCategory[bucket][itemId] = (data.inventoryByCategory[bucket][itemId] or 0) + qty
end

-- ---------- Lifecycle ------------------------------------------------------

function Quest.startQuest(player: Player, questId: string): boolean
	local data = PlayerData.get(player)
	if not data then return false end
	if not Quests.canAccept(data, questId) then return false end

	PlayerData.update(player, function(d)
		d.activeQuests = d.activeQuests or {}
		d.activeQuests[questId] = {
			acceptedAt = os.time(),
			progress = {},
		}
	end)
	print(string.format("[Quest] %s started %s", player.Name, questId))
	return true
end

function Quest.turnInQuest(player: Player, questId: string): boolean
	local data = PlayerData.get(player)
	if not data then return false end
	if not Quests.canTurnIn(data, questId) then return false end
	local quest = Quests.byId[questId]
	if not quest then return false end

	PlayerData.update(player, function(d)
		-- Move from active → completed.
		d.activeQuests = d.activeQuests or {}
		d.activeQuests[questId] = nil
		d.stats.questsCompleted = d.stats.questsCompleted or {}
		d.stats.questsCompleted[questId] = true

		-- Apply rewards.
		local rewards = quest.rewards or {}
		if type(rewards.coins) == "number" and rewards.coins > 0 then
			d.coins = (d.coins or 0) + rewards.coins
			d.stats.totalCoinsEarned = (d.stats.totalCoinsEarned or 0) + rewards.coins
		end
		if type(rewards.items) == "table" then
			for itemId, qty in pairs(rewards.items) do
				if type(qty) == "number" and qty > 0 then
					depositReward(d, itemId, qty)
				end
			end
		end
	end)
	print(string.format("[Quest] %s turned in %s", player.Name, questId))
	return true
end

function Quest.abandonQuest(player: Player, questId: string): boolean
	local data = PlayerData.get(player)
	if not data or not Quests.isActive(data, questId) then return false end
	PlayerData.update(player, function(d)
		d.activeQuests[questId] = nil
	end)
	return true
end

-- ---------- Event tracking -------------------------------------------------

function Quest.onEvent(player: Player, kind: string, payload: any)
	if type(kind) ~= "string" or not Quests.OBJECTIVE_KINDS[kind] then return end
	local data = PlayerData.get(player)
	if not data then return end
	-- Cheap pre-check: if no active quests, skip the update call entirely.
	if type(data.activeQuests) ~= "table" or next(data.activeQuests) == nil then return end

	-- Pre-check: would any active objective actually advance from this event?
	-- Both the kind/target match AND the objective is below its count cap.
	-- Read-only — PlayerData.get returned the LIVE profile.Data reference, so
	-- mutating here would skip replication. The actual mutation happens inside
	-- PlayerData.update below.
	local anyMatch = false
	for questId, state in pairs(data.activeQuests) do
		local quest = Quests.byId[questId]
		if quest then
			local progress = state.progress or {}
			for i, obj in ipairs(quest.objectives) do
				if Quests.objectiveMatches(obj, kind, payload) and (progress[i] or 0) < obj.count then
					anyMatch = true
					break
				end
			end
		end
		if anyMatch then break end
	end
	if not anyMatch then return end

	PlayerData.update(player, function(d)
		Quests.applyEvent(d, kind, payload)
	end)
end

-- ---------- Remote handlers ----------------------------------------------

local function handleAccept(player, questId)
	if type(questId) == "string" then Quest.startQuest(player, questId) end
end
local function handleTurnIn(player, questId)
	if type(questId) == "string" then Quest.turnInQuest(player, questId) end
end
local function handleAbandon(player, questId)
	if type(questId) == "string" then Quest.abandonQuest(player, questId) end
end

-- ---------- Wiring --------------------------------------------------------

function Quest.start(harvesting)
	-- Connect to existing Harvesting BindableEvents — no edit to that module.
	if harvesting and harvesting.WildHarvested then
		harvesting.WildHarvested.Event:Connect(function(player, _root, speciesId)
			Quest.onEvent(player, "harvest_wild", { speciesId = speciesId, count = 1 })
		end)
	end
	if harvesting and harvesting.PlotHarvested then
		harvesting.PlotHarvested.Event:Connect(function(player, _plot, speciesId)
			Quest.onEvent(player, "harvest_plot", { speciesId = speciesId, count = 1 })
		end)
	end

	local Remotes = require(ReplicatedStorage.Shared.Remotes)
	Remotes.get(Constants.REMOTES.AcceptQuest).OnServerEvent:Connect(handleAccept)
	Remotes.get(Constants.REMOTES.TurnInQuest).OnServerEvent:Connect(handleTurnIn)
	Remotes.get(Constants.REMOTES.AbandonQuest).OnServerEvent:Connect(handleAbandon)
end

return Quest
