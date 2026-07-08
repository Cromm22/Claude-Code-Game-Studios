# ADR-0010: Resource Management Tick Loop

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + Knit framework |
| **Domain** | Core (server tick loop, `RunService.Heartbeat`) |
| **Knowledge Risk** | LOW — `RunService.Heartbeat` and its delta-time argument are long-standing, well-documented Roblox APIs; nothing in this ADR depends on a post-cutoff feature. |
| **References Consulted** | `design/gdd/resource-management.md` (CR.3, H.6, H.19, H.43, H.44, H.49, H.52, H.54), ADR-0009 (Beacon-Charge-Tier accessor, called from this loop), ADR-0005 (Death & Respawn Lifecycle — the death-cost deduction path this loop must sequence correctly against) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0009 (Resource Management Beacon-Charge-Tier Accessor) — this loop calls that accessor once per tick to select the drain rate. |
| **Enables** | Resource Management epic — this was the second of RM's two blocking gaps found by the 2026-07-06 `/architecture-review`; RM's own most correctness-critical loop had no architectural decision at all before this ADR. |
| **Blocks** | No other ADR directly, but every RM Logic story that touches oxygen deduction, restoration, or drain depends on this loop's ordering being settled. |
| **Ordering Note** | Should be Accepted alongside or after ADR-0009. |

## Context

### Problem Statement

Resource Management's GDD specifies a strict per-tick ordering for its oxygen
pool math (CR.3): deductions apply, then restores apply, then drain applies,
clamping the pool after each step — with the squad's Empty-state check evaluated
only on the final, post-drain value. It also specifies a delta-time safety cap
(`MAX_TICK_DT=0.1s`, H.54) so a lag spike or GC pause cannot crater the pool in
one tick, and a same-tick death-coalescing rule (H.44) so simultaneous deaths
produce one HUD event, not N. None of this had ever been formalized at the
architecture level — RM's own most correctness-critical server loop was
entirely undecided prior to this ADR.

### Constraints

- Must run on `RunService.Heartbeat`, matching the project's stated performance
  pattern (`current-best-practices.md`: "Use Heartbeat for variable-rate per-frame logic").
- Must clamp the pool to `[0, OXYGEN_POOL_START]` after every mutating step, not
  just once at the end — an intermediate over-restore or over-deduct must never
  be observable even transiently within the same tick.
- Must call ADR-0009's `GetCurrentBeaconChargeTier()` accessor exactly once per
  tick (not once per deduction/restore event within the tick) to avoid the
  drain rate changing mid-calculation if the tier flips during a single tick.
- Must evaluate the beacon-survival win-check (RM's own H.49 cross-system ordering
  rule) *before* the Empty-state death trigger on the same boundary tick, so a
  tie resolves in the squad's favor per the GDD's own tie-breaking rule.

### Requirements

- One `RunService.Heartbeat`-bound tick function with the fixed step order:
  deductions → restores → drain (band-scaled) → clamp → win-check → Empty-state evaluation.
- A `MAX_TICK_DT` cap and a non-negative `dt` guard, since Roblox's `Heartbeat`
  delta can theoretically be reported as a very large value after a lag spike
  or (in a pathological case) as slightly negative due to floating-point timing artifacts.
- Same-tick multi-death coalescing into a single `OnOxygenDeducted` event carrying an applied count, not one event per death.

## Decision

**A single `RunService.Heartbeat`-connected function, `ResourceService:_onTick(dt: number)`,
established during `KnitStart` (per ADR-0001 — the loop itself is a KnitStart-phase
connection to an engine event, not a cross-service signal, so Rule 1 does not
require it to start in `KnitInit`), executing this fixed order every tick:**

1. **Clamp `dt`**: `local clampedDt = math.clamp(dt, 0, MAX_TICK_DT)` where `MAX_TICK_DT = 0.1`. A negative or absurdly large `dt` is silently clamped, never trusted raw — this closes both the lag-spike risk (H.54) and the negative-`dt` floating-point edge case in one guard.
2. **Deductions**: apply all oxygen deductions already queued this tick (death-cost charges from `RequestSquadOxygenSpend`, ADR-0005 — that call path is itself outside this loop's own scope; this step only applies the resulting pool mutation), coalescing same-tick multiple deductions into one applied total and one `OnOxygenDeducted` event carrying the coalesced count (H.44). Clamp the pool to `[0, OXYGEN_POOL_START]` after this step.
3. **Restores**: apply all queued restores (e.g., a Canister's `OnOxygenPulseRequest`). Clamp after this step.
4. **Drain**: read the current drain-relevant tier via `CraftingService:GetCurrentBeaconChargeTier()` (ADR-0009) **exactly once this tick**, look up the corresponding drain rate, and deduct `drainRate * clampedDt` from the pool. Clamp after this step.
5. **Win-check**: evaluate the beacon-survival win condition (owned by Crafting, read via its own accessor — out of this ADR's scope to define, only to sequence) *before* step 6, per H.49's tie-breaking rule.
6. **Empty-state evaluation**: check the post-drain, post-clamp pool value against the Empty threshold. If newly Empty this tick, fire the squad-wide `OnPlayerOxygenExpired()` (ADR-0005) exactly once.

Steps 1–6 execute synchronously within the same Heartbeat callback, with no
yield between them — this is not a new zero-yield rule invented here, it is the
same discipline ADR-0001/ADR-0004 already establish project-wide for cross-service-sensitive
sequences, applied to RM's own internal tick.

### Architecture Diagram

```
RunService.Heartbeat:Connect(function(dt)
    ResourceService:_onTick(dt)
end)  -- connected in KnitStart

ResourceService:_onTick(dt):
    1. clampedDt = math.clamp(dt, 0, MAX_TICK_DT)          -- H.54 lag-spike guard
    2. apply queued deductions -> clamp[0, OXYGEN_POOL_START]   -- coalesced, H.44
    3. apply queued restores   -> clamp[0, OXYGEN_POOL_START]
    4. tier = CraftingService:GetCurrentBeaconChargeTier()  -- ADR-0009, ONCE per tick
       drain = DRAIN_RATE_BY_TIER[tier] * clampedDt
       pool -= drain            -> clamp[0, OXYGEN_POOL_START]
    5. evaluate beacon-survival win-check (Crafting-owned)  -- BEFORE step 6, H.49
    6. if pool == 0 and not already Empty this run:
           fire OnPlayerOxygenExpired()  -- exactly once, ADR-0005
```

### Key Interfaces

```luau
--!strict
local MAX_TICK_DT = 0.1

function ResourceService:KnitStart()
    -- Connected here (not KnitInit) — this is an engine-event connection,
    -- not a cross-service-visible object ADR-0001 Rule 1 governs.
    RunService.Heartbeat:Connect(function(dt: number)
        self:_onTick(dt)
    end)
end

function ResourceService:_onTick(dt: number): ()
    local clampedDt = math.clamp(dt, 0, MAX_TICK_DT)  -- guards both lag spikes and negative dt

    self:_applyQueuedDeductions()   -- coalesced (H.44), clamps internally
    self:_applyQueuedRestores()     -- clamps internally

    local ok, tier = pcall(function()
        return Knit.GetService("CraftingService"):GetCurrentBeaconChargeTier()
    end)
    local drainTier = (ok and typeof(tier) == "number" and tier) or 1  -- ADR-0009 fail-safe
    local drainRate = DRAIN_RATE_BY_TIER[drainTier]
    self._oxygenPool = math.clamp(self._oxygenPool - drainRate * clampedDt, 0, OXYGEN_POOL_START)

    -- Win-check BEFORE Empty-state eval, per H.49 tie-breaking rule.
    self:_evaluateBeaconSurvivalWinCheck()

    if self._oxygenPool <= 0 and not self._hasFiredEmptyThisRun then
        self._hasFiredEmptyThisRun = true
        self._onPlayerOxygenExpired:Fire()  -- ADR-0005
    end
end
```

## Alternatives Considered

### Alternative 1: Apply drain continuously, deductions/restores as immediate side-effects outside the tick
- **Description**: Instead of queuing deductions/restores and applying them in a fixed tick order, apply each mutation immediately when it occurs (e.g., deduct oxygen the instant `RequestSquadOxygenSpend` resolves), and only run drain on the Heartbeat.
- **Pros**: Slightly simpler — no queue to manage.
- **Cons**: Loses the deterministic same-tick ordering CR.3 requires and makes the same-tick death-coalescing rule (H.44) impossible to implement correctly, since two near-simultaneous deaths could each apply and fire their own event before the other is even queued.
- **Rejection Reason**: Directly breaks two explicit GDD requirements (deterministic ordering, coalescing) for a marginal simplicity gain.

### Alternative 2: Read the Beacon-Charge-Tier accessor once per mutation type instead of once per tick
- **Description**: Call `GetCurrentBeaconChargeTier()` separately before deductions, before restores, and before drain, in case the tier changes mid-tick.
- **Pros**: Slightly more "live" if the tier happens to change mid-tick.
- **Cons**: The tier is only actually used by the drain step — calling it three times per tick for one consumer is wasted work, and worse, if the tier did change between calls, deductions and restores would be evaluated against an inconsistent tier snapshot, which is not a real requirement of the GDD and adds risk for no benefit.
- **Rejection Reason**: No requirement demands sub-tick tier consistency across steps that don't use the value; a single per-tick read is simpler and sufficient.

## Consequences

### Positive
- RM's most correctness-critical loop now has an explicit, implementable ordering, matching CR.3's own deterministic-ordering requirement exactly.
- The `MAX_TICK_DT` clamp closes both the lag-spike risk (H.54) and a previously-unconsidered negative-`dt` floating-point edge case in one guard.
- Sequencing the win-check before the Empty-state eval directly implements H.49's tie-breaking rule without needing a separate special case.

### Negative
- The fixed 6-step order is now a hard constraint on any future RM feature — a new oxygen-affecting mechanic must slot into one of these steps (most likely deductions or restores), not invent a seventh ad-hoc phase, to preserve the ordering guarantee.

### Risks
- **`CraftingService:GetCurrentBeaconChargeTier()` must never yield** (see ADR-0009's own Risks section) — if it ever does, this entire tick stalls, which is worse here than in most other server loops since RM's tick directly gates the Empty-state death trigger. **Mitigation**: already stated as a hard requirement in ADR-0009; this ADR's `pcall` wrap additionally protects against the call erroring outright, though not against it yielding (pcall does not prevent a yield from stalling the calling coroutine — this is the same class of risk ADR-0005 already flags for `RequestSquadOxygenSpend`, and the same mitigation applies: the accessor must be synchronous by contract, not merely wrapped defensively).
- **Engine-specialist review (2026-07-06)**: confirmed large `dt` spikes are real (lag, GC pauses, Studio breakpoint resumes) and the clamp is standard practice; confirmed a negative `dt` has no documented or observed precedent (the guard is likely a permanent no-op, correctly hedged as such rather than overclaimed). Minor non-blocking suggestion: cache `Knit.GetService("CraftingService")` once in `KnitStart` rather than re-resolving it by string lookup inside the 60Hz tick's `pcall`.
- **A negative `Heartbeat` delta has not been empirically observed on Roblox** — this ADR treats it as a defensive guard against a theoretical floating-point edge case, not a confirmed platform behavior. If it never occurs in practice, the guard is a no-op; if it does, the guard prevents a negative drain (i.e., the pool would otherwise increase) from a malformed `dt`.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| resource-management.md | CR.3 — 60Hz deterministic tick order (deductions → restores → drain, clamp after each step), Empty evaluated on final P; H.54 — `MAX_TICK_DT` cap; H.44 — same-tick death coalescing; H.49 — win-check-before-Empty-eval ordering | All five requirements are directly implemented in the Decision section's 6-step order |

## Performance Implications
- **CPU**: Negligible — a handful of arithmetic operations and one cross-service accessor call per Heartbeat tick (60Hz), well within Roblox's per-frame budget.
- **Memory**: None beyond the existing oxygen-pool scalar and a small deduction/restore queue, bounded by squad size (max 4).
- **Load Time**: None.
- **Network**: None directly — this is a server-internal tick; any resulting client-facing push (`OnOxygenChanged` etc.) is governed by RM's own signal-rate-limiting requirements, not this ADR.

## Migration Plan
No migration — RM's tick loop is not implemented yet.

## Validation Criteria
- Unit test: given a `dt` of `10.0` (a simulated lag spike), the pool changes by no more than `DRAIN_RATE_BY_TIER[tier] * MAX_TICK_DT`, not `DRAIN_RATE_BY_TIER[tier] * 10.0`.
- Unit test: given a negative `dt` (simulated pathological input), the tick applies zero drain, not a negative (pool-increasing) drain.
- Unit test: two simulated same-tick deaths result in exactly one `OnOxygenDeducted` event with an applied count of 2, not two separate events.
- Unit test: a simulated beacon-survival win condition and an Empty-state condition arising on the same tick resolves as a win, per H.49.

## Related Decisions
- Depends on ADR-0009 (Resource Management Beacon-Charge-Tier Accessor).
- References ADR-0005 (Death & Respawn Lifecycle) for the death-cost deduction path and `OnPlayerOxygenExpired` signal this loop fires.
- `design/gdd/resource-management.md` CR.3, H.44, H.49, H.54.
