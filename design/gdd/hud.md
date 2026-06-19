# HUD

> **Status**: In Design
> **Author**: chrusht + Claude Code (game-designer, ux-designer, ui-programmer, art-director, creative-director)
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 2 (The Squad Is the Experience) primary — coordination without voice; Pillar 1 (Quiet Is Power) — the disturbance bar is the proactive-quiet signal; Pillar 3 (The World Watches) — makes the world's reaction legible.

## Overview

The HUD is Terranova's player-facing **presentation layer**: a server-authoritative readout that subscribes to the gameplay systems' pushed signals — the squad's shared **oxygen** pool and **disturbance** level, each player's **stamina** and the **world-response cue**, the **predator's** lock and proximity, **resource-node** states and gather progress, and the **Beacon's** charge and survival-window countdown — and renders them so the squad can act on them. The player does not so much *use* the HUD as **read** it: it is almost entirely a non-interactive display driven by server pushes (≤ 5 Hz), and the few interactive surfaces it shows (the gather progress ring, the emote wheel) are owned and driven by the systems that raise them, not by the HUD itself. It exists because Terranova is a **voiceless co-op survival game** whose every decision — walk or sprint, lantern up or down, gather here or one zone over, hold the Beacon or run — is a trade between quiet and loud, and none of those trades are legible without a readout. The HUD is where the shared oxygen clock, the rising disturbance, the predator turning toward you, and the world's reaction become things the squad can *see* and coordinate around — its **shared nervous system**, the one surface through which Pillar 2 (coordination without voice), Pillar 1 (the disturbance bar as the proactive-quiet signal), and Pillar 3 (making the world's reaction legible) all reach the player.

## Player Fantasy

**The Shared Pulse.**

In a game where no one is assumed to be speaking, the HUD is the squad's **shared nervous system** — the one surface where you feel your teammates and the watching world at a glance, without a word. You don't operate it; you *read* it, the way you read your own breathing. The shared **oxygen** pool says it plainest: one bar, four people drawing on it, ticking down while you hide — you are spending the same breath, and you each know it without saying so. A teammate's **stamina** sliver creeping back up beside you is a held-still promise you can see. This is coordination as *feeling*, not chat.

And it is how you feel the world lean in. You rarely see the predator first — you feel it on the HUD. Someone breaks into a sprint to close a gap and you watch the **disturbance bar** climb; then the **world-response cue** pulses once, upward, a cold acknowledgment that the squad just got louder than it should have been. A half-second later the **predator-lock** indicator tightens at the edge of your eye: it's reading *you* now. Your stomach drops before anything has happened. This is *Alien: Isolation*'s motion-tracker register — a readout that raises your pulse precisely because it tells you something is wrong without showing you the thing.

The HUD never cries wolf, and it never tells you you're safe. The disturbance bar shows your standing, but its alarm only ever *rises* — quiet is a felt reward, never a green light to optimize toward (it is a feeling, not a meter to solve). Because the instrument stays calm and honest through the long quiet stretches — Beacon charge creeping up, disturbance low — you believe it instantly the moment it spikes, and you move. The trust it earns in the silence is what makes its alarm land.

**Anchor moment** — the 2–5 seconds this surface must deliver: crouched in the dark waiting out a patrol, you glance down — shared oxygen ticking, your teammate's stamina recovering beside you — and in the same glance the predator-lock indicator catches your eye: it's *you* it's reading now. The calm instrument you'd stopped consciously watching just spoke. You don't type, you don't ping; you both already know, and you move as one.

**Pillars served**
- **Pillar 2 — The Squad Is the Experience** (primary): the HUD is the shared nervous system that makes voiceless coordination and shared fragility *visible*.
- **Pillar 3 — The World Watches**: the HUD is the felt instrument of the world's attention; the predator-lock and world-response cue are how "the world watches" reaches the player.
- **Pillar 1 — Quiet Is Power**: the climbing disturbance bar makes loud play viscerally costly at a glance, and the one-directional world-response cue keeps quiet a felt reward, not a solvable meter.

**Reference grounding**: *Alien: Isolation* (the motion-tracker — dread from a readout that warns without revealing); *Subnautica* (a calm, diegetic instrument that earns trust through restraint, so its alarms are believed); *Doors* / *Apeirophobia* (Roblox co-op fragility — restraint over reflex, expressed through shared state).

**What the player should feel** — not in command of a dashboard, but plugged into a shared body they trust: calm until it isn't, and when it isn't, they move together without a word.

## Detailed Design

### Core Rules

[To be designed]

### States and Transitions

[To be designed]

### Interactions with Other Systems

[To be designed]

## Formulas

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
