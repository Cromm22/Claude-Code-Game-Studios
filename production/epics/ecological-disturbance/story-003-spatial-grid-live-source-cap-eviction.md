# Story 003: Spatial Hash Grid, Live-Source List & Cap Eviction

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-001` (table-of-tables spatial hash grid, 3×3 neighborhood scan), `TR-ed-002` (live-source list half of the two-store model), `TR-ed-019` (`MAX_LIVE_SOURCES=500` hard cap + cap-hit policy)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: A plain Luau table-of-tables spatial hash grid, keyed by integer cell coordinates (`grid[cellX][cellZ] = {sourceId, ...}`), cell size 32 studs. `Region3` is explicitly rejected. Cap-eviction is **oldest-first** (by `emissionTime` ascending) — this is now settled ADR text, not an open question: when a new emission would push the live-source count past 500, the single oldest live source is evicted to make room; the new emission is never refused. This directly supersedes the GDD's own H.35b prose ("drop-new... Q3"), which the epic's 2026-07-06 update marks RESOLVED in favor of the ADR's evict-oldest policy.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: HIGH
**Engine Notes**: No post-cutoff API risk — this is a pure data-structure decision (plain Luau tables), deliberately chosen to sidestep any Roblox physics-query API. The risk classification is HIGH because this is "the busiest module in the game" per `architecture.md` — every downstream system's correctness depends on getting the grid right once.

**Control Manifest Rules (Core layer)**:
- Required: DisturbanceService's spatial index is a plain Luau table-of-tables hash grid, keyed by integer cell coordinates, cell size `SPATIAL_GRID_CELL_SIZE = 32` studs; a source's cell is computed once at emission and only recomputed if its position is later mutated — source: ADR-0004
- Required: Cap-eviction at `MAX_LIVE_SOURCES = 500`: evict the single oldest live source (by `emissionTime`, ascending) to make room for a new emission — never refuse the new emission — source: ADR-0004
- Forbidden: Never use `Region3`/`Workspace:FindPartsInRegion3` for DisturbanceService's spatial queries — sources are pure data, not physical Instances — source: ADR-0004
- Guardrail: `GetHottestHotspot`/`fieldValue()` touch only ~4–9 grid cells per query — source: ADR-0004

---

## Acceptance Criteria

- [ ] **C.1.6** — a flat 2D grid (32×32-stud cells, XZ plane) over active emissions is maintained. Each emission is inserted into its containing cell on creation and removed on expiry. A query at position P reads only cells whose nearest point is within `INFLUENCE_RADIUS` of P — with defaults, up to 9 cells (3×3 neighborhood centered on P's cell).
- [ ] A source's cell is computed once at emission time (`cellX = floor(position.X / 32)`, `cellZ = floor(position.Z / 32)`) and only recomputed if the source's position field is later mutated (sources are otherwise immutable once emitted).
- [ ] **H.35b** — GIVEN exactly `MAX_LIVE_SOURCES` live sources exist, WHEN an additional `Emit()` arrives, THEN — **per ADR-0004, superseding the GDD's own "drop-new" prose** — the single oldest live source (by `emissionTime`, ascending) is evicted from both the live-source list and its grid cell bucket, and the new emission is inserted successfully. The call returns without error; a server-side ops-log entry records the eviction (`sourcePlayerId`/`emissionType`/cap-hit timestamp of the evicted source).
- [ ] Eviction removes the evicted source from both the live-source list and its grid cell bucket; the write-once attribution archive entry for the evicted source is unaffected (Story 004 owns archive independence).
- [ ] The grid backs both `fieldValue()` queries (Story 005) and `GetHottestHotspot` candidate enumeration (Story 008) — not a full linear scan over all live sources in either case.

---

## Implementation Notes

Key interface (ADR-0004, cite verbatim):
```luau
--!strict
type SourceId = string
type SpatialGrid = {[number]: {[number]: {SourceId}}}  -- grid[cellX][cellZ] = flat list of source ids

local SPATIAL_GRID_CELL_SIZE = 32
local function cellCoordFor(position: Vector3): (number, number)
    return math.floor(position.X / SPATIAL_GRID_CELL_SIZE),
           math.floor(position.Z / SPATIAL_GRID_CELL_SIZE)
end
```
Cap-eviction policy is **binding**, not a tuning choice: when insertion would exceed `MAX_LIVE_SOURCES = 500`, find and remove the single oldest live source by `emissionTime` ascending, then insert the new one. A naive O(N) linear scan for "oldest" is acceptable at N=500 (this is not the hot path — cap-hits are rare in normal play per H.36's ~207-source steady-state expectation); do not over-engineer a priority-queue unless profiling in Story 017 shows this is load-bearing.

Do not implement the GDD's H.35b prose literally ("emission dropped") — the ADR is the authoritative decision here per the epic's resolved-conflicts note; write the test to assert eviction, not rejection.

---

## Out of Scope

- Story 002: emission schema validation happens before a source ever reaches the grid.
- Story 004: the write-once attribution archive, which is a separate store with independent lifecycle rules (archive entries survive live-source eviction/expiry).
- Story 005: decay math and `fieldValue()` summation (this story only owns storage/retrieval structure, not the contribution formula).
- Story 017: performance profiling of grid query cost under H.36/H.38/H.38b clustered-source conditions.

---

## QA Test Cases

- **AC — grid membership/query**: Given: a source emitted at position P — When: `fieldValue()` or `GetHottestHotspot` queries a nearby position Q within `INFLUENCE_RADIUS` — Then: the grid query touches only the 3×3 cell neighborhood around Q's cell, and the source is discoverable via that neighborhood scan (not a full-list linear scan). Edge cases: a source exactly on a cell boundary (verify `math.floor` handles negative coordinates correctly — a position at X=-0.5 must floor to cell -1, not 0); a query position at the extreme edge of `INFLUENCE_RADIUS` from a cell it doesn't share.
- **AC-H.35b (corrected to evict-oldest)**: Given: exactly 500 live sources with distinct, ascending `emissionTime`s — When: a 501st `Emit()` call arrives — Then: the source with the smallest (oldest) `emissionTime` is removed from both the live-source list and its grid cell; the new source is present in the live-source list and its grid cell; total count remains 500; an ops-log entry records the eviction. Edge cases: two sources with an identical `emissionTime` (tie-break must be deterministic — document and test the chosen tie-break, e.g. insertion order); the evicted source is the ONLY occupant of its grid cell (verify the cell's bucket, not just the source, is cleaned up — an empty-bucket cell should not persist as dead weight, though this is a hygiene concern rather than correctness).
- **AC — eviction independence from archive**: Given: a source is evicted per the above — When: the attribution archive is queried for that source's `emissionId` — Then: the archive entry (written independently at `Emit()` time per Story 002/004) is still present and resolvable, unaffected by the live-source eviction.
- **AC — no client-callable path**: Given: the spatial grid's insertion/removal/query methods — When: inspected for `.Client` surface — Then: none of the grid's internal methods appear on `DisturbanceService.Client` (structural precondition for Story 016).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/spatial-grid-live-source-cap-eviction_test.luau` — must exist and pass
**Status**: [x] Created and passing — verified 2026-07-07 via `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` (exit code 0, 5/5 test files pass, 0 failures).

---

## Dependencies

- Depends on: 001, 002
- Unlocks: 004, 005, 008

---

## Completion Notes
**Completed**: 2026-07-07
**Criteria**: 5/5 passing
**Deviations**: None blocking. One documented, pre-approved ADR-drift: `CellCoordFor(position, cellSize?)` deviates from ADR-0004's cited verbatim single-argument signature — justified to avoid `SPATIAL_GRID_CELL_SIZE` (a genuine G.3 tuning knob) becoming a second, driftable source of truth; production call sites always pass `DisturbanceConstants.SPATIAL_GRID_CELL_SIZE` explicitly. Three real gaps found by `/code-review` and fixed in the same pass: (1) `InsertEmission` had no documented precondition against duplicate-`emissionId` re-insertion — added a precondition doc-comment explaining why it's structurally unreachable today (Story 002's fresh-GUID-per-call guarantee) and what a future relaxation of that guarantee would require; (2) the cap-eviction `warn()` ops-log call site had zero test coverage — added a static structural check; (3) `InsertEmission`'s unconditional `liveCount` full-table scan (distinct from the story's own pre-approved O(N) allowance, which only covered the cap-triggered oldest-lookup) was undocumented — added an explicit accepted-tradeoff comment with an escalation path to Story 017's profiling.
**Test Evidence**: Logic: `tests/unit/ecological-disturbance/spatial-grid-live-source-cap-eviction_test.luau` — created and genuinely executed passing (21 test functions across 5 `describe()` blocks; full suite re-confirmed green after every code-review fix).
**Code Review**: Complete (`/code-review`, this session) — engine specialist verdict CLEAN (hand-traced every algorithm: cell math, eviction ordering, tie-break order-independence, grid hygiene, archive independence — all confirmed correct against the actual code, not just test assertions); QA testability verdict GAPS, all closed same-session. Forward obligation flagged for Story 004: once the real attribution archive exists, add a behavioral test (not just the current static/structural proof) confirming an evicted source's archive entry remains resolvable.
