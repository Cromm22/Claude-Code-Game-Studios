--!strict
-- DisturbanceServiceStreamingLogic
--
-- Implements: production/epics/ecological-disturbance/story-014-streaming-chunk-membership-flora-push.md
-- GDD: design/gdd/ecological-disturbance.md -- C.3.5 (chunk-batched flora broadcast), TR-ed-008
--      (server-side loadedChunks[player] membership set), TR-ed-009 (per-player per-flora
--      last-pushed-t cache, reset on snapshot/drop), TR-ed-029 (two raw RemoteEvents,
--      server-fire-only), TR-ed-031/TR-ed-064 (the client-writable streaming-focus property
--      ADR-0004's N1 Decision names is forbidden; loadedChunks is the sole snapshot authority),
--      TR-ed-050 (sources persist independent of StreamingEnabled),
--      TR-ed-060 (CHUNK_DIMENSIONS=64x64 studs)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md -- N1 (server-computed,
--      position-based chunk membership; XZ-plane-only distance, engine-specialist-review fix),
--      N2/N9 (one atomic, yield-free chunk-stream-in sequence), N5 (raw RemoteEvents, zero
--      OnServerEvent registrations)
--
-- Pure domain logic for chunk-id encoding/decoding, the N1 XZ-only distance membership check, the
-- per-flora delta-threshold gate, the wire payload format, the N2/N9 atomic stream-in ordering,
-- and the fire-time membership-gated-delivery check. Deliberately has ZERO dependency on Knit, any
-- Roblox service call, OR any require() at all -- mirrors every sibling DisturbanceService*Logic
-- module's own zero-require precedent (Stories 001-008), so it can be required and unit-tested
-- directly under Lune. DisturbanceService.luau is a thin Knit wrapper around this module's
-- functions: it owns the real self._loadedChunks/self._floraDeltaCache state tables, the two real
-- RemoteEvent Instances (constructed in KnitInit), the real Character/HumanoidRootPart.Position
-- reads, and the real self:fieldValue(position) calls this module's callers use to build
-- `floraStates` before calling in here.
--
-- SECURITY NOTE (REQUIRED, TR-ed-031/TR-ed-064, H.31b): this module -- and DisturbanceService
-- .luau's own Story 014 section -- NEVER reads or watches the client-writable streaming-focus
-- Player property ADR-0004's N1 Decision names and forbids (its literal name is deliberately never
-- spelled out anywhere in this codebase's own source files -- H.31b's own security lint checks for
-- its absence from the raw source text, comments included; see this story's own test file for the
-- documented rationale). loadedChunks[player] (owned by DisturbanceService.luau, not this module)
-- is the sole chunk-membership authority; membership is derived ENTIRELY from a server-tracked
-- position this module receives as an already-resolved `Vector3` parameter -- this module never
-- touches a `Player` instance or any client-writable property at all.
--
-- CALLBACK-INJECTION DESIGN (design call, mirrors DisturbanceServiceHotspotQueryLogic's and
-- DisturbanceServiceSquadAggregateLogic's own precedent): RunChunkStreamIn accepts
-- computeSnapshotFn/fireFn/resetCacheFn callbacks rather than performing the real Fire/cache-write
-- itself, so the exact N2/N9 four-step ordering (membership add -> snapshot compute -> fire ->
-- cache reset, ALL yield-free) is provable at the pure-module level via a test harness that records
-- call order through the injected callbacks, without requiring a live Knit service instance or a
-- real RemoteEvent Instance.
--
-- FLORA-NODE-ENUMERATION ASSUMPTION (flagged, not silently invented): this module -- and
-- DisturbanceService.luau's Story 014 wiring -- never enumerates flora nodes itself. Every function
-- below that needs "the current t value for each flora in a chunk" takes an ALREADY-BUILT
-- `floraStates: {[floraNodeId]: targetT}` table as a parameter. The codebase has no flora-node
-- registry yet (no CollectionService tag, no position list) -- the "Bioluminescent Flora rendering
-- subsystem" the GDD's own dependency table names as this data's owner is listed "Not started."
-- DisturbanceService.luau injects a placeholder `self._getFloraNodesInChunk` seam (defaulting to an
-- empty list) that a future flora-registry story must wire a real enumeration into -- mirroring
-- Story 004's DefaultIsEmissionLocked precedent (a stub awaiting a not-yet-built sibling story).

export type FloraSnapshotEntry = { floraNodeId: string, targetT: number }

--- Wire format, cited verbatim from the story's own Implementation Notes: a 2-element positional
--- array `{chunkId, floraPairs}`, where `floraPairs[i]` is itself a 2-element positional pair
--- `{floraNodeId, targetT}` (bandwidth-efficient -- no named keys over the wire).
export type ChunkPushPayload = { any }

--- Per-player per-flora last-pushed-t cache (TR-ed-009), keyed by floraNodeId. The caller
--- (DisturbanceService.luau) owns ONE of these per connected player.
export type FloraDeltaCache = { [string]: number }

local DisturbanceServiceStreamingLogic = {}

-- ============================================================================
-- Chunk-id encoding/decoding (TR-ed-060: CHUNK_DIMENSIONS=64x64 studs). "%d_%d" format, matching
-- this codebase's own established canonical-cellKey convention (TR-ed-011's previousTierAtPosition
-- keying, HotspotQueryLogic's DedupCellKey).
-- ============================================================================

function DisturbanceServiceStreamingLogic.ChunkIdFor(position: Vector3, chunkDimensions: number): string
	local chunkX = math.floor(position.X / chunkDimensions)
	local chunkZ = math.floor(position.Z / chunkDimensions)
	return ("%d_%d"):format(chunkX, chunkZ)
end

--- Inverts ChunkIdFor: returns the chunk's CENTER point (Y=0 -- chunks are an XZ-plane concept
--- only; see the distance check below for why Y is never used).
function DisturbanceServiceStreamingLogic.ChunkCenterFor(chunkId: string, chunkDimensions: number): Vector3
	local chunkXStr, chunkZStr = chunkId:match("^(%-?%d+)_(%-?%d+)$")
	assert(chunkXStr and chunkZStr, "DisturbanceServiceStreamingLogic.ChunkCenterFor: malformed chunkId: " .. tostring(chunkId))
	local chunkX = tonumber(chunkXStr) :: number
	local chunkZ = tonumber(chunkZStr) :: number
	return Vector3.new(chunkX * chunkDimensions + chunkDimensions / 2, 0, chunkZ * chunkDimensions + chunkDimensions / 2)
end

-- ============================================================================
-- N1 -- server-computed chunk membership. XZ-PLANE-ONLY distance (REQUIRED, engine-specialist
-- review 2026-07-06 fix cited verbatim from ADR-0004): full 3D .Magnitude would skew results across
-- cliffs/caves/multi-level builds where vertical distance is large but the chunk is still correct.
-- ============================================================================

function DisturbanceServiceStreamingLogic.IsChunkLoadedForPosition(
	playerPosition: Vector3,
	chunkCenter: Vector3,
	streamingPushRadius: number
): boolean
	local dx = playerPosition.X - chunkCenter.X
	local dz = playerPosition.Z - chunkCenter.Z
	return math.sqrt(dx * dx + dz * dz) <= streamingPushRadius
end

--- Enumerates candidate chunk ids near a player's position, for the per-pass membership-add scan
--- (DisturbanceService.luau's own orchestration needs SOME bounded candidate set to test
--- IsChunkLoadedForPosition against -- the story's own pseudocode only specifies the single-chunk
--- predicate, not this enumeration; this is this story's own necessary implementation detail,
--- flagged here rather than silently invented). `cellRadius` is deliberately generous (+1 cell
--- margin beyond the ceil'd radius-in-cells) -- over-enumeration here is safe/cheap, since
--- IsChunkLoadedForPosition above is the sole authoritative filter; a candidate that fails it is
--- simply never added to loadedChunks.
function DisturbanceServiceStreamingLogic.CandidateChunkIdsNear(
	playerPosition: Vector3,
	chunkDimensions: number,
	streamingPushRadius: number
): { string }
	local centerChunkX = math.floor(playerPosition.X / chunkDimensions)
	local centerChunkZ = math.floor(playerPosition.Z / chunkDimensions)
	local cellRadius = math.ceil(streamingPushRadius / chunkDimensions) + 1

	local candidates: { string } = {}
	for dx = -cellRadius, cellRadius do
		for dz = -cellRadius, cellRadius do
			table.insert(candidates, ("%d_%d"):format(centerChunkX + dx, centerChunkZ + dz))
		end
	end
	return candidates
end

-- ============================================================================
-- Per-flora delta-threshold gate (TR-ed-009 / FLORA_UPDATE_DELTA_THRESHOLD). A flora never pushed
-- before (nil in the cache) ALWAYS counts as crossed -- this is what makes
-- FloraChunkInitialSnapshot's "ALL flora, unconditional" semantics fall out of the SAME underlying
-- gate as a degenerate case, without a separate code path.
-- ============================================================================

function DisturbanceServiceStreamingLogic.HasCrossedDeltaThreshold(previousT: number?, newT: number, deltaThreshold: number): boolean
	if previousT == nil then
		return true
	end
	return math.abs(newT - previousT) > deltaThreshold
end

-- ============================================================================
-- Wire payload construction -- cited verbatim positional format from the story's own AC text:
-- `{chunkId, [{floraNodeId, targetT}, ...]}`.
-- ============================================================================

function DisturbanceServiceStreamingLogic.BuildFloraChunkPayload(chunkId: string, floraEntries: { FloraSnapshotEntry }): ChunkPushPayload
	local floraPairs: { any } = table.create(#floraEntries)
	for i, entry in floraEntries do
		floraPairs[i] = { entry.floraNodeId, entry.targetT }
	end
	return { chunkId, floraPairs }
end

--- FloraChunkInitialSnapshot payload (REQUIRED): ALL flora in the chunk, unconditional -- never
--- delta-filtered. Also returns a fresh cache table (every flora's value), which the caller uses as
--- the N2/N9 step-4 cache reset.
function DisturbanceServiceStreamingLogic.ComputeChunkFullSnapshot(
	chunkId: string,
	floraStates: { [string]: number }
): (ChunkPushPayload, FloraDeltaCache)
	local entries: { FloraSnapshotEntry } = {}
	local freshCache: FloraDeltaCache = {}
	for floraNodeId, targetT in floraStates do
		table.insert(entries, { floraNodeId = floraNodeId, targetT = targetT })
		freshCache[floraNodeId] = targetT
	end
	return DisturbanceServiceStreamingLogic.BuildFloraChunkPayload(chunkId, entries), freshCache
end

--- FloraChunkUpdate payload (REQUIRED): only flora whose `t` crossed FLORA_UPDATE_DELTA_THRESHOLD
--- since the last push. Empty-array suppression (REQUIRED): returns `nil` (not an empty-array
--- payload) when nothing crossed this pass -- the caller must not fire on a nil return. The second
--- return value carries ONLY the entries that were actually included, for the caller to fold into
--- its persistent per-player cache (never a full-cache replacement -- flora that did not cross stay
--- at their prior cached value).
function DisturbanceServiceStreamingLogic.ComputeChunkDeltaUpdate(
	chunkId: string,
	floraStates: { [string]: number },
	lastPushedCache: FloraDeltaCache,
	deltaThreshold: number
): (ChunkPushPayload?, FloraDeltaCache)
	local changedEntries: { FloraSnapshotEntry } = {}
	local updatedCacheValues: FloraDeltaCache = {}

	for floraNodeId, targetT in floraStates do
		if DisturbanceServiceStreamingLogic.HasCrossedDeltaThreshold(lastPushedCache[floraNodeId], targetT, deltaThreshold) then
			table.insert(changedEntries, { floraNodeId = floraNodeId, targetT = targetT })
			updatedCacheValues[floraNodeId] = targetT
		end
	end

	if #changedEntries == 0 then
		return nil, updatedCacheValues
	end

	return DisturbanceServiceStreamingLogic.BuildFloraChunkPayload(chunkId, changedEntries), updatedCacheValues
end

-- ============================================================================
-- N2/N9 -- one atomic, yield-free chunk-stream-in sequence, cited verbatim from ADR-0004's Key
-- Interfaces: (1) membership add, (2) synchronous snapshot compute, (3) fire, (4) cache reset. No
-- yield primitive appears anywhere in this function's body -- the four steps execute back-to-back
-- within a single Luau frame, so no interleaving chunk-re-add for the SAME player+chunk can ever
-- interrupt this sequence partway through (N2's own edge case).
-- ============================================================================

function DisturbanceServiceStreamingLogic.RunChunkStreamIn(
	loadedChunksForPlayer: { [string]: true },
	chunkId: string,
	computeSnapshotFn: () -> ChunkPushPayload,
	fireFn: (ChunkPushPayload) -> (),
	resetCacheFn: (ChunkPushPayload) -> ()
): ()
	loadedChunksForPlayer[chunkId] = true -- (1) membership add
	local snapshot = computeSnapshotFn() -- (2) synchronous compute, no yield
	fireFn(snapshot) -- (3) fire
	resetCacheFn(snapshot) -- (4) cache reset
end

-- ============================================================================
-- Membership-gated delivery (REQUIRED): re-checks `loadedChunksForPlayer[chunkId]` at the EXACT
-- moment of the call -- never a value cached/hoisted from earlier in the same pass. The caller MUST
-- pass the SAME live per-player loadedChunks table DisturbanceService.luau mutates elsewhere in the
-- same pass (never a copy), so a stream-out that happened earlier in this pass is guaranteed
-- visible here, closing the stream-out/stream-in race window (this story's own edge case).
-- ============================================================================

function DisturbanceServiceStreamingLogic.FireIfStillMember(loadedChunksForPlayer: { [string]: true }, chunkId: string, fireFn: () -> ()): boolean
	if not loadedChunksForPlayer[chunkId] then
		return false
	end
	fireFn()
	return true
end

-- ============================================================================
-- PlayerRemoving cleanup (REQUIRED, TR-ed-008/TR-ed-009): clears BOTH per-player tables this story
-- introduces. Exposed as a pure, directly-testable function (coding-standards.md: "all public
-- methods must be unit-testable") so the N=50 join/leave-cycle bounded-size property can be proven
-- without a live Knit service instance; DisturbanceService.luau's real PlayerRemoving handler
-- performs the equivalent two assignments inline (matching this file's own established inline-style
-- precedent for this exact handler), not by calling this function directly -- see that file's own
-- static/structural test for the real wiring confirmation.
-- ============================================================================

function DisturbanceServiceStreamingLogic.ClearPlayerStreamingState(
	loadedChunksByPlayer: { [any]: { [string]: true } },
	floraDeltaCacheByPlayer: { [any]: FloraDeltaCache },
	player: any
): ()
	loadedChunksByPlayer[player] = nil
	floraDeltaCacheByPlayer[player] = nil
end

return DisturbanceServiceStreamingLogic
