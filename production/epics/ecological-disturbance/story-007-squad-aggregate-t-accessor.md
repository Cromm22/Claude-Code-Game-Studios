# Story 007: Squad Aggregate t & GetSquadAggregateT Accessor

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-045` (`GetSquadAggregateT(excludePlayer)` exclusion-form semantics + empty/zero guards), `TR-ed-071` (`squadT = max` over connected players + empty-player short-circuit + finiteness fail-quiet guards)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: This story implements the frozen `GetSquadAggregateT(excludePlayer: Player?): number` contract that Predator AI's approved GDD already depends on — the round-23 B1 exclusion-form closure. No ADR-level deviation from GDD D.5/D.6b.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: No engine-API risk. The one hazard is Luau's `math.max()` raising an error when called with zero arguments — the empty-player guard must short-circuit BEFORE calling `math.max()`, never rely on catching the error.

**Control Manifest Rules (Core layer)**:
- Required: `hotspot.id` tie-break comparisons use Luau's native string `<` operator (not applicable here — this is Story 008's rule, listed for cross-reference only; this story has no dedicated Core-layer manifest line, governed by the general server-internal-only discipline).

---

## Acceptance Criteria

- [ ] **D.5 Squad Aggregate t**: `squadT = if connectedPlayers is empty then 0.0 else max(fieldValue(pᵢ.position)) for all connected players pᵢ`. Justification: max-aggregation surfaces the worst case — "the squad is only as safe as its most exposed member."
- [ ] **Empty-player guard (REQUIRED)**: `math.max()` is never invoked with zero arguments — the implementation short-circuits to `0.0` when no players are connected.
- [ ] **H.22** — GIVEN a 4-player session with `fieldValue` {0.71, 0.34, 0.09, 0.02}, WHEN `squadT` computed, THEN result is 0.71 — max, not mean or sum.
- [ ] **H.22b** — GIVEN zero connected players, WHEN `squadT` computed, THEN result is exactly 0.0, no error, `math.max()` not called with zero args.
- [ ] **NaN-guard defense-in-depth (REQUIRED)**: the implementation applies a finiteness check to the computed `squadT` before publishing — if `squadT ~= squadT or squadT == math.huge`, publish `0.0` instead (fail-quiet). The SAME check applies to each per-player `playerT` before publish (`tierAt()` performs no finiteness check of its own).
- [ ] **Exclusion form — `GetSquadAggregateT(excludePlayer: Player?): number`**: pinned semantics — (a) `nil` → the unfiltered D.5 max; (b) empty remainder (excluded player is the ONLY connected player) → return the UNFILTERED max, i.e. the lone player's own T, never `0`/`nil`; (c) zero connected players → `0.0` regardless of argument; (d) the D.5 finiteness guard applies identically.
- [ ] **H.22c** — GIVEN a 4-player session {P1=0.71, P2=0.34, P3=0.09, P4=0.02}, WHEN `GetSquadAggregateT(P1)` called, THEN result is 0.34 ± 0.001; WHEN `GetSquadAggregateT(nil)` called, THEN result is 0.71 ± 0.001; AND GIVEN a 1-player session where lone player P reads 0.55, WHEN `GetSquadAggregateT(P)` called, THEN result is 0.55 ± 0.001 (empty-remainder returns UNFILTERED max); AND GIVEN zero connected players, WHEN called with any argument, THEN result is exactly 0.0; AND the finiteness guard applies identically to the exclusion form.
- [ ] Cost: O(P) where P ≤ 4 (connected player count) — cheap enough to call at Predator AI's 4Hz cadence without budget concerns.
- [ ] `GetSquadAggregateT` is server-internal only — never exposed via `DisturbanceService.Client` (verified structurally here, enforced mechanically by Story 016).

---

## Implementation Notes

```luau
function GetSquadAggregateT(excludePlayer: Player?): number
    if excludePlayer == nil then
        return squadT -- as computed by D.5 using the same per-pass cache
    end
    -- max over connected players MINUS excludePlayer, from the same per-pass
    -- fieldValue cache; empty remainder → fall back to the unfiltered max
    -- (lone player's own T, never 0/nil).
    return maxOverConnectedExcluding(excludePlayer) -- O(P), P ≤ 4
end
```
The exclusion form is the round-23 B1 closure of Predator AI's R5/OQ.10 obligation: PA's Hunt→Disengage quiet-check reads `squadQuietT = GetSquadAggregateT(excludeLockedPlayer)` — without exclusion, the locked target's own forced-survival sprint would keep the unfiltered `squadT` loud and make Hunt→Disengage structurally unreachable, inverting Pillar 1. This is a frozen cross-GDD contract; do not rename or alter the signature.

Both the `nil` form and the exclusion form MUST read from the **same per-pass fieldValue cache** (computed once per field-update pass, per Story 005's per-source decay caching discipline) — do not recompute `fieldValue` per player per call.

---

## Out of Scope

- Story 009: the squad-aggregate *tier-crossing notification* (`OnDisturbanceBandCrossed`) that consumes this story's `squadT` value — this story only produces the scalar and the accessor.
- Story 013: HUD's consumption of `squadT` via `OnMeterUpdate` (this story's output is a dependency, not this story's scope).

---

## QA Test Cases

- **AC-H.22**: Given: 4 connected players with fieldValues {0.71, 0.34, 0.09, 0.02} — When: `squadT` computed — Then: result is 0.71 (max). Edge case: all four players at the exact same fieldValue — max equals that shared value, not a multiple.
- **AC-H.22b**: Given: zero connected players — When: `squadT` computed — Then: result is exactly 0.0; assert `math.max` is never invoked (spy/counter on the call, or structural code review that the empty check precedes any `math.max` call).
- **AC — NaN-guard**: Given: a corrupted fieldValue read that yields NaN or `+math.huge` for one player — When: `squadT`/`playerT` computed and published — Then: the published value is `0.0`, never NaN/+Inf. Edge case: test both NaN-flavored and `+math.huge`-flavored corruption separately (per H.25c's "falsifiability control" precedent from the hotspot story — apply the same rigor here).
- **AC-H.22c**: Given: 4-player session {P1=0.71, P2=0.34, P3=0.09, P4=0.02} — When: `GetSquadAggregateT(P1)` called — Then: 0.34 ± 0.001. When: `GetSquadAggregateT(nil)` called — Then: 0.71 ± 0.001. Given: a 1-player session, lone player P at 0.55 — When: `GetSquadAggregateT(P)` called — Then: 0.55 ± 0.001 (NOT 0.0, NOT nil). Given: zero connected players — When: called with any player argument (even a stale/disconnected Player reference) — Then: exactly 0.0. Edge case: calling with a `Player` object that is NOT currently in the connected set (e.g., already departed) — verify the implementation treats this gracefully (falls through to the unfiltered max, since the "excluded" player isn't in the pool to begin with) rather than erroring.
- **AC — cost/cadence**: Given: 4 connected players — When: `GetSquadAggregateT` is called at Predator AI's 4Hz simulated cadence for a sustained period — Then: no per-call recomputation of `fieldValue` beyond the shared per-pass cache (verify via a call-counter on the underlying `fieldValue` function, confirming it's O(P) reads, not O(P × calls)).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/squad-aggregate-t-accessor_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 005
- Unlocks: 009, 013, 015

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: All ACs COVERED (H.22, H.22b, H.22c, NaN-guard both flavors, exclusion form a-d, cost/cadence O(P)), including a post-review composed test proving H.25c(d)'s cross-module claim (squadT=0.0 under real NaN corruption, both argument forms) end-to-end
**Deviations**: None blocking.
**Test Evidence**: `tests/unit/ecological-disturbance/squad-aggregate-t-accessor_test.luau` — passing
**Code Review**: Complete (combined ed-7+ed-8 review) — APPROVED WITH SUGGESTIONS
