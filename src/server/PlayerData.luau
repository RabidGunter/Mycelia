-- Per-player save data via ProfileService.
--
-- ProfileService gives us session locking (a player's profile loads in
-- exactly one server at a time), retry logic, autosave on a managed cadence,
-- and graceful shutdown — all the things the Pre-Alpha DataStore wrapper
-- had to fake or skip. We migrated for Phase 1 because trading (Phase 2)
-- can't be made safe without session locking.
--
-- The public API (`get`, `update`, `save`) is preserved from Pre-Alpha so
-- gameplay modules don't change. Internally, calls go through a `profiles`
-- table keyed by Player Instance. Save schema is versioned via
-- `data.schemaVersion`; bump `SCHEMA_VERSION` and add a step in `migrate()`
-- when the shape changes.
--
-- Spec: docs/specs/save-schema-v3.md.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local ProfileService = require(ServerScriptService.Server.Vendor.ProfileService)
local PendingMutations = require(ServerScriptService.Server.PendingMutations)

local PlayerData = {}

local SCHEMA_VERSION = 3

-- ---------- Default data --------------------------------------------------

local function defaultData()
	return {
		schemaVersion = SCHEMA_VERSION,
		coins = Constants.ECONOMY.startingCoins,

		-- Legacy v2 fields. Preserved for backwards compat — gameplay
		-- modules still read/write `data.inventory` and `data.potions`. The
		-- v3 `inventoryByCategory` is the new canonical home; future Phase
		-- work moves consumers across, then v4 can drop these legacy keys.
		inventory = {},
		potions = {},

		-- v3: 11-category inventory model. Mushrooms-raw mirrors `inventory`
		-- at migration time but they don't auto-sync — see Notes below.
		inventoryByCategory = {
			mushrooms_raw   = {},
			mushrooms_dried = {},
			potions         = {},
			spores          = {},
			substrates      = {},
			additives       = {},
			recipes         = {},
			spirit_items    = {},
			quest_items     = {},
			cosmetics       = {},
			tools           = {},
		},

		spirits = {
			activeRoster = {},     -- list of spiritUniqueIds, capped by Constants
			allOwned     = {},     -- map: [uniqueId] = { spiritType, obtainedAt, customName }
		},

		decorations = {
			unlocked = {},          -- map: [decorationId] = true
			placed   = {},          -- list of { decorationId, position, rotation }
		},

		-- Per-player plot persistence. Lazily allocated on first join.
		plots = {},

		stats = {
			totalHarvested      = 0,
			totalPlanted        = 0,
			totalSold           = 0,
			totalCoinsEarned    = 0,
			totalBrewed         = 0,
			totalRareVariants   = 0,
			totalPlotFailures   = 0,
			totalDistanceWalked = 0,
			speciesDiscovered   = {},
			potionsDiscovered   = {},
			spiritsCollected    = {},
			biomesUnlocked      = { StarterGlade = true },
			questsCompleted     = {},
			recipesAttempted    = 0,
			recipesDiscovered   = {},
		},

		reputation = {},            -- [npcId] = { score, firstMet, lastDailyGreeting }
		activeQuests = {},          -- [questId] = { acceptedAt, progress }
		gamepassesOwned = {},       -- [gamePassId] = { ownedSince }

		-- Player Stalls (Phase 2). Additive to v3 schema; assigned lazily on
		-- first stall interaction (PlotAnchors.assign writes plotAnchorId).
		-- See docs/specs/player-stalls.md (D-13).
		stalls = {
			plotAnchorId          = nil,
			listings              = {},
			mailbox = {
				coins          = 0,
				items          = {},
				sales          = {},
				overflowNotice = nil,
			},
			featuredRentExpiresAt = nil,
		},

		settings = {
			masterVolume       = 1.0,
			musicVolume        = 0.7,
			sfxVolume          = 1.0,
			ambientVolume      = 0.6,
			hutAccessLevel     = "friends_only",
			muteWhenTabbedOut  = true,
			showPotionHints    = true,
			reducedMotion      = false,
			cameraSensitivity  = 1.0,
		},

		auditTrail = {
			firstJoinedAt        = 0,    -- set on first onPlayerAdded
			lastSavedAt          = 0,    -- updated each PlayerData.save
			totalPlaytimeSeconds = 0,
			sessionsPlayed       = 0,
		},
	}
end

-- ---------- Migration -----------------------------------------------------
--
-- Always check `data.schemaVersion < N` (not `==`) — migration is idempotent
-- and a save jumping multiple versions runs every step in order. Forward-
-- compat: when v4 lands, the v3->v4 step is appended below.

local function migrate(data)
	if data.schemaVersion == nil then
		data.schemaVersion = 1
	end

	-- v1 -> v2: brewing system added.
	if data.schemaVersion < 2 then
		data.potions = data.potions or {}
		if data.stats then
			data.stats.totalBrewed = data.stats.totalBrewed or 0
			data.stats.potionsDiscovered = data.stats.potionsDiscovered or {}
		end
		data.schemaVersion = 2
	end

	-- v2 -> v3: Phase 1 schema (full inventory categories + spirits +
	-- decorations + plots + reputation + quests + gamepasses + settings +
	-- audit trail).
	if data.schemaVersion < 3 then
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

		data.spirits         = data.spirits or { activeRoster = {}, allOwned = {} }
		data.decorations     = data.decorations or { unlocked = {}, placed = {} }
		data.plots           = data.plots or {}
		data.reputation      = data.reputation or {}
		data.activeQuests    = data.activeQuests or {}
		data.gamepassesOwned = data.gamepassesOwned or {}

		data.settings = data.settings or {
			masterVolume       = 1.0,
			musicVolume        = 0.7,
			sfxVolume          = 1.0,
			ambientVolume      = 0.6,
			hutAccessLevel     = "friends_only",
			muteWhenTabbedOut  = true,
			showPotionHints    = true,
			reducedMotion      = false,
			cameraSensitivity  = 1.0,
		}

		data.auditTrail = data.auditTrail or {
			firstJoinedAt        = os.time(),
			lastSavedAt          = os.time(),
			totalPlaytimeSeconds = 0,
			sessionsPlayed       = 0,
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

	-- Additive backfill (no schema bump): Phase 2 added data.stalls. Safe to
	-- re-run on any v3 profile; only writes when the field is missing.
	-- ProfileService:Reconcile() also backfills against the template, so this
	-- is belt-and-suspenders — explicit here for migration auditability.
	data.stalls = data.stalls or {
		plotAnchorId          = nil,
		listings              = {},
		mailbox = {
			coins          = 0,
			items          = {},
			sales          = {},
			overflowNotice = nil,
		},
		featuredRentExpiresAt = nil,
	}

	return data
end

-- Exported for tests + tooling that wants the canonical shape.
PlayerData.defaultData = defaultData
PlayerData.migrate = migrate
PlayerData.SCHEMA_VERSION = SCHEMA_VERSION

-- ---------- ProfileService setup ------------------------------------------

-- Pending stall mutations queue (D-19). Reads happen in onPlayerAdded BEFORE
-- any other startup hook; deletes happen on successful drain.
local PENDING_STORE_NAME = "MyceliaStallPendingMutations_v1"
local pendingStore = nil
do
	local ok, store = pcall(DataStoreService.GetDataStore, DataStoreService, PENDING_STORE_NAME)
	if ok then pendingStore = store end
end

local ProfileTemplate = defaultData()
-- Existing store key from Pre-Alpha kept verbatim (don't rename — schema
-- versioning is in `data.schemaVersion`, not the store name; renaming would
-- orphan every existing save).
local ProfileStore = ProfileService.GetProfileStore(Constants.SAVE.dataStoreName, ProfileTemplate)

-- Per-player profiles, keyed by Player Instance (not UserId).
local profiles: { [Player]: any } = {}

-- ---------- Player lifecycle ----------------------------------------------

local function onPlayerAdded(player: Player)
	local profile = ProfileStore:LoadProfileAsync("u_" .. player.UserId, "ForceLoad")

	if profile == nil then
		-- Another server still holds the session lock past ForceLoad.
		-- Kick rather than start a fresh profile — instantiating defaults
		-- here would overwrite the player's real save when this server
		-- eventually saves.
		player:Kick("Couldn't load your save. Please rejoin in a moment.")
		return
	end

	profile.Data = migrate(profile.Data)
	profile:AddUserId(player.UserId)
	profile:Reconcile()    -- backfill any keys missing vs. ProfileTemplate

	profile:ListenToRelease(function()
		profiles[player] = nil
		if player:IsDescendantOf(Players) then
			player:Kick("Save data was loaded on another server.")
		end
	end)

	if not player:IsDescendantOf(Players) then
		-- Player left while we were loading. Release the lock for the next
		-- session.
		profile:Release()
		return
	end

	-- Stamp first-join timestamp + bump session counter.
	if profile.Data.auditTrail.firstJoinedAt == 0 then
		profile.Data.auditTrail.firstJoinedAt = os.time()
	end
	profile.Data.auditTrail.sessionsPlayed = (profile.Data.auditTrail.sessionsPlayed or 0) + 1

	profiles[player] = profile

	-- D-19: drain any queued stall mutations that arrived while this player
	-- was offline. MUST run BEFORE the FireClient below so the client's first
	-- frame sees the post-drain state.
	if pendingStore then
		local ok, mutations = pcall(function()
			return pendingStore:GetAsync(tostring(player.UserId))
		end)
		if ok and type(mutations) == "table" and #mutations > 0 then
			local applied, errors = PendingMutations.drain(profile.Data, mutations)
			if #errors > 0 then
				warn(string.format(
					"[PlayerData] PendingMutations drain partial for userId=%d: applied=%d errors=%s",
					player.UserId, applied, table.concat(errors, " | ")
				))
			end
			-- Atomic delete on full success only — partial failures leave the
			-- queue intact for next login.
			if applied > 0 and #errors == 0 then
				pcall(function()
					pendingStore:RemoveAsync(tostring(player.UserId))
				end)
			end
		end
	end

	-- Self-sweep any expired listings + featured slot in the loaded profile
	-- (catches things that expired while player was offline). Lazy-required
	-- to break the PlayerData↔Stall cycle (Stall requires PlayerData).
	local Stall = require(ServerScriptService.Server.Stall)
	Stall.selfSweepOnLoad(profile.Data, os.time())

	-- Initial state push so client UIs render with real data.
	Remotes.get(Constants.REMOTES.PlayerDataUpdated):FireClient(player, profile.Data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Release()
	end
	profiles[player] = nil
end

-- ---------- Public API ----------------------------------------------------

function PlayerData.get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data or nil
end

-- Mutate a player's data via callback. Fires PlayerDataUpdated immediately
-- so client UI stays in sync regardless of when the actual DataStore write
-- hits. Use this rather than mutating the table returned by `get` directly —
-- that path skips replication.
function PlayerData.update(player: Player, fn: (any) -> ())
	local profile = profiles[player]
	if not profile then
		warn("[PlayerData] update for player without profile:", player)
		return
	end
	fn(profile.Data)
	Remotes.get(Constants.REMOTES.PlayerDataUpdated):FireClient(player, profile.Data)
end

-- Force-save knob. ProfileService auto-saves on its own schedule (~30s);
-- this is for cases where the caller wants persistence before a user-visible
-- action (e.g. before TeleportService into an expedition Place).
function PlayerData.save(player: Player)
	local profile = profiles[player]
	if profile then
		profile:Save()
		profile.Data.auditTrail.lastSavedAt = os.time()
	end
end

-- Wires PlayerAdded / PlayerRemoving handlers + processes any players
-- already in-server (Studio Play Solo, hot reload). Replaces the four
-- separate Pre-Alpha lifecycle calls (onPlayerAdded, onPlayerRemoving,
-- startAutosaveLoop, saveAllOnShutdown) — autosave + shutdown handling
-- are now ProfileService's responsibility.
function PlayerData.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
end

return PlayerData
