--!strict
-- DisturbanceServiceBandCrossedLogic
--
-- Implements: production/epics/ecological-disturbance/story-009-disturbance-band-crossed-signal.md
-- GDD: design/gdd/ecological-disturbance.md -- C.3.3 (added Session C 2026-06-19), D.4 (tier
--      classification state machine, hysteresis, first-call flat-threshold dispatch, post-hitch
--      multi-tier settle loop), D.5/D.6b (squadT), TR-ed-038 (server-internal
--      OnDisturbanceBandCrossed(direction, newTier, ts) squad-aggregate signal, up+down),
--      TR-ed-054 (post-hitch cascade settle loop reuse), TR-ed-070 (stateful hysteresis +
--      first-call flat-threshold dispatch)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md (Public surface
--      Architecture Diagram; server-internal signal discipline matching TierCrossedEvent's own
--      dispatch mechanism)
--
-- Pure domain logic for the squad-aggregate band-crossing signal. Deliberately has ZERO
-- dependency on Knit, any Roblox service call, OR any require() at all -- mirrors EVERY sibling
-- DisturbanceService*Logic module's own zero-require precedent (Stories 001-008/014), so it can be
-- required and unit-tested directly under Lune.
--
-- CALLBACK-INJECTION DESIGN (REQUIRED, not a stylistic choice -- mirrors
-- DisturbanceServiceHotspotQueryLogic's own CALLBACK-INJECTION DESIGN precedent, approved
-- 2026-07-08, verbatim rationale reused here): this story's own Implementation Notes require
-- reusing "the same tierAt-style classification function... and the same post-hitch
-- cascade-settle-loop shape from Story 006" rather than reimplementing tier classification math.
-- The naive way to do that would be `require(script.Parent.DisturbanceServiceTierClassificationLogic)`
-- and call `.ClassifyWithCascade` directly -- but `script.Parent`-relative require() is
-- UNRESOLVABLE under this project's loadstring-based Lune test harness (the same landmine
-- DisturbanceServiceDecayFalloffLogic's and DisturbanceServiceHotspotQueryLogic's own headers
-- already document; confirmed empirically here too -- see this story's own report for the fix
-- history). Fixed by accepting `classifyWithCascadeFn` as a CALLER-INJECTED parameter instead:
-- DisturbanceService.luau's real `_runBandCrossedPass` binds this to the REAL
-- `TierClassificationLogic.ClassifyWithCascade` function value directly -- satisfying "call into
-- Story 006's math, do not reimplement it" via genuine function-object reuse, not formula
-- duplication, while staying zero-require and Lune-testable. Test harnesses (this module's own
-- unit-test-equivalent coverage, folded into the sibling integration test file per this story's
-- file-count constraint) inject the SAME real
-- DisturbanceServiceTierClassificationLogic.ClassifyWithCascade function (required independently
-- at the TEST FILE's own top level, where multi-module require() is proven to work -- see
-- tier-classification-hysteresis-tiercrossedevent_test.luau's own multi-require precedent), so
-- this is genuine end-to-end reuse, not a mocked stand-in.
--
-- DisturbanceService.luau is a thin Knit wrapper around this module: it owns the real
-- self._previousSquadTier state (a single nilable Tier -- see FIRST-PASS DESIGN CALL below), the
-- real self._disturbanceBandCrossedSignal Signal (Signal.new(), per ADR-0001's Signal-over-
-- BindableEvent preference for new cross-service channels -- matching Story 006's own
-- self._tierCrossedEvent precedent exactly), the real self:GetSquadAggregateT(nil) call supplying
-- `t` (the UNFILTERED squad aggregate -- this signal is squad-wide, not per-excluded-player), the
-- real TierClassificationLogic.ClassifyWithCascade function value bound as `classifyWithCascadeFn`
-- (see CALLBACK-INJECTION DESIGN above), and the real workspace:GetServerTimeNow() clock sample
-- this module's own events are stamped with AT FIRE TIME (never baked into this pure module --
-- matches Story 006's own resolveContributorFn-at-fire-time precedent: this module returns
-- {direction, newTier} pairs only, no timestamp field at all).
--
-- FIRST-PASS DESIGN CALL (flagged, per this story's own instructions to document the choice): a
-- SINGLE nilable `previousSquadTier: Tier?` parameter serves BOTH roles the story's AC text
-- requires, rather than a separate boolean flag:
--   1. `nil` signals "no prior classification this session" -- the ONLY case in which this module
--      suppresses ALL events (H.28d(d)'s "zero fires on the very first pass, regardless of the
--      classified tier" rule), even if the freshly-classified tier differs from the "Calm" default
--      the flat-threshold dispatch below effectively uses.
--   2. `nil` also selects the flat-threshold dispatch branch inside TierAt (TR-ed-070's first-call
--      convention: `classifyWithCascadeFn`'s `previousTier` argument only understands the four
--      real Tier values, so `nil` is translated to the literal `"Calm"` string here before being
--      passed in -- flat dispatch from "Calm" is EXACTLY TierAt's documented first-call behavior,
--      per DisturbanceServiceTierClassificationLogic.luau's own TIERAT SIGNATURE DEVIATION note: "a
--      first-call with t = 0.85 correctly returns 'Hunt' directly, not 'Tense' via a single-step
--      ladder").
-- A nilable field was chosen over a separate `self._hasClassifiedSquadTierOnce: boolean` flag
-- because it makes an invalid state (`hasClassifiedOnce = true` but `previousSquadTier = nil`, or
-- vice versa) structurally unrepresentable -- one piece of state, one meaning, rather than two
-- fields that could drift out of sync. DisturbanceService.luau's real KnitInit constructs
-- `self._previousSquadTier = nil`; `_runBandCrossedPass` always overwrites it with the freshly
-- classified `finalTier` (never nil again) after the FIRST call, so this module's `isFirstPass`
-- branch can only ever fire once per server lifetime.
--
-- DIRECTION-ONCE-PER-CASCADE DESIGN CALL (flagged): rather than recomputing a direction per
-- individual crossed-boundary step, this module computes ONE direction for the whole cascade, by
-- comparing TIER_SEVERITY(effectivePreviousTier) against TIER_SEVERITY(finalTier) -- the cascade's
-- overall start and end points. This is provably equivalent to a per-step direction because
-- `classifyWithCascadeFn`'s settle loop is DETERMINISTIC given a FIXED `t` (fieldValue/squadT does
-- not change mid-pass, TR-ed-017's decay-cache-frozen-per-pass guarantee extends transitively here
-- via Story 007's own single fieldValueFn read per member): every TierAt step is a pure function of
-- (t, prevTier), and for a fixed t the sequence of results converges MONOTONICALLY toward whatever
-- tier `t` would flat-dispatch to from "Calm" -- it structurally cannot first climb the ladder then
-- descend it (or vice versa) within one cascade, since each step is a strict function of the SAME
-- t. AC-H.28d(e)'s own 3-fire Retreat->Hunt->Tense->Calm cascade (all `direction="down"`) is the
-- worked example this reasoning is verified against.

--- The canonical Tier union (duplicated here, not require()d, matching
--- DisturbanceServiceHotspotQueryLogic's own Tier duplication precedent for the identical
--- zero-require reason -- keep in sync by hand if the GDD's Tier union ever changes).
export type Tier = "Calm" | "Tense" | "Hunt" | "Retreat"

export type Direction = "up" | "down"

export type BandCrossedEvent = {
	direction: Direction,
	newTier: Tier,
}

--- The shape of DisturbanceServiceTierClassificationLogic.ClassifyWithCascade this module needs --
--- satisfied structurally by the real function (see CALLBACK-INJECTION DESIGN above); duplicated
--- as a type alias here rather than require()d for the same zero-require reason.
export type ClassifyWithCascadeFn = (number, Tier, number, number, number, number) -> (Tier, { Tier })

local DisturbanceServiceBandCrossedLogic = {}

-- ============================================================================
-- Tier severity ordering (REQUIRED for direction derivation): Calm < Tense < Hunt < Retreat.
-- Mirrors DisturbanceServiceTierClassificationLogic's own RETREAT CEILING precedent -- no
-- separately registered G.1 constant backs this ordering; it is the fixed structural shape of the
-- D.4 ladder itself, not a tuning knob.
-- ============================================================================

local TIER_SEVERITY: { [Tier]: number } = {
	Calm = 1,
	Tense = 2,
	Hunt = 3,
	Retreat = 4,
}

--- Returns "up" if `toTier` is more severe than `fromTier`, "down" otherwise (including the
--- degenerate equal-severity case, which this module never actually calls this with -- see
--- ClassifySquadBandCrossing's own early-return-on-zero-crossings guard below).
function DisturbanceServiceBandCrossedLogic.DirectionFor(fromTier: Tier, toTier: Tier): Direction
	if TIER_SEVERITY[toTier] > TIER_SEVERITY[fromTier] then
		return "up"
	else
		return "down"
	end
end

-- ============================================================================
-- ClassifySquadBandCrossing -- the full per-pass orchestration (REQUIRED). Reuses the
-- CALLER-INJECTED `classifyWithCascadeFn` (bound to the REAL
-- TierClassificationLogic.ClassifyWithCascade in production -- see CALLBACK-INJECTION DESIGN
-- above) UNMODIFIED (TR-ed-054) against the single scalar `t` (squadT) and the single
-- `previousSquadTier` value -- see this file's own FIRST-PASS DESIGN CALL note above for the
-- nil-means-first-pass contract.
--
-- Returns (finalTier, events): `finalTier` is ALWAYS the freshly classified tier (the caller must
-- persist this as the new self._previousSquadTier, first pass or not); `events` is the ordered
-- list of {direction, newTier} pairs to fire, in ladder order, EMPTY on the first pass regardless
-- of `finalTier` (H.28d(d)) and EMPTY whenever the pass classifies no boundary crossing at all
-- (steady-state / within-hysteresis-band oscillation, H.28d(b)).
-- ============================================================================

function DisturbanceServiceBandCrossedLogic.ClassifySquadBandCrossing(
	t: number,
	previousSquadTier: Tier?,
	classifyWithCascadeFn: ClassifyWithCascadeFn,
	tenseThreshold: number,
	huntThreshold: number,
	hysteresisBand: number,
	maxIterations: number
): (Tier, { BandCrossedEvent })
	local isFirstPass = previousSquadTier == nil
	local effectivePreviousTier: Tier = previousSquadTier or "Calm"

	local finalTier, crossedTiers =
		classifyWithCascadeFn(t, effectivePreviousTier, tenseThreshold, huntThreshold, hysteresisBand, maxIterations)

	if isFirstPass then
		-- H.28d(d): the session's very first pass NEVER fires, regardless of the classified tier.
		return finalTier, {}
	end

	if #crossedTiers == 0 then
		-- Steady-state (H.28d(a)'s "zero fires when tier unchanged") or hysteresis-band
		-- oscillation (H.28d(b)) -- no boundary was crossed this pass.
		return finalTier, {}
	end

	-- DIRECTION-ONCE-PER-CASCADE (see header note above): one direction, derived from the
	-- cascade's overall start/end points, applied to every crossed boundary in this pass.
	local direction = DisturbanceServiceBandCrossedLogic.DirectionFor(effectivePreviousTier, finalTier)

	local events: { BandCrossedEvent } = table.create(#crossedTiers)
	for _, crossedTier in crossedTiers do
		table.insert(events, { direction = direction, newTier = crossedTier })
	end

	return finalTier, events
end

return DisturbanceServiceBandCrossedLogic
