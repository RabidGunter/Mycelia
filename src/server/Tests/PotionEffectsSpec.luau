-- Tests for the pure registry helpers in PotionEffects (apply / clear /
-- isActive / magnitudeOf / sweepExpired / snapshot). These don't touch
-- Roblox state; they operate on plain `state` tables passed in.
--
-- The Roblox-bound side of PotionEffects (consume, walk-speed application,
-- plot acceleration, remotes) is exercised by playtest in Studio, not by
-- unit tests.

local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local PotionEffects = require(ServerScriptService.Server.PotionEffects)

return function()
	TestKit.describe("PotionEffects.apply", function()
		TestKit.test("creates an entry with magnitude and expiresAt", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			TestKit.eq(state[1].speed.magnitude, 1.3)
			TestKit.eq(state[1].speed.expiresAt, 100)
		end)

		TestKit.test("returns true on fresh activation", function()
			local state = {}
			local fresh = PotionEffects.apply(state, 1, "speed", 1.3, 100)
			TestKit.eq(fresh, true)
		end)

		TestKit.test("returns false on refresh of same kind", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			local fresh = PotionEffects.apply(state, 1, "speed", 1.5, 200)
			TestKit.eq(fresh, false)
			TestKit.eq(state[1].speed.magnitude, 1.5)
			TestKit.eq(state[1].speed.expiresAt, 200)
		end)

		TestKit.test("different kinds for the same player coexist", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.apply(state, 1, "growth", 0.7, 200)
			TestKit.eq(state[1].speed.magnitude, 1.3)
			TestKit.eq(state[1].growth.magnitude, 0.7)
		end)

		TestKit.test("different players are isolated", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.apply(state, 2, "speed", 1.5, 100)
			TestKit.eq(state[1].speed.magnitude, 1.3)
			TestKit.eq(state[2].speed.magnitude, 1.5)
		end)
	end)

	TestKit.describe("PotionEffects.clear", function()
		TestKit.test("removes the named kind", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.apply(state, 1, "growth", 0.7, 200)
			PotionEffects.clear(state, 1, "speed")
			TestKit.eq(state[1].speed, nil)
			TestKit.eq(state[1].growth.magnitude, 0.7)
		end)

		TestKit.test("removes the player's bucket entirely when last kind clears", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.clear(state, 1, "speed")
			TestKit.eq(state[1], nil)
		end)

		TestKit.test("is a no-op for unknown player or kind", function()
			local state = {}
			PotionEffects.clear(state, 99, "speed")    -- should not error
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.clear(state, 1, "growth")    -- different kind
			TestKit.eq(state[1].speed.magnitude, 1.3)
		end)
	end)

	TestKit.describe("PotionEffects.isActive", function()
		TestKit.test("returns false for unknown player", function()
			TestKit.eq(PotionEffects.isActive({}, 1, "speed", 0), false)
		end)

		TestKit.test("returns true while now < expiresAt", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			TestKit.eq(PotionEffects.isActive(state, 1, "speed", 50), true)
		end)

		TestKit.test("returns false at and past expiresAt", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			TestKit.eq(PotionEffects.isActive(state, 1, "speed", 100), false)
			TestKit.eq(PotionEffects.isActive(state, 1, "speed", 101), false)
		end)
	end)

	TestKit.describe("PotionEffects.magnitudeOf", function()
		TestKit.test("returns default for unknown player", function()
			TestKit.eq(PotionEffects.magnitudeOf({}, 1, "growth", 0, 1.0), 1.0)
		end)

		TestKit.test("returns active magnitude while not expired", function()
			local state = {}
			PotionEffects.apply(state, 1, "growth", 0.7, 100)
			TestKit.eq(PotionEffects.magnitudeOf(state, 1, "growth", 50, 1.0), 0.7)
		end)

		TestKit.test("returns default once expired", function()
			local state = {}
			PotionEffects.apply(state, 1, "growth", 0.7, 100)
			TestKit.eq(PotionEffects.magnitudeOf(state, 1, "growth", 200, 1.0), 1.0)
		end)

		TestKit.test("yield-style default of 0 works", function()
			local state = {}
			TestKit.eq(PotionEffects.magnitudeOf(state, 1, "wildYield", 0, 0), 0)
			PotionEffects.apply(state, 1, "wildYield", 1, 100)
			TestKit.eq(PotionEffects.magnitudeOf(state, 1, "wildYield", 50, 0), 1)
		end)
	end)

	TestKit.describe("PotionEffects.sweepExpired", function()
		TestKit.test("removes only entries past expiresAt", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.apply(state, 1, "growth", 0.7, 200)
			local expired = PotionEffects.sweepExpired(state, 150)
			TestKit.eq(#expired, 1)
			TestKit.eq(expired[1].userId, 1)
			TestKit.eq(expired[1].kind, "speed")
			TestKit.eq(state[1].speed, nil)
			TestKit.eq(state[1].growth.magnitude, 0.7)
		end)

		TestKit.test("returns empty list when nothing has expired", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			local expired = PotionEffects.sweepExpired(state, 50)
			TestKit.eq(#expired, 0)
		end)

		TestKit.test("collapses bucket when last entry expires", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.sweepExpired(state, 200)
			TestKit.eq(state[1], nil)
		end)

		TestKit.test("expires across multiple players", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.apply(state, 2, "growth", 0.7, 100)
			PotionEffects.apply(state, 3, "wildYield", 1, 500)
			local expired = PotionEffects.sweepExpired(state, 200)
			TestKit.eq(#expired, 2)
			TestKit.eq(state[1], nil)
			TestKit.eq(state[2], nil)
			TestKit.eq(state[3].wildYield.magnitude, 1)
		end)
	end)

	TestKit.describe("PotionEffects.snapshot", function()
		TestKit.test("returns empty list for unknown player", function()
			TestKit.eq(#PotionEffects.snapshot({}, 1, 0), 0)
		end)

		TestKit.test("includes only non-expired entries", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.apply(state, 1, "growth", 0.7, 50)
			local snap = PotionEffects.snapshot(state, 1, 75)
			TestKit.eq(#snap, 1)
			TestKit.eq(snap[1].kind, "speed")
			TestKit.eq(snap[1].magnitude, 1.3)
			TestKit.eq(snap[1].expiresAt, 100)
		end)

		TestKit.test("returns all kinds when all are active", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.3, 100)
			PotionEffects.apply(state, 1, "growth", 0.7, 100)
			PotionEffects.apply(state, 1, "wildYield", 1, 100)
			TestKit.eq(#PotionEffects.snapshot(state, 1, 50), 3)
		end)

		TestKit.test("includes params when present", function()
			local state = {}
			PotionEffects.apply(state, 1, "weatherSummon", 0, 100, { weatherKind = "Rainy" })
			local snap = PotionEffects.snapshot(state, 1, 50)
			TestKit.eq(#snap, 1)
			TestKit.eq(snap[1].params.weatherKind, "Rainy")
		end)
	end)

	TestKit.describe("PotionEffects.apply with params (Phase 1: cosmetic / weather / timeShift)", function()
		TestKit.test("stores params alongside magnitude + expiresAt", function()
			local state = {}
			PotionEffects.apply(state, 1, "cosmeticGlow", 0, 100, { color = "blue" })
			TestKit.eq(state[1].cosmeticGlow.params.color, "blue")
			TestKit.eq(state[1].cosmeticGlow.expiresAt, 100)
		end)

		TestKit.test("apply without params keeps params field nil", function()
			local state = {}
			PotionEffects.apply(state, 1, "luck", 0.05, 100)
			TestKit.eq(state[1].luck.params, nil)
		end)

		TestKit.test("refresh replaces params (one trail at a time)", function()
			local state = {}
			PotionEffects.apply(state, 1, "cosmeticGlow", 0, 100, { color = "blue" })
			PotionEffects.apply(state, 1, "cosmeticGlow", 0, 200, { color = "red" })
			TestKit.eq(state[1].cosmeticGlow.params.color, "red")
			TestKit.eq(state[1].cosmeticGlow.expiresAt, 200)
		end)
	end)

	TestKit.describe("PotionEffects.paramsOf", function()
		TestKit.test("returns nil for unknown player", function()
			TestKit.eq(PotionEffects.paramsOf({}, 1, "cosmeticGlow", 0), nil)
		end)

		TestKit.test("returns nil for kind not active", function()
			local state = {}
			PotionEffects.apply(state, 1, "speed", 1.5, 100)
			TestKit.eq(PotionEffects.paramsOf(state, 1, "cosmeticGlow", 50), nil)
		end)

		TestKit.test("returns active params while not expired", function()
			local state = {}
			PotionEffects.apply(state, 1, "weatherSummon", 0, 100, { weatherKind = "Foggy" })
			local p = PotionEffects.paramsOf(state, 1, "weatherSummon", 50)
			TestKit.eq(p.weatherKind, "Foggy")
		end)

		TestKit.test("returns nil once expired", function()
			local state = {}
			PotionEffects.apply(state, 1, "weatherSummon", 0, 100, { weatherKind = "Sunny" })
			TestKit.eq(PotionEffects.paramsOf(state, 1, "weatherSummon", 200), nil)
		end)
	end)

	TestKit.describe("PotionEffects.magnitudeOf for new effect kinds", function()
		TestKit.test("luckBonus default 0", function()
			TestKit.eq(PotionEffects.magnitudeOf({}, 1, "luck", 0, 0), 0)
		end)

		TestKit.test("harvestYieldBonus default 0", function()
			TestKit.eq(PotionEffects.magnitudeOf({}, 1, "harvestYield", 0, 0), 0)
		end)

		TestKit.test("revealRadius default 0", function()
			TestKit.eq(PotionEffects.magnitudeOf({}, 1, "reveal", 0, 0), 0)
		end)

		TestKit.test("spiritAttract default 1.0 (no buff = neutral multiplier)", function()
			TestKit.eq(PotionEffects.magnitudeOf({}, 1, "spiritAttract", 0, 1.0), 1.0)
		end)

		TestKit.test("active luck returns the configured rareBonus", function()
			local state = {}
			PotionEffects.apply(state, 1, "luck", 0.15, 100)
			TestKit.eq(PotionEffects.magnitudeOf(state, 1, "luck", 50, 0), 0.15)
		end)

		TestKit.test("active reveal returns the configured radius", function()
			local state = {}
			PotionEffects.apply(state, 1, "reveal", 90, 100)
			TestKit.eq(PotionEffects.magnitudeOf(state, 1, "reveal", 50, 0), 90)
		end)
	end)
end
