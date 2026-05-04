# Requirements (synthesized from PRDs)

**No PRDs in ingest set.**

The 26 ingested docs break down as 4 ADRs + 12 SPECs + 10 DOCs. Mycelia uses an ADR-then-spec workflow (see docs/CONTRIBUTING.md): architectural decisions live in `docs/decisions/`, implementation contracts live in `docs/specs/`, and product-style requirements with explicit acceptance criteria are not currently authored as standalone PRDs.

**For requirement-shaped intent**, downstream consumers should look at:
- **Tasks with acceptance/done state** → `docs/ROADMAP.md` (phased task list with size markers and completion ticks). Synthesized in `intel/context.md` under "## Roadmap (canonical phase plan)".
- **Per-feature acceptance criteria** → embedded in each SPEC's "tests" / "validation matrix" / "verification pending in Studio" section. Synthesized in `intel/constraints.md`.
- **Definition of Done** → `docs/CONTRIBUTING.md`. Synthesized in `intel/context.md`.

If product-style requirements need to be authored downstream (e.g., for upcoming Phase 2 features like Player Stalls or Co-op Foraging Expeditions), the convention to follow is to write the SPEC first (per CONTRIBUTING.md) and let acceptance criteria live in the SPEC's tests + validation sections.
