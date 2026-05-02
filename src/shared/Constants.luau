--!strict
-- All gameplay tunables live here. Anything you'd want to tweak during a
-- balance pass should be in this file, not buried in logic.

local Constants = {}

-- Starter Glade ----------------------------------------------------------------
-- The single biome shipping in Pre-Alpha.
Constants.STARTER_GLADE = {
	id = "StarterGlade",
	displayName = "Starter Glade",
	-- How many wild mushrooms can exist in the glade at once before
	-- the spawner stops respawning. Tune for visual density.
	wildSpawnCap = 25,
	-- Seconds between wild-spawn attempts when below the cap.
	wildSpawnInterval = 8,
}

-- Cultivation ------------------------------------------------------------------
Constants.CULTIVATION = {
	-- Base growth-time multiplier. 1.0 = species default; raise during
	-- testing if growth feels too fast.
	growthTimeMultiplier = 1.0,
	-- Plot tiers (Bigger Plot is a future game pass).
	startingPlotSize = 4,        -- patches the player can plant simultaneously
	maxPlotSize = 16,             -- with the Bigger Plot pass
	-- Cost in coins to plant a Spore Patch of the named tier.
	plantCost = {
		Common = 10,
		Uncommon = 50,
		Rare = 250,
		Epic = 1500,
	},
}

-- Economy ----------------------------------------------------------------------
Constants.ECONOMY = {
	startingCoins = 25,           -- enough to plant a couple of common patches
	-- The Forest Witch's stall buys at species.baseSellPrice * tier.sellMultiplier.
	-- This global modifier is the lever for tuning inflation across the economy.
	witchPriceMultiplier = 1.0,
}

-- Movement ---------------------------------------------------------------------
Constants.MOVEMENT = {
	-- Roblox default Humanoid.WalkSpeed. Buffs (Common Speed Potion) multiply
	-- this; clearing a buff resets back to this value.
	defaultWalkSpeed = 16,
}

-- Potions ----------------------------------------------------------------------
-- Per-potion effect tunables. A potion id present here is *active*
-- (consumable with an in-game effect). A potion missing from this table is
-- inert (sits in inventory, shows "No effect yet" in the UI).
--
-- 10 effect kinds (PotionEffects knows these — see EFFECT_HANDLERS there):
--   "speed"         — WalkSpeed *= magnitude for durationSeconds.
--   "growth"        — shortens remaining grow time on the player's growing
--                     plots by magnitude (one-shot on fresh activation), and
--                     multiplies new plants' growthTimeSeconds by magnitude
--                     during durationSeconds. magnitude < 1 = faster.
--   "wildYield"     — wild harvests award 1 + magnitude for durationSeconds.
--   "harvestYield"  — planted-plot harvests award +magnitude bonus mushrooms.
--   "luck"          — additive bonus to rare-variant chance (typical 0.05–0.15).
--   "reveal"        — hidden mushrooms within `magnitude` studs become
--                     visible to this player for durationSeconds.
--   "spiritAttract" — multiplies spirit attraction roll chance by magnitude.
--   "cosmeticGlow"  — particle trail behind the character. params.color sets
--                     the trail color. No mechanical effect.
--   "weatherSummon" — overrides local biome's weather to params.weatherKind
--                     for durationSeconds. Phase 4 stub (Weather not yet built).
--   "timeShift"     — enables a HUD button to toggle day/night on the
--                     player's own plots. Phase 4 stub (Lighting.localOverride
--                     not yet built). magnitude unused.
Constants.POTIONS = {
	-- Pre-Alpha (3, already shipped active) ------------------------------
	CommonSpeedPotion = { kind = "speed",     durationSeconds = 30, magnitude = 1.30 },
	DewdropTonic      = { kind = "wildYield", durationSeconds = 60, magnitude = 1 },
	HearthBrew        = { kind = "growth",    durationSeconds = 60, magnitude = 0.70 },

	-- Pre-Alpha potions activated in Phase 1 (3) -------------------------
	InkblotElixir     = { kind = "reveal",    durationSeconds = 45, magnitude = 30 },
	SpottedTincture   = { kind = "luck",      durationSeconds = 60, magnitude = 0.05 },
	GlowmossPowder    = { kind = "reveal",    durationSeconds = 90, magnitude = 60 },

	-- Phase 1 new active potions (12) ------------------------------------
	StonecastInfusion = { kind = "harvestYield", durationSeconds = 60,  magnitude = 1 },
	WoodlandWarmth    = { kind = "growth",       durationSeconds = 90,  magnitude = 0.85 },
	LatticeBalm       = { kind = "growth",       durationSeconds = 30,  magnitude = 0.50 },
	HollowwindBrew    = { kind = "speed",        durationSeconds = 30,  magnitude = 1.50 },
	CoralCordial      = { kind = "wildYield",    durationSeconds = 45,  magnitude = 2 },
	DaybreakPowder    = { kind = "timeShift",    durationSeconds = 300, magnitude = 0,
	                      params = { allowToggle = true } },
	LuckPowder        = { kind = "luck",         durationSeconds = 60,  magnitude = 0.10 },
	EverdewPowder     = { kind = "weatherSummon",durationSeconds = 600, magnitude = 0,
	                      params = { weatherKind = "Rainy" } },
	CrystalEssence    = { kind = "cosmeticGlow", durationSeconds = 600, magnitude = 0,
	                      params = { color = Color3.fromRGB(180, 200, 255) } },
	NightlanternOil   = { kind = "reveal",       durationSeconds = 120, magnitude = 90 },
	TideweaverElixir  = { kind = "harvestYield", durationSeconds = 120, magnitude = 2 },
	SpiritcallTonic   = { kind = "spiritAttract",durationSeconds = 600, magnitude = 2.0 },
}

-- Spirits ----------------------------------------------------------------------
-- Forest Spirits are pet-style companions attracted by holding/growing
-- specific mushroom species. Active-roster spirits contribute permanent
-- (untimed) bonuses via PassiveBonuses.lua and wander idly near the
-- player's hut. Spec: docs/specs/spirits.md.
Constants.SPIRITS = {
	startingRosterSize        = 3,
	biggerRosterGamepassBonus = 3,    -- +3 with BiggerSpiritRoster gamepass; total 6
	attractionTickSeconds     = 300,  -- 5 minutes
	unclaimedDespawnSeconds   = 300,  -- 5 minutes
	claimRange                = 12,   -- studs
	wanderRadiusCommon        = 8,
	wanderRadiusRare          = 12,
	walkSpeed                 = 4,    -- studs/sec
	homePointFallback         = "spawnArea",    -- if no hut, wander near spawn

	-- Per-rarity classification (for wander radius selection + UI tier dot).
	rarity = {
		Mossling     = "Common",
		Spritefly    = "Common",
		Dewdrop      = "Common",
		Lanternfox   = "Rare",
		Crystalmoth  = "Rare",
		Deerlet      = "Rare",
		ForestMother = "Legendary",    -- Phase 4 lunar event
	},

	-- Bonuses applied permanently while in active roster. The kind strings
	-- align with PotionEffects kinds where applicable; gameplay code reads
	-- both via PassiveBonuses + PotionEffects and combines them additively.
	bonuses = {
		Mossling    = { kind = "wildYield",    magnitude = 0.05 },    -- +5% wild yield
		Spritefly   = { kind = "growthSpeed",  magnitude = 0.05 },    -- -5% growth time
		Dewdrop     = { kind = "harvestYield", magnitude = 0.05 },    -- +5% planted yield
		Lanternfox  = { kind = "wildYield",    magnitude = 0.15 },
		Crystalmoth = { kind = "rareChance",   magnitude = 0.15 },    -- +15% rare-variant
		Deerlet     = { kind = "growthSpeed",  magnitude = 0.15 },
	},

	-- Per-spirit attraction map: { [speciesId] = baseChancePerHour }.
	-- Each attraction tick (5 min = 1/12 hour) rolls chancePerHour/12 per
	-- species held/grown. Multiple species stack additively. The
	-- spiritAttract potion multiplies the final chance.
	attractionMap = {
		Mossling = {
			BrownCap         = 0.04,
			Buttoncap        = 0.03,
			Mossring         = 0.10,    -- main attractor
			Pinwheel         = 0.02,
		},
		Spritefly = {
			FairyCup         = 0.10,    -- main
			Sundrop          = 0.05,
			SpottedToadstool = 0.02,
		},
		Dewdrop = {
			FairyCup         = 0.05,
			Hollowstem       = 0.08,
			Dewfern          = 0.15,    -- main
		},
		Lanternfox = {
			Inkpot           = 0.02,
			Glowmoss         = 0.05,    -- main
		},
		Crystalmoth = {
			Whisperbloom     = 0.04,
			CrystalCap       = 0.10,    -- main
		},
		Deerlet = {
			CoralTongue      = 0.04,
			LatticeVeil      = 0.04,
			Glowmoss         = 0.02,
		},
	},

	-- Unique-mechanic tunables (Phase 1 stubs where the dependent system
	-- isn't built yet — Crystalmoth's daily shard ships; Lanternfox
	-- illumination + Deerlet favor wait for content systems).
	lanternfoxIlluminationRadius = 30,
	crystalmothShardSchedule     = "midnight",    -- once per server-day
	deerletFavorCooldownHours    = 24,
	forestMotherDuration         = 1800,    -- Phase 4
	forestMotherServerBonus      = { wildYield = 0.25, growthSpeed = 0.25 },
}

-- Non-mushroom inventory items. Mushrooms are in Species.luau; this is
-- everything else (consumables, materials, special items dropped by
-- spirits or quests). Indexed by id; lookup pattern across all categories.
Constants.ITEMS = {
	CrystalShard = {
		id            = "CrystalShard",
		displayName   = "Crystal Shard",
		description   = "A faceted shard left behind by a Crystalmoth at midnight. Brewers and traders prize them.",
		category      = "tools",          -- inventoryByCategory.tools bucket
		stackable     = true,
		maxStack      = 999,
		tradable      = true,
		droppable     = false,
		iconAssetId   = "rbxassetid://0", -- placeholder; user supplies
		baseSellPrice = 50,
	},
}

-- Biomes -----------------------------------------------------------------------
-- Per-biome configuration. Single-place world with 2000-stud-spaced zones
-- (per ADR 001). Each biome has spatial layout, wild-spawn config, lighting/
-- atmosphere overrides applied client-side, weather distribution, and
-- substrate availability. Adding biome 8 means appending a config entry —
-- no architectural rewrite. Spec: docs/specs/biome-config.md.
Constants.BIOMES = {
	StarterGlade = {
		id            = "StarterGlade",
		displayName   = "Starter Glade",
		description   = "A misty clearing where new gatherers begin.",
		unlockRenown  = 0,
		unlockOrder   = 1,
		zoneCenter    = Vector3.new(0, 0, 0),
		zoneRadius    = 500,
		spawnPoint    = Vector3.new(0, 5, 0),
		plotOrigin    = Vector3.new(0, 0, 30),
		npcPositions = {
			travelCoordinator = Vector3.new(-15, 0, 0),
			forestWitch       = Vector3.new(85, 2, -5),    -- inside cave chamber
			substrateMerchant = Vector3.new(15, 0, 0),
		},
		wildSpawnArea     = "WildSpawnArea_StarterGlade",
		wildSpawnTable    = {
			"BrownCap", "SpottedToadstool", "FairyCup",
			"Mossring", "Buttoncap", "Pinwheel",
		},
		wildSpawnCap      = 25,
		wildSpawnInterval = 8,
		atmosphere = {
			density = 0.3, offset = 0.25,
			color   = Color3.fromRGB(199, 199, 199),
			decay   = Color3.fromRGB(106, 112, 125),
			glare   = 0, haze = 0,
		},
		lightingOverride = {
			ambient        = Color3.fromRGB(100, 100, 100),
			outdoorAmbient = Color3.fromRGB(140, 140, 140),
			colorShift_Top = Color3.fromRGB(255, 245, 220),
			colorShift_Bottom = Color3.fromRGB(120, 100, 80),
			brightness     = 2,
		},
		ambientMusicAssetId  = "rbxassetid://0",    -- placeholder
		ambientLoopAssetId   = "rbxassetid://0",    -- placeholder
		availableSubstrates  = { "compost", "hardwood", "straw", "dung" },
		weatherDistribution  = { Sunny = 0.6, Cloudy = 0.3, Rainy = 0.1 },
		travelCostCoins      = 0,
	},

	MistyHollow = {
		id            = "MistyHollow",
		displayName   = "Misty Hollow",
		description   = "A rainforest hollow where water-loving species fruit in the ever-present mist.",
		unlockRenown  = 100,
		unlockOrder   = 2,
		zoneCenter    = Vector3.new(2000, 0, 0),    -- 2000 studs east of Starter Glade
		zoneRadius    = 500,
		spawnPoint    = Vector3.new(2000, 5, 0),
		plotOrigin    = Vector3.new(2000, 0, 30),
		npcPositions = {
			travelCoordinator = Vector3.new(1985, 0, 0),
		},
		wildSpawnArea     = "WildSpawnArea_MistyHollow",
		wildSpawnTable    = {
			-- Commons that appear here too:
			"BrownCap", "FairyCup", "Mossring",
			-- Misty Hollow specialties (water-loving):
			"Hollowstem", "Dewfern",
			-- Rare wild appearance (low drop weight):
			"Glowmoss",
		},
		wildSpawnCap      = 30,
		wildSpawnInterval = 6,
		atmosphere = {
			density = 0.6, offset = 0.4,
			color   = Color3.fromRGB(180, 200, 195),
			decay   = Color3.fromRGB(70, 90, 100),
			glare   = 0.1, haze = 0.5,
		},
		lightingOverride = {
			ambient        = Color3.fromRGB(80, 100, 95),
			outdoorAmbient = Color3.fromRGB(120, 140, 135),
			colorShift_Top = Color3.fromRGB(180, 220, 200),
			colorShift_Bottom = Color3.fromRGB(60, 80, 75),
			brightness     = 1.5,
		},
		ambientMusicAssetId  = "rbxassetid://0",    -- placeholder
		ambientLoopAssetId   = "rbxassetid://0",    -- placeholder
		availableSubstrates  = { "compost", "hardwood", "peat" },
		weatherDistribution  = { Rainy = 0.5, Cloudy = 0.3, Sunny = 0.1, Foggy = 0.1 },
		travelCostCoins      = 25,
	},
}

-- Save data --------------------------------------------------------------------
Constants.SAVE = {
	dataStoreName = "MyceliaPlayerData_v1",
	-- Minimum seconds between forced saves per player. Roblox throttles
	-- DataStore writes at 6/min/key; keep us well below that.
	autosaveInterval = 60,
}

-- RemoteEvent / RemoteFunction names ------------------------------------------
-- These are referenced from both client and server so they live here as
-- string constants instead of magic strings scattered through the codebase.
Constants.REMOTES = {
	HarvestMushroom = "HarvestMushroom",
	PlantPatch = "PlantPatch",
	PlantSpecies = "PlantSpecies",
	SellInventory = "SellInventory",
	SellCompleted = "SellCompleted",
	Brew = "Brew",
	BrewCompleted = "BrewCompleted",
	ConsumePotion = "ConsumePotion",
	ActiveEffectsUpdated = "ActiveEffectsUpdated",
	ClaimSpirit = "ClaimSpirit",
	SpiritClaimCompleted = "SpiritClaimCompleted",
	EquipSpirit = "EquipSpirit",
	UnequipSpirit = "UnequipSpirit",
	PassiveBonusesUpdated = "PassiveBonusesUpdated",
	RequestBiomeTravel = "RequestBiomeTravel",
	BiomeTravelCompleted = "BiomeTravelCompleted",
	BiomeUnlocked = "BiomeUnlocked",
	GetPlayerData = "GetPlayerData",
	PlayerDataUpdated = "PlayerDataUpdated",
}

return Constants
