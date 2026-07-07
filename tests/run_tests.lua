#!/usr/bin/env lune
--!strict
-- tests/run_tests.lua
--
-- Headless test runner for Terranova test suite.
-- Runs TestEZ specs under Lune (standalone Luau runtime with Roblox API emulation).
--
-- Execution:
--   lune run tests/run_tests.lua [test_directory_1] [test_directory_2] ...
--
-- Example:
--   lune run tests/run_tests.lua tests/unit tests/integration
--
-- This script:
-- 1. Uses Lune's built-in Roblox API emulation (game, Instance, require)
-- 2. Creates a virtual DataModel with project structure mappings
-- 3. Discovers .luau and .lua test files in given directories
-- 4. Loads and executes tests via TestEZ (if available)
-- 5. Reports results to stdout and tests/results/
-- 6. Exits with non-zero status if any test fails (CI gate)

-- Lune provides fs and process modules natively
local fs = require("@lune/fs")
local process = require("@lune/process")

-- Lune's Roblox emulation requires explicit requires
local roblox = require("@lune/roblox")
local Instance = roblox.Instance

-- Create a DataModel to serve as the root `game` object
local game = Instance.new("DataModel")

-- Make game and Roblox types available globally so loadstring() code can access it
_G.game = game
_G.Instance = Instance
_G.Vector3 = roblox.Vector3
_G.Vector2 = roblox.Vector2
_G.CFrame = roblox.CFrame
_G.Color3 = roblox.Color3
_G.UDim2 = roblox.UDim2
_G.UDim = roblox.UDim
_G.Enum = roblox.Enum
_G.BrickColor = roblox.BrickColor

-- ============================================================================
-- Configuration
-- ============================================================================

local TEST_RESULT_DIR = "tests/results"
local PROJECT_ROOT = "."

-- Test file patterns (TestEZ convention)
local TEST_PATTERNS: {string} = {
	"_test%.luau$",
	"_test%.lua$",
	"%.spec%.luau$",
	"%.spec%.lua$",
}

-- ============================================================================
-- Utilities
-- ============================================================================

local function matches_test_pattern(filename: string): boolean
	for _, pattern in TEST_PATTERNS do
		if string.match(filename, pattern) then
			return true
		end
	end
	return false
end

local function find_test_files(directory: string): {string}
	local tests: {string} = {}

	local function scan(dir: string, prefix: string)
		local ok, entries = pcall(function()
			return fs.readDir(dir)
		end)

		if not ok then
			warn("Cannot read directory: " .. dir)
			return
		end

		for _, entry in entries do
			local path = dir .. "/" .. entry
			local attr = fs.metadata(path)

			if attr.kind == "dir" then
				scan(path, prefix .. entry .. "/")
			elseif matches_test_pattern(entry) then
				table.insert(tests, prefix .. entry)
			end
		end
	end

	scan(directory, "")
	return tests
end

local function create_result_dir()
	local ok = pcall(function()
		fs.writeDir(TEST_RESULT_DIR)
	end)

	if not ok then
		warn("Could not create result directory: " .. TEST_RESULT_DIR)
	end
end

-- ============================================================================
-- Module Cache for Roblox-style Requires
-- ============================================================================

-- Since Lune's require() doesn't support Instance objects (unlike Roblox),
-- we maintain a cache of loaded modules that test files can retrieve via
-- Instance navigation. This maps Instance paths to their loaded module values.
local _moduleCache: {[any]: any} = {}

-- Custom require function that handles both strings and Instances
local function custom_require(module: any): any
	if type(module) == "string" then
		-- String path - use Lune's native require
		return require(module)
	elseif type(module) == "userdata" then
		-- Instance object - look it up in our cache
		if _moduleCache[module] then
			return _moduleCache[module]
		else
			error("Module not found in cache: " .. tostring(module))
		end
	else
		error("require() expects string or Instance, got " .. type(module))
	end
end

-- ============================================================================
-- Roblox API Emulation Setup for Lune
-- ============================================================================

-- Lune provides a partial Roblox API. We enhance it with what's needed for
-- tests to load modules via game:GetService() chains.

local function setup_roblox_environment()
	-- Ensure game.ServerScriptService exists for require() via game:GetService()
	if not game:FindFirstChild("ServerScriptService") then
		local service = Instance.new("Folder")
		service.Name = "ServerScriptService"
		service.Parent = game
	end

	-- Create the gameplay/services folder hierarchy
	local function ensure_path(parent: Instance, segments: {string}): Instance
		local current = parent
		for _, segment in segments do
			local child = current:FindFirstChild(segment)
			if not child then
				child = Instance.new("Folder")
				child.Name = segment
				child.Parent = current
			end
			current = child
		end
		return current
	end

	local sss = game:GetService("ServerScriptService") :: Instance
	local gameplayFolder = ensure_path(sss, {"gameplay", "services"})
	local coreFolder = ensure_path(sss, {"core"})
	-- NOTE: this "core" mount is a test-harness-only convenience under
	-- ServerScriptService, for require()-resolution purposes -- it does not mirror the real
	-- Rojo tree, where src/core ships as its own sibling mapping (see default.project.json;
	-- production code under src/core requires its sibling modules via script.Parent, not via
	-- ServerScriptService.core).

	-- Load actual Luau module files and mount them in the Instance tree
	-- so they can be require()'d via game:GetService() chain
	local function load_luau_file(filepath: string, parent: Instance, moduleName: string)
		-- Create a ModuleScript-like instance
		local module = Instance.new("ModuleScript")
		module.Name = moduleName
		module.Parent = parent

		-- Read and execute the module code using loadstring
		local ok, content = pcall(function()
			return fs.readFile(filepath)
		end)

		if not ok then
			warn("Could not read file: " .. filepath)
			return module
		end

		-- Compile and execute the module code using loadstring
		local ok_compile, loadedModule = pcall(function()
			local fn = loadstring(content, filepath)
			if fn then
				return fn()
			else
				error("loadstring returned nil for " .. filepath)
			end
		end)

		if not ok_compile then
			warn("Could not execute module from " .. filepath .. ": " .. tostring(loadedModule))
			return module
		end

		-- Store the loaded module in our cache using the Instance as key
		_moduleCache[module] = loadedModule

		-- Also store source for reference
		local manyType: any = module
		manyType.Source = content

		return module
	end

	-- Load the module(s) under test
	load_luau_file(
		"src/gameplay/services/PlayerControllerLanternLogic.luau",
		gameplayFolder,
		"PlayerControllerLanternLogic"
	);
	load_luau_file(
		"src/gameplay/services/PlayerControllerLocomotionStaminaLogic.luau",
		gameplayFolder,
		"PlayerControllerLocomotionStaminaLogic"
	);
	load_luau_file(
		"src/gameplay/services/DisturbanceServiceBootstrapLogic.luau",
		gameplayFolder,
		"DisturbanceServiceBootstrapLogic"
	);
	load_luau_file(
		"src/gameplay/services/DisturbanceServiceEmissionLogic.luau",
		gameplayFolder,
		"DisturbanceServiceEmissionLogic"
	);
	load_luau_file(
		"src/gameplay/services/DisturbanceServiceSpatialGridLogic.luau",
		gameplayFolder,
		"DisturbanceServiceSpatialGridLogic"
	);
	load_luau_file(
		"src/gameplay/services/RunControllerLogic.luau",
		gameplayFolder,
		"RunControllerLogic"
	);
	load_luau_file("src/core/ServerBootstrap.luau", coreFolder, "ServerBootstrap");
end

-- ============================================================================
-- Main Test Execution
-- ============================================================================

-- Parse command-line arguments
local args = process.args
local test_dirs: {string} = {}

if #args == 0 then
	test_dirs = {"tests/unit", "tests/integration"}
else
	for _, arg in args do
		table.insert(test_dirs, arg)
	end
end

print("Lune Test Runner — Terranova")
print("=" .. string.rep("=", 69))

-- Set up Roblox environment for test execution
setup_roblox_environment()

-- Override the global require function to handle Instance-based requires
-- This allows test files to use: require(game:GetService("ServerScriptService").gameplay.services.ModuleName)
_G.require = custom_require

-- Discover all test files
local all_tests: {string} = {}
for _, test_dir in test_dirs do
	local metadata = fs.metadata(test_dir)
	if metadata.exists then
		local found = find_test_files(test_dir)
		for _, test_file in found do
			table.insert(all_tests, test_dir .. "/" .. test_file)
		end
	else
		warn("Test directory not found: " .. test_dir)
	end
end

if #all_tests == 0 then
	error("No test files found in: " .. table.concat(test_dirs, ", "))
end

print("Discovered " .. tostring(#all_tests) .. " test file(s)")
print("=" .. string.rep("=", 69) .. "\n")

-- ============================================================================
-- Load TestEZ
-- ============================================================================

local testEZ: any
local has_testez = false

local ok_tes, err_tes = pcall(function()
	testEZ = require("testez")
	has_testez = true
end)

if not has_testez then
	warn("TestEZ not found. Install via: luarocks install testez")
	warn("Tests will still run via direct function calls.\n")

	-- Provide mock TestEZ functions so tests can at least load
	-- These are minimal stubs that allow test files to execute
	_G.describe = function(name: string, fn: () -> ())
		-- Minimal describe - just calls the function
		if fn then fn() end
	end

	_G.it = function(name: string, fn: () -> ())
		-- Minimal it - just calls the function
		if fn then fn() end
	end

	_G.expect = function(value: any)
		-- Minimal expect - returns an object with chained assertions.
		--
		-- BUG FIX: the original version of this mock defined its matcher methods
		-- with Luau's colon self-sugar (`function assertion:equal(other)`), but
		-- every real call site in this project's test files chains via plain
		-- dot-access (`expect(x).to.equal(y)`, NOT `expect(x).to:equal(y)`).
		-- A colon-sugared method invoked via a dot-call receives its caller's
		-- first REAL argument into the method's implicit `self` parameter, so
		-- the actual second parameter (`other`) was always nil regardless of
		-- what the test passed -- e.g. `expect(0).to.equal(0)` silently checked
		-- `0 ~= nil` and failed with "Expected 0 to equal nil" on every call,
		-- for every test file, immediately on the first assertion. Fixed by
		-- declaring these as plain closures (no `self`/colon at all) that
		-- capture `value` from the enclosing `expect()` scope directly.
		--
		-- Also adds real `.never` support (`expect(x).never.to.equal(y)`),
		-- which the original mock didn't implement at all, even though several
		-- of this project's real test files use it.
		local function makeAssertion(negate: boolean)
			local assertion = {}

			assertion.equal = function(other: any)
				local isEqual = value == other
				if negate then
					if isEqual then
						error("Expected " .. tostring(value) .. " to NOT equal " .. tostring(other))
					end
				else
					if not isEqual then
						error("Expected " .. tostring(value) .. " to equal " .. tostring(other))
					end
				end
				return assertion
			end

			assertion.ok = function()
				local truthy = value and true or false
				if negate then
					if truthy then
						error("Expected falsy value, got " .. tostring(value))
					end
				else
					if not truthy then
						error("Expected truthy value, got " .. tostring(value))
					end
				end
				return assertion
			end

			assertion.a = function(typ: string)
				local matches = type(value) == typ
				if negate then
					if matches then
						error("Expected type NOT " .. typ .. " but got " .. type(value))
					end
				else
					if not matches then
						error("Expected type " .. typ .. " but got " .. type(value))
					end
				end
				return assertion
			end

			return assertion
		end

		local positive = makeAssertion(false)
		local negative = makeAssertion(true)

		return {
			to = positive,
			be = positive,
			never = { to = negative, be = negative },
		}
	end

	_G.pending = function(name: string)
		-- Minimal pending - just logs
		print("PENDING: " .. name)
	end
end

-- Create result directory
create_result_dir()

-- ============================================================================
-- Test Execution Loop
-- ============================================================================

local test_results: {any} = {}
local total_count = 0
local passed_count = 0
local failed_count = 0

for _, test_file_relative in all_tests do
	print("Running: " .. test_file_relative)

	-- Load test file using loadstring() and execute it
	-- The custom_require function will handle Instance-based requires
	local ok_load, test_fn = pcall(function()
		local content = fs.readFile(test_file_relative)

		-- Prepend variable declarations to make globals available to the loaded code
		-- This works around Lune's loadstring() environment isolation
		local preamble = [[
local game = _G.game
local Instance = _G.Instance
local require = _G.require
local describe = _G.describe
local it = _G.it
local expect = _G.expect
local pending = _G.pending
local Vector3 = _G.Vector3
local Vector2 = _G.Vector2
local CFrame = _G.CFrame
local Color3 = _G.Color3
local UDim2 = _G.UDim2
local UDim = _G.UDim
local Enum = _G.Enum
local BrickColor = _G.BrickColor
]]
		local wrapped_content = preamble .. content

		local fn = loadstring(wrapped_content, test_file_relative)
		if fn then
			return fn()
		else
			error("loadstring returned nil")
		end
	end)

	if not ok_load then
		print("  ERROR loading test file: " .. tostring(test_fn))
		failed_count += 1
		table.insert(test_results, {
			file = test_file_relative,
			status = "ERROR",
			message = tostring(test_fn),
		})
	else
		if type(test_fn) == "function" then
			if has_testez then
				-- Run via TestEZ framework
				local ok_run, result = pcall(function()
					return testEZ.run({test_fn})
				end)

				if ok_run then
					local success_ct = result.successCount or 0
					local failure_ct = result.failureCount or 0
					total_count += success_ct + failure_ct
					passed_count += success_ct
					failed_count += failure_ct

					if failure_ct > 0 then
						print("  FAIL (" .. tostring(success_ct) .. " passed, " .. tostring(failure_ct) .. " failed)")
					else
						print("  PASS (" .. tostring(success_ct) .. " assertions)")
					end

					table.insert(test_results, {
						file = test_file_relative,
						status = if failure_ct > 0 then "FAIL" else "PASS",
						successCount = success_ct,
						failureCount = failure_ct,
					})
				else
					print("  ERROR running tests: " .. tostring(result))
					failed_count += 1
					total_count += 1
					table.insert(test_results, {
						file = test_file_relative,
						status = "ERROR",
						message = tostring(result),
					})
				end
			else
				-- Fallback: minimal execution without TestEZ harness
				local ok_exec, result = pcall(function()
					return test_fn()
				end)

				if ok_exec then
					print("  EXECUTED (no TestEZ harness)")
					passed_count += 1
					total_count += 1
					table.insert(test_results, {
						file = test_file_relative,
						status = "PASS",
						successCount = 1,
						failureCount = 0,
					})
				else
					print("  ERROR: " .. tostring(result))
					failed_count += 1
					total_count += 1
					table.insert(test_results, {
						file = test_file_relative,
						status = "ERROR",
						message = tostring(result),
					})
				end
			end
		else
			print("  WARN: test file did not return a function; skipping")
		end
	end
end

-- ============================================================================
-- Report Results
-- ============================================================================

print("\n" .. string.rep("=", 70))
print("TEST SUMMARY")
print(string.rep("=", 70))
print("Total:  " .. tostring(total_count))
print("Passed: " .. tostring(passed_count))
print("Failed: " .. tostring(failed_count))

if failed_count > 0 then
	print("\nStatus: FAIL")
	process.exit(1)
else
	print("\nStatus: PASS")
	process.exit(0)
end
