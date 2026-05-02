-- Tests for the pure inventory math in ServerScriptService.Server.Inventory.
-- Inventory has no Roblox dependencies, so these run instantly and form
-- the cheapest regression net we have.

local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local Inventory = require(ServerScriptService.Server.Inventory)

return function()
	TestKit.describe("Inventory.count", function()
		TestKit.test("returns 0 for an empty inventory", function()
			TestKit.eq(Inventory.count({}, "BrownCap"), 0)
		end)

		TestKit.test("returns 0 for a missing species", function()
			TestKit.eq(Inventory.count({ FairyCup = 2 }, "BrownCap"), 0)
		end)

		TestKit.test("returns the stored count for a present species", function()
			TestKit.eq(Inventory.count({ BrownCap = 7 }, "BrownCap"), 7)
		end)
	end)

	TestKit.describe("Inventory.add", function()
		TestKit.test("adds 1 by default", function()
			local inv = {}
			Inventory.add(inv, "BrownCap")
			TestKit.eq(inv.BrownCap, 1)
		end)

		TestKit.test("accumulates on repeated adds", function()
			local inv = {}
			Inventory.add(inv, "BrownCap", 3)
			Inventory.add(inv, "BrownCap", 4)
			TestKit.eq(inv.BrownCap, 7)
		end)

		TestKit.test("does not affect other species", function()
			local inv = { FairyCup = 2 }
			Inventory.add(inv, "BrownCap", 5)
			TestKit.eq(inv.BrownCap, 5)
			TestKit.eq(inv.FairyCup, 2)
		end)

		TestKit.test("errors on non-positive amounts", function()
			TestKit.errors(function() Inventory.add({}, "BrownCap", 0) end)
			TestKit.errors(function() Inventory.add({}, "BrownCap", -1) end)
		end)
	end)

	TestKit.describe("Inventory.remove", function()
		TestKit.test("returns true when there's enough", function()
			local inv = { BrownCap = 5 }
			TestKit.eq(Inventory.remove(inv, "BrownCap", 2), true)
			TestKit.eq(inv.BrownCap, 3)
		end)

		TestKit.test("returns false when there isn't enough, and leaves inv unchanged", function()
			local inv = { BrownCap = 2 }
			TestKit.eq(Inventory.remove(inv, "BrownCap", 5), false)
			TestKit.eq(inv.BrownCap, 2)
		end)

		TestKit.test("returns false on missing species", function()
			local inv = { FairyCup = 1 }
			TestKit.eq(Inventory.remove(inv, "BrownCap", 1), false)
		end)

		TestKit.test("removes the key entirely when count hits zero", function()
			local inv = { BrownCap = 3 }
			Inventory.remove(inv, "BrownCap", 3)
			TestKit.eq(inv.BrownCap, nil)
		end)

		TestKit.test("errors on non-positive amounts", function()
			TestKit.errors(function() Inventory.remove({ BrownCap = 1 }, "BrownCap", 0) end)
			TestKit.errors(function() Inventory.remove({ BrownCap = 1 }, "BrownCap", -1) end)
		end)
	end)

	TestKit.describe("Inventory.isEmpty", function()
		TestKit.test("returns true on empty table", function()
			TestKit.eq(Inventory.isEmpty({}), true)
		end)

		TestKit.test("returns false when entries exist", function()
			TestKit.eq(Inventory.isEmpty({ BrownCap = 1 }), false)
		end)

		TestKit.test("returns true after removing the last item", function()
			local inv = { BrownCap = 1 }
			Inventory.remove(inv, "BrownCap", 1)
			TestKit.eq(Inventory.isEmpty(inv), true)
		end)
	end)

	TestKit.describe("Inventory.totalItems", function()
		TestKit.test("returns 0 on empty", function()
			TestKit.eq(Inventory.totalItems({}), 0)
		end)

		TestKit.test("sums counts across species", function()
			TestKit.eq(Inventory.totalItems({ BrownCap = 3, FairyCup = 4, Glowmoss = 1 }), 8)
		end)
	end)

	TestKit.describe("Inventory.species", function()
		TestKit.test("returns the list of present ids (any order)", function()
			local list = Inventory.species({ BrownCap = 1, FairyCup = 2 })
			table.sort(list)
			TestKit.eq(#list, 2)
			TestKit.eq(list[1], "BrownCap")
			TestKit.eq(list[2], "FairyCup")
		end)

		TestKit.test("returns empty list for empty inventory", function()
			TestKit.eq(#Inventory.species({}), 0)
		end)
	end)

	TestKit.describe("Inventory.clone", function()
		TestKit.test("produces a table with equal values", function()
			local original = { BrownCap = 3, FairyCup = 1 }
			local copy = Inventory.clone(original)
			TestKit.eq(copy.BrownCap, 3)
			TestKit.eq(copy.FairyCup, 1)
		end)

		TestKit.test("mutating the clone does not mutate the original", function()
			local original = { BrownCap = 3 }
			local copy = Inventory.clone(original)
			Inventory.add(copy, "BrownCap", 10)
			TestKit.eq(original.BrownCap, 3)
			TestKit.eq(copy.BrownCap, 13)
		end)
	end)
end
