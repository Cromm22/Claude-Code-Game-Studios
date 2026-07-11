--!strict
-- path-b-oxygen-grace-timer_test
--
-- Unit tests for Story 006: Path B Disconnect Predicate, Oxygen Grace Timer &
-- Oxygen-Gated Respawn Wait.
-- Story: production/epics/player-controller/story-006-path-b-oxygen-grace-timer.md
-- ADR: docs/architecture/adr-0005-death-respawn-lifecycle.md (THE LAW -- C4 restated:
--      OXYGEN_GRACE_DURATION=5s, PC-owned, squad-wide, 4-8s safe range, 2.0s hard
--      floor R7c-I4; the KnitInit-hard-error + bootstrap game:Shutdown() pairing
--      requirement)
--
-- Production code under test:
--   src/gameplay/services/PlayerControllerPathBGraceLogic.luau -- the REAL, pure,
--     zero-require predicate/timer/config-gate/peek module, exercised DIRECTLY
--     (first section below).
--   src/gameplay/services/PlayerControllerService.luau -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live PlayerControllerService
--     instance cannot be constructed here (same precedent every prior PC test in this
--     repo documents). Verified two ways instead:
--       (a) FakePlayerControllerService below mirrors the real Knit wrapper's Story
--           004/005/006 method bodies method-for-method (same established precedent as
--           death-cost-reconciliation-core_test.luau / death-respawn-side-effects_test
--           .luau), substituting an injectable `_now` for the real `getServerTime()`
--           seam, calling `_completeDispatch` SYNCHRONOUSLY where the real wrapper
--           `task.spawn`s it, and a Fake-local `_simulatePlayerRemoving(player)`
--           method standing in for the real `Players.PlayerRemoving:Connect(...)`
--           closure body (this harness has no live `Players` service to fire a real
--           `PlayerRemoving` event from).
--       (b) static/structural source-text checks against the real
--           PlayerControllerService.luau AND src/core/ServerBootstrap.luau /
--           src/core/ServerInit.server.luau (mirrors death-cost-reconciliation-core_test
--           .luau's own established pattern, including its documented stripLuaComments
--           `--`-in-string caveat).
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must
-- pass (BLOCKING gate).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local PathBGraceLogic = require(ServerScriptService.gameplay.services.PlayerControllerPathBGraceLogic)
local ReconLogic = require(ServerScriptService.gameplay.services.PlayerControllerDeathReconciliationLogic)
local SideEffectsLogic = require(ServerScriptService.gameplay.services.PlayerControllerDeathSideEffectsLogic)
local LocomotionStaminaLogic = require(ServerScriptService.gameplay.services.PlayerControllerLocomotionStaminaLogic)
local LanternLogic = require(ServerScriptService.gameplay.services.PlayerControllerLanternLogic)
local EmissionPublisherLogic = require(ServerScriptService.gameplay.services.PlayerControllerEmissionPublisherLogic)

type ReconcileRow = ReconLogic.ReconcileRow

-- ============================================================================
-- FakePlayerControllerService -- see header note (a) above. Mirrors the REAL Knit
-- wrapper's Story 004/005/006 method bodies exactly (pc-4/pc-5's own established
-- Fake-harness precedent, extended with this story's Path-B/grace-timer/respawn-wait
-- additions).
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

	self._oxygenGraceState = PathBGraceLogic.NewGraceState()

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

	-- Story 006 cross-epic read/pool seams -- default to the SAME safe defaults the
	-- real service's own `_default*` stub methods use (nil/false for PredatorService
	-- reads; a large sentinel for the pool read so an unconfigured test never
	-- spuriously fires a grace-expiry death).
	self._getLastPredatorDamageTimestampFn = function(_userId: number): number?
		return nil
	end
	self._getPredatorCausedImminentFn = function(_userId: number): boolean
		return false
	end
	self._getPredatorCausedImminentSetTimestampFn = function(_userId: number): number?
		return nil
	end
	self._getSquadOxygenPoolFn = function(): number
		return math.huge
	end

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

--- Fake-local stand-in for `Players:GetPlayers()` (this harness has no live
--- `Players` service list) -- iterates the Fake's own registry, matching
--- death-respawn-side-effects_test.luau's own `_playersByUserId` precedent.
function FakePlayerControllerService:_getConnectedPlayers(): { any }
	local list: { any } = {}
	for _, player in self._playersByUserId do
		table.insert(list, player)
	end
	return list
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

	-- HARNESS DISCLOSURE (matches pc-4/pc-5's own established precedent): real
	-- production `task.spawn`s this; called synchronously here for deterministic
	-- single-threaded test execution.
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
		local player = self._playersByUserId[row.userId]
		self:_beginAndDispatch(row, now, "reconciliation", player, nil)
	end
end

--- Story 006 (H.65): mirrors the real `_checkRespawnTimers` extension exactly --
--- the oxygen-gated respawn wait, gated by the non-mutating
--- `PathBGraceLogic.HasRespawnTimerElapsed` peek + `_isRespawnOxygenGated` BEFORE
--- ever calling the real, mutating `ReconLogic.TryRespawn`.
function FakePlayerControllerService:_checkRespawnTimers(now: number): ()
	local reconState = self._deathReconciliationState
	local trackedPlayers: { any } = {}
	for player in reconState.deathStartedAt do
		table.insert(trackedPlayers, player)
	end
	for _, player in trackedPlayers do
		local startedAt = reconState.deathStartedAt[player]
		if not PathBGraceLogic.HasRespawnTimerElapsed(startedAt, now, ReconLogic.RESPAWN_DELAY) then
			continue
		end
		if self:_isRespawnOxygenGated(player) then
			continue
		end
		local respawned = ReconLogic.TryRespawn(reconState, player, now, ReconLogic.RESPAWN_DELAY)
		if respawned then
			self:_completeRespawn(player, now)
		end
	end
end

function FakePlayerControllerService:_isRespawnOxygenGated(player: any): boolean
	local poolNow = self._getSquadOxygenPoolFn()
	if poolNow >= 1 then
		return false
	end
	for _, other in self:_getConnectedPlayers() do
		if other ~= player and not self:_isPlayerDead(other) then
			return true
		end
	end
	return false
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

-- ============================================================================
-- Story 006 -- the grace-timer's own Heartbeat check (mirrors the real
-- `_checkOxygenGraceTimer` exactly).
-- ============================================================================

function FakePlayerControllerService:OnOxygenExpired(): ()
	local now = self._now
	PathBGraceLogic.StartOrRestartGraceTimer(self._oxygenGraceState, now, PathBGraceLogic.OXYGEN_GRACE_DURATION)
end

function FakePlayerControllerService:_checkOxygenGraceTimer(now: number): ()
	local graceState = self._oxygenGraceState
	if not PathBGraceLogic.IsGraceTimerActive(graceState) then
		return
	end

	local poolNow = self._getSquadOxygenPoolFn()

	if poolNow >= 1 then
		PathBGraceLogic.CancelGraceTimer(graceState)
		return
	end

	if not PathBGraceLogic.HasGraceTimerExpired(graceState, now) then
		return
	end

	PathBGraceLogic.CancelGraceTimer(graceState)

	for _, player in self:_getConnectedPlayers() do
		if not self:_isPlayerDead(player) then
			self:_beginDeathFlow(player, now, "A")
		end
	end
end

-- ============================================================================
-- Story 006 -- Path B: the real `Players.PlayerRemoving` handler body, mirrored
-- method-for-method (see PlayerControllerService.luau's own KnitStart wiring).
-- ============================================================================

function FakePlayerControllerService:_simulatePlayerRemoving(player: any): ()
	-- FIRST STATEMENT BLOCK -- see the real service's own doc comment.
	local cachedNow = self._now
	local cachedDamageTs = self._getLastPredatorDamageTimestampFn(player.UserId)
	local cachedPredatorCausedImminent = self._getPredatorCausedImminentFn(player.UserId)
	local cachedLatchSetTs = self._getPredatorCausedImminentSetTimestampFn(player.UserId)
	local cachedPlayerName = player.Name
	local cachedHealth: number? = player.Health -- Fake players carry a plain `Health` field (see harness helper below)

	local imminent = PathBGraceLogic.IsImminentDeath(
		cachedHealth,
		cachedDamageTs,
		cachedPredatorCausedImminent,
		cachedLatchSetTs,
		cachedNow
	)
	if imminent then
		self:_beginDeathFlow(player, cachedNow, "B")
	end
	local _ = cachedPlayerName -- read-and-cache set; used for parity with the real handler's synchronous warn, not asserted here

	local reconState = self._deathReconciliationState
	local departingDeathEventId = reconState.currentDeathRecord[player]
	if departingDeathEventId then
		local departingRow = reconState.reconcileRows[departingDeathEventId]
		if departingRow and departingRow.state == "Committed" then
			reconState.reconcileRows[departingDeathEventId] = nil
		end
	end
	reconState.currentDeathRecord[player] = nil
	reconState.deathInProgress[player] = nil
	reconState.deathStartedAt[player] = nil

	self._locomotionState[player] = nil
	self._playerState[player] = nil
	self._emissionState[player] = nil
	self._deathEffectsState[player] = nil
	self._lastServerTrackedPosition[player] = nil
	self._playersByUserId[player.UserId] = nil
end

local function newServiceWithPlayer(userId: number, health: number?)
	local service = FakePlayerControllerService.new()
	service:KnitInit()
	service:_setNow(0.0)
	service:KnitStart()
	local player = { UserId = userId, Name = "Player" .. tostring(userId), Health = health }
	service:_registerPlayer(player)
	return service, player
end

return function()
	-- ============================================================================
	-- Pure module: PlayerControllerPathBGraceLogic -- direct, exhaustive unit
	-- coverage of the predicate/config-gate/timer/peek math every AC below
	-- ultimately depends on.
	-- ============================================================================

	describe("PlayerControllerPathBGraceLogic -- IsImminentDeath (H.22b/c/d -- arm isolation)", function()
		it("test_h22b_arm1_only_fires_low_hp_recent_predator_damage", function()
			-- Health=20 (<25), lastPredatorDamageTimestamp = now-5 (elapsed 5 < 30
			-- HP_ARM_RECENT_WINDOW, carries arm1; 5 is NOT < 3 DAMAGE_RECENT_WINDOW,
			-- so arm2 does NOT carry -- isolates arm1).
			local now = 100.0
			local result = PathBGraceLogic.IsImminentDeath(20, now - 5, false, nil, now)
			expect(result).to.equal(true)
		end)

		it("test_h22c_full_health_no_damage_timestamp_never_fires", function()
			local now = 100.0
			local result = PathBGraceLogic.IsImminentDeath(100, nil, false, nil, now)
			expect(result).to.equal(false)
		end)

		it("test_h22d_arm2_only_fires_full_health_very_recent_damage", function()
			-- Full health (arm1's health check fails regardless of window), elapsed
			-- 1.5s < 3.0 DAMAGE_RECENT_WINDOW -- isolates arm2.
			local now = 100.0
			local result = PathBGraceLogic.IsImminentDeath(100, now - 1.5, false, nil, now)
			expect(result).to.equal(true)
		end)

		it("test_nil_health_never_satisfies_arm1_or_arm3_but_arm2_still_can", function()
			-- Already-destroyed-character case: cachedHealth nil -- arms 1/3 can't
			-- fire (nil-safe), arm2 (health-independent) still can.
			local now = 100.0
			expect(PathBGraceLogic.IsImminentDeath(nil, now - 1.0, true, now - 1.0, now)).to.equal(true) -- arm2 carries
			expect(PathBGraceLogic.IsImminentDeath(nil, nil, true, now - 1.0, now)).to.equal(false) -- nothing can fire
		end)

		it("test_each_arm_independently_exercisable_in_isolation", function()
			local now = 100.0
			-- Arm1 alone.
			expect(PathBGraceLogic.IsImminentDeath(20, now - 10, false, nil, now)).to.equal(true)
			-- Arm2 alone.
			expect(PathBGraceLogic.IsImminentDeath(100, now - 1.0, false, nil, now)).to.equal(true)
			-- Arm3 alone (health low, latch true+recent, damage ts nil so arms 1/2 can't fire).
			expect(PathBGraceLogic.IsImminentDeath(18, nil, true, now - 45, now)).to.equal(true)
		end)
	end)

	describe("PlayerControllerPathBGraceLogic -- H.43 (exact-boundary rejection, paired off-boundary)", function()
		it("test_h43_health_exact_threshold_does_not_satisfy_arm1", function()
			local now = 100.0
			-- Health=25.0 exactly, recent damage ts (would otherwise carry arm1).
			expect(PathBGraceLogic.IsImminentDeath(25.0, now - 5, false, nil, now)).to.equal(false)
		end)

		it("test_h43_health_just_under_threshold_satisfies_arm1", function()
			local now = 100.0
			expect(PathBGraceLogic.IsImminentDeath(24.99, now - 5, false, nil, now)).to.equal(true)
		end)

		it("test_h43_arm1_window_exact_30s_boundary_does_not_fire", function()
			local now = 100.0
			-- Health passes (24.99); elapsed EXACTLY 30.0s -- strict `<` rejects.
			expect(PathBGraceLogic.IsImminentDeath(24.99, now - 30.0, false, nil, now)).to.equal(false)
		end)

		it("test_h43_arm1_window_just_under_30s_fires", function()
			local now = 100.0
			expect(PathBGraceLogic.IsImminentDeath(24.99, now - 29.99, false, nil, now)).to.equal(true)
		end)

		it("test_h43_arm2_exact_3s_boundary_does_not_fire", function()
			local now = 100.0
			-- Full health (arm1/arm3 moot); elapsed EXACTLY 3.0s -- strict `<` rejects.
			expect(PathBGraceLogic.IsImminentDeath(100, now - 3.0, false, nil, now)).to.equal(false)
		end)

		it("test_h43_arm2_just_under_3s_fires", function()
			local now = 100.0
			expect(PathBGraceLogic.IsImminentDeath(100, now - 2.99, false, nil, now)).to.equal(true)
		end)

		it("test_h43_combined_exact_boundaries_all_arms_false", function()
			-- Literal AC reading: Health=25.0, elapsed=30.0s (shared timestamp -- also
			-- trivially fails arm2's OWN 3.0s window since 30 is not < 3),
			-- predatorCausedImminent=false. All three arms false.
			local now = 100.0
			expect(PathBGraceLogic.IsImminentDeath(25.0, now - 30.0, false, nil, now)).to.equal(false)
		end)
	end)

	describe("PlayerControllerPathBGraceLogic -- H.44 (arm 3 latch + outer ceiling)", function()
		it("test_h44_arm3_fires_health18_latch_true_45s_ago_outside_other_arms", function()
			local now = 100.0
			-- Health=18, predatorCausedImminent=true, latch set 45s ago (within
			-- LATCH_MAX_AGE=120), lastPredatorDamageTimestamp = now-45 (outside
			-- HP_ARM_RECENT_WINDOW=30 AND DAMAGE_RECENT_WINDOW=3 -- arms 1/2 cannot fire).
			expect(PathBGraceLogic.IsImminentDeath(18, now - 45, true, now - 45, now)).to.equal(true)
		end)

		it("test_h44_negative1_predatorCausedImminent_false_nothing_fires", function()
			local now = 100.0
			expect(PathBGraceLogic.IsImminentDeath(18, now - 45, false, now - 45, now)).to.equal(false)
		end)

		it("test_h44_negative2_outer_ceiling_150s_ago_arm3_does_not_fire", function()
			local now = 100.0
			-- latch set 150s ago (outside LATCH_MAX_AGE=120) -- arm3 does not fire.
			-- lastPredatorDamageTimestamp also stale (150s), so arms1/2 stay closed too.
			expect(PathBGraceLogic.IsImminentDeath(18, now - 150, true, now - 150, now)).to.equal(false)
		end)

		it("test_h44_exact_120s_boundary_does_not_fire_119_99_fires", function()
			local now = 100.0
			expect(PathBGraceLogic.IsImminentDeath(18, now - 200, true, now - 120.0, now)).to.equal(false)
			expect(PathBGraceLogic.IsImminentDeath(18, now - 200, true, now - 119.99, now)).to.equal(true)
		end)
	end)

	describe("PlayerControllerPathBGraceLogic -- ValidateConfig (H.12a clause, config gate)", function()
		it("test_config_gate_rejects_below_2s_hard_floor", function()
			local ok, err = PathBGraceLogic.ValidateConfig(1.5)
			expect(ok).to.equal(false)
			expect(err).never.to.equal(nil)
		end)

		it("test_config_gate_accepts_exactly_2s_hard_floor", function()
			local ok = PathBGraceLogic.ValidateConfig(2.0)
			expect(ok).to.equal(true)
		end)

		it("test_config_gate_accepts_default_5s", function()
			local ok = PathBGraceLogic.ValidateConfig(PathBGraceLogic.OXYGEN_GRACE_DURATION)
			expect(ok).to.equal(true)
		end)

		it("test_knitinit_throws_for_misconfigured_grace_duration_assert_via_pcall", function()
			-- Mirrors the KnitInit hard-error CALL SITE shape without constructing a
			-- real Knit service (this harness has no vendored Knit) -- proves the
			-- error() call itself fires for a misconfigured value, matching the real
			-- service's own KnitInit gate verbatim.
			local ok, err = pcall(function()
				local valid, validationErr = PathBGraceLogic.ValidateConfig(1.5)
				if not valid then
					error("PlayerControllerService config-validation FAILED: " .. tostring(validationErr))
				end
			end)
			expect(ok).to.equal(false)
			expect(tostring(err):find("config%-validation FAILED")).never.to.equal(nil)
		end)
	end)

	describe("PlayerControllerPathBGraceLogic -- ValidateLatchMaxAgeInvariant (H.12a clause (iii), GDD G.6 coupled-knob invariant)", function()
		it("test_defaults_pass_120_exceeds_30_plus_30", function()
			local ok, err = PathBGraceLogic.ValidateLatchMaxAgeInvariant(
				PathBGraceLogic.LATCH_MAX_AGE,
				PathBGraceLogic.HP_ARM_RECENT_WINDOW
			)
			expect(ok).to.equal(true)
			expect(err).to.equal(nil)
		end)

		it("test_margin_exactly_30_rejected_strict_greater_than", function()
			-- HP_ARM_RECENT_WINDOW=30, LATCH_MAX_AGE=60 -- margin is EXACTLY 30, which
			-- the invariant's strict `>` rejects (60 <= 30+30 = 60).
			local ok, err = PathBGraceLogic.ValidateLatchMaxAgeInvariant(60.0, 30.0)
			expect(ok).to.equal(false)
			expect(err).never.to.equal(nil)
		end)

		it("test_margin_just_over_30_accepted", function()
			-- 60.01 > 60 -- passes by the smallest possible margin.
			local ok = PathBGraceLogic.ValidateLatchMaxAgeInvariant(60.01, 30.0)
			expect(ok).to.equal(true)
		end)

		it("test_clear_violation_rejected", function()
			-- The GDD's own named degenerate corner: LATCH_MAX_AGE at its 60s range
			-- MINIMUM with HP_ARM_RECENT_WINDOW at its 60s range MAXIMUM -- margin is
			-- ZERO, deeply violating the invariant (reopens Scenario C).
			local ok, err = PathBGraceLogic.ValidateLatchMaxAgeInvariant(60.0, 60.0)
			expect(ok).to.equal(false)
			expect(err).never.to.equal(nil)
		end)

		it("test_hp_arm_recent_window_at_range_max_forces_latch_max_age_minimum", function()
			-- GDD G.6's own worked example, verbatim: "with HP_ARM_RECENT_WINDOW at
			-- its 60s max, any LATCH_MAX_AGE <= 90s is rejected."
			local hpArmRecentWindowAtRangeMax = 60.0
			local ok90, err90 = PathBGraceLogic.ValidateLatchMaxAgeInvariant(90.0, hpArmRecentWindowAtRangeMax)
			expect(ok90).to.equal(false)
			expect(err90).never.to.equal(nil)

			local ok90_01 = PathBGraceLogic.ValidateLatchMaxAgeInvariant(90.01, hpArmRecentWindowAtRangeMax)
			expect(ok90_01).to.equal(true)

			-- 180 (LATCH_MAX_AGE's own range max) comfortably clears the floor here.
			local ok180 = PathBGraceLogic.ValidateLatchMaxAgeInvariant(180.0, hpArmRecentWindowAtRangeMax)
			expect(ok180).to.equal(true)
		end)

		it("test_knitinit_throws_for_misconfigured_latch_invariant_assert_via_pcall", function()
			local ok, err = pcall(function()
				local valid, validationErr = PathBGraceLogic.ValidateLatchMaxAgeInvariant(60.0, 60.0)
				if not valid then
					error("PlayerControllerService config-validation FAILED: " .. tostring(validationErr))
				end
			end)
			expect(ok).to.equal(false)
			expect(tostring(err):find("config%-validation FAILED")).never.to.equal(nil)
		end)
	end)

	describe("PlayerControllerPathBGraceLogic -- grace timer state machine (C.5.1)", function()
		it("test_grace_timer_starts_inactive", function()
			local state = PathBGraceLogic.NewGraceState()
			expect(PathBGraceLogic.IsGraceTimerActive(state)).to.equal(false)
		end)

		it("test_grace_timer_start_then_expires_at_exact_duration_inclusive", function()
			local state = PathBGraceLogic.NewGraceState()
			PathBGraceLogic.StartOrRestartGraceTimer(state, 0.0, 5.0)
			expect(PathBGraceLogic.IsGraceTimerActive(state)).to.equal(true)
			expect(PathBGraceLogic.HasGraceTimerExpired(state, 4.99)).to.equal(false)
			expect(PathBGraceLogic.HasGraceTimerExpired(state, 5.0)).to.equal(true)
		end)

		it("test_grace_timer_cancel_clears_active_and_expiry", function()
			local state = PathBGraceLogic.NewGraceState()
			PathBGraceLogic.StartOrRestartGraceTimer(state, 0.0, 5.0)
			PathBGraceLogic.CancelGraceTimer(state)
			expect(PathBGraceLogic.IsGraceTimerActive(state)).to.equal(false)
			expect(PathBGraceLogic.HasGraceTimerExpired(state, 100.0)).to.equal(false)
		end)

		it("test_grace_timer_fresh_empty_entry_restarts_the_window", function()
			local state = PathBGraceLogic.NewGraceState()
			PathBGraceLogic.StartOrRestartGraceTimer(state, 0.0, 5.0)
			-- Restart at t=3 -- the window re-anchors from 3, not accumulating from 0.
			PathBGraceLogic.StartOrRestartGraceTimer(state, 3.0, 5.0)
			expect(PathBGraceLogic.HasGraceTimerExpired(state, 5.0)).to.equal(false) -- would have fired under the OLD anchor
			expect(PathBGraceLogic.HasGraceTimerExpired(state, 8.0)).to.equal(true)
		end)
	end)

	describe("PlayerControllerPathBGraceLogic -- HasRespawnTimerElapsed (H.65 peek)", function()
		it("test_nil_started_at_never_elapsed", function()
			expect(PathBGraceLogic.HasRespawnTimerElapsed(nil, 1000.0, 30.0)).to.equal(false)
		end)

		it("test_elapsed_inclusive_at_exact_boundary", function()
			expect(PathBGraceLogic.HasRespawnTimerElapsed(0.0, 29.99, 30.0)).to.equal(false)
			expect(PathBGraceLogic.HasRespawnTimerElapsed(0.0, 30.0, 30.0)).to.equal(true)
		end)
	end)

	-- ============================================================================
	-- Integration-shaped coverage via the Fake harness -- Path B dispatch (H.22b/c/d
	-- through the REAL reconciliation state machine), H.22f (fault injection),
	-- H.65 (oxygen-gated respawn wait), grace-timer expiry-fires-only-if-still-0
	-- (C.5.1), and TD-013 teardown semantics.
	-- ============================================================================

	describe("Story 006 -- Path B dispatch through the real reconciliation state machine (H.22b/c/d)", function()
		it("test_h22b_imminent_disconnect_commits_charges_oxygen_broadcasts", function()
			local service, player = newServiceWithPlayer(1, 20)
			service._getLastPredatorDamageTimestampFn = function(_userId: number): number?
				return 95.0 -- elapsed 5s at now=100
			end
			service:_setNow(100.0)

			local oxygenSpendCalls = 0
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				oxygenSpendCalls += 1
				return true
			end
			local broadcasts: { { userId: number, deathCause: string } } = {}
			service._broadcastPlayerDiedFn = function(userId: number, deathCause: string)
				table.insert(broadcasts, { userId = userId, deathCause = deathCause })
			end

			service:_simulatePlayerRemoving(player)

			expect(oxygenSpendCalls).to.equal(1)
			expect(#broadcasts).to.equal(1)
			expect(broadcasts[1].deathCause).to.equal(SideEffectsLogic.DEATH_CAUSE_PATH_B)

			-- The row committed (dispatch succeeded) -- but the pointer AND the
			-- Committed row are both cleared by the SAME teardown pass (TD-013's
			-- "if already Committed at teardown, retire immediately" rule) since the
			-- dispatch resolves synchronously in this Fake (see HARNESS DISCLOSURE).
			expect(service._deathReconciliationState.currentDeathRecord[player]).to.equal(nil)
		end)

		it("test_h22c_full_health_no_damage_ts_never_dispatches", function()
			local service, player = newServiceWithPlayer(2, 100)
			service:_setNow(100.0)

			local oxygenSpendCalls = 0
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				oxygenSpendCalls += 1
				return true
			end
			local broadcasts = 0
			service._broadcastPlayerDiedFn = function(_userId: number, _deathCause: string)
				broadcasts += 1
			end

			service:_simulatePlayerRemoving(player)

			expect(oxygenSpendCalls).to.equal(0)
			expect(broadcasts).to.equal(0)
			expect(service._deathReconciliationState.currentDeathRecord[player]).to.equal(nil) -- was never set
		end)

		it("test_h22d_arm2_only_full_health_very_recent_damage_dispatches", function()
			local service, player = newServiceWithPlayer(3, 100)
			service._getLastPredatorDamageTimestampFn = function(_userId: number): number?
				return 98.5 -- elapsed 1.5s at now=100
			end
			service:_setNow(100.0)

			local oxygenSpendCalls = 0
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				oxygenSpendCalls += 1
				return true
			end
			local broadcasts = 0
			service._broadcastPlayerDiedFn = function(_userId: number, _deathCause: string)
				broadcasts += 1
			end

			service:_simulatePlayerRemoving(player)

			expect(oxygenSpendCalls).to.equal(1)
			expect(broadcasts).to.equal(1)
		end)
	end)

	describe("Story 006 -- H.22f (fault-injected spend, Pending->InFlight->rollback, no crash, log never touches live instance)", function()
		it("test_h22f_fault_injection_rolls_back_no_crash_no_charge", function()
			local service, player = newServiceWithPlayer(4, 18)
			service._getLastPredatorDamageTimestampFn = function(_userId: number): number?
				return nil
			end
			service._getPredatorCausedImminentFn = function(_userId: number): boolean
				return true
			end
			service._getPredatorCausedImminentSetTimestampFn = function(_userId: number): number?
				return 55.0 -- elapsed 45s at now=100, within LATCH_MAX_AGE=120
			end
			service:_setNow(100.0)

			-- Poison the player's `Name` field so ANY dereference during the async
			-- failure-log path would raise -- proves the log path never touches the
			-- live instance (it logs via row.userId only). Cache reads in the FIRST
			-- statement block already captured `cachedPlayerName` BEFORE this poison
			-- would matter, but the assertion here is specifically about the
			-- FAILURE-LOG path inside `_completeDispatch`, which never reads
			-- `player.Name` at all.
			local poisoned = setmetatable({ UserId = player.UserId }, {
				__index = function(_, key)
					if key == "Name" then
						error("test poison: live Player.Name was dereferenced by the async failure-log path")
					end
					return nil
				end,
			})

			local chargeAttempts = 0
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				chargeAttempts += 1
				error("simulated RequestSquadOxygenSpend failure")
			end

			local ok = pcall(function()
				service:_beginDeathFlow(poisoned, 100.0, "B")
			end)
			expect(ok).to.equal(true) -- no crash surfaces to the caller

			expect(chargeAttempts).to.equal(1)

			local deathEventId = service._deathReconciliationState.currentDeathRecord[poisoned]
			expect(deathEventId).never.to.equal(nil)
			local row = service._deathReconciliationState.reconcileRows[deathEventId]
			expect(row.state).to.equal("Pending") -- rolled back InFlight -> Pending
			expect(row.inFlightSince).to.equal(nil)
		end)
	end)

	describe("Story 006 -- H.65 (oxygen-gated respawn wait)", function()
		it("test_h65_withheld_across_multiple_heartbeats_no_restart_no_recharge_then_respawns_first_heartbeat_pool_ge_1", function()
			local service, playerA = newServiceWithPlayer(10, 100)
			local _service2, playerB = nil, { UserId = 11, Name = "PlayerB", Health = 100 }
			service:_registerPlayer(playerB)

			-- Spend-call counter (code-review fix): the AC's "no additional oxygen
			-- charge" clause was previously proven only by code-path absence (no
			-- dispatch call site reachable while withheld). Counting actual
			-- `RequestSquadOxygenSpend` invocations makes it an explicit assertion:
			-- exactly 1 (the original death's charge) for the ENTIRE test, including
			-- every withheld Heartbeat AND the eventual successful respawn (T6 itself
			-- never charges oxygen -- the death already paid its unit at T5).
			local spendCalls = 0
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				spendCalls += 1
				return true
			end

			service:_setNow(0.0)
			service:_beginDeathFlow(playerA, 0.0, "A") -- A dies at t=0 -- the ONE legitimate charge
			expect(spendCalls).to.equal(1)

			local startedAt = service._deathReconciliationState.deathStartedAt[playerA]
			expect(startedAt).to.equal(0.0)

			local pool = 0
			service._getSquadOxygenPoolFn = function(): number
				return pool
			end

			local t6Calls = 0
			service._onPlayerT6RespawnedFn = function(_userId: number)
				t6Calls += 1
			end

			-- Respawn timer elapses at t=30 -- pool is 0, B (playerB) is alive -- WITHHELD.
			service:_setNow(30.0)
			service:_checkRespawnTimers(30.0)
			expect(t6Calls).to.equal(0)
			expect(service._deathReconciliationState.deathStartedAt[playerA]).to.equal(0.0) -- UNCHANGED -- no restart
			expect(spendCalls).to.equal(1) -- no additional charge

			-- Several more Heartbeats, still pool=0 -- still withheld, still no restart,
			-- no additional oxygen charge (no dispatch call at all on this path).
			for t = 31, 35 do
				service:_setNow(t)
				service:_checkRespawnTimers(t)
			end
			expect(t6Calls).to.equal(0)
			expect(service._deathReconciliationState.deathStartedAt[playerA]).to.equal(0.0)
			expect(spendCalls).to.equal(1) -- still exactly 1 across every withheld Heartbeat

			-- Pool restores to >= 1 -- respawns on the FIRST Heartbeat the pool reads >= 1.
			pool = 1
			service:_setNow(36.0)
			service:_checkRespawnTimers(36.0)
			expect(t6Calls).to.equal(1)
			expect(service._deathReconciliationState.deathStartedAt[playerA]).to.equal(nil)
			expect(spendCalls).to.equal(1) -- T6 itself never re-charges oxygen either
		end)

		it("test_h65_not_gated_when_pool_ge_1_at_elapse", function()
			local service, playerA = newServiceWithPlayer(20, 100)
			local playerB = { UserId = 21, Name = "PlayerB", Health = 100 }
			service:_registerPlayer(playerB)

			service:_setNow(0.0)
			service:_beginDeathFlow(playerA, 0.0, "A")

			service._getSquadOxygenPoolFn = function(): number
				return 3
			end
			local t6Calls = 0
			service._onPlayerT6RespawnedFn = function(_userId: number)
				t6Calls += 1
			end

			service:_setNow(30.0)
			service:_checkRespawnTimers(30.0)
			expect(t6Calls).to.equal(1)
		end)

		it("test_h65_not_gated_when_no_teammate_alive_solo_case", function()
			-- No OTHER connected player registered -- the gate only withholds "while a
			-- teammate is alive" (GDD E.E); with none, this gate does not withhold
			-- (Story 009's T7/wipe scope, not this gate's).
			local service, playerA = newServiceWithPlayer(30, 100)
			service:_setNow(0.0)
			service:_beginDeathFlow(playerA, 0.0, "A")

			service._getSquadOxygenPoolFn = function(): number
				return 0
			end
			local t6Calls = 0
			service._onPlayerT6RespawnedFn = function(_userId: number)
				t6Calls += 1
			end

			service:_setNow(30.0)
			service:_checkRespawnTimers(30.0)
			expect(t6Calls).to.equal(1)
		end)

		it("test_h65_not_gated_when_only_other_connected_player_is_also_dead", function()
			-- A teammate is CONNECTED but ALSO dead (both in S4) -- distinct from the
			-- solo/no-teammate case above. `_isRespawnOxygenGated` requires an OTHER
			-- player who is both connected AND alive to withhold; with the only other
			-- connected player also dead, this does not gate (same "no live teammate"
			-- rationale, exercised via a different code path than the solo case).
			local service, playerA = newServiceWithPlayer(31, 100)
			local playerB = { UserId = 32, Name = "PlayerB", Health = 100 }
			service:_registerPlayer(playerB)

			service:_setNow(0.0)
			service:_beginDeathFlow(playerA, 0.0, "A")
			service:_beginDeathFlow(playerB, 0.0, "A")
			expect(service:_isPlayerDead(playerB)).to.equal(true)

			service._getSquadOxygenPoolFn = function(): number
				return 0
			end

			expect(service:_isRespawnOxygenGated(playerA)).to.equal(false)
		end)
	end)

	describe("Story 006 -- grace timer (expiry-fires-only-if-still-0, mid-grace cancel, restart on fresh Empty)", function()
		it("test_grace_expiry_fires_t5_for_still_alive_players_only_if_pool_still_0", function()
			local service, playerA = newServiceWithPlayer(40, 100)
			local playerB = { UserId = 41, Name = "PlayerB", Health = 100 }
			service:_registerPlayer(playerB)

			local pool = 0
			service._getSquadOxygenPoolFn = function(): number
				return pool
			end

			service:_setNow(0.0)
			service:OnOxygenExpired() -- starts the 5s grace window

			local broadcasts = 0
			service._broadcastPlayerDiedFn = function(_userId: number, _deathCause: string)
				broadcasts += 1
			end

			-- Mid-window, before expiry -- no fire yet.
			service:_setNow(3.0)
			service:_checkOxygenGraceTimer(3.0)
			expect(broadcasts).to.equal(0)

			-- Expiry at t=5, pool still 0 -- fires T5 for BOTH still-alive players.
			service:_setNow(5.0)
			service:_checkOxygenGraceTimer(5.0)
			expect(broadcasts).to.equal(2)
			expect(service:_isPlayerDead(playerA)).to.equal(true)
			expect(service:_isPlayerDead(playerB)).to.equal(true)
		end)

		it("test_grace_mid_window_canister_restore_cancels_pending_deaths_and_timer", function()
			local service, playerA = newServiceWithPlayer(50, 100)

			local pool = 0
			service._getSquadOxygenPoolFn = function(): number
				return pool
			end

			service:_setNow(0.0)
			service:OnOxygenExpired()

			-- Restore mid-window.
			pool = 5
			service:_setNow(2.0)
			service:_checkOxygenGraceTimer(2.0)
			expect(PathBGraceLogic.IsGraceTimerActive(service._oxygenGraceState)).to.equal(false)

			-- Even past the ORIGINAL expiry time, no death fires (timer was cancelled,
			-- not merely paused) -- pool dropping back to 0 afterward does not resume
			-- a cancelled window; it would need a FRESH OnPlayerOxygenExpired() edge.
			pool = 0
			service:_setNow(10.0)
			service:_checkOxygenGraceTimer(10.0)
			expect(service:_isPlayerDead(playerA)).to.equal(false)
		end)

		it("test_grace_fresh_empty_entry_restarts_the_timer", function()
			local service, playerA = newServiceWithPlayer(60, 100)

			local pool = 0
			service._getSquadOxygenPoolFn = function(): number
				return pool
			end

			service:_setNow(0.0)
			service:OnOxygenExpired() -- window: [0, 5]

			service:_setNow(3.0)
			service:OnOxygenExpired() -- fresh Empty entry -- re-anchors to [3, 8], NOT [0,5]

			-- t=5 (would have fired under the OLD window) -- does NOT fire, since the
			-- window was restarted at t=3.
			service:_setNow(5.0)
			service:_checkOxygenGraceTimer(5.0)
			expect(service:_isPlayerDead(playerA)).to.equal(false)

			-- t=8 (elapsed exactly 5s from the restart at t=3) -- fires.
			service:_setNow(8.0)
			service:_checkOxygenGraceTimer(8.0)
			expect(service:_isPlayerDead(playerA)).to.equal(true)
		end)
	end)

	describe("Story 006 -- TD-013 PlayerRemoving teardown (pointer-vs-row semantics)", function()
		it("test_td013_clears_death_in_progress_started_at_and_pointer", function()
			local service, player = newServiceWithPlayer(70, 20)
			service:_setNow(0.0)
			service:_beginDeathFlow(player, 0.0, "A") -- alive-dies via Path A -- now tracked dead (S4)

			expect(service._deathReconciliationState.deathInProgress[player]).to.equal(true)
			expect(service._deathReconciliationState.deathStartedAt[player]).to.equal(0.0)
			expect(service._deathReconciliationState.currentDeathRecord[player]).never.to.equal(nil)

			-- Disconnect while in S4 -- predicate evaluation is moot (BeginDeathFlow's
			-- own idempotent guard no-ops regardless), but the teardown MUST still run.
			service:_setNow(10.0)
			service:_simulatePlayerRemoving(player)

			expect(service._deathReconciliationState.deathInProgress[player]).to.equal(nil)
			expect(service._deathReconciliationState.deathStartedAt[player]).to.equal(nil)
			expect(service._deathReconciliationState.currentDeathRecord[player]).to.equal(nil)
		end)

		it("test_td013_suppresses_departed_player_t6_entirely", function()
			local service, player = newServiceWithPlayer(71, 20)
			service:_setNow(0.0)
			service:_beginDeathFlow(player, 0.0, "A")

			service:_setNow(5.0)
			service:_simulatePlayerRemoving(player) -- departs mid-respawn-timer

			local t6Calls = 0
			service._onPlayerT6RespawnedFn = function(_userId: number)
				t6Calls += 1
			end

			-- Even once RESPAWN_DELAY has fully elapsed, no T6 fires -- `deathStartedAt`
			-- was cleared at teardown, so `_checkRespawnTimers`'s own tracked-player
			-- scan never selects this player again.
			service:_setNow(30.0)
			service:_checkRespawnTimers(30.0)
			expect(t6Calls).to.equal(0)
		end)

		it("test_td013_uncommitted_row_survives_pointer_cleared_late_commit_orphan_removes", function()
			local service, player = newServiceWithPlayer(72, 20)
			service._getLastPredatorDamageTimestampFn = function(_userId: number): number?
				return -5.0 -- elapsed 5s at now=0
			end

			local outage = true
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, _deathEventId: string): boolean
				if outage then
					error("simulated RM outage")
				end
				return true
			end

			service:_setNow(0.0)
			service:_simulatePlayerRemoving(player) -- Path B fires (arm1), dispatch fails -> Pending

			local deathEventId = nil
			for id, row in service._deathReconciliationState.reconcileRows do
				deathEventId = id
			end
			expect(deathEventId).never.to.equal(nil)

			-- Pointer cleared (TD-013), row SURVIVES (still Pending -- uncommitted rows
			-- are NEVER deleted on departure).
			expect(service._deathReconciliationState.currentDeathRecord[player]).to.equal(nil)
			expect(service._deathReconciliationState.reconcileRows[deathEventId :: string]).never.to.equal(nil)
			expect((service._deathReconciliationState.reconcileRows[deathEventId :: string] :: ReconcileRow).state).to.equal("Pending")

			-- A late reconciliation tick recovers it -- with no live pointer, this is
			-- an ORPHAN commit: the row is removed immediately (pc-4's own H.39 rule),
			-- exercised here via the pointer having been cleared by departure.
			outage = false
			service:_setNow(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)
			service:_runReconciliationTick(ReconLogic.RECONCILIATION_TICK_INTERVAL + 1.0)

			expect(service._deathReconciliationState.reconcileRows[deathEventId :: string]).to.equal(nil)
		end)

		it("test_td013_already_committed_row_at_teardown_is_retired_immediately", function()
			local service, player = newServiceWithPlayer(73, 20)
			service._getLastPredatorDamageTimestampFn = function(_userId: number): number?
				return -5.0
			end

			-- Capture-at-source (code-review fix): record the dispatched deathEventId
			-- directly from the spend seam's own argument, rather than scanning
			-- `reconcileRows` AFTER the fact. The prior after-the-fact scan could not
			-- distinguish "retirement worked" from "the Path-B dispatch never fired at
			-- all" (an empty `reconcileRows` table satisfies BOTH an `if deathEventId
			-- then` guard skip AND a genuinely-retired row identically). Capturing the
			-- id at the spend call site proves the dispatch actually happened
			-- UNCONDITIONALLY, before asserting the row's post-teardown absence.
			local capturedId: string? = nil
			service._requestSquadOxygenSpendFn = function(_userId: number, _amount: number, _reason: string, deathEventId: string): boolean
				capturedId = deathEventId
				return true
			end

			service:_setNow(0.0)
			service:_simulatePlayerRemoving(player) -- Path B fires, spend succeeds -> Committed

			-- Proves the dispatch actually happened (not a silent no-dispatch).
			expect(capturedId).never.to.equal(nil)

			-- Proves the already-Committed row was retired at teardown -- the Fake's
			-- synchronous dispatch already committed AND the SAME teardown pass
			-- retired it (both happen inside one `_simulatePlayerRemoving` call in
			-- this harness). This is the "if already Committed at teardown time,
			-- remove immediately" clause, distinct from the orphan-at-later-commit
			-- path the previous test covers -- asserted UNCONDITIONALLY, not gated
			-- behind an `if capturedId then`.
			expect(service._deathReconciliationState.reconcileRows[capturedId :: string]).to.equal(nil)
		end)
	end)

	-- ============================================================================
	-- Static/structural source-text checks against the real PlayerControllerService
	-- .luau AND the server bootstrap files -- mirrors death-cost-reconciliation-core_
	-- test.luau's own established pattern.
	-- ============================================================================
	describe("PlayerControllerService.luau / bootstrap -- Story 006 (wiring, static/structural checks)", function()
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

		it("test_knitinit_calls_pathbgracelogic_validateconfig", function()
			local source = loadStrippedSource()
			expect(source:find("PathBGraceLogic%.ValidateConfig%(PathBGraceLogic%.OXYGEN_GRACE_DURATION%)")).never.to.equal(nil)
		end)

		-- Code-review fix: the GDD G.6 coupled-knob invariant is a SECOND, separate
		-- KnitInit call site (couples two constants, not one) -- pinned independently
		-- of the OXYGEN_GRACE_DURATION gate above.
		it("test_knitinit_calls_pathbgracelogic_validatelatchmaxageinvariant", function()
			local source = loadStrippedSource()
			expect(
				source:find(
					"PathBGraceLogic%.ValidateLatchMaxAgeInvariant%(%s*PathBGraceLogic%.LATCH_MAX_AGE,%s*PathBGraceLogic%.HP_ARM_RECENT_WINDOW%s*%)"
				)
			).never.to.equal(nil)
		end)

		it("test_playerremoving_predicate_and_dispatch_run_before_td013_teardown_clears", function()
			local source = loadStrippedSource()
			local removingPos = source:find("Players%.PlayerRemoving:Connect%(function%(player: Player%)")
			expect(removingPos).never.to.equal(nil)

			local dispatchPos = source:find('self:_beginDeathFlow%(player, cachedNow, "B"%)', removingPos)
			expect(dispatchPos).never.to.equal(nil)

			local deathInProgressClearPos = source:find("reconState%.deathInProgress%[player%] = nil", removingPos)
			local deathStartedAtClearPos = source:find("reconState%.deathStartedAt%[player%] = nil", removingPos)
			local pointerClearPos = source:find("reconState%.currentDeathRecord%[player%] = nil", removingPos)
			expect(deathInProgressClearPos).never.to.equal(nil)
			expect(deathStartedAtClearPos).never.to.equal(nil)
			expect(pointerClearPos).never.to.equal(nil)

			-- Ordering: the Path-B dispatch call site sits textually BEFORE all three
			-- TD-013 teardown clears in the SAME handler.
			expect((dispatchPos :: number) < (deathInProgressClearPos :: number)).to.equal(true)
			expect((dispatchPos :: number) < (deathStartedAtClearPos :: number)).to.equal(true)
			expect((dispatchPos :: number) < (pointerClearPos :: number)).to.equal(true)
		end)

		it("test_first_statement_block_reads_precede_the_predicate_call", function()
			local source = loadStrippedSource()
			local removingPos = source:find("Players%.PlayerRemoving:Connect%(function%(player: Player%)")
			expect(removingPos).never.to.equal(nil)

			local cachedNowPos = source:find("local cachedNow = self%.getServerTime%(%)", removingPos)
			local cachedDamagePos = source:find("local cachedDamageTs = self%._getLastPredatorDamageTimestampFn%(player%.UserId%)", removingPos)
			local predicatePos = source:find("PathBGraceLogic%.IsImminentDeath%(", removingPos)
			expect(cachedNowPos).never.to.equal(nil)
			expect(cachedDamagePos).never.to.equal(nil)
			expect(predicatePos).never.to.equal(nil)

			expect((cachedNowPos :: number) < (predicatePos :: number)).to.equal(true)
			expect((cachedDamagePos :: number) < (predicatePos :: number)).to.equal(true)
		end)

		it("test_fourth_heartbeat_connection_drives_oxygen_grace_check", function()
			local source = loadStrippedSource()
			expect(source:find("self:_onOxygenGraceHeartbeat%(%)")).never.to.equal(nil)
		end)

		it("test_onoxygenexpired_directly_callable_public_method", function()
			local source = loadStrippedSource()
			expect(source:find("function PlayerControllerService:OnOxygenExpired%(%): %(%)")).never.to.equal(nil)
		end)

		it("test_checkrespawntimers_consults_oxygen_gate_before_tryrespawn", function()
			local source = loadStrippedSource()
			local fnPos = source:find("function PlayerControllerService:_checkRespawnTimers%(")
			expect(fnPos).never.to.equal(nil)
			local gatePos = source:find("self:_isRespawnOxygenGated%(player%)", fnPos)
			local tryRespawnPos = source:find("DeathReconciliationLogic%.TryRespawn%(", fnPos)
			expect(gatePos).never.to.equal(nil)
			expect(tryRespawnPos).never.to.equal(nil)
			expect((gatePos :: number) < (tryRespawnPos :: number)).to.equal(true)
		end)

		it("test_no_second_inline_get_server_time_now_call_introduced_by_story_006", function()
			-- The pre-existing pc-5 pin (death-respawn-side-effects_test.luau) already
			-- asserts count==1 for the whole file; this test re-confirms the SAME
			-- invariant from this story's own file, so a future regression in EITHER
			-- test file still catches it.
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

		it("test_no_humanoid_died_subscription_introduced_by_story_006", function()
			local source = loadStrippedSource()
			expect(source:find(".Died:Connect(", 1, true)).to.equal(nil)
		end)

		it("test_no_forbidden_deprecated_scheduling_primitives_in_story_006_sections", function()
			local raw = loadRawSource()
			local sectionStart = raw:find("SCOPE NOTE %(Story 006")
			expect(sectionStart).never.to.equal(nil)
			local rawSection = raw:sub(sectionStart :: number)
			local strippedSection = stripLuaComments(rawSection)

			expect(strippedSection:find("%f[%a]wait%(")).to.equal(nil)
			expect(strippedSection:find("%f[%a]delay%(")).to.equal(nil)
			expect(strippedSection:find("task%.delay")).to.equal(nil)
		end)

		it("test_no_global_table_usage_introduced_by_story_006", function()
			local raw = loadRawSource()
			local sectionStart = raw:find("SCOPE NOTE %(Story 006")
			expect(sectionStart).never.to.equal(nil)
			local rawSection = raw:sub(sectionStart :: number)
			expect(rawSection:find("_G%.")).to.equal(nil)
		end)

		it("test_predator_and_resource_stub_flags_still_per_instance_not_class_table", function()
			local source = loadRawSource()
			expect(source:find("PlayerControllerService%._hasWarnedMissingResourceService")).to.equal(nil)
			expect(source:find("PlayerControllerService%._hasWarnedMissingPredatorService")).to.equal(nil)
		end)

		-- ADR-0005's binding project-wide requirement: a KnitInit-time config-
		-- validation hard error MUST be paired with a bootstrap catch handler that
		-- calls game:Shutdown(). Verifies the EXISTING bootstrap already satisfies
		-- this (no bootstrap file changes were needed for this story).
		it("test_bootstrap_catch_handler_calls_shutdown", function()
			local bootstrapSource = fs.readFile("src/core/ServerBootstrap.luau")
			local catchPos = bootstrapSource:find(":catch%(function%(err: any%)")
			expect(catchPos).never.to.equal(nil)
			local warnPos = bootstrapSource:find("deps%.warn%(err%)", catchPos)
			local shutdownPos = bootstrapSource:find("deps%.shutdown%(%)", catchPos)
			expect(warnPos).never.to.equal(nil)
			expect(shutdownPos).never.to.equal(nil)
		end)

		it("test_server_init_wires_shutdown_to_real_game_shutdown", function()
			local initSource = fs.readFile("src/core/ServerInit.server.luau")
			local shutdownFieldPos = initSource:find("shutdown = function%(%)")
			expect(shutdownFieldPos).never.to.equal(nil)
			local gameShutdownPos = initSource:find("game:Shutdown%(%)", shutdownFieldPos)
			expect(gameShutdownPos).never.to.equal(nil)
		end)

		-- H.22f: the shared async failure-log path (used by Path A, Path B, AND
		-- reconciliation dispatches alike -- this story does not fork it) logs via
		-- `row.deathEventId`/`row.userId` ONLY, never a live `player.Name`/`player.*`
		-- dereference. Pinned directly against the real source so this claim is
		-- verified independently of the Fake harness (which never constructs this
		-- exact log line at all).
		it("test_completedispatch_failure_log_never_dereferences_live_player_instance", function()
			local source = loadStrippedSource()
			local fnPos = source:find("function PlayerControllerService:_completeDispatch%(")
			expect(fnPos).never.to.equal(nil)
			local nextFnPos = source:find("\nfunction PlayerControllerService:", fnPos + 1)
			local fnBody = source:sub(fnPos, nextFnPos or #source)

			expect(fnBody:find("RequestSquadOxygenSpend failed for deathEventId=%%s")).never.to.equal(nil)
			expect(fnBody:find("row%.deathEventId")).never.to.equal(nil)
			expect(fnBody:find("row%.userId")).never.to.equal(nil)
			-- Never a live-instance dereference anywhere in this function's body.
			expect(fnBody:find("player%.Name")).to.equal(nil)
			expect(fnBody:find("player%.UserId")).to.equal(nil)
		end)
	end)
end
