# Player Stalls — Spec

The player-driven storefront economy. Each player gets a personal stall on their plot anchor; a daily-rented featured row in the Trading Post zone gives sellers central foot traffic + entry to a searchable Plot Directory. Listings are fixed-price only in v1 and persist asynchronously via DataStore — buyers can purchase from offline sellers, and earnings collect in a per-player mailbox claimed at next login.

The second pillar of Phase 2's social economy (the first being the Trading Post). Reuses the atomic-execute + audit-log primitives from [trading-post.md](trading-post.md), refactored into a shared `Exchange.luau` core. Pairs with a forthcoming `remote-api.md` section for the wire-level remote contract.

---

## Architectural decisions (confirmed 2026-05-03)

1. **Hybrid placement.** Each player has a free personal stall on a per-player plot anchor. Trading Post zone hosts a separate physical row of 12 featured slots, rented daily for 200 coins. Personal stall is always-on; featured slot is the discoverability lever. *Rationale: pure central-row leaves personal plots empty; pure personal-only leaves the central zone empty. Hybrid covers both.*
2. **Async sales via mailbox.** Listings persist in DataStore. Items leave inventory at list time (escrow). Anyone can buy from any active listing regardless of seller presence. Sale proceeds collect in `data.stalls.mailbox`, claimed on next login. *Rationale: matches DESIGN.md's "daily check-in habit" target and keeps the trade economy warm during low-concurrency Closed Beta.*
3. **Fixed-price only in v1; auctions deferred.** Single listing kind keeps the loop testable. Save-schema and listing shape leave room for `kind = "auction"` + `bids` + `expiresAt` in a future commit with no rework. *Rationale: ROADMAP §89 calls for auctions but cozy-genre liquidity is unproven; ship the simpler half first.*
4. **Tight tunables.** 4 listing slots per stall · 48-hour listing expiry · 12 featured slots · 200 coin/day featured fee · 1 featured slot per account. Gamepass hooks (`Bigger Stall`, `Featured Discount`) designed-in via Constants but not wired. *Rationale: 4 slots forces curation (cozy depth); 48h cycle creates daily-relist ritual aligned with mailbox-claim ritual.*
5. **Discovery is gated to featured row.** Plot Directory UI shows featured-row sellers only + a global recent-activity feed (last 20 sales). Personal-only stalls are word-of-mouth / physical-visit discoverable. *Rationale: makes the featured fee meaningfully purchase discoverability, not just foot traffic; preserves cozy "wander to find" feel.*
6. **Shared Exchange core.** New `src/server/Exchange.luau` owns snapshot/restore, atomic mutation, and audit log writes. Both `Trade.luau` (refactored) and `Stall.luau` (new) consume it. Audit log entries gain a `kind` field (`"trade"` | `"stall_purchase"`). *Rationale: third caller arrives in Phase 3 LiveOps trading events per [trading-post.md §176](trading-post.md); two callers already justify extraction.*

---

## Module map

```
src/server/
  Exchange.luau               NEW — snapshotData, restoreFromSnapshot, applyOneSided, writeAudit
  Trade.luau                  REFACTOR — call into Exchange; remove duplicated helpers; preserve public API
  Stall.luau                  NEW — listing CRUD, browse, buy, mailbox, expiry sweeper, featured rental
  PlotAnchors.luau            NEW — assign/lookup per-player plot tile (foundation for Phase 3 huts)
  Tests/
    ExchangeSpec.luau         NEW — pure helpers (one-sided apply + audit shape)
    StallSpec.luau            NEW — listing validation, mailbox accumulation, featured FIFO, expiry sweep
    TradeSpec.luau            UPDATE — refactor tests to consume Exchange where applicable; behavior unchanged
src/client/
  StallUI.client.luau         NEW — three modes (owner, buyer, directory)
src/shared/
  Constants.luau              ADD — STALL config block, MERCHANTS.StallManager
  Remotes (added)             CreateListing, CancelListing, BuyListing, RentFeaturedSlot,
                              ClaimMailbox, BrowseDirectory, OpenStallOwnerUI, OpenStallBuyerUI,
                              StallTransactionCompleted, MailboxUpdated
src/server/MapSetup.luau      ADD — buildStallManager, buildFeaturedRowStalls (12 anchored Parts in TP zone),
                              buildPlotAnchorGrid (64 tiles in the Cottages zone, claimed lazily on first stall interaction)
```

---

## Save schema additions (additive to v3)

```lua
data.stalls = {
    plotAnchorId = "tile_07",            -- assigned lazily on first stall interaction; nil until then; stable per player once assigned
    listings = {                          -- max 4 active
        [listingId] = {
            itemId = "BrownCap",          -- mushroom species id OR Constants.ITEMS id
            qty = 5,
            unitPrice = 12,               -- coins per unit; min 1, max 1e9
            listedAt = 1717000000,        -- os.time() at creation
            expiresAt = 1717172800,       -- listedAt + 48h
            featured = false,             -- mirrored from data.stalls.featuredRentExpiresAt at list time
        }
    },
    mailbox = {
        coins = 0,                        -- accumulated sale proceeds
        items = { [itemId] = qty },       -- returned-unsold + cancelled-listing items
        sales = {                         -- recent activity for owner UI; last 50 trimmed FIFO
            { listingId, soldAt, buyerName, itemId, qty, coinsEarned }
        },
    },
    featuredRentExpiresAt = nil,          -- os.time() expiry; nil = not in featured row
}
```

`listingId` is a UUID generated server-side on create. Stable across listing's lifetime. Featured-row participation is a *seller-level* attribute (`featuredRentExpiresAt`), not per-listing — when rented, *all* of that seller's listings appear in the featured row + Plot Directory.

**Migration:** v3→v3 additive. Default `data.stalls = { plotAnchorId = nil, listings = {}, mailbox = { coins = 0, items = {}, sales = {} }, featuredRentExpiresAt = nil }`. `plotAnchorId` is assigned lazily on first stall interaction (not on join, to avoid burning anchor IDs on players who never engage).

---

## Listing state machine

```
       CreateListing                    BuyListing
   ────────────────────►  Active  ────────────────────►  Sold
                            │              (proceeds → mailbox.coins)
                            │
                            ├─────  CancelListing  ─────►  Cancelled
                            │                          (items → mailbox.items)
                            │
                            └─────  48h elapses  ───────►  Expired
                                                       (items → mailbox.items)
```

All terminal transitions are **DataStore-persisted** via `PlayerData.update`. No in-memory-only state for listings (unlike Trade sessions, which are ephemeral negotiations).

---

## Validation matrix

| Check | Where | Error code |
|---|---|---|
| Listing slot available (≤ 4 active) | CreateListing | `SLOT_FULL` |
| Item exists in caller inventory | CreateListing | `INSUFFICIENT_INVENTORY` |
| Item is tradable (`Constants.ITEMS[id].tradable ~= false` for non-species) | CreateListing | `ITEM_NOT_TRADABLE` |
| `unitPrice` is positive integer ≤ 1e9 | CreateListing | `INVALID_PRICE` |
| `qty` is positive integer | CreateListing | `INVALID_REQUEST` |
| Listing exists + still Active | BuyListing | `LISTING_GONE` |
| Buyer has `unitPrice * qty` coins | BuyListing | `INSUFFICIENT_COINS` |
| Buyer ≠ seller | BuyListing | `SELF_PURCHASE` |
| Caller owns the listing | CancelListing | `NOT_OWNER` |
| Returned items would exceed seller mailbox 100-id cap | CancelListing, expirySweep | `MAILBOX_FULL` (falls through to audit-only — see [Mailbox model](#mailbox-model)) |
| Caller has 200 coins for featured | RentFeaturedSlot | `INSUFFICIENT_COINS` |
| Featured row not at 12 slots | RentFeaturedSlot | `FEATURED_FULL` |
| Caller doesn't already hold a featured slot | RentFeaturedSlot | `ALREADY_FEATURED` |

---

## Atomic execution (BuyListing)

Reuses the snapshot-rollback pattern from Trade, refactored through `Exchange.applyOneSided`:

1. Server fetches listing from seller's `data.stalls.listings[listingId]`. If missing → `LISTING_GONE`.
2. Re-validate buyer can afford `unitPrice * qty`. If not → `INSUFFICIENT_COINS`.
3. Snapshot buyer's data + seller's `data.stalls`.
4. **Mutate buyer:** subtract `unitPrice * qty` coins, add `qty` of `itemId` to correct inventory bucket (mushroom species → `data.inventory`; non-mushroom → `data.inventoryByCategory[category]`).
5. **Mutate seller:** delete `listings[listingId]`, add `unitPrice * qty` to `mailbox.coins`, prepend a sale entry to `mailbox.sales` (trim to 50).
6. If step 5 fails: restore buyer from snapshot. Log audit failure. Return `MUTATION_FAILED`.
7. On success: write audit entry (`kind = "stall_purchase"`), fire `StallTransactionCompleted` to buyer, fire `MailboxUpdated` to seller (only if seller is online — otherwise picked up at next login from saved data).

The seller mutation is **DataStore-persistent**, not in-memory: it goes through `PlayerData.update` regardless of seller's online state. ProfileService handles the "seller offline" case — their Profile is loaded from DataStore, mutated, saved back without an active session. *(Verify: ProfileService API for offline-profile mutation. If API requires session ownership, fall back to a pending-mutations queue keyed on `userId` that the player picks up next time their Profile loads.)*

---

## Mailbox model

`data.stalls.mailbox` is a write-only-by-system inbox. Player claims via `ClaimMailbox` remote, which atomically:
1. Reads current mailbox contents.
2. Adds `coins` to `data.coins`.
3. Routes `items` into the correct inventory bucket (species → `data.inventory`; non-species → `data.inventoryByCategory[category]`).
4. Resets mailbox to `{ coins = 0, items = {} }`. `sales` array is preserved (it's the activity feed, not an inbox).

If routing fails partway (extreme edge case — capacity overflow on a category bucket), the mailbox is left intact and the failure is reported. No partial claims. The recent-sales feed is purely informational and never blocks a claim.

**Mailbox cap:** to bound DataStore size, mailbox is hard-capped at 100 unique item ids (coins are uncapped). When a returned-unsold listing would exceed the cap, the items are silently merged into the audit log only (player gets a notification on next claim: "3 listings returned to audit log — mailbox was full"). Coins always accumulate. *Rationale: ultra-rare; only triggers if a player has 100+ stale unsold returned listings without claiming, which means they're not playing actively anyway.*

---

## Featured row allocation

12 anchored stall Models in the Trading Post zone (positions defined in `Constants.STALL.featuredRowPositions`). Each rental is an independent 24-hour cycle — no global daily reset.

**Allocation:** FIFO continuous. The first `RentFeaturedSlot` call to find an unoccupied slot succeeds. When all 12 slots are occupied, calls return `FEATURED_FULL` until an existing rental's 24h expires and the expiry sweeper frees its slot.

**Per-account cap:** 1 featured slot at a time. `featuredRentExpiresAt` enforces — if `os.time() < featuredRentExpiresAt`, `RentFeaturedSlot` returns `ALREADY_FEATURED`.

**Slot assignment:** when a player rents, they're assigned the lowest-indexed unoccupied slot. The physical stall Model at that index displays their name + listings via `SurfaceGui`. Slot identity is opaque to the player — they can't pick "stall #3."

**Expiry:** 24 hours after rental. At expiry sweeper tick, the seller's `featuredRentExpiresAt` is cleared and the physical stall reverts to "Available" state. Listings stay active (just no longer featured / in directory).

**Renewal:** a seller whose 24h has elapsed can immediately fire `RentFeaturedSlot` again to renew. They're likely to get the same slot back (lowest-indexed unoccupied; the sweeper just freed theirs), but no guarantee — if 12 other sellers raced in between expiry and renewal, the renewing seller waits.

---

## Plot anchors (foundation for Phase 3 huts)

Minimal v1: an 8×8 grid of plot tiles in a dedicated **Cottages zone** west of spawn (precise coordinates set in `Constants.STALL.cottagesZoneOrigin`). Each tile is a 16×16 stud square with a placeholder Part marking it. On a player's first stall interaction (`OpenStallOwnerUI` from any Stall Manager NPC), `PlotAnchors.assign(player)` claims the lowest unclaimed tile and writes `data.stalls.plotAnchorId = "tile_NN"`.

The player's personal stall renders as a stand Model on their assigned tile. Anyone can walk up to it and trigger the buyer UI via ProximityPrompt. Tile assignment is permanent for the player.

**Capacity:** Phase 2 ships with **64 tiles** (8×8 grid). Solo project, Closed Beta — likely fits under any realistic CCU. When tiles run out, `PlotAnchors.assign` returns `OUT_OF_PLOTS`; UI shows "Plot system at capacity, please contact the developer." When this becomes real, the fix is either a bigger grid or per-server tile pools.

**Phase 3 transition:** the hut interior system replaces the placeholder Part with a real hut Model on the same tile. `plotAnchorId` is the persistent key; the visual representation is what changes. No save-data migration needed.

---

## Anti-griefing

- **Inventory escrow at list time.** Items physically leave `data.inventory` / `data.inventoryByCategory` at `CreateListing`. Cannot list-then-trade-away. Cancel/expire returns to mailbox (not directly to inventory).
- **Atomic buy.** Snapshot-rollback per Exchange core. Buyer can't lose coins without receiving items; seller's listing can't decrement without coin credit to mailbox.
- **Rate limits.** `CreateListing` 1/3s per player. `BuyListing` 1/1s per player. `RentFeaturedSlot` 1/60s. Server-side; UI throttles below these.
- **Price bounds.** `unitPrice` ∈ [1, 1e9]. Prevents both 0-coin troll listings (which would be weird but harmless) and integer-overflow griefing.
- **Mailbox bounds.** 100 unique item ids cap; coins uncapped. See [Mailbox model](#mailbox-model) for fallback behavior.
- **Self-purchase blocked.** `BuyListing` rejects when buyer == seller. Prevents wash trading.
- **No price-discovery scraping bots.** Only featured listings are exposed to the Plot Directory; personal-only listings are physical-visit only. Bounds the "list every item, scrape global prices" attack surface.
- **Audit log on every state transition.** Create / Cancel / Expire / Sold all write to `MyceliaAuditLog_v1` with `kind = "stall_*"`. Manual review surface for exploit forensics.

---

## UI surface

### Stall Manager NPC (Trading Post zone)

New dialogue tree (`Dialogues.StallManager`). Three response branches at greeting:
- **"Manage my stall"** → fires `OpenStallOwnerUI` to client.
- **"Rent a featured slot"** → confirms 200-coin fee, fires `RentFeaturedSlot`. Server response routes to a toast.
- **"Open my mailbox"** → fires `OpenStallOwnerUI` to client with mailbox tab pre-selected.

Plus standard lore + endDialogue responses per existing dialogue patterns.

### Stall Owner UI (modal, opened from Stall Manager or own stall ProximityPrompt)

Three tabs: **Listings · Mailbox · Featured**.

- **Listings tab:** 4 slot grid. Each slot shows item icon + qty + unitPrice + time-left bar (out of 48h). Add button on empty slots → item picker submodal (reuses Trade's pattern: filter by tradable, qty stepper, unit-price input). Cancel button on filled slots → confirms then cancels.
- **Mailbox tab:** displays accumulated `coins` + `items` with a single "Claim All" button. Below: scrolling activity feed (`sales` array) — "[2026-05-03 14:22] Alice bought 5× Brown Cap for 60 coins."
- **Featured tab:** if not featured, shows "Rent featured slot for 200 coins/day" button. If featured, shows "Featured for Xh Ym remaining" + listings auto-shown to the global Plot Directory.

### Stall Buyer UI (modal, opened from another player's stall ProximityPrompt)

Reuses the Shop UI buy-tab pattern. Header shows seller's username. Listings rendered as rows: item icon + name + qty available + unit price + total + "Buy" button. Buy fires `BuyListing(listingId, qty)` and shows a confirmation toast on success.

If the seller has zero active listings, modal shows "This stall is empty."

### Plot Directory UI (HUD button "Marketplace", opens from anywhere)

Two tabs: **Featured · Recent Sales**.

- **Featured tab:** scrollable list of all sellers currently in the featured row (≤ 12). Each row: seller name + listing count + "Visit Stall" button (teleports the player's `HumanoidRootPart.CFrame` to the seller's plot tile per [ADR 001](../decisions/001-biome-architecture.md) single-place teleport pattern — *not* `TeleportService`) + "Quick Buy" button (opens the seller's listings inline as a buyer modal — same as physical visit, no teleport).
- **Recent Sales tab:** chronological feed of the last 20 sales globally. Each row: "[time-ago] Alice bought 5× Brown Cap from Bob for 60 coins." Pure informational, no actions.

The directory is gated to featured-row sellers — personal-only stalls don't appear. *Rationale: featured fee buys discoverability.*

---

## Tests (`Tests/StallSpec.luau` + `Tests/ExchangeSpec.luau`)

Pure helpers covered:

**ExchangeSpec (~8 tests):**
- `Exchange.applyOneSided(data, give, receive)` — coin deltas, item routing per bucket, no-op on empty give/receive, defensive against missing `inventoryByCategory`.
- `Exchange.snapshotData` / `Exchange.restoreFromSnapshot` round-trip — coins + inventory + inventoryByCategory all restored exactly.
- Audit entry shape: required fields, `kind` discrimination.

**StallSpec (~17 tests):**
- `Stall.canCreateListing(data, listing)` — happy path, slot-cap rejection, insufficient-inventory rejection, invalid-price rejection (zero, negative, fractional, > 1e9), non-tradable item rejection.
- `Stall.executeBuy(buyerData, sellerData, listingId, qty)` — happy path (full quantity), insufficient-coins rejection, listing-gone rejection, self-purchase rejection.
- `Stall.cancelListing(data, listingId)` — items return to mailbox, listing removed, mailbox cap respected.
- `Stall.expirySweep(data, now)` — listings past `expiresAt` move to mailbox, fresh ones untouched.
- `Stall.canRentFeatured(data, featuredRowState, now)` — happy, already-featured rejection, insufficient-coins rejection, featured-full rejection.
- `Stall.claimMailbox(data)` — coins added, items routed to correct buckets, sales array preserved, mailbox reset.
- `PlotAnchors.assign(claimedSet)` — happy (lowest free), already-assigned no-op, out-of-plots rejection.
- Mailbox cap behavior: cancel a listing when mailbox at cap → falls through to audit-only path.

**Roblox-bound side** (DataStore writes, ProximityPrompt dispatch, UI rendering, offline seller mutation) — Studio integration tests, not unit. Documented as Studio verification steps in HANDOFF.

---

## Future-proofing

- **Auctions (Phase 2 fast-follow).** Add `kind` field to listings: `"fixed"` (current) | `"auction"`. Auction listings carry `bids = {}` + `minBid`. Bid escrow reuses Exchange.applyOneSided. Auction expiry sweeper extends the existing Stall expiry sweeper. ~1 weekend of work; schema is ready.
- **LiveOps trading events (Phase 3).** Per [trading-post.md §176](trading-post.md), Exchange's audit-log shape with `kind` is the LiveOps event hook. Trading-event lotteries are a third caller of `Exchange.applyOneSided` with `kind = "trade_event_lottery"`.
- **Hut integration (Phase 3).** PlotAnchors is the foundation. Phase 3 hut system replaces the placeholder Part at `plotAnchorId` with a Hut Model + interior; stall stand becomes a hut decoration. No save-data migration.
- **Spatial Voice in marketplaces (Phase 3 polish).** When a buyer enters a featured stall's ProximityPrompt range, server can flip a chat channel attribute scoped to seller+buyer. Independent system.
- **Bigger Stall + Featured Discount gamepasses (Phase 3 monetization).** `Constants.STALL.slotCount` and `Constants.STALL.featuredFee` are the only knobs; each gamepass is a 2-line lookup against `data.gamepassesOwned` at the right call site.

---

## Open follow-ups (not in v1)

- ~~**ProfileService offline-mutation API.**~~ **RESOLVED 2026-05-03** via planning round (D-19): pending-mutations queue chosen. Implementation routes offline-seller buys through a new `MyceliaStallPendingMutations_v1` DataStore + `PendingMutations.drain(player)` hook in `PlayerData.onPlayerAdded`. See `.planning/phases/02-closed-beta-social-systems-content/02-CONTEXT.md` D-19 for full contract.
- **Plot anchor visual polish.** v1 is placeholder Parts. Real plot tiles (boundary fences, "your plot" sign) is a polish pass.
- **Stall stand visual polish.** v1 reuses the wood-crate merchant stall pattern. Real stall Models with thatch roofs, hanging signs, etc. ship when assets ship.
- **Mailbox notification on next login.** v1: mailbox shows in Stall Manager UI when player walks up. Polish: HUD toast on join "You have N coins waiting in your stall mailbox."
- **Plot Directory pagination.** v1: ≤12 featured sellers fit on one screen. If featured row expands beyond 12, add pagination.

---

*Last touched: 2026-05-03. Status: design complete; implementation pending writing-plans skill output.*
