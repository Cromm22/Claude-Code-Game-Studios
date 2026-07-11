# Story 009: Run-End Contract (T7 Wipe / T8 Victory)

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-026` (T7 whole-squad-wipe raises `RunController:RunEndConditionRaised('wipe', squadState)`; PC never broadcasts `RunEnded`), `TR-pc-027` (T8 victory consumes `OnBeaconWindowSurvived`, raises `('victory', ...)`; victory-over-wipe precedence), `TR-pc-028` (`RUN_END_DEFEAT_HOLD = 0.5s` arbiter hold window), `TR-pc-029` (`_beaconActivated` latch, set/cleared/self-healed), `TR-pc-030` (PC subscribes to `RunEnded(outcome)`; drives S4/alive→S5 + input lock; idempotent)

**ADR Governing Implementation**: ADR-0005: Death & Respawn Lifecycle (restates the D1 kill-criterion and the caller-side `RunEndConditionRaised` contract this story implements; the arbiter itself is RunController's own `ADR-0002`, cross-epic, not in this epic's governing ADR list)
**ADR Decision Summary**: ADR-0005's diagram explicitly routes PC's whole-squad-wipe condition through `RunController:RunEndConditionRaised("wipe", squadState)` rather than a direct broadcast, and restates the D1 last-stand kill-criterion (`aliveCount ≤ 2`) as binding, with an analytics-segmentation instrumentation requirement. The control manifest's own Foundation-layer rule (sourced from RunController's ADR-0002) is binding here even though ADR-0002 is not one of this epic's 7 governing ADRs: **PC never broadcasts `RunEnded`; never splits run-ending ownership.**

**Engine**: Roblox Studio (live platform) + Knit framework | **Risk**: LOW
**Engine Notes**: No new engine API. This story's correctness depends entirely on a cross-epic contract (RunController's arbiter) that is authored separately — PC's own tests mock the arbiter and the stub emitters for Crafting's signals.

**Control Manifest Rules (Foundation layer)**:
- Required: RunController exposes exactly one server-internal method, `RunEndConditionRaised(conditionType, squadState)`, callable by any server-side Knit service; RunController never calls back into the caller to independently verify state.
- Required: RunController fires `RunEnded` exactly once per run via a one-shot idempotency latch; subsequent calls are silent no-ops logged at `warn` level.
- Required: `RunEnded` payload `timestamp` uses `os.time()`, never `workspace:GetServerTimeNow()`.
- Forbidden: Never let RunController poll PC's (or any Core/Feature service's) state synchronously each tick.
- Forbidden: Never split run-ending ownership (e.g., RunController owns defeat, Player Controller broadcasts victory directly) — this is the exact defect a prior migration attempt introduced and had reverted.
- Forbidden: Never expose `RunEndConditionRaised` under a Knit service's `.Client` table — it must remain server-internal.

---

## Acceptance Criteria

- [ ] **H.47** — GIVEN a squad whose Beacon fired `OnEscapeBeaconActivated` (BCT3, window-start) but NOT yet `OnBeaconWindowSurvived`, WHEN PC's T8 consumer is evaluated, THEN PC raises NO `"victory"` condition. WHEN `OnBeaconWindowSurvived(timestamp)` (BCT4) subsequently fires, THEN PC calls `RunController:RunEndConditionRaised("victory", squadState)` exactly once. Mock the signal emitter with the exact arities (`OnEscapeBeaconActivated(activatorPlayerId, timestamp, windowDurationSeconds)` / `OnBeaconWindowSurvived(timestamp)`) — do not depend on Crafting's actual implementation.
- [ ] **H.48** — GIVEN a 2-player squad where B is in S4 at the moment `OnBeaconWindowSurvived` fires, WHEN T8 resolves victory, THEN B transitions S4→S5(victory), B's respawn timer is cancelled, B is counted a survivor in `squadState`.
- [ ] **H.49** — GIVEN all 2–4 squad members in S4 AND squad oxygen `< 1`, WHEN T7's condition is met, THEN PC calls `RunEndConditionRaised("wipe", squadState)` exactly once and PC itself NEVER fires a `RunEnded` RemoteEvent.
- [ ] **H.50** — GIVEN a mocked arbiter, all members in S4 and oxygen `<1` at time `T`, WHEN T7 fires and `OnBeaconWindowSurvived` is emitted at `T+Δ` (`Δ < RUN_END_DEFEAT_HOLD`), THEN: (1) PC raised `("wipe", squadState)` exactly once with a concrete per-member liveness snapshot (deep-equal, not shape-only); (2) PC raised `("victory", squadState)` exactly once on the BCT4 emit with its own concrete snapshot; (3) throughout the hold window PC itself broadcasts no `RunEnded`, no defeat banner, no defeat UI state; (4) PC mutates no run-end state on its own authority while the hold is pending.
- [ ] **H.61** — GIVEN a mocked arbiter and the H.47 stub emitter, WHEN `OnEscapeBeaconActivated` fires (latch set) and THEN all squad members enter S4 with oxygen `<1`, THEN PC raises NO `"wipe"` for the WHOLE post-activation lifecycle (clock advanced well past `RUN_END_DEFEAT_HOLD`, still no raise). Paired pre-activation positive: identical all-dead condition WITHOUT prior activation raises `"wipe"` exactly once. Paired latch-release: the latch clears ONLY on the arbiter's `RunEnded` broadcast (primary) or the `BEACON_LATCH_TIMEOUT` self-heal (H.61c) — and nothing else; test both directions (does clear on `RunEnded`; does NOT clear mid-run on any other event within the timeout window).
- [ ] **H.61b** — GIVEN `PlayerControllerService` at server/run start, THEN immediately after bootstrap (before any `OnEscapeBeaconActivated`) `_beaconActivated == false` AND `_beaconActivatedAt == nil`. Paired N+1-run fresh-start: after a full run completes and clears, a fresh run begins with `_beaconActivated == false` again (never ratchets across run boundaries).
- [ ] **H.61c** — GIVEN the latch SET with no inbound `RunEnded` ever delivered, WHEN the clock advances past `_beaconActivatedAt + BEACON_LATCH_TIMEOUT` and a reconciliation-tick Heartbeat fires, THEN the guard force-clears the latch, emits a `beacon-latch-timeout` warning, T7 wipe terminal re-enabled. Paired negative: clock advanced only to `timeout − ε` → latch stays true, T7 stays suppressed. Paired straggler-`RunEnded`: arriving after self-heal already cleared → idempotent no-op. Paired double-`RunEnded` (no self-heal involved): two broadcasts for the same run resolve to exactly one effect — post-second-broadcast state is byte-identical to post-first-broadcast state.

---

## Implementation Notes

- **PC never broadcasts `RunEnded`** — it only ever calls `RunController:RunEndConditionRaised(conditionType, squadState)` where `conditionType ∈ {"wipe", "victory"}`. This is the binding cross-epic contract; do not implement any local `RunEnded` broadcast path from PC.
- `squadState` is a per-member liveness snapshot `{ [userId] = "alive" | "S4" | "S5" }`, captured at raise time — the arbiter uses this to resolve the S4-rescue rule.
- **T7 (whole-squad-wipe)**: fires when all 2–4 squad members are in S4 AND squad oxygen `< 1` — **AND `NOT _beaconActivated`** (post-activation, Crafting's own BCT-DEFEAT owns the wipe terminal instead; PC's raise is suppressed for the WHOLE post-activation lifecycle, not merely a hold window).
- **T8 (victory)**: consumes `OnBeaconWindowSurvived(timestamp)` (Crafting's BCT4 window-END signal) — **explicitly NOT** `OnEscapeBeaconActivated` (BCT3, the window-START cue only). Raising `"victory"` on activation instead of survival is the exact regression this AC (H.47) exists to catch.
- **`_beaconActivated` latch lifecycle**: init `false`/`nil` at bootstrap (alongside Story 004's other bootstrap-initialized tables); SET once on `OnEscapeBeaconActivated` receipt (recording `_beaconActivatedAt = getServerTime()` via PC's C.11 seam); CLEARED primarily on the inbound `RunEnded` broadcast, OR by the `BEACON_LATCH_TIMEOUT` self-heal (default 300s, range 180–600) folded into the existing reconciliation-tick Heartbeat connection (no new connection) — this is a Pillar-4 backstop against a dropped/never-sent arbiter broadcast wedging the run.
- **Inbound `RunEnded(outcome)` subscription**: clears `_beaconActivated`; drives every alive/S4 player → S5 by `outcome`, cancelling respawn timers and rescuing S4-players on victory; is idempotent (a second `RunEnded` within an already-resolved run is a no-op — latch already clear, players already in S5); accesses no client-supplied state (`outcome` originates server-side from the arbiter only).
- Mock the arbiter and Crafting's stub emitters in every test — do NOT depend on RunController's or Crafting's actual implementation, both of which are separate epics.
- No dedicated ADR in this epic's governing list owns the arbiter itself (RunController's `ADR-0002` does, but it is out of this epic's scope) — implement PC's caller-side contract per the GDD's own C.5.8/C.6 specification, and escalate to `/architecture-decision` only if a genuine ambiguity in PC's own raise-side logic is hit.

---

## Out of Scope

- RunController epic: the arbiter itself — its own `RunEndConditionRaised` receiving implementation, its one-shot `RunEnded` idempotency latch, its `RUN_END_DEFEAT_HOLD` precedence resolution (victory-over-wipe), and its raise-axis idempotency.
- Crafting & Items epic: `OnEscapeBeaconActivated`/`OnBeaconWindowSurvived`/`OnBeaconWindowFailed`'s own producer implementation and BCT-DEFEAT's direct raise to the arbiter.
- Resource Management epic: D1 kill-criterion analytics segmentation (this story only feeds the wipe condition the criterion measures against).

---

## QA Test Cases

- **AC-1 (H.47 — T8 consumes survival, not activation)**:
  - Given: activation fired, survival not yet fired.
  - When: T8 consumer evaluated.
  - Then: no victory raise.
  - When: survival fires.
  - Then: exactly one `("victory", squadState)` raise.
  - Edge cases: mock arities must match Crafting's exact declared signature, not a stale zero-arity form.
- **AC-2 (H.49 — T7 raises, never broadcasts)**:
  - Given: all-S4, oxygen<1, pre-activation.
  - When: T7 fires.
  - Then: exactly one `("wipe", squadState)` raise; zero `RunEnded` broadcasts from PC (assert via a mocked RemoteEvent surface with zero fire calls).
- **AC-3 (H.61 — BC4 suppression, both directions of the latch)**:
  - Given: activation fired (latch true).
  - When: all-dead condition occurs, clock advanced well past the defeat-hold.
  - Then: no wipe raise for the whole lifecycle.
  - Given: latch cleared via `RunEnded`.
  - When: a subsequent run's pre-activation all-dead condition occurs.
  - Then: raises `"wipe"` again (latch never ratchets across runs).
  - Edge cases: within the timeout window, non-`RunEnded` events (alive-changed edges, a T6 respawn, arbitrary Heartbeats) must NOT clear the latch.
- **AC-4 (H.61c — self-heal backstop)**:
  - Given: latch set, no `RunEnded` ever arrives.
  - When: clock passes `BEACON_LATCH_TIMEOUT`.
  - Then: force-clear, warning logged, T7 re-enabled.
  - Edge cases: a straggler `RunEnded` after the self-heal is an idempotent no-op; a duplicate `RunEnded` with no self-heal involved produces byte-identical post-state.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/run-end-contract_test.luau`
**Status**: [x] Created and passing (part of the 24/24-file suite, `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` → exit 0, re-verified 2026-07-11 after code-review fixes)

---

## Dependencies

- Depends on: Story 004, Story 005; Cross-epic: RunController arbiter (**REAL — rc-1/rc-2 done; production wiring targets the live service, tests mock the seam**); Crafting & Items epic's `OnEscapeBeaconActivated`/`OnBeaconWindowSurvived` producers (**stubbed** — injectable emitters with the exact H.47 arities)
- Unlocks: Story 010

---

## Completion Notes
**Completed**: 2026-07-11
**Criteria**: 7/7 passing per named sub-case (QA verified every sub-case against the actual test file; deep-equal assertions confirmed genuinely recursive; fake RunEnded payloads confirmed matching the REAL arbiter's `{exitReason, squadState, timestamp, defeatReason?}` shape). Review-fix additions: self-heal→genuine-re-raise + guard-still-blocks pair, N+1-run wipe re-raise (AC-3's literal promise), solo-squad T7 (pure + Fake — engine review confirmed `squadSize > 0` matches the GDD's literal no-floor wording), the behavioral same-tick wipe-preempts-respawn race test, and the ForceSelfHeal traced-and-found-safe note.
**Deviations**: Wired to the REAL arbiter payload over the GDD's stale `outcome ∈ {"victory","defeat"}` prose (engine-ratified; GDD C.9 inbound-row text needs a sync at next touch). **TD-018 logged** (RunControllerLogic's exported SquadStateSnapshot type still ADR-0002's `{aliveCount,totalCount}` placeholder vs the real userId-keyed shape PC sends — sync + ADR-0002 addendum before any HUD/analytics consumer). **TD-019 logged** (`Packages/` empty — Knit/Signal not vendored; Signal `:Fire()` synchronicity is load-bearing for the wipe-before-respawn Heartbeat ordering; verify at first Studio boot). Known out-of-scope gap per the story's own text: RunController lacks `RUN_END_DEFEAT_HOLD`/victory-over-wipe precedence (future RunController story — PC's raise-side contract is complete regardless). Scope-adjacent addition disclosed: `BEACON_LATCH_TIMEOUT` KnitInit config gate (range 180–600) added by codebase precedent. Raise-once design: independent `hasRaisedWipe`/`hasRaisedVictory` flags reset on RunEnded, deliberately NOT on self-heal (traced safe — a lost broadcast is not a fresh run).
**Test Evidence**: `tests/integration/player-controller/run-end-contract_test.luau` — passing (24/24 suite, exit 0)
**Code Review**: Complete — engine specialist MINOR NOTES (zero must-fix; ADR-0002/0005 PASS; composed-Heartbeat ordering + self-heal interaction traced sound); QA GAPS (2 medium composition gaps + 2 edges, ALL closed same-session)
