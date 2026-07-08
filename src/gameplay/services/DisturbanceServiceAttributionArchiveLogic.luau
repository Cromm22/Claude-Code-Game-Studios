--!strict
-- DisturbanceServiceAttributionArchiveLogic
--
-- Implements: production/epics/ecological-disturbance/story-004-attribution-archive-ttl-cap.md
-- GDD: design/gdd/ecological-disturbance.md -- C.1.11 (archive lifetime rule: retained for the
--      LONGER of TTL-from-emissionTime / all-referencing-players-departed / predator-lock-held;
--      no dedicated H.x AC number exists for this -- C.1.11's own rule text is the authoritative
--      testable contract, per the epic's explicit deferral to this implementation story)
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md -- "the write-once
--      attribution archive entry is unaffected [by live-source eviction]... archive entries are
--      independent of live-source-list membership" (Spatial data structure Decision subsection).
--      ADR-0004 has no dedicated Decision subsection for the archive's own TTL/cap-FIFO
--      mechanics -- this story's own Context/Implementation Notes are the more complete spec
--      here, per the story's own citation instruction.
--
-- Pure domain logic for the write-once attribution archive: entry construction, the three-
-- condition retention rule (TTL / live-referencer / predator-lock), count-cap FIFO eviction with
-- lock-exemption, and per-player-departure referencer-set maintenance. Deliberately has ZERO
-- dependency on Knit or any Roblox service call (mirrors DisturbanceServiceBootstrapLogic /
-- DisturbanceServiceEmissionLogic / DisturbanceServiceSpatialGridLogic's own zero-require
-- precedent from Stories 001-003), so it can be required and unit-tested directly under Lune.
-- DisturbanceService.luau is a thin Knit wrapper around this module's functions -- it owns the
-- real self._attributionArchive/self._attributionReferencingPlayers/self._archiveInsertionSequence
-- state tables, the real workspace:GetServerTimeNow() clock sample, the Players.PlayerRemoving
-- connection, the periodic Heartbeat-driven maintenance-pass scheduling, and the game-facing
-- warn() ops-log call sites; this module owns only the actual retention/eviction math and never
-- touches self._spatialGrid or self._liveSources.
--
-- ARCHIVE INDEPENDENCE FROM THE LIVE-SOURCE LIST (design note, mirrors
-- DisturbanceServiceSpatialGridLogic.luau's own "ARCHIVE INDEPENDENCE" note in reverse): this
-- module's functions never accept a spatial-grid or live-source-list parameter, and never
-- reference "spatialGrid"/"liveSources" anywhere in their actual code. Story 003's
-- MAX_LIVE_SOURCES cap-eviction (DisturbanceServiceSpatialGridLogic.EvictOldestSource) has no
-- archive parameter either (confirmed by that module's own header note and its accompanying
-- test's static check) -- the two stores share no code path in either direction, only the same
-- Emit() caller. See this file's own test for the mirrored static check.
--
-- EmissionType is DUPLICATED here (not require()d from DisturbanceServiceEmissionLogic) as a
-- design call, approved 2026-07-06: the story's own Implementation Notes type sample uses
-- `emissionType: EmissionType`, not the plain `string` DisturbanceServiceSpatialGridLogic.
-- MinimalSource uses -- to honor that literal type shape while preserving the zero-require
-- discipline every sibling pure-logic module in this service follows, the union is restated
-- locally rather than cross-module-required. Keep the member list in sync with
-- DisturbanceServiceEmissionLogic.EmissionType by hand if that enum ever changes.
--
-- CONDITION (b) SCOPING (design call, approved 2026-07-06 -- explicit, not silent): "the players
-- who could reference this entry" is, for THIS story, exactly `{sourcePlayerId}` -- tracked as a
-- live per-entry set, seeded at write time and shrunk on Players.PlayerRemoving. The GDD's fuller
-- condition (b) also includes "any player who has died with this emissionId in their attribution
-- chain," which requires Story 012's DeathAttributionPayload resolution and does not exist yet.
-- This module's ReferencingPlayers table is the seam Story 012 will widen later (adding players
-- to an entry's set at death-attribution time) without needing to change this module's retention
-- predicate (ShouldPurge) at all -- only the set's population source grows.

export type EmissionType = "Gather" | "Sprint" | "Light" | "Beacon" | "Craft"

export type AttributionArchiveEntry = {
	emissionId: string,
	sourcePlayerId: number,
	emissionType: EmissionType,
	position: Vector3,
	emissionTime: number,
	attributionChain: { string },
}

--- The minimal structural shape BuildEntry needs from a live emission payload. The real
--- DisturbanceServiceEmissionLogic.EmissionPayload satisfies this structurally (it is a superset
--- -- it also carries `initialMagnitude`, which BuildEntry deliberately does NOT copy onto the
--- archive entry; see BuildEntry's own doc comment for why) -- this module never require()s that
--- module, matching the zero-require precedent explained above.
export type MinimalEmission = {
	emissionId: string,
	sourcePlayerId: number,
	emissionType: EmissionType,
	position: Vector3,
	emissionTime: number,
	attributionChain: { string },
}

export type Archive = { [string]: AttributionArchiveEntry }

--- Per-entry set of player ids currently "referencing" that entry (condition (b) -- see the
--- CONDITION (b) SCOPING note above for this story's scoped population source). Presence as a
--- key (value `true`) means "still referencing"; the set becoming empty means condition (b) no
--- longer keeps the entry alive.
export type ReferencingPlayers = { [string]: { [number]: true } }

--- Monotonic per-entry insertion-order counter, keyed by emissionId -- NOT derived from Luau's
--- own (unordered) table iteration order. Mirrors DisturbanceServiceSpatialGridLogic's own
--- insertionSequence precedent (Story 003) exactly, for the same deterministic-tie-break reason.
export type InsertionSequence = { [string]: number }

--- Story 011's eventual predator-lock-registry query surface. See DefaultIsEmissionLocked below
--- for this story's required stub.
export type IsEmissionLockedFn = (emissionId: string) -> boolean

local DisturbanceServiceAttributionArchiveLogic = {}

-- ============================================================================
-- Write-once entry construction
-- ============================================================================

--- Constructs an AttributionArchiveEntry from a live emission payload's structural subset.
--- Deliberately copies ONLY the six archive-entry fields -- `initialMagnitude` (present on the
--- real EmissionPayload) is NEVER copied onto the archive entry, structurally enforcing "archive
--- entries... are NOT used by any field-value math" (this story's own AC) rather than relying on
--- convention alone: a future caller cannot accidentally read a magnitude value off an archive
--- entry because the field is never present on it.
---
--- Write-once by construction, not by a runtime guard: the sole production caller
--- (DisturbanceService:Emit()) always mints a fresh HttpService:GenerateGUID(false) per call
--- (Story 002, GDD E.20's "collision probability effectively zero" guardrail) and never accepts a
--- caller-supplied id -- mirrors DisturbanceServiceSpatialGridLogic.InsertEmission's own
--- PRECONDITION note on why a duplicate-id guard is not added here.
function DisturbanceServiceAttributionArchiveLogic.BuildEntry(payload: MinimalEmission): AttributionArchiveEntry
	return {
		emissionId = payload.emissionId,
		sourcePlayerId = payload.sourcePlayerId,
		emissionType = payload.emissionType,
		position = payload.position,
		emissionTime = payload.emissionTime,
		attributionChain = payload.attributionChain,
	}
end

-- ============================================================================
-- Story 011 stub -- condition (c)'s predator-lock query
-- ============================================================================

--- TODO(Story 011): always returns false. Story 011's predator-lock registry does not exist yet
--- -- this stub keeps condition (c) permanently inert (never retains an entry past TTL/condition-
--- b on its own) until Story 011 supplies a real implementation. DisturbanceService.luau injects
--- this as `self._isEmissionLocked`'s default value; every function below takes
--- `isEmissionLocked` as a parameter (never calls this stub directly itself), so Story 011 can
--- later swap in a real predicate at the single self._isEmissionLocked assignment site without
--- touching any call site in this module -- the same injection-seam pattern Stories 002/003 used
--- for `now`/`cellSize` rather than hardcoding a clock or config lookup.
function DisturbanceServiceAttributionArchiveLogic.DefaultIsEmissionLocked(_emissionId: string): boolean
	return false
end

-- ============================================================================
-- Retention predicate -- the three-condition "longer of" rule (C.1.11)
-- ============================================================================

--- Condition (a): true once `now - emissionTime` reaches `ttl`.
---
--- TTL BOUNDARY (design call, approved 2026-07-06): INCLUSIVE at exactly `now - emissionTime ==
--- ttl` -- an entry becomes TTL-purge-eligible AT exactly the boundary, not only strictly after
--- it. This mirrors this service's own established boundary convention
--- (DisturbanceServiceBootstrapLogic.StepAccumulator's `newAccumulator >= interval` fires-at-
--- exactly-the-boundary semantics) rather than introducing a second, inconsistent boundary rule
--- within the same service.
function DisturbanceServiceAttributionArchiveLogic.IsTtlExpired(emissionTime: number, now: number, ttl: number): boolean
	return (now - emissionTime) >= ttl
end

--- Condition (b), scoped per this story's own CONDITION (b) SCOPING note above: true if at least
--- one player id is still present in `emissionId`'s referencing set.
function DisturbanceServiceAttributionArchiveLogic.HasLiveReferencer(referencingPlayers: ReferencingPlayers, emissionId: string): boolean
	local set = referencingPlayers[emissionId]
	return set ~= nil and next(set) ~= nil
end

--- The combined "longer of (a)/(b)/(c)" retention rule, expressed as its purge-eligibility
--- inverse (purge iff NONE of the three retaining conditions hold): an entry purges only when its
--- TTL has expired AND it has no live referencer AND it is not currently predator-lock-referenced.
--- Any single retaining condition being true keeps the entry alive.
function DisturbanceServiceAttributionArchiveLogic.ShouldPurge(
	entry: AttributionArchiveEntry,
	referencingPlayers: ReferencingPlayers,
	isEmissionLocked: IsEmissionLockedFn,
	now: number,
	ttl: number
): boolean
	if not DisturbanceServiceAttributionArchiveLogic.IsTtlExpired(entry.emissionTime, now, ttl) then
		return false -- condition (a) not yet met -- always retained regardless of (b)/(c)
	end
	if DisturbanceServiceAttributionArchiveLogic.HasLiveReferencer(referencingPlayers, entry.emissionId) then
		return false -- condition (b) keeps it alive
	end
	if isEmissionLocked(entry.emissionId) then
		return false -- condition (c) keeps it alive
	end
	return true
end

-- ============================================================================
-- Count-cap FIFO eviction, skipping locked entries (condition (c) eviction-exemption)
-- ============================================================================

--- Finds the emissionId of the oldest archive entry NOT currently predator-lock-referenced:
--- smallest `emissionTime` wins among unlocked entries; ties are broken by the smaller
--- `insertionSequence` value (first-inserted-wins-as-oldest -- mirrors
--- DisturbanceServiceSpatialGridLogic.FindOldestSourceId's own required, documented,
--- deterministic tie-break rule exactly). Returns nil if every entry is locked (the pathological
--- "cannot evict" case) or the archive is empty.
function DisturbanceServiceAttributionArchiveLogic.FindOldestUnlockedEntryId(
	archive: Archive,
	insertionSequence: InsertionSequence,
	isEmissionLocked: IsEmissionLockedFn
): string?
	local oldestId: string? = nil
	local oldestTime: number? = nil
	local oldestSeq: number? = nil

	for id, entry in archive do
		if isEmissionLocked(id) then
			continue
		end
		local seq = insertionSequence[id] or 0
		if oldestId == nil then
			oldestId = id
			oldestTime = entry.emissionTime
			oldestSeq = seq
		else
			local betterByTime = entry.emissionTime < (oldestTime :: number)
			local tiedByTime = entry.emissionTime == (oldestTime :: number)
			local betterBySequenceOnTie = tiedByTime and seq < (oldestSeq :: number)
			if betterByTime or betterBySequenceOnTie then
				oldestId = id
				oldestTime = entry.emissionTime
				oldestSeq = seq
			end
		end
	end

	return oldestId
end

--- Removes `emissionId` from all three parallel tables. Shared by InsertEntry's write-time cap
--- check, EnforceCap's periodic cap loop, and PurgeExpiredEntries' TTL/condition-b/condition-c
--- sweep -- the single place an archive entry is ever fully torn down.
local function evictEntry(archive: Archive, referencingPlayers: ReferencingPlayers, insertionSequence: InsertionSequence, emissionId: string): ()
	archive[emissionId] = nil
	referencingPlayers[emissionId] = nil
	insertionSequence[emissionId] = nil
end

local function countEntries(archive: Archive): number
	local count = 0
	for _ in archive do
		count += 1
	end
	return count
end

-- ============================================================================
-- Write-time insertion -- the entry point DisturbanceService:Emit() calls (mirrors
-- DisturbanceServiceSpatialGridLogic.InsertEmission's orchestration shape).
-- ============================================================================

--- Inserts `entry` into `archive`, cap-evicting the single oldest UNLOCKED entry first if
--- `archive` is already at `maxEntries` (condition (c) eviction-exemption: locked entries are
--- never evicted). The new entry is ALWAYS written, even in the pathological case where every
--- existing entry is locked and nothing can be evicted (`evictionFailed = true`) -- this function
--- never throws and never silently drops the new write; the caller (DisturbanceService.luau) is
--- responsible for logging `evictionFailed` as a distinct ops-log warning.
---
--- Returns (evictedId, evictionFailed, updatedNextSequence): `evictedId` is nil if no eviction
--- occurred (either below cap, or nothing was evictable); the caller must store
--- `updatedNextSequence` back into its own counter for the next call.
function DisturbanceServiceAttributionArchiveLogic.InsertEntry(
	archive: Archive,
	referencingPlayers: ReferencingPlayers,
	insertionSequence: InsertionSequence,
	nextSequence: number,
	maxEntries: number,
	entry: AttributionArchiveEntry,
	isEmissionLocked: IsEmissionLockedFn
): (string?, boolean, number)
	local evictedId: string? = nil
	local evictionFailed = false

	if countEntries(archive) >= maxEntries then
		local candidate = DisturbanceServiceAttributionArchiveLogic.FindOldestUnlockedEntryId(archive, insertionSequence, isEmissionLocked)
		if candidate then
			evictEntry(archive, referencingPlayers, insertionSequence, candidate)
			evictedId = candidate
		else
			evictionFailed = true
		end
	end

	archive[entry.emissionId] = entry
	referencingPlayers[entry.emissionId] = { [entry.sourcePlayerId] = true }
	insertionSequence[entry.emissionId] = nextSequence

	return evictedId, evictionFailed, nextSequence + 1
end

-- ============================================================================
-- Periodic maintenance -- the "distinctly-named, separately-callable pass" this story's AC
-- requires (TR-ed-051's "lazy expiry, low-frequency maintenance cull pass"). Story 017 wraps
-- calls to RunMaintenancePass in debug.profilebegin/profileend instrumentation later -- this
-- story only needs the pass to exist as its own function, which it does.
-- ============================================================================

--- Sweeps every archive entry and purges those whose ShouldPurge predicate is true. Returns the
--- list of purged emissionIds.
function DisturbanceServiceAttributionArchiveLogic.PurgeExpiredEntries(
	archive: Archive,
	referencingPlayers: ReferencingPlayers,
	insertionSequence: InsertionSequence,
	isEmissionLocked: IsEmissionLockedFn,
	now: number,
	ttl: number
): { string }
	local purgedIds: { string } = {}

	for id, entry in archive do
		if DisturbanceServiceAttributionArchiveLogic.ShouldPurge(entry, referencingPlayers, isEmissionLocked, now, ttl) then
			table.insert(purgedIds, id)
		end
	end

	for _, id in purgedIds do
		evictEntry(archive, referencingPlayers, insertionSequence, id)
	end

	return purgedIds
end

--- Defensive cap-enforcement loop: while `archive` is over `maxEntries`, evicts the single oldest
--- unlocked entry, repeating until back at/under cap or nothing more can be evicted. Normally a
--- no-op in production (InsertEntry already enforces the cap synchronously at write time) -- this
--- exists so RunMaintenancePass stays correct if ever called standalone (e.g. a future test, or a
--- state constructed by a caller that bypassed InsertEntry). Returns (evictedIds, evictionFailed);
--- `evictionFailed` is true if the loop had to stop with the archive still over cap because every
--- remaining entry is locked -- logged as a distinct ops-log warning by the caller, never a crash
--- and never a silent unbounded-growth outcome.
function DisturbanceServiceAttributionArchiveLogic.EnforceCap(
	archive: Archive,
	referencingPlayers: ReferencingPlayers,
	insertionSequence: InsertionSequence,
	maxEntries: number,
	isEmissionLocked: IsEmissionLockedFn
): ({ string }, boolean)
	local evictedIds: { string } = {}
	local evictionFailed = false

	while countEntries(archive) > maxEntries do
		local candidate = DisturbanceServiceAttributionArchiveLogic.FindOldestUnlockedEntryId(archive, insertionSequence, isEmissionLocked)
		if candidate then
			evictEntry(archive, referencingPlayers, insertionSequence, candidate)
			table.insert(evictedIds, candidate)
		else
			evictionFailed = true
			break
		end
	end

	return evictedIds, evictionFailed
end

--- The orchestration entry point: TTL/condition-b/condition-c purge, THEN defensive cap
--- enforcement. This is the single function Story 017 instruments with
--- debug.profilebegin/profileend, and the function DisturbanceService.luau's periodic
--- EXPIRY_MAINTENANCE_INTERVAL-cadenced Heartbeat accumulator (and its Players.PlayerRemoving
--- handler, for condition (b)'s immediate re-evaluation) both call.
---
--- Returns (purgedIds, capEvictedIds, evictionFailed).
function DisturbanceServiceAttributionArchiveLogic.RunMaintenancePass(
	archive: Archive,
	referencingPlayers: ReferencingPlayers,
	insertionSequence: InsertionSequence,
	isEmissionLocked: IsEmissionLockedFn,
	now: number,
	ttl: number,
	maxEntries: number
): ({ string }, { string }, boolean)
	local purgedIds =
		DisturbanceServiceAttributionArchiveLogic.PurgeExpiredEntries(archive, referencingPlayers, insertionSequence, isEmissionLocked, now, ttl)
	local capEvictedIds, evictionFailed =
		DisturbanceServiceAttributionArchiveLogic.EnforceCap(archive, referencingPlayers, insertionSequence, maxEntries, isEmissionLocked)

	return purgedIds, capEvictedIds, evictionFailed
end

-- ============================================================================
-- Player-departure handling -- condition (b)'s live-referencer-set shrink (Players.PlayerRemoving)
-- ============================================================================

--- Removes `departedPlayerId` from every archive entry's referencing set. O(archive size) --
--- acceptable at the 4000-entry cap per this story's own Implementation Notes. Pure bookkeeping
--- only: does NOT purge anything itself -- DisturbanceService.luau's PlayerRemoving handler calls
--- this, then immediately calls RunMaintenancePass so any entry that just lost its last live
--- referencer is re-evaluated for purge right away rather than waiting for the next periodic tick.
function DisturbanceServiceAttributionArchiveLogic.HandlePlayerDeparture(referencingPlayers: ReferencingPlayers, departedPlayerId: number): ()
	for _, set in referencingPlayers do
		set[departedPlayerId] = nil
	end
end

return DisturbanceServiceAttributionArchiveLogic
