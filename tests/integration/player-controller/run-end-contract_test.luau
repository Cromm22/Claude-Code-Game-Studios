--!strict
-- run-end-contract_test
--
-- Integration tests for Story 009: Run-End Contract (T7 Wipe / T8 Victory).
-- Story: production/epics/player-controller/story-009-run-end-contract.md
-- ADR: docs/architecture/adr-0002-runcontroller-architecture.md (the REAL,
--      already-implemented arbiter -- RunEndConditionRaised(conditionType,
--      squadState, defeatReason?) / GetRunEndedSignal() -- mocked below per this
--      story's own explicit instruction: "Mock the arbiter... do NOT depend on
--      RunController's actual implementation")
--      docs/architecture/adr-0005-death-respawn-lifecycle.md (D1 last-stand
--      kill-criterion; the ReconciliationState shape ForceCancelRespawnTimer
--      mirrors, minus the elapsed-time gate)
--
-- Production code under test:
--   src/gameplay/services/PlayerControllerRunEndLogic.luau -- the REAL, pure,
--     zero-require module, exercised DIRECTLY (Section A below).
--   src/gameplay/services/PlayerControllerService.luau -- Knit is not vendored
--     under ReplicatedStorage.Packages in this harness, so a live
--     PlayerControllerService instance cannot be constructed here (same
--     precedent every prior PC integration test in this repo documents).
--     Verified two ways instead:
--       (a) FakePlayerControllerService (Section B) mirrors the real Knit
--           wrapper's Story 009 method bodies method-for-method (on top of the
--           pc-4/pc-5/pc-7-established Fake, extended here) -- per this
--           project's own established Fake-harness precedent.
--           DISCLOSED SUBSTITUTIONS (not silently glossed over):
--             1. The mocked arbiter (`_requestRunEndConditionRaisedFn`) records
--                calls into `self._runEndConditionRaisedCalls` instead of calling
--                a live `RunController:RunEndConditionRaised` -- per this
--                story's own explicit instruction to mock the arbiter. It
--                deliberately does NOT auto-invoke `_onRunEnded` (unlike the
--                REAL RunController, which fires `RunEnded` synchronously from
--                the same call) -- this is what lets H.50's "no PC-side
--                mutation while the hold is pending" assertion be meaningfully
--                distinct from "the raise happened."
--             2. `player` values are plain Lua tables (`{UserId, Name}`), never
--                real Roblox `Player` instances -- matches every prior PC
--                integration test's own harness disclosure.
--             3. `warn()` is locally shadowed (below) to capture the
--                `beacon-latch-timeout` self-heal warning for H.61c's own
--                assertion -- the production file's real `warn()` calls are
--                never executed under this harness (PlayerControllerService.luau
--                itself is not loaded/run here at all, only read as source text
--                for Section D's static checks), so this shim exists purely to
--                let the FAKE's own mirrored self-heal method produce an
--                assertable side effect.
--       (b) Section D: static/structural source-text checks against the real
--           PlayerControllerService.luau (mirrors pc-5/pc-7's own established
--           pattern, including the documented `stripLuaComments` `--`-in-string
--           caveat).
--
-- Story Type: Integration -- coding-standards.md's bar is an automated
-- integration test that must pass (BLOCKING gate).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local RunEndLogic = require(ServerScriptService.gameplay.services.PlayerControllerRunEndLogic)
local ReconLogic = require(ServerScriptService.gameplay.services.PlayerControllerDeathReconciliationLogic)
local SideEffectsLogic = require(ServerScriptService.gameplay.services.PlayerControllerDeathSideEffectsLogic)
local LocomotionStaminaLogic = require(ServerScriptService.gameplay.services.PlayerControllerLocomotionStaminaLogic)
local LanternLogic = require(ServerScriptService.gameplay.services.PlayerControllerLanternLogic)
local EmissionPublisherLogic = require(ServerScriptService.gameplay.services.PlayerControllerEmissionPublisherLogic)
local RenderScopeLogic = require(ServerScriptService.gameplay.services.PlayerControllerRenderScopeLogic)

type ReconcileRow = ReconLogic.ReconcileRow

-- Local (never global) deep-equal helper -- this harness's own `expect(...).to.equal(...)`
-- only ever does `==` (reference/value identity, NOT structural table comparison), so
-- H.50's own "concrete per-member liveness snapshot (deep-equal, not shape-only)"
-- requirement needs its own comparator. Defined once, file-local (test-standards.md:
-- "test data ... never shared mutable state" -- this is a pure comparator, not shared
-- state, and lives only in this file, matching pc-7's own locally-defined-helper
-- precedent for `hasRespawnTimerElapsed`).
local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

-- Local (never global) elapsed-time helper for FakePlayerControllerService's own
-- `_checkRespawnTimers` mirror below -- matches pc-7's own established precedent
-- verbatim (avoids pulling in the full PathBGraceLogic dependency for one predicate).
local function hasRespawnTimerElapsed(startedAt: number?, now: number, delay: number): boolean
	if not startedAt then
		return false
	end
	return (now - startedAt) >= delay
end

-- Local warn-capturing shim (see header DISCLOSED SUBSTITUTIONS #3). Shadows the
-- Lune-global `warn` for the REST OF THIS FILE (lexical scoping -- every function
-- defined below this point, including the Fake's own methods, resolves `warn` to
-- THIS local, not the true global) so H.61c's "emits a beacon-latch-timeout warning"
-- assertion is directly observable.
local capturedWarnings: { string } = {}
local realWarn = warn
local function warn(message: string)
	table.insert(capturedWarnings, message)
	realWarn(message)
end

return function()
	-- ==========================================================================
	-- Section A -- PlayerControllerRunEndLogic (pure module) direct tests
	-- ==========================================================================

	describe("PlayerControllerRunEndLogic -- NewRunEndState (H.61b bootstrap)", function()
		local function test_bootstrap_is_false_and_nil()
			local state = RunEndLogic.NewRunEndState()
			expect(state.beaconActivated).to.equal(false)
			expect(state.beaconActivatedAt).to.equal(nil)
			expect(state.hasRaisedWipe).to.equal(false)
			expect(state.hasRaisedVictory).to.equal(false)
		end
		it("test_bootstrap_is_false_and_nil", test_bootstrap_is_false_and_nil)
	end)

	describe("PlayerControllerRunEndLogic -- ActivateBeaconLatch (GDD C.6 latch table SET column)", function()
		local function test_activates_and_records_timestamp()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ActivateBeaconLatch(state, 100)
			expect(state.beaconActivated).to.equal(true)
			expect(state.beaconActivatedAt).to.equal(100)
		end
		it("test_activates_and_records_timestamp", test_activates_and_records_timestamp)

		local function test_set_once_never_re_set_within_a_run()
			-- GDD C.6: "set ONCE, never re-set within a run" -- a duplicate/replayed
			-- activation must not re-anchor beaconActivatedAt (which would spuriously
			-- extend the self-heal window).
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ActivateBeaconLatch(state, 100)
			RunEndLogic.ActivateBeaconLatch(state, 999)
			expect(state.beaconActivatedAt).to.equal(100)
		end
		it("test_set_once_never_re_set_within_a_run", test_set_once_never_re_set_within_a_run)
	end)

	describe("PlayerControllerRunEndLogic -- ClearOnRunEnded (H.61b N+1-run fresh-start)", function()
		local function test_clears_all_four_fields_together()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ActivateBeaconLatch(state, 100)
			RunEndLogic.MarkWipeRaised(state)
			RunEndLogic.MarkVictoryRaised(state)

			RunEndLogic.ClearOnRunEnded(state)

			expect(state.beaconActivated).to.equal(false)
			expect(state.beaconActivatedAt).to.equal(nil)
			expect(state.hasRaisedWipe).to.equal(false)
			expect(state.hasRaisedVictory).to.equal(false)
		end
		it("test_clears_all_four_fields_together", test_clears_all_four_fields_together)

		local function test_idempotent_on_an_already_clear_state()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ClearOnRunEnded(state)
			expect(state.beaconActivated).to.equal(false)
			expect(state.beaconActivatedAt).to.equal(nil)
			expect(state.hasRaisedWipe).to.equal(false)
			expect(state.hasRaisedVictory).to.equal(false)
		end
		it("test_idempotent_on_an_already_clear_state", test_idempotent_on_an_already_clear_state)
	end)

	describe("PlayerControllerRunEndLogic -- ShouldSelfHealBeaconLatch / ForceSelfHeal (H.61c)", function()
		local function test_fires_strictly_past_timeout()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ActivateBeaconLatch(state, 0)
			expect(RunEndLogic.ShouldSelfHealBeaconLatch(state, RunEndLogic.BEACON_LATCH_TIMEOUT + 0.01, RunEndLogic.BEACON_LATCH_TIMEOUT)).to.equal(true)
		end
		it("test_fires_strictly_past_timeout", test_fires_strictly_past_timeout)

		local function test_does_not_fire_exactly_at_timeout()
			-- Strict `>` per the GDD's own text -- exactly AT the timeout has not yet
			-- been EXCEEDED.
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ActivateBeaconLatch(state, 0)
			expect(RunEndLogic.ShouldSelfHealBeaconLatch(state, RunEndLogic.BEACON_LATCH_TIMEOUT, RunEndLogic.BEACON_LATCH_TIMEOUT)).to.equal(false)
		end
		it("test_does_not_fire_exactly_at_timeout", test_does_not_fire_exactly_at_timeout)

		local function test_negative_case_timeout_minus_epsilon()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ActivateBeaconLatch(state, 0)
			expect(RunEndLogic.ShouldSelfHealBeaconLatch(state, RunEndLogic.BEACON_LATCH_TIMEOUT - 0.01, RunEndLogic.BEACON_LATCH_TIMEOUT)).to.equal(false)
		end
		it("test_negative_case_timeout_minus_epsilon", test_negative_case_timeout_minus_epsilon)

		local function test_never_fires_while_latch_not_activated()
			local state = RunEndLogic.NewRunEndState()
			expect(RunEndLogic.ShouldSelfHealBeaconLatch(state, 999999, RunEndLogic.BEACON_LATCH_TIMEOUT)).to.equal(false)
		end
		it("test_never_fires_while_latch_not_activated", test_never_fires_while_latch_not_activated)

		local function test_force_self_heal_clears_only_beacon_fields_not_raise_flags()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ActivateBeaconLatch(state, 0)
			RunEndLogic.MarkWipeRaised(state)

			RunEndLogic.ForceSelfHeal(state)

			expect(state.beaconActivated).to.equal(false)
			expect(state.beaconActivatedAt).to.equal(nil)
			-- NOT a "fresh run" event -- hasRaisedWipe must survive the self-heal
			-- (see PlayerControllerRunEndLogic.luau's own ForceSelfHeal doc comment).
			expect(state.hasRaisedWipe).to.equal(true)
		end
		it(
			"test_force_self_heal_clears_only_beacon_fields_not_raise_flags",
			test_force_self_heal_clears_only_beacon_fields_not_raise_flags
		)
	end)

	describe("PlayerControllerRunEndLogic -- IsWholeSquadWiped (T7 squad condition)", function()
		local function test_empty_squad_is_never_wiped()
			expect(RunEndLogic.IsWholeSquadWiped(0, 0, true)).to.equal(false)
		end
		it("test_empty_squad_is_never_wiped", test_empty_squad_is_never_wiped)

		local function test_partial_s4_is_not_wiped()
			expect(RunEndLogic.IsWholeSquadWiped(2, 1, true)).to.equal(false)
		end
		it("test_partial_s4_is_not_wiped", test_partial_s4_is_not_wiped)

		local function test_all_s4_but_oxygen_not_below_one_is_not_wiped()
			expect(RunEndLogic.IsWholeSquadWiped(2, 2, false)).to.equal(false)
		end
		it("test_all_s4_but_oxygen_not_below_one_is_not_wiped", test_all_s4_but_oxygen_not_below_one_is_not_wiped)

		local function test_all_s4_and_oxygen_below_one_is_wiped()
			expect(RunEndLogic.IsWholeSquadWiped(4, 4, true)).to.equal(true)
		end
		it("test_all_s4_and_oxygen_below_one_is_wiped", test_all_s4_and_oxygen_below_one_is_wiped)

		local function test_solo_squad_all_s4_oxygen_below_one_is_wiped()
			-- QA Gap 3 (engine review confirmed): the GDD's literal wording ("All
			-- 2-4 squad members in S4 AND squad oxygen < 1") carries no explicit
			-- SIZE FLOOR beyond `squadSize > 0` -- a solo (1-player) squad, all-S4
			-- + oxygen<1, IS wiped. This module does not special-case squadSize==1
			-- as a non-wipe.
			expect(RunEndLogic.IsWholeSquadWiped(1, 1, true)).to.equal(true)
		end
		it("test_solo_squad_all_s4_oxygen_below_one_is_wiped", test_solo_squad_all_s4_oxygen_below_one_is_wiped)
	end)

	describe("PlayerControllerRunEndLogic -- ShouldRaiseWipe / ShouldRaiseVictory (raise-once guards)", function()
		local function test_wipe_raises_when_all_conditions_hold()
			local state = RunEndLogic.NewRunEndState()
			expect(RunEndLogic.ShouldRaiseWipe(state, true)).to.equal(true)
		end
		it("test_wipe_raises_when_all_conditions_hold", test_wipe_raises_when_all_conditions_hold)

		local function test_wipe_suppressed_when_beacon_activated()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.ActivateBeaconLatch(state, 0)
			expect(RunEndLogic.ShouldRaiseWipe(state, true)).to.equal(false)
		end
		it("test_wipe_suppressed_when_beacon_activated", test_wipe_suppressed_when_beacon_activated)

		local function test_wipe_suppressed_once_already_raised()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.MarkWipeRaised(state)
			expect(RunEndLogic.ShouldRaiseWipe(state, true)).to.equal(false)
		end
		it("test_wipe_suppressed_once_already_raised", test_wipe_suppressed_once_already_raised)

		local function test_wipe_never_raises_if_squad_condition_false()
			local state = RunEndLogic.NewRunEndState()
			expect(RunEndLogic.ShouldRaiseWipe(state, false)).to.equal(false)
		end
		it("test_wipe_never_raises_if_squad_condition_false", test_wipe_never_raises_if_squad_condition_false)

		local function test_victory_raises_by_default()
			local state = RunEndLogic.NewRunEndState()
			expect(RunEndLogic.ShouldRaiseVictory(state)).to.equal(true)
		end
		it("test_victory_raises_by_default", test_victory_raises_by_default)

		local function test_victory_suppressed_once_already_raised()
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.MarkVictoryRaised(state)
			expect(RunEndLogic.ShouldRaiseVictory(state)).to.equal(false)
		end
		it("test_victory_suppressed_once_already_raised", test_victory_suppressed_once_already_raised)

		local function test_wipe_and_victory_guards_are_independent()
			-- H.50: both a wipe raise AND a later, separate victory raise must each
			-- succeed exactly once for the SAME run -- a shared flag would incorrectly
			-- conflate them.
			local state = RunEndLogic.NewRunEndState()
			RunEndLogic.MarkWipeRaised(state)
			expect(RunEndLogic.ShouldRaiseVictory(state)).to.equal(true)
		end
		it("test_wipe_and_victory_guards_are_independent", test_wipe_and_victory_guards_are_independent)
	end)

	describe("PlayerControllerRunEndLogic -- squadState snapshot construction (H.50 deep-equal)", function()
		local function test_render_scope_mapping()
			expect(RunEndLogic.RenderScopeToSquadStateValue("alive")).to.equal("alive")
			expect(RunEndLogic.RenderScopeToSquadStateValue("dead-respawning")).to.equal("S4")
			expect(RunEndLogic.RenderScopeToSquadStateValue("post-run")).to.equal("S5")
			expect(RunEndLogic.RenderScopeToSquadStateValue(nil)).to.equal("alive")
		end
		it("test_render_scope_mapping", test_render_scope_mapping)

		local function test_build_squad_state_snapshot_shape()
			local snapshot = RunEndLogic.BuildSquadStateSnapshot({
				{ userId = 1, scope = "alive" },
				{ userId = 2, scope = "dead-respawning" },
			})
			expect(deepEqual(snapshot, { [1] = "alive", [2] = "S4" })).to.equal(true)
		end
		it("test_build_squad_state_snapshot_shape", test_build_squad_state_snapshot_shape)

		local function test_build_squad_state_snapshot_returns_a_fresh_table_every_call()
			local members = { { userId = 1, scope = "alive" } }
			local snapshotA = RunEndLogic.BuildSquadStateSnapshot(members)
			local snapshotB = RunEndLogic.BuildSquadStateSnapshot(members)
			expect(snapshotA).never.to.equal(snapshotB)
			expect(deepEqual(snapshotA, snapshotB)).to.equal(true)
		end
		it(
			"test_build_squad_state_snapshot_returns_a_fresh_table_every_call",
			test_build_squad_state_snapshot_returns_a_fresh_table_every_call
		)
	end)

	describe("PlayerControllerRunEndLogic -- ForceCancelRespawnTimer (T8 S4-rescue mechanism)", function()
		local function test_noop_for_a_player_never_tracked_as_dead()
			local state = ReconLogic.NewReconciliationState()
			local playerA = { UserId = 1 }
			local cancelled = RunEndLogic.ForceCancelRespawnTimer(state, playerA)
			expect(cancelled).to.equal(false)
		end
		it("test_noop_for_a_player_never_tracked_as_dead", test_noop_for_a_player_never_tracked_as_dead)

		local function test_cancels_a_pending_timer_regardless_of_elapsed_time()
			local state = ReconLogic.NewReconciliationState()
			local playerA = { UserId = 1 }
			-- Death started 1 tick ago -- nowhere near RESPAWN_DELAY=30s elapsed.
			local row = ReconLogic.BeginDeathFlow(state, playerA, 1, 10)
			expect(row).never.to.equal(nil)

			local cancelled = RunEndLogic.ForceCancelRespawnTimer(state, playerA)

			expect(cancelled).to.equal(true)
			expect(state.deathStartedAt[playerA]).to.equal(nil)
			expect(state.currentDeathRecord[playerA]).to.equal(nil)
			expect(state.deathInProgress[playerA]).to.equal(nil)
		end
		it(
			"test_cancels_a_pending_timer_regardless_of_elapsed_time",
			test_cancels_a_pending_timer_regardless_of_elapsed_time
		)

		local function test_retires_an_already_committed_record()
			local state = ReconLogic.NewReconciliationState()
			local playerA = { UserId = 1 }
			local row = ReconLogic.BeginDeathFlow(state, playerA, 1, 10) :: ReconcileRow
			ReconLogic.BeginDispatch(row, 10)
			ReconLogic.TryCommitDispatch(state, row)
			expect(row.state).to.equal("Committed")

			RunEndLogic.ForceCancelRespawnTimer(state, playerA)

			expect(state.reconcileRows[row.deathEventId]).to.equal(nil)
		end
		it("test_retires_an_already_committed_record", test_retires_an_already_committed_record)

		local function test_survives_an_uncommitted_pending_record()
			local state = ReconLogic.NewReconciliationState()
			local playerA = { UserId = 1 }
			local row = ReconLogic.BeginDeathFlow(state, playerA, 1, 10) :: ReconcileRow
			-- Deliberately NOT dispatched -- row stays "Pending".

			RunEndLogic.ForceCancelRespawnTimer(state, playerA)

			-- ADR-0005: an uncommitted Pending/InFlight record is never deleted on
			-- departure/detach -- it survives by deathEventId.
			expect(state.reconcileRows[row.deathEventId]).never.to.equal(nil)
			expect(state.currentDeathRecord[playerA]).to.equal(nil)
		end
		it("test_survives_an_uncommitted_pending_record", test_survives_an_uncommitted_pending_record)
	end)

	describe("PlayerControllerRunEndLogic -- ValidateConfig (BEACON_LATCH_TIMEOUT range gate)", function()
		local function test_default_passes()
			local ok = RunEndLogic.ValidateConfig(RunEndLogic.BEACON_LATCH_TIMEOUT)
			expect(ok).to.equal(true)
		end
		it("test_default_passes", test_default_passes)

		local function test_range_boundaries_pass()
			expect(RunEndLogic.ValidateConfig(180)).to.equal(true)
			expect(RunEndLogic.ValidateConfig(600)).to.equal(true)
		end
		it("test_range_boundaries_pass", test_range_boundaries_pass)

		local function test_below_floor_fails()
			local ok = RunEndLogic.ValidateConfig(179.9)
			expect(ok).to.equal(false)
		end
		it("test_below_floor_fails", test_below_floor_fails)

		local function test_above_ceiling_fails()
			local ok = RunEndLogic.ValidateConfig(600.1)
			expect(ok).to.equal(false)
		end
		it("test_above_ceiling_fails", test_above_ceiling_fails)
	end)

	-- ==========================================================================
	-- Section B -- FakePlayerControllerService (see header note (a) above)
	-- ==========================================================================

	local FakePlayerControllerService = {}
	FakePlayerControllerService.__index = FakePlayerControllerService

	function FakePlayerControllerService.new()
		return setmetatable({}, FakePlayerControllerService)
	end

	function FakePlayerControllerService:KnitInit()
		self._deathReconciliationState = ReconLogic.NewReconciliationState()
		self._now = 0

		self._locomotionState = {}
		self._playerState = {}
		self._emissionState = {}
		self._deathEffectsState = {}
		self._lastServerTrackedPosition = {}
		self._playersByUserId = {}

		self._renderScope = {}
		self._renderScopePushLog = {}
		self._renderScopePushCount = {}
		self._humanoidState = {}
		self._capturedJumpState = {}

		self._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
			return true
		end
		self._releasePredatorLockFn = function(_userId: number): () end
		self._onPlayerS4EnteredFn = function(_userId: number): () end
		self._onPlayerT6RespawnedFn = function(_userId: number): () end
		self._onSquadMemberAliveChangedFn = function(_userId: number, _isAlive: boolean): () end
		self._getRespawnAnchorPositionFn = function(_player: any): Vector3
			return Vector3.new(0, 0, 0)
		end
		self._respawnPlayerAtAnchorFn = function(_player: any, _anchorPosition: Vector3): any?
			return nil
		end
		self._broadcastPlayerDiedFn = function(_userId: number, _deathCause: string): () end

		self._preYieldDeathSideEffectsFn = function(row: ReconcileRow, dispatchOrigin: string, pathOrigin: string?): ()
			self:_applyPreYieldDeathSideEffects(row, dispatchOrigin, pathOrigin)
		end
		self._onDeathCommitFn = function(row: ReconcileRow, dispatchOrigin: string, player: any, pathOrigin: string?): ()
			self:_applyPostCommitDeathSideEffects(row, dispatchOrigin, player, pathOrigin)
		end

		-- Story 009: the run-end state + the MOCKED arbiter (see header DISCLOSED
		-- SUBSTITUTIONS #1). `_getSquadOxygenPoolFn` defaults to `math.huge` -- same
		-- "a stub must never manufacture a false death" precedent pc-6's real
		-- `_defaultGetSquadOxygenPool` established -- tests override it directly.
		self._runEndState = RunEndLogic.NewRunEndState()
		self._getSquadOxygenPoolFn = function(): number
			return math.huge
		end
		self._runEndConditionRaisedCalls = {} :: { { conditionType: string, squadState: any, defeatReason: string? } }
		self._requestRunEndConditionRaisedFn = function(conditionType: string, squadState: any, defeatReason: string?): ()
			table.insert(self._runEndConditionRaisedCalls, {
				conditionType = conditionType,
				squadState = squadState,
				defeatReason = defeatReason,
			})
		end
	end

	function FakePlayerControllerService:_setNow(now: number)
		self._now = now
	end

	function FakePlayerControllerService:KnitStart()
		self._deathReconciliationState.lastTickTime = self._now
	end

	function FakePlayerControllerService:_registerPlayer(player: any)
		self._playersByUserId[player.UserId] = player
		self._locomotionState[player] = LocomotionStaminaLogic.NewPlayerLocomotionState()
		self._playerState[player] = LanternLogic.NewPlayerState()
		self._playerState[player].locomotion = self._locomotionState[player].locomotion
		self._emissionState[player] = EmissionPublisherLogic.NewPlayerEmissionState()
		self._renderScope[player] = "alive"
		self._humanoidState[player] = { WalkSpeed = LocomotionStaminaLogic.WALK_SPEED, JumpPower = 65, JumpHeight = 8.5 }
	end

	function FakePlayerControllerService:_isPlayerDead(player: any): boolean
		return self._deathReconciliationState.deathStartedAt[player] ~= nil
	end

	function FakePlayerControllerService:_onPlayerDied(payload: { deadPlayer: any, deathTimestamp: number, predatorWasLockedAtDeath: boolean })
		local now = self._now
		self:_beginDeathFlow(payload.deadPlayer, now, "A")
	end

	function FakePlayerControllerService:_beginDeathFlow(player: any, now: number, pathOrigin: string): (ReconcileRow?, string?)
		local row, reason = ReconLogic.BeginDeathFlow(self._deathReconciliationState, player, player.UserId, now)
		if row then
			self:_beginAndDispatch(row, now, "initial", player, pathOrigin)
		end
		return row, reason
	end

	function FakePlayerControllerService:_beginAndDispatch(row: ReconcileRow, now: number, dispatchOrigin: string, player: any, pathOrigin: string?): ()
		ReconLogic.BeginDispatch(row, now)

		local hookOk = pcall(function()
			self._preYieldDeathSideEffectsFn(row, dispatchOrigin, pathOrigin)
		end)
		if not hookOk then
			ReconLogic.RollbackIfStillInFlight(row)
			return
		end

		self:_completeDispatch(row, dispatchOrigin, player, pathOrigin)
	end

	function FakePlayerControllerService:_completeDispatch(row: ReconcileRow, dispatchOrigin: string, player: any, pathOrigin: string?): ()
		local ok, _result = pcall(function()
			return self._requestSquadOxygenSpendFn(
				row.userId,
				ReconLogic.DEATH_OXYGEN_SPEND_AMOUNT,
				ReconLogic.DEATH_OXYGEN_SPEND_REASON,
				row.deathEventId
			)
		end)

		if ok then
			local committed = ReconLogic.TryCommitDispatch(self._deathReconciliationState, row)
			if committed then
				pcall(function()
					self._onDeathCommitFn(row, dispatchOrigin, player, pathOrigin)
				end)
			end
		else
			ReconLogic.RollbackIfStillInFlight(row)
		end
	end

	function FakePlayerControllerService:_checkRespawnTimers(now: number): ()
		local reconState = self._deathReconciliationState
		local trackedPlayers: { any } = {}
		for player in reconState.deathStartedAt do
			table.insert(trackedPlayers, player)
		end
		for _, player in trackedPlayers do
			if not hasRespawnTimerElapsed(reconState.deathStartedAt[player], now, ReconLogic.RESPAWN_DELAY) then
				continue
			end
			local respawned = ReconLogic.TryRespawn(reconState, player, now, ReconLogic.RESPAWN_DELAY)
			if respawned then
				self:_completeRespawn(player, now)
			end
		end
	end

	function FakePlayerControllerService:_completeRespawn(player: any, _now: number): ()
		self._locomotionState[player] = LocomotionStaminaLogic.NewPlayerLocomotionState()

		local playerState = self._playerState[player]
		if playerState then
			playerState.lantern = "S3a"
			playerState.locomotion = "S1"
		end

		local emissionState = self._emissionState[player]
		if emissionState then
			EmissionPublisherLogic.OnAxisExited(emissionState.sprint)
			EmissionPublisherLogic.OnAxisExited(emissionState.light)
			EmissionPublisherLogic.ResetGraceAnchorsOnDeath(emissionState)
		end

		self._deathEffectsState[player] = nil

		if self._playersByUserId[player.UserId] ~= player then
			return
		end

		local anchorPosition = self._getRespawnAnchorPositionFn(player)
		local hrp = self._respawnPlayerAtAnchorFn(player, anchorPosition)

		self._lastServerTrackedPosition[player] = anchorPosition

		self._onPlayerT6RespawnedFn(player.UserId)

		if hrp then
			self._onSquadMemberAliveChangedFn(player.UserId, true)
			self:_exitToAliveRenderScope(player)
		end
	end

	function FakePlayerControllerService:ResetGraceAnchorsOnDeath(player: any): ()
		local emissionState = self._emissionState[player]
		if not emissionState then
			return
		end
		EmissionPublisherLogic.ResetGraceAnchorsOnDeath(emissionState)
	end

	function FakePlayerControllerService:_setDeathEffectFlag(player: any, field: string, value: boolean): ()
		local flags = self._deathEffectsState[player]
		if not flags then
			flags = {}
			self._deathEffectsState[player] = flags
		end
		flags[field] = value
	end

	function FakePlayerControllerService:_applyPreYieldDeathSideEffects(row: ReconcileRow, dispatchOrigin: string, pathOrigin: string?): ()
		if SideEffectsLogic.ShouldFireReleasePredatorLockPreYield(dispatchOrigin :: any) then
			self._releasePredatorLockFn(row.userId)
		end
		if SideEffectsLogic.ShouldFireOnPlayerS4EnteredPreYield(dispatchOrigin :: any, pathOrigin :: any) then
			self._onPlayerS4EnteredFn(row.userId)
		end
		if SideEffectsLogic.ShouldFireAliveEdgeFalsePreYield(dispatchOrigin :: any) then
			self._onSquadMemberAliveChangedFn(row.userId, false)
		end
	end

	function FakePlayerControllerService:_applyPostCommitDeathSideEffects(row: ReconcileRow, dispatchOrigin: string, player: any, pathOrigin: string?): ()
		local effects = SideEffectsLogic.SelectPostCommitSideEffects(dispatchOrigin :: any, pathOrigin :: any)

		self._broadcastPlayerDiedFn(row.userId, effects.deathCause)

		local touchLiveState = true
		if dispatchOrigin == "reconciliation" and player then
			touchLiveState = self._deathReconciliationState.currentDeathRecord[player] == row.deathEventId
		end

		if effects.sprintReset and player and touchLiveState then
			local locState = self._locomotionState[player]
			if locState and locState.locomotion == "S2" then
				LocomotionStaminaLogic.ForceRevertToS1(locState, self._now)
				local playerState = self._playerState[player]
				if playerState then
					playerState.locomotion = "S1"
				end
			end
			local emissionState = self._emissionState[player]
			if emissionState then
				EmissionPublisherLogic.OnAxisExited(emissionState.sprint)
			end
		end

		if effects.lanternReset and player and touchLiveState then
			local playerState = self._playerState[player]
			if playerState and playerState.lantern == "S3b" then
				playerState.lantern = "S3a"
			end
			local emissionState = self._emissionState[player]
			if emissionState then
				EmissionPublisherLogic.OnAxisExited(emissionState.light)
			end
		end

		if effects.resetGraceAnchors and player then
			self:ResetGraceAnchorsOnDeath(player)
		end

		if effects.activateSpectatorCamera and player then
			self:_setDeathEffectFlag(player, "spectatorCameraActive", true)
		end

		if effects.lockClientInput and player then
			self:_setDeathEffectFlag(player, "inputLocked", true)
			self:_enterDeadRespawningRenderScope(player)
		end

		if effects.releasePredatorLock then
			self._releasePredatorLockFn(row.userId)
		end
	end

	function FakePlayerControllerService:_setRenderScope(player: any, scope: string): ()
		if self._renderScope[player] == scope then
			return
		end
		self._renderScope[player] = scope
		table.insert(self._renderScopePushLog, { player = player, scope = scope })
		self._renderScopePushCount[player] = (self._renderScopePushCount[player] or 0) + 1
	end

	function FakePlayerControllerService:_isEligibleForGameplayEvents(player: any): boolean
		return RenderScopeLogic.IsAliveScope(self._renderScope[player])
	end

	function FakePlayerControllerService:_enterDeadRespawningRenderScope(player: any): ()
		self:_setRenderScope(player, "dead-respawning")
		local humanoidState = self._humanoidState[player]
		if humanoidState then
			self._capturedJumpState[player] = { JumpPower = humanoidState.JumpPower, JumpHeight = humanoidState.JumpHeight }
			humanoidState.WalkSpeed = 0
			humanoidState.JumpPower = 0
			humanoidState.JumpHeight = 0
		end
	end

	function FakePlayerControllerService:_exitToAliveRenderScope(player: any): ()
		self:_setRenderScope(player, "alive")
		local humanoidState = self._humanoidState[player]
		if humanoidState then
			humanoidState.WalkSpeed = LocomotionStaminaLogic.WALK_SPEED
			local captured = self._capturedJumpState[player]
			if captured then
				humanoidState.JumpPower = captured.JumpPower
				humanoidState.JumpHeight = captured.JumpHeight
			end
		end
		self._capturedJumpState[player] = nil
	end

	function FakePlayerControllerService:EnterPostRunScope(player: any): ()
		self:_setRenderScope(player, "post-run")
	end

	-- ---------------------------------------------------------------------
	-- Story 009 -- run-end contract (mirrors PlayerControllerService.luau's own
	-- `_buildSquadStateSnapshot`/`_evaluateT7Wipe`/`OnBeaconWindowSurvived`/
	-- `OnEscapeBeaconActivated`/`_checkBeaconLatchSelfHeal`/`_onRunEnded`).
	-- ---------------------------------------------------------------------

	function FakePlayerControllerService:_buildSquadStateSnapshot(): any
		local members = {}
		for _, player in self._playersByUserId do
			table.insert(members, { userId = player.UserId, scope = self._renderScope[player] })
		end
		return RunEndLogic.BuildSquadStateSnapshot(members)
	end

	function FakePlayerControllerService:_evaluateT7Wipe(_now: number): ()
		local squadSize = 0
		local s4Count = 0
		for _, player in self._playersByUserId do
			squadSize += 1
			if self:_isPlayerDead(player) then
				s4Count += 1
			end
		end

		local squadOxygenBelowOne = self._getSquadOxygenPoolFn() < 1
		local wholeSquadWiped = RunEndLogic.IsWholeSquadWiped(squadSize, s4Count, squadOxygenBelowOne)

		if not RunEndLogic.ShouldRaiseWipe(self._runEndState, wholeSquadWiped) then
			return
		end

		RunEndLogic.MarkWipeRaised(self._runEndState)
		local squadState = self:_buildSquadStateSnapshot()
		self._requestRunEndConditionRaisedFn("wipe", squadState, nil)
	end

	function FakePlayerControllerService:OnBeaconWindowSurvived(_timestamp: number): ()
		if not RunEndLogic.ShouldRaiseVictory(self._runEndState) then
			return
		end

		RunEndLogic.MarkVictoryRaised(self._runEndState)
		local squadState = self:_buildSquadStateSnapshot()
		self._requestRunEndConditionRaisedFn("victory", squadState, nil)
	end

	function FakePlayerControllerService:OnEscapeBeaconActivated(_activatorPlayerId: number, _timestamp: number, _windowDurationSeconds: number): ()
		RunEndLogic.ActivateBeaconLatch(self._runEndState, self._now)
	end

	function FakePlayerControllerService:_checkBeaconLatchSelfHeal(now: number): ()
		if not RunEndLogic.ShouldSelfHealBeaconLatch(self._runEndState, now, RunEndLogic.BEACON_LATCH_TIMEOUT) then
			return
		end

		RunEndLogic.ForceSelfHeal(self._runEndState)
		warn(
			("FakePlayerControllerService: beacon-latch-timeout: _beaconActivated force-cleared after exceeding BEACON_LATCH_TIMEOUT=%.1fs"):format(
				RunEndLogic.BEACON_LATCH_TIMEOUT
			)
		)
	end

	function FakePlayerControllerService:_onRunEnded(_payload: any): ()
		RunEndLogic.ClearOnRunEnded(self._runEndState)

		for _, player in self._playersByUserId do
			local scope = self._renderScope[player]
			if scope == "alive" or scope == "dead-respawning" then
				RunEndLogic.ForceCancelRespawnTimer(self._deathReconciliationState, player)
				self:EnterPostRunScope(player)
			end
		end
	end

	--- Mirrors the REAL `_onDeathReconciliationHeartbeat`'s composed ordering
	--- verbatim (self-heal -> T7 -> respawn timers) -- engine Finding 1 / QA
	--- edge 3's own "drive the real composed order" instruction. Skips the
	--- `_runReconciliationTick`-equivalent step: this Fake (matching pc-4/pc-7's
	--- own established harness scope) never models the staleness sweep, since
	--- the RM stub (`_requestSquadOxygenSpendFn`) is synchronous here -- no row
	--- is ever left `InFlight` long enough to need re-arming, so there is
	--- nothing for that step to do between self-heal and T7.
	function FakePlayerControllerService:_onDeathReconciliationHeartbeat(now: number): ()
		self:_checkBeaconLatchSelfHeal(now)
		self:_evaluateT7Wipe(now)
		self:_checkRespawnTimers(now)
	end

	-- ==========================================================================
	-- Section C -- behavioral integration tests (Fake harness)
	-- ==========================================================================

	local function newFakeWithTwoPlayers()
		local fake = FakePlayerControllerService.new()
		fake:KnitInit()
		fake:_setNow(0)
		fake:KnitStart()
		local playerA = { UserId = 1, Name = "Alice" }
		local playerB = { UserId = 2, Name = "Bob" }
		fake:_registerPlayer(playerA)
		fake:_registerPlayer(playerB)
		return fake, playerA, playerB
	end

	local function killViaRealT5Path(fake: any, player: any, now: number)
		fake:_setNow(now)
		fake:_onPlayerDied({ deadPlayer = player, deathTimestamp = now, predatorWasLockedAtDeath = false })
	end

	describe("H.47 -- T8 consumes OnBeaconWindowSurvived, never OnEscapeBeaconActivated", function()
		local function test_activation_alone_raises_no_victory()
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:_setNow(0)
			fake:KnitStart()

			fake:OnEscapeBeaconActivated(1, 0, 90)

			expect(#fake._runEndConditionRaisedCalls).to.equal(0)
		end
		it("test_activation_alone_raises_no_victory", test_activation_alone_raises_no_victory)

		local function test_survival_raises_victory_exactly_once()
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:_setNow(0)
			fake:KnitStart()
			fake:OnEscapeBeaconActivated(1, 0, 90)

			fake:OnBeaconWindowSurvived(45)

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			expect(fake._runEndConditionRaisedCalls[1].conditionType).to.equal("victory")
		end
		it("test_survival_raises_victory_exactly_once", test_survival_raises_victory_exactly_once)

		local function test_exact_arities_accepted()
			-- OnEscapeBeaconActivated(activatorPlayerId, timestamp, windowDurationSeconds)
			-- / OnBeaconWindowSurvived(timestamp) -- exact arities per H.47.
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:KnitStart()
			local activateOk = pcall(function()
				fake:OnEscapeBeaconActivated(7, 12.5, 90)
			end)
			local surviveOk = pcall(function()
				fake:OnBeaconWindowSurvived(60.0)
			end)
			expect(activateOk).to.equal(true)
			expect(surviveOk).to.equal(true)
		end
		it("test_exact_arities_accepted", test_exact_arities_accepted)

		local function test_activation_never_calls_the_arbiter_directly_regression_target()
			-- H.47's own named regression: raising "victory" on ACTIVATION instead of
			-- SURVIVAL. Proven here by activating many times and confirming zero raises.
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:KnitStart()
			for i = 1, 5 do
				fake:OnEscapeBeaconActivated(1, i, 90)
			end
			expect(#fake._runEndConditionRaisedCalls).to.equal(0)
		end
		it(
			"test_activation_never_calls_the_arbiter_directly_regression_target",
			test_activation_never_calls_the_arbiter_directly_regression_target
		)
	end)

	describe("H.48 -- T8 S4-rescue", function()
		local function test_s4_player_rescued_to_s5_victory_with_timer_cancelled_and_counted_survivor()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerB, 10)
			expect(fake._renderScope[playerB]).to.equal("dead-respawning")
			expect(fake._deathReconciliationState.deathStartedAt[playerB]).never.to.equal(nil)

			fake:_setNow(12)
			fake:OnBeaconWindowSurvived(12)

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			local raisedCall = fake._runEndConditionRaisedCalls[1]
			expect(raisedCall.conditionType).to.equal("victory")
			-- Counted as a survivor: B's entry is PRESENT in the raised squadState
			-- (not omitted), reflecting B's true S4 status at raise time.
			expect(deepEqual(raisedCall.squadState, { [1] = "alive", [2] = "S4" })).to.equal(true)

			-- Simulate the (mocked) arbiter's own RunEnded broadcast resolving this raise.
			fake:_onRunEnded({ exitReason = "victory", squadState = raisedCall.squadState, timestamp = 12, defeatReason = nil })

			expect(fake._renderScope[playerB]).to.equal("post-run")
			expect(fake._renderScope[playerA]).to.equal("post-run")
			expect(fake._deathReconciliationState.deathStartedAt[playerB]).to.equal(nil)
			expect(fake._deathReconciliationState.currentDeathRecord[playerB]).to.equal(nil)
		end
		it(
			"test_s4_player_rescued_to_s5_victory_with_timer_cancelled_and_counted_survivor",
			test_s4_player_rescued_to_s5_victory_with_timer_cancelled_and_counted_survivor
		)
	end)

	describe("H.49 -- T7 raises exactly once, PC never broadcasts RunEnded", function()
		local function test_wipe_raises_exactly_once()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			fake:_setNow(10)
			killViaRealT5Path(fake, playerB, 10)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			fake:_evaluateT7Wipe(10)

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			expect(fake._runEndConditionRaisedCalls[1].conditionType).to.equal("wipe")
			expect(deepEqual(fake._runEndConditionRaisedCalls[1].squadState, { [1] = "S4", [2] = "S4" })).to.equal(true)
		end
		it("test_wipe_raises_exactly_once", test_wipe_raises_exactly_once)

		local function test_repeated_evaluation_never_re_raises()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			killViaRealT5Path(fake, playerB, 10)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			for i = 1, 20 do
				fake:_evaluateT7Wipe(10 + i)
			end

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
		end
		it("test_repeated_evaluation_never_re_raises", test_repeated_evaluation_never_re_raises)

		local function test_solo_squad_wipe_raises_via_the_fake()
			-- QA Gap 3 (Fake-level half): a solo (1-player) squad, all-S4 +
			-- oxygen<1, raises "wipe" through the REAL `_evaluateT7Wipe` wrapper
			-- logic (not just the pure `IsWholeSquadWiped` predicate above) --
			-- confirms there is no squad-size floor anywhere in the wrapper's own
			-- squad-scan/raise call chain either.
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:_setNow(0)
			fake:KnitStart()
			local playerA = { UserId = 1, Name = "Alice" }
			fake:_registerPlayer(playerA)
			killViaRealT5Path(fake, playerA, 10)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			fake:_evaluateT7Wipe(10)

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			expect(fake._runEndConditionRaisedCalls[1].conditionType).to.equal("wipe")
			expect(deepEqual(fake._runEndConditionRaisedCalls[1].squadState, { [1] = "S4" })).to.equal(true)
		end
		it("test_solo_squad_wipe_raises_via_the_fake", test_solo_squad_wipe_raises_via_the_fake)

		local function test_pc_itself_never_broadcasts_run_ended()
			-- PC's only "run end" side effect is the recorded call into the MOCKED
			-- arbiter above -- there is no second, competing broadcast call site
			-- anywhere in the Fake (which mirrors the real file's own absence of a
			-- `Client.RunEnded` signal -- see Section D's static proof below).
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			killViaRealT5Path(fake, playerB, 10)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			fake:_evaluateT7Wipe(10)

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			-- No player was force-transitioned to post-run by the RAISE itself -- only
			-- an inbound RunEnded (never called in this test) does that.
			expect(fake._renderScope[playerA]).to.equal("dead-respawning")
			expect(fake._renderScope[playerB]).to.equal("dead-respawning")
		end
		it("test_pc_itself_never_broadcasts_run_ended", test_pc_itself_never_broadcasts_run_ended)
	end)

	describe("H.50 -- wipe then victory, each exactly once, concrete snapshots, no PC-side mutation during the hold", function()
		local function test_full_race_scenario()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			killViaRealT5Path(fake, playerB, 10)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			-- (1) T7 fires at T=10.
			fake:_evaluateT7Wipe(10)
			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			local wipeCall = fake._runEndConditionRaisedCalls[1]
			expect(wipeCall.conditionType).to.equal("wipe")
			expect(deepEqual(wipeCall.squadState, { [1] = "S4", [2] = "S4" })).to.equal(true)

			-- (2) OnBeaconWindowSurvived fires at T+Delta, Delta < RUN_END_DEFEAT_HOLD (0.5s).
			local runEndDefeatHold = 0.5
			local delta = 0.2
			expect(delta < runEndDefeatHold).to.equal(true)
			fake:_setNow(10 + delta)
			fake:OnBeaconWindowSurvived(10 + delta)

			expect(#fake._runEndConditionRaisedCalls).to.equal(2)
			local victoryCall = fake._runEndConditionRaisedCalls[2]
			expect(victoryCall.conditionType).to.equal("victory")
			expect(deepEqual(victoryCall.squadState, { [1] = "S4", [2] = "S4" })).to.equal(true)

			-- Each snapshot is its OWN concrete table (deep-equal in content, not the
			-- same reference) -- H.50's "concrete, not shape-only" requirement.
			expect(wipeCall.squadState).never.to.equal(victoryCall.squadState)

			-- (3)/(4): throughout the hold window PC itself broadcasts no RunEnded, no
			-- defeat banner/UI, and mutates no run-end state on its own authority --
			-- the mocked arbiter was never asked to resolve (no `_onRunEnded` call), so
			-- both players remain exactly where the raise found them.
			expect(fake._renderScope[playerA]).to.equal("dead-respawning")
			expect(fake._renderScope[playerB]).to.equal("dead-respawning")
			expect(fake._deathReconciliationState.deathStartedAt[playerA]).never.to.equal(nil)
			expect(fake._deathReconciliationState.deathStartedAt[playerB]).never.to.equal(nil)
		end
		it("test_full_race_scenario", test_full_race_scenario)
	end)

	describe("H.61 -- post-activation whole-lifecycle suppression, pre-activation positive, latch-release both directions", function()
		local function test_post_activation_suppresses_wipe_for_the_whole_lifecycle()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			fake:OnEscapeBeaconActivated(1, 0, 90)
			killViaRealT5Path(fake, playerA, 10)
			killViaRealT5Path(fake, playerB, 10)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			-- Well past RUN_END_DEFEAT_HOLD (0.5s) -- still no raise, for the WHOLE
			-- post-activation lifecycle (not merely a hold window).
			fake:_evaluateT7Wipe(10)
			fake:_evaluateT7Wipe(10.5)
			fake:_evaluateT7Wipe(15)
			fake:_evaluateT7Wipe(60)

			expect(#fake._runEndConditionRaisedCalls).to.equal(0)
		end
		it(
			"test_post_activation_suppresses_wipe_for_the_whole_lifecycle",
			test_post_activation_suppresses_wipe_for_the_whole_lifecycle
		)

		local function test_pre_activation_positive_raises_wipe_exactly_once()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			-- No activation this time.
			killViaRealT5Path(fake, playerA, 10)
			killViaRealT5Path(fake, playerB, 10)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			fake:_evaluateT7Wipe(10)

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			expect(fake._runEndConditionRaisedCalls[1].conditionType).to.equal("wipe")
		end
		it("test_pre_activation_positive_raises_wipe_exactly_once", test_pre_activation_positive_raises_wipe_exactly_once)

		local function test_latch_clears_on_run_ended()
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:KnitStart()
			fake:OnEscapeBeaconActivated(1, 0, 90)
			expect(fake._runEndState.beaconActivated).to.equal(true)

			fake:_onRunEnded({ exitReason = "victory", squadState = {}, timestamp = 0, defeatReason = nil })

			expect(fake._runEndState.beaconActivated).to.equal(false)
		end
		it("test_latch_clears_on_run_ended", test_latch_clears_on_run_ended)

		local function test_latch_does_not_clear_on_non_run_ended_events_within_the_timeout_window()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			fake:OnEscapeBeaconActivated(1, 0, 90)
			expect(fake._runEndState.beaconActivated).to.equal(true)

			-- A T6 respawn attempt (an unrelated event) -- no one is dead, so this is a
			-- pure no-op scan, but it must not touch the latch either way.
			fake:_checkRespawnTimers(5)
			expect(fake._runEndState.beaconActivated).to.equal(true)

			-- An unrelated T7 evaluation (squad condition false -- no one is dead).
			fake:_evaluateT7Wipe(5)
			expect(fake._runEndState.beaconActivated).to.equal(true)

			-- A self-heal check well within the timeout window.
			fake:_checkBeaconLatchSelfHeal(5)
			expect(fake._runEndState.beaconActivated).to.equal(true)
		end
		it(
			"test_latch_does_not_clear_on_non_run_ended_events_within_the_timeout_window",
			test_latch_does_not_clear_on_non_run_ended_events_within_the_timeout_window
		)
	end)

	describe("H.61b -- bootstrap false/nil, N+1-run fresh start", function()
		local function test_bootstrap_before_any_activation()
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			expect(fake._runEndState.beaconActivated).to.equal(false)
			expect(fake._runEndState.beaconActivatedAt).to.equal(nil)
		end
		it("test_bootstrap_before_any_activation", test_bootstrap_before_any_activation)

		local function test_fresh_run_after_run_ended_never_ratchets()
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:KnitStart()
			fake:OnEscapeBeaconActivated(1, 0, 90)
			expect(fake._runEndState.beaconActivated).to.equal(true)

			-- Run 1 ends.
			fake:_onRunEnded({ exitReason = "victory", squadState = {}, timestamp = 0, defeatReason = nil })
			expect(fake._runEndState.beaconActivated).to.equal(false)
			expect(fake._runEndState.beaconActivatedAt).to.equal(nil)

			-- Run 2 (a fresh run on the same server session) begins with a clean slate --
			-- activation is possible again, never permanently latched by run 1.
			fake:OnEscapeBeaconActivated(1, 100, 90)
			expect(fake._runEndState.beaconActivated).to.equal(true)
		end
		it("test_fresh_run_after_run_ended_never_ratchets", test_fresh_run_after_run_ended_never_ratchets)

		local function test_wipe_re_raises_after_a_fresh_run_never_ratchets()
			-- QA Gap 2 (AC-3's literal QA Test Case promise): "the RAISE itself
			-- never ratchets across runs," not merely the latch boolean --
			-- distinct from `test_fresh_run_after_run_ended_never_ratchets`
			-- above, which only asserts `_beaconActivated` resets. This drives
			-- a SECOND, genuine pre-activation all-dead+oxygen<1 condition
			-- through `_evaluateT7Wipe` after a run boundary and asserts a NEW
			-- wipe raise actually fires (not silently swallowed by a stale
			-- `hasRaisedWipe` guard).
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			killViaRealT5Path(fake, playerB, 10)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			-- Run 1: pre-activation whole-squad wipe raises once.
			fake:_evaluateT7Wipe(10)
			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			expect(fake._runEndConditionRaisedCalls[1].conditionType).to.equal("wipe")

			-- Run 1 ends (the arbiter resolves the raised wipe) -- clears
			-- `hasRaisedWipe` back to false via `ClearOnRunEnded`.
			fake:_onRunEnded({
				exitReason = "wipe",
				squadState = fake._runEndConditionRaisedCalls[1].squadState,
				timestamp = 10,
				defeatReason = nil,
			})
			expect(fake._runEndState.hasRaisedWipe).to.equal(false)

			-- Run 2 (a fresh run, same server session): this Fake has no
			-- separate "next run" lifecycle that resets the SAME players back
			-- to "alive" (out of this story's scope) -- run 1's squad is
			-- removed from the roster (a fresh run's own squad, matching this
			-- codebase's own player-identity-is-opaque convention) so a NEW
			-- pair reaching the identical pre-activation all-dead condition
			-- has a clean squad-size/S4-count read.
			fake._playersByUserId[playerA.UserId] = nil
			fake._playersByUserId[playerB.UserId] = nil
			local playerC = { UserId = 3, Name = "Cara" }
			local playerD = { UserId = 4, Name = "Dana" }
			fake:_registerPlayer(playerC)
			fake:_registerPlayer(playerD)
			killViaRealT5Path(fake, playerC, 20)
			killViaRealT5Path(fake, playerD, 20)

			fake:_evaluateT7Wipe(20)

			-- The RAISE itself never ratchets -- a SECOND wipe condition, in a
			-- fresh run, raises again.
			expect(#fake._runEndConditionRaisedCalls).to.equal(2)
			expect(fake._runEndConditionRaisedCalls[2].conditionType).to.equal("wipe")
			expect(deepEqual(fake._runEndConditionRaisedCalls[2].squadState, { [3] = "S4", [4] = "S4" })).to.equal(true)
		end
		it(
			"test_wipe_re_raises_after_a_fresh_run_never_ratchets",
			test_wipe_re_raises_after_a_fresh_run_never_ratchets
		)
	end)

	describe("H.61c -- self-heal backstop, negative boundary, straggler RunEnded, double RunEnded", function()
		local function test_self_heal_fires_at_timeout_with_warning()
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:_setNow(0)
			fake:KnitStart()
			fake:OnEscapeBeaconActivated(1, 0, 90)
			capturedWarnings = {}

			fake:_checkBeaconLatchSelfHeal(RunEndLogic.BEACON_LATCH_TIMEOUT + 1)

			expect(fake._runEndState.beaconActivated).to.equal(false)
			expect(fake._runEndState.beaconActivatedAt).to.equal(nil)
			expect(#capturedWarnings).to.equal(1)
			expect(capturedWarnings[1]:find("beacon%-latch%-timeout") ~= nil).to.equal(true)
		end
		it("test_self_heal_fires_at_timeout_with_warning", test_self_heal_fires_at_timeout_with_warning)

		local function test_self_heal_re_enables_a_genuine_wipe_raise()
			-- QA Gap 1: proves the self-heal actually RE-ENABLES T7 end-to-end
			-- (composed through the real `_evaluateT7Wipe` wrapper), not merely
			-- that `ShouldSelfHealBeaconLatch`/`ForceSelfHeal` flip a boolean in
			-- isolation (Section A already covers that in the pure module).
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			fake:OnEscapeBeaconActivated(1, 0, 90)
			killViaRealT5Path(fake, playerA, 1)
			killViaRealT5Path(fake, playerB, 1)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			-- Latch active -- T7 suppressed even though the squad condition is
			-- already genuinely true.
			fake:_evaluateT7Wipe(1)
			expect(#fake._runEndConditionRaisedCalls).to.equal(0)

			-- Clock advances past BEACON_LATCH_TIMEOUT -- self-heal fires.
			fake:_checkBeaconLatchSelfHeal(RunEndLogic.BEACON_LATCH_TIMEOUT + 1)
			expect(fake._runEndState.beaconActivated).to.equal(false)

			-- The SAME genuine all-S4 + oxygen<1 condition, re-evaluated after
			-- the self-heal, now raises for real.
			fake:_evaluateT7Wipe(RunEndLogic.BEACON_LATCH_TIMEOUT + 1)

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			expect(fake._runEndConditionRaisedCalls[1].conditionType).to.equal("wipe")
		end
		it("test_self_heal_re_enables_a_genuine_wipe_raise", test_self_heal_re_enables_a_genuine_wipe_raise)

		local function test_self_heal_does_not_bypass_the_already_raised_guard()
			-- Paired negative (QA Gap 1): if `hasRaisedWipe` is ALREADY true
			-- BEFORE the self-heal fires, the self-heal must not re-open a
			-- second raise for the SAME still-true condition -- `ForceSelfHeal`
			-- never touches `hasRaisedWipe` (see its own doc comment), so the
			-- guard alone (not the latch) is what continues to block here.
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 1)
			killViaRealT5Path(fake, playerB, 1)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			-- Pre-activation raise (latch not active yet).
			fake:_evaluateT7Wipe(1)
			expect(#fake._runEndConditionRaisedCalls).to.equal(1)

			-- Activation arrives AFTER the raise (pathological ordering,
			-- exercised purely to isolate the raise-once guard from the latch)
			-- and later times out.
			fake:OnEscapeBeaconActivated(1, 1, 90)
			fake:_checkBeaconLatchSelfHeal(1 + RunEndLogic.BEACON_LATCH_TIMEOUT + 1)
			expect(fake._runEndState.beaconActivated).to.equal(false)

			-- Re-evaluating the SAME still-true condition after the self-heal
			-- must NOT re-raise.
			fake:_evaluateT7Wipe(1 + RunEndLogic.BEACON_LATCH_TIMEOUT + 1)

			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
		end
		it(
			"test_self_heal_does_not_bypass_the_already_raised_guard",
			test_self_heal_does_not_bypass_the_already_raised_guard
		)

		local function test_negative_boundary_timeout_minus_epsilon_stays_suppressed()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			fake:OnEscapeBeaconActivated(1, 0, 90)
			capturedWarnings = {}

			fake:_checkBeaconLatchSelfHeal(RunEndLogic.BEACON_LATCH_TIMEOUT - 0.01)

			expect(fake._runEndState.beaconActivated).to.equal(true)
			expect(#capturedWarnings).to.equal(0)

			-- T7 stays suppressed too (whole-post-activation-lifecycle suppression).
			killViaRealT5Path(fake, playerA, 1)
			killViaRealT5Path(fake, playerB, 1)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end
			fake:_evaluateT7Wipe(RunEndLogic.BEACON_LATCH_TIMEOUT - 0.01)
			expect(#fake._runEndConditionRaisedCalls).to.equal(0)
		end
		it(
			"test_negative_boundary_timeout_minus_epsilon_stays_suppressed",
			test_negative_boundary_timeout_minus_epsilon_stays_suppressed
		)

		local function test_straggler_run_ended_after_self_heal_is_idempotent_noop()
			local fake = FakePlayerControllerService.new()
			fake:KnitInit()
			fake:_setNow(0)
			fake:KnitStart()
			fake:OnEscapeBeaconActivated(1, 0, 90)
			fake:_checkBeaconLatchSelfHeal(RunEndLogic.BEACON_LATCH_TIMEOUT + 1)

			local stateAfterSelfHeal = {
				beaconActivated = fake._runEndState.beaconActivated,
				beaconActivatedAt = fake._runEndState.beaconActivatedAt,
				hasRaisedWipe = fake._runEndState.hasRaisedWipe,
				hasRaisedVictory = fake._runEndState.hasRaisedVictory,
			}

			-- A straggler RunEnded arrives AFTER the self-heal already cleared the latch.
			fake:_onRunEnded({ exitReason = "wipe", squadState = {}, timestamp = 999, defeatReason = nil })

			expect(deepEqual(fake._runEndState, stateAfterSelfHeal)).to.equal(true)
		end
		it(
			"test_straggler_run_ended_after_self_heal_is_idempotent_noop",
			test_straggler_run_ended_after_self_heal_is_idempotent_noop
		)

		local function test_double_run_ended_byte_identical_post_state()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerB, 10)

			local payload = { exitReason = "victory", squadState = {}, timestamp = 10, defeatReason = nil }
			fake:_onRunEnded(payload)

			local stateAfterFirst = {
				renderScopeA = fake._renderScope[playerA],
				renderScopeB = fake._renderScope[playerB],
				runEndState = {
					beaconActivated = fake._runEndState.beaconActivated,
					beaconActivatedAt = fake._runEndState.beaconActivatedAt,
					hasRaisedWipe = fake._runEndState.hasRaisedWipe,
					hasRaisedVictory = fake._runEndState.hasRaisedVictory,
				},
				deathStartedAtB = fake._deathReconciliationState.deathStartedAt[playerB],
				pushCountA = fake._renderScopePushCount[playerA],
				pushCountB = fake._renderScopePushCount[playerB],
			}

			-- Second broadcast for the SAME run (no self-heal involved).
			fake:_onRunEnded(payload)

			local stateAfterSecond = {
				renderScopeA = fake._renderScope[playerA],
				renderScopeB = fake._renderScope[playerB],
				runEndState = {
					beaconActivated = fake._runEndState.beaconActivated,
					beaconActivatedAt = fake._runEndState.beaconActivatedAt,
					hasRaisedWipe = fake._runEndState.hasRaisedWipe,
					hasRaisedVictory = fake._runEndState.hasRaisedVictory,
				},
				deathStartedAtB = fake._deathReconciliationState.deathStartedAt[playerB],
				pushCountA = fake._renderScopePushCount[playerA],
				pushCountB = fake._renderScopePushCount[playerB],
			}

			expect(deepEqual(stateAfterFirst, stateAfterSecond)).to.equal(true)
			-- Also confirm the SECOND broadcast pushed no ADDITIONAL renderScope
			-- transitions (both players already "post-run" -- idempotent no-op).
			expect(stateAfterSecond.pushCountA).to.equal(stateAfterFirst.pushCountA)
			expect(stateAfterSecond.pushCountB).to.equal(stateAfterFirst.pushCountB)
		end
		it("test_double_run_ended_byte_identical_post_state", test_double_run_ended_byte_identical_post_state)
	end)

	describe("Behavioral same-tick race -- T7 wipe pre-empts a same-tick-elapsed respawn timer (engine Finding 1 / QA edge 3)", function()
		local function test_wipe_raise_preempts_a_same_tick_completed_respawn_timer()
			local fake, playerA, playerB = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 0)
			killViaRealT5Path(fake, playerB, 0)
			fake._getSquadOxygenPoolFn = function(): number
				return 0
			end

			local respawnedCount = 0
			fake._onPlayerT6RespawnedFn = function(_userId: number): ()
				respawnedCount += 1
			end

			-- This test's own arbiter override ALSO synchronously invokes
			-- `_onRunEnded` -- mirroring the REAL, already-implemented
			-- RunController's own dispatch contract (`RunEndConditionRaised` ->
			-- `Signal:Fire()` -> every connected subscriber, including PC's own
			-- `_onRunEnded`, runs SYNCHRONOUSLY within the same call, per
			-- ADR-0001's zero-yield `Signal:Fire()` dispatch guarantee). Every
			-- OTHER test in this file leaves the mock non-resolving on purpose
			-- (H.50 needs to observe the UNRESOLVED-hold state); THIS test's
			-- whole point is the opposite -- proving the composed Heartbeat
			-- ordering correctly pre-empts a same-tick respawn when the arbiter
			-- resolves as fast as production actually does.
			fake._requestRunEndConditionRaisedFn = function(conditionType: string, squadState: any, defeatReason: string?): ()
				table.insert(fake._runEndConditionRaisedCalls, {
					conditionType = conditionType,
					squadState = squadState,
					defeatReason = defeatReason,
				})
				fake:_onRunEnded({
					exitReason = conditionType,
					squadState = squadState,
					timestamp = fake._now,
					defeatReason = defeatReason,
				})
			end

			-- Both players' respawn timers have fully elapsed (RESPAWN_DELAY=30s)
			-- AT THE SAME INSTANT the whole-squad-wipe condition is true -- the
			-- exact same-tick race this test targets. `_onDeathReconciliationHeartbeat`
			-- runs the REAL composed order: self-heal, THEN T7, THEN respawn timers.
			local now = ReconLogic.RESPAWN_DELAY
			fake:_onDeathReconciliationHeartbeat(now)

			-- Exactly one wipe raise fired.
			expect(#fake._runEndConditionRaisedCalls).to.equal(1)
			expect(fake._runEndConditionRaisedCalls[1].conditionType).to.equal("wipe")

			-- The wipe raise (synchronously resolved by the arbiter override
			-- above) already drove both players to "post-run" and force-
			-- cancelled their respawn timers BEFORE `_checkRespawnTimers` ran
			-- later in the SAME tick -- so both land post-run, neither is
			-- tracked as dead anymore, and the respawn-completion path
			-- (`_completeRespawn`, the ONLY call site that fires
			-- `OnPlayerT6Respawned` or re-mints "alive") was never reached for
			-- either player.
			expect(fake._renderScope[playerA]).to.equal("post-run")
			expect(fake._renderScope[playerB]).to.equal("post-run")
			expect(fake._deathReconciliationState.deathStartedAt[playerA]).to.equal(nil)
			expect(fake._deathReconciliationState.deathStartedAt[playerB]).to.equal(nil)
			expect(respawnedCount).to.equal(0)
		end
		it(
			"test_wipe_raise_preempts_a_same_tick_completed_respawn_timer",
			test_wipe_raise_preempts_a_same_tick_completed_respawn_timer
		)
	end)

	-- ==========================================================================
	-- Section D -- static/structural source-text checks against the real
	-- PlayerControllerService.luau (see header note (b) above).
	-- ==========================================================================

	local function stripLuaComments(source: string): string
		local strippedLines = {}
		for line in (source .. "\n"):gmatch("([^\n]*)\n") do
			local codeOnly = line:match("^(.-)%-%-") or line
			table.insert(strippedLines, codeOnly)
		end
		return table.concat(strippedLines, "\n")
	end

	local serviceSource: string? = nil
	local function loadServiceSource(): string
		if not serviceSource then
			serviceSource = stripLuaComments(fs.readFile("src/gameplay/services/PlayerControllerService.luau"))
		end
		return serviceSource :: string
	end

	local function extractMethodBody(source: string, methodName: string): string
		local startPattern = "function PlayerControllerService:" .. methodName .. "%("
		local startIdx = source:find(startPattern)
		expect(startIdx).never.to.equal(nil)
		local nextFnIdx = source:find("\nfunction PlayerControllerService:", (startIdx :: number) + 1)
		if nextFnIdx then
			return source:sub(startIdx :: number, nextFnIdx)
		end
		return source:sub(startIdx :: number)
	end

	describe("PlayerControllerService.luau -- Story 009 (wiring, static/structural checks)", function()
		local function test_client_table_never_declares_a_run_ended_signal()
			-- The control manifest's own binding rule: PC never broadcasts RunEnded.
			-- Proven here via the three literal shapes a Client-facing RunEnded signal
			-- would have to take -- none appear anywhere in the file (the only real
			-- `RunEnded` occurrences are the INBOUND `RunEndedPayload` type alias and
			-- the `GetRunEndedSignal()` / `_onRunEnded` call sites, both asserted by
			-- other tests in this section).
			local source = loadServiceSource()
			expect(source:find("RunEnded = Knit%.CreateSignal%(%)")).to.equal(nil)
			expect(source:find("%.RunEnded:FireAll%(")).to.equal(nil)
			expect(source:find("%.RunEnded:Fire%(")).to.equal(nil)
			expect(source:find("Client%.RunEnded")).to.equal(nil)
		end
		it("test_client_table_never_declares_a_run_ended_signal", test_client_table_never_declares_a_run_ended_signal)

		local function test_default_arbiter_seam_calls_only_run_end_condition_raised()
			local source = loadServiceSource()
			local body = extractMethodBody(source, "KnitInit")
			local seamIdx = body:find("self%._requestRunEndConditionRaisedFn = function")
			expect(seamIdx).never.to.equal(nil)
			local seamEndIdx = body:find("\tend", seamIdx :: number)
			expect(seamEndIdx).never.to.equal(nil)
			local seamBody = body:sub(seamIdx :: number, seamEndIdx :: number)
			expect(seamBody:find("self%._runController:RunEndConditionRaised%(")).never.to.equal(nil)
			expect(seamBody:find(":FireAll%(")).to.equal(nil)
			expect(seamBody:find(":Fire%(")).to.equal(nil)
		end
		it(
			"test_default_arbiter_seam_calls_only_run_end_condition_raised",
			test_default_arbiter_seam_calls_only_run_end_condition_raised
		)

		local function test_on_escape_beacon_activated_never_calls_the_arbiter_seam()
			local source = loadServiceSource()
			local body = extractMethodBody(source, "OnEscapeBeaconActivated")
			expect(body:find("_requestRunEndConditionRaisedFn")).to.equal(nil)
			expect(body:find("RunEndLogic%.ActivateBeaconLatch%(")).never.to.equal(nil)
		end
		it(
			"test_on_escape_beacon_activated_never_calls_the_arbiter_seam",
			test_on_escape_beacon_activated_never_calls_the_arbiter_seam
		)

		local function test_on_beacon_window_survived_raises_victory_not_wipe()
			local source = loadServiceSource()
			local body = extractMethodBody(source, "OnBeaconWindowSurvived")
			expect(body:find('"victory"')).never.to.equal(nil)
			expect(body:find('"wipe"')).to.equal(nil)
		end
		it("test_on_beacon_window_survived_raises_victory_not_wipe", test_on_beacon_window_survived_raises_victory_not_wipe)

		local function test_self_heal_warn_string_contains_the_tag()
			local source = loadServiceSource()
			local body = extractMethodBody(source, "_checkBeaconLatchSelfHeal")
			expect(body:find("beacon%-latch%-timeout")).never.to.equal(nil)
		end
		it("test_self_heal_warn_string_contains_the_tag", test_self_heal_warn_string_contains_the_tag)

		local function test_heartbeat_ordering_self_heal_and_t7_before_respawn_timers()
			local source = loadServiceSource()
			local body = extractMethodBody(source, "_onDeathReconciliationHeartbeat")
			local selfHealIdx = body:find("self:_checkBeaconLatchSelfHeal%(")
			local t7Idx = body:find("self:_evaluateT7Wipe%(")
			local respawnIdx = body:find("self:_checkRespawnTimers%(")
			expect(selfHealIdx).never.to.equal(nil)
			expect(t7Idx).never.to.equal(nil)
			expect(respawnIdx).never.to.equal(nil)
			expect((selfHealIdx :: number) < (t7Idx :: number)).to.equal(true)
			expect((t7Idx :: number) < (respawnIdx :: number)).to.equal(true)
		end
		it(
			"test_heartbeat_ordering_self_heal_and_t7_before_respawn_timers",
			test_heartbeat_ordering_self_heal_and_t7_before_respawn_timers
		)

		local function test_on_run_ended_uses_force_cancel_not_try_respawn()
			local source = loadServiceSource()
			local body = extractMethodBody(source, "_onRunEnded")
			expect(body:find("RunEndLogic%.ForceCancelRespawnTimer%(")).never.to.equal(nil)
			expect(body:find("TryRespawn")).to.equal(nil)
			expect(body:find("self:EnterPostRunScope%(player%)")).never.to.equal(nil)
		end
		it("test_on_run_ended_uses_force_cancel_not_try_respawn", test_on_run_ended_uses_force_cancel_not_try_respawn)

		local function test_run_controller_acquired_in_knit_start_not_knit_init()
			local source = loadServiceSource()
			local knitStartBody = extractMethodBody(source, "KnitStart")
			expect(knitStartBody:find('Knit%.GetService%("RunController"%)')).never.to.equal(nil)
			expect(knitStartBody:find("GetRunEndedSignal%(%):Connect%(")).never.to.equal(nil)
		end
		it(
			"test_run_controller_acquired_in_knit_start_not_knit_init",
			test_run_controller_acquired_in_knit_start_not_knit_init
		)
	end)
end
