--!strict
-- DisturbanceServiceBootstrapLogic
--
-- Implements: production/epics/ecological-disturbance/story-001-constants-bootstrap-field-update-loop.md
-- GDD: design/gdd/ecological-disturbance.md -- G.7 (SPATIAL_GRID_CELL_SIZE >= INFLUENCE_RADIUS
--      invariant), C.1.13 (Heartbeat catch-up / graceful-skip semantics)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md (N8 -- graceful-skip
--      catch-up triggers an ops-log emission; the ops-log itself is Story 017's scope, this
--      module only provides the accumulator math the log will later observe)
--      docs/architecture/adr-0005 (KnitInit-time config-validation hard-error convention this
--      module's predicates are wrapped by)
--
-- Pure domain logic for DisturbanceService's config-validation gates (H.3d/H.3e) and its
-- field-update Heartbeat accumulator (C.1.13). Deliberately has ZERO dependency on Knit or
-- any Roblox service call, so it can be required and unit-tested directly under Lune without
-- a live RunService.Heartbeat connection or a vendored Knit package.
-- DisturbanceService.luau is a thin Knit wrapper around these functions -- it owns the
-- RunService.Heartbeat connection itself, the KnitInit/KnitStart container construction, and
-- the game-facing error() call sites; this module owns the actual predicate/accumulator math.

local DisturbanceServiceBootstrapLogic = {}

-- ============================================================================
-- H.3d / H.3e -- KnitInit config-validation gates
-- ============================================================================

--- H.3d: INFLUENCE_RADIUS must be strictly positive. Returns (true) if valid, or
--- (false, message) if not. Pure -- never errors itself; DisturbanceService wraps this in a
--- KnitInit-time error() hard-stop, per ADR-0005's binding "config-validation hard error MUST
--- pair with a bootstrap catch -> Shutdown" rule (control-manifest.md, Foundation Layer).
function DisturbanceServiceBootstrapLogic.ValidateInfluenceRadius(influenceRadius: number): (boolean, string?)
	if influenceRadius <= 0 then
		return false, ("DisturbanceService: INFLUENCE_RADIUS misconfigured: %.2f <= 0"):format(influenceRadius)
	end
	return true, nil
end

--- H.3e: SPATIAL_GRID_CELL_SIZE must be >= INFLUENCE_RADIUS (the G.7 invariant). Exactly-equal
--- PASSES; strictly-less FAILS.
function DisturbanceServiceBootstrapLogic.ValidateSpatialGridCellSize(
	spatialGridCellSize: number,
	influenceRadius: number
): (boolean, string?)
	if spatialGridCellSize < influenceRadius then
		return false,
			("DisturbanceService: SPATIAL_GRID_CELL_SIZE (%.1f) < INFLUENCE_RADIUS (%.1f) -- violates G.7 invariant")
				:format(spatialGridCellSize, influenceRadius)
	end
	return true, nil
end

-- ============================================================================
-- C.1.13 -- Heartbeat accumulator, graceful-skip catch-up semantics
-- ============================================================================

--- Given the current accumulator value, a Heartbeat dt, and the configured update interval
--- (1 / FIELD_UPDATE_HZ), returns the new accumulator value and whether the update pass
--- should fire THIS callback.
---
--- Fires AT MOST ONCE per call, regardless of how far `accumulator + dt` exceeds `interval`
--- -- if it fires, the returned accumulator is reset to 0, discarding any residual debt
--- (C.1.13, REQUIRED). Catch-up loops (looping internally to fire 2-3 times when dt is large)
--- are FORBIDDEN by the story's own AC; this function's single `if` (not `while`) is what
--- structurally guarantees that -- there is no code path that can fire more than once per call.
function DisturbanceServiceBootstrapLogic.StepAccumulator(
	accumulator: number,
	dt: number,
	interval: number
): (number, boolean)
	local newAccumulator = accumulator + dt
	if newAccumulator >= interval then
		return 0, true
	end
	return newAccumulator, false
end

return DisturbanceServiceBootstrapLogic
