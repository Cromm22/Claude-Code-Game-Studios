---
name: Terranova UX Context
description: Key UX/interaction constraints locked for Terranova as of art bible review — shapes work on /ux-design and future Section 7 collaboration
type: project
---

Terranova is a Roblox co-op survival/horror game (2-4 players, 5-20 min runs). Cross-platform: PC keyboard/mouse, mobile touch (iPhone SE-class is perf floor), console gamepad. All input methods must reach feature parity.

**Locked UX commitments (from art bible Sections 2-6):**
- HUD: non-diegetic, equipment-register visual language — hard rectangles (CornerRadius 0), stroke-over-fill, opaque white text #F0F0F0. Only circle in HUD is emote/signal wheel.
- Emote wheel: circular, up to 8 segments, confirmed input pattern: tap-to-open + drag-to-select + release (touch); hold-trigger + stick (gamepad).
- Touch safety: tap-hold or proximity-gate confirm for all disturbance-creating actions.
- Accessibility: all audio cues have visual redundancy; all color cues have shape/icon redundancy.
- Squad teammate outline: up to 4 cool-toned colors, 30-stud render distance, color-coded by squad.

**Pending UX decisions requiring user approval:**
- Gamepad button assignment for quick-ping (recommend L1/LB; must align with game-designer's input map).
- Reduced-motion Settings toggle (scope addition — strongly recommended but not yet confirmed in scope).

**Why:** Decisions affect Section 7 authoring scope and the full /ux-design pass that comes after.
**How to apply:** When authoring /ux-design specs for HUD, menus, or interaction patterns, treat these as locked constraints. Ping button and reduced-motion toggle need user approval before Section 7 finalizes.
