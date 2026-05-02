-- Tests for the pure helpers in Spirits.lua + PassiveBonuses.lua.
--
-- Roblox-bound code (claim handler, world Model spawning, wander tick) is
-- exercised by playtest in Studio. These cover the math + data paths that
-- matter for correctness and that are easy to break.
--
-- Spec: docs/specs/spirits.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Spirits = require(ServerScriptService.Server.Spirits)
local PassiveBonuses = require(ServerScriptService.Server.PassiveBonuses)

return function()
	-- Synthetic Constants.SPIRITS used by some tests so we can vary tunables
	-- without mutating the real one. Where we test against the live config
	-- (e.g. catalog integrity), we use Constants.SPIRITS directly.
	local function syntheticSpiritsConfig()
		return {
			startingRosterSize        = 3,
			biggerRosterGamepassBonus = 3,
			attractionTickSeconds     = 300,
			bonuses = {
				Mossling    = { kind = "wildYield",    magnitude = 0.05 },
				Lanternfox  = { kind = "wildYield",    magnitude = 0.15 },
				Dewdrop     = { kind = "harvestYield", magnitude = 0.05 },
				Spritefly   = { kind = "growthSpeed",  magnitude = 0.05 },
			},
			attractionMap = {
				Mossling = { Mossring = 0.10, BrownCap = 0.04 },
				Spritefly = { FairyCup = 0.10 },
			},
		}
	end

	TestKit.describe("Spirits.rosterCapForData", function()
		TestKit.test("default cap is startingRosterSize when no gamepass owned", function()
			local data = { gamepassesOwned = {} }
			TestKit.eq(Spirits.rosterCapForData(data, syntheticSpiritsConfig()), 3)
		end)

		TestKit.test("cap extends with BiggerSpiritRoster gamepass", function()
			local data = { gamepassesOwned = { BiggerSpiritRoster = { ownedSince = 0 } } }
			TestKit.eq(Spirits.rosterCapForData(data, syntheticSpiritsConfig()), 6)
		end)

		TestKit.test("nil data returns startingRosterSize (defensive)", function()
			TestKit.eq(Spirits.rosterCapForData(nil, syntheticSpiritsConfig()), 3)
		end)
	end)

	TestKit.describe("Spirits.holdingsFromData", function()
		TestKit.test("empty data returns empty set", function()
			TestKit.eq(next(Spirits.holdingsFromData(nil)), nil)
			TestKit.eq(next(Spirits.holdingsFromData({})), nil)
		end)

		TestKit.test("inventory species are included", function()
			local holdings = Spirits.holdingsFromData({
				inventory = { BrownCap = 3, FairyCup = 1 },
			})
			TestKit.eq(holdings.BrownCap, true)
			TestKit.eq(holdings.FairyCup, true)
		end)

		TestKit.test("inventory species with count 0 are excluded", function()
			local holdings = Spirits.holdingsFromData({
				inventory = { BrownCap = 0, FairyCup = 2 },
			})
			TestKit.eq(holdings.BrownCap, nil)
			TestKit.eq(holdings.FairyCup, true)
		end)

		TestKit.test("Growing + Ripe plot species are included", function()
			local holdings = Spirits.holdingsFromData({
				inventory = {},
				plots = {
					[1] = { state = "Growing", speciesId = "Mossring" },
					[2] = { state = "Ripe",    speciesId = "Glowmoss" },
					[3] = { state = "Empty" },
				},
			})
			TestKit.eq(holdings.Mossring, true)
			TestKit.eq(holdings.Glowmoss, true)
		end)

		TestKit.test("Empty plots don't contribute holdings", function()
			local holdings = Spirits.holdingsFromData({
				plots = { [1] = { state = "Empty", speciesId = "" } },
			})
			TestKit.eq(next(holdings), nil)
		end)

		TestKit.test("inventory + plot species deduplicate (set semantics)", function()
			local holdings = Spirits.holdingsFromData({
				inventory = { Mossring = 5 },
				plots = { [1] = { state = "Growing", speciesId = "Mossring" } },
			})
			-- Same species via two paths should still appear once.
			TestKit.eq(holdings.Mossring, true)
		end)
	end)

	TestKit.describe("Spirits.attractionChancePerTick", function()
		local config = syntheticSpiritsConfig()
		local tick = 300    -- 5 min = 12 ticks/hour

		TestKit.test("zero chance for unknown spirit", function()
			local chance = Spirits.attractionChancePerTick(
				"NotASpirit", { Mossring = true }, config, tick, 1
			)
			TestKit.eq(chance, 0)
		end)

		TestKit.test("zero chance with no holdings", function()
			TestKit.eq(Spirits.attractionChancePerTick("Mossling", {}, config, tick, 1), 0)
		end)

		TestKit.test("matches per-hour / 12 with one matching species", function()
			-- Mossling base for Mossring = 0.10/hour; 12 ticks/hr -> ~0.00833.
			local chance = Spirits.attractionChancePerTick(
				"Mossling", { Mossring = true }, config, tick, 1
			)
			TestKit.eq(math.abs(chance - (0.10 / 12)) < 1e-6, true)
		end)

		TestKit.test("multiple matching species stack additively", function()
			local chance = Spirits.attractionChancePerTick(
				"Mossling", { Mossring = true, BrownCap = true }, config, tick, 1
			)
			-- (0.10 + 0.04) / 12 = 0.01166...
			TestKit.eq(math.abs(chance - (0.14 / 12)) < 1e-6, true)
		end)

		TestKit.test("unrelated holdings don't contribute", function()
			-- FairyCup attracts Spritefly, not Mossling.
			TestKit.eq(Spirits.attractionChancePerTick(
				"Mossling", { FairyCup = true }, config, tick, 1
			), 0)
		end)

		TestKit.test("spiritAttract potion multiplier scales chance", function()
			local base = Spirits.attractionChancePerTick(
				"Mossling", { Mossring = true }, config, tick, 1
			)
			local boosted = Spirits.attractionChancePerTick(
				"Mossling", { Mossring = true }, config, tick, 2
			)
			TestKit.eq(math.abs(boosted - (base * 2)) < 1e-6, true)
		end)
	end)

	TestKit.describe("PassiveBonuses.sumFromSpirits", function()
		local config = syntheticSpiritsConfig()

		TestKit.test("empty roster contributes nothing", function()
			local data = {
				spirits = { activeRoster = {}, allOwned = {} },
			}
			TestKit.eq(next(PassiveBonuses.sumFromSpirits(data, config)), nil)
		end)

		TestKit.test("missing spirits subtable is safe", function()
			TestKit.eq(next(PassiveBonuses.sumFromSpirits({}, config)), nil)
			TestKit.eq(next(PassiveBonuses.sumFromSpirits(nil, config)), nil)
		end)

		TestKit.test("single Mossling contributes wildYield 0.05", function()
			local data = {
				spirits = {
					activeRoster = { "Mossling_1_100" },
					allOwned = { Mossling_1_100 = { spiritType = "Mossling" } },
				},
			}
			local totals = PassiveBonuses.sumFromSpirits(data, config)
			TestKit.eq(totals.wildYield, 0.05)
		end)

		TestKit.test("two same-kind spirits stack additively", function()
			-- Mossling 0.05 + Lanternfox 0.15 = 0.20 wildYield
			local data = {
				spirits = {
					activeRoster = { "Mossling_1_100", "Lanternfox_1_200" },
					allOwned = {
						Mossling_1_100   = { spiritType = "Mossling" },
						Lanternfox_1_200 = { spiritType = "Lanternfox" },
					},
				},
			}
			local totals = PassiveBonuses.sumFromSpirits(data, config)
			TestKit.eq(math.abs(totals.wildYield - 0.20) < 1e-6, true)
		end)

		TestKit.test("different kinds stay separate", function()
			-- Mossling (wildYield) + Dewdrop (harvestYield) + Spritefly (growthSpeed)
			local data = {
				spirits = {
					activeRoster = { "M_1", "D_1", "S_1" },
					allOwned = {
						M_1 = { spiritType = "Mossling" },
						D_1 = { spiritType = "Dewdrop" },
						S_1 = { spiritType = "Spritefly" },
					},
				},
			}
			local totals = PassiveBonuses.sumFromSpirits(data, config)
			TestKit.eq(totals.wildYield, 0.05)
			TestKit.eq(totals.harvestYield, 0.05)
			TestKit.eq(totals.growthSpeed, 0.05)
		end)

		TestKit.test("activeRoster entry without allOwned record is skipped (defensive)", function()
			local data = {
				spirits = {
					activeRoster = { "M_1", "ghost_1" },
					allOwned = { M_1 = { spiritType = "Mossling" } },
				},
			}
			local totals = PassiveBonuses.sumFromSpirits(data, config)
			TestKit.eq(totals.wildYield, 0.05)
		end)

		TestKit.test("unknown spiritType is skipped (defensive)", function()
			local data = {
				spirits = {
					activeRoster = { "X_1" },
					allOwned = { X_1 = { spiritType = "Unicorn" } },
				},
			}
			local totals = PassiveBonuses.sumFromSpirits(data, config)
			TestKit.eq(next(totals), nil)
		end)
	end)

	TestKit.describe("Constants.SPIRITS — catalog integrity", function()
		TestKit.test("every bonus references a known kind", function()
			local validKinds = {
				wildYield = true, harvestYield = true,
				growthSpeed = true, rareChance = true,
			}
			for spiritId, def in pairs(Constants.SPIRITS.bonuses) do
				TestKit.truthy(validKinds[def.kind] == true,
					"unknown bonus kind for " .. spiritId .. ": " .. tostring(def.kind))
			end
		end)

		TestKit.test("every spirit in attractionMap has a rarity tier", function()
			for spiritId in pairs(Constants.SPIRITS.attractionMap) do
				TestKit.truthy(Constants.SPIRITS.rarity[spiritId] ~= nil,
					"missing rarity for " .. spiritId)
			end
		end)

		TestKit.test("every spirit in bonuses has a rarity tier", function()
			for spiritId in pairs(Constants.SPIRITS.bonuses) do
				TestKit.truthy(Constants.SPIRITS.rarity[spiritId] ~= nil,
					"missing rarity for " .. spiritId)
			end
		end)
	end)
end
