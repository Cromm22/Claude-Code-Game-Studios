# Story 014: Haptic Feedback

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Visual/Feel
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-052` (`HapticService` rumble wrapped in `IsMotorSupported()` guard)

**ADR Governing Implementation**: ADR-0011: Player Controller Sprint-State Authority & Stamina Lifecycle (closest fit — haptics most naturally attach to this story's own sprint/stamina/death state transitions; no dedicated ADR governs haptic feedback itself, a named gap in the epic's own list)
**ADR Decision Summary**: Not directly addressed by any of the 7 governing ADRs. Per the GDD's own F.5 (Engine and Library Dependencies), `HapticService` is used for "optional gamepad rumble for state transitions / death feedback," and calls MUST be wrapped in an `IsMotorSupported()` guard.

**Engine**: Roblox Studio (live platform) | **Risk**: LOW
**Engine Notes**: `HapticService` and `IsMotorSupported()` are long-standing, well-documented Roblox APIs — no post-cutoff risk. No ADR formalizes trigger conditions or intensity; implement per the GDD's own F.5 note.

**Control Manifest Rules (Presentation layer)**:
- Required: All interactive prompts must work with touch tap, mouse click, and gamepad button — haptics is gamepad-only supplementary feedback, never a required channel (a player without gamepad rumble must receive equivalent information through another already-specified channel, e.g. `OnStaminaChanged`/`OnSprintPulse`'s audio cues).
- Guardrail: no per-frame haptic calls — trigger only on discrete state transitions (sprint force-walk, death, stamina depletion), never continuously.

---

## Acceptance Criteria

- [ ] **`IsMotorSupported()` guard (no dedicated H.x — verify via code review + a controller-connected Studio smoke test)** — every `HapticService` call is preceded by an `IsMotorSupported()` check on the target `Enum.UserInputType`; a call on an unsupported/disconnected gamepad motor does not throw and does not silently no-op in a way that breaks the surrounding code path.
- [ ] **Trigger-condition audit** — haptic feedback fires on the state transitions the GDD's own F.5 names as its intended use ("state transitions / death feedback"): at minimum, forced sprint-exhaustion (T2 via stamina=0, Story 001), and the T5 death transition (Story 005) — no haptic fires on every Heartbeat or on any non-discrete-transition event.
- [ ] **No gameplay-consequential dependency** — a player on a platform with no haptic motor (PC without a connected gamepad, or a gamepad with `IsMotorSupported()` returning false) experiences no functional degradation; haptics is confirmed to be a pure supplementary feedback channel, never a required one.

---

## Implementation Notes

- Wrap every `HapticService:SetMotor(...)` (or equivalent) call in an `IsMotorSupported(inputType, Enum.VibrationMotor.X)` guard — per the GDD's own F.5 flag from a gameplay-programmer review.
- Trigger conditions are NOT formally specified anywhere in the GDD beyond "state transitions / death feedback" — treat the forced sprint-exhaustion transition (Story 001's T2-at-stamina-0) and the T5 death transition (Story 005) as the minimum viable trigger set for this story, since those are the two state transitions explicitly named. Do not invent additional triggers (e.g. per-pulse rumble) without a design ruling — that would be scope creep against an unauthored mechanic.
- Client-side only — no server-side state is introduced by this story. The client's `PlayerControllerController` subscribes to the same server-pushed signals already established (`OnSprintStateChanged`, `OnPlayerDied`) and triggers the haptic call locally on receipt; no new RemoteEvent is needed.
- No dedicated ADR governs this mechanism — implement per the GDD's own F.5 note, and escalate to `/architecture-decision` if a real engine ambiguity is hit (e.g., if `IsMotorSupported()`'s behavior on a specific platform proves inconsistent with documentation during implementation).

---

## Out of Scope

- Any haptic feedback tied to unauthored mechanics (Predator AI proximity, oxygen-critical state, etc.) — those would require their own design ruling first; this story implements only the two GDD-named trigger conditions (state transitions, death).
- Audio/visual equivalents of these same feedback moments — those are HUD/audio-director owned (V/A.3 already covers the audio side of sprint/death feedback).

---

## QA Test Cases

- **Manual check (IsMotorSupported guard)**:
  - Setup: a connected gamepad supporting rumble, and a session with no gamepad connected.
  - Verify: with a gamepad, the trigger conditions produce a rumble; with no gamepad, no error is thrown and gameplay proceeds identically.
  - Pass condition: no exception in either case; rumble only fires when `IsMotorSupported()` returns true.
- **Manual check (trigger-condition audit)**:
  - Setup: a play session cycling sprint-to-exhaustion and a death.
  - Verify: haptic feedback fires at forced sprint-exhaustion and at death, and at no other point (no per-Heartbeat, per-pulse, or per-footstep rumble).
  - Pass condition: rumble count for a 30-second session matches exactly the count of the two named transitions that occurred.

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**: `production/qa/evidence/haptic-feedback-evidence.md`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (sprint-exhaustion transition), Story 004 (death transition)
- Unlocks: None
