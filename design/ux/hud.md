# HUD Design

> **Status**: In Design (first draft — authored during Pre-Production to close a
> carried `/gate-check` obligation, translating the mechanics already frozen in
> `design/gdd/hud.md` into a screen/UX-layer spec)
> **Author**: producer + gameplay-programmer (standing in for an unstaffed ux-designer role)
> **Last Updated**: 2026-07-06
> **Template**: HUD Design

> **Relationship to `design/gdd/hud.md`**: That document is the mechanics GDD —
> it defines signal contracts, arbitration rules, and formulas (CR.1–CR.9, D.1–D.7,
> H.1–H.28). This document is the presentation-layer translation: what the player
> actually sees, where, and how it behaves — cross-referenced against `design/ux/interaction-patterns.md`
> for the patterns it reuses (Color-Independent Status Readout, Bearing + Distance-Band
> Indicator, Rate-Limited Push Signal, Combined-Flash Ceiling, Server-Clock-Derived
> Countdown, Reduced-Motion Degrade). Where this spec and the GDD ever conflict,
> the GDD's mechanics win — this document should be corrected, not the other way.

---

## HUD Philosophy

**"Minimal but present — only decision-relevant information visible; everything
else is read from the world itself."** Terranova's core fantasy depends on players
reading the *world* (bioluminescent saturation, predator eye-shine, the dark/light
boundary) as much as the HUD — the art bible's Visual Identity Anchor ("the player
should always know where safety ends") is explicitly a world-legibility rule, not
a HUD rule. The HUD's job is to carry the handful of things the world genuinely
cannot communicate on its own (exact oxygen value, exact disturbance tier, squad
roster liveness, precise beacon-window countdown) — not to duplicate what the
environment already tells the player. This directly matches HUD's own GDD framing
(a "pure-subscriber consumer" that owns no balance values and adds no new gameplay
information beyond what producers already compute).

---

## Information Architecture

### Full Information Inventory

Pulled from every MVP GDD's cross-references into HUD (per the traceability work
done in this session's `/architecture-review`):

- Disturbance tier / meter value (Ecological Disturbance)
- Disturbance tier-crossing alert + death-attribution cause (Ecological Disturbance)
- Oxygen pool value + drain rate + state (Healthy/Critical/Empty) (Resource Management)
- Predator bearing + distance band + lock status (YOU-locked / squad-locked / patrol) (Predator AI)
- Squad roster + liveness (alive/dead/respawning per member) (Player Controller)
- Own stamina (Player Controller)
- Own lantern state (raised/lowered) (Player Controller)
- Gather prompt + progress ring + reject reason (Resource Node)
- Node state (armed/disarmed/depleted/respawning) at nearby nodes (Resource Node)
- Beacon charge tier (BC1–BC4) + survival-window countdown (Crafting & Items)
- Craft progress / bench proximity prompt (Crafting & Items)
- Death/respawn countdown + dead/spectating state (Player Controller, RunController)
- Victory/defeat banner (RunController)
- Ping markers (own + squad) (Player Controller)
- Emote wheel (Player Controller)

### Categorization

| Category | Items |
|----------|-------|
| **Must Show** (always visible during a live run) | Own stamina, own oxygen contribution/state, disturbance meter, squad roster liveness |
| **Contextual** (visible only when relevant) | Predator bearing/distance chevron (only while a lock is active or predator is sensed within range), gather prompt/ring (only near an armed node), craft/bench prompt (only near a bench), beacon charge tier + survival countdown (only after beacon activation), node state overlays (only for nodes in perception range) |
| **On Demand** (player actively requests) | Emote wheel, ping placement, full squad-status panel (if one exists beyond the always-visible roster strip) |
| **Hidden** (communicated through the world, never HUD text) | Bioluminescence saturation as disturbance texture, predator silhouette/scale at first sighting, dark-zone boundary itself |

This split matches the "world reads at rest, HUD reads under pressure" philosophy:
the Must Show list is short (4 items) precisely because the world is doing most of
the ambient communication, and the HUD steps in for exact values and squad-wide
state the world can't show.

---

## Layout Zones

Given the philosophy (minimal but present) and mobile-first constraints (iPhone
SE-class floor, `technical-preferences.md`), the HUD uses a four-zone layout that
keeps the center of the screen almost entirely clear for world-reading:

```
+--------------------------------------------------+
| [Squad Roster strip]              [Disturbance    |
|  (top-left, always visible)        meter] (top-   |
|                                     right, always) |
|                                                    |
|                    (clear center —                |
|                     world-reading space,           |
|                     predator chevron floats         |
|                     here contextually)             |
|                                                    |
| [Stamina/Oxygen]                  [Contextual      |
|  (bottom-left, always)             prompts: gather/|
|                                     craft/beacon]   |
|                                     (bottom-right,  |
|                                      contextual)    |
+--------------------------------------------------+
```

- **Top-left — Squad Roster strip**: compact per-member liveness icons (Must Show).
- **Top-right — Disturbance meter**: bar/tier readout (Must Show).
- **Center (contextual only)**: predator bearing chevron, only rendered when a
  lock/sense event is active — this is the one HUD element allowed inside the
  "clear center" zone, since predator proximity is the single most decision-critical
  piece of contextual information in the game.
- **Bottom-left — Stamina + Oxygen**: own-player vitals (Must Show).
- **Bottom-right — Contextual action prompts**: gather ring, craft/bench prompt,
  beacon charge tier + countdown — only one of these is typically active at a time
  given the game's phase structure (gather vs. craft vs. beacon-hold), so they can
  share the same screen real estate without collision.

---

## HUD Elements

| Element | Category | Content | Visual Form | Update Behavior | Trigger | Animation |
|---|---|---|---|---|---|---|
| Squad Roster strip | Must Show | Per-member alive/dead/respawning icon | Row of 2–4 small avatar/icons | Event-driven (`OnSquadMemberAliveChanged`, `OnPlayerDied`) | Always visible in a live run | Icon state-change flash (routed through `FlashArbiter`, ≤3/sec combined ceiling) |
| Disturbance meter | Must Show | Current tier (Calm/Tense/Hunt) + underlying value | Horizontal bar with tier-color fill + pip markers per tier + numeric readout | Rate-limited push (`OnMeterUpdate`, ~5Hz) with client-side tween (0.25s ease, per HUD's own D-series interpolation rule) | Always visible | Cancel-restart tween on each push; tier-crossing triggers a `FlashArbiter`-routed alert cue |
| Predator bearing chevron | Contextual | Bearing (screen-space direction) + distance band (FAR/NEAR/CONTACT) | Chevron pointing toward predator, opacity/pulse-rate scaling with distance band | Per-client targeted push (`OnPredatorSense`, 10–20Hz accumulated-time rate-gate) | Rendered only while a sense/lock event is active | Signed-shortest-arc lerp + snap threshold (per HUD's D.3); eye-shine overlay added at CONTACT band only |
| Stamina bar | Must Show | Own stamina 0–100 | Vertical or horizontal bar, non-color-coded shape distinct from oxygen | Rate-limited push (`OnStaminaChanged`, ≤5Hz) | Always visible | Low-stamina state gets a distinct icon change, not color alone (per Color-Independent Status Readout pattern) |
| Oxygen readout | Must Show | Squad oxygen pool value + drain rate + state (Healthy/Critical/Empty) | Bar/numeric combo, state icon distinct per state | Dead-reckoned client-side between rate-limited pushes (`OnOxygenChanged` ≥2Hz + transition events), per the Rate-Limited Push Signal pattern | Always visible | Empty-state transition is a `FlashArbiter`-routed alert, not a raw color flash |
| Gather prompt + ring | Contextual | Gather availability + hold-progress ring | Radial fill ring (the one client-predicted UI element in this game, per the Tap-Hold Commit pattern) around a prompt icon | Local input-driven fill; server-confirmed commit via `RequestGather` | Rendered only near an armed, in-range node | Ring resets visibly on server rejection (Silent-Drop Rejection pattern) |
| Node state overlay | Contextual | Nearby node armed/disarmed/depleted/respawning | Small icon per visible node | Event-driven (`OnNodeStateChanged`) + full snapshot on join (`OnNodeFullStateSnapshot`) | Rendered for nodes within perception range | State-change icon swap, no continuous animation |
| Craft/bench prompt | Contextual | Bench proximity + craft progress | Prompt icon + progress bar when crafting is active | Rate-limited push (`OnCraftProgressUpdate`, ≤5Hz) | Rendered only near a bench | — |
| Beacon charge tier + countdown | Contextual | BC1–BC4 tier + survival-window remaining time | Tier icon/label (non-color-coded backup per Color-Independent Status Readout) + server-clock-derived countdown | Event-driven tier changes + per-frame local countdown recompute (Server-Clock-Derived Countdown pattern) | Rendered only once a beacon is activated | Tier-change flash routed through `FlashArbiter` |
| Death/respawn overlay | Contextual (full-screen when active) | Respawn countdown (`RESPAWN_DELAY=30s`), dead/spectating state | Full-screen dim + countdown text | Server-clock-derived countdown from the death event's server timestamp | Rendered only while the local player is in T5 (Dead-Respawning) | Fade-in/out; no flash |
| Victory/defeat banner | Contextual (once per run, terminal) | Run outcome | Full-screen banner | Single authoritative event (`RunEnded(outcome)`) — no provisional banner shown during any defeat-hold window | Rendered exactly once, at `RunEnded` | Fade-in, holds until player action or scene transition |
| Ping markers | On Demand | Player-placed ping location | World-space marker + screen-edge indicator if off-screen | Player-triggered (`RequestPing`), server-confirmed | Rendered on request, times out after a fixed duration | Pop-in, fade-out on expiry |
| Emote wheel | On Demand | 4–6 emote slots | Radial menu | Player-triggered (hold to open) | Rendered only while the input is held | Radial expand/collapse |

---

## Dynamic Behaviors

- **Contextual prompt collision avoidance**: gather, craft/bench, and beacon
  countdown all share the bottom-right zone but are mutually exclusive in
  practice given the game's phase structure (a player is rarely simultaneously
  in gather range, bench range, and holding an activated beacon) — if a future
  playtest finds an overlap case, the priority order (highest first) should be:
  beacon countdown > craft progress > gather prompt, since the beacon window is
  the most time-critical.
- **Alert-channel precedence**: per HUD's own CR.4, higher-priority alerts
  (disturbance tier-crossing, oxygen state-change) preempt lower-priority ones;
  equal-priority alerts FIFO-queue rather than overlap.
- **Combined-flash ceiling governs all of the above**: regardless of how many
  systems want to flash simultaneously (disturbance tier-cross + oxygen
  critical + node completion), the `FlashArbiter` module caps the *combined*
  onset rate at ≤3/sec — this is a HUD-wide constraint, not per-element.

---

## Platform & Input Variants

- **Mobile (iPhone SE floor)**: all Must Show elements must remain legible at
  the smallest supported screen; contextual prompts use 44pt-minimum touch
  targets per the Cross-Input Action Parity pattern.
- **Console/gamepad**: no hover-dependent affordances (none exist in this
  design, consistent with the forbidden-pattern list); prompt icons show the
  active gamepad button glyph dynamically if the input method switches mid-session.
- **Aspect ratio**: root `UIScale` + `UIAspectRatioConstraint`, per
  `technical-preferences.md`; ultrawide gets a bar-width cap so the disturbance
  meter and oxygen bar don't stretch to an unreadable width.

---

## Accessibility

Cross-referenced against `design/ux/accessibility-requirements.md` (Standard tier):

- Every color-coded element above (disturbance meter, oxygen state, node
  overlay, beacon tier) has a stated non-color backup — see the Per-Feature
  Accessibility Matrix's HUD row and the Color-Independent Status Readout
  pattern.
- The combined-flash ceiling directly implements the accessibility doc's WCAG
  2.3.1 commitment.
- Every animated element above should be classified load-bearing vs. decorative
  per the Reduced-Motion Degrade pattern — this spec has not yet assigned that
  classification per-element (see Open Questions).
- Text size/contrast minimums (accessibility doc's Visual Accessibility table)
  apply to all numeric readouts and banner text above.

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|-----------|
| Per-element reduced-motion classification (load-bearing vs. decorative) has not been assigned for every element in the table above — needed before implementation | ui-programmer | Before HUD implementation begins | Unresolved |
| The bottom-right contextual-prompt collision priority order (beacon > craft > gather) is this session's best guess, not a playtested decision | game-designer | First vertical-slice playtest | Unresolved — flagged as a playtest validation item |
| CR.8 figure/ground arbitration (how the chevron/eye-shine visually compete with world elements at the dark/light boundary) is referenced by the GDD but not fully translated into this layout spec | ui-programmer + art-director | Before HUD implementation | Unresolved — carried from the HUD GDD's own open items (round-2 gate) |
| This spec has not been run through `/ux-review` — the Pre-Production gate expects at minimum a review verdict, not just an authored spec | producer | Before declaring HUD "implementation-ready" | Unresolved — recommended next step |
