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
--   - Story 003: spatial grid insertion/removal/query logic
--   - Story 004: attribution archive TTL/cap-eviction logic
--   - Story 010: Humanoid.Died subscription chain body and OnPlayerDied fan-out dispatch
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
-- Session-scoped (TR-ed-049): no DataStoreService interaction anywhere in this file.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local DisturbanceConstants = require(script.Parent.DisturbanceConstants)
local BootstrapLogic = require(script.Parent.DisturbanceServiceBootstrapLogic)
local EmissionLogic = require(script.Parent.DisturbanceServiceEmissionLogic)

export type SourceId = string
export type SpatialGrid = { [number]: { [number]: { SourceId } } } -- grid[cellX][cellZ] = flat list of source ids (ADR-0004)

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
	self._attributionArchive = {} :: { [string]: any } -- Story 004 defines the AttributionEntry shape

	-- Raw BindableEvent, per the GDD's own frozen C.1.11 mechanism choice (ADR-0004's
	-- OnPlayerDied Decision) -- NOT a Knit Signal. Only the empty channel is constructed
	-- here; Story 010 owns the Humanoid.Died dispatch chain that fires it.
	-- Workspace.SignalBehavior is pinned in the server bootstrap script, BEFORE any KnitInit
	-- runs -- not here (see ADR-0004's own code-sample placement).
	self._onPlayerDied = Instance.new("BindableEvent")

	-- Placeholder module reference only -- Story 011 owns its actual exports.
	self._registrationHandshake = require(script.Parent.DisturbanceServiceRegistrationHandshake)

	self._loadedChunks = {} :: { [Player]: { [string]: true } }

	self._fieldUpdateAccumulator = 0
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
	end)

	-- Required cleanup for the one per-player table this story constructs (ADR-0004/
	-- ADR-0006 leak-prevention precedent).
	Players.PlayerRemoving:Connect(function(player: Player)
		self._loadedChunks[player] = nil
	end)
end

-- ============================================================================
-- Field-update pass -- intentionally empty/no-op. Stories 003-015 extend the body (decay
-- pass, tier classification, N7/N8 monitoring, etc.).
-- ============================================================================

function DisturbanceService:_runFieldUpdatePass(): ()
	-- no-op (Story 001 scope: only the loop's accumulator skeleton exists)
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

	-- Story 002 scope: append to the flat live-source list only, keyed by emissionId -- Story
	-- 003 owns spatial-grid cell placement, Story 004 owns the attribution archive entry.
	self._liveSources[payload.emissionId] = payload
end

return DisturbanceService
