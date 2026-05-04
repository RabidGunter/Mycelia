# Trading Post — Spec

The player-driven trade economy. Two players negotiate item-for-item exchanges through a synchronized modal with anti-scam UX (lock + countdown + confirm).

The marquee Phase 2 feature, and the foundation Player Stalls + future LiveOps trading events build on. Pairs with [remote-api.md §281–381](remote-api.md) for the wire-level remote contract.

---

## Architectural decisions (confirmed 2026-05-03)

1. **Trade sessions live in-memory only.** Server keeps active sessions in a `[sessionId] = TradeSession` table. Lost if the server crashes mid-trade — both players keep their original items (failure-safe). DataStore is **only** for the immutable audit log.
2. **No Trading Post zone gate yet.** Phase 2 ships the backend + UI with no spatial restriction. A placeholder "Trading Post" Part exists at the spawn pad for navigation hint. Real zone (per remote-api.md spec) lands in a follow-up commit alongside Player Stalls.
3. **Adopt Me anti-scam UX.** Lock → 5-second countdown → both players Confirm → atomic execute. Modifying offer during countdown reverts both sides to "Open" and resets the countdown.

---

## Trade session state machine

```
        RequestTrade            RespondToTradeRequest:accept
   --------------------->  Pending  ------------------------->  Open  <----+
                              |                                  |        |
                              | RespondToTradeRequest:decline    |        | UpdateTradeOffer
                              v                                  v        |
                           Cancelled                           Locked-----+
                                                                  |
                                                                  | (5s countdown,
                                                                  |  both Confirm)
                                                                  v
                                                              Completed
                                                                  ^
                              CancelTrade (any party, any state) -+
```

**Reverts:**
- Locked → Open if either party fires `UpdateTradeOffer` (the offer changed; countdown invalid). Both clients see lock buttons clear.

**Locks:**
- A player who has fired `LockTradeOffer` cannot fire `UpdateTradeOffer` until the other side modifies (which puts both back to Open) or trade cancels.

---

## TradeSession shape (in-memory only)

```lua
{
    sessionId = "uuid-string",
    state     = "Pending" | "Open" | "Locked" | "Completed" | "Cancelled",
    a = { player = Player, offer = { coins = 0, items = { [itemId] = qty } }, locked = false, confirmed = false },
    b = { player = Player, offer = { coins = 0, items = { [itemId] = qty } }, locked = false, confirmed = false },
    lockedAt = number?,    -- os.time() when state first became Locked
    createdAt = number,
}
```

Both `a` and `b` mirror each other — `a` is conventionally the requester, `b` the target. Server tracks both indexes; clients only see "you" and "them" labels.

---

## Validation matrix

| Check | Where | Error code |
|---|---|---|
| Target is real online player | RequestTrade | `INVALID_TARGET` |
| Sender ≠ target | RequestTrade | `SELF_TRADE` |
| Neither party in another session | RequestTrade, RespondToTradeRequest | `ALREADY_IN_TRADE` |
| Cooldown elapsed (20s per spec) | RequestTrade | `COOLDOWN` |
| Item quantities are positive ints | UpdateTradeOffer | `INVALID_REQUEST` |
| Coins offered ≥ 0 and ≤ player's balance | UpdateTradeOffer (at validation time) | `INSUFFICIENT_COINS` |
| Player has each (itemId, qty) | UpdateTradeOffer + at confirmation | `INSUFFICIENT_INVENTORY` |
| Trade in correct state for the action | every C→S | `INVALID_STATE` |
| Both players still online | at confirmation | `PLAYER_DISCONNECTED` |

Validation runs at every C→S edge. Coin/inventory checks at confirmation are mandatory — items can disappear during the negotiation (Pre-Alpha brewing consumes ingredients, planting spends coins).

---

## Atomic execution (on dual Confirm)

1. Server snapshots both players' relevant inventory + coin state at confirm time.
2. **Re-validate** both offers against current inventory (the second mandatory check).
3. If validation fails: cancel the trade with `INSUFFICIENT_INVENTORY` or `INSUFFICIENT_COINS`. No mutations. Log audit entry.
4. **Mutate A:** subtract offerA, add offerB. Wrapped in PlayerData.update.
5. **Mutate B:** subtract offerB, add offerA. Wrapped in PlayerData.update.
6. If step 5 fails for any reason (player disconnected mid-execute, etc.): roll back step 4 from snapshot. Log audit failure. Cancel trade.
7. On success: log audit entry, fire `TradeCompleted` to both, clear session.

Roblox doesn't have transactional DataStore writes. "Atomic" here = validate-before-mutate + snapshot-rollback on partial failure. Tests cover the validation step; rollback is a defensive backstop for extreme cases.

---

## Inventory split (Phase 2 reality)

Same rules as Shop UI — see [shop-ui.md](shop-ui.md) "Inventory split":
- Mushroom species ids → legacy `data.inventory`
- Non-mushroom item ids → `data.inventoryByCategory[item.category]`

Trade offers carry `{ [itemId] = qty }` payloads. Server routes each item to the right bucket using `Species.byId[id]` vs `Constants.ITEMS[id]` lookup.

---

## Audit log

Separate DataStore: `MyceliaAuditLog_v1`. Schema:
```lua
{
    sessionId = "uuid",
    timestamp = number,    -- os.time()
    outcome = "completed" | "cancelled",
    cancelReason = string?,    -- when cancelled
    a = { userId = number, name = string, gave = { coins, items }, got = { coins, items } },
    b = { ... same shape ... },
}
```

Key: `"trade_" .. sessionId`. Append-only — never overwritten. DataStore throttle (6/min/key) doesn't apply because each session writes to a unique key.

Phase 2 logs only on terminal states (Completed / Cancelled). Per-transition logging (every Lock, every Update) is overkill for current scale; can layer in later if exploit forensics demand it.

If the audit DataStore write fails (network blip, service down): log a warning, continue with the trade. Future hardening: a backlog queue that retries on next save tick.

---

## UI surface

### Player-picker modal

Triggered by a "Trade" button in the HUD (next to Journal). Lists online players (excluding self) with a "Request" button per row. Clicking fires `RequestTrade` and shows "Waiting for [name]…" toast.

### Incoming trade request

When `TradeRequestReceived` fires, target sees a small notification toast at the top of the screen with `{Accept} {Decline}` buttons. 30-second timeout — auto-declines.

### Trade modal

Two-panel side-by-side card (mobile: stacked vertically). Each panel:
- **Header:** player name, online indicator, lock status icon
- **Offer area:** 6-slot item grid + coin input field
- **Status:** "Editing", "Locked", "Confirmed", "Waiting for {other}"

Center between panels: countdown timer (5s on Lock → 0), Confirm button (greys out unless both Locked).

Bottom: Cancel button (always visible).

Lock + Confirm flow:
1. Player clicks **Lock** → their lock indicator lights up; if other side already locked, countdown starts.
2. During countdown, either player modifying their offer reverts both to Open + clears countdown.
3. Countdown reaches 0 → **Confirm** button enables for both. Each clicks Confirm independently.
4. When both confirmed, server runs atomic execution.

Disconnect during trade: server detects via Players.PlayerRemoving; auto-cancels session, fires TradeCompleted with `success=false, code="PLAYER_DISCONNECTED"`.

### Item picker submodal

Click an empty offer slot → submodal lists player's tradable items (legacy inventory + every `inventoryByCategory.*` entry where the matching `Constants.ITEMS[itemId].tradable == true`). Per-row qty stepper. "Add" confirms; "Cancel" backs out.

Click a filled offer slot → removes the item from offer (one-step, no confirmation).

---

## Tests (`Tests/TradeSpec.luau`)

Pure helpers covered:
- `Trade.canRequest(senderData, targetData, activeSessions)` — happy path, target busy, sender busy, cooldown.
- `Trade.validateOffer(offer, data)` — happy path, missing items, insufficient coins, fractional/negative qty.
- `Trade.computeNetMutation(offerA, offerB)` — symmetry (A loses what B gains, A gains what B loses).
- `Trade.applyOffer(data, offerToReceive, offerToGive)` — pure helper that mutates a snapshot; tests cover both inventory + inventoryByCategory routing.
- TradeSession state transitions — Open → Locked when both `lock=true`, Locked → Open if anyone updates, etc.

Roblox-bound side (DataStore audit, remote dispatch, UI) — Studio integration tests, not unit.

---

## Future-proofing

Player Stalls (next Phase 2 piece) use the same atomic-execution primitives. The `Trade.applyOffer` pure helper becomes `Stall.applyPurchase` with one-sided semantics. Audit log shape extends with a `kind` field (`"trade"` / `"stall_purchase"` / `"trade_event_lottery"`).

Trading Post zone (Phase 2 polish): `Trade.canRequest` adds a check that both players are within the zone Part. Trivial extension; no schema change.

Spatial Voice (Phase 3 polish): when both players enter trade modal, server flips a chat channel attribute. Independent system; doesn't touch the trade state machine.

---

*Last touched: 2026-05-03. Status: foundation shipping in this commit (backend + UI + audit + tests). Trading Post zone + per-remote rate limits + Spatial Voice are follow-ups.*
