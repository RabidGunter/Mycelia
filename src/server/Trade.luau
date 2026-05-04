-- Two-player Trading Post backend.
--
-- Manages active trade sessions in memory + an immutable audit log on a
-- separate DataStore. Atomic execution: both players' inventories mutate
-- in a single tick, with snapshot-rollback if either side fails.
--
-- State machine:
--   Pending → Open → Locked → Completed
--                ↑       ↓
--                +-------+ (UpdateOffer reverts Locked → Open)
--   Cancelled is a terminal state reachable from any non-terminal.
--
-- Spec: docs/specs/trading-post.md.
-- Wire-level remotes: docs/specs/remote-api.md §281–381.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(ServerScriptService.Server.Inventory)
local PlayerData = require(ServerScriptService.Server.PlayerData)
local Exchange = require(ServerScriptService.Server.Exchange)

local Trade = {}

-- ---------- Tunables -------------------------------------------------------

local LOCK_COUNTDOWN_SECONDS = 5
local REQUEST_COOLDOWN_SECONDS = 20
local MAX_OFFER_ITEMS = 6              -- distinct itemIds per side
local MAX_COIN_OFFERING = 1e9          -- sanity cap (well below 64-bit limits)
local REQUEST_TIMEOUT_SECONDS = 30     -- target auto-declines after this

-- ---------- State ----------------------------------------------------------

-- Active session table. Key = sessionId, Value = TradeSession.
local sessions: { [string]: any } = {}

-- Reverse index: [userId] = sessionId. Lets us answer "is this player in a
-- trade?" in O(1). Both sides of every active session are listed.
local playerSession: { [number]: string } = {}

-- Per-player request cooldown timestamp. [userId] = os.time() of last RequestTrade.
local lastRequestAt: { [number]: number } = {}

-- Pending requests waiting for the target's Accept/Decline. [sessionId] = expiry.
local pendingExpiry: { [string]: number } = {}

-- ---------- Pure helpers ---------------------------------------------------

local function emptyOffer()
	return { coins = 0, items = {} }
end

-- True if `data` has at least `qty` of `itemId` (mushroom species or
-- non-mushroom item) reachable for trading. Mushrooms come from legacy
-- data.inventory; everything else from data.inventoryByCategory[*].
function Trade.hasItem(data, itemId: string, qty: number): boolean
	if type(data) ~= "table" or type(itemId) ~= "string" then return false end
	if type(qty) ~= "number" or qty <= 0 then return false end
	if Species.byId[itemId] then
		return Inventory.count(data.inventory or {}, itemId) >= qty
	end
	local def = Constants.ITEMS[itemId]
	if not def or def.tradable == false then return false end
	local bucket = data.inventoryByCategory and data.inventoryByCategory[def.category]
	if type(bucket) ~= "table" then return false end
	return (bucket[itemId] or 0) >= qty
end

-- Validate an offer against a player's data. Returns (ok, code).
function Trade.validateOffer(offer, data): (boolean, string)
	if type(offer) ~= "table" then return false, "INVALID_REQUEST" end
	if type(offer.coins) ~= "number" or offer.coins < 0 or offer.coins > MAX_COIN_OFFERING then
		return false, "INVALID_REQUEST"
	end
	if offer.coins ~= math.floor(offer.coins) then return false, "INVALID_REQUEST" end
	if (data.coins or 0) < offer.coins then return false, "INSUFFICIENT_COINS" end

	if type(offer.items) ~= "table" then return false, "INVALID_REQUEST" end
	local itemCount = 0
	for itemId, qty in pairs(offer.items) do
		itemCount += 1
		if itemCount > MAX_OFFER_ITEMS then return false, "TOO_MANY_ITEMS" end
		if type(itemId) ~= "string" then return false, "INVALID_REQUEST" end
		if type(qty) ~= "number" or qty <= 0 or qty ~= math.floor(qty) then
			return false, "INVALID_REQUEST"
		end
		if not Trade.hasItem(data, itemId, qty) then
			return false, "INSUFFICIENT_INVENTORY"
		end
	end
	return true, "OK"
end

-- Pure mutation: subtract `give` from data, add `receive` to data. Returns
-- nothing; mutates in place. Caller wraps in PlayerData.update.
--
-- Refactored 2026-05-03 to delegate to Exchange.applyOneSided per docs/specs/
-- player-stalls.md §16 (D-02). Preserves public API for TradeSpec.
function Trade.applyOffer(data, give, receive)
	Exchange.applyOneSided(data, give, receive)
end

-- Returns (ok, code). Pure check before allowing RequestTrade. `now` and
-- `cooldownTable` parameters keep this testable without mocking os.time.
function Trade.canRequest(senderUserId, targetUserId, activeSessionsByUser, cooldownByUser, now): (boolean, string)
	if senderUserId == targetUserId then return false, "SELF_TRADE" end
	if activeSessionsByUser[senderUserId] then return false, "ALREADY_IN_TRADE" end
	if activeSessionsByUser[targetUserId] then return false, "ALREADY_IN_TRADE" end
	local last = cooldownByUser[senderUserId] or 0
	if now - last < REQUEST_COOLDOWN_SECONDS then return false, "COOLDOWN" end
	return true, "OK"
end

-- ---------- Session helpers (Roblox-bound) --------------------------------

local function newSessionId(): string
	if HttpService and HttpService.GenerateGUID then
		return HttpService:GenerateGUID(false)
	end
	return tostring(os.time()) .. "_" .. tostring(math.random(1, 1e9))
end

local function clientView(session, forUserId: number)
	-- The payload sent to either client. We send both sides' state but
	-- label "you" / "them" implicitly via the Player references.
	return {
		sessionId = session.sessionId,
		state     = session.state,
		you       = session.a.player.UserId == forUserId and {
			player = session.a.player,
			offer = session.a.offer,
			locked = session.a.locked,
			confirmed = session.a.confirmed,
		} or {
			player = session.b.player,
			offer = session.b.offer,
			locked = session.b.locked,
			confirmed = session.b.confirmed,
		},
		them      = session.a.player.UserId == forUserId and {
			player = session.b.player,
			offer = session.b.offer,
			locked = session.b.locked,
			confirmed = session.b.confirmed,
		} or {
			player = session.a.player,
			offer = session.a.offer,
			locked = session.a.locked,
			confirmed = session.a.confirmed,
		},
		lockedAt = session.lockedAt,
		countdownSeconds = LOCK_COUNTDOWN_SECONDS,
	}
end

local function broadcast(session)
	local rem = Remotes.get(Constants.REMOTES.TradeOfferUpdated)
	rem:FireClient(session.a.player, clientView(session, session.a.player.UserId))
	rem:FireClient(session.b.player, clientView(session, session.b.player.UserId))
end

local function clearSession(session)
	sessions[session.sessionId] = nil
	pendingExpiry[session.sessionId] = nil
	if session.a and session.a.player then
		playerSession[session.a.player.UserId] = nil
	end
	if session.b and session.b.player then
		playerSession[session.b.player.UserId] = nil
	end
end

local function writeAudit(session, outcome, code)
	local function offerSnapshot(side)
		return {
			coins = side.offer.coins or 0,
			items = side.offer.items or {},
		}
	end
	-- kind = "trade" per Exchange's audit taxonomy (post-2026-05-03 refactor).
	-- sessionId is what Exchange.writeAudit uses to derive the DataStore key.
	Exchange.writeAudit(Exchange.buildAuditEntry("trade", {
		sessionId    = session.sessionId,
		outcome      = outcome,
		cancelReason = code,
		a = {
			userId = session.a.player and session.a.player.UserId or 0,
			name   = session.a.player and session.a.player.Name or "",
			gave   = offerSnapshot(session.a),
			got    = offerSnapshot(session.b),
		},
		b = {
			userId = session.b.player and session.b.player.UserId or 0,
			name   = session.b.player and session.b.player.Name or "",
			gave   = offerSnapshot(session.b),
			got    = offerSnapshot(session.a),
		},
	}))
end

local function fireCompleted(session, success, code)
	local rem = Remotes.get(Constants.REMOTES.TradeCompleted)
	for _, side in ipairs({ session.a, session.b }) do
		if side.player and side.player.Parent then
			rem:FireClient(side.player, {
				sessionId = session.sessionId,
				success = success,
				code = code,
			})
		end
	end
end

local function endSession(session, outcome: string, code: string)
	session.state = (outcome == "completed") and "Completed" or "Cancelled"
	writeAudit(session, outcome, code)
	fireCompleted(session, outcome == "completed", code)
	clearSession(session)
end

-- ---------- Atomic execution ----------------------------------------------
--
-- Refactored 2026-05-03 to use Exchange.snapshotData / Exchange.restoreFromSnapshot
-- per docs/specs/player-stalls.md §16 (D-02). Roblox-bound PlayerData.update
-- wrapping stays here at the call site; Exchange's helpers operate on plain
-- `data` tables.

local function snapshotPlayer(player: Player)
	local data = PlayerData.get(player)
	if not data then return nil end
	return Exchange.snapshotData(data)
end

local function restorePlayer(player: Player, snap)
	if not snap then return end
	PlayerData.update(player, function(d)
		Exchange.restoreFromSnapshot(d, snap)
	end)
end

local function executeAtomic(session): (boolean, string)
	local pa, pb = session.a.player, session.b.player
	if not pa or not pa.Parent or not pb or not pb.Parent then
		return false, "PLAYER_DISCONNECTED"
	end

	local dataA = PlayerData.get(pa)
	local dataB = PlayerData.get(pb)
	if not dataA or not dataB then return false, "PLAYER_DISCONNECTED" end

	-- Re-validate both offers against current state.
	local okA, codeA = Trade.validateOffer(session.a.offer, dataA)
	if not okA then return false, codeA end
	local okB, codeB = Trade.validateOffer(session.b.offer, dataB)
	if not okB then return false, codeB end

	local snapA = snapshotPlayer(pa)
	local snapB = snapshotPlayer(pb)

	-- Mutate A: gives offerA, receives offerB.
	local okMutA = pcall(function()
		PlayerData.update(pa, function(d)
			Exchange.applyOneSided(d, session.a.offer, session.b.offer)
		end)
	end)
	if not okMutA then
		restorePlayer(pa, snapA)
		return false, "MUTATION_FAILED"
	end

	-- Mutate B: gives offerB, receives offerA. If this fails, roll back A.
	local okMutB = pcall(function()
		PlayerData.update(pb, function(d)
			Exchange.applyOneSided(d, session.b.offer, session.a.offer)
		end)
	end)
	if not okMutB then
		restorePlayer(pa, snapA)
		restorePlayer(pb, snapB)
		return false, "MUTATION_FAILED"
	end

	return true, "OK"
end

-- ---------- Remote handlers ------------------------------------------------

local function handleRequest(player: Player, targetPlayer: any)
	if typeof(targetPlayer) ~= "Instance" or not targetPlayer:IsA("Player") then return end
	local senderId = player.UserId
	local targetId = targetPlayer.UserId

	local ok, code = Trade.canRequest(senderId, targetId, playerSession, lastRequestAt, os.time())
	if not ok then
		-- Light-touch error toast via TradeCompleted with success=false and a synthetic sessionId.
		Remotes.get(Constants.REMOTES.TradeCompleted):FireClient(player, {
			success = false, code = code, sessionId = "",
		})
		return
	end
	lastRequestAt[senderId] = os.time()

	local sessionId = newSessionId()
	local session = {
		sessionId = sessionId,
		state = "Pending",
		a = { player = player, offer = emptyOffer(), locked = false, confirmed = false },
		b = { player = targetPlayer, offer = emptyOffer(), locked = false, confirmed = false },
		createdAt = os.time(),
	}
	sessions[sessionId] = session
	playerSession[senderId] = sessionId
	playerSession[targetId] = sessionId
	pendingExpiry[sessionId] = os.time() + REQUEST_TIMEOUT_SECONDS

	Remotes.get(Constants.REMOTES.TradeRequestReceived):FireClient(targetPlayer, {
		sessionId = sessionId,
		fromPlayer = player,
	})
end

local function handleRespond(player: Player, sessionId: any, accept: any)
	if type(sessionId) ~= "string" then return end
	local session = sessions[sessionId]
	if not session or session.state ~= "Pending" then return end
	if session.b.player ~= player then return end  -- only target can respond
	if not accept then
		endSession(session, "cancelled", "DECLINED")
		return
	end
	session.state = "Open"
	pendingExpiry[sessionId] = nil
	Remotes.get(Constants.REMOTES.TradeSessionStarted):FireClient(session.a.player, clientView(session, session.a.player.UserId))
	Remotes.get(Constants.REMOTES.TradeSessionStarted):FireClient(session.b.player, clientView(session, session.b.player.UserId))
end

local function sideForPlayer(session, player)
	if session.a.player == player then return session.a, session.b end
	if session.b.player == player then return session.b, session.a end
	return nil, nil
end

local function handleUpdate(player: Player, sessionId: any, offer: any)
	if type(sessionId) ~= "string" then return end
	local session = sessions[sessionId]
	if not session then return end
	if session.state ~= "Open" and session.state ~= "Locked" then return end
	local mySide, _otherSide = sideForPlayer(session, player)
	if not mySide then return end

	local data = PlayerData.get(player)
	if not data then return end
	local ok, _code = Trade.validateOffer(offer, data)
	if not ok then
		-- Re-broadcast the unchanged session so the client's UI snaps back to
		-- the last accepted state. Without this, a rejected offer (e.g. coin
		-- amount > balance) leaves the client's input out of sync.
		broadcast(session)
		return
	end
	-- Defensive copy so the client can't share mutable references.
	mySide.offer = { coins = offer.coins, items = {} }
	for itemId, qty in pairs(offer.items) do mySide.offer.items[itemId] = qty end

	-- An update during Locked reverts the trade back to Open and clears
	-- both lock flags. Anti-scam: prevents a malicious player from luring
	-- the other into Lock then secretly modifying.
	if session.state == "Locked" then
		session.state = "Open"
		session.a.locked = false
		session.b.locked = false
		session.lockedAt = nil
	end

	broadcast(session)
end

local function handleLock(player: Player, sessionId: any)
	if type(sessionId) ~= "string" then return end
	local session = sessions[sessionId]
	if not session or (session.state ~= "Open" and session.state ~= "Locked") then return end
	local mySide = sideForPlayer(session, player)
	if not mySide then return end
	mySide.locked = true
	if session.a.locked and session.b.locked then
		session.state = "Locked"
		session.lockedAt = os.time()
	end
	broadcast(session)
end

local function handleConfirm(player: Player, sessionId: any)
	if type(sessionId) ~= "string" then return end
	local session = sessions[sessionId]
	if not session or session.state ~= "Locked" then return end
	if not session.lockedAt or (os.time() - session.lockedAt) < LOCK_COUNTDOWN_SECONDS then
		-- Countdown still running; ignore.
		return
	end
	local mySide = sideForPlayer(session, player)
	if not mySide then return end
	mySide.confirmed = true

	if session.a.confirmed and session.b.confirmed then
		local ok, code = executeAtomic(session)
		if ok then
			endSession(session, "completed", "OK")
		else
			endSession(session, "cancelled", code)
		end
		return
	end
	broadcast(session)
end

local function handleCancel(player: Player, sessionId: any)
	if type(sessionId) ~= "string" then return end
	local session = sessions[sessionId]
	if not session then return end
	if not sideForPlayer(session, player) then return end
	endSession(session, "cancelled", "USER_CANCELLED")
end

local function handlePlayerLeaving(player: Player)
	local sessionId = playerSession[player.UserId]
	if not sessionId then return end
	local session = sessions[sessionId]
	if not session then return end
	endSession(session, "cancelled", "PLAYER_DISCONNECTED")
end

-- ---------- Pending request expiry sweeper --------------------------------

local function sweepExpiredRequests()
	local now = os.time()
	for sessionId, expiry in pairs(pendingExpiry) do
		if now >= expiry then
			local session = sessions[sessionId]
			if session and session.state == "Pending" then
				endSession(session, "cancelled", "REQUEST_TIMEOUT")
			end
			pendingExpiry[sessionId] = nil
		end
	end
end

-- ---------- Wiring --------------------------------------------------------

function Trade.start()
	Remotes.get(Constants.REMOTES.RequestTrade).OnServerEvent:Connect(handleRequest)
	Remotes.get(Constants.REMOTES.RespondToTradeRequest).OnServerEvent:Connect(handleRespond)
	Remotes.get(Constants.REMOTES.UpdateTradeOffer).OnServerEvent:Connect(handleUpdate)
	Remotes.get(Constants.REMOTES.LockTradeOffer).OnServerEvent:Connect(handleLock)
	Remotes.get(Constants.REMOTES.ConfirmTrade).OnServerEvent:Connect(handleConfirm)
	Remotes.get(Constants.REMOTES.CancelTrade).OnServerEvent:Connect(handleCancel)
	Players.PlayerRemoving:Connect(handlePlayerLeaving)

	-- Sweep expired pending requests once per second.
	task.spawn(function()
		while true do
			task.wait(1)
			sweepExpiredRequests()
		end
	end)
end

return Trade
