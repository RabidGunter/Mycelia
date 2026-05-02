-- Tests for Selling.priceOf — the witch's payout calculator.
--
-- These pin the economy floor: if these numbers change unexpectedly,
-- it means somebody adjusted Species.baseSellPrice / Tiers.sellMultiplier
-- without realising it shifts the witch payout. Failing here is the
-- early-warning the balance change actually happened.
--
-- Hardcoded expected values are derived from the data shipped on
-- 2026-04-30 (Pre-Alpha):
--   BrownCap     base 3   tier Common    multiplier 1   ->   3
--   LatticeVeil  base 12  tier Uncommon  multiplier 2   ->  24
--   Glowmoss     base 50  tier Rare      multiplier 5   -> 250
--   CrystalCap   base 200 tier Epic      multiplier 12  -> 2400

local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local Selling = require(ServerScriptService.Server.Selling)

return function()
	TestKit.describe("Selling.priceOf", function()
		TestKit.test("returns 0 for empty inventory", function()
			TestKit.eq(Selling.priceOf({}), 0)
		end)

		TestKit.test("prices Common at base * 1", function()
			TestKit.eq(Selling.priceOf({ BrownCap = 1 }), 3)
		end)

		TestKit.test("scales linearly with count", function()
			TestKit.eq(Selling.priceOf({ BrownCap = 5 }), 15)
		end)

		TestKit.test("applies Uncommon multiplier (2x)", function()
			TestKit.eq(Selling.priceOf({ LatticeVeil = 1 }), 24)
		end)

		TestKit.test("applies Rare multiplier (5x)", function()
			TestKit.eq(Selling.priceOf({ Glowmoss = 1 }), 250)
		end)

		TestKit.test("applies Epic multiplier (12x)", function()
			TestKit.eq(Selling.priceOf({ CrystalCap = 1 }), 2400)
		end)

		TestKit.test("sums across species", function()
			-- 2 BrownCap (6) + 1 LatticeVeil (24) + 1 Glowmoss (250) = 280
			TestKit.eq(Selling.priceOf({
				BrownCap = 2,
				LatticeVeil = 1,
				Glowmoss = 1,
			}), 280)
		end)

		TestKit.test("ignores unknown species ids without crashing", function()
			TestKit.eq(Selling.priceOf({ NonexistentMushroom = 99 }), 0)
		end)

		TestKit.test("includes valid species and skips unknown ones in the same inventory", function()
			TestKit.eq(Selling.priceOf({
				BrownCap = 1,
				NonexistentMushroom = 99,
			}), 3)
		end)
	end)
end
