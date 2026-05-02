# Spec — Potions and Recipes

Complete list of recipes (current 6 + 14 new = 20 total target) and all 10 potion effect kinds with parameters. Implements the brewing depth task in Phase 1 of the [ROADMAP](../ROADMAP.md).

A contractor implementing brewing depth should be able to copy these tables into `Recipes.lua` / `Potions.lua` / `PotionEffects.lua` directly.

---

## Recipes (20 total: 6 existing + 14 new)

Recipes are matched by `(method, sortedIngredientIds)` → potion id. Failed brews intentionally consume ingredients (engagement design — experimentation has cost).

Recipe key format: `method .. "|" .. table.concat(sortedIngredientIds, ",")`.

Structure used in `Recipes.lua`:
```lua
addRecipe(method, ingredients, potionId)
```

### Recipes table (in implementation order)

| # | Method | Ingredients (sorted alphabetically) | Output potion | Difficulty |
|---|---|---|---|---|
| **Existing (6, already shipped)** |||||
| 1 | steep | BrownCap, BrownCap, BrownCap | CommonSpeedPotion | Easy |
| 2 | steep | FairyCup, Mossring | DewdropTonic | Easy |
| 3 | boil | Buttoncap, Pinwheel, SpottedToadstool | HearthBrew | Easy |
| 4 | ferment | Inkpot | InkblotElixir | Mid |
| 5 | ferment | SpottedToadstool, SpottedToadstool | SpottedTincture | Easy |
| 6 | dry_grind | Glowmoss | GlowmossPowder | Hard |
| **Phase 1 additions (14)** |||||
| 7 | steep | FairyCup, FairyCup | DewdropTonic | Easy (alt path) |
| 8 | steep | Mossring, Mossring, Mossring | StonecastInfusion | Easy |
| 9 | boil | BrownCap, FairyCup | WoodlandWarmth | Easy |
| 10 | boil | LatticeVeil, BrownCap | LatticeBalm | Mid |
| 11 | ferment | Buttoncap, Inkpot | InkblotElixir | Mid (alt path) |
| 12 | ferment | Hollowstem, Pinwheel | HollowwindBrew | Mid |
| 13 | ferment | CoralTongue | CoralCordial | Mid |
| 14 | dry_grind | Sundrop | DaybreakPowder | Mid |
| 15 | dry_grind | Whisperbloom | LuckPowder | Hard |
| 16 | dry_grind | Dewfern | EverdewPowder | Hard |
| 17 | steep | CrystalCap, CrystalCap | CrystalEssence | Hard |
| 18 | boil | Glowmoss, Mossring | NightlanternOil | Hard |
| 19 | ferment | LatticeVeil, CoralTongue | TideweaverElixir | Mid |
| 20 | ferment | Whisperbloom, FairyCup, Mossring | SpiritcallTonic | Hard |

### Recipe distribution rationale

- **5 Easy recipes** (commons-only, common methods): give a new player frequent discovery moments in their first few hours.
- **8 Mid recipes** (require uncommons or specific common combos): mid-game discovery as cultivation depth opens up.
- **5 Hard recipes** (require rares/epics, or specific weird combos): late-game chase.
- **Recipe redundancy on purpose:** DewdropTonic has two paths (FairyCup+Mossring OR FairyCup×2) and InkblotElixir has two paths (Inkpot OR Buttoncap+Inkpot). Players who don't have one ingredient set might find another. Light combinatorial encouragement.

### Recipe data flow (for context)

1. Player opens cauldron UI, picks method + ingredients, hits Brew.
2. Client fires `Brew` remote with `(method, ingredientIds[])`.
3. Server validates, consumes ingredients, computes recipe key, looks up `Recipes.byKey[key]`.
4. If hit → award potion, mark as discovered if first time, fire `BrewCompleted(success=true, potionId, isNewDiscovery)`.
5. If miss → fizzle, ingredients still consumed, fire `BrewCompleted(success=false)`.
6. Client renders the appropriate toast.

---

## Potions (20 total: 6 existing + 14 new)

Each potion has flavor (`displayName`, `description`, `rarity`) and one effect kind with parameters.

Structure in `Constants.POTIONS`:
```lua
[potionId] = {
    displayName,
    description,
    rarity,                      -- "Common" | "Uncommon" | "Rare"
    effectKind,                  -- one of the 10 kinds below
    effectParams = { ... },      -- kind-specific parameters
    durationSeconds,             -- 0 means one-shot / instant; else timed effect
}
```

### Catalog

#### Existing (6)

| Id | Name | Rarity | Effect | Params | Duration |
|---|---|---|---|---|---|
| `CommonSpeedPotion` | Common Speed Potion | Common | speed | `{ multiplier = 1.30 }` | 30s |
| `DewdropTonic` | Dewdrop Tonic | Common | wildYield | `{ bonusYield = 1 }` | 60s |
| `HearthBrew` | Hearth Brew | Common | growth | `{ multiplier = 0.70 }` | 60s |
| `InkblotElixir` | Inkblot Elixir | Uncommon | reveal | `{ radius = 30 }` | 45s |
| `SpottedTincture` | Spotted Tincture | Uncommon | luck | `{ rareBonus = 0.05 }` | 60s |
| `GlowmossPowder` | Glowmoss Powder | Rare | reveal | `{ radius = 60 }` | 90s |

#### Phase 1 additions (14)

| Id | Name | Rarity | Effect | Params | Duration |
|---|---|---|---|---|---|
| `StonecastInfusion` | Stonecast Infusion | Common | harvestYield | `{ bonusYield = 1 }` | 60s |
| `WoodlandWarmth` | Woodland Warmth | Common | growth | `{ multiplier = 0.85 }` | 90s |
| `LatticeBalm` | Lattice Balm | Uncommon | growth | `{ multiplier = 0.50 }` | 30s |
| `HollowwindBrew` | Hollowwind Brew | Uncommon | speed | `{ multiplier = 1.50 }` | 30s |
| `CoralCordial` | Coral Cordial | Uncommon | wildYield | `{ bonusYield = 2 }` | 45s |
| `DaybreakPowder` | Daybreak Powder | Uncommon | timeShift | `{ allowToggle = true }` | 300s |
| `LuckPowder` | Luck Powder | Rare | luck | `{ rareBonus = 0.10 }` | 60s |
| `EverdewPowder` | Everdew Powder | Rare | weatherSummon | `{ weatherKind = "Rainy" }` | 600s |
| `CrystalEssence` | Crystal Essence | Rare | cosmeticGlow | `{ color = Color3.fromRGB(180, 200, 255) }` | 600s |
| `NightlanternOil` | Nightlantern Oil | Rare | reveal | `{ radius = 90 }` | 120s |
| `TideweaverElixir` | Tideweaver Elixir | Rare | harvestYield | `{ bonusYield = 2 }` | 120s |
| `SpiritcallTonic` | Spiritcall Tonic | Rare | spiritAttract | `{ multiplier = 2.0 }` | 600s |

### Naming consistency

- `*Powder` → effects from dry-grind. Always.
- `*Tonic` / `*Brew` / `*Infusion` → steep / boil products.
- `*Elixir` / `*Cordial` → ferment products typically.
- `*Essence` → reserved for crystalline/refined potions.

This is loose convention to help players intuit method ↔ result patterns.

---

## Effect kinds (10 total)

Implemented in `PotionEffects.lua`. Each kind has:
- An `apply(player, params, durationSeconds)` function.
- A `revert(player, effectInstance)` function.
- Per-player effect registry tracking active instances.
- Heartbeat-driven expiry.

Existing implementation (Phase 0) covers `speed`, `growth`, `wildYield`. Phase 1 extends to all 10.

### 1. `speed`

Multiplies player's `Humanoid.WalkSpeed` for `durationSeconds`.

**Params:** `{ multiplier: number }` — typical 1.2 to 1.6.

**Apply:** `humanoid.WalkSpeed = baseSpeed * multiplier` and remember the original value.

**Revert:** restore `WalkSpeed = baseSpeed`.

**Stacking:** same-kind reapply refreshes timer; doesn't multiply magnitude.

**Notes:** if the character respawns mid-effect, re-apply on character spawn (track effect end time, not character lifecycle).

### 2. `growth`

Applies a growth-time multiplier to all of the player's currently-Growing plots, AND to plots planted during the duration.

**Params:** `{ multiplier: number }` — typical 0.5 to 0.9 (lower = faster).

**Apply:**
- For each plot currently in `Growing` state owned by the player: `plot.ripeAt = plot.plantedAt + (plot.ripeAt - plot.plantedAt) * multiplier`.
- Set a flag `player._growthMultiplier = multiplier` (or track in PotionEffects registry).
- For new plants during the duration, multiply `growthTimeSeconds * multiplier` at plant time.

**Revert:** clear the flag. Already-Growing plots keep their accelerated `ripeAt`; new plants no longer get the bonus.

**Stacking:** reapply during active = take the smaller (better) multiplier and refresh timer.

### 3. `wildYield`

Wild mushroom harvests award `+bonusYield` extra mushrooms.

**Params:** `{ bonusYield: number }` — typical 1 to 2.

**Apply:** set flag in PotionEffects registry.

**Affects:** `Harvesting.harvestWild` reads the flag at harvest time and awards `1 + bonusYield` mushrooms.

**Revert:** clear flag.

**Stacking:** higher of two stacks wins; timer refreshes.

### 4. `harvestYield`

Planted-plot harvests award extra mushrooms beyond the formula's output.

**Params:** `{ bonusYield: number }` — typical 1 to 3.

**Apply:** set flag.

**Affects:** `Harvesting.harvestPlot` reads flag, adds `bonusYield` to final yield count after the cultivation formula runs (so it stacks additively after multipliers).

### 5. `luck`

Increases rare-variant chance for both wild and planted harvests.

**Params:** `{ rareBonus: number }` — typical 0.05 to 0.15 (= 5% to 15% additive).

**Apply:** set flag.

**Affects:** `rare_chance` formula adds `luckBonus` before capping at `maxRareChance`.

### 6. `reveal`

Hidden mushrooms (a flag on wild spawns) become visible to this player within `radius` studs.

**Params:** `{ radius: number }` — typical 30 to 90.

**Apply:** set per-player visibility override; client-side renders previously-hidden mushrooms within radius.

**Affects:** `WildSpawn` flags some wild spawns as `hidden=true` (server-side, not visible by default). Client subscribes to `RevealUpdated` events and shows them within range.

**Notes:** "hidden" wild spawns are an optional content feature for late-game biomes (e.g., Glimmerwood). Not used in Pre-Alpha or Misty Hollow unless content design adds them.

### 7. `spiritAttract`

Increases spirit attraction roll multiplier for the duration.

**Params:** `{ multiplier: number }` — typical 1.5 to 3.0.

**Apply:** flag in registry.

**Affects:** `Spirits.attractionTick` multiplies the player's per-NPC roll chance by `multiplier`.

### 8. `cosmeticGlow`

Visual particle trail behind player character. No mechanical effect.

**Params:** `{ color: Color3 }`.

**Apply:** parent a `ParticleEmitter` (asset supplied) to player's HumanoidRootPart with `Color = color`.

**Revert:** remove particle emitter.

**Stacking:** later cosmetic potion replaces earlier (one trail at a time).

### 9. `weatherSummon`

Forces local biome's weather to `weatherKind` for the duration. Overrides natural weather.

**Params:** `{ weatherKind: string }` — `"Rainy"` / `"Sunny"` / `"Foggy"` / etc. (whatever Weather system supports; Phase 4).

**Apply:** call into `Weather.setOverride(biomeId, weatherKind, durationSeconds)`. Weather system handles the actual visual + plot-moisture changes.

**Revert:** Weather system clears override and resumes natural cycle.

**Stacking:** later override replaces earlier. (One weather at a time.)

**Phase 1 stub:** since Weather lands in Phase 4, the Phase 1 implementation can stub this — `EverdewPowder` shows a "Weather summon not yet active" toast or applies a tiny VFX-only rain that doesn't affect plot moisture. Document the stub in code.

### 10. `timeShift`

While active, the player can toggle day/night on their own plots via a UI button. Doesn't change other players' view.

**Params:** `{ allowToggle: bool }`.

**Apply:** flag in registry; HUD shows "☀/🌙" toggle button (no emoji in code; a Roblox Decal asset).

**Affects:** `Lighting.localOverride(player, mode)` adjusts what the player sees on their own plots. Other players see normal day/night.

**Phase 1 stub:** if Lighting infrastructure isn't ready, stub as a flag-only effect with no visual change. Document.

---

## PotionEffects.lua structure

```lua
local PotionEffects = {}

local activeByPlayer = {}    -- { [player] = { [effectKind] = { magnitude, endsAt, params } } }

function PotionEffects.apply(player, kind, params, durationSeconds)
    -- 1. Look up effect handler in EFFECT_HANDLERS[kind].apply
    -- 2. Call handler.apply(player, params)
    -- 3. Set activeByPlayer[player][kind] = { ..., endsAt = os.time() + durationSeconds }
    -- 4. Fire ActiveEffectsUpdated to client
    -- 5. Schedule expiry via task.delay or Heartbeat tick
end

function PotionEffects.revert(player, kind)
    -- 1. Look up handler.revert
    -- 2. Call handler.revert(player, params)
    -- 3. Clear activeByPlayer[player][kind]
    -- 4. Fire ActiveEffectsUpdated to client
end

function PotionEffects.isActive(player, kind)
    return activeByPlayer[player] and activeByPlayer[player][kind] ~= nil
end

function PotionEffects.getMultiplier(player, kind)
    -- Convenience: returns the magnitude for kind, or default (1.0 for multipliers, 0 for additives)
end

function PotionEffects.start()
    -- Heartbeat tick scans activeByPlayer for expired entries; reverts them.
    -- Player leaving: clear all active effects via revert (no save-and-restore — effects expire on logout).
end

local EFFECT_HANDLERS = {
    speed         = { apply = ..., revert = ... },
    growth        = { apply = ..., revert = ... },
    wildYield     = { apply = ..., revert = ... },
    harvestYield  = { apply = ..., revert = ... },
    luck          = { apply = ..., revert = ... },
    reveal        = { apply = ..., revert = ... },
    spiritAttract = { apply = ..., revert = ... },
    cosmeticGlow  = { apply = ..., revert = ... },
    weatherSummon = { apply = ..., revert = ... },
    timeShift     = { apply = ..., revert = ... },
}

return PotionEffects
```

---

## Stacking rules summary

| Kind | Same-kind reapply behavior |
|---|---|
| speed | Refresh timer; magnitude = max(old, new) |
| growth | Refresh timer; multiplier = min(old, new) — better stacks |
| wildYield | Refresh timer; bonus = max(old, new) |
| harvestYield | Refresh timer; bonus = max(old, new) |
| luck | Refresh timer; rareBonus = max(old, new) |
| reveal | Refresh timer; radius = max(old, new) |
| spiritAttract | Refresh timer; multiplier = max(old, new) |
| cosmeticGlow | Replace (one trail at a time) |
| weatherSummon | Replace (one weather override at a time) |
| timeShift | Refresh timer (no magnitude — boolean toggle) |

Different-kind potions stack freely (you can have speed + luck + reveal active simultaneously).

---

## Tests

`Tests/PotionEffectsSpec.lua`:

- Each kind: apply works, sets registry entry.
- Each kind: revert reverses the apply (state matches pre-apply state).
- Each kind: timed expiry triggers revert.
- Stacking rules per kind work as specified.
- `getMultiplier` returns correct value for active effects.
- Player leave clears active effects.

`Tests/RecipeLookupSpec.lua` (covers integrity of `Recipes.byKey`):

- Every recipe in the table maps to a valid potion id.
- Every potion id used in recipes exists in `Potions.byId`.
- No duplicate keys.
- `Recipes.lookup(method, ingredients)` returns expected potion for each known recipe.
- Ingredient-order independence: lookup with shuffled ingredient list returns the same potion.
- Missing recipes return nil.

---

## Notes

- **Failed brews still consume ingredients.** This is documented engagement design (see [SCRIPTING-ORDER.pdf](../SCRIPTING-ORDER.pdf) brewing section). The cost is what makes successful discovery feel like a discovery rather than a checkbox.
- **Recipes are server-side only.** Never replicate `Recipes.byKey` to clients. A determined client could parse it and spoil discovery.
- **The recipe attempts counter** in `data.stats.recipesAttempted` increments only on NEW combinations. Players who repeat a known-failure don't pad the counter.
- **The discovered-recipes map** in `data.stats.recipesDiscovered` records `key → potionId`. Lets the Brewing Journal show "you found this with: BrownCap × 3, steep" if `settings.showPotionHints == true`.
