# Mycelia — Decision: Coin Economy Floor and Ceiling

**Status:** RESOLVED 2026-05-01
**Decision:** Anti-exploit hard cap at 10 billion. Realistic player wealth ceiling at 10 million. Earning curve scales roughly 10× per 5× play hours. NPC prices fixed in absolute coins; player-to-player trading is the only inflation vector and self-balances.

Resolves open question #5 from the [ROADMAP](../ROADMAP.md).

---

## The question

What's a healthy coin economy across the player progression curve? Specifically:

- What's the realistic earning rate per hour at hour 1, hour 10, hour 100, hour 1000?
- What's the realistic wealth ceiling for a "rich" player vs. a "whale" outlier?
- What's the anti-exploit hard cap, and where do the sanity-flag thresholds sit relative to it?
- How do we prevent inflation as players accumulate?

These numbers anchor: plant costs, substrate costs, NPC item prices, stall rental fees, sanity-check thresholds, and the Coin Pack dev product sizing in Phase 3.

---

## The earning curve

Target progression: roughly **10× wealth growth per 5× hours played**, decelerating naturally as the player accumulates.

| Time played | Coins earned (cumulative) | Notes |
|---|---|---|
| Hour 1 | ~400 | Starting 25 + tutorial sells. Enough for several common plants. |
| Hour 5 | ~5,000 | Past Misty Hollow unlock. Uncommons in rotation. |
| Hour 20 | ~50,000 | Has access to mid-tier substrates. Cultivating Rares. |
| Hour 100 | ~500,000 | Established player. Epic plants comfortably affordable. |
| Hour 500 | ~5,000,000 | "Rich" tier. Running stalls, trading regularly. |
| Hour 1000 | ~10,000,000 | Practical wealth ceiling for solo earners. |
| Hour 1000+ | Trade-driven | Beyond 10M, wealth is mostly redistributed via player trading rather than NPC sells. |

Key insight: the curve flattens because **NPC sell prices are fixed**. A new player and a hour-1000 player both get the same base price from the witch. The hour-1000 player earns more by selling rarer mushrooms and operating stalls — not by inflating prices.

This is the design-doc-required protection against pay-to-win and against trading-economy collapse: NPC prices are a stable floor.

---

## The wealth tiers

| Tier | Coins held | What it represents | % of player base |
|---|---|---|---|
| New | 0 – 999 | First few hours. | 100% pass through |
| Settled | 1,000 – 99,999 | Comfortable mid-game. | Most active players |
| Rich | 100,000 – 9,999,999 | Established. Trades regularly. | ~10% of long-term players |
| Whale | 10,000,000 – 99,999,999 | Outlier. Known in community. Likely runs stalls. | <1% |
| Suspicious | 100,000,000 – 9,999,999,999 | Investigation-worthy. Audit-log review on every gain. | (any player here is flagged) |
| Hard cap | 10,000,000,000 | Server refuses gains past this. | Should never be reached legitimately. |

The "Suspicious" tier exists deliberately: it leaves room above realistic-whale wealth without throwing immediate exploit alarms. A legitimate trader hitting 100M is rare but possible. The audit-log review at that tier catches exploits without false-flagging legit traders.

---

## Hard cap and sanity thresholds

```lua
Constants.ECONOMY.coinHardCap                = 10_000_000_000   -- 10 billion
Constants.ECONOMY.coinSuspiciousThreshold    = 100_000_000      -- 100 million; flags account for review
Constants.ECONOMY.singleTickGainSuspicious   = 1_000_000        -- 1M coins gained in one tick = flag
Constants.ECONOMY.singleTickGainHardReject   = 10_000_000       -- 10M in one tick = reject the gain entirely
```

Three layers of defense:

1. **Hard cap** — server refuses any add that would push balance past 10B. Total stored value can't exceed this.
2. **Per-tick rejection** — server refuses any single coin gain over 10M (no legitimate operation produces this).
3. **Per-tick flag** — gains of 1M+ are logged to the audit DataStore for review, but allowed (some legit operations could produce this — e.g., selling a mass inventory of rares).

`Suspicious` tier (100M+ held) plus `singleTickGainSuspicious` (1M+ gain) layered together catches exploits at multiple stages.

---

## Spending guideposts

Reference prices for an internally-consistent economy. Tuned in `Constants.lua`; numbers below are starter values.

### Substrates (cost on plant)

| Substrate | Cost | Why this price |
|---|---|---|
| Compost | 5 | Cheap default. Hour-1 affordable. |
| Hardwood | 5 | Cheap; Uncommon-tier specialist. |
| Straw | 5 | Cheap; Uncommon-tier specialist. |
| Dung | 5 | Cheap; Uncommon-tier specialist. |
| Peat | 25 | Mid-tier; gates Rare cultivation. |
| Magical Loam | 200 | Premium; gates Epic cultivation. |

### Plant costs (per `Constants.CULTIVATION.plantCost` already in code)

| Tier | Cost |
|---|---|
| Common | 10 |
| Uncommon | 50 |
| Rare | 250 |
| Epic | 1,500 |
| Legendary | 7,500 |
| Mythic | n/a (event-spawned, not plantable) |

Total cost to grow one Epic = `1500 (plant) + 200 (loam) = 1700 coins`. At hour 100 (~500k coins held), this is 0.34% of bankroll per attempt. Tight enough that careful play matters; loose enough that Epic-cultivation experimentation is reasonable.

### Other recurring costs

| Item | Cost | Notes |
|---|---|---|
| Trading stall rent | 1,000 / day | Drain that scales with stall ownership. |
| Daily auto-renew if balance ≥ 1000 | (deducts above) | Prevents stall hoarding. |
| Spirit Food (cheap) | 20 / item | Used for spirit attraction. |
| Spirit Food (premium) | 200 / item | Higher attraction multiplier. |
| Decoration (cheap) | 50 / item | Hut decoration drop. |
| Decoration (premium) | 500 / item | Larger pieces. |
| Outfit (cheap NPC) | 1,000 | Cosmetic via Cosmetic Merchant. |

### Coin sinks vs faucets — balance check

**Faucets** (coins enter economy):
- Selling mushrooms to Forest Witch (primary).
- Quest rewards.
- Daily login bonus (small).

**Sinks** (coins leave economy):
- Plant costs (recurring).
- Substrate costs (recurring).
- Stall rent (recurring, large).
- One-time purchases (decorations, outfits, etc.).
- Failed brews (consumed ingredients = lost potential coin).

**Trades** (coins move within economy, no creation):
- Player-to-player trading. Self-balancing.

The economy needs sinks ≥ faucets for currency velocity. The big ongoing drain is stall rent (1000/day per stall, scales with stall count). New plant + substrate cost per harvest cycle is the minor ongoing drain.

A rough sense-check: a Rich player (1M coins) running 3 stalls costs 3000/day rent = 90k/month rent. They earn enough to cover it ~10x over via stall sales + cultivation. Stalls are a net positive operation for them — the rent is friction, not a barrier.

---

## Inflation control

Three mechanisms keep coin value stable across the lifetime of the game:

1. **NPC prices are fixed.** The Forest Witch never raises her buy price for BrownCap from 3 coins. Player wealth growth comes from selling RARER items, not from price inflation of common items.

2. **Substrate / plant costs are fixed.** A Common plant always costs 10 coins. A new player and a hour-1000 player pay the same.

3. **Trading is the only floating-price market.** Player-to-player trades set their own prices. Markets self-balance: if Glowmoss is over-supplied, market price drops; if rare, it rises. The trading-post audit log lets the design team monitor this and tune NPC buy prices upward only if a category becomes systemically under-valued.

Crucially: **resist the urge to scale NPC prices to "match player wealth."** That's the trap that kills trading-economy games (Pet Simulator's currency inflation). Mycelia's wealth growth comes from rarity-of-output, not price-inflation-of-output.

---

## Implementation notes

### Constants additions

```lua
Constants.ECONOMY = {
    startingCoins                   = 25,
    coinHardCap                     = 10_000_000_000,
    coinSuspiciousThreshold         = 100_000_000,
    singleTickGainSuspicious        = 1_000_000,
    singleTickGainHardReject        = 10_000_000,
    witchPriceMultiplier            = 1.0,    -- already exists
}

Constants.WEALTH_TIERS = {
    { name = "New",        min = 0 },
    { name = "Settled",    min = 1_000 },
    { name = "Rich",       min = 100_000 },
    { name = "Whale",      min = 10_000_000 },
    { name = "Suspicious", min = 100_000_000 },
}
```

### Server-side coin add guard

```lua
function Coins.add(player, amount, source)
    if amount > Constants.ECONOMY.singleTickGainHardReject then
        return false, "rejected: single-tick gain too large"
    end
    if amount > Constants.ECONOMY.singleTickGainSuspicious then
        AuditLog.write({ kind = "suspicious_gain", player, amount, source })
    end
    local new = data.coins + amount
    if new > Constants.ECONOMY.coinHardCap then
        return false, "rejected: would exceed hard cap"
    end
    data.coins = new
    return true
end
```

`Coins.add` becomes the single chokepoint. Every coin increase — sells, quest rewards, daily bonus, dev-product purchases — funnels through it. No direct `data.coins += x` writes anywhere else in the codebase.

### Audit log entries

Every coin gain over 1M, every coin balance hitting Suspicious tier, and every dev-product purchase get logged to a separate `MyceliaAuditLog_v1` DataStore with: timestamp, userId, amount, source, resulting balance.

### Tests (`Tests/CoinEconomySpec.lua`)

- Hard cap enforcement on add.
- Single-tick rejection on gains > 10M.
- Suspicious flag fires on gains ≥ 1M without rejecting.
- Wealth tier lookup matches thresholds.
- New player at hour 1 can plausibly afford an Uncommon plant by sell-and-replant.

---

## When the alternative IS appropriate

**Inflating NPC prices over time:** rejected. This is the documented anti-pattern that destroys trading economies (Pet Simulator's runaway inflation). Don't.

**Lower hard cap (e.g., 1B instead of 10B):** the lower the cap, the higher the chance a legitimate whale/trader hits it. 10B has 1000× headroom over realistic max — that's the right ratio for an anti-exploit ceiling.

**No hard cap, just sanity flags:** rejected. Without a cap, an integer-overflow exploit (32-bit overflow at ~2B; 64-bit overflow at ~9.2 quintillion) is a real risk. Hard cap closes the door.

**Dynamic stall rent (scales with player wealth):** rejected for the same reason as price inflation — it's a fairness illusion that punishes engaged players.

---

## Override criteria

Revisit if:

- Whale tier (10M+) is reached by hour 200 by typical players → tighten earning curve, raise stall rent, consider increasing premium-substrate costs.
- Suspicious tier hits more than 1% of long-term players → raise threshold.
- Trading post markets have median rare-mushroom price > 10× witch price → witch underpaying; tune `witchPriceMultiplier` upward (don't tune species `baseSellPrice` — that's content data).
- New players consistently can't afford their second plant after hour 1 → either lower starting plant cost or raise tutorial sell rewards.

Tunables live in `Constants.ECONOMY` and `Constants.CULTIVATION.plantCost`. Only the inflation-control philosophy is locked here.

---

*Marked resolved in [../ROADMAP.md](../ROADMAP.md).*
