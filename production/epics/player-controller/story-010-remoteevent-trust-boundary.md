# Story 010: RemoteEvent Trust Boundary Application (Canonical Order + Global Budget)

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-035` (client-fired RemoteEvent canonical validation: alive-guard → rate+burst → payload → server re-derivation, drop-first), `TR-pc-036` (per-player global RemoteEvent budget across all client-fired events), `TR-pc-037` (server-pushed-only events register zero `OnServerEvent` callbacks)

**ADR Governing Implementation**: ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting
**ADR Decision Summary**: Every client→server RemoteEvent handler MUST evaluate a 6-step canonical order (alive/state guard → per-event rate+burst → per-player global budget of 30 accepted fires/sec (tumbling 1.0s window) → payload shape validation → server-side plausibility re-derivation → domain validation). A dropped event (steps 1–4) must not mutate any state. Server-pushed-only surfaces register zero `OnServerEvent` callbacks.

**Engine**: Roblox Studio (live platform) | **Risk**: LOW
**Engine Notes**: Server validation of client-fired RemoteEvents is a long-standing, well-documented Roblox pattern (`FilteringEnabled` is mandatory and long-standing). Nothing here depends on a post-cutoff API.

**Control Manifest Rules (Core layer)**:
- Required: Every client-fired `RemoteEvent` handler evaluates this exact 6-step order.
- Required: A dropped event (steps 1–4) must not mutate any state, including cooldown/grace-timer anchors.
- Required: Enforce a per-player global RemoteEvent budget of 30 accepted fires/sec (tumbling 1.0s window), checked after the per-event rate limit, incremented only on events that pass steps 1–2.
- Required: Server-pushed-only surfaces (respawn, squad join/leave, AFK kick, death confirmation, flora chunk subscription — and PC's own `OnPlayerDied`/`OnPlayerRespawned`) register zero `OnServerEvent` callbacks.
- Forbidden: Never respond to a rejected/rate-limited RemoteEvent with an explicit error response to the client.
- Forbidden: Never rely on per-event rate limits alone without the per-player global budget.
- Forbidden: Any future `RemoteFunction` (none exist today) must always return a value on every path, including rejection — never reuse the silent-drop convention.

---

## Acceptance Criteria

- [ ] **H.62** — GIVEN the C.9 registry limits, WHEN `RequestGather {nodeId}` arrives (a) from a player in S4 → rejected (alive-guard); (b) with an unknown/stale `nodeId` → rejected silently; (c) from a player whose server-tracked position is farther than `GATHER_PROXIMITY_RADIUS=4` studs from the node center → rejected (server-side proximity re-check, spoofed armed-prompt state never trusted); (d) at a rate exceeding 2/s + burst 4/2.0s → excess dropped silently; (e) alive + valid `nodeId` + in range + within limits → forwarded to Resource Node's receive side.
- [ ] **H.63** — Same shape as H.62 against `RequestInteract {targetId}`: S4/dead reject, unknown `targetId` reject, out-of-range reject, rate limit 2/s + burst 4/2.0s, valid case forwarded to Crafting's receive side.
- [ ] **H.77** — GIVEN a player in S1, WHEN `RequestSprintToggle {sprint=false}` arrives (same-state), THEN dropped before any side-effect (no transition, no `OnSprintStateChanged`, no grace-anchor read). Burst-cap case: >15 events in 2.0s → excess dropped while the 10/s per-second limit also holds. Paired alternating-from-S2 burst case: a burst of alternating `{sprint=false}`/`{sprint=true}` at above-cap rate (each a genuine state change) still bounds the number of accepted T1 sprint-entries to the burst cap, so grace-exempt Sprint first-pulses cannot be harvested beyond C.8.1's cooldown-permitted rate.
- [ ] **Global budget unit test (ADR-0006 Validation Criteria)** — a simulated client firing 6 different under-their-own-limit events in rapid alternation is capped by the global 30/s budget once the sum exceeds it.
- [ ] **No-mutation-on-reject test (ADR-0006 Validation Criteria)** — a rejected event (any of steps 1–4) is confirmed to leave no observable state mutation (cooldown anchors, grace timers unchanged).
- [ ] **Zero-registration audit** — every PC server-pushed-only `RemoteEvent` (`OnPlayerDied`, `OnPlayerRespawned`, `OnSprintStateChanged`, `OnLanternStateChanged`, `OnStaminaChanged`, `OnSprintPulse`, `OnPingBroadcast`, `OnEmoteBroadcast`, `OnWorldResponseCue`) registers zero `OnServerEvent` callbacks — grep-verifiable.

---

## Implementation Notes

- Implement the shared `checkGlobalBudget(player)` helper exactly per the ADR's Key Interfaces: a tumbling (hard-reset every 1.0s) per-player window counter, NOT a true sliding window — this permits up to ~2× burst near a window boundary, an accepted trade-off, not an exploit-tuning oracle. Checked AFTER the per-event rate limit (step 3), incremented ONLY on events that pass steps 1–2 (a per-event-rejected event never consumes global budget).
  ```luau
  local GLOBAL_REMOTE_EVENT_BUDGET_PER_SEC = 30
  local function checkGlobalBudget(player: Player): boolean
      local now = workspace:GetServerTimeNow()
      local record = _globalEventCounts[player]
      if not record or (now - record.windowStart) >= 1.0 then
          record = {count = 0, windowStart = now}
          _globalEventCounts[player] = record
      end
      if record.count >= GLOBAL_REMOTE_EVENT_BUDGET_PER_SEC then return false end
      record.count += 1
      return true
  end
  ```
- Retrofit this shared helper into every RemoteEvent handler built in Stories 001, 002, 005, 009 (`RequestSprintToggle`, `RequestLanternToggle`, `RequestGather`, `RequestInteract`) as their step-3 check, and audit that each handler's step-1 alive/state guard runs FIRST and unconditionally.
- Add `Players.PlayerRemoving` cleanup for `_globalEventCounts[player] = nil` — without it this table leaks a stale record per departed player for the life of the server.
- **Silent-drop convention scope note**: this applies to fire-and-forget `RemoteEvent`s only. This project has no `RemoteFunction` surface today — if one is ever added, it must NOT reuse the silent-drop convention (an un-returned `RemoteFunction` leaves the calling client's coroutine yielded indefinitely); it must always return a value, including on rejection.
- **Server-pushed-only audit**: confirm via grep (or a small static-analysis pass) that `OnPlayerDied`, `OnPlayerRespawned`, and every other PC event with no client-fire path have literally zero `OnServerEvent:Connect(...)` calls anywhere in PC's codebase.
- The 30/s figure is a first estimate derived from summing PC's current per-event limits at their busiest legitimate combination (~21.3/s) with headroom — re-derive if a future GDD adds a new high-frequency client event (flagged in ADR-0006's own Risks as something a future architecture-review pass should re-check).

---

## Out of Scope

- Resource Node epic / Crafting epic: the deep/domain validation (step 6) for `RequestGather`/`RequestInteract`'s receive side — this story stops at step 5.
- Story 012/013: `RequestPing`/`RequestEmote`'s own event-specific rules (this story establishes the shared infrastructure they will consume).
- Any future `RemoteFunction` surface — none exists today; this story only states the binding rule for if/when one is added.

---

## QA Test Cases

- **AC-1 (H.62/H.63 — trust boundary matrix for RequestGather/RequestInteract)**:
  - Given: each of the five conditions (S4, unknown id, out-of-range, over-rate, valid).
  - When: the respective request arrives.
  - Then: rejected/rejected/rejected/dropped/forwarded respectively.
  - Edge cases: a spoofed client-side "armed" state must not bypass the server-side proximity re-check.
- **AC-2 (H.77 — sprint toggle burst + same-state parity with lantern)**:
  - Given: player in S1.
  - When: same-state toggle arrives.
  - Then: dropped before any side-effect.
  - Edge cases: alternating-from-S2 burst must still bound grace-exempt pulse harvesting to the cooldown-permitted rate.
- **AC-3 (global budget)**:
  - Given: a client alternating 6 different under-limit events.
  - When: combined rate exceeds 30/s.
  - Then: capped once the sum crosses the threshold, incremented only on events that already passed steps 1–2.
- **AC-4 (no-mutation-on-reject)**:
  - Given: a cooldown anchor at some known value.
  - When: a flood of rejected events (any of steps 1–4) arrives.
  - Then: the anchor is provably unchanged after the flood.
- **AC-5 (zero-registration audit)**:
  - Given: PC's full RemoteEvent surface.
  - When: grepped for `OnServerEvent:Connect`.
  - Then: zero matches on every server-pushed-only event name.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/remoteevent-trust-boundary_test.luau`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 005, Story 009 (retrofits the shared budget/order infrastructure into their already-built handlers)
- Unlocks: Story 012, Story 013
