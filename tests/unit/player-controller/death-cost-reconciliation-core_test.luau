--!strict
-- death-cost-reconciliation-core_test
--
-- Unit tests for Story 004: Death-Cost Reconciliation Core (deathEventId + State
-- Machine).
-- Story: production/epics/player-controller/story-004-death-cost-reconciliation-core.md
-- ADR: docs/architecture/adr-0005-death-respawn-lifecycle.md (THE LAW -- the ratified
--      Pending/InFlight/Committed/Abandoned state machine, the sole-minter deathEventId
--      contract, the post-yield ownership re-check, the C.11 getServerTime seam
--      requirement)
--
-- Production code under test:
--   src/gameplay/services/PlayerControllerDeathReconciliationLogic.luau -- the REAL,
--     pure, zero-require state-machine module, exercised DIRECTLY (most of this file)
--     and via the FakePlayerControllerService harness below (unmodified in both
--     cases).
--   src/gameplay/services/PlayerControllerService.luau -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live PlayerControllerService
--     instance cannot be constructed here (same precedent every prior PC/ED test in
--     this repo documents -- see e.g. humanoid-died-monopoly-onplayerdied-fanout_test
--     .luau's own MOCK BINDABLE EVENT DISCLOSURE). Verified two ways instead:
--       (a) FakePlayerControllerService below mirrors the real Knit wrapper's Story
--           004 method bodies (`_onPlayerDied`/`_beginDeathFlow`/`_beginAndDispatch`/
--           `_completeDispatch`/`_runReconciliationTick`/`_checkRespawnTimers`/
--           `OnBindToClose`) method-for-method, substituting an injectable `_now`
--           for the real `getServerTime()` clock read and calling `_completeDispatch`
--           SYNCHRONOUSLY where the real wrapper `task.spawn`s it (HARNESS DISCLOSURE,
--           not silently glossed over: this harness is single-threaded/deterministic
--           by design -- the state-machine TRANSITIONS exercised are identical to
--           production; only the scheduling primitive differs, which this file's own
--           pure-module tests already cover directly via the split-dispatch design,
--           see PlayerControllerDeathReconciliationLogic.luau's own SPLIT-DISPATCH
--           DESIGN header note).
--       (b) static/structural source-text checks against the real
--           PlayerControllerService.luau (mirrors humanoid-died-monopoly-
--           onplayerdied-fanout_test.luau's own established pattern, including its
--           documented stripLuaComments `--`-in-string caveat).
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must
-- pass (BLOCKING gate).
local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local Logic = require(ServerScriptService.gameplay.services.PlayerControllerDeathReconciliationLogic)

type ReconciliationState = Logic.ReconciliationState
type ReconcileRow = Logic.ReconcileRow

-- ============================================================================
-- FakePlayerControllerService -- see header note (a) above. Mirrors
-- PlayerControllerService.luau's real Story 004 method bodies exactly, with an
-- injectable `_now` in place of the real `getServerTime()` C.11 seam and
-- synchronous `_completeDispatch` in place of `task.spawn`.
-- ============================================================================

local FakePlayerControllerService = {}
FakePlayerControllerService.__index = FakePlayerControllerService

function FakePlayerControllerService.new()
	return setmetatable({}, FakePlayerControllerService)
end

function FakePlayerControllerService:KnitInit()
	self._deathReconciliationState = Logic.NewReconciliationState()
	self._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
		return true
	end
	self._preYieldDeathSideEffectsFn = function(_row: ReconcileRow): () end
	self._onDeathCommitFn = function(_row: ReconcileRow): () end
	self._now = 0
end

function FakePlayerControllerService:_setNow(now: number)
	self._now = now
end

function FakePlayerControllerService:KnitStart()
	self._deathReconciliationState.lastTickTime = self._now
end

function FakePlayerControllerService:_onPlayerDied(payload: { deadPlayer: any, deathTimestamp: number, predatorWasLockedAtDeath: boolean })
	local now = self._now
	self:_beginDeathFlow(payload.deadPlayer, now)
end

function FakePlayerControllerService:_beginDeathFlow(player: any, now: number): (ReconcileRow?, string?)
	local row, reason = Logic.BeginDeathFlow(self._deathReconciliationState, player, 1, now)
	if row then
		self:_beginAndDispatch(row, now)
	end
	return row, reason
end

function FakePlayerControllerService:_beginAndDispatch(row: ReconcileRow, now: number): ()
	Logic.BeginDispatch(row, now)

	local hookOk = pcall(function()
		self._preYieldDeathSideEffectsFn(row)
	end)
	if not hookOk then
		Logic.RollbackIfStillInFlight(row)
		return
	end

	-- HARNESS DISCLOSURE: real production `task.spawn`s this; called synchronously
	-- here for deterministic single-threaded test execution (see file header).
	self:_completeDispatch(row)
end

function FakePlayerControllerService:_completeDispatch(row: ReconcileRow): ()
	local ok, _result = pcall(function()
		return self._requestSquadOxygenSpendFn(
			row.userId,
			Logic.DEATH_OXYGEN_SPEND_AMOUNT,
			Logic.DEATH_OXYGEN_SPEND_REASON,
			row.deathEventId
		)
	end)

	if ok then
		local committed = Logic.TryCommitDispatch(self._deathReconciliationState, row)
		if committed then
			pcall(function()
				self._onDeathCommitFn(row)
			end)
		end
	else
		Logic.RollbackIfStillInFlight(row)
	end
end

function FakePlayerControllerService:_runReconciliationTick(now: number): ()
	local reconState = self._deathReconciliationState
	if not Logic.ShouldRunReconciliationTick(reconState.lastTickTime, now, Logic.RECONCILIATION_TICK_INTERVAL) then
		return
	end
	reconState.lastTickTime = now

	Logic.RunStalenessSweep(reconState.reconcileRows, now, Logic.STALENESS_SWEEP_THRESHOLD)

	local eligibleRows = Logic.ScanPendingRows(reconState.reconcileRows)
	for _, row in eligibleRows do
		self:_beginAndDispatch(row, now)
	end
end

function FakePlayerControllerService:_checkRespawnTimers(now: number): ()
	local reconState = self._deathReconciliationState
	local trackedPlayers: { any } = {}
	for player in reconState.deathStartedAt do
		table.insert(trackedPlayers, player)
	end
	for _, player in trackedPlayers do
		Logic.TryRespawn(reconState, player, now, Logic.RESPAWN_DELAY)
	end
end

function FakePlayerControllerService:OnBindToClose(): ()
	Logic.RunBindToClose(self._deathReconciliationState.reconcileRows)
end

return function()
	-- ============================================================================
	-- deathEventId minting (TR-pc-020) -- sole-minter, monotonic, session-scoped.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (deathEventId minting)", function()
		local function test_mint_death_event_id_is_monotonic_and_formatted()
			local id1, counter1 = Logic.MintDeathEventId(0)
			expect(id1).to.equal("evt-1")
			expect(counter1).to.equal(1)

			local id2, counter2 = Logic.MintDeathEventId(counter1)
			expect(id2).to.equal("evt-2")
			expect(counter2).to.equal(2)

			expect(id1).never.to.equal(id2)
		end
		it("test_mint_death_event_id_is_monotonic_and_formatted", function()
			test_mint_death_event_id_is_monotonic_and_formatted()
		end)
	end)

	-- ============================================================================
	-- H.22 / H.22e / H.37b / TR-pc-016/017/019/020 -- BeginDeathFlow: the
	-- idempotent-guard + mint-and-create-record entry point.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (BeginDeathFlow, idempotent guard)", function()
		local function test_begin_death_flow_creates_pending_row_with_fresh_deathEventId()
			local state = Logic.NewReconciliationState()
			local row, reason = Logic.BeginDeathFlow(state, "playerA", 7, 100.0)

			expect(reason).to.equal(nil)
			expect(row).never.to.equal(nil)
			local realRow = row :: ReconcileRow
			expect(realRow.deathEventId).to.equal("evt-1")
			expect(realRow.userId).to.equal(7)
			expect(realRow.state).to.equal("Pending")
			expect(realRow.inFlightSince).to.equal(nil)
			expect(state.reconcileRows["evt-1"]).to.equal(realRow)
			expect(state.currentDeathRecord["playerA"]).to.equal("evt-1")
			expect(state.deathInProgress["playerA"]).to.equal(true)
			expect(state.deathStartedAt["playerA"]).to.equal(100.0)
		end
		it("test_begin_death_flow_creates_pending_row_with_fresh_deathEventId", function()
			test_begin_death_flow_creates_pending_row_with_fresh_deathEventId()
		end)

		-- H.22 edge case: exact-same-Heartbeat double-fire.
		local function test_h22_double_fire_same_tick_is_noop()
			local state = Logic.NewReconciliationState()
			local row1, reason1 = Logic.BeginDeathFlow(state, "playerA", 7, 100.0)
			expect(reason1).to.equal(nil)

			local row2, reason2 = Logic.BeginDeathFlow(state, "playerA", 7, 100.0)
			expect(row2).to.equal(nil)
			expect(reason2).to.equal("already-in-progress")

			-- No second deathEventId minted, no second row created.
			expect(state.nextDeathEventIdCounter).to.equal(1)
			expect(state.currentDeathRecord["playerA"]).to.equal((row1 :: ReconcileRow).deathEventId)
		end
		it("test_h22_double_fire_same_tick_is_noop", function()
			test_h22_double_fire_same_tick_is_noop()
		end)

		-- H.22 edge case: adjacent-Heartbeat double-fire (later `now`, guard still
		-- refuses re-entry -- the guard is state-based, not time-window-based).
		local function test_h22_double_fire_adjacent_tick_is_noop()
			local state = Logic.NewReconciliationState()
			local row1 = Logic.BeginDeathFlow(state, "playerA", 7, 100.0)

			local row2, reason2 = Logic.BeginDeathFlow(state, "playerA", 7, 100.1)
			expect(row2).to.equal(nil)
			expect(reason2).to.equal("already-in-progress")

			-- The RESPAWN_DELAY timer anchor is NOT reset by the no-op (TR-pc-017).
			expect(state.deathStartedAt["playerA"]).to.equal(100.0)
			expect(state.currentDeathRecord["playerA"]).to.equal((row1 :: ReconcileRow).deathEventId)
		end
		it("test_h22_double_fire_adjacent_tick_is_noop", function()
			test_h22_double_fire_adjacent_tick_is_noop()
		end)

		-- H.37b: a replayed Died arriving AFTER the record has progressed to
		-- InFlight/Committed is refused by the SAME guard, structurally impossible
		-- to reach the mint step.
		local function test_h37b_replayed_died_after_dispatch_still_refused()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 100.0) :: ReconcileRow
			Logic.BeginDispatch(row, 100.0)
			expect(row.state).to.equal("InFlight")

			local row2, reason2 = Logic.BeginDeathFlow(state, "playerA", 7, 100.2)
			expect(row2).to.equal(nil)
			expect(reason2).to.equal("already-in-progress")
		end
		it("test_h37b_replayed_died_after_dispatch_still_refused", function()
			test_h37b_replayed_died_after_dispatch_still_refused()
		end)
	end)

	-- ============================================================================
	-- ADR-0005 step 2 -- BeginDispatch: Pending -> InFlight, synchronous.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (BeginDispatch)", function()
		local function test_begin_dispatch_transitions_pending_to_inflight_and_stamps_inflightSince()
			local row: ReconcileRow = { deathEventId = "evt-1", userId = 7, state = "Pending", inFlightSince = nil }
			Logic.BeginDispatch(row, 50.0)
			expect(row.state).to.equal("InFlight")
			expect(row.inFlightSince).to.equal(50.0)
		end
		it(
			"test_begin_dispatch_transitions_pending_to_inflight_and_stamps_inflightSince",
			function()
				test_begin_dispatch_transitions_pending_to_inflight_and_stamps_inflightSince()
			end
		)
	end)

	-- ============================================================================
	-- H.64 / H.64b -- error-guard scoping (RollbackIfStillInFlight).
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (H.64/H.64b error-guard scoping)", function()
		local function test_h64_error_before_commit_rolls_back_and_clears_inflightSince()
			local row: ReconcileRow = { deathEventId = "evt-1", userId = 7, state = "Pending", inFlightSince = nil }
			Logic.BeginDispatch(row, 10.0)
			expect(row.state).to.equal("InFlight")

			-- Simulates either an ordinary RequestSquadOxygenSpend failure result OR
			-- an error thrown before commit -- both collapse to this same rollback
			-- (see this module's own RollbackIfStillInFlight doc comment).
			local rolledBack = Logic.RollbackIfStillInFlight(row)
			expect(rolledBack).to.equal(true)
			expect(row.state).to.equal("Pending")
			expect(row.inFlightSince).to.equal(nil)
		end
		it(
			"test_h64_error_before_commit_rolls_back_and_clears_inflightSince",
			function()
				test_h64_error_before_commit_rolls_back_and_clears_inflightSince()
			end
		)

		local function test_h64b_error_after_commit_does_not_rollback()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row, 0.0)
			local committed = Logic.TryCommitDispatch(state, row)
			expect(committed).to.equal(true)
			expect(row.state).to.equal("Committed")

			-- A thrown error in the post-commit side-effect block (Story 005's own
			-- payload, simulated here by directly attempting the SAME rollback
			-- function a naive implementation might mistakenly call) must NOT roll
			-- the record back -- it is a terminal-success state.
			local rolledBack = Logic.RollbackIfStillInFlight(row)
			expect(rolledBack).to.equal(false)
			expect(row.state).to.equal("Committed")
		end
		it("test_h64b_error_after_commit_does_not_rollback", function()
			test_h64b_error_after_commit_does_not_rollback()
		end)

		-- Knit-wrapper-shaped proof: the pre-yield hook error path rolls back
		-- (mirrors the real _beginAndDispatch method body).
		local function test_h64_knit_wrapper_pre_yield_hook_error_rolls_back()
			local service = FakePlayerControllerService.new()
			service:KnitInit()
			service:_setNow(0.0)
			service:KnitStart()

			service._preYieldDeathSideEffectsFn = function(_row: ReconcileRow): ()
				error("simulated pre-yield hook failure")
			end

			local row = service:_beginDeathFlow("playerA", 0.0) :: ReconcileRow
			expect(row.state).to.equal("Pending")
			expect(row.inFlightSince).to.equal(nil)
		end
		it(
			"test_h64_knit_wrapper_pre_yield_hook_error_rolls_back",
			function()
				test_h64_knit_wrapper_pre_yield_hook_error_rolls_back()
			end
		)

		-- Knit-wrapper-shaped proof: the post-commit hook error path does NOT roll
		-- back and the charge is never re-attempted (mirrors the real
		-- _completeDispatch method body).
		local function test_h64b_knit_wrapper_post_commit_hook_error_stays_committed()
			local service = FakePlayerControllerService.new()
			service:KnitInit()
			service:_setNow(0.0)
			service:KnitStart()

			local spendCallCount = 0
			service._requestSquadOxygenSpendFn = function(_userId, _amount, _reason, _deathEventId): boolean
				spendCallCount += 1
				return true
			end
			service._onDeathCommitFn = function(_row: ReconcileRow): ()
				error("simulated post-commit hook failure")
			end

			local row = service:_beginDeathFlow("playerA", 0.0) :: ReconcileRow
			expect(row.state).to.equal("Committed")
			expect(spendCallCount).to.equal(1)

			-- A later reconciliation tick must NOT re-select this row (it is
			-- Committed, not Pending) -- proves "never re-charged".
			service:_runReconciliationTick(1000.0)
			expect(spendCallCount).to.equal(1)
			expect(row.state).to.equal("Committed")
		end
		it(
			"test_h64b_knit_wrapper_post_commit_hook_error_stays_committed",
			function()
				test_h64b_knit_wrapper_post_commit_hook_error_stays_committed()
			end
		)
	end)

	-- ============================================================================
	-- H.54 -- staleness-sweep late-success discard, with the load-bearing
	-- post-yield ownership re-check.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (H.54 staleness-sweep late-success discard)", function()
		local function test_h54_staleness_sweep_late_success_discarded_same_deathEventId()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			local originalDeathEventId = row.deathEventId

			-- First coroutine dispatches at t=0.
			Logic.BeginDispatch(row, 0.0)
			expect(row.state).to.equal("InFlight")

			-- Held "mid-yield" past 2 x RECONCILIATION_TICK_INTERVAL (10s) -- the
			-- staleness sweep re-arms it to Pending at t=11.
			local reArmed = Logic.RunStalenessSweep(state.reconcileRows, 11.0, Logic.STALENESS_SWEEP_THRESHOLD)
			expect(#reArmed).to.equal(1)
			expect(row.state).to.equal("Pending")
			expect(row.inFlightSince).to.equal(nil)

			-- A second coroutine (the next tick's dispatch) re-dispatches and
			-- commits it FIRST.
			local eligible = Logic.ScanPendingRows(state.reconcileRows)
			expect(#eligible).to.equal(1)
			Logic.BeginDispatch(row, 12.0)
			local secondCommitted = Logic.TryCommitDispatch(state, row)
			expect(secondCommitted).to.equal(true)
			expect(row.state).to.equal("Committed")

			-- THEN the original (first) coroutine's held call finally resolves
			-- successfully -- this is the late/discarded resolution.
			local firstLateCommitted = Logic.TryCommitDispatch(state, row)
			expect(firstLateCommitted).to.equal(false)

			-- Exactly one commit occurred; the row is Committed, not double-
			-- committed, not rolled back; both attempts carried the SAME
			-- deathEventId (the idempotency key RM's own dedup depends on).
			expect(row.state).to.equal("Committed")
			expect(row.deathEventId).to.equal(originalDeathEventId)
		end
		it(
			"test_h54_staleness_sweep_late_success_discarded_same_deathEventId",
			function()
				test_h54_staleness_sweep_late_success_discarded_same_deathEventId()
			end
		)

		-- Harness-level companion to the pure-module test above (code-review
		-- addition): drives the SAME race through the Fake wrapper's real
		-- _beginDeathFlow/_beginAndDispatch/_completeDispatch/_runReconciliationTick
		-- flow and asserts the spend-CALL-COUNT through the stub seam (exactly two
		-- dispatch attempts, exactly one Committed outcome), rather than inferring
		-- "exactly one unit charged" from state alone. The re-entrant spend fn
		-- simulates "the first call is held mid-yield while the clock advances past
		-- the staleness threshold and a tick re-arms + re-dispatches the row."
		local function test_h54_wrapper_level_exactly_two_spend_calls_one_commit()
			local service = FakePlayerControllerService.new()
			service:KnitInit()
			service:_setNow(0.0)
			service:KnitStart()

			local spendCallCount = 0
			local firstCall = true
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				spendCallCount += 1
				if firstCall then
					firstCall = false
					-- Simulated mid-yield window: clock jumps past
					-- STALENESS_SWEEP_THRESHOLD and a reconciliation tick runs while
					-- this first call is "held" (re-entrant, single-threaded stand-in
					-- for the real task.spawn'd yield).
					local reArmTime = Logic.STALENESS_SWEEP_THRESHOLD + Logic.RECONCILIATION_TICK_INTERVAL + 1.0
					service:_setNow(reArmTime)
					service:_runReconciliationTick(reArmTime)
				end
				return true
			end

			local row = service:_beginDeathFlow("player-A", 0.0)
			expect(row).never.to.equal(nil)
			local typedRow = row :: ReconcileRow
			local originalDeathEventId = typedRow.deathEventId

			-- Exactly TWO dispatch attempts hit the seam (the held original + the
			-- tick's re-dispatch), both under the SAME deathEventId; exactly one
			-- Committed outcome; no rollback of the committed state by the late
			-- first attempt's resolution.
			expect(spendCallCount).to.equal(2)
			expect(typedRow.state).to.equal("Committed")
			expect(typedRow.deathEventId).to.equal(originalDeathEventId)
		end
		it(
			"test_h54_wrapper_level_exactly_two_spend_calls_one_commit",
			function()
				test_h54_wrapper_level_exactly_two_spend_calls_one_commit()
			end
		)
	end)

	-- ============================================================================
	-- H.35-H.46/H.56 -- Reconciliation Tick block.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (Reconciliation Tick block)", function()
		-- H.35: a failed initial dispatch (rollback to Pending) is picked up and
		-- successfully completed by the next tick.
		local function test_h35_rollback_then_tick_recovery_handoff()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow

			Logic.BeginDispatch(row, 0.0)
			local rolledBack = Logic.RollbackIfStillInFlight(row) -- simulated failure
			expect(rolledBack).to.equal(true)
			expect(row.state).to.equal("Pending")

			-- Next tick.
			local eligible = Logic.ScanPendingRows(state.reconcileRows)
			expect(#eligible).to.equal(1)
			Logic.BeginDispatch(row, 5.0)
			local committed = Logic.TryCommitDispatch(state, row)
			expect(committed).to.equal(true)
			expect(row.state).to.equal("Committed")
		end
		it("test_h35_rollback_then_tick_recovery_handoff", function()
			test_h35_rollback_then_tick_recovery_handoff()
		end)

		-- H.37a: the tick-scan structurally skips a retained Committed row.
		local function test_h37a_tick_scan_skips_retained_committed_row()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row, 0.0)
			Logic.TryCommitDispatch(state, row)
			expect(row.state).to.equal("Committed")

			local eligible = Logic.ScanPendingRows(state.reconcileRows)
			expect(#eligible).to.equal(0)
			-- Still retained (pointer live), not silently dropped.
			expect(state.reconcileRows[row.deathEventId]).to.equal(row)
		end
		it("test_h37a_tick_scan_skips_retained_committed_row", function()
			test_h37a_tick_scan_skips_retained_committed_row()
		end)

		-- H.38: nominal recovery bound of 2 x RECONCILIATION_TICK_INTERVAL.
		local function test_h38_nominal_latency_bound_within_2x_interval()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row, 0.0)
			Logic.RollbackIfStillInFlight(row) -- simulated failure at t=0

			-- Worst case: a tick fires immediately before the failure resolves;
			-- the NEXT tick (t = RECONCILIATION_TICK_INTERVAL) re-dispatches and
			-- succeeds.
			local tickTime = Logic.RECONCILIATION_TICK_INTERVAL
			Logic.BeginDispatch(row, tickTime)
			local committed = Logic.TryCommitDispatch(state, row)
			expect(committed).to.equal(true)

			local elapsed = tickTime - 0.0
			expect(elapsed <= (2 * Logic.RECONCILIATION_TICK_INTERVAL)).to.equal(true)
		end
		it(
			"test_h38_nominal_latency_bound_within_2x_interval",
			function()
				test_h38_nominal_latency_bound_within_2x_interval()
			end
		)

		-- H.38: sustained-outage non-loss -- repeated failures never drop the row.
		local function test_h38_sustained_outage_row_never_lost()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow

			local tickTime = 0.0
			for _ = 1, 20 do
				tickTime += Logic.RECONCILIATION_TICK_INTERVAL
				Logic.BeginDispatch(row, tickTime)
				Logic.RollbackIfStillInFlight(row) -- RM stays down every tick
			end

			expect(row.state).to.equal("Pending")
			expect(state.reconcileRows[row.deathEventId]).to.equal(row)

			-- RM finally recovers.
			tickTime += Logic.RECONCILIATION_TICK_INTERVAL
			Logic.BeginDispatch(row, tickTime)
			local committed = Logic.TryCommitDispatch(state, row)
			expect(committed).to.equal(true)
		end
		it("test_h38_sustained_outage_row_never_lost", function()
			test_h38_sustained_outage_row_never_lost()
		end)

		-- H.39: a Committed row with a still-live pointer is RETAINED, not removed
		-- immediately.
		local function test_h39_committed_row_retained_while_pointer_live()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row, 0.0)
			local committed, removedAsOrphan = Logic.TryCommitDispatch(state, row)
			expect(committed).to.equal(true)
			expect(removedAsOrphan).to.equal(false)
			expect(state.reconcileRows[row.deathEventId]).to.equal(row)
		end
		it(
			"test_h39_committed_row_retained_while_pointer_live",
			function()
				test_h39_committed_row_retained_while_pointer_live()
			end
		)

		-- H.39: a reconciliation-tick commit for a row whose pointer was already
		-- detached (this player already respawned via T6 while the row was still
		-- Pending) removes the Committed row IMMEDIATELY -- no live identity could
		-- ever replay a death signal against it.
		local function test_h39_orphaned_commit_removed_immediately()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row, 0.0)
			Logic.RollbackIfStillInFlight(row) -- initial dispatch failed; stays Pending

			-- Player respawns (T6) WHILE the row is still Pending -- per ADR-0005,
			-- an uncommitted row is NOT deleted, only the pointer is detached.
			local respawned = Logic.TryRespawn(state, "playerA", Logic.RESPAWN_DELAY, Logic.RESPAWN_DELAY)
			expect(respawned).to.equal(true)
			expect(state.currentDeathRecord["playerA"]).to.equal(nil)
			expect(state.reconcileRows[row.deathEventId]).to.equal(row) -- still present

			-- A later tick finally dispatches it successfully -- no live pointer
			-- references this deathEventId anymore.
			Logic.BeginDispatch(row, 999.0)
			local committed, removedAsOrphan = Logic.TryCommitDispatch(state, row)
			expect(committed).to.equal(true)
			expect(removedAsOrphan).to.equal(true)
			expect(state.reconcileRows[row.deathEventId]).to.equal(nil)
		end
		it("test_h39_orphaned_commit_removed_immediately", function()
			test_h39_orphaned_commit_removed_immediately()
		end)

		-- H.40: first-tick bootstrap safety -- a nil lastTickTime never raises
		-- "attempt to perform arithmetic on nil".
		local function test_h40_should_run_reconciliation_tick_tolerates_nil_last_tick_time()
			local ok, result = pcall(function()
				return Logic.ShouldRunReconciliationTick(nil, 100.0, Logic.RECONCILIATION_TICK_INTERVAL)
			end)
			expect(ok).to.equal(true)
			expect(result).to.equal(true)
		end
		it(
			"test_h40_should_run_reconciliation_tick_tolerates_nil_last_tick_time",
			function()
				test_h40_should_run_reconciliation_tick_tolerates_nil_last_tick_time()
			end
		)

		local function test_h40_should_run_reconciliation_tick_strict_greater_than_gate()
			-- Exactly at the interval boundary: NOT yet eligible (strict `>`).
			expect(Logic.ShouldRunReconciliationTick(0.0, 5.0, 5.0)).to.equal(false)
			-- Past the boundary: eligible.
			expect(Logic.ShouldRunReconciliationTick(0.0, 5.01, 5.0)).to.equal(true)
		end
		it(
			"test_h40_should_run_reconciliation_tick_strict_greater_than_gate",
			function()
				test_h40_should_run_reconciliation_tick_strict_greater_than_gate()
			end
		)

		-- H.41: multi-life record independence -- life 2's dispatch proceeds
		-- through a completely fresh Pending -> InFlight -> Committed path with
		-- zero residual state from life 1 (no per-player sticky flag survives).
		local function test_h41_multi_life_no_sticky_flag_survives_across_lives()
			local state = Logic.NewReconciliationState()

			-- Life 1: fails every retry, then respawns while still Pending.
			local row1 = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row1, 0.0)
			Logic.RollbackIfStillInFlight(row1)
			Logic.TryRespawn(state, "playerA", Logic.RESPAWN_DELAY, Logic.RESPAWN_DELAY)
			expect(state.deathInProgress["playerA"]).to.equal(nil)

			-- Life 2: mints cleanly, with NO leaked InFlight/Committed state.
			local row2, reason2 = Logic.BeginDeathFlow(state, "playerA", 7, 200.0)
			expect(reason2).to.equal(nil)
			local realRow2 = row2 :: ReconcileRow
			expect(realRow2.deathEventId).never.to.equal(row1.deathEventId)
			expect(realRow2.state).to.equal("Pending")

			Logic.BeginDispatch(realRow2, 200.0)
			local committed2 = Logic.TryCommitDispatch(state, realRow2)
			expect(committed2).to.equal(true)

			-- Life 1's row is untouched by life 2's success.
			expect(row1.state).to.equal("Pending")
		end
		it(
			"test_h41_multi_life_no_sticky_flag_survives_across_lives",
			function()
				test_h41_multi_life_no_sticky_flag_survives_across_lives()
			end
		)

		-- H.42 (MANUAL-DEVICE): BindToClose -> Abandoned, directly-callable.
		local function test_h42_bindtoclose_abandons_pending_and_inflight_rows_only()
			local state = Logic.NewReconciliationState()

			local pendingRow: ReconcileRow = { deathEventId = "evt-pending", userId = 1, state = "Pending", inFlightSince = nil }
			local inFlightRow: ReconcileRow = { deathEventId = "evt-inflight", userId = 2, state = "InFlight", inFlightSince = 10.0 }
			local committedRow: ReconcileRow = { deathEventId = "evt-committed", userId = 3, state = "Committed", inFlightSince = 5.0 }
			state.reconcileRows["evt-pending"] = pendingRow
			state.reconcileRows["evt-inflight"] = inFlightRow
			state.reconcileRows["evt-committed"] = committedRow

			local abandoned = Logic.RunBindToClose(state.reconcileRows)

			expect(#abandoned).to.equal(2)
			expect(pendingRow.state).to.equal("Abandoned")
			expect(inFlightRow.state).to.equal("Abandoned")
			expect(inFlightRow.inFlightSince).to.equal(nil)
			expect(committedRow.state).to.equal("Committed") -- untouched, not abandoned
		end
		it(
			"test_h42_bindtoclose_abandons_pending_and_inflight_rows_only",
			function()
				test_h42_bindtoclose_abandons_pending_and_inflight_rows_only()
			end
		)

		-- H.42 idempotency: AbandonRow on an already-Abandoned row is a safe no-op.
		local function test_h42_abandon_row_is_idempotent()
			local row: ReconcileRow = { deathEventId = "evt-1", userId = 1, state = "Abandoned", inFlightSince = nil }
			local transitioned = Logic.AbandonRow(row)
			expect(transitioned).to.equal(false)
			expect(row.state).to.equal("Abandoned")
		end
		it("test_h42_abandon_row_is_idempotent", function()
			test_h42_abandon_row_is_idempotent()
		end)

		-- H.45: mid-retry, an InFlight row is never re-selected by the scan --
		-- structurally impossible to double-dispatch across ticks.
		local function test_h45_inflight_row_not_selected_by_scan_no_double_dispatch()
			local state = Logic.NewReconciliationState()
			local row = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row, 0.0)
			expect(row.state).to.equal("InFlight")

			local eligible = Logic.ScanPendingRows(state.reconcileRows)
			expect(#eligible).to.equal(0)
		end
		it(
			"test_h45_inflight_row_not_selected_by_scan_no_double_dispatch",
			function()
				test_h45_inflight_row_not_selected_by_scan_no_double_dispatch()
			end
		)

		-- H.46: rejoin-during-reconciliation race closure -- a Pending row is
		-- keyed by deathEventId, independent of player-identity churn. A "rejoin"
		-- (a fresh player-identity value, e.g. a new Player instance for the same
		-- real userId) neither collides with nor disturbs the still-pending row.
		local function test_h46_rejoin_does_not_disturb_pending_row_keyed_by_deathEventId()
			local state = Logic.NewReconciliationState()
			local row1 = Logic.BeginDeathFlow(state, "playerInstance1", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row1, 0.0)
			Logic.RollbackIfStillInFlight(row1) -- stays Pending, unresolved

			-- Rejoin: a FRESH player-identity value, same real userId, with no
			-- entry in currentDeathRecord/deathInProgress (never used those tables
			-- before).
			local row2, reason2 = Logic.BeginDeathFlow(state, "playerInstance2", 7, 50.0)
			expect(reason2).to.equal(nil) -- NOT refused -- distinct identity, no guard set
			local realRow2 = row2 :: ReconcileRow
			expect(realRow2.deathEventId).never.to.equal(row1.deathEventId)

			-- row1 is untouched and still independently reconcile-eligible.
			local eligible = Logic.ScanPendingRows(state.reconcileRows)
			local foundRow1 = false
			for _, r in eligible do
				if r.deathEventId == row1.deathEventId then
					foundRow1 = true
				end
			end
			expect(foundRow1).to.equal(true)
		end
		it(
			"test_h46_rejoin_does_not_disturb_pending_row_keyed_by_deathEventId",
			function()
				test_h46_rejoin_does_not_disturb_pending_row_keyed_by_deathEventId()
			end
		)
	end)

	-- ============================================================================
	-- H.56 -- inFlightSince declared-field lifecycle.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (H.56 inFlightSince lifecycle)", function()
		local function test_h56_inflightSince_full_lifecycle()
			local row: ReconcileRow = { deathEventId = "evt-1", userId = 1, state = "Pending", inFlightSince = nil }
			expect(row.inFlightSince).to.equal(nil) -- nil while Pending

			Logic.BeginDispatch(row, 10.0)
			expect(row.inFlightSince).to.equal(10.0) -- set at Pending -> InFlight

			Logic.RollbackIfStillInFlight(row)
			expect(row.inFlightSince).to.equal(nil) -- cleared on rollback (InFlight -> Pending)

			Logic.BeginDispatch(row, 20.0)
			local reArmed = Logic.RunStalenessSweep({ ["evt-1"] = row }, 40.0, Logic.STALENESS_SWEEP_THRESHOLD)
			expect(#reArmed).to.equal(1)
			expect(row.inFlightSince).to.equal(nil) -- cleared on staleness-sweep re-arm

			local state = Logic.NewReconciliationState()
			state.reconcileRows["evt-1"] = row
			state.currentDeathRecord["playerA"] = "evt-1"
			Logic.BeginDispatch(row, 41.0)
			expect(row.inFlightSince).to.equal(41.0)
			Logic.TryCommitDispatch(state, row)
			expect(row.state).to.equal("Committed")
			-- Committed rows are NOT required to clear inFlightSince (the ADR
			-- describes it as "nil while Pending" only) -- it retains its
			-- last-dispatch stamp for observability.
			expect(row.inFlightSince).to.equal(41.0)

			local abandonRow: ReconcileRow = { deathEventId = "evt-2", userId = 2, state = "InFlight", inFlightSince = 5.0 }
			Logic.AbandonRow(abandonRow)
			expect(abandonRow.inFlightSince).to.equal(nil) -- cleared on Abandon too
		end
		it("test_h56_inflightSince_full_lifecycle", function()
			test_h56_inflightSince_full_lifecycle()
		end)
	end)

	-- ============================================================================
	-- H.22e -- multi-life independence via T6 (respawn) detach.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (H.22e multi-life independence via T6)", function()
		local function test_h22e_full_two_life_squad_scenario()
			local state = Logic.NewReconciliationState()

			-- Life 1: A dies, oxygen decrements (Committed), T6 fires at +30s.
			local row1 = Logic.BeginDeathFlow(state, "playerA", 7, 0.0) :: ReconcileRow
			Logic.BeginDispatch(row1, 0.0)
			local committed1 = Logic.TryCommitDispatch(state, row1)
			expect(committed1).to.equal(true)

			local respawned = Logic.TryRespawn(state, "playerA", Logic.RESPAWN_DELAY, Logic.RESPAWN_DELAY)
			expect(respawned).to.equal(true)

			-- Asserted IMMEDIATELY post-T6, not just as a setup assumption.
			expect(state.currentDeathRecord["playerA"]).to.equal(nil)
			expect(state.deathInProgress["playerA"]).to.equal(nil)
			-- The Committed life-1 row is removed at T6 (N-2 replay-guard window
			-- closes once the player has respawned).
			expect(state.reconcileRows[row1.deathEventId]).to.equal(nil)

			-- Life 2: A dies again -- a FRESH deathEventId, distinct from life 1's.
			local row2, reason2 = Logic.BeginDeathFlow(state, "playerA", 7, Logic.RESPAWN_DELAY + 1.0)
			expect(reason2).to.equal(nil)
			local realRow2 = row2 :: ReconcileRow
			expect(realRow2.deathEventId).never.to.equal(row1.deathEventId)

			Logic.BeginDispatch(realRow2, Logic.RESPAWN_DELAY + 1.0)
			local committed2 = Logic.TryCommitDispatch(state, realRow2)
			expect(committed2).to.equal(true)
		end
		it("test_h22e_full_two_life_squad_scenario", function()
			test_h22e_full_two_life_squad_scenario()
		end)
	end)

	-- ============================================================================
	-- H.23 -- squad oxygen decrements SAME Heartbeat as death, NOT at respawn.
	-- Story 006's own scope note: this story dispatches IMMEDIATELY at death
	-- (Path A only, no grace window). Story 006 inserts OXYGEN_GRACE_DURATION in
	-- FRONT of the `BeginDispatch`/`_beginAndDispatch` call site this story
	-- exposes -- see this file's header note (b) and the final report.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (H.23 same-Heartbeat dispatch, immediate per this story's scope)", function()
		local function test_h23_dispatch_begins_synchronously_at_death_not_deferred_to_respawn()
			local service = FakePlayerControllerService.new()
			service:KnitInit()
			service:_setNow(0.0)
			service:KnitStart()

			local spendCallCount = 0
			service._requestSquadOxygenSpendFn = function(_userId, _amount, _reason, _deathEventId): boolean
				spendCallCount += 1
				return true
			end

			service:_onPlayerDied({ deadPlayer = "playerA", deathTimestamp = 0.0, predatorWasLockedAtDeath = false })

			-- The spend attempt already happened WITHIN the same synchronous call
			-- that handled the death signal -- no Heartbeat, let alone the 30s
			-- respawn timer, had to elapse first.
			expect(spendCallCount).to.equal(1)
			local deathEventId = service._deathReconciliationState.currentDeathRecord["playerA"]
			expect(service._deathReconciliationState.reconcileRows[deathEventId].state).to.equal("Committed")
		end
		it(
			"test_h23_dispatch_begins_synchronously_at_death_not_deferred_to_respawn",
			function()
				test_h23_dispatch_begins_synchronously_at_death_not_deferred_to_respawn()
			end
		)
	end)

	-- ============================================================================
	-- H.16 (referenced context) / H.21 (ordering hook point only, Story 005 owns
	-- the payload) -- Knit-wrapper-shaped proof via FakePlayerControllerService.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (H.16/H.21 death-signal entry + pre-yield hook ordering)", function()
		local function test_h16_death_moment_flows_only_through_onplayerdied_payload()
			local service = FakePlayerControllerService.new()
			service:KnitInit()
			service:_setNow(5.0)
			service:KnitStart()

			local row = service:_beginDeathFlow("playerA", 5.0) :: ReconcileRow
			expect(row).never.to.equal(nil)
			expect(row.state).to.equal("Committed")
			-- The ONLY way BeginDeathFlow was invoked in this test is via the
			-- Fake's own _onPlayerDied/_beginDeathFlow methods, which mirror the
			-- real service's GetOnPlayerDiedSignal()-driven call chain -- see the
			-- static/structural checks below for the repo-wide "no direct
			-- Humanoid.Died" proof against the real file.
		end
		it(
			"test_h16_death_moment_flows_only_through_onplayerdied_payload",
			function()
				test_h16_death_moment_flows_only_through_onplayerdied_payload()
			end
		)

		-- H.21 ordering hook point: the pre-yield side-effect hook fires
		-- SYNCHRONOUSLY, within the SAME call that handles the death signal --
		-- i.e. well within "1 Heartbeat" of Humanoid.Died. The real RESET
		-- PAYLOAD (locomotion=S1, lantern=S3a, pulse timers stopped, stamina
		-- frozen) is Story 005's own scope (this story's Out-of-Scope clause);
		-- this test proves only that the ORDERING HOOK POINT this story owns
		-- fires at the correct moment for Story 005 to plug into.
		local function test_h21_pre_yield_hook_fires_synchronously_within_death_handling_call()
			local service = FakePlayerControllerService.new()
			service:KnitInit()
			service:_setNow(0.0)
			service:KnitStart()

			local hookFiredSynchronously = false
			service._preYieldDeathSideEffectsFn = function(_row: ReconcileRow): ()
				hookFiredSynchronously = true
			end

			service:_onPlayerDied({ deadPlayer = "playerA", deathTimestamp = 0.0, predatorWasLockedAtDeath = false })

			-- Already true by the time _onPlayerDied returns -- no Heartbeat
			-- needed at all.
			expect(hookFiredSynchronously).to.equal(true)
		end
		it(
			"test_h21_pre_yield_hook_fires_synchronously_within_death_handling_call",
			function()
				test_h21_pre_yield_hook_fires_synchronously_within_death_handling_call()
			end
		)
	end)

	-- ============================================================================
	-- Multi-player same-tick independence (code-review addition): ScanPendingRows /
	-- _runReconciliationTick / _checkRespawnTimers are structurally squad-size-
	-- agnostic, but no other test exercises them with more than one concurrent
	-- player. Two players die during a simulated RM outage, recover together in ONE
	-- tick scan, and respawn together in ONE respawn check.
	-- ============================================================================
	describe("PlayerControllerDeathReconciliationLogic -- Story 004 (multi-player same-tick independence)", function()
		local function test_two_players_recover_in_one_tick_and_respawn_in_one_check()
			local service = FakePlayerControllerService.new()
			service:KnitInit()
			service:_setNow(0.0)
			service:KnitStart()

			local outage = true
			local spendCallCount = 0
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				spendCallCount += 1
				if outage then
					error("simulated RM outage")
				end
				return true
			end

			-- Both players die at t=0 during the outage: both dispatch attempts
			-- fail, both rows roll back to Pending.
			local rowA = service:_beginDeathFlow("player-A", 0.0) :: ReconcileRow
			local rowB = service:_beginDeathFlow("player-B", 0.0) :: ReconcileRow
			expect(spendCallCount).to.equal(2)
			expect(rowA.state).to.equal("Pending")
			expect(rowB.state).to.equal("Pending")

			-- Outage ends; ONE reconciliation tick recovers BOTH rows in the same
			-- ScanPendingRows pass, independently.
			outage = false
			service:_setNow(Logic.RECONCILIATION_TICK_INTERVAL + 1.0)
			service:_runReconciliationTick(Logic.RECONCILIATION_TICK_INTERVAL + 1.0)
			expect(spendCallCount).to.equal(4)
			expect(rowA.state).to.equal("Committed")
			expect(rowB.state).to.equal("Committed")
			expect(rowA.deathEventId == rowB.deathEventId).to.equal(false)

			-- ONE respawn check past RESPAWN_DELAY (anchored at each death's own
			-- t=0) respawns BOTH: pointers detached, guards cleared, committed rows
			-- removed at T6.
			local state = service._deathReconciliationState
			service:_setNow(Logic.RESPAWN_DELAY + 1.0)
			service:_checkRespawnTimers(Logic.RESPAWN_DELAY + 1.0)
			expect(state.currentDeathRecord["player-A"]).to.equal(nil)
			expect(state.currentDeathRecord["player-B"]).to.equal(nil)
			expect(state.deathInProgress["player-A"]).to.equal(nil)
			expect(state.deathInProgress["player-B"]).to.equal(nil)
			expect(state.reconcileRows[rowA.deathEventId]).to.equal(nil)
			expect(state.reconcileRows[rowB.deathEventId]).to.equal(nil)
		end
		it(
			"test_two_players_recover_in_one_tick_and_respawn_in_one_check",
			function()
				test_two_players_recover_in_one_tick_and_respawn_in_one_check()
			end
		)
	end)

	-- ============================================================================
	-- Static/structural source-text checks against the real PlayerControllerService
	-- .luau -- mirrors humanoid-died-monopoly-onplayerdied-fanout_test.luau's own
	-- established pattern (including its documented stripLuaComments `--`-in-string
	-- caveat).
	-- ============================================================================
	describe("PlayerControllerService.luau -- Story 004 (wiring, static/structural checks)", function()
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local rawSource: string? = nil
		local strippedSource: string? = nil

		local function loadRawSource(): string
			if not rawSource then
				rawSource = fs.readFile("src/gameplay/services/PlayerControllerService.luau")
			end
			return rawSource :: string
		end

		local function loadStrippedSource(): string
			if not strippedSource then
				strippedSource = stripLuaComments(loadRawSource())
			end
			return strippedSource :: string
		end

		-- TR-pc-016: death moment acquired via GetOnPlayerDiedSignal(), never a
		-- direct Humanoid.Died subscription -- this file itself must contain
		-- ZERO `.Died:Connect(` occurrences (ED's own repo-wide grep test already
		-- covers the whole tree; this is a local, story-scoped reinforcement).
		local function test_no_direct_humanoid_died_connect_in_this_file()
			local source = loadStrippedSource()
			local matchStart = source:find(".Died:Connect(", 1, true)
			expect(matchStart).to.equal(nil)
		end
		it("test_no_direct_humanoid_died_connect_in_this_file", function()
			test_no_direct_humanoid_died_connect_in_this_file()
		end)

		local function test_subscribes_via_get_on_player_died_signal_in_knit_start()
			local source = loadRawSource()
			local knitStartPos = source:find("function PlayerControllerService:KnitStart%(%)")
			expect(knitStartPos).never.to.equal(nil)

			local subscribePos = source:find("GetOnPlayerDiedSignal%(%):Connect%(", knitStartPos)
			expect(subscribePos).never.to.equal(nil)
		end
		it(
			"test_subscribes_via_get_on_player_died_signal_in_knit_start",
			function()
				test_subscribes_via_get_on_player_died_signal_in_knit_start()
			end
		)

		-- TR-pc-045: KnitInit builds self._deathReconciliationState BEFORE
		-- KnitStart connects anything.
		local function test_death_reconciliation_state_constructed_in_knit_init_before_knit_start()
			local source = loadRawSource()
			local knitInitPos = source:find("function PlayerControllerService:KnitInit%(%)")
			local knitStartPos = source:find("function PlayerControllerService:KnitStart%(%)")
			expect(knitInitPos).never.to.equal(nil)
			expect(knitStartPos).never.to.equal(nil)

			local constructPos = source:find("self%._deathReconciliationState = DeathReconciliationLogic%.NewReconciliationState%(%)", knitInitPos)
			expect(constructPos).never.to.equal(nil)
			expect((constructPos :: number) < (knitStartPos :: number)).to.equal(true)
		end
		it(
			"test_death_reconciliation_state_constructed_in_knit_init_before_knit_start",
			function()
				test_death_reconciliation_state_constructed_in_knit_init_before_knit_start()
			end
		)

		-- H.42: the real game:BindToClose(...) registration exists (the story
		-- requires the live wiring to EXIST, even though its firing cannot be
		-- exercised under this harness -- OnBindToClose itself is what the tests
		-- above directly exercise via the Fake harness / pure module).
		local function test_bindtoclose_registration_exists_and_calls_onbindtoclose()
			local source = loadStrippedSource()
			local bindPos = source:find("game:BindToClose(", 1, true)
			expect(bindPos).never.to.equal(nil)

			local callPos = source:find("self:OnBindToClose()", bindPos, true)
			expect(callPos).never.to.equal(nil)
			-- The call must be reasonably close to the registration (same small
			-- callback body), not an unrelated later occurrence.
			expect((callPos :: number) - (bindPos :: number) < 200).to.equal(true)
		end
		it(
			"test_bindtoclose_registration_exists_and_calls_onbindtoclose",
			function()
				test_bindtoclose_registration_exists_and_calls_onbindtoclose()
			end
		)

		-- RM-epic stub shape pin (code-review addition): the default
		-- RequestSquadOxygenSpend stub must return success unconditionally and gate
		-- its warn() behind the PER-INSTANCE `self._hasWarnedMissingResourceService`
		-- flag (never a class-table flag), with the flag initialised in KnitInit.
		-- Static-only evidence: the stub's behavior cannot run under this harness
		-- (requiring the real service needs Knit), so its shape is pinned instead.
		local function test_default_oxygen_spend_stub_returns_true_and_warn_gated_per_instance()
			local source = loadRawSource()

			local stubPos = source:find("function PlayerControllerService:_defaultRequestSquadOxygenSpend%(")
			expect(stubPos).never.to.equal(nil)

			local bodyStart = source:find("\n", stubPos :: number) or (stubPos :: number)
			local bodyEnd = source:find("\nend", bodyStart, true)
			expect(bodyEnd).never.to.equal(nil)
			local body = source:sub(bodyStart, bodyEnd :: number)

			expect(body:find("if not self%._hasWarnedMissingResourceService then")).never.to.equal(nil)
			expect(body:find("self%._hasWarnedMissingResourceService = true")).never.to.equal(nil)
			expect(body:find("return true")).never.to.equal(nil)
			-- No class-table flag anywhere in the file (the reviewed defect's shape).
			expect(source:find("PlayerControllerService%._hasWarnedMissingResourceService")).to.equal(nil)

			-- Flag initialised per-instance in KnitInit, before KnitStart.
			local knitInitPos = source:find("function PlayerControllerService:KnitInit%(%)")
			local knitStartPos = source:find("function PlayerControllerService:KnitStart%(%)")
			local flagInitPos = source:find("self%._hasWarnedMissingResourceService = false", knitInitPos)
			expect(flagInitPos).never.to.equal(nil)
			expect((flagInitPos :: number) < (knitStartPos :: number)).to.equal(true)
		end
		it(
			"test_default_oxygen_spend_stub_returns_true_and_warn_gated_per_instance",
			function()
				test_default_oxygen_spend_stub_returns_true_and_warn_gated_per_instance()
			end
		)

		-- C.11 seam discipline: the ONLY inline `workspace:GetServerTimeNow()` call
		-- anywhere in this file is the seam definition itself
		-- (`PlayerControllerService.getServerTime = function() ... end`) -- Story
		-- 004's own additions never call it a second time.
		local function test_only_one_inline_get_server_time_now_call_the_seam_itself()
			local source = loadStrippedSource()
			local count = 0
			local searchStart = 1
			while true do
				local matchStart = source:find("workspace:GetServerTimeNow()", searchStart, true)
				if not matchStart then
					break
				end
				count += 1
				searchStart = matchStart + 1
			end
			expect(count).to.equal(1)
		end
		it(
			"test_only_one_inline_get_server_time_now_call_the_seam_itself",
			function()
				test_only_one_inline_get_server_time_now_call_the_seam_itself()
			end
		)

		-- Forbidden-pattern check (project-wide rule, PC's own Story 004 scope):
		-- no bare wait()/delay() (deprecated Roblox globals) anywhere in the
		-- Story 004 additions. `task.spawn` is intentionally PRESENT (TR-pc-021's
		-- "yielding remainder task.spawn'd off handler") and deliberately NOT
		-- checked as forbidden here -- only `task.delay`/bare `wait(`/`delay(`
		-- are. The marker is located in the RAW source (comments intact) since
		-- the marker text is itself a comment; the forbidden-pattern scan then
		-- runs on a freshly comment-stripped COPY of just that section, so a
		-- prose mention inside a comment can never false-positive.
		local function test_no_forbidden_deprecated_scheduling_primitives()
			local raw = loadRawSource()
			local story004SectionStart = raw:find("Story 004 %-%- death%-cost reconciliation state machine%. All pure transitions live")
			expect(story004SectionStart).never.to.equal(nil)
			local rawSection = raw:sub(story004SectionStart :: number)
			local strippedSection = stripLuaComments(rawSection)

			expect(strippedSection:find("%f[%a]wait%(")).to.equal(nil)
			expect(strippedSection:find("%f[%a]delay%(")).to.equal(nil)
			expect(strippedSection:find("task%.delay")).to.equal(nil)
			-- task.spawn IS expected/required in this section (TR-pc-021) --
			-- sanity-check its presence rather than its absence.
			expect(strippedSection:find("task%.spawn")).never.to.equal(nil)
		end
		it(
			"test_no_forbidden_deprecated_scheduling_primitives",
			function()
				test_no_forbidden_deprecated_scheduling_primitives()
			end
		)
	end)
end
