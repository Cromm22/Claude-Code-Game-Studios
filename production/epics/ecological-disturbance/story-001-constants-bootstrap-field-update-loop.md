# Story 001: Constants Module, Service Bootstrap & 5Hz Field-Update Loop Driver

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 1.0 day
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-026` (5Hz field-update loop, accumulator + graceful-skip catch-up), `TR-ed-036` (KnitInit config-validation fatal error), `TR-ed-047` (cross-GDD constant locks), `TR-ed-049` (session-scoped field, no persistence), `TR-ed-053` (KnitInit/KnitStart ordering discipline)
**ADR Governing Implementation**: ADR-0001 (KnitInit/KnitStart Ordering Discipline), ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: "`KnitInit` builds, `KnitStart` connects" — every cross-service-visible object (spatial grid, live-source list, attribution archive, `OnPlayerDied` BindableEvent, RegistrationHandshake module, `loadedChunks` table) is constructed empty during `KnitInit`; the 5Hz field-update Heartbeat loop itself begins in `KnitStart`. Config-validation hard errors at `KnitInit` MUST be paired with a bootstrap `catch` handler that calls `game:Shutdown()`.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: HIGH
**Engine Notes**: `require()` module-cache singleton identity is unverified against the pinned Studio/Knit build — a Studio spike (two-ModuleScript `require()` round-trip, confirm identity equality) MUST run before this story is considered done, per ADR-0001's Risks section. `RegistrationHandshake` modules must only be `require()`d from the default serial Luau script context, never from an `Actor`. The common Knit bootstrap boilerplate (`Knit.Start():andThen(print):catch(warn)`) only **logs** a rejected `KnitInit` promise and does NOT halt the server — the project's `ServerInit.server.luau` MUST use a `catch` handler that calls `game:Shutdown()` (or equivalent hard-stop), per ADR-0005's engine-specialist finding, binding project-wide.

**Control Manifest Rules (Foundation/Core layers)**:
- Required: "`KnitInit` builds, `KnitStart` connects" — any object another service might synchronously read/call during its own `KnitStart` MUST be fully constructed inside the owning service's `KnitInit` — source: ADR-0001
- Required: Any `KnitInit`-time config-validation hard error (`error()`) MUST be paired with a server bootstrap `catch` handler that calls `game:Shutdown()` — source: ADR-0005
- Forbidden: Never construct a cross-service-visible object inside `KnitStart` — source: ADR-0001
- Forbidden: Never fork or wrap Knit's own `Start()` with a custom centralized bootstrap phase — source: ADR-0001
- Guardrail: Knit lifecycle overhead is negligible, one-time cost at server boot, not per-frame — source: ADR-0001

---

## Acceptance Criteria

- [ ] A single `--!strict` constants module publishes every G-section tuning knob (`TENSE_THRESHOLD=0.30`, `HUNT_THRESHOLD=0.65`, `HYSTERESIS_BAND=0.03`, `STANDARD_HALF_LIFE=30`, `BEACON_HALF_LIFE=90`, `MAGNITUDE_FLOOR=0.02`, `INFLUENCE_RADIUS=24`, `HOTSPOT_DEDUP_GRID_SIZE=4`, `SPATIAL_GRID_CELL_SIZE=32`, `FIELD_UPDATE_HZ=5`, `FLORA_UPDATE_DELTA_THRESHOLD=0.02`, `EXPIRY_MAINTENANCE_INTERVAL=3`, `MAX_LIVE_SOURCES=500`, `ATTRIBUTION_ARCHIVE_TTL=1200`, `MAX_ATTRIBUTION_ARCHIVE_ENTRIES=4000`, `MAX_FLORA_PER_CHUNK=8`, `CHUNK_DIMENSIONS=64`, all G.5 magnitude/pulse knobs) with no hardcoded literal duplicating these values anywhere else in the service (coding-standards.md: "Gameplay values must be data-driven").
- [ ] **H.3d** — GIVEN `INFLUENCE_RADIUS` is configured to 0 or a negative value, WHEN `DisturbanceService:KnitInit()` runs at server startup, THEN the service refuses to start and raises a fatal error identifying the misconfigured constant.
- [ ] **H.3e** — GIVEN `SPATIAL_GRID_CELL_SIZE` is configured strictly less than `INFLUENCE_RADIUS` (e.g., cell=16, radius=24), WHEN `DisturbanceService:KnitInit()` runs, THEN the service refuses to start and raises a fatal error identifying the violation of the G.7 invariant `SPATIAL_GRID_CELL_SIZE >= INFLUENCE_RADIUS`.
- [ ] `DisturbanceService:KnitInit()` constructs, empty: the spatial hash grid, the live-source list, the attribution archive, the `OnPlayerDied` BindableEvent (see Story 010 for its full dispatch logic — this story only constructs the empty channel and pins `Workspace.SignalBehavior = Enum.SignalBehavior.Immediate` at boot), the RegistrationHandshake module reference, and `loadedChunks: {[Player]: {[chunkId]: true}}`.
- [ ] `DisturbanceService:KnitStart()` begins the field-update loop: driven by `RunService.Heartbeat` with a manual time-accumulator (`task.wait` loops forbidden — they drift under server load), firing the update pass at the `FIELD_UPDATE_HZ` interval (default 5 Hz / 0.2 s).
- [ ] **Heartbeat catch-up semantics (C.1.13, REQUIRED)**: when `RunService.Heartbeat` fires with `dt` greater than the update interval (e.g., dt=0.5s while interval=0.2s), the accumulator pattern fires the update pass **at most once per Heartbeat callback**, then resets remaining accumulated debt to zero. Catch-up loops (firing twice/three times in one Heartbeat to consume debt) are FORBIDDEN.
- [ ] The service bootstrap (`ServerInit.server.luau`) wraps `Knit.Start()` with `:andThen(...):catch(function(err) warn(err); game:Shutdown() end)` — a `catch(warn)`-only boilerplate does not satisfy this criterion.
- [ ] The disturbance field is session-scoped: created at run start, discarded at run-end, no cross-run persistence, no `DataStoreService` interaction anywhere in this service (TR-ed-049).

---

## Implementation Notes

Per ADR-0004's Architecture Diagram, `KnitInit` constructs (in order, all empty):
```
DisturbanceService
├── KnitInit:
│     - spatial hash grid (empty, cell-size 32)
│     - live-source list (empty)
│     - attribution archive (empty, cap MAX_ATTRIBUTION_ARCHIVE_ENTRIES)
│     - OnPlayerDied BindableEvent (raw BindableEvent per GDD's frozen C.1.11 — NOT Knit Signal)
│     - Humanoid.Died chain registration (Players.PlayerAdded → CharacterAdded → Died) — see Story 010
│     - RegistrationHandshake module reference — see Story 011
│     - loadedChunks: {[Player]: {[chunkId]: true}}
├── KnitStart:
│     - field-update Heartbeat loop begins (decay pass + N7/N8 monitoring — see Story 017)
```
Only this story's scope is: the constants module, the empty-container construction, the config-validation gates (H.3d/H.3e), the `Workspace.SignalBehavior` pin, the Heartbeat accumulator driving the update-pass call site (the *body* of the update pass — decay, tier classification, etc. — is built out across Stories 003–015; this story just guarantees the loop exists and calls into a (initially empty/no-op) `_runFieldUpdatePass()` method that later stories extend), and the bootstrap `catch` → `game:Shutdown()` wiring.

`Workspace.SignalBehavior = Enum.SignalBehavior.Immediate` must be set **before any `KnitInit` runs**, per ADR-0004's `OnPlayerDied` channel-type Decision — this is a one-line, one-time server-boot assertion, not a per-call cost.

**Performance**: the Heartbeat-bound accumulator this story establishes costs a single float comparison per Heartbeat frame while `_runFieldUpdatePass()` stays empty/no-op — negligible, no measurable per-frame impact from this story's own scope. The actual per-pass workload this loop will drive once Stories 003–015 extend `_runFieldUpdatePass()` is Story 017's own budgeted concern (`DisturbanceService_Update` ≤1.43ms avg / 2.86ms p99) — not a performance obligation of this story.

Config-validation idiom (from ADR-0005's parallel pattern, binding project-wide):
```luau
function DisturbanceService:KnitInit()
    if INFLUENCE_RADIUS <= 0 then
        error(("DisturbanceService: INFLUENCE_RADIUS misconfigured: %.2f <= 0"):format(INFLUENCE_RADIUS))
    end
    if SPATIAL_GRID_CELL_SIZE < INFLUENCE_RADIUS then
        error(("DisturbanceService: SPATIAL_GRID_CELL_SIZE (%.1f) < INFLUENCE_RADIUS (%.1f) — violates G.7 invariant")
            :format(SPATIAL_GRID_CELL_SIZE, INFLUENCE_RADIUS))
    end
    -- ... construct empty containers ...
end
```
And the bootstrap file:
```luau
Knit.Start():andThen(function() print("Knit started") end):catch(function(err)
    warn(err)
    game:Shutdown()
end)
```

---

## Out of Scope

- Story 002: `Emit()` intake logic and schema validation (this story only constructs the empty live-source list container).
- Story 003: spatial grid insertion/removal/query logic (this story only allocates the empty grid).
- Story 004: attribution archive TTL/cap-eviction logic (this story only allocates the empty archive).
- Story 010: `Humanoid.Died` subscription chain body and `OnPlayerDied` fan-out dispatch (this story only constructs the empty BindableEvent and pins `SignalBehavior`).
- Story 011: RegistrationHandshake module's actual export functions (this story only establishes that the module exists and is `require()`-acquired during `KnitInit`).
- Story 017: N7/N8 ops-log monitoring logic that runs inside the Heartbeat loop (this story only establishes the loop's accumulator skeleton).

---

## QA Test Cases

- **AC — H.3d**: GIVEN `INFLUENCE_RADIUS` configured to 0 or negative — When: `DisturbanceService:KnitInit()` runs at server startup — Then: service refuses to start, fatal error identifies the misconfigured constant. Edge cases: exactly 0; a large negative value; a non-numeric misconfiguration (should also fail-fast at the type level under `--!strict`).
- **AC — H.3e**: GIVEN `SPATIAL_GRID_CELL_SIZE` strictly less than `INFLUENCE_RADIUS` (cell=16, radius=24) — When: `KnitInit()` runs — Then: error identifies the G.7 invariant violation. Edge cases: exactly equal (cell == radius, should PASS — invariant is `>=`); cell one unit below radius (should FAIL).
- **AC — Heartbeat catch-up semantics**: Given: a mocked `RunService.Heartbeat:Fire(dt)` with `dt = 0.5s` while the interval is 0.2s — When: the accumulator processes the Heartbeat callback — Then: the update pass body is invoked exactly once (not 2, not 3 times), and the accumulator's residual debt resets to zero rather than carrying forward. Edge cases: `dt` exactly equal to the interval (fires once, no residual); `dt = 0` (no fire); a string of many small `dt`s that sum past the interval (fires once per crossing, standard accumulator behavior, not the graceful-skip branch).
- **AC — bootstrap catch → Shutdown**: Given: a test double for `Knit.Start()` that rejects its promise — When: the bootstrap script's `:catch(...)` handler runs — Then: `game:Shutdown` (or the test's spy for it) is invoked exactly once, in addition to `warn(err)`. Edge case: verify a `catch(warn)`-only variant is rejected by code review (STATIC check, not a runtime test — this is enforceable by grep for `catch(warn)` alone without an adjacent `Shutdown` call).
- **AC — session-scoped field**: Given: a completed run (`RunEnded` fires) — When: a new run begins — Then: the live-source list, spatial grid, and attribution archive are all empty at the start of the new session; no `DataStoreService` call appears anywhere in the service's source.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ecological-disturbance/service-bootstrap-config-validation_test.luau` — must exist and pass
**Status**: [x] Created and passing — verified 2026-07-07 via `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` (exit code 0, 3/3 test files pass, 0 failures). Two real bugs found and fixed during verification: (1) the test harness's mock `expect()` matcher used colon self-sugar incompatible with this project's dot-chained assertion style, silently discarding every comparison argument; (2) this story's own `test_no_datastoreservice_reference_anywhere_in_source` did a naive whole-word grep that false-positived on `DisturbanceService.luau`'s own explanatory comment — narrowed to check for actual `GetService("DataStoreService")` usage.

---

## Dependencies

- Depends on: None
- Unlocks: 002, 003, 004, 010, 011, 014

---

## Completion Notes
**Completed**: 2026-07-07
**Criteria**: 8/8 passing
**Deviations**: None. One architectural violation was found and fixed during `/code-review` (`default.project.json` did not sync `src/core/ServerBootstrap.luau`, so `require()` would have failed at real server boot — fixed by mapping `src/core` as a folder instead of a single-file leaf).
**Test Evidence**: Integration: `tests/integration/ecological-disturbance/service-bootstrap-config-validation_test.luau` — created and genuinely executed passing (`.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration`, exit code 0, 3/3 files, 0 failures). Two additional bugs surfaced and fixed during this verification pass: a test-harness `expect()` matcher argument-binding bug (affected all three test files project-wide, not specific to this story), and this story's own overly-naive `DataStoreService` grep check (false-positived on an explanatory comment).
**Code Review**: Complete (`/code-review`, this session) — one ARCHITECTURAL VIOLATION found and fixed; QA testability review found non-blocking coverage gaps (Heartbeat-wiring untested, `RegistrationHandshake` require()-ability untested, `PlayerRemoving` cleanup untested/unflagged) — recommended as follow-up, not closed this story.
**Known follow-ups** (non-blocking, tracked here for visibility): the `RunService.Heartbeat:Connect` wiring itself has no test coverage even indirectly (only the `StepAccumulator` math it calls is tested); `DisturbanceServiceRegistrationHandshake`'s require()-ability is untested and not mounted in the test harness; `Players.PlayerRemoving` → `_loadedChunks` cleanup is untested; the "no duplicate literal" half of the constants AC has no automated regression guard. The `require()` module-cache singleton identity mechanism (ADR-0001) remains unverified against a live Roblox Studio build — a Studio spike is still required before Story 011's real RegistrationHandshake exports are trusted in production.
