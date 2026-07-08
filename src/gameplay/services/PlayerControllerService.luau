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

type PlayerState = LanternLogic.PlayerState
type TumblingWindow = LanternLogic.TumblingWindow
type LanternRateLimitRecord = LanternLogic.LanternRateLimitRecord
type PlayerLocomotionState = LocomotionStaminaLogic.PlayerLocomotionState
type SprintRateLimitRecord = LocomotionStaminaLogic.SprintRateLimitRecord
type PlayerEmissionState = EmissionPublisherLogic.PlayerEmissionState

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

return PlayerControllerService
