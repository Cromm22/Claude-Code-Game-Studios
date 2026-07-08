# ADR-0009: Resource Management Beacon-Charge-Tier Accessor

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + Knit framework |
| **Domain** | Core (cross-service read contract) |
| **Knowledge Risk** | LOW — this ADR introduces no new Roblox engine API; it is a Knit service-to-service accessor contract, governed by patterns already established in ADR-0001/ADR-0004. |
| **References Consulted** | `design/gdd/resource-management.md` (CR.2, Interactions, H.21, H.41), `docs/architecture/architecture.md` (Module Ownership — Crafting & Items row: "Beacon lifecycle (BC1-6)"), ADR-0001 (KnitInit/KnitStart Ordering Discipline), ADR-0004 (DisturbanceService Core Architecture, the sibling accessor pattern this ADR mirrors) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond what ADR-0001 already requires (KnitInit-time construction of the accessor). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (KnitInit/KnitStart Ordering Discipline) — the accessor method must be callable from RM's own tick loop regardless of KnitStart ordering between RM and Crafting. |
| **Enables** | Resource Management epic (`production/epics/resource-management/EPIC.md`) — this was the single hardest blocking gap found by the 2026-07-06 `/architecture-review`; RM's per-tick drain rate cannot be implemented without it. |
| **Blocks** | No other ADR directly, but the Resource Management epic's Logic stories for drain-rate calculation cannot start without this ADR Accepted. |
| **Ordering Note** | Should be Accepted alongside or after ADR-0010 (Resource Management Tick Loop), since the tick loop is what calls this accessor each Heartbeat. |

## Context

### Problem Statement

Resource Management's own GDD (CR.2) requires RM to read "the current Beacon
Charge Tier" each tick to select its oxygen drain rate, describing the source as
"the ED/Beacon escalation authority" — language ambiguous enough that this
session's `/architecture-review` initially assumed the accessor belonged on
`DisturbanceService` (ADR-0004), which does not expose one. Re-examining
`architecture.md`'s own Module Ownership table resolves the ambiguity: **Beacon
lifecycle (stages BC1 through BC6) is explicitly owned by Crafting & Items
(`CraftingService`)**, not Ecological Disturbance. RM's drain-rate bands (BC1-4)
are a coarser, drain-relevant projection of Crafting's full BC1-6 lifecycle, not
a separate piece of state — no second source of truth should exist for "what
stage is the beacon at." This ADR fixes the owner and defines the read contract.

### Constraints

- Must not create a second, competing definition of "beacon stage" — Crafting's
  own BC1-6 lifecycle (bench build → activation → charging → hold-window →
  survived/failed) is already the authoritative state machine; RM must project
  from it, not duplicate it.
- Must comply with ADR-0001: the accessor must be constructed/available from
  Crafting's `KnitInit`, since RM's tick loop may call it before Crafting's own
  `KnitStart` has run.
- Must not require RM to know Crafting's internal BC1-6 stage count or names —
  RM only needs a drain-relevant tier number, insulating RM from future changes
  to Crafting's own lifecycle granularity.
- Fail-safe: per RM's own H.41, if the accessor is ever unavailable (e.g., a
  boot-order edge case), RM must default to BC1 (slowest drain) for that tick
  and log — never error, never stall the tick.

### Requirements

- A single, server-internal, read-only accessor method on `CraftingService`
  that RM's tick loop calls once per Heartbeat.
- The returned value must be a drain-relevant tier (1-4), computed by Crafting
  from its own internal BC1-6 state — Crafting owns the mapping.
- The accessor must never yield (RM's tick loop is itself yield-sensitive per
  ADR-0010) and must never throw.

## Decision

**`CraftingService:GetCurrentBeaconChargeTier(): number`** — a plain, server-internal
Knit service method (never under `.Client`), returning an integer in `[1, 4]`.
Crafting owns the mapping from its internal BC1-6 lifecycle to this coarser
drain-tier value; RM treats the returned number as an opaque drain-tier index and
performs no interpretation of what "BC3" or "BC4" means internally to Crafting.

Before any beacon has been activated in the current run (Crafting's own BC1/BC2
pre-activation stages), the accessor returns `1` (the slowest/baseline drain
tier) — there is no "no beacon yet" special case RM needs to handle; tier 1 is
already the correct answer for "no escalation pressure yet."

The method is constructed to be safely callable from `KnitInit` onward: Crafting's
own `_beaconChargeTier: number` field is initialized to `1` inside `CraftingService:KnitInit()`
(per ADR-0001 Rule 1), so the accessor is always well-defined regardless of
KnitStart ordering between RM and Crafting.

### Architecture Diagram

```
CraftingService (owns Beacon lifecycle BC1-6)
    │
    │  KnitInit: self._beaconChargeTier = 1  (ADR-0001 Rule 1 — safe from t=0)
    │  Beacon lifecycle transitions (bench build -> activation -> charging ->
    │  hold-window -> survived/failed) update self._beaconChargeTier internally,
    │  mapped to the coarser [1,4] drain-relevant range Crafting alone defines.
    │
    ▼
function CraftingService:GetCurrentBeaconChargeTier(): number
    return self._beaconChargeTier  -- never yields, never throws
end
    │
    ▼
ResourceService's tick loop (ADR-0010), once per Heartbeat:
    local ok, tier = pcall(function()
        return Knit.GetService("CraftingService"):GetCurrentBeaconChargeTier()
    end)
    local drainTier = (ok and tier) or 1   -- H.41 fail-safe: default to BC1, log
    if not ok then
        warn("ResourceService: BCT accessor unavailable this tick, defaulting to BC1")
    end
```

### Key Interfaces

```luau
--!strict
-- CraftingService (owning side)
type CraftingServiceState = {
    _beaconChargeTier: number,
    -- ...other CraftingService fields
}

function CraftingService:KnitInit()
    -- REQUIRED by ADR-0001 Rule 1: initialized here so the accessor is
    -- well-defined the instant any other service might call it.
    -- NOTE (engine-specialist review 2026-07-06): type ascription (`: type`)
    -- is only valid on `local` declarations/parameters, not on a `self.field =`
    -- assignment — that would fail to compile under --!strict. The field's
    -- type is declared on CraftingServiceState above instead.
    self._beaconChargeTier = 1
end

function CraftingService:GetCurrentBeaconChargeTier(): number
    -- Server-internal only — deliberately NOT under .Client. Never yields.
    return self._beaconChargeTier
end

-- ResourceService (consuming side) — see ADR-0010 for the full tick loop;
-- this is the accessor-call shape ADR-0010's loop uses each Heartbeat.
local function readBeaconChargeTierSafely(): number
    local ok, tier = pcall(function()
        return Knit.GetService("CraftingService"):GetCurrentBeaconChargeTier()
    end)
    if ok and typeof(tier) == "number" and tier >= 1 and tier <= 4 then
        return tier
    end
    warn("ResourceService: BCT accessor unavailable or invalid this tick, defaulting to BC1 (H.41)")
    return 1
end
```

## Alternatives Considered

### Alternative 1: Beacon-tier state lives on DisturbanceService
- **Description**: Add `GetCurrentBeaconChargeTier()` to `DisturbanceService` (ADR-0004) instead, treating beacon escalation as an ecological-field concept.
- **Pros**: Matches RM's own ambiguous GDD phrasing ("the ED/Beacon escalation authority") at face value.
- **Cons**: Directly contradicts `architecture.md`'s own Module Ownership table, which places Beacon lifecycle under Crafting & Items, not Ecological Disturbance. Would create a second, ED-side beacon-stage tracking mechanism duplicating Crafting's own BC1-6 state machine — a state-ownership conflict, not a naming nitpick.
- **Rejection Reason**: Creates competing sources of truth for beacon stage; violates the project's own module ownership record.

### Alternative 2: RM computes its own drain-tier by subscribing to Crafting's beacon-stage change events
- **Description**: Instead of a pull-based accessor, RM subscribes to a Crafting-fired `OnBeaconStageChanged` event and caches the tier itself.
- **Pros**: Avoids a per-tick cross-service call.
- **Cons**: RM's own tick loop (ADR-0010) already runs every Heartbeat and reading one number is cheap — the event-subscription approach adds a second piece of state (RM's own cached copy) that could drift from Crafting's true value if an event is ever missed, which a pull-based accessor cannot do by construction.
- **Rejection Reason**: A pull accessor is simpler, cannot drift, and the per-tick cost is negligible (a plain field read, not a signal dispatch).

## Consequences

### Positive
- Resolves a real, previously-undecided ownership ambiguity (RM's own GDD text
  named two possible owners) using the project's own existing Module Ownership record.
- RM is fully insulated from Crafting's internal BC1-6 stage count or naming —
  Crafting can rename or restructure its own lifecycle stages without touching RM.
- The fail-safe (default to BC1, log, never stall) directly satisfies RM's own H.41 requirement.

### Negative
- Adds one more cross-service dependency to RM's tick loop (though RM already depends on Crafting per `systems-index.md`'s dependency map, so this is not a new coupling, just a concrete interface for an already-declared dependency).

### Risks
- **Engine-specialist review (2026-07-06) fix**: the Key Interfaces sample's `self._beaconChargeTier: number = 1` inline type ascription on a table-index assignment does not compile under `--!strict` (type ascription is only valid on `local` declarations/parameters) — fixed by declaring the field's type on a `CraftingServiceState` type alias instead and using a plain assignment.
- **Minor, non-blocking**: `Knit.GetService("CraftingService")` should be cached once in RM's own `KnitStart` (e.g. `self._craftingService = Knit.GetService("CraftingService")`) rather than re-resolved by string lookup inside the pcall every Heartbeat tick — a performance nicety, not a correctness issue.
- **`Knit.GetService("CraftingService")` call inside RM's tick loop must never yield** — if Crafting's method implementation is ever changed to do anything yielding (a DataStore call, a `task.wait`), it would stall RM's entire Heartbeat tick. **Mitigation**: this ADR's Decision section states the accessor must never yield; code review for `GetCurrentBeaconChargeTier`'s implementation should treat any yielding call inside it as a blocking finding.
- **If Crafting's own BC1-6-to-drain-tier mapping formula is later found to need re-tuning**, this ADR does not itself specify that formula (it is Crafting's own internal decision) — only the accessor contract. Flagged as an Open Question below.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| resource-management.md | CR.2 — per-band drain rate keyed to Beacon Charge Tier, read via a server-internal accessor, RM owns no band state; H.41 — fail-safe default to BC1 on accessor unavailability | Fixes the accessor's owner (Crafting, per `architecture.md`) and its exact signature; specifies the fail-safe behavior verbatim |
| crafting-and-items.md | Beacon lifecycle (BC1-6), already owned per `architecture.md`'s Module Ownership table | Crafting is confirmed as the authoritative owner; this ADR adds the read-only cross-service accessor Crafting must expose on top of its existing internal state |

## Performance Implications
- **CPU**: Negligible — one field read per Heartbeat tick (RM's own tick rate, ADR-0010), not a signal dispatch or DataStore call.
- **Memory**: None beyond one integer field already implicit in Crafting's beacon lifecycle tracking.
- **Load Time**: None.
- **Network**: None — this is a server-internal Knit call, not a RemoteEvent.

## Migration Plan
No migration — neither RM nor Crafting's beacon-tier tracking is implemented yet.

## Validation Criteria
- Unit test: `GetCurrentBeaconChargeTier()` returns `1` immediately after Crafting's `KnitInit`, before any beacon has been built.
- Unit test: RM's tick loop, given a mocked accessor that throws, falls back to drain-tier 1 and logs a warning, without stalling the tick.
- Integration test (once both services are implemented): activating a beacon in Crafting and progressing through its BC1-6 stages produces the expected drain-tier sequence on RM's side.

## Related Decisions
- Depends on ADR-0001 (KnitInit/KnitStart Ordering Discipline).
- Companion to ADR-0010 (Resource Management Tick Loop) — this accessor is called from that loop.
- `docs/architecture/architecture.md` — Module Ownership (Crafting & Items row, "Beacon lifecycle (BC1-6)").
- `design/gdd/resource-management.md` CR.2, H.41.

## Open Questions
- **Crafting's exact BC1-6 → drain-tier [1,4] mapping formula** is not specified by this ADR — it is Crafting's own internal decision, to be resolved during Crafting's implementation (or in a future Crafting Core Architecture ADR, if one is ever written). This ADR only fixes the accessor contract and the fail-safe behavior.
