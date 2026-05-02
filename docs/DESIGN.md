# Mushroom Forest — Roblox Game Design Document

**Working Title:** *Mycelia* (placeholder — see naming section at end)

**Genre:** Cozy life-sim with hidden depth (Bee Swarm Simulator lineage)

**Target Session:** 5-15 minutes for casual, 60+ minutes for engaged players. Daily check-in habit.

**Platform Priority:** Mobile-first. PC and console secondary.

**Target Audience:** Primary 9-16, but designed to retain players into adulthood like Bee Swarm does.

---

## Core Vision Statement

A cozy mushroom-cultivation game set in an enchanted forest, where simple harvesting in your first hour gradually reveals a 200-hour optimization puzzle, a player-driven trading economy, and a collection ceiling that grows with the game. Built to feel like Stardew Valley's quiet moments wrapped around Bee Swarm Simulator's depth, with a player-to-player potion economy as the long-term retention engine.

---

## The Core Loop (The Five-Minute Version)

A new player should experience this loop within their first 5 minutes:

1. **Walk** into a misty starter glade. Glowing spots on the ground mark wild mushrooms.
2. **Harvest** their first mushrooms with a tap (no tool required).
3. **Sell** mushrooms at the Forest Witch's stall for coins, OR drop them in the cauldron to learn what they do.
4. **Plant** a Spore Patch in the starter glade with their coins.
5. **Wait** a minute, harvest again, but this time more mushrooms grew because they planted intentionally.

That five-minute loop is the entire game. Everything else is depth layered on top.

---

## The Long Loop (The 200-Hour Version)

The same loop scales up like this:

- **Harvest** becomes 12 different biomes with seasonal rotations
- **Sell** becomes a player-driven trading post with potion auctions
- **Plant** becomes substrate optimization, pH balancing, host-tree pairing, mycelium networks
- **Wait** becomes time-based recipe discovery and lunar growth cycles
- **And** then there's brewing, foraging expeditions, forest spirits, and recipe research

This layered design is what makes Bee Swarm last. New players see "plant mushroom, get money." Veterans see a logistics puzzle.

---

## Game Systems

### 1. The Mushroom Collection (the "Pokedex")

**Launch with 60 species across 6 rarity tiers.** Plan for 200+ at maturity.

| Tier | Examples | How Obtained |
|------|----------|--------------|
| Common | Brown Cap, Spotted Toadstool, Fairy Cup | Grow anywhere |
| Uncommon | Lattice Veil, Inkpot, Coral Tongue | Specific substrate |
| Rare | Glowmoss, Dewfern, Whisperbloom | Biome-specific + conditions |
| Epic | Crystal Cap, Auroracap, Frostling | Weather + season + biome |
| Legendary | Starseed, Heartwood, Voidcap | Lunar cycle + recipe discovery |
| Mythic | The Old One, Eternal Bloom | Community-discovered events |

**Why six tiers:** Adopt Me has roughly this rarity structure. It gives free players progression (commons through rares) and gives whales/grinders something to chase (epics through mythics).

**Visual design rule:** every mushroom must look distinct from a thumbnail-sized icon. This matters massively for trading UI later.

### 2. Cultivation Mechanics

This is the depth layer. Bee Swarm's secret is that the optimization is real, not fake.

**Variables that affect what grows:**
- **Substrate type** (compost, hardwood, straw, dung, peat, magical loam) — unlocked over time
- **Moisture level** — set by watering, affected by rain
- **Light level** — sunny, dappled, dark
- **Host tree** — some species only fruit near specific trees
- **Soil pH** — adjusted with additives
- **Companion mushrooms** — some species boost others, some inhibit

A new player just plants and harvests. A veteran is balancing 6 variables to grow specific rare hybrids. **Optimization can take hundreds of hours to master and still leave room for community-discovered builds.**

### 3. The Brewing System (this is the secret weapon)

Mushrooms are ingredients. The cauldron at your hut lets you brew **potions**.

**Mechanic:** Drop 1-5 mushrooms in the cauldron, choose a brewing method (steep, boil, ferment, dry-grind), wait. Potion appears. Effect is determined by which mushrooms + which method.

**Recipes are not given to players.** They're discovered. This is critical.

**Why this matters:**
- A player who discovers a great recipe has something other players want
- Player communities will share or hoard recipes — both build engagement
- The recipe space is combinatorial — with 60 mushrooms × 4 methods × 1-5 ingredient combos, there are *thousands* of possible recipes. Some are duds. Some are valuable. Discovery has long legs.
- Wikis, Discord servers, YouTube guide channels grow up around recipe discovery. This is *exactly* what Bee Swarm has, and it's why it lasts.

**Potion effect categories:**
- **Buffs** — speed, harvest yield, luck (rare drop chance), drying time
- **Tools** — see hidden mushrooms, reveal map areas, attract spirits
- **Cosmetic** — temporary glow effects, color changes, particle trails (these are tradeable status items)
- **Forest interaction** — rain summons, day/night control on private plots, season shifts

### 4. The Trading Post (the longevity engine)

This is where this game becomes a 7-year game instead of a 1-year game.

**Players can trade:**
- Mushrooms (raw and dried)
- Potions (with their discovered effects)
- Spores (seeds for specific species)
- Recipes (a one-time-use scroll they can sell)
- Cosmetic items
- Forest spirits (see next system)

**The trading post is a physical place** in the game (not just a menu) where players gather, browse stalls, and negotiate. Spatial Voice integration here from day one.

**Player-run shops:** at higher levels, players can rent stalls and run their own shops with auto-pricing or auction formats. This is the Adopt Me lesson — players generating value for each other.

**Critical design rule:** never let real-money purchases bypass the trading economy. Premium players should buy *time* and *cosmetics*, never tradeable rare items directly. Pay-to-win kills trading economies fast.

### 5. Forest Spirits (the pet/companion layer)

Specific mushrooms attract specific Forest Spirits — small creature companions that wander your plot and grant passive bonuses.

- Common spirits: Mossling, Spritefly, Dewdrop
- Rare spirits: Lanternfox, Crystalmoth, Deerlet
- Legendary spirits: Forest Mother (a once-per-server spawn during lunar events)

**Spirits are tradeable**, which makes them function like the pets in Adopt Me. They generate emotional attachment, drive collection completion, and are the single most valuable trading currency.

Spirits also offer mechanical bonuses (faster growth, rare seed drops, weather control), so they're not pure cosmetics — but the cosmetic appeal is what drives the whale spend.

### 6. Biomes and Foraging Expeditions

Players start in the **Starter Glade**. Over time they unlock:

- **Misty Hollow** (rainforest aesthetic, water-loving species)
- **Frostroot Pass** (snowy, slow-growing but high-value species)
- **Sunken Grove** (swamp, weird textures, alchemy ingredients)
- **Old Growth** (ancient forest, requires reputation to enter, legendary species)
- **The Glimmerwood** (bioluminescent, only at night, lunar mechanics)
- **Lost Cathedral** (ruined temple in the woods, mythic spawns during events)

Each biome has its own substrate types, weather patterns, and exclusive species. Travel between biomes is a meaningful unlock that gates progression naturally.

**Foraging Expeditions** are co-op runs into deeper biomes (2-4 players). Time-limited, slightly dangerous (you can lose unfinished potions if you fail), high reward. **This is the social hook that drives the algorithm — players invite friends.**

### 7. Seasons and Lunar Cycles

Real-time season cycle (each season = one real-world week, so 4 weeks = 1 game year). Different mushrooms fruit in different seasons. Some legendary species only appear in specific moon phases.

**Why this matters for retention:** if a player wants the rare autumn mushroom, they have to *be there in autumn*. This is a daily check-in pressure that doesn't feel coercive — it feels like the world has rhythm.

### 8. Quest System (the onboarding scaffold)

The Forest Witch (NPC tutorial guide) gives quests for the first ~10 hours. After that, quest-givers become other forest characters with their own stories — the Old Hermit, the Wandering Alchemist, the Spirit Speaker.

**Quests reward recipes, biome unlocks, rare seeds, and reputation.** They're never required for progression but they teach mechanics smoothly.

---

## Progression Curve

Designed for retention waves at specific timestamps:

- **Hour 1:** Discover the core loop. Plant first patch. Discover first potion accidentally.
- **Hour 5:** Unlock second biome. Realize there are species you can't grow yet. Trade with first other player.
- **Hour 20:** Discover that recipes have deep effects. Start hunting specific ingredients.
- **Hour 50:** Reach mid-tier rarity. Specialize in a brewing style. Join a Discord/community to discuss recipes.
- **Hour 100:** Have a "build" — a specific way you play. Are known in the trading post for something.
- **Hour 500:** Hunting mythics. Possibly running a stall. Helping new players. Game has become a place, not a game.

**No level cap. No prestige. The game ends when you've collected everything, and the dev's job is to make sure that horizon keeps moving.**

---

## Monetization Plan

This is the most important section. Get this wrong and the game dies in year 2 even if everything else is right.

### Robux Game Pass Items (one-time purchases)

- **Bigger Plot** — more space to plant. Convenience, not power.
- **Auto-Harvester** — passively gathers ripe mushrooms while offline. Quality of life.
- **Recipe Journal Plus** — better organization for discovered recipes. UI convenience.
- **Cosmetic outfits** — for your character.
- **House upgrades** — bigger hut, decoration tools.

### Robux Direct Purchases (consumables)

- **Coin packs** — small acceleration, but never enough to skip progression
- **Speed-up potions** — 30 minutes of faster growth. Time, not power.
- **Cosmetic spirit skins** — pure visual variants.

### What to Never Sell

- Rare mushrooms or spores directly
- Spirits directly (only spirit *food* that increases attraction chance)
- Recipes
- Trading advantages

### Why This Works Long-Term

Adopt Me's monetization is essentially this model. Pet Simulator 99 leans more pay-to-win and consequently has shorter player lifecycles. Bee Swarm Simulator is even more conservative — almost everything is grindable — and it's been alive for 7 years.

**The model:** sell *time* and *cosmetics*, never *power* or *rarity*. Players will spend on a game they trust forever; they'll spend once on a game that nickel-and-dimes them.

### Realistic Revenue Expectations

- Top 1% of Roblox games earn $1M+ per year
- A successful long-term cozy game in this lane (Bee Swarm tier) could realistically clear $100k-500k/year for a small team
- Don't optimize for first-month revenue. Optimize for Year 2 retention. The math works out massively in your favor.

---

## LiveOps Calendar (the retention engine)

Static games die. Schedule from launch:

- **Daily:** Login bonus, daily quest from the Forest Witch
- **Weekly:** Limited-time mushroom species in rotation, weekly event in one biome
- **Monthly:** Major event with mythic spawns, new spirit released, new recipe ingredients introduced
- **Seasonal (every 3 months):** New biome introduced, major story beat, exclusive cosmetic line

**Plan for at least one major event per month from launch.** This is the workload reality of running a long-term Roblox game. Bee Swarm's developer (Onett) is essentially a one-person LiveOps machine. Theme Park Tycoon's dev does the same. Plan accordingly.

---

## Social and Community Hooks

These drive the algorithm, which drives discovery, which drives growth.

1. **Co-op Foraging Expeditions** (multiplayer, friend invites)
2. **Trading Post** (player gathering, Spatial Voice)
3. **Recipe Discovery sharing** (community knowledge)
4. **Visit other players' plots** (like Theme Park Tycoon)
5. **Shared servers with day/night cycle** (you bump into the same regulars)
6. **Lunar Events** (server-wide cooperation to summon mythics — community moments)

---

## Visual and Audio Direction

**Visual:** Hand-painted, slightly desaturated cozy aesthetic. Think Studio Ghibli forest scenes meets cottagecore. Heavy use of mist, dappled light, particle effects (spores in air, glowing pollen, fireflies). Mushrooms themselves should be *highly* varied visually — bioluminescent, lattice-textured, jelly-soft, crystalline.

**Audio:** This is undervalued on Roblox. A great ambient forest soundtrack with seasonal/biome variations is one of the cheapest ways to make a game feel premium. Hire one composer for original ambient music. Birdsong, distant streams, wind through leaves — sound design is what makes "cozy" actually work.

**Mobile UI:** giant tap targets, bottom-heavy layout, single-thumb operability. Test every screen on a phone before shipping.

---

## Naming the Game

*Mycelia* is a working title. Real options to consider:

- **Mycelia** — clean, mystic, easy to brand. May be too obscure for younger audience.
- **Spore & Stem** — cozy, descriptive, kid-friendly.
- **The Mushroom Hollow** — locational, evocative.
- **Glimmerwood** — pure aesthetic appeal, could be the name of the magic biome elevated to game title.
- **Forager** — clean, but may be too generic.
- **Misty Glade** — cozy and atmospheric.
- **Fae Forest** — fantasy lean, broader appeal.

For Roblox specifically, **a slightly whimsical name with a clear visual hook beats a clean abstract name.** "Grow a Garden" tells you everything in three words. "Mycelia" sounds cool but doesn't sell itself.

I'd test 2-3 names with thumbnails before committing.

---

## Build Order (Roadmap to Launch)

### Pre-Alpha (Months 1-2)
- Core loop: walk, harvest, plant, sell
- 15 mushroom species
- One biome (Starter Glade)
- Basic UI
- **Goal: prove the loop is fun in 5 minutes**

### Alpha (Months 3-4)
- Brewing system with 5 recipes
- Second biome
- 30 mushroom species total
- Forest Spirit system (5 spirits)
- **Goal: prove the depth layer engages players past hour 1**

### Closed Beta (Months 5-6)
- Trading Post (basic version)
- Co-op Foraging
- 60 mushroom species
- Quest system
- Mobile optimization pass
- **Goal: prove retention past day 7**

### Soft Launch (Month 7)
- Polish, balance pass, monetization integration
- LiveOps infrastructure
- Launch in low-traffic regions first
- **Goal: validate metrics before global launch**

### Global Launch (Month 8+)
- TikTok content seeded with creators
- First major event in week 2
- LiveOps cadence locked in

**Realistic timeline for a small team (1-3 devs): 8-12 months to soft launch.** Don't rush this. Cozy games live on polish.

---

## What Could Kill This Game

Honest list of failure modes to watch for:

1. **Going pay-to-win** — would gut the trading economy in 6 months
2. **Recipe space too small** — if players exhaust recipe discovery in week 1, the game loses its long-term hook. Make sure the combinatorics are deep.
3. **Mobile controls feel bad** — losing 40%+ of the audience instantly. Test relentlessly.
4. **No LiveOps cadence** — algorithm punishment, players churn
5. **Onboarding too slow** — if the first 2 minutes feel boring, you're done
6. **Trading exploits** — duping bugs killed early Adopt Me momentum. Trade system needs to be airtight from day one
7. **Trying to scope too big** — launch with 60 species, not 200. Add over time.

---

## Why This Game Wins Long-Term

To restate it clearly:

- **Production loop has real mycology depth** → optimization is genuine, not fake
- **Recipe discovery is combinatorial** → community knowledge persists for years
- **Trading post creates player-to-player value** → the Adopt Me lesson
- **Cottagecore aesthetic is stable** → not tied to a passing meme
- **Co-op foraging drives social signals** → algorithm rewards
- **Cosmetic monetization preserves trust** → players spend forever
- **Uncontested theme on Roblox** → no incumbent to fight

If this hits even 10% of Bee Swarm's longevity, it's a successful game. If it hits 50%, it's a generational hit.

---

*Built around 2026 Roblox platform realities — mobile-first, retention-weighted algorithm, social signal priority, Spatial Voice integration, and the proven longevity patterns of Bee Swarm Simulator (2018-present), Adopt Me (2019-present), and Theme Park Tycoon 2 (2014-present).*
