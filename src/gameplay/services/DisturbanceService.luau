--!strict
-- DisturbanceService
--
-- Implements: production/epics/ecological-disturbance/story-001-constants-bootstrap-field-update-loop.md
-- GDD: design/gdd/ecological-disturbance.md -- G.1-G.5 tuning knobs, C.1.13 Heartbeat
--      catch-up semantics, TR-ed-026/036/047/049/053
-- ADR: docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md ("KnitInit builds,
--      KnitStart connects"; RegistrationHandshake pattern)
--      docs/architecture/adr-0004-disturbanceservice-core-architecture.md (full
--      DisturbanceService architecture -- THIS STORY implements only the KnitInit
--      empty-container construction, config-validation gates, and the KnitStart
--      Heartbeat-accumulator skeleton; see the SCOPE NOTE below)
--
-- SCOPE NOTE (Story 001): this is a MINIMAL Knit service skeleton. In scope: the empty-
-- container construction, the config-validation gates (H.3d/H.3e), the Heartbeat accumulator
-- driving an empty `_runFieldUpdatePass()`. NOT implemented here (deferred to later stories,
-- per this story's own Out of Scope section):
--   - Story 002: DONE -- see the Emit() method below and DisturbanceServiceEmissionLogic.luau
--     (bullet kept and marked complete, rather than deleted, to preserve the Story 001 scope
--     note's original enumeration as a historical record)
--   - Story 003: DONE -- see the Emit() method below and DisturbanceServiceSpatialGridLogic.luau
--     (bullet kept and marked complete, matching the Story 002 precedent immediately above)
--   - Story 004: DONE -- see the Emit() method's archive-write tail, the KnitStart maintenance-
--     accumulator wiring, the PlayerRemoving handler, and DisturbanceServiceAttributionArchive
--     Logic.luau (bullet kept and marked complete, matching the Story 002/003 precedent above)
--   - Story 010: DONE -- see the KnitInit Humanoid.Died chain registration, the
--     _onHumanoidDied/_captureDeathLockSnapshot/GetOnPlayerDiedSignal methods below, and
--     DisturbanceServiceDeathFanoutLogic.luau (bullet kept and marked complete, matching the
--     Story 002/003/004 precedent above)
--   - Story 011: RegistrationHandshake module's actual export functions
--   - Story 017: N7/N8 ops-log monitoring logic inside the Heartbeat loop
--
-- All config-validation and accumulator-stepping math lives in the dependency-free
-- DisturbanceServiceBootstrapLogic module (zero Knit/Roblox-service dependency, directly
-- unit-testable under Lune). This file is a thin Knit wrapper: KnitInit container
-- construction + config-validation call sites, KnitStart's RunService.Heartbeat connection.
--
-- SCOPE NOTE (Story 002 -- production/epics/ecological-disturbance/story-002-emission-schema-
-- emit-intake.md): adds the Emit() method (server-internal, per ADR-0004 / GDD C.1.8's "No
-- client-callable emission path" rule -- no RemoteEvent/RemoteFunction/BindableEvent/.Client
-- method may call this, directly or indirectly). All schema validation and EmissionPayload
-- construction lives in the dependency-free DisturbanceServiceEmissionLogic module; this file
-- only samples the real clock (workspace:GetServerTimeNow()) and the real GUID generator
-- (HttpService:GenerateGUID(false)) and inserts the resulting payload into the flat
-- self._liveSources table keyed by emissionId (Story 003 owns spatial-grid cell placement;
-- Story 004 owns the attribution archive entry -- both explicitly out of this story's scope).
--
-- SCOPE NOTE (Story 003 -- production/epics/ecological-disturbance/story-003-spatial-grid-
-- live-source-cap-eviction.md): Emit()'s tail now routes through
-- DisturbanceServiceSpatialGridLogic.InsertEmission(), which places the payload into its grid
-- cell AND evicts the single oldest live source (by emissionTime ascending, per ADR-0004's
-- Q3 decision) if self._liveSources is already at DisturbanceConstants.MAX_LIVE_SOURCES. All
-- grid/cell/eviction math lives in that dependency-free module; this file only owns the real
-- self._spatialGrid/self._liveSources/self._insertionSequence state tables and the ops-log
-- warn() call site for cap-evictions. Story 004 owns the attribution archive entry, which this
-- path never reads or writes (archive independence -- see DisturbanceServiceSpatialGridLogic
-- .luau's own header note).
--
-- SCOPE NOTE (Story 004 -- production/epics/ecological-disturbance/story-004-attribution-
-- archive-ttl-cap.md): Emit()'s tail now ALSO writes a write-once AttributionArchiveEntry via
-- DisturbanceServiceAttributionArchiveLogic.InsertEntry() -- unconditionally, independent of
-- whether the Story 003 live-source cap-eviction above fired (see that module's own ARCHIVE
-- INDEPENDENCE note). All retention (TTL / live-referencer / predator-lock) and cap-FIFO-
-- eviction math lives in that dependency-free module; this file only owns the real
-- self._attributionArchive/self._attributionReferencingPlayers/self._archiveInsertionSequence
-- state tables, the self._isEmissionLocked injection point (Story 011's stub, per that module's
-- DefaultIsEmissionLocked -- TODO(Story 011)), the Players.PlayerRemoving re-evaluation call
-- (condition (b), scoped to sourcePlayerId only -- see that module's CONDITION (b) SCOPING
-- note), the periodic EXPIRY_MAINTENANCE_INTERVAL-cadenced Heartbeat accumulator driving
-- _runAttributionArchiveMaintenancePass() (TR-ed-051's "low-frequency maintenance cull pass"),
-- and the ops-log warn() call sites for cap-eviction / cap-exceeded-cannot-evict.
--
-- Session-scoped (TR-ed-049): no DataStoreService interaction anywhere in this file.
--
-- SCOPE NOTE (Story 005 -- production/epics/ecological-disturbance/story-005-decay-falloff-
-- fieldvalue.md): adds per-source decay caching (TR-ed-017), the dist2DSquared-before-dist2D
-- spatial falloff/contribution math (TR-ed-018, D.2), and the public fieldValue() accessor
-- (D.3). All decay/falloff/aggregation math lives in the dependency-free
-- DisturbanceServiceDecayFalloffLogic module; this file only owns the real self._decayCache
-- state table, the real workspace:GetServerTimeNow() clock sample driving the 5Hz decay pass
-- (inside _runFieldUpdatePass, alongside Story 001's existing accumulator skeleton), the
-- self._expFn server-internal test-injection point (_setExpFn -- H.9b, never exposed via
-- .Client), and the expiry-culling orchestration across self._liveSources/self._spatialGrid/
-- self._decayCache/self._insertionSequence (_cullExpiredSources, wired onto the SAME
-- EXPIRY_MAINTENANCE_INTERVAL-cadenced accumulator Story 004 already established, per H.9's own
-- "next maintenance pass... within EXPIRY_MAINTENANCE_INTERVAL" AC text). Story 008 owns
-- GetHottestHotspot -- out of this story's scope.
--
-- SCOPE NOTE (Story 008 -- production/epics/ecological-disturbance/story-008-hottest-hotspot-
-- query.md): adds the public `GetHottestHotspot(callerPosition, searchRadius, minimumTier)`
-- accessor (D.6, TR-ed-004/TR-ed-046) and the `_topContributorsAt(position, n)` helper it calls.
-- All scoring/dedup/non-finite-disqualification/contributor-ranking math lives in the
-- dependency-free DisturbanceServiceHotspotQueryLogic module; this file only owns the real grid
-- query composition (SpatialGridLogic.QueryCellsInRadius for the outer candidate enumeration,
-- SpatialGridLogic.QueryNeighborhood for topContributorsAt's fixed-INFLUENCE_RADIUS scan --
-- see DisturbanceServiceHotspotQueryLogic.luau's own SPATIAL-GRID QUERY-PRIMITIVE NOTE for why
-- these are two DIFFERENT primitives) and the real workspace:GetServerTimeNow() clock sample
-- topContributorsAt's age computation needs.
--
-- SCOPE NOTE (Story 006 -- production/epics/ecological-disturbance/story-006-tier-classification-
-- hysteresis-tiercrossedevent.md): adds tier classification with hysteresis (D.4), the canonical
-- previousTierAtPosition key encoding (TR-ed-011), the post-hitch multi-tier settle loop
-- (TR-ed-054), and the server-internal TierCrossedEvent Signal with C.3.3's server-side
-- per-pass coalescing rule (TR-ed-037). All state-machine/cascade/coalescing math lives in the
-- dependency-free DisturbanceServiceTierClassificationLogic module; this file only owns the real
-- self._previousTierAtPosition state table, the real self._tierCrossedEvent Signal (Signal.new(),
-- a NEW cross-service channel per ADR-0001 -- NOT the GDD-frozen C.1.11 OnPlayerDied raw
-- BindableEvent), the real live-source-position enumeration, and the GetTierCrossedSignal()
-- accessor. See _runTierClassificationPass's own header note for the position-enumeration design
-- call and its flagged known gap.
--
-- SCOPE NOTE (Story 009 -- production/epics/ecological-disturbance/story-009-disturbance-band-
-- crossed-signal.md): adds the server-internal, squad-aggregate-keyed OnDisturbanceBandCrossed
-- signal (TR-ed-038) -- distinct from Story 006's position-keyed TierCrossedEvent above: this one
-- is driven by the single scalar squadT (Story 007's GetSquadAggregateT(nil), unfiltered) rather
-- than per-position field values. All classification/direction/first-pass math lives in the
-- dependency-free DisturbanceServiceBandCrossedLogic module, which reuses Story 006's
-- TierClassificationLogic.ClassifyWithCascade unmodified (TR-ed-054) via CALLER-INJECTED function
-- reuse rather than reimplementing the settle loop OR require()-ing the sibling module directly
-- (that module stays zero-require, per every sibling *Logic module's own precedent -- see its own
-- CALLBACK-INJECTION DESIGN header note); this file only owns the real self._previousSquadTier
-- state (a single nilable Tier, NOT a table -- see that module's own FIRST-PASS DESIGN CALL note),
-- the real self._disturbanceBandCrossedSignal Signal (Signal.new(), a NEW cross-service channel per
-- ADR-0001, matching Story 006's own self._tierCrossedEvent precedent), the real
-- TierClassificationLogic.ClassifyWithCascade function value bound as the injected callback, and
-- the GetDisturbanceBandCrossedSignal() accessor.
--
-- SCOPE NOTE (Story 010 -- production/epics/ecological-disturbance/story-010-humanoid-died-
-- monopoly-onplayerdied-fanout.md): adds the Humanoid.Died sole-subscriber chain
-- (Players.PlayerAdded -> CharacterAdded -> Humanoid.Died:Connect, registered in KnitInit per
-- ADR-0001 Rule 1 / ADR-0004's Architecture Diagram) and the OnPlayerDied fan-out this is the
-- ONLY code path anywhere in the server codebase permitted to subscribe to Humanoid.Died
-- (TR-ed-032; a repo-wide static grep in this story's own test file verifies the monopoly). All
-- payload-construction math (step 5b) lives in the dependency-free
-- DisturbanceServiceDeathFanoutLogic module; this file only owns the real
-- self._deathLockSnapshot state table (KnitInit), the real self._onPlayerDied BindableEvent
-- (KnitInit -- a RAW BindableEvent, NOT a Knit Signal, per the GDD's own frozen C.1.11 closure --
-- see ADR-0004's dedicated OnPlayerDied channel type Decision subsection, NOT this story's own
-- new-channel choice), the real Humanoid.Died chain registration (KnitInit), the real
-- self:_captureDeathLockSnapshot stub (5a -- TODO(Story 011) below), and the real
-- workspace:GetServerTimeNow() clock sample (5b, sampled AFTER the snapshot capture). No dedup at
-- this layer (REQUIRED) -- see DisturbanceServiceDeathFanoutLogic.luau's own NO DEDUP note.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)
local DisturbanceConstants = require(script.Parent.DisturbanceConstants)
local BootstrapLogic = require(script.Parent.DisturbanceServiceBootstrapLogic)
local EmissionLogic = require(script.Parent.DisturbanceServiceEmissionLogic)
local SpatialGridLogic = require(script.Parent.DisturbanceServiceSpatialGridLogic)
local AttributionArchiveLogic = require(script.Parent.DisturbanceServiceAttributionArchiveLogic)
local DecayFalloffLogic = require(script.Parent.DisturbanceServiceDecayFalloffLogic)
local SquadAggregateLogic = require(script.Parent.DisturbanceServiceSquadAggregateLogic)
local HotspotQueryLogic = require(script.Parent.DisturbanceServiceHotspotQueryLogic)
local StreamingLogic = require(script.Parent.DisturbanceServiceStreamingLogic)
local TierClassificationLogic = require(script.Parent.DisturbanceServiceTierClassificationLogic)
local BandCrossedLogic = require(script.Parent.DisturbanceServiceBandCrossedLogic)
local DeathFanoutLogic = require(script.Parent.DisturbanceServiceDeathFanoutLogic)

export type SourceId = SpatialGridLogic.SourceId
export type SpatialGrid = SpatialGridLogic.SpatialGrid -- grid[cellX][cellZ] = flat list of source ids (ADR-0004)
export type AttributionArchiveEntry = AttributionArchiveLogic.AttributionArchiveEntry
export type DecayCache = DecayFalloffLogic.DecayCache
export type HotspotResult = HotspotQueryLogic.HotspotResult
export type FloraDeltaCache = StreamingLogic.FloraDeltaCache
export type ChunkPushPayload = StreamingLogic.ChunkPushPayload
export type Tier = TierClassificationLogic.Tier
export type BandCrossedDirection = BandCrossedLogic.Direction

local DisturbanceService = Knit.CreateService({
	Name = "DisturbanceService",
	Client = {},
})

--- Exposed for direct testability without a live service instance, matching the
--- PlayerControllerService precedent (Player Controller epic, Story 002).
DisturbanceService.ValidateInfluenceRadius = BootstrapLogic.ValidateInfluenceRadius
DisturbanceService.ValidateSpatialGridCellSize = BootstrapLogic.ValidateSpatialGridCellSize
DisturbanceService.StepAccumulator = BootstrapLogic.StepAccumulator
DisturbanceService.ValidateAndBuildEmission = EmissionLogic.ValidateAndBuildEmission
DisturbanceService.CellCoordFor = SpatialGridLogic.CellCoordFor
DisturbanceService.QueryNeighborhood = SpatialGridLogic.QueryNeighborhood
DisturbanceService.InsertEmission = SpatialGridLogic.InsertEmission
DisturbanceService.BuildAttributionArchiveEntry = AttributionArchiveLogic.BuildEntry
DisturbanceService.InsertAttributionArchiveEntry = AttributionArchiveLogic.InsertEntry
DisturbanceService.RunAttributionArchiveMaintenancePass = AttributionArchiveLogic.RunMaintenancePass
DisturbanceService.HandleAttributionArchivePlayerDeparture = AttributionArchiveLogic.HandlePlayerDeparture
DisturbanceService.HalfLifeFor = DecayFalloffLogic.HalfLifeFor
DisturbanceService.ComputeAge = DecayFalloffLogic.ComputeAge
DisturbanceService.ComputeDecayedMagnitude = DecayFalloffLogic.ComputeDecayedMagnitude
DisturbanceService.IsExpired = DecayFalloffLogic.IsExpired
DisturbanceService.RunDecayPass = DecayFalloffLogic.RunDecayPass
DisturbanceService.FindExpiredSourceIds = DecayFalloffLogic.FindExpiredSourceIds
DisturbanceService.dist2DSquared = DecayFalloffLogic.dist2DSquared
DisturbanceService.dist2D = DecayFalloffLogic.dist2D
DisturbanceService.Contribution = DecayFalloffLogic.Contribution
DisturbanceService.FieldValueAt = DecayFalloffLogic.FieldValueAt
DisturbanceService.GuardFinite = SquadAggregateLogic.GuardFinite
DisturbanceService.ComputeSquadAggregateT = SquadAggregateLogic.ComputeSquadAggregateT
DisturbanceService.QueryCellsInRadius = SpatialGridLogic.QueryCellsInRadius
DisturbanceService.TierLowerBound = HotspotQueryLogic.TierLowerBound
DisturbanceService.DedupCellKey = HotspotQueryLogic.DedupCellKey
DisturbanceService.DeduplicateByFloorSnap = HotspotQueryLogic.DeduplicateByFloorSnap
DisturbanceService.ScoreCandidates = HotspotQueryLogic.ScoreCandidates
DisturbanceService.TopContributorsAt = HotspotQueryLogic.TopContributorsAt
DisturbanceService.GetHottestHotspotPure = HotspotQueryLogic.GetHottestHotspot
DisturbanceService.ChunkIdFor = StreamingLogic.ChunkIdFor
DisturbanceService.ChunkCenterFor = StreamingLogic.ChunkCenterFor
DisturbanceService.IsChunkLoadedForPosition = StreamingLogic.IsChunkLoadedForPosition
DisturbanceService.CandidateChunkIdsNear = StreamingLogic.CandidateChunkIdsNear
DisturbanceService.HasCrossedDeltaThreshold = StreamingLogic.HasCrossedDeltaThreshold
DisturbanceService.BuildFloraChunkPayload = StreamingLogic.BuildFloraChunkPayload
DisturbanceService.ComputeChunkFullSnapshot = StreamingLogic.ComputeChunkFullSnapshot
DisturbanceService.ComputeChunkDeltaUpdate = StreamingLogic.ComputeChunkDeltaUpdate
DisturbanceService.RunChunkStreamIn = StreamingLogic.RunChunkStreamIn
DisturbanceService.FireIfStillMember = StreamingLogic.FireIfStillMember
DisturbanceService.ClearPlayerStreamingState = StreamingLogic.ClearPlayerStreamingState
DisturbanceService.CanonicalKeyFor = TierClassificationLogic.CanonicalKeyFor
DisturbanceService.DedupPositionsByCanonicalKey = TierClassificationLogic.DedupPositionsByCanonicalKey
DisturbanceService.TierAt = TierClassificationLogic.TierAt
DisturbanceService.ClassifyWithCascade = TierClassificationLogic.ClassifyWithCascade
DisturbanceService.RunClassificationPass = TierClassificationLogic.RunClassificationPass
DisturbanceService.DirectionFor = BandCrossedLogic.DirectionFor
DisturbanceService.ClassifySquadBandCrossing = BandCrossedLogic.ClassifySquadBandCrossing
DisturbanceService.BuildDeathPayload = DeathFanoutLogic.BuildDeathPayload

-- ============================================================================
-- KnitInit -- builds. Per ADR-0001 Rule 1, every object another service might need to
-- synchronously read/call during its own KnitStart is fully constructed here, never
-- deferred to KnitStart.
-- ============================================================================

function DisturbanceService:KnitInit(): ()
	-- H.3d / H.3e: config-validation hard errors. Per control-manifest.md's binding
	-- Foundation-layer rule (ADR-0005), any KnitInit-time error() here MUST be paired with a
	-- server bootstrap catch handler that calls game:Shutdown() -- that wiring lives in
	-- src/core/ServerBootstrap.luau / src/core/ServerInit.server.luau, not in this file.
	local radiusOk, radiusErr = BootstrapLogic.ValidateInfluenceRadius(DisturbanceConstants.INFLUENCE_RADIUS)
	if not radiusOk then
		error(radiusErr)
	end

	local cellSizeOk, cellSizeErr = BootstrapLogic.ValidateSpatialGridCellSize(
		DisturbanceConstants.SPATIAL_GRID_CELL_SIZE,
		DisturbanceConstants.INFLUENCE_RADIUS
	)
	if not cellSizeOk then
		error(cellSizeErr)
	end

	-- Empty containers only -- per ADR-0004's Architecture Diagram and this story's own Out
	-- of Scope list, none of these are populated here.
	self._spatialGrid = {} :: SpatialGrid
	self._liveSources = {} :: { [string]: EmissionLogic.EmissionPayload } -- keyed by emissionId (Story 002)
	self._attributionArchive = {} :: AttributionArchiveLogic.Archive -- keyed by emissionId (Story 004)

	-- Story 003: the deterministic-tie-break bookkeeping InsertEmission()'s eviction rule
	-- needs (see DisturbanceServiceSpatialGridLogic.luau's FindOldestSourceId header note) --
	-- a monotonic per-emission sequence counter, NOT derived from Luau's own (unordered) table
	-- iteration order.
	self._insertionSequence = {} :: { [string]: number }
	self._nextInsertionSequence = 0

	-- Story 004: the attribution archive's own parallel state -- a live per-entry
	-- referencing-player set (condition (b), scoped to sourcePlayerId only -- see
	-- DisturbanceServiceAttributionArchiveLogic.luau's CONDITION (b) SCOPING note) and its own
	-- independent deterministic-tie-break insertion-sequence counter (mirrors self
	-- ._insertionSequence's own precedent immediately above, but kept as a SEPARATE table/counter
	-- since archive entries outlive live-source-list membership).
	self._attributionReferencingPlayers = {} :: AttributionArchiveLogic.ReferencingPlayers
	self._archiveInsertionSequence = {} :: AttributionArchiveLogic.InsertionSequence
	self._nextArchiveInsertionSequence = 0

	-- TODO(Story 011): DefaultIsEmissionLocked always returns false -- Story 011's predator-lock
	-- registry does not exist yet. Injected as a function value (not called directly at any call
	-- site below) so Story 011 can swap in a real predicate here without touching any archive
	-- call site -- mirrors Stories 002/003's own now/cellSize injection-seam precedent.
	self._isEmissionLocked = AttributionArchiveLogic.DefaultIsEmissionLocked

	-- Story 004: accumulator driving the periodic, low-frequency attribution-archive maintenance
	-- pass (TR-ed-051) -- a SEPARATE accumulator from self._fieldUpdateAccumulator, stepped at
	-- DisturbanceConstants.EXPIRY_MAINTENANCE_INTERVAL (3s) rather than 1/FIELD_UPDATE_HZ (0.2s).
	self._attributionMaintenanceAccumulator = 0

	-- Raw BindableEvent, per the GDD's own frozen C.1.11 mechanism choice (ADR-0004's
	-- OnPlayerDied Decision) -- NOT a Knit Signal. Constructed here (KnitInit, ADR-0001 Rule 1);
	-- fired by the Humanoid.Died chain registered immediately below (Story 010).
	-- Workspace.SignalBehavior is pinned in the server bootstrap script, BEFORE any KnitInit
	-- runs -- not here (see ADR-0004's own code-sample placement).
	self._onPlayerDied = Instance.new("BindableEvent")

	-- Story 010 (TR-ed-030): single-writer mailbox this story writes into at (5a) -- Story 012's
	-- GetDeathAttributionPayload is the reader, using a read-and-clear idiom (out of THIS story's
	-- scope -- see this story's own Implementation Notes). Keyed by Player, one entry per death.
	self._deathLockSnapshot = {} :: { [Player]: boolean }

	-- Story 010 (TR-ed-032): Humanoid.Died sole-subscriber chain -- registered HERE, in KnitInit
	-- (ADR-0001 Rule 1; ADR-0004 Architecture Diagram, fixed 2026-07-06 to KnitInit, not
	-- KnitStart). This is the ONLY `Humanoid.Died:Connect` call anywhere in the entire server
	-- codebase -- a repo-wide static grep in this story's own test file verifies the monopoly;
	-- Story 016's H.39e CI lint later enforces it mechanically project-wide.
	Players.PlayerAdded:Connect(function(player: Player)
		player.CharacterAdded:Connect(function(character: Model)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				self:_onHumanoidDied(player)
			end)
		end)
	end)

	-- Placeholder module reference only -- Story 011 owns its actual exports.
	self._registrationHandshake = require(script.Parent.DisturbanceServiceRegistrationHandshake)

	self._loadedChunks = {} :: { [Player]: { [string]: true } }

	-- Story 014 (TR-ed-009): per-player per-flora last-pushed-t cache, reset on snapshot/drop.
	self._floraDeltaCache = {} :: { [Player]: FloraDeltaCache }

	-- Story 014 (TR-ed-029/N5): two raw RemoteEvents, server-fire-only -- zero OnServerEvent
	-- registrations anywhere in this file (grep-verified by this story's own test suite). This is
	-- the FIRST raw RemoteEvent instance in this codebase -- no prior ReplicatedStorage.RemoteEvents
	-- convention existed, so a get-or-create folder is established here as the project's convention
	-- for future server-pushed-only raw RemoteEvents (ADR-0006's #11 registry entry).
	local remoteEventsFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
	if not remoteEventsFolder then
		remoteEventsFolder = Instance.new("Folder")
		remoteEventsFolder.Name = "RemoteEvents"
		remoteEventsFolder.Parent = ReplicatedStorage
	end

	self._floraChunkUpdateEvent = Instance.new("RemoteEvent")
	self._floraChunkUpdateEvent.Name = "FloraChunkUpdate"
	self._floraChunkUpdateEvent.Parent = remoteEventsFolder

	self._floraChunkInitialSnapshotEvent = Instance.new("RemoteEvent")
	self._floraChunkInitialSnapshotEvent.Name = "FloraChunkInitialSnapshot"
	self._floraChunkInitialSnapshotEvent.Parent = remoteEventsFolder

	-- ASSUMPTION FLAGGED (not silently invented): this codebase has no flora-node registry yet (no
	-- CollectionService tag, no position list) -- the Bioluminescent Flora rendering subsystem the
	-- GDD names as this data's owner is "Not started" per its own dependency table. This injectable
	-- seam mirrors Story 004's DefaultIsEmissionLocked precedent (a stub awaiting a not-yet-built
	-- sibling story) -- defaults to an empty list so this story's own streaming/membership/push
	-- mechanism is fully exercisable and correct against whatever real enumeration is wired in
	-- later, without touching any call site below. Never exposed via .Client.
	self._getFloraNodesInChunk = function(_chunkId: string): { { floraNodeId: string, position: Vector3 } }
		return {}
	end

	self._fieldUpdateAccumulator = 0

	-- Story 005 (TR-ed-017): per-pass decayed-magnitude cache, keyed by emissionId -- computed
	-- at most once per live source per field-update pass by _runFieldUpdatePass below, reused
	-- for every fieldValue() query within that same pass. self._expFn defaults to the real
	-- math.exp; only the server-internal _setExpFn seam (H.9b) may ever swap it, and that seam
	-- is never exposed via .Client (Story 016 verifies).
	self._decayCache = {} :: DecayFalloffLogic.DecayCache
	self._expFn = math.exp

	-- Story 006 (TR-ed-011): position-keyed tier-classification state, keyed by the canonical
	-- %d_%d string (TierClassificationLogic.CanonicalKeyFor) -- NEVER the Vector3 itself (Luau
	-- userdata reference-equality bug).
	self._previousTierAtPosition = {} :: { [string]: TierClassificationLogic.Tier }

	-- Story 006 (TR-ed-037): a NEW cross-service Signal -- NOT the GDD-frozen C.1.11 OnPlayerDied
	-- raw BindableEvent constructed above. Per ADR-0001's general Signal-over-BindableEvent
	-- preference, which applies cleanly here (no ADR-0004-style type tension, since there is no
	-- prior frozen-BindableEvent text governing this specific channel). Constructed here (KnitInit),
	-- not KnitStart, so any subscriber (Predator AI) can safely call GetTierCrossedSignal():Connect()
	-- during its own KnitStart regardless of KnitInit ordering between services (ADR-0001 Rule 1).
	self._tierCrossedEvent = Signal.new()

	-- Story 009 (TR-ed-038): squad-aggregate-keyed band-crossing state -- a SINGLE nilable Tier,
	-- NOT a table keyed by position (contrast self._previousTierAtPosition above, which is
	-- per-position; squadT is one scalar for the whole squad). `nil` here means "no field-update
	-- pass has classified squadT yet this session" -- DisturbanceServiceBandCrossedLogic's own
	-- FIRST-PASS DESIGN CALL note explains why this single nilable field does double duty (flat-
	-- threshold dispatch selection AND first-pass fire suppression) rather than a separate
	-- self._hasClassifiedSquadTierOnce boolean.
	self._previousSquadTier = nil :: TierClassificationLogic.Tier?

	-- Story 009 (TR-ed-038): a NEW cross-service Signal -- mirrors self._tierCrossedEvent's own
	-- ADR-0001 Signal-over-BindableEvent precedent immediately above. Constructed here (KnitInit),
	-- not KnitStart, so any subscriber (Player Controller, out of this epic) can safely call
	-- GetDisturbanceBandCrossedSignal():Connect() during its own KnitStart regardless of KnitInit
	-- ordering between services (ADR-0001 Rule 1).
	self._disturbanceBandCrossedSignal = Signal.new()
end

-- ============================================================================
-- KnitStart -- connects. The field-update Heartbeat loop begins here; its body
-- (_runFieldUpdatePass) stays empty/no-op -- Stories 003-015 extend it.
-- ============================================================================

function DisturbanceService:KnitStart(): ()
	local updateInterval = 1 / DisturbanceConstants.FIELD_UPDATE_HZ

	self._heartbeatConnection = RunService.Heartbeat:Connect(function(dt: number)
		local newAccumulator, shouldFire =
			BootstrapLogic.StepAccumulator(self._fieldUpdateAccumulator, dt, updateInterval)
		self._fieldUpdateAccumulator = newAccumulator
		if shouldFire then
			self:_runFieldUpdatePass()
		end

		-- Story 004 / TR-ed-051: the attribution archive's own low-frequency maintenance-cull
		-- accumulator, stepped at DisturbanceConstants.EXPIRY_MAINTENANCE_INTERVAL -- a SEPARATE
		-- cadence from the field-update accumulator above (reuses the same StepAccumulator
		-- fires-at-most-once-per-call math, per this module's own C.1.13 graceful-skip
		-- semantics, applied here to a different interval).
		local newArchiveAccumulator, shouldRunArchiveMaintenance = BootstrapLogic.StepAccumulator(
			self._attributionMaintenanceAccumulator,
			dt,
			DisturbanceConstants.EXPIRY_MAINTENANCE_INTERVAL
		)
		self._attributionMaintenanceAccumulator = newArchiveAccumulator
		if shouldRunArchiveMaintenance then
			self:_runAttributionArchiveMaintenancePass()

			-- Story 005 / H.9: source-expiry culling runs on the SAME
			-- EXPIRY_MAINTENANCE_INTERVAL cadence as the attribution archive's own maintenance
			-- pass above (a separate, lower-frequency pass from the 5Hz decay-caching pass in
			-- _runFieldUpdatePass) -- exactly "the next maintenance pass" H.9's AC text refers to.
			self:_cullExpiredSources()
		end
	end)

	-- Required cleanup for the one per-player table this story constructs (ADR-0004/
	-- ADR-0006 leak-prevention precedent).
	Players.PlayerRemoving:Connect(function(player: Player)
		self._loadedChunks[player] = nil

		-- Story 014 (TR-ed-009): the per-player per-flora last-pushed-t cache leaks a table per
		-- departed player for the life of the server if not cleared here too (same leak class
		-- ADR-0004's own engine-specialist review already caught for self._loadedChunks above).
		self._floraDeltaCache[player] = nil

		-- Story 010 (code-review fix): a player who dies and then disconnects before Story 012's
		-- read-and-clear reader ever consumes their snapshot entry would otherwise pin their
		-- departed Player instance in this table for the life of the server (same leak class as
		-- the two clears above). Story 012's reader already degrades to nil for an absent key by
		-- design, so clearing here is safe for it.
		self._deathLockSnapshot[player] = nil

		-- Story 004 condition (b): a departed player can no longer reference any archive entry
		-- via sourcePlayerId (this story's own scoped interpretation -- see
		-- DisturbanceServiceAttributionArchiveLogic.luau's CONDITION (b) SCOPING note). Re-run
		-- the full maintenance pass immediately after shrinking the referencer sets so an entry
		-- that just lost its last live referencer purges right away, rather than waiting up to
		-- EXPIRY_MAINTENANCE_INTERVAL seconds for the next periodic tick.
		AttributionArchiveLogic.HandlePlayerDeparture(self._attributionReferencingPlayers, player.UserId)
		self:_runAttributionArchiveMaintenancePass()
	end)
end

-- ============================================================================
-- Story 010 (TR-ed-030/032/044/052/061) -- Humanoid.Died sole-subscriber chain (registered in
-- KnitInit, above) and OnPlayerDied fan-out. All payload-construction math (step 5b) lives in the
-- dependency-free DisturbanceServiceDeathFanoutLogic module (see its own header note for the
-- PLAYER IDENTITY / ORDERING NOTE / NO DEDUP design calls); this file only owns the real
-- self._deathLockSnapshot state table (KnitInit, above), the real self._onPlayerDied BindableEvent
-- (KnitInit, above), the real Humanoid.Died chain registration (KnitInit, above), the real
-- self:_captureDeathLockSnapshot stub immediately below, and the real
-- workspace:GetServerTimeNow() clock sample -- sourced AFTER the snapshot capture (5a), per the
-- AC's own ordering requirement.
--
-- TODO(Story 011): _captureDeathLockSnapshot always returns false. Story 011's predator-lock
-- registry does not exist yet -- this stub keeps predatorWasLockedAtDeath permanently false until
-- Story 011 supplies a real registry lookup, mirroring DisturbanceServiceAttributionArchiveLogic
-- .luau's own DefaultIsEmissionLocked stub precedent from Story 004 (same "-- TODO(Story N)"
-- marker convention, same "stub returns a fixed default until a later story implements the real
-- check" shape). Kept as a plain method here (not an injected function-value seam like
-- DefaultIsEmissionLocked) because this story's own Implementation Notes pin the exact call shape
-- `self:_captureDeathLockSnapshot(deadPlayer)` verbatim -- Story 011 replaces this method's body
-- directly when it lands, rather than swapping an injected callback.
-- ============================================================================

function DisturbanceService:_captureDeathLockSnapshot(_deadPlayer: Player): boolean
	return false
end

--- (5a)-(5c): synchronous, yield-free snapshot-then-fire sequence (REQUIRED -- TR-ed-052). No
--- dedup at this layer (REQUIRED -- see DisturbanceServiceDeathFanoutLogic's own NO DEDUP note):
--- if Humanoid.Died fires twice for the same player (a pathological replication race, Player
--- Controller's own documented assumption per ADR-0005), this method runs its own independently-
--- correct snapshot-then-payload sequence each time it is invoked -- ED performs no
--- de-duplication of its own; each consumer owns its own idempotency (PC's future
--- `_deathInProgress` guard, ADR-0005).
function DisturbanceService:_onHumanoidDied(deadPlayer: Player): ()
	-- (5a) snapshot the predator-lock registry state for this player, synchronously.
	local wasLocked = self:_captureDeathLockSnapshot(deadPlayer) -- see Story 011/012 for the registry itself
	self._deathLockSnapshot[deadPlayer] = wasLocked

	-- (5b) construct payload AFTER the snapshot capture -- ordering matters (AC text): the flag
	-- value must stay consistent with the registry read at (5a), not a later, possibly-already-
	-- released state.
	local now = workspace:GetServerTimeNow()
	local payload = DeathFanoutLogic.BuildDeathPayload(deadPlayer, wasLocked, now)

	-- (5c) fire, synchronous dispatch guaranteed by the Workspace.SignalBehavior pin (Story 001).
	self._onPlayerDied:Fire(payload)
end

-- ============================================================================
-- GetOnPlayerDiedSignal() -- server-internal accessor (Story 010, TR-ed-030/044). SERVER-INTERNAL
-- ONLY -- never exposed via DisturbanceService.Client (this file's `Client = {}` table above stays
-- empty; Story 016's H.39/H.39d CI lint later enforces this mechanically). Returns the SAME
-- BindableEvent instance every call, constructed once in KnitInit (ADR-0001 Rule 1) so a
-- subscriber calling this during its own KnitStart never races construction. Fans out to exactly
-- 3 consumers (Player Controller, Crafting & Items, Predator AI, per this session's TD sign-off)
-- -- a cross-epic expectation documented here, not enforced at runtime by this method itself (see
-- this story's own Implementation Notes; Story 016's CI lint verifies the actual subscriber count
-- once all 3 consuming epics exist).
-- ============================================================================

function DisturbanceService:GetOnPlayerDiedSignal(): BindableEvent
	return self._onPlayerDied
end

-- ============================================================================
-- Field-update pass -- intentionally empty/no-op. Stories 003-015 extend the body (decay
-- pass, tier classification, N7/N8 monitoring, etc.).
-- ============================================================================

function DisturbanceService:_runFieldUpdatePass(): ()
	-- Story 005 (TR-ed-017/018, D.1-D.3): per-source decay caching -- computes m(age) exactly
	-- once per live source this pass and caches it, so fieldValue()/GetHottestHotspot() queries
	-- within the same pass never re-invoke math.exp (H.9b).
	local now = workspace:GetServerTimeNow()
	DecayFalloffLogic.RunDecayPass(
		self._liveSources,
		self._decayCache,
		now,
		DisturbanceConstants.STANDARD_HALF_LIFE,
		DisturbanceConstants.BEACON_HALF_LIFE,
		DisturbanceConstants.MAGNITUDE_FLOOR,
		self._expFn
	)

	-- Story 014 (TR-ed-008/009/029): StreamingEnabled chunk membership + flora chunk
	-- snapshot/update push -- its own clearly-delimited step, called AFTER the decay pass above so
	-- this pass's fieldValue() reads (inside _runStreamingChunkPushPass) consume this SAME pass's
	-- freshly-cached decay values (TR-ed-017). Deliberately a single call to its own method, kept
	-- separate from any other story's own additions to this function.
	self:_runStreamingChunkPushPass()

	-- Story 006 (TR-ed-011/037/054/070, D.4/C.3.3): tier classification + post-hitch cascade +
	-- server-side per-pass coalescing -- its own clearly-delimited step, called AFTER the decay
	-- pass above so this pass's fieldValue() reads (inside _runTierClassificationPass) consume
	-- this SAME pass's freshly-cached decay values (TR-ed-017). Order relative to the streaming
	-- push pass above is immaterial -- neither reads nor mutates the other's state, both only
	-- read this pass's already-computed decay cache via fieldValue().
	self:_runTierClassificationPass()

	-- Story 009 (TR-ed-038): squad-aggregate-keyed band-crossing signal -- its own clearly-
	-- delimited step, called AFTER the decay pass above so this pass's GetSquadAggregateT(nil)
	-- read (inside _runBandCrossedPass) consumes this SAME pass's freshly-cached decay values
	-- (TR-ed-017, transitively via each member's fieldValue() read). Order relative to
	-- _runStreamingChunkPushPass/_runTierClassificationPass above is immaterial -- this step
	-- neither reads nor mutates self._previousTierAtPosition/self._floraDeltaCache/
	-- self._loadedChunks, and is not read or mutated by either of those steps in turn; it only
	-- reads/writes its OWN self._previousSquadTier state.
	self:_runBandCrossedPass()
end

-- ============================================================================
-- Source-expiry culling (Story 005, H.9) -- removes every source whose most recent decay-cache
-- entry is expired from ALL FOUR parallel stores: self._liveSources, its self._spatialGrid cell
-- bucket, self._decayCache, and self._insertionSequence. Runs on the EXPIRY_MAINTENANCE_INTERVAL
-- cadence (KnitStart, above), alongside Story 004's own attribution-archive maintenance pass.
-- This orchestration cannot live inside DisturbanceServiceDecayFalloffLogic.luau itself (that
-- module never touches self._spatialGrid / SpatialGridLogic -- see its own CANDIDATE
-- ENUMERATION OWNERSHIP header note), which is why this thin wrapper composes
-- DecayFalloffLogic.FindExpiredSourceIds with SpatialGridLogic.RemoveSourceFromGridCell itself.
-- ============================================================================

function DisturbanceService:_cullExpiredSources(): ()
	local expiredIds = DecayFalloffLogic.FindExpiredSourceIds(self._liveSources, self._decayCache)

	for _, emissionId in expiredIds do
		local source = self._liveSources[emissionId]
		if source then
			local cellX, cellZ = SpatialGridLogic.CellCoordFor(source.position, DisturbanceConstants.SPATIAL_GRID_CELL_SIZE)
			SpatialGridLogic.RemoveSourceFromGridCell(self._spatialGrid, cellX, cellZ, emissionId)
		end
		self._liveSources[emissionId] = nil
		self._decayCache[emissionId] = nil
		self._insertionSequence[emissionId] = nil
	end
end

-- ============================================================================
-- Story 014 (TR-ed-008/009/029/031/050/060/064) -- StreamingEnabled chunk membership & flora
-- chunk snapshot/update push. All chunk-id encoding, XZ-only distance math, delta-threshold
-- comparison, wire payload format, N2/N9 ordering, and fire-time membership-gating live in the
-- dependency-free DisturbanceServiceStreamingLogic module (see its own header note for why); this
-- file only owns the real self._loadedChunks/self._floraDeltaCache state (KnitInit, above), the
-- two real RemoteEvent Instances (KnitInit, above), and the real Character/HumanoidRootPart
-- .Position reads below.
--
-- ADR-0004 N1 (SECURITY, REQUIRED, TR-ed-031/TR-ed-064): loadedChunks[player] is computed
-- ENTIRELY from the server-tracked position read below -- the client-writable streaming-focus
-- property ADR-0004's N1 Decision names and forbids is NEVER read or watched anywhere in this
-- section (H.31b's own security lint checks for the literal property name's absence from this
-- file's source, so it is deliberately never spelled out here either -- see this story's own test
-- file for the documented raw-source-scanning rationale). Worst-case failure mode of the
-- position-based approximation is a bandwidth/timing nicety (slightly early/late push), never a
-- security or correctness issue, per ADR-0004's own Consequences section.
-- ============================================================================

--- Mirrors GetSquadAggregateT's own rootPart-lookup precedent above: a player with no live
--- Character/HumanoidRootPart simply yields nil (omitted from this pass' chunk-membership scan),
--- exactly as a not-yet-spawned player contributes nothing.
function DisturbanceService:_getServerTrackedPosition(player: Player): Vector3?
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then
		return nil
	end
	return rootPart.Position
end

function DisturbanceService:_isChunkLoadedForPlayer(player: Player, chunkId: string): boolean
	local playerPos = self:_getServerTrackedPosition(player)
	if not playerPos then
		return false
	end
	local chunkCenter = StreamingLogic.ChunkCenterFor(chunkId, DisturbanceConstants.CHUNK_DIMENSIONS)
	return StreamingLogic.IsChunkLoadedForPosition(playerPos, chunkCenter, DisturbanceConstants.STREAMING_PUSH_RADIUS)
end

--- Synchronous, no-yield snapshot compute (N2/N9 step 2): evaluates self:fieldValue() (Story 005's
--- per-pass-cached accessor -- TR-ed-017, never re-invokes math.exp) at every flora node's position
--- in this chunk, per self._getFloraNodesInChunk's own ASSUMPTION-FLAGGED seam (KnitInit, above).
function DisturbanceService:_computeChunkSnapshot(chunkId: string): StreamingLogic.ChunkPushPayload
	local floraNodes = self._getFloraNodesInChunk(chunkId)
	local floraStates: { [string]: number } = {}
	for _, node in floraNodes do
		floraStates[node.floraNodeId] = self:fieldValue(node.position)
	end
	local payload, _freshCache = StreamingLogic.ComputeChunkFullSnapshot(chunkId, floraStates)
	return payload
end

--- N2/N9 step 4: resets this player's per-flora last-pushed-t cache to the just-fired snapshot's
--- OWN values (TR-ed-009). `snapshotPayload` is `{chunkId, floraPairs}`; `floraPairs[i]` is
--- `{floraNodeId, targetT}` (StreamingLogic.ChunkPushPayload's own positional wire format).
function DisturbanceService:_resetFloraDeltaCache(player: Player, _chunkId: string, snapshotPayload: StreamingLogic.ChunkPushPayload): ()
	local floraPairs = snapshotPayload[2] :: { { any } }
	local cache = self._floraDeltaCache[player]
	if not cache then
		cache = {}
		self._floraDeltaCache[player] = cache
	end
	for _, pair in floraPairs do
		cache[pair[1]] = pair[2]
	end
end

--- N2/N9 -- one atomic, yield-free chunk-stream-in sequence (cited verbatim from ADR-0004's Key
--- Interfaces). Delegates the exact 4-step ordering to StreamingLogic.RunChunkStreamIn; this
--- method only supplies the real callbacks (real snapshot compute, real Fire, real cache reset).
---
--- REAL-API RECONCILIATION NOTE (deviation from ADR-0004's own pseudocode, flagged explicitly):
--- ADR-0004's Key Interfaces sample writes `self._floraChunkInitialSnapshot:Fire(player, snapshot)`,
--- but N5's own Decision text is explicit these are RAW Roblox RemoteEvents, not Knit
--- RemoteSignals -- a raw RemoteEvent's real server->single-client dispatch method is
--- `:FireClient(player, ...)`, not `:Fire(player, ...)` (`:Fire` is Knit RemoteSignal's / raw
--- BindableEvent's method). Implemented here using the real `:FireClient` API for a raw
--- RemoteEvent Instance, per N5's own explicit "raw RemoteEvent" decision.
function DisturbanceService:_onChunkStreamIn(player: Player, chunkId: string): ()
	StreamingLogic.RunChunkStreamIn(
		self._loadedChunks[player],
		chunkId,
		function()
			return self:_computeChunkSnapshot(chunkId)
		end,
		function(snapshot)
			self._floraChunkInitialSnapshotEvent:FireClient(player, snapshot)
		end,
		function(snapshot)
			self:_resetFloraDeltaCache(player, chunkId, snapshot)
		end
	)
end

--- Chunk stream-out for one player: removes the chunk from that player's loadedChunks membership
--- set, and defensively clears that chunk's flora entries from this player's delta cache
--- (TR-ed-009's "reset ... on ... drop" -- a later stream-back-in re-derives fresh values via
--- _onChunkStreamIn's own N2/N9 step-4 cache reset regardless, so this is defense-in-depth against
--- a stale entry lingering in this player's cache table, not load-bearing for correctness on its
--- own).
function DisturbanceService:_dropChunkForPlayer(player: Player, chunkId: string): ()
	self._loadedChunks[player][chunkId] = nil

	local floraNodes = self._getFloraNodesInChunk(chunkId)
	local cache = self._floraDeltaCache[player]
	if cache then
		for _, node in floraNodes do
			cache[node.floraNodeId] = nil
		end
	end
end

--- Per-field-update-pass orchestration (called once per _runFieldUpdatePass tick, above -- max
--- FIELD_UPDATE_HZ/sec): for every connected player, (1) adds any newly-in-range chunk via the
--- N2/N9 atomic sequence, (2) drops any chunk that fell out of range, then (3) computes and fires a
--- delta-filtered FloraChunkUpdate for every chunk still loaded for that player -- empty-array
--- suppression (REQUIRED): a chunk with zero crossed flora this tick fires nothing at all.
--- Membership is re-checked at the EXACT fire call via StreamingLogic.FireIfStillMember (REQUIRED),
--- closing the stream-out/stream-in race window step (2) above could open earlier in this SAME
--- pass.
function DisturbanceService:_runStreamingChunkPushPass(): ()
	for _, player: Player in Players:GetPlayers() do
		local playerPos = self:_getServerTrackedPosition(player)
		if not playerPos then
			continue
		end

		if not self._loadedChunks[player] then
			self._loadedChunks[player] = {}
		end
		local loadedChunksForPlayer = self._loadedChunks[player]

		-- Additions: any candidate chunk near the player, not already loaded, whose center is now
		-- within STREAMING_PUSH_RADIUS (N1).
		local candidateIds = StreamingLogic.CandidateChunkIdsNear(
			playerPos,
			DisturbanceConstants.CHUNK_DIMENSIONS,
			DisturbanceConstants.STREAMING_PUSH_RADIUS
		)
		for _, chunkId in candidateIds do
			if not loadedChunksForPlayer[chunkId] and self:_isChunkLoadedForPlayer(player, chunkId) then
				self:_onChunkStreamIn(player, chunkId)
			end
		end

		-- Removals: any currently-loaded chunk whose center is no longer within radius. The key
		-- list is snapshotted first -- mutating loadedChunksForPlayer while iterating it directly
		-- is unsafe in Luau.
		local currentlyLoadedIds: { string } = {}
		for chunkId in loadedChunksForPlayer do
			table.insert(currentlyLoadedIds, chunkId)
		end
		for _, chunkId in currentlyLoadedIds do
			if not self:_isChunkLoadedForPlayer(player, chunkId) then
				self:_dropChunkForPlayer(player, chunkId)
			end
		end

		-- Per-tick delta push: "active chunk" (C.3.5) reduces here to "every chunk still in this
		-- player's own loadedChunks set" -- since loadedChunks[player] is ALREADY exactly "within
		-- STREAMING_PUSH_RADIUS of this player," iterating it per-player is equivalent to (and
		-- simpler than) computing a separate global active-chunk union first.
		for chunkId in loadedChunksForPlayer do
			local floraNodes = self._getFloraNodesInChunk(chunkId)
			local floraStates: { [string]: number } = {}
			for _, node in floraNodes do
				floraStates[node.floraNodeId] = self:fieldValue(node.position)
			end

			local cache = self._floraDeltaCache[player]
			if not cache then
				cache = {}
				self._floraDeltaCache[player] = cache
			end

			local payload, updatedCacheValues = StreamingLogic.ComputeChunkDeltaUpdate(
				chunkId,
				floraStates,
				cache,
				DisturbanceConstants.FLORA_UPDATE_DELTA_THRESHOLD
			)

			if payload then
				StreamingLogic.FireIfStillMember(loadedChunksForPlayer, chunkId, function()
					self._floraChunkUpdateEvent:FireClient(player, payload)
				end)
			end

			for floraNodeId, value in updatedCacheValues do
				cache[floraNodeId] = value
			end
		end
	end
end

-- ============================================================================
-- Story 006 (TR-ed-011/037/054/070, D.4/C.3.3) -- tier classification, post-hitch cascade, and
-- server-side per-pass coalescing. All hysteresis/cascade/coalescing math lives in the
-- dependency-free DisturbanceServiceTierClassificationLogic module (see its own header note for
-- the TierAt signature deviation and the RETREAT CEILING / DOWNWARD-HYSTERESIS design calls);
-- this file only owns the real self._previousTierAtPosition state table (KnitInit, above), the
-- real self._tierCrossedEvent Signal (KnitInit, above), the real live-source-position enumeration
-- below, and the real self:fieldValue()/self:_topContributorsAt() + self._liveSources lookups the
-- module's injected callbacks delegate to.
--
-- POSITION ENUMERATION (design call, flagged): each pass classifies the canonical-key-deduplicated
-- set of CURRENTLY-LIVE emission source positions (self._liveSources, deduped via
-- TierClassificationLogic.DedupPositionsByCanonicalKey, first-encountered-wins) -- not an
-- independently-tracked position registry. KNOWN GAP (intentionally out of this story's scope,
-- not silently papered over): if a position's ONLY originating live source fully expires and is
-- culled (Story 005's maintenance pass) with no other nearby source still live, that position's
-- self._previousTierAtPosition entry is no longer re-enumerated by this pass and can remain stuck
-- at an elevated tier indefinitely instead of decaying back down to Calm and being pruned. No
-- Acceptance Criterion in this story requires closing this gap (every AC scenario keeps at least
-- one live source at the tested position throughout), but it is a real latent correctness gap for
-- a future maintenance pass to close.
-- ============================================================================

function DisturbanceService:_runTierClassificationPass(): ()
	local rawPositions: { Vector3 } = {}
	for _, source in self._liveSources do
		table.insert(rawPositions, source.position)
	end
	local positionEntries = TierClassificationLogic.DedupPositionsByCanonicalKey(rawPositions)

	local events = TierClassificationLogic.RunClassificationPass(
		positionEntries,
		self._previousTierAtPosition,
		function(position: Vector3): number
			return self:fieldValue(position)
		end,
		function(position: Vector3): (string, number)
			-- Resolved ONLY for coalescing winners (RunClassificationPass's own bounded-cost
			-- design) -- top-1 contributor's own fixed initialMagnitude field, per this story's
			-- confirmed interpretation of C.3.3's payload semantics under coalescing.
			local topIds = self:_topContributorsAt(position, 1)
			local topEmissionId = topIds[1]
			if not topEmissionId then
				-- Defensive fallback only -- should not occur, since `position` always originates
				-- from a live source within INFLUENCE_RADIUS of itself (distance 0).
				return "", 0
			end
			local source = self._liveSources[topEmissionId]
			return topEmissionId, if source then source.initialMagnitude else 0
		end,
		DisturbanceConstants.TENSE_THRESHOLD,
		DisturbanceConstants.HUNT_THRESHOLD,
		DisturbanceConstants.HYSTERESIS_BAND,
		DisturbanceConstants.MAX_TIER_CASCADE_ITERATIONS
	)

	for _, event in events do
		self._tierCrossedEvent:Fire(event.crossedTier, event.position, event.emissionId, event.initialMagnitude)
	end
end

-- ============================================================================
-- GetTierCrossedSignal() -- server-internal accessor (Story 006, TR-ed-037). SERVER-INTERNAL ONLY
-- -- never exposed via DisturbanceService.Client (this file's `Client = {}` table above stays
-- empty). Naming matches this codebase's actually-SHIPPED RunController.GetRunEndedSignal()
-- precedent (drops "On"/verb-form padding, pairs the core noun directly with "Signal") --
-- GetOnPlayerDiedSignal() is still-unimplemented ADR-0004 prose (Story 010), not a shipped
-- convention, so it is not treated as binding here. Returns the SAME Signal instance every call,
-- constructed once in KnitInit (ADR-0001 Rule 1) so a subscriber calling this during its own
-- KnitStart never races construction.
-- ============================================================================

function DisturbanceService:GetTierCrossedSignal()
	return self._tierCrossedEvent
end

-- ============================================================================
-- Story 009 (TR-ed-038) -- squad-aggregate-keyed band-crossing signal. All classification/
-- direction/first-pass math lives in the dependency-free DisturbanceServiceBandCrossedLogic
-- module (see its own header notes for the CALLBACK-INJECTION DESIGN, FIRST-PASS DESIGN CALL, and
-- DIRECTION-ONCE-PER-CASCADE design calls); this file only owns the real self._previousSquadTier
-- state (KnitInit, above), the real self._disturbanceBandCrossedSignal Signal (KnitInit, above),
-- the real self:GetSquadAggregateT(nil) UNFILTERED read below (Story 007 -- this signal is
-- squad-wide, not per-excluded-player), the real TierClassificationLogic.ClassifyWithCascade
-- function value passed as `classifyWithCascadeFn` (CALLBACK-INJECTION DESIGN -- BandCrossedLogic
-- itself never require()s TierClassificationLogic, since script.Parent-relative require() is
-- unresolvable under this project's loadstring-based Lune test harness, mirroring
-- DisturbanceServiceHotspotQueryLogic's own precedent), and the real workspace:GetServerTimeNow()
-- clock sample.
--
-- CLOCK-SAMPLE-ONCE-PER-PASS (design call, flagged): `now` is sampled exactly ONCE per call to
-- this method, before the fire loop, and the SAME value is used to stamp every event fired this
-- pass (rather than re-sampling workspace:GetServerTimeNow() once per event inside the loop).
-- Mirrors this file's own established "compute once per pass, reuse for every event/query within
-- that pass" discipline (TR-ed-017's decay-cache-frozen-per-pass precedent, applied here to the
-- clock read rather than a decay computation) -- all events fired by one field-update pass
-- legitimately share one "fire time." AC-H.28d's own text only requires "timestamp from
-- workspace:GetServerTimeNow() at fire time," which a single per-pass sample satisfies exactly
-- (the pass IS the fire time for every event it produces).
--
-- NO _setTestClock SEAM (discrepancy, flagged): the story's own AC text parenthetically mentions
-- "deterministic in tests via the _setTestClock seam," but no such seam exists anywhere in this
-- file (or anywhere else in this codebase, confirmed by search) -- every other
-- workspace:GetServerTimeNow() call site in this file (the decay pass, _topContributorsAt,
-- _runAttributionArchiveMaintenancePass, Emit) samples the real clock directly with no injectable
-- override. This method follows that SAME established real-clock-sampling precedent rather than
-- introducing a one-off seam found nowhere else in this service; the integration test below
-- verifies the classification/direction/event-count/first-pass behavior entirely through the pure
-- DisturbanceServiceBandCrossedLogic module and a fake per-test clock function on the test
-- harness's own Fake service (mirroring Story 006's tier-crossed-signal-subscription_test.luau
-- harness precedent), never through the real workspace clock.
-- ============================================================================

function DisturbanceService:_runBandCrossedPass(): ()
	local squadT = self:GetSquadAggregateT(nil)

	local finalTier, events = BandCrossedLogic.ClassifySquadBandCrossing(
		squadT,
		self._previousSquadTier,
		TierClassificationLogic.ClassifyWithCascade,
		DisturbanceConstants.TENSE_THRESHOLD,
		DisturbanceConstants.HUNT_THRESHOLD,
		DisturbanceConstants.HYSTERESIS_BAND,
		DisturbanceConstants.MAX_TIER_CASCADE_ITERATIONS
	)

	self._previousSquadTier = finalTier

	if #events > 0 then
		local now = workspace:GetServerTimeNow()
		for _, event in events do
			self._disturbanceBandCrossedSignal:Fire(event.direction, event.newTier, now)
		end
	end
end

-- ============================================================================
-- GetDisturbanceBandCrossedSignal() -- server-internal accessor (Story 009, TR-ed-038).
-- SERVER-INTERNAL ONLY -- never exposed via DisturbanceService.Client (this file's `Client = {}`
-- table above stays empty). Naming matches GetTierCrossedSignal()'s own established convention
-- (drops "On"/verb-form padding, pairs the core noun directly with "Signal"). Returns the SAME
-- Signal instance every call, constructed once in KnitInit (ADR-0001 Rule 1) so a subscriber
-- calling this during its own KnitStart never races construction.
-- ============================================================================

function DisturbanceService:GetDisturbanceBandCrossedSignal()
	return self._disturbanceBandCrossedSignal
end

-- ============================================================================
-- fieldValue() -- server-internal public accessor (Story 005, D.3). Enumerates candidates via
-- Story 003's 3x3 grid-neighborhood primitive, per ADR-0004's own "iterates
-- grid[cellX +/-1][cellZ +/-1] around the query point, exactly matching the GDD's own
-- implementation note" Decision text -- then delegates the actual falloff/aggregation math to
-- DecayFalloffLogic.FieldValueAt, which reads the CURRENT pass's cached decay values only (never
-- re-invokes math.exp -- TR-ed-017).
-- ============================================================================

function DisturbanceService:fieldValue(position: Vector3): number
	local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, DisturbanceConstants.SPATIAL_GRID_CELL_SIZE)
	local candidateIds = SpatialGridLogic.QueryNeighborhood(self._spatialGrid, cellX, cellZ)

	return DecayFalloffLogic.FieldValueAt(
		position,
		candidateIds,
		self._liveSources,
		self._decayCache,
		DisturbanceConstants.INFLUENCE_RADIUS
	)
end

-- ============================================================================
-- GetSquadAggregateT() -- server-internal public accessor (Story 007, D.5/D.6b). SERVER-INTERNAL
-- ONLY -- never exposed via DisturbanceService.Client (this file's `Client = {}` table above stays
-- empty; Story 016's H.39/H.39d CI lint later enforces this mechanically).
--
-- This is the FROZEN cross-GDD contract Predator AI's approved GDD depends on (round-23 B1
-- closure, TR-pa-004): PA's Hunt->Disengage quiet-check reads
-- `GetSquadAggregateT(excludeLockedPlayer)` so the locked target's own forced-survival sprint can
-- never keep the unfiltered squadT loud.
--
-- Gathers each connected player's server-observed HumanoidRootPart.Position (mirroring
-- PlayerControllerService's own _getServerPosition precedent -- a player with no live
-- Character/HumanoidRootPart is simply omitted from the `members` list, exactly as a
-- not-yet-spawned player contributes nothing to D.5's max) and this pass's cached fieldValue() for
-- that position (TR-ed-017 -- no re-invocation of math.exp), then delegates ALL max/exclusion/
-- finiteness-guard math to DisturbanceServiceSquadAggregateLogic.ComputeSquadAggregateT -- O(P)
-- fieldValue reads, P<=4, cheap enough for Predator AI's 4Hz cadence.
-- ============================================================================

function DisturbanceService:GetSquadAggregateT(excludePlayer: Player?): number
	local members: { SquadAggregateLogic.SquadMember } = {}

	for _, player: Player in Players:GetPlayers() do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			table.insert(members, { player = player, position = rootPart.Position })
		end
	end

	return SquadAggregateLogic.ComputeSquadAggregateT(members, excludePlayer, function(position: Vector3): number
		return self:fieldValue(position)
	end)
end

-- ============================================================================
-- _topContributorsAt() -- server-internal helper (Story 008, D.6 step 4). Enumerates candidates
-- via the SAME fixed 3x3 QueryNeighborhood primitive fieldValue() uses (this sub-step genuinely
-- operates on the fixed INFLUENCE_RADIUS, matching ADR-0004's "grid[cellX +/-1][cellZ +/-1]"
-- language for this specific step -- see DisturbanceServiceHotspotQueryLogic.luau's own
-- SPATIAL-GRID QUERY-PRIMITIVE NOTE), then delegates ranking/age math to
-- HotspotQueryLogic.TopContributorsAt.
-- ============================================================================

function DisturbanceService:_topContributorsAt(position: Vector3, n: number): ({ string }, number)
	local cellX, cellZ = SpatialGridLogic.CellCoordFor(position, DisturbanceConstants.SPATIAL_GRID_CELL_SIZE)
	local candidateIds = SpatialGridLogic.QueryNeighborhood(self._spatialGrid, cellX, cellZ)
	local now = workspace:GetServerTimeNow()

	return HotspotQueryLogic.TopContributorsAt(
		position,
		n,
		candidateIds,
		self._liveSources,
		self._decayCache,
		DisturbanceConstants.INFLUENCE_RADIUS,
		now,
		DecayFalloffLogic.dist2D,
		DecayFalloffLogic.Contribution
	)
end

-- ============================================================================
-- GetHottestHotspot() -- server-internal public accessor (Story 008, D.6). SERVER-INTERNAL ONLY
-- -- never exposed via DisturbanceService.Client (this file's `Client = {}` table above stays
-- empty). `callerPosition` is supplied by the caller (Predator AI) -- this method NEVER pulls a
-- position via Knit.GetService, preserving F.1's "no MVP-internal hard dependencies" rule
-- (TR-ed-046, round-17 I16-11).
--
-- Enumerates candidates via SpatialGridLogic.QueryCellsInRadius (the general cell-range
-- primitive -- NOT the fixed 3x3 QueryNeighborhood; see DisturbanceServiceHotspotQueryLogic
-- .luau's own SPATIAL-GRID QUERY-PRIMITIVE NOTE for why GetHottestHotspot's outer candidate
-- enumeration needs a different primitive from fieldValue()'s/topContributorsAt's fixed-radius
-- scan), maps ids to live positions, then delegates ALL dedup/scoring/non-finite-disqualification/
-- result-construction math to HotspotQueryLogic.GetHottestHotspot -- passing this service's own
-- fieldValue()/_topContributorsAt() methods and DecayFalloffLogic.dist2DSquared as the injected
-- callbacks (see that module's own CALLBACK-INJECTION DESIGN header note for why).
--
-- Does NOT implement PathfindingService:FindPathAsync (TR-ed-034) -- entirely Predator AI's
-- scope; this method only ever supplies `position` as a navigation target. `secondBestPosition`
-- is explicitly NOT implemented (removed for MVP per the GDD -- no flank/distract mechanic).
-- ============================================================================

function DisturbanceService:GetHottestHotspot(
	callerPosition: Vector3,
	searchRadius: number,
	minimumTier: string
): HotspotQueryLogic.HotspotResult?
	local candidateIds =
		SpatialGridLogic.QueryCellsInRadius(self._spatialGrid, callerPosition, searchRadius, DisturbanceConstants.SPATIAL_GRID_CELL_SIZE)

	local rawCandidatePositions: { Vector3 } = {}
	for _, emissionId in candidateIds do
		local source = self._liveSources[emissionId]
		if source then
			table.insert(rawCandidatePositions, source.position)
		end
	end

	return HotspotQueryLogic.GetHottestHotspot(
		callerPosition,
		searchRadius,
		minimumTier,
		rawCandidatePositions,
		DisturbanceConstants.TENSE_THRESHOLD,
		DisturbanceConstants.HUNT_THRESHOLD,
		DisturbanceConstants.HOTSPOT_DEDUP_GRID_SIZE,
		DecayFalloffLogic.dist2DSquared,
		function(position: Vector3): number
			return self:fieldValue(position)
		end,
		function(position: Vector3): ({ string }, number)
			return self:_topContributorsAt(position, 3)
		end
	)
end

-- ============================================================================
-- _setExpFn() -- server-internal test seam ONLY (H.9b). Swaps self._expFn, consumed by
-- _runFieldUpdatePass's DecayFalloffLogic.RunDecayPass call above. Mirrors this service's own
-- established now/cellSize injection-seam precedent (Stories 002/003) -- NEVER exposed via
-- .Client (Story 016's H.39d-class lint would catch it if it ever were).
-- ============================================================================

function DisturbanceService:_setExpFn(fn: (number) -> number): ()
	self._expFn = fn
end

-- ============================================================================
-- Attribution-archive maintenance pass (Story 004) -- the periodic, low-frequency cull TR-ed-051
-- requires. Runs TTL/condition-b/condition-c purge, then defensive cap enforcement (see
-- DisturbanceServiceAttributionArchiveLogic.RunMaintenancePass's own doc comment). Called on
-- EXPIRY_MAINTENANCE_INTERVAL-cadenced Heartbeat ticks (KnitStart, above) and immediately after
-- every Players.PlayerRemoving departure (condition (b)'s re-evaluation, above). A future Story
-- 017 wraps THIS call site in debug.profilebegin/profileend instrumentation -- not fenced yet,
-- per this story's own scope.
-- ============================================================================

function DisturbanceService:_runAttributionArchiveMaintenancePass(): ()
	local now = workspace:GetServerTimeNow()

	local _purgedIds, capEvictedIds, evictionFailed = AttributionArchiveLogic.RunMaintenancePass(
		self._attributionArchive,
		self._attributionReferencingPlayers,
		self._archiveInsertionSequence,
		self._isEmissionLocked,
		now,
		DisturbanceConstants.ATTRIBUTION_ARCHIVE_TTL,
		DisturbanceConstants.MAX_ATTRIBUTION_ARCHIVE_ENTRIES
	)

	for _, emissionId in capEvictedIds do
		warn(
			("DisturbanceService: attribution archive cap-evicted oldest unlocked entry during maintenance pass: emissionId=%s"):format(
				emissionId
			)
		)
	end

	if evictionFailed then
		warn(
			("DisturbanceService: attribution archive cap exceeded, cannot evict: all entries locked: maxEntries=%d"):format(
				DisturbanceConstants.MAX_ATTRIBUTION_ARCHIVE_ENTRIES
			)
		)
	end
end

-- ============================================================================
-- Emit() -- server-internal emission intake (Story 002).
--
-- SERVER-INTERNAL ONLY. Per ADR-0004 / GDD C.1.8's "No client-callable emission path" rule
-- (control-manifest.md Core-layer Forbidden rule), no RemoteEvent, RemoteFunction,
-- BindableEvent, or DisturbanceService.Client method may call this, directly or indirectly --
-- this file's `Client = {}` table above stays empty; a future feature that conceptually
-- requires "the client caused this emission" MUST route through a server-side authority that
-- validates the action and then calls Emit() itself. Story 016's H.39/H.39d CI lint later
-- enforces this mechanically -- this story only ensures it does not introduce such a path.
--
-- Fire-and-forget: no acknowledgment is returned to the caller, and this method never errors --
-- a rejected emission is logged via warn() and silently dropped, so a caller (e.g. the Gather
-- reward path) can never be blocked by a disturbance-side rejection (C.3.1 emit-before-reward
-- ordering: the gather reward is still granted even if Emit() rejects).
-- ============================================================================

function DisturbanceService:Emit(
	emissionType: EmissionLogic.EmissionType,
	position: Vector3,
	initialMagnitude: number,
	sourcePlayerId: number,
	attributionChain: { string }
): ()
	-- H.7b: workspace:GetServerTimeNow() is the SOLE permitted clock source on this path --
	-- os.time()/tick()/os.clock() are forbidden anywhere on the Emit() path (this file and
	-- DisturbanceServiceEmissionLogic.luau).
	local now = workspace:GetServerTimeNow()
	-- emissionId is generated server-side ONLY -- never accept a caller-supplied id (GDD E.20).
	local emissionId = HttpService:GenerateGUID(false)

	local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
		emissionType,
		position,
		initialMagnitude,
		sourcePlayerId,
		attributionChain,
		now,
		emissionId
	)

	if not payload then
		local info = rejection :: EmissionLogic.EmissionRejection
		warn(
			("DisturbanceService:Emit() rejected: reason=%s field=%s sourcePlayerId=%s emissionType=%s"):format(
				info.reason,
				info.field,
				tostring(info.sourcePlayerId),
				tostring(info.emissionType)
			)
		)
		return
	end

	-- Story 003: insert into both the live-source list and the payload's spatial-grid cell,
	-- cap-evicting the single oldest live source first if already at MAX_LIVE_SOURCES
	-- (ADR-0004's Q3 evict-oldest policy -- Emit() itself never rejects on cap). `cellSize` is
	-- passed explicitly from DisturbanceConstants -- see DisturbanceServiceSpatialGridLogic
	-- .luau's header note on why the module's own fallback is never relied upon here. Story 004
	-- owns the attribution archive entry, which this call never reads or writes.
	local evicted, updatedNextSequence = SpatialGridLogic.InsertEmission(
		self._spatialGrid,
		self._liveSources,
		self._insertionSequence,
		self._nextInsertionSequence,
		DisturbanceConstants.MAX_LIVE_SOURCES,
		payload,
		DisturbanceConstants.SPATIAL_GRID_CELL_SIZE
	)
	self._nextInsertionSequence = updatedNextSequence

	if evicted then
		-- Story 005: the decay cache is a fourth parallel per-source store (alongside
		-- self._liveSources / self._spatialGrid / self._insertionSequence, all cleared above by
		-- SpatialGridLogic.InsertEmission's eviction). It must be cleared here too, or the evicted
		-- source's cache entry is stranded permanently -- _cullExpiredSources only ever iterates
		-- self._liveSources, so a cap-evicted (not TTL-expired) source's decay cache entry would
		-- never be discovered or freed for the life of the server process.
		self._decayCache[evicted.emissionId] = nil

		warn(
			("DisturbanceService:Emit() cap-evicted oldest live source: emissionId=%s sourcePlayerId=%s emissionType=%s emissionTime=%.3f")
				:format(evicted.emissionId, tostring(evicted.sourcePlayerId), tostring(evicted.emissionType), evicted.emissionTime)
		)
	end

	-- Story 004: write-once attribution archive entry, independent of the live-source-list write
	-- above -- this call never reads or writes self._spatialGrid/self._liveSources, and the
	-- SpatialGridLogic eviction above never reads or writes self._attributionArchive (see
	-- DisturbanceServiceSpatialGridLogic.luau's own ARCHIVE INDEPENDENCE note). Runs
	-- UNCONDITIONALLY, exactly once per Emit() call -- deliberately NOT nested under
	-- `if evicted then`, so a Story 003 live-source cap-eviction can never suppress this write
	-- and never triggers an extra one either.
	local archiveEntry = AttributionArchiveLogic.BuildEntry(payload)
	local archiveEvictedId, archiveEvictionFailed, updatedNextArchiveSequence = AttributionArchiveLogic.InsertEntry(
		self._attributionArchive,
		self._attributionReferencingPlayers,
		self._archiveInsertionSequence,
		self._nextArchiveInsertionSequence,
		DisturbanceConstants.MAX_ATTRIBUTION_ARCHIVE_ENTRIES,
		archiveEntry,
		self._isEmissionLocked
	)
	self._nextArchiveInsertionSequence = updatedNextArchiveSequence

	if archiveEvictedId then
		warn(
			("DisturbanceService:Emit() attribution archive cap-evicted oldest unlocked entry: emissionId=%s sourcePlayerId=%s"):format(
				archiveEvictedId,
				tostring(sourcePlayerId)
			)
		)
	elseif archiveEvictionFailed then
		warn(
			("DisturbanceService:Emit() attribution archive cap exceeded, cannot evict: all entries locked: maxEntries=%d"):format(
				DisturbanceConstants.MAX_ATTRIBUTION_ARCHIVE_ENTRIES
			)
		)
	end
end

return DisturbanceService
