# ADR-0004: DisturbanceService Core Architecture

## Status
Proposed

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + Knit framework |
| **Domain** | Core (spatial field simulation, event bus, StreamingEnabled integration) |
| **Knowledge Risk** | HIGH/MEDIUM — StreamingEnabled chunk-load detection (N1) and `require()`/`Signal`/`BindableEvent` dispatch semantics (already governed by ADR-0001) are both flagged HIGH in `docs/architecture/architecture.md`'s Engine Knowledge Gap Summary; the spatial-grid data-structure choice and Knit `RemoteSignal` method names (`:Fire`/`:FireAll`, corrected once already mid-design per the GDD's own history) are MEDIUM. |
| **References Consulted** | `docs/engine-reference/roblox/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md`, `design/gdd/ecological-disturbance.md` (C.1.x, D.1–D.7, G.5–G.7), `design/gdd/ecological-disturbance-forward-obligations.md` (N1–N11 — the ADR obligations this document is required to close), ADR-0001 (KnitInit/KnitStart Ordering Discipline, RegistrationHandshake pattern) |
| **Post-Cutoff APIs Used** | None chosen definitively — see N1 below, which is left as an explicit pre-implementation verification item rather than a guessed API name, per this project's own engine-reference verification workflow (`VERSION.md`: "WebSearch the API name + Roblox if you are uncertain"). |
| **Verification Required** | N1 (StreamingEnabled chunk-load detection API — see Decision), N3 (Knit `RemoteSignal:Fire` on a departed `Player` is a silent no-op — empirical Studio test required, not assumed from training data). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (KnitInit/KnitStart Ordering Discipline) — the ED↔PA RegistrationHandshake instance this ADR specifies is the concrete worked example of ADR-0001's Rule 2. |
| **Enables** | ADR-0005 (Death & Respawn Lifecycle) — depends on this ADR's `OnPlayerDied`/`GetDeathAttributionPayload` construction; the should-have-tier ADR #12 (Predator AI Locomotion & Pathfinding) consumes `GetHottestHotspot`. |
| **Blocks** | Ecological Disturbance is the sole cross-system event bus (Architecture Principle #2) — no other Core/Feature-layer service can be implemented against a stable contract until this ADR is Accepted. |
| **Ordering Note** | This is "the busiest module in the game" per `architecture.md`'s own Required ADRs table — every other system's correctness depends on getting this right once. Should be accepted before any Core/Feature-layer implementation begins. |

## Context

### Problem Statement

`ecological-disturbance.md` is explicit, in its own text, that "Production implementation lives in the future `DisturbanceService` ADR; this GDD specifies behaviour, not implementation" — and separately enumerates **eleven specific implementation obligations (N1–N11)** across the GDD and its forward-obligations tracker that it states "the ADR MUST specify." This ADR is that document: it fixes the spatial-grid data structure, the StreamingEnabled chunk-membership mechanism, the cap-eviction policy, and closes all eleven N-series obligations with a concrete decision each, so implementation can begin without re-deriving any of them from GDD prose alone.

### Constraints

- Must never trust any client-writable property or client-fired signal to gate server-authoritative state (`ReplicationFocus` is explicitly named and banned in the GDD itself, H.31b enforces this).
- Must support O(1)-ish spatial queries at up to `MAX_LIVE_SOURCES = 500` sources, with `GetHottestHotspot` typically touching only 4–9 grid cells per query (GDD's own stated implementation note).
- Must comply with ADR-0001 (KnitInit-time construction of the `OnPlayerDied` BindableEvent-equivalent and the RegistrationHandshake module).
- Must not introduce a new decision that could contradict the frozen `GetSquadAggregateT(excludePlayer)` / `GetOnPlayerDiedSignal()` / `GetHottestHotspot` public contracts already relied on by Predator AI's approved GDD.

### Requirements

- One spatial data structure serving both the field-value query path (`GetHottestHotspot`, `fieldValue()`) and the live-source list's decay/cull pass.
- A StreamingEnabled chunk-membership mechanism that is provably never influenced by any client-driven signal.
- Closure of all eleven N-series obligations (N1–N11) with a specific, implementable decision each — not a restatement of the GDD's already-stated requirement.

## Decision

### Spatial data structure

**A plain Luau table-of-tables spatial hash grid, keyed by integer cell coordinates** (`grid[cellX][cellZ] = {sourceId, sourceId, ...}`), cell size `SPATIAL_GRID_CELL_SIZE = 32` studs (C.1.6). **`Region3` is explicitly rejected** — it is a `Workspace`/physics-query primitive (`WorkspacePartBoundsInBox`-class APIs), not a custom spatial-hash container, and would route every query through the physics engine for a purely data-structural problem this project's sources aren't even physical Instances for. A live source's cell is computed once at emission time (`cellX = floor(position.X / 32)`, `cellZ = floor(position.Z / 32)`) and only recomputed if a source's position field is later mutated (sources are otherwise immutable once emitted — position does not change post-emission per the GDD's own model). `GetHottestHotspot`'s and `fieldValue()`'s cell-radius scan (C.1.6's "4–9 cells" note) iterates `grid[cellX ± 1][cellZ ± 1]` around the query point, exactly matching the GDD's own implementation note.

**Cap-eviction policy (Q3)**: when a new emission would push the live-source count past `MAX_LIVE_SOURCES = 500`, the single **oldest** live source (by `emissionTime`, ascending) is evicted to make room, not the new emission refused. This preserves the "field responds to current activity" fantasy (Pillar 1/3) — refusing new emissions at cap would silently break responsiveness exactly when the world is busiest, which is the worst possible failure mode. Eviction removes the source from both the live-source list and its grid cell bucket; the write-once attribution archive entry is unaffected (archive entries are independent of live-source-list membership per the GDD's own C.1.x note).

### N1 — StreamingEnabled chunk-membership: server-computed, position-based (no client signal in the trust path)

**Decision**: `loadedChunks[player]` is computed **entirely server-side from the player's own server-tracked position** (already authoritative per Player Controller's `HumanoidRootPart.Position` reads), never from any client-fired signal, client-writable property, or property-changed subscription. A chunk (identified by its `(chunkX, chunkZ)` coordinate at `CHUNK_DIMENSIONS = 64×64` studs) is considered "loaded" for a player if the player's last known server position is within `STREAMING_PUSH_RADIUS` studs of the chunk's center — a server-owned constant, independent of the client's actual `Workspace.StreamingEnabled` render state. This sidesteps needing to trust or even observe any client-side streaming signal at all: worst case, the server pushes a flora update slightly before or after the client has visually streamed the chunk in, which is a bandwidth/timing nicety, not a security or correctness issue (the client simply ignores updates for chunks it hasn't rendered yet). **This satisfies F.4 row 5 and N1's own escalation clause** ("if no clean API exists, escalate to creative-director") without needing the escalation — the position-based heuristic requires no engine API whose post-cutoff behavior is uncertain. **Verification Required before implementation**: confirm `STREAMING_PUSH_RADIUS`'s chosen value (recommended: `Workspace.StreamingTargetRadius` + a safety margin, if that property is readable server-side at the pinned Studio version — WebSearch/Studio-verify per `VERSION.md`'s workflow) keeps false-negative (chunk loaded but not pushed) and false-positive (pushed but not yet rendered) rates low enough that H.32d's cache-integrity ACs pass empirically.

### N2 / N9 — Chunk-stream-in ordering: one atomic, yield-free sequence

**Decision**: chunk-membership add, snapshot computation, `FloraChunkInitialSnapshot` fire, and per-flora cache reset are one **synchronous, yield-free sequence per player per chunk**, mirroring the same discipline C.1.11/C.1.12 already established for `OnPlayerDied`:
1. `loadedChunks[player][chunkId] = true` (membership add)
2. Compute the snapshot payload from current field state (synchronous read, no yield)
3. `:Fire(player, snapshotPayload)`
4. Reset the per-flora last-pushed-t cache for that chunk to the snapshot values

Because steps 1–4 execute without yielding, there is no window where a second chunk-re-add (N2's edge case: "chunk re-add happens within the same field-update pass as the original snapshot fire") can interleave — the entire sequence completes atomically within one Heartbeat before any other chunk-membership mutation for that player can begin. This closes N2 and N9 with the same mechanism.

### N3 — Empirical verification of Knit `RemoteSignal:Fire` no-op on departed players

**Decision**: before implementation is considered complete, a Studio test explicitly fires a Knit `RemoteSignal:Fire(player, ...)` (not the raw `RemoteEvent:FireClient`, which is a different method with its own semantics — the GDD's own history notes this exact confusion was already corrected once) targeting a `Player` instance that has already left the game, and confirms it is a silent no-op (no error, no yield, no exception). This is Verification Required, not a design decision this ADR can settle from documentation alone — captured in this ADR's verification log once run, per N3's own instruction.

### N4 — `OnDisturbanceAlert` rate-limit and coalescing

**Decision**: per-player rate limit of **5 fires/sec** on `OnDisturbanceAlert`. If a single field-update pass would fire more than one tier-crossing for the same player (e.g., simultaneously crossing Tense and Hunt as the field rises rapidly), **coalesce into one payload carrying the full ordered list of crossed tiers** for that pass, rather than firing multiple times or dropping all but the highest. This preserves complete tier-crossing information for HUD/audio subscribers without violating the rate limit.

### N5 — Raw RemoteEvent server-fire-only enforcement

**Decision**: `FloraChunkUpdate` and `FloraChunkInitialSnapshot` are raw Roblox `RemoteEvent`s (not Knit `RemoteSignal`s, per the GDD's own bandwidth-efficiency choice). The server-side script registers **no `OnServerEvent` callback** for either — this is a code-review-enforceable invariant (grep for `FloraChunkUpdate.OnServerEvent`/`FloraChunkInitialSnapshot.OnServerEvent` finding zero matches), not merely a convention. A future H.39e-style static lint could mechanically enforce this the same way H.39e enforces the `Humanoid.Died` monopoly, but that is an optional hardening, not required for this ADR's closure.

### N6 — `GetDeathAttributionPayload` eager construction

**Decision**: `GetDeathAttributionPayload` is invoked **eagerly, synchronously, inside the same `Humanoid.Died` handler** that constructs the rest of the death snapshot (C.1.11's existing yield-free sequence), not lazily on HUD request. The payload is cached against the `deathEventId` for the HUD to retrieve later (a simple keyed table, cleared at run end per Architecture Principle #5), closing the archive-entry-TTL-expiry race N6 identifies.

### N7 / N8 — Ops-log monitoring

**Decision**: two ops-log (`print`/analytics-tagged `warn`, not a hard error) emissions:
- **N7**: when the live-source count exceeds `207` (the H.36 expected steady-state upper bound) for a sustained window of **>30 s**, log a pathological-zone warning tagged with current count and duration. A simple watchdog: record the timestamp the count first exceeded 207; if still exceeded 30 s later, emit; reset the timestamp once the count drops back under 207.
- **N8**: when C.1.13's graceful-skip catch-up triggers (a single Heartbeat consuming more than one update interval), log a Heartbeat-floor-freeze event tagged with the actual elapsed time vs. the expected interval.

Both are observability-only — neither changes runtime behavior, both exist so a production hitch or drift is caught in logs before it becomes a player-visible complaint.

### N10 — Simultaneous squad-death attribution: pre-dispatch registry snapshot (Option A)

**Decision**: adopt **Option (a)** from N10's own framing — a **once-per-field-update-pass pre-dispatch registry snapshot**, consulted by `_captureDeathLockSnapshot` for every death that occurs within the same pass, rather than accepting the post-purge "decayed history" read for the second death. Concretely: at the start of each field-update pass, before processing any `Humanoid.Died` callbacks that pass triggers, the current `predatorId` lock registry is snapshotted into a pass-scoped local. Every death handled within that same pass reads from the pass-scoped snapshot, not the live (potentially-already-purged) registry — so a second same-pass death sees the SAME at-death lock state the first death saw, regardless of fan-out ordering between the two `Humanoid.Died` callbacks. This is chosen over Option (b) (accept degraded semantics) because it preserves death-screen narrative correctness for both players at a small, bounded implementation cost (one extra table snapshot per pass, not per death), and because the GDD's own framing marks Option (a) as closing the gap rather than merely documenting it. **This ADR authors the mechanism; a companion AC (recommended id `H.30d`, per N10's own suggestion) exercising the two-deaths-same-pass scenario should be added to the GDD in a follow-up touch** — this ADR does not itself edit the GDD's Acceptance Criteria section.

### N11 — `hotspot.id` comparison convention

**Decision**: `hotspot.id` (the `"%d_%d"`-format dedup-cell string) comparison for tie-breaking (Predator AI's Core Rule 3 / H.8 third tier) uses **Luau's native string `<` operator (byte-lexicographic)** — no numeric parse of the encoded cell coordinates. This is the GDD's own recommended pin; adopted verbatim since any single deterministic total order satisfies PA's determinism clause and this is purely a cross-implementation-consistency hygiene decision, not a live contradiction.

### Architecture Diagram

```
DisturbanceService
├── KnitInit:
│     - spatial hash grid (empty, cell-size 32)
│     - live-source list (empty)
│     - attribution archive (empty, cap MAX_ATTRIBUTION_ARCHIVE_ENTRIES)
│     - OnPlayerDied Signal (ADR-0001 Rule 1: constructed here, not KnitStart)
│     - RegistrationHandshake module (ADR-0001 Rule 2 worked example — see below)
│     - loadedChunks: {[Player]: {[chunkId]: true}}  (server-computed, N1)
│
├── KnitStart:
│     - Humanoid.Died chain registration (Players.PlayerAdded → CharacterAdded → Died)
│     - field-update Heartbeat loop begins (decay pass + N7/N8 monitoring)
│
├── Public surface (server-internal, non-.Client):
│     - GetHottestHotspot(callerPosition, searchRadius, minimumTier)
│     - GetSquadAggregateT(excludePlayer?)
│     - GetOnPlayerDiedSignal()
│     - GetDeathAttributionPayload(deathEventId)  -- N6: pre-computed, not lazy
│
├── RegistrationHandshake (module-private require(), ADR-0001 Rule 2):
│     - RegisterPredatorLockChangedSignal(signal)
│     - ReleasePredatorLock(predatorId)  -- caller: Predator AI ONLY
│
└── Raw RemoteEvents (N5: server-fire-only, zero OnServerEvent registrations):
      - FloraChunkInitialSnapshot
      - FloraChunkUpdate
```

### Key Interfaces

```luau
--!strict
-- Spatial grid: plain table-of-tables, NOT Region3.
type SourceId = string
type SpatialGrid = {[number]: {[number]: {SourceId}}}  -- grid[cellX][cellZ] = flat list of source ids

local SPATIAL_GRID_CELL_SIZE = 32
local function cellCoordFor(position: Vector3): (number, number)
    return math.floor(position.X / SPATIAL_GRID_CELL_SIZE),
           math.floor(position.Z / SPATIAL_GRID_CELL_SIZE)
end

-- N1: server-computed chunk membership, no client signal in the trust path.
local CHUNK_DIMENSIONS = 64
local STREAMING_PUSH_RADIUS = 96  -- provisional; verify against Workspace.StreamingTargetRadius
function DisturbanceService:_isChunkLoadedForPlayer(player: Player, chunkId: string): boolean
    local playerPos = self:_getServerTrackedPosition(player)  -- PC's own authoritative read
    local chunkCenter = chunkCenterFor(chunkId)
    -- XZ-plane distance only, matching cellCoordFor's own XZ-only grid (engine-specialist
    -- review 2026-07-06): full 3D Magnitude would skew results across cliffs/caves/multi-level
    -- builds where vertical distance is large but the chunk is still the correct one.
    local dx, dz = playerPos.X - chunkCenter.X, playerPos.Z - chunkCenter.Z
    return math.sqrt(dx * dx + dz * dz) <= STREAMING_PUSH_RADIUS
end

-- N2/N9: one atomic, yield-free sequence per player per chunk.
function DisturbanceService:_onChunkStreamIn(player: Player, chunkId: string): ()
    self._loadedChunks[player][chunkId] = true              -- (1) membership add
    local snapshot = self:_computeChunkSnapshot(chunkId)     -- (2) synchronous compute, no yield
    self._floraChunkInitialSnapshot:Fire(player, snapshot)   -- (3) fire
    self:_resetFloraDeltaCache(player, chunkId, snapshot)    -- (4) cache reset
end

-- Cleanup: without this, self._loadedChunks[player] leaks a table per departed
-- player for the life of the server (engine-specialist review 2026-07-06).
Players.PlayerRemoving:Connect(function(player: Player)
    DisturbanceService._loadedChunks[player] = nil
end)
```

## Alternatives Considered

### Alternative 1: `Region3`-based spatial queries
- **Description**: Use Roblox's `Region3`/`Workspace:FindPartsInRegion3` family for spatial queries instead of a manual hash grid.
- **Pros**: Built-in engine primitive, no custom code.
- **Cons**: `Region3` queries physical `BasePart` Instances in the 3D world; this system's "sources" are pure data (position + magnitude + age), not physical Instances, so using `Region3` would require spawning invisible physical markers for every emission purely to make them queryable — adding real per-emission Instance overhead (up to 500 live sources) for a problem a plain table already solves in O(1).
- **Rejection Reason**: Solves a problem this system doesn't have (physical collision/proximity) at a real performance cost, for a system whose own GDD already assumes plain-data sources.

### Alternative 2: Read `Player.ReplicationFocus` for chunk membership (N1)
- **Description**: Use the client-set `ReplicationFocus` property as the signal for "this chunk is loaded for this player."
- **Pros**: Would directly reflect the client's actual StreamingEnabled state, rather than an approximation.
- **Cons**: **Already explicitly rejected in the GDD itself** (line 522: "`ReplicationFocus` is NEVER read or watched by `DisturbanceService`... client-writable and therefore not a trustworthy signal... an exploit-class regression"). Restated here only because N1 is this ADR's obligation to close, not to reopen a settled question.
- **Rejection Reason**: Already closed by the GDD's own H.31b AC; re-opening it would be a security regression.

## Consequences

### Positive
- All eleven N-series ADR obligations closed with a concrete, implementable decision each — implementation can proceed without re-deriving GDD-referenced-but-unspecified behavior.
- Spatial grid choice (plain table, not `Region3`) avoids real per-emission Instance overhead at up to 500 live sources.
- N1's server-position-based heuristic requires no uncertain post-cutoff API, sidestepping the GDD's own "escalate to creative-director if no clean API exists" branch entirely.

### Negative
- N1's heuristic is an approximation, not a true StreamingEnabled-state mirror — accepted because the failure mode (slightly early/late push) is a bandwidth nicety, not a correctness or security issue, but this trade-off should be named explicitly to whoever tunes `STREAMING_PUSH_RADIUS`.
- N10's pre-dispatch snapshot adds one extra table copy per field-update pass (not per death) — a small, bounded cost accepted for death-screen correctness.

### Risks
- **Engine-specialist review (2026-07-06) fixes**: the `Key Interfaces` spatial-grid type had a bug (`GridCell` was declared as a `{sourceId: string}` record instead of the flat string list the Decision text describes — fixed to `type SourceId = string; SpatialGrid = {[number]: {[number]: {SourceId}}}`); `_isChunkLoadedForPlayer` used full 3D `.Magnitude` against an XZ-only grid concept (fixed to an XZ-plane-only distance check, matching `cellCoordFor`'s own XZ-only cell coordinates — vertical distance across cliffs/caves/multi-level builds would otherwise skew results); `self._loadedChunks[player]` had no `PlayerRemoving` cleanup (fixed — a `Players.PlayerRemoving` connection now clears it, preventing a per-departed-player table leak).
- **`STREAMING_PUSH_RADIUS`'s correct value is unverified** — set too small, chunks push late (visible pop); set too large, wasted bandwidth pushing to players who haven't rendered the chunk yet. **Mitigation**: named as Verification Required; tune empirically against H.32d's cache-integrity ACs during implementation.
- **N3's empirical Knit `RemoteSignal:Fire` no-op behavior is unverified** against the pinned build. **Mitigation**: explicit Studio test required before implementation is considered complete (see N3 Decision).
- **The eviction policy (oldest-first) could evict a source still relevant to an active predator lock** if that lock has persisted unusually long. **Mitigation**: `MAX_LIVE_SOURCES = 500` is far above the H.36 steady-state expectation of ~207; eviction under normal play is not expected to occur. If N7's ops-log ever fires in production, that is the signal this risk is materializing and warrants revisiting the eviction policy, not a silent tuning change.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| ecological-disturbance.md | N1–N11 (forward-obligations.md, "the ADR MUST specify" cluster); spatial-grid data structure and cap-eviction policy (Q3) reverse-cited at GDD line 1288 | Every N-item closed with a specific decision above; `Region3` explicitly rejected in favor of a plain table-of-tables grid; oldest-first eviction adopted for Q3 |
| predator-ai.md | Consumes `GetHottestHotspot`, `GetSquadAggregateT`, the ED↔PA RegistrationHandshake | Unchanged — this ADR implements, not renames, the frozen contracts PA's approved GDD depends on |

## Performance Implications
- **CPU**: Spatial grid lookups are O(1) amortized per cell; `GetHottestHotspot`'s 4–9-cell scan matches the GDD's own stated cost model. N7/N8 monitoring adds negligible per-pass overhead (a counter comparison and a timestamp check).
- **Memory**: Live-source list bounded at 500 entries; attribution archive bounded at `MAX_ATTRIBUTION_ARCHIVE_ENTRIES` (already registered in `docs/registry/architecture.yaml` via the ED GDD's own round-24 patch). Grid cell tables are sparse (only populated cells exist), bounded by the same 500-source cap.
- **Load Time**: None — server-side simulation state, no asset loading.
- **Network**: N4's 5/sec rate limit and coalescing bounds `OnDisturbanceAlert` bandwidth; N5 confirms `FloraChunkUpdate`/`FloraChunkInitialSnapshot` remain raw, bandwidth-efficient RemoteEvents rather than the heavier Knit `RemoteSignal` wrapper.

## Migration Plan
No migration — DisturbanceService is not yet implemented. This ADR is the baseline implementation is written against.

## Validation Criteria
- N3's Studio test (Knit `RemoteSignal:Fire` on a departed player) passes and is logged in this ADR's verification record.
- N1's `STREAMING_PUSH_RADIUS` value keeps H.32d's cache-integrity ACs passing under representative playtest movement patterns.
- N7's ops-log never fires under the H.36 steady-state (~207 sources) in normal 4-player play; if it does, that is itself useful signal, not a failure of this ADR.
- A grep-based check confirms zero `OnServerEvent` registrations exist for `FloraChunkUpdate`/`FloraChunkInitialSnapshot` (N5).

## Related Decisions
- Depends on ADR-0001 (KnitInit/KnitStart Ordering Discipline) — this ADR's RegistrationHandshake instance is ADR-0001's Rule 2 worked example.
- Enables ADR-0005 (Death & Respawn Lifecycle).
- `design/gdd/ecological-disturbance.md` (C.1.x, D.1–D.7, G.5–G.7), `design/gdd/ecological-disturbance-forward-obligations.md` (N1–N11, the obligations this ADR closes).

## Open Questions
- **Companion AC `H.30d`** (N10's two-deaths-same-pass scenario) is not authored by this ADR — flagged as a follow-up GDD touch, per N10's own instruction that this ADR specify the mechanism, not edit the GDD's Acceptance Criteria section directly.
