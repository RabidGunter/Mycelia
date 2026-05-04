-- Tests for PendingMutations.luau — the offline-seller mutation queue (D-19).
-- Drain is the testable pure helper; write+peek covered via the in-memory
-- cache. The DataStore side is verified live in Studio.

local ServerScriptService = game:GetService("ServerScriptService")

local TestKit = require(script.Parent.TestKit)
local PendingMutations = require(ServerScriptService.Server.PendingMutations)

local function freshSellerData()
	return {
		coins = 100,
		inventory = {},
		inventoryByCategory = {
			mushrooms_raw = {}, mushrooms_dried = {}, potions = {},
			spores = {}, substrates = {}, additives = {}, recipes = {},
			spirit_items = {}, quest_items = {}, cosmetics = {}, tools = {},
		},
		stalls = {
			plotAnchorId          = "tile_05",
			listings              = {
				abc123 = { itemId = "BrownCap", qty = 5, unitPrice = 10, listedAt = 100, expiresAt = 200 },
			},
			mailbox = { coins = 0, items = {}, sales = {}, overflowNotice = nil },
			featuredRentExpiresAt = 9999,
		},
	}
end

return function()

	TestKit.describe("PendingMutations.drain", function()
		TestKit.test("stall_sale: adds coins to mailbox, prepends sale entry, removes listing", function()
			local data = freshSellerData()
			local mutations = {
				{
					kind = "stall_sale",
					listingId = "abc123",
					coinsEarned = 50,
					soldAt = 1000,
					buyerName = "Alice",
					itemId = "BrownCap",
					qty = 5,
					snapshotMicroseconds = 100,
				},
			}
			local applied, errors = PendingMutations.drain(data, mutations)
			TestKit.eq(applied, 1)
			TestKit.eq(#errors, 0)
			TestKit.eq(data.stalls.mailbox.coins, 50)
			TestKit.eq(#data.stalls.mailbox.sales, 1)
			TestKit.eq(data.stalls.mailbox.sales[1].buyerName, "Alice")
			TestKit.eq(data.stalls.listings.abc123, nil)
		end)

		TestKit.test("expiry_clear_featured: nils the featuredRentExpiresAt", function()
			local data = freshSellerData()
			local mutations = {
				{ kind = "expiry_clear_featured", snapshotMicroseconds = 100 },
			}
			PendingMutations.drain(data, mutations)
			TestKit.eq(data.stalls.featuredRentExpiresAt, nil)
		end)

		TestKit.test("expiry_listing_to_mailbox: removes listing + adds items to mailbox", function()
			local data = freshSellerData()
			local mutations = {
				{ kind = "expiry_listing_to_mailbox", listingId = "abc123", snapshotMicroseconds = 100 },
			}
			PendingMutations.drain(data, mutations)
			TestKit.eq(data.stalls.listings.abc123, nil)
			TestKit.eq(data.stalls.mailbox.items.BrownCap, 5)
		end)

		TestKit.test("ordering: applies in ascending snapshotMicroseconds even when input is mixed", function()
			local data = freshSellerData()
			-- Two stall_sale mutations; second has earlier microseconds.
			-- After both apply, mailbox.sales[1] should be the LATER one (newer-first prepend).
			local mutations = {
				{ kind = "stall_sale", listingId = "later",  coinsEarned = 200, soldAt = 2000, buyerName = "Bob",   itemId = "BrownCap", qty = 1, snapshotMicroseconds = 200 },
				{ kind = "stall_sale", listingId = "earlier", coinsEarned = 100, soldAt = 1000, buyerName = "Alice", itemId = "BrownCap", qty = 1, snapshotMicroseconds = 100 },
			}
			PendingMutations.drain(data, mutations)
			-- Both applied
			TestKit.eq(data.stalls.mailbox.coins, 300)
			-- Earlier sale (Alice) was applied first, so it's now sales[2]; later sale (Bob) is sales[1] (newer).
			TestKit.eq(data.stalls.mailbox.sales[1].buyerName, "Bob")
			TestKit.eq(data.stalls.mailbox.sales[2].buyerName, "Alice")
		end)

		TestKit.test("pcall isolation: bad mutation kind doesn't block the rest", function()
			local data = freshSellerData()
			local mutations = {
				{ kind = "bogus_kind", snapshotMicroseconds = 50 },
				{ kind = "stall_sale", listingId = "abc123", coinsEarned = 30, soldAt = 1000, buyerName = "OK", itemId = "BrownCap", qty = 5, snapshotMicroseconds = 100 },
			}
			local applied, errors = PendingMutations.drain(data, mutations)
			TestKit.eq(applied, 1)        -- only the stall_sale applied
			TestKit.eq(#errors, 1)        -- one error for the bogus kind
			TestKit.eq(data.stalls.mailbox.coins, 30)
		end)
	end)

	TestKit.describe("PendingMutations.peek + _reset", function()
		TestKit.test("peek returns cache contents after write; _reset clears", function()
			PendingMutations._reset()
			TestKit.eq(PendingMutations.peek(42), nil)
			-- Note: write() also tries to call DataStore which may or may not work
			-- in TestKit context. The cache populates regardless; that's what we test.
			PendingMutations.write(42, { kind = "stall_sale", coinsEarned = 10, snapshotMicroseconds = 1 })
			local q = PendingMutations.peek(42)
			TestKit.truthy(q)
			TestKit.eq(#q, 1)
			TestKit.eq(q[1].kind, "stall_sale")
			PendingMutations._reset()
			TestKit.eq(PendingMutations.peek(42), nil)
		end)
	end)

end
