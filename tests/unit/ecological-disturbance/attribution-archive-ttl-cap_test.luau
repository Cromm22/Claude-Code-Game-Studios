--!strict
-- attribution-archive-ttl-cap_test
--
-- Unit tests for Story 004: Attribution Archive (write-once store, TTL, count-cap FIFO).
-- Story: production/epics/ecological-disturbance/story-004-attribution-archive-ttl-cap.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceAttributionArchiveLogic.luau (pure write-once entry
--     construction, the three-condition "longer of" retention rule, count-cap FIFO eviction with
--     lock-exemption, and player-departure referencer-set maintenance -- C.1.11)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only, for the
--     same reason Stories 002/003's own test files give -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live DisturbanceService:Emit() call is not
--     currently possible in an automated test -- the wiring/ops-log ACs are instead proven via
--     source-text checks against the real file)
--
-- Story Type: Logic -- coding-standards.md's bar is an automated unit test that must pass
-- (BLOCKING gate).

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local ArchiveLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceAttributionArchiveLogic)
local SpatialGridLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceSpatialGridLogic)

type Archive = ArchiveLogic.Archive
type ReferencingPlayers = ArchiveLogic.ReferencingPlayers
type InsertionSequence = ArchiveLogic.InsertionSequence
type AttributionArchiveEntry = ArchiveLogic.AttributionArchiveEntry

-- ATTRIBUTION_ARCHIVE_TTL / MAX_ATTRIBUTION_ARCHIVE_ENTRIES literals below intentionally match
-- DisturbanceConstants.luau's published values (1200 / 4000) without require()-ing that module --
-- this test file follows the exact same harness-driven precedent Story 002/003's own test files
-- document (DisturbanceConstants.luau is not mounted under this harness's ServerScriptService
-- tree, and require(script.Parent...) is not resolvable for loadstring-executed modules here).
local ATTRIBUTION_ARCHIVE_TTL = 1200
local MAX_ATTRIBUTION_ARCHIVE_ENTRIES = 4000

--- Always-unlocked stub, matching production's own DefaultIsEmissionLocked shape but declared
--- locally so tests can swap in an always-true / selective mock freely.
local function neverLocked(_emissionId: string): boolean
	return false
end

--- Builds a well-formed AttributionArchiveEntry for test setup.
local function makeEntry(emissionId: string, emissionTime: number, sourcePlayerId: number?): AttributionArchiveEntry
	return {
		emissionId = emissionId,
		sourcePlayerId = sourcePlayerId or 1,
		emissionType = "Gather",
		position = Vector3.new(0, 0, 0),
		emissionTime = emissionTime,
		attributionChain = { "GatherWood" },
	}
end

--- Seeds `archive`/`referencingPlayers`/`insertionSequence` with `entry`, as InsertEntry would --
--- used by tests that want to set up pre-existing state directly rather than going through
--- InsertEntry itself (e.g. constructing an already-at-cap archive for eviction tests).
local function seedEntry(
	archive: Archive,
	referencingPlayers: ReferencingPlayers,
	insertionSequence: InsertionSequence,
	entry: AttributionArchiveEntry,
	sequence: number
): ()
	archive[entry.emissionId] = entry
	referencingPlayers[entry.emissionId] = { [entry.sourcePlayerId] = true }
	insertionSequence[entry.emissionId] = sequence
end

local function countEntries(archive: Archive): number
	local count = 0
	for _ in archive do
		count += 1
	end
	return count
end

return function()
	describe("DisturbanceServiceAttributionArchiveLogic -- Story 004 (write-once record shape)", function()
		local function test_build_entry_copies_exactly_the_six_archive_fields()
			local position = Vector3.new(10, 5, -20)
			local attributionChain = { "GatherWood", "SprintPulse" }
			local payload = {
				emissionId = "emit-1",
				sourcePlayerId = 42,
				emissionType = "Gather" :: ArchiveLogic.EmissionType,
				position = position,
				emissionTime = 500.25,
				attributionChain = attributionChain,
				initialMagnitude = 0.25, -- present on a real EmissionPayload, must NOT be copied
			}

			local entry = ArchiveLogic.BuildEntry(payload)

			expect(entry.emissionId).to.equal("emit-1")
			expect(entry.sourcePlayerId).to.equal(42)
			expect(entry.emissionType).to.equal("Gather")
			expect(entry.position).to.equal(position)
			expect(entry.emissionTime).to.equal(500.25)
			expect(#entry.attributionChain).to.equal(2)
			expect(entry.attributionChain[1]).to.equal("GatherWood")

			-- Structural enforcement of "NOT used by any field-value math": initialMagnitude is
			-- never copied onto the archive entry at all.
			local entryAny: any = entry
			expect(entryAny.initialMagnitude).to.equal(nil)
		end
		it("test_build_entry_copies_exactly_the_six_archive_fields", function()
			test_build_entry_copies_exactly_the_six_archive_fields()
		end)

		local function test_entry_survives_independently_of_any_live_source_concept()
			-- The archive entry itself has no notion of "still live" / "decayed below floor" --
			-- it is retrievable purely by key, with no dependency on any external liveness check.
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			local entry = makeEntry("emit-2", 10)
			ArchiveLogic.InsertEntry(archive, referencingPlayers, insertionSequence, 0, MAX_ATTRIBUTION_ARCHIVE_ENTRIES, entry, neverLocked)

			expect(archive["emit-2"]).never.to.equal(nil)
			expect((archive["emit-2"] :: AttributionArchiveEntry).emissionTime).to.equal(10)
		end
		it("test_entry_survives_independently_of_any_live_source_concept", function()
			test_entry_survives_independently_of_any_live_source_concept()
		end)
	end)

	describe("DisturbanceServiceAttributionArchiveLogic -- Story 004 (TTL purge, condition (a), boundary pinned INCLUSIVE)", function()
		local function test_is_ttl_expired_false_before_boundary()
			expect(ArchiveLogic.IsTtlExpired(1000, 1000 + 1199.9, ATTRIBUTION_ARCHIVE_TTL)).to.equal(false)
		end
		it("test_is_ttl_expired_false_before_boundary", function()
			test_is_ttl_expired_false_before_boundary()
		end)

		-- Pinned design call: exactly at the 1200.0s boundary is TREATED AS EXPIRED (inclusive),
		-- matching this service's own StepAccumulator `>= interval` convention.
		local function test_is_ttl_expired_true_exactly_at_boundary()
			expect(ArchiveLogic.IsTtlExpired(1000, 1000 + 1200.0, ATTRIBUTION_ARCHIVE_TTL)).to.equal(true)
		end
		it("test_is_ttl_expired_true_exactly_at_boundary", function()
			test_is_ttl_expired_true_exactly_at_boundary()
		end)

		local function test_is_ttl_expired_true_after_boundary()
			expect(ArchiveLogic.IsTtlExpired(1000, 1000 + 1200.1, ATTRIBUTION_ARCHIVE_TTL)).to.equal(true)
		end
		it("test_is_ttl_expired_true_after_boundary", function()
			test_is_ttl_expired_true_after_boundary()
		end)

		local function test_purge_expired_entries_removes_entry_with_no_referencer_and_no_lock()
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			local entry = makeEntry("emit-ttl", 1000, 7)
			seedEntry(archive, referencingPlayers, insertionSequence, entry, 0)
			-- No live referencer: simulate the source player having already left.
			referencingPlayers["emit-ttl"] = {}

			local now = 1000 + 1200.1
			local purgedIds = ArchiveLogic.PurgeExpiredEntries(archive, referencingPlayers, insertionSequence, neverLocked, now, ATTRIBUTION_ARCHIVE_TTL)

			expect(#purgedIds).to.equal(1)
			expect(purgedIds[1]).to.equal("emit-ttl")
			expect(archive["emit-ttl"]).to.equal(nil)
			expect(referencingPlayers["emit-ttl"]).to.equal(nil)
			expect(insertionSequence["emit-ttl"]).to.equal(nil)
		end
		it(
			"test_purge_expired_entries_removes_entry_with_no_referencer_and_no_lock",
			function()
				test_purge_expired_entries_removes_entry_with_no_referencer_and_no_lock()
			end
		)

		local function test_purge_expired_entries_retains_entry_before_ttl_boundary()
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			local entry = makeEntry("emit-fresh", 1000, 7)
			seedEntry(archive, referencingPlayers, insertionSequence, entry, 0)
			referencingPlayers["emit-fresh"] = {} -- no referencer, but TTL not yet expired

			local now = 1000 + 1199.9
			local purgedIds = ArchiveLogic.PurgeExpiredEntries(archive, referencingPlayers, insertionSequence, neverLocked, now, ATTRIBUTION_ARCHIVE_TTL)

			expect(#purgedIds).to.equal(0)
			expect(archive["emit-fresh"]).never.to.equal(nil)
		end
		it("test_purge_expired_entries_retains_entry_before_ttl_boundary", function()
			test_purge_expired_entries_retains_entry_before_ttl_boundary()
		end)
	end)

	describe("DisturbanceServiceAttributionArchiveLogic -- Story 004 (player-departure retention, condition (b))", function()
		local function test_should_purge_false_when_ttl_expired_but_source_player_still_connected()
			local entry = makeEntry("emit-b1", 1000, 99)
			local referencingPlayers: ReferencingPlayers = { ["emit-b1"] = { [99] = true } }

			local shouldPurge = ArchiveLogic.ShouldPurge(entry, referencingPlayers, neverLocked, 1000 + 1300, ATTRIBUTION_ARCHIVE_TTL)

			-- TTL has expired (1300 > 1200), but condition (b) keeps it alive: the source player
			-- is still connected (still present in the referencing set).
			expect(shouldPurge).to.equal(false)
		end
		it(
			"test_should_purge_false_when_ttl_expired_but_source_player_still_connected",
			function()
				test_should_purge_false_when_ttl_expired_but_source_player_still_connected()
			end
		)

		-- Edge case: the source player disconnects -- entry should now purge on the next
		-- maintenance pass IF TTL has also expired AND no predator lock references it.
		local function test_handle_player_departure_then_maintenance_pass_purges_when_ttl_also_expired()
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			local entry = makeEntry("emit-b2", 1000, 99)
			seedEntry(archive, referencingPlayers, insertionSequence, entry, 0)

			-- Player 99 departs.
			ArchiveLogic.HandlePlayerDeparture(referencingPlayers, 99)
			expect(ArchiveLogic.HasLiveReferencer(referencingPlayers, "emit-b2")).to.equal(false)

			local purgedIds =
				ArchiveLogic.PurgeExpiredEntries(archive, referencingPlayers, insertionSequence, neverLocked, 1000 + 1200.1, ATTRIBUTION_ARCHIVE_TTL)

			expect(#purgedIds).to.equal(1)
			expect(archive["emit-b2"]).to.equal(nil)
		end
		it(
			"test_handle_player_departure_then_maintenance_pass_purges_when_ttl_also_expired",
			function()
				test_handle_player_departure_then_maintenance_pass_purges_when_ttl_also_expired()
			end
		)

		local function test_handle_player_departure_only_removes_the_departed_player_from_shared_sets()
			local referencingPlayers: ReferencingPlayers = {
				["emit-shared"] = { [1] = true, [2] = true },
				["emit-solo"] = { [1] = true },
			}

			ArchiveLogic.HandlePlayerDeparture(referencingPlayers, 1)

			-- emit-shared still has player 2 as a live referencer.
			expect(ArchiveLogic.HasLiveReferencer(referencingPlayers, "emit-shared")).to.equal(true)
			-- emit-solo's only referencer just left.
			expect(ArchiveLogic.HasLiveReferencer(referencingPlayers, "emit-solo")).to.equal(false)
		end
		it(
			"test_handle_player_departure_only_removes_the_departed_player_from_shared_sets",
			function()
				test_handle_player_departure_only_removes_the_departed_player_from_shared_sets()
			end
		)
	end)

	describe("DisturbanceServiceAttributionArchiveLogic -- Story 004 (predator-lock retention, condition (c))", function()
		local function alwaysLocked(_emissionId: string): boolean
			return true
		end

		local function test_should_purge_false_when_locked_even_with_ttl_expired_and_no_referencer()
			local entry = makeEntry("emit-c1", 1000, 7)
			local referencingPlayers: ReferencingPlayers = { ["emit-c1"] = {} } -- no live referencer

			local shouldPurge = ArchiveLogic.ShouldPurge(entry, referencingPlayers, alwaysLocked, 1000 + 1300, ATTRIBUTION_ARCHIVE_TTL)

			expect(shouldPurge).to.equal(false)
		end
		it(
			"test_should_purge_false_when_locked_even_with_ttl_expired_and_no_referencer",
			function()
				test_should_purge_false_when_locked_even_with_ttl_expired_and_no_referencer()
			end
		)

		local function test_should_purge_true_once_lock_releases_and_all_other_conditions_fail()
			local entry = makeEntry("emit-c2", 1000, 7)
			local referencingPlayers: ReferencingPlayers = { ["emit-c2"] = {} }

			-- Lock has now released (mock returns false) -- entry purges on the next maintenance
			-- pass after release, per the story's own edge-case framing.
			local shouldPurge = ArchiveLogic.ShouldPurge(entry, referencingPlayers, neverLocked, 1000 + 1300, ATTRIBUTION_ARCHIVE_TTL)

			expect(shouldPurge).to.equal(true)
		end
		it(
			"test_should_purge_true_once_lock_releases_and_all_other_conditions_fail",
			function()
				test_should_purge_true_once_lock_releases_and_all_other_conditions_fail()
			end
		)

		local function test_default_is_emission_locked_stub_always_returns_false()
			-- The required Story 011 stub -- TODO(Story 011) marker lives in production source.
			expect(ArchiveLogic.DefaultIsEmissionLocked("any-id")).to.equal(false)
		end
		it("test_default_is_emission_locked_stub_always_returns_false", function()
			test_default_is_emission_locked_stub_always_returns_false()
		end)
	end)

	describe("DisturbanceServiceAttributionArchiveLogic -- Story 004 (count-cap FIFO with lock-exemption)", function()
		local function test_insert_entry_below_cap_does_not_evict()
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("existing", 1), 0)

			local evictedId, evictionFailed, nextSequence =
				ArchiveLogic.InsertEntry(archive, referencingPlayers, insertionSequence, 1, MAX_ATTRIBUTION_ARCHIVE_ENTRIES, makeEntry("fresh", 2), neverLocked)

			expect(evictedId).to.equal(nil)
			expect(evictionFailed).to.equal(false)
			expect(nextSequence).to.equal(2)
			expect(archive["existing"]).never.to.equal(nil)
			expect(archive["fresh"]).never.to.equal(nil)
		end
		it("test_insert_entry_below_cap_does_not_evict", function()
			test_insert_entry_below_cap_does_not_evict()
		end)

		-- AC core case: at exactly cap, the oldest entry is locked -- eviction must SKIP it and
		-- advance to the next-oldest UNLOCKED entry instead, with the new entry still inserted.
		local function test_insert_entry_at_cap_skips_locked_oldest_and_evicts_next_oldest_unlocked()
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			-- "oldestLocked" (emissionTime=1) is the true oldest but is locked; "secondOldest"
			-- (emissionTime=2) is the oldest UNLOCKED entry and must be the one evicted.
			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("oldestLocked", 1), 0)
			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("secondOldest", 2), 1)
			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("newest", 3), 2)

			local smallCap = 3
			local isLocked = function(emissionId: string): boolean
				return emissionId == "oldestLocked"
			end

			local evictedId, evictionFailed = ArchiveLogic.InsertEntry(
				archive,
				referencingPlayers,
				insertionSequence,
				3,
				smallCap,
				makeEntry("incoming", 4),
				isLocked
			)

			expect(evictionFailed).to.equal(false)
			expect(evictedId).to.equal("secondOldest")
			expect(archive["oldestLocked"]).never.to.equal(nil) -- exempt, never evicted
			expect(archive["secondOldest"]).to.equal(nil)
			expect(archive["newest"]).never.to.equal(nil)
			expect(archive["incoming"]).never.to.equal(nil)
			expect(countEntries(archive)).to.equal(smallCap)
		end
		it(
			"test_insert_entry_at_cap_skips_locked_oldest_and_evicts_next_oldest_unlocked",
			function()
				test_insert_entry_at_cap_skips_locked_oldest_and_evicts_next_oldest_unlocked()
			end
		)

		-- Required tie-break edge case (mirrors Story 003's own FindOldestSourceId tie-break
		-- test): identical emissionTime is tie-broken by insertion order.
		local function test_find_oldest_unlocked_entry_id_tie_break_is_first_inserted()
			local archive: Archive = {}
			local insertionSequence: InsertionSequence = {}
			archive["firstInserted"] = makeEntry("firstInserted", 500)
			archive["secondInserted"] = makeEntry("secondInserted", 500)
			insertionSequence["firstInserted"] = 1
			insertionSequence["secondInserted"] = 2

			local oldestId = ArchiveLogic.FindOldestUnlockedEntryId(archive, insertionSequence, neverLocked)
			expect(oldestId).to.equal("firstInserted")
		end
		it("test_find_oldest_unlocked_entry_id_tie_break_is_first_inserted", function()
			test_find_oldest_unlocked_entry_id_tie_break_is_first_inserted()
		end)

		local function test_find_oldest_unlocked_entry_id_returns_nil_when_empty()
			expect(ArchiveLogic.FindOldestUnlockedEntryId({}, {}, neverLocked)).to.equal(nil)
		end
		it("test_find_oldest_unlocked_entry_id_returns_nil_when_empty", function()
			test_find_oldest_unlocked_entry_id_returns_nil_when_empty()
		end)

		-- Pathological edge case: ALL entries are locked. Must not crash, must not silently grow
		-- unbounded without a distinct signal -- InsertEntry reports evictionFailed=true and still
		-- writes the new entry (never drops a write, never throws).
		local function test_insert_entry_all_locked_reports_eviction_failed_and_still_inserts()
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			local smallCap = 2
			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("lockedA", 1), 0)
			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("lockedB", 2), 1)

			local alwaysLocked = function(_emissionId: string): boolean
				return true
			end

			local evictedId, evictionFailed, nextSequence =
				ArchiveLogic.InsertEntry(archive, referencingPlayers, insertionSequence, 2, smallCap, makeEntry("incoming", 3), alwaysLocked)

			expect(evictedId).to.equal(nil)
			expect(evictionFailed).to.equal(true)
			expect(nextSequence).to.equal(3)
			-- The new entry is still written -- never silently dropped.
			expect(archive["incoming"]).never.to.equal(nil)
			-- Both pre-existing locked entries remain untouched.
			expect(archive["lockedA"]).never.to.equal(nil)
			expect(archive["lockedB"]).never.to.equal(nil)
			-- The archive now exceeds smallCap by one -- an accepted, LOGGED (by the caller)
			-- pathological outcome, not a crash.
			expect(countEntries(archive)).to.equal(smallCap + 1)
		end
		it(
			"test_insert_entry_all_locked_reports_eviction_failed_and_still_inserts",
			function()
				test_insert_entry_all_locked_reports_eviction_failed_and_still_inserts()
			end
		)

		local function test_enforce_cap_pathological_all_locked_does_not_crash_and_reports_failure()
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			for i = 1, 5 do
				local id = "locked" .. tostring(i)
				seedEntry(archive, referencingPlayers, insertionSequence, makeEntry(id, i), i)
			end

			local alwaysLocked = function(_emissionId: string): boolean
				return true
			end

			-- Archive already exceeds a cap of 2, and every entry is locked -- EnforceCap must
			-- terminate (not infinite-loop), evict nothing, and report the failure distinctly.
			local evictedIds, evictionFailed = ArchiveLogic.EnforceCap(archive, referencingPlayers, insertionSequence, 2, alwaysLocked)

			expect(#evictedIds).to.equal(0)
			expect(evictionFailed).to.equal(true)
			expect(countEntries(archive)).to.equal(5) -- unchanged, nothing evictable
		end
		it(
			"test_enforce_cap_pathological_all_locked_does_not_crash_and_reports_failure",
			function()
				test_enforce_cap_pathological_all_locked_does_not_crash_and_reports_failure()
			end
		)

		local function test_run_maintenance_pass_purges_then_enforces_cap()
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local insertionSequence: InsertionSequence = {}

			-- One entry eligible for TTL purge (no referencer, TTL expired).
			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("expired", 0), 0)
			referencingPlayers["expired"] = {}
			-- One entry that survives purge but leaves the archive still over a tiny cap.
			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("fresh1", 1000), 1)
			seedEntry(archive, referencingPlayers, insertionSequence, makeEntry("fresh2", 1001), 2)

			local now = 0 + 1200.1
			local purgedIds, capEvictedIds, evictionFailed =
				ArchiveLogic.RunMaintenancePass(archive, referencingPlayers, insertionSequence, neverLocked, now, ATTRIBUTION_ARCHIVE_TTL, 1)

			expect(#purgedIds).to.equal(1)
			expect(purgedIds[1]).to.equal("expired")
			expect(archive["expired"]).to.equal(nil)

			-- After purge, 2 entries remain against a cap of 1 -- cap enforcement evicts the
			-- oldest of what's left ("fresh1").
			expect(#capEvictedIds).to.equal(1)
			expect(capEvictedIds[1]).to.equal("fresh1")
			expect(evictionFailed).to.equal(false)
			expect(archive["fresh2"]).never.to.equal(nil)
			expect(countEntries(archive)).to.equal(1)
		end
		it("test_run_maintenance_pass_purges_then_enforces_cap", function()
			test_run_maintenance_pass_purges_then_enforces_cap()
		end)
	end)

	describe("DisturbanceServiceAttributionArchiveLogic -- Story 004 (independence from live-source eviction, Story 003)", function()
		local function test_evicting_a_live_source_never_touches_a_separate_archive_table()
			-- Build a live-source-list state and trigger Story 003's own cap-eviction path.
			local grid: SpatialGridLogic.SpatialGrid = {}
			local liveSources: { [string]: SpatialGridLogic.MinimalSource } = {}
			local liveInsertionSequence: { [string]: number } = {}

			local oldLiveSource = {
				emissionId = "live-old",
				sourcePlayerId = 1,
				emissionType = "Gather",
				emissionTime = 10,
				position = Vector3.new(0, 0, 0),
			}
			liveSources["live-old"] = oldLiveSource
			liveInsertionSequence["live-old"] = 0

			-- A completely separate, pre-populated attribution archive -- SpatialGridLogic's
			-- EvictOldestSource signature has no archive parameter at all (structural
			-- independence), so this archive cannot be reached from that call no matter what.
			local archive: Archive = {}
			local referencingPlayers: ReferencingPlayers = {}
			local archiveInsertionSequence: InsertionSequence = {}
			seedEntry(archive, referencingPlayers, archiveInsertionSequence, makeEntry("archived-1", 5), 0)

			local evicted = SpatialGridLogic.EvictOldestSource(grid, liveSources, liveInsertionSequence, 32)

			expect(evicted).never.to.equal(nil)
			expect((evicted :: SpatialGridLogic.EvictedSourceInfo).emissionId).to.equal("live-old")
			-- The archive, entirely untouched -- still has exactly its one pre-existing entry.
			expect(countEntries(archive)).to.equal(1)
			expect(archive["archived-1"]).never.to.equal(nil)
		end
		it(
			"test_evicting_a_live_source_never_touches_a_separate_archive_table",
			function()
				test_evicting_a_live_source_never_touches_a_separate_archive_table()
			end
		)
	end)

	describe("DisturbanceServiceAttributionArchiveLogic -- Story 004 (archive independence & forbidden-reference static checks)", function()
		local archiveLogicSource: string? = nil
		local disturbanceServiceSource: string? = nil

		-- Naive first-`--`-match comment stripper, matching spatial-grid-live-source-cap-
		-- eviction_test.luau / emission-schema-server-emit-intake_test.luau's own reference
		-- implementation exactly (NOT quote-aware -- this project's convention is to avoid `--`
		-- inside warn()/print()/error strings, using `:`/`|` separators instead, which this
		-- story's own production code under test follows).
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function loadArchiveLogicSource(): string
			if not archiveLogicSource then
				archiveLogicSource =
					stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceServiceAttributionArchiveLogic.luau"))
			end
			return archiveLogicSource :: string
		end

		local function loadServiceSource(): string
			if not disturbanceServiceSource then
				disturbanceServiceSource = stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceService.luau"))
			end
			return disturbanceServiceSource :: string
		end

		-- RAW (NOT comment-stripped) source, for the one check below that must find text living
		-- INSIDE a comment on purpose (the `-- TODO(Story 011)` marker itself is a comment by
		-- design -- stripLuaComments would remove it, which is correct behavior for every other
		-- check in this describe() block (those check real code references), but would produce a
		-- false negative here specifically. Read fresh each call (this file's own convenience
		-- helpers above cache the stripped variants, but this one check is cheap enough not to
		-- bother caching separately).
		local function loadArchiveLogicRawSource(): string
			return fs.readFile("src/gameplay/services/DisturbanceServiceAttributionArchiveLogic.luau")
		end

		-- Mirrors DisturbanceServiceSpatialGridLogic.luau's own "never references
		-- attributionArchive" static check, in reverse: this module never references the
		-- spatial-grid/live-source concepts either -- confirming the independence is structural
		-- on BOTH sides, not just one.
		local function test_archive_logic_never_references_spatial_grid_or_live_sources()
			local source = loadArchiveLogicSource()
			expect(source:find("spatialGrid")).to.equal(nil)
			expect(source:find("liveSources")).to.equal(nil)
		end
		it("test_archive_logic_never_references_spatial_grid_or_live_sources", function()
			test_archive_logic_never_references_spatial_grid_or_live_sources()
		end)

		-- No client-callable path: none of this module's functions ever appear on
		-- DisturbanceService.Client (structural precondition for Story 016, matching Story 003's
		-- own precedent test).
		local function test_client_table_remains_empty_no_archive_methods_exposed_to_clients()
			local source = loadServiceSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it(
			"test_client_table_remains_empty_no_archive_methods_exposed_to_clients",
			function()
				test_client_table_remains_empty_no_archive_methods_exposed_to_clients()
			end
		)

		-- Wiring confirmation: Emit() actually calls AttributionArchiveLogic.InsertEntry() with
		-- the real DisturbanceConstants, and that call site is NOT nested inside `if evicted
		-- then` (i.e. it runs unconditionally, independent of Story 003's own eviction branch).
		local function test_disturbance_service_emit_wires_insert_entry_unconditionally()
			local source = loadServiceSource()
			expect(source:find("AttributionArchiveLogic%.InsertEntry%(")).never.to.equal(nil)
			expect(source:find("AttributionArchiveLogic%.BuildEntry%(")).never.to.equal(nil)
			expect(source:find("DisturbanceConstants%.MAX_ATTRIBUTION_ARCHIVE_ENTRIES")).never.to.equal(nil)

			-- Structural independence check: the text between `if evicted then` and its closing
			-- `end` (Story 003's own eviction-log branch) does not contain the archive insert
			-- call -- i.e. the archive write is not nested inside that conditional.
			local evictedBranchStart = source:find("if evicted then")
			local evictedBranchEnd = source:find("\tend", evictedBranchStart)
			local evictedBranchText = source:sub(evictedBranchStart, evictedBranchEnd)
			expect(evictedBranchText:find("AttributionArchiveLogic%.InsertEntry%(")).to.equal(nil)
		end
		it(
			"test_disturbance_service_emit_wires_insert_entry_unconditionally",
			function()
				test_disturbance_service_emit_wires_insert_entry_unconditionally()
			end
		)

		-- Ops-log AC: cap-eviction and cap-exceeded-cannot-evict are each logged with a distinct
		-- message (not the same warn() text, and not silently swallowed).
		local function test_disturbance_service_logs_archive_cap_eviction_and_cannot_evict_distinctly()
			local source = loadServiceSource()
			expect(source:find("attribution archive cap%-evicted")).never.to.equal(nil)
			expect(source:find("attribution archive cap exceeded, cannot evict")).never.to.equal(nil)
		end
		it(
			"test_disturbance_service_logs_archive_cap_eviction_and_cannot_evict_distinctly",
			function()
				test_disturbance_service_logs_archive_cap_eviction_and_cannot_evict_distinctly()
			end
		)

		-- Story 011 stub AC: the injection-seam default and its TODO marker both actually exist
		-- in the production module (not just in this test file's own mock).
		local function test_archive_logic_has_story_011_todo_marker_and_default_stub()
			-- The TODO marker lives inside a comment BY DESIGN (it is a forward-looking authorship
			-- note, not executable code) -- checked against the RAW source, not the comment-
			-- stripped variant every other check in this describe() block uses, since stripping
			-- would remove the very text this check needs to find.
			local rawSource = loadArchiveLogicRawSource()
			expect(rawSource:find("TODO%(Story 011%)")).never.to.equal(nil)

			-- DefaultIsEmissionLocked is a real function definition (executable code), so the
			-- comment-stripped source is the right check here, consistent with every other check
			-- in this describe() block.
			local source = loadArchiveLogicSource()
			expect(source:find("DefaultIsEmissionLocked")).never.to.equal(nil)
		end
		it("test_archive_logic_has_story_011_todo_marker_and_default_stub", function()
			test_archive_logic_has_story_011_todo_marker_and_default_stub()
		end)

		-- Periodic maintenance wiring AC (TR-ed-051): the KnitStart Heartbeat actually steps a
		-- SEPARATE accumulator at EXPIRY_MAINTENANCE_INTERVAL and calls the maintenance pass.
		local function test_disturbance_service_wires_periodic_maintenance_accumulator()
			local source = loadServiceSource()
			expect(source:find("DisturbanceConstants%.EXPIRY_MAINTENANCE_INTERVAL")).never.to.equal(nil)
			expect(source:find("_runAttributionArchiveMaintenancePass")).never.to.equal(nil)
			expect(source:find("AttributionArchiveLogic%.RunMaintenancePass%(")).never.to.equal(nil)
		end
		it(
			"test_disturbance_service_wires_periodic_maintenance_accumulator",
			function()
				test_disturbance_service_wires_periodic_maintenance_accumulator()
			end
		)

		-- Condition (b) wiring AC: PlayerRemoving calls HandlePlayerDeparture.
		local function test_disturbance_service_wires_player_departure_handling()
			local source = loadServiceSource()
			expect(source:find("AttributionArchiveLogic%.HandlePlayerDeparture%(")).never.to.equal(nil)
			expect(source:find("PlayerRemoving")).never.to.equal(nil)
		end
		it("test_disturbance_service_wires_player_departure_handling", function()
			test_disturbance_service_wires_player_departure_handling()
		end)
	end)
end
