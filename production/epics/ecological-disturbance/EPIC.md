# Epic: Ecological Disturbance

> **Layer**: Foundation
> **GDD**: design/gdd/ecological-disturbance.md (+ ecological-disturbance-forward-obligations.md, ecological-disturbance-verification.md)
> **Architecture Module**: `DisturbanceService` (+ `DisturbanceController`)
> **Status**: Ready
> **Stories**: 17 created (2026-07-06) — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Constants Module, Service Bootstrap & 5Hz Field-Update Loop Driver | Integration | Ready | ADR-0001, ADR-0004 |
| 002 | Emission Schema & Server-Authoritative Emit() Intake | Logic | Ready | ADR-0004 |
| 003 | Spatial Hash Grid, Live-Source List & Cap Eviction | Logic | Ready | ADR-0004 |
| 004 | Attribution Archive (write-once store, TTL, count-cap FIFO) | Logic | Ready | ADR-0004 |
| 005 | Decay Formula, Spatial Falloff & fieldValue() | Logic | Ready | ADR-0004 |
| 006 | Tier Classification with Hysteresis, TierCrossedEvent & Post-Hitch Cascade | Logic | Ready | ADR-0004 |
| 007 | Squad Aggregate t & GetSquadAggregateT Accessor | Logic | Ready | ADR-0004 |
| 008 | GetHottestHotspot Query & topContributorsAt | Logic | Ready | ADR-0004 |
| 009 | OnDisturbanceBandCrossed Squad-Aggregate Band-Crossing Signal | Integration | Ready | ADR-0004 |
| 010 | Humanoid.Died Monopoly & OnPlayerDied Fan-out | Integration | Ready | ADR-0001, ADR-0004, ADR-0005 |
| 011 | RegistrationHandshake Module & Predator-Lock Registry | Integration | Ready | ADR-0001, ADR-0004 |
| 012 | Death Attribution Resolution & DeathAttributionPayload | Integration | Ready | ADR-0004, ADR-0005 |
| 013 | HUD Meter & Alert Wiring (OnMeterUpdate/OnDisturbanceAlert) | Integration | Ready | ADR-0004 |
| 014 | StreamingEnabled Chunk Membership & Flora Chunk Snapshot/Update Push | Integration | Ready | ADR-0004 |
| 015 | Beacon Stationary-Squad Hunt-Floor Cap & Cap-State Discriminant | Logic | Ready | ADR-0004 |
| 016 | Security Hardening — Client-Surface Lints & Test-Seam Enforcement | Integration | Ready | ADR-0004 |
| 017 | Performance Instrumentation & Ops-Log Observability | Logic | Ready | ADR-0004 |

## Overview

DisturbanceService is the sole cross-system event bus for Terranova: every player
action (sprint, lantern, gather, craft, beacon) emits a disturbance signal into a
server-side spatial field, which Predator AI queries to hunt and HUD subscribes to
for the meter/alert display. It owns the live-source spatial hash grid, the
write-once attribution archive, tier classification, and the sole `Humanoid.Died`
subscription that fans death out to Player Controller, Crafting, and Predator AI.
Per `architecture.md`, it is "the busiest module in the game" — every other
system's correctness depends on getting this one right once.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0001: KnitInit/KnitStart Ordering Discipline | KnitInit builds, KnitStart connects; RegistrationHandshake pattern for live cross-service registration (ED↔PA is the worked example) | HIGH |
| ADR-0004: DisturbanceService Core Architecture | Plain table-of-tables spatial hash grid (32-stud cells); oldest-first cap eviction at 500 sources; server-computed StreamingEnabled chunk membership (N1); closes all 11 forward-obligations (N1-N11) | HIGH |
| ADR-0005: Death & Respawn Lifecycle | ED owns the sole `Humanoid.Died` subscription and fans `OnPlayerDied` out to exactly 3 consumers (PC, Crafting, PA) | LOW (for ED's slice of this ADR) |

## GDD Requirements

72 total requirements traced (see `docs/architecture/architecture-traceability.md` for the full table): **33 Covered, 17 Partial, 22 Gap.**

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-ed-001 | Table-of-tables spatial hash grid (32-stud cells) | ADR-0004 ✅ |
| TR-ed-004 | `HotspotResult` exactly-6-field non-optional return | ADR-0004 ⚠️ (fields not enumerated) |
| TR-ed-019 | `MAX_LIVE_SOURCES=500` cap + cap-hit policy | ADR-0004 ⚠️ — **CONFLICT: ADR evicts oldest, GDD drops new (unresolved)** |
| TR-ed-030 | Server-internal `OnPlayerDied` BindableEvent, KnitInit-constructed | ADR-0001/0004/0005 ✅ (type tension w/ Signal-class recommendation, unresolved) |
| TR-ed-032 | `Humanoid.Died` sole subscriber, registered in KnitInit | ADR-0004/0005 ✅ — **CONFLICT: ADR-0004's diagram shows KnitStart (unresolved)** |
| TR-ed-043 | `Emit(emissionType, position, magnitude, sourcePlayerId)` publisher | ADR-0006 ⚠️ (signature never enumerated in ADR-0004 despite 3 other systems calling it) |
| TR-ed-006, -007, -010, -016–018, -021–023, -025, -027, -035, -037, -038, -047, -051, -054, -058, -059, -067, -070, -072 | Internal simulation math, micro-optimizations, cross-service signals (`TierCrossedEvent`, `OnDisturbanceBandCrossed`), presentation, and cross-GDD constant locks | ❌ No ADR (22 total — see traceability index for full text) |

**Update 2026-07-06 (later same day)**: all three conflicts below are now **RESOLVED** — fixed directly in `ecological-disturbance.md` and ADR-0001/ADR-0004 during the `/architecture-review` follow-up pass. See `docs/architecture/architecture-review-2026-07-06.md`'s "Carried-Forward Conflicts: RESOLVED" section for the fix detail. Story-writing is unblocked.
1. ~~Cap-eviction policy contradiction~~ — FIXED: GDD's Q3 marked RESOLVED, tuning table synced to ADR-0004's evict-oldest.
2. ~~`Humanoid.Died` registration phase~~ — FIXED: ADR-0004's diagram now shows KnitInit.
3. ~~`GetOnPlayerDiedSignal(): BindableEvent` type vs. Signal-class~~ — FIXED: kept as `BindableEvent` per the GDD's frozen closure, with `Workspace.SignalBehavior` pinned instead.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/ecological-disturbance.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- ~~The 3 unresolved ADR-vs-GDD conflicts above are fixed~~ — done, 2026-07-06 (see Update note above)

## Next Step

Run `/create-stories ecological-disturbance` to break this epic into implementable stories.
