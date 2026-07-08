# Story 004: Death-Cost Reconciliation Core (deathEventId + State Machine)

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-016` (death moment via `GetOnPlayerDiedSignal()`, not direct `Humanoid.Died`), `TR-pc-017` (`RESPAWN_DELAY=30s` timer + idempotent guard), `TR-pc-018` (oxygen deduction via `RequestSquadOxygenSpend`, idempotent per `(userId, deathEventId)`), `TR-pc-019` (`DeathCostReconciliation` state machine: Pending/InFlight/Committed/Abandoned, post-yield ownership re-check), `TR-pc-020` (`deathEventId` = PC-minted monotonic counter), `TR-pc-021` (reconciliation tick every 5s, staleness-sweep re-arm), `TR-pc-025` (T5 pre-yield side-effect ordering), `TR-pc-045` (`KnitInit` builds signals, `KnitStart` connects)

**ADR Governing Implementation**: ADR-0005: Death & Respawn Lifecycle
**ADR Decision Summary**: PC mints `deathEventId` from a monotonic per-server-session counter (sole minter). The oxygen-spend charge is dispatched through a ratified Pending → InFlight → Committed/Abandoned state machine, with a **load-bearing post-yield re-check** (`row.state == "InFlight"`) before committing — a staleness-sweep-re-armed row's late success is discarded, never committed or rolled back. `Humanoid.Died`'s idempotent guard prevents a double-fire from resetting the respawn timer or minting a second `deathEventId`.

**Engine**: Roblox Studio (live platform) + Knit framework | **Risk**: LOW
**Engine Notes**: Introduces no new engine API beyond `Humanoid.Died` (governed by Ecological Disturbance's `ADR-0004` sole-subscriber monopoly, cross-epic) and standard Knit service-to-service calls (ADR-0001). No post-cutoff APIs used.

**Control Manifest Rules (Core layer)**:
- Required: `Player Controller mints deathEventId from a monotonic per-server-session counter (nextDeathEventId())`; it is the sole minter — Resource Management and any other consumer treat it as an opaque key.
- Required: `RequestSquadOxygenSpend(deadPlayerUserId, amount, reason, deathEventId)` is deduplicated by Resource Management against the compound key `(deadPlayerUserId, deathEventId)`; a duplicate call is a silent no-op.
- Required: The async oxygen-spend charge follows Pending → InFlight → Committed/Abandoned. On the success path, the caller MUST re-check `row.state == "InFlight"` AFTER the yield resolves before treating the call as committed.
- Required: If `RequestSquadOxygenSpend` is ever made genuinely async via a Promise, the caller must `:await()`/`:expect()` it inside the `pcall` — never bare-call-and-check `ok`.
- Required: `Humanoid.Died` handling must guard against re-entry (`_deathInProgress` flag) — a pathological double-fire must not reset the 30s respawn timer or mint a second `deathEventId`.
- Required: Any `KnitInit`-time config-validation hard error MUST be paired with a bootstrap `catch` handler calling `game:Shutdown()` — a `catch(warn)`-only boilerplate logs but does not halt startup (binding project-wide).
- Forbidden: Never fire-and-forget the oxygen-spend charge without Pending/InFlight/Committed/Abandoned tracking.
- Forbidden: Never let Resource Management (or anything but Player Controller) mint `deathEventId`.

---

## Acceptance Criteria

- [ ] **H.16 (referenced context)** — Death moment is acquired via `DisturbanceService:GetOnPlayerDiedSignal()`, never a direct `Humanoid.Died` subscription (ED's H.39e monopoly).
- [ ] **H.21** — GIVEN a player in S2+S3b with sprint pulse timer active, WHEN `Humanoid.Died` fires (relayed), THEN within 1 Heartbeat: locomotion=S1, lantern=S3a, both pulse timers stopped, stamina frozen.
- [ ] **H.22** — GIVEN `Humanoid.Died` fires for player A, WHEN the same event fires a second time within 1s (replication race), THEN the death handler is a no-op — no second oxygen deduction, no second timer reset.
- [ ] **H.22e** — GIVEN a 4-player squad, player A dies (life 1, Committed, oxygen 5→4), T6 fires at +30s (respawn; `currentDeathRecord[A]==nil` asserted immediately post-T6), WHEN A dies a second time, THEN a fresh `deathEventId` (distinct from life 1's) is minted off the cleared pointer, oxygen decrements 4→3, `OnPlayerDied` broadcast.
- [ ] **H.23** — GIVEN a 2-player squad with oxygen=5, WHEN player A dies, THEN oxygen decrements to 4 within the same Heartbeat as the death (NOT at respawn arrival).
- [ ] **H.35–H.46, H.54, H.56 (Reconciliation Tick block)** — including: F3a rollback→tick recovery handoff (H.35); F3b Path-B `deathEventId`-keyed recovery + destroyed-instance safety (H.36); F3c tick-scan skip of a retained `Committed` row (H.37a) and the N-2 replayed-`Died` short-circuit (H.37b); F3d nominal `2×RECONCILIATION_TICK_INTERVAL` latency bound + sustained-outage non-loss (H.38); F3e orphaned-row immediate removal vs retained-until-T6 (H.39); F3f first-tick bootstrap safety, no `now - nil` crash (H.40); F3g multi-life record independence — no per-player sticky flag survives across lives (H.41); F3h `BindToClose → Abandoned` explicit terminal transition (H.42, MANUAL-DEVICE); mid-retry no-double-dispatch across ticks (H.45); rejoin-during-reconciliation `deathEventId`-keying race closure (H.46); staleness-sweep late-success discard with the post-yield ownership re-check (H.54); `inFlightSince` declared-field lifecycle (H.56).
- [ ] **H.64 / H.64b** — Whole-span error guard: a thrown error while `state == "InFlight"` (before commit) rolls back to `Pending`, clears `inFlightSince`, logs via snapshots. A thrown error AFTER `Committed` does NOT roll back — caught, logged, record stays `Committed`, no second charge ever attempted.

---

## Implementation Notes

- **`deathEventId` minting**: `nextDeathEventId()` increments a server-session-scoped counter and returns it — session-lifetime-unique, never derived from any client value. PC is the sole minter.
- **The `DeathCostReconciliation` state record** (per ADR-0005's ratified state machine):

| State | Meaning | Entered from | Exits to |
|---|---|---|---|
| Pending | Charge owed, not dispatched. Only reconcile-eligible state. | record creation; rollback from InFlight; staleness-sweep re-arm | → InFlight; → Abandoned |
| InFlight | Dispatched, awaiting resolution. | Pending, on dispatch | → Committed (post-yield-recheck-gated); → Pending (rollback/re-arm) |
| Committed | Charge succeeded. Terminal-success. | success path, only if still `InFlight` at yield-resolve | (retained until T6/`PlayerRemoving`) |
| Abandoned | Closed without a charge. Terminal-accepted-loss. | `BindToClose` while Pending/InFlight | (terminal) |

- **The load-bearing rule**: `Pending → InFlight` happens **synchronously, before any yield** — this is what lets a racing second path (a replayed `Humanoid.Died`, or `PlayerRemoving`) resolve the record at step 1, read `InFlight`/`Committed`, and no-op. On the success path, **re-check `row.state == "InFlight"` AFTER the yield resolves** — if the staleness sweep re-armed the row to `Pending` mid-yield (and a subsequent tick already re-dispatched it), the original coroutine's late success is discarded (logged, not committed, not rolled back).
- If `RequestSquadOxygenSpend` ever becomes genuinely async via a Knit Promise, `:await()`/`:expect()` it **inside** the `pcall` — never bare-call-and-check `ok`, which reports success the instant the Promise is *constructed*, not once it *resolves*.
- Use PC's `getServerTime` clock seam (established Story 001) for `inFlightSince` and every reconciliation timestamp — the ADR's own first draft called `workspace:GetServerTimeNow()` inline and this was a caught-and-fixed re-verification bug.
- **`KnitInit` config-validation hard error**: any `error()` thrown at `KnitInit` (e.g., a misconfigured knob) only halts startup if the server bootstrap's `Knit.Start():andThen(...):catch(...)` actually calls `game:Shutdown()` — a `catch(warn)`-only boilerplate silently defeats the hard-error. This is binding project-wide, not just for this story's own knobs.
- `Humanoid.Died` idempotent guard: a simple `_deathInProgress[player]` flag, set on first entry, cleared at T6.

---

## Out of Scope

- Story 005: The specific T5/T6 side-effect payload (sprint hard-reset, `ReleasePredatorLock`, `OnPlayerS4Entered`/`OnPlayerT6Respawned`, `OnSquadMemberAliveChanged`) — this story implements the reconciliation state machine's dispatch mechanics; Story 005 implements what fires when a dispatch resolves.
- Story 006: Path B (`PlayerRemoving`-while-imminent) disconnect predicate and the oxygen grace timer.
- Ecological Disturbance epic: the `Humanoid.Died` sole-subscriber connection and `GetOnPlayerDiedSignal()` construction itself.
- Resource Management epic: `RequestSquadOxygenSpend`'s receiving-side dedup implementation.

---

## QA Test Cases

- **AC-1 (H.22 — idempotent double-fire)**:
  - Given: `Humanoid.Died` fires for A.
  - When: the same event fires again within 1s.
  - Then: no-op — no second deduction, no second timer reset.
  - Edge cases: exact-same-Heartbeat double-fire vs. adjacent-Heartbeat double-fire.
- **AC-2 (H.22e — multi-life independence)**:
  - Given: A dies (life 1, Committed), respawns (T6 clears pointer).
  - When: A dies again (life 2).
  - Then: fresh distinct `deathEventId`, oxygen decrements again, independent of life 1's record state.
  - Edge cases: assert `currentDeathRecord[A]==nil` immediately post-T6, not just as a setup assumption.
- **AC-3 (H.54 — staleness-sweep late-success discard)**:
  - Given: an `InFlight` record held mid-yield past `2×RECONCILIATION_TICK_INTERVAL`.
  - When: the sweep re-arms it to `Pending` and a second coroutine commits it, THEN the first coroutine's held call resolves successfully.
  - Then: the late coroutine does NOT commit, does NOT roll back, does NOT double-broadcast — logs and exits. Exactly one squad-oxygen unit charged.
  - Edge cases: both attempts must carry the SAME `deathEventId` (idempotency key for RM's own dedup).
- **AC-4 (H.64/H.64b — error guard scoping)**:
  - Given: a record `InFlight`.
  - When: an error is thrown before commit.
  - Then: rolls back to `Pending`, `inFlightSince` cleared.
  - Given: a record already `Committed`.
  - When: an error is thrown in the post-commit side-effect block.
  - Then: caught and logged, stays `Committed`, never re-debited.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player-controller/death-cost-reconciliation-core_test.luau`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Ecological Disturbance epic's `Humanoid.Died` fan-out story (`GetOnPlayerDiedSignal()`/`OnPlayerDied` BindableEvent construction) — cross-epic; Resource Management epic's `RequestSquadOxygenSpend` receiving-service implementation — cross-epic
- Unlocks: Story 005, Story 006, Story 007, Story 009
