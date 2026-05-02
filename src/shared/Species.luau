--!strict
-- The 15 mushroom species shipping in Pre-Alpha (Starter Glade only).
-- Adding species is the most common content task — keep this file flat
-- and well-commented so a designer can edit without reading other code.
--
-- Field reference:
--   id                 unique string, never renamed (used as save-data key)
--   displayName        what the player sees
--   tier               must match a key in Tiers.lua
--   description        flavor text shown in the Pokedex / inspect UI
--   baseSellPrice      coins; the actual sell price is this * tier.sellMultiplier
--   growthTimeSeconds  base time from plant -> ripe; affected by buffs
--   substratePref      preferred substrate(s); growth is faster on these
--   lightPref          "sunny" | "dappled" | "dark"
--   moisturePref       0-1 ideal moisture (0 = dry, 1 = soaked)
--   pHPref             ideal pH (4.0 - 8.0)
--   brewingTags        ingredient categories the cauldron uses to resolve recipes;
--                      empty for now — populated when the brewing system lands
--
-- New species should generally launch with brewingTags = {} and have tags
-- added during the brewing-system milestone, so balance is changed one
-- system at a time.

local Species = {}

Species.LIST = {

	------------------------------------------------------------------ Common
	{
		id = "BrownCap",
		displayName = "Brown Cap",
		tier = "Common",
		description = "The everyman of the forest. Not glamorous, but pays the rent.",
		baseSellPrice = 3,
		growthTimeSeconds = 60,
		substratePref = { "compost" },
		lightPref = "dappled",
		moisturePref = 0.5,
		pHPref = 6.5,
		brewingTags = {},
	},
	{
		id = "SpottedToadstool",
		displayName = "Spotted Toadstool",
		tier = "Common",
		description = "Storybook-red with white spots. Mildly hallucinogenic to garden gnomes.",
		baseSellPrice = 4,
		growthTimeSeconds = 75,
		substratePref = { "compost", "straw" },
		lightPref = "dappled",
		moisturePref = 0.55,
		pHPref = 6.0,
		brewingTags = {},
	},
	{
		id = "FairyCup",
		displayName = "Fairy Cup",
		tier = "Common",
		description = "Tiny chalice-shaped caps that catch morning dew.",
		baseSellPrice = 5,
		growthTimeSeconds = 90,
		substratePref = { "compost" },
		lightPref = "dappled",
		moisturePref = 0.7,
		pHPref = 6.5,
		brewingTags = {},
	},
	{
		id = "Mossring",
		displayName = "Mossring",
		tier = "Common",
		description = "Forms tidy circles in damp moss. The forest's punctuation.",
		baseSellPrice = 5,
		growthTimeSeconds = 90,
		substratePref = { "compost" },
		lightPref = "dappled",
		moisturePref = 0.65,
		pHPref = 6.5,
		brewingTags = {},
	},
	{
		id = "Buttoncap",
		displayName = "Buttoncap",
		tier = "Common",
		description = "Squat, sturdy, and content. The mushroom equivalent of a good chair.",
		baseSellPrice = 3,
		growthTimeSeconds = 55,
		substratePref = { "compost", "dung" },
		lightPref = "dark",
		moisturePref = 0.5,
		pHPref = 7.0,
		brewingTags = {},
	},
	{
		id = "Pinwheel",
		displayName = "Pinwheel",
		tier = "Common",
		description = "Thin, fluted gills like a child's toy. Pops up after rain.",
		baseSellPrice = 6,
		growthTimeSeconds = 100,
		substratePref = { "straw" },
		lightPref = "sunny",
		moisturePref = 0.6,
		pHPref = 6.5,
		brewingTags = {},
	},

	---------------------------------------------------------------- Uncommon
	-- Uncommons require a non-default substrate. They don't grow on plain
	-- compost — players have to learn to shop for substrate types.
	{
		id = "LatticeVeil",
		displayName = "Lattice Veil",
		tier = "Uncommon",
		description = "A shimmering net of mycelial lace drapes from the cap.",
		baseSellPrice = 12,
		growthTimeSeconds = 180,
		substratePref = { "hardwood" },
		lightPref = "dappled",
		moisturePref = 0.5,
		pHPref = 6.0,
		brewingTags = {},
	},
	{
		id = "Inkpot",
		displayName = "Inkpot",
		tier = "Uncommon",
		description = "Black gills that liquify into ink at maturity. Worth harvesting precisely.",
		baseSellPrice = 15,
		growthTimeSeconds = 200,
		substratePref = { "dung" },
		lightPref = "dark",
		moisturePref = 0.7,
		pHPref = 7.5,
		brewingTags = {},
	},
	{
		id = "CoralTongue",
		displayName = "Coral Tongue",
		tier = "Uncommon",
		description = "Branching pink-orange fingers. Looks more like reef than fungus.",
		baseSellPrice = 18,
		growthTimeSeconds = 220,
		substratePref = { "hardwood" },
		lightPref = "dappled",
		moisturePref = 0.55,
		pHPref = 6.0,
		brewingTags = {},
	},
	{
		id = "Sundrop",
		displayName = "Sundrop",
		tier = "Uncommon",
		description = "Yellow caps that follow the sun. The only mushroom you can tell time by.",
		baseSellPrice = 14,
		growthTimeSeconds = 180,
		substratePref = { "straw" },
		lightPref = "sunny",
		moisturePref = 0.4,
		pHPref = 6.5,
		brewingTags = {},
	},
	{
		id = "Hollowstem",
		displayName = "Hollowstem",
		tier = "Uncommon",
		description = "Tall and reedy with a hollow stalk that whistles in wind.",
		baseSellPrice = 16,
		growthTimeSeconds = 210,
		substratePref = { "peat" },
		lightPref = "dappled",
		moisturePref = 0.75,
		pHPref = 5.5,
		brewingTags = {},
	},

	-------------------------------------------------------------------- Rare
	-- Rares fruit only when substrate, light, and moisture are all on-target.
	-- Players will hit them by accident first, then learn to reproduce.
	{
		id = "Glowmoss",
		displayName = "Glowmoss",
		tier = "Rare",
		description = "Bioluminescent. Casts soft green light at night — a player's first 'wow'.",
		baseSellPrice = 50,
		growthTimeSeconds = 480,
		substratePref = { "peat" },
		lightPref = "dark",
		moisturePref = 0.8,
		pHPref = 5.5,
		brewingTags = {},
	},
	{
		id = "Dewfern",
		displayName = "Dewfern",
		tier = "Rare",
		description = "Fern-like fronds, perpetually beaded with water. Used in cooling potions.",
		baseSellPrice = 45,
		growthTimeSeconds = 420,
		substratePref = { "peat" },
		lightPref = "dappled",
		moisturePref = 0.9,
		pHPref = 6.0,
		brewingTags = {},
	},
	{
		id = "Whisperbloom",
		displayName = "Whisperbloom",
		tier = "Rare",
		description = "Said to faintly murmur at dusk. Brewers swear it improves recipe luck.",
		baseSellPrice = 60,
		growthTimeSeconds = 540,
		substratePref = { "magical_loam" },
		lightPref = "dappled",
		moisturePref = 0.6,
		pHPref = 6.5,
		brewingTags = {},
	},

	-------------------------------------------------------------------- Epic
	-- One epic in the Starter Glade — gives Pre-Alpha players a horizon to
	-- chase before biome 2 unlocks.
	{
		id = "CrystalCap",
		displayName = "Crystal Cap",
		tier = "Epic",
		description = "Translucent quartz-like cap. Refracts sunbeams into rainbows on the forest floor.",
		baseSellPrice = 200,
		growthTimeSeconds = 900,
		substratePref = { "magical_loam" },
		lightPref = "sunny",
		moisturePref = 0.4,
		pHPref = 6.0,
		brewingTags = {},
	},
}

-- Lookup: Species.byId["BrownCap"] -> the entry above.
Species.byId = {}
for _, entry in ipairs(Species.LIST) do
	Species.byId[entry.id] = entry
end

-- Convenience: Species.byTier.Rare -> array of all rares.
Species.byTier = {}
for _, entry in ipairs(Species.LIST) do
	local bucket = Species.byTier[entry.tier]
	if not bucket then
		bucket = {}
		Species.byTier[entry.tier] = bucket
	end
	table.insert(bucket, entry)
end

return Species
