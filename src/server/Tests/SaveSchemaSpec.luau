-- Tests for save schema v3 + migration paths.
--
-- We exercise PlayerData.defaultData() and PlayerData.migrate(data) directly.
-- Both are pure (no Roblox-instance dependencies, no DataStore touching), so
-- we can run them in TestKit without ProfileService side effects.
--
-- Spec being verified: docs/specs/save-schema-v3.md.

local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local PlayerData = require(ServerScriptService.Server.PlayerData)

return function()
	TestKit.describe("PlayerData.defaultData", function()
		TestKit.test("returns schemaVersion = 3", function()
			TestKit.eq(PlayerData.defaultData().schemaVersion, 3)
		end)

		TestKit.test("contains all top-level v3 keys", function()
			local d = PlayerData.defaultData()
			for _, key in ipairs({
				"schemaVersion", "coins", "inventory", "potions",
				"inventoryByCategory", "spirits", "decorations", "plots",
				"stats", "reputation", "activeQuests", "gamepassesOwned",
				"settings", "auditTrail",
			}) do
				TestKit.truthy(d[key] ~= nil, "missing top-level key: " .. key)
			end
		end)

		TestKit.test("inventoryByCategory has all 11 categories", function()
			local d = PlayerData.defaultData()
			for _, cat in ipairs({
				"mushrooms_raw", "mushrooms_dried", "potions", "spores",
				"substrates", "additives", "recipes", "spirit_items",
				"quest_items", "cosmetics", "tools",
			}) do
				TestKit.truthy(d.inventoryByCategory[cat] ~= nil,
					"missing category: " .. cat)
			end
		end)

		TestKit.test("StarterGlade is unlocked by default", function()
			TestKit.eq(PlayerData.defaultData().stats.biomesUnlocked.StarterGlade, true)
		end)

		TestKit.test("settings have sensible audio defaults", function()
			local s = PlayerData.defaultData().settings
			TestKit.eq(s.masterVolume, 1.0)
			TestKit.eq(s.musicVolume, 0.7)
			TestKit.eq(s.sfxVolume, 1.0)
			TestKit.eq(s.ambientVolume, 0.6)
		end)

		TestKit.test("default hutAccessLevel is friends_only", function()
			TestKit.eq(PlayerData.defaultData().settings.hutAccessLevel, "friends_only")
		end)
	end)

	TestKit.describe("PlayerData.migrate from v1", function()
		local function v1Save()
			-- Approximation of what a v1 save looked like (pre-brewing).
			return {
				schemaVersion = 1,
				coins = 100,
				inventory = { BrownCap = 5, FairyCup = 2 },
				stats = {
					totalHarvested = 10,
					totalPlanted = 3,
					totalSold = 0,
					totalCoinsEarned = 75,
					speciesDiscovered = { BrownCap = true, FairyCup = true },
				},
			}
		end

		TestKit.test("ends at schemaVersion = 3", function()
			local migrated = PlayerData.migrate(v1Save())
			TestKit.eq(migrated.schemaVersion, 3)
		end)

		TestKit.test("preserves coins + inventory + stats from v1", function()
			local migrated = PlayerData.migrate(v1Save())
			TestKit.eq(migrated.coins, 100)
			TestKit.eq(migrated.inventory.BrownCap, 5)
			TestKit.eq(migrated.inventory.FairyCup, 2)
			TestKit.eq(migrated.stats.totalHarvested, 10)
			TestKit.eq(migrated.stats.speciesDiscovered.BrownCap, true)
		end)

		TestKit.test("backfills v2 brewing fields", function()
			local migrated = PlayerData.migrate(v1Save())
			TestKit.eq(type(migrated.potions), "table")
			TestKit.eq(migrated.stats.totalBrewed, 0)
			TestKit.eq(type(migrated.stats.potionsDiscovered), "table")
		end)

		TestKit.test("backfills v3 inventoryByCategory with mushrooms in mushrooms_raw", function()
			local migrated = PlayerData.migrate(v1Save())
			TestKit.eq(migrated.inventoryByCategory.mushrooms_raw.BrownCap, 5)
			TestKit.eq(migrated.inventoryByCategory.mushrooms_raw.FairyCup, 2)
		end)

		TestKit.test("backfills v3 spirits + decorations + plots + reputation + quests + gamepasses", function()
			local migrated = PlayerData.migrate(v1Save())
			TestKit.eq(type(migrated.spirits.activeRoster), "table")
			TestKit.eq(type(migrated.spirits.allOwned), "table")
			TestKit.eq(type(migrated.decorations.unlocked), "table")
			TestKit.eq(type(migrated.decorations.placed), "table")
			TestKit.eq(type(migrated.plots), "table")
			TestKit.eq(type(migrated.reputation), "table")
			TestKit.eq(type(migrated.activeQuests), "table")
			TestKit.eq(type(migrated.gamepassesOwned), "table")
		end)

		TestKit.test("backfills v3 settings", function()
			local migrated = PlayerData.migrate(v1Save())
			TestKit.eq(migrated.settings.masterVolume, 1.0)
			TestKit.eq(migrated.settings.hutAccessLevel, "friends_only")
		end)

		TestKit.test("backfills v3 stats counters and sets", function()
			local migrated = PlayerData.migrate(v1Save())
			TestKit.eq(migrated.stats.totalRareVariants, 0)
			TestKit.eq(migrated.stats.totalPlotFailures, 0)
			TestKit.eq(migrated.stats.recipesAttempted, 0)
			TestKit.eq(type(migrated.stats.spiritsCollected), "table")
			TestKit.eq(migrated.stats.biomesUnlocked.StarterGlade, true)
			TestKit.eq(type(migrated.stats.questsCompleted), "table")
			TestKit.eq(type(migrated.stats.recipesDiscovered), "table")
		end)
	end)

	TestKit.describe("PlayerData.migrate from v2", function()
		local function v2Save()
			return {
				schemaVersion = 2,
				coins = 250,
				inventory = { Glowmoss = 1 },
				potions = { CommonSpeedPotion = 2 },
				stats = {
					totalHarvested = 50,
					totalPlanted = 10,
					totalSold = 5,
					totalCoinsEarned = 200,
					totalBrewed = 3,
					speciesDiscovered = { Glowmoss = true },
					potionsDiscovered = { CommonSpeedPotion = true },
				},
			}
		end

		TestKit.test("ends at schemaVersion = 3", function()
			TestKit.eq(PlayerData.migrate(v2Save()).schemaVersion, 3)
		end)

		TestKit.test("preserves potions inventory", function()
			local migrated = PlayerData.migrate(v2Save())
			TestKit.eq(migrated.potions.CommonSpeedPotion, 2)
		end)

		TestKit.test("inventoryByCategory.potions mirrors data.potions", function()
			local migrated = PlayerData.migrate(v2Save())
			TestKit.eq(migrated.inventoryByCategory.potions.CommonSpeedPotion, 2)
		end)

		TestKit.test("preserves potionsDiscovered set", function()
			local migrated = PlayerData.migrate(v2Save())
			TestKit.eq(migrated.stats.potionsDiscovered.CommonSpeedPotion, true)
		end)
	end)

	TestKit.describe("PlayerData.migrate is idempotent", function()
		TestKit.test("v3 save is unchanged by migrate", function()
			local fresh = PlayerData.defaultData()
			fresh.coins = 999    -- mark so we can check no defaults stomped it
			local migrated = PlayerData.migrate(fresh)
			TestKit.eq(migrated.schemaVersion, 3)
			TestKit.eq(migrated.coins, 999)
		end)

		TestKit.test("running migrate twice is the same as once", function()
			local once = PlayerData.migrate(PlayerData.defaultData())
			local twice = PlayerData.migrate(once)
			TestKit.eq(twice.schemaVersion, 3)
			-- Same table identity confirms no clobbering on second pass.
			TestKit.eq(once, twice)
		end)
	end)

	TestKit.describe("Migration handles malformed input gracefully", function()
		TestKit.test("save with no schemaVersion is treated as v1", function()
			local migrated = PlayerData.migrate({
				coins = 50,
				inventory = {},
				stats = { speciesDiscovered = {} },
			})
			TestKit.eq(migrated.schemaVersion, 3)
		end)

		TestKit.test("save with missing stats subtable doesn't crash", function()
			-- A pathological save with no stats table at all.
			local migrated = PlayerData.migrate({
				schemaVersion = 1,
				coins = 0,
				inventory = {},
			})
			TestKit.eq(migrated.schemaVersion, 3)
			-- Top-level v3 fields still backfilled.
			TestKit.eq(type(migrated.spirits), "table")
			TestKit.eq(type(migrated.settings), "table")
		end)
	end)
end
