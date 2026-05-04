# Mycelia — Build Roadmap

Self-paced task list for taking Mycelia from current state (Pre-Alpha + brewing depth + painted terrain) to launch. Pick what you have time for. Each phase is a coherent chunk that can stand alone — finish one, take a break, come back later.

This roadmap **pairs with the Scripting Order Request PDF** — the PDF is the design spec (the *what* and *why*); this file is the actionable list (the *do*). Refer to the PDF when you start a task and need the details.

---

## How to use this list

- Tasks are grouped by phase. Phase order matters — each phase depends on the one before. Within a phase, you can mostly pick task order.
- Size markers: **(S)** = an evening · **(M)** = a weekend · **(L)** = several sessions · **(XL)** = ongoing or weeks.
- A task is "done" when:
  - The new code has tests (happy path + at least one edge case).
  - Existing tests still pass.
  - `HANDOFF.md` is updated.
  - You've actually played the change in Studio at least once.

---

## ✅ Already done (Pre-Alpha)

- Core gameplay loop (walk → harvest → plant → sell → brew).
- Brewing foundation: 4 methods, 6 recipes, 3 active potion effects (speed, growth, wildYield).
- 15 species across 4 tiers (Common / Uncommon / Rare / Epic).
- Save schema v2 with DataStore graceful degradation.
- 74 unit tests via TestKit.
- Painted terrain (mossy mountain with cave interior, pond, paths, hills).
- Animated koi fish in the pond.
- Brewing Journal UI.
- Hand-built escape valves for all procedurally-built world pieces.
- Lighting + atmosphere setup.

---

## Phase 1 — Alpha (depth layer)

*Goal: brewing reaches design-target; spirits exist; second biome works.*

### Foundations to do first
- [x] **(L) Migrate save persistence to ProfileService.** ✓ 2026-05-01 — vendored at `src/server/Vendor/ProfileService.luau`; PlayerData rewritten; public API preserved; init.server.luau simplified to `PlayerData.start()`.
- [x] **(M) Bump save schema to v3.** ✓ 2026-05-01 — full v3 shape per spec, idempotent v2→v3 migration, legacy `data.inventory`/`data.potions` preserved for backwards compat. SaveSchemaSpec covers v1/v2/v3 paths + idempotency + malformed input (21 tests).

### Brewing depth
- [x] **(S) Add 14+ new recipes** to `Recipes.lua` to reach 20+ total. ✓ 2026-05-01 — 20 recipes shipped (5 Easy / 8 Mid / 5 Hard + 2 alt-paths). 12 new potion catalog entries. RecipesSpec covers integrity + alt-paths + cross-ref to Potions.byId.
- [x] **(L) Implement the remaining 7 potion effects** in `PotionEffects.lua`. ✓ 2026-05-01 — refactored to handler-table dispatch with per-kind stacking; 18 active potions in `Constants.POTIONS`.
  - [x] luck (rare-variant chance bonus) — exposed; rare-variant logic per ADR 002 lands later
  - [x] harvestYield (planted-harvest bonus) — wired into Harvesting.harvestPlot
  - [x] reveal (hidden mushrooms visible within X studs) — exposed; hidden mushrooms feature is content-side
  - [x] spiritAttract (attraction-roll bonus) — exposed; awaits Spirits system
  - [x] cosmeticGlow (player particle trail) — applies live (placeholder texture; user supplies asset later)
  - [x] weatherSummon (rain on local biome) — Phase 4 stub per spec; logs warning, updates HUD chip
  - [x] timeShift (player can toggle day/night on own plots) — Phase 4 stub per spec

### Forest Spirits
- [x] **(L) Spirit attraction system.** ✓ 2026-05-01 — per-player attraction loop every 5 min; chance/tick = (sum of speciesBase per held/grown species) / 12 × spiritAttract potion multiplier.
- [x] **(M) Spirit claim flow.** ✓ 2026-05-01 — ClaimSpirit remote with atomic claim-and-revert; range/owner/roster-cap validation; SpiritClaimCompleted reply; PassiveBonuses recompute on success.
- [x] **(M) Active-roster wandering AI.** ✓ 2026-05-01 — Heartbeat tick, idle/walking state machine, wander radius per rarity (Common 8, Rare 12), 4 studs/sec.
- [x] **(S) Spirit-as-item packaging.** ✓ 2026-05-01 — EquipSpirit/UnequipSpirit remotes; spirits live as `data.spirits.allOwned` (always) + `data.spirits.activeRoster` (subset); world Model spawns/despawns on roster transitions.

### Biome architecture
- [x] **(L) Refactor `MapSetup` and `WildSpawn` to be biome-parameterized.** ✓ 2026-05-01 — `Constants.BIOMES` table, per-biome `WildSpawn.startBiome` instances, new `BiomeBuilder` module for procedural per-biome construction with hand-built escape valve. (MapSetup's StarterGlade-specific Pre-Alpha layout is reused; full per-biome refactor of MapSetup deferred to a future polish pass.)
- [x] **(L) Misty Hollow biome.** ✓ 2026-05-01 — full data config (zone center 2000 studs east, rainforest atmosphere, water-loving wild table including Hollowstem/Dewfern/rare Glowmoss, peat as locally-cheap substrate). Procedural WildSpawnArea built; visual decoration awaits hand-built terrain pass.
- [x] **(S) Travel NPC at spawn.** ✓ 2026-05-01 — `Travel.luau` handles `RequestBiomeTravel` remote with renown + cost validation, sets `currentBiome` attribute. Per ADR 001 single-place zones (HumanoidRootPart.CFrame teleport, no TeleportService). Client-side Travel NPC dialogue UI is the remaining UX piece; backend is wired.

### Tests for everything new
- [ ] PotionEffects: per-effect happy path + duration test.
- [ ] Recipes: lookup table integrity, no duplicate keys.
- [ ] Spirits: attraction math, roster cap enforcement.

### Phase 1 open question to settle before starting
**Biomes as separate Places (per the PDF) vs. single-place zones?** Per-Place means each biome publishes separately, costs cross-place data races, but supports unique terrain/lighting per biome cleanly. Single-place means one giant world with zone teleports. Bee Swarm and Adopt Me both use single-place. Decide before doing the biome refactor — pivoting later is painful.

---

## Phase 2 — Closed Beta (social systems + content)

*Goal: trading economy lights up; quests provide structure; species count doubles.*

### Trading Post (the longevity engine)
- [x] **(L) Trade UI + flow.** ✓ 2026-05-03 — `src/client/TradeUI.client.luau`. Two-panel modal (your offer / their offer), 6-slot grid + coin input, item picker submodal, lock + 5s countdown + confirm flow per Adopt Me anti-scam UX. Player picker (HUD button) + incoming-request toast included.
- [x] **(L) Atomic trade execution server-side.** ✓ 2026-05-03 — `src/server/Trade.luau`. Validate-before-mutate + snapshot-rollback on partial failure. Re-validates both offers at confirmation time (items/coins may have moved during negotiation).
- [~] **(M) Anti-duping protections.** ✓ Audit log to `MyceliaAuditLog_v1` DataStore (separate from player saves). ✓ Confirmation-time re-validation. ⬜ Per-remote rate limits and inventory mutation lock during trade are deferred — confirmation re-validation covers the dupe path; rate limits prevent spam not duping.
- [~] **(M) Trading Post location** — placeholder wood marker Part at (25, _, 0) with surface text. Real zone (with travel portals from all biomes) is a follow-up; trade currently works from anywhere via the HUD "Trade" button.

### Player Stalls
- [ ] **(L) Stall rental flow.** Stall Manager NPC, daily fee, stall Model assigned to player.
- [ ] **(L) Listing UI** — fixed-price + auction with min bid + duration toggle.
- [ ] **(M) Browse + buy flow** — other players approach a stall, see listings, buy with prompt.
- [ ] **(M) Stall renewal/release loop** — daily auto-renew if owner has fee; otherwise listings return to inventory.

### Co-op Foraging Expeditions
- [ ] **(L) Lobby system.** Coordinator NPC, Create/Join tabs, lobby UI with kick + password + level requirement.
- [ ] **(L) Expedition Place(s).** Separate Roblox Places for each expedition type. Time limit, environmental constraints, special spawn tables.
- [ ] **(M) Party teleport via TeleportService** with reserved server.
- [ ] **(M) Reward distribution** based on participation. Mushrooms collected in expedition come back with players; unfinished items lost on failure.
- [ ] **(S) Lobby chat** — private channel per party.

### Quest system
- [x] **(L) Quest data structure** in `Quests.luau` (id, title, description, NPC, objectives, rewards, prerequisites, repeatable). ✓ 2026-05-03 — pure-data + 7 OBJECTIVE_KINDS + pure helpers (`canAccept`, `canTurnIn`, `objectiveMatches`, `applyEvent`).
- [x] **(L) Quest Journal UI** — Active / Completed / Available tabs. ✓ 2026-05-03 — `src/client/QuestController.client.luau`.
- [x] **(M) Tutorial 5-quest sequence** with Gardener Coach NPC at spawn. Teaches harvest → plant → sell → brew → discover. ✓ 2026-05-03 — 5 chained quests in `Quests.byId`, Gardener Coach dialogue tree owns all 5 start/turn-in responses with `condition` filtering.
- [x] **(S) HUD-tracked quest widget** — pinned objective summary top-right. ✓ 2026-05-03 — bundled into QuestController.

### NPC dialogue system
- [x] **(L) Dialogue tree data structure** per NPC. ✓ 2026-05-03 — `src/shared/Dialogues.luau` indexed by `[npcId][nodeId]`. Pure-data trees with `next` (navigation) or `action` (server side effect: openShop / endDialogue) per response. Schema + integrity tests in [DialoguesSpec.luau](../src/server/Tests/DialoguesSpec.luau).
- [x] **(M) Dialogue UI** — ✓ 2026-05-03 — `src/client/DialogueController.client.luau`. Bottom-anchored card, portrait + speakerName header, body line, scrollable response list, mobile-first 44pt buttons. Lockout-on-critical-lines is a Phase 3 polish item (intentionally deferred).
- [~] **Wire up the major launch NPCs** — 5 of 8 shipped as of 2026-05-03: Forest Witch, Gardener Coach (tutorial guide), Travel Coordinator (player-facing wrapper for the existing Travel.luau backend), Old Hermit (lore), Wandering Alchemist (lore + brewing tips). Pending: Spirit Speaker, Expedition Coordinator, Trading Post Manager — each tied to a system that hasn't shipped yet (Spirits dialogue, Expeditions, Trading Post). Adding them is mechanical once those land.

### Shop UI (replaces witch auto-sell)
- [x] **(L) Shared shop UI component** with Sell / Buy tabs. Used by all merchants. ✓ 2026-05-02 — `src/client/ShopUI.client.luau` shipped.
- [x] **(M) Per-merchant config** in `Constants.MERCHANTS`: which categories they buy, which items they sell, price modifiers, rep gates. ✓ 2026-05-02 — schema in [docs/specs/shop-ui.md](specs/shop-ui.md). ForestWitch entry migrated; 5 secondary merchants reserved as future tasks below.
- [~] **(M) Wire up secondary merchants** — partial: Substrate Dealer + Spore Merchant shipped 2026-05-03 (6 substrates, 3 spore samples). Spirit Food + Cosmetic + Decoration vendors are remaining (~30 min each — pattern is locked). Items are inert until cultivation depth lands; see HANDOFF for the schema-ready / behavior-deferred caveat.

### Content
- [ ] **(XL) Add 15+ new species** to reach 30+ across 5 tiers (add Legendary tier here). Mostly content/data work — `Species.lua` entries plus visual variants in `WildSpawn.SPECIES_VISUALS`.

### Tests
- [ ] Trading: end-to-end happy path + every cancel-condition path (disconnect, distance, decline, server crash).
- [ ] Stalls: listing + sale + renewal flows.
- [ ] Expeditions: lobby state machine, reward distribution math.
- [ ] Quests: objective tracking, prerequisite gating.

---

## Phase 3 — Soft Launch (monetization + polish)

*Goal: shippable to low-traffic regions. Mobile feels good. Money works.*

### Monetization
- [ ] **(L) Wire up gamepasses to MarketplaceService.** Bigger Plot, Auto-Harvester, Recipe Journal Plus, Inventory Expansion, Bigger Spirit Roster, Recyclable Substrate, Cosmetic Outfit Packs, House Upgrade.
- [ ] **(M) Wire up dev products** — Coin Pack (S/M/L), Speed-Up Potion (1/hr cap), Cosmetic Spirit Skin, Decoration Items.
- [ ] **(M) Server-side gamepass ownership cache** in PlayerData. Check on join, refresh on `PromptGamePassPurchaseFinished`.
- [ ] **(M) Shop UI** for browsing gamepasses + dev products in-game.

### Hut + decoration
- [ ] **(L) Hut interior system** — basic hut on first spawn, decoration anchors, personal cauldron + storage chest + spirit shelf inside.
- [ ] **(L) Decoration placement UI** — pick item → ghost preview follows cursor → tap to place. Long-press to remove.
- [ ] **(M) Hut Settings** — wall color, floor texture, lighting cycle, public/friends-only/private access.
- [ ] **(M) Plot visiting via TeleportService.** Visitor cannot modify host's stuff.
- [ ] **(S) Guestbook** — visitors can leave a message, persists in host's hut.

### Player profile + LiveOps
- [ ] **(M) Player profile UI** — reputation per NPC, total stats, discovery badges, total renown.
- [ ] **(L) LiveOps event scheduler.** Config-driven via `MessagingService` or HTTP endpoint. Daily login bonus, daily quest, weekly events.
- [ ] **(M) Event UI** — HUD button, event-info panel with current details, leaderboard, claimed rewards.
- [ ] **(M) Push-notification analog** — top-screen toast + chat-channel message when events start.

### Polish
- [ ] **(L) Mobile optimization pass.** 44pt tap-target audit, layout review on 6.1" reference device, performance/memory profiling.
- [ ] **(L) Camera scripting.** Smooth zoom, cinematic discovery moments, modal-open desaturation tween, lunar event pan, rare-event camera shake.
- [ ] **(L) Animation wiring** for all systems shipped to date. Player character (idle/walk/run/harvest/plant/brew/sell), NPCs, mushroom growth lerp, plot ripen wobble, harvest pickup float, spirit wandering, UI transitions, toast slide-in.
- [ ] **(L) Sound wiring** — per-biome ambient music (crossfade on biome change), per-season ambient layer, pond water spatial audio, wild forest ambience, all the SFX one-shots, UI SFX, spirit chime, lunar event audio.
- [ ] **(M) VFX wiring** — spore puff, brew bubbles, discovery glow, spirit summon, lunar event beam, seasonal particles, ambient (fireflies, glowing pollen).
- [ ] **(M) Settings UI** — master/music/SFX volume sliders, hut access, mute-when-tabbed-out, accessibility options.

### Anti-exploit hardening
- [ ] **(M) Rate limits on every remote** in `Constants.RATE_LIMITS`. Default 5/sec, override per-remote where appropriate.
- [ ] **(M) Audit logging** on every coin and item movement to a separate DataStore.
- [ ] **(S) Sanity check thresholds** — flag and log if a player gains >1M coins or >1000 items in a tick.
- [ ] **(S) Coin cap** — hard ceiling at 1 trillion to prevent integer overflow.
- [ ] **(S) Inventory cap enforcement** — server rejects adds that exceed slot/stack limits.

### Tests
- [ ] Monetization: every gamepass + dev product happy path.
- [ ] Rate limiting: simulate burst calls, verify rejection.
- [ ] Audit log: every transaction type produces a log entry.

---

## Phase 4 — Global Launch (content completeness)

*Goal: world fully built. All 60 species. All biomes. Seasons cycle. Ready for global push.*

### Remaining biomes (each is M-L on its own)
- [ ] **(L) Frostroot Pass** — snowy, slow-growing high-value species. Reputation 300 unlock.
- [ ] **(L) Sunken Grove** — swamp, alchemy ingredients. Reputation 600.
- [ ] **(L) Old Growth** — ancient forest, legendary species. Reputation 1500.
- [ ] **(L) Glimmerwood** — bioluminescent, night-only. Reputation 2500 + lunar quest.
- [ ] **(L) Lost Cathedral** — mythic spawns during events. Community-event unlock.

### Content completeness
- [ ] **(XL) 30+ more species** to reach 60 total. Mostly content work; integration is the scripting piece. Add Mythic tier with the species data.
- [ ] **(XL) Recipe space expansion** — more recipes for the new species and methods. Goal: thousands of possible combinations, hundreds of valid potions.

### Seasons + lunar cycles
- [ ] **(L) Server-side time engine.** Read `os.time()`, compute season + lunar phase from fixed epoch (e.g., 2026-01-01). All servers share the same season + moon phase.
- [ ] **(M) SeasonChanged + LunarPhaseChanged BindableEvents.** Subscribers: WildSpawn, Weather, Lighting, Spirits.
- [ ] **(M) Replicate to clients via SeasonState remote** for HUD season indicator.
- [ ] **(M) Per-season visual + gameplay effects** — Spring/Summer/Autumn/Winter palette + bonuses + VFX.
- [ ] **(M) Lunar mechanics** — Full Moon enables Glimmerwood legendary spawns, New Moon enables stealth/quieter movement.

### Weather
- [ ] **(L) Per-biome weather state.** Sunny / Cloudy / Rainy / Stormy / Snowy / Foggy. Probabilistic transitions every 10 min, biased by season.
- [ ] **(M) Weather replication + client VFX** — rain particles, snow, fog Atmosphere settings.
- [ ] **(M) Plot moisture during rain** — auto-raise moisture on rainy plots.
- [ ] **(S) Weather summon potion integration.**

### Final pass
- [ ] **(L) Balance pass.** Multi-session iteration on `Constants.lua`. Yields, prices, growth times, drop rates, spirit attraction, recipe costs.
- [ ] **(M) Roblox compliance review.** Chat filtering certified, age-appropriate content checked, parental purchase consent flows tested.
- [ ] **(M) 1-week stability soak** with 0 critical bugs before global push.

---

## After launch (ongoing)

Things that aren't part of any single phase but keep the game alive:

- **(XL ongoing) LiveOps content.** Weekly events, monthly mythic spawns, seasonal stories, exclusive cosmetic drops. Realistically one major event per month from launch.
- **(L per drop) New biomes** beyond the launch 7. Each follows the parameterized biome system.
- **(M per drop) New gamepasses + dev products** as the player base shows what's wanted.
- **(S per drop) Recipe additions** — easy way to add discovery content without new systems.
- **(M ongoing) Bug fixes + balance hot-fixes + exploit response.** Daily check on the Audit DataStore for suspicious activity.

---

## Open questions to resolve when you reach them

These are decisions, not tasks. They block specific work but don't need answering until then:

1. ~~**Per-biome Place vs single-place zones**~~ **RESOLVED 2026-05-01: single-place zones.** Per-Place via TeleportService used only for foraging expeditions (and possibly limited-time event biomes). Full reasoning in [decisions/001-biome-architecture.md](decisions/001-biome-architecture.md).
2. ~~**Substrate compatibility math**~~ **RESOLVED 2026-05-01:** per-species `yieldBySubstrate` table, multiplicative formula with substrate as the only hard-failure variable. Full reasoning in [decisions/002-cultivation-yield-formula.md](decisions/002-cultivation-yield-formula.md).
3. ~~**Reputation gain rates**~~ **RESOLVED 2026-05-01:** two-layer model (per-NPC rep cap 5000 with five friendship tiers, total renown gates biome unlocks). Decelerating gain curve. Full table of gain sources + numbers in [decisions/003-reputation-rates.md](decisions/003-reputation-rates.md).
4. ~~**Rare-variant drop chance curve**~~ **RESOLVED 2026-05-01:** base 1% per yielded mushroom, scales with multiplier excess + magical-loam flat bonus, capped at 10%. Same ADR: [decisions/002-cultivation-yield-formula.md](decisions/002-cultivation-yield-formula.md).
5. ~~**Coin economy floor and ceiling**~~ **RESOLVED 2026-05-01:** earning curve targets 10× wealth growth per 5× hours. Realistic player ceiling 10M; hard cap 10B. NPC prices fixed forever (anti-inflation). Full curve, wealth tiers, sinks/faucets, anti-exploit thresholds in [decisions/004-coin-economy.md](decisions/004-coin-economy.md).

---

*Last touched: 2026-05-01. Reflects state described in the Scripting Order Request PDF dated 2026-04-30.*
