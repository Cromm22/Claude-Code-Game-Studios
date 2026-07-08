# Story 013: HUD Meter & Alert Wiring (OnMeterUpdate/OnDisturbanceAlert)

> **Epic**: Ecological Disturbance
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-028` (Knit `DisturbanceService`+`DisturbanceController`, 3 `.Client` RemoteSignals fired `:Fire`/`:FireAll`), `TR-ed-035` (HUD meter tween is client-side; server pushes only `targetT` scalars), `TR-ed-066` (per-player targeted routing on 3 RemoteSignals — `:FireAll` forbidden, per-player t leak risk)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: No ADR-level deviation — this story implements the GDD's own C.3.4 contract directly. The one historical correction to carry forward: Knit `RemoteSignal` fires via `:Fire(player, ...)` (per-client) and `:FireAll(...)` (broadcast) — the raw RemoteEvent API names `:FireClient`/`:FireAllClients` are NOT methods on Knit RemoteSignal objects (an earlier GDD revision cited the wrong names; corrected).

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: MEDIUM
**Engine Notes**: Confirm the pinned Knit build's `RemoteSignal:Fire`/`:FireAll` method names match this story's implementation — this exact confusion (citing raw-RemoteEvent method names on a Knit RemoteSignal) has already occurred once in this GDD's own history and was corrected; do not reintroduce it.

**Control Manifest Rules (Core layer)**:
- No dedicated manifest line beyond the general Knit RemoteSignal per-player routing discipline; this story's `OnMeterUpdate`/`OnDisturbanceAlert` are the concrete instances of that discipline for ED.

---

## Acceptance Criteria

- [ ] **`OnMeterUpdate`**: server pushes per-player `t` and squad collective `t` (Story 007's `squadT`) at the field-update cadence (5Hz default) via `DisturbanceService.Client.OnMeterUpdate` (`Knit.CreateSignal()`). Payload: `MeterUpdatePayload = {playerT: number, squadT: number}` (the `beaconCapState`/`nearby`/`stationary_nearby` extension fields belong to Story 015, added here as `nil`-defaulted optional fields for forward-compatibility).
- [ ] **Routing (REQUIRED)**: fired **per-player** using `OnMeterUpdate:Fire(player, {playerT=thisPlayerT, squadT=currentSquadT})`. `:FireAll(...)` is FORBIDDEN for this signal (would leak per-player `t` to all clients or force the signal to drop the per-player field).
- [ ] **H.29** — GIVEN the HUD controller joined AND the harness installs `MockRemoteSignalRecorder` wrapping Knit `RemoteSignal:Fire`/`:FireAll`, WHEN the server's field update pushes a player's `t` change, THEN the recorder captures a payload whose top-level keys are exactly `{playerT, squadT}` (plus the Story 015 optional fields once that story lands) and asserts NO captured payload contains `sources`/`sourceList`/`emissions`/`otherPlayerPosition`/`position`/any other `Vector3` field.
- [ ] **H.29b** — GIVEN four mock clients with recorders at fieldValues {0.71, 0.34, 0.09, 0.02}, WHEN `OnMeterUpdate` fires, THEN each captures exactly one payload with its OWN `playerT`; ALL four carry the same `squadT=0.71`; `:FireAll` captured zero times.
- [ ] **H.29c** — GIVEN a mock client joins without `CharacterAdded` firing yet, WHEN the next cycle pushes, THEN the recorder captures `playerT=0.0` and `squadT=currentSquadT`, no error, no skipped push (E.17).
- [ ] **Initial sync on join**: server-pushed. When `Players.PlayerAdded` fires, the server registers the player and fires `OnMeterUpdate` to that player on the next field-update cycle (≤200ms after join). No client-initiated RemoteFunction exists for this (the round-1 `GetCurrentMeterValue` RemoteFunction stays removed).
- [ ] **`OnDisturbanceAlert`** (two sub-types, event-driven, fire-once-on-trigger): ACTIVE alert (a new emission's cumulative contribution pushes the field above a tier threshold at emission time — "you caused this"); PASSIVE alert (a player walks into a position whose existing field is above a tier threshold, fired once on entry, suppressed until exit+re-entry). Routed only to the triggering/entering player (`:Fire(player, payload)`), never `:FireAll`.
- [ ] Published payload types (cite verbatim):
  ```luau
  type AlertSubtype = "Active" | "Passive"
  type DisturbanceAlertPayload = {
      alertSubtype: AlertSubtype, emissionType: EmissionType,
      emissionId: string?, crossedTier: Tier, sourcePlayerId: number?,
  }
  ```
- [ ] Client never receives raw field data, only the derived `t` scalar. Per-player payloads do not reveal other players' `t` values.

---

## Implementation Notes

`OnMeterUpdate`/`OnDisturbanceAlert`/`OnDeathAttributionPushed` (Story 012) are the ONLY three RemoteSignals declared on `DisturbanceService.Client` — no more, no fewer (verified structurally here, mechanically by Story 016's H.39).

Send-on-change gate (advisory, NOT required): the implementation MAY skip a per-player fire on a tick if BOTH `playerT` and `squadT` are unchanged from the previous tick by less than 0.001 — this is an optional optimization; always-push is the default and is correct under always-push semantics. Do not implement this optimization unless Story 017's profiling shows it's needed.

Pre-character-spawn race (E.17): if `CharacterAdded` has not yet fired for the joining player when the first `OnMeterUpdate` would push, push `{playerT=0.0, squadT=currentSquadT}` — position-based `playerT` is correctly populated on the first cycle after `CharacterAdded` fires.

---

## Out of Scope

- Story 015: `beaconCapState`/`nearby`/`stationary_nearby` payload extension fields and the cap-state discriminant computation (this story only establishes the base `{playerT, squadT}` payload shape and the routing discipline the extension builds on).
- Story 012: `OnDeathAttributionPushed` (a separate signal with its own story — this story covers only `OnMeterUpdate` and `OnDisturbanceAlert`).
- HUD's own client-side rendering (tween, visual treatment) — entirely out of this epic.

---

## QA Test Cases

- **AC-H.29**: Given: `MockRemoteSignalRecorder` installed, a player's `t` changes — When: `OnMeterUpdate` fires — Then: captured payload's top-level keys are exactly `{playerT, squadT}` (no extras); no `Vector3`-typed field present anywhere in the payload.
- **AC-H.29b**: Given: 4 mock clients at fieldValues {0.71, 0.34, 0.09, 0.02} — When: `OnMeterUpdate` fires — Then: each of the 4 recorders captures exactly one payload with its own distinct `playerT`; all 4 share `squadT=0.71`; `:FireAll` call count = 0 across all 4 recorders combined.
- **AC-H.29c**: Given: a mock client joins, `CharacterAdded` has NOT fired — When: the next field-update cycle pushes — Then: recorder captures `{playerT=0.0, squadT=currentSquadT}`, no error, no skipped push. Edge case: `CharacterAdded` fires mid-cycle, between two pushes — the NEXT push after `CharacterAdded` must carry the correct position-based `playerT`, not still 0.0.
- **AC — initial sync on join**: Given: a player joins — When: the next field-update cycle completes — Then: that player receives their first `OnMeterUpdate` within ≤200ms of `PlayerAdded`. Edge case: 4 simultaneous joins (thundering-herd scenario) — verify no RemoteFunction round-trip is used anywhere in this path (structurally, `GetCurrentMeterValue` must not exist).
- **AC — `:FireAll` forbidden structurally**: Given: the `OnMeterUpdate`/`OnDisturbanceAlert` fire call-sites — When: statically inspected — Then: neither call site ever invokes `:FireAll(...)`; both invoke `:Fire(player, ...)` exclusively.
- **AC — ACTIVE/PASSIVE alert routing**: Given: player P triggers a PASSIVE alert by walking into an elevated zone — When: the alert fires — Then: only P's recorder captures the payload; the other 3 connected players' recorders capture zero payloads for that event.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ecological-disturbance/hud-meter-alert-wiring_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 006, 007
- Unlocks: 015
