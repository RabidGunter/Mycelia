-- Tests for Shop.luau — pure helpers only (priceFor, totalSellPrice, canSell,
-- canBuy, validateSell, validateBuy) plus Constants.MERCHANTS integrity.
--
-- Replaces the old SellingSpec. The witch-payout numeric pins from
-- SellingSpec are preserved here verbatim — Shop.totalSellPrice with the
-- ForestWitch merchant config is mathematically identical to the old
-- Selling.priceOf, so any drift in those numbers means a Species.baseSellPrice
-- or Tiers.sellMultiplier shift.
--
-- Hardcoded expected values from the data shipped on 2026-04-30 (Pre-Alpha):
--   BrownCap     base 3   tier Common    multiplier 1   ->   3
--   LatticeVeil  base 12  tier Uncommon  multiplier 2   ->  24
--   Glowmoss     base 50  tier Rare      multiplier 5   -> 250
--   CrystalCap   base 200 tier Epic      multiplier 12  -> 2400

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Shop = require(ServerScriptService.Server.Shop)

local witch = Constants.MERCHANTS.ForestWitch

return function()

	TestKit.describe("Shop.priceFor", function()
		TestKit.test("returns 0 for unknown id", function()
			TestKit.eq(Shop.priceFor(witch, "NotAMushroom"), 0)
		end)
		TestKit.test("returns 0 for malformed args", function()
			TestKit.eq(Shop.priceFor(nil, "BrownCap"), 0)
			TestKit.eq(Shop.priceFor(witch, ""), 0)
			TestKit.eq(Shop.priceFor(witch, 42 :: any), 0)
		end)
		TestKit.test("prices Common at base * 1 (BrownCap = 3)", function()
			TestKit.eq(Shop.priceFor(witch, "BrownCap"), 3)
		end)
		TestKit.test("applies Uncommon multiplier (LatticeVeil = 24)", function()
			TestKit.eq(Shop.priceFor(witch, "LatticeVeil"), 24)
		end)
		TestKit.test("applies Rare multiplier (Glowmoss = 250)", function()
			TestKit.eq(Shop.priceFor(witch, "Glowmoss"), 250)
		end)
		TestKit.test("applies Epic multiplier (CrystalCap = 2400)", function()
			TestKit.eq(Shop.priceFor(witch, "CrystalCap"), 2400)
		end)
		TestKit.test("respects merchant buyMultiplier (0.5x = halved)", function()
			local stingyWitch = { buyMultiplier = 0.5 }
			TestKit.eq(Shop.priceFor(stingyWitch, "BrownCap"), 1)        -- floor(3 * 0.5) = 1
			TestKit.eq(Shop.priceFor(stingyWitch, "Glowmoss"), 125)
		end)
	end)

	TestKit.describe("Shop.totalSellPrice", function()
		TestKit.test("returns 0 for empty request", function()
			TestKit.eq(Shop.totalSellPrice(witch, {}), 0)
		end)
		TestKit.test("scales linearly with count", function()
			TestKit.eq(Shop.totalSellPrice(witch, { BrownCap = 5 }), 15)
		end)
		TestKit.test("sums across species", function()
			-- 2 BrownCap (6) + 1 LatticeVeil (24) + 1 Glowmoss (250) = 280
			TestKit.eq(Shop.totalSellPrice(witch, {
				BrownCap = 2,
				LatticeVeil = 1,
				Glowmoss = 1,
			}), 280)
		end)
		TestKit.test("ignores unknown ids without crashing", function()
			TestKit.eq(Shop.totalSellPrice(witch, { NotAMushroom = 99 }), 0)
		end)
		TestKit.test("includes valid + skips unknown in same request", function()
			TestKit.eq(Shop.totalSellPrice(witch, {
				BrownCap = 1,
				NotAMushroom = 99,
			}), 3)
		end)
		TestKit.test("ignores zero/negative quantities defensively", function()
			TestKit.eq(Shop.totalSellPrice(witch, { BrownCap = 0 }), 0)
			TestKit.eq(Shop.totalSellPrice(witch, { BrownCap = -3 }), 0)
		end)
	end)

	TestKit.describe("Shop.canSell", function()
		TestKit.test("witch accepts mushroom species (mushrooms_raw)", function()
			TestKit.eq(Shop.canSell(witch, "BrownCap"), true)
			TestKit.eq(Shop.canSell(witch, "Glowmoss"), true)
		end)
		TestKit.test("rejects unknown ids", function()
			TestKit.eq(Shop.canSell(witch, "NotAMushroom"), false)
		end)
		TestKit.test("rejects when buyCategories doesn't include mushrooms_raw", function()
			local cosmeticOnly = { buyCategories = { "cosmetics" } }
			TestKit.eq(Shop.canSell(cosmeticOnly, "BrownCap"), false)
		end)
		TestKit.test("rejects malformed merchant", function()
			TestKit.eq(Shop.canSell(nil, "BrownCap"), false)
			TestKit.eq(Shop.canSell({}, "BrownCap"), false)
		end)
	end)

	TestKit.describe("Shop.canBuy", function()
		TestKit.test("returns false when itemsForSale is empty", function()
			TestKit.eq(Shop.canBuy(witch, "AnyItem"), false)
		end)
		TestKit.test("returns true for listed item", function()
			local seller = { itemsForSale = { Compost = { unitPrice = 5, category = "substrates" } } }
			TestKit.eq(Shop.canBuy(seller, "Compost"), true)
			TestKit.eq(Shop.canBuy(seller, "NotListed"), false)
		end)
	end)

	TestKit.describe("Shop.validateSell", function()
		TestKit.test("happy path: 5 BrownCap from inventory of 10", function()
			local ok, code, breakdown, total =
				Shop.validateSell(witch, { BrownCap = 5 }, { BrownCap = 10 })
			TestKit.eq(ok, true)
			TestKit.eq(code, "OK")
			TestKit.eq(total, 15)
			TestKit.eq(breakdown.BrownCap.qty, 5)
			TestKit.eq(breakdown.BrownCap.unit, 3)
			TestKit.eq(breakdown.BrownCap.sub, 15)
		end)
		TestKit.test("rejects empty request", function()
			local ok, code = Shop.validateSell(witch, {}, { BrownCap = 10 })
			TestKit.eq(ok, false)
			TestKit.eq(code, "INVALID_REQUEST")
		end)
		TestKit.test("rejects unknown item id", function()
			local ok, code = Shop.validateSell(witch, { Imaginary = 1 }, { Imaginary = 1 })
			TestKit.eq(ok, false)
			TestKit.eq(code, "UNKNOWN_ITEM")
		end)
		TestKit.test("rejects category not in buyCategories", function()
			local cosmetic = { buyCategories = { "cosmetics" }, buyMultiplier = 1 }
			local ok, code = Shop.validateSell(cosmetic, { BrownCap = 1 }, { BrownCap = 1 })
			TestKit.eq(ok, false)
			TestKit.eq(code, "CATEGORY_REJECTED")
		end)
		TestKit.test("rejects insufficient inventory", function()
			local ok, code = Shop.validateSell(witch, { BrownCap = 5 }, { BrownCap = 2 })
			TestKit.eq(ok, false)
			TestKit.eq(code, "INSUFFICIENT_INVENTORY")
		end)
		TestKit.test("rejects negative or fractional qty", function()
			local _, code1 = Shop.validateSell(witch, { BrownCap = -1 }, { BrownCap = 5 })
			TestKit.eq(code1, "INVALID_REQUEST")
			local _, code2 = Shop.validateSell(witch, { BrownCap = 1.5 }, { BrownCap = 5 })
			TestKit.eq(code2, "INVALID_REQUEST")
		end)
	end)

	TestKit.describe("Shop.validateBuy", function()
		local seller = {
			buyCategories = {},
			buyMultiplier = 1,
			itemsForSale = {
				Compost = { unitPrice = 10, category = "substrates" },
				Hardwood = { unitPrice = 25, category = "substrates" },
			},
		}
		TestKit.test("happy path: 2 Compost with sufficient coins", function()
			local ok, code, breakdown, total = Shop.validateBuy(seller, { Compost = 2 }, 100, {})
			TestKit.eq(ok, true)
			TestKit.eq(code, "OK")
			TestKit.eq(total, 20)
			TestKit.eq(breakdown.Compost.category, "substrates")
		end)
		TestKit.test("multi-item totals correctly", function()
			local ok, _, _, total =
				Shop.validateBuy(seller, { Compost = 1, Hardwood = 2 }, 100, {})
			TestKit.eq(ok, true)
			TestKit.eq(total, 60) -- 10 + 50
		end)
		TestKit.test("rejects unlisted item", function()
			local ok, code = Shop.validateBuy(seller, { Mystery = 1 }, 100, {})
			TestKit.eq(ok, false)
			TestKit.eq(code, "UNKNOWN_ITEM")
		end)
		TestKit.test("rejects insufficient coins", function()
			local ok, code = Shop.validateBuy(seller, { Hardwood = 5 }, 30, {})
			TestKit.eq(ok, false)
			TestKit.eq(code, "INSUFFICIENT_COINS")
		end)
		TestKit.test("rejects empty request", function()
			local _, code = Shop.validateBuy(seller, {}, 100, {})
			TestKit.eq(code, "INVALID_REQUEST")
		end)
	end)

	TestKit.describe("Shop with SubstrateDealer (real Phase 2 merchant)", function()
		local dealer = Constants.MERCHANTS.SubstrateDealer
		TestKit.test("SubstrateDealer is configured with substrates for sale", function()
			TestKit.truthy(dealer, "SubstrateDealer missing from MERCHANTS")
			TestKit.eq(Shop.canBuy(dealer, "Compost"), true)
			TestKit.eq(Shop.canBuy(dealer, "MagicalLoam"), true)
			TestKit.eq(Shop.canBuy(dealer, "BrownCap"), false) -- not for sale here
		end)
		TestKit.test("validateBuy: 3 Compost (15 coins) succeeds with 100", function()
			local ok, code, _, total = Shop.validateBuy(dealer, { Compost = 3 }, 100, {})
			TestKit.eq(ok, true)
			TestKit.eq(code, "OK")
			TestKit.eq(total, 15)
		end)
		TestKit.test("validateBuy: 1 MagicalLoam (500) rejects with 100 coins", function()
			local ok, code = Shop.validateBuy(dealer, { MagicalLoam = 1 }, 100, {})
			TestKit.eq(ok, false)
			TestKit.eq(code, "INSUFFICIENT_COINS")
		end)
		TestKit.test("dealer rejects mushroom species (not listed)", function()
			local ok, code = Shop.validateBuy(dealer, { BrownCap = 1 }, 100, {})
			TestKit.eq(ok, false)
			TestKit.eq(code, "UNKNOWN_ITEM")
		end)
		TestKit.test("dealer.canSell is false for everything (sell-only is one-way)", function()
			-- buyCategories is empty, so the dealer accepts no inventory categories.
			TestKit.eq(Shop.canSell(dealer, "BrownCap"), false)
			TestKit.eq(Shop.canSell(dealer, "Compost"), false)
		end)
	end)

	TestKit.describe("Shop with SporeMerchant", function()
		local sporer = Constants.MERCHANTS.SporeMerchant
		TestKit.test("sells the three Phase 2 spore samples", function()
			TestKit.eq(Shop.canBuy(sporer, "BrownCapSpore"), true)
			TestKit.eq(Shop.canBuy(sporer, "FairyCupSpore"), true)
			TestKit.eq(Shop.canBuy(sporer, "InkpotSpore"), true)
		end)
		TestKit.test("multi-spore Buy totals correctly", function()
			-- 2 BrownCapSpore (2 * 10 = 20) + 1 InkpotSpore (1 * 60 = 60) = 80
			local ok, _, _, total =
				Shop.validateBuy(sporer, { BrownCapSpore = 2, InkpotSpore = 1 }, 100, {})
			TestKit.eq(ok, true)
			TestKit.eq(total, 80)
		end)
	end)

	TestKit.describe("Constants.MERCHANTS integrity", function()
		TestKit.test("ForestWitch exists with required fields", function()
			TestKit.truthy(witch, "ForestWitch missing from MERCHANTS")
			TestKit.eq(type(witch.displayName), "string")
			TestKit.eq(type(witch.buyCategories), "table")
			TestKit.eq(type(witch.buyMultiplier), "number")
			TestKit.eq(type(witch.itemsForSale), "table")
		end)
		TestKit.test("MERCHANT_DEFAULTS provides talkRange + repPerCoin", function()
			TestKit.eq(type(Constants.MERCHANT_DEFAULTS.talkRange), "number")
			TestKit.eq(type(Constants.MERCHANT_DEFAULTS.repPerCoin), "number")
		end)
		TestKit.test("every merchant's buyCategories entries are real inventory keys", function()
			-- Build the set of valid v3 inventoryByCategory keys by introspecting
			-- the default save data. If a merchant references a category that
			-- doesn't exist in the schema, validateSell will silently never match.
			local PlayerData = require(ServerScriptService.Server.PlayerData)
			local default = PlayerData.defaultData()
			local validCategories = default.inventoryByCategory or {}
			for npcId, merchant in pairs(Constants.MERCHANTS) do
				for _, cat in ipairs(merchant.buyCategories or {}) do
					TestKit.truthy(validCategories[cat] ~= nil,
						string.format("Merchant %s buys category %s but it's not in inventoryByCategory schema", npcId, cat))
				end
			end
		end)
		TestKit.test("every itemsForSale.category is a real inventory key", function()
			local PlayerData = require(ServerScriptService.Server.PlayerData)
			local default = PlayerData.defaultData()
			local validCategories = default.inventoryByCategory or {}
			for npcId, merchant in pairs(Constants.MERCHANTS) do
				for itemId, listing in pairs(merchant.itemsForSale or {}) do
					TestKit.truthy(validCategories[listing.category] ~= nil,
						string.format("Merchant %s sells %s into category %s, not in schema", npcId, itemId, tostring(listing.category)))
				end
			end
		end)
		TestKit.test("every itemsForSale entry has a Constants.ITEMS definition", function()
			-- Cross-ref: merchant catalogues should only list items the game
			-- actually defines. Catches typos at startup.
			for npcId, merchant in pairs(Constants.MERCHANTS) do
				for itemId in pairs(merchant.itemsForSale or {}) do
					TestKit.truthy(Constants.ITEMS[itemId] ~= nil,
						string.format("Merchant %s sells %s but Constants.ITEMS[%s] is missing", npcId, itemId, itemId))
				end
			end
		end)
	end)

end
