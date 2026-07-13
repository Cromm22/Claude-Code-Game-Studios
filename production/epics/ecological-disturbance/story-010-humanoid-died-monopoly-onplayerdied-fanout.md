# Story 010: Humanoid.Died Monopoly & OnPlayerDied Fan-out

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-030` (server-internal `OnPlayerDied` BindableEvent, synchronous-dispatch, KnitInit-constructed), `TR-ed-032` (`Humanoid.Died` sole subscriber, registered in KnitInit, CI-enforced), `TR-ed-033` (`Character.PrimaryPart` nil-guard on ring-buffer writes — cross-referenced, owned by Story 015), `TR-ed-044` (`GetOnPlayerDiedSignal(): BindableEvent`), `TR-ed-052` (yield-free single-Luau-frame death path), `TR-ed-056` (same-frame `Fire(false)`-before-`Fire(true)` ordering — cross-referenced, owned by Story 011), `TR-ed-061` (server sole authority)
**ADR Governing Implementation**: ADR-0001 (KnitInit/KnitStart Ordering Discipline), ADR-0004 (DisturbanceService Core Architecture), ADR-0005 (Death & Respawn Lifecycle)
**ADR Decision Summary**: DisturbanceService is the ONLY code path anywhere in the server codebase with a `Humanoid.Died:Connect` chain — registered in `KnitInit` (not `KnitStart`, fixed 2026-07-06 re-verification pass). `OnPlayerDied` stays a raw `Instance.new("BindableEvent")` per the GDD's own frozen C.1.11 closure (round-11 BLOCK-3/red-team I-3) — NOT switched to Knit `Signal` — with `Workspace.SignalBehavior = Enum.SignalBehavior.Immediate` pinned at boot (Story 001) as ADR-0001's own stated fallback for a channel that stays `BindableEvent`. Fans out to exactly 3 consumers: Player Controller, Crafting & Items, Predator AI.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: HIGH
**Engine Notes**: `BindableEvent:Fire` synchronous-dispatch is governed by `Workspace.SignalBehavior` (pinned to `Immediate` in Story 001) — this story's yield-free death path depends on that pin holding. `Humanoid.Died` firing twice in a pathological replication race is a real, documented Roblox behavior this story's consumers (not this story itself) must guard against via their own idempotent handlers (PC's `_deathInProgress` flag, ADR-0005) — this story's own obligation is strictly the fan-out mechanism, not de-duplication (ED fires once per actual `Humanoid.Died` event; if that event itself double-fires, ED faithfully double-fans-out, and consumers are individually responsible for idempotency).

**Control Manifest Rules (Foundation layer)**:
- Required: `DisturbanceService` MUST be the only code path in the server codebase with a `Humanoid.Died:Connect` chain — source: GDD C.1.11, ADR-0004
- Required: `OnPlayerDied` BindableEvent constructed during `KnitInit`, `Humanoid.Died` chain registered during `KnitInit` (fixed 2026-07-06 — was previously drafted under `KnitStart` in ADR-0004's diagram, corrected) — source: ADR-0001 Rule 1, ADR-0004
- Required: `Workspace.SignalBehavior = Enum.SignalBehavior.Immediate` pinned at boot (Story 001) so `OnPlayerDied`'s dispatch is synchronous — source: ADR-0004
- Required: The death-snapshot construction (5a)-(5c) executes synchronously, yield-free, within a single Luau frame — source: GDD C.1.11/C.1.12, ADR-0004
- Forbidden: No other service anywhere may subscribe to `Humanoid.Died` directly — all consumers subscribe to `GetOnPlayerDiedSignal()` instead — source: GDD C.1.11 (H.39e CI-enforced, see Story 016)

---

## Acceptance Criteria

- [ ] `DisturbanceService:GetOnPlayerDiedSignal(): BindableEvent` returns the single, `KnitInit`-constructed `OnPlayerDied` BindableEvent — the SAME instance on every call (identity-equal).
- [ ] `Humanoid.Died` is subscribed to EXACTLY ONCE anywhere in the entire server codebase, via a chain registered during `DisturbanceService:KnitInit()`: `Players.PlayerAdded → CharacterAdded → Humanoid.Died:Connect(...)`.
- [ ] **Yield-free single-Luau-frame death path (5a)-(5c), REQUIRED**: on `Humanoid.Died` firing, the handler synchronously (no yield primitives — no `task.wait`, no yielding RemoteEvent/DataStore calls) within the same frame: (5a) captures a `_deathLockSnapshot` of the predator-lock registry state for this player (read-only snapshot, written by this story, read-and-cleared later by Story 012 — see that story's dedicated read-and-clear idiom); (5b) constructs the `OnPlayerDied` payload `{deadPlayer = deadPlayer, deathTimestamp = workspace:GetServerTimeNow(), predatorWasLockedAtDeath = self._deathLockSnapshot[deadPlayer]}` — payload constructed AFTER the snapshot capture so the flag value is consistent with the registry read at (5a); (5c) fires `OnPlayerDied:Fire(payload)`.
- [ ] **Exactly 3 consumers fan-out (corrected count per this session's TD sign-off)**: Player Controller, Crafting & Items, Predator AI. `GetOnPlayerDiedSignal()` supports an arbitrary number of `:Connect()` subscribers — the "exactly 3" is a documented, CI-verifiable consumer-count expectation (Story 016), not a hardcoded limit in the signal mechanism itself.
- [ ] `Humanoid.Died` firing twice in a pathological replication race results in `OnPlayerDied` fan-out firing twice as well — ED does not de-duplicate; each individual consumer (PC's `_deathInProgress` guard, etc.) is responsible for its own idempotency. ED's own obligation is limited to: the SAME snapshot-capture-then-fire sequence runs correctly and yield-free on EACH fire, not just the first.
- [ ] `GetOnPlayerDiedSignal()` is server-internal only — never exposed via `.Client`, never wrapped in a RemoteEvent/RemoteFunction.

---

## Implementation Notes

`KnitInit` chain registration (ADR-0004 Architecture Diagram, corrected 2026-07-06 — moved from `KnitStart` to `KnitInit`):
```luau
function DisturbanceService:KnitInit()
    -- ... Story 001's empty-container construction ...
    self._onPlayerDied = Instance.new("BindableEvent") -- raw BindableEvent per GDD C.1.11 frozen closure
    -- Workspace.SignalBehavior = Enum.SignalBehavior.Immediate already pinned in Story 001, before this runs.

    -- Humanoid.Died sole-subscriber chain — registered HERE, not KnitStart (fixed 2026-07-06).
    Players.PlayerAdded:Connect(function(player: Player)
        player.CharacterAdded:Connect(function(character: Model)
            local humanoid = character:WaitForChild("Humanoid") :: Humanoid
            humanoid.Died:Connect(function()
                self:_onHumanoidDied(player)
            end)
        end)
    end)
end

function DisturbanceService:_onHumanoidDied(deadPlayer: Player): ()
    -- (5a) snapshot the predator-lock registry state for this player, synchronously.
    local wasLocked = self:_captureDeathLockSnapshot(deadPlayer) -- see Story 011/012 for the registry itself
    self._deathLockSnapshot[deadPlayer] = wasLocked

    -- (5b) construct payload AFTER the snapshot capture.
    local payload = {
        deadPlayer = deadPlayer,
        deathTimestamp = workspace:GetServerTimeNow(),
        predatorWasLockedAtDeath = wasLocked,
    }

    -- (5c) fire, synchronous dispatch guaranteed by the Workspace.SignalBehavior pin (Story 001).
    self._onPlayerDied:Fire(payload)
end

function DisturbanceService:GetOnPlayerDiedSignal(): BindableEvent
    return self._onPlayerDied
end
```
`_deathLockSnapshot` is a single-writer mailbox this story writes into — Story 012's `GetDeathAttributionPayload` is the reader, using a read-and-clear idiom (read then set to `nil`, zero yield between the two operations) so a duplicate resolution request degrades gracefully rather than re-resolving stale data. This story only WRITES the snapshot at (5a); it does not read it back.

The 3-consumer fan-out count (PC, Crafting, Predator AI) is a cross-epic expectation, not something this story enforces at runtime — document it in this story's own code comments and rely on Story 016's CI lint (H.39c/H.39d) to verify the actual subscriber count matches once all 3 consuming epics exist.

---

## Out of Scope

- Story 011: the predator-lock registry itself (`RegisterPredatorLock`/`ReleasePredatorLock`) and the `_deathLockSnapshot`'s actual capture mechanics beyond the write-once-per-death call site shown above.
- Story 012: `GetDeathAttributionPayload`'s read-and-clear consumption of `_deathLockSnapshot`.
- Player Controller / Crafting & Items / Predator AI epics: their own `GetOnPlayerDiedSignal():Connect(...)` subscriber implementations and idempotency guards (out of this epic entirely).
- Story 016: the CI lint mechanics (H.39e) that mechanically enforce the `Humanoid.Died` sole-subscriber monopoly and the yield-free call-graph traversal.

---

## QA Test Cases

- **AC — same-instance accessor**: Given: a `KnitInit`-constructed `DisturbanceService` — When: `GetOnPlayerDiedSignal()` is called twice — Then: both calls return the identical `BindableEvent` instance.
- **AC — sole subscriber**: Given: the full server codebase (as it exists after this story, plus stubs for consumers) — When: grepped for `Humanoid.Died:Connect` — Then: exactly one match, located inside `DisturbanceService`'s `CharacterAdded` handler, itself registered during `KnitInit`.
- **AC — yield-free snapshot-then-fire sequence**: Given: `Humanoid.Died` fires for a player — When: the handler executes — Then: steps (5a)/(5b)/(5c) run with zero yield primitives between them (verify via a static/structural check that no `task.wait`, no yielding call appears in `_onHumanoidDied`'s body, plus a runtime assertion that the whole sequence completes within the same resumption of the calling coroutine).
- **AC — payload consistency**: Given: a player with a live predator lock at the moment of death — When: `Humanoid.Died` fires — Then: `OnPlayerDied`'s payload `predatorWasLockedAtDeath` matches the registry state AT THE MOMENT OF THE SNAPSHOT (5a), not a later, possibly-already-released state.
- **AC — double-fire fan-out (no dedup at ED's layer)**: Given: `Humanoid.Died` fires twice for the same player within the same test (simulating a replication race) — When: both fires are processed — Then: `OnPlayerDied` fires twice, each with its own independently-correct snapshot-then-payload sequence — ED performs no de-duplication of its own; this is by design (consumers own their own idempotency).
- **AC — server-internal only**: Given: `GetOnPlayerDiedSignal` and `_onPlayerDied` — When: inspected for `.Client` surface or RemoteEvent/RemoteFunction wrapping — Then: none found.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ecological-disturbance/humanoid-died-monopoly-onplayerdied-fanout_test.luau` — must exist and pass
**Status**: [x] Created and passing (part of the 19/19-file suite, `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` → exit 0, re-verified 2026-07-09 after code-review fixes)

---

## Dependencies

- Depends on: 001, 004
- Unlocks: 011, 012

---

## Completion Notes
**Completed**: 2026-07-09
**Criteria**: 6/6 passing — all COVERED per the QA testability review's full AC-traceability table (behavioral coverage via the disclosed FakeDisturbanceService harness + static/structural checks against the real source, per this epic's established Lune-harness strategy)
**Deviations**: One real defect found and fixed same-session by code review: `_deathLockSnapshot` had no `PlayerRemoving` cleanup (same leak class as `_loadedChunks`/`_floraDeltaCache`, fixed with the matching one-line clear + a static regression test). Advisory items logged: **TD-011** (`PlayerAdded`/`CharacterAdded` already-existing-instance races — design call needed), **TD-012** (textual monopoly grep is early-warning only; Story 016's H.39e lint must be robust to the documented evasion classes), **TD-010 extended** (`deathTimestamp` inherits the no-`_setTestClock`-seam caveat, same `_setNow` harness workaround). ADR-0004's N10 per-pass registry snapshot correctly deferred to Story 011 (stub per this story's own Out of Scope). Review hardenings applied: per-fire coroutine yield-free proof on the double-fire test, body-bounded ordering check, re-scoped `stripLuaComments` caveat.
**Test Evidence**: `tests/integration/ecological-disturbance/humanoid-died-monopoly-onplayerdied-fanout_test.luau` — passing
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (engine specialist: MINOR NOTES, ADR-0001/0004/0005 all COMPLIANT; QA: TESTABLE, zero blocking gaps)
