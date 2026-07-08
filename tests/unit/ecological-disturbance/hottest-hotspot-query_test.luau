--!strict
-- hottest-hotspot-query_test
--
-- Unit tests for Story 008: GetHottestHotspot Query & topContributorsAt.
-- Story: production/epics/ecological-disturbance/story-008-hottest-hotspot-query.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceHotspotQueryLogic.luau (pure D.6 scoring/dedup/
--     non-finite-disqualification algorithm, topContributorsAt contributor ranking -- H.23
--     through H.25d)
--   src/gameplay/services/DisturbanceServiceSpatialGridLogic.luau (QueryCellsInRadius -- the
--     Story 008-added general cell-range query primitive; static/structural checks only for
--     that addition's composition with the rest of the grid module, exercised directly here)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only, for the
--     same reason Stories 002-007's own test files give -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live DisturbanceService instance is not
--     currently possible in an automated test -- the wiring/test-seam ACs are instead proven via
--     source-text checks against the real file)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate).
--
-- FIXED DISCOVERY (Story 008, found while designing the H.25c falsifiability control; fixed
-- same-session, 2026-07-08): DisturbanceServiceDecayFalloffLogic.FieldValueAt's own D.3 clamp
-- was written `return math.min(1.0, total)`. Empirically verified against this project's pinned
-- Lune runtime: `math.min(1.0, 0/0) == 1` (NOT NaN) and `math.min(1.0, math.huge) == 1` (the
-- intended, correct clamp behavior for a legitimately-huge total). The NaN case was the
-- concerning one: because `1.0` was the FIRST argument, Luau's math.min silently laundered a NaN
-- `total` into a finite `1.0` -- meaning neither NaN nor +Inf could reach GetHottestHotspot's D.6
-- in-loop non-finite-disqualification guard via the REAL composed `fieldValue()` path (the guard
-- itself was always correct, proven below against injected fieldValueFn stubs that bypass this
-- clamp -- it was simply unreachable end-to-end for the NaN case specifically). Fixed by swapping
-- the clamp's argument order to `math.min(total, 1.0)` (`math.min(0/0, 1.0) == NaN`, confirmed
-- empirically) in DisturbanceServiceDecayFalloffLogic.luau -- see that file and
-- decay-falloff-fieldvalue_test.luau's own dedicated regression test. The tests below now assert
-- the CORRECT (fixed, NaN-propagating) behavior.

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local HotspotQueryLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceHotspotQueryLogic)
local SpatialGridLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceSpatialGridLogic)
local DecayFalloffLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceDecayFalloffLogic)

type DecayableSource = DecayFalloffLogic.DecayableSource
type DecayCache = DecayFalloffLogic.DecayCache
type SpatialGrid = SpatialGridLogic.SpatialGrid

-- Literals intentionally match DisturbanceConstants.luau's published values without require()-ing
-- that module -- this test file follows the exact same harness-driven precedent Stories
-- 002/003/004/005's own test files document (DisturbanceConstants.luau is not require()-friendly
-- across this loadstring-based harness for cross-module literal sharing).
local TENSE_THRESHOLD = 0.30
local HUNT_THRESHOLD = 0.65
local INFLUENCE_RADIUS = 24
local SPATIAL_GRID_CELL_SIZE = 32
local HOTSPOT_DEDUP_GRID_SIZE = 4

local function almostEqual(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

--- UUID 8-4-4-4-12 hex regex, matching H.1's canonical emissionId format check (H.25b).
local UUID_PATTERN = "^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$"

--- Canonical hotspotId format regex (H.25d clause (b)).
local HOTSPOT_ID_PATTERN = "^%-?%d+_%-?%d+$"

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

--- A small "world" fixture: grid + liveSources + decayCache. Tests construct decayCache entries
--- DIRECTLY (bypassing DecayFalloffLogic.RunDecayPass) since these tests are about D.6's scoring/
--- dedup/query-primitive contract, not D.1's decay math -- matching decay-falloff-fieldvalue
--- _test.luau's own direct-decayCache-construction convention.
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
	emissionTime: number?
): ()
	local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, SPATIAL_GRID_CELL_SIZE)
	SpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, emissionId)
	liveSources[emissionId] = makeSource(emissionId, magnitude, emissionTime or 0, position)
	decayCache[emissionId] = { magnitude = magnitude, expired = false }
end

local function removeSource(grid: SpatialGrid, liveSources: { [string]: DecayableSource }, decayCache: DecayCache, emissionId: string): ()
	local source = liveSources[emissionId]
	if source then
		local cellX, cellZ = SpatialGridLogic.CellCoordFor(source.position, SPATIAL_GRID_CELL_SIZE)
		SpatialGridLogic.RemoveSourceFromGridCell(grid, cellX, cellZ, emissionId)
	end
	liveSources[emissionId] = nil
	decayCache[emissionId] = nil
end

--- Real fieldValue() composition -- exactly mirroring DisturbanceService.luau's own real
--- fieldValue() method (CellCoordFor -> QueryNeighborhood -> FieldValueAt).
local function fieldValueViaWorld(grid: SpatialGrid, liveSources: { [string]: DecayableSource }, decayCache: DecayCache, position: Vector3): number
	local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, SPATIAL_GRID_CELL_SIZE)
	local candidateIds = SpatialGridLogic.QueryNeighborhood(grid, cellX, cellZ)
	return DecayFalloffLogic.FieldValueAt(position, candidateIds, liveSources, decayCache, INFLUENCE_RADIUS)
end

--- Real topContributorsAt() composition -- mirrors DisturbanceService.luau's real
--- _topContributorsAt() method.
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

--- Real GetHottestHotspot() composition -- mirrors DisturbanceService.luau's real
--- GetHottestHotspot() method exactly (QueryCellsInRadius for outer enumeration,
--- fieldValueViaWorld/topContributorsViaWorld as the injected callbacks).
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
	describe("DisturbanceServiceHotspotQueryLogic -- Story 008 (TierLowerBound)", function()
		local function test_tier_lower_bound_maps_all_four_tiers()
			expect(HotspotQueryLogic.TierLowerBound("Calm", TENSE_THRESHOLD, HUNT_THRESHOLD)).to.equal(0.0)
			expect(HotspotQueryLogic.TierLowerBound("Tense", TENSE_THRESHOLD, HUNT_THRESHOLD)).to.equal(TENSE_THRESHOLD)
			expect(HotspotQueryLogic.TierLowerBound("Hunt", TENSE_THRESHOLD, HUNT_THRESHOLD)).to.equal(HUNT_THRESHOLD)
			expect(HotspotQueryLogic.TierLowerBound("Retreat", TENSE_THRESHOLD, HUNT_THRESHOLD)).to.equal(1.0)
		end
		it("test_tier_lower_bound_maps_all_four_tiers", function()
			test_tier_lower_bound_maps_all_four_tiers()
		end)
	end)

	describe("DisturbanceServiceHotspotQueryLogic -- Story 008 (Dedup snap-method, D.6)", function()
		local function test_dedup_cell_key_uses_string_format_not_tuple()
			local key = HotspotQueryLogic.DedupCellKey(Vector3.new(10, 0, 10), HOTSPOT_DEDUP_GRID_SIZE)
			expect(key).to.equal("2_2") -- floor(10/4) = 2
		end
		it("test_dedup_cell_key_uses_string_format_not_tuple", function()
			test_dedup_cell_key_uses_string_format_not_tuple()
		end)

		-- H.25d clause (b) edge case: negative-coordinate cells format correctly.
		local function test_dedup_cell_key_handles_negative_coordinates()
			local key = HotspotQueryLogic.DedupCellKey(Vector3.new(-5, 0, -5), HOTSPOT_DEDUP_GRID_SIZE)
			expect(key).to.equal("-2_-2") -- floor(-5/4) = -2
			expect(key:match(HOTSPOT_ID_PATTERN)).never.to.equal(nil)
		end
		it("test_dedup_cell_key_handles_negative_coordinates", function()
			test_dedup_cell_key_handles_negative_coordinates()
		end)

		local function test_deduplicate_by_floor_snap_keeps_first_encountered_per_cell()
			local positions = {
				Vector3.new(1, 0, 1), -- cell 0_0
				Vector3.new(2, 0, 2), -- cell 0_0 (same cell -- dropped)
				Vector3.new(100, 0, 0), -- cell 25_0
			}
			local deduped = HotspotQueryLogic.DeduplicateByFloorSnap(positions, HOTSPOT_DEDUP_GRID_SIZE)
			expect(#deduped).to.equal(2)
			expect(deduped[1]).to.equal(Vector3.new(1, 0, 1)) -- first-encountered, NOT "best within cell"
			expect(deduped[2]).to.equal(Vector3.new(100, 0, 0))
		end
		it(
			"test_deduplicate_by_floor_snap_keeps_first_encountered_per_cell",
			function()
				test_deduplicate_by_floor_snap_keeps_first_encountered_per_cell()
			end
		)
	end)

	describe("DisturbanceServiceHotspotQueryLogic -- Story 008 (ScoreCandidates -- H.25c guard, injected fieldValueFn)", function()
		-- H.25c falsifiability control, guard-level, NaN flavor: a NaN-scoring candidate is
		-- disqualified -- never counted, never wins bestPosition.
		local function test_score_candidates_disqualifies_nan_flavor()
			local candidates = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
			local function fieldValueFn(pos: Vector3): number
				if pos == Vector3.new(0, 0, 0) then
					return 0 / 0
				end
				return 0.70
			end
			local bestPosition, bestScore, hotspotCount = HotspotQueryLogic.ScoreCandidates(candidates, TENSE_THRESHOLD, fieldValueFn)
			expect(bestPosition).to.equal(Vector3.new(100, 0, 0))
			expect(almostEqual(bestScore, 0.70, 0.001)).to.equal(true)
			expect(hotspotCount).to.equal(1) -- the NaN candidate never incremented this
		end
		it("test_score_candidates_disqualifies_nan_flavor", function()
			test_score_candidates_disqualifies_nan_flavor()
		end)

		-- H.25c falsifiability control, guard-level, +math.huge flavor (independent run).
		local function test_score_candidates_disqualifies_positive_infinity_flavor()
			local candidates = { Vector3.new(0, 0, 0), Vector3.new(100, 0, 0) }
			local function fieldValueFn(pos: Vector3): number
				if pos == Vector3.new(0, 0, 0) then
					return math.huge
				end
				return 0.70
			end
			local bestPosition, bestScore, hotspotCount = HotspotQueryLogic.ScoreCandidates(candidates, TENSE_THRESHOLD, fieldValueFn)
			expect(bestPosition).to.equal(Vector3.new(100, 0, 0))
			expect(almostEqual(bestScore, 0.70, 0.001)).to.equal(true)
			expect(hotspotCount).to.equal(1)
		end
		it(
			"test_score_candidates_disqualifies_positive_infinity_flavor",
			function()
				test_score_candidates_disqualifies_positive_infinity_flavor()
			end
		)

		-- Grep sub-AC (H.9c-style, H.25c's own instruction): the non-finite-disqualification
		-- idiom appears inside the D.6 candidate-scoring loop body, before the tierFloor gate.
		local function test_h25c_grep_disqualification_idiom_present_before_tierfloor_gate()
			local source = fs.readFile("src/gameplay/services/DisturbanceServiceHotspotQueryLogic.luau")
			local disqualifyIndex = source:find("score ~= score or score == math%.huge")
			local tierFloorGateIndex = source:find("if score >= tierFloor then")
			expect(disqualifyIndex).never.to.equal(nil)
			expect(tierFloorGateIndex).never.to.equal(nil)
			expect((disqualifyIndex :: number) < (tierFloorGateIndex :: number)).to.equal(true)
		end
		it(
			"test_h25c_grep_disqualification_idiom_present_before_tierfloor_gate",
			function()
				test_h25c_grep_disqualification_idiom_present_before_tierfloor_gate()
			end
		)
	end)

	describe("DisturbanceServiceHotspotQueryLogic -- Story 008 (GetHottestHotspot orchestration -- H.25c, injected callbacks)", function()
		local function makeInjectedFixture(corruptScore: number)
			local rawPositions = { Vector3.new(0, 0, 0), Vector3.new(200, 0, 0) }
			local function fieldValueFn(pos: Vector3): number
				if pos == Vector3.new(0, 0, 0) then
					return corruptScore
				end
				return 0.70
			end
			local function topContributorsFn(pos: Vector3): ({ string }, number)
				return { "legit-emission-0000-0000-000000000000" }, 12
			end
			return rawPositions, fieldValueFn, topContributorsFn
		end

		-- (a)/(b)/(c) NaN flavor.
		local function test_get_hottest_hotspot_disqualifies_nan_and_returns_legit_candidate()
			local rawPositions, fieldValueFn, topContributorsFn = makeInjectedFixture(0 / 0)

			local result = HotspotQueryLogic.GetHottestHotspot(
				Vector3.new(100, 0, 0),
				300,
				"Tense",
				rawPositions,
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HOTSPOT_DEDUP_GRID_SIZE,
				DecayFalloffLogic.dist2DSquared,
				fieldValueFn,
				topContributorsFn
			)
			expect(result).never.to.equal(nil)
			local hotspot = result :: HotspotQueryLogic.HotspotResult
			expect(almostEqual(hotspot.fieldValue, 0.70, 0.001)).to.equal(true)
			expect(hotspot.position).to.equal(Vector3.new(200, 0, 0))
			expect(hotspot.hotspotCount).to.equal(1) -- (a) NaN candidate never counted
			-- Non-finite output prohibition.
			expect(hotspot.fieldValue == hotspot.fieldValue).to.equal(true)
			expect(hotspot.fieldValue ~= math.huge).to.equal(true)
			expect(hotspot.fieldValue >= TENSE_THRESHOLD).to.equal(true)

			-- (c): with the legitimate candidate removed, returns nil -- NOT a fabricated 0.0.
			local rawPositionsNoLegit = { Vector3.new(0, 0, 0) }
			local resultAfterRemoval = HotspotQueryLogic.GetHottestHotspot(
				Vector3.new(100, 0, 0),
				300,
				"Tense",
				rawPositionsNoLegit,
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HOTSPOT_DEDUP_GRID_SIZE,
				DecayFalloffLogic.dist2DSquared,
				fieldValueFn,
				topContributorsFn
			)
			expect(resultAfterRemoval).to.equal(nil)
		end
		it(
			"test_get_hottest_hotspot_disqualifies_nan_and_returns_legit_candidate",
			function()
				test_get_hottest_hotspot_disqualifies_nan_and_returns_legit_candidate()
			end
		)

		-- (a)/(b)/(c) +math.huge flavor (independent run -- H.25c's own falsifiability
		-- instruction: a `value ~= value`-only guard would pass a NaN-only test while leaking
		-- +Inf, so both flavors must independently pass).
		local function test_get_hottest_hotspot_disqualifies_positive_infinity_and_returns_legit_candidate()
			local rawPositions, fieldValueFn, topContributorsFn = makeInjectedFixture(math.huge)

			local result = HotspotQueryLogic.GetHottestHotspot(
				Vector3.new(100, 0, 0),
				300,
				"Tense",
				rawPositions,
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HOTSPOT_DEDUP_GRID_SIZE,
				DecayFalloffLogic.dist2DSquared,
				fieldValueFn,
				topContributorsFn
			)
			expect(result).never.to.equal(nil)
			local hotspot = result :: HotspotQueryLogic.HotspotResult
			expect(almostEqual(hotspot.fieldValue, 0.70, 0.001)).to.equal(true)
			expect(hotspot.position).to.equal(Vector3.new(200, 0, 0))
			expect(hotspot.hotspotCount).to.equal(1)
			expect(hotspot.fieldValue == hotspot.fieldValue).to.equal(true)
			expect(hotspot.fieldValue ~= math.huge).to.equal(true)

			local rawPositionsNoLegit = { Vector3.new(0, 0, 0) }
			local resultAfterRemoval = HotspotQueryLogic.GetHottestHotspot(
				Vector3.new(100, 0, 0),
				300,
				"Tense",
				rawPositionsNoLegit,
				TENSE_THRESHOLD,
				HUNT_THRESHOLD,
				HOTSPOT_DEDUP_GRID_SIZE,
				DecayFalloffLogic.dist2DSquared,
				fieldValueFn,
				topContributorsFn
			)
			expect(resultAfterRemoval).to.equal(nil)
		end
		it(
			"test_get_hottest_hotspot_disqualifies_positive_infinity_and_returns_legit_candidate",
			function()
				test_get_hottest_hotspot_disqualifies_positive_infinity_and_returns_legit_candidate()
			end
		)
	end)

	describe(
		"DisturbanceServiceHotspotQueryLogic -- Story 008 (H.25c falsifiability control, REAL fieldValue() composition)",
		function()
			-- FIXED (code-review follow-up, 2026-07-08) -- see this file's own header note, since
			-- updated. Asserts the CURRENT, actual, empirically-verified behavior of the real
			-- composed fieldValue() path, now that DecayFalloffLogic.FieldValueAt's clamp
			-- argument-order bug is fixed: a corrupted (NaN-flavored) source's contribution
			-- correctly propagates as NaN, is never laundered into a finite value, and is
			-- disqualified by this story's own ScoreCandidates guard on the real end-to-end path
			-- (not just against injected stubs, as it was before the fix).
			local function test_probe_fieldvalue_is_nan_not_laundered_under_nan_corruption()
				-- FIXED (code-review follow-up, 2026-07-08): this test previously documented a real
				-- bug in DecayFalloffLogic.FieldValueAt's clamp (`math.min(1.0, total)` laundered a
				-- NaN `total` into a finite 1.0, since Luau's math.min(a, b) returns `a` whenever `b`
				-- is NaN). Fixed by swapping the argument order (math.min(total, 1.0)) so NaN now
				-- correctly propagates -- this test asserts the CORRECT (fixed) behavior: the probe
				-- value is genuinely NaN, not silently laundered into a finite reading. See
				-- decay-falloff-fieldvalue_test.luau's own dedicated regression test at the source.
				local grid, liveSources, decayCache = makeWorld()
				insertSource(grid, liveSources, decayCache, "corrupted", Vector3.new(0, 0, 0), 0 / 0, 0)

				local probeValue = fieldValueViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0))
				expect(probeValue == probeValue).to.equal(false) -- genuinely NaN, correctly propagated
			end
			it(
				"test_probe_fieldvalue_is_nan_not_laundered_under_nan_corruption",
				function()
					test_probe_fieldvalue_is_nan_not_laundered_under_nan_corruption()
				end
			)

			-- +math.huge flavor (independent run) -- this one IS the clamp's intended, correct
			-- behavior (a legitimately-overflowing total correctly clamping to 1.0), not a defect.
			local function test_probe_fieldvalue_is_finite_under_positive_infinity_corruption()
				local grid, liveSources, decayCache = makeWorld()
				insertSource(grid, liveSources, decayCache, "corrupted", Vector3.new(0, 0, 0), math.huge, 0)

				local probeValue = fieldValueViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0))
				expect(probeValue == probeValue).to.equal(true)
				expect(probeValue ~= math.huge).to.equal(true)
				expect(probeValue).to.equal(1.0) -- correctly clamped
			end
			it(
				"test_probe_fieldvalue_is_finite_under_positive_infinity_corruption",
				function()
					test_probe_fieldvalue_is_finite_under_positive_infinity_corruption()
				end
			)
		end
	)

	describe("DisturbanceServiceHotspotQueryLogic -- Story 008 (TopContributorsAt contract)", function()
		-- zero/nonzero contract: zero live contributors -> ({}, 0).
		local function test_top_contributors_returns_empty_when_zero_contributors()
			local topIds, oldestAge = HotspotQueryLogic.TopContributorsAt(
				Vector3.new(0, 0, 0),
				3,
				{}, -- no candidate ids at all
				{},
				{},
				INFLUENCE_RADIUS,
				100,
				DecayFalloffLogic.dist2D,
				DecayFalloffLogic.Contribution
			)
			expect(#topIds).to.equal(0)
			expect(oldestAge).to.equal(0)
		end
		it(
			"test_top_contributors_returns_empty_when_zero_contributors",
			function()
				test_top_contributors_returns_empty_when_zero_contributors()
			end
		)

		-- nonzero contract: >= 1 live contributor -> at least 1 emissionId in slot 1, ranked by
		-- contribution descending, age = max across ALL in-range contributors (not just top-n).
		local function test_top_contributors_ranks_by_contribution_descending_and_reports_max_age()
			local grid, liveSources, decayCache = makeWorld()
			-- Four sources, all near the origin, within INFLUENCE_RADIUS -- distinct
			-- contributions/ages so ranking + max-age-across-all-contributors is unambiguous.
			insertSource(grid, liveSources, decayCache, "low", Vector3.new(20, 0, 0), 0.10, 5) -- far, weak, young
			insertSource(grid, liveSources, decayCache, "mid", Vector3.new(10, 0, 0), 0.30, 50) -- mid, mid, OLDEST
			insertSource(grid, liveSources, decayCache, "high", Vector3.new(0, 0, 0), 0.50, 20) -- close, strong

			local topIds, oldestAge = topContributorsViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0), 3, 100)

			expect(#topIds).to.equal(3)
			expect(topIds[1]).to.equal("high") -- dist=0, magnitude=0.50 -> highest contribution
			expect(topIds[2]).to.equal("mid")
			expect(topIds[3]).to.equal("low")
			-- Max age across ALL in-range contributors: "mid" at now(100) - emissionTime(50) = 50,
			-- the oldest of the three (high=80, low=95 -- wait, verify: high age=100-20=80;
			-- low age=100-5=95). The true oldest (max age) is "low" at 95s -- NOT limited to the
			-- top-1 contributor by score.
			expect(oldestAge).to.equal(95)
		end
		it(
			"test_top_contributors_ranks_by_contribution_descending_and_reports_max_age",
			function()
				test_top_contributors_ranks_by_contribution_descending_and_reports_max_age()
			end
		)

		-- n smaller than the live-contributor count: only n returned, still ranked correctly.
		local function test_top_contributors_respects_n_smaller_than_contributor_count()
			local grid, liveSources, decayCache = makeWorld()
			insertSource(grid, liveSources, decayCache, "a", Vector3.new(0, 0, 0), 0.50, 0)
			insertSource(grid, liveSources, decayCache, "b", Vector3.new(1, 0, 0), 0.40, 0)
			insertSource(grid, liveSources, decayCache, "c", Vector3.new(2, 0, 0), 0.30, 0)

			local topIds = topContributorsViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0), 1, 0)
			expect(#topIds).to.equal(1)
			expect(topIds[1]).to.equal("a")
		end
		it(
			"test_top_contributors_respects_n_smaller_than_contributor_count",
			function()
				test_top_contributors_respects_n_smaller_than_contributor_count()
			end
		)

		-- Expired/missing sources are silently skipped, never counted as contributors.
		local function test_top_contributors_skips_expired_sources()
			local grid, liveSources, decayCache = makeWorld()
			insertSource(grid, liveSources, decayCache, "live", Vector3.new(0, 0, 0), 0.50, 0)
			insertSource(grid, liveSources, decayCache, "expired", Vector3.new(1, 0, 0), 0.90, 0)
			decayCache["expired"] = { magnitude = 0.90, expired = true }

			local topIds, _oldestAge = topContributorsViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0), 3, 10)
			expect(#topIds).to.equal(1)
			expect(topIds[1]).to.equal("live")
		end
		it("test_top_contributors_skips_expired_sources", function()
			test_top_contributors_skips_expired_sources()
		end)
	end)

	describe("DisturbanceServiceSpatialGridLogic -- Story 008 (QueryCellsInRadius)", function()
		-- Confirms the new general cell-range primitive covers a wider footprint than the fixed
		-- 3x3 QueryNeighborhood would -- the whole point of adding it (see this story's own
		-- SPATIAL-GRID QUERY-PRIMITIVE NOTE / final report flag).
		local function test_query_cells_in_radius_covers_sources_beyond_a_fixed_3x3_neighborhood()
			local grid: SpatialGrid = {}
			-- 200 studs away on the X axis -- WAY beyond a fixed 3x3/32-stud-cell neighborhood
			-- (max ~48 studs), but well within a 300-stud searchRadius.
			local farPosition = Vector3.new(200, 0, 0)
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(farPosition, SPATIAL_GRID_CELL_SIZE)
			SpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, "farSource")

			local viaFixedNeighborhood = SpatialGridLogic.QueryNeighborhood(grid, 0, 0)
			expect(#viaFixedNeighborhood).to.equal(0) -- NOT found via the fixed 3x3 primitive

			local viaRadiusQuery = SpatialGridLogic.QueryCellsInRadius(grid, Vector3.new(0, 0, 0), 300, SPATIAL_GRID_CELL_SIZE)
			local found = false
			for _, id in viaRadiusQuery do
				if id == "farSource" then
					found = true
				end
			end
			expect(found).to.equal(true)
		end
		it(
			"test_query_cells_in_radius_covers_sources_beyond_a_fixed_3x3_neighborhood",
			function()
				test_query_cells_in_radius_covers_sources_beyond_a_fixed_3x3_neighborhood()
			end
		)

		-- A source far outside even the radius query's own padded cell range is correctly absent.
		local function test_query_cells_in_radius_excludes_sources_far_outside_the_range()
			local grid: SpatialGrid = {}
			local veryFarPosition = Vector3.new(100000, 0, 100000)
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(veryFarPosition, SPATIAL_GRID_CELL_SIZE)
			SpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, "veryFarSource")

			local viaRadiusQuery = SpatialGridLogic.QueryCellsInRadius(grid, Vector3.new(0, 0, 0), 300, SPATIAL_GRID_CELL_SIZE)
			expect(#viaRadiusQuery).to.equal(0)
		end
		it(
			"test_query_cells_in_radius_excludes_sources_far_outside_the_range",
			function()
				test_query_cells_in_radius_excludes_sources_far_outside_the_range()
			end
		)
	end)

	describe("DisturbanceServiceHotspotQueryLogic -- Story 008 (H.23/H.24/H.25/H.25b end-to-end, real composition)", function()
		-- H.23: no live sources anywhere -> nil, no error, across finite callerPositions
		-- including the origin, extreme-but-finite coordinates, and negative coordinates.
		local function test_h23_no_live_sources_returns_nil_across_callerposition_variants()
			local grid, liveSources, decayCache = makeWorld()

			local variants = { Vector3.new(0, 0, 0), Vector3.new(1e10, 0, 1e10), Vector3.new(-500, 0, -500) }
			for _, callerPosition in variants do
				local ok, result = pcall(function()
					return getHottestHotspotViaWorld(grid, liveSources, decayCache, callerPosition, 200, "Tense")
				end)
				expect(ok).to.equal(true)
				expect(result).to.equal(nil)
			end
		end
		it(
			"test_h23_no_live_sources_returns_nil_across_callerposition_variants",
			function()
				test_h23_no_live_sources_returns_nil_across_callerposition_variants()
			end
		)

		-- H.24: live sources exist, but none reach the Tense floor (0.30) -> nil.
		local function test_h24_sources_below_tierfloor_returns_nil()
			local grid, liveSources, decayCache = makeWorld()
			insertSource(grid, liveSources, decayCache, "weakA", Vector3.new(0, 0, 0), 0.05, 0)
			insertSource(grid, liveSources, decayCache, "weakB", Vector3.new(500, 0, 500), 0.05, 0)

			local result = getHottestHotspotViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0), 1000, "Tense")
			expect(result).to.equal(nil)
		end
		it("test_h24_sources_below_tierfloor_returns_nil", function()
			test_h24_sources_below_tierfloor_returns_nil()
		end)

		-- H.25 / H.25b: three isolated sources (no co-cell competitors, per H.25's own test-setup
		-- instruction), source A scores highest -> result.fieldValue matches fieldValue(A.position)
		-- +/- 0.001, topContributingEmissionIds[1] == A.emissionId, and the H.25b non-empty +
		-- UUID-format + resolves-in-live-source-list contract all hold.
		local function test_h25_and_h25b_highest_scoring_source_wins_with_valid_top_contributor()
			local grid, liveSources, decayCache = makeWorld()
			local idA = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
			local idB = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"
			local idC = "cccccccc-cccc-cccc-cccc-cccccccccccc"
			insertSource(grid, liveSources, decayCache, idA, Vector3.new(0, 0, 0), 0.90, 0)
			insertSource(grid, liveSources, decayCache, idB, Vector3.new(100, 0, 0), 0.50, 0)
			insertSource(grid, liveSources, decayCache, idC, Vector3.new(200, 0, 0), 0.30, 0)

			local result = getHottestHotspotViaWorld(grid, liveSources, decayCache, Vector3.new(100, 0, 0), 300, "Tense")
			expect(result).never.to.equal(nil)
			local hotspot = result :: HotspotQueryLogic.HotspotResult

			local expectedFieldValueAtA = fieldValueViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0))
			expect(almostEqual(hotspot.fieldValue, expectedFieldValueAtA, 0.001)).to.equal(true)
			expect(hotspot.position).to.equal(Vector3.new(0, 0, 0))
			expect(hotspot.hotspotCount).to.equal(3) -- all three meet the Tense floor (C at exactly 0.30)

			-- H.25b
			expect(#hotspot.topContributingEmissionIds >= 1).to.equal(true)
			expect(hotspot.topContributingEmissionIds[1]).to.equal(idA)
			expect(hotspot.topContributingEmissionIds[1]:match(UUID_PATTERN)).never.to.equal(nil)
			expect(liveSources[hotspot.topContributingEmissionIds[1]] ~= nil).to.equal(true)
		end
		it(
			"test_h25_and_h25b_highest_scoring_source_wins_with_valid_top_contributor",
			function()
				test_h25_and_h25b_highest_scoring_source_wins_with_valid_top_contributor()
			end
		)
	end)

	describe("DisturbanceServiceHotspotQueryLogic -- Story 008 (H.25d hotspotId stability across representative-position turnover)", function()
		local function test_h25d_hotspotid_stable_across_turnover_and_differs_across_cells()
			local grid, liveSources, decayCache = makeWorld()
			-- A and B both floor-snap to dedup cell "0_0" at HOTSPOT_DEDUP_GRID_SIZE=4.
			local sourceA = Vector3.new(1, 0, 1)
			local sourceB = Vector3.new(2, 0, 2)
			insertSource(grid, liveSources, decayCache, "sourceA", sourceA, 0.90, 0)
			insertSource(grid, liveSources, decayCache, "sourceB", sourceB, 0.90, 0)

			-- Query BEFORE turnover: sourceA is first-encountered -> representative position = A.
			local beforeResult = getHottestHotspotViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0), 200, "Tense")
			expect(beforeResult).never.to.equal(nil)
			local before = beforeResult :: HotspotQueryLogic.HotspotResult
			expect(before.hotspotId).to.equal("0_0")
			expect(before.position).to.equal(sourceA)

			-- Simulate sourceA's expiry (the real maintenance-pass effect: removed from grid,
			-- liveSources, decayCache) while sourceB (same dedup cell) remains and keeps the cell
			-- winning.
			removeSource(grid, liveSources, decayCache, "sourceA")

			local afterResult = getHottestHotspotViaWorld(grid, liveSources, decayCache, Vector3.new(0, 0, 0), 200, "Tense")
			expect(afterResult).never.to.equal(nil)
			local after = afterResult :: HotspotQueryLogic.HotspotResult

			-- (a) identical hotspotId across both calls even though position differs.
			expect(after.hotspotId).to.equal(before.hotspotId)
			expect(after.position).to.equal(sourceB)
			expect(after.position == before.position).to.equal(false)

			-- (b) canonical format regex.
			expect(before.hotspotId:match(HOTSPOT_ID_PATTERN)).never.to.equal(nil)
			expect(after.hotspotId:match(HOTSPOT_ID_PATTERN)).never.to.equal(nil)

			-- Follow-up config: a DIFFERENT dedup cell (K2) wins -> hotspotId differs from K1's.
			local grid2, liveSources2, decayCache2 = makeWorld()
			insertSource(grid2, liveSources2, decayCache2, "sourceK2", Vector3.new(500, 0, 500), 0.90, 0)
			local k2Result = getHottestHotspotViaWorld(grid2, liveSources2, decayCache2, Vector3.new(500, 0, 500), 200, "Tense")
			expect(k2Result).never.to.equal(nil)
			local k2 = k2Result :: HotspotQueryLogic.HotspotResult
			expect(k2.hotspotId).never.to.equal(before.hotspotId)
			expect(k2.hotspotId:match(HOTSPOT_ID_PATTERN)).never.to.equal(nil)
		end
		it(
			"test_h25d_hotspotid_stable_across_turnover_and_differs_across_cells",
			function()
				test_h25d_hotspotid_stable_across_turnover_and_differs_across_cells()
			end
		)
	end)

	describe("DisturbanceServiceHotspotQueryLogic -- Story 008 (secondBestPosition removal, no flank/distract mechanic)", function()
		local function test_second_best_position_is_not_implemented()
			local source = fs.readFile("src/gameplay/services/DisturbanceServiceHotspotQueryLogic.luau")
			expect(source:find("secondBestPosition%s*=")).to.equal(nil)
			expect(source:find("function DisturbanceServiceHotspotQueryLogic%.SecondBestPosition")).to.equal(nil)
		end
		it("test_second_best_position_is_not_implemented", function()
			test_second_best_position_is_not_implemented()
		end)
	end)

	describe("DisturbanceService.luau -- Story 008 (wiring, static checks)", function()
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

		-- No client-callable path: GetHottestHotspot/_topContributorsAt never appear on
		-- DisturbanceService.Client (matching Stories 002-007's own precedent test).
		local function test_client_table_remains_empty_no_hotspot_methods_exposed_to_clients()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it(
			"test_client_table_remains_empty_no_hotspot_methods_exposed_to_clients",
			function()
				test_client_table_remains_empty_no_hotspot_methods_exposed_to_clients()
			end
		)

		-- Wiring confirmation: GetHottestHotspot exists, takes callerPosition as a parameter (not
		-- pulled via Knit.GetService -- TR-ed-046), and routes through
		-- SpatialGridLogic.QueryCellsInRadius + HotspotQueryLogic.GetHottestHotspot.
		local function test_disturbance_service_wires_get_hottest_hotspot()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:GetHottestHotspot%(")).never.to.equal(nil)
			expect(source:find("callerPosition: Vector3")).never.to.equal(nil)
			expect(source:find("SpatialGridLogic%.QueryCellsInRadius%(")).never.to.equal(nil)
			expect(source:find("HotspotQueryLogic%.GetHottestHotspot%(")).never.to.equal(nil)
			-- F.1 "no MVP-internal hard dependencies": GetHottestHotspot never pulls position via
			-- Knit.GetService internally.
			expect(source:find('Knit%.GetService%("PredatorAI"%)')).to.equal(nil)
			expect(source:find('Knit%.GetService%("PredatorService"%)')).to.equal(nil)
		end
		it("test_disturbance_service_wires_get_hottest_hotspot", function()
			test_disturbance_service_wires_get_hottest_hotspot()
		end)

		-- Wiring confirmation: _topContributorsAt exists and routes through
		-- SpatialGridLogic.QueryNeighborhood (the FIXED 3x3 primitive, matching fieldValue()'s own
		-- INFLUENCE_RADIUS scan) + HotspotQueryLogic.TopContributorsAt.
		local function test_disturbance_service_wires_top_contributors_at()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:_topContributorsAt%(")).never.to.equal(nil)
			expect(source:find("HotspotQueryLogic%.TopContributorsAt%(")).never.to.equal(nil)
		end
		it("test_disturbance_service_wires_top_contributors_at", function()
			test_disturbance_service_wires_top_contributors_at()
		end)

		-- Exposed-for-testability accessors mirror the established Stories 002-007 precedent.
		local function test_disturbance_service_exposes_hotspot_pure_functions_for_testability()
			local source = loadServiceSource()
			expect(source:find("DisturbanceService%.TierLowerBound = HotspotQueryLogic%.TierLowerBound")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.DedupCellKey = HotspotQueryLogic%.DedupCellKey")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.ScoreCandidates = HotspotQueryLogic%.ScoreCandidates")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.TopContributorsAt = HotspotQueryLogic%.TopContributorsAt")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.QueryCellsInRadius = SpatialGridLogic%.QueryCellsInRadius")).never.to.equal(nil)
		end
		it(
			"test_disturbance_service_exposes_hotspot_pure_functions_for_testability",
			function()
				test_disturbance_service_exposes_hotspot_pure_functions_for_testability()
			end
		)

		-- PathfindingService:FindPathAsync is NOT this story's scope (TR-ed-034) -- confirm this
		-- file never calls it.
		local function test_disturbance_service_never_calls_pathfinding_service()
			local source = loadServiceSource()
			expect(source:find("FindPathAsync")).to.equal(nil)
		end
		it("test_disturbance_service_never_calls_pathfinding_service", function()
			test_disturbance_service_never_calls_pathfinding_service()
		end)
	end)
end
