# Constraints (synthesized from SPECs)

12 SPECs cover technical contracts: data tables, schemas, API surfaces, protocol/state-machine descriptions, and visual tokens. Every constraint below is per-spec; the Shop UI spec already shipped (Phase 2 first milestone). All others are mixed shipped/in-progress/pending — see context.md (HANDOFF section) for current implementation state.

---

## CONSTRAINT-species-data: Species + Substrate Data Tables

- **source:** docs/specs/species-data.md
- **type:** schema (data tables)
- **summary:** Complete data shape for the 15 Pre-Alpha species (6 Common / 5 Uncommon / 3 Rare / 1 Epic) and 6 substrates. Implements ADR 002's `yieldBySubstrate` and `rareVariantId` requirements.
- **key constraints:**
  - **Substrates table** (`Constants.SUBSTRATES`): 6 entries — compost (5c, default), hardwood (5c, rep gate 100), straw (5c, rep gate 100), dung (5c, quest gate `SM_introduce_dung`), peat (25c, rep gate 500), magical_loam (200c, rep gate 1500). All gates against SubstrateMerchant NPC.
  - **`Constants.SUBSTRATE_ORDER`** array enforces consistent UI iteration.
  - **Species fields:** id (immutable save key), displayName, tier, description, baseSellPrice, growthTimeSeconds, substratePref (UI hint), yieldBySubstrate, lightPref/moisturePref/pHPref (Phase 2+ usage), rareVariantId, brewingTags.
  - **Validation rules** (in `Tests/SpeciesSpec.lua`): unique ids; valid tiers; ≥1 yieldBySubstrate key with value >0; all keys reference real substrate ids; values in [0.0, 2.0]; rareVariantId references existing species at next-tier-up; baseSellPrice/growthTimeSeconds positive; substratePref entries appear in yieldBySubstrate with value ≥1.0.
  - **Authoring guidance:** Commons should have 4+ viable substrates; Uncommons 2–3; Rares 1–2; Epics 1. Magical loam yields 1.0–1.2 (Common bonus), 0.8–0.9 (Uncommon penalty), 0.8 (Rare penalty), 1.0 (Epic only viable).

---

## CONSTRAINT-save-schema-v3: PlayerData v3 Shape + Migration

- **source:** docs/specs/save-schema-v3.md
- **type:** schema (save data)
- **summary:** Complete v3 PlayerData shape, idempotent v1→v2→v3 migration, ProfileService integration pattern, public PlayerData API contract.
- **top-level fields:** schemaVersion=3 · coins · inventory (legacy mushrooms) · inventoryByCategory (11 categories: mushrooms_raw, mushrooms_dried, potions, spores, substrates, additives, recipes, spirit_items, quest_items, cosmetics, tools) · spirits {activeRoster, allOwned} · decorations {unlocked, placed} · plots · stats (with new v3 counters: totalRareVariants, totalPlotFailures, totalDistanceWalked, spiritsCollected, biomesUnlocked, questsCompleted, recipesAttempted, recipesDiscovered) · reputation · activeQuests · gamepassesOwned · settings · auditTrail.
- **key constraints:**
  - `inventoryByCategory` per-stack max 999; per-category 32 slots default (+4 rows per Inventory Expansion gamepass).
  - `spirits.allOwned` keyed by uniqueId format `spiritType_userId_timestamp`; `spiritType` stored explicitly (not parsed from uniqueId).
  - `spirits.activeRoster` is a subset of `allOwned` keys; cap = `STARTING_SPIRIT_ROSTER_SIZE` (3) + gamepass bonus (+3).
  - Plots persist across sessions; `plotIndex` maps to world position via `biome.plotOrigin + Vector3.new((plotIndex-1) * Constants.CULTIVATION.plotSpacing, 0, 0)`. Default plotSpacing=7.
  - Reputation per-NPC fields: `{ score, firstMet, lastDailyGreeting }`. Score capped at 5000 (per ADR 003).
  - Settings: 9 fields including `hutAccessLevel` ("private"/"friends_only"/"public"), `reducedMotion`, `showPotionHints`.
  - **Migration is idempotent.** Always check `data.schemaVersion < N`. Forward-compat: `Reconcile()` backfills additive fields. Field renames require explicit migration steps.
- **ProfileService contract:**
  - Vendored at `src/ServerScriptService/Vendor/ProfileService.lua`.
  - Store key `MyceliaPlayerData_v1` is **immutable** (changing it orphans all existing saves; schema versions tracked inside data, not in store key).
  - `LoadProfileAsync("u_" .. UserId, "ForceLoad")`. On nil return → kick player (don't silently fail — losing data is worse than re-joining).
  - `profile:Reconcile()` after migrate. `profile:ListenToRelease()` for cross-server takeover handling.
  - Public API preserved: `PlayerData.get(player)` / `update(player, fn)` / `save(player)`.

---

## CONSTRAINT-remote-api: Server-Authoritative Remote Contracts

- **source:** docs/specs/remote-api.md
- **type:** api-contract
- **summary:** Every RemoteEvent / RemoteFunction in Mycelia with signature, direction, validation rules, error codes, rate limits.
- **conventions:** PascalCase remote names in `Constants.REMOTES`. Direction `C → S` (client fires) / `S → C` (server fires) / `C ↔ S` (RemoteFunction). Validation philosophy: type-check → range/id → permission → mutate. Failure modes are silent unless UI requires the response.
- **error code taxonomy:** OK, INVALID_INPUT, NOT_FOUND, INSUFFICIENT_FUNDS, INSUFFICIENT_INVENTORY, LOCKED, RATE_LIMITED, RECEPTION_FULL, UNAUTHORIZED, INTERNAL.
- **rate limits** in `Constants.RATE_LIMITS` (default 5/sec). Notable overrides: PlantSpecies 2/sec, Brew 2/sec, ConsumePotion 2/sec, RequestTrade 1/20s, UpdateTradeOffer 10/sec, RequestVisitHut 1/5s.
- **remote inventory (existing + Phase 1+2):**
  - Pre-Alpha: PlayerDataUpdated, HarvestMushroom (RESERVED, unused), PlantSpecies, Brew, BrewCompleted, PlantPatch (RESERVED).
  - **PlantSpecies CHANGES IN PHASE 1**: `(plot, speciesId, substrateId, additives)` — full cultivation flow. 10 validation rules with specific error codes per rule.
  - **REMOVED in Phase 2**: SellInventory / SellCompleted (superseded by Shop UI flow).
  - Phase 1 new: ConsumePotion, ConsumePotionFailed, ActiveEffectsUpdated, ReputationChanged, ClaimSpirit, SpiritClaimCompleted, EquipSpirit, UnequipSpirit, PassiveBonusesUpdated, RequestBiomeTravel, BiomeTravelCompleted, BiomeUnlocked.
  - Phase 2 new: OpenShop, BuyFromMerchant, SellToMerchant, ShopTransactionCompleted, RequestTrade, TradeRequestReceived, RespondToTradeRequest, TradeSessionStarted, UpdateTradeOffer, TradeOfferUpdated, LockTradeOffer, ConfirmTrade, CancelTrade, TradeCompleted, OpenDialogue, DialogueAction, AcceptQuest, TurnInQuest, AbandonQuest, QuestObjectiveUpdated.
  - Future: OpenStall/CloseStall/UpdateStallListing (Player Stalls), StartExpedition/JoinExpeditionLobby/etc. (Expeditions), ChangeSettings, RequestVisitHut, Cinematic remotes (CinematicDiscovery, CinematicLunarEvent, WorldShake).
- **biome travel** explicitly uses `HumanoidRootPart.CFrame` teleport per ADR 001 — never `TeleportService` for in-world travel.
- **validation skeleton** (template enforced for every C→S handler): rate-limit middleware → type checks → range/id validation → player state → permission/ownership → atomic mutate via `PlayerData.update` → notify result.

---

## CONSTRAINT-potions-and-recipes: Recipes, Potions, Effects

- **source:** docs/specs/potions-and-recipes.md
- **type:** schema (data tables) + protocol
- **summary:** 20 brewing recipes (6 existing + 14 new), 20 potion catalog entries, 10 potion effect kinds with parameters, stacking rules, PotionEffects.lua module structure.
- **recipe key format:** `method .. "|" .. table.concat(sortedIngredientIds, ",")`. Failed brews consume ingredients (engagement-design cost).
- **distribution:** 5 Easy (commons-only) · 8 Mid (uncommons or specific common combos) · 5 Hard (rares/epics). Two intentional alt-paths (DewdropTonic via 2× FairyCup; InkblotElixir via Buttoncap+Inkpot).
- **potion shape:** `{ displayName, description, rarity, effectKind, effectParams, durationSeconds }`. Naming convention: `*Powder` from dry-grind, `*Tonic`/`*Brew`/`*Infusion` from steep/boil, `*Elixir`/`*Cordial` from ferment, `*Essence` for crystalline/refined.
- **10 effect kinds** (in `PotionEffects.lua`, handler-table dispatch): speed, growth, wildYield, harvestYield, luck, reveal, spiritAttract, cosmeticGlow, weatherSummon (Phase 4 stub), timeShift (Phase 4 stub).
- **stacking rules per kind:** speed/wildYield/harvestYield/luck/reveal/spiritAttract → max-of, refresh timer; growth → min-of (better stacks); cosmeticGlow/weatherSummon → replace; timeShift → refresh boolean.
- **module API contract:** `PotionEffects.apply(player, kind, params, durationSeconds)`, `revert(player, kind)`, `isActive(player, kind)`, `getMultiplier(player, kind)`, `start()`. Per-player active registry: `{ [player] = { [effectKind] = { magnitude, endsAt, params } } }`.
- **server-side only:** Recipes table is never replicated to clients (would spoil discovery).
- **stats counters:** `recipesAttempted` increments on NEW combinations only; `recipesDiscovered` records `key → potionId` map.

---

## CONSTRAINT-spirits: Forest Spirits System

- **source:** docs/specs/spirits.md
- **type:** schema + protocol + module-contract
- **summary:** Complete catalog (3 Common + 3 Rare + 1 Legendary), attraction algorithm, claim flow with race-condition handling, equip/unequip, wandering AI, trading, PassiveBonuses module, Crystal Shard item.
- **catalog:** Common (Mossling/Spritefly/Dewdrop, +5% bonuses) · Rare (Lanternfox/Crystalmoth/Deerlet, +15% bonuses + unique mechanics) · Legendary (ForestMother — Phase 4 lunar event spawn, server-wide bonuses).
- **roster cap:** `Constants.SPIRITS.startingRosterSize` (3) + `biggerRosterGamepassBonus` (3) = 6 with gamepass.
- **attraction algorithm:** per-player tick every `attractionTickSeconds` (300s default). Sum holdings (inventory + Growing/Ripe plots, deduped). For each spirit type: `chancePerTick = sum(attractionMap[spiritId][species]) / (3600/attractionTickSeconds) × spiritAttract_potion_multiplier`. Independent rolls per spirit type. Skip players in non-biome contexts (expedition, hut interior).
- **spawn contract:** Models from `ReplicatedStorage.SpiritModels.<spiritId>` (user-supplied, named exactly the spiritId). Set attributes: `isUnclaimedSpirit=true`, `spawnedFor=UserId`, `spiritType`, `spawnedAt`. Despawn after `unclaimedDespawnSeconds` (300s).
- **claim flow** (atomic check-and-set): set `isUnclaimedSpirit=false` first, then validate (spawnedFor match, range, roster space), revert on any failure. UniqueId format: `spiritType_userId_timestamp`.
- **wandering AI:** Heartbeat tick. Idle (20%/sec chance to start walking) → Walking (linear movement to random point in wanderRadius). Common 8 stud radius / Rare 12. walkSpeed=4.
- **trading:** Spirits live in `data.spirits`, not `inventoryByCategory`. Removed from activeRoster on offer (passive bonus recomputed). On success: removed from sender's allOwned, new entry created in recipient's allOwned with new uniqueId. spiritType + obtainedAt preserved. Recipient does NOT get auto-equipped.
- **PassiveBonuses module** (separate from PotionEffects): per-player registry of permanent bonus totals by kind. `PassiveBonuses.recomputeForPlayer(player)` on every claim/equip/unequip/trade. Combined with PotionEffects additively: `total = PassiveBonuses.get(player, kind) + PotionEffects.get(player, kind)`.
- **Crystal Shard:** `Constants.ITEMS.CrystalShard` — Crystalmoth's daily midnight drop. Tradable, stackable, category="tools", baseSellPrice=50.

---

## CONSTRAINT-biome-config: Biome Schema + Misty Hollow

- **source:** docs/specs/biome-config.md
- **type:** schema (config) + protocol
- **summary:** `Constants.BIOMES` schema, complete StarterGlade + MistyHollow configs, atmosphere/lighting transition contract, StreamingEnabled tuning, travel NPC contract, biome unlock trigger flow.
- **biome config schema** (per entry): id, displayName, description, unlockRenown, unlockExtraGate (optional function), unlockOrder, zoneCenter, zoneRadius, spawnPoint, plotOrigin, npcPositions (travelCoordinator always present + biome-specific NPCs), wildSpawnArea (Workspace BasePart name), wildSpawnTable, wildSpawnCap, wildSpawnInterval, atmosphere (density/offset/color/decay/glare/haze), lightingOverride (ambient/outdoorAmbient/colorShift_Top/colorShift_Bottom/brightness/clockTime), ambientMusicAssetId, ambientLoopAssetId, availableSubstrates (50% surcharge for non-listed), weatherDistribution (sums to 1.0), travelCostCoins.
- **Misty Hollow specifics:** zoneCenter=(2000,0,0), unlockRenown=100, peat normal price (cheaper than elsewhere), travelCostCoins=25, weatherDistribution {Rainy 0.5, Cloudy 0.3, Sunny 0.1, Foggy 0.1}, wild table includes Glowmoss at low weight + Hollowstem/Dewfern.
- **all 7 biome unlock thresholds** (cross-references ADR 003): StarterGlade 0 / MistyHollow 100 / FrostrootPass 300 / SunkenGrove 600 / OldGrowth 1500 / Glimmerwood 2500+lunar / LostCathedral event-based.
- **transition protocol:** Client-side detection on RenderStepped — `detectBiome(position, currentBiomeId)` returns current biome's id (returns currentBiomeId when between zones to avoid snap-to-default jarring). 1.5s tween crossfade for atmosphere/lighting/music. `Settings.reducedMotion = true` skips tween.
- **server-side biome tracking:** `player:SetAttribute("currentBiome", biomeId)`. Updated 1Hz polling.
- **StreamingEnabled tuning:** `StreamingMinRadius=256`, `StreamingTargetRadius=1024`, `StreamingPauseMode=ClientPhysicsPause`, `StreamOutBehavior=Default`. Biome wild spawn areas/plot regions marked `Persistent` (`ModelStreamingMode = Enum.ModelStreamingMode.Persistent`).
- **biome unlock trigger paths** (3): eager via `Reputation.add` re-checking thresholds → fires `BiomeUnlocked` toast; defensive at travel time; quest reward / event participation. Don't gate `RequestBiomeTravel` on `biomesUnlocked` alone — always re-check renown threshold.
- **hand-built escape valve:** Each biome under `Workspace.Biomes.<biomeId>`. Attribute `BuiltManually = true` skips procedural construction, only verifies WildSpawnArea Part exists by name.

---

## CONSTRAINT-shop-ui: Merchant UI + Per-Merchant Config

- **source:** docs/specs/shop-ui.md
- **type:** api-contract + UI surface contract
- **summary:** Shared Buy/Sell modal used by every merchant NPC. Replaces Pre-Alpha witch auto-sell. Phase 2 first milestone (shipped 2026-05-02).
- **`Constants.MERCHANTS[npcId]` schema:** displayName, description, talkRange (default `Constants.MERCHANT_DEFAULTS.talkRange = 14`), buyCategories (categories merchant accepts in Sell), buyMultiplier, itemsForSale (`{[itemId] = ItemListing}`), reputationKey (defaults to npcId), repPerCoin, repGate.
- **ItemListing schema:** unitPrice, category (target inventoryByCategory bucket), repGate, displayName.
- **launch merchant set:** ForestWitch (shipped, migrated from Pre-Alpha witch — buys mushrooms_raw at 1.0×) + 5 future (SubstrateDealer, SporeMerchant, SpiritFood, Cosmetic, DecorationVendor). SubstrateDealer + SporeMerchant shipped 2026-05-03.
- **wire flow:** ProximityPrompt fires server-side → server resolves `merchantId` from prompt's parent Part attribute → fires `OpenShop(npcId)` to triggering client → client opens shared modal → on Confirm fires BuyFromMerchant/SellToMerchant → server validates → success: deduct/add via Inventory + Coins + Reputation chokepoints → fires `ShopTransactionCompleted` with breakdown.
- **validation matrix** (per error code): UNKNOWN_MERCHANT, OUT_OF_RANGE, INVALID_REQUEST, UNKNOWN_ITEM, CATEGORY_REJECTED (Sell only), INSUFFICIENT_INVENTORY, INSUFFICIENT_COINS (Buy only), REP_GATE (Buy only).
- **inventory split (Phase 2 reality, deliberate asymmetry):** Sell mutates legacy `data.inventory` (mushrooms); Buy mutates `data.inventoryByCategory[itemListing.category]` (non-mushroom). Full reconciliation deferred to v3→v4 migration. Don't write reconciliation tooling in the meantime.
- **Reputation shim:** `src/shared/Reputation.luau` — `Reputation.add` is log-only stub until full system lands; `Reputation.get` reads `data.reputation[key].score`. Forward-compat: when real Reputation system ships, replaces this module without refactoring callsites.
- **UI rules:** Sell tab default state = every row preselected at full inventory count (one-click sell-all preserves Pre-Alpha frictionless UX). Tabs: Buy hidden if itemsForSale is empty. Plain Roblox Instance code (no Roact). Pulls from `Constants.UI` tokens per visual-language spec.
- **migration mapping (Pre-Alpha → Phase 2):** `Constants.ECONOMY.witchPriceMultiplier` deleted → `Constants.MERCHANTS.ForestWitch.buyMultiplier`. `Selling.priceOf` → `Shop.totalSellPrice`. `Selling.start` → `Shop.start`. `SellInventory`/`SellCompleted` removed. `SellToast.client.luau` removed (toast lives inside Shop UI).

---

## CONSTRAINT-trading-post: Two-Player Trade System

- **source:** docs/specs/trading-post.md
- **type:** protocol + state-machine + api-contract
- **summary:** Atomic two-player trade with synchronized lock+countdown+confirm anti-scam UX. Marquee Phase 2 feature (shipped 2026-05-03).
- **architectural decisions (locked 2026-05-03):**
  1. **Trade sessions live in-memory only.** Server-crash mid-trade → both players keep originals (failure-safe). DataStore is for the immutable audit log only.
  2. **No Trading Post zone gate yet.** Placeholder marker Part at spawn; real zone follows-up alongside Player Stalls.
  3. **Adopt Me anti-scam UX.** Lock → 5s countdown → both Confirm → atomic execute. Modifying offer during countdown reverts both to Open and resets countdown.
- **state machine:** Pending → Open → Locked → Completed (terminal). Cancelled is alternate terminal from any state. Locked → Open if either party fires UpdateTradeOffer.
- **TradeSession shape (in-memory):** `{ sessionId, state, a:{player,offer,locked,confirmed}, b:{...}, lockedAt, createdAt }`. `a` is requester, `b` is target.
- **validation matrix:** INVALID_TARGET, SELF_TRADE, ALREADY_IN_TRADE, COOLDOWN (20s), INVALID_REQUEST, INSUFFICIENT_COINS, INSUFFICIENT_INVENTORY, INVALID_STATE, PLAYER_DISCONNECTED. Coin/inventory checks at confirmation are mandatory (items can disappear during negotiation).
- **atomic execution on dual Confirm:** Snapshot both → re-validate → mutate A (subtract offerA, add offerB via PlayerData.update) → mutate B (subtract offerB, add offerA) → on partial failure, restore from snapshot, log audit. Roblox lacks transactional DataStore writes; "atomic" = validate-before-mutate + snapshot-rollback backstop.
- **inventory split routing:** Mushroom species → legacy `data.inventory`; non-mushroom → `data.inventoryByCategory[item.category]`. Looked up via `Species.byId[id]` vs `Constants.ITEMS[id]`.
- **audit log:** Separate DataStore `MyceliaAuditLog_v1`. Key `"trade_" .. sessionId`. Append-only. Schema: `{sessionId, timestamp, outcome, cancelReason?, a:{userId,name,gave,got}, b:{...}}`. Logs only on terminal states. pcall'd — DataStore failure doesn't abort trades.
- **UI surface:** Player-picker modal (HUD button), incoming-request toast (30s timeout), two-panel trade modal (6-slot grid + coin input per side, lock indicator, countdown, Cancel + Confirm), item-picker submodal.
- **rate limits (deferred to Phase 3):** RequestTrade 1/20s (already enforced as cooldown), UpdateTradeOffer 10/s, LockTradeOffer 2/s, ConfirmTrade 2/s.

---

## CONSTRAINT-player-stalls: Stalls + Featured Row + Mailbox

- **source:** docs/specs/player-stalls.md
- **type:** protocol + state-machine + api-contract
- **summary:** Player-driven storefront economy. Personal stall on per-player plot anchor + 12-slot featured row in Trading Post zone (rented daily for 200 coins) + fixed-price async listings + mailbox-claimed proceeds + shared Exchange core. **Brand new spec written 2026-05-03; implementation pending.**
- **architectural decisions (confirmed 2026-05-03):**
  1. Hybrid placement (free personal stall + paid featured slot).
  2. Async sales via mailbox (listings persist in DataStore; items leave inventory at list time as escrow; sale proceeds collect in `data.stalls.mailbox`, claimed on next login).
  3. Fixed-price only in v1; auctions deferred (schema reserves `kind = "auction"` + `bids` + `expiresAt` for future).
  4. Tight tunables: 4 listing slots/stall, 48-hour listing expiry, 12 featured slots, 200 coin/day featured fee, 1 featured slot per account.
  5. Discovery gated to featured row (Plot Directory shows featured-row sellers only + global recent-activity feed).
  6. Shared `Exchange.luau` core (snapshotData, restoreFromSnapshot, applyOneSided, writeAudit) consumed by Trade.luau (refactored) and Stall.luau (new). Audit log gains `kind` field (`"trade"` | `"stall_purchase"`).
- **module map:** New: Exchange.luau, Stall.luau, PlotAnchors.luau, ExchangeSpec.luau, StallSpec.luau, StallUI.client.luau. Refactor: Trade.luau (consume Exchange), TradeSpec.luau (consume Exchange where applicable). Constants additions: STALL config block, MERCHANTS.StallManager. New REMOTES (10): CreateListing, CancelListing, BuyListing, RentFeaturedSlot, ClaimMailbox, BrowseDirectory, OpenStallOwnerUI, OpenStallBuyerUI, StallTransactionCompleted, MailboxUpdated. MapSetup adds: buildStallManager, buildFeaturedRowStalls (12 anchored Parts in TP zone), buildPlotAnchorGrid (8×8 = 64 tiles in Cottages zone, claimed lazily).
- **save schema additions** (additive to v3, no migration needed beyond ProfileService Reconcile): `data.stalls = { plotAnchorId, listings = {[uuid] = {...}}, mailbox = {coins, items, sales}, featuredRentExpiresAt }`. `plotAnchorId` lazily assigned on first stall interaction.
- **listing state machine:** CreateListing → Active → (BuyListing → Sold | CancelListing → Cancelled | 48h elapses → Expired). All transitions DataStore-persisted via PlayerData.update.
- **validation matrix:** SLOT_FULL (≤4 active), INSUFFICIENT_INVENTORY, ITEM_NOT_TRADABLE, INVALID_PRICE (1 ≤ unitPrice ≤ 1e9), INVALID_REQUEST, LISTING_GONE, INSUFFICIENT_COINS, SELF_PURCHASE, NOT_OWNER, MAILBOX_FULL (100 unique item id cap; falls through to audit-only), FEATURED_FULL (12 slots), ALREADY_FEATURED.
- **atomic execution (BuyListing):** snapshot buyer + seller's stalls → mutate buyer (subtract coins, add items to correct bucket) → mutate seller (delete listing, add coins to mailbox, prepend sales entry trim to 50) → on step-2 failure restore buyer → audit + fire StallTransactionCompleted.
- **offline seller mutation open question:** ProfileService API for offline-profile mutation needs verification. Fallback: pending-mutations queue keyed on userId.
- **mailbox model:** Write-only-by-system inbox. ClaimMailbox atomically reads → adds coins to data.coins → routes items to inventory buckets → resets `{coins=0, items={}}`. Sales array preserved (activity feed). 100 unique item id cap; coins uncapped. Cap-overflow → audit-log-only.
- **featured row allocation:** 12 anchored stall Models, FIFO continuous, 24h cycle (no global daily reset). Per-account cap=1. Lowest-indexed unoccupied slot. Renewal not guaranteed to return same slot.
- **plot anchors:** 8×8 grid in Cottages zone west of spawn. Claimed lazily on first stall interaction. `OUT_OF_PLOTS` when full. Phase 3 hut system replaces placeholder Part with hut Model on same tile (no save migration needed).
- **anti-griefing:** Inventory escrow at list time. Atomic buy. Rate limits (CreateListing 1/3s, BuyListing 1/1s, RentFeaturedSlot 1/60s). Price bounds. Mailbox bounds. Self-purchase blocked. Personal-only stalls don't appear in directory (anti-scrape). Audit log on every state transition.
- **UI surface:** Stall Manager NPC dialogue tree (3 branches: manage/rent/mailbox). Stall Owner UI (3 tabs: Listings · Mailbox · Featured). Stall Buyer UI (reuses Shop UI buy-tab pattern). Plot Directory UI (HUD "Marketplace" button, 2 tabs: Featured · Recent Sales). Plot Directory "Visit Stall" uses CFrame teleport per ADR 001.
- **future-proofing:** Auctions (~1 weekend; schema ready). LiveOps trading events (Phase 3, third Exchange caller). Hut integration (Phase 3, no save migration). Spatial Voice in marketplaces (Phase 3 polish). Bigger Stall + Featured Discount gamepasses (Phase 3 monetization, only Constants.STALL.slotCount + featuredFee knobs needed).

---

## CONSTRAINT-dialogue-system: NPC Dialogue Trees

- **source:** docs/specs/dialogue-system.md
- **type:** protocol + UI surface contract
- **summary:** Tree-based NPC dialogue. Pure-data trees, client-side navigation, server-side action validation. Phase 2 foundation system (shipped 2026-05-03).
- **architecture:**
  - Pure-data dialogue trees in `src/shared/Dialogues.luau`, indexed by `[npcId][nodeId]`.
  - Client-side navigation (no round-trip per click). Client receives `OpenDialogue({npcId, startNodeId})`, walks local tree.
  - Server-side side effects via `DialogueAction(npcId, nodeId, actionId)` — server validates (talk range, response exists, action allowed) before applying.
  - **Mutual exclusivity at the anchor:** anchor Part has *either* `dialogueId` OR `merchantId`. Shop.luau prompt handler defers to dialogue if `dialogueId` is present; Dialogue.luau defers to shop if absent.
- **node fields:** text (required), responses (required, ≥1), condition (optional `(data) -> boolean` predicate for future quest-gated dialogue).
- **response fields:** id, text, exactly one of `next` (target nodeId) or `action` (Action descriptor).
- **action shapes (Phase 2):** `openShop({npcId})` — server fires `OpenShop`, client closes dialogue + opens Shop UI. `endDialogue` — client closes UI. `giveItem({itemId, quantity})` — future. `startQuest({questId})` — Phase 2 (lands with Quest system). `turnInQuest({questId})` — Phase 2. `requestBiomeTravel({biomeId})` — Phase 2 (added 2026-05-03).
- **wire flow:** Player walks within ProximityPrompt range of `dialogueId`-tagged anchor → `Dialogue.start()` reads attribute → fires `OpenDialogue` → client navigates locally for `next`-bearing responses or fires `DialogueAction` for `action`-bearing → server validates + dispatches via action handler table.
- **UI surface:** Bottom-anchored card on mobile (max 60% screen height), centered card on desktop. Header: speaker portrait (placeholder colored circle with initials in Phase 2) + speakerName (Merriweather H2). Body: instant text (no typewriter — Phase 3 polish). Responses: `parchment.recessed` background, 44pt min tap target, up to 4 before scroll. No "Continue" button — every line has explicit responses. Walk-away auto-close: client throttled (4Hz) Heartbeat checks distance from anchor; > talkRange+4 studs → close.
- **ForestWitch migration:** anchor swaps `merchantId="ForestWitch"` for `dialogueId="ForestWitch"`. One extra click on happy path (greeting → "Sell mushrooms" response → Shop UI). Substrate Dealer + Spore Merchant keep `merchantId` (no dialogue, direct shop).
- **future-proofing:** New action kinds extend `Dialogue.luau` dispatch table. Localization deliberately out of scope for Phase 2 — `node.text` becomes a translation key when needed.

---

## CONSTRAINT-quest-system: Quests + Tutorial Sequence

- **source:** docs/specs/quest-system.md
- **type:** protocol + module-contract + UI surface
- **summary:** Pure-data quest definitions + server-side state tracking + Quest Journal UI + HUD pinned widget. Phase 2 ships foundation + 5-quest tutorial sequence with Gardener Coach (shipped 2026-05-03).
- **architecture:**
  - Pure-data quest definitions in `src/shared/Quests.luau`. Each entry: id, title, description, givenBy, objectives, rewards, prerequisites, repeatable.
  - Server-side state in `data.activeQuests[questId] = {acceptedAt, progress = {[i] = count}}` and `data.stats.questsCompleted[questId] = true` (both already in v3 schema).
  - Event-driven progress. Gameplay modules call `Quests.onEvent(player, eventName, payload)`. Quest module updates objective progress for every active quest with matching kind.
  - Dialogue-driven lifecycle. Quests start/turn-in via dialogue actions (`startQuest(id)` / `turnInQuest(id)`). No HUD-attached Accept/Abandon buttons in Phase 2.
  - Pure-helper coverage: `isActive`, `isComplete`, `objectivesComplete`, `canAccept`, `canTurnIn` exposed for dialogue conditions and tests.
- **objective fields:** kind, target (itemId/speciesId or `"any"`), count, label.
- **7 supported event kinds (Phase 2):** harvest_wild, harvest_plot, plant_species, brew_attempt, brew_success, sell_to_merchant, consume_potion. Each fires from a specific gameplay module's BindableEvent or call site.
- **5-quest tutorial sequence (all given by Gardener Coach NPC at spawn):**
  1. `first_steps` — harvest 3 wild mushrooms → 25 coins.
  2. `a_place_to_grow` — plant 1 Spore Patch → 50 coins.
  3. `the_witch_pays` — sell 5 mushrooms to Forest Witch → 1× Compost.
  4. `the_cauldron_calls` — drop ingredients in cauldron once (any brew) → 1× BrownCapSpore.
  5. `a_recipe_discovered` — discover first valid recipe → 100 coins.
  Sequential prerequisites; total reward ~175 coins + 1× Compost + 1× BrownCapSpore.
- **wire flow:**
  - Accept: dialogue response with `action = {kind="startQuest", questId=...}`, gated by `Quests.canAccept(data, questId)` client-side condition. Server validates (exists, prereqs met, not already active/completed). Adds to `data.activeQuests`. PlayerDataUpdated propagates.
  - Track: gameplay events fire BindableEvents → Quest module walks active quests, increments matching objectives. Updated progress in `data.activeQuests[questId].progress`.
  - Turn-in: dialogue's "done with X" response (gated by canTurnIn condition) → server validates → atomic PlayerData.update: removes from activeQuests, sets stats.questsCompleted[questId]=true, awards rewards. Coins routed to data.coins; items routed to correct inventory bucket.
  - Abandon: AbandonQuest remote drops from activeQuests. Non-repeatable quests can still be re-accepted later.
- **Quest Journal UI:** Three tabs (Active / Completed / Available). Same modal pattern as ShopUI / Brewing Journal.
- **HUD pinned widget:** Top-right corner. Quest title + first incomplete objective + `current/count` in `accent.gold`. Hidden when no active quest. Click to open Journal. Multi-objective quests cycle through in Journal; HUD shows one at a time.
- **dialogue action handler extensions:** `startQuest` and `turnInQuest` wired in `Dialogue.luau` action dispatch table.

---

## CONSTRAINT-visual-language: UI/World Visual Tokens

- **source:** docs/specs/visual-language.md
- **type:** schema (design tokens) + style contract
- **summary:** Single source of truth for color, typography, motion, spacing, and surface tokens for all UI and world surfaces.
- **brand palette (12 tokens):** forest.{ink, deep, mid (PRIMARY), sage, mist}, parchment.{cream (DEFAULT UI), mist, bone}, bark.{warm, dark}, accent.{gold (CURRENCY), amber, duskBlue, barnRed}.
- **rarity tiers (6):** Common #8FA478 / Uncommon #6B8FA8 / Rare #B07AA1 / Epic #D9866A / Legendary #E5C547 / Mythic gradient #9C68D4 → #5C9BD5 (animated hue-rotate at 0.05Hz).
- **biome palettes (7):** StarterGlade (sun-dappled meadow) · MistyHollow (cool grey-violet rainforest) · FrostrootPass (alpine pale blue-white) · SunkenGrove (swamp moss-mauve) · OldGrowth (deep amber-shadow) · Glimmerwood (deep blue/neon green, **DARK MODE**) · Lost Cathedral (weathered gold ruined stone).
- **UI surface tokens (light theme — default):** ui.{bg, surface, surface.recessed, surface.raised, divider, text.primary/secondary/muted, accent.primary/primary.hover/gold, success, warning, error, info, shadow}. Dark theme (Glimmerwood + future night cycles) defined skeletally; full tokens TBD when first dark-theme screen ships.
- **typography (Roblox built-in fonts only):** Merriweather (Display H1/H2, headers), Nunito (section headings, body, captions, buttons), Inconsolata (currency / numeric — tabular figures avoid jitter). Mobile + desktop sizes specified per role. Line-height 1.4× body / 1.2× heading.
- **iconography:** 12px corner radius cards, 8px buttons, 4px chips. Outlined icons (2px stroke). 1.5px min line weight at base scale. Single soft shadow `0 4 12 ui.shadow`. Glimmerwood uses inverted bioluminescent glow instead of shadow.
- **motion tokens:** micro 80ms · short 200ms · medium 350ms · long 600ms · discovery 1200ms (with overshoot). Reduced-motion: multiply durations by 0.5, clamp discovery to 300ms with no overshoot.
- **spacing system (8pt grid):** xs 4 · sm 8 · md 16 (default card padding) · lg 24 · xl 32 · 2xl 48. **Mobile tap targets: 44pt minimum** (extend hit-area with invisible padding).
- **surface elevation:** Level 0 page (no shadow) · Level 1 cards · Level 2 modal/dialog (page dimmed) · Level 3 toast/floating.
- **conventions (locked rules):** Never hardcode hex codes in logic — pull from `Constants.UI.color.*`. Never use Roblox default colors without translating through this palette. Never mix two rarity colors on same surface. One accent per screen. Pairing rule: never `forest.ink` text on `parchment.bone` (use `forest.deep` on bone or `forest.ink` on cream).
- **`Constants.UI` table** specified verbatim for code consumption.
