--!strict
-- death-respawn-side-effects_test
--
-- Integration tests for Story 005: Death/Respawn Side-Effects & Cross-Service Signals
-- (T5/T6).
-- Story: production/epics/player-controller/story-005-death-respawn-side-effects.md
-- ADR: docs/architecture/adr-0005-death-respawn-lifecycle.md (THE LAW -- three
--      commit-INDEPENDENT run-fact side-effects fire synchronously pre-yield, never
--      gated on the oxygen charge's success)
--
-- Production code under test:
--   src/gameplay/services/PlayerControllerDeathSideEffectsLogic.luau -- the REAL, pure,
--     zero-require side-effect SELECTION module (dispatchOrigin/pathOrigin ->
--     which of (a)-(i) fire + the deathCause string), exercised DIRECTLY (first
--     section below).
--   src/gameplay/services/PlayerControllerService.luau -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live PlayerControllerService
--     instance cannot be constructed here (same precedent every prior PC/ED test in
--     this repo documents). Verified two ways instead:
--       (a) FakePlayerControllerService below mirrors the real Knit wrapper's Story
--           005 method bodies (`_onPlayerDied`/`_beginDeathFlow`/`_beginAndDispatch`/
--           `_completeDispatch`/`_runReconciliationTick`/`_checkRespawnTimers`/
--           `_completeRespawn`/`_applyPreYieldDeathSideEffects`/
--           `_applyPostCommitDeathSideEffects`/`_setDeathEffectFlag`/
--           `ResetGraceAnchorsOnDeath`) method-for-method, per pc-4's own established
--           Fake-harness precedent. DISCLOSED SUBSTITUTIONS (not silently glossed
--           over):
--             1. `_beginAndDispatch` calls `_completeDispatch` SYNCHRONOUSLY where the
--                real wrapper `task.spawn`s it -- deterministic single-threaded test
--                execution; the state-machine TRANSITIONS and side-effect SELECTIONS
--                exercised are identical to production (pc-4's own precedent).
--             2. `player` values are plain Lua tables (`{UserId, Name}`), never real
--                Roblox `Player` instances -- this project's Lune harness cannot
--                construct a live Player/Character/CharacterAdded chain at all (see
--                PlayerControllerDeathSideEffectsLogic.luau's own PLAYER IDENTITY
--                precedent).
--             3. `_runReconciliationTick`'s player-resolution uses a Fake-local
--                `self._playersByUserId` registry instead of the real
--                `Players:GetPlayerByUserId(...)` (a real Roblox API this harness has
--                no live `Players` service player list to back).
--             4. `_completeRespawn`'s `_respawnPlayerAtAnchorFn`/
--                `_getRespawnAnchorPositionFn` seams are ALWAYS test-overridden (never
--                exercising the real `_defaultRespawnPlayerAtAnchor`'s
--                `Player:LoadCharacter()` call) -- STUDIO VERIFICATION REQUIRED per
--                that method's own doc comment; this harness can only prove the
--                ORDERING contract (respawn-placement resolves BEFORE the alive=true
--                edge), not the real Roblox respawn mechanics themselves.
--       (b) static/structural source-text checks against the real
--           PlayerControllerService.luau (mirrors death-cost-reconciliation-core_test
--           .luau's own established pattern, including its documented
--           stripLuaComments `--`-in-string caveat).
--
-- Story Type: Integration -- coding-standards.md's bar is an automated integration
-- test that must pass (BLOCKING gate).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local ReconLogic = require(ServerScriptService.gameplay.services.PlayerControllerDeathReconciliationLogic)
local SideEffectsLogic = require(ServerScriptService.gameplay.services.PlayerControllerDeathSideEffectsLogic)
local LocomotionStaminaLogic = require(ServerScriptService.gameplay.services.PlayerControllerLocomotionStaminaLogic)
local LanternLogic = require(ServerScriptService.gameplay.services.PlayerControllerLanternLogic)
local EmissionPublisherLogic = require(ServerScriptService.gameplay.services.PlayerControllerEmissionPublisherLogic)

type ReconcileRow = ReconLogic.ReconcileRow

-- ============================================================================
-- FakePlayerControllerService -- see header note (a) above.
-- ============================================================================

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

	-- HARNESS DISCLOSURE (see file header note (a).1): real production `task.spawn`s
	-- this; called synchronously here for deterministic single-threaded execution.
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

function FakePlayerControllerService:_runReconciliationTick(now: number): ()
	local reconState = self._deathReconciliationState
	if not ReconLogic.ShouldRunReconciliationTick(reconState.lastTickTime, now, ReconLogic.RECONCILIATION_TICK_INTERVAL) then
		return
	end
	reconState.lastTickTime = now

	ReconLogic.RunStalenessSweep(reconState.reconcileRows, now, ReconLogic.STALENESS_SWEEP_THRESHOLD)

	local eligibleRows = ReconLogic.ScanPendingRows(reconState.reconcileRows)
	for _, row in eligibleRows do
		-- HARNESS DISCLOSURE (see file header note (a).3): the Fake-local registry
		-- stands in for the real `Players:GetPlayerByUserId(...)`.
		local player = self._playersByUserId[row.userId]
		self:_beginAndDispatch(row, now, "reconciliation", player, nil)
	end
end

function FakePlayerControllerService:_checkRespawnTimers(now: number): ()
	local reconState = self._deathReconciliationState
	local trackedPlayers: { any } = {}
	for player in reconState.deathStartedAt do
		table.insert(trackedPlayers, player)
	end
	for _, player in trackedPlayers do
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

	-- HARNESS DISCLOSURE (see file header note (a).1): the real wrapper
	-- `task.spawn`s this remainder off the Heartbeat handler (code-review fix,
	-- isolating `LoadCharacter`'s yield/error risk per player); called
	-- synchronously here for deterministic single-threaded execution, matching
	-- this Fake's own established `_beginAndDispatch`/`_completeDispatch`
	-- simplification. The real wrapper's liveness re-check
	-- (`Players:GetPlayerByUserId(player.UserId) == player`) is mirrored via the
	-- Fake-local `self._playersByUserId` registry (see file header note (a).3).
	if self._playersByUserId[player.UserId] ~= player then
		return
	end

	local anchorPosition = self._getRespawnAnchorPositionFn(player)
	local hrp = self._respawnPlayerAtAnchorFn(player, anchorPosition)

	self._lastServerTrackedPosition[player] = anchorPosition

	self._onPlayerT6RespawnedFn(player.UserId)

	if hrp then
		self._onSquadMemberAliveChangedFn(player.UserId, true)
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
	end

	if effects.releasePredatorLock then
		self._releasePredatorLockFn(row.userId)
	end
end

local function newServiceWithPlayer(userId: number)
	local service = FakePlayerControllerService.new()
	service:KnitInit()
	service:_setNow(0.0)
	service:KnitStart()
	local player = { UserId = userId, Name = "Player" .. tostring(userId) }
	service:_registerPlayer(player)
	return service, player
end

return function()
	-- ============================================================================
	-- Pure module: PlayerControllerDeathSideEffectsLogic -- direct, fast, exhaustive
	-- unit coverage of the selection logic every AC below ultimately depends on.
	-- ============================================================================
	describe("PlayerControllerDeathSideEffectsLogic -- ResolveDeathCause", function()
		it("test_resolve_death_cause_initial_path_a_is_predator_kill", function()
			expect(SideEffectsLogic.ResolveDeathCause("initial", "A")).to.equal("predator-kill")
		end)

		it("test_resolve_death_cause_initial_path_b_is_disconnect_while_damaged", function()
			expect(SideEffectsLogic.ResolveDeathCause("initial", "B")).to.equal("disconnect-while-damaged")
		end)

		it("test_resolve_death_cause_reconciliation_always_recovery_regardless_of_path", function()
			expect(SideEffectsLogic.ResolveDeathCause("reconciliation", "A")).to.equal("reconciliation-recovery")
			expect(SideEffectsLogic.ResolveDeathCause("reconciliation", "B")).to.equal("reconciliation-recovery")
			expect(SideEffectsLogic.ResolveDeathCause("reconciliation", nil)).to.equal("reconciliation-recovery")
		end)
	end)

	describe("PlayerControllerDeathSideEffectsLogic -- pre-yield selection ((g)/(h)/(i))", function()
		it("test_release_lock_preyield_fires_initial_only", function()
			expect(SideEffectsLogic.ShouldFireReleasePredatorLockPreYield("initial")).to.equal(true)
			expect(SideEffectsLogic.ShouldFireReleasePredatorLockPreYield("reconciliation")).to.equal(false)
		end)

		it("test_s4_entered_preyield_fires_initial_path_a_only", function()
			expect(SideEffectsLogic.ShouldFireOnPlayerS4EnteredPreYield("initial", "A")).to.equal(true)
			expect(SideEffectsLogic.ShouldFireOnPlayerS4EnteredPreYield("initial", "B")).to.equal(false)
			expect(SideEffectsLogic.ShouldFireOnPlayerS4EnteredPreYield("reconciliation", "A")).to.equal(false)
			expect(SideEffectsLogic.ShouldFireOnPlayerS4EnteredPreYield("initial", nil)).to.equal(false)
		end)

		it("test_alive_edge_false_preyield_fires_initial_only", function()
			expect(SideEffectsLogic.ShouldFireAliveEdgeFalsePreYield("initial")).to.equal(true)
			expect(SideEffectsLogic.ShouldFireAliveEdgeFalsePreYield("reconciliation")).to.equal(false)
		end)
	end)

	describe("PlayerControllerDeathSideEffectsLogic -- SelectPostCommitSideEffects", function()
		it("test_initial_path_a_full_set_minus_g", function()
			local e = SideEffectsLogic.SelectPostCommitSideEffects("initial", "A")
			expect(e.deathCause).to.equal("predator-kill")
			expect(e.sprintReset).to.equal(true)
			expect(e.lanternReset).to.equal(true)
			expect(e.freezeStamina).to.equal(true)
			expect(e.resetGraceAnchors).to.equal(true)
			expect(e.activateSpectatorCamera).to.equal(true)
			expect(e.lockClientInput).to.equal(true)
			expect(e.releasePredatorLock).to.equal(false)
		end)

		it("test_initial_path_b_suppresses_def_and_release_lock", function()
			local e = SideEffectsLogic.SelectPostCommitSideEffects("initial", "B")
			expect(e.deathCause).to.equal("disconnect-while-damaged")
			expect(e.sprintReset).to.equal(true)
			expect(e.lanternReset).to.equal(true)
			expect(e.resetGraceAnchors).to.equal(false)
			expect(e.activateSpectatorCamera).to.equal(false)
			expect(e.lockClientInput).to.equal(false)
			expect(e.releasePredatorLock).to.equal(false)
		end)

		it("test_reconciliation_only_a_b_g", function()
			local e = SideEffectsLogic.SelectPostCommitSideEffects("reconciliation", nil)
			expect(e.deathCause).to.equal("reconciliation-recovery")
			expect(e.sprintReset).to.equal(true)
			expect(e.lanternReset).to.equal(true)
			expect(e.freezeStamina).to.equal(false)
			expect(e.resetGraceAnchors).to.equal(false)
			expect(e.activateSpectatorCamera).to.equal(false)
			expect(e.lockClientInput).to.equal(false)
			expect(e.releasePredatorLock).to.equal(true)
		end)
	end)

	-- ============================================================================
	-- H.51 -- ReleasePredatorLock both paths + idempotent reconciliation re-invoke.
	-- ============================================================================
	describe("Story 005 -- H.51 (ReleasePredatorLock both paths + idempotent reconciliation)", function()
		it("test_h51_path_a_releases_lock_exactly_once", function()
			local service, player = newServiceWithPlayer(1)
			local releaseCalls = 0
			service._releasePredatorLockFn = function(_userId: number)
				releaseCalls += 1
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = true })

			expect(releaseCalls).to.equal(1)
		end)

		it("test_h51_path_b_releases_lock_exactly_once", function()
			local service, player = newServiceWithPlayer(2)
			local releaseCalls = 0
			service._releasePredatorLockFn = function(_userId: number)
				releaseCalls += 1
			end

			service:_beginDeathFlow(player, 0.0, "B")

			expect(releaseCalls).to.equal(1)
		end)

		it("test_h51_reconciliation_success_reinvokes_idempotently_net_one_effective_release", function()
			local service, player = newServiceWithPlayer(3)
			local releaseCalls = 0
			service._releasePredatorLockFn = function(_userId: number)
				releaseCalls += 1
			end

			local outage = true
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				if outage then
					error("simulated RM outage")
				end
				return true
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = true })
			-- (g) already fired pre-yield at the initial dispatch, REGARDLESS of the
			-- charge's later outcome (ADR-0005: "never gated on the oxygen charge's
			-- success").
			expect(releaseCalls).to.equal(1)

			outage = false
			service:_setNow(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)
			service:_runReconciliationTick(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)

			-- Reconciliation-success re-invokes (g) post-commit (R6-B8 subset) -- a
			-- SECOND call. Idempotent IN PRODUCTION (releasing an already-released lock
			-- is a no-op per ADR-0005) -- net ONE effective release; TWO calls is the
			-- correct, expected count for this design (this mock does not itself model
			-- idempotency -- that is PredatorService's own contract, out of scope here).
			expect(releaseCalls).to.equal(2)
		end)
	end)

	-- ============================================================================
	-- H.59 -- OnPlayerS4Entered Path A exactly once, Path B zero, never re-fired by
	-- a reconciliation tick.
	-- ============================================================================
	describe("Story 005 -- H.59 (OnPlayerS4Entered Path A exactly once, Path B zero)", function()
		it("test_h59_path_a_fires_exactly_once", function()
			local service, player = newServiceWithPlayer(1)
			local s4Calls = 0
			service._onPlayerS4EnteredFn = function(_userId: number)
				s4Calls += 1
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })

			expect(s4Calls).to.equal(1)
		end)

		-- Path-B negative: ADVISORY per the story's own text ("the mock's 'never
		-- re-acquires' half is vacuous-against-mock until Predator AI's GDD exists")
		-- -- this test proves PC's fire-side obligation only (the real BLOCKING gate).
		it("test_h59_path_b_fires_zero_times_ADVISORY_fire_side_only", function()
			local service, player = newServiceWithPlayer(2)
			local s4Calls = 0
			service._onPlayerS4EnteredFn = function(_userId: number)
				s4Calls += 1
			end

			service:_beginDeathFlow(player, 0.0, "B")

			expect(s4Calls).to.equal(0)
		end)

		it("test_h59_reconciliation_ticks_never_re_fire", function()
			local service, player = newServiceWithPlayer(3)
			local s4Calls = 0
			service._onPlayerS4EnteredFn = function(_userId: number)
				s4Calls += 1
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })
			expect(s4Calls).to.equal(1)

			-- Committed row: subsequent ticks skip it (ScanPendingRows selects only
			-- "Pending") -- confirms no re-fire even after several ticks.
			for i = 1, 3 do
				local t = ReconLogic.RECONCILIATION_TICK_INTERVAL * i + 1.0
				service:_setNow(t)
				service:_runReconciliationTick(t)
			end
			expect(s4Calls).to.equal(1)
		end)
	end)

	-- ============================================================================
	-- H.60 -- OnPlayerT6Respawned exactly once, ONLY from T6.
	-- ============================================================================
	describe("Story 005 -- H.60 (OnPlayerT6Respawned exactly once, T6 only)", function()
		it("test_h60_fires_exactly_once_only_at_t6", function()
			local service, player = newServiceWithPlayer(1)
			local t6Calls = 0
			service._onPlayerT6RespawnedFn = function(_userId: number)
				t6Calls += 1
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })
			expect(t6Calls).to.equal(0) -- not at T5

			-- A replayed Died before T6 is refused by the idempotent guard -- no T6 call.
			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.1, predatorWasLockedAtDeath = false })
			expect(t6Calls).to.equal(0)

			-- A reconciliation tick before T6 does not fire it either (row already
			-- Committed -- ScanPendingRows skips it structurally).
			service:_setNow(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)
			service:_runReconciliationTick(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)
			expect(t6Calls).to.equal(0)

			-- T6 elapses.
			service:_setNow(ReconLogic.RESPAWN_DELAY)
			service:_checkRespawnTimers(ReconLogic.RESPAWN_DELAY)
			expect(t6Calls).to.equal(1)

			-- A stray extra respawn-timer check afterward (no active death tracked for
			-- this player anymore) does not re-fire it.
			service:_setNow(ReconLogic.RESPAWN_DELAY + 5.0)
			service:_checkRespawnTimers(ReconLogic.RESPAWN_DELAY + 5.0)
			expect(t6Calls).to.equal(1)
		end)
	end)

	-- ============================================================================
	-- H.72 -- alive-edge timing + anchor-position ordering.
	-- ============================================================================
	describe("Story 005 -- H.72 (alive-edge timing + anchor-position ordering)", function()
		it("test_h72_false_edge_at_t5_true_edge_at_t6_after_placement_no_duplicate_on_replay", function()
			local service, player = newServiceWithPlayer(1)

			local aliveEdges: { { userId: number, isAlive: boolean } } = {}
			local ANCHOR = Vector3.new(42, 5, -17)

			-- Ordering-SENSITIVE capture (code-review fix): read
			-- `service._lastServerTrackedPosition[player]` and the fake-HRP's
			-- truthiness INSIDE the alive=true callback itself, at the exact moment it
			-- fires -- not after `_checkRespawnTimers` returns. This is what actually
			-- proves "positioned before the edge fires" rather than merely "positioned
			-- by the time the whole call finished."
			local positionAtAliveTrueFireTime: Vector3? = nil
			local hrpTruthyAtAliveTrueFireTime: boolean? = nil
			service._onSquadMemberAliveChangedFn = function(userId: number, isAlive: boolean)
				table.insert(aliveEdges, { userId = userId, isAlive = isAlive })
				if isAlive then
					positionAtAliveTrueFireTime = service._lastServerTrackedPosition[player]
					hrpTruthyAtAliveTrueFireTime = service._respawnHrpForOrderingCheck ~= nil
				end
			end

			service._getRespawnAnchorPositionFn = function(_player: any): Vector3
				return ANCHOR
			end

			local observedPositionAtPlacement: Vector3? = nil
			service._respawnPlayerAtAnchorFn = function(_player: any, anchorPosition: Vector3): any?
				-- Simulates the real HRP being positioned at the anchor BEFORE this
				-- returns (mirrors the real `_defaultRespawnPlayerAtAnchor`'s own
				-- `LoadCharacter` + `hrp.CFrame = CFrame.new(anchorPosition)` sequence).
				observedPositionAtPlacement = anchorPosition
				local hrp = { Position = anchorPosition } -- fake HumanoidRootPart marker
				service._respawnHrpForOrderingCheck = hrp
				return hrp
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })
			expect(#aliveEdges).to.equal(1)
			expect(aliveEdges[1].userId).to.equal(1)
			expect(aliveEdges[1].isAlive).to.equal(false)

			-- Replayed Died -- refused by the idempotent guard -- no duplicate edge.
			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.1, predatorWasLockedAtDeath = false })
			expect(#aliveEdges).to.equal(1)

			service:_setNow(ReconLogic.RESPAWN_DELAY)
			service:_checkRespawnTimers(ReconLogic.RESPAWN_DELAY)

			expect(#aliveEdges).to.equal(2)
			expect(aliveEdges[2].userId).to.equal(1)
			expect(aliveEdges[2].isAlive).to.equal(true)

			-- Ordering + position: placement resolves (mock records the position it was
			-- CALLED with) strictly before the alive=true edge in `_completeRespawn`'s
			-- own call order, and the recorded position equals the injected anchor --
			-- never the world origin.
			expect(observedPositionAtPlacement).to.equal(ANCHOR)
			expect(service._lastServerTrackedPosition[player]).to.equal(ANCHOR)

			-- Ordering-sensitive assertions: AT THE MOMENT the alive=true edge fired,
			-- the position cache was ALREADY the anchor and the HRP had ALREADY been
			-- produced -- proving placement-before-edge, not just placement-by-the-end.
			expect(positionAtAliveTrueFireTime).to.equal(ANCHOR)
			expect(hrpTruthyAtAliveTrueFireTime).to.equal(true)
		end)

		it("test_h72_alive_true_never_fires_if_hrp_placement_not_confirmed", function()
			local service, player = newServiceWithPlayer(2)
			local aliveTrueCalls = 0
			service._onSquadMemberAliveChangedFn = function(_userId: number, isAlive: boolean)
				if isAlive then
					aliveTrueCalls += 1
				end
			end
			service._respawnPlayerAtAnchorFn = function(_player: any, _anchorPosition: Vector3): any?
				return nil -- placement could not be confirmed
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })
			service:_setNow(ReconLogic.RESPAWN_DELAY)
			service:_checkRespawnTimers(ReconLogic.RESPAWN_DELAY)

			expect(aliveTrueCalls).to.equal(0)
		end)
	end)

	-- ============================================================================
	-- H.75 -- dispatch-origin vs live-pointer independence.
	-- ============================================================================
	describe("Story 005 -- H.75 (dispatch-origin vs live-pointer independence)", function()
		it("test_h75_orphaned_initial_dispatch_still_runs_full_initial_set", function()
			local service, player = newServiceWithPlayer(1)

			-- Pre-death: player mid-sprint, lantern raised -- proves (a)/(b)/(d) touch
			-- REAL per-player state even on this orphaned path.
			local locState = service._locomotionState[player]
			LocomotionStaminaLogic.HandleSprintToggleDomain(locState, true, 0.0) -- enters S2
			service._playerState[player].locomotion = "S2"
			service._playerState[player].lantern = "S3b"
			EmissionPublisherLogic.OnAxisEntered(service._emissionState[player].sprint, Vector3.new(0, 0, 0), 0.0)
			EmissionPublisherLogic.OnAxisEntered(service._emissionState[player].light, Vector3.new(0, 0, 0), 0.0)
			service._emissionState[player].sprint.t_lastGracePulse = 999.0 -- must become nil at (d)
			service._emissionState[player].light.t_lastGracePulse = 999.0

			local broadcastCalls: { { userId: number, deathCause: string } } = {}
			service._broadcastPlayerDiedFn = function(userId: number, deathCause: string)
				table.insert(broadcastCalls, { userId = userId, deathCause = deathCause })
			end

			local totalReleaseLockCalls = 0
			service._releasePredatorLockFn = function(_userId: number)
				totalReleaseLockCalls += 1
			end

			-- Mid-yield departure simulation: the spend mock itself detaches the live
			-- pointer BEFORE returning success -- the coroutine-local dispatchOrigin
			-- captured at dispatch time is untouched by this (see
			-- PlayerControllerService.luau's own `_beginAndDispatch` doc comment).
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				service._deathReconciliationState.currentDeathRecord[player] = nil
				return true
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })

			-- (g) fired ONCE, pre-yield -- NOT re-fired post-commit on an initial
			-- dispatch (H.51/H.70).
			expect(totalReleaseLockCalls).to.equal(1)

			-- Broadcast: full initial set selects the real Path-A deathCause.
			expect(#broadcastCalls).to.equal(1)
			expect(broadcastCalls[1].deathCause).to.equal(SideEffectsLogic.DEATH_CAUSE_PATH_A)

			-- (a)/(b): real per-player state WAS touched, despite no live pointer.
			expect(locState.locomotion).to.equal("S1")
			expect(service._playerState[player].locomotion).to.equal("S1")
			expect(service._playerState[player].lantern).to.equal("S3a")
			expect(service._emissionState[player].sprint.t_0).to.equal(nil)
			expect(service._emissionState[player].light.t_0).to.equal(nil)

			-- (d): grace anchors reset to nil.
			expect(service._emissionState[player].sprint.t_lastGracePulse).to.equal(nil)
			expect(service._emissionState[player].light.t_lastGracePulse).to.equal(nil)

			-- (e)/(f): server-observable proxies fire despite no live pointer.
			expect(service._deathEffectsState[player].spectatorCameraActive).to.equal(true)
			expect(service._deathEffectsState[player].inputLocked).to.equal(true)

			-- (c): stamina-frozen proxy -- the player is flagged dead (deathStartedAt
			-- set), so the real Heartbeat dead-skip (`_isPlayerDead`) would freeze
			-- their stamina -- despite no live pointer.
			expect(service:_isPlayerDead(player)).to.equal(true)
		end)

		it("test_h75_paired_reconciliation_with_live_pointer_runs_only_a_b_g_and_retains_row", function()
			local service, player = newServiceWithPlayer(2)

			local outage = true
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				if outage then
					error("simulated RM outage")
				end
				return true
			end

			local broadcastCalls: { { userId: number, deathCause: string } } = {}
			service._broadcastPlayerDiedFn = function(userId: number, deathCause: string)
				table.insert(broadcastCalls, { userId = userId, deathCause = deathCause })
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })
			-- Initial dispatch failed -- no commit yet, no broadcast yet.
			expect(#broadcastCalls).to.equal(0)
			local deathEventId = service._deathReconciliationState.currentDeathRecord[player]
			expect(deathEventId).never.to.equal(nil)

			outage = false
			service:_setNow(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)
			service:_runReconciliationTick(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)

			expect(#broadcastCalls).to.equal(1)
			expect(broadcastCalls[1].deathCause).to.equal(SideEffectsLogic.DEATH_CAUSE_RECONCILIATION_RECOVERY)

			-- Row retained -- the live pointer still points at it (player never
			-- respawned).
			expect(service._deathReconciliationState.reconcileRows[deathEventId]).never.to.equal(nil)
			expect(service._deathReconciliationState.currentDeathRecord[player]).to.equal(deathEventId)

			-- Forbidden set never fired ((c)-(f) proxies never set).
			expect(service._deathEffectsState[player]).to.equal(nil)
		end)
	end)

	-- ============================================================================
	-- H.70 -- reconciliation forbidden set, live-pointer AND orphaned variants.
	-- ============================================================================
	describe("Story 005 -- H.70 (reconciliation forbidden set -- live-pointer AND orphaned variants)", function()
		local function buildForbiddenSetTracker(service: any)
			local counts = {
				s4Entered = 0,
				aliveTrue = 0,
				aliveFalse = 0,
				releaseLock = 0,
				broadcast = 0,
			}
			service._onPlayerS4EnteredFn = function(_userId: number)
				counts.s4Entered += 1
			end
			service._onSquadMemberAliveChangedFn = function(_userId: number, isAlive: boolean)
				if isAlive then
					counts.aliveTrue += 1
				else
					counts.aliveFalse += 1
				end
			end
			service._releasePredatorLockFn = function(_userId: number)
				counts.releaseLock += 1
			end
			service._broadcastPlayerDiedFn = function(_userId: number, _deathCause: string)
				counts.broadcast += 1
			end
			return counts
		end

		it("test_h70_live_pointer_reconciliation_only_a_b_g", function()
			local service, player = newServiceWithPlayer(1)
			local counts = buildForbiddenSetTracker(service)

			local outage = true
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				if outage then
					error("simulated RM outage")
				end
				return true
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })
			expect(counts.releaseLock).to.equal(1) -- pre-yield, initial
			expect(counts.aliveFalse).to.equal(1) -- pre-yield, initial
			expect(counts.s4Entered).to.equal(1) -- pre-yield, initial (Path A)
			expect(counts.broadcast).to.equal(0) -- initial dispatch failed, no commit yet

			-- Grace-anchor sentinel (code-review fix): the initial dispatch failed
			-- BEFORE reaching the post-commit block, so (d) never ran -- seed a
			-- non-nil sentinel here so the "resetGraceAnchors is suppressed on a
			-- reconciliation dispatch" claim below is actually falsifiable (a field
			-- that starts nil and stays nil proves nothing).
			service._emissionState[player].sprint.t_lastGracePulse = 999.0
			service._emissionState[player].light.t_lastGracePulse = 999.0

			outage = false
			service:_setNow(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)
			service:_runReconciliationTick(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)

			-- (g) re-fired post-commit (idempotent in production) -- (h)/(i) NOT re-fired.
			expect(counts.releaseLock).to.equal(2)
			expect(counts.s4Entered).to.equal(1)
			expect(counts.aliveFalse).to.equal(1)
			expect(counts.aliveTrue).to.equal(0)
			-- The reconciliation-recovery broadcast DOES fire (it is orthogonal to the
			-- (c)-(f) forbidden set -- see H.75's paired test / the GDD's own HUD
			-- forward-obligation text).
			expect(counts.broadcast).to.equal(1)

			-- (c)-(f) proxies never set.
			expect(service._deathEffectsState[player]).to.equal(nil)

			-- (d) never re-fired: the sentinel is UNCHANGED (still 999.0, not nil).
			expect(service._emissionState[player].sprint.t_lastGracePulse).to.equal(999.0)
			expect(service._emissionState[player].light.t_lastGracePulse).to.equal(999.0)
		end)

		it("test_h70_orphaned_reconciliation_only_a_b_g_row_removed_immediately", function()
			local service, player = newServiceWithPlayer(2)
			local counts = buildForbiddenSetTracker(service)

			-- Put the player in S2 (sprinting) BEFORE death -- the initial dispatch
			-- (below) fails before ever reaching `_applyPostCommitDeathSideEffects`, so
			-- this locomotion state is untouched at T5 too. This makes the
			-- `isSameLife`/`touchLiveState` gate assertion below MEANINGFUL: if the
			-- gate incorrectly let the orphaned reconciliation's (a) touch this table,
			-- `ForceRevertToS1` would actually flip `locomotion` to "S1" and clear
			-- `sprintPulseAnchorAt` -- a real, observable mutation, not a vacuous
			-- "nil stays nil" check.
			local locState = service._locomotionState[player]
			LocomotionStaminaLogic.HandleSprintToggleDomain(locState, true, 0.0)
			expect(locState.locomotion).to.equal("S2")

			local outage = true
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				if outage then
					error("simulated RM outage")
				end
				return true
			end

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })
			local deathEventId = service._deathReconciliationState.currentDeathRecord[player]
			-- Confirms the initial dispatch really did fail before touching locomotion
			-- (arrange-step sanity check, not the assertion under test).
			expect(locState.locomotion).to.equal("S2")

			-- Grace-anchor sentinel (code-review fix -- same rationale as the
			-- live-pointer variant above): falsifiable proof that (d) does not re-fire.
			service._emissionState[player].sprint.t_lastGracePulse = 999.0
			service._emissionState[player].light.t_lastGracePulse = 999.0

			-- `isSameLife`/`touchLiveState` sentinel (code-review fix -- replaces a
			-- comment that previously CLAIMED an object-identity assertion without one
			-- actually existing in this test body): capture the EXACT
			-- `PlayerLocomotionState` object reference this player is currently
			-- registered under, and stamp a sentinel field onto it. If the orphaned
			-- reconciliation's (a)/(b) incorrectly touched this player's CURRENT
			-- per-player state (the exact bug the `isSameLife` gate in
			-- `_applyPostCommitDeathSideEffects` exists to prevent), either (i) a NEW
			-- table would replace this reference (identity check fails), or (ii) the
			-- sentinel field would be clobbered by `ForceRevertToS1`'s real field
			-- writes (sentinel-survival check fails), or (iii) `locomotion` would flip
			-- to "S1" (the real, observable mutation check).
			local locStateBeforeTick = service._locomotionState[player]
			local locStateBeforeTickAny = locStateBeforeTick :: any
			locStateBeforeTickAny.__testSentinel = "untouched"

			-- Simulate the live pointer becoming detached BEFORE the reconciliation tick
			-- recovers (pc-4's own H.39 orphan scenario) -- WITHOUT touching the row
			-- itself or removing the player from the Fake's userId registry (mirrors a
			-- still-connected-but-pointer-detached production case, e.g. life 2).
			service._deathReconciliationState.currentDeathRecord[player] = nil

			outage = false
			service:_setNow(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)
			service:_runReconciliationTick(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)

			expect(counts.releaseLock).to.equal(2) -- pre-yield initial + post-commit reconciliation
			expect(counts.s4Entered).to.equal(1)
			expect(counts.aliveFalse).to.equal(1)
			expect(counts.aliveTrue).to.equal(0)
			expect(counts.broadcast).to.equal(1)

			-- H.39 (pc-4): an orphaned reconciliation commit removes the row immediately.
			expect(service._deathReconciliationState.reconcileRows[deathEventId]).to.equal(nil)

			-- (c)-(f) proxies never set.
			expect(service._deathEffectsState[player]).to.equal(nil)

			-- (d) never re-fired (falsifiable sentinel, matches the live-pointer variant).
			expect(service._emissionState[player].sprint.t_lastGracePulse).to.equal(999.0)
			expect(service._emissionState[player].light.t_lastGracePulse).to.equal(999.0)

			-- `isSameLife`/`touchLiveState` gate actually exercised: this player's
			-- CURRENT `_locomotionState` entry is still the EXACT SAME object (identity,
			-- not just equal fields), the sentinel survived untouched, AND `locomotion`
			-- is STILL "S2" (never flipped to "S1") -- proving (a)/(b) did NOT touch it
			-- (the orphaned reconciliation success never called `ForceRevertToS1` /
			-- mutated this table at all).
			expect(service._locomotionState[player]).to.equal(locStateBeforeTick)
			expect((service._locomotionState[player] :: any).__testSentinel).to.equal("untouched")
			expect(service._locomotionState[player].locomotion).to.equal("S2")
		end)
	end)

	-- ============================================================================
	-- H.32 -- TR-pc-032 sprint hard-reset (T5) + fresh-life reset (T6).
	-- ============================================================================
	describe("Story 005 -- H.32 (TR-pc-032 sprint hard-reset + T6 fresh-life reset)", function()
		it("test_h32_t5_forces_s1_s3a_stops_pulses_stamina_frozen_via_heartbeat_skip", function()
			local service, player = newServiceWithPlayer(1)
			local locState = service._locomotionState[player]
			LocomotionStaminaLogic.HandleSprintToggleDomain(locState, true, 0.0)
			service._playerState[player].locomotion = "S2"
			service._playerState[player].lantern = "S3b"
			EmissionPublisherLogic.OnAxisEntered(service._emissionState[player].sprint, Vector3.new(0, 0, 0), 0.0)
			EmissionPublisherLogic.OnAxisEntered(service._emissionState[player].light, Vector3.new(0, 0, 0), 0.0)
			locState.stamina = 37.5

			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })

			expect(locState.locomotion).to.equal("S1")
			expect(service._playerState[player].lantern).to.equal("S3a")
			expect(service._emissionState[player].sprint.t_0).to.equal(nil)
			expect(service._emissionState[player].light.t_0).to.equal(nil)

			-- (c): stamina frozen -- enforced (in production) by the Heartbeat dead-skip
			-- (`_isPlayerDead`); proven here by asserting the value is untouched at
			-- exactly its pre-death snapshot, and that the player is now flagged dead so
			-- the real Heartbeat loop WOULD skip them.
			expect(locState.stamina).to.equal(37.5)
			expect(service:_isPlayerDead(player)).to.equal(true)
		end)

		it("test_h32_t6_respawns_s1_full_stamina_lantern_lowered", function()
			local service, player = newServiceWithPlayer(2)
			service:_onPlayerDied({ deadPlayer = player, deathTimestamp = 0.0, predatorWasLockedAtDeath = false })

			service:_setNow(ReconLogic.RESPAWN_DELAY)
			service:_checkRespawnTimers(ReconLogic.RESPAWN_DELAY)

			local locState = service._locomotionState[player]
			expect(locState.locomotion).to.equal("S1")
			expect(locState.stamina).to.equal(LocomotionStaminaLogic.STAMINA_MAX)
			expect(service._playerState[player].lantern).to.equal("S3a")
			expect(service:_isPlayerDead(player)).to.equal(false)
		end)
	end)

	-- ============================================================================
	-- Static/structural source-text checks against the real PlayerControllerService
	-- .luau -- mirrors death-cost-reconciliation-core_test.luau's own established
	-- pattern.
	-- ============================================================================
	describe("PlayerControllerService.luau -- Story 005 (wiring, static/structural checks)", function()
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

		it("test_onplayerdied_signal_declared_on_client_table", function()
			local source = loadRawSource()
			expect(source:find("OnPlayerDied = Knit%.CreateSignal%(%)")).never.to.equal(nil)
		end)

		it("test_preyield_hook_call_passes_dispatch_origin_and_path_origin", function()
			local source = loadStrippedSource()
			expect(source:find("self%._preYieldDeathSideEffectsFn%(row, dispatchOrigin, pathOrigin%)")).never.to.equal(nil)
		end)

		it("test_postcommit_hook_call_passes_dispatch_origin_player_and_path_origin", function()
			local source = loadStrippedSource()
			expect(source:find("self%._onDeathCommitFn%(row, dispatchOrigin, player, pathOrigin%)")).never.to.equal(nil)
		end)

		it("test_reconciliation_tick_dispatches_with_reconciliation_origin", function()
			local source = loadStrippedSource()
			expect(source:find('self:_beginAndDispatch%(row, now, "reconciliation", player, nil%)')).never.to.equal(nil)
		end)

		it("test_check_respawn_timers_calls_complete_respawn", function()
			local source = loadStrippedSource()
			expect(source:find("self:_completeRespawn%(player, now%)")).never.to.equal(nil)
		end)

		-- Code-review fix pin: `_completeRespawn`'s live-Character-touching remainder
		-- is `task.spawn`'d (isolates `LoadCharacter`'s yield/error risk per player,
		-- off the Heartbeat handler), and INSIDE that spawned body the alive=true edge
		-- textually follows the respawn-placement call and sits inside an `if hrp`
		-- gate (H.72's ordering contract, pinned at the source level).
		it("test_complete_respawn_spawns_the_live_character_touching_remainder", function()
			local source = loadStrippedSource()
			local completeRespawnPos = source:find("function PlayerControllerService:_completeRespawn%(")
			expect(completeRespawnPos).never.to.equal(nil)

			local spawnPos = source:find("task%.spawn%(function%(%)", completeRespawnPos)
			expect(spawnPos).never.to.equal(nil)

			local placementPos = source:find("self%._respawnPlayerAtAnchorFn%(player, anchorPosition%)", spawnPos)
			expect(placementPos).never.to.equal(nil)

			local ifHrpPos = source:find("if hrp then", placementPos)
			expect(ifHrpPos).never.to.equal(nil)

			local aliveTruePos = source:find('self%._onSquadMemberAliveChangedFn%(player%.UserId, true%)', ifHrpPos)
			expect(aliveTruePos).never.to.equal(nil)

			-- Full ordering chain: _completeRespawn < task.spawn < placement < if hrp
			-- < alive=true.
			expect((completeRespawnPos :: number) < (spawnPos :: number)).to.equal(true)
			expect((spawnPos :: number) < (placementPos :: number)).to.equal(true)
			expect((placementPos :: number) < (ifHrpPos :: number)).to.equal(true)
			expect((ifHrpPos :: number) < (aliveTruePos :: number)).to.equal(true)
		end)

		-- Code-review fix pin: the LoadCharacter yield/error risk is pcall-guarded in
		-- the default respawn-placement seam.
		it("test_default_respawn_player_at_anchor_wraps_loadcharacter_in_pcall", function()
			local source = loadStrippedSource()
			local defaultPos = source:find("function PlayerControllerService:_defaultRespawnPlayerAtAnchor%(")
			expect(defaultPos).never.to.equal(nil)
			local pcallPos = source:find("pcall%(function%(%)", defaultPos)
			expect(pcallPos).never.to.equal(nil)
			local loadCharPos = source:find("player:LoadCharacter%(%)", pcallPos)
			expect(loadCharPos).never.to.equal(nil)
		end)

		-- Code-review fix pin: `Players.PlayerRemoving` clears BOTH Story 005 tables.
		it("test_player_removing_clears_death_effects_state_and_last_tracked_position", function()
			local source = loadStrippedSource()
			local removingPos = source:find("Players%.PlayerRemoving:Connect%(function%(player: Player%)")
			expect(removingPos).never.to.equal(nil)

			local requestLanternPos = source:find("self%.Client%.RequestLanternToggle:Connect%(", removingPos)
			expect(requestLanternPos).never.to.equal(nil)

			local deathEffectsClearPos = source:find("self%._deathEffectsState%[player%] = nil", removingPos)
			local lastPositionClearPos = source:find("self%._lastServerTrackedPosition%[player%] = nil", removingPos)
			expect(deathEffectsClearPos).never.to.equal(nil)
			expect(lastPositionClearPos).never.to.equal(nil)

			-- Both clears are WITHIN the PlayerRemoving handler body (before the next
			-- connection is registered), not some unrelated later occurrence.
			expect((deathEffectsClearPos :: number) < (requestLanternPos :: number)).to.equal(true)
			expect((lastPositionClearPos :: number) < (requestLanternPos :: number)).to.equal(true)
		end)

		it("test_begin_death_flow_requires_path_origin_and_path_b_seam_exists", function()
			local source = loadStrippedSource()
			-- The Path-A/B discriminator seam entry point Story 006 is expected to call.
			expect(source:find('function PlayerControllerService:_beginDeathFlow%(player: Player, now: number, pathOrigin: PathOrigin%)')).never.to.equal(nil)
			expect(source:find('self:_beginDeathFlow%(payload%.deadPlayer, now, "A"%)')).never.to.equal(nil)
		end)

		it("test_only_one_inline_get_server_time_now_call_the_seam_itself", function()
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
		end)

		it("test_no_direct_humanoid_died_connect_in_this_file", function()
			local source = loadStrippedSource()
			local matchStart = source:find(".Died:Connect(", 1, true)
			expect(matchStart).to.equal(nil)
		end)

		it("test_no_forbidden_deprecated_scheduling_primitives_in_story_005_section", function()
			local raw = loadRawSource()
			local sectionStart = raw:find("Story 005 %-%- Death/Respawn Side%-Effects & Cross%-Service Signals %(T5/T6%)%. All")
			expect(sectionStart).never.to.equal(nil)
			local rawSection = raw:sub(sectionStart :: number)
			local strippedSection = stripLuaComments(rawSection)

			expect(strippedSection:find("%f[%a]wait%(")).to.equal(nil)
			expect(strippedSection:find("%f[%a]delay%(")).to.equal(nil)
			expect(strippedSection:find("task%.delay")).to.equal(nil)
		end)

		it("test_predator_and_crafting_stub_flags_are_per_instance_not_class_table", function()
			local source = loadRawSource()
			-- No class-table flag anywhere in the file (the TD-013/Story-004-established
			-- forbidden static-singleton shape).
			expect(source:find("PlayerControllerService%._hasWarnedMissingPredatorService")).to.equal(nil)
			expect(source:find("PlayerControllerService%._hasWarnedMissingCraftingService")).to.equal(nil)
			expect(source:find("PlayerControllerService%._hasWarnedMissingRespawnAnchor")).to.equal(nil)

			local knitInitPos = source:find("function PlayerControllerService:KnitInit%(%)")
			local knitStartPos = source:find("function PlayerControllerService:KnitStart%(%)")
			expect(knitInitPos).never.to.equal(nil)
			expect(knitStartPos).never.to.equal(nil)

			local predatorFlagPos = source:find("self%._hasWarnedMissingPredatorService = false", knitInitPos)
			local craftingFlagPos = source:find("self%._hasWarnedMissingCraftingService = false", knitInitPos)
			expect(predatorFlagPos).never.to.equal(nil)
			expect(craftingFlagPos).never.to.equal(nil)
			expect((predatorFlagPos :: number) < (knitStartPos :: number)).to.equal(true)
			expect((craftingFlagPos :: number) < (knitStartPos :: number)).to.equal(true)
		end)

		it("test_isplayerdead_used_by_both_locomotion_and_emission_heartbeat_loops", function()
			local source = loadStrippedSource()
			local locomotionPos = source:find("function PlayerControllerService:_onLocomotionHeartbeat%(")
			local emissionPos = source:find("function PlayerControllerService:_onEmissionHeartbeat%(")
			expect(locomotionPos).never.to.equal(nil)
			expect(emissionPos).never.to.equal(nil)

			local locomotionGuardPos = source:find("self:_isPlayerDead%(player%)", locomotionPos)
			expect(locomotionGuardPos).never.to.equal(nil)
			expect((locomotionGuardPos :: number) < (emissionPos :: number)).to.equal(true)

			local emissionGuardPos = source:find("self:_isPlayerDead%(player%)", emissionPos)
			expect(emissionGuardPos).never.to.equal(nil)
		end)
	end)
end
