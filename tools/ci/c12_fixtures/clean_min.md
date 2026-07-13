<!-- C.12 hook self-test fixture: CLEAN. Every wired signal has a canonical row,
     every S->C push is in F.2, the non-subscription is recorded, the external
     name is on the allowlist. check_inv1() MUST report PASS against this file. -->

# Fixture GDD (minimal)

## Detailed Rules

On death PC calls `PredatorService:ReleasePredatorLock` and raises
`RunController:RunEndConditionRaised`. PC subscribes to `RunEnded`, receives
`RequestSprintToggle`, and pushes `OnSprintStateChanged` and `OnPlayerDied`.
PC also references Crafting's `RequestCraft` at the trust boundary.
PC does NOT subscribe to `OnBeaconWindowFailed`.

#### C.9 — RemoteEvent Surface

| Event | Direction | Payload |
|---|---|---|
| `RequestSprintToggle` | C → S | `{sprint}` |
| `OnSprintStateChanged` | S → C (broadcast) | `{playerId, sprinting}` |
| `OnPlayerDied` | S → C (squad) | `{playerId}` |

Server-internal cross-service signals introduced by PC:

| Signal | Direction | Fired when |
|---|---|---|
| `PredatorService:ReleasePredatorLock` | PC → PredatorService | T5 death |
| `RunController:RunEndConditionRaised` | PC → RunController | T7/T8 |

Server-internal INBOUND subscriptions consumed by PC:

| Signal | Direction | PC handler |
|---|---|---|
| `RunEnded` | RunController → PC | clear latch, drive S5 |

#### C.10 — boundary

(closes the C.9 section)

### F.2 — Soft Dependencies

| System | Direction | Interface | Status |
|---|---|---|---|
| **HUD** | PC → HUD | `OnSprintStateChanged`, `OnPlayerDied` (per C.9) | provisional |
