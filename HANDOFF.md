# Mycelia — Handoff

Current state of the project. The orientation doc CLAUDE.md points here first; read this for what's working, what's most recently shipped, and what to pick up next. For the *why* behind locked-in decisions, see `docs/decisions/`. For the *what* of pending implementation work, see `docs/specs/` and `docs/ROADMAP.md`.

---

## State as of last session (2026-05-01)

**Project structure**: new top-level `src/` (Luau, `.luau` extension) is now the canonical Rojo source. Wired into Roblox via `default.project.json`:

- `src/shared/` → `ReplicatedStorage.Shared` (Folder of ModuleScripts).
- `src/server/init.server.luau` → `ServerScriptService.Server` (Script entry point).
- `src/server/X.luau` → child ModuleScripts of `Server`.
- `src/server/Tests/` → child Folder of `Server` containing the test runner + specs.
- `src/client/X.client.luau` → LocalScripts under `StarterPlayerScripts.Client` (Folder).

**Pre-Alpha gameplay code** has been ported from `mycelia/src/` (the legacy folder, still present as reference) into the new `src/` layout. Path rewrites applied: every `require(ServerScriptService.X)` is now `require(ServerScriptService.Server.X)`. Shared and client paths are unchanged.

**Working end-to-end** (per Pre-Alpha pre-port — needs Studio re-verification post-port):
- Core gameplay loop: harvest → plant → sell → brew → consume potions.
- 15 mushroom species across 4 tiers; 6 brewing recipes; 3 active potion effects (speed, growth, wildYield).
- Painted terrain (mossy mountain with cave interior containing the witch+cauldron, pond west of spawn with animated koi, paths, hills).
- Brewing Journal UI showing discovered + undiscovered potions.
- 166 unit tests via TestKit (Inventory + Selling + Species + PotionEffects + Recipes + SaveSchema + Spirits + BiomeConfig specs), all passing as of 2026-05-02 verification in Studio.
- DataStore persistence with autosave + graceful degradation (place is published).
- Hand-built escape valves for every procedurally-built world piece.

**Known follow-ups from the port (verify in Studio next session)**:
- `RunTests.server.luau` lives at `ServerScriptService.Server.Tests.RunTests` — nested under the Server Script. Roblox should still auto-run nested Scripts in ServerScriptService, but verify by pressing Play and checking Output for `Tests complete: 74 passed, 0 failed`. If tests don't auto-run, convert RunTests to a ModuleScript and call it from `init.server.luau`.
- The legacy `mycelia/` subfolder still exists with the old code. Once the new `src/` is verified working in Studio, the legacy folder can be deleted (or kept as reference — your call). Nothing in the new project.json points at it.
- `mycelia/HANDOFF.md` is the legacy handoff and is now obsolete; this file (at the project root) supersedes it.

---

## How to resume work

1. Open VS Code at `C:\Users\fonte\Documents\Mycelia\` (the new project root, NOT the `mycelia/` subfolder).
2. Run `rojo serve default.project.json` from the project root (or use the Rojo VS Code extension's UI). Terminal should show `Rojo serving on port 34872`.
3. Open the Mycelia place in Studio (`File → Open from Roblox` → Mycelia).
4. **Plugins → Rojo → Connect** (default localhost:34872). Approve the HTTP prompt if shown.
5. Press Play. Output should show `Tests complete: 74 passed, 0 failed (74 total)` and the world should build with HUD + paths + cave + pond + koi.

If Studio's Toolbox panel doesn't open, see `docs/git-setup.md` and the workarounds below ("Setup gotchas"). Toolbox isn't needed for the next phase of work — only required if you want to drag in marketplace assets.

---

## Phase 1 — pick a starter task

All five Phase 1 architectural questions are resolved (see `docs/ROADMAP.md` "Open questions" — links to ADRs 001–004). Phase 1 implementation is largely mechanical execution against the specs in `docs/specs/`.

Recommended order (foundations first):

1. ~~**(L) Migrate save persistence to ProfileService.**~~ **DONE 2026-05-01** — see session log below.
2. ~~**(M) Bump save schema to v3.**~~ **DONE 2026-05-01** — see session log below.
3. ~~**(S) Add 14+ new recipes** to `Recipes.luau` to reach 20+ total.~~ **DONE 2026-05-01** — 20 recipes (6 Pre-Alpha + 14 new), 18 unique potions in catalog. See session log below.
4. ~~**(L) Implement the remaining 7 potion effects** in `PotionEffects.luau`.~~ **DONE 2026-05-01** — 10 effect kinds total (3 Pre-Alpha + 7 new). Handler-table dispatch with per-kind stacking rules. 18 active potions in `Constants.POTIONS`. cosmeticGlow + harvestYield wired into actual gameplay; luck/reveal/spiritAttract exposed via helpers but await consumer systems; weatherSummon + timeShift are spec-mandated stubs (Phase 4).
5. ~~**Forest Spirits** — attraction + claim + roster + wander AI.~~ **DONE 2026-05-01** — see session log. New PassiveBonuses module + Spirits module. Models still need to be supplied at `ReplicatedStorage.SpiritModels.<spiritId>` for visual rendering; system is functionally complete without them.
6. ~~**Biome architecture** — refactor `MapSetup` and `WildSpawn` to be biome-parameterized.~~ **DONE 2026-05-01** — see session log. WildSpawn refactored to per-biome instances. New BiomeBuilder + Travel modules. Misty Hollow data + procedural WildSpawnArea live. Client atmosphere transition + Travel NPC UI deferred to a polish/UX pass.

Full Phase 1 task list with size markers: `docs/ROADMAP.md`.

---

## Setup gotchas worth knowing about

- **Studio's Toolbox panel doesn't always appear** even when toggled in View. Workarounds: try `File → Studio Settings → search "Toolbox"`, or fully uninstall + reinstall Studio. For now, marketplace assets can be brought in via `InsertService:LoadAsset(assetId)` in code if the Toolbox UI is unavailable.
- **Rojo doesn't sync during a Play session.** After editing a `.luau`, stop Play, wait ~2s for Rojo to push, then Play again.
- **Rojo + Studio plugin must be the same protocol version.** Project pins `rojo-rbx/rojo@7.7.0-rc.1` via `aftman.toml`. Run `rojo plugin install` from the project folder once to install the matching Studio plugin.
- **Terrain repaints are sticky once `Workspace.HasHandBuiltGround=true`.** To force `TerrainBuilder.build()` to re-run after editing it, paste in the Studio command bar:
  ```
  workspace.Terrain:Clear()
  workspace:SetAttribute("HasHandBuiltGround", nil)
  ```
- **Same pattern for Witch + Cauldron Parts**: MapSetup detects existing instances by name and skips re-placement. To force re-place after moving them, delete the existing ones in Studio first.
- **DataStore is unavailable in unpublished places** — `PlayerData.lua` pcalls and degrades gracefully. To enable saves: `File → Save to Roblox` + Game Settings → Security → Enable Studio Access to API Services.
- **Place is currently published** as "Mycelia" under RabidGunter's account. DataStore reads/writes work in Studio editor.
- **Don't push code from the work machine.** The work laptop pulls / does planning; the personal machine pushes. See `docs/git-setup.md` for the asymmetric multi-machine workflow.

---

## Recent session log

### 2026-05-01 — Phase 1 Biome architecture refactor + Misty Hollow data
- New `Constants.BIOMES` table with full configs for `StarterGlade` (matches existing layout) and `MistyHollow` (Phase 1 second biome). Single-place world with biomes at 2000-stud spacing per ADR 001. Schema covers spatial layout, wild-spawn config, lighting/atmosphere, weather distribution, available substrates, travel cost.
- Refactored `WildSpawn.luau` to be biome-parameterized. New entry: `WildSpawn.startBiome(biomeConfig, area, harvesting)` runs an independent spawn loop per biome with the biome's own `wildSpawnTable`, `wildSpawnCap`, `wildSpawnInterval`. Each spawned mushroom gets a `biomeId` attribute so harvest events scope back to the right spawner. Old `WildSpawn.start(area, harvesting)` shim preserved for backwards-compat (routes to startBiome with StarterGlade config).
- New module `BiomeBuilder.luau`. Walks `Constants.BIOMES`, ensures every biome has a `Workspace.Biomes.<biomeId>` Folder, builds a procedural `WildSpawnArea` BasePart per biome at the configured zone center + size 400×100×400. Hand-built escape valve per spec: if the Folder exists with attribute `BuiltManually = true`, BiomeBuilder leaves it alone (just verifies the area exists). For StarterGlade specifically, BiomeBuilder reuses MapSetup's legacy `Workspace.WildSpawnArea` to avoid double-spawning.
- New module `Travel.luau`. Handles `RequestBiomeTravel` remote: validates renown threshold (sum of `data.reputation[*].score`) + travel cost, deducts coins, moves player's HumanoidRootPart to `biome.spawnPoint`, sets `player:SetAttribute("currentBiome", biomeId)`, sets `data.stats.biomesUnlocked[biomeId] = true` defensively. Also stamps initial `currentBiome = "StarterGlade"` on player join. Pure helpers `Travel.totalRenown(data)` and `Travel.canTravel(data, biomeId)` are testable.
- 3 new remotes: `RequestBiomeTravel`, `BiomeTravelCompleted`, `BiomeUnlocked`.
- `init.server.luau` updates: requires `BiomeBuilder` + `Travel`. Replaces the single `WildSpawn.start(map.wildSpawnArea, Harvesting)` call with a loop over `BiomeBuilder.buildAll()` results (one `WildSpawn.startBiome` call per biome). `Travel.start()` runs alongside other gameplay systems.
- New tests: `Tests/BiomeConfigSpec.luau` covers schema integrity (every biome has all required fields), id-key match, unique unlockOrder, every wildSpawnTable entry references known species, weatherDistribution sums to 1.0 per biome, sanity bounds on zoneRadius and travelCostCoins. Also covers `Travel.totalRenown` (nil/empty/multi-NPC sum, defensive defaults) and `Travel.canTravel` (unknown biome, StarterGlade always-ok, MistyHollow renown gate, MistyHollow cost gate, success path).

**What's not in this pass (deferred):**
- **Client-side atmosphere transition.** Spec calls for a LocalScript that polls position, detects current biome, tweens Lighting + Atmosphere settings + crossfades ambient music on transition. Awaits user-supplied audio assets and an Atmosphere instance in Lighting; can ship as a polish pass.
- **Travel NPC dialogue UI.** The remote handler works (any client can fire `RequestBiomeTravel`), but there's no in-world Travel Coordinator NPC yet. Hand-built or to be built when NPCs are tackled.
- **Reputation-driven biome unlock notifications.** Spec calls for `Reputation.add` to re-check thresholds and fire `BiomeUnlocked` toasts. Reputation system isn't implemented yet — defensive `biomesUnlocked` flagging at travel time covers the gameplay path.
- **MapSetup full per-biome refactor.** MapSetup still hardcodes Starter Glade's spawn pad / witch / cauldron / plots. Future refactor moves the StarterGlade-specific build into BiomeBuilder so MistyHollow can have parallel SpawnPads, plot regions, etc. For now: MistyHollow's WildSpawnArea exists but it's just an invisible volume — there's no pad or plots there yet.

**Verification pending in Studio:**
- Press Play → `Tests complete: ~125 passed, 0 failed` (105 prior + ~14 in BiomeConfigSpec).
- Output should print BiomeBuilder progress + show `Workspace.Biomes.MistyHollow.WildSpawnArea_MistyHollow` in the Explorer.
- Walk over to `Vector3.new(2000, 5, 0)` (MistyHollow spawn) — should see wild mushrooms spawning there with the MistyHollow palette (BrownCap/FairyCup/Mossring + Hollowstem/Dewfern/occasional Glowmoss).
- From the command bar, fire travel manually:
  ```
  game:GetService("ReplicatedStorage").Remotes.RequestBiomeTravel:FireServer("MistyHollow")
  ```
  (Expect failure with `renownGate` until the player has 100 renown — manually set via the command bar to test: edit `PlayerData.get(game.Players.LocalPlayer).reputation.test = { score = 100 }`.)

### 2026-05-01 — Phase 1 Forest Spirits + PassiveBonuses
- New module `PassiveBonuses.luau` — symmetric to PotionEffects but for *permanent* (untimed) bonuses. Per-player registry of `{ kind → magnitude }` totals. Pure helper `sumFromSpirits(data, config)` is testable; recompute pass walks the active-roster spirits and sums per-kind magnitudes from `Constants.SPIRITS.bonuses`. Future sources (gamepasses, achievements) slot into the same pass.
- New module `Spirits.luau` — full attraction + claim + equip/unequip + wander AI per the spec. Pure helpers `rosterCapForData`, `holdingsFromData`, `attractionChancePerTick` are testable. Roblox-bound: attraction loop (per-player roll every 5 min summing baseChancePerHour for held + grown species, multiplied by spiritAttract potion); spawn from `ReplicatedStorage.SpiritModels.<spiritId>:Clone()` near the player's home point with claim ProximityPrompt + 5min despawn timer; atomic claim-and-revert handler that survives concurrent claims; equip/unequip remotes that move spirits between activeRoster and inactive in `data.spirits` and recompute PassiveBonuses; Heartbeat-driven idle/walking wander state machine.
- 6 launch spirits in `Constants.SPIRITS`: Common (Mossling, Spritefly, Dewdrop) + Rare (Lanternfox, Crystalmoth, Deerlet). Forest Mother (Legendary) is data-only — Phase 4 lunar event spawn. Full attraction maps populated for the 15 species.
- New `Constants.ITEMS` table (non-mushroom inventory items). First entry: `CrystalShard` — Crystalmoth's planned daily drop. Stackable, tradable, lives in `inventoryByCategory.tools`.
- Combined-bonus reads wired into gameplay code:
  - `Harvesting.harvestWild`: yield = `floor(1 * (1 + spirit_wildYield)) + potion_wildYieldBonus`
  - `Harvesting.harvestPlot`: same pattern with `harvestYield` kind
  - `Planting.attemptPlantSpecies`: ripeAt sampled with `potion_growthMultiplier × (1 - spirit_growthSpeed)` combined factor
  - All three formulas fall through to no-op (multiplier 1.0, bonus 0) when no spirits/potions are active — backwards compatible.
- New remotes registered: `ClaimSpirit`, `SpiritClaimCompleted`, `EquipSpirit`, `UnequipSpirit`, `PassiveBonusesUpdated`.
- `init.server.luau` now starts `PassiveBonuses.start()` then `Spirits.start()` after PotionEffects.
- Tests: new `Tests/SpiritsSpec.luau` covers: rosterCap with/without gamepass + nil-data fallback, holdings extraction (inventory + plots, deduplication, Empty-state exclusion), attraction-chance math (per-hour-to-per-tick, multi-species stacking, irrelevant-holdings ignore, potion multiplier scaling), PassiveBonuses summing (single + multi spirit, kind separation, defensive against missing-allOwned and unknown-spiritType entries), Constants.SPIRITS catalog integrity (every bonus → known kind, every spirit has a rarity tier).

**Spirit Models still need to be supplied at `ReplicatedStorage.SpiritModels.<spiritId>` (one Model per spirit type, named exactly the id).** Without them, attraction rolls succeed but `Spirits.spawn` warns and skips — system is functionally complete but visually invisible. Drop in any rigged Model named `Mossling` / `Spritefly` / `Dewdrop` / `Lanternfox` / `Crystalmoth` / `Deerlet` and they appear.

**Known stubs (deferred to later content/system phases):**
- Crystalmoth's daily Crystal Shard drop — spec mentions a midnight scheduler. Code structure ready; the actual `task.delay` to next-midnight isn't wired (Phase 1 was about the foundation, not LiveOps timing). Easy follow-up.
- Lanternfox dark-plot illumination — depends on biome lighting state.
- Deerlet daily favor (instant-ripen) — depends on per-day cooldown UI.
- Forest Mother — Phase 4 lunar event.

**Verification pending in Studio:**
- Press Play → tests should now show ~22 new (`SpiritsSpec` count: rosterCap 3, holdings 6, attractionChance 6, sumFromSpirits 6, catalog integrity 3 = 24) + previous 81 = ~105 total. Adjust upward when verified.
- Dry-run attraction: no SpiritModels exist → spawn warns + skips. Loop runs without error.
- With a SpiritModels.Mossling Model present + Mossring in inventory: wait one tick (5 min — set Constants.SPIRITS.attractionTickSeconds shorter for testing), spirit appears near player, claim with E, world Model swaps to active-roster instance, PassiveBonusesUpdated remote fires with `{ wildYield = 0.05 }`.

### 2026-05-01 — Phase 1 brewing: 7 new potion effect kinds wired up
- Extended `PotionEffects.luau` with 7 new effect kinds: `harvestYield`, `luck`, `reveal`, `spiritAttract`, `cosmeticGlow`, `weatherSummon`, `timeShift`. Total: 10 effect kinds.
- Refactored to a handler-table (`EFFECT_HANDLERS`) dispatch. Each kind specifies a `stack(old, new)` rule (max-of for most, min-of for growth, replace for cosmetic/weather), plus `onApply` and `onExpire` side-effect hooks. Replaces the previous if/elseif switch in `consumeInternal`.
- Pure helpers extended: `apply` accepts an optional `params` table (for kinds whose effect data doesn't fit in scalar magnitude — cosmetic color, weather kind). New `paramsOf` helper. `snapshot` now includes params for client rendering.
- New public query helpers on the Roblox-bound layer: `harvestYieldBonus`, `luckBonus`, `revealRadius`, `spiritAttractMultiplier`, `weatherSummonKind`, `isTimeShiftActive`. Existing `growthMultiplier` and `wildYieldBonus` unchanged.
- `cosmeticGlow` actually applies — creates a placeholder ParticleEmitter on the player's HumanoidRootPart, parents survives character respawn (re-applied in CharacterAdded hook). Texture is a default for now; will be swapped when the user supplies the cosmetic particle texture asset.
- `weatherSummon` and `timeShift` are stubs per spec — Weather and Lighting.localOverride systems aren't built yet (Phase 4). Both log a warning and update the active-effect chip on the HUD; no actual world change.
- Wired `harvestYield` bonus into `Harvesting.harvestPlot` — yield is now `1 + harvestYieldBonus`. `luck` and `reveal` are exposed via helpers but no consumer reads them yet (rare-variant logic + hidden mushrooms feature land later in Phase 1+).
- Updated `Constants.POTIONS` with 12 new active entries + 3 reactivated (Inkblot/Spotted/Glowmoss). 18 active potions total. All previously-inert Pre-Alpha potions now have effects.
- Added 14 new tests to `PotionEffectsSpec` covering: params storage in apply, paramsOf helper, snapshot params inclusion, and default values + active values for all 4 new query helpers (luck, harvestYield, reveal, spiritAttract).

**Verification done 2026-05-02:**
- ✓ Studio Play output: `Tests complete: 166 passed, 0 failed (166 total)`. All 6 Phase 1 task groups ship clean (ProfileService migration, save schema v3, 14 new recipes, 7 new potion effect kinds, Forest Spirits + PassiveBonuses, Biome architecture refactor + Misty Hollow + Travel).
- One-time gotcha encountered: existing player save data in DataStore was in raw v2 format (pre-ProfileService). ProfileService:LoadProfileAsync errored with `attempt to index nil with 'ActiveSession'`. Resolved by wiping the test player's record via command bar (`DataStoreService:GetDataStore("MyceliaPlayerData_v1"):RemoveAsync("u_" .. UserId)`). Future migrations between save backends should pre-migrate raw data into the new format rather than relying on the new backend to handle it.
- Second gotcha: orphan instances from the legacy project layout (`ServerScriptService.Tests`, etc.) still embedded in the saved place file caused old test specs to run alongside new ones. Resolved by deleting the orphan duplicates from Studio's Explorer. Future restructures should include a "delete orphans" cleanup pass in the same session.
- Brew + consume Inkblot Elixir → blue chip appears for 45s with kind "reveal" + magnitude 30. (No visible effect since hidden mushrooms aren't a thing yet, but the chip + countdown should work.)
- Brew + consume Crystal Essence → cosmeticGlow particle trail appears behind player character for 600s (5min). Effect persists across character respawn.
- Brew + consume Everdew Powder → Output should print `[PotionEffects] weatherSummon stub for ... Rainy ...`.

**Known follow-ups:**
- `luck` is exposed but no consumer reads it. When the cultivation-yield formula ships (per ADR 002), it should add `PotionEffects.luckBonus(player)` into the rare-variant chance calculation.
- `reveal` similarly waits for the hidden-mushroom feature in late-Phase content.
- `spiritAttract` waits for the Spirits system.
- `weatherSummon` + `timeShift` wait for Weather + Lighting.localOverride (Phase 4).
- Cosmetic glow texture is a placeholder; user-supplied particle texture asset will replace it in a future polish pass.

### 2026-05-01 — Phase 1 brewing: 14 new recipes + 12 new potions
- Added 14 new recipes to `Recipes.luau`, hitting the Phase 1 target of 20 total. Distribution per spec: 5 Easy (commons-only), 8 Mid (uncommons or specific common combos), 5 Hard (rares + epics + multi-rare).
- Two recipes are intentional alt-paths to existing potions (DewdropTonic from 2× FairyCup, InkblotElixir from Buttoncap + Inkpot) — light combinatorial encouragement so players who don't have one ingredient set might find another.
- Added 12 new potion catalog entries to `Potions.luau` (no new potions for the alt-paths). Each has displayName + description + rarity. Naming follows the loose convention from the spec (`*Powder` from dry-grind, `*Tonic`/`*Brew`/`*Infusion` from steep/boil, `*Elixir`/`*Cordial` from ferment, `*Essence` for refined/crystalline).
- Updated Potions.luau docstring: effects ARE now defined for some potions (the 3 from Pre-Alpha + 3 from Phase 1 task 4 once that lands). Inert potions still show "No effect yet" in the UI.
- Updated `RecipesSpec` byKey count from 6 → 20. Added 5 new tests: alt-paths, 3-Mossring StonecastInfusion, 3-ingredient SpiritcallTonic, dry_grind rares, and a cross-ref test confirming every recipe output exists in `Potions.byId`.

**Inert until next task:** the 12 new potions all have catalog entries but most lack `Constants.POTIONS` effect mappings. They'll appear in inventory + Brewing Journal but show "No effect yet" when consumed. Effect implementations land in the next Phase 1 task (the 7 remaining effect kinds).

### 2026-05-01 — ProfileService migration + save schema v3
- Vendored ProfileService at `src/server/Vendor/ProfileService.luau` (downloaded from MadStudioRoblox/ProfileService master).
- Rewrote `PlayerData.luau` to use ProfileService for session locking + autosave + retries. Public API (`get`, `update`, `save`) preserved so gameplay modules don't need updates. Replaced 4 separate lifecycle calls (`onPlayerAdded`, `onPlayerRemoving`, `startAutosaveLoop`, `saveAllOnShutdown`) with a single `PlayerData.start()` — autosave + shutdown handling are now ProfileService's responsibility.
- Bumped save schema to v3. Added v3 fields per `docs/specs/save-schema-v3.md`: `inventoryByCategory` (11 categories), `spirits`, `decorations`, `plots`, `reputation`, `activeQuests`, `gamepassesOwned`, `settings`, `auditTrail`, plus new `stats` counters (`totalRareVariants`, `totalPlotFailures`, `totalDistanceWalked`, `spiritsCollected`, `biomesUnlocked`, `questsCompleted`, `recipesAttempted`, `recipesDiscovered`).
- Wrote `migrate(data)` v2→v3 step. Idempotent (safe to run on already-v3 saves). Backwards compatible: legacy `data.inventory` and `data.potions` fields preserved so existing modules (Brewing, Harvesting, Planting, Selling, PotionEffects) work unchanged. Future phase work moves consumers to `inventoryByCategory.*` and v4 can drop the legacy keys.
- Updated `init.server.luau`: replaced 4 PlayerData calls with one `PlayerData.start()` and removed the BindToClose autosave block.
- Added `Tests/SaveSchemaSpec.luau` — 21 tests covering defaultData shape, v1→v3 migration, v2→v3 migration, idempotency, malformed-input handling. Total test count target: 95 (74 + 21). Registered in `RunTests.server.luau`.

**Verification pending in Studio:**
- Run Play and confirm Output shows `Tests complete: 95 passed, 0 failed`.
- Confirm `[ProfileService]: ...` startup logs (ProfileService prints its own version info on first load).
- Existing player saves (v2) should auto-migrate on first load. Confirm a Studio Play Solo session loads cleanly + the HUD shows expected coins/inventory.

**Known follow-up:**
- Constants.SAVE.autosaveInterval is now unused (ProfileService manages its own ~30s autosave). Leave the constant for now; remove in a future cleanup pass once we're sure nothing reads it.
- `data.inventory` + `data.inventoryByCategory.mushrooms_raw` don't auto-sync after migration — they're separate tables. Existing code reads/writes `data.inventory`; new v3-aware code (Phase 2+) reads `inventoryByCategory.mushrooms_raw`. Don't write to one and expect the other to update. Sync layer or full consumer migration goes in v4 prep.

### 2026-05-01 — Pre-Alpha port to new project structure
- Ported all 36 Pre-Alpha files from `mycelia/src/` into the new top-level `src/` layout.
- Renamed `.lua` → `.luau`. Renamed `Main.server.lua` → `init.server.luau`.
- Rewrote all `require(ServerScriptService.X)` to `require(ServerScriptService.Server.X)` to match the new project.json wrapper.
- Removed the three stub files (`server/init.server.luau`, `client/init.client.luau`, `shared/Hello.luau`).
- Created this HANDOFF.md at the project root (CLAUDE.md and CONTRIBUTING.md both reference it).
- Verification pending in Studio: re-Play and confirm world builds + tests pass + no broken require paths.

### Earlier (in `mycelia/HANDOFF.md`)
The legacy handoff document captures the full Pre-Alpha build history — gameplay scaffold, brewing foundation, terrain pass, mountain + cave + pond + koi, etc. Refer to that file for the long-form history of how Pre-Alpha was built. Once the new structure is verified working in Studio, that file is archive-only.

---

## Design rules locked in (don't break)

- **Server-authoritative everything.** Clients send intents via Remotes; server validates before any state mutation.
- **Tunables in `src/shared/Constants.luau`.** Anything balance-affecting (costs, durations, multipliers, drop rates) belongs there, not in logic files.
- **Species `id` never changes once shipped.** It's the save-data key.
- **No pay-to-win.** Robux unlocks time and cosmetics, never rare items, recipes, or trading advantages.
- **Match existing module conventions.** Don't introduce new patterns (OOP frameworks, dependency injection, alternative module structures) without writing an ADR first (see `docs/CONTRIBUTING.md`).
- **Pure-function modules get tests.** Server-side remote handlers get tests. See `docs/CONTRIBUTING.md`'s Definition of Done.

---

*Last touched: 2026-05-01. Last verified working: Pre-Alpha gameplay loop in legacy `mycelia/` structure (74 tests passing). Port to new `src/` structure complete; Studio verification pending.*
