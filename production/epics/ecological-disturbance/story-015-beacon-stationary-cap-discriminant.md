# Story 015: Beacon Stationary-Squad Hunt-Floor Cap & Cap-State Discriminant

> **Epic**: Ecological Disturbance
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-006` (per-player XZ ring buffer, ~15 samples, cumulative-distance integral), `TR-ed-007` (per-beacon `BeaconCapEvalEntry` cache, two-field encoding — sentinel `-1.0` forbidden), `TR-ed-010` (`_capCueDecayPassesRemaining[player]` cadence-derived decay counter), `TR-ed-033` (`Character.PrimaryPart` nil-guard before `.Position` on ring-buffer writes), `TR-ed-072` (Beacon stationary-squad Hunt-floor cap: multiplicative `scaleFactor`, engagement ratios, denominator-zero short-circuit)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: This story implements the GDD's own C.3.6/C.3.4 cap-formula and discriminant logic directly — no ADR-level deviation, but it is the single most complex Logic story in this epic (round-5 through round-15's game-design closure of a degenerate strategy). The two-field `BeaconCapEvalEntry` encoding (`cap_engaged: boolean`, `scaleFactor: number`, both always non-nilable, no sentinel) is binding.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: MEDIUM
**Engine Notes**: No new post-cutoff API — pure gameplay logic built on Stories 005–007's math. The complexity risk is in the sheer number of interacting edge cases (14 named `H.41*` criteria), not engine uncertainty.

**Control Manifest Rules (Core layer)**:
- No dedicated manifest line beyond the general per-source decay-caching and finiteness-guard disciplines already established in Stories 005/007, which this story's cap math must respect (e.g., the denominator-zero short-circuit is analogous to the NaN-guard pattern).

---

## Acceptance Criteria

- [ ] **Cap rule (C.3.6, steps 1–7)**: on every field-update pass, for each active Beacon B: (1) count `nearby` = connected players within `BEACON_STATIONARY_PROXIMITY_RADIUS` (16 studs) of B; (2) `connected` = count of players whose `Character` has spawned; (3) if `nearby/connected > 0.50` (strict), evaluate stationary status; (4) per-player cumulative-distance integral over `BEACON_STATIONARY_WINDOW` (3.0s) via a 5Hz-cadence ring buffer — `cumulativeXZ = sum of inter-sample 2D displacements`, stationary if `< BEACON_CUMULATIVE_DISTANCE_THRESHOLD` (6.0 studs); (5) if `stationary_nearby/nearby > 0.50` (strict, denominator is `nearby` not `connected`), cap engages: `fieldValue(B.position)` bounded at `BEACON_STATIONARY_CAP_FIELD_VALUE` (0.65); (6) `scaleFactor = (0.65 − non_beacon_contribution_at_B) / beacon_native_contribution_at_B`, clamped `[0.0, 1.0]`; (7) cap clears as soon as any criterion fails.
- [ ] **`Character.PrimaryPart` nil-guard (REQUIRED, TR-ed-033)**: ring-buffer writes MUST guard `character.PrimaryPart` being nil (a real, reachable window where `Character` is assigned but `PrimaryPart` has not yet replicated) — buffer is NOT appended that pass; the player falls through to the "characterless" treatment for both `nearby` and `stationary_nearby`.
- [ ] **Buffer-fill precondition**: a player's `cumulativeXZ` is used for cap engagement ONLY when the ring buffer holds at least `floor(BEACON_STATIONARY_WINDOW × FIELD_UPDATE_HZ) = 15` samples at default tunings. Under-filled buffers are treated as **moving** (`cumulativeXZ = +∞`), excluded from `stationary_nearby` until filled.
- [ ] **Two-field `BeaconCapEvalEntry` encoding (REQUIRED, no sentinel)**: `cap_engaged: boolean` (per-beacon, computed once per pass at step 5) and `scaleFactor: number` (always non-nilable, default `0.0`). Read-sites applying `scaleFactor` as a multiplier MUST be gated by `if cap_engaged then ...` — this is a binding read-site audit rule, enforced by Story 016's grep.
- [ ] **All-beacons-excluded / co-located amendment**: `non_beacon_contribution_at_B(B_i)` includes all non-Beacon sources, excludes `B_i` itself, and includes OTHER live beacons `B_j` ONLY IF `dist2D(B_i, B_j) < INFLUENCE_RADIUS` (co-located case).
- [ ] **Denominator-zero short-circuit (State C)**: if `beacon_native_contribution_at_B < MAGNITUDE_FLOOR × 1.5 = 0.03`, the cap rule does NOT apply for this beacon this pass (guards 0/0 NaN).
- [ ] **Cap-state discriminant (C.3.4, `MeterUpdatePayload` extension to Story 013's base payload)**: `beaconCapState: "A"|"B"|"C"|nil`, `nearby: number?`, `stationary_nearby: number?` — computed via a strict `if/elseif` chain, State C evaluated FIRST, then State A, then State B, then no-cap-cue.
- [ ] **Persistence rule**: `_capCueDecayPassesRemaining[player]` initialized to `math.ceil(1.0 × FIELD_UPDATE_HZ)` on any transition to nil `beaconCapState`, decremented each pass; fields stay populated while counter > 0.
- [ ] **H.41** — GIVEN four connected players all within 16 studs of active Beacon B, each `cumulativeXZ < 6.0` studs over 3.0s, WHEN the pass runs, THEN cap engages, `fieldValue(B.position) == 0.65` ± 0.001, B's `m(t,age)` unmodified.
- [ ] **H.41a** — GIVEN zero connected players AND active Beacon B, WHEN the pass runs, THEN cap does NOT engage; `fieldValue(B.position)` reflects full unmodified contribution.
- [ ] **H.41b** — GIVEN one connected player within 16 studs, stationary, WHEN the pass runs, THEN cap engages (`1/1 > 0.50` on both checks).
- [ ] **H.41c** — GIVEN a player's per-frame XZ delta exceeds `2 × 6.0 = 12` studs, WHEN the next pass runs, THEN ring buffer marked discontinuous, `cumulativeXZ` treated as `+∞` until buffer refills, player excluded from `stationary_nearby`.
- [ ] **H.41d** — GIVEN cap engaged per H.41, WHEN any nearby player's `cumulativeXZ` reaches/exceeds 6.0 studs, THEN cap clears next pass; full contribution returns.
- [ ] **H.41f** — GIVEN Beacon B whose age is sufficient that `m(B.age) × falloff(0) < 0.03` AND four nearby stationary players, WHEN the pass runs, THEN cap short-circuited for B, no NaN propagates, B expires per its own decay lifecycle.
- [ ] **H.41g** — GIVEN four players within 16 studs of B, 2 stationary and 2 with `cumulativeXZ ≥ 6.0`, WHEN the pass runs, THEN `stationary_nearby/nearby = 2/4 = 0.50, NOT > 0.50` — cap does NOT engage.
- [ ] **H.41h** — GIVEN ambient at B.position = 0.70 (above cap) AND cap-engagement preconditions satisfied, WHEN the pass runs, THEN: (a) `scaleFactor` clamps to 0.0; (b) beacon contribution = 0; (c) `fieldValue(B.position) = 0.70`.
- [ ] **H.41i** — GIVEN two beacons B1/B2 ≥24 studs apart AND squad-of-4 stationary near both, evaluated in both orders, WHEN the pass runs, THEN B1's verdict/scaleFactor identical regardless of B2's evaluation order.
- [ ] **H.41j** — GIVEN P_void joined without `CharacterAdded` while P1/P2 have spawned characters, all within 16 studs of B, stationary, WHEN the pass runs, THEN: (a) `connected=2`; (b) `nearby=2`; (c) both ratios 1.0>0.50; (d) cap engages; (e) with P_void as SOLE connected player: `connected=0` → cap rule does not apply.
- [ ] **H.41k** — GIVEN P1-P3 have full ring buffers, P_new joined <1.0s ago with 5 samples, all within 16 studs of B, WHEN the pass runs, THEN P_new treated as moving; various ratio outcomes per buffer-fill state; after 12 deterministic `_runFieldUpdatePass()` invocations, P_new's buffer holds 17≥15 samples and re-evaluation shows cap now engages where it previously didn't.
- [ ] **H.41l** — GIVEN two beacons B1/B2 <24 studs apart AND squad-of-4 stationary near both, zero ambient, WHEN the pass runs, THEN `non_beacon_contribution_at_B(B1)` INCLUDES B2's contribution when co-located; three sub-tests at d=4, d=23.9, d=24.1 studs verify the boundary.
- [ ] **H.41m** — GIVEN four scenarios (no-cap-cue, State A, State B, State C), WHEN the pass runs and `OnMeterUpdate` fires, THEN each payload's discriminant fields match the decision tree, including the persistence sub-test.
- [ ] **H.41n** — GIVEN one connected player within 16 studs, ring buffer starts empty, genuinely stationary, WHEN 15 passes run, THEN cap does NOT engage until the buffer fills at pass 15; a genuinely-moving player does NOT engage even at pass 15.
- [ ] **H.41o** — GIVEN a player with `Character ~= nil` but `Character.PrimaryPart == nil`, WHEN `_runFieldUpdatePass()` runs, THEN: (a) ring buffer NOT appended; (b) no runtime error; (c) `--!strict` nil-check idiom present; (d) player excluded from `nearby`; (e) buffer resumes once PrimaryPart is set.

---

## Implementation Notes

Per-pass buffer-write nil-guard idiom (REQUIRED, cite verbatim):
```luau
--!strict
local character = player.Character
if not character then return end
local primaryPart = character.PrimaryPart
if not primaryPart then
    return -- PrimaryPart not yet replicated; buffer NOT appended this pass
end
local position: Vector3 = primaryPart.Position
self:_appendRingBufferSample(player, position)
```
`non_beacon_at_B_i` co-location computation (round-9 update, cite verbatim):
```luau
local non_beacon_at_B_i = 0
for _, S in ipairs(liveSources) do
    if S.emissionId == B_i.emissionId then continue end
    if S.emissionType == "Beacon" then
        local d2sq = dist2DSquared(B_i.position, S.position)
        if d2sq < INFLUENCE_RADIUS * INFLUENCE_RADIUS then
            non_beacon_at_B_i = non_beacon_at_B_i + contribution(B_i.position, S)
        end
    else
        non_beacon_at_B_i = non_beacon_at_B_i + contribution(B_i.position, S)
    end
end
```
Cap-state discriminant strict evaluation order (STATE C FIRST, binding — cite verbatim):
```luau
if beacon_native_contribution_at_B < MAGNITUDE_FLOOR * 1.5 then
    -- State C: short-circuit BEFORE any cap-rule math; cap_engaged := false; scaleFactor := 0.0
elseif cap_engaged and scaleFactor > 0.0 and non_beacon_contribution_at_B < BEACON_STATIONARY_CAP_FIELD_VALUE then
    -- State A
elseif cap_engaged and scaleFactor == 0.0 then
    -- State B
else
    -- No-cap-cue
end
```
`BeaconCapEvalEntry` type (binding, no sentinel):
```luau
type BeaconCapEvalEntry = {non_beacon: number, beacon_native: number, cap_engaged: boolean, scaleFactor: number}
```
Persistence-counter cadence derivation (binding — use `math.ceil`, not `math.floor`): `math.ceil(1.0 × FIELD_UPDATE_HZ)` — produces 5 at 5Hz, 2 at 2Hz, 4 at 4Hz, 10 at 10Hz, always honoring the 1.0s persistence target ± one pass.

Test seams required (per verification companion doc): `_setRingBufferState(player, samples)`, `_resetCapCueDecayPassesRemaining()`, `_setLiveSourceState(sources)` — all server-internal only, verified non-`.Client` by Story 016.

---

## Out of Scope

- Story 013: the base `OnMeterUpdate` payload shape and per-player routing discipline (this story only extends the payload with the 3 optional discriminant fields).
- Predator AI's consumption of the capped `fieldValue` at the beacon (out of this epic — PA's own H.47 covers the Hunt-tier-not-attack-commit framing; no PA-side change required).
- H.41e (MANUAL-PLAYTEST degenerate-strategy closure) — this is a playtest verification, not an implementation criterion; not included in this story's automated test evidence, tracked separately at the production/qa level if run.

---

## QA Test Cases

- **AC-H.41**: Given: 4 players within 16 studs of B, all stationary — When: pass runs — Then: cap engages, `fieldValue(B.position) = 0.65` ± 0.001; B's raw `m(t,age)` verified unchanged by direct inspection.
- **AC-H.41a**: Given: zero connected players, active B — When: pass runs — Then: cap does not engage; full unmodified contribution.
- **AC-H.41b**: Given: 1 player, stationary, within 16 studs — When: pass runs — Then: cap engages (`1/1 > 0.50` both checks).
- **AC-H.41c**: Given: a player's per-frame XZ delta exceeds 12 studs — When: next pass runs — Then: buffer marked discontinuous, `cumulativeXZ = +∞`, excluded from `stationary_nearby` until refilled.
- **AC-H.41d**: Given: cap engaged — When: a nearby player's `cumulativeXZ` reaches 6.0 — Then: cap clears next pass.
- **AC-H.41f**: Given: B near-expiry (`m×falloff(0) < 0.03`), 4 stationary nearby — When: pass runs — Then: cap short-circuits, no NaN, B continues its natural decay/expiry.
- **AC-H.41g**: Given: 4 players within 16 studs, 2 stationary + 2 moving — When: pass runs — Then: ratio 0.50 exactly — cap does NOT engage (strict `>`, not `>=`).
- **AC-H.41h**: Given: ambient 0.70 at B, cap preconditions met — When: pass runs — Then: `scaleFactor` clamps to 0.0, beacon contributes 0, `fieldValue = 0.70`.
- **AC-H.41i**: Given: two beacons ≥24 studs apart, squad stationary near both — When: evaluated B1-then-B2 vs B2-then-B1 — Then: B1's verdict identical in both orders.
- **AC-H.41j**: Given: P_void (no Character), P1/P2 spawned, all within 16 studs — When: pass runs — Then: `connected=2`, `nearby=2`, cap engages. Given: P_void as SOLE connected player — When: pass runs — Then: `connected=0`, cap does not apply (E.15-style short-circuit).
- **AC-H.41k**: Given: P_new joined <1.0s ago with 5 samples, P1-P3 full buffers — When: pass runs — Then: P_new treated as moving. Given: 12 more deterministic passes run — When: re-evaluated — Then: P_new's buffer has 17≥15 samples and cap engagement re-evaluates correctly with P_new now eligible.
- **AC-H.41l**: Given: B1/B2 at d=4 studs (co-located) — When: pass runs — Then: `fieldValue(B1.position) ∈ [0.6587, 0.6607]`, `scaleFactor==0.0` exactly. Given: d=23.9 studs — Then: amendment fires (co-located branch), negligible effect. Given: d=24.1 studs — Then: amendment does NOT fire, reverts to the non-co-located exclusion rule.
- **AC-H.41m**: Given: 4 scenarios (no-cap-cue, State A, State B, State C) — When: `OnMeterUpdate` fires for each — Then: discriminant fields match exactly per scenario; persistence sub-test confirms State A→C (or any-to-nil) transition retains populated fields for `math.ceil(1.0×FIELD_UPDATE_HZ)` passes then nils, at 5/2/10Hz cadences.
- **AC-H.41n**: Given: 1 player, empty buffer, genuinely stationary — When: 15 passes run — Then: cap does not engage through pass 14, engages at pass 15. Given: the SAME player genuinely moving — When: 15 passes run — Then: cap does not engage even at pass 15.
- **AC-H.41o**: Given: `Character ~= nil`, `PrimaryPart == nil` — When: `_runFieldUpdatePass()` runs — Then: buffer not appended, no error, player excluded from `nearby`; once `PrimaryPart` is set on a later pass, buffer resumes appending.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/beacon-stationary-cap-discriminant_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 005, 006, 007, 013
- Unlocks: 016, 017
