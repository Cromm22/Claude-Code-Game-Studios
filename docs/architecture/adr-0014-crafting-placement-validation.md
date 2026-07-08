# ADR-0014: Crafting Bench/Beacon Placement Validation

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) |
| **Domain** | Core (server-side geometry validation) + Networking (trust boundary, ADR-0006's step-5 instance) |
| **Knowledge Risk** | LOW — `Workspace:Raycast()` and `RaycastParams` are long-standing, well-documented Roblox APIs; nothing in this ADR depends on a post-cutoff feature. |
| **References Consulted** | `design/gdd/crafting-and-items.md` (C.15 placement validation order, F.4's flagged "Placement Validation" ADR), ADR-0006 (RemoteEvent Trust Boundary — this ADR is the concrete worked example of its step-5 "server-side plausibility re-derivation" principle), ADR-0008 (Character Replication Bandwidth & NetworkOwnership — the same "never trust client position" principle this ADR applies to placement) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0006 (RemoteEvent Trust Boundary & Rate-Limiting) — this ADR is a domain-specific (step-6) elaboration of that ADR's step-5 principle, applied to bench/beacon placement specifically. |
| **Enables** | Crafting & Items epic — the fourth of Crafting's own four self-flagged, previously-unauthored ADRs. |
| **Blocks** | No other ADR, but Crafting's `RequestBeaconPlace` (and any future placeable-item) Logic stories depend on this ADR. |
| **Ordering Note** | Independent of ADR-0013 — the two Crafting ADRs can be Accepted in either order. |

## Context

### Problem Statement

Crafting's own GDD (C.15) already specifies a 4-step placement validation order
for player-placed objects (the escape beacon, and any future placeable) — clamp,
line-of-sight raycast, floor raycast, overlap check — and already states the
principle that "client position is a direction hint, never a trusted coordinate."
But this was never formalized as its own ADR, despite Crafting's own F.4 flagging
it as needed, leaving the exact `RaycastParams` configuration and validation
ordering undecided at the architecture level.

### Constraints

- Per ADR-0006's step 5 (server-side plausibility re-derivation), the client's
  proposed placement position must never be trusted as the final placement
  coordinate — it is used only as a hint for which direction/area the player is
  aiming at; the server re-derives the actual placement geometry independently.
- Must reject placements that would be inside geometry, floating, or without
  line-of-sight from the placing player — in that specific order, since each
  check is progressively more expensive (clamp is free; LOS raycast is one ray;
  floor raycast is a second ray; overlap check queries a region) and rejecting
  early on a cheap check avoids paying for expensive checks on an already-invalid request.
- Must use `RaycastParams` with an explicit filter (not an empty/default filter),
  since a default raycast would hit the placing player's own character or other
  non-terrain instances, producing false rejections or false approvals.

### Requirements

- A single, ordered validation pipeline for any player-placed object: clamp →
  LOS raycast → floor raycast → overlap check, short-circuiting on the first failure.
- `RaycastParams` configured to filter out the placing player's own character
  and any other players' characters, so the LOS/floor rays only interact with
  world geometry.
- The final placement transform is entirely server-computed from the raycast
  results, never the client-supplied coordinate verbatim.

## Decision

**A single server-side function, `CraftingService:_validateAndResolvePlacement(player, clientHintPosition, placementType)`,**
implementing the 4-step order Crafting's own GDD already specifies, with each
step's `RaycastParams` explicitly configured:

1. **Clamp**: the client-supplied `clientHintPosition` is clamped to a maximum
   distance from the player's own server-tracked `HumanoidRootPart.Position`
   (a "reach" radius) — this is the cheapest check and rejects wildly
   implausible hints (e.g., a spoofed coordinate across the map) before any
   raycast is spent on them.
2. **LOS raycast**: a single ray from the player's server-tracked position
   toward the clamped hint position, using a `RaycastParams` filter set to
   `FilterType = Enum.RaycastFilterType.Exclude` with `FilterDescendantsInstances`
   containing every player's character in the current squad (never an empty
   filter). If the ray hits any world geometry before reaching the hint
   position, the placement is rejected — the player cannot see the spot they're
   trying to place at.
3. **Floor raycast**: a second ray, straight down, using the same
   character-excluding filter, to find the actual floor `Y` coordinate beneath
   the hint's `X`/`Z`. This is what determines the real placement `Y` — the
   client's hint `Y` is discarded entirely from the final transform; only the
   client's `X`/`Z` (already clamped and LOS-validated) survive into it.
   **The ray's own origin height must be derived from the placing player's own
   server-tracked position (`playerPos.Y + margin`), never from the client's
   hint `Y`** (engine-specialist review 2026-07-06): on a multi-story structure,
   a client-supplied hint `Y` on a different floor than the player could
   otherwise cause the ray to originate at the wrong level entirely and
   miss the correct floor, or hit the wrong one.
4. **Overlap check**: a region query (`Workspace:GetPartBoundsInBox` or
   equivalent) at the resolved floor position, checking for existing
   placed-object overlap (e.g., a second beacon too close to an existing one,
   or overlapping world geometry) — the most expensive check, run last since
   the first three checks have already eliminated most invalid requests.

If all four steps pass, the resolved placement transform (never the client's
original coordinate) is what actually gets used to instantiate the placed object.

### Architecture Diagram

```
RequestBeaconPlace(clientHintPosition)  -- client sends a DIRECTION HINT, not a trusted coordinate
        │
        ▼ (ADR-0006 steps 1-4 already passed: alive-guard, rate-limit, budget, payload shape)
1. CLAMP: hintPos clamped to maxReachRadius from player's server-tracked position
        │ (cheapest check — rejects wildly implausible hints first)
        ▼
2. LOS RAYCAST: ray from player position -> clamped hint, RaycastParams excludes
   all player characters. Blocked? -> REJECT (no LOS).
        │ PASS
        ▼
3. FLOOR RAYCAST: ray straight down from the LOS-validated XZ, same filter.
   No hit? -> REJECT (no floor beneath). Hit found -> this Y is the REAL
   placement Y (client's Y is discarded entirely here).
        │ PASS
        ▼
4. OVERLAP CHECK: region query at the resolved position. Overlaps existing
   placement or geometry? -> REJECT.
        │ PASS
        ▼
   Instantiate the placed object at the SERVER-RESOLVED transform
   (clamped XZ + floor-raycast Y) — the client's original coordinate is
   never used directly.
```

### Key Interfaces

```luau
--!strict
local MAX_PLACEMENT_REACH = 10  -- studs, tunable per placement type

function CraftingService:_validateAndResolvePlacement(
    player: Player,
    clientHintPosition: Vector3,
    placementType: string
): (boolean, Vector3?)
    local playerPos = self:_getServerTrackedPosition(player)

    -- Step 1: clamp
    local delta = clientHintPosition - playerPos
    local clampedDelta = if delta.Magnitude > MAX_PLACEMENT_REACH
        then delta.Unit * MAX_PLACEMENT_REACH
        else delta
    local clampedHint = playerPos + clampedDelta

    -- Filter excludes every squad member's character — never an empty filter.
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = self:_getAllSquadCharacters()

    -- Step 2: LOS raycast
    local losResult = workspace:Raycast(playerPos, clampedHint - playerPos, params)
    if losResult then
        return false, nil  -- blocked line of sight
    end

    -- Step 3: floor raycast (Y is entirely server-resolved from here).
    -- Origin height derives from the PLAYER's own tracked Y, not clampedHint.Y
    -- (engine-specialist review 2026-07-06 — see Decision section note: using
    -- clampedHint.Y as the ray-origin height risks originating on the wrong
    -- floor of a multi-story structure if the client's hint Y differs from
    -- the player's actual level).
    local floorRayOrigin = Vector3.new(clampedHint.X, playerPos.Y + 50, clampedHint.Z)
    local floorResult = workspace:Raycast(
        floorRayOrigin,
        Vector3.new(0, -100, 0),
        params
    )
    if not floorResult then
        return false, nil  -- no floor beneath
    end
    local resolvedPosition = Vector3.new(clampedHint.X, floorResult.Position.Y, clampedHint.Z)

    -- Step 4: overlap check (most expensive — run last)
    if self:_hasOverlappingPlacement(resolvedPosition, placementType) then
        return false, nil
    end

    return true, resolvedPosition
end
```

## Alternatives Considered

### Alternative 1: Trust the client's `Y` coordinate, only re-derive `X`/`Z`
- **Description**: Accept the client-supplied `Y` value as-is (assuming the client's own raycast against its locally-rendered geometry already found a valid floor), only clamping/re-deriving the horizontal position.
- **Pros**: Slightly less server-side raycast work (one fewer ray).
- **Cons**: A client's local geometry state is not guaranteed to match the server's — exploiting this gap (e.g., a modified client reporting a `Y` value that places the beacon inside or above terrain the server would never have resolved to) is exactly the class of attack ADR-0006's "never trust a client-supplied position" principle exists to prevent. There is no gameplay reason to trust `Y` specifically while distrusting `X`/`Z`.
- **Rejection Reason**: Directly contradicts ADR-0006's own trust-boundary principle for no performance benefit worth the risk.

### Alternative 2: Overlap check first, geometry checks last
- **Description**: Run the (expensive) overlap region-query first, since it's the check most likely to reject an obviously-bad placement (e.g., trying to place inside an existing beacon).
- **Pros**: None identified — this ordering has no advantage over cheapest-first.
- **Cons**: Runs the most expensive check on every request, including the wildly-implausible ones the cheap clamp check alone would have rejected — wasted server work under a hostile client sending many bad requests, which the RemoteEvent trust boundary's own rate limits don't fully prevent within the allowed rate.
- **Rejection Reason**: Cheapest-check-first is a strictly better ordering with no downside; there's no reason to pay for the most expensive check before the cheap ones have already filtered out most invalid requests.

## Consequences

### Positive
- Closes the fourth and final of Crafting's own self-flagged, previously-unauthored ADRs.
- The explicit character-excluding `RaycastParams` filter prevents a whole class of false-reject/false-approve bugs that an empty-filter raycast would silently introduce.
- Cheapest-check-first ordering minimizes wasted server work under both legitimate and hostile request volume.

### Negative
- Four sequential checks (one of them a region query) add a small but real per-placement-request server cost — acceptable since placement requests are rare (a handful per run, not a per-frame concern), unlike RM's tick loop or ED's field update.

### Risks
- **Engine-specialist review (2026-07-06) fixes, folded in**: (1) confirmed `Workspace:Raycast()` + Exclude-type `RaycastParams` and `Workspace:GetPartBoundsInBox` are both current, correctly-named APIs at the pinned engine version. (2) Found a real bug — the floor raycast's origin height was derived from `clampedHint.Y` (which still carries client-influenced data from the 3D clamp), risking the ray originating on the wrong floor of a multi-story structure; fixed by deriving the origin height from the player's own server-tracked `playerPos.Y` instead (see the Decision section and Key Interfaces above). (3) `_getAllSquadCharacters()` must filter out `nil`/dead-player entries before returning — a squad member with no live `Character` (dead, not yet spawned) would otherwise insert a `nil` into `FilterDescendantsInstances`, which expects a clean `{Instance}` array and would error or silently misfilter; the helper implementation must exclude such entries.
- **An empty or misconfigured `RaycastParams.FilterDescendantsInstances` would silently break both the LOS and floor raycasts** (rays would hit player characters instead of world geometry) — this is the single most likely implementation mistake for this ADR. **Mitigation**: code review should explicitly check that the filter list is populated with all squad characters, not left as `RaycastParams.new()`'s default empty filter.
- **`MAX_PLACEMENT_REACH`'s specific value is a placeholder** in this ADR — the actual tunable distance depends on Crafting's own bench/beacon placement UX (how far a player can reasonably place an object relative to their own position), which is a GDD-level tuning decision, not an architecture decision. Flagged as an Open Question below.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| crafting-and-items.md | C.15 — 4-step placement validation order (clamp → LOS raycast → floor raycast → overlap); client position is a "direction hint," never a trusted coordinate | All four steps directly implemented in the Decision section, with the client-position-as-hint-only principle enforced by discarding the client's `Y` entirely at step 3 |

## Performance Implications
- **CPU**: Two raycasts + one region query per placement request — negligible given placement requests occur only a handful of times per run (beacon placement is a rare, deliberate action, not a per-frame or per-tick operation).
- **Memory**: None beyond the transient `RaycastParams` object per call.
- **Load Time**: None.
- **Network**: None beyond the existing `RequestBeaconPlace` RemoteEvent already covered by ADR-0006's bandwidth accounting.

## Migration Plan
No migration — placement validation is not implemented yet.

## Validation Criteria
- Unit test: a client-supplied position beyond `MAX_PLACEMENT_REACH` is clamped, not rejected outright (the clamp is a correction, not a rejection — only the subsequent LOS/floor/overlap checks can reject).
- Unit test: a raycast that hits a squad member's own character (not world geometry) is not treated as a LOS-blocking hit, confirming the filter is correctly excluding characters.
- Unit test: the final placed object's `Y` coordinate always matches the floor-raycast result, never the client's originally-supplied `Y`.
- Unit test: an overlap with an existing placed object of the same type is rejected at step 4.

## Related Decisions
- Depends on ADR-0006 (RemoteEvent Trust Boundary & Rate-Limiting).
- `design/gdd/crafting-and-items.md` C.15.

## Open Questions
- **`MAX_PLACEMENT_REACH`'s exact tunable value** is not specified by this ADR — it is a GDD-level tuning decision (how far a player can place an object relative to their own position) that should be resolved during Crafting's implementation or in the GDD itself, not guessed at here.
