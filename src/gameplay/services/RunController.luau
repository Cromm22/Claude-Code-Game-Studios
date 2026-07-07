--!strict
-- RunController
--
-- Implements: production/epics/runcontroller/story-001-core-aggregator.md
-- ADR: docs/architecture/adr-0002-runcontroller-architecture.md (sole design authority --
--      no GDD exists for this module; Decision points 1-4, Key Interfaces, Risks section)
--      docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md (Rule 1: KnitInit
--      builds / KnitStart connects; Signal-over-BindableEvent preference)
--
-- SCOPE NOTE (Story 001): implements RunEndConditionRaised, the one-shot _hasEnded latch,
-- and defeatReason payload support. NOT implemented here (Story 002's own scope): the
-- GetRunEndedSignal() accessor and its KnitInit-before-KnitStart subscriber-ordering
-- integration test -- self._runEnded IS constructed here via Signal.new(), per ADR-0002's
-- own instruction, so this story's :Fire() call site has something to fire against; Story 002
-- will not need to change this line, only add the accessor and its dedicated test.
--
-- All idempotency-latch decision logic and RunEndedPayload construction lives in the
-- dependency-free RunControllerLogic module (zero Knit/Roblox-service dependency, directly
-- unit-testable under Lune). This file is a thin Knit wrapper: KnitInit container
-- construction, the real os.time() clock sample, and the actual Signal:Fire() call site.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local RunControllerLogic = require(script.Parent.RunControllerLogic)

export type SquadStateSnapshot = RunControllerLogic.SquadStateSnapshot
export type ConditionType = RunControllerLogic.ConditionType
export type DefeatReason = RunControllerLogic.DefeatReason
export type RunEndedPayload = RunControllerLogic.RunEndedPayload

local RunController = Knit.CreateService({
	Name = "RunController",
	Client = {},
	-- Deliberately empty, and MUST remain empty. Per ADR-0002's Risks section:
	-- RunEndConditionRaised must NEVER be added to this table -- doing so would let any
	-- connected game client fire a fake RunEndConditionRaised("victory", ...) and end the run
	-- for the whole squad, a server-authority breach per technical-preferences.md's "Trusting
	-- client-supplied values" forbidden pattern. Treat any .Client-table placement of that
	-- method as an automatic blocking defect in review.
})

--- Exposed for direct testability without a live service instance, matching the
--- DisturbanceService / PlayerControllerService precedent.
RunController.ShouldFire = RunControllerLogic.ShouldFire
RunController.BuildPayload = RunControllerLogic.BuildPayload

-- ============================================================================
-- KnitInit -- builds. Per ADR-0001 Rule 1 and ADR-0002's own Key Interfaces code block, both
-- the latch and the outbound Signal are constructed here, not KnitStart -- PC/Crafting may
-- call RunEndConditionRaised at any point after their own KnitStart completes and cannot
-- assume RunController's KnitStart has already run.
-- ============================================================================

function RunController:KnitInit(): ()
	self._hasEnded = false
	self._runEnded = Signal.new() -- ADR-0001: prefer Signal over Instance.new("BindableEvent")
end

-- ============================================================================
-- RunEndConditionRaised -- server-internal inter-service method (ADR-0002 Decision point 1).
--
-- SERVER-INTERNAL ONLY -- deliberately NOT placed under RunController.Client anywhere in
-- this file. See the Client = {} comment above for why. Never calls back into the caller or
-- any other service (no Knit.GetService(...) anywhere in this file) to independently verify
-- state -- the caller is always responsible for having already determined the condition is
-- true and for supplying its own current squadState snapshot in the payload.
-- ============================================================================

function RunController:RunEndConditionRaised(
	conditionType: ConditionType,
	squadState: SquadStateSnapshot,
	defeatReason: DefeatReason?
): ()
	if not RunControllerLogic.ShouldFire(self._hasEnded) then
		warn(("RunController: RunEndConditionRaised(%s) called after run already ended -- ignored"):format(
			conditionType
		))
		return
	end

	self._hasEnded = true

	-- os.time() -- wall-clock Unix epoch seconds, deliberately NOT workspace:GetServerTimeNow()
	-- (ADR-0002 Risks section / this story's own binding AC): GetServerTimeNow() is
	-- seconds-since-server-instance-start and would be meaningless to an analytics pipeline
	-- reading RunEnded{exitReason} events across sessions/servers.
	local now = os.time()
	local payload = RunControllerLogic.BuildPayload(conditionType, squadState, now, defeatReason)
	self._runEnded:Fire(payload)
end

return RunController
