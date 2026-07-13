# Smoke Test: Critical Paths

**Purpose**: Run these checks in under 15 minutes before any QA hand-off.
**Run via**: `/smoke-check` (which reads this file)
**Update**: Add new entries as new core systems are implemented; do not let this
list go stale once Pre-Production prototyping produces the first playable build.

## Core Stability (always run)

1. Game launches to the lobby/loadout screen without crash
2. A squad (2-4 players) can start a run from the lobby
3. Lobby/loadout UI responds to all inputs (touch, mouse, gamepad) without freezing

## Core Mechanic (update per sprint — currently unimplemented, Pre-Production)

<!-- Populate once the vertical slice's core loop exists. Candidates, per the
     vertical-slice scope decision: -->
4. [Player can move and the camera follows correctly — PC locomotion, ADR-0003]
5. [Gather → craft loop completes at least one full cycle — RM/Crafting]
6. [Ecological Disturbance responds visibly to player activity — ED]
7. [Predator AI engages and disengages per the quiet/loud lever — PA]
8. [Beacon activation is reachable and holds — Crafting win-con]

## Data Integrity

9. Cosmetic purchase (`ProcessReceipt`) grants exactly once and survives a
   simulated reconnect (once Save/Load, ADR-0007, is implemented)

## Network / Trust Boundary

10. A RemoteEvent fired above its rate limit is silently dropped with no
    observable state mutation (ADR-0006)

## Performance

11. No visible frame rate drops on target hardware (60fps PC / 30fps mobile baseline)
12. Per-client bandwidth stays under the 50 KB/s advisory ceiling in a 4-player
    + 1-predator scene (ADR-0008 — this is also the empirical measurement the
    `/prototype predator-ai` spike is meant to produce)
