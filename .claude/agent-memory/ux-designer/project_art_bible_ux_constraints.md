---
name: Art Bible UX Gate Check Results
description: Constraints and flags produced by UX alignment review of art bible (pre-Section 7) on 2026-04-29 — use to inform Section 7 authoring and full /ux-design pass
type: project
---

UX gate check run against art bible Sections 2-6 before Section 7 (UI/HUD Visual Direction) was authored. Section 7 must incorporate these constraints.

**Hard constraints (no approval needed — accessibility baselines):**
1. All interactive Frames >= 44x44pt touch target; UIStroke is cosmetic only, does not define hit area.
2. Hold-confirm progress indicator must be a linear rectangular fill bar — radial fills are circles, prohibited by Section 3.3's single-circle rule (emote wheel only).
3. Spike alert must NOT use full-screen flash; use screen-edge vignette pulse (0.8-1.2s, 1 cycle max per event) consistent with death screen vignette implementation path.
4. Death screen text must have opaque backing Panel (#1A1E2B, 80-90% opacity) to guarantee 4.5:1 WCAG AA contrast at Hunt state + partial desaturation on mobile.
5. Squad outline system needs: (a) 30deg+ hue angle AND 0.15+ luminance separation between all 4 squad colors, (b) a white shape symbol on each outline as color-redundant backup signal.
6. Emote wheel minimum 120pt diameter for 8 segments; must include center cancel zone.

**Scope flags (require user approval):**
- Gamepad ping button assignment: recommend L1/LB, but must align with game-designer's input map. Two-finger tap confirmed for touch; G key/middle-mouse for KB+M.
- Reduced Motion Settings toggle: scope addition. Per-animation fallback states needed in Section 7 if approved. Flora pulse: reduce amplitude not disable. Lantern flicker: replace with static dim. Vignette alert: replace with 2s static tint.

**Why:** All constraints derive from WCAG 2.3.1, WCAG AA contrast, Apple HIG 44pt minimum, and the art bible's own stated accessibility commitments (color cues have shape redundancy; audio cues have visual redundancy).
**How to apply:** Treat hard constraints as blocking requirements when reviewing Section 7 drafts. Surface scope flags to user before Section 7 is written.
