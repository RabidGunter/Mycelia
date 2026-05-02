-- Tiny in-Studio test framework. Just enough to run assertion-based
-- tests against pure modules without pulling in TestEZ or Wally.
--
-- Usage in a *Spec.lua module:
--
--   local TestKit = require(...)
--   local Module  = require(...)
--
--   return function()
--       TestKit.describe("Module.foo", function()
--           TestKit.test("does the thing", function()
--               TestKit.eq(Module.foo(1), 2)
--           end)
--       end)
--   end
--
-- The runner (RunTests.server.lua) requires each spec module, calls the
-- returned function, then calls TestKit.run() to print results.

local TestKit = {}

-- list of { name, tests = { { name, run } } }
local groups = {}
local current = nil

function TestKit.describe(name: string, fn: () -> ())
	current = { name = name, tests = {} }
	fn()
	table.insert(groups, current)
	current = nil
end

function TestKit.test(name: string, fn: () -> ())
	assert(current, "TestKit.test() called outside describe()")
	table.insert(current.tests, { name = name, run = fn })
end

-- ---------- Assertions -----------------------------------------------------

local function fmt(v: any): string
	if type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end

function TestKit.eq(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(string.format(
			"%s\n        expected: %s\n        actual:   %s",
			message or "values not equal", fmt(expected), fmt(actual)
		), 2)
	end
end

function TestKit.neq(actual: any, expected: any, message: string?)
	if actual == expected then
		error(string.format(
			"%s\n        both values were: %s",
			message or "expected values to differ", fmt(actual)
		), 2)
	end
end

function TestKit.truthy(v: any, message: string?)
	if not v then
		error(message or "expected truthy value", 2)
	end
end

function TestKit.falsy(v: any, message: string?)
	if v then
		error(string.format("%s (got %s)", message or "expected falsy value", fmt(v)), 2)
	end
end

-- Asserts that calling `fn` raises an error. Returns the error message
-- so callers can check its content.
function TestKit.errors(fn: () -> any, message: string?): string
	local ok, err = pcall(fn)
	if ok then
		error(message or "expected function to error, but it returned normally", 2)
	end
	return tostring(err)
end

-- ---------- Runner ---------------------------------------------------------

function TestKit.run(): boolean
	local totalPass, totalFail = 0, 0
	local failures = {}
	for _, group in ipairs(groups) do
		print(string.format("\n-- %s --", group.name))
		for _, t in ipairs(group.tests) do
			local ok, err = pcall(t.run)
			if ok then
				print(string.format("  [PASS] %s", t.name))
				totalPass += 1
			else
				print(string.format("  [FAIL] %s", t.name))
				print(string.format("         %s", tostring(err)))
				totalFail += 1
				table.insert(failures, string.format("%s > %s", group.name, t.name))
			end
		end
	end
	print(string.format(
		"\nTests complete: %d passed, %d failed (%d total)",
		totalPass, totalFail, totalPass + totalFail
	))
	if totalFail > 0 then
		print("Failures:")
		for _, name in ipairs(failures) do
			print("  - " .. name)
		end
	end
	return totalFail == 0
end

function TestKit.reset()
	groups = {}
	current = nil
end

return TestKit
