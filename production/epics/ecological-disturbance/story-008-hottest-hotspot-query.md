# Story 008: GetHottestHotspot Query & topContributorsAt

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-004` (`HotspotResult` exactly-6-field non-optional return, `hotspotId` stable cellKey), `TR-ed-034` (predator nav via `PathfindingService:FindPathAsync`; ED supplies targets only, never navigates itself), `TR-ed-046` (`GetHottestHotspot` caller-supplied position, nil-recovery), `TR-ed-055` (predator queries synchronous at PA's 4Hz; DisturbanceService cadence-agnostic, decoupled 5Hz field)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: `hotspot.id` tie-break comparisons (N11) use Luau's native string `<` operator (byte-lexicographic) — no numeric parse of the encoded cell coordinates. This is the GDD's own recommended pin, adopted verbatim.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: MEDIUM
**Engine Notes**: No new post-cutoff API — this is grid-traversal logic building directly on Story 003/005. Risk is MEDIUM because this is the query path Predator AI calls at a fixed 4Hz — correctness AND the `hotspotId` stability contract are both load-bearing for a system this epic doesn't own (Predator AI consumes it without re-deriving it).

**Control Manifest Rules (Core layer)**:
- Required: `hotspot.id` tie-break comparisons use Luau's native string `<` operator (byte-lexicographic), not a numeric parse of the encoded coordinates — source: ADR-0004
- Required: Predator AI consumes DisturbanceService's `GetHottestHotspot` / `GetSquadAggregateT(excludePlayer)` / `GetOnPlayerDiedSignal()` via the frozen, ADR-specified contracts — do not re-derive or rename them — source: ADR-0004 (Feature-layer rule, cited here because this story is the producer side of that contract)

---

## Acceptance Criteria

- [ ] **`GetHottestHotspot(callerPosition, searchRadius, minimumTier): HotspotResult?`** — position supplied by the caller (Predator AI), NOT pulled via `Knit.GetService` — preserves the "no MVP-internal hard dependencies" architecture rule.
- [ ] **`HotspotResult`** has exactly 6 required (non-optional) fields when non-nil: `position`, `fieldValue`, `hotspotId`, `topContributingEmissionIds` (1–3 entries, `#list >= 1` guaranteed), `hotspotCount`, `oldestContributorAge`. Returns nil only when no candidate meets `minimumTier`.
- [ ] **`hotspotId`** is the D.6 dedup cellKey of `bestPosition` (`string.format("%d_%d", floor(X/k), floor(Z/k))`, k=`HOTSPOT_DEDUP_GRID_SIZE`) — stable across successive queries while the winning dedup cell is unchanged, even when the representative position within the cell shifts.
- [ ] **H.23** — GIVEN no live sources exist anywhere, WHEN `GetHottestHotspot(callerPosition, searchRadius, "Tense")` called with any finite `callerPosition`, THEN returns `nil` and does not error.
- [ ] **H.24** — GIVEN multiple live sources but none produce `fieldValue` at/above `tierFloor` for `minimumTier`, WHEN `GetHottestHotspot()` called, THEN returns `nil`.
- [ ] **H.25** — GIVEN three live sources within `searchRadius` where source A produces the highest `fieldValue`, WHEN `GetHottestHotspot()` returns a result, THEN `result.fieldValue` matches `fieldValue(A.position)` ± 0.001 and `result.topContributingEmissionIds` contains A's `emissionId` first.
- [ ] **H.25b** — GIVEN any config causing `GetHottestHotspot()` to return non-nil, WHEN inspected, THEN `#result.topContributingEmissionIds >= 1` AND `result.topContributingEmissionIds[1]` is a valid `emissionId` matching the H.1 UUID regex and resolves in the live-source list.
- [ ] **H.25c** — GIVEN a live-source configuration where D.3 evaluation at one candidate yields NaN or `+math.huge` at the D.6 scoring loop, AND a second legitimate finite candidate scoring 0.70 exists, AND a connected player P_probe positioned within `INFLUENCE_RADIUS` of the corrupted source such that `fieldValue(P_probe.position)` routes through the corrupted contribution, WHEN `GetHottestHotspot(callerPosition, searchRadius, "Tense")` called, THEN: (a) the non-finite candidate is disqualified — never sets bestPosition, never increments `hotspotCount`, never returned; (b) returned result is the legitimate candidate (fieldValue=0.70±0.001); (c) with the legitimate candidate removed, the same call returns `nil` (not a fabricated 0.0); (d) under the corrupted config with P_probe placement, `squadT = 0.0` publishes (both nil and exclusion argument forms), AND P_probe's `OnMeterUpdate` carries `playerT = 0.0` — never NaN/+Inf.
- [ ] **H.25d** — GIVEN a config where dedup cell K1 wins AND the harness advances the clock so the first-encountered source in K1 expires while another source in the SAME cell keeps K1 winning, WHEN two successive `GetHottestHotspot` calls are made (one before, one after turnover), THEN: (a) both results carry the identical `hotspotId` even though `result.position` may differ; (b) `hotspotId` matches the canonical dedup-key format (regex `^%-?%d+_%-?%d+$`); AND GIVEN a different cell K2 wins in a follow-up config, WHEN queried, THEN `hotspotId` differs from K1's.
- [ ] **Non-finite output prohibition**: a returned non-nil `HotspotResult` ALWAYS satisfies `fieldValue == fieldValue and fieldValue ~= math.huge` AND meets the caller's `minimumTier`.
- [ ] `secondBestPosition` is explicitly NOT implemented (removed for MVP per the GDD — no flank/distract mechanic at launch).
- [ ] `topContributorsAt(P, n)` returns `({}, 0)` when P has zero live contributors; returns at least 1 `emissionId` in the first slot when P has ≥1 live contributor.

---

## Implementation Notes

Full normative pseudocode (D.6 — cite verbatim, production body lives in this story, not re-derived from scratch):
```luau
function GetHottestHotspot(callerPosition: Vector3, searchRadius: number, minimumTier: Tier): HotspotResult?
    local tierFloor = tierLowerBound(minimumTier) -- Calm:0.00, Tense:0.30, Hunt:0.65, Retreat:1.00
    local candidatePositions = {}
    for source in liveSourcesInGridCellsIntersecting(callerPosition, searchRadius) do
        if dist2DSquared(callerPosition, source.position) <= searchRadius * searchRadius then
            table.insert(candidatePositions, source.position)
        end
    end
    candidatePositions = deduplicateByFloorSnap(candidatePositions, HOTSPOT_DEDUP_GRID_SIZE)
    local bestPosition, bestScore = nil, -1
    local hotspotCount = 0
    for _, C in ipairs(candidatePositions) do
        local score = fieldValue(C)
        if score ~= score or score == math.huge then continue end -- non-finite: disqualify (H.25c)
        if score >= tierFloor then
            hotspotCount = hotspotCount + 1
            if score > bestScore then bestScore, bestPosition = score, C end
        end
    end
    if bestPosition == nil then return nil end
    local topEmissions, oldestContributorAge = topContributorsAt(bestPosition, 3)
    return {
        position = bestPosition, fieldValue = bestScore, hotspotId = dedupCellKey(bestPosition),
        topContributingEmissionIds = topEmissions, hotspotCount = hotspotCount,
        oldestContributorAge = oldestContributorAge,
    }
end
```
Dedup snap-method (canonical, MUST use `string.format`, not tuple-as-key — the latter is invalid Luau):
```luau
local k = HOTSPOT_DEDUP_GRID_SIZE
local cellKey: string = string.format("%d_%d", math.floor(P.X / k), math.floor(P.Z / k))
```
The retained position for each unique `cellKey` is the first candidate encountered in enumeration order (deterministic given deterministic source iteration order). This story does NOT implement `PathfindingService:FindPathAsync` — that belongs entirely to Predator AI; ED supplies `position` as a target, never navigates (TR-ed-034).

`hotspot.id` tie-break comparisons (used by Predator AI, not by this story directly, but this story's `hotspotId` format is what makes the tie-break possible) use Luau's native string `<` — document this in the returned type's doc comment so Predator AI implementers don't re-derive a numeric-parse comparison.

---

## Out of Scope

- Story 003: grid cell enumeration mechanism itself (this story consumes `liveSourcesInGridCellsIntersecting`).
- Story 005: `fieldValue`/`contribution` math (this story calls into it, doesn't reimplement it).
- Predator AI's own consumption of the returned `HotspotResult` (out of this epic — the nil-recovery posture, path-stability rule, and attribution-refresh rule are all Predator AI GDD obligations, not ED implementation).

---

## QA Test Cases

- **AC-H.23**: Given: zero live sources — When: `GetHottestHotspot(pos, 200, "Tense")` called with any finite position — Then: returns `nil`, no error. Edge case: `callerPosition` at the world origin, at extreme-but-finite coordinates (1e10), and negative coordinates — all should behave identically.
- **AC-H.24**: Given: several live sources, none reaching the Tense floor (0.30) — When: `GetHottestHotspot(pos, r, "Tense")` called — Then: returns `nil`.
- **AC-H.25**: Given: 3 sources within `searchRadius`, source A scoring highest — When: queried — Then: `result.fieldValue ≈ fieldValue(A.position)` ± 0.001; `result.topContributingEmissionIds[1] == A.emissionId`.
- **AC-H.25b**: Given: any non-nil-producing config — When: inspected — Then: `#topContributingEmissionIds >= 1`, first entry matches the UUID regex and resolves in the live-source list. Edge case: negative path — when nil is returned, no `topContributingEmissionIds` field is exposed/accessed.
- **AC-H.25c**: Given: one corrupted (NaN or +Inf) candidate + one legitimate 0.70 candidate + a P_probe near the corrupted source — When: `GetHottestHotspot` called — Then: (a) corrupted candidate never selected/counted; (b) legitimate 0.70 candidate returned; (c) removing the legitimate candidate yields `nil` (not fabricated 0.0); (d) `squadT` and P_probe's `playerT` both publish as 0.0, never NaN/+Inf, in both nil and exclusion argument forms of `GetSquadAggregateT`. Edge case (falsifiability control): run the test with a NaN-flavored corruption AND separately with a `+math.huge`-flavored corruption — both must independently pass; also directly call `fieldValue(P_probe.position)` and assert it is non-finite before asserting the downstream 0.0 fail-quiet behavior (proves the guard is actually engaging, not vacuously passing).
- **AC-H.25d**: Given: dedup cell K1 wins, first-encountered source in K1 expires while a second K1 source keeps K1 winning — When: queried before and after turnover — Then: `hotspotId` identical across both calls even though `position` may shift; format matches `^%-?%d+_%-?%d+$`. Given: a different cell K2 wins in a follow-up scenario — When: queried — Then: `hotspotId` differs from K1's. Edge case: negative-coordinate cells (verify the regex and the `%d_%d` format correctly represent negative cell indices, e.g. `"-3_2"`).
- **AC — non-finite output prohibition**: Given: any query that would otherwise produce a non-finite `fieldValue` — When: `GetHottestHotspot` returns — Then: either `nil` or a result whose `fieldValue` passes the finiteness check AND meets `minimumTier`. No result is ever returned with a `fieldValue` below `tierFloor` due to a corrupted read slipping through.
- **AC — `topContributorsAt` zero/nonzero contract**: Given: a position P with zero live contributors within `INFLUENCE_RADIUS` — When: `topContributorsAt(P, 3)` called — Then: returns `({}, 0)`. Given: P with ≥1 live contributor — When: called — Then: returns at least 1 `emissionId` in slot 1.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/hottest-hotspot-query_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 003, 005
- Unlocks: 010, 011, 017

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: All ACs COVERED (H.23, H.24, H.25, H.25b, H.25c incl. both NaN/+Inf falsifiability controls, H.25d, non-finite output prohibition, `secondBestPosition` correctly absent, `topContributorsAt` zero/nonzero contract)
**Deviations**: Added a new `QueryCellsInRadius` primitive (`DisturbanceServiceSpatialGridLogic.luau`) instead of reusing the fixed 3×3 `QueryNeighborhood` — code review independently verified this is required by the GDD's own `searchRadius`-scaled cost model (32-512 stud range), and that ADR-0004's literal wording (implying a fixed 3×3 scan for this function too) is the inaccurate one, not the implementation. Logged as **TD-008** (documentation-only ADR-0004 fix needed). Also discovered and fixed a real NaN-laundering bug in the already-closed `ed-5` module during this story's own testing (see ed-5's amended Completion Notes / this session's history).
**Test Evidence**: `tests/unit/ecological-disturbance/hottest-hotspot-query_test.luau` — passing
**Code Review**: Complete (combined ed-7+ed-8 review) — APPROVED WITH SUGGESTIONS
