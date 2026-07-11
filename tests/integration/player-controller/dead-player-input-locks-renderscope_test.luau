--!strict
-- dead-player-input-locks-renderscope_test
--
-- Integration tests for Story 007: Dead-Player Input Locks & renderScope (S4/S5).
-- Story: production/epics/player-controller/story-007-dead-player-input-locks-renderscope.md
-- ADR: docs/architecture/adr-0012-player-controller-death-spectator-state.md
--      (THE LAW -- renderScope server-minted, pushed exactly once per
--      transition, inside the same handler that performs the transition; S4
--      input locks; S5 strict superset of S4's locks)
--      docs/architecture/adr-0006-remoteevent-trust-boundary.md (step-1
--      alive/state guard; "a dropped event MUST NOT mutate any state")
--
-- Production code under test:
--   src/gameplay/services/PlayerControllerRenderScopeLogic.luau -- the REAL,
--     pure, zero-require classification/predicate module, exercised DIRECTLY
--     (Section A below).
--   src/gameplay/services/PlayerControllerService.luau -- Knit is not
--     vendored under ReplicatedStorage.Packages in this harness, so a live
--     PlayerControllerService instance cannot be constructed here (same
--     precedent every prior PC integration test in this repo documents).
--     Verified two ways instead:
--       (a) FakePlayerControllerService (Section B) mirrors the real Knit
--           wrapper's Story 001/004/005/006/007 method bodies method-for-
--           method, per pc-4/pc-5's own established Fake-harness precedent.
--           DISCLOSED SUBSTITUTIONS (not silently glossed over):
--             1. `_beginAndDispatch` calls `_completeDispatch` SYNCHRONOUSLY
--                where the real wrapper `task.spawn`s it -- deterministic
--                single-threaded test execution (pc-5's own precedent); the
--                state-machine TRANSITIONS and side-effect SELECTIONS/renderScope
--                mints exercised are identical to production.
--             2. `player` values are plain Lua tables (`{UserId, Name}`), never
--                real Roblox `Player` instances -- this project's Lune harness
--                cannot construct a live Player/Character/CharacterAdded chain
--                at all (see PlayerControllerDeathSideEffectsLogic.luau's own
--                PLAYER IDENTITY precedent).
--             3. `Humanoid.WalkSpeed`/`Humanoid.JumpPower`/`Humanoid.JumpHeight`
--                are stood in by a Fake-local
--                `self._humanoidState[player] = {WalkSpeed, JumpPower, JumpHeight}`
--                plain table -- there is no live Humanoid instance to write to
--                under this harness. This proves the WRAPPER'S OWN DECISION of
--                "capture JumpPower/JumpHeight + zero at S4 entry, restore the
--                CAPTURED values at T6" (code-review fix, engine Finding 3 --
--                no hardcoded jump-restore default anywhere in this path), not
--                the real `Humanoid` instance write itself (a Studio-only
--                concern, same class of gap this file's own static/structural
--                section D closes by asserting the REAL file contains the
--                real `humanoid.WalkSpeed = 0` / `humanoid.JumpPower = 0` /
--                `humanoid.JumpHeight = 0` writes and their captured-value
--                restores).
--             4. `_checkRespawnTimers`'s player-resolution and
--                `_respawnPlayerAtAnchorFn`/`_getRespawnAnchorPositionFn` seams
--                are ALWAYS test-overridden (never exercising the real
--                `Player:LoadCharacter()` call), matching pc-5's own harness
--                disclosure.
--       (b) Section D: static/structural source-text checks against the real
--           PlayerControllerService.luau (mirrors pc-5's own established
--           pattern, including its documented stripLuaComments `--`-in-string
--           caveat).
--
-- OUT OF SCOPE DISCLOSURE (matches this story's own Ping/Emote disclosure
-- style): H.34 (touch emote-wheel client-side suppression of a tap-hold
-- RequestGather, the T9 mutual-exclusion) is Story 013's client-side
-- obligation -- deliberately NOT covered by this file (no client code exists
-- in this story; see the story document's own Out of Scope section).
--
-- Story Type: Integration -- coding-standards.md's bar is an automated
-- integration test that must pass (BLOCKING gate).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local RenderScopeLogic = require(ServerScriptService.gameplay.services.PlayerControllerRenderScopeLogic)
local ReconLogic = require(ServerScriptService.gameplay.services.PlayerControllerDeathReconciliationLogic)
local SideEffectsLogic = require(ServerScriptService.gameplay.services.PlayerControllerDeathSideEffectsLogic)
local LocomotionStaminaLogic = require(ServerScriptService.gameplay.services.PlayerControllerLocomotionStaminaLogic)
local LanternLogic = require(ServerScriptService.gameplay.services.PlayerControllerLanternLogic)
local EmissionPublisherLogic = require(ServerScriptService.gameplay.services.PlayerControllerEmissionPublisherLogic)

type ReconcileRow = ReconLogic.ReconcileRow

-- Local (never global) elapsed-time helper for FakePlayerControllerService's
-- own `_checkRespawnTimers` mirror below -- avoids pulling in the full
-- PlayerControllerPathBGraceLogic dependency for one predicate, and avoids
-- leaking a bare global function name into the shared Lune process (this
-- project's test-standards.md isolation rule).
local function hasRespawnTimerElapsed(startedAt: number?, now: number, delay: number): boolean
	if not startedAt then
		return false
	end
	return (now - startedAt) >= delay
end

return function()
	-- ==========================================================================
	-- Section A -- PlayerControllerRenderScopeLogic (pure module) direct tests
	-- ==========================================================================

	describe("PlayerControllerRenderScopeLogic -- IsAliveScope (ADR-0012 step-1 boolean)", function()
		local function test_alive_scope_is_eligible()
			expect(RenderScopeLogic.IsAliveScope("alive")).to.equal(true)
		end
		it("test_alive_scope_is_eligible", test_alive_scope_is_eligible)

		local function test_dead_respawning_scope_is_not_eligible()
			expect(RenderScopeLogic.IsAliveScope("dead-respawning")).to.equal(false)
		end
		it("test_dead_respawning_scope_is_not_eligible", test_dead_respawning_scope_is_not_eligible)

		local function test_post_run_scope_is_not_eligible()
			expect(RenderScopeLogic.IsAliveScope("post-run")).to.equal(false)
		end
		it("test_post_run_scope_is_not_eligible", test_post_run_scope_is_not_eligible)

		local function test_nil_scope_is_not_eligible()
			-- Arrange: a player whose renderScope table entry was never
			-- initialized (fail-closed, per this module's own doc comment).
			-- Act/Assert:
			expect(RenderScopeLogic.IsAliveScope(nil)).to.equal(false)
		end
		it("test_nil_scope_is_not_eligible_fail_closed", test_nil_scope_is_not_eligible)
	end)

	describe("PlayerControllerRenderScopeLogic -- IsEventAllowedInScope (H.24 classification matrix)", function()
		local ALL_EVENT_CLASSES = { "lantern", "sprint", "heartbeat", "gather", "interact", "ping", "emote" }

		local function test_all_classes_allowed_while_alive()
			for _, class in ALL_EVENT_CLASSES do
				expect(RenderScopeLogic.IsEventAllowedInScope(class :: any, "alive")).to.equal(true)
			end
		end
		it("test_all_classes_allowed_while_alive", test_all_classes_allowed_while_alive)

		local function test_s4_rejects_ping_movement_lantern_gather_interact_heartbeat()
			-- H.24 / GDD C.5 item 4: "Movement / sprint: NO", "Lantern toggle: NO",
			-- "Gather / interact / craft: NO"; quick-ping "NO at MVP -- CUT".
			local rejectedInS4 = { "lantern", "sprint", "heartbeat", "gather", "interact", "ping" }
			for _, class in rejectedInS4 do
				expect(RenderScopeLogic.IsEventAllowedInScope(class :: any, "dead-respawning")).to.equal(false)
			end
		end
		it(
			"test_s4_rejects_ping_movement_lantern_gather_interact_heartbeat",
			test_s4_rejects_ping_movement_lantern_gather_interact_heartbeat
		)

		local function test_s4_allows_emote()
			-- H.24 accept-half, GDD C.5 item 4 "Emote wheel: YES". No real
			-- RequestEmote RemoteEvent exists yet (Story 013's scope) -- this
			-- proves the CLASSIFICATION accepts an emote-class event, per this
			-- story's own pre-resolved item. STRUCTURALLY-COVERED-PENDING-STORY-013:
			-- the literal H.24 "RequestEmote accepted server-side" assertion
			-- cannot be exercised end-to-end until Story 013 wires a real handler
			-- that consults this same table.
			expect(RenderScopeLogic.IsEventAllowedInScope("emote", "dead-respawning")).to.equal(true)
		end
		it("test_s4_allows_emote_structurally_pending_story_013", test_s4_allows_emote)

		local function test_s5_rejects_every_event_class_including_emote()
			-- AC-3 / ADR-0012: S5 rejects a STRICT SUPERSET of what S4 rejects --
			-- "no exception permitted in S5 that S4 allows." Asserted here across
			-- EVERY class this table enumerates, not just the four H.24 names.
			for _, class in ALL_EVENT_CLASSES do
				expect(RenderScopeLogic.IsEventAllowedInScope(class :: any, "post-run")).to.equal(false)
			end
		end
		it("test_s5_rejects_every_event_class_including_emote", test_s5_rejects_every_event_class_including_emote)

		local function test_s5_superset_property_mechanical()
			-- For every class: allowed-in-S5 implies allowed-in-S4 (vacuously true
			-- since S5 never allows anything), AND allowed-in-S4 implies
			-- allowed-in-alive (S4's carve-out is a SUBSET of alive's full access).
			for _, class in ALL_EVENT_CLASSES do
				local allowedS5 = RenderScopeLogic.IsEventAllowedInScope(class :: any, "post-run")
				local allowedS4 = RenderScopeLogic.IsEventAllowedInScope(class :: any, "dead-respawning")
				local allowedAlive = RenderScopeLogic.IsEventAllowedInScope(class :: any, "alive")
				if allowedS5 then
					expect(allowedS4).to.equal(true)
				end
				if allowedS4 then
					expect(allowedAlive).to.equal(true)
				end
			end
		end
		it("test_s5_superset_property_mechanical", test_s5_superset_property_mechanical)

		local function test_nil_scope_rejects_every_class()
			for _, class in ALL_EVENT_CLASSES do
				expect(RenderScopeLogic.IsEventAllowedInScope(class :: any, nil)).to.equal(false)
			end
		end
		it("test_nil_scope_rejects_every_class_fail_closed", test_nil_scope_rejects_every_class)
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

		self._lanternRateLimit = {}
		self._sprintRateLimit = {}
		self._heartbeatRateLimit = {}

		-- Story 007
		self._renderScope = {}
		self._renderScopePushLog = {}
		self._renderScopePushCount = {}
		self._humanoidState = {}
		-- Code-review fix (engine Finding 3): the S4-entry capture-and-restore
		-- table, mirroring the real `self._capturedJumpState`.
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
		-- Story 007: every player starts "alive" -- mirrors the real
		-- `_initPlayerState`'s own seed write (no push -- not a transition).
		self._renderScope[player] = "alive"
		-- Fixture values only (test-standards.md: test data belongs in the test,
		-- never a shared production constant) -- deliberately NOT round numbers
		-- matching any prior "default", so the capture-and-restore tests below
		-- can prove the T6 restore returns THIS exact captured value, not a
		-- coincidentally-matching default.
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

		-- HARNESS DISCLOSURE (header note (a).1): real production `task.spawn`s
		-- this; called synchronously here for deterministic single-threaded
		-- execution.
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

		-- HARNESS DISCLOSURE (header note (a).1/(a).4): the real wrapper
		-- `task.spawn`s this remainder and re-checks liveness via
		-- `Players:GetPlayerByUserId`; mirrored via the Fake-local registry.
		if self._playersByUserId[player.UserId] ~= player then
			return
		end

		local anchorPosition = self._getRespawnAnchorPositionFn(player)
		local hrp = self._respawnPlayerAtAnchorFn(player, anchorPosition)

		self._lastServerTrackedPosition[player] = anchorPosition

		self._onPlayerT6RespawnedFn(player.UserId)

		if hrp then
			self._onSquadMemberAliveChangedFn(player.UserId, true)
			-- Story 007: the REAL S4 exit -- gated on the SAME `hrp` confirmation
			-- as the alive=true edge immediately above (H.72 parity).
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
			-- Story 007: the REAL S4 entry -- renderScope mint + humanoid-state
			-- zero-out. Same branch pc-5 already established for the proxy flag
			-- immediately above -- NOT a new call site.
			self:_enterDeadRespawningRenderScope(player)
		end

		if effects.releasePredatorLock then
			self._releasePredatorLockFn(row.userId)
		end
	end

	-- ---------------------------------------------------------------------
	-- Story 007 -- renderScope core (mirrors PlayerControllerService.luau's
	-- own `_setRenderScope`/`_isEligibleForGameplayEvents`/
	-- `_enterDeadRespawningRenderScope`/`_exitToAliveRenderScope`/
	-- `EnterPostRunScope`).
	-- ---------------------------------------------------------------------

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

	--- Code-review fix (engine Finding 3): CAPTURE-AND-RESTORE, not a hardcoded
	--- jump-restore default -- mirrors the real
	--- `_enterDeadRespawningRenderScope`'s own doc comment. Nil-guarded
	--- (`if humanoidState then`) so a nil/never-spawned character at S4 entry
	--- (fix 5, QA gap) is a harmless no-op: nothing captured, nothing zeroed.
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

	--- Restores whatever was actually captured at S4 entry -- never a
	--- hardcoded default. If nothing was captured (nil character at S4 entry),
	--- this is a no-op for Jump* and the fresh humanoidState (if any) simply
	--- keeps its own already-set values -- there is nothing to restore TO.
	--- `_capturedJumpState[player]` is cleared unconditionally, mirroring the
	--- real method.
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
	-- Story 007 -- guarded handler mirrors (ADR-0006 canonical order, step 1
	-- now the REAL renderScope guard). Steps 3-5 (global budget, payload
	-- shape beyond the boolean check, plausibility re-derivation) are
	-- intentionally trimmed from this Fake -- they are Story 001/002's own
	-- already-tested territory and are orthogonal to this story's ACs (H.24's
	-- edge case is specifically about STEP 1 vs STEP 2's rate-limit anchor).
	-- ---------------------------------------------------------------------

	function FakePlayerControllerService:_handleLanternToggleRequest(player: any, raised: any): (boolean, string?)
		if not self:_isEligibleForGameplayEvents(player) then
			return false, "not-alive-or-eligible"
		end
		local now = self._now
		local rateRecord = self._lanternRateLimit[player]
		if not rateRecord then
			rateRecord = {
				perSecond = { count = 0, windowStart = now },
				burst = { count = 0, windowStart = now },
			}
			self._lanternRateLimit[player] = rateRecord
		end
		if not LanternLogic.CheckLanternToggleRateLimit(rateRecord, now) then
			return false, "rate-limited"
		end
		if typeof(raised) ~= "boolean" then
			return false, "invalid-payload-shape"
		end
		local state = self._playerState[player]
		if not state then
			return false, "no-player-state"
		end
		local accepted, reason = LanternLogic.HandleLanternToggleDomain(state, raised)
		return accepted, reason
	end

	function FakePlayerControllerService:_handleSprintToggleRequest(player: any, sprint: any): (boolean, string?)
		if not self:_isEligibleForGameplayEvents(player) then
			return false, "not-alive-or-eligible"
		end
		local now = self._now
		local rateRecord = self._sprintRateLimit[player]
		if not rateRecord then
			rateRecord = {
				perSecond = { count = 0, windowStart = now },
				burst = { count = 0, windowStart = now },
			}
			self._sprintRateLimit[player] = rateRecord
		end
		if not LocomotionStaminaLogic.CheckSprintToggleRateLimit(rateRecord, now) then
			return false, "rate-limited"
		end
		if typeof(sprint) ~= "boolean" then
			return false, "invalid-payload-shape"
		end
		local locState = self._locomotionState[player]
		if not locState then
			return false, "no-player-state"
		end
		local accepted, reason = LocomotionStaminaLogic.HandleSprintToggleDomain(locState, sprint, now)
		return accepted, reason
	end

	function FakePlayerControllerService:_handlePlayerHeartbeat(player: any): boolean
		if not self:_isEligibleForGameplayEvents(player) then
			return false
		end
		local now = self._now
		local rateRecord = self._heartbeatRateLimit[player]
		if not rateRecord then
			rateRecord = { count = 0, windowStart = now }
			self._heartbeatRateLimit[player] = rateRecord
		end
		if not LocomotionStaminaLogic.CheckHeartbeatRateLimit(rateRecord, now) then
			return false
		end
		local locState = self._locomotionState[player]
		if not locState then
			return false
		end
		return LocomotionStaminaLogic.HandlePlayerHeartbeatDomain(locState, now)
	end

	function FakePlayerControllerService:BeginGatherHold(player: any, nodeId: string, isDarkZone: boolean): boolean
		if not self:_isEligibleForGameplayEvents(player) then
			return false
		end
		local state = self._playerState[player]
		if not state then
			return false
		end
		return LanternLogic.BeginGatherHold(state, nodeId, isDarkZone, self._now)
	end

	function FakePlayerControllerService:TryCommitGatherHold(player: any, nodeId: string): boolean
		if not self:_isEligibleForGameplayEvents(player) then
			return false
		end
		local state = self._playerState[player]
		if not state then
			return false
		end
		return LanternLogic.TryCommitGatherHold(state, nodeId)
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
		-- Drives S4 entry through the REAL pc-5 T5 commit-path hook:
		-- _onPlayerDied -> _beginDeathFlow -> _beginAndDispatch (Pending->InFlight,
		-- pre-yield (g)/(h)/(i)) -> _completeDispatch (oxygen spend succeeds by
		-- default) -> TryCommitDispatch (InFlight->Committed) -> _onDeathCommitFn
		-- -> _applyPostCommitDeathSideEffects -> effects.lockClientInput=true
		-- (Path A initial dispatch) -> _enterDeadRespawningRenderScope.
		fake:_setNow(now)
		fake:_onPlayerDied({ deadPlayer = player, deathTimestamp = now, predatorWasLockedAtDeath = false })
	end

	describe("H.24 -- S4 rejects Gather/Lantern/Sprint/Heartbeat with zero state mutation", function()
		local function test_s4_rejects_all_named_events_zero_mutation()
			-- Arrange
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			expect(fake._renderScope[playerA]).to.equal("dead-respawning")

			-- Act
			local lanternAccepted = fake:_handleLanternToggleRequest(playerA, true)
			local sprintAccepted = fake:_handleSprintToggleRequest(playerA, true)
			local heartbeatAccepted = fake:_handlePlayerHeartbeat(playerA)
			local gatherArmed = fake:BeginGatherHold(playerA, "node-1", false)
			local gatherCommitted = fake:TryCommitGatherHold(playerA, "node-1")

			-- Assert: all rejected.
			expect(lanternAccepted).to.equal(false)
			expect(sprintAccepted).to.equal(false)
			expect(heartbeatAccepted).to.equal(false)
			expect(gatherArmed).to.equal(false)
			expect(gatherCommitted).to.equal(false)

			-- Assert: ZERO state mutation -- step 1 rejects BEFORE step 2 ever
			-- creates a rate-limit record.
			expect(fake._lanternRateLimit[playerA]).to.equal(nil)
			expect(fake._sprintRateLimit[playerA]).to.equal(nil)
			expect(fake._heartbeatRateLimit[playerA]).to.equal(nil)
			expect(fake._playerState[playerA].gatherInProgress).to.equal(nil)
		end
		it("test_s4_rejects_all_named_events_zero_mutation", test_s4_rejects_all_named_events_zero_mutation)

		local function test_s4_rejects_ping_via_classification_no_handler_exists()
			-- RequestPing has no PC handler yet (Story 012's scope) -- proven at
			-- the classification level per this story's own scope contract.
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			expect(RenderScopeLogic.IsEventAllowedInScope("ping", fake._renderScope[playerA])).to.equal(false)
		end
		it("test_s4_rejects_ping_via_classification_no_handler_exists", test_s4_rejects_ping_via_classification_no_handler_exists)

		local function test_s4_allows_emote_via_classification_no_handler_exists()
			-- H.24 accept-half, structurally-covered-pending-Story-013 (see
			-- Section A's own test for the direct pure-module proof).
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			expect(RenderScopeLogic.IsEventAllowedInScope("emote", fake._renderScope[playerA])).to.equal(true)
		end
		it("test_s4_allows_emote_via_classification_no_handler_exists", test_s4_allows_emote_via_classification_no_handler_exists)

		local function test_flood_of_rejected_s4_requests_never_perturbs_rate_limit_anchor()
			-- Edge case (AC-1): rejection happens at step 1, BEFORE rate-limit or
			-- any other check runs, so a flood of rejected S4 requests can never
			-- perturb a legitimate cooldown anchor.
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)

			for i = 1, 50 do
				fake:_setNow(10 + i * 0.01)
				fake:_handleLanternToggleRequest(playerA, true)
				fake:_handleSprintToggleRequest(playerA, true)
				fake:_handlePlayerHeartbeat(playerA)
			end

			expect(fake._lanternRateLimit[playerA]).to.equal(nil)
			expect(fake._sprintRateLimit[playerA]).to.equal(nil)
			expect(fake._heartbeatRateLimit[playerA]).to.equal(nil)
		end
		it(
			"test_flood_of_rejected_s4_requests_never_perturbs_rate_limit_anchor",
			test_flood_of_rejected_s4_requests_never_perturbs_rate_limit_anchor
		)

		local function test_alive_player_accepts_lantern_toggle_contrast_case()
			-- Contrast case: the SAME request from an alive player mutates state
			-- (proves the rejection above is genuinely guard-driven, not a
			-- universal no-op bug in the Fake).
			local fake, playerA = newFakeWithTwoPlayers()
			local accepted = fake:_handleLanternToggleRequest(playerA, true)
			expect(accepted).to.equal(true)
			expect(fake._lanternRateLimit[playerA]).never.to.equal(nil)
		end
		it("test_alive_player_accepts_lantern_toggle_contrast_case", test_alive_player_accepts_lantern_toggle_contrast_case)
	end)

	describe("renderScope single-mint discipline (ADR-0012 Validation Criteria)", function()
		local function test_exactly_one_push_on_s1_to_s4_transition()
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)

			expect(fake._renderScopePushCount[playerA]).to.equal(1)
			expect(fake._renderScopePushLog[#fake._renderScopePushLog].scope).to.equal("dead-respawning")
		end
		it("test_exactly_one_push_on_s1_to_s4_transition", test_exactly_one_push_on_s1_to_s4_transition)

		local function test_no_redundant_push_on_subsequent_heartbeats_while_still_s4()
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			expect(fake._renderScopePushCount[playerA]).to.equal(1)

			-- Simulate repeated Heartbeat-driven activity while still S4: nothing
			-- in this file's production wiring re-invokes _setRenderScope for an
			-- unchanged scope (the idempotent guard inside _setRenderScope is the
			-- belt-and-braces backstop -- proven directly here).
			for i = 1, 10 do
				fake:_setRenderScope(playerA, "dead-respawning")
			end
			expect(fake._renderScopePushCount[playerA]).to.equal(1)
		end
		it(
			"test_no_redundant_push_on_subsequent_heartbeats_while_still_s4",
			test_no_redundant_push_on_subsequent_heartbeats_while_still_s4
		)

		local function test_exactly_one_additional_push_on_t6_respawn()
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			expect(fake._renderScopePushCount[playerA]).to.equal(1)

			-- Arrange a successful respawn placement.
			fake._respawnPlayerAtAnchorFn = function(_player: any, _anchorPosition: Vector3): any?
				return { Position = Vector3.new(0, 0, 0) }
			end

			fake:_checkRespawnTimers(10 + ReconLogic.RESPAWN_DELAY)

			expect(fake._renderScope[playerA]).to.equal("alive")
			expect(fake._renderScopePushCount[playerA]).to.equal(2)
			expect(fake._renderScopePushLog[#fake._renderScopePushLog].scope).to.equal("alive")
		end
		it("test_exactly_one_additional_push_on_t6_respawn", test_exactly_one_additional_push_on_t6_respawn)

		local function test_no_alive_remint_if_respawn_placement_fails()
			-- If the real respawn placement fails (departed player / no hrp), the
			-- renderScope must NOT be re-minted to "alive" (H.72 parity -- never
			-- fires before the respawned HumanoidRootPart actually exists).
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			expect(fake._renderScopePushCount[playerA]).to.equal(1)

			-- Default _respawnPlayerAtAnchorFn already returns nil.
			fake:_checkRespawnTimers(10 + ReconLogic.RESPAWN_DELAY)

			expect(fake._renderScope[playerA]).to.equal("dead-respawning")
			expect(fake._renderScopePushCount[playerA]).to.equal(1)
		end
		it("test_no_alive_remint_if_respawn_placement_fails", test_no_alive_remint_if_respawn_placement_fails)

		local function test_exactly_one_push_on_post_run_entry()
			local fake, playerA = newFakeWithTwoPlayers()
			expect(fake._renderScopePushCount[playerA]).to.equal(nil)

			fake:EnterPostRunScope(playerA)

			expect(fake._renderScope[playerA]).to.equal("post-run")
			expect(fake._renderScopePushCount[playerA]).to.equal(1)
			expect(fake._renderScopePushLog[#fake._renderScopePushLog].scope).to.equal("post-run")
		end
		it("test_exactly_one_push_on_post_run_entry", test_exactly_one_push_on_post_run_entry)

		local function test_walkspeed_jumppower_jumpheight_zeroed_at_s4_entry_and_restored_at_t6()
			-- Arrange: playerA's fixture humanoidState is {WalkSpeed=WALK_SPEED,
			-- JumpPower=65, JumpHeight=8.5} (registered via newFakeWithTwoPlayers).
			local fake, playerA = newFakeWithTwoPlayers()
			expect(fake._humanoidState[playerA].WalkSpeed).to.equal(LocomotionStaminaLogic.WALK_SPEED)
			expect(fake._humanoidState[playerA].JumpPower).to.equal(65)
			expect(fake._humanoidState[playerA].JumpHeight).to.equal(8.5)

			-- Act: S4 entry.
			killViaRealT5Path(fake, playerA, 10)

			-- Assert: both zeroed; the pre-death values are CAPTURED, not lost.
			expect(fake._humanoidState[playerA].WalkSpeed).to.equal(0)
			expect(fake._humanoidState[playerA].JumpPower).to.equal(0)
			expect(fake._humanoidState[playerA].JumpHeight).to.equal(0)
			expect(fake._capturedJumpState[playerA]).never.to.equal(nil)
			expect(fake._capturedJumpState[playerA].JumpPower).to.equal(65)
			expect(fake._capturedJumpState[playerA].JumpHeight).to.equal(8.5)

			-- Act: T6 respawn.
			fake._respawnPlayerAtAnchorFn = function(_player: any, _anchorPosition: Vector3): any?
				return { Position = Vector3.new(0, 0, 0) }
			end
			fake:_checkRespawnTimers(10 + ReconLogic.RESPAWN_DELAY)

			-- Assert: WalkSpeed restored via GetMoveSpeed (fresh-life S1); Jump*
			-- restored to the EXACT captured values (65/8.5) -- never a
			-- hardcoded default (code-review fix, engine Finding 3) -- and the
			-- capture entry is cleared so it cannot leak into a later life.
			expect(fake._humanoidState[playerA].WalkSpeed).to.equal(LocomotionStaminaLogic.WALK_SPEED)
			expect(fake._humanoidState[playerA].JumpPower).to.equal(65)
			expect(fake._humanoidState[playerA].JumpHeight).to.equal(8.5)
			expect(fake._capturedJumpState[playerA]).to.equal(nil)
		end
		it(
			"test_walkspeed_jumppower_jumpheight_zeroed_at_s4_entry_and_restored_at_t6",
			test_walkspeed_jumppower_jumpheight_zeroed_at_s4_entry_and_restored_at_t6
		)

		local function test_jump_capture_restores_a_nondefault_value_not_a_hardcoded_default()
			-- QA-driven regression proof (engine Finding 3): give playerB a
			-- DIFFERENT, deliberately non-round JumpPower/JumpHeight from
			-- playerA's fixture, and confirm the restore returns playerB's OWN
			-- captured value -- proving this is a genuine per-player capture,
			-- not a shared/hardcoded constant that would coincidentally pass
			-- for any one player.
			local fake, _playerA, playerB = newFakeWithTwoPlayers()
			fake._humanoidState[playerB] = { WalkSpeed = LocomotionStaminaLogic.WALK_SPEED, JumpPower = 12, JumpHeight = 3.25 }

			killViaRealT5Path(fake, playerB, 10)
			expect(fake._capturedJumpState[playerB].JumpPower).to.equal(12)
			expect(fake._capturedJumpState[playerB].JumpHeight).to.equal(3.25)

			fake._respawnPlayerAtAnchorFn = function(_player: any, _anchorPosition: Vector3): any?
				return { Position = Vector3.new(0, 0, 0) }
			end
			fake:_checkRespawnTimers(10 + ReconLogic.RESPAWN_DELAY)

			expect(fake._humanoidState[playerB].JumpPower).to.equal(12)
			expect(fake._humanoidState[playerB].JumpHeight).to.equal(3.25)
		end
		it(
			"test_jump_capture_restores_a_nondefault_value_not_a_hardcoded_default",
			test_jump_capture_restores_a_nondefault_value_not_a_hardcoded_default
		)

		local function test_nil_character_at_s4_entry_and_t6_exit_handled_gracefully()
			-- QA gap (fix 5): a mid-yield-departed-or-never-spawned character at
			-- S4 entry -- nothing to capture, nothing to zero, and the scope
			-- must STILL mint (the renderScope write/push is independent of the
			-- humanoid nil-guard).
			local fake, playerA = newFakeWithTwoPlayers()
			fake._humanoidState[playerA] = nil

			local enteredOk = pcall(function()
				killViaRealT5Path(fake, playerA, 10)
			end)
			expect(enteredOk).to.equal(true)
			expect(fake._renderScope[playerA]).to.equal("dead-respawning")
			expect(fake._renderScopePushCount[playerA]).to.equal(1)
			expect(fake._capturedJumpState[playerA]).to.equal(nil)

			-- T6 exit: a FRESH humanoidState now exists (LoadCharacter succeeded)
			-- but NOTHING was captured at S4 entry -- the restore must be a
			-- graceful no-op for Jump*, leaving the fresh character's own
			-- already-set values untouched (there is nothing to restore TO).
			fake._humanoidState[playerA] = { WalkSpeed = 0, JumpPower = 42, JumpHeight = 6.0 }
			fake._respawnPlayerAtAnchorFn = function(_player: any, _anchorPosition: Vector3): any?
				return { Position = Vector3.new(0, 0, 0) }
			end
			local exitedOk = pcall(function()
				fake:_checkRespawnTimers(10 + ReconLogic.RESPAWN_DELAY)
			end)
			expect(exitedOk).to.equal(true)
			expect(fake._renderScope[playerA]).to.equal("alive")
			expect(fake._humanoidState[playerA].WalkSpeed).to.equal(LocomotionStaminaLogic.WALK_SPEED)
			expect(fake._humanoidState[playerA].JumpPower).to.equal(42)
			expect(fake._humanoidState[playerA].JumpHeight).to.equal(6.0)
		end
		it(
			"test_nil_character_at_s4_entry_and_t6_exit_handled_gracefully",
			test_nil_character_at_s4_entry_and_t6_exit_handled_gracefully
		)
	end)

	describe("S5 (post-run) strict superset of S4's locks (AC-3)", function()
		local function test_s5_rejects_all_named_events_zero_mutation()
			local fake, playerA = newFakeWithTwoPlayers()
			fake:EnterPostRunScope(playerA)
			expect(fake._renderScope[playerA]).to.equal("post-run")

			local lanternAccepted = fake:_handleLanternToggleRequest(playerA, true)
			local sprintAccepted = fake:_handleSprintToggleRequest(playerA, true)
			local heartbeatAccepted = fake:_handlePlayerHeartbeat(playerA)
			local gatherArmed = fake:BeginGatherHold(playerA, "node-1", false)
			-- QA gap fix: the S4 sibling test asserts BOTH BeginGatherHold AND
			-- TryCommitGatherHold; AC-3 claims "every event" for S5 too, so this
			-- must cover TryCommitGatherHold as well (a hold that was somehow
			-- already armed -- e.g. armed while alive, then RunEnded fires mid-
			-- hold -- must still be rejected at commit time in S5).
			local gatherCommitted = fake:TryCommitGatherHold(playerA, "node-1")

			expect(lanternAccepted).to.equal(false)
			expect(sprintAccepted).to.equal(false)
			expect(heartbeatAccepted).to.equal(false)
			expect(gatherArmed).to.equal(false)
			expect(gatherCommitted).to.equal(false)

			expect(fake._lanternRateLimit[playerA]).to.equal(nil)
			expect(fake._sprintRateLimit[playerA]).to.equal(nil)
			expect(fake._heartbeatRateLimit[playerA]).to.equal(nil)
			expect(fake._playerState[playerA].gatherInProgress).to.equal(nil)
		end
		it("test_s5_rejects_all_named_events_zero_mutation", test_s5_rejects_all_named_events_zero_mutation)

		local function test_s5_rejects_emote_where_s4_would_have_allowed_it()
			-- The load-bearing superset assertion: S5 rejects the ONE class S4
			-- uniquely allows.
			local fake, playerA = newFakeWithTwoPlayers()
			fake:EnterPostRunScope(playerA)
			expect(RenderScopeLogic.IsEventAllowedInScope("emote", fake._renderScope[playerA])).to.equal(false)
		end
		it("test_s5_rejects_emote_where_s4_would_have_allowed_it", test_s5_rejects_emote_where_s4_would_have_allowed_it)

		local function test_s5_entry_from_mid_death_s4_still_rejects()
			-- ADR-0012: S5 is entered "regardless of the player's S1-S4 status at
			-- that moment."
			local fake, playerA = newFakeWithTwoPlayers()
			killViaRealT5Path(fake, playerA, 10)
			expect(fake._renderScope[playerA]).to.equal("dead-respawning")

			fake:EnterPostRunScope(playerA)
			expect(fake._renderScope[playerA]).to.equal("post-run")
			expect(fake._renderScopePushCount[playerA]).to.equal(2)

			local accepted = fake:_handleLanternToggleRequest(playerA, true)
			expect(accepted).to.equal(false)
		end
		it("test_s5_entry_from_mid_death_s4_still_rejects", test_s5_entry_from_mid_death_s4_still_rejects)
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

	local function countOccurrences(source: string, literalPattern: string): number
		local count = 0
		local searchStart = 1
		while true do
			local foundIdx = source:find(literalPattern, searchStart, true)
			if not foundIdx then
				break
			end
			count += 1
			searchStart = foundIdx + #literalPattern
		end
		return count
	end

	describe("PlayerControllerService.luau -- Story 007 (wiring, static/structural checks)", function()
		local function test_client_table_declares_onrenderscopechanged()
			local source = loadServiceSource()
			local signalIdx = source:find("OnRenderScopeChanged = Knit%.CreateSignal%(%)")
			expect(signalIdx).never.to.equal(nil)
			local knitInitIdx = source:find("function PlayerControllerService:KnitInit%(%)")
			expect(knitInitIdx).never.to.equal(nil)
			-- The Client table is declared before KnitInit in this file --
			-- structural proof the signal lives in the Client table, not some
			-- later ad-hoc declaration.
			expect((signalIdx :: number) < (knitInitIdx :: number)).to.equal(true)
		end
		it("test_client_table_declares_onrenderscopechanged", test_client_table_declares_onrenderscopechanged)

		local function test_setrenderscope_is_sole_mint_site()
			local source = loadServiceSource()
			-- Server-mint-only: the parameterized write `self._renderScope[player]
			-- = scope` (the mint) appears EXACTLY ONCE in the whole file -- only
			-- inside `_setRenderScope`. The fixed-value seed
			-- (`= "alive"`) and the teardown clear (`= nil`) are different literal
			-- strings and are not counted here.
			expect(countOccurrences(source, "self._renderScope[player] = scope")).to.equal(1)
		end
		it("test_setrenderscope_is_sole_mint_site", test_setrenderscope_is_sole_mint_site)

		local function test_setrenderscope_called_from_exactly_three_transition_sites()
			local source = loadServiceSource()
			-- Exactly 3 real call sites: S4 entry (_enterDeadRespawningRenderScope),
			-- T6 exit (_exitToAliveRenderScope), and S5 entry (EnterPostRunScope).
			-- Never inside a RunService.Heartbeat loop -- no polling.
			expect(countOccurrences(source, "self:_setRenderScope(")).to.equal(3)
		end
		it(
			"test_setrenderscope_called_from_exactly_three_transition_sites",
			test_setrenderscope_called_from_exactly_three_transition_sites
		)

		local function test_guard_is_literal_step_one_in_every_handler()
			local source = loadServiceSource()
			local handlerNames = {
				"_handleLanternToggleRequest",
				"_handleSprintToggleRequest",
				"_handlePlayerHeartbeat",
				"BeginGatherHold",
				"TryCommitGatherHold",
			}
			for _, name in handlerNames do
				local body = extractMethodBody(source, name)
				local guardIdx = body:find("self:_isEligibleForGameplayEvents%(player%)")
				expect(guardIdx).never.to.equal(nil)
				-- The guard call itself uses colon-method syntax ("self:_..."),
				-- never "self._" (dot-table-access) -- so the FIRST "self._"
				-- occurrence in the body, if any, must come from step 2+ (a
				-- rate-limit/player-state table read), never before the guard.
				local firstTableAccessIdx = body:find("self%._")
				if firstTableAccessIdx then
					expect((guardIdx :: number) < firstTableAccessIdx).to.equal(true)
				end
			end
		end
		it("test_guard_is_literal_step_one_in_every_handler", test_guard_is_literal_step_one_in_every_handler)

		local function test_s4_entry_zeroes_walkspeed_jumppower_jumpheight_character_not_destroyed()
			local source = loadServiceSource()
			local body = extractMethodBody(source, "_enterDeadRespawningRenderScope")
			expect(body:find("humanoid%.WalkSpeed = 0")).never.to.equal(nil)
			expect(body:find("humanoid%.JumpPower = 0")).never.to.equal(nil)
			expect(body:find("humanoid%.JumpHeight = 0")).never.to.equal(nil)
			expect(body:find(":Destroy%(%)")).to.equal(nil)

			-- Fix 5 (QA gap) static side: the humanoid-lookup guard must appear
			-- BEFORE the capture/zero writes, so a nil character is a no-op, not
			-- an index-into-nil error.
			local guardIdx = body:find("if humanoid then")
			expect(guardIdx).never.to.equal(nil)
			local firstWriteIdx = body:find("humanoid%.WalkSpeed = 0")
			expect((guardIdx :: number) < (firstWriteIdx :: number)).to.equal(true)
		end
		it(
			"test_s4_entry_zeroes_walkspeed_jumppower_jumpheight_character_not_destroyed",
			test_s4_entry_zeroes_walkspeed_jumppower_jumpheight_character_not_destroyed
		)

		local function test_s4_entry_captures_jump_state_before_zeroing()
			-- Code-review fix (engine Finding 3): the capture write must occur
			-- BEFORE the zero writes, or the capture would record the
			-- already-zeroed value.
			local source = loadServiceSource()
			local body = extractMethodBody(source, "_enterDeadRespawningRenderScope")
			local captureIdx = body:find("self%._capturedJumpState%[player%] = ")
			expect(captureIdx).never.to.equal(nil)
			local zeroJumpPowerIdx = body:find("humanoid%.JumpPower = 0")
			expect((captureIdx :: number) < (zeroJumpPowerIdx :: number)).to.equal(true)
		end
		it("test_s4_entry_captures_jump_state_before_zeroing", test_s4_entry_captures_jump_state_before_zeroing)

		local function test_t6_exit_restores_walkspeed_and_captured_jump_state()
			-- Code-review fix (engine Finding 3): no hardcoded jump-restore
			-- default anywhere in this file -- the restore reads FROM the
			-- captured table, never a named constant.
			local source = loadServiceSource()
			local body = extractMethodBody(source, "_exitToAliveRenderScope")
			expect(body:find("humanoid%.WalkSpeed = LocomotionStaminaLogic%.GetMoveSpeed%(")).never.to.equal(nil)
			expect(body:find("humanoid%.JumpPower = captured%.JumpPower")).never.to.equal(nil)
			expect(body:find("humanoid%.JumpHeight = captured%.JumpHeight")).never.to.equal(nil)
			expect(body:find("self%._capturedJumpState%[player%] = nil")).never.to.equal(nil)
			expect(source:find("DEFAULT_JUMP_POWER")).to.equal(nil)
		end
		it(
			"test_t6_exit_restores_walkspeed_and_captured_jump_state",
			test_t6_exit_restores_walkspeed_and_captured_jump_state
		)

		local function test_enterpostrunscope_exists_and_mints_post_run()
			local source = loadServiceSource()
			local body = extractMethodBody(source, "EnterPostRunScope")
			expect(body:find('self:_setRenderScope%(player, "post%-run"%)')).never.to.equal(nil)
		end
		it("test_enterpostrunscope_exists_and_mints_post_run", test_enterpostrunscope_exists_and_mints_post_run)

		local function test_isaliveandeligible_stub_fully_retired()
			-- pc-1/pc-2's stub name must not linger anywhere in the file --
			-- confirms the rename (not an alias) landed cleanly.
			local source = loadServiceSource()
			expect(source:find("_isAliveAndEligible")).to.equal(nil)
		end
		it("test_isaliveandeligible_stub_fully_retired", test_isaliveandeligible_stub_fully_retired)

		local function test_renderscope_and_capturedjumpstate_cleared_in_playerremoving_teardown()
			-- QA gap (fix 4): mirrors pc-5's own established teardown-pin
			-- pattern -- assert the clear lives INSIDE the real
			-- `Players.PlayerRemoving:Connect(...)` handler body, not merely
			-- somewhere in the file.
			local source = loadServiceSource()
			local startIdx = source:find("Players%.PlayerRemoving:Connect%(function%(player: Player%)")
			expect(startIdx).never.to.equal(nil)
			local endIdx = source:find("self%.Client%.RequestLanternToggle:Connect%(", startIdx :: number)
			expect(endIdx).never.to.equal(nil)
			local body = source:sub(startIdx :: number, endIdx :: number)
			expect(body:find("self%._renderScope%[player%] = nil")).never.to.equal(nil)
			expect(body:find("self%._capturedJumpState%[player%] = nil")).never.to.equal(nil)
		end
		it(
			"test_renderscope_and_capturedjumpstate_cleared_in_playerremoving_teardown",
			test_renderscope_and_capturedjumpstate_cleared_in_playerremoving_teardown
		)

		local function test_onrenderscopechanged_never_fired_via_fireall()
			-- Engine Finding 4: renderScope is per-client-owning-only (ADR-0012)
			-- -- it must never be broadcast via :FireAll (that would leak a
			-- squadmate's dead/post-run state to every client).
			local source = loadServiceSource()
			expect(source:find("OnRenderScopeChanged:FireAll%(")).to.equal(nil)
			expect(source:find("OnRenderScopeChanged:Fire%(")).never.to.equal(nil)
		end
		it("test_onrenderscopechanged_never_fired_via_fireall", test_onrenderscopechanged_never_fired_via_fireall)
	end)
end
