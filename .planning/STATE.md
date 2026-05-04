# Mycelia — STATE.md

GSD project memory. Updated by orchestrator agents after every non-trivial unit of work. Mirrors authoritative state from [HANDOFF.md](../HANDOFF.md) for the GSD layer; HANDOFF.md remains the canonical session log for code state.

**Last updated:** 2026-05-03 (initial state from `new-project-from-ingest` synthesis)

---

## Project Reference

- **Name:** Mycelia (working title)
- **Type:** Roblox cozy life-sim game (Luau / `.luau`)
- **Core value:** Cozy mushroom-cultivation game where the 5-min first-hour loop unfolds into a 200-hour optimization puzzle, a player-driven trading economy, and a collection ceiling that grows with the game. ([docs/DESIGN.md](../docs/DESIGN.md))
- **Current focus:** Phase 2 Closed Beta in progress. **Next pickup: Player Stalls implementation** per the approved spec at [docs/specs/player-stalls.md](../docs/specs/player-stalls.md).
- **Repo root:** `c:\Users\fonte\Documents\Mycelia\`
- **Canonical Rojo source:** `src/` (per `default.project.json`); legacy `mycelia/src/` is archive-only.

---

## Current Position

- **Phase:** 2 — Closed Beta (social systems + content) — *In progress*
- **Plan:** None active. Next plan to author: **Player Stalls** (P2-STALL-01..06).
- **Status:** Phase 1 complete; Phase 2 mid-flight with 6 milestones shipped 2026-05-02 / 2026-05-03 (Shop UI · Substrate Dealer + Spore Merchant · Dialogue system · Quest system + tutorial · 5-of-8 launch NPCs · Trading Post backend + UI + audit log).
- **Tests:** ~253 passing (166 Phase 1 baseline + ~30 ShopSpec + ~10 expanded ShopSpec + ~11 DialoguesSpec + ~16 QuestsSpec + ~20 TradeSpec). Studio verification pending for the most recent additions per HANDOFF.md.

### Phase progress bar

```
Pre-Alpha:    [██████████] complete (baseline)
Phase 1:      [██████████] complete 2026-05-02 (166 tests verified)
Phase 2:      [████░░░░░░] in progress (6 of ~12 sub-feature groups shipped or partial)
Phase 3:      [░░░░░░░░░░] not started
Phase 4:      [░░░░░░░░░░] not started
After launch: [░░░░░░░░░░] not started
```

---

## Performance Metrics

- **Lines of Luau (~snapshot 2026-05-02 from PROJECT-REVIEW.md):** ~6,000 gameplay + ~2,000 tests
- **Active modules:** 18 server, 9 client, 6 shared
- **Save schema:** v3 (idempotent v1→v2→v3 migration)
- **Persistence backend:** ProfileService (session-locked, autosave)
- **Test framework:** in-house TestKit (no external deps, no Wally); auto-runs on Studio Play via `RunTests.server.luau`
- **Test count progression:** 74 (Pre-Alpha) → 95 (ProfileService + v3) → ~125 (biome refactor) → 166 (Phase 1 verified) → ~253 (Phase 2 milestones)
- **Locked decisions:** 4 ADRs (001 biome architecture · 002 cultivation formula · 003 reputation rates · 004 coin economy)
- **SPECs authored:** 12 (incl. brand-new player-stalls.md 2026-05-03)
- **DOCs maintained:** 10 (DESIGN, ROADMAP, HANDOFF root, CONTRIBUTING, PROJECT-REVIEW, visual-references, README, CLAUDE.md, git-setup, legacy archive)

---

## Accumulated Context

### Recent decisions (last 7 days)

- **2026-05-03** — Player Stalls architecture confirmed (player-stalls.md): hybrid placement (free personal + paid featured row), async sales via mailbox, fixed-price-only v1, 4 listing slots / 48h expiry / 12 featured slots / 200c/day fee, shared `Exchange.luau` core consumed by both Trade.luau (refactor) and Stall.luau (new).
- **2026-05-03** — Trading Post anti-scam UX locked: Adopt Me lock + 5s countdown + dual confirm; modifying offer during countdown reverts both to Open and resets countdown.
- **2026-05-03** — Trade sessions live in-memory only; server-crash mid-trade returns originals to both players (failure-safe). DataStore is for the immutable audit log only.
- **2026-05-03** — Trading Post zone gate deferred — placeholder marker shipped; real zone follow-up alongside Player Stalls.
- **2026-05-03** — Dialogue / Shop mutual exclusivity at anchor Part: anchor has *either* `dialogueId` OR `merchantId`. Dialogue handler defers to Shop if absent; Shop handler defers to Dialogue if present.
- **2026-05-02** — Visual language tokens locked at [docs/specs/visual-language.md](../docs/specs/visual-language.md). Single source of truth for color/typography/motion/spacing/surface; consumed by Shop UI + Quest + Dialogue + Trade UIs.
- **2026-05-01** — Four ADRs accepted simultaneously: biome architecture (single-place), cultivation formula (per-species yieldBySubstrate, multiplicative, substrate-only hard fail), reputation rates (two-layer 5000-cap NPC + total renown for biome unlocks, decelerating curve), coin economy (10B hard cap, NPC prices fixed forever, three-layer anti-exploit, Coins.add chokepoint).

### Open todos (next session pickups)

1. **Implement Player Stalls** per [docs/specs/player-stalls.md](../docs/specs/player-stalls.md) — 10 new remotes, Exchange.luau extraction, Trade.luau refactor, Stall.luau + StallUI.client.luau new, plot anchor grid + featured row stalls in MapSetup, save schema additive (no migration), audit log `kind` field. Authoring `/gsd-plan-phase 2` will decompose this into ordered work units.
2. **Wire remaining 3 launch NPCs** — Spirit Speaker (blocked on Spirits dialogue UX), Expedition Coordinator (blocked on Co-op Expeditions), Trading Post Manager (lands with Stalls). Pattern is mechanical once backing system exists.
3. **Wire remaining 3 secondary merchants** — Spirit Food Vendor, Cosmetic Vendor, Decoration Vendor. Items inert until cultivation depth lands; schema-ready / behavior-deferred per HANDOFF caveat.
4. **Author Co-op Foraging Expeditions** — lobby + reserved-server teleport + reward distribution (P2-EXP-01..05). Largest remaining Phase 2 system.
5. **Add 15+ new species (P2-CONT-01)** — XL content task. Mostly `Species.luau` data + WildSpawn visual variants. Introduces Legendary tier.
6. **Test gaps** — StallSpec + ExchangeSpec (P2-TEST-02), expedition lobby + reward math (P2-TEST-03), trade cancel-condition coverage (P2-TEST-01 partial).

### Blockers

- **None active.** All Phase 2 in-flight work has resolved blockers per HANDOFF.md. Player Stalls implementation has one open question flagged in the spec: ProfileService API for offline-profile mutation needs verification (fallback: pending-mutations queue keyed on userId).

### Cross-spec dependency notes

- **Constants rename: `witchPriceMultiplier` → `MERCHANTS.ForestWitch.buyMultiplier`.** ADR 004 cites the old name; shop-ui.md spec migrated it. Same lever, renamed. Logged in [.planning/INGEST-CONFLICTS.md](INGEST-CONFLICTS.md) INFO bucket #2.
- **Coin hard cap revised: 1T (in ROADMAP Phase 3 task) → 10B (per ADR 004).** ADR 004 supersedes; Phase 3 task P3-SEC-04 reflects 10B.
- **Inventory split is intentional asymmetry through Phase 2.** Sells route to legacy `data.inventory` (mushrooms); buys route to `inventoryByCategory[itemListing.category]` (non-mushroom). Full reconciliation deferred to v3→v4 migration.

---

## Session Continuity

### Last session summary (2026-05-03)

Per HANDOFF.md: Player Stalls spec written and approved (player-stalls.md). User restarting Claude Code to resume implementation. Trading Post backend + UI + audit log shipped earlier the same day. GSD ingest run completing concurrently — this STATE.md is the synthesized initial state from that run.

### Next session intent

1. **Open this STATE.md and [HANDOFF.md](../HANDOFF.md)** to confirm current state hasn't drifted.
2. **Run `/gsd-plan-phase 2`** to decompose remaining Phase 2 work into ordered plans, starting with Player Stalls (P2-STALL-01..06).
3. **Begin Player Stalls implementation** with the Exchange.luau extraction pass (so Trade.luau refactor + Stall.luau new both consume the shared core).
4. **Follow Definition of Done per [docs/CONTRIBUTING.md](../docs/CONTRIBUTING.md)**: tests (happy path + edge), existing tests pass, HANDOFF.md updated, affected docs updated, change verified in Studio.

### Resume protocol (for any future session)

1. Read [HANDOFF.md](../HANDOFF.md) (canonical state).
2. Read this STATE.md (GSD layer; should mirror HANDOFF for "current position" but adds GSD plan/phase tracking).
3. Read the relevant ADR(s) and spec(s) for the system you're touching (per CLAUDE.md "Before making changes" checklist).
4. Verify tests pass before any change (`RunTests.server.luau` on Studio Play).
5. After change: update tests, update HANDOFF.md session log, update STATE.md "Current Position" + "Last session summary", update affected docs per CONTRIBUTING.md table.

---

## References

- Canonical state: [HANDOFF.md](../HANDOFF.md)
- AI assistant primer: [CLAUDE.md](../CLAUDE.md)
- GSD project memory: [.planning/PROJECT.md](PROJECT.md)
- GSD requirement register: [.planning/REQUIREMENTS.md](REQUIREMENTS.md)
- GSD roadmap: [.planning/ROADMAP.md](ROADMAP.md)
- Ingest synthesis: [.planning/intel/SYNTHESIS.md](intel/SYNTHESIS.md)
- Conflict report: [.planning/INGEST-CONFLICTS.md](INGEST-CONFLICTS.md)
