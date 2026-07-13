# Ecological Disturbance — Verification & Test Engineering

> Companion to `design/gdd/ecological-disturbance.md`. Decomposed by content type on 2026-05-30 (relocation only — **no contract text changed**; behavioural Acceptance-Criteria contracts remain in the GDD). Holds the *how-it's-tested* mechanics: test-infrastructure prerequisites and testability flags.
>
> **Round-22 AC-extraction pass (2026-07-04) — EXECUTED.** The embedded CI YAML gates (`h30c-i-evidence-gate.yml`, `h39d-evidence-gate.yml`), the H.30c call-stack nesting diagram, the evidence/review templates (H.30c-i, H.41m-g, H.39d), and the H.39e deferred-queue reference implementation are now extracted here — see **"Relocated from the GDD's Acceptance Criteria section"** below. Relocation only; one-line pointers remain at each original GDD site. H.31b/H.31c were additionally regrouped inside the GDD to follow H.31 (ids unchanged).

> Inline cites within the relocated content below to `C.x` / `D.x` / `H.x` anchors refer to the companion GDD `ecological-disturbance.md`. Inline cites to `F.2a` / `F.2a-IMPORTANT` / `F.2b` resolve to `ecological-disturbance-forward-obligations.md`.

### Test Infrastructure Prerequisites

These blocking infrastructure dependencies must exist before PERF-DEVICE and several AUTO-INTEGRATION ACs can be executed. These are NOT design decisions — they are project-infrastructure stories that must land before this GDD's stories enter sprint:

| Prereq | Required by | Owner | Note |
|--------|-------------|-------|------|
| iPhone SE-class physical test device (or accurate ARM simulator with iPhone SE perf profile) | H.36, H.37, H.38, H.38b | Producer + DevOps | Roblox Studio simulator on a dev machine does NOT reproduce the ARM CPU/GPU profile of a physical device. A simulator-only run is invalid evidence for these ACs. |
| MicroProfiler capture workflow (Studio local-server only — production deploy MicroProfiler is not available) | H.36, H.37, H.38, H.38b | DevOps + gameplay-programmer | Per H.36a, implementation must wrap update loop and hotspot query in named profilebegin tags. Captures cannot be exported headlessly; tester must save MicroProfiler frames manually for evidence. PERF-DEVICE tests run in Studio local-server mode on the physical device, not on deployed Roblox servers. H.37 bandwidth measurement also requires this workflow — outbound packet sampling depends on the same Studio session. |
| 4-simulated-client harness (scripted reproducible 4-player stress scenario) | H.29, H.29b, H.30, H.31, H.36, H.37 | DevOps + qa-lead | Roblox local-server multi-client test mode supports this but requires test scripting that does not exist yet. |
| `MockRemoteSignalRecorder` test fixture (`tests/helpers/network_recorder.luau`) — public API: per-player install, payload capture, Fire-vs-FireAll routing distinction, key-presence assertion, routing assertion (per-player counts) | H.29, H.29b, H.29c, H.30 | qa-lead + gameplay-programmer | Wraps Knit `RemoteSignal:Fire` AND `RemoteSignal:FireAll` to capture wire payloads AND routing for assertion (round-22 B2 fanout correction, applied 2026-07-04: the prior row named `:FireClient`/`:FireAllClients`, which per the GDD C.3.4 round-5 API note are raw-RemoteEvent methods that do NOT exist on Knit RemoteSignal handles — a recorder wrapping those names would intercept nothing and silently pass every privacy assertion). The fixture's API is canonical at the level of these capabilities; concrete signatures live in the helper file itself. |
| `MockTweenService` test fixture (`tests/helpers/tween_recorder.luau`) — records every `TweenService:Create` call with its target Instance, properties, and TweenInfo | H.31 | qa-lead + gameplay-programmer | Required for asserting state-before-tween in the H.31 deterministic check. |
| Test-clock injection seam on `DisturbanceService` (`_setTestClock(fn: (() -> number) -> ())` + `_advanceTestClock(seconds: number)` — declared on the service-internal table, NEVER on `DisturbanceService.Client`) | H.5, H.5b, H.34 | gameplay-programmer | Production code uses `workspace:GetServerTimeNow()` per D.1; the seam exists for deterministic time-dependent tests. H.39c verifies non-Client declaration. |
| Math-fn injection seam on `DisturbanceService` (`_setExpFn(fn: (number) -> number)` — server-internal only) | H.9b | gameplay-programmer | Test-time replacement for `math.exp` to enable the per-pass call counter without monkey-patching the global `math` table (which `--!strict` does not permit cleanly and can pollute concurrent tests). |
| Synthetic-emission injection seam on `DisturbanceService` (`_injectSyntheticEmission(payload: EmissionPayload)` — server-internal only; H.39c verifies non-Client) | H.38b | gameplay-programmer + qa-lead | H.38b's clustered-source worst case is unreachable through the normal `Emit()` path under Q9 stationary attenuation. The seam allows test harness to fill a single grid cell to 200+ sources directly, bypassing schema-rejection and attenuation rules. Production code MUST NOT expose this seam via Knit Client. |
| **`MockOrderingRecorder` test fixture** (`tests/helpers/ordering_recorder.luau` — round-9 addition for Cluster 1 closure) — instruments timestamped event capture across DisturbanceService and partner-service code paths; capabilities: per-event-name install + auto-uninstall in test teardown; per-event timestamp capture using a monotonic in-test counter (NOT `os.clock()` or `tick()`); strict-ordering assertion API (`recorder:AssertOrdering({"event_a", "event_b", "event_c"})`); interleaving-log assertion API (`recorder:AssertNoStateObserved({predicate})`); Heartbeat-boundary detection via `RunService.Heartbeat:Connect`-injected sentinel events; yield-primitive detection via `task.wait` / `task.spawn` / `task.delay` / `coroutine.yield` global wraps installed during `setUp` and removed during `tearDown` (does NOT pollute concurrent tests because the fixture is per-test-instance) | H.30c sub-ACs (e), (h), (i) | qa-lead + gameplay-programmer | Round-9 addition. Required for Cluster 1 (B-CC1-A through B-CC1-E) closure verification. The fixture's API is canonical at the level of these capabilities; concrete signatures live in the helper file itself. The fixture MUST also expose a Knit-init-order randomization helper (`recorder:RandomizeKnitInitOrder(seed)`) used by H.30c sub-AC (h)'s 100-trial harness — this helper monkey-patches Knit's service-creation order during the test's setup phase only, before `Knit.Start()` is invoked. |
| **Field-update-pass seam on `DisturbanceService`** (`_runFieldUpdatePass()` — server-internal only; H.39c MUST also verify non-Client per round-9 grep-sweep update) | H.41k sub-test (e), H.34b cascade verification, H.41i two-beacon order-independence | gameplay-programmer + qa-lead | Round-9 addition for Cluster 2 (B-CC2-A) closure. The H.41k sub-test (e) requires the test harness to advance the field-update pass by exactly one Heartbeat-equivalent step (e.g., to fill P_new's ring buffer from 5 → 17 samples by simulating 12 additional 5 Hz passes). The existing `_advanceTestClock(seconds)` seam advances clock reads but does NOT trigger the Heartbeat callback that runs the field-update pass body — passing real time without firing the pass leaves the live-source decay cache stale and the per-player ring buffer un-updated. The new seam: `DisturbanceService:_runFieldUpdatePass()` invokes the entire field-update pass body (decay-cache population, per-player ring-buffer XZ-sample append, per-flora field evaluation, tier-classification + TierCrossedEvent firing, beacon cap evaluation, OnMeterUpdate fire) **without yielding to Heartbeat**, then returns. Production code uses the actual `RunService.Heartbeat`-driven invocation; the seam is for deterministic test stepping. H.39c MUST be updated to grep for `_runFieldUpdatePass` alongside the existing test seams to verify it is not exposed via `Service.Client`. |
| **Ring-buffer manipulation seam on `DisturbanceService`** (`_setRingBufferState(player: Player, samples: {Vector3})` — server-internal only; H.39c MUST verify non-Client per round-9 grep-sweep update) | H.41k sub-tests (a)–(e), H.30c sub-AC (g) construction of interleaved Heartbeat-aligned conditions | gameplay-programmer + qa-lead | Round-9 addition for Cluster 2 (B-CC2-C) closure. H.41k sub-tests need to construct under-filled, fully-filled, and post-teleport-discontinuity ring-buffer states deterministically (e.g., P_new joined 1.0 s ago and has 5 samples; P1 has 17 samples; P_void has 0 samples because its Character is nil). Using the natural pulse cadence to populate the buffer is non-deterministic in tests (depends on real Heartbeat timing). The seam: `DisturbanceService:_setRingBufferState(player, samples)` directly writes the ring buffer for `player` with the supplied `{Vector3}` array (length determines how filled the buffer is; index 1 = oldest sample, index n = newest). Tests use this to construct exact buffer states before invoking `_runFieldUpdatePass`. Production code never invokes `_setRingBufferState`; H.39c verifies non-Client. |
| **Characterless-player harness mechanism** (round-9 addition for Cluster 2 B-CC2-D closure; H.41j sub-test (a)) | H.41j sub-test (a) `P_void.Character == nil` precondition | qa-lead + gameplay-programmer | Round-9 addition. The 4-simulated-client harness (above) MUST expose a mode where a mock player joins with `Player.CharacterAutoLoads = false` set BEFORE `Players.PlayerAdded` fires, so `player.Character == nil` for the duration of the sub-test (no automatic respawn). Implementation: the harness calls `Players.CharacterAutoLoads = false` at session-startup, creates the mock player via the harness's mock-player factory, fires `PlayerAdded`, and does NOT call `Player:LoadCharacter()` — `Character` remains nil. After the sub-test completes, the harness restores `Players.CharacterAutoLoads = true` and calls `LoadCharacter()` for any remaining mock players to leave the test environment clean. (The harness's `MockPlayerFactory` API exposes `CreateCharacterlessPlayer(userId): Player` as the canonical entry point.) |
| **Sub-stud-tolerance source-placement helper** on `DisturbanceService` (`_setLiveSourceState(sources: {EmissionPayload})` — server-internal only; H.39c MUST verify non-Client per round-11 grep-sweep update; round-11 B-R10-6 promotion of round-9 R9-I6 forward obligation to prereq table) | H.41l sub-tests (a) / (b) / (c) — the d=4, d=23.9, d=24.1 boundary cases for the round-9 DR-2 = Option B co-location amendment; **H.25c** (non-finite candidate construction — round-23 QA-4 cross-reference completion; the row's "Required by" column was not updated when round-22 authored H.25c against this seam) | qa-lead + gameplay-programmer | Round-11 addition. The H.41l boundary tests at d=23.9 studs and d=24.1 studs require placing two Beacon emissions at sub-stud co-location distances (±0.05 studs) that sit on either side of the `INFLUENCE_RADIUS = 24` boundary. Roblox `Vector3` uses single-precision float; the placement helper MUST construct the second beacon's position via `Vector3` arithmetic that survives the float-precision round-trip (recommended: `B2.position = B1.position + Vector3.new(distance, 0, 0)` rather than manual coordinate construction with hard-coded literal coordinates that may quantise to integer-stud precision under the test framework's serialisation). The helper directly writes the live-source list with the supplied `{EmissionPayload}` array — it bypasses Q9 stationary attenuation, schema validation, and the cap-eviction policy, parallel to `_injectSyntheticEmission`'s seam properties (E.24 invariants apply: position finite, `initialMagnitude ∈ (0, 1.00]`, `emissionType` in canonical enum). Production code never invokes `_setLiveSourceState`; H.39c verifies non-Client. The R9-I6 forward obligation in F.2a-IMPORTANT (round-9 cluster) records the architectural rationale; this prereq table row makes the dependency mechanically tracked for sprint planning. **Without this helper, H.41l sub-tests (b) and (c) are unsoundable** — integer-stud-precision placement would round 23.9 → 24 and 24.1 → 24, collapsing the boundary pair into a single test case that cannot distinguish the round-9 amendment's `dist < INFLUENCE_RADIUS` predicate's two branches. |
| **Cap-cue persistence-state reset seam** on `DisturbanceService` (`_resetCapCueDecayPassesRemaining(): ()` — server-internal only; H.39c verifies non-Client per round-13 grep-sweep update; round-13 R12-B2 closure of the round-11 H.41m sub-AC (d) parenthetical-deferral that did not execute in the round-11 patch session) | H.41m sub-AC (d) — Scenario 4 cold-start test-isolation precondition (cap-state discriminant State C from cold) | qa-lead + gameplay-programmer | Round-13 addition. H.41m sub-AC (d) requires the test fixture to construct Scenario 4 (State C — beacon near expiry) with no prior cap engagement within the past `math.ceil(1.0 × FIELD_UPDATE_HZ)` passes; without explicit reset, residual `_capCueDecayPassesRemaining[player]` state from a prior sub-test (e.g., a sub-AC (b) Scenario 2 run that left State A populated for some player) contaminates the cold-start assertion AND sub-AC (d) FAILS spuriously even on a correct implementation. The seam: `function DisturbanceService:_resetCapCueDecayPassesRemaining() self._capCueDecayPassesRemaining = {} end` (or equivalent — clearing entries individually via `for player, _ in pairs(self._capCueDecayPassesRemaining) do self._capCueDecayPassesRemaining[player] = nil end` is also acceptable; nil-vs-0 produces identical behaviour because the persistence rule decrements only when the entry is `> 0`, per C.3.4 step 4). Production code never invokes `_resetCapCueDecayPassesRemaining`; H.39c verifies non-Client per the round-13 expansion. **Without this helper, H.41m sub-AC (d) Scenario 4 is unsoundable** — residual persistence state from prior sub-tests' Scenario 2 / Scenario 3 runs would populate `nearby` / `stationary_nearby` on Scenario 4's first pass, contradicting the round-11 B-R10-2 nil-on-State-C-from-cold assertion. |
| **Extended-stationary-segment-active seam** on `DisturbanceService` (`_setExtendedStationarySegmentActive(active: boolean): ()` — server-internal only; H.39c verifies non-Client per round-15 grep-sweep update; round-15 R14-B9 + red-team B-RT-3 closure of the round-15-first-pass authoring's failure to add this prereq row in the same patch session that introduced the seam at H.PB1-BETA criterion (iv)) | H.PB1-BETA criterion (iv) FAIL-iv-server telemetry contract — bracketing the per-pass telemetry-row capture window for the extended-stationary-squad observation segment | qa-lead + gameplay-programmer + DevOps Engineer | Round-15 addition. The H.PB1-BETA criterion (iv) FAIL-iv-server clause requires per-pass telemetry rows (`pass_index`, `pass_timestamp_seconds`, `squad_t`, `predator_state`, `pre_segment_profile`, `session_id`) written to the evidence file `production/qa/evidence/HPB1-BETA-iv-server-telemetry-[session-id].csv` ONLY during the extended-stationary-squad observation segment (≥ 60 s window). Without this seam, the implementation cannot bracket the telemetry capture — either it logs every field-update pass for the entire session (wasted disk) or it has no signal-to-start-logging mechanism. The seam: `function DisturbanceService:_setExtendedStationarySegmentActive(active: boolean) self._extendedStationarySegmentActive = active end` (or equivalent — production code paths read `self._extendedStationarySegmentActive` to gate telemetry-row emission inside the field-update pass). The Beta-playtest harness invokes the seam at segment-start and segment-end; outside the segment window, no telemetry rows are emitted. Production code never invokes `_setExtendedStationarySegmentActive`; H.39c verifies non-Client per the round-15 expansion. **If Client-callable**, a malicious client could spuriously activate the flag mid-session AND pollute the evidence-file logs with non-segment-window data, OR conversely deactivate the flag during a legitimate segment AND silently drop the FAIL-trigger detection. **Without this helper, H.PB1-BETA criterion (iv) FAIL-iv-server is unsoundable** at production-deploy scale — Beta playtests run on production-deploy where the harness must externally bracket the telemetry. |

**Sequence rule.** PERF-DEVICE ACs are NOT run per-PR in CI. They run at milestone gates (post-sprint, pre-release). AUTO-INTEGRATION ACs requiring partner systems run when the partner system reaches its own DoD; this GDD's stories must not block on partner-system test evidence at their own DoD.


### Testability Flags

- **C.1.6 (spatial index)** — Now MANDATORY (revised from advisory). Grid correctness is implicitly verified by H.12, H.13, H.16, and H.36's perf budget. The DisturbanceService ADR MUST include explicit unit tests for grid cell insertion/removal/query and for `GetHottestHotspot` candidate enumeration via the grid (not a full live-source linear walk).
- **D.6 `HOTSPOT_DEDUP_GRID_SIZE`** — Internal optimization. Correctness verified indirectly by H.25. The DisturbanceService ADR MUST include a dedicated unit test for the 4-stud de-duplication behaviour (white-box access required).
- **C.1.11 attribution archive** — Behaviour verified by H.30 (resolution against archive entries) and H.35c (incomplete-attribution flag). Archive TTL purge behaviour (`ATTRIBUTION_ARCHIVE_TTL` expiry) is not directly tested in this GDD's ACs; defer a TTL-purge unit test to the DisturbanceService ADR.
- **`tierAt()` purity** — `tierAt(P, previousTier)` is a PURE function — callers always supply `previousTier`; the function holds no internal state. H.18–H.21 test setup calls the function directly with the desired `previousTier` parameter. No state-driving setup sequence is required.

---

## Relocated from the GDD's Acceptance Criteria section (round-22 AC-extraction pass, 2026-07-04 — relocation only, no contract text changed)

> Each block below was moved verbatim from `ecological-disturbance.md` § Acceptance Criteria; a one-line pointer remains at each original site. The behavioural GIVEN/WHEN/THEN contracts, PASS criteria, and binding “epic BLOCKED on gate presence” rules remain in the GDD.

### H.30c — call-stack nesting diagram (sub-AC (e))

> Cited from GDD H.30c sub-AC (e): “the recorder captures the in-frame instruction-sequence ordering as the following call-stack nesting”. The normative ordering predicate remains in the GDD.

```
t_i        — _captureDeathLockSnapshot completion at sub-step (5a)
t_i.5      — sub-step (5b) BindableEvent payload construction completion
t_i.75     — sub-step (5c) _OnPlayerDied:Fire(payload) invocation entry
  ├── t_iii — Predator AI's OnPlayerDied:Connect callback entry  (synchronous BindableEvent dispatch — runs INSIDE :Fire's lexical scope; :Fire has not yet returned)
  │   └── t_iv — :ReleasePredatorLock(predatorId) invocation entry  (called from inside Predator AI's callback body)
  │       ├── t_v   — sub-step (4a) pre_purge_targets computation completion
  │       ├── t_vi  — sub-step (4b) OnPredatorLockChanged:Fire(targetedPlayer, {locked = false}) invocation, per-target loop
  │       └── t_vii — sub-step (4c) atomic registry purge completion
  │       (t_iv returns to t_iii after t_vii completes; the indented block above is t_iv's lexical scope)
  │   (t_iii returns to t_i.75 after t_iv returns; if other OnPlayerDied:Connect callbacks are registered, they run after t_iii's block completes — also INSIDE t_i.75's :Fire call)
  └── (t_i.75's :Fire returns to its caller — DisturbanceService's Humanoid.Died handler — after all OnPlayerDied:Connect callbacks complete)
```

### H.30c-i evidence gate — normative CI YAML + evidence-file template + required-check clauses

> Cited from GDD H.30c sub-AC (i). The binding requirement (two-engineer yield-free review; recursive path filter; epic BLOCKED on gate presence) remains stated in the GDD.

**Normative YAML block (round-17 B16-3 closure of round-16 BLOCKING; CD-elevated to BLOCKING per `feedback_severity_floor_for_server_authoritative_seams.md` — round-15 R14-B10 specified the gate in prose only, leaving the "implementation epic is BLOCKED on this CI gate's presence" clause unenforceable on a server-authoritative primary write seam).** The CI gate's structure mirrors H.39d's evidence-gate workflow with an additional grep-narrowing step (the H.30c sub-AC (i) review is required only when modified DisturbanceService files contain protected references; an editor-only doc-string change to a tangential file does not trigger review):

```yaml
# .github/workflows/h30c-i-evidence-gate.yml (round-17 B16-3 normative spec — closes round-16 BLOCKING B16-3 of round-15 R14-B10 prose-only specification; CD-elevated to BLOCKING per the severity-floor rule for server-authoritative primary write seams)
name: H.30c sub-AC (i) Evidence Gate
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  # Mirrors H.39d's round-9 B-NS4 trigger expansion: gate fires on BOTH PR and
  # direct-to-main push so admin or branch-protection-bypass force-pushes cannot
  # evade the gate. Branch-protection rules are non-normative; this CI gate is
  # the authoritative enforcement.
jobs:
  detect-touched-paths:
    runs-on: ubuntu-latest
    outputs:
      disturbance-touched: ${{ steps.filter.outputs.disturbance }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Detect changed files via paths-filter (recursive over DisturbanceService source tree per round-15 R14-B10)
        id: filter
        uses: dorny/paths-filter@v3
        with:
          filters: |
            disturbance:
              - 'src/server/services/DisturbanceService/**/*.luau'
  check-h30c-i-trigger-narrowing:
    needs: detect-touched-paths
    if: needs.detect-touched-paths.outputs.disturbance-touched == 'true'
    runs-on: ubuntu-latest
    outputs:
      narrowing-matched: ${{ steps.grep.outputs.matched }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Grep changed files for H.30c sub-AC (i) protected-reference trigger patterns
        id: grep
        run: |
          # Trigger conditions: changed file modified AND contains any of the
          # protected server-authoritative-write references. The grep narrowing
          # avoids requiring the evidence file on tangential edits to
          # DisturbanceService source files that do NOT touch the predator-lock
          # registry purge path.
          # Protected references (per the H.30c sub-AC (i) prose specification):
          #   :ReleasePredatorLock, _OnPlayerDied:Fire, _predatorLockRegistry,
          #   _captureDeathLockSnapshot, OR any function declaration whose body
          #   lexically contains _OnPlayerDied:Fire (approximation: file
          #   contains _OnPlayerDied:Fire).
          # Round-17 B-RT17-3 closure (red-team finding — first-push portability).
          # On first-push events, github.event.before is the zero SHA; on PRs,
          # github.event.pull_request.base.sha is the PR's base. Compute BASE_SHA
          # safely; if neither is available (initial repo push), fall back to
          # treating ALL DisturbanceService source files as touched
          # (conservative-default: first-push of protected code MUST require
          # evidence rather than fail-open).
          BASE_SHA="${{ github.event.pull_request.base.sha }}"
          if [ -z "$BASE_SHA" ]; then
            BASE_SHA="${{ github.event.before }}"
          fi
          if [ -z "$BASE_SHA" ] || [ "$BASE_SHA" = "0000000000000000000000000000000000000000" ]; then
            echo "::warning::BASE_SHA unavailable (first-push or empty before-SHA); treating ALL DisturbanceService .luau files as touched per round-17 B-RT17-3 conservative-default rule"
            CHANGED_FILES=$(find src/server/services/DisturbanceService -name "*.luau" -type f 2>/dev/null)
          else
            CHANGED_FILES=$(git diff --name-only "$BASE_SHA" "${{ github.sha }}" \
              | grep -E '^src/server/services/DisturbanceService/.*\.luau$' || true)
          fi
          if [ -z "$CHANGED_FILES" ]; then
            echo "matched=false" >> $GITHUB_OUTPUT
          else
            MATCHED=$(echo "$CHANGED_FILES" \
              | xargs -r grep -lE ':ReleasePredatorLock|_OnPlayerDied:Fire|_predatorLockRegistry|_captureDeathLockSnapshot' 2>/dev/null \
              | wc -l)
            if [ "$MATCHED" -gt 0 ]; then
              echo "matched=true" >> $GITHUB_OUTPUT
            else
              echo "matched=false" >> $GITHUB_OUTPUT
            fi
          fi
  check-h30c-i-evidence:
    needs: check-h30c-i-trigger-narrowing
    if: needs.check-h30c-i-trigger-narrowing.outputs.narrowing-matched == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Find current sprint id
        id: sprint
        run: echo "sprint_id=$(cat production/sprints/current.txt)" >> $GITHUB_OUTPUT
      - name: Assert H.30c sub-AC (i) evidence file exists for current sprint
        run: |
          FILE="production/qa/evidence/H30c-i-yield-free-review-${{ steps.sprint.outputs.sprint_id }}.md"
          if [ ! -f "$FILE" ]; then
            echo "::error::H.30c sub-AC (i) evidence file missing: $FILE"
            exit 1
          fi
      - name: Assert evidence file lists two distinct GitHub reviewers
        run: |
          FILE="production/qa/evidence/H30c-i-yield-free-review-${{ steps.sprint.outputs.sprint_id }}.md"
          REVIEWER_COUNT=$(grep -c '^- @[A-Za-z0-9_-]\+$' "$FILE")
          if [ "$REVIEWER_COUNT" -lt 2 ]; then
            echo "::error::H.30c sub-AC (i) evidence file at $FILE lists fewer than 2 reviewers"
            exit 1
          fi
          REVIEWERS=$(grep '^- @[A-Za-z0-9_-]\+$' "$FILE" | sort -u | wc -l)
          if [ "$REVIEWERS" -lt 2 ]; then
            echo "::error::H.30c sub-AC (i) evidence file lists duplicate reviewer accounts"
            exit 1
          fi
      - name: Assert each reviewer's yield-free attestation line is present
        run: |
          FILE="production/qa/evidence/H30c-i-yield-free-review-${{ steps.sprint.outputs.sprint_id }}.md"
          ATTESTATION_COUNT=$(grep -c '^- attestation:' "$FILE")
          if [ "$ATTESTATION_COUNT" -lt 2 ]; then
            echo "::error::H.30c sub-AC (i) evidence file lacks two attestation: lines (one per reviewer)"
            exit 1
          fi
```

The evidence file's required structure to satisfy the CI gate:

```markdown
# H.30c sub-AC (i) Yield-Free Review — Sprint [sprint-id]
- date: 2026-MM-DD
- @reviewer-one
- @reviewer-two
- attestation: @reviewer-one — sub-steps (4a)–(4c) of `:ReleasePredatorLock` AND sub-steps (5a)–(5c) of `_OnPlayerDied:Fire` dispatch path AND any code path lexically nested in those bodies are yield-free; ZERO occurrences of task.wait, task.spawn, task.delay, coroutine.yield, :InvokeServer, :InvokeClient, RunService.Heartbeat:Wait, .Stepped:Wait, .RenderStepped:Wait, or any other yield primitive that surrenders control to a Heartbeat boundary. Traversal: [one-paragraph summary of the call-graph traversal performed across the modified files].
- attestation: @reviewer-two — sub-steps (4a)–(4c) AND (5a)–(5c) of the protected paths are yield-free per the canonical forbidden-primitive list. ZERO violations observed. Traversal: [one-paragraph summary; independent traversal, NOT copy-paste from reviewer-one's narrative].
- flagged_paths: [none / list]
```

**The CI gate MUST be a required check on PRs that touch `src/server/services/DisturbanceService/**/*.luau` AND whose changed files contain any of the protected references (`:ReleasePredatorLock`, `_OnPlayerDied:Fire`, `_predatorLockRegistry`, `_captureDeathLockSnapshot`).** The PR template still includes a checklist item for human reviewer-awareness, but the CI gate is the mechanical enforcement. CODEOWNERS rules on `src/server/services/DisturbanceService/**` requiring two-reviewer approval are a recommended additional defense; CODEOWNERS may be relaxed under sprint pressure but the CI gate **cannot** be relaxed without a force-push (which is recorded). The structural enforcement is parallel to H.39d's CI gate model and to H.39e/H.39f's CI gate models — the four CI gates together cover the project's complete server-authoritative seam set. **The DevOps Engineer MUST land this CI gate before any PR touches `:ReleasePredatorLock`'s body or the `_OnPlayerDied:Fire` dispatch path — the implementation epic is BLOCKED on the gate's presence per round-15 R14-B10 binding ruling AND now structurally enforceable per round-17 B16-3 closure.** Without this YAML being landed, the round-15 R14-B10 prose-only specification was honor-system on a server-authoritative primary write seam; round-17 closes the gap.

**R13-I4 + R16-B16-3 closure status:** R13-I4 was closed inline at the CI gate trigger path-filter mandate at round-15 R14-B10; the round-16 verdict re-elevated as B16-3 because the actual normative YAML did not exist (the round-15 closure was prose-only — "MUST author a CI gate" — without the YAML schema parallel to H.39d's). Round-17 B16-3 authors the YAML inline above, closing the round-16 elevation. The R13-I forward obligation tracking entry remains CLOSED (see F.2a-IMPORTANT round-13 cluster).

### H.41m-g bandwidth review — evidence-file template + gate-parse rules + optional MockSerializer upgrade

> Cited from GDD H.41m sub-AC (g). The MANUAL-REVIEW contract (per-payload increment ≤ 25 bytes; ≤ 25 × FIELD_UPDATE_HZ bytes/s per player; two independent attestations) remains in the GDD.

```markdown
# H.41m sub-AC (g) Bandwidth Increment Review — Sprint [sprint-id]
- date: 2026-MM-DD
- @reviewer-one
- @reviewer-two
- measurement-method: [JSONEncode-byte-count-approximation | MockSerializer-proxy | other-explicit]
- per-payload-increment-bytes-populated: [observed integer ≤ 25]
- per-payload-increment-bytes-nil: [observed integer; baseline]
- per-payload-increment-delta-bytes: [populated minus nil; ≤ 25 to PASS]
- per-second-per-player-incoming-bytes-at-default-5-hz: [observed; ≤ 125 to PASS]
- per-second-per-player-incoming-bytes-at-2-hz: [observed; ≤ 50 to PASS]
- per-second-per-player-incoming-bytes-at-10-hz: [observed; ≤ 250 to PASS]
- attestation: @reviewer-one — both byte-budget criteria PASS at all three cadences. Measurement notes: [one-paragraph summary of the measurement methodology and any observed variance].
- attestation: @reviewer-two — both byte-budget criteria PASS at all three cadences. Measurement notes: [one-paragraph summary; independent measurement, NOT copy-paste from reviewer-one].
- flagged_observations: [none / list]
```

The H.39d format (call-graph traversal narrative) is wrong-shape because bandwidth attestation requires NUMERIC OBSERVED VALUES, not free-text traversal summaries. The CI gate's grep pattern for H.41m sub-AC (g) MUST verify the presence of all numeric fields AND that the observed-value fields parse as integers AND that the parsed integers are within the PASS bounds (`per-payload-increment-delta-bytes <= 25`, `per-second-per-player-incoming-bytes-at-X-hz <= 25 * X`). **Optional MockSerializer proxy mechanism for AUTO-INTEGRATION upgrade (round-11 forward obligation; not blocking):** the test harness MAY install a `MockSerializer` proxy on `Knit.RemoteSignal` that intercepts `:Fire(player, payload)` calls, serialises the payload using a `HttpService:JSONEncode(payload)` byte-count approximation (NOT exact wire-format; Roblox uses a binary protocol with type-prefix encoding that is not exposed via Luau, so JSON byte-count is a conservative-upper-bound proxy), and exposes a per-player byte-counter via `recorder:GetPayloadIncrement(player): number`. If a future Roblox release exposes the actual wire-serialised byte count via a server-side API, the AUTO-INTEGRATION upgrade becomes viable; until then, the MANUAL-REVIEW with MockSerializer-attested approximation is the sound formulation. **Round-10 IMPORTANT cluster sources:** network-programmer F1 + systems-designer F5 + qa-lead F3 + performance-analyst F3 (4-spec convergent finding — "total" should be "increment"; per-player vs server-aggregated ambiguous; no Lemur-viable measurement mechanism).

### H.39d evidence gate — normative CI YAML + evidence-file template + required-check clause

> Cited from GDD H.39d. The two-reviewer call-graph review contract and evidence-file content requirements (a)–(e) remain in the GDD.

```yaml
# .github/workflows/h39d-evidence-gate.yml (round-7a R7-B16 normative spec; round-7c I-7b-8 corrected: changed_files API replaced with paths-filter / git diff because the GitHub Actions `github.event.pull_request.changed_files` field is a paginated URL, not a usable inline file list — using it under `if: contains(...)` evaluates the URL string itself, never matching, and silently disables the gate; round-9 B-NS4 — trigger expanded to include direct pushes to main + protected branches because the round-7c `pull_request`-only trigger could be bypassed entirely by force-pushing or admin-pushing directly to main, leaving the gate enforced only on the PR path)
name: H.39d Evidence Gate
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  # Round-9 B-NS4 closure: the gate fires on BOTH PR and direct-to-main push.
  # The original round-7c trigger was `on: pull_request` only — admins or anyone
  # with branch-protection-bypass privileges could push directly to main and
  # bypass the gate entirely. Branch-protection rules are non-normative (they
  # rely on GitHub admin configuration that lives outside this repo's source
  # of truth). Adding `push: branches: [main]` makes the CI gate the
  # authoritative enforcement, independent of branch-protection settings.
jobs:
  detect-touched-paths:
    runs-on: ubuntu-latest
    outputs:
      client-touched: ${{ steps.filter.outputs.client }}
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Detect changed files via paths-filter (round-7c I-7b-8 fix; round-23 B7/QA-1 — RECURSIVE filter)
        id: filter
        uses: dorny/paths-filter@v3
        with:
          # Round-23 B7/QA-1: the prior filter matched ONLY 'DisturbanceService/Client/**'
          # and 'DisturbanceService.Client.luau'. Under the standard single-file Knit
          # layout — Service.Client methods declared inline in Init.luau, the layout
          # the GDD's own H.30c-i rationale acknowledges — NEITHER path ever matches,
          # client-touched stays false forever, and this gate (the P0 client-Emit
          # two-engineer review) silently never fires. The recursive filter below is
          # the same fix shape H.30c-i's gate already uses; the content-grep step in
          # check-h39d-evidence narrows to PRs that actually touch Client surface.
          filters: |
            client:
              - 'src/server/services/DisturbanceService/**/*.luau'
  check-h39d-evidence:
    needs: detect-touched-paths
    if: needs.detect-touched-paths.outputs.client-touched == 'true'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - name: Narrow to Client-surface-touching changes (round-23 B7/QA-1 content grep)
        id: narrow
        run: |
          # Review is required only when a changed DisturbanceService file declares or
          # touches the Service.Client surface (any of the H.39 four declaration forms,
          # or an existing Client-method body edit). Doc-only or unrelated-internal
          # changes to the service tree skip the evidence requirement.
          BASE="${{ github.event.pull_request.base.sha || github.event.before }}"
          TOUCHED=false
          for f in $(git diff --name-only "$BASE"...HEAD -- 'src/server/services/DisturbanceService/'); do
            # Round-24 Gate-B1 F4.1: do NOT skip files missing at HEAD — a whole-file
            # deletion of Client surface must still trigger the review (git diff of a
            # deleted path still yields the removed lines to grep).
            if git diff "$BASE"...HEAD -- "$f" | grep -qE '(DisturbanceService\.Client|function .*\.Client[:.])'; then
              TOUCHED=true
            fi
          done
          echo "client_surface=$TOUCHED" >> $GITHUB_OUTPUT
      - name: Find current sprint id
        if: steps.narrow.outputs.client_surface == 'true'
        id: sprint
        run: echo "sprint_id=$(cat production/sprints/current.txt)" >> $GITHUB_OUTPUT
      - name: Assert H.39d evidence file exists for current sprint
        if: steps.narrow.outputs.client_surface == 'true'
        run: |
          FILE="production/qa/evidence/H39d-${{ steps.sprint.outputs.sprint_id }}-call-graph-review.md"
          if [ ! -f "$FILE" ]; then
            echo "::error::H.39d evidence file missing: $FILE"
            exit 1
          fi
      - name: Assert evidence file lists two distinct GitHub reviewers
        if: steps.narrow.outputs.client_surface == 'true'
        run: |
          FILE="production/qa/evidence/H39d-${{ steps.sprint.outputs.sprint_id }}-call-graph-review.md"
          REVIEWER_COUNT=$(grep -c '^- @[A-Za-z0-9_-]\+$' "$FILE")
          if [ "$REVIEWER_COUNT" -lt 2 ]; then
            echo "::error::H.39d evidence file at $FILE lists fewer than 2 reviewers"
            exit 1
          fi
          REVIEWERS=$(grep '^- @[A-Za-z0-9_-]\+$' "$FILE" | sort -u | wc -l)
          if [ "$REVIEWERS" -lt 2 ]; then
            echo "::error::H.39d evidence file lists duplicate reviewer accounts"
            exit 1
          fi
      - name: Assert each reviewer's attestation line is present
        if: steps.narrow.outputs.client_surface == 'true'
        run: |
          FILE="production/qa/evidence/H39d-${{ steps.sprint.outputs.sprint_id }}-call-graph-review.md"
          ATTESTATION_COUNT=$(grep -c '^- attestation:' "$FILE")
          if [ "$ATTESTATION_COUNT" -lt 2 ]; then
            echo "::error::H.39d evidence file lacks two attestation: lines (one per reviewer)"
            exit 1
          fi
```

The evidence file's required structure to satisfy the CI gate:

```markdown
# H.39d Call-Graph Review — Sprint [sprint-id]
- date: 2026-MM-DD
- @reviewer-one
- @reviewer-two
- attestation: @reviewer-one — no client-reachable path leads to self:Emit(...) without a server-side authority validator. Traversal: [one-paragraph summary].
- attestation: @reviewer-two — no client-reachable path leads to self:Emit(...) without a server-side authority validator. Traversal: [one-paragraph summary].
- flagged_paths: [none / list]
```

**The CI gate MUST be a required check on PRs that touch `src/server/services/DisturbanceService/**/*.luau` whose changed files touch the `Service.Client` surface (round-23 B7/QA-1 — the prior `Client/`-subdirectory-only filter could structurally never fire under the standard single-file Knit layout, where Client methods are declared inline in Init.luau; the recursive filter + content-grep narrowing step above is the same fix shape as the H.30c-i gate).** The PR template still includes the checklist item for human reviewer-awareness, but the CI gate is the mechanical enforcement. CODEOWNERS rules on `src/server/services/DisturbanceService/**` requiring two-reviewer approval are a recommended additional defense; CODEOWNERS may be relaxed under sprint pressure but the CI gate **cannot** be relaxed without a force-push (which is recorded). This eliminates the honor-system gap. The DevOps Engineer MUST land this CI gate before any DisturbanceService.Client method body is introduced or modified — the implementation epic is BLOCKED on the gate's presence per round-7a binding ruling.

### H.39e deferred-queue reference implementation (informational, not normative)

> Cited from GDD H.39e Lint (b): subscribers needing async work after receiving a payload MUST use the deferred-queue pattern; this is the reference shape.

```luau
-- Acceptable pattern (lint passes):
self._pendingDeaths = {}
DisturbanceService:GetOnPlayerDiedSignal():Connect(function(payload)
    table.insert(self._pendingDeaths, payload)  -- synchronous, yield-free, lint-clean
end)
RunService.Heartbeat:Connect(function()
    while #self._pendingDeaths > 0 do
        local payload = table.remove(self._pendingDeaths, 1)
        self:_handleDeathAsync(payload)  -- may yield freely; outside the OnPlayerDied:Connect scope
    end
end)
```
