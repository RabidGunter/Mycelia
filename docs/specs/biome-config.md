# Spec — Biome Configuration

Biome config schema + complete Misty Hollow specification. Implements the biome refactor task in Phase 1 of the [ROADMAP](../ROADMAP.md), per the architecture decision in [decisions/001-biome-architecture.md](../decisions/001-biome-architecture.md) (single-place zones, not per-Place).

---

## Biome config schema

`Constants.BIOMES` is a table of biome configs keyed by biome id. Each entry follows this schema:

```lua
Constants.BIOMES = {
    [biomeId] = {
        id                 = string,    -- same as the key, kept for convenience
        displayName        = string,    -- player-visible name
        description        = string,    -- shown in travel UI

        unlockRenown       = number,    -- total renown required to enter; 0 = always unlocked
        unlockExtraGate    = function?, -- optional extra gate (e.g., lunar quest completed)
                                        --   signature: (player) -> bool
        unlockOrder        = number,    -- order shown in travel UI; lower = earlier

        -- Spatial layout in the single-place world:
        zoneCenter         = Vector3,   -- center of the biome zone
        zoneRadius         = number,    -- studs; entire biome contained within this sphere from center
        spawnPoint         = Vector3,   -- where the Travel NPC drops players entering this biome
        plotOrigin         = Vector3,   -- starting position for player plots in this biome (plot 1)
        npcPositions       = {          -- where biome-specific NPCs stand; nil if no biome-NPC of that type
            travelCoordinator = Vector3?,    -- always present (every biome has one)
            forestWitch       = Vector3?,    -- only Starter Glade
            substrateMerchant = Vector3?,    -- only Starter Glade in Phase 1
            -- ... etc, per biome's NPC roster
        },

        -- Wild spawn config:
        wildSpawnArea      = string,    -- name of the BasePart in Workspace marking the spawn volume
        wildSpawnTable     = { string },-- list of speciesId eligible for wild spawn here
        wildSpawnCap       = number,    -- max simultaneous wild mushrooms in this biome
        wildSpawnInterval  = number,    -- seconds between spawn attempts when below cap

        -- Atmosphere + lighting (applied client-side when player enters the zone):
        atmosphere         = {
            density        = number,
            offset         = number,
            color          = Color3,
            decay          = Color3,
            glare          = number,
            haze           = number,
        },
        lightingOverride   = {
            ambient        = Color3,
            outdoorAmbient = Color3,
            colorShift_Top = Color3,
            colorShift_Bottom = Color3,
            brightness     = number,
            clockTime      = number?,    -- if set, this biome locks day/night to this time
        },

        -- Audio:
        ambientMusicAssetId = string,    -- looping music asset
        ambientLoopAssetId  = string,    -- background loop (birdsong, water, etc.)

        -- Substrate availability for plots in this biome:
        availableSubstrates = { string },-- list of substrate ids whose costs are normal here
                                         -- (substrates not in this list cost +50% in this biome)

        -- Weather pattern (Phase 4):
        weatherDistribution = { [weatherKind] = number },  -- probabilities, sum to 1.0

        -- Travel:
        travelCostCoins    = number,    -- charged on each travel into this biome (0 for Starter Glade)
    }
}
```

The schema accommodates all 7 launch biomes; Misty Hollow below is the worked example.

---

## Starter Glade (existing — for reference)

```lua
StarterGlade = {
    id            = "StarterGlade",
    displayName   = "Starter Glade",
    description   = "A misty clearing where new gatherers begin.",
    unlockRenown  = 0,
    unlockOrder   = 1,
    zoneCenter    = Vector3.new(0, 0, 0),
    zoneRadius    = 500,
    spawnPoint    = Vector3.new(0, 5, 0),
    plotOrigin    = Vector3.new(0, 0, 30),    -- 30 studs north of spawn
    npcPositions = {
        travelCoordinator = Vector3.new(-15, 0, 0),
        forestWitch       = Vector3.new(20, 2, 0),
        substrateMerchant = Vector3.new(15, 0, 0),
    },

    wildSpawnArea     = "WildSpawnArea_StarterGlade",
    wildSpawnTable    = {
        "BrownCap", "SpottedToadstool", "FairyCup",
        "Mossring", "Buttoncap", "Pinwheel",
    },
    wildSpawnCap      = 25,
    wildSpawnInterval = 8,

    atmosphere = {
        density = 0.3, offset = 0.25,
        color   = Color3.fromRGB(199, 199, 199),
        decay   = Color3.fromRGB(106, 112, 125),
        glare   = 0, haze = 0,
    },
    lightingOverride = {
        ambient        = Color3.fromRGB(100, 100, 100),
        outdoorAmbient = Color3.fromRGB(140, 140, 140),
        colorShift_Top = Color3.fromRGB(255, 245, 220),
        colorShift_Bottom = Color3.fromRGB(120, 100, 80),
        brightness     = 2,
    },

    ambientMusicAssetId = "rbxassetid://0",   -- placeholder; user supplies
    ambientLoopAssetId  = "rbxassetid://0",

    availableSubstrates = { "compost", "hardwood", "straw", "dung" },
    weatherDistribution = { Sunny = 0.6, Cloudy = 0.3, Rainy = 0.1 },
    travelCostCoins     = 0,
},
```

---

## Misty Hollow (Phase 1 — new biome)

```lua
MistyHollow = {
    id            = "MistyHollow",
    displayName   = "Misty Hollow",
    description   = "A rainforest hollow where water-loving species fruit in the ever-present mist.",
    unlockRenown  = 100,
    unlockOrder   = 2,
    zoneCenter    = Vector3.new(2000, 0, 0),     -- east of Starter Glade
    zoneRadius    = 500,
    spawnPoint    = Vector3.new(2000, 5, 0),
    plotOrigin    = Vector3.new(2000, 0, 30),    -- per-biome plot region; relative to biome's zoneCenter
    npcPositions = {
        travelCoordinator = Vector3.new(1985, 0, 0),
        -- (no merchants in Misty Hollow; players travel back to Starter Glade for shopping)
    },

    wildSpawnArea     = "WildSpawnArea_MistyHollow",
    wildSpawnTable    = {
        -- Commons that appear here too (so there's still some easy harvest):
        "BrownCap", "FairyCup", "Mossring",
        -- Misty Hollow specialties (water-loving):
        "Hollowstem", "Dewfern",
        -- Rare wild appearance (low drop weight):
        "Glowmoss",
    },
    wildSpawnCap      = 30,    -- denser than Starter Glade
    wildSpawnInterval = 6,     -- faster respawn

    atmosphere = {
        density = 0.6, offset = 0.4,
        color   = Color3.fromRGB(180, 200, 195),
        decay   = Color3.fromRGB(70, 90, 100),
        glare   = 0.1, haze = 0.5,
    },
    lightingOverride = {
        ambient        = Color3.fromRGB(80, 100, 95),
        outdoorAmbient = Color3.fromRGB(120, 140, 135),
        colorShift_Top = Color3.fromRGB(180, 220, 200),
        colorShift_Bottom = Color3.fromRGB(60, 80, 75),
        brightness     = 1.5,    -- dimmer than Starter Glade
    },

    ambientMusicAssetId = "rbxassetid://0",   -- user supplies (something rainforest-y, water sounds, light music)
    ambientLoopAssetId  = "rbxassetid://0",   -- user supplies (rain ambience, distant frog calls)

    availableSubstrates = { "compost", "hardwood", "peat" },    -- peat is locally cheaper
    weatherDistribution = { Rainy = 0.5, Cloudy = 0.3, Sunny = 0.1, Foggy = 0.1 },
    travelCostCoins     = 25,
},
```

### Misty Hollow design notes

- **Wet biome identity:** lighting/atmosphere lean cool/blue/green. Weather defaults to rainy/cloudy 80% of the time.
- **Peat is normal price here** (vs. +50% elsewhere). This is the gameplay-mechanical reason to travel here for cultivation: rare-tier mushrooms become economically viable.
- **Wild spawn includes Glowmoss** with low drop weight (its tier weight = 10 → 4% wild spawn vs. Common's 100 → 41% spawn). Still rare in the wild but possible. Cultivation in peat is the reliable way.
- **Hollowstem and Dewfern** are wild-spawned-Uncommons in Misty Hollow but cultivated-only in Starter Glade. This makes Misty Hollow the unlock that "opens up" cultivation for those species.
- **No Crystal Cap or Whisperbloom** in Misty Hollow's wild table — those need cultivation.
- **Travel cost (25c):** small but non-zero. Encourages "travel less, harvest a bunch, travel back" rather than constant biome hopping.

### Spatial layout

Misty Hollow's center is at (2000, 0, 0) — 2000 studs east of Starter Glade's center (0, 0, 0). The biome zone has radius 500; combined with Starter Glade's radius 500, there's 1000 studs of "wilderness" between them. That gap is filled with a transition area (sparse trees, paths winding through hills) so the boundary feels organic rather than a sudden cut.

The Travel NPC at Starter Glade's spawn pad teleports the player to `MistyHollow.spawnPoint` via `HumanoidRootPart.CFrame = CFrame.new(spawnPoint)`. No `TeleportService` (per the architecture decision).

### Required Workspace items

For Misty Hollow to work, the world needs (built either procedurally or by-hand in Studio):

1. **`Workspace.Biomes.MistyHollow.WildSpawnArea_MistyHollow`** — invisible BasePart, size ~400x100x400, centered on `(2000, 50, 0)`. Marks the volume within which wild mushrooms spawn.
2. **`Workspace.Biomes.MistyHollow.SpawnPad`** — visible Part where players land on biome travel.
3. **`Workspace.Biomes.MistyHollow.PlotArea`** — region where player plots are placed when in Misty Hollow.
4. **Decorative parts** — terrain, trees, water, lighting fixtures, etc. (User-supplied assets; scripter places them or `MapSetup` builds procedural fallback.)
5. **`Workspace.Biomes.MistyHollow.AtmosphereTrigger`** — invisible BasePart matching `zoneRadius`. Players entering this trigger get the Misty Hollow atmosphere applied client-side.

The `Workspace.Biomes.<biomeId>` namespace organization means CollectionService tags or simple string lookups can find biome-specific Instances cleanly.

---

## Atmosphere + lighting transition

Per the [biome architecture decision](../decisions/001-biome-architecture.md), atmosphere and lighting are applied client-side when a player enters a biome zone. Server doesn't replicate these (each player can be in a different biome simultaneously).

### Client-side detection

```lua
-- In a biome controller LocalScript:

local currentBiome = "StarterGlade"
local TRANSITION_DURATION = 1.5

RunService.RenderStepped:Connect(function()
    local hrp = player.Character and player.Character.PrimaryPart
    if not hrp then return end

    local newBiome = detectBiome(hrp.Position)
    if newBiome ~= currentBiome then
        transitionTo(newBiome)
        currentBiome = newBiome
    end
end)

local function detectBiome(position, currentBiomeId)
    -- Iterate Constants.BIOMES; find the one whose zoneCenter is within zoneRadius
    -- of position. Return that biome's id.
    --
    -- If position is outside ALL zones (player walking through the gap between
    -- biomes), return currentBiomeId — i.e., DON'T transition to a default. This
    -- avoids a jarring "snap to StarterGlade in transit" experience when traveling
    -- between two non-Starter biomes.
    --
    -- On first call (currentBiomeId is nil) and position outside all zones,
    -- fall back to "StarterGlade" since players spawn there by default.
end

local function transitionTo(biomeId)
    local config = BIOMES[biomeId]
    -- Tween Atmosphere properties to target over TRANSITION_DURATION
    -- Tween Lighting properties similarly
    -- Crossfade ambient music (stop old, start new) over TRANSITION_DURATION
end
```

A 1.5-second crossfade is short enough to feel responsive and long enough to avoid jarring pops. Settings.reducedMotion = true skips the tween (instant change).

### Server-side biome tracking

The server tracks each player's current biome (as a player attribute or PlayerData field) for systems that care:
- Spirit attraction uses player's biome to skip biome-incompatible attraction calcs (future).
- Wild spawn uses biome to scope per-biome spawn areas.
- Quest objectives might require "in biome X" gating.

```lua
player:SetAttribute("currentBiome", biomeId)
```

Updated server-side via region check on Heartbeat or Region3 enter/leave events. Sub-second precision not required; 1-second polling is fine.

---

## StreamingEnabled tuning

Per the architecture decision, single-place world relies on `StreamingEnabled` to keep client memory bounded.

```lua
Workspace.StreamingEnabled = true
Workspace.StreamingMinRadius = 256        -- always-loaded radius around player
Workspace.StreamingTargetRadius = 1024    -- attempts-to-load radius
Workspace.StreamingPauseMode = Enum.StreamingPauseMode.ClientPhysicsPause
Workspace.StreamOutBehavior = Enum.StreamOutBehavior.Default
```

With biomes 2000 studs apart and 500-stud radii, a player in the middle of one biome has the entire biome loaded (radius 1024 covers it) but only the closest sliver of the next biome. Memory bounded; transitions smooth.

**Important:** mark biome wild spawn areas, plot regions, and any biome-critical instances as **persistent** (`StreamingEnabled` won't unload them):

```lua
biomeFolder:SetAttribute("ModelStreamingMode", Enum.ModelStreamingMode.Persistent)
```

This ensures even if the player is far from Misty Hollow, the wild spawn area still exists for spawn loop targeting. Without persistence, the server might try to spawn into a non-replicated area, causing weird state.

---

## Travel NPC

A simple NPC at each biome's spawn pad. Talks via dialogue system, opens travel UI on request:

```lua
-- TravelCoordinator NPC dialogue tree (loose):
{
    intro = "Where do you want to go?",
    options = {
        { text = "Show me where I can travel", action = "openTravelUI" },
        { text = "Never mind", action = "close" },
    },
}
```

**Travel UI** lists every biome with its current state:
- Locked: greyed out, shows requirement ("Reach 100 renown").
- Unlocked, available: tappable. Shows travel cost.
- Currently in: highlighted, "You are here" label.

**On selection:**
1. Confirm prompt: "Travel to Misty Hollow? Your inventory comes with you. Travel cost: 25 coins."
2. On confirm: client fires `RequestBiomeTravel(biomeId)`.
3. Server validates renown + travel cost.
4. Server deducts coins.
5. Server moves player's HumanoidRootPart to `BIOMES[biomeId].spawnPoint`.
6. Sets `currentBiome` attribute.
7. Fires `BiomeTravelCompleted` to client.
8. Client triggers atmosphere transition (already happens via the RenderStepped poll).

---

## Biome unlock trigger

`data.stats.biomesUnlocked[biomeId] = true` gets set in three ways:

1. **Eager via reputation hook.** `Reputation.add(player, npcId, amount)` — after applying the gain — re-checks total renown against every biome's `unlockRenown` threshold. Newly-met thresholds get `biomesUnlocked[biomeId] = true` and fire a `BiomeUnlocked` notification to the client (toast: "New biome available: Misty Hollow!"). This is the primary path.

2. **At travel time** (defensive). If `RequestBiomeTravel` succeeds (renown threshold met) and `biomesUnlocked[biomeId]` isn't set, set it. Catches edge cases where the eager hook missed (e.g., reputation gained during a server hot-reload).

3. **Quest reward** (event-driven). Some biome unlocks (Glimmerwood's lunar quest, Lost Cathedral's event participation) come from quest completion or event participation rather than rep. The relevant quest reward / event handler sets `biomesUnlocked[biomeId] = true` directly.

`biomesUnlocked` serves both as a "have I been here" flag (UI state) and as a unlock-bypass for biomes whose threshold has been reduced after the player already cleared it. **Don't gate `RequestBiomeTravel` on `biomesUnlocked` alone** — always re-check the renown threshold (or extra gate) at travel time, so a player who somehow lost the flag (via support-team intervention, save-data corruption migration) can still travel.

---

## All 7 biome unlock thresholds (recap)

For convenience; full configs ship as biomes are built:

| Biome | unlockRenown | unlockExtraGate | Phase shipped |
|---|---|---|---|
| StarterGlade | 0 | nil | Pre-Alpha |
| MistyHollow | 100 | nil | Phase 1 |
| FrostrootPass | 300 | nil | Phase 4 |
| SunkenGrove | 600 | nil | Phase 4 |
| OldGrowth | 1500 | nil | Phase 4 |
| Glimmerwood | 2500 | `lunarQuestCompleted` flag | Phase 4 |
| LostCathedral | (event-based) | `eventParticipation` flag | Phase 4 |

Misty Hollow is the only Phase 1 biome addition. The full 7 land in Phase 4 per the [ROADMAP](../ROADMAP.md).

---

## Tests

`Tests/BiomeConfigSpec.lua`:

- All `BIOMES` entries have required fields per the schema.
- All biome `wildSpawnTable` entries reference valid species ids.
- All biome `availableSubstrates` entries reference valid substrate ids.
- All biome `unlockOrder` values are unique.
- `weatherDistribution` sums to 1.0 per biome.
- `unlockRenown` thresholds match `Constants.BIOME_UNLOCK_RENOWN` from [reputation ADR](../decisions/003-reputation-rates.md).

`Tests/BiomeTravelSpec.lua`:

- Travel succeeds when renown threshold met.
- Travel rejected when renown insufficient.
- Travel coin cost deducted correctly.
- Player position updates to `spawnPoint`.
- `currentBiome` attribute updates.

---

## Notes for whoever's implementing

- **Single-place zones** is the locked-in architecture. Don't sneak `TeleportService` into biome travel. Foraging expeditions use TeleportService in Phase 2; biome travel does not.
- **Biome configs are data, not code.** All numbers in `Constants.BIOMES`. Adding biome 8 is a data change plus terrain art, not an architectural rewrite.
- **Atmosphere transitions are client-side.** Don't try to replicate Atmosphere objects from server — Roblox replicates a single Lighting instance. Each client controls its own atmosphere via local Lighting tweens.
- **`MapSetup.lua` should iterate biome configs.** When building procedurally, MapSetup loops `Constants.BIOMES` and builds each biome's spawn pad, wild spawn area, plot region from the config. No biome is hardcoded in MapSetup — adding biome 8 means adding a config entry.
- **Hand-built terrain trumps procedural.** Detection convention: each biome lives under `Workspace.Biomes.<biomeId>` as a Model or Folder. If that container exists and has the attribute `BuiltManually = true`, MapSetup skips procedural construction for that biome and trusts whatever's already there (just verifies the WildSpawnArea Part exists by name; logs a warning if missing). If `BuiltManually` is absent or false, MapSetup builds procedurally per the biome config and sets `BuiltManually = false` on the resulting container. A scripter doing a hand-built terrain pass on Misty Hollow would: build the world in Studio, place a `BuiltManually = true` attribute on `Workspace.Biomes.MistyHollow`, save, and the next server start preserves the work.
