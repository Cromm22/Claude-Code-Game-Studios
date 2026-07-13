--!strict
-- PlayerControllerLocomotionStaminaLogic
--
-- Pure domain logic for PlayerControllerService's locomotion axis (S1 Walk /
-- S2 Sprint), server-authoritative stamina drain/regen, and the ghost-sprint
-- (PlayerHeartbeat staleness) guard. Deliberately has ZERO dependency on Knit
-- or any Roblox service call, so it can be required and unit-tested directly
-- under Lune without a vendored Knit package or a live Roblox environment --
-- matching the precedent PlayerControllerLanternLogic.luau established for
-- Story 002. `PlayerControllerService.luau` is a thin Knit wrapper around
-- these functions -- it owns Player identity, RemoteEvent wiring, Humanoid
-- side effects (`WalkSpeed`), and per-player table lifecycle; this module
-- owns the actual state-machine rules.
--
-- Implements: production/epics/player-controller/story-001-locomotion-sprint-stamina-authority.md
-- GDD: design/gdd/player-controller.md -- C.2/C.2.5 (sprint-state authority,
--      force-walk at zero stamina), C.9 (RequestSprintToggle/PlayerHeartbeat/
--      OnSprintStateChanged/OnStaminaChanged surface), D.1 (stamina drain),
--      D.2 (stamina regen, STAMINA_REGEN_DELAY strict `>` boundary), D.3
--      (T_sprint effective sprint duration), E.D (SPRINT_CLIENT_TIMEOUT
--      ghost-sprint guard), C.11 (clock-injection seam contract -- this
--      module never reads a clock itself; every timestamp is an explicit
--      `now` parameter, matching PlayerControllerLanternLogic's own
--      `BeginGatherHold(..., now)` precedent).
-- ADR: docs/architecture/adr-0011-player-controller-sprint-stamina-authority.md
--      (S1/S2 state machine, stamina tick, ghost-sprint watchdog -- this
--      module implements the ADR's Decision section as pure, testable
--      functions; the ADR's own Key Interfaces sample is illustrative
--      pseudocode, not a literal signature contract -- see the two
--      deviations noted below)
--      docs/architecture/adr-0006-remoteevent-trust-boundary.md (canonical
--      6-step order this module implements step 2 (CheckSprintToggleRateLimit
--      / CheckHeartbeatRateLimit) and step 6 (HandleSprintToggleDomain /
--      HandlePlayerHeartbeatDomain) of; step 3, the per-player GLOBAL budget,
--      is intentionally NOT duplicated here -- the Knit wrapper reuses the
--      existing self._globalEventCounts table + LanternLogic.CheckGlobalBudget,
--      since that budget is meant to be ONE shared counter across ALL of PC's
--      events, not a second independent one for this event)
--
-- Two deliberate deviations from the ADR's own illustrative Key Interfaces
-- sample (both reviewed and approved -- see story-001 implementation
-- session, 2026-07-06):
--   1. `GetMoveSpeed` takes `"S1"|"S2"` (the ADR's own bound `LocomotionState`
--      type), not the literal `"Walk"|"Sprint"` strings the story's H.1 prose
--      and QA Test Case section informally use -- the type is the binding
--      spec; the prose is descriptive English.
--   2. `HandleSprintToggleDomain` takes the real `{sprint: boolean}` payload
--      (GDD C.9) and same-state-debounces BOTH directions, matching
--      PlayerControllerLanternLogic's own `HandleLanternToggleDomain`
--      structure exactly (pc-2's own Implementation Notes explicitly say its
--      debounce discipline mirrors "RequestSprintToggle (Story 001)" -- i.e.
--      this behavior was always the intended precedent Story 002 copied
--      FROM). The ADR's Key Interfaces sample simplifies this away entirely
--      (its `_handleSprintToggleRequest(player)` takes no payload at all,
--      inferring a bare toggle from `currentState` alone) -- that simplification
--      is illustrative shorthand, not a literal contract to reproduce.

local LocomotionStaminaLogic = {}

-- ============================================================================
-- Types
-- ============================================================================

export type LocomotionState = "S1" | "S2"

export type PlayerLocomotionState = {
	locomotion: LocomotionState,
	stamina: number,
	lastLeftSprintAt: number?, -- set on every S2->S1 transition (T2, any path); nil until the first T2
	sprintPulseAnchorAt: number?, -- set on S1->S2 transition (T1); H.3 timer-persistence anchor ONLY --
	-- Story 003 owns the actual pulse-emission cadence/grace-window logic that consumes this.
	lastHeartbeatAt: number?, -- set by an accepted PlayerHeartbeat OR the implicit T1 first-heartbeat seed; nil otherwise
}

export type TumblingWindow = {
	count: number,
	windowStart: number,
}

export type SprintRateLimitRecord = {
	perSecond: TumblingWindow,
	burst: TumblingWindow,
}

-- ============================================================================
-- Config knobs (data-driven: named + centralized here, not scattered magic
-- numbers in logic). Names match design/gdd/player-controller.md verbatim
-- where the GDD names a constant (STAMINA_REGEN_DELAY, not the ADR's own
-- pseudocode shorthand REGEN_DELAY).
-- ============================================================================

LocomotionStaminaLogic.WALK_SPEED = 12 -- studs/s, GDD C.2 / ADR-0003
LocomotionStaminaLogic.SPRINT_SPEED = 20 -- studs/s, GDD C.2 / ADR-0003

LocomotionStaminaLogic.STAMINA_MAX = 100
LocomotionStaminaLogic.STAMINA_DRAIN_RATE = 12.5 -- units/s while in S2, GDD D.1
LocomotionStaminaLogic.STAMINA_REGEN_RATE = 10 -- units/s while in S1 past STAMINA_REGEN_DELAY, GDD D.2
LocomotionStaminaLogic.STAMINA_REGEN_DELAY = 1.5 -- seconds since leaving S2, GDD D.2 (strict `>` boundary, H.8)

LocomotionStaminaLogic.SPRINT_CLIENT_TIMEOUT = 3.0 -- seconds of stale PlayerHeartbeat before force-revert, GDD E.D
LocomotionStaminaLogic.HEARTBEAT_SEND_RATE = 1 -- Hz, GDD C.9 PlayerHeartbeat rate limit

LocomotionStaminaLogic.SPRINT_PULSE_INTERVAL = 2.0 -- seconds; H.3 SCOPE ONLY -- Story 003 owns real emission cadence

LocomotionStaminaLogic.SPRINT_TOGGLE_RATE_LIMIT_PER_SEC = 10 -- GDD C.9 RequestSprintToggle
LocomotionStaminaLogic.SPRINT_TOGGLE_BURST_CAP = 15 -- GDD C.9 round-16 network sustained-flood ceiling
LocomotionStaminaLogic.SPRINT_TOGGLE_BURST_WINDOW_SEC = 2.0

-- ============================================================================
-- Construction
-- ============================================================================

--- Returns a freshly-initialized per-player locomotion+stamina state table.
--- Locomotion starts at S1 (Walk), stamina starts full, per the GDD's
--- default spawn state.
function LocomotionStaminaLogic.NewPlayerLocomotionState(): PlayerLocomotionState
	return {
		locomotion = "S1",
		stamina = LocomotionStaminaLogic.STAMINA_MAX,
		lastLeftSprintAt = nil,
		sprintPulseAnchorAt = nil,
		lastHeartbeatAt = nil,
	}
end

-- ============================================================================
-- H.1 -- GetMoveSpeed
-- ============================================================================

--- Pure, O(1). Returns the `Humanoid.WalkSpeed` value for a given locomotion
--- state. Errors on an unrecognized state string (H.1's own edge case:
--- "must not silently return a stale value") rather than returning a
--- default -- the caller (the Knit wrapper) only ever calls this with a
--- value this module itself produced, so an unrecognized value here always
--- indicates a real defect, not legitimate input drift.
function LocomotionStaminaLogic.GetMoveSpeed(locomotion: string): number
	if locomotion == "S1" then
		return LocomotionStaminaLogic.WALK_SPEED
	elseif locomotion == "S2" then
		return LocomotionStaminaLogic.SPRINT_SPEED
	else
		error(
			('LocomotionStaminaLogic.GetMoveSpeed: unrecognized locomotion state %q -- expected "S1" or "S2"'):format(
				tostring(locomotion)
			),
			2
		)
	end
end

-- ============================================================================
-- H.2 -- XZ displacement (Logic-gate proxy for the Lemur headless-server
-- displacement check; a full Humanoid-physics simulation is infra this
-- project doesn't have yet -- see the story's own H.2 ADVISORY/BLOCKING split)
-- ============================================================================

--- Pure. `distance = speed * durationSec` -- proves the move-speed constant
--- feeds correctly into the displacement formula the manual playtest (PC
--- ADVISORY) independently confirms feels correct in a live Humanoid sim.
function LocomotionStaminaLogic.ComputeXZDisplacement(speed: number, durationSec: number): number
	return speed * durationSec
end

-- ============================================================================
-- H.8 -- IsRegenActive (strict `>` boundary, GDD D.2's "Boundary comparator R6-I1")
-- ============================================================================

--- Pure. `lastLeftSprintAt == nil` means the player has never left S2 (e.g.
--- a fresh spawn that has never sprinted) -- regen is not yet a meaningful
--- concept for them (stamina is already at STAMINA_MAX, so this returning
--- false costs nothing in practice), so this returns false rather than
--- treating `nil` as "eligible since the beginning of time".
function LocomotionStaminaLogic.IsRegenActive(lastLeftSprintAt: number?, now: number): boolean
	if lastLeftSprintAt == nil then
		return false
	end
	return (now - lastLeftSprintAt) > LocomotionStaminaLogic.STAMINA_REGEN_DELAY
end

-- ============================================================================
-- H.6 -- T_sprint(s_0) = s_0 / STAMINA_DRAIN_RATE (GDD D.3, verbatim formula name)
-- ============================================================================

--- Pure. Effective sprint duration (seconds) given starting stamina `s0`,
--- assuming uninterrupted sprint. Divide-by-zero is guarded by the GDD's own
--- config-validation floor on STAMINA_DRAIN_RATE (> 0) -- not re-guarded
--- here, since STAMINA_DRAIN_RATE is a module constant, not caller input.
function LocomotionStaminaLogic.T_sprint(s0: number): number
	return s0 / LocomotionStaminaLogic.STAMINA_DRAIN_RATE
end

-- ============================================================================
-- Shared transition helpers (private) -- both the explicit "stop sprint,
-- always honored" domain path and every forced-revert path (stamina
-- exhaustion, ghost-sprint timeout) converge on the SAME S2->S1 transition,
-- per ADR-0011's own "same force-transition code path" requirement.
-- ============================================================================

local function _enterS1(state: PlayerLocomotionState, now: number): ()
	state.locomotion = "S1"
	state.lastLeftSprintAt = now -- starts the STAMINA_REGEN_DELAY timer (GDD D.2)
	state.lastHeartbeatAt = nil -- T2 clearance (GDD C.9 PlayerHeartbeat lifecycle)
	state.sprintPulseAnchorAt = nil -- stops the sprint pulse timer (H.33a)
end

local function _enterS2(state: PlayerLocomotionState, now: number): ()
	state.locomotion = "S2"
	state.sprintPulseAnchorAt = now -- H.3 scope only; Story 003 consumes this anchor
	state.lastHeartbeatAt = now -- implicit first heartbeat (GDD C.9: "T1 seeds the timestamp to `now`")
end

-- ============================================================================
-- Forced-transition path (stamina exhaustion, ghost-sprint timeout) -- also
-- exported as the stable integration point a future story (e.g. Story 004's
-- T5 death handling) can call once it exists; not called by any death path
-- in this story (ADR-0012 is not implemented yet).
-- ============================================================================

function LocomotionStaminaLogic.ForceRevertToS1(state: PlayerLocomotionState, now: number): ()
	_enterS1(state, now)
end

-- ============================================================================
-- H.4 / H.5 / H.33a / H.82 -- TickStamina, RunService.Heartbeat-bound
-- ============================================================================

--- Mutates `state` in place. Returns (forcedTransition, reason?) so the Knit
--- wrapper knows when to also apply the Humanoid.WalkSpeed side effect and
--- broadcast OnSprintStateChanged (this module never touches a Humanoid).
---
--- Negative-`dt` guard (H.82, GDD D.1/D.2 "R12-SD-6 -- normative"): `dt` is
--- clamped to >= 0 BEFORE either formula evaluates -- a negative `dt` (clock
--- anomaly, anomalous Heartbeat event arg) must not refund stamina through
--- the drain formula or drain it through the regen formula.
---
--- Ordering (matches ADR-0011's own bugfix note): `now` is the caller-supplied
--- parameter, read once by the Knit wrapper at the top of its Heartbeat
--- handler body and passed in here -- this module never calls a clock itself.
function LocomotionStaminaLogic.TickStamina(state: PlayerLocomotionState, dt: number, now: number): (boolean, string?)
	local safeDt = math.max(dt, 0)

	if state.locomotion == "S2" then
		state.stamina = math.clamp(state.stamina - LocomotionStaminaLogic.STAMINA_DRAIN_RATE * safeDt, 0, LocomotionStaminaLogic.STAMINA_MAX)
		if state.stamina <= 0 then
			-- Forced transition to S1 in the SAME tick stamina hits zero --
			-- never leave a player visibly sprinting at 0 stamina for even
			-- one frame (ADR-0011 Decision #3).
			_enterS1(state, now)
			return true, "stamina-exhausted"
		end

		-- Ghost-sprint guard (H.33a): a stale liveness ping force-reverts,
		-- using the identical transition path as stamina exhaustion above.
		if state.lastHeartbeatAt and (now - state.lastHeartbeatAt) > LocomotionStaminaLogic.SPRINT_CLIENT_TIMEOUT then
			_enterS1(state, now)
			return true, "ghost-sprint-timeout"
		end
	elseif LocomotionStaminaLogic.IsRegenActive(state.lastLeftSprintAt, now) then
		state.stamina = math.clamp(state.stamina + LocomotionStaminaLogic.STAMINA_REGEN_RATE * safeDt, 0, LocomotionStaminaLogic.STAMINA_MAX)
	end

	return false, nil
end

-- ============================================================================
-- ADR-0006 step 6 -- deep/domain validation + transition for RequestSprintToggle
-- ============================================================================

--- Given a request that already passed steps 1-5, applies the domain rule
--- (ADR-0011 Decision #1): honor a toggle to S2 only if `locomotion == "S1"
--- AND stamina > 0`; a request to stop sprinting is always honored
--- immediately. Same-state requests are debounced in BOTH directions,
--- matching PlayerControllerLanternLogic.HandleLanternToggleDomain's own
--- structure (its own Implementation Notes cite this event's debounce
--- discipline as the precedent it copied from).
---
--- Returns (accepted, reason?) -- `reason` is nil on accept, otherwise a
--- short machine-readable drop reason (test/debug observability only --
--- production never surfaces this to the client, per ADR-0006's
--- silent-drop convention).
function LocomotionStaminaLogic.HandleSprintToggleDomain(
	state: PlayerLocomotionState,
	sprint: boolean,
	now: number
): (boolean, string?)
	if sprint then
		if state.locomotion == "S2" then
			return false, "same-state-debounced"
		end
		if state.stamina <= 0 then
			return false, "no-stamina" -- F.2's "sprint input ignored until stamina>0" -- silent, no error
		end
		_enterS2(state, now)
		return true, nil
	else
		if state.locomotion == "S1" then
			return false, "same-state-debounced"
		end
		_enterS1(state, now) -- stopping sprint is ALWAYS honored (no stamina/other gate)
		return true, nil
	end
end

-- ============================================================================
-- ADR-0006 step 2 -- RequestSprintToggle per-event rate limit (10/s + burst
-- cap 15/2.0s, GDD C.9). Mirrors LanternLogic.CheckLanternToggleRateLimit's
-- exact tumbling-window structure with this event's own numbers.
-- ============================================================================

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

--- ADR-0006 step 2 for RequestSprintToggle: BOTH the per-second sustained
--- rate (10/s) AND the burst cap (15 per 2.0s) must pass. Peeks both windows
--- before committing either -- a request that fails either check must not
--- partially consume the other's budget (same "no state mutation on drop"
--- rule LanternLogic's own rate limit already enforces).
function LocomotionStaminaLogic.CheckSprintToggleRateLimit(record: SprintRateLimitRecord, now: number): boolean
	if (now - record.perSecond.windowStart) >= 1.0 then
		record.perSecond = { count = 0, windowStart = now }
	end
	if (now - record.burst.windowStart) >= LocomotionStaminaLogic.SPRINT_TOGGLE_BURST_WINDOW_SEC then
		record.burst = { count = 0, windowStart = now }
	end

	if record.perSecond.count >= LocomotionStaminaLogic.SPRINT_TOGGLE_RATE_LIMIT_PER_SEC then
		return false
	end
	if record.burst.count >= LocomotionStaminaLogic.SPRINT_TOGGLE_BURST_CAP then
		return false
	end

	record.perSecond.count += 1
	record.burst.count += 1
	return true
end

-- ============================================================================
-- H.33b -- PlayerHeartbeat per-event rate limit (HEARTBEAT_SEND_RATE = 1 Hz,
-- GDD C.9: "server drops excess silently")
-- ============================================================================

function LocomotionStaminaLogic.CheckHeartbeatRateLimit(record: TumblingWindow, now: number): boolean
	return _tryConsumeWindow(record, now, 1 / LocomotionStaminaLogic.HEARTBEAT_SEND_RATE, 1)
end

-- ============================================================================
-- H.33c -- PlayerHeartbeat domain validation (ADR-0006 step 6): S2-only.
-- ============================================================================

--- Given a PlayerHeartbeat that already passed the rate limit (step 2) and
--- global budget (step 3, Knit-wrapper-owned), updates `lastHeartbeatAt`
--- ONLY if the player is currently in S2 -- a heartbeat received while in S1
--- is silently dropped: no error, no timestamp update, no state transition
--- (GDD C.9: "Heartbeats MUST NOT be sent while in S1, S4, or S5 -- server
--- drops any PlayerHeartbeat received from a player not in S2"). Returns
--- whether the heartbeat was accepted, for test/debug observability.
function LocomotionStaminaLogic.HandlePlayerHeartbeatDomain(state: PlayerLocomotionState, now: number): boolean
	if state.locomotion ~= "S2" then
		return false
	end
	state.lastHeartbeatAt = now
	return true
end

return LocomotionStaminaLogic
