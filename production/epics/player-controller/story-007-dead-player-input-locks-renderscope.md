# Story 007: Dead-Player Input Locks & renderScope (S4/S5)

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-034` (dead-player input state guards: `RequestPing` rejected S4/S5; `renderScope` server-minted; movement/gather locked)

**ADR Governing Implementation**: ADR-0012: Player Controller Dead-Player Input Lock & Minimal Spectator State
**ADR Decision Summary**: `renderScope` is a `"alive" | "dead-respawning" | "post-run"` enum, pushed to the owning client exactly once per state transition, server-minted inside the same handler that performs the S1/S4/S5 transition — never inferred client-side. While in S4: `RequestGather`/`RequestLanternToggle`/`RequestSprintToggle`/`RequestPing` are all rejected at the step-1 alive/state guard; movement is locked via `Humanoid.WalkSpeed = 0` and `Humanoid.JumpPower = 0` (not by destroying the character). S5 is a strictly stricter superset of S4's locks.

**Engine**: Roblox Studio (live platform) | **Risk**: MEDIUM
**Engine Notes**: The input-lock and `renderScope` contract are LOW risk (standard RemoteEvent server-authority patterns already governed by ADR-0006). The spectator camera's chunk-load guard is a separate, HIGH-risk item — scoped out to Story 008.

**Control Manifest Rules (Core layer)**:
- Required: Every client-fired `RemoteEvent` handler evaluates alive/state guard FIRST, before any other check (ADR-0006 step 1) — this story is that step's concrete implementation for PC's own events.
- Required: A dropped event must not mutate any state.
- Forbidden: Never let a client infer its own `renderScope`/dead-state from a locally-observable proxy signal (e.g., `Humanoid.Health`) — server-minted, pushed explicitly, per ADR-0012's rejection of Alternative 2.

---

## Acceptance Criteria

- [ ] **H.24** — GIVEN a player in S4, WHEN the player sends `RequestEmote`, THEN accepted server-side; WHEN the player sends `RequestPing`, THEN REJECTED (no `OnPingBroadcast`); movement/sprint/lantern/gather requests in the same window are also rejected.
- [ ] **H.34** — GIVEN a player on touch with the emote wheel open, WHEN a `RequestGather` would normally fire from a tap-hold, THEN suppressed client-side, no `RequestGather` reaches the server. After the wheel closes, the same input fires normally. *(T9 mutual-exclusion — cross-referenced here since it interacts with the alive/state guard's input surface.)*
- [ ] **C.5.4 input-lock contract (ADR-0012 Validation Criteria)** — a `RequestGather`/`RequestLanternToggle`/`RequestSprintToggle`/`RequestPing` call from a player in S4 or S5 is rejected with no state mutation.
- [ ] **`renderScope` transition discipline (ADR-0012 Validation Criteria)** — `renderScope` transitions exactly once per state change, never polled or re-sent redundantly; a scope of `"post-run"` (S5) rejects strictly more RemoteEvents than `"dead-respawning"` (S4) rejects (S5 is a superset of S4's locks — no exception permitted in S5 that S4 allows).

---

## Implementation Notes

- **S4 entry** (called from Story 005's T5 handler): set `renderScope[player] = "dead-respawning"` via `_setRenderScope` (fires a per-client targeted push, `_onRenderScopeChanged`); set `Humanoid.WalkSpeed = 0` and `Humanoid.JumpPower = 0` on the still-present character (do NOT destroy the character — the camera needs a `HumanoidRootPart` reference, Story 008).
- **S5 entry** (called from Story 009's `RunEnded` subscription): set `renderScope[player] = "post-run"` — every client-fired RemoteEvent PC defines is rejected at the same step-1 guard.
- **The single shared guard**: `_isEligibleForGameplayEvents(player)` returns `renderScope[player] == "alive"`. Every PC RemoteEvent handler (`RequestGather`, `RequestLanternToggle`, `RequestSprintToggle`, `RequestPing`) calls this as its literal step-1 check — no separate S5-specific rejection logic is needed since the same boolean covers both states.
- **`renderScope` is never inferred client-side** — this closes the alternative of deriving render state from `Humanoid.Health <= 0`, which a `Humanoid.Died` double-fire race (already guarded in Story 004) or a replication-timing quirk could desync.
- `RequestPing` is explicitly rejected in BOTH S4 and S5 (a dead or post-run player cannot ping) — this is the R17-3 cut (pending the Camera GDD's dead-spectator distinguishability work, a forward obligation, not this story's to resolve).
- Use `:WaitForChild("Humanoid")`-style patterns consistent with ADR-0003's guidance if the character is mid-respawn when the S4 entry handler fires.

---

## Out of Scope

- Story 008: the spectator camera target itself (this story only mints `renderScope` and locks input; Story 008 consumes `renderScope == "dead-respawning"` to drive camera behavior).
- Story 009: the `RunEnded` subscription that triggers S5 entry (this story implements what S5 entry DOES once triggered).
- Story 012: `RequestPing`'s deeper trust-boundary validation (origin tolerance, server-side raycast re-run) — this story only covers the S4/S5 alive-guard rejection.
- Story 013: the emote-wheel D-pad flow and cosmetic replacement itself (H.34's T9 lockout is cross-referenced here only because it touches the same input-eligibility surface).

---

## QA Test Cases

- **AC-1 (H.24 — S4 input acceptance/rejection matrix)**:
  - Given: player in S4.
  - When: `RequestEmote` sent.
  - Then: accepted.
  - When: `RequestPing`/movement/sprint/lantern/gather sent.
  - Then: all rejected, no state mutation.
  - Edge cases: verify rejection happens at step-1 (before rate-limit/payload checks even run) so a flood of rejected S4 requests never perturbs any cooldown anchor.
- **AC-2 (`renderScope` single-mint discipline)**:
  - Given: a player transitioning S1→S4.
  - When: the transition handler runs.
  - Then: exactly one `OnRenderScopeChanged` push, value `"dead-respawning"`.
  - Edge cases: no polling, no redundant re-send on subsequent Heartbeats while still in S4.
- **AC-3 (S5 superset property)**:
  - Given: a player in S5.
  - When: any RemoteEvent PC defines is sent.
  - Then: rejected — assert this holds for every event PC exposes, not just the four named in H.24 (S5 must reject a strict superset of what S4 rejects).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/dead-player-input-locks-renderscope_test.luau`
**Status**: [x] Created and passing (part of the 23/23-file suite, `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` → exit 0, re-verified 2026-07-11 after code-review fixes)

---

## Dependencies

- Depends on: Story 004, Story 005
- Unlocks: Story 008, Story 009, Story 010, Story 012, Story 013

---

## Completion Notes
**Completed**: 2026-07-11
**Criteria**: 4/4 passing. H.24's RequestEmote-accept and RequestPing-reject halves are structurally covered at the classification-table level with explicit pending-Story-012/013 in-file disclosures (no such handlers exist yet); H.34 deferred to Story 013 (client-side), disclosed in-file. The S5 strict-superset property is proven mechanically over the data-driven `S4_ALLOWED_EVENT_CLASSES` table (no second rejection list to drift). renderScope single-mint proven behaviorally (all 3 transitions, no-redundant-resend, placement-failure negative) + structurally (sole-mint-site, exactly-3-transition-sites, guard-is-step-1-in-every-handler pins).
**Deviations**: **TD-017 logged** — the S4 input-lock is commit-gated per the GDD's own C.5.3 (a)–(f) ordering, so `renderScope` stays "alive" (inputs accepted) during a future async RM yield window: a genuine GDD-vs-ADR-0012 tension, faithfully implemented per the GDD, needs a design ruling bundled with TD-015's trigger. Review fixes applied same-session: jump lock switched to CAPTURE-AND-RESTORE of both `JumpPower` and `JumpHeight` (the modern `UseJumpPower=false`/`JumpHeight` rig mechanism would have made JumpPower-only zeroing a silent no-op; the unverified `DEFAULT_JUMP_POWER` constant was removed entirely; `UseJumpPower` per-rig state carried as a STUDIO VERIFICATION item); `_renderScope`/`_capturedJumpState` H.75 recreation leak disclosed in-code per the `_deathEffectsState` precedent; +5 test additions (S5 TryCommitGatherHold, PlayerRemoving-clears pin, nil-character S4/T6 grace, capture-not-default proof, `:FireAll` regression pin). ADR-0012's Key Interfaces sample should be annotated to the landed commit-gated timing and GDD C.9 should gain an `OnRenderScopeChanged` row (forward obligations, in TD-017's text). Guard rename `_isAliveAndEligible`→`_isEligibleForGameplayEvents` verified fully retired; both `networkownership-bandwidth_test.luau` pin updates verified legitimate and intent-preserving.
**Test Evidence**: `tests/integration/player-controller/dead-player-input-locks-renderscope_test.luau` — passing (23/23 suite, exit 0)
**Code Review**: Complete — engine specialist ISSUES FOUND (non-blocking, all tracked/fixed: TD-017 registered, capture-and-restore applied, disclosure added, pin added); QA TESTABLE with 4 gaps (all closed same-session); ADR-0012/0006 compliant with the disclosed commit-gating tension
