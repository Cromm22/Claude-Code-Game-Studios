--!strict
-- run_end_condition_raised_test
--
-- Unit tests for Story 001: RunController Core Aggregator -- RunEndConditionRaised,
-- Idempotency Latch, and defeatReason Payload Support.
-- Story: production/epics/runcontroller/story-001-core-aggregator.md
-- ADR: docs/architecture/adr-0002-runcontroller-architecture.md
--
-- Production code under test:
--   src/gameplay/services/RunControllerLogic.luau (pure idempotency-latch predicate +
--     RunEndedPayload constructor -- behavioral tests, first describe() block)
--   src/gameplay/services/RunController.luau (static/structural source checks only for the
--     .Client-exposure ban, os.time() sourcing, and the no-Knit.GetService AC -- second
--     describe() block)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate). This file mixes true behavioral tests (against the Knit-free
-- RunControllerLogic module) with static/structural source-text checks (against the actual
-- RunController.luau file text), exactly matching the precedent established by
-- tests/unit/ecological-disturbance/emission-schema-server-emit-intake_test.luau's own second
-- describe() block: RunController.luau cannot be instantiated under this harness (Knit and
-- Signal are not yet vendored under ReplicatedStorage.Packages), so a live
-- RunController:RunEndConditionRaised() call is not currently possible in an automated test --
-- the .Client-exposure ban, os.time() sourcing, and no-Knit.GetService ACs are instead proven
-- via source-text checks against the real file.
--
-- The first describe() block also uses a small in-test harness (simulateRunEndConditionRaised)
-- that composes RunControllerLogic.ShouldFire + RunControllerLogic.BuildPayload in EXACTLY the
-- same order RunController.luau's own RunEndConditionRaised method does (see that file's body).
-- This is necessary to exercise the idempotency-latch + "which call's exitReason wins" behavior
-- end-to-end without a live Signal to fire against -- the harness intentionally mirrors the
-- production composition rather than reimplementing separate logic, so a divergence between the
-- two would need to be introduced at the RunController.luau call site itself, which the second
-- describe() block's static checks partially guard against (e.g. confirming the post-latch
-- branch never mutates self._hasEnded further, via the "no error(" file-wide check standing in
-- for -- there being no other branch in the file that could touch it).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local RunControllerLogic = require(ServerScriptService.gameplay.services.RunControllerLogic)

type ConditionType = RunControllerLogic.ConditionType
type DefeatReason = RunControllerLogic.DefeatReason
type SquadStateSnapshot = RunControllerLogic.SquadStateSnapshot
type RunEndedPayload = RunControllerLogic.RunEndedPayload

-- ============================================================================
-- Test harness: mirrors RunController.luau's own RunEndConditionRaised composition.
-- ============================================================================

type FakeRunController = {
	hasEnded: boolean,
	firedPayloads: { RunEndedPayload },
}

local function newFakeController(): FakeRunController
	return { hasEnded = false, firedPayloads = {} }
end

--- Mirrors RunController.luau's RunEndConditionRaised body exactly:
--   if not ShouldFire(hasEnded) then warn(...); return end
--   hasEnded = true; payload = BuildPayload(...); runEnded:Fire(payload)
-- The production warn() call itself is not reproduced here (log side effects are out of this
-- pure harness's scope) -- only the control-flow and state-mutation shape is mirrored, which is
-- what AC-4/AC-5's "does not re-fire" / "exitReason matches the FIRST call" behavior depends on.
local function simulateRunEndConditionRaised(
	controller: FakeRunController,
	conditionType: ConditionType,
	squadState: SquadStateSnapshot,
	now: number,
	defeatReason: DefeatReason?
): ()
	if not RunControllerLogic.ShouldFire(controller.hasEnded) then
		return
	end
	controller.hasEnded = true
	local payload = RunControllerLogic.BuildPayload(conditionType, squadState, now, defeatReason)
	table.insert(controller.firedPayloads, payload)
end

return function()
	describe("RunControllerLogic -- Story 001 (idempotency latch predicate, RunEndedPayload construction)", function()
		-- ====================================================================
		-- AC-2 -- first call sets latch and fires with correct payload.
		-- ====================================================================
		local function test_first_call_fires_once_with_correct_payload_shape()
			local controller = newFakeController()
			local squadState: SquadStateSnapshot = { aliveCount = 0, totalCount = 4 }

			simulateRunEndConditionRaised(controller, "wipe", squadState, 1000)

			expect(controller.hasEnded).to.equal(true)
			expect(#controller.firedPayloads).to.equal(1)

			local payload = controller.firedPayloads[1]
			expect(payload.exitReason).to.equal("wipe")
			expect(payload.squadState).to.equal(squadState) -- opaque pass-through, same reference
			expect(payload.timestamp).to.equal(1000)
			expect(payload.defeatReason).to.equal(nil)
		end

		it("test_first_call_fires_once_with_correct_payload_shape", function()
			test_first_call_fires_once_with_correct_payload_shape()
		end)

		-- Edge case: squadState containing extra/unexpected fields passes through unmodified
		-- (opaque pass-through -- RunController never reads or validates squadState's fields).
		local function test_squad_state_with_extra_fields_passes_through_unmodified()
			local squadState: SquadStateSnapshot = {
				aliveCount = 2,
				totalCount = 4,
				unexpectedField = "some-future-PC-field",
				nestedTable = { a = 1, b = 2 },
			}

			local payload = RunControllerLogic.BuildPayload("victory", squadState, 500, nil)

			expect(payload.squadState).to.equal(squadState) -- byte-for-byte, same table reference
			expect((payload.squadState :: any).unexpectedField).to.equal("some-future-PC-field")
			expect((payload.squadState :: any).nestedTable).to.equal(squadState.nestedTable :: any)
		end

		it("test_squad_state_with_extra_fields_passes_through_unmodified", function()
			test_squad_state_with_extra_fields_passes_through_unmodified()
		end)

		-- ====================================================================
		-- AC-3 -- timestamp is an exact pass-through of the caller-injected `now` value
		-- (RunController.luau samples the real os.time() and passes it in; this module never
		-- calls a clock API itself -- see the static check in the second describe() block for
		-- confirmation that the real os.time() call site exists and GetServerTimeNow() does not).
		-- ====================================================================
		local function test_timestamp_is_exact_pass_through_of_injected_now()
			local FIXED_MOCK_TIME = 1751500000 -- arbitrary fixed Unix-epoch-like value

			local payload = RunControllerLogic.BuildPayload("wipe", { aliveCount = 1, totalCount = 4 }, FIXED_MOCK_TIME, nil)

			expect(payload.timestamp).to.equal(FIXED_MOCK_TIME)
		end

		it("test_timestamp_is_exact_pass_through_of_injected_now", function()
			test_timestamp_is_exact_pass_through_of_injected_now()
		end)

		-- ====================================================================
		-- AC-4 -- any call after the latch is set is a no-op: does not re-fire, does not
		-- mutate hasEnded further. Idempotent for arbitrarily many extra calls, not just one.
		-- ====================================================================
		local function test_calls_after_latch_are_silent_no_ops_idempotent_for_many_calls()
			local controller = newFakeController()
			local squadStateA: SquadStateSnapshot = { aliveCount = 0, totalCount = 4 }

			simulateRunEndConditionRaised(controller, "wipe", squadStateA, 100)
			expect(#controller.firedPayloads).to.equal(1)
			expect(controller.hasEnded).to.equal(true)

			-- Three further calls, arbitrary conditionType/squadState/defeatReason each time.
			simulateRunEndConditionRaised(controller, "victory", { aliveCount = 4, totalCount = 4 }, 200)
			simulateRunEndConditionRaised(controller, "wipe", { aliveCount = 0, totalCount = 4 }, 300, "scatter")
			simulateRunEndConditionRaised(controller, "victory", { aliveCount = 3, totalCount = 4 }, 400)

			-- Still exactly one fired payload -- the first one -- and hasEnded is still true
			-- (never mutated further).
			expect(#controller.firedPayloads).to.equal(1)
			expect(controller.hasEnded).to.equal(true)
			expect(controller.firedPayloads[1].exitReason).to.equal("wipe")
			expect(controller.firedPayloads[1].squadState).to.equal(squadStateA)
			expect(controller.firedPayloads[1].timestamp).to.equal(100)
		end

		it("test_calls_after_latch_are_silent_no_ops_idempotent_for_many_calls", function()
			test_calls_after_latch_are_silent_no_ops_idempotent_for_many_calls()
		end)

		-- ====================================================================
		-- AC-5 -- duplicate call with a DIFFERENT conditionType still results in exactly one
		-- RunEnded fire, with exitReason matching the FIRST call. Tested in BOTH directions
		-- per ADR-0002's own Validation Criteria, verbatim.
		-- ====================================================================
		local function test_wipe_then_victory_preserves_wipe_as_exit_reason()
			local controller = newFakeController()
			local squadStateA: SquadStateSnapshot = { aliveCount = 0, totalCount = 4 }
			local squadStateB: SquadStateSnapshot = { aliveCount = 4, totalCount = 4 }

			simulateRunEndConditionRaised(controller, "wipe", squadStateA, 111)
			simulateRunEndConditionRaised(controller, "victory", squadStateB, 222)

			expect(#controller.firedPayloads).to.equal(1)
			expect(controller.firedPayloads[1].exitReason).to.equal("wipe")
			expect(controller.firedPayloads[1].squadState).to.equal(squadStateA)
		end

		it("test_wipe_then_victory_preserves_wipe_as_exit_reason", function()
			test_wipe_then_victory_preserves_wipe_as_exit_reason()
		end)

		local function test_victory_then_wipe_preserves_victory_as_exit_reason()
			local controller = newFakeController()
			local squadStateA: SquadStateSnapshot = { aliveCount = 4, totalCount = 4 }
			local squadStateB: SquadStateSnapshot = { aliveCount = 0, totalCount = 4 }

			simulateRunEndConditionRaised(controller, "victory", squadStateA, 333)
			simulateRunEndConditionRaised(controller, "wipe", squadStateB, 444, "wipe")

			expect(#controller.firedPayloads).to.equal(1)
			expect(controller.firedPayloads[1].exitReason).to.equal("victory")
			expect(controller.firedPayloads[1].squadState).to.equal(squadStateA)
			expect(controller.firedPayloads[1].defeatReason).to.equal(nil) -- first call was victory, no defeatReason supplied
		end

		it("test_victory_then_wipe_preserves_victory_as_exit_reason", function()
			test_victory_then_wipe_preserves_victory_as_exit_reason()
		end)

		-- ====================================================================
		-- AC-6 -- defeatReason opaque pass-through, and nil-for-victory / nil-when-omitted.
		-- ====================================================================
		local function test_defeat_reason_scatter_passes_through_for_in_window_wipe()
			local payload = RunControllerLogic.BuildPayload("wipe", { aliveCount = 1, totalCount = 4 }, 555, "scatter")
			expect(payload.defeatReason).to.equal("scatter")
		end

		it("test_defeat_reason_scatter_passes_through_for_in_window_wipe", function()
			test_defeat_reason_scatter_passes_through_for_in_window_wipe()
		end)

		local function test_defeat_reason_is_nil_for_victory_even_if_never_supplied()
			local payload = RunControllerLogic.BuildPayload("victory", { aliveCount = 4, totalCount = 4 }, 666, nil)
			expect(payload.defeatReason).to.equal(nil)
		end

		it("test_defeat_reason_is_nil_for_victory_even_if_never_supplied", function()
			test_defeat_reason_is_nil_for_victory_even_if_never_supplied()
		end)

		-- Edge case: a pre-activation wipe with no defeatReason at all (no scatter concept)
		-- results in defeatReason == nil -- RunController must not default it to "wipe" or
		-- any other value.
		local function test_defeat_reason_is_nil_for_pre_activation_wipe_with_no_reason_supplied()
			local payload = RunControllerLogic.BuildPayload("wipe", { aliveCount = 0, totalCount = 4 }, 777, nil)
			expect(payload.defeatReason).to.equal(nil)
		end

		it("test_defeat_reason_is_nil_for_pre_activation_wipe_with_no_reason_supplied", function()
			test_defeat_reason_is_nil_for_pre_activation_wipe_with_no_reason_supplied()
		end)

		-- ====================================================================
		-- Edge case (found during code review): a first-ever call with squadState == nil
		-- is not prohibited by any AC (RunController never dereferences squadState's
		-- fields), but was previously untested. Confirms this doesn't error and passes
		-- nil through opaquely, same as every other opaque field.
		-- ====================================================================
		local function test_squad_state_nil_passes_through_without_error()
			local ok, payload = pcall(function()
				return RunControllerLogic.BuildPayload("wipe", nil :: any, 888, nil)
			end)
			expect(ok).to.equal(true)
			expect((payload :: RunEndedPayload).squadState).to.equal(nil)
		end
		it("test_squad_state_nil_passes_through_without_error", function()
			test_squad_state_nil_passes_through_without_error()
		end)
	end)

	describe("RunController.luau -- Story 001 static/structural source checks (.Client exposure, os.time() sourcing, no Knit.GetService)", function()
		-- These are STATIC checks against the actual .luau source text, not runtime behavioral
		-- tests -- see this file's header comment for why RunController.luau cannot yet be
		-- instantiated in this test harness (Knit and Signal are not vendored under
		-- ReplicatedStorage.Packages in this repo).
		local runControllerSource: string? = nil

		-- Strips Lua/Luau single-line comments (everything from `--` to end of line) from each
		-- line before the static checks below run, so doc-comment prose that legitimately quotes
		-- forbidden/required API names doesn't false-positive the checks. Matches the identical
		-- helper (and its documented `--`-in-string-literal caveat) already used by
		-- tests/unit/ecological-disturbance/emission-schema-server-emit-intake_test.luau and
		-- tests/unit/ecological-disturbance/spatial-grid-live-source-cap-eviction_test.luau.
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
		-- AC-1 -- RunEndConditionRaised exists as a plain server-internal Knit service
		-- method -- NEVER declared under RunController.Client anywhere in the module.
		-- ====================================================================
		local function test_client_table_remains_a_literal_empty_table()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("RunController%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it("test_client_table_remains_a_literal_empty_table", function()
			test_client_table_remains_a_literal_empty_table()
		end)

		local function test_run_end_condition_raised_declared_as_plain_colon_method()
			local source = loadServiceSource()
			expect(source:find("function RunController:RunEndConditionRaised%(")).never.to.equal(nil)
		end
		it("test_run_end_condition_raised_declared_as_plain_colon_method", function()
			test_run_end_condition_raised_declared_as_plain_colon_method()
		end)

		local function test_no_remote_or_bindable_wiring_present_in_source()
			local source = loadServiceSource()
			expect(source:find("RemoteEvent")).to.equal(nil)
			expect(source:find("RemoteFunction")).to.equal(nil)
			expect(source:find("OnServerEvent")).to.equal(nil)
			expect(source:find("OnServerInvoke")).to.equal(nil)
		end
		it("test_no_remote_or_bindable_wiring_present_in_source", function()
			test_no_remote_or_bindable_wiring_present_in_source()
		end)

		-- ====================================================================
		-- AC-3 -- timestamp is produced by os.time() -- never workspace:GetServerTimeNow().
		-- ====================================================================
		local function test_run_controller_calls_os_time()
			local source = loadServiceSource()
			expect(source:find("os%.time%(%)")).never.to.equal(nil)
		end
		it("test_run_controller_calls_os_time", function()
			test_run_controller_calls_os_time()
		end)

		local function test_run_controller_never_calls_get_server_time_now()
			local source = loadServiceSource()
			expect(source:find("GetServerTimeNow%(")).to.equal(nil)
		end
		it("test_run_controller_never_calls_get_server_time_now", function()
			test_run_controller_never_calls_get_server_time_now()
		end)

		-- ====================================================================
		-- AC-4 -- post-latch no-op logs at warn level, not error. RunController has no
		-- config-validation gates (unlike DisturbanceService/PlayerControllerService), so
		-- error() should never appear anywhere in this file.
		-- ====================================================================
		local function test_post_latch_path_uses_warn_not_error()
			local source = loadServiceSource()
			expect(source:find("warn%(")).never.to.equal(nil)
			expect(source:find("error%(")).to.equal(nil)
		end
		it("test_post_latch_path_uses_warn_not_error", function()
			test_post_latch_path_uses_warn_not_error()
		end)

		-- ====================================================================
		-- AC-4 (strengthened, found during code review): the prior check above only
		-- confirms warn( appears somewhere in the whole file, not that it's specifically
		-- inside the ShouldFire-false branch. This check isolates the text between the
		-- "if not ... ShouldFire(...) then" guard and its matching "return" and confirms
		-- warn( lives INSIDE that slice -- a future edit that moved warn() onto the
		-- success path (or duplicated it there) would fail this, where the whole-file
		-- substring check would not have caught it.
		-- ====================================================================
		local function test_warn_call_is_specifically_inside_the_should_fire_false_branch()
			local source = loadServiceSource()
			local branchStart = source:find("ShouldFire%(self%._hasEnded%)%s*then")
			expect(branchStart).never.to.equal(nil)
			local branchEnd = source:find("return", branchStart :: number)
			expect(branchEnd).never.to.equal(nil)
			local branchSlice = source:sub(branchStart :: number, branchEnd :: number)
			expect(branchSlice:find("warn%(")).never.to.equal(nil)
		end
		it(
			"test_warn_call_is_specifically_inside_the_should_fire_false_branch",
			function()
				test_warn_call_is_specifically_inside_the_should_fire_false_branch()
			end
		)

		-- ====================================================================
		-- AC-7 -- RunEndConditionRaised never calls back into the caller or any other
		-- service -- no Knit.GetService(...) call appears anywhere in this file.
		-- ====================================================================
		local function test_no_knit_get_service_call_anywhere_in_file()
			local source = loadServiceSource()
			expect(source:find("Knit%.GetService")).to.equal(nil)
		end
		it("test_no_knit_get_service_call_anywhere_in_file", function()
			test_no_knit_get_service_call_anywhere_in_file()
		end)

		-- ====================================================================
		-- Bonus structural sanity checks matching this story's own Implementation Notes:
		-- Signal.new() (not Instance.new("BindableEvent")) backs the outbound channel.
		-- ====================================================================
		local function test_uses_signal_new_not_bindable_event()
			local source = loadServiceSource()
			expect(source:find("Signal%.new%(%)")).never.to.equal(nil)
			expect(source:find('Instance%.new%("BindableEvent"%)')).to.equal(nil)
		end
		it("test_uses_signal_new_not_bindable_event", function()
			test_uses_signal_new_not_bindable_event()
		end)
	end)
end
