--!strict
-- sprint-stamina-authority_test
--
-- TestEZ unit tests for Story 001: Locomotion & Sprint-State Authority
-- (S1/S2) + Stamina + Ghost-Sprint Guard.
-- Story: production/epics/player-controller/story-001-locomotion-sprint-stamina-authority.md
-- Production code under test: src/gameplay/services/PlayerControllerLocomotionStaminaLogic.luau
--
-- These tests require PlayerControllerLocomotionStaminaLogic directly -- NOT
-- PlayerControllerService (the Knit wrapper) -- because that module is
-- dependency-free (no Knit, no Roblox service calls) and therefore portable
-- to Lune without a vendored Knit package or a Rojo-synced DataModel. The
-- Knit-wrapper service delegates to these exact functions with no additional
-- branching beyond Player-identity bookkeeping, Humanoid.WalkSpeed side
-- effects, and the ADR-0006 step-1/3/5 plumbing (alive-guard stub, global
-- budget bookkeeping shared with the lantern axis, the intentional step-5
-- no-op) -- so coverage here is representative of the production service's
-- actual decision logic. A live-Studio/TestService smoke pass is still
-- recommended to confirm the Knit wiring itself once Rojo sync is live --
-- this mirrors the same Lemur/Lune-fidelity caveat already documented in
-- Story 002's own test file for instance-lifecycle-dependent paths. Named
-- explicitly (found during code review -- prior drafts of this note only
-- generically bucketed these, which under-disclosed the gap):
--   - Client signal connections (RequestSprintToggle, PlayerHeartbeat)
--   - The RunService.Heartbeat stamina-tick connection itself
--   - PlayerAdded/PlayerRemoving lifecycle wiring
--   - Humanoid.WalkSpeed assignment at spawn/transition time
--   - OnSprintStateChanged:FireAll(...) broadcast (fires on every real transition)
--   - OnStaminaChanged:Fire(player, ...) rate-limited single-client push
--   - CROSS-EVENT BUDGET INTERACTION: self._globalEventCounts is shared across
--     Lantern/Sprint/Heartbeat requests (the entire point of ADR-0006's shared
--     per-player budget), but no test anywhere in this repo proves consuming
--     the budget via one event actually starves another -- this can only be
--     tested once the Knit wrapper is instantiable, tracked as a live-Studio
--     smoke-test follow-up, not silently assumed correct.
--
-- Floating-point tolerance handling (per the story's own instruction, option
-- (a) chosen -- see the implementation session, 2026-07-06/07): every
-- formula-based assertion below computes its expected value using the
-- module's own public constants in the IDENTICAL arithmetic order the
-- production code uses (e.g. `math.clamp(100 - Logic.STAMINA_DRAIN_RATE *
-- 0.01667, 0, Logic.STAMINA_MAX)`), giving bit-exact equality under Luau's
-- deterministic floating-point arithmetic rather than needing a tolerance-
-- aware matcher at all. `tests/run_tests.lua`'s shared `expect()` mock is
-- NOT extended by this story -- no genuine gap was found (unlike the
-- `stripLuaComments` fix or the `.never` matcher addition, both cited in the
-- harness's own history).
local ServerScriptService = game:GetService("ServerScriptService")
local Logic = require(ServerScriptService.gameplay.services.PlayerControllerLocomotionStaminaLogic)

type PlayerLocomotionState = Logic.PlayerLocomotionState
type TumblingWindow = Logic.TumblingWindow

return function()
	describe("PlayerControllerLocomotionStaminaLogic -- Story 001 (locomotion S1/S2, stamina, ghost-sprint guard)", function()
		-- ====================================================================
		-- H.1 -- GetMoveSpeed returns the correct constants; errors on an
		-- unrecognized state rather than silently returning a stale value.
		-- ====================================================================
		local function test_H1_get_move_speed_returns_walk_and_sprint_constants_and_errors_on_unrecognized()
			expect(Logic.GetMoveSpeed("S1")).to.equal(12)
			expect(Logic.GetMoveSpeed("S2")).to.equal(20)
			expect(Logic.GetMoveSpeed("S1")).to.equal(Logic.WALK_SPEED)
			expect(Logic.GetMoveSpeed("S2")).to.equal(Logic.SPRINT_SPEED)

			local ok = pcall(function()
				return Logic.GetMoveSpeed("bogus-state")
			end)
			expect(ok).to.equal(false)
		end

		it("test_H1_get_move_speed_returns_walk_and_sprint_constants_and_errors_on_unrecognized", function()
			test_H1_get_move_speed_returns_walk_and_sprint_constants_and_errors_on_unrecognized()
		end)

		-- ====================================================================
		-- H.2 -- XZ displacement (Logic gate; the full Lemur/Lune headless-
		-- server Humanoid-physics simulation is infra this project doesn't
		-- have yet -- no default.project.json/live DataModel -- so this
		-- proves the displacement FORMULA, not a live physics run. PC
		-- manual-playtest confirmation is ADVISORY per the story, not
		-- automated here.
		-- ====================================================================
		local function test_H2_xz_displacement_matches_walk_speed_times_duration_within_tolerance()
			local displacement = Logic.ComputeXZDisplacement(Logic.GetMoveSpeed("S1"), 3)
			local expected = Logic.WALK_SPEED * 3
			local withinTolerance = math.abs(displacement - expected) <= 0.5
			expect(withinTolerance).to.equal(true)
		end

		it("test_H2_xz_displacement_matches_walk_speed_times_duration_within_tolerance", function()
			test_H2_xz_displacement_matches_walk_speed_times_duration_within_tolerance()
		end)

		-- ====================================================================
		-- H.3 -- the sprint pulse-interval TIMER survives a jump physics
		-- event mid-sprint. No jump-event handler is wired anywhere in this
		-- codebase (Story 003 owns real pulse emission) -- this test proves
		-- the persistence MECHANISM: `sprintPulseAnchorAt` is set once at S1
		-- -> S2 entry and is never touched by the per-Heartbeat tick loop
		-- (the same loop that would still be running during any jump), so
		-- the next pulse boundary stays anchored regardless.
		-- ====================================================================
		local function test_H3_sprint_pulse_anchor_persists_across_ticks_including_a_simulated_jump_frame()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()

			local accepted = Logic.HandleSprintToggleDomain(state, true, 100.0) -- T1 at t=100
			expect(accepted).to.equal(true)
			expect(state.sprintPulseAnchorAt).to.equal(100.0)

			-- Five simulated Heartbeats at t=100.1, 100.2, ... 100.5 -- one of
			-- these stands in for "the frame a jump physics event fires".
			-- Since no jump handler exists anywhere in this service, nothing
			-- here COULD reset the anchor even if a real jump occurred on
			-- one of these frames -- the loop below exercises exactly the
			-- code path (TickStamina) that runs on every frame, jump or not.
			local now = 100.0
			for _ = 1, 5 do
				now += 0.1
				local forced = Logic.TickStamina(state, 0.1, now)
				expect(forced).to.equal(false) -- stamina is nowhere near exhausted
				expect(state.sprintPulseAnchorAt).to.equal(100.0) -- unchanged by ANY tick
			end

			local nextPulseBoundary = (state.sprintPulseAnchorAt :: number) + Logic.SPRINT_PULSE_INTERVAL
			expect(nextPulseBoundary).to.equal(102.0) -- 100.0 + 2.0s, unaffected by the 5 intervening ticks
		end

		it("test_H3_sprint_pulse_anchor_persists_across_ticks_including_a_simulated_jump_frame", function()
			test_H3_sprint_pulse_anchor_persists_across_ticks_including_a_simulated_jump_frame()
		end)

		-- ====================================================================
		-- H.4 -- stamina drain formula, bit-exact single tick.
		-- ====================================================================
		local function test_H4_stamina_drain_formula_bit_exact_single_tick()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S2"
			state.stamina = 100
			state.lastHeartbeatAt = 0 -- 0 elapsed at now=0 -- keeps the ghost-sprint guard from interfering

			local forced = Logic.TickStamina(state, 0.01667, 0)

			local expected = math.clamp(100 - Logic.STAMINA_DRAIN_RATE * 0.01667, 0, Logic.STAMINA_MAX)
			expect(forced).to.equal(false)
			expect(state.stamina).to.equal(expected) -- ~= 99.792, bit-exact vs. the identical expression
		end

		it("test_H4_stamina_drain_formula_bit_exact_single_tick", function()
			test_H4_stamina_drain_formula_bit_exact_single_tick()
		end)

		-- ====================================================================
		-- H.5 -- stamina regen formula, bit-exact single tick.
		-- ====================================================================
		local function test_H5_stamina_regen_formula_bit_exact_single_tick()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S1"
			state.stamina = 50
			state.lastLeftSprintAt = -10 -- well past STAMINA_REGEN_DELAY relative to now=0

			local forced = Logic.TickStamina(state, 0.01667, 0)

			local expected = math.clamp(50 + Logic.STAMINA_REGEN_RATE * 0.01667, 0, Logic.STAMINA_MAX)
			expect(forced).to.equal(false)
			expect(state.stamina).to.equal(expected) -- ~= 50.167, bit-exact vs. the identical expression
		end

		it("test_H5_stamina_regen_formula_bit_exact_single_tick", function()
			test_H5_stamina_regen_formula_bit_exact_single_tick()
		end)

		-- ====================================================================
		-- H.6 -- T_sprint(s_0) = s_0 / STAMINA_DRAIN_RATE.
		-- ====================================================================
		local function test_H6_T_sprint_formula()
			expect(Logic.T_sprint(50)).to.equal(4.0)
			expect(Logic.T_sprint(100)).to.equal(8.0)
			expect(Logic.T_sprint(25)).to.equal(2.0)
		end

		it("test_H6_T_sprint_formula", function()
			test_H6_T_sprint_formula()
		end)

		-- ====================================================================
		-- H.7 -- zero-stamina sprint-toggle rejection: no transition. (The
		-- "no OnSprintStateChanged broadcast" half of this AC is a static
		-- property of the Knit wrapper's own code path -- it only calls
		-- FireAll when `accepted == true`, which this test proves is false
		-- here -- not independently testable without a live Knit service.)
		-- ====================================================================
		local function test_H7_zero_stamina_sprint_toggle_rejected_no_transition()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S1"
			state.stamina = 0

			local accepted, reason = Logic.HandleSprintToggleDomain(state, true, 0)

			expect(accepted).to.equal(false)
			expect(reason).to.equal("no-stamina")
			expect(state.locomotion).to.equal("S1")

			-- Edge case (E.B, story QA notes): stamina = 0.4 (just above
			-- zero) MUST be honored -- this is correct, not a bug.
			local state2: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state2.locomotion = "S1"
			state2.stamina = 0.4
			local accepted2 = Logic.HandleSprintToggleDomain(state2, true, 0)
			expect(accepted2).to.equal(true)
			expect(state2.locomotion).to.equal("S2")
		end

		it("test_H7_zero_stamina_sprint_toggle_rejected_no_transition", function()
			test_H7_zero_stamina_sprint_toggle_rejected_no_transition()
		end)

		-- ====================================================================
		-- H.8 -- IsRegenActive strict `>` boundary, epsilon-based assertion.
		-- ====================================================================
		local function test_H8_regen_delay_strict_greater_than_boundary()
			local tEnd = 0
			local epsilon = 0.001

			expect(Logic.IsRegenActive(tEnd, tEnd + 1.4)).to.equal(false)
			expect(Logic.IsRegenActive(tEnd, tEnd + Logic.STAMINA_REGEN_DELAY)).to.equal(false) -- exactly 1.5s: still inside delay (strict >)
			expect(Logic.IsRegenActive(tEnd, tEnd + Logic.STAMINA_REGEN_DELAY + epsilon)).to.equal(true)
		end

		it("test_H8_regen_delay_strict_greater_than_boundary", function()
			test_H8_regen_delay_strict_greater_than_boundary()
		end)

		-- ====================================================================
		-- H.13 -- no ghost-hold across forced walk: a stale sprint=true
		-- re-assertion immediately after a forced T2 is NOT honored.
		-- ====================================================================
		local function test_H13_no_ghost_hold_across_forced_walk()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S2"
			state.stamina = 0.125 -- drains to exactly 0 in one 0.01s tick at STAMINA_DRAIN_RATE=12.5
			state.lastHeartbeatAt = 0 -- avoid the ghost-sprint guard firing instead

			local forced, reason = Logic.TickStamina(state, 0.01, 0)
			expect(forced).to.equal(true)
			expect(reason).to.equal("stamina-exhausted")
			expect(state.locomotion).to.equal("S1")
			expect(state.stamina).to.equal(0)

			-- A stale sprint=true re-assertion (the client still holding the
			-- key/touch-toggle, NOT a fresh press) immediately after T2, same
			-- tick's `now`: must NOT be honored -- stamina is still 0.
			local accepted, rejectReason = Logic.HandleSprintToggleDomain(state, true, 0)
			expect(accepted).to.equal(false)
			expect(rejectReason).to.equal("no-stamina")
			expect(state.locomotion).to.equal("S1")
		end

		it("test_H13_no_ghost_hold_across_forced_walk", function()
			test_H13_no_ghost_hold_across_forced_walk()
		end)

		-- ====================================================================
		-- H.26 -- DEFERRED. MANUAL-PLAYTEST acceptance criterion (PC + Gamepad
		-- testers on the same LIVE server, both exhausting stamina from
		-- s_0=50 and confirming a simultaneous S2->S1 transition within the
		-- same Heartbeat). This requires two real input devices and a live
		-- server session -- it cannot be automated under the Lune/TestEZ
		-- headless harness (no live server, no real input hardware). Per the
		-- story's own Test Evidence section, this is intentionally left
		-- DEFERRED rather than fabricated as an automated pass. This
		-- function exists only so the AC is not silently missing from this
		-- suite's coverage -- it makes no assertions.
		-- ====================================================================
		local function test_H26_multi_input_method_simultaneous_exhaustion_DEFERRED_manual_playtest()
			print(
				"H.26 DEFERRED -- MANUAL-PLAYTEST required (one PC/KB+M tester + one gamepad tester on the same live server, both sprinting from s_0=50 to simultaneous exhaustion). Not automatable under Lune/TestEZ -- no live server, no real input devices."
			)
		end

		it("test_H26_multi_input_method_simultaneous_exhaustion_DEFERRED_manual_playtest", function()
			test_H26_multi_input_method_simultaneous_exhaustion_DEFERRED_manual_playtest()
		end)

		-- ====================================================================
		-- H.33a -- ghost-sprint watchdog: stale PlayerHeartbeat (>3s) forces
		-- S2->S1 within one Heartbeat tick; a Wi-Fi-flap shorter than 3s
		-- (strict boundary) does NOT force-revert.
		-- ====================================================================
		local function test_H33a_ghost_sprint_watchdog_forces_revert_after_stale_heartbeat()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S2"
			state.stamina = 100 -- far from exhaustion -- isolates the ghost-timeout path
			state.lastHeartbeatAt = 0

			local forced, reason = Logic.TickStamina(state, 0.01667, Logic.SPRINT_CLIENT_TIMEOUT + 0.001)
			expect(forced).to.equal(true)
			expect(reason).to.equal("ghost-sprint-timeout")
			expect(state.locomotion).to.equal("S1")
			expect(state.lastHeartbeatAt).to.equal(nil) -- stops the sprint pulse timer / clears heartbeat state
			expect(state.sprintPulseAnchorAt).to.equal(nil)
			expect(state.lastLeftSprintAt).to.equal(Logic.SPRINT_CLIENT_TIMEOUT + 0.001) -- starts the regen-delay timer

			-- Wi-Fi-flap tolerance: exactly at the 3s boundary (strict >, not
			-- >=) must NOT force-revert.
			local stateAtBoundary: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			stateAtBoundary.locomotion = "S2"
			stateAtBoundary.stamina = 100
			stateAtBoundary.lastHeartbeatAt = 0
			local forcedAtBoundary = Logic.TickStamina(stateAtBoundary, 0.01667, Logic.SPRINT_CLIENT_TIMEOUT)
			expect(forcedAtBoundary).to.equal(false)
			expect(stateAtBoundary.locomotion).to.equal("S2")
		end

		it("test_H33a_ghost_sprint_watchdog_forces_revert_after_stale_heartbeat", function()
			test_H33a_ghost_sprint_watchdog_forces_revert_after_stale_heartbeat()
		end)

		-- ====================================================================
		-- H.33b -- heartbeat flood (10/s) rate-limited: excess dropped,
		-- `lastHeartbeatAt` updated by accepted events ONLY, sprint not
		-- extended by heartbeat traffic.
		-- ====================================================================
		local function test_H33b_heartbeat_flood_rate_limited_does_not_extend_sprint()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S2"

			local record: TumblingWindow = { count = 0, windowStart = 0 }

			-- 10 heartbeats flooded at 0.1s spacing across [0.0, 0.9] -- well
			-- above HEARTBEAT_SEND_RATE = 1Hz (cap 1 per 1.0s tumbling window).
			local timestamps = { 0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9 }
			local acceptedCount = 0
			for _, t in timestamps do
				if Logic.CheckHeartbeatRateLimit(record, t) then
					acceptedCount += 1
					Logic.HandlePlayerHeartbeatDomain(state, t)
				end
			end

			expect(acceptedCount).to.equal(1) -- only the first passes the 1Hz cap within this window
			expect(state.lastHeartbeatAt).to.equal(0.0) -- updated by the ONE accepted event only

			-- Sprint termination is unaffected by heartbeat traffic: stamina
			-- exhaustion still fires at its normal boundary regardless of how
			-- much (accepted or rejected) heartbeat traffic preceded it.
			state.stamina = 0.125
			local forced = Logic.TickStamina(state, 0.01, 0.9)
			expect(forced).to.equal(true)
			expect(state.locomotion).to.equal("S1")
		end

		it("test_H33b_heartbeat_flood_rate_limited_does_not_extend_sprint", function()
			test_H33b_heartbeat_flood_rate_limited_does_not_extend_sprint()
		end)

		-- ====================================================================
		-- H.33c -- a PlayerHeartbeat received while in S1 is silently
		-- dropped: no error, no timestamp update, no state transition.
		-- ====================================================================
		local function test_H33c_heartbeat_while_S1_silently_dropped()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S1"
			state.lastHeartbeatAt = nil

			local accepted = Logic.HandlePlayerHeartbeatDomain(state, 123.0)

			expect(accepted).to.equal(false)
			expect(state.lastHeartbeatAt).to.equal(nil)
			expect(state.locomotion).to.equal("S1")
		end

		it("test_H33c_heartbeat_while_S1_silently_dropped", function()
			test_H33c_heartbeat_while_S1_silently_dropped()
		end)

		-- ====================================================================
		-- H.82 -- negative-dt safety: the drain formula cannot refund
		-- stamina, and the regen formula cannot drain it, on a negative dt.
		-- ====================================================================
		local function test_H82_negative_dt_safety_drain_and_regen()
			local drainState: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			drainState.locomotion = "S2"
			drainState.stamina = 80
			drainState.lastHeartbeatAt = 0 -- 0 elapsed at now=0, avoids the ghost guard

			local forcedDrain = Logic.TickStamina(drainState, -0.05, 0)
			expect(forcedDrain).to.equal(false)
			expect(drainState.stamina).to.equal(80) -- exactly unchanged -- no refund

			local regenState: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			regenState.locomotion = "S1"
			regenState.stamina = 50
			regenState.lastLeftSprintAt = -10 -- regen-delay long expired relative to now=0

			local forcedRegen = Logic.TickStamina(regenState, -0.05, 0)
			expect(forcedRegen).to.equal(false)
			expect(regenState.stamina).to.equal(50) -- exactly unchanged -- no drain
		end

		it("test_H82_negative_dt_safety_drain_and_regen", function()
			test_H82_negative_dt_safety_drain_and_regen()
		end)

		-- ====================================================================
		-- Gaps found during code review (all four below): the original 14 tests covered
		-- every AC but left several real code paths in this module unexercised. None of
		-- these represent AC-level gaps (every story AC was already covered) -- they
		-- close coverage holes flagged by independent QA/engine review before this story
		-- is used as the reference pattern for later stories.
		-- ====================================================================

		-- HandleSprintToggleDomain's same-state debounce, TRUE direction: a
		-- sprint=true toggle while already in S2 must be dropped (no re-entry side
		-- effects), same discipline as PlayerControllerLanternLogic's own debounce.
		local function test_same_state_debounce_sprint_true_while_already_S2()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S2"
			state.sprintPulseAnchorAt = 50.0 -- sentinel: must NOT be touched by a debounced call

			local accepted, reason = Logic.HandleSprintToggleDomain(state, true, 100.0)

			expect(accepted).to.equal(false)
			expect(reason).to.equal("same-state-debounced")
			expect(state.locomotion).to.equal("S2")
			expect(state.sprintPulseAnchorAt).to.equal(50.0) -- unchanged -- no re-entry into _enterS2
		end
		it("test_same_state_debounce_sprint_true_while_already_S2", function()
			test_same_state_debounce_sprint_true_while_already_S2()
		end)

		-- HandleSprintToggleDomain's voluntary stop-sprint path (sprint=false), called
		-- DIRECTLY -- previously only exercised indirectly via the forced-revert path
		-- inside TickStamina, which is a different code path (_enterS1 called from
		-- TickStamina, not from this function). Always honored, no stamina gate.
		local function test_voluntary_stop_sprint_always_honored()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S2"
			state.stamina = 100 -- plenty of stamina -- proves stop-sprint has no stamina gate
			state.sprintPulseAnchorAt = 50.0
			state.lastHeartbeatAt = 50.0

			local accepted, reason = Logic.HandleSprintToggleDomain(state, false, 100.0)

			expect(accepted).to.equal(true)
			expect(reason).to.equal(nil)
			expect(state.locomotion).to.equal("S1")
			expect(state.lastLeftSprintAt).to.equal(100.0) -- starts the regen-delay timer
			expect(state.sprintPulseAnchorAt).to.equal(nil) -- pulse timer stopped
			expect(state.lastHeartbeatAt).to.equal(nil) -- T2 clearance
		end
		it("test_voluntary_stop_sprint_always_honored", function()
			test_voluntary_stop_sprint_always_honored()
		end)

		-- HandleSprintToggleDomain's same-state debounce, FALSE direction: a
		-- sprint=false toggle while already in S1 must be dropped.
		local function test_same_state_debounce_sprint_false_while_already_S1()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			state.locomotion = "S1"

			local accepted, reason = Logic.HandleSprintToggleDomain(state, false, 100.0)

			expect(accepted).to.equal(false)
			expect(reason).to.equal("same-state-debounced")
			expect(state.locomotion).to.equal("S1")
		end
		it("test_same_state_debounce_sprint_false_while_already_S1", function()
			test_same_state_debounce_sprint_false_while_already_S1()
		end)

		-- TickStamina's regen nil-safety: a fresh S1 player who has never sprinted
		-- (lastLeftSprintAt == nil, per NewPlayerLocomotionState's own default) must not
		-- error, and IsRegenActive(nil, now) must correctly return false rather than
		-- treating nil as "eligible since the beginning of time" (this module's own
		-- documented design decision for the nil case).
		local function test_tick_stamina_fresh_s1_player_never_sprinted_is_nil_safe()
			local state: PlayerLocomotionState = Logic.NewPlayerLocomotionState()
			expect(state.locomotion).to.equal("S1")
			expect(state.lastLeftSprintAt).to.equal(nil)
			expect(state.stamina).to.equal(Logic.STAMINA_MAX) -- already full -- regen is a no-op either way

			local ok, forced = pcall(function()
				return Logic.TickStamina(state, 0.01667, 0)
			end)

			expect(ok).to.equal(true)
			expect(forced).to.equal(false)
			expect(state.stamina).to.equal(Logic.STAMINA_MAX) -- clamped, unchanged
		end
		it(
			"test_tick_stamina_fresh_s1_player_never_sprinted_is_nil_safe",
			function()
				test_tick_stamina_fresh_s1_player_never_sprinted_is_nil_safe()
			end
		)

		-- CheckSprintToggleRateLimit (ADR-0006 step 2 for RequestSprintToggle: 10/s +
		-- 15-per-2.0s burst cap) -- previously completely untested, despite
		-- coding-standards.md's explicit "exploit-resistance for all RemoteEvents"
		-- requirement. Mirrors the existing H.33b heartbeat-rate-limit test's flood
		-- pattern, scaled to this event's own numbers.
		local function test_check_sprint_toggle_rate_limit_burst_cap()
			local record: Logic.SprintRateLimitRecord = {
				perSecond = { count = 0, windowStart = 0 },
				burst = { count = 0, windowStart = 0 },
			}

			-- 20 requests evenly spaced 0.1s apart across [0, 1.9]: lands 10 in each of
			-- two successive 1-second per-second sub-windows, so the 10/s cap is never
			-- individually the reason for a drop -- but the single 2.0s burst window
			-- (which never tumbles across this span) accumulates across both
			-- sub-windows and hits its cap of 15 at the 16th request.
			local acceptedCount = 0
			local now = 0
			for _ = 1, 20 do
				if Logic.CheckSprintToggleRateLimit(record, now) then
					acceptedCount += 1
				end
				now += 0.1
			end

			expect(acceptedCount).to.equal(Logic.SPRINT_TOGGLE_BURST_CAP) -- exactly 15 accepted
		end
		it("test_check_sprint_toggle_rate_limit_burst_cap", function()
			test_check_sprint_toggle_rate_limit_burst_cap()
		end)

		-- CheckSprintToggleRateLimit: a rejected request must not partially consume
		-- either window's budget (the "no state mutation on drop" rule this module's
		-- own header claims, previously unverified by any test).
		local function test_check_sprint_toggle_rate_limit_rejection_does_not_partially_consume()
			local record: Logic.SprintRateLimitRecord = {
				perSecond = { count = Logic.SPRINT_TOGGLE_RATE_LIMIT_PER_SEC, windowStart = 0 },
				burst = { count = 0, windowStart = 0 },
			}

			-- perSecond is already at cap (within the same 1.0s window) -- must reject,
			-- and burst.count must remain untouched by the rejected attempt.
			local accepted = Logic.CheckSprintToggleRateLimit(record, 0.5)

			expect(accepted).to.equal(false)
			expect(record.burst.count).to.equal(0)
		end
		it(
			"test_check_sprint_toggle_rate_limit_rejection_does_not_partially_consume",
			function()
				test_check_sprint_toggle_rate_limit_rejection_does_not_partially_consume()
			end
		)
	end)
end
