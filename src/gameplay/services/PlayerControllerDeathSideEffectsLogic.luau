--!strict
-- PlayerControllerDeathSideEffectsLogic
--
-- Pure domain logic for Story 005 (Death/Respawn Side-Effects & Cross-Service Signals):
-- the dispatchOrigin/pathOrigin discriminators that select WHICH T5 side-effect set fires
-- pre-yield and post-commit. Deliberately has ZERO dependency on Knit, any Roblox service
-- call, OR any require() at all -- mirrors every sibling PlayerController*Logic module's own
-- zero-require precedent, so it can be required and unit-tested directly under Lune.
--
-- Implements: production/epics/player-controller/story-005-death-respawn-side-effects.md
-- GDD: design/gdd/player-controller.md -- C.5.3 step 2 (pre-yield ordering rule, round-18
--      [R16-2]), C.5.3 step 5 (dispatch-origin discriminator, round-20 SD-19-B2; the R6-B8
--      reconciliation-success player-removal-safe subset), C.6 T5 row (the lettered
--      (a)-(i) side-effect enumeration)
-- ADR: docs/architecture/adr-0005-death-respawn-lifecycle.md (THE LAW -- three
--      commit-INDEPENDENT run-fact side-effects fire synchronously pre-yield, at the same
--      step-2 Pending->InFlight transition, never gated on the oxygen charge's success)
--
-- DESIGN DECISION (flagged, not silently assumed -- see this story's own final report):
-- the dispatchOrigin ("initial"|"reconciliation") and pathOrigin ("A"|"B") axes select
-- WHICH side effects fire; the SEPARATE live-pointer-vs-orphan axis is already owned by
-- PlayerControllerDeathReconciliationLogic.TryCommitDispatch's own `removedAsOrphan` return
-- value and selects ONLY row retention (per the story's own binding instruction: "orphan-
-- removal is selected independently by live-pointer-absence"). This module therefore never
-- reads or needs orphan/live-pointer state at all -- every side effect this module selects
-- is either (a) a pure server-side state-table write (the Knit wrapper never dereferences a
-- live Player instance's Character/Humanoid to apply it) or (b) a userId-keyed cross-service
-- seam call -- both are safe to fire identically whether or not a live `currentDeathRecord`
-- pointer exists at commit time. See PlayerControllerService.luau's own header SCOPE NOTE
-- for how the Knit wrapper composes this module's selections with the real per-player state
-- tables (which DO nil-guard against a departed player, independently of this module).
--
-- ROW-SHAPE NEUTRALITY (REQUIRED, not a stylistic choice): this module never touches
-- `ReconcileRow` or `ReconciliationState` at all -- `dispatchOrigin`/`pathOrigin` are threaded
-- as plain call-scoped parameters by the Knit wrapper (dispatch-scoped coroutine-locals,
-- per the GDD's own "not a new record field and not a per-player sticky flag" text), so
-- PlayerControllerDeathReconciliationLogic.luau's ADR-0005-FROZEN `ReconcileRow` shape
-- ({deathEventId, userId, state, inFlightSince}) needed ZERO changes for this story.

local PlayerControllerDeathSideEffectsLogic = {}

-- ============================================================================
-- Types
-- ============================================================================

export type DispatchOrigin = "initial" | "reconciliation"
export type PathOrigin = "A" | "B"

export type PostCommitSideEffects = {
	deathCause: string,
	sprintReset: boolean, -- (a) sprint pulse-timer stop / force T2 if S2 active
	lanternReset: boolean, -- (b) lantern force-T4 / Light pulse-timer stop if S3b active
	freezeStamina: boolean, -- (c) -- SELECTION ONLY; the Knit wrapper enforces this by
	-- skipping the stamina drain/regen Heartbeat tick for a currently-dead player, not by
	-- an action this module performs (there is nothing to "do" to freeze a value in place)
	resetGraceAnchors: boolean, -- (d), Path A only
	activateSpectatorCamera: boolean, -- (e), Path A only -- server-observable proxy only
	-- (round-24 SD-23: "emits only the server-side camera-state signal ... observed on
	-- the server"); no client-facing RemoteEvent is fired by this story (Story 007 scope)
	lockClientInput: boolean, -- (f), Path A only -- server-observable proxy only (same
	-- round-24 SD-23 scoping; Story 007 owns what the client is told/does with this flag)
	releasePredatorLock: boolean, -- (g) POST-COMMIT re-fire (reconciliation dispatches
	-- ONLY -- the initial dispatch already fired (g) pre-yield and must NOT re-fire it here)
}

-- ============================================================================
-- Death-cause resolution (C.9 OnPlayerDied payload / C.5.3 Path A/B literal deathCause
-- strings, verbatim per the GDD's own text).
-- ============================================================================

PlayerControllerDeathSideEffectsLogic.DEATH_CAUSE_PATH_A = "predator-kill"
PlayerControllerDeathSideEffectsLogic.DEATH_CAUSE_PATH_B = "disconnect-while-damaged"
PlayerControllerDeathSideEffectsLogic.DEATH_CAUSE_RECONCILIATION_RECOVERY = "reconciliation-recovery"

--- GDD C.5.3: "a delayed OnPlayerDied(deathCause="reconciliation-recovery") carries the
--- record's snapshotted deathTimestamp." A reconciliation commit ALWAYS uses the recovery
--- cause regardless of the original path; an initial commit uses the path-specific cause.
--- `pathOrigin` is only meaningful (and only read) when `dispatchOrigin == "initial"`; a
--- reconciliation dispatch never carries a resolved pathOrigin (see PlayerControllerService
--- .luau's own `_runReconciliationTick` call site, which passes `nil`).
function PlayerControllerDeathSideEffectsLogic.ResolveDeathCause(dispatchOrigin: DispatchOrigin, pathOrigin: PathOrigin?): string
	local L = PlayerControllerDeathSideEffectsLogic
	if dispatchOrigin == "reconciliation" then
		return L.DEATH_CAUSE_RECONCILIATION_RECOVERY
	end
	if pathOrigin == "B" then
		return L.DEATH_CAUSE_PATH_B
	end
	return L.DEATH_CAUSE_PATH_A
end

-- ============================================================================
-- Pre-yield selection (C.5.3 step 2 pre-yield ordering rule, round-18 [R16-2]) --
-- (g)/(h)/(i). Fire ONLY on the initial dispatch; a reconciliation-tick dispatch fires NONE
-- of these pre-yield (H.70 -- they already fired, exactly once, at the initial dispatch;
-- re-firing (g) on a successful reconciliation happens POST-COMMIT instead, see
-- SelectPostCommitSideEffects below, per the R6-B8 subset).
-- ============================================================================

--- (g) both paths, unconditional on charge outcome -- fires on every INITIAL dispatch
--- regardless of whether the oxygen charge later succeeds or fails (ADR-0005: "never gated
--- on the oxygen charge's success").
function PlayerControllerDeathSideEffectsLogic.ShouldFireReleasePredatorLockPreYield(dispatchOrigin: DispatchOrigin): boolean
	return dispatchOrigin == "initial"
end

--- (h) Path A only -- a Path-B player is removed, never enters S4 (GDD C.5.3 side-effect (h)).
function PlayerControllerDeathSideEffectsLogic.ShouldFireOnPlayerS4EnteredPreYield(dispatchOrigin: DispatchOrigin, pathOrigin: PathOrigin?): boolean
	return dispatchOrigin == "initial" and pathOrigin == "A"
end

--- (i) both paths.
function PlayerControllerDeathSideEffectsLogic.ShouldFireAliveEdgeFalsePreYield(dispatchOrigin: DispatchOrigin): boolean
	return dispatchOrigin == "initial"
end

-- ============================================================================
-- Post-commit selection (C.5.3 step 5 success path + R6-B8 reconciliation subset) -- the
-- lettered (a)-(g) enumeration, MINUS (g)/(h)/(i) on the initial dispatch (already fired
-- pre-yield) and MINUS (c)-(f)/(h)/(i) entirely on a reconciliation dispatch (H.70).
-- ============================================================================

function PlayerControllerDeathSideEffectsLogic.SelectPostCommitSideEffects(
	dispatchOrigin: DispatchOrigin,
	pathOrigin: PathOrigin?
): PostCommitSideEffects
	local L = PlayerControllerDeathSideEffectsLogic
	local deathCause = L.ResolveDeathCause(dispatchOrigin, pathOrigin)

	if dispatchOrigin == "initial" then
		local isPathA = pathOrigin == "A"
		return {
			deathCause = deathCause,
			sprintReset = true,
			lanternReset = true,
			freezeStamina = true,
			resetGraceAnchors = isPathA,
			activateSpectatorCamera = isPathA,
			lockClientInput = isPathA,
			releasePredatorLock = false, -- already fired pre-yield; NOT re-run here (H.51/H.70)
		}
	end

	-- dispatchOrigin == "reconciliation": the R6-B8 player-removal-safe subset ONLY -- (c)-(f)
	-- explicitly suppressed. (h)/(i) never reach this function at all -- they are pre-yield-only
	-- and ShouldFireOnPlayerS4EnteredPreYield/ShouldFireAliveEdgeFalsePreYield above already
	-- return false for a "reconciliation" dispatchOrigin, so there is no post-commit counterpart
	-- to suppress for those two.
	return {
		deathCause = deathCause,
		sprintReset = true,
		lanternReset = true,
		freezeStamina = false,
		resetGraceAnchors = false,
		activateSpectatorCamera = false,
		lockClientInput = false,
		releasePredatorLock = true,
	}
end

return PlayerControllerDeathSideEffectsLogic
