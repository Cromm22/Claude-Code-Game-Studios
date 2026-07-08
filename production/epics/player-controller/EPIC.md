# Epic: Player Controller

> **Layer**: Foundation
> **GDD**: design/gdd/player-controller.md
> **Architecture Module**: `PlayerControllerService` (+ client controller)
> **Status**: Ready
> **Stories**: 15 created (2026-07-06) — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | Locomotion & Sprint-State Authority (S1/S2) + Stamina + Ghost-Sprint Guard | Logic | Ready | ADR-0011 |
| 002 | Lantern Axis, Light-to-Gather Gate & Tap-Hold Gather | Logic | Ready | ADR-0006 |
| 003 | Disturbance Emission Publisher (Sprint/Light Pulses, Grace, Cooldown, Magnitude) | Logic | Ready | ADR-0003 |
| 004 | Death-Cost Reconciliation Core (deathEventId + State Machine) | Logic | Ready | ADR-0005 |
| 005 | Death/Respawn Side-Effects & Cross-Service Signals (T5/T6) | Integration | Ready | ADR-0005 |
| 006 | Path B Disconnect Predicate, Oxygen Grace Timer & Oxygen-Gated Respawn Wait | Logic | Ready | ADR-0005 |
| 007 | Dead-Player Input Locks & renderScope (S4/S5) | Integration | Ready | ADR-0012 |
| 008 | Minimal Spectator Camera | Integration | Ready | ADR-0012 |
| 009 | Run-End Contract (T7 Wipe / T8 Victory) | Integration | Ready | ADR-0005 (cross-epic: RunController's ADR-0002) |
| 010 | RemoteEvent Trust Boundary Application (Canonical Order + Global Budget) | Integration | Ready | ADR-0006 |
| 011 | NetworkOwnership & Character Replication Bandwidth | Integration | Ready | ADR-0008 |
| 012 | Quick-Ping (Raycast, Gesture, Origin Tolerance) | Integration | Ready | ADR-0006 |
| 013 | Emote Wheel & Cosmetic Boundary | Integration | Ready | ADR-0006 |
| 014 | Haptic Feedback | Visual/Feel | Ready | ADR-0011 (closest fit; no dedicated ADR) |
| 015 | C.12 Contract-Completeness CI Hook Extension | Integration | Ready | ADR-0006 (closest fit; no dedicated ADR) |

## Overview

Player Controller owns locomotion (sprint/stamina/lantern), the death/respawn
lifecycle (S4/S5, `deathEventId` minting, the `DeathCostReconciliation` state
machine), and the client-facing RemoteEvent surface for sprint, lantern, gather,
ping, and emote. It wraps Roblox's `Humanoid` (ratified as the shared locomotion
primitive with Predator AI, ADR-0003) and is a Foundation-tier module with no
MVP-internal design dependencies of its own, though several of its own sub-systems
depend on modules that don't exist yet (RunController, Camera).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0001: KnitInit/KnitStart Ordering Discipline | Cross-service signal construction discipline | HIGH |
| ADR-0003: Locomotion Driver | Humanoid.WalkSpeed/MoveDirection ratified over Character Controller Library, shared with PA | HIGH |
| ADR-0005: Death & Respawn Lifecycle | `deathEventId` minting (PC-owned), Pending/InFlight/Committed/Abandoned reconciliation state machine, `OXYGEN_GRACE_DURATION=5s` (C4), D1 kill-criterion | LOW |
| ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting | Canonical 6-step validation order + 30/s global budget, generalized from PC's own C.9 pattern | LOW |
| ADR-0008: Character Replication Bandwidth & NetworkOwnership | Default automatic NetworkOwnership for player characters | HIGH |

## GDD Requirements

53 total requirements traced (see `docs/architecture/architecture-traceability.md` for the full table): **25 Covered, 13 Partial, 15 Gap.**

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-pc-001 | Locomotion driver Humanoid.WalkSpeed, WALK_SPEED=12/SPRINT_SPEED=20 | ADR-0003 ✅ |
| TR-pc-013 | Clock-injection seam (`getServerTime()` DI), inline `workspace:GetServerTimeNow()` forbidden | ADR-0011 defines the `getServerTime()` seam field; ADR-0005's sample code violation is **FIXED** (2026-07-06 `/architecture-review` follow-up pass) |
| TR-pc-017–024 | Death/respawn timer, oxygen deduction, reconciliation state machine, grace timer | ADR-0005 ✅ (mostly covered; sweep interval and a few arities remain open) |
| TR-pc-026–030 | Run-end contract (`RunEndConditionRaised`, `RunEnded` subscription) | ADR-0002 ✅ (see the RunController epic for known defects in this contract) |
| TR-pc-034–039, TR-pc-047–048 | RemoteEvent trust boundary + NetworkOwnership/bandwidth | ADR-0006/ADR-0008 ✅ |
| TR-pc-004 | Sprint-state authority model (server-gated T1/T2) | ❌ No ADR — **PC's own F.4 flagged this as needed; never written** |
| TR-pc-005 | Stamina drain/regen lifecycle | ❌ No ADR — **PC's own F.4 flagged this as needed; never written** |
| TR-pc-033 | Spectator camera + StreamingEnabled chunk-load guard | ❌ No ADR — **PC's own F.4 flagged this as needed; blocked further on the unauthored Camera system (OQ.3)** |
| TR-pc-002, -008, -009, -012, -014, -015, -040, -041, -051, -052, -053 | Per-platform input bindings, pulse cadence, cross-service PA latches, gestures, haptics, CI hooks | ❌ No ADR (remaining 12 of 15 gaps — see traceability index for full text) |

## ADRs Written 2026-07-06 — Status: Accepted (ratified by the user 2026-07-06)

- TR-pc-004/005/006/039 (Sprint-State Authority + Stamina Lifecycle) → `docs/architecture/adr-0011-player-controller-sprint-stamina-authority.md`
- TR-pc-033/034 (Dead-Player Input Lock + minimal Spectator State) → `docs/architecture/adr-0012-player-controller-death-spectator-state.md`

Both passed engine-specialist review, each with real compile-breaking bugs caught and fixed (an undefined helper function + a variable-scoping error in ADR-0011; a nonexistent `HasChunkLoaded()` API replaced with confirmed alternatives in ADR-0012). A `/architecture-review` follow-up pass later fixed a clock-seam violation found in ADR-0011 itself (see TR-pc-013 above). Both ADRs are now Accepted — no longer blocking their stories.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/player-controller.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- All Visual/Feel and UI stories have evidence docs with sign-off in `production/qa/evidence/`
- ~~ADR-0011 and ADR-0012 above are Accepted (or ratified) before their stories are treated as fully unblocked~~ — done, 2026-07-06

## Next Step

Run `/create-stories player-controller` to break this epic into implementable stories.
