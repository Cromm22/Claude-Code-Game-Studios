--!strict
-- squad-aggregate-t-accessor_test
--
-- Unit tests for Story 007: Squad Aggregate t & GetSquadAggregateT Accessor.
-- Story: production/epics/ecological-disturbance/story-007-squad-aggregate-t-accessor.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceSquadAggregateLogic.luau (pure D.5 max-aggregation
--     formula, D.6b exclusion form, NaN/+Infinity fail-quiet finiteness guard -- H.22, H.22b,
--     H.22c, the NaN-guard AC, and the cost/cadence AC)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only, for the
--     same reason Stories 002/003/004/005's own test files give -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live DisturbanceService instance is not
--     currently possible in an automated test -- the wiring/server-internal-only ACs are instead
--     proven via source-text checks against the real file)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local SquadAggregateLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceSquadAggregateLogic)
local DecayFalloffLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceDecayFalloffLogic)
local SpatialGridLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceSpatialGridLogic)

type SquadMember = SquadAggregateLogic.SquadMember
type DecayableSource = DecayFalloffLogic.DecayableSource
type DecayCache = DecayFalloffLogic.DecayCache
type SpatialGrid = SpatialGridLogic.SpatialGrid

-- STANDARD_HALF_LIFE / INFLUENCE_RADIUS / SPATIAL_GRID_CELL_SIZE literals below intentionally
-- match DisturbanceConstants.luau's published values without require()-ing that module -- same
-- harness-driven precedent every sibling test file in this epic documents.
local INFLUENCE_RADIUS = 24
local SPATIAL_GRID_CELL_SIZE = 32

local function almostEqual(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

--- Builds a fieldValueFn from a plain {player -> value} lookup table, matching the real
--- DisturbanceService.luau wrapper's shape (position -> fieldValue), but keyed by player identity
--- here for test-authoring convenience -- the lookup is done by matching `member.position` back to
--- the owning player via a parallel positionToPlayer map built alongside `members`.
local function makeSquadSession(
	valuesByPlayer: { [any]: number }
): ({ SquadMember }, (Vector3) -> number, () -> number)
	local members: { SquadMember } = {}
	local valueByPosition: { [Vector3]: number } = {}
	local index = 0

	for player, value in valuesByPlayer do
		index += 1
		-- Distinct positions per player (X = index) so the lookup below is unambiguous.
		local position = Vector3.new(index, 0, 0)
		table.insert(members, { player = player, position = position })
		valueByPosition[position] = value
	end

	local callCount = 0
	local function fieldValueFn(position: Vector3): number
		callCount += 1
		local value = valueByPosition[position]
		if value == nil then
			error("makeSquadSession: no value registered for position " .. tostring(position))
		end
		return value
	end
	local function getCallCount(): number
		return callCount
	end

	return members, fieldValueFn, getCallCount
end

return function()
	describe("DisturbanceServiceSquadAggregateLogic -- Story 007 (H.22 max-aggregation)", function()
		-- AC-H.22: 4 players {0.71, 0.34, 0.09, 0.02} -> squadT = 0.71 (max, not mean/sum).
		local function test_h22_squad_t_is_max_not_mean_or_sum()
			local p1, p2, p3, p4 = {}, {}, {}, {}
			local members, fieldValueFn = makeSquadSession({
				[p1] = 0.71,
				[p2] = 0.34,
				[p3] = 0.09,
				[p4] = 0.02,
			})

			local squadT = SquadAggregateLogic.ComputeSquadAggregateT(members, nil, fieldValueFn)
			expect(almostEqual(squadT, 0.71, 0.001)).to.equal(true)

			-- Not the mean (0.29) and not the sum (1.16) -- proves max, not an averaging bug.
			expect(almostEqual(squadT, 0.29, 0.001)).to.equal(false)
			expect(almostEqual(squadT, 1.16, 0.001)).to.equal(false)
		end
		it("test_h22_squad_t_is_max_not_mean_or_sum", function()
			test_h22_squad_t_is_max_not_mean_or_sum()
		end)

		-- AC-H.22 edge case: all four players share the exact same fieldValue -- max equals that
		-- shared value, not a multiple (rules out an accidental sum/count bug).
		local function test_h22_edge_all_players_at_identical_field_value()
			local p1, p2, p3, p4 = {}, {}, {}, {}
			local members, fieldValueFn = makeSquadSession({
				[p1] = 0.40,
				[p2] = 0.40,
				[p3] = 0.40,
				[p4] = 0.40,
			})

			local squadT = SquadAggregateLogic.ComputeSquadAggregateT(members, nil, fieldValueFn)
			expect(almostEqual(squadT, 0.40, 0.001)).to.equal(true)
			expect(almostEqual(squadT, 1.60, 0.001)).to.equal(false) -- rules out an accidental sum
		end
		it("test_h22_edge_all_players_at_identical_field_value", function()
			test_h22_edge_all_players_at_identical_field_value()
		end)
	end)

	describe("DisturbanceServiceSquadAggregateLogic -- Story 007 (H.22b empty-player guard)", function()
		-- AC-H.22b: zero connected players -> squadT is exactly 0.0, no error.
		local function test_h22b_zero_connected_players_returns_exactly_zero()
			local members: { SquadMember } = {}
			local callCount = 0
			local function fieldValueFn(_position: Vector3): number
				callCount += 1
				return 0.5
			end

			local ok, squadT = pcall(function()
				return SquadAggregateLogic.ComputeSquadAggregateT(members, nil, fieldValueFn)
			end)

			expect(ok).to.equal(true)
			expect(squadT).to.equal(0.0)
			-- Zero-member short-circuit means fieldValueFn is never even called.
			expect(callCount).to.equal(0)
		end
		it("test_h22b_zero_connected_players_returns_exactly_zero", function()
			test_h22b_zero_connected_players_returns_exactly_zero()
		end)

		-- AC-H.22b continued: zero connected players + an excludePlayer argument still returns
		-- exactly 0.0, no error (case (c) of the exclusion-form spec applies regardless of the
		-- argument).
		local function test_h22b_zero_connected_players_with_exclude_argument_still_returns_zero()
			local members: { SquadMember } = {}
			local staleExcluded = {}
			local function fieldValueFn(_position: Vector3): number
				return 0.5
			end

			local ok, squadT = pcall(function()
				return SquadAggregateLogic.ComputeSquadAggregateT(members, staleExcluded, fieldValueFn)
			end)

			expect(ok).to.equal(true)
			expect(squadT).to.equal(0.0)
		end
		it(
			"test_h22b_zero_connected_players_with_exclude_argument_still_returns_zero",
			function()
				test_h22b_zero_connected_players_with_exclude_argument_still_returns_zero()
			end
		)

		-- Structural corroboration (AC's own "OR structural code review" alternative): WITHIN
		-- ComputeSquadAggregateT's own body, the zero-members short-circuit textually precedes the
		-- (only) call to maxOverGuardedValues (the sole call site that reaches math.max), so
		-- math.max can never be reached with an empty `members` list.
		--
		-- SCOPING NOTE (why this checks WITHIN the function, not the whole file): the real
		-- math.max(a, b) call lives inside the local helper `maxOverGuardedValues`, which is
		-- DEFINED (lexically, textually earlier in the file) above ComputeSquadAggregateT, even
		-- though it is only ever INVOKED from within ComputeSquadAggregateT, always after that
		-- function's own `#members == 0` guard has already returned. A naive whole-file textual
		-- scan for `math%.max%(` would therefore find the helper's definition BEFORE the guard and
		-- wrongly fail -- textual definition order is not call order. Restricting the scan to
		-- ComputeSquadAggregateT's own extracted body avoids this false negative, since within that
		-- one function's body, textual order and execution order coincide (no nested local
		-- function definitions reorder anything).
		--
		-- COMMENT-STRIPPING NOTE (known fragile pattern, avoided here): comments are stripped first
		-- (naive first-`--`-match stripper, matching Stories 002/003/004/005's own precedent --
		-- this module's own comments never place `--` inside a string literal, so the naive
		-- stripper is safe here), since this module's own header comments describe the guard using
		-- the literal phrase "math.max()" in prose, which would otherwise be mis-detected as a real
		-- call site.
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function extractFunctionBody(source: string, functionNamePattern: string): string
			local startIndex = source:find(functionNamePattern)
			if not startIndex then
				return ""
			end
			local endIndex = source:find("\nend", startIndex)
			if not endIndex then
				return source:sub(startIndex)
			end
			return source:sub(startIndex, endIndex)
		end

		local function test_h22b_empty_check_structurally_precedes_every_math_max_call_site()
			local source = stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceServiceSquadAggregateLogic.luau"))
			local body = extractFunctionBody(source, "function DisturbanceServiceSquadAggregateLogic%.ComputeSquadAggregateT")
			expect(body).never.to.equal("")

			local emptyCheckIndex = body:find("#members == 0")
			expect(emptyCheckIndex).never.to.equal(nil)

			-- The ONLY call to maxOverGuardedValues reachable before the empty-set return is none --
			-- every occurrence of the call within this function's body must appear strictly after
			-- the empty-set guard.
			local searchStart = 1
			local foundAny = false
			while true do
				local matchIndex = body:find("maxOverGuardedValues%(", searchStart)
				if not matchIndex then
					break
				end
				foundAny = true
				expect(matchIndex > (emptyCheckIndex :: number)).to.equal(true)
				searchStart = matchIndex + 1
			end
			expect(foundAny).to.equal(true) -- sanity: maxOverGuardedValues IS called from this function
		end
		it(
			"test_h22b_empty_check_structurally_precedes_every_math_max_call_site",
			function()
				test_h22b_empty_check_structurally_precedes_every_math_max_call_site()
			end
		)
	end)

	describe("DisturbanceServiceSquadAggregateLogic -- Story 007 (NaN-guard defense-in-depth, both flavors)", function()
		-- GuardFinite direct unit tests -- NaN flavor.
		local function test_guard_finite_nan_becomes_zero()
			local nan = 0 / 0
			expect(nan ~= nan).to.equal(true) -- sanity: this really is NaN
			expect(SquadAggregateLogic.GuardFinite(nan)).to.equal(0.0)
		end
		it("test_guard_finite_nan_becomes_zero", function()
			test_guard_finite_nan_becomes_zero()
		end)

		-- GuardFinite direct unit tests -- +Infinity flavor, tested SEPARATELY per the story's own
		-- falsifiability-control rigor (H.25c precedent).
		local function test_guard_finite_positive_infinity_becomes_zero()
			expect(SquadAggregateLogic.GuardFinite(math.huge)).to.equal(0.0)
		end
		it("test_guard_finite_positive_infinity_becomes_zero", function()
			test_guard_finite_positive_infinity_becomes_zero()
		end)

		-- GuardFinite passes through an ordinary finite value unchanged.
		local function test_guard_finite_passes_through_ordinary_value()
			expect(SquadAggregateLogic.GuardFinite(0.42)).to.equal(0.42)
		end
		it("test_guard_finite_passes_through_ordinary_value", function()
			test_guard_finite_passes_through_ordinary_value()
		end)

		-- Integration: a single corrupted (NaN) per-player reading must not corrupt squadT --
		-- the guard applies to each per-player playerT before the max is taken.
		local function test_nan_corrupted_player_reading_does_not_corrupt_squad_t()
			local p1, pCorrupt, p3 = {}, {}, {}
			local nan = 0 / 0
			local members, fieldValueFn = makeSquadSession({
				[p1] = 0.10,
				[pCorrupt] = nan,
				[p3] = 0.05,
			})

			local squadT = SquadAggregateLogic.ComputeSquadAggregateT(members, nil, fieldValueFn)
			expect(squadT ~= squadT).to.equal(false) -- squadT itself must not be NaN
			expect(almostEqual(squadT, 0.10, 0.001)).to.equal(true) -- guarded NaN reads as 0.0, ignored by max
		end
		it(
			"test_nan_corrupted_player_reading_does_not_corrupt_squad_t",
			function()
				test_nan_corrupted_player_reading_does_not_corrupt_squad_t()
			end
		)

		-- Integration: a single corrupted (+Infinity) per-player reading must not corrupt squadT,
		-- tested SEPARATELY from the NaN flavor above.
		local function test_positive_infinity_corrupted_player_reading_does_not_corrupt_squad_t()
			local p1, pCorrupt, p3 = {}, {}, {}
			local members, fieldValueFn = makeSquadSession({
				[p1] = 0.10,
				[pCorrupt] = math.huge,
				[p3] = 0.05,
			})

			local squadT = SquadAggregateLogic.ComputeSquadAggregateT(members, nil, fieldValueFn)
			expect(squadT == math.huge).to.equal(false)
			expect(almostEqual(squadT, 0.10, 0.001)).to.equal(true)
		end
		it(
			"test_positive_infinity_corrupted_player_reading_does_not_corrupt_squad_t",
			function()
				test_positive_infinity_corrupted_player_reading_does_not_corrupt_squad_t()
			end
		)

		-- Integration: EVERY connected player corrupted (NaN) -> squadT is exactly 0.0, not NaN.
		local function test_all_players_nan_corrupted_squad_t_is_exactly_zero()
			local p1, p2 = {}, {}
			local nan = 0 / 0
			local members, fieldValueFn = makeSquadSession({
				[p1] = nan,
				[p2] = nan,
			})

			local squadT = SquadAggregateLogic.ComputeSquadAggregateT(members, nil, fieldValueFn)
			expect(squadT).to.equal(0.0)
		end
		it(
			"test_all_players_nan_corrupted_squad_t_is_exactly_zero",
			function()
				test_all_players_nan_corrupted_squad_t_is_exactly_zero()
			end
		)
	end)

	describe("DisturbanceServiceSquadAggregateLogic -- Story 007 (H.22c exclusion-form pinned semantics)", function()
		-- AC-H.22c: 4-player session {P1=0.71, P2=0.34, P3=0.09, P4=0.02}.
		local function buildFourPlayerSession(): ({ SquadMember }, (Vector3) -> number, any, any, any, any)
			local p1, p2, p3, p4 = {}, {}, {}, {}
			local members, fieldValueFn = makeSquadSession({
				[p1] = 0.71,
				[p2] = 0.34,
				[p3] = 0.09,
				[p4] = 0.02,
			})
			return members, fieldValueFn, p1, p2, p3, p4
		end

		-- (a) GetSquadAggregateT(P1) -> 0.34 +/- 0.001 (max of the remaining 3).
		local function test_h22c_exclude_p1_returns_max_of_remaining_three()
			local members, fieldValueFn, p1 = buildFourPlayerSession()
			local result = SquadAggregateLogic.ComputeSquadAggregateT(members, p1, fieldValueFn)
			expect(almostEqual(result, 0.34, 0.001)).to.equal(true)
		end
		it("test_h22c_exclude_p1_returns_max_of_remaining_three", function()
			test_h22c_exclude_p1_returns_max_of_remaining_three()
		end)

		-- (a) GetSquadAggregateT(nil) -> 0.71 +/- 0.001 (the unfiltered D.5 max).
		local function test_h22c_nil_returns_unfiltered_max()
			local members, fieldValueFn = buildFourPlayerSession()
			local result = SquadAggregateLogic.ComputeSquadAggregateT(members, nil, fieldValueFn)
			expect(almostEqual(result, 0.71, 0.001)).to.equal(true)
		end
		it("test_h22c_nil_returns_unfiltered_max", function()
			test_h22c_nil_returns_unfiltered_max()
		end)

		-- (b) 1-player session, lone player P at 0.55 -> GetSquadAggregateT(P) -> 0.55 +/- 0.001
		-- (empty-remainder returns the UNFILTERED max, NOT 0.0, NOT nil).
		local function test_h22c_solo_session_excluding_the_lone_player_returns_own_t_not_zero()
			local p = {}
			local members, fieldValueFn = makeSquadSession({ [p] = 0.55 })

			local result = SquadAggregateLogic.ComputeSquadAggregateT(members, p, fieldValueFn)
			expect(result).never.to.equal(nil)
			expect(almostEqual(result, 0.55, 0.001)).to.equal(true)
			expect(result).never.to.equal(0.0)
		end
		it(
			"test_h22c_solo_session_excluding_the_lone_player_returns_own_t_not_zero",
			function()
				test_h22c_solo_session_excluding_the_lone_player_returns_own_t_not_zero()
			end
		)

		-- (c) zero connected players, called with ANY argument (even a stale/disconnected Player
		-- reference) -> exactly 0.0.
		local function test_h22c_zero_connected_players_with_any_argument_returns_exactly_zero()
			local staleReference = {}
			local members: { SquadMember } = {}
			local function fieldValueFn(_position: Vector3): number
				return 0.9
			end

			local result = SquadAggregateLogic.ComputeSquadAggregateT(members, staleReference, fieldValueFn)
			expect(result).to.equal(0.0)
		end
		it(
			"test_h22c_zero_connected_players_with_any_argument_returns_exactly_zero",
			function()
				test_h22c_zero_connected_players_with_any_argument_returns_exactly_zero()
			end
		)

		-- Edge case: calling with a Player reference that is NOT currently in the connected set
		-- (e.g. already departed) -- falls through to the unfiltered max gracefully, no error.
		local function test_h22c_excluding_a_departed_player_falls_through_to_unfiltered_max()
			local members, fieldValueFn = buildFourPlayerSession()
			local departedPlayer = {} -- never inserted into `members` at all

			local ok, result = pcall(function()
				return SquadAggregateLogic.ComputeSquadAggregateT(members, departedPlayer, fieldValueFn)
			end)

			expect(ok).to.equal(true)
			expect(almostEqual(result, 0.71, 0.001)).to.equal(true)
		end
		it(
			"test_h22c_excluding_a_departed_player_falls_through_to_unfiltered_max",
			function()
				test_h22c_excluding_a_departed_player_falls_through_to_unfiltered_max()
			end
		)

		-- (d) finiteness guard applies identically to the exclusion form: a corrupted (NaN) OTHER
		-- player must not corrupt the exclusion-form result either.
		local function test_h22c_finiteness_guard_applies_identically_to_exclusion_form()
			local p1, pCorrupt, p3 = {}, {}, {}
			local nan = 0 / 0
			local members, fieldValueFn = makeSquadSession({
				[p1] = 0.20,
				[pCorrupt] = nan,
				[p3] = 0.05,
			})

			-- Exclude p3; the remaining pool is {p1=0.20, pCorrupt=NaN->guarded 0.0}.
			local result = SquadAggregateLogic.ComputeSquadAggregateT(members, p3, fieldValueFn)
			expect(result ~= result).to.equal(false)
			expect(almostEqual(result, 0.20, 0.001)).to.equal(true)
		end
		it(
			"test_h22c_finiteness_guard_applies_identically_to_exclusion_form",
			function()
				test_h22c_finiteness_guard_applies_identically_to_exclusion_form()
			end
		)
	end)

	describe("DisturbanceServiceSquadAggregateLogic -- Story 007 (cost/cadence: O(P) reads, not O(P x calls))", function()
		-- Given 4 connected players, calling ComputeSquadAggregateT at a simulated 4Hz cadence for
		-- a sustained period (N calls) must cost exactly P reads PER CALL (4 x N total), never
		-- P x N x (something extra) from re-derivation, and never more than one fieldValueFn
		-- invocation per member per call (both the unfiltered max and any exclusion-form remainder
		-- reuse the SAME per-call reads).
		local function test_cost_is_linear_in_calls_not_quadratic_across_sustained_cadence()
			local p1, p2, p3, p4 = {}, {}, {}, {}
			local members, fieldValueFn, getCallCount = makeSquadSession({
				[p1] = 0.71,
				[p2] = 0.34,
				[p3] = 0.09,
				[p4] = 0.02,
			})

			local N = 40 -- e.g. 10 seconds at a simulated 4Hz cadence
			for i = 1, N do
				-- Alternate nil / excluded-player forms -- both must stay O(P) per call.
				local excludePlayer = if i % 2 == 0 then p1 else nil
				SquadAggregateLogic.ComputeSquadAggregateT(members, excludePlayer, fieldValueFn)
			end

			expect(getCallCount()).to.equal(4 * N)
		end
		it(
			"test_cost_is_linear_in_calls_not_quadratic_across_sustained_cadence",
			function()
				test_cost_is_linear_in_calls_not_quadratic_across_sustained_cadence()
			end
		)

		-- A single call with an exclusion form must not invoke fieldValueFn more than once per
		-- member (i.e. the exclusion-form remainder computation must not trigger a second pass of
		-- reads on top of the unfiltered-max pass).
		local function test_single_exclusion_form_call_reads_each_member_exactly_once()
			local p1, p2, p3, p4 = {}, {}, {}, {}
			local members, fieldValueFn, getCallCount = makeSquadSession({
				[p1] = 0.71,
				[p2] = 0.34,
				[p3] = 0.09,
				[p4] = 0.02,
			})

			SquadAggregateLogic.ComputeSquadAggregateT(members, p2, fieldValueFn)
			expect(getCallCount()).to.equal(4)
		end
		it(
			"test_single_exclusion_form_call_reads_each_member_exactly_once",
			function()
				test_single_exclusion_form_call_reads_each_member_exactly_once()
			end
		)
	end)

	describe("DisturbanceServiceSquadAggregateLogic -- Story 007 (server-internal-only structural check)", function()
		-- This module itself has no Knit/.Client surface at all (zero-require, zero-Roblox-service
		-- precedent) -- confirms it never references DisturbanceService.Client or Knit directly,
		-- matching every sibling *Logic module's own structural precedent.
		--
		-- COMMENT-STRIPPING NOTE: this module's own header comments describe the zero-require
		-- precedent in prose (e.g. "OR any require() at all", "does not require() that sibling
		-- module either") -- comments are stripped first (naive first-`--`-match stripper, matching
		-- Stories 002/003/004/005's own precedent) so only real code is scanned for `.Client` /
		-- `require(` occurrences.
		local function stripLuaCommentsForClientCheck(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function test_module_has_zero_client_or_knit_references()
			local source =
				stripLuaCommentsForClientCheck(fs.readFile("src/gameplay/services/DisturbanceServiceSquadAggregateLogic.luau"))
			expect(source:find("%.Client")).to.equal(nil)
			expect(source:find("require%(")).to.equal(nil)
		end
		it("test_module_has_zero_client_or_knit_references", function()
			test_module_has_zero_client_or_knit_references()
		end)
	end)

	describe("DisturbanceServiceSquadAggregateLogic -- Story 007 (DisturbanceService.luau wiring, static checks)", function()
		local disturbanceServiceSource: string? = nil

		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function loadServiceSource(): string
			if not disturbanceServiceSource then
				disturbanceServiceSource = stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceService.luau"))
			end
			return disturbanceServiceSource :: string
		end

		-- Server-internal-only: GetSquadAggregateT is never exposed via .Client (matching Stories
		-- 002/003/004/005's own precedent test -- this file's `Client = {}` table stays empty).
		local function test_get_squad_aggregate_t_never_exposed_to_clients()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it("test_get_squad_aggregate_t_never_exposed_to_clients", function()
			test_get_squad_aggregate_t_never_exposed_to_clients()
		end)

		-- Wiring confirmation: GetSquadAggregateT exists, requires the new pure-logic module, and
		-- delegates to ComputeSquadAggregateT -- never re-implementing the max/exclusion math
		-- locally.
		local function test_disturbance_service_wires_get_squad_aggregate_t()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:GetSquadAggregateT%(")).never.to.equal(nil)
			expect(source:find("require%(script%.Parent%.DisturbanceServiceSquadAggregateLogic%)")).never.to.equal(nil)
			expect(source:find("SquadAggregateLogic%.ComputeSquadAggregateT%(")).never.to.equal(nil)
			expect(source:find("Players:GetPlayers%(%)")).never.to.equal(nil)
			expect(source:find("HumanoidRootPart")).never.to.equal(nil)
		end
		it("test_disturbance_service_wires_get_squad_aggregate_t", function()
			test_disturbance_service_wires_get_squad_aggregate_t()
		end)

		-- GetSquadAggregateT calls self:fieldValue(...) (the Story 005 per-pass-cached accessor),
		-- never recomputing decay math itself.
		local function test_get_squad_aggregate_t_delegates_to_field_value()
			local source = loadServiceSource()
			local startIndex = source:find("function DisturbanceService:GetSquadAggregateT%(")
			expect(startIndex).never.to.equal(nil)
			local endIndex = source:find("\nend", startIndex :: number)
			local body = source:sub(startIndex :: number, endIndex)
			expect(body:find("self:fieldValue%(")).never.to.equal(nil)
		end
		it("test_get_squad_aggregate_t_delegates_to_field_value", function()
			test_get_squad_aggregate_t_delegates_to_field_value()
		end)
	end)

	-- ============================================================================
	-- Code-review follow-up (ed-7+ed-8 review, 2026-07-08): H.25c(d) explicitly ties
	-- GetHottestHotspot's NaN-corruption scenario to GetSquadAggregateT's own fail-quiet
	-- guarantee ("squadT = 0.0 publishes... in both nil and exclusion argument forms"), but
	-- neither this file nor hottest-hotspot-query_test.luau previously composed the two REAL
	-- modules together -- each half was independently proven correct, but the specific
	-- cross-module claim in H.25c(d) was never exercised end-to-end. This closes that gap: a
	-- corrupted (NaN-flavored) decay-cache entry, fed through the REAL DecayFalloffLogic
	-- .FieldValueAt (not an injected stub), composed into a REAL ComputeSquadAggregateT call.
	-- ============================================================================
	describe("DisturbanceServiceSquadAggregateLogic -- Story 007 (H.25c(d), REAL fieldValue() composition with SquadAggregateLogic)", function()
		local function makeWorld(): (SpatialGrid, { [string]: DecayableSource }, DecayCache)
			return {}, {}, {}
		end

		local function insertSource(
			grid: SpatialGrid,
			liveSources: { [string]: DecayableSource },
			decayCache: DecayCache,
			emissionId: string,
			position: Vector3,
			magnitude: number
		): ()
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, SPATIAL_GRID_CELL_SIZE)
			SpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, emissionId)
			liveSources[emissionId] = {
				emissionId = emissionId,
				sourcePlayerId = 1,
				emissionType = "Gather",
				emissionTime = 0,
				position = position,
			}
			decayCache[emissionId] = { magnitude = magnitude, expired = false }
		end

		local function fieldValueViaWorld(grid: SpatialGrid, liveSources: { [string]: DecayableSource }, decayCache: DecayCache, position: Vector3): number
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, SPATIAL_GRID_CELL_SIZE)
			local candidateIds = SpatialGridLogic.QueryNeighborhood(grid, cellX, cellZ)
			return DecayFalloffLogic.FieldValueAt(position, candidateIds, liveSources, decayCache, INFLUENCE_RADIUS)
		end

		-- H.25c(d): a probe player positioned within INFLUENCE_RADIUS of a NaN-corrupted source,
		-- WHEN squadT is computed via the REAL composed fieldValue() path, THEN squadT publishes
		-- as 0.0 -- never NaN/+Inf -- in BOTH the nil and exclusion argument forms.
		local function test_h25c_d_squad_t_is_zero_under_real_nan_corruption_both_argument_forms()
			local grid, liveSources, decayCache = makeWorld()
			insertSource(grid, liveSources, decayCache, "corrupted", Vector3.new(0, 0, 0), 0 / 0)

			local pProbe, pOther = {}, {}
			local members: { SquadMember } = {
				{ player = pProbe, position = Vector3.new(0, 0, 0) }, -- coincides with the corrupted source
				{ player = pOther, position = Vector3.new(1000, 0, 1000) }, -- far away, legitimately 0.0
			}

			local function realFieldValueFn(position: Vector3): number
				return fieldValueViaWorld(grid, liveSources, decayCache, position)
			end

			-- Sanity precondition: confirm the probe's own fieldValue() read really is non-finite
			-- before asserting the downstream guard engaged (proves the guard isn't vacuously
			-- passing because the corruption never reached it).
			local probeRawValue = realFieldValueFn(Vector3.new(0, 0, 0))
			expect(probeRawValue == probeRawValue).to.equal(false) -- genuinely NaN

			local squadTNilForm = SquadAggregateLogic.ComputeSquadAggregateT(members, nil, realFieldValueFn)
			expect(squadTNilForm).to.equal(0.0)
			expect(squadTNilForm == squadTNilForm).to.equal(true) -- finite, not NaN

			local squadTExclusionForm = SquadAggregateLogic.ComputeSquadAggregateT(members, pOther, realFieldValueFn)
			expect(squadTExclusionForm).to.equal(0.0)
			expect(squadTExclusionForm == squadTExclusionForm).to.equal(true) -- finite, not NaN
		end
		it(
			"test_h25c_d_squad_t_is_zero_under_real_nan_corruption_both_argument_forms",
			function()
				test_h25c_d_squad_t_is_zero_under_real_nan_corruption_both_argument_forms()
			end
		)
	end)
end
