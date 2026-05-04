-- NPC dialogue trees. Pure data — every node has a `text` line, a list of
-- response options, and an optional `condition` predicate (skipped if false,
-- not yet used in Phase 2). Responses either navigate to another node via
-- `next`, or trigger a server-side side effect via `action`.
--
-- Spec: docs/specs/dialogue-system.md.
-- Validated by Tests/DialoguesSpec.luau (every nextNode resolves, every
-- action.kind is in the known set, every node has at least one response).
--
-- Adding a new NPC: append an entry below + add a `dialogueId` attribute
-- to the NPC anchor Part in MapSetup (or hand-built worldspace).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)
local Quests = require(ReplicatedStorage.Shared.Quests)

local Dialogues = {}

-- Sums total renown across every NPC reputation entry. Mirrors the same
-- pure helper in Travel.luau (which lives server-side and isn't reachable
-- from client-side dialogue rendering). Future: consolidate both into a
-- shared Reputation module when that system materializes.
local function totalRenown(data): number
	if type(data) ~= "table" or type(data.reputation) ~= "table" then return 0 end
	local total = 0
	for _, entry in pairs(data.reputation) do
		if type(entry) == "table" then total += (entry.score or 0) end
	end
	return total
end

-- Closure: response shows when player meets renown + coin gates for the
-- target biome. Mirrors Travel.canTravel server-side.
local function biomeUnlocked(biomeId)
	return function(data)
		local biome = Constants.BIOMES[biomeId]
		if not biome then return false end
		if totalRenown(data) < (biome.unlockRenown or 0) then return false end
		if (data and data.coins or 0) < (biome.travelCostCoins or 0) then return false end
		return true
	end
end

-- Helper closures for response.condition. Every condition takes the player's
-- replicated data (server: PlayerData.get(player); client: cached
-- PlayerDataUpdated payload) and returns a boolean. A response with a
-- condition that returns false is hidden from the player's UI.
local function offerable(questId)
	return function(data) return Quests.canAccept(data, questId) end
end
local function readyToTurnIn(questId)
	return function(data) return Quests.canTurnIn(data, questId) end
end
local function activeIncomplete(questId)
	return function(data)
		return Quests.isActive(data, questId) and not Quests.objectivesComplete(data, questId)
	end
end

-- ---------- Forest Witch -------------------------------------------------
-- The Phase 2 proof-of-concept. Replaces the direct "press E to sell"
-- prompt with a tiny tree that adds a sliver of character without slowing
-- the gathering loop. The "Sell mushrooms" response routes straight to
-- the existing Shop UI via the `openShop` action.

Dialogues.ForestWitch = {
	rootNodeId  = "greeting",
	speakerName = "Forest Witch",
	portrait    = "rbxassetid://0",  -- placeholder; real asset in polish pass
	nodes = {
		greeting = {
			text = "Welcome, gatherer. The forest's been busy lately. What brings you to my stall?",
			responses = {
				{ id = "sell",  text = "I'd like to sell mushrooms.", action = { kind = "openShop", npcId = "ForestWitch" } },
				{ id = "lore",  text = "Tell me about the forest.",   next = "lore_intro" },
				{ id = "leave", text = "Just passing through.",       action = { kind = "endDialogue" } },
			},
		},

		lore_intro = {
			text = "The forest is older than memory. Many secrets sleep beneath the moss — but some prefer the moonlight.",
			responses = {
				{ id = "moon", text = "What kind of secrets?",         next = "lore_moon" },
				{ id = "back", text = "Maybe another time.",           next = "greeting" },
				{ id = "leave", text = "I should go.",                 action = { kind = "endDialogue" } },
			},
		},

		lore_moon = {
			text = "Some mushrooms only fruit when the moon turns full. Others wait centuries for the right rain. Patience is the only spell that works on the deep wood.",
			responses = {
				{ id = "back",  text = "I'll remember that.",          next = "greeting" },
				{ id = "leave", text = "Goodbye, witch.",              action = { kind = "endDialogue" } },
			},
		},
	},
}

-- ---------- Gardener Coach -----------------------------------------------
-- The Phase 2 tutorial guide. Owns all 5 sequential tutorial quests. Every
-- response is gated by a `condition` predicate keyed off the player's quest
-- state — so the same root node serves "first visit", "mid-tutorial",
-- "ready to turn in", and "graduated" without needing multiple roots.
--
-- Players who finish all 5 see only the lore + goodbye responses. Future
-- side quests can append entries to this tree without disturbing the
-- tutorial chain.

Dialogues.GardenerCoach = {
	rootNodeId  = "greeting",
	speakerName = "Gardener Coach",
	portrait    = "rbxassetid://0",
	nodes = {
		greeting = {
			text = "First time in the glade? The mushrooms here practically wave at you. Stay a while — the land takes notice of those who do.",
			responses = {
				-- Quest 1 — start
				{ id = "start_first_steps", text = "Will you train me?",
				  condition = offerable("first_steps"),
				  action = { kind = "startQuest", questId = "first_steps" } },
				-- Quest 1 — turn in
				{ id = "turnin_first_steps", text = "I have the three mushrooms.",
				  condition = readyToTurnIn("first_steps"),
				  action = { kind = "turnInQuest", questId = "first_steps" } },
				-- Quest 2
				{ id = "start_a_place_to_grow", text = "Show me how to plant.",
				  condition = offerable("a_place_to_grow"),
				  action = { kind = "startQuest", questId = "a_place_to_grow" } },
				{ id = "turnin_a_place_to_grow", text = "My first patch is in the ground.",
				  condition = readyToTurnIn("a_place_to_grow"),
				  action = { kind = "turnInQuest", questId = "a_place_to_grow" } },
				-- Quest 3
				{ id = "start_witch_pays", text = "Where does the coin come from?",
				  condition = offerable("the_witch_pays"),
				  action = { kind = "startQuest", questId = "the_witch_pays" } },
				{ id = "turnin_witch_pays", text = "The witch bought my mushrooms.",
				  condition = readyToTurnIn("the_witch_pays"),
				  action = { kind = "turnInQuest", questId = "the_witch_pays" } },
				-- Quest 4
				{ id = "start_cauldron_calls", text = "What's the cauldron for?",
				  condition = offerable("the_cauldron_calls"),
				  action = { kind = "startQuest", questId = "the_cauldron_calls" } },
				{ id = "turnin_cauldron_calls", text = "I stirred the cauldron.",
				  condition = readyToTurnIn("the_cauldron_calls"),
				  action = { kind = "turnInQuest", questId = "the_cauldron_calls" } },
				-- Quest 5
				{ id = "start_recipe_discovered", text = "Teach me how brewing really works.",
				  condition = offerable("a_recipe_discovered"),
				  action = { kind = "startQuest", questId = "a_recipe_discovered" } },
				{ id = "turnin_recipe_discovered", text = "I brewed a real recipe.",
				  condition = readyToTurnIn("a_recipe_discovered"),
				  action = { kind = "turnInQuest", questId = "a_recipe_discovered" } },
				-- Mid-quest reassurance
				{ id = "still_working", text = "Still working on it.",
				  condition = function(data)
					  return activeIncomplete("first_steps")(data)
						  or activeIncomplete("a_place_to_grow")(data)
						  or activeIncomplete("the_witch_pays")(data)
						  or activeIncomplete("the_cauldron_calls")(data)
						  or activeIncomplete("a_recipe_discovered")(data)
				  end,
				  next = "still_working" },
				-- Lore (always available)
				{ id = "lore", text = "Tell me about the glade.", next = "lore_intro" },
				-- Always-available goodbye
				{ id = "leave", text = "I'll be on my way.", action = { kind = "endDialogue" } },
			},
		},

		still_working = {
			text = "Take your time. The forest doesn't reward hurry. Come back when it's done.",
			responses = {
				{ id = "back",  text = "I will.", next = "greeting" },
				{ id = "leave", text = "Goodbye.", action = { kind = "endDialogue" } },
			},
		},

		lore_intro = {
			text = "Generations of gatherers walked this glade before you. Each learned the same five things — how to harvest, plant, sell, brew, and discover. After that, the path forks for everyone.",
			responses = {
				{ id = "back",  text = "I see.",        next = "greeting" },
				{ id = "leave", text = "Until later.",  action = { kind = "endDialogue" } },
			},
		},
	},
}

-- ---------- Travel Coordinator ------------------------------------------
-- Anchored at the spawn pad. Wraps the existing Travel.luau backend in a
-- player-facing dialogue. Misty Hollow option only appears when the player
-- meets the renown gate (currently 100). Future biomes append their own
-- gated responses here.

Dialogues.TravelCoordinator = {
	rootNodeId = "greeting",
	speakerName = "Travel Coordinator",
	portrait = "rbxassetid://0",
	nodes = {
		greeting = {
			text = "I know the paths between glades. The forest doesn't always show the way — but I do, if you've earned the trust to walk them.",
			responses = {
				{ id = "to_misty_hollow", text = "Take me to Misty Hollow.",
				  condition = biomeUnlocked("MistyHollow"),
				  action = { kind = "requestBiomeTravel", biomeId = "MistyHollow" } },
				{ id = "locked_misty", text = "What's beyond the glade?",
				  condition = function(data) return not biomeUnlocked("MistyHollow")(data) end,
				  next = "locked_lore" },
				{ id = "where_am_i", text = "Where am I now?", next = "current_biome" },
				{ id = "leave", text = "Just passing.", action = { kind = "endDialogue" } },
			},
		},
		locked_lore = {
			text = "Misty Hollow lies east of here, where the rain never quite stops. The forest only opens that path to gatherers it knows. Build a name for yourself — the trail will appear.",
			responses = {
				{ id = "back",  text = "I'll keep at it.", next = "greeting" },
				{ id = "leave", text = "Goodbye.", action = { kind = "endDialogue" } },
			},
		},
		current_biome = {
			text = "Starter Glade — the first ring. Almost everyone begins here. Some never leave.",
			responses = {
				{ id = "back",  text = "Tell me more about other places.", next = "greeting" },
				{ id = "leave", text = "Goodbye.", action = { kind = "endDialogue" } },
			},
		},
	},
}

-- ---------- Old Hermit ---------------------------------------------------
-- Lore-only flavor NPC. Tucked away in the woods. No quests, no shops —
-- adds atmosphere and hints at the deeper lore (lunar cycles, mythic
-- spawns, biomes the player hasn't reached yet).

Dialogues.OldHermit = {
	rootNodeId = "greeting",
	speakerName = "Old Hermit",
	portrait = "rbxassetid://0",
	nodes = {
		greeting = {
			text = "You walk soft. Most don't. The ones who do — they're the ones the forest tells things to.",
			responses = {
				{ id = "moon",   text = "The forest tells things?",     next = "moon_lore" },
				{ id = "deep",   text = "What's deeper than the glade?", next = "deep_lore" },
				{ id = "leave",  text = "I'll let you be.",              action = { kind = "endDialogue" } },
			},
		},
		moon_lore = {
			text = "On a full moon, certain mushrooms come up that no one's ever seen by daylight. Some say they're not really there at all — that they're memories of mushrooms, fruiting in the wrong direction. I say: pick what you can. Sleep when you can't.",
			responses = {
				{ id = "more",  text = "Tell me about the deeper places.", next = "deep_lore" },
				{ id = "back",  text = "I'll think on that.",               next = "greeting" },
				{ id = "leave", text = "Goodbye.",                          action = { kind = "endDialogue" } },
			},
		},
		deep_lore = {
			text = "Beyond Misty Hollow are places older than counting. Frostroot in the high passes. Sunken Grove under the mire. The Glimmerwood, which only opens when the moon agrees. The Lost Cathedral — they say once a year a path appears. Don't ask me where; I haven't seen it twice.",
			responses = {
				{ id = "back",  text = "And the moon?",                  next = "moon_lore" },
				{ id = "leave", text = "I should go.",                   action = { kind = "endDialogue" } },
			},
		},
	},
}

-- ---------- Wandering Alchemist -----------------------------------------
-- Lore + brewing-tip flavor NPC. Hangs near the cauldron area. Drops
-- non-spoiler hints about the brewing system without revealing recipes.

Dialogues.WanderingAlchemist = {
	rootNodeId = "greeting",
	speakerName = "Wandering Alchemist",
	portrait = "rbxassetid://0",
	nodes = {
		greeting = {
			text = "You smell like cap-spores. Beautiful. Are you a brewer? You should be a brewer. Everyone should be a brewer.",
			responses = {
				{ id = "tips",  text = "Any tips for a beginner?",       next = "brewing_tips" },
				{ id = "fizzle", text = "What does it mean when a brew fizzles?", next = "fizzle_lore" },
				{ id = "leave",  text = "Maybe later.",                  action = { kind = "endDialogue" } },
			},
		},
		brewing_tips = {
			text = "Four methods. Steep is gentle, boil is fast, ferment takes patience, dry-grind takes nerve. The same mushrooms make different things by different methods. That's the whole secret. Well — half. The other half is which mushrooms.",
			responses = {
				{ id = "fizzle", text = "And when it doesn't work?",     next = "fizzle_lore" },
				{ id = "back",   text = "Thank you.",                    next = "greeting" },
				{ id = "leave",  text = "Goodbye.",                      action = { kind = "endDialogue" } },
			},
		},
		fizzle_lore = {
			text = "A fizzle is the cauldron telling you the combination doesn't sing. Don't be discouraged. Every brewer who knows anything has burned through a hundred fizzles. The cost is the lesson — and the lessons compound.",
			responses = {
				{ id = "back",  text = "I'll keep trying.",             next = "greeting" },
				{ id = "leave", text = "Goodbye.",                      action = { kind = "endDialogue" } },
			},
		},
	},
}

return Dialogues
