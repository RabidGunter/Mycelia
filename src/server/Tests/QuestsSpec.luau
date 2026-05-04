-- Tests for Quests.luau pure helpers + the 5-quest tutorial integrity.
--
-- Server-side dispatcher (Quest.startQuest / turnInQuest / onEvent) is
-- Roblox-bound and not unit-tested here — covered by Studio integration.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(script.Parent.TestKit)
local Quests = require(ReplicatedStorage.Shared.Quests)

local function freshData()
	-- Minimal save-shaped data for helper tests. Mirrors the v3 schema's
	-- relevant fields without pulling in PlayerData module.
	return {
		coins = 0,
		inventory = {},
		stats = { questsCompleted = {} },
		activeQuests = {},
	}
end

return function()

	TestKit.describe("Quests catalog integrity", function()
		TestKit.test("byId and LIST agree on count", function()
			local count = 0
			for _ in pairs(Quests.byId) do count += 1 end
			TestKit.eq(count, #Quests.LIST)
		end)
		TestKit.test("every quest has required fields", function()
			for id, quest in pairs(Quests.byId) do
				TestKit.eq(quest.id, id, string.format("%s id mismatch", id))
				TestKit.eq(type(quest.title), "string")
				TestKit.eq(type(quest.description), "string")
				TestKit.eq(type(quest.givenBy), "string")
				TestKit.eq(type(quest.objectives), "table")
				TestKit.truthy(#quest.objectives > 0, string.format("%s has zero objectives", id))
				TestKit.eq(type(quest.rewards), "table")
				TestKit.eq(type(quest.prerequisites), "table")
			end
		end)
		TestKit.test("every objective.kind is in OBJECTIVE_KINDS", function()
			for id, quest in pairs(Quests.byId) do
				for _, obj in ipairs(quest.objectives) do
					TestKit.truthy(Quests.OBJECTIVE_KINDS[obj.kind] == true,
						string.format("%s objective.kind %q not registered", id, tostring(obj.kind)))
				end
			end
		end)
		TestKit.test("every prerequisite references a real quest", function()
			for id, quest in pairs(Quests.byId) do
				for _, prereqId in ipairs(quest.prerequisites) do
					TestKit.truthy(Quests.byId[prereqId] ~= nil,
						string.format("%s has prereq %q which doesn't exist", id, prereqId))
				end
			end
		end)
		TestKit.test("tutorial quests chain in order (1 → 2 → 3 → 4 → 5)", function()
			TestKit.eq(#Quests.byId.first_steps.prerequisites, 0)
			TestKit.eq(Quests.byId.a_place_to_grow.prerequisites[1], "first_steps")
			TestKit.eq(Quests.byId.the_witch_pays.prerequisites[1], "a_place_to_grow")
			TestKit.eq(Quests.byId.the_cauldron_calls.prerequisites[1], "the_witch_pays")
			TestKit.eq(Quests.byId.a_recipe_discovered.prerequisites[1], "the_cauldron_calls")
		end)
	end)

	TestKit.describe("Quests.canAccept", function()
		TestKit.test("accepts first quest from a fresh player", function()
			TestKit.eq(Quests.canAccept(freshData(), "first_steps"), true)
		end)
		TestKit.test("rejects quest with unmet prerequisites", function()
			TestKit.eq(Quests.canAccept(freshData(), "a_place_to_grow"), false)
		end)
		TestKit.test("accepts quest 2 once quest 1 is completed", function()
			local data = freshData()
			data.stats.questsCompleted.first_steps = true
			TestKit.eq(Quests.canAccept(data, "a_place_to_grow"), true)
		end)
		TestKit.test("rejects quest already active", function()
			local data = freshData()
			data.activeQuests.first_steps = { acceptedAt = 1, progress = {} }
			TestKit.eq(Quests.canAccept(data, "first_steps"), false)
		end)
		TestKit.test("rejects already-completed non-repeatable quest", function()
			local data = freshData()
			data.stats.questsCompleted.first_steps = true
			TestKit.eq(Quests.canAccept(data, "first_steps"), false)
		end)
		TestKit.test("rejects unknown quest id", function()
			TestKit.eq(Quests.canAccept(freshData(), "imaginary_quest"), false)
		end)
	end)

	TestKit.describe("Quests.objectiveMatches", function()
		TestKit.test("any-target matches any payload", function()
			local obj = { kind = "harvest_wild", target = "any", count = 1 }
			TestKit.eq(Quests.objectiveMatches(obj, "harvest_wild", { speciesId = "BrownCap" }), true)
			TestKit.eq(Quests.objectiveMatches(obj, "harvest_wild", { speciesId = "FairyCup" }), true)
		end)
		TestKit.test("specific target matches only the right payload", function()
			local obj = { kind = "harvest_wild", target = "BrownCap", count = 1 }
			TestKit.eq(Quests.objectiveMatches(obj, "harvest_wild", { speciesId = "BrownCap" }), true)
			TestKit.eq(Quests.objectiveMatches(obj, "harvest_wild", { speciesId = "FairyCup" }), false)
		end)
		TestKit.test("kind mismatch never matches", function()
			local obj = { kind = "harvest_wild", target = "any", count = 1 }
			TestKit.eq(Quests.objectiveMatches(obj, "plant_species", { speciesId = "BrownCap" }), false)
		end)
		TestKit.test("sell_to_merchant matches by npcId", function()
			local obj = { kind = "sell_to_merchant", target = "ForestWitch", count = 1 }
			TestKit.eq(Quests.objectiveMatches(obj, "sell_to_merchant", { npcId = "ForestWitch" }), true)
			TestKit.eq(Quests.objectiveMatches(obj, "sell_to_merchant", { npcId = "OtherNPC" }), false)
		end)
	end)

	TestKit.describe("Quests.applyEvent + objectivesComplete + canTurnIn", function()
		TestKit.test("harvest_wild events progress first_steps", function()
			local data = freshData()
			data.activeQuests.first_steps = { acceptedAt = 1, progress = {} }
			local touched = Quests.applyEvent(data, "harvest_wild", { speciesId = "BrownCap", count = 1 })
			TestKit.eq(touched[1], "first_steps")
			TestKit.eq(data.activeQuests.first_steps.progress[1], 1)
		end)
		TestKit.test("clamps progress at the count threshold", function()
			local data = freshData()
			data.activeQuests.first_steps = { acceptedAt = 1, progress = { [1] = 2 } }
			Quests.applyEvent(data, "harvest_wild", { speciesId = "BrownCap", count = 5 })
			TestKit.eq(data.activeQuests.first_steps.progress[1], 3)  -- capped at obj.count = 3
		end)
		TestKit.test("doesn't progress completed quests further", function()
			local data = freshData()
			data.activeQuests.first_steps = { acceptedAt = 1, progress = { [1] = 3 } }
			local touched = Quests.applyEvent(data, "harvest_wild", { speciesId = "BrownCap", count = 1 })
			TestKit.eq(#touched, 0)  -- nothing changed
		end)
		TestKit.test("objectivesComplete reflects threshold", function()
			local data = freshData()
			data.activeQuests.first_steps = { acceptedAt = 1, progress = { [1] = 2 } }
			TestKit.eq(Quests.objectivesComplete(data, "first_steps"), false)
			data.activeQuests.first_steps.progress[1] = 3
			TestKit.eq(Quests.objectivesComplete(data, "first_steps"), true)
		end)
		TestKit.test("canTurnIn requires active + complete", function()
			local data = freshData()
			TestKit.eq(Quests.canTurnIn(data, "first_steps"), false)
			data.activeQuests.first_steps = { acceptedAt = 1, progress = { [1] = 3 } }
			TestKit.eq(Quests.canTurnIn(data, "first_steps"), true)
		end)
	end)

end
