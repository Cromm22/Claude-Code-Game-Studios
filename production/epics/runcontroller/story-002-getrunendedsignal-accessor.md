# Story 002: RunController GetRunEndedSignal Accessor and KnitInit/KnitStart Subscriber-Safety Verification

> **Epic**: RunController
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: None — ADR-0002 is sole design authority (no GDD exists for this module)
**Requirement**: N/A — see ADR-0002 Key Interfaces (`GetRunEndedSignal`), Validation Criteria ("`RunEnded`'s signal object is confirmed non-nil immediately after `KnitInit` completes, before any `KnitStart` runs"), and ADR-0001 Rule 1/Rule 2 (the general `KnitInit`-builds/`KnitStart`-connects discipline this story verifies an instance of)
**ADR Governing Implementation**: ADR-0002: RunController Architecture (referencing ADR-0001: KnitInit/KnitStart Ordering Discipline for the construction-timing requirement)
**ADR Decision Summary**: RunController exposes one outbound signal, `RunEnded`, constructed during `KnitInit` (never `KnitStart`) so that any subscriber — HUD's end-screen, analytics, Player Controller's own T7/T8 cleanup — can safely connect to it via `GetRunEndedSignal()` during its own `KnitStart`, regardless of which service's `KnitStart` happens to run first (Knit gives no ordering guarantee between different services' `KnitStart` calls).

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: Per ADR-0002's Engine Compatibility field, LOW risk — no new Roblox API beyond what ADR-0001 already governs (`Signal`/`BindableEvent`, `KnitInit`/`KnitStart` ordering). The risk this story guards against is architectural/ordering-related (an object being read before it exists), which is exactly the class of bug ADR-0001 was written to prevent project-wide — this story is that prevention pattern's first concrete instance for RunController.

**Control Manifest Rules (Foundation layer)**:
- Required: "'`KnitInit` builds, `KnitStart` connects'" — any object, signal, or accessor another service might need to synchronously read or call during its own `KnitStart` MUST be fully constructed inside the owning service's `KnitInit` — source: ADR-0001
- Required: "Prefer Knit's bundled `Signal` class (RbxUtil) over raw `Instance.new("BindableEvent")` for cross-service signals" — source: ADR-0001
- Required: "HUD's end-screen (and any other `RunEnded` subscriber) connects to `RunController:GetRunEndedSignal()` during its own `KnitStart`" — source: ADR-0002 (Presentation layer rule, but the accessor itself is authored here)
- Forbidden: "Never construct a cross-service-visible object (signal, accessor) inside `KnitStart`" — source: ADR-0001
- Forbidden: "Never call another service's public Knit API from your own `KnitStart` and assume that service's `KnitStart`-time setup has already completed" — source: ADR-0001
- Guardrail: one `Signal` instance + one boolean per server instance for the run's lifetime, discarded at run end — source: ADR-0002 Performance Implications

---

## Acceptance Criteria

- [ ] `RunController:GetRunEndedSignal(): Signal.Signal` exists and returns `self._runEnded`.
- [ ] `self._runEnded` is constructed inside `KnitInit` via `Signal.new()` (Knit's bundled Signal class), not `Instance.new("BindableEvent")` and not deferred to `KnitStart`.
- [ ] `RunController:GetRunEndedSignal()` returns a non-nil Signal object immediately after `KnitInit` completes, confirmed **before any service's `KnitStart` runs** — this is ADR-0002's own Validation Criteria, verbatim.
- [ ] Every call to `GetRunEndedSignal()` returns the **same** Signal instance (identity-equal), not a new object per call.
- [ ] Multiple independent mock subscribers, each connecting to the signal during their own simulated `KnitStart` in an arbitrary/undefined relative order (simulating that Knit gives no `KnitStart`-ordering guarantee between services), all receive the same `RunEnded` fire exactly once, regardless of connection order.
- [ ] A subscriber that connects to `GetRunEndedSignal()` *after* `RunEnded` has already fired does **not** receive a replayed/retroactive fire — this documents the signal's forward-only behavior so future subscriber implementations (HUD, analytics) don't assume replay semantics.

---

## Implementation Notes

- This story's accessor is a one-line method (`return self._runEnded`), but its test surface is the substantial part: it must prove the ADR-0001 ordering guarantee actually holds for this specific service, not just assert the trivial accessor body.
- Build the integration test using multiple mock/stub "subscriber services," each with its own simulated `KnitInit`/`KnitStart` phases, to mirror the real multi-service boot sequence: (1) call RunController's `KnitInit` first, (2) construct N mock subscribers in a deliberately shuffled order, each calling `GetRunEndedSignal():Connect(...)` inside its own simulated `KnitStart`, (3) only then trigger `RunEndConditionRaised` (from Story 001) and confirm all N subscribers received the fire.
- Do not use `task.wait()` or any timing-based synchronization to "ensure" ordering in the test — the whole point of ADR-0001's Rule 1 is that correctness does not depend on timing; if the test needs a `task.wait()` to pass reliably, that is itself a sign the implementation is relying on incidental ordering rather than the `KnitInit`-construction guarantee.
- Reference ADR-0001's Risks section on the `Signal` vs raw `BindableEvent` choice: prefer `Signal:Fire()`'s plain-Luau-call synchronicity guarantee, which is independent of `Workspace.SignalBehavior` entirely — do not introduce a raw `BindableEvent` for `RunEnded` under any circumstance.
- The "no replay for late subscribers" behavior is a natural consequence of using a plain Signal (not a cached-last-value pattern) — do not add replay/caching logic to satisfy this acceptance criterion; the test should confirm the *absence* of replay, not require new code to prevent it, unless the chosen Signal implementation happens to replay by default (verify this against the actual `Signal.new()` implementation in `ReplicatedStorage.Packages.Signal` before assuming either behavior).

---

## Out of Scope

- `RunEndConditionRaised`'s own idempotency/latch logic and the `.Client`-exposure-ban verification — Story 001.
- The full scripted 2-player D1 `aliveCount ≤ 2` end-to-end integration test named in ADR-0002's Validation Criteria — explicitly deferred there "once PC/Crafting are implemented"; this story's integration test uses mock subscribers, not the real Player Controller service.
- `SquadStateSnapshot`'s finalized concrete type — open ADR-0002 question, tracked separately.
- Any real subscriber's own implementation (HUD's end-screen render, analytics' event emission, PC's T7/T8 cleanup) — those belong to their own epics/stories; this story only proves the accessor + ordering contract they will rely on.

---

## QA Test Cases

- **AC-1/AC-2**: Accessor returns the KnitInit-constructed Signal
  - Given: a freshly `KnitInit`-constructed RunController
  - When: `GetRunEndedSignal()` is called
  - Then: it returns a non-nil object that is identity-equal to `self._runEnded`, and `self._runEnded` was constructed via `Signal.new()` inside `KnitInit` (verified by inspecting construction call site, not just runtime behavior)
  - Edge cases: confirm no raw `Instance.new("BindableEvent")` appears anywhere in the module

- **AC-3**: Signal non-nil before any KnitStart runs
  - Given: a test harness that calls `RunController:KnitInit()` and then immediately (before calling `KnitStart` on RunController or any other simulated service) calls `GetRunEndedSignal()`
  - When: the returned value is checked
  - Then: it is non-nil — this is the exact scenario named in ADR-0002's Validation Criteria
  - Edge cases: repeat with a simulated delay/other services' `KnitInit`s running in between (still before any `KnitStart`) — result is unchanged, still non-nil

- **AC-4**: Same instance returned on every call
  - Given: a `KnitInit`-constructed RunController
  - When: `GetRunEndedSignal()` is called twice
  - Then: both return values are identity-equal (`==`), not merely deep-equal
  - Edge cases: call from two different simulated "caller services" — same identity result regardless of caller

- **AC-5**: Order-independent multi-subscriber receipt
  - Given: 3 mock subscriber stubs, each simulating its own `KnitStart` phase, connecting to `GetRunEndedSignal()` in a deliberately shuffled order (e.g., subscriber C connects first, then A, then B)
  - When: `RunEndConditionRaised("wipe", squadState)` is called (using Story 001's implementation) after all 3 have connected
  - Then: all 3 subscribers' callbacks fire exactly once each, with the identical payload
  - Edge cases: run the same test with connection order reversed (A, B, C) — result identical, proving the outcome does not depend on connection order; also test with 0 subscribers connected (no error, fire is simply unobserved) and with 1 subscriber connecting, disconnecting, then a second subscriber connecting before the fire (only the still-connected subscriber receives it)

- **AC-6**: No replay for late subscribers
  - Given: `RunEndConditionRaised` has already fired `RunEnded` once (latch is set)
  - When: a new mock subscriber connects to `GetRunEndedSignal()` *after* the fire
  - Then: that subscriber's callback is never invoked (no retroactive replay)
  - Edge cases: confirm this holds even when the late-connecting subscriber is the very next line of code after the fire (no timing window where replay might incidentally occur)

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/runcontroller/get_run_ended_signal_test.luau`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (needs `RunEndConditionRaised`'s `_runEnded:Fire()` call to exist in order to test subscriber receipt)
- Unlocks: HUD epic's end-screen `RunEnded`-subscription work; analytics' `RunEnded{exitReason}` event wiring; Player Controller epic's T7/T8 cleanup subscription; Resource Node epic's completability gate (which names `RunEnded` as an open dependency)

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: 6/6 passing
**Deviations**: None blocking. Code review noted a pre-existing, unrelated drift in `control-manifest.md:118` (still describes the older direct-Crafting→RunController model that ADR-0002 already corrected) — logged as TD-007, not a defect in this story.
**Test Evidence**: `tests/integration/runcontroller/get_run_ended_signal_test.luau` — passing
**Code Review**: Complete — APPROVED
