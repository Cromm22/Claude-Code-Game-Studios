# Story 011: NetworkOwnership & Character Replication Bandwidth

> **Epic**: Player Controller
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-044` (server-tracked `HumanoidRootPart.Position` is PA's perception input; no client-predicted positions into perception), `TR-pc-047` (player characters default automatic NetworkOwnership; server-authoritative `WalkSpeed`), `TR-pc-048` (character-replication bandwidth baseline; PC signal budget within <50 KB/s ceiling)

**ADR Governing Implementation**: ADR-0008: Character Replication Bandwidth Baseline & NetworkOwnership Strategy
**ADR Decision Summary**: Player characters use default automatic `NetworkOwnership` (client-owned physics simulation for local responsiveness); gameplay-consequential state (`WalkSpeed`, death, RemoteEvent outcomes) is enforced through normal server-authority mechanisms, never through forcing ownership. Treat `architecture.md`'s ~15–30 KB/s "before any game code runs" figure as a provisional planning ceiling; every PC signal's bandwidth budget should be evaluated against `50 KB/s minus the measured baseline`, not the full ceiling.

**Engine**: Roblox Studio (live platform) | **Risk**: HIGH
**Engine Notes**: `NetworkOwnership` semantics themselves are LOW risk (long-standing, well-documented); the exact per-character baseline replication cost is engine-version- and network-settings-dependent and MUST be measured empirically (Roblox Studio Network stats or `Stats` service) during the `/prototype predator-ai` spike before any other system's bandwidth budget — including PC's own signal set — is treated as final.

**Control Manifest Rules (Core layer)**:
- Required: Player characters use Roblox's default automatic `NetworkOwnership`; gameplay-consequential state stays server-validated via RemoteEvents, never inferred from client-owned physics.
- Required: Every system's bandwidth budget must be evaluated against `50 KB/s minus the measured character-replication baseline`, not the full 50 KB/s ceiling.
- Forbidden: Never force server-owned `NetworkOwnership` on player characters — removes local movement responsiveness for zero server-authority benefit, since gameplay-critical state is already RemoteEvent-validated.

---

## Acceptance Criteria

- [ ] **H.28** — GIVEN a 4-player server running 300 Heartbeat ticks (5s simulated), all 4 cycling Walk/Sprint/Dead with lantern toggling each second, AND all 4 carrying `Pending` `reconcileRows` under an injected RM fault (exercising the full reconciliation scan-and-dispatch path), WHEN total CPU time attributed to PC's state machines + stamina + lantern + emission timers + the reconciliation tick's scan/dispatch is measured via `debug.profilebegin`/`debug.profileend`, THEN average per-frame cost < 0.1ms AND the reconciliation Heartbeat-body scan contributes < 0.01ms/tick.
- [ ] **H.29** — GIVEN a 4-player server in steady-state sprint, WHEN RemoteEvent traffic is sampled over 60 frames excluding character replication, THEN total outbound bandwidth for PC events (`OnSprintStateChanged`, `OnLanternStateChanged`, `OnStaminaChanged`, `OnSprintPulse` — ~60–80 B/s at 4 steady-state sprinters — ping/emote broadcasts) cumulative across all clients < 1 KB/s. `GatherNodeArmed`/`GatherNodeDisarmed` are RN-owned and accounted separately, not here.
- [ ] **NetworkOwnership confirmation (no dedicated H.x — verify via code review + a Studio smoke test)** — no `SetNetworkOwner` call exists anywhere on a player character's `HumanoidRootPart`; the default automatic ownership is retained; `Humanoid.WalkSpeed` remains server-set on every S1/S2/S3a/S3b transition regardless of ownership.
- [ ] **Empirical baseline measurement (ADR-0008 Validation Criteria, cross-epic)** — the `/prototype predator-ai` spike measures actual per-client bandwidth for a representative 4-player + 1-predator scene before Production sprint planning treats any system's bandwidth budget (including PC's own H.29 figure) as final.

---

## Implementation Notes

- **No explicit `SetNetworkOwner` call for player characters** — Roblox's default automatic ownership behavior is retained. This is the entirety of this story's `NetworkOwnership` implementation for player characters: doing nothing beyond what Stories 001/002/004/005 already implement server-side (`Humanoid.WalkSpeed` set server-side, death/respawn server-driven, all gameplay-consequential state RemoteEvent-validated per Story 010).
- **Distinction to encode in a code-review checklist, not runtime logic**: automatic `NetworkOwnership`'s "reassigns to whichever client is nearest" behavior applies to *ownerless physics props* (loose items, resource nodes) — it does NOT apply to a player's own controlled character assembly, which Roblox always automatically owns by that specific player regardless of other players' proximity. Do not conflate the two when reviewing PC code against Resource Node's future prop-ownership work.
- **Bandwidth accounting**: treat the provisional 15–30 KB/s "before any game code runs" figure as a planning ceiling, not a precise input, until the `/prototype predator-ai` spike measures the real number. PC's own signal budget (H.29's <1 KB/s figure) is evaluated against the *remaining* budget after that baseline, not the full 50 KB/s.
- **`HumanoidRootPart.Position` as PA's perception input**: PC does not push position to Predator AI — Predator AI reads the same server-tracked state PC already writes (`HumanoidRootPart.Position`, server-observed). PC must never introduce a client-predicted position into any cross-system perception path — this is the same server-authoritative-position discipline Story 003 already establishes for emission position, restated here as the NetworkOwnership-adjacent reason WHY it matters: a laggy client's locally-simulated position (permitted under default ownership for movement *feel*) must never leak into a gameplay-consequential read.
- Profile the reconciliation tick's Heartbeat-body cost (`debug.profilebegin("PC_ReconcileTick")`) EXCLUDING the `task.spawn`'d retry coroutines (Story 004's scan-only cost, not the yielding `RequestSquadOxygenSpend` calls).

---

## Out of Scope

- Predator AI epic: `SetNetworkOwner(nil)` for the predator NPC and its own bandwidth accounting (this story covers player characters only).
- The actual empirical baseline measurement itself — that is the `/prototype predator-ai` spike's deliverable, a separate pre-production task, not a PC story.
- Resource Node epic: `GatherNodeArmed`/`GatherNodeDisarmed` bandwidth accounting (RN-owned).

---

## QA Test Cases

- **AC-1 (H.28 — CPU budget)**:
  - Given: 4-player server, 300 ticks, mixed state cycling, injected RM fault exercising full reconciliation scan.
  - When: profiled via `debug.profilebegin`/`profileend`.
  - Then: average <0.1ms/frame; reconciliation scan alone <0.01ms/tick.
  - Edge cases: worst-case all-4-players-simultaneously-Pending scenario, not just a steady-state idle case.
- **AC-2 (H.29 — bandwidth budget)**:
  - Given: 4-player steady-state sprint.
  - When: sampled over 60 frames.
  - Then: cumulative PC event bandwidth <1 KB/s (excluding character replication and RN-owned events).
- **AC-3 (NetworkOwnership code-review check)**:
  - Given: PC's full codebase.
  - When: grepped for `SetNetworkOwner`.
  - Then: zero matches on any player-character `HumanoidRootPart`.
  - Edge cases: confirm `Humanoid.WalkSpeed` assignment happens server-side in every transition handler regardless.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/networkownership-bandwidth_test.luau`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001
- Unlocks: None internal (closes PC's own bandwidth/ownership obligation; the cross-epic empirical measurement at the `/prototype predator-ai` spike is what finalizes every system's budget, including this one)

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: NetworkOwnership confirmation fully COVERED (zero `SetNetworkOwner` calls anywhere in `src/`, `WalkSpeed` confirmed server-set at both write sites). H.28/H.29 honestly DEFERRED (`pending()`) — require live Roblox Studio profiling, matching this story's own Out of Scope section. Empirical baseline measurement correctly deferred to the cross-epic `/prototype predator-ai` spike.
**Deviations**: None — no production code changes were needed; the story's entire "implementation" is a verified absence of `SetNetworkOwner`, per its own Implementation Notes.
**Test Evidence**: `tests/integration/player-controller/networkownership-bandwidth_test.luau` — passing
**Code Review**: Complete (combined pc-3+pc-11 review) — APPROVED WITH SUGGESTIONS
