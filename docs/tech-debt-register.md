# Tech Debt Register

Tracks advisory-level deviations and known gaps accepted during `/story-done` closure — not blocking at the time, but worth revisiting. Each entry links back to the story that surfaced it.

| ID | Source Story | Description | Owner/Target | Status |
|----|--------------|-------------|---------------|--------|
| TD-001 | `pc-2` (Lantern Axis, Light-to-Gather Gate & Tap-Hold Gather) | `_globalEventCounts` (ADR-0006's global RemoteEvent budget) is currently scoped to `PlayerControllerService` only, not truly project-wide — a client could combine calls across multiple services to exceed the intended 30/s cap once a second client-fired-event service exists. | Story 010 (RemoteEvent Trust Boundary Application) | Open |
| TD-002 | `pc-2` | Minor redundant window-reset duplication in `PlayerControllerService.luau`'s step-3 global-budget check — harmless (traced clean), but inconsistent with step 2's cleaner single-source-of-truth pattern. | `PlayerControllerService.luau` | Open |
| TD-003 | `pc-2` | 4 suggested (non-blocking) test cases never added: `no-player-state` drop path, double-`BeginGatherHold` overwrite semantics, `TryCommitGatherHold` nodeId-mismatch branch, H.10's literal 200ms debounce window (current implementation debounces unconditionally, functionally stricter than the AC but untested as literally specified). | `tests/unit/player-controller/lantern-gather-gate_test.luau` | Open |
| TD-004 | `ed-3` (Spatial Hash Grid, Live-Source List & Cap Eviction) | Once Story 004's real attribution archive exists, add a behavioral test (not just the current static/structural proof) confirming an evicted source's archive entry remains resolvable — currently only proven by construction (no archive parameter exists in the eviction functions). | Story 004 (Attribution Archive) | Open |
