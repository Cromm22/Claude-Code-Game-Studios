--!strict
-- decay-falloff-fieldvalue_test
--
-- Unit tests for Story 005: Decay Formula, Spatial Falloff & fieldValue().
-- Story: production/epics/ecological-disturbance/story-005-decay-falloff-fieldvalue.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceDecayFalloffLogic.luau (pure decay-magnitude math
--     D.1, per-source decay caching TR-ed-017, dist2DSquared/dist2D helpers, the D.2 falloff/
--     contribution formula, and D.3's fieldValue() aggregation -- H.7 through H.16, H.9b, H.9c)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only, for
--     the same reason Stories 002/003/004's own test files give -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live DisturbanceService instance is not
--     currently possible in an automated test -- the wiring/test-seam ACs are instead proven via
--     source-text checks against the real file)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate).
--
-- SCOPE NOTE (flagged, not silent): AC-H.9c's stated math.sqrt bound is
-- "30 x (Q + C + 1)" where C is the candidate count from a single GetHottestHotspot() call.
-- GetHottestHotspot is explicitly Story 008's scope (this story's own Out of Scope section) and
-- does not exist yet -- the H.9c tests below exercise Q query positions only (C=0), and the
-- bound assertions substitute C=0 accordingly. Flagged in this story's final report.

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local DecayFalloffLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceDecayFalloffLogic)
local SpatialGridLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceSpatialGridLogic)

type DecayableSource = DecayFalloffLogic.DecayableSource
type DecayCache = DecayFalloffLogic.DecayCache

-- STANDARD_HALF_LIFE / BEACON_HALF_LIFE / MAGNITUDE_FLOOR / INFLUENCE_RADIUS / SPATIAL_GRID_CELL_SIZE
-- literals below intentionally match DisturbanceConstants.luau's published values (30 / 90 / 0.02
-- / 24 / 32) without require()-ing that module -- this test file follows the exact same
-- harness-driven precedent Stories 002/003/004's own test files document (DisturbanceConstants
-- .luau is not mounted under this harness's ServerScriptService tree).
local STANDARD_HALF_LIFE = 30
local BEACON_HALF_LIFE = 90
local MAGNITUDE_FLOOR = 0.02
local INFLUENCE_RADIUS = 24
local SPATIAL_GRID_CELL_SIZE = 32

local function almostEqual(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

--- Builds a well-formed DecayableSource record for test setup.
local function makeSource(
	emissionId: string,
	emissionType: string,
	initialMagnitude: number,
	emissionTime: number,
	position: Vector3?
): DecayableSource
	return {
		emissionId = emissionId,
		sourcePlayerId = 1,
		emissionType = emissionType :: any,
		position = position or Vector3.new(0, 0, 0),
		initialMagnitude = initialMagnitude,
		emissionTime = emissionTime,
	}
end

--- Builds a counting wrapper around a real math function, for exp/sqrt/pow call-count ACs
--- (H.9b, H.9c). Returns (wrappedFn, getCount).
local function makeCountingWrapper(realFn: (number) -> number): ((number) -> number, () -> number)
	local count = 0
	local function wrapped(x: number): number
		count += 1
		return realFn(x)
	end
	local function getCount(): number
		return count
	end
	return wrapped, getCount
end

--- Same idea as makeCountingWrapper, but for dist2D's own (Vector3, Vector3) -> number
--- signature (used to indirectly count math.sqrt calls -- see the LUNE READONLY-MATH-TABLE NOTE
--- below, near this file's H.9c tests, for why dist2D itself is the wrap target).
local function makeDist2DCountingWrapper(realDist2D: (Vector3, Vector3) -> number): ((Vector3, Vector3) -> number, () -> number)
	local count = 0
	local function wrapped(a: Vector3, b: Vector3): number
		count += 1
		return realDist2D(a, b)
	end
	local function getCount(): number
		return count
	end
	return wrapped, getCount
end

--- Queries the spatial grid exactly as DisturbanceService.luau's real fieldValue() wrapper does
--- (CellCoordFor -> QueryNeighborhood), then delegates to DecayFalloffLogic.FieldValueAt -- the
--- same composition this module's own CANDIDATE ENUMERATION OWNERSHIP header note describes.
local function fieldValueViaGrid(
	queryPosition: Vector3,
	grid: SpatialGridLogic.SpatialGrid,
	liveSources: { [string]: DecayableSource },
	decayCache: DecayCache,
	influenceRadius: number
): number
	local cellX, cellZ = SpatialGridLogic.CellCoordFor(queryPosition, SPATIAL_GRID_CELL_SIZE)
	local candidateIds = SpatialGridLogic.QueryNeighborhood(grid, cellX, cellZ)
	return DecayFalloffLogic.FieldValueAt(queryPosition, candidateIds, liveSources, decayCache, influenceRadius)
end

return function()
	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (dist2DSquared / dist2D helpers)", function()
		local function test_dist2dsquared_computes_xz_only_squared_distance()
			local a = Vector3.new(0, 0, 0)
			local b = Vector3.new(3, 999, 4)
			expect(DecayFalloffLogic.dist2DSquared(a, b)).to.equal(25) -- 3^2 + 4^2 = 25, Y ignored
		end
		it("test_dist2dsquared_computes_xz_only_squared_distance", function()
			test_dist2dsquared_computes_xz_only_squared_distance()
		end)

		local function test_dist2d_is_sqrt_of_dist2dsquared()
			local a = Vector3.new(0, 0, 0)
			local b = Vector3.new(3, 0, 4)
			expect(DecayFalloffLogic.dist2D(a, b)).to.equal(5) -- sqrt(25) = 5
		end
		it("test_dist2d_is_sqrt_of_dist2dsquared", function()
			test_dist2d_is_sqrt_of_dist2dsquared()
		end)

		-- H.16 basis: Y is fully ignored by both helpers.
		local function test_dist2d_ignores_y_separation_entirely()
			local a = Vector3.new(10, 0, 10)
			local b = Vector3.new(10, 500, 10)
			expect(DecayFalloffLogic.dist2D(a, b)).to.equal(0)
		end
		it("test_dist2d_ignores_y_separation_entirely", function()
			test_dist2d_ignores_y_separation_entirely()
		end)
	end)

	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (D.1 decay formula, H.7/H.8, half-life selection)", function()
		local function test_half_life_for_returns_standard_for_gather_sprint_light()
			expect(DecayFalloffLogic.HalfLifeFor("Gather", STANDARD_HALF_LIFE, BEACON_HALF_LIFE)).to.equal(STANDARD_HALF_LIFE)
			expect(DecayFalloffLogic.HalfLifeFor("Sprint", STANDARD_HALF_LIFE, BEACON_HALF_LIFE)).to.equal(STANDARD_HALF_LIFE)
			expect(DecayFalloffLogic.HalfLifeFor("Light", STANDARD_HALF_LIFE, BEACON_HALF_LIFE)).to.equal(STANDARD_HALF_LIFE)
		end
		it("test_half_life_for_returns_standard_for_gather_sprint_light", function()
			test_half_life_for_returns_standard_for_gather_sprint_light()
		end)

		local function test_half_life_for_returns_beacon_half_life_for_beacon()
			expect(DecayFalloffLogic.HalfLifeFor("Beacon", STANDARD_HALF_LIFE, BEACON_HALF_LIFE)).to.equal(BEACON_HALF_LIFE)
		end
		it("test_half_life_for_returns_beacon_half_life_for_beacon", function()
			test_half_life_for_returns_beacon_half_life_for_beacon()
		end)

		-- AC-H.7: initialMagnitude=0.25, age=STANDARD_HALF_LIFE(30) -> m ~= 0.125 +/- 0.001.
		local function test_h7_standard_half_life_decay_at_exactly_one_half_life()
			local age = DecayFalloffLogic.ComputeAge(30, 0)
			local halfLife = DecayFalloffLogic.HalfLifeFor("Gather", STANDARD_HALF_LIFE, BEACON_HALF_LIFE)
			local magnitude = DecayFalloffLogic.ComputeDecayedMagnitude(0.25, age, halfLife)
			expect(almostEqual(magnitude, 0.125, 0.001)).to.equal(true)
		end
		it("test_h7_standard_half_life_decay_at_exactly_one_half_life", function()
			test_h7_standard_half_life_decay_at_exactly_one_half_life()
		end)

		-- H.7 edge case: age=0 returns exactly initialMagnitude.
		local function test_h7_edge_age_zero_returns_exact_initial_magnitude()
			local age = DecayFalloffLogic.ComputeAge(1000, 1000)
			expect(age).to.equal(0)
			local magnitude = DecayFalloffLogic.ComputeDecayedMagnitude(0.25, age, STANDARD_HALF_LIFE)
			expect(magnitude).to.equal(0.25)
		end
		it("test_h7_edge_age_zero_returns_exact_initial_magnitude", function()
			test_h7_edge_age_zero_returns_exact_initial_magnitude()
		end)

		-- H.7 edge case: age far beyond half-life (3x) returns the correctly-compounded decayed
		-- value (0.25 * 0.5^3 = 0.03125), NOT floor-clamped -- ComputeDecayedMagnitude never
		-- clamps to MAGNITUDE_FLOOR itself.
		local function test_h7_edge_age_far_beyond_half_life_is_correctly_compounded_not_floor_clamped()
			local age = DecayFalloffLogic.ComputeAge(90, 0) -- 3 x STANDARD_HALF_LIFE
			local magnitude = DecayFalloffLogic.ComputeDecayedMagnitude(0.25, age, STANDARD_HALF_LIFE)
			expect(almostEqual(magnitude, 0.03125, 0.001)).to.equal(true)
			-- Still above MAGNITUDE_FLOOR (0.02) -- proves this is the real exponential value, not
			-- a clamp.
			expect(magnitude > MAGNITUDE_FLOOR).to.equal(true)
		end
		it(
			"test_h7_edge_age_far_beyond_half_life_is_correctly_compounded_not_floor_clamped",
			function()
				test_h7_edge_age_far_beyond_half_life_is_correctly_compounded_not_floor_clamped()
			end
		)

		-- AC-H.8: Beacon, initialMagnitude=0.95, age=BEACON_HALF_LIFE(90) -> m ~= 0.475 +/- 0.001.
		local function test_h8_beacon_half_life_decay_at_exactly_one_half_life()
			local age = DecayFalloffLogic.ComputeAge(90, 0)
			local halfLife = DecayFalloffLogic.HalfLifeFor("Beacon", STANDARD_HALF_LIFE, BEACON_HALF_LIFE)
			local magnitude = DecayFalloffLogic.ComputeDecayedMagnitude(0.95, age, halfLife)
			expect(almostEqual(magnitude, 0.475, 0.001)).to.equal(true)
		end
		it("test_h8_beacon_half_life_decay_at_exactly_one_half_life", function()
			test_h8_beacon_half_life_decay_at_exactly_one_half_life()
		end)

		-- ComputeAge defensive clamp: a (should-be-impossible) future emissionTime never produces
		-- a negative age.
		local function test_compute_age_clamps_negative_to_zero()
			expect(DecayFalloffLogic.ComputeAge(100, 150)).to.equal(0)
		end
		it("test_compute_age_clamps_negative_to_zero", function()
			test_compute_age_clamps_negative_to_zero()
		end)
	end)

	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (H.9/H.10 strict-less-than expiry boundary)", function()
		-- AC-H.9 edge case: m == MAGNITUDE_FLOOR exactly is NOT culled (strict less-than).
		local function test_is_expired_false_exactly_at_floor()
			expect(DecayFalloffLogic.IsExpired(MAGNITUDE_FLOOR, MAGNITUDE_FLOOR)).to.equal(false)
		end
		it("test_is_expired_false_exactly_at_floor", function()
			test_is_expired_false_exactly_at_floor()
		end)

		local function test_is_expired_true_strictly_below_floor()
			expect(DecayFalloffLogic.IsExpired(0.0199, MAGNITUDE_FLOOR)).to.equal(true)
		end
		it("test_is_expired_true_strictly_below_floor", function()
			test_is_expired_true_strictly_below_floor()
		end)

		local function test_is_expired_false_above_floor()
			expect(DecayFalloffLogic.IsExpired(0.5, MAGNITUDE_FLOOR)).to.equal(false)
		end
		it("test_is_expired_false_above_floor", function()
			test_is_expired_false_above_floor()
		end)

		-- AC-H.10: initialMagnitude = MAGNITUDE_FLOOR exactly, age=0 -> contributes its full
		-- (negligible) magnitude, NOT culled.
		local function test_h10_source_at_floor_magnitude_age_zero_is_not_expired()
			local liveSources: { [string]: DecayableSource } = {
				floorSource = makeSource("floorSource", "Gather", MAGNITUDE_FLOOR, 1000),
			}
			local decayCache: DecayCache = {}
			DecayFalloffLogic.RunDecayPass(liveSources, decayCache, 1000, STANDARD_HALF_LIFE, BEACON_HALF_LIFE, MAGNITUDE_FLOOR)

			expect(decayCache["floorSource"].magnitude).to.equal(MAGNITUDE_FLOOR)
			expect(decayCache["floorSource"].expired).to.equal(false)
		end
		it("test_h10_source_at_floor_magnitude_age_zero_is_not_expired", function()
			test_h10_source_at_floor_magnitude_age_zero_is_not_expired()
		end)

		-- AC-H.10 continued: after decaying strictly below the floor, the same source IS flagged
		-- expired on a later pass.
		local function test_h10_source_at_floor_magnitude_eventually_expires_after_decay()
			local liveSources: { [string]: DecayableSource } = {
				floorSource = makeSource("floorSource", "Gather", MAGNITUDE_FLOOR, 1000),
			}
			local decayCache: DecayCache = {}
			-- Far enough past emission that even a tiny starting magnitude has decayed below floor.
			DecayFalloffLogic.RunDecayPass(
				liveSources,
				decayCache,
				1000 + STANDARD_HALF_LIFE * 5,
				STANDARD_HALF_LIFE,
				BEACON_HALF_LIFE,
				MAGNITUDE_FLOOR
			)

			expect(decayCache["floorSource"].expired).to.equal(true)
			local expiredIds = DecayFalloffLogic.FindExpiredSourceIds(liveSources, decayCache)
			expect(#expiredIds).to.equal(1)
			expect(expiredIds[1]).to.equal("floorSource")
		end
		it("test_h10_source_at_floor_magnitude_eventually_expires_after_decay", function()
			test_h10_source_at_floor_magnitude_eventually_expires_after_decay()
		end)

		-- AC-H.9: FindExpiredSourceIds never includes a live, non-expired source.
		local function test_find_expired_source_ids_excludes_live_sources()
			local liveSources: { [string]: DecayableSource } = {
				fresh = makeSource("fresh", "Gather", 0.25, 1000),
			}
			local decayCache: DecayCache = {}
			DecayFalloffLogic.RunDecayPass(liveSources, decayCache, 1000, STANDARD_HALF_LIFE, BEACON_HALF_LIFE, MAGNITUDE_FLOOR)

			local expiredIds = DecayFalloffLogic.FindExpiredSourceIds(liveSources, decayCache)
			expect(#expiredIds).to.equal(0)
		end
		it("test_find_expired_source_ids_excludes_live_sources", function()
			test_find_expired_source_ids_excludes_live_sources()
		end)
	end)

	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (H.9b per-source decay caching)", function()
		-- AC-H.9b core case: 100 sources, 50 query positions in ONE pass -> math.exp called at
		-- most 100 times, never 5000. Re-running the same pass's queries a second time must not
		-- increase the count further.
		local function test_h9b_exp_called_at_most_once_per_source_per_pass()
			local liveSources: { [string]: DecayableSource } = {}
			for i = 1, 100 do
				local id = "source" .. tostring(i)
				liveSources[id] = makeSource(id, "Gather", 0.25, 0, Vector3.new(i * 5, 0, 0))
			end
			local decayCache: DecayCache = {}

			local countingExp, getExpCount = makeCountingWrapper(math.exp)

			-- ONE decay pass -- exactly 100 sources -> at most 100 exp calls.
			DecayFalloffLogic.RunDecayPass(liveSources, decayCache, 100, STANDARD_HALF_LIFE, BEACON_HALF_LIFE, MAGNITUDE_FLOOR, countingExp)
			expect(getExpCount() <= 100).to.equal(true)
			local countAfterPass = getExpCount()

			-- 50 query positions against the SAME pass's cached values -- FieldValueAt never
			-- touches expFn at all, so the count must not increase.
			for q = 1, 50 do
				local candidateIds = {}
				for id in liveSources do
					table.insert(candidateIds, id)
				end
				DecayFalloffLogic.FieldValueAt(Vector3.new(q, 0, 0), candidateIds, liveSources, decayCache, INFLUENCE_RADIUS)
			end
			expect(getExpCount()).to.equal(countAfterPass)

			-- Re-running the SAME pass's queries a second time (no new RunDecayPass call, no
			-- clock advance) -- the cached values must be reused, so the count still must not
			-- increase.
			for q = 1, 50 do
				local candidateIds = {}
				for id in liveSources do
					table.insert(candidateIds, id)
				end
				DecayFalloffLogic.FieldValueAt(Vector3.new(q, 0, 0), candidateIds, liveSources, decayCache, INFLUENCE_RADIUS)
			end
			expect(getExpCount()).to.equal(countAfterPass)
		end
		it("test_h9b_exp_called_at_most_once_per_source_per_pass", function()
			test_h9b_exp_called_at_most_once_per_source_per_pass()
		end)

		-- A second RunDecayPass call (a NEW pass) DOES call exp again, once per source --
		-- confirms the cache is per-pass, not permanent/one-time-only.
		local function test_h9b_a_new_pass_recomputes_exp_once_per_source_again()
			local liveSources: { [string]: DecayableSource } = {
				a = makeSource("a", "Gather", 0.25, 0),
				b = makeSource("b", "Gather", 0.25, 0),
			}
			local decayCache: DecayCache = {}
			local countingExp, getExpCount = makeCountingWrapper(math.exp)

			DecayFalloffLogic.RunDecayPass(liveSources, decayCache, 10, STANDARD_HALF_LIFE, BEACON_HALF_LIFE, MAGNITUDE_FLOOR, countingExp)
			expect(getExpCount()).to.equal(2)

			DecayFalloffLogic.RunDecayPass(liveSources, decayCache, 20, STANDARD_HALF_LIFE, BEACON_HALF_LIFE, MAGNITUDE_FLOOR, countingExp)
			expect(getExpCount()).to.equal(4)
		end
		it("test_h9b_a_new_pass_recomputes_exp_once_per_source_again", function()
			test_h9b_a_new_pass_recomputes_exp_once_per_source_again()
		end)
	end)

	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (H.11-H.13 single-source fieldValue)", function()
		-- AC-H.11: dist2D(P,S)=0 -> fieldValue ~= m +/- 0.001.
		local function test_h11_field_value_at_source_position_equals_decayed_magnitude()
			local source = makeSource("s1", "Gather", 0.25, 0, Vector3.new(50, 0, 50))
			local liveSources: { [string]: DecayableSource } = { s1 = source }
			local decayCache: DecayCache = { s1 = { magnitude = 0.2, expired = false } }

			local value = DecayFalloffLogic.FieldValueAt(Vector3.new(50, 0, 50), { "s1" }, liveSources, decayCache, INFLUENCE_RADIUS)
			expect(almostEqual(value, 0.2, 0.001)).to.equal(true)
		end
		it("test_h11_field_value_at_source_position_equals_decayed_magnitude", function()
			test_h11_field_value_at_source_position_equals_decayed_magnitude()
		end)

		-- AC-H.12: dist2D(P,S) = INFLUENCE_RADIUS exactly -> fieldValue = 0.0 EXACTLY.
		local function test_h12_field_value_at_exact_influence_radius_is_exactly_zero()
			local source = makeSource("s1", "Gather", 0.25, 0, Vector3.new(0, 0, 0))
			local liveSources: { [string]: DecayableSource } = { s1 = source }
			local decayCache: DecayCache = { s1 = { magnitude = 0.5, expired = false } }

			-- Exactly INFLUENCE_RADIUS (24) studs away on the X axis.
			local value = DecayFalloffLogic.FieldValueAt(
				Vector3.new(INFLUENCE_RADIUS, 0, 0),
				{ "s1" },
				liveSources,
				decayCache,
				INFLUENCE_RADIUS
			)
			expect(value).to.equal(0.0)
		end
		it("test_h12_field_value_at_exact_influence_radius_is_exactly_zero", function()
			test_h12_field_value_at_exact_influence_radius_is_exactly_zero()
		end)

		-- AC-H.13: dist2D(P,S) > INFLUENCE_RADIUS -> fieldValue = 0.0 exactly.
		local function test_h13_field_value_beyond_influence_radius_is_exactly_zero()
			local source = makeSource("s1", "Gather", 0.25, 0, Vector3.new(0, 0, 0))
			local liveSources: { [string]: DecayableSource } = { s1 = source }
			local decayCache: DecayCache = { s1 = { magnitude = 0.5, expired = false } }

			local value = DecayFalloffLogic.FieldValueAt(
				Vector3.new(INFLUENCE_RADIUS + 10, 0, 0),
				{ "s1" },
				liveSources,
				decayCache,
				INFLUENCE_RADIUS
			)
			expect(value).to.equal(0.0)
		end
		it("test_h13_field_value_beyond_influence_radius_is_exactly_zero", function()
			test_h13_field_value_beyond_influence_radius_is_exactly_zero()
		end)

		-- Expired / missing sources are silently skipped, never erroring and never contributing.
		local function test_field_value_skips_expired_and_missing_sources()
			local source = makeSource("expired1", "Gather", 0.25, 0, Vector3.new(0, 0, 0))
			local liveSources: { [string]: DecayableSource } = { expired1 = source }
			local decayCache: DecayCache = { expired1 = { magnitude = 0.5, expired = true } }

			local value = DecayFalloffLogic.FieldValueAt(
				Vector3.new(0, 0, 0),
				{ "expired1", "doesNotExist" },
				liveSources,
				decayCache,
				INFLUENCE_RADIUS
			)
			expect(value).to.equal(0)
		end
		it("test_field_value_skips_expired_and_missing_sources", function()
			test_field_value_skips_expired_and_missing_sources()
		end)
	end)

	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (H.9c forbidden-transcendentals static checks)", function()
		local decayFalloffLogicSource: string? = nil

		-- Naive first-`--`-match comment stripper, matching Stories 002/003/004's own reference
		-- implementation exactly (NOT quote-aware -- this project's convention is to avoid `--`
		-- inside warn()/print()/error strings, using `:`/`|` separators instead, which this
		-- story's own production code under test follows).
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function loadDecayFalloffLogicSource(): string
			if not decayFalloffLogicSource then
				decayFalloffLogicSource =
					stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceServiceDecayFalloffLogic.luau"))
			end
			return decayFalloffLogicSource :: string
		end

		-- Extracts the substring from a function's declaration line through its matching
		-- module-level `end` (the next line that is exactly `end` at zero indentation),
		-- restricted to FieldValueAt and Contribution -- "the inner contribution loop" H.9c's AC
		-- text targets.
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

		-- (a) zero math.pow calls in the inner contribution loop (FieldValueAt + Contribution).
		local function test_h9c_zero_math_pow_in_inner_contribution_loop()
			local source = loadDecayFalloffLogicSource()
			local fieldValueBody = extractFunctionBody(source, "function DisturbanceServiceDecayFalloffLogic%.FieldValueAt")
			local contributionBody = extractFunctionBody(source, "function DisturbanceServiceDecayFalloffLogic%.Contribution")

			expect(fieldValueBody:find("math%.pow")).to.equal(nil)
			expect(contributionBody:find("math%.pow")).to.equal(nil)
		end
		it("test_h9c_zero_math_pow_in_inner_contribution_loop", function()
			test_h9c_zero_math_pow_in_inner_contribution_loop()
		end)

		-- (b) zero occurrences of the literal `^` operator in the inner contribution loop.
		-- Plain-text search (4th arg `true`), NOT a Lua pattern, since `^` is a pattern anchor.
		local function test_h9c_zero_caret_operator_in_inner_contribution_loop()
			local source = loadDecayFalloffLogicSource()
			local fieldValueBody = extractFunctionBody(source, "function DisturbanceServiceDecayFalloffLogic%.FieldValueAt")
			local contributionBody = extractFunctionBody(source, "function DisturbanceServiceDecayFalloffLogic%.Contribution")

			expect(fieldValueBody:find("^", 1, true)).to.equal(nil)
			expect(contributionBody:find("^", 1, true)).to.equal(nil)
		end
		it("test_h9c_zero_caret_operator_in_inner_contribution_loop", function()
			test_h9c_zero_caret_operator_in_inner_contribution_loop()
		end)

		-- (c) H.9c edge case: a source that fails the dist2DSquared radius cull must NOT trigger
		-- a math.sqrt call at all.
		--
		-- LUNE READONLY-MATH-TABLE NOTE: Lune's `math` library table is READ-ONLY --
		-- `math.sqrt = ...` errors with "attempt to modify a readonly table" under this project's
		-- test harness. FieldValueAt's inner loop therefore calls `DecayFalloffLogic.dist2D`
		-- THROUGH THE MODULE TABLE (see that function's own TESTABILITY NOTE in the production
		-- file), so this test wraps `DecayFalloffLogic.dist2D` itself instead of the global
		-- `math.sqrt` -- dist2D always calls math.sqrt internally, so counting dist2D invocations
		-- is equivalent to counting sqrt calls for this AC's purposes.
		local function test_h9c_out_of_radius_source_triggers_zero_sqrt_calls()
			local source = makeSource("farAway", "Gather", 0.25, 0, Vector3.new(10000, 0, 10000))
			local liveSources: { [string]: DecayableSource } = { farAway = source }
			local decayCache: DecayCache = { farAway = { magnitude = 0.5, expired = false } }

			local realDist2D = DecayFalloffLogic.dist2D
			local countingDist2D, getSqrtCount = makeDist2DCountingWrapper(realDist2D)
			DecayFalloffLogic.dist2D = countingDist2D

			local ok, value = pcall(function()
				return DecayFalloffLogic.FieldValueAt(Vector3.new(0, 0, 0), { "farAway" }, liveSources, decayCache, INFLUENCE_RADIUS)
			end)

			DecayFalloffLogic.dist2D = realDist2D

			expect(ok).to.equal(true)
			expect(value).to.equal(0)
			expect(getSqrtCount()).to.equal(0)
		end
		it("test_h9c_out_of_radius_source_triggers_zero_sqrt_calls", function()
			test_h9c_out_of_radius_source_triggers_zero_sqrt_calls()
		end)

		-- (c) continued: math.sqrt call count over Q query positions stays within the AC's own
		-- 30 x (Q + C + 1) formula (C=0 here -- GetHottestHotspot is Story 008's scope, not this
		-- story's -- see this file's own SCOPE NOTE header). One in-range source per query
		-- position triggers exactly one sqrt call per query (Q total), well within the 30x(Q+1)
		-- ceiling. See the LUNE READONLY-MATH-TABLE NOTE above for why this wraps
		-- DecayFalloffLogic.dist2D rather than the global math.sqrt.
		local function test_h9c_sqrt_call_count_bounded_across_q_query_positions()
			local liveSources: { [string]: DecayableSource } = {
				near = makeSource("near", "Gather", 0.25, 0, Vector3.new(0, 0, 0)),
			}
			local decayCache: DecayCache = { near = { magnitude = 0.5, expired = false } }

			local realDist2D = DecayFalloffLogic.dist2D
			local countingDist2D, getSqrtCount = makeDist2DCountingWrapper(realDist2D)
			DecayFalloffLogic.dist2D = countingDist2D

			local Q = 20
			local ok = pcall(function()
				for q = 1, Q do
					-- Well within INFLUENCE_RADIUS of the single source at the origin.
					DecayFalloffLogic.FieldValueAt(Vector3.new(1, 0, 1), { "near" }, liveSources, decayCache, INFLUENCE_RADIUS)
				end
			end)

			DecayFalloffLogic.dist2D = realDist2D

			expect(ok).to.equal(true)
			expect(getSqrtCount()).to.equal(Q) -- exactly one radius-cull-passing sqrt call per query
			expect(getSqrtCount() <= 30 * (Q + 0 + 1)).to.equal(true) -- the AC's own bound, C=0
		end
		it("test_h9c_sqrt_call_count_bounded_across_q_query_positions", function()
			test_h9c_sqrt_call_count_bounded_across_q_query_positions()
		end)
	end)

	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (H.14/H.15/H.16 multi-source aggregation)", function()
		-- AC-H.14: two independent sources, both within range -> additive stacking, even sharing
		-- the same sourcePlayerId.
		local function test_h14_two_sources_stack_additively_even_with_shared_source_player_id()
			local s1 = makeSource("s1", "Gather", 0.25, 0, Vector3.new(0, 0, 0))
			local s2 = makeSource("s2", "Gather", 0.25, 0, Vector3.new(5, 0, 0))
			s1.sourcePlayerId = 7
			s2.sourcePlayerId = 7 -- shared sourcePlayerId -- stacking must be unaffected

			local liveSources: { [string]: DecayableSource } = { s1 = s1, s2 = s2 }
			local decayCache: DecayCache = {
				s1 = { magnitude = 0.3, expired = false },
				s2 = { magnitude = 0.2, expired = false },
			}

			local queryPosition = Vector3.new(2, 0, 0)
			local combined = DecayFalloffLogic.FieldValueAt(queryPosition, { "s1", "s2" }, liveSources, decayCache, INFLUENCE_RADIUS)

			local d1 = DecayFalloffLogic.dist2D(queryPosition, s1.position)
			local d2 = DecayFalloffLogic.dist2D(queryPosition, s2.position)
			local expected = DecayFalloffLogic.Contribution(0.3, d1, INFLUENCE_RADIUS)
				+ DecayFalloffLogic.Contribution(0.2, d2, INFLUENCE_RADIUS)

			expect(almostEqual(combined, expected, 0.0001)).to.equal(true)
		end
		it("test_h14_two_sources_stack_additively_even_with_shared_source_player_id", function()
			test_h14_two_sources_stack_additively_even_with_shared_source_player_id()
		end)

		-- AC-H.15: enough sources to exceed 1.0 -> clamped to 1.0 EXACTLY; each source's stored
		-- decayCache magnitude is unaffected by the clamp.
		local function test_h15_field_value_clamps_at_one_without_mutating_stored_magnitudes()
			local liveSources: { [string]: DecayableSource } = {}
			local decayCache: DecayCache = {}
			local candidateIds: { string } = {}

			for i = 1, 5 do
				local id = "s" .. tostring(i)
				liveSources[id] = makeSource(id, "Beacon", 0.95, 0, Vector3.new(0, 0, 0))
				decayCache[id] = { magnitude = 0.9, expired = false } -- 5 x 0.9 = 4.5, far past 1.0
				table.insert(candidateIds, id)
			end

			local value = DecayFalloffLogic.FieldValueAt(Vector3.new(0, 0, 0), candidateIds, liveSources, decayCache, INFLUENCE_RADIUS)
			expect(value).to.equal(1.0)

			-- Each source's raw stored magnitude is queried directly and confirmed unmutated.
			for i = 1, 5 do
				local id = "s" .. tostring(i)
				expect(decayCache[id].magnitude).to.equal(0.9)
			end
		end
		it("test_h15_field_value_clamps_at_one_without_mutating_stored_magnitudes", function()
			test_h15_field_value_clamps_at_one_without_mutating_stored_magnitudes()
		end)

		-- ====================================================================
		-- Code-review follow-up (ed-8's Story 008 review, 2026-07-08): the D.3
		-- clamp `math.min(1.0, total)` silently laundered a NaN `total` into a
		-- finite 1.0 (Retreat-tier, maximum severity) instead of propagating
		-- the corruption -- because Luau's math.min(a, b) returns `a` whenever
		-- `b` is NaN. Fixed by swapping the argument order to
		-- math.min(total, 1.0), so NaN correctly propagates through the clamp
		-- for downstream finiteness guards (H.25c in Story 008, GuardFinite in
		-- Story 007) to catch and disqualify. This is the single WORST
		-- possible fail-quiet failure for this system: a corrupted source
		-- would otherwise WIN hotspot/tier selection outright instead of
		-- being disqualified.
		-- ====================================================================
		local function test_field_value_propagates_nan_total_instead_of_laundering_to_one()
			local liveSources: { [string]: DecayableSource } = {}
			local decayCache: DecayCache = {}

			liveSources["corrupted"] = makeSource("corrupted", "Beacon", 0.95, 0, Vector3.new(0, 0, 0))
			decayCache["corrupted"] = { magnitude = 0 / 0, expired = false } -- NaN magnitude

			local value = DecayFalloffLogic.FieldValueAt(
				Vector3.new(0, 0, 0),
				{ "corrupted" },
				liveSources,
				decayCache,
				INFLUENCE_RADIUS
			)

			-- NaN never equals itself -- this is the standard finiteness assertion idiom.
			expect(value == value).to.equal(false)
			expect(value).never.to.equal(1.0) -- the specific laundering bug this test guards against
		end
		it("test_field_value_propagates_nan_total_instead_of_laundering_to_one", function()
			test_field_value_propagates_nan_total_instead_of_laundering_to_one()
		end)

		local function test_field_value_still_clamps_positive_infinity_total_at_one()
			-- +math.huge is unaffected by the argument-order fix either way -- confirm the
			-- ordinary clamp behavior for the OTHER non-finite flavor is unchanged.
			local liveSources: { [string]: DecayableSource } = {}
			local decayCache: DecayCache = {}

			liveSources["overflowing"] = makeSource("overflowing", "Beacon", 0.95, 0, Vector3.new(0, 0, 0))
			decayCache["overflowing"] = { magnitude = math.huge, expired = false }

			local value = DecayFalloffLogic.FieldValueAt(
				Vector3.new(0, 0, 0),
				{ "overflowing" },
				liveSources,
				decayCache,
				INFLUENCE_RADIUS
			)

			expect(value).to.equal(1.0)
		end
		it("test_field_value_still_clamps_positive_infinity_total_at_one", function()
			test_field_value_still_clamps_positive_infinity_total_at_one()
		end)

		-- AC-H.16: two sources at identical XZ, differing Y -> both contribute identically based
		-- on XZ distance only, queried at a coplanar P.
		local function test_h16_identical_xz_different_y_contribute_identically()
			local low = makeSource("low", "Gather", 0.25, 0, Vector3.new(10, 0, 10))
			local high = makeSource("high", "Gather", 0.25, 0, Vector3.new(10, 40, 10))

			local liveSources: { [string]: DecayableSource } = { low = low, high = high }
			local decayCache: DecayCache = {
				low = { magnitude = 0.4, expired = false },
				high = { magnitude = 0.4, expired = false },
			}

			local queryPosition = Vector3.new(12, 0, 10) -- coplanar with `low`, NOT with `high`
			local lowOnlyValue = DecayFalloffLogic.FieldValueAt(queryPosition, { "low" }, liveSources, decayCache, INFLUENCE_RADIUS)
			local highOnlyValue = DecayFalloffLogic.FieldValueAt(queryPosition, { "high" }, liveSources, decayCache, INFLUENCE_RADIUS)

			expect(lowOnlyValue).to.equal(highOnlyValue)

			local combined = DecayFalloffLogic.FieldValueAt(queryPosition, { "low", "high" }, liveSources, decayCache, INFLUENCE_RADIUS)
			expect(almostEqual(combined, lowOnlyValue + highOnlyValue, 0.0001)).to.equal(true)
		end
		it("test_h16_identical_xz_different_y_contribute_identically", function()
			test_h16_identical_xz_different_y_contribute_identically()
		end)
	end)

	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (D.3 candidate enumeration via Story 003's grid)", function()
		-- Composition test: candidates come from SpatialGridLogic's own 3x3-neighborhood query
		-- primitive (the ADR-0004-mandated mechanism -- see this module's own CANDIDATE
		-- ENUMERATION OWNERSHIP header note), exactly as DisturbanceService.luau's real
		-- fieldValue() wrapper composes the two modules.
		local function test_field_value_via_grid_only_sums_candidates_from_the_queried_neighborhood()
			local grid: SpatialGridLogic.SpatialGrid = {}
			local liveSources: { [string]: DecayableSource } = {}
			local decayCache: DecayCache = {}

			-- A nearby source, placed in the same cell as the query point.
			local nearPosition = Vector3.new(5, 0, 5)
			local nearCellX, nearCellZ = SpatialGridLogic.CellCoordFor(nearPosition, SPATIAL_GRID_CELL_SIZE)
			SpatialGridLogic.InsertSourceIntoGridCell(grid, nearCellX, nearCellZ, "near")
			liveSources["near"] = makeSource("near", "Gather", 0.25, 0, nearPosition)
			decayCache["near"] = { magnitude = 0.5, expired = false }

			-- A far-away source, placed many cells away -- outside the 3x3 neighborhood entirely,
			-- so it must never even be considered as a candidate.
			local farPosition = Vector3.new(5000, 0, 5000)
			local farCellX, farCellZ = SpatialGridLogic.CellCoordFor(farPosition, SPATIAL_GRID_CELL_SIZE)
			SpatialGridLogic.InsertSourceIntoGridCell(grid, farCellX, farCellZ, "far")
			liveSources["far"] = makeSource("far", "Gather", 0.25, 0, farPosition)
			decayCache["far"] = { magnitude = 0.5, expired = false }

			local queryPosition = Vector3.new(6, 0, 6) -- close to `near`, nowhere near `far`
			local value = fieldValueViaGrid(queryPosition, grid, liveSources, decayCache, INFLUENCE_RADIUS)

			local expectedNearOnly =
				DecayFalloffLogic.Contribution(0.5, DecayFalloffLogic.dist2D(queryPosition, nearPosition), INFLUENCE_RADIUS)
			expect(almostEqual(value, expectedNearOnly, 0.0001)).to.equal(true)
		end
		it(
			"test_field_value_via_grid_only_sums_candidates_from_the_queried_neighborhood",
			function()
				test_field_value_via_grid_only_sums_candidates_from_the_queried_neighborhood()
			end
		)
	end)

	describe("DisturbanceServiceDecayFalloffLogic -- Story 005 (DisturbanceService.luau wiring, static checks)", function()
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

		-- No client-callable path: fieldValue()/_setExpFn/decay methods never appear on
		-- DisturbanceService.Client (structural precondition for Story 016, matching Stories
		-- 002/003/004's own precedent test).
		local function test_client_table_remains_empty_no_decay_methods_exposed_to_clients()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it(
			"test_client_table_remains_empty_no_decay_methods_exposed_to_clients",
			function()
				test_client_table_remains_empty_no_decay_methods_exposed_to_clients()
			end
		)

		-- Wiring confirmation: _runFieldUpdatePass actually calls DecayFalloffLogic.RunDecayPass,
		-- and _cullExpiredSources actually calls DecayFalloffLogic.FindExpiredSourceIds.
		local function test_disturbance_service_wires_decay_pass_and_cull()
			local source = loadServiceSource()
			expect(source:find("DecayFalloffLogic%.RunDecayPass%(")).never.to.equal(nil)
			expect(source:find("DecayFalloffLogic%.FindExpiredSourceIds%(")).never.to.equal(nil)
			expect(source:find("_cullExpiredSources")).never.to.equal(nil)
			expect(source:find("DisturbanceConstants%.STANDARD_HALF_LIFE")).never.to.equal(nil)
			expect(source:find("DisturbanceConstants%.BEACON_HALF_LIFE")).never.to.equal(nil)
			expect(source:find("DisturbanceConstants%.MAGNITUDE_FLOOR")).never.to.equal(nil)
		end
		it("test_disturbance_service_wires_decay_pass_and_cull", function()
			test_disturbance_service_wires_decay_pass_and_cull()
		end)

		-- Wiring confirmation: fieldValue() exists and routes through DecayFalloffLogic
		-- .FieldValueAt, using SpatialGridLogic's own CellCoordFor/QueryNeighborhood for
		-- candidate enumeration (never re-implementing that primitive locally).
		local function test_disturbance_service_wires_field_value_accessor()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:fieldValue%(")).never.to.equal(nil)
			expect(source:find("DecayFalloffLogic%.FieldValueAt%(")).never.to.equal(nil)
			expect(source:find("SpatialGridLogic%.QueryNeighborhood%(")).never.to.equal(nil)
			expect(source:find("DisturbanceConstants%.INFLUENCE_RADIUS")).never.to.equal(nil)
		end
		it("test_disturbance_service_wires_field_value_accessor", function()
			test_disturbance_service_wires_field_value_accessor()
		end)

		-- Test-seam AC: _setExpFn exists, is server-internal (not under .Client, confirmed by the
		-- empty-Client-table check above), and is what _runFieldUpdatePass's self._expFn read
		-- actually consumes.
		local function test_disturbance_service_has_set_exp_fn_seam()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:_setExpFn%(")).never.to.equal(nil)
			expect(source:find("self%._expFn = fn")).never.to.equal(nil)
			expect(source:find("self%._expFn")).never.to.equal(nil)
		end
		it("test_disturbance_service_has_set_exp_fn_seam", function()
			test_disturbance_service_has_set_exp_fn_seam()
		end)

		-- Cull orchestration AC: _cullExpiredSources removes from all four parallel stores,
		-- including the grid cell (via SpatialGridLogic.RemoveSourceFromGridCell).
		local function test_disturbance_service_cull_removes_from_all_stores()
			local source = loadServiceSource()
			expect(source:find("SpatialGridLogic%.RemoveSourceFromGridCell%(")).never.to.equal(nil)
			expect(source:find("self%._liveSources%[emissionId%] = nil")).never.to.equal(nil)
			expect(source:find("self%._decayCache%[emissionId%] = nil")).never.to.equal(nil)
			expect(source:find("self%._insertionSequence%[emissionId%] = nil")).never.to.equal(nil)
		end
		it("test_disturbance_service_cull_removes_from_all_stores", function()
			test_disturbance_service_cull_removes_from_all_stores()
		end)

		-- Cadence AC (H.9): the cull runs on the SAME EXPIRY_MAINTENANCE_INTERVAL-gated branch as
		-- the attribution archive's own maintenance pass, not a separate accumulator.
		local function test_disturbance_service_cull_shares_the_maintenance_accumulator_cadence()
			local source = loadServiceSource()
			local maintenanceBranchStart = source:find("if shouldRunArchiveMaintenance then")
			expect(maintenanceBranchStart).never.to.equal(nil)
			local maintenanceBranchEnd = source:find("\tend", maintenanceBranchStart :: number)
			local branchText = source:sub(maintenanceBranchStart :: number, maintenanceBranchEnd)
			expect(branchText:find("_cullExpiredSources")).never.to.equal(nil)
		end
		it(
			"test_disturbance_service_cull_shares_the_maintenance_accumulator_cadence",
			function()
				test_disturbance_service_cull_shares_the_maintenance_accumulator_cadence()
			end
		)
	end)
end
