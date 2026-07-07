--!strict
-- emission-schema-server-emit-intake_test
--
-- Unit tests for Story 002: Emission Schema & Server-Authoritative Emit() Intake.
-- Story: production/epics/ecological-disturbance/story-002-emission-schema-emit-intake.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceEmissionLogic.luau (pure schema validator +
--     EmissionPayload constructor -- H.1/H.2/H.3/H.3b/H.3c/H.6/H.6b)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only for
--     H.7b's clock-source restriction and the no-client-path AC -- see below for why)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate). This file mixes true behavioral tests (against the Knit-free
-- DisturbanceServiceEmissionLogic module) with static/structural source-text checks (against
-- the actual DisturbanceService.luau file text), exactly matching the precedent established by
-- tests/integration/ecological-disturbance/service-bootstrap-config-validation_test.luau's
-- third describe() block: DisturbanceService.luau cannot be instantiated under this harness
-- (Knit is not yet vendored under ReplicatedStorage.Packages), so a live
-- `DisturbanceService:Emit()` call is not currently possible in an automated test -- H.7b and
-- the no-client-path AC are instead proven via source-text checks against the real file.

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local EmissionLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceEmissionLogic)

type EmissionType = EmissionLogic.EmissionType

-- Lua patterns do not support {n} repetition counts (unlike the AC's own PCRE-style
-- `^[%x]{8}%-...$` notation) -- this is the Lua-pattern-equivalent of that regex, built by
-- repeating %x literally instead. Used only by this test file's own assertions; production
-- code never re-validates emissionId's format (it trusts HttpService:GenerateGUID(false) at
-- the DisturbanceService:Emit() call site -- see the H.7b describe() block below for why that
-- call site itself is only source-text-checked, not exercised, under this harness).
local function looksLikeUuid(id: string): boolean
	return id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$") ~= nil
end

-- A fixed, well-formed 8-4-4-4-12 hex string standing in for a real
-- HttpService:GenerateGUID(false) return value (per this story's clock/GUID-injection-seam
-- design: DisturbanceServiceEmissionLogic never generates its own id, it only accepts one).
local SAMPLE_EMISSION_ID = "a1b2c3d4-e5f6-47a8-89ab-cdef01234567"
local SAMPLE_NOW = 1000.5

return function()
	describe("DisturbanceServiceEmissionLogic -- Story 002 (schema validation, EmissionPayload construction)", function()
		-- ====================================================================
		-- H.1 -- well-formed call inserts (constructs) a payload with emissionId matching the
		-- UUID format, emissionTime equal to the injected clock value, and all other fields
		-- matching the call's arguments exactly.
		-- ====================================================================
		local function test_well_formed_emission_is_accepted_with_exact_field_passthrough()
			local position = Vector3.new(10, 0, 20)
			local attributionChain = { "GatherWood" }

			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				position,
				0.25,
				12345,
				attributionChain,
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)

			expect(rejection).to.equal(nil)
			expect(payload).never.to.equal(nil)

			local p = payload :: EmissionLogic.EmissionPayload
			expect(looksLikeUuid(p.emissionId)).to.equal(true)
			expect(p.emissionId).to.equal(SAMPLE_EMISSION_ID)
			expect(p.emissionTime).to.equal(SAMPLE_NOW)
			expect(p.sourcePlayerId).to.equal(12345)
			expect(p.emissionType).to.equal("Gather")
			expect(p.position).to.equal(position)
			expect(p.initialMagnitude).to.equal(0.25)
			expect(#p.attributionChain).to.equal(1)
			expect(p.attributionChain[1]).to.equal("GatherWood")
		end
		it("test_well_formed_emission_is_accepted_with_exact_field_passthrough", function()
			test_well_formed_emission_is_accepted_with_exact_field_passthrough()
		end)

		-- Edge case (AC-H.1): initialMagnitude exactly at MAGNITUDE_FLOOR (0.02) still inserts.
		-- MAGNITUDE_FLOOR governs decay/expiry (C.1.4/C.1.12), a separate mechanism from Emit()
		-- rejection (H.3 only requires strictly-positive) -- 0.02 is well above the H.3 floor
		-- of "> 0", so it must be accepted. The literal 0.02 here matches
		-- DisturbanceConstants.MAGNITUDE_FLOOR (this test intentionally does not require()
		-- DisturbanceConstants -- see this story's harness-driven scope note in
		-- DisturbanceServiceEmissionLogic.luau's header comment).
		local function test_magnitude_exactly_at_magnitude_floor_is_accepted()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0.02,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(rejection).to.equal(nil)
			expect(payload).never.to.equal(nil)
		end
		it("test_magnitude_exactly_at_magnitude_floor_is_accepted", function()
			test_magnitude_exactly_at_magnitude_floor_is_accepted()
		end)

		-- Edge case (AC-H.1): attributionChain length exactly 4 accepts; length 5 rejects.
		local function test_attribution_chain_length_exactly_four_is_accepted()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0.25,
				1,
				{ "a", "b", "c", "d" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(rejection).to.equal(nil)
			expect(payload).never.to.equal(nil)
		end
		it("test_attribution_chain_length_exactly_four_is_accepted", function()
			test_attribution_chain_length_exactly_four_is_accepted()
		end)

		local function test_attribution_chain_length_five_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0.25,
				1,
				{ "a", "b", "c", "d", "e" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect(rejection).never.to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("attribution-chain-too-long")
		end
		it("test_attribution_chain_length_five_is_rejected", function()
			test_attribution_chain_length_five_is_rejected()
		end)

		-- ====================================================================
		-- H.2 -- any one of the seven required payload fields missing/null -> rejected, no
		-- source inserted, error identifies the missing field. Each field tested independently
		-- (7 separate tests, per the story's own QA Test Cases instruction).
		-- ====================================================================
		local function validArgs(): { any }
			return {
				"Gather", -- emissionType
				Vector3.new(1, 2, 3), -- position
				0.25, -- initialMagnitude
				99, -- sourcePlayerId
				{ "GatherWood" }, -- attributionChain
				SAMPLE_NOW, -- now (emissionTime)
				SAMPLE_EMISSION_ID, -- emissionId
			}
		end

		local function test_missing_emission_id_is_rejected()
			local a = validArgs()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(a[1], a[2], a[3], a[4], a[5], a[6], nil)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("missing-field")
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("emissionId")
		end
		it("test_missing_emission_id_is_rejected", function()
			test_missing_emission_id_is_rejected()
		end)

		local function test_missing_source_player_id_is_rejected()
			local a = validArgs()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(a[1], a[2], a[3], nil, a[5], a[6], a[7])
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("missing-field")
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("sourcePlayerId")
		end
		it("test_missing_source_player_id_is_rejected", function()
			test_missing_source_player_id_is_rejected()
		end)

		local function test_missing_emission_type_is_rejected()
			local a = validArgs()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(nil, a[2], a[3], a[4], a[5], a[6], a[7])
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("missing-field")
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("emissionType")
		end
		it("test_missing_emission_type_is_rejected", function()
			test_missing_emission_type_is_rejected()
		end)

		local function test_missing_position_is_rejected()
			local a = validArgs()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(a[1], nil, a[3], a[4], a[5], a[6], a[7])
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("missing-field")
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("position")
		end
		it("test_missing_position_is_rejected", function()
			test_missing_position_is_rejected()
		end)

		local function test_missing_initial_magnitude_is_rejected()
			local a = validArgs()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(a[1], a[2], nil, a[4], a[5], a[6], a[7])
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("missing-field")
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("initialMagnitude")
		end
		it("test_missing_initial_magnitude_is_rejected", function()
			test_missing_initial_magnitude_is_rejected()
		end)

		local function test_missing_emission_time_is_rejected()
			local a = validArgs()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(a[1], a[2], a[3], a[4], a[5], nil, a[7])
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("missing-field")
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("emissionTime")
		end
		it("test_missing_emission_time_is_rejected", function()
			test_missing_emission_time_is_rejected()
		end)

		local function test_missing_attribution_chain_is_rejected()
			local a = validArgs()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(a[1], a[2], a[3], a[4], nil, a[6], a[7])
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("missing-field")
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("attributionChain")
		end
		it("test_missing_attribution_chain_is_rejected", function()
			test_missing_attribution_chain_is_rejected()
		end)

		-- ====================================================================
		-- H.3 -- initialMagnitude <= 0 rejected, regardless of other fields being valid.
		-- ====================================================================
		local function test_magnitude_zero_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("non-positive-magnitude")
		end
		it("test_magnitude_zero_is_rejected", function()
			test_magnitude_zero_is_rejected()
		end)

		-- Edge case (AC-H.3): -0.0001 also rejected.
		local function test_magnitude_small_negative_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				-0.0001,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("non-positive-magnitude")
		end
		it("test_magnitude_small_negative_is_rejected", function()
			test_magnitude_small_negative_is_rejected()
		end)

		-- Edge case (AC-H.3): 0.0001 (just above zero) accepted.
		local function test_magnitude_small_positive_is_accepted()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0.0001,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(rejection).to.equal(nil)
			expect(payload).never.to.equal(nil)
		end
		it("test_magnitude_small_positive_is_accepted", function()
			test_magnitude_small_positive_is_accepted()
		end)

		-- ====================================================================
		-- H.3b -- 5 SEPARATE invocations, each violating exactly one of {NaN position,
		-- +Inf position, -Inf position, NaN magnitude, +Inf magnitude}: each independently
		-- rejected, error records sourcePlayerId, emissionType, and offending axis. A single
		-- payload violating all 5 at once must NOT substitute for these 5 separate assertions
		-- (short-circuit risk) -- each test below is a fully independent invocation.
		-- ====================================================================
		local function test_position_x_nan_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0 / 0, 0, 0),
				0.25,
				42,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			local r = rejection :: EmissionLogic.EmissionRejection
			expect(r.reason).to.equal("non-finite-value")
			expect(r.field).to.equal("position.X")
			expect(r.sourcePlayerId).to.equal(42)
			expect(r.emissionType).to.equal("Gather")
		end
		it("test_position_x_nan_is_rejected", function()
			test_position_x_nan_is_rejected()
		end)

		local function test_position_x_positive_infinity_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(math.huge, 0, 0),
				0.25,
				42,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			local r = rejection :: EmissionLogic.EmissionRejection
			expect(r.reason).to.equal("non-finite-value")
			expect(r.field).to.equal("position.X")
			expect(r.sourcePlayerId).to.equal(42)
			expect(r.emissionType).to.equal("Gather")
		end
		it("test_position_x_positive_infinity_is_rejected", function()
			test_position_x_positive_infinity_is_rejected()
		end)

		local function test_position_x_negative_infinity_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(-math.huge, 0, 0),
				0.25,
				42,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			local r = rejection :: EmissionLogic.EmissionRejection
			expect(r.reason).to.equal("non-finite-value")
			expect(r.field).to.equal("position.X")
			expect(r.sourcePlayerId).to.equal(42)
			expect(r.emissionType).to.equal("Gather")
		end
		it("test_position_x_negative_infinity_is_rejected", function()
			test_position_x_negative_infinity_is_rejected()
		end)

		local function test_magnitude_nan_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0 / 0,
				42,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			local r = rejection :: EmissionLogic.EmissionRejection
			expect(r.reason).to.equal("non-finite-value")
			expect(r.field).to.equal("initialMagnitude")
			expect(r.sourcePlayerId).to.equal(42)
			expect(r.emissionType).to.equal("Gather")
		end
		it("test_magnitude_nan_is_rejected", function()
			test_magnitude_nan_is_rejected()
		end)

		local function test_magnitude_positive_infinity_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				math.huge,
				42,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			local r = rejection :: EmissionLogic.EmissionRejection
			expect(r.reason).to.equal("non-finite-value")
			expect(r.field).to.equal("initialMagnitude")
			expect(r.sourcePlayerId).to.equal(42)
			expect(r.emissionType).to.equal("Gather")
		end
		it("test_magnitude_positive_infinity_is_rejected", function()
			test_magnitude_positive_infinity_is_rejected()
		end)

		-- Bonus (non-blocking) coverage beyond the required 5: confirms the per-axis isFinite
		-- check also independently catches Y and Z, not only X (the required 5 cases above
		-- only exercise the X axis, per the AC's own "position.X/Y/Z is (a)/(b)/(c)" wording).
		local function test_position_y_positive_infinity_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, math.huge, 0),
				0.25,
				42,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("position.Y")
		end
		it("test_position_y_positive_infinity_is_rejected", function()
			test_position_y_positive_infinity_is_rejected()
		end)

		local function test_position_z_negative_infinity_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, -math.huge),
				0.25,
				42,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).field).to.equal("position.Z")
		end
		it("test_position_z_negative_infinity_is_rejected", function()
			test_position_z_negative_infinity_is_rejected()
		end)

		-- ====================================================================
		-- H.3c -- emissionType not in the canonical enum is rejected. Case-sensitive: lowercase
		-- "gather" is also rejected (exact-string-match enum).
		-- ====================================================================
		local function test_unrecognized_emission_type_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Explosion",
				Vector3.new(0, 0, 0),
				0.25,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("invalid-emission-type")
		end
		it("test_unrecognized_emission_type_is_rejected", function()
			test_unrecognized_emission_type_is_rejected()
		end)

		local function test_lowercase_gather_is_rejected_case_sensitive()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"gather",
				Vector3.new(0, 0, 0),
				0.25,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("invalid-emission-type")
		end
		it("test_lowercase_gather_is_rejected_case_sensitive", function()
			test_lowercase_gather_is_rejected_case_sensitive()
		end)

		-- ====================================================================
		-- H.6 -- Beacon emission with initialMagnitude below 0.85 is rejected (values below
		-- 0.85 reserved exclusively for non-Beacon types). Boundary explicitly tested at both
		-- 0.849 (still below -> rejected for Beacon) and 0.850 (exactly at boundary ->
		-- accepted for Beacon, per this story's resolved reading of "values ABOVE 0.85 are
		-- reserved for Beacon": 0.85 itself is the SHARED boundary, legal for both sides).
		-- ====================================================================
		local function test_beacon_magnitude_0_80_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Beacon",
				Vector3.new(0, 0, 0),
				0.80,
				1,
				{ "BeaconPlaced" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("beacon-below-reserved-band")
		end
		it("test_beacon_magnitude_0_80_is_rejected", function()
			test_beacon_magnitude_0_80_is_rejected()
		end)

		local function test_beacon_magnitude_0_849_is_rejected_below_boundary()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Beacon",
				Vector3.new(0, 0, 0),
				0.849,
				1,
				{ "BeaconPlaced" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("beacon-below-reserved-band")
		end
		it("test_beacon_magnitude_0_849_is_rejected_below_boundary", function()
			test_beacon_magnitude_0_849_is_rejected_below_boundary()
		end)

		local function test_beacon_magnitude_0_850_is_accepted_at_shared_boundary()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Beacon",
				Vector3.new(0, 0, 0),
				0.850,
				1,
				{ "BeaconPlaced" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(rejection).to.equal(nil)
			expect(payload).never.to.equal(nil)
		end
		it("test_beacon_magnitude_0_850_is_accepted_at_shared_boundary", function()
			test_beacon_magnitude_0_850_is_accepted_at_shared_boundary()
		end)

		-- ====================================================================
		-- H.6b -- non-Beacon emission with initialMagnitude > 0.85 is rejected (reverse-
		-- direction check of H.6). 0.850 itself (the shared boundary) is accepted for
		-- non-Beacon types too.
		-- ====================================================================
		local function test_non_beacon_magnitude_0_90_is_rejected()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0.90,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("non-beacon-above-reserved-band")
		end
		it("test_non_beacon_magnitude_0_90_is_rejected", function()
			test_non_beacon_magnitude_0_90_is_rejected()
		end)

		local function test_non_beacon_magnitude_0_850_is_accepted_at_shared_boundary()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0.850,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(rejection).to.equal(nil)
			expect(payload).never.to.equal(nil)
		end
		it("test_non_beacon_magnitude_0_850_is_accepted_at_shared_boundary", function()
			test_non_beacon_magnitude_0_850_is_accepted_at_shared_boundary()
		end)

		-- Bonus (non-blocking): symmetric just-above-boundary check, mirroring H.6's 0.849 case.
		local function test_non_beacon_magnitude_0_851_is_rejected_just_above_boundary()
			local payload, rejection = EmissionLogic.ValidateAndBuildEmission(
				"Gather",
				Vector3.new(0, 0, 0),
				0.851,
				1,
				{ "GatherWood" },
				SAMPLE_NOW,
				SAMPLE_EMISSION_ID
			)
			expect(payload).to.equal(nil)
			expect((rejection :: EmissionLogic.EmissionRejection).reason).to.equal("non-beacon-above-reserved-band")
		end
		it("test_non_beacon_magnitude_0_851_is_rejected_just_above_boundary", function()
			test_non_beacon_magnitude_0_851_is_rejected_just_above_boundary()
		end)
	end)

	describe("DisturbanceService.luau -- Story 002 static/structural source checks (H.7b, no-client-path)", function()
		-- These are STATIC checks against the actual .luau source text, not runtime behavioral
		-- tests -- see this file's header comment for why DisturbanceService.luau cannot yet be
		-- instantiated in this test harness (Knit is not vendored under
		-- ReplicatedStorage.Packages).
		local disturbanceServiceSource: string? = nil
		local emissionLogicSource: string? = nil

		-- Strips Lua/Luau single-line comments (everything from `--` to end of line) from each
		-- line before the static checks below run. WHY: this file's own doc comments (and this
		-- story's production-code doc comments) legitimately QUOTE the exact forbidden/required
		-- call syntax they're describing (e.g. "the sampled workspace:GetServerTimeNow() value"
		-- inside a header comment) -- a naive whole-source grep false-positives on prose that
		-- merely mentions an API, not code that calls it. This is the same false-positive class
		-- the Story 001 precedent's own DataStoreService check already hit and documented; here
		-- it's fixed via comment-stripping (reusable across every check below) rather than
		-- rewording every doc comment to dodge its own subject matter.
		--
		-- CAVEAT (found + fixed during code review): this is a naive first-`--`-match strip, NOT
		-- quote-aware -- it WOULD wrongly truncate a line whose string-literal content contains
		-- `--` before any of the checked tokens. DisturbanceService.luau's Emit()-rejection
		-- warn() message originally used `--` as a visual separator inside its own format string,
		-- which this exact bug would have silently mis-stripped; fixed by rewording that message
		-- to use `:` instead. No known `--`-in-string-literal remains in either source file this
		-- checks today, but this stripper does NOT structurally guarantee that going forward --
		-- a future string literal containing `--` before a checked token would silently reintroduce
		-- this risk. Harden with real quote-tracking if this pattern gets reused for more files.
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

		local function loadEmissionLogicSource(): string
			if not emissionLogicSource then
				emissionLogicSource =
					stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceServiceEmissionLogic.luau"))
			end
			return emissionLogicSource :: string
		end

		-- ====================================================================
		-- H.7b -- os.time()/tick()/os.clock() are forbidden anywhere on the Emit() path;
		-- workspace:GetServerTimeNow() is the sole permitted clock source. All checks below run
		-- against COMMENT-STRIPPED source (see stripLuaComments above) so they assert real code
		-- usage, not doc-comment prose.
		-- ====================================================================
		local function test_emission_logic_module_never_touches_any_clock_api()
			-- The pure logic module doesn't even call the PERMITTED clock API -- it receives
			-- `now` as an injected parameter -- so none of the four APIs should appear as a
			-- call anywhere in this file's actual code.
			local source = loadEmissionLogicSource()
			expect(source:find("os%.time%(")).to.equal(nil)
			expect(source:find("tick%(")).to.equal(nil)
			expect(source:find("os%.clock%(")).to.equal(nil)
			expect(source:find("GetServerTimeNow%(")).to.equal(nil)
		end
		it("test_emission_logic_module_never_touches_any_clock_api", function()
			test_emission_logic_module_never_touches_any_clock_api()
		end)

		local function test_disturbance_service_never_calls_forbidden_clock_apis()
			local source = loadServiceSource()
			expect(source:find("os%.time%(")).to.equal(nil)
			expect(source:find("tick%(")).to.equal(nil)
			expect(source:find("os%.clock%(")).to.equal(nil)
		end
		it("test_disturbance_service_never_calls_forbidden_clock_apis", function()
			test_disturbance_service_never_calls_forbidden_clock_apis()
		end)

		local function test_disturbance_service_emit_uses_get_server_time_now()
			local source = loadServiceSource()
			expect(source:find("workspace:GetServerTimeNow%(%)")).never.to.equal(nil)
		end
		it("test_disturbance_service_emit_uses_get_server_time_now", function()
			test_disturbance_service_emit_uses_get_server_time_now()
		end)

		local function test_disturbance_service_emit_uses_http_service_generate_guid()
			local source = loadServiceSource()
			expect(source:find('HttpService:GenerateGUID%(false%)')).never.to.equal(nil)
		end
		it("test_disturbance_service_emit_uses_http_service_generate_guid", function()
			test_disturbance_service_emit_uses_http_service_generate_guid()
		end)

		-- ====================================================================
		-- No client-reachable path calls Emit(), directly or indirectly (structural
		-- precondition for Story 016's H.39/H.39d lint).
		-- ====================================================================
		local function test_client_table_remains_empty_no_emit_exposed_to_clients()
			local source = loadServiceSource()
			-- The Client table is declared once, as a literal empty table, and never appended
			-- to elsewhere in the file.
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it("test_client_table_remains_empty_no_emit_exposed_to_clients", function()
			test_client_table_remains_empty_no_emit_exposed_to_clients()
		end)

		local function test_no_remote_or_bindable_wiring_present_in_source()
			local source = loadServiceSource()
			expect(source:find("RemoteEvent")).to.equal(nil)
			expect(source:find("RemoteFunction")).to.equal(nil)
			-- BindableEvent legitimately appears once, for the unrelated OnPlayerDied channel
			-- (Story 001/ADR-0004) -- confirm it is NOT wired to fire or call Emit.
			expect(source:find("OnServerEvent")).to.equal(nil)
			expect(source:find("OnServerInvoke")).to.equal(nil)
		end
		it("test_no_remote_or_bindable_wiring_present_in_source", function()
			test_no_remote_or_bindable_wiring_present_in_source()
		end)
	end)
end
