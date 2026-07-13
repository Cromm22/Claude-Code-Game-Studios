# Story 001: RunController Core Aggregator — RunEndConditionRaised, Idempotency Latch, and defeatReason Payload Support

> **Epic**: RunController
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 0.5 day
> **Manifest Version**: 2026-07-06

## Context

**GDD**: None — ADR-0002 is sole design authority (no GDD exists for this module)
**Requirement**: N/A — see ADR-0002 Decision, points 1, 2, and 4; Key Interfaces code block (`RunEndConditionRaised`); Risks section (`.Client`-exposure risk, `os.time()` vs `workspace:GetServerTimeNow()` risk)
**ADR Governing Implementation**: ADR-0002: RunController Architecture
**ADR Decision Summary**: RunController exposes exactly one server-internal (never `.Client`) Knit method, `RunEndConditionRaised(conditionType: "wipe"|"victory", squadState, defeatReason: ("wipe"|"scatter")?)`. The first call in a run sets a one-shot `_hasEnded` latch and fires `RunEnded` with `exitReason` = the first call's `conditionType`; every subsequent call in the same run is a silent no-op logged at `warn` level.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: Per ADR-0002's Engine Compatibility field, this ADR introduces no new Roblox engine API beyond what ADR-0001 already governs (Knit service methods, `Signal`/`BindableEvent`, `KnitInit`/`KnitStart`). The risk is architectural (server-authority correctness), not an engine-knowledge-gap — no post-cutoff API is used, no additional verification spike is required beyond ADR-0001's existing `require()`/`Signal` spike.

**Control Manifest Rules (Foundation layer)**:
- Required: "RunController exposes exactly one server-internal method, `RunEndConditionRaised(conditionType: "wipe"|"victory", squadState)`, callable by any server-side Knit service; RunController never calls back into the caller to independently verify state" — source: ADR-0002
- Required: "RunController fires `RunEnded` exactly once per run via a one-shot idempotency latch (`_hasEnded` flag); subsequent calls in the same run are silent no-ops logged at `warn` level" — source: ADR-0002
- Required: "`RunEnded` payload `timestamp` uses `os.time()` (wall-clock Unix epoch seconds), never `workspace:GetServerTimeNow()`" — source: ADR-0002
- Forbidden: "Never expose `RunEndConditionRaised` under a Knit service's `.Client` table — it must remain a plain, server-internal method; placing it under `.Client` would let any connected client end the run for the whole squad" — source: ADR-0002
- Forbidden: "Never let RunController poll Crafting/Resource-Node/Player-Controller state synchronously each tick — violates the event-subscriber-only mandate" — source: ADR-0002
- Forbidden: "Never split run-ending ownership (e.g. RunController owns defeat, Player Controller broadcasts victory directly)" — source: ADR-0002
- Guardrail: `RunEndConditionRaised` fires at most a handful of times per run (typically exactly once) — negligible CPU cost, not a per-frame call — source: ADR-0002 Performance Implications

---

## Acceptance Criteria

- [ ] `RunController:RunEndConditionRaised(conditionType, squadState, defeatReason?)` exists as a plain server-internal Knit service method — **not** declared under `RunController.Client` anywhere in the module.
- [ ] The first call to `RunEndConditionRaised` in a run sets `self._hasEnded = true` and fires `self._runEnded` with payload `{exitReason = conditionType, squadState = squadState, timestamp = os.time(), defeatReason = defeatReason}`.
- [ ] `timestamp` is produced by `os.time()` — never `workspace:GetServerTimeNow()`.
- [ ] Any subsequent call to `RunEndConditionRaised` after `_hasEnded == true` is a no-op: it does **not** re-fire `RunEnded`, does **not** mutate `_hasEnded` further, and logs at `warn` level (not `error`).
- [ ] A duplicate call with a **different** `conditionType` than the first call still results in exactly one `RunEnded` fire, with `exitReason` matching the **first** call (not the second) — this is ADR-0002's own Validation Criteria, verbatim.
- [ ] `defeatReason` is accepted as an optional third parameter (`("wipe" | "scatter")?`), passed through opaquely into the `RunEnded` payload with no branching logic inside RunController — RunController does not interpret or validate its value beyond type-shape.
- [ ] `defeatReason` is `nil` when `conditionType == "victory"` and is never populated by RunController itself — it is only ever whatever the caller supplied (RunController performs no defaulting or inference).
- [ ] `squadState` is treated as an opaque pass-through payload — RunController does not read, validate, or branch on any of its fields.
- [ ] Calling `RunEndConditionRaised` does not call back into the caller (or any other service) to independently verify state — no `Knit.GetService(...)` calls appear anywhere in this method's body.

---

## Implementation Notes

- Construct `self._hasEnded = false` inside `KnitInit` (not `KnitStart`) per ADR-0001 Rule 1 — this story's `RunEndConditionRaised` method assumes the latch already exists when first called, since callers (Player Controller) may invoke it at any point after their own boot completes.
- This story assumes the `self._runEnded` Signal object also exists by the time `RunEndConditionRaised` first runs (its construction, plus the `GetRunEndedSignal()` accessor and the cross-service subscriber-ordering guarantee, is Story 002's focus — but the `:Fire()` call in this story's method body is written against it now). If Story 002 has not landed yet, stub `self._runEnded = Signal.new()` in `KnitInit` so this story's tests can run; Story 002 will not need to change this line, only add the accessor and its dedicated integration test.
- Use Knit's bundled `Signal` class (`require(ReplicatedStorage.Packages.Signal)`), not raw `Instance.new("BindableEvent")` — per ADR-0001's Foundation-layer requirement, `Signal:Fire()` synchronicity is independent of `Workspace.SignalBehavior`.
- The `.Client`-exposure ban is the single highest-stakes acceptance criterion in this story: per ADR-0002's Risks section, a future contributor "fixing" the terminology mismatch by moving `RunEndConditionRaised` under `.Client` would let any connected game client fire a fake `RunEndConditionRaised("victory", ...)` and end the run for the whole squad — a server-authority breach per `.claude/docs/technical-preferences.md`'s "Trusting client-supplied values" forbidden pattern. Code review must treat any `.Client`-table placement of this method as an automatic blocking finding, not a style nit.
- `warn`, not `error`, on a post-latch call — ADR-0002 Consequences (Negative) explicitly accepts this as an MVP tradeoff: a caller-side race (e.g., PC calling `RunEndConditionRaised` twice) is only observable in logs, not surfaced as a hard failure.
- `defeatReason`'s type is `("wipe" | "scatter")?` — do not widen it to accept arbitrary strings; do not attempt to validate that `defeatReason == "scatter"` only co-occurs with `conditionType == "wipe"` inside RunController — that check, if wanted, belongs to the caller (Player Controller), not this module, per the event-fan-in-aggregator, no-interpretation design.
- `SquadStateSnapshot`'s concrete shape remains an open ADR-0002 question (deferred until PC's/Crafting's own squad-state types are finalized) — implement this story's tests against a minimal stub shape (`{aliveCount: number, totalCount: number}`), not a speculative full shape.

---

## Out of Scope

- `GetRunEndedSignal()` accessor and the KnitInit-before-KnitStart subscriber-ordering integration test — Story 002.
- Crafting & Items calling `RunEndConditionRaised` directly — explicitly deferred per ADR-0002's "Current caller reality" fix (2026-07-06); the sole current caller is Player Controller, forwarding Crafting's in-window BC4 outcomes. Do not wire a Crafting call site as part of this story.
- Player Controller's actual T7 (wipe)/T8 (victory) call sites into `RunEndConditionRaised` — that wiring belongs to the Player Controller epic's own stories, which are blocked on this ADR being Accepted (already true) and this story being implemented, not the other way around.
- `SquadStateSnapshot`'s finalized concrete type — open ADR-0002 question, tracked separately, not blocking for this story.
- The scripted 2-player D1 `aliveCount ≤ 2` end-to-end integration test named in ADR-0002's Validation Criteria — explicitly deferred there "once PC/Crafting are implemented."

---

## QA Test Cases

- **AC-1**: `RunEndConditionRaised` is never under `.Client`
  - Given: the compiled `RunController` Knit service module
  - When: the module table and its `.Client` sub-table (if any) are inspected
  - Then: `RunController.Client` is either `nil` or does not contain a `RunEndConditionRaised` key
  - Edge cases: also assert no RemoteEvent/RemoteFunction instance named after this method is ever created under the service's networking folder

- **AC-2**: First call sets latch and fires with correct payload
  - Given: a freshly `KnitInit`-constructed RunController (`_hasEnded == false`)
  - When: `RunEndConditionRaised("wipe", {aliveCount = 0, totalCount = 4})` is called
  - Then: `_hasEnded` becomes `true`, and `RunEnded` fires exactly once with `exitReason = "wipe"`, `squadState` equal to the passed table (by reference or deep-equal), `timestamp` a number, `defeatReason = nil`
  - Edge cases: `squadState` containing extra/unexpected fields is passed through unmodified (opaque pass-through)

- **AC-3**: `timestamp` uses `os.time()`
  - Given: a mocked/spied `os.time()` returning a known fixed value, and a spy confirming `workspace:GetServerTimeNow()` is never called
  - When: `RunEndConditionRaised` fires
  - Then: the payload's `timestamp` equals the mocked `os.time()` value exactly
  - Edge cases: none — this is a direct call-site assertion, not a timing-sensitive test

- **AC-4**: Duplicate call after latch is a silent no-op, logged at `warn`
  - Given: RunController with `_hasEnded == true` (already fired once for `"wipe"`)
  - When: `RunEndConditionRaised("victory", {aliveCount = 4, totalCount = 4})` is called a second time
  - Then: `RunEnded` does not fire again (subscriber call count stays at 1), `_hasEnded` remains `true`, and a `warn`-level log line is emitted (not `error`)
  - Edge cases: a third, fourth call behave identically (idempotent for arbitrarily many extra calls, not just exactly one duplicate)

- **AC-5**: Duplicate call with a *different* conditionType still preserves the first call's exitReason
  - Given: RunController freshly constructed (`_hasEnded == false`)
  - When: `RunEndConditionRaised("wipe", squadStateA)` is called, immediately followed by `RunEndConditionRaised("victory", squadStateB)`
  - Then: `RunEnded` fired exactly once, with `exitReason == "wipe"` and `squadState == squadStateA` (matching the FIRST call, per ADR-0002's Validation Criteria verbatim) — this is the exact scenario named in ADR-0002
  - Edge cases: reverse the order (`"victory"` first, then `"wipe"`) and confirm `exitReason == "victory"` — the latch always honors whichever call executed first, not a hardcoded preference for one `conditionType`

- **AC-6**: `defeatReason` pass-through and nil-for-victory
  - Given: RunController freshly constructed
  - When: (a) `RunEndConditionRaised("wipe", squadState, "scatter")` is called; (b) in a separate run, `RunEndConditionRaised("victory", squadState)` is called with no third argument
  - Then: (a) the `RunEnded` payload's `defeatReason == "scatter"`; (b) the payload's `defeatReason == nil`
  - Edge cases: `RunEndConditionRaised("wipe", squadState)` called with no `defeatReason` at all (pre-activation wipe, no scatter concept) results in `defeatReason == nil` — RunController must not default it to `"wipe"` or any other value

- **AC-7**: No callback into the caller
  - Given: a static/structural review of the `RunEndConditionRaised` method body
  - When: searched for any `Knit.GetService(...)` call
  - Then: zero matches — the method only reads its own arguments and mutates its own `_hasEnded`/`_runEnded` state

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/runcontroller/run_end_condition_raised_test.luau`
**Status**: [x] Created and passing — verified 2026-07-07 via `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` (exit code 0, 7/7 test files pass, 0 failures).

---

## Dependencies

- Depends on: None
- Unlocks: Story 002 (GetRunEndedSignal accessor builds on this story's `_runEnded:Fire()` call); Player Controller epic's T7 (wipe)/T8 (victory) stories, which are the sole current caller of this method; Crafting & Items epic's future direct-migration story, if ever authored (currently deferred, not planned)

---

## Completion Notes
**Completed**: 2026-07-07
**Criteria**: 9/9 passing
**Deviations**: None blocking. One non-blocking process note from `/code-review`: no test drives a live `RunController` instance end-to-end (Knit/Signal not yet vendored under `ReplicatedStorage.Packages`) — behavioral coverage is split between the pure `RunControllerLogic` module and static source-text checks against the real `RunController.luau`, an accepted, documented limitation shared with every other story in this codebase to date. Two coverage gaps found by `/code-review` and closed in the same pass: a `warn()` static check that only proved whole-file substring presence (not branch-specific correctness) was strengthened to isolate the `ShouldFire`-false branch specifically; a `squadState == nil` first-call case was untested and is now covered.
**Test Evidence**: Logic: `tests/unit/runcontroller/run_end_condition_raised_test.luau` — created and genuinely executed passing (19 test functions across 2 `describe()` blocks; full 7-file suite re-confirmed green after every code-review fix).
**Code Review**: Complete (`/code-review`, this session) — engine specialist verdict CLEAN (hand-traced the idempotency-latch mutation ordering, confirmed it exploits Knit `Signal`'s synchronous dispatch guarantee for genuine re-entrancy safety, not just conventional idempotency); QA verdict GAPS, both closed same-session.
