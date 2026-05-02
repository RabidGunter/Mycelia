-- Pure inventory math. No Roblox state, no DataStore, no replication —
-- this module operates on plain tables passed in by the caller. That makes
-- it trivially testable and reusable from PlayerData and from any future
-- system that handles items (trading, brewing, gifts).
--
-- Inventory shape:
--   { [speciesId: string] = count: number }
-- Counts are integers >= 1; zero counts are removed (Inventory.add and
-- Inventory.remove both maintain this invariant).

local Inventory = {}

function Inventory.count(inv: { [string]: number }, speciesId: string): number
	return inv[speciesId] or 0
end

function Inventory.add(inv: { [string]: number }, speciesId: string, n: number?)
	local amount = n or 1
	assert(amount > 0, "Inventory.add: amount must be positive")
	inv[speciesId] = (inv[speciesId] or 0) + amount
end

-- Returns true if the removal succeeded, false if there wasn't enough.
function Inventory.remove(inv: { [string]: number }, speciesId: string, n: number?): boolean
	local amount = n or 1
	assert(amount > 0, "Inventory.remove: amount must be positive")
	local current = inv[speciesId] or 0
	if current < amount then
		return false
	end
	if current == amount then
		inv[speciesId] = nil
	else
		inv[speciesId] = current - amount
	end
	return true
end

function Inventory.isEmpty(inv: { [string]: number }): boolean
	return next(inv) == nil
end

function Inventory.totalItems(inv: { [string]: number }): number
	local total = 0
	for _, c in pairs(inv) do
		total += c
	end
	return total
end

-- Returns the list of species ids in the inventory (unspecified order).
function Inventory.species(inv: { [string]: number }): { string }
	local list = {}
	for id in pairs(inv) do
		table.insert(list, id)
	end
	return list
end

-- Used for save serialization and for sending state to clients.
function Inventory.clone(inv: { [string]: number }): { [string]: number }
	local copy = {}
	for k, v in pairs(inv) do
		copy[k] = v
	end
	return copy
end

return Inventory
