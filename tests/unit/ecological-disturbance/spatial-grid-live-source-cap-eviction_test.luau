--!strict
-- spatial-grid-live-source-cap-eviction_test
--
-- Unit tests for Story 003: Spatial Hash Grid, Live-Source List & Cap Eviction.
-- Story: production/epics/ecological-disturbance/story-003-spatial-grid-live-source-cap-eviction.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceSpatialGridLogic.luau (pure grid math, cell
--     insertion/removal hygiene, 3x3-neighborhood query primitive, oldest-first cap eviction
--     with deterministic tie-break -- C.1.6, H.35b)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only, for
--     the same reason Story 002's test file gives -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live DisturbanceService:Emit() call is
--     not currently possible in an automated test)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local SpatialGridLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceSpatialGridLogic)

type SpatialGrid = SpatialGridLogic.SpatialGrid
type MinimalSource = SpatialGridLogic.MinimalSource

-- MAX_LIVE_SOURCES / SPATIAL_GRID_CELL_SIZE literals below intentionally match
-- DisturbanceConstants.luau's published values (500 / 32) without require()-ing that module --
-- this test file follows the exact same harness-driven precedent Story 002's own test file
-- documents (DisturbanceConstants.luau is not mounted under this harness's ServerScriptService
-- tree, and require(script.Parent...) is not resolvable for loadstring-executed modules here).
local MAX_LIVE_SOURCES = 500
local SPATIAL_GRID_CELL_SIZE = 32

--- Builds a well-formed MinimalSource record for test setup.
local function makeSource(emissionId: string, emissionTime: number, position: Vector3?): MinimalSource
	return {
		emissionId = emissionId,
		sourcePlayerId = 1,
		emissionType = "Gather",
		emissionTime = emissionTime,
		position = position or Vector3.new(0, 0, 0),
	}
end

--- Returns true if `id` appears anywhere in the flat array `list`.
local function listContains(list: { string }, id: string): boolean
	for _, entry in list do
		if entry == id then
			return true
		end
	end
	return false
end

--- Counts the number of populated grid buckets (for hygiene assertions).
local function countGridCells(grid: SpatialGrid): number
	local count = 0
	for _, row in grid do
		for _ in row do
			count += 1
		end
	end
	return count
end

return function()
	describe("DisturbanceServiceSpatialGridLogic -- Story 003 (cell math)", function()
		local function test_cell_coord_for_uses_default_cell_size_of_32()
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(Vector3.new(40, 0, 70))
			expect(cellX).to.equal(1) -- floor(40 / 32) = 1
			expect(cellZ).to.equal(2) -- floor(70 / 32) = 2
		end
		it("test_cell_coord_for_uses_default_cell_size_of_32", function()
			test_cell_coord_for_uses_default_cell_size_of_32()
		end)

		-- Required edge case: X=-0.5 must floor to cell -1, not 0.
		local function test_cell_coord_for_negative_position_floors_toward_negative_infinity()
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(Vector3.new(-0.5, 0, -0.5))
			expect(cellX).to.equal(-1)
			expect(cellZ).to.equal(-1)
		end
		it(
			"test_cell_coord_for_negative_position_floors_toward_negative_infinity",
			function()
				test_cell_coord_for_negative_position_floors_toward_negative_infinity()
			end
		)

		-- Boundary edge case: a position exactly on a cell boundary (X=32) belongs to the NEXT
		-- cell (32 / 32 = 1 exactly, floor(1) = 1), not the previous one.
		local function test_cell_coord_for_position_exactly_on_boundary()
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(Vector3.new(32, 0, -32))
			expect(cellX).to.equal(1)
			expect(cellZ).to.equal(-1)
		end
		it("test_cell_coord_for_position_exactly_on_boundary", function()
			test_cell_coord_for_position_exactly_on_boundary()
		end)

		-- The explicit cellSize override (production wiring: DisturbanceService.luau always
		-- passes DisturbanceConstants.SPATIAL_GRID_CELL_SIZE explicitly rather than relying on
		-- this module's own fallback default).
		local function test_cell_coord_for_respects_explicit_cell_size_override()
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(Vector3.new(25, 0, 5), 10)
			expect(cellX).to.equal(2) -- floor(25 / 10) = 2
			expect(cellZ).to.equal(0) -- floor(5 / 10) = 0
		end
		it("test_cell_coord_for_respects_explicit_cell_size_override", function()
			test_cell_coord_for_respects_explicit_cell_size_override()
		end)
	end)

	describe("DisturbanceServiceSpatialGridLogic -- Story 003 (grid cell insertion/removal hygiene)", function()
		local function test_insert_and_remove_single_source_cleans_up_bucket_and_row()
			local grid: SpatialGrid = {}
			SpatialGridLogic.InsertSourceIntoGridCell(grid, 0, 0, "sourceA")

			expect(grid[0]).never.to.equal(nil)
			expect(grid[0][0]).never.to.equal(nil)
			expect(listContains(grid[0][0], "sourceA")).to.equal(true)

			SpatialGridLogic.RemoveSourceFromGridCell(grid, 0, 0, "sourceA")

			-- Hygiene: the empty bucket AND the now-empty row are both cleaned up, not left as
			-- dead weight.
			expect(grid[0]).to.equal(nil)
		end
		it(
			"test_insert_and_remove_single_source_cleans_up_bucket_and_row",
			function()
				test_insert_and_remove_single_source_cleans_up_bucket_and_row()
			end
		)

		local function test_remove_source_leaves_row_intact_when_sibling_cell_remains()
			local grid: SpatialGrid = {}
			SpatialGridLogic.InsertSourceIntoGridCell(grid, 0, 0, "sourceA")
			SpatialGridLogic.InsertSourceIntoGridCell(grid, 0, 1, "sourceB")

			SpatialGridLogic.RemoveSourceFromGridCell(grid, 0, 0, "sourceA")

			-- grid[0][0]'s bucket is cleaned up, but grid[0] itself survives because grid[0][1]
			-- still has an occupant.
			expect(grid[0]).never.to.equal(nil)
			expect(grid[0][0]).to.equal(nil)
			expect(grid[0][1]).never.to.equal(nil)
			expect(listContains(grid[0][1], "sourceB")).to.equal(true)
		end
		it(
			"test_remove_source_leaves_row_intact_when_sibling_cell_remains",
			function()
				test_remove_source_leaves_row_intact_when_sibling_cell_remains()
			end
		)

		local function test_remove_source_from_nonexistent_cell_is_a_safe_no_op()
			local grid: SpatialGrid = {}
			-- Must not error when removing from a cell that was never populated.
			SpatialGridLogic.RemoveSourceFromGridCell(grid, 5, 5, "ghost")
			expect(next(grid)).to.equal(nil)
		end
		it("test_remove_source_from_nonexistent_cell_is_a_safe_no_op", function()
			test_remove_source_from_nonexistent_cell_is_a_safe_no_op()
		end)
	end)

	describe("DisturbanceServiceSpatialGridLogic -- Story 003 (3x3-neighborhood query primitive)", function()
		local function test_query_neighborhood_finds_sources_within_3x3_and_excludes_beyond_it()
			local grid: SpatialGrid = {}
			SpatialGridLogic.InsertSourceIntoGridCell(grid, 0, 0, "center")
			SpatialGridLogic.InsertSourceIntoGridCell(grid, 1, 1, "diagonalNeighbor")
			SpatialGridLogic.InsertSourceIntoGridCell(grid, -1, -1, "oppositeDiagonalNeighbor")
			SpatialGridLogic.InsertSourceIntoGridCell(grid, 2, 2, "outsideNeighborhood")

			local results = SpatialGridLogic.QueryNeighborhood(grid, 0, 0)

			expect(listContains(results, "center")).to.equal(true)
			expect(listContains(results, "diagonalNeighbor")).to.equal(true)
			expect(listContains(results, "oppositeDiagonalNeighbor")).to.equal(true)
			expect(listContains(results, "outsideNeighborhood")).to.equal(false)
			expect(#results).to.equal(3)
		end
		it(
			"test_query_neighborhood_finds_sources_within_3x3_and_excludes_beyond_it",
			function()
				test_query_neighborhood_finds_sources_within_3x3_and_excludes_beyond_it()
			end
		)

		-- Cross-cell-boundary edge case: a source near the edge of its own cell is still
		-- discoverable from an adjacent query cell via the 3x3 scan (query position at the
		-- extreme edge of INFLUENCE_RADIUS from a cell it doesn't share).
		local function test_query_neighborhood_discovers_source_across_cell_boundary()
			local grid: SpatialGrid = {}
			-- A source sitting at the far edge of cell (0, 0).
			local sourcePosition = Vector3.new(31, 0, 31)
			local sourceCellX, sourceCellZ = SpatialGridLogic.CellCoordFor(sourcePosition, SPATIAL_GRID_CELL_SIZE)
			SpatialGridLogic.InsertSourceIntoGridCell(grid, sourceCellX, sourceCellZ, "edgeSource")

			-- Querying from the diagonally-adjacent cell (1, 1) -- its 3x3 neighborhood spans
			-- cells 0..2 on each axis, which includes cell (0, 0).
			local results = SpatialGridLogic.QueryNeighborhood(grid, 1, 1)
			expect(listContains(results, "edgeSource")).to.equal(true)
		end
		it(
			"test_query_neighborhood_discovers_source_across_cell_boundary",
			function()
				test_query_neighborhood_discovers_source_across_cell_boundary()
			end
		)

		local function test_query_neighborhood_on_empty_grid_returns_empty_array()
			local grid: SpatialGrid = {}
			local results = SpatialGridLogic.QueryNeighborhood(grid, 4, 4)
			expect(#results).to.equal(0)
		end
		it("test_query_neighborhood_on_empty_grid_returns_empty_array", function()
			test_query_neighborhood_on_empty_grid_returns_empty_array()
		end)
	end)

	describe("DisturbanceServiceSpatialGridLogic -- Story 003 (H.35b oldest-first cap eviction)", function()
		local function test_find_oldest_source_id_returns_smallest_emission_time()
			local liveSources: { [string]: MinimalSource } = {
				a = makeSource("a", 100),
				b = makeSource("b", 50),
				c = makeSource("c", 200),
			}
			local insertionSequence = { a = 1, b = 2, c = 3 }

			local oldestId = SpatialGridLogic.FindOldestSourceId(liveSources, insertionSequence)
			expect(oldestId).to.equal("b")
		end
		it("test_find_oldest_source_id_returns_smallest_emission_time", function()
			test_find_oldest_source_id_returns_smallest_emission_time()
		end)

		-- Required edge case: identical emissionTime is tie-broken by insertion order
		-- (first-inserted-wins-as-oldest -- the smaller insertionSequence value).
		local function test_find_oldest_source_id_tie_break_is_first_inserted()
			local liveSources: { [string]: MinimalSource } = {
				firstInserted = makeSource("firstInserted", 500),
				secondInserted = makeSource("secondInserted", 500),
			}
			local insertionSequence = { firstInserted = 1, secondInserted = 2 }

			local oldestId = SpatialGridLogic.FindOldestSourceId(liveSources, insertionSequence)
			expect(oldestId).to.equal("firstInserted")
		end
		it("test_find_oldest_source_id_tie_break_is_first_inserted", function()
			test_find_oldest_source_id_tie_break_is_first_inserted()
		end)

		local function test_find_oldest_source_id_returns_nil_for_empty_table()
			local oldestId = SpatialGridLogic.FindOldestSourceId({}, {})
			expect(oldestId).to.equal(nil)
		end
		it("test_find_oldest_source_id_returns_nil_for_empty_table", function()
			test_find_oldest_source_id_returns_nil_for_empty_table()
		end)

		local function test_evict_oldest_source_removes_from_both_live_sources_and_grid()
			local grid: SpatialGrid = {}
			local liveSources: { [string]: MinimalSource } = {}
			local insertionSequence: { [string]: number } = {}

			local oldSource = makeSource("old", 10, Vector3.new(0, 0, 0))
			local newSource = makeSource("new", 20, Vector3.new(100, 0, 100))

			local oldCellX, oldCellZ = SpatialGridLogic.CellCoordFor(oldSource.position, SPATIAL_GRID_CELL_SIZE)
			local newCellX, newCellZ = SpatialGridLogic.CellCoordFor(newSource.position, SPATIAL_GRID_CELL_SIZE)

			SpatialGridLogic.InsertSourceIntoGridCell(grid, oldCellX, oldCellZ, "old")
			SpatialGridLogic.InsertSourceIntoGridCell(grid, newCellX, newCellZ, "new")
			liveSources["old"] = oldSource
			liveSources["new"] = newSource
			insertionSequence["old"] = 1
			insertionSequence["new"] = 2

			local evicted = SpatialGridLogic.EvictOldestSource(grid, liveSources, insertionSequence, SPATIAL_GRID_CELL_SIZE)

			expect(evicted).never.to.equal(nil)
			local evictedInfo = evicted :: SpatialGridLogic.EvictedSourceInfo
			expect(evictedInfo.emissionId).to.equal("old")
			expect(evictedInfo.sourcePlayerId).to.equal(1)
			expect(evictedInfo.emissionType).to.equal("Gather")
			expect(evictedInfo.emissionTime).to.equal(10)

			-- Removed from the live-source list.
			expect(liveSources["old"]).to.equal(nil)
			expect(insertionSequence["old"]).to.equal(nil)
			-- Removed from its grid cell bucket, and the empty bucket/row is cleaned up (it was
			-- the sole occupant of its cell).
			expect(grid[oldCellX]).to.equal(nil)
			-- The untouched source remains fully intact.
			expect(liveSources["new"]).never.to.equal(nil)
			expect(listContains(grid[newCellX][newCellZ], "new")).to.equal(true)
		end
		it(
			"test_evict_oldest_source_removes_from_both_live_sources_and_grid",
			function()
				test_evict_oldest_source_removes_from_both_live_sources_and_grid()
			end
		)

		-- Required edge case: the evicted source is the ONLY occupant of its grid cell -- the
		-- cell's bucket (and row) must not persist as dead weight.
		local function test_evict_oldest_source_cleans_up_empty_bucket_when_sole_occupant()
			local grid: SpatialGrid = {}
			local liveSources: { [string]: MinimalSource } = {}
			local insertionSequence: { [string]: number } = {}

			local soleOccupant = makeSource("sole", 5, Vector3.new(200, 0, 200))
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(soleOccupant.position, SPATIAL_GRID_CELL_SIZE)
			SpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, "sole")
			liveSources["sole"] = soleOccupant
			insertionSequence["sole"] = 1

			expect(countGridCells(grid)).to.equal(1)

			SpatialGridLogic.EvictOldestSource(grid, liveSources, insertionSequence, SPATIAL_GRID_CELL_SIZE)

			expect(countGridCells(grid)).to.equal(0)
			expect(next(grid)).to.equal(nil)
		end
		it(
			"test_evict_oldest_source_cleans_up_empty_bucket_when_sole_occupant",
			function()
				test_evict_oldest_source_cleans_up_empty_bucket_when_sole_occupant()
			end
		)

		local function test_evict_oldest_source_returns_nil_when_live_sources_empty()
			local grid: SpatialGrid = {}
			local evicted = SpatialGridLogic.EvictOldestSource(grid, {}, {}, SPATIAL_GRID_CELL_SIZE)
			expect(evicted).to.equal(nil)
		end
		it("test_evict_oldest_source_returns_nil_when_live_sources_empty", function()
			test_evict_oldest_source_returns_nil_when_live_sources_empty()
		end)
	end)

	describe("DisturbanceServiceSpatialGridLogic -- Story 003 (InsertEmission orchestration, AC-H.35b)", function()
		local function test_insert_emission_below_cap_does_not_evict()
			local grid: SpatialGrid = {}
			local liveSources: { [string]: MinimalSource } = {
				existing = makeSource("existing", 1),
			}
			local insertionSequence: { [string]: number } = { existing = 0 }

			local newPayload = makeSource("fresh", 2)
			local evicted, nextSequence = SpatialGridLogic.InsertEmission(
				grid,
				liveSources,
				insertionSequence,
				1,
				MAX_LIVE_SOURCES,
				newPayload,
				SPATIAL_GRID_CELL_SIZE
			)

			expect(evicted).to.equal(nil)
			expect(nextSequence).to.equal(2)
			expect(liveSources["existing"]).never.to.equal(nil)
			expect(liveSources["fresh"]).never.to.equal(nil)
		end
		it("test_insert_emission_below_cap_does_not_evict", function()
			test_insert_emission_below_cap_does_not_evict()
		end)

		-- AC-H.35b core case: GIVEN exactly MAX_LIVE_SOURCES (500) live sources with distinct,
		-- ascending emissionTimes, WHEN a 501st Emit() arrives, THEN the smallest-emissionTime
		-- source is evicted from both stores, the new source is present in both, and total
		-- count remains 500.
		local function test_insert_emission_at_exactly_cap_evicts_oldest_and_inserts_new()
			local grid: SpatialGrid = {}
			local liveSources: { [string]: MinimalSource } = {}
			local insertionSequence: { [string]: number } = {}

			for i = 1, MAX_LIVE_SOURCES do
				local id = "source" .. tostring(i)
				-- Spread sources across distinct cells so grid hygiene is also exercised at
				-- scale (not all 500 piled into one bucket).
				local position = Vector3.new(i * SPATIAL_GRID_CELL_SIZE, 0, 0)
				local record = makeSource(id, i, position) -- ascending emissionTime: 1..500
				local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, SPATIAL_GRID_CELL_SIZE)
				SpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, id)
				liveSources[id] = record
				insertionSequence[id] = i
			end

			expect(countGridCells(grid)).to.equal(MAX_LIVE_SOURCES)

			local newPosition = Vector3.new(999 * SPATIAL_GRID_CELL_SIZE, 0, 0)
			local newPayload = makeSource("source501", 501, newPosition)

			local evicted, updatedNextSequence = SpatialGridLogic.InsertEmission(
				grid,
				liveSources,
				insertionSequence,
				MAX_LIVE_SOURCES + 1,
				MAX_LIVE_SOURCES,
				newPayload,
				SPATIAL_GRID_CELL_SIZE
			)

			expect(evicted).never.to.equal(nil)
			local evictedInfo = evicted :: SpatialGridLogic.EvictedSourceInfo
			-- "source1" has emissionTime = 1, the smallest -- it must be the one evicted.
			expect(evictedInfo.emissionId).to.equal("source1")
			expect(updatedNextSequence).to.equal(MAX_LIVE_SOURCES + 2)

			-- Total count remains exactly MAX_LIVE_SOURCES.
			local finalCount = 0
			for _ in liveSources do
				finalCount += 1
			end
			expect(finalCount).to.equal(MAX_LIVE_SOURCES)

			-- The evicted source is gone from both stores; the evicted source's own grid cell
			-- (it was the sole occupant) is cleaned up entirely.
			expect(liveSources["source1"]).to.equal(nil)
			local evictedCellX, evictedCellZ = SpatialGridLogic.CellCoordFor(Vector3.new(1 * SPATIAL_GRID_CELL_SIZE, 0, 0), SPATIAL_GRID_CELL_SIZE)
			expect(grid[evictedCellX]).to.equal(nil)

			-- The new source is present in the live-source list and its grid cell.
			expect(liveSources["source501"]).never.to.equal(nil)
			local newCellX, newCellZ = SpatialGridLogic.CellCoordFor(newPosition, SPATIAL_GRID_CELL_SIZE)
			expect(listContains(grid[newCellX][newCellZ], "source501")).to.equal(true)
		end
		it(
			"test_insert_emission_at_exactly_cap_evicts_oldest_and_inserts_new",
			function()
				test_insert_emission_at_exactly_cap_evicts_oldest_and_inserts_new()
			end
		)

		-- Required edge case (H.35b tie-break, exercised end-to-end through InsertEmission
		-- rather than FindOldestSourceId in isolation): two of the at-cap sources share an
		-- identical emissionTime -- the deterministic first-inserted-wins-as-oldest rule must
		-- still pick exactly one, correctly, when a cap-triggering emission arrives. Uses a
		-- small custom maxLiveSources (InsertEmission's cap is an injected parameter, not a
		-- hardcoded 500) so the scenario stays easy to read.
		local function test_insert_emission_tie_break_case()
			local grid: SpatialGrid = {}
			local liveSources: { [string]: MinimalSource } = {}
			local insertionSequence: { [string]: number } = {}

			local tiedFirst = makeSource("tiedFirst", 42, Vector3.new(0, 0, 0))
			local tiedSecond = makeSource("tiedSecond", 42, Vector3.new(64, 0, 0))
			local distinctThird = makeSource("distinctThird", 99, Vector3.new(128, 0, 0))

			for _, entry in { { "tiedFirst", tiedFirst, 1 }, { "tiedSecond", tiedSecond, 2 }, { "distinctThird", distinctThird, 3 } } do
				local id, record, seq = entry[1], entry[2], entry[3]
				local cellX, cellZ = SpatialGridLogic.CellCoordFor(record.position, SPATIAL_GRID_CELL_SIZE)
				SpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, id)
				liveSources[id] = record
				insertionSequence[id] = seq
			end

			local newPayload = makeSource("fourth", 100, Vector3.new(192, 0, 0))
			local evicted = SpatialGridLogic.InsertEmission(
				grid,
				liveSources,
				insertionSequence,
				4,
				3, -- maxLiveSources: exactly 3 live sources already present triggers eviction
				newPayload,
				SPATIAL_GRID_CELL_SIZE
			)

			expect(evicted).never.to.equal(nil)
			-- tiedFirst and tiedSecond share emissionTime=42; tiedFirst was inserted first
			-- (insertionSequence=1 < 2), so it -- not tiedSecond -- is the one evicted.
			expect((evicted :: SpatialGridLogic.EvictedSourceInfo).emissionId).to.equal("tiedFirst")
			expect(liveSources["tiedFirst"]).to.equal(nil)
			expect(liveSources["tiedSecond"]).never.to.equal(nil)
		end
		it("test_insert_emission_tie_break_case", function()
			test_insert_emission_tie_break_case()
		end)
	end)

	describe("DisturbanceServiceSpatialGridLogic -- Story 003 (archive independence & forbidden-API static checks)", function()
		local spatialGridLogicSource: string? = nil
		local disturbanceServiceSource: string? = nil

		-- Naive first-`--`-match comment stripper, matching
		-- emission-schema-server-emit-intake_test.luau's own reference implementation exactly
		-- (see that file's header comment for the documented caveat: NOT quote-aware, so this
		-- project's own convention is to avoid `--` inside warn()/print()/error strings, using
		-- `:`/`|` separators instead -- this test file's own production code under test follows
		-- that convention).
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function loadSpatialGridLogicSource(): string
			if not spatialGridLogicSource then
				spatialGridLogicSource =
					stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceServiceSpatialGridLogic.luau"))
			end
			return spatialGridLogicSource :: string
		end

		local function loadServiceSource(): string
			if not disturbanceServiceSource then
				disturbanceServiceSource = stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceService.luau"))
			end
			return disturbanceServiceSource :: string
		end

		-- ====================================================================
		-- Archive independence: eviction is independent of Story 004's (not-yet-built)
		-- attribution archive BY CONSTRUCTION -- none of this module's functions accept an
		-- archive parameter, and the module never references "attributionArchive" anywhere in
		-- its actual code (comment-stripped).
		-- ====================================================================
		local function test_spatial_grid_logic_never_references_attribution_archive()
			local source = loadSpatialGridLogicSource()
			expect(source:find("[Aa]ttribution[Aa]rchive")).to.equal(nil)
		end
		it("test_spatial_grid_logic_never_references_attribution_archive", function()
			test_spatial_grid_logic_never_references_attribution_archive()
		end)

		-- ====================================================================
		-- ADR-0004 forbidden pattern: Region3 / Workspace:FindPartsInRegion3 must never appear
		-- -- sources are pure data, not physical Instances.
		-- ====================================================================
		local function test_spatial_grid_logic_never_uses_region3()
			local source = loadSpatialGridLogicSource()
			expect(source:find("Region3")).to.equal(nil)
			expect(source:find("FindPartsInRegion3")).to.equal(nil)
		end
		it("test_spatial_grid_logic_never_uses_region3", function()
			test_spatial_grid_logic_never_uses_region3()
		end)

		-- ====================================================================
		-- No client-callable path: the grid's insertion/removal/query/eviction methods never
		-- appear on DisturbanceService.Client (structural precondition for Story 016).
		-- ====================================================================
		local function test_client_table_remains_empty_no_grid_methods_exposed_to_clients()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it(
			"test_client_table_remains_empty_no_grid_methods_exposed_to_clients",
			function()
				test_client_table_remains_empty_no_grid_methods_exposed_to_clients()
			end
		)

		-- ====================================================================
		-- Wiring confirmation: DisturbanceService.luau's Emit() actually routes through
		-- SpatialGridLogic.InsertEmission() and passes DisturbanceConstants.SPATIAL_GRID_CELL_SIZE
		-- explicitly (never silently relying on the module's own fallback default in the real
		-- runtime path). This is a structural check, not a live-instantiation test, for the same
		-- Knit-not-vendored reason given at this file's header.
		-- ====================================================================
		local function test_disturbance_service_emit_wires_insert_emission()
			local source = loadServiceSource()
			expect(source:find("SpatialGridLogic%.InsertEmission%(")).never.to.equal(nil)
			expect(source:find("DisturbanceConstants%.SPATIAL_GRID_CELL_SIZE")).never.to.equal(nil)
			expect(source:find("DisturbanceConstants%.MAX_LIVE_SOURCES")).never.to.equal(nil)
		end
		it("test_disturbance_service_emit_wires_insert_emission", function()
			test_disturbance_service_emit_wires_insert_emission()
		end)

		-- ====================================================================
		-- Ops-log AC: "a server-side ops-log entry records the eviction" -- confirms Emit()'s
		-- `if evicted then` branch actually pairs with a warn() call site referencing the evicted
		-- source's identity fields, not just that InsertEmission() is wired at all (the prior
		-- test only proves wiring, not that the eviction's ops-log obligation is met). Static
		-- check, same Knit-not-vendored reason as the rest of this describe() block.
		-- ====================================================================
		local function test_disturbance_service_emit_logs_cap_eviction_ops_entry()
			local source = loadServiceSource()
			expect(source:find("if evicted then")).never.to.equal(nil)
			expect(source:find("cap%-evicted")).never.to.equal(nil)
			expect(source:find("evicted%.emissionId")).never.to.equal(nil)
			expect(source:find("evicted%.sourcePlayerId")).never.to.equal(nil)
		end
		it("test_disturbance_service_emit_logs_cap_eviction_ops_entry", function()
			test_disturbance_service_emit_logs_cap_eviction_ops_entry()
		end)
	end)
end
