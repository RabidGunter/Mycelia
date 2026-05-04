# Decisions (synthesized from ADRs)

All four decisions below are **LOCKED** (Accepted, immutable). Source ADRs are immutable per `docs/CONTRIBUTING.md`; supersession requires a new numbered ADR.

---

## DECISION-001: Biome Architecture — Single-Place Zones

- **source:** docs/decisions/001-biome-architecture.md
- **status:** locked (Accepted 2026-05-01)
- **scope:** biomes, MapSetup, WildSpawn, Travel NPC, TeleportService usage, StreamingEnabled, foraging expeditions, hut visiting, cross-biome events
- **decision statement:** Biomes are zones within a single Roblox Place. Travel between biomes uses CFrame teleport (HumanoidRootPart re-anchor), never `TeleportService`. `TeleportService` is reserved exclusively for ephemeral instanced content — foraging expeditions (Phase 2) and possibly limited-time event biomes.
- **rationale:** Trading economy depends on social density; multi-Place collapses density and adds cross-place data races. All comparable long-lived Roblox economy games (Bee Swarm Simulator, Adopt Me, Theme Park Tycoon 2, Grow a Garden) use single-place. `StreamingEnabled` solves the client-memory concern.
- **implementation contract:** Biomes laid out 1000–2000 studs apart; `Workspace.StreamingEnabled = true` with `StreamingMinRadius=256`/`StreamingTargetRadius=1024`; per-zone atmosphere/lighting tweened client-side on Region3 enter; per-biome `WildSpawnArea` Parts; cross-biome events via server-side BindableEvents.
- **override criteria:** Specific biome needs radically different physics/rendering; concurrent player count exceeds 100 at one biome; one biome becomes effectively a separate game.

---

## DECISION-002: Cultivation Yield + Rare-Variant Formula

- **source:** docs/decisions/002-cultivation-yield-formula.md
- **status:** locked (Accepted 2026-05-01)
- **scope:** cultivation, yield formula, substrate compatibility, rare-variant chance, growth-time formula, plot state machine, magical loam, Species data, Constants.CULTIVATION, Planting, Harvesting
- **decision statement:**
  1. Per-species `yieldBySubstrate` table is the substrate-compatibility data shape. Each (species, substrate) declares an explicit non-negative multiplier (typical range 0–1.5).
  2. Cultivation yield = `max(1, floor(baseYield × yieldBySubstrate × moistureMult × lightMult × pHMult × hostTreeMult × companionMult × playerBonusMult))`. Substrate is the only HARD failure variable (multiplier 0 → plot Failed). Yield capped at 5; excess flows to rare-variant chance.
  3. Growth-time formula is **decoupled from substrate** — `ripeTime = species.growthTimeSeconds × Constants.CULTIVATION.growthTimeMultiplier × playerActiveGrowthPotionMultiplier`. Substrate affects yield only.
  4. Rare-variant chance per yielded mushroom = `baseRareChance + substrate_match_excess × bonus + magicalLoamRareBonus + other_excesses × bonus + potion_luck`, capped at `maxRareChance` (10%).
  5. Plot state machine adds `Failed` state. Substrate consumed at plant time regardless of outcome. Yield resolved at ripen check, not at harvest (Failed plots never enter Ripe).
  6. `playerBonusMultiplier` aggregates ALL same-kind bonus sources additively (`1 + PotionEffects.get(player, kind) + PassiveBonuses.get(player, kind) + ...`) — source-agnostic.
- **constants additions (locked names):** `Constants.CULTIVATION.{baseYield, maxYield, baseRareChance, maxRareChance, substrateMatchExcessRareBonus, magicalLoamRareBonus, otherMultiplierExcessRareBonus, failedDisplaySeconds}`; `Constants.SUBSTRATES` (6 substrates).
- **override criteria:** players complete full Pokedex in <50h, can't get past Tier 2, magical loam unused or sole choice, plot failures feel punitive (try refund-on-fail before formula change).

---

## DECISION-003: Reputation Rates and Tiers

- **source:** docs/decisions/003-reputation-rates.md
- **status:** locked (Accepted 2026-05-01)
- **scope:** reputation system, per-NPC reputation, total renown, friendship tiers, biome unlock thresholds, diminishing returns, Reputation.lua, Constants.REPUTATION, Constants.BIOME_UNLOCK_RENOWN, save schema v3 reputation extension, NPC dialogue UI, player profile UI
- **decision statement:** Two-layer reputation model:
  1. **Per-NPC rep** (`data.reputation[npcId].score`) caps at 5000. Five friendship tiers: Acquaintance (0–99) · Familiar (100–499) · Friend (500–1499) · Trusted (1500–4999) · Confidant (5000). Per-NPC rep gates NPC-specific content (shop tiers, story arcs, Confidant unique reward).
  2. **Total renown** (sum across all NPCs) gates biome unlocks. Thresholds: StarterGlade 0 · MistyHollow 100 · FrostrootPass 300 · SunkenGrove 600 · OldGrowth 1500 · Glimmerwood 2500+lunar quest · LostCathedral event-based.
  3. **Decelerating gain curve:** 1.0× rate at 0–999, 0.5× at 1000–2999, 0.25× at 3000–4999, 0× at cap.
- **gain sources (locked rates):** tutorialQuest +15 · dailyQuest +5 · storyQuestSmall +25 · storyQuestMedium +75 · storyQuestMajor +200 · sell/buy 1 per 200 coins · dailyGreeting +1 · storyMilestone +500.
- **api contract:** `Reputation.add(player, npcId, rawAmount)` is the only mutator path. `Reputation.tier(score)`, `Reputation.totalRenown(player)`, `Reputation.canAccess(player, gate)` are read helpers.
- **override criteria:** tutorial doesn't reach Misty Hollow, Old Growth unlocked too fast (<5h), Confidant reached too quickly across most NPCs, specialists feel forced to generalize.

---

## DECISION-004: Coin Economy Floor and Ceiling

- **source:** docs/decisions/004-coin-economy.md
- **status:** locked (Accepted 2026-05-01)
- **scope:** coin economy, wealth tiers, anti-exploit hard cap, audit log thresholds, substrate costs, plant costs, stall rent, inflation control, Constants.ECONOMY, Coins.add server guard
- **decision statement:**
  1. **Earning curve targets ~10× wealth per 5× hours played.** Realistic player ceiling 10M; whale tier 10M–100M; suspicious 100M+; hard cap 10B.
  2. **Three-layer anti-exploit defense:** server refuses any `Coins.add` that would push balance past 10B (hard cap); rejects any single-tick gain >10M; logs gains ≥1M to audit DataStore.
  3. **NPC prices are fixed forever.** Wealth growth comes from rarity-of-output, not price-inflation-of-output. Player-to-player trading is the only floating-price market and self-balances.
  4. **`Coins.add` is the single chokepoint.** All coin gains route through it; no direct `data.coins += x` writes elsewhere.
- **constants (locked names + values):** `Constants.ECONOMY.{startingCoins=25, coinHardCap=10_000_000_000, coinSuspiciousThreshold=100_000_000, singleTickGainSuspicious=1_000_000, singleTickGainHardReject=10_000_000}`. Wealth-tier table at `Constants.WEALTH_TIERS`.
- **starter prices (locked references):** Compost/Hardwood/Straw/Dung 5c · Peat 25c · Magical Loam 200c. Plant costs by tier: Common 10 / Uncommon 50 / Rare 250 / Epic 1500 / Legendary 7500. Trading stall rent 1000/day.
- **note (cross-spec dependency):** The original ADR cites `Constants.ECONOMY.witchPriceMultiplier` as the witch tuning lever. The Shop UI spec (docs/specs/shop-ui.md) has migrated this to `Constants.MERCHANTS.ForestWitch.buyMultiplier`. Same lever, renamed. ADR 004's principle (NPC prices stable) is preserved. See INGEST-CONFLICTS.md INFO bucket.
- **rejected alternatives:** Inflating NPC prices over time (kills trading economies — Pet Simulator anti-pattern); lower hard cap (less headroom for whales); no hard cap (integer overflow risk); dynamic stall rent (fairness-illusion punish for engaged players).
- **override criteria:** Whale tier reached by hour 200 typical; suspicious tier exceeds 1% of long-term players; trading-post median rare price >10× witch (witch underpaying); new players can't afford second plant.
