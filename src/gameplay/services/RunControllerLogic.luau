--!strict
-- RunControllerLogic
--
-- Implements: production/epics/runcontroller/story-001-core-aggregator.md
-- ADR: docs/architecture/adr-0002-runcontroller-architecture.md (sole design authority for
--      this module -- no GDD exists for RunController; see the ADR's Decision points 1-4
--      and its Key Interfaces code block for RunEndConditionRaised/RunEndedPayload)
--
-- Pure domain logic for RunController's one-shot idempotency latch decision and
-- RunEndedPayload construction. Deliberately has ZERO dependency on Knit, Signal, or any
-- Roblox service call (no os.time() call site lives here either -- see BuildPayload's own
-- comment below) so it can be required and unit-tested directly under Lune, matching the
-- DisturbanceServiceBootstrapLogic / PlayerControllerLanternLogic precedent.
-- RunController.luau is a thin Knit wrapper around this module -- it owns the
-- Signal.new()/:Fire() call, the real os.time() clock sample, and the KnitInit container
-- construction; this module owns only the actual idempotency-latch decision and the
-- payload-shape construction.

--- Opaque pass-through payload -- RunController never reads, validates, or branches on any
--- of these fields (ADR-0002 Decision point 1 / Negative Consequences). Shape copied
--- verbatim from ADR-0002's Key Interfaces block; SquadStateSnapshot's fully-finalized shape
--- remains an open ADR-0002 question, tracked separately, not blocking for this story.
export type SquadStateSnapshot = {
	aliveCount: number,
	totalCount: number,
	[string]: any,
}

export type ConditionType = "wipe" | "victory"
export type DefeatReason = "wipe" | "scatter"

export type RunEndedPayload = {
	exitReason: ConditionType,
	squadState: SquadStateSnapshot,
	timestamp: number,
	defeatReason: DefeatReason?,
}

local RunControllerLogic = {}

--- Returns true if a call to RunEndConditionRaised with this current `hasEnded` value should
--- proceed to latch + fire RunEnded; false if it is a post-latch no-op. Pure predicate only --
--- RunController.luau is responsible for actually mutating self._hasEnded (on true) and for
--- the warn()-level log call site (on false); this function performs neither side effect
--- itself (ADR-0002 Decision point 2).
function RunControllerLogic.ShouldFire(hasEnded: boolean): boolean
	return not hasEnded
end

--- Builds the RunEnded payload table. `now` is caller-supplied -- RunController.luau samples
--- the real os.time() itself and passes the result in here; this module never calls os.time()
--- (or any clock API) directly, matching the DisturbanceServiceEmissionLogic clock-injection
--- precedent (the wrapper samples the real clock, the pure logic module only shapes data).
--- `squadState` is never read, validated, or branched on -- passed through byte-for-byte
--- (ADR-0002's opaque pass-through requirement). `defeatReason` is likewise passed through
--- opaquely -- no validation, no defaulting, no co-occurrence checking (that belongs to the
--- caller, per ADR-0002's Implementation Notes).
function RunControllerLogic.BuildPayload(
	conditionType: ConditionType,
	squadState: SquadStateSnapshot,
	now: number,
	defeatReason: DefeatReason?
): RunEndedPayload
	return {
		exitReason = conditionType,
		squadState = squadState,
		timestamp = now,
		defeatReason = defeatReason,
	}
end

return RunControllerLogic
