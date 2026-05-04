# Synthesis Summary

Entry point for downstream consumers (gsd-roadmapper). All numbers below are derived from the 26 classification JSONs in `.planning/intel/classifications/` and the source documents themselves.

---

## Doc counts by type

| Type | Count | Notes |
|---|---|---|
| ADR | 4 | All locked (Accepted), all 2026-05-01 |
| SPEC | 12 | Mix of shipped (Shop UI, Trading Post, Quest, Dialogue) and in-progress/pending (Player Stalls — written 2026-05-03, implementation pending) |
| DOC | 10 | Vision, roadmap, current state, contributing rules, project review, visual references, README, AI primer, git workflow, legacy archived handoff |
| **Total** | **26** | All `confidence: high`. None UNKNOWN. None require user re-tagging. |

---

## Decisions locked (from ADRs)

4 LOCKED decisions, no LOCKED-vs-LOCKED contradictions detected. Full text in `intel/decisions.md`.

- **DECISION-001:** Biome Architecture — single-place zones; TeleportService reserved for ephemeral instanced content (foraging expeditions). [docs/decisions/001-biome-architecture.md]
- **DECISION-002:** Cultivation Yield + Rare-Variant Formula — per-species `yieldBySubstrate` table, multiplicative formula with substrate as only HARD failure variable, decoupled growth-time formula, rare-variant chance with magical-loam bonus capped at 10%. Source-agnostic player bonus aggregation (`PotionEffects + PassiveBonuses + future`). [docs/decisions/002-cultivation-yield-formula.md]
- **DECISION-003:** Reputation Rates and Tiers — two-layer model (per-NPC cap 5000 with 5 friendship tiers gates NPC-specific content; total renown gates biome unlocks); decelerating gain curve. [docs/decisions/003-reputation-rates.md]
- **DECISION-004:** Coin Economy — 10B hard cap, 10M realistic ceiling, fixed NPC prices, three-layer anti-exploit defense (hard cap + per-tick reject + audit log), `Coins.add` as single chokepoint. [docs/decisions/004-coin-economy.md]

---

## Requirements extracted (from PRDs)

**0 PRDs in ingest set.** Mycelia uses an ADR-then-spec workflow (per docs/CONTRIBUTING.md); explicit product-requirements documents are not currently authored. Requirement-shaped intent lives in:
- `docs/ROADMAP.md` task list (with phase + size markers + completion ticks) — synthesized in `intel/context.md` §Roadmap.
- Per-feature acceptance criteria embedded in each SPEC's "tests" / "validation matrix" / "verification pending in Studio" sections — synthesized in `intel/constraints.md`.
- Definition of Done in `docs/CONTRIBUTING.md` — synthesized in `intel/context.md` §Documentation hygiene.

See `intel/requirements.md` for the explanatory note.

---

## Constraints extracted (from SPECs)

12 SPECs synthesized into `intel/constraints.md`. By type:

| SPEC | Type | Status |
|---|---|---|
| species-data | schema (data tables) | Complete for 15 Pre-Alpha species + 6 substrates; copy-pasteable |
| save-schema-v3 | schema (save data) + ProfileService contract | Phase 1 shipped; idempotent v1→v2→v3 migration |
| remote-api | api-contract (every Remote) | Authoritative; updated each phase |
| potions-and-recipes | schema + module-contract | 20 recipes / 18 potions / 10 effect kinds shipped |
| spirits | schema + protocol + module-contract | Spirits + PassiveBonuses shipped Phase 1 |
| biome-config | schema (config) + protocol | StarterGlade + MistyHollow shipped; 5 biomes Phase 4 |
| shop-ui | api-contract + UI surface | Shipped Phase 2 (2026-05-02), 2 of 6 secondary merchants live |
| trading-post | protocol + state-machine + api-contract | Shipped Phase 2 (2026-05-03) — backend + UI + audit log |
| player-stalls | protocol + state-machine + api-contract | **Brand new spec 2026-05-03; implementation pending** |
| dialogue-system | protocol + UI surface | Shipped Phase 2 (2026-05-03); 5 of 8 launch NPC trees |
| quest-system | protocol + module-contract + UI surface | Shipped Phase 2 (2026-05-03) — foundation + tutorial sequence |
| visual-language | schema (design tokens) + style contract | Foundation locked; consumed by Shop UI + Quest + Dialogue + Trade UIs |

---

## Context topics (from DOCs)

10 DOCs synthesized into `intel/context.md` under named sections. Key topics:

- **Project identity + vision** (DESIGN.md canonical)
- **Game systems** (8 systems from DESIGN.md §Game Systems)
- **Progression curve** (Hour 1 / 5 / 20 / 50 / 100 / 500 retention waves)
- **Monetization plan** (cosmetic-only, never pay-to-win)
- **LiveOps cadence + social hooks**
- **Failure modes** (7 watched failure modes)
- **Roadmap** (canonical phase plan from ROADMAP.md — Pre-Alpha + 4 phases + after-launch)
- **Current state** (HANDOFF.md root canonical; legacy mycelia/HANDOFF.md archived)
- **Codebase rules locked** (server-authoritative, tunables in Constants, never rename species id, no pay-to-win, ADR-first for new patterns, pure-function modules get tests)
- **Documentation hygiene** (docs-stay-current rule; ADR vs SPEC distinction; Definition of Done)
- **Multi-machine workflow** (asymmetric pull-only — personal pushes, work laptop pulls)
- **Visual references board** (curated external links paired with visual-language spec)
- **Test count baseline** (74 → 166 → ~253 progression)

---

## Conflicts

- **0 BLOCKERS**
- **0 WARNINGS** (no PRD competing variants — no PRDs in ingest set)
- **5 INFO entries** (auto-resolved):
  1. SPEC > DOC on launch biome count (7 in SPEC vs 12 mentioned in DESIGN.md)
  2. SPEC field rename of ADR-cited constant (`witchPriceMultiplier` → `MERCHANTS.ForestWitch.buyMultiplier`)
  3. Two HANDOFF.md files (root canonical, legacy archive-only per prompt + root file disposition)
  4. Test count snapshots vary across docs (different timestamps; HANDOFF canonical for current)
  5. DESIGN.md "60 species at launch" vs phased 15→30→60 in ROADMAP (terminology drift; "launch" = Phase 4 Global Launch)

Cycle detection on cross_refs graph: **no cycles found.** Most edges point to ROADMAP.md or upward to ADRs; no back-edges that would create a cycle.

Full conflict report: `.planning/INGEST-CONFLICTS.md`

---

## Per-type intel files (downstream consumers read these directly)

- `intel/decisions.md` — 4 LOCKED decisions with statement, scope, rationale, constants contract, override criteria
- `intel/requirements.md` — explanatory note (no PRDs in set; pointers to where requirement-shaped intent lives)
- `intel/constraints.md` — 12 SPECs as detailed constraint blocks (one per spec)
- `intel/context.md` — 10 DOCs synthesized by topic
- `INGEST-CONFLICTS.md` (one level up) — full conflict report per `references/doc-conflict-engine.md` format

---

## Notes for `gsd-roadmapper` (downstream consumer)

1. **Phase plan is well-defined.** ROADMAP.md is canonical multi-phase: Pre-Alpha (shipped), Phase 1 Alpha (shipped), Phase 2 Closed Beta (in progress with tracked sub-features), Phase 3 Soft Launch (not started), Phase 4 Global Launch (not started). Reproducing this multi-phase structure in ROADMAP output is essential — collapsing to single-phase loses critical scope/timing context.

2. **Current Phase 2 status is mid-flight.** Multiple sub-features have shipped this week (2026-05-02 and 2026-05-03); Player Stalls spec is brand new (today, 2026-05-03) with implementation pending. The synthesized context preserves the "shipped vs pending" status per sub-feature.

3. **Project state is HANDOFF.md-driven.** Use HANDOFF.md root as canonical state; treat the legacy mycelia/HANDOFF.md as archive-only history (per ingest prompt + root file's own disposition statement).

4. **All four ADRs are LOCKED and were never contradicted by any SPEC or DOC.** They can be carried into PROJECT.md / REQUIREMENTS.md as `<decisions>` entries with `locked: true`.

5. **No user-facing prompts needed.** Zero blockers, zero competing variants — synthesis is safe to route directly. INFO entries are recorded for transparency and don't gate progression.

6. **Player Stalls spec is implementation-ready but unimplemented.** If the roadmapper drafts a Phase 2 backlog, Player Stalls (with its `Exchange.luau` shared core that requires refactoring Trade.luau) is a major deliverable not yet started. Detailed in `intel/constraints.md` CONSTRAINT-player-stalls and referenced in `intel/context.md` §Roadmap.
