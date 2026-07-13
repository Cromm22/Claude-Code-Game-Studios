# Interaction Pattern Library

> **Status**: In Design (first draft — authored during Pre-Production to close a
> carried `/gate-check` obligation, ahead of any full UX spec authoring pass)
> **Author**: producer + gameplay-programmer (standing in for an unstaffed ux-designer role)
> **Last Updated**: 2026-07-06
> **Template**: Interaction Pattern Library

> **Provenance note**: This skill normally catalogs patterns already in use across
> existing `design/ux/*.md` specs. None exist yet — this is the first UX-layer
> document for this project. The patterns below are instead extracted from
> interaction rules already frozen in the MVP GDDs (`player-controller.md`,
> `hud.md`, and the ADR-0006 RemoteEvent trust boundary), since those are the
> closest thing to an approved interaction contract that exists today. Treat this
> as a real first draft, not a placeholder — but expect it to grow once
> `design/ux/hud.md` and other screen specs are authored and can be cross-checked
> against it.

---

## Overview

Terranova has no traditional menu-heavy UI — the interaction surface is almost
entirely in-world (movement, gather, craft, lantern, ping, emote) plus a HUD that
reads server state. Patterns here are grouped by category: **Input Parity**
(the same action across touch/gamepad/KB+M), **Feedback** (how the game
communicates state without relying on color alone), and **Trust Boundary**
(how a client-fired action behaves when the server rejects it — a UX-visible
consequence of ADR-0006, not just a networking concern).

---

## Pattern Catalog

| Pattern | Category | Used In (GDD source) |
|---|---|---|
| Cross-Input Action Parity | Input Parity | Player Controller (sprint, gather, lantern, ping) |
| Hold-vs-Toggle Action | Input Parity | Player Controller (sprint) |
| Tap-Hold Commit (progress-gated action) | Input Parity | Player Controller (gather), Resource Node |
| Multi-Touch Gesture (two-finger) | Input Parity | Player Controller (ping) |
| Silent-Drop Rejection | Trust Boundary / Feedback | ADR-0006 (all client-fired RemoteEvents) |
| Color-Independent Status Readout | Feedback | HUD (disturbance meter, oxygen state, node tier, beacon tier) |
| Bearing + Distance-Band Indicator | Feedback | HUD / Predator AI |
| Rate-Limited Push Signal | Feedback | HUD (all producer-pushed HUD signals) |
| Combined-Flash Ceiling | Feedback / Accessibility | HUD (`FlashArbiter`) |
| Server-Clock-Derived Countdown | Feedback | HUD (gather ring, survival-window timer) |
| Reduced-Motion Degrade | Feedback / Accessibility | HUD |

---

## Patterns

### Cross-Input Action Parity

**Category**: Input Parity
**Used In**: Player Controller (sprint, gather, lantern toggle, ping), and by
extension any future client-fired action

**Description**: Every player-triggered action must have an explicit, designed
binding on all three supported input methods (touch, gamepad, keyboard/mouse) —
never a single binding assumed to "just work" across platforms via engine
defaults. This project's `technical-preferences.md` already makes this a hard
platform requirement ("All interactive prompts must work with touch tap, mouse
click, and gamepad button"); this pattern is the interaction-design form of
that rule.

**Specification**:
- Every action definition names its touch binding, its gamepad binding, and its
  KB+M binding as three separate, explicit entries — not "keyboard, and touch
  inherits the same gesture."
- No action may rely on hover for its primary trigger (mobile/gamepad have no
  hover) — confirmed as a project-wide forbidden pattern in the control manifest.
- When a new action is added to any system, its cross-input bindings must be
  specified in the same GDD pass that defines the action — not deferred to
  implementation.

**When to Use**: Every client-triggered gameplay action, with no exception.
**When NOT to Use**: N/A — this is a floor requirement, not a situational choice.

---

### Hold-vs-Toggle Action

**Category**: Input Parity
**Used In**: Player Controller — sprint (touch: toggle; KB+M: hold; gamepad: L3-hold)

**Description**: The same logical action (sprint) uses a *different* interaction
shape per input method, chosen for that method's own ergonomics — touch already
uses toggle because a sustained-hold gesture on a touchscreen is uncomfortable
and imprecise, while KB+M and gamepad use hold because it's the lower-friction
default there. This is a deliberate divergence, not an inconsistency: the
pattern is "match the interaction shape to the input method's ergonomics," not
"use identical gestures everywhere."

**Specification**:
- Touch: single tap toggles the state on; a second tap (or an explicit stop
  affordance) toggles it off.
- KB+M / Gamepad: holding the bound key/button sustains the state; releasing
  ends it.
- The accessibility layer (see `design/ux/accessibility-requirements.md`,
  Motor Accessibility) should extend the toggle *option* to KB+M/gamepad too,
  as a settings-level choice — the default per-platform shape above stays,
  but players who need it can opt into toggle-everywhere.

**When to Use**: Any sustained-state action (sprint, block, aim) where a
platform's default gesture would create a real ergonomics or accessibility gap.
**When NOT to Use**: One-shot actions (jump, interact) — those are always a
single tap/press/click regardless of platform.

---

### Tap-Hold Commit (progress-gated action)

**Category**: Input Parity
**Used In**: Player Controller / Resource Node — gather (500ms wall-clock hold)

**Description**: An action that requires a sustained input over a fixed
duration before it commits, rendered as a filling ring or bar the player can
watch and cancel out of. The commit duration is wall-clock time (measured in
milliseconds), never frame-count, so it behaves identically regardless of
framerate — a project-wide rule, not specific to gather.

**Specification**:
- Duration is a named constant (e.g. `GATHER_HOLD_DURATION = 500ms`), never a
  hardcoded magic number at the call site.
- The ring/progress indicator is the **one** client-predicted UI element this
  project permits (per ADR-0008's client-prediction scope) — it fills based on
  local input timing, but the actual gather only commits after the server
  confirms `RequestGather`. If the server rejects, the ring must visibly reset,
  not silently freeze.
- Releasing early cancels the hold with no penalty and no partial credit.
- An accessibility timing-multiplier setting (0.5x–3.0x, per the accessibility
  requirements doc) must scale this duration.

**When to Use**: Any action gated behind a "channel/commit" period rather than
an instant trigger.
**When NOT to Use**: Instant actions (ping, emote, toggle) — no ring needed.

---

### Multi-Touch Gesture (two-finger)

**Category**: Input Parity
**Used In**: Player Controller — ping (two-finger tap, 150ms window)

**Description**: A small number of actions that would otherwise conflict with
a single-finger gesture already bound to something else (e.g., camera drag or
gather-hold) are triggered by a distinct multi-touch gesture instead, detected
via a per-frame touch-point accumulator rather than any built-in gesture
recognizer (since `ContextActionService` cannot natively express multi-touch
combinations).

**Specification**:
- Gesture window (currently `PING_TWO_FINGER_WINDOW=150ms`) is a named,
  tunable constant.
- This pattern should be used sparingly — multi-touch gestures are the
  hardest interaction shape for players with limited dexterity or single-hand
  play; before adding a second multi-touch-gated action, check the Motor
  Accessibility section of the accessibility requirements doc for a one-hand
  alternative.

**When to Use**: A secondary/non-critical action that has no free single-touch
gesture available on mobile.
**When NOT to Use**: Any primary or time-critical action — those need a
single-touch binding at minimum, with multi-touch as an optional shortcut, not
the only path.

---

### Silent-Drop Rejection

**Category**: Trust Boundary / Feedback
**Used In**: Every client-fired RemoteEvent, project-wide (ADR-0006)

**Description**: When the server rejects a client-fired action (rate limit,
global budget, invalid state, failed re-derivation), it does **not** send an
explicit rejection response — this is a deliberate security choice (ADR-0006:
an explicit rejection gives an attacker a clean oracle to tune exploit timing
against). This has a real, unavoidable UX consequence: from the player's
perspective, a rejected action simply appears to do nothing. Every interaction
built on top of a RemoteEvent must design for this — the *client-side* feedback
for "my input was rejected" has to come from the client's own local read of
its current cooldown/state, not from a server acknowledgment.

**Specification**:
- Any action with a cooldown or rate limit must render its own cooldown state
  client-side (e.g., a greyed-out gather prompt, a cooling-down ping icon) so
  the player has a *local* explanation for why nothing happened, without the
  server ever confirming the rejection.
- Never design a UI flow that waits for an explicit "rejected" event from the
  server — none will come, by design.
- This pattern is the reason the Tap-Hold Commit pattern above requires the
  ring to visibly reset on a server rejection: the reset itself is the only
  feedback the player gets.

**When to Use**: Every client-fired action — this is a floor requirement of
the project's trust-boundary architecture, not an optional pattern.
**When NOT to Use**: N/A.

---

### Color-Independent Status Readout

**Category**: Feedback
**Used In**: HUD — disturbance meter, oxygen state, node tier, beacon tier

**Description**: Every status readout that uses color to communicate a tier or
state (disturbance level, oxygen health, node yield tier, beacon charge stage)
must pair that color with a non-color signal — numeric value, distinct icon,
distinct shape, or distinct pip pattern — so the information survives all
colorblind modes. This directly implements the Color-as-Only-Indicator Audit
in `design/ux/accessibility-requirements.md`; that document is the source of
truth for which specific elements still need a backup designed.

**Specification**:
- No status element may rely on hue alone to distinguish two states a player
  must act on differently.
- The non-color backup must be visible at the same time as the color signal
  (not hidden behind a hover/focus state, since this project has none).

**When to Use**: Every color-coded gameplay status readout.
**When NOT to Use**: Purely decorative/ambient color (e.g., bioluminescence
mood lighting that isn't a player-facing signal) — that's the art bible's
domain, not this pattern's.

---

### Bearing + Distance-Band Indicator

**Category**: Feedback
**Used In**: HUD / Predator AI — predator proximity chevron, eye-shine

**Description**: Predator proximity is communicated via a screen-space chevron
(bearing + distance-band, never exact world position, per PA's RR-4 anti-wallhack
rule) plus a screen-space eye-shine cue at close range — deliberately never a
minimap dot or world-anchored marker. This is both a design choice (preserving
tension/legibility, Pillar 1) and a security constraint (exact position would
leak information the predator's own stealth design depends on hiding).

**Specification**:
- Chevron intensity/pulse-rate — not hue alone — should communicate proximity
  urgency (ties into Color-Independent Status Readout above).
- Eye-shine only triggers at the CONTACT distance band; it is a supplementary
  cue, not a replacement for the chevron.

**When to Use**: Any threat/entity-proximity indicator in this game.
**When NOT to Use**: N/A within this game's current scope (single predator).

---

### Rate-Limited Push Signal

**Category**: Feedback
**Used In**: HUD — every producer-pushed HUD signal (oxygen, disturbance meter, node state, etc.)

**Description**: HUD never polls; every value it displays arrives via a
server-pushed signal at a bounded rate (≤5Hz typical, per ADR-0008's bandwidth
accounting). Between pushes, the HUD interpolates/dead-reckons locally rather
than freezing — e.g., the oxygen meter dead-reckons using the last known drain
rate. This pattern exists so implementers don't accidentally design a HUD
element that looks "laggy" between the (intentionally infrequent) authoritative
pushes.

**Specification**:
- Any new HUD element must specify both its producer push rate AND its local
  interpolation behavior between pushes — a push rate alone is an incomplete
  spec.
- Interpolation must never overshoot past the next authoritative push's value
  in a visually jarring way (dead-reckoning should "catch up" smoothly, not snap).

**When to Use**: Every HUD element backed by a server-authoritative value.
**When NOT to Use**: Client-predicted UI (there is exactly one exception in
this project — the Tap-Hold Commit gather ring above).

---

### Combined-Flash Ceiling

**Category**: Feedback / Accessibility
**Used In**: HUD — `FlashArbiter` (disturbance spike, beacon-window, node
completion, and any future flash/throb cue)

**Description**: This project has more than one system capable of triggering a
screen flash or throb (disturbance spikes, beacon-window pulses, node
completion). No individual system may manage its own flash timing — all flash
requests route through one arbiter module that enforces a combined ceiling of
≤3 onsets/second (WCAG 2.3.1), coalescing simultaneous requests from different
sources into one onset rather than stacking them.

**Specification**:
- Any new gameplay system that wants a flash/throb cue must route the request
  through `FlashArbiter`, never implement its own `TweenService` flash call
  directly.
- The arbiter is a pure `(request-stream, clock) -> onset-schedule` function —
  unit-testable with a fake clock (see `tests/unit/` once implemented).

**When to Use**: Any visual flash, throb, or rapid-pulse cue anywhere in the game.
**When NOT to Use**: N/A — this is the sole permitted path for this cue type.

---

### Server-Clock-Derived Countdown

**Category**: Feedback
**Used In**: HUD — gather-ring progress, survival-window countdown, respawn timer

**Description**: Any on-screen countdown or progress timer derives its
remaining time from a single server timestamp (`GetServerTimeNow()`) captured
once at the start of the timed action, recomputed locally every frame as
`duration - (now - startTimestamp)` — never a client-side `task.delay`/local
timer that could drift from the server's own authoritative deadline.

**Specification**:
- Every timed HUD element must specify which server-provided
  `startTimestamp`/`duration` pair it derives from.
- Zero/negative-duration results must be guarded and clamped, not allowed to
  display a negative countdown.

**When to Use**: Every player-facing countdown tied to a server-timed event.
**When NOT to Use**: Purely decorative animation timing (unrelated to a
game-state deadline).

---

### Reduced-Motion Degrade

**Category**: Feedback / Accessibility
**Used In**: HUD — all animated elements

**Description**: Every animated HUD element is classified in advance as either
**load-bearing** (the animation itself carries information the player needs —
degrade to a minimal functional form when reduced-motion is active, don't just
remove it) or **decorative** (pure polish — replace with a static fallback
when reduced-motion is active). This classification must happen at design
time, per element, not left for an implementer to guess at.

**Specification**:
- Every new HUD element's spec must state its reduced-motion classification
  explicitly.
- The combined-flash ceiling (above) still applies regardless of the
  reduced-motion flag — reduced motion lowers animation amplitude/frequency,
  it does not exempt a system from the flash-safety floor.

**When to Use**: Every animated HUD element.
**When NOT to Use**: N/A.

---

## Gaps & Patterns Needed

- **Menu/lobby navigation patterns** — this project has no lobby/loadout screen
  UX spec yet; once one is authored, its navigation patterns (button focus
  order, back-button behavior, confirm/cancel affordances) should be added here.
- **Modal/overlay pattern** (e.g., a confirmation dialog, a pause menu) — not
  yet needed by any authored GDD, but likely required once a pause/settings
  flow is designed.
- **Crafting bench interaction pattern** — Crafting & Items' own systems index
  entry flags `/ux-design crafting-bench` as a dependency before epic authoring;
  that spec should feed new patterns back into this library once written.
- **Cosmetic purchase/preview flow pattern** — ADR-0007 requires a full-rotation
  preview before purchase confirmation; no UX spec exists yet for this flow.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Should this library be revisited by a dedicated ux-designer pass once `design/ux/hud.md` and other screen specs exist, rather than staying derived from GDD prose? | producer | Before Production gate-check | Unresolved — recommended |
| Does the Hold-vs-Toggle pattern's "extend toggle-everywhere as an accessibility option" need its own ADR, or is it purely a client-controller implementation detail? | technical-director | During Foundation-layer implementation | Unresolved |
