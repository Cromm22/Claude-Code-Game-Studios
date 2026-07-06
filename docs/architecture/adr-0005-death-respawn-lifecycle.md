# ADR-0005: Death & Respawn Lifecycle

## Status
Proposed

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + Knit framework |
| **Domain** | Core (cross-cutting: Player Controller, Resource Management, Ecological Disturbance) |
| **Knowledge Risk** | LOW — this ADR is a cross-service contract and state-machine specification; it introduces no new engine API beyond `Humanoid.Died` (already governed by ED's `OnPlayerDied` monopoly, ADR-0004) and standard Knit service-to-service calls (already governed by ADR-0001). |
| **References Consulted** | `design/gdd/player-controller.md` (C.5.x death/respawn sequence, F.2 reconciliation state machine, G.6 `OXYGEN_GRACE_DURATION`), `design/gdd/resource-management.md` (CR.4 idempotency, F.2 dedup contract, H.10/H.12/H.14/H.53), `design/gdd/ecological-disturbance-forward-obligations.md` (R7c-I4), `docs/architecture/architecture.md` (Boundary 3 — `RequestSquadOxygenSpend` signature, TD sign-off 2026-07-06), ADR-0004 (DisturbanceService Core Architecture — `GetOnPlayerDiedSignal()` / `GetDeathAttributionPayload`) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond what ADR-0001/ADR-0004 already require. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0004 (DisturbanceService Core Architecture) — the sole `Humanoid.Died` subscription and `GetOnPlayerDiedSignal()` fan-out this ADR's PC/Crafting/PA consumers rely on; ADR-0002 (RunController Architecture) — a whole-squad wipe (this ADR's terminal failure state) is reported to RunController via `RunEndConditionRaised`, not broadcast directly. |
| **Enables** | Implementation of Player Controller's T5/T6 states, Resource Management's death-cost deduction path, and the D1 2-player last-stand kill-criterion instrumentation. |
| **Blocks** | Player Controller, Resource Management, and Crafting & Items cannot implement their death-consuming code paths until this ADR is Accepted — all three currently reference a "converges the C4 ruling and the seam-patch re-anchor work" ADR that doesn't yet exist as a formal document. |
| **Ordering Note** | Should be accepted after ADR-0004 (depends on its `OnPlayerDied` construction) and can proceed in parallel with ADR-0006 (RemoteEvent Trust Boundary) — they don't share state. |

## Context

### Problem Statement

Death and respawn is the one lifecycle that spans three systems' own state machines: Ecological Disturbance owns the sole `Humanoid.Died` subscription and fans out `OnPlayerDied` to three consumers (Player Controller, Crafting & Items, Predator AI — corrected count per this session's TD sign-off); Player Controller owns the T5 (Dead-Respawning) state, mints `deathEventId`, and runs an async reconciliation state machine against Resource Management's oxygen pool; Resource Management owns idempotent deduction keyed by `(deadPlayerUserId, deathEventId)`. Two cross-review rulings (C4: grace-timer ownership/duration; D1: 2-player last-stand kill-criterion) were already made and ratified by the user, but exist only as GDD-level notes scattered across `player-controller.md` and `resource-management.md` — this ADR is the single place that formalizes the full cross-system contract, including PC's own async reconciliation state machine, which several GDDs flag as needing ADR-level authority.

### Constraints

- `Humanoid.Died` can fire twice in pathological replication races (PC's own documented assumption) — the death handler must refuse re-entry, not reset the respawn timer.
- The oxygen-spend charge (`RequestSquadOxygenSpend`) is an async, potentially-yielding server-to-server call (RM's own `pcall`-wrapped path) — a naive "fire and forget" or "fire and assume success" would risk double-charging or losing a charge across a `BindToClose` server shutdown.
- `deathEventId` must be session-lifetime-unique (PC's own guarantee to RM, CR.4) and must survive across T6 (respawn) so a still-pending reconciliation can complete after the player has already respawned.
- The C4 and D1 rulings are already user-ratified — this ADR restates them as binding architecture, it does not reopen them.

### Requirements

- One canonical `deathEventId` minting scheme, used consistently by PC (minter), RM (dedup key), and any future consumer.
- A named, reusable async-idempotent-call state machine for the oxygen-spend charge, since a naive request/response assumption is unsafe across `BindToClose` and reconciliation-tick edge cases PC's own GDD already worked out in detail.
- Formal architecture-level record of the C4 (grace timer) and D1 (kill-criterion) rulings so future ADRs/stories don't need to re-derive them from GDD prose.
- R7c-I4: the grace-window safe range must refuse configuration below 2.0 s with a hard startup error, matching the config-validation-gate pattern ED itself uses (H.3d/H.3e).

## Decision

### `deathEventId` minting

**Player Controller mints `deathEventId` from a monotonic per-server-session counter** (`nextDeathEventId()`), guaranteeing session-lifetime uniqueness — this is PC's existing GDD design, ratified here as the binding cross-service contract RM's idempotency depends on (RM's own H.53 explicitly clears its dedup set at run end, "complementing PC's session-lifetime-uniqueness guarantee"). No other system mints a `deathEventId`; RM and any future consumer treat it as an opaque, PC-supplied key.

### Cross-service idempotency: compound key `(deadPlayerUserId, deathEventId)`

**`RequestSquadOxygenSpend(deadPlayerUserId: number, amount: number, reason: string, deathEventId: string): ()`** (signature already fixed in `docs/architecture/architecture.md` Boundary 3 during this session's TD sign-off) is deduplicated by RM against the compound key `(deadPlayerUserId, deathEventId)`. A duplicate call with the same compound key is a silent no-op (RM's own H.12). This ADR formalizes the signature and dedup key as binding — PC and RM must not diverge on either.

### PC's Pending → InFlight → Committed / Abandoned reconciliation state machine (ratified as the binding pattern)

PC's own GDD already designed a detailed async-idempotent-call state machine for the oxygen-spend charge, specifically to handle the case where `RequestSquadOxygenSpend`'s underlying call yields, and a **staleness sweep** or a server `BindToClose` could race the yield's resolution. **This ADR ratifies that state machine as the binding architecture**, since three GDDs (PC, RM, and this ADR's own cross-cutting scope) all assume its exact shape:

| State | Meaning | Entered from | Exits to |
|-------|---------|---------------|----------|
| **Pending** | Charge owed, not yet dispatched. The only reconcile-eligible state. | Record creation (at death); rollback from InFlight on call failure; staleness-sweep re-arm of an aged InFlight row | → InFlight (dispatch); → Abandoned (`BindToClose`) |
| **InFlight** | `RequestSquadOxygenSpend` call dispatched, awaiting resolution. | Pending, on dispatch | → Committed (success, gated by the post-yield ownership re-check below); → Pending (staleness-sweep re-arm mid-yield) |
| **Committed** | Charge succeeded; terminal-success. | The success path, **only if the row is still `InFlight`** at the moment the yield resolves | (terminal — row retained until the player's T6/`PlayerRemoving`, not deleted on the success path itself) |
| **Abandoned** | Closed without a charge; terminal-accepted-loss. | `BindToClose` fires while Pending or InFlight | (terminal) |

**The critical correctness rule**: on the success path, PC MUST re-check `row.state == "InFlight"` **after** the yield resolves, before treating the call as committed. If the staleness sweep re-armed the row to `Pending` *during* the yield (and a subsequent tick already re-dispatched it), the original coroutine's late success is **discarded** — logged, not committed, not rolled back — since acting on it would risk a double-commit against the re-dispatched attempt. This post-yield re-check is the load-bearing invariant; every future async cross-service charge in this project (if one arises) should follow the same Pending/InFlight/Committed-with-post-yield-recheck/Abandoned shape rather than inventing a new one, per Architecture Principle #4 ("Relocate, don't re-litigate").

A `deathEventId`-keyed record is independent of the player's S4 (Dead-Respawning) membership and instance lifecycle — it survives T6 (respawn) so a still-Pending charge reconciles after the player has already respawned into their next life. T6 detaches the player's `currentDeathRecord` pointer and starts the next life's record; it never deletes an uncommitted prior-life record.

### `Humanoid.Died` idempotent guard

**Decision**: the death handler (owned by ED per ADR-0004's `Humanoid.Died` monopoly) and PC's own T5-entry handler both refuse re-entry for an already-in-progress death: `Humanoid.Died` firing twice in a pathological replication race must not reset `RESPAWN_DELAY`'s 30 s timer or mint a second `deathEventId` for the same life. This is a simple guard flag (`_deathInProgress[player]`), set on first entry and cleared at T6.

### C4 ruling (grace timer): restated as binding architecture

**`OXYGEN_GRACE_DURATION = 5 s`** (safe range 4–8 s), **owned by Player Controller**, squad-wide (not per-player), with a pool-recheck at expiry and cancellation semantics per PC's own `CR.6`. This was ratified by the user on 2026-07-06 (cross-review C4) and is restated here as the binding architectural record — this ADR does not reopen it, only formalizes it as an implementation constraint alongside the rest of the death lifecycle it's part of.

### D1 ruling (2-player last-stand kill-criterion): restated as binding architecture

**Accept the 2-player BC4 (Beacon-Collapse-4) design as-is, with a binding kill-criterion**: `aliveCount ≤ 2` is a pre-committed last-stand floor, to be evaluated against first playtest data — if the 2-player post-BC4-death win rate is observed to be at or near zero, the kill-criterion triggers a mandatory design revisit (not a silent tuning patch). This was ratified by the user on 2026-07-06 (cross-review D1) and is restated here as binding, with the explicit **instrumentation requirement**: the analytics pipeline (`game-concept.md`'s `RunEnded{exitReason}` event, now concretely specified by ADR-0002's `RunEnded` signal) must be able to report 2-player-squad win/loss outcomes segmented from 3-and-4-player squads, so the kill-criterion is actually measurable from real data rather than anecdote.

### R7c-I4: grace-window safe-range hard error

**Decision**: `OXYGEN_GRACE_DURATION`'s config-validation gate refuses any configured value below **2.0 s** with a fatal startup error (mirroring ED's own `H.3d`/`H.3e` pattern of refusing misconfigured constants at `KnitInit` rather than silently degrading). This closes R7c-I4 and is consistent with the 4–8 s safe range the C4 ruling already established — 2.0 s is a hard floor below the safe range's own lower bound, catching a gross misconfiguration, not a legitimate tuning choice.

### Architecture Diagram

```
Humanoid.Died fires (ED's sole subscription, ADR-0004)
        │
        ▼
DisturbanceService:_onHumanoidDied  ─── GetOnPlayerDiedSignal() fan-out (3 consumers) ───┐
        │                                                                                 │
        ▼                                                                                 ▼        ▼
Player Controller (T5 entry)                                                    Crafting & Items  Predator AI
  - _deathInProgress guard (refuse re-entry)                                    (aliveMembers      (ReleasePredatorLock,
  - mint deathEventId = nextDeathEventId()                                       tracking)          C.1.x lock-clear)
  - create reconcileRows[deathEventId] = {state: "Pending", ...}
  - start OXYGEN_GRACE_DURATION (5s, PC-owned, squad-wide) — C.5 grace window
        │
        ▼ (grace expires OR immediate dispatch, per PC's own C.5 sequence)
  Pending → InFlight: RequestSquadOxygenSpend(deadPlayerUserId, amount, reason, deathEventId)
        │
        ▼ (yields — RM's pcall-wrapped path)
  Resource Management: dedup on (deadPlayerUserId, deathEventId) → deduct or no-op
        │
        ▼ (resolves)
  PC: post-yield re-check row.state == "InFlight"?
        │                                  │
       YES                                 NO (staleness sweep re-armed mid-yield)
        │                                  │
        ▼                                  ▼
   → Committed (terminal)          discard (log only, no commit, no rollback)

  RESPAWN_DELAY = 30s timer (independent of the above; starts at Humanoid.Died,
  idempotent guard prevents reset on a pathological double-fire)
        │
        ▼
  T6 (respawn): detach currentDeathRecord[player]; start next life's record;
  if reconcileRows[deathEventId] still Pending/InFlight, it survives and
  reconciles independently of T6.

  D1 kill-criterion: if aliveCount ≤ 2 post-BC4, this is the pre-committed
  last-stand floor — RunController's RunEndConditionRaised("wipe", squadState)
  fires per PC's own T7 logic (ADR-0002), segmented in analytics by squad size.
```

### Key Interfaces

```luau
--!strict
type ReconcileState = "Pending" | "InFlight" | "Committed" | "Abandoned"
type ReconcileRow = {
    deathEventId: string,
    userId: number,
    state: ReconcileState,
    inFlightSince: number?,  -- getServerTime() at Pending -> InFlight; nil while Pending
}

-- PC: minting (session-lifetime-unique, monotonic).
local _deathEventCounter = 0
local function nextDeathEventId(): string
    _deathEventCounter += 1
    return ("evt-%d"):format(_deathEventCounter)
end

-- PC: dispatch with the load-bearing post-yield re-check.
-- BINDING REQUIREMENT (engine-specialist review 2026-07-06): RequestSquadOxygenSpend
-- MUST yield synchronously within its own call (as shown below, it does not currently
-- yield at all, which is safe but means the pcall below has no real yield point to
-- protect against). If a future implementation makes RM's call genuinely async via
-- Knit's bundled Promise library, RequestSquadOxygenSpend must return a Promise that
-- THIS function :await()s/:expect()s INSIDE the pcall — never bare-call-and-check `ok`,
-- since pcall does not await a Promise; it would report ok=true the instant the Promise
-- object is constructed, before it resolves, silently defeating this entire race guard.
function PlayerController:_dispatchOxygenSpend(row: ReconcileRow): ()
    row.state = "InFlight"
    row.inFlightSince = workspace:GetServerTimeNow()
    local ok, result = pcall(function()
        return Knit.GetService("ResourceService"):RequestSquadOxygenSpend(
            row.userId, 1, "death", row.deathEventId)  -- row.userId, not a duplicated param (drift risk)
    end)
    -- LOAD-BEARING: re-check state AFTER the yield, not before.
    if ok and row.state == "InFlight" then
        row.state = "Committed"
    elseif ok then
        -- row was re-armed to Pending by the staleness sweep during the yield —
        -- discard this late success; the re-dispatched attempt owns the outcome.
        warn(("PC: discarding late success for %s — row re-armed mid-yield"):format(row.deathEventId))
    else
        row.state = "Pending"  -- rollback on failure
    end
end

-- RM: idempotent dedup on the compound key.
type DeathDedupSet = {[string]: boolean}
function ResourceService:RequestSquadOxygenSpend(
    deadPlayerUserId: number, amount: number, reason: string, deathEventId: string
): ()
    local dedupKey = (deadPlayerUserId .. "_" .. deathEventId)
    if self._deathDedupSet[dedupKey] then
        return  -- idempotent no-op (H.12)
    end
    self._deathDedupSet[dedupKey] = true
    self._oxygenPool = math.max(0, self._oxygenPool - amount * DEATH_OXYGEN_COST)
end

-- R7c-I4: config-validation hard error at KnitInit.
function PlayerController:KnitInit()
    if OXYGEN_GRACE_DURATION < 2.0 then
        error(("OXYGEN_GRACE_DURATION misconfigured: %.2f < 2.0s hard floor"):format(OXYGEN_GRACE_DURATION))
    end
end

-- BINDING REQUIREMENT (engine-specialist review 2026-07-06): error() thrown inside
-- KnitInit only halts startup if the server bootstrap's Knit.Start() catch handler
-- actually stops the server. The common Knit boilerplate
-- (Knit.Start():andThen(print):catch(warn)) only LOGS a rejected KnitInit promise —
-- Roblox has no implicit crash-on-uncaught-error at the process level, so a misconfigured
-- OXYGEN_GRACE_DURATION would silently fail to block server startup under that boilerplate,
-- defeating this hard-error requirement entirely. The project's server bootstrap
-- (ServerInit.server.luau) MUST use a catch handler that actually stops the instance:
--   Knit.Start():andThen(function() print("Knit started") end):catch(function(err)
--       warn(err)
--       game:Shutdown()  -- or an equivalent hard-stop; logging alone is NOT sufficient
--   end)
-- This is binding on ALL KnitInit-time config-validation hard errors project-wide
-- (ED's own H.3d/H.3e included), not just this ADR's OXYGEN_GRACE_DURATION check.
```

## Alternatives Considered

### Alternative 1: Fire-and-forget oxygen spend (no reconciliation state machine)
- **Description**: PC calls `RequestSquadOxygenSpend` once at death and assumes success; no Pending/InFlight/Committed tracking.
- **Pros**: Much simpler to implement.
- **Cons**: Cannot safely handle a `BindToClose` server shutdown mid-call (the charge could be silently lost with no record it was ever owed), and cannot handle the staleness-sweep re-arm case (a slow-resolving call racing a re-dispatch could double-commit). PC's own GDD already identified both failure modes in detail — this alternative would reintroduce bugs the existing design already closed.
- **Rejection Reason**: Loses correctness guarantees PC's own GDD already designed for; simplicity isn't worth reopening closed bugs.

### Alternative 2: RM mints `deathEventId` instead of PC
- **Description**: Have Resource Management mint the idempotency key, since it's the system that consumes it for deduplication.
- **Pros**: Keeps key-minting and key-consumption in the same system.
- **Cons**: `deathEventId` is also consumed by Crafting (`OnSquadMemberAliveChanged` correlation) and potentially other future death-consuming systems — PC is the system that actually observes the death event first (via `GetOnPlayerDiedSignal()`), so it is the natural minting point; RM minting it would require a round-trip (PC asks RM for a key, then uses it) before PC could even start its own T5 state machine, adding a synchronous dependency PC doesn't currently need.
- **Rejection Reason**: PC already mints it in the approved GDD; changing this would require a round-trip RM doesn't need and PC's GDD doesn't currently have.

## Consequences

### Positive
- PC's own carefully-designed reconciliation state machine is formally ratified as the binding cross-service contract, rather than living only in GDD prose that RM and future systems might not fully absorb.
- The C4 and D1 rulings now have one canonical architectural home instead of being scattered across two GDDs' notes.
- The post-yield ownership re-check pattern is named explicitly as a reusable project convention for any future async cross-service charge.

### Negative
- The reconciliation state machine is non-trivial to implement correctly (4 states, a staleness sweep, a post-yield re-check) — this is accepted complexity, not avoidable, given the correctness requirements (no double-charge, no silently-lost charge across `BindToClose`).

### Risks
- **Engine-specialist review (2026-07-06) — 2 blocking fixes applied**: (1) the `pcall`-wrapped dispatch had no stated yield discipline — if `RequestSquadOxygenSpend` is ever made genuinely async via a Knit Promise, `pcall` would report success the instant the Promise is *constructed*, not once it *resolves*, silently defeating the entire post-yield race guard this state machine exists for. Fixed: `RequestSquadOxygenSpend` MUST yield synchronously within its own call, or if it ever returns a Promise, `_dispatchOxygenSpend` MUST `:await()`/`:expect()` it inside the `pcall`, never bare-call-and-check `ok`. (2) `error()` thrown at `KnitInit` does not necessarily halt server startup — the common Knit bootstrap boilerplate (`Knit.Start():andThen(print):catch(warn)`) only logs a rejected `KnitInit` promise, which would silently defeat R7c-I4's "refuses to start" requirement. Fixed: the project's server bootstrap MUST use a `catch` handler that calls `game:Shutdown()` (or equivalent hard-stop) on any `KnitInit` rejection — stated as binding project-wide, not just for this ADR's own config-validation check. Also fixed: `_dispatchOxygenSpend` dropped its duplicated `deadPlayerUserId` parameter in favor of `row.userId` (drift-risk cleanup), and `_deathDedupSet`'s type is now declared explicitly.
- **The staleness sweep's own re-arm timing is not fully specified by this ADR** — PC's GDD implies a sweep exists (referenced by the "aged InFlight row" re-arm trigger) but its interval/threshold isn't restated here. **Mitigation**: this is implementation detail belonging to PC's own service, not a cross-service contract; flagged as an Open Question below rather than guessed at in this ADR.
- **D1's kill-criterion is only as good as the analytics segmentation** — if 2-player-squad outcomes aren't segmented from 3/4-player squads in the analytics pipeline, the kill-criterion cannot actually be evaluated. **Mitigation**: named explicitly as an instrumentation requirement in the D1 Decision above, not left implicit.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| player-controller.md | C.5.x death/respawn sequence, F.2 Pending/InFlight/Committed/Abandoned state machine, G.6 `OXYGEN_GRACE_DURATION`, F.4's own flagged need for a "Death-Cost Attribution" ADR | Ratifies PC's own state machine as binding; formalizes C4 (grace timer) as architecture |
| resource-management.md | CR.4 idempotency, F.2 `(userId, deathEventId)` dedup, H.10/H.12/H.14/H.53 | Formalizes the compound dedup key and PC's session-lifetime-uniqueness guarantee as a binding cross-service contract |
| ecological-disturbance-forward-obligations.md | R7c-I4 (grace-window safe-range hard error) | Closed via the `KnitInit` config-validation gate above |

## Performance Implications
- **CPU**: Negligible — reconciliation rows are created/resolved at most once per player death, not per-frame.
- **Memory**: One `ReconcileRow` per in-flight/pending death, bounded by concurrent squad size (max 4); rows are cleared at run end.
- **Load Time**: None.
- **Network**: `RequestSquadOxygenSpend` is a server-internal Knit call (not a RemoteEvent), so no client-facing bandwidth impact.

## Migration Plan
No migration — none of PC/RM/ED's death-handling code is implemented yet.

## Validation Criteria
- Unit test: a duplicate `RequestSquadOxygenSpend` call with the same `(deadPlayerUserId, deathEventId)` is a no-op (RM's own H.12, now a binding cross-service test).
- Unit test: a `Humanoid.Died` double-fire for the same life does not reset `RESPAWN_DELAY` or mint a second `deathEventId`.
- Unit test: a simulated staleness-sweep re-arm during an in-flight call's yield results in the late success being discarded, not committed.
- Integration test: the D1 kill-criterion's analytics segmentation correctly distinguishes a 2-player squad's win/loss outcome from 3/4-player squads.

## Related Decisions
- Depends on ADR-0004 (DisturbanceService Core Architecture) and ADR-0002 (RunController Architecture).
- `design/gdd/player-controller.md`, `design/gdd/resource-management.md`.
- The C4/D1 cross-review rulings, originally recorded in `design/gdd/gdd-cross-review-2026-07-05.md` and ratified by the user 2026-07-06.

## Open Questions
- **Staleness sweep interval/threshold** for re-arming an aged InFlight row to Pending is not specified by this ADR — belongs to Player Controller's own implementation detail, not a cross-service contract. Should be resolved during PC's implementation, not left permanently unspecified.
