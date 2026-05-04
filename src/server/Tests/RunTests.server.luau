-- Test runner. Auto-runs in Studio (any place, including Play Solo) and
-- nowhere else, so live servers don't print test output to the log.
--
-- Pre-Alpha caveat: the test files DO ship in the production .rbxl
-- because they live under src/. The RunService:IsStudio() guard below
-- prevents them from EXECUTING on live servers, but they're still
-- replicated in the place file. When the project graduates to a real
-- production build, move src/ServerScriptService/Tests/ into a separate
-- tests/ directory with its own tests.project.json so it's excluded
-- from default.project.json.

local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

-- Small delay so other systems have a chance to start logging first
-- (otherwise test output races with Main.server.lua's startup prints
-- and the result is hard to read in Studio's Output window).
task.wait(0.5)

local TestKit = require(script.Parent.TestKit)
TestKit.reset()

print("\n========== Mycelia tests ==========")

require(script.Parent.InventorySpec)()
require(script.Parent.ShopSpec)()
require(script.Parent.DialoguesSpec)()
require(script.Parent.QuestsSpec)()
require(script.Parent.TradeSpec)()
require(script.Parent.SpeciesSpec)()
require(script.Parent.PotionEffectsSpec)()
require(script.Parent.RecipesSpec)()
require(script.Parent.SaveSchemaSpec)()
require(script.Parent.SpiritsSpec)()
require(script.Parent.BiomeConfigSpec)()

local allPassed = TestKit.run()
print("===================================\n")

if not allPassed then
	-- warn() shows red in the Output window — the test failure is hard
	-- to miss this way without crashing the server.
	warn("[Mycelia tests] one or more tests failed; see [FAIL] entries above")
end
