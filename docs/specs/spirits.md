# Spec — Forest Spirits

Complete catalog for the launch spirit system: 7 spirit types, attraction maps, roster mechanics, world AI behavior. Implements the Forest Spirits task in Phase 1 of the [ROADMAP](../ROADMAP.md).

---

## Spirit catalog

Three rarity tiers. Phase 1 ships all Common and Rare spirits; Legendary lands later (lunar event spawn).

### Common (3)

| Id | Display name | Visual hint | Passive bonus while in active roster |
|---|---|---|---|
| `Mossling` | Mossling | Small mossy creature. Soft green glow. | `+5% wildYield` for the player. |
| `Spritefly` | Spritefly | Tiny winged sprite, blue-white particle trail. | `-5% growthTime` on player's plots. |
| `Dewdrop` | Dewdrop | Translucent water-drop creature. | `+5% harvestYield` from planted plots. |

### Rare (3)

| Id | Display name | Visual hint | Passive bonus | Unique mechanic |
|---|---|---|---|---|
| `Lanternfox` | Lanternfox | Fox with glowing tail. | `+15% wildYield`. | Lights up dark plots — illuminates plots within 30 studs at night, lets bioluminescent species be planted in dark biomes that would normally fail. |
| `Crystalmoth` | Crystalmoth | Moth with crystalline wings. | `+15% rare-variant chance` (additive, capped per usual). | At each midnight (server time), drops a `Crystal Shard` consumable into player's inventory. Crystal Shards trade for premium prices. |
| `Deerlet` | Deerlet | Tiny deer with antlers like coral. | `-15% growthTime`. | Once per real-world day, player can spend the Deerlet's "favor" to instantly ripen one plot. Favor regenerates 24h after use. |

### Legendary (1, Phase 4)

| Id | Display name | Visual hint | Passive bonus | Unique mechanic |
|---|---|---|---|---|
| `ForestMother` | Forest Mother | Stag-like figure with antlers wreathed in glowing leaves. | Server-wide effects (see notes). | Once-per-server lunar event spawn. While present in the server, every player gets +25% to all yields and -25% growthTime. Despawns after 30 minutes. |

`ForestMother` is a special case:
- Not in any player's roster (server-bound, not player-bound).
- Spawns during full-moon lunar phase events.
- All players in the server can witness it; passive bonuses apply server-wide.
- Cosmetic spawn animation (camera pan, music sting) shared across clients.

---

## Spirit attraction system

Players attract spirits passively by what's in their inventory and on their plots. Server runs a per-player attraction tick every `Constants.SPIRITS.attractionTickSeconds` (default 300s = 5 min).

### Attraction map per spirit

Each spirit type has a table mapping species ids to "base chance per hour" of that spirit appearing while the player holds/grows that species.

`Constants.SPIRITS.attractionMap[spiritId]`:

```lua
Constants.SPIRITS.attractionMap = {
    Mossling = {
        BrownCap     = 0.04,    -- 4% per hour while holding/growing
        Buttoncap    = 0.03,
        Mossring     = 0.10,    -- main attractor
        Pinwheel     = 0.02,
    },
    Spritefly = {
        FairyCup     = 0.10,    -- main
        Sundrop      = 0.05,
        SpottedToadstool = 0.02,
    },
    Dewdrop = {
        FairyCup     = 0.05,
        Hollowstem   = 0.08,
        Dewfern      = 0.15,    -- main
    },
    Lanternfox = {
        Inkpot       = 0.02,
        Glowmoss     = 0.05,    -- main
    },
    Crystalmoth = {
        Whisperbloom = 0.04,
        CrystalCap   = 0.10,    -- main
    },
    Deerlet = {
        CoralTongue  = 0.04,
        LatticeVeil  = 0.04,
        Glowmoss     = 0.02,
    },
    -- ForestMother is event-spawned, not attraction-driven.
}
```

**Reading the table:** if a player has `Mossring` in inventory or growing on a plot, every attraction tick (5 min = 1/12 of an hour) rolls a `0.10 / 12 = 0.83%` chance of attracting a `Mossling`.

**Stacking:** multiple species each contribute their chance independently. Player with both `Mossring` and `BrownCap` rolls `0.10/12 + 0.04/12 = 0.0117 = 1.17%` per tick for Mossling.

**Spirit-attract potion bonus:** if the player has an active `spiritAttract` effect, multiply each species' contribution by the potion's `multiplier`.

**Multi-spirit rolls per tick:** each spirit type rolls independently per tick. A player with diverse holdings might attract two spirits in one tick.

### Attraction tick algorithm

```
on Heartbeat tick (every attractionTickSeconds):
    for each player in server:
        if player.activeRoster is full: skip
        gather player's "holdings" = species in inventory + species in plots (Growing or Ripe)
        active_potion_mult = PotionEffects.getMultiplier(player, "spiritAttract") or 1.0
        for each spiritId in attractionMap:
            chancePerTick = sum over holdings of (attractionMap[spiritId][species] or 0)
            chancePerTick = chancePerTick / (3600 / attractionTickSeconds)
            chancePerTick *= active_potion_mult
            if math.random() < chancePerTick:
                spawn(player, spiritId)
```

### Spirit world spawn

When a spirit is "attracted":

1. Server picks a spawn point near the player's hut (or plot area if no hut yet) within 20 studs.
2. Instantiates the spirit's Model template via `ReplicatedStorage.SpiritModels:FindFirstChild(spiritId):Clone()`. Templates are user-supplied Models pre-populated in `ReplicatedStorage.SpiritModels` (one Model per spirit type, named exactly the spiritId — `Mossling`, `Spritefly`, etc.). If the template is missing, log a warning and skip the spawn.
3. Sets attributes on the cloned Model: `isUnclaimedSpirit = true`, `spawnedFor = player.UserId`, `spiritType = spiritId`, `spawnedAt = os.time()`.
4. Adds `ProximityPrompt` for claiming.
5. Fires server→client toast: `"A Mossling has wandered onto your plot!"` (only to the targeted player; other players see the spirit but can't claim it).
6. Schedules despawn after `Constants.SPIRITS.unclaimedDespawnSeconds` (default 300s = 5 min). If the player doesn't claim in time, spirit disappears with a small particle puff.

**Skip the attraction tick for players not in a normal biome.** A player currently in a foraging expedition Place, hut interior, or other non-biome context shouldn't have spirits spawning back in their plot area (they wouldn't see the toast and the spirit would despawn before they returned). Check `player:GetAttribute("currentBiome")` — if nil or one of the special-context values, skip that player on this tick.

### Claim flow

Player approaches spirit, presses E (or taps prompt), client fires `ClaimSpirit` remote. The handler must use a **claim-and-revert pattern** to handle the race where two players try to claim simultaneously:

```lua
Remotes.get(Constants.REMOTES.ClaimSpirit).OnServerEvent:Connect(
    function(player, spiritWorldInstance)
        -- 1. Type check
        if typeof(spiritWorldInstance) ~= "Instance" then return end
        if not spiritWorldInstance:IsDescendantOf(Workspace) then return end

        -- 2. Atomic check-and-set: this whole block runs synchronously,
        --    so no other handler thread can interleave the read and write.
        if spiritWorldInstance:GetAttribute("isUnclaimedSpirit") ~= true then
            -- Another player already claimed it (or it despawned).
            return
        end
        spiritWorldInstance:SetAttribute("isUnclaimedSpirit", false)

        -- 3. Validation. If anything fails, REVERT the attribute so the
        --    spirit is claimable again. Otherwise the spirit gets stuck
        --    (neither owned nor available).
        local function revertAndReturn()
            spiritWorldInstance:SetAttribute("isUnclaimedSpirit", true)
        end

        if spiritWorldInstance:GetAttribute("spawnedFor") ~= player.UserId then
            return revertAndReturn()    -- not your spirit
        end

        local distance = (player.Character.PrimaryPart.Position
            - spiritWorldInstance:GetPivot().Position).Magnitude
        if distance > Constants.SPIRITS.claimRange then
            return revertAndReturn()
        end

        local data = PlayerData.get(player)
        if not data then return revertAndReturn() end

        local rosterCap = Spirits.rosterCapForPlayer(player)
        if #data.spirits.activeRoster >= rosterCap then
            return revertAndReturn()    -- roster full
        end

        -- 4. All checks passed. Mutate state.
        local spiritId = spiritWorldInstance:GetAttribute("spiritType")
        local uniqueId = string.format("%s_%d_%d", spiritId, player.UserId, os.time())

        PlayerData.update(player, function(d)
            d.spirits.allOwned[uniqueId] = {
                spiritType = spiritId,
                obtainedAt = os.time(),
                customName = nil,
            }
            table.insert(d.spirits.activeRoster, uniqueId)
            d.stats.spiritsCollected[spiritId] = true
        end)

        -- 5. Apply roster bonus immediately and despawn world Model.
        PassiveBonuses.recomputeForPlayer(player)
        spiritWorldInstance:Destroy()

        -- 6. Notify client.
        Remotes.get(Constants.REMOTES.SpiritClaimCompleted):FireClient(player, {
            success = true, spiritId = spiritId, uniqueId = uniqueId,
        })
    end
)
```

Unique id format: `spiritType .. "_" .. UserId .. "_" .. timestamp`. Allows multiple Mosslings owned by the same player (each is a distinct instance, can have its own custom name).

The `spiritType` is also stored explicitly in `data.spirits.allOwned[uniqueId].spiritType` per the [save schema](save-schema-v3.md). Don't parse the type out of the uniqueId at runtime — use the stored field.

---

## Roster mechanics

**Data model:** `data.spirits.allOwned` holds every spirit the player has ever owned (keyed by uniqueId). `data.spirits.activeRoster` is an array of uniqueIds — a *subset* of `allOwned` keys representing the currently-equipped spirits. Equipping/unequipping changes the activeRoster array; it does NOT move entries between collections.

**Roster cap:**

```lua
local rosterCap = Constants.SPIRITS.startingRosterSize    -- = 3
                + (player owns BiggerSpiritRoster gamepass and Constants.SPIRITS.biggerRosterGamepassBonus or 0)
                -- = 6 with gamepass
```

**Active-roster spirits (uniqueId in activeRoster):**
- Spawn as anchored Models in the player's hut area (or plot area if no hut).
- Wander idly via simple AI (random target within wander radius, walk to it, idle for 5–10s, repeat).
- Contribute their passive bonus to the player's `PassiveBonuses` registry.
- Despawn from the world when player leaves; respawn when player returns.

**Inactive spirits (uniqueId in allOwned but NOT in activeRoster):**
- No visible presence in world.
- No passive bonus contribution.
- Can be moved into the active roster via `EquipSpirit` if there's space.

**`EquipSpirit` (C → S):** validates the uniqueId exists in `allOwned`, isn't already in `activeRoster`, and roster has space. Appends to `activeRoster`. Spawns world Model. Calls `PassiveBonuses.recomputeForPlayer(player)`.

**`UnequipSpirit` (C → S):** validates the uniqueId is in `activeRoster`. Removes it from the array (does NOT remove from `allOwned`). Despawns world Model. Calls `PassiveBonuses.recomputeForPlayer(player)`.

### Wandering AI

Per active-roster spirit:

```
state = "Idle"
target = nil

every 1 second on Heartbeat:
    if state == "Idle":
        if random() < 0.2:    -- 20% chance per second to start walking
            target = randomPointInRadius(homePoint, wanderRadius)
            state = "Walking"
            playAnim(spirit, "Walk")
    elif state == "Walking":
        moveToward(spirit, target, walkSpeed)
        if distance(spirit, target) < 1:
            state = "Idle"
            playAnim(spirit, "Idle")
```

`wanderRadius` per spirit type (Common = 8 studs, Rare = 12). `walkSpeed` = 4 studs/sec for all spirits. Pathing doesn't need pathfinding — a simple linear movement on a flat plot area is enough. If the spirit hits an obstacle, it idles for 2s and picks a new target.

User supplies idle and walk animations per spirit Model. Scripter loads them via `AnimationController` and plays them on state changes.

---

## Spirit trading

Spirits are tradeable, but they're **not represented as items in `inventoryByCategory`** — they're a special trade-item type that the trade UI handles directly via `data.spirits`. This avoids splitting a spirit's identity across two tables.

**Trade flow:**

1. Player opens trade UI (per [remote-api spec](remote-api.md)).
2. Trade UI's "Spirits" picker shows the player's `data.spirits.allOwned` entries (display: name, type, custom name if set, obtained date).
3. Player drags a spirit into a trade offer slot. The slot displays `[Spirit] Mossling` (or the customName).
4. **While in the offer slot, the spirit is removed from `activeRoster` server-side** (world Model despawns; passive bonus recomputed). It remains in `allOwned` until trade resolves.
5. If trade SUCCEEDS:
   - Server removes the entry from sender's `data.spirits.allOwned`.
   - Server creates a new entry in recipient's `data.spirits.allOwned`, generating a new uniqueId scoped to the recipient's UserId. The `spiritType` and `obtainedAt` are preserved (the spirit's identity is the same; the uniqueId is just a per-account local key).
   - Recipient gets a top-screen notification: `"Received: Mossling. Equip from your spirit roster."`
   - Recipient does NOT get the spirit auto-equipped — they choose when to add to active roster.
6. If trade CANCELS:
   - Spirit stays in original owner's `allOwned` (untouched).
   - Server re-adds to `activeRoster` if there was room when removed; otherwise leaves inactive.

**Renaming on trade:** the receiving player can set a `customName` after claiming. The original `spiritType` and `obtainedAt` are immutable — they're effectively the spirit's birth certificate.

**Anti-duping:** spirit transfer is part of the same atomic trade commit as items + coins (per [remote-api trade flow](remote-api.md)). If the server crashes mid-trade, the spirit is still in the sender's `allOwned` (untouched until commit). No partial-state window.

---

## Constants

```lua
Constants.SPIRITS = {
    startingRosterSize         = 3,
    biggerRosterGamepassBonus  = 3,    -- +3 with gamepass; total 6
    attractionTickSeconds      = 300,  -- 5 minutes
    unclaimedDespawnSeconds    = 300,  -- 5 minutes
    claimRange                 = 12,   -- studs
    wanderRadiusCommon         = 8,
    wanderRadiusRare           = 12,
    walkSpeed                  = 4,    -- studs/sec
    homePointFallback          = "spawnArea",  -- if no hut, wander near spawn

    -- Bonuses applied while in active roster:
    bonuses = {
        Mossling     = { kind = "wildYield",    magnitude = 0.05 },
        Spritefly    = { kind = "growthSpeed",  magnitude = 0.05 },
        Dewdrop      = { kind = "harvestYield", magnitude = 0.05 },
        Lanternfox   = { kind = "wildYield",    magnitude = 0.15 },
        Crystalmoth  = { kind = "rareChance",   magnitude = 0.15 },
        Deerlet      = { kind = "growthSpeed",  magnitude = 0.15 },
    },

    -- Unique mechanic configs:
    lanternfoxIlluminationRadius = 30,   -- studs
    crystalmothShardSchedule     = "midnight",  -- once per server-day
    deerletFavorCooldownHours    = 24,
    forestMotherDuration         = 1800, -- 30 min
    forestMotherServerBonus      = { wildYield = 0.25, growthSpeed = 0.25 },
}
```

`Constants.SPIRITS.bonuses` defines passive bonuses by kind. The `kind` strings overlap with PotionEffects kinds where applicable (`wildYield`, `growthSpeed`, etc.) — a player with a Mossling AND an active wild-yield potion stacks both. Some kinds are spirit-only (`rareChance` is encoded directly in the cultivation formula's other-multiplier-excess slot).

---

## PassiveBonuses module (new)

Spirits' bonuses are *permanent while equipped* — they don't have an expiry timer like potion effects. Rather than overloading PotionEffects.lua with permanent flags, ship a separate `PassiveBonuses.lua` module with the same lookup interface so the cultivation/yield/economy systems can read both transparently.

```lua
local PassiveBonuses = {}

-- registry[player][kind] = total magnitude from all permanent sources
local registry = {}

function PassiveBonuses.recomputeForPlayer(player)
    local data = PlayerData.get(player)
    if not data then return end

    local totals = {}    -- by kind

    -- Spirit roster contributions:
    for _, uniqueId in ipairs(data.spirits.activeRoster) do
        local entry = data.spirits.allOwned[uniqueId]
        if entry then
            local bonusDef = Constants.SPIRITS.bonuses[entry.spiritType]
            if bonusDef then
                totals[bonusDef.kind] = (totals[bonusDef.kind] or 0) + bonusDef.magnitude
            end
        end
    end

    -- Future: gamepass-driven permanent bonuses, achievement rewards, etc.

    registry[player] = totals
    Remotes.get(Constants.REMOTES.PassiveBonusesUpdated):FireClient(player, totals)
end

function PassiveBonuses.get(player, kind)
    local totals = registry[player]
    return totals and (totals[kind] or 0) or 0
end

function PassiveBonuses.start()
    Players.PlayerAdded:Connect(function(player)
        -- Spawned right after PlayerData.onPlayerAdded so data exists
        task.wait(0.5)
        PassiveBonuses.recomputeForPlayer(player)
    end)
    Players.PlayerRemoving:Connect(function(player)
        registry[player] = nil
    end)
end

return PassiveBonuses
```

**Where it gets called:**
- After every successful claim, equip, unequip, trade resolution: `Spirits.lua` calls `PassiveBonuses.recomputeForPlayer(player)`.
- The cultivation/yield/economy formulas read `PassiveBonuses.get(player, "wildYield")` etc. when computing multipliers.
- Multipliers are **additive within kind**: total `wildYield` bonus = `PassiveBonuses.get(player, "wildYield") + PotionEffects.get(player, "wildYield")`. Then applied as `(1 + total)` to the base value.

This separation means PotionEffects stays simple (timed effects only) and PassiveBonuses absorbs spirit + future permanent bonuses. Both systems are read by gameplay code via the same `(kind) -> magnitude` interface.

---

## Spirits.lua structure

```lua
local Spirits = {}

local activeAttractionTimer  -- shared Heartbeat accumulator
local activeWorldSpirits = {} -- { [uniqueId] = { player, spiritType, model, state, target } }

function Spirits.startAttractionLoop()
    -- Heartbeat tick, runs every attractionTickSeconds.
    -- Iterates Players:GetPlayers(), runs attraction algorithm above.
end

function Spirits.spawn(player, spiritId)
    -- Creates world Model, sets attributes, adds prompt, schedules despawn.
end

function Spirits.claim(player, spiritWorldInstance)
    -- Called from ClaimSpirit remote. Validates + adds to roster.
end

function Spirits.equip(player, uniqueId)
    -- Move from allOwned (only) to activeRoster.
end

function Spirits.unequip(player, uniqueId)
    -- Move from activeRoster to allOwned (still in allOwned, just despawn from world).
end

function Spirits.spawnActiveRosterForPlayer(player)
    -- Called on player join + on hut entry. Instantiates Models for all active-roster spirits.
end

function Spirits.despawnActiveRosterForPlayer(player)
    -- Called on player leave. Removes Models.
end

function Spirits.applyRosterBonuses(player)
    -- Computes total bonus from active roster, registers with PotionEffects-like system
    -- so the cultivation/yield formulas pick up the boost transparently.
    -- Re-runs whenever roster changes.
end

function Spirits.start()
    Spirits.startAttractionLoop()
    -- Heartbeat for wandering AI ticks.
    -- Player join/leave handlers.
    -- Crystalmoth midnight schedule.
end

return Spirits
```

---

## Tests

`Tests/SpiritsSpec.lua`:

- Attraction roll math: with known holdings, expected probability per tick matches.
- Roster cap enforcement: claim fails when roster full.
- Equip / unequip move spirit between collections correctly.
- Discovery flag (`stats.spiritsCollected`) sets on first claim.
- Race condition: two players trying to claim the same spawned spirit — only one succeeds.
- Despawn timer: unclaimed spirit removed after `unclaimedDespawnSeconds`.
- Spirit-attract potion multiplier scales attraction chance.
- Trading: spirit moves from owner's roster to recipient's allOwned correctly.

---

## Notes for whoever's implementing

- **Spirits' world Models are user-supplied assets.** Scripter just instantiates them, sets attributes, drives the AI/animations. Don't try to model a fox geometrically in code.
- **Attraction tick is per-player, not per-spirit.** Each player ticks all spirit types once per cycle. Don't iterate `Players × Spirits × Species` — that's redundant. The server cost is `O(players × species_in_inventory × spirits)`, which is fine at typical Roblox player counts.
- **Spirit ids vs unique ids.** `spiritId` is the type ("Mossling"); `uniqueId` is the instance key (`"Mossling_12345_1640000000"`). Roster stores unique ids; bonuses key on spirit type.
- **Forest Mother is special and Phase 4.** Don't try to ship her in Phase 1. Stub the data structure; lunar-event scaffolding lands with the seasons system.
- **Crystalmoth's daily Crystal Shard:** schedule a `task.delay` from server start to next midnight; on tick, iterate all players with a Crystalmoth in their roster, add a Crystal Shard to their inventory. Re-schedule every 24h. Crystal Shard is defined as a tradable inventory item — see [Constants.ITEMS](#crystal-shard-item-definition) below.

---

## Crystal Shard item definition

Crystalmoth's daily reward is a tradable consumable. Defined in `Constants.ITEMS` (a generic items table that holds non-mushroom inventory items):

```lua
Constants.ITEMS.CrystalShard = {
    id            = "CrystalShard",
    displayName   = "Crystal Shard",
    description   = "A faceted shard left behind by a Crystalmoth at midnight. Brewers and traders prize them.",
    category      = "tools",                -- lives in inventoryByCategory.tools
    stackable     = true,
    maxStack      = 999,
    tradable      = true,
    droppable     = false,                  -- can't drop; intentional rarity
    iconAssetId   = "rbxassetid://0",       -- placeholder; user supplies
    baseSellPrice = 50,                     -- witch buys; player-trade prices typically higher
}
```

Future similar items (event drops, quest rewards) follow the same shape. `Constants.ITEMS` is a flat table indexed by id — the lookup pattern for any non-mushroom item.
