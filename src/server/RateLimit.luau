-- Per-player per-remote rate limiter shared by all Phase 2 stall remote
-- handlers (D-21). Used by Stall.start in PLAN 02b. Returns true if the call
-- is permitted, false if within the cooldown window.
--
-- Internal state: lastCallAt[remoteName][userId] = os.clock() of last allowed call.
--
-- Caller pattern (PLAN 02b):
--   if not RateLimit.check(player, "BuyListing", Constants.STALL.rateLimits.BuyListing) then
--       Remotes.get(Constants.REMOTES.StallTransactionCompleted):FireClient(player, {
--           success = false, code = "RATE_LIMITED", action = "buy",
--       })
--       return
--   end

local RateLimit = {}

local lastCallAt: { [string]: { [number]: number } } = {}

function RateLimit.check(player, remoteName, intervalSeconds)
	-- Defensive: handle bad inputs without crashing the calling handler.
	if player == nil then return false end
	local userId
	if type(player) == "table" then
		userId = player.UserId
	elseif typeof(player) == "Instance" then
		userId = player.UserId
	end
	if type(userId) ~= "number" then return false end
	if type(remoteName) ~= "string" or remoteName == "" then return false end
	if type(intervalSeconds) ~= "number" or intervalSeconds < 0 then return false end

	local now = os.clock()
	local bucket = lastCallAt[remoteName]
	if not bucket then
		bucket = {}
		lastCallAt[remoteName] = bucket
	end
	local last = bucket[userId]
	if last and (now - last) < intervalSeconds then
		return false
	end
	bucket[userId] = now
	return true
end

-- Test-only: clear all cooldown state. NOT used by production code.
function RateLimit._reset()
	lastCallAt = {}
end

return RateLimit
