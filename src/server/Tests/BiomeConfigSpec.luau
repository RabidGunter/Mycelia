-- Tests for Constants.BIOMES integrity + Travel pure helpers.
-- Roblox-bound code (RequestBiomeTravel handler, character teleport) is
-- exercised by playtest in Studio.
--
-- Spec: docs/specs/biome-config.md.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Travel = require(ServerScriptService.Server.Travel)

return function()
	TestKit.describe("Constants.BIOMES — schema integrity", function()
		TestKit.test("StarterGlade exists with the expected base unlock (0)", function()
			TestKit.truthy(Constants.BIOMES.StarterGlade ~= nil, "StarterGlade missing")
			TestKit.eq(Constants.BIOMES.StarterGlade.unlockRenown, 0)
		end)

		TestKit.test("MistyHollow exists as the Phase 1 second biome", function()
			TestKit.truthy(Constants.BIOMES.MistyHollow ~= nil, "MistyHollow missing")
			TestKit.eq(Constants.BIOMES.MistyHollow.unlockRenown, 100)
		end)

		TestKit.test("every biome has all required fields", function()
			local required = {
				"id", "displayName", "description",
				"unlockRenown", "unlockOrder",
				"zoneCenter", "zoneRadius", "spawnPoint", "plotOrigin",
				"npcPositions",
				"wildSpawnArea", "wildSpawnTable", "wildSpawnCap", "wildSpawnInterval",
				"atmosphere", "lightingOverride",
				"ambientMusicAssetId", "ambientLoopAssetId",
				"availableSubstrates", "weatherDistribution", "travelCostCoins",
			}
			for biomeId, config in pairs(Constants.BIOMES) do
				for _, field in ipairs(required) do
					TestKit.truthy(config[field] ~= nil,
						string.format("biome %s missing field: %s", biomeId, field))
				end
			end
		end)

		TestKit.test("biome id matches its key", function()
			for biomeId, config in pairs(Constants.BIOMES) do
				TestKit.eq(config.id, biomeId)
			end
		end)

		TestKit.test("unlockOrder values are unique", function()
			local seen = {}
			for biomeId, config in pairs(Constants.BIOMES) do
				TestKit.truthy(seen[config.unlockOrder] == nil,
					string.format("duplicate unlockOrder %d (in %s and %s)",
						config.unlockOrder, biomeId, tostring(seen[config.unlockOrder])))
				seen[config.unlockOrder] = biomeId
			end
		end)

		TestKit.test("every wildSpawnTable entry references a known species id", function()
			for biomeId, config in pairs(Constants.BIOMES) do
				for _, speciesId in ipairs(config.wildSpawnTable) do
					TestKit.truthy(Species.byId[speciesId] ~= nil,
						string.format("biome %s references unknown species %s", biomeId, speciesId))
				end
			end
		end)

		TestKit.test("weatherDistribution sums to ~1.0 per biome", function()
			for biomeId, config in pairs(Constants.BIOMES) do
				local total = 0
				for _, p in pairs(config.weatherDistribution) do
					total = total + p
				end
				TestKit.truthy(math.abs(total - 1.0) < 0.001,
					string.format("biome %s weatherDistribution sums to %.3f, not 1.0", biomeId, total))
			end
		end)

		TestKit.test("zoneRadius is positive", function()
			for biomeId, config in pairs(Constants.BIOMES) do
				TestKit.truthy(config.zoneRadius > 0, biomeId .. " has non-positive zoneRadius")
			end
		end)

		TestKit.test("travelCostCoins is non-negative", function()
			for biomeId, config in pairs(Constants.BIOMES) do
				TestKit.truthy(config.travelCostCoins >= 0,
					biomeId .. " has negative travelCostCoins")
			end
		end)

		TestKit.test("StarterGlade's travelCostCoins is 0 (you don't pay to come home)", function()
			TestKit.eq(Constants.BIOMES.StarterGlade.travelCostCoins, 0)
		end)
	end)

	TestKit.describe("Travel.totalRenown", function()
		TestKit.test("returns 0 for nil data", function()
			TestKit.eq(Travel.totalRenown(nil), 0)
		end)

		TestKit.test("returns 0 for data with no reputation", function()
			TestKit.eq(Travel.totalRenown({}), 0)
			TestKit.eq(Travel.totalRenown({ reputation = {} }), 0)
		end)

		TestKit.test("sums scores across NPCs", function()
			local data = {
				reputation = {
					ForestWitch = { score = 80 },
					OldHermit   = { score = 30 },
					Alchemist   = { score = 0 },
				},
			}
			TestKit.eq(Travel.totalRenown(data), 110)
		end)

		TestKit.test("missing score field defaults to 0 (defensive)", function()
			local data = { reputation = { Witch = {} } }
			TestKit.eq(Travel.totalRenown(data), 0)
		end)
	end)

	TestKit.describe("Travel.canTravel", function()
		TestKit.test("rejects unknown biome id", function()
			local data = { coins = 1000, reputation = {} }
			local ok, reason = Travel.canTravel(data, "Atlantis")
			TestKit.eq(ok, false)
			TestKit.eq(reason, "unknownBiome")
		end)

		TestKit.test("StarterGlade is always travelable (renown 0, cost 0)", function()
			local data = { coins = 0, reputation = {} }
			local ok = Travel.canTravel(data, "StarterGlade")
			TestKit.eq(ok, true)
		end)

		TestKit.test("MistyHollow rejected when renown too low", function()
			local data = {
				coins = 1000,
				reputation = { Witch = { score = 50 } },    -- need 100
			}
			local ok, reason = Travel.canTravel(data, "MistyHollow")
			TestKit.eq(ok, false)
			TestKit.eq(reason, "renownGate")
		end)

		TestKit.test("MistyHollow rejected when coins insufficient", function()
			local data = {
				coins = 10,    -- need 25
				reputation = { Witch = { score = 100 } },
			}
			local ok, reason = Travel.canTravel(data, "MistyHollow")
			TestKit.eq(ok, false)
			TestKit.eq(reason, "insufficientCoins")
		end)

		TestKit.test("MistyHollow accepted when renown + coins both meet thresholds", function()
			local data = {
				coins = 25,
				reputation = { Witch = { score = 60 }, Hermit = { score = 50 } },    -- 110
			}
			local ok, reason = Travel.canTravel(data, "MistyHollow")
			TestKit.eq(ok, true)
			TestKit.eq(reason, nil)
		end)
	end)
end
