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
}

-- Merchants --------------------------------------------------------------------
-- Every merchant NPC's config. The Shop system (src/server/Shop.luau) reads
-- these to validate Buy/Sell requests, compute prices, and fire reputation
-- gains. World code (MapSetup or hand-built NPCs) tags the NPC anchor Part
-- with attribute `merchantId = "<npcId>"` so the prompt-trigger handler can
-- resolve which merchant config to use.
--
-- See docs/specs/shop-ui.md for the full schema and field semantics.
Constants.MERCHANT_DEFAULTS = {
	talkRange = 14,                -- studs from anchor Part
	repPerCoin = 0.001,            -- 1 rep per 1000 coins transacted
	repGate = 0,
}

Constants.MERCHANTS = {
	ForestWitch = {
		displayName  = "Forest Witch",
		description  = "Buys raw mushrooms at fair flat rates.",
		talkRange    = 14,
		buyCategories = { "mushrooms_raw" },
		buyMultiplier = 1.0,        -- replaces the Pre-Alpha witchPriceMultiplier
		itemsForSale  = {},          -- the witch sells nothing in Phase 2
		reputationKey = "ForestWitch",
		repPerCoin    = 0.001,
		repGate       = 0,
	},
	SubstrateDealer = {
		displayName  = "Substrate Dealer",
		description  = "Cultivation supplies for the discerning grower.",
		talkRange    = 14,
		buyCategories = {},          -- sell-only for now (player can't sell back)
		buyMultiplier = 0,
		itemsForSale = {
			Compost     = { unitPrice = 5,   category = "substrates" },
			Straw       = { unitPrice = 8,   category = "substrates" },
			Dung        = { unitPrice = 18,  category = "substrates" },
			Hardwood    = { unitPrice = 25,  category = "substrates" },
			Peat        = { unitPrice = 35,  category = "substrates" },
			MagicalLoam = { unitPrice = 500, category = "substrates" },
		},
		reputationKey = "SubstrateDealer",
		repPerCoin    = 0.001,
		repGate       = 0,
	},
	SporeMerchant = {
		displayName  = "Spore Merchant",
		description  = "Carefully isolated spore samples for serious cultivators.",
		talkRange    = 14,
		buyCategories = {},
		buyMultiplier = 0,
		itemsForSale = {
			BrownCapSpore = { unitPrice = 10, category = "spores" },
			FairyCupSpore = { unitPrice = 15, category = "spores" },
			InkpotSpore   = { unitPrice = 60, category = "spores" },
		},
		reputationKey = "SporeMerchant",
		repPerCoin    = 0.001,
		repGate       = 0,
	},
	-- Future Phase 2 merchants:
	--   SpiritFood, Cosmetic, DecorationVendor.

	-- Stall Manager NPC. Not a buy/sell merchant — entry exists so Dialogue.luau
	-- can resolve dialogueId-vs-merchantId routing and any future repPerCoin /
	-- repGate hooks have a config home. The actual stall functionality (rental,
	-- listing, browse) goes through the Stall.luau remotes.
	StallManager = {
		displayName  = "Stall Manager",
		description  = "Runs the featured row in the Trading Post; mails out your sale proceeds.",
		talkRange    = 14,
		buyCategories = {},
		buyMultiplier = 0,
		itemsForSale  = {},
		reputationKey = "StallManager",
		repPerCoin    = 0.001,
		repGate       = 0,
	},
}

-- Player Stalls (Phase 2) ------------------------------------------------------
-- Tunables for the Player Stalls system. See docs/specs/player-stalls.md and
-- .planning/phases/02-closed-beta-social-systems-content/02-CONTEXT.md (D-06..D-21).
Constants.STALL = {
	-- D-06: listing slots per stall. Gamepass +4 hook designed-in but unwired in v1.
	slotCount               = 4,
	-- D-07: listings auto-expire after this many seconds (48h). Items return to mailbox.
	listingExpirySeconds    = 48 * 3600,
	-- D-08: featured row in the Trading Post zone.
	featuredSlotCount       = 12,
	featuredFee             = 200,                          -- coins per 24h rental
	featuredRentSeconds     = 24 * 3600,
	featuredCapPerAccount   = 1,
	-- D-09: Cottages zone with an 8x8 grid of plot anchors (64 tiles total).
	cottagesZoneOrigin      = Vector3.new(-300, 0, 0),      -- west of spawn
	plotTileSize            = 16,                           -- studs per tile side
	plotGridSize            = 8,                            -- 8x8 = 64 tiles
	plotGridSpacing         = 24,                           -- 16-stud tile + 8-stud gap
	-- D-10: price bounds.
	minPrice                = 1,
	maxPrice                = 1e9,
	-- D-11: mailbox cap (unique item ids; coins uncapped).
	mailboxItemIdCap        = 100,
	-- CD-2 + CD-6: sweeper tick + offline-seller registry TTL.
	expirySweeperIntervalSeconds = 60,
	knownSellersTtlSeconds  = 7 * 24 * 3600,
	-- D-21: per-remote rate-limit intervals (seconds). Used by Stall.start
	-- handlers via RateLimit.check.
	rateLimits = {
		CreateListing    = 3,
		BuyListing       = 1,
		CancelListing    = 3,
		RentFeaturedSlot = 60,
		ClaimMailbox     = 10,
		BrowseDirectory  = 2,
	},
	-- CD-4: featured row positions in the Trading Post zone. The TP marker
	-- sits at (25, 0.5, 0) per MapSetup.luau; lay the 12 stalls in 2 rows of 6
	-- just south of it so foot traffic walks past on the way to spawn.
	featuredRowOrigin       = Vector3.new(25, 0, 14),
	featuredRowOffsets      = {
		Vector3.new(-15, 0, 0), Vector3.new( -9, 0, 0), Vector3.new(-3, 0, 0),
		Vector3.new(  3, 0, 0), Vector3.new(  9, 0, 0), Vector3.new(15, 0, 0),
		Vector3.new(-15, 0, 6), Vector3.new( -9, 0, 6), Vector3.new(-3, 0, 6),
		Vector3.new(  3, 0, 6), Vector3.new(  9, 0, 6), Vector3.new(15, 0, 6),
	},
	-- Stall Manager NPC anchor position. Sits at the head of the featured row.
	stallManagerPosition    = Vector3.new(25, 2.5, 8),
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

	-- Substrates (Phase 2). Sold by SubstrateDealer at spawn. Currently INERT —
	-- they sit in inventoryByCategory.substrates but no gameplay system reads
	-- them yet. Cultivation depth (substrate-driven yield per ADR 002) wires
	-- them in during Phase 3.
	Compost = {
		id = "Compost", displayName = "Compost", description = "Standard growing medium. Works for any common species.",
		category = "substrates", stackable = true, maxStack = 99, tradable = true, droppable = false, baseSellPrice = 3,
	},
	Straw = {
		id = "Straw", displayName = "Straw Bedding", description = "Light, breathable. Favored by cap-tier mushrooms.",
		category = "substrates", stackable = true, maxStack = 99, tradable = true, droppable = false, baseSellPrice = 5,
	},
	Dung = {
		id = "Dung", displayName = "Composted Dung", description = "Rich nitrogen mix for hungry uncommons.",
		category = "substrates", stackable = true, maxStack = 99, tradable = true, droppable = false, baseSellPrice = 12,
	},
	Hardwood = {
		id = "Hardwood", displayName = "Hardwood Chips", description = "Lattice and shelf species prefer dense wood.",
		category = "substrates", stackable = true, maxStack = 99, tradable = true, droppable = false, baseSellPrice = 18,
	},
	Peat = {
		id = "Peat", displayName = "Bog Peat", description = "Acidic. Misty Hollow's water-loving species thrive here.",
		category = "substrates", stackable = true, maxStack = 99, tradable = true, droppable = false, baseSellPrice = 25,
	},
	MagicalLoam = {
		id = "MagicalLoam", displayName = "Magical Loam", description = "Boosts rare-variant chance. Whisper says it sings at night.",
		category = "substrates", stackable = true, maxStack = 99, tradable = true, droppable = false, baseSellPrice = 200,
	},

	-- Spore samples (Phase 2). Sold by SporeMerchant. Currently INERT — Planting
	-- does not yet consume spores from inventory; spore items sit decorative
	-- until cultivation depth ships and Planting reads inventoryByCategory.spores.
	BrownCapSpore = {
		id = "BrownCapSpore", displayName = "Brown Cap Spore", description = "Common species. Grows in any substrate.",
		category = "spores", stackable = true, maxStack = 50, tradable = true, droppable = false, baseSellPrice = 8,
		speciesId = "BrownCap",
	},
	FairyCupSpore = {
		id = "FairyCupSpore", displayName = "Fairy Cup Spore", description = "Common species. Prefers damp substrate.",
		category = "spores", stackable = true, maxStack = 50, tradable = true, droppable = false, baseSellPrice = 12,
		speciesId = "FairyCup",
	},
	InkpotSpore = {
		id = "InkpotSpore", displayName = "Inkpot Spore", description = "Uncommon. Hardwood substrate only.",
		category = "spores", stackable = true, maxStack = 50, tradable = true, droppable = false, baseSellPrice = 40,
		speciesId = "Inkpot",
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
			substrateDealer   = Vector3.new(15, 2, -8),
			sporeMerchant     = Vector3.new(-12, 2, -8),
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

-- UI palette + tokens -----------------------------------------------------------
-- Source of truth for all client UI colors, typography, motion, and spacing.
-- Spec: docs/specs/visual-language.md. Every new client UI module reads from
-- this table; never hardcode hex codes in UI code. Pre-Alpha UIs (Journal,
-- Brew, Potion controllers) predate this token system and use their own
-- inline values — they get migrated as their next polish pass touches them.
Constants.UI = {
	color = {
		forest = {
			ink  = Color3.fromHex("#2B3A2E"),
			deep = Color3.fromHex("#3F5538"),
			mid  = Color3.fromHex("#4A6440"),
			sage = Color3.fromHex("#8FA478"),
			mist = Color3.fromHex("#C9D1B8"),
		},
		parchment = {
			cream = Color3.fromHex("#F4ECDC"),
			mist  = Color3.fromHex("#EDE3D0"),
			bone  = Color3.fromHex("#FAF6EB"),
		},
		bark = {
			warm = Color3.fromHex("#6B4F3A"),
			dark = Color3.fromHex("#3E2D22"),
		},
		text = {
			primary   = Color3.fromHex("#2B3A2E"),
			secondary = Color3.fromHex("#6B6557"),
			muted     = Color3.fromHex("#9A8F7E"),
			onAccent  = Color3.fromHex("#FAF6EB"),
		},
		surface = {
			bg        = Color3.fromHex("#F4ECDC"),
			panel     = Color3.fromHex("#FAF6EB"),
			recessed  = Color3.fromHex("#EDE3D0"),
			divider   = Color3.fromHex("#D4C9B0"),
		},
		accent = {
			primary      = Color3.fromHex("#4A6440"),
			primaryHover = Color3.fromHex("#3F5538"),
			gold         = Color3.fromHex("#C9A04E"),
			amber        = Color3.fromHex("#D9A85C"),
			duskBlue     = Color3.fromHex("#6B8FA8"),
			barnRed      = Color3.fromHex("#B85F5F"),
		},
		state = {
			success = Color3.fromHex("#6B8E5C"),
			warning = Color3.fromHex("#D9A85C"),
			error   = Color3.fromHex("#B85F5F"),
			info    = Color3.fromHex("#6B8FA8"),
		},
	},
	rarity = {
		Common    = Color3.fromHex("#8FA478"),
		Uncommon  = Color3.fromHex("#6B8FA8"),
		Rare      = Color3.fromHex("#B07AA1"),
		Epic      = Color3.fromHex("#D9866A"),
		Legendary = Color3.fromHex("#E5C547"),
		-- Mythic is a gradient — UI code samples both endpoints when needed.
		MythicFrom = Color3.fromHex("#9C68D4"),
		MythicTo   = Color3.fromHex("#5C9BD5"),
	},
	-- NOTE: cottagecore-target fonts (Merriweather / Nunito / Inconsolata
	-- per docs/specs/visual-language.md) aren't all in Roblox's Enum.Font
	-- on every Studio build. Shipping with safe Enum.Font values for now;
	-- swap to the target fonts via Font.new(asset_id, weight, style) when
	-- typography polish lands.
	typography = {
		display = { font = Enum.Font.GothamBold,   size = 28 },
		heading = { font = Enum.Font.GothamBold,   size = 18 },
		body    = { font = Enum.Font.Gotham,       size = 14 },
		caption = { font = Enum.Font.Gotham,       size = 12 },
		numeric = { font = Enum.Font.Code,         size = 16 }, -- Code is monospaced; stand-in for Inconsolata
		button  = { font = Enum.Font.GothamBold,   size = 16 },
	},
	motion = { micro = 0.08, short = 0.20, medium = 0.35, long = 0.60, discovery = 1.20 },
	space  = { xs = 4, sm = 8, md = 16, lg = 24, xl = 32, xxl = 48 },
	radius = { card = 12, button = 8, chip = 4 },
	tapTargetMin = 44,
}

-- RemoteEvent / RemoteFunction names ------------------------------------------
-- These are referenced from both client and server so they live here as
-- string constants instead of magic strings scattered through the codebase.
Constants.REMOTES = {
	HarvestMushroom = "HarvestMushroom",
	PlantPatch = "PlantPatch",
	PlantSpecies = "PlantSpecies",
	-- Shop / merchants (Phase 2). Pre-Alpha SellInventory + SellCompleted
	-- removed — sales now route through the Shop UI.
	OpenShop = "OpenShop",
	BuyFromMerchant = "BuyFromMerchant",
	SellToMerchant = "SellToMerchant",
	ShopTransactionCompleted = "ShopTransactionCompleted",
	-- Dialogue (Phase 2). Server tells client to open dialogue UI; client
	-- fires DialogueAction back when the player picks a response that has
	-- a side effect.
	OpenDialogue = "OpenDialogue",
	DialogueAction = "DialogueAction",
	-- Quest lifecycle (Phase 2). AcceptQuest/TurnInQuest/AbandonQuest are
	-- usually fired by dialogue actions but exposed as direct remotes for
	-- HUD-driven flows + future side quests with non-NPC entry points.
	AcceptQuest = "AcceptQuest",
	TurnInQuest = "TurnInQuest",
	AbandonQuest = "AbandonQuest",
	-- Trading Post (Phase 2). Two-player synchronized trade with anti-scam
	-- lock + countdown + confirm flow. See docs/specs/trading-post.md.
	RequestTrade = "RequestTrade",
	TradeRequestReceived = "TradeRequestReceived",
	RespondToTradeRequest = "RespondToTradeRequest",
	TradeSessionStarted = "TradeSessionStarted",
	UpdateTradeOffer = "UpdateTradeOffer",
	TradeOfferUpdated = "TradeOfferUpdated",
	LockTradeOffer = "LockTradeOffer",
	ConfirmTrade = "ConfirmTrade",
	CancelTrade = "CancelTrade",
	TradeCompleted = "TradeCompleted",
	-- Player Stalls (Phase 2). See docs/specs/player-stalls.md and
	-- .planning/phases/02-closed-beta-social-systems-content/02-CONTEXT.md (D-12).
	-- C->S
	CreateListing             = "CreateListing",
	CancelListing             = "CancelListing",
	BuyListing                = "BuyListing",
	RentFeaturedSlot          = "RentFeaturedSlot",
	ClaimMailbox              = "ClaimMailbox",
	BrowseDirectory           = "BrowseDirectory",
	-- S->C
	OpenStallOwnerUI          = "OpenStallOwnerUI",
	OpenStallBuyerUI          = "OpenStallBuyerUI",
	StallTransactionCompleted = "StallTransactionCompleted",
	MailboxUpdated            = "MailboxUpdated",
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
