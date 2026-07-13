# ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) |
| **Domain** | Networking (RemoteEvent/RemoteFunction trust boundary) |
| **Knowledge Risk** | LOW — server validation of client-fired RemoteEvents is a long-standing, well-documented Roblox pattern (FilteringEnabled is mandatory and long-standing per `breaking-changes.md`); nothing in this ADR depends on a post-cutoff API. |
| **References Consulted** | `design/gdd/game-concept.md` (the 11-surface concept-level enumeration), `design/gdd/player-controller.md` (C.9 — the fullest existing RemoteEvent surface table, already implementing this pattern per-event), `design/gdd/crafting-and-items.md` (C.15 receive-side surface), `docs/engine-reference/roblox/breaking-changes.md` ("FilteringEnabled is Mandatory"), `docs/engine-reference/roblox/deprecated-apis.md` (Networking table) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Implementation of every client-facing RemoteEvent across PC, Crafting, and RN. |
| **Blocks** | No epic is directly blocked, but PC's own GDD explicitly flagged this as "an ADR PC's own GDD could not close alone" (architecture.md Required ADRs #5) — PC's C.9 surface and Crafting's C.15 surface both currently describe per-event rules without a reconciled, project-wide registry. |
| **Ordering Note** | Independent of the other five remaining must-have ADRs; can be written and accepted in any order relative to them. |

## Context

### Problem Statement

`game-concept.md` already enumerates 11 concept-level RemoteEvent surfaces and states two cross-cutting principles ("server validates plausibility, not just legality" and "per-event rate limits + a per-player global RemoteEvent budget must both apply"), explicitly deferring the full registry and enforcement pattern to this ADR. Player Controller's own C.9 table already implements a consistent per-event shape (rate limit + burst cap + alive-guard + server-side re-derivation) across 6 client-fired events, but this pattern has never been named or made binding project-wide, and no project-wide *global* per-player budget (the second half of game-concept's own stated principle) has been specified anywhere. This ADR is the reconciliation PC's GDD explicitly asked for and the registry `game-concept.md` deferred.

### Constraints

- Every RemoteEvent is FilteringEnabled by default (Roblox platform default, long-standing) — this ADR does not change that, it specifies what server-side validation must exist on top of it.
- Must not contradict any already-approved GDD's specific per-event rate limits (PC's C.9, Crafting's C.15) — this ADR generalizes the pattern those tables already follow, it does not redesign their numbers.
- Must cover all 11 concept-level surfaces, reconciling each against its GDD-level name where one already exists.

### Requirements

- One canonical, named validation order every client-fired RemoteEvent handler follows, so new events don't reinvent (or subtly under-implement) the pattern PC's own GDD already uses correctly.
- A concrete per-player global RemoteEvent budget, defending against the exact bypass game-concept.md names ("a misbehaving client can spam multiple low-rate-limited events to bypass per-event caps").
- A reconciled registry mapping all 11 concept-level surfaces to their GDD-level implementations (or explicit "server-pushed only, no client path" status).

## Decision

### Canonical validation order (binding on every client-fired RemoteEvent)

Every client→server RemoteEvent handler MUST evaluate checks in this exact order, matching the "drop-first ordering" pattern PC's own C.9 already uses for `RequestSprintToggle`/`RequestLanternToggle`/`PlayerHeartbeat` (its own I1 parity rule), generalized here as the project-wide standard:

1. **Alive/state guard** — reject if the calling player is in a state that cannot legitimately fire this event (e.g., dead/S4/S5 for most gameplay events), evaluated FIRST, before any other check touches state.
2. **Rate limit + burst cap** — the per-event sustained rate (e.g., "2/s") AND a burst cap over a short window (e.g., "4 per 2.0 s") both apply; excess is dropped silently (no error response to the client — silence gives an attacker no oracle to tune against).
3. **Per-player global RemoteEvent budget** (NEW, project-wide, this ADR) — see below.
4. **Payload shape validation** — reject non-conforming payloads (wrong type, out-of-enum values, non-integer where an integer is required) before any semantic interpretation of the payload.
5. **Server-side plausibility re-derivation** — never trust a client-supplied id, position, or distance claim; re-derive from server-tracked state (e.g., a `nodeId` must resolve to an existing, live node the server itself tracks; a proximity claim is re-checked against the server's own `HumanoidRootPart.Position`, never the client's).
6. **Deep/domain validation** — owned by the receiving service (e.g., Crafting's C.15 owns recipe/inventory validation for `RequestCraft`; Resource Node owns depletion/yield validation for `RequestGather`'s receive side). This ADR's job stops at step 5; step 6 is each domain service's own responsibility, already specified in its own GDD.

**Critical ordering rule (matching PC's own I1 parity)**: a dropped event (steps 1–4) MUST NOT mutate any state, including cooldown/grace-timer anchors — a flood of rejected events must not be usable to perturb a legitimate cooldown window by its side effects alone.

### Per-player global RemoteEvent budget (closes game-concept's own named gap)

**Decision**: in addition to every event's own per-event rate limit, each player has a **global budget of 30 accepted RemoteEvent fires per second**, summed across ALL client-fired events. This is deliberately set well above the sum of all current per-event limits at their busiest legitimate combination (`RequestSprintToggle` 10/s + `RequestLanternToggle` 5/s + `RequestPing` ~1/s + `RequestEmote` ~0.33/s + `RequestGather`/`RequestInteract` 2/s each + `PlayerHeartbeat` 1/s ≈ 21.3/s worst-case legitimate combination), so it never throttles legitimate play, but caps the theoretical maximum an attacker could achieve by combining many low-limit events simultaneously to probe for a per-event-limit gap. Implemented as a single per-player **tumbling** (hard-reset-every-1.0s) window counter, not a true sliding window — this permits up to ~2× burst near a window boundary (e.g., a client firing just before and just after the reset), which is an accepted, still-bounded trade-off, not an exploit-tuning oracle. Checked after the per-event rate limit (step 3), incremented only on events that pass steps 1–2 (a per-event-rejected event should not also consume global budget, since it never had a chance to do anything).

**Scope note**: this 6-step pattern, including the silent-drop-on-reject convention, applies to fire-and-forget `RemoteEvent`s only. This project has no `RemoteFunction` surface today (all current events are `RemoteEvent`s, consistent with `deprecated-apis.md`'s "RemoteFunction for fire-and-forget → use RemoteEvent" guidance). If a future domain ever needs a `RemoteFunction` (a synchronous call requiring a return value), it MUST NOT reuse the silent-drop convention as-is — an un-returned `RemoteFunction` invocation leaves the calling client's coroutine yielded indefinitely. Any future `RemoteFunction` must always return a value on every path, including rejection (e.g., an explicit `false`/error-code return), never a silent drop.

### Reconciled surface registry (game-concept's 11 items → GDD-level implementation)

| # | Concept-level surface | GDD-level event(s) | Status |
|---|---|---|---|
| 1 | Gather request | `RequestGather` (PC C.9) | Implemented in PC; receive-side deep validation in the unauthored Resource Node GDD (registered, per PC's own note) |
| 2 | Craft request | `RequestCraft` (Crafting C.15) | Implemented in Crafting |
| 3 | Beacon activation | `RequestBeaconActivate` (Crafting C.15) | Implemented in Crafting |
| 4 | Ping | `RequestPing` (PC C.9) | Implemented in PC |
| 5 | Emote | `RequestEmote` (PC C.9) | Implemented in PC |
| 6 | Cosmetic purchase | `MarketplaceService:ProcessReceipt` callback | Deferred to ADR-0007 (Save/Load & Cosmetic Persistence) — this ADR only confirms it is NOT a RemoteEvent and is out of this ADR's scope |
| 7 | Respawn / character-ready handshake | `OnPlayerRespawned` (PC C.9, currently server-pushed only) | Server-pushed only — no client-initiated respawn RemoteEvent exists; respawn is server-timed (`RESPAWN_DELAY`, ADR-0005). **No client path required or permitted.** |
| 8 | Squad join/leave | (no dedicated event — Roblox `Players.PlayerAdded`/`PlayerRemoving` are the underlying signals) | Server-pushed only, per game-concept's own note — confirmed, no client-initiated squad-membership RemoteEvent should ever exist |
| 9 | AFK kick signal | (not yet named in any GDD) | Server→client only, per game-concept's own note — flagged as an Open Question below since no GDD currently specifies this event's name or trigger condition |
| 10 | Death confirmation | `OnPlayerDied` (PC C.9, server-pushed) | Server-pushed only — confirmed no client can fire its own death; the sole trigger is ED's `Humanoid.Died` monopoly (ADR-0004) |
| 11 | Disturbance overlay / flora chunk subscription | `FloraChunkInitialSnapshot`/`FloraChunkUpdate` (ED, raw RemoteEvents) | Server-pushed only, N5 (ADR-0004) already mandates zero `OnServerEvent` registration — this ADR's registry confirms this surface is closed the same way as #7/#8/#10 |

**Generalized rule for all server-pushed-only surfaces (#7, #8, #9, #10, #11)**: the underlying `RemoteEvent` object registers **zero `OnServerEvent` callbacks** — this is the same invariant ADR-0004's N5 established for the flora-chunk surfaces specifically, generalized here as the binding rule for every server-pushed-only surface in the project, not just ED's. A future static lint (in the spirit of ED's own H.39e) could mechanically enforce this across all such RemoteEvents at once; optional hardening, not required for this ADR's closure.

### Architecture Diagram

```
Client fires RequestX(payload)
        │
        ▼
1. Alive/state guard ────────────────► FAIL → silent drop, no state mutation
        │ PASS
        ▼
2. Per-event rate limit + burst cap ──► FAIL → silent drop, no state mutation
        │ PASS
        ▼
3. Global per-player budget (30/s) ───► FAIL → silent drop, no state mutation
        │ PASS
        ▼
4. Payload shape validation ──────────► FAIL → silent drop, no state mutation
        │ PASS
        ▼
5. Server-side plausibility re-derivation (never trust client id/position) ──► FAIL → silent drop
        │ PASS
        ▼
6. Deep/domain validation (owned by the receiving service's own GDD)
        │ PASS
        ▼
   Effect applied (state mutation, disturbance emission, etc.)


Server-pushed-only surfaces (#7 respawn, #8 squad join/leave, #9 AFK kick,
#10 death, #11 flora chunk): ZERO OnServerEvent registrations — a client
firing these RemoteEvents has no server-side listener to reach at all.
```

### Key Interfaces

```luau
--!strict
-- Project-wide global per-player RemoteEvent budget (step 3), checked by a shared
-- helper every client-fired-event handler calls after its own per-event rate limit.

local GLOBAL_REMOTE_EVENT_BUDGET_PER_SEC = 30
local _globalEventCounts: {[Player]: {count: number, windowStart: number}} = {}

local function checkGlobalBudget(player: Player): boolean
    local now = workspace:GetServerTimeNow()
    local record = _globalEventCounts[player]
    if not record or (now - record.windowStart) >= 1.0 then
        record = {count = 0, windowStart = now}
        _globalEventCounts[player] = record
    end
    if record.count >= GLOBAL_REMOTE_EVENT_BUDGET_PER_SEC then
        return false  -- over budget, drop
    end
    record.count += 1
    return true
end

-- Cleanup: without this, _globalEventCounts holds a stale Player-keyed record
-- per departed player for the life of the server (engine-specialist review 2026-07-06).
Players.PlayerRemoving:Connect(function(player: Player)
    _globalEventCounts[player] = nil
end)

-- Example handler shape, matching the canonical 6-step order:
someRemoteEvent.OnServerEvent:Connect(function(player: Player, payload: any)
    if not isAliveAndEligible(player) then return end               -- (1)
    if not checkPerEventRateLimit(player) then return end            -- (2)
    if not checkGlobalBudget(player) then return end                 -- (3)
    if not isValidPayloadShape(payload) then return end               -- (4)
    if not reDeriveAgainstServerState(player, payload) then return end -- (5)
    -- (6) deep/domain validation + effect: owned by the receiving service
end)
```

## Alternatives Considered

### Alternative 1: Per-event rate limits only, no global budget
- **Description**: Rely solely on each event's own rate limit + burst cap, as PC's C.9 currently does, without a project-wide global budget.
- **Pros**: Simpler — one fewer check per event.
- **Cons**: Directly leaves open the exact bypass `game-concept.md` itself names: "a misbehaving client can spam multiple low-rate-limited events to bypass per-event caps" — e.g., alternating between 6 different events each individually under its own limit could still produce a high aggregate fire rate against the server.
- **Rejection Reason**: `game-concept.md` already identified this gap explicitly and required both layers; omitting the global budget would leave a concept-level requirement unimplemented.

### Alternative 2: Per-event error responses instead of silent drops
- **Description**: When a check fails, send the client an explicit rejection response (e.g., a RemoteFunction return or a dedicated `OnRequestRejected` event) so the client UI can show immediate feedback.
- **Pros**: Better client-side UX feedback for legitimate players who hit a rate limit accidentally.
- **Cons**: Gives an attacker a clean oracle to binary-search the exact rate-limit/budget thresholds, and adds a new server→client surface that itself needs trust-boundary review; PC's own C.9 already establishes the silent-drop convention for its 6 existing events, and changing it here would be inconsistent with already-approved behavior.
- **Rejection Reason**: Security cost (exploit-tuning oracle) outweighs the UX benefit; PC's existing convention is silent-drop and this ADR should not introduce an inconsistent pattern for other events.

## Consequences

### Positive
- All 11 concept-level surfaces are now reconciled against their GDD-level implementation (or explicitly confirmed as having none, correctly).
- The global per-player budget closes the exact multi-event-bypass gap `game-concept.md` itself named as a requirement.
- The 6-step canonical order gives every future RemoteEvent (Save/Load's cosmetic purchase flow aside, which uses a different transport) one pattern to implement against, rather than each system re-deriving its own order.

### Negative
- The global budget (30/s) is a new per-player counter that must be threaded through every event handler — a small implementation tax on every RemoteEvent, existing and future.

### Risks
- **Engine-specialist review (2026-07-06) fixes**: the global budget was mislabeled a "sliding-window counter" when the code is actually a tumbling (hard-reset) window — corrected in the Decision text and flagged as an accepted ~2× boundary-burst trade-off, not a true sliding window; the silent-drop convention was stated in universal terms with no carve-out for a future `RemoteFunction`, risking a permanently-yielded client coroutine if ever copied verbatim for a synchronous call — a Scope Note now restricts silent-drop to fire-and-forget `RemoteEvent`s and mandates any future `RemoteFunction` always return a value; the `Key Interfaces` code lacked the `PlayerRemoving` cleanup its own Performance section promised — added.
- **The 30/s global budget figure is a first estimate**, derived from summing current per-event limits at their busiest legitimate combination (~21.3/s) with headroom. If a future GDD adds a new high-frequency client event, this number should be re-derived, not left stale. **Mitigation**: flagged here explicitly so a future architecture-review pass re-checks this sum against the actual event list at that time.
- **The AFK kick signal (#9) has no GDD-level specification yet** — this ADR cannot close its trust-boundary status beyond "server-pushed only," since no GDD names the event or its trigger condition. **Mitigation**: flagged as an Open Question below.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| game-concept.md | The 11-surface concept-level enumeration; "per-event rate limits + per-player global budget must both apply" | All 11 surfaces reconciled in the registry table; the global budget is authored here for the first time |
| player-controller.md | C.9's RemoteEvent surface, already implementing the 6-step order per-event without it being named project-wide | Generalizes PC's own existing pattern as the binding project-wide standard, changing no PC numbers |
| crafting-and-items.md | C.15 receive-side surface (`RequestCraft`, `RequestBeaconActivate`) | Confirmed as items #2/#3 in the reconciled registry |

## Performance Implications
- **CPU**: Negligible — one additional table lookup + counter increment per accepted RemoteEvent fire (the global budget check).
- **Memory**: One small record per connected player (`{count, windowStart}`), cleared on `PlayerRemoving`.
- **Load Time**: None.
- **Network**: This ADR bounds, rather than adds, network surface — the < 50 KB/s advisory ceiling (`technical-preferences.md`) is unaffected by the budget check itself (which runs server-side and rejects before any broadcast).

## Migration Plan
No migration — none of PC's or Crafting's RemoteEvent handlers are implemented yet; this ADR is the pattern they're written against from the start.

## Validation Criteria
- Unit test: a simulated client firing 6 different under-their-own-limit events in rapid alternation is capped by the global budget once the sum exceeds 30/s.
- Unit test: a rejected event (any of steps 1–4) confirmed to leave no observable state mutation (cooldown anchors, grace timers unchanged).
- Code review checklist item: every new RemoteEvent handler is checked against the 6-step canonical order before merge.

## Related Decisions
- Depends conceptually on ADR-0004's N5 (server-pushed-only surfaces must register zero `OnServerEvent` callbacks) — generalized here project-wide.
- `design/gdd/game-concept.md` (the 11-surface enumeration this ADR closes), `design/gdd/player-controller.md` C.9, `design/gdd/crafting-and-items.md` C.15.

## Open Questions
- **AFK kick signal (#9)**: no GDD currently names this event, its trigger condition (idle duration threshold), or its payload. This ADR confirms it must be server→client only if/when authored, but does not itself specify it — flagged for whichever GDD (likely Player Controller or a future Session Management doc) ends up owning AFK detection.
