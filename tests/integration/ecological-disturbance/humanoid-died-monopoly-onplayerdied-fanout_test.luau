--!strict
-- humanoid-died-monopoly-onplayerdied-fanout_test
--
-- Integration tests for Story 010: Humanoid.Died Monopoly & OnPlayerDied Fan-out.
-- Story: production/epics/ecological-disturbance/story-010-humanoid-died-monopoly-onplayerdied-fanout.md
-- ADR: docs/architecture/adr-0001-knit-lifecycle-ordering-discipline.md (Rule 1 -- "KnitInit
--      builds, KnitStart connects")
--      docs/architecture/adr-0004-disturbanceservice-core-architecture.md (Humanoid.Died sole
--      subscription, OnPlayerDied raw-BindableEvent channel-type Decision, N10 pre-dispatch
--      snapshot)
--      docs/architecture/adr-0005-death-respawn-lifecycle.md (fan-out to exactly 3 consumers;
--      the Humanoid.Died idempotent guard is EACH CONSUMER's own responsibility, not ED's)
--
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceDeathFanoutLogic.luau -- the REAL, pure
--     BuildDeathPayload function (step 5b), exercised directly AND via the FakeDisturbanceService
--     harness below, unmodified in both cases.
--   src/gameplay/services/DisturbanceService.luau -- verified via STATIC/structural source-text
--     checks (sole-subscriber monopoly, KnitInit placement, yield-free body, server-internal-only
--     surface) -- Knit is not vendored under ReplicatedStorage.Packages in this harness, so a
--     live DisturbanceService instance (and real Player/Humanoid/Character instances) cannot be
--     constructed here, matching every prior ED integration test's own documented precedent.
--
-- MOCK BINDABLE EVENT DISCLOSURE (identical in spirit to tier-crossed-signal-subscription_test
-- .luau's own MockSignal disclosure): "MockBindableEvent" below is a small, honest in-test
-- stand-in for a real Roblox BindableEvent, NOT the real thing -- it exists solely to give this
-- story's behavioral harness something real to Connect()/Fire() against, with the exact semantics
-- OnPlayerDied's contract requires: multiple independent subscribers, delivery order-independent
-- of connection order, a Disconnect() handle, and synchronous (same-Luau-frame, no yield)
-- dispatch. The REAL production channel is a raw `Instance.new("BindableEvent")` (not this Mock,
-- and not a Knit Signal -- see the static checks below), whose real synchronous-dispatch
-- guarantee depends on the `Workspace.SignalBehavior = Enum.SignalBehavior.Immediate` boot-time
-- pin (ADR-0004) -- that pin's own wiring is out of this story's scope (Story 001 / ServerInit
-- .server.luau / ServerBootstrap.luau, already confirmed correct per this story's own task
-- description).
--
-- Story Type: Integration -- coding-standards.md's bar is an automated integration test that must
-- pass (BLOCKING gate), placed under tests/integration/ since this exercises the sole-subscriber
-- MONOPOLY and the fan-out CONTRACT across simulated subscribers, not a single pure-logic formula
-- alone (though the pure DeathFanoutLogic.BuildDeathPayload formula is also directly exercised
-- below, folded into this same file per this epic's own established file-count precedent -- e.g.
-- DisturbanceServiceBandCrossedLogic's pure tests folded into disturbance-band-crossed-signal_test
-- .luau).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local DeathFanoutLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceDeathFanoutLogic)

type DeathPayload = DeathFanoutLogic.DeathPayload

-- ============================================================================
-- MockBindableEvent -- see MOCK BINDABLE EVENT DISCLOSURE above. Array-based listener list;
-- Fire() walks a SNAPSHOT taken at fire-time (matches tier-crossed-signal-subscription_test.luau's
-- own MockSignal precedent exactly).
-- ============================================================================

type MockListener = { fn: (...any) -> (), connected: boolean }
type MockConnection = { Disconnect: (self: MockConnection) -> () }

local MockBindableEvent = {}
MockBindableEvent.__index = MockBindableEvent

function MockBindableEvent.new()
	return setmetatable({ _listeners = {} :: { MockListener } }, MockBindableEvent)
end

function MockBindableEvent:Connect(fn: (...any) -> ()): MockConnection
	local record: MockListener = { fn = fn, connected = true }
	table.insert(self._listeners, record)

	local connection = {}
	function connection.Disconnect()
		record.connected = false
	end
	return (connection :: any) :: MockConnection
end

function MockBindableEvent:Fire(...: any)
	local snapshot = table.clone(self._listeners)
	for _, record in snapshot do
		if record.connected then
			record.fn(...)
		end
	end
end

-- ============================================================================
-- FakeDisturbanceService -- mirrors DisturbanceService.luau's real KnitInit /
-- _captureDeathLockSnapshot / _onHumanoidDied / GetOnPlayerDiedSignal bodies method-for-method
-- (this story's own production deliverable), substituting MockBindableEvent for the real
-- (unvendored) Instance.new("BindableEvent"), an injectable `_now` for the real
-- workspace:GetServerTimeNow() clock sample (mirrors disturbance-band-crossed-signal_test.luau's
-- own _setNow precedent -- see DisturbanceService.luau's own NO _setTestClock SEAM note), and an
-- injectable `_captureFn` for the real _captureDeathLockSnapshot stub (the REAL production method
-- is hardcoded to always return false -- TODO(Story 011) -- this harness's version is injectable
-- so the payload-consistency AC can exercise the SNAPSHOT-BEFORE-LATER-MUTATION ordering guarantee
-- this story is actually responsible for, without waiting on Story 011's not-yet-built
-- predator-lock registry). Reuses the real, already-unit-coverable
-- DisturbanceServiceDeathFanoutLogic.BuildDeathPayload UNMODIFIED.
-- ============================================================================

local FakeDisturbanceService = {}
FakeDisturbanceService.__index = FakeDisturbanceService

function FakeDisturbanceService.new()
	return setmetatable({}, FakeDisturbanceService)
end

--- Mirrors DisturbanceService.luau's real KnitInit body exactly (the Story 010 slice of it):
--- self._deathLockSnapshot starts empty, self._onPlayerDied is constructed via (mock)
--- BindableEvent -- never deferred to KnitStart.
function FakeDisturbanceService:KnitInit()
	self._deathLockSnapshot = {} :: { [any]: boolean }
	self._onPlayerDied = MockBindableEvent.new()
	self._now = 0
	self._captureFn = function(_deadPlayer: any): boolean
		return false
	end
end

--- Test-only setup helpers (this harness's stand-in for the real workspace:GetServerTimeNow()
--- clock read and the real, currently-hardcoded self:_captureDeathLockSnapshot stub).
function FakeDisturbanceService:_setNow(now: number)
	self._now = now
end

function FakeDisturbanceService:_setCaptureDeathLockSnapshotFn(fn: (any) -> boolean)
	self._captureFn = fn
end

--- Mirrors DisturbanceService.luau's real _captureDeathLockSnapshot method's SHAPE exactly (a
--- plain colon method, called as `self:_captureDeathLockSnapshot(deadPlayer)` at the (5a) call
--- site below) -- the real production method is hardcoded to always return false (TODO(Story
--- 011)); this harness's version delegates to the injectable `_captureFn` above.
function FakeDisturbanceService:_captureDeathLockSnapshot(deadPlayer: any): boolean
	return self._captureFn(deadPlayer)
end

--- Mirrors DisturbanceService.luau's real GetOnPlayerDiedSignal body exactly: bare
--- `return self._onPlayerDied`, same instance every call.
function FakeDisturbanceService:GetOnPlayerDiedSignal()
	return self._onPlayerDied
end

--- Mirrors DisturbanceService.luau's real _onHumanoidDied body exactly: (5a) snapshot capture ->
--- write to self._deathLockSnapshot, (5b) payload construction AFTER the snapshot (via the REAL
--- DeathFanoutLogic.BuildDeathPayload, unmodified), (5c) fire -- SYNCHRONOUSLY, within this single
--- Luau call (no task.wait/task.spawn/yield anywhere). No dedup at this layer (REQUIRED): calling
--- this twice for the same deadPlayer produces two independently-correct fires.
function FakeDisturbanceService:_onHumanoidDied(deadPlayer: any)
	-- (5a)
	local wasLocked = self:_captureDeathLockSnapshot(deadPlayer)
	self._deathLockSnapshot[deadPlayer] = wasLocked

	-- (5b) -- payload constructed AFTER the snapshot capture.
	local now = self._now
	local payload = DeathFanoutLogic.BuildDeathPayload(deadPlayer, wasLocked, now)

	-- (5c)
	self._onPlayerDied:Fire(payload)
end

-- ============================================================================
-- MockConsumer -- a mock "subscriber service" simulating its own KnitStart phase, exactly as
-- tier-crossed-signal-subscription_test.luau's own MockPredatorAI does: constructed
-- independently, connects to GetOnPlayerDiedSignal() during its own simulated KnitStart. Three
-- named instances below stand in for the story's own "exactly 3 consumers" documentation (Player
-- Controller, Crafting & Items, Predator AI) -- GetOnPlayerDiedSignal() itself supports an
-- arbitrary subscriber count; the fixed count of 3 is a cross-epic expectation, not a limit this
-- mechanism enforces (per the story's own Implementation Notes).
-- ============================================================================

local MockConsumer = {}
MockConsumer.__index = MockConsumer

function MockConsumer.new(name: string)
	return setmetatable({
		name = name,
		receivedCount = 0,
		receivedPayloads = {} :: { DeathPayload },
	}, MockConsumer)
end

function MockConsumer:KnitStart(disturbanceService)
	local consumer = self
	disturbanceService:GetOnPlayerDiedSignal():Connect(function(payload: DeathPayload)
		consumer.receivedCount += 1
		table.insert(consumer.receivedPayloads, payload)
	end)
end

function MockConsumer:lastPayload(): DeathPayload
	return self.receivedPayloads[#self.receivedPayloads]
end

return function()
	-- ============================================================================
	-- AC -- same-instance accessor.
	-- ============================================================================
	describe("DisturbanceService (Fake) -- Story 010 (GetOnPlayerDiedSignal construction/identity)", function()
		local function test_signal_non_nil_immediately_after_knit_init_before_any_knit_start()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local signal = service:GetOnPlayerDiedSignal()

			expect(signal).never.to.equal(nil)
		end
		it(
			"test_signal_non_nil_immediately_after_knit_init_before_any_knit_start",
			function()
				test_signal_non_nil_immediately_after_knit_init_before_any_knit_start()
			end
		)

		local function test_get_on_player_died_signal_returns_same_instance_every_call()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local first = service:GetOnPlayerDiedSignal()
			local second = service:GetOnPlayerDiedSignal()

			expect(first).to.equal(second)
		end
		it(
			"test_get_on_player_died_signal_returns_same_instance_every_call",
			function()
				test_get_on_player_died_signal_returns_same_instance_every_call()
			end
		)
	end)

	-- ============================================================================
	-- AC -- 3-consumer fan-out, shuffled connection order, synchronous same-pass delivery.
	-- ============================================================================
	describe("DisturbanceService (Fake) -- Story 010 (3-consumer fan-out, synchronous dispatch)", function()
		local function test_three_consumers_all_receive_the_same_death_fire_exactly_once()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local playerController = MockConsumer.new("PlayerController")
			local craftingItems = MockConsumer.new("CraftingItems")
			local predatorAI = MockConsumer.new("PredatorAI")

			-- Shuffled connection order -- mirrors tier-crossed-signal-subscription_test.luau's own
			-- shuffled-order precedent, proving delivery is order-independent.
			predatorAI:KnitStart(service)
			playerController:KnitStart(service)
			craftingItems:KnitStart(service)

			service:_setNow(100.0)
			service:_onHumanoidDied("player-A")

			expect(playerController.receivedCount).to.equal(1)
			expect(craftingItems.receivedCount).to.equal(1)
			expect(predatorAI.receivedCount).to.equal(1)

			expect(playerController:lastPayload().deadPlayer).to.equal("player-A")
			expect(playerController:lastPayload().deathTimestamp).to.equal(100.0)
			expect(playerController:lastPayload().predatorWasLockedAtDeath).to.equal(false)
		end
		it(
			"test_three_consumers_all_receive_the_same_death_fire_exactly_once",
			function()
				test_three_consumers_all_receive_the_same_death_fire_exactly_once()
			end
		)

		local function test_zero_subscribers_does_not_error()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local ok = pcall(function()
				service:_onHumanoidDied("player-solo")
			end)

			expect(ok).to.equal(true)
		end
		it("test_zero_subscribers_does_not_error", function()
			test_zero_subscribers_does_not_error()
		end)

		-- Runtime proof of TR-ed-052's "yield-free single-Luau-frame death path": the whole (5a)-
		-- (5c) sequence completes within the SAME coroutine resumption, with no internal yield
		-- point suspending it partway through.
		local function test_on_humanoid_died_runs_to_completion_within_the_same_resumption()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local co = coroutine.create(function()
				service:_onHumanoidDied("player-A")
			end)
			local ok = coroutine.resume(co)

			expect(ok).to.equal(true)
			-- "dead" = ran to completion in this SINGLE resume call -- if _onHumanoidDied yielded
			-- internally, the coroutine would still be "suspended" here instead.
			expect(coroutine.status(co)).to.equal("dead")
		end
		it(
			"test_on_humanoid_died_runs_to_completion_within_the_same_resumption",
			function()
				test_on_humanoid_died_runs_to_completion_within_the_same_resumption()
			end
		)
	end)

	-- ============================================================================
	-- AC -- double-fire fan-out, NO dedup at ED's layer (Humanoid.Died firing twice in a
	-- pathological replication race must fan out twice, each independently correct).
	-- ============================================================================
	describe("DisturbanceService (Fake) -- Story 010 (double-fire, no dedup at ED's layer)", function()
		local function test_humanoid_died_double_fire_fans_out_twice_each_independently_correct()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			local predatorAI = MockConsumer.new("PredatorAI")
			predatorAI:KnitStart(service)

			-- Each fire is wrapped in its OWN coroutine-completion check (code-review hardening):
			-- the AC's yield-free clause reads "on EACH fire, not just the first", so the second
			-- fire gets the same same-resumption runtime proof as the dedicated single-fire test
			-- above, not just the first.
			local function fireOnceYieldFree()
				local co = coroutine.create(function()
					service:_onHumanoidDied("player-A")
				end)
				local ok = coroutine.resume(co)
				expect(ok).to.equal(true)
				expect(coroutine.status(co)).to.equal("dead")
			end

			-- First fire: predator lock held at moment of death.
			service:_setCaptureDeathLockSnapshotFn(function(_deadPlayer: any): boolean
				return true
			end)
			service:_setNow(10.0)
			fireOnceYieldFree()

			-- Second fire (pathological double-fire, same life): lock has since been released.
			service:_setCaptureDeathLockSnapshotFn(function(_deadPlayer: any): boolean
				return false
			end)
			service:_setNow(10.05)
			fireOnceYieldFree()

			expect(predatorAI.receivedCount).to.equal(2)

			local firstPayload = predatorAI.receivedPayloads[1]
			local secondPayload = predatorAI.receivedPayloads[2]

			expect(firstPayload.deadPlayer).to.equal("player-A")
			expect(firstPayload.deathTimestamp).to.equal(10.0)
			expect(firstPayload.predatorWasLockedAtDeath).to.equal(true)

			expect(secondPayload.deadPlayer).to.equal("player-A")
			expect(secondPayload.deathTimestamp).to.equal(10.05)
			expect(secondPayload.predatorWasLockedAtDeath).to.equal(false)
		end
		it(
			"test_humanoid_died_double_fire_fans_out_twice_each_independently_correct",
			function()
				test_humanoid_died_double_fire_fans_out_twice_each_independently_correct()
			end
		)
	end)

	-- ============================================================================
	-- AC -- payload consistency: predatorWasLockedAtDeath matches the registry state AT THE
	-- MOMENT OF THE SNAPSHOT (5a), unaffected by a LATER mutation of the same registry state
	-- (proves snapshot-before-later-state semantics, the mechanism this story is responsible for
	-- -- Story 011's registry itself does not exist yet, per this story's own scope).
	-- ============================================================================
	describe("DisturbanceService (Fake) -- Story 010 (payload consistency -- snapshot BEFORE later mutation)", function()
		local function test_payload_reflects_snapshot_at_death_not_a_later_release()
			local service = FakeDisturbanceService.new()
			service:KnitInit()

			-- Lock is HELD at the moment of death.
			service:_setCaptureDeathLockSnapshotFn(function(_deadPlayer: any): boolean
				return true
			end)

			local capturedPayload: DeathPayload? = nil
			service:GetOnPlayerDiedSignal():Connect(function(payload: DeathPayload)
				capturedPayload = payload
			end)

			service:_onHumanoidDied("player-A")

			-- Simulate the lock being released MOMENTS AFTER death (e.g. Predator AI's own
			-- ReleasePredatorLock, out of this story's scope) -- this must NOT retroactively
			-- change the already-fired payload or the already-written snapshot.
			service:_setCaptureDeathLockSnapshotFn(function(_deadPlayer: any): boolean
				return false
			end)

			expect(service._deathLockSnapshot["player-A"]).to.equal(true)
			expect((capturedPayload :: DeathPayload).predatorWasLockedAtDeath).to.equal(true)
		end
		it(
			"test_payload_reflects_snapshot_at_death_not_a_later_release",
			function()
				test_payload_reflects_snapshot_at_death_not_a_later_release()
			end
		)
	end)

	-- ============================================================================
	-- Pure DisturbanceServiceDeathFanoutLogic.BuildDeathPayload -- direct tests (folded into this
	-- integration file per this epic's own established precedent -- e.g. Story 009's
	-- BandCrossedLogic pure tests folded into disturbance-band-crossed-signal_test.luau).
	-- ============================================================================
	describe("DisturbanceServiceDeathFanoutLogic -- Story 010 (pure BuildDeathPayload)", function()
		local function test_build_death_payload_returns_exact_three_fields()
			local payload = DeathFanoutLogic.BuildDeathPayload("player-A", false, 42.5)

			expect(payload.deadPlayer).to.equal("player-A")
			expect(payload.deathTimestamp).to.equal(42.5)
			expect(payload.predatorWasLockedAtDeath).to.equal(false)
		end
		it("test_build_death_payload_returns_exact_three_fields", function()
			test_build_death_payload_returns_exact_three_fields()
		end)

		local function test_build_death_payload_preserves_wasLocked_true()
			local payload = DeathFanoutLogic.BuildDeathPayload("player-B", true, 0.0)
			expect(payload.predatorWasLockedAtDeath).to.equal(true)
		end
		it("test_build_death_payload_preserves_wasLocked_true", function()
			test_build_death_payload_preserves_wasLocked_true()
		end)

		local function test_build_death_payload_preserves_player_identity_by_reference()
			-- Table-identity stand-in for a real Player instance: BuildDeathPayload must carry the
			-- SAME reference through, never a copy.
			local playerIdentity = { UserId = 7 }
			local payload = DeathFanoutLogic.BuildDeathPayload(playerIdentity, false, 1.0)
			expect(payload.deadPlayer).to.equal(playerIdentity)
		end
		it(
			"test_build_death_payload_preserves_player_identity_by_reference",
			function()
				test_build_death_payload_preserves_player_identity_by_reference()
			end
		)
	end)

	-- ============================================================================
	-- Static/structural source-text checks against the real DisturbanceService.luau -- see this
	-- file's header comment for why a live DisturbanceService instance cannot be constructed under
	-- this test harness. Mirrors disturbance-band-crossed-signal_test.luau's own
	-- "wiring, static Client-surface checks" describe block precedent (including its documented
	-- stripLuaComments `--`-in-string caveat).
	-- ============================================================================
	describe("DisturbanceService.luau -- Story 010 (wiring, static/structural checks)", function()
		-- Strips Lua/Luau single-line comments. CAVEAT (re-scoped per this story's code review --
		-- the earlier "safe against code-structure checks" framing overclaimed): a `--` inside a
		-- string literal truncates the line early at the FIRST `--`-like sequence, so ANY check
		-- that scans files this test does not control (the repo-wide monopoly grep below) has a
		-- FALSE-NEGATIVE gap -- a future `.Died:Connect(` sharing a line with, and positioned
		-- after, a string literal containing `--` would be stripped away and under-counted. This
		-- textual grep is therefore an early-warning check only; the HARD enforcement layer is
		-- Story 016's H.39e CI lint, which must be robust against this (and against the
		-- indirection evasions listed in this story's review: variable-held signal, bracket
		-- indexing, captured method reference, whitespace before `:Connect`). This is also why
		-- every message this test file itself writes uses `:`/`|` instead of `--`.
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local disturbanceServiceSource: string? = nil

		local function loadServiceSource(): string
			if not disturbanceServiceSource then
				disturbanceServiceSource = stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceService.luau"))
			end
			return disturbanceServiceSource :: string
		end

		-- Recursively collects every .luau file under `dir` -- used for the repo-wide
		-- sole-subscriber grep below.
		local function collectLuauFiles(dir: string, acc: { string })
			local ok, entries = pcall(function()
				return fs.readDir(dir)
			end)
			if not ok then
				return
			end
			for _, entry in entries do
				local path = dir .. "/" .. entry
				local meta = fs.metadata(path)
				if meta.kind == "dir" then
					collectLuauFiles(path, acc)
				elseif entry:match("%.luau$") then
					table.insert(acc, path)
				end
			end
		end

		-- Counts literal `.Died:Connect(` occurrences in `source` -- plain-text search (NOT a Lua
		-- pattern -- `.` here is a LITERAL dot, matching the real `humanoid.Died:Connect(` call
		-- site, whatever the local Humanoid variable happens to be named). A comment merely
		-- MENTIONING "Humanoid.Died" in prose (no trailing `:Connect(`) never matches this pattern
		-- regardless of comment-stripping, since the literal substring requires the actual
		-- method-call syntax to be present.
		local function countDiedConnectOccurrences(source: string): number
			local count = 0
			local searchStart = 1
			while true do
				local matchStart = source:find(".Died:Connect(", searchStart, true)
				if not matchStart then
					break
				end
				count += 1
				searchStart = matchStart + 1
			end
			return count
		end

		-- ====================================================================
		-- AC -- sole subscriber (TR-ed-032, security-critical): exactly ONE `.Died:Connect(` call
		-- anywhere in the entire src/ tree, and it lives in DisturbanceService.luau.
		-- ====================================================================
		local function test_humanoid_died_connect_subscribed_exactly_once_repo_wide()
			local luauFiles: { string } = {}
			collectLuauFiles("src", luauFiles)
			expect(#luauFiles > 0).to.equal(true) -- sanity: the walk actually found files

			local totalMatches = 0
			local matchingFiles: { string } = {}
			for _, path in luauFiles do
				local stripped = stripLuaComments(fs.readFile(path))
				local occurrences = countDiedConnectOccurrences(stripped)
				if occurrences > 0 then
					totalMatches += occurrences
					table.insert(matchingFiles, path)
				end
			end

			expect(totalMatches).to.equal(1)
			expect(#matchingFiles).to.equal(1)
			expect(matchingFiles[1]).to.equal("src/gameplay/services/DisturbanceService.luau")
		end
		it(
			"test_humanoid_died_connect_subscribed_exactly_once_repo_wide",
			function()
				test_humanoid_died_connect_subscribed_exactly_once_repo_wide()
			end
		)

		-- ====================================================================
		-- AC -- the sole `.Died:Connect(` call is registered inside KnitInit (not KnitStart), via
		-- the exact Players.PlayerAdded -> CharacterAdded -> Died:Connect nesting order the
		-- story's own Implementation Notes pin verbatim.
		-- ====================================================================
		local function test_humanoid_died_connect_registered_inside_knit_init_chain_order()
			local source = loadServiceSource()

			local knitInitStart = source:find("function DisturbanceService:KnitInit%(%)")
			local knitStartStart = source:find("function DisturbanceService:KnitStart%(%)")
			expect(knitInitStart).never.to.equal(nil)
			expect(knitStartStart).never.to.equal(nil)

			local playerAddedPos = source:find("Players%.PlayerAdded:Connect%(", knitInitStart)
			local characterAddedPos = source:find("CharacterAdded:Connect%(", knitInitStart)
			local diedConnectPos = source:find(".Died:Connect(", knitInitStart, true)

			expect(playerAddedPos).never.to.equal(nil)
			expect(characterAddedPos).never.to.equal(nil)
			expect(diedConnectPos).never.to.equal(nil)

			-- All three fall strictly within KnitInit's body -- before KnitStart begins.
			expect((playerAddedPos :: number) < knitStartStart).to.equal(true)
			expect((characterAddedPos :: number) < knitStartStart).to.equal(true)
			expect((diedConnectPos :: number) < knitStartStart).to.equal(true)

			-- Nesting order, textually in sequence: PlayerAdded -> CharacterAdded -> Died:Connect.
			expect((playerAddedPos :: number) < (characterAddedPos :: number)).to.equal(true)
			expect((characterAddedPos :: number) < (diedConnectPos :: number)).to.equal(true)
		end
		it(
			"test_humanoid_died_connect_registered_inside_knit_init_chain_order",
			function()
				test_humanoid_died_connect_registered_inside_knit_init_chain_order()
			end
		)

		-- ====================================================================
		-- AC -- OnPlayerDied stays a raw BindableEvent (GDD's own frozen C.1.11 closure /
		-- ADR-0004's dedicated Decision subsection) -- NOT a Knit Signal.
		-- ====================================================================
		local function test_on_player_died_is_a_raw_bindable_event_not_a_signal()
			local source = loadServiceSource()
			expect(source:find('self%._onPlayerDied = Instance%.new%("BindableEvent"%)')).never.to.equal(nil)
			expect(source:find("self%._onPlayerDied = Signal%.new%(%)")).to.equal(nil)
		end
		it(
			"test_on_player_died_is_a_raw_bindable_event_not_a_signal",
			function()
				test_on_player_died_is_a_raw_bindable_event_not_a_signal()
			end
		)

		-- ====================================================================
		-- AC -- self._deathLockSnapshot is constructed in KnitInit (not KnitStart), as an empty
		-- table literal.
		-- ====================================================================
		local function test_death_lock_snapshot_constructed_empty_in_knit_init()
			local source = loadServiceSource()
			local knitInitStart = source:find("function DisturbanceService:KnitInit%(%)")
			local knitStartStart = source:find("function DisturbanceService:KnitStart%(%)")

			local snapshotPos = source:find("self%._deathLockSnapshot = {} ::", knitInitStart)
			expect(snapshotPos).never.to.equal(nil)
			expect((snapshotPos :: number) < knitStartStart).to.equal(true)
		end
		it(
			"test_death_lock_snapshot_constructed_empty_in_knit_init",
			function()
				test_death_lock_snapshot_constructed_empty_in_knit_init()
			end
		)

		-- ====================================================================
		-- AC -- yield-free (5a)-(5c) sequence (TR-ed-052, REQUIRED): _onHumanoidDied's body
		-- contains zero yield primitives.
		-- ====================================================================
		local function test_on_humanoid_died_body_contains_zero_yield_primitives()
			local source = loadServiceSource()

			local bodyHeaderPos = source:find("function DisturbanceService:_onHumanoidDied%(deadPlayer: Player%)")
			expect(bodyHeaderPos).never.to.equal(nil)

			local bodyStart = source:find("\n", bodyHeaderPos :: number) or (bodyHeaderPos :: number)
			local bodyEnd = source:find("\nend", bodyStart, true)
			expect(bodyEnd).never.to.equal(nil)

			local body = source:sub(bodyStart, bodyEnd)

			expect(body:find("task%.wait")).to.equal(nil)
			expect(body:find("task%.delay")).to.equal(nil)
			expect(body:find("task%.spawn")).to.equal(nil)
			expect(body:find("WaitForChild")).to.equal(nil)
			expect(body:find("%f[%a]wait%(")).to.equal(nil)
			expect(body:find("%f[%a]delay%(")).to.equal(nil)
		end
		it(
			"test_on_humanoid_died_body_contains_zero_yield_primitives",
			function()
				test_on_humanoid_died_body_contains_zero_yield_primitives()
			end
		)

		-- ====================================================================
		-- AC -- payload constructed AFTER the snapshot capture: _onHumanoidDied's body writes
		-- self._deathLockSnapshot[deadPlayer] BEFORE it samples workspace:GetServerTimeNow() /
		-- constructs the payload.
		-- ====================================================================
		local function test_snapshot_write_precedes_payload_construction_in_source_order()
			local source = loadServiceSource()

			local bodyHeaderPos = source:find("function DisturbanceService:_onHumanoidDied%(deadPlayer: Player%)")
			expect(bodyHeaderPos).never.to.equal(nil)

			-- Bound the search to _onHumanoidDied's own body (code-review hardening -- mirrors the
			-- yield-primitives test's bodyStart/bodyEnd bounding above), so a future occurrence of
			-- any of these three substrings elsewhere in the file can never make this check verify
			-- the wrong occurrence.
			local bodyStart = source:find("\n", bodyHeaderPos :: number) or (bodyHeaderPos :: number)
			local bodyEnd = source:find("\nend", bodyStart, true)
			expect(bodyEnd).never.to.equal(nil)
			local body = source:sub(bodyStart, bodyEnd)

			local snapshotWritePos = body:find("self%._deathLockSnapshot%[deadPlayer%] = wasLocked")
			local nowSamplePos = body:find("workspace:GetServerTimeNow%(%)")
			local fireCallPos = body:find("self%._onPlayerDied:Fire%(payload%)")

			expect(snapshotWritePos).never.to.equal(nil)
			expect(nowSamplePos).never.to.equal(nil)
			expect(fireCallPos).never.to.equal(nil)

			expect((snapshotWritePos :: number) < (nowSamplePos :: number)).to.equal(true)
			expect((nowSamplePos :: number) < (fireCallPos :: number)).to.equal(true)
		end
		it(
			"test_snapshot_write_precedes_payload_construction_in_source_order",
			function()
				test_snapshot_write_precedes_payload_construction_in_source_order()
			end
		)

		-- ====================================================================
		-- AC -- server-internal only: GetOnPlayerDiedSignal is never exposed via
		-- DisturbanceService.Client, and .Client stays an empty table.
		-- ====================================================================
		local function test_get_on_player_died_signal_never_exposed_via_client()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it(
			"test_get_on_player_died_signal_never_exposed_via_client",
			function()
				test_get_on_player_died_signal_never_exposed_via_client()
			end
		)

		-- ====================================================================
		-- AC -- GetOnPlayerDiedSignal() exists and returns the real self._onPlayerDied instance.
		-- ====================================================================
		local function test_get_on_player_died_signal_accessor_returns_real_field()
			local source = loadServiceSource()
			expect(source:find("function DisturbanceService:GetOnPlayerDiedSignal%(%): BindableEvent")).never.to.equal(nil)
			expect(source:find("return self%._onPlayerDied")).never.to.equal(nil)
		end
		it(
			"test_get_on_player_died_signal_accessor_returns_real_field",
			function()
				test_get_on_player_died_signal_accessor_returns_real_field()
			end
		)

		-- ====================================================================
		-- AC -- _captureDeathLockSnapshot stub exists and is hardcoded to always return false
		-- (TODO(Story 011) -- the predator-lock registry does not exist yet).
		-- ====================================================================
		local function test_capture_death_lock_snapshot_stub_always_returns_false()
			local source = loadServiceSource()
			local stubPos = source:find("function DisturbanceService:_captureDeathLockSnapshot%(_deadPlayer: Player%): boolean")
			expect(stubPos).never.to.equal(nil)

			local bodyStart = source:find("\n", stubPos :: number) or (stubPos :: number)
			local bodyEnd = source:find("\nend", bodyStart, true)
			local body = source:sub(bodyStart, bodyEnd)
			expect(body:find("return false")).never.to.equal(nil)
		end
		it(
			"test_capture_death_lock_snapshot_stub_always_returns_false",
			function()
				test_capture_death_lock_snapshot_stub_always_returns_false()
			end
		)

		-- ====================================================================
		-- Regression pin (code-review fix, this story): the PlayerRemoving handler clears
		-- self._deathLockSnapshot[player] -- a player who dies then disconnects before Story
		-- 012's read-and-clear reader consumes the entry must not pin their departed Player
		-- instance for the life of the server (same leak class as the _loadedChunks /
		-- _floraDeltaCache clears in the same handler). PlayerRemoving itself cannot fire under
		-- this harness (no live Players service), so this is a static/structural pin, matching
		-- this describe block's own established strategy.
		-- ====================================================================
		local function test_player_removing_handler_clears_death_lock_snapshot()
			local source = loadServiceSource()

			local removingPos = source:find("Players%.PlayerRemoving:Connect%(")
			expect(removingPos).never.to.equal(nil)

			local clearPos = source:find("self%._deathLockSnapshot%[player%] = nil", removingPos)
			expect(clearPos).never.to.equal(nil)

			-- The clear falls inside the PlayerRemoving handler's own region: after the handler
			-- opens and before the next function declaration in the file.
			local nextFunctionPos = source:find("function DisturbanceService:", removingPos)
			expect(nextFunctionPos).never.to.equal(nil)
			expect((clearPos :: number) < (nextFunctionPos :: number)).to.equal(true)
		end
		it(
			"test_player_removing_handler_clears_death_lock_snapshot",
			function()
				test_player_removing_handler_clears_death_lock_snapshot()
			end
		)
	end)
end
