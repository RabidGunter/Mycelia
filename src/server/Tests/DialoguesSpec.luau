-- Tests for the dialogue system.
--
-- Schema integrity for every Dialogues tree (rootNodeId resolves, every
-- response is well-formed, every `next` points to a real node, every
-- action.kind is in the known set).
--
-- Plus pure-helper coverage for Dialogue.findResponse / Dialogue.canExecuteAction.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local Dialogues = require(ReplicatedStorage.Shared.Dialogues)
local Dialogue = require(ServerScriptService.Server.Dialogue)

-- Action kinds that the server's dispatcher knows about. Must be kept
-- in sync with ACTION_HANDLERS in src/server/Dialogue.luau. A test fails
-- when a tree adds an unknown kind, prompting a deliberate dispatcher
-- update before the broken tree ships.
local KNOWN_ACTION_KINDS = {
	openShop = true,
	endDialogue = true,
	startQuest = true,
	turnInQuest = true,
	requestBiomeTravel = true,
}

return function()

	TestKit.describe("Dialogues schema integrity", function()
		TestKit.test("every NPC tree has a rootNodeId that resolves", function()
			for npcId, tree in pairs(Dialogues) do
				TestKit.eq(type(tree.rootNodeId), "string",
					string.format("NPC %s missing rootNodeId", npcId))
				TestKit.eq(type(tree.nodes), "table",
					string.format("NPC %s missing nodes table", npcId))
				TestKit.truthy(tree.nodes[tree.rootNodeId] ~= nil,
					string.format("NPC %s rootNodeId %q points to a nonexistent node", npcId, tree.rootNodeId))
			end
		end)

		TestKit.test("every node has at least one response (no dead ends)", function()
			for npcId, tree in pairs(Dialogues) do
				for nodeId, node in pairs(tree.nodes) do
					TestKit.eq(type(node.responses), "table",
						string.format("%s.%s has no responses table", npcId, nodeId))
					TestKit.truthy(#node.responses > 0,
						string.format("%s.%s has zero responses (dead end)", npcId, nodeId))
				end
			end
		end)

		TestKit.test("every response has exactly one of next or action", function()
			for npcId, tree in pairs(Dialogues) do
				for nodeId, node in pairs(tree.nodes) do
					for _, r in ipairs(node.responses) do
						local hasNext = r.next ~= nil
						local hasAction = r.action ~= nil
						TestKit.truthy(hasNext or hasAction,
							string.format("%s.%s response %q has neither next nor action", npcId, nodeId, tostring(r.id)))
						TestKit.truthy(not (hasNext and hasAction),
							string.format("%s.%s response %q has both next and action", npcId, nodeId, tostring(r.id)))
						TestKit.eq(type(r.id), "string",
							string.format("%s.%s response missing id field", npcId, nodeId))
						TestKit.eq(type(r.text), "string",
							string.format("%s.%s response %q missing text field", npcId, nodeId, tostring(r.id)))
					end
				end
			end
		end)

		TestKit.test("every response.next points to a real node", function()
			for npcId, tree in pairs(Dialogues) do
				for nodeId, node in pairs(tree.nodes) do
					for _, r in ipairs(node.responses) do
						if r.next then
							TestKit.truthy(tree.nodes[r.next] ~= nil,
								string.format("%s.%s response %q points to missing node %q", npcId, nodeId, tostring(r.id), tostring(r.next)))
						end
					end
				end
			end
		end)

		TestKit.test("every response.action.kind is in the known dispatcher set", function()
			for npcId, tree in pairs(Dialogues) do
				for nodeId, node in pairs(tree.nodes) do
					for _, r in ipairs(node.responses) do
						if r.action then
							local kind = r.action.kind
							TestKit.truthy(KNOWN_ACTION_KINDS[kind] == true,
								string.format("%s.%s response %q action.kind %q is not in dispatcher", npcId, nodeId, tostring(r.id), tostring(kind)))
						end
					end
				end
			end
		end)

		TestKit.test("openShop actions reference real merchants", function()
			local Constants = require(ReplicatedStorage.Shared.Constants)
			for npcId, tree in pairs(Dialogues) do
				for nodeId, node in pairs(tree.nodes) do
					for _, r in ipairs(node.responses) do
						if r.action and r.action.kind == "openShop" then
							-- Either action.npcId or fall through to the dialogue's npcId.
							local target = r.action.npcId or npcId
							TestKit.truthy(Constants.MERCHANTS[target] ~= nil,
								string.format("%s.%s openShop targets unknown merchant %q", npcId, nodeId, tostring(target)))
						end
					end
				end
			end
		end)

		TestKit.test("startQuest / turnInQuest actions reference real quests", function()
			local Quests = require(ReplicatedStorage.Shared.Quests)
			for npcId, tree in pairs(Dialogues) do
				for nodeId, node in pairs(tree.nodes) do
					for _, r in ipairs(node.responses) do
						if r.action and (r.action.kind == "startQuest" or r.action.kind == "turnInQuest") then
							TestKit.truthy(Quests.byId[r.action.questId] ~= nil,
								string.format("%s.%s %s targets unknown quest %q", npcId, nodeId, r.action.kind, tostring(r.action.questId)))
						end
					end
				end
			end
		end)

		TestKit.test("requestBiomeTravel actions reference real biomes", function()
			local Constants = require(ReplicatedStorage.Shared.Constants)
			for npcId, tree in pairs(Dialogues) do
				for nodeId, node in pairs(tree.nodes) do
					for _, r in ipairs(node.responses) do
						if r.action and r.action.kind == "requestBiomeTravel" then
							TestKit.truthy(Constants.BIOMES[r.action.biomeId] ~= nil,
								string.format("%s.%s requestBiomeTravel targets unknown biome %q", npcId, nodeId, tostring(r.action.biomeId)))
						end
					end
				end
			end
		end)
	end)

	TestKit.describe("Dialogue.findResponse / canExecuteAction", function()
		TestKit.test("findResponse resolves a real (npcId, nodeId, responseId)", function()
			-- ForestWitch.greeting.sell is the canonical openShop response.
			local r = Dialogue.findResponse("ForestWitch", "greeting", "sell")
			TestKit.truthy(r ~= nil)
			TestKit.eq(r.id, "sell")
		end)
		TestKit.test("findResponse returns nil for fabricated tuples", function()
			TestKit.eq(Dialogue.findResponse("NotAnNPC", "x", "y"), nil)
			TestKit.eq(Dialogue.findResponse("ForestWitch", "no_node", "x"), nil)
			TestKit.eq(Dialogue.findResponse("ForestWitch", "greeting", "no_response"), nil)
		end)
		TestKit.test("canExecuteAction is true for action-bearing responses", function()
			TestKit.eq(Dialogue.canExecuteAction("ForestWitch", "greeting", "sell"), true)
			TestKit.eq(Dialogue.canExecuteAction("ForestWitch", "greeting", "leave"), true)
		end)
		TestKit.test("canExecuteAction is false for navigation-only responses", function()
			-- "lore" response on greeting carries `next`, no action — server
			-- shouldn't try to run a side effect on it.
			TestKit.eq(Dialogue.canExecuteAction("ForestWitch", "greeting", "lore"), false)
		end)
		TestKit.test("canExecuteAction is false for fabricated tuples", function()
			TestKit.eq(Dialogue.canExecuteAction("NotAnNPC", "x", "y"), false)
		end)
	end)

end
