# Mycelia — Project Review

A cozy mushroom-cultivation game for Roblox, in active development. Built solo as a long-term project, currently in early **Closed Beta** development (about 4 months in).

This document is for reviewers — a snapshot of what the game is, what's been built, what's coming, and where I'd appreciate feedback. Skim the headers; dive into whatever section matters most for your review.

---

## What it is — in one paragraph

Mycelia is **Stardew Valley's quiet pace wrapped around Bee Swarm Simulator's depth**, with a player-driven potion economy as the long-term retention engine. You walk into a misty starter glade, harvest glowing mushrooms, sell them to a Forest Witch, plant your first patch of spores, and discover that brewing potions is recipe-driven and combinatorial. By hour 50 you're balancing six cultivation variables, hunting rare biome-specific species, and running a stall in the Trading Post. By hour 500, the game is a place, not a game.

**Genre:** cozy life-sim with hidden depth.
**Platform:** Roblox, mobile-first.
**Audience:** primary 9–16, designed to retain into adulthood (the Bee Swarm pattern).
**Session shape:** 5–15 min for casual; 60+ min for engaged; daily check-in habit.

---

## The five-minute core loop

Every new player should hit this loop in their first 5 minutes:

1. **Walk** into a misty glade with glowing mushroom spots.
2. **Harvest** with a tap.
3. **Sell** at the Forest Witch's stall, OR drop ingredients in the cauldron to brew.
4. **Plant** a Spore Patch with the coins.
5. **Wait** a minute — harvest again, more grew because of intentional planting.

That's the whole game. Everything else — recipe discovery, trading, spirits, biomes, seasons, lunar cycles — is depth layered on top.

---

## The depth layer (200-hour version)

The same loop scales:

- **Harvest** → 7 biomes (forest, rainforest, alpine, swamp, ancient forest, bioluminescent, ruined cathedral) with seasonal rotations and lunar mechanics.
- **Sell** → player-driven Trading Post, player-rented stalls, potion auctions.
- **Plant** → six-variable cultivation puzzle (substrate, moisture, light, host tree, pH, companions). Real optimization, not fake.
- **Wait** → lunar cycles, season rotations, time-gated rare species.
- **Brew** → 60 species × 4 methods × 1–5 ingredient combos = thousands of possible recipes, hundreds of valuable ones. **Recipes aren't given — they're discovered.** Wikis and Discord servers grow up around the discovery process.

The full vision is in [DESIGN.md](DESIGN.md) — the canonical 8-page design doc with progression curves, monetization plan (cosmetic-only — never pay-to-win), LiveOps cadence, and the failure modes I'm watching out for.

---

## What's been built so far

### Pre-Alpha (shipped, verified in Studio)
- Core gameplay loop end-to-end: walk → harvest → plant → sell → brew → consume.
- 15 mushroom species across 4 rarity tiers.
- 6 brewing recipes, 3 active potion effects.
- Hand-painted starter biome: mossy mountain with cave interior (witch + cauldron live in the cave), pond west of spawn with animated koi, paths, hills.
- Brewing Journal UI showing discovered + undiscovered potions.
- DataStore persistence with autosave.

### Phase 1 — Alpha (shipped, verified 2026-05-02)
- **Save persistence migrated to ProfileService** with session locking + autosave + retries.
- **Save schema v3** — 11-category inventory, spirits, decorations, plots, reputation, quests, gamepass tracking, audit trail. Idempotent v1→v2→v3 migration.
- **20 brewing recipes** (5 Easy, 8 Mid, 5 Hard + 2 alt-paths) → 18 unique potions in the catalog.
- **10 potion effect kinds** with handler-table dispatch and per-kind stacking rules: speed, growth, wildYield, harvestYield, luck, reveal, spiritAttract, cosmeticGlow, weatherSummon (Phase 4 stub), timeShift (Phase 4 stub).
- **Forest Spirits system** — 6 spirits (Mossling, Spritefly, Dewdrop, Lanternfox, Crystalmoth, Deerlet). Per-player attraction loop, atomic claim flow, equip/unequip, wandering AI, passive bonuses (yield/growth speed) wired into actual gameplay.
- **Biome architecture refactor** — biome-parameterized WildSpawn, BiomeBuilder module, second biome (Misty Hollow) shipped as data + procedural spawn area.
- **Travel system** — biome unlock gates (renown threshold + coin cost), HumanoidRootPart-based teleport per ADR-001 (single-place world).
- **166 unit tests passing** via in-house TestKit (no external dependencies).

### Phase 2 — Closed Beta (in progress, first milestone shipped 2026-05-02)
- **Visual language locked** — full palette spec ([visual-language.md](specs/visual-language.md)) covering brand tokens, 6 rarity-tier colors, 7 biome palettes, UI surface tokens, typography (Merriweather + Nunito + Inconsolata), motion, spacing.
- **Shop UI shipped** — replaces the Pre-Alpha witch auto-sell. Shared modal component (Sell / Buy tabs, per-row qty stepper, running total) used by every future merchant. Per-merchant config in `Constants.MERCHANTS`. Reputation hook stubbed for the future Reputation system.

---

## Visual direction

> Hand-painted, slightly desaturated cozy aesthetic. Studio Ghibli forest scenes meets cottagecore.

Concrete translation:
- **Warm earth tones** as the base, not greys. Cream parchment + mossy ink instead of white + black.
- **Desaturated greens** for the dominant brand color — verdant but never neon.
- **Jewel accents reserved for rarity and magic.** Common items live in earth; legendaries glow.
- **Mobile-first contrast.** All text hits WCAG AA. 44pt minimum tap targets.

Reference points: Stardew Valley (warmth, scale, single-screen intimacy), Cozy Grove + Ooblets (modern cottagecore UI), Hollow Knight (handmade shop ornaments). The full palette + reference board is in [docs/specs/visual-language.md](specs/visual-language.md) and [docs/visual-references.md](visual-references.md).

---

## Architecture overview (for engineering reviewers)

- **Roblox + Luau**, synced via [Rojo](https://rojo.space/) from a `default.project.json`. Source lives under `src/` (server / client / shared).
- **Server-authoritative everything.** Clients send intents via Remotes; server validates before any state mutation.
- **Tunables in `Constants.luau`.** Anything balance-affecting lives there, not in logic files.
- **ProfileService** for session-locked DataStore persistence with graceful degradation in unpublished places.
- **Pure-function modules get tests.** Server-side remote handlers get tests. 166 tests passing as of 2026-05-02; in-house TestKit (no Wally / no external dependencies).
- **ADR process for architectural decisions.** Locked-in choices live in `docs/decisions/` (currently 4 ADRs covering biome architecture, cultivation yield formula, reputation rates, coin economy).
- **Implementation specs in `docs/specs/`** (mutable; copy-pasteable into code) cover species data, save schema v3, every remote, brewing depth, spirits, biomes, the Shop UI, and the visual language.

---

## What's coming (Phase 2 → Launch)

### Phase 2 — Closed Beta (current)
*Goal: trading economy lights up; quests provide structure; species count doubles.*

- **NPC dialogue system** — tree-based, every Phase 2 system feeds through it.
- **Quest system + tutorial 5-quest sequence** with the Forest Witch as guide.
- **Trading Post** (the longevity engine) — atomic two-player trade, anti-duping audit log, cooldown-into-accept-button anti-scam UX.
- **Player-rented stalls** — auto-pricing or auction listings.
- **Co-op Foraging Expeditions** — 2–4 player runs into deeper biomes via TeleportService.
- **Secondary merchants** — Substrate Dealer, Spore Merchant, Spirit Food, Cosmetic, Decoration. (Schema is ready; each is a small follow-up to Shop UI.)
- **30+ species total** (currently 15 → 30, with Legendary tier introduced).

### Phase 3 — Soft Launch
*Goal: shippable to low-traffic regions. Mobile feels good. Money works.*

- Monetization wired to MarketplaceService — gamepasses + dev products (Bigger Plot, Auto-Harvester, cosmetics, coin packs).
- Hut interior + decoration placement + plot visiting via TeleportService.
- LiveOps event scheduler + daily login + weekly events.
- Mobile optimization pass, animation/sound/VFX wiring.
- Anti-exploit hardening (rate limits, audit logging, sanity-check thresholds).

### Phase 4 — Global Launch
*Goal: world fully built. All 60 species. All 7 biomes. Seasons cycle.*

- Five remaining biomes (Frostroot Pass, Sunken Grove, Old Growth, Glimmerwood, Lost Cathedral).
- 60 species total (Mythic tier introduced).
- Server-side time engine for seasons + lunar cycles, replicated to all clients.
- Per-biome weather (sunny/cloudy/rainy/stormy/snowy/foggy with probabilistic transitions).
- Balance pass, compliance review, 1-week stability soak.

---

## Where I'd appreciate feedback

If the reviewer has perspective on any of these, it'd be especially useful:

1. **Visual direction** — does the cottagecore + Ghibli palette feel distinctive on Roblox, or is it competing with too many similar games? (Specifically, is there a less-saturated direction worth considering?)
2. **The recipe-discovery hook** — is "thousands of possible recipes, hundreds of valuable ones" the right size for a 7-year game, or does this need wider/narrower combinatorics?
3. **The Trading Post architecture** — Phase 2's biggest unknown is whether the atomic-trade flow + audit-log approach is bulletproof against duping. Independent reads on the [trade remote spec](specs/remote-api.md) (lines 281–381) would be valuable.
4. **Pacing of progression** — does the Hour 1 / 5 / 20 / 50 / 100 / 500 retention-wave plan feel realistic, or is it too aggressive / too gentle?
5. **Anything obviously missing** that you'd expect to see in a cozy Roblox game targeting this audience.

---

## Quick stats

| Metric | Current |
|---|---|
| Test coverage | 166 unit tests, 100% passing |
| Lines of Luau | ~6,000 (gameplay) + ~2,000 (tests) |
| Active modules | 18 server, 9 client, 6 shared |
| Species | 15 (target: 60 at Global Launch) |
| Recipes | 20 (target: thousands of combos at maturity) |
| Biomes shipped | 2 of 7 (StarterGlade, Misty Hollow) |
| Test framework | In-house TestKit (no external deps) |
| Save schema | v3 (with idempotent v1→v3 migration) |
| Persistence backend | ProfileService (session-locked, autosave) |

---

## Reading order if you have 30 minutes

1. **This document** (you're reading it) — 5 min
2. [DESIGN.md](DESIGN.md) — 10 min — the full vision
3. [docs/ROADMAP.md](ROADMAP.md) — 10 min — the actionable build plan, phase by phase
4. (optional) [docs/specs/visual-language.md](specs/visual-language.md) — 5 min — palette + tokens

Skip the ADRs (`docs/decisions/`) and implementation specs (`docs/specs/`) unless something in the above flags a question.

---

*Generated 2026-05-02. State reflects: Phase 1 verified complete in Studio; Phase 2 first milestone (Shop UI) shipped same day. Live deployment pending — game is playable in Studio but not yet published.*
