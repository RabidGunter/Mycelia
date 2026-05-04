-- Tests for Stall.luau pure helpers (Wave 2a). Roblox-bound side
-- (Stall.start, remote handlers, sweeper task, ProximityPrompt routing) is
-- covered by Studio integration testing in Wave 2b.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local Stall = require(ServerScriptService.Server.Stall)
local Constants = require(ReplicatedStorage.Shared.Constants)

local function freshData()
	return {
		coins = 1000,
		inventory = { BrownCap = 5, Glowmoss = 1 },
		inventoryByCategory = {
			mushrooms_raw = {}, mushrooms_dried = {}, potions = {},
			spores = { BrownCapSpore = 2 }, substrates = { Compost = 3 }, additives = {},
			recipes = {}, spirit_items = {}, quest_items = {},
			cosmetics = {}, tools = { CrystalShard = 1 },
		},
		stalls = {
			plotAnchorId          = nil,
			listings              = {},
			mailbox = { coins = 0, items = {}, sales = {}, overflowNotice = nil },
			featuredRentExpiresAt = nil,
		},
	}
end

return function()

	TestKit.describe("Stall.canCreateListing", function()
		TestKit.test("happy path: slot free + item in inventory + valid price", function()
			local d = freshData()
			local ok, code = Stall.canCreateListing(d, { itemId = "BrownCap", qty = 2, unitPrice = 50 })
			TestKit.eq(ok, true)
			TestKit.eq(code, "OK")
		end)
		TestKit.test("SLOT_FULL when 4 listings already active", function()
			local d = freshData()
			for i = 1, Constants.STALL.slotCount do
				d.stalls.listings["fakeid_" .. i] = { itemId = "BrownCap", qty = 1, unitPrice = 1 }
			end
			local ok, code = Stall.canCreateListing(d, { itemId = "Glowmoss", qty = 1, unitPrice = 100 })
			TestKit.eq(ok, false)
			TestKit.eq(code, "SLOT_FULL")
		end)
		TestKit.test("INSUFFICIENT_INVENTORY when item not in inventory", function()
			local d = freshData()
			local ok, code = Stall.canCreateListing(d, { itemId = "BrownCap", qty = 99, unitPrice = 10 })
			TestKit.eq(ok, false)
			TestKit.eq(code, "INSUFFICIENT_INVENTORY")
		end)
		TestKit.test("INVALID_PRICE for zero, negative, fractional, > maxPrice", function()
			local d = freshData()
			TestKit.eq(({Stall.canCreateListing(d, { itemId = "BrownCap", qty = 1, unitPrice = 0 })})[2],   "INVALID_PRICE")
			TestKit.eq(({Stall.canCreateListing(d, { itemId = "BrownCap", qty = 1, unitPrice = -5 })})[2],  "INVALID_PRICE")
			TestKit.eq(({Stall.canCreateListing(d, { itemId = "BrownCap", qty = 1, unitPrice = 1.5 })})[2], "INVALID_PRICE")
			TestKit.eq(({Stall.canCreateListing(d, { itemId = "BrownCap", qty = 1, unitPrice = 1e10 })})[2], "INVALID_PRICE")
		end)
		TestKit.test("INVALID_REQUEST for fractional or non-positive qty", function()
			local d = freshData()
			TestKit.eq(({Stall.canCreateListing(d, { itemId = "BrownCap", qty = 0,    unitPrice = 5 })})[2], "INVALID_REQUEST")
			TestKit.eq(({Stall.canCreateListing(d, { itemId = "BrownCap", qty = -1,   unitPrice = 5 })})[2], "INVALID_REQUEST")
			TestKit.eq(({Stall.canCreateListing(d, { itemId = "BrownCap", qty = 1.5,  unitPrice = 5 })})[2], "INVALID_REQUEST")
		end)
	end)

	TestKit.describe("Stall.canBuy", function()
		TestKit.test("happy path", function()
			local buyer = freshData()
			local ok, code = Stall.canBuy(1, 2, buyer, { unitPrice = 10, qty = 5 })
			TestKit.eq(ok, true)
			TestKit.eq(code, "OK")
		end)
		TestKit.test("SELF_PURCHASE when buyer == seller", function()
			local buyer = freshData()
			local ok, code = Stall.canBuy(1, 1, buyer, { unitPrice = 10, qty = 1 })
			TestKit.eq(ok, false)
			TestKit.eq(code, "SELF_PURCHASE")
		end)
		TestKit.test("LISTING_GONE when listing is nil", function()
			local buyer = freshData()
			local ok, code = Stall.canBuy(1, 2, buyer, nil)
			TestKit.eq(ok, false)
			TestKit.eq(code, "LISTING_GONE")
		end)
		TestKit.test("INSUFFICIENT_COINS when buyer can't afford total", function()
			local buyer = freshData()
			buyer.coins = 5
			local ok, code = Stall.canBuy(1, 2, buyer, { unitPrice = 10, qty = 1 })
			TestKit.eq(ok, false)
			TestKit.eq(code, "INSUFFICIENT_COINS")
		end)
	end)

	TestKit.describe("Stall.executeBuy", function()
		TestKit.test("happy path: subtracts buyer coins, adds items, returns sellerMutation", function()
			local buyer = freshData()
			local seller = freshData()
			seller.stalls.listings.lid001 = { itemId = "BrownCap", qty = 3, unitPrice = 20, listedAt = 1, expiresAt = 9999 }
			local ok, code, mut = Stall.executeBuy(buyer, seller, "lid001", 3, 100, 200, "AliceBuyer")
			TestKit.eq(ok, true)
			TestKit.eq(code, "OK")
			-- Buyer mutated
			TestKit.eq(buyer.coins, 1000 - 60)
			TestKit.eq(buyer.inventory.BrownCap, 5 + 3)
			-- Seller mutation record shape
			TestKit.eq(mut.kind, "stall_sale")
			TestKit.eq(mut.listingId, "lid001")
			TestKit.eq(mut.coinsEarned, 60)
			TestKit.eq(mut.itemId, "BrownCap")
			TestKit.eq(mut.qty, 3)
			TestKit.eq(mut.buyerName, "AliceBuyer")
			TestKit.truthy(type(mut.snapshotMicroseconds) == "number")
		end)
		TestKit.test("LISTING_GONE when listingId not in seller's listings", function()
			local buyer = freshData()
			local seller = freshData()
			local ok, code = Stall.executeBuy(buyer, seller, "nonexistent", 1, 1, 2, "x")
			TestKit.eq(ok, false)
			TestKit.eq(code, "LISTING_GONE")
		end)
		TestKit.test("non-mushroom item routes to inventoryByCategory bucket", function()
			local buyer = freshData()
			local seller = freshData()
			seller.stalls.listings.lid002 = { itemId = "Compost", qty = 2, unitPrice = 5, listedAt = 1, expiresAt = 9999 }
			local ok = Stall.executeBuy(buyer, seller, "lid002", 2, 100, 200, "x")
			TestKit.eq(ok, true)
			TestKit.eq(buyer.inventoryByCategory.substrates.Compost, 3 + 2)
		end)
	end)

	TestKit.describe("Stall.cancelListing", function()
		TestKit.test("happy path: listing removed, items in mailbox, no overflow", function()
			local d = freshData()
			d.stalls.listings.lid001 = { itemId = "BrownCap", qty = 3, unitPrice = 10, listedAt = 1, expiresAt = 9999 }
			local ok, code, overflow = Stall.cancelListing(d, "lid001")
			TestKit.eq(ok, true)
			TestKit.eq(code, "OK")
			TestKit.eq(overflow, nil)
			TestKit.eq(d.stalls.listings.lid001, nil)
			TestKit.eq(d.stalls.mailbox.items.BrownCap, 3)
		end)
		TestKit.test("LISTING_GONE when listingId doesn't exist", function()
			local d = freshData()
			local ok, code = Stall.cancelListing(d, "nope")
			TestKit.eq(ok, false)
			TestKit.eq(code, "LISTING_GONE")
		end)
		TestKit.test("D-20 silent fallback: mailbox at cap returns overflow + sets overflowNotice + still removes listing", function()
			local d = freshData()
			-- Pre-fill mailbox to cap (100 unique ids)
			for i = 1, Constants.STALL.mailboxItemIdCap do
				d.stalls.mailbox.items["fakeId_" .. i] = 1
			end
			d.stalls.listings.lid001 = { itemId = "BrandNewItem", qty = 7, unitPrice = 10, listedAt = 1, expiresAt = 9999 }
			local ok, code, overflow = Stall.cancelListing(d, "lid001")
			TestKit.eq(ok, true)             -- D-20: succeeds even on overflow
			TestKit.eq(code, "OK")
			TestKit.truthy(overflow)
			TestKit.eq(overflow.BrandNewItem, 7)
			TestKit.truthy(d.stalls.mailbox.overflowNotice)
			TestKit.eq(d.stalls.mailbox.overflowNotice.count, 1)
			TestKit.eq(d.stalls.listings.lid001, nil)  -- listing still removed
		end)
	end)

	TestKit.describe("Stall.expirySweep + sweepFeaturedExpiry", function()
		TestKit.test("expirySweep returns ids of listings past expiresAt; skips fresh ones", function()
			local d = freshData()
			d.stalls.listings.fresh   = { itemId = "BrownCap", qty = 1, unitPrice = 10, listedAt = 1000, expiresAt = 5000 }
			d.stalls.listings.expired = { itemId = "BrownCap", qty = 1, unitPrice = 10, listedAt = 100,  expiresAt = 200 }
			local list = Stall.expirySweep(d, 1000)
			TestKit.eq(#list, 1)
			TestKit.eq(list[1], "expired")
		end)
		TestKit.test("sweepFeaturedExpiry returns userIds whose featured rental ended", function()
			local registry = {
				[1] = { featuredRentExpiresAt = 100 },   -- expired
				[2] = { featuredRentExpiresAt = 5000 },  -- fresh
				[3] = { featuredRentExpiresAt = 200 },   -- expired
			}
			local list = Stall.sweepFeaturedExpiry(registry, 1000)
			table.sort(list)
			TestKit.eq(#list, 2)
			TestKit.eq(list[1], 1)
			TestKit.eq(list[2], 3)
		end)
	end)

	TestKit.describe("Stall.canRentFeatured", function()
		TestKit.test("happy path: returns slot 1 when row empty + caller has fee", function()
			local d = freshData()
			local ok, code, slot = Stall.canRentFeatured(d, { occupiedSlots = {} }, 1000, 1)
			TestKit.eq(ok, true)
			TestKit.eq(code, "OK")
			TestKit.eq(slot, 1)
		end)
		TestKit.test("INSUFFICIENT_COINS when caller can't afford fee", function()
			local d = freshData()
			d.coins = Constants.STALL.featuredFee - 1
			local ok, code = Stall.canRentFeatured(d, { occupiedSlots = {} }, 1000, 1)
			TestKit.eq(ok, false)
			TestKit.eq(code, "INSUFFICIENT_COINS")
		end)
		TestKit.test("ALREADY_FEATURED when caller's featuredRentExpiresAt is in the future", function()
			local d = freshData()
			d.stalls.featuredRentExpiresAt = 5000
			local ok, code = Stall.canRentFeatured(d, { occupiedSlots = {} }, 1000, 1)
			TestKit.eq(ok, false)
			TestKit.eq(code, "ALREADY_FEATURED")
		end)
		TestKit.test("FEATURED_FULL when all 12 slots occupied", function()
			local d = freshData()
			local occupied = {}
			for i = 1, Constants.STALL.featuredSlotCount do occupied[i] = 999 + i end
			local ok, code = Stall.canRentFeatured(d, { occupiedSlots = occupied }, 1000, 1)
			TestKit.eq(ok, false)
			TestKit.eq(code, "FEATURED_FULL")
		end)
		TestKit.test("returns lowest unoccupied slot when partially full", function()
			local d = freshData()
			local occupied = { [1] = 100, [2] = 200, [4] = 400 }
			local ok, _, slot = Stall.canRentFeatured(d, { occupiedSlots = occupied }, 1000, 1)
			TestKit.eq(ok, true)
			TestKit.eq(slot, 3)
		end)
	end)

	TestKit.describe("Stall.claimMailbox", function()
		TestKit.test("claims coins + items, resets mailbox + overflowNotice, preserves sales", function()
			local d = freshData()
			d.stalls.mailbox.coins = 250
			d.stalls.mailbox.items = { BrownCap = 4, Compost = 2 }
			d.stalls.mailbox.sales = { { listingId = "x", soldAt = 100 } }
			d.stalls.mailbox.overflowNotice = { count = 3, since = 50 }

			local claimedCoins, claimedItems, ok = Stall.claimMailbox(d)
			TestKit.eq(ok, true)
			TestKit.eq(claimedCoins, 250)
			TestKit.eq(claimedItems.BrownCap, 4)
			-- Coins added to player balance
			TestKit.eq(d.coins, 1000 + 250)
			-- BrownCap routed to legacy inventory; Compost to inventoryByCategory.substrates
			TestKit.eq(d.inventory.BrownCap, 5 + 4)
			TestKit.eq(d.inventoryByCategory.substrates.Compost, 3 + 2)
			-- Mailbox reset
			TestKit.eq(d.stalls.mailbox.coins, 0)
			TestKit.eq(next(d.stalls.mailbox.items), nil)
			TestKit.eq(d.stalls.mailbox.overflowNotice, nil)
			-- Sales feed preserved (it's the activity feed, not an inbox)
			TestKit.eq(#d.stalls.mailbox.sales, 1)
		end)
	end)

	TestKit.describe("Stall.recordRecentSale + browseDirectory", function()
		TestKit.test("recordRecentSale prepends entries, trims to 50", function()
			local d = freshData()
			for i = 1, 60 do
				Stall.recordRecentSale(d, { listingId = "id" .. i, soldAt = i })
			end
			TestKit.eq(#d.stalls.mailbox.sales, 50)
			-- Newest (id60) is first; oldest preserved 50 entries (id11..id60)
			TestKit.eq(d.stalls.mailbox.sales[1].listingId, "id60")
			TestKit.eq(d.stalls.mailbox.sales[50].listingId, "id11")
		end)
		TestKit.test("browseDirectory passes through valid entries (B-6: includes plotPosition)", function()
			local registry = {
				{ sellerUserId = 1, sellerName = "Alice", listingCount = 2, plotPosition = Vector3.new(-300, 0, 0) },
				{ sellerUserId = 2, sellerName = "Bob",   listingCount = 1, plotPosition = Vector3.new(-276, 0, 0) },
				{ malformed = "skipped" },  -- no sellerUserId → filtered out
			}
			local rows = Stall.browseDirectory(registry)
			TestKit.eq(#rows, 2)
			TestKit.eq(rows[1].sellerUserId, 1)
			TestKit.eq(rows[1].plotPosition.X, -300)
			TestKit.eq(rows[2].sellerName, "Bob")
		end)
	end)

	TestKit.describe("Stall.AUDIT_KINDS taxonomy", function()
		TestKit.test("locked at exactly 7 values (W-9)", function()
			TestKit.eq(#Stall.AUDIT_KINDS, 7)
			-- Spot-check three of them are present
			local set = {}
			for _, k in ipairs(Stall.AUDIT_KINDS) do set[k] = true end
			TestKit.truthy(set["stall_purchase"])
			TestKit.truthy(set["mailbox_overflow"])
			TestKit.truthy(set["stall_featured_rented"])
		end)
	end)

end
