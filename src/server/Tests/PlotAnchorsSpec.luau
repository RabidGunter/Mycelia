-- Tests for PlotAnchors.luau — pure tile assignment + position derivation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local PlotAnchors = require(ServerScriptService.Server.PlotAnchors)
local Constants = require(ReplicatedStorage.Shared.Constants)

return function()

	TestKit.describe("PlotAnchors.assign", function()
		TestKit.test("returns tile_01 when no tiles claimed", function()
			TestKit.eq(PlotAnchors.assign({}), "tile_01")
		end)
		TestKit.test("skips claimed tiles, returns lowest free", function()
			local claimed = { tile_01 = true, tile_02 = true, tile_04 = true }
			TestKit.eq(PlotAnchors.assign(claimed), "tile_03")
		end)
		TestKit.test("returns nil when all 64 tiles claimed (OUT_OF_PLOTS)", function()
			local claimed = {}
			for i = 1, 64 do claimed[string.format("tile_%02d", i)] = true end
			TestKit.eq(PlotAnchors.assign(claimed), nil)
		end)
	end)

	TestKit.describe("PlotAnchors.tileIdToPosition", function()
		TestKit.test("tile_01 sits at the cottages zone origin", function()
			local pos = PlotAnchors.tileIdToPosition("tile_01")
			local origin = Constants.STALL.cottagesZoneOrigin
			TestKit.eq(pos.X, origin.X)
			TestKit.eq(pos.Y, origin.Y)
			TestKit.eq(pos.Z, origin.Z)
		end)
		TestKit.test("tile_02 is one spacing east of tile_01 (col 2 row 1)", function()
			local pos = PlotAnchors.tileIdToPosition("tile_02")
			local origin = Constants.STALL.cottagesZoneOrigin
			TestKit.eq(pos.X, origin.X + Constants.STALL.plotGridSpacing)
			TestKit.eq(pos.Z, origin.Z)
		end)
		TestKit.test("tile_09 is one spacing south of tile_01 (col 1 row 2)", function()
			local pos = PlotAnchors.tileIdToPosition("tile_09")
			local origin = Constants.STALL.cottagesZoneOrigin
			TestKit.eq(pos.X, origin.X)
			TestKit.eq(pos.Z, origin.Z + Constants.STALL.plotGridSpacing)
		end)
		TestKit.test("tile_64 sits at the bottom-right corner (col 8 row 8)", function()
			local pos = PlotAnchors.tileIdToPosition("tile_64")
			local origin = Constants.STALL.cottagesZoneOrigin
			local expected = origin + Vector3.new(
				7 * Constants.STALL.plotGridSpacing,
				0,
				7 * Constants.STALL.plotGridSpacing
			)
			TestKit.eq(pos.X, expected.X)
			TestKit.eq(pos.Z, expected.Z)
		end)
		TestKit.test("returns nil for malformed tile id", function()
			TestKit.eq(PlotAnchors.tileIdToPosition("bogus"), nil)
			TestKit.eq(PlotAnchors.tileIdToPosition("tile_99"), nil)
		end)
	end)

	TestKit.describe("PlotAnchors.isAssigned", function()
		TestKit.test("returns true for claimed tiles, false otherwise", function()
			local claimed = { tile_01 = true, tile_05 = true }
			TestKit.eq(PlotAnchors.isAssigned(claimed, "tile_01"), true)
			TestKit.eq(PlotAnchors.isAssigned(claimed, "tile_02"), false)
			TestKit.eq(PlotAnchors.isAssigned(claimed, "tile_05"), true)
		end)
	end)

end
