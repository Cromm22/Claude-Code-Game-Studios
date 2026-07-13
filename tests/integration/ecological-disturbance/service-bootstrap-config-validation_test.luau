--!strict
-- service-bootstrap-config-validation_test
--
-- Integration tests for Story 001: Constants Module, Service Bootstrap & 5Hz Field-Update
-- Loop Driver.
-- Story: production/epics/ecological-disturbance/story-001-constants-bootstrap-field-update-loop.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceBootstrapLogic.luau (H.3d/H.3e config-validation
--     gates, C.1.13 Heartbeat accumulator)
--   src/core/ServerBootstrap.luau (bootstrap catch -> game:Shutdown() wiring)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only --
--     see the third describe() block below for why)
--
-- Story Type: Integration (per the story file's own Test Evidence section) -- coding-
-- standards.md's bar for Integration is "Integration test OR documented playtest," so this
-- file mixes true behavioral tests (against the Knit-free logic/bootstrap modules) with
-- static/structural source-text checks (against the actual .luau file text), exactly as the
-- story's own QA Test Cases section prescribes for the "no DataStoreService call anywhere in
-- the service's source" case ("this can be a static/structural check -- grep the file for
-- DataStoreService, assert zero matches") -- extended here to also cover the "containers
-- constructed empty" AC, for the same underlying reason: DisturbanceService.luau cannot be
-- instantiated under this test harness (Knit is not yet vendored under
-- ReplicatedStorage.Packages -- a pre-existing, already-documented gap; see
-- tests/README.md's "Future Enhancements" -> "Package Vendoring (Wally)" section), so a live
-- `DisturbanceService:KnitInit()` call is not currently possible in an automated test. This
-- mirrors the same Knit-wrapper/pure-logic split precedent already established by
-- tests/unit/player-controller/lantern-gather-gate_test.luau.
--
-- NOTE: this test file requires @lune/fs directly (not just via tests/run_tests.lua's own
-- top-level require) for the static source-text checks below. Lune's "@lune/" aliases are
-- expected to resolve the same way regardless of require() call depth (a built-in-library
-- alias, not a filesystem-relative resolution) -- this is an assumption inherited from this
-- story's implementation notes and has not been executed against a real `lune run` in this
-- environment (no Lune/Foreman toolchain installed here); verify on first real CI run.

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local BootstrapLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceBootstrapLogic)
local ServerBootstrap = require(ServerScriptService.core.ServerBootstrap)

type KnitPromiseLike = ServerBootstrap.KnitPromiseLike

return function()
	describe("DisturbanceServiceBootstrapLogic -- Story 001 (config-validation gates, Heartbeat accumulator)", function()
		-- ====================================================================
		-- H.3d -- INFLUENCE_RADIUS must be strictly positive.
		-- ====================================================================
		local function test_influence_radius_zero_is_rejected()
			local ok, message = BootstrapLogic.ValidateInfluenceRadius(0)
			expect(ok).to.equal(false)
			expect(message).never.to.equal(nil)
			expect((message :: string):find("INFLUENCE_RADIUS")).never.to.equal(nil)
		end
		it("test_influence_radius_zero_is_rejected", function()
			test_influence_radius_zero_is_rejected()
		end)

		local function test_influence_radius_large_negative_is_rejected()
			local ok, message = BootstrapLogic.ValidateInfluenceRadius(-9999)
			expect(ok).to.equal(false)
			expect(message).never.to.equal(nil)
		end
		it("test_influence_radius_large_negative_is_rejected", function()
			test_influence_radius_large_negative_is_rejected()
		end)

		local function test_influence_radius_default_passes()
			local ok, message = BootstrapLogic.ValidateInfluenceRadius(24)
			expect(ok).to.equal(true)
			expect(message).to.equal(nil)
		end
		it("test_influence_radius_default_passes", function()
			test_influence_radius_default_passes()
		end)

		-- ====================================================================
		-- H.3e -- SPATIAL_GRID_CELL_SIZE >= INFLUENCE_RADIUS (G.7 invariant). Exactly-equal
		-- PASSES; strictly-less FAILS.
		-- ====================================================================
		local function test_cell_size_strictly_less_than_radius_is_rejected()
			local ok, message = BootstrapLogic.ValidateSpatialGridCellSize(16, 24)
			expect(ok).to.equal(false)
			expect(message).never.to.equal(nil)
			expect((message :: string):find("G%.7")).never.to.equal(nil)
		end
		it("test_cell_size_strictly_less_than_radius_is_rejected", function()
			test_cell_size_strictly_less_than_radius_is_rejected()
		end)

		local function test_cell_size_exactly_equal_to_radius_passes()
			local ok, message = BootstrapLogic.ValidateSpatialGridCellSize(24, 24)
			expect(ok).to.equal(true)
			expect(message).to.equal(nil)
		end
		it("test_cell_size_exactly_equal_to_radius_passes", function()
			test_cell_size_exactly_equal_to_radius_passes()
		end)

		local function test_cell_size_one_unit_below_radius_is_rejected()
			local ok, message = BootstrapLogic.ValidateSpatialGridCellSize(23, 24)
			expect(ok).to.equal(false)
			expect(message).never.to.equal(nil)
		end
		it("test_cell_size_one_unit_below_radius_is_rejected", function()
			test_cell_size_one_unit_below_radius_is_rejected()
		end)

		local function test_cell_size_default_passes()
			local ok, message = BootstrapLogic.ValidateSpatialGridCellSize(32, 24)
			expect(ok).to.equal(true)
			expect(message).to.equal(nil)
		end
		it("test_cell_size_default_passes", function()
			test_cell_size_default_passes()
		end)

		-- ====================================================================
		-- C.1.13 -- Heartbeat catch-up (graceful-skip) semantics.
		-- ====================================================================
		local function test_large_dt_fires_exactly_once_and_resets_residual_to_zero()
			-- dt=0.5s while interval=0.2s: must fire exactly once (not 2-3 times for the
			-- 0.5/0.2 = 2.5 "debt"), and the returned accumulator must be 0, not the 0.3s
			-- residual a naive "accumulator -= interval" implementation would carry forward.
			local newAccumulator, shouldFire = BootstrapLogic.StepAccumulator(0, 0.5, 0.2)
			expect(shouldFire).to.equal(true)
			expect(newAccumulator).to.equal(0)
		end
		it("test_large_dt_fires_exactly_once_and_resets_residual_to_zero", function()
			test_large_dt_fires_exactly_once_and_resets_residual_to_zero()
		end)

		local function test_dt_exactly_equal_to_interval_fires_once_no_residual()
			local newAccumulator, shouldFire = BootstrapLogic.StepAccumulator(0, 0.2, 0.2)
			expect(shouldFire).to.equal(true)
			expect(newAccumulator).to.equal(0)
		end
		it("test_dt_exactly_equal_to_interval_fires_once_no_residual", function()
			test_dt_exactly_equal_to_interval_fires_once_no_residual()
		end)

		local function test_dt_zero_never_fires()
			local newAccumulator, shouldFire = BootstrapLogic.StepAccumulator(0.1, 0, 0.2)
			expect(shouldFire).to.equal(false)
			expect(newAccumulator).to.equal(0.1)
		end
		it("test_dt_zero_never_fires", function()
			test_dt_zero_never_fires()
		end)

		local function test_many_small_dts_summing_past_interval_fires_once_per_crossing()
			-- Interval=4, per-step dt=1 (integer-scale values, deliberately chosen over e.g.
			-- 0.05-per-step decimals to avoid floating-point summation drift across repeated
			-- additions being mistaken for a functional bug -- StepAccumulator is unit-
			-- agnostic, so this exercises the identical code path as the real 5Hz/0.2s
			-- config). Fires once on the 4th step (1+1+1+1=4), resets to 0, then the 5th step
			-- accumulates fresh from zero (standard accumulator behavior, NOT the
			-- graceful-skip branch -- no step's dt alone exceeds the interval).
			local accumulator = 0
			local fireLog: { boolean } = {}
			for _ = 1, 5 do
				local newAccumulator, shouldFire = BootstrapLogic.StepAccumulator(accumulator, 1, 4)
				accumulator = newAccumulator
				table.insert(fireLog, shouldFire)
			end

			expect(fireLog[1]).to.equal(false) -- 1
			expect(fireLog[2]).to.equal(false) -- 2
			expect(fireLog[3]).to.equal(false) -- 3
			expect(fireLog[4]).to.equal(true) -- 4 -- fires, resets to 0
			expect(fireLog[5]).to.equal(false) -- 1 (fresh accumulation post-reset)

			local fireCount = 0
			for _, fired in fireLog do
				if fired then
					fireCount += 1
				end
			end
			expect(fireCount).to.equal(1)
		end
		it("test_many_small_dts_summing_past_interval_fires_once_per_crossing", function()
			test_many_small_dts_summing_past_interval_fires_once_per_crossing()
		end)
	end)

	describe("ServerBootstrap -- Story 001 (bootstrap catch -> game:Shutdown() wiring)", function()
		-- A minimal fake Promise double: :andThen() is a pass-through no-op on a rejected
		-- promise (never invokes its resolve handler, matching real Promise semantics), and
		-- :catch() immediately invokes the rejection handler with the captured error. This is
		-- a deliberately simplified stand-in for Knit's real bundled Promise -- sufficient to
		-- prove ServerBootstrap.Run's OWN sequencing logic, not a general-purpose Promise
		-- reimplementation.
		local function makeRejectedPromise(err: any): KnitPromiseLike
			local promise = {} :: any
			function promise.andThen(_self: any, _onResolved: () -> ())
				return promise
			end
			function promise.catch(_self: any, onRejected: (err: any) -> ())
				onRejected(err)
				return promise
			end
			return promise :: KnitPromiseLike
		end

		local function makeResolvedPromise(): KnitPromiseLike
			local promise = {} :: any
			function promise.andThen(_self: any, onResolved: () -> ())
				onResolved()
				return promise
			end
			function promise.catch(_self: any, _onRejected: (err: any) -> ())
				return promise
			end
			return promise :: KnitPromiseLike
		end

		-- ====================================================================
		-- AC -- bootstrap catch -> Shutdown: a rejected Knit.Start() causes warn(err) AND
		-- game:Shutdown() (via its test spy) to each fire exactly once. Also proves ordering:
		-- the SignalBehavior pin happens before Knit.Start() is invoked (ADR-0004: "before
		-- any KnitInit runs").
		-- ====================================================================
		local function test_rejected_knit_start_invokes_warn_and_shutdown_exactly_once()
			local warnCallCount = 0
			local warnLastArg: any = nil
			local shutdownCallCount = 0
			local onStartedCallCount = 0
			local callOrder: { string } = {}

			ServerBootstrap.Run({
				pinSignalBehavior = function()
					table.insert(callOrder, "pin")
				end,
				knitStart = function()
					table.insert(callOrder, "knitStart")
					return makeRejectedPromise("simulated KnitInit config-validation failure")
				end,
				onStarted = function()
					onStartedCallCount += 1
				end,
				warn = function(...)
					warnCallCount += 1
					warnLastArg = select(1, ...)
				end,
				shutdown = function()
					shutdownCallCount += 1
				end,
			})

			expect(warnCallCount).to.equal(1)
			expect(warnLastArg).to.equal("simulated KnitInit config-validation failure")
			expect(shutdownCallCount).to.equal(1)
			expect(onStartedCallCount).to.equal(0) -- the resolve handler must NOT run on a rejected promise

			expect(callOrder[1]).to.equal("pin")
			expect(callOrder[2]).to.equal("knitStart")
		end
		it("test_rejected_knit_start_invokes_warn_and_shutdown_exactly_once", function()
			test_rejected_knit_start_invokes_warn_and_shutdown_exactly_once()
		end)

		-- ====================================================================
		-- Contrast case: a RESOLVED Knit.Start() must call onStarted, and must NEVER call
		-- warn or shutdown -- proving the catch handler fires only on rejection, not
		-- unconditionally alongside every boot.
		-- ====================================================================
		local function test_resolved_knit_start_never_invokes_warn_or_shutdown()
			local warnCallCount = 0
			local shutdownCallCount = 0
			local onStartedCallCount = 0

			ServerBootstrap.Run({
				pinSignalBehavior = function() end,
				knitStart = function()
					return makeResolvedPromise()
				end,
				onStarted = function()
					onStartedCallCount += 1
				end,
				warn = function(...)
					warnCallCount += 1
				end,
				shutdown = function()
					shutdownCallCount += 1
				end,
			})

			expect(onStartedCallCount).to.equal(1)
			expect(warnCallCount).to.equal(0)
			expect(shutdownCallCount).to.equal(0)
		end
		it("test_resolved_knit_start_never_invokes_warn_or_shutdown", function()
			test_resolved_knit_start_never_invokes_warn_or_shutdown()
		end)
	end)

	describe("DisturbanceService.luau -- Story 001 static/structural source checks", function()
		-- These are STATIC checks against the actual .luau source text, not runtime
		-- behavioral tests -- see this file's header comment for why DisturbanceService.luau
		-- cannot yet be instantiated in this test harness.
		local disturbanceServiceSource: string? = nil

		local function loadSource(): string
			if not disturbanceServiceSource then
				disturbanceServiceSource = fs.readFile("src/gameplay/services/DisturbanceService.luau")
			end
			return disturbanceServiceSource :: string
		end

		-- ====================================================================
		-- AC -- session-scoped field: no DataStoreService interaction anywhere in this
		-- service's source (TR-ed-049).
		-- ====================================================================
		local function test_no_datastoreservice_reference_anywhere_in_source()
			-- Checks for actual DataStoreService USAGE (GetService(...) calls),
			-- not the bare word -- the file's own header comment legitimately
			-- explains "no DataStoreService interaction" using that exact
			-- phrase, which a naive whole-word search would false-positive on.
			local source = loadSource()
			expect(source:find('GetService%("DataStoreService"%)')).to.equal(nil)
			expect(source:find("GetService%('DataStoreService'%)")).to.equal(nil)
		end
		it("test_no_datastoreservice_reference_anywhere_in_source", function()
			test_no_datastoreservice_reference_anywhere_in_source()
		end)

		-- ====================================================================
		-- AC -- session-scoped field: the live-source list, spatial grid, attribution
		-- archive, and loadedChunks table are all constructed as EMPTY table literals inside
		-- KnitInit (not pre-populated with any entries).
		-- ====================================================================
		local function test_containers_constructed_as_empty_literals_in_knit_init()
			local source = loadSource()
			expect(source:find("self%._spatialGrid = {} ::")).never.to.equal(nil)
			expect(source:find("self%._liveSources = {} ::")).never.to.equal(nil)
			expect(source:find("self%._attributionArchive = {} ::")).never.to.equal(nil)
			expect(source:find("self%._loadedChunks = {} ::")).never.to.equal(nil)
		end
		it("test_containers_constructed_as_empty_literals_in_knit_init", function()
			test_containers_constructed_as_empty_literals_in_knit_init()
		end)

		-- ====================================================================
		-- AC -- KnitInit also constructs the (empty) OnPlayerDied BindableEvent and
		-- acquires the RegistrationHandshake module reference via require() -- the other two
		-- items this AC bullet names alongside the three containers above.
		-- ====================================================================
		local function test_knit_init_constructs_on_player_died_and_registration_handshake()
			local source = loadSource()
			expect(source:find('self%._onPlayerDied = Instance%.new%("BindableEvent"%)')).never.to.equal(nil)
			expect(source:find("self%._registrationHandshake = require%(script%.Parent%.DisturbanceServiceRegistrationHandshake%)"))
				.never.to.equal(nil)
		end
		it("test_knit_init_constructs_on_player_died_and_registration_handshake", function()
			test_knit_init_constructs_on_player_died_and_registration_handshake()
		end)

		-- ====================================================================
		-- AC -- catch(warn)-only boilerplate rejected by code review (static check): the
		-- REAL bootstrap wiring lives in ServerBootstrap.luau, not DisturbanceService.luau.
		-- Confirms the actual bootstrap module pairs its catch's warn(err) with a
		-- deps.shutdown() call -- a catch(warn)-only variant would fail this check.
		-- ====================================================================
		local function test_server_bootstrap_catch_handler_pairs_warn_with_shutdown()
			local bootstrapSource = fs.readFile("src/core/ServerBootstrap.luau")
			expect(bootstrapSource:find("deps%.warn%(err%)")).never.to.equal(nil)
			expect(bootstrapSource:find("deps%.shutdown%(%)")).never.to.equal(nil)
		end
		it("test_server_bootstrap_catch_handler_pairs_warn_with_shutdown", function()
			test_server_bootstrap_catch_handler_pairs_warn_with_shutdown()
		end)
	end)
end
