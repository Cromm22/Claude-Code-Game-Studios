--!strict
-- PlayerControllerRunEndLogic
--
-- Pure domain logic for Story 009 (Run-End Contract, T7 Wipe / T8 Victory). Deliberately
-- has ZERO dependency on Knit, any Roblox service call, OR any require() at all --
-- mirrors every sibling PlayerController*Logic module's own zero-require precedent
-- (PlayerControllerDeathReconciliationLogic.luau / PlayerControllerPathBGraceLogic.luau /
-- PlayerControllerRenderScopeLogic.luau), so it can be required and unit-tested directly
-- under Lune. `PlayerControllerService.luau` is a thin Knit wrapper around these
-- functions -- it owns Player identity, the real `Players:GetPlayers()` squad scan, the
-- real cross-service calls (`Knit.GetService("RunController"):RunEndConditionRaised(...)`,
-- `GetRunEndedSignal():Connect(...)`), and the real C.11 `getServerTime()` clock sample;
-- this module owns only the T7/T8 predicate decisions, the `_beaconActivated` latch
-- lifecycle mutations, the raise-once guards, and the squadState snapshot shape.
--
-- Implements: production/epics/player-controller/story-009-run-end-contract.md
-- GDD: design/gdd/player-controller.md -- C.6 T7/T8 transition rows, the
--      `_beaconActivated` latch table (C.6, just above the T7/T8 rows), the
--      `BEACON_LATCH_TIMEOUT` self-heal prose, C.9 RemoteEvent surface (`RunEnded`
--      inbound row, `OnEscapeBeaconActivated`/`OnBeaconWindowSurvived` inbound rows,
--      `RunController:RunEndConditionRaised` outbound row), G.6 (`BEACON_LATCH_TIMEOUT`
--      default 300s, range 180-600)
-- ADR: docs/architecture/adr-0002-runcontroller-architecture.md (the arbiter's own
--      contract this module's callers feed -- `RunEndConditionRaised(conditionType,
--      squadState, defeatReason?)` / `RunEnded{exitReason, squadState, timestamp,
--      defeatReason}` -- consulted here only to keep this module's exported types
--      structurally compatible with the REAL, already-implemented RunController;
--      RunController's own idempotency latch and RUN_END_DEFEAT_HOLD precedence
--      resolution are that service's OWN scope, not duplicated here)
--      docs/architecture/adr-0005-death-respawn-lifecycle.md (the ReconciliationState
--      shape `ForceCancelRespawnTimer` below mirrors, minus the elapsed-time gate)
--
-- SCOPE NOTE (Story 009, this module): implements ONLY PC's caller-side raise
-- decisions and the `_beaconActivated` latch state machine. Explicitly OUT OF SCOPE
-- (per the story's own Out-of-Scope clause): RunController's own `RunEndConditionRaised`
-- receiving implementation, its one-shot `RunEnded` idempotency latch, and its
-- `RUN_END_DEFEAT_HOLD` precedence resolution (victory-over-wipe) -- all of that
-- already exists in `src/gameplay/services/RunController.luau` /
-- `RunControllerLogic.luau` (rc-1/rc-2) and is NOT touched by this module. Also out of
-- scope: Crafting & Items' own `OnEscapeBeaconActivated`/`OnBeaconWindowSurvived`
-- producer implementation, and PC's own (deliberately unimplemented, per GDD C.10's
-- "Deliberate NON-subscription") forwarding of Crafting's in-window BCT-DEFEAT
-- `OnBeaconWindowFailed` -- this module therefore never needs a live `defeatReason`
-- value; every call site in the Knit wrapper passes `nil` for it (ADR-0002: "nil for
-- victory and for a pre-activation PC wipe").
--
-- PLAYER IDENTITY (design call, matching PlayerControllerDeathReconciliationLogic.luau's
-- own precedent verbatim): `ForceCancelRespawnTimer`'s `playerKey` parameter is an
-- opaque identity value, compared only via table-key identity/`==` -- works identically
-- for a real Roblox `Player` instance and for the plain Lua tables this module's own
-- test suite uses as stand-ins. `BuildSquadStateSnapshot` never references the `Player`
-- type either -- it consumes a plain `{userId, scope}` tuple list the Knit wrapper
-- builds by iterating `Players:GetPlayers()`.
--
-- RECONCILIATION-STATE SHAPE (structural, not `require()`d): `ForceCancelRespawnTimer`
-- accepts a locally-declared `ReconciliationStateLike` type, structurally identical to
-- `PlayerControllerDeathReconciliationLogic.ReconciliationState`'s `reconcileRows` /
-- `currentDeathRecord` / `deathInProgress` / `deathStartedAt` fields (Luau's structural
-- typing accepts the real table without this module ever `require()`ing that module),
-- preserving this file's own zero-require discipline.

local PlayerControllerRunEndLogic = {}

-- ============================================================================
-- Types
-- ============================================================================

--- Mirrors `RunControllerLogic.ConditionType` (`src/gameplay/services/RunControllerLogic.luau`)
--- structurally -- this module never `require()`s that file, but the REAL
--- `RunController:RunEndConditionRaised` call this module's callers feed expects
--- exactly these two string values.
export type ConditionType = "wipe" | "victory"

--- Mirrors `RunControllerLogic.DefeatReason` structurally. Never actually produced by
--- this module (see the header SCOPE NOTE) -- exported only so the Knit wrapper's own
--- call-site type annotations have somewhere to point.
export type DefeatReason = "wipe" | "scatter"

--- The per-run `_beaconActivated` latch + the two independent raise-once guards. ONE
--- instance per server session, reset (not recreated) at every `RunEnded` (`ClearOnRunEnded`
--- below) -- never per-player.
export type RunEndState = {
	beaconActivated: boolean,
	beaconActivatedAt: number?,
	hasRaisedWipe: boolean,
	hasRaisedVictory: boolean,
}

--- Structural match for `PlayerControllerRenderScopeLogic.RenderScope` -- this module
--- never `require()`s that file (zero-require discipline); the three literal string
--- values are copied verbatim since Luau's structural typing does not need a shared
--- nominal type for this to type-check at every real call site.
export type RenderScopeLike = "alive" | "dead-respawning" | "post-run"

--- The per-member liveness snapshot value this story's own Implementation Notes
--- specify verbatim: `squadState = { [userId] = "alive" | "S4" | "S5" }`. This is a
--- DELIBERATE, binding resolution of ADR-0002's own Open Question ("SquadStateSnapshot's
--- concrete shape... deferred until Player Controller's and Crafting's own squad-state
--- types are authored/reconciled") -- PC is the sole current caller (ADR-0002 Decision
--- point 1's "Current caller reality"), so PC's own concrete shape IS the resolution,
--- not a placeholder. RunController itself treats this as an opaque pass-through
--- payload (ADR-0002 Decision point 1) and never validates or branches on its shape.
export type SquadStateValue = "alive" | "S4" | "S5"
export type SquadStateSnapshot = { [number]: SquadStateValue }

--- Plain `{userId, scope}` tuple -- see the header PLAYER IDENTITY note. The Knit
--- wrapper builds a list of these by iterating `Players:GetPlayers()`; this module
--- never sees a live `Player` instance.
export type SquadMemberEntry = { userId: number, scope: RenderScopeLike? }

--- Structural match for a single row of
--- `PlayerControllerDeathReconciliationLogic.ReconcileRow` -- see the header
--- RECONCILIATION-STATE SHAPE note. Only the `state` field is read.
export type ReconcileRowLike = { state: string, [string]: any }

--- Structural match for `PlayerControllerDeathReconciliationLogic.ReconciliationState` --
--- only the four fields `ForceCancelRespawnTimer` actually touches are declared here
--- (the real table also carries `nextDeathEventIdCounter`/`lastTickTime`, which Luau's
--- structural typing tolerates as extra fields on the real argument passed in).
export type ReconciliationStateLike = {
	reconcileRows: { [string]: ReconcileRowLike },
	currentDeathRecord: { [any]: string? },
	deathInProgress: { [any]: boolean },
	deathStartedAt: { [any]: number },
}

-- ============================================================================
-- Config knobs (data-driven: named + centralized here, matching every sibling
-- PlayerController*Logic module's own "kept LOCAL, not a separate constants module"
-- precedent under this harness's require() constraints).
-- ============================================================================

--- GDD G.6. Default 300s, safe range [180, 600] -- the self-heal backstop for a
--- dropped/never-sent `RunEnded` broadcast (R17-4, user-ruled 2026-06-14). See
--- `ValidateConfig` below for the hard range gate.
PlayerControllerRunEndLogic.BEACON_LATCH_TIMEOUT = 300.0

PlayerControllerRunEndLogic.BEACON_LATCH_TIMEOUT_MIN = 180.0
PlayerControllerRunEndLogic.BEACON_LATCH_TIMEOUT_MAX = 600.0

--- KnitInit-time hard-error gate, mirroring every other PC knob's own established
--- pattern (`PlayerControllerLanternLogic.ValidateConfig` /
--- `PlayerControllerEmissionPublisherLogic.ValidateConfig` /
--- `PlayerControllerPathBGraceLogic.ValidateConfig`) -- this function itself never
--- errors, keeping it a pure, directly-assertable value function; the Knit wrapper's
--- `KnitInit` is what actually calls `error()` on a `false` result.
function PlayerControllerRunEndLogic.ValidateConfig(beaconLatchTimeout: number): (boolean, string?)
	local L = PlayerControllerRunEndLogic
	if beaconLatchTimeout < L.BEACON_LATCH_TIMEOUT_MIN or beaconLatchTimeout > L.BEACON_LATCH_TIMEOUT_MAX then
		return false,
			("BEACON_LATCH_TIMEOUT misconfigured: %.1fs is outside the safe range [%.1f, %.1f] (GDD G.6)"):format(
				beaconLatchTimeout,
				L.BEACON_LATCH_TIMEOUT_MIN,
				L.BEACON_LATCH_TIMEOUT_MAX
			)
	end
	return true, nil
end

-- ============================================================================
-- Construction / per-run reset (TR-pc-0xx-equivalent bootstrap; H.61b: `false`/`nil`
-- at server/run start).
-- ============================================================================

function PlayerControllerRunEndLogic.NewRunEndState(): RunEndState
	return {
		beaconActivated = false,
		beaconActivatedAt = nil,
		hasRaisedWipe = false,
		hasRaisedVictory = false,
	}
end

-- ============================================================================
-- `_beaconActivated` latch lifecycle (GDD C.6 latch table).
-- ============================================================================

--- SET on `OnEscapeBeaconActivated` receipt. "Set ONCE, never re-set within a run"
--- (GDD C.6) is enforced HERE (idempotent no-op if already `true`) rather than left to
--- the caller's own discretion -- a defensive belt-and-braces against a duplicate or
--- replayed activation signal re-anchoring `beaconActivatedAt` and spuriously
--- extending the self-heal window. `now` is caller-supplied (the Knit wrapper's own
--- C.11 `getServerTime()` seam) -- this module never samples a clock itself.
function PlayerControllerRunEndLogic.ActivateBeaconLatch(state: RunEndState, now: number): ()
	if state.beaconActivated then
		return
	end
	state.beaconActivated = true
	state.beaconActivatedAt = now
end

--- The PRIMARY clear-path: the inbound `RunEnded` broadcast (any outcome). Also resets
--- BOTH raise-once guards -- a fresh run begins with a clean slate (H.61b's paired
--- "N+1-run fresh-start" case): `_beaconActivated`, `hasRaisedWipe`, and
--- `hasRaisedVictory` are all "per-run" state by the same GDD C.6 rule ("never
--- ratchets across run boundaries"), so all four fields reset together at the SAME
--- call site, never independently.
function PlayerControllerRunEndLogic.ClearOnRunEnded(state: RunEndState): ()
	state.beaconActivated = false
	state.beaconActivatedAt = nil
	state.hasRaisedWipe = false
	state.hasRaisedVictory = false
end

--- The SELF-HEAL predicate (R17-4): strict `>` per the GDD's own text
--- ("`getServerTime() - _beaconActivatedAt) > BEACON_LATCH_TIMEOUT`"). Pure predicate
--- only -- the caller (Knit wrapper) is responsible for the `warn()` call site
--- (`beacon-latch-timeout` tag) on a `true` result, matching
--- `PlayerControllerDeathReconciliationLogic.RunStalenessSweep`'s own
--- "returns what changed; caller logs" precedent.
function PlayerControllerRunEndLogic.ShouldSelfHealBeaconLatch(state: RunEndState, now: number, timeout: number): boolean
	return state.beaconActivated and state.beaconActivatedAt ~= nil and (now - (state.beaconActivatedAt :: number)) > timeout
end

--- The self-heal's ACTUAL mutation: force-clears `_beaconActivated`/`_beaconActivatedAt`
--- ONLY. Deliberately does NOT touch `hasRaisedWipe`/`hasRaisedVictory` -- unlike
--- `ClearOnRunEnded`, the self-heal is a "T7 terminal re-enabled" backstop, not a
--- "fresh run began" event (no `RunEnded` was ever actually delivered) -- a wipe raised
--- BEFORE the self-heal fired must still count against `hasRaisedWipe` (there is only
--- ever one run in progress; a self-heal mid-run must not let PC re-raise a condition
--- it already raised once for THIS run).
---
--- TRACED AND FOUND SAFE (code-review Finding 3, 2026-07-11): the only way
--- `hasRaisedWipe` can be `true` at the moment a self-heal fires is if PC already
--- called `RunEndConditionRaised("wipe", ...)` earlier THIS run -- and the REAL
--- `RunController:RunEndConditionRaised` (rc-1/rc-2) fires its `RunEnded` signal
--- SAME-VM synchronously, with no yield anywhere in the call chain (ADR-0001's
--- zero-yield `Signal:Fire()` dispatch guarantee). So either (a) the run has
--- ALREADY ended via that same raise (the arbiter's one-shot latch already fired
--- `RunEnded`, which -- absent a dropped/never-delivered broadcast, the exact
--- failure class this self-heal exists to backstop -- already cleared
--- `hasRaisedWipe` via `ClearOnRunEnded` long before the timeout could elapse), or
--- (b) this IS that dropped-broadcast case, in which case `hasRaisedWipe` staying
--- `true` is correct: PC must not re-raise a condition the (still-latched,
--- from PC's own local perspective) arbiter already received once. There is no
--- code path where `RunEndConditionRaised` is called, the call itself is lost
--- (not just its `RunEnded` reply), and PC could safely retry -- that would be a
--- caller-to-arbiter transport failure, a different failure class entirely, not
--- one this self-heal is designed to paper over.
function PlayerControllerRunEndLogic.ForceSelfHeal(state: RunEndState): ()
	state.beaconActivated = false
	state.beaconActivatedAt = nil
end

-- ============================================================================
-- T7 (whole-squad-wipe) -- GDD C.6 T7 row.
-- ============================================================================

--- The squad-level-condition half of T7, independent of the latch/raise-once guard:
--- true iff a non-empty squad has EVERY member in S4 AND the squad oxygen pool is
--- `< 1`. `squadSize > 0` guards the vacuous-truth degenerate case (an empty squad,
--- e.g. between server start and the first `PlayerAdded`, must never read as
--- "wiped"). The oxygen-below-1 comparison itself is done by the caller (a plain
--- `pool < 1` read against the existing C.5.1 `_getSquadOxygenPoolFn` seam) and
--- passed in as a boolean, per this module's own clock/external-state-injection
--- discipline (mirrors `IsGraceTimerActive`'s own caller-supplied-boolean shape).
function PlayerControllerRunEndLogic.IsWholeSquadWiped(squadSize: number, s4Count: number, squadOxygenBelowOne: boolean): boolean
	return squadSize > 0 and s4Count == squadSize and squadOxygenBelowOne
end

--- The FULL T7 raise decision: the squad condition above, AND NOT `_beaconActivated`
--- (GDD C.6 T7 row: "AND NOT `_beaconActivated`" -- post-activation the in-window wipe
--- terminal is Crafting's BCT-DEFEAT, raised via PC's own forwarding path, out of this
--- story's scope), AND the raise-once guard (`not state.hasRaisedWipe`) -- T7's
--- condition can remain continuously true across many reconciliation-tick evaluations
--- (e.g. the squad stays all-S4/oxygen-empty for several ticks before a `RunEnded`
--- ever arrives back), so the guard is what makes "raises exactly once" hold
--- (H.49/H.50/H.61) rather than re-raising every tick.
function PlayerControllerRunEndLogic.ShouldRaiseWipe(state: RunEndState, wholeSquadWiped: boolean): boolean
	return wholeSquadWiped and (not state.beaconActivated) and (not state.hasRaisedWipe)
end

function PlayerControllerRunEndLogic.MarkWipeRaised(state: RunEndState): ()
	state.hasRaisedWipe = true
end

-- ============================================================================
-- T8 (victory) -- GDD C.6 T8 row. Consumes `OnBeaconWindowSurvived` ONLY -- NEVER
-- `OnEscapeBeaconActivated` (H.47's regression target; the Knit wrapper's
-- `OnEscapeBeaconActivated` entry point calls only `ActivateBeaconLatch` above, never
-- anything in this section).
-- ============================================================================

--- T8's raise decision is simpler than T7's: `OnBeaconWindowSurvived` firing IS the
--- trigger (event-driven, not a per-tick poll re-evaluating a level condition) -- the
--- only guard needed is the raise-once flag itself, defending against a duplicate/
--- replayed survival signal.
function PlayerControllerRunEndLogic.ShouldRaiseVictory(state: RunEndState): boolean
	return not state.hasRaisedVictory
end

function PlayerControllerRunEndLogic.MarkVictoryRaised(state: RunEndState): ()
	state.hasRaisedVictory = true
end

-- ============================================================================
-- squadState snapshot construction (H.50: "a concrete per-member liveness snapshot
-- (deep-equal, not shape-only)").
-- ============================================================================

--- Maps a single player's `renderScope` to this story's own `squadState` value
--- vocabulary. `nil` (an uninitialized/never-seeded scope) maps to `"alive"` --
--- fail-open here is deliberate and safe: every real squad member reaching this
--- function came from `Players:GetPlayers()`, which by this codebase's own
--- `_initPlayerState` convention already seeds `"alive"` synchronously at
--- `PlayerAdded`, so a `nil` scope value is unreachable in production; the fallback
--- exists only so this function is total (never errors) for a test double that
--- forgets to seed a scope.
function PlayerControllerRunEndLogic.RenderScopeToSquadStateValue(scope: RenderScopeLike?): SquadStateValue
	if scope == "dead-respawning" then
		return "S4"
	elseif scope == "post-run" then
		return "S5"
	end
	return "alive"
end

--- Builds a FRESH plain table every call (never a live reference into any per-player
--- table the Knit wrapper owns) -- this is what makes the snapshot "deep-equal-able,
--- not shape-only" (H.50): two snapshots taken at two different raise moments are
--- independent tables the test can `expect(...).to.equal(...)`-style deep-compare
--- without either one being mutated out from under the assertion by a later state
--- change.
function PlayerControllerRunEndLogic.BuildSquadStateSnapshot(members: { SquadMemberEntry }): SquadStateSnapshot
	local snapshot: SquadStateSnapshot = {}
	for _, member in members do
		snapshot[member.userId] = PlayerControllerRunEndLogic.RenderScopeToSquadStateValue(member.scope)
	end
	return snapshot
end

-- ============================================================================
-- Respawn-timer cancellation (T8 S4-rescue / the inbound `RunEnded` handler's forced
-- S4->S5 transition for every squad member, regardless of outcome).
-- ============================================================================

--- Force-cancels `playerKey`'s in-flight respawn timer WITHOUT requiring
-- `RESPAWN_DELAY` to have elapsed -- unlike
--- `PlayerControllerDeathReconciliationLogic.TryRespawn` (pc-4), which is gated on
--- elapsed time and is the ONLY path that also re-spawns the player back to S1. A
--- run-end forcibly ends every pending respawn regardless of timer progress (the
--- player is going to S5, never back to S1) -- this function mirrors `TryRespawn`'s
--- own detach-bookkeeping (an already-`Committed` prior-life record is retired now;
--- an uncommitted `Pending`/`InFlight` record is NOT deleted -- it survives by
--- `deathEventId` and reconciles independently, ADR-0005's own rule, unchanged by this
--- forced path) but skips the elapsed-time gate entirely.
---
--- Returns `true` if `playerKey` was actually tracked as dead (a timer existed to
--- cancel), `false` if this is a no-op (the player was already alive/never died this
--- life) -- safe to call unconditionally for every squad member from the inbound
--- `RunEnded` handler, mirroring `TryRespawn`'s own "not tracked as dead is not an
--- error" contract.
function PlayerControllerRunEndLogic.ForceCancelRespawnTimer(state: ReconciliationStateLike, playerKey: any): boolean
	if state.deathStartedAt[playerKey] == nil then
		return false
	end

	local deathEventId = state.currentDeathRecord[playerKey]
	if deathEventId then
		local row = state.reconcileRows[deathEventId]
		if row and row.state == "Committed" then
			state.reconcileRows[deathEventId] = nil
		end
	end

	state.currentDeathRecord[playerKey] = nil
	state.deathInProgress[playerKey] = nil
	state.deathStartedAt[playerKey] = nil
	return true
end

return PlayerControllerRunEndLogic
