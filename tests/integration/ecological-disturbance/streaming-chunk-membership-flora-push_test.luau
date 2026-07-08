--!strict
-- streaming-chunk-membership-flora-push_test
--
-- Integration tests for Story 014: StreamingEnabled Chunk Membership & Flora Chunk
-- Snapshot/Update Push.
-- Story: production/epics/ecological-disturbance/story-014-streaming-chunk-membership-flora-push.md
-- Production code under test:
--   src/gameplay/services/DisturbanceServiceStreamingLogic.luau (pure chunk-id encoding, N1
--     XZ-only distance membership check, per-flora delta-threshold gate, wire payload format,
--     N2/N9 atomic stream-in ordering, fire-time membership-gated-delivery check, PlayerRemoving
--     cleanup)
--   src/gameplay/services/DisturbanceService.luau (static/structural source checks only, for the
--     same reason every prior ED story's own test file gives -- Knit is not vendored under
--     ReplicatedStorage.Packages in this harness, so a live DisturbanceService instance is not
--     currently possible in an automated test)
--
-- Story Type: Integration -- coding-standards.md's bar is "Integration test OR documented
-- playtest," so this file mixes true behavioral tests (against the Knit-free
-- DisturbanceServiceStreamingLogic module) with static/structural source-text checks (against the
-- real DisturbanceService.luau file text), exactly matching Story 001/007's own established
-- precedent for this exact split.
--
-- SCOPE NARROWING (flagged explicitly, not silently assumed): H.31's own AC text describes a
-- CLIENT-side behavior (MockTweenService recording TweenService:Create, a tween's StartValue).
-- The Bioluminescent Flora rendering subsystem that would own that client-side tween logic is
-- listed "Not started" in the GDD's own dependency table and is explicitly out of this epic's
-- scope (this story's own Out of Scope section: "Client-side flora rendering ... entirely out of
-- this epic"). This file therefore proves the SERVER-SIDE guarantee H.31 depends on instead: the
-- initial snapshot fires BEFORE any delta update for the same chunk, carries the snapshot's own
-- authoritative values, and the cache is reset to those SAME values so no spurious "second push
-- from a stale/zero baseline" can ever reach a client immediately after the snapshot. The
-- client-side tween-ordering half of H.31 is not testable without that (not-yet-built) subsystem.

local ServerScriptService = game:GetService("ServerScriptService")
local fs = require("@lune/fs")

local StreamingLogic = require(ServerScriptService.gameplay.services.DisturbanceServiceStreamingLogic)

type ChunkPushPayload = StreamingLogic.ChunkPushPayload
type FloraDeltaCache = StreamingLogic.FloraDeltaCache

local function almostEqual(a: number, b: number, tolerance: number): boolean
	return math.abs(a - b) <= tolerance
end

--- Extracts {floraNodeId -> targetT} from a wire-format payload, for assertion convenience.
local function payloadToMap(payload: ChunkPushPayload): { [string]: number }
	local floraPairs = payload[2] :: { { any } }
	local map: { [string]: number } = {}
	for _, pair in floraPairs do
		map[pair[1]] = pair[2]
	end
	return map
end

return function()
	describe("DisturbanceServiceStreamingLogic -- Story 014 (chunk-id encoding, TR-ed-060)", function()
		local function test_chunk_id_for_encodes_floor_division()
			-- Position (130, 5, -70), CHUNK_DIMENSIONS=64 -> chunkX = floor(130/64) = 2,
			-- chunkZ = floor(-70/64) = -2 (Luau's math.floor rounds toward -infinity).
			local chunkId = StreamingLogic.ChunkIdFor(Vector3.new(130, 5, -70), 64)
			expect(chunkId).to.equal("2_-2")
		end
		it("test_chunk_id_for_encodes_floor_division", function()
			test_chunk_id_for_encodes_floor_division()
		end)

		local function test_chunk_center_for_inverts_chunk_id()
			local center = StreamingLogic.ChunkCenterFor("2_-2", 64)
			-- centerX = 2*64 + 32 = 160; centerZ = -2*64 + 32 = -96; Y is always 0 (XZ-plane concept).
			expect(almostEqual(center.X, 160, 0.001)).to.equal(true)
			expect(almostEqual(center.Y, 0, 0.001)).to.equal(true)
			expect(almostEqual(center.Z, -96, 0.001)).to.equal(true)
		end
		it("test_chunk_center_for_inverts_chunk_id", function()
			test_chunk_center_for_inverts_chunk_id()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (N1 XZ-only distance, cave/cliff AC)", function()
		-- AC -- server-computed membership, XZ-only: a chunk whose center is within
		-- STREAMING_PUSH_RADIUS in XZ but far away in Y (a cave far below) must return true --
		-- the engine-specialist-review fix this story cites verbatim.
		local function test_xz_distance_ignores_large_y_separation_cave_case()
			local playerPosition = Vector3.new(0, 500, 0) -- player far above (or the chunk far below)
			local chunkCenter = Vector3.new(10, -500, 10) -- chunk center: 1000 studs of Y separation
			local streamingPushRadius = 96

			-- XZ-only distance: sqrt(10^2 + 10^2) ~= 14.14, well within 96 -- must be true.
			local isLoaded = StreamingLogic.IsChunkLoadedForPosition(playerPosition, chunkCenter, streamingPushRadius)
			expect(isLoaded).to.equal(true)

			-- Sanity: proves the fix matters -- full 3D .Magnitude would have returned false here
			-- (1000 studs of Y alone vastly exceeds the 96-stud radius).
			local dx = playerPosition.X - chunkCenter.X
			local dy = playerPosition.Y - chunkCenter.Y
			local dz = playerPosition.Z - chunkCenter.Z
			local full3DDistance = math.sqrt(dx * dx + dy * dy + dz * dz)
			expect(full3DDistance > streamingPushRadius).to.equal(true)
		end
		it("test_xz_distance_ignores_large_y_separation_cave_case", function()
			test_xz_distance_ignores_large_y_separation_cave_case()
		end)

		local function test_xz_distance_correctly_rejects_far_chunk()
			local playerPosition = Vector3.new(0, 0, 0)
			local chunkCenter = Vector3.new(500, 0, 500)
			expect(StreamingLogic.IsChunkLoadedForPosition(playerPosition, chunkCenter, 96)).to.equal(false)
		end
		it("test_xz_distance_correctly_rejects_far_chunk", function()
			test_xz_distance_correctly_rejects_far_chunk()
		end)

		local function test_xz_distance_exactly_at_radius_is_loaded()
			-- Boundary: exactly-equal-to-radius PASSES (<=, not <).
			local playerPosition = Vector3.new(0, 0, 0)
			local chunkCenter = Vector3.new(96, 0, 0)
			expect(StreamingLogic.IsChunkLoadedForPosition(playerPosition, chunkCenter, 96)).to.equal(true)
		end
		it("test_xz_distance_exactly_at_radius_is_loaded", function()
			test_xz_distance_exactly_at_radius_is_loaded()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (candidate chunk enumeration)", function()
		local function test_candidate_chunk_ids_near_includes_players_own_chunk()
			local playerPosition = Vector3.new(10, 0, 10) -- chunk "0_0" at CHUNK_DIMENSIONS=64
			local candidates = StreamingLogic.CandidateChunkIdsNear(playerPosition, 64, 96)

			local found = false
			for _, chunkId in candidates do
				if chunkId == "0_0" then
					found = true
					break
				end
			end
			expect(found).to.equal(true)
		end
		it("test_candidate_chunk_ids_near_includes_players_own_chunk", function()
			test_candidate_chunk_ids_near_includes_players_own_chunk()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (per-flora delta threshold, TR-ed-009)", function()
		local function test_first_push_never_pushed_before_always_crosses()
			-- previousT == nil (never pushed) -- ALWAYS counts as crossed, regardless of newT.
			expect(StreamingLogic.HasCrossedDeltaThreshold(nil, 0.0, 0.02)).to.equal(true)
			expect(StreamingLogic.HasCrossedDeltaThreshold(nil, 0.5, 0.02)).to.equal(true)
		end
		it("test_first_push_never_pushed_before_always_crosses", function()
			test_first_push_never_pushed_before_always_crosses()
		end)

		local function test_delta_exactly_at_threshold_does_not_cross()
			-- Strictly-greater-than gate: a delta EXACTLY equal to the threshold does NOT cross.
			-- Values chosen to be BIT-EXACT in IEEE-754 double precision (0.50, 0.75, and their
			-- 0.25 difference are all exactly representable binary fractions) -- 0.50/0.52/0.02
			-- would fail spuriously here, since 0.52 - 0.50 is NOT bit-exact 0.02 in floating
			-- point (it evaluates fractionally ABOVE 0.02), which would make this "exactly at
			-- threshold" case incorrectly report as crossed -- a bug in the test's chosen values,
			-- not in HasCrossedDeltaThreshold's own strictly-greater-than logic.
			expect(StreamingLogic.HasCrossedDeltaThreshold(0.50, 0.75, 0.25)).to.equal(false)
		end
		it("test_delta_exactly_at_threshold_does_not_cross", function()
			test_delta_exactly_at_threshold_does_not_cross()
		end)

		local function test_delta_above_threshold_crosses()
			expect(StreamingLogic.HasCrossedDeltaThreshold(0.50, 0.53, 0.02)).to.equal(true)
		end
		it("test_delta_above_threshold_crosses", function()
			test_delta_above_threshold_crosses()
		end)

		local function test_delta_below_threshold_does_not_cross()
			expect(StreamingLogic.HasCrossedDeltaThreshold(0.50, 0.505, 0.02)).to.equal(false)
		end
		it("test_delta_below_threshold_does_not_cross", function()
			test_delta_below_threshold_does_not_cross()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (wire payload format)", function()
		local function test_payload_wire_format_matches_positional_spec()
			-- Verbatim wire format: {chunkId, [{floraNodeId, targetT}, ...]}.
			local payload = StreamingLogic.BuildFloraChunkPayload("1_1", { { floraNodeId = "flora_A", targetT = 0.42 } })
			expect(payload[1]).to.equal("1_1")
			local floraPairs = payload[2] :: { { any } }
			expect(#floraPairs).to.equal(1)
			expect(floraPairs[1][1]).to.equal("flora_A")
			expect(almostEqual(floraPairs[1][2], 0.42, 0.001)).to.equal(true)
		end
		it("test_payload_wire_format_matches_positional_spec", function()
			test_payload_wire_format_matches_positional_spec()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (full snapshot vs delta update, empty-array suppression)", function()
		local function test_full_snapshot_includes_all_flora_unconditionally()
			local floraStates = { flora_A = 0.10, flora_B = 0.20, flora_C = 0.30 }
			local payload, freshCache = StreamingLogic.ComputeChunkFullSnapshot("0_0", floraStates)
			local map = payloadToMap(payload)

			expect(map.flora_A).to.equal(0.10)
			expect(map.flora_B).to.equal(0.20)
			expect(map.flora_C).to.equal(0.30)
			expect(freshCache.flora_A).to.equal(0.10)
			expect(freshCache.flora_B).to.equal(0.20)
			expect(freshCache.flora_C).to.equal(0.30)
		end
		it("test_full_snapshot_includes_all_flora_unconditionally", function()
			test_full_snapshot_includes_all_flora_unconditionally()
		end)

		local function test_delta_update_only_includes_crossed_flora()
			local floraStates = { flora_A = 0.50, flora_B = 0.201 } -- flora_B barely moved
			local lastPushedCache: FloraDeltaCache = { flora_A = 0.10, flora_B = 0.20 }

			local payload = StreamingLogic.ComputeChunkDeltaUpdate("0_0", floraStates, lastPushedCache, 0.02)
			expect(payload).never.to.equal(nil)
			local map = payloadToMap(payload :: ChunkPushPayload)

			expect(map.flora_A).to.equal(0.50) -- crossed (delta 0.40 > 0.02)
			expect(map.flora_B).to.equal(nil) -- did NOT cross (delta 0.001 < 0.02) -- excluded entirely
		end
		it("test_delta_update_only_includes_crossed_flora", function()
			test_delta_update_only_includes_crossed_flora()
		end)

		-- AC -- empty-array suppression (REQUIRED): nothing crossed this tick -> nil, NEVER an
		-- empty-array payload.
		local function test_delta_update_returns_nil_when_nothing_crossed()
			local floraStates = { flora_A = 0.101, flora_B = 0.199 }
			local lastPushedCache: FloraDeltaCache = { flora_A = 0.10, flora_B = 0.20 }

			local payload, updatedCacheValues = StreamingLogic.ComputeChunkDeltaUpdate("0_0", floraStates, lastPushedCache, 0.02)
			expect(payload).to.equal(nil)
			-- No entries were pushed, so the cache-values return is empty (nothing to fold in).
			local updatedCount = 0
			for _ in updatedCacheValues do
				updatedCount += 1
			end
			expect(updatedCount).to.equal(0)
		end
		it("test_delta_update_returns_nil_when_nothing_crossed", function()
			test_delta_update_returns_nil_when_nothing_crossed()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (N2/N9 atomic sequence)", function()
		-- AC -- N2/N9 atomic sequence: the four steps execute in EXACT order (membership add ->
		-- snapshot compute -> fire -> cache reset), with no interleaving.
		local function test_run_chunk_stream_in_executes_four_steps_in_exact_order()
			local loadedChunksForPlayer: { [string]: true } = {}
			local callOrder: { string } = {}
			local firedPayload: ChunkPushPayload? = nil
			local cacheResetPayload: ChunkPushPayload? = nil

			local fakeSnapshot: ChunkPushPayload = { "0_0", { { "flora_A", 0.42 } } }

			StreamingLogic.RunChunkStreamIn(
				loadedChunksForPlayer,
				"0_0",
				function()
					table.insert(callOrder, "computeSnapshot")
					return fakeSnapshot
				end,
				function(snapshot)
					table.insert(callOrder, "fire")
					firedPayload = snapshot
				end,
				function(snapshot)
					table.insert(callOrder, "resetCache")
					cacheResetPayload = snapshot
				end
			)

			expect(callOrder[1]).to.equal("computeSnapshot")
			expect(callOrder[2]).to.equal("fire")
			expect(callOrder[3]).to.equal("resetCache")
			expect(#callOrder).to.equal(3)

			-- Step (1) membership add happened -- and, since it happens FIRST, before any callback,
			-- it must already be true by the time computeSnapshotFn runs (verified below).
			expect(loadedChunksForPlayer["0_0"]).to.equal(true)
			expect(firedPayload).never.to.equal(nil)
			expect(cacheResetPayload).never.to.equal(nil)
		end
		it("test_run_chunk_stream_in_executes_four_steps_in_exact_order", function()
			test_run_chunk_stream_in_executes_four_steps_in_exact_order()
		end)

		-- Step (1) must textually/temporally precede step (2): membership is already TRUE by the
		-- time computeSnapshotFn is invoked.
		local function test_membership_added_before_snapshot_computed()
			local loadedChunksForPlayer: { [string]: true } = {}
			local membershipVisibleDuringCompute = false

			StreamingLogic.RunChunkStreamIn(loadedChunksForPlayer, "0_0", function()
				membershipVisibleDuringCompute = loadedChunksForPlayer["0_0"] == true
				return { "0_0", {} }
			end, function(_snapshot) end, function(_snapshot) end)

			expect(membershipVisibleDuringCompute).to.equal(true)
		end
		it("test_membership_added_before_snapshot_computed", function()
			test_membership_added_before_snapshot_computed()
		end)

		-- Edge case (N2): a second chunk-stream-in for the SAME player+chunk within the same pass
		-- runs its own full atomic sequence again, never interleaving partway through the first.
		local function test_second_stream_in_same_pass_is_reentrant_safe()
			local loadedChunksForPlayer: { [string]: true } = {}
			local fireCount = 0

			local function runOnce(snapshot: ChunkPushPayload)
				StreamingLogic.RunChunkStreamIn(loadedChunksForPlayer, "0_0", function()
					return snapshot
				end, function(_snapshot)
					fireCount += 1
				end, function(_snapshot) end)
			end

			runOnce({ "0_0", { { "flora_A", 0.10 } } })
			runOnce({ "0_0", { { "flora_A", 0.90 } } })

			expect(fireCount).to.equal(2) -- both sequences ran to completion, fully separately
			expect(loadedChunksForPlayer["0_0"]).to.equal(true)
		end
		it("test_second_stream_in_same_pass_is_reentrant_safe", function()
			test_second_stream_in_same_pass_is_reentrant_safe()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (membership-gated delivery, race window)", function()
		local function test_fire_if_still_member_fires_when_member()
			local loadedChunksForPlayer: { [string]: true } = { ["0_0"] = true }
			local fired = false
			local delivered = StreamingLogic.FireIfStillMember(loadedChunksForPlayer, "0_0", function()
				fired = true
			end)
			expect(delivered).to.equal(true)
			expect(fired).to.equal(true)
		end
		it("test_fire_if_still_member_fires_when_member", function()
			test_fire_if_still_member_fires_when_member()
		end)

		local function test_fire_if_still_member_drops_silently_when_not_member()
			local loadedChunksForPlayer: { [string]: true } = {}
			local fired = false
			local delivered = StreamingLogic.FireIfStillMember(loadedChunksForPlayer, "0_0", function()
				fired = true
			end)
			expect(delivered).to.equal(false)
			expect(fired).to.equal(false)
		end
		it("test_fire_if_still_member_drops_silently_when_not_member", function()
			test_fire_if_still_member_drops_silently_when_not_member()
		end)

		-- AC edge case -- race window: membership is removed from loadedChunks EARLIER in the same
		-- pass than the fire attempt. The gate must be evaluated AT FIRE TIME, not from a value
		-- cached earlier in the pass -- proven here by mutating the SAME live table between
		-- "earlier in the pass" and the fire call.
		local function test_fire_if_still_member_race_window_membership_removed_before_fire()
			local loadedChunksForPlayer: { [string]: true } = { ["0_0"] = true }

			-- Simulates "earlier in this same pass, a stream-out removed this chunk."
			loadedChunksForPlayer["0_0"] = nil

			local fired = false
			local delivered = StreamingLogic.FireIfStillMember(loadedChunksForPlayer, "0_0", function()
				fired = true
			end)

			expect(delivered).to.equal(false)
			expect(fired).to.equal(false) -- silently dropped, never delivered
		end
		it("test_fire_if_still_member_race_window_membership_removed_before_fire", function()
			test_fire_if_still_member_race_window_membership_removed_before_fire()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (H.31, server-side scope narrowing)", function()
		-- See this file's header SCOPE NARROWING note: the client-side tween-ordering half of
		-- H.31 is untestable without the not-yet-built Bioluminescent Flora rendering subsystem.
		-- This proves the SERVER-SIDE half: immediately after a snapshot fires and resets the
		-- cache to ITS OWN values, an unchanged fieldState produces NO further update (no spurious
		-- "second push" a client could ever observe racing the first tween).
		local function test_h31_no_spurious_update_immediately_follows_a_snapshot_with_unchanged_state()
			local floraStates = { flora_A = 0.42, flora_B = 0.10 }
			local snapshotPayload, freshCache = StreamingLogic.ComputeChunkFullSnapshot("0_0", floraStates)

			-- The snapshot itself carries the authoritative values (never 0 unless truly 0).
			local snapshotMap = payloadToMap(snapshotPayload)
			expect(almostEqual(snapshotMap.flora_A, 0.42, 0.001)).to.equal(true)

			-- Immediately after: the SAME floraStates, checked against the freshly-reset cache ->
			-- nothing crosses, so no further FloraChunkUpdate would fire.
			local deltaPayload = StreamingLogic.ComputeChunkDeltaUpdate("0_0", floraStates, freshCache, 0.02)
			expect(deltaPayload).to.equal(nil)
		end
		it("test_h31_no_spurious_update_immediately_follows_a_snapshot_with_unchanged_state", function()
			test_h31_no_spurious_update_immediately_follows_a_snapshot_with_unchanged_state()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (H.32b, stream-out continues decay)", function()
		-- AC-H.32b: a chunk streams out while emissions live; the field continues decaying
		-- server-side; on a LATER stream-in, the snapshot carries the CURRENT decayed value, not
		-- the stale pre-stream-out value.
		local function test_h32b_restream_in_snapshot_reflects_current_decayed_value_not_stale()
			-- t1: chunk loaded, flora at 0.60 (fresh emission nearby).
			local floraStatesAtT1 = { flora_A = 0.60 }
			local snapshotAtT1 = StreamingLogic.ComputeChunkFullSnapshot("0_0", floraStatesAtT1)
			expect(almostEqual(payloadToMap(snapshotAtT1).flora_A, 0.60, 0.001)).to.equal(true)

			-- Simulates: chunk streams out (client drops it); server continues running; the field
			-- continues decaying independent of any client's loaded state (TR-ed-050). Some time
			-- later, floraStates has decayed to 0.35 (D.1's own decay math -- computed elsewhere,
			-- this module only ever consumes an already-computed targetT).
			local floraStatesAtT2 = { flora_A = 0.35 }

			-- Stream-in again: a FRESH snapshot, reflecting the decayed value.
			local snapshotAtT2 = StreamingLogic.ComputeChunkFullSnapshot("0_0", floraStatesAtT2)
			expect(almostEqual(payloadToMap(snapshotAtT2).flora_A, 0.35, 0.001)).to.equal(true)
			expect(almostEqual(payloadToMap(snapshotAtT2).flora_A, 0.60, 0.001)).to.equal(false) -- NOT the stale value
		end
		it("test_h32b_restream_in_snapshot_reflects_current_decayed_value_not_stale", function()
			test_h32b_restream_in_snapshot_reflects_current_decayed_value_not_stale()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (H.32d, re-add within same/subsequent pass)", function()
		-- AC-H.32d: chunkA added, snapshot fires; removed from loadedChunks within the same pass;
		-- re-added on a subsequent pass. On the pass the re-add happens: (a) a FRESH snapshot
		-- fires; (b) the cache resets to the fresh snapshot's values (not the pre-drop values);
		-- (c) recovery is complete within that one pass (RunChunkStreamIn is synchronous, so this
		-- is structurally guaranteed, not merely eventually-consistent).
		local function test_h32d_readd_after_drop_fires_fresh_snapshot_and_resets_cache()
			local loadedChunksForPlayer: { [string]: true } = {}
			local playerCache: FloraDeltaCache = {}
			local fireLog: { ChunkPushPayload } = {}

			local function streamIn(snapshot: ChunkPushPayload)
				StreamingLogic.RunChunkStreamIn(loadedChunksForPlayer, "0_0", function()
					return snapshot
				end, function(firedSnapshot)
					table.insert(fireLog, firedSnapshot)
				end, function(firedSnapshot)
					local floraPairs = firedSnapshot[2] :: { { any } }
					for _, pair in floraPairs do
						playerCache[pair[1]] = pair[2]
					end
				end)
			end

			-- (1) Original stream-in: snapshot fires with flora_A = 0.20.
			local originalSnapshot = StreamingLogic.ComputeChunkFullSnapshot("0_0", { flora_A = 0.20 })
			streamIn(originalSnapshot)
			expect(#fireLog).to.equal(1)
			expect(playerCache.flora_A).to.equal(0.20)

			-- (2) Same-pass drop: chunkA removed from loadedChunks (harness-simulated race).
			loadedChunksForPlayer["0_0"] = nil

			-- (3) Subsequent-pass re-add: field has moved on (flora_A now 0.75) -- a FRESH
			-- snapshot must fire, and the cache must reset to the FRESH value, not 0.20.
			local freshSnapshot = StreamingLogic.ComputeChunkFullSnapshot("0_0", { flora_A = 0.75 })
			streamIn(freshSnapshot)

			-- (a) a fresh snapshot fired (second Fire call recorded).
			expect(#fireLog).to.equal(2)
			local secondFiredMap = payloadToMap(fireLog[2])
			expect(almostEqual(secondFiredMap.flora_A, 0.75, 0.001)).to.equal(true)

			-- (b) cache reset to the FRESH snapshot's values, not the stale pre-drop 0.20.
			expect(almostEqual(playerCache.flora_A, 0.75, 0.001)).to.equal(true)
			expect(almostEqual(playerCache.flora_A, 0.20, 0.001)).to.equal(false)

			-- (c) membership is loaded again, immediately (RunChunkStreamIn is synchronous --
			-- recovery is complete within this single call, not merely "eventually").
			expect(loadedChunksForPlayer["0_0"]).to.equal(true)

			-- Consequence of (b): the very next delta check against the reset cache, using the
			-- SAME fresh value, correctly reports "nothing crossed" (gated against the fresh
			-- baseline, not the stale one).
			local nextDelta = StreamingLogic.ComputeChunkDeltaUpdate("0_0", { flora_A = 0.75 }, playerCache, 0.02)
			expect(nextDelta).to.equal(nil)
		end
		it("test_h32d_readd_after_drop_fires_fresh_snapshot_and_resets_cache", function()
			test_h32d_readd_after_drop_fires_fresh_snapshot_and_resets_cache()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (PlayerRemoving cleanup, N=50 bounded size)", function()
		-- AC -- PlayerRemoving cleanup: no memory leak across repeated join/leave cycles (N=50),
		-- table size stays bounded.
		local function test_clear_player_streaming_state_n50_cycles_bounded()
			local loadedChunksByPlayer: { [any]: { [string]: true } } = {}
			local floraDeltaCacheByPlayer: { [any]: FloraDeltaCache } = {}

			local function countKeys(t: { [any]: any }): number
				local count = 0
				for _ in t do
					count += 1
				end
				return count
			end

			for _ = 1, 50 do
				local fakePlayer = {} -- opaque identity stand-in, mirrors this codebase's own precedent
				-- "join": populate both per-player tables.
				loadedChunksByPlayer[fakePlayer] = { ["0_0"] = true, ["1_1"] = true }
				floraDeltaCacheByPlayer[fakePlayer] = { flora_A = 0.5 }

				expect(countKeys(loadedChunksByPlayer)).to.equal(1)
				expect(countKeys(floraDeltaCacheByPlayer)).to.equal(1)

				-- "leave": PlayerRemoving cleanup.
				StreamingLogic.ClearPlayerStreamingState(loadedChunksByPlayer, floraDeltaCacheByPlayer, fakePlayer)

				expect(countKeys(loadedChunksByPlayer)).to.equal(0)
				expect(countKeys(floraDeltaCacheByPlayer)).to.equal(0)
			end
		end
		it("test_clear_player_streaming_state_n50_cycles_bounded", function()
			test_clear_player_streaming_state_n50_cycles_bounded()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (zero-Client / zero-require structural check)", function()
		-- Mirrors every sibling *Logic module's own structural precedent (Story 005/007/008): this
		-- module never references DisturbanceService.Client or require() at all.
		local function stripLuaComments(source: string): string
			local strippedLines = {}
			for line in (source .. "\n"):gmatch("([^\n]*)\n") do
				local codeOnly = line:match("^(.-)%-%-") or line
				table.insert(strippedLines, codeOnly)
			end
			return table.concat(strippedLines, "\n")
		end

		local function test_module_has_zero_client_or_knit_references()
			local source = stripLuaComments(fs.readFile("src/gameplay/services/DisturbanceServiceStreamingLogic.luau"))
			expect(source:find("%.Client")).to.equal(nil)
			expect(source:find("require%(")).to.equal(nil)
		end
		it("test_module_has_zero_client_or_knit_references", function()
			test_module_has_zero_client_or_knit_references()
		end)
	end)

	describe("DisturbanceServiceStreamingLogic -- Story 014 (H.31b security lint, BLOCKING)", function()
		-- H.31b (BLOCKING): zero occurrences of "ReplicationFocus", zero GetPropertyChangedSignal,
		-- zero direct Player.ReplicationFocus reads, anywhere in this story's own files.
		--
		-- RAW-SOURCE DECISION (documented, per this story's own fragile-pattern guidance): this
		-- check scans the RAW (unstripped) source, deliberately -- H.31b's own AC text states
		-- "zero occurrences of `ReplicationFocus`" with no comment carve-out, and this is a
		-- BLOCKING security lint. A comment that merely NAMES "ReplicationFocus" as a forbidden
		-- API (e.g. explaining the rule) would also fail this strict raw-source check -- accepted
		-- deliberately, since the safest possible zero-occurrences bar for a security-class lint
		-- is to never let the literal string appear at all, forcing any future discussion of this
		-- API to happen in a design doc, not in this story's own source files.
		local function test_zero_replicationfocus_or_property_polling_in_streaming_files()
			local streamingLogicSource = fs.readFile("src/gameplay/services/DisturbanceServiceStreamingLogic.luau")
			local serviceSource = fs.readFile("src/gameplay/services/DisturbanceService.luau")

			for _, source in { streamingLogicSource, serviceSource } do
				expect(source:find("ReplicationFocus")).to.equal(nil)
				expect(source:find("GetPropertyChangedSignal")).to.equal(nil)
			end
		end
		it("test_zero_replicationfocus_or_property_polling_in_streaming_files", function()
			test_zero_replicationfocus_or_property_polling_in_streaming_files()
		end)

		-- Position-polling-loop proxy (documented limitation): DisturbanceService.luau's ONLY
		-- position reads are single-shot per-call HumanoidRootPart.Position reads (mirroring
		-- GetSquadAggregateT's own established precedent), never a manual busy-wait loop. This
		-- codebase drives ALL periodic work through RunService.Heartbeat:Connect (already used
		-- elsewhere in this file), never a hand-rolled `while true do ... task.wait() ... end`
		-- polling loop -- confirmed structurally: zero occurrences of that loop shape in the file.
		local function test_no_manual_polling_loop_in_disturbance_service()
			local serviceSource = fs.readFile("src/gameplay/services/DisturbanceService.luau")
			expect(serviceSource:find("while%s+true%s+do")).to.equal(nil)
		end
		it("test_no_manual_polling_loop_in_disturbance_service", function()
			test_no_manual_polling_loop_in_disturbance_service()
		end)
	end)

	describe("DisturbanceService.luau -- Story 014 (KnitInit wiring, static/structural checks)", function()
		local disturbanceServiceSource: string? = nil

		local function loadSource(): string
			if not disturbanceServiceSource then
				disturbanceServiceSource = fs.readFile("src/gameplay/services/DisturbanceService.luau")
			end
			return disturbanceServiceSource :: string
		end

		local function test_flora_delta_cache_constructed_as_empty_literal_in_knit_init()
			local source = loadSource()
			expect(source:find("self%._floraDeltaCache = {} ::")).never.to.equal(nil)
		end
		it("test_flora_delta_cache_constructed_as_empty_literal_in_knit_init", function()
			test_flora_delta_cache_constructed_as_empty_literal_in_knit_init()
		end)

		local function test_both_raw_remote_events_constructed_in_knit_init()
			local source = loadSource()
			expect(source:find('Instance%.new%("RemoteEvent"%)')).never.to.equal(nil)
			expect(source:find('self%._floraChunkUpdateEvent%.Name = "FloraChunkUpdate"')).never.to.equal(nil)
			expect(source:find('self%._floraChunkInitialSnapshotEvent%.Name = "FloraChunkInitialSnapshot"')).never.to.equal(nil)
		end
		it("test_both_raw_remote_events_constructed_in_knit_init", function()
			test_both_raw_remote_events_constructed_in_knit_init()
		end)

		-- AC -- zero OnServerEvent (REQUIRED, N5): both RemoteEvents register ZERO
		-- OnServerEvent callbacks anywhere in this file.
		local function test_zero_onserverevent_registrations_for_flora_events()
			local source = loadSource()
			expect(source:find("FloraChunkUpdate.-OnServerEvent")).to.equal(nil)
			expect(source:find("FloraChunkInitialSnapshot.-OnServerEvent")).to.equal(nil)
			expect(source:find("_floraChunkUpdateEvent%.OnServerEvent")).to.equal(nil)
			expect(source:find("_floraChunkInitialSnapshotEvent%.OnServerEvent")).to.equal(nil)
			expect(source:find("%.OnServerEvent")).to.equal(nil) -- this file registers NO OnServerEvent at all
		end
		it("test_zero_onserverevent_registrations_for_flora_events", function()
			test_zero_onserverevent_registrations_for_flora_events()
		end)

		-- AC -- PlayerRemoving clears BOTH self._loadedChunks[player] AND
		-- self._floraDeltaCache[player], within the SAME existing handler (this file's own
		-- established single-shared-connection pattern, not a second separate :Connect() call).
		local function test_player_removing_clears_both_loaded_chunks_and_flora_delta_cache_in_same_handler()
			local source = loadSource()
			local handlerStart = source:find("Players%.PlayerRemoving:Connect%(function%(player: Player%)")
			expect(handlerStart).never.to.equal(nil)
			-- The handler is nested one level inside KnitStart -- its closing "end)" is
			-- TAB-indented (matching the "Connect(" call's own 1-tab indent), not at column 0.
			-- Verified against this file's real indentation first (known fragile pattern:
			-- "\nend%)" with no leading tab would never match here).
			local handlerEnd = source:find("\n\tend%)", handlerStart :: number)
			expect(handlerEnd).never.to.equal(nil)
			local handlerBody = source:sub(handlerStart :: number, handlerEnd :: number)

			expect(handlerBody:find("self%._loadedChunks%[player%] = nil")).never.to.equal(nil)
			expect(handlerBody:find("self%._floraDeltaCache%[player%] = nil")).never.to.equal(nil)

			-- Only ONE Players.PlayerRemoving:Connect call exists in the whole file (the shared
			-- handler this story's own cleanup line was added to, not a second stacked connection).
			local occurrences = 0
			local searchStart = 1
			while true do
				local matchIndex = source:find("Players%.PlayerRemoving:Connect%(", searchStart)
				if not matchIndex then
					break
				end
				occurrences += 1
				searchStart = matchIndex + 1
			end
			expect(occurrences).to.equal(1)
		end
		it(
			"test_player_removing_clears_both_loaded_chunks_and_flora_delta_cache_in_same_handler",
			function()
				test_player_removing_clears_both_loaded_chunks_and_flora_delta_cache_in_same_handler()
			end
		)

		-- Wiring confirmation: _runFieldUpdatePass calls the new streaming push-pass method
		-- (never re-implementing the push logic inline inside _runFieldUpdatePass itself).
		local function test_run_field_update_pass_calls_streaming_push_pass()
			local source = loadSource()
			local startIndex = source:find("function DisturbanceService:_runFieldUpdatePass%(%)")
			expect(startIndex).never.to.equal(nil)
			local endIndex = source:find("\nend", startIndex :: number)
			local body = source:sub(startIndex :: number, endIndex)
			expect(body:find("self:_runStreamingChunkPushPass%(%)")).never.to.equal(nil)
		end
		it("test_run_field_update_pass_calls_streaming_push_pass", function()
			test_run_field_update_pass_calls_streaming_push_pass()
		end)

		-- Wiring confirmation: _isChunkLoadedForPlayer/_onChunkStreamIn exist and delegate to the
		-- pure StreamingLogic module, never re-implementing the math/ordering locally.
		local function test_isChunkLoadedForPlayer_and_onChunkStreamIn_delegate_to_pure_module()
			local source = loadSource()
			expect(source:find("function DisturbanceService:_isChunkLoadedForPlayer%(")).never.to.equal(nil)
			expect(source:find("StreamingLogic%.IsChunkLoadedForPosition%(")).never.to.equal(nil)
			expect(source:find("StreamingLogic%.ChunkCenterFor%(")).never.to.equal(nil)

			expect(source:find("function DisturbanceService:_onChunkStreamIn%(")).never.to.equal(nil)
			expect(source:find("StreamingLogic%.RunChunkStreamIn%(")).never.to.equal(nil)

			expect(source:find("require%(script%.Parent%.DisturbanceServiceStreamingLogic%)")).never.to.equal(nil)
		end
		it(
			"test_isChunkLoadedForPlayer_and_onChunkStreamIn_delegate_to_pure_module",
			function()
				test_isChunkLoadedForPlayer_and_onChunkStreamIn_delegate_to_pure_module()
			end
		)

		-- Membership-gated delivery is wired via the pure module's fire-time re-check, not a
		-- locally re-implemented boolean check.
		local function test_streaming_push_pass_uses_fire_if_still_member()
			local source = loadSource()
			expect(source:find("StreamingLogic%.FireIfStillMember%(")).never.to.equal(nil)
		end
		it("test_streaming_push_pass_uses_fire_if_still_member", function()
			test_streaming_push_pass_uses_fire_if_still_member()
		end)

		-- Server-internal-only: none of this story's new methods are exposed via .Client (this
		-- file's `Client = {}` table stays empty, matching every sibling story's own precedent).
		local function test_no_new_client_surface_introduced()
			local source = loadSource()
			expect(source:find("Client = {}")).never.to.equal(nil)
			expect(source:find("DisturbanceService%.Client%.")).to.equal(nil)
			expect(source:find("self%.Client%.")).to.equal(nil)
		end
		it("test_no_new_client_surface_introduced", function()
			test_no_new_client_surface_introduced()
		end)
	end)
end
