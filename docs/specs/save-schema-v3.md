# Spec — Save Schema v3

Complete shape of `PlayerData` after Phase 1 migration. Every field listed with type, default, and origin (set by which system).

A contractor should be able to copy the `defaultData()` body directly from this spec, plus follow the migration steps verbatim.

---

## Schema version

`schemaVersion = 3` (Phase 1 target).

| Version | Shipped in | Adds |
|---|---|---|
| 1 | Pre-Alpha session 1 | Initial: coins, inventory, basic stats. |
| 2 | Pre-Alpha session 2 | `potions`, `stats.potionsDiscovered`, `stats.totalBrewed`. |
| 3 | Phase 1 | All categories below. |

---

## Top-level shape

```lua
{
    schemaVersion = 3,
    coins = 25,
    inventory = {                       -- mushrooms (raw category default)
        -- [speciesId] = count
    },
    inventoryByCategory = {             -- the 11-category model from PDF
        mushrooms_raw   = {},
        mushrooms_dried = {},
        potions         = {},
        spores          = {},
        substrates      = {},
        additives       = {},
        recipes         = {},           -- recipe scrolls (one-time-use items)
        spirit_items    = {},           -- spirit food, spirit cosmetics
        quest_items     = {},
        cosmetics       = {},
        tools           = {},
    },
    spirits = {
        activeRoster = {},              -- list of spiritId currently equipped (max = STARTING_SPIRIT_ROSTER_SIZE + gamepass extension)
        allOwned     = {},              -- map: [spiritId] = { obtainedAt, customName }
    },
    decorations = {
        unlocked = {},                  -- map: [decorationId] = true (i.e. owned, can be placed)
        placed   = {},                  -- list of { decorationId, position, rotation } in hut
    },
    plots = {                           -- per-player plots; persists across sessions
        -- [plotIndex] = {
        --     state         = "Empty" | "Growing" | "Ripe" | "Failed",
        --     biomeId       = string,         -- which biome this plot is in
        --     speciesId     = string?,        -- nil when Empty
        --     plantedAt     = number,
        --     ripeAt        = number,
        --     substrate     = string?,        -- substrate id; nil when Empty
        --     additives     = { [string] = number },   -- Phase 2+
        -- }
    },
    stats = {
        totalHarvested      = 0,
        totalPlanted        = 0,
        totalSold           = 0,
        totalCoinsEarned    = 0,
        totalBrewed         = 0,
        totalRareVariants   = 0,        -- new in v3
        totalPlotFailures   = 0,        -- new in v3
        totalDistanceWalked = 0,        -- new in v3, optional metric
        speciesDiscovered   = {},       -- map: [speciesId] = true
        potionsDiscovered   = {},       -- map: [potionId] = true
        spiritsCollected    = {},       -- new in v3, map: [spiritId] = true (history of all owned, even traded away)
        biomesUnlocked      = {         -- new in v3
            StarterGlade = true,
        },
        questsCompleted     = {},       -- new in v3, map: [questId] = completedAt timestamp
        recipesAttempted    = 0,        -- new in v3, count of distinct (method, sortedIngredients) tried
        recipesDiscovered   = {},       -- new in v3, map: [recipeKey] = potionId (the resolution of attempted recipes)
    },
    reputation = {                      -- new in v3
        -- [npcId] = { score, firstMet, lastDailyGreeting }
    },
    activeQuests = {                    -- new in v3
        -- [questId] = { acceptedAt, progress = { [objectiveId] = currentValue } }
    },
    gamepassesOwned = {                 -- new in v3
        -- [gamePassId] = { ownedSince }
    },
    settings = {                        -- new in v3
        masterVolume       = 1.0,
        musicVolume        = 0.7,
        sfxVolume          = 1.0,
        ambientVolume      = 0.6,
        hutAccessLevel     = "friends_only",  -- "private" | "friends_only" | "public"
        muteWhenTabbedOut  = true,
        showPotionHints    = true,            -- toggle Brewing Journal ingredient hints
        reducedMotion      = false,           -- accessibility
        cameraSensitivity  = 1.0,
    },
    auditTrail = {                      -- new in v3, optional
        firstJoinedAt      = 0,
        lastSavedAt        = 0,
        totalPlaytimeSeconds = 0,
        sessionsPlayed     = 0,
    },
}
```

---

## Field-by-field reference

### `schemaVersion`

| | |
|---|---|
| Type | number |
| Default | `SCHEMA_VERSION` (currently 3) |
| Set by | `defaultData()` |
| Read by | `migrate()` |
| Notes | Auto-bumped during `migrate()`. Never directly modified by gameplay. |

### `coins`

| | |
|---|---|
| Type | number |
| Default | `Constants.ECONOMY.startingCoins` (= 25) |
| Set by | `Coins.add` / `Coins.spend` (server-side) |
| Read by | `CoinDisplay.client.lua`, every shop UI, `Planting.attemptPlantSpecies` |
| Constraints | `0 <= coins <= Constants.ECONOMY.coinHardCap`. Single-tick gain rejected if > `singleTickGainHardReject`. |
| Audit | Every `Coins.add` ≥ `singleTickGainSuspicious` writes to `MyceliaAuditLog_v1`. |

### `inventory` (legacy)

| | |
|---|---|
| Type | `{ [string] = number }` |
| Default | `{}` |
| Notes | **Existing v2 field, preserved for backwards compat during v2→v3 migration.** New code reads `inventoryByCategory.mushrooms_raw` instead. After migration is in place for ≥ 30 days, this field can be removed and the v3→v4 migration can drop it. |

### `inventoryByCategory`

| | |
|---|---|
| Type | `{ [categoryId] = { [itemId] = count } }` |
| Default | All 11 categories present, all empty. |
| Set by | `Inventory.add(category, itemId, count)` etc. |
| Read by | Backpack UI, every shop UI, brewing UI. |
| Constraints | Per-stack max: 999. Per-category slot count: 32 default; +4 rows per Inventory Expansion gamepass. |
| Notes | Item ids are unique across all categories. A potion id and a substrate id never collide. |

### `spirits.activeRoster`

| | |
|---|---|
| Type | `{ [number]: spiritId }` (array-style) |
| Default | `{}` |
| Notes | Length capped at `STARTING_SPIRIT_ROSTER_SIZE` (= 3) + gamepass bonus (Bigger Spirit Roster: +3). Server enforces cap at every add. |

### `spirits.allOwned`

| | |
|---|---|
| Type | `{ [uniqueId] = { spiritType: string, obtainedAt: number, customName: string? } }` |
| Default | `{}` |
| Set by | `Spirits.claim()` on the server. |
| Notes | Spirits are unique-instance items; multiple instances of the same spiritType create separate entries with different keys. Unique id format: `spiritType .. "_" .. UserId .. "_" .. timestamp`. The `spiritType` field is stored explicitly (not parsed from the uniqueId at lookup) so renaming the id format later doesn't break bonus resolution. |

### `decorations.unlocked`

| | |
|---|---|
| Type | `{ [decorationId] = true }` |
| Default | `{}` |
| Set by | Decoration purchases (Decoration Merchant), quest rewards, gamepass bonuses. |

### `decorations.placed`

| | |
|---|---|
| Type | `array of { decorationId: string, position: Vector3, rotation: number }` |
| Default | `[]` |
| Notes | Position is in the hut's local coordinate system. Rotation is yaw in degrees. |

### `plots`

| | |
|---|---|
| Type | `{ [plotIndex: number] = { state, biomeId, speciesId, plantedAt, ripeAt, substrate, additives } }` |
| Default | `{}` (lazily populated when player gets their first plot) |
| Set by | `Planting.lua` plant + harvest paths; `Plots.allocate(player)` on first join. |
| Read by | Plot rebuild on player join, plant flow, harvest flow, Heartbeat ripen check. |

**Plot lifecycle:**

- On player's first join (no `data.plots` populated): server allocates `Constants.CULTIVATION.startingPlotSize` (= 4 default) plot entries, all `state = "Empty"`, `biomeId = "StarterGlade"` (or whichever biome the player will spawn into).
- On every subsequent join: server reads `data.plots`, instantiates plot Models in the player's plot region for the player's current biome, restores Growing/Ripe/Failed visuals from the saved state. Plots in OTHER biomes (because the player has plots in multiple biomes) only instantiate visually when the player is in those biomes.
- On player leave: plot Instances despawn from world; `data.plots` keeps the state. Growing plots' `ripeAt` is a timestamp, so when the player rejoins, the system computes whether the plot has ripened during the player's absence (server time elapsed > ripeAt → transition to Ripe or Failed).
- Bigger Plot gamepass purchase: server appends additional plot entries to `data.plots` up to `Constants.CULTIVATION.maxPlotSize` (= 16).

**Plot index → world position mapping:** plot Models are placed in the biome's `plotOrigin` (defined in biome config — see [biome-config](biome-config.md)) using `plotIndex` to offset:

```
position = biome.plotOrigin + Vector3.new(
    (plotIndex - 1) * Constants.CULTIVATION.plotSpacing,
    0,
    0
)
```

Default `plotSpacing = 7` studs. So plot 1 is at `plotOrigin`, plot 2 is at `plotOrigin + (7, 0, 0)`, etc. Up to 16 plots fits in a 105-stud row.

**Cross-biome plots (Phase 2+):** if a player has plots in Misty Hollow, those are stored with `biomeId = "MistyHollow"` and only instantiate as world Models when the player is in Misty Hollow. Each biome has its own plotOrigin so plot 1 in Starter Glade and plot 1 in Misty Hollow are at different world positions. Pre-Alpha phase 1 ships only Starter Glade plots; the architecture is forward-compatible.

### `stats.*`

All `stats.total*` are non-decreasing counters. Reset only via admin tooling.

| Field | Default | Increments when |
|---|---|---|
| `totalHarvested` | 0 | Any harvest action (wild or planted). |
| `totalPlanted` | 0 | Any plant action that succeeds (server-validated). |
| `totalSold` | 0 | Sell transaction completes; counts items not coins. |
| `totalCoinsEarned` | 0 | Any coin gain (sell, quest reward, login bonus). |
| `totalBrewed` | 0 | Brew action completes (success OR fizzle). |
| `totalRareVariants` | 0 | Rare-variant roll lands. |
| `totalPlotFailures` | 0 | Planted plot enters Failed state (substrate=0 mismatch). |
| `totalDistanceWalked` | 0 | Optional. Updated server-side every N seconds based on character position delta. |

| Set | Default | Populated when |
|---|---|---|
| `speciesDiscovered` | `{}` | Species enters inventory for the first time. |
| `potionsDiscovered` | `{}` | Potion enters inventory for the first time. |
| `spiritsCollected` | `{}` | Spirit added to roster for the first time. Persists even after trading the spirit away. |
| `biomesUnlocked` | `{ StarterGlade = true }` | Total renown crosses biome's threshold OR specific unlock event. |
| `questsCompleted` | `{}` | Quest turn-in. Value is timestamp. |
| `recipesDiscovered` | `{}` | Brew action produces a potion. Key is the resolved recipe key (`method .. "|" .. sortedIngredients`); value is the potion id. |

| Counter | Default | Increments when |
|---|---|---|
| `recipesAttempted` | 0 | Brew action with a previously-untried recipe key. |

### `reputation`

| | |
|---|---|
| Type | `{ [npcId] = { score: number, firstMet: number, lastDailyGreeting: number } }` |
| Default | `{}` (lazily created on first NPC interaction) |
| Notes | Score capped at 5000 per NPC. See [decisions/003-reputation-rates.md](../decisions/003-reputation-rates.md) for gain rates and tiers. |

### `activeQuests`

| | |
|---|---|
| Type | `{ [questId] = { acceptedAt: number, progress: { [objectiveId] = number } } }` |
| Default | `{}` |
| Notes | Moved to `stats.questsCompleted` on turn-in. |

### `gamepassesOwned`

| | |
|---|---|
| Type | `{ [gamePassId] = { ownedSince: number } }` |
| Default | `{}` |
| Notes | Refreshed on player join via `MarketplaceService:UserOwnsGamePassAsync`. Updated immediately on `PromptGamePassPurchaseFinished` for mid-session purchases. |

### `settings`

| Field | Default | Notes |
|---|---|---|
| `masterVolume` | 1.0 | 0–1; multiplied with sub-volumes. |
| `musicVolume` | 0.7 | 0–1. |
| `sfxVolume` | 1.0 | 0–1. |
| `ambientVolume` | 0.6 | 0–1. |
| `hutAccessLevel` | `"friends_only"` | `"private"` / `"friends_only"` / `"public"`. |
| `muteWhenTabbedOut` | `true` | Boolean. |
| `showPotionHints` | `true` | Brewing Journal shows ingredient combo hints if true. |
| `reducedMotion` | `false` | Skips camera shake, slows tweens. |
| `cameraSensitivity` | 1.0 | 0.5–2.0 typical range. |

### `auditTrail`

| Field | Default | Notes |
|---|---|---|
| `firstJoinedAt` | `os.time()` (set on first save) | Never updates after creation. |
| `lastSavedAt` | `os.time()` (updated every save) | Used for "last seen" UX. |
| `totalPlaytimeSeconds` | 0 | Incremented on heartbeat tick while player is in-server. |
| `sessionsPlayed` | 0 | Incremented on player join. |

---

## Migration

```lua
local function migrate(data)
    if data.schemaVersion == nil then
        data.schemaVersion = 1
    end

    -- v1 -> v2 (already shipped in Pre-Alpha)
    if data.schemaVersion < 2 then
        data.potions = data.potions or {}
        if data.stats then
            data.stats.totalBrewed       = data.stats.totalBrewed or 0
            data.stats.potionsDiscovered = data.stats.potionsDiscovered or {}
        end
        data.schemaVersion = 2
    end

    -- v2 -> v3 (Phase 1)
    if data.schemaVersion < 3 then
        -- Move legacy `inventory` (mushrooms) into category model. Don't
        -- delete the old key yet — leave for backwards compat for one schema
        -- version, drop in v4.
        data.inventoryByCategory = {
            mushrooms_raw   = data.inventory or {},
            mushrooms_dried = {},
            potions         = data.potions or {},
            spores          = {},
            substrates      = {},
            additives       = {},
            recipes         = {},
            spirit_items    = {},
            quest_items     = {},
            cosmetics       = {},
            tools           = {},
        }

        data.spirits        = data.spirits or { activeRoster = {}, allOwned = {} }
        data.decorations    = data.decorations or { unlocked = {}, placed = {} }
        data.plots          = data.plots or {}
        data.reputation     = data.reputation or {}
        data.activeQuests   = data.activeQuests or {}
        data.gamepassesOwned = data.gamepassesOwned or {}

        data.settings = data.settings or {
            masterVolume = 1.0,    musicVolume = 0.7,    sfxVolume = 1.0,
            ambientVolume = 0.6,   hutAccessLevel = "friends_only",
            muteWhenTabbedOut = true,    showPotionHints = true,
            reducedMotion = false,    cameraSensitivity = 1.0,
        }

        data.auditTrail = data.auditTrail or {
            firstJoinedAt = os.time(),    lastSavedAt = os.time(),
            totalPlaytimeSeconds = 0,    sessionsPlayed = 0,
        }

        if data.stats then
            data.stats.totalRareVariants   = data.stats.totalRareVariants or 0
            data.stats.totalPlotFailures   = data.stats.totalPlotFailures or 0
            data.stats.totalDistanceWalked = data.stats.totalDistanceWalked or 0
            data.stats.spiritsCollected    = data.stats.spiritsCollected or {}
            data.stats.biomesUnlocked      = data.stats.biomesUnlocked or { StarterGlade = true }
            data.stats.questsCompleted     = data.stats.questsCompleted or {}
            data.stats.recipesAttempted    = data.stats.recipesAttempted or 0
            data.stats.recipesDiscovered   = data.stats.recipesDiscovered or {}
        end

        data.schemaVersion = 3
    end

    return data
end
```

Migration is idempotent — running it on an already-v3 save is a no-op. Always check `data.schemaVersion < N` rather than `==`.

**Forward-compat:** when v4 lands, the v3→v4 step is added to the same function. `migrate()` always brings any save up to current. Don't write reverse migrations.

---

## ProfileService configuration

The Phase 1 work migrates from raw `DataStoreService` to ProfileService for proper session locking, retry logic, and graceful shutdown handling.

### Installation

ProfileService is a community library by `loleris`. Two install options:

**Option A — vendor it (recommended for this project):**
1. Download `ProfileService.lua` from https://github.com/MadStudioRoblox/ProfileService.
2. Drop into `src/ServerScriptService/Vendor/ProfileService.lua`.
3. Require as `local ProfileService = require(ServerScriptService.Vendor.ProfileService)`.

Vendoring is simplest for a solo project. No new toolchain, easy to read the source if debugging, version pinned by what's checked in.

**Option B — Wally:**
1. Add `wally.toml` to project root with `ProfileService = "loleris/profileservice@^1.4"` (or current version).
2. Add Wally to `aftman.toml`.
3. Run `wally install`.
4. Require as `local ProfileService = require(ReplicatedStorage.Packages.ProfileService)` (path depends on Wally setup).

Use Option B only if you're also planning to add other community libraries and want package management.

### Store key

Use the existing store key — **do not rename**:

```lua
local ProfileTemplate = defaultData()    -- shape from earlier in this doc
local ProfileService = require(ServerScriptService.Vendor.ProfileService)
local ProfileStore = ProfileService.GetProfileStore("MyceliaPlayerData_v1", ProfileTemplate)
```

**Why keep the existing store key:** schema versions are tracked inside the data via `schemaVersion` and handled by `migrate()`. ProfileService's store key is the namespace for session locks — changing it would orphan all existing saves (every v1/v2 playtest record on Roblox lost). Bumping `SCHEMA_VERSION` from 2 to 3 inside the data is the correct version pivot; the store key stays put.

If you ever need a hard cutover (e.g., schema is incompatible enough that migration isn't viable), do it as a separate, deliberate, one-time data move — not as a side effect of a library swap.

### Player lifecycle

The full lifecycle pattern. Drop this into `PlayerData.lua` (or a thin wrapper module that PlayerData uses):

```lua
local Players = game:GetService("Players")

local profiles = {}    -- [Player] = profile

local function onPlayerAdded(player)
    local profile = ProfileStore:LoadProfileAsync("u_" .. player.UserId, "ForceLoad")

    if profile == nil then
        -- Another server still has the lock and won't release.
        -- Kick rather than silently fail — losing data is worse than re-joining.
        player:Kick("Couldn't load your save. Please rejoin in a moment.")
        return
    end

    profile.Data = migrate(profile.Data)    -- in-place mutation; no-op if already current
    profile:AddUserId(player.UserId)
    profile:Reconcile()                     -- backfill missing fields per ProfileTemplate

    profile:ListenToRelease(function()
        -- Another server took over (rare; usually due to player teleport).
        profiles[player] = nil
        if player:IsDescendantOf(Players) then
            player:Kick("Save data was loaded on another server.")
        end
    end)

    if not player:IsDescendantOf(Players) then
        -- Player left while we were loading. Release immediately.
        profile:Release()
        return
    end

    profiles[player] = profile
    -- Fire initial PlayerDataUpdated to client now that data is ready.
    Remotes.get("PlayerDataUpdated"):FireClient(player, profile.Data)
end

local function onPlayerRemoving(player)
    local profile = profiles[player]
    if profile then
        profile:Release()
    end
    profiles[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Players already in (Studio Play Solo, server hot-reload) get processed too:
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

-- BindToClose: ProfileService releases all profiles automatically on game close.
-- No manual handling needed unless you want to add a shutdown timeout knob.
```

`Reconcile()` is the safety net: any field present in `ProfileTemplate` but missing from a loaded profile gets backfilled. Means future schema additions that are pure-additions (new field with default) don't necessarily need their own migration step in `migrate()`.

### Public API (PlayerData wrapper)

The Pre-Alpha `PlayerData.get / update / save` API is preserved so other modules don't need to change. Internally, those calls go through ProfileService:

```lua
function PlayerData.get(player)
    local profile = profiles[player]
    return profile and profile.Data or nil
end

function PlayerData.update(player, fn)
    local profile = profiles[player]
    if not profile then return end
    fn(profile.Data)
    -- ProfileService auto-saves on its own schedule; we don't trigger a save
    -- per update (that would thrash). The Updated event keeps the client in sync
    -- regardless of when the actual write hits DataStore.
    Remotes.get(Constants.REMOTES.PlayerDataUpdated):FireClient(player, profile.Data)
end

function PlayerData.save(player)
    -- Mostly unnecessary — ProfileService auto-saves. Provided as a force-save
    -- option for cases where the caller wants to ensure persistence before
    -- a user-visible action (e.g., before a TeleportService teleport into an
    -- expedition Place).
    local profile = profiles[player]
    if profile then profile:Save() end
end
```

The internal `cache` table from Pre-Alpha is replaced by `profiles` (keyed by Player Instance, not UserId, since Profile lookup is per-session not per-account).

### Autosave behavior

ProfileService manages auto-save internally — default ~30 seconds. **You don't need `Constants.SAVE.autosaveInterval` anymore;** delete it from Constants or leave it documented as deprecated.

ProfileService's auto-save period isn't directly tunable, but it's tuned conservatively for Roblox's DataStore rate limits. Don't override it without good reason.

### Edge cases worth knowing

- **Rapid join/leave** (player joins, leaves before profile loads): handled by the `if not player:IsDescendantOf(Players)` check after migrate. If they've left, release the profile so the next session can load.
- **Teleport between Places** (foraging expedition entry/exit): ProfileService releases the profile when the player teleports out, the destination Place's `ListenToRelease` fires, the destination loads its own profile. No manual coordination needed if both Places use the same `ProfileStore` config.
- **Mid-save shutdown** (Roblox shuts down a server): `BindToClose` runs ProfileService's release-all internally; everything saves before the server dies.
- **Suspicious load** (load returns nil): this means another server still holds the lock past `ForceLoad`'s patience. Kick rather than instantiate a fresh profile — wrong choice would overwrite the player's real data.

---

## Tests

`Tests/SaveSchemaSpec.lua` should cover:

- `defaultData()` returns a table with `schemaVersion == 3` and all top-level keys present.
- `migrate(v1_save)` produces `schemaVersion == 3` and contains every required v3 field.
- `migrate(v2_save)` produces `schemaVersion == 3` (preserves potions and inventory).
- `migrate(v3_save)` is a no-op.
- All 11 inventory categories are present in `inventoryByCategory`.
- `Reconcile()` adds a missing field to a synthetic incomplete profile.

---

## Notes for whoever's implementing

- **Don't try to optimize storage.** ProfileService writes the whole profile on each save. Don't be tempted to skip writing "unchanged" subtables — let ProfileService handle it.
- **Field renames are migrations.** If you ever need to rename a field in a future schema, write the migration step explicitly. Don't just rename in `defaultData()` and hope `Reconcile()` handles it (it adds, doesn't rename).
- **Inventory slot count is enforced server-side.** The Backpack UI shows 32 slots default; the server validates that adds don't push the count above this. Rejected adds become "Inventory full" toast on client.
- **`auditTrail` is optional.** If memory is tight, this entire subtable can be moved to a separate DataStore. Default plan: keep in-profile.
