---
name: Terranova performance review context
description: Terranova concept-level performance budgets, known gaps, and review findings relevant to future perf analysis sessions
type: project
---

Terranova is a Roblox co-op survival game (2-4 players, 5-20 min runs). Performance budgets are set in `.claude/docs/technical-preferences.md`:
- 60fps PC / 30fps mobile (iPhone SE-class, lowest tier)
- 50 KB/s bandwidth per client
- <1GB client memory
- <200MB total asset weight
- 60Hz server Heartbeat

**Why:** These are the committed ceilings. All GDD authors write against them. Budget allocation by system has NOT been committed as of 2026-04-30.

**How to apply:** When reviewing GDDs or architecture, always stress-test against 4-player worst-case simultaneously (not per-player in isolation). Engine-level replication baseline (4 players + 1 predator Characters) consumes an estimated 10-24 KB/s before any custom RemoteEvents fire, leaving ~26-40 KB/s effective custom budget.

## Open blockers from concept re-review (2026-04-30)

- B1: No per-system bandwidth allocation. Effective custom budget is ~26-40 KB/s, not 50 KB/s.
- B2: No Predator AI server tick ceiling committed at concept. FindPathAsync is 50-200ms async under load; concept defers recompute rate to AI GDD without a ceiling.
- B3: "30fps mobile baseline" has no p95 frame-time or thermal-ramp commitment. iPhone SE throttles within 3-5 min of sustained load.
- B4: StreamingEnabled committed but no streaming radius or critical-path guarantee.
- B5: HUD update rates unspecified across 6+ components; risk of unthrottled 60Hz bindings on 30fps mobile client.

## Verified fixes (prior review 2026-04-29)
- Cosmetic boundary rule: present and specific (line 124)
- Spatial-radius-merged disturbance aggregation: present (line 211)
- Death-state feedback: locked as MVP requirement (line 244)
- Touch mis-tap confirm pattern: locked as MVP requirement (line 245)
- DataStore write path via ProfileStore with retry + idempotency: present (line 193)

## Verify-incomplete items
- RemoteEvent rate-limit: commitment present (line 192) but no ceiling number specified
- Cross-platform prediction: pattern committed (line 194) but no latency budget number

## Key prototype requirement
Integrated worst-case load test (4 players + predator + disturbance events + HUD updates simultaneously) must measure all three budgets together. Single-system predator prototype is insufficient.
