# Story 017: Performance Instrumentation & Ops-Log Observability

> **Epic**: Ecological Disturbance
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-014` (`DisturbanceService_Update` budget ≤1.43ms avg/2.86ms p99), `TR-ed-015` (`DisturbanceService_HotspotQuery` ≤1ms avg/2ms p99), `TR-ed-016` (two `debug.profilebegin` fences, 11 workloads nested), `TR-ed-021` (cap-formula full-scan cost measured inside stress budget), `TR-ed-022` (query-position count anchoring), `TR-ed-023` (PERF-DEVICE budgets valid only at `FIELD_UPDATE_HZ=5` and `activeBeacons≤3`), `TR-ed-024` (memory ceiling <1GB, session-scoped), `TR-ed-057` (iPhone SE-class binding floor), `TR-ed-058` (touch tap-toggle telemetry split by input method), `TR-ed-059` (`BEACON_CUMULATIVE_DISTANCE_THRESHOLD` provisional)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: N7/N8 ops-log decisions (settled): N7 — when live-source count exceeds 207 for a sustained >30s window, log a pathological-zone warning; N8 — when the graceful-skip catch-up triggers, log a Heartbeat-floor-freeze event. Both observability-only, neither changes runtime behavior.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: HIGH
**Engine Notes**: PERF-DEVICE testing requires a physical iPhone SE-class device (or accurate ARM simulator) and the Studio-local-server MicroProfiler capture workflow — a Studio-simulator-only run on a dev machine is INVALID evidence for these ACs (does not reproduce the ARM CPU/GPU profile). This is a live-platform risk: MicroProfiler capture cannot be exported headlessly; captures must be manually saved as evidence.

**Control Manifest Rules (Core layer)**:
- Guardrail: `GetHottestHotspot`/`fieldValue()` touch only ~4–9 grid cells per query — source: ADR-0004
- Guardrail: `OnDisturbanceAlert` rate-limited to 5 fires/sec per player; simultaneous same-pass tier-crossings coalesce into one payload — source: ADR-0004
- Guardrail: Character-replication baseline provisional 15–30 KB/s per client before any game-code signals; every system's bandwidth budget must be re-derived from `(50 KB/s − measured baseline)` once the real figure is known — source: ADR-0008

---

## Acceptance Criteria

- [ ] **H.36a** — GIVEN the implementation, WHEN a code search for `debug.profilebegin("DisturbanceService_Update")` and `debug.profilebegin("DisturbanceService_HotspotQuery")` runs, THEN both are present and balanced with `debug.profileend()`. The `_Update` region MUST enclose ALL 11 listed workloads: (1) per-source decay cache; (2) field-value eval at flora positions; (3) field-value eval at player positions; (4) tier-classification + `TierCrossedEvent` firing; (5) per-player ring-buffer maintenance; (6) per-beacon cap-state evaluation; (7) per-player cap-state discriminant computation; (8) per-player teleport-discontinuity detection; (9) `OnMeterUpdate` per-player Fire; (10) squad-aggregate band-crossing check; (11) attribution-archive maintenance. The `_HotspotQuery` region MUST enclose the `GetHottestHotspot` body.
- [ ] **N7 ops-log**: when the live-source count exceeds 207 for a sustained >30s window, log a pathological-zone warning tagged with current count and duration. A simple watchdog: record the timestamp the count first exceeded 207; if still exceeded 30s later, emit; reset the timestamp once the count drops back under 207.
- [ ] **N8 ops-log**: when the graceful-skip catch-up (Story 001's accumulator) triggers, log a Heartbeat-floor-freeze event tagged with the actual elapsed time vs. the expected interval.
- [ ] **H.36** — GIVEN a 4-player Hunt-state session (60s elapsed) AND H.36a instrumentation, testing BOTH Variant 1 (Beacon-inactive worst-case, ~207 live sources, no beacon, archive pre-seeded to 4000) and Variant 2 (Beacon-active worst-case, all 4 players stationary ~138-source population, 3 active beacons), AND ≥10 minutes running before each sample window, AND a 5-second MicroProfiler sample per variant on iPhone SE-class device, THEN for BOTH variants: average `DisturbanceService_Update` cost ≤1.43ms per cycle and 99th-percentile ≤2.86ms per cycle. A failure on EITHER Variant fails the AC. Scope clause: PASS valid ONLY when `activeBeacons ≤ 3` AND `FIELD_UPDATE_HZ = 5Hz`.
- [ ] **H.37** — GIVEN the same session as H.36 with 4 loaded chunks AND an assumed ≤30 KB/s engine-replication baseline, WHEN `FloraChunkUpdate` RemoteEvents fire over 5s, THEN total disturbance-signal outbound bandwidth per client does not exceed 20 KB/s.
- [ ] **H.37b** — GIVEN four mock clients connect simultaneously (100ms window), each streaming in 8 chunks × `MAX_FLORA_PER_CHUNK`, WHEN `FloraChunkInitialSnapshot` fires per (client×chunk) pair, THEN total burst traffic per client completes within 1000ms of `PlayerAdded` AND burst-second bandwidth per client does not exceed 30 KB/s instantaneous.
- [ ] **H.38** — GIVEN `MAX_LIVE_SOURCES` distributed such that no cell holds more than ~40 sources AND at least one cell holds ~40 (natural-stationary-cluster case) AND a mock predator calls `GetHottestHotspot` at 4Hz over a 5-second window, WHEN MicroProfiler captures the sample, THEN average `DisturbanceService_HotspotQuery` cost ≤1ms per call and 99th-percentile ≤2ms per call.
- [ ] **H.38b** — GIVEN synthetic injection fills ONE 32-stud grid cell with 200+ live sources at varied ages (total map-wide 500) AND a mock predator queries at 4Hz, WHEN MicroProfiler captures a 5-second sample, THEN average combined `_Update + _HotspotQuery` cost ≤4ms per cycle. Fixture extension includes THREE active Beacon emissions with the stationary-squad cap engaged on at least one, measuring the C.3.6 step-6 summation (3×500=1,500 evaluations/pass) inside the same 4ms ceiling.
- [ ] Memory ceiling: session-scoped field discarded at run-end; live-source list bounded at 500 entries; attribution archive bounded at `MAX_ATTRIBUTION_ARCHIVE_ENTRIES`.
- [ ] The `H.PB1-BETA` criterion (iv) `FAIL-iv-server` telemetry seam: `_setExtendedStationarySegmentActive(active: boolean)` (server-internal only) gates per-pass CSV telemetry-row emission (`pass_index`, `pass_timestamp_seconds`, `squad_t`, `predator_state`, `pre_segment_profile`, `session_id`) to `production/qa/evidence/HPB1-BETA-iv-server-telemetry-[session-id].csv`, active ONLY during the extended-stationary-squad observation segment (≥60s window). This story implements the seam and CSV-emission mechanism; the Beta harness itself (invoking the seam, running the actual playtest) is a later production-phase activity, out of this story's scope.

---

## Implementation Notes

Instrumentation shape (H.36a, cite the structural requirement — do not guess at exact profilebegin string names beyond what's specified):
```luau
function DisturbanceService:_runFieldUpdatePass()
    debug.profilebegin("DisturbanceService_Update")
    -- (1) per-source decay cache
    -- (2) field-value eval at flora positions
    -- (3) field-value eval at player positions
    -- (4) tier-classification + TierCrossedEvent firing
    -- (5) per-player ring-buffer maintenance
    -- (6) per-beacon cap-state evaluation
    -- (7) per-player cap-state discriminant computation
    -- (8) per-player teleport-discontinuity detection
    -- (9) OnMeterUpdate per-player Fire
    -- (10) squad-aggregate band-crossing check
    -- (11) attribution-archive maintenance
    debug.profileend()
end

function DisturbanceService:GetHottestHotspot(callerPosition, searchRadius, minimumTier)
    debug.profilebegin("DisturbanceService_HotspotQuery")
    -- ... D.6 body ...
    debug.profileend()
end
```
N7 watchdog (cite the shape):
```luau
if #self._liveSources > 207 then
    self._pathologicalZoneSince = self._pathologicalZoneSince or workspace:GetServerTimeNow()
    if workspace:GetServerTimeNow() - self._pathologicalZoneSince > 30 then
        warn(("DisturbanceService: pathological live-source count %d sustained >30s"):format(#self._liveSources))
    end
else
    self._pathologicalZoneSince = nil
end
```
PERF-DEVICE test evidence is fundamentally different from the automated unit/integration tests elsewhere in this epic — it requires a physical device and a manually-saved MicroProfiler capture. Per this project's testing standards, treat H.36/H.37/H.38/H.38b as **advisory-tier evidence** (a dated evidence doc with the MicroProfiler capture screenshot/export + a PASS/FAIL note), analogous to the Visual/Feel evidence tier, even though this story's Type is classified Logic for the deterministic instrumentation-presence checks (H.36a is AUTO-UNIT and IS blocking).

---

## Out of Scope

- Every other story's own correctness (this story only wraps existing logic in profiling fences and adds observability logging — it must not change any behavior).
- The actual Beta-milestone playtest execution for H.PB1-BETA (this story only builds the telemetry seam and CSV-writer; running the playtest is a later production-phase activity).
- `STREAMING_PUSH_RADIUS` tuning (Story 014's concern, cross-referenced here only for the bandwidth budget interaction).

---

## QA Test Cases

- **AC-H.36a**: Given: the implementation's source — When: greped for the two named `debug.profilebegin` calls — Then: both present, each balanced with a `debug.profileend()`; the `_Update` fence lexically encloses all 11 named workload comments/call-sites. Edge case: a workload accidentally placed OUTSIDE the `_Update` fence (e.g., a refactor that moves attribution-archive maintenance to a separate un-fenced function) must cause this AC to fail — verify via a deliberately-broken positive control.
- **AC — N7 ops-log**: Given: a simulated live-source count held at 250 for 35 seconds via the test-clock seam — When: the watchdog evaluates each pass — Then: a warning fires once around the 30s mark, tagged with count=250 and duration≈30s. Edge case: count drops to 200 at 25s, then rises back to 250 — the 30s timer must RESET at the drop, not continue accumulating from the original timestamp.
- **AC — N8 ops-log**: Given: a simulated Heartbeat `dt` exceeding the update interval (server hitch) — When: the graceful-skip catch-up triggers — Then: a log entry fires with the actual elapsed time vs. expected interval.
- **AC-H.36**: Given: a 4-player Hunt-state session on physical iPhone SE-class hardware, ≥10 minutes warmup, both Variant 1 and Variant 2 fixtures — When: MicroProfiler captures a 5-second sample per variant — Then: BOTH variants show avg `DisturbanceService_Update` ≤1.43ms, p99 ≤2.86ms. Edge case: a Studio-simulator-only run (no physical device) is INVALID evidence — the evidence doc must explicitly record the device used.
- **AC-H.37**: Given: the H.36 session with 4 loaded chunks — When: `FloraChunkUpdate` bandwidth is measured over 5s — Then: per-client disturbance-signal bandwidth ≤20 KB/s.
- **AC-H.37b**: Given: 4 simultaneous joins within a 100ms window, each streaming 8 chunks × `MAX_FLORA_PER_CHUNK` — When: initial snapshots fire — Then: burst completes within 1000ms of `PlayerAdded`; burst-second bandwidth ≤30 KB/s per client.
- **AC-H.38**: Given: a clustered-but-not-pathological source distribution (~40/cell max) and a 4Hz-querying mock predator — When: sampled over 5s — Then: avg `_HotspotQuery` ≤1ms, p99 ≤2ms.
- **AC-H.38b**: Given: one cell synthetically filled with 200+ sources (500 total map-wide), 3 active beacons with cap engaged on ≥1, 4Hz querying predator — When: sampled over 5s — Then: avg combined `_Update + _HotspotQuery` ≤4ms.
- **AC — H.PB1-BETA telemetry seam**: Given: `_setExtendedStationarySegmentActive(true)` called — When: field-update passes run during the active window — Then: CSV rows are written with all 6 named fields to the session-specific evidence file. Given: `_setExtendedStationarySegmentActive(false)` — When: passes run — Then: no CSV rows are emitted. Edge case: the seam is verified server-internal only (not on `.Client`) — cross-reference Story 016's H.39c for the mechanical enforcement.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/performance-instrumentation-observability_test.luau` (covers H.36a instrumentation-presence, N7/N8 ops-log logic, and the telemetry seam — all deterministic/automatable) PLUS `production/qa/evidence/H36-H38b-perf-device-[date].md` (PERF-DEVICE evidence doc with MicroProfiler captures, advisory-tier, requires physical iPhone SE-class device per the Test Infrastructure Prerequisites table)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 003, 005, 006, 007, 008, 013, 014, 015
- Unlocks: None (final story in the epic)
