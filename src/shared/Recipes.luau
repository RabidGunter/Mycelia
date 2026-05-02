--!strict
-- Brewing recipe table.
--
-- The brewing system identifies a recipe by:
--   key = method .. "|" .. <ingredient species ids, sorted, comma-joined>
--
-- Sorting normalizes input order: {BrownCap, FairyCup} and {FairyCup,
-- BrownCap} produce the same key. Duplicate ingredients are kept (3x
-- BrownCap = "BrownCap,BrownCap,BrownCap"). Unknown combinations resolve
-- to nil — i.e. the brew fizzles, ingredients are consumed for nothing.
-- Players are *expected* to fail recipes; that's the engagement loop.
--
-- Keep this file flat and easy for designers to edit. New recipe = one
-- line with `recipe(...)`.

local Recipes = {}

Recipes.METHODS = { "steep", "boil", "ferment", "dry_grind" }

Recipes.METHOD_DISPLAY = {
	steep = "Steep",
	boil = "Boil",
	ferment = "Ferment",
	dry_grind = "Dry-grind",
}

local function buildKey(method: string, ids: { string }): string
	local sorted = table.create(#ids)
	for i, id in ipairs(ids) do
		sorted[i] = id
	end
	table.sort(sorted)
	return method .. "|" .. table.concat(sorted, ",")
end

Recipes.byKey = {}

local function recipe(method: string, ingredients: { string }, outputPotionId: string)
	Recipes.byKey[buildKey(method, ingredients)] = outputPotionId
end

-- ---------- Easy: reachable with commons only ----------------------------
recipe("steep",     { "BrownCap", "BrownCap", "BrownCap" },              "CommonSpeedPotion")
recipe("steep",     { "FairyCup", "Mossring" },                          "DewdropTonic")
recipe("steep",     { "FairyCup", "FairyCup" },                          "DewdropTonic")           -- alt path to DewdropTonic
recipe("steep",     { "Mossring", "Mossring", "Mossring" },              "StonecastInfusion")
recipe("boil",      { "Buttoncap", "Pinwheel", "SpottedToadstool" },     "HearthBrew")
recipe("boil",      { "BrownCap", "FairyCup" },                          "WoodlandWarmth")

-- ---------- Mid: cultivation gates open uncommon ingredients --------------
recipe("ferment",   { "Inkpot" },                                         "InkblotElixir")
recipe("ferment",   { "SpottedToadstool", "SpottedToadstool" },           "SpottedTincture")
recipe("ferment",   { "Buttoncap", "Inkpot" },                            "InkblotElixir")          -- alt path to InkblotElixir
recipe("boil",      { "BrownCap", "LatticeVeil" },                        "LatticeBalm")
recipe("ferment",   { "Hollowstem", "Pinwheel" },                         "HollowwindBrew")
recipe("ferment",   { "CoralTongue" },                                    "CoralCordial")
recipe("dry_grind", { "Sundrop" },                                        "DaybreakPowder")

-- ---------- Hard: rares + epics + specific multi-rare combos --------------
recipe("dry_grind", { "Glowmoss" },                                       "GlowmossPowder")
recipe("dry_grind", { "Whisperbloom" },                                   "LuckPowder")
recipe("dry_grind", { "Dewfern" },                                        "EverdewPowder")
recipe("steep",     { "CrystalCap", "CrystalCap" },                       "CrystalEssence")
recipe("boil",      { "Glowmoss", "Mossring" },                           "NightlanternOil")
recipe("ferment",   { "CoralTongue", "LatticeVeil" },                     "TideweaverElixir")
recipe("ferment",   { "FairyCup", "Mossring", "Whisperbloom" },           "SpiritcallTonic")

function Recipes.lookup(method: string, ingredientIds: { string }): string?
	return Recipes.byKey[buildKey(method, ingredientIds)]
end

return Recipes
