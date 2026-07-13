---
name: Terranova Art Bible Authorship Status
description: Current lock status, open decisions, and key constraints for the Terranova art bible at design/art/art-bible.md
type: project
---

**Status as of 2026-07-06 (AD-PHASE-GATE review, Systems Design -> Technical Setup):** All 9 sections fully authored (Visual Identity Anchor + 1 Identity Statement, 2 Mood/Atmosphere, 3 Shape Language, 4 Color System, 5 Character Design, 6 Environment Design Language, 7 UI/HUD Visual Direction, 8 Asset Standards incl. §8.11 perf QA gates, 9 Reference Direction). All Section 7.9 "Locked Decisions" (A-F) are resolved. File header metadata still says "Status: Draft — authoring in progress" — this is stale/cosmetic and should be updated to reflect completion, but content itself is production-ready.

**Why:** Art bible is the visual source of truth for the Terranova co-op Roblox survival/horror game. All 7 MVP GDDs cite it directly (Visual/Audio Requirements sections) and defer per-asset generation to `/asset-spec` post-approval. Cross-checked citations §4.3 (bioluminescent tier table), §6.5 (MAX_FLORA_PER_CHUNK=8), §8.11 (Test 1 perf conditions) all verified present and accurate against ecological-disturbance.md's citations (2026-07-06 gate review).

**How to apply:** Before proposing any visual spec, read locked sections. Do not contradict locked decisions without explicit user sign-off. Treat the bible as read-only reference at this point — it is not mid-authoring.

## OPEN — HUD GDD OQ.6: predator-hue exclusion contradiction (needs AD ruling)

`design/gdd/hud.md` VA.3 (Reserved-hue compliance) did the HSV math on the bible's own locked §4.5 UI palette values and found the bible's own justification text is wrong:

- **Oxygen warning color `#FFD060`** (art-bible §4.5): bible text claims hue ~50° ("outside" the 18°-48° exclusion band) and calls it "desaturated." Actual math: hue ≈ 42° (INSIDE the band) at S ≈ 62% (ABOVE the S>50% gate). It does NOT clear the §4.2 predator-hue exclusion by either axis. HUD proposes it survives only via the §4.5 "disambiguation triad" (lighter value + fixed meter position + it's a meter not a peripheral alarm) — but this needs an explicit AD affirmation, not just HUD's own say-so.
- **CONTACT warm-cream `#FFF0C8`** (HUD-proposed, not yet bible-locked): hue ≈43.6° inside band, S≈22% (passes only by the saturation gate) — HUD demoted this to an optional enhancement that does not ship without AD sign-off; the locked primary CONTACT treatment (pure UIStroke escalation) has zero hue risk and needs no sign-off.

This is logged as **OQ.6** in `hud.md` (owner: art-director, target: "art-bible approval / asset-spec pass") and is **still fully open** — no waiver has been logged in `assets/art/reference/asset-decisions.md` (that file does not exist yet), and the art bible §4.5 text has not been corrected.

**Why this matters:** art-bible §8.3/§8.5 specify an automated HSV gate script (delegated to gameplay-programmer) that auto-fails any Color3 in the 18°-48°/S>50% band. If built literally against §4.2's stated rule with no exception list, it will flag the game's own oxygen-warning meter — a color the bible itself locked. Must be resolved (AD ruling + art-bible §4.5 text fix + asset-decisions.md waiver entry, or a refined gate that special-cases meter-context colors) before that CI hook/ADR is authored, or the validation tooling will need rework.

**How to apply:** When next asked to rule on OQ.6, or when reviewing/authoring the predator-hue-exclusion ADR or the HSV gate script spec: affirm or reject the disambiguation-triad argument for `#FFD060` explicitly, correct the art-bible §4.5 prose (hue/saturation numbers are wrong), and record the ruling in `assets/art/reference/asset-decisions.md` (create the file — it's referenced by the bible but doesn't exist).

## Squad color set (Section 7.5, locked)

| Slot | Name | Hex | Hue |
|---|---|---|---|
| P1 | Signal Blue | `#4090E0` | 210° |
| P2 | Citron | `#C8D040` | 63° |
| P3 | Lavender | `#9060D0` | 270° |
| P4 | Ice Teal | `#40D0C0` | 175° |

## Key locked constraints (non-negotiable without user approval)

- Section 3.3: HUD is non-diegetic, equipment-register grammar, CornerRadius=0, Stroke-over-fill, one circle exception (emote wheel)
- Section 4.2: Predator amber `#E8871A` exclusion zone ±15° hue (18°–48°, S>50%) — forbidden on all non-predator assets including UI (see OQ.6 above for a live edge case)
- Section 4.5: Full UI palette locked (HUD stroke `#F0F0F0`, frame fill `#1A1E2B`, O2 teal→yellow→orange, disturbance cool-grey→violet `#6040E0`)
- Section 5.3 / 7.5: Squad colors outside predator exclusion zone, deuteranopia-safe — locked
- Section 6.2: Three-material vocabulary only (Geological: Slate/Sand/Grass; Fabricated: SmoothPlastic; Emissive: Neon flora tips) — no SurfaceAppearance/MaterialVariant in MVP
- Section 8.11: Blocking perf QA gates (4 tests) required before ship, owned jointly by technical-artist (run) + art-director (visual-quality sign-off) + lead-programmer
