# Epic: Crafting & Items

> **Layer**: Core
> **GDD**: design/gdd/crafting-and-items.md
> **Architecture Module**: `CraftingService` (+ `CraftingController`)
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories crafting-and-items`

## Overview

CraftingService owns bench state, the recipe catalog, two-tier inventory, and the
Beacon lifecycle (BC1-6) — the game's sole win-condition path (craft the escape
beacon, activate it, survive the window). It depends on Player Controller for
interaction and publishes `Beacon`/`Craft` emissions to Ecological Disturbance.
Its run-ending contract (`OnBeaconWindowSurvived`/`OnBeaconWindowFailed`) currently
routes through Player Controller directly — the migration to RunController's
`RunEndConditionRaised` is designed but explicitly deferred (see the RunController
epic's known defect).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0001: KnitInit/KnitStart Ordering Discipline | Cross-service signal construction discipline (`OnBeaconWindowSurvived` etc.) | HIGH |
| ADR-0002: RunController Architecture | Defines the target contract Crafting will migrate to (`RunEndConditionRaised`) — **not yet wired**, see known defect below | LOW |
| ADR-0004: DisturbanceService Core Architecture | Crafting calls `Emit("Beacon"\|"Craft", ...)` — signature not individually enumerated in ADR-0004's public surface | HIGH |
| ADR-0005: Death & Respawn Lifecycle | Crafting must not subscribe to `Humanoid.Died` directly; consumes `GetOnPlayerDiedSignal()` fan-out | LOW |
| ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting | `RequestCraft`/`RequestBeaconActivate` confirmed consistent with the canonical 6-step order | LOW |
| ADR-0007: Save/Load & Cosmetic Persistence | Zero DataStore writes during a run (Crafting state is purely runtime) | LOW |
| ADR-0008: Character Replication Bandwidth Baseline | Progress/hold-state signals counted in the aggregate bandwidth budget | HIGH |

## GDD Requirements

25 total requirements traced (see `docs/architecture/architecture-traceability.md`): **8 Covered, 11 Partial, 6 Gap.**

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-craft-001, -002 | Beacon activation/BCT-DEFEAT routing through PC, not RunController | ADR-0002 ⚠️ — **known defect: stale citation, deferred migration, enum can't represent "scatter" (see the RunController epic)** |
| TR-craft-004, -006, -016 | `RunEnded` subscription, no direct `Humanoid.Died`, zero persistence during a run | ADR-0002/0004/0005/0007 ✅ |
| TR-craft-010, -014 | `RequestCraft`/`RequestBeaconActivate` trust boundary, position re-derivation | ADR-0006/0008 ✅ |
| TR-craft-005 | Survival-window timer (per-Heartbeat, never `task.delay`) | ❌ No ADR — **Crafting's own F.4 flagged this as needed; never written** |
| TR-craft-015 | Test-harness DI seam | ❌ No ADR — **Crafting's own F.4 flagged this as needed; never written** |
| TR-craft-020 | Bench proximity watcher | ❌ No ADR — **Crafting's own F.4 flagged this as needed; never written** |
| TR-craft-013 | Placement validation order (clamp→LOS raycast→floor raycast→overlap) | ❌ No ADR — **Crafting's own F.4 flagged this as needed; never written** |
| TR-craft-009, -021, -023 | `MAX_ACTIVE_BEACONS` enforcement, CPU budgets, run-start roster gate | ❌ No ADR (remaining 2 of 6 gaps) |

## Blocking Issues

1. **2 of Crafting's 4 self-flagged ADRs are now written** (Status: Proposed, pending Acceptance):
   - Survival-Window Timer + Bench Proximity Watcher → `docs/architecture/adr-0013-crafting-survival-window-and-bench-watcher.md`
   - Placement Validation → `docs/architecture/adr-0014-crafting-placement-validation.md`

   Both passed engine-specialist review (ADR-0013: fixed a fault-isolation gap between its two sub-loops; ADR-0014: fixed a floor-raycast-origin bug that could target the wrong story of a multi-level structure, plus a nil-character-filtering gap). **The Test-Harness Injection Seam ADR remains unwritten** — not part of this session's authoring batch; still a gap.
2. **The RunController migration is designed but not applied** — stories should
   implement against the *current* PC-routed model (`OnBeaconWindowSurvived`/
   `OnBeaconWindowFailed` → PC) unless/until the migration is explicitly re-authored
   and ADR-0002 is fixed to match.

## Definition of Done

This epic is complete when:
- The two blocking ADRs above are Accepted (or the affected stories are explicitly scoped around them)
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/crafting-and-items.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- The `/ux-design crafting-bench` dependency flagged in `systems-index.md` is resolved before epic completion

## Next Step

Run `/create-stories crafting-and-items` to break this epic into implementable stories.
