# Story 012: Death Attribution Resolution & DeathAttributionPayload

> **Epic**: Ecological Disturbance
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-005` (published payload types incl. `DeathAttributionPayload`), `TR-ed-020` (archive resolution reference — reads, does not re-implement, Story 004's archive)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture), ADR-0005 (Death & Respawn Lifecycle)
**ADR Decision Summary**: `GetDeathAttributionPayload` is invoked eagerly, synchronously, inside the same `Humanoid.Died` handler that constructs the rest of the death snapshot (N6) — not lazily on HUD request. The payload is cached against the `deathEventId`-equivalent key for later HUD retrieval, closing the archive-entry-TTL-expiry race.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: MEDIUM
**Engine Notes**: The one confirmed-but-unverified risk this story depends on: N3 — Knit `RemoteSignal:Fire(player, ...)` targeting an already-departed `Player` must be a silent no-op (no error, no yield). This must be Studio-verified (per ADR-0004's N3 Decision) before this story's E.21/H.32c behavior can be trusted as correct rather than merely untested-in-the-failure-path.

**Control Manifest Rules (Core layer)**:
- Required: `GetDeathAttributionPayload` is constructed eagerly and synchronously inside the same `Humanoid.Died` handler that builds the rest of the death snapshot, cached by `deathEventId` — source: ADR-0004

---

## Acceptance Criteria

- [ ] **`DeathAttributionPayload`** (published Luau type, cite verbatim):
  ```luau
  type DeathAttributionEntry = {
      emissionId: string, sourcePlayerId: number, emissionType: EmissionType,
      emissionTime: number, positionLabel: string,
  }
  type DeathAttributionPayload = {
      killingEmissions: {DeathAttributionEntry}, -- 0-3 entries, ordered by contribution desc
      attributionMayBeIncomplete: boolean,
      predatorWasLockedAtDeath: boolean,
  }
  ```
- [ ] Resolution reads from the **attribution archive** (Story 004), NOT the live-source list. Unresolvable `emissionId`s (cap drops, expired entries) are skipped silently from `killingEmissions`, setting `attributionMayBeIncomplete = true`.
- [ ] **H.30** — GIVEN a player dies after predator locked onto a hotspot driven by a specific `emissionId` AND recorders on all 4 clients, WHEN `DeathAttributionPayload` constructed, THEN payload contains that `emissionId` with `sourcePlayerId`/`emissionType`/`emissionTime`/`positionLabel` populated, delivered exactly once to the dead player, zero times to the other three. `:FireAll` registers zero events.
- [ ] **H.30b** — GIVEN a Beacon emission published with `attributionChain=["BeaconPlaced"]` AND a player dies with the predator locked onto that Beacon, WHEN `DeathAttributionPayload` constructed, THEN `killingEmissions` entry has `emissionType="Beacon"`, `sourcePlayerId` matching the placing player, and the archive entry's `attributionChain` contains `"BeaconPlaced"`.
- [ ] **H.35c** — GIVEN a `MAX_LIVE_SOURCES` cap drop occurred during a player's contribution window AND that player subsequently dies, WHEN `DeathAttributionPayload` constructed, THEN `attributionMayBeIncomplete = true`. Cap drops outside the dead player's window do NOT set the flag.
- [ ] **E.9 (empty attribution)**: GIVEN a player dies in Calm tier with no emissions in the past 10 minutes, THEN `killingEmissions: []` (empty array, not nil) — a valid payload, not an error condition.
- [ ] **E.21 / H.32c (departed-player delivery)**: GIVEN the dead player rapid-disconnects before `OnDeathAttributionPushed:Fire()` executes, THEN: (a) the fire returns without error (silent no-op on a departed `Player`); (b) `attributionMayBeIncomplete` is NOT set true due to this (delivery failure ≠ data incompleteness); (c) an ops-log entry records the attempted-but-unfired delivery (`disturbance.attribution.delivery_failed_player_departed`, with `sourcePlayerId`/`deathTimestamp`/contributing emissionIds); (d) the surviving players' recorders capture zero payloads (no broadcast fallback); (e) no retry is attempted.
- [ ] `predatorWasLockedAtDeath` is read from Story 010's `_deathLockSnapshot` (read-and-clear, atomic within a single Luau frame — no yield between the table-read and the `nil`-assignment).
- [ ] Delivered via `DisturbanceService.Client.OnDeathAttributionPushed:Fire(deadPlayer, payload)` — **never** `:FireAll(...)`.

---

## Implementation Notes

Read-and-clear atomicity (cite verbatim, this is the canonical idiom for `GetDeathAttributionPayload`):
```luau
function DisturbanceService:GetDeathAttributionPayload(deadPlayer: Player): DeathAttributionPayload
    local snapshot = self._deathLockSnapshot[deadPlayer]
    self._deathLockSnapshot[deadPlayer] = nil
    return constructPayload(snapshot, ...)
end
```
Between the table-read and the `nil`-assignment there MUST be zero yield primitives. The cleared-entry semantics protects against re-resolution of a stale snapshot if the consumer requests the payload twice (the second call sees `nil` and follows the E.21 silent-no-op path — i.e., a repeated request after clear should be treated gracefully, not error).

`killingEmissions` ordering: up to 3 entries, ordered by contribution score descending — reuse `topContributorsAt`'s ordering from Story 008 (the predator's locked attribution list at the moment of death, resolved against Story 004's archive rather than the live-source list).

---

## Out of Scope

- Story 010: the death-lock snapshot's *capture* (this story only *reads and clears* it).
- Story 011: the predator-lock registry itself (this story only resolves already-locked `emissionId`s against the archive).
- HUD's own death-screen rendering and fallback copy for E.9's empty case (out of this epic — HUD GDD owns the visual, Q1 remains an open cross-GDD item unresolved as of this epic).

---

## QA Test Cases

- **AC-H.30**: Given: a player dies while predator-locked onto a hotspot with a known `emissionId` — When: `DeathAttributionPayload` constructed and pushed — Then: the payload's `killingEmissions` contains that `emissionId` with all 5 `DeathAttributionEntry` fields populated; delivered exactly once to the dead player via 4 client recorders (one per connected player); `:FireAll` call count = 0.
- **AC-H.30b**: Given: a Beacon emission with `attributionChain=["BeaconPlaced"]`, predator locked onto it, placing player dies — When: payload constructed — Then: entry has `emissionType="Beacon"`, correct `sourcePlayerId`, and the archive's `attributionChain` for that entry contains `"BeaconPlaced"`.
- **AC-H.35c**: Given: a cap drop (Story 003's live-source eviction) occurred DURING the dead player's contribution window — When: payload constructed — Then: `attributionMayBeIncomplete = true`. Edge case: a cap drop that occurred OUTSIDE the dead player's contribution window (e.g., before they even started contributing, or affecting a different player entirely) must NOT set the flag for this death.
- **AC-E.9**: Given: a player dies in Calm tier, no emissions in the past 10 minutes — When: payload constructed — Then: `killingEmissions = {}` (empty array, not nil); HUD-side handling is out of scope but the payload itself must be well-formed and non-erroring.
- **AC-E.21/H.32c**: Given: a dead player rapid-disconnects before the `:Fire()` call executes — When: `:Fire(deadPlayer, payload)` is invoked anyway — Then: (a) no error/exception; (b) `attributionMayBeIncomplete` unaffected by the delivery failure itself; (c) exactly one ops-log entry with the specified fields; (d) all 3 surviving players' recorders show zero `OnDeathAttributionPushed` payloads; (e) no retry logic fires. Edge case: verify this is tested against the ACTUAL Knit `RemoteSignal:Fire` no-op behavior on a departed player (per ADR-0004's N3 Studio-verification item) — if N3 has not yet been empirically confirmed, flag this test as depending on that unresolved verification.
- **AC — read-and-clear atomicity**: Given: `GetDeathAttributionPayload` is called twice in succession for the same `deadPlayer` (simulating a duplicate HUD request) — When: the second call runs — Then: it observes `_deathLockSnapshot[deadPlayer] == nil` (already cleared by the first call) and follows a graceful fallback path (does not error, does not fabricate a stale `predatorWasLockedAtDeath` value).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ecological-disturbance/death-attribution-payload_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 004, 010, 011
- Unlocks: None (consumed by HUD, outside this epic)
