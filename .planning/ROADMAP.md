# Mycelia — ROADMAP.md

GSD roadmap. Mirrors the canonical [docs/ROADMAP.md](../docs/ROADMAP.md) phase structure (Pre-Alpha + 4 phases + After launch) with size markers (S/M/L/XL) and completion ticks preserved. Each phase has goal-backward success criteria and a requirements mapping. **Player Stalls is tracked as a Phase 2 sub-feature** (not a separate phase) per its spec at [docs/specs/player-stalls.md](../docs/specs/player-stalls.md).

Granularity: **standard** (defaulted; no `.planning/config.json` present at synthesis time).

---

## Phases

- [x] **Pre-Alpha** — Core loop, 15 species, 6 recipes, save schema v2, 74 tests, painted terrain. *Shipped baseline.*
- [x] **Phase 1: Alpha (depth layer)** — Brewing reaches design-target; spirits exist; second biome works. *Shipped 2026-05-02 (166 tests).*
- [ ] **Phase 2: Closed Beta (social systems + content)** — Trading economy lights up; quests provide structure; species count doubles. *In progress — 6 milestones shipped 2026-05-02 / 03; Player Stalls + Co-op Expeditions + 15 new species pending.*
- [ ] **Phase 3: Soft Launch (monetization + polish)** — Shippable to low-traffic regions. Mobile feels good. Money works. *Pending.*
- [ ] **Phase 4: Global Launch (content completeness)** — World fully built. All 60 species. All 7 biomes. Seasons cycle. *Pending.*
- [ ] **After launch (XL ongoing)** — LiveOps content, new biomes beyond launch 7, gamepass/dev-product expansion, recipe additions, daily exploit response.

---

## Phase Details

### Pre-Alpha
**Goal**: Establish the playable core gameplay loop, brewing foundation, painted world, and test framework so Phase 1 has something to build *depth* onto.
**Depends on**: Nothing (project genesis).
**Requirements**: BASE-01, BASE-02, BASE-03, BASE-04, BASE-05, BASE-06
**Success Criteria** (what is TRUE):
  1. Player can walk, harvest a wild mushroom, plant a Spore Patch, sell harvest to Forest Witch, and brew a 6-recipe potion in cauldron.
  2. 15 species across Common/Uncommon/Rare/Epic exist and persist across sessions via save schema v2 (DataStore with graceful pcall degradation).
  3. The world is hand-painted (mountain + cave + pond + paths + hills + animated koi) with hand-built escape valves so procedural construction can be overridden.
  4. 74-test TestKit baseline runs on Studio Play.
**Plans**: shipped (no further plans needed).

---

### Phase 1: Alpha (depth layer)
**Goal**: Brewing reaches design-target depth; Forest Spirits exist as a second progression axis; the second biome (Misty Hollow) is reachable so the biome system is proven.
**Depends on**: Pre-Alpha.
**Requirements**: P1-FOUND-01, P1-FOUND-02, P1-BREW-01, P1-BREW-02, P1-SPIR-01, P1-SPIR-02, P1-SPIR-03, P1-SPIR-04, P1-BIOME-01, P1-BIOME-02, P1-BIOME-03, P1-TEST-01, P1-TEST-02, P1-TEST-03, P1-DECISION-01
**Success Criteria** (what is TRUE):
  1. Player saves persist across sessions via ProfileService (session-locked, autosave) on save schema v3 with idempotent v1→v2→v3 migration.
  2. Player can brew any of 20 recipes across 4 methods, with 10 distinct potion effect kinds (8 functional + 2 Phase 4 stubs that warn cleanly).
  3. Player can attract, claim, equip, and observe wandering Forest Spirits whose passive bonuses combine source-agnostically with PotionEffects.
  4. Player can travel from StarterGlade to Misty Hollow via the Travel NPC (CFrame teleport per ADR 001) once their renown ≥ 100.
  5. All four open architectural questions resolved as ADRs 001–004 (single-place biomes, cultivation formula, reputation rates, coin economy).
**Plans**: shipped (no further plans needed).
**Sub-task ledger** (preserves canonical ROADMAP.md ticks + sizes):
  - **Foundations**
    - [x] (L) Migrate save persistence to ProfileService — *2026-05-01*
    - [x] (M) Bump save schema to v3 — *2026-05-01*
  - **Brewing depth**
    - [x] (S) Add 14+ new recipes to reach 20 total — *2026-05-01*
    - [x] (L) Implement remaining 7 potion effects — *2026-05-01*
  - **Forest Spirits**
    - [x] (L) Spirit attraction system — *2026-05-01*
    - [x] (M) Spirit claim flow — *2026-05-01*
    - [x] (M) Active-roster wandering AI — *2026-05-01*
    - [x] (S) Spirit-as-item packaging — *2026-05-01*
  - **Biome architecture**
    - [x] (L) Refactor MapSetup + WildSpawn to be biome-parameterized — *2026-05-01*
    - [x] (L) Misty Hollow biome — *2026-05-01*
    - [x] (S) Travel NPC backend — *2026-05-01*
  - **Tests**
    - [ ] PotionEffects: per-effect happy path + duration test (covered indirectly by integration tests)
    - [x] Recipes: lookup table integrity, no duplicate keys
    - [x] Spirits: attraction math, roster cap enforcement
  - **Open questions resolved**
    - ✓ ADR 001 — biome architecture (single-place zones)
    - ✓ ADR 002 — cultivation yield formula
    - ✓ ADR 003 — reputation rates
    - ✓ ADR 004 — coin economy

---

### Phase 2: Closed Beta (social systems + content)
**Goal**: The trading economy lights up (player-to-player trades + player-driven stalls + co-op expeditions); quests provide structured onboarding and mid-game pull; species count doubles to 30 with the introduction of the Legendary tier.
**Depends on**: Phase 1.
**Requirements**: P2-TRADE-01..04, P2-STALL-01..06, P2-EXP-01..05, P2-QUEST-01..04, P2-DIAG-01..03, P2-SHOP-01..03, P2-CONT-01, P2-TEST-01..04, P2-VIS-01
**Success Criteria** (what is TRUE):
  1. Two players can trade items and coins in an atomic, anti-scam-protected session (lock + 5s countdown + dual confirm; snapshot rollback on partial failure; audit log per terminal state).
  2. A player can list items at fixed prices on a personal stall (4 slot cap, 48h expiry, inventory escrow at list time) OR rent a featured-row slot in the Trading Post zone (12 slots, 200c/day, FIFO continuous), and another player can buy those listings even when the seller is offline (mailbox-claimed proceeds).
  3. Up to 4 players can launch into a co-op foraging expedition (lobby + reserved server via TeleportService per ADR 001), complete time-limited content, and return with rewards distributed by participation.
  4. A new player can complete the Gardener Coach 5-quest tutorial (harvest → plant → sell → brew → discover) and 5+ NPCs (of 8 launch NPCs) hold dialogue trees that gate quests, shops, and biome travel.
  5. Every merchant uses the shared Shop UI; sells go through the chokepoint (legacy `data.inventory` for mushrooms; `inventoryByCategory` for non-mushroom buys); per-merchant config drives behavior from `Constants.MERCHANTS`.
  6. Visual language tokens (`Constants.UI`) are the single source of truth — no hex codes in logic; every Phase 2 UI surface (Shop / Quest / Dialogue / Trade / future Stalls) consumes them.
**Plans**: TBD (next pickup: Player Stalls implementation per the approved spec).
**UI hint**: yes
**Sub-task ledger** (preserves canonical ROADMAP.md ticks + sizes; `~` = partial):
  - **Trading Post (the longevity engine)**
    - [x] (L) Trade UI + flow — *2026-05-03*
    - [x] (L) Atomic trade execution server-side — *2026-05-03*
    - [~] (M) Anti-duping protections — audit log + re-validation shipped; rate limits + inventory mutation lock deferred to Phase 3
    - [~] (M) Trading Post location — placeholder marker shipped; real zone follows alongside Player Stalls
  - **Player Stalls** (spec ready 2026-05-03 — implementation pending; spec at [docs/specs/player-stalls.md](../docs/specs/player-stalls.md))
    - [ ] (L) Stall rental flow (Stall Manager NPC, daily fee, plot anchor or featured slot assignment)
    - [ ] (L) Listing UI (fixed-price v1; auctions schema-reserved)
    - [ ] (M) Browse + buy flow (Plot Directory UI; featured-row sellers + recent-activity feed)
    - [ ] (M) Stall renewal/release loop (24h cycle, FIFO continuous, per-account cap=1 featured)
    - [ ] (M) Mailbox model (write-only-by-system inbox; ClaimMailbox atomic routing)
    - [ ] (M) Shared Exchange.luau core (snapshotData/restoreFromSnapshot/applyOneSided/writeAudit; refactor Trade.luau to consume)
  - **Co-op Foraging Expeditions**
    - [ ] (L) Lobby system (Coordinator NPC, Create/Join tabs, kick + password + level requirement)
    - [ ] (L) Expedition Place(s) (separate Roblox Places per type; time limit; environmental constraints)
    - [ ] (M) Party teleport via TeleportService with reserved server (per ADR 001)
    - [ ] (M) Reward distribution based on participation; failed runs lose unfinished items
    - [ ] (S) Lobby chat — private channel per party
  - **Quest system**
    - [x] (L) Quest data structure (7 OBJECTIVE_KINDS + pure helpers) — *2026-05-03*
    - [x] (L) Quest Journal UI — *2026-05-03*
    - [x] (M) Tutorial 5-quest sequence with Gardener Coach — *2026-05-03*
    - [x] (S) HUD-tracked quest widget — *2026-05-03*
  - **NPC dialogue system**
    - [x] (L) Dialogue tree data structure — *2026-05-03*
    - [x] (M) Dialogue UI (mobile-first, 44pt buttons, walk-away auto-close) — *2026-05-03*
    - [~] Wire up the major launch NPCs — 5 of 8 shipped (Forest Witch, Gardener Coach, Travel Coordinator, Old Hermit, Wandering Alchemist); pending Spirit Speaker, Expedition Coordinator, Trading Post Manager
  - **Shop UI (replaces witch auto-sell)**
    - [x] (L) Shared shop UI component — *2026-05-02*
    - [x] (M) Per-merchant config in Constants.MERCHANTS — *2026-05-02*
    - [~] (M) Wire up secondary merchants — Substrate Dealer + Spore Merchant shipped 2026-05-03; Spirit Food + Cosmetic + Decoration vendors pending
  - **Content**
    - [ ] (XL) Add 15+ new species to reach 30+ across 5 tiers (introduce Legendary tier)
  - **Tests**
    - [~] Trading: end-to-end happy path + every cancel-condition path — TradeSpec ~20 tests shipped 2026-05-03; some edge paths pending
    - [ ] Stalls: listing + sale + renewal flows (StallSpec + ExchangeSpec)
    - [ ] Expeditions: lobby state machine, reward distribution math
    - [x] Quests: objective tracking, prerequisite gating (QuestsSpec ~16 tests)
  - **Visual language (cross-cutting foundation)**
    - [x] (M) Constants.UI tokens locked + consumed by Shop / Quest / Dialogue / Trade UIs — *2026-05-02*

---

### Phase 3: Soft Launch (monetization + polish)
**Goal**: Game is shippable to low-traffic regions. Mobile feels production-quality. Monetization works end-to-end. The game looks, sounds, and runs like a finished product.
**Depends on**: Phase 2.
**Requirements**: P3-MON-01..04, P3-HUT-01..05, P3-PROF-01, P3-OPS-01..03, P3-POL-01..06, P3-SEC-01..05, P3-TEST-01..03
**Success Criteria** (what is TRUE):
  1. A player can buy any of 8 gamepasses or 4 dev-product types via in-game Robux shop UI; ownership persists in PlayerData and refreshes on `PromptGamePassPurchaseFinished`. No purchase grants gameplay power, rarity, or trading advantage (locked rule).
  2. A player has a personal hut they can decorate (placement UI with ghost preview) and configure (wall/floor/lighting/access settings); other players can visit via TeleportService and leave guestbook messages but cannot modify host's stuff.
  3. A LiveOps event scheduler fires daily/weekly events that surface as HUD toasts + chat messages and resolve via reputation + reward grants.
  4. The game runs cleanly on a 6.1" reference mobile device with 44pt tap targets, smooth camera scripting, full animation/sound/VFX wiring, and a settings UI that respects the v3 settings schema.
  5. Every remote enforces a rate limit per `Constants.RATE_LIMITS`; every coin and item movement writes to the audit DataStore; the 10B coin hard cap and per-tick reject thresholds (per ADR 004) are enforced server-side.
**Plans**: TBD.
**UI hint**: yes

---

### Phase 4: Global Launch (content completeness)
**Goal**: The world is fully built. All 7 launch biomes are explorable. All 60 launch species are discoverable. Seasons and lunar cycles are live. The game is ready for global push.
**Depends on**: Phase 3.
**Requirements**: P4-BIOME-01..05, P4-CONT-01/02, P4-TIME-01..05, P4-WEATH-01..04, P4-FINAL-01..03
**Success Criteria** (what is TRUE):
  1. All 5 remaining biomes (Frostroot Pass, Sunken Grove, Old Growth, Glimmerwood, Lost Cathedral) are reachable per their renown / lunar / event gates from ADR 003, with biome-appropriate atmosphere, wild spawn tables, and per-biome substrates.
  2. The Pokedex contains 60 species across 6 tiers (Mythic tier added); the recipe space supports thousands of combinations and hundreds of valid potions.
  3. All servers share a synchronized season + lunar phase derived from `os.time()` against the 2026-01-01 epoch; per-season visual + gameplay effects fire; Full Moon gates Glimmerwood legendary spawns.
  4. Per-biome weather state cycles probabilistically (Sunny/Cloudy/Rainy/Stormy/Snowy/Foggy biased by season); rain raises plot moisture; the weatherSummon potion stub becomes functional.
  5. A balance pass on Constants.luau lands; Roblox compliance review passes (chat filter, age-appropriate content, parental purchase consent); a 1-week stability soak completes with 0 critical bugs.
**Plans**: TBD.

---

### After launch (XL ongoing)
**Goal**: The game stays alive and grows. LiveOps cadence sustains; new biomes and content drop on a predictable beat; exploits are caught and patched within the day.
**Depends on**: Phase 4 (global launch).
**Requirements**: POST-01, POST-02, POST-03, POST-04, POST-05
**Success Criteria** (what is TRUE):
  1. At least one major LiveOps event ships per month (mythic spawn, story beat, exclusive cosmetic, or seasonal rotation).
  2. New biomes beyond the launch 7 ship via the parameterized biome system without requiring code refactors.
  3. New gamepasses and dev products ship in response to player demand; recipe additions ship as low-effort discovery content drops.
  4. The Audit DataStore is reviewed daily for suspicious activity (per ADR 004 thresholds); exploit hot-fixes ship within the day they're identified.
**Plans**: TBD (rolling).

---

## Progress Table

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| Pre-Alpha | n/a | Shipped | (baseline) |
| 1. Alpha (depth layer) | n/a (sub-tasks tracked above) | Shipped | 2026-05-02 |
| 2. Closed Beta (social systems + content) | 0 / TBD | In progress | — |
| 3. Soft Launch (monetization + polish) | 0 / TBD | Not started | — |
| 4. Global Launch (content completeness) | 0 / TBD | Not started | — |
| After launch | n/a (rolling) | Not started | — |

Plan counts populate after `/gsd-plan-phase` runs against each integer phase.

---

## References

- Canonical roadmap: [docs/ROADMAP.md](../docs/ROADMAP.md)
- Current state: [HANDOFF.md](../HANDOFF.md)
- Design north star: [docs/DESIGN.md](../docs/DESIGN.md)
- ADRs (locked decisions): [docs/decisions/](../docs/decisions/)
- Specs (mutable contracts): [docs/specs/](../docs/specs/)
- GSD project memory: [.planning/PROJECT.md](PROJECT.md)
- GSD requirement register: [.planning/REQUIREMENTS.md](REQUIREMENTS.md)
- Ingest synthesis: [.planning/intel/SYNTHESIS.md](intel/SYNTHESIS.md)
- Conflict report: [.planning/INGEST-CONFLICTS.md](INGEST-CONFLICTS.md)
