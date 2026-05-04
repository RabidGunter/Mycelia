## Conflict Detection Report

### BLOCKERS (0)

(none)

### WARNINGS (0)

(none)

### INFO (5)

[INFO] Auto-resolved: SPEC > DOC on launch biome count
  Found: docs/DESIGN.md §The Long Loop describes "12 different biomes with seasonal rotations"
  Note: docs/specs/biome-config.md and docs/ROADMAP.md commit to 7 launch biomes (StarterGlade, MistyHollow, FrostrootPass, SunkenGrove, OldGrowth, Glimmerwood, LostCathedral); ADR 003 reputation thresholds enumerate the same 7. Per precedence (SPEC > DOC) the synthesized intel uses 7 launch biomes; the DESIGN.md "12" reads as aspirational long-tail content, not a launch commitment. No SPEC blocks this — biome-config.md schema is generic enough to accept additional biomes post-launch via the same data shape.

[INFO] Auto-resolved: SPEC field rename of ADR-cited constant
  Found: docs/decisions/004-coin-economy.md cites "Constants.ECONOMY.witchPriceMultiplier" as the witch tuning lever
  Note: docs/specs/shop-ui.md migrated this constant to Constants.MERCHANTS.ForestWitch.buyMultiplier (Pre-Alpha → Phase 2 migration table). Same lever, renamed for the per-merchant config shape. ADR 004's principle (NPC prices fixed, single tuning multiplier per merchant) is preserved. HANDOFF.md 2026-05-02 entry already documents this rename and explicitly notes it for ADR 004 readers. Synthesized decisions.md DECISION-004 carries a note pointing readers to the new field name.

[INFO] Two HANDOFF.md files; legacy is archive-only
  Found: HANDOFF.md (root) and mycelia/HANDOFF.md both exist
  Note: Per ingest prompt instructions and the current HANDOFF.md root file ("the legacy mycelia/HANDOFF.md is archive-only and should be treated as historical context, not current state"), the root HANDOFF.md is canonical for current state. The legacy mycelia/HANDOFF.md is preserved for Pre-Alpha build history. Synthesized context.md treats them per this disposition — current state pulled from root, history attributed to legacy.

[INFO] Test count snapshots vary across docs (expected; different timestamps)
  Found: docs/PROJECT-REVIEW.md says "166 unit tests, 100% passing"; HANDOFF.md root session log progresses through 74 → 95 → ~125 → 166 → ~253
  Note: Same source-of-truth (in-house TestKit auto-run on Play). 166 is the Phase-1-complete snapshot (2026-05-02); ~253 is the current Phase-2-in-progress snapshot (after Trading Post + Quests + Dialogue + Stalls work). Both are correct for their snapshot. Downstream consumers should use HANDOFF.md as canonical for "current" test count.

[INFO] DESIGN.md says "60 species at launch"; current is 15 with phased plan
  Found: docs/DESIGN.md §The Mushroom Collection: "Launch with 60 species across 6 rarity tiers"
  Note: ROADMAP.md and docs/specs/species-data.md commit to 15 Pre-Alpha species (across 4 tiers — Common/Uncommon/Rare/Epic), 30+ in Phase 2 (add Legendary), 60+ in Phase 4 Global Launch (add Mythic). DESIGN.md "launch" maps to ROADMAP.md "Phase 4 Global Launch" — not actually contradictory once the phase mapping is understood, just terminology drift. Synthesized context.md notes both in the §Mushroom Collection summary.
