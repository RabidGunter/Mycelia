# Phase 2: Closed Beta — Player Stalls slice — Context

**Gathered:** 2026-05-03
**Status:** Ready for planning
**Source:** PRD Express Path — `docs/specs/player-stalls.md` (approved 2026-05-03 via brainstorming skill)

> **Scope notice:** This planning round covers the **Player Stalls sub-feature only** (requirements P2-STALL-01..06). Other Phase 2 sub-features are tracked separately:
> - **Already shipped:** Trading Post (P2-TRADE-01..04), Quest system (P2-QUEST-01..04), Dialogue (P2-DIAG-01..03), Shop UI partial (P2-SHOP-01..02), Visual Language (P2-VIS-01)
> - **Planned in future passes:** Co-op Expeditions (P2-EXP-01..05), 3 remaining secondary merchants (P2-SHOP-03), 15+ new species (P2-CONT-01), test gaps (P2-TEST-01..04)
>
> The planner MUST scope its output to P2-STALL-01..06 only. Do not plan tasks for other Phase 2 sub-features in this PLAN.

<domain>
## Phase Boundary

Player Stalls is the second pillar of Phase 2's social economy (the first being the Trading Post, shipped 2026-05-03). It enables async player-to-player commerce: each player gets a free personal storefront on a per-player plot anchor, and a daily-rented featured row of 12 stalls in the Trading Post zone gives sellers central foot traffic + entry to a searchable Plot Directory. Listings are fixed-price-only in v1 and persist asynchronously via DataStore — buyers can purchase from offline sellers, and earnings collect in a per-player mailbox claimed at next login.

The feature reuses atomic-execution + audit-log primitives from `Trade.luau` (shipped earlier same day), refactored into a shared `Exchange.luau` core. Both `Trade.luau` (refactor) and `Stall.luau` (new) consume the core.

**Out of scope for this slice:**
- Auctions (deferred to Phase 2 fast-follow per spec §247)
- Hut interior system (Phase 3 territory; PlotAnchors v1 is just numbered tiles in a Cottages zone)
- Bigger Stall / Featured Discount gamepasses (Phase 3 monetization; Constants hooks designed-in but unwired)
- Spatial Voice in marketplace (Phase 3 polish)
- Real visual polish on plot tiles, stall stands, NPC models (placeholder Parts in v1)

</domain>

<decisions>
## Implementation Decisions

All decisions below are LOCKED via the spec at `docs/specs/player-stalls.md` (user-approved 2026-05-03). Reference each decision ID in task actions for traceability.

### Architecture

- **D-01: Hybrid placement.** Each player has a free personal stall on a per-player plot anchor (assigned lazily on first stall interaction). Trading Post zone hosts a separate physical row of 12 featured slots, rented daily for 200 coins. Personal stall is always-on; featured slot is the discoverability lever. (Spec §11)

- **D-02: Shared Exchange core.** New `src/server/Exchange.luau` owns snapshot/restore, atomic mutation (one-sided), and audit log writes. Both `Trade.luau` (refactored — preserves public API) and `Stall.luau` (new) consume it. Audit log entries gain a `kind` field (`"trade"` | `"stall_purchase"`). (Spec §16)

- **D-03: Async sales via mailbox.** Listings persist in DataStore. Items leave inventory at list time (escrow). Anyone can buy from any active listing regardless of seller presence. Sale proceeds collect in `data.stalls.mailbox`, claimed via `ClaimMailbox` remote. (Spec §12)

- **D-04: Fixed-price only in v1.** Single listing kind; save-schema and listing shape leave room for `kind = "auction"` + `bids` + `expiresAt` in a future commit with no rework. (Spec §13)

- **D-05: Discovery gated to featured row.** Plot Directory UI shows featured-row sellers only + a global recent-activity feed (last 20 sales). Personal-only stalls are word-of-mouth / physical-visit discoverable. (Spec §15)

### Tunables (locked numbers — do not invent variants)

- **D-06: Listing slots per stall.** `Constants.STALL.slotCount = 4`. Gamepass hook `+4 if gamepasses.BiggerStall` designed-in but unwired in v1. (Spec §14)
- **D-07: Listing expiry.** `Constants.STALL.listingExpirySeconds = 48 * 3600`. Expired listings return items to the seller's mailbox. (Spec §14)
- **D-08: Featured row size + fee.** `Constants.STALL.featuredSlotCount = 12`, `Constants.STALL.featuredFee = 200` coins per 24-hour rental. Continuous FIFO allocation, no global daily reset. 1 featured slot per account. (Spec §14, §147–157)
- **D-09: Plot anchor capacity.** 8×8 grid = 64 tiles in a Cottages zone west of spawn. Position grid origin at `Constants.STALL.cottagesZoneOrigin`. Each tile is 16×16 studs. (Spec §163, §167)
- **D-10: Price bounds.** `unitPrice ∈ [1, 1e9]`. Sanity bounds; no economic floor enforcement beyond 1. (Spec §178)
- **D-11: Mailbox cap.** Hard cap at 100 unique item ids; coins uncapped. Returned-unsold items beyond cap fall through to audit-log-only with player notification. (Spec §141, §179) — see D-20 for the precise return-value semantics.

### Modules to write/refactor

- **D-12: Module map** (per Spec §22-41):
  - `src/server/Exchange.luau` — NEW. Pure helpers: `snapshotData`, `restoreFromSnapshot`, `applyOneSided(data, give, receive)`, `writeAudit(entry)`. Audit `kind` field is mandatory.
  - `src/server/Trade.luau` — REFACTOR. Replace inline snapshot/restore/audit helpers with `Exchange.*` calls. Preserve public API (`Trade.start`, all remote handlers). Update `applyOffer` to call `Exchange.applyOneSided`.
  - `src/server/Stall.luau` — NEW. Listing CRUD, browse, atomic buy via Exchange, mailbox claim, expiry sweeper, featured-row rental.
  - `src/server/PlotAnchors.luau` — NEW. Per-player plot tile assignment + lookup. Stable `plotAnchorId` written to `data.stalls`.
  - `src/server/MapSetup.luau` — UPDATE. Add `buildStallManager` NPC, `buildFeaturedRowStalls` (12 anchored Parts in TP zone), `buildPlotAnchorGrid` (64 tiles in Cottages zone). Hand-built escape valves per existing pattern.
  - `src/client/StallUI.client.luau` — NEW. Three modes: owner UI (4-slot grid + mailbox tab + featured tab), buyer UI (list of seller's listings + Buy button), Plot Directory UI (HUD "Marketplace" button → featured tab + recent sales tab).
  - `src/shared/Constants.luau` — UPDATE. Add `STALL` config block + `MERCHANTS.StallManager` entry + `cottagesZoneOrigin`. Reuse existing `inventoryByCategory` schema; no new ITEMS additions.
  - `src/shared/Dialogues.luau` — UPDATE. Add `StallManager` dialogue tree per Spec §188-194.
  - 10 new REMOTES (Spec §36-38): `CreateListing`, `CancelListing`, `BuyListing`, `RentFeaturedSlot`, `ClaimMailbox`, `BrowseDirectory`, `OpenStallOwnerUI`, `OpenStallBuyerUI`, `StallTransactionCompleted`, `MailboxUpdated`.

### Save schema (additive to v3, no migration needed)

- **D-13: data.stalls shape** (per Spec §47-69):
  ```lua
  data.stalls = {
      plotAnchorId = nil,                    -- assigned lazily; "tile_NN" string when set
      listings = { [listingId] = { itemId, qty, unitPrice, listedAt, expiresAt, featured } },
      mailbox = { coins = 0, items = {}, sales = {} },
      featuredRentExpiresAt = nil,
  }
  ```
  Default written for any v3 player on next save. Idempotent.

### Atomic execution flow (BuyListing)

- **D-14:** Per Spec §117-127. Server fetches listing → re-validates buyer affordability → snapshots both parties → mutates buyer (subtract coins, add items via Exchange) → mutates seller's stalls (delete listing, add coins to mailbox, prepend sale entry trimmed to 50) → on failure, restore from snapshot. Audit `kind = "stall_purchase"`. Offline-seller mutation strategy is locked in **D-19** below.

### Validation matrix

- **D-15: Validation matrix** (Spec §97-111). Server-authoritative checks at every C→S edge. Error codes: `SLOT_FULL`, `INSUFFICIENT_INVENTORY`, `ITEM_NOT_TRADABLE`, `INVALID_PRICE`, `INVALID_REQUEST`, `LISTING_GONE`, `INSUFFICIENT_COINS`, `SELF_PURCHASE`, `NOT_OWNER`, `MAILBOX_FULL`, `FEATURED_FULL`, `ALREADY_FEATURED`.

### Anti-griefing

- **D-16:** Per Spec §175-182. Inventory escrow at list time. Atomic buy with snapshot-rollback. Rate limits per **D-21** (full table). Self-purchase blocked. Audit log on every state transition.

### UI surface

- **D-17:** Three UI surfaces (Spec §188-218):
  1. **Stall Manager NPC dialogue** — three response branches: "Manage my stall" → `OpenStallOwnerUI`; "Rent a featured slot" → confirms 200-coin fee, fires `RentFeaturedSlot`; "Open my mailbox" → opens owner UI with mailbox tab pre-selected.
  2. **Stall Owner UI** — 3 tabs (Listings · Mailbox · Featured). Reuses Trade UI's item picker submodal pattern.
  3. **Stall Buyer UI** — opens via ProximityPrompt on a stall stand. Reuses Shop UI's buy-tab pattern.
  4. **Plot Directory UI** — HUD "Marketplace" button → Featured tab (sellers in featured row, "Visit Stall" via CFrame teleport per ADR 001 — NOT TeleportService — and "Quick Buy" inline buyer modal) + Recent Sales tab (chronological feed of last 20 global sales).

### Tests

- **D-18:** New `Tests/StallSpec.luau` (~17 tests) and `Tests/ExchangeSpec.luau` (~8 tests). Existing `Tests/TradeSpec.luau` updated to consume Exchange where applicable; behavior unchanged. Coverage spelled out in Spec §222-241.

### Decisions added during plan-checker revision (2026-05-03 user-confirmed)

- **D-19: Offline-seller mutation via pending-mutations queue.** When a buyer purchases from an offline seller, the server writes a mutation record to a new `MyceliaStallPendingMutations_v1` DataStore keyed on `userId`. Schema per record: `{ kind = "stall_sale", listingId, coinsEarned, soldAt, buyerName, itemId, qty }`. Multiple records per userId are stored as an array under the userId key (read-modify-append-write pattern; idempotent merges). When the seller next loads their Profile via `PlayerData.onPlayerAdded`, a new `PendingMutations.drain(player)` step runs **before** any other startup hooks: it reads the queue, applies each mutation to the seller's `data.stalls.listings` / `data.stalls.mailbox.coins` / `data.stalls.mailbox.sales`, then atomically deletes the queue entry. The drain is wrapped in pcall — if it fails, the queue is left intact for next login (no partial drains). For online sellers, the buy still uses direct `PlayerData.update`. Path: route through a `StallMutations.applyToSeller(sellerUserId, mutation)` helper that branches: **online** → `PlayerData.update` directly; **offline** → write to pending queue. The `PendingMutations` module is new and reusable for future offline-mutation needs (e.g., LiveOps event payouts). Audit log writes the same `stall_purchase` entry regardless of path.

- **D-20: MAILBOX_FULL is a silent fallback, not a hard error.** Per spec §141 prose ("falls through to audit-only"), when a returned-unsold listing would exceed the seller's 100-id mailbox cap: items are written to `MyceliaAuditLog_v1` with a `mailbox_overflow` audit kind, the listing is removed, the seller's `data.stalls.mailbox.overflowNotice = { count = N, since = os.time() }` is set so the Owner UI shows a banner ("3 listings returned to audit log — mailbox was full"). The cancel/expire operation **succeeds** (returns `(true, "OK")`); buyer-facing operations are unaffected. Coins always accumulate in mailbox. The `MAILBOX_FULL` error code listed in spec §108's validation matrix is **deprecated in favor of this silent-fallback behavior**; remove the row from the validation matrix in player-stalls.md as a doc-hygiene follow-up. The `claimMailbox` operation MUST reset `overflowNotice = nil` when called (so the banner disappears once the player acknowledges).

- **D-21: Full rate limit table (server-side enforcement).** All 6 stall remotes get explicit server-side limits. UI throttles below these as a courtesy:
  - `CreateListing` — 1 / 3s per player (per spec §177)
  - `BuyListing` — 1 / 1s per player (per spec §177)
  - `CancelListing` — 1 / 3s per player (NEW — D-21)
  - `RentFeaturedSlot` — 1 / 60s per player (per spec §177)
  - `ClaimMailbox` — 1 / 10s per player (NEW — D-21)
  - `BrowseDirectory` — 1 / 2s per player (NEW — D-21; bot-scraping deterrent)
  All limits implemented via a shared `RateLimit.check(player, remoteName, intervalSeconds)` helper in a new `src/server/RateLimit.luau` module (or extend an existing equivalent if one exists in the project — verify during planning). On rate-limit reject, server fires `StallTransactionCompleted` (or appropriate completed-remote per the action) with `{ success = false, code = "RATE_LIMITED" }`.

### Claude's Discretion

- **CD-1: Listing ID generation.** Spec calls for "UUID generated server-side." Use `HttpService:GenerateGUID(false)` per Trade.luau precedent.
- **CD-2: Expiry sweeper interval.** Spec doesn't specify; use 60-second tick (low cost; expiry granularity is fine at minute level for 48h listings).
- **CD-3: Plot anchor visual.** Spec says "placeholder Part." Use a thin 16×16 stud square Part with a stall stand Model on top. Hand-built escape valve per existing MapSetup convention.
- **CD-4: Featured stall positions.** Spec says "12 anchored stall Models in the Trading Post zone (positions defined in Constants.STALL.featuredRowPositions)." Lay out as a 3×4 grid or single row of 12 — choose based on Trading Post zone layout. Position via `Constants.STALL.featuredRowOrigin` + offsets.
- **CD-5: Cottages zone location.** Spec says "west of spawn." Place grid at approximately `Vector3.new(-300, 0, 0)` to be far enough from the StarterGlade core (which sits around the origin) without conflicting with the future Phase 1 Misty Hollow zone (which is east at +2000).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Player Stalls spec (the PRD itself)
- `docs/specs/player-stalls.md` — full design contract, the source of all D-XX above

### Direct dependencies (must read)
- `docs/specs/trading-post.md` — Trade.luau spec; Player Stalls extracts Exchange core from here. Already shipped.
- `docs/specs/save-schema-v3.md` — current save schema; data.stalls is an additive extension.
- `docs/specs/remote-api.md` — wire-level remote contract; 10 new remotes get added.
- `docs/specs/shop-ui.md` — Shop UI buy-tab pattern reused in Stall Buyer UI.
- `docs/specs/dialogue-system.md` — dialogue tree pattern reused for StallManager NPC.
- `docs/specs/visual-language.md` — `Constants.UI` token table for any new UI surfaces.

### Architectural decisions (locked)
- `docs/decisions/001-biome-architecture.md` — single-place world; "teleport" means CFrame.RootPart move, NOT TeleportService. Plot Directory's "Visit Stall" button uses this pattern.
- `docs/decisions/004-coin-economy.md` — 10B coin hard cap; Coins.add chokepoint discipline. Stall purchases must route through whatever the project's coin-mutation chokepoint is.

### Project conventions
- `CLAUDE.md` — server-authoritative everything; tunables in Constants.luau; pure-function modules get tests; match existing module conventions.
- `docs/CONTRIBUTING.md` — Definition of Done (tests + HANDOFF + docs + Studio verification).
- `HANDOFF.md` — current state; trade primitives shipped 2026-05-03 are the immediate predecessor.

### Source modules (must read for refactor)
- `src/server/Trade.luau` — current Trade module; helpers to extract into Exchange.luau (`snapshotData`, `restoreFromSnapshot`, `writeAudit`, `applyOffer`).
- `src/server/PlayerData.luau` — ProfileService wrapper. **Critical:** verify whether it supports mutating an offline player's profile (loaded from DataStore without active session). This is the open follow-up flagged in Spec §127.
- `src/server/Inventory.luau` — `Inventory.add`, `Inventory.remove`, `Inventory.count` for legacy inventory bucket.
- `src/server/MapSetup.luau` — existing escape-valve pattern for hand-built world pieces.
- `src/server/Dialogue.luau` — dialogue dispatcher for StallManager NPC.
- `src/server/Shop.luau` — Shop UI dispatcher for buyer-UI ProximityPrompt pattern.
- `src/shared/Constants.luau` — existing MERCHANTS / ITEMS / REMOTES / UI tables.
- `src/shared/Remotes.luau` — `Remotes.get(name)` accessor.
- `src/shared/Species.luau` — `Species.byId` for routing mushroom-vs-non-mushroom items.
- `src/server/Tests/TradeSpec.luau` — pattern for atomic-execution tests (will be the refactor template for ExchangeSpec).

</canonical_refs>

<specifics>
## Specific Ideas

- The 6 sub-tasks (P2-STALL-01..06) from `.planning/REQUIREMENTS.md`:
  - **P2-STALL-01:** Stall rental flow (Stall Manager NPC + dialogue + RentFeaturedSlot remote handler).
  - **P2-STALL-02:** Listing UI (owner UI: 4-slot grid, item picker, edit/cancel).
  - **P2-STALL-03:** Browse + buy flow (buyer UI on stall ProximityPrompt; BuyListing handler with atomic execution).
  - **P2-STALL-04:** Stall renewal/release loop (24h featured expiry sweeper; 48h listing expiry sweeper; auto-return-to-mailbox on expiry).
  - **P2-STALL-05:** Plot anchors (PlotAnchors.luau + Cottages zone grid + lazy assignment).
  - **P2-STALL-06:** Plot Directory UI + recent-sales feed (HUD Marketplace button).
- The plan should naturally split into **2 execution waves**:
  - **Wave 1 (foundation):** Exchange.luau extraction + Trade.luau refactor (zero behavior change; tests must still pass) + save schema additive default + Constants.STALL block + 10 remotes registered. Pure refactor; no new gameplay yet. *This wave is critical to get right because it touches a shipping system; tests are the safety net.*
  - **Wave 2 (Stalls feature):** Stall.luau + PlotAnchors.luau + StallUI.client.luau + MapSetup additions + StallManager dialogue + StallSpec + ExchangeSpec.
- Atomic commits per task per project convention.
- Studio verification required at end of each wave; documented in PLAN as a verification step (since automated tests can't cover Roblox-bound behavior like ProximityPrompts and DataStore writes).

</specifics>

<deferred>
## Deferred Ideas

Per Spec §247-261 (Future-proofing + Open follow-ups):

- Auctions (Phase 2 fast-follow; schema is ready)
- LiveOps trading event lotteries (Phase 3 — third caller of Exchange.applyOneSided)
- Hut interior system (Phase 3; PlotAnchors v1 is the foundation)
- Spatial Voice in marketplaces (Phase 3 polish)
- Bigger Stall + Featured Discount gamepasses (Phase 3 monetization)
- Real plot anchor / stall stand / NPC visuals (asset pipeline)
- Mailbox notification on next login (HUD toast — polish)
- Plot Directory pagination (only matters if featured row > 12)
- ~~ProfileService offline-mutation API verification~~ — **RESOLVED 2026-05-03 via D-19** (pending-mutations queue chosen; no ProfileService offline-mutation needed)

</deferred>

---

*Phase: 02-closed-beta-social-systems-content (Player Stalls slice)*
*Context gathered: 2026-05-03 via PRD Express Path (`docs/specs/player-stalls.md`)*
