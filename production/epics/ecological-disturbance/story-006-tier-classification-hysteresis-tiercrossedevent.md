# Story 006: Tier Classification with Hysteresis, TierCrossedEvent & Post-Hitch Cascade

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-011` (`previousTierAtPosition` keyed by canonical `%d_%d` string), `TR-ed-037` (server-internal `TierCrossedEvent`, position-keyed, coalesced), `TR-ed-054` (post-hitch multi-tier cascade settle loop), `TR-ed-070` (stateful tier classification: hysteresis ±0.03 downward-only + first-call flat-threshold dispatch)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: This story implements the GDD's own D.4 formula and C.3.3 notification rule directly — no ADR-level deviation. The `hotspot.id` string-comparison convention (N11) belongs to Story 008, not here.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: No engine-API risk — pure state-machine logic. The only implementation hazard flagged by the GDD itself is keying the `previousTierAtPosition` table by Vector3 directly (Luau userdata uses reference equality, not value equality) — MUST key by the canonical `%d_%d` string instead.

**Control Manifest Rules (Core layer)**:
- No dedicated Core-layer manifest line names tier classification specifically; the closest applicable rule is the general "server-internal, never `.Client`" discipline that governs `TierCrossedEvent` — enforced structurally here and verified by Story 016.

---

## Acceptance Criteria

- [ ] **D.4 Tier Classification**: `tierAt(P: Vector3, previousTier: Tier): Tier` is a PURE function — callers always supply `previousTier`; holds no internal state itself. Tier boundaries: Calm/Tense at 0.30, Tense/Hunt at 0.65, Hunt/Retreat at 1.00; hysteresis band ±0.03 on every boundary, downward transitions only.
- [ ] **First-call rule**: for any position whose tier has never been classified before, callers MUST pass `previousTier = "Calm"`. On the Calm branch, the function dispatches by flat-threshold (no hysteresis applied).
- [ ] **H.17** — GIVEN a position whose `fieldValue` rises from below `TENSE_THRESHOLD` to exactly `TENSE_THRESHOLD`, WHEN `tierAt(P, "Calm")` evaluated, THEN returns "Tense" (no upward hysteresis).
- [ ] **H.17b** — GIVEN `fieldValue = 0.85` AND `previousTier = "Calm"`, WHEN `tierAt(P, "Calm")` evaluated, THEN returns "Hunt" — confirms flat-threshold dispatch on the Calm branch (single-step ladder bypassed only on first-call).
- [ ] **H.17c** — GIVEN `fieldValue = 1.00` AND `previousTier = "Calm"`, WHEN `tierAt(P, "Calm")` evaluated, THEN returns "Retreat".
- [ ] **H.18** — GIVEN a position in "Tense" whose `fieldValue` falls to `TENSE_THRESHOLD − HYSTERESIS_BAND + 0.001`, WHEN `tierAt(P, "Tense")` evaluated, THEN remains "Tense".
- [ ] **H.19** — GIVEN a position in "Tense" whose `fieldValue` falls strictly below `TENSE_THRESHOLD − HYSTERESIS_BAND`, WHEN `tierAt(P, "Tense")` evaluated, THEN returns "Calm".
- [ ] **H.20** — GIVEN `tierAt()` called with `previousTier="Hunt"` and `fieldValue` at `HUNT_THRESHOLD − HYSTERESIS_BAND − 0.001`, WHEN evaluated, THEN returns "Tense" — Hunt→Tense hysteresis independent of Tense→Calm.
- [ ] **H.21** — GIVEN a position in "Retreat" whose `fieldValue` decays to `1.0 − HYSTERESIS_BAND − 0.001`, WHEN `tierAt(P, "Retreat")` evaluated, THEN returns "Hunt".
- [ ] **Canonical key encoding (REQUIRED)**: the `previousTierAtPosition` table MUST be keyed by `string.format("%d_%d", math.floor(P.X), math.floor(P.Z))`, NOT the Vector3 `P` directly, and NOT `tostring(P)`.
- [ ] **Post-hitch multi-tier cascade (REQUIRED)**: the field-update pass loops classification until it converges (at most 4 iterations, worst case Retreat→Hunt→Tense→Calm), firing one `TierCrossedEvent` per boundary crossed subject to per-pass coalescing.
- [ ] **H.34b** — GIVEN `previousTierAtPosition[P] = "Retreat"` AND a simulated hitch drops `fieldValue(P)` from 1.00→0.20 in one step AND a mock Predator AI subscribes to `TierCrossedEvent`, WHEN the pass completes its settle loop, THEN: (a) `previousTierAtPosition[P]` set to "Calm" (NOT "Hunt"); (b) exactly three `TierCrossedEvent`s fire (Hunt, Tense, Calm), subject to coalescing; (c) cascade terminates in ≤4 iterations.
- [ ] **H.34** — GIVEN a position oscillates across a boundary alternating `TENSE_THRESHOLD ± 0.01` across four ticks, WHEN tier classification runs with hysteresis, THEN `TierCrossedEvent` fires at most twice.
- [ ] **C.3.3 server-side per-pass coalescing (REQUIRED)**: within a single field-update pass, at most one `TierCrossedEvent` fires per `crossedTier` boundary value. When multiple positions cross the same boundary in the same pass, select the position carrying the highest cumulative `fieldValue` at pass-end as the event's `position`, and that position's most-contributing `emissionId`.
- [ ] **H.28** — GIVEN the field at a position rises above `TENSE_THRESHOLD` due to a new emission, WHEN the update loop runs, THEN a server-internal `TierCrossedEvent` fires carrying `{crossedTier, position, emissionId, initialMagnitude}`; a subscribed mock Predator AI receives this within `1/FIELD_UPDATE_HZ` seconds.
- [ ] **H.28b** — GIVEN three positions cross `TENSE_THRESHOLD` in the same pass, WHEN the pass completes, THEN exactly one `TierCrossedEvent` fires for `crossedTier="Tense"` (not three), with `position` corresponding to the highest-fieldValue crossing.
- [ ] **H.28c** — GIVEN a `TierCrossedEvent` fires at P (fieldValue exactly 0.31) AND the test clock advances past `ln(0.31/MAGNITUDE_FLOOR)/(ln(2)/STANDARD_HALF_LIFE) ≈ 119s`, WHEN `GetHottestHotspot(callerPosition, 200, "Tense")` called (Story 008), THEN returns `nil`.
- [ ] **H.35** — GIVEN two emissions from different players on the same tick pushing a position from below `TENSE_THRESHOLD` to above it, WHEN the loop processes that tick, THEN `TierCrossedEvent` fires exactly once, and both `emissionId`s are eligible for a subsequent death attribution's top-3 list.

---

## Implementation Notes

Published Luau type + pure function (D.4, cite verbatim):
```luau
type Tier = "Calm" | "Tense" | "Hunt" | "Retreat"

function tierAt(P: Vector3, previousTier: Tier): Tier
    local t = fieldValue(P)
    if previousTier == "Calm" then
        if     t >= 1.00 then return "Retreat"
        elseif t >= 0.65 then return "Hunt"
        elseif t >= 0.30 then return "Tense"
        else                  return "Calm" end
    elseif previousTier == "Tense" then
        if     t >= 0.65 then return "Hunt"
        elseif t <  0.27 then return "Calm"
        else                  return "Tense" end
    elseif previousTier == "Hunt" then
        if     t >= 1.00 then return "Retreat"
        elseif t <  0.62 then return "Tense"
        else                  return "Hunt" end
    elseif previousTier == "Retreat" then
        if t < 0.97 then return "Hunt"
        else             return "Retreat" end
    end
    error(("tierAt: invalid previousTier '%s'"):format(tostring(previousTier)))
    return "Calm"
end
```
Post-hitch settle loop (cite verbatim, caller's responsibility per position per pass):
```luau
local key = string.format("%d_%d", math.floor(P.X), math.floor(P.Z))
local prev = previousTierAtPosition[key] or "Calm"
local result = tierAt(P, prev)
while result ~= prev do
    prev = result
    result = tierAt(P, prev)
end
previousTierAtPosition[key] = result
-- Fire one TierCrossedEvent per boundary crossed, subject to per-pass coalescing.
```
`TierCrossedEvent` is **activation-signal-only** — `position` is informational (under coalescing, the highest-cumulative position among same-pass crossings); it is NOT authoritative for navigation. This constraint governs Predator AI's consumption (out of scope here, but the event's contract must not imply position-authority).

---

## Out of Scope

- Story 007: squad-aggregate classification (`OnDisturbanceBandCrossed`) — that's a *squad-level* tier crossing built on top of this story's position-keyed classification, wired in Story 009.
- Story 008: `GetHottestHotspot`'s own tier-floor filtering (consumes `tierAt`'s boundary constants but doesn't call `tierAt` directly).
- Predator AI's own state machine consuming `TierCrossedEvent` (out of this epic entirely).

---

## QA Test Cases

- **AC-H.17**: Given: `fieldValue` rises from below 0.30 to exactly 0.30, `previousTier="Calm"` — When: `tierAt` evaluated — Then: returns "Tense". Edge case: `fieldValue = 0.2999` returns "Calm" (just below boundary).
- **AC-H.17b**: Given: `fieldValue=0.85`, `previousTier="Calm"` — When: evaluated — Then: returns "Hunt" (not "Tense" via a single-step ladder).
- **AC-H.17c**: Given: `fieldValue=1.00`, `previousTier="Calm"` — When: evaluated — Then: returns "Retreat".
- **AC-H.18**: Given: `previousTier="Tense"`, `fieldValue = 0.30 - 0.03 + 0.001 = 0.271` — When: evaluated — Then: remains "Tense".
- **AC-H.19**: Given: `previousTier="Tense"`, `fieldValue` strictly below 0.27 — When: evaluated — Then: returns "Calm". Edge case: exactly 0.27 (boundary) does NOT transition (per D.4's `<` operator, not `<=`).
- **AC-H.20**: Given: `previousTier="Hunt"`, `fieldValue = 0.65 - 0.03 - 0.001 = 0.619` — When: evaluated — Then: returns "Tense".
- **AC-H.21**: Given: `previousTier="Retreat"`, `fieldValue = 1.0 - 0.03 - 0.001 = 0.969` — When: evaluated — Then: returns "Hunt".
- **AC — canonical key encoding**: Given: two Vector3 instances with identical X/Z but constructed separately (different userdata references) — When: both are used to key `previousTierAtPosition` via the `%d_%d` string helper — Then: both resolve to the SAME table entry (Vector3 reference-equality bug does NOT manifest). Edge case: negative coordinates (`math.floor(-0.5) = -1`, verify the string format handles the negative sign correctly, e.g. `"-1_3"` not `"-0_3"` or malformed).
- **AC-H.34b**: Given: `previousTierAtPosition[P]="Retreat"`, a simulated hitch drops `fieldValue` to 0.20 in one step, mock PA subscriber attached — When: the settle loop runs — Then: final stored tier is "Calm"; exactly 3 `TierCrossedEvent`s fire in ladder order (Retreat→Hunt, Hunt→Tense, Tense→Calm); loop terminates in ≤4 iterations. Edge case: a hitch that crosses only 2 boundaries (Retreat→Tense, skipping the intermediate check point) still produces the correct number of discrete events per boundary, not a single skip-level event.
- **AC-H.34**: Given: fieldValue oscillates `0.31, 0.29, 0.31, 0.29` across 4 ticks — When: classified with hysteresis each tick — Then: `TierCrossedEvent` fires at most twice total (not once per tick).
- **AC-H.28**: Given: an emission pushes a position above 0.30 — When: the update loop runs — Then: `TierCrossedEvent` fires with correct `crossedTier`/`position`/`emissionId`/`initialMagnitude`; a mock subscriber receives it within `1/FIELD_UPDATE_HZ` seconds (0.2s at default).
- **AC-H.28b**: Given: three DISTINCT positions cross Tense in the same pass, with fieldValues 0.31, 0.40, 0.35 — When: pass completes — Then: exactly one `TierCrossedEvent` fires for "Tense", carrying the 0.40 position (highest).
- **AC-H.28c**: Given: `TierCrossedEvent` fired at P with fieldValue exactly 0.31 — When: clock advances past ≈119s and `GetHottestHotspot` is queried — Then: returns `nil` (source has decayed below the Tense floor and expired).
- **AC-H.35**: Given: two emissions from different players land the same tick, jointly pushing P from 0.28 to 0.35 — When: the tick is processed — Then: `TierCrossedEvent` fires exactly once for "Tense"; both emissionIds remain eligible for `topContributingEmissionIds` at that position.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/tier-classification-hysteresis-tiercrossedevent_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 005
- Unlocks: 009, 013, 015

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: All ACs COVERED (H.17-H.21, H.34, H.34b, H.28/H.28b/H.28c, H.35, canonical key encoding incl. negative coords, post-hitch cascade)
**Deviations**: Five pre-implementation design calls confirmed by the coordinator before coding (downward-threshold computed inline from registered constants — verified bit-identical to the story's literal pseudocode via IEEE-754 check; no new `RETREAT_THRESHOLD` constant, following Story 008's precedent; live-source-position enumeration for the classification pass; `initialMagnitude` under coalescing = winning contributor's own fixed field; `GetTierCrossedSignal()` naming matching `GetRunEndedSignal()`'s shipped precedent). Self-disclosed and code-review-confirmed gap: `self._previousTierAtPosition` has no cleanup path — logged as **TD-009**, flagged as a prerequisite before Predator AI subscribes to this signal.
**Test Evidence**: `tests/unit/ecological-disturbance/tier-classification-hysteresis-tiercrossedevent_test.luau` + `tests/integration/ecological-disturbance/tier-crossed-signal-subscription_test.luau` — passing
**Code Review**: Complete (combined ed-6+ed-14 review) — APPROVED WITH SUGGESTIONS
