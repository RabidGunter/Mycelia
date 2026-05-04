# Context (synthesized from DOCs)

10 DOCs ingested: project vision, roadmap, current state, contributing rules, project review, visual references, README, AI assistant onboarding, git workflow, legacy archived handoff. Below they are organized by topic with full source attribution.

---

## Project identity + vision

- **source:** docs/DESIGN.md (canonical north star)
- **also:** docs/PROJECT-REVIEW.md (reviewer-facing snapshot), CLAUDE.md (AI assistant primer)

**One-paragraph definition (PROJECT-REVIEW.md):** Mycelia is **Stardew Valley's quiet pace wrapped around Bee Swarm Simulator's depth**, with a player-driven potion economy as the long-term retention engine.

**Genre:** Cozy life-sim with hidden depth (Bee Swarm Simulator lineage).
**Target session:** 5–15 min casual / 60+ min engaged. Daily check-in habit.
**Platform priority:** Mobile-first. PC and console secondary.
**Target audience:** Primary 9–16, designed to retain into adulthood (Bee Swarm pattern).

**Core vision (DESIGN.md §Core Vision Statement):** A cozy mushroom-cultivation game set in an enchanted forest, where simple harvesting in your first hour gradually reveals a 200-hour optimization puzzle, a player-driven trading economy, and a collection ceiling that grows with the game.

**Five-minute core loop (DESIGN.md):** Walk into a misty starter glade → harvest glowing mushrooms with a tap → sell at Forest Witch's stall OR drop in cauldron → plant a Spore Patch → wait → harvest more (intentional planting paid off).

**200-hour long loop:** Same loop scales — harvest becomes 7 biomes with seasonal rotations and lunar mechanics; sell becomes player-driven Trading Post with stalls + auctions; plant becomes 6-variable cultivation puzzle; wait becomes recipe discovery + lunar growth cycles; brew becomes thousands of recipe combos with hundreds of valuable potions.

**Naming (DESIGN.md):** *Mycelia* is a working title. Real options listed: Mycelia, Spore & Stem, The Mushroom Hollow, Glimmerwood, Forager, Misty Glade, Fae Forest. Recommendation: test 2–3 names with thumbnails before committing. "A slightly whimsical name with a clear visual hook beats a clean abstract name."

---

## Game systems (full design vision)

- **source:** docs/DESIGN.md §Game Systems

**1. Mushroom Collection ("Pokedex"):** Launch with 60 species across 6 rarity tiers. Plan for 200+ at maturity. Tiers: Common (Brown Cap, Spotted Toadstool, Fairy Cup) · Uncommon (Lattice Veil, Inkpot, Coral Tongue) · Rare (Glowmoss, Dewfern, Whisperbloom) · Epic (Crystal Cap, Auroracap, Frostling) · Legendary (Starseed, Heartwood, Voidcap) · Mythic (The Old One, Eternal Bloom). **Visual design rule:** every mushroom must look distinct from a thumbnail-sized icon.

**2. Cultivation Mechanics (the depth layer):** 6 variables — substrate type, moisture, light level, host tree, soil pH, companion mushrooms. New player just plants/harvests; veteran balances 6 variables for specific rare hybrids. **Optimization can take hundreds of hours to master.**

**3. Brewing System (the secret weapon):** Drop 1–5 mushrooms in cauldron, choose method (steep/boil/ferment/dry-grind), wait. **Recipes are NOT given to players — they're discovered.** With 60 mushrooms × 4 methods × 1–5 ingredient combos, thousands of possible recipes. Categories: Buffs / Tools / Cosmetic / Forest interaction.

**4. Trading Post (the longevity engine):** Players trade mushrooms (raw + dried), potions, spores, recipes (one-time-use scrolls), cosmetics, forest spirits. **Trading post is a physical place** with Spatial Voice from day one. Player-run shops at higher levels. **Critical rule: never let real-money purchases bypass the trading economy.**

**5. Forest Spirits (the pet/companion layer):** Specific mushrooms attract specific spirits — wandering plot companions with passive bonuses. Common (Mossling/Spritefly/Dewdrop) / Rare (Lanternfox/Crystalmoth/Deerlet) / Legendary (Forest Mother — once-per-server lunar event spawn). **Spirits are tradeable** — function like Adopt Me pets, drive collection completion, single most valuable trading currency.

**6. Biomes and Foraging Expeditions:** Players start in Starter Glade, unlock Misty Hollow / Frostroot Pass / Sunken Grove / Old Growth / Glimmerwood / Lost Cathedral. Each biome has own substrates, weather, exclusive species. **Foraging Expeditions** are co-op runs into deeper biomes (2–4 players, time-limited, slightly dangerous = lose unfinished potions on failure, high reward) — **the social hook driving the algorithm.**

**7. Seasons and Lunar Cycles:** Real-time, each season = 1 real-world week (4 weeks = 1 game year). Different mushrooms fruit in different seasons. Some legendaries only appear in specific moon phases. **Daily check-in pressure that doesn't feel coercive.**

**8. Quest System (onboarding scaffold):** Forest Witch (NPC tutorial guide) gives quests for first ~10 hours, then Old Hermit / Wandering Alchemist / Spirit Speaker take over with their own stories. Quests reward recipes, biome unlocks, rare seeds, reputation. **Never required for progression but teach mechanics smoothly.**

**Note on biome count discrepancy:** DESIGN.md §The Long Loop mentions "Harvest becomes 12 different biomes." The committed implementation per ROADMAP.md and biome-config.md spec is **7 launch biomes**. Auto-resolved per precedence (SPEC > DOC); see INGEST-CONFLICTS.md INFO bucket. The number 12 in DESIGN appears to be aspirational long-tail content, not a launch commitment.

---

## Progression curve (retention waves)

- **source:** docs/DESIGN.md §Progression Curve, also docs/PROJECT-REVIEW.md

| Hour | Player state |
|---|---|
| 1 | Discover core loop. Plant first patch. Discover first potion accidentally. |
| 5 | Unlock second biome. Realize there are species you can't grow yet. Trade with first other player. |
| 20 | Discover recipes have deep effects. Start hunting specific ingredients. |
| 50 | Reach mid-tier rarity. Specialize in a brewing style. Join Discord/community. |
| 100 | Have a "build" — specific way you play. Known in trading post for something. |
| 500 | Hunting mythics. Possibly running a stall. Helping new players. **Game has become a place, not a game.** |

**No level cap. No prestige.** Game ends when you've collected everything; dev's job is to make sure the horizon keeps moving.

---

## Monetization plan

- **source:** docs/DESIGN.md §Monetization Plan
- **enforcement:** CLAUDE.md "Things to never do" + ADR 004 inflation control

**Game pass items (one-time):** Bigger Plot, Auto-Harvester, Recipe Journal Plus, Cosmetic outfits, House upgrades.
**Direct purchases (consumables):** Coin packs (small acceleration, never enough to skip progression), Speed-up potions (30 min faster growth), Cosmetic spirit skins.
**What to never sell:** Rare mushrooms or spores directly · Spirits directly (only spirit *food* that increases attraction chance) · Recipes · Trading advantages.

**Locked rule (CLAUDE.md):** "No pay-to-win. Robux unlocks time and cosmetics, never rare items, recipes, or trading advantages." Sell *time* and *cosmetics*, never *power* or *rarity*.

**Realistic revenue expectations (DESIGN.md):** Top 1% of Roblox games earn $1M+/year. Successful long-term cozy game in this lane (Bee Swarm tier) could realistically clear $100k–500k/year for small team. **Don't optimize for first-month revenue. Optimize for Year 2 retention.**

---

## LiveOps cadence + social hooks

- **source:** docs/DESIGN.md §LiveOps Calendar + §Social and Community Hooks

**Cadence (planned from launch):** Daily login bonus + daily quest from Forest Witch · Weekly limited-time mushroom species rotation + biome event · Monthly major event with mythic spawns + new spirit + new ingredients · Seasonal (every 3 months) new biome + major story beat + exclusive cosmetic line.

**Social hooks** (driving algorithm):
1. Co-op Foraging Expeditions (multiplayer, friend invites)
2. Trading Post (player gathering, Spatial Voice)
3. Recipe Discovery sharing (community knowledge)
4. Visit other players' plots (Theme Park Tycoon model)
5. Shared servers with day/night cycle (bump into the same regulars)
6. Lunar Events (server-wide cooperation to summon mythics)

---

## Failure modes (what could kill this game)

- **source:** DESIGN.md §What Could Kill This Game

1. Going pay-to-win — gut the trading economy in 6 months.
2. Recipe space too small — players exhaust discovery in week 1, lose long-term hook.
3. Mobile controls feel bad — losing 40%+ audience instantly.
4. No LiveOps cadence — algorithm punishment, players churn.
5. Onboarding too slow — first 2 minutes boring = done.
6. Trading exploits — duping bugs killed early Adopt Me momentum. Trade system needs to be airtight from day one.
7. Trying to scope too big — launch with 60 species, not 200. Add over time.

---

## Roadmap (canonical phase plan)

- **source:** docs/ROADMAP.md
- **status snapshot:** Phase 1 verified complete 2026-05-02. Phase 2 in progress (multiple milestones shipped 2026-05-02 and 2026-05-03).

**Pre-Alpha (shipped):** Core loop · 6 recipes · 3 active potion effects · 15 species across 4 tiers · save schema v2 · 74 unit tests · painted terrain · brewing journal UI · hand-built escape valves.

**Phase 1 — Alpha (Goal: brewing reaches design-target; spirits exist; second biome works) — COMPLETE:**
- Foundations: ProfileService migration ✓ · Save schema v3 ✓
- Brewing depth: 14+ new recipes (→20 total) ✓ · 7 remaining potion effects ✓
- Forest Spirits: attraction system ✓ · claim flow ✓ · wandering AI ✓ · spirit-as-item packaging ✓
- Biome architecture: refactor MapSetup/WildSpawn ✓ · Misty Hollow ✓ · Travel NPC ✓
- Tests: per-effect tests, recipe integrity, spirit math (covered)
- Open questions ALL resolved → ADRs 001–004 (single-place biomes, cultivation formula, reputation rates, coin economy)

**Phase 2 — Closed Beta (Goal: trading economy lights up; quests provide structure; species count doubles) — IN PROGRESS:**
- **Trading Post (the longevity engine):** Trade UI + flow ✓ · atomic execution ✓ · anti-duping protections (audit log + re-validation done; rate limits + inventory mutation lock deferred) · Trading Post location (placeholder marker shipped; real zone follow-up).
- **Player Stalls:** spec written ✓ (docs/specs/player-stalls.md, 2026-05-03); implementation pending — stall rental flow, listing UI, browse + buy flow, stall renewal/release loop.
- **Co-op Foraging Expeditions:** all pending — lobby system, expedition Place(s), party teleport via TeleportService (correct usage per ADR 001), reward distribution, lobby chat.
- **Quest system:** quest data structure ✓ · Quest Journal UI ✓ · Tutorial 5-quest sequence ✓ · HUD-tracked quest widget ✓
- **NPC dialogue system:** dialogue tree data structure ✓ · Dialogue UI ✓ · launch NPCs partial (5 of 8 shipped — Forest Witch, Gardener Coach, Travel Coordinator, Old Hermit, Wandering Alchemist; pending Spirit Speaker + Expedition Coordinator + Trading Post Manager, each blocked on its backing system).
- **Shop UI (replaces witch auto-sell):** shared shop UI component ✓ · per-merchant config ✓ · secondary merchants partial (Substrate Dealer + Spore Merchant shipped; Spirit Food + Cosmetic + Decoration vendors pending).
- **Content:** 15+ new species (→30 total, add Legendary tier) — pending.
- **Tests:** trading end-to-end (started, ~20 tests in TradeSpec) · stalls (pending) · expeditions (pending) · quests (16 tests in QuestsSpec).

**Phase 3 — Soft Launch (Goal: shippable to low-traffic regions. Mobile feels good. Money works) — NOT STARTED:**
- Monetization: gamepasses + dev products (Bigger Plot, Auto-Harvester, Recipe Journal Plus, Inventory Expansion, Bigger Spirit Roster, Recyclable Substrate, Cosmetic Outfit Packs, House Upgrade); coin packs / speed-up potions / cosmetic spirit skins / decoration items; gamepass ownership cache; in-game shop UI.
- Hut + decoration: hut interior system, decoration placement UI, hut settings, plot visiting via TeleportService, guestbook.
- Player profile + LiveOps: profile UI (rep per NPC, total stats, badges, total renown), LiveOps event scheduler (config-driven via MessagingService or HTTP), event UI, push-notification analog.
- Polish: mobile optimization pass, camera scripting, animation wiring, sound wiring (per-biome ambient music with crossfade, per-season ambient layers, SFX, UI SFX, spirit chime, lunar event audio), VFX wiring, settings UI.
- Anti-exploit hardening: rate limits per remote, audit logging, sanity check thresholds (>1M coins or >1000 items in tick), coin cap (1 trillion → revised to 10B per ADR 004), inventory cap enforcement.

**Phase 4 — Global Launch (Goal: world fully built. All 60 species. All 7 biomes. Seasons cycle.) — NOT STARTED:**
- Remaining 5 biomes (each L): Frostroot Pass · Sunken Grove · Old Growth · Glimmerwood · Lost Cathedral.
- Content completeness (XL): 30+ more species (→60 total, add Mythic) · recipe space expansion (thousands of combinations).
- Seasons + lunar cycles: server-side time engine (`os.time()` from epoch 2026-01-01), SeasonChanged + LunarPhaseChanged BindableEvents, replicate to clients via SeasonState remote, per-season visual + gameplay effects, lunar mechanics.
- Weather: per-biome weather state (Sunny/Cloudy/Rainy/Stormy/Snowy/Foggy, probabilistic transitions every 10 min), weather replication + client VFX, plot moisture during rain, weather summon potion integration.
- Final pass: balance pass on Constants.lua, Roblox compliance review, 1-week stability soak with 0 critical bugs.

**After launch (XL ongoing):** LiveOps content (1 major event/month from launch), new biomes beyond launch 7, new gamepasses + dev products, recipe additions, bug fixes + balance hot-fixes + exploit response (daily Audit DataStore review).

---

## Current state (HANDOFF.md, canonical)

- **source:** HANDOFF.md (root) — last touched 2026-05-03
- **legacy archive:** mycelia/HANDOFF.md (Pre-Alpha port history; archive-only per HANDOFF.md root)

**Phase 2 Closed Beta in progress.** Six milestones shipped:
- 2026-05-02: Shop UI replacing Pre-Alpha witch auto-sell.
- 2026-05-03: Substrate Dealer + Spore Merchant (secondary merchants partial).
- 2026-05-03: NPC dialogue system foundation + Forest Witch tree.
- 2026-05-03: Quest system + 5-quest tutorial sequence + Gardener Coach NPC.
- 2026-05-03: Travel Coordinator + Old Hermit + Wandering Alchemist NPCs (5 of 8 launch NPCs).
- 2026-05-03: Walk-away dialogue auto-close UX.
- 2026-05-03: **Trading Post — atomic two-player trade backend + UI + audit log.**

**Player Stalls + Co-op Expeditions + 15+ new species pending.** Phase 1 verified complete in Studio (166 tests passing prior to Phase 2 work; ~253 tests after Phase 2 milestones).

**Project structure:** Top-level `src/` is canonical Rojo source (Luau, `.luau`). Legacy `mycelia/src/` preserved for reference but archive-only. Wired into Roblox via `default.project.json`:
- `src/shared/` → ReplicatedStorage.Shared
- `src/server/init.server.luau` → ServerScriptService.Server
- `src/server/X.luau` → child ModuleScripts of Server
- `src/server/Tests/` → child Folder of Server containing test runner + specs
- `src/client/X.client.luau` → LocalScripts under StarterPlayerScripts.Client

**Environment / setup:**
- Studio + Rojo workflow. `rojo serve default.project.json` from VS Code, connect via Rojo Studio plugin.
- Project pins `rojo-rbx/rojo@7.7.0-rc.1` via `aftman.toml`. Run `rojo plugin install` from project folder once.
- DataStore unavailable in unpublished Studio places. PlayerData.lua pcalls and degrades gracefully. Place is currently published as "Mycelia" under RabidGunter's account.

**Setup gotchas (HANDOFF.md):**
- Studio's Toolbox panel doesn't always appear when toggled. Workarounds: try `File → Studio Settings → search "Toolbox"`, or fully uninstall + reinstall Studio. Marketplace assets can be brought in via `InsertService:LoadAsset(assetId)` in code.
- Rojo doesn't sync during a Play session. Stop Play, wait ~2s, then Play again.
- Terrain repaints sticky once `Workspace.HasHandBuiltGround=true`. Force re-run via command bar: `workspace.Terrain:Clear(); workspace:SetAttribute("HasHandBuiltGround", nil)`.
- Same pattern for Witch + Cauldron Parts (delete in Studio first to force re-place).
- DataStore unavailable in unpublished places — `PlayerData.lua` pcalls. Enable saves via File → Save to Roblox + Game Settings → Security → Enable Studio Access to API Services.

**One-time gotchas (encountered + resolved):**
- ProfileService:LoadProfileAsync errored on raw v2 player save data with `attempt to index nil with 'ActiveSession'`. Resolved by wiping the test player's record via command bar. Future migrations between save backends should pre-migrate raw data.
- Orphan instances from legacy project layout (`ServerScriptService.Tests`, etc.) embedded in saved place file caused old test specs to run alongside new ones. Resolved by deleting orphan duplicates from Studio Explorer. Future restructures should include "delete orphans" cleanup pass.

---

## Codebase rules (locked, "don't break")

- **source:** CLAUDE.md + HANDOFF.md "Design rules locked in"

1. **Server-authoritative everything.** Clients send intents via Remotes; server validates before any state mutation. Never trust client input.
2. **Tunables in `src/shared/Constants.luau`.** Anything balance-affecting (costs, durations, multipliers, drop rates) belongs there, not in logic files.
3. **Species `id` never changes once shipped.** It's the save-data key. Add new species, don't rename old ones.
4. **No pay-to-win.** Robux unlocks time and cosmetics, never rare items, recipes, or trading advantages.
5. **Match existing module conventions.** Don't introduce new patterns (OOP frameworks, dependency injection, alternative module structures) without writing an ADR first.
6. **Pure-function modules get tests. Server-side remote handlers get tests.** See CONTRIBUTING.md Definition of Done.

**Things to never do (CLAUDE.md):**
- Push code from a work machine, even to a private repo.
- Sell power, rarity, or trading advantages for Robux.
- Skip server-side validation on a remote because "the client UI guarantees it."
- Rename a shipped species `id`.
- Edit `.rbxl` files outside Studio.
- Introduce new module conventions without an ADR.
- Reach into Roblox Service objects in pure-function tests — keep test modules dependency-free.
- Hardcode magic numbers in logic files when a Constants entry would do.

---

## Documentation hygiene (process rules)

- **source:** docs/CONTRIBUTING.md

**The docs-stay-current rule:** Every non-trivial change updates `docs/` *in the same session*. If you make the change but skip the docs, the change is incomplete.

| What changed | What to update |
|---|---|
| Code state (new system, milestone progress, file structure) | HANDOFF.md "State as of last session" + README.md repo layout |
| Scope (new feature scoped in, work descoped, phase boundary moved) | ROADMAP.md |
| Architecture / locked-in design decision | New numbered ADR in decisions/ |
| Open question resolved | Mark resolved in ROADMAP.md "Open questions" with link to new ADR |
| Concrete data / API shape / schema not already pinned | New spec in specs/ |
| Setup gotcha encountered | HANDOFF.md "Setup gotchas worth knowing about" |
| Test count or coverage shifted significantly | HANDOFF.md state + README.md milestone checklist |

**ADR naming:** `NNN-short-kebab-name.md`. Numbers monotonically increase; never re-number old decisions even if superseded (write a new ADR that supersedes the old one instead).

**ADR template (loose):** Status + decision (one line each at top) → The question → The options (concrete pros/cons) → Real-world evidence if relevant → Project-specific considerations → Recommendation + reasoning → Implementation notes → When the alternative IS appropriate → Override criteria.

**Spec vs ADR:** ADR explains *why* we chose an approach; spec describes *what* to build under that approach. **ADRs are immutable; specs are mutable** (evolve in place; older versions in git history).

**Definition of done per change:**
- New code has tests covering happy path + at least one edge case.
- Existing tests still pass.
- HANDOFF.md reflects the new state.
- Any other affected docs are updated per the table above.
- Change is verified in Studio at least once (Play Solo is fine).

---

## Multi-machine workflow

- **source:** docs/git-setup.md + docs/CONTRIBUTING.md "Working across machines"

**Solo project, multiple machines.** Code lives canonically on the personal machine. Work-laptop sessions are usually planning-only.

**Asymmetric pull-only workflow:**
- **Personal machine:** pushes to GitHub. Source of truth for code.
- **Work laptop:** pull-only. Never `git push` from this machine (outbound traffic to github.com under personal credentials triggers work network monitoring).
- For changes made on work laptop: generate `.patch` files via `git format-patch origin/main..HEAD --output-directory=~/Downloads/patches/`, transfer via USB, on personal machine `git am ~/path/to/patches/0001-*.patch` then push.
- Or simpler for small edits: copy raw files via USB, review + commit + push on personal.

**Rules:**
- Don't commit `.rbxl` / `.rbxlx` / `.rbxm` / `.rbxmx` files (Roblox binary places — always edit in Studio).
- Don't commit `.vscode/`, `.idea/`, `.DS_Store`, OS junk, secrets/API keys.
- DO commit vendored dependencies (e.g., `src/ServerScriptService/Vendor/`) — vendoring's whole point is reproducibility.
- Feature branches per substantial change. Trivial fixes can go straight to `main`.
- Commit messages describe WHY, not WHAT.

---

## Visual references board

- **source:** docs/visual-references.md (paired with docs/specs/visual-language.md)

Curated external reference links for Mycelia's cottagecore + Ghibli aesthetic.

**Most-relevant references for current Phase 2 work:**
- **Stardew Valley General Store** — single-column scrollable item list, portrait + name + price + buy button per row, warm brown wood frame. Closest reference for witch shop intimacy.
- **Hollow Knight merchant UI** — character portrait at the top of shop dialog as decorative anchor; gives every shop unique personality. Lift handmade-ornament-as-frame approach.
- **Adopt Me trade screen** — side-by-side offer panels, cooldown-into-green-accept-button is *the* anti-scam UX pattern (matches remote-api spec LockTradeOffer + ConfirmTrade flow).
- **Cozy Grove + Ooblets via Game UI Database** — Ooblets is the closest reference for overall visual target (cottagecore-meets-modern-UI balance, clean type, soft sage greens, hand-drawn icons but crisp digital UI).
- **Bee Swarm Simulator Robux Shop** — tabbed shop layout, large tap targets. Take structure, leave 2018 chrome.
- **Ghibli + cottagecore Pinterest boards** — color temperature for biomes (Old Growth + Misty Hollow especially — violet-grey-green palette of damp forest at dawn matches `forest.mist` and Misty Hollow tokens).
- **Lospec / Coolors cozy palettes** — sanity-check our hex picks.

**How to use the board:** Open closest reference for 60 seconds before designing, then close. Don't keep open while drafting (leads to copying). When result feels generic-AI, revisit Cozy Grove or Ooblets — canonical "cottagecore-but-modern" benchmark.

---

## Existing test count baseline

- **source:** HANDOFF.md + PROJECT-REVIEW.md

**Baselines reported in HANDOFF.md session log:**
- 74 tests (Pre-Alpha original count)
- ~95 tests after ProfileService + save schema v3 (74 + 21 SaveSchemaSpec)
- ~105 tests after Forest Spirits (95 + 10 SpiritsSpec — actual count varied; HANDOFF mentions 22 SpiritsSpec)
- ~125 tests after Biome architecture (105 + ~14 BiomeConfigSpec)
- 166 tests verified Studio 2026-05-02 (Phase 1 complete)
- ~196 after Shop UI (166 + ~30 ShopSpec) [verification pending]
- ~206 after Substrate Dealer + Spore Merchant additions (196 + ~10 expanded ShopSpec)
- ~217 after Dialogue system (206 + 11 DialoguesSpec)
- ~233 after Quest system (217 + 16 QuestsSpec)
- ~253 after Trading Post (233 + 20 TradeSpec)

**Test framework:** In-house TestKit (no external dependencies, no Wally). Auto-runs on Studio Play via `RunTests.server.luau`.

**Architecture stats from PROJECT-REVIEW.md (snapshot ~2026-05-02):**
- Lines of Luau: ~6,000 (gameplay) + ~2,000 (tests).
- Active modules: 18 server, 9 client, 6 shared.
- Save schema: v3 (with idempotent v1→v3 migration).
- Persistence backend: ProfileService (session-locked, autosave).

---

## README (repo entry-point, brief)

- **source:** README.md

Project root README contains Rojo getting-started instructions only:
- `rojo build -o "Mycelia.rbxlx"` to build place from scratch.
- Open `Mycelia.rbxlx` in Studio + start `rojo serve`.
- Pointer to https://rojo.space/docs.

This README is intentionally minimal; CLAUDE.md and HANDOFF.md carry the actual onboarding context.

---

## Legacy archive: mycelia/HANDOFF.md

- **source:** mycelia/HANDOFF.md (archive-only per current HANDOFF.md root)
- **disposition:** Historical context for Pre-Alpha build. Preserved for reference only. Coordinates and code organization referenced inside refer to the **legacy** `mycelia/src/` layout that has been ported to top-level `src/` per the new project structure (HANDOFF.md root 2026-05-01 entry).

**Captures:** Pre-Alpha gameplay scaffold history, terrain pass, mountain + cave + pond + koi build details, original architecture overview, daily dev loop, design rules and prohibitions, test runner overview, original session log.

**Treat as read-only history.** Any conflict with the current HANDOFF.md (root) is resolved in favor of the current root file. Per ingest prompt: "the legacy mycelia/HANDOFF.md is archive-only and should be treated as historical context, not current state."
