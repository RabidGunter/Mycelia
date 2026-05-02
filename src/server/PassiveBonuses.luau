-- Per-player permanent (untimed) bonus registry.
--
-- Spirits and (later) gamepasses + achievement rewards contribute *permanent*
-- bonuses while equipped/owned. PotionEffects.lua is for *timed* effects;
-- this module is the symmetric one for the no-expiry flavor. Both expose
-- the same `(kind) -> magnitude` interface so gameplay code can read both
-- transparently and combine them additively.
--
-- For Phase 1, only spirits feed bonuses in. The recompute pass walks the
-- player's active spirit roster and sums per-kind magnitudes from
-- Constants.SPIRITS.bonuses. Future sources slot into the same recompute.
--
-- Spec: docs/specs/spirits.md "PassiveBonuses module".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local PlayerData = require(ServerScriptService.Server.PlayerData)

local PassiveBonuses = {}

-- registry[player] = { [kind] = total magnitude }
local registry: { [Player]: { [string]: number } } = {}

-- ---------- Pure helpers (testable) --------------------------------------

-- Sum spirit-roster contributions from a save data table. Returns
-- { [kind] = magnitude }. Doesn't touch any Roblox state — testable.
function PassiveBonuses.sumFromSpirits(data, spiritsConfig)
	local totals: { [string]: number } = {}
	if not data or not data.spirits or not data.spirits.activeRoster then
		return totals
	end
	local bonuses = spiritsConfig.bonuses
	for _, uniqueId in ipairs(data.spirits.activeRoster) do
		local entry = data.spirits.allOwned and data.spirits.allOwned[uniqueId]
		if entry then
			local def = bonuses[entry.spiritType]
			if def then
				totals[def.kind] = (totals[def.kind] or 0) + def.magnitude
			end
		end
	end
	return totals
end

-- ---------- Roblox-bound API ---------------------------------------------

function PassiveBonuses.recomputeForPlayer(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end

	-- Future: layer in gamepass bonuses, achievement bonuses, etc. here.
	local totals = PassiveBonuses.sumFromSpirits(data, Constants.SPIRITS)

	registry[player] = totals
	Remotes.get(Constants.REMOTES.PassiveBonusesUpdated):FireClient(player, totals)
end

-- Returns the additive magnitude for a kind, or 0 if no bonus is active.
-- Gameplay code reads this and combines with PotionEffects via additive
-- formulas like `total = PassiveBonuses.get(p, "wildYield") + PotionEffects.wildYieldBonus(p)`.
function PassiveBonuses.get(player: Player, kind: string): number
	local totals = registry[player]
	return totals and (totals[kind] or 0) or 0
end

-- Convenience: growth-speed bonus expressed as a multiplier (1 - bonus).
-- Spritefly's 0.05 growthSpeed → 0.95 multiplier (5% faster).
function PassiveBonuses.growthSpeedMultiplier(player: Player): number
	return 1 - PassiveBonuses.get(player, "growthSpeed")
end

function PassiveBonuses.start()
	-- Recompute on player join after PlayerData is ready. We can't hook
	-- the same PlayerAdded as PlayerData.start (no ordering guarantee
	-- between handlers); instead, defer briefly and check that data exists.
	Players.PlayerAdded:Connect(function(player)
		task.wait(0.5)
		if PlayerData.get(player) then
			PassiveBonuses.recomputeForPlayer(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		registry[player] = nil
	end)

	-- Players already in (Studio Play Solo, server hot-reload) — recompute
	-- once their PlayerData is loaded.
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			task.wait(0.5)
			if PlayerData.get(player) then
				PassiveBonuses.recomputeForPlayer(player)
			end
		end)
	end
end

return PassiveBonuses
