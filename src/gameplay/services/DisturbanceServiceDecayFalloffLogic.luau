--!strict
-- DisturbanceServiceDecayFalloffLogic
--
-- Implements: production/epics/ecological-disturbance/story-005-decay-falloff-fieldvalue.md
-- GDD: design/gdd/ecological-disturbance.md -- D.1 (magnitude decay formula), D.2 (spatial
--      falloff / contribution formula), D.3 (fieldValue() aggregation), TR-ed-017 (per-source
--      decay caching, math.exp <= once per source per pass), TR-ed-018 (forbidden
--      transcendentals in the inner contribution loop; squared-distance cull before sqrt)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md -- "Spatial data
--      structure" Decision subsection: fieldValue()'s candidate enumeration "iterates
--      grid[cellX +/-1][cellZ +/-1] around the query point, exactly matching the GDD's own
--      implementation note" -- this module's FieldValueAt takes an ALREADY-QUERIED candidate id
--      list (see CANDIDATE ENUMERATION OWNERSHIP note below for why), never the raw grid table.
--
-- Pure domain logic for decay-magnitude computation, per-pass decay caching, the 2D
-- distance/falloff/contribution math, and fieldValue() aggregation over a caller-supplied
-- candidate list. Deliberately has ZERO dependency on Knit, any Roblox service call, OR any
-- require() at all (mirrors DisturbanceServiceBootstrapLogic / DisturbanceServiceEmissionLogic /
-- DisturbanceServiceSpatialGridLogic / DisturbanceServiceAttributionArchiveLogic's own
-- zero-require precedent from Stories 001-004), so it can be required and unit-tested directly
-- under Lune. DisturbanceService.luau is a thin Knit wrapper around this module's functions -- it
-- owns the real self._liveSources/self._decayCache state tables, the real
-- workspace:GetServerTimeNow() clock sample, the self._expFn injection point (_setExpFn test
-- seam), and the real SpatialGridLogic.CellCoordFor/QueryNeighborhood calls that produce the
-- candidate id list FieldValueAt consumes.
--
-- CANDIDATE ENUMERATION OWNERSHIP (design call, approved 2026-07-06/07): D.3's prose describes
-- "using the spatial grid for candidate enumeration." This module does NOT re-implement
-- DisturbanceServiceSpatialGridLogic's CellCoordFor/QueryNeighborhood locally, and does NOT
-- require() that sibling module either -- require(script.Parent.X) is unresolvable for
-- loadstring-executed modules under tests/run_tests.lua's harness (no `script` global; the exact
-- landmine DisturbanceServiceEmissionLogic.luau's own header note already documents for
-- DisturbanceConstants). Instead, FieldValueAt takes an ALREADY-QUERIED `candidateSourceIds: {
-- string }` parameter -- the caller (DisturbanceService.luau's real fieldValue() wrapper, OR a
-- test that composes this module with the already-independently-tested SpatialGridLogic module
-- directly, exactly as attribution-archive-ttl-cap_test.luau's own cross-module composition
-- tests do) is responsible for calling SpatialGridLogic.CellCoordFor + QueryNeighborhood first.
-- This keeps the 3x3-neighborhood cell-scan implementation living in exactly ONE place
-- (DisturbanceServiceSpatialGridLogic.luau, "the seam Stories 005/008 call into" per that
-- module's own header) rather than duplicating it a second time here.
--
-- PER-SOURCE DECAY CACHE STORAGE (design call, matching this service's own established
-- convention): the decayed magnitude is NOT written back onto the live-source record itself.
-- It lives in a SEPARATE caller-owned parallel table keyed by emissionId (`DecayCache`),
-- mirroring DisturbanceServiceSpatialGridLogic's own insertionSequence and
-- DisturbanceServiceAttributionArchiveLogic's own referencingPlayers/insertionSequence
-- precedent -- never mutating the EmissionPayload record structure itself.

export type ExpFn = (number) -> number

--- EmissionType is DUPLICATED here (not require()d from DisturbanceServiceEmissionLogic), matching
--- DisturbanceServiceAttributionArchiveLogic's own EmissionType duplication precedent (Story 004)
--- for the identical zero-require reason. Keep in sync by hand if the enum ever changes.
export type EmissionType = "Gather" | "Sprint" | "Light" | "Beacon" | "Craft"

--- The minimal structural shape this module needs from a live source record. The real
--- DisturbanceServiceEmissionLogic.EmissionPayload satisfies this structurally (it is a superset
--- -- it also carries attributionChain, which this module never reads) -- this module never
--- require()s that module, matching the zero-require precedent explained above.
export type DecayableSource = {
	emissionId: string,
	sourcePlayerId: number,
	emissionType: EmissionType,
	position: Vector3,
	initialMagnitude: number,
	emissionTime: number,
}

--- One pass's cached decay result for a single source (TR-ed-017): the decayed magnitude at the
--- pass's `now`, and whether that magnitude is strictly below MAGNITUDE_FLOOR (the culling
--- signal a separate maintenance pass consumes -- this module never removes anything from
--- `liveSources` itself; see FindExpiredSourceIds below).
export type DecayCacheEntry = {
	magnitude: number,
	expired: boolean,
}

export type DecayCache = { [string]: DecayCacheEntry }

local DisturbanceServiceDecayFalloffLogic = {}

-- math.log(2) is computed ONCE at module load, not per-source-per-pass -- this is ordinary
-- module-scope constant folding, not part of TR-ed-018's "forbidden transcendentals in the
-- inner [contribution] loop" restriction, which is scoped to FieldValueAt/Contribution below
-- (the spatial-query path), not the decay-math path.
local LN2 = math.log(2)

-- ============================================================================
-- D.1 -- magnitude decay: m(t, age) = initialMagnitude x exp(-lambda x age), lambda = ln(2) / t_half
-- ============================================================================

--- Half-life selection (D.1): Beacon emissions decay on `beaconHalfLife`; every other emission
--- type (Gather/Sprint/Light, and -- per this story's own scope note below -- Craft) decays on
--- `standardHalfLife`.
---
--- SCOPE NOTE (assumption, flagged -- not silently invented): the story's AC text names only
--- "Gather/Sprint/Light" for the 30s standard half-life and "Beacon" for the 90s half-life; the
--- fifth EmissionType member, "Craft", is not mentioned by either AC. Interpreted here as
--- "everything that is not Beacon uses STANDARD_HALF_LIFE" (the natural reading of D.1's own
--- "t_half = 30s for Gather/Sprint/Light, 90s for Beacon" -- an exhaustive partition would leave
--- Craft with no half-life at all, which cannot be correct). Flagged in this story's final report
--- for confirmation rather than assumed silently.
function DisturbanceServiceDecayFalloffLogic.HalfLifeFor(
	emissionType: string,
	standardHalfLife: number,
	beaconHalfLife: number
): number
	if emissionType == "Beacon" then
		return beaconHalfLife
	end
	return standardHalfLife
end

--- age = max(0, serverTime - emissionTime). Clamped at 0 so a (should-be-impossible, but
--- defensively guarded) emissionTime in the future never produces a negative age.
function DisturbanceServiceDecayFalloffLogic.ComputeAge(now: number, emissionTime: number): number
	return math.max(0, now - emissionTime)
end

--- m(t, age) = initialMagnitude x expFn(-lambda x age). `expFn` defaults to `math.exp` when not
--- provided; DisturbanceService.luau's real caller always passes its own self._expFn (which
--- itself defaults to math.exp, swappable only via the server-internal _setExpFn test seam --
--- H.9b). Never clamps to MAGNITUDE_FLOOR itself -- the raw decayed value is always returned,
--- even below the floor; IsExpired (below) is a separate, non-mutating signal.
function DisturbanceServiceDecayFalloffLogic.ComputeDecayedMagnitude(
	initialMagnitude: number,
	age: number,
	halfLife: number,
	expFn: ExpFn?
): number
	local usedExpFn = expFn or math.exp
	local lambda = LN2 / halfLife
	return initialMagnitude * usedExpFn(-lambda * age)
end

--- D.1 / H.9 / H.10: expiry is STRICT less-than -- a magnitude exactly equal to `magnitudeFloor`
--- is NOT expired.
function DisturbanceServiceDecayFalloffLogic.IsExpired(magnitude: number, magnitudeFloor: number): boolean
	return magnitude < magnitudeFloor
end

-- ============================================================================
-- TR-ed-017 -- per-source decay caching: math.exp evaluated <=once per live source per pass.
-- ============================================================================

--- Recomputes every live source's decayed magnitude ONCE and writes the result into
--- `decayCache[emissionId]`, overwriting any prior-pass entry. Called once per field-update pass
--- (DisturbanceService.luau's KnitStart Heartbeat, at FIELD_UPDATE_HZ) -- NEVER per query. Every
--- fieldValue()/GetHottestHotspot() query within the same pass reads the cached value via
--- FieldValueAt below, which never touches `expFn` at all (H.9b's "re-run the same pass's
--- queries a second time ... exp count should not increase further" is satisfied by
--- construction: FieldValueAt has no expFn parameter).
function DisturbanceServiceDecayFalloffLogic.RunDecayPass(
	liveSources: { [string]: DecayableSource },
	decayCache: DecayCache,
	now: number,
	standardHalfLife: number,
	beaconHalfLife: number,
	magnitudeFloor: number,
	expFn: ExpFn?
): ()
	for emissionId, source in liveSources do
		local halfLife = DisturbanceServiceDecayFalloffLogic.HalfLifeFor(source.emissionType, standardHalfLife, beaconHalfLife)
		local age = DisturbanceServiceDecayFalloffLogic.ComputeAge(now, source.emissionTime)
		local magnitude =
			DisturbanceServiceDecayFalloffLogic.ComputeDecayedMagnitude(source.initialMagnitude, age, halfLife, expFn)

		decayCache[emissionId] = {
			magnitude = magnitude,
			expired = DisturbanceServiceDecayFalloffLogic.IsExpired(magnitude, magnitudeFloor),
		}
	end
end

--- H.9: returns the emissionIds of every live source whose MOST RECENT decay-cache entry is
--- expired (strictly below MAGNITUDE_FLOOR). Pure query -- does NOT remove anything from
--- `liveSources`/`decayCache` itself; DisturbanceService.luau's own low-frequency maintenance
--- pass (the "next maintenance pass... within EXPIRY_MAINTENANCE_INTERVAL" H.9's AC text refers
--- to) is the caller that actually tears the source down (live-source list, grid cell, decay
--- cache, insertion-sequence counter -- see that file's _cullExpiredSources for the full
--- multi-store orchestration, which needs DisturbanceServiceSpatialGridLogic's grid-removal
--- function too and therefore cannot live in this zero-require module).
function DisturbanceServiceDecayFalloffLogic.FindExpiredSourceIds(
	liveSources: { [string]: DecayableSource },
	decayCache: DecayCache
): { string }
	local expiredIds: { string } = {}
	for emissionId in liveSources do
		local cached = decayCache[emissionId]
		if cached and cached.expired then
			table.insert(expiredIds, emissionId)
		end
	end
	return expiredIds
end

-- ============================================================================
-- D.2 -- 2D (XZ-plane) distance helpers. Cited VERBATIM from this story's own Implementation
-- Notes (parameter names a/b, exact body) -- also exposed on the module table below for direct
-- testability (H.9c wraps math.sqrt around calls into dist2D specifically).
-- ============================================================================

local function dist2DSquared(a: Vector3, b: Vector3): number
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return dx * dx + dz * dz
end

local function dist2D(a: Vector3, b: Vector3): number
	return math.sqrt(dist2DSquared(a, b))
end

DisturbanceServiceDecayFalloffLogic.dist2DSquared = dist2DSquared
DisturbanceServiceDecayFalloffLogic.dist2D = dist2D

-- ============================================================================
-- D.2 -- contribution(P, S) = m(age) x max(0, 1 - dist2D(P,S) / INFLUENCE_RADIUS)^2
-- Squaring via explicit multiplication -- math.pow and the ^ operator are FORBIDDEN here (H.9c).
-- ============================================================================

--- `distance2D` is a PRE-COMPUTED dist2D(P, S) value (the caller, FieldValueAt below, computes
--- it at most once per candidate, only after the cheap dist2DSquared radius cull has passed).
function DisturbanceServiceDecayFalloffLogic.Contribution(cachedMagnitude: number, distance2D: number, influenceRadius: number): number
	local falloffLinear = math.max(0, 1 - distance2D / influenceRadius)
	return cachedMagnitude * (falloffLinear * falloffLinear)
end

-- ============================================================================
-- D.3 -- fieldValue(P) = min(1.0, sum of contribution(P, Si)) over live, non-expired candidates.
-- THE INNER CONTRIBUTION LOOP (H.9c's static-analysis target): dist2DSquared cull happens BEFORE
-- any dist2D (math.sqrt) call -- a candidate failing the cull triggers zero math.sqrt calls.
--
-- TESTABILITY NOTE: this loop calls `DisturbanceServiceDecayFalloffLogic.dist2DSquared`/`.dist2D`
-- THROUGH THE MODULE TABLE (not the bare local upvalues `dist2DSquared`/`dist2D` defined above),
-- deliberately -- Lune's `math` library table is READ-ONLY (`math.sqrt = ...` errors with
-- "attempt to modify a readonly table"), so H.9c's "counter wrapping math.sqrt" test cannot
-- monkey-patch the global `math.sqrt` directly under this project's Lune test harness. Routing
-- the call through the table lets a test swap `DisturbanceServiceDecayFalloffLogic.dist2D` for a
-- counting wrapper instead (dist2D always calls math.sqrt internally, so counting dist2D
-- invocations is equivalent to counting sqrt calls for this module's purposes) without touching
-- any read-only global. The exported dist2DSquared/dist2D functions themselves are unchanged
-- (still the verbatim Implementation Notes bodies) -- only the call site inside this loop was
-- changed from an upvalue reference to a table reference.
-- ============================================================================

--- `candidateSourceIds` is an ALREADY-QUERIED candidate list -- see this file's own
--- CANDIDATE ENUMERATION OWNERSHIP header note for why this module never touches the spatial
--- grid directly. Expired or since-evicted sources (missing from `liveSources`/`decayCache`, or
--- present but flagged `expired`) are silently skipped, never erroring.
function DisturbanceServiceDecayFalloffLogic.FieldValueAt(
	queryPosition: Vector3,
	candidateSourceIds: { string },
	liveSources: { [string]: DecayableSource },
	decayCache: DecayCache,
	influenceRadius: number
): number
	local radiusSquared = influenceRadius * influenceRadius
	local total = 0

	for _, sourceId in candidateSourceIds do
		local source = liveSources[sourceId]
		local cached = decayCache[sourceId]
		if source and cached and not cached.expired then
			-- TR-ed-018: cheap squared-distance cull BEFORE any math.sqrt call. A candidate that
			-- fails this cull never reaches dist2D/math.sqrt at all (H.9c edge case).
			local distanceSquared = DisturbanceServiceDecayFalloffLogic.dist2DSquared(queryPosition, source.position)
			if distanceSquared <= radiusSquared then
				local distance = DisturbanceServiceDecayFalloffLogic.dist2D(queryPosition, source.position)
				total += DisturbanceServiceDecayFalloffLogic.Contribution(cached.magnitude, distance, influenceRadius)
			end
		end
	end

	-- NaN-safety: argument order matters here. Luau's math.min(a, b) returns `a` whenever `b` is
	-- NaN (since NaN fails every comparison), so math.min(1.0, total) would silently launder a
	-- NaN `total` into a finite 1.0 -- the single WORST possible fail-quiet failure for this
	-- system, since 1.0 is Retreat-tier (maximum severity) and would make a corrupted source win
	-- hotspot selection outright instead of being disqualified. total MUST be the first argument
	-- so NaN propagates through the clamp for downstream finiteness guards (H.25c, GuardFinite) to
	-- catch. +math.huge is unaffected by argument order either way.
	return math.min(total, 1.0)
end

return DisturbanceServiceDecayFalloffLogic
