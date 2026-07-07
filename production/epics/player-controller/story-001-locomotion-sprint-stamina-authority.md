# Story 001: Locomotion & Sprint-State Authority (S1/S2) + Stamina + Ghost-Sprint Guard

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1.5 days
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-001` (locomotion driver, WALK_SPEED=12/SPRINT_SPEED=20), `TR-pc-002` (per-platform sprint binding), `TR-pc-003` (jump mid-sprint, pulse timers not reset-on-interrupt), `TR-pc-004` (sprint-state authority model), `TR-pc-005` (server-authoritative stamina drain/regen), `TR-pc-006` (`OnStaminaChanged` push ≤5Hz), `TR-pc-013` (clock-injection seam), `TR-pc-039` (`PlayerHeartbeat` S2-only 1Hz + `SPRINT_CLIENT_TIMEOUT` ghost-sprint force-revert)

**ADR Governing Implementation**: ADR-0011: Player Controller Sprint-State Authority & Stamina Lifecycle
**ADR Decision Summary**: A two-state server-authoritative locomotion state (S1 Walk / S2 Sprint) owned entirely by `PlayerControllerService`, transitioning only via validated `RequestSprintToggle` or a forced-revert condition. Stamina drains 12.5/s in S2, regens 10/s in S1 after a 1.5s delay, forces S1 at 0 stamina same-tick. A `PlayerHeartbeat`-staleness watchdog (3s) force-reverts a ghost-sprinting client.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: This ADR reuses `Humanoid.WalkSpeed` (ratified by ADR-0003) and `RunService.Heartbeat`; no new engine API. No post-cutoff APIs used. ADR-0003's own open item (mid-sprint `WalkSpeed` reassignment smoothness) is inherited, not re-verified here — pending the `/prototype predator-ai` spike.

**Control Manifest Rules (Foundation/Core layer)**:
- Required: Locomotion driver for Player Controller and Predator AI is `Humanoid`-driven movement (`Humanoid.WalkSpeed`, `MoveDirection`) — a single shared primitive so `WALK_SPEED < HUNT_APPROACH_SPEED < SPRINT_SPEED` stays meaningful (ADR-0003).
- Required: Use `:WaitForChild("Humanoid")` at character-setup time, not `FindFirstChildOfClass("Humanoid")` immediately after `CharacterAdded` (ADR-0003).
- Required: `RequestSprintToggle` follows ADR-0006's canonical 6-step order; this ADR is step 6 (domain validation).
- Forbidden: Never let Predator AI and Player Controller use different locomotion primitives (ADR-0003).
- Forbidden: Never force server-owned `NetworkOwnership` on player characters as a substitute for server-authoritative `WalkSpeed` (ADR-0008) — speed authority comes from the server setting `WalkSpeed`, not from ownership.
- Guardrail: `OnStaminaChanged` rate-limited to ≤5Hz, owning client only — never `:FireAll`.

---

## Acceptance Criteria

- [ ] **H.1** — GIVEN a `PlayerControllerService` with default config, WHEN `GetMoveSpeed(state)` is called, THEN returns 12 studs/s for `Walk` and 20 studs/s for `Sprint`.
- [ ] **H.2** — GIVEN a Lemur headless server with one player at `WALK_SPEED`, WHEN the player holds W for 3s on flat terrain and releases, THEN XZ-displacement equals `WALK_SPEED × 3s ± 0.5 studs`, Y-axis uncounted (Logic gate, BLOCKING); PC manual-playtest confirmation is ADVISORY feel-only.
- [ ] **H.3** — GIVEN a sprinting player with `getServerTime()` injected, WHEN a jump physics event fires mid-sprint, THEN the Sprint emission interval timer is unaffected — next pulse fires at the expected `SPRINT_PULSE_INTERVAL = 2s` boundary from the prior pulse regardless of the jump.
- [ ] **H.4** — GIVEN stamina = 100 and sprint active, WHEN `TickStamina(dt = 0.01667)` is called once, THEN stamina = `clamp(100 − 12.5 × 0.01667, 0, 100) ≈ 99.792` (±0.001).
- [ ] **H.5** — GIVEN stamina = 50, sprint inactive, regen-delay expired, WHEN `TickStamina(dt = 0.01667)` is called, THEN stamina ≈ 50.167 (±0.001).
- [ ] **H.6** — GIVEN `s_0 = 50`, WHEN `T_sprint(s_0)` is computed, THEN result = 4.0s ± 0.01s.
- [ ] **H.7** — GIVEN stamina = 0, WHEN client sends `RequestSprintToggle(sprint=true)`, THEN server rejects, player remains S1, no `OnSprintStateChanged` broadcast.
- [ ] **H.8** — GIVEN sprint exits at `t_end` (clock injected), WHEN advanced to `t_end + 1.4s`, THEN `IsRegenActive()` = false; at exactly `t_end + 1.5s`, STILL false (strict `>`); at `t_end + 1.5s + ε` for any positive ε, THEN true.
- [ ] **H.13** — GIVEN a touch sprint toggle active, `getServerTime()` injected, WHEN stamina depletes to 0 and force-walk (T2) engages, THEN server clears sprint-authorization such that no further `RequestSprintToggle=true` is honored until a fresh toggle assertion (no ghost-hold across forced T2). MANUAL-DEVICE (iPhone SE-class) confirms the touch button visually returns to "off" (ADVISORY).
- [ ] **H.26** — MANUAL-PLAYTEST (PC + Gamepad): one PC tester (KB+M hold) and one gamepad tester (L3 hold) on the same server both initiate sprint from `s_0 = 50` and hold continuously; both exhaust stamina at exactly `t = 4.0s ± 1 frame`; both transition to S1 within the same Heartbeat.
- [ ] **H.33a** — GIVEN a player in S2 sending `PlayerHeartbeat` at 1Hz, clock injected, WHEN the client stops sending heartbeats and the injected clock advances `SPRINT_CLIENT_TIMEOUT = 3s` past `_lastHeartbeatTime`, THEN within 1 Heartbeat: transition to S1, stop sprint pulse timer, stop emitting Sprint pulses, start `STAMINA_REGEN_DELAY` timer.
- [ ] **H.33b** — GIVEN a player in S2 sending heartbeats at 1Hz, WHEN the client floods heartbeats faster than `HEARTBEAT_SEND_RATE = 1Hz` (10/s), THEN excess is dropped, `_lastHeartbeatTime` updated by accepted events ONLY, stamina continues draining normally, sprint terminates at the normal stamina-0 boundary (not extended by heartbeat traffic).
- [ ] **H.33c** — GIVEN a player in S1, WHEN client sends `PlayerHeartbeat`, THEN server silently drops it (no error, no ban), `_lastHeartbeatTime` NOT updated, no state transition.
- [ ] **H.82** — GIVEN stamina = 80 and sprint active, WHEN `TickStamina(dt = -0.05)` is called (negative delta), THEN stamina remains exactly 80 (drain formula cannot refund). GIVEN stamina = 50, sprint inactive, regen-delay expired, WHEN `TickStamina(dt = -0.05)` is called, THEN stamina remains exactly 50 (regen formula cannot drain).

---

## Implementation Notes

- Two-state server-authoritative locomotion state (`S1`/`S2`) owned by `PlayerControllerService`; the domain-validation step (ADR-0006 step 6) for `RequestSprintToggle`: honor a toggle to `S2` only if `currentState == S1 AND stamina > 0`; silently ignore (no state change, no error) a sprint request at `stamina <= 0`. A request to stop sprinting is always honored immediately.
- `Humanoid.WalkSpeed` is set server-side inside the same handler that processes the toggle — never client-side. `S1 -> WALK_SPEED (12)`, `S2 -> SPRINT_SPEED (20)`.
- Stamina tick is `RunService.Heartbeat`-bound, connected in `KnitStart` (an engine-event connection, not a cross-service-visible object under ADR-0001 Rule 1). Drain `12.5 * dt` in S2; regen `10 * dt` in S1 once `REGEN_DELAY (1.5s)` has elapsed since leaving S2; both clamped to `[0, STAMINA_MAX]`. Forced transition to S1 happens in the SAME tick stamina hits 0 — never leave a player visibly sprinting at 0 stamina for even one frame.
- **Use PC's own C.11 clock-injection seam** (`PlayerControllerService.getServerTime`) for every timestamp read in this story — never `workspace:GetServerTimeNow()` inline. This was a real bug caught in ADR-0011's first draft (2026-07-06 re-verification) and is CI-grep-gated per PC's GDD C.11.
- Ghost-sprint guard: `PlayerHeartbeat` (client-sent at 1Hz while in S2 only) tracked as `_lastHeartbeatTime[player]`. A Heartbeat-bound watchdog force-transitions to S1 if `now - _lastHeartbeatTime[player] > SPRINT_CLIENT_TIMEOUT (3s)`, using the same force-transition path as stamina exhaustion (no client round-trip).
- `OnStaminaChanged` is rate-limited to ≤5Hz, sent only to the owning client (never `:FireAll`); it is display-only — the client never gates its own input on it.
- Compute `now` **once** at the top of the tick loop body and inline the regen-eligibility check — do not call a separate helper from a sibling `if` branch (the ADR's first draft had an out-of-scope-variable bug an engine-specialist review caught and fixed).
- Add a `Players.PlayerRemoving` cleanup that clears `_playerState[player] = nil` — without it this table leaks one entry per departed player for the life of the server (the same leak class ADR-0004/ADR-0006 already guard against).
- Use `:WaitForChild("Humanoid")` at character-setup time, not an immediate `FindFirstChildOfClass("Humanoid")` after `CharacterAdded` (ADR-0003's spawn-timing race).
- **Performance**: the per-player stamina tick + ghost-sprint watchdog are both a handful of arithmetic comparisons per Heartbeat, bounded by squad size (≤4 connected players) — negligible per-frame cost from this story's own scope. The system-wide budget this contributes to is PC's own `H.28` acceptance criterion (Story 011): average CPU time across ALL of PC's combined state machines (locomotion, stamina, lantern, emission timers, reconciliation tick) <0.1ms/frame — not a per-story obligation of this one.

---

## Out of Scope

- Story 002: Lantern axis (S3a/S3b), light-to-gather gate.
- Story 003: Sprint/Light emission publishing (`DisturbanceService:Emit`), grace-window/cooldown magnitude logic.
- Story 010: The shared per-player global RemoteEvent budget check and the canonical 6-step order's steps 1–5 as a reusable helper (this story implements step 6 only, per ADR-0011's scope).
- Per-platform touch/gamepad input binding *specifics* beyond the input-shape convention already documented in `design/ux/interaction-patterns.md` (TR-pc-002's exact touch-toggle/gamepad-hold wiring) — no ADR governs this mechanism; implement per the GDD's own C.1.3 specification (touch=toggle, KB+M=hold, gamepad=hold), and escalate to `/architecture-decision` if a real engine ambiguity is hit during implementation.

---

## QA Test Cases

- **AC-1 (H.1)**: GetMoveSpeed returns correct constants.
  - Given: default config.
  - When: `GetMoveSpeed("Walk")` / `GetMoveSpeed("Sprint")` called.
  - Then: 12 / 20 studs/s respectively.
  - Edge cases: unrecognized state string should not silently return a stale value — assert an explicit error or a documented default.
- **AC-2 (H.4/H.5 — drain/regen formulas)**:
  - Given: stamina=100, S2 active.
  - When: one Heartbeat tick at `dt=0.01667`.
  - Then: stamina ≈ 99.792 (±0.001).
  - Edge cases: `dt` spike to 0.5s (extreme lag) must clamp safely (see H.82); negative `dt` must not refund/drain (H.82).
- **AC-3 (H.7 — zero-stamina sprint rejection)**:
  - Given: stamina = 0.
  - When: `RequestSprintToggle(sprint=true)`.
  - Then: rejected, player stays S1, no broadcast.
  - Edge cases: stamina = 0.4 (just above zero) must be honored (T1 fires, ~2 frames of sprint before forced-walk) — this is correct behavior, not a bug (E.B).
- **AC-4 (H.8 — regen-delay strict boundary)**:
  - Given: sprint exits at `t_end`, clock injected.
  - When: advanced to `t_end + 1.4s`, then exactly `t_end + 1.5s`, then `t_end + 1.5s + ε`.
  - Then: false, false (strict `>`, still inside delay), true.
  - Edge cases: use an ε-based assertion (e.g. 0.001s), never a tick-rate-derived hardcoded constant.
- **AC-5 (H.33a/b/c — ghost-sprint + heartbeat rate limiting)**:
  - Given: player in S2 sending heartbeats at 1Hz.
  - When: heartbeats stop and clock advances past 3s.
  - Then: forced S2→S1 within 1 Heartbeat, sprint timer stopped, regen-delay timer started.
  - Edge cases: heartbeat flood (10/s) must not extend sprint beyond the stamina bound; heartbeat from S1 must be dropped silently with no timestamp update.
- **AC-6 (H.13 — no ghost-hold post force-walk)**:
  - Given: touch sprint toggle active, stamina depletes to 0.
  - When: T2 force-fires.
  - Then: server-side toggle-authorization state clears; a stale `sprint=true` re-assertion (not a fresh press) is not honored.
  - Edge cases: this is the Logic gate; the touch button's visual return to "off" is a separate MANUAL-DEVICE ADVISORY check.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player-controller/sprint-stamina-authority_test.luau`
**Status**: [x] Created and passing — verified 2026-07-07 via `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` (exit code 0, 7/7 test files pass, 0 failures).

---

## Dependencies

- Depends on: None
- Unlocks: Story 002, Story 003, Story 004 (T5 clears sprint state, consumes this story's transition function), Story 010, Story 011, Story 014

---

## Completion Notes
**Completed**: 2026-07-07
**Criteria**: 13/13 passing (H.26 correctly DEFERRED — a real, documented manual-playtest placeholder with zero assertions, not fabricated as automated)
**Deviations**: None blocking. Two documented, pre-approved ADR-0011 deviations from the implementation session: `GetMoveSpeed` takes the ADR's bound `"S1"|"S2"` type rather than the story doc's informal "Walk"/"Sprint" prose; `HandleSprintToggleDomain` takes the real `{sprint: boolean}` payload with both-direction same-state debounce, matching pc-2's own Implementation Notes, which explicitly cite this event as the precedent their debounce discipline was copied from. Six coverage gaps found by `/code-review` and closed in the same pass: same-state debounce was untested in both directions; the voluntary "stop sprinting" domain path (`sprint=false`) had never been directly exercised, only inferred via the forced-revert path; a fresh-never-sprinted S1 player's nil-safety branch was untested; `CheckSprintToggleRateLimit` had zero coverage despite this project's own exploit-resistance testing standard; the cross-event shared-budget interaction and the two Knit-only broadcasts were disclosed only generically rather than by name — all six now closed or explicitly itemized.
**Test Evidence**: Logic: `tests/unit/player-controller/sprint-stamina-authority_test.luau` — created and genuinely executed passing (20 test functions; full 7-file suite re-confirmed green after every code-review fix).
**Code Review**: Complete (`/code-review`, this session) — engine specialist verdict CLEAN (all 5 stamina/regen formulas, the forced-transition-same-tick behavior, and the reused-global-budget claim independently hand-traced and confirmed correct); QA verdict GAPS, all closed same-session.
