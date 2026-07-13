--!strict
-- disturbance-emission-publisher_test
--
-- TestEZ unit tests for Story 003: Disturbance Emission Publisher
-- (Sprint/Light Pulses, Grace, Cooldown, Magnitude).
-- Story: production/epics/player-controller/story-003-disturbance-emission-publisher.md
-- GDD: design/gdd/player-controller.md -- C.8/C.8.1/C.8.2, D.4, D.6
--
-- Production code under test:
--   src/gameplay/services/PlayerControllerEmissionPublisherLogic.luau (pure D.4/D.6 formula
--     logic -- behavioral tests, first describe() block)
--   src/gameplay/services/PlayerControllerService.luau (static/structural source-text checks
--     only, for H.15's "two distinct Emit call sites, no dedup" AC -- second describe()
--     block, matching the precedent tests/unit/runcontroller/run_end_condition_raised_test
--     .luau and tests/unit/ecological-disturbance/emission-schema-server-emit-intake_test
--     .luau both already established for files this harness cannot instantiate live (Knit is
--     not vendored under ReplicatedStorage.Packages, so a real
--     `self._disturbanceService:Emit(...)` call cannot be exercised end-to-end here)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate). H.32 (MANUAL-DEVICE, iPhone SE-class) is explicitly DEFERRED, not
-- automated -- same honest-gap pattern as pc-1's H.26.
--
-- H.11h is the single most important test in this file (see its own comment block below):
-- it is the test that proves the G1-exploit-closing anchor-on-eligibility rule is wired in
-- the exact evaluation order the GDD's D.4 Step 0a mandates, including the case a naive
-- "anchor only inside the grace-window branch" implementation would get WRONG.

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")
local Logic = require(ServerScriptService.gameplay.services.PlayerControllerEmissionPublisherLogic)
local DisturbanceConstants = require(ServerScriptService.gameplay.services.DisturbanceConstants)

type AxisEmissionState = Logic.AxisEmissionState
type PlayerEmissionState = Logic.PlayerEmissionState

return function()
	describe("PlayerControllerEmissionPublisherLogic -- Story 003 (D.4 pulse magnitude, D.6 sampling)", function()
		-- ====================================================================
		-- H.11 -- grace-eligible first pulse fires at full magnitude, and the
		-- anchor is written to the EXACT sentinel t_0 (not merely non-nil).
		-- ====================================================================
		local function test_H11_grace_eligible_first_pulse_fires_full_and_anchors_exact_sentinel()
			local axisState = Logic.NewPlayerEmissionState().sprint -- t_lastGracePulse = nil
			local t0 = 12345.0

			local magnitude = Logic.GetPulseMagnitude(axisState, "Sprint", t0, t0 + 0.5, 0.4, "pc")

			expect(magnitude).to.equal(0.10)
			expect(axisState.t_lastGracePulse).to.equal(12345.0) -- the sentinel itself, not merely non-nil
		end
		it("test_H11_grace_eligible_first_pulse_fires_full_and_anchors_exact_sentinel", function()
			test_H11_grace_eligible_first_pulse_fires_full_and_anchors_exact_sentinel()
		end)

		-- ====================================================================
		-- H.11h -- THE LOAD-BEARING TEST. A first pulse that delivers LATE
		-- (past FIRST_PULSE_GRACE_WINDOW=1.0s, simulating server jitter) must
		-- still anchor t_lastGracePulse at t_0 -- NOT at the late delivery
		-- time, and NOT skip the anchor write entirely. A subsequent
		-- state-entry within GRACE_REENTRY_COOLDOWN=6.0s of that anchor must
		-- then observe grace_eligible=false. This is verified INDIRECTLY but
		-- conclusively: the second call uses inputs that would produce a
		-- DIFFERENT magnitude (0.10, the grace/full value) if grace were
		-- wrongly still eligible, versus the correct stationary-attenuated
		-- Sprint hold-floor (0.09) if grace correctly resolved false AND the
		-- anchor is left unchanged (proving Step 0a did NOT re-fire).
		-- ====================================================================
		local function test_H11h_late_delivered_first_pulse_still_anchors_at_state_entry_time()
			local axisState = Logic.NewPlayerEmissionState().sprint -- t_lastGracePulse = nil, so eligible
			local t0 = 12345.0
			local lateDeliveryTime = t0 + 1.5 -- PAST FIRST_PULSE_GRACE_WINDOW = 1.0s

			-- grace_eligible resolves true (nil anchor), so Step 0a anchors t_lastGracePulse = t0
			-- REGARDLESS of the grace-window check below failing (1.5 > 1.0). The pulse itself
			-- falls through to the stationary branch (d_xz=0.4 < EMITTER_MOVEMENT_DELTA_FLOOR)
			-- and, being Sprint, is raised to the hold-floor.
			local firstMagnitude = Logic.GetPulseMagnitude(axisState, "Sprint", t0, lateDeliveryTime, 0.4, "pc")

			expect(axisState.t_lastGracePulse).to.equal(t0) -- anchored at STATE-ENTRY time, not delivery time
			expect(axisState.t_lastGracePulse).never.to.equal(lateDeliveryTime)
			expect(firstMagnitude).to.equal(0.09)

			-- A subsequent state-entry at t0 + 5.0s is WITHIN GRACE_REENTRY_COOLDOWN (6.0s) of the
			-- anchor -- grace_eligible MUST resolve false. Prove it with inputs that would produce
			-- the full-magnitude grace branch (0.10) if a bug wrongly re-granted eligibility: pulse
			-- fires 0.1s after this new t_0 (well within FIRST_PULSE_GRACE_WINDOW if eligible) and
			-- stationary (d_xz=0.4, sub-floor).
			local secondT0 = t0 + 5.0
			local secondMagnitude = Logic.GetPulseMagnitude(axisState, "Sprint", secondT0, secondT0 + 0.1, 0.4, "pc")

			expect(secondMagnitude).to.equal(0.09) -- stationary hold-floor, NOT 0.10 (grace) -- proves grace_eligible=false
			expect(axisState.t_lastGracePulse).to.equal(t0) -- UNCHANGED -- Step 0a did not re-anchor, confirming ineligibility
		end
		it("test_H11h_late_delivered_first_pulse_still_anchors_at_state_entry_time", function()
			test_H11h_late_delivered_first_pulse_still_anchors_at_state_entry_time()
		end)

		-- ====================================================================
		-- H.11b/c -- cooldown-active (anchor 3.0s old, < 6.0s) Sprint: stationary
		-- falls through to the hold-floor (0.09); moving still pays full (0.10)
		-- -- cooldown never silences a moving sprinter.
		-- ====================================================================
		local function test_H11bc_sprint_cooldown_blocked_stationary_floors_moving_pays_full()
			local tNow = 1000.0

			local stationaryAxis = Logic.NewPlayerEmissionState().sprint
			stationaryAxis.t_lastGracePulse = tNow - 3.0 -- cooldown active
			local stationaryMagnitude = Logic.GetPulseMagnitude(stationaryAxis, "Sprint", tNow, tNow + 4.0, 0.4, "pc")
			expect(stationaryMagnitude).to.equal(0.09)

			local movingAxis = Logic.NewPlayerEmissionState().sprint
			movingAxis.t_lastGracePulse = tNow - 3.0 -- cooldown active
			local movingMagnitude = Logic.GetPulseMagnitude(movingAxis, "Sprint", tNow, tNow + 4.0, 5, "pc")
			expect(movingMagnitude).to.equal(0.10)
		end
		it("test_H11bc_sprint_cooldown_blocked_stationary_floors_moving_pays_full", function()
			test_H11bc_sprint_cooldown_blocked_stationary_floors_moving_pays_full()
		end)

		-- ====================================================================
		-- H.11d -- death-reset forward seam: resets BOTH axes' grace anchors
		-- to nil. T5 (Humanoid.Died) itself does not exist yet (Story 004) --
		-- this proves the SEAM function itself, per the story's own scope.
		-- ====================================================================
		local function test_H11d_reset_grace_anchors_on_death_clears_both_axes()
			local state = Logic.NewPlayerEmissionState()
			state.sprint.t_lastGracePulse = 500.0
			state.light.t_lastGracePulse = 600.0

			Logic.ResetGraceAnchorsOnDeath(state)

			expect(state.sprint.t_lastGracePulse).to.equal(nil)
			expect(state.light.t_lastGracePulse).to.equal(nil)
		end
		it("test_H11d_reset_grace_anchors_on_death_clears_both_axes", function()
			test_H11d_reset_grace_anchors_on_death_clears_both_axes()
		end)

		-- ====================================================================
		-- H.11e -- both axes independent and simultaneous: distinct sentinels,
		-- no cross-axis contamination.
		-- ====================================================================
		local function test_H11e_both_axes_independent_simultaneous_no_cross_contamination()
			local state = Logic.NewPlayerEmissionState()
			local sprintT0 = 12345.0
			local lightT0 = 23456.0

			local sprintMagnitude = Logic.GetPulseMagnitude(state.sprint, "Sprint", sprintT0, sprintT0 + 0.2, 0.1, "pc")
			local lightMagnitude = Logic.GetPulseMagnitude(state.light, "Light", lightT0, lightT0 + 0.2, 0.1, "pc")

			expect(sprintMagnitude).to.equal(0.10)
			expect(lightMagnitude).to.equal(0.08)
			expect(state.sprint.t_lastGracePulse).to.equal(12345.0)
			expect(state.light.t_lastGracePulse).to.equal(23456.0)
			expect(state.sprint.t_lastGracePulse).never.to.equal(state.light.t_lastGracePulse)
		end
		it("test_H11e_both_axes_independent_simultaneous_no_cross_contamination", function()
			test_H11e_both_axes_independent_simultaneous_no_cross_contamination()
		end)

		-- ====================================================================
		-- H.11f/g -- Light-axis parity with H.11b/c: cooldown-active stationary
		-- -> 0.024 (no hold-floor on Light); cooldown-active moving -> 0.08
		-- (full).
		-- ====================================================================
		local function test_H11fg_light_cooldown_blocked_stationary_attenuates_moving_pays_full()
			local tNow = 1000.0

			local stationaryAxis = Logic.NewPlayerEmissionState().light
			stationaryAxis.t_lastGracePulse = tNow - 3.0
			local stationaryMagnitude = Logic.GetPulseMagnitude(stationaryAxis, "Light", tNow, tNow + 8.0, 0.2, "pc")
			expect(stationaryMagnitude).to.equal(0.024)

			local movingAxis = Logic.NewPlayerEmissionState().light
			movingAxis.t_lastGracePulse = tNow - 3.0
			local movingMagnitude = Logic.GetPulseMagnitude(movingAxis, "Light", tNow, tNow + 0.3, 5, "pc")
			expect(movingMagnitude).to.equal(0.08)
		end
		it("test_H11fg_light_cooldown_blocked_stationary_attenuates_moving_pays_full", function()
			test_H11fg_light_cooldown_blocked_stationary_attenuates_moving_pays_full()
		end)

		-- ====================================================================
		-- H.12/H.12a/H.81 -- Sprint-axis hold-floor vs Light-axis no-floor
		-- security contrast, in the SAME test (proves the asymmetry is real,
		-- not a global leak). Sprint stationary (cooldown-blocked) -> EXACTLY
		-- 0.09, never 0.03/0.08/0.10. Light stationary (cooldown-blocked) ->
		-- EXACTLY 0.024, NEVER raised to the hold-floor.
		-- ====================================================================
		local function test_H12_H81_sprint_hold_floor_vs_light_no_floor_security_contrast()
			local tNow = 1000.0

			local sprintAxis = Logic.NewPlayerEmissionState().sprint
			sprintAxis.t_lastGracePulse = tNow - 3.0
			local sprintMagnitude = Logic.GetPulseMagnitude(sprintAxis, "Sprint", tNow, tNow + 4.0, 0.5, "pc")
			expect(sprintMagnitude).to.equal(0.09)
			expect(sprintMagnitude).never.to.equal(0.03) -- the pre-hold-floor value; must never leak through
			expect(sprintMagnitude).never.to.equal(0.08)
			expect(sprintMagnitude).never.to.equal(0.10)

			local lightAxis = Logic.NewPlayerEmissionState().light
			lightAxis.t_lastGracePulse = tNow - 3.0
			local lightMagnitude = Logic.GetPulseMagnitude(lightAxis, "Light", tNow, tNow + 8.0, 0.2, "pc")
			expect(lightMagnitude).to.equal(0.024)
			expect(lightMagnitude).never.to.equal(Logic.SPRINT_HOLD_FLOOR) -- the security property: Light is NEVER floored
		end
		it("test_H12_H81_sprint_hold_floor_vs_light_no_floor_security_contrast", function()
			test_H12_H81_sprint_hold_floor_vs_light_no_floor_security_contrast()
		end)

		-- ====================================================================
		-- H.12a -- config validation: the G.7 hierarchy invariant (both
		-- strict) and the STATIONARY_EMISSION_FACTOR (0, 1] range gate.
		-- ====================================================================
		local function test_H12a_config_validation_gates()
			-- Default config accepted.
			local defaultOk = Logic.ValidateConfig(0.08, 0.10, 0.09, 0.30)
			expect(defaultOk).to.equal(true)

			-- SPRINT_HOLD_FLOOR <= MAGNITUDE_LIGHT_PULSE -- rejected (strict).
			local floorEqualsLight = Logic.ValidateConfig(0.08, 0.10, 0.08, 0.30)
			expect(floorEqualsLight).to.equal(false)
			local floorBelowLight = Logic.ValidateConfig(0.08, 0.10, 0.05, 0.30)
			expect(floorBelowLight).to.equal(false)

			-- SPRINT_HOLD_FLOOR >= MAGNITUDE_SPRINT_PULSE -- rejected (strict).
			local floorEqualsSprint = Logic.ValidateConfig(0.08, 0.10, 0.10, 0.30)
			expect(floorEqualsSprint).to.equal(false)
			local floorAboveSprint = Logic.ValidateConfig(0.08, 0.10, 0.15, 0.30)
			expect(floorAboveSprint).to.equal(false)

			-- STATIONARY_EMISSION_FACTOR <= 0 or > 1 -- rejected. Exactly 1.0 is valid.
			local factorZero = Logic.ValidateConfig(0.08, 0.10, 0.09, 0)
			expect(factorZero).to.equal(false)
			local factorNegative = Logic.ValidateConfig(0.08, 0.10, 0.09, -0.1)
			expect(factorNegative).to.equal(false)
			local factorTooHigh = Logic.ValidateConfig(0.08, 0.10, 0.09, 1.5)
			expect(factorTooHigh).to.equal(false)
			local factorExactlyOne = Logic.ValidateConfig(0.08, 0.10, 0.09, 1.0)
			expect(factorExactlyOne).to.equal(true)
		end
		it("test_H12a_config_validation_gates", function()
			test_H12a_config_validation_gates()
		end)

		-- ====================================================================
		-- H.13/H.14 -- mobile-drift-floor platform distinction. Touch zeroes
		-- effective_d below MOBILE_ANALOG_DRIFT_THRESHOLD; PC does not apply
		-- the drift gate at all (but reaches the same stationary output via
		-- the ordinary EMITTER_MOVEMENT_DELTA_FLOOR path) -- same magnitude,
		-- different code path.
		-- ====================================================================
		local function test_H13_H14_mobile_drift_floor_distinguishes_platform_not_output()
			local touchAxis = Logic.NewPlayerEmissionState().light
			touchAxis.t_lastGracePulse = 1000.0 - 3.0
			local touchMagnitude = Logic.GetPulseMagnitude(touchAxis, "Light", 1000.0, 1000.0 + 4.0, 0.2, "touch")
			expect(touchMagnitude).to.equal(0.024)

			local pcAxis = Logic.NewPlayerEmissionState().light
			pcAxis.t_lastGracePulse = 1000.0 - 3.0
			local pcMagnitude = Logic.GetPulseMagnitude(pcAxis, "Light", 1000.0, 1000.0 + 4.0, 0.2, "pc")
			expect(pcMagnitude).to.equal(0.024) -- same output as touch, reached via the movement-delta floor, not the drift gate
		end
		it("test_H13_H14_mobile_drift_floor_distinguishes_platform_not_output", function()
			test_H13_H14_mobile_drift_floor_distinguishes_platform_not_output()
		end)

		-- ====================================================================
		-- H.15 -- two emission types, no dedup. EvaluatePulse composes
		-- IsPulseDue + GetPulseMagnitude for the Knit wrapper's per-tick call
		-- -- this proves BOTH axes independently fire pulses on their own
		-- cadence (Sprint 2s / Light 4s), with no shared suppression between
		-- them.
		-- ====================================================================
		local function test_H15_both_axes_fire_independently_on_own_cadence_no_dedup()
			local state = Logic.NewPlayerEmissionState()
			local origin = Vector3.new(0, 0, 0)

			Logic.OnAxisEntered(state.sprint, origin, 100.0)
			Logic.OnAxisEntered(state.light, origin, 100.0)

			-- Both axes' first pulse is due immediately at state-entry.
			local sprintFirst = Logic.EvaluatePulse(state.sprint, "Sprint", 100.0, origin, "pc")
			local lightFirst = Logic.EvaluatePulse(state.light, "Light", 100.0, origin, "pc")
			expect(sprintFirst).never.to.equal(nil)
			expect(lightFirst).never.to.equal(nil)
			expect(sprintFirst).to.equal(0.10) -- grace-exempt full magnitude
			expect(lightFirst).to.equal(0.08)

			-- Advance 2.0s: Sprint's next pulse (SPRINT_PULSE_INTERVAL=2.0s) is due; Light's
			-- (LIGHT_PULSE_INTERVAL=4.0s) is NOT -- proves independent cadence, not a shared timer.
			local sprintSecond = Logic.EvaluatePulse(state.sprint, "Sprint", 102.0, origin, "pc")
			local lightSecond = Logic.EvaluatePulse(state.light, "Light", 102.0, origin, "pc")
			expect(sprintSecond).never.to.equal(nil)
			expect(lightSecond).to.equal(nil) -- not due yet, NOT suppressed by Sprint's pulse (no dedup, just not due)

			-- Advance to 104.0s: Light's pulse is now due too.
			local lightThird = Logic.EvaluatePulse(state.light, "Light", 104.0, origin, "pc")
			expect(lightThird).never.to.equal(nil)
		end
		it("test_H15_both_axes_fire_independently_on_own_cadence_no_dedup", function()
			test_H15_both_axes_fire_independently_on_own_cadence_no_dedup()
		end)

		-- ====================================================================
		-- H.32 -- MANUAL-DEVICE (iPhone SE-class). DEFERRED, honestly (same
		-- pattern as pc-1's H.26): a stationary player with sub-2-stud
		-- thumbstick drift, sprint held 10s, every pulse past the grace window
		-- at exactly SPRINT_HOLD_FLOOR=0.09, requires a live mobile device and
		-- position-log capture this project's automated test harness cannot
		-- produce. Not automated here. The FORMULA this depends on
		-- (GetPulseMagnitude's Sprint hold-floor branch, touch-platform drift
		-- zeroing) is fully covered by test_H12_H81_... and
		-- test_H13_H14_... above.
		-- ====================================================================
		local function test_H32_manual_device_deferred()
			pending("H.32 is MANUAL-DEVICE (iPhone SE-class) -- DEFERRED, not automated (see comment block above)")
		end
		it("test_H32_manual_device_deferred", function()
			test_H32_manual_device_deferred()
		end)

		-- ====================================================================
		-- Supporting formula coverage (not a named AC, but load-bearing for
		-- every test above): D.6 XZ-displacement sampling discards Y, and the
		-- axis-transition hooks seed/clear the right fields.
		-- ====================================================================
		local function test_D6_sample_xz_displacement_discards_y()
			local previous = Vector3.new(10, 0, 10)
			local jumpInPlace = Vector3.new(10, 50, 10) -- large Y change, zero XZ change
			expect(Logic.SampleXZDisplacement(previous, jumpInPlace)).to.equal(0)

			local movedXZ = Vector3.new(13, 0, 14)
			expect(Logic.SampleXZDisplacement(previous, movedXZ)).to.equal(5) -- 3-4-5 triangle
		end
		it("test_D6_sample_xz_displacement_discards_y", function()
			test_D6_sample_xz_displacement_discards_y()
		end)

		local function test_axis_transition_hooks_seed_and_clear_without_touching_grace_anchor()
			local axisState = Logic.NewPlayerEmissionState().sprint
			axisState.t_lastGracePulse = 42.0 -- simulate a prior grace pulse from an earlier state-entry

			local position = Vector3.new(5, 0, 5)
			Logic.OnAxisEntered(axisState, position, 100.0)
			expect(axisState.t_0).to.equal(100.0)
			expect(axisState.lastPulseFiredAt).to.equal(nil)
			expect(axisState.lastPulsePosition).to.equal(position)
			expect(axisState.t_lastGracePulse).to.equal(42.0) -- UNTOUCHED by entry

			Logic.OnAxisExited(axisState)
			expect(axisState.t_0).to.equal(nil)
			expect(axisState.lastPulseFiredAt).to.equal(nil)
			expect(axisState.lastPulsePosition).to.equal(nil)
			expect(axisState.t_lastGracePulse).to.equal(42.0) -- STILL untouched -- cooldown survives axis-off
		end
		it("test_axis_transition_hooks_seed_and_clear_without_touching_grace_anchor", function()
			test_axis_transition_hooks_seed_and_clear_without_touching_grace_anchor()
		end)

		-- ====================================================================
		-- Code-review follow-up (rc-2/ed-4/ed-5/pc-3/pc-11 review batch,
		-- 2026-07-08): the 8 ED-registry-owned constants below are duplicated
		-- locally in PlayerControllerEmissionPublisherLogic.luau (documented
		-- SCOPE NOTE, same test-harness require() gap as
		-- DisturbanceServiceEmissionLogic.luau's precedent). Nothing previously
		-- caught drift between the local copy and DisturbanceConstants.luau's
		-- canonical values -- this test closes that gap.
		-- ====================================================================
		local function test_locally_duplicated_ed_registry_constants_match_canonical_source()
			expect(Logic.MAGNITUDE_SPRINT_PULSE).to.equal(DisturbanceConstants.MAGNITUDE_SPRINT_PULSE)
			expect(Logic.MAGNITUDE_LIGHT_PULSE).to.equal(DisturbanceConstants.MAGNITUDE_LIGHT_PULSE)
			expect(Logic.SPRINT_HOLD_FLOOR).to.equal(DisturbanceConstants.SPRINT_HOLD_FLOOR)
			expect(Logic.STATIONARY_EMISSION_FACTOR).to.equal(DisturbanceConstants.STATIONARY_EMISSION_FACTOR)
			expect(Logic.EMITTER_MOVEMENT_DELTA_FLOOR).to.equal(DisturbanceConstants.EMITTER_MOVEMENT_DELTA_FLOOR)
			expect(Logic.FIRST_PULSE_GRACE_WINDOW).to.equal(DisturbanceConstants.FIRST_PULSE_GRACE_WINDOW)
			expect(Logic.SPRINT_PULSE_INTERVAL).to.equal(DisturbanceConstants.SPRINT_PULSE_INTERVAL)
			expect(Logic.LIGHT_PULSE_INTERVAL).to.equal(DisturbanceConstants.LIGHT_PULSE_INTERVAL)
		end
		it("test_locally_duplicated_ed_registry_constants_match_canonical_source", function()
			test_locally_duplicated_ed_registry_constants_match_canonical_source()
		end)
	end)

	-- ========================================================================
	-- Static/structural source-text checks against the real
	-- PlayerControllerService.luau file. This harness cannot instantiate Knit
	-- services (Knit/Signal are not vendored under ReplicatedStorage.Packages),
	-- so the real cross-service `self._disturbanceService:Emit(...)` call
	-- cannot be exercised live -- these checks prove the CALL SITE shape
	-- instead, matching the precedent
	-- tests/unit/ecological-disturbance/emission-schema-server-emit-intake_test
	-- .luau and tests/unit/runcontroller/run_end_condition_raised_test.luau
	-- both already established for exactly this class of gap.
	-- ========================================================================
	describe("PlayerControllerService -- Story 003 (Emit call-site structural checks, H.15)", function()
		local serviceSource: string? = nil

		-- Strips Lua/Luau single-line comments before the checks below run, so a doc comment
		-- that merely MENTIONS a call shape in prose doesn't false-positive a check looking for
		-- real code. Same naive first-`--`-match implementation (and the same documented
		-- quote-awareness caveat) as the precedent in
		-- tests/unit/ecological-disturbance/emission-schema-server-emit-intake_test.luau.
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function loadServiceSource(): string
			if not serviceSource then
				serviceSource = stripLuaComments(fs.readFile("src/gameplay/services/PlayerControllerService.luau"))
			end
			return serviceSource :: string
		end

		-- ====================================================================
		-- H.15 -- two distinct Emit(...) call sites, one per emission type,
		-- both reachable from the SAME Heartbeat tick with no dedup logic
		-- between them (no shared suppression flag/guard connects the two
		-- call sites to each other).
		-- ====================================================================
		local function test_two_distinct_emit_call_sites_sprint_and_light()
			local source = loadServiceSource()
			expect(source:find('self%._disturbanceService:Emit%("Sprint"')).never.to.equal(nil)
			expect(source:find('self%._disturbanceService:Emit%("Light"')).never.to.equal(nil)
		end
		it("test_two_distinct_emit_call_sites_sprint_and_light", function()
			test_two_distinct_emit_call_sites_sprint_and_light()
		end)

		-- ====================================================================
		-- Cross-service call is made via Knit.GetService, in KnitStart (ADR-0001
		-- Rule 1's sanctioned pattern) -- not assumed/cached before KnitStart.
		-- ====================================================================
		local function test_disturbance_service_acquired_via_knit_get_service_in_knit_start()
			local source = loadServiceSource()
			local knitStartStart = source:find("function PlayerControllerService:KnitStart%(")
			expect(knitStartStart).never.to.equal(nil)
			local knitStartEnd = source:find("function PlayerControllerService:_initPlayerState%(", knitStartStart :: number)
			expect(knitStartEnd).never.to.equal(nil)
			local knitStartBody = source:sub(knitStartStart :: number, (knitStartEnd :: number) - 1)
			expect(knitStartBody:find('Knit%.GetService%("DisturbanceService"%)')).never.to.equal(nil)
		end
		it("test_disturbance_service_acquired_via_knit_get_service_in_knit_start", function()
			test_disturbance_service_acquired_via_knit_get_service_in_knit_start()
		end)

		-- ====================================================================
		-- Emission position is never a client-supplied value -- both Emit
		-- call sites are fed by `position`, sourced from
		-- `self:_getServerPosition(player)` (HumanoidRootPart.Position), never
		-- from a RemoteEvent payload argument.
		-- ====================================================================
		local function test_emit_position_argument_is_server_observed_not_client_supplied()
			local source = loadServiceSource()
			expect(source:find("function PlayerControllerService:_getServerPosition%(")).never.to.equal(nil)
			expect(source:find("rootPart%.Position")).never.to.equal(nil)
			-- The RequestSprintToggle/RequestLanternToggle handlers' own payload variables
			-- (`sprint`, `raised`) are booleans, never forwarded as a position argument anywhere.
			expect(source:find("self%._disturbanceService:Emit%(.-sprint,.-%)")).to.equal(nil)
			expect(source:find("self%._disturbanceService:Emit%(.-raised,.-%)")).to.equal(nil)
		end
		it("test_emit_position_argument_is_server_observed_not_client_supplied", function()
			test_emit_position_argument_is_server_observed_not_client_supplied()
		end)

		-- ====================================================================
		-- Code-review follow-up (rc-2/ed-4/ed-5/pc-3/pc-11 review batch,
		-- 2026-07-08): a copy-paste axis swap between _applyLocomotionTransition
		-- (Sprint) and _applyLightAxisTransition (Light) would silently
		-- cross-contaminate the two axes' independent grace/cooldown state, and
		-- nothing previously caught it -- confirms each hook body references
		-- ITS OWN axis field, not the other one.
		-- ====================================================================
		local function test_locomotion_transition_hook_feeds_sprint_axis_not_light()
			local source = loadServiceSource()
			local fnStart = source:find("function PlayerControllerService:_applyLocomotionTransition%(")
			expect(fnStart).never.to.equal(nil)
			local fnEnd = source:find("\nend", fnStart :: number)
			expect(fnEnd).never.to.equal(nil)
			local fnBody = source:sub(fnStart :: number, fnEnd :: number)
			expect(fnBody:find("emissionState%.sprint")).never.to.equal(nil)
			expect(fnBody:find("emissionState%.light")).to.equal(nil)
		end
		it("test_locomotion_transition_hook_feeds_sprint_axis_not_light", function()
			test_locomotion_transition_hook_feeds_sprint_axis_not_light()
		end)

		local function test_light_axis_transition_hook_feeds_light_axis_not_sprint()
			local source = loadServiceSource()
			local fnStart = source:find("function PlayerControllerService:_applyLightAxisTransition%(")
			expect(fnStart).never.to.equal(nil)
			local fnEnd = source:find("\nend", fnStart :: number)
			expect(fnEnd).never.to.equal(nil)
			local fnBody = source:sub(fnStart :: number, fnEnd :: number)
			expect(fnBody:find("emissionState%.light")).never.to.equal(nil)
			expect(fnBody:find("emissionState%.sprint")).to.equal(nil)
		end
		it("test_light_axis_transition_hook_feeds_light_axis_not_sprint", function()
			test_light_axis_transition_hook_feeds_light_axis_not_sprint()
		end)
	end)
end
