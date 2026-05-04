-- Tests for RateLimit.luau — per-player per-remote-name cooldown checker.

local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local RateLimit = require(ServerScriptService.Server.RateLimit)

return function()

	TestKit.describe("RateLimit.check", function()
		TestKit.test("first call within an interval returns true; immediate second call returns false", function()
			RateLimit._reset()
			local p = { UserId = 42 }
			TestKit.eq(RateLimit.check(p, "BuyListing", 1), true)
			TestKit.eq(RateLimit.check(p, "BuyListing", 1), false)
		end)

		TestKit.test("isolation across players: two userIds are independently rate-limited", function()
			RateLimit._reset()
			local p1 = { UserId = 1 }
			local p2 = { UserId = 2 }
			TestKit.eq(RateLimit.check(p1, "BuyListing", 60), true)
			TestKit.eq(RateLimit.check(p2, "BuyListing", 60), true)
			-- Both within the 60s window now -> both rejected on second call
			TestKit.eq(RateLimit.check(p1, "BuyListing", 60), false)
			TestKit.eq(RateLimit.check(p2, "BuyListing", 60), false)
		end)

		TestKit.test("isolation across remote names: two remotes are independently rate-limited", function()
			RateLimit._reset()
			local p = { UserId = 99 }
			TestKit.eq(RateLimit.check(p, "BuyListing", 60), true)
			-- Different remoteName, even within the window -> still allowed
			TestKit.eq(RateLimit.check(p, "CreateListing", 60), true)
			-- Repeat the first remote within window -> rejected
			TestKit.eq(RateLimit.check(p, "BuyListing", 60), false)
		end)

		TestKit.test("rejects malformed args (defensive)", function()
			RateLimit._reset()
			TestKit.eq(RateLimit.check(nil, "X", 1), false)
			TestKit.eq(RateLimit.check({}, "X", 1), false)            -- no UserId
			TestKit.eq(RateLimit.check({ UserId = "x" }, "X", 1), false)  -- non-numeric UserId
			TestKit.eq(RateLimit.check({ UserId = 1 }, nil, 1), false)
			TestKit.eq(RateLimit.check({ UserId = 1 }, "X", nil), false)
		end)
	end)

end
