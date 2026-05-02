-- Forest Witch's stall: convert the player's full inventory to coins.
--
-- Pre-Alpha rule: "Sell" sells *everything* at base price × tier multiplier.
-- That's intentionally simple — when the trading post lands, players will
-- have a real reason to *not* sell rares to the witch (other players will
-- pay more). Keeping the witch as a flat-rate fallback price keeps the
-- economy floor predictable.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Species = require(ReplicatedStorage.Shared.Species)
local Tiers = require(ReplicatedStorage.Shared.Tiers)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Inventory = require(ServerScriptService.Server.Inventory)
local PlayerData = require(ServerScriptService.Server.PlayerData)

local Selling = {}

-- Compute what an inventory is worth at the witch's stall.
function Selling.priceOf(inv: { [string]: number }): number
	local total = 0
	for speciesId, count in pairs(inv) do
		local species = Species.byId[speciesId]
		if species then
			local tier = Tiers[species.tier]
			if tier then
				total += count * species.baseSellPrice * tier.sellMultiplier
			end
		end
	end
	return math.floor(total * Constants.ECONOMY.witchPriceMultiplier)
end

local function sellAll(player: Player)
	local data = PlayerData.get(player)
	if not data or Inventory.isEmpty(data.inventory) then
		return
	end
	local payout = Selling.priceOf(data.inventory)
	if payout <= 0 then
		return
	end
	PlayerData.update(player, function(d)
		d.coins += payout
		d.stats.totalSold += Inventory.totalItems(d.inventory)
		d.stats.totalCoinsEarned += payout
		d.inventory = {}
	end)
	-- Tell the client to show the "+N coins" toast. Decoupled from
	-- PlayerDataUpdated so the toast only fires for sells, not for any
	-- coin change (planting cost, future quest rewards, etc.).
	Remotes.get(Constants.REMOTES.SellCompleted):FireClient(player, payout)
end

function Selling.start()
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "SellPrompt" then
			sellAll(player)
		end
	end)
end

return Selling
