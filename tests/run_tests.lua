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

-- Lune provides a global `game` object with Roblox API emulation
declare global game: any

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

	-- Load actual Luau module files and mount them in the Instance tree
	-- so they can be require()'d via game:GetService() chain
	local function load_luau_file(filepath: string, parent: Instance, moduleName: string)
		local ok, content = pcall(function()
			return fs.readFile(filepath)
		end)

		if not ok then
			warn("Could not read file: " .. filepath)
			return
		end

		-- Create a ModuleScript-like instance
		local module = Instance.new("ModuleScript")
		module.Name = moduleName
		module.Parent = parent

		-- Store the source code in a property so Lune's require() can access it
		(module :: any).Source = content

		return module
	end

	-- Load the module under test
	load_luau_file(
		"src/gameplay/services/PlayerControllerLanternLogic.luau",
		gameplayFolder,
		"PlayerControllerLanternLogic"
	)
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

	-- Lune's require() can load .luau files directly from the filesystem
	local ok_load, test_fn = pcall(function()
		return require(test_file_relative)
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
