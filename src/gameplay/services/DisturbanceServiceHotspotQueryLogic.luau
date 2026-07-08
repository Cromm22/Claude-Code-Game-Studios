--!strict
-- DisturbanceServiceHotspotQueryLogic
--
-- Implements: production/epics/ecological-disturbance/story-008-hottest-hotspot-query.md
-- GDD: design/gdd/ecological-disturbance.md -- D.6 (GetHottestHotspot scoring/dedup/
--      non-finite-disqualification algorithm, verbatim pseudocode), the topContributorsAt
--      contract (round-7a R7-B10 -- non-nil HotspotResult implies #topContributingEmissionIds
--      >= 1), TR-ed-004 (HotspotResult exactly-6-field contract, hotspotId stable %d_%d
--      cellKey), TR-ed-046 (caller-supplied position, nil-recovery)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md -- N11 (hotspot.id
--      tie-break uses Luau's native string `<`, byte-lexicographic -- documented on
--      HotspotResult.hotspotId below for Predator AI implementers, NOT implemented here --
--      the tie-break itself is Predator AI's own consume-side logic, AC H.8)
--
-- Pure domain logic for GetHottestHotspot's candidate scoring/dedup/non-finite-disqualification
-- algorithm and topContributorsAt's per-position contributor ranking. Deliberately has ZERO
-- dependency on Knit, any Roblox service call, OR any require() at all (mirrors
-- DisturbanceServiceDecayFalloffLogic/DisturbanceServiceSpatialGridLogic's own zero-require
-- precedent from Stories 003/005), so it can be required and unit-tested directly under Lune.
-- DisturbanceService.luau is a thin Knit wrapper around this module's functions -- it owns the
-- real self._spatialGrid/self._liveSources/self._decayCache reads and composes
-- DisturbanceServiceSpatialGridLogic + DisturbanceServiceDecayFalloffLogic to build the
-- `fieldValueFn`/`topContributorsFn`/`dist2DSquaredFn` callbacks this module's GetHottestHotspot
-- takes as parameters (see CALLBACK-INJECTION DESIGN note below).
--
-- CALLBACK-INJECTION DESIGN (design call, approved 2026-07-08 -- mirrors
-- DisturbanceServiceDecayFalloffLogic's own CANDIDATE ENUMERATION OWNERSHIP precedent, applied
-- one level further): GetHottestHotspot's D.6 pseudocode step 3 calls `fieldValue(C)` and step 4
-- calls `topContributorsAt(bestPosition, 3)` -- both of which are themselves compositions of
-- DisturbanceServiceSpatialGridLogic's grid-query primitives with
-- DisturbanceServiceDecayFalloffLogic's decay/falloff math (exactly what DisturbanceService
-- .luau's own `fieldValue()` method already does). Rather than require() either sibling module
-- directly (unresolvable via `script.Parent` under this project's loadstring-based Lune test
-- harness -- the same landmine DisturbanceServiceDecayFalloffLogic's own header documents), this
-- module accepts `fieldValueFn: (Vector3) -> number`, `topContributorsFn: (Vector3) -> ({string},
-- number)`, and `dist2DSquaredFn: (Vector3, Vector3) -> number` as caller-injected callbacks.
-- DisturbanceService.luau's real GetHottestHotspot wrapper binds these to its own
-- `self:fieldValue`, `self:_topContributorsAt`, and `DecayFalloffLogic.dist2DSquared`
-- respectively -- satisfying this story's "call into Story 005's math, do not reimplement it"
-- instruction via genuine function-object reuse, not formula duplication.
--
-- SPATIAL-GRID QUERY-PRIMITIVE NOTE (flagged, not silently resolved -- see this story's final
-- report for the full discrepancy writeup): ADR-0004's Decision text states GetHottestHotspot's
-- cell scan "iterates grid[cellX +/-1][cellZ +/-1]" (the same fixed 3x3 neighborhood
-- `fieldValue()` uses for its fixed INFLUENCE_RADIUS=24 studs). The GDD's own D.6 pseudocode,
-- however, calls for enumerating grid cells intersecting a circle of radius `searchRadius`
-- around `callerPosition` (`liveSourcesInGridCellsIntersecting`) -- and Predator AI's documented
-- searchRadius range is 32-512 studs, far exceeding a fixed 3x3/96-stud footprint at 32-stud
-- cells. This module does not itself perform grid enumeration (see the design note above) --
-- DisturbanceService.luau's real wrapper is responsible for supplying `rawCandidatePositions`
-- via a NEW `DisturbanceServiceSpatialGridLogic.QueryCellsInRadius` primitive (general
-- cell-range query, not the fixed 3x3 `QueryNeighborhood`) rather than reusing `QueryNeighborhood`
-- for this step. `QueryNeighborhood` IS still the correct primitive for `topContributorsAt`
-- (which genuinely operates on the fixed `INFLUENCE_RADIUS`, matching the ADR's language for
-- that sub-step specifically).

--- The canonical Tier union (duplicated here, not require()d, matching
--- DisturbanceServiceDecayFalloffLogic's own EmissionType duplication precedent for the
--- identical zero-require reason -- keep in sync by hand if the GDD's Tier union ever changes).
export type Tier = "Calm" | "Tense" | "Hunt" | "Retreat"

--- The minimal structural shape this module needs from a live source record for
--- topContributorsAt's age/contribution computation. The real
--- DisturbanceServiceDecayFalloffLogic.DecayableSource satisfies this structurally (superset).
export type ContributorSource = {
	position: Vector3,
	emissionTime: number,
}

--- Mirrors DisturbanceServiceDecayFalloffLogic.DecayCacheEntry's shape (duplicated, not
--- require()d -- same zero-require precedent).
export type ContributorDecayCacheEntry = {
	magnitude: number,
	expired: boolean,
}

--- The public HotspotResult contract (TR-ed-004 / C.3.3). All six fields are required
--- (non-optional) whenever a HotspotResult is returned; GetHottestHotspot returns nil instead of
--- ever constructing a partially-populated result.
export type HotspotResult = {
	position: Vector3,
	fieldValue: number,
	--- Stable hotspot identity -- the D.6 dedup cellKey of `position`
	--- (`string.format("%d_%d", floor(X/k), floor(Z/k))`, k = HOTSPOT_DEDUP_GRID_SIZE). Stable
	--- across successive queries while the winning dedup cell is unchanged, even when the
	--- representative `position` within the cell shifts (first-encountered-source turnover).
	--- PREDATOR AI TIE-BREAK NOTE (ADR-0004 N11, documented here per this story's own
	--- instruction so Predator AI implementers never re-derive a numeric-parse comparison):
	--- when Predator AI needs to break a tie between two hotspotId candidates, the comparison
	--- MUST use Luau's native string `<` operator (byte-lexicographic) on this field directly --
	--- NOT a numeric parse of the encoded cell coordinates. This module does not implement that
	--- tie-break itself (it is Predator AI's own consume-side logic, AC H.8) -- this doc comment
	--- exists solely so the convention is discoverable at the producer side of the contract.
	hotspotId: string,
	--- 1-3 emissionIds, ordered by contribution descending. Guaranteed `#list >= 1` whenever this
	--- HotspotResult is non-nil (round-7a R7-B10 contract).
	topContributingEmissionIds: { string },
	--- Count of distinct (post-dedup) candidate positions >= minimumTier within searchRadius.
	hotspotCount: number,
	--- Age in seconds of the oldest live contributor within INFLUENCE_RADIUS of `position`.
	--- Informational only -- computed across ALL in-range live contributors, not just the top-n
	--- returned in topContributingEmissionIds (per the GDD's own field doc: "age... of the oldest
	--- live source within INFLUENCE_RADIUS of bestPosition").
	oldestContributorAge: number,
}

local DisturbanceServiceHotspotQueryLogic = {}

-- ============================================================================
-- D.6 -- tierFloor selection: Calm=0.00, Tense=tenseThreshold, Hunt=huntThreshold, Retreat=1.00.
-- Retreat's 1.00 ceiling is D.3's own fieldValue clamp ceiling, not a separate registered G.1
-- tuning knob -- no RETREAT_THRESHOLD constant exists in DisturbanceConstants.luau.
-- ============================================================================

function DisturbanceServiceHotspotQueryLogic.TierLowerBound(minimumTier: string, tenseThreshold: number, huntThreshold: number): number
	if minimumTier == "Calm" then
		return 0.0
	elseif minimumTier == "Tense" then
		return tenseThreshold
	elseif minimumTier == "Hunt" then
		return huntThreshold
	elseif minimumTier == "Retreat" then
		return 1.0
	end
	error(("DisturbanceServiceHotspotQueryLogic.TierLowerBound: unrecognized minimumTier %s"):format(tostring(minimumTier)))
end

-- ============================================================================
-- D.6 -- Dedup snap-method (canonical). MUST use string.format, never a tuple-as-table-key
-- (invalid Luau -- see this story's own Implementation Notes header for the exact hazard).
-- ============================================================================

--- Computes the floor-snap dedup cellKey for `position` at `dedupGridSize`-stud resolution.
--- Cited verbatim from this story's own Implementation Notes (D.6 "Dedup snap-method").
function DisturbanceServiceHotspotQueryLogic.DedupCellKey(position: Vector3, dedupGridSize: number): string
	return string.format("%d_%d", math.floor(position.X / dedupGridSize), math.floor(position.Z / dedupGridSize))
end

--- De-duplicates `candidatePositions` by floor-snapping each to a `dedupGridSize`-stud grid cell.
--- The retained position for each unique cellKey is the FIRST candidate encountered in
--- enumeration order (deterministic given deterministic source iteration order) -- NOT "best
--- within cell."
function DisturbanceServiceHotspotQueryLogic.DeduplicateByFloorSnap(candidatePositions: { Vector3 }, dedupGridSize: number): { Vector3 }
	local seen: { [string]: boolean } = {}
	local result: { Vector3 } = {}
	for _, position in candidatePositions do
		local key = DisturbanceServiceHotspotQueryLogic.DedupCellKey(position, dedupGridSize)
		if not seen[key] then
			seen[key] = true
			table.insert(result, position)
		end
	end
	return result
end

-- ============================================================================
-- D.6 step 3 -- candidate scoring loop, cited VERBATIM from this story's own Implementation
-- Notes: non-finite disqualification (H.25c) happens BEFORE the tierFloor gate, so a
-- NaN/+Inf-scoring candidate never sets bestPosition and never increments hotspotCount.
-- ============================================================================

--- Scores each (already-deduplicated) candidate position via `fieldValueFn`, tracking the
--- highest-scoring candidate meeting `tierFloor` and the count of all candidates meeting it.
--- A candidate whose score evaluates non-finite (`score ~= score or score == math.huge`) is
--- disqualified entirely -- it is never counted toward hotspotCount and can never win
--- bestPosition, regardless of its (fabricated) magnitude.
---
--- ASYMMETRIC REACHABILITY NOTE (code review, 2026-07-08): via the real, production
--- `fieldValueFn` (DisturbanceServiceDecayFalloffLogic.FieldValueAt), only the NaN branch of
--- this guard is actually reachable end-to-end -- FieldValueAt's own `math.min(total, 1.0)`
--- clamp always converts a legitimately-or-corruptly-overflowing total into a finite `1.0`
--- before it would ever reach this check, so `score == math.huge` never fires against the real
--- composed path today. This is not a safety gap (clamping a corrupted +Inf source to `1.0` is
--- already the maximum, Retreat-tier severity -- at least as conservative as disqualifying it),
--- but the `+math.huge` branch here is currently defense-in-depth against a hypothetical future
--- `fieldValueFn` implementation that does not clamp before returning, not something exercised
--- by the current DecayFalloffLogic-backed path.
---
--- Returns (bestPosition, bestScore, hotspotCount); bestPosition is nil (bestScore/hotspotCount
--- are then meaningless) when no candidate meets tierFloor.
function DisturbanceServiceHotspotQueryLogic.ScoreCandidates(
	candidatePositions: { Vector3 },
	tierFloor: number,
	fieldValueFn: (Vector3) -> number
): (Vector3?, number, number)
	local bestPosition: Vector3? = nil
	local bestScore = -1
	local hotspotCount = 0

	for _, C in candidatePositions do
		local score = fieldValueFn(C)
		if score ~= score or score == math.huge then
			continue -- non-finite: disqualify (H.25c)
		end
		if score >= tierFloor then
			hotspotCount += 1
			if score > bestScore then
				bestScore, bestPosition = score, C
			end
		end
	end

	return bestPosition, bestScore, hotspotCount
end

-- ============================================================================
-- topContributorsAt -- per-position contributor ranking (D.6 step 4's own sub-procedure).
-- Contract (round-7a R7-B10): P with zero live contributors -> ({}, 0). P with >=1 live
-- contributor -> at least 1 emissionId in slot 1.
-- ============================================================================

--- Ranks the live, non-expired sources present in `candidateSourceIds` (an ALREADY-QUERIED
--- candidate id list -- see this module's own CALLBACK-INJECTION DESIGN header note for why this
--- function never touches the spatial grid directly) by their D.2 contribution to `position`,
--- descending. Ties are broken by `emissionId` ascending (native Luau string `<`,
--- byte-lexicographic -- mirrors the ADR-0004 N11 convention used for hotspotId comparisons,
--- applied here purely for this function's own determinism, not because Predator AI reads this
--- ordering). Returns the top-`n` emissionIds and the maximum age (in seconds, via
--- `now - emissionTime`, clamped at 0) across ALL in-range live contributors -- not just the
--- top-`n` returned -- matching the GDD's own `oldestContributorAge` field doc ("age... of the
--- oldest live source within INFLUENCE_RADIUS of bestPosition").
--- `dist2DFn`/`contributionFn` are injected (caller passes
--- DisturbanceServiceDecayFalloffLogic.dist2D / .Contribution) -- see this module's own
--- CALLBACK-INJECTION DESIGN header note.
function DisturbanceServiceHotspotQueryLogic.TopContributorsAt(
	position: Vector3,
	n: number,
	candidateSourceIds: { string },
	liveSources: { [string]: ContributorSource },
	decayCache: { [string]: ContributorDecayCacheEntry },
	influenceRadius: number,
	now: number,
	dist2DFn: (Vector3, Vector3) -> number,
	contributionFn: (number, number, number) -> number
): ({ string }, number)
	local entries: { { emissionId: string, contribution: number, age: number } } = {}
	local maxAge = 0

	for _, emissionId in candidateSourceIds do
		local source = liveSources[emissionId]
		local cached = decayCache[emissionId]
		if source and cached and not cached.expired then
			local distance = dist2DFn(position, source.position)
			if distance <= influenceRadius then
				local contribution = contributionFn(cached.magnitude, distance, influenceRadius)
				local age = math.max(0, now - source.emissionTime)
				table.insert(entries, { emissionId = emissionId, contribution = contribution, age = age })
				if age > maxAge then
					maxAge = age
				end
			end
		end
	end

	if #entries == 0 then
		return {}, 0
	end

	table.sort(entries, function(a, b)
		if a.contribution ~= b.contribution then
			return a.contribution > b.contribution
		end
		return a.emissionId < b.emissionId
	end)

	local topIds: { string } = {}
	for i = 1, math.min(n, #entries) do
		table.insert(topIds, entries[i].emissionId)
	end

	return topIds, maxAge
end

-- ============================================================================
-- GetHottestHotspot -- the full D.6 orchestration, cited verbatim from this story's own
-- Implementation Notes. `rawCandidatePositions` is the ALREADY-grid-cell-queried (but NOT yet
-- searchRadius-culled) list of live-source positions from
-- `liveSourcesInGridCellsIntersecting(callerPosition, searchRadius)` -- this module performs the
-- searchRadius cull (step 1's inner `if`), the dedup (step 2), the scoring (step 3), and the
-- final result construction (step 4), all as pure functions of its inputs.
-- ============================================================================

--- `secondBestPosition` is explicitly NOT implemented (removed for MVP per the GDD -- no
--- flank/distract mechanic at launch). This function does NOT invoke
--- PathfindingService:FindPathAsync -- that is entirely Predator AI's scope (TR-ed-034); this
--- function only ever supplies `position` as a navigation target.
function DisturbanceServiceHotspotQueryLogic.GetHottestHotspot(
	callerPosition: Vector3,
	searchRadius: number,
	minimumTier: string,
	rawCandidatePositions: { Vector3 },
	tenseThreshold: number,
	huntThreshold: number,
	dedupGridSize: number,
	dist2DSquaredFn: (Vector3, Vector3) -> number,
	fieldValueFn: (Vector3) -> number,
	topContributorsFn: (Vector3) -> ({ string }, number)
): HotspotResult?
	local tierFloor = DisturbanceServiceHotspotQueryLogic.TierLowerBound(minimumTier, tenseThreshold, huntThreshold)

	local radiusSquared = searchRadius * searchRadius
	local candidatePositions: { Vector3 } = {}
	for _, sourcePosition in rawCandidatePositions do
		if dist2DSquaredFn(callerPosition, sourcePosition) <= radiusSquared then
			table.insert(candidatePositions, sourcePosition)
		end
	end

	candidatePositions = DisturbanceServiceHotspotQueryLogic.DeduplicateByFloorSnap(candidatePositions, dedupGridSize)

	local bestPosition, bestScore, hotspotCount =
		DisturbanceServiceHotspotQueryLogic.ScoreCandidates(candidatePositions, tierFloor, fieldValueFn)

	if bestPosition == nil then
		return nil
	end

	local topEmissions, oldestContributorAge = topContributorsFn(bestPosition)

	return {
		position = bestPosition,
		fieldValue = bestScore,
		hotspotId = DisturbanceServiceHotspotQueryLogic.DedupCellKey(bestPosition, dedupGridSize),
		topContributingEmissionIds = topEmissions,
		hotspotCount = hotspotCount,
		oldestContributorAge = oldestContributorAge,
	}
end

return DisturbanceServiceHotspotQueryLogic
