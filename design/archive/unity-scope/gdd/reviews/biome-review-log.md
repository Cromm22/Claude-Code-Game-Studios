# Review Log: Biome System GDD

---

## Review — 2026-04-22 — Verdict: NEEDS REVISION → Revised in session

**Scope signal:** M
**Specialists:** game-designer, systems-designer, qa-lead, audio-director, creative-director (senior)
**Blocking items:** 15 | **Recommended:** 9
**Prior verdict resolved:** No — first review

**Summary:** The core biome design (two archetypes, static data records, linear interpolation for transitions) was sound. Blocking issues clustered around four unresolved decisions that the creative director identified as the load-bearing fixes: (1) the transition model (step function vs. interpolation from band entry), (2) authoritative value source for drain modifiers and band width, (3) state ownership for EC-2 directional traversal tracking, and (4) Player Fantasy overclaiming what the biome system delivers alone. All 15 blocking items were resolved in-session. Key structural changes: Rule 4 rewritten so modifiers interpolate from band entry (the band IS the ramp-up); transition_band_width_m canonicalized to 40m for both crossing directions; Resource Management named as owner of band_entry_biome state; Tuning Knobs corrected to match biome profile values; Acceptance Criteria rewritten to test biome records directly rather than routing through unimplemented consuming systems; 2 new regression guard ACs added (EC-2 reverse traversal, EC-8 intentional exploitation). Audio section updated to specify equal-power crossfade and MVP static-layer placeholder.
