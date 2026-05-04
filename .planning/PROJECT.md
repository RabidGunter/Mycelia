# Mycelia — PROJECT.md

GSD project memory: who, what, why. Synthesized from `.planning/intel/SYNTHESIS.md` (entry point) and the canonical `docs/` corpus. **Do not duplicate** the contents of ADRs or specs here — link to them.

---

## Identity

- **Name:** Mycelia (working title; final naming candidates listed in [docs/DESIGN.md §Naming](../docs/DESIGN.md))
- **Type:** Roblox cozy life-sim game (Luau / `.luau`)
- **Genre line:** *Stardew Valley's quiet pace wrapped around Bee Swarm Simulator's depth, with a player-driven potion economy as the long-term retention engine.* ([docs/PROJECT-REVIEW.md](../docs/PROJECT-REVIEW.md))
- **Target runtime:** Roblox client. **Mobile-first.** PC + console secondary. Studio + Rojo workflow on dev side.
- **Target audience:** Primary 9–16; designed to retain into adulthood (Bee Swarm Simulator lineage).
- **Repo layout:** `src/` is canonical Rojo source (per `default.project.json`). `docs/` is the design corpus (DESIGN, ROADMAP, CONTRIBUTING, ADRs, specs). Legacy `mycelia/src/` and `mycelia/HANDOFF.md` are archive-only.

---

## Core value

A cozy mushroom-cultivation game where the **5-minute first-hour loop** (walk → harvest → sell → plant → wait → harvest more) gradually unfolds into a **200-hour optimization puzzle**, a **player-driven trading economy**, and a **collection ceiling that grows with the game**. ([docs/DESIGN.md §Core Vision Statement](../docs/DESIGN.md))

The trading economy is the **longevity engine** — the thing that turns the game from a playable demo into a place players come back to for years.

---

## Developer-facing success metrics

- **Daily check-in habit retention.** Game must support 5–15 min casual sessions and 60+ min engaged sessions. Daily login pressure exists (LiveOps + lunar cycles) but never feels coercive.
- **200-hour optimization depth** for engaged players. The 6-variable cultivation puzzle, recipe discovery space (thousands of combinations), and Pokedex completion all need to hold up at hour 100+ without feeling exhausted.
- **Player-driven trading economy as long-term retention engine.** Trading Post + Player Stalls + Co-op Foraging Expeditions create the social density that drives the algorithm. **Critical rule:** never let real-money purchases bypass this economy.
- **Player progression milestones (DESIGN.md §Progression Curve):** Hour 1 discover loop · Hour 5 second biome + first trade · Hour 20 deep recipes · Hour 50 specialize · Hour 100 build a "build" · Hour 500 game has become a place.

---

## Target audience

- **Primary:** Roblox players age 9–16. Mobile-first because that's where this audience lives.
- **Designed to retain:** This audience grows up; the game should age with them (Bee Swarm Simulator pattern — players stayed for years).
- **Session shape:** 5–15 min casual / 60+ min engaged. Not a competitive game; not a quick-burst game; a *cozy place to come back to*.

---

## Decisions

All four ADRs are **LOCKED**. Source documents in `docs/decisions/` are immutable per [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md). Supersession requires a new numbered ADR.

```
<decisions locked="true">
  <decision id="DECISION-001" status="locked">
    Biome architecture is single-place zones. Travel between biomes uses CFrame teleport
    (HumanoidRootPart re-anchor), never TeleportService. TeleportService is reserved for
    ephemeral instanced content — foraging expeditions (Phase 2) and possibly limited-time
    event biomes.
    See: docs/decisions/001-biome-architecture.md
  </decision>

  <decision id="DECISION-002" status="locked">
    Cultivation yield + rare-variant formula. Per-species yieldBySubstrate table.
    Multiplicative yield formula. Substrate is the ONLY hard-failure variable (multiplier
    0 → plot Failed). Yield capped at 5; excess flows to rare-variant chance. Growth time
    is decoupled from substrate. Rare-variant chance capped at 10% with magical-loam bonus.
    Source-agnostic player bonus aggregation via PotionEffects + PassiveBonuses + future.
    See: docs/decisions/002-cultivation-yield-formula.md
  </decision>

  <decision id="DECISION-003" status="locked">
    Reputation rates and tiers. Two-layer model:
    (1) Per-NPC rep capped at 5000 with 5 friendship tiers (Acquaintance / Familiar /
        Friend / Trusted / Confidant) — gates NPC-specific content.
    (2) Total renown (sum across all NPCs) gates biome unlocks
        (StarterGlade 0 / MistyHollow 100 / FrostrootPass 300 / SunkenGrove 600 /
         OldGrowth 1500 / Glimmerwood 2500+lunar quest / LostCathedral event-based).
    Decelerating gain curve (1.0× / 0.5× / 0.25× / 0× by score band).
    See: docs/decisions/003-reputation-rates.md
  </decision>

  <decision id="DECISION-004" status="locked">
    Coin economy floor and ceiling. 10B hard cap, 10M realistic player ceiling, 100M+
    suspicious. Three-layer anti-exploit defense (hard cap + per-tick reject 10M +
    audit log threshold 1M). NPC prices are fixed forever — wealth growth comes from
    rarity-of-output, not price-inflation-of-output. Coins.add is the single chokepoint
    for all coin gains; no direct data.coins += x writes elsewhere.
    See: docs/decisions/004-coin-economy.md
  </decision>
</decisions>
```

These four decisions cannot be unlocked via spec or roadmap edits. Override criteria are defined inside each ADR.

---

## Constraints

12 SPECs in `docs/specs/` define implementation contracts. Synthesized in [.planning/intel/constraints.md](intel/constraints.md). Each is mutable in place (per CONTRIBUTING.md) but represents the current source of truth for its system.

**Schemas + data tables**

- [species-data.md](../docs/specs/species-data.md) — 15 Pre-Alpha species + 6 substrates; yieldBySubstrate authoring rules.
- [save-schema-v3.md](../docs/specs/save-schema-v3.md) — v3 PlayerData shape, idempotent v1→v2→v3 migration, ProfileService contract.
- [potions-and-recipes.md](../docs/specs/potions-and-recipes.md) — 20 recipes / 18 potions / 10 effect kinds; stacking rules.
- [biome-config.md](../docs/specs/biome-config.md) — biome schema, StarterGlade + MistyHollow configs, transition contract, StreamingEnabled tuning.
- [visual-language.md](../docs/specs/visual-language.md) — 12 brand tokens / 6 rarity tiers / 7 biome palettes / Constants.UI table.

**API + protocol contracts**

- [remote-api.md](../docs/specs/remote-api.md) — every RemoteEvent / RemoteFunction with signature, validation, error code, rate limit.
- [shop-ui.md](../docs/specs/shop-ui.md) — shared Buy/Sell modal; per-merchant config schema; ForestWitch + 5 secondary merchants.
- [trading-post.md](../docs/specs/trading-post.md) — atomic two-player trade; in-memory sessions; audit DataStore; lock + countdown + confirm UX.
- [player-stalls.md](../docs/specs/player-stalls.md) — **brand new spec 2026-05-03; implementation pending.** Personal stall + featured row + mailbox + shared Exchange.luau core.
- [dialogue-system.md](../docs/specs/dialogue-system.md) — pure-data trees, client-side navigation, server-side action validation; mutual exclusivity at anchor.
- [quest-system.md](../docs/specs/quest-system.md) — pure-data quests, event-driven progress, dialogue-driven lifecycle, Journal + HUD widget.

**Module contracts**

- [spirits.md](../docs/specs/spirits.md) — 7-spirit catalog; attraction algorithm; claim race-condition handling; PassiveBonuses module.

---

## Codebase rules (locked, "don't break")

From [CLAUDE.md](../CLAUDE.md) + [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md). These are non-negotiable; treat as project axioms.

1. **Server-authoritative everything.** Clients send intents via Remotes; server validates before any state mutation. Never trust client input.
2. **Tunables in `src/shared/Constants.luau`.** Anything balance-affecting (costs, durations, multipliers, drop rates) lives there, not in logic files.
3. **Species `id` never changes once shipped.** It's the save-data key. Add new species, don't rename old ones.
4. **No pay-to-win.** Robux unlocks time and cosmetics, never rare items, recipes, or trading advantages.
5. **Match existing module conventions.** Don't introduce new patterns (OOP frameworks, DI, alternative module structures) without writing an ADR first.
6. **Pure-function modules get tests. Server-side remote handlers get tests.** Test framework is in-house TestKit (no Wally / external deps).
7. **`Coins.add` is the single chokepoint** for coin mutations (per ADR 004). No direct `data.coins += x`.
8. **Multi-machine workflow is asymmetric.** Personal machine pushes; work laptop is pull-only (network monitoring concern). See [docs/git-setup.md](../docs/git-setup.md).

---

## Things to never do

- Push code from a work machine, even to a private repo.
- Sell power, rarity, or trading advantages for Robux.
- Skip server-side validation on a remote because "the client UI guarantees it."
- Rename a shipped species `id`.
- Edit `.rbxl` / `.rbxlx` / `.rbxm` / `.rbxmx` files outside Studio.
- Introduce new module conventions without an ADR.
- Reach into Roblox Service objects in pure-function tests — keep test modules dependency-free.
- Hardcode magic numbers in logic files when a Constants entry would do.
- Hardcode hex codes in UI logic — pull from `Constants.UI.color.*` per visual-language spec.

---

## Working environment

- **Studio + Rojo workflow.** `rojo serve default.project.json` from VS Code; connect via Rojo Studio plugin.
- **Rojo pinned at `7.7.0-rc.1`** via `aftman.toml`. Run `rojo plugin install` from project folder once.
- **DataStore unavailable in unpublished places.** PlayerData.lua pcalls and degrades gracefully. Place is currently published as "Mycelia" under RabidGunter's account; enable saves via File → Save to Roblox + Game Settings → Security → Enable Studio Access to API Services.
- **Test runner:** `src/server/Tests/RunTests.server.luau` auto-runs on Studio Play.

---

## Failure modes (watched)

From [docs/DESIGN.md §What Could Kill This Game](../docs/DESIGN.md):

1. Going pay-to-win — guts the trading economy in 6 months.
2. Recipe space too small — players exhaust discovery in week 1.
3. Mobile controls feel bad — losing 40%+ audience instantly.
4. No LiveOps cadence — algorithm punishment, players churn.
5. Onboarding too slow — first 2 minutes boring = done.
6. Trading exploits — duping bugs killed early Adopt Me momentum.
7. Trying to scope too big — launch with 60 species, not 200; add over time.

---

## Reference index

- **Entry point for downstream agents:** [.planning/intel/SYNTHESIS.md](intel/SYNTHESIS.md)
- **Per-type intel:** [decisions.md](intel/decisions.md) · [requirements.md](intel/requirements.md) · [constraints.md](intel/constraints.md) · [context.md](intel/context.md)
- **Conflict report:** [.planning/INGEST-CONFLICTS.md](INGEST-CONFLICTS.md) — 0 BLOCKERS, 0 WARNINGS, 5 INFO entries auto-resolved.
- **Design north star:** [docs/DESIGN.md](../docs/DESIGN.md)
- **Current state:** [HANDOFF.md](../HANDOFF.md) (root, canonical)
- **Process rules:** [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md)
- **AI assistant primer:** [CLAUDE.md](../CLAUDE.md)
