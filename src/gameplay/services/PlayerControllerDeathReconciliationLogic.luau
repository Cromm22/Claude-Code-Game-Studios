--!strict
-- PlayerControllerDeathReconciliationLogic
--
-- Pure domain logic for PlayerControllerService's death-cost reconciliation state
-- machine: deathEventId minting, the Pending/InFlight/Committed/Abandoned lifecycle
-- (with the load-bearing post-yield ownership re-check), the RESPAWN_DELAY=30s timer's
-- T6-detach decision, the reconciliation-tick scan + staleness sweep, and the
-- BindToClose -> Abandoned terminal transition. Deliberately has ZERO dependency on
-- Knit, any Roblox service call, OR any require() at all -- mirrors every sibling
-- PlayerController*Logic / DisturbanceService*Logic module's own zero-require
-- precedent (see PlayerControllerLocomotionStaminaLogic.luau / PlayerControllerEmission
-- PublisherLogic.luau), so it can be required and unit-tested directly under Lune.
--
-- Implements: production/epics/player-controller/story-004-death-cost-reconciliation-core.md
-- GDD: design/gdd/player-controller.md -- C.5.2 (RESPAWN_DELAY=30s + idempotent guard),
--      C.5.3 (DeathCostReconciliation state record, the four-state table, the
--      Pending->InFlight-before-any-yield rule, the post-yield ownership re-check,
--      the error-guard scoping, the reconciliation tick + staleness sweep, the
--      orphaned-row-vs-retained-until-T6 rule), C.6 T5/T6 rows (RESPAWN_DELAY timer
--      lifecycle, T6 currentDeathRecord detach), TR-pc-016/017/018/019/020/021/025/045
-- ADR: docs/architecture/adr-0005-death-respawn-lifecycle.md (THE LAW for this story --
--      the ratified Pending/InFlight/Committed/Abandoned state machine, the sole-minter
--      deathEventId contract, the post-yield re-check invariant, the C.11 getServerTime
--      seam requirement, the pcall/Promise-await-inside-pcall discipline)
--
-- SCOPE NOTE (Story 004, this module): implements ONLY the reconciliation state
-- machine's dispatch mechanics -- minting, the four-state lifecycle, the tick scan,
-- the staleness sweep, the T6 detach decision, and the BindToClose terminal
-- transition. Explicitly OUT OF SCOPE (per the story's own Out-of-Scope clause):
--   - Story 005: the T5/T6 side-effect PAYLOADS (ReleasePredatorLock,
--     OnPlayerS4Entered/OnPlayerT6Respawned, OnSquadMemberAliveChanged,
--     OnPlayerDied broadcast content, sprint/lantern hard-reset). This module
--     exposes the ORDERING HOOK POINTS (pre-yield / post-commit) that Story 005
--     will wire real payloads into (TR-pc-025) -- see PlayerControllerService.luau's
--     own `_preYieldDeathSideEffectsFn` / `_onDeathCommitFn` injectable seams.
--   - Story 006: Path B (`PlayerRemoving`-while-imminent) and the
--     `OXYGEN_GRACE_DURATION` squad-wide grace timer. This module's dispatch is
--     therefore IMMEDIATE at death (Path A only) -- Story 006 inserts a grace
--     window in FRONT of the dispatch call site this module exposes
--     (`BeginDispatch`), without needing to change this module's own state-machine
--     functions (see PlayerControllerService.luau's own header note for the exact
--     seam Story 006 is expected to use).
--   - Resource Management epic: `RequestSquadOxygenSpend`'s receiving-side dedup.
--     This module never calls it directly -- the Knit wrapper injects a function
--     value (`self._requestSquadOxygenSpendFn`), matching this codebase's
--     established injectable-stub precedent (DisturbanceService's
--     `_captureDeathLockSnapshot` / AttributionArchiveLogic's
--     `DefaultIsEmissionLocked`).
--
-- PLAYER IDENTITY (design call, matching DisturbanceServiceDeathFanoutLogic.luau's own
-- precedent verbatim): this module never references the `Player` type. Every
-- `playerKey` parameter is an opaque identity value, compared only via table-key
-- identity/`==` -- works identically for a real Roblox `Player` instance (referential
-- equality) and for the plain strings/tables this module's own test suite uses as
-- stand-ins.
--
-- RECONCILE ROW SHAPE (ADR-0005 FROZEN, do not add fields): `{deathEventId, userId,
-- state, inFlightSince}` -- exactly the ADR's own Key Interfaces `ReconcileRow` type,
-- verbatim. Orphan-detection (H.39) is done by SCANNING `state.currentDeathRecord`
-- for a live pointer to `row.deathEventId` at commit time (see `TryCommitDispatch`
-- below) rather than adding a `playerKey` field to the row itself -- keeps this
-- module's row shape byte-for-byte ADR-compliant.
--
-- SPLIT-DISPATCH DESIGN (REQUIRED for testability, not a stylistic choice): the
-- Pending->InFlight transition (`BeginDispatch`, synchronous, before any yield) and
-- the post-yield resolution (`TryCommitDispatch` / `RollbackIfStillInFlight`) are
-- exposed as SEPARATE functions, rather than one function that internally calls the
-- (Knit-wrapper-owned) oxygen-spend seam and pcalls it. This is what makes the H.54
-- staleness-sweep-late-success-discard race directly and deterministically testable
-- under Lune WITHOUT real coroutines/task.spawn: a test can call `BeginDispatch`,
-- then manually interleave `RunStalenessSweep` + a second full dispatch (simulating
-- "the sweep re-armed it and a second coroutine committed it"), THEN call
-- `TryCommitDispatch` again on the FIRST row reference (simulating the original
-- coroutine's late resolution) and assert it is discarded, not committed, not rolled
-- back. The real Knit wrapper's `_dispatchOxygenSpend`/`_completeDispatch` methods
-- compose these same two functions around the real (yield-capable) oxygen-spend call
-- and `task.spawn` -- see PlayerControllerService.luau.

export type ReconcileState = "Pending" | "InFlight" | "Committed" | "Abandoned"

--- ADR-0005 FROZEN shape -- see header note above. Do not add fields here; if a
--- future story needs more per-row bookkeeping, thread it through a SEPARATE
--- parallel table (matching DisturbanceService's own `_insertionSequence`-as-a-
--- separate-parallel-table precedent), not by growing this type.
export type ReconcileRow = {
	deathEventId: string,
	userId: number,
	state: ReconcileState,
	inFlightSince: number?, -- getServerTime() at Pending -> InFlight; nil while Pending/Abandoned
}

--- Opaque player identity -- see PLAYER IDENTITY note above.
export type PlayerIdentity = any

--- The full per-server-session reconciliation bookkeeping this module's orchestration
--- functions operate on. The Knit wrapper owns exactly one instance of this
--- (`self._deathReconciliationState`), constructed via `NewReconciliationState()` in
--- KnitInit (TR-pc-045).
export type ReconciliationState = {
	reconcileRows: { [string]: ReconcileRow }, -- keyed by deathEventId; survives T6 (ADR-0005)
	currentDeathRecord: { [PlayerIdentity]: string? }, -- playerKey -> deathEventId, detached at T6
	deathInProgress: { [PlayerIdentity]: boolean }, -- Humanoid.Died idempotent-guard flag, cleared at T6
	deathStartedAt: { [PlayerIdentity]: number }, -- RESPAWN_DELAY timer anchor, cleared at T6
	nextDeathEventIdCounter: number,
	lastTickTime: number?, -- nil until KnitStart seeds it; ShouldRunReconciliationTick tolerates nil (H.40)
}

local PlayerControllerDeathReconciliationLogic = {}

-- ============================================================================
-- Config knobs (data-driven: named + centralized here, not scattered magic numbers
-- in logic; kept LOCAL rather than a separate constants module -- matches
-- PlayerControllerEmissionPublisherLogic.luau's own established precedent for
-- genuinely PC-owned tunables under this harness's require() constraints).
-- ============================================================================

--- GDD C.5.2 / TR-pc-017. Range 10-60s per the GDD's own Tuning Knobs table.
PlayerControllerDeathReconciliationLogic.RESPAWN_DELAY = 30

--- GDD C.5.3 / TR-pc-021. Range 2-10s per the GDD's own Tuning Knobs table.
PlayerControllerDeathReconciliationLogic.RECONCILIATION_TICK_INTERVAL = 5.0

--- STALENESS SWEEP THRESHOLD -- design decision (ADR-0005 leaves this as an
--- explicit Open Question, "belongs to Player Controller's own implementation
--- detail, not a cross-service contract"). Chosen: `2 x RECONCILIATION_TICK_INTERVAL`
--- -- this is the exact bound the GDD's own H.38/H.54 text independently derives
--- ("the sweep threshold MUST stay >= 2 x RECONCILIATION_TICK_INTERVAL, never
--- tightened below it") and the nominal recovery-latency bound the GDD computes
--- ("a rolled-back row is recovered within at most 2 x RECONCILIATION_TICK_INTERVAL").
--- Registered here as a named constant (not an inline literal) per the story's own
--- instruction to register the choice, not just use it silently.
PlayerControllerDeathReconciliationLogic.STALENESS_SWEEP_THRESHOLD =
	2 * PlayerControllerDeathReconciliationLogic.RECONCILIATION_TICK_INTERVAL

--- GDD C.5.3 (fixed value per the GDD's own text) / ADR-0005 Key Interfaces sample.
--- Named constants rather than inline literals at the RequestSquadOxygenSpend call
--- site (code-review fix -- matches this module's own data-driven-knobs discipline
--- two paragraphs above).
PlayerControllerDeathReconciliationLogic.DEATH_OXYGEN_SPEND_AMOUNT = 1
PlayerControllerDeathReconciliationLogic.DEATH_OXYGEN_SPEND_REASON = "death"

-- ============================================================================
-- Construction (TR-pc-045: KnitInit bootstrap-inits all these tables).
-- ============================================================================

function PlayerControllerDeathReconciliationLogic.NewReconciliationState(): ReconciliationState
	return {
		reconcileRows = {},
		currentDeathRecord = {},
		deathInProgress = {},
		deathStartedAt = {},
		nextDeathEventIdCounter = 0,
		lastTickTime = nil,
	}
end

-- ============================================================================
-- deathEventId minting (TR-pc-020, ADR-0005 sole-minter contract) -- monotonic,
-- server-session-scoped, `("evt-%d"):format(n)` shape verbatim per the ADR's own
-- Key Interfaces sample.
-- ============================================================================

function PlayerControllerDeathReconciliationLogic.MintDeathEventId(counter: number): (string, number)
	local nextCounter = counter + 1
	return ("evt-%d"):format(nextCounter), nextCounter
end

-- ============================================================================
-- H.16/H.21/H.22/H.22e/TR-pc-016/017/019/020 -- BeginDeathFlow: the death-signal
-- entry point (called once per relayed OnPlayerDied fire, see the Knit wrapper's
-- `_onPlayerDied` handler). Owns the `_deathInProgress` idempotent guard (TR-pc-017)
-- AND the mint-and-create-record step (ADR-0005 step 1/2) as ONE atomic, yield-free
-- operation -- there is no yield anywhere in this function, so a replayed death
-- signal arriving before this function returns is not a real concern (Luau is
-- single-threaded within a synchronous call), and a replay arriving on a LATER tick
-- (after this function has already returned) is refused by the guard flag it just
-- set, which stays true until T6 (`TryRespawn` below).
-- ============================================================================

--- Returns (row, nil) on a fresh mint, or (nil, "already-in-progress") on a
--- double-fire no-op (H.22 same-tick/adjacent-tick, H.37b replayed-Died
--- short-circuit) -- the caller (Knit wrapper) never dispatches, never mints a
--- second `deathEventId`, and never resets `deathStartedAt` (the RESPAWN_DELAY
--- anchor) on the no-op path, per TR-pc-017's idempotent-guard requirement.
function PlayerControllerDeathReconciliationLogic.BeginDeathFlow(
	state: ReconciliationState,
	playerKey: PlayerIdentity,
	userId: number,
	now: number
): (ReconcileRow?, string?)
	if state.deathInProgress[playerKey] then
		return nil, "already-in-progress"
	end

	state.deathInProgress[playerKey] = true
	state.deathStartedAt[playerKey] = now -- RESPAWN_DELAY=30s timer anchor (TR-pc-017), same instant as the mint

	local deathEventId, nextCounter =
		PlayerControllerDeathReconciliationLogic.MintDeathEventId(state.nextDeathEventIdCounter)
	state.nextDeathEventIdCounter = nextCounter

	local row: ReconcileRow = {
		deathEventId = deathEventId,
		userId = userId,
		state = "Pending",
		inFlightSince = nil,
	}
	state.reconcileRows[deathEventId] = row
	state.currentDeathRecord[playerKey] = deathEventId

	return row, nil
end

-- ============================================================================
-- ADR-0005 step 2 -- Pending -> InFlight, SYNCHRONOUSLY, before any yield. This is
-- the single idempotency-and-no-double-dispatch guard (load-bearing rule, ADR-0005
-- Decision section) -- the Knit wrapper calls this, then TR-pc-025's pre-yield hook
-- points, THEN yields into the (task.spawn'd, for a tick dispatch) oxygen-spend call.
-- ============================================================================

function PlayerControllerDeathReconciliationLogic.BeginDispatch(row: ReconcileRow, now: number): ()
	-- Defense-in-depth (code-review hardening): every legitimate call site hands this
	-- a Pending row (fresh mint, or a row filtered through ScanPendingRows). A caller
	-- violating that precondition (e.g. a future Path-B wiring re-dispatching an
	-- already-InFlight row) would silently corrupt inFlightSince and defeat the
	-- staleness sweep for that row; fail loudly instead.
	assert(
		row.state == "Pending",
		("BeginDispatch precondition violated: row %s is %s, expected Pending"):format(row.deathEventId, row.state)
	)
	row.state = "InFlight"
	row.inFlightSince = now
end

-- ============================================================================
-- ADR-0005 step 4 (failure outcome) / H.64 (error-guard, pre-commit) -- rollback is
-- CONDITIONED on the row still being InFlight (GDD C.5.3 step 4's own SD-B4 scoping
-- note): both an ordinary `RequestSquadOxygenSpend` failure result AND an error
-- thrown before commit collapse to this same rollback, since the Knit wrapper wraps
-- the whole pre-commit span in one `pcall` (an error and a `pcall`-caught `ok=false`
-- are indistinguishable from this function's point of view -- both mean "the attempt
-- did not succeed"). Returns whether it actually rolled back (false if the row had
-- already left InFlight, e.g. a staleness-sweep re-arm already put it back to
-- Pending, or a prior call already resolved it) -- callers use this for
-- logging/test-observability, never to gate correctness (the function is already
-- idempotent/no-op-safe when it returns false).
-- ============================================================================

function PlayerControllerDeathReconciliationLogic.RollbackIfStillInFlight(row: ReconcileRow): boolean
	if row.state == "InFlight" then
		row.state = "Pending"
		row.inFlightSince = nil
		return true
	end
	return false
end

-- ============================================================================
-- ADR-0005 step 5 -- the load-bearing post-yield ownership re-check (R12-net-B2) +
-- H.39's orphaned-row-vs-retained-until-T6 removal decision.
-- ============================================================================

--- Returns (committed, removedAsOrphan):
---   - `committed=false` -- the row was NOT still InFlight when this resolved (a
---     staleness-sweep re-arm mid-yield, or the row was already resolved by a prior
---     call) -- H.54's discard path: no commit, no rollback, no double-broadcast.
---     `removedAsOrphan` is always false in this branch.
---   - `committed=true, removedAsOrphan=false` -- committed AND retained in
---     `state.reconcileRows` (some `state.currentDeathRecord` pointer still points
---     at this `deathEventId` -- the row survives until that player's T6 /
---     `PlayerRemoving`, per ADR-0005's N-2 replayed-Died-double-deduct guard).
---   - `committed=true, removedAsOrphan=true` -- committed AND immediately removed
---     from `state.reconcileRows` (H.39: no live pointer references this
---     `deathEventId` at commit time -- e.g. this player's T6 already detached the
---     pointer while this row was still Pending/InFlight -- there is no present
---     identity that could replay a death signal against it, so nothing needs to
---     wait for).
function PlayerControllerDeathReconciliationLogic.TryCommitDispatch(
	state: ReconciliationState,
	row: ReconcileRow
): (boolean, boolean)
	if row.state ~= "InFlight" then
		-- Discarded (H.54): the sweep re-armed this row to Pending (or a fresher
		-- coroutine already resolved it) during this coroutine's own yield. Logged
		-- by the caller, not here (this module never calls warn()/print()).
		return false, false
	end

	row.state = "Committed"

	-- H.39 orphan check: does ANY currently-tracked player identity still point at
	-- this deathEventId? O(squad size), bounded at 4.
	local isOrphan = true
	for _, pointedDeathEventId in state.currentDeathRecord do
		if pointedDeathEventId == row.deathEventId then
			isOrphan = false
			break
		end
	end

	if isOrphan then
		state.reconcileRows[row.deathEventId] = nil
		return true, true
	end

	return true, false
end

-- ============================================================================
-- ADR-0005 `BindToClose` -> Abandoned terminal transition (H.42, MANUAL-DEVICE --
-- directly-callable, not exercised via a real engine BindToClose firing under this
-- harness).
-- ============================================================================

--- Transitions a single row Pending/InFlight -> Abandoned. Returns whether it
--- actually transitioned (false if the row was already Committed/Abandoned --
--- idempotent-safe to call more than once).
function PlayerControllerDeathReconciliationLogic.AbandonRow(row: ReconcileRow): boolean
	if row.state == "Pending" or row.state == "InFlight" then
		row.state = "Abandoned"
		row.inFlightSince = nil
		return true
	end
	return false
end

--- Sweeps every row in `reconcileRows`, abandoning every Pending/InFlight row.
--- Returns the list of rows that were actually abandoned this call (for
--- ops-log warn() call sites at the real call site).
function PlayerControllerDeathReconciliationLogic.RunBindToClose(reconcileRows: { [string]: ReconcileRow }): { ReconcileRow }
	local abandoned: { ReconcileRow } = {}
	for _, row in reconcileRows do
		if PlayerControllerDeathReconciliationLogic.AbandonRow(row) then
			table.insert(abandoned, row)
		end
	end
	return abandoned
end

-- ============================================================================
-- Reconciliation tick (TR-pc-021, GDD C.5.3) -- tick-interval gate (H.40 first-tick
-- safety), the tick-scan (H.37a skips Committed/InFlight/Abandoned rows structurally
-- -- only "Pending" is ever selected), and the staleness sweep (H.54/H.38).
-- ============================================================================

--- H.40: first-tick bootstrap safety -- a `nil` `lastTickTime` (module-construction
--- time, before the Knit wrapper's KnitStart seeds it to `getServerTime()`) is
--- treated as "eligible" rather than evaluating `now - nil`, which would raise a
--- runtime error and (in the real Heartbeat-bound caller) kill the reconciliation
--- tick for the entire server session. Strict `>` per the GDD's own gate text.
function PlayerControllerDeathReconciliationLogic.ShouldRunReconciliationTick(
	lastTickTime: number?,
	now: number,
	interval: number
): boolean
	if lastTickTime == nil then
		return true
	end
	return (now - lastTickTime) > interval
end

--- H.54/H.38 belt-and-braces staleness sweep: re-arms any InFlight row whose
--- `inFlightSince` is older than `threshold` (recommended `STALENESS_SWEEP_THRESHOLD`)
--- back to Pending, clearing `inFlightSince` (H.56's declared-field lifecycle).
--- Strict `>` per the GDD's own sweep predicate text. Returns the list of rows
--- actually re-armed this call (for ops-log warn() call sites / test observability).
function PlayerControllerDeathReconciliationLogic.RunStalenessSweep(
	reconcileRows: { [string]: ReconcileRow },
	now: number,
	threshold: number
): { ReconcileRow }
	local reArmed: { ReconcileRow } = {}
	for _, row in reconcileRows do
		if row.state == "InFlight" and row.inFlightSince ~= nil and (now - (row.inFlightSince :: number)) > threshold then
			row.state = "Pending"
			row.inFlightSince = nil
			table.insert(reArmed, row)
		end
	end
	return reArmed
end

--- H.37a: the tick-scan's own eligibility predicate -- `reconcile_eligible(row) =
--- (row.state == "Pending")`, per the GDD's own "single clause" text verbatim. A
--- retained Committed row, an Abandoned row, and a still-InFlight row (not yet aged
--- past the staleness threshold) are all structurally skipped -- this function
--- never inspects any state field except `state == "Pending"`.
function PlayerControllerDeathReconciliationLogic.ScanPendingRows(reconcileRows: { [string]: ReconcileRow }): { ReconcileRow }
	local eligible: { ReconcileRow } = {}
	for _, row in reconcileRows do
		if row.state == "Pending" then
			table.insert(eligible, row)
		end
	end
	return eligible
end

-- ============================================================================
-- T6 (respawn) -- RESPAWN_DELAY timer elapse decision + record-pointer detach
-- (H.22e, H.41). Only the reconciliation-state-machine slice of T6 lives here --
-- the real respawn side effects (anchor placement, stamina reset, lantern reset,
-- etc.) are Story 005/006's scope; this function only answers "has enough time
-- elapsed, and if so, what does the reconciliation bookkeeping do about it."
-- ============================================================================

--- Returns true if `playerKey` respawned this call (RESPAWN_DELAY elapsed since
--- `BeginDeathFlow` last set `deathStartedAt[playerKey]`), false otherwise
--- (including "this player is not currently tracked as dead," which is not an
--- error -- a player who never died, or who already respawned, simply has no
--- `deathStartedAt` entry).
---
--- On respawn: clears `deathInProgress[playerKey]` (TR-pc-017: "cleared at T6" --
--- this is what makes H.22e's life-2 death mint a FRESH deathEventId instead of
--- being refused as a double-fire) and `currentDeathRecord[playerKey]`
--- (ADR-0005: "T6 detaches currentDeathRecord[player]; never deletes an
--- uncommitted prior-life record"). If the detached record is `Committed`, it is
--- ALSO removed from `reconcileRows` now (the N-2 replayed-Died-double-deduct
--- guard's job ends once this player has respawned -- a stale corpse instance
--- from a life this player has already left cannot replay `Humanoid.Died`
--- against this record anymore). A `Pending`/`InFlight` prior-life record is left
--- untouched -- it survives by `deathEventId` and continues to reconcile.
--- Comparator is inclusive `>=` (a respawn timer reaching EXACTLY RESPAWN_DELAY
--- has elapsed).
function PlayerControllerDeathReconciliationLogic.TryRespawn(
	state: ReconciliationState,
	playerKey: PlayerIdentity,
	now: number,
	respawnDelay: number
): boolean
	local startedAt = state.deathStartedAt[playerKey]
	if startedAt == nil then
		return false
	end
	if (now - startedAt) < respawnDelay then
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

return PlayerControllerDeathReconciliationLogic
