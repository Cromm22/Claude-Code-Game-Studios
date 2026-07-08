--!strict
-- tier-classification-hysteresis-tiercrossedevent_test
--
-- Unit tests for Story 006: Tier Classification with Hysteresis, TierCrossedEvent & Post-Hitch
-- Cascade.
-- Story: production/epics/ecological-disturbance/story-006-tier-classification-hysteresis-tiercrossedevent.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceTierClassificationLogic.luau (pure D.4 state machine,
--     canonical key encoding -- TR-ed-011, post-hitch settle loop -- TR-ed-054, and the full
--     per-pass RunClassificationPass orchestration + C.3.3 server-side coalescing -- TR-ed-037)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only, for the
--     same reason Stories 002-008/014's own test files give -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live DisturbanceService instance is not
--     currently possible in an automated test)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate).
--
-- H.28c NOTE (per this story's own instructions): tested via FULL REAL composition (GetHottestHotspot
-- + SpatialGridLogic + DecayFalloffLogic, exactly mirroring hottest-hotspot-query_test.luau's own
-- "world" harness), NOT the DecayFalloffLogic-only fallback the story text permits -- composition
-- is directly possible here (this project's existing test infrastructure already fully supports
-- it), so it is used for stronger end-to-end evidence rather than falling back early.
--
-- DESIGN CALLS THIS FILE VERIFIES (confirmed by the coordinating agent before implementation):
--   1. Downward-hysteresis thresholds (0.27/0.62/0.97) are COMPUTED from tenseThreshold/
--      huntThreshold/hysteresisBand parameters inside TierAt, not hardcoded literals -- verified
--      bit-identical to the story's own literal pseudocode under this project's pinned Lune/Luau
--      runtime (no precision drift). This file's own literal test values (0.271, 0.269, etc.)
--      independently confirm the production code's computed thresholds land exactly where the
--      story's AC text says they should.
--   2. No RETREAT_THRESHOLD constant -- 1.0 is used directly, matching Story 008's
--      TierLowerBound precedent.
--   3. Position enumeration for RunClassificationPass is the canonical-key-deduplicated set of
--      CURRENTLY-LIVE source positions -- this file tests DedupPositionsByCanonicalKey directly
--      as the mechanism DisturbanceService.luau's real _runTierClassificationPass composes.
--   4. initialMagnitude under coalescing = the winning contributor's own fixed initialMagnitude
--      field, resolved via resolveContributorFn called ONLY on coalescing winners.

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local TierClassificationLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceTierClassificationLogic)
local DecayFalloffLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceDecayFalloffLogic)
local SpatialGridLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceSpatialGridLogic)
local HotspotQueryLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceHotspotQueryLogic)

type Tier = TierClassificationLogic.Tier
type DecayableSource = DecayFalloffLogic.DecayableSource
type DecayCache = DecayFalloffLogic.DecayCache
type SpatialGrid = SpatialGridLogic.SpatialGrid

-- Literals intentionally match DisturbanceConstants.luau's published values without require()-ing
-- that module -- matches Stories 002-008/014's own established harness-driven precedent
-- (DisturbanceConstants.luau is not require()-friendly across this loadstring-based harness for
-- cross-module literal sharing).
local TENSE_THRESHOLD = 0.30
local HUNT_THRESHOLD = 0.65
local HYSTERESIS_BAND = 0.03
local MAX_TIER_CASCADE_ITERATIONS = 4
local MAGNITUDE_FLOOR = 0.02
local STANDARD_HALF_LIFE = 30
local INFLUENCE_RADIUS = 24
local SPATIAL_GRID_CELL_SIZE = 32
local HOTSPOT_DEDUP_GRID_SIZE = 4

local function almostEqual(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

-- ============================================================================
-- "World" fixture -- grid + liveSources + decayCache, mirroring hottest-hotspot-query_test.luau's
-- own precedent exactly, for the H.28c and H.35 tests that need real end-to-end composition.
-- ============================================================================

local function makeSource(emissionId: string, initialMagnitude: number, emissionTime: number, position: Vector3): DecayableSource
	return {
		emissionId = emissionId,
		sourcePlayerId = 1,
		emissionType = "Gather" :: any,
		position = position,
		initialMagnitude = initialMagnitude,
		emissionTime = emissionTime,
	}
end

local function makeWorld(): (SpatialGrid, { [string]: DecayableSource }, DecayCache)
	return {}, {}, {}
end

local function insertSource(
	grid: SpatialGrid,
	liveSources: { [string]: DecayableSource },
	decayCache: DecayCache,
	emissionId: string,
	position: Vector3,
	magnitude: number,
	emissionTime: number?,
	sourcePlayerId: number?
): ()
	local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, SPATIAL_GRID_CELL_SIZE)
	SpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, emissionId)
	local source = makeSource(emissionId, magnitude, emissionTime or 0, position)
	source.sourcePlayerId = sourcePlayerId or 1
	liveSources[emissionId] = source
	decayCache[emissionId] = { magnitude = magnitude, expired = false }
end

local function fieldValueViaWorld(grid: SpatialGrid, liveSources: { [string]: DecayableSource }, decayCache: DecayCache, position: Vector3): number
	local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, SPATIAL_GRID_CELL_SIZE)
	local candidateIds = SpatialGridLogic.QueryNeighborhood(grid, cellX, cellZ)
	return DecayFalloffLogic.FieldValueAt(position, candidateIds, liveSources, decayCache, INFLUENCE_RADIUS)
end

local function topContributorsViaWorld(
	grid: SpatialGrid,
	liveSources: { [string]: DecayableSource },
	decayCache: DecayCache,
	position: Vector3,
	n: number,
	now: number
): ({ string }, number)
	local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, SPATIAL_GRID_CELL_SIZE)
	local candidateIds = SpatialGridLogic.QueryNeighborhood(grid, cellX, cellZ)
	return HotspotQueryLogic.TopContributorsAt(
		position,
		n,
		candidateIds,
		liveSources,
		decayCache,
		INFLUENCE_RADIUS,
		now,
		DecayFalloffLogic.dist2D,
		DecayFalloffLogic.Contribution
	)
end

local function getHottestHotspotViaWorld(
	grid: SpatialGrid,
	liveSources: { [string]: DecayableSource },
	decayCache: DecayCache,
	callerPosition: Vector3,
	searchRadius: number,
	minimumTier: string,
	now: number?
): HotspotQueryLogic.HotspotResult?
	local candidateIds = SpatialGridLogic.QueryCellsInRadius(grid, callerPosition, searchRadius, SPATIAL_GRID_CELL_SIZE)
	local rawPositions: { Vector3 } = {}
	for _, id in candidateIds do
		local source = liveSources[id]
		if source then
			table.insert(rawPositions, source.position)
		end
	end

	return HotspotQueryLogic.GetHottestHotspot(
		callerPosition,
		searchRadius,
		minimumTier,
		rawPositions,
		TENSE_THRESHOLD,
		HUNT_THRESHOLD,
		HOTSPOT_DEDUP_GRID_SIZE,
		DecayFalloffLogic.dist2DSquared,
		function(position: Vector3): number
			return fieldValueViaWorld(grid, liveSources, decayCache, position)
		end,
		function(position: Vector3): ({ string }, number)
			return topContributorsViaWorld(grid, liveSources, decayCache, position, 3, now or 0)
		end
	)
end

return function()
	-- ============================================================================
	-- Canonical key encoding (REQUIRED, TR-ed-011)
	-- ============================================================================
	describe("DisturbanceServiceTierClassificationLogic -- Story 006 (Canonical key encoding, TR-ed-011)", function()
		local function test_canonical_key_basic_floor_no_division()
			-- CanonicalKeyFor floors raw X/Z directly -- NO division by any cell size (unlike
			-- HotspotQueryLogic.DedupCellKey, which divides by HOTSPOT_DEDUP_GRID_SIZE).
			local key = TierClassificationLogic.CanonicalKeyFor(Vector3.new(10.5, 0, 10.9))
			expect(key).to.equal("10_10")
		end
		it("test_canonical_key_basic_floor_no_division", function()
			test_canonical_key_basic_floor_no_division()
		end)

		local function test_canonical_key_negative_coordinates()
			local key = TierClassificationLogic.CanonicalKeyFor(Vector3.new(-0.5, 0, 3.2))
			expect(key).to.equal("-1_3") -- math.floor(-0.5) == -1, not -0 or malformed
		end
		it("test_canonical_key_negative_coordinates", function()
			test_canonical_key_negative_coordinates()
		end)

		local function test_canonical_key_two_separately_constructed_vector3_same_key()
			-- The exact Vector3-reference-equality bug this encoding exists to avoid: two
			-- SEPARATELY-CONSTRUCTED Vector3 instances (different userdata references) with
			-- identical X/Z must resolve to the SAME canonical key string.
			local a = Vector3.new(42, 5, 17)
			local b = Vector3.new(42, 99, 17) -- different Y -- irrelevant, only X/Z matter
			expect(TierClassificationLogic.CanonicalKeyFor(a)).to.equal(TierClassificationLogic.CanonicalKeyFor(b))
			expect(TierClassificationLogic.CanonicalKeyFor(a)).to.equal("42_17")
		end
		it(
			"test_canonical_key_two_separately_constructed_vector3_same_key",
			function()
				test_canonical_key_two_separately_constructed_vector3_same_key()
			end
		)

		local function test_canonical_key_never_uses_tostring()
			-- Never tostring(P) -- Vector3's tostring format ("X, Y, Z") would never match this
			-- module's "%d_%d" format, so this is really just a format-shape sanity check.
			local key = TierClassificationLogic.CanonicalKeyFor(Vector3.new(5, 0, 5))
			expect(key:match("^%-?%d+_%-?%d+$")).never.to.equal(nil)
			expect(key:find(",")).to.equal(nil)
		end
		it("test_canonical_key_never_uses_tostring", function()
			test_canonical_key_never_uses_tostring()
		end)
	end)

	-- ============================================================================
	-- D.4 -- TierAt state machine (H.17-H.21, first-call flat dispatch, TR-ed-070)
	-- ============================================================================
	describe("DisturbanceServiceTierClassificationLogic -- Story 006 (TierAt state machine, D.4/TR-ed-070)", function()
		-- H.17: rises from below 0.30 to exactly 0.30, previousTier="Calm" -> "Tense" (no upward
		-- hysteresis). Edge case: 0.2999 stays "Calm".
		local function test_h17_calm_to_tense_at_exact_boundary_no_upward_hysteresis()
			local result = TierClassificationLogic.TierAt(0.30, "Calm", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(result).to.equal("Tense")

			local justBelow = TierClassificationLogic.TierAt(0.2999, "Calm", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(justBelow).to.equal("Calm")
		end
		it(
			"test_h17_calm_to_tense_at_exact_boundary_no_upward_hysteresis",
			function()
				test_h17_calm_to_tense_at_exact_boundary_no_upward_hysteresis()
			end
		)

		-- H.17b: t=0.85, previousTier="Calm" -> "Hunt" directly (flat-threshold dispatch, single-
		-- step ladder bypassed).
		local function test_h17b_first_call_flat_dispatch_to_hunt()
			local result = TierClassificationLogic.TierAt(0.85, "Calm", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(result).to.equal("Hunt")
		end
		it("test_h17b_first_call_flat_dispatch_to_hunt", function()
			test_h17b_first_call_flat_dispatch_to_hunt()
		end)

		-- H.17c: t=1.00, previousTier="Calm" -> "Retreat".
		local function test_h17c_first_call_flat_dispatch_to_retreat()
			local result = TierClassificationLogic.TierAt(1.00, "Calm", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(result).to.equal("Retreat")
		end
		it("test_h17c_first_call_flat_dispatch_to_retreat", function()
			test_h17c_first_call_flat_dispatch_to_retreat()
		end)

		-- H.18: previousTier="Tense", t = 0.30-0.03+0.001 = 0.271 -> remains "Tense".
		local function test_h18_tense_remains_within_hysteresis_band()
			local result = TierClassificationLogic.TierAt(0.271, "Tense", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(result).to.equal("Tense")
		end
		it("test_h18_tense_remains_within_hysteresis_band", function()
			test_h18_tense_remains_within_hysteresis_band()
		end)

		-- H.19: previousTier="Tense", t strictly below 0.27 -> "Calm". Edge case: exactly 0.27
		-- does NOT transition (D.4's "<" operator, not "<=").
		local function test_h19_tense_to_calm_strictly_below_hysteresis_floor()
			local result = TierClassificationLogic.TierAt(0.269, "Tense", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(result).to.equal("Calm")

			local atExactBoundary = TierClassificationLogic.TierAt(0.27, "Tense", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(atExactBoundary).to.equal("Tense") -- exactly 0.27 does NOT cross (strict <)
		end
		it(
			"test_h19_tense_to_calm_strictly_below_hysteresis_floor",
			function()
				test_h19_tense_to_calm_strictly_below_hysteresis_floor()
			end
		)

		-- H.20: previousTier="Hunt", t = 0.65-0.03-0.001 = 0.619 -> "Tense" (independent of
		-- Tense->Calm hysteresis).
		local function test_h20_hunt_to_tense_hysteresis_independent()
			local result = TierClassificationLogic.TierAt(0.619, "Hunt", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(result).to.equal("Tense")
		end
		it("test_h20_hunt_to_tense_hysteresis_independent", function()
			test_h20_hunt_to_tense_hysteresis_independent()
		end)

		-- H.21: previousTier="Retreat", t = 1.0-0.03-0.001 = 0.969 -> "Hunt".
		local function test_h21_retreat_to_hunt_hysteresis()
			local result = TierClassificationLogic.TierAt(0.969, "Retreat", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			expect(result).to.equal("Hunt")
		end
		it("test_h21_retreat_to_hunt_hysteresis", function()
			test_h21_retreat_to_hunt_hysteresis()
		end)

		-- Stability checks: staying within-band on every non-Calm branch when nothing changed.
		local function test_stays_in_current_tier_when_within_band()
			expect(TierClassificationLogic.TierAt(0.50, "Tense", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)).to.equal("Tense")
			expect(TierClassificationLogic.TierAt(0.80, "Hunt", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)).to.equal("Hunt")
			expect(TierClassificationLogic.TierAt(1.00, "Retreat", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)).to.equal("Retreat")
		end
		it("test_stays_in_current_tier_when_within_band", function()
			test_stays_in_current_tier_when_within_band()
		end)

		-- Invalid previousTier is a defensive programming error (never nil, never returns nil).
		local function test_invalid_previous_tier_errors()
			local ok = pcall(function()
				TierClassificationLogic.TierAt(0.50, "NotATier" :: any, TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND)
			end)
			expect(ok).to.equal(false)
		end
		it("test_invalid_previous_tier_errors", function()
			test_invalid_previous_tier_errors()
		end)
	end)

	-- ============================================================================
	-- DedupPositionsByCanonicalKey
	-- ============================================================================
	describe("DisturbanceServiceTierClassificationLogic -- Story 006 (DedupPositionsByCanonicalKey)", function()
		local function test_dedup_collapses_same_cell_first_encountered_wins()
			local positions = {
				Vector3.new(10, 0, 10), -- key "10_10"
				Vector3.new(10.9, 0, 10.9), -- same key "10_10" -- dropped
				Vector3.new(50, 0, 50), -- key "50_50"
			}
			local deduped = TierClassificationLogic.DedupPositionsByCanonicalKey(positions)
			expect(#deduped).to.equal(2)
			expect(deduped[1].key).to.equal("10_10")
			expect(deduped[1].position).to.equal(Vector3.new(10, 0, 10)) -- first-encountered
			expect(deduped[2].key).to.equal("50_50")
		end
		it(
			"test_dedup_collapses_same_cell_first_encountered_wins",
			function()
				test_dedup_collapses_same_cell_first_encountered_wins()
			end
		)

		local function test_dedup_preserves_distinct_negative_and_positive_cells()
			local positions = { Vector3.new(-5, 0, -5), Vector3.new(5, 0, 5) }
			local deduped = TierClassificationLogic.DedupPositionsByCanonicalKey(positions)
			expect(#deduped).to.equal(2)
			expect(deduped[1].key).to.equal("-5_-5")
			expect(deduped[2].key).to.equal("5_5")
		end
		it(
			"test_dedup_preserves_distinct_negative_and_positive_cells",
			function()
				test_dedup_preserves_distinct_negative_and_positive_cells()
			end
		)

		local function test_dedup_empty_input_returns_empty()
			local deduped = TierClassificationLogic.DedupPositionsByCanonicalKey({})
			expect(#deduped).to.equal(0)
		end
		it("test_dedup_empty_input_returns_empty", function()
			test_dedup_empty_input_returns_empty()
		end)
	end)

	-- ============================================================================
	-- Post-hitch multi-tier cascade settle loop (REQUIRED, TR-ed-054)
	-- ============================================================================
	describe("DisturbanceServiceTierClassificationLogic -- Story 006 (ClassifyWithCascade post-hitch settle loop, TR-ed-054)", function()
		-- H.34b: previousTier="Retreat", hitch drops t from 1.00 to 0.20 in one step -> final tier
		-- "Calm" (NOT "Hunt"), exactly three crossedTiers in ladder order (Hunt, Tense, Calm),
		-- terminates within maxIterations=4 (no error raised).
		local function test_h34b_full_retreat_to_calm_cascade_exactly_three_crossings()
			local finalTier, crossedTiers = TierClassificationLogic.ClassifyWithCascade(
				0.20,
				"Retreat",
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HYSTERESIS_BAND,
				MAX_TIER_CASCADE_ITERATIONS
			)
			expect(finalTier).to.equal("Calm")
			expect(#crossedTiers).to.equal(3)
			expect(crossedTiers[1]).to.equal("Hunt")
			expect(crossedTiers[2]).to.equal("Tense")
			expect(crossedTiers[3]).to.equal("Calm")
		end
		it(
			"test_h34b_full_retreat_to_calm_cascade_exactly_three_crossings",
			function()
				test_h34b_full_retreat_to_calm_cascade_exactly_three_crossings()
			end
		)

		-- Edge case (QA Test Cases' own instruction): a hitch that crosses only TWO boundaries
		-- (Retreat -> Tense band, landing at t=0.50) still produces exactly 2 discrete crossings
		-- (Retreat->Hunt, Hunt->Tense) -- never a single skip-level "Retreat->Tense" event.
		local function test_two_boundary_hitch_produces_two_discrete_crossings_not_a_skip_level_event()
			local finalTier, crossedTiers = TierClassificationLogic.ClassifyWithCascade(
				0.50,
				"Retreat",
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HYSTERESIS_BAND,
				MAX_TIER_CASCADE_ITERATIONS
			)
			expect(finalTier).to.equal("Tense")
			expect(#crossedTiers).to.equal(2)
			expect(crossedTiers[1]).to.equal("Hunt")
			expect(crossedTiers[2]).to.equal("Tense")
		end
		it(
			"test_two_boundary_hitch_produces_two_discrete_crossings_not_a_skip_level_event",
			function()
				test_two_boundary_hitch_produces_two_discrete_crossings_not_a_skip_level_event()
			end
		)

		-- Single-step (no cascade needed) case: an ordinary upward crossing resolves in one
		-- iteration with exactly one crossedTier.
		local function test_single_boundary_crossing_resolves_in_one_iteration()
			local finalTier, crossedTiers =
				TierClassificationLogic.ClassifyWithCascade(0.31, "Calm", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND, MAX_TIER_CASCADE_ITERATIONS)
			expect(finalTier).to.equal("Tense")
			expect(#crossedTiers).to.equal(1)
			expect(crossedTiers[1]).to.equal("Tense")
		end
		it(
			"test_single_boundary_crossing_resolves_in_one_iteration",
			function()
				test_single_boundary_crossing_resolves_in_one_iteration()
			end
		)

		-- No crossing at all: previousTier already matches -> empty crossedTiers list.
		local function test_no_crossing_when_tier_unchanged()
			local finalTier, crossedTiers =
				TierClassificationLogic.ClassifyWithCascade(0.50, "Tense", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND, MAX_TIER_CASCADE_ITERATIONS)
			expect(finalTier).to.equal("Tense")
			expect(#crossedTiers).to.equal(0)
		end
		it("test_no_crossing_when_tier_unchanged", function()
			test_no_crossing_when_tier_unchanged()
		end)

		-- H.34: fieldValue oscillates 0.31/0.29/0.31/0.29 across four ticks -- TierCrossedEvent
		-- (here: total crossedTiers across all four ticks) fires AT MOST TWICE.
		local function test_h34_oscillation_across_four_ticks_fires_at_most_twice()
			local values = { 0.31, 0.29, 0.31, 0.29 }
			local currentTier: Tier = "Calm" -- first-call default
			local totalCrossings = 0

			for _, t in values do
				local finalTier, crossedTiers =
					TierClassificationLogic.ClassifyWithCascade(t, currentTier, TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND, MAX_TIER_CASCADE_ITERATIONS)
				totalCrossings += #crossedTiers
				currentTier = finalTier
			end

			expect(totalCrossings <= 2).to.equal(true)
		end
		it(
			"test_h34_oscillation_across_four_ticks_fires_at_most_twice",
			function()
				test_h34_oscillation_across_four_ticks_fires_at_most_twice()
			end
		)

		-- GDD's own D.4 worked example table (0.28 -> 0.31 -> 0.29 -> 0.26): exactly 2 firings
		-- (ticks 2 and 4), ticks 1 and 3 fire nothing.
		local function test_gdd_worked_example_exactly_two_firings_at_ticks_two_and_four()
			local values = { 0.28, 0.31, 0.29, 0.26 }
			local expectedCrossingCounts = { 0, 1, 0, 1 }
			local currentTier: Tier = "Calm"

			for i, t in values do
				local finalTier, crossedTiers =
					TierClassificationLogic.ClassifyWithCascade(t, currentTier, TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND, MAX_TIER_CASCADE_ITERATIONS)
				expect(#crossedTiers).to.equal(expectedCrossingCounts[i])
				currentTier = finalTier
			end

			expect(currentTier).to.equal("Calm")
		end
		it(
			"test_gdd_worked_example_exactly_two_firings_at_ticks_two_and_four",
			function()
				test_gdd_worked_example_exactly_two_firings_at_ticks_two_and_four()
			end
		)

		-- Defensive maxIterations guard (TR-ed-054): an artificially tiny maxIterations forces the
		-- guard to fire deterministically, proving the defensive code path is reachable and correct.
		local function test_max_iterations_defensive_guard_fires_when_exceeded()
			local ok, err = pcall(function()
				TierClassificationLogic.ClassifyWithCascade(0.20, "Retreat", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND, 1)
			end)
			expect(ok).to.equal(false)
			expect(tostring(err):find("maxIterations")).never.to.equal(nil)
		end
		it(
			"test_max_iterations_defensive_guard_fires_when_exceeded",
			function()
				test_max_iterations_defensive_guard_fires_when_exceeded()
			end
		)

		-- The legitimate worst case (maxIterations=4, a full Retreat->Calm cascade) NEVER triggers
		-- the guard -- confirms the guard's bound is exactly right, not overly tight.
		local function test_max_iterations_four_never_triggers_guard_on_legitimate_worst_case()
			local ok = pcall(function()
				TierClassificationLogic.ClassifyWithCascade(0.20, "Retreat", TENSE_THRESHOLD, HUNT_THRESHOLD, HYSTERESIS_BAND, MAX_TIER_CASCADE_ITERATIONS)
			end)
			expect(ok).to.equal(true)
		end
		it(
			"test_max_iterations_four_never_triggers_guard_on_legitimate_worst_case",
			function()
				test_max_iterations_four_never_triggers_guard_on_legitimate_worst_case()
			end
		)
	end)

	-- ============================================================================
	-- RunClassificationPass + C.3.3 server-side per-pass coalescing (REQUIRED)
	-- ============================================================================
	describe("DisturbanceServiceTierClassificationLogic -- Story 006 (RunClassificationPass + C.3.3 coalescing)", function()
		-- H.28: a single position rises above TENSE_THRESHOLD -- TierCrossedEvent-equivalent
		-- fires once, carrying {crossedTier, position, emissionId, initialMagnitude}.
		local function test_h28_single_position_crosses_tense_fires_once_with_correct_payload()
			local P = Vector3.new(100, 0, 50)
			local previousTierAtPosition: { [string]: Tier } = {}
			local positionEntries = TierClassificationLogic.DedupPositionsByCanonicalKey({ P })

			local events = TierClassificationLogic.RunClassificationPass(
				positionEntries,
				previousTierAtPosition,
				function(_position: Vector3): number
					return 0.31
				end,
				function(_position: Vector3): (string, number)
					return "emission-A", 0.15
				end,
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HYSTERESIS_BAND,
				MAX_TIER_CASCADE_ITERATIONS
			)

			expect(#events).to.equal(1)
			expect(events[1].crossedTier).to.equal("Tense")
			expect(events[1].position).to.equal(P)
			expect(events[1].emissionId).to.equal("emission-A")
			expect(events[1].initialMagnitude).to.equal(0.15)

			local key = TierClassificationLogic.CanonicalKeyFor(P)
			expect(previousTierAtPosition[key]).to.equal("Tense")
		end
		it(
			"test_h28_single_position_crosses_tense_fires_once_with_correct_payload",
			function()
				test_h28_single_position_crosses_tense_fires_once_with_correct_payload()
			end
		)

		-- H.28b: THREE distinct positions cross TENSE_THRESHOLD in the same pass (fieldValues
		-- 0.31/0.40/0.35) -- exactly ONE event fires for crossedTier="Tense", carrying the 0.40
		-- position (highest). Also verifies each of the three positions' OWN previousTierAtPosition
		-- entry is still updated independently -- coalescing affects EVENT firing only, never the
		-- per-position state mutation.
		local function test_h28b_three_positions_cross_tense_same_pass_coalesces_to_one_event()
			local pLow = Vector3.new(0, 0, 0)
			local pHigh = Vector3.new(100, 0, 0) -- fieldValue 0.40 -- the winner
			local pMid = Vector3.new(200, 0, 0)

			local fieldValues: { [Vector3]: number } = {
				[pLow] = 0.31,
				[pHigh] = 0.40,
				[pMid] = 0.35,
			}

			local previousTierAtPosition: { [string]: Tier } = {}
			local positionEntries = TierClassificationLogic.DedupPositionsByCanonicalKey({ pLow, pHigh, pMid })

			local resolveCallCount = 0
			local events = TierClassificationLogic.RunClassificationPass(
				positionEntries,
				previousTierAtPosition,
				function(position: Vector3): number
					return fieldValues[position]
				end,
				function(position: Vector3): (string, number)
					resolveCallCount += 1
					if position == pHigh then
						return "emission-high", 0.40
					elseif position == pLow then
						return "emission-low", 0.31
					end
					return "emission-mid", 0.35
				end,
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HYSTERESIS_BAND,
				MAX_TIER_CASCADE_ITERATIONS
			)

			expect(#events).to.equal(1) -- coalesced -- not three
			expect(events[1].crossedTier).to.equal("Tense")
			expect(events[1].position).to.equal(pHigh) -- highest fieldValue wins
			expect(events[1].emissionId).to.equal("emission-high")
			expect(resolveCallCount).to.equal(1) -- resolveContributorFn called ONLY on the winner

			-- All three positions' OWN state entries are still independently updated to "Tense".
			expect(previousTierAtPosition[TierClassificationLogic.CanonicalKeyFor(pLow)]).to.equal("Tense")
			expect(previousTierAtPosition[TierClassificationLogic.CanonicalKeyFor(pHigh)]).to.equal("Tense")
			expect(previousTierAtPosition[TierClassificationLogic.CanonicalKeyFor(pMid)]).to.equal("Tense")
		end
		it(
			"test_h28b_three_positions_cross_tense_same_pass_coalesces_to_one_event",
			function()
				test_h28b_three_positions_cross_tense_same_pass_coalesces_to_one_event()
			end
		)

		-- Multi-boundary coalescing: a pass with positions crossing DIFFERENT boundaries in the
		-- same pass fires one event PER distinct crossedTier value (not globally coalesced to one).
		local function test_different_boundaries_each_get_their_own_coalesced_event()
			local pTense = Vector3.new(0, 0, 0)
			local pHunt = Vector3.new(500, 0, 0)
			local fieldValues: { [Vector3]: number } = {
				[pTense] = 0.31,
				[pHunt] = 0.70,
			}
			local previousTierAtPosition: { [string]: Tier } = {}
			local positionEntries = TierClassificationLogic.DedupPositionsByCanonicalKey({ pTense, pHunt })

			local events = TierClassificationLogic.RunClassificationPass(
				positionEntries,
				previousTierAtPosition,
				function(position: Vector3): number
					return fieldValues[position]
				end,
				function(_position: Vector3): (string, number)
					return "some-emission", 0.5
				end,
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HYSTERESIS_BAND,
				MAX_TIER_CASCADE_ITERATIONS
			)

			expect(#events).to.equal(2)
			local crossedTiersSeen: { [string]: boolean } = {}
			for _, event in events do
				crossedTiersSeen[event.crossedTier] = true
			end
			expect(crossedTiersSeen["Tense"]).to.equal(true)
			expect(crossedTiersSeen["Hunt"]).to.equal(true)
		end
		it(
			"test_different_boundaries_each_get_their_own_coalesced_event",
			function()
				test_different_boundaries_each_get_their_own_coalesced_event()
			end
		)

		-- Zero positions -> zero events, no error.
		local function test_zero_positions_produces_zero_events_no_error()
			local previousTierAtPosition: { [string]: Tier } = {}
			local ok, events = pcall(function()
				return TierClassificationLogic.RunClassificationPass(
					{},
					previousTierAtPosition,
					function(_position: Vector3): number
						return 0.5
					end,
					function(_position: Vector3): (string, number)
						return "unused", 0
					end,
					TENSE_THRESHOLD,
					HUNT_THRESHOLD,
					HYSTERESIS_BAND,
					MAX_TIER_CASCADE_ITERATIONS
				)
			end)
			expect(ok).to.equal(true)
			expect(#(events :: any)).to.equal(0)
		end
		it(
			"test_zero_positions_produces_zero_events_no_error",
			function()
				test_zero_positions_produces_zero_events_no_error()
			end
		)

		-- H.35 -- REAL composition: two emissions from different players at the SAME position
		-- jointly push fieldValue from below TENSE_THRESHOLD to above it. RunClassificationPass
		-- fires exactly once for "Tense", AND (separately, via real TopContributorsAt composition)
		-- BOTH emissionIds remain eligible for a subsequent death attribution's top-3 list --
		-- proving the single-emissionId TierCrossedEvent payload does not suppress the OTHER
		-- contributor's downstream attribution eligibility.
		local function test_h35_two_same_tick_emissions_cross_tense_once_both_remain_attribution_eligible()
			local grid, liveSources, decayCache = makeWorld()
			local P = Vector3.new(0, 0, 0)
			-- Two independent sources, different players, combined contribution >= TENSE_THRESHOLD.
			insertSource(grid, liveSources, decayCache, "player-A-emission", P, 0.20, 0, 1)
			insertSource(grid, liveSources, decayCache, "player-B-emission", P, 0.20, 0, 2)

			local combinedFieldValue = fieldValueViaWorld(grid, liveSources, decayCache, P)
			expect(combinedFieldValue >= TENSE_THRESHOLD).to.equal(true) -- precondition: this tick crosses Tense

			local previousTierAtPosition: { [string]: Tier } = {} -- first-call (below threshold prior tick)
			local positionEntries = TierClassificationLogic.DedupPositionsByCanonicalKey({ P })

			local events = TierClassificationLogic.RunClassificationPass(
				positionEntries,
				previousTierAtPosition,
				function(position: Vector3): number
					return fieldValueViaWorld(grid, liveSources, decayCache, position)
				end,
				function(position: Vector3): (string, number)
					local topIds = topContributorsViaWorld(grid, liveSources, decayCache, position, 1, 0)
					local topId = topIds[1]
					local source = liveSources[topId]
					return topId, if source then source.initialMagnitude else 0
				end,
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HYSTERESIS_BAND,
				MAX_TIER_CASCADE_ITERATIONS
			)

			expect(#events).to.equal(1) -- fires exactly once, not twice (one per contributing source)
			expect(events[1].crossedTier).to.equal("Tense")

			-- Both emissionIds remain resolvable/eligible via the real topContributorsAt path (the
			-- attribution mechanism a subsequent death attribution's top-3 list draws from).
			local topContributors = topContributorsViaWorld(grid, liveSources, decayCache, P, 3, 0)
			local seenA, seenB = false, false
			for _, id in topContributors do
				if id == "player-A-emission" then
					seenA = true
				elseif id == "player-B-emission" then
					seenB = true
				end
			end
			expect(seenA).to.equal(true)
			expect(seenB).to.equal(true)
		end
		it(
			"test_h35_two_same_tick_emissions_cross_tense_once_both_remain_attribution_eligible",
			function()
				test_h35_two_same_tick_emissions_cross_tense_once_both_remain_attribution_eligible()
			end
		)
	end)

	-- ============================================================================
	-- H.28c -- real GetHottestHotspot composition, post-decay-driven expiry
	-- ============================================================================
	describe("DisturbanceServiceTierClassificationLogic/DecayFalloffLogic/HotspotQueryLogic -- Story 006 (H.28c decay-driven expiry)", function()
		-- GIVEN a TierCrossedEvent-equivalent fires at P (fieldValue exactly 0.31) AND the clock
		-- advances past ln(0.31/MAGNITUDE_FLOOR)/(ln(2)/STANDARD_HALF_LIFE) ~= 118.6s, WHEN
		-- GetHottestHotspot(callerPosition, 200, "Tense") is called, THEN it returns nil.
		local function test_h28c_source_decays_below_tense_floor_get_hottest_hotspot_returns_nil()
			local grid, liveSources, decayCache = makeWorld()
			local P = Vector3.new(50, 0, 50)
			insertSource(grid, liveSources, decayCache, "decaying-emission", P, 0.31, 0)

			-- At emission time: still detectable at/above the Tense floor.
			DecayFalloffLogic.RunDecayPass(liveSources, decayCache, 0, STANDARD_HALF_LIFE, 90, MAGNITUDE_FLOOR)
			local beforeResult = getHottestHotspotViaWorld(grid, liveSources, decayCache, P, 200, "Tense", 0)
			expect(beforeResult).never.to.equal(nil)

			-- Advance the clock well past the ~118.6s expiry threshold (comfortable margin against
			-- any floating-point boundary flakiness) and re-run the decay pass, exactly as the real
			-- field-update loop would on the next pass.
			DecayFalloffLogic.RunDecayPass(liveSources, decayCache, 120, STANDARD_HALF_LIFE, 90, MAGNITUDE_FLOOR)
			local afterResult = getHottestHotspotViaWorld(grid, liveSources, decayCache, P, 200, "Tense", 120)
			expect(afterResult).to.equal(nil)
		end
		it(
			"test_h28c_source_decays_below_tense_floor_get_hottest_hotspot_returns_nil",
			function()
				test_h28c_source_decays_below_tense_floor_get_hottest_hotspot_returns_nil()
			end
		)
	end)

	-- ============================================================================
	-- DisturbanceService.luau -- Story 006 wiring (static/structural checks)
	-- ============================================================================
	describe("DisturbanceService.luau -- Story 006 (wiring, static checks)", function()
		local disturbanceServiceSource: string? = nil

		-- Strips Lua/Luau single-line comments -- see this project's own documented `--`-in-string
		-- caveat (Stories 002-008/014's own precedent): a `--` inside a string literal truncates
		-- early, so this helper is only safe against code-structure checks, never comment-only text.
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

		local function test_client_table_remains_empty_no_tier_methods_exposed_to_clients()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it(
			"test_client_table_remains_empty_no_tier_methods_exposed_to_clients",
			function()
				test_client_table_remains_empty_no_tier_methods_exposed_to_clients()
			end
		)

		local function test_get_tier_crossed_signal_accessor_exists()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:GetTierCrossedSignal%(")).never.to.equal(nil)
		end
		it("test_get_tier_crossed_signal_accessor_exists", function()
			test_get_tier_crossed_signal_accessor_exists()
		end)

		local function test_tier_crossed_event_constructed_via_signal_new_inside_knit_init()
			local source = loadServiceSource()
			local declStart = source:find("function DisturbanceService:KnitInit%(")
			expect(declStart).never.to.equal(nil)
			local bodyEnd = source:find("\nend", declStart :: number)
			expect(bodyEnd).never.to.equal(nil)
			local bodySlice = source:sub(declStart :: number, bodyEnd :: number)
			expect(bodySlice:find("self%._tierCrossedEvent = Signal%.new%(%)")).never.to.equal(nil)
			expect(bodySlice:find("self%._previousTierAtPosition = {}")).never.to.equal(nil)
		end
		it(
			"test_tier_crossed_event_constructed_via_signal_new_inside_knit_init",
			function()
				test_tier_crossed_event_constructed_via_signal_new_inside_knit_init()
			end
		)

		local function test_tier_classification_pass_wired_into_field_update_pass()
			local source = loadServiceSource()
			local declStart = source:find("function DisturbanceService:_runFieldUpdatePass%(")
			expect(declStart).never.to.equal(nil)
			local bodyEnd = source:find("\nend", declStart :: number)
			expect(bodyEnd).never.to.equal(nil)
			local bodySlice = source:sub(declStart :: number, bodyEnd :: number)
			expect(bodySlice:find("self:_runTierClassificationPass%(%)")).never.to.equal(nil)
		end
		it(
			"test_tier_classification_pass_wired_into_field_update_pass",
			function()
				test_tier_classification_pass_wired_into_field_update_pass()
			end
		)

		local function test_run_tier_classification_pass_method_exists_and_routes_through_pure_logic()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:_runTierClassificationPass%(")).never.to.equal(nil)
			expect(source:find("TierClassificationLogic%.DedupPositionsByCanonicalKey%(")).never.to.equal(nil)
			expect(source:find("TierClassificationLogic%.RunClassificationPass%(")).never.to.equal(nil)
		end
		it(
			"test_run_tier_classification_pass_method_exists_and_routes_through_pure_logic",
			function()
				test_run_tier_classification_pass_method_exists_and_routes_through_pure_logic()
			end
		)

		local function test_no_raw_bindable_event_for_tier_crossed()
			local source = loadServiceSource()
			expect(source:find('self%._tierCrossedEvent = Instance%.new%("BindableEvent"%)')).to.equal(nil)
		end
		it("test_no_raw_bindable_event_for_tier_crossed", function()
			test_no_raw_bindable_event_for_tier_crossed()
		end)

		local function test_disturbance_service_exposes_tier_classification_pure_functions_for_testability()
			local source = loadServiceSource()
			expect(source:find("DisturbanceService%.CanonicalKeyFor = TierClassificationLogic%.CanonicalKeyFor")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.TierAt = TierClassificationLogic%.TierAt")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.ClassifyWithCascade = TierClassificationLogic%.ClassifyWithCascade")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.RunClassificationPass = TierClassificationLogic%.RunClassificationPass")).never.to.equal(nil)
		end
		it(
			"test_disturbance_service_exposes_tier_classification_pure_functions_for_testability",
			function()
				test_disturbance_service_exposes_tier_classification_pure_functions_for_testability()
			end
		)
	end)
end
