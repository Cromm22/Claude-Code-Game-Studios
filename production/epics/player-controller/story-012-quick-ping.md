# Story 012: Quick-Ping (Raycast, Gesture, Origin Tolerance)

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-038` (ping: server re-runs raycast, client `candidateTargetId` advisory only, origin within `PING_ORIGIN_TOLERANCE` of server position), `TR-pc-051` (two-finger ping gesture detection, `PING_TWO_FINGER_WINDOW=150ms`)

**ADR Governing Implementation**: ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting (closest fit — `RequestPing`'s origin-tolerance + server-side raycast re-run is a direct application of ADR-0006 step 5, "never trust a client-supplied id/position/distance claim — re-derive from server-tracked state")
**ADR Decision Summary**: `RequestPing` follows the canonical 6-step order; step 5 (server-side plausibility re-derivation) is the specific mechanism this story implements — the server validates the ray *origin* against the player's server-tracked position, then re-runs the raycast itself and uses ITS OWN result, treating the client's `candidateTargetId` as advisory only.

**Engine**: Roblox Studio (live platform) | **Risk**: LOW
**Engine Notes**: No dedicated ADR governs the two-finger gesture-detection mechanism itself (TR-pc-051 is a named gap in the epic's own list) — implement per the GDD's own C.4.1/C.7 specification.

**Control Manifest Rules (Core layer)**:
- Required: Server-side plausibility re-derivation — never trust a client-supplied id/position/distance claim; re-derive from server-tracked state (ADR-0006 step 5). This is the entirety of `RequestPing`'s trust model.
- Forbidden: Never respond to a rejected/rate-limited RemoteEvent with an explicit error response to the client.

---

## Acceptance Criteria

- [ ] **H.16** — GIVEN a 2-player server, WHEN player A fires `RequestPing` targeting a tagged entity at 50 studs (within `PING_RAYCAST_RANGE=80`), THEN player B's client receives `OnPingBroadcast` with the entity's tag within ≤1 server Heartbeat; marker displays for `8.0s ± 0.1s` and auto-removes.
- [ ] **H.17** — GIVEN a player has fired 3 pings within a 1.5s window, WHEN a 4th ping is requested within the same window, THEN rejected (`PING_BURST_CAP=3` exceeded), no `OnPingBroadcast`, no rate-limit budget consumed for legitimate pings.
- [ ] **H.18** — GIVEN three `TouchStarted` events arrive within `PING_TWO_FINGER_WINDOW=150ms`, WHEN the gesture detector evaluates, THEN no ping fires (3rd-finger cancel) and no cooldown is charged.
- [ ] **H.24 (ping-specific slice)** — a player in S4 sending `RequestPing` is REJECTED (already established at the alive-guard level in Story 007; this story's own AC re-verifies the ping-specific downstream validation runs only after that guard passes).
- [ ] **H.68** — GIVEN player A's server-tracked position = `P`, WHEN `RequestPing` arrives with `rayOriginPos` farther than `PING_ORIGIN_TOLERANCE=8 studs` from `P`, THEN rejected (no broadcast); a `rayOriginPos` within tolerance is accepted and the server-side raycast result is broadcast (client `candidateTargetId` is advisory only).

---

## Implementation Notes

- **Server-side re-derivation is the whole trust model**: the client raycasts from camera center on input, carrying an optional `candidateTargetId`. The server validates the ray *origin* against the player's server-tracked `HumanoidRootPart.Position` within `PING_ORIGIN_TOLERANCE = 8 studs` BEFORE broadcasting, then re-runs the raycast SERVER-SIDE and uses the server's own result. The client's `candidateTargetId` is advisory only — if it disagrees with the server's own raycast (replication lag), the server's result wins.
- **The server does NOT validate camera angle** — camera orientation is not server-tracked, so a camera-angle plausibility check is unenforceable. Ping legitimacy rests on origin-position plausibility plus the server-authoritative raycast result alone.
- **Two-finger gesture detection**: client tracks `UserInputService.TouchStarted` events via a per-frame accumulator pattern in the client controller (`ContextActionService` does not natively express multi-touch gestures). If two `TouchStarted` events land within `PING_TWO_FINGER_WINDOW = 150ms` (count, not position), the ping fires. A THIRD touch within the window CANCELS and SUPPRESSES the ping (defends against frantic multi-finger sequences during predator encounters) — no cooldown charged for a suppressed ping.
- Categories: Danger (red, enemy tag), Resource (green, resource tag), Navigate (yellow, terrain/door/exit), Untagged (white, location-only). Persistence: `PING_DISPLAY_DURATION = 8s`. Rate limit: `PING_COOLDOWN_PER_PLAYER = 1.0s` + burst cap `3` per `1.5s`.
- **Pings publish nothing to Ecological Disturbance** — no emission, no positional audio, no world object. HUD/teaching copy must never imply a ping attracts the predator (a Pillar-2 coordination regression if players believe it does).
- The alive-guard rejection for S4/S5 (Story 007's shared `_isEligibleForGameplayEvents` check) runs BEFORE any of this story's own logic — this story's own trust-boundary steps only matter once that guard has already passed.

---

## Out of Scope

- Story 007: the S4/S5 alive-guard rejection itself (this story only re-confirms `RequestPing`'s downstream steps run correctly once that guard passes).
- Story 010: the shared global-budget helper and generic 6-step order infrastructure (this story consumes it, does not redefine it).
- HUD epic: the ping marker's visual rendering and the world-marker mental-model teaching copy.

---

## QA Test Cases

- **AC-1 (H.16 — broadcast + display)**:
  - Given: 2-player server.
  - When: A pings a tagged entity within range.
  - Then: B receives `OnPingBroadcast` with the tag within ≤1 Heartbeat; marker displays 8.0s±0.1s.
- **AC-2 (H.17 — burst cap)**:
  - Given: 3 pings already fired within 1.5s.
  - When: a 4th ping requested in the same window.
  - Then: rejected, no broadcast, no budget consumption on legitimate pings.
- **AC-3 (H.18 — third-finger cancel)**:
  - Given: two touches within 150ms.
  - When: a third touch lands within the same window.
  - Then: no ping fires, no cooldown charged.
- **AC-4 (H.68 — origin tolerance + server-authoritative raycast)**:
  - Given: server-tracked position `P`.
  - When: `rayOriginPos` is farther than 8 studs from `P`.
  - Then: rejected.
  - Edge cases: a within-tolerance origin with a `candidateTargetId` that disagrees with the server's own raycast result must broadcast the SERVER's result, not the client's claim.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/quick-ping_test.luau`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010, Story 007
- Unlocks: None internal
