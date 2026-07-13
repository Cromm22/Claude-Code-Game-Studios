# Story 014: StreamingEnabled Chunk Membership & Flora Chunk Snapshot/Update Push

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-008` (server-side `loadedChunks[player]` membership set, server-computed only), `TR-ed-009` (per-player per-flora last-pushed-t cache, reset on snapshot/drop), `TR-ed-029` (two raw RemoteEvents, server-fire-only), `TR-ed-031` (StreamingEnabled chunk-load detection, `ReplicationFocus` forbidden), `TR-ed-050` (sources persist independent of any client's StreamingEnabled), `TR-ed-060` (`CHUNK_DIMENSIONS=64×64` studs), `TR-ed-064` (`ReplicationFocus` never trusted, `loadedChunks` sole snapshot authority)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: **N1 (settled)** — `loadedChunks[player]` is computed entirely server-side from the player's own server-tracked position (already authoritative per Player Controller's `HumanoidRootPart.Position` reads), never from any client-fired signal or client-writable property. A chunk is "loaded" if the player's last known server position is within `STREAMING_PUSH_RADIUS` studs of the chunk's center. **N2/N9 (settled)** — chunk-membership add, snapshot computation, `FloraChunkInitialSnapshot` fire, and per-flora cache reset are one synchronous, yield-free sequence per player per chunk.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: HIGH
**Engine Notes**: `STREAMING_PUSH_RADIUS`'s correct value is UNVERIFIED (recommended: `Workspace.StreamingTargetRadius` + safety margin, if that property is readable server-side at the pinned Studio version — WebSearch/Studio-verify per `VERSION.md`'s workflow before finalizing the constant). This is Verification Required, not guessable from training data.

**Control Manifest Rules (Core layer)**:
- Required: StreamingEnabled chunk-membership (`loadedChunks[player]`) is computed entirely server-side from the player's own server-tracked position — never from any client-fired signal or client-writable property — source: ADR-0004
- Required: Chunk-stream-in is one atomic, yield-free sequence per player per chunk: membership add → snapshot compute → `Fire` → per-flora cache reset — source: ADR-0004
- Required: `FloraChunkUpdate`/`FloraChunkInitialSnapshot` are raw `RemoteEvent`s with zero `OnServerEvent` registrations on the server — source: ADR-0004
- Required: Clean up any per-player table (`loadedChunks`) on `Players.PlayerRemoving` — source: ADR-0004
- Forbidden: Never read or watch `Player.ReplicationFocus` for chunk-membership/streaming decisions — client-writable, not a trustworthy signal, an exploit-class regression — source: ADR-0004
- Forbidden: Never wrap `FloraChunkUpdate`/`FloraChunkInitialSnapshot` in a Knit `RemoteSignal` — must remain raw, bandwidth-efficient `RemoteEvent`s — source: ADR-0004

---

## Acceptance Criteria

- [ ] `loadedChunks: {[Player]: {[chunkId]: true}}` computed server-side via `_isChunkLoadedForPlayer` using XZ-plane-only distance (matching the grid's own XZ-only cell coordinates — NOT full 3D `.Magnitude`, which would skew results across cliffs/caves/multi-level builds).
- [ ] `Players.PlayerRemoving` clears `self._loadedChunks[player]` — without this, a per-departed-player table leaks for the life of the server.
- [ ] **N2/N9 atomic sequence (REQUIRED)**: (1) `loadedChunks[player][chunkId] = true`; (2) compute snapshot payload from current field state (synchronous, no yield); (3) `:Fire(player, snapshotPayload)`; (4) reset per-flora last-pushed-t cache for that chunk to the snapshot values. All 4 steps execute without yielding.
- [ ] **`FloraChunkUpdate`**: one raw `RemoteEvent` fired per active chunk per tick (max 5/sec), carrying `{chunkId, [{floraNodeId, targetT}, ...]}` for every flora in that chunk whose `t` changed by more than `FLORA_UPDATE_DELTA_THRESHOLD` since the last push. Empty arrays are NOT fired.
- [ ] **`FloraChunkInitialSnapshot`**: one-shot raw `RemoteEvent` fired when the server's own streaming logic newly adds a chunk to a player's `loadedChunks` set, carrying ALL flora in that chunk (not just delta-crossing ones). Payload format identical to `FloraChunkUpdate`.
- [ ] **Membership-gated delivery (REQUIRED)**: every fire of either RemoteEvent MUST gate its target-player resolution against the server-side `loadedChunks` membership set — a push for `(player, chunkId)` where `chunkId ∉ loadedChunks[player]` is silently dropped, never delivered, even during stream-out/stream-in race windows.
- [ ] **`ReplicationFocus` NEVER read or watched** by `DisturbanceService`, anywhere in the chunk-load detection path. The round-1 `GetChunkFieldSnapshot` RemoteFunction stays removed — no client-callable surface for snapshot requests.
- [ ] Both RemoteEvents register **zero `OnServerEvent` callbacks** on the server (server-fire-only).
- [ ] **H.31** — GIVEN a chunk streams in with stale flora state AND `MockTweenService` records `TweenService:Create` calls, WHEN the server fires `FloraChunkInitialSnapshot`, THEN the client's flora-state table updates to the snapshot's `targetT` ± 0.001 BEFORE any tween fires, and the first tween's `StartValue` equals the snapshot value (not 0).
- [ ] **H.32b** — GIVEN a chunk streams out on its only loaded client with live emissions, WHEN the server continues, THEN emissions continue decaying and remain queryable via `GetHottestHotspot`; on stream-in, `FloraChunkInitialSnapshot` carries current decayed `targetT`.
- [ ] **H.32d** — GIVEN a mock client has chunkA added to `loadedChunks`, server fires `FloraChunkInitialSnapshot`, THEN the harness removes chunkA from `loadedChunks` within the SAME pass, re-adds on the SUBSEQUENT pass, WHEN the third pass runs, THEN: (a) a fresh snapshot fires for chunkA; (b) per-flora last-pushed-t cache reset such that the next `FloraChunkUpdate` applies the delta gate against snapshot values (not pre-stream-out); (c) recovery bounded to one pass after stream-in.
- [ ] **H.31b (security lint, STATIC — verified structurally here, mechanically enforced by Story 016)**: zero occurrences of `"ReplicationFocus"`; zero `Player:GetPropertyChangedSignal("ReplicationFocus")`; zero direct reads of `Player.ReplicationFocus`; zero `GetPropertyChangedSignal` on any client-writable Player property in the chunk-load code path; zero `Player.Character.*.Position`-polling loops. **BLOCKING.**

---

## Implementation Notes

Key interface (ADR-0004, cite verbatim):
```luau
local CHUNK_DIMENSIONS = 64
local STREAMING_PUSH_RADIUS = 96  -- provisional; verify against Workspace.StreamingTargetRadius
function DisturbanceService:_isChunkLoadedForPlayer(player: Player, chunkId: string): boolean
    local playerPos = self:_getServerTrackedPosition(player) -- PC's own authoritative read
    local chunkCenter = chunkCenterFor(chunkId)
    local dx, dz = playerPos.X - chunkCenter.X, playerPos.Z - chunkCenter.Z
    return math.sqrt(dx * dx + dz * dz) <= STREAMING_PUSH_RADIUS
end

function DisturbanceService:_onChunkStreamIn(player: Player, chunkId: string): ()
    self._loadedChunks[player][chunkId] = true              -- (1) membership add
    local snapshot = self:_computeChunkSnapshot(chunkId)     -- (2) synchronous compute, no yield
    self._floraChunkInitialSnapshot:Fire(player, snapshot)   -- (3) fire
    self:_resetFloraDeltaCache(player, chunkId, snapshot)    -- (4) cache reset
end

Players.PlayerRemoving:Connect(function(player: Player)
    DisturbanceService._loadedChunks[player] = nil
end)
```
Worst-case failure mode of the `STREAMING_PUSH_RADIUS` approximation is a bandwidth/timing nicety (slightly early/late push), not a correctness or security issue — the client simply ignores updates for chunks it hasn't rendered yet. This is the accepted trade-off per ADR-0004's Consequences section; do not over-engineer a tighter sync.

"Active chunk" (for `FloraChunkUpdate`'s per-tick fan-out, distinct from initial snapshot) = any chunk containing at least one player or within `StreamingTarget` radius of any connected player.

---

## Out of Scope

- Story 005: `fieldValue`/decay math that produces the `targetT` values this story pushes (this story consumes it, doesn't compute it).
- Client-side flora rendering (Color3.Lerp, PointLight tween) — entirely out of this epic, owned by the Bioluminescent Flora rendering subsystem.
- Story 016: the H.31b/H.39f CI lint mechanics that *enforce* this story's security constraints mechanically.

---

## QA Test Cases

- **AC — server-computed membership, XZ-only**: Given: a player at a known server-tracked position — When: `_isChunkLoadedForPlayer` evaluated against a chunk whose center is within `STREAMING_PUSH_RADIUS` in XZ but far away in Y (e.g., a cave far below) — Then: correctly returns `true` (XZ-only distance) despite large Y separation — confirms the fix from ADR-0004's engine-specialist review (full 3D `.Magnitude` would have incorrectly returned `false`).
- **AC — `PlayerRemoving` cleanup**: Given: a player with populated `loadedChunks` entries departs — When: `PlayerRemoving` fires — Then: `self._loadedChunks[player]` is `nil` afterward; no memory leak across repeated join/leave cycles (test with N=50 simulated join/leave cycles, assert table size stays bounded).
- **AC — N2/N9 atomic sequence**: Given: an instrumented harness — When: a chunk streams in for a player — Then: the four steps (membership add, snapshot compute, fire, cache reset) execute with zero yields between them, in that exact order, within a single Luau frame. Edge case: a second chunk-stream-in request for the SAME player+chunk arriving within the same field-update pass as the first — the atomicity of the first sequence prevents any interleaving.
- **AC — membership-gated delivery**: Given: a push attempt for `(player, chunkId)` where `chunkId` is NOT in `loadedChunks[player]` — When: attempted — Then: silently dropped, never delivered. Edge case: a race window where a chunk is being removed from `loadedChunks` in the same pass a push was about to fire — the membership check must be evaluated at fire-time, not cached from an earlier point in the pass.
- **AC-H.31**: Given: `MockTweenService` recording `TweenService:Create` calls, a chunk with stale client flora state streams in — When: `FloraChunkInitialSnapshot` fires — Then: the client-side flora-state table (test double) updates to the snapshot's `targetT` ± 0.001 BEFORE any tween is created; the first tween's `StartValue` equals the snapshot value, not 0.
- **AC-H.32b**: Given: a chunk streams out on its only loaded client, live emissions remain in that chunk — When: the server continues running — Then: those emissions continue decaying per Story 005's D.1 and remain queryable via `GetHottestHotspot`; on a later stream-in, the snapshot carries the correctly-decayed `targetT` (not the stale pre-stream-out value).
- **AC-H.32d**: Given: chunkA added to `loadedChunks`, initial snapshot fired, then removed from `loadedChunks` within the same pass, then re-added on the subsequent pass — When: the third pass runs — Then: (a) a FRESH snapshot fires for chunkA; (b) the per-flora last-pushed-t cache is reset to the fresh snapshot's values (so the next `FloraChunkUpdate`'s delta gate compares against the fresh snapshot, not stale pre-stream-out values); (c) full recovery is achieved within one pass after the re-add.
- **AC-H.31b (security lint, structural — this story's own code must pass this)**: Given: the entire chunk-load code path this story introduces — When: grepped for `"ReplicationFocus"`, `GetPropertyChangedSignal`, and `Position`-polling loops — Then: zero matches anywhere in this story's files.
- **AC — zero `OnServerEvent`**: Given: `FloraChunkUpdate` and `FloraChunkInitialSnapshot`'s server-side declarations — When: grepped for `.OnServerEvent` — Then: zero matches.
- **AC — empty-array suppression**: Given: a field-update pass where no flora in a given active chunk crossed `FLORA_UPDATE_DELTA_THRESHOLD` — When: the pass completes — Then: no `FloraChunkUpdate` fires for that chunk at all (not an empty-array payload).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ecological-disturbance/streaming-chunk-membership-flora-push_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 001, 005
- Unlocks: 016

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: All ACs COVERED except H.31's client-side tween-ordering half (the Bioluminescent Flora rendering subsystem doesn't exist yet — explicitly out of this epic; the server-side guarantee H.31 depends on is fully implemented and tested)
**Deviations**: `STREAMING_PUSH_RADIUS=96` is UNVERIFIED per the story's own Engine Notes — clearly flagged in `DisturbanceConstants.luau`, the module header, and call-site comments, not silently treated as final. `:FireClient` (not the ADR's literal `:Fire`) used for the two raw RemoteEvents — correct per N5's actual Decision text; ADR-0004's own Key Interfaces sample has a documentation bug, logged as part of **TD-008**. Fixed a real harness infrastructure gap (`tests/run_tests.lua`'s `load_luau_file` didn't give loaded modules the Roblox-datatype-global preamble needed to construct `Vector3` internally) — benefits future stories, not just this one. Flora-node enumeration has no real data source yet (no registry exists) — stubbed via an injectable function, mirroring Story 004's established stub precedent.
**Test Evidence**: `tests/integration/ecological-disturbance/streaming-chunk-membership-flora-push_test.luau` — passing
**Code Review**: Complete (combined ed-6+ed-14 review) — APPROVED WITH SUGGESTIONS
