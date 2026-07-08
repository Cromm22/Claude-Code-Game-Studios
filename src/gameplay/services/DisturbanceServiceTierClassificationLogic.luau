--!strict
-- DisturbanceServiceTierClassificationLogic
--
-- Implements: production/epics/ecological-disturbance/story-006-tier-classification-hysteresis-tiercrossedevent.md
-- GDD: design/gdd/ecological-disturbance.md -- D.4 (tier classification state machine, hysteresis,
--      first-call flat-threshold dispatch, canonical key encoding, post-hitch multi-tier settle
--      loop), C.3.3 (TierCrossedEvent server-side per-pass coalescing rule), TR-ed-011 (canonical
--      %d_%d previousTierAtPosition key), TR-ed-037 (server-internal TierCrossedEvent, coalesced
--      one-per-pass-per-boundary), TR-ed-054 (post-hitch cascade settle loop, <=4 iterations),
--      TR-ed-070 (stateful hysteresis +-0.03 downward-only + first-call flat-threshold dispatch)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md -- Architecture Diagram
--      "Public surface (server-internal, non-.Client)" section names TierCrossedEvent as a
--      server-internal signal; this story authors a NEW cross-service Signal for it (NOT the
--      GDD-frozen C.1.11 OnPlayerDied raw BindableEvent), so ADR-0001's general Signal-over-
--      BindableEvent preference applies cleanly with no ADR-0004-style type tension.
--
-- Pure domain logic for D.4's tierAt state machine, the canonical previousTierAtPosition key
-- encoding, the post-hitch multi-tier settle loop, and the full per-pass classification + C.3.3
-- server-side coalescing orchestration. Deliberately has ZERO dependency on Knit, any Roblox
-- service call, OR any require() at all (mirrors every sibling DisturbanceService*Logic module's
-- own zero-require precedent -- Stories 001-008/014), so it can be required and unit-tested
-- directly under Lune.
--
-- DisturbanceService.luau is a thin Knit wrapper around this module: it owns the real
-- self._previousTierAtPosition state table, the real self._tierCrossedEvent Signal
-- (Signal.new(), per ADR-0001 -- a NEW cross-service channel, not the GDD-frozen OnPlayerDied),
-- the real self:fieldValue(position) calls this module's `fieldValueFn` injection point
-- delegates to, and the real self:_topContributorsAt(position, 1) +
-- self._liveSources[emissionId].initialMagnitude lookup this module's `resolveContributorFn`
-- injection point delegates to.
--
-- TIERAT SIGNATURE DEVIATION (design call, flagged): the story's own Implementation Notes cite
-- `tierAt(P: Vector3, previousTier: Tier): Tier` verbatim, with a pseudocode body that calls
-- `local t = fieldValue(P)` internally. This module's TierAt instead takes `t: number` directly
-- (the ALREADY-COMPUTED fieldValue reading), NOT a Vector3 -- mirroring every sibling pure-logic
-- module's own established precedent (DecayFalloffLogic.FieldValueAt takes an already-queried
-- candidate id list, never the raw spatial grid; SquadAggregateLogic.ComputeSquadAggregateT takes
-- a fieldValueFn callback rather than reimplementing fieldValue() internally). A pure,
-- zero-Roblox module cannot itself own self._spatialGrid/self._liveSources/self._decayCache, so
-- it cannot compute fieldValue(P) internally. The GDD's own D.6 "Note on the algorithm body"
-- disclaimer ("bodies are pseudocode... production implementation lives in the future
-- DisturbanceService ADR; this GDD specifies behaviour, not implementation") licenses this same
-- translation for D.4's body. DisturbanceService.luau's real orchestration calls
-- self:fieldValue(position) FIRST, then passes the resulting `t` into this module's
-- TierAt/ClassifyWithCascade/RunClassificationPass -- functionally identical behavior to the
-- GDD's pseudocode, just factored for testability.
--
-- RETREAT CEILING (design call, matches Story 008 precedent): `1.0` is used directly as the
-- Hunt->Retreat upward boundary and the Retreat->Hunt downward-hysteresis anchor -- NOT a
-- `RETREAT_THRESHOLD` constant. Retreat's 1.00 ceiling is D.3's own fieldValue clamp ceiling, not
-- a separately registered G.1 tuning knob -- see DisturbanceServiceHotspotQueryLogic.luau's own
-- TierLowerBound, which already established this exact precedent ("no RETREAT_THRESHOLD constant
-- exists in DisturbanceConstants.luau").
--
-- DOWNWARD-HYSTERESIS THRESHOLDS COMPUTED, NOT HARDCODED: D.4's literal branch text reads
-- `t < 0.27` / `t < 0.62` / `t < 0.97`, annotated "hysteresis: 0.30 - 0.03" etc. This module
-- computes these as `tenseThreshold - hysteresisBand` / `huntThreshold - hysteresisBand` /
-- `1.0 - hysteresisBand` from the caller-supplied parameters, rather than hardcoding the bare
-- literals -- verified bit-identical under this project's pinned Lune/Luau runtime (IEEE-754
-- double subtraction of these specific operands introduces no precision drift), so this satisfies
-- coding-standards.md's "never hardcode gameplay values" rule with zero behavioral difference
-- from the story's own literal pseudocode.

export type Tier = "Calm" | "Tense" | "Hunt" | "Retreat"

export type PositionEntry = {
	key: string,
	position: Vector3,
}

export type ClassificationPassEvent = {
	crossedTier: Tier,
	position: Vector3,
	emissionId: string,
	initialMagnitude: number,
}

export type FieldValueFn = (Vector3) -> number
export type ResolveContributorFn = (Vector3) -> (string, number)

local DisturbanceServiceTierClassificationLogic = {}

-- ============================================================================
-- Canonical key encoding (REQUIRED, TR-ed-011). NEVER key previousTierAtPosition by the Vector3
-- itself (Luau userdata reference-equality bug) and NEVER via tostring(P).
-- ============================================================================

function DisturbanceServiceTierClassificationLogic.CanonicalKeyFor(position: Vector3): string
	return string.format("%d_%d", math.floor(position.X), math.floor(position.Z))
end

-- ============================================================================
-- Canonical-key dedup over a raw position list (first-encountered-wins, mirrors
-- DisturbanceServiceHotspotQueryLogic.DeduplicateByFloorSnap's own precedent). Multiple live
-- sources can share the same canonical XZ key (e.g. two players standing at the same spot, or
-- repeated Gather emissions at the same node) -- this collapses them to one PositionEntry per key
-- so RunClassificationPass below classifies each distinct position exactly once per pass.
-- ============================================================================

function DisturbanceServiceTierClassificationLogic.DedupPositionsByCanonicalKey(rawPositions: { Vector3 }): { PositionEntry }
	local seen: { [string]: boolean } = {}
	local deduped: { PositionEntry } = {}
	for _, position in rawPositions do
		local key = DisturbanceServiceTierClassificationLogic.CanonicalKeyFor(position)
		if not seen[key] then
			seen[key] = true
			table.insert(deduped, { key = key, position = position })
		end
	end
	return deduped
end

-- ============================================================================
-- D.4 -- tierAt state machine (verbatim branch structure; see this file's own TIERAT SIGNATURE
-- DEVIATION note above for why this takes `t: number`, not `P: Vector3`). PURE -- holds no
-- internal state; callers always supply `previousTier` explicitly (first-call rule: pass
-- previousTier = "Calm" for any position never classified before -- TR-ed-070).
-- ============================================================================

function DisturbanceServiceTierClassificationLogic.TierAt(
	t: number,
	previousTier: Tier,
	tenseThreshold: number,
	huntThreshold: number,
	hysteresisBand: number
): Tier
	if previousTier == "Calm" then
		-- First-call / default-state flat dispatch (TR-ed-070): the ONLY branch with no
		-- hysteresis applied -- a first-call with t = 0.85 correctly returns "Hunt" directly,
		-- not "Tense" via a single-step ladder (H.17b).
		if t >= 1.0 then
			return "Retreat"
		elseif t >= huntThreshold then
			return "Hunt"
		elseif t >= tenseThreshold then
			return "Tense"
		else
			return "Calm"
		end
	elseif previousTier == "Tense" then
		if t >= huntThreshold then
			return "Hunt"
		elseif t < tenseThreshold - hysteresisBand then
			return "Calm"
		else
			return "Tense"
		end
	elseif previousTier == "Hunt" then
		if t >= 1.0 then
			return "Retreat"
		elseif t < huntThreshold - hysteresisBand then
			return "Tense"
		else
			return "Hunt"
		end
	elseif previousTier == "Retreat" then
		if t < 1.0 - hysteresisBand then
			return "Hunt"
		else
			return "Retreat"
		end
	end

	-- Unreachable for valid Tier inputs; defensive guard catches typed-string violations, mirrors
	-- the GDD's own D.4 pseudocode's identical defensive tail.
	error(("DisturbanceServiceTierClassificationLogic.TierAt: invalid previousTier '%s'"):format(tostring(previousTier)))
end

-- ============================================================================
-- Post-hitch multi-tier cascade settle loop (REQUIRED, TR-ed-054). Runs TierAt repeatedly with
-- the SAME `t` (fieldValue is fixed within a single field-update pass -- the decay cache doesn't
-- change mid-pass, TR-ed-017) until the result stabilizes. Returns the final tier plus the
-- ORDERED list of crossed tiers (ladder order) -- one entry per boundary actually crossed.
--
-- `maxIterations` is a DEFENSIVE bound (TR-ed-054's own "<=4 iterations" ceiling). Structurally,
-- only 4 distinct Tier values exist and a downward cascade only ever moves monotonically toward
-- Calm (or resolves in a single call on any upward/non-cascading case), so this should NEVER
-- actually fire for any valid Tier input -- exceeding it is treated as a defensive-programming
-- error (a corrupted previousTier or an oscillating TierAt implementation), not a recoverable
-- case.
-- ============================================================================

function DisturbanceServiceTierClassificationLogic.ClassifyWithCascade(
	t: number,
	previousTier: Tier,
	tenseThreshold: number,
	huntThreshold: number,
	hysteresisBand: number,
	maxIterations: number
): (Tier, { Tier })
	local crossedTiers: { Tier } = {}
	local prev: Tier = previousTier
	local result = DisturbanceServiceTierClassificationLogic.TierAt(t, prev, tenseThreshold, huntThreshold, hysteresisBand)
	local iterationsUsed = 1

	while result ~= prev do
		table.insert(crossedTiers, result)
		prev = result
		iterationsUsed += 1

		if iterationsUsed > maxIterations then
			error(
				("DisturbanceServiceTierClassificationLogic.ClassifyWithCascade: settle loop exceeded maxIterations=%d -- defensive guard triggered (TR-ed-054)"):format(
					maxIterations
				)
			)
		end

		result = DisturbanceServiceTierClassificationLogic.TierAt(t, prev, tenseThreshold, huntThreshold, hysteresisBand)
	end

	return result, crossedTiers
end

-- ============================================================================
-- RunClassificationPass -- the full per-pass orchestration (D.4 settle loop x N positions + C.3.3
-- server-side per-pass coalescing, REQUIRED). Mutates `previousTierAtPosition` IN PLACE (mirrors
-- DisturbanceServiceDecayFalloffLogic.RunDecayPass's own decayCache-mutated-in-place precedent)
-- -- one entry per canonical key, set to that position's post-cascade final tier.
--
-- Coalescing (C.3.3): groups every crossing observed this pass by `crossedTier`, keeping only the
-- highest-fieldValue-at-pass-end position per crossedTier value (strict `>` -- first-encountered
-- wins an exact tie, matching DeduplicateByFloorSnap's own tie-break precedent). `t` is read via
-- `fieldValueFn` at most once per position (TR-ed-017 -- no re-invocation of decay math), and
-- since decay is fixed for the whole pass, that single reading IS the "at pass-end" value C.3.3
-- specifies regardless of enumeration order. `resolveContributorFn` is called EXACTLY ONCE per
-- coalescing WINNER (not per crossing, not per position) -- bounded cost, mirrors
-- GetHottestHotspot's own "only resolve contributors for the winner" design.
-- ============================================================================

function DisturbanceServiceTierClassificationLogic.RunClassificationPass(
	positionEntries: { PositionEntry },
	previousTierAtPosition: { [string]: Tier },
	fieldValueFn: FieldValueFn,
	resolveContributorFn: ResolveContributorFn,
	tenseThreshold: number,
	huntThreshold: number,
	hysteresisBand: number,
	maxIterations: number
): { ClassificationPassEvent }
	-- crossedTier -> the running best (highest-fieldValue) candidate for that boundary this pass.
	local bestByTier: { [string]: { position: Vector3, fieldValueAtPassEnd: number } } = {}

	for _, entry in positionEntries do
		local previousTier: Tier = previousTierAtPosition[entry.key] or "Calm"
		local t = fieldValueFn(entry.position)
		local finalTier, crossedTiers = DisturbanceServiceTierClassificationLogic.ClassifyWithCascade(
			t,
			previousTier,
			tenseThreshold,
			huntThreshold,
			hysteresisBand,
			maxIterations
		)

		previousTierAtPosition[entry.key] = finalTier

		for _, crossedTier in crossedTiers do
			local existing = bestByTier[crossedTier]
			if not existing or t > existing.fieldValueAtPassEnd then
				bestByTier[crossedTier] = { position = entry.position, fieldValueAtPassEnd = t }
			end
		end
	end

	-- Resolve contributor info ONLY for the coalescing winners, and only after every position in
	-- this pass has already been classified (true pass-end semantics).
	local events: { ClassificationPassEvent } = {}
	for crossedTier, best in bestByTier do
		local emissionId, initialMagnitude = resolveContributorFn(best.position)
		table.insert(events, {
			crossedTier = crossedTier :: Tier,
			position = best.position,
			emissionId = emissionId,
			initialMagnitude = initialMagnitude,
		})
	end

	return events
end

return DisturbanceServiceTierClassificationLogic
