--!strict
-- PlayerControllerLanternLogic
--
-- Pure domain logic for PlayerControllerService's lantern axis (S3a/S3b) and
-- the light-to-gather gate. Deliberately has ZERO dependency on Knit or any
-- Roblox service call, so it can be required and unit-tested directly under
-- TestEZ/Lemur without a vendored Knit package or a live Roblox environment.
-- `PlayerControllerService.luau` is a thin Knit wrapper around these
-- functions -- it owns Player identity, RemoteEvent wiring, and per-player
-- table lifecycle; this module owns the actual state-machine rules.
--
-- Implements: production/epics/player-controller/story-002-lantern-gather-gate.md
-- GDD: design/gdd/player-controller.md -- C.3.6 (light-to-gather gate),
--      C.7 (tap-hold gather), C.9 (RequestLanternToggle surface),
--      C.11 (clock-injection seam contract)
-- ADR: docs/architecture/adr-0006-remoteevent-trust-boundary.md (canonical
--      6-step order this module implements steps 2 and 6 of)
--
-- SCOPE NOTE: this story does NOT implement Story 001 (locomotion/sprint) or
-- Story 003 (disturbance emission). `PlayerState.locomotion` is an opaque
-- stub field Story 001 will populate -- this module never reads or writes
-- it. `PlayerState.t_lastGracePulse_light` is likewise forward-declared for
-- Story 003 -- no function in this module ever assigns it; this module only
-- has to prove a dropped/same-state request cannot touch it (H.74), which
-- trivially holds since nothing here writes it at all.

local LanternLogic = {}

-- ============================================================================
-- Types
-- ============================================================================

export type LanternState = "S3a" | "S3b"

export type GatherInProgress = {
	nodeId: string,
	isDarkZoneScoped: boolean, -- captured at arm-time; the lanternRaised precondition
	-- must hold for the WHOLE tap-hold in a dark zone, not just at arm time (H.89)
	armedAt: number,
}

export type PlayerState = {
	lantern: LanternState,
	t_lastGracePulse_light: number?, -- Story 003 owns writes; never written here
	gatherInProgress: GatherInProgress?,
	locomotion: string?, -- Story 001 owns writes; never read or written here
}

export type TumblingWindow = {
	count: number,
	windowStart: number,
}

export type LanternRateLimitRecord = {
	perSecond: TumblingWindow,
	burst: TumblingWindow,
}

-- ============================================================================
-- Config knobs (data-driven: named + centralized here, not scattered magic
-- numbers in logic -- the values every check in this module reads).
-- ============================================================================

LanternLogic.LANTERN_VISIBILITY_RADIUS = 20 -- studs; GDD C.3.6 reveal/identify radius
LanternLogic.GATHER_PROXIMITY_RADIUS = 4 -- studs; GDD C.3.6/C.7 arm/gather radius

LanternLogic.LANTERN_TOGGLE_RATE_LIMIT_PER_SEC = 5 -- GDD C.9 RequestLanternToggle
LanternLogic.LANTERN_TOGGLE_BURST_CAP = 8 -- GDD C.9 round-20 NET-B1
LanternLogic.LANTERN_TOGGLE_BURST_WINDOW_SEC = 2.0

LanternLogic.GLOBAL_REMOTE_EVENT_BUDGET_PER_SEC = 30 -- ADR-0006 project-wide global per-player budget

LanternLogic.TAP_HOLD_COMMIT_DURATION = 0.5 -- seconds; GDD C.7 -- wall-clock only, never frame-count

-- ============================================================================
-- Construction
-- ============================================================================

--- Returns a freshly-initialized per-player state table. Lantern starts
--- lowered (S3a) per the GDD's default spawn state.
function LanternLogic.NewPlayerState(): PlayerState
	return {
		lantern = "S3a",
		t_lastGracePulse_light = nil,
		gatherInProgress = nil,
		locomotion = nil,
	}
end

-- ============================================================================
-- H.88(b) -- config validation
-- ============================================================================

--- Pure validity check for the DC-5 coupled-knob invariant: a node must
--- never be gatherable-but-unrevealed. Returns (true) if valid, or
--- (false, message) if not. The Knit service wraps this in a KnitInit-time
--- `error()` hard-stop; this function itself never errors, to stay testable.
function LanternLogic.ValidateConfig(gatherProximityRadius: number, lanternVisibilityRadius: number): (boolean, string?)
	if gatherProximityRadius >= lanternVisibilityRadius then
		return false,
			(
				"GATHER_PROXIMITY_RADIUS (%d) must be < LANTERN_VISIBILITY_RADIUS (%d) -- "
				.. "a node must never be gatherable-but-unrevealed (H.88b, GDD C.3.6 coupled-knob invariant)."
			):format(gatherProximityRadius, lanternVisibilityRadius)
	end
	return true, nil
end

-- ============================================================================
-- H.84 Part 1 -- C.3.6 light-to-gather gate arm predicate
-- ============================================================================

--- Pure, O(1), no hidden state. In a dark zone, arming requires the lantern
--- to be raised. In an ambient-lit zone, the gate is always armable
--- regardless of lantern state.
function LanternLogic.C3_6_CanArmGather(lanternRaised: boolean, isDarkZone: boolean): boolean
	if not isDarkZone then
		return true
	end
	return lanternRaised
end

-- ============================================================================
-- ADR-0006 step 2 / step 3 -- tumbling-window rate limiting
-- ============================================================================

--- Generic tumbling-window peek-then-commit: resets the window if expired,
--- then either rejects (no mutation) if at/over cap, or accepts and
--- increments. A rejected check never partially mutates the window.
local function _tryConsumeWindow(record: TumblingWindow, now: number, windowSeconds: number, cap: number): boolean
	if (now - record.windowStart) >= windowSeconds then
		record.count = 0
		record.windowStart = now
	end
	if record.count >= cap then
		return false
	end
	record.count += 1
	return true
end

--- ADR-0006 step 3: per-player global RemoteEvent budget (30/s, tumbling
--- 1.0s window). Incremented only on events that reach this check having
--- already passed the per-event rate limit (step 2), per ADR-0006's own
--- wording -- the caller is responsible for calling this only after step 2
--- passes.
function LanternLogic.CheckGlobalBudget(record: TumblingWindow, now: number): boolean
	return _tryConsumeWindow(record, now, 1.0, LanternLogic.GLOBAL_REMOTE_EVENT_BUDGET_PER_SEC)
end

--- ADR-0006 step 2 for RequestLanternToggle: BOTH the per-second sustained
--- rate (5/s) AND the burst cap (8 per 2.0s) must pass. Peeks both windows
--- before committing either -- a request that fails either check must not
--- partially consume the other's budget (H.74's "no state mutation on
--- drop" rule applied to the rate-limit counters themselves).
function LanternLogic.CheckLanternToggleRateLimit(record: LanternRateLimitRecord, now: number): boolean
	if (now - record.perSecond.windowStart) >= 1.0 then
		record.perSecond = { count = 0, windowStart = now }
	end
	if (now - record.burst.windowStart) >= LanternLogic.LANTERN_TOGGLE_BURST_WINDOW_SEC then
		record.burst = { count = 0, windowStart = now }
	end

	if record.perSecond.count >= LanternLogic.LANTERN_TOGGLE_RATE_LIMIT_PER_SEC then
		return false
	end
	if record.burst.count >= LanternLogic.LANTERN_TOGGLE_BURST_CAP then
		return false
	end

	record.perSecond.count += 1
	record.burst.count += 1
	return true
end

-- ============================================================================
-- H.89 -- mid-gather lantern-lower cancel (forward seam)
-- ============================================================================
--
-- FORWARD SEAM (approved architecture decision, Story 002 review 2026-07-06):
-- no C->S "start hold" RemoteEvent exists anywhere in the GDD -- C.7's
-- tap-hold flow is fully client-predicted until commit (RequestGather), and
-- the proximity-gate flow's GatherNodeArmed/GatherNodeDisarmed are RN-owned
-- S->C events, not a C->S "start" signal. BeginGatherHold/TryCommitGatherHold
-- are the future integration points a later story (PC's own tap-hold wiring,
-- or the RN epic's RequestGather receive-side) will call at the real arm/
-- commit moments. This story exercises them directly (from the Knit service
-- wrapper's own public methods, and from tests) rather than inventing a new
-- RemoteEvent, per explicit user ruling.

--- Records a gather hold as in-progress, subject to the C3_6_CanArmGather
--- gate. `isDarkZone` is captured once, at arm time, as `isDarkZoneScoped` --
--- this is what makes the mid-hold cancel dark-zone-scoped-only (H.89).
function LanternLogic.BeginGatherHold(state: PlayerState, nodeId: string, isDarkZone: boolean, now: number): boolean
	if not LanternLogic.C3_6_CanArmGather(state.lantern == "S3b", isDarkZone) then
		return false
	end
	state.gatherInProgress = {
		nodeId = nodeId,
		isDarkZoneScoped = isDarkZone,
		armedAt = now,
	}
	return true
end

--- Simulates the guard the future RequestGather handler will run at its own
--- step 5/6: rejects if the record was cancelled, never armed, or the
--- nodeId doesn't match. Proves H.89's "zero RequestGather completes"
--- invariant without a live RequestGather handler existing in this story.
function LanternLogic.TryCommitGatherHold(state: PlayerState, nodeId: string): boolean
	if not state.gatherInProgress then
		return false
	end
	if state.gatherInProgress.nodeId ~= nodeId then
		return false
	end
	state.gatherInProgress = nil
	return true
end

--- Cancels an in-progress gather ONLY if it was dark-zone-scoped at arm
--- time. An ambient-lit-zone hold is untouched by a lantern-lower (H.89's
--- "dark-zone-scoped only" contrast case).
function LanternLogic.CancelGatherIfDarkZoneLanternLowered(state: PlayerState): ()
	if not state.gatherInProgress then
		return
	end
	if state.gatherInProgress.isDarkZoneScoped then
		state.gatherInProgress = nil
	end
end

-- ============================================================================
-- ADR-0006 step 6 -- deep/domain validation + transition for RequestLanternToggle
-- ============================================================================

--- Given a request that already passed steps 1-5, applies the lantern
--- same-state debounce (H.74) and the accepted-path transition, including
--- the H.89 mid-gather-cancel side effect on a lower (S3b -> S3a)
--- transition. Returns (accepted, reason?) -- `reason` is nil on accept,
--- otherwise a short machine-readable drop reason (for test/debug
--- observability only -- production never surfaces this to the client,
--- per ADR-0006's silent-drop convention).
function LanternLogic.HandleLanternToggleDomain(state: PlayerState, raised: boolean): (boolean, string?)
	local requestedState: LanternState = if raised then "S3b" else "S3a"

	-- Same-state debounce (H.74): dropped BEFORE any side-effect, including
	-- a read/write of t_lastGracePulse_light. Note this function never
	-- writes t_lastGracePulse_light on ANY path, accepted or not -- that
	-- field is Story 003's to populate on a real grace-exempt pulse.
	if state.lantern == requestedState then
		return false, "same-state-debounced"
	end

	state.lantern = requestedState

	if requestedState == "S3a" then
		LanternLogic.CancelGatherIfDarkZoneLanternLowered(state)
	end

	return true, nil
end

return LanternLogic
