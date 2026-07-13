# Story 011: RegistrationHandshake Module & Predator-Lock Registry

> **Epic**: Ecological Disturbance
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-039` (`OnPredatorStateChanged` BindableEvent, PA-owned, subscribed for defense-in-depth lock purge), `TR-ed-040` (`RegisterPredatorLock`/`ReleasePredatorLock`, merge-on-reregister, 5s grace, clear-fire ownership), `TR-ed-041` (module-private `RegistrationHandshake.luau`, exactly 5 exports, `require()`-acquired), `TR-ed-042` (register-time-subscribe pattern, KnitStart getters-before-handler-setter order)
**ADR Governing Implementation**: ADR-0001 (KnitInit/KnitStart Ordering Discipline), ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: This is the concrete worked example of ADR-0001's Rule 2 (RegistrationHandshake for live cross-service subscriptions). The handshake module is a plain ModuleScript at `src/server/services/DisturbanceService/RegistrationHandshake.luau`, acquired via `require()` by both DisturbanceService and Predator AI — order-independent because `require()` caching happens independently of Knit's `KnitStart` lifecycle. Exactly 5 canonical exports, no more, no fewer.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: HIGH
**Engine Notes**: `require()` module-cache singleton identity reliability is UNVERIFIED against the pinned Studio/Knit build (ADR-0001's flagged HIGH risk) — the Story 001 Studio spike must have already confirmed this before this story's tests can be trusted as meaningful. RegistrationHandshake modules must only be `require()`d from the default serial Luau script context, never from an `Actor` used for parallel execution.

**Control Manifest Rules (Foundation layer)**:
- Required: RegistrationHandshake pattern — where a live cross-service subscription requires one side to register itself (not just listen) and neither side can assume boot order, use the module-private `require()`-acquired RegistrationHandshake pattern — source: ADR-0001
- Required: RegistrationHandshake modules must only be `require()`d from the default serial Luau script context — never from inside an `Actor` — source: ADR-0001
- Forbidden: Never construct a cross-service-visible object inside `KnitStart` — source: ADR-0001

---

## Acceptance Criteria

- [ ] **Handshake module** at `src/server/services/DisturbanceService/RegistrationHandshake.luau` exports EXACTLY 5 names: `RegisterPredatorLockChangedSignal`, `RegisterPredatorStateChangedSignal`, `setOnPredatorStateChangedHandler`, `getOnPredatorLockChangedSignal`, `getOnPredatorStateChangedBindable`. No more, no fewer.
- [ ] **Register-time-subscribe pattern**: `RegisterPredatorStateChangedSignal(bindable)` writes the handle into a module-local slot AND immediately performs the `:Connect` registration to that bindable using the DisturbanceService-side handler if available; if DisturbanceService's `KnitStart` has not yet completed, the `:Connect` is queued in a pending-registrations list, drained when `setOnPredatorStateChangedHandler` is eventually called.
- [ ] **DisturbanceService's KnitStart handshake-import ordering (binding, not swappable)**: getters (`getOnPredatorLockChangedSignal`, `getOnPredatorStateChangedBindable`) MUST both be called BEFORE `setOnPredatorStateChangedHandler` — the two getters are order-independent relative to each other, but both must precede the handler-setter, which triggers a queue drain.
- [ ] **`RegisterPredatorLock(predatorId, newList)`** is merge-on-re-register, not replace: unions the new list with the predator's prior list, pruned by archive-resolution (any `emissionId` no longer resolving in the archive is silently dropped at union time). Prior IDs not in `newList` enter a `PREDATOR_LOCK_RELEASE_GRACE_WINDOW` (default 5.0s) before removal.
- [ ] **`ReleasePredatorLock(predatorId)`** is server-internal (never on `.Client`), removes ALL entries the predator had locked, including grace-window entries. Predator AI MUST call this on every state transition out of Hunt/Investigate/Disengage and on predator respawn/despawn.
- [ ] **Defense-in-depth**: DisturbanceService also listens on the server-internal `OnPredatorStateChanged` BindableEvent (PA-owned, payload `{predatorId, fromState, toState, timestamp}`) and purges registrations on observed state-exit even if Predator AI omitted the explicit `:ReleasePredatorLock` call.
- [ ] **`:ReleasePredatorLock`'s yield-free sub-steps (4a)-(4c)**: (4a) compute `pre_purge_targets` (the set of `targetedPlayer` UserIds this predator currently holds — the registry is the single source of truth; no `GetLockedTargetedPlayers` accessor exists); (4b) for each target, invoke `OnPredatorLockChanged:Fire(targetedPlayer, {locked=false, predatorId=predatorId})` — no synchronous-side-effect observer may attach to this fire path (sync-callback prohibition); (4c) atomically purge all entries for `predatorId`. All three sub-steps yield-free, no exceptions.
- [ ] **Same-frame Fire(false)-before-Fire(true) ordering (E.23)**: on the predator's own state-machine code path, the clear MUST sequence before the acquire within the same Luau frame.
- [ ] **H.30c sub-AC (a)-(d)**: (a) TTL-purged entries no longer resolve; (b) unresolvable IDs at registration are silently dropped at union time (not retained); (c) transition clears ALL registrations regardless of explicit `:ReleasePredatorLock` call (defense-in-depth); (d) live-source list retains nothing beyond natural expiry (unaffected by lock registry state).
- [ ] **H.30c sub-AC (e)** (this story's portion): `MockOrderingRecorder` verifies `t_iii < t_iv < t_v < t_vi < t_vii` — Predator AI's `OnPlayerDied:Connect` callback entry, `:ReleasePredatorLock` invocation entry, sub-steps (4a)/(4b)/(4c) completion, in strict nested order, all within Story 010's `:Fire`'s lexical scope.
- [ ] **H.30c sub-AC (g)**: during-release atomicity — a dying player's `Humanoid.Died` chain executes entirely BEFORE sub-step (4a) or entirely AFTER (4c) of an in-flight `:ReleasePredatorLock` — never mid-purge.
- [ ] **H.30c sub-AC (i)** (secondary, this story's portion): AUTO-INTEGRATION concurrent-reader regression backstop — a 100-trial interleaving log shows zero partial-purge observations. (The primary MANUAL-REVIEW yield-free attestation for this AC is a cross-cutting evidence-file requirement shared with Story 010 — see Story 016 for the CI-gate mechanics.)
- [ ] **H.30c sub-AC (j)**: same-frame Fire(true)+Fire(false) ordering contract — strict ordering `t_(j-i) < ... < t_(j-v)`; `OnPredatorLockChanged:Fire(playerA,false)` queued before `Fire(playerB,true)`. A negative sub-test verifies the AC catches a contract-violating (reversed-ordering) implementation.

---

## Implementation Notes

Handshake module shape (cite the canonical shape from ADR-0001's Key Interfaces + the forward-obligations doc's fully-worked handshake spec):
```luau
-- src/server/services/DisturbanceService/RegistrationHandshake.luau
local _onPredatorLockChangedSignal: RemoteSignal? = nil
local _onPredatorStateChangedBindable: BindableEvent? = nil
local _onPredatorStateChangedHandler: ((payload: any) -> ())? = nil
local _pendingConnects: {() -> ()} = {}

local function RegisterPredatorLockChangedSignal(signal): ()
    _onPredatorLockChangedSignal = signal
    -- replay any pending :Fire-deferred operations queued before registration (defensive)
end

local function RegisterPredatorStateChangedSignal(bindable): ()
    _onPredatorStateChangedBindable = bindable
    if _onPredatorStateChangedHandler then
        bindable.Event:Connect(_onPredatorStateChangedHandler)
    else
        table.insert(_pendingConnects, function() bindable.Event:Connect(_onPredatorStateChangedHandler) end)
    end
end

local function setOnPredatorStateChangedHandler(handler): ()
    _onPredatorStateChangedHandler = handler
    for _, connectFn in ipairs(_pendingConnects) do connectFn() end
    _pendingConnects = {}
end

local function getOnPredatorLockChangedSignal() return _onPredatorLockChangedSignal end
local function getOnPredatorStateChangedBindable() return _onPredatorStateChangedBindable end

return {
    RegisterPredatorLockChangedSignal = RegisterPredatorLockChangedSignal,
    RegisterPredatorStateChangedSignal = RegisterPredatorStateChangedSignal,
    setOnPredatorStateChangedHandler = setOnPredatorStateChangedHandler,
    getOnPredatorLockChangedSignal = getOnPredatorLockChangedSignal,
    getOnPredatorStateChangedBindable = getOnPredatorStateChangedBindable,
}
```
DisturbanceService's `KnitStart` handshake import (binding order — getters first, handler-setter LAST):
```luau
function DisturbanceService:KnitStart()
    local handshake = require(script.Parent.RegistrationHandshake)
    self._onPredatorLockChangedSignal = handshake.getOnPredatorLockChangedSignal()   -- (4-step-a)
    self._onPredatorStateChangedBindable = handshake.getOnPredatorStateChangedBindable() -- (4-step-b)
    handshake.setOnPredatorStateChangedHandler(self._handlePredatorStateChanged)     -- (4-step-c) MUST be last
end
```
Why this ordering is binding: `setOnPredatorStateChangedHandler` triggers a queue drain of any pending `:Connect` registrations queued during Predator AI's prior `RegisterPredatorStateChangedSignal` call (if DisturbanceService's `KnitStart` hadn't run yet). If (4-step-c) ran before (4-step-a)/(4-step-b), the drained callback closures would reference an uninitialized `self._onPredatorStateChangedBindable` slot — a deterministic nil-dereference.

`:ReleasePredatorLock` body (sub-steps 4a-4c, cite verbatim shape):
```luau
function DisturbanceService:ReleasePredatorLock(predatorId: string): ()
    local pre_purge_targets = self:_getTargetsFor(predatorId) -- (4a)
    for _, targetedPlayer in ipairs(pre_purge_targets) do
        self._onPredatorLockChangedSignal:Fire(targetedPlayer, {locked = false, predatorId = predatorId}) -- (4b)
    end
    self:_purgeRegistryFor(predatorId) -- (4c)
end
```
No `GetLockedTargetedPlayers(predatorId)` public accessor is declared — the registry stays encapsulated (TR-ed-013, cited here as a hard constraint even though it's not this story's own TR-ID — the accessor must never be added).

---

## Out of Scope

- Story 010: `Humanoid.Died` monopoly and `OnPlayerDied` fan-out (this story's registry is READ by Story 010's (5a) snapshot step, but this story owns the registry's own write paths).
- Predator AI's own state machine, `OnPredatorStateChanged` firing, and `OnPredatorLockChanged`'s `locked=true` acquire fire (all out of this epic — Predator AI owns firing both; this story only owns the `locked=false` clear-fire ownership and the defense-in-depth purge listener).
- Story 004: the attribution archive's own TTL/cap logic (this story only *reads* archive resolution status when pruning the union at re-registration).

---

## QA Test Cases

- **AC — exactly 5 exports**: Given: the handshake module's `return` table — When: inspected — Then: exactly the 5 canonical names are present, no more, no fewer (a 6th export, even a harmless one, FAILS this AC).
- **AC — register-time-subscribe, KnitStart-order-independent**: Given: two boot orderings — (1) Predator AI's `KnitStart` runs first, registering the bindable before DisturbanceService's handler exists; (2) DisturbanceService's `KnitStart` runs first, setting the handler before Predator AI registers — When: either ordering is exercised — Then: in BOTH cases, a subsequent `OnPredatorStateChanged` fire correctly reaches DisturbanceService's handler (case 1 via the queued-then-drained `:Connect`; case 2 via immediate `:Connect` at registration time).
- **AC — merge-on-re-register**: Given: a predator registers `{emA, emB}`, then later re-registers `{emB, emC}` — When: inspected — Then: the registry holds the UNION `{emA, emB, emC}` immediately after re-registration (not a replace to just `{emB, emC}`); `emA` (no longer in the new list) enters the grace window rather than being removed immediately.
- **AC — grace-window expiry**: Given: `emA` entered the grace window at re-registration — When: `PREDATOR_LOCK_RELEASE_GRACE_WINDOW` (5.0s) elapses without `emA` being re-included — Then: `emA` is removed from the registration set. Edge case: a re-registration that re-includes `emA` again BEFORE the grace window expires cancels the pending removal.
- **AC — archive-resolution pruning at union time**: Given: a predator re-registers with a list containing an `emissionId` that no longer resolves in the attribution archive (already purged) — When: the union+prune step runs — Then: the unresolvable ID is silently dropped from the union — NOT retained as a "the ID doesn't resolve so extend its TTL forever" case.
- **AC — sync-callback prohibition on (4b)**: Given: an attempted synchronous-side-effect observer attached to `OnPredatorLockChanged`'s server-side fire path during the (4b) iteration — When: statically analyzed (Story 016's lint) — Then: flagged as forbidden. This story's own code must not introduce any such observer.
- **AC-H.30c(a)-(d)**: Given: a predator registered `{emA, emB, emC}` where `emC` has been TTL-purged from the archive — When: the predator transitions out of Hunt/Investigate/Disengage AND the clock advances past `emA`/`emB`'s TTL — Then: (a) `emA`/`emB` purged on the following maintenance pass; (b) `emC` was silently dropped at first registration (never entered the live registry); (c) the transition clears ALL registrations regardless of an explicit `:ReleasePredatorLock` call being made; (d) the live-source list is unaffected (retains nothing beyond its own natural expiry rules from Story 003/005).
- **AC-H.30c(e)** (joint with Story 010): Given: `MockOrderingRecorder` instrumented across the full death→release chain — When: a death triggers a predator-lock release from within an `OnPlayerDied:Connect` callback — Then: the nesting order `t_iii (PA's OnPlayerDied callback entry) < t_iv (:ReleasePredatorLock entry) < t_v (4a) < t_vi (4b) < t_vii (4c)` holds strictly, and this entire chain is nested inside Story 010's `t_i.75` (`_OnPlayerDied:Fire` invocation) lexical scope.
- **AC-H.30c(g)**: Given: an in-flight `:ReleasePredatorLock` call for predator X (mid-way through sub-steps 4a-4c) — When: a player death's `Humanoid.Died` chain fires concurrently (simulated via the harness) — Then: the death's processing is observed to complete entirely BEFORE (4a) begins, or entirely AFTER (4c) completes — never interleaved mid-purge. Edge case: this is only reachable to test meaningfully BECAUSE (4a)-(4c) are yield-free — the harness should also assert no yield primitives are present in the observed window, corroborating the atomicity claim structurally, not just via timing observation.
- **AC-H.30c(i)** (secondary/backstop): Given: a 100-trial concurrent-reader harness — When: run — Then: zero trials observe a partial-purge state (a reader seeing some-but-not-all of a predator's registrations cleared mid-transition).
- **AC-H.30c(j)**: Given: a predator's state machine simultaneously clears a lock on player A and acquires a lock on player B within the same Luau frame — When: the ordering is captured — Then: `Fire(playerA, false)` is strictly ordered before `Fire(playerB, true)`. Negative sub-test: Given: a deliberately-broken implementation that reverses this ordering — When: the same assertion runs — Then: the test FAILS (proving the AC is not vacuously true).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ecological-disturbance/registration-handshake-predator-lock-registry_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 001, 010
- Unlocks: 012
