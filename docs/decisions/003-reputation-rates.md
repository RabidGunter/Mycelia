# Mycelia — Decision: Reputation Rates and Tiers

**Status:** RESOLVED 2026-05-01
**Decision:** Per-NPC rep cap 5000, five named friendship tiers, decelerating gain curve. Total renown (sum across NPCs) gates biome unlocks. Per-NPC rep gates NPC-specific content.

Resolves open question #3 from the [ROADMAP](../ROADMAP.md).

---

## The question

How fast does reputation accumulate, and how does it gate progression? Specifically:

- What's the per-NPC rep cap and how is it earned?
- Do biome unlocks gate on per-NPC rep or on total renown?
- What gain rates make biome unlock 1 (Misty Hollow at rep 100) feel "post-tutorial" and biome unlock 5 (Glimmerwood at rep 2500) feel "deep mid-game"?
- Are there friendship tiers, and what do they unlock?

Without concrete numbers here, the quest reward design and the merchant config in Phase 2 stalls — every quest needs a rep value, every merchant needs to know what their preferred sells are worth.

---

## Two-layer reputation model

**Per-NPC reputation** (`data.reputation[npcId]`) — earned from interactions with that specific NPC. Caps at 5000. Gates NPC-specific content (advanced shop items, late-storyline quests, "friend" perks).

**Total renown** (computed: `sum(data.reputation)`) — sum across all NPCs. Gates biome unlocks. Rises naturally as the player engages with several NPCs.

The two-layer split rewards both styles of player:
- **Specialist** who picks one or two NPCs to "main" — high per-NPC rep, unlocks deep storylines and shop tiers there.
- **Generalist** who interacts with everyone — high total renown, unlocks biomes faster than the specialist would.

Neither path is gated out of the other. A specialist eventually has enough total renown for all biomes; a generalist eventually has enough per-NPC rep for advanced NPC content.

---

## Friendship tiers (per-NPC)

Same scale used for every NPC:

| Tier | Per-NPC rep | Unlocks |
|---|---|---|
| Acquaintance | 0–99 | Default. Basic dialogue, basic shop. |
| Familiar | 100–499 | NPC remembers your name in dialogue. First-tier story quest unlocked. |
| Friend | 500–1499 | Daily greeting bonus. Mid-tier shop items. Second-tier story quest. |
| Trusted | 1500–4999 | Discount on this NPC's shop (10%). Late storyline quests. Special-occasion dialogue. |
| Confidant | 5000 (cap) | NPC offers a unique reward (e.g., the Forest Witch's signature potion recipe). Unique cosmetic. |

Cosmetic / dialogue benefits per tier are the visible feedback; mechanical benefits (shop discounts, exclusive items) are the optimization rewards.

---

## Reputation gain rates

| Source | Rep gained | Notes |
|---|---|---|
| Tutorial quest (Gardener Coach only) | +15 each | Five tutorial quests = +75 to Gardener Coach. |
| Daily quest from any NPC | +5 | Refreshes daily. Small but consistent. |
| NPC story quest — small | +25 | Single-step quests. |
| NPC story quest — medium | +75 | Multi-step. Usually 30+ minutes of play. |
| NPC story quest — major | +200 | Multi-session storyline. Usually unlocks a biome or grants a unique item. |
| Selling preferred-category items | +1 per 200 coins of value | Witch buys mushrooms; preferred-category logic per merchant. |
| Buying from NPC | +1 per 200 coins spent | Encourages investment in the NPC. |
| Daily greeting | +1 per real-world day | Walk up + Talk + Continue. Once per day per NPC. Floor for inactive players. |
| Story milestone (rare) | +500 | Reserved for major beats — saving a spirit, completing a multi-NPC questline. |

Gain rate intentionally front-loaded: a new player completing the tutorial earns 75 rep with Gardener Coach immediately, plus another 25–50 from incidental sells, putting them near or past Misty Hollow's 100-renown unlock.

---

## Diminishing returns

To prevent burn-through past the Confidant tier and to preserve reaching cap as a milestone:

| Per-NPC rep range | Gain multiplier |
|---|---|
| 0 – 999 | 1.0× (full rate) |
| 1000 – 2999 | 0.5× (half rate) |
| 3000 – 4999 | 0.25× (quarter rate) |
| 5000 (cap) | 0× (no further gain to that NPC) |

Sell-rep, buy-rep, and quest-rep all respect this curve. Means hitting Confidant with one NPC takes deliberate effort across many sessions — not something a one-day grind achieves.

Concrete sense-check: a player generating +30 rep/hr from sells alone gets:
- 0 → 1000 in ~33 hours (full rate)
- 1000 → 3000 in ~133 hours (half rate)
- 3000 → 5000 in ~267 hours (quarter rate)
- Total to cap one NPC: ~430 hours

That's deliberately a lot — Confidant is supposed to feel earned. A specialist who focuses on one NPC reaches Confidant in roughly 200 hours of focused play (helped by quest rep stacking with sell rep).

---

## Biome unlock thresholds (total renown)

Recap from PDF, with rationale:

| Biome | Total renown required | Rationale |
|---|---|---|
| Starter Glade | 0 | Default. |
| Misty Hollow | 100 | Post-tutorial reachable. ~1–2 hours of play. |
| Frostroot Pass | 300 | A few story quests deep. ~5 hours. |
| Sunken Grove | 600 | Substantial play across several NPCs. ~12 hours. |
| Old Growth | 1500 | Mid-game. ~30 hours. |
| Glimmerwood | 2500 + lunar quest | Late-game. ~60 hours plus a specific quest milestone. |
| Lost Cathedral | Event-based | No rep gate; participation-locked during community events. |

**Why total renown for biomes (not per-NPC):** biomes are platform-level progression and shouldn't be locked behind one specific NPC relationship. A player who specializes in the Witch shouldn't be blocked from Frostroot Pass because they ignored the Old Hermit. Total renown rewards engagement across the whole world.

---

## Per-NPC rep gates for content

These are NPC-specific gates, complementing total-renown biome gates:

| Gate | Per-NPC rep needed | Example |
|---|---|---|
| Mid-tier shop unlocks | 500 (Friend) | Witch sells better substrates after Friend status. |
| Story arc 1 quest available | 100 (Familiar) | First story quest from each NPC. |
| Story arc 2 quest available | 500 (Friend) | Second-tier story; unlocks usually a recipe or rare seed. |
| Story arc 3 quest available | 1500 (Trusted) | Multi-session arc. Often unlocks a biome via the major quest reward. |
| Confidant reward | 5000 (Confidant) | Each NPC has a signature unique item. |

Quest-availability gates check per-NPC rep at the time of NPC dialogue, not at quest journal load time — keeps the journal honest about what's actually offered.

---

## Implementation notes

### Save schema (extends v3)

```lua
data.reputation = {
    [npcId] = {
        score = 0,           -- 0..5000
        firstMet = 0,        -- timestamp; for "we've known each other" UI
        lastDailyGreeting = 0, -- timestamp; rate-limit daily greeting bonus
    },
    -- ...
}
```

`Constants.NPCS` provides the npcId → display name + role mapping.

### Helper functions (`Reputation.lua`, new module)

```lua
-- Apply gain with diminishing returns + cap.
function Reputation.add(player, npcId, rawAmount)
function Reputation.tier(score) -> "Acquaintance" | "Familiar" | ...
function Reputation.totalRenown(player) -> number
function Reputation.canAccess(player, gate) -> boolean
```

`Reputation.add` is the only mutator path — every rep-affecting event funnels through it, applies diminishing-returns curve, clamps to cap, fires `ReputationChanged` to the client for HUD/profile updates.

### Constants additions

```lua
Constants.REPUTATION = {
    perNPCCap = 5000,
    diminishingReturnsThresholds = { 1000, 3000 },
    diminishingReturnsMultipliers = { 1.0, 0.5, 0.25 },
    sources = {
        tutorialQuest = 15,
        dailyQuest = 5,
        storyQuestSmall = 25,
        storyQuestMedium = 75,
        storyQuestMajor = 200,
        sellPerCoinRatio = 1 / 200,
        buyPerCoinRatio = 1 / 200,
        dailyGreeting = 1,
        storyMilestone = 500,
    },
    tiers = {
        { name = "Acquaintance", min = 0 },
        { name = "Familiar",     min = 100 },
        { name = "Friend",       min = 500 },
        { name = "Trusted",      min = 1500 },
        { name = "Confidant",    min = 5000 },
    },
}

Constants.BIOME_UNLOCK_RENOWN = {
    StarterGlade   = 0,
    MistyHollow    = 100,
    FrostrootPass  = 300,
    SunkenGrove    = 600,
    OldGrowth      = 1500,
    Glimmerwood    = 2500,    -- plus lunar quest flag
    LostCathedral  = math.huge,  -- gated by event participation, not rep
}
```

### Tests (`Tests/ReputationSpec.lua`)

- Gain applies diminishing returns at correct thresholds.
- Cap is hard — no gain past 5000.
- Tier lookup matches thresholds.
- Total renown is sum across all entries.
- Daily greeting bonus respects 24-hour window.
- canAccess gates correctly for both renown and per-NPC checks.

### UI surfaces

- **Player profile** shows: total renown number, per-NPC rep bars colored by tier.
- **NPC dialogue** shows current tier as a small label under their name. Tier-up triggers a small "+" animation when the dialogue closes.
- **Biome travel UI** shows locked biomes with their renown threshold ("Reach 300 renown to unlock").

---

## When the alternative IS appropriate

**Single-layer (per-NPC only, no separate total renown):** rejected because biome gates would force specialists to interact with NPCs they don't care about. Two-layer model is strictly more flexible.

**Total-renown only (no per-NPC tracking):** rejected because it loses the "loyalty rewarded" dimension. NPCs feel interchangeable and the world feels flat.

**Per-NPC caps higher than 5000:** would extend the post-Confidant grind indefinitely. Cap should feel achievable for a dedicated player without becoming busywork. 5000 with the diminishing-returns curve hits both targets.

---

## Override criteria

Revisit if:

- Players consistently complete the tutorial and don't feel "ready for Misty Hollow" → lower the 100-renown threshold or raise tutorial-quest rep.
- Old Growth (1500) ends up being unlocked at hour 5 via a single lucky storyline → tighten the diminishing-returns curve at 1000.
- Confidant tier ends up reached by hour 50 across most NPCs → raise per-NPC cap to 7500 or steepen the diminishing-returns curve.
- Specialists feel they "have to" generalize for biome unlocks → lower biome thresholds OR provide a per-NPC bonus path to renown (e.g., Confidant gives +500 bonus renown).

Tunable values live in `Constants.REPUTATION` and `Constants.BIOME_UNLOCK_RENOWN`. Only the two-layer model is locked structurally here.

---

*Marked resolved in [../ROADMAP.md](../ROADMAP.md).*
