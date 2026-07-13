--!strict
-- ServerBootstrap
--
-- Implements: production/epics/ecological-disturbance/story-001-constants-bootstrap-field-update-loop.md
-- ADR: docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md
--      docs/architecture/adr-0004-disturbanceservice-core-architecture.md (OnPlayerDied
--      channel type Decision -- Workspace.SignalBehavior pin, "before any KnitInit runs")
--      docs/architecture/adr-0005 (KnitInit-time config-validation hard error MUST be paired
--      with a bootstrap catch handler that calls game:Shutdown() -- binding project-wide,
--      restated in control-manifest.md's Foundation Layer Required Patterns)
--
-- Dependency-injected server-boot sequencing, deliberately free of any direct Knit/Roblox-
-- global reference so it is unit-testable under Lune without a live Roblox environment or a
-- vendored Knit package. ServerInit.server.luau (a plain Script, NOT require()-able) is a
-- thin wrapper that supplies the real dependencies (Knit.Start, game:Shutdown, warn, the
-- SignalBehavior pin) and calls ServerBootstrap.Run once, at server boot.
--
-- SCOPE NOTE (Story 001): this module owns ONLY the pin-then-start-then-catch sequencing
-- shape. It does not know about DisturbanceService or any other Knit service by name --
-- Knit.AddServicesDeep(...) (called by ServerInit.server.luau before Run) is what makes
-- services discoverable to Knit.Start().

local ServerBootstrap = {}

export type KnitPromiseLike = {
	andThen: (self: KnitPromiseLike, onResolved: () -> ()) -> KnitPromiseLike,
	catch: (self: KnitPromiseLike, onRejected: (err: any) -> ()) -> KnitPromiseLike,
}

export type BootstrapDependencies = {
	pinSignalBehavior: () -> (),
	knitStart: () -> KnitPromiseLike,
	onStarted: () -> (),
	warn: (...any) -> (),
	shutdown: () -> (),
}

--- Pins Workspace.SignalBehavior (via the injected `pinSignalBehavior`) BEFORE calling
--- `knitStart()` -- satisfying ADR-0004's "before any KnitInit runs" requirement, since
--- KnitInit only fires once Knit.Start()'s promise chain begins. On success, calls
--- `onStarted`. On failure (a rejected KnitInit promise, e.g. a config-validation hard
--- error), calls `warn(err)` AND `shutdown()` -- a `catch(warn)`-only boilerplate does NOT
--- satisfy ADR-0005's binding project-wide rule (control-manifest.md, Foundation Layer
--- Required Patterns).
function ServerBootstrap.Run(deps: BootstrapDependencies): KnitPromiseLike
	deps.pinSignalBehavior()

	return deps
		.knitStart()
		:andThen(function()
			deps.onStarted()
		end)
		:catch(function(err: any)
			deps.warn(err)
			deps.shutdown()
		end)
end

return ServerBootstrap
