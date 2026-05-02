-- Tests for Recipes.lookup (pure-data module — easy and fast to test).
--
-- The lookup keys things by method + sorted ingredient list, so we want
-- coverage for: every known recipe resolves correctly, order independence,
-- duplicate ingredients (the 3x BrownCap pattern), unknown combinations,
-- wrong method paired with valid ingredients, and empty/edge inputs.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestKit = require(script.Parent.TestKit)
local Recipes = require(ReplicatedStorage.Shared.Recipes)

return function()
	TestKit.describe("Recipes.METHODS", function()
		TestKit.test("includes the four Pre-Alpha methods", function()
			local set = {}
			for _, m in ipairs(Recipes.METHODS) do
				set[m] = true
			end
			TestKit.eq(set.steep, true)
			TestKit.eq(set.boil, true)
			TestKit.eq(set.ferment, true)
			TestKit.eq(set.dry_grind, true)
		end)

		TestKit.test("every method has a display name", function()
			for _, m in ipairs(Recipes.METHODS) do
				TestKit.truthy(Recipes.METHOD_DISPLAY[m],
					"missing METHOD_DISPLAY for " .. m)
			end
		end)
	end)

	TestKit.describe("Recipes.lookup — known recipes", function()
		TestKit.test("steep + 3x BrownCap -> Common Speed Potion", function()
			TestKit.eq(
				Recipes.lookup("steep", { "BrownCap", "BrownCap", "BrownCap" }),
				"CommonSpeedPotion"
			)
		end)

		TestKit.test("steep + FairyCup + Mossring -> Dewdrop Tonic", function()
			TestKit.eq(
				Recipes.lookup("steep", { "FairyCup", "Mossring" }),
				"DewdropTonic"
			)
		end)

		TestKit.test("boil + Buttoncap + Pinwheel + SpottedToadstool -> Hearth Brew", function()
			TestKit.eq(
				Recipes.lookup("boil", { "Buttoncap", "Pinwheel", "SpottedToadstool" }),
				"HearthBrew"
			)
		end)

		TestKit.test("ferment + Inkpot -> Inkblot Elixir", function()
			TestKit.eq(Recipes.lookup("ferment", { "Inkpot" }), "InkblotElixir")
		end)

		TestKit.test("ferment + 2x SpottedToadstool -> Spotted Tincture", function()
			TestKit.eq(
				Recipes.lookup("ferment", { "SpottedToadstool", "SpottedToadstool" }),
				"SpottedTincture"
			)
		end)

		TestKit.test("dry_grind + Glowmoss -> Glowmoss Powder", function()
			TestKit.eq(Recipes.lookup("dry_grind", { "Glowmoss" }), "GlowmossPowder")
		end)
	end)

	TestKit.describe("Recipes.lookup — Phase 1 additions", function()
		TestKit.test("alt path: 2x FairyCup also produces DewdropTonic", function()
			TestKit.eq(
				Recipes.lookup("steep", { "FairyCup", "FairyCup" }),
				"DewdropTonic"
			)
		end)

		TestKit.test("alt path: Buttoncap + Inkpot also produces InkblotElixir", function()
			TestKit.eq(
				Recipes.lookup("ferment", { "Buttoncap", "Inkpot" }),
				"InkblotElixir"
			)
		end)

		TestKit.test("3-Mossring steep produces StonecastInfusion", function()
			TestKit.eq(
				Recipes.lookup("steep", { "Mossring", "Mossring", "Mossring" }),
				"StonecastInfusion"
			)
		end)

		TestKit.test("3-ingredient rare ferment produces SpiritcallTonic", function()
			TestKit.eq(
				Recipes.lookup("ferment", { "Whisperbloom", "FairyCup", "Mossring" }),
				"SpiritcallTonic"
			)
		end)

		TestKit.test("dry_grind single rares (Whisperbloom, Dewfern, Sundrop)", function()
			TestKit.eq(Recipes.lookup("dry_grind", { "Whisperbloom" }), "LuckPowder")
			TestKit.eq(Recipes.lookup("dry_grind", { "Dewfern" }), "EverdewPowder")
			TestKit.eq(Recipes.lookup("dry_grind", { "Sundrop" }), "DaybreakPowder")
		end)
	end)

	TestKit.describe("Recipes.lookup — order independence", function()
		TestKit.test("FairyCup + Mossring matches Mossring + FairyCup", function()
			TestKit.eq(
				Recipes.lookup("steep", { "Mossring", "FairyCup" }),
				"DewdropTonic"
			)
		end)

		TestKit.test("3-ingredient permutation still matches", function()
			-- Hearth Brew: any order of Buttoncap, Pinwheel, SpottedToadstool.
			TestKit.eq(
				Recipes.lookup("boil", { "SpottedToadstool", "Buttoncap", "Pinwheel" }),
				"HearthBrew"
			)
			TestKit.eq(
				Recipes.lookup("boil", { "Pinwheel", "SpottedToadstool", "Buttoncap" }),
				"HearthBrew"
			)
		end)
	end)

	TestKit.describe("Recipes.lookup — fizzles", function()
		TestKit.test("unknown method returns nil", function()
			TestKit.eq(Recipes.lookup("microwave", { "BrownCap" }), nil)
		end)

		TestKit.test("right ingredients with wrong method returns nil", function()
			-- 3x BrownCap is a steep recipe; boil should not produce anything.
			TestKit.eq(
				Recipes.lookup("boil", { "BrownCap", "BrownCap", "BrownCap" }),
				nil
			)
		end)

		TestKit.test("empty ingredient list returns nil", function()
			TestKit.eq(Recipes.lookup("steep", {}), nil)
		end)

		TestKit.test("unknown ingredient combination returns nil", function()
			TestKit.eq(Recipes.lookup("steep", { "BrownCap", "FairyCup" }), nil)
		end)

		TestKit.test("partial recipe (subset) returns nil", function()
			-- Hearth Brew needs all three; just two should fizzle.
			TestKit.eq(Recipes.lookup("boil", { "Buttoncap", "Pinwheel" }), nil)
		end)

		TestKit.test("superset of a recipe returns nil", function()
			-- Adding a 4th ingredient to a 3-ingredient recipe shouldn't match.
			TestKit.eq(
				Recipes.lookup("boil",
					{ "Buttoncap", "Pinwheel", "SpottedToadstool", "BrownCap" }),
				nil
			)
		end)

		TestKit.test("wrong duplicate count returns nil", function()
			-- 2x BrownCap is not a recipe (3x is).
			TestKit.eq(Recipes.lookup("steep", { "BrownCap", "BrownCap" }), nil)
		end)

		TestKit.test("ingredient ids are case-sensitive", function()
			-- Defends against a future ingredient registry that lowercases ids.
			TestKit.eq(Recipes.lookup("steep", { "browncap", "browncap", "browncap" }), nil)
		end)

		TestKit.test("method is case-sensitive", function()
			TestKit.eq(Recipes.lookup("STEEP", { "BrownCap", "BrownCap", "BrownCap" }), nil)
		end)
	end)

	TestKit.describe("Recipes.byKey — table integrity", function()
		TestKit.test("every value is a non-empty string potion id", function()
			for key, value in pairs(Recipes.byKey) do
				TestKit.truthy(type(value) == "string" and #value > 0,
					"recipe " .. tostring(key) .. " has invalid output")
			end
		end)

		TestKit.test("byKey contains every shipped recipe (no silent overwrites)", function()
			-- If two recipe() calls produce the same key (typo in ingredient
			-- list, identical method+ingredients), the second silently
			-- overwrites the first and a recipe disappears. Counting entries
			-- catches that — bump this number when you add a recipe.
			local count = 0
			for _ in pairs(Recipes.byKey) do
				count += 1
			end
			TestKit.eq(count, 20)
		end)

		TestKit.test("every recipe output is a valid potion id (cross-ref Potions catalog)", function()
			-- Catches the bug of adding a recipe whose output potion was
			-- never added to Potions.LIST.
			local Potions = require(game:GetService("ReplicatedStorage").Shared.Potions)
			for key, potionId in pairs(Recipes.byKey) do
				TestKit.truthy(Potions.byId[potionId] ~= nil,
					string.format("recipe %s produces unknown potion %s", tostring(key), tostring(potionId)))
			end
		end)
	end)
end
