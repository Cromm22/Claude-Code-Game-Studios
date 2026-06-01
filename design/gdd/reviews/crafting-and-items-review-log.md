# Crafting & Items GDD — Review Log

Revision history for `design/gdd/crafting-and-items.md`. Each entry records the verdict, scope, specialists consulted, and a summary of load-bearing findings. Used by re-reviews to verify that prior blocking items were addressed.

---

## Review — 2026-05-01 — Verdict: MAJOR REVISION NEEDED

**Scope signal:** L (verging on XL — multi-system integration touching 4 not-yet-authored downstream GDDs, 7 formulas, 21 new constants, 3 ADRs flagged for architecture, 72 ACs, 25 visual moments)
**Specialists:** game-designer, systems-designer, economy-designer, qa-lead, network-programmer, ux-designer, creative-director (senior synthesis)
**Blocking items:** 24 | **Recommended:** ~20 | **Nice-to-have:** ~15
**Prior verdict resolved:** First review (no prior log)
**Review depth:** full (per `/design-review` default; `production/review-mode.txt` is `lean` but `--depth` is independent of project review mode)

### Summary

The 24 BLOCKING items collapse into six themes:

1. **Recipe catalog has dominated strategy.** Composite Patch is a net-negative trap recipe (flagged independently by game-designer and economy-designer — strongest convergence in the review). Quiet Step Wrap saves 0.05 emission once for 0.12+0.65 craft+gather cost. Beacon path dominates the full aid suite on cost-per-disturbance-unit AND wins the run; aid items are dominated strategy. This breaks Pillar 4 (no run-to-run variance) and weakens Pillar 2 (no coordination value in aid).

2. **Modifier-stacking order-of-operations is non-deterministic** (project-standard violation per `coding-standards.md` testing determinism rule). D.5 + E.15 contradict each other on Wrap behavior under grace-window + stationary. D.6 + H.38 Coil × stationary attenuation order is architecturally unspecified. D.7 midpulse attribution uses `crafters[1]` array index but BT4 may shift the array — silent wrong-attribution bug at runtime.

3. **Schema and state-machine defects.** CraftSession schema missing `benchPosition` field referenced by D.3 and D.7. E.18 "same emissionId" rationale is documentation-incorrect. Server crash mid-craft (BT1→BT3) has no documented expected behavior or AC. Late-join timing race (200 ms client lag at 5 Hz update rate) causes legitimate joins to fail with no HUD prompt suppression.

4. **Networking and exploits.** `RequestBeaconPlace` + `RequestPlaceItem` trust client-supplied position for raycast — should be a direction hint, not trusted coordinate (textbook exploit vector against `coding-standards.md` Forbidden Patterns rule). Rate-limit burst math self-contradictory ("2 per 3s" + "1/s base" produces 0.67/s effective ceiling that breaks legitimate retry-after-rejection patterns). Luau single-threaded race-prevention guarantee is yield-contingent with no AC verifying zero-yield in handlers. CRAFTING_GLOBAL_RATE_LIMIT = 8/s is reachable by a single legitimate motivated player.

5. **UX/accessibility on the primary platform.** 7-row recipe panel scrolling on iPhone SE extends bench dwell on the platform's primary device — pillar collision: Section B's "exposure not refuge" undermined by UX on the most-played device. Beacon activation single-commit has no friction model (highest-stakes interaction in the game with no proposed safeguard against accidental activation). VA.3 Moments 13 (Beacon activation) and 17 (Wrap-modified Sprint pulse) are audio-only with no visual fallback.

6. **Bench cap pillar collision in 2-player squads.** BENCH_MAX_CRAFTERS = 2 creates a degenerate "nobody watches" state in 2-player squads (a supported configuration). Salvageable: scale cap with squad size, e.g., `min(2, ceil(squad_size / 2))`.

### Senior Verdict (creative-director)

> Section B player-fantasy is genuinely the strongest articulation in the project. **But Sections C–H partially betray it.** Composite Patch and Wrap teach players that crafting is a trap (anti-Pillar 1). Beacon dominance means there's only one question worth asking every run (anti-Pillar 4). iPhone SE friction means the bench is "where you choose what to fear AND fight a UI for 8 extra seconds" (pillar collision). Order-of-operations ambiguity means players cannot build accurate emission mental models (anti-Pillar 1).
>
> Structural document quality is high — best-organized GDD in the project. The revision is targeted, not foundational. Suggested round-2 sequence: (1) cut Composite Patch + Wrap; (2) declare canonical emission-modifier order-of-operations; (3) address Beacon dominance via cost rebalance OR multi-recipe finale restructure; (4) tune BENCH_MAX_CRAFTERS to scale with squad size; (5) sweep qa-lead AC rewrites and missing edge cases.
>
> The load-bearing question for round-2: **is the Beacon meant to dominate as a "you've earned the win" payoff, or meant to be one option among several?** Different revision paths follow.

### Specialist Convergences

- **Composite Patch** flagged independently by game-designer (fantasy lens) AND economy-designer (math lens) — crossing-of-lenses is the most reliable signal in this review.
- **Modifier order-of-operations** flagged from four angles: systems-designer #1 (Wrap contradiction), systems-designer #2 (Coil ordering), qa-lead missing AC for E.15, network-programmer "yield-contingent" race concern. All four resolve with one architectural decision.
- **Wrap × grace window** flagged by systems-designer (logic contradiction) and qa-lead (missing AC) — same defect from two angles.

### Specialist Disagreements

- **Squad Relay 0.20 burst tier** — game-designer says cut to MID 0.18 (unjustified by current design); economy-designer says cost/value undefined until Resource Management GDD lands. Both correct in different frames; not a true disagreement. Defer to next pass after RM GDD exists.

### Recommended Round-2 Sequence

1. Cut Composite Patch and Quiet Step Wrap from recipe catalog. Reconsider whether their slots return as redesigned items or are retired entirely.
2. Resolve the load-bearing Beacon-dominance question (creative-director's flag): is Beacon meant to dominate as "you earned the win," or be one option among several? Different revision paths follow.
3. Declare canonical emission-modifier order-of-operations (one decision, four BLOCKING items resolve at once: B5, B6, B7, and qa-lead's missing E.15 AC).
4. Add `benchPosition` and `primaryCrafterId` fields to CraftSession schema; document server-crash and server-migration cleanup paths.
5. Fix `RequestBeaconPlace` / `RequestPlaceItem` to treat client position as direction hint; bound raycast origin by server-tracked player position.
6. Tune BENCH_MAX_CRAFTERS to scale with squad size (recommend `min(2, ceil(squad_size / 2))`).
7. Resolve UX BLOCKING: iPhone SE recipe panel layout budget, Beacon activation friction model, Moments 13/17 visual fallback.
8. Sweep qa-lead AC rewrites (H.27 determinism, H.61 tick-count window, H.63/H.64 reclassification) and add 5 missing edge-case ACs (E.2, E.4, E.11, E.15, E.19) plus startup-invariant AC.
9. Add Visual/Audio and UI ACs to Section H (currently zero ACs cover those sections).
10. Fix mechanical hygiene: rate-limit burst math (B12), `OnSignalAnchorTripped` payload mismatch, `QUIET_STEP_WRAP_REDUCTION` upper-bound disagreement (D.5: 0.60 vs G.5/registry: 0.70), other Recommended items.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (1608 lines, status: NEEDS REVISION)
- Upstream: `design/gdd/player-controller.md` (Designed pending review), `design/gdd/ecological-disturbance.md` (round-5 done, awaiting round-6 re-review)
- Cross-cited: `design/gdd/game-concept.md`, `design/gdd/systems-index.md`, `design/registry/entities.yaml`
- Standards: `.claude/docs/coding-standards.md`, `.claude/docs/technical-preferences.md`

---

## Round-2 Patch Applied — 2026-05-30 (Phase A) + 2026-06-01 (Phase B) — NOT YET RE-REVIEWED

**This is a patch record, not a review verdict.** The round-2 patch resolves the 2026-05-01 MAJOR REVISION NEEDED verdict (24 BLOCKING / 6 themes). A real round-2 `/design-review` against the patched document is the **next step** — do not treat this entry as an APPROVED verdict.

**Design direction:** locked via brainstorm (2026-05-30). Spec: `design/gdd/reviews/crafting-and-items-round2-patch-plan.md`.
**Execution:** split across two sessions — Phase A (design-substance, 2026-05-30) + Phase B (hygiene sweep, 2026-06-01).
**Keystone decision:** the Beacon is the **sole** win condition, but **activation no longer wins instantly** — it opens a **survival window** (`BEACON_SURVIVAL_WINDOW ≈ 49 s`, ED-derived). Victory fires only on surviving it (≥1 alive at window-end → `OnBeaconWindowSurvived` → PC T8); a full-squad wipe during the window is defeat. This is what makes the aid suite load-bearing and kills the round-1 Beacon-rush dominance.

### Resolution by round-1 theme

| # | Round-1 theme (BLOCKING) | Round-2 resolution |
|---|---|---|
| 1 | Recipe catalog dominated strategy (Patch trap, Beacon dominance) | Cut Composite Patch + Quiet Step Wrap → 5-recipe catalog; survival window makes the 4 aid items necessary (C.2, C.5.6a) |
| 2 | Modifier order-of-operations non-deterministic (4 angles) | Cut collapses modifiers to one (Dampener Coil); single canonical 2-stage chain declared (D.6a) |
| 3 | Schema + state-machine defects (benchPosition, primaryCrafterId, crash path) | Added both `CraftSession` fields + server-crash cleanup doc + AC (C.10, H.74, H.79); BT3/D.7 repointed to `primaryCrafterId` (B7) |
| 4 | Networking + exploits (client-position trust, rate-limit math, zero-yield) | Client position now a clamped direction hint (B13, H.75); rate-limit burst ≥ sustained, `1/s + burst 3/3 s` (B12); zero-yield-in-handler AC (B14, H.80); global-limit reachability reassessed (B15) |
| 5 | UX/accessibility (iPhone SE panel, Beacon friction, visual fallback) | Panel now 5 rows (fits iPhone SE without scroll — UI.4); survival-window countdown is the on-screen visual fallback for the former audio-only Moment 13 (Moments 26/27, UI.1 surface 13) |
| 6 | Bench cap pillar collision in 2-player squads | Squad-scaled effective cap `min(BENCH_MAX_CRAFTERS, ceil(squadSize/2))` (B19 → C.3.5, D.2) |

### Phase B hygiene sweep (2026-06-01) — what changed

- **Cut-item sweep**: removed/retired all Composite Patch + Quiet Step Wrap residue — E.14/E.15 (edge cases), H.18/H.19/H.20/H.34/H.35/H.36/H.59 (ACs), Moments 16/17 (VA), `MAGNITUDE_CRAFT_LIGHT` + `QUIET_STEP_WRAP_REDUCTION` (G.4/G.5 + registry), `compositePatchDowngrade`/`quietStepWrapReduction` (registry formulas), Patch/Wrap UI surfaces + badges + OQ.1. Retired numbers stubbed in place (not reused), matching the D.4/D.5 precedent.
- **Survival-window additions**: edge cases E.24 (full-wipe defeat), E.25 (window tie-break), E.26 (decay ordering); ACs H.73 (window victory), H.76 (defeat), H.77 (tie-break), H.78 (fires-once); VA Moments 26 (countdown) + 27 (victory); UI surface 13 (countdown).
- **BCT renumber**: decay transition BCT4 → BCT5 (E.8, H.16, VA Moment 14); new BCT4 = window-survival victory; BCT-DEFEAT = full-wipe.
- **Schema/net ACs**: H.74 (crash), H.75 (position clamp), H.79 (schema fields), H.80 (zero-yield).
- **Counts reconciled**: recipes 7→5, item types 7→5, edge cases (24 live, through E.26), ACs (73 live, through H.80), VA moments (25 live, 1–27 with 16/17 retired + 26/27 added).
- **Registry**: `design/registry/entities.yaml` — deleted 2 constants + 2 formulas, fixed recipe-number + type-count notes, repointed attribution to `primaryCrafterId`/`benchPosition`, squad-scaled the dwell-rate formula.

### Cross-GDD forward obligations created (must be honored when those GDDs revise)

- **Player Controller** (in MAJOR REVISION round-6): T8 now subscribes to `OnBeaconWindowSurvived` (window-end), NOT activation; PC keeps inputs/state active through the ~49 s window. Fold into PC's revision (F.4 / F.6).
- **Ecological Disturbance**: `BEACON_SURVIVAL_WINDOW` length is ED-owned (derived from `MAGNITUDE_BEACON`/`BEACON_HALF_LIFE`/`HUNT_THRESHOLD` per ED.D.7); ED's beacon section may want a reverse-cite that the lure window now gates victory. Confirm ED.D.7 defines it when ED resumes.
- **Resource Node**: Composite Patch ↔ RN `GetEquippedEffect` interaction removed — RN contract simplifies (no gather-downgrade read).
- **HUD**: new `OnBeaconActivated` (window-start) + `OnBeaconWindowSurvived` (victory) + survival-window countdown surface; Patch/Wrap badges removed.

### Not done (intentional)

- **No git commit** (per CLAUDE.md — awaiting user instruction).
- **No round-2 `/design-review` yet** — the patched doc must be re-reviewed (full depth) before the round-2 verdict is recorded. The cross-cut still binding: ED's F.6 Crafting-`MAX_BEACON` mandate (runtime `MAX_ACTIVE_BEACONS = 3` cap with reject-at-publish-site) — fold into the next revision pass.

---
