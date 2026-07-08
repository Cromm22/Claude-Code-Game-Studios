# Story 013: Emote Wheel & Cosmetic Boundary

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-049` (emote slots 4-6 cosmetically replaceable; no cosmetic may alter `WalkSpeed`/emission magnitudes)

**ADR Governing Implementation**: ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting (closest fit — `RequestEmote`'s slot-validation and rate-limit are a direct application of the canonical order; no dedicated ADR governs the emote wheel's D-pad flow or the cosmetic-boundary rule itself, both gaps in the epic's own list)
**ADR Decision Summary**: `RequestEmote` follows the canonical 6-step order (payload shape validation at step 4 rejects any non-integer/out-of-range/non-number `slot`). The `renderScope` discriminator established in Story 007 (`"world"` vs `"squad-ui"`) governs the dead-player emote billboard suppression.

**Engine**: Roblox Studio (live platform) | **Risk**: LOW
**Engine Notes**: No post-cutoff API. No dedicated ADR governs the emote wheel's client-side D-pad/touch/hold flow (C.4.2) or the cosmetic-boundary checklist (a project-wide `technical-preferences.md`/game-concept principle, not an ADR) — implement per the GDD's own specification.

**Control Manifest Rules (Core/Presentation layer)**:
- Required: `OnEmoteBroadcast`'s `renderScope` discriminator is server-minted from the emitter's server-tracked state at broadcast time — never client-supplied.
- Required: All interactive prompts must work with touch tap, mouse click, and gamepad button — no hover-only interactions (the emote wheel's D-pad fallback is this rule's concrete instance).
- Forbidden: Never let a cosmetic emote replacement alter any input the predator AI consumes (`WalkSpeed`, sprint/light emission magnitudes) — the cosmetic-boundary rule.

---

## Acceptance Criteria

- [ ] **H.19** — GIVEN a player in any state opens the emote wheel and selects any of slots 1–6, WHEN the emote fires, THEN `DisturbanceService:Emit` is NOT called (zero invocations), asserted AFTER confirming exactly one `OnEmoteBroadcast` fired for the selected slot (non-vacuous — an unwired handler that never fires the emote cannot pass this AC).
- [ ] **H.20** — MANUAL-PLAYTEST (Gamepad, D-pad-only): GIVEN right stick masked off, WHEN the player presses D-pad Up (held 0.3s) to open, D-pad Left/Right to cycle, `A/Cross` to commit, THEN one of the 6 emotes fires correctly and displays for `EMOTE_DISPLAY_DURATION = 4s`.
- [ ] **H.30** — MANUAL-PLAYTEST (Gamepad, D-pad-only): GIVEN a player using only D-pad + face buttons, WHEN opening the wheel and reaching any of the 6 slots, THEN every slot is reachable in ≤5 button presses.
- [ ] **H.67** — WHEN `RequestEmote` arrives with `slot=2.5` (non-integer), `7`/`0`/`-1` (out-of-range), `"3"` (non-number), or `nil`, THEN each is rejected server-side (no `OnEmoteBroadcast`, no cooldown charged); `slot ∈ {1,...,6}` as an integer is accepted within rate limits. `RequestEmote` carries ONLY `slot` — `renderScope` is server-minted and has no inbound field to validate (asserted in H.80, cross-referenced).
- [ ] **H.76** — MANUAL-DEVICE / client-integration, ADVISORY: GIVEN a player opens the emote wheel (client T9 gather lock engaged) and makes no slot selection, WHEN `EMOTE_WHEEL_IDLE_TIMEOUT = 4.0s` elapses, THEN the wheel auto-closes client-side, no emote is committed (no cooldown charge), and the client-side T9 gather lock releases. This is client-side-only — no headless server contract exists to gate here.
- [ ] **H.80 Part 1** — GIVEN a player in S4 (corpse `HumanoidRootPart` still present) who fires `RequestEmote`, WHEN processed, THEN accepted and `OnEmoteBroadcast` sent with `renderScope == "squad-ui"` (server-minted from S4 state; a client-supplied `renderScope` in the request is ignored/does-not-exist), payload carries NO world-position/corpse-anchor field. Paired positive contrast: a LIVING player's emote broadcasts `renderScope == "world"`.

---

## Implementation Notes

- **Zero-disturbance contract (H.19)**: emotes generate ZERO disturbance — server-validated. Assert the zero-`Emit` negative only AFTER proving the emote path was actually exercised (one `OnEmoteBroadcast` fired) — an unwired handler must not vacuously pass.
- **Slot validation (H.67)**: `RequestEmote {slot: integer 1..6}` — reject non-integer (`slot % 1 ~= 0`), out-of-range, or non-number values at payload-shape validation (step 4 of the canonical order). Rate limit: `EMOTE_COOLDOWN_PER_PLAYER = 3.0s` + burst cap `5` per `15.0s`.
- **Slot semantics**: 6 slots, ordered by predicted use frequency (Quiet, Follow me, Danger, All clear, Wait, Help/SOS). Slots 1–3 are functionally locked; **slots 4–6 are cosmetically replaceable via Robux purchases** — animation-swap with semantic preservation, per the cosmetic-boundary rule. No cosmetic may alter `WalkSpeed`, lantern brightness, sprint/light emission magnitude, or any other predator-perceived input (TR-pc-049's core requirement).
- **`renderScope` on `OnEmoteBroadcast` (H.80)**: server-minted, `∈ {"world", "squad-ui"}`, set from the emitter's server-tracked state (the `renderScope` established in Story 007) at broadcast time — `"squad-ui"` when the emitter is in S4, `"world"` when alive. This is what suppresses the world-space billboard over a dead player's corpse (the dead-position-tell class that got S4 `RequestPing` cut). HUD owns the render — this story's server-side obligation ends at minting the correct discriminator.
- **Accidental-open lockout (H.76)**: an open emote wheel with no slot selection auto-closes after `EMOTE_WHEEL_IDLE_TIMEOUT = 4.0s` (range 2–8s) — client-side entirely (the server has no wheel-open state; it only ever sees a `RequestEmote` on commit). This is NOT a headless-gateable AC — it's MANUAL-DEVICE/client-integration ADVISORY, do not attempt to force it into an AUTO-UNIT test.
- **D-pad fallback (accessibility)**: `D-pad Up` (hold 0.3s) opens and LATCHES the wheel open (does not close on release); `D-pad Left/Right` cycles; `A/Cross` commits and closes; `D-pad Down` cancels and closes; also closes on `EMOTE_WHEEL_IDLE_TIMEOUT` or a T5 death force-close (Story 007's S4 entry).
- **T9 mutual exclusion** (touch only): while the wheel is open, tap-hold gather is locked out client-side on the right-thumb zone — gated on `isTouch` input context, NOT on bare wheel-open state (there is no tap-hold gather gesture on gamepad/PC, so an open wheel must not suppress gather on those platforms).

---

## Out of Scope

- Story 007: `renderScope` minting mechanics themselves (this story only consumes it as the `OnEmoteBroadcast` discriminator).
- Story 010: the shared canonical-order helper and global budget (consumed, not redefined).
- Cosmetic purchase flow / `MarketplaceService:ProcessReceipt` — deferred to the Save/Load epic (ADR-0007), out of this epic's scope entirely; this story only enforces that a cosmetic emote replacement cannot touch gameplay-consequential values.

---

## QA Test Cases

- **AC-1 (H.19 — zero-disturbance, non-vacuous)**:
  - Given: player selects an emote slot.
  - When: emote fires.
  - Then: exactly one `OnEmoteBroadcast` (proves wiring), then zero `DisturbanceService:Emit` calls.
- **AC-2 (H.67 — slot validation)**:
  - Given: various malformed `slot` values.
  - When: `RequestEmote` sent.
  - Then: all rejected, no broadcast, no cooldown charge.
  - Edge cases: a valid integer slot within {1..6} must be accepted and rate-limited normally.
- **AC-3 (H.80 — renderScope discriminator, S4 vs alive contrast)**:
  - Given: a player in S4.
  - When: `RequestEmote` fires.
  - Then: `renderScope == "squad-ui"`, no world-position field.
  - Given: the same player alive.
  - When: `RequestEmote` fires.
  - Then: `renderScope == "world"`.
  - Edge cases: a client-supplied `renderScope` in the request payload must have no effect (the field doesn't exist on `RequestEmote`).
- **Manual check (H.20/H.30 — D-pad-only reachability)**:
  - Setup: gamepad with right stick masked off.
  - Verify: all 6 slots reachable in ≤5 presses; selected emote fires and displays for 4s.
  - Pass condition: no slot requires the right stick at any point.
- **Manual check (H.76 — idle-timeout auto-close)**:
  - Setup: touch device, open wheel, make no selection.
  - Verify: after 4.0s, wheel closes, no emote committed, gather lock releases.
  - Pass condition: no `RequestEmote` observed on the network, no cooldown UI indicator engaged. Evidence logged to `production/qa/evidence/emote-wheel-idle-close.md`.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/emote-wheel-cosmetic_test.luau` + `production/qa/evidence/emote-wheel-idle-close.md` + `production/qa/evidence/dead-emote-billboard.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 010, Story 007
- Unlocks: None internal
