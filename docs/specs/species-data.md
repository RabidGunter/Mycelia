# Spec — Species Data and Substrates

Complete data tables for all 15 Pre-Alpha species and 6 substrates. Implements the cultivation formula from [decisions/002-cultivation-yield-formula.md](../decisions/002-cultivation-yield-formula.md).

A contractor implementing Phase 1 should be able to copy these tables directly into `Species.lua` and `Constants.SUBSTRATES` with minimal interpretation.

---

## Substrates

`Constants.SUBSTRATES`. Six substrate types. Cost is in coins (charged at plant time, consumed on harvest unless `Recyclable Substrate` gamepass is owned).

```lua
Constants.SUBSTRATES = {
    compost = {
        id           = "compost",
        displayName  = "Compost",
        cost         = 5,
        unlockSource = "default",         -- available from Substrate Merchant on first interaction
        unlockGate   = nil,
        description  = "Decayed plant matter. The everyman substrate. Most commons love it.",
    },
    hardwood = {
        id           = "hardwood",
        displayName  = "Hardwood",
        cost         = 5,
        unlockSource = "merchant",
        unlockGate   = { kind = "reputation", npcId = "SubstrateMerchant", min = 100 },
        description  = "Aged hardwood chips. Wood-loving species fruit here.",
    },
    straw = {
        id           = "straw",
        displayName  = "Straw",
        cost         = 5,
        unlockSource = "merchant",
        unlockGate   = { kind = "reputation", npcId = "SubstrateMerchant", min = 100 },
        description  = "Sun-dried straw. Sun-loving decomposers prefer it.",
    },
    dung = {
        id           = "dung",
        displayName  = "Dung",
        cost         = 5,
        unlockSource = "quest",
        unlockGate   = { kind = "questCompleted", questId = "SM_introduce_dung" },
        description  = "Aged animal dung. Don't ask. Coprophilic species thrive on it.",
    },
    peat = {
        id           = "peat",
        displayName  = "Peat",
        cost         = 25,
        unlockSource = "merchant",
        unlockGate   = { kind = "reputation", npcId = "SubstrateMerchant", min = 500 },
        description  = "Compressed bog material. Holds water. Bioluminescents love it.",
    },
    magical_loam = {
        id           = "magical_loam",
        displayName  = "Magical Loam",
        cost         = 200,
        unlockSource = "merchant",
        unlockGate   = { kind = "reputation", npcId = "SubstrateMerchant", min = 1500 },
        description  = "Mycelium-rich enchanted soil. Grows almost anything (slightly less yield) and increases rare-variant chance.",
    },
}

Constants.SUBSTRATE_ORDER = {
    "compost", "hardwood", "straw", "dung", "peat", "magical_loam"
}
```

`SUBSTRATE_ORDER` is used by UI so substrates appear in a consistent left-to-right order in pickers, regardless of `pairs()` iteration order.

---

## Species

All 15 Pre-Alpha species. Each entry below contains the **complete** record needed by `Species.lua`, including the `yieldBySubstrate` table and `rareVariantId`.

### Field reference

| Field | Type | Notes |
|---|---|---|
| `id` | string | Save-data key. **Never change** once shipped. |
| `displayName` | string | Player-visible name. |
| `tier` | string | One of `Common` / `Uncommon` / `Rare` / `Epic`. (Legendary / Mythic ship in Phase 4.) |
| `description` | string | Pokedex flavor text. |
| `baseSellPrice` | number | Witch-stall buy price before tier multiplier. |
| `growthTimeSeconds` | number | Base growth time at substrate=1.0 and all multipliers=1.0. |
| `substratePref` | array of strings | Display hint: which substrates this species prefers (yieldBySubstrate >= 1.0). For UI only; logic uses yieldBySubstrate directly. |
| `yieldBySubstrate` | table | Per-substrate yield multiplier. Missing keys default to 0.0. |
| `lightPref` | string | `sunny` / `dappled` / `dark`. Phase 2+ uses this; Phase 1 ignores. |
| `moisturePref` | number | 0–1 ideal. Phase 2+ uses; Phase 1 ignores. |
| `pHPref` | number | 4.0–8.0 ideal. Phase 2+ uses; Phase 1 ignores. |
| `rareVariantId` | string or nil | The species id one tier above this one that this species can occasionally yield. Nil if no rare variant defined. |
| `brewingTags` | array | Empty placeholder for now; populated when brewing depth lands in Phase 1. |

### Common (6 species)

```lua
{
    id = "BrownCap",
    displayName = "Brown Cap",
    tier = "Common",
    description = "The everyman of the forest. Not glamorous, but pays the rent.",
    baseSellPrice = 3,
    growthTimeSeconds = 60,
    substratePref = { "compost" },
    yieldBySubstrate = {
        compost = 1.0, straw = 0.7, dung = 0.5, peat = 0.3,
        hardwood = 0.0, magical_loam = 1.2,
    },
    lightPref = "dappled",
    moisturePref = 0.5,
    pHPref = 6.5,
    rareVariantId = "LatticeVeil",
    brewingTags = {},
},
{
    id = "SpottedToadstool",
    displayName = "Spotted Toadstool",
    tier = "Common",
    description = "Storybook-red with white spots. Mildly hallucinogenic to garden gnomes.",
    baseSellPrice = 4,
    growthTimeSeconds = 75,
    substratePref = { "compost", "straw" },
    yieldBySubstrate = {
        compost = 1.0, straw = 1.0, dung = 0.4, peat = 0.0,
        hardwood = 0.3, magical_loam = 1.2,
    },
    lightPref = "dappled",
    moisturePref = 0.55,
    pHPref = 6.0,
    rareVariantId = "LatticeVeil",
    brewingTags = {},
},
{
    id = "FairyCup",
    displayName = "Fairy Cup",
    tier = "Common",
    description = "Tiny chalice-shaped caps that catch morning dew.",
    baseSellPrice = 5,
    growthTimeSeconds = 90,
    substratePref = { "compost" },
    yieldBySubstrate = {
        compost = 1.0, straw = 0.5, dung = 0.0, peat = 0.6,
        hardwood = 0.0, magical_loam = 1.2,
    },
    lightPref = "dappled",
    moisturePref = 0.7,
    pHPref = 6.5,
    rareVariantId = "Sundrop",
    brewingTags = {},
},
{
    id = "Mossring",
    displayName = "Mossring",
    tier = "Common",
    description = "Forms tidy circles in damp moss. The forest's punctuation.",
    baseSellPrice = 5,
    growthTimeSeconds = 90,
    substratePref = { "compost" },
    yieldBySubstrate = {
        compost = 1.0, straw = 0.4, dung = 0.0, peat = 0.7,
        hardwood = 0.0, magical_loam = 1.1,
    },
    lightPref = "dappled",
    moisturePref = 0.65,
    pHPref = 6.5,
    rareVariantId = "CoralTongue",
    brewingTags = {},
},
{
    id = "Buttoncap",
    displayName = "Buttoncap",
    tier = "Common",
    description = "Squat, sturdy, and content. The mushroom equivalent of a good chair.",
    baseSellPrice = 3,
    growthTimeSeconds = 55,
    substratePref = { "compost", "dung" },
    yieldBySubstrate = {
        compost = 1.0, straw = 0.4, dung = 1.0, peat = 0.0,
        hardwood = 0.0, magical_loam = 1.1,
    },
    lightPref = "dark",
    moisturePref = 0.5,
    pHPref = 7.0,
    rareVariantId = "Inkpot",
    brewingTags = {},
},
{
    id = "Pinwheel",
    displayName = "Pinwheel",
    tier = "Common",
    description = "Thin, fluted gills like a child's toy. Pops up after rain.",
    baseSellPrice = 6,
    growthTimeSeconds = 100,
    substratePref = { "straw" },
    yieldBySubstrate = {
        compost = 0.5, straw = 1.0, dung = 0.3, peat = 0.0,
        hardwood = 0.0, magical_loam = 1.1,
    },
    lightPref = "sunny",
    moisturePref = 0.6,
    pHPref = 6.5,
    rareVariantId = "Sundrop",
    brewingTags = {},
},
```

### Uncommon (5 species)

```lua
{
    id = "LatticeVeil",
    displayName = "Lattice Veil",
    tier = "Uncommon",
    description = "A shimmering net of mycelial lace drapes from the cap.",
    baseSellPrice = 12,
    growthTimeSeconds = 180,
    substratePref = { "hardwood" },
    yieldBySubstrate = {
        hardwood = 1.0, compost = 0.4, magical_loam = 0.9,
        straw = 0.0, dung = 0.0, peat = 0.0,
    },
    lightPref = "dappled",
    moisturePref = 0.5,
    pHPref = 6.0,
    rareVariantId = "Whisperbloom",
    brewingTags = {},
},
{
    id = "Inkpot",
    displayName = "Inkpot",
    tier = "Uncommon",
    description = "Black gills that liquify into ink at maturity. Worth harvesting precisely.",
    baseSellPrice = 15,
    growthTimeSeconds = 200,
    substratePref = { "dung" },
    yieldBySubstrate = {
        dung = 1.0, compost = 0.3, magical_loam = 0.9,
        hardwood = 0.0, straw = 0.0, peat = 0.0,
    },
    lightPref = "dark",
    moisturePref = 0.7,
    pHPref = 7.5,
    rareVariantId = "Whisperbloom",
    brewingTags = {},
},
{
    id = "CoralTongue",
    displayName = "Coral Tongue",
    tier = "Uncommon",
    description = "Branching pink-orange fingers. Looks more like reef than fungus.",
    baseSellPrice = 18,
    growthTimeSeconds = 220,
    substratePref = { "hardwood" },
    yieldBySubstrate = {
        hardwood = 1.0, compost = 0.3, magical_loam = 0.9,
        straw = 0.0, dung = 0.0, peat = 0.0,
    },
    lightPref = "dappled",
    moisturePref = 0.55,
    pHPref = 6.0,
    rareVariantId = "Glowmoss",
    brewingTags = {},
},
{
    id = "Sundrop",
    displayName = "Sundrop",
    tier = "Uncommon",
    description = "Yellow caps that follow the sun. The only mushroom you can tell time by.",
    baseSellPrice = 14,
    growthTimeSeconds = 180,
    substratePref = { "straw" },
    yieldBySubstrate = {
        straw = 1.0, compost = 0.4, magical_loam = 0.9,
        hardwood = 0.0, dung = 0.0, peat = 0.0,
    },
    lightPref = "sunny",
    moisturePref = 0.4,
    pHPref = 6.5,
    rareVariantId = "Dewfern",
    brewingTags = {},
},
{
    id = "Hollowstem",
    displayName = "Hollowstem",
    tier = "Uncommon",
    description = "Tall and reedy with a hollow stalk that whistles in wind.",
    baseSellPrice = 16,
    growthTimeSeconds = 210,
    substratePref = { "peat" },
    yieldBySubstrate = {
        peat = 1.0, compost = 0.3, magical_loam = 0.9,
        hardwood = 0.0, straw = 0.0, dung = 0.0,
    },
    lightPref = "dappled",
    moisturePref = 0.75,
    pHPref = 5.5,
    rareVariantId = "Dewfern",
    brewingTags = {},
},
```

### Rare (3 species)

```lua
{
    id = "Glowmoss",
    displayName = "Glowmoss",
    tier = "Rare",
    description = "Bioluminescent. Casts soft green light at night — a player's first 'wow'.",
    baseSellPrice = 50,
    growthTimeSeconds = 480,
    substratePref = { "peat" },
    yieldBySubstrate = {
        peat = 1.0, magical_loam = 0.8,
        compost = 0.0, hardwood = 0.0, straw = 0.0, dung = 0.0,
    },
    lightPref = "dark",
    moisturePref = 0.8,
    pHPref = 5.5,
    rareVariantId = "CrystalCap",
    brewingTags = {},
},
{
    id = "Dewfern",
    displayName = "Dewfern",
    tier = "Rare",
    description = "Fern-like fronds, perpetually beaded with water. Used in cooling potions.",
    baseSellPrice = 45,
    growthTimeSeconds = 420,
    substratePref = { "peat" },
    yieldBySubstrate = {
        peat = 1.0, magical_loam = 0.8,
        compost = 0.0, hardwood = 0.0, straw = 0.0, dung = 0.0,
    },
    lightPref = "dappled",
    moisturePref = 0.9,
    pHPref = 6.0,
    rareVariantId = "CrystalCap",
    brewingTags = {},
},
{
    id = "Whisperbloom",
    displayName = "Whisperbloom",
    tier = "Rare",
    description = "Said to faintly murmur at dusk. Brewers swear it improves recipe luck.",
    baseSellPrice = 60,
    growthTimeSeconds = 540,
    substratePref = { "magical_loam" },
    yieldBySubstrate = {
        magical_loam = 1.0,
        compost = 0.0, hardwood = 0.0, straw = 0.0, dung = 0.0, peat = 0.4,
    },
    lightPref = "dappled",
    moisturePref = 0.6,
    pHPref = 6.5,
    rareVariantId = "CrystalCap",
    brewingTags = {},
},
```

### Epic (1 species)

```lua
{
    id = "CrystalCap",
    displayName = "Crystal Cap",
    tier = "Epic",
    description = "Translucent quartz-like cap. Refracts sunbeams into rainbows on the forest floor.",
    baseSellPrice = 200,
    growthTimeSeconds = 900,
    substratePref = { "magical_loam" },
    yieldBySubstrate = {
        magical_loam = 1.0,
        compost = 0.0, hardwood = 0.0, straw = 0.0, dung = 0.0, peat = 0.0,
    },
    lightPref = "sunny",
    moisturePref = 0.4,
    pHPref = 6.0,
    rareVariantId = nil,    -- no Legendary in Pre-Alpha
    brewingTags = {},
},
```

---

## Validation rules

These rules belong in `Tests/SpeciesSpec.lua` and should be enforced on every CI run:

1. Every species id is unique.
2. Every species' tier is one of `Common`, `Uncommon`, `Rare`, `Epic`, `Legendary`, `Mythic`.
3. Every species' `yieldBySubstrate` has at least one key with value > 0 (otherwise the species is unplantable, which is a data bug).
4. Every key in `yieldBySubstrate` matches a substrate id in `Constants.SUBSTRATES`.
5. Every value in `yieldBySubstrate` is in the range `[0.0, 2.0]` — exceeding 2.0 breaks rare-chance balance.
6. `rareVariantId`, when not nil, references an existing species id.
7. `rareVariantId`, when not nil, references a species one tier above this one (Common → Uncommon, etc.).
8. `baseSellPrice > 0` and `growthTimeSeconds > 0`.
9. `substratePref` is informational only (UI hint); every entry must appear in `yieldBySubstrate` with value >= 1.0.

---

## Notes for whoever's adding species

- Rare-variant connections are flavor-driven. BrownCap (Common, woody) → LatticeVeil (Uncommon, woody). Pick targets with thematic continuity, not random tier-above species.
- Magical loam yields 1.0–1.2 for Commons (slight bonus), 0.8–0.9 for Uncommons (penalty), 0.8 for Rares (penalty), 1.0 for Epics (only viable). This curve is what makes loam progression-relevant.
- Strict species (Rares and Epics) accept 1–2 substrates max. Don't add a fourth substrate option to a Rare to "make it more flexible" — strictness IS the depth.
- New species with fewer than 4 viable substrates feel "specialized." Most Commons should have 4+ viable substrates; Uncommons 2–3; Rares 1–2; Epics 1.
