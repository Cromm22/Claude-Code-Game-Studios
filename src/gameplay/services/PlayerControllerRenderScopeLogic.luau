--!strict
-- PlayerControllerRenderScopeLogic
--
-- Pure domain logic for Story 007 (Dead-Player Input Locks & renderScope,
-- S4/S5). Deliberately has ZERO dependency on Knit or any Roblox service
-- call, so it can be required and unit-tested directly under Lune without a
-- vendored Knit package or a live Roblox environment -- mirrors every
-- sibling PlayerController*Logic module's own zero-require precedent.
-- `PlayerControllerService.luau` is a thin Knit wrapper around these
-- functions -- it owns Player identity, the real per-client
-- `OnRenderScopeChanged` push, and the real `Humanoid.WalkSpeed`/
-- `Humanoid.JumpPower`/`Humanoid.JumpHeight` side effects (including the
-- capture-and-restore jump-lock scheme -- see that file's own
-- `_enterDeadRespawningRenderScope`/`_exitToAliveRenderScope` doc comments);
-- this module owns the actual classification/predicate rules.
--
-- Implements: production/epics/player-controller/story-007-dead-player-input-locks-renderscope.md
-- GDD: design/gdd/player-controller.md -- C.5 item 4 ("Inputs accepted while
--      dead": ping NO, emote YES, spectate YES, movement/lantern/gather NO),
--      C.6 S4/S5 state table, C.9 RemoteEvent surface (`RequestPing`
--      "reject from S4/S5"; `RequestEmote` "Alive OR dead-spectating")
-- ADR: docs/architecture/adr-0012-player-controller-death-spectator-state.md
--      (THE LAW -- `renderScope` is a server-minted `"alive" |
--      "dead-respawning" | "post-run"` enum, pushed to the owning client
--      exactly once per transition; S4 rejects Gather/Lantern/Sprint/Ping at
--      the same step-1 guard; S5 is a strictly stricter superset of S4's
--      locks -- "nothing is permitted in S5 that isn't also blocked in S4")
--      docs/architecture/adr-0006-remoteevent-trust-boundary.md (step-1
--      alive/state guard this module's `IsAliveScope` implements; "a
--      dropped event MUST NOT mutate any state")
--
-- DESIGN DECISION -- data-driven event classification (pre-resolved item,
-- flagged per the story's own instruction): H.24's `RequestEmote`
-- accept-half has no real RemoteEvent surface yet (Story 013 owns the emote
-- wheel) and `RequestPing` has no PC handler yet (Story 012's scope). Rather
-- than hardcode "S4 rejects everything" in the Knit wrapper and leave a
-- silent gap for those two future stories to rediscover (and possibly
-- reinvent inconsistently), this module exposes a single, data-driven
-- event-class table (`S4_ALLOWED_EVENT_CLASSES`) that BOTH the boolean
-- `_isEligibleForGameplayEvents` guard (every currently-alive-only event)
-- AND any future S4-partial-allow event (`RequestEmote`) must consult. Only
-- "emote" is entered as an S4-allowed class today -- a placeholder
-- classification entry, structurally proven by this module's own test
-- coverage, NOT wired to any real RemoteEvent by this story (Story 013's
-- forward obligation). `IsEventAllowedInScope` mechanically proves the S5
-- strict-superset property: "post-run" never appears as an allowed scope in
-- ANY branch, so every event class this table enumerates -- including the
-- one class S4 uniquely allows -- is rejected in S5, with no second,
-- competing S5-specific rejection table to keep in sync.

local PlayerControllerRenderScopeLogic = {}

-- ============================================================================
-- Types
-- ============================================================================

export type RenderScope = "alive" | "dead-respawning" | "post-run"

-- The full enumeration of client-fired RemoteEvent "classes" this project's
-- alive/state guard classifies. Not every class has a live handler yet (see
-- the header DESIGN DECISION) -- this is the FULL set the classification
-- table below must cover, so a newly-added PC event can never silently
-- bypass the S4/S5 guard by omission.
export type EventClass = "lantern" | "sprint" | "heartbeat" | "gather" | "interact" | "ping" | "emote"

-- ============================================================================
-- Config (data-driven, named -- not scattered magic values, per
-- gameplay-code.md)
-- ============================================================================

-- NOTE: there is deliberately NO "default JumpPower" constant here.
-- Code-review fix (engine Finding 3): a hardcoded jump-restore default was
-- removed in favor of a capture-and-restore scheme -- `PlayerControllerService
-- .luau`'s `_enterDeadRespawningRenderScope` captures each player's ACTUAL
-- pre-S4 `Humanoid.JumpPower`/`JumpHeight` and `_exitToAliveRenderScope`
-- restores those captured values verbatim at T6, so this module never needs
-- to guess at an engine default (which also would have been wrong on any rig
-- where `Humanoid.UseJumpPower == false` and `JumpHeight` governs instead).

--- The S4-allowed event-class carve-out (ADR-0012 Decision / GDD C.5 item 4:
--- "Emote wheel: YES ... Movement / sprint: NO ... Lantern toggle: NO ...
--- Gather / interact / craft: NO"). Every class NOT a key in this table is
--- rejected while `renderScope == "dead-respawning"`. `"emote"` is the sole
--- S4 exception -- Story 013's future `RequestEmote` handler must consult
--- this SAME table, not reinvent its own S4 special-case.
PlayerControllerRenderScopeLogic.S4_ALLOWED_EVENT_CLASSES = {
	emote = true,
} :: { [EventClass]: boolean }

-- ============================================================================
-- Core guard -- ADR-0006 step 1 / ADR-0012's single shared boolean
-- ============================================================================

--- `_isEligibleForGameplayEvents`'s pure predicate: true only when `scope` is
--- exactly `"alive"`. A `nil` scope (a player whose `renderScope` table entry
--- was never initialized -- e.g. a request that arrives before
--- `PlayerAdded`-driven init completes) is treated as NOT eligible --
--- fail-closed, matching this codebase's established "no state -> silent
--- drop" convention (see `PlayerControllerService.luau`'s own
--- "no-player-state" reason string) rather than assuming aliveness.
function PlayerControllerRenderScopeLogic.IsAliveScope(scope: RenderScope?): boolean
	return scope == "alive"
end

-- ============================================================================
-- Data-driven event classification (S4/S5 accept-vs-reject)
-- ============================================================================

--- Returns whether `eventClass` is permitted while the player's `renderScope`
--- is `scope`. This is the SINGLE decision point both the boolean
--- `_isEligibleForGameplayEvents` guard (alive-only events) and any future
--- S4-partial-allow event must consult -- there is no second, competing
--- S5-specific rejection table (ADR-0012: "no separate S5-specific rejection
--- logic is needed since the same boolean covers both states", generalized
--- here: `"post-run"` never appears as an allowed branch below, so it always
--- falls through to `false` regardless of `eventClass`, mechanically proving
--- the S5-superset property for every class this table enumerates -- S5
--- rejects a STRICT superset of what S4 rejects, including "emote", the one
--- class S4 uniquely allows).
function PlayerControllerRenderScopeLogic.IsEventAllowedInScope(eventClass: EventClass, scope: RenderScope?): boolean
	if scope == "alive" then
		return true
	end
	if scope == "dead-respawning" then
		return PlayerControllerRenderScopeLogic.S4_ALLOWED_EVENT_CLASSES[eventClass] == true
	end
	-- "post-run" (S5), or an uninitialized/nil scope: reject unconditionally.
	return false
end

return PlayerControllerRenderScopeLogic
