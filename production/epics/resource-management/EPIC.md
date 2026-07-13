# Epic: Resource Management

> **Layer**: Core
> **GDD**: design/gdd/resource-management.md
> **Architecture Module**: `ResourceService`
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories resource-management`

## Overview

ResourceService owns the squad-shared oxygen scalar `P` (clamped [0, 600]), the
Healthy/Critical/Empty state machine, and the death-cost idempotency dedup set.
It ticks a 60Hz Heartbeat drain loop keyed to the current Beacon Charge Tier, and
deducts oxygen on player death via the cross-service `RequestSquadOxygenSpend`
contract ratified in ADR-0005. Depends on Crafting & Items for the oxygen item
definition per `systems-index.md`'s dependency map.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0005: Death & Respawn Lifecycle | `RequestSquadOxygenSpend(deadPlayerUserId, amount, reason, deathEventId)` compound-key idempotency; `OXYGEN_GRACE_DURATION=5s` (C4); D1 kill-criterion | LOW |
| ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting | Read-only client projection principle (general boundary; RM's specific surface not enumerated in the ADR's registry) | LOW |
| ADR-0008: Character Replication Bandwidth Baseline | RM's `OXYGEN_SYNC_HZ=2` signal counted in the aggregate bandwidth budget (not individually derived) | HIGH |

## GDD Requirements

28 total requirements traced (see `docs/architecture/architecture-traceability.md`): **7 Covered, 9 Partial, 12 Gap.**

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-rm-006 | Per-band drain keyed to Beacon Charge Tier — RM reads the current band from ED every tick | ❌ **No ADR — blocks implementation entirely.** ADR-0004's public surface has no BCT/band accessor. See Blocking Issue below. |
| TR-rm-007 | Fail-safe default to BC1 if the BCT accessor is nil | ❌ No ADR (depends on TR-rm-006) |
| TR-rm-008 | 60Hz Heartbeat deterministic tick order | ❌ No ADR — RM's most correctness-critical loop has no architectural decision at all |
| TR-rm-009 | `MAX_TICK_DT=0.1s` cap + non-negative dt guard | ❌ No ADR |
| TR-rm-010–012 | Death-cost deduction, idempotency, `deathEventId` contract | ADR-0005 ✅ (note: RM's own GDD signature `(amount, reason, deathEventId)` drifted from ADR-0005's ratified `(deadPlayerUserId, amount, reason, deathEventId)` — needs a GDD text patch) |
| TR-rm-018, TR-rm-027 | Oxygen-empty grace timer (C4), D1 kill-criterion | ADR-0005 ✅ |
| TR-rm-001–005, -015–017, -022–026, -028 | Pool ownership model, client dead-reckoning, state machine, HUD signal surface, anti-camping invariant, disconnect handling | ❌ No ADR (remaining gaps — see traceability index for full text) |

## Blocking Issues — RESOLVED 2026-07-06 (ADRs written, Status: Proposed, pending Acceptance)

1. **RM's Beacon-Charge-Tier/band accessor** — now `docs/architecture/adr-0009-resource-management-disturbance-band-accessor.md`. Resolves the ownership ambiguity: `CraftingService:GetCurrentBeaconChargeTier()` (Crafting owns Beacon lifecycle per `architecture.md`'s Module Ownership table), not a DisturbanceService accessor.
2. **RM's core drain tick loop** — now `docs/architecture/adr-0010-resource-management-tick-loop.md`. Fixed 6-step Heartbeat order: deductions → restores → drain (calling ADR-0009's accessor once per tick) → clamp → win-check → Empty-state eval.

Both ADRs passed engine-specialist review (each caught and fixed a real bug — see the ADRs' own Risks sections). **Still Proposed, not yet Accepted** — run `/architecture-review` in a fresh session to confirm coverage, or ratify directly, before treating these stories as fully unblocked.

## Definition of Done

This epic is complete when:
- Both blocking ADRs above are Accepted
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/resource-management.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- RM's `RequestSquadOxygenSpend` GDD signature is reconciled to ADR-0005's ratified one

## Next Step

Run `/create-stories resource-management` to break this epic into implementable stories
— but expect most Logic stories to be Blocked until the two ADRs above land.
