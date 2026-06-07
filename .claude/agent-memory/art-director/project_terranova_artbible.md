---
name: Terranova Art Bible Authorship Status
description: Current lock status, open decisions, and key constraints for the Terranova art bible at design/art/art-bible.md
type: project
---

Sections 1–7 are authored. Section 8 (Asset Standards) and Section 9 (Reference Direction) are pending stubs.

**Why:** Art bible is the visual source of truth for the Terranova planetary survival game on Roblox. All asset, UI, and environment decisions defer to it.

**How to apply:** Before proposing any visual spec, read locked sections. Do not contradict locked decisions without explicit user sign-off.

## Key locked constraints (non-negotiable without user approval)

- Section 3.3: HUD is non-diegetic, equipment-register grammar, CornerRadius=0, Stroke-over-fill, one circle exception (emote wheel)
- Section 4.2: Predator amber `#E8871A` exclusion zone ±15° hue (18°–48°, S>50%) — forbidden on all non-predator assets including UI
- Section 4.5: Full UI palette locked (HUD stroke `#F0F0F0`, frame fill `#1A1E2B`, O2 teal→yellow→orange, disturbance cool-grey→violet `#6040E0`)
- Section 5.3: Squad colors outside predator exclusion zone, deuteranopia-safe — locked in Section 7.5

## Section 7 open decisions (awaiting user approval)

**Decision A**: Font — GothamMedium + RobotoMono (recommended) vs alternatives
**Decision B**: Ping marker screen-space (recommended) vs world-space
**Decision C**: Squad outline at 0–15 studs — opacity 0.7 fade (recommended) vs hard cutoff at 15 studs
**Decision D**: Citron P2 at hue 63° (15° from exclusion zone) vs shifting to 80° for more margin

## Squad color set (Section 7.5, locked pending Decision D)

| Slot | Name | Hex | Hue |
|---|---|---|---|
| P1 | Signal Blue | `#4090E0` | 210° |
| P2 | Citron | `#C8D040` | 63° |
| P3 | Lavender | `#9060D0` | 270° |
| P4 | Ice Teal | `#40D0C0` | 175° |
