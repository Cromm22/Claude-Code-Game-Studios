--!strict
-- lantern-gather-gate_test
--
-- TestEZ unit tests for Story 002: Lantern Axis, Light-to-Gather Gate &
-- Tap-Hold Gather.
-- Story: production/epics/player-controller/story-002-lantern-gather-gate.md
-- Production code under test: src/gameplay/services/PlayerControllerLanternLogic.luau
--
-- These tests require PlayerControllerLanternLogic directly -- NOT
-- PlayerControllerService (the Knit wrapper) -- because that module is
-- dependency-free (no Knit, no Roblox service calls) and therefore portable
-- to Lemur without a vendored Knit package or a Rojo-synced DataModel. The
-- Knit-wrapper service delegates to these exact functions with no
-- additional branching beyond Player-identity bookkeeping and the ADR-0006
-- step-1/3/5 plumbing (alive-guard stub, global-budget bookkeeping, the
-- intentional step-5 no-op) -- so coverage here is representative of the
-- production service's actual decision logic. A live-Studio/TestService
-- smoke pass is still recommended to confirm the Knit wiring itself
-- (Client signal connection, PlayerAdded/PlayerRemoving) once Rojo sync is
-- live -- this mirrors the same Lemur-fidelity caveat already documented in
-- the GDD's own C.11 section for instance-lifecycle-dependent paths.
--
-- NOTE (require-path provisional): no Rojo default.project.json exists yet
-- in this repo (a pre-existing, already-flagged gap -- see tests/README.md's
-- own "the precise Lemur CLI invocation ... has not been verified against a
-- real run yet" note). The require() below assumes the eventual
-- project.json mounts src/gameplay under ServerScriptService, the
-- conventional location for Knit server-side services. Adjust this path
-- once default.project.json is authored and the test suite is run for
-- real -- this is infra wiring outside this story's scope, not a defect in
-- the logic under test.
local ServerScriptService = game:GetService("ServerScriptService")
local LanternLogic = require(ServerScriptService.gameplay.services.PlayerControllerLanternLogic)

type PlayerState = LanternLogic.PlayerState
type LanternRateLimitRecord = LanternLogic.LanternRateLimitRecord

return function()
	describe("PlayerControllerLanternLogic -- Story 002 (lantern axis, light-to-gather gate, tap-hold gather)", function()
		-- ====================================================================
		-- H.9 -- orthogonal axes: lantern toggle never touches the
		-- locomotion stub field.
		-- ====================================================================
		local function test_lantern_toggle_leaves_locomotion_stub_untouched()
			local state: PlayerState = LanternLogic.NewPlayerState()
			state.lantern = "S3a"
			state.locomotion = "S2-STUB-SENTINEL" -- opaque stub seam Story 001 will own

			local accepted = LanternLogic.HandleLanternToggleDomain(state, true)

			expect(accepted).to.equal(true)
			expect(state.lantern).to.equal("S3b")
			expect(state.locomotion).to.equal("S2-STUB-SENTINEL")
		end

		it("test_lantern_toggle_leaves_locomotion_stub_untouched", function()
			test_lantern_toggle_leaves_locomotion_stub_untouched()
		end)

		-- ====================================================================
		-- H.10 -- same-state debounce + burst cap: rapid S3b -> S3a -> S3b
		-- converges to the final requested state with no phantom
		-- intermediate transitions. Cross-platform-feel confirmation
		-- (PC/Mobile/Gamepad) is ADVISORY per the story -- deferred to
		-- manual playtest, not automated here.
		-- ====================================================================
		local function test_rapid_S3a_S3b_S3a_S3b_converges_to_final_requested_state()
			local state: PlayerState = LanternLogic.NewPlayerState()
			state.lantern = "S3b" -- starting raised, per the AC's GIVEN

			-- S3b -> S3a, within the 200ms window.
			local accepted1, reason1 = LanternLogic.HandleLanternToggleDomain(state, false)
			expect(accepted1).to.equal(true)
			expect(reason1).to.equal(nil)
			expect(state.lantern).to.equal("S3a")

			-- S3a -> S3b, still within the 200ms window.
			local accepted2, reason2 = LanternLogic.HandleLanternToggleDomain(state, true)
			expect(accepted2).to.equal(true)
			expect(reason2).to.equal(nil)
			expect(state.lantern).to.equal("S3b")

			-- A same-state duplicate immediately after: must be dropped
			-- (debounced), proving no phantom emission on a redundant
			-- request converging to the same final state.
			local accepted3, reason3 = LanternLogic.HandleLanternToggleDomain(state, true)
			expect(accepted3).to.equal(false)
			expect(reason3).to.equal("same-state-debounced")
			expect(state.lantern).to.equal("S3b")
		end

		it("test_rapid_S3a_S3b_S3a_S3b_converges_to_final_requested_state", function()
			test_rapid_S3a_S3b_S3a_S3b_converges_to_final_requested_state()
		end)

		-- ====================================================================
		-- H.25 -- the four locomotion x lantern combinations: mutating
		-- either axis independently leaves the other axis unchanged, in
		-- all 8 single-axis transitions (4 combos x 2 checks each).
		-- ====================================================================
		local function test_eight_single_axis_transitions_leave_other_axis_unchanged()
			local combos: { { locomotion: string, lantern: LanternLogic.LanternState } } = {
				{ locomotion = "S1", lantern = "S3a" },
				{ locomotion = "S1", lantern = "S3b" },
				{ locomotion = "S2", lantern = "S3a" },
				{ locomotion = "S2", lantern = "S3b" },
			}

			for _, combo in combos do
				-- Check (a): mutate the lantern axis only. Locomotion stub
				-- must remain byte-for-byte unchanged.
				do
					local state: PlayerState = LanternLogic.NewPlayerState()
					state.locomotion = combo.locomotion
					state.lantern = combo.lantern

					local otherLanternState: LanternLogic.LanternState = if combo.lantern == "S3a" then "S3b" else "S3a"
					local accepted = LanternLogic.HandleLanternToggleDomain(state, otherLanternState == "S3b")

					expect(accepted).to.equal(true)
					expect(state.lantern).to.equal(otherLanternState)
					expect(state.locomotion).to.equal(combo.locomotion)
				end

				-- Check (b): mutate the locomotion axis only (simulated by
				-- a direct write, standing in for Story 001's future
				-- logic, per the story's own "model locomotion as a stub
				-- field" instruction). Lantern axis must remain unchanged.
				do
					local state: PlayerState = LanternLogic.NewPlayerState()
					state.locomotion = combo.locomotion
					state.lantern = combo.lantern

					state.locomotion = combo.locomotion == "S1" and "S2" or "S1" -- stand-in for a future Story 001 mutation

					expect(state.lantern).to.equal(combo.lantern)
				end
			end
		end

		it("test_eight_single_axis_transitions_leave_other_axis_unchanged", function()
			test_eight_single_axis_transitions_leave_other_axis_unchanged()
		end)

		-- ====================================================================
		-- H.74 -- same-state request dropped BEFORE any side-effect,
		-- including a read/write of t_lastGracePulse_light.
		-- ====================================================================
		local function test_same_state_request_dropped_before_touching_grace_pulse_anchor()
			local state: PlayerState = LanternLogic.NewPlayerState()
			state.lantern = "S3a"
			state.t_lastGracePulse_light = 12345.5 -- sentinel: no function in this module ever writes this field

			local accepted, reason = LanternLogic.HandleLanternToggleDomain(state, false) -- same-state (already S3a)

			expect(accepted).to.equal(false)
			expect(reason).to.equal("same-state-debounced")
			expect(state.lantern).to.equal("S3a")
			expect(state.t_lastGracePulse_light).to.equal(12345.5)
		end

		it("test_same_state_request_dropped_before_touching_grace_pulse_anchor", function()
			test_same_state_request_dropped_before_touching_grace_pulse_anchor()
		end)

		-- ====================================================================
		-- H.74 -- burst cap (8 per 2.0s) drops excess while the 5/s
		-- per-second limit also independently holds. Isolated at the
		-- rate-limit layer (step 2), independent of same-state debounce
		-- (step 6) -- rate limiting doesn't inspect the requested value.
		-- ====================================================================
		local function test_burst_cap_drops_excess_within_2s_while_persec_limit_also_holds()
			local record: LanternRateLimitRecord = {
				perSecond = { count = 0, windowStart = 0 },
				burst = { count = 0, windowStart = 0 },
			}

			-- 10 requests evenly spaced 0.2s apart across [0, 1.8]: this
			-- lands 5 in each of two successive 1-second per-second
			-- sub-windows ([0,1.0) and [1.0,2.0)), so the 5/s cap is never
			-- the reason for a drop -- but the single 2.0s burst window
			-- (which never tumbles across this span) accumulates across
			-- both sub-windows and hits its cap of 8 at the 9th request.
			local timestamps = { 0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8 }
			local results: { boolean } = {}
			for _, t in timestamps do
				table.insert(results, LanternLogic.CheckLanternToggleRateLimit(record, t))
			end

			local expectedAccepted = { true, true, true, true, true, true, true, true, false, false }
			for i, expectedResult in expectedAccepted do
				expect(results[i]).to.equal(expectedResult)
			end

			-- Exactly the burst cap's worth (8) were accepted -- confirms
			-- the drop is attributable to the burst cap, not the
			-- per-second limit (which, per the spacing above, never
			-- individually reached its own cap of 5 within either
			-- sub-window before the burst cap intervened).
			local acceptedCount = 0
			for _, wasAccepted in results do
				if wasAccepted then
					acceptedCount += 1
				end
			end
			expect(acceptedCount).to.equal(8)
		end

		it("test_burst_cap_drops_excess_within_2s_while_persec_limit_also_holds", function()
			test_burst_cap_drops_excess_within_2s_while_persec_limit_also_holds()
		end)

		-- ====================================================================
		-- H.84 Part 1 -- C3_6_CanArmGather predicate matrix.
		-- ====================================================================
		local function test_can_arm_gather_predicate_dark_zone_and_lantern_matrix()
			expect(LanternLogic.C3_6_CanArmGather(false, true)).to.equal(false) -- dark zone, lantern lowered -> cannot arm
			expect(LanternLogic.C3_6_CanArmGather(true, true)).to.equal(true) -- dark zone, lantern raised -> can arm
			expect(LanternLogic.C3_6_CanArmGather(false, false)).to.equal(true) -- ambient-lit -> always armable
			expect(LanternLogic.C3_6_CanArmGather(true, false)).to.equal(true) -- ambient-lit -> always armable
		end

		it("test_can_arm_gather_predicate_dark_zone_and_lantern_matrix", function()
			test_can_arm_gather_predicate_dark_zone_and_lantern_matrix()
		end)

		-- ====================================================================
		-- H.88(b) -- config validation rejects the coupled-knob violation,
		-- accepts the shipped default.
		-- ====================================================================
		local function test_config_validation_rejects_gather_radius_gte_lantern_radius()
			local okEqual, msgEqual = LanternLogic.ValidateConfig(20, 20) -- equal -- strict >= must reject
			expect(okEqual).to.equal(false)
			expect(msgEqual).never.to.equal(nil)

			local okGreater, msgGreater = LanternLogic.ValidateConfig(25, 20) -- greater -- must reject
			expect(okGreater).to.equal(false)
			expect(msgGreater).never.to.equal(nil)
		end

		it("test_config_validation_rejects_gather_radius_gte_lantern_radius", function()
			test_config_validation_rejects_gather_radius_gte_lantern_radius()
		end)

		local function test_config_validation_accepts_default_radii()
			expect(LanternLogic.GATHER_PROXIMITY_RADIUS).to.equal(4)
			expect(LanternLogic.LANTERN_VISIBILITY_RADIUS).to.equal(20)

			local ok, msg =
				LanternLogic.ValidateConfig(LanternLogic.GATHER_PROXIMITY_RADIUS, LanternLogic.LANTERN_VISIBILITY_RADIUS)
			expect(ok).to.equal(true)
			expect(msg).to.equal(nil)
		end

		it("test_config_validation_accepts_default_radii", function()
			test_config_validation_accepts_default_radii()
		end)

		-- ====================================================================
		-- H.89 -- mid-gather lantern-lower cancel, dark-zone-scoped only.
		-- ====================================================================
		local function test_mid_gather_lantern_lower_cancels_dark_zone_scoped_hold()
			local state: PlayerState = LanternLogic.NewPlayerState()
			state.lantern = "S3b"

			local began = LanternLogic.BeginGatherHold(state, "node-1", true, 100.0) -- dark zone
			expect(began).to.equal(true)
			expect(state.gatherInProgress).never.to.equal(nil)

			-- Lantern lowers mid-hold, before TAP_HOLD_COMMIT_DURATION elapses.
			local accepted = LanternLogic.HandleLanternToggleDomain(state, false)
			expect(accepted).to.equal(true)
			expect(state.lantern).to.equal("S3a")
			expect(state.gatherInProgress).to.equal(nil) -- cancelled server-side

			-- Zero RequestGather can complete for this hold.
			local committed = LanternLogic.TryCommitGatherHold(state, "node-1")
			expect(committed).to.equal(false)
		end

		it("test_mid_gather_lantern_lower_cancels_dark_zone_scoped_hold", function()
			test_mid_gather_lantern_lower_cancels_dark_zone_scoped_hold()
		end)

		local function test_mid_gather_lantern_lower_does_not_cancel_ambient_lit_hold()
			local state: PlayerState = LanternLogic.NewPlayerState()
			state.lantern = "S3b"

			local began = LanternLogic.BeginGatherHold(state, "node-2", false, 100.0) -- ambient-lit zone
			expect(began).to.equal(true) -- C3_6_CanArmGather(true, false) == true regardless of lantern

			local accepted = LanternLogic.HandleLanternToggleDomain(state, false)
			expect(accepted).to.equal(true)
			expect(state.lantern).to.equal("S3a")
			expect(state.gatherInProgress).never.to.equal(nil) -- NOT cancelled -- ambient-lit-scoped hold survives

			local committed = LanternLogic.TryCommitGatherHold(state, "node-2")
			expect(committed).to.equal(true)
		end

		it("test_mid_gather_lantern_lower_does_not_cancel_ambient_lit_hold", function()
			test_mid_gather_lantern_lower_does_not_cancel_ambient_lit_hold()
		end)
	end)
end
