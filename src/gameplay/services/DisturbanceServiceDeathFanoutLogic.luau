--!strict
-- DisturbanceServiceDeathFanoutLogic
--
-- Implements: production/epics/ecological-disturbance/story-010-humanoid-died-monopoly-onplayerdied-fanout.md
-- GDD: design/gdd/ecological-disturbance.md -- C.1.11/C.1.12 (Humanoid.Died sole subscription,
--      OnPlayerDied fan-out, yield-free (5a)-(5c) snapshot-then-fire sequence), TR-ed-030,
--      TR-ed-032, TR-ed-044, TR-ed-052, TR-ed-061
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md (OnPlayerDied channel
--      type Decision -- raw BindableEvent, not Knit Signal; N10 pre-dispatch snapshot)
--      docs/architecture/adr-0005-death-respawn-lifecycle.md (Humanoid.Died fan-out to exactly 3
--      consumers; the Humanoid.Died idempotent guard is EACH CONSUMER's own responsibility, not
--      this story's/module's -- see this story's own Engine Notes)
--
-- Pure domain logic for step (5b) of the death-fan-out sequence: OnPlayerDied payload
-- construction. Deliberately has ZERO dependency on Knit, any Roblox service call, OR any
-- require() at all -- mirrors every sibling DisturbanceService*Logic module's own zero-require
-- precedent (Stories 001-009/014), so it can be required and unit-tested directly under Lune.
--
-- PLAYER IDENTITY (design call, matching DisturbanceServiceSquadAggregateLogic.luau's own
-- precedent verbatim): this module never references the `Player` type. `deadPlayer` is an opaque
-- identity value, carried through into the returned payload unmodified and compared only via `==`
-- -- works identically for a real Roblox `Player` instance (referential equality) and for the
-- plain Lua tables/strings this module's own test suite uses as stand-ins, since Player/Humanoid/
-- Character instances cannot be meaningfully live-constructed under this project's Lune test
-- harness. The frozen `Player` type on the real (5a)-(5c) sequence lives on DisturbanceService
-- .luau's thin wrapper (`_onHumanoidDied(deadPlayer: Player)`), not here.
--
-- DisturbanceService.luau is a thin Knit wrapper around this module's BuildDeathPayload: it owns
-- the real self._deathLockSnapshot state table (KnitInit), the real self._onPlayerDied
-- BindableEvent (KnitInit, raw BindableEvent per the GDD's own frozen C.1.11 closure -- NOT
-- Signal, see ADR-0004's dedicated Decision subsection), the real Humanoid.Died subscription
-- chain (Players.PlayerAdded -> CharacterAdded -> Humanoid.Died:Connect, KnitInit, ADR-0004
-- Architecture Diagram), the real self:_captureDeathLockSnapshot(deadPlayer) stub call (5a --
-- TODO(Story 011), always returns false until Story 011's predator-lock registry exists,
-- mirroring DisturbanceServiceAttributionArchiveLogic.luau's own DefaultIsEmissionLocked stub
-- precedent from Story 004), and the real workspace:GetServerTimeNow() clock sample (5b, sourced
-- AFTER the snapshot capture -- see this module's own ORDERING NOTE below).
--
-- ORDERING NOTE (REQUIRED, not a stylistic choice): BuildDeathPayload is a pure function of its
-- three already-resolved inputs -- it cannot itself enforce that the caller samples `now` and
-- captures `wasLocked` in the correct order (snapshot BEFORE clock/payload construction, per the
-- story's own AC text: "payload constructed AFTER the snapshot capture so the flag value is
-- consistent with the registry read at (5a)"). That ordering is a property of the CALL SITE
-- (DisturbanceService.luau's real _onHumanoidDied) -- this story's test file verifies it both via
-- a static/structural check against the real call site and via a behavioral Fake-service harness
-- that mirrors the real method body's call order exactly.
--
-- NO DEDUP (REQUIRED, out of scope by design): this module never deduplicates repeated calls -- a
-- caller invoking BuildDeathPayload twice for the same deadPlayer (e.g. Humanoid.Died firing
-- twice in a pathological replication race, Player Controller's own documented assumption per
-- ADR-0005) produces two independently-correct payloads, each stamped with its OWN `now`/
-- `wasLocked` snapshot. ED's own obligation is limited to the correctness of each individual
-- snapshot-then-payload sequence, not deduplication across sequences -- that is explicitly PC's
-- own future `_deathInProgress` guard's job (ADR-0005), not this module's or DisturbanceService
-- .luau's.

--- Opaque player identity -- see PLAYER IDENTITY note above.
export type PlayerIdentity = any

export type DeathPayload = {
	deadPlayer: PlayerIdentity,
	deathTimestamp: number,
	predatorWasLockedAtDeath: boolean,
}

local DisturbanceServiceDeathFanoutLogic = {}

-- ============================================================================
-- BuildDeathPayload -- step (5b) of the death-fan-out sequence (REQUIRED). Constructs the
-- OnPlayerDied payload from three ALREADY-RESOLVED inputs -- see this module's own header note
-- for why the ordering guarantee (snapshot captured BEFORE this is called) is a call-site
-- property, not something this pure function enforces itself.
-- ============================================================================

function DisturbanceServiceDeathFanoutLogic.BuildDeathPayload(
	deadPlayer: PlayerIdentity,
	wasLocked: boolean,
	now: number
): DeathPayload
	return {
		deadPlayer = deadPlayer,
		deathTimestamp = now,
		predatorWasLockedAtDeath = wasLocked,
	}
end

return DisturbanceServiceDeathFanoutLogic
