--!strict
-- DisturbanceServiceSpatialGridLogic
--
-- Implements: production/epics/ecological-disturbance/story-003-spatial-grid-live-source-cap-eviction.md
-- GDD: design/gdd/ecological-disturbance.md -- C.1.6 (flat 2D spatial hash grid over active
--      emissions, 32x32-stud cells, XZ plane; 3x3-cell-neighborhood query primitive)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md -- "Spatial data
--      structure" Decision subsection (verbatim Key Interfaces code block this module's
--      CellCoordFor mirrors) and Cap-eviction policy (Q3, oldest-first by emissionTime
--      ascending -- supersedes the GDD's own H.35b "drop-new" prose, RESOLVED 2026-07-06).
--      `Region3`/`Workspace:FindPartsInRegion3` is explicitly FORBIDDEN here -- sources are
--      pure data, not physical Instances (see the ADR's Alternative 1 rejection).
--
-- Pure domain logic for DisturbanceService's spatial hash grid: cell-coordinate math,
-- grid cell insertion/removal (with empty-bucket/empty-row hygiene), the 3x3-neighborhood
-- query primitive Stories 005/008 call into, and MAX_LIVE_SOURCES cap-eviction (oldest-first,
-- deterministic tie-break). Deliberately has ZERO dependency on Knit or any Roblox service
-- call (mirrors DisturbanceServiceBootstrapLogic/DisturbanceServiceEmissionLogic's own
-- zero-require precedent from Stories 001/002), so it can be required and unit-tested
-- directly under Lune. DisturbanceService.luau is a thin Knit wrapper around this module's
-- functions -- it owns the real self._spatialGrid/self._liveSources/self._insertionSequence
-- state tables and the game-facing warn() ops-log call site for cap-evictions; this module
-- owns only the actual grid/eviction math and never touches self._attributionArchive.
--
-- ARCHIVE INDEPENDENCE (design note, approved 2026-07-06): Story 004's write-once attribution
-- archive does not exist yet. Per the story's own design note, this module's eviction
-- functions (EvictOldestSource / InsertEmission) NEVER read or write an archive -- their
-- signatures below have no archive parameter at all. This makes the "eviction is independent
-- of the archive" AC provable by construction, not just by convention: there is no code path
-- in this file that could touch an archive even if a future caller wanted it to. See this
-- file's own test (spatial-grid-live-source-cap-eviction_test.luau) for the accompanying
-- static check confirming the string "attributionArchive" appears nowhere in this file.
--
-- CellCoordFor's `cellSize` PARAMETER (design call, approved 2026-07-06): ADR-0004's Key
-- Interfaces block cites `cellCoordFor(position)` with a hardcoded
-- `local SPATIAL_GRID_CELL_SIZE = 32` at module scope. Unlike Story 002's schema-fixed local
-- constants (ATTRIBUTION_CHAIN_MAX_LENGTH, BEACON_MAGNITUDE_RESERVED_BOUNDARY),
-- SPATIAL_GRID_CELL_SIZE IS a genuine G.3 tuning knob in DisturbanceConstants.luau -- hardcoding
-- it here would create a second, driftable source of truth for a value coding-standards.md
-- requires be data-driven. Resolution: `cellSize` is an OPTIONAL parameter, defaulting to the
-- local DEFAULT_SPATIAL_GRID_CELL_SIZE fallback below (kept purely so this module's ADR-cited
-- one-argument call shape still works, e.g. in tests) -- but DisturbanceService.luau's real
-- call sites always pass DisturbanceConstants.SPATIAL_GRID_CELL_SIZE explicitly and never rely
-- on this fallback in a production code path.

export type SourceId = string
export type SpatialGrid = { [number]: { [number]: { SourceId } } } -- grid[cellX][cellZ] = flat list of source ids (ADR-0004)

--- The minimal structural shape this module needs from a live source record. The real
--- DisturbanceServiceEmissionLogic.EmissionPayload satisfies this structurally (it is a
--- superset of these fields) -- this module never require()s that module, matching the
--- zero-require precedent explained above.
export type MinimalSource = {
	emissionId: string,
	sourcePlayerId: number,
	emissionType: string,
	emissionTime: number,
	position: Vector3,
}

--- The eviction record DisturbanceService.luau's Emit() formats into its ops-log warn().
export type EvictedSourceInfo = {
	emissionId: string,
	sourcePlayerId: number,
	emissionType: string,
	emissionTime: number,
}

local DisturbanceServiceSpatialGridLogic = {}

-- Fallback only -- see this file's header note on why this is not the sole source of truth.
local DEFAULT_SPATIAL_GRID_CELL_SIZE = 32

-- ============================================================================
-- C.1.6 / ADR-0004 -- cell-coordinate math (verbatim math, optional cellSize override)
-- ============================================================================

--- Computes the (cellX, cellZ) integer cell coordinate containing `position`, on the XZ plane.
--- `math.floor` handles negative coordinates correctly (floors toward negative infinity):
--- a position at X=-0.5 floors to cell -1, not 0.
function DisturbanceServiceSpatialGridLogic.CellCoordFor(position: Vector3, cellSize: number?): (number, number)
	local size = cellSize or DEFAULT_SPATIAL_GRID_CELL_SIZE
	return math.floor(position.X / size), math.floor(position.Z / size)
end

-- ============================================================================
-- Grid cell insertion / removal (with empty-bucket / empty-row hygiene)
-- ============================================================================

--- Inserts `sourceId` into `grid[cellX][cellZ]`'s flat id list, creating the row/bucket tables
--- as needed.
function DisturbanceServiceSpatialGridLogic.InsertSourceIntoGridCell(
	grid: SpatialGrid,
	cellX: number,
	cellZ: number,
	sourceId: SourceId
): ()
	local row = grid[cellX]
	if not row then
		row = {}
		grid[cellX] = row
	end
	local bucket = row[cellZ]
	if not bucket then
		bucket = {}
		row[cellZ] = bucket
	end
	table.insert(bucket, sourceId)
end

--- Removes `sourceId` from `grid[cellX][cellZ]`'s flat id list. Hygiene (a correctness-adjacent
--- concern, not strictly required, per the story's own QA note): if the bucket becomes empty,
--- the cellZ entry is cleared; if the row then has no remaining cellZ entries, the cellX entry
--- is cleared too -- an empty-bucket/empty-row cell never persists as dead weight.
function DisturbanceServiceSpatialGridLogic.RemoveSourceFromGridCell(
	grid: SpatialGrid,
	cellX: number,
	cellZ: number,
	sourceId: SourceId
): ()
	local row = grid[cellX]
	if not row then
		return
	end
	local bucket = row[cellZ]
	if not bucket then
		return
	end
	for i, id in bucket do
		if id == sourceId then
			table.remove(bucket, i)
			break
		end
	end
	if #bucket == 0 then
		row[cellZ] = nil
	end
	if next(row) == nil then
		grid[cellX] = nil
	end
end

-- ============================================================================
-- C.1.6 -- 3x3-cell-neighborhood query primitive (the seam Stories 005/008 call into)
-- ============================================================================

--- Returns a flat array of every source id present in the 3x3 cell neighborhood centered on
--- (centerCellX, centerCellZ) -- i.e. cellX in [centerCellX-1, centerCellX+1] crossed with
--- cellZ in [centerCellZ-1, centerCellZ+1]. Touches only populated cells (up to 9 lookups),
--- never a full linear scan over all live sources.
function DisturbanceServiceSpatialGridLogic.QueryNeighborhood(
	grid: SpatialGrid,
	centerCellX: number,
	centerCellZ: number
): { SourceId }
	local result: { SourceId } = {}
	for dx = -1, 1 do
		local row = grid[centerCellX + dx]
		if row then
			for dz = -1, 1 do
				local bucket = row[centerCellZ + dz]
				if bucket then
					for _, id in bucket do
						table.insert(result, id)
					end
				end
			end
		end
	end
	return result
end

-- ============================================================================
-- Story 008 (D.6 / TR-ed-046) -- general cell-range query primitive for GetHottestHotspot's
-- `liveSourcesInGridCellsIntersecting(callerPosition, searchRadius)`. NOT the same as
-- QueryNeighborhood above: that primitive is a FIXED 3x3 neighborhood, sized correctly for
-- fieldValue()'s/topContributorsAt's fixed INFLUENCE_RADIUS (24 studs at 32-stud cells).
-- GetHottestHotspot's searchRadius is caller-supplied and documented up to 512 studs (Predator
-- AI's recommended 32-512 stud range) -- reusing the fixed 3x3 primitive for this step would
-- silently cap effective search range at ~48 studs regardless of the caller's searchRadius
-- argument. This function computes the cell range needed to cover a circle of radius
-- `searchRadius` around `centerPosition` and returns every source id in that range (a superset
-- of the true circle -- the caller still performs the exact dist2DSquared <= searchRadius^2 cull
-- per D.6 step 1's own inner check; over-inclusion here is a correctness-safe superset, not a bug).
-- ============================================================================

--- Returns a flat array of every source id present in every grid cell whose extent could
--- intersect a circle of radius `searchRadius` centered at `centerPosition`. See this section's
--- own header note for why this is a distinct primitive from QueryNeighborhood.
function DisturbanceServiceSpatialGridLogic.QueryCellsInRadius(
	grid: SpatialGrid,
	centerPosition: Vector3,
	searchRadius: number,
	cellSize: number?
): { SourceId }
	local size = cellSize or DEFAULT_SPATIAL_GRID_CELL_SIZE
	local centerCellX, centerCellZ = DisturbanceServiceSpatialGridLogic.CellCoordFor(centerPosition, size)
	-- +1 pads for a source sitting near the far edge of the outermost cell in range.
	local cellRadius = math.floor(searchRadius / size) + 1

	local result: { SourceId } = {}
	for dx = -cellRadius, cellRadius do
		local row = grid[centerCellX + dx]
		if row then
			for dz = -cellRadius, cellRadius do
				local bucket = row[centerCellZ + dz]
				if bucket then
					for _, id in bucket do
						table.insert(result, id)
					end
				end
			end
		end
	end
	return result
end

-- ============================================================================
-- H.35b -- MAX_LIVE_SOURCES cap-eviction: oldest-first by emissionTime ascending, with a
-- deterministic tie-break.
-- ============================================================================

--- Finds the emissionId of the oldest live source: smallest `emissionTime` wins; ties are
--- broken by the smaller `insertionSequence` value (first-inserted-wins-as-oldest -- the
--- story's own required, documented, deterministic tie-break rule). `insertionSequence` is a
--- caller-owned monotonic counter table keyed by emissionId, NOT derived from Luau's own
--- (unordered) table iteration -- pairs()/generalized-for iteration order over a hash-keyed
--- table is not something this module relies on for correctness.
--- Returns nil if `liveSources` is empty.
function DisturbanceServiceSpatialGridLogic.FindOldestSourceId(
	liveSources: { [string]: MinimalSource },
	insertionSequence: { [string]: number }
): SourceId?
	local oldestId: SourceId? = nil
	local oldestTime: number? = nil
	local oldestSeq: number? = nil

	for id, record in liveSources do
		local seq = insertionSequence[id] or 0
		if oldestId == nil then
			oldestId = id
			oldestTime = record.emissionTime
			oldestSeq = seq
		else
			local betterByTime = record.emissionTime < (oldestTime :: number)
			local tiedByTime = record.emissionTime == (oldestTime :: number)
			local betterBySequenceOnTie = tiedByTime and seq < (oldestSeq :: number)
			if betterByTime or betterBySequenceOnTie then
				oldestId = id
				oldestTime = record.emissionTime
				oldestSeq = seq
			end
		end
	end

	return oldestId
end

--- Evicts the single oldest live source (per FindOldestSourceId's rule) from BOTH `liveSources`
--- and its grid cell bucket. Returns the evicted source's info (for the caller's ops-log entry)
--- or nil if `liveSources` was already empty.
---
--- ARCHIVE INDEPENDENCE: this function's signature has no attribution-archive parameter --
--- it is structurally impossible for this function to read or write an archive. See this
--- file's header note.
function DisturbanceServiceSpatialGridLogic.EvictOldestSource(
	grid: SpatialGrid,
	liveSources: { [string]: MinimalSource },
	insertionSequence: { [string]: number },
	cellSize: number?
): EvictedSourceInfo?
	local oldestId = DisturbanceServiceSpatialGridLogic.FindOldestSourceId(liveSources, insertionSequence)
	if oldestId == nil then
		return nil
	end

	local record = liveSources[oldestId]
	local cellX, cellZ = DisturbanceServiceSpatialGridLogic.CellCoordFor(record.position, cellSize)
	DisturbanceServiceSpatialGridLogic.RemoveSourceFromGridCell(grid, cellX, cellZ, oldestId)

	liveSources[oldestId] = nil
	insertionSequence[oldestId] = nil

	return {
		emissionId = oldestId,
		sourcePlayerId = record.sourcePlayerId,
		emissionType = record.emissionType,
		emissionTime = record.emissionTime,
	}
end

-- ============================================================================
-- Orchestration -- the single entry point DisturbanceService:Emit() calls.
-- ============================================================================

--- Inserts `payload` into both `liveSources` and its grid cell. If `liveSources` already has
--- `maxLiveSources` entries, the single oldest live source is evicted first (per
--- EvictOldestSource) to make room -- the new emission is NEVER refused (ADR-0004's
--- evict-oldest policy, superseding the GDD's own "drop-new" H.35b prose).
---
--- PRECONDITION (found + documented during code review): `payload.emissionId` MUST be unique
--- across all currently-live sources -- this function does NOT check for or clean up a prior
--- grid-cell placement of the same id. Calling this twice with the same emissionId at two
--- different positions would leave a stray, permanently-orphaned entry in the OLD cell's bucket
--- (InsertSourceIntoGridCell is purely additive; only the newest position is ever visible via
--- `liveSources[id]`, and eviction/removal always computes the cell from the LATEST stored
--- position, never the stale one). This is currently unreachable in production: the sole caller
--- (DisturbanceService:Emit()) always mints a fresh HttpService:GenerateGUID(false) per call
--- (Story 002, GDD E.20's "collision probability effectively zero" guardrail) and never accepts
--- a caller-supplied id. If a future caller ever relaxes that guarantee, this function will need
--- a duplicate-id guard (remove the old grid entry before inserting the new one) -- not added
--- here per the story's own "do not over-engineer" guidance for an unreachable case.
---
--- PERFORMANCE NOTE: `liveCount` below is a full linear scan over `liveSources` on EVERY call,
--- not just when near the cap -- distinct from (and in addition to) FindOldestSourceId's own
--- O(N) scan, which the story text pre-approved but scoped only to the cap-triggered lookup.
--- Accepted as-is per the story's "do not over-engineer... not the hot path" framing and the
--- H.36 steady-state expectation (~207 of 500 sources) -- if Story 017's profiling shows this
--- unconditional scan is load-bearing, replace with a maintained counter on
--- DisturbanceService's own state rather than optimizing this pure function in isolation.
---
--- Returns (evictedInfo, updatedNextSequence): `evictedInfo` is nil if no eviction occurred;
--- the caller must store `updatedNextSequence` back into its own counter for the next call.
function DisturbanceServiceSpatialGridLogic.InsertEmission(
	grid: SpatialGrid,
	liveSources: { [string]: MinimalSource },
	insertionSequence: { [string]: number },
	nextSequence: number,
	maxLiveSources: number,
	payload: MinimalSource,
	cellSize: number?
): (EvictedSourceInfo?, number)
	local liveCount = 0
	for _ in liveSources do
		liveCount += 1
	end

	local evicted: EvictedSourceInfo? = nil
	if liveCount >= maxLiveSources then
		evicted = DisturbanceServiceSpatialGridLogic.EvictOldestSource(grid, liveSources, insertionSequence, cellSize)
	end

	local cellX, cellZ = DisturbanceServiceSpatialGridLogic.CellCoordFor(payload.position, cellSize)
	DisturbanceServiceSpatialGridLogic.InsertSourceIntoGridCell(grid, cellX, cellZ, payload.emissionId)
	liveSources[payload.emissionId] = payload
	insertionSequence[payload.emissionId] = nextSequence

	return evicted, nextSequence + 1
end

return DisturbanceServiceSpatialGridLogic
