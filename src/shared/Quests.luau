-- Quest catalog + pure helpers.
--
-- Every quest in the game is defined here. Server-side `Quest.luau` reads
-- this table to validate accepts/turn-ins; client-side QuestController
-- reads it to render the Journal + HUD widget; Dialogues.GardenerCoach
-- references quest ids in startQuest / turnInQuest action responses.
--
-- Spec: docs/specs/quest-system.md.
-- Validated by Tests/QuestsSpec.luau (schema integrity, prereq chains,
-- helper math).

local Quests = {}

-- Supported objective kinds — must be in sync with the event firing sites
-- in gameplay modules (Harvesting, Planting, Brewing, Shop, PotionEffects).
-- Adding a new kind: extend this set + add the firing site.
Quests.OBJECTIVE_KINDS = {
	harvest_wild     = true,
	harvest_plot     = true,
	plant_species    = true,
	brew_attempt     = true,
	brew_success     = true,
	sell_to_merchant = true,
	consume_potion   = true,
}

-- ---------- The 5-quest tutorial sequence ----------------------------------
-- Sequential prerequisites (1 → 2 → 3 → 4 → 5). Each given by the Gardener
-- Coach NPC. Modest rewards — by the end the player has enough to plant a
-- couple patches and brew deliberately. See spec for the design rationale.

Quests.byId = {
	first_steps = {
		id = "first_steps",
		title = "First Steps",
		description = "Brand-new gatherers spot wild mushrooms by their gentle glow. Pick three, and the forest will know you've arrived.",
		givenBy = "GardenerCoach",
		objectives = {
			{ kind = "harvest_wild", target = "any", count = 3, label = "Harvest wild mushrooms" },
		},
		rewards = { coins = 25, items = {} },
		prerequisites = {},
		repeatable = false,
	},

	a_place_to_grow = {
		id = "a_place_to_grow",
		title = "A Place to Grow",
		description = "Wild mushrooms are gifts. Cultivated ones are friendships. Plant your first patch and the land will start to remember you.",
		givenBy = "GardenerCoach",
		objectives = {
			{ kind = "plant_species", target = "any", count = 1, label = "Plant a Spore Patch" },
		},
		rewards = { coins = 50, items = {} },
		prerequisites = { "first_steps" },
		repeatable = false,
	},

	the_witch_pays = {
		id = "the_witch_pays",
		title = "The Witch Pays",
		description = "The Forest Witch buys what we grow. Take her five — she'll teach you how the coin moves through this place.",
		givenBy = "GardenerCoach",
		objectives = {
			-- Counts mushroom items sold to the witch (not gold). Five mushrooms
			-- of any species in any combination of trips.
			{ kind = "sell_to_merchant", target = "ForestWitch", count = 5, label = "Sell mushrooms to the Forest Witch" },
		},
		-- Reward includes Compost so the player has *something* in their
		-- substrate inventory. Inert in Phase 2 (cultivation depth lands
		-- in Phase 3) but the visual confirmation matters.
		rewards = { coins = 0, items = { Compost = 1 } },
		prerequisites = { "a_place_to_grow" },
		repeatable = false,
	},

	the_cauldron_calls = {
		id = "the_cauldron_calls",
		title = "The Cauldron Calls",
		description = "There's a cauldron in the cave — the witch's, but she shares. Drop something in and learn what stirring feels like. Right or wrong, both teach.",
		givenBy = "GardenerCoach",
		objectives = {
			-- "brew_attempt" fires on every cauldron use, success or fizzle.
			-- The lesson is the action, not the result.
			{ kind = "brew_attempt", target = "any", count = 1, label = "Use the cauldron" },
		},
		rewards = { coins = 0, items = { BrownCapSpore = 1 } },
		prerequisites = { "the_witch_pays" },
		repeatable = false,
	},

	a_recipe_discovered = {
		id = "a_recipe_discovered",
		title = "A Recipe Discovered",
		description = "Brew a real recipe. Combine ingredients the right way and the cauldron rewards the patient. The first time is the only first time.",
		givenBy = "GardenerCoach",
		objectives = {
			-- "brew_success" fires only when a valid recipe resolves to a real
			-- potion (not a fizzle). target=any so any recipe completes the
			-- objective.
			{ kind = "brew_success", target = "any", count = 1, label = "Discover a recipe" },
		},
		-- Graduation gift. Pure coins on purpose — handing out a Speed Potion
		-- here would short-circuit the discovery hook elsewhere.
		rewards = { coins = 100, items = {} },
		prerequisites = { "the_cauldron_calls" },
		repeatable = false,
	},
}

-- Sorted list view, used by UIs that want a stable iteration order. Tutorial
-- quests appear in the order their prerequisites chain.
Quests.LIST = {
	Quests.byId.first_steps,
	Quests.byId.a_place_to_grow,
	Quests.byId.the_witch_pays,
	Quests.byId.the_cauldron_calls,
	Quests.byId.a_recipe_discovered,
}

-- ---------- Pure helpers ---------------------------------------------------

-- Defensive accessors: handle nil/malformed save data without crashing.
function Quests.isActive(data, questId: string): boolean
	if type(data) ~= "table" or type(questId) ~= "string" then return false end
	local active = data.activeQuests
	return type(active) == "table" and active[questId] ~= nil
end

function Quests.isCompleted(data, questId: string): boolean
	if type(data) ~= "table" or type(questId) ~= "string" then return false end
	local stats = data.stats
	if type(stats) ~= "table" then return false end
	local done = stats.questsCompleted
	return type(done) == "table" and done[questId] == true
end

-- A response can offer to start a quest when:
--   1) the quest exists,
--   2) it isn't already active,
--   3) it isn't already completed (unless repeatable),
--   4) every prerequisite is in stats.questsCompleted.
function Quests.canAccept(data, questId: string): boolean
	local quest = Quests.byId[questId]
	if not quest then return false end
	if Quests.isActive(data, questId) then return false end
	if Quests.isCompleted(data, questId) and not quest.repeatable then return false end
	for _, prereqId in ipairs(quest.prerequisites or {}) do
		if not Quests.isCompleted(data, prereqId) then return false end
	end
	return true
end

-- True when every objective has hit its count. Reads progress from
-- data.activeQuests[questId].progress; missing entries count as 0.
function Quests.objectivesComplete(data, questId: string): boolean
	local quest = Quests.byId[questId]
	if not quest then return false end
	if not Quests.isActive(data, questId) then return false end
	local progress = (data.activeQuests[questId] or {}).progress or {}
	for i, obj in ipairs(quest.objectives) do
		if (progress[i] or 0) < obj.count then return false end
	end
	return true
end

function Quests.canTurnIn(data, questId: string): boolean
	if not Quests.isActive(data, questId) then return false end
	return Quests.objectivesComplete(data, questId)
end

-- Pure: does this objective match an event of (kind, payload)?
-- target = "any" matches anything; otherwise must equal payload's identifying
-- field (speciesId for harvest/plant, npcId for sell, potionId for brew/consume).
function Quests.objectiveMatches(objective, eventKind: string, payload): boolean
	if type(objective) ~= "table" or objective.kind ~= eventKind then return false end
	if objective.target == "any" then return true end
	if type(payload) ~= "table" then return objective.target == nil end
	-- Per-event identifier:
	if eventKind == "harvest_wild" or eventKind == "harvest_plot" or eventKind == "plant_species" then
		return objective.target == payload.speciesId
	elseif eventKind == "sell_to_merchant" then
		return objective.target == payload.npcId
	elseif eventKind == "brew_success" or eventKind == "consume_potion" then
		return objective.target == payload.potionId
	elseif eventKind == "brew_attempt" then
		-- brew_attempt has no identifier; target should be "any".
		return false
	end
	return false
end

-- Pure: increment matching objectives across every active quest.
-- Mutates `data` in place. Caller is responsible for wrapping in PlayerData.update.
-- Returns a list of questIds whose progress changed (so the caller can fire
-- replication / completion checks).
function Quests.applyEvent(data, eventKind: string, payload): { string }
	local touched = {}
	if type(data) ~= "table" or type(data.activeQuests) ~= "table" then
		return touched
	end
	for questId, state in pairs(data.activeQuests) do
		local quest = Quests.byId[questId]
		if quest then
			state.progress = state.progress or {}
			local changed = false
			for i, obj in ipairs(quest.objectives) do
				if Quests.objectiveMatches(obj, eventKind, payload) then
					local current = state.progress[i] or 0
					local delta = (type(payload) == "table" and type(payload.count) == "number") and payload.count or 1
					if current < obj.count then
						state.progress[i] = math.min(current + delta, obj.count)
						changed = true
					end
				end
			end
			if changed then table.insert(touched, questId) end
		end
	end
	return touched
end

return Quests
