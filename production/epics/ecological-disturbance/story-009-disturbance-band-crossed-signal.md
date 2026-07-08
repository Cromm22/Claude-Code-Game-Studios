# Story 009: OnDisturbanceBandCrossed Squad-Aggregate Band-Crossing Signal

> **Epic**: Ecological Disturbance
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-038` (server-internal `OnDisturbanceBandCrossed(direction, newTier, ts)` squad-aggregate signal, up+down)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: This signal is entirely GDD-specified (C.3.3, added Session C 2026-06-19) with no ADR-level deviation — it closes Player Controller's F.4 producer obligation. Distinct from `TierCrossedEvent` (position-keyed): this is *squad-aggregate*-keyed, driven by `squadT` (Story 007) classified via the same D.4 tier machinery (Story 006).

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: No engine-API risk — server-internal signal only, same dispatch mechanism as `TierCrossedEvent`.

**Control Manifest Rules (Core layer)**:
- Forbidden: `OnDisturbanceBandCrossed` MUST NOT be declared on `.Client`, never a RemoteEvent/RemoteFunction — server-internal, no client-reachable input path. (Analogous to the general "never expose server-internal decision signals to `.Client`" discipline enforced elsewhere in the manifest for `RunEndConditionRaised`.)

---

## Acceptance Criteria

- [ ] Server-internal Knit signal `OnDisturbanceBandCrossed(direction: "up" | "down", newTier: Tier, timestamp: number)`. `timestamp` sourced from `workspace:GetServerTimeNow()` (same server clock as D.1, deterministic in tests via the `_setTestClock` seam).
- [ ] **Producer logic**: the field-update pass maintains a `previousSquadTier` state variable. Every pass classifies the current `squadT` into a tier via the same D.4 tier-classification + ±0.03 hysteresis used for positional crossings (no new thresholds). When the classified squad tier differs from `previousSquadTier`, fire once with `direction` (`"up"` if escalating, `"down"` if de-escalating) and the new tier, then update `previousSquadTier`.
- [ ] **First-pass rule (REQUIRED)**: on the very first field-update pass of a session, `previousSquadTier` initialises to that pass's freshly-classified squad tier via flat-threshold dispatch (the D.4 first-call convention), and NO `OnDisturbanceBandCrossed` fires on that pass regardless of the classified tier.
- [ ] **Post-hitch multi-tier cascade parity**: if a single pass moves `squadT` across MULTIPLE boundaries, the classifier converges through the full ladder within that pass (≤4 settle iterations) and fires one event per crossed boundary, in ladder order, all with the same `direction` — never a single skip-level fire.
- [ ] **Both directions fire; the consumer filters**: ED fires on BOTH up and down crossings; the signal does not assume the consumer's (Player Controller's) filter.
- [ ] **Security (binding)**: server-internal only — never on `DisturbanceService.Client`, never a RemoteEvent/RemoteFunction.
- [ ] **H.28d** — GIVEN a mock PC subscriber connected to `OnDisturbanceBandCrossed` AND the harness drives `squadT` across D.4 boundaries, WHEN the field-update pass runs, THEN: (a) exactly one fire per pass per squad-tier TRANSITION, `timestamp` from `workspace:GetServerTimeNow()`, zero fires when tier unchanged; (b) hysteresis-band oscillation (e.g., 0.30 then 0.285) fires no event; (c) the signal has no `.Client` surface, never client-reachable; (d) driving `squadT` above threshold BEFORE the first pass results in zero fires on that pass — `previousSquadTier` initialises via flat-dispatch; (e) driving `squadT` from Retreat-range to Calm-range (0.20) at a connected player's position between passes results in `previousSquadTier` converging through the full ladder AND exactly THREE fires in ladder order (Retreat→Hunt, Hunt→Tense, Tense→Calm), each `direction="down"`.

---

## Implementation Notes

At steady-state, at most one fire per field-update pass (5Hz cadence is the natural debounce). The producer logic mirrors Story 006's positional tier-classification code almost exactly, but operates on the single scalar `squadT` (Story 007) rather than per-position field values — reuse the same `tierAt`-style classification function against `squadT` and `previousSquadTier`, and the same post-hitch cascade-settle-loop shape from Story 006.

D.7 coupling note (no action required, just awareness): the tier boundaries (0.30/0.65/1.00) are unchanged by the 2026-06-19 D.7 ED-yields ruling — that ruling changed only the magnitude/lifetime of stationary-sprint pulses, so `OnDisturbanceBandCrossed` fires earlier in real time under a held stationary sprint (working as designed).

---

## Out of Scope

- Player Controller's consumption of this signal into `OnWorldResponseCue` (out of this epic entirely).
- Story 006: position-keyed `TierCrossedEvent` (a distinct signal built earlier in this epic; this story's producer logic parallels but does not reuse its exact code path — squad-aggregate has its own `previousSquadTier` state, not `previousTierAtPosition`).

---

## QA Test Cases

- **AC-H.28d(a)**: Given: a mock PC subscriber, `squadT` driven from Calm (0.20) to Tense (0.40) between passes — When: the pass runs — Then: exactly one fire, `direction="up"`, `newTier="Tense"`, `timestamp` matches `workspace:GetServerTimeNow()` at fire time. Edge case: two consecutive passes with no tier change between them — zero fires on the second pass.
- **AC-H.28d(b)**: Given: `squadT` oscillates within the hysteresis band (0.30, then 0.285, back to 0.30) — When: passes run — Then: no event fires across the oscillation (hysteresis suppresses).
- **AC-H.28d(c)**: Given: the signal's declaration — When: inspected for `.Client` surface — Then: not present; not a RemoteEvent/RemoteFunction.
- **AC-H.28d(d)**: Given: a fresh session where `squadT` is ALREADY above the Tense threshold before the very first field-update pass runs (e.g., a hot-join into a pre-elevated field or a test fixture) — When: the first pass runs — Then: zero fires occur on that pass; `previousSquadTier` is set via flat-threshold dispatch to match the current classification.
- **AC-H.28d(e)**: Given: `squadT` at Retreat-range (1.0), then between passes a connected player's position causes it to drop to 0.20 (Calm-range) — When: the next pass runs — Then: `previousSquadTier` converges Retreat→Hunt→Tense→Calm within ≤4 settle iterations, and exactly 3 fires occur in that ladder order, each with `direction="down"`. Edge case: verify the cascade does NOT fire a single "Retreat→Calm" skip-level event instead of the 3 discrete ones.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ecological-disturbance/disturbance-band-crossed-signal_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 006, 007
- Unlocks: None (consumed by Player Controller, outside this epic)
