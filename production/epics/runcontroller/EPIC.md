# Epic: RunController

> **Layer**: Foundation
> **GDD**: None — this module has no GDD; ADR-0002 is its sole design authority (per `architecture.md`'s Module Ownership table, `RunController` is listed as *(UNAUTHORED)* at the GDD level even though its ADR is Accepted)
> **Architecture Module**: `RunController`
> **Status**: Ready
> **Stories**: 2 created (2026-07-06) — see table below

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | RunController Core Aggregator — RunEndConditionRaised, Idempotency Latch, and defeatReason Payload Support | Logic | Ready | ADR-0002 |
| 002 | RunController GetRunEndedSignal Accessor and KnitInit/KnitStart Subscriber-Safety Verification | Integration | Ready | ADR-0002, ADR-0001 |

## Overview

RunController is a thin, idempotent event-fan-in aggregator: the sole broadcaster
of `RunEnded(exitReason, squadState, timestamp)`, fired exactly once per run via a
one-shot idempotency latch. Player Controller and (eventually) Crafting & Items
call its single inbound method, `RunEndConditionRaised(conditionType, squadState)`,
to report a wipe or victory condition; RunController never calls back into a
caller to independently verify state (the TD's binding event-subscriber-only
mandate). This module unblocks Player Controller, Crafting & Items, and Resource
Node's completability gates, all three of which name it as an open dependency.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0002: RunController Architecture | Single inbound method `RunEndConditionRaised`, one-shot `_hasEnded` latch, single outbound `RunEnded` signal, KnitInit-constructed per ADR-0001 | LOW |

## GDD Requirements

**No TR-registry entries exist for this module** — RunController predates the
GDD-driven `tr-registry.yaml` populated by this session's `/architecture-review`
(it was authored directly from `architecture.md`'s TD sign-off, not from a system
GDD). Requirements are traced directly from ADR-0002 instead:

| Requirement (from ADR-0002) | Consumers | Status |
|---|---|---|
| `RunEndConditionRaised(conditionType: "wipe"\|"victory", squadState, defeatReason?)` — server-internal Knit method, never under `.Client` | Player Controller (T7 wipe, T8 victory, and in-window BC4 outcomes forwarded from Crafting's `OnBeaconWindowFailed`/`Survived`) — ✅ sole current caller, per Crafting's own GDD model | ✅ Covered |
| `RunEnded(exitReason, squadState, timestamp, defeatReason?)` signal, fire-once idempotent | HUD (end-screen), Player Controller (T7/T8 cleanup), analytics | ✅ Covered |
| `GetRunEndedSignal()` accessor, safe to connect during any subscriber's own KnitStart | All subscribers | ✅ Covered |

**Update 2026-07-06 (later same day) — ADR defect FIXED**: the stale `C.5.8`
citation is corrected to `C.9` (Crafting's actual Beacon State Machine section);
the caller list now correctly states PC as sole current caller (Crafting's GDD
routes through PC, not the arbiter directly — the round-24-reverted direct
migration remains unapplied); `conditionType` gained an optional
`defeatReason: ("wipe"|"scatter")?` field so PC's forwarding path can carry
Crafting's `"scatter"` line-break reason. See
`docs/architecture/architecture-review-2026-07-06.md`'s "Carried-Forward
Conflicts: RESOLVED" section, item 5, for full detail. **One non-blocking
residual item remains** (flagged as an ADR-0002 Open Question, not fixed): a
cross-GDD prose tension between `player-controller.md` line 369 ("raised to the
arbiter") and Crafting's actual PC-forwarding model — recommend a small GDD-text
sync at some point, not blocking for story-writing.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- ~~The 3-part ADR-0002/Crafting mismatch above is resolved~~ — done, 2026-07-06 (see Update note above; one non-blocking residual GDD-prose item remains, tracked separately)
- Unit tests confirm: a duplicate `RunEndConditionRaised` call with a different
  `conditionType` results in exactly one `RunEnded` fire, matching the first call
- Integration test: `RunEnded`'s signal object is confirmed non-nil immediately
  after `KnitInit` completes (before any `KnitStart` runs)

## Next Step

Run `/create-stories runcontroller` to break this epic into implementable stories.
