-- Per-player potion effect registry.
--
-- Active effects are short-duration buffs (in some cases tools/cosmetics)
-- that mutate gameplay. They are server-authoritative and live in memory
-- only — they do NOT persist across sessions. (A timed buff that survives
-- a player leaving and rejoining hours later doesn't make sense for this
-- game.)
--
-- Shape of the in-memory registry, keyed by Player.UserId:
--   state[userId] = { [kind] = { magnitude = number, expiresAt = number, params = table? } }
-- where `kind` is one of the 10 supported effect kinds (see EFFECT_HANDLERS
-- below). At most one entry per kind per player; consuming a second potion
-- of the same kind during the active window applies the kind's stacking
-- rule (most are max-of, growth is min-of, cosmetic+weather replace).
--
-- Public API has two layers:
--   1. Pure helpers (apply, clear, isActive, magnitudeOf, paramsOf,
--      sweepExpired, snapshot) that operate on a plain `state` table passed
--      in by the caller. Tests exercise these directly.
--   2. Roblox-bound entry points (start, consume, growthMultiplier,
--      wildYieldBonus, harvestYieldBonus, luckBonus, revealRadius,
--      spiritAttractMultiplier, isTimeShiftActive) that wrap the pure
--      helpers around a per-module `state` table and dispatch per-kind
--      side effects via EFFECT_HANDLERS.
--
-- Spec: docs/specs/potions-and-recipes.md (effect kinds + stacking rules).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.Server.PlayerData)

local PotionEffects = {}

-- ---------- Pure helpers (testable) ---------------------------------------

-- Sets/refreshes an effect of `kind` to expire at `expiresAt` with `magnitude`
-- and optional `params` table. Returns true if this was a fresh activation
-- (no prior entry of this kind), false if it refreshed an existing one.
-- Stacking math (max-of, min-of, replace) is applied by the caller before
-- calling apply; this just stores what it's given.
function PotionEffects.apply(state, userId: number, kind: string, magnitude: number, expiresAt: number, params: any?): boolean
	local bucket = state[userId]
	if not bucket then
		bucket = {}
		state[userId] = bucket
	end
	local fresh = bucket[kind] == nil
	bucket[kind] = { magnitude = magnitude, expiresAt = expiresAt, params = params }
	return fresh
end

function PotionEffects.clear(state, userId: number, kind: string)
	local bucket = state[userId]
	if not bucket then
		return
	end
	bucket[kind] = nil
	if next(bucket) == nil then
		state[userId] = nil
	end
end

function PotionEffects.isActive(state, userId: number, kind: string, now: number): boolean
	local bucket = state[userId]
	if not bucket then
		return false
	end
	local entry = bucket[kind]
	return entry ~= nil and entry.expiresAt > now
end

-- Returns the active magnitude for (userId, kind), or `default` if no
-- non-expired entry exists.
function PotionEffects.magnitudeOf(state, userId: number, kind: string, now: number, default: number): number
	local bucket = state[userId]
	if not bucket then
		return default
	end
	local entry = bucket[kind]
	if not entry or entry.expiresAt <= now then
		return default
	end
	return entry.magnitude
end

-- Returns the active params table for (userId, kind), or nil if no
-- non-expired entry exists. Used for kinds whose effect data doesn't fit
-- in `magnitude` (cosmeticGlow's color, weatherSummon's kind string, etc.).
function PotionEffects.paramsOf(state, userId: number, kind: string, now: number)
	local bucket = state[userId]
	if not bucket then
		return nil
	end
	local entry = bucket[kind]
	if not entry or entry.expiresAt <= now then
		return nil
	end
	return entry.params
end

-- Removes any entries whose expiresAt is <= now. Returns a list of
-- (userId, kind) pairs that were just expired so the caller can run
-- per-effect cleanup hooks (reset walk speed, despawn cosmetic emitter,
-- etc.) and notify clients.
function PotionEffects.sweepExpired(state, now: number): { { userId: number, kind: string } }
	local expired = {}
	for userId, bucket in pairs(state) do
		for kind, entry in pairs(bucket) do
			if entry.expiresAt <= now then
				table.insert(expired, { userId = userId, kind = kind })
			end
		end
	end
	for _, e in ipairs(expired) do
		PotionEffects.clear(state, e.userId, e.kind)
	end
	return expired
end

-- Snapshot a player's active effects in client-friendly form.
function PotionEffects.snapshot(state, userId: number, now: number)
	local out = {}
	local bucket = state[userId]
	if not bucket then
		return out
	end
	for kind, entry in pairs(bucket) do
		if entry.expiresAt > now then
			table.insert(out, {
				kind = kind,
				magnitude = entry.magnitude,
				expiresAt = entry.expiresAt,
				params = entry.params,
			})
		end
	end
	return out
end

-- ---------- Roblox-bound state ---------------------------------------------

-- Module-level registry — the live state the server reads from. The pure
-- helpers above could be used against any table; this one is the table
-- they happen to be wired to in production.
local state: { [number]: { [string]: { magnitude: number, expiresAt: number, params: any } } } = {}

-- Per-player cosmetic ParticleEmitter we created and need to clean up.
local cosmeticEmitters: { [number]: ParticleEmitter } = {}

-- ---------- Per-kind side effects (apply/clear hooks) ----------------------

local function speedMultiplierFor(userId: number): number
	local bucket = state[userId]
	if not bucket or not bucket.speed then
		return 1.0
	end
	if bucket.speed.expiresAt <= os.time() then
		return 1.0
	end
	return bucket.speed.magnitude
end

local function applyWalkSpeed(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	humanoid.WalkSpeed = Constants.MOVEMENT.defaultWalkSpeed * speedMultiplierFor(player.UserId)
end

-- Accelerate currently-growing plots planted by `player` by `magnitude`.
-- magnitude < 1 → faster. Plots without `plantedByUserId` are skipped —
-- growth potions are intentionally "yours, not the community's".
local function accelerateGrowingPlots(player: Player, magnitude: number)
	local now = os.time()
	for _, instance in ipairs(Workspace:GetDescendants()) do
		if instance:GetAttribute("isPlot")
			and instance:GetAttribute("state") == "Growing"
			and instance:GetAttribute("plantedByUserId") == player.UserId
		then
			local ripeAt = instance:GetAttribute("ripeAt") or 0
			if ripeAt > now then
				local remaining = ripeAt - now
				local newRipe = now + math.max(1, math.floor(remaining * magnitude))
				instance:SetAttribute("ripeAt", newRipe)
			end
		end
	end
end

local function clearCosmeticGlow(userId: number)
	local emitter = cosmeticEmitters[userId]
	if emitter then
		emitter:Destroy()
		cosmeticEmitters[userId] = nil
	end
end

local function applyCosmeticGlow(player: Player, color: Color3?)
	-- One trail at a time — clear any existing emitter first.
	clearCosmeticGlow(player.UserId)

	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end

	-- Placeholder ParticleEmitter — when the user supplies the cosmetic
	-- particle texture asset, set emitter.Texture to that asset id and
	-- adjust speed/lifetime to taste. For now this gives a basic colored
	-- particle trail; the visual will be improved when assets land.
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "MyceliaCosmeticGlow"
	emitter.Color = ColorSequence.new(color or Color3.fromRGB(255, 255, 255))
	emitter.Lifetime = NumberRange.new(0.6, 1.2)
	emitter.Rate = 25
	emitter.Speed = NumberRange.new(2, 4)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.LightEmission = 0.6
	emitter.Parent = hrp

	cosmeticEmitters[player.UserId] = emitter
end

-- ---------- Effect handlers ----------------------------------------------
--
-- Each kind has:
--   stack(oldMagnitude, newMagnitude) — returns the resulting magnitude
--     when reapplying during an active duration. nil oldMagnitude means
--     fresh activation.
--   onApply(player, magnitude, params, fresh) — server-side side effect
--     run AFTER the registry entry is set.
--   onExpire(player) — server-side cleanup when the effect expires (or
--     is otherwise cleared by the sweep). Pure-query effects (luck,
--     reveal, etc.) have a no-op onExpire — Harvesting / WildSpawn etc.
--     read the magnitude live and naturally see 0/default on expiry.

local EFFECT_HANDLERS: { [string]: any } = {
	speed = {
		stack = function(old, new) return math.max(old or 1, new) end,
		onApply = function(player, magnitude, params, fresh)
			applyWalkSpeed(player)
		end,
		onExpire = function(player)
			applyWalkSpeed(player)    -- recomputes; defaults to 1× now
		end,
	},
	growth = {
		-- Better (lower) wins.
		stack = function(old, new)
			if old then return math.min(old, new) else return new end
		end,
		onApply = function(player, magnitude, params, fresh)
			-- One-shot acceleration on the player's currently-growing plots.
			-- Only on fresh activation, not refresh — otherwise drinking a
			-- second growth potion during the buff stacks the multiplier on
			-- the same plots (0.7 × 0.7 = 0.49). Refresh extends the window
			-- for new plants but doesn't re-accelerate.
			if fresh then
				accelerateGrowingPlots(player, magnitude)
			end
		end,
		onExpire = function(player) end,    -- multiplier query handles itself
	},
	wildYield = {
		stack = function(old, new) return math.max(old or 0, new) end,
		onApply = function(player, magnitude, params, fresh) end,    -- pure query
		onExpire = function(player) end,
	},
	harvestYield = {
		stack = function(old, new) return math.max(old or 0, new) end,
		onApply = function(player, magnitude, params, fresh) end,    -- pure query (Harvesting reads at harvest time)
		onExpire = function(player) end,
	},
	luck = {
		stack = function(old, new) return math.max(old or 0, new) end,
		onApply = function(player, magnitude, params, fresh) end,    -- pure query
		onExpire = function(player) end,
	},
	reveal = {
		stack = function(old, new) return math.max(old or 0, new) end,
		onApply = function(player, magnitude, params, fresh) end,
		-- Client renders hidden mushrooms within radius based on snapshot.
		-- "Hidden mushrooms" feature is content-side (Glimmerwood etc.) and
		-- unblocked but not yet populated. The flag travels regardless.
		onExpire = function(player) end,
	},
	spiritAttract = {
		stack = function(old, new) return math.max(old or 1, new) end,
		onApply = function(player, magnitude, params, fresh) end,    -- Spirits.attractionTick reads at tick time
		onExpire = function(player) end,
	},
	cosmeticGlow = {
		-- Replace: later cosmetic potion overrides earlier (one trail at a time).
		stack = function(old, new) return new end,
		onApply = function(player, magnitude, params, fresh)
			applyCosmeticGlow(player, params and params.color)
		end,
		onExpire = function(player)
			clearCosmeticGlow(player.UserId)
		end,
	},
	weatherSummon = {
		-- Replace: one weather override at a time per player.
		stack = function(old, new) return new end,
		onApply = function(player, magnitude, params, fresh)
			-- Phase 4 stub. The Weather system isn't built yet — this just
			-- logs intent. When Weather lands, replace with a call to
			-- Weather.setOverride(currentBiomeId, params.weatherKind, durationSeconds).
			warn(("[PotionEffects] weatherSummon stub for %s: %s (Weather system not yet implemented)"):format(
				player.Name, tostring(params and params.weatherKind)
			))
		end,
		onExpire = function(player) end,
	},
	timeShift = {
		-- Boolean toggle — magnitude unused. Refresh extends duration.
		stack = function(old, new) return 1 end,
		onApply = function(player, magnitude, params, fresh)
			-- Phase 4 stub. Lighting.localOverride isn't built yet — this
			-- just logs intent. When that lands, the client will get a
			-- HUD toggle button while this effect is active.
			warn(("[PotionEffects] timeShift stub for %s (Lighting.localOverride not yet implemented)"):format(player.Name))
		end,
		onExpire = function(player) end,
	},
}

-- ---------- Internal consume + notify -------------------------------------

local function notifyEffects(player: Player)
	local snap = PotionEffects.snapshot(state, player.UserId, os.time())
	Remotes.get(Constants.REMOTES.ActiveEffectsUpdated):FireClient(player, snap)
end

local function consumeInternal(player: Player, potionId: string)
	local spec = Constants.POTIONS[potionId]
	if not spec then
		return false    -- inert potion or unknown id
	end
	local handler = EFFECT_HANDLERS[spec.kind]
	if not handler then
		warn("[PotionEffects] no handler for kind: " .. tostring(spec.kind))
		return false
	end

	local data = PlayerData.get(player)
	if not data or (data.potions[potionId] or 0) < 1 then
		return false
	end

	-- Deduct potion in a single PlayerData.update so the client sees one
	-- replicated change.
	PlayerData.update(player, function(d)
		d.potions[potionId] -= 1
		if d.potions[potionId] <= 0 then
			d.potions[potionId] = nil
		end
	end)

	local now = os.time()
	local expiresAt = now + spec.durationSeconds

	-- Apply per-kind stacking rule. If an entry already exists, compute
	-- the resulting magnitude from old + new (handler decides).
	local existingMagnitude = nil
	if PotionEffects.isActive(state, player.UserId, spec.kind, now) then
		existingMagnitude = state[player.UserId][spec.kind].magnitude
	end
	local effectiveMagnitude = handler.stack(existingMagnitude, spec.magnitude)

	local fresh = PotionEffects.apply(
		state, player.UserId, spec.kind,
		effectiveMagnitude, expiresAt, spec.params
	)

	-- Run side effect AFTER state is set so onApply can see the new entry.
	handler.onApply(player, effectiveMagnitude, spec.params, fresh)

	notifyEffects(player)
	return true
end

-- ---------- Public Roblox-bound API ---------------------------------------

function PotionEffects.consume(player: Player, potionId: string): boolean
	return consumeInternal(player, potionId)
end

-- Multiplier on growthTimeSeconds at plant time. 1.0 = no buff. Lower = faster.
function PotionEffects.growthMultiplier(player: Player): number
	return PotionEffects.magnitudeOf(state, player.UserId, "growth", os.time(), 1.0)
end

-- Extra mushrooms per wild harvest. 0 = no buff.
function PotionEffects.wildYieldBonus(player: Player): number
	return PotionEffects.magnitudeOf(state, player.UserId, "wildYield", os.time(), 0)
end

-- Extra mushrooms per planted-plot harvest. 0 = no buff.
function PotionEffects.harvestYieldBonus(player: Player): number
	return PotionEffects.magnitudeOf(state, player.UserId, "harvestYield", os.time(), 0)
end

-- Additive bonus to rare-variant chance. 0.0 = no buff. Typical 0.05–0.15.
function PotionEffects.luckBonus(player: Player): number
	return PotionEffects.magnitudeOf(state, player.UserId, "luck", os.time(), 0)
end

-- Reveal-mushrooms radius in studs around the player. 0 = no reveal active.
function PotionEffects.revealRadius(player: Player): number
	return PotionEffects.magnitudeOf(state, player.UserId, "reveal", os.time(), 0)
end

-- Multiplier on spirit-attraction roll chance. 1.0 = no buff.
function PotionEffects.spiritAttractMultiplier(player: Player): number
	return PotionEffects.magnitudeOf(state, player.UserId, "spiritAttract", os.time(), 1.0)
end

-- Whether the player can currently toggle day/night on their own plots.
function PotionEffects.isTimeShiftActive(player: Player): boolean
	return PotionEffects.isActive(state, player.UserId, "timeShift", os.time())
end

-- Active weather override for the player (e.g. "Rainy"), or nil if none.
function PotionEffects.weatherSummonKind(player: Player): string?
	local params = PotionEffects.paramsOf(state, player.UserId, "weatherSummon", os.time())
	return params and params.weatherKind or nil
end

function PotionEffects.start()
	-- Client → server: "consume this potion".
	Remotes.get(Constants.REMOTES.ConsumePotion).OnServerEvent:Connect(
		function(player: Player, potionId: any)
			if typeof(potionId) ~= "string" then
				return
			end
			consumeInternal(player, potionId)
		end
	)

	-- Re-apply walk speed + cosmetic glow on character respawn so buffs
	-- survive death without callers having to reach into our registry.
	local function attachCharacterHooks(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait()    -- let Humanoid + HumanoidRootPart settle
			applyWalkSpeed(player)
			-- Re-apply cosmetic glow if active.
			if PotionEffects.isActive(state, player.UserId, "cosmeticGlow", os.time()) then
				local params = PotionEffects.paramsOf(state, player.UserId, "cosmeticGlow", os.time())
				applyCosmeticGlow(player, params and params.color)
			end
		end)
	end

	Players.PlayerAdded:Connect(attachCharacterHooks)
	for _, player in ipairs(Players:GetPlayers()) do
		attachCharacterHooks(player)
		if player.Character then
			applyWalkSpeed(player)
		end
	end

	-- Players leaving: drop their state + clean up any cosmetic emitter.
	Players.PlayerRemoving:Connect(function(player)
		clearCosmeticGlow(player.UserId)
		state[player.UserId] = nil
	end)

	-- Heartbeat-driven expiry sweep. ~2x/sec is plenty for buffs measured
	-- in tens of seconds; cheaper than every frame, more responsive than
	-- per-second.
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		local expired = PotionEffects.sweepExpired(state, os.time())
		if #expired == 0 then
			return
		end
		-- Group by userId to fire one update per affected player and run
		-- per-kind cleanup hooks.
		local affected: { [number]: boolean } = {}
		for _, e in ipairs(expired) do
			affected[e.userId] = true
			local handler = EFFECT_HANDLERS[e.kind]
			if handler then
				local player = Players:GetPlayerByUserId(e.userId)
				if player then
					handler.onExpire(player)
				end
			end
		end
		for userId in pairs(affected) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				notifyEffects(player)
			end
		end
	end)
end

return PotionEffects
