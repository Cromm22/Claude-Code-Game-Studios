# Story 005: Decay Formula, Spatial Falloff & fieldValue()

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-017` (per-source decay caching, ≤1 `math.exp` call per source per pass), `TR-ed-018` (forbidden transcendentals in inner loop, squared-distance cull)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: This story implements the GDD's own D.1–D.3 formulas exactly as specified — the ADR does not re-derive the math, only the data structures (Story 003) it runs against. `GetHottestHotspot`/`fieldValue()` performance guardrail (touch only ~4–9 grid cells per query) depends directly on this story's correct use of Story 003's grid.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: No engine-API risk — pure deterministic math over Luau primitives. The only Roblox-specific concern is the clock source (`workspace:GetServerTimeNow()`, already established in Story 002) and confirming Luau's `math.exp`/`math.sqrt`/`^` operator behavior matches the "forbidden transcendentals" constraints (some Luau VM builds compile `a^2` to `exp(2*log(a))` — must use explicit `x*x`).

**Control Manifest Rules (Core layer)**:
- Guardrail: `GetHottestHotspot`/`fieldValue()` touch only ~4–9 grid cells per query — source: ADR-0004

---

## Acceptance Criteria

- [ ] **D.1 Magnitude Decay**: `m(t, age) = initialMagnitude × exp(−λ × age)` where `age = math.max(0, serverTime − emissionTime)` and `λ = ln(2) / t½`. `t½ = 30s` for Gather/Sprint/Light, `90s` for Beacon. Output range `(0.0, initialMagnitude]`; source expires when `m < MAGNITUDE_FLOOR = 0.02` (strict less-than).
- [ ] **H.7** — GIVEN a Gather/Sprint/Light emission with known `initialMagnitude` and `emissionTime`, WHEN evaluated at `age = STANDARD_HALF_LIFE`, THEN `m(age)` equals `initialMagnitude × 0.5` ± 0.001.
- [ ] **H.8** — GIVEN a Beacon emission, WHEN evaluated at `age = BEACON_HALF_LIFE`, THEN `m(age)` equals `initialMagnitude × 0.5` ± 0.001.
- [ ] **H.9** — GIVEN a point source whose `m(age)` has just dropped strictly below `MAGNITUDE_FLOOR`, WHEN the next maintenance pass runs (within `EXPIRY_MAINTENANCE_INTERVAL`), THEN the source is no longer in the live-source list and contributes zero to subsequent queries. Expiry comparison is strict less-than: `m == MAGNITUDE_FLOOR` exactly is NOT culled.
- [ ] **H.9b** — GIVEN a counter wrapping `math.exp` (via `_setExpFn(fn)`, server-internal only) AND the live-source list contains 100 sources AND the field is queried at 50 distinct positions in a single update pass, WHEN the pass completes, THEN `math.exp` was called at most 100 times — not 5,000 (verifies per-source-per-pass caching).
- [ ] **H.9c** — GIVEN counters wrapping `math.pow` and `math.sqrt` AND a static-analysis pass over the inner contribution loop, WHEN a field-update pass over Q query positions completes AND one `GetHottestHotspot` query completes, THEN: (a) `math.pow` called zero times in the inner loop; (b) zero occurrences of the Luau `^` operator in the inner loop scope; (c) `math.sqrt` called at most `30 × (Q + C + 1)` times (only on radius-cull-passing sources).
- [ ] **H.10** — GIVEN a source with `initialMagnitude = MAGNITUDE_FLOOR`, WHEN queried at age=0, THEN it contributes its full (negligible) magnitude; on the next maintenance pass after decaying strictly below floor, it is culled.
- [ ] **D.2 Spatial Falloff**: `contribution(P, S) = m(age) × max(0, 1 − dist2D(P, S) / INFLUENCE_RADIUS)²`. Use `dist2DSquared` for the radius cull BEFORE invoking `dist2D` (`math.sqrt`); use explicit multiplication for squaring, never `math.pow` or `^`.
- [ ] **H.11** — GIVEN a single live source at S with current decayed magnitude `m`, WHEN `fieldValue()` queried at P where `dist2D(P,S)=0`, THEN returned value equals `m` ± 0.001.
- [ ] **H.12** — GIVEN a single live source, WHEN queried at P where `dist2D(P,S) = INFLUENCE_RADIUS`, THEN returned value is exactly 0.0.
- [ ] **H.13** — GIVEN a single live source, WHEN queried at P where `dist2D(P,S) > INFLUENCE_RADIUS`, THEN returned value is exactly 0.0.
- [ ] **H.14** — GIVEN two independent live sources S1/S2 both within `INFLUENCE_RADIUS` of P, WHEN `fieldValue(P)` computed, THEN result equals `contribution(P,S1) + contribution(P,S2)` — additive stacking, even sharing the same `sourcePlayerId`.
- [ ] **H.15** — GIVEN enough live sources near P that summed contributions exceed 1.0, WHEN `fieldValue(P)` returned, THEN clamped at 1.0; each source's stored `m(t,age)` unaffected by the clamp.
- [ ] **H.16** — GIVEN two sources at identical XZ but different Y, WHEN `fieldValue()` queried at a coplanar P, THEN both contribute based on XZ distance only — Y separation irrelevant.
- [ ] **D.3 Field Value**: `fieldValue(P) = min(1.0, Σ contribution(P, Sᵢ))` for all live sources within range, using Story 003's grid for the candidate enumeration (only cells within `INFLUENCE_RADIUS + 16 studs` of P — typically 4–9 cells).

---

## Implementation Notes

Two helper functions (D.2, cite verbatim — parameter names `a`/`b`, not `P`/`S`, to avoid identifier collision):
```luau
function dist2DSquared(a: Vector3, b: Vector3): number
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return dx * dx + dz * dz
end

function dist2D(a: Vector3, b: Vector3): number
    return math.sqrt(dist2DSquared(a, b))
end
```
Implementation pattern (REQUIRED): use `dist2DSquared` for the radius cull (`if dist2DSquared(P, S.position) > INFLUENCE_RADIUS * INFLUENCE_RADIUS then continue end`); only invoke `dist2D` (i.e., `math.sqrt`) on sources that pass the cull. The squared form `(1 − d/r)*(1 − d/r)` MUST be used for the falloff square — `math.pow` is forbidden.

**Per-source decay caching (REQUIRED, C.1.13)**: every update pass MUST evaluate `m(age)` exactly once per live source, cache the value on the source record, and reuse the cached value for every field-value query within that same pass (flora positions, player positions, hotspot candidates). Calling `math.exp()` per-source-per-query-position is forbidden. Once a source's decayed magnitude falls below `MAGNITUDE_FLOOR`, subsequent passes skip the `exp()` call entirely and mark the source for the next maintenance-pass cull.

Test seams required by the verification companion doc: `_setExpFn(fn: (number) -> number)` (server-internal only, H.9b) and the existing `_setTestClock`/`_advanceTestClock` seam from Story 001/002 (H.5, H.5b, H.34 elsewhere). Neither seam may be exposed via `.Client` (Story 016 verifies).

---

## Out of Scope

- Story 003: grid data structure itself (this story consumes it, does not build it).
- Story 006: tier classification consuming the `fieldValue()` output (this story only produces the scalar).
- Story 008: `GetHottestHotspot`'s candidate scoring loop (consumes `fieldValue`/`contribution`, built in Story 008).

---

## QA Test Cases

- **AC-H.7**: Given: a Gather/Sprint/Light emission with `initialMagnitude=0.25` — When: evaluated at `age=30` (STANDARD_HALF_LIFE) — Then: `m(age) ≈ 0.125` ± 0.001. Edge case: `age=0` returns exactly `initialMagnitude`; `age` far beyond half-life (e.g. 3× half-life) returns the correctly-compounded decayed value, not a floor-clamped value.
- **AC-H.8**: Given: a Beacon emission with `initialMagnitude=0.95` — When: evaluated at `age=90` (BEACON_HALF_LIFE) — Then: `m(age) ≈ 0.475` ± 0.001.
- **AC-H.9**: Given: a source whose `m` has just dropped strictly below 0.02 — When: the next maintenance pass runs — Then: source removed from live-source list. Edge case: `m` exactly equal to 0.02 is NOT culled (strict less-than).
- **AC-H.9b**: Given: a wrapped `math.exp` counter, 100 sources, 50 query positions in one pass — When: the pass completes — Then: `math.exp` call count ≤ 100. Edge case: re-run the SAME pass's queries a second time without advancing the clock — the cached values must be reused, so the exp count should not increase further within that same pass.
- **AC-H.9c**: Given: wrapped `math.pow`/`math.sqrt` counters and a static-analysis pass — When: a pass over Q=20 query positions and one `GetHottestHotspot` call (C=5 candidates) completes — Then: `math.pow` count = 0; `^` operator count = 0 in the inner loop; `math.sqrt` count ≤ `30 × 26 = 780`. Edge case: a source that fails the `dist2DSquared` radius cull must NOT trigger a `math.sqrt` call at all.
- **AC-H.10**: Given: a source with `initialMagnitude = 0.02` exactly — When: queried at age=0 — Then: contributes its full negligible magnitude; culled only after decaying strictly below 0.02.
- **AC-H.11**: Given: single source at S with decayed `m` — When: queried at `dist2D=0` — Then: `fieldValue ≈ m` ± 0.001.
- **AC-H.12**: Given: single source — When: queried at exactly `dist2D = INFLUENCE_RADIUS` — Then: `fieldValue = 0.0` exactly (not approximately — the falloff term is exactly zero at the boundary by construction).
- **AC-H.13**: Given: single source — When: queried beyond `INFLUENCE_RADIUS` — Then: `fieldValue = 0.0` exactly.
- **AC-H.14**: Given: two sources S1, S2 both within range of P — When: `fieldValue(P)` computed — Then: result equals `contribution(P,S1)+contribution(P,S2)`. Edge case: both sources share the same `sourcePlayerId` — stacking is unaffected by shared ownership.
- **AC-H.15**: Given: enough sources to sum past 1.0 — When: `fieldValue(P)` returned — Then: clamped to 1.0 exactly; each individual source's stored `m` is verified unaffected (query the sources' raw `m` values directly, confirm no mutation from the clamp).
- **AC-H.16**: Given: two sources at identical XZ, differing Y (e.g. Y=0 and Y=40) — When: queried at a coplanar P — Then: both contribute identically based on XZ distance only.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/decay-falloff-fieldvalue_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 003
- Unlocks: 006, 007, 008, 014, 015

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: 12/12 passing (D.1-D.3, H.7-H.16, H.9b, H.9c)
**Deviations**: Introduced the `self._decayCache` cap-eviction leak found and fixed in code review (see ed-4's Completion Notes — same fix, one file). Lune's `math` table is read-only (cannot monkey-patch `math.sqrt` globally) — H.9c's sqrt-counting tests wrap `DecayFalloffLogic.dist2D` instead, documented in-file as a TESTABILITY NOTE. "Craft" `EmissionType`'s half-life is unspecified by H.7/H.8 — defaulted to `STANDARD_HALF_LIFE` (non-Beacon), documented as a SCOPE NOTE, confirmed "Craft" is a real schema value via grep. D.3's grid-neighborhood coverage independently re-verified against the G.7 invariant (`SPATIAL_GRID_CELL_SIZE=32 >= INFLUENCE_RADIUS=24`), confirmed the 3×3 query is provably sufficient.
**Test Evidence**: `tests/unit/ecological-disturbance/decay-falloff-fieldvalue_test.luau` — passing
**Code Review**: Complete (combined ed-4+ed-5 review) — CHANGES REQUIRED → fixed → clean

**Post-closure amendment (2026-07-08, found during ed-8's implementation)**: `FieldValueAt`'s clamp was `math.min(1.0, total)`, which silently laundered a NaN `total` into a finite `1.0` (Retreat-tier, maximum severity) instead of propagating the corruption, because Luau's `math.min(a,b)` returns `a` whenever `b` is NaN. Fixed same-day by swapping the argument order to `math.min(total, 1.0)`, with a dedicated regression test added to this story's own test file (`test_field_value_propagates_nan_total_instead_of_laundering_to_one`) plus a matching "+math.huge still clamps correctly" control test. `+math.huge` was never affected by this bug — only NaN. Independently verified by both the ed-7+ed-8 and ed-6+ed-14 code reviews (both confirmed no other `math.min`/`math.max` call in the epic has the same argument-order hazard).
