# CLAUDE.md

Project context for AI assistants (Claude Code etc.) working on the Mycelia Roblox game. This file is auto-loaded into every session — keep it concise.

---

## Read first, in this order

1. **[HANDOFF.md](HANDOFF.md)** — current state of the project, setup steps, what's most recently shipped, what's next.
2. **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)** — how to make changes without breaking docs hygiene. Read before any edit.
3. **[docs/ROADMAP.md](docs/ROADMAP.md)** — multi-phase build plan; check the phase you're working on.

---

## What this project is

Mycelia: a cozy mushroom-cultivation Roblox game. Bee Swarm Simulator longevity model wrapped in Stardew-Valley-style aesthetic. The design vision is captured in [docs/DESIGN.md](docs/DESIGN.md) — that's the north star when gameplay direction is unclear.

Solo project, built across multiple machines. Code lives canonically on the personal machine; work-laptop sessions are usually planning-only.

---

## Where things are

- **`src/`** — Roblox source (Luau). Synced to Studio via Rojo from `default.project.json`.
- **`docs/DESIGN.md`** — full design vision (the north star).
- **`docs/ROADMAP.md`** — multi-phase build plan with task list.
- **`docs/CONTRIBUTING.md`** — process rules.
- **`docs/decisions/`** — Architecture Decision Records (ADRs). Numbered, immutable, capture the *why* behind locked-in choices. **Read the relevant ADR before changing the system it covers.**
- **`docs/specs/`** — implementation specs (data tables, API contracts, schemas). Mutable; copy-pasteable into code.

---

## Codebase rules (don't break)

- **Server-authoritative everything.** Clients send intents via Remotes; server validates before any state mutation. Never trust client input.
- **Tunables in `src/ReplicatedStorage/Shared/Constants.lua`.** Anything balance-affecting (costs, durations, multipliers, drop rates) belongs there, not in logic files.
- **Species `id` never changes once shipped.** It's the save-data key. Add new species, don't rename old ones.
- **No pay-to-win.** Robux unlocks time and cosmetics, never rare items, recipes, or trading advantages.
- **Match existing module conventions.** Don't introduce new patterns (OOP frameworks, dependency injection, alternative module structures) without writing an ADR first.
- **Pure-function modules get tests.** Server-side remote handlers get tests. See CONTRIBUTING.md's Definition of Done.

---

## Before making changes

1. Identify the relevant ADR(s) in `docs/decisions/` — read if you'll touch a system they cover.
2. Check `docs/specs/` for any spec covering the data / API / schema you'll modify.
3. Review the change against [CONTRIBUTING.md](docs/CONTRIBUTING.md)'s docs-stay-current rule:
   - Code change → update HANDOFF.md state + ensure tests pass.
   - Architecture decision → write a new ADR.
   - Concrete data / API / schema → write or update a spec.
   - Open question resolved → mark resolved in ROADMAP.md with link to the new ADR.
   - Setup gotcha encountered → log in HANDOFF.md "Setup gotchas".

---

## Definition of done per change

A task is "done" only when ALL of these are true (full version in [CONTRIBUTING.md](docs/CONTRIBUTING.md)):

- New code has tests covering happy path + at least one edge case.
- Existing tests still pass.
- `HANDOFF.md` reflects the new state.
- Affected docs in `docs/` are updated per CONTRIBUTING.md's table.
- Change is verified in Studio at least once.

---

## Working environment

- **Studio + Rojo workflow.** `rojo serve default.project.json` from VS Code, then connect via the Rojo Studio plugin. Live sync — edit `.lua` files in VS Code, they appear in Studio.
- **Multi-machine project.** Personal machine pushes; work laptop pulls. See [docs/git-setup.md](docs/git-setup.md) for the one-time setup and the asymmetric workflow.
- **DataStore.** Unpublished Studio places can't access DataStore — `PlayerData.lua` pcalls and degrades gracefully. To enable saves between sessions: save place to Roblox + enable "Studio Access to API Services" in Game Settings → Security.

---

## Things to never do

- Push code from a work machine, even to a private repo.
- Sell power, rarity, or trading advantages for Robux.
- Skip server-side validation on a remote because "the client UI guarantees it."
- Rename a shipped species `id`.
- Edit `.rbxl` files outside Studio.
- Introduce new module conventions without an ADR.
- Reach into Roblox Service objects in pure-function tests — keep test modules dependency-free.
- Hardcode magic numbers in logic files when a Constants entry would do.

---

## Session handoff

After every non-trivial change, **update HANDOFF.md's session log** with what was done, what's verified, and any gotchas discovered. This is the durable record that future sessions read to resume work cleanly.

For longer planning-only sessions, also note "no code changes" so the resumer knows the codebase state didn't move.

---

## Phase status (current)

**Phase 1 complete (2026-05-02)** — 166 tests passing, all six task groups verified in Studio. ProfileService migration, save schema v3, 20 brewing recipes, 10 potion effect kinds, Forest Spirits + PassiveBonuses, Biome architecture + Misty Hollow + Travel.

**Phase 2 in progress.** First milestone — Shop UI replacing the witch auto-sell — shipped 2026-05-02. Visual language locked in [docs/specs/visual-language.md](docs/specs/visual-language.md). See `docs/ROADMAP.md` "Phase 2" for remaining tasks; the natural next pickups are the Quest system, NPC dialogue, or secondary merchants.

When new questions surface during Phase 2 implementation, write them up as a new ADR (don't make decisions silently in code).

---

*This file is short on purpose. For depth on any topic, follow the links to HANDOFF.md, CONTRIBUTING.md, ROADMAP.md, or the ADRs/specs in `docs/`.*
