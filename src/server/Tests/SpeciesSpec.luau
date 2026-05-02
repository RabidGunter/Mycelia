-- Sanity-check the species data table itself.
--
-- These tests don't validate gameplay behaviour — they validate that the
-- shape of the data is consistent. Easy to break by typo (e.g. mistyped
-- tier name, duplicated id), and easy to catch here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(script.Parent.TestKit)
local Species = require(ReplicatedStorage.Shared.Species)
local Tiers = require(ReplicatedStorage.Shared.Tiers)

return function()
	TestKit.describe("Species data", function()
		TestKit.test("has at least 15 entries (Pre-Alpha minimum)", function()
			TestKit.truthy(#Species.LIST >= 15,
				string.format("expected >= 15 species, got %d", #Species.LIST))
		end)

		TestKit.test("every id is unique", function()
			local seen = {}
			for _, sp in ipairs(Species.LIST) do
				TestKit.falsy(seen[sp.id], "duplicate species id: " .. tostring(sp.id))
				seen[sp.id] = true
			end
		end)

		TestKit.test("every species references a tier defined in Tiers.lua", function()
			for _, sp in ipairs(Species.LIST) do
				TestKit.truthy(Tiers[sp.tier],
					string.format("species %s has unknown tier %s", sp.id, tostring(sp.tier)))
			end
		end)

		TestKit.test("every species has positive baseSellPrice and growthTimeSeconds", function()
			for _, sp in ipairs(Species.LIST) do
				TestKit.truthy(sp.baseSellPrice > 0,
					string.format("%s.baseSellPrice must be > 0", sp.id))
				TestKit.truthy(sp.growthTimeSeconds > 0,
					string.format("%s.growthTimeSeconds must be > 0", sp.id))
			end
		end)

		TestKit.test("Species.byId resolves every LIST entry", function()
			for _, sp in ipairs(Species.LIST) do
				TestKit.eq(Species.byId[sp.id], sp,
					string.format("byId mismatch for %s", sp.id))
			end
		end)

		TestKit.test("Species.byTier covers every LIST entry exactly once", function()
			local found = {}
			for tier, list in pairs(Species.byTier) do
				TestKit.truthy(Tiers[tier], "byTier key not in Tiers: " .. tostring(tier))
				for _, sp in ipairs(list) do
					TestKit.falsy(found[sp.id],
						"species appears in byTier twice: " .. sp.id)
					found[sp.id] = true
				end
			end
			for _, sp in ipairs(Species.LIST) do
				TestKit.truthy(found[sp.id],
					"species missing from byTier: " .. sp.id)
			end
		end)
	end)

	TestKit.describe("Tiers data", function()
		TestKit.test("ORDER lists every defined tier", function()
			local inOrder = {}
			for _, name in ipairs(Tiers.ORDER) do
				inOrder[name] = true
			end
			for k, v in pairs(Tiers) do
				if k ~= "ORDER" and type(v) == "table" then
					TestKit.truthy(inOrder[k],
						"Tiers." .. k .. " is defined but missing from Tiers.ORDER")
				end
			end
		end)

		TestKit.test("sellMultiplier is monotonically non-decreasing along ORDER", function()
			local last = 0
			for _, name in ipairs(Tiers.ORDER) do
				local tier = Tiers[name]
				TestKit.truthy(tier.sellMultiplier >= last,
					string.format("%s.sellMultiplier (%s) is less than the previous tier's (%s)",
						name, tostring(tier.sellMultiplier), tostring(last)))
				last = tier.sellMultiplier
			end
		end)
	end)
end
