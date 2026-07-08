--!strict
-- DisturbanceServiceSquadAggregateLogic
--
-- Implements: production/epics/ecological-disturbance/story-007-squad-aggregate-t-accessor.md
-- GDD: design/gdd/ecological-disturbance.md -- D.5 (Squad Aggregate t formula), D.6b
--      (GetSquadAggregateT(excludePlayer) server accessor), TR-ed-045 (exclusion-form
--      semantics + empty/zero guards), TR-ed-071 (squadT = max over connected players +
--      empty-player short-circuit + finiteness fail-quiet guards)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md -- "Public surface
--      (server-internal, non-.Client)" Architecture Diagram entry: GetSquadAggregateT(excludePlayer?).
--      This is a FROZEN cross-GDD contract (Predator AI's round-23 B1 closure, TR-pa-004) -- the
--      signature is never renamed or altered by this story.
--
-- Pure domain logic for the D.5 max-aggregation formula, the D.6b exclusion form, and the
-- NaN/+Infinity fail-quiet finiteness guard. Deliberately has ZERO dependency on Knit, any
-- Roblox service call, OR any require() at all (mirrors every sibling
-- DisturbanceService*Logic module's own zero-require precedent -- Stories 001-005), so it can be
-- required and unit-tested directly under Lune.
--
-- DisturbanceService.luau is a thin Knit wrapper around this module's ComputeSquadAggregateT:
-- it owns the real Players:GetPlayers() enumeration, the real
-- Character/HumanoidRootPart.Position reads (mirroring PlayerControllerService's own
-- _getServerPosition precedent -- a player with no live Character/HumanoidRootPart is simply
-- omitted from the `members` list this module receives, exactly as a player who hasn't spawned
-- yet contributes nothing to D.5's max), and the real self:fieldValue(position) call (which
-- itself reads the CURRENT pass's cached decay values only -- TR-ed-017 -- so passing it in here
-- as `fieldValueFn` never re-invokes math.exp).
--
-- PLAYER IDENTITY (design call, matching this service's zero-Roblox-dependency precedent): this
-- module never references the `Player` type. `SquadMember.player` is an opaque identity value
-- compared only via `==` (works identically for real Roblox `Player` instances, whose equality is
-- referential, and for the plain Lua tables/strings this file's own test suite uses as stand-ins).
-- The frozen `Player?` type in the GDD's D.6b signature lives on DisturbanceService.luau's thin
-- wrapper, not here.
--
-- FIELDVALUEFN INDIRECTION (design call): rather than accepting a caller-precomputed list of
-- {player, fieldValue} pairs, this module accepts {player, position} pairs plus a `fieldValueFn`
-- callback, and calls it EXACTLY ONCE per member per ComputeSquadAggregateT invocation -- O(P)
-- reads, P<=4 (the story's own cost AC). This keeps the O(P)-reads guarantee independently
-- testable at the pure-module level (a counting wrapper around fieldValueFn, matching Story 005's
-- own makeCountingWrapper precedent for math.exp/dist2D) without requiring a live Knit service
-- instance.

export type SquadMember = {
	player: any, -- opaque identity; a real Player instance in production
	position: Vector3,
}

export type FieldValueFn = (Vector3) -> number

local DisturbanceServiceSquadAggregateLogic = {}

-- ============================================================================
-- NaN-guard defense-in-depth (REQUIRED, TR-ed-071): fail-quiet to 0.0 on any non-finite read.
-- Verbatim formula from the story's own AC text: `x ~= x or x == math.huge`. Applied to BOTH each
-- per-player fieldValue reading (tierAt() performs no finiteness check of its own -- this is the
-- only protection a corrupted per-player reading gets) AND the final computed squadT/exclusion-
-- form result (defense-in-depth -- "before publishing").
-- ============================================================================

function DisturbanceServiceSquadAggregateLogic.GuardFinite(x: number): number
	if x ~= x or x == math.huge then
		return 0.0
	end
	return x
end

-- ============================================================================
-- Empty-player guard (REQUIRED): math.max() is NEVER invoked with zero arguments. This helper is
-- only ever called by ComputeSquadAggregateT after that function has already confirmed
-- `#guardedValues >= 1` -- the empty-set short-circuit lives entirely in the caller, structurally
-- preceding every call site below. Uses a running binary max (`math.max(a, b)`, never a variadic
-- spread) so the "never zero-arg" guarantee holds even if this helper were ever called in
-- isolation with a non-empty list.
-- ============================================================================

local function maxOverGuardedValues(guardedValues: { number }): number
	local result = guardedValues[1]
	for i = 2, #guardedValues do
		result = math.max(result, guardedValues[i])
	end
	return result
end

-- ============================================================================
-- D.5 / D.6b -- squadT = if connectedPlayers is empty then 0.0 else max(fieldValue(pi.position))
-- for all connected players pi, with the D.6b exclusion-form overlay:
--   (a) excludePlayer == nil            -> the unfiltered D.5 max
--   (b) empty remainder (excluded is the ONLY member) -> the UNFILTERED max (lone player's own T)
--   (c) zero connected players          -> 0.0 regardless of the excludePlayer argument
--   (d) the same finiteness guard applies identically to every case above
--
-- `fieldValueFn` is invoked EXACTLY ONCE per member (O(P) reads, P<=4) -- the resulting guarded
-- values are reused for BOTH the unfiltered max and the excluded-remainder max, so the exclusion
-- form never triggers a second round of fieldValueFn calls.
-- ============================================================================

function DisturbanceServiceSquadAggregateLogic.ComputeSquadAggregateT(
	members: { SquadMember },
	excludePlayer: any?,
	fieldValueFn: FieldValueFn
): number
	-- Case (c): zero connected players -> 0.0 regardless of excludePlayer. Guarantees math.max()
	-- is never invoked with zero arguments -- this check structurally precedes every math.max
	-- call site in maxOverGuardedValues above.
	if #members == 0 then
		return 0.0
	end

	-- One fieldValueFn call per member, guarded immediately (per-player playerT finiteness guard
	-- -- REQUIRED, since tierAt() performs no finiteness check of its own).
	local guardedValues: { number } = table.create(#members)
	for i, member in members do
		guardedValues[i] = DisturbanceServiceSquadAggregateLogic.GuardFinite(fieldValueFn(member.position))
	end

	local unfilteredMax = maxOverGuardedValues(guardedValues)

	if excludePlayer == nil then
		-- Case (a): nil -> the unfiltered D.5 max.
		return DisturbanceServiceSquadAggregateLogic.GuardFinite(unfilteredMax)
	end

	-- Exclusion form: max over connected players MINUS excludePlayer, reusing the SAME guarded
	-- values computed above (no re-invocation of fieldValueFn). A member whose identity does not
	-- match excludePlayer (including the case where excludePlayer has already departed and is not
	-- a member at all) is retained in `remainderValues` -- this is what makes the "stale/departed
	-- Player reference" edge case fall through to the unfiltered max gracefully, with no special
	-- casing required.
	local remainderValues: { number } = {}
	for i, member in members do
		if member.player ~= excludePlayer then
			table.insert(remainderValues, guardedValues[i])
		end
	end

	if #remainderValues == 0 then
		-- Case (b): empty remainder (excludePlayer is the ONLY connected member) -> fall back to
		-- the UNFILTERED max (the lone player's own T), never 0/nil.
		return DisturbanceServiceSquadAggregateLogic.GuardFinite(unfilteredMax)
	end

	return DisturbanceServiceSquadAggregateLogic.GuardFinite(maxOverGuardedValues(remainderValues))
end

return DisturbanceServiceSquadAggregateLogic
