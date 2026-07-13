--!strict
-- PlayerControllerPathBGraceLogic
--
-- Pure domain logic for Story 006 (Path B Disconnect Predicate, Oxygen Grace Timer &
-- Oxygen-Gated Respawn Wait): the 3-arm imminent-death predicate that gates the Path-B
-- (`Players.PlayerRemoving`-while-imminent) death dispatch, the squad-wide oxygen grace
-- timer's state transitions, the OXYGEN_GRACE_DURATION config-validation hard-error gate,
-- the GDD G.6 LATCH_MAX_AGE x HP_ARM_RECENT_WINDOW coupled-knob invariant gate (H.12a
-- clause (iii)), and the (non-mutating) respawn-timer-elapsed peek the oxygen-gated
-- respawn wait (H.65) needs. Deliberately has ZERO dependency on Knit, any Roblox
-- service call, OR any require() at all -- mirrors every sibling PlayerController*Logic
-- / DisturbanceService*Logic module's own zero-require precedent, so it can be required
-- and unit-tested directly under Lune.
--
-- Implements: production/epics/player-controller/story-006-path-b-oxygen-grace-timer.md
-- GDD: design/gdd/player-controller.md -- C.5 item 1 (trigger conditions, including the
--      PC-owned squad-wide oxygen-grace timer), C.5.1 (OXYGEN_GRACE_DURATION mechanism:
--      squad-wide grace timer started on RM's OnPlayerOxygenExpired(), pool re-check at
--      expiry, mid-grace-restore cancellation, fresh-Empty restart), C.5.3 (the 3-arm
--      imminent-death predicate, its strict-`<` boundary semantics (B11), the arm-3
--      LATCH_MAX_AGE outer staleness ceiling (R10-1), the read-and-cache discipline this
--      module's predicate is designed to be called with), E.E (the oxygen-gated respawn
--      wait, H.65), G.6 (the knob table: HP_IMMINENT_THRESHOLD=25 range 10-50,
--      HP_ARM_RECENT_WINDOW=30.0s range 15-60, DAMAGE_RECENT_WINDOW=3.0s range 1.5-5.0,
--      LATCH_MAX_AGE=120.0s range 60-180, OXYGEN_GRACE_DURATION=5s range 4-8)
-- ADR: docs/architecture/adr-0005-death-respawn-lifecycle.md (THE LAW -- C4 restated:
--      OXYGEN_GRACE_DURATION=5s, PC-owned, squad-wide, 4-8s safe range, 2.0s hard floor
--      R7c-I4; the KnitInit-hard-error + bootstrap game:Shutdown() pairing requirement)
--
-- SCOPE NOTE (this module): implements ONLY the pure predicate/state-machine math --
-- the imminent-death predicate, the grace-timer's own start/cancel/expiry transitions,
-- the config-validation gate, and the respawn-timer-elapsed peek. The Knit wrapper
-- (PlayerControllerService.luau) owns: the real `Players.PlayerRemoving`
-- read-and-cache-then-evaluate-then-dispatch sequencing, the injectable
-- PredatorService/ResourceService cross-epic read seams this predicate's inputs are
-- sourced from, the real RunService.Heartbeat-driven grace-timer tick, and wiring this
-- module's respawn-timer-elapsed peek into the existing `_checkRespawnTimers` flow
-- (pc-4's own `DeathReconciliationLogic.TryRespawn` remains the SOLE mutating respawn
-- transition -- this module never mutates reconciliation state, per the file-scope
-- contract that `PlayerControllerDeathReconciliationLogic.luau` is NOT edited by this
-- story).
--
-- DISCLOSED, DELIBERATE DUPLICATION (flagged, not accidental): `HasRespawnTimerElapsed`
-- below re-implements the SAME `(now - deathStartedAt) >= respawnDelay` comparator
-- `PlayerControllerDeathReconciliationLogic.TryRespawn` already evaluates internally.
-- This is a narrow, intentional duplication -- `TryRespawn` is a frozen, out-of-scope
-- module for this story (it is a check-AND-mutate combo: calling it just to "peek"
-- would also detach `currentDeathRecord`/clear `deathInProgress` even when the caller
-- only wanted to know "has the timer elapsed, so I should even bother checking the
-- oxygen gate"), and `PlayerControllerDeathReconciliationLogic.luau` exposes no
-- non-mutating peek of its own. Duplicating this one, stable, single-line comparator
-- here (rather than editing the frozen module to add a peek function, which is outside
-- this story's file-scope contract) is the lower-risk choice. See this story's own
-- final report for the full reasoning.

local PlayerControllerPathBGraceLogic = {}

-- ============================================================================
-- Config knobs (data-driven: named + centralized here, not scattered magic numbers --
-- matches every sibling *Logic module's own established precedent).
-- ============================================================================

--- GDD C.5.3 / G.6. Range 10-50 per the GDD's own Tuning Knobs table. Strict `<`
--- comparator (B11) -- a player at EXACTLY this HP does NOT satisfy arm 1 or arm 3.
PlayerControllerPathBGraceLogic.HP_IMMINENT_THRESHOLD = 25

--- GDD C.5.3 / G.6. Range 15-60s. Arm 1's recency window -- strict `<`.
PlayerControllerPathBGraceLogic.HP_ARM_RECENT_WINDOW = 30.0

--- GDD C.5.3 / G.6. Range 1.5-5.0s. Arm 2's recency window -- strict `<`.
PlayerControllerPathBGraceLogic.DAMAGE_RECENT_WINDOW = 3.0

--- GDD C.5.3 / G.6 (R10-1 arm-3 outer staleness ceiling). Range 60-180s, subject to
--- the coupled floor `LATCH_MAX_AGE > HP_ARM_RECENT_WINDOW + 30s` -- ENFORCED by
--- `ValidateLatchMaxAgeInvariant` below (GDD G.6: "machine-checkable, enforced by
--- config validation", AC H.12a clause (iii)). Strict `<` in the predicate itself.
PlayerControllerPathBGraceLogic.LATCH_MAX_AGE = 120.0

--- GDD C.5.1 / G.6 / ADR-0005 C4 ruling. Default 5s, safe range 4-8s, PC-owned,
--- squad-wide.
PlayerControllerPathBGraceLogic.OXYGEN_GRACE_DURATION = 5.0

--- ADR-0005 R7c-I4: the hard config-validation floor -- any configured value below
--- this MUST hard-error at KnitInit (mirrors ED's own H.3d/H.3e pattern). This is a
--- gross-misconfiguration floor, NOT the 4-8s safe-range's own lower bound.
PlayerControllerPathBGraceLogic.OXYGEN_GRACE_DURATION_HARD_FLOOR = 2.0

--- GDD G.6 coupled-knob invariant's own margin constant -- `LATCH_MAX_AGE` must
--- exceed `HP_ARM_RECENT_WINDOW` by AT LEAST this many seconds (named, not an
--- inline literal, per this codebase's own never-hardcode-a-magic-number
--- discipline).
PlayerControllerPathBGraceLogic.LATCH_MAX_AGE_COUPLED_MARGIN = 30.0

-- ============================================================================
-- H.22b/H.22c/H.22d/H.43/H.44 -- the 3-arm imminent-death predicate (GDD C.5.3).
-- ============================================================================

--- Evaluates the Path-B imminent-death predicate against ALREADY-CACHED inputs --
--- this function never reads a clock or a live table itself; the caller (PC's
--- `Players.PlayerRemoving` handler) is responsible for the load-bearing
--- read-and-cache-as-the-first-statement-block discipline (GDD C.5.3) BEFORE calling
--- this function. All comparators are strict `<` (B11 -- boundary values never
--- satisfy any arm, biasing toward under-charge at the exact edge). Every
--- Health/timestamp input nil-guards BEFORE any subtraction (Luau short-circuit
--- semantics: the `~= nil` conjunct always left-evaluates first) -- an
--- already-destroyed character's `nil` cached Health, or a never-set predator
--- timestamp/latch, safely fails to satisfy the arm that needs it rather than
--- raising a `nil` arithmetic error.
---
--- Arm 1 (recent graze + currently low HP): `cachedHealth < HP_IMMINENT_THRESHOLD
--- AND cachedDamageTs ~= nil AND (cachedNow - cachedDamageTs) < HP_ARM_RECENT_WINDOW`.
--- Arm 2 (lethal combo in flight from high HP): `cachedDamageTs ~= nil AND
--- (cachedNow - cachedDamageTs) < DAMAGE_RECENT_WINDOW`.
--- Arm 3 (predator-caused sub-threshold state, recency-independent but
--- outer-ceiling-bounded, B5/R10-1): `cachedPredatorCausedImminent == true AND
--- cachedHealth < HP_IMMINENT_THRESHOLD AND cachedLatchSetTs ~= nil AND
--- (cachedNow - cachedLatchSetTs) < LATCH_MAX_AGE`.
function PlayerControllerPathBGraceLogic.IsImminentDeath(
	cachedHealth: number?,
	cachedDamageTs: number?,
	cachedPredatorCausedImminent: boolean?,
	cachedLatchSetTs: number?,
	cachedNow: number
): boolean
	local L = PlayerControllerPathBGraceLogic

	local arm1 = cachedHealth ~= nil
		and (cachedHealth :: number) < L.HP_IMMINENT_THRESHOLD
		and cachedDamageTs ~= nil
		and (cachedNow - (cachedDamageTs :: number)) < L.HP_ARM_RECENT_WINDOW
	if arm1 then
		return true
	end

	local arm2 = cachedDamageTs ~= nil and (cachedNow - (cachedDamageTs :: number)) < L.DAMAGE_RECENT_WINDOW
	if arm2 then
		return true
	end

	local arm3 = cachedPredatorCausedImminent == true
		and cachedHealth ~= nil
		and (cachedHealth :: number) < L.HP_IMMINENT_THRESHOLD
		and cachedLatchSetTs ~= nil
		and (cachedNow - (cachedLatchSetTs :: number)) < L.LATCH_MAX_AGE
	return arm3
end

-- ============================================================================
-- H.12a clause (config gate) -- ADR-0005 R7c-I4.
-- ============================================================================

--- Returns (true, nil) if `oxygenGraceDuration` is at/above the hard floor, or
--- (false, errorMessage) if it is below it. The Knit wrapper's KnitInit is
--- responsible for calling `error(...)` with this message (mirroring the identical
--- pattern `PlayerControllerLanternLogic.ValidateConfig` /
--- `PlayerControllerEmissionPublisherLogic.ValidateConfig` already establish) --
--- this function itself never errors, keeping it a pure, directly-assertable value
--- function.
function PlayerControllerPathBGraceLogic.ValidateConfig(oxygenGraceDuration: number): (boolean, string?)
	local L = PlayerControllerPathBGraceLogic
	if oxygenGraceDuration < L.OXYGEN_GRACE_DURATION_HARD_FLOOR then
		return false,
			("OXYGEN_GRACE_DURATION misconfigured: %.2fs is below the %.1fs hard floor (ADR-0005 R7c-I4)"):format(
				oxygenGraceDuration,
				L.OXYGEN_GRACE_DURATION_HARD_FLOOR
			)
	end
	return true, nil
end

-- ============================================================================
-- H.12a clause (iii) -- GDD G.6 coupled-knob invariant (R13-F2, closes R12-SD-7/AI-8):
-- `LATCH_MAX_AGE > HP_ARM_RECENT_WINDOW + 30.0` (strict, machine-checkable). The
-- prior prose-only "must stay `>` with margin" admitted the degenerate 60/60 corner
-- (LATCH_MAX_AGE at its 60s range minimum with HP_ARM_RECENT_WINDOW at its 60s range
-- maximum gives a margin of ZERO, reopening Scenario C -- a player the predator drove
-- sub-threshold who fled past the ceiling can disconnect cost-free again). This is a
-- SEPARATE gate function (not folded into `ValidateConfig`, which is scoped to
-- `OXYGEN_GRACE_DURATION` alone per its own name/signature) -- the Knit wrapper calls
-- BOTH at KnitInit, mirroring the existing two-call-site pattern
-- (`LanternLogic.ValidateConfig` + `EmissionPublisherLogic.ValidateConfig`) already
-- established in that file.
-- ============================================================================

--- Returns (true, nil) if `latchMaxAge > hpArmRecentWindow + LATCH_MAX_AGE_COUPLED_
--- MARGIN` (strict), or (false, errorMessage) otherwise. At the module's own
--- defaults (120 > 30 + 30) this holds with 60s of headroom; with
--- `hpArmRecentWindow` at its 60s range max, any `latchMaxAge <= 90s` is rejected
--- (GDD G.6's own worked example, verbatim).
function PlayerControllerPathBGraceLogic.ValidateLatchMaxAgeInvariant(latchMaxAge: number, hpArmRecentWindow: number): (boolean, string?)
	local L = PlayerControllerPathBGraceLogic
	local requiredFloor = hpArmRecentWindow + L.LATCH_MAX_AGE_COUPLED_MARGIN
	if latchMaxAge <= requiredFloor then
		return false,
			("LATCH_MAX_AGE misconfigured: %.2fs does not exceed HP_ARM_RECENT_WINDOW (%.2fs) + %.1fs margin (%.2fs required, strict) -- GDD G.6 coupled-knob invariant, closes R12-SD-7/AI-8 Scenario C"):format(
				latchMaxAge,
				hpArmRecentWindow,
				L.LATCH_MAX_AGE_COUPLED_MARGIN,
				requiredFloor
			)
	end
	return true, nil
end

-- ============================================================================
-- C.5.1 -- the squad-wide oxygen grace timer's own state machine.
-- ============================================================================

export type OxygenGraceState = {
	active: boolean,
	expiresAt: number?,
}

function PlayerControllerPathBGraceLogic.NewGraceState(): OxygenGraceState
	return { active = false, expiresAt = nil }
end

--- Starts (or, per GDD C.5.1 "a fresh Empty entry restarts it", RESTARTS) the
--- squad-wide grace timer. Called on every `OnPlayerOxygenExpired()` edge, whether
--- or not a timer was already active -- a fresh Empty entry always re-anchors the
--- full `duration` from `now`, never accumulates/extends an existing window.
function PlayerControllerPathBGraceLogic.StartOrRestartGraceTimer(state: OxygenGraceState, now: number, duration: number): ()
	state.active = true
	state.expiresAt = now + duration
end

--- Mid-grace Canister restore (GDD C.5.1: "cancels the pending deaths and the
--- timer") -- also used as the one-shot consume-on-fire transition at expiry (a
--- fresh `OnPlayerOxygenExpired()` afterward is what starts the NEXT window, not a
--- leftover active flag).
function PlayerControllerPathBGraceLogic.CancelGraceTimer(state: OxygenGraceState): ()
	state.active = false
	state.expiresAt = nil
end

function PlayerControllerPathBGraceLogic.IsGraceTimerActive(state: OxygenGraceState): boolean
	return state.active
end

--- Inclusive `>=` at the boundary (mirrors this codebase's own `RESPAWN_DELAY`
--- elapsed-timer convention, e.g. `PlayerControllerDeathReconciliationLogic.
--- TryRespawn`'s internal comparator) -- NOT the predicate's strict-`<` convention
--- above, which governs a different (cost-attribution) semantic. A grace timer
--- whose duration has been exactly reached has elapsed.
function PlayerControllerPathBGraceLogic.HasGraceTimerExpired(state: OxygenGraceState, now: number): boolean
	if not state.active or state.expiresAt == nil then
		return false
	end
	return now >= (state.expiresAt :: number)
end

-- ============================================================================
-- H.65 -- the oxygen-gated respawn wait's non-mutating respawn-timer-elapsed peek.
-- See this module's own header DISCLOSED DUPLICATION note for why this exists
-- alongside (not instead of) `PlayerControllerDeathReconciliationLogic.TryRespawn`.
-- ============================================================================

--- Inclusive `>=` at the boundary -- identical semantics to `TryRespawn`'s own
--- internal check (`(now - startedAt) < respawnDelay` returning early), just
--- expressed as a pure, non-mutating boolean so a caller can decide whether to even
--- evaluate the (comparatively more expensive) oxygen-pool-read + squad-liveness
--- scan before calling the real, mutating `TryRespawn`.
function PlayerControllerPathBGraceLogic.HasRespawnTimerElapsed(deathStartedAt: number?, now: number, respawnDelay: number): boolean
	if deathStartedAt == nil then
		return false
	end
	return (now - (deathStartedAt :: number)) >= respawnDelay
end

return PlayerControllerPathBGraceLogic
