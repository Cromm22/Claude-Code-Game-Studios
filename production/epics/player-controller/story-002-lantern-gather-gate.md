# Story 002: Lantern Axis, Light-to-Gather Gate & Tap-Hold Gather

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1.0 day
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-007` (lantern axis S3a/S3b; server-authoritative `lanternRaised`), `TR-pc-008` (light-to-gather gate: dual radii, coupled-knob config validation, server-authoritative dark-zone classification), `TR-pc-009` (mid-gather lantern-lower cancels in-progress gather server-side), `TR-pc-050` (tap-hold gather 500ms wall-clock)

**ADR Governing Implementation**: ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting (closest fit — governs the `RequestLanternToggle`/`RequestGather`-arm-eligibility validation surface this story's server handlers must follow)
**ADR Decision Summary**: Every client-fired RemoteEvent MUST evaluate the canonical 6-step order (alive/state guard → rate+burst → global budget → payload shape → server-side plausibility re-derivation → deep/domain validation). This story's `RequestLanternToggle` and `RequestGather`-arm-eligibility logic is steps 5–6.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: No post-cutoff API is used by this story. No dedicated ADR governs the light-to-gather gate mechanism itself (C.3.6) or the tap-hold gather timing (C.7) — both are gaps in the epic's own gap list (TR-pc-008, TR-pc-050 have no ADR).

**Control Manifest Rules (Core layer)**:
- Required: Every client-fired `RemoteEvent` handler evaluates the 6-step canonical order (ADR-0006).
- Required: A dropped event (steps 1–4) must not mutate any state, including cooldown/grace-timer anchors (ADR-0006) — a same-state `RequestLanternToggle` must not touch `t_lastGracePulse_light`.
- Forbidden: Never trust a client-supplied `lanternRaised` or `isDarkZone` claim — both must be server-authoritative and re-verified at commit (ADR-0006 step 5).

---

## Acceptance Criteria

- [ ] **H.9** — GIVEN a player in S2 (sprinting) + S3a (lantern lowered), `getServerTime()` injected, WHEN the player toggles lantern on, THEN locomotion axis remains S2 and lantern axis transitions to S3b, and BOTH axes' pulse-interval timers advance independently against the injected clock.
- [ ] **H.10** — GIVEN lantern in S3b with same-state debounce + burst cap active, WHEN toggled S3b → S3a → S3b within 200ms, THEN server lantern-axis state converges to the final input with no intermediate phantom emission (Logic gate, BLOCKING); cross-platform-feel confirmation (PC/Mobile/Gamepad) is ADVISORY.
- [ ] **H.25** — GIVEN the four locomotion×lantern combinations (S1+S3a, S1+S3b, S2+S3a, S2+S3b), WHEN each axis is mutated independently, THEN the other axis remains unchanged in all 8 single-axis transitions tested (no cross-axis side effects).
- [ ] **H.74** — GIVEN a player in S3a, `getServerTime()` injected, WHEN `RequestLanternToggle {raised=false}` arrives (same-state), THEN it is dropped **before any side-effect** — no transition, no Light pulse, and `t_lastGracePulse_light` is NOT touched. WHEN more than 8 events arrive within 2.0s (burst-cap), THEN excess dropped silently while the 5/s per-second limit also holds. A flood of alternating-then-same-state toggles cannot manufacture more grace-exempt Light pulses than C.8.2's cooldown permits.
- [ ] **H.84 Part 1** — GIVEN `isDarkZone = true`, WHEN `C3_6_CanArmGather(lanternRaised = false, isDarkZone = true)` is evaluated, THEN returns false; WHEN `lanternRaised = true`, THEN returns true. GIVEN `isDarkZone = false` (ambient-lit), THEN returns true regardless of `lanternRaised` (the gate is dark-zone-scoped).
- [ ] **H.88(b)** — GIVEN PC's config-validation pass, WHEN it runs, THEN it rejects a config with `GATHER_PROXIMITY_RADIUS >= LANTERN_VISIBILITY_RADIUS` (strict), and accepts the default (`4 < 20`).
- [ ] **H.89** — GIVEN a player in a dark zone within `GATHER_PROXIMITY_RADIUS` of a node with lantern raised (S3b) and a gather tap-hold **in progress** (past arm, before `TAP_HOLD_COMMIT_DURATION` completes), clock injected, WHEN the player lowers the lantern mid-hold, THEN the in-progress gather is CANCELLED server-side before any `RequestGather` completes (zero `RequestGather` for the node), the gather ring animates to "cancelled" client-side. GIVEN the same in-progress gather in an ambient-lit zone, WHEN the lantern lowers, THEN the gather is NOT cancelled (dark-zone-scoped only).

---

## Implementation Notes

- Lantern is a second, orthogonal server-authoritative state axis (`S3a`/`S3b`), independent of the locomotion axis established in Story 001 — both may be active simultaneously with independent pulse-interval timers and independent movement-delta trackers (this story only establishes the lantern-axis state and the gate predicate; pulse emission itself is Story 003's scope).
- `RequestLanternToggle` domain validation follows the same drop-first-ordering discipline as `RequestSprintToggle` (Story 001): same-state requests are dropped BEFORE any grace-anchor read or side-effect (H.74) — this is exploit-parity with `RequestSprintToggle`, not a new authority model.
- **DC-5 light-to-gather gate (C.3.6)**: two distinct radii, two distinct stages — reveal/identify at `LANTERN_VISIBILITY_RADIUS = 20 studs` (visual only, not this story's scope beyond the config gate) and arm/gather at `GATHER_PROXIMITY_RADIUS = 4 studs`. The arm predicate is `playerWithinGatherProximity AND lanternRaised` **in a dark zone**; in an ambient-lit zone the predicate is always true. Implement `C3_6_CanArmGather(lanternRaised, isDarkZone)` as a pure, PC-owned, testable server-side predicate — do NOT couple it to Resource Node's own dark-zone classification implementation (that's a forward obligation, see Out of Scope).
- Config validation MUST reject `GATHER_PROXIMITY_RADIUS >= LANTERN_VISIBILITY_RADIUS` (H.88b) — a node must never be gatherable-but-unrevealed.
- **Mid-gather lantern-lower cancel (H.89)**: the `lanternRaised` precondition must hold for the WHOLE tap-hold, not just at arm time. Track the in-progress gather's dark-zone-scoped-ness at arm time; on a lantern-lower event mid-hold in a dark zone, cancel server-side before `RequestGather` fires.
- Tap-hold commit duration (`TAP_HOLD_COMMIT_DURATION = 500ms`) MUST be measured wall-clock (via the C.11 seam), never frame-count — a frame-based implementation would make PC gather commit twice as fast as 30fps mobile.
- No dedicated ADR governs the light-to-gather gate mechanism or gather timing — implement per the GDD's own C.3.6/C.7 specification; escalate to `/architecture-decision` if a real engine ambiguity is hit during implementation.
- **Performance**: `C3_6_CanArmGather` is a pure O(1) predicate call, not a per-frame tick; `RequestLanternToggle` handling is bounded by ADR-0006's own rate/burst caps (5/s, 8 events/2.0s per player) — negligible server cost, no dedicated performance budget needed beyond those caps.

---

## Out of Scope

- Story 003: Actual `DisturbanceService:Emit("Light", ...)` publishing, magnitude/grace/cooldown formulas.
- Resource Node epic: the dark-zone classification (`isDarkZone(nodeId)`) and node reveal-state itself — this story only consumes a boolean `isDarkZone` input; the runtime classification is a Resource Node + level-design tagging obligation (currently a `MockDarkZone` seam per the GDD's F.4 reverse-cite note).
- Story 010: the shared canonical-order helper and global budget (this story implements the domain-specific parts of steps 5–6 only).

---

## QA Test Cases

- **AC-1 (H.9 — orthogonal axes)**:
  - Given: player in S2+S3a, clock injected.
  - When: lantern toggled on.
  - Then: locomotion stays S2, lantern → S3b, both pulse timers advance independently.
  - Edge cases: toggling lantern must never reset the sprint pulse timer or vice versa.
- **AC-2 (H.74 — same-state debounce + burst cap)**:
  - Given: player in S3a.
  - When: `RequestLanternToggle {raised=false}` (same-state) arrives.
  - Then: dropped before any side-effect, `t_lastGracePulse_light` untouched.
  - Edge cases: >8 events in 2.0s dropped (burst cap); alternating flood cannot exceed the cooldown-permitted grace-pulse rate.
- **AC-3 (H.84 Part 1 — arm predicate)**:
  - Given: `isDarkZone=true, lanternRaised=false`.
  - When: predicate evaluated.
  - Then: false. `lanternRaised=true` → true. `isDarkZone=false` → true regardless.
  - Edge cases: predicate must be pure/deterministic — no hidden state dependency.
- **AC-4 (H.89 — mid-gather cancel)**:
  - Given: dark-zone gather in progress, lantern raised.
  - When: lantern lowers mid-hold.
  - Then: gather cancelled server-side, zero `RequestGather` completes.
  - Edge cases: ambient-lit zone contrast — lantern-lower during gather does NOT cancel.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player-controller/lantern-gather-gate_test.luau`
**Status**: [x] Created and passing — verified 2026-07-07 via `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` (exit code 0, 3/3 test files pass, 0 failures). One test-harness bug fixed during verification (mock `expect()` matcher's argument binding), unrelated to this story's own logic.

---

## Dependencies

- Depends on: None (parallel to Story 001; orthogonal state axis)
- Unlocks: Story 003, Story 010
