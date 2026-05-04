---
phase: 02-closed-beta-social-systems-content
plan: 02a
type: execute
wave: 2a
depends_on: ["02-01"]
files_modified:
  - src/server/Stall.luau
  - src/server/PlotAnchors.luau
  - src/server/PendingMutations.luau
  - src/server/Tests/StallSpec.luau
  - src/server/Tests/PlotAnchorsSpec.luau
  - src/server/Tests/PendingMutationsSpec.luau
  - src/server/Tests/RunTests.server.luau
autonomous: true
requirements:
  # Closes the pure-logic half of P2-STALL-04, P2-STALL-05.
  # P2-STALL-01..03, 06 are closed elsewhere (01 by 02b+03, 02-03 by 04, 06 by 01).
  - P2-STALL-04-pure
  - P2-STALL-05-pure

must_haves:
  truths:
    - "Stall.luau exports the full pure-helper API specified in `<interfaces>` below — every helper takes plain `data` tables (no Player references, no Roblox calls). Roblox-bound wiring lives in PLAN 02b."
    - "PlotAnchors exports assign(claimedSet) (returns lowest unclaimed tile id or nil for OUT_OF_PLOTS) + tileIdToPosition(tileId) (returns Vector3 derived from Constants.STALL.cottagesZoneOrigin + grid math). Both are pure."
    - "PendingMutations exports write/peek/drain/_reset. write is Roblox-bound (DataStore SetAsync inside pcall); peek + drain take a `loadedQueue` table for testability. The Roblox PlayerData.onPlayerAdded hook in PLAN 02b calls drain via a thin Roblox-bound wrapper."
    - "All three new test specs land and run via TestKit. New test count delta: ~30 tests (StallSpec ~20, PlotAnchorsSpec ~5, PendingMutationsSpec ~5)."
    - "MAILBOX_FULL semantics per D-20: Stall.cancelListing returns (true, 'OK') even on overflow; sets data.stalls.mailbox.overflowNotice; the items go to audit-log-only via PLAN 02b's writeAudit call."
    - "Stall.canBuy is a separate exported helper (W-8 lock): self-purchase rejection lives here, not in handler. Required, not 'recommended'."
    - "Audit kind taxonomy locked (W-9): exactly these 7 kinds, no more, no fewer — stall_purchase, stall_create, stall_cancel, stall_expire, mailbox_overflow, stall_featured_rented, stall_mailbox_claim."
  artifacts:
    - path: "src/server/Stall.luau"
      provides: "Pure helpers ONLY in this plan (no start, no remote handlers — those land in PLAN 02b)"
      exports: ["canCreateListing", "canCancelListing", "canBuy", "executeBuy", "cancelListing", "expirySweep", "sweepFeaturedExpiry", "canRentFeatured", "claimMailbox", "browseDirectory", "recordRecentSale", "newListingId"]
      min_lines: 250
    - path: "src/server/PlotAnchors.luau"
      provides: "Pure tile-assignment helpers"
      exports: ["assign", "tileIdToPosition", "isAssigned"]
      min_lines: 40
    - path: "src/server/PendingMutations.luau"
      provides: "Pending mutations queue per D-19 (offline-seller mutation pattern)"
      exports: ["write", "peek", "drain", "_reset"]
      min_lines: 80
    - path: "src/server/Tests/StallSpec.luau"
      provides: "~20 tests covering all pure helpers + MAILBOX_FULL fallback (D-20) + audit kind taxonomy (W-9)"
      min_lines: 300
    - path: "src/server/Tests/PlotAnchorsSpec.luau"
      provides: "~5 tests: assign happy path (lowest free), assign already-claimed no-op, assign OUT_OF_PLOTS at 64, tileIdToPosition formula, isAssigned membership"
      min_lines: 50
    - path: "src/server/Tests/PendingMutationsSpec.luau"
      provides: "~5 tests: write+peek round-trip, drain applies all + clears queue, drain ordering (snapshotMicroseconds asc), drain pcall on bad mutation leaves rest intact, online vs offline branch decision via mock player table"
      min_lines: 60
  key_links:
    - from: "src/server/Stall.luau"
      to: "src/server/Exchange.luau"
      via: "require + applyOneSided in executeBuy"
      pattern: "Exchange%.applyOneSided"
    - from: "src/server/PendingMutations.luau"
      to: "DataStoreService"
      via: "GetDataStore('MyceliaStallPendingMutations_v1') lazy init"
      pattern: "MyceliaStallPendingMutations_v1"
---

<objective>
Land all the pure logic for Player Stalls — Stall.luau (helpers only, no start), PlotAnchors.luau (tile assignment), PendingMutations.luau (D-19 offline-seller queue). Three new spec files with ~30 tests covering everything. Roblox-bound wiring (start, remote handlers, sweeper task, drain hook) lands in PLAN 02b.

Splitting 02 into 02a + 02b per plan-checker B-3 (Plan 02 had 11+ sub-features in one task; the budget allows ~5).
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/02-closed-beta-social-systems-content/02-CONTEXT.md
@.planning/phases/02-closed-beta-social-systems-content/02-01-PLAN.md
@CLAUDE.md
@docs/specs/player-stalls.md
@src/server/Exchange.luau
@src/server/Trade.luau
@src/server/Inventory.luau
@src/shared/Constants.luau
@src/shared/Species.luau
@src/server/Tests/TradeSpec.luau
@src/server/Tests/TestKit.luau

<interfaces>
<!-- All function signatures the executor MUST honor. -->

```luau
-- src/server/Stall.luau (PURE HELPERS ONLY in this plan)

-- Generate a server-side UUID per CD-1.
function Stall.newListingId(): string

-- Validation matrix entry per D-15 + spec §97-111.
-- listing = { itemId, qty, unitPrice }; checks slot count, inventory, tradability, price bounds.
-- Returns: (ok: bool, code: string).
function Stall.canCreateListing(data, listing): (boolean, string)

-- Owner-only cancel check.
function Stall.canCancelListing(data, listingId, callerUserId): (boolean, string)

-- Self-purchase + listing-existence + buyer-affordability check (W-8 lock — separate export, not folded into executeBuy).
-- Returns: (ok: bool, code: string).
function Stall.canBuy(buyerUserId, sellerUserId, buyerData, listing): (boolean, string)

-- Atomic buy: mutates buyerData (subtract coins, add items via Exchange.applyOneSided)
-- and returns a sellerMutation record describing what to apply to the seller.
-- Caller (PLAN 02b) routes the sellerMutation through StallMutations.applyToSeller
-- which branches online (PlayerData.update) vs offline (PendingMutations.write).
-- Returns: (ok: bool, code: string, sellerMutation: table?).
function Stall.executeBuy(buyerData, sellerData, listingId, qty, buyerUserId, sellerUserId): (boolean, string, table?)

-- D-20: silent fallback. Returns (true, "OK") even on overflow.
-- Sets data.stalls.mailbox.overflowNotice = { count, since } when overflow happens.
-- Returns: (ok, code, overflowItems table?). overflowItems is non-nil when mailbox was full;
-- caller (PLAN 02b) writes those to audit log via Exchange.writeAudit({ kind = "mailbox_overflow", ... }).
function Stall.cancelListing(data, listingId, callerUserId): (boolean, string, table?)

-- Pure scan: returns list of expired listing ids (now > expiresAt).
-- Caller iterates and calls cancelListing-equivalent per id (which writes to mailbox).
function Stall.expirySweep(data, now): { string }

-- Pure scan over a registry table: returns list of seller userIds whose featured rental ended.
-- Registry shape: { [userId] = { featuredRentExpiresAt = number } } — caller assembles from in-memory + recent profiles.
function Stall.sweepFeaturedExpiry(registry, now): { number }

-- Featured row rental check.
-- featuredRowState = { occupiedSlots = { [slotIndex] = userId }, [userId] = featuredRentExpiresAt }
-- Returns: (ok, code, slotIndex?). slotIndex is the assigned lowest-unoccupied index on success.
function Stall.canRentFeatured(callerData, featuredRowState, now): (boolean, string, number?)

-- D-20: claimMailbox MUST reset overflowNotice = nil as part of the same atomic mutation.
-- Returns: (claimedCoins, claimedItems, ok). Caller wraps in PlayerData.update.
function Stall.claimMailbox(data): (number, table, boolean)

-- Browse: iterates a registry of featured sellers, returns directory rows.
-- Each row: { sellerUserId, sellerName, listingCount, plotPosition: Vector3 } (B-6: plotPosition included).
function Stall.browseDirectory(featuredRegistry): { table }

-- Append a sale entry to data.stalls.mailbox.sales, trim to last 50.
function Stall.recordRecentSale(data, saleEntry)
```

```luau
-- src/server/PlotAnchors.luau (NEW)

-- Assign the lowest unclaimed tile id from the given claimedSet (table of { ["tile_NN"] = true }).
-- Returns: tileId string ("tile_01".."tile_64") or nil if all 64 are claimed (caller raises OUT_OF_PLOTS).
function PlotAnchors.assign(claimedSet): string?

-- Derive world position from tile id using Constants.STALL.cottagesZoneOrigin + grid math.
-- Tile naming: tile_NN where N is 1..64 in row-major order across the 8x8 grid.
function PlotAnchors.tileIdToPosition(tileId): Vector3

-- Boolean check.
function PlotAnchors.isAssigned(claimedSet, tileId): boolean
```

```luau
-- src/server/PendingMutations.luau (NEW per D-19)

-- Mutation record schema:
--   { kind = "stall_sale" | "expiry_clear_featured" | "expiry_listing_to_mailbox",
--     listingId?, coinsEarned?, soldAt?, buyerName?, itemId?, qty?,
--     snapshotMicroseconds = os.clock() * 1e6 (for ordering during drain) }

-- Roblox-bound: DataStore SetAsync (read-modify-append-write inside pcall).
-- Idempotent merge: appends to the array under sellerUserId's key.
function PendingMutations.write(sellerUserId: number, mutation: table): boolean

-- Test seam: returns the in-memory queue contents (or nil if not loaded).
function PendingMutations.peek(sellerUserId: number): { table }?

-- Apply each pending mutation to a loaded `data.stalls`. Pure: takes a list of mutations
-- (caller fetches from DataStore) + a data table; mutates in place.
-- Returns: (appliedCount, errors: { string }).
-- Order: chronological by snapshotMicroseconds.
function PendingMutations.drain(data, mutations): (number, { string })

-- Test-only: clear in-memory cache.
function PendingMutations._reset()
```

**Audit kind taxonomy (W-9 — locked):**
Exactly 7 values: `stall_purchase`, `stall_create`, `stall_cancel`, `stall_expire`, `mailbox_overflow`, `stall_featured_rented`, `stall_mailbox_claim`. Document at the top of Stall.luau as `Stall.AUDIT_KINDS` table for executor reference.

**B-2 wiring note (for PLAN 02b consumption):**
The expirySweep + sweepFeaturedExpiry return only IDs/userIds. PLAN 02b's sweeper task is responsible for: (a) iterating each result, (b) for online sellers using PlayerData.update directly, (c) for offline sellers writing to PendingMutations.write. The pure helpers in this plan don't know about Roblox state.

</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write the three new modules + their TestKit specs (TDD)</name>
  <files>src/server/Stall.luau, src/server/PlotAnchors.luau, src/server/PendingMutations.luau, src/server/Tests/StallSpec.luau, src/server/Tests/PlotAnchorsSpec.luau, src/server/Tests/PendingMutationsSpec.luau, src/server/Tests/RunTests.server.luau</files>
  <behavior>
    **TDD: write specs FIRST, then the modules to make them pass.** Pattern: `src/server/Tests/TradeSpec.luau`.

    StallSpec coverage (~20 tests):
    1. canCreateListing happy path (slot available, item in inventory, valid price, tradable)
    2. canCreateListing SLOT_FULL (4 listings already)
    3. canCreateListing INSUFFICIENT_INVENTORY (item not in inventory)
    4. canCreateListing INVALID_PRICE — zero, negative, fractional, > 1e9
    5. canCreateListing ITEM_NOT_TRADABLE (Constants.ITEMS[id].tradable = false)
    6. canBuy happy path (different seller, listing exists, buyer can afford)
    7. canBuy SELF_PURCHASE (buyerUserId == sellerUserId)
    8. canBuy LISTING_GONE (listingId not in seller's listings)
    9. canBuy INSUFFICIENT_COINS
    10. executeBuy happy path — buyer coins down, items in inventory; sellerMutation has correct shape (kind=stall_sale, coinsEarned, listingId, etc.)
    11. executeBuy mushroom species → buyer.inventory; non-mushroom → buyer.inventoryByCategory
    12. cancelListing happy — listing removed, items in mailbox, returns (true, "OK", nil overflow)
    13. cancelListing MAILBOX_FULL FALLBACK (D-20) — pre-fill mailbox to 100 unique ids, cancel a 101st distinct item, verify returns (true, "OK", overflowItems table) AND data.stalls.mailbox.overflowNotice is set
    14. cancelListing NOT_OWNER — different callerUserId
    15. claimMailbox — coins added to claimedCoins, items returned, mailbox reset (coins=0, items={}, sales preserved, overflowNotice=nil per D-20)
    16. expirySweep returns expired listing ids (now > expiresAt) and skips fresh ones
    17. sweepFeaturedExpiry returns expired userIds from a mock registry
    18. canRentFeatured happy — returns slotIndex 1 when row empty
    19. canRentFeatured ALREADY_FEATURED — caller's featuredRentExpiresAt > now
    20. canRentFeatured FEATURED_FULL — 12 slots occupied
    + bonus: browseDirectory shape includes plotPosition (B-6)
    + bonus: recordRecentSale trims to 50 entries

    PlotAnchorsSpec (~5 tests):
    1. assign happy — empty set returns "tile_01"
    2. assign skips claimed — { tile_01=true, tile_03=true } returns "tile_02"
    3. assign OUT_OF_PLOTS — all 64 claimed returns nil
    4. tileIdToPosition formula — tile_01 = origin + Vector3(0,0,0); tile_02 = origin + Vector3(spacing,0,0); tile_09 = origin + Vector3(0,0,spacing)
    5. isAssigned membership

    PendingMutationsSpec (~5 tests):
    1. drain happy — mutations apply in chronological order; data.stalls reflects all changes; (count, []) returned
    2. drain ordering — input mutations with mixed snapshotMicroseconds, drain applies in ascending order
    3. drain pcall isolation — one bad mutation (e.g., kind="unknown") doesn't block the others; appliedCount excludes the failed one
    4. peek round-trip via _reset (test-only seam)
    5. mutation kinds covered — stall_sale increments mailbox.coins + adds to sales; expiry_clear_featured nils featuredRentExpiresAt; expiry_listing_to_mailbox removes listing + adds to mailbox.items
  </behavior>
  <action>
    1. Write the three test specs first (TDD). Use TradeSpec.luau as the format reference; freshData() helper at the top with the v3 shape including data.stalls per PLAN 01's D-13 default.

    2. Write Stall.luau implementing every export. Key implementation notes:
       - require Exchange, Inventory, Constants, Species (for byId routing).
       - newListingId: `HttpService:GenerateGUID(false)` (CD-1).
       - canCreateListing: count active listings (table size of data.stalls.listings); reject if ≥ Constants.STALL.slotCount. Walk validation in spec §97-111 order. Use Trade.hasItem-equivalent logic for inventory check (mushroom species → Inventory.count(data.inventory, itemId); non-mushroom → data.inventoryByCategory[def.category][itemId]).
       - executeBuy: build a give = { coins = unitPrice * qty, items = {} }, receive = { coins = 0, items = { [itemId] = qty } }; call Exchange.applyOneSided(buyerData, give, receive). Build sellerMutation = { kind = "stall_sale", listingId, coinsEarned = unitPrice * qty, soldAt = os.time(), buyerName, itemId, qty, snapshotMicroseconds = os.clock() * 1e6 }. Return (true, "OK", sellerMutation).
       - cancelListing: route items to mailbox via Stall._addToMailbox helper. _addToMailbox checks current unique-id count: if at cap (Constants.STALL.mailboxItemIdCap = 100) AND new item not already in mailbox → set overflowNotice += 1 count and return overflowItems for caller's audit-log routing. Else add normally.
       - claimMailbox: snapshot coins + items, reset both, reset overflowNotice = nil, return.
       - expirySweep: iterate data.stalls.listings, collect ids where now > expiresAt.
       - sweepFeaturedExpiry: iterate registry, collect userIds where now > featuredRentExpiresAt.
       - canRentFeatured: count occupied slots, find lowest unoccupied (1..12), return slot index.
       - browseDirectory: iterate featuredRegistry, return rows with plotPosition (resolved via PlotAnchors.tileIdToPosition).
       - At the top of the module: `Stall.AUDIT_KINDS = { "stall_purchase", "stall_create", "stall_cancel", "stall_expire", "mailbox_overflow", "stall_featured_rented", "stall_mailbox_claim" }`.

    3. Write PlotAnchors.luau:
       - assign(claimedSet): for i=1..64 do local tileId = string.format("tile_%02d", i); if not claimedSet[tileId] then return tileId end; return nil
       - tileIdToPosition(tileId): parse i from tileId, derive (col, row) from i (1-indexed); return Constants.STALL.cottagesZoneOrigin + Vector3.new((col-1) * spacing, 0, (row-1) * spacing) where col = ((i-1) % gridSize) + 1, row = floor((i-1) / gridSize) + 1, spacing = Constants.STALL.plotGridSpacing.
       - isAssigned: just `claimedSet[tileId] == true`.

    4. Write PendingMutations.luau:
       - DataStoreService:GetDataStore("MyceliaStallPendingMutations_v1") lazy init at top.
       - write(userId, mutation): pcall-wrapped UpdateAsync (read-modify-append-write to preserve concurrent appends from other servers). On failure, log warning + return false. Mutation must have snapshotMicroseconds field; assert if missing.
       - peek(userId): returns the in-memory copy if loaded, else nil. Pure-test seam.
       - drain(data, mutations): sort by snapshotMicroseconds asc; iterate; per-kind dispatch; pcall each mutation application; collect errors as { "i: msg" } strings; return (appliedCount, errors). Apply per-kind logic:
         - stall_sale: data.stalls.mailbox.coins += coinsEarned; recordRecentSale(data, { listingId, soldAt, buyerName, itemId, qty, coinsEarned })
         - expiry_clear_featured: data.stalls.featuredRentExpiresAt = nil
         - expiry_listing_to_mailbox: remove from data.stalls.listings[listingId]; add items to mailbox via the same _addToMailbox path
       - _reset(): clear in-memory cache (used by tests only).

    5. Update src/server/Tests/RunTests.server.luau to register the three new specs.

    6. Studio Play to verify: open output, expect "Tests complete: BASELINE + ~30 passed, 0 failed" where BASELINE was captured in PLAN 01.
  </action>
  <success-criteria>
    - All 3 new modules + 3 new specs land
    - All ~30 new tests pass; existing test count unchanged
    - No Roblox-bound code (no PlayerData.update, no remote firing, no RemoteEvent connections) in any of the 3 new modules — except DataStore in PendingMutations.write which is pcall-wrapped
    - `Stall.AUDIT_KINDS` table present at top of Stall.luau
  </success-criteria>
  <how-to-verify>
    1. `rojo serve default.project.json` from project root, ensure Studio is connected.
    2. Press Play in Studio.
    3. Output panel should print: `Tests complete: <BASELINE+~30> passed, 0 failed`. Compare to PLAN 01's BASELINE+11 to confirm delta is ~30.
    4. Open the Workspace via Explorer; confirm no new world objects (this plan is pure-logic only).
    5. Stop Play.
  </how-to-verify>
</task>

<task type="checkpoint">
  <name>Task 2: User checkpoint — PLAN 02a verification</name>
  <action>Stop. Surface to user: "PLAN 02a complete — Stall pure helpers + PlotAnchors + PendingMutations land + ~30 tests passing. Ready for PLAN 02b (Roblox-bound start, remote handlers, sweeper task, drain hook)?" Wait for go-ahead before proceeding to 02b.</action>
</task>

</tasks>

<summary_template_hook>
After execution, write SUMMARY at .planning/phases/02-closed-beta-social-systems-content/02-02a-SUMMARY.md.
Key items to surface to PLAN 02b:
- The exact sellerMutation shape executeBuy returns
- The exact mailbox.overflowNotice shape (for PLAN 04 banner UI)
- Any deviation from D-19's mutation kinds (stall_sale + 2 expiry kinds — confirm or note additions)
- Whether BASELINE+11+30 = expected count, or whether some test was deferred
</summary_template_hook>
