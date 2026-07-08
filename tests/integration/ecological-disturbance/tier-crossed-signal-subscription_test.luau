--!strict
-- tier-crossed-signal-subscription_test
--
-- Integration tests for Story 006: TierCrossedEvent Signal subscription contract (H.28's "a
-- subscribed mock Predator AI must receive it within 1/FIELD_UPDATE_HZ seconds" clause) and the
-- KnitInit-before-KnitStart subscriber-safety guarantee (ADR-0001 Rule 1).
-- Story: production/epics/ecological-disturbance/story-006-tier-classification-hysteresis-tiercrossedevent.md
-- ADR: docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md (Rule 1 -- "KnitInit
--      builds, KnitStart connects"; Signal-over-BindableEvent preference)
--      docs/architecture/adr-0004-disturbanceservice-core-architecture.md (TierCrossedEvent named
--      as a server-internal signal in the Public surface Architecture Diagram)
--
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceTierClassificationLogic.luau -- the REAL, already
--     unit-tested pure module (RunClassificationPass), reused here UNMODIFIED inside a behavioral
--     harness that mirrors DisturbanceService.luau's real KnitInit/_runTierClassificationPass/
--     GetTierCrossedSignal composition method-for-method.
--   src/gameplay/services/DisturbanceService.luau -- verified via STATIC/structural source-text
--     checks in the sibling unit test file (tier-classification-hysteresis-tiercrossedevent_test
--     .luau's own "wiring, static checks" describe block) -- Knit/Signal are not vendored under
--     ReplicatedStorage.Packages in this harness (matches RunController's own
--     get_run_ended_signal_test.luau precedent), so a live DisturbanceService instance is not
--     currently possible here either.
--
-- MOCK SIGNAL DISCLOSURE (identical to get_run_ended_signal_test.luau's own disclosure): the
-- "MockSignal" class below is a small, honest in-test stand-in for Knit's real bundled Signal
-- class (RbxUtil), NOT the real thing -- it exists solely to give this story's behavioral harness
-- something real to Connect()/Fire() against, with the exact semantics TierCrossedEvent's contract
-- requires: multiple independent subscribers, delivery order-independent of connection order, a
-- Disconnect() handle, and synchronous (same-Luau-frame, no yield) dispatch -- which is exactly
-- what proves H.28's "receives within 1/FIELD_UPDATE_HZ seconds" clause: a synchronous Signal:Fire
-- call has NO timing window to wait out at all, so receipt is provably faster than the 0.2s budget
-- by construction, not by a timer-based measurement.
--
-- Story Type: Integration -- coding-standards.md's bar is an automated integration test that must
-- pass (BLOCKING gate), placed under tests/integration/ since this exercises the
-- KnitInit-Signal-construction + per-pass-firing CONTRACT across a simulated subscriber, not a
-- single pure-logic formula (which the sibling tests/unit file already covers exhaustively).

local ServerScriptService = game:GetService("ServerScriptService")

local TierClassificationLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceTierClassificationLogic)

type Tier = TierClassificationLogic.Tier
type ClassificationPassEvent = TierClassificationLogic.ClassificationPassEvent

local TENSE_THRESHOLD = 0.30
local HUNT_THRESHOLD = 0.65
local HYSTERESIS_BAND = 0.03
local MAX_TIER_CASCADE_ITERATIONS = 4

-- ============================================================================
-- MockSignal -- see MOCK SIGNAL DISCLOSURE above. Array-based listener list; Fire() walks a
-- SNAPSHOT taken at fire-time (matches get_run_ended_signal_test.luau's own precedent exactly).
-- ============================================================================

type MockSignalListener = { fn: (...any) -> (), connected: boolean }
type MockConnection = { Disconnect: (self: MockConnection) -> () }

local MockSignal = {}
MockSignal.__index = MockSignal

function MockSignal.new()
	return setmetatable({ _listeners = {} :: { MockSignalListener } }, MockSignal)
end

function MockSignal:Connect(fn: (...any) -> ()): MockConnection
	local record: MockSignalListener = { fn = fn, connected = true }
	table.insert(self._listeners, record)

	local connection = {}
	function connection.Disconnect()
		record.connected = false
	end
	return (connection :: any) :: MockConnection
end

function MockSignal:Fire(...: any)
	local snapshot = table.clone(self._listeners)
	for _, record in snapshot do
		if record.connected then
			record.fn(...)
		end
	end
end

-- ============================================================================
-- FakeDisturbanceService -- mirrors DisturbanceService.luau's real KnitInit /
-- GetTierCrossedSignal / _runTierClassificationPass bodies method-for-method (this story's own
-- production deliverable), substituting MockSignal for the real (unvendored) Signal.new() and a
-- caller-supplied `liveSourcePositions` list for the real self._liveSources enumeration. Reuses
-- the real, already-unit-tested TierClassificationLogic module unmodified.
-- ============================================================================

local FakeDisturbanceService = {}
FakeDisturbanceService.__index = FakeDisturbanceService

function FakeDisturbanceService.new()
	return setmetatable({}, FakeDisturbanceService)
end

--- Mirrors DisturbanceService.luau's real KnitInit body exactly (the Story 006 slice of it):
--- self._previousTierAtPosition starts empty, self._tierCrossedEvent is constructed via (mock)
--- Signal.new() -- never deferred to KnitStart.
function FakeDisturbanceService:KnitInit()
	self._previousTierAtPosition = {} :: { [string]: Tier }
	self._tierCrossedEvent = MockSignal.new()
	self._liveSourcePositions = {} :: { Vector3 }
	self._fieldValueByPosition = {} :: { [Vector3]: number }
	self._contributorByPosition = {} :: { [Vector3]: { emissionId: string, initialMagnitude: number } }
end

--- Mirrors DisturbanceService.luau's real GetTierCrossedSignal body exactly: bare
--- `return self._tierCrossedEvent`, same instance every call.
function FakeDisturbanceService:GetTierCrossedSignal()
	return self._tierCrossedEvent
end

--- Test-only setup helpers (this harness's stand-in for the real self._liveSources table +
--- self:fieldValue()/self:_topContributorsAt() methods).
function FakeDisturbanceService:_setLiveSourcePosition(position: Vector3, fieldValueAtPassEnd: number, emissionId: string, initialMagnitude: number)
	table.insert(self._liveSourcePositions, position)
	self._fieldValueByPosition[position] = fieldValueAtPassEnd
	self._contributorByPosition[position] = { emissionId = emissionId, initialMagnitude = initialMagnitude }
end

--- Mirrors DisturbanceService.luau's real _runTierClassificationPass body exactly: dedup live
--- source positions, run the pure RunClassificationPass, fire the (mock) Signal once per returned
--- event -- SYNCHRONOUSLY, within this single Luau call (no task.wait/task.spawn/yield anywhere),
--- which is exactly what "receipt within 1/FIELD_UPDATE_HZ seconds" reduces to structurally.
function FakeDisturbanceService:_runTierClassificationPass()
	local positionEntries = TierClassificationLogic.DedupPositionsByCanonicalKey(self._liveSourcePositions)

	local events = TierClassificationLogic.RunClassificationPass(
		positionEntries,
		self._previousTierAtPosition,
		function(position: Vector3): number
			return self._fieldValueByPosition[position]
		end,
		function(position: Vector3): (string, number)
			local contributor = self._contributorByPosition[position]
			return contributor.emissionId, contributor.initialMagnitude
		end,
		TENSE_THRESHOLD,
		HUNT_THRESHOLD,
		HYSTERESIS_BAND,
		MAX_TIER_CASCADE_ITERATIONS
	)

	for _, event in events do
		self._tierCrossedEvent:Fire(event.crossedTier, event.position, event.emissionId, event.initialMagnitude)
	end
end

-- ============================================================================
-- MockPredatorAI -- a mock "subscriber service" simulating its own KnitStart phase, exactly as
-- get_run_ended_signal_test.luau's own MockSubscriber does: constructed independently, connects to
-- GetTierCrossedSignal() during its own simulated KnitStart.
-- ============================================================================

local MockPredatorAI = {}
MockPredatorAI.__index = MockPredatorAI

function MockPredatorAI.new()
	return setmetatable({ receivedCount = 0, lastCrossedTier = nil :: Tier?, lastPosition = nil :: Vector3?, lastEmissionId = nil :: string? }, MockPredatorAI)
end

function MockPredatorAI:KnitStart(disturbanceService)
	local predator = self
	disturbanceService:GetTierCrossedSignal():Connect(function(crossedTier: Tier, position: Vector3, emissionId: string, _initialMagnitude: number)
		predator.receivedCount += 1
		predator.lastCrossedTier = crossedTier
		predator.lastPosition = position
		predator.lastEmissionId = emissionId
	end)
end

return function()
	describe("DisturbanceService (Fake) -- Story 006 (GetTierCrossedSignal construction/identity)", function()
		local function test_signal_non_nil_immediately_after_knit_init_before_any_knit_start()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local signal = service:GetTierCrossedSignal()

			expect(signal).never.to.equal(nil)
		end
		it(
			"test_signal_non_nil_immediately_after_knit_init_before_any_knit_start",
			function()
				test_signal_non_nil_immediately_after_knit_init_before_any_knit_start()
			end
		)

		local function test_get_tier_crossed_signal_returns_same_instance_every_call()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local first = service:GetTierCrossedSignal()
			local second = service:GetTierCrossedSignal()

			expect(first).to.equal(second)
		end
		it(
			"test_get_tier_crossed_signal_returns_same_instance_every_call",
			function()
				test_get_tier_crossed_signal_returns_same_instance_every_call()
			end
		)
	end)

	describe("DisturbanceService (Fake) -- Story 006 (H.28 -- mock Predator AI receives synchronously within one pass)", function()
		local function test_mock_predator_ai_receives_tier_crossed_event_synchronously_same_pass()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local predator = MockPredatorAI.new()
			predator:KnitStart(service)

			local P = Vector3.new(10, 0, 20)
			service:_setLiveSourcePosition(P, 0.31, "emission-1", 0.15)

			-- SYNCHRONOUS call -- no task.wait() anywhere in this test. ADR-0001's zero-yield Signal
			-- dispatch guarantee (Signal:Fire() is a plain Luau call) means the assertion below
			-- observes the result immediately, with no timing window to wait out at all -- this is
			-- structurally faster than the 1/FIELD_UPDATE_HZ = 0.2s budget H.28 requires, by
			-- construction rather than by a timer-based measurement.
			service:_runTierClassificationPass()

			expect(predator.receivedCount).to.equal(1)
			expect(predator.lastCrossedTier).to.equal("Tense")
			expect(predator.lastPosition).to.equal(P)
			expect(predator.lastEmissionId).to.equal("emission-1")
		end
		it(
			"test_mock_predator_ai_receives_tier_crossed_event_synchronously_same_pass",
			function()
				test_mock_predator_ai_receives_tier_crossed_event_synchronously_same_pass()
			end
		)

		-- Multi-subscriber: shuffled connection order, all subscribers receive the SAME fire
		-- exactly once (mirrors get_run_ended_signal_test.luau's own shuffled-order precedent).
		local function test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local subA = MockPredatorAI.new()
			local subB = MockPredatorAI.new()
			local subC = MockPredatorAI.new()

			subC:KnitStart(service)
			subA:KnitStart(service)
			subB:KnitStart(service)

			service:_setLiveSourcePosition(Vector3.new(0, 0, 0), 0.85, "emission-hunt", 0.5)
			service:_runTierClassificationPass()

			expect(subA.receivedCount).to.equal(1)
			expect(subB.receivedCount).to.equal(1)
			expect(subC.receivedCount).to.equal(1)
			expect(subA.lastCrossedTier).to.equal("Hunt")
			expect(subB.lastCrossedTier).to.equal("Hunt")
			expect(subC.lastCrossedTier).to.equal("Hunt")
		end
		it(
			"test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once",
			function()
				test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once()
			end
		)

		-- Zero subscribers -- pass runs and fires with no error, simply unobserved.
		local function test_zero_subscribers_pass_does_not_error()
			local service = FakeDisturbanceService.new()
			service:KnitInit()
			service:_setLiveSourcePosition(Vector3.new(5, 0, 5), 0.31, "emission-x", 0.1)

			local ok = pcall(function()
				service:_runTierClassificationPass()
			end)

			expect(ok).to.equal(true)
		end
		it("test_zero_subscribers_pass_does_not_error", function()
			test_zero_subscribers_pass_does_not_error()
		end)

		-- H.28b end-to-end through the Fake service: three positions crossing Tense in the same
		-- pass -- the subscriber receives exactly ONE event, for the highest-fieldValue position.
		local function test_h28b_coalescing_end_to_end_through_fake_service()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local predator = MockPredatorAI.new()
			predator:KnitStart(service)

			local pHigh = Vector3.new(100, 0, 0)
			service:_setLiveSourcePosition(Vector3.new(0, 0, 0), 0.31, "emission-low", 0.31)
			service:_setLiveSourcePosition(pHigh, 0.40, "emission-high", 0.40)
			service:_setLiveSourcePosition(Vector3.new(200, 0, 0), 0.35, "emission-mid", 0.35)

			service:_runTierClassificationPass()

			expect(predator.receivedCount).to.equal(1)
			expect(predator.lastCrossedTier).to.equal("Tense")
			expect(predator.lastPosition).to.equal(pHigh)
			expect(predator.lastEmissionId).to.equal("emission-high")
		end
		it(
			"test_h28b_coalescing_end_to_end_through_fake_service",
			function()
				test_h28b_coalescing_end_to_end_through_fake_service()
			end
		)

		-- Cross-pass persistence: previousTierAtPosition survives across TWO successive
		-- _runTierClassificationPass calls (simulating two field-update ticks), and hysteresis
		-- correctly suppresses a spurious re-fire on the second tick when the position stays within
		-- the same tier band.
		local function test_cross_pass_persistence_suppresses_spurious_refire_within_band()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local predator = MockPredatorAI.new()
			predator:KnitStart(service)

			local P = Vector3.new(1, 0, 1)

			-- Tick 1: crosses into Tense.
			service._liveSourcePositions = {}
			service:_setLiveSourcePosition(P, 0.31, "emission-1", 0.15)
			service:_runTierClassificationPass()
			expect(predator.receivedCount).to.equal(1)

			-- Tick 2: still within the Tense hysteresis band (0.29 >= 0.27) -- no re-fire.
			service._liveSourcePositions = {}
			service._fieldValueByPosition = {}
			service._contributorByPosition = {}
			service:_setLiveSourcePosition(P, 0.29, "emission-1", 0.15)
			service:_runTierClassificationPass()
			expect(predator.receivedCount).to.equal(1) -- unchanged -- no spurious refire
		end
		it(
			"test_cross_pass_persistence_suppresses_spurious_refire_within_band",
			function()
				test_cross_pass_persistence_suppresses_spurious_refire_within_band()
			end
		)
	end)
end
