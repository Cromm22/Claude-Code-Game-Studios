# ADR-0002: RunController Architecture

## Status
Accepted (ratified by the user 2026-07-06)

**Adoption note**: This ADR was drafted after 3 consecutive `AskUserQuestion` timeouts (60s each, no response) during this session. Per this project's established precedent (adopt the recommended option, flag pending ratification, and stop re-offering widgets after repeated timeouts rather than retrying indefinitely), the assumptions, decision, and write were all made autonomously using the recommended options. **RATIFIED by the user 2026-07-06** — the autonomous adoption is now explicitly confirmed, no longer pending.

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + Knit framework |
| **Domain** | Core (Foundation-tier orchestration / run-lifecycle state machine) |
| **Knowledge Risk** | LOW — this ADR introduces no new Roblox engine API beyond what ADR-0001 already governs (Knit service methods, `Signal`/`BindableEvent`, `KnitInit`/`KnitStart`). The risk here is architectural (getting the read-direction right), not engine-knowledge-gap. |
| **References Consulted** | `docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md`, `docs/architecture/architecture.md` (Module Ownership, Data Flow Flow 4, Architecture Principle #3), `design/gdd/player-controller.md` (F.4, H.7w), `design/gdd/crafting-and-items.md` (C.9 Beacon State Machine — BCT-DEFEAT's actual anchor, corrected 2026-07-06 from a stale "C.5.8" citation which is Crafting's cosmetic-boundary bullet, not the state machine; and its round-24 revert history), `design/gdd/resource-node.md` (completability gate) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond what ADR-0001 already requires (module-private `require()` identity, `Signal`/`BindableEvent` dispatch semantics) — RunController does not introduce a new engine-verification surface. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (KnitInit/KnitStart Ordering Discipline) — `RunEndConditionRaised` and the `RunEnded` signal object must be constructed during RunController's `KnitInit`, per Rule 1, since PC/Crafting may call `RunEndConditionRaised` at any point after their own boot completes and cannot assume RunController's `KnitStart` has already run. |
| **Enables** | Unblocks Player Controller, Crafting & Items, and Resource Node's completability gates — all three currently carry RunController as an explicit open dependency. |
| **Blocks** | The Foundation-layer epic cannot be considered complete without this ADR Accepted; PC's T7/T8 stories are blocked pending this ADR. Crafting's C.9 BCT-DEFEAT story is **not** currently blocked by this ADR — per Crafting's own frozen GDD model (see Decision, "Current caller reality" below), Crafting fires `OnBeaconWindowFailed`/`OnBeaconWindowSurvived` to Player Controller, not directly to RunController; PC is the sole current caller of `RunEndConditionRaised` for both wipe and victory, including the in-window (BC4) outcomes. |
| **Ordering Note** | Should be Accepted before Death & Respawn Lifecycle (must-have ADR #4), since T7 wipe (PC) and BCT-DEFEAT (Crafting) both fire through the RunEndConditionRaised contract this ADR defines, and the D1 cross-review ruling (2-player BC4 kill-criterion) is evaluated by PC before it calls into RunController, not by RunController itself. |

## Context

### Problem Statement

Every MVP GDD refers to "RunController" as the sole owner of run-lifecycle state and the sole `RunEnded` broadcaster, but RunController has never had its own GDD or ADR. Three systems (Player Controller, Crafting & Items, Resource Node) call out to it as an unauthored dependency. A real design attempt was made and explicitly backed out (commit `3747c3c`, round-24): it migrated only the "defeat" half of run-ending to RunController while leaving "victory" as a direct Player Controller broadcast (violating RunController's own "sole broadcaster" claim), never declared RunController in any interface table, left `RunEndConditionRaised` unregistered, and was non-buildable. This ADR authors RunController's architecture from scratch, explicitly designed to avoid that exact failure mode, and to satisfy the binding mandate from this project's own Technical Director architecture sign-off (`docs/architecture/architecture.md`, TD sign-off 2026-07-06): **RunController must be an event-subscriber only, never a synchronous state-puller.**

### Constraints

- Must not create an upward compile-time dependency from the Foundation layer into Core/Feature layers (RunController is Foundation-tier per the System Layer Map; PC is also Foundation-tier; Crafting is Core-tier; RN is Feature-tier — RunController must not synchronously call INTO Crafting or RN to ask "are you done/have you lost," per the layer map's downward-only dependency direction).
- Must fire `RunEnded` exactly once per run, regardless of how many separate conditions (PC wipe, PC victory, Crafting BCT-DEFEAT) are raised, including near-simultaneous raises.
- Must comply with ADR-0001: any object another service needs to call into (the `RunEndConditionRaised` method, the `RunEnded` signal) must exist from `KnitInit`.
- Must not repeat the backed-out migration's specific defect: partial migration (one exit path routed, the other not) and undeclared interface.

### Requirements

- A single, uniform entry point any Foundation/Core/Feature-layer service can call to report a run-ending condition, without RunController needing bespoke per-caller logic.
- The 2-player BC4 last-stand kill-criterion (D1 cross-review ruling: `aliveCount ≤ 2` post-Beacon-Collapse-4 floor) is evaluated where the relevant state already lives (Player Controller's own squad-alive tracking), not duplicated inside RunController.
- `RunEnded(exitReason)`'s payload must be sufficient for every current and near-term subscriber (HUD's end-screen, analytics' `RunEnded{exitReason}` event per `game-concept.md`) without requiring a second round-trip query back into RunController.

## Decision

RunController is authored as a thin, idempotent **event-fan-in aggregator**, not a state machine that independently tracks squad or crafting state:

1. **Single inbound contract**: RunController exposes exactly one **server-internal inter-service method (a plain Knit service method, NOT placed under `.Client` — no client-facing exposure is intended or safe)**, `RunEndConditionRaised(conditionType: "wipe" | "victory", squadState: SquadStateSnapshot, defeatReason: ("wipe" | "scatter")?)`, callable by any server-side Knit service. The caller is always responsible for having already determined that the condition is true and for supplying its own current state snapshot in the payload — RunController never calls back into the caller (or any other service) to independently verify or fetch state. This directly satisfies the TD's event-subscriber-only mandate and is the fix for the backed-out migration's core defect (it tried to have RunController own logic that properly belongs to the caller).

   **Current caller reality (fixed 2026-07-06 — closes a 3-part ADR-vs-GDD mismatch found by `/architecture-review`)**: the **sole current caller is Player Controller** — T7 whole-squad-wipe (pre-activation only) and T8 victory (H.7w). Crafting & Items is **not** a current caller: per Crafting's own frozen GDD (C.9 Beacon State Machine — corrected from a stale "C.5.8" citation, which is actually Crafting's cosmetic-boundary bullet, not the state machine), Crafting fires `OnBeaconWindowSurvived`/`OnBeaconWindowFailed(reason: "wipe" | "scatter")` to **Player Controller**, which is the system that would in turn call `RunEndConditionRaised` for the in-window (BC4) outcomes — mirroring the same T7/T8 pattern PC already owns pre-activation. This ADR previously listed Crafting as a current direct caller, which was never true under Crafting's actual GDD model (the round-24 revert backed out exactly this migration; it has not been re-applied). **`defeatReason` is added as an optional third parameter** so that when PC forwards Crafting's in-window wipe (`reason="wipe"`) or scatter/line-break (`reason="scatter"`) outcome, the distinction survives into `RunEndConditionRaised` and `RunEnded`'s payload for analytics/HUD — `conditionType` alone (`"wipe" | "victory"`) cannot represent "scatter" as a defeat sub-reason, and extending `conditionType` itself would break its clean wipe/victory symmetry for no benefit, so a separate optional field carries the finer distinction instead. `defeatReason` is `nil` for `conditionType == "victory"` and for a pre-activation `"wipe"` (which has no scatter/line-break concept — only the in-window BC4 outcome can be "scatter").
2. **One-shot idempotency latch**: RunController holds a single `_hasEnded: boolean` flag, `false` at `KnitInit`. The first call to `RunEndConditionRaised` (regardless of `conditionType` or caller) sets `_hasEnded = true` and immediately fires the outbound `RunEnded(exitReason)` signal with `exitReason` set to the same value as the inbound `conditionType`. Every subsequent call in the same run is a silent no-op (logged at `warn` level for observability, since a second call after latch usually indicates a caller-side ordering bug worth surfacing, not a crash-worthy condition).
3. **Single outbound contract**: RunController exposes one signal, `RunEnded`, fired exactly once per run with payload `{exitReason: "wipe" | "victory", squadState: SquadStateSnapshot, timestamp: number}`. All current and near-term subscribers (HUD end-screen, analytics `RunEnded{exitReason}` event, PC's own T7/T8 terminal-state cleanup) subscribe to this one signal — none query RunController for current state, matching Architecture Principle #2 ("One event bus, one direction" — though RunController is not THE bus, ED is; RunController is a second, narrower, single-purpose broadcast channel, scoped only to the run-boundary event itself).
4. **Fixes the specific backed-out defect**: both "wipe" and "victory" are declared, symmetric `conditionType` values on the SAME method — there is no code path where one exit reason bypasses RunController and is broadcast directly by the caller. `RunEndConditionRaised` and `RunEnded` are both declared in this ADR's Key Interfaces (the backed-out migration's failure was in part that neither was declared anywhere).

### Architecture Diagram

```
                    ┌─────────────────────────────────────┐
                    │           RunController               │
                    │  (Foundation tier, event-fan-in only) │
                    │                                       │
  PC (T7 wipe,     │  RunEndConditionRaised(conditionType,  │
   pre-activation) │    squadState, defeatReason?)          │
  PC (T8 victory)──►│    │                                  │
  PC (in-window     │    │  (Crafting fires OnBeaconWindowFailed/
   BC4 wipe/scatter,│    │   Survived to PC per its own GDD model —
   forwarded from   │    │   PC calls RunEndConditionRaised, Crafting
   Crafting's C.9)─►│    │   does not call it directly, fixed 2026-07-06)
                    │    ▼                                  │
                    │  if _hasEnded: no-op + warn            │
                    │  else: _hasEnded = true                │
                    │        Fire RunEnded(exitReason,       │
                    │          squadState, timestamp)        │
                    └──────────────┬────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┬───────────┐
                    ▼              ▼              ▼           ▼
                  HUD          Analytics    PC (self,     (future
             (end screen)   (RunEnded event) cleanup)    subscribers)
```

Note the arrows: RunController never reaches back UP into PC or Crafting. It only receives calls and only broadcasts outward — satisfying the Foundation layer's requirement of not creating upward dependencies into Core/Feature.

### Key Interfaces

```luau
--!strict
-- src/server/services/RunController.luau

type SquadStateSnapshot = {
    aliveCount: number,
    totalCount: number,
    -- exact shape TBD when PC/Crafting's squadState types are finalized;
    -- RunController treats this as an opaque pass-through payload it does
    -- not interpret, only relays to RunEnded subscribers.
    [string]: any,
}

type RunEndedPayload = {
    exitReason: "wipe" | "victory",
    squadState: SquadStateSnapshot,
    timestamp: number,
    -- Added 2026-07-06 (/architecture-review re-verification, closes the
    -- Crafting "scatter" enum gap): nil for victory and for a pre-activation
    -- PC wipe; set to Crafting's own reason ("wipe" | "scatter") when PC
    -- forwards an in-window BC4 outcome it received via OnBeaconWindowFailed.
    defeatReason: ("wipe" | "scatter")?,
}

function RunController:KnitInit()
    -- REQUIRED by ADR-0001 Rule 1: constructed here, not KnitStart, since PC/
    -- Crafting may call RunEndConditionRaised at any point after their own
    -- KnitStart completes, and cannot assume RunController's KnitStart already ran.
    self._hasEnded = false
    self._runEnded = Signal.new()  -- ADR-0001: prefer Signal over BindableEvent
end

-- Server-internal inter-service method — a plain Knit service method, deliberately
-- NOT placed under `.Client`. Placing this under `.Client` would let any connected
-- game client fire a fake RunEndConditionRaised("victory", ...) and end the run for
-- the whole squad — a server-authority breach. This method must never be exposed
-- to clients.
function RunController:RunEndConditionRaised(
    conditionType: "wipe" | "victory",
    squadState: SquadStateSnapshot,
    defeatReason: ("wipe" | "scatter")?  -- added 2026-07-06; nil unless PC forwards
                                          -- Crafting's in-window BC4 outcome
): ()
    if self._hasEnded then
        warn(("RunController: RunEndConditionRaised(%s) called after run already ended — ignored")
            :format(conditionType))
        return
    end
    self._hasEnded = true
    self._runEnded:Fire({
        exitReason = conditionType,
        squadState = squadState,
        timestamp = os.time(),  -- wall-clock Unix epoch seconds — NOT workspace:GetServerTimeNow(),
                                 -- which is seconds-since-server-start and meaningless to an
                                 -- analytics pipeline outside this server instance (engine-specialist
                                 -- review 2026-07-06).
        defeatReason = defeatReason,
    } :: RunEndedPayload)
end

function RunController:GetRunEndedSignal(): Signal.Signal
    -- Subscribers connect here during their own KnitStart. Safe regardless of
    -- KnitStart order because the Signal object was constructed at KnitInit (ADR-0001).
    return self._runEnded
end
```

## Alternatives Considered

### Alternative 1: RunController independently polls squad/crafting state each tick
- **Description**: RunController runs its own `RunService.Heartbeat` loop, synchronously querying `Knit.GetService("PlayerController"):GetSquadState()` and `Knit.GetService("CraftingService"):GetBeaconState()` each tick to decide wipe/victory itself.
- **Pros**: Centralizes all win/lose logic in one file; callers don't need to know the exit conditions themselves.
- **Cons**: Directly violates the TD's event-subscriber-only mandate — creates a synchronous, per-tick dependency from Foundation (RunController) into Core (Crafting) and requires RunController to duplicate win/lose logic that PC and Crafting already need to know for their own state machines (PC's own T7/T8 transitions, Crafting's own BCT-DEFEAT detection). Wasteful (polling every tick vs. event-driven) and violates the layer map's downward-only dependency direction.
- **Rejection Reason**: This is the exact pattern the TD sign-off explicitly forbade.

### Alternative 2: Split ownership — RunController owns defeat only, PC keeps broadcasting victory directly
- **Description**: Preserve the shape of the backed-out migration — only route the "wipe" path through RunController; leave "victory" as a direct PC-side `RunEnded` broadcast.
- **Pros**: Smaller diff if PC's victory logic is already written to broadcast directly.
- **Cons**: This is literally the defect the round-24 focused review found and backed out — it breaks RunController's own "sole broadcaster" claim, means two different code paths implement the run-ending contract with different guarantees (only one goes through the idempotency latch), and any future subscriber (HUD, analytics) must special-case which signal to listen to depending on exit reason.
- **Rejection Reason**: Already tried, already reverted, already documented as non-buildable and inconsistent (`3747c3c`).

## Consequences

### Positive
- Single, symmetric contract for both exit conditions — no special-casing per subscriber or per caller.
- Idempotency latch makes double-fire (e.g., a near-simultaneous PC wipe detection and Crafting BCT-DEFEAT raise) safe by construction, rather than relying on caller-side coordination.
- Directly closes the exact defect class the backed-out migration left open, using the mined lesson from that commit's message rather than repeating it.
- Fully compliant with ADR-0001 and the TD's event-subscriber mandate — no upward Foundation→Core/Feature dependency is created.

### Negative
- `SquadStateSnapshot`'s shape is intentionally left opaque/pass-through at this ADR's authoring time, since PC's and Crafting's own squad-state types aren't finalized as a shared type yet — this is deferred to implementation, not resolved here (see Open Questions).
- The `warn`-not-error choice for a post-latch call means a caller-side bug (e.g., PC racing to call `RunEndConditionRaised` twice) is only observable in logs, not surfaced as a hard failure — acceptable for MVP, but worth a QA smoke check once implemented.

### Risks
- **`/architecture-review` re-verification fix (2026-07-06)**: this ADR previously (a) cited a stale "C.5.8" anchor for Crafting's BCT-DEFEAT (the actual Beacon State Machine section is C.9; C.5.8 is Crafting's cosmetic-boundary bullet), (b) listed Crafting & Items as a *current* caller of `RunEndConditionRaised`, when Crafting's own frozen GDD model has it firing `OnBeaconWindowFailed`/`OnBeaconWindowSurvived` to Player Controller instead — the direct-to-RunController migration is the one round-24 explicitly backed out and has not been re-applied, and (c) had no way for `conditionType: "wipe" | "victory"` to represent Crafting's `"scatter"` line-break defeat reason. Fixed: reworded the caller list to state PC as sole current caller (forwarding Crafting's in-window outcomes), corrected the citation, and added an optional `defeatReason: ("wipe" | "scatter")?` parameter/payload field so PC's forwarding path (present or future) has somewhere to put Crafting's finer reason. See the Open Questions below for the remaining cross-GDD tension this fix does not fully resolve.
- **`RunEndConditionRaised` must never be exposed under `.Client`** (identified by gameplay-programmer engine-specialist review 2026-07-06). In Knit idiom, methods placed under a service's `.Client` sub-table are auto-exposed to game clients via RemoteFunction/RemoteEvent. `RunEndConditionRaised` is a plain, server-internal Knit service method by design — if a future contributor "fixes" the terminology mismatch by moving it under `.Client`, any connected game client could fire a fake `RunEndConditionRaised("victory", ...)` and end the run for the whole squad, a server-authority breach (`.claude/docs/technical-preferences.md`'s "Trusting client-supplied values" forbidden pattern). **Mitigation**: this is now stated explicitly in the Decision and Key Interfaces sections, not left as an implicit assumption; code review for RunController's implementation should treat any `.Client`-table placement of this method as an automatic blocking finding.
- **`os.time()` vs. `workspace:GetServerTimeNow()` for the payload's `timestamp` field** (identified by gameplay-programmer engine-specialist review 2026-07-06): `GetServerTimeNow()` returns seconds-since-server-instance-start, not wall-clock time, and would be meaningless to an analytics pipeline reading `RunEnded{exitReason}` events across sessions/servers (`game-concept.md`'s analytics event schema, referenced in `docs/architecture/architecture.md`'s Technical Requirements Baseline). **Fixed in this revision**: `timestamp` now uses `os.time()` (Unix epoch seconds) instead.
- **Near-simultaneous dual-raise race**: if PC's wipe detection and Crafting's BCT-DEFEAT both fire in the same frame before either sees the other's effect, the ADR-0001 zero-yield/synchronous-dispatch guarantee (Signal:Fire()) ensures the first call to actually execute wins the latch deterministically — there is no genuine race at the Luau execution-model level, only an ordering question of which caller happens to invoke first, which is an acceptable non-determinism (either exit reason is a legitimate simultaneous end state). **Mitigation**: none needed beyond the latch itself; flag for a scenario-walkthrough re-check in the next `/review-all-gdds` pass once RunController's GDD-facing behavior (if authored) integrates with PC/Crafting.
- **`SquadStateSnapshot` shape drift**: since this ADR treats the payload as opaque, PC and Crafting could each supply incompatible shapes, and HUD/analytics subscribers would need to handle both. **Mitigation**: this is flagged as an Open Question below and should be resolved before implementation, ideally by pointing both PC and Crafting at one shared type alias.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| player-controller.md | F.4 caller-side contract: `RunController:RunEndConditionRaised(conditionType ∈ {"wipe","victory"}, squadState)` (H.7w T7/T8); PC is the sole current caller, including in-window BC4 outcomes forwarded from Crafting | This ADR authors the receive-side of this contract, extended with an optional `defeatReason` param (2026-07-06) so PC can forward Crafting's `"wipe"`/`"scatter"` distinction without changing `conditionType`'s clean wipe/victory symmetry |
| crafting-and-items.md | C.9 Beacon State Machine — BCT-DEFEAT fires `OnBeaconWindowFailed(reason ∈ {"wipe","scatter"})` to **Player Controller** (not directly to RunController, per Crafting's own current GDD model); round-24 revert history (the backed-out direct-to-RunController migration) | This ADR does not wire Crafting as a direct caller (that migration remains deferred, unapplied) — it only ensures PC's forwarding path can carry Crafting's full reason set via `defeatReason`, so a future direct-migration (if authored) or PC's current forwarding path both have a home for `"scatter"` |
| resource-node.md | Completability gate (Emit / PC death+isDarkZone / RunEnded / HUD render) | `RunEnded` is now a concretely specified signal RN's completability chain can depend on |

## Performance Implications
- **CPU**: Negligible — `RunEndConditionRaised` fires at most a handful of times per run (once per exit-condition attempt, most runs firing it exactly once), not per-frame.
- **Memory**: One `Signal` instance and one boolean per server instance for the lifetime of a run; discarded at run end per Architecture Principle #5 ("Rounds, not saves").
- **Load Time**: None.
- **Network**: None directly — `RunEnded` is a server-internal signal; any client-facing broadcast (e.g., HUD's end screen) is the subscriber's own `RemoteEvent`/`RemoteSignal` responsibility, not RunController's.

## Migration Plan
No migration — RunController has never been implemented. The backed-out `3747c3c` commit reverted the only prior implementation attempt before it was ever committed as working code; there is nothing to migrate from.

## Validation Criteria
- Unit test: calling `RunEndConditionRaised` twice with different `conditionType`s results in exactly one `RunEnded` fire, with `exitReason` matching the FIRST call.
- Unit test: `RunEnded`'s signal object is confirmed non-nil immediately after `KnitInit` completes (before any `KnitStart` runs), verifying ADR-0001 compliance.
- Integration test (once PC/Crafting are implemented): a scripted 2-player run reaching the D1 `aliveCount ≤ 2` floor results in PC calling `RunEndConditionRaised("wipe", ...)` and RunController broadcasting `RunEnded` exactly once.

## Related Decisions
- Depends on ADR-0001 (KnitInit/KnitStart Ordering Discipline).
- `docs/architecture/architecture.md` — Module Ownership (RunController row, TD-mandated event-subscriber pattern), Data Flow Flow 4.
- Mined from the reverted commit `3747c3c` ("Crafting & Items: round-24 focused arbiter review — back out uncommitted RunController-arbiter migration").

## Open Questions
- **`SquadStateSnapshot`'s concrete shape** is not finalized here — deferred until Player Controller's and Crafting's own squad-state types are authored/reconciled, ideally as one shared type alias both services import, to avoid the drift risk noted above. This should be resolved before or during Foundation-layer implementation, not left open into Production.
- **A deeper PC-vs-Crafting model tension survives this fix, and needs a design ruling, not an ADR-level patch**: `player-controller.md` line 369 describes the in-window (BC4) wipe as "Crafting's BCT-DEFEAT, raised to the arbiter" — phrasing that reads as Crafting calling `RunEndConditionRaised` directly — while `crafting-and-items.md` (lines 1806, 2088) has Crafting firing `OnBeaconWindowFailed`/`OnBeaconWindowSurvived` to **PC**, with PC then responsible for mapping `reason="wipe"` to `RunEnded(defeat)` (marked "Deferred... unverified-until-PC" in Crafting's own GDD). This ADR's fix (above) assumes PC-as-forwarder, matching Crafting's GDD and PC's own C.9 RemoteEvent table (line 463, which lists PC as the sole caller), but PC's line-369 prose itself still describes the older direct-Crafting-to-arbiter shape. Recommend a small GDD-text sync (not an architecture decision) confirming PC-as-forwarder in both places, or an explicit ruling if direct-Crafting-calling is actually preferred — flagged here rather than silently resolved, since editing either GDD's normative text is outside this ADR's authority.
