-- Tests for Exchange.luau pure helpers — snapshotData, restoreFromSnapshot,
-- applyOneSided, buildAuditEntry. writeAudit's DataStore side is not exercised
-- here; in TestKit context it no-ops via pcall.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local Exchange = require(ServerScriptService.Server.Exchange)

local function freshData()
	return {
		coins = 1000,
		inventory = { BrownCap = 5, Glowmoss = 1 },
		inventoryByCategory = {
			substrates = { Compost = 3, Hardwood = 1 },
			spores = { BrownCapSpore = 2 },
			tools = { CrystalShard = 1 },
		},
	}
end

return function()

	TestKit.describe("Exchange.snapshotData", function()
		TestKit.test("deep-copies coins + inventory + inventoryByCategory", function()
			local d = freshData()
			local snap = Exchange.snapshotData(d)
			TestKit.eq(snap.coins, 1000)
			TestKit.eq(snap.inventory.BrownCap, 5)
			TestKit.eq(snap.inventoryByCategory.substrates.Compost, 3)
			-- mutate snapshot, original untouched
			snap.coins = 1
			snap.inventory.BrownCap = 99
			snap.inventoryByCategory.substrates.Compost = 99
			TestKit.eq(d.coins, 1000)
			TestKit.eq(d.inventory.BrownCap, 5)
			TestKit.eq(d.inventoryByCategory.substrates.Compost, 3)
		end)
		TestKit.test("returns nil for nil input (defensive)", function()
			TestKit.eq(Exchange.snapshotData(nil), nil)
		end)
	end)

	TestKit.describe("Exchange.restoreFromSnapshot", function()
		TestKit.test("round-trip: snap, mutate heavily, restore returns to snap state", function()
			local d = freshData()
			local snap = Exchange.snapshotData(d)
			-- mutate the original heavily
			d.coins = 50
			d.inventory.BrownCap = 100
			d.inventory.NewSpecies = 10
			d.inventoryByCategory.substrates = nil
			d.inventoryByCategory.cosmetics = { GoldenHat = 1 }
			-- restore
			Exchange.restoreFromSnapshot(d, snap)
			TestKit.eq(d.coins, 1000)
			TestKit.eq(d.inventory.BrownCap, 5)
			TestKit.eq(d.inventory.NewSpecies, nil)
			TestKit.eq(d.inventoryByCategory.substrates.Compost, 3)
			TestKit.eq(d.inventoryByCategory.cosmetics, nil)
		end)
		TestKit.test("no-op when snapshot is nil", function()
			local d = freshData()
			Exchange.restoreFromSnapshot(d, nil)
			TestKit.eq(d.coins, 1000)
		end)
	end)

	TestKit.describe("Exchange.applyOneSided", function()
		TestKit.test("subtracts give items + coins, adds receive items + coins", function()
			local d = freshData()
			-- Give: 2 BrownCap + 50 coins. Receive: 1 Compost + 100 coins.
			Exchange.applyOneSided(d,
				{ coins = 50, items = { BrownCap = 2 } },
				{ coins = 100, items = { Compost = 1 } })
			TestKit.eq(d.coins, 1000 - 50 + 100)                  -- 1050
			TestKit.eq(d.inventory.BrownCap, 3)                    -- 5 - 2
			TestKit.eq(d.inventoryByCategory.substrates.Compost, 4) -- 3 + 1
		end)
		TestKit.test("routes mushroom species to inventory; non-species to inventoryByCategory", function()
			local d = freshData()
			-- Receive a mushroom AND a non-mushroom in the same call
			Exchange.applyOneSided(d,
				{ coins = 0, items = {} },
				{ coins = 0, items = { BrownCap = 2, CrystalShard = 1 } })
			TestKit.eq(d.inventory.BrownCap, 7)                    -- 5 + 2
			TestKit.eq(d.inventoryByCategory.tools.CrystalShard, 2) -- 1 + 1
		end)
		TestKit.test("no-op on empty give/receive", function()
			local d = freshData()
			Exchange.applyOneSided(d,
				{ coins = 0, items = {} },
				{ coins = 0, items = {} })
			TestKit.eq(d.coins, 1000)
			TestKit.eq(d.inventory.BrownCap, 5)
		end)
		TestKit.test("creates inventoryByCategory bucket if receive lands in a previously-missing category", function()
			local d = freshData()
			d.inventoryByCategory.tools = nil  -- delete the bucket
			Exchange.applyOneSided(d,
				{ coins = 0, items = {} },
				{ coins = 0, items = { CrystalShard = 1 } })
			TestKit.eq(d.inventoryByCategory.tools.CrystalShard, 1)
		end)
	end)

	TestKit.describe("Exchange.buildAuditEntry", function()
		TestKit.test("returns a table with kind, timestamp, and shallow-merged payload", function()
			local entry = Exchange.buildAuditEntry("trade", { sessionId = "abc", outcome = "completed" })
			TestKit.eq(entry.kind, "trade")
			TestKit.truthy(type(entry.timestamp) == "number")
			TestKit.eq(entry.sessionId, "abc")
			TestKit.eq(entry.outcome, "completed")
		end)
		TestKit.test("kind discrimination: different kinds, same payload shape", function()
			local trade = Exchange.buildAuditEntry("trade", { sessionId = "x" })
			local stall = Exchange.buildAuditEntry("stall_purchase", { listingId = "y", sellerUserId = 42 })
			TestKit.eq(trade.kind, "trade")
			TestKit.eq(stall.kind, "stall_purchase")
			TestKit.eq(stall.sellerUserId, 42)
		end)
		TestKit.test("asserts kind is a string", function()
			TestKit.errors(function() Exchange.buildAuditEntry(nil, {}) end)
			TestKit.errors(function() Exchange.buildAuditEntry(123, {}) end)
		end)
	end)

end
