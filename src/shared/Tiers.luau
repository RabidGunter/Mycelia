--!strict
-- Rarity tier definitions. Single source of truth for tier metadata
-- (display color, drop weight, sell multiplier). Species reference these
-- by string id so balance changes happen in one place.

local Tiers = {}

Tiers.Common = {
	id = "Common",
	displayColor = Color3.fromRGB(200, 200, 200),
	-- Relative weight in the wild-spawn drop table. Commons dominate.
	dropWeight = 100,
	-- Sell-price multiplier applied on top of species.baseSellPrice.
	sellMultiplier = 1,
}

Tiers.Uncommon = {
	id = "Uncommon",
	displayColor = Color3.fromRGB(120, 220, 140),
	dropWeight = 35,
	sellMultiplier = 2,
}

Tiers.Rare = {
	id = "Rare",
	displayColor = Color3.fromRGB(80, 160, 255),
	dropWeight = 10,
	sellMultiplier = 5,
}

Tiers.Epic = {
	id = "Epic",
	displayColor = Color3.fromRGB(180, 100, 255),
	dropWeight = 2,
	sellMultiplier = 12,
}

Tiers.Legendary = {
	id = "Legendary",
	displayColor = Color3.fromRGB(255, 180, 60),
	dropWeight = 0.3,
	sellMultiplier = 35,
}

Tiers.Mythic = {
	id = "Mythic",
	displayColor = Color3.fromRGB(255, 80, 200),
	-- Mythics never drop from the wild-spawn table; they require event triggers.
	dropWeight = 0,
	sellMultiplier = 100,
}

Tiers.ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

return Tiers
