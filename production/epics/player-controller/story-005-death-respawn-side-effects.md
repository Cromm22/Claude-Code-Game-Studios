# Story 005: Death/Respawn Side-Effects & Cross-Service Signals (T5/T6)

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-032` (sprint hard-reset on death; respawn spawns S1 with stamina=MAX, lantern lowered), `TR-pc-041` (`PredatorService` S4 lifecycle pair `OnPlayerS4Entered`/`OnPlayerT6Respawned`), `TR-pc-042` (`PredatorService:ReleasePredatorLock` idempotent, invoked on death both paths + reconciliation success), `TR-pc-043` (`OnSquadMemberAliveChanged(playerId, isAlive)` server-internal edge to Crafting)

**ADR Governing Implementation**: ADR-0005: Death & Respawn Lifecycle
**ADR Decision Summary**: Restates PC's T5/T6 side-effect ordering as binding: three commit-INDEPENDENT run-fact side-effects (`ReleasePredatorLock`, `OnPlayerS4Entered`, `OnSquadMemberAliveChanged(isAlive=false)`) fire synchronously PRE-YIELD, at the same step-2 `Pending → InFlight` transition established in Story 004 — never gated on the oxygen charge's success, never dependent on cross-service `PlayerRemoving` teardown ordering.

**Engine**: Roblox Studio (live platform) + Knit framework | **Risk**: LOW
**Engine Notes**: No new engine API; this is a cross-service signal contract layered on Story 004's already-established state machine and ADR-0001's `KnitInit`/`KnitStart` discipline.

**Control Manifest Rules (Core layer)**:
- Required: `Humanoid.Died` handling must guard against re-entry.
- Required: Clean up any per-player table (`loadedChunks`, dedup sets, rate-limit counters) on `Players.PlayerRemoving` (ADR-0004/ADR-0006 pattern, generalized).
- Required: Mount Instances / cross-service-visible objects must be constructed during `KnitInit`, never `KnitStart` (ADR-0001 Rule 1) — the `PredatorService`/Crafting signal targets this story fires into must already exist.
- Forbidden: Never call another service's public Knit API from your own `KnitStart` and assume that service's `KnitStart`-time setup has already completed (ADR-0001) — use the RegistrationHandshake pattern if a live cross-service subscription is needed here.

---

## Acceptance Criteria

- [ ] **H.32 (TR-pc-032 sprint hard-reset)** — captured by H.21 (Story 004): sprint state hard-reset on T5; respawn (T6) spawns S1 with stamina=`STAMINA_MAX`, lantern lowered (`LanternLowered`).
- [ ] **H.51** — GIVEN player A holding a predator target-lock (mock `PredatorService`), WHEN A dies via Path A, THEN `PredatorService:ReleasePredatorLock(A)` invoked exactly once as a T5 side-effect. Paired Path-B case: a disconnect satisfying the imminent-death predicate also triggers `:ReleasePredatorLock` once. Paired reconciliation case (clock injected): a rolled-back initial charge that recovers on a tick re-invokes `:ReleasePredatorLock` on the reconciliation-success path (idempotent — net one effective release).
- [ ] **H.59** — GIVEN player A holding a predator lock, WHEN A dies via Path A (T5→S4), THEN `PredatorService:OnPlayerS4Entered(A)` invoked exactly once. Paired Path-B negative: a Path-B death (removed) fires NO `OnPlayerS4Entered`. **The real BLOCKING gate is PC's fire-side obligation only** — the mock's "never re-acquires" half is vacuous-against-mock and ADVISORY until Predator AI's GDD exists.
- [ ] **H.60** — GIVEN player A in S4 with a mock `PredatorService` recording received signals, WHEN T6 fires, THEN `PredatorService:OnPlayerT6Respawned(A)` invoked exactly once, and NO OTHER PC code path fires it (not T5, not the reconciliation tick, not a replayed `Humanoid.Died`).
- [ ] **H.72** — GIVEN a mock subscriber recording `(playerId, isAlive)` tuples, WHEN A dies via Path A, THEN exactly one `(A, false)` fires at T5; WHEN A respawns at T6, THEN exactly one `(A, true)` fires ONLY AFTER A's respawned `HumanoidRootPart` exists AND is positioned at the anchor (never at the world origin). A replayed `Humanoid.Died` fires no duplicate edge.
- [ ] **H.75** — GIVEN a death dispatched with `dispatchOrigin="initial"` captured pre-yield, WHEN the player departs mid-yield (orphaned exactly like a reconciliation orphan) and the held spend resolves successfully, THEN the commit selects the **initial** side-effect set from `dispatchOrigin` (not live-pointer-presence) — `OnPlayerDied` broadcast fires, input-lock flag set, stamina frozen, grace anchors reset, spectator-camera-activate signal emitted — while orphan-removal is selected independently by live-pointer-absence.
- [ ] **H.70** — GIVEN a death whose initial charge rolled back and recovers on a reconciliation tick, in BOTH the live-pointer case and the orphaned case, WHEN the tick commits, THEN ONLY the player-removal-safe subset (a: sprint timer stop, b: lantern force-T4, g: `ReleasePredatorLock`) fires — spectator camera NOT re-activated, stamina NOT re-frozen, grace slate NOT re-reset, input lock NOT re-applied, `OnPlayerS4Entered` NOT re-fired, `OnSquadMemberAliveChanged` NOT re-fired.

---

## Implementation Notes

- **Pre-yield ordering is the load-bearing rule (round-18 [R16-2])**: three side-effects — `(g) ReleasePredatorLock(player)`, `(h) OnPlayerS4Entered(player)` [Path A only], `(i) OnSquadMemberAliveChanged(userId, isAlive=false)` [both paths] — are facts of the death/disconnect itself, NOT of the oxygen charge. On the **initial** T5 dispatch they MUST fire synchronously in the SAME pre-yield span as Story 004's step-2 `Pending → InFlight` transition, BEFORE the yield — guarded once-only by that same transition. This makes the predator no-re-acquire gate immediate and independent of whether the charge commits AND independent of the non-deterministic cross-service `PlayerRemoving` teardown ordering.
- **Dispatch-origin discriminator (H.75)**: the post-yield commit selects its side-effect SET from a coroutine-local `dispatchOrigin ∈ {"initial", "reconciliation"}` captured at dispatch time — NOT from whether a live `currentDeathRecord` pointer exists at commit. Live-pointer-presence selects ONLY the retain-vs-remove decision for the row. These two axes are independent — a mid-yield-orphaned initial dispatch still runs the full initial set.
- **Reconciliation-tick dispatches re-fire ONLY (a)/(b)/(g)** — never (c)–(f), never (h)/(i) (H.70). `(h)` and `(i)` are one-time facts that already fired at the initial T5.
- **T6 side-effects**: clear `currentDeathRecord[player] = nil`; remove a prior-life record from `reconcileRows` IF it is `Committed` (an uncommitted `Pending`/`InFlight` record is NOT deleted — it survives by `deathEventId`); reset `lastServerTrackedPosition[player]` to the respawn-anchor position (never `nil`); fire `PredatorService:OnPlayerT6Respawned(player)` — the SINGLE trigger channel for PredatorService's own clearance of `lastPredatorDamageTimestamp`/`predatorCausedImminent`/`predatorCausedImminentSetTimestamp` (that clearance logic itself is PredatorService's, cross-epic); fire `OnSquadMemberAliveChanged(userId, isAlive=true)` **only after** the respawned `HumanoidRootPart` exists and is positioned at the anchor (Crafting's positioned-HRP re-add guarantee).
- `PredatorService:ReleasePredatorLock` is contractually **idempotent** — releasing an already-released or never-held lock is a no-op, never an error. Safe to call from both the initial dispatch and the reconciliation-success path.
- These are all server-internal Knit signals/calls — never RemoteEvents, never client-reachable, never appearing under any `Service.Client` table.

---

## Out of Scope

- Predator AI epic: the actual `PredatorService` handler implementations for `OnPlayerS4Entered`/`OnPlayerT6Respawned`/`ReleasePredatorLock` (this story only implements PC's caller/fire-side obligation and tests against a mock).
- Crafting & Items epic: `RunSession.aliveMembers`'s own consumption of `OnSquadMemberAliveChanged`.
- Story 006: Path B's own predicate for whether T5 fires at all on a disconnect.
- Story 007: dead-player input locks and `renderScope` (this story fires the death transition; Story 007 owns what the client is allowed to do and told while in it).

---

## QA Test Cases

- **AC-1 (H.51 — ReleasePredatorLock both paths + idempotent)**:
  - Given: player holding a lock, mock PredatorService.
  - When: dies via Path A.
  - Then: `ReleasePredatorLock` called exactly once.
  - Edge cases: Path B disconnect also triggers it once; reconciliation-success re-invokes it idempotently (net one effective release).
- **AC-2 (H.59/H.60 — S4/T6 lifecycle pair, fire-side only)**:
  - Given: mock PredatorService recording signals.
  - When: T5→S4 (Path A).
  - Then: `OnPlayerS4Entered` fires exactly once; Path B fires none.
  - When: T6.
  - Then: `OnPlayerT6Respawned` fires exactly once, and ONLY from T6 (not from T5, not from the reconciliation tick, not from a replayed `Died`).
  - Edge cases: the "gate never re-acquires" half of H.59 is vacuous-against-mock — do not claim it as a real gate until Predator AI's GDD lands.
- **AC-3 (H.72 — alive-edge timing)**:
  - Given: mock subscriber.
  - When: A dies (T5).
  - Then: exactly one `(A, false)`.
  - When: A respawns (T6).
  - Then: exactly one `(A, true)`, and the signal-time HRP position equals the anchor, never the world origin.
  - Edge cases: a replayed `Died` fires no duplicate edge.
- **AC-4 (H.75 — dispatch-origin vs live-pointer independence)**:
  - Given: initial dispatch, player departs mid-yield.
  - When: held spend resolves successfully.
  - Then: full initial side-effect set runs (via server-observable proxies: broadcast fired, input-lock flag true, stamina frozen, grace anchors nil, camera-activate signal emitted) despite no live pointer.
  - Edge cases: paired reconciliation dispatch with a live pointer runs ONLY (a)/(b)/(g) and retains the row.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/death-respawn-side-effects_test.luau`
**Status**: [x] Created and passing (part of the 21/21-file suite, `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` → exit 0, re-verified 2026-07-09 after code-review fixes)

---

## Dependencies

- Depends on: Story 004
- Unlocks: Story 007, Story 009; Cross-epic: Predator AI epic's `PredatorService` (`OnPlayerS4Entered`/`OnPlayerT6Respawned`/`ReleasePredatorLock` handler implementations — **note TD-016: PC fires these userId-keyed, deviating from this GDD's `(player)` text; reconcile at PA-epic first touch**); Crafting & Items epic's `OnSquadMemberAliveChanged` consumer (`RunSession.aliveMembers`)

---

## Completion Notes
**Completed**: 2026-07-09
**Criteria**: 7/7 passing — full AC traceability produced by the QA testability review; the three PARTIAL rows it found (H.72 ordering-sensitivity, H.75 missing 5th proxy, H.70 unfalsifiable grace-anchor claim) were all closed by same-session review fixes, including replacing a false test-comment coverage claim with the real `isSameLife` object-identity assertion.
**Deviations**: Two BLOCKING engine-review findings fixed same-session: (1) `Player:LoadCharacter()` reachable for departed players (T6 fires regardless of liveness) with an uncaught error aborting sibling respawns — fixed with liveness re-validation inside the now-`task.spawn`'d T6 remainder + a pcall backstop in `_defaultRespawnPlayerAtAnchor`; (2) the T6 live-Character work ran synchronously inside the Heartbeat handler — fixed per the file's own established synchronous-transition-then-task.spawn pattern, preserving H.72's ordering inside the spawned closure. Design decisions ratified by review: call-scoped `dispatchOrigin`/`pathOrigin` params (ADR-frozen `ReconcileRow` untouched — the reviewer confirmed the ADR supersedes the GDD's fuller row prose); `isSameLife` gate (traced sound); `_isPlayerDead` heartbeat-skip (traced sound, stale-watchdog-safe); `OnPlayerDied` as a genuine S→C Client signal per ADR-0006 registry item #10 (outbound-only, 6-step validation correctly N/A). Tech debt: **TD-014** (payload missing `deathTimestamp`/`deathEventId` — widen before Story 007/HUD), **TD-015** (stale-INITIAL-dispatch races a newer life — needs ruling at RM's real async call), **TD-016** (userId-keyed seam deviation), **TD-013 corrected** (T6 does fire for departed players; hook-idempotency facet CLOSED by this story's `dispatchOrigin` design). Studio-verification item carried: `LoadCharacter()`'s synchronous-completion contract (unverifiable under Lune, flagged in-code).
**Test Evidence**: `tests/integration/player-controller/death-respawn-side-effects_test.luau` — passing (21/21 suite, exit 0)
**Code Review**: Complete — CHANGES REQUIRED → all fixes applied → effectively APPROVED WITH SUGGESTIONS (engine: ISSUES FOUND with 2 must-fixes, both fixed + statically pinned; QA: GAPS, all four named gaps closed same-session; ADR-0005/0001/0006 all COMPLIANT)
