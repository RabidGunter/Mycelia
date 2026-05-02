# Spec — Remote API Contracts

Every RemoteEvent / RemoteFunction in the project. Signature, direction, validation rules, return value, error codes.

A contractor implementing a new remote handler should be able to copy the validation skeleton from this spec, swap in the system-specific logic, and have a server-authoritative endpoint that follows the project's pattern.

---

## Conventions

**Naming:** Remote names are `PascalCase`. Defined in `Constants.REMOTES` table. Created at startup by `Remotes.lua`.

**Direction notation:** `C → S` means client fires, server handles. `S → C` means server fires, client handles. `C ↔ S` (RemoteFunction) means client invokes, server returns.

**Validation philosophy:** the server treats every incoming arg as adversarial. Type-check first; validate ranges / referenced ids; check player permissions / inventory / state; only then mutate state. Failure modes are silent (log on server, no-op for client) unless explicitly listed.

**Rate limits:** every C→S remote has a rate limit. Default 5 calls/sec/player. Configured per-remote in `Constants.RATE_LIMITS`. Exceeding the limit drops the request silently and logs.

**Error codes (returned via S→C events for failures that need UI):**

| Code | Meaning |
|---|---|
| `OK` | Operation succeeded. |
| `INVALID_INPUT` | Type mismatch or out-of-range arg. |
| `NOT_FOUND` | Referenced id doesn't exist. |
| `INSUFFICIENT_FUNDS` | Coin balance too low. |
| `INSUFFICIENT_INVENTORY` | Item count too low. |
| `LOCKED` | Player or world state forbids the action right now (e.g., trade in progress). |
| `RATE_LIMITED` | Too many calls per second. |
| `RECEPTION_FULL` | Inventory full / roster full / stall full. |
| `UNAUTHORIZED` | Player doesn't own the target (plot, hut, stall). |
| `INTERNAL` | Server bug or DataStore error. |

---

## Existing remotes (Pre-Alpha)

These are already shipped in Pre-Alpha. Documented here for completeness; no changes needed in Phase 1 unless flagged.

### `PlayerDataUpdated` (S → C)

Fires when a player's save data is mutated server-side. Whole-data push.

**Args (server fires with):** `data: PlayerData` — the full save table.

**Client handler:** caches into `latestData`; updates HUD, picker UIs, etc.

**Notes:** consider switching to delta updates in Phase 3 (only the fields that changed) to reduce network traffic. Pre-Alpha simplicity = whole-data push.

### `HarvestMushroom` — RESERVED

Currently unused. Harvest action runs through `ProximityPromptService.PromptTriggered` server-side, not via this remote. Reserved name; can be repurposed or removed in Phase 1.

### `PlantSpecies` (C → S) — **CHANGES IN PHASE 1**

Player commits a plant action.

**Pre-Alpha args:** `(plot: Instance, speciesId: string)` — plant chosen species on plot. Substrate is implicit (default compost).

**Phase 1 args:** `(plot: Instance, speciesId: string, substrateId: string, additives: { [string] = number })` — full cultivation flow.

**Server validation** — every rule has a failure error code that goes in the `PlantCompleted` reply:

| # | Check | Failure code |
|---|---|---|
| 1 | Type-check: `plot` is Instance, `speciesId` and `substrateId` are strings, `additives` is a table. | `INVALID_INPUT` |
| 2 | `plot` exists in Workspace and has `isPlot=true` attribute. | `NOT_FOUND` |
| 3 | `plot:GetAttribute("ownerUserId") == player.UserId`. (Phase 1 introduces per-player plots; the legacy `plantedByUserId` attribute is renamed `ownerUserId`.) | `UNAUTHORIZED` |
| 4 | `plot:GetAttribute("state") == "Empty"`. | `LOCKED` |
| 5 | `Species.byId[speciesId]` exists. | `NOT_FOUND` |
| 6 | `data.stats.speciesDiscovered[speciesId] == true`. | `UNAUTHORIZED` |
| 7 | `Constants.SUBSTRATES[substrateId]` exists. | `NOT_FOUND` |
| 8 | `Inventory.count(data.inventoryByCategory.substrates, substrateId) >= 1`. | `INSUFFICIENT_INVENTORY` |
| 9 | `data.coins >= (Constants.CULTIVATION.plantCost[Species.byId[speciesId].tier] + Constants.SUBSTRATES[substrateId].cost)`. | `INSUFFICIENT_FUNDS` |
| 10 | (Phase 2+) Each `additives` entry is a valid additive id and player has the count. | `INSUFFICIENT_INVENTORY` |

The error-code-per-rule pattern applies to every other remote handler in this document. Where an inline table isn't shown, use this same mapping convention: type/format → `INVALID_INPUT`; missing referenced id → `NOT_FOUND`; ownership/discovery → `UNAUTHORIZED`; conflicting state → `LOCKED`; missing items → `INSUFFICIENT_INVENTORY`; missing coins → `INSUFFICIENT_FUNDS`; full inventory/roster → `RECEPTION_FULL`.

**On success:**
- Deduct coins (plant cost + substrate cost + additive costs).
- Consume 1 substrate from `inventoryByCategory.substrates`.
- Consume additives from inventory.
- Set plot attributes: `state = "Growing"`, `speciesId`, `plantedAt`, `ripeAt = plantedAt + species.growthTimeSeconds × growthMultiplier`, `substrate`, `plantedByUserId` (legacy alias for `ownerUserId`), `additives` (Phase 2+).
- Disable PlantPrompt, hide EmptyVisual, show GrowingVisual.
- Increment `stats.totalPlanted`.
- Fire `PlantCompleted` to client (S → C).

**On failure:** silent no-op server-side; fire `PlantCompleted` with `success=false, code=<reason>` so client UI can show "Not enough coins" etc.

### `SellInventory` — RESERVED

Currently unused. Sell action runs through ProximityPromptService server-side. Phase 1 replaces with the full Sell tab (see `Sell` remote below) but keeps `SellInventory` reserved as the legacy auto-sell-everything fast-path. Consider removing in Phase 1 cleanup.

### `SellCompleted` (S → C)

Fires when a sell transaction completes.

**Args:** `payout: number` — coins gained.

**Client handler:** shows the `+N coins` toast.

**Phase 1 changes:** `payout` argument expands to a struct so the toast can say "+50 coins (3 BrownCap, 1 LatticeVeil)" — better feedback.

```
{
    payout: number,
    items: { [itemId] = count }    -- what was sold
}
```

### `Brew` (C → S)

Player commits a brew action.

**Args:** `(method: string, ingredientIds: { string })` — method name, list of mushroom species ids (1–5 entries).

**Server validation:** see `Brewing.lua` (Pre-Alpha already implements). No changes in Phase 1.

### `BrewCompleted` (S → C)

Fires when a brew action resolves.

**Args:**
```
{
    success: boolean,
    potionId: string?,
    isNewDiscovery: boolean,
}
```

**Client handler:** shows the brew toast (Discovered / Brewed / Fizzles).

### `PlantSpecies` already documented above.

### `PlantPatch` — RESERVED

Currently unused. Reserved name from earlier design; can be removed in Phase 1.

---

## New remotes — Phase 1

### `ConsumePotion` (C → S)

Player consumes a potion from their inventory.

**Args:** `potionId: string`.

**Validation:**
1. Type-check: `potionId` is a string.
2. `Potions.byId[potionId]` exists.
3. `Inventory.count(data.inventoryByCategory.potions, potionId) >= 1`.

**On success:**
- Decrement potion count.
- Apply effect via `PotionEffects.apply(player, potion.effectKind, potion.effectParams)`.
- Fire `ActiveEffectsUpdated` (S → C).

**On failure:** fire `ConsumePotionFailed` with error code.

**Rate limit:** 2/sec. Players can spam-click but server throttles cheap.

### `ActiveEffectsUpdated` (S → C)

Replicates the player's currently-active potion effects to the client (for HUD chips).

**Args:**
```
{
    [effectKind] = {
        magnitude: number,
        endsAt: number,    -- os.time()-style
    },
    -- ...
}
```

**Notes:** server fires this on apply, on expiry, and on player join. Client renders a chip per kind; live countdown computed locally from `endsAt`.

### `ReputationChanged` (S → C)

Replicates a reputation-score change to the client (for tier-up animations and profile UI).

**Args:**
```
{
    npcId: string,
    oldScore: number,
    newScore: number,
    oldTier: string,    -- "Acquaintance" / "Familiar" / ...
    newTier: string,
}
```

**Client handler:** updates profile UI. If `oldTier != newTier`, plays a brief tier-up animation in NPC dialogue (if open) or queues for next dialogue open.

### `ConsumePotionFailed` (S → C)

Fires when a `ConsumePotion` request is rejected.

**Args:** `{ code: string, potionId: string? }`.

### `ClaimSpirit` (C → S)

Player claims a wandered-in spirit Model.

**Args:** `spiritWorldInstance: Instance` — reference to the spirit Model in Workspace.

**Validation:**
1. Type-check: `spiritWorldInstance` is an Instance, exists, has `isUnclaimedSpirit=true`.
2. Player is within `Constants.SPIRITS.claimRange` studs of the spirit.
3. Player roster has space (`#data.spirits.activeRoster < rosterCap`).
4. Spirit hasn't been claimed by another player (race-condition guard via attribute toggle).

**On success:**
- Set spirit attribute `isUnclaimedSpirit = false`.
- Add to player's `spirits.activeRoster` and `spirits.allOwned`.
- Despawn the world Model.
- Fire `SpiritClaimCompleted` (S → C).

### `EquipSpirit` / `UnequipSpirit` (C → S)

Move a spirit between active roster and inventory.

**Args:** `spiritId: string`.

**Validation:** standard ownership + capacity checks.

### `BuyFromMerchant` (C → S)

Buy item from any merchant NPC's shop.

**Args:** `(npcId: string, itemId: string, quantity: number)`.

**Validation:**
1. NPC exists and is a merchant.
2. Player is within talk range of NPC.
3. Merchant config (in `Constants.MERCHANTS[npcId]`) lists `itemId` for sale.
4. Player has `quantity * unitPrice` coins.
5. Resulting inventory wouldn't exceed slot/stack caps.
6. (For gated items) Player meets reputation gate with this NPC.

**On success:**
- Deduct coins.
- Add item × quantity to inventory.
- Apply rep gain (small bonus per coin spent).
- Fire `ShopTransactionCompleted` (S → C).

### `SellToMerchant` (C → S)

Sell items from inventory to merchant.

**Args:** `(npcId: string, items: { [itemId] = quantity })`.

**Validation:**
1. NPC exists and is a merchant.
2. Player is within talk range.
3. Merchant config specifies `buyCategories`; every itemId in the request must belong to a buyCategory the merchant accepts.
4. Player has each `(itemId, quantity)` in inventory.

**On success:**
- Compute payout per item using merchant's price formula (default = species/item base price × merchant's `buyMultiplier`).
- Add total payout to coins (via `Coins.add` chokepoint).
- Remove items from inventory.
- Apply rep gain (small bonus per coin earned, only if items were in NPC's preferred categories).
- Fire `ShopTransactionCompleted` (S → C) with the breakdown.

### `ShopTransactionCompleted` (S → C)

```
{
    success: boolean,
    code: string,       -- error code or OK
    npcId: string,
    items: { [itemId] = count }?,    -- what was bought / sold
    coinDelta: number?,              -- net coin change
}
```

### `RequestTrade` (C → S)

Send a trade request to another player.

**Args:** `targetPlayer: Player`.

**Validation:**
1. Both players are in the same server.
2. Both are inside the Trading Post zone.
3. Neither is already in a trade.
4. Sender's request cooldown has elapsed (20s default).

**On success:** fire `TradeRequestReceived` to target with sender info.

### `TradeRequestReceived` (S → C)

Notifies the target player of an incoming trade request.

**Args:** `{ fromPlayer: Player, fromName: string }`.

**Client handler:** shows accept/decline prompt with 20s timeout.

### `RespondToTradeRequest` (C → S)

Target accepts or declines.

**Args:** `(fromPlayer: Player, accept: boolean)`.

**On accept:** server creates a trade session; fires `TradeSessionStarted` to both.

### `TradeSessionStarted` (S → C)

```
{
    sessionId: string,
    partner: Player,
    partnerName: string,
}
```

Both players' clients open the Trade UI.

### `UpdateTradeOffer` (C → S)

Player modifies their offer in an active trade.

**Args:**
```
{
    sessionId: string,
    items: { [itemId] = count },    -- offered items
    coins: number,                  -- offered coin amount
}
```

**Validation:**
1. Session exists and player is in it.
2. Offered items exist in inventory.
3. Coins ≤ player's balance.
4. Trade is not in `Locked` state.

**On success:** server updates session state, fires `TradeOfferUpdated` to both players.

### `TradeOfferUpdated` (S → C)

Pushes both sides' current offers to both clients.

```
{
    sessionId: string,
    myOffer: { items, coins },
    theirOffer: { items, coins },
    state: "Editing" | "Locked" | "Confirming" | "Cancelled",
}
```

### `LockTradeOffer` (C → S)

Player clicks "Offer". Locks their side. When both are locked, state becomes `Confirming`.

### `ConfirmTrade` (C → S)

Player clicks "Accept" in the `Confirming` state. When both confirm, server executes.

### `CancelTrade` (C → S)

Player aborts. Trade ends; both keep their original items.

### `TradeCompleted` (S → C)

```
{
    success: boolean,
    code: string,
    sessionId: string,
    received: { items, coins }?,    -- on success: what came in
    given: { items, coins }?,
}
```

Server-side flow logs every trade to `MyceliaAuditLog_v1` regardless of outcome.

### `OpenStall` / `CloseStall` / `UpdateStallListing` (C → S)

Phase 2 stall management. Documented in detail in the stall spec (future).

### `StartExpedition` / `JoinExpeditionLobby` / `LeaveExpeditionLobby` / `ExpeditionLobbyUpdated` (C → S, S → C)

Phase 2 expedition flow. Future spec.

### `AcceptQuest` / `AbandonQuest` / `TurnInQuest` (C → S)

Quest interactions. Future spec.

### `QuestObjectiveUpdated` (S → C)

Fires whenever a tracked quest objective progress changes (auto-tracked via gameplay events server-side).

### `ChangeSettings` (C → S)

Player updates `data.settings`.

**Args:** `{ [settingKey] = value }` — partial update.

**Validation:**
1. Each key matches an allowed setting name.
2. Each value is in the allowed range/set.

**On success:** updates `data.settings`, fires `PlayerDataUpdated`.

### `RequestBiomeTravel` (C → S)

Player wants to travel to a different biome via the Travel NPC.

**Args:** `biomeId: string`.

**Validation:**

| # | Check | Failure code |
|---|---|---|
| 1 | Type-check: `biomeId` is a string. | `INVALID_INPUT` |
| 2 | `Constants.BIOMES[biomeId]` exists. | `NOT_FOUND` |
| 3 | Player has met biome's renown threshold (`Reputation.totalRenown(player) >= Constants.BIOMES[biomeId].unlockRenown`). | `UNAUTHORIZED` |
| 4 | Player passes `Constants.BIOMES[biomeId].unlockExtraGate(player)` if the biome has one (e.g., Glimmerwood lunar quest). | `UNAUTHORIZED` |
| 5 | Player has `data.coins >= Constants.BIOMES[biomeId].travelCostCoins`. | `INSUFFICIENT_FUNDS` |
| 6 | Player is currently in a Travel-NPC interaction range (server-side region check). | `LOCKED` |
| 7 | Player isn't in an active trade or expedition. | `LOCKED` |

**On success:**

- Deduct travel cost from coins via `Coins.spend`.
- Set `player:SetAttribute("currentBiome", biomeId)`.
- CFrame teleport player's `HumanoidRootPart` to `Constants.BIOMES[biomeId].spawnPoint` (no `TeleportService` per [ADR 001](../decisions/001-biome-architecture.md)).
- Mark `data.stats.biomesUnlocked[biomeId] = true` if not already (some biomes are reached by travel without prior renown unlock — e.g., quest-driven biome reveals).
- Fire `BiomeTravelCompleted` to client.
- Trigger plot-rebuild for the destination biome (instantiate plots from `data.plots` filtered to `biomeId == biomeId`).

### `BiomeTravelCompleted` (S → C)

```
{
    success: boolean,
    code: string,
    biomeId: string?,        -- only on success
    spawnPoint: Vector3?,    -- only on success
}
```

Client uses `BiomeTravelCompleted` to:
- Trigger atmosphere transition (already running on RenderStepped, but this gives an authoritative cue).
- Show a "Welcome to Misty Hollow" toast or similar.
- Update local biome-display UI elements.

### `RequestVisitHut` (C → S)

Player requests to visit another player's hut.

**Args:** `targetUserId: number`.

**Validation:**
1. Target's `settings.hutAccessLevel` allows it (public, or friends-only with sender on friends list).
2. Target is online OR target's hut state can be loaded server-side without them present.

**On success:** TeleportService teleport (or in-world Region teleport per [decision 001](../decisions/001-biome-architecture.md)).

### Camera / Cinematic remotes (S → C)

These are server-pushed signals that trigger client-side camera moments.

- `CinematicDiscovery(speciesId, position)` — orbit camera around discovery point for ~2s.
- `CinematicLunarEvent(eventLocation)` — pan all clients' cameras to event location.
- `WorldShake(amplitude, duration)` — small camera shake on rare events.

Clients that have `settings.reducedMotion = true` skip cinematic camera moments.

---

## Rate-limit configuration

```lua
Constants.RATE_LIMITS = {
    default                    = { calls = 5, per = 1 },
    PlantSpecies               = { calls = 2, per = 1 },     -- expensive op
    Brew                       = { calls = 2, per = 1 },     -- expensive op
    ConsumePotion              = { calls = 2, per = 1 },
    BuyFromMerchant            = { calls = 5, per = 1 },
    SellToMerchant             = { calls = 5, per = 1 },
    RequestTrade               = { calls = 1, per = 20 },    -- 1 per 20 seconds
    UpdateTradeOffer           = { calls = 10, per = 1 },    -- frequent during trading
    LockTradeOffer             = { calls = 2, per = 1 },
    ConfirmTrade               = { calls = 2, per = 1 },
    ChangeSettings             = { calls = 5, per = 1 },
    RequestVisitHut            = { calls = 1, per = 5 },
}
```

Global rate-limit middleware in `Remotes.lua`. Applied transparently — handlers don't need to think about it.

---

## Validation skeleton (template)

Every C→S handler follows this shape:

```lua
Remotes.get(Constants.REMOTES.MyRemote).OnServerEvent:Connect(
    function(player, arg1, arg2, ...)
        -- 1. Rate limit (handled by middleware; handler is invoked only if allowed)

        -- 2. Type checks
        if typeof(arg1) ~= "string" then return end
        if type(arg2) ~= "number" then return end
        -- ...

        -- 3. Range / id validation
        if not SomeRegistry[arg1] then return end
        if arg2 < 0 or arg2 > MAX then return end

        -- 4. Player state validation
        local data = PlayerData.get(player)
        if not data then return end
        if data.someState ~= "ExpectedState" then return end

        -- 5. Permission / ownership
        if not playerCanDoThing(player, arg1) then return end

        -- 6. Mutate state (atomic; via PlayerData.update)
        PlayerData.update(player, function(d)
            -- mutations
        end)

        -- 7. Notify client of result (success or failure)
        Remotes.get(Constants.REMOTES.MyRemoteCompleted):FireClient(player, {
            success = true,
            ...
        })
    end
)
```

Invalid requests are dropped silently server-side. The corresponding `*Completed` remote fires with `success=false, code=<reason>` only if the client actively needs to know (e.g., to show an error toast). For pure no-ops (rate-limited, malformed input from a clearly-buggy client), the server logs and drops without notification.

---

## Tests

Per remote, `Tests/Remotes_<RemoteName>Spec.lua` should cover at least:

- Happy path: valid args → state mutates correctly → success notification fires.
- Type-mismatch: invalid arg type → no state change, no client notification.
- Missing prerequisite: player lacks required state → `*Failed` notification with correct code.
- Rate-limit: rapid calls → some dropped silently.
- Cross-player isolation: player A's call doesn't affect player B's data.

Per the Definition of Done in [CONTRIBUTING.md](../CONTRIBUTING.md), every server-side remote handler ships with these three tests minimum (happy path, unauthorized input, rate-limit).
