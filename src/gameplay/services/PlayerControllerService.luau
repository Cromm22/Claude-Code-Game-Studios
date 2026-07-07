--!strict
-- PlayerControllerService
--
-- Implements: production/epics/player-controller/story-002-lantern-gather-gate.md
-- GDD: design/gdd/player-controller.md (C.3.6 light-to-gather gate, C.7
--      tap-hold/proximity-gate, C.8.2 Light emission cooldown rationale,
--      C.9 RemoteEvent surface, C.11 clock-injection seam contract)
-- ADR: docs/architecture/adr-0006-remoteevent-trust-boundary.md (canonical
--      6-step order every client-fired RemoteEvent handler follows)
--      docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md
--      (KnitInit builds / KnitStart connects)
--
-- SCOPE NOTE (Story 002): this is a MINIMAL Knit service skeleton, built only
-- far enough to host the lantern axis. Story 001 (Locomotion & Sprint-State
-- Authority) has NOT been implemented yet -- this file does not implement
-- sprint/stamina/locomotion. `PlayerState.locomotion` (see
-- PlayerControllerLanternLogic) is an opaque stub seam Story 001 will
-- populate; this story only proves the lantern axis never reads or mutates
-- it (H.9, H.25). Story 003 (disturbance emission) is likewise not
-- implemented -- `t_lastGracePulse_light` is forward-declared but never
-- written by any code path in this file.
--
-- All actual state-machine logic lives in the dependency-free
-- PlayerControllerLanternLogic module (zero Knit/Roblox-service
-- dependency, directly unit-testable under TestEZ/Lemur without a vendored
-- Knit package). This file is a thin Knit wrapper: Player identity,
-- RemoteEvent wiring, per-player table lifecycle, and the ADR-0006 6-step
-- ordering glue.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local LanternLogic = require(script.Parent.PlayerControllerLanternLogic)

type PlayerState = LanternLogic.PlayerState
type TumblingWindow = LanternLogic.TumblingWindow
type LanternRateLimitRecord = LanternLogic.LanternRateLimitRecord

local PlayerControllerService = Knit.CreateService({
	Name = "PlayerControllerService",
	Client = {
		RequestLanternToggle = Knit.CreateSignal(), -- C -> S (RemoteEvent-backed; ADR-0006 scope note: no RemoteFunctions in this project)
		OnLanternStateChanged = Knit.CreateSignal(), -- S -> C broadcast, per GDD C.9 table
	},
})

--- Exposed for direct testability without a live service instance (H.84).
PlayerControllerService.C3_6_CanArmGather = LanternLogic.C3_6_CanArmGather

--- C.11 clock-injection seam (production default). NEVER call
--- `workspace:GetServerTimeNow()` inline anywhere else in this file --
--- tests override this field directly with a fake closure.
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

	self._playerState = {} :: { [Player]: PlayerState }
	self._globalEventCounts = {} :: { [Player]: TumblingWindow }
	self._lanternRateLimit = {} :: { [Player]: LanternRateLimitRecord }
end

-- ============================================================================
-- KnitStart -- connects. Engine-event connections (PlayerAdded/PlayerRemoving)
-- and RemoteEvent-backed signal connections happen here, matching
-- ADR-0010's Heartbeat-in-KnitStart precedent (connections belong in
-- KnitStart; construction belongs in KnitInit).
-- ============================================================================

function PlayerControllerService:KnitStart(): ()
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
	end)

	self.Client.RequestLanternToggle:Connect(function(player: Player, raised: any)
		self:_handleLanternToggleRequest(player, raised)
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
	end
	return accepted, reason
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

return PlayerControllerService
