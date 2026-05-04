-- Per-player plot tile assignment + lookup.
--
-- Phase 2 minimal: 8x8 grid (64 tiles) in a Cottages zone west of spawn.
-- Each tile is named "tile_NN" (zero-padded NN = 1..64 in row-major order).
-- Stable per player once assigned. When all 64 are claimed, assign returns
-- nil and the caller raises OUT_OF_PLOTS to the user.
--
-- Phase 3 hut system: replaces the placeholder Part at each tile with a
-- real hut Model. plotAnchorId is the persistent key; visual representation
-- is what changes. No save-data migration needed.
--
-- Spec: docs/specs/player-stalls.md §163-169.
-- Plan: 02-CONTEXT.md (D-09, CD-3, CD-5).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage.Shared.Constants)

local PlotAnchors = {}

-- ---------- Tile id formatting ---------------------------------------------

-- tile_01..tile_64 in row-major order. Zero-padded for stable string sort.
local function tileIdFromIndex(i: number): string
	return string.format("tile_%02d", i)
end

local function indexFromTileId(tileId: string): number?
	local n = tonumber(string.match(tileId or "", "^tile_(%d+)$"))
	if n and n >= 1 and n <= Constants.STALL.plotGridSize * Constants.STALL.plotGridSize then
		return n
	end
	return nil
end

-- ---------- Public API -----------------------------------------------------

-- Returns the lowest unclaimed tile id ("tile_01".."tile_64") or nil if all
-- 64 tiles are claimed (caller raises OUT_OF_PLOTS).
function PlotAnchors.assign(claimedSet): string?
	if type(claimedSet) ~= "table" then claimedSet = {} end
	local total = Constants.STALL.plotGridSize * Constants.STALL.plotGridSize
	for i = 1, total do
		local tileId = tileIdFromIndex(i)
		if not claimedSet[tileId] then
			return tileId
		end
	end
	return nil
end

-- Derive world position from a tile id using
-- Constants.STALL.cottagesZoneOrigin + (col-1, 0, row-1) * plotGridSpacing.
-- Row-major: tile_01 at (0,0,0) offset, tile_02 at (spacing,0,0), tile_09 at
-- (0, 0, spacing), tile_64 at ((gridSize-1)*spacing, 0, (gridSize-1)*spacing).
function PlotAnchors.tileIdToPosition(tileId: string): Vector3?
	local i = indexFromTileId(tileId)
	if not i then return nil end
	local gridSize = Constants.STALL.plotGridSize
	local spacing = Constants.STALL.plotGridSpacing
	local col = ((i - 1) % gridSize) + 1
	local row = math.floor((i - 1) / gridSize) + 1
	local origin = Constants.STALL.cottagesZoneOrigin
	return origin + Vector3.new((col - 1) * spacing, 0, (row - 1) * spacing)
end

function PlotAnchors.isAssigned(claimedSet, tileId: string): boolean
	if type(claimedSet) ~= "table" then return false end
	return claimedSet[tileId] == true
end

return PlotAnchors
