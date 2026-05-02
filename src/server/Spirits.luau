-- Forest Spirit attraction + claim + roster + wander system.
--
-- Player attracts spirits passively by holding/growing specific mushroom
-- species. On a successful attraction roll, server spawns the spirit's
-- world Model near the player's hut/spawn area; player walks up + presses
-- E to claim into their roster (default cap 3). Active-roster spirits
-- spawn idle Models in the world that wander randomly, and contribute
-- permanent bonuses via PassiveBonuses.lua.
--
-- Architecture:
--   * `attractionLoop` — Heartbeat tick every Constants.SPIRITS.attractionTickSeconds.
--   * `spawn(player, spiritId)` — instantiates the world Model from
--     ReplicatedStorage.SpiritModels.<spiritId>:Clone(), sets attributes,
--     adds ProximityPrompt, schedules despawn timer.
--   * `claim` remote handler — atomic claim-and-revert pattern (handles
--     race where two players try to claim simultaneously, even though
--     spawnedFor restricts to one player by design).
--   * `equip` / `unequip` remote handlers — move spirit between active
--     roster and "owned but inactive" buckets in PlayerData.
--   * `wander` Heartbeat tick — drives idle/walking AI per active world spirit.
--
-- Spirit Models are user-supplied at ReplicatedStorage.SpiritModels.<spiritId>.
-- If a Model is missing for a given spirit type, spawn calls log a warning
-- and skip — the rest of the system functions normally; the spirit just
-- never visibly appears until you supply the Model.
--
-- Spec: docs/specs/spirits.md.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.Server.PlayerData)
local PassiveBonuses = require(ServerScriptService.Server.PassiveBonuses)
local PotionEffects = require(ServerScriptService.Server.PotionEffects)

local Spirits = {}

-- ---------- Pure helpers (testable) --------------------------------------

-- Compute roster cap for a player given their save data.
function Spirits.rosterCapForData(data, spiritsConfig): number
	local cap = spiritsConfig.startingRosterSize
	if data and data.gamepassesOwned and data.gamepassesOwned.BiggerSpiritRoster then
		cap = cap + spiritsConfig.biggerRosterGamepassBonus
	end
	return cap
end

-- Gather species that contribute to attraction rolls — inventory + plots.
-- Returns a deduplicated set: { [speciesId] = true }.
function Spirits.holdingsFromData(data): { [string]: boolean }
	local set: { [string]: boolean } = {}
	if not data then return set end
	for speciesId, count in pairs(data.inventory or {}) do
		if count and count > 0 then
			set[speciesId] = true
		end
	end
	for _, plot in pairs(data.plots or {}) do
		if plot and plot.speciesId and (plot.state == "Growing" or plot.state == "Ripe") then
			set[plot.speciesId] = true
		end
	end
	return set
end

-- Per-tick attraction probability for a single spirit type, given holdings
-- and the optional spiritAttract potion multiplier.
function Spirits.attractionChancePerTick(
	spiritId: string,
	holdings: { [string]: boolean },
	spiritsConfig,
	tickSeconds: number,
	potionMultiplier: number
): number
	local map = spiritsConfig.attractionMap[spiritId]
	if not map then return 0 end
	local chancePerHour = 0
	for speciesId in pairs(holdings) do
		chancePerHour = chancePerHour + (map[speciesId] or 0)
	end
	local ticksPerHour = 3600 / tickSeconds
	return (chancePerHour / ticksPerHour) * (potionMultiplier or 1)
end

-- ---------- Roblox-bound state -------------------------------------------

-- Active world spirits we've spawned, indexed by Model so wander tick can
-- find them. Also indexed by uniqueId for despawn-on-trade lookups.
local worldSpirits: {
	[Model]: {
		player: Player,
		spiritType: string,
		uniqueId: string?,    -- nil for unclaimed spirits
		state: string,        -- "Idle" | "Walking"
		target: Vector3?,
		homePoint: Vector3,
		wanderRadius: number,
		idleUntil: number,
	},
} = {}

-- ---------- Helpers -------------------------------------------------------

local function getSpiritModelTemplate(spiritId: string): Model?
	local container = ReplicatedStorage:FindFirstChild("SpiritModels")
	if not container then
		return nil
	end
	local template = container:FindFirstChild(spiritId)
	if not template or not template:IsA("Model") then
		return nil
	end
	return template
end

local function getHomePointForPlayer(player: Player): Vector3
	-- Prefer the player's hut interior; fallback to spawn area near origin.
	-- (Hut system isn't built yet — Phase 3 — so we always fall back for now.)
	-- Spec calls for spawn near plots if no hut.
	local character = player.Character
	if character and character.PrimaryPart then
		return character.PrimaryPart.Position
	end
	return Vector3.new(0, 5, 0)    -- spawn fallback
end

local function pickPointInRadius(center: Vector3, radius: number): Vector3
	local angle = math.random() * math.pi * 2
	local r = math.sqrt(math.random()) * radius    -- uniform area distribution
	return center + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
end

local function rosterCapForPlayer(player: Player): number
	return Spirits.rosterCapForData(PlayerData.get(player), Constants.SPIRITS)
end

-- ---------- Spawn (attraction-driven, unclaimed) -------------------------

function Spirits.spawn(player: Player, spiritId: string)
	local template = getSpiritModelTemplate(spiritId)
	if not template then
		warn(("[Spirits] No Model template at ReplicatedStorage.SpiritModels.%s — skipping spawn"):format(spiritId))
		return
	end

	local model = template:Clone()
	model.Name = "WildSpirit_" .. spiritId

	-- Place near player's home/plot point.
	local homePoint = getHomePointForPlayer(player)
	local spawnPoint = pickPointInRadius(homePoint, 12)
	if model.PrimaryPart then
		model:PivotTo(CFrame.new(spawnPoint))
	else
		-- Without PrimaryPart we can't move it cleanly. Try to find a base.
		local first = model:FindFirstChildWhichIsA("BasePart")
		if first then
			first.Position = spawnPoint
		end
	end

	model:SetAttribute("isUnclaimedSpirit", true)
	model:SetAttribute("spawnedFor", player.UserId)
	model:SetAttribute("spiritType", spiritId)
	model:SetAttribute("spawnedAt", os.time())

	-- Add a claim prompt to the PrimaryPart (or first BasePart).
	local promptParent = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if promptParent then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "ClaimSpiritPrompt"
		prompt.ActionText = "Claim"
		prompt.ObjectText = spiritId
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Constants.SPIRITS.claimRange
		prompt.RequiresLineOfSight = false
		prompt.Parent = promptParent
	end

	model.Parent = Workspace

	-- Track for AI tick (unclaimed spirits also wander idly).
	local rarity = Constants.SPIRITS.rarity[spiritId] or "Common"
	worldSpirits[model] = {
		player = player,
		spiritType = spiritId,
		uniqueId = nil,
		state = "Idle",
		target = nil,
		homePoint = spawnPoint,
		wanderRadius = (rarity == "Rare" or rarity == "Legendary")
			and Constants.SPIRITS.wanderRadiusRare
			or Constants.SPIRITS.wanderRadiusCommon,
		idleUntil = 0,
	}

	-- Schedule despawn if not claimed in time.
	task.delay(Constants.SPIRITS.unclaimedDespawnSeconds, function()
		if model:GetAttribute("isUnclaimedSpirit") then
			worldSpirits[model] = nil
			model:Destroy()
		end
	end)
end

-- ---------- Claim flow (remote handler) -----------------------------------

local function handleClaim(player: Player, spiritWorldInstance: any)
	if typeof(spiritWorldInstance) ~= "Instance" then return end
	if not spiritWorldInstance:IsDescendantOf(Workspace) then return end

	-- Atomic check-and-set: this whole block runs synchronously, so no
	-- other handler thread can interleave between read and write.
	if spiritWorldInstance:GetAttribute("isUnclaimedSpirit") ~= true then
		return    -- already claimed or despawned
	end
	spiritWorldInstance:SetAttribute("isUnclaimedSpirit", false)

	local function revertAndReturn()
		-- Validation failed — make the spirit claimable again.
		spiritWorldInstance:SetAttribute("isUnclaimedSpirit", true)
	end

	-- Targeted player only.
	if spiritWorldInstance:GetAttribute("spawnedFor") ~= player.UserId then
		return revertAndReturn()
	end

	-- Within range.
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return revertAndReturn()
	end
	local instancePos = spiritWorldInstance:GetPivot().Position
	if (hrp.Position - instancePos).Magnitude > Constants.SPIRITS.claimRange then
		return revertAndReturn()
	end

	local data = PlayerData.get(player)
	if not data then
		return revertAndReturn()
	end

	-- Roster cap.
	if #data.spirits.activeRoster >= rosterCapForPlayer(player) then
		Remotes.get(Constants.REMOTES.SpiritClaimCompleted):FireClient(player, {
			success = false, reason = "rosterFull",
		})
		return revertAndReturn()
	end

	-- All checks pass — mutate state.
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

	-- Tear down world Model and hand over to "active roster" representation.
	worldSpirits[spiritWorldInstance] = nil
	spiritWorldInstance:Destroy()

	-- Spawn the active-roster Model for this spirit (the "your spirit
	-- wandering near your hut" representation).
	Spirits.spawnActiveSpirit(player, uniqueId, spiritId)

	-- Recompute permanent bonuses.
	PassiveBonuses.recomputeForPlayer(player)

	Remotes.get(Constants.REMOTES.SpiritClaimCompleted):FireClient(player, {
		success = true, spiritId = spiritId, uniqueId = uniqueId,
	})
end

-- ---------- Active-roster spawn / despawn --------------------------------

function Spirits.spawnActiveSpirit(player: Player, uniqueId: string, spiritType: string)
	local template = getSpiritModelTemplate(spiritType)
	if not template then
		warn(("[Spirits] No Model template for active-roster %s — spirit invisible until template added"):format(spiritType))
		return
	end

	local model = template:Clone()
	model.Name = "ActiveSpirit_" .. spiritType
	model:SetAttribute("isActiveSpirit", true)
	model:SetAttribute("ownerUserId", player.UserId)
	model:SetAttribute("uniqueId", uniqueId)
	model:SetAttribute("spiritType", spiritType)

	local homePoint = getHomePointForPlayer(player)
	if model.PrimaryPart then
		model:PivotTo(CFrame.new(homePoint))
	else
		local first = model:FindFirstChildWhichIsA("BasePart")
		if first then first.Position = homePoint end
	end
	model.Parent = Workspace

	local rarity = Constants.SPIRITS.rarity[spiritType] or "Common"
	worldSpirits[model] = {
		player = player,
		spiritType = spiritType,
		uniqueId = uniqueId,
		state = "Idle",
		target = nil,
		homePoint = homePoint,
		wanderRadius = (rarity == "Rare" or rarity == "Legendary")
			and Constants.SPIRITS.wanderRadiusRare
			or Constants.SPIRITS.wanderRadiusCommon,
		idleUntil = 0,
	}
end

function Spirits.spawnActiveRosterForPlayer(player: Player)
	local data = PlayerData.get(player)
	if not data or not data.spirits or not data.spirits.activeRoster then
		return
	end
	for _, uniqueId in ipairs(data.spirits.activeRoster) do
		local entry = data.spirits.allOwned[uniqueId]
		if entry then
			Spirits.spawnActiveSpirit(player, uniqueId, entry.spiritType)
		end
	end
end

function Spirits.despawnActiveRosterForPlayer(player: Player)
	for model, info in pairs(worldSpirits) do
		if info.player == player and info.uniqueId ~= nil then
			worldSpirits[model] = nil
			model:Destroy()
		end
	end
end

local function despawnByUniqueId(uniqueId: string)
	for model, info in pairs(worldSpirits) do
		if info.uniqueId == uniqueId then
			worldSpirits[model] = nil
			model:Destroy()
			return
		end
	end
end

-- ---------- Equip / unequip ----------------------------------------------

local function handleEquip(player: Player, uniqueId: any)
	if typeof(uniqueId) ~= "string" then return end
	local data = PlayerData.get(player)
	if not data then return end
	local entry = data.spirits.allOwned[uniqueId]
	if not entry then return end

	-- Already in active roster?
	for _, id in ipairs(data.spirits.activeRoster) do
		if id == uniqueId then return end
	end

	-- Roster space?
	if #data.spirits.activeRoster >= rosterCapForPlayer(player) then
		return
	end

	PlayerData.update(player, function(d)
		table.insert(d.spirits.activeRoster, uniqueId)
	end)

	Spirits.spawnActiveSpirit(player, uniqueId, entry.spiritType)
	PassiveBonuses.recomputeForPlayer(player)
end

local function handleUnequip(player: Player, uniqueId: any)
	if typeof(uniqueId) ~= "string" then return end
	local data = PlayerData.get(player)
	if not data then return end

	-- Find + remove from activeRoster.
	local removed = false
	PlayerData.update(player, function(d)
		for i, id in ipairs(d.spirits.activeRoster) do
			if id == uniqueId then
				table.remove(d.spirits.activeRoster, i)
				removed = true
				break
			end
		end
	end)

	if removed then
		despawnByUniqueId(uniqueId)
		PassiveBonuses.recomputeForPlayer(player)
	end
end

-- ---------- Attraction tick ----------------------------------------------

local function rollAttractionForPlayer(player: Player)
	local data = PlayerData.get(player)
	if not data then return end
	-- Skip if roster is full — no point spawning a spirit they can't claim.
	if #data.spirits.activeRoster >= rosterCapForPlayer(player) then return end

	local holdings = Spirits.holdingsFromData(data)
	local potionMul = PotionEffects.spiritAttractMultiplier(player)
	local tickSeconds = Constants.SPIRITS.attractionTickSeconds

	for spiritId in pairs(Constants.SPIRITS.attractionMap) do
		local chance = Spirits.attractionChancePerTick(
			spiritId, holdings, Constants.SPIRITS, tickSeconds, potionMul
		)
		if chance > 0 and math.random() < chance then
			Spirits.spawn(player, spiritId)
		end
	end
end

local function startAttractionLoop()
	task.spawn(function()
		while true do
			task.wait(Constants.SPIRITS.attractionTickSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				rollAttractionForPlayer(player)
			end
		end
	end)
end

-- ---------- Wander AI ----------------------------------------------------

local function tickWanderAI(dt: number)
	local now = os.time()
	for model, info in pairs(worldSpirits) do
		if not model.Parent then
			worldSpirits[model] = nil
			continue
		end
		local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if not primary then continue end

		if info.state == "Idle" then
			if now < info.idleUntil then continue end
			-- 20% chance per second to start walking; tick rate is dt-driven.
			if math.random() < (0.2 * dt) then
				info.target = pickPointInRadius(info.homePoint, info.wanderRadius)
				info.state = "Walking"
			end
		elseif info.state == "Walking" and info.target then
			local pos = primary.Position
			local toTarget = info.target - pos
			toTarget = Vector3.new(toTarget.X, 0, toTarget.Z)    -- keep Y stable
			local dist = toTarget.Magnitude
			if dist < 1 then
				info.state = "Idle"
				info.target = nil
				info.idleUntil = now + math.random(5, 10)
			else
				local step = math.min(dist, Constants.SPIRITS.walkSpeed * dt)
				local newPos = pos + toTarget.Unit * step
				if model.PrimaryPart then
					model:PivotTo(CFrame.lookAt(newPos, newPos + toTarget.Unit))
				else
					primary.Position = newPos
				end
			end
		end
	end
end

-- ---------- Public API + start -------------------------------------------

function Spirits.rosterCapForPlayer(player: Player): number
	return rosterCapForPlayer(player)
end

function Spirits.start()
	-- Remote handlers.
	Remotes.get(Constants.REMOTES.ClaimSpirit).OnServerEvent:Connect(handleClaim)
	Remotes.get(Constants.REMOTES.EquipSpirit).OnServerEvent:Connect(handleEquip)
	Remotes.get(Constants.REMOTES.UnequipSpirit).OnServerEvent:Connect(handleUnequip)

	-- Player lifecycle: spawn active-roster spirits on join, despawn on leave.
	-- Defer briefly so PlayerData has loaded.
	Players.PlayerAdded:Connect(function(player)
		task.wait(0.6)
		if PlayerData.get(player) then
			Spirits.spawnActiveRosterForPlayer(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		Spirits.despawnActiveRosterForPlayer(player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			task.wait(0.6)
			if PlayerData.get(player) then
				Spirits.spawnActiveRosterForPlayer(player)
			end
		end)
	end

	-- Attraction loop (5min default).
	startAttractionLoop()

	-- Wander AI loop (Heartbeat).
	RunService.Heartbeat:Connect(tickWanderAI)
end

return Spirits
