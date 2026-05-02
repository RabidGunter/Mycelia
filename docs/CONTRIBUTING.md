# Contributing to Mycelia

How to make changes without letting documentation drift from reality. The single most important rule on this project.

---

## The docs-stay-current rule

**Every non-trivial change updates `docs/` *in the same session*.** If you make the change but skip the docs, the change is incomplete.

| What changed | What to update |
|---|---|
| Code state (new system, milestone progress, file structure) | [HANDOFF.md](../HANDOFF.md) "State as of last session" + [README.md](../README.md) repo layout if structure moved |
| Scope (new feature scoped in, work descoped, phase boundary moved) | [ROADMAP.md](ROADMAP.md) |
| Architecture / locked-in design decision | New numbered ADR in [decisions/](decisions/) |
| Open question resolved | Mark resolved in [ROADMAP.md](ROADMAP.md) "Open questions" with link to the new ADR |
| Concrete data / API shape / schema that wasn't already pinned | New spec in [specs/](specs/) |
| Setup gotcha encountered | [HANDOFF.md](../HANDOFF.md) "Setup gotchas worth knowing about" |
| Test count or test coverage shifted significantly | [HANDOFF.md](../HANDOFF.md) state + [README.md](../README.md) milestone checklist |

**Test for whether a change qualifies:** would a developer reading the docs in 6 months be misled by the current state? If yes → update. When unsure, update — small over-documentation is cheap; under-documentation is expensive on resume.

---

## Architecture Decision Records (ADRs)

`decisions/` holds one numbered Markdown file per locked-in architectural decision.

**Naming:** `NNN-short-kebab-name.md` (e.g., `001-biome-architecture.md`). Numbers monotonically increase; never re-number old decisions even if they get superseded (write a new ADR that supersedes the old one instead).

**Write an ADR when:**
- A choice between two viable approaches is being locked in.
- The decision affects how multiple systems will be built.
- "Why did we...?" six months from now would be hard to answer without it.

**Don't write an ADR for:**
- Tunable values (those live in `Constants.lua`).
- Bug fixes (commit messages cover those).
- Small refactors confined to one module.

**ADR template (loose):**
1. **Status + decision** — at the top, one line each. So someone scanning gets the answer first.
2. **The question** — one paragraph stating what's being decided and why it matters.
3. **The options** — each with concrete pros/cons.
4. **Real-world evidence** if relevant (similar projects, prior art, what comparable Roblox games chose).
5. **Project-specific considerations** — what about Mycelia tilts the decision.
6. **Recommendation + reasoning.**
7. **Implementation notes** — concrete steps for whoever executes against this decision.
8. **When the alternative IS appropriate** — don't be dogmatic; capture exceptions.
9. **Override criteria** — what would make us revisit.

[decisions/001-biome-architecture.md](decisions/001-biome-architecture.md) is the working example.

---

## Specs (`specs/`)

`specs/` holds concrete implementation details that don't fit a decision/rationale shape — data tables, API contracts, schemas, protocol descriptions. These are the artifacts a contractor copies straight into code.

**Difference from ADRs:** an ADR explains *why* we chose an approach; a spec describes *what* to build under that approach. They complement each other.

**Naming:** `specs/<topic>.md`. No numbering — specs evolve in place as systems mature; older versions live in git history. ADRs are immutable; specs are mutable.

**When to write a spec:**
- The implementation needs concrete numbers across many entries (e.g., per-species data tables).
- API contracts that span multiple modules.
- Schemas (save data, message formats, etc.).
- Recipe / loot / progression tables.

**When NOT to write a spec:**
- Single-module internals — code comments are enough.
- Things that change every session — keep in code, not docs.

Current specs (Phase 1 prep):
- [specs/species-data.md](specs/species-data.md) — full 15-species data tables + 6 substrates.
- [specs/save-schema-v3.md](specs/save-schema-v3.md) — complete v3 save shape + migration.
- [specs/remote-api.md](specs/remote-api.md) — every RemoteEvent / RemoteFunction with signatures and validation rules.
- [specs/potions-and-recipes.md](specs/potions-and-recipes.md) — 20-recipe target + 10 potion effect kinds.
- [specs/spirits.md](specs/spirits.md) — 7 spirit types + attraction maps + roster mechanics.
- [specs/biome-config.md](specs/biome-config.md) — biome config schema + Misty Hollow.

---

## Definition of done per change

A task is done when ALL of these are true:
- New code has tests covering happy path + at least one edge case.
- Existing tests still pass.
- `HANDOFF.md` reflects the new state (state, recipe table, schema version, etc.).
- Any other affected docs are updated per the table above.
- Change is verified in Studio at least once (Play Solo is fine).

---

## Code style + design rules

Captured in [HANDOFF.md](../HANDOFF.md) under "Design rules locked in." Don't repeat here — read those before writing code. Highlights:
- Server-authoritative everything.
- Tunables in `Constants.lua`.
- Species `id` never changes once shipped.
- Match existing module conventions; don't introduce new patterns without discussion.

---

## Working across machines

This project gets worked on across multiple machines (work laptop + personal). When you change docs on one machine, **the changes don't auto-sync** — copy the updated `docs/` folder + modified `HANDOFF.md` / `README.md` over via USB or whatever transfer method you're using.

When you sync, **the up-to-date code lives on the personal machine**; the work-laptop copy is for planning/documentation work that doesn't require Studio. If they diverge in code state, the personal machine wins.

---

## Git

For the one-time git-init + GitHub remote setup, see [git-setup.md](git-setup.md). Once the project is under git, ongoing rules:

- Feature branches per substantial change. Trivial fixes can go straight to `main`.
- Commit messages describe WHY, not WHAT. "Fix planting bug" is bad; "Validate plot ownership before charging coins in attemptPlantSpecies" is good.
- **Don't push from a work machine.** The work laptop pulls; the personal machine pushes. For substantial changes made on the work laptop, generate `.patch` files and `git am` them on the personal machine — see git-setup.md "Work-laptop workflow."
- Don't commit `.rbxl` files, secrets, or editor configs. The `.gitignore` covers most of this.

---

*If this file conflicts with existing patterns in the codebase, the codebase wins — update this file rather than diverging.*
