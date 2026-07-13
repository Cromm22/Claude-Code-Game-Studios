# Story 006: Path B Disconnect Predicate, Oxygen Grace Timer & Oxygen-Gated Respawn Wait

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-022` (Path B `PlayerRemoving` imminent-death predicate; cross-service teardown-order race), `TR-pc-023` (`OXYGEN_GRACE_DURATION=5s`, PC-owned squad-wide; pool re-check at expiry; hard config error <2s), `TR-pc-024` (`OnPlayerOxygenExpired()` argument-less squad-wide RM→PC trigger), `TR-pc-031` (oxygen-gated respawn wait: T6 withheld if pool<1, re-checked each Heartbeat), `TR-pc-040` (`PredatorService`-owned `lastPredatorDamageTimestamp` + `predatorCausedImminent` latch — read-only inputs to this story's predicate), `TR-pc-046` (`KnitInit` config-validation hard-error requiring `game:Shutdown()` bootstrap catch)

**ADR Governing Implementation**: ADR-0005: Death & Respawn Lifecycle
**ADR Decision Summary**: Restates the C4 cross-review ruling as binding architecture: `OXYGEN_GRACE_DURATION = 5s` (safe range 4–8s), PC-owned, squad-wide, with a config-validation hard error below the 2.0s floor (R7c-I4). Also restates the D1 kill-criterion (`aliveCount ≤ 2` last-stand floor, evaluated against playtest data) as binding, with an explicit instrumentation requirement.

**Engine**: Roblox Studio (live platform) + Knit framework | **Risk**: LOW
**Engine Notes**: No new engine API. Cross-service dependency on Resource Management's oxygen pool read and Predator AI's damage-timestamp/latch tables — both read-only from PC's side.

**Control Manifest Rules (Core layer)**:
- Required: `OXYGEN_GRACE_DURATION = 5s (safe range 4–8s), owned by Player Controller, squad-wide`; config-validation must hard-error for any configured value below the 2.0s floor.
- Required: `D1 kill-criterion: aliveCount ≤ 2` is the pre-committed last-stand floor after Beacon-Collapse-4; the analytics pipeline must segment 2-player-squad win/loss outcomes from 3/4-player squads.
- Required: Any `KnitInit`-time config-validation hard error MUST be paired with a bootstrap `catch` handler that calls `game:Shutdown()`.
- Forbidden: Never let `Resource Management` (or anything but Player Controller) mint `deathEventId` — restated here since this story's Path B dispatch mints via the same Story 004 mechanism.

---

## Acceptance Criteria

- [ ] **H.22b** — GIVEN an alive player A with `Health=20` (below `HP_IMMINENT_THRESHOLD=25`), clock injected to `T`, `lastPredatorDamageTimestamp[A]=T-5` (within `HP_ARM_RECENT_WINDOW=30s`, outside `DAMAGE_RECENT_WINDOW=3s` — only arm 1 carries), squad oxygen=5, WHEN A disconnects without `Humanoid.Died` having fired, THEN within the same Heartbeat: a `DeathCostReconciliation` record reaches `Committed`, oxygen decrements to 4, `OnPlayerDied(deathCause="disconnect-while-damaged")` broadcast.
- [ ] **H.22c** — GIVEN an alive player A at full health, no recent predator damage (`lastPredatorDamageTimestamp[A]=nil`), WHEN A disconnects, THEN the predicate evaluates false, T5 NOT invoked, oxygen unchanged, no broadcast.
- [ ] **H.22d** — GIVEN full-health A with `lastPredatorDamageTimestamp[A]=T-1.5` (within `DAMAGE_RECENT_WINDOW=3.0s` — only arm 2 carries), WHEN A disconnects, THEN T5 fires, oxygen decrements, broadcast fires (verifies arm 2 in isolation).
- [ ] **H.22f** — GIVEN A satisfies the Path B predicate (record minted `Pending`), AND a fault is injected into the server-internal `RequestSquadOxygenSpend` call such that `pcall` returns `(false, err)`, WHEN dispatched, THEN: transitions `Pending→InFlight` before the call, `pcall` captures failure without crashing, rollback `InFlight→Pending`, failure logged via `row.playerName`/`row.userId` (never the live instance), oxygen ledger unchanged.
- [ ] **H.43** — GIVEN the imminent-death predicate, WHEN evaluated at exact boundary values (`Health=25.0`, elapsed=`30.0s` arm 1, elapsed=`3.0s` arm 2, `predatorCausedImminent=false` arm 3), THEN all strict-`<` comparators return false (predicate does NOT fire). Paired off-boundary cases (`24.99`/`29.99s`/`2.99s`) exercise the live branches.
- [ ] **H.44** — GIVEN A at `Health=18`, `predatorCausedImminent[A]=true`, latch set 45s ago (within `LATCH_MAX_AGE=120s`), `lastPredatorDamageTimestamp[A]=T-45` (outside `HP_ARM_RECENT_WINDOW`, arms 1/2 cannot fire), WHEN A disconnects, THEN arm 3 fires: record `Committed`, oxygen decrements, broadcast fires. Paired negative #1: `predatorCausedImminent=false` → predicate false, nothing charged (stale-graze class stays closed). Paired negative #2 (outer ceiling): latch set 150s ago (outside `LATCH_MAX_AGE`) → arm 3 does NOT fire. Exact-boundary pair: elapsed exactly `120.0s` → does NOT fire (strict `<`); `119.99s` → fires.
- [ ] **H.65** — GIVEN a 2-player squad, A in S4 with respawn timer elapsed, B alive, squad oxygen pool=0, WHEN server Heartbeats continue, THEN A REMAINS in S4 (no transition, no timer restart, no additional oxygen charge), S4 input set (emote/spectate; `RequestPing` still CUT) stays accepted, condition re-evaluated each Heartbeat. WHEN pool restores to ≥1 (mock RM), THEN A respawns via a normal T6 on the FIRST Heartbeat the pool reads ≥1.
- [ ] **H.12a clause (config gate for `OXYGEN_GRACE_DURATION` floor)** — config validation hard-errors any `OXYGEN_GRACE_DURATION < 2.0s`.

---

## Implementation Notes

- **Imminent-death predicate** (evaluated server-side, no client involvement, at `PlayerRemoving` time):
  ```
  isImminentDeath(player) =
      (Health < HP_IMMINENT_THRESHOLD AND lastPredatorDamageTimestamp ~= nil
       AND (now - lastPredatorDamageTimestamp) < HP_ARM_RECENT_WINDOW)
    OR (lastPredatorDamageTimestamp ~= nil AND (now - lastPredatorDamageTimestamp) < DAMAGE_RECENT_WINDOW)
    OR (predatorCausedImminent == true AND Health < HP_IMMINENT_THRESHOLD
        AND predatorCausedImminentSetTimestamp ~= nil
        AND (now - predatorCausedImminentSetTimestamp) < LATCH_MAX_AGE)
  ```
  All comparators are **strict `<`** (boundary values do NOT satisfy any arm — biases toward under-charge at the exact edge, the opposite convention from ping-cooldown's `>=` accept-at-boundary).
- **Read-and-cache discipline is mandatory and load-bearing**: the `PlayerRemoving` handler MUST read `lastPredatorDamageTimestamp[player]`, `predatorCausedImminent[player]`, `predatorCausedImminentSetTimestamp[player]`, `Humanoid.Health`, and `getServerTime()` into local variables **as the first statement block**, before any yield-capable call (no `task.wait`, no `RemoteFunction:InvokeServer`, no `Knit:GetService(...)` round-trip). The cached locals — never live table reads — are what the predicate evaluates. This closes Race 1 (a cross-service `PlayerRemoving` ordering race where `PredatorService`'s own teardown could clear the entry mid-handler). Race 2 (PredatorService clears BEFORE PC's handler even starts) is an accepted, Pillar-2-safe under-charge — not this story's problem to close.
- `lastPredatorDamageTimestamp`/`predatorCausedImminent`/`predatorCausedImminentSetTimestamp` are **read-only from PC's side** — `PredatorService` (Predator AI epic) is the sole writer.
- **Oxygen grace timer (C.5.1)**: on RM's squad-wide, argument-less `OnPlayerOxygenExpired()` broadcast (edge-triggered on Empty entry), PC starts ONE squad-wide grace timer of `OXYGEN_GRACE_DURATION=5s`. At expiry, PC re-checks the squad pool via RM's server-internal pool read and fires T5 for every still-alive player ONLY if the pool is still 0 — a mid-grace Canister restore cancels the pending deaths and the timer; a fresh Empty entry restarts it.
- **Oxygen-gated respawn wait (T6)**: if the respawn timer elapsed but squad oxygen pool `< 1` and at least one squad member is alive, the T6 transition is WITHHELD (no state change, timer does not restart, no additional charge — the death already paid its unit at T5). Re-check the full condition (`timer elapsed AND pool ≥ 1`) each Heartbeat.
- Config validation MUST hard-error (paired with a bootstrap `catch(...) game:Shutdown()`) for any `OXYGEN_GRACE_DURATION < 2.0s` — this is the R7c-I4 closure, mirroring the same pattern Story 004 already establishes for its own hard-error.
- **D1 kill-criterion**: this story does not implement analytics segmentation itself (that is Resource Management's `TR-rm-027` and the analytics pipeline's obligation) — but the whole-squad-wipe path this story's grace timer feeds into (Story 009's T7) is what the D1 criterion is measured against. Note this in the story's implementation as a documented dependency, not a task to build here.

---

## Out of Scope

- Story 004: The reconciliation state machine's dispatch mechanics themselves (this story only supplies the Path B *trigger condition* that invokes the same dispatch).
- Predator AI epic: the `lastPredatorDamageTimestamp`/`predatorCausedImminent` write-side lifecycle (bootstrap init, damage-application writer, HP-recovery watcher) — PC only reads these tables.
- Resource Management epic: the oxygen pool itself, the `OnPlayerOxygenExpired()` producer, and the D1 kill-criterion's analytics segmentation.
- Story 009: the whole-squad-wipe T7 raise itself.

---

## QA Test Cases

- **AC-1 (H.22b/c/d — predicate arms in isolation)**:
  - Given: low HP + recent predator damage (arm 1 only).
  - When: disconnect.
  - Then: charged.
  - Given: full health, no damage timestamp.
  - When: disconnect.
  - Then: not charged.
  - Given: full health + very recent damage (arm 2 only).
  - When: disconnect.
  - Then: charged.
  - Edge cases: each arm must be exercisable in isolation without the others confounding the result.
- **AC-2 (H.43 — exact-boundary rejection)**:
  - Given: exact-boundary values for all three arms.
  - When: predicate evaluated.
  - Then: none fire (strict `<`).
  - Edge cases: off-boundary values (±0.01) must fire correctly.
- **AC-3 (H.44 — arm 3 latch + outer ceiling)**:
  - Given: predator-caused sub-threshold state, latch set within `LATCH_MAX_AGE`.
  - When: disconnect.
  - Then: charged.
  - Edge cases: latch unset (never crossed) → not charged; latch aged past `LATCH_MAX_AGE` → not charged; exact-boundary at `120.0s` → not charged, `119.99s` → charged.
- **AC-4 (H.65 — oxygen-gated respawn wait)**:
  - Given: respawn timer elapsed, pool=0, teammate alive.
  - When: Heartbeats continue.
  - Then: player stays in S4, condition re-checked every tick.
  - Edge cases: pool restores mid-wait → respawns on the very next Heartbeat where pool≥1, no extra delay.
- **AC-5 (config gate)**:
  - Given: config with `OXYGEN_GRACE_DURATION = 1.5`.
  - When: `KnitInit` runs.
  - Then: hard error thrown, paired bootstrap `catch` calls `game:Shutdown()`.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/player-controller/path-b-oxygen-grace-timer_test.luau`
**Status**: [x] Created and passing (part of the 22/22-file suite, `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` → exit 0, re-verified 2026-07-10 after code-review fixes)

---

## Dependencies

- Depends on: Story 004; Cross-epic: Resource Management epic's `OnPlayerOxygenExpired()`/`RequestSquadOxygenSpend` receiving-service (mocked — injectable seams, pool default `math.huge` so no false deaths); Predator AI epic's `lastPredatorDamageTimestamp`/`predatorCausedImminent` latch write-side (mocked — 3 read seams, userId-keyed per TD-016's established convention)
- Unlocks: Story 009

---

## Completion Notes
**Completed**: 2026-07-10
**Criteria**: 8/8 passing (H.22b/c/d/f, H.43, H.44, H.65, H.12a clause — plus the GDD G.6 coupled-knob invariant `LATCH_MAX_AGE > HP_ARM_RECENT_WINDOW + 30.0` bound to H.12a clause (iii), which QA review established as a binding requirement this story owns since it authors both constants; implemented with the GDD's own worked examples as tests rather than deferred)
**Deviations**: **TD-013 RESOLVED by this story** — PlayerRemoving teardown clears `deathInProgress`/`deathStartedAt`/pointer with correct pointer-vs-row semantics (uncommitted rows survive by deathEventId and late-commit orphan-remove; an already-Committed-at-teardown row is retired immediately — a case identified beyond TD-013's own corrected text), suppressing the departed-player T6 entirely. Review fixes applied same-session: the retirement test was found UNSOUND (passed even if the Path-B dispatch never fired) and hardened to capture-at-source; H.65's no-recharge clause got an explicit spend-count assertion; +the teammate-connected-but-dead gate test. Design decisions ratified by review: grace-expiry deaths dispatch via pathOrigin "A" (side-effect-correct — the resulting `deathCause="predator-kill"` naming inaccuracy for oxygen deaths is a disclosed pc-5-era constant-naming follow-up, see TD-014's payload work); H.22f's literal `row.playerName` satisfied via handler-cached locals (the ADR-frozen row shape was not widened); read-and-cache first-statement-block verified genuinely yield-free; the engine review's task.spawn ordering trace confirmed the pointer-vs-row design absorbs both the synchronous-stub-today and async-RM-later worlds.
**Test Evidence**: `tests/unit/player-controller/path-b-oxygen-grace-timer_test.luau` — passing (22/22 suite, exit 0)
**Code Review**: Complete — engine specialist CLEAN; QA GAPS (3 required fixes + 1 optional, ALL applied same-session); ADR-0005/0001 COMPLIANT
