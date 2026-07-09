--!strict
-- PlayerControllerService
--
-- Implements: production/epics/player-controller/story-003-disturbance-emission-publisher.md
--             production/epics/player-controller/story-002-lantern-gather-gate.md
--             production/epics/player-controller/story-001-locomotion-sprint-stamina-authority.md
-- GDD: design/gdd/player-controller.md (C.2/C.2.5 sprint-state authority,
--      C.3.6 light-to-gather gate, C.7 tap-hold/proximity-gate, C.8/C.8.1/C.8.2
--      Disturbance System Contract (publisher), C.9 RemoteEvent surface, C.11
--      clock-injection seam contract, D.1-D.3 stamina formulas, D.4 pulse
--      emission magnitude, D.6 movement-delta sampling, E.D ghost-sprint guard)
-- ADR: docs/architecture/adr-0006-remoteevent-trust-boundary.md (canonical
--      6-step order every client-fired RemoteEvent handler follows)
--      docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md
--      (KnitInit builds / KnitStart connects; `Knit.GetService()` calls to
--      other services belong in KnitStart, per Rule 1's own Key Interfaces
--      sample -- this is PC's first cross-service call OUT, to
--      DisturbanceService)
--      docs/architecture/adr-0011-player-controller-sprint-stamina-authority.md
--      (S1/S2 locomotion state machine, stamina tick, ghost-sprint watchdog)
--      docs/architecture/adr-0003-locomotion-driver.md (HumanoidRootPart.Position
--      as the server-tracked position primitive this story's emission-position
--      reads depend on)
--
-- SCOPE NOTE (Story 003 -- DONE, this file): the Sprint/Light disturbance-
-- emission publisher. All magnitude/grace/cooldown/attenuation formulas live
-- in the dependency-free PlayerControllerEmissionPublisherLogic module -- this
-- file only owns the axis-transition hook call sites (piggybacking on Story
-- 001's `_applyLocomotionTransition` and Story 002's `_handleLanternToggleRequest`
-- accept path, WITHOUT editing either sibling module -- see
-- PlayerControllerEmissionPublisherLogic.luau's own header SCOPE NOTE for why
-- this module owns a fully self-contained per-axis state rather than reusing
-- `sprintPulseAnchorAt` / `t_lastGracePulse_light`), a new dedicated
-- RunService.Heartbeat connection driving the per-axis pulse cadence, the
-- real `HumanoidRootPart.Position` read, and the real
-- `DisturbanceService:Emit(...)` cross-service call. KNOWN GAP (honest, not
-- silently faked): `platform` is hardcoded to `"pc"` at the Emit call site --
-- GDD C.7's "most-recent input event type" platform classifier requires a
-- client->server signal that does not exist on any RemoteEvent surface yet;
-- wiring that up is a forward obligation, not this story's to invent. T5
-- (`Humanoid.Died`) death-reset is Story 004's scope -- `ResetGraceAnchorsOnDeath`
-- below is an unwired forward seam, per that story's own precedent
-- (`BeginGatherHold`).
--
-- SCOPE NOTE (Story 004 -- production/epics/player-controller/story-004-death-cost-
-- reconciliation-core.md): adds the death-cost reconciliation state machine --
-- `deathEventId` minting, the Pending/InFlight/Committed/Abandoned lifecycle (with
-- the load-bearing post-yield ownership re-check), the RESPAWN_DELAY=30s timer's
-- T6-detach decision, the RECONCILIATION_TICK_INTERVAL=5s tick + staleness sweep,
-- and the BindToClose -> Abandoned terminal transition. All pure state-machine
-- transitions live in the dependency-free PlayerControllerDeathReconciliationLogic
-- module (see its own header SCOPE NOTE for exactly what this story implements vs.
-- defers to Story 005/006/the RM epic); this file only owns: the real
-- `DisturbanceService:GetOnPlayerDiedSignal():Connect(...)` subscription (TR-pc-016
-- -- NEVER a direct `Humanoid.Died` connection, ED's H.39e sole-subscriber
-- monopoly), the real `self._deathReconciliationState` table (KnitInit, TR-pc-045),
-- the `self._requestSquadOxygenSpendFn` / `self._preYieldDeathSideEffectsFn` /
-- `self._onDeathCommitFn` injectable seams, a THIRD dedicated RunService.Heartbeat
-- connection driving the reconciliation tick + respawn-timer check, and the real
-- `game:BindToClose(...)` registration. ADR-0005 is THE LAW for this story's
-- architecture -- see that document's Decision section and Key Interfaces sample.
--
-- DESIGN DECISION (flagged, not silently assumed): `Players.PlayerRemoving` does
-- NOT clear `self._deathReconciliationState`'s per-player tables
-- (`deathInProgress`/`currentDeathRecord`/`deathStartedAt`) in this story. Path B
-- (`PlayerRemoving`-while-imminent) and its own teardown discipline are explicitly
-- Story 006's scope (see the GDD's own C.5.3 "Per-player teardown" bullet) --
-- clearing these tables here, ahead of that story, risks conflicting with its
-- eventual design (e.g. the GDD's own rule that an uncommitted record must NOT be
-- cleared on departure, only a `currentDeathRecord` *pointer* to an already-
-- `Committed` row). CONSEQUENCE (corrected by this story's code review -- the
-- original "bounded by squad size <= 4" claim here was WRONG): the retention
-- grows with the CUMULATIVE number of distinct players who disconnect mid-death
-- across the session's lifetime, not with concurrent squad size -- AND a departed
-- player's stale `currentDeathRecord` pointer makes TryCommitDispatch's H.39
-- orphan check treat their eventually-committed row as non-orphan, retaining it
-- in `reconcileRows` PERMANENTLY (no T6 ever fires for a departed player). Today
-- this window is nearly unreachable only because the RM stub is synchronous (no
-- yield between Pending and Committed for a player to disconnect inside); it
-- becomes live the moment RM lands a genuinely-yielding call OR during a
-- sustained-outage retry loop where a row sits Pending across many ticks. Story
-- 006's PlayerRemoving teardown must close BOTH the raw table entries AND this
-- orphan-detection interaction (tracked as TD-013 in docs/tech-debt-register.md).
--
-- SCOPE NOTE (Story 002 -- DONE): the lantern axis (S3a/S3b) and the
-- light-to-gather gate. `PlayerState.locomotion` (LanternLogic's own stub
-- field) is populated for real as of Story 001 below -- Story 002's own
-- logic still never reads or mutates it (H.9, H.25 remain true).
--
-- SCOPE NOTE (Story 001 -- DONE, this file): the locomotion axis (S1 Walk /
-- S2 Sprint), server-authoritative stamina drain/regen, and the
-- PlayerHeartbeat-staleness ghost-sprint guard. All state-machine rules live
-- in the dependency-free PlayerControllerLocomotionStaminaLogic module,
-- sibling to PlayerControllerLanternLogic -- this file only owns Player
-- identity, RemoteEvent wiring, Humanoid.WalkSpeed side effects, and
-- per-player table lifecycle for this axis. The canonical locomotion+stamina
-- state lives in `self._locomotionState[player]` (this story's OWN table,
-- per the approved architecture decision -- see story-001 implementation
-- session, 2026-07-06); the Knit wrapper mirrors the coarse "S1"/"S2" value
-- into `self._playerState[player].locomotion` (LanternLogic's shared stub
-- field) on every real transition, so that field is genuinely populated
-- without this file editing PlayerControllerLanternLogic.luau at all.
--
-- All actual state-machine logic lives in the dependency-free
-- PlayerControllerLanternLogic / PlayerControllerLocomotionStaminaLogic /
-- PlayerControllerEmissionPublisherLogic modules (zero Knit/Roblox-service
-- dependency, directly unit-testable under Lune without a vendored Knit
-- package). This file is a thin Knit wrapper: Player identity, RemoteEvent
-- wiring, per-player table lifecycle, Humanoid side effects, the real
-- DisturbanceService:Emit(...) call site, and the ADR-0006 6-step ordering
-- glue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local LanternLogic = require(script.Parent.PlayerControllerLanternLogic)
local LocomotionStaminaLogic = require(script.Parent.PlayerControllerLocomotionStaminaLogic)
local EmissionPublisherLogic = require(script.Parent.PlayerControllerEmissionPublisherLogic)
local DeathReconciliationLogic = require(script.Parent.PlayerControllerDeathReconciliationLogic)
local DeathSideEffectsLogic = require(script.Parent.PlayerControllerDeathSideEffectsLogic)

type PlayerState = LanternLogic.PlayerState
type TumblingWindow = LanternLogic.TumblingWindow
type LanternRateLimitRecord = LanternLogic.LanternRateLimitRecord
type PlayerLocomotionState = LocomotionStaminaLogic.PlayerLocomotionState
type SprintRateLimitRecord = LocomotionStaminaLogic.SprintRateLimitRecord
type PlayerEmissionState = EmissionPublisherLogic.PlayerEmissionState
type ReconcileRow = DeathReconciliationLogic.ReconcileRow
type DeathPayload = { deadPlayer: Player, deathTimestamp: number, predatorWasLockedAtDeath: boolean }
type DispatchOrigin = DeathSideEffectsLogic.DispatchOrigin
type PathOrigin = DeathSideEffectsLogic.PathOrigin
type DeathEffectFlags = { inputLocked: boolean?, spectatorCameraActive: boolean? }

-- Minimum interval between OnStaminaChanged pushes to a single client (<=5Hz
-- guardrail, ADR-0011 Decision #4 / GDD C.9: "<=5Hz", "never :FireAll").
local STAMINA_PUSH_MIN_INTERVAL = 1 / 5

local PlayerControllerService = Knit.CreateService({
	Name = "PlayerControllerService",
	Client = {
		RequestLanternToggle = Knit.CreateSignal(), -- C -> S (RemoteEvent-backed; ADR-0006 scope note: no RemoteFunctions in this project)
		OnLanternStateChanged = Knit.CreateSignal(), -- S -> C broadcast, per GDD C.9 table
		RequestSprintToggle = Knit.CreateSignal(), -- C -> S, {sprint: boolean}
		PlayerHeartbeat = Knit.CreateSignal(), -- C -> S, no payload, S2-only 1Hz liveness ping
		OnSprintStateChanged = Knit.CreateSignal(), -- S -> C broadcast, {playerId, sprinting}
		OnStaminaChanged = Knit.CreateSignal(), -- S -> owning C only, <=5Hz, display-only
		-- Story 005 (TR-pc-016/GDD C.9 trust-boundary RE#10 "Death confirmation" / the V/A
		-- "Death screen vignette <- OnPlayerDied" row): client-facing S->C broadcast fired at
		-- EVERY successful T5 commit -- both the initial dispatch (deathCause = the real Path
		-- A/B cause) AND a delayed reconciliation-recovery commit (deathCause =
		-- "reconciliation-recovery", per GDD C.5.3's own HUD forward-obligation text). This is
		-- the ONLY Story 005 signal added to this Client table -- the spectator-camera-activate
		-- and input-lock side effects ((e)/(f)) are deliberately kept server-internal state (see
		-- `self._deathEffectsState` below), matching the GDD's own round-24 SD-23 language
		-- ("emits only the server-side camera-state signal ... observed on the server") -- Story
		-- 007 owns turning those into real client-facing behavior.
		OnPlayerDied = Knit.CreateSignal(), -- S -> C broadcast, {deadPlayerUserId, deathCause}
	},
})

--- Exposed for direct testability without a live service instance (H.84).
PlayerControllerService.C3_6_CanArmGather = LanternLogic.C3_6_CanArmGather

--- C.11 clock-injection seam (production default). NEVER call
--- `workspace:GetServerTimeNow()` inline anywhere else in this file --
--- tests override this field directly with a fake closure. Reused verbatim
--- by Story 001's locomotion/stamina code paths below -- this is the SAME
--- seam, not a second one (this project has already hit the "second inline
--- clock call" bug 3+ times per the story's own implementation notes).
PlayerControllerService.getServerTime = function(): number
	return workspace:GetServerTimeNow()
end

--- Story 004 cross-epic stub (sanctioned by the sprint plan -- the Resource
--- Management epic has no stories yet, so `Knit.GetService("ResourceService")`
--- does not exist and calling it unconditionally would error at dispatch time).
--- Injectable function-value seam, mirrors DisturbanceService's own
--- `_captureDeathLockSnapshot` / AttributionArchiveLogic.DefaultIsEmissionLocked
--- precedent (KnitInit assigns `self._requestSquadOxygenSpendFn` a closure over
--- this method by default; tests and, eventually, the RM epic's own real
--- `Knit.GetService("ResourceService"):RequestSquadOxygenSpend(...)` call
--- override the field directly). CHOSEN SEMANTICS (decision, not a guess --
--- flagged per the story's own instruction): warn ONCE per server session (never
--- per-death, which could spam the log under a long session with many deaths)
--- and return success (`true`) UNCONDITIONALLY, so the reconciliation state
--- machine exercises its REAL Pending -> InFlight -> Committed path in
--- production-shaped flows, rather than being permanently stuck retrying a call
--- that can never succeed until the RM epic lands. The warn-once flag lives on
--- the service INSTANCE (`self._hasWarnedMissingResourceService`, KnitInit), not
--- the shared class table (code-review fix -- matches this file's own
--- per-instance `self._foo` convention everywhere else; a class-table flag was
--- the exact static-singleton-state shape gameplay-code.md forbids).
function PlayerControllerService:_defaultRequestSquadOxygenSpend(
	_userId: number,
	_amount: number,
	_reason: string,
	_deathEventId: string
): boolean
	if not self._hasWarnedMissingResourceService then
		self._hasWarnedMissingResourceService = true
		warn("PlayerControllerService: RequestSquadOxygenSpend stub in use.  TODO(RM epic): ResourceService does not exist yet; returning success unconditionally.")
	end
	return true
end

-- ============================================================================
-- KnitInit -- builds. Per ADR-0001 Rule 1, every table/accessor another
-- service (or this service's own KnitStart-time connections) might need
-- must be fully constructed here, never deferred to KnitStart.
-- ============================================================================

function PlayerControllerService:KnitInit(): ()
	-- H.88(b): hard-error at KnitInit time and halt server bootstrap if the
	-- DC-5 coupled-knob invariant is violated. The server bootstrap script
	-- (NOT this file -- out of this story's scope) MUST wrap Knit.Start()
	-- in a pcall/catch that calls game:Shutdown() on failure, per
	-- control-manifest.md's Foundation-layer rule: "Any KnitInit-time
	-- config-validation hard error MUST be paired with a server bootstrap
	-- catch handler that calls game:Shutdown()."
	local configOk, configErr = LanternLogic.ValidateConfig(
		LanternLogic.GATHER_PROXIMITY_RADIUS,
		LanternLogic.LANTERN_VISIBILITY_RADIUS
	)
	if not configOk then
		error(
			"PlayerControllerService config-validation FAILED: "
				.. tostring(configErr)
				.. " Server bootstrap MUST catch this KnitInit-time error and call game:Shutdown() -- that catch handler is NOT implemented in this file (out of this story's scope)."
		)
	end

	-- Story 003 (H.12a): the G.7 hierarchy invariant + STATIONARY_EMISSION_FACTOR
	-- range gate. Same KnitInit-time hard-error pattern as the LanternLogic
	-- config-validation call directly above.
	local emissionConfigOk, emissionConfigErr = EmissionPublisherLogic.ValidateConfig(
		EmissionPublisherLogic.MAGNITUDE_LIGHT_PULSE,
		EmissionPublisherLogic.MAGNITUDE_SPRINT_PULSE,
		EmissionPublisherLogic.SPRINT_HOLD_FLOOR,
		EmissionPublisherLogic.STATIONARY_EMISSION_FACTOR
	)
	if not emissionConfigOk then
		error(
			"PlayerControllerService config-validation FAILED: "
				.. tostring(emissionConfigErr)
				.. " Server bootstrap MUST catch this KnitInit-time error and call game:Shutdown() -- that catch handler is NOT implemented in this file (out of this story's scope)."
		)
	end

	self._playerState = {} :: { [Player]: PlayerState }
	self._globalEventCounts = {} :: { [Player]: TumblingWindow }
	self._lanternRateLimit = {} :: { [Player]: LanternRateLimitRecord }

	-- Story 001: locomotion axis (S1/S2) + stamina, this service's own
	-- per-player tables, separate from LanternLogic's PlayerState (see the
	-- header SCOPE NOTE for why).
	self._locomotionState = {} :: { [Player]: PlayerLocomotionState }
	self._sprintRateLimit = {} :: { [Player]: SprintRateLimitRecord }
	self._heartbeatRateLimit = {} :: { [Player]: TumblingWindow }
	self._lastStaminaPushAt = {} :: { [Player]: number }

	-- Story 003: the Sprint/Light emission-publisher state, this service's
	-- own per-player table -- fully self-contained, see
	-- PlayerControllerEmissionPublisherLogic.luau's header SCOPE NOTE for why
	-- it is not folded into `self._locomotionState` / `self._playerState`.
	self._emissionState = {} :: { [Player]: PlayerEmissionState }

	-- Story 004 (TR-pc-045): the death-cost reconciliation state machine's full
	-- bootstrap -- `reconcileRows`/`currentDeathRecord`/`deathInProgress`/
	-- `deathStartedAt` all start empty, per PlayerControllerDeathReconciliation
	-- Logic.NewReconciliationState()'s own construction contract. `lastTickTime`
	-- stays nil here (ShouldRunReconciliationTick tolerates that, H.40) -- KnitStart
	-- seeds it to the real clock once the service is actually starting (below).
	self._deathReconciliationState = DeathReconciliationLogic.NewReconciliationState()

	-- Story 004: RM epic cross-epic stub -- see _defaultRequestSquadOxygenSpend's
	-- own doc comment above for the chosen "warn once + return success" semantics
	-- and rationale. Flag + default closure both per-instance (code-review fix).
	self._hasWarnedMissingResourceService = false
	self._requestSquadOxygenSpendFn = function(userId: number, amount: number, reason: string, deathEventId: string): boolean
		return self:_defaultRequestSquadOxygenSpend(userId, amount, reason, deathEventId)
	end

	-- Story 005: cross-epic PredatorService stub (Predator AI epic does not exist yet --
	-- same "sanctioned by the sprint plan" rationale as _defaultRequestSquadOxygenSpend
	-- above). ONE shared warn-once flag covers all three PredatorService-bound seams
	-- (ReleasePredatorLock/OnPlayerS4Entered/OnPlayerT6Respawned) -- they are the same
	-- missing cross-epic dependency, so one warning is enough context for an operator
	-- reading the log; a second, independent flag covers the Crafting & Items epic's
	-- OnSquadMemberAliveChanged consumer (a different missing epic). Both flags are
	-- per-INSTANCE (code-review-established convention from Story 004 -- a class-table
	-- flag is the forbidden static-singleton shape gameplay-code.md disallows).
	self._hasWarnedMissingPredatorService = false
	self._hasWarnedMissingCraftingService = false
	self._hasWarnedMissingRespawnAnchor = false

	self._releasePredatorLockFn = function(userId: number): ()
		self:_defaultReleasePredatorLock(userId)
	end
	self._onPlayerS4EnteredFn = function(userId: number): ()
		self:_defaultOnPlayerS4Entered(userId)
	end
	self._onPlayerT6RespawnedFn = function(userId: number): ()
		self:_defaultOnPlayerT6Respawned(userId)
	end
	self._onSquadMemberAliveChangedFn = function(userId: number, isAlive: boolean): ()
		self:_defaultOnSquadMemberAliveChanged(userId, isAlive)
	end

	-- Story 005: respawn-anchor cross-epic stub. Level design owns "specific anchors"
	-- (GDD C.5.7 -- explicitly not this story's to author); no SpawnLocation/anchor
	-- registry exists in this codebase yet, so this defaults to the world origin with
	-- the SAME warn-once-per-instance shape as every other cross-epic stub in this file.
	self._getRespawnAnchorPositionFn = function(player: Player): Vector3
		return self:_defaultGetRespawnAnchorPosition(player)
	end

	-- Story 005: the actual Roblox respawn-placement call. Unlike the seams above, this
	-- one is NOT "the target epic doesn't exist yet" -- `Player:LoadCharacter()` is a
	-- real, long-stable Roblox API this codebase can call today. It is still an
	-- injectable seam (not an inline call) because (a) it is the one piece of this
	-- story's T6 side effects that touches a live Player/Character/HumanoidRootPart
	-- chain, which this project's Lune test harness cannot construct or exercise at all
	-- (see PlayerControllerDeathSideEffectsLogic.luau's own PLAYER IDENTITY precedent
	-- and this story's test file's own harness-disclosure header), and (b) its exact
	-- synchronous-completion contract (does `LoadCharacter()` guarantee `CharacterAdded`
	-- has already fired, and `HumanoidRootPart` already exists, by the time it returns?)
	-- is stated in Roblox's docs but flagged here for a live-Studio verification pass
	-- before this default is trusted in production -- see this story's own final report.
	self._respawnPlayerAtAnchorFn = function(player: Player, anchorPosition: Vector3): BasePart?
		return self:_defaultRespawnPlayerAtAnchor(player, anchorPosition)
	end

	-- Story 005: the client-facing OnPlayerDied broadcast (see the Client table
	-- declaration above). Injectable (not an inline `self.Client.OnPlayerDied:FireAll`
	-- call at the use site) so this story's FakePlayerControllerService test harness --
	-- which has no vendored Knit and therefore no real `self.Client` signals at all, per
	-- every prior PC story's own established harness precedent -- can override it with a
	-- recording mock instead of needing to fake an entire Knit Signal object.
	self._broadcastPlayerDiedFn = function(deadPlayerUserId: number, deathCause: string): ()
		self.Client.OnPlayerDied:FireAll(deadPlayerUserId, deathCause)
	end

	-- Story 005: per-player death-effect proxy state -- the (e)/(f) T5 side effects
	-- ((e) spectator-camera-activate, (f) client-input-lock), kept as plain
	-- server-internal table state per the GDD's own round-24 SD-23 "server-side ...
	-- observed on the server" language (see this file's Client-table comment above).
	-- Story 007 owns turning these into real client-facing behavior/rendering.
	self._deathEffectsState = {} :: { [Player]: DeathEffectFlags }

	-- Story 005 (GDD C.5.3 bootstrap enumeration -- "reconcileRows = {}, currentDeathRecord
	-- = {}, lastServerTrackedPosition = {}, ..." -- all bootstrapped at the SAME site).
	-- WRITE-SIDE SCOPE NOTE (flagged, not silently assumed): this story implements ONLY
	-- the bootstrap (empty table) and the T6 reset-to-anchor write this story's own
	-- Binding Rules require (`_completeRespawn` below). The GDD's own "each server
	-- Heartbeat, update lastServerTrackedPosition[player] = HumanoidRootPart.Position"
	-- continuous upkeep pass -- needed by Story 006's own Path-B `lastKnownPosition`
	-- nil-coalesce fallback -- is explicitly OUT of this story's scope (Path B does not
	-- exist yet) and is Story 006's obligation to wire.
	self._lastServerTrackedPosition = {} :: { [Player]: Vector3 }

	-- Story 005 (TR-pc-025): the REAL pre-yield/post-commit side-effect payloads,
	-- replacing Story 004's no-op ordering-hook-point defaults. dispatchOrigin/
	-- pathOrigin are threaded as plain call-scoped parameters (see
	-- PlayerControllerDeathSideEffectsLogic.luau's own ROW-SHAPE NEUTRALITY note) --
	-- neither is stored on `row` or in any per-player table.
	self._preYieldDeathSideEffectsFn = function(row: ReconcileRow, dispatchOrigin: DispatchOrigin, pathOrigin: PathOrigin?): ()
		self:_applyPreYieldDeathSideEffects(row, dispatchOrigin, pathOrigin)
	end
	self._onDeathCommitFn = function(row: ReconcileRow, dispatchOrigin: DispatchOrigin, player: Player?, pathOrigin: PathOrigin?): ()
		self:_applyPostCommitDeathSideEffects(row, dispatchOrigin, player, pathOrigin)
	end
end

-- ============================================================================
-- KnitStart -- connects. Engine-event connections (PlayerAdded/PlayerRemoving)
-- and RemoteEvent-backed signal connections happen here, matching
-- ADR-0010's Heartbeat-in-KnitStart precedent (connections belong in
-- KnitStart; construction belongs in KnitInit). This is PC's FIRST
-- RunService.Heartbeat connection (Story 001) -- separate from ED's own
-- field-update Heartbeat loop in DisturbanceService.
-- ============================================================================

function PlayerControllerService:KnitStart(): ()
	-- Story 003: PC's first cross-service call OUT to DisturbanceService.
	-- Safe here per ADR-0001 Rule 1's own Key Interfaces sample -- `Emit()`
	-- only touches DisturbanceService's KnitInit-constructed containers
	-- (`self._liveSources`/`self._spatialGrid`), never anything DisturbanceService's
	-- own KnitStart connects, so this call does not assume DisturbanceService's
	-- KnitStart has already run.
	self._disturbanceService = Knit.GetService("DisturbanceService")

	-- Story 004 (TR-pc-016): death moment acquired via `GetOnPlayerDiedSignal()` --
	-- NEVER a direct `Humanoid.Died:Connect` (ED's H.39e sole-subscriber monopoly,
	-- ADR-0004/ADR-0005). The payload is fired synchronously, same Luau frame as
	-- the real `Humanoid.Died`, per ED's own yield-free (5a)-(5c) dispatch.
	self._disturbanceService:GetOnPlayerDiedSignal():Connect(function(payload: DeathPayload)
		self:_onPlayerDied(payload)
	end)

	Players.PlayerAdded:Connect(function(player: Player)
		self:_initPlayerState(player)
	end)

	-- Defensive: cover the case where KnitStart runs after some players have
	-- already joined (e.g. a hot-reload in Studio).
	for _, player: Player in Players:GetPlayers() do
		self:_initPlayerState(player)
	end

	-- Required cleanup for every per-player table this service owns
	-- (ADR-0004/ADR-0006 leak-prevention precedent).
	Players.PlayerRemoving:Connect(function(player: Player)
		self._playerState[player] = nil
		self._globalEventCounts[player] = nil
		self._lanternRateLimit[player] = nil
		self._locomotionState[player] = nil
		self._sprintRateLimit[player] = nil
		self._heartbeatRateLimit[player] = nil
		self._lastStaminaPushAt[player] = nil
		self._emissionState[player] = nil

		-- Story 005: per-player death-effect proxy state + position cache. NOTE
		-- (disclosed, not silently assumed -- see this story's own final report):
		-- this does NOT clear `self._deathReconciliationState`'s own per-player
		-- tables (`deathInProgress`/`currentDeathRecord`/`deathStartedAt`) -- that
		-- remains Story 006's explicit obligation (TD-013). A post-commit hook
		-- firing AFTER this teardown (the H.75 mid-yield-departure case) simply
		-- recreates `self._deathEffectsState[player]` -- see
		-- `_applyPostCommitDeathSideEffects`'s own doc comment for why that is
		-- intentional, not a bug.
		self._deathEffectsState[player] = nil
		self._lastServerTrackedPosition[player] = nil
	end)

	self.Client.RequestLanternToggle:Connect(function(player: Player, raised: any)
		self:_handleLanternToggleRequest(player, raised)
	end)

	self.Client.RequestSprintToggle:Connect(function(player: Player, sprint: any)
		self:_handleSprintToggleRequest(player, sprint)
	end)

	self.Client.PlayerHeartbeat:Connect(function(player: Player)
		self:_handlePlayerHeartbeat(player)
	end)

	-- Story 001: the stamina drain/regen + ghost-sprint watchdog tick.
	-- `now` is computed ONCE at the top of the handler body (ADR-0011's own
	-- bugfix note -- never call the clock seam from inside the per-player
	-- loop).
	RunService.Heartbeat:Connect(function(dt: number)
		self:_onLocomotionHeartbeat(dt)
	end)

	-- Story 003: a SECOND, dedicated RunService.Heartbeat connection driving
	-- the Sprint/Light pulse cadence -- separate from the locomotion tick
	-- above (which only iterates `self._locomotionState`, not the emission
	-- table) and from ED's own field-update Heartbeat loop in
	-- DisturbanceService. `dt` is intentionally unused -- every emission
	-- timing decision below is an absolute-timestamp comparison through the
	-- C.11 `getServerTime()` seam, matching `_onLocomotionHeartbeat`'s own
	-- "now computed once at the top" discipline.
	RunService.Heartbeat:Connect(function(_dt: number)
		self:_onEmissionHeartbeat()
	end)

	-- Story 004: seeds the reconciliation tick's interval-gate anchor at server
	-- start (H.40) -- ShouldRunReconciliationTick also tolerates a nil seed
	-- defensively (belt-and-braces), but seeding here is the documented bootstrap
	-- per the GDD's own "first tick fires no earlier than
	-- RECONCILIATION_TICK_INTERVAL after server start" text.
	self._deathReconciliationState.lastTickTime = self.getServerTime()

	-- Story 004: a THIRD, dedicated RunService.Heartbeat connection driving the
	-- death-cost reconciliation tick + respawn-timer (T6) check -- separate from
	-- the locomotion tick and the emission-publisher tick above, and from ED's own
	-- field-update Heartbeat loop in DisturbanceService. `_dt` is intentionally
	-- unused -- every reconciliation timing decision is an absolute-timestamp
	-- comparison through the C.11 `getServerTime()` seam, matching this file's own
	-- established "now computed once at the top" discipline.
	RunService.Heartbeat:Connect(function(_dt: number)
		self:_onDeathReconciliationHeartbeat()
	end)

	-- Story 004 (H.42, MANUAL-DEVICE): BindToClose -> Abandoned. A real
	-- `game:BindToClose` firing cannot be exercised under the Lune test harness (no
	-- live engine shutdown event) -- `OnBindToClose` is a directly-callable public
	-- method so the transition itself is still unit-testable (see this story's own
	-- test file).
	game:BindToClose(function()
		self:OnBindToClose()
	end)
end

-- ============================================================================
-- Per-player state
-- ============================================================================

function PlayerControllerService:_initPlayerState(player: Player): ()
	if self._playerState[player] then
		return
	end
	self._playerState[player] = LanternLogic.NewPlayerState()

	-- Story 001: separate locomotion+stamina table (see header SCOPE NOTE),
	-- with the shared stub field mirrored to its real initial value.
	self._locomotionState[player] = LocomotionStaminaLogic.NewPlayerLocomotionState()
	self._playerState[player].locomotion = self._locomotionState[player].locomotion

	-- Story 003: separate emission-publisher table (see
	-- PlayerControllerEmissionPublisherLogic.luau's header SCOPE NOTE).
	self._emissionState[player] = EmissionPublisherLogic.NewPlayerEmissionState()

	self:_wireCharacterSetup(player)
end

--- Story 005 -- (c) "freeze stamina at current value" / the sprint+light pulse-timer
--- stop enforcement mechanism: rather than a one-shot snapshot, a currently-dead player
--- (an active `deathStartedAt` entry -- set at BeginDeathFlow, cleared at T6, per
--- PlayerControllerDeathReconciliationLogic's own contract) is skipped entirely by the
--- stamina-tick and emission-pulse Heartbeat loops below, so nothing can drain/regen
--- stamina or fire a phantom Sprint/Light pulse from a corpse for the whole S4 window --
--- a strictly stronger guarantee than a single frozen-value snapshot. Deliberately does
--- NOT use `_isAliveAndEligible` (that stub is ADR-0012's own forward seam, out of this
--- story's scope per its own doc comment) -- this reads the reconciliation state's own
--- `deathStartedAt` table directly, which already exists and is exactly "is this player
--- currently in S4" without needing ADR-0012 to land first.
function PlayerControllerService:_isPlayerDead(player: Player): boolean
	return self._deathReconciliationState.deathStartedAt[player] ~= nil
end

--- Reads the server-observed HumanoidRootPart.Position for a player, or nil
--- if the character/HumanoidRootPart isn't currently available (e.g. between
--- CharacterAdded events). NEVER a client-predicted position (ADR-0006 step
--- 5 parity, ADR-0003's server-tracked-position convention) -- this is the
--- ONLY position source Story 003's emission calls use.
function PlayerControllerService:_getServerPosition(player: Player): Vector3?
	local character = player.Character
	if not character then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end
	return rootPart.Position
end

--- Sets Humanoid.WalkSpeed server-side at spawn time, per the player's
--- current locomotion state. Uses :WaitForChild("Humanoid"), never
--- FindFirstChildOfClass immediately after CharacterAdded (ADR-0003's
--- spawn-timing race, control-manifest.md Foundation/Core rule).
function PlayerControllerService:_wireCharacterSetup(player: Player): ()
	local function onCharacterAdded(character: Model): ()
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		local locState = self._locomotionState[player]
		if locState then
			humanoid.WalkSpeed = LocomotionStaminaLogic.GetMoveSpeed(locState.locomotion)
		end
	end

	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

-- ============================================================================
-- ADR-0006 step 1 -- alive/state guard
-- ============================================================================

function PlayerControllerService:_isAliveAndEligible(player: Player): boolean
	-- STUB SEAM (approved architecture decision, Story 002 review
	-- 2026-07-06): Story 001 (Locomotion & Sprint-State Authority) and
	-- ADR-0012 (Death & Spectator State) are not implemented yet, so there
	-- is no real S4/S5 dead-state to check against. This always returns
	-- true until a future story replaces this BODY with a real check
	-- (e.g. against an ADR-0012-owned accessor or a field on
	-- self._playerState[player]). The CALL SITE (step 1 of the 6-step
	-- order) is already correctly wired -- only this function's
	-- implementation needs to change later.
	--
	-- NOTE (Story 001): RequestSprintToggle/PlayerHeartbeat below also call
	-- this same stub (two call sites now instead of one) -- the
	-- implementation is unchanged; still always true until ADR-0012 lands.
	return true
end

-- ============================================================================
-- RequestLanternToggle -- ADR-0006 canonical 6-step order
-- ============================================================================

--- Returns (accepted, reason?) for test/debug observability. Production
--- callers (the Client signal connection in KnitStart) ignore the return
--- value -- ADR-0006 mandates silent-drop-only, never an explicit
--- rejection response to the client.
function PlayerControllerService:_handleLanternToggleRequest(player: Player, raised: any): (boolean, string?)
	-- Step 1: Alive/state guard -- evaluated FIRST, before any other check
	-- touches state.
	if not self:_isAliveAndEligible(player) then
		return false, "not-alive-or-eligible"
	end

	local now = self.getServerTime()

	-- Step 2: per-event rate limit (5/s) + burst cap (8 per 2.0s). Silent
	-- drop, no state mutation (LanternLogic peeks both windows before
	-- committing either).
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

	-- Step 3: per-player global RemoteEvent budget (30/s, tumbling 1.0s
	-- window). Only reached for events that already passed step 2.
	local budgetRecord = self._globalEventCounts[player]
	if not budgetRecord or (now - budgetRecord.windowStart) >= 1.0 then
		budgetRecord = { count = 0, windowStart = now }
		self._globalEventCounts[player] = budgetRecord
	end
	if not LanternLogic.CheckGlobalBudget(budgetRecord, now) then
		return false, "global-budget-exceeded"
	end

	-- Step 4: payload shape validation.
	if typeof(raised) ~= "boolean" then
		return false, "invalid-payload-shape"
	end

	-- Step 5: server-side plausibility re-derivation. Intentional no-op for
	-- this event: {raised} carries no client-supplied id/position/distance
	-- claim to re-derive against (documented explicitly so this isn't
	-- mistaken for a skipped step).

	-- Step 6: deep/domain validation (this story's own logic) -- same-state
	-- debounce (H.74), accepted-path transition, and the H.89 mid-gather
	-- cancel side effect, all owned by LanternLogic.HandleLanternToggleDomain.
	local state = self._playerState[player]
	if not state then
		-- Request arrived before PlayerAdded-driven init completed. No
		-- state exists to mutate -- silent drop.
		return false, "no-player-state"
	end

	local accepted, reason = LanternLogic.HandleLanternToggleDomain(state, raised)
	if accepted then
		self.Client.OnLanternStateChanged:FireAll(player.UserId, raised)
		self:_applyLightAxisTransition(player, state, now)
	end
	return accepted, reason
end

-- ============================================================================
-- Story 003 -- Light-axis emission-publisher transition hook. Called from
-- `_handleLanternToggleRequest`'s own accept path immediately above --
-- `state.lantern` has ALREADY been mutated by
-- LanternLogic.HandleLanternToggleDomain by this point, so reading it here
-- tells us which direction the transition just went, without this file
-- editing PlayerControllerLanternLogic.luau itself.
-- ============================================================================

function PlayerControllerService:_applyLightAxisTransition(player: Player, state: PlayerState, now: number): ()
	local emissionState = self._emissionState[player]
	if not emissionState then
		return
	end

	if state.lantern == "S3b" then
		local position = self:_getServerPosition(player) or Vector3.new(0, 0, 0)
		EmissionPublisherLogic.OnAxisEntered(emissionState.light, position, now)
	else
		EmissionPublisherLogic.OnAxisExited(emissionState.light)
	end
end

-- ============================================================================
-- Gather-hold forward seam (H.89) -- see PlayerControllerLanternLogic's own
-- header comment for why this is internal methods rather than a new
-- RemoteEvent (approved architecture decision, Story 002 review 2026-07-06).
-- ============================================================================

--- Future call site: wherever tap-hold/proximity-gate arm is eventually
--- wired (a later PC story, or the RN epic's arm signal). Enforces
--- C3_6_CanArmGather at arm time.
function PlayerControllerService:BeginGatherHold(player: Player, nodeId: string, isDarkZone: boolean): boolean
	local state = self._playerState[player]
	if not state then
		return false
	end
	return LanternLogic.BeginGatherHold(state, nodeId, isDarkZone, self.getServerTime())
end

--- Future call site: the RequestGather handler's own step 5/6 guard (RN
--- epic). Rejects if the record was cancelled, never armed, or the nodeId
--- doesn't match.
function PlayerControllerService:TryCommitGatherHold(player: Player, nodeId: string): boolean
	local state = self._playerState[player]
	if not state then
		return false
	end
	return LanternLogic.TryCommitGatherHold(state, nodeId)
end

-- ============================================================================
-- Story 001 -- RequestSprintToggle -- ADR-0006 canonical 6-step order
-- ============================================================================

--- Returns (accepted, reason?) for test/debug observability. Production
--- callers (the Client signal connection in KnitStart) ignore the return
--- value -- ADR-0006 mandates silent-drop-only, never an explicit
--- rejection response to the client.
function PlayerControllerService:_handleSprintToggleRequest(player: Player, sprint: any): (boolean, string?)
	-- Step 1: Alive/state guard -- evaluated FIRST, before any other check
	-- touches state.
	if not self:_isAliveAndEligible(player) then
		return false, "not-alive-or-eligible"
	end

	local now = self.getServerTime()

	-- Step 2: per-event rate limit (10/s) + burst cap (15 per 2.0s). Silent
	-- drop, no state mutation.
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

	-- Step 3: per-player global RemoteEvent budget (30/s, tumbling 1.0s
	-- window). REUSES the SAME self._globalEventCounts table Lantern's
	-- handler uses -- this budget is meant to be one shared counter across
	-- ALL of a player's RemoteEvents, not a second independent one per
	-- event (ADR-0006's own point: defends against spreading fire-rate
	-- across multiple low-limit events).
	local budgetRecord = self._globalEventCounts[player]
	if not budgetRecord or (now - budgetRecord.windowStart) >= 1.0 then
		budgetRecord = { count = 0, windowStart = now }
		self._globalEventCounts[player] = budgetRecord
	end
	if not LanternLogic.CheckGlobalBudget(budgetRecord, now) then
		return false, "global-budget-exceeded"
	end

	-- Step 4: payload shape validation.
	if typeof(sprint) ~= "boolean" then
		return false, "invalid-payload-shape"
	end

	-- Step 5: server-side plausibility re-derivation. Intentional no-op for
	-- this event: {sprint} carries no client-supplied id/position/distance
	-- claim to re-derive against.

	-- Step 6: deep/domain validation (this story's own logic) -- same-state
	-- debounce (both directions), stamina>0 gate on sprint-entry, always-honor
	-- on sprint-exit, all owned by LocomotionStaminaLogic.HandleSprintToggleDomain.
	local locState = self._locomotionState[player]
	if not locState then
		-- Request arrived before PlayerAdded-driven init completed. No
		-- state exists to mutate -- silent drop.
		return false, "no-player-state"
	end

	local accepted, reason = LocomotionStaminaLogic.HandleSprintToggleDomain(locState, sprint, now)
	if accepted then
		self:_applyLocomotionTransition(player, locState, now)
	end
	return accepted, reason
end

-- ============================================================================
-- Story 001 -- PlayerHeartbeat -- ADR-0006 canonical 6-step order
-- ============================================================================

--- Returns whether the heartbeat was accepted, for test/debug
--- observability. Production callers ignore the return value.
function PlayerControllerService:_handlePlayerHeartbeat(player: Player): boolean
	-- Step 1: alive/state guard.
	if not self:_isAliveAndEligible(player) then
		return false
	end

	local now = self.getServerTime()

	-- Step 2: per-event rate limit (HEARTBEAT_SEND_RATE = 1Hz). Excess
	-- dropped silently, per GDD C.9's "drop-first-write ordering (normative,
	-- I1)" -- evaluated BEFORE lastHeartbeatAt is ever written.
	local rateRecord = self._heartbeatRateLimit[player]
	if not rateRecord then
		rateRecord = { count = 0, windowStart = now }
		self._heartbeatRateLimit[player] = rateRecord
	end
	if not LocomotionStaminaLogic.CheckHeartbeatRateLimit(rateRecord, now) then
		return false
	end

	-- Step 3: per-player global RemoteEvent budget -- same shared table as
	-- every other event this service handles.
	local budgetRecord = self._globalEventCounts[player]
	if not budgetRecord or (now - budgetRecord.windowStart) >= 1.0 then
		budgetRecord = { count = 0, windowStart = now }
		self._globalEventCounts[player] = budgetRecord
	end
	if not LanternLogic.CheckGlobalBudget(budgetRecord, now) then
		return false
	end

	-- Step 4/5: no-op -- PlayerHeartbeat carries no payload to validate or
	-- re-derive against.

	-- Step 6: deep/domain validation (H.33c) -- S2-only; a heartbeat
	-- received while in S1 is silently dropped, no timestamp update.
	local locState = self._locomotionState[player]
	if not locState then
		return false
	end
	return LocomotionStaminaLogic.HandlePlayerHeartbeatDomain(locState, now)
end

-- ============================================================================
-- Story 001 -- stamina drain/regen + ghost-sprint watchdog tick
-- ============================================================================

function PlayerControllerService:_onLocomotionHeartbeat(dt: number): ()
	-- Computed ONCE at the top of the loop body -- ADR-0011's own bugfix
	-- note: never call the clock seam from inside the per-player loop or a
	-- sibling branch.
	local now = self.getServerTime()

	for player: Player, locState: PlayerLocomotionState in self._locomotionState do
		-- Story 005 (c): a currently-dead player (S4) is skipped entirely -- stamina
		-- stays frozen at whatever value it held at T5, and no forced-transition/
		-- broadcast side effect can fire from a corpse. See `_isPlayerDead`'s own
		-- doc comment.
		if self:_isPlayerDead(player) then
			continue
		end
		local forced = LocomotionStaminaLogic.TickStamina(locState, dt, now)
		if forced then
			self:_applyLocomotionTransition(player, locState, now)
		end
		self:_maybePushStaminaChanged(player, locState, now)
	end
end

--- Applies the Humanoid.WalkSpeed side effect, mirrors the shared
--- PlayerState.locomotion stub field (Story 001 owns this write), broadcasts
--- OnSprintStateChanged, and (Story 003) drives the Sprint-axis
--- emission-publisher transition hook. Called on every REAL transition --
--- accepted toggles and forced reverts alike. `now` is threaded through from
--- the caller (already computed via the C.11 seam at the top of that
--- caller's own handler body) -- never a second inline clock read here.
function PlayerControllerService:_applyLocomotionTransition(player: Player, locState: PlayerLocomotionState, now: number): ()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = LocomotionStaminaLogic.GetMoveSpeed(locState.locomotion)
	end

	local playerState = self._playerState[player]
	if playerState then
		playerState.locomotion = locState.locomotion
	end

	self.Client.OnSprintStateChanged:FireAll(player.UserId, locState.locomotion == "S2")

	local emissionState = self._emissionState[player]
	if emissionState then
		if locState.locomotion == "S2" then
			local position = self:_getServerPosition(player) or Vector3.new(0, 0, 0)
			EmissionPublisherLogic.OnAxisEntered(emissionState.sprint, position, now)
		else
			EmissionPublisherLogic.OnAxisExited(emissionState.sprint)
		end
	end
end

--- OnStaminaChanged push, rate-limited to <=5Hz, owning client only (GDD
--- C.9 / ADR-0011 Decision #4). Display-only -- the client never gates its
--- own input on this value.
function PlayerControllerService:_maybePushStaminaChanged(player: Player, locState: PlayerLocomotionState, now: number): ()
	local lastPush = self._lastStaminaPushAt[player]
	if lastPush and (now - lastPush) < STAMINA_PUSH_MIN_INTERVAL then
		return
	end
	self._lastStaminaPushAt[player] = now
	self.Client.OnStaminaChanged:Fire(player, locState.stamina / LocomotionStaminaLogic.STAMINA_MAX)
end

-- ============================================================================
-- Story 003 -- Sprint/Light disturbance-emission publisher tick. All
-- magnitude/grace/cooldown/attenuation math lives in
-- PlayerControllerEmissionPublisherLogic (see that module's own D.4 doc
-- comment) -- this loop only supplies the real inputs (`now`, the server-
-- observed position) and performs the real `DisturbanceService:Emit(...)`
-- call, per GDD C.8's normative contract.
-- ============================================================================

--- KNOWN GAP (honest, not silently faked -- see this file's header SCOPE
--- NOTE): `platform` is hardcoded to `"pc"` below. GDD C.7's "most-recent
--- input event type" platform classifier needs a client->server signal this
--- codebase does not have yet on any RemoteEvent surface -- until it exists,
--- `EmissionPublisherLogic`'s mobile-drift floor is correct and fully tested,
--- but this call site can never actually exercise the "touch" branch in a
--- live server. Not this story's obligation to invent that signal.
function PlayerControllerService:_onEmissionHeartbeat(): ()
	local now = self.getServerTime()

	for player: Player, emissionState: PlayerEmissionState in self._emissionState do
		-- Story 005 (b, phantom-emission closure): a currently-dead player's axes were
		-- already force-closed at T5 (see `_applyPostCommitDeathSideEffects`'s (a)/(b)
		-- handling) -- this skip is belt-and-braces, ensuring no pulse can EVER fire from
		-- a corpse regardless of hook-ordering, mirroring the SAME `_isPlayerDead` guard
		-- the locomotion tick above uses.
		if self:_isPlayerDead(player) then
			continue
		end

		local position = self:_getServerPosition(player)
		if not position then
			continue -- no live character/HumanoidRootPart this tick -- skip, do not error
		end

		local sprintMagnitude = EmissionPublisherLogic.EvaluatePulse(emissionState.sprint, "Sprint", now, position, "pc")
		if sprintMagnitude then
			self._disturbanceService:Emit("Sprint", position, sprintMagnitude, player.UserId, {})
		end

		local lightMagnitude = EmissionPublisherLogic.EvaluatePulse(emissionState.light, "Light", now, position, "pc")
		if lightMagnitude then
			self._disturbanceService:Emit("Light", position, lightMagnitude, player.UserId, {})
		end
	end
end

-- ============================================================================
-- H.11d -- death-reset forward seam (Story 004 will call this once T5 /
-- Humanoid.Died handling exists -- matches the BeginGatherHold precedent,
-- Story 002 review 2026-07-06).
-- ============================================================================

--- Resets both axes' grace-cooldown anchors for `player`. Unwired -- no call
--- site in this file invokes it yet, per this story's own Out-of-Scope
--- clause (T5 death handling is Story 004's scope).
function PlayerControllerService:ResetGraceAnchorsOnDeath(player: Player): ()
	local emissionState = self._emissionState[player]
	if not emissionState then
		return
	end
	EmissionPublisherLogic.ResetGraceAnchorsOnDeath(emissionState)
end

-- ============================================================================
-- Story 004 -- death-cost reconciliation state machine. All pure transitions live
-- in PlayerControllerDeathReconciliationLogic (see its own header SCOPE NOTE); this
-- section is the thin Knit-wrapper glue: the real `GetOnPlayerDiedSignal()` handler,
-- the real yield-capable `RequestSquadOxygenSpend` dispatch (via the injectable
-- `self._requestSquadOxygenSpendFn` seam, `pcall`-wrapped per ADR-0005's binding
-- yield-discipline requirement -- see that ADR's own Key Interfaces sample comment
-- for why a genuinely-async Promise-returning RM call would need to be `:await()`ed
-- INSIDE this `pcall`, never bare-called-and-checked), and the reconciliation
-- tick/respawn-timer Heartbeat orchestration.
-- ============================================================================

--- TR-pc-016 entry point: fired by `GetOnPlayerDiedSignal()`, never a direct
--- `Humanoid.Died` connection. `now` is read ONCE here via the C.11 seam and
--- threaded through -- never a second inline clock read anywhere below. This
--- is Path A ONLY -- see `_beginDeathFlow`'s own doc comment for the
--- Path-A/B discriminator seam Story 006 will use.
function PlayerControllerService:_onPlayerDied(payload: DeathPayload): ()
	local now = self.getServerTime()
	self:_beginDeathFlow(payload.deadPlayer, now, "A")
end

--- Resolves-or-refuses the death (TR-pc-017 idempotent guard) and, on a fresh mint,
--- immediately begins the dispatch as an "initial" dispatch. Exposed as its own
--- method (rather than folded into `_onPlayerDied`) so a future story's own
--- death-adjacent call site can invoke the identical resolve-or-mint step without
--- duplicating this logic -- mirrors this file's own `BeginGatherHold`/
--- `TryCommitGatherHold` forward-seam precedent. Returns (row, reason) for
--- test/debug observability, matching this file's `_handle*Request` convention.
---
--- PATH-A/B DISCRIMINATOR SEAM (Story 005 design decision, flagged per the story's
--- own instruction -- this is the entry point Story 006's Path B
--- (`PlayerRemoving`-while-imminent) is expected to call): `pathOrigin` is a
--- REQUIRED parameter (not defaulted internally), so every current and future call
--- site must explicitly decide which path it represents rather than silently
--- inheriting a stale default. Story 006 can call
--- `self:_beginDeathFlow(player, now, "B")` directly, from its own
--- `Players.PlayerRemoving`-driven predicate handler, WITHOUT this method or
--- `_beginAndDispatch`/`_applyPreYieldDeathSideEffects`/
--- `_applyPostCommitDeathSideEffects` below needing to change at all -- `pathOrigin`
--- already threads all the way through to the side-effect selection functions in
--- PlayerControllerDeathSideEffectsLogic.luau, which already handle `"B"` (Path-B
--- negative: no `OnPlayerS4Entered`, no (d)/(e)/(f), `deathCause` resolves to
--- `"disconnect-while-damaged"`).
function PlayerControllerService:_beginDeathFlow(player: Player, now: number, pathOrigin: PathOrigin): (ReconcileRow?, string?)
	local row, reason = DeathReconciliationLogic.BeginDeathFlow(self._deathReconciliationState, player, player.UserId, now)
	if row then
		self:_beginAndDispatch(row, now, "initial", player, pathOrigin)
	end
	return row, reason
end

--- ADR-0005 step 2 (`Pending -> InFlight`, synchronous, before any yield) + the
--- TR-pc-025 pre-yield ordering hook point, THEN the yield-capable remainder
--- `task.spawn`'d off the caller (both the initial death-flow call site and the
--- reconciliation-tick call site below share this one function, so neither
--- duplicates the pre-yield-hook-error-guard logic).
---
--- DISPATCH-ORIGIN DISCRIMINATOR (Story 005, GDD C.5.3 round-20 SD-19-B2 / H.75):
--- `dispatchOrigin` is a dispatch-scoped parameter, NOT stored on `row` or in any
--- per-player table (PlayerControllerDeathReconciliationLogic.luau's ADR-0005-FROZEN
--- `ReconcileRow` shape needed zero changes for this story) -- it is simply closed
--- over by the `task.spawn`'d closure below, so it stays "initial" for the ENTIRE
--- lifetime of an initial dispatch's coroutine even if the player departs mid-yield
--- (the H.75 orphan case) -- the side-effect SET this dispatch eventually applies is
--- selected from THIS captured value, never re-derived from live-pointer state at
--- commit time. `player`/`pathOrigin` are `nil` for a reconciliation-tick dispatch
--- (see `_runReconciliationTick` below) -- pathOrigin is only ever read when
--- `dispatchOrigin == "initial"` (see PlayerControllerDeathSideEffectsLogic's own
--- `ResolveDeathCause` doc comment).
function PlayerControllerService:_beginAndDispatch(
	row: ReconcileRow,
	now: number,
	dispatchOrigin: DispatchOrigin,
	player: Player?,
	pathOrigin: PathOrigin?
): ()
	DeathReconciliationLogic.BeginDispatch(row, now)

	-- TR-pc-025: fires synchronously, in the SAME pre-yield span as the transition
	-- immediately above, before the yield-capable oxygen-spend call below. An error
	-- here is still "an error thrown while state == InFlight" (H.64) -- rolled back
	-- to Pending, exactly like a failed oxygen-spend attempt.
	local hookOk, hookErr = pcall(function()
		self._preYieldDeathSideEffectsFn(row, dispatchOrigin, pathOrigin)
	end)
	if not hookOk then
		DeathReconciliationLogic.RollbackIfStillInFlight(row)
		warn(
			("PlayerControllerService: pre-yield death side-effect hook errored for deathEventId=%s (rolled back to Pending): %s"):format(
				row.deathEventId,
				tostring(hookErr)
			)
		)
		return
	end

	task.spawn(function()
		self:_completeDispatch(row, dispatchOrigin, player, pathOrigin)
	end)
end

--- The yield-capable remainder: dispatch `RequestSquadOxygenSpend`, then resolve
--- via the load-bearing post-yield ownership re-check (ADR-0005 step 5 / H.54).
--- BINDING REQUIREMENT (ADR-0005): if `self._requestSquadOxygenSpendFn` is ever
--- made genuinely async via a Knit Promise, it must be `:await()`/`:expect()`ed
--- INSIDE this `pcall`, never bare-called-and-checked -- the current stub/mock is
--- synchronous, so this `pcall` has no real yield point to protect yet, but the
--- call site is already shaped correctly for when one exists.
function PlayerControllerService:_completeDispatch(
	row: ReconcileRow,
	dispatchOrigin: DispatchOrigin,
	player: Player?,
	pathOrigin: PathOrigin?
): ()
	local ok, result = pcall(function()
		return self._requestSquadOxygenSpendFn(
			row.userId,
			DeathReconciliationLogic.DEATH_OXYGEN_SPEND_AMOUNT,
			DeathReconciliationLogic.DEATH_OXYGEN_SPEND_REASON,
			row.deathEventId
		)
	end)

	if ok then
		local committed, _removedAsOrphan = DeathReconciliationLogic.TryCommitDispatch(self._deathReconciliationState, row)
		if committed then
			-- Post-commit hook (TR-pc-025, Story 005's real payload). H.64b: an error
			-- thrown HERE does NOT roll back -- caught, logged, stays Committed, never
			-- re-charged. `_removedAsOrphan` is deliberately NOT threaded into the hook
			-- -- see PlayerControllerDeathSideEffectsLogic.luau's own header SCOPE NOTE
			-- for why side-effect selection is independent of retain-vs-remove.
			local hookOk, hookErr = pcall(function()
				self._onDeathCommitFn(row, dispatchOrigin, player, pathOrigin)
			end)
			if not hookOk then
				warn(
					("PlayerControllerService: post-commit death hook errored for deathEventId=%s (row stays Committed, not re-charged): %s"):format(
						row.deathEventId,
						tostring(hookErr)
					)
				)
			end
		else
			warn(
				("PlayerControllerService: discarding late RequestSquadOxygenSpend success for deathEventId=%s (row re-armed mid-yield; re-dispatched attempt owns the outcome)"):format(
					row.deathEventId
				)
			)
		end
	else
		DeathReconciliationLogic.RollbackIfStillInFlight(row)
		warn(
			("PlayerControllerService: RequestSquadOxygenSpend failed for deathEventId=%s (userId=%d): %s"):format(
				row.deathEventId,
				row.userId,
				tostring(result)
			)
		)
	end
end

--- Composed Heartbeat handler (Story 004's third dedicated Heartbeat connection,
--- KnitStart above): runs the reconciliation tick, then the respawn-timer (T6)
--- check. `now` is computed ONCE here, matching this file's own established
--- "now computed once at the top" discipline.
function PlayerControllerService:_onDeathReconciliationHeartbeat(): ()
	local now = self.getServerTime()
	self:_runReconciliationTick(now)
	self:_checkRespawnTimers(now)
end

--- TR-pc-021: the RECONCILIATION_TICK_INTERVAL=5s tick -- interval gate, staleness
--- sweep, then the tick-scan's own synchronous-transition-then-task.spawn dispatch
--- for every currently-Pending row.
function PlayerControllerService:_runReconciliationTick(now: number): ()
	local reconState = self._deathReconciliationState

	if
		not DeathReconciliationLogic.ShouldRunReconciliationTick(
			reconState.lastTickTime,
			now,
			DeathReconciliationLogic.RECONCILIATION_TICK_INTERVAL
		)
	then
		return
	end
	reconState.lastTickTime = now

	local reArmed = DeathReconciliationLogic.RunStalenessSweep(
		reconState.reconcileRows,
		now,
		DeathReconciliationLogic.STALENESS_SWEEP_THRESHOLD
	)
	for _, row in reArmed do
		warn(("PlayerControllerService: staleness sweep re-armed deathEventId=%s to Pending (stale InFlight row)"):format(row.deathEventId))
	end

	-- Story 005: dispatchOrigin="reconciliation", pathOrigin=nil -- a tick dispatch's
	-- side-effect SET is selected purely from dispatchOrigin (H.70's player-removal-
	-- safe (a)/(b)/(g) subset), independent of which path originally created the row.
	-- `player` IS resolved (via the real `Players:GetPlayerByUserId`, a standard,
	-- long-stable Roblox API -- NOT a live-pointer lookup into
	-- `self._deathReconciliationState`) so (a)/(b) CAN touch this player's CURRENT
	-- per-player state if -- and only if -- `_applyPostCommitDeathSideEffects`'s own
	-- `isSameLife` guard confirms this row is still their live tracked death (see
	-- that method's own doc comment for why a stale reconciliation success must
	-- never stomp a different, already-current life's state).
	local eligibleRows = DeathReconciliationLogic.ScanPendingRows(reconState.reconcileRows)
	for _, row in eligibleRows do
		local player = Players:GetPlayerByUserId(row.userId)
		self:_beginAndDispatch(row, now, "reconciliation", player, nil)
	end
end

--- T6 (respawn): the reconciliation-state-machine slice (record-pointer detach +
--- idempotent-guard clear, pc-4's own `TryRespawn`) EXTENDED with this story's real
--- respawn payload (`_completeRespawn` below) -- per this story's own instruction,
--- extends this method rather than duplicating pc-4's respawn-timer-elapsed check.
function PlayerControllerService:_checkRespawnTimers(now: number): ()
	local reconState = self._deathReconciliationState

	-- Snapshot the tracked-player key list first -- TryRespawn mutates
	-- `deathStartedAt` (clears the entry on respawn), and mutating a table while
	-- iterating it directly is unsafe in Luau (matches this file's own
	-- `_runStreamingChunkPushPass`-equivalent precedent in DisturbanceService.luau).
	local trackedPlayers: { Player } = {}
	for player in reconState.deathStartedAt do
		table.insert(trackedPlayers, player)
	end

	for _, player in trackedPlayers do
		local respawned = DeathReconciliationLogic.TryRespawn(reconState, player, now, DeathReconciliationLogic.RESPAWN_DELAY)
		if respawned then
			self:_completeRespawn(player, now)
		end
	end
end

--- H.42 (MANUAL-DEVICE): `BindToClose -> Abandoned`. Registered against the real
--- `game:BindToClose(...)` in KnitStart above; exposed as its own public method so
--- it is directly callable/unit-testable without a live engine shutdown event.
function PlayerControllerService:OnBindToClose(): ()
	local abandoned = DeathReconciliationLogic.RunBindToClose(self._deathReconciliationState.reconcileRows)
	for _, row in abandoned do
		warn(
			("PlayerControllerService: BindToClose abandoned deathEventId=%s (state was Pending/InFlight; oxygen decrement not applied this session)"):format(
				row.deathEventId
			)
		)
	end
end

-- ============================================================================
-- Story 005 -- Death/Respawn Side-Effects & Cross-Service Signals (T5/T6). All
-- side-effect SELECTION logic (which of (a)-(i) fire, and the deathCause string)
-- lives in the dependency-free PlayerControllerDeathSideEffectsLogic module; this
-- section is the thin Knit-wrapper glue: applying those selections to this file's
-- real per-player state tables, the cross-epic seams (PredatorService/Crafting do
-- NOT exist yet -- TR-pc-041/042/043), and the real T6 respawn-placement call.
-- ============================================================================

--- TR-pc-025 pre-yield hook target (see KnitInit's `self._preYieldDeathSideEffectsFn`
--- wiring). Applies (g)/(h)/(i) -- all three are userId-keyed cross-service seam
--- calls, never a live Player-instance dereference, so this needs no `player`
--- parameter at all.
function PlayerControllerService:_applyPreYieldDeathSideEffects(row: ReconcileRow, dispatchOrigin: DispatchOrigin, pathOrigin: PathOrigin?): ()
	if DeathSideEffectsLogic.ShouldFireReleasePredatorLockPreYield(dispatchOrigin) then
		self._releasePredatorLockFn(row.userId)
	end
	if DeathSideEffectsLogic.ShouldFireOnPlayerS4EnteredPreYield(dispatchOrigin, pathOrigin) then
		self._onPlayerS4EnteredFn(row.userId)
	end
	if DeathSideEffectsLogic.ShouldFireAliveEdgeFalsePreYield(dispatchOrigin) then
		self._onSquadMemberAliveChangedFn(row.userId, false)
	end
end

--- TR-pc-025 post-commit hook target (see KnitInit's `self._onDeathCommitFn` wiring).
--- Applies the OnPlayerDied broadcast + (a)-(g) per
--- `DeathSideEffectsLogic.SelectPostCommitSideEffects`'s own selection.
---
--- `isSameLife` SAFETY GATE (Story 005 design decision, flagged -- not in the GDD's
--- own prose, which does not anticipate this specific interaction): a RECONCILIATION
--- dispatch's (a)/(b) live-per-player-table touches are gated on this row still being
--- the player's CURRENTLY tracked death (`currentDeathRecord[player] == row.
--- deathEventId`). Without this gate, a reconciliation success that resolves AFTER
--- this player has already respawned to (or died again on) a DIFFERENT life would
--- incorrectly force-reset that unrelated, currently-active life's sprint/lantern
--- state. An INITIAL dispatch is NEVER gated this way -- H.75 requires the full
--- initial side-effect set to fire regardless of live-pointer status (dispatchOrigin
--- alone selects the set; see PlayerControllerDeathSideEffectsLogic.luau's own header
--- SCOPE NOTE for the two-axes-are-independent framing this gate deliberately keeps
--- narrow to (a)/(b) only, not a blanket orphan check).
function PlayerControllerService:_applyPostCommitDeathSideEffects(
	row: ReconcileRow,
	dispatchOrigin: DispatchOrigin,
	player: Player?,
	pathOrigin: PathOrigin?
): ()
	local effects = DeathSideEffectsLogic.SelectPostCommitSideEffects(dispatchOrigin, pathOrigin)

	-- Broadcast fires on EVERY successful commit -- initial with the real Path A/B
	-- deathCause, reconciliation with "reconciliation-recovery" (GDD C.5.3's own HUD
	-- forward-obligation text).
	self._broadcastPlayerDiedFn(row.userId, effects.deathCause)

	local touchLiveState = true
	if dispatchOrigin == "reconciliation" and player then
		touchLiveState = self._deathReconciliationState.currentDeathRecord[player] == row.deathEventId
	end

	if effects.sprintReset and player and touchLiveState then
		local locState = self._locomotionState[player]
		if locState and locState.locomotion == "S2" then
			LocomotionStaminaLogic.ForceRevertToS1(locState, self.getServerTime())
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

	-- (c) freeze stamina at current value: no explicit action here -- enforced by
	-- `_isPlayerDead`'s Heartbeat-loop skip (see `_onLocomotionHeartbeat`). Listed
	-- here only so `effects.freezeStamina` has an AC-traceable read site.
	local _ = effects.freezeStamina

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

--- Sets a single field on `self._deathEffectsState[player]`, creating the entry if
--- absent. Deliberately UNCONDITIONAL on any other per-player table's existence
--- (never nil-guarded against `_locomotionState[player]`/`_emissionState[player]`) --
--- these two flags are server-observable proxies in their own right (GDD round-24
--- SD-23: "server-side ... observed on the server"), so they must remain writable
--- (and therefore H.75-observable) even for a mid-yield-orphaned initial dispatch
--- whose OTHER per-player tables may already have been cleared by
--- `Players.PlayerRemoving` (see KnitStart's own teardown connection).
function PlayerControllerService:_setDeathEffectFlag(player: Player, field: "inputLocked" | "spectatorCameraActive", value: boolean): ()
	local flags = self._deathEffectsState[player]
	if not flags then
		flags = {}
		self._deathEffectsState[player] = flags
	end
	flags[field] = value
end

-- ============================================================================
-- Story 005 -- T6 respawn payload (extends pc-4's `_checkRespawnTimers`, see that
-- method's own doc comment).
-- ============================================================================

--- The real T6 side effects: fresh-life locomotion/lantern/emission reset (TR-pc-032
--- / H.32 -- S1, LanternLowered, stamina=STAMINA_MAX), clearing the (e)/(f)
--- death-effect proxies, the respawn-anchor position write, `OnPlayerT6Respawned`
--- (fired exactly once, ONLY from here), and the alive=true edge -- gated on the
--- respawned `HumanoidRootPart` actually existing (GDD C.6 T6 row / H.72's ordering
--- requirement: never fires at the world origin, never fires before placement).
function PlayerControllerService:_completeRespawn(player: Player, _now: number): ()
	-- Fresh-life reset: mirrors `_initPlayerState`'s own construction (S1, full
	-- stamina, no sprint/heartbeat anchors) -- TR-pc-032 / H.32. Kept SYNCHRONOUS
	-- (code-review fix): pure per-player state, no live Character/HumanoidRootPart
	-- dereference, so there is no yield-risk or destroyed-instance hazard here --
	-- unlike the task.spawn'd remainder below, this part is safe to run
	-- unconditionally even for a since-departed player (a residual, TD-013-class
	-- table-recreation cost, not a crash risk).
	self._locomotionState[player] = LocomotionStaminaLogic.NewPlayerLocomotionState()

	local playerState = self._playerState[player]
	if playerState then
		playerState.lantern = "S3a" -- LanternLowered, GDD C.6 T6 row
		playerState.locomotion = "S1"
	end

	local emissionState = self._emissionState[player]
	if emissionState then
		EmissionPublisherLogic.OnAxisExited(emissionState.sprint)
		EmissionPublisherLogic.OnAxisExited(emissionState.light)
		-- Fresh grace slate for the NEW life too (H.32's own "respawn spawns S1 with
		-- stamina=MAX, lantern lowered" spirit extended to the grace-cooldown anchors
		-- this story's (d) side effect already resets at T5 for the OLD life).
		EmissionPublisherLogic.ResetGraceAnchorsOnDeath(emissionState)
	end

	-- Clears the (e)/(f) proxies from the life that just ended.
	self._deathEffectsState[player] = nil

	-- Code-review fix (BLOCKING): the remainder touches a live Player/Character
	-- chain (`_respawnPlayerAtAnchorFn`'s default calls `Player:LoadCharacter()`,
	-- which can yield and errors on a departed Player instance -- `TryRespawn` does
	-- NOT itself check liveness, and `Players.PlayerRemoving` does not clear
	-- `deathStartedAt` until Story 006/TD-013 closes it, so a departed player's
	-- stale death record WILL eventually satisfy `RESPAWN_DELAY` here). This is
	-- `task.spawn`'d off the Heartbeat handler -- matching `_beginAndDispatch`'s own
	-- established pattern (synchronous state transition, then task.spawn the
	-- yield-risk remainder) -- so (a) `LoadCharacter`'s yield never blocks the
	-- Heartbeat handler, and (b) one player's error here can never delay or skip a
	-- SIBLING player's respawn in the same `_checkRespawnTimers` pass (each player
	-- gets its own spawned coroutine).
	--
	-- LIVENESS RE-VALIDATION (design decision, flagged -- not dictated by the GDD):
	-- re-checked INSIDE the spawned closure (at execution time, not before
	-- spawning, since more time may have passed by the time this coroutine actually
	-- runs) via `Players:GetPlayerByUserId(player.UserId) == player` -- true only if
	-- this EXACT `Player` instance is still the live one for this userId (false for
	-- both "departed entirely" and "rejoined as a new instance with the same
	-- userId"). SEMANTICS: if NOT live, the entire remainder is skipped -- no
	-- anchor query, no `_respawnPlayerAtAnchorFn` call (so `LoadCharacter` is never
	-- even attempted against a destroyed instance -- that function's own `pcall` is
	-- a belt-and-braces backstop, not the primary guard), no `OnPlayerT6Respawned`,
	-- no alive-edge. This makes `OnPlayerT6Respawned`'s contract precise: it fires
	-- if and only if a player who is STILL CONNECTED actually came back to life --
	-- a departed player's stale death record simply elapses silently (their
	-- PredatorService-side cleanup is already covered by PredatorService's own
	-- `PlayerRemoving` teardown per the GDD's F.4 belt-and-braces clearance rule, so
	-- no signal is lost by skipping this).
	task.spawn(function()
		if Players:GetPlayerByUserId(player.UserId) ~= player then
			return
		end

		local anchorPosition = self._getRespawnAnchorPositionFn(player)
		local hrp = self._respawnPlayerAtAnchorFn(player, anchorPosition)

		-- GDD C.6 T6 row: reset (never clear to nil) the position cache to the
		-- respawn-anchor position, so it is fresh for the new life from the instant
		-- of respawn.
		self._lastServerTrackedPosition[player] = anchorPosition

		-- The SINGLE trigger channel for PredatorService's own T6 clearance
		-- (TR-pc-041) -- fires exactly once, ONLY from T6 (never T5, never a
		-- reconciliation tick, never a replayed Humanoid.Died -- the
		-- deathInProgress guard already prevents any of those from reaching this
		-- method at all).
		self._onPlayerT6RespawnedFn(player.UserId)

		-- H.72: the alive=true edge fires ONLY AFTER the respawned
		-- HumanoidRootPart exists (the positioned-HRP re-add guarantee,
		-- TR-pc-043) -- never unconditionally.
		if hrp then
			self._onSquadMemberAliveChangedFn(player.UserId, true)
		end
	end)
end

-- ============================================================================
-- Story 005 -- cross-epic stub defaults (PredatorService / Crafting & Items do not
-- exist yet; the respawn-anchor registry is level design's future responsibility).
-- Same "warn once per instance, then proceed as a no-op" shape Story 004 established
-- for `_defaultRequestSquadOxygenSpend` -- see that method's own doc comment for the
-- full rationale (a class-table flag is the forbidden static-singleton shape
-- gameplay-code.md disallows; a per-death warn would spam the log).
-- ============================================================================

function PlayerControllerService:_defaultReleasePredatorLock(_userId: number): ()
	if not self._hasWarnedMissingPredatorService then
		self._hasWarnedMissingPredatorService = true
		warn(
			"PlayerControllerService: PredatorService cross-epic stub in use. TODO(Predator AI epic): PredatorService does not exist yet; ReleasePredatorLock/OnPlayerS4Entered/OnPlayerT6Respawned are no-ops."
		)
	end
end

function PlayerControllerService:_defaultOnPlayerS4Entered(_userId: number): ()
	if not self._hasWarnedMissingPredatorService then
		self._hasWarnedMissingPredatorService = true
		warn(
			"PlayerControllerService: PredatorService cross-epic stub in use. TODO(Predator AI epic): PredatorService does not exist yet; ReleasePredatorLock/OnPlayerS4Entered/OnPlayerT6Respawned are no-ops."
		)
	end
end

function PlayerControllerService:_defaultOnPlayerT6Respawned(_userId: number): ()
	if not self._hasWarnedMissingPredatorService then
		self._hasWarnedMissingPredatorService = true
		warn(
			"PlayerControllerService: PredatorService cross-epic stub in use. TODO(Predator AI epic): PredatorService does not exist yet; ReleasePredatorLock/OnPlayerS4Entered/OnPlayerT6Respawned are no-ops."
		)
	end
end

function PlayerControllerService:_defaultOnSquadMemberAliveChanged(_userId: number, _isAlive: boolean): ()
	if not self._hasWarnedMissingCraftingService then
		self._hasWarnedMissingCraftingService = true
		warn(
			"PlayerControllerService: Crafting & Items cross-epic stub in use. TODO(Crafting & Items epic): a RunSession.aliveMembers consumer does not exist yet; OnSquadMemberAliveChanged is a no-op."
		)
	end
end

function PlayerControllerService:_defaultGetRespawnAnchorPosition(_player: Player): Vector3
	if not self._hasWarnedMissingRespawnAnchor then
		self._hasWarnedMissingRespawnAnchor = true
		warn(
			"PlayerControllerService: respawn-anchor stub in use. TODO(level design): no SpawnLocation/anchor registry exists yet; returning Vector3.new(0, 0, 0) unconditionally (GDD C.5.7: 'specific anchors are level design's responsibility')."
		)
	end
	return Vector3.new(0, 0, 0)
end

--- STUDIO VERIFICATION REQUIRED (flagged, not silently assumed -- see this story's
--- own final report): `Player:LoadCharacter()` is documented by Roblox as
--- synchronously creating the character (firing `CharacterAdded` before returning),
--- which is what lets this function read `player.Character`/`HumanoidRootPart`
--- immediately below without an explicit `:WaitForChild` yield -- confirm this
--- synchronous-completion contract still holds under the project's live, auto-
--- updating Studio version before trusting this default in production (this
--- codebase's Lune test harness cannot construct a real Player/Character/
--- CharacterAdded chain at all -- see this story's own test file's harness-
--- disclosure header).
function PlayerControllerService:_defaultRespawnPlayerAtAnchor(player: Player, anchorPosition: Vector3): BasePart?
	-- Code-review fix (BLOCKING): `LoadCharacter()` on a departed/destroyed `Player`
	-- instance errors. `TryRespawn` does NOT itself check liveness, and
	-- `Players.PlayerRemoving` does not clear `deathStartedAt` until Story
	-- 006/TD-013 closes it -- so this function CAN be reached for a departed
	-- player. `_completeRespawn`'s own liveness re-check is the PRIMARY guard
	-- (skips calling this function at all for a departed player); this `pcall` is
	-- the belt-and-braces backstop for any remaining race (e.g. the player departs
	-- between that check and this call).
	local loadOk, loadErr = pcall(function()
		player:LoadCharacter()
	end)
	if not loadOk then
		warn(
			("PlayerControllerService: LoadCharacter failed for userId=%d (player likely departed mid respawn): %s"):format(
				player.UserId,
				tostring(loadErr)
			)
		)
		return nil
	end

	local character = player.Character
	if not character then
		return nil
	end
	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return nil
	end
	hrp.CFrame = CFrame.new(anchorPosition)
	return hrp
end

return PlayerControllerService
