# Story 003: Disturbance Emission Publisher (Sprint/Light Pulses, Grace, Cooldown, Magnitude)

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-010` (PC publishes Sprint & Light emissions via `DisturbanceService:Emit`), `TR-pc-011` (emission position = server-observed `HumanoidRootPart.Position`, client-predicted forbidden), `TR-pc-012` (pulse cadence, `FIRST_PULSE_GRACE_WINDOW`, `GRACE_REENTRY_COOLDOWN`, magnitude attenuation, `SPRINT_HOLD_FLOOR`), `TR-pc-014` (mobile analog-drift threshold), `TR-pc-015` (sprint-pulse flora micro-pulse — forward obligation to ED)

**ADR Governing Implementation**: ADR-0003: Locomotion Driver — Humanoid vs. Character Controller Library (closest fit — establishes `HumanoidRootPart.Position` as the shared, server-tracked position primitive this story's emission-position semantics depend on)
**ADR Decision Summary**: `Humanoid`-driven movement is the shared locomotion primitive for PC and Predator AI; `HumanoidRootPart.Position` is server-tracked and authoritative. No ADR directly governs the emission magnitude/pulse-cadence formulas themselves (those are ED-registry-owned constants PC consumes) — this is a named gap.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: HIGH
**Engine Notes**: HIGH risk inherited from ADR-0003's own Knowledge Risk field (Character Controller Library co-existence and `WalkSpeed` reassignment smoothness are unverified pending the `/prototype predator-ai` spike) — this story's emission-position reads depend on the same `HumanoidRootPart` the spike verifies.

**Control Manifest Rules (Core layer)**:
- Required: `Player Controller publishes Sprint & Light emissions via DisturbanceService:Emit(type, position, magnitude, sourcePlayerId)` — emission position is the server-observed `HumanoidRootPart.Position`; client-predicted positions are forbidden.
- Required: Every read of "current server time" inside timers MUST go through the C.11 `getServerTime()` seam.
- Forbidden: Never read or trust a client-supplied position for an emission call (ADR-0006 step 5 parity — server-side plausibility re-derivation).

---

## Acceptance Criteria

- [ ] **H.11** — GIVEN a player with `t_lastGracePulse_sprint = nil` enters S2 at `t_0` (sentinel-injected, e.g. 12345.0), WHEN `GetPulseMagnitude(t = t_0+0.5, d_xz=0.4, platform="pc")` is called within `FIRST_PULSE_GRACE_WINDOW=1.0s`, THEN returns `0.10` (grace-exempt), AND the test asserts `t_lastGracePulse_sprint == 12345.0` (the sentinel, not merely non-nil).
- [ ] **H.11b/c** — GIVEN `t_lastGracePulse_sprint = t_now-3.0s` (cooldown active), the first pulse fires within grace window, WHEN evaluated for Sprint stationary (`d_xz=0.4`), THEN `grace_eligible=false`, falls through to stationary attenuation `0.10×0.30=0.03`, raised by the R10-6 hold-floor to `max(0.09, 0.03)=0.09`. WHEN moving (`d_xz=5`), THEN result = `0.10` (full — cooldown never silences a moving sprinter).
- [ ] **H.11d** — GIVEN a Sprint grace-exempt pulse fired 2s ago (cooldown active), WHEN `Humanoid.Died` (T5) fires and the player respawns and re-enters S2, THEN the first Sprint pulse on the new life is grace-exempt at full magnitude (`t_lastGracePulse_sprint` reset to `nil` on T5).
- [ ] **H.11e** — GIVEN `t_lastGracePulse_sprint=nil` AND `t_lastGracePulse_light=nil` (distinct sentinels 12345.0/23456.0), the player enters S2 then S3b while S2 still active, WHEN both first-pulses evaluated, THEN BOTH grace-exempt (Sprint 0.10, Light 0.08), AND both anchors independently assert their own sentinel (no cross-axis contamination).
- [ ] **H.11f/g** — Light-axis parity with H.11b/c: cooldown-active stationary → `0.024` (no hold-floor on Light axis); cooldown-active moving → `0.08` (full).
- [ ] **H.11h** — GIVEN `t_lastGracePulse_sprint=nil` (eligible) entering S2 at `t_0`, but the first pulse delivers at `t_0+1.5s` (past grace window, simulating server jitter), WHEN Step 0a evaluates, THEN `t_lastGracePulse[Sprint]` is set to `t_0` regardless of whether the grace-window check passes. A subsequent S2 entry at `t_0+5.0s` (within `GRACE_REENTRY_COOLDOWN=6.0s`) observes `grace_eligible=false`.
- [ ] **H.12 / H.12a / H.81** — Sprint stationary (grace-ineligible) → exactly `config.SPRINT_HOLD_FLOOR` (default 0.09), never 0.03/0.08/0.10. Light stationary (grace-ineligible) → exactly `0.024`, NEVER raised to the hold-floor (Sprint-axis-only security property, H.81). Config validation rejects `SPRINT_HOLD_FLOOR <= MAGNITUDE_LIGHT_PULSE` or `>= MAGNITUDE_SPRINT_PULSE` (both strict), rejects `STATIONARY_EMISSION_FACTOR <= 0` or `> 1` (clause vi).
- [ ] **H.13/H.14** — GIVEN `platform="touch"`, `d_xz=0.2` (below `MOBILE_ANALOG_DRIFT_THRESHOLD=2`), THEN `effective_d` zeroed, stationary attenuation applies (`0.024`). GIVEN `platform="pc"`, same `d_xz=0.2`, THEN drift-floor gate does NOT apply, `effective_d=0.2`, still stationary-attenuated via the movement-delta floor (distinguishes the code path, same output).
- [ ] **H.15** — GIVEN a player in S2 publishing every 2s, clock injected, WHEN the player also enters S3b and the clock advances across both a Sprint and a Light interval boundary, THEN both emissions appear in ED's live-source list with distinct `emissionType` tags, no deduplication.
- [ ] **H.32** — MANUAL-DEVICE (iPhone SE-class): GIVEN a stationary player with sub-2-stud thumbstick drift confirmed from position log, WHEN sprint is active for 10s, THEN every pulse past the grace window is at exactly `SPRINT_HOLD_FLOOR = 0.09`.

---

## Implementation Notes

- Implement `GetPulseMagnitude` exactly per D.4's evaluation order: (0) resolve `grace_eligible` per-axis, anchor `t_lastGracePulse[axis] = t_0` on **eligibility, not on grace-window pass** (H.11h — this is load-bearing; anchoring only inside the grace-window branch reopens the G1 exploit under server jitter); (1) apply the mobile-drift floor (`effective_d := 0` if `d_xz < MOBILE_ANALOG_DRIFT_THRESHOLD` AND `platform=="touch"`); (2) branch grace/moving/stationary; (3) apply the Sprint-axis-ONLY hold-floor `max(SPRINT_HOLD_FLOOR, magnitude_out)`.
- `t_lastGracePulse_sprint`/`t_lastGracePulse_light` are tracked **per-axis independently** — entering one axis must never zero or overwrite the other's anchor (H.11e).
- `SPRINT_HOLD_FLOOR = 0.09` is an ED-registry-owned constant (landed in ED G.5 + `entities.yaml`) — reference it, do not redefine it locally. Bound by the hierarchy invariant `MAGNITUDE_LIGHT_PULSE (0.08) < SPRINT_HOLD_FLOOR (0.09) < MAGNITUDE_SPRINT_PULSE (0.10)`, both strict.
- Emission position is always the server-observed `HumanoidRootPart.Position` at pulse-fire time — never a client-predicted position (ADR-0006 step 5 parity, ADR-0003's server-tracked-position convention).
- Every timestamp read (`t`, `t_0`, `t_lastGracePulse[axis]`) MUST go through PC's C.11 `getServerTime()` seam, established in Story 001 — do not add a second, divergent clock read in this story.
- The XZ movement-delta sampler (D.6) discards Y — jump-in-place must produce `d_xz = 0`; first pulse on state-entry uses the state-entry position as the baseline (no sentinel needed, the grace branch consumes it regardless of value).
- No ADR directly governs this emission-magnitude formula set — it is ED-registry-owned and PC-consumed; implement per the GDD's own D.4 specification, and escalate to `/architecture-decision` if a real engine ambiguity is hit (e.g., a `RunService.Heartbeat` timing edge that materially affects pulse-fire precision).

---

## Out of Scope

- Story 001/002: sprint/lantern state-axis transitions themselves (this story only fires the emission on top of an already-transitioned axis).
- Ecological Disturbance epic: the receiving-side spatial hash grid, hotspot query, and the sprint-pulse flora micro-pulse render response (TR-pc-015 is PC's obligation to fire the emission it already owes; the flora micro-pulse itself is ED's forward obligation).
- Predator AI epic: any consumption of the emitted disturbance signal.

---

## QA Test Cases

- **AC-1 (H.11/H.11h — grace eligibility + anchor-on-eligibility)**:
  - Given: `t_lastGracePulse_sprint=nil`, sentinel clock injected.
  - When: first pulse fires within grace window.
  - Then: 0.10, anchor written to the exact sentinel `t_0`.
  - Edge cases: first pulse delivered LATE (past grace window) must still anchor at `t_0` (H.11h), not at delivery time.
- **AC-2 (H.11b/c — cooldown-blocked stationary vs moving)**:
  - Given: cooldown active (anchor 3s old).
  - When: stationary pulse (`d_xz=0.4`).
  - Then: `0.09` (hold-floor). When moving (`d_xz=5`): `0.10` (full, cost never dodged by movement).
  - Edge cases: exactly at `EMITTER_MOVEMENT_DELTA_FLOOR=1.0` boundary.
- **AC-3 (H.81 — Light-axis no-floor security property)**:
  - Given: Light-axis stationary, cooldown-blocked.
  - When: `GetPulseMagnitude` called for Light.
  - Then: exactly `0.024`, never raised to `SPRINT_HOLD_FLOOR`.
  - Edge cases: paired Sprint-axis contrast in the same test body proves the floor is axis-specific, not a global leak.
- **AC-4 (H.12a — config-validation gates)**:
  - Given: config with `SPRINT_HOLD_FLOOR <= 0.08` or `>= 0.10`.
  - When: config validation runs.
  - Then: rejected. Default config accepted.
  - Edge cases: `STATIONARY_EMISSION_FACTOR = 0` or `-0.1` or `1.5` also rejected (clause vi).

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player-controller/disturbance-emission-publisher_test.luau`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (sprint state S1/S2 must exist to gate Sprint pulses), Story 002 (lantern state S3a/S3b must exist to gate Light pulses)
- Unlocks: None internal (this closes PC's publisher obligation; Ecological Disturbance epic consumes it — cross-epic, no PC story blocked on it)

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: 9/10 fully passing; H.11d covered at the seam-function level only (the `Humanoid.Died` wiring itself is explicitly this project's own future death/respawn story's scope, not this one's — correctly not implemented here); H.32 honestly DEFERRED (`pending()`, MANUAL-DEVICE, matching the pc-1 H.26 precedent)
**Deviations**:
- `platform` hardcoded to `"pc"` at the emission-heartbeat call site — a live correctness gap for touch players (misclassified in the 1.0–2.0 stud drift band, pays full magnitude instead of the intended attenuated value), not merely a deferred test. Logged as **TD-005**.
- `OnSprintPulse` (GDD C.9) has no owning story anywhere in the Player Controller epic despite Story 010/011 assuming it exists. Logged as **TD-006**.
- Two regression tests added post-review: axis-wiring cross-contamination check (Sprint/Light hooks feed the correct `emissionState` field), constant-drift check (local ED-registry constant duplicates vs. `DisturbanceConstants.luau` canonical values). Both pass.
**Test Evidence**: `tests/unit/player-controller/disturbance-emission-publisher_test.luau` — passing
**Code Review**: Complete (combined pc-3+pc-11 review) — APPROVED WITH SUGGESTIONS
