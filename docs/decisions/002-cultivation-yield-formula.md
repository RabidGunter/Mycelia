# Mycelia — Decision: Cultivation Yield + Rare-Variant Formula

**Status:** RESOLVED 2026-05-01
**Decision:** Per-species `yieldBySubstrate` table. Multiplicative cultivation formula with all variables layered. Rare-variant chance scales with multiplier excess + magical-loam bonus.

Resolves open questions #2 (substrate compatibility math) and #4 (rare-variant drop chance curve) from the [ROADMAP](../ROADMAP.md).

---

## The question

Two tightly-coupled questions block Phase 1 cultivation depth:

- **#2: How does substrate type affect yield?** A common species planted on the wrong substrate should yield poorly or fail; getting it right should reward; magical loam should have a unique role. We need a concrete formula to translate "right" / "wrong" / "expensive-but-flexible" into harvest yields.
- **#4: What's the rare-variant drop chance curve?** Each harvest can roll for a tier-above variant of the planted species (a Common harvest occasionally yielding an Uncommon, etc.). What governs the chance — base rate, modifiers from variables, ceiling?

These two questions can't be answered independently because the optimization-substrate identity (magical loam, mostly) drives both yield and rare chance. Resolving them in one ADR keeps the formulas consistent.

---

## Options for substrate compatibility

### Model A — Binary

Preferred substrate: 1× yield. Wrong substrate: 0× (fails).

- **Pros:** Trivial to implement; no per-species balance work.
- **Cons:** Every plot is binary win/lose. No depth. Veterans bored within hours.

### Model B — Tiered compatibility groups

Each (species, substrate) pair is "preferred" / "compatible" / "incompatible" / "hostile," mapping to yield multipliers (1.5× / 1.0× / 0.5× / 0×).

- **Pros:** Simpler than per-species tables, more nuanced than binary.
- **Cons:** Tier groups become messy fast — eventually you're back to per-species with less flexibility. Bee Swarm doesn't use this; nobody else does either.

### Model C — Per-species `yieldBySubstrate` table

Each species declares an explicit map: `{ [substrateId] = multiplier }`. Multipliers are non-negative numbers, typically 0 to ~1.5.

- **Pros:** Maximum flexibility. Easy to tune one species without ripple. Encodes design knowledge directly. Bee Swarm follows the same pattern (per-bee jelly preferences).
- **Cons:** Six entries per species to maintain. At 60 species that's 360 numbers. Manageable; species data is the kind of thing CSV-edited or generated, not handwritten in Lua repeatedly.

---

## Recommendation: Model C — per-species `yieldBySubstrate`

Maintenance overhead is real but the design space it unlocks IS the depth layer. Without per-species control, "substrate strategy" is a one-line decision tree, which is exactly the shallow gameplay the design doc warns against.

---

## The full cultivation formula

```
final_yield = max(1, floor(
    baseYield
    × yieldBySubstrate[substrate]
    × moistureMultiplier
    × lightMultiplier
    × pHMultiplier
    × hostTreeMultiplier
    × companionMultiplier
    × playerBonusMultiplier
))

if yieldBySubstrate[substrate] == 0:
    plot fails  -- substrate is the only HARD failure variable
```

`playerBonusMultiplier` aggregates **all sources** of player-level bonuses for the relevant kind, applied additively then converted to a multiplier:

```
playerBonusMultiplier = 1 + PotionEffects.get(player, "harvestYield")
                          + PassiveBonuses.get(player, "harvestYield")
                          -- + future bonus sources (gamepass, achievements, etc.)
```

So a player with a `+15% harvestYield` Dewdrop spirit equipped AND a `+1 harvestYield` (= +100% additively) Stonecast Infusion potion active gets `playerBonusMultiplier = 1 + 1.0 + 0.15 = 2.15`. Multiple sources of the same kind stack additively at the source-aggregation step, then multiply through the formula.

The same pattern applies for wild harvests (`wildYield` kind), growth time (`growthSpeed` kind), and any future per-kind bonus. **Source-agnostic by design**: gameplay formulas don't care whether a bonus comes from a potion, a spirit, a gamepass, or a quest reward. They ask `PotionEffects.get(...) + PassiveBonuses.get(...)` and stack from there.

**Where:**
- `baseYield = 1`. Always start with 1. Depth comes from multipliers, not base power.
- Each multiplier is a non-negative number, typically 0 to ~1.5.
- If `yieldBySubstrate` is 0, plot fails entirely (no growth, ingredients lost). Other zero multipliers should be impossible by construction (player can't pick "0 moisture") — but if they happen, treat as failure.
- `max(1, floor(...))` means non-failed plots always yield at least 1 mushroom — the player who got the substrate right should never feel cheated by a bad pH roll.
- Cap `final_yield` at 5. Anything above 5 stacks toward rare-variant chance instead of more mushrooms (see below). Keeps the Pokedex grind manageable.

**Variable scope by phase:**
- **Phase 1 ships substrate only.** Other multipliers default to 1.0. The formula is multiplicative and accepts more terms additively over time.
- **Phase 2+** introduces moisture (watering), light (plot location), pH (additives).
- **Phase 3+** adds host tree (proximity to tagged trees), companion mushrooms (adjacent plot synergy).
- **Potion multiplier** ships with Phase 1's potion-effects work (already on the roadmap as `harvestYield`).

---

## Growth-time formula

Plot growth time is **decoupled from substrate compatibility**. Substrate affects yield (and rare chance via match-excess); time stays a clean function of species characteristic plus tuning multipliers.

```
ripeTime = species.growthTimeSeconds
         × Constants.CULTIVATION.growthTimeMultiplier
         × playerActiveGrowthPotionMultiplier   -- 1.0 if no growth potion active

ripeAt = plantedAt + math.floor(ripeTime)
```

**Phase 1 inputs:**
- `species.growthTimeSeconds` — per-species base time (data, in `Species.lua`).
- `Constants.CULTIVATION.growthTimeMultiplier` — global tuning knob; default 1.0. Rebalance lever for game-wide pacing.
- `playerActiveGrowthPotionMultiplier` — from PotionEffects registry; 1.0 if no `growth`-kind potion active.

**Phase 2+ moisture/light/pH/host/companion variables affect yield only, not time.** Adding more variables to time would punish players doubly (low yield AND slow growth) for non-optimal plots; keeping time decoupled means weak plots fail or yield poorly, but don't waste extra wall-clock waiting.

**Why magical loam doesn't speed up growth:** loam's identity is "rare-chance bonus + slight yield variance + universal viability." Adding a time bonus would stack three benefits and incentivize loam-only play. Loam stays the most expensive substrate for a reason.

The only way to accelerate plot ripening is via active `growth`-kind potions (HearthBrew, LatticeBalm, WoodlandWarmth — see [potions-and-recipes spec](../specs/potions-and-recipes.md)) or future progression unlocks (e.g., a Spritefly spirit in active roster).

---

## Rare-variant chance formula

Each individual mushroom yielded rolls independently for a rare variant — a tier-above mushroom of the same theme.

```
rare_chance = baseRareChance
            + (substrate_match_excess × substrateMatchExcessRareBonus)
            + (magicalLoamRareBonus  if substrate == "magical_loam"  else 0)
            + (sum of OTHER multiplier excesses × otherMultiplierExcessRareBonus)
            + (potion_luck_bonus  if luck potion active  else 0)

rare_chance = min(rare_chance, maxRareChance)

substrate_match_excess = max(0, yieldBySubstrate[substrate] - 1.0)
```

**Defaults (in `Constants.CULTIVATION`):**
- `baseRareChance = 0.01` (1%)
- `substrateMatchExcessRareBonus = 0.005` (each 0.1 of substrate excess → +0.05% rare chance — slow accumulator)
- `magicalLoamRareBonus = 0.01` (flat +1% if planted on magical loam)
- `otherMultiplierExcessRareBonus = 0.003` (other variables contribute less than substrate)
- `maxRareChance = 0.10` (hard cap at 10%)

**Why this shape:**
- A perfect 1.0 substrate match contributes nothing — getting it right is the *baseline*, not the bonus. Bonuses come from *exceeding* preferred (e.g., magical loam returning 1.2 for a common gives 0.2 of excess).
- Magical loam gets a flat +1% on top of its possibly-bonus excess. Encodes loam's identity as "the experiment substrate" — yields slightly less, drops rares slightly more.
- The 10% cap prevents stacking everything to a near-guaranteed rare; rare-variant should always feel like a roll, not an expectation.
- One roll per yielded mushroom (so a 3-yield plot rolls 3 times) — keeps math intuitive.

**Tier mapping for rare variants:**

| Planted | Possible rare variant |
|---|---|
| Common | Uncommon (same biome / theme) |
| Uncommon | Rare |
| Rare | Epic |
| Epic | Legendary |
| Legendary | Mythic (rare — usually lunar event triggered) |
| Mythic | (no further; mythic is the ceiling) |

The exact "which Uncommon comes from which Common" mapping is per-species data, defined as `Species.rareVariantId` (singular — each species has one rare-variant target). Permits flavor-driven choices: BrownCap → LatticeVeil (the fungal-adjacent Uncommon) rather than a random Uncommon roll.

---

## Substrate identity hints

To make the design read clearly to players (and to anyone setting yield numbers later):

| Substrate | Cost | Identity | Best for |
|---|---|---|---|
| **Compost** | Cheap | Default starting substrate. Forgiving to commons. | Commons; baseline option. |
| **Hardwood** | Cheap | Wood-loving species. | Lattice Veil, Coral Tongue, similar wood decomposers. |
| **Straw** | Cheap | Sun-loving decomposers. | Pinwheel, Sundrop, Spotted Toadstool. |
| **Dung** | Cheap | Coprophilic species. Gross but reliable. | Inkpot, Buttoncap. |
| **Peat** | Mid | Water-loving + bioluminescent. | Glowmoss, Dewfern, Hollowstem. |
| **Magical Loam** | Expensive | Universal-but-pricey. Reduced yield, increased rare chance. | Rares, Epics, experimental brews. |

Player progression goal: unlock magical loam by mid-game (substrate merchant gates it behind reputation), making Epic species reachable via cultivation rather than purely wild luck.

---

## Concrete `yieldBySubstrate` for Pre-Alpha species

The numbers below are starting values. Tune via Constants and per-species data based on playtesting.

### Common (5 of the 15 — sample)

**BrownCap** — default everyman. Most flexible.
```lua
yieldBySubstrate = {
    compost      = 1.0,   -- preferred
    straw        = 0.7,
    dung         = 0.5,
    peat         = 0.3,
    hardwood     = 0.0,   -- hostile
    magical_loam = 1.2,   -- loam loves commons
}
```

**Buttoncap** — coprophilic.
```lua
yieldBySubstrate = {
    dung         = 1.0,
    compost      = 0.6,
    peat         = 0.0,
    hardwood     = 0.0,
    straw        = 0.0,
    magical_loam = 1.1,
}
```

**Pinwheel** — sun-lover.
```lua
yieldBySubstrate = {
    straw        = 1.0,
    compost      = 0.5,
    dung         = 0.3,
    peat         = 0.0,
    hardwood     = 0.0,
    magical_loam = 1.1,
}
```

### Uncommon

**LatticeVeil** — wood-loving.
```lua
yieldBySubstrate = {
    hardwood     = 1.0,
    compost      = 0.4,
    magical_loam = 0.9,
    -- straw, dung, peat all 0.0 (hostile)
}
```

**Inkpot** — coprophilic.
```lua
yieldBySubstrate = {
    dung         = 1.0,
    compost      = 0.3,
    magical_loam = 0.9,
    -- hardwood, straw, peat all 0.0
}
```

### Rare

**Glowmoss** — strict, water-loving.
```lua
yieldBySubstrate = {
    peat         = 1.0,
    magical_loam = 0.8,
    -- everything else 0.0
}
```

**Dewfern** — strict, water-loving.
```lua
yieldBySubstrate = {
    peat         = 1.0,
    magical_loam = 0.8,
    -- everything else 0.0
}
```

### Epic

**CrystalCap** — only loam.
```lua
yieldBySubstrate = {
    magical_loam = 1.0,
    -- everything else 0.0
}
```

**Pattern:** as tier rises, viable substrates collapse. By Epic, only magical loam works — and loam is the most expensive substrate, so cost-of-trying matches rarity-of-success.

---

## Plot state machine

Phase 1 introduces a `Failed` state. Full state machine for a plot:

| State | Player-visible | Active prompt | Visual |
|---|---|---|---|
| `Empty` | yes | `PlantPrompt` | `EmptyVisual` |
| `Growing` | yes | (none) | `GrowingVisual` |
| `Ripe` | yes | `HarvestPrompt` | `RipeVisual` |
| `Failed` | yes (transient) | (none) | `FailedVisual` + floating "Nothing grew here." text |

### Transitions

| From | To | Trigger |
|---|---|---|
| Empty | Growing | Successful `PlantSpecies` remote (all validation rules pass). |
| Growing | Ripe | At ripen check (`os.time() >= ripeAt`), if computed `final_yield > 0`. |
| Growing | Failed | At ripen check, if computed `final_yield == 0` (i.e., `yieldBySubstrate[substrate] == 0` or any other multiplier zero in Phase 2+). |
| Ripe | Empty | Successful harvest via `HarvestPrompt`. |
| Failed | Empty | After `Constants.CULTIVATION.failedDisplaySeconds` (default 5) has elapsed. Auto-reset; no player action required. |

### Resolution timing — failed at ripen, not at harvest

Yield is computed at the **ripen check** (the Heartbeat-driven loop that polls `Growing` plots for `ripeAt`), not at harvest time. If yield is 0 the plot transitions directly Growing → Failed and never enters Ripe. The player sees the failure visually as soon as the growth period elapses; they don't walk up expecting a harvest and get a surprise.

This matters for player feel: a Ripe-looking plot that fails on `E` press would feel deceptive. Resolving at ripen means the visible state is always honest.

### Substrate consumption

Substrate is consumed at **plant time**, regardless of outcome. The player loses one substrate item even if the plot ends up Failed. This is the documented engagement-design cost of experimentation — see also failed brews in the brewing system, same principle.

### New constant

```lua
Constants.CULTIVATION.failedDisplaySeconds = 5
```

---

## Implementation notes

### Data layer

1. **Add `yieldBySubstrate` to every entry in `Species.lua`.** Default any unspecified substrate to 0.0 (i.e., explicit only the substrates that work). A species lookup helper returns 0 for missing keys.

2. **Add `rareVariantId` to species** that have one (defaults to nil for top-tier species like Mythic). Naming convention preserved: target species id only, no extra metadata.

3. **Add `Constants.SUBSTRATES`** table:
   ```lua
   Constants.SUBSTRATES = {
       compost      = { displayName = "Compost",      cost = 5,   ... },
       hardwood     = { displayName = "Hardwood",     cost = 5,   ... },
       straw        = { displayName = "Straw",        cost = 5,   ... },
       dung         = { displayName = "Dung",         cost = 5,   ... },
       peat         = { displayName = "Peat",         cost = 25,  ... },
       magical_loam = { displayName = "Magical Loam", cost = 200, ... },
   }
   ```

### Server logic

4. **Plant flow** (`Planting.lua`):
   - `PlantSpecies` remote takes `(plot, speciesId, substrateId, additives)`.
   - Server validates: player owns substrate, can afford. Substrate is consumed at plant time.
   - Server stores `substrate` attribute on the plot.
   - **Don't reject** plant on substrate=0 mismatch — let the player try and learn from the failure. Plot enters Growing state, then Failed state when ripeAt elapses.

5. **Harvest flow** (`Harvesting.lua`):
   - Read all plot attributes + species data.
   - Compute `final_yield` per the formula.
   - If 0, plot enters "Failed" state — a small "Nothing grew here." text floats from the plot, plot resets to Empty. Substrate is gone (intentional — failure has cost, this is the design-doc engagement loop).
   - For each unit of yield, roll rare-variant chance independently.
   - Award yielded mushrooms (mix of base species + rare variants).
   - Show toast: `"Harvested 3 BrownCap, 1 LatticeVeil!"` (or similar, conveying which were rare).

### Constants additions

```lua
Constants.CULTIVATION.baseYield                            = 1
Constants.CULTIVATION.maxYield                             = 5
Constants.CULTIVATION.baseRareChance                       = 0.01
Constants.CULTIVATION.maxRareChance                        = 0.10
Constants.CULTIVATION.substrateMatchExcessRareBonus        = 0.005
Constants.CULTIVATION.magicalLoamRareBonus                 = 0.01
Constants.CULTIVATION.otherMultiplierExcessRareBonus       = 0.003
```

### Tests (`Tests/CultivationSpec.lua`)

- Yield formula correctness for known input combinations.
- Plot fails (yield = 0) when `yieldBySubstrate[substrate] == 0`.
- Plot yields exactly 1 when all multipliers are 1.0 (sanity check).
- Yield caps at 5 even with extreme multipliers.
- Rare chance correctly scales with substrate excess.
- Rare chance correctly caps at 10%.
- Magical loam +1% bonus applies regardless of species.
- Every species in `Species.byId` has a `yieldBySubstrate` table (data integrity).

---

## When the alternative IS appropriate

If at any point the per-species table maintenance becomes intolerable (e.g., post-launch with 100+ species and no CSV pipeline), retreat to **Model B (tiered groups)** by extracting common patterns. Don't go to **Model A (binary)** — too shallow for the design promise.

If players consistently report "substrate doesn't matter" or "I just always use magical loam" — first tune Constants (raise loam cost, lower loam bonus); only restructure the formula if Constants tuning fails.

---

## Override criteria

Revisit this formula if:

- Players consistently complete the full Pokedex in <50 hours. → Rare chance too generous; lower `baseRareChance` or `maxRareChance`.
- Players consistently report "I can't get past Tier 2." → Rare chance too stingy; raise the bonuses.
- Magical loam ends up unused. → Loam bonus needs to go up; loam cost needs to come down.
- Magical loam is the *only* substrate anyone uses. → Loam bonus needs to go down; loam cost needs to go up; cheap-substrate yields need a small bump.
- Plot failures feel punitive rather than instructive (players quit after a couple). → Soften the cost (refund partial substrate on fail) before changing the formula.

Tunable values live in `Constants.lua`. Only the *formula structure* is locked here.

---

*Marked resolved in [../ROADMAP.md](../ROADMAP.md).*
