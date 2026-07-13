--!strict
-- get_run_ended_signal_test
--
-- Integration tests for Story 002: RunController GetRunEndedSignal Accessor and
-- KnitInit/KnitStart Subscriber-Safety Verification.
-- Story: production/epics/runcontroller/story-002-getrunendedsignal-accessor.md
-- ADR: docs/architecture/adr-0002-runcontroller-architecture.md (Key Interfaces --
--      GetRunEndedSignal, Validation Criteria -- non-nil-before-any-KnitStart)
--      docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md (Rule 1 --
--      "KnitInit builds, KnitStart connects" -- the general discipline this story verifies
--      a concrete instance of)
--
-- Production code under test:
--   src/gameplay/services/RunController.luau -- GetRunEndedSignal() accessor (added this
--     story) and the KnitInit-time `self._runEnded = Signal.new()` construction (Story 001,
--     re-verified here per this story's own AC-2) -- verified via STATIC/structural
--     source-text checks (first describe() block), matching Story 001's own precedent
--     (tests/unit/runcontroller/run_end_condition_raised_test.luau): RunController.luau
--     cannot be instantiated live under this Lune test harness, because it require()s
--     ReplicatedStorage.Packages.Knit and ReplicatedStorage.Packages.Signal, and NEITHER
--     package is vendored anywhere in this repo (confirmed by search -- no Packages/Knit or
--     Packages/Signal directory exists, and tests/run_tests.lua's setup_roblox_environment()
--     does not mount any ReplicatedStorage.Packages folder at all, only
--     ServerScriptService.gameplay.services/core -- see tests/README.md's "Future
--     Enhancements" section, item 2, which names this exact gap as deferred).
--   src/gameplay/services/RunControllerLogic.luau -- the pure, dependency-free
--     idempotency-latch predicate + payload constructor (already unit-tested by Story 001's
--     own suite) -- reused here, unmodified, inside a behavioral test harness (second
--     describe() block) that mirrors RunController.luau's real
--     KnitInit/GetRunEndedSignal/RunEndConditionRaised composition method-for-method, the
--     same way Story 001's own simulateRunEndConditionRaised() harness did.
--
-- MOCK SIGNAL DISCLOSURE (read before extending this file): the "MockSignal" class below is
-- a small, honest in-test stand-in for Knit's real bundled Signal class (RbxUtil), NOT the
-- real thing -- it is not vendored anywhere in this repo (see above). It exists solely to
-- give this story's behavioral harness something real to Connect()/Fire() against, with the
-- exact semantics this story's ACs require: multiple independent subscribers, delivery
-- order-independent of connection order, a Disconnect() handle, and NO replay/cached-last-
-- value behavior for a subscriber connecting after a fire has already happened. This mirrors
-- every prior story's own "Knit/Signal not vendored" disclosure (see
-- run_end_condition_raised_test.luau's header and tests/README.md's Future Enhancements #2)
-- -- flagged here again, explicitly, per this story's own instructions, rather than silently
-- assumed.
--
-- Story Type: Integration -- coding-standards.md's bar is an automated integration test that
-- must pass (BLOCKING gate), placed under tests/integration/ per this story's own Test
-- Evidence section (not tests/unit/, since this story exercises the KnitInit/KnitStart
-- cross-service-ordering CONTRACT, not a single pure-logic formula).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local RunControllerLogic = require(ServerScriptService.gameplay.services.RunControllerLogic)

type ConditionType = RunControllerLogic.ConditionType
type DefeatReason = RunControllerLogic.DefeatReason
type SquadStateSnapshot = RunControllerLogic.SquadStateSnapshot

-- ============================================================================
-- MockSignal -- see MOCK SIGNAL DISCLOSURE above. Array-based listener list; Fire() walks a
-- SNAPSHOT taken at fire-time, so nothing here retains "the fired value" once Fire() returns
-- -- there is no state a later Connect() could possibly replay from, by construction, not by
-- extra guard logic (matching this story's Implementation Notes: "don't add replay-prevention
-- logic to satisfy this AC").
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
-- FakeRunController -- mirrors RunController.luau's real KnitInit / GetRunEndedSignal /
-- RunEndConditionRaised bodies method-for-method (Story 001 + Story 002's own production
-- deliverable), substituting MockSignal for the real (unvendored) Signal.new(). Reuses the
-- real, already-unit-tested RunControllerLogic module unmodified -- only the Signal
-- implementation is mocked, matching this story's own instruction to build a mock Signal, not
-- a mock of the whole latch/payload logic.
-- ============================================================================

local FakeRunController = {}
FakeRunController.__index = FakeRunController

function FakeRunController.new()
	return setmetatable({}, FakeRunController)
end

--- Mirrors RunController.luau's real KnitInit body exactly: _hasEnded starts false,
--- _runEnded is constructed via (mock) Signal.new() -- never deferred to KnitStart.
function FakeRunController:KnitInit()
	self._hasEnded = false
	self._runEnded = MockSignal.new()
end

--- Mirrors RunController.luau's real GetRunEndedSignal body exactly: return self._runEnded,
--- no construction here -- same instance every call.
function FakeRunController:GetRunEndedSignal()
	return self._runEnded
end

--- Mirrors RunController.luau's real RunEndConditionRaised body exactly: ShouldFire guard,
--- latch, BuildPayload, Fire.
function FakeRunController:RunEndConditionRaised(
	conditionType: ConditionType,
	squadState: SquadStateSnapshot,
	defeatReason: DefeatReason?
)
	if not RunControllerLogic.ShouldFire(self._hasEnded) then
		return
	end
	self._hasEnded = true
	local now = os.time()
	local payload = RunControllerLogic.BuildPayload(conditionType, squadState, now, defeatReason)
	self._runEnded:Fire(payload)
end

-- ============================================================================
-- MockSubscriber -- a mock "subscriber service" simulating its own KnitStart phase, exactly
-- as this story's Implementation Notes describe: constructed independently, connects to
-- GetRunEndedSignal() during its own simulated KnitStart.
-- ============================================================================

local MockSubscriber = {}
MockSubscriber.__index = MockSubscriber

function MockSubscriber.new(name: string)
	return setmetatable({ name = name, receivedCount = 0, lastPayload = nil :: any }, MockSubscriber)
end

function MockSubscriber:KnitStart(runController)
	local subscriber = self
	runController:GetRunEndedSignal():Connect(function(payload: any)
		subscriber.receivedCount += 1
		subscriber.lastPayload = payload
	end)
end

return function()
	describe("RunController.luau -- Story 002 static/structural source checks (accessor existence, KnitInit-construction re-verification, no raw BindableEvent)", function()
		-- STATIC checks against the actual .luau source text, not runtime behavior -- see this
		-- file's header comment for why RunController.luau cannot yet be instantiated in this
		-- test harness (Knit and Signal are not vendored under ReplicatedStorage.Packages).
		local runControllerSource: string? = nil

		-- Strips Lua/Luau single-line comments, identical helper (and its documented
		-- `--`-in-string-literal caveat) already used by
		-- tests/unit/runcontroller/run_end_condition_raised_test.luau and the
		-- ecological-disturbance test files.
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function loadServiceSource(): string
			if not runControllerSource then
				runControllerSource = stripLuaComments(fs.readFile("src/gameplay/services/RunController.luau"))
			end
			return runControllerSource :: string
		end

		-- ====================================================================
		-- AC-1 -- GetRunEndedSignal exists as a plain colon method.
		-- ====================================================================
		local function test_get_run_ended_signal_declared_as_plain_colon_method()
			local source = loadServiceSource()
			expect(source:find("function RunController:GetRunEndedSignal%(")).never.to.equal(nil)
		end
		it("test_get_run_ended_signal_declared_as_plain_colon_method", function()
			test_get_run_ended_signal_declared_as_plain_colon_method()
		end)

		-- ====================================================================
		-- AC-1/AC-4 -- the accessor's body is a bare `return self._runEnded` and never
		-- constructs a new Signal (structural proof that every call returns the SAME
		-- instance, not a new object per call). Isolates the text between the method's
		-- declaration and its own first `end` -- safe here because, unlike
		-- RunEndConditionRaised, this method body contains no nested if/then block that
		-- could contain an earlier `end`.
		-- ====================================================================
		local function test_get_run_ended_signal_body_is_bare_return_self_run_ended()
			local source = loadServiceSource()
			local declStart = source:find("function RunController:GetRunEndedSignal%(")
			expect(declStart).never.to.equal(nil)
			local bodyEnd = source:find("\nend", declStart :: number)
			expect(bodyEnd).never.to.equal(nil)
			local bodySlice = source:sub(declStart :: number, bodyEnd :: number)
			expect(bodySlice:find("return self%._runEnded")).never.to.equal(nil)
			expect(bodySlice:find("Signal%.new%(")).to.equal(nil)
		end
		it("test_get_run_ended_signal_body_is_bare_return_self_run_ended", function()
			test_get_run_ended_signal_body_is_bare_return_self_run_ended()
		end)

		-- ====================================================================
		-- AC-2 (re-verification, Story 001's construction) -- self._runEnded = Signal.new()
		-- sits inside KnitInit's own body slice, not KnitStart or anywhere else.
		-- ====================================================================
		local function test_run_ended_constructed_via_signal_new_inside_knit_init()
			local source = loadServiceSource()
			local declStart = source:find("function RunController:KnitInit%(")
			expect(declStart).never.to.equal(nil)
			local bodyEnd = source:find("\nend", declStart :: number)
			expect(bodyEnd).never.to.equal(nil)
			local bodySlice = source:sub(declStart :: number, bodyEnd :: number)
			expect(bodySlice:find("self%._runEnded = Signal%.new%(%)")).never.to.equal(nil)
		end
		it("test_run_ended_constructed_via_signal_new_inside_knit_init", function()
			test_run_ended_constructed_via_signal_new_inside_knit_init()
		end)

		-- ====================================================================
		-- AC-1/AC-2 edge case -- no raw Instance.new("BindableEvent") appears anywhere in
		-- the module (re-verified here per this story's own QA Test Cases, not just assumed
		-- carried-over from Story 001).
		-- ====================================================================
		local function test_no_raw_bindable_event_anywhere_in_file()
			local source = loadServiceSource()
			expect(source:find('Instance%.new%("BindableEvent"%)')).to.equal(nil)
		end
		it("test_no_raw_bindable_event_anywhere_in_file", function()
			test_no_raw_bindable_event_anywhere_in_file()
		end)

		-- ====================================================================
		-- Structural guard against the "constructed inside KnitStart" forbidden pattern
		-- (ADR-0001 Rule 1) -- RunController.luau currently declares no KnitStart method at
		-- all, so there is nothing for GetRunEndedSignal to be nested inside. This check
		-- pins that fact so a future change that adds a KnitStart method is forced to
		-- re-examine this test (and, per ADR-0001, must not move any construction into it).
		-- ====================================================================
		local function test_no_knit_start_method_currently_exists_in_file()
			local source = loadServiceSource()
			expect(source:find("function RunController:KnitStart%(")).to.equal(nil)
		end
		it("test_no_knit_start_method_currently_exists_in_file", function()
			test_no_knit_start_method_currently_exists_in_file()
		end)
	end)

	describe("RunController -- Story 002 behavioral tests (MockSignal + FakeRunController harness)", function()
		-- ====================================================================
		-- AC-3 -- GetRunEndedSignal returns non-nil immediately after KnitInit completes,
		-- before any KnitStart runs -- the exact ADR-0002 Validation Criteria scenario.
		-- ====================================================================
		local function test_signal_non_nil_immediately_after_knit_init_before_any_knit_start()
			local runController = FakeRunController.new()
			runController:KnitInit()

			local signal = runController:GetRunEndedSignal()

			expect(signal).never.to.equal(nil)
		end
		it("test_signal_non_nil_immediately_after_knit_init_before_any_knit_start", function()
			test_signal_non_nil_immediately_after_knit_init_before_any_knit_start()
		end)

		-- Edge case: other simulated services' KnitInits running before/after RunController's
		-- own (still all before any KnitStart) -- result unchanged, still non-nil. Knit's own
		-- guarantee is only "all KnitInits complete before any KnitStart begins," not any
		-- particular KnitInit ordering, so this exercises that the accessor doesn't depend on
		-- RunController's KnitInit running first or last among its peers.
		local function test_signal_still_non_nil_with_other_simulated_services_knit_init_interleaved()
			local otherServiceAInitRan = false
			local otherServiceBInitRan = false

			otherServiceAInitRan = true
			local runController = FakeRunController.new()
			runController:KnitInit()
			otherServiceBInitRan = true

			expect(otherServiceAInitRan).to.equal(true)
			expect(otherServiceBInitRan).to.equal(true)
			expect(runController:GetRunEndedSignal()).never.to.equal(nil)
		end
		it("test_signal_still_non_nil_with_other_simulated_services_knit_init_interleaved", function()
			test_signal_still_non_nil_with_other_simulated_services_knit_init_interleaved()
		end)

		-- ====================================================================
		-- AC-4 -- every call returns the SAME Signal instance.
		-- ====================================================================
		local function test_get_run_ended_signal_returns_same_instance_every_call()
			local runController = FakeRunController.new()
			runController:KnitInit()

			local first = runController:GetRunEndedSignal()
			local second = runController:GetRunEndedSignal()

			expect(first).to.equal(second)
		end
		it("test_get_run_ended_signal_returns_same_instance_every_call", function()
			test_get_run_ended_signal_returns_same_instance_every_call()
		end)

		-- Edge case: identity holds regardless of which "caller service" asks.
		local function test_get_run_ended_signal_same_instance_from_two_different_caller_contexts()
			local runController = FakeRunController.new()
			runController:KnitInit()

			local function callerServiceA()
				return runController:GetRunEndedSignal()
			end
			local function callerServiceB()
				return runController:GetRunEndedSignal()
			end

			expect(callerServiceA()).to.equal(callerServiceB())
		end
		it("test_get_run_ended_signal_same_instance_from_two_different_caller_contexts", function()
			test_get_run_ended_signal_same_instance_from_two_different_caller_contexts()
		end)

		-- ====================================================================
		-- AC-5 -- order-independent multi-subscriber receipt: shuffled order (C, A, B).
		-- ====================================================================
		local function test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once()
			local runController = FakeRunController.new()
			runController:KnitInit()

			local subA = MockSubscriber.new("A")
			local subB = MockSubscriber.new("B")
			local subC = MockSubscriber.new("C")

			-- Deliberately shuffled relative order: C connects first, then A, then B --
			-- simulating that Knit gives no KnitStart-ordering guarantee between services.
			subC:KnitStart(runController)
			subA:KnitStart(runController)
			subB:KnitStart(runController)

			local squadState: SquadStateSnapshot = { aliveCount = 0, totalCount = 4 }
			runController:RunEndConditionRaised("wipe", squadState, nil)

			expect(subA.receivedCount).to.equal(1)
			expect(subB.receivedCount).to.equal(1)
			expect(subC.receivedCount).to.equal(1)
			expect(subA.lastPayload).to.equal(subB.lastPayload)
			expect(subB.lastPayload).to.equal(subC.lastPayload)
		end
		it("test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once", function()
			test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once()
		end)

		-- Edge case: reverse of the shuffled order above (A, B, C) -- proves the outcome does
		-- not depend on connection order, not just spot-checking one arbitrary order.
		local function test_reverse_connection_order_all_subscribers_receive_fire_exactly_once()
			local runController = FakeRunController.new()
			runController:KnitInit()

			local subA = MockSubscriber.new("A")
			local subB = MockSubscriber.new("B")
			local subC = MockSubscriber.new("C")

			subA:KnitStart(runController)
			subB:KnitStart(runController)
			subC:KnitStart(runController)

			local squadState: SquadStateSnapshot = { aliveCount = 4, totalCount = 4 }
			runController:RunEndConditionRaised("victory", squadState, nil)

			expect(subA.receivedCount).to.equal(1)
			expect(subB.receivedCount).to.equal(1)
			expect(subC.receivedCount).to.equal(1)
			expect(subA.lastPayload).to.equal(subB.lastPayload)
			expect(subB.lastPayload).to.equal(subC.lastPayload)
		end
		it("test_reverse_connection_order_all_subscribers_receive_fire_exactly_once", function()
			test_reverse_connection_order_all_subscribers_receive_fire_exactly_once()
		end)

		-- Edge case: 0 subscribers connected -- fire is simply unobserved, no error.
		local function test_zero_subscribers_fire_does_not_error()
			local runController = FakeRunController.new()
			runController:KnitInit()

			local ok = pcall(function()
				runController:RunEndConditionRaised("wipe", { aliveCount = 0, totalCount = 4 }, nil)
			end)

			expect(ok).to.equal(true)
		end
		it("test_zero_subscribers_fire_does_not_error", function()
			test_zero_subscribers_fire_does_not_error()
		end)

		-- Edge case: 1 subscriber connects, disconnects, then a second subscriber connects
		-- before the fire -- only the still-connected subscriber receives it.
		local function test_disconnected_subscriber_does_not_receive_fire_only_still_connected_second_subscriber_does()
			local runController = FakeRunController.new()
			runController:KnitInit()

			local firstReceivedCount = 0
			local firstConnection = runController:GetRunEndedSignal():Connect(function()
				firstReceivedCount += 1
			end)
			firstConnection:Disconnect()

			local secondSubscriber = MockSubscriber.new("second")
			secondSubscriber:KnitStart(runController)

			runController:RunEndConditionRaised("wipe", { aliveCount = 0, totalCount = 4 }, nil)

			expect(firstReceivedCount).to.equal(0)
			expect(secondSubscriber.receivedCount).to.equal(1)
		end
		it(
			"test_disconnected_subscriber_does_not_receive_fire_only_still_connected_second_subscriber_does",
			function()
				test_disconnected_subscriber_does_not_receive_fire_only_still_connected_second_subscriber_does()
			end
		)

		-- ====================================================================
		-- AC-6 -- a subscriber connecting AFTER RunEnded has already fired does not receive
		-- a replayed fire.
		-- ====================================================================
		local function test_late_subscriber_after_fire_does_not_receive_replay()
			local runController = FakeRunController.new()
			runController:KnitInit()

			runController:RunEndConditionRaised("wipe", { aliveCount = 0, totalCount = 4 }, nil)

			local lateSubscriber = MockSubscriber.new("late")
			lateSubscriber:KnitStart(runController)

			expect(lateSubscriber.receivedCount).to.equal(0)
		end
		it("test_late_subscriber_after_fire_does_not_receive_replay", function()
			test_late_subscriber_after_fire_does_not_receive_replay()
		end)

		-- Edge case: the late subscriber connects on the VERY NEXT line of code after the
		-- fire -- confirms there is no timing window where replay might incidentally occur.
		-- No task.wait() anywhere in this test: ADR-0001's zero-yield, synchronous-dispatch
		-- guarantee (Signal:Fire() is a plain Luau call) means there is no timing window to
		-- wait out in the first place -- if replay were happening, it would already have
		-- happened by the assertion below.
		local function test_late_subscriber_connecting_on_the_very_next_line_after_fire_still_does_not_replay()
			local runController = FakeRunController.new()
			runController:KnitInit()

			local receivedCount = 0
			runController:RunEndConditionRaised("victory", { aliveCount = 4, totalCount = 4 }, nil)
			local connection = runController:GetRunEndedSignal():Connect(function()
				receivedCount += 1
			end)

			expect(receivedCount).to.equal(0)
			expect(connection).never.to.equal(nil)
		end
		it(
			"test_late_subscriber_connecting_on_the_very_next_line_after_fire_still_does_not_replay",
			function()
				test_late_subscriber_connecting_on_the_very_next_line_after_fire_still_does_not_replay()
			end
		)
	end)
end
