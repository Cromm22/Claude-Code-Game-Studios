--!strict
-- disturbance-band-crossed-signal_test
--
-- Integration tests for Story 009: OnDisturbanceBandCrossed Squad-Aggregate Band-Crossing Signal.
-- Story: production/epics/ecological-disturbance/story-009-disturbance-band-crossed-signal.md
-- ADR: docs/architecture/adr-0004-disturbanceservice-core-architecture.md (Public surface
--      Architecture Diagram; server-internal signal discipline matching TierCrossedEvent's own
--      dispatch mechanism -- GetTierCrossedSignal()'s naming precedent, extended here to
--      GetDisturbanceBandCrossedSignal())
--      docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md (Rule 1 -- "KnitInit
--      builds, KnitStart connects"; Signal-over-BindableEvent preference)
--
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceBandCrossedLogic.luau -- the REAL, dependency-free
--     pure module (ClassifySquadBandCrossing/DirectionFor), reused here UNMODIFIED inside a
--     behavioral harness that mirrors DisturbanceService.luau's real
--     KnitInit/_runBandCrossedPass/GetDisturbanceBandCrossedSignal composition method-for-method.
--   src/gameplay/services/DisturbanceService.luau -- verified via STATIC/structural source-text
--     checks (AC-H.28d(c) describe block below) -- Knit/Signal are not vendored under
--     ReplicatedStorage.Packages in this harness (matches Story 006's own
--     tier-crossed-signal-subscription_test.luau precedent), so a live DisturbanceService
--     instance is not currently possible here either.
--
-- SCOPE NOTE: GetSquadAggregateT(nil)'s own unfiltered-max/exclusion-form/finiteness-guard math is
-- already exhaustively unit-tested by squad-aggregate-t-accessor_test.luau and is NOT re-tested
-- here. This file's FakeDisturbanceService injects the squadT SCALAR directly via `_setSquadT`,
-- exactly mirroring Story 006's own tier-crossed-signal-subscription_test.luau precedent of
-- injecting `fieldValueByPosition` directly rather than re-composing the full spatial-grid/decay
-- pipeline -- this file's job is to exercise the NEW band-crossing production code
-- (DisturbanceServiceBandCrossedLogic + DisturbanceService's own _runBandCrossedPass composition),
-- not to re-verify an already-covered upstream dependency.
--
-- MOCK SIGNAL DISCLOSURE (identical to tier-crossed-signal-subscription_test.luau's own
-- disclosure): the "MockSignal" class below is a small, honest in-test stand-in for Knit's real
-- bundled Signal class (RbxUtil), NOT the real thing -- it exists solely to give this story's
-- behavioral harness something real to Connect()/Fire() against, with the exact semantics
-- OnDisturbanceBandCrossed's contract requires: multiple independent subscribers, delivery
-- order-independent of connection order, a Disconnect() handle, and synchronous (same-Luau-frame,
-- no yield) dispatch.
--
-- Story Type: Integration -- coding-standards.md's bar is an automated integration test that must
-- pass (BLOCKING gate), placed under tests/integration/ since this exercises the
-- KnitInit-Signal-construction + per-pass-firing + first-pass-suppression CONTRACT across a
-- simulated subscriber, not a single pure-logic formula in isolation.

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local BandCrossedLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceBandCrossedLogic)
local TierClassificationLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceTierClassificationLogic)

type Tier = BandCrossedLogic.Tier
type Direction = BandCrossedLogic.Direction

-- CALLBACK-INJECTION DESIGN (see DisturbanceServiceBandCrossedLogic.luau's own header note):
-- BandCrossedLogic never require()s TierClassificationLogic itself (script.Parent-relative
-- require() is unresolvable under this project's loadstring-based Lune test harness for MODULES
-- loaded via run_tests.lua's own load_luau_file). This TEST FILE, however, is proven able to
-- require() multiple sibling modules at its own top level (matches
-- tier-classification-hysteresis-tiercrossedevent_test.luau's own multi-require precedent), so it
-- binds the REAL TierClassificationLogic.ClassifyWithCascade here and threads it through
-- FakeDisturbanceService's own _runBandCrossedPass below -- genuine end-to-end reuse of Story
-- 006's already-unit-tested settle loop, not a mocked stand-in.
local classifyWithCascadeFn: BandCrossedLogic.ClassifyWithCascadeFn = TierClassificationLogic.ClassifyWithCascade

local TENSE_THRESHOLD = 0.30
local HUNT_THRESHOLD = 0.65
local HYSTERESIS_BAND = 0.03
local MAX_TIER_CASCADE_ITERATIONS = 4

-- ============================================================================
-- MockSignal -- see MOCK SIGNAL DISCLOSURE above. Array-based listener list; Fire() walks a
-- SNAPSHOT taken at fire-time (matches tier-crossed-signal-subscription_test.luau's own
-- precedent exactly).
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
-- GetDisturbanceBandCrossedSignal / _runBandCrossedPass bodies method-for-method (this story's own
-- production deliverable), substituting MockSignal for the real (unvendored) Signal.new(), a
-- caller-supplied `_squadT` scalar for the real self:GetSquadAggregateT(nil) composition, and a
-- caller-supplied `_now` value for the real workspace:GetServerTimeNow() clock sample (see
-- DisturbanceService.luau's own NO _setTestClock SEAM note -- this harness-local fake clock plays
-- that role for testing purposes only). Reuses the real, already-unit-coverable
-- DisturbanceServiceBandCrossedLogic module unmodified.
-- ============================================================================

local FakeDisturbanceService = {}
FakeDisturbanceService.__index = FakeDisturbanceService

function FakeDisturbanceService.new()
	return setmetatable({}, FakeDisturbanceService)
end

--- Mirrors DisturbanceService.luau's real KnitInit body exactly (the Story 009 slice of it):
--- self._previousSquadTier starts nil (H.28d(d)'s first-pass sentinel), self
--- ._disturbanceBandCrossedSignal is constructed via (mock) Signal.new() -- never deferred to
--- KnitStart.
function FakeDisturbanceService:KnitInit()
	self._previousSquadTier = nil :: Tier?
	self._disturbanceBandCrossedSignal = MockSignal.new()
	self._squadT = 0.0
	self._now = 0
end

--- Mirrors DisturbanceService.luau's real GetDisturbanceBandCrossedSignal body exactly: bare
--- `return self._disturbanceBandCrossedSignal`, same instance every call.
function FakeDisturbanceService:GetDisturbanceBandCrossedSignal()
	return self._disturbanceBandCrossedSignal
end

--- Test-only setup helpers (this harness's stand-in for the real self:GetSquadAggregateT(nil)
--- composition and the real workspace:GetServerTimeNow() clock read).
function FakeDisturbanceService:_setSquadT(t: number)
	self._squadT = t
end

function FakeDisturbanceService:_setNow(now: number)
	self._now = now
end

--- Mirrors DisturbanceService.luau's real _runBandCrossedPass body exactly: classify via the
--- (real) DisturbanceServiceBandCrossedLogic.ClassifySquadBandCrossing, persist the returned
--- finalTier as the new self._previousSquadTier UNCONDITIONALLY (first pass or not), then fire the
--- (mock) Signal once per returned event, all stamped with the SAME single per-pass clock sample
--- (CLOCK-SAMPLE-ONCE-PER-PASS design call, mirrored from the real production method) --
--- SYNCHRONOUSLY, within this single Luau call (no task.wait/task.spawn/yield anywhere).
function FakeDisturbanceService:_runBandCrossedPass()
	local finalTier, events = BandCrossedLogic.ClassifySquadBandCrossing(
		self._squadT,
		self._previousSquadTier,
		classifyWithCascadeFn,
		TENSE_THRESHOLD,
		HUNT_THRESHOLD,
		HYSTERESIS_BAND,
		MAX_TIER_CASCADE_ITERATIONS
	)

	self._previousSquadTier = finalTier

	if #events > 0 then
		local now = self._now
		for _, event in events do
			self._disturbanceBandCrossedSignal:Fire(event.direction, event.newTier, now)
		end
	end
end

-- ============================================================================
-- MockPlayerController -- a mock "subscriber service" simulating its own KnitStart phase, exactly
-- as tier-crossed-signal-subscription_test.luau's own MockPredatorAI does: constructed
-- independently, connects to GetDisturbanceBandCrossedSignal() during its own simulated KnitStart.
-- Named "PlayerController" (not "PredatorAI") since this signal's real-world consumer is Player
-- Controller's OnWorldResponseCue, per this story's own Out of Scope section -- the consumer
-- itself is out of this epic, but the NAME is chosen to avoid implying the wrong consumer.
-- ============================================================================

local MockPlayerController = {}
MockPlayerController.__index = MockPlayerController

function MockPlayerController.new()
	return setmetatable({
		receivedCount = 0,
		receivedEvents = {} :: { { direction: Direction, newTier: Tier, timestamp: number } },
	}, MockPlayerController)
end

function MockPlayerController:KnitStart(disturbanceService)
	local subscriber = self
	disturbanceService:GetDisturbanceBandCrossedSignal():Connect(function(direction: Direction, newTier: Tier, timestamp: number)
		subscriber.receivedCount += 1
		table.insert(subscriber.receivedEvents, { direction = direction, newTier = newTier, timestamp = timestamp })
	end)
end

function MockPlayerController:lastEvent()
	return self.receivedEvents[#self.receivedEvents]
end

return function()
	describe("DisturbanceService (Fake) -- Story 009 (GetDisturbanceBandCrossedSignal construction/identity)", function()
		local function test_signal_non_nil_immediately_after_knit_init_before_any_knit_start()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local signal = service:GetDisturbanceBandCrossedSignal()

			expect(signal).never.to.equal(nil)
		end
		it(
			"test_signal_non_nil_immediately_after_knit_init_before_any_knit_start",
			function()
				test_signal_non_nil_immediately_after_knit_init_before_any_knit_start()
			end
		)

		local function test_get_disturbance_band_crossed_signal_returns_same_instance_every_call()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local first = service:GetDisturbanceBandCrossedSignal()
			local second = service:GetDisturbanceBandCrossedSignal()

			expect(first).to.equal(second)
		end
		it(
			"test_get_disturbance_band_crossed_signal_returns_same_instance_every_call",
			function()
				test_get_disturbance_band_crossed_signal_returns_same_instance_every_call()
			end
		)

		local function test_zero_subscribers_pass_does_not_error()
			local service = FakeDisturbanceService.new()
			service:KnitInit()
			service:_setSquadT(0.20)

			local ok = pcall(function()
				service:_runBandCrossedPass()
			end)

			expect(ok).to.equal(true)
		end
		it("test_zero_subscribers_pass_does_not_error", function()
			test_zero_subscribers_pass_does_not_error()
		end)

		local function test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local subA = MockPlayerController.new()
			local subB = MockPlayerController.new()
			local subC = MockPlayerController.new()

			subC:KnitStart(service)
			subA:KnitStart(service)
			subB:KnitStart(service)

			-- First pass (session-first-pass, H.28d(d)): establishes the Calm baseline, zero fires.
			service:_setSquadT(0.20)
			service:_runBandCrossedPass()

			-- Second pass: crosses Tense -- all three subscribers receive exactly one fire.
			service:_setSquadT(0.40)
			service:_setNow(50.0)
			service:_runBandCrossedPass()

			expect(subA.receivedCount).to.equal(1)
			expect(subB.receivedCount).to.equal(1)
			expect(subC.receivedCount).to.equal(1)
			expect(subA:lastEvent().direction).to.equal("up")
			expect(subB:lastEvent().direction).to.equal("up")
			expect(subC:lastEvent().direction).to.equal("up")
			expect(subA:lastEvent().newTier).to.equal("Tense")
		end
		it(
			"test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once",
			function()
				test_shuffled_connection_order_all_subscribers_receive_fire_exactly_once()
			end
		)
	end)

	-- ============================================================================
	-- AC-H.28d(a): exactly one fire per pass per squad-tier TRANSITION, timestamp from
	-- workspace:GetServerTimeNow() (faked here via _setNow), zero fires when tier unchanged.
	-- ============================================================================
	describe("DisturbanceService (Fake) -- Story 009 AC-H.28d(a) (one fire per transition, correct timestamp, zero on no-change)", function()
		local function test_h28d_a_squad_t_calm_to_tense_fires_once_with_correct_timestamp()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local subscriber = MockPlayerController.new()
			subscriber:KnitStart(service)

			-- Session-first-pass: squadT already Calm-range -- zero fires regardless (H.28d(d)
			-- structurally applies here too, though this pass also happens to classify no crossing
			-- at all since Calm == Calm).
			service:_setSquadT(0.20)
			service:_setNow(10.0)
			service:_runBandCrossedPass()
			expect(subscriber.receivedCount).to.equal(0)

			-- Second pass: squadT rises to Tense-range -- exactly one fire.
			service:_setSquadT(0.40)
			service:_setNow(100.5)
			service:_runBandCrossedPass()

			expect(subscriber.receivedCount).to.equal(1)
			local event = subscriber:lastEvent()
			expect(event.direction).to.equal("up")
			expect(event.newTier).to.equal("Tense")
			expect(event.timestamp).to.equal(100.5)
		end
		it(
			"test_h28d_a_squad_t_calm_to_tense_fires_once_with_correct_timestamp",
			function()
				test_h28d_a_squad_t_calm_to_tense_fires_once_with_correct_timestamp()
			end
		)

		-- Edge case (explicit in the QA text): two consecutive passes with no tier change between
		-- them -- zero fires on the second pass.
		local function test_h28d_a_edge_case_no_tier_change_between_passes_zero_fires_on_second_pass()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local subscriber = MockPlayerController.new()
			subscriber:KnitStart(service)

			service:_setSquadT(0.20)
			service:_runBandCrossedPass() -- first pass, suppressed
			service:_setSquadT(0.40)
			service:_runBandCrossedPass() -- crosses to Tense, 1 fire
			expect(subscriber.receivedCount).to.equal(1)

			service:_setSquadT(0.40) -- unchanged
			service:_runBandCrossedPass()
			expect(subscriber.receivedCount).to.equal(1) -- unchanged -- no spurious refire
		end
		it(
			"test_h28d_a_edge_case_no_tier_change_between_passes_zero_fires_on_second_pass",
			function()
				test_h28d_a_edge_case_no_tier_change_between_passes_zero_fires_on_second_pass()
			end
		)
	end)

	-- ============================================================================
	-- AC-H.28d(b): hysteresis-band oscillation (0.30, then 0.285, back to 0.30) fires no event
	-- across the oscillation.
	-- ============================================================================
	describe("DisturbanceService (Fake) -- Story 009 AC-H.28d(b) (hysteresis-band oscillation suppresses)", function()
		local function test_h28d_b_hysteresis_band_oscillation_fires_no_event()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local subscriber = MockPlayerController.new()
			subscriber:KnitStart(service)

			-- Session-first-pass: establish Calm baseline.
			service:_setSquadT(0.20)
			service:_runBandCrossedPass()
			expect(subscriber.receivedCount).to.equal(0)

			-- Crosses into Tense.
			service:_setSquadT(0.30)
			service:_runBandCrossedPass()
			expect(subscriber.receivedCount).to.equal(1)

			-- Oscillates within the hysteresis band: 0.285 stays Tense (0.285 >= 0.30 - 0.03 =
			-- 0.27) -- no fire.
			service:_setSquadT(0.285)
			service:_runBandCrossedPass()
			expect(subscriber.receivedCount).to.equal(1)

			-- Back to 0.30 -- still Tense, still no fire.
			service:_setSquadT(0.30)
			service:_runBandCrossedPass()
			expect(subscriber.receivedCount).to.equal(1)
		end
		it(
			"test_h28d_b_hysteresis_band_oscillation_fires_no_event",
			function()
				test_h28d_b_hysteresis_band_oscillation_fires_no_event()
			end
		)
	end)

	-- ============================================================================
	-- AC-H.28d(c): the signal has no .Client surface, never client-reachable. Verified via
	-- STATIC/structural source-text checks against the real DisturbanceService.luau (matches
	-- tier-classification-hysteresis-tiercrossedevent_test.luau's own "wiring, static checks"
	-- precedent -- see that file for the stripLuaComments `--`-in-string caveat this helper
	-- inherits).
	-- ============================================================================
	describe("DisturbanceService.luau -- Story 009 AC-H.28d(c) (wiring, static Client-surface checks)", function()
		local disturbanceServiceSource: string? = nil

		-- Strips Lua/Luau single-line comments. CAVEAT (per this project's own documented
		-- footgun): a `--` inside a string literal truncates early at the FIRST `--`-like
		-- sequence on that line -- this helper is only safe against code-STRUCTURE checks (does
		-- this line contain `Instance.new(`, `.Client.`, etc.), never against comment-only text.
		-- This is why every message this test file itself writes uses `:`/`|` instead of `--`.
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function loadServiceSource(): string
			if not disturbanceServiceSource then
				disturbanceServiceSource = stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceService.luau"))
			end
			return disturbanceServiceSource :: string
		end

		local function test_client_table_remains_empty_no_band_crossed_methods_exposed_to_clients()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it(
			"test_client_table_remains_empty_no_band_crossed_methods_exposed_to_clients",
			function()
				test_client_table_remains_empty_no_band_crossed_methods_exposed_to_clients()
			end
		)

		--- Every line mentioning "BandCrossed" (the signal's own state/accessor/method names) must
		--- never ALSO mention a RemoteEvent/RemoteFunction construction, a client-fire call, or a
		--- `.Client` surface reference -- confirms the signal is server-internal end-to-end, not
		--- merely that the top-level Client table happens to stay empty elsewhere in the file.
		local function test_no_band_crossed_line_references_remote_or_client_surface()
			local source = loadServiceSource()
			local violatingLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				if line:find("BandCrossed") then
					if
						line:find("RemoteEvent")
						or line:find("RemoteFunction")
						or line:find("%.Client")
						or line:find(":FireClient%(")
					then
						table.insert(violatingLines, line)
					end
				end
			end
			expect(#violatingLines).to.equal(0)
		end
		it(
			"test_no_band_crossed_line_references_remote_or_client_surface",
			function()
				test_no_band_crossed_line_references_remote_or_client_surface()
			end
		)

		local function test_disturbance_band_crossed_signal_constructed_via_signal_new_not_remote_event()
			local source = loadServiceSource()
			expect(source:find("_disturbanceBandCrossedSignal = Signal%.new%(%)")).never.to.equal(nil)
		end
		it(
			"test_disturbance_band_crossed_signal_constructed_via_signal_new_not_remote_event",
			function()
				test_disturbance_band_crossed_signal_constructed_via_signal_new_not_remote_event()
			end
		)

		local function test_get_disturbance_band_crossed_signal_accessor_exists_and_returns_the_real_field()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:GetDisturbanceBandCrossedSignal%(%)")).never.to.equal(nil)
			expect(source:find("return self%._disturbanceBandCrossedSignal")).never.to.equal(nil)
		end
		it(
			"test_get_disturbance_band_crossed_signal_accessor_exists_and_returns_the_real_field",
			function()
				test_get_disturbance_band_crossed_signal_accessor_exists_and_returns_the_real_field()
			end
		)
	end)

	-- ============================================================================
	-- AC-H.28d(d): squadT ALREADY above the Tense threshold BEFORE the very first field-update
	-- pass runs -- zero fires on that first pass; previousSquadTier initialises via
	-- flat-threshold dispatch (verified structurally, not just by absence-of-fire, via a
	-- differentiating second pass -- see comment below).
	-- ============================================================================
	describe("DisturbanceService (Fake) -- Story 009 AC-H.28d(d) (hot-join above threshold: zero fires on first pass, flat-dispatch verified)", function()
		local function test_h28d_d_squad_t_already_hunt_range_before_first_pass_zero_fires()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local subscriber = MockPlayerController.new()
			subscriber:KnitStart(service)

			-- Session's very first pass: squadT is ALREADY in Hunt-range (0.85 >= 0.65) before any
			-- classification has ever happened this session.
			service:_setSquadT(0.85)
			service:_runBandCrossedPass()

			expect(subscriber.receivedCount).to.equal(0)
		end
		it(
			"test_h28d_d_squad_t_already_hunt_range_before_first_pass_zero_fires",
			function()
				test_h28d_d_squad_t_already_hunt_range_before_first_pass_zero_fires()
			end
		)

		-- Differentiating check: if the first pass had (incorrectly) climbed the ladder
		-- one-boundary-at-a-time from "Calm" (Calm->Tense->Hunt, mirroring an UNGUARDED cascade
		-- rather than TR-ed-070's flat-threshold dispatch), OR if previousSquadTier had been left
		-- as "Calm" instead of being updated to "Hunt" despite the suppressed fire, a SECOND pass
		-- at a mid-range value would misclassify. This test proves previousSquadTier settled to
		-- the CORRECT flat-dispatched "Hunt" (not "Calm", not "Tense") after the suppressed first
		-- pass: a second pass at t=0.50 (below Hunt's downward-hysteresis floor of 0.62, but above
		-- Tense's) must classify as exactly one "down" transition to "Tense" -- which only happens
		-- if the state machine's remembered previous tier was genuinely "Hunt".
		local function test_h28d_d_previous_squad_tier_settles_to_flat_dispatched_hunt_not_calm_or_tense()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local subscriber = MockPlayerController.new()
			subscriber:KnitStart(service)

			service:_setSquadT(0.85)
			service:_runBandCrossedPass()
			expect(subscriber.receivedCount).to.equal(0)

			service:_setSquadT(0.50)
			service:_setNow(200.0)
			service:_runBandCrossedPass()

			expect(subscriber.receivedCount).to.equal(1)
			local event = subscriber:lastEvent()
			expect(event.direction).to.equal("down")
			expect(event.newTier).to.equal("Tense")
			expect(event.timestamp).to.equal(200.0)
		end
		it(
			"test_h28d_d_previous_squad_tier_settles_to_flat_dispatched_hunt_not_calm_or_tense",
			function()
				test_h28d_d_previous_squad_tier_settles_to_flat_dispatched_hunt_not_calm_or_tense()
			end
		)
	end)

	-- ============================================================================
	-- AC-H.28d(e): squadT at Retreat-range (1.0), then drops to Calm-range (0.20) between passes
	-- -- previousSquadTier converges Retreat->Hunt->Tense->Calm within <=4 settle iterations, and
	-- exactly THREE fires occur in ladder order, each direction="down". Edge case: verify the
	-- cascade does NOT fire a single "Retreat->Calm" skip-level event instead.
	-- ============================================================================
	describe("DisturbanceService (Fake) -- Story 009 AC-H.28d(e) (post-hitch multi-tier cascade: 3 discrete down-fires, ladder order)", function()
		local function test_h28d_e_retreat_to_calm_fires_three_discrete_down_events_in_ladder_order()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local subscriber = MockPlayerController.new()
			subscriber:KnitStart(service)

			-- Session-first-pass: establish Retreat baseline (flat-dispatch: t=1.0 >= 1.0 ->
			-- "Retreat" directly). Suppressed fire, per H.28d(d).
			service:_setSquadT(1.0)
			service:_runBandCrossedPass()
			expect(subscriber.receivedCount).to.equal(0)

			-- Between passes, squadT drops all the way to Calm-range.
			service:_setSquadT(0.20)
			service:_setNow(300.0)
			service:_runBandCrossedPass()

			expect(subscriber.receivedCount).to.equal(3)

			local first = subscriber.receivedEvents[1]
			local second = subscriber.receivedEvents[2]
			local third = subscriber.receivedEvents[3]

			-- Ladder order: Retreat->Hunt, Hunt->Tense, Tense->Calm -- never a single skip-level
			-- "Retreat->Calm" event.
			expect(first.newTier).to.equal("Hunt")
			expect(second.newTier).to.equal("Tense")
			expect(third.newTier).to.equal("Calm")

			expect(first.direction).to.equal("down")
			expect(second.direction).to.equal("down")
			expect(third.direction).to.equal("down")

			expect(first.timestamp).to.equal(300.0)
			expect(second.timestamp).to.equal(300.0)
			expect(third.timestamp).to.equal(300.0)
		end
		it(
			"test_h28d_e_retreat_to_calm_fires_three_discrete_down_events_in_ladder_order",
			function()
				test_h28d_e_retreat_to_calm_fires_three_discrete_down_events_in_ladder_order()
			end
		)
	end)

	-- ============================================================================
	-- Code-review follow-up (ed-9 review, 2026-07-08): DisturbanceServiceBandCrossedLogic's own
	-- orchestration correctness (DirectionFor, first-pass suppression, zero-crossings suppression,
	-- event-list construction) was previously entirely coupled to the REAL
	-- TierClassificationLogic.ClassifyWithCascade's actual cascade behavior -- every test above
	-- injects the real function. This decouples the two: DirectionFor is tested standalone across
	-- all relevant tier-pair orderings, and ClassifySquadBandCrossing is tested against a STUBBED
	-- classifyWithCascadeFn whose return value is fully controlled by the test, proving this
	-- module's OWN logic (not Story 006's) independently.
	-- ============================================================================
	describe("DisturbanceServiceBandCrossedLogic -- Story 009 (DirectionFor, standalone)", function()
		local function test_direction_for_reports_up_across_every_increasing_severity_pair()
			expect(BandCrossedLogic.DirectionFor("Calm", "Tense")).to.equal("up")
			expect(BandCrossedLogic.DirectionFor("Calm", "Hunt")).to.equal("up")
			expect(BandCrossedLogic.DirectionFor("Calm", "Retreat")).to.equal("up")
			expect(BandCrossedLogic.DirectionFor("Tense", "Hunt")).to.equal("up")
			expect(BandCrossedLogic.DirectionFor("Tense", "Retreat")).to.equal("up")
			expect(BandCrossedLogic.DirectionFor("Hunt", "Retreat")).to.equal("up")
		end
		it(
			"test_direction_for_reports_up_across_every_increasing_severity_pair",
			function()
				test_direction_for_reports_up_across_every_increasing_severity_pair()
			end
		)

		local function test_direction_for_reports_down_across_every_decreasing_severity_pair()
			expect(BandCrossedLogic.DirectionFor("Retreat", "Hunt")).to.equal("down")
			expect(BandCrossedLogic.DirectionFor("Retreat", "Tense")).to.equal("down")
			expect(BandCrossedLogic.DirectionFor("Retreat", "Calm")).to.equal("down")
			expect(BandCrossedLogic.DirectionFor("Hunt", "Tense")).to.equal("down")
			expect(BandCrossedLogic.DirectionFor("Hunt", "Calm")).to.equal("down")
			expect(BandCrossedLogic.DirectionFor("Tense", "Calm")).to.equal("down")
		end
		it(
			"test_direction_for_reports_down_across_every_decreasing_severity_pair",
			function()
				test_direction_for_reports_down_across_every_decreasing_severity_pair()
			end
		)
	end)

	describe(
		"DisturbanceServiceBandCrossedLogic -- Story 009 (ClassifySquadBandCrossing orchestration, stubbed cascade)",
		function()
			-- Builds a stubbed classifyWithCascadeFn returning a fixed (finalTier, crossedTiers)
			-- pair regardless of its actual (t, previousTier, ...) arguments -- isolates this
			-- module's OWN event-building/suppression logic from Story 006's real cascade math.
			local function stubClassifyWithCascadeFn(
				finalTier: Tier,
				crossedTiers: { Tier }
			): BandCrossedLogic.ClassifyWithCascadeFn
				return function(_t, _previousTier, _tense, _hunt, _hysteresis, _maxIterations)
					return finalTier, crossedTiers
				end
			end

			local function test_first_pass_suppresses_events_even_when_stub_reports_crossings()
				local finalTier, events = BandCrossedLogic.ClassifySquadBandCrossing(
					0.85,
					nil, -- first pass
					stubClassifyWithCascadeFn("Hunt", { "Tense", "Hunt" }), -- stub reports crossings anyway
					TENSE_THRESHOLD,
					HUNT_THRESHOLD,
					HYSTERESIS_BAND,
					MAX_TIER_CASCADE_ITERATIONS
				)
				expect(finalTier).to.equal("Hunt") -- caller must still persist this
				expect(#events).to.equal(0) -- but zero events fire, regardless of what the stub reports
			end
			it(
				"test_first_pass_suppresses_events_even_when_stub_reports_crossings",
				function()
					test_first_pass_suppresses_events_even_when_stub_reports_crossings()
				end
			)

			local function test_zero_crossed_tiers_from_stub_produces_zero_events_on_a_later_pass()
				local finalTier, events = BandCrossedLogic.ClassifySquadBandCrossing(
					0.40,
					"Tense", -- not first pass
					stubClassifyWithCascadeFn("Tense", {}), -- stub reports no crossings
					TENSE_THRESHOLD,
					HUNT_THRESHOLD,
					HYSTERESIS_BAND,
					MAX_TIER_CASCADE_ITERATIONS
				)
				expect(finalTier).to.equal("Tense")
				expect(#events).to.equal(0)
			end
			it(
				"test_zero_crossed_tiers_from_stub_produces_zero_events_on_a_later_pass",
				function()
					test_zero_crossed_tiers_from_stub_produces_zero_events_on_a_later_pass()
				end
			)

			local function test_stubbed_multi_crossing_builds_correct_event_list_and_shared_direction()
				local finalTier, events = BandCrossedLogic.ClassifySquadBandCrossing(
					0.20,
					"Retreat", -- not first pass
					stubClassifyWithCascadeFn("Calm", { "Hunt", "Tense", "Calm" }), -- stub-controlled cascade
					TENSE_THRESHOLD,
					HUNT_THRESHOLD,
					HYSTERESIS_BAND,
					MAX_TIER_CASCADE_ITERATIONS
				)
				expect(finalTier).to.equal("Calm")
				expect(#events).to.equal(3)
				expect(events[1].newTier).to.equal("Hunt")
				expect(events[2].newTier).to.equal("Tense")
				expect(events[3].newTier).to.equal("Calm")
				-- All three share ONE direction, derived from start ("Retreat") vs. end ("Calm"), not
				-- recomputed per crossed-tier step -- this is the module's own orchestration logic,
				-- not the stub's, and would be identical regardless of what the stub's
				-- crossedTiers list actually contains.
				expect(events[1].direction).to.equal("down")
				expect(events[2].direction).to.equal("down")
				expect(events[3].direction).to.equal("down")
			end
			it(
				"test_stubbed_multi_crossing_builds_correct_event_list_and_shared_direction",
				function()
					test_stubbed_multi_crossing_builds_correct_event_list_and_shared_direction()
				end
			)

			local function test_stubbed_single_upward_crossing_reports_up_direction()
				local finalTier, events = BandCrossedLogic.ClassifySquadBandCrossing(
					0.35,
					"Calm", -- not first pass
					stubClassifyWithCascadeFn("Tense", { "Tense" }),
					TENSE_THRESHOLD,
					HUNT_THRESHOLD,
					HYSTERESIS_BAND,
					MAX_TIER_CASCADE_ITERATIONS
				)
				expect(finalTier).to.equal("Tense")
				expect(#events).to.equal(1)
				expect(events[1].newTier).to.equal("Tense")
				expect(events[1].direction).to.equal("up")
			end
			it(
				"test_stubbed_single_upward_crossing_reports_up_direction",
				function()
					test_stubbed_single_upward_crossing_reports_up_direction()
				end
			)
		end
	)
end
