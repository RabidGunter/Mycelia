# Shop UI — Spec

The shared Buy / Sell UI used by every merchant NPC in Mycelia. Replaces the Pre-Alpha witch auto-sell with a configurable per-merchant interaction.

This is the first user-facing piece of Phase 2 Closed Beta. Architectural pieces it locks in:
- Pattern for routing player→NPC interaction through a server `OpenShop` event.
- Per-merchant config table (`Constants.MERCHANTS`) used by every future merchant (Substrate Dealer, Spore Merchant, Spirit Food, Cosmetic, Decoration).
- Reputation shim (`src/shared/Reputation.luau`) — no-op until the full Reputation system lands; merchant configs reference `reputationKey` now so no schema migration is needed later.
- Inventory split: Sell reads legacy `data.inventory`; Buy writes to `data.inventoryByCategory[*]`. Documented as Phase 2 reality. Full reconciliation deferred to v4 prep.

Pairs with [remote-api.md](remote-api.md) §"BuyFromMerchant / SellToMerchant" for the wire-level remote contract.

---

## NPC config — `Constants.MERCHANTS[npcId]`

| Field | Type | Required | Description |
|---|---|---|---|
| `displayName` | string | yes | Shown as the shop UI title. |
| `description` | string | no | One-line tagline. Shown under title. |
| `talkRange` | number | no | Studs. Defaults to `Constants.MERCHANT_DEFAULTS.talkRange` (14). |
| `buyCategories` | `{string}` | yes | Inventory categories this merchant *buys from* the player. e.g. `{"mushrooms_raw"}`. |
| `buyMultiplier` | number | yes | Applied to species/item base price for sells. Witch = 1.0 (was `Constants.ECONOMY.witchPriceMultiplier`). |
| `itemsForSale` | `{[string]=ItemListing}` | yes | Items the merchant sells. May be `{}`. See *ItemListing* below. |
| `reputationKey` | string | no | Identifier used by `Reputation.add(player, key, delta)`. Defaults to `npcId` if omitted. |
| `repPerCoin` | number | no | Rep gain per coin transacted. Defaults to `Constants.MERCHANT_DEFAULTS.repPerCoin`. |
| `repGate` | number | no | Minimum rep with this NPC required to access this shop. Defaults to 0. |

### ItemListing
| Field | Type | Required | Description |
|---|---|---|---|
| `unitPrice` | number | yes | Coins per unit. |
| `category` | string | yes | Target `inventoryByCategory[<category>]` slot. e.g. `"substrates"`. |
| `repGate` | number | no | Per-item rep gate. 0 = unlocked at shop entry. |
| `displayName` | string | no | Override item display name (defaults to id). |

### Launch merchant set (Phase 2)

| npcId | Status | Notes |
|---|---|---|
| `ForestWitch` | **shipped** | Migrated from Pre-Alpha. Buys `mushrooms_raw` at 1.0×. Sells nothing. |
| `SubstrateDealer` | future | Will sell substrates. Empty config now. |
| `SporeMerchant` | future | Sells spores. |
| `SpiritFood` | future | Sells items that boost spirit attraction rolls. |
| `Cosmetic` | future | Cosmetic skins / decorations. |
| `DecorationVendor` | future | Hut decorations. |

---

## Wire flow

### Player initiates the interaction
1. Player walks within proximity-prompt range of an NPC anchor Part.
2. Anchor Part has attribute `merchantId = "<npcId>"` set by world build (MapSetup for the witch; future hand-built NPCs can set the attribute manually).
3. Player presses prompt key. `ProximityPromptService.PromptTriggered` fires server-side.
4. Server resolves `merchantId` from the prompt's parent Part.
5. Server fires `OpenShop` (S→C) to the triggering player with `{npcId, merchantConfig}`.

### Client opens the UI
6. Client receives `OpenShop`. Builds a card with Buy / Sell tabs (Buy hidden if `itemsForSale` is empty).
7. **Sell tab default state: every row preselected with quantity = full inventory count.** One click on "Confirm Sell" sells everything — preserves the Pre-Alpha frictionless experience while letting players uncheck rows or tweak quantities.

### Player confirms Sell
8. Client fires `SellToMerchant(npcId, items)` where `items = { [itemId] = quantity }`.
9. Server runs full validation (talk range, ownership, category match, no zero/negative quantities).
10. On success: deduct items via `Inventory.remove`, add coins, fire `Reputation.add`, fire `ShopTransactionCompleted`.

### Player confirms Buy
11. Client fires `BuyFromMerchant(npcId, items)`.
12. Server validates (talk range, items in `itemsForSale`, sufficient coins, no rep-gate violations).
13. On success: deduct coins, add items to `inventoryByCategory[itemListing.category]`, fire `Reputation.add`, fire `ShopTransactionCompleted`.

### Both paths end with
14. Client receives `ShopTransactionCompleted` with breakdown. Closes UI (or stays open if user wants another transaction). Shows toast.

---

## Validation matrix

| Check | Sell | Buy | Error code |
|---|---|---|---|
| `npcId` exists in `Constants.MERCHANTS` | ✓ | ✓ | `UNKNOWN_MERCHANT` |
| Player within `talkRange` of merchant anchor | ✓ | ✓ | `OUT_OF_RANGE` |
| `items` is a non-empty table of `{[itemId]=positiveInt}` | ✓ | ✓ | `INVALID_REQUEST` |
| Each itemId resolves (Sell: `Species.byId` for mushrooms; Buy: `merchant.itemsForSale[itemId]`) | ✓ | ✓ | `UNKNOWN_ITEM` |
| Sell: itemId's category is in `merchant.buyCategories` | ✓ | — | `CATEGORY_REJECTED` |
| Sell: player has each `(itemId, quantity)` in `data.inventory` | ✓ | — | `INSUFFICIENT_INVENTORY` |
| Buy: player has `coins >= sum(quantity * unitPrice)` | — | ✓ | `INSUFFICIENT_COINS` |
| Buy: player meets `merchant.repGate` and per-item `repGate` | — | ✓ | `REP_GATE` |
| Player not in another active session (trade, expedition) | ✓ | ✓ | `LOCKED` (future) |

`LOCKED` is added when Trading Post + Expeditions land. For Phase 2 Shop, only Sell can race against a future trade — defer the check.

---

## Inventory split (Phase 2 reality)

Phase 1 introduced `inventoryByCategory` alongside the legacy `data.inventory` ([HANDOFF.md:185](../../HANDOFF.md:185)). The two don't auto-sync.

**Phase 2 Shop:**
- **Sell** mutates `data.inventory` (mushroom-only, where every gameplay system currently writes/reads).
- **Buy** mutates `data.inventoryByCategory[itemListing.category]` (already the canonical home for non-mushroom items per [save-schema-v3.md](save-schema-v3.md)).

This is asymmetric on purpose. Future migrations:
- v4 prep moves all mushroom systems (Harvesting, Brewing, Planting, Selling) onto `inventoryByCategory.mushrooms_raw`.
- Drop `data.inventory` from the schema and add a one-time sync step in v3→v4 migration.
- Trading Post and Stalls will read `inventoryByCategory` directly because they need to surface non-mushroom items too.

Don't write tooling that reconciles the two tables in the meantime — every reconciliation pass becomes a different migration to undo later.

---

## Reputation shim

`src/shared/Reputation.luau` exposes:

```lua
Reputation.add(player, key, delta)  -- log-only stub for now
Reputation.get(data, key) -> number  -- defensive read of data.reputation[key].score
```

Until the full Reputation system lands (Phase 2/3), `Reputation.add` prints `[Reputation] +N <key> for <PlayerName>` and does **not** mutate save data. This keeps merchant configs forward-compatible: when the real Reputation system ships, it replaces this module and all `Reputation.add` callsites become live without a refactor.

`Reputation.get` reads the score off of v3's `data.reputation[npcId].score` field (already in the schema, default 0). Travel.luau also reads this directly today; consolidation of those reads into Reputation can happen lazily.

---

## UI surface

The Shop UI is the first new UI to consume `Constants.UI` (the palette tokens added in this commit per [visual-language.md](visual-language.md)). Conventions:

- **Top:** merchant title (Merriweather H2) + tagline (Nunito caption).
- **Tabs:** Buy / Sell (Nunito Bold). Active tab gets `forest.mid` underline; inactive is muted.
- **Tab body:** `ScrollingFrame` of rows. Each row:
  - Rarity dot (4px circle, `Constants.UI.rarity[species.tier]`).
  - Item name (Nunito Bold).
  - Owned count / available count (Nunito caption, `text.secondary`).
  - Quantity input (`+`/`-` stepper or text input on desktop).
  - Per-row total (Inconsolata Bold, `accent.gold`).
- **Footer:** running total (Inconsolata 18pt, `accent.gold`), "Cancel" + "Confirm" buttons (`forest.mid` primary).
- **Mobile:** card fills 92% width, max 440px. Buttons 44pt min tap target. Bottom-anchored footer.
- **Glimmerwood / dark-mode override:** later. Light theme only for Phase 2.

UI builds in plain Roblox Instance code (no Roact for now — matches existing client conventions in `JournalController.client.luau`).

---

## Tests (`Tests/ShopSpec.luau`)

Pure helpers covered:
- `Shop.priceFor(merchant, itemId)` — known mushroom species (Common/Uncommon/Rare/Epic), unknown id → 0.
- `Shop.totalSellPrice(merchant, items)` — empty, single, multi, ignores unknowns. **Pins the same numeric values as the original SellingSpec** (witch payouts haven't changed).
- `Shop.canSell(merchant, itemId)` — category match, mismatch, unknown item.
- `Shop.canBuy(merchant, itemId)` — for-sale lookup, non-listed item.
- `Shop.validateSell(merchant, items, inventory)` — happy path, missing inventory, category-rejected, empty request.
- `Shop.validateBuy(merchant, items, coins, inventoryByCategory)` — happy path, insufficient coins, unknown item.
- `Constants.MERCHANTS` integrity — every merchant has required fields; every `buyCategories` entry is a real `inventoryByCategory` key.

Roblox-bound code (talk-range, remote handlers) deliberately uncovered — those need integration testing in Studio, not unit tests.

---

## Migration from Pre-Alpha witch

| Was | Becomes |
|---|---|
| `Constants.ECONOMY.witchPriceMultiplier = 1.0` | `Constants.MERCHANTS.ForestWitch.buyMultiplier = 1.0` (old constant deleted) |
| `Selling.priceOf(inv)` | `Shop.totalSellPrice(Constants.MERCHANTS.ForestWitch, inv)` |
| `Selling.start()` (auto-sell on prompt) | `Shop.start()` (prompt fires `OpenShop` → client UI) |
| `SellInventory` / `SellCompleted` remotes | Removed. Replaced by `SellToMerchant` / `ShopTransactionCompleted` / `OpenShop`. |
| `SellToast.client.luau` | Removed. Confirmation toast lives inside the Shop UI itself. |
| `SellingSpec` tests | Replaced by `ShopSpec` — same numeric pins, expanded coverage. |

The witch's player-facing behavior is unchanged on the happy path: walk up, press E, confirm, items become coins. The only added click is the Confirm button — and the spec calls for it specifically as anti-misclick UX (#1 confirmed).

---

*Last touched: 2026-05-02. Status: shipped in this same commit.*
