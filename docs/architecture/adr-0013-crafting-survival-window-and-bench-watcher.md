# ADR-0013: Crafting Survival-Window Timer & Bench Proximity Watcher

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + Knit framework |
| **Domain** | Core (server tick loops — two independent Heartbeat-bound watchers) |
| **Knowledge Risk** | LOW — both loops use `RunService.Heartbeat`, an already-established pattern in this project (ADR-0004's field-update loop, ADR-0010's RM tick loop). The survival-window loop's timestamp read routes through Crafting's own C.16 `_clock()` seam (production default `workspace:GetServerTimeNow()`), per a 2026-07-06 re-verification fix — the original draft called the engine clock inline, which Crafting's GDD forbids in handler bodies (R4-4). |
| **References Consulted** | `design/gdd/crafting-and-items.md` (C.9 survival-window, C.5.8/B5 `_step` Heartbeat binding, E.13/G.5 bench sensor), ADR-0010 (Resource Management Tick Loop — the sibling pattern this ADR mirrors for a second system's own tick loop), ADR-0004 (DisturbanceService's own field-update Heartbeat loop, the precedent for Heartbeat-bound accumulator patterns in this project) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (KnitInit/KnitStart Ordering Discipline — governs where the Heartbeat connections themselves are established). |
| **Enables** | Crafting & Items epic — two of Crafting's own four self-flagged, previously-unauthored ADRs (per `production/epics/crafting-and-items/EPIC.md`). |
| **Blocks** | No other ADR, but Crafting's beacon-window and bench-interaction Logic stories depend on this ADR. |
| **Ordering Note** | Independent of ADR-0014 (Crafting Placement Validation) — the two Crafting ADRs can be Accepted in either order. |

## Context

### Problem Statement

Crafting & Items owns two independent time-sensitive server loops that were
never formalized at the architecture level, despite Crafting's own F.4 section
naming both as needing dedicated ADRs: (1) the beacon survival-window countdown,
which must be measured via a monotonic server clock comparison rather than
`task.delay` (since `task.delay` cannot be cancelled/re-armed cleanly if the
window needs to end early via `BindToClose` or a squad wipe), and (2) the bench
proximity watcher, which determines whether enough squad members are near a
bench to craft, sampled at a fixed rate rather than continuously.

### Constraints

- The survival-window timer must never use `task.delay` — a `BindToClose`-triggered
  forced cleanup or a squad wipe mid-window must be able to end the window
  immediately, and a pending `task.delay` callback firing after such an event
  would fire on stale state. A per-Heartbeat clock comparison can simply be
  skipped once a `runOutcomeResolved` latch (Crafting's own C.9 idempotency
  latch) is set, with no risk of a stale callback firing later.
- The bench watcher must run at a fixed, bounded rate (`SENSOR_CHECK_HZ = 5`,
  matching ED's own `FIELD_UPDATE_HZ` per Crafting's own G.5 cross-reference)
  rather than every single Heartbeat frame, since proximity checks across
  multiple players and multiple benches are more expensive than a single
  scalar comparison and do not need per-frame precision.
- Both loops must be yield-free within their own per-tick body, consistent with
  the zero-yield discipline this project already establishes for time-sensitive
  logic (ADR-0001, ADR-0004, ADR-0010).

### Requirements

- A single `RunService.Heartbeat`-bound survival-window timer using
  `workspace:GetServerTimeNow()` comparisons, never `task.delay`.
- A separate `RunService.Heartbeat`-bound bench-proximity watcher, rate-limited
  to `SENSOR_CHECK_HZ = 5` via an accumulator (not every Heartbeat frame).
- Both loops must respect Crafting's own `runOutcomeResolved` idempotency latch
  (ADR-0002-adjacent — see the RunController epic) — once set, both loops become no-ops.

## Decision

### Survival-window timer

**A single `RunService.Heartbeat`-connected function** (established in
`KnitStart`, per the same reasoning as ADR-0010's tick loop — an engine-event
connection, not a cross-service-visible object ADR-0001 Rule 1 governs), holding
one server-side timestamp per active beacon window,
`_windowActivatedAt: number`, set via Crafting's own **`_clock()` seam** (C.16 —
production default wraps `workspace:GetServerTimeNow()`, test-overridable; never
called inline, per R4-4) at the moment the beacon is activated. Each tick:

```
if runOutcomeResolved then return end  -- idempotency latch, no-op after resolution
if not windowActive then return end
local elapsed = _clock() - _windowActivatedAt   -- C.16 seam, not inline workspace:GetServerTimeNow()
if elapsed >= WINDOW_DURATION then
    -- fire OnBeaconWindowSurvived (win) — see the Crafting epic /
    -- RunController epic for the known interface-mismatch caveat on
    -- what this eventually routes to
end
```

No `task.delay` is ever used for this comparison. If the window needs to end
early (a squad wipe reaching Crafting via `GetOnPlayerDiedSignal`'s fan-out, or
a `BindToClose`-triggered forced cleanup), the check above is simply never
reached again once `runOutcomeResolved` is set elsewhere in the same tick or a
prior one — there is no pending callback to cancel, because none was ever scheduled.

### Bench proximity watcher

**A second `RunService.Heartbeat`-connected function**, using an accumulator
pattern identical in shape to ED's own field-update loop (ADR-0004):

```
_benchWatcherAccumulator += dt
if _benchWatcherAccumulator < (1 / SENSOR_CHECK_HZ) then return end
_benchWatcherAccumulator -= (1 / SENSOR_CHECK_HZ)
-- run the actual proximity scan here, at a true 5Hz cadence regardless of
-- the underlying Heartbeat's actual frame rate
```

Each 5Hz pass computes, per bench, the count of squad members within the
bench's proximity radius (using server-tracked `HumanoidRootPart.Position`
reads, the same primitive every other proximity check in this project already
uses), and updates `benchMaxCraftersEffective` accordingly. This value changing
fires a rate-limited client-facing signal (already covered by ADR-0008's
bandwidth accounting for Crafting's signals) only on an actual value change,
not every 5Hz tick regardless of change.

### Architecture Diagram

```
CraftingService:KnitStart():
    RunService.Heartbeat:Connect(function(dt)
        self:_onSurvivalWindowTick()   -- every Heartbeat frame, clock-comparison only
        self:_onBenchWatcherTick(dt)   -- accumulator-gated, true 5Hz cadence
    end)

_onSurvivalWindowTick():
    if runOutcomeResolved: return       -- idempotency latch short-circuits both loops'
                                         -- "window resolution" concerns permanently
    if not windowActive: return
    elapsed = _clock() - windowActivatedAt   -- C.16 seam, not inline GetServerTimeNow()
    if elapsed >= WINDOW_DURATION:
        -- fire survival win condition

_onBenchWatcherTick(dt):
    accumulator += dt
    if accumulator < 1/SENSOR_CHECK_HZ: return
    accumulator -= 1/SENSOR_CHECK_HZ
    for each bench:
        count = count squad members within proximity radius (server-tracked positions)
        if count != bench.lastKnownCount:
            bench.lastKnownCount = count
            fire rate-limited client update (only on actual change)
```

### Key Interfaces

```luau
--!strict
local SENSOR_CHECK_HZ = 5

-- Crafting's own C.16 clock-injection seam (production default; tests override
-- this field directly). Added 2026-07-06 re-verification fix — the original
-- draft called workspace:GetServerTimeNow() inline in _onSurvivalWindowTick,
-- which Crafting's GDD explicitly forbids in handler bodies (R4-4).
CraftingService._clock = function() return workspace:GetServerTimeNow() end

function CraftingService:KnitStart()
    -- NOTE (engine-specialist review 2026-07-06): Roblox does not continue
    -- executing the rest of a connected function after an uncaught error —
    -- it logs and returns. Running both sub-calls in one callback body means
    -- an error in _onSurvivalWindowTick would silently skip the bench scan
    -- for that frame. Each is pcall-wrapped individually to preserve fault
    -- isolation between the two otherwise-independent concerns.
    RunService.Heartbeat:Connect(function(dt: number)
        local ok1, err1 = pcall(function() self:_onSurvivalWindowTick() end)
        if not ok1 then warn("CraftingService survival-window tick error:", err1) end
        local ok2, err2 = pcall(function() self:_onBenchWatcherTick(dt) end)
        if not ok2 then warn("CraftingService bench-watcher tick error:", err2) end
    end)
end

function CraftingService:_onSurvivalWindowTick(): ()
    if self._runOutcomeResolved then return end
    if not self._windowActive then return end
    local elapsed = self._clock() - self._windowActivatedAt  -- C.16 seam, NOT inline workspace:GetServerTimeNow()
    if elapsed >= self._windowDuration then
        self._windowActive = false
        self:_onBeaconWindowSurvived()  -- see Crafting/RunController epics for the
                                          -- known routing caveat on this outcome
    end
end

function CraftingService:_onBenchWatcherTick(dt: number): ()
    self._benchWatcherAccumulator += dt
    local interval = 1 / SENSOR_CHECK_HZ
    if self._benchWatcherAccumulator < interval then return end
    self._benchWatcherAccumulator -= interval

    for _, bench in self._benches do
        local count = self:_countSquadMembersNearBench(bench)  -- server-tracked positions
        if count ~= bench.lastKnownCount then
            bench.lastKnownCount = count
            self:_fireBenchOccupancyChanged(bench)  -- rate-limited, change-only
        end
    end
end
```

## Alternatives Considered

### Alternative 1: `task.delay` for the survival window
- **Description**: Schedule the window's resolution via `task.delay(WINDOW_DURATION, function() ... end)` at activation time, instead of a per-tick clock comparison.
- **Pros**: Simpler at first glance — no per-tick check needed.
- **Cons**: `task.delay` cannot be cleanly cancelled once scheduled without holding onto and explicitly cancelling the returned thread — and even then, a squad wipe or `BindToClose` arriving in the same frame as (but before) the delayed callback fires creates a race the per-tick comparison approach simply does not have, since the per-tick approach's every check already begins with the `runOutcomeResolved` short-circuit.
- **Rejection Reason**: The per-tick comparison is simpler to reason about for early-termination correctness, and this project's own `deprecated-apis.md` already discourages "saving on every property change" style timing patterns in favor of explicit ownership over the check — the same principle applies here.

### Alternative 2: Bench watcher runs every Heartbeat frame, not accumulator-gated
- **Description**: Run the bench proximity scan on every single Heartbeat tick (potentially 60Hz), not gated to 5Hz.
- **Pros**: Slightly more "live" proximity detection.
- **Cons**: Crafting's own G.5 cross-reference already pins this to match ED's `FIELD_UPDATE_HZ=5` cadence — running 12x more often than that reference cadence for no stated gameplay benefit wastes server CPU for a value (bench occupancy) that does not need frame-perfect precision.
- **Rejection Reason**: No requirement demands higher than 5Hz precision; the accumulator pattern already has a proven precedent in this project (ADR-0004).

## Consequences

### Positive
- Closes two of Crafting's own four self-flagged, previously-unauthored ADRs.
- The clock-comparison approach for the survival window makes early-termination (squad wipe, `BindToClose`) trivially correct — there is no cancellation logic to get wrong, only a short-circuit check that already has to exist for the idempotency latch anyway.
- The bench watcher's accumulator pattern directly reuses a proven pattern (ADR-0004) rather than inventing a new one.

### Negative
- Two independent Heartbeat connections inside `CraftingService` (plus RM's own tick loop, ADR-0010, and ED's field-update loop, ADR-0004) means this project now has multiple systems each running their own Heartbeat-bound loop — individually cheap, but worth consolidating into a shared tick-dispatcher if a future system wants a fourth or fifth independent loop (same note as ADR-0011's Consequences).

### Risks
- **Engine-specialist review (2026-07-06) finding, folded in**: running both sub-loops in one shared `Heartbeat:Connect` callback meant an uncaught error in `_onSurvivalWindowTick` would silently abort the callback before `_onBenchWatcherTick` ran that frame (Roblox does not continue executing the rest of a connected function after an error). Fixed by wrapping each sub-call in its own `pcall` inside the shared callback, restoring fault isolation between the two otherwise-independent concerns without needing two separate connections.
- **`/architecture-review` re-verification fix (2026-07-06)**: the original Decision text and Key Interfaces sample called `workspace:GetServerTimeNow()` inline inside `_onSurvivalWindowTick`, bypassing Crafting's own C.16 `_clock()` seam — a GDD-mandated rule (R4-4) this ADR itself is supposed to implement for, and the same bug class already caught once in ADR-0005 (still unfixed there). Fixed by adding a `CraftingService._clock` seam field and routing the elapsed-time read through it.
- **Both loops must remain yield-free within their per-tick bodies** — the bench proximity scan iterates all benches and all squad members each 5Hz pass; if that scan is ever implemented with a yielding call inside the loop (e.g., an accidental `task.wait` or a yielding RemoteEvent call), it would stall the entire Heartbeat callback for both loops sharing this connection. **Mitigation**: code review should treat any yielding call inside either `_onSurvivalWindowTick` or `_onBenchWatcherTick` as a blocking finding.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| crafting-and-items.md | C.9 survival-window end via per-Heartbeat `_clock()` comparison, never `task.delay`; single `_step` Heartbeat connection bound at RunStarted (B5); E.13/G.5 bench proximity watcher at `SENSOR_CHECK_HZ=5` matching ED's `FIELD_UPDATE_HZ` | Both requirements directly implemented in the Decision section |

## Performance Implications
- **CPU**: Survival-window check is a single timestamp subtraction and comparison per Heartbeat frame — negligible. Bench watcher runs its actual scan only at 5Hz (not 60Hz), bounded by bench count × squad size (small numbers in this MVP's scope).
- **Memory**: One timestamp + one boolean per active window; one accumulator + one last-known-count per bench.
- **Load Time**: None.
- **Network**: Bench occupancy changes are change-gated (not every 5Hz tick), already accounted for in ADR-0008's aggregate bandwidth budget for Crafting's signals.

## Migration Plan
No migration — neither loop is implemented yet.

## Validation Criteria
- Unit test: a simulated squad wipe mid-window results in the survival-window tick becoming a permanent no-op (via the idempotency latch), with no stray win condition firing afterward.
- Unit test: the bench watcher's occupancy-changed event fires only when the count actually changes, not on every 5Hz tick.
- Unit test: the bench watcher's effective check rate matches 5Hz regardless of whether the underlying Heartbeat runs at 30fps, 60fps, or 144fps.

## Related Decisions
- Depends on ADR-0001 (KnitInit/KnitStart Ordering Discipline).
- Mirrors the tick-loop pattern established in ADR-0010 (Resource Management Tick Loop) and the accumulator pattern established in ADR-0004 (DisturbanceService Core Architecture).
- `design/gdd/crafting-and-items.md` C.9, E.13, G.5.
