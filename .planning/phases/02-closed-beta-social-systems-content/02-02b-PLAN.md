---
phase: 02-closed-beta-social-systems-content
plan: 02b
type: execute
wave: 2b
depends_on: ["02-02a"]
files_modified:
  - src/server/Stall.luau                  # ADD start() + remote handlers + sweeper + ProximityPrompt routing
  - src/server/PlayerData.luau             # ADD PendingMutations.drain call in onPlayerAdded
  - src/server/init.server.luau            # ADD Stall.start() invocation
  - src/server/Tests/StallSpec.luau        # OPTIONAL: extend with knownSellers TTL test if practical
autonomous: false                           # Studio verification at the end (multi-player flow)
requirements:
  - P2-STALL-04                             # Closed: sweeper + offline mutation drain wire renewal/release
  - P2-STALL-05                             # Closed: full mailbox flow including ClaimMailbox remote

must_haves:
  truths:
    - "Stall.start() registers handlers for all 6 stall remotes (CreateListing, CancelListing, BuyListing, RentFeaturedSlot, ClaimMailbox, BrowseDirectory). Every handler calls RateLimit.check(player, remoteName, Constants.STALL.rateLimits[remoteName]) FIRST; on rate-limit reject fires StallTransactionCompleted with code='RATE_LIMITED'."
    - "Stall.start() spawns a sweeper task running every Constants.STALL.expirySweeperIntervalSeconds (60s). Sweeper iterates Stall.knownSellers registry; for each known seller calls expirySweep + sweepFeaturedExpiry; routes resulting mutations through StallMutations.applyToSeller (online → PlayerData.update; offline → PendingMutations.write)."
    - "Stall.knownSellers is an in-memory registry { [userId] = lastSeenAt }. Updated on every CreateListing / RentFeaturedSlot / drain-on-load. Entries older than CD-6 (Constants.STALL.knownSellersTtlSeconds = 7 days) are dropped on each sweeper tick."
    - "PlayerData.onPlayerAdded calls PendingMutations.drain BEFORE any other startup hook. Reads MyceliaStallPendingMutations_v1 for player.UserId, drains via PendingMutations.drain(data, mutations), atomically deletes the queue entry on success."
    - "Stall.requestRentFeatured(player) is a public function (B-6 lock) that the StallManager dialogue's openShop-style action will call in PLAN 03. Same code path as the RentFeaturedSlot remote handler — extracted so the dialogue dispatcher can invoke it without re-firing a client→server remote."
    - "Stall.executeBuy's seller-side mutation routes through StallMutations.applyToSeller(sellerUserId, mutation). The atomic-buy from buyer's POV is: validate buyer affordability → snapshot buyer → mutate buyer → call applyToSeller for seller branch → on failure restore buyer from snapshot. Online seller failures restore buyer; offline seller writes to PendingMutations and is considered successful (queue durability is the durability)."
    - "ProximityPrompt routing: server listens on ProximityPromptService.PromptTriggered; if prompt is on a Part with attribute `stallSellerUserId` set, fires OpenStallBuyerUI to player with sellerUserId payload. (The actual stall stand Parts get this attribute in PLAN 03's MapSetup additions.)"
    - "Audit log entries written for every state transition per the W-9 taxonomy (7 kinds). Each transition wraps Exchange.writeAudit({ kind = ..., listingId?, sellerUserId, buyerUserId?, items?, coins?, reason? })."
  artifacts:
    - path: "src/server/Stall.luau"
      provides: "ADDS start() + handleCreateListing + handleCancelListing + handleBuyListing + handleRentFeaturedSlot + handleClaimMailbox + handleBrowseDirectory + sweeperTask + StallMutations.applyToSeller + Stall.requestRentFeatured + ProximityPrompt routing. Pure helpers from PLAN 02a remain unchanged."
      contains: "function Stall.start"
    - path: "src/server/PlayerData.luau"
      provides: "PendingMutations.drain call in onPlayerAdded BEFORE other hooks"
      contains: "PendingMutations"
    - path: "src/server/init.server.luau"
      provides: "Stall.start() called after Trade.start() (or wherever other gameplay starts go)"
      contains: "Stall.start"
  key_links:
    - from: "src/server/Stall.luau"
      to: "src/server/RateLimit.luau"
      via: "RateLimit.check(player, remoteName, Constants.STALL.rateLimits[remoteName]) at every handler entry"
      pattern: "RateLimit%.check"
    - from: "src/server/Stall.luau"
      to: "src/server/PendingMutations.luau"
      via: "PendingMutations.write in StallMutations.applyToSeller offline branch"
      pattern: "PendingMutations%.write"
    - from: "src/server/PlayerData.luau"
      to: "src/server/PendingMutations.luau"
      via: "drain hook in onPlayerAdded"
      pattern: "PendingMutations%.drain"
---

<objective>
Wire the Roblox-bound side of Player Stalls: register all 6 stall remote handlers, spawn the expiry sweeper task, integrate the offline-seller PendingMutations drain into the PlayerData lifecycle, and expose the public Stall.requestRentFeatured for PLAN 03's dialogue dispatcher.

This plan touches three existing files (Stall.luau extends with Roblox-bound code, PlayerData.luau gets the drain hook, init.server.luau adds the start call). No new files. No new tests (the helpers are already covered by PLAN 02a; Roblox-bound behavior is verified live in Studio per CLAUDE.md "tests cover what's testable, Studio verifies the rest").
</objective>

<execution_context>
@$HOME/.claude/get-shit-done/workflows/execute-plan.md
@$HOME/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/STATE.md
@.planning/phases/02-closed-beta-social-systems-content/02-CONTEXT.md
@.planning/phases/02-closed-beta-social-systems-content/02-01-PLAN.md
@.planning/phases/02-closed-beta-social-systems-content/02-02a-PLAN.md
@CLAUDE.md
@docs/specs/player-stalls.md
@src/server/Stall.luau
@src/server/Trade.luau
@src/server/Shop.luau
@src/server/PlayerData.luau
@src/server/init.server.luau
@src/server/RateLimit.luau
@src/server/PendingMutations.luau
@src/server/Exchange.luau
@src/shared/Constants.luau
@src/shared/Remotes.luau

<interfaces>

```luau
-- ADDS to src/server/Stall.luau (PURE HELPERS from PLAN 02a unchanged)

-- In-memory registry of sellers with active stall state. Used by sweeper.
-- { [userId] = lastSeenAt: number }. Drops entries older than Constants.STALL.knownSellersTtlSeconds.
Stall.knownSellers = {}

-- Routes a sellerMutation to the right destination per online/offline branch.
-- Online: PlayerData.update + Exchange.writeAudit. Offline: PendingMutations.write + Exchange.writeAudit.
-- Returns: (ok, code).
function Stall.applyToSeller(sellerUserId: number, mutation: table): (boolean, string)

-- Public function for the StallManager dialogue (PLAN 03).
-- Same code path as the RentFeaturedSlot remote handler. See B-6 lock.
function Stall.requestRentFeatured(player: Player): (boolean, string)

-- Wire all 6 remote handlers + ProximityPromptService listener + sweeper task.
-- Idempotent (guarded by a started flag).
function Stall.start()
```

```luau
-- EDITS to src/server/PlayerData.luau

-- onPlayerAdded already exists. Add the drain BEFORE any other startup hook:
--
--   local function onPlayerAdded(player)
--       -- existing profile load logic
--       local profile = ProfileService:LoadProfileAsync(...)
--       -- ... profile reconcile / initial save / etc ...
--
--       -- NEW: drain pending stall mutations BEFORE any gameplay-system observer fires
--       local mutations = pcall(function()
--           return PendingMutationsStore:GetAsync(tostring(player.UserId))
--       end)
--       if mutations and #mutations > 0 then
--           PlayerData.update(player, function(data)
--               local applied, errors = PendingMutations.drain(data, mutations)
--               if #errors > 0 then warn(...) end
--           end)
--           -- atomic delete after successful apply
--           pcall(function() PendingMutationsStore:RemoveAsync(tostring(player.UserId)) end)
--       end
--
--       -- existing PlayerDataReady firing / observers / etc continues here
--   end
```

```luau
-- EDITS to src/server/init.server.luau

-- After existing system starts (Shop.start, Dialogue.start, Quest.start, Trade.start, etc.):
local Stall = require(ServerScriptService.Server.Stall)
Stall.start()
```

**Per-handler rate limit lookup pattern (D-21):**
```luau
local function handleCreateListing(player, payload)
    if not RateLimit.check(player, "CreateListing", Constants.STALL.rateLimits.CreateListing) then
        Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
            success = false, code = "RATE_LIMITED", action = "create",
        })
        return
    end
    -- ... validation + atomic mutation + audit ...
end
```

**Sweeper task pattern (B-2 wiring):**
```luau
task.spawn(function()
    while true do
        task.wait(Constants.STALL.expirySweeperIntervalSeconds)  -- 60s per CD-2

        -- Drop stale entries from knownSellers per CD-6 TTL
        local now = os.time()
        for userId, lastSeenAt in pairs(Stall.knownSellers) do
            if now - lastSeenAt > Constants.STALL.knownSellersTtlSeconds then
                Stall.knownSellers[userId] = nil
            end
        end

        -- For each known seller: pure-helper analysis + route mutations
        for userId in pairs(Stall.knownSellers) do
            local player = Players:GetPlayerByUserId(userId)
            if player then
                -- online — direct mutation
                PlayerData.update(player, function(data)
                    local expiredIds = Stall.expirySweep(data, now)
                    for _, listingId in ipairs(expiredIds) do
                        local _, _, overflow = Stall.cancelListing(data, listingId, userId)
                        if overflow then
                            Exchange.writeAudit(Exchange.buildAuditEntry("mailbox_overflow", { ... }))
                        end
                        Exchange.writeAudit(Exchange.buildAuditEntry("stall_expire", { listingId, sellerUserId = userId }))
                    end
                    -- featured expiry inline
                    if data.stalls.featuredRentExpiresAt and now > data.stalls.featuredRentExpiresAt then
                        data.stalls.featuredRentExpiresAt = nil
                        -- caller updates featuredRowState in-memory too — see below
                    end
                end)
            else
                -- offline — write to PendingMutations
                -- Need to read the offline player's data to know what's expired.
                -- Tradeoff: we don't have the data offline. Two options:
                --   (a) Cache a "summary" of every seller's expiresAt timestamps in memory at write-time
                --       (CreateListing, RentFeaturedSlot stamp Stall.knownSellers[userId].expiries = {...})
                --   (b) Skip offline sellers in this tick and let the drain-on-load do the work next time they log in
                -- Recommend (a) — cheap memory cost (a few dozen timestamps per seller), avoids
                -- "ghost" expired listings sitting in DataStore until next login.
            end
        end
    end
end)
```

**B-2 implementation note (offline expiry):**
Use option (a) above — extend `Stall.knownSellers[userId]` shape from a number to a table:
```luau
{ lastSeenAt = number, listingExpiries = { [listingId] = expiresAt }, featuredExpiresAt = number? }
```
Updated on every CreateListing / RentFeaturedSlot / drain-on-load. The sweeper for an offline seller iterates `listingExpiries`, identifies expired ones, and writes `expiry_listing_to_mailbox` mutations to PendingMutations queue. For featured expiry: writes `expiry_clear_featured`. The actual seller `data.stalls` mutation happens on next drain-on-load.

**ProximityPrompt routing:**
The buyer UI opens when a player triggers a ProximityPrompt on a stall stand Part. The Part's `stallSellerUserId` attribute (set by PLAN 03's MapSetup additions for featured stalls; set by Stall.start when a player's personal plot stall is rendered) tells the server which seller's listings to send. Pattern mirrors Shop.luau / Dialogue.luau:
```luau
ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
    local part = prompt.Parent
    local sellerUserId = part:GetAttribute("stallSellerUserId")
    if sellerUserId then
        local sellerData = ... -- fetch via PlayerData.get if online; use a snapshot in Stall.knownSellers if offline
        local listings = sellerData and sellerData.stalls.listings or {}
        Remotes.get(Constants.REMOTES.OpenStallBuyerUI):FireClient(player, {
            sellerUserId = sellerUserId,
            sellerName = ...,
            listings = listings,
        })
    end
end)
```

</interfaces>
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add Stall.start + handlers + sweeper + applyToSeller + requestRentFeatured</name>
  <files>src/server/Stall.luau</files>
  <behavior>
    No tests in this task — the pure helpers are already covered by PLAN 02a's StallSpec. Studio verification covers the wiring.
  </behavior>
  <action>
    1. At the top of Stall.luau (below the existing pure-helpers section from PLAN 02a):
       - Require RateLimit, PendingMutations, Players, ProximityPromptService, PlayerData, Exchange, Remotes, Constants.
       - Initialize `Stall.knownSellers = {}` (the registry).

    2. Implement `Stall.applyToSeller(sellerUserId, mutation)`:
       - If `Players:GetPlayerByUserId(sellerUserId)` returns non-nil → online branch: call PlayerData.update(player, fn), where fn applies the mutation (per-kind dispatch matching PendingMutations.drain's logic). Then Exchange.writeAudit per the appropriate kind.
       - Else → offline branch: PendingMutations.write(sellerUserId, mutation). Then Exchange.writeAudit (note: still write the audit even though the seller mutation is queued — the audit reflects buyer-side facts).
       - Update Stall.knownSellers[sellerUserId] for sweeper visibility.

    3. Implement `Stall.requestRentFeatured(player)`:
       - Read player data via PlayerData.get(player).
       - Build featuredRowState from a server-memory `Stall.featuredRowState` table (initialize empty; populate from knownSellers + on-the-fly).
       - Call Stall.canRentFeatured(data, featuredRowState, os.time()). If reject → return (false, code).
       - On accept: PlayerData.update to deduct 200 coins + set data.stalls.featuredRentExpiresAt = now + Constants.STALL.featuredRentSeconds. Update Stall.featuredRowState[slotIndex] = player.UserId. Update Stall.knownSellers. Exchange.writeAudit({ kind = "stall_featured_rented", sellerUserId, slotIndex, fee = 200 }). Fire StallTransactionCompleted to player. Return (true, "OK").

    4. Implement the 6 remote handlers:
       - **handleCreateListing(player, payload)**: rate-limit check → validate payload structure → validate via Stall.canCreateListing → PlayerData.update to escrow items + create listing → update Stall.knownSellers + listingExpiries → Exchange.writeAudit({ kind = "stall_create", ... }) → fire StallTransactionCompleted.
       - **handleCancelListing(player, listingId)**: rate-limit → Stall.canCancelListing → PlayerData.update to call Stall.cancelListing → if overflow: Exchange.writeAudit({ kind = "mailbox_overflow", ... }) → Exchange.writeAudit({ kind = "stall_cancel", ... }) → fire StallTransactionCompleted.
       - **handleBuyListing(player, sellerUserId, listingId, qty)**: rate-limit → fetch seller data (online via PlayerData.get; offline via Stall.knownSellers cached snapshot) → Stall.canBuy → snapshot buyer via Exchange.snapshotData → PlayerData.update buyer to call Stall.executeBuy → call Stall.applyToSeller(sellerUserId, sellerMutation) → on offline-applyToSeller failure (write returned false): Exchange.restoreFromSnapshot buyer → fire StallTransactionCompleted with success=false, code="MUTATION_FAILED" → otherwise Exchange.writeAudit({ kind = "stall_purchase", ... }) → fire StallTransactionCompleted success=true.
       - **handleRentFeaturedSlot(player)**: rate-limit → call Stall.requestRentFeatured(player).
       - **handleClaimMailbox(player)**: rate-limit → PlayerData.update buyer to call Stall.claimMailbox → Exchange.writeAudit({ kind = "stall_mailbox_claim", ... }) → fire MailboxUpdated to player with new mailbox state.
       - **handleBrowseDirectory(player)**: rate-limit → build featuredRegistry from Stall.featuredRowState + each seller's plot tile → call Stall.browseDirectory → fire BrowseDirectory back to player with the rows.

    5. Implement ProximityPromptService listener per `<interfaces>` block above. Skip if the prompt's parent has a `merchantId` or `dialogueId` attribute (defer to Shop / Dialogue per existing pattern).

    6. Implement the sweeper task per `<interfaces>` block. Includes:
       - 60s tick.
       - Drop stale knownSellers entries older than CD-6 TTL.
       - For each known seller, online vs offline branch.
       - Online: direct PlayerData.update with expirySweep results + featured expiry.
       - Offline: read knownSellers cached expiries; queue mutations via PendingMutations.write.

    7. Wrap `Stall.start()` to register all of the above. Idempotent guard with a `started` flag.
  </action>
  <success-criteria>
    - Stall.start() does NOT crash on import (require chain resolves)
    - All 6 remote handlers connected
    - ProximityPrompt listener active
    - Sweeper task running (visible in `print` line at sweeper start)
    - knownSellers registry populated on first CreateListing
  </success-criteria>
</task>

<task type="auto">
  <name>Task 2: Wire PendingMutations.drain into PlayerData.onPlayerAdded</name>
  <files>src/server/PlayerData.luau</files>
  <behavior>
    The drain MUST run BEFORE any other startup hook (PlayerDataReady firing, observer setup, etc.). Otherwise observers see stale data and miss the queued mutations.
  </behavior>
  <action>
    1. require PendingMutations at the top of PlayerData.luau.
    2. Acquire the PendingMutationsStore lazily (mirroring the existing audit-store pattern in Trade.luau).
    3. In the onPlayerAdded function, after the profile loads but BEFORE any PlayerDataReady fire / observer call:
       ```luau
       local ok, mutations = pcall(function()
           return PendingMutationsStore:GetAsync(tostring(player.UserId))
       end)
       if ok and type(mutations) == "table" and #mutations > 0 then
           PlayerData.update(player, function(data)
               local applied, errors = PendingMutations.drain(data, mutations)
               if #errors > 0 then
                   warn("[PendingMutations] drain errors for", player.UserId, table.concat(errors, " | "))
               end
           end)
           pcall(function() PendingMutationsStore:RemoveAsync(tostring(player.UserId)) end)
       end
       ```
    4. Critically: if the drain pcall fails, leave the queue intact for next login. Don't delete the queue on failure.
  </action>
  <success-criteria>
    - Player joins; if MyceliaStallPendingMutations_v1 has pending entries for their userId, they apply before any other observer fires
    - Failed drains leave the queue intact (test by manually corrupting one mutation and verifying the rest don't apply but the queue stays)
  </success-criteria>
</task>

<task type="auto">
  <name>Task 3: Add Stall.start() to init.server.luau</name>
  <files>src/server/init.server.luau</files>
  <action>
    1. Read existing init.server.luau to find where Trade.start() lives.
    2. After Trade.start() (or wherever the Phase 2 systems live), add:
       ```luau
       local Stall = require(ServerScriptService.Server.Stall)
       Stall.start()
       ```
    3. Order matters: Stall.start MUST run AFTER PlayerData.start (so the drain hook is registered before any player joins) and AFTER Exchange/RateLimit/PendingMutations are accessible. Verify the require ordering doesn't cause any cyclic-require issues.
  </action>
</task>

<task type="checkpoint">
  <name>Task 4: Studio verification — multi-player end-to-end</name>
  <action>
    Studio test plan (W-2 split applied — 3 discrete checkpoints):

    **Checkpoint A — Online flow (smoke test)**:
    1. rojo serve, Studio Play with 2 test players.
    2. Player1: walks to spawn area, opens command bar, manually grants 1000 coins + 5 BrownCap (since the StallManager NPC isn't built yet — that's PLAN 03):
       `local PlayerData = require(game.ServerScriptService.Server.PlayerData); local d = PlayerData.get(game.Players:GetPlayers()[1]); d.coins = 1000; d.inventory.BrownCap = 5`
    3. Player1: fire CreateListing manually:
       `game.ReplicatedStorage.Remotes.CreateListing:FireServer({ itemId = "BrownCap", qty = 2, unitPrice = 50 })`
    4. Verify in command bar: `for k, v in pairs(d.stalls.listings) do print(k, v.itemId, v.qty, v.unitPrice) end` — should show one listing with the GUID-style id.
    5. Player2: fire BuyListing manually with the listingId from step 4:
       `game.ReplicatedStorage.Remotes.BuyListing:FireServer(<player1.UserId>, "<listingId>", 2)`
    6. Verify Player2's inventory: BrownCap +2; coins -100.
    7. Verify Player1's mailbox: coins=100, sales[1] populated.
    8. Player1 fire ClaimMailbox; verify coins +100.

    **Checkpoint B — Offline flow (the D-19 marquee test)**:
    1. Player1 still in server with one listing (re-list if needed).
    2. Player1 leaves the server (close their Studio Play window).
    3. Player2 fires BuyListing with Player1's userId + listingId.
    4. Verify in DataStore: `MyceliaStallPendingMutations_v1[<player1.UserId>]` has one entry of kind="stall_sale".
    5. Stop Play, re-Play, have Player1 join again.
    6. Verify Player1's data.stalls.mailbox shows coins from the offline sale; the queue entry is removed.

    **Checkpoint C — Sweeper + offline expiry**:
    1. Manually set Constants.STALL.expirySweeperIntervalSeconds = 5 and Constants.STALL.listingExpirySeconds = 10 (temporary tuning for test).
    2. Player1 creates a listing, then leaves.
    3. Wait 15s.
    4. Verify in DataStore: queue has expiry_listing_to_mailbox mutation.
    5. Player1 rejoins; verify mailbox has the items back.
    6. Restore tunables.

    Resume signals: if any checkpoint fails, stop and surface to user with: "Checkpoint X failed at step Y: <observation>". Do NOT silently retry — diagnose first.
  </action>
</task>

</tasks>

<summary_template_hook>
After execution, write SUMMARY at .planning/phases/02-closed-beta-social-systems-content/02-02b-SUMMARY.md.
Surface to PLAN 03 + 04:
- Whether the offline flow worked end-to-end on first try (or notes on iteration)
- Final shape of Stall.knownSellers entries (extended-table form per B-2)
- Any deviation from D-19's mutation kinds
- Test count delta (should be 0 — this plan adds Roblox-bound code only; tests were in 02a)
- Whether Constants.STALL.knownSellersTtlSeconds = 7 days felt right or got tweaked
</summary_template_hook>
