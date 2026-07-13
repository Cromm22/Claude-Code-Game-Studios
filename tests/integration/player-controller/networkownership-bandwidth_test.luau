--!strict
-- networkownership-bandwidth_test
--
-- TestEZ integration tests for Story 011: NetworkOwnership & Character
-- Replication Bandwidth.
-- Story: production/epics/player-controller/story-011-networkownership-bandwidth.md
-- GDD: design/gdd/player-controller.md (state table S1/S2/S3a/S3b, C.9)
-- ADR: docs/architecture/adr-0008-character-replication-bandwidth-networkownership.md
--      (NetworkOwnership strategy: player characters retain default automatic
--      ownership; no SetNetworkOwner call for them)
--      docs/architecture/adr-0011-player-controller-sprint-stamina-authority.md
--      (S1/S2 locomotion transitions, Humanoid.WalkSpeed server authority)
--
-- Story Type: Integration. Per this story's own Implementation Notes, the
-- ENTIRE NetworkOwnership "implementation" for player characters is the
-- ABSENCE of a SetNetworkOwner call -- Roblox's default automatic ownership
-- is what's wanted. There is no new production code for this story. This
-- file is a static/structural AUDIT against the real, already-implemented
-- Story 001/ADR-0008 code paths, not a test of new logic.
--
-- H.28 (CPU budget) and H.29 (bandwidth budget) require live Roblox Studio
-- profiling (debug.profilebegin/profileend, real RemoteEvent traffic
-- sampling over a real Heartbeat scheduler) that CANNOT be executed under
-- the headless Lune harness -- there is no live server, no real network
-- stack, no real Heartbeat scheduler under test. Per this story's own Out of
-- Scope section, the empirical baseline measurement itself belongs to the
-- `/prototype predator-ai` spike, not this story. Both are marked DEFERRED
-- via pending(...), matching the established precedent in
-- tests/unit/player-controller/sprint-stamina-authority_test.luau (H.26) and
-- tests/unit/player-controller/disturbance-emission-publisher_test.luau
-- (H.32) -- NOT fabricated as automated passes.
--
-- This file loads NO new module into tests/run_tests.lua's mount list --
-- every check here is a static/structural fs.readFile(...) source-text
-- check against the real production files, same pattern as the
-- "PlayerControllerService -- Story 003 (Emit call-site structural checks,
-- H.15)" describe() block in disturbance-emission-publisher_test.luau.

local fs = require("@lune/fs")

-- PC's full current file surface (all PlayerController*-owned production
-- files). Deliberately hardcoded and SCOPED TO PC, not a recursive scan of
-- all of src/ -- Predator AI's own future `SetNetworkOwner(nil)` call for
-- the predator NPC (Out of Scope for this story; see ADR-0008 Decision
-- section, "Predator NPC: explicit server NetworkOwnership") is a LEGITIMATE
-- call in a different epic's file and must not fail this suite once that
-- epic lands. Scoping the audit to PC's own files keeps this test durable
-- across that future addition.
local PC_SOURCE_FILES = {
	"src/gameplay/services/PlayerControllerService.luau",
	"src/gameplay/services/PlayerControllerLanternLogic.luau",
	"src/gameplay/services/PlayerControllerLocomotionStaminaLogic.luau",
	"src/gameplay/services/PlayerControllerEmissionPublisherLogic.luau",
}

-- Strips Lua/Luau single-line comments before the WalkSpeed/position checks
-- below run, so a doc comment that merely MENTIONS "Humanoid.WalkSpeed" or
-- "rootPart.Position" in prose doesn't false-positive a check looking for
-- real code. Same naive first-`--`-match implementation (and the same
-- documented quote-awareness caveat -- a `--` inside a string literal, e.g.
-- a warn() message, truncates the source early) as the established
-- precedent in tests/unit/ecological-disturbance/emission-schema-server-emit
-- -intake_test.luau and tests/unit/player-controller/disturbance-emission
-- -publisher_test.luau. Verified against PlayerControllerService.luau: none
-- of its string literals contain "--", so this naive strip is safe for this
-- file as of this story.
local function stripLuaComments(source: string): string
	local strippedLines = {}
	for line in (source .. "\n"):gmatch("([^\n]*)\n") do
		local codeOnly = line:match("^(.-)%-%-") or line
		table.insert(strippedLines, codeOnly)
	end
	return table.concat(strippedLines, "\n")
end

local serviceSource: string? = nil
local function loadServiceSource(): string
	if not serviceSource then
		serviceSource = stripLuaComments(fs.readFile("src/gameplay/services/PlayerControllerService.luau"))
	end
	return serviceSource :: string
end

return function()
	-- ==========================================================================
	-- NetworkOwnership confirmation (story AC, no dedicated H.x) -- ADR-0008 /
	-- TR-pc-047: player characters retain Roblox's default automatic
	-- NetworkOwnership. The entirety of this requirement's implementation is
	-- the ABSENCE of a SetNetworkOwner call anywhere in PC's own code.
	-- ==========================================================================
	describe("NetworkOwnership -- default automatic ownership retained (ADR-0008, TR-pc-047)", function()
		local function test_zero_setnetworkowner_calls_in_player_controller_files()
			for _, path in PC_SOURCE_FILES do
				local ok, source = pcall(function()
					return fs.readFile(path)
				end)
				expect(ok).to.equal(true)
				expect((source :: string):find("SetNetworkOwner")).to.equal(nil)
			end
		end
		it("test_zero_setnetworkowner_calls_in_player_controller_files", function()
			test_zero_setnetworkowner_calls_in_player_controller_files()
		end)
	end)

	-- ==========================================================================
	-- Humanoid.WalkSpeed server-authority (story AC edge case, ADR-0008 /
	-- TR-pc-047: "server-authoritative WalkSpeed" holds regardless of
	-- NetworkOwnership). Per the GDD's own state table (design/gdd/
	-- player-controller.md: S1/S2 = Locomotion axis, WalkSpeed-bearing; S3a/S3b
	-- = Lantern axis, orthogonal, no WalkSpeed value), WalkSpeed is a pure
	-- function of the locomotion axis only -- these checks confirm (a) it is
	-- set server-side at spawn, (b) it is set server-side on every real
	-- locomotion transition (both accepted S1<->S2 toggles AND forced reverts,
	-- since both converge on the same _applyLocomotionTransition call site per
	-- that function's own doc comment), and (c) the lantern-axis (S3a/S3b)
	-- transition handler correctly never independently touches WalkSpeed --
	-- confirming H.25's orthogonal-axis invariant holds for this
	-- NetworkOwnership-adjacent guarantee too, not just for gameplay-outcome
	-- state.
	-- ==========================================================================
	describe("Humanoid.WalkSpeed server authority across S1/S2/S3a/S3b (ADR-0008, TR-pc-047)", function()
		local function extractFunctionBody(source: string, startPattern: string, endPattern: string): string
			local startIdx = source:find(startPattern)
			expect(startIdx).never.to.equal(nil)
			local endIdx = source:find(endPattern, startIdx :: number)
			expect(endIdx).never.to.equal(nil)
			return source:sub(startIdx :: number, (endIdx :: number) - 1)
		end

		local function test_walkspeed_set_serverside_at_spawn()
			local source = loadServiceSource()
			local spawnBody = extractFunctionBody(
				source,
				"function PlayerControllerService:_wireCharacterSetup%(",
				-- Story 007 (pc-7): pc-1/pc-2's `_isAliveAndEligible` stub was
				-- renamed to its real ADR-0012 name, `_isEligibleForGameplayEvents`,
				-- in the SAME file position (immediately after
				-- `_wireCharacterSetup`) -- this boundary pattern updated in
				-- lockstep, a legitimate pin update per pc-7's own report.
				"function PlayerControllerService:_isEligibleForGameplayEvents%("
			)
			expect(spawnBody:find("humanoid%.WalkSpeed = LocomotionStaminaLogic%.GetMoveSpeed%(")).never.to.equal(nil)
		end
		it("test_walkspeed_set_serverside_at_spawn", function()
			test_walkspeed_set_serverside_at_spawn()
		end)

		local function test_walkspeed_set_serverside_on_every_locomotion_transition_accepted_and_forced()
			local source = loadServiceSource()
			local transitionBody = extractFunctionBody(
				source,
				"function PlayerControllerService:_applyLocomotionTransition%(",
				"function PlayerControllerService:_maybePushStaminaChanged%("
			)
			expect(transitionBody:find("humanoid%.WalkSpeed = LocomotionStaminaLogic%.GetMoveSpeed%("))
				.never.to.equal(nil)

			-- _applyLocomotionTransition is the SAME call site for both an
			-- accepted RequestSprintToggle (T1/T2) and every forced-revert path
			-- (stamina exhaustion, ghost-sprint timeout) -- confirm both call
			-- sites reach it (extracted by function body, not a fragile
			-- end-of-line pattern), so this one WalkSpeed write genuinely
			-- covers every real S1<->S2 transition, not just the
			-- voluntary-toggle path.
			local acceptedToggleBody = extractFunctionBody(
				source,
				"function PlayerControllerService:_handleSprintToggleRequest%(",
				"function PlayerControllerService:_handlePlayerHeartbeat%("
			)
			expect(acceptedToggleBody:find("self:_applyLocomotionTransition%(")).never.to.equal(nil) -- accepted-toggle call site

			local forcedRevertBody = extractFunctionBody(
				source,
				"function PlayerControllerService:_onLocomotionHeartbeat%(",
				"function PlayerControllerService:_applyLocomotionTransition%("
			)
			expect(forcedRevertBody:find("self:_applyLocomotionTransition%(")).never.to.equal(nil) -- forced-revert call site
		end
		it(
			"test_walkspeed_set_serverside_on_every_locomotion_transition_accepted_and_forced",
			function()
				test_walkspeed_set_serverside_on_every_locomotion_transition_accepted_and_forced()
			end
		)

		local function test_walkspeed_write_site_count_is_exactly_two()
			-- Story 007 (pc-7) pin update: was exactly 2 write sites (spawn +
			-- the shared locomotion-transition function) -- pc-7 legitimately
			-- added a THIRD, `_exitToAliveRenderScope` (the T6/ADR-0012 restore
			-- site, "restore at T6" per that story's own binding rules), so the
			-- audited count is now 3. Still guards against a future stray/
			-- duplicate WalkSpeed assignment being added outside these three
			-- audited, server-only call sites.
			local source = loadServiceSource()
			local count = 0
			for _ in source:gmatch("humanoid%.WalkSpeed = LocomotionStaminaLogic%.GetMoveSpeed%(") do
				count += 1
			end
			expect(count).to.equal(3)
		end
		it("test_walkspeed_write_site_count_is_exactly_two", function()
			test_walkspeed_write_site_count_is_exactly_two()
		end)

		local function test_lantern_axis_transition_never_independently_touches_walkspeed()
			local source = loadServiceSource()
			local lanternBody = extractFunctionBody(
				source,
				"function PlayerControllerService:_applyLightAxisTransition%(",
				"function PlayerControllerService:BeginGatherHold%("
			)
			-- S3a/S3b is the Lantern axis (orthogonal to Locomotion, per the
			-- GDD's own state table) -- it must NEVER independently write
			-- WalkSpeed. This is intentional per H.25, not a gap: WalkSpeed is
			-- purely a function of the S1/S2 locomotion axis.
			expect(lanternBody:find("WalkSpeed")).to.equal(nil)
		end
		it(
			"test_lantern_axis_transition_never_independently_touches_walkspeed",
			function()
				test_lantern_axis_transition_never_independently_touches_walkspeed()
			end
		)
	end)

	-- ==========================================================================
	-- No client-predicted position ever enters a cross-system perception path
	-- (TR-pc-044: "server-tracked HumanoidRootPart.Position is PA's perception
	-- input; no client-predicted positions into perception"). PC's own default
	-- NetworkOwnership permits client-side physics simulation for movement
	-- FEEL, but every position this service reads for a gameplay-consequential
	-- purpose (disturbance emission position) must be the server-observed
	-- HumanoidRootPart.Position, never a client-supplied RemoteEvent argument.
	-- ==========================================================================
	describe("No client-predicted position forwarded into a perception/emission path (TR-pc-044)", function()
		local function test_position_reads_are_server_observed_only()
			local source = loadServiceSource()
			expect(source:find("function PlayerControllerService:_getServerPosition%(")).never.to.equal(nil)
			expect(source:find("rootPart%.Position")).never.to.equal(nil)

			-- _getServerPosition is the ONLY position source used by every
			-- emission/transition call site -- at least 3 call sites in this
			-- file (_applyLightAxisTransition, _applyLocomotionTransition,
			-- _onEmissionHeartbeat) route through it, never a RemoteEvent
			-- payload argument.
			local callSiteCount = 0
			for _ in source:gmatch("self:_getServerPosition%(player%)") do
				callSiteCount += 1
			end
			expect(callSiteCount >= 3).to.equal(true)
		end
		it("test_position_reads_are_server_observed_only", function()
			test_position_reads_are_server_observed_only()
		end)

		local function test_client_payload_variables_never_forwarded_as_a_position_argument()
			local source = loadServiceSource()
			-- RequestLanternToggle's payload (`raised`) and RequestSprintToggle's
			-- payload (`sprint`) are both validated as strictly boolean (step 4,
			-- ADR-0006) -- neither is ever forwarded into an Emit(...) call or a
			-- WalkSpeed assignment as a position-shaped argument anywhere in this
			-- file.
			expect(source:find('if typeof%(raised%) ~= "boolean" then')).never.to.equal(nil)
			expect(source:find('if typeof%(sprint%) ~= "boolean" then')).never.to.equal(nil)
			expect(source:find("self%._disturbanceService:Emit%(.-raised,.-%)")).to.equal(nil)
			expect(source:find("self%._disturbanceService:Emit%(.-sprint,.-%)")).to.equal(nil)
			expect(source:find("WalkSpeed = raised")).to.equal(nil)
			expect(source:find("WalkSpeed = sprint")).to.equal(nil)
		end
		it(
			"test_client_payload_variables_never_forwarded_as_a_position_argument",
			function()
				test_client_payload_variables_never_forwarded_as_a_position_argument()
			end
		)
	end)

	-- ==========================================================================
	-- H.28 / H.29 -- DEFERRED. Both require live Roblox Studio profiling
	-- (debug.profilebegin/profileend, real RemoteEvent traffic sampling) over a
	-- real 4-player server with a real Heartbeat scheduler and a real network
	-- stack -- none of which exist under the headless Lune/TestEZ harness. Per
	-- this story's own Out of Scope section, "The actual empirical baseline
	-- measurement itself -- that is the /prototype predator-ai spike's
	-- deliverable, a separate pre-production task, not a PC story." Not
	-- automated here, and not fabricated as a pass -- same honest-gap pattern
	-- already established by pc-1's H.26 and pc-3's H.32.
	-- ==========================================================================
	describe("H.28 / H.29 -- CPU and bandwidth budgets (DEFERRED to /prototype predator-ai spike)", function()
		local function test_H28_cpu_budget_DEFERRED_requires_live_studio_profiling()
			pending(
				"H.28 (CPU budget: debug.profilebegin/profileend over a live 4-player, 300-tick Heartbeat schedule with an injected RM reconciliation fault) requires a live Roblox Studio server and a real RunService.Heartbeat scheduler -- neither exists under the headless Lune/TestEZ harness. DEFERRED to the /prototype predator-ai spike per this story's own Out of Scope section."
			)
		end
		it("test_H28_cpu_budget_DEFERRED_requires_live_studio_profiling", function()
			test_H28_cpu_budget_DEFERRED_requires_live_studio_profiling()
		end)

		local function test_H29_bandwidth_budget_DEFERRED_requires_live_studio_profiling()
			pending(
				"H.29 (bandwidth budget: sampling real outbound RemoteEvent traffic over 60 frames for a live 4-player steady-state sprint) requires a live Roblox Studio server and a real network transport -- neither exists under the headless Lune/TestEZ harness. DEFERRED to the /prototype predator-ai spike per this story's own Out of Scope section and ADR-0008's Validation Criteria."
			)
		end
		it("test_H29_bandwidth_budget_DEFERRED_requires_live_studio_profiling", function()
			test_H29_bandwidth_budget_DEFERRED_requires_live_studio_profiling()
		end)
	end)
end
