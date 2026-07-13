--!strict
-- PlayerControllerEmissionPublisherLogic
--
-- Pure domain logic for PlayerControllerService's Sprint/Light disturbance-emission
-- publisher: grace-window exemption, per-axis re-entry cooldown (and the G1-exploit-closing
-- anchor-on-eligibility rule), mobile-drift floor, stationary attenuation, and the
-- Sprint-axis-only hold-floor. Deliberately has ZERO dependency on Knit or any Roblox
-- service call, so it can be required and unit-tested directly under Lune without a
-- vendored Knit package or a live Roblox environment -- matching the precedent
-- PlayerControllerLanternLogic.luau / PlayerControllerLocomotionStaminaLogic.luau
-- established for Stories 001/002. `PlayerControllerService.luau` is a thin Knit wrapper
-- around these functions -- it owns Player identity, the axis-transition call sites
-- (hooking into Story 001's sprint toggle and Story 002's lantern toggle accept paths),
-- the `RunService.Heartbeat`-driven pulse tick, the `HumanoidRootPart.Position` read, and
-- the real `DisturbanceService:Emit(...)` call site; this module owns only the actual
-- magnitude/cadence formulas.
--
-- Implements: production/epics/player-controller/story-003-disturbance-emission-publisher.md
-- GDD: design/gdd/player-controller.md -- C.8 (Disturbance System Contract, publisher),
--      C.8.1 (Sprint emission), C.8.2 (Light emission), C.11 (clock-injection seam
--      contract -- this module never reads a clock itself; every timestamp is an explicit
--      parameter, matching LocomotionStaminaLogic's own precedent), D.4 (Pulse Emission
--      Magnitude formula, implemented verbatim below), D.6 (Movement-Delta Sampling)
-- ADR: docs/architecture/adr-0003-locomotion-driver.md (HumanoidRootPart.Position as the
--      shared, server-tracked position primitive this module's `position: Vector3`
--      parameters assume -- reading the live Humanoid is a Knit-wrapper-layer concern,
--      never this module's)
--
-- SCOPE NOTE (architecture decision, approved 2026-07-06 -- see this story's own
-- implementation session): this module owns a FULLY SELF-CONTAINED `PlayerEmissionState`,
-- rather than writing into Story 001's `PlayerLocomotionState.sprintPulseAnchorAt` /
-- Story 002's `PlayerControllerLanternLogic.PlayerState.t_lastGracePulse_light` directly
-- (both of which those modules' own header comments name as fields "Story 003 owns" or
-- "will consume"). This was a deliberate choice, not a default:
--   1. It keeps this module require()-free and structurally independent of
--      PlayerControllerLanternLogic.luau / PlayerControllerLocomotionStaminaLogic.luau,
--      matching every sibling pure-logic module's zero-dependency precedent in this
--      codebase (LanternLogic, LocomotionStaminaLogic, DisturbanceServiceEmissionLogic,
--      DisturbanceServiceBootstrapLogic are ALL zero-require) -- reaching into another
--      module's exported type would be the first exception to that pattern.
--   2. It is REQUIRED for correctness, not just style: `sprintPulseAnchorAt` is cleared to
--      `nil` on every S2->S1 exit (`_enterS1` in PlayerControllerLocomotionStaminaLogic.luau).
--      But H.11h's `t_lastGracePulse[axis]` anchor MUST persist across an axis exit/re-entry
--      cycle -- that persistence is the entire mechanism `GRACE_REENTRY_COOLDOWN` (6.0s)
--      depends on (GDD C.8.1's "Cooldown rationale (Pillar 1 closure)": toggle sprint off,
--      wait for stamina regen, toggle on again -- the G1 exploit this story closes). Reusing
--      `sprintPulseAnchorAt` as the grace anchor would have silently broken the cooldown the
--      moment a player stopped and restarted sprinting within the re-entry window.
-- Zero fields on `PlayerLocomotionState` / `PlayerControllerLanternLogic.PlayerState` are
-- read or written by this module or by PlayerControllerService's Story 003 additions --
-- full compliance with this story's Out-of-Scope clause ("don't touch Story 001/002
-- transition logic"). The tradeoff: `PlayerControllerService.luau` seeds this module's own
-- `t_0` at the SAME transition moments Story 001/002 already seed their own anchors (a few
-- bytes of duplicated bookkeeping, not duplicated logic).
--
-- NOTE (harness-driven scope call, approved 2026-07-06 -- deviates from this story's own
-- Implementation Notes prose, which says SPRINT_HOLD_FLOOR should be "referenced, not
-- redefined locally"): MAGNITUDE_SPRINT_PULSE, MAGNITUDE_LIGHT_PULSE, SPRINT_HOLD_FLOOR,
-- STATIONARY_EMISSION_FACTOR, EMITTER_MOVEMENT_DELTA_FLOOR, FIRST_PULSE_GRACE_WINDOW,
-- SPRINT_PULSE_INTERVAL, and LIGHT_PULSE_INTERVAL are all ED-registry-owned constants
-- (`DisturbanceConstants.luau`, G.5) but are kept as LOCAL constants below rather than
-- require()'d, because tests/run_tests.lua's load_luau_file() harness loads this module via
-- loadstring() and never gives it a `script` global -- `require(script.Parent.
-- DisturbanceConstants)` cannot resolve here. This is the identical harness gap
-- DisturbanceServiceEmissionLogic.luau's own header note documents for its
-- BEACON_MAGNITUDE_RESERVED_BOUNDARY local constant; this module follows that exact,
-- already-approved precedent. GRACE_REENTRY_COOLDOWN and MOBILE_ANALOG_DRIFT_THRESHOLD are
-- genuinely PC-owned tunables (confirmed absent from DisturbanceConstants.luau; the GDD's
-- own D.4 tuning-knob table marks both without an "ED registry" owner tag, unlike the other
-- eight) -- no ED citation applies to those two.

local PlayerControllerEmissionPublisherLogic = {}

-- ============================================================================
-- Types
-- ============================================================================

export type Axis = "Sprint" | "Light"
export type Platform = "pc" | "touch" | "gamepad"

export type AxisEmissionState = {
	t_0: number?, -- state-entry timestamp (GDD D.4 `t_0`); nil while the axis is inactive
	t_lastGracePulse: number?, -- H.11h anchor; PERSISTS across axis exit/re-entry within a
	-- life (that is the whole point of GRACE_REENTRY_COOLDOWN) -- cleared ONLY by
	-- ResetGraceAnchorsOnDeath (H.11d), never by OnAxisExited
	lastPulseFiredAt: number?, -- cadence bookkeeping; nil until this state-entry's first
	-- pulse has fired
	lastPulsePosition: Vector3?, -- D.6 baseline for the next XZ-displacement sample; nil
	-- until the axis is active
}

export type PlayerEmissionState = {
	sprint: AxisEmissionState,
	light: AxisEmissionState,
}

-- ============================================================================
-- Config knobs (data-driven: named + centralized here, not scattered magic numbers in
-- logic). See the header SCOPE NOTE above for exactly which of these are ED-registry-owned
-- (duplicated locally due to the harness require() gap) versus genuinely PC-owned.
-- ============================================================================

PlayerControllerEmissionPublisherLogic.MAGNITUDE_SPRINT_PULSE = 0.10 -- ED registry (G.5)
PlayerControllerEmissionPublisherLogic.MAGNITUDE_LIGHT_PULSE = 0.08 -- ED registry (G.5)
PlayerControllerEmissionPublisherLogic.SPRINT_HOLD_FLOOR = 0.09 -- ED registry (G.5); Sprint-axis only (H.81)
PlayerControllerEmissionPublisherLogic.STATIONARY_EMISSION_FACTOR = 0.30 -- ED registry (G.5)
PlayerControllerEmissionPublisherLogic.EMITTER_MOVEMENT_DELTA_FLOOR = 1.0 -- studs; ED registry (G.5)
PlayerControllerEmissionPublisherLogic.FIRST_PULSE_GRACE_WINDOW = 1.0 -- seconds; ED registry (G.5)
PlayerControllerEmissionPublisherLogic.SPRINT_PULSE_INTERVAL = 2.0 -- seconds; ED registry (G.5)
PlayerControllerEmissionPublisherLogic.LIGHT_PULSE_INTERVAL = 4.0 -- seconds; ED registry (G.5)

PlayerControllerEmissionPublisherLogic.GRACE_REENTRY_COOLDOWN = 6.0 -- seconds; PC-owned (GDD D.4 table, range 4.0-12.0)
PlayerControllerEmissionPublisherLogic.MOBILE_ANALOG_DRIFT_THRESHOLD = 2.0 -- studs; PC-owned, touch-only (GDD C.7/D.4, range 1-4)

-- ============================================================================
-- Construction
-- ============================================================================

local function newAxisEmissionState(): AxisEmissionState
	return {
		t_0 = nil,
		t_lastGracePulse = nil,
		lastPulseFiredAt = nil,
		lastPulsePosition = nil,
	}
end

--- Returns a freshly-initialized per-player emission state table. Both axes start inactive
--- (no life-in-progress sprint/light has ever fired a pulse).
function PlayerControllerEmissionPublisherLogic.NewPlayerEmissionState(): PlayerEmissionState
	return {
		sprint = newAxisEmissionState(),
		light = newAxisEmissionState(),
	}
end

-- ============================================================================
-- H.12a -- config validation
-- ============================================================================

--- Pure validity check for the G.7 hierarchy invariant
--- `MAGNITUDE_LIGHT_PULSE < SPRINT_HOLD_FLOOR < MAGNITUDE_SPRINT_PULSE` (both strict), plus
--- the STATIONARY_EMISSION_FACTOR range gate (clause vi: must be in `(0, 1]`). Returns
--- (true) if valid, or (false, message) if not. Never errors itself -- the Knit service
--- wraps this in a KnitInit-time error() hard-stop, matching LanternLogic.ValidateConfig's
--- precedent.
function PlayerControllerEmissionPublisherLogic.ValidateConfig(
	magnitudeLightPulse: number,
	magnitudeSprintPulse: number,
	sprintHoldFloor: number,
	stationaryEmissionFactor: number
): (boolean, string?)
	if sprintHoldFloor <= magnitudeLightPulse then
		return false,
			("PlayerControllerEmissionPublisherLogic: SPRINT_HOLD_FLOOR (%.3f) must be > MAGNITUDE_LIGHT_PULSE (%.3f); G.7 hierarchy invariant"):format(
				sprintHoldFloor,
				magnitudeLightPulse
			)
	end
	if sprintHoldFloor >= magnitudeSprintPulse then
		return false,
			("PlayerControllerEmissionPublisherLogic: SPRINT_HOLD_FLOOR (%.3f) must be < MAGNITUDE_SPRINT_PULSE (%.3f); G.7 hierarchy invariant"):format(
				sprintHoldFloor,
				magnitudeSprintPulse
			)
	end
	if stationaryEmissionFactor <= 0 or stationaryEmissionFactor > 1 then
		return false,
			("PlayerControllerEmissionPublisherLogic: STATIONARY_EMISSION_FACTOR (%.3f) must be in (0, 1]"):format(
				stationaryEmissionFactor
			)
	end
	return true, nil
end

-- ============================================================================
-- Axis-transition hooks (called by the Knit wrapper at the exact same moments Story 001's
-- RequestSprintToggle accept path / Story 002's RequestLanternToggle accept path already
-- fire their OWN transitions -- this module never detects a transition itself, it only
-- reacts to one the caller already resolved).
-- ============================================================================

--- Called when an axis becomes active (S1->S2 for Sprint, S3a->S3b for Light). Seeds `t_0`
--- (GDD D.4's state-entry timestamp) and the D.6 first-pulse position baseline. Deliberately
--- does NOT touch `t_lastGracePulse` -- that anchor's whole purpose is to persist across
--- exactly this kind of re-entry (see header SCOPE NOTE).
function PlayerControllerEmissionPublisherLogic.OnAxisEntered(axisState: AxisEmissionState, position: Vector3, now: number): ()
	axisState.t_0 = now
	axisState.lastPulseFiredAt = nil -- first pulse of this state-entry is due immediately
	axisState.lastPulsePosition = position -- D.6 first-pulse special case: baseline = state-entry position
end

--- Called when an axis becomes inactive (S2->S1 for Sprint, S3b->S3a for Light), on ANY
--- exit path (explicit toggle, forced revert, or a future death transition). Clears the
--- active-state bookkeeping. `t_lastGracePulse` is intentionally left untouched -- the
--- cooldown must survive the axis being off.
function PlayerControllerEmissionPublisherLogic.OnAxisExited(axisState: AxisEmissionState): ()
	axisState.t_0 = nil
	axisState.lastPulseFiredAt = nil
	axisState.lastPulsePosition = nil
end

-- ============================================================================
-- H.11d -- death-reset forward seam. T5 (Humanoid.Died) itself is Story 004's scope and
-- does not exist yet -- this function is the stable integration point Story 004 will call
-- once it does, matching this project's established forward-seam pattern (pc-2's own
-- BeginGatherHold, ed-1's RegistrationHandshake stub).
-- ============================================================================

--- Resets BOTH axes' grace-cooldown anchors to nil, so a fresh life gets a fresh
--- grace-exempt first pulse on each axis. Does NOT touch t_0/lastPulseFiredAt/
--- lastPulsePosition -- those are cleared by OnAxisExited whenever the real S2->S1 /
--- S3b->S3a transition a death causes actually fires (Story 001/002's own transition
--- paths); this seam owns only the grace-anchor reset, per H.11d's own scope.
function PlayerControllerEmissionPublisherLogic.ResetGraceAnchorsOnDeath(state: PlayerEmissionState): ()
	state.sprint.t_lastGracePulse = nil
	state.light.t_lastGracePulse = nil
end

-- ============================================================================
-- D.6 -- Movement-Delta Sampling (XZ displacement). Y is discarded -- jump-in-place
-- produces d_xz = 0.
-- ============================================================================

function PlayerControllerEmissionPublisherLogic.SampleXZDisplacement(previousPosition: Vector3, currentPosition: Vector3): number
	local dx = currentPosition.X - previousPosition.X
	local dz = currentPosition.Z - previousPosition.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- ============================================================================
-- D.4 -- Pulse Emission Magnitude (with stationary gate). Implements the GDD's own
-- pseudocode verbatim, in order.
-- ============================================================================

--- Pure per the mutation contract documented on `axisState` above: mutates
--- `axisState.t_lastGracePulse` in place (Step 0a) and returns the computed magnitude.
--- Every timestamp (`t_0`, `t`) is an explicit caller-supplied parameter -- this function
--- never reads a clock itself, per the C.11 seam contract.
---
--- Evaluation order (GDD D.4, exact -- do not reorder):
---   Step 0  -- resolve grace_eligible from the per-axis cooldown.
---   Step 0a -- H.11h / B9 LOAD-BEARING RULE: anchor `t_lastGracePulse` on ELIGIBILITY,
---             unconditionally, NOT gated behind the grace-window check below passing.
---             Anchoring only inside the grace-window branch would silently reopen the G1
---             exploit under server jitter (a late-delivered first pulse would never anchor
---             the cooldown, so the NEXT state-entry would still read grace_eligible=true).
---   Step 1  -- mobile-drift floor (touch platform only): effective_d := 0 if d_xz is below
---             MOBILE_ANALOG_DRIFT_THRESHOLD.
---   Step 2  -- branch: grace (full) / moving (full) / stationary (attenuated).
---   Step 3  -- Sprint-axis-ONLY hold-floor: max(SPRINT_HOLD_FLOOR, computed). NEVER applied
---             to the Light axis (H.81 -- a security property, not an oversight).
function PlayerControllerEmissionPublisherLogic.GetPulseMagnitude(
	axisState: AxisEmissionState,
	axis: Axis,
	t_0: number,
	t: number,
	d_xz: number,
	platform: Platform
): number
	local L = PlayerControllerEmissionPublisherLogic

	-- Step 0: resolve grace eligibility for this pulse (per-axis cooldown). Boundary
	-- comparator is INCLUSIVE (`>=`), per the GDD registry's own B9/R6-B3 fix: elapsed time
	-- exactly equal to GRACE_REENTRY_COOLDOWN IS eligible.
	local lastGrace = axisState.t_lastGracePulse
	local graceEligible = (lastGrace == nil) or ((t_0 - (lastGrace :: number)) >= L.GRACE_REENTRY_COOLDOWN)

	-- Step 0a (H.11h -- LOAD-BEARING): anchor on eligibility, unconditionally. This line
	-- must NOT be moved inside the grace-window `if` below.
	if graceEligible then
		axisState.t_lastGracePulse = t_0
	end

	-- Step 1: mobile-drift floor (touch-only; PC/gamepad never zero effective_d here).
	local effectiveD = d_xz
	if d_xz < L.MOBILE_ANALOG_DRIFT_THRESHOLD and platform == "touch" then
		effectiveD = 0
	end

	local magnitudeBase = if axis == "Sprint" then L.MAGNITUDE_SPRINT_PULSE else L.MAGNITUDE_LIGHT_PULSE

	-- Step 2: grace / moving / stationary branch.
	local magnitudeOut: number
	if graceEligible and (t - t_0) <= L.FIRST_PULSE_GRACE_WINDOW then
		magnitudeOut = magnitudeBase
	elseif effectiveD < L.EMITTER_MOVEMENT_DELTA_FLOOR then
		magnitudeOut = magnitudeBase * L.STATIONARY_EMISSION_FACTOR
	else
		magnitudeOut = magnitudeBase
	end

	-- Step 3: Sprint-axis-ONLY hold-floor (H.81 security property -- Light never gets this).
	if axis == "Sprint" then
		magnitudeOut = math.max(L.SPRINT_HOLD_FLOOR, magnitudeOut)
	end

	return magnitudeOut
end

-- ============================================================================
-- Cadence gate -- "is a pulse due this tick" -- and the composed per-tick evaluator the
-- Knit wrapper's Heartbeat loop calls once per player per axis.
-- ============================================================================

--- True if the axis is active AND either (a) no pulse has fired yet this state-entry (the
--- first pulse is due immediately), or (b) at least SPRINT_PULSE_INTERVAL/LIGHT_PULSE_INTERVAL
--- has elapsed since the last pulse fired on this axis.
function PlayerControllerEmissionPublisherLogic.IsPulseDue(axisState: AxisEmissionState, axis: Axis, now: number): boolean
	if axisState.t_0 == nil then
		return false -- axis inactive
	end
	if axisState.lastPulseFiredAt == nil then
		return true -- first pulse of this state-entry
	end
	local interval = if axis == "Sprint"
		then PlayerControllerEmissionPublisherLogic.SPRINT_PULSE_INTERVAL
		else PlayerControllerEmissionPublisherLogic.LIGHT_PULSE_INTERVAL
	return (now - (axisState.lastPulseFiredAt :: number)) >= interval
end

--- Composes IsPulseDue + SampleXZDisplacement + GetPulseMagnitude for a single axis/tick,
--- and records the pulse-fire bookkeeping (lastPulseFiredAt/lastPulsePosition) on accept.
--- Returns the magnitude to publish if a pulse should fire this tick, or nil if no pulse is
--- due yet. The Knit wrapper calls this once per active axis per Heartbeat tick and, on a
--- non-nil result, is responsible for the actual `DisturbanceService:Emit(...)` call --
--- this function never calls Knit or any Roblox service itself.
function PlayerControllerEmissionPublisherLogic.EvaluatePulse(
	axisState: AxisEmissionState,
	axis: Axis,
	now: number,
	position: Vector3,
	platform: Platform
): number?
	if not PlayerControllerEmissionPublisherLogic.IsPulseDue(axisState, axis, now) then
		return nil
	end

	local t_0 = axisState.t_0 :: number -- IsPulseDue guarantees non-nil when it returns true
	local previousPosition = axisState.lastPulsePosition or position
	local d_xz = PlayerControllerEmissionPublisherLogic.SampleXZDisplacement(previousPosition, position)

	local magnitude = PlayerControllerEmissionPublisherLogic.GetPulseMagnitude(axisState, axis, t_0, now, d_xz, platform)

	axisState.lastPulseFiredAt = now
	axisState.lastPulsePosition = position

	return magnitude
end

return PlayerControllerEmissionPublisherLogic
