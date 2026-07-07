--!strict
-- ServerInit.server.luau
--
-- Implements: production/epics/ecological-disturbance/story-001-constants-bootstrap-field-update-loop.md
-- ADR: docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md
--      docs/architecture/adr-0004-disturbanceservice-core-architecture.md (OnPlayerDied
--      channel type Decision -- Workspace.SignalBehavior = Enum.SignalBehavior.Immediate,
--      pinned before any KnitInit runs)
--      docs/architecture/adr-0005 (KnitInit hard-error MUST pair with a bootstrap catch
--      handler that calls game:Shutdown(), not just warn())
--
-- Server entry point. Discovers all Knit services under ServerScriptService.gameplay via
-- Knit.AddServicesDeep, then delegates the actual pin -> start -> catch sequencing to the
-- dependency-free ServerBootstrap module so that sequencing logic is unit-testable without a
-- live Roblox environment -- see
-- tests/integration/ecological-disturbance/service-bootstrap-config-validation_test.luau.
--
-- This file itself is a plain Script (not a ModuleScript) and is intentionally kept as thin
-- as possible: it supplies real Roblox/Knit dependencies to ServerBootstrap.Run and nothing
-- else.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ServerBootstrap = require(script.Parent.ServerBootstrap)

Knit.AddServicesDeep(ServerScriptService.gameplay.services)

ServerBootstrap.Run({
	pinSignalBehavior = function()
		-- ADR-0004's OnPlayerDied Decision: must be pinned BEFORE any KnitInit runs. A
		-- one-line, one-time server-boot assertion -- not a per-call cost.
		workspace.SignalBehavior = Enum.SignalBehavior.Immediate
	end,
	knitStart = function()
		return (Knit.Start() :: any) :: ServerBootstrap.KnitPromiseLike
	end,
	onStarted = function()
		print("Knit started")
	end,
	warn = warn,
	shutdown = function()
		game:Shutdown()
	end,
})
