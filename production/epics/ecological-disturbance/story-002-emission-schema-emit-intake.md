# Story 002: Emission Schema & Server-Authoritative Emit() Intake

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-003` (EmissionPayload fixed 7-field record), `TR-ed-025` (canonical clock), `TR-ed-027` (emissionId via GUID), `TR-ed-043` (`Emit()` signature, fire-and-forget), `TR-ed-061` (server sole authority, plain tables), `TR-ed-062` (no client-callable Emit path), `TR-ed-065` (full schema validation)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: `Emit()` is a server-internal method — no `RemoteEvent`/`RemoteFunction`/`BindableEvent`/`.Client` method may trigger or proxy a call to it. Note the epic's flagged gap: ADR-0004 never enumerates `Emit`'s exact signature — this story's canonical signature is `Emit(emissionType: EmissionType, position: Vector3, initialMagnitude: number, sourcePlayerId: number, attributionChain: {string})`, taken directly from GDD C.1.2 and the C.3.1/C.3.2 publisher call-site prose.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: MEDIUM
**Engine Notes**: `HttpService:GenerateGUID(false)` is the mandated `emissionId` generator (non-braced UUID). `workspace:GetServerTimeNow()` is the sole permitted clock source for `emissionTime` — `os.time()`, `tick()`, and `os.clock()` are all forbidden on this path (D.1's clock spec; `os.clock()` is not guaranteed wall-clock on server processes).

**Control Manifest Rules (Core layer)**:
- Required: Emission data lives as plain Luau tables inside `DisturbanceService` — never stored in Instance attributes or `Workspace` descendants (StreamingEnabled would silently drop it) — source: GDD C.1.8
- Forbidden: Never let any client-writable surface trigger or proxy `Emit()` — an exploit-class regression reviewers MUST reject — source: GDD C.1.8, enforced by Story 016's H.39/H.39d
- Guardrail: `emissionId` collision probability is effectively zero (~144,000 IDs/20-min session vs 2^122 ID space) — not explicitly checked, treated as unreachable — source: GDD E.20

---

## Acceptance Criteria

- [ ] **H.1** — GIVEN the server receives an `Emit()` call with all seven required payload fields populated and `initialMagnitude > 0`, WHEN `DisturbanceService:Emit()` processes the call, THEN a new point source is inserted into the live-source list with `emissionId` matching the standard UUID 8-4-4-4-12 hex format (regex: `^[%x]{8}%-[%x]{4}%-[%x]{4}%-[%x]{4}%-[%x]{12}$`, version-agnostic), `emissionTime` equal to `workspace:GetServerTimeNow()` sampled at insertion, and all other fields matching the call's arguments exactly.
- [ ] **H.2** — GIVEN the server receives an `Emit()` call with any one of the seven required payload fields missing or null, WHEN the call is processed, THEN the call is rejected, no point source is inserted, and a server-side error log entry is written identifying the missing field.
- [ ] **H.3** — GIVEN an `Emit()` call with `initialMagnitude = 0` or `< 0`, WHEN schema validation runs, THEN the emission is rejected and no source is inserted, regardless of other fields being valid.
- [ ] **H.3b** — GIVEN an `Emit()` call where `position.X/Y/Z` is (a) NaN (`0/0`), (b) +Infinity, or (c) −Infinity, AND a separate 4th invocation where `initialMagnitude` is NaN, AND a separate 5th invocation where `initialMagnitude` is +Infinity, WHEN schema validation runs on each invocation independently, THEN each emission is rejected, no source inserted, no archive entry written, and a server-side error log records `sourcePlayerId`, `emissionType`, and offending axis. Each of the five cases MUST be a separately-asserted invocation.
- [ ] **H.3c** — GIVEN an `Emit()` call whose `emissionType` is not in the canonical enum `{Gather, Sprint, Light, Beacon, Craft}`, WHEN schema validation runs, THEN the emission is rejected and no source inserted.
- [ ] **H.6** — GIVEN a Beacon emission is submitted with `initialMagnitude` below 0.85, WHEN schema validation runs, THEN the emission is rejected — values below 0.85 are reserved exclusively for non-Beacon types.
- [ ] **H.6b** — GIVEN a non-Beacon emission (`{"Gather","Sprint","Light","Craft"}`) is submitted with `initialMagnitude > 0.85`, WHEN schema validation runs, THEN the emission is rejected (reverse-direction check to H.6).
- [ ] **H.7b** — GIVEN the harness has installed a counter wrapping `workspace:GetServerTimeNow()` AND `os.time()` AND `tick()` AND `os.clock()`, WHEN exercising `Emit()`, THEN within that scope `os.time()`, `tick()`, `os.clock()` were called zero times and `workspace:GetServerTimeNow()` was the sole clock source. (Out-of-scope: ops-log timestamp formatting using `os.time()` is not flagged.)
- [ ] No client-reachable `RemoteEvent`/`RemoteFunction`/`BindableEvent`/`.Client` method calls `Emit()` directly or indirectly (structural precondition for Story 016's H.39/H.39d — this story must not introduce any such path).

---

## Implementation Notes

Published Luau types (canonical, GDD C.1.2 — cite directly, do not re-derive):
```luau
--!strict
type EmissionType = "Gather" | "Sprint" | "Light" | "Beacon" | "Craft"

type EmissionPayload = {
    emissionId: string,
    sourcePlayerId: number,
    emissionType: EmissionType,
    position: Vector3,
    initialMagnitude: number,
    emissionTime: number,
    attributionChain: {string},
}
```
NaN/Infinity detection idiom (REQUIRED, GDD E.16 — use verbatim):
```luau
local function isFinite(n: number): boolean
    return n == n and n ~= math.huge and n ~= -math.huge
end
```
The schema validator MUST call `isFinite` on `position.X/Y/Z` and on `initialMagnitude`, rejecting if any axis fails. Attribution chain length cap (`{string}` length ≤ 4) is a runtime validation, not a Luau type constraint. `emissionId` is generated server-side via `HttpService:GenerateGUID(false)` — never accept a caller-supplied ID (E.20). `emissionTime` is written from `workspace:GetServerTimeNow()` at insertion — the same clock source D.1's decay math reads from (Story 005 depends on this consistency).

Guarantee: emission recorded server-side **before** the gather reward is granted (C.3.1 emit-before-reward ordering) — if the emit call fails, the gather is still granted; disturbance failure is non-blocking for gameplay. Fire-and-forget: no acknowledgment returned to the caller.

---

## Out of Scope

- Story 003: actual insertion into the spatial hash grid (this story validates and constructs the `EmissionPayload`; Story 003 owns the grid-cell placement).
- Story 004: writing the corresponding write-once attribution archive entry (this story's `Emit()` call is the trigger point, but the archive's own lifecycle rules are Story 004's scope).
- Story 016: the H.39/H.39d/H.39e CI lint gates that *enforce* the no-client-Emit rule mechanically (this story only ensures no such path is introduced by this story's own code).

---

## QA Test Cases

- **AC-H.1**: Given: a well-formed `Emit()` call with all 7 fields, `initialMagnitude=0.25` — When: `DisturbanceService:Emit(...)` is called — Then: live-source list gains one entry; `emissionId` matches the UUID regex; `emissionTime == workspace:GetServerTimeNow()` at call time. Edge cases: `initialMagnitude` exactly at `MAGNITUDE_FLOOR` (0.02, should still insert); `attributionChain` length exactly 4 (accept) and 5 (should this reject? — verify against the runtime cap).
- **AC-H.2**: Given: an `Emit()` call omitting `attributionChain` — When: processed — Then: rejected, no source inserted, error log identifies `attributionChain` as missing. Edge cases: each of the 7 fields tested missing independently, one test per field (not a single combined test).
- **AC-H.3**: Given: `initialMagnitude = 0` — When: validated — Then: rejected. Edge case: `initialMagnitude = -0.0001` also rejected; `initialMagnitude = 0.0001` (just above zero) accepted.
- **AC-H.3b**: Given: 5 separate invocations, each violating exactly one of {NaN position, +Inf position, -Inf position, NaN magnitude, +Inf magnitude} — When: each is validated independently — Then: each rejected independently with the correct offending-axis logged. Edge case: a single payload violating all 5 simultaneously must NOT be used as a substitute for the 5 separate assertions (short-circuit risk).
- **AC-H.3c**: Given: `emissionType = "Explosion"` (not in canonical enum) — When: validated — Then: rejected. Edge case: case-sensitivity — `"gather"` (lowercase) should also be rejected, since the enum is exact-string-match.
- **AC-H.6**: Given: `emissionType="Beacon"`, `initialMagnitude=0.80` — When: validated — Then: rejected. Edge case: exactly `0.85` (boundary) — per C.1.2 "values above 0.85 are reserved" wording, confirm whether 0.85 itself is Beacon-exclusive or shared; test both `0.849` (non-Beacon-legal) and `0.850` explicitly.
- **AC-H.6b**: Given: `emissionType="Gather"`, `initialMagnitude=0.90` — When: validated — Then: rejected (reverse check). Edge case: boundary at exactly 0.85 for non-Beacon types.
- **AC-H.7b**: Given: a clock-source call-counter wrapping all four Roblox time APIs — When: `Emit()` is called — Then: `workspace:GetServerTimeNow()` count increases by exactly 1 (or the expected count for this call path), and `os.time`/`tick`/`os.clock` counts remain unchanged. Edge case: verify the counter captures calls made transitively (helper functions Emit() calls internally), not just the top-level frame.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/emission-schema-server-emit-intake_test.luau` — must exist and pass
**Status**: [x] Created and passing — verified 2026-07-07 via `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` (exit code 0, 4/4 test files pass, 0 failures).

---

## Completion Notes
**Completed**: 2026-07-07
**Criteria**: 9/9 passing
**Deviations**: None blocking. Two advisory items found by `/code-review` and fixed in the same pass: (1) `DisturbanceServiceEmissionLogic.luau`'s header comment mis-cited ADR-0004 as enumerating `Emit()` in its public-surface diagram (it doesn't — corrected to cite this story's own Context section instead); (2) `self._liveSources` was typed `{[string]: any}` despite `EmissionPayload` now existing — tightened to `{[string]: EmissionLogic.EmissionPayload}`. One real, currently-non-manifesting test-harness bug also found and fixed: the test file's `stripLuaComments` static-check helper used a naive first-`--`-match that would have silently truncated `DisturbanceService.luau`'s own `Emit()`-rejection `warn()` message (which used `--` as a visual separator) — fixed by rewording the message to use `:` instead, and by correcting the test file's own overconfident safety-claim comment. Accepted scope call (not a deviation): `BEACON_MAGNITUDE_RESERVED_BOUNDARY`/`ATTRIBUTION_CHAIN_MAX_LENGTH` kept local to `DisturbanceServiceEmissionLogic.luau` rather than `DisturbanceConstants.luau`, per the same `script.Parent`-require harness limitation Story 001 already established a precedent for.
**Test Evidence**: Logic: `tests/unit/ecological-disturbance/emission-schema-server-emit-intake_test.luau` — created and genuinely executed passing (39 test functions; full suite re-confirmed green after all code-review fixes were applied).
**Code Review**: Complete (`/code-review`, this session) — verdict APPROVED WITH SUGGESTIONS, all suggestions applied before closure. No architectural violations found; validation ordering, the 0.85 shared-boundary interpretation, and the clock/GUID injection seam were all independently verified correct by the engine specialist.

---

## Dependencies

- Depends on: 001
- Unlocks: 003, 004
