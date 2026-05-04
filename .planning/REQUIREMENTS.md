# Mycelia — REQUIREMENTS.md

GSD requirements register. Each requirement has a stable ID, a phase mapping (traceability), and a status. **Mycelia ingest set contained 0 PRDs**, so requirements below are derived from `docs/ROADMAP.md` task list and per-spec acceptance criteria (see [.planning/intel/requirements.md](intel/requirements.md) for the explanatory note).

The convention going forward (per [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md)): write the SPEC first; let acceptance criteria live in the spec's tests + validation sections; treat requirements here as the *traceability surface* between phases and shipped systems.

---

## How to read this file

- **REQ-IDs** are stable. Once shipped, never re-numbered. New requirements get the next free number in their category.
- **Status** values: `Shipped` (verified in Studio + tests pass) · `In progress` (some sub-tasks complete) · `Pending` (not started) · `Spec ready` (spec authored, implementation pending).
- **Source** points to the spec or roadmap section the requirement is derived from.
- **Phase** is the phase that delivers (or delivered) the requirement.

---

## Pre-Alpha (shipped baseline)

These predate the formal phase system but are listed for traceability. All are `Shipped` and verified.

| REQ-ID | Requirement | Source | Phase | Status |
|---|---|---|---|---|
| BASE-01 | Core gameplay loop: walk → harvest → plant → sell → brew | DESIGN.md | Pre-Alpha | Shipped |
| BASE-02 | Brewing foundation: 4 methods, 6 recipes, 3 active potion effects | potions-and-recipes.md | Pre-Alpha | Shipped |
| BASE-03 | 15 species across 4 tiers (Common / Uncommon / Rare / Epic) | species-data.md | Pre-Alpha | Shipped |
| BASE-04 | Save schema v2 with DataStore graceful degradation | save-schema-v3.md (history) | Pre-Alpha | Shipped |
| BASE-05 | 74 baseline unit tests via in-house TestKit | HANDOFF.md | Pre-Alpha | Shipped |
| BASE-06 | Painted terrain (mountain + cave + pond + paths + hills) + animated koi + brewing journal UI + lighting/atmosphere | ROADMAP.md | Pre-Alpha | Shipped |

---

## Phase 1 — Alpha (depth layer)

Goal: brewing reaches design-target; spirits exist; second biome works. **Phase verified complete 2026-05-02 (166 tests passing).**

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P1-FOUND-01 | Migrate save persistence to ProfileService | save-schema-v3.md | L | 1 | Shipped 2026-05-01 |
| P1-FOUND-02 | Bump save schema to v3 with idempotent v1→v2→v3 migration | save-schema-v3.md | M | 1 | Shipped 2026-05-01 |
| P1-BREW-01 | Add 14+ new recipes to reach 20 total (5 Easy / 8 Mid / 5 Hard + 2 alt-paths) | potions-and-recipes.md | S | 1 | Shipped 2026-05-01 |
| P1-BREW-02 | Implement remaining 7 potion effects (luck, harvestYield, reveal, spiritAttract, cosmeticGlow, weatherSummon, timeShift) | potions-and-recipes.md | L | 1 | Shipped 2026-05-01 |
| P1-SPIR-01 | Spirit attraction system (per-player tick every 5 min) | spirits.md | L | 1 | Shipped 2026-05-01 |
| P1-SPIR-02 | Spirit claim flow with atomic check-and-revert | spirits.md | M | 1 | Shipped 2026-05-01 |
| P1-SPIR-03 | Active-roster wandering AI (idle/walking state machine) | spirits.md | M | 1 | Shipped 2026-05-01 |
| P1-SPIR-04 | Spirit-as-item packaging (allOwned + activeRoster, EquipSpirit / UnequipSpirit) | spirits.md + save-schema-v3.md | S | 1 | Shipped 2026-05-01 |
| P1-BIOME-01 | Refactor MapSetup + WildSpawn to be biome-parameterized | biome-config.md | L | 1 | Shipped 2026-05-01 |
| P1-BIOME-02 | Misty Hollow biome (zone center 2000 east, rainforest atmosphere, water-loving wild table) | biome-config.md | L | 1 | Shipped 2026-05-01 |
| P1-BIOME-03 | Travel NPC backend (RequestBiomeTravel remote, renown + cost validation, CFrame teleport per ADR 001) | remote-api.md + ADR 001 | S | 1 | Shipped 2026-05-01 |
| P1-TEST-01 | PotionEffects per-effect happy path + duration tests | ROADMAP Phase 1 Tests | S | 1 | Pending (covered by integration tests; standalone per-effect spec deferred) |
| P1-TEST-02 | Recipes lookup table integrity, no duplicate keys | ROADMAP Phase 1 Tests | S | 1 | Shipped (RecipesSpec) |
| P1-TEST-03 | Spirits attraction math + roster cap enforcement tests | ROADMAP Phase 1 Tests | S | 1 | Shipped (SpiritsSpec) |
| P1-DECISION-01 | Resolve "biomes as separate Places vs single-place zones" open question | ADR 001 | — | 1 | Resolved 2026-05-01 → ADR 001 |

---

## Phase 2 — Closed Beta (social systems + content) — IN PROGRESS

Goal: trading economy lights up; quests provide structure; species count doubles. **Multiple milestones shipped 2026-05-02 and 2026-05-03; Player Stalls + Co-op Expeditions + 15+ new species pending.**

### Trading Post (the longevity engine)

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-TRADE-01 | Trade UI + flow (two-panel modal, 6-slot grid + coin input, lock + 5s countdown + confirm) | trading-post.md | L | 2 | Shipped 2026-05-03 |
| P2-TRADE-02 | Atomic trade execution server-side (validate-before-mutate + snapshot-rollback, re-validation at confirm) | trading-post.md | L | 2 | Shipped 2026-05-03 |
| P2-TRADE-03 | Anti-duping protections: audit log to MyceliaAuditLog_v1 + confirmation re-validation | trading-post.md | M | 2 | In progress (audit + re-validation shipped; per-remote rate limits + inventory mutation lock deferred to Phase 3) |
| P2-TRADE-04 | Trading Post location — physical zone with travel portals from all biomes | trading-post.md + ROADMAP | M | 2 | In progress (placeholder marker shipped; real zone follows alongside Player Stalls) |

### Player Stalls (spec ready, implementation pending)

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-STALL-01 | Stall rental flow (Stall Manager NPC, daily fee 200c featured / free personal, stall Model assigned via plot anchor or featured slot) | player-stalls.md | L | 2 | Spec ready 2026-05-03 |
| P2-STALL-02 | Listing UI — fixed-price v1 (auctions schema-reserved for future) | player-stalls.md | L | 2 | Spec ready 2026-05-03 |
| P2-STALL-03 | Browse + buy flow (Plot Directory UI; featured-row sellers + recent-activity feed; Visit Stall via CFrame teleport per ADR 001) | player-stalls.md | M | 2 | Spec ready 2026-05-03 |
| P2-STALL-04 | Stall renewal/release loop (24h cycle, FIFO continuous, per-account cap=1 featured slot) | player-stalls.md | M | 2 | Spec ready 2026-05-03 |
| P2-STALL-05 | Mailbox model (write-only-by-system inbox; ClaimMailbox atomically routes coins + items; 100 unique item id cap) | player-stalls.md | M | 2 | Spec ready 2026-05-03 |
| P2-STALL-06 | Shared Exchange.luau core (snapshotData, restoreFromSnapshot, applyOneSided, writeAudit) consumed by Trade.luau (refactor) + Stall.luau (new) | player-stalls.md | M | 2 | Spec ready 2026-05-03 |

### Co-op Foraging Expeditions (pending)

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-EXP-01 | Lobby system (Coordinator NPC, Create/Join tabs, kick + password + level requirement) | ROADMAP Phase 2 | L | 2 | Pending |
| P2-EXP-02 | Expedition Place(s) — separate Roblox Places per expedition type, time limit, environmental constraints | ROADMAP Phase 2 + ADR 001 | L | 2 | Pending |
| P2-EXP-03 | Party teleport via TeleportService with reserved server (correct usage per ADR 001) | ROADMAP Phase 2 + ADR 001 | M | 2 | Pending |
| P2-EXP-04 | Reward distribution based on participation; failed runs lose unfinished items | ROADMAP Phase 2 | M | 2 | Pending |
| P2-EXP-05 | Lobby chat — private channel per party | ROADMAP Phase 2 | S | 2 | Pending |

### Quest system

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-QUEST-01 | Quest data structure (id, title, desc, NPC, objectives, rewards, prerequisites, repeatable; 7 OBJECTIVE_KINDS) | quest-system.md | L | 2 | Shipped 2026-05-03 |
| P2-QUEST-02 | Quest Journal UI (Active / Completed / Available tabs) | quest-system.md | L | 2 | Shipped 2026-05-03 |
| P2-QUEST-03 | Tutorial 5-quest sequence with Gardener Coach (harvest → plant → sell → brew → discover) | quest-system.md | M | 2 | Shipped 2026-05-03 |
| P2-QUEST-04 | HUD-tracked quest widget (pinned objective summary top-right) | quest-system.md | S | 2 | Shipped 2026-05-03 |

### NPC dialogue system

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-DIAG-01 | Dialogue tree data structure per NPC (`src/shared/Dialogues.luau` indexed by `[npcId][nodeId]`) | dialogue-system.md | L | 2 | Shipped 2026-05-03 |
| P2-DIAG-02 | Dialogue UI (bottom-anchored card mobile / centered desktop, portrait + speakerName, scrollable responses, 44pt buttons, walk-away auto-close) | dialogue-system.md | M | 2 | Shipped 2026-05-03 |
| P2-DIAG-03 | Wire up the major launch NPCs (8 total) | dialogue-system.md + ROADMAP | M | 2 | In progress — 5 of 8 shipped (Forest Witch, Gardener Coach, Travel Coordinator, Old Hermit, Wandering Alchemist); pending Spirit Speaker, Expedition Coordinator, Trading Post Manager (each blocked on its backing system) |

### Shop UI (replaces witch auto-sell)

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-SHOP-01 | Shared shop UI component with Sell / Buy tabs (used by all merchants) | shop-ui.md | L | 2 | Shipped 2026-05-02 |
| P2-SHOP-02 | Per-merchant config in `Constants.MERCHANTS` (categories, items, multipliers, rep gates) | shop-ui.md | M | 2 | Shipped 2026-05-02 |
| P2-SHOP-03 | Wire up secondary merchants (Substrate Dealer, Spore Merchant, Spirit Food, Cosmetic, Decoration) | shop-ui.md + ROADMAP | M | 2 | In progress — Substrate Dealer + Spore Merchant shipped 2026-05-03; Spirit Food + Cosmetic + Decoration vendors pending |

### Content

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-CONT-01 | Add 15+ new species to reach 30+ across 5 tiers (introduce Legendary tier) | species-data.md + ROADMAP | XL | 2 | Pending |

### Tests

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-TEST-01 | Trading: end-to-end happy path + every cancel-condition path (disconnect, distance, decline, server crash) | ROADMAP Phase 2 Tests | M | 2 | In progress — TradeSpec ~20 tests shipped 2026-05-03 |
| P2-TEST-02 | Stalls: listing + sale + renewal flows (StallSpec + ExchangeSpec) | player-stalls.md | M | 2 | Pending |
| P2-TEST-03 | Expeditions: lobby state machine, reward distribution math | ROADMAP Phase 2 Tests | M | 2 | Pending |
| P2-TEST-04 | Quests: objective tracking, prerequisite gating | quest-system.md | M | 2 | Shipped (QuestsSpec ~16 tests) |

### Visual language (cross-cutting foundation)

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P2-VIS-01 | Visual language tokens locked (12 brand / 6 rarity / 7 biome / Constants.UI table) consumed by Shop UI + Quest + Dialogue + Trade UIs | visual-language.md | M | 2 | Shipped 2026-05-02 |

---

## Phase 3 — Soft Launch (monetization + polish) — PENDING

Goal: shippable to low-traffic regions. Mobile feels good. Money works.

### Monetization

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P3-MON-01 | Wire gamepasses to MarketplaceService (Bigger Plot, Auto-Harvester, Recipe Journal Plus, Inventory Expansion, Bigger Spirit Roster, Recyclable Substrate, Cosmetic Outfit Packs, House Upgrade) | ROADMAP Phase 3 | L | 3 | Pending |
| P3-MON-02 | Wire dev products (Coin Pack S/M/L, Speed-Up Potion 1/hr cap, Cosmetic Spirit Skin, Decoration Items) | ROADMAP Phase 3 | M | 3 | Pending |
| P3-MON-03 | Server-side gamepass ownership cache in PlayerData; refresh on PromptGamePassPurchaseFinished | ROADMAP Phase 3 | M | 3 | Pending |
| P3-MON-04 | In-game Robux shop UI for browsing gamepasses + dev products | ROADMAP Phase 3 | M | 3 | Pending |

### Hut + decoration

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P3-HUT-01 | Hut interior system (basic hut on first spawn, decoration anchors, personal cauldron + storage chest + spirit shelf) | ROADMAP Phase 3 | L | 3 | Pending |
| P3-HUT-02 | Decoration placement UI (pick → ghost preview → tap to place; long-press to remove) | ROADMAP Phase 3 | L | 3 | Pending |
| P3-HUT-03 | Hut Settings (wall color, floor texture, lighting cycle, public/friends_only/private access — schema in v3) | ROADMAP Phase 3 + save-schema-v3.md | M | 3 | Pending |
| P3-HUT-04 | Plot visiting via TeleportService (visitor cannot modify host's stuff) | ROADMAP Phase 3 + ADR 001 | M | 3 | Pending |
| P3-HUT-05 | Guestbook (visitors can leave a message, persists in host's hut) | ROADMAP Phase 3 | S | 3 | Pending |

### Player profile + LiveOps

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P3-PROF-01 | Player profile UI (rep per NPC, total stats, discovery badges, total renown) | ROADMAP Phase 3 + ADR 003 | M | 3 | Pending |
| P3-OPS-01 | LiveOps event scheduler (config-driven via MessagingService or HTTP endpoint) | ROADMAP Phase 3 + DESIGN.md §LiveOps | L | 3 | Pending |
| P3-OPS-02 | Event UI (HUD button, event-info panel with current details, leaderboard, claimed rewards) | ROADMAP Phase 3 | M | 3 | Pending |
| P3-OPS-03 | Push-notification analog (top-screen toast + chat-channel message when events start) | ROADMAP Phase 3 | M | 3 | Pending |

### Polish

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P3-POL-01 | Mobile optimization pass (44pt tap-target audit, 6.1" reference device layout review, performance/memory profiling) | ROADMAP Phase 3 + visual-language.md | L | 3 | Pending |
| P3-POL-02 | Camera scripting (smooth zoom, cinematic discovery moments, modal-open desaturation tween, lunar event pan, rare-event camera shake) | ROADMAP Phase 3 | L | 3 | Pending |
| P3-POL-03 | Animation wiring (player char idle/walk/run/harvest/plant/brew/sell, NPCs, mushroom growth lerp, plot ripen wobble, harvest pickup float, spirit wandering, UI transitions, toast slide-in) | ROADMAP Phase 3 | L | 3 | Pending |
| P3-POL-04 | Sound wiring (per-biome ambient music with crossfade, per-season ambient layer, pond water spatial audio, wild forest ambience, SFX, UI SFX, spirit chime, lunar event audio) | ROADMAP Phase 3 + biome-config.md | L | 3 | Pending |
| P3-POL-05 | VFX wiring (spore puff, brew bubbles, discovery glow, spirit summon, lunar event beam, seasonal particles, ambient fireflies + glowing pollen) | ROADMAP Phase 3 | M | 3 | Pending |
| P3-POL-06 | Settings UI (master/music/SFX volume sliders, hut access, mute-when-tabbed-out, accessibility options) | ROADMAP Phase 3 + save-schema-v3.md | M | 3 | Pending |

### Anti-exploit hardening

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P3-SEC-01 | Rate limits on every remote in `Constants.RATE_LIMITS` (default 5/sec, override per-remote per remote-api spec) | remote-api.md + ROADMAP | M | 3 | Pending |
| P3-SEC-02 | Audit logging on every coin and item movement to a separate DataStore | ROADMAP Phase 3 + ADR 004 | M | 3 | Pending |
| P3-SEC-03 | Sanity check thresholds (flag and log if a player gains >1M coins or >1000 items in a tick — per ADR 004 thresholds) | ADR 004 + ROADMAP | S | 3 | Pending |
| P3-SEC-04 | Coin hard cap enforcement — 10B per ADR 004 (note: ADR supersedes ROADMAP's 1T) | ADR 004 | S | 3 | Pending |
| P3-SEC-05 | Inventory cap enforcement — server rejects adds that exceed slot/stack limits (999/stack, 32 slots/category default) | save-schema-v3.md | S | 3 | Pending |

### Tests

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P3-TEST-01 | Monetization: every gamepass + dev product happy path | ROADMAP Phase 3 Tests | M | 3 | Pending |
| P3-TEST-02 | Rate limiting: simulate burst calls, verify rejection | ROADMAP Phase 3 Tests | S | 3 | Pending |
| P3-TEST-03 | Audit log: every transaction type produces a log entry | ROADMAP Phase 3 Tests | S | 3 | Pending |

---

## Phase 4 — Global Launch (content completeness) — PENDING

Goal: world fully built. All 60 species. All 7 biomes. Seasons cycle. Ready for global push.

### Remaining biomes

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P4-BIOME-01 | Frostroot Pass (snowy, slow-growing high-value species; renown 300 unlock) | biome-config.md + ADR 003 | L | 4 | Pending |
| P4-BIOME-02 | Sunken Grove (swamp, alchemy ingredients; renown 600) | biome-config.md + ADR 003 | L | 4 | Pending |
| P4-BIOME-03 | Old Growth (ancient forest, legendary species; renown 1500) | biome-config.md + ADR 003 | L | 4 | Pending |
| P4-BIOME-04 | Glimmerwood (bioluminescent, night-only, DARK MODE; renown 2500 + lunar quest) | biome-config.md + visual-language.md + ADR 003 | L | 4 | Pending |
| P4-BIOME-05 | Lost Cathedral (mythic spawns during events; community-event unlock) | biome-config.md + ADR 003 | L | 4 | Pending |

### Content completeness

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P4-CONT-01 | 30+ more species to reach 60 total (introduce Mythic tier) | species-data.md + DESIGN.md | XL | 4 | Pending |
| P4-CONT-02 | Recipe space expansion — thousands of combinations, hundreds of valid potions | potions-and-recipes.md + DESIGN.md | XL | 4 | Pending |

### Seasons + lunar cycles

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P4-TIME-01 | Server-side time engine (`os.time()` from epoch 2026-01-01; all servers share season + moon phase) | ROADMAP Phase 4 | L | 4 | Pending |
| P4-TIME-02 | SeasonChanged + LunarPhaseChanged BindableEvents (subscribers: WildSpawn, Weather, Lighting, Spirits) | ROADMAP Phase 4 | M | 4 | Pending |
| P4-TIME-03 | SeasonState remote replication for HUD season indicator | ROADMAP Phase 4 | M | 4 | Pending |
| P4-TIME-04 | Per-season visual + gameplay effects (Spring/Summer/Autumn/Winter palette + bonuses + VFX) | ROADMAP Phase 4 + visual-language.md | M | 4 | Pending |
| P4-TIME-05 | Lunar mechanics (Full Moon enables Glimmerwood legendary spawns; New Moon enables stealth/quieter movement) | ROADMAP Phase 4 + spirits.md (ForestMother) | M | 4 | Pending |

### Weather

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P4-WEATH-01 | Per-biome weather state (Sunny/Cloudy/Rainy/Stormy/Snowy/Foggy; probabilistic transitions every 10 min, biased by season) | biome-config.md + ROADMAP | L | 4 | Pending |
| P4-WEATH-02 | Weather replication + client VFX (rain particles, snow, fog Atmosphere settings) | ROADMAP Phase 4 | M | 4 | Pending |
| P4-WEATH-03 | Plot moisture during rain (auto-raise moisture on rainy plots) | ROADMAP Phase 4 + ADR 002 | M | 4 | Pending |
| P4-WEATH-04 | Weather summon potion integration (P1-BREW-02's weatherSummon stub becomes functional) | potions-and-recipes.md + ROADMAP | S | 4 | Pending |

### Final pass

| REQ-ID | Requirement | Source | Size | Phase | Status |
|---|---|---|---|---|---|
| P4-FINAL-01 | Balance pass on Constants.luau (yields, prices, growth times, drop rates, spirit attraction, recipe costs) | ROADMAP Phase 4 + ADR 002 + ADR 004 | L | 4 | Pending |
| P4-FINAL-02 | Roblox compliance review (chat filtering certified, age-appropriate content checked, parental purchase consent flows tested) | ROADMAP Phase 4 | M | 4 | Pending |
| P4-FINAL-03 | 1-week stability soak with 0 critical bugs before global push | ROADMAP Phase 4 | M | 4 | Pending |

---

## After launch (XL ongoing)

Not part of any single phase but tracked here for visibility.

| REQ-ID | Requirement | Source | Phase | Status |
|---|---|---|---|---|
| POST-01 | LiveOps content cadence (1 major event/month from launch) | DESIGN.md §LiveOps | After | Pending |
| POST-02 | New biomes beyond launch 7 (per parameterized biome system) | ROADMAP After launch | After | Pending |
| POST-03 | New gamepasses + dev products as the player base shows what's wanted | ROADMAP After launch | After | Pending |
| POST-04 | Recipe additions (easy way to add discovery content without new systems) | ROADMAP After launch | After | Pending |
| POST-05 | Bug fixes + balance hot-fixes + exploit response (daily Audit DataStore review) | ROADMAP After launch + ADR 004 | After | Pending |

---

## Traceability

Every requirement above maps to exactly one phase. Coverage = 100% (no orphans). Use this section as the lookup surface for "what phase delivers REQ-X" and "what requirements does Phase Y own."

### By phase

- **Pre-Alpha:** BASE-01 through BASE-06 (6 reqs, all Shipped)
- **Phase 1:** P1-FOUND-01/02 + P1-BREW-01/02 + P1-SPIR-01/02/03/04 + P1-BIOME-01/02/03 + P1-TEST-01/02/03 + P1-DECISION-01 (15 reqs, all Shipped or Resolved except P1-TEST-01 deferred)
- **Phase 2:** P2-TRADE-01/02/03/04 + P2-STALL-01..06 + P2-EXP-01..05 + P2-QUEST-01..04 + P2-DIAG-01/02/03 + P2-SHOP-01/02/03 + P2-CONT-01 + P2-TEST-01..04 + P2-VIS-01 (27 reqs; 12 Shipped, 4 In progress, 6 Spec ready, 5 Pending)
- **Phase 3:** P3-MON-01..04 + P3-HUT-01..05 + P3-PROF-01 + P3-OPS-01..03 + P3-POL-01..06 + P3-SEC-01..05 + P3-TEST-01..03 (27 reqs, all Pending)
- **Phase 4:** P4-BIOME-01..05 + P4-CONT-01/02 + P4-TIME-01..05 + P4-WEATH-01..04 + P4-FINAL-01..03 (19 reqs, all Pending)
- **After launch:** POST-01..05 (5 reqs, all Pending)

**Total:** 99 requirements across 6 buckets. 0 orphans.

### By status

- **Shipped:** ~26 (Pre-Alpha 6 + Phase 1 ~13 + Phase 2 ~7)
- **In progress:** 4 (Phase 2: P2-TRADE-03, P2-TRADE-04, P2-DIAG-03, P2-SHOP-03, P2-TEST-01)
- **Spec ready:** 6 (Phase 2 Player Stalls: P2-STALL-01..06)
- **Pending:** ~63 (Phase 2 remaining + Phase 3 + Phase 4 + After launch)

Status counts are approximate where Phase 1 sub-tests were rolled into integration coverage rather than tracked as distinct test specs.
