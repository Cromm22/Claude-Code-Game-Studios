<!-- determinism hook self-test fixture: BROKEN (DET-2). Reproduces the recurring
     band-literal drift: the H.105 config-gate AC carries the stale decimal-less
     band [35,70] and the pre-round-22 crash predicate <= 70.0 instead of the
     canonical [35.0, 70.1] / <= 70.1. check_det2() MUST report a band failure. -->

# Fixture GDD (minimal)

## Acceptance Criteria

> **Determinism preamble (fixture):** every time-dependent AC is driven by the C.16 `_clock`/`_step` seam and asserts exact values, never `task.wait`. The bit-exact-equality cluster is **H.27, H.29**; the time-driven cluster includes **H.116**. **H.39** (a `>=` crossing test) is deliberately NOT in the enumeration.

**H.27 [P0] — craft progress exact at the dwell boundary (clock-boundary)**
- **GIVEN** `_clock() = rateAnchorClock + 10.0`
- **THEN** `craftProgress == 1.0` **exactly** — bit-exact, no tolerance
- **Test type**: Logic

**H.29 [P0] — progress clamped at 1.0, does not overflow**
- **GIVEN** `_clock() = rateAnchorClock + 10.0017`
- **THEN** `craftProgress` clamped to exactly 1.0
- **Test type**: Logic

**H.116 [P0] — activation signals carry windowDurationSeconds**
- **GIVEN** via the C.16 seam, `_clock()` controlled at BCT3
- **THEN** `timestamp == _clock()` at activation
- **Test type**: Logic

**H.105 [P0] — abort if the derived survival window is outside [35,70]s**
- **GIVEN** `CraftingService` init with a resolved `BEACON_HALF_LIFE`; the enforced predicate is `<= 70.0`
- **THEN** init aborts when the derived window falls outside `[35,70]` s
- **Test type**: Logic
