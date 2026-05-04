-- Reputation shim. Phase 2 placeholder for the full Reputation system that
-- lands later in Phase 2 / early Phase 3.
--
-- Why a shim: merchant configs in Constants.MERCHANTS reference a
-- `reputationKey` field, and shop transactions in Shop.luau call
-- Reputation.add() on every successful sale or purchase. By exposing those
-- entry points now we can wire the call sites against a stable API and
-- avoid a refactor when the real system ships. The full implementation
-- will replace this module in-place — same function signatures, same
-- module path — and every existing call site lights up automatically.
--
-- Currently this module:
--   - Reputation.add: logs the delta to Output, does NOT mutate save data.
--   - Reputation.get: defensive read of data.reputation[key].score (this
--     works today because the v3 save schema already provisions the field;
--     Travel.luau also reads it directly to compute total renown).
--
-- See docs/specs/shop-ui.md "Reputation shim" for the full migration plan.

local Reputation = {}

-- Log-only stub. Replace with a real `data.reputation[key].score += delta`
-- mutation (and tier-up event firing) when the Reputation system ships.
function Reputation.add(player: Player, key: string, delta: number)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then return end
	if type(key) ~= "string" or key == "" then return end
	if type(delta) ~= "number" or delta == 0 then return end
	print(string.format("[Reputation] +%.2f %s for %s", delta, key, player.Name))
end

-- Defensive read: returns 0 when the player has no rep entry for this key.
-- Safe to call against malformed save data, missing-data, or never-met NPCs.
function Reputation.get(data, key: string): number
	if not data or type(data) ~= "table" then return 0 end
	if type(key) ~= "string" or key == "" then return 0 end
	local rep = data.reputation
	if type(rep) ~= "table" then return 0 end
	local entry = rep[key]
	if type(entry) ~= "table" then return 0 end
	local score = entry.score
	if type(score) ~= "number" then return 0 end
	return score
end

return Reputation
