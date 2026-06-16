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

## Review — 2026-06-01 — Verdict: MAJOR REVISION NEEDED (round-2 re-review)

**Scope signal:** L (verging XL — 5+ dependencies, two unwritten sibling GDDs the thesis now depends on, a cross-doc conflict, multiple new ADR obligations)
**Specialists:** game-designer, systems-designer, economy-designer, ux-designer, network-programmer, qa-lead, creative-director (senior synthesis)
**Review depth:** full (7 adversarial specialist agents + senior synthesis)
**Prior verdict resolved:** Partially — round-1 themes 2 (order-of-ops) & 6 (bench cap) RESOLVED; themes 1/3/4/5 PARTIAL.

### Summary

Senior verdict (creative-director): **sound thesis, unfinished patch.** The survival-window redesign is the correct structural fix for round-1's press-button-win dominance and serves the pillars — keep it. But the blocking cluster is dominated by an **incomplete reconciliation sweep** (the patch reached the normative surfaces but missed the prose, the copy-paste template, a state-machine `From` field, and the upstream parent doc) plus **specification gaps** that hand the load-bearing "aid items are necessary" claim to two GDDs that don't exist yet (Predator AI, Resource Management). The specialists individually leaned NEEDS REVISION; the CD escalated to MAJOR REVISION NEEDED on the verified keystone contradiction + the unupdated authoritative parent + the blocking-cluster volume.

### Blocking items — Group A (reconciliation-sweep misses) — **FIXED this session (2026-06-01)**

- **A1** [VERIFIED] E.9 edge-case body still fired `T8` + "run ends in victory" at activation (the pre-round-2 keystone). → rewritten to window-survival semantics, consistent with H.44.
- **A2** [VERIFIED] C.11.3 (normative publisher contract) + H.39 still used `sourcePlayerId=crafters[1]` for the midpulse (round-1 B7 bug). → repointed to `CraftSession.primaryCrafterId`.
- **A3** [VERIFIED] C.9 BCT5 `From` field listed "BC4 or BC5" (BC5 is terminal-victory). → corrected to `From: BC4` only.
- **A4** [BLOCKING cross-doc] `game-concept.md` lines 270/317 ("victory state on activation") contradicted the window model. → updated game-concept to the survival-window win condition.
- **R1/R2** [VERIFIED RECOMMENDED] registry `dampenerCoilReduction` formula `× DAMPENER_REDUCTION` (diverged from GDD `× (1 − DAMPENER_REDUCTION)` at non-default tunings; output_range `[0.04]`) → fixed to `× (1 − DAMPENER_REDUCTION)`, range `[0.024, 0.056]`; H.67 craft-time list (7 values) → 5.
- *(Dismissed: qa-lead's "AC count 72 not 73" — re-verified 73 live is correct: 72 original − 7 retired + 8 added, numbered through H.80.)*

### Blocking items — Group B (design decisions) — **PENDING (next session)**

- **B1** Victory-proximity rule undefined (BCT4 "≥1 alive *anywhere*") — must state the proximity stance; "activate-and-scatter" otherwise trivializes the window. *(CD ruling: the under-specified condition is BLOCKING; the balance exploit is RECOMMENDED-pending-PA-GDD.)*
- **B2** Aid-suite-necessity unsubstantiated — add F.4 forward obligations: min predator aggression during BC4, min oxygen drain, provisional oxygen-transfer values for Canister/Relay. (game-designer + economy-designer convergence; Canister-stack-and-bunker is the likely new dominant line.)
- **B3** BCT-DEFEAT leans on PC's unverified all-dead `RunEnded(defeat)` path (PC in MAJOR REVISION) — add a cross-GDD lock; mark H.76 integration/unverified-until-PC.
- **B4** Cross-wall placement exploit — clamp + downward-raycast still allows placing a beacon/anchor through a wall into an unreachable room; add a server-side reachability raycast + AC.
- **B5** Pin the survival-window timer to `RunService.Heartbeat` (not `task.delay`) or the E.25/H.77 tie-break determinism breaks.
- **B6** Beacon activation friction (round-1 B19) still open — lock a design decision (single-tap / tap-hold / two-tap) + acknowledge irreversible placement.
- **B7** H.80 zero-yield AC covers only 3 of 8 state-mutating handlers (double-consume race on UseItem/EquipItem) — extend to all eight.
- **B8** Round-1 carryover H.27 (determinism tolerance) + H.61 (tick-window boundary) still unresolved — dt-injection rewrites.
- **B9** H.74 (server-crash) + H.77 (tie-break) not deterministically reproducible as written — specify the test-harness injection mechanism.

### Recommended (deferred to Group-B session)

Registry `BEACON_HALF_LIFE` cross-GDD lock (safe window range ⇒ ~[64,128] s vs. registry [45,180]); `OnSignalAnchorTripped` payload `anchorPosition` vs `predatorPosition`; RELAY tier (0.20) sub-floor vs MID (0.18) — consider merging; Canister stack-cap + dead-player-lock-in-window analysis; ux (countdown ring vs art-bible single-circle, reduced-motion, BC4 HUD-density audit, Coil-badge color-only warning); H.63→P1, H.64 annotation, H.80 lint-enforcement, rate-limit algorithm; solo-play (squad=1) supported?; E.26 covering AC.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-2 patched + Group-A reconciled)
- Parent updated: `design/gdd/game-concept.md` (win-condition reconciled to the window model)
- Registry: `design/registry/entities.yaml` (Coil formula corrected)
- Cross-cited: `design/gdd/player-controller.md` (round-6 MAJOR REVISION — T8/defeat contracts unverified), `design/gdd/ecological-disturbance.md` (owns the derived window length)

---

## Review — 2026-06-01 — Verdict: MAJOR REVISION NEEDED (round-3 re-review)

**Scope signal:** L (verging XL — 5+ dependencies, two load-bearing sibling GDDs still unwritten, a cross-doc consume-timing contradiction, multiple new architecture obligations)
**Specialists:** game-designer, systems-designer, economy-designer, ux-designer, network-programmer, qa-lead, creative-director (senior synthesis) — full 7-spec adversarial panel
**Review depth:** full
**Prior verdict resolved:** Group A (round-2 reconciliation misses) — YES, fixed & committed (`b26fb89`). Group B (round-2 design decisions) — NO, still open. This pass ran BEFORE Group B was addressed, so Group B re-surfaced as expected.

### Summary

Senior verdict (creative-director): **sound thesis, converging — but the round structure is now generating churn.** All six specialists independently returned NEEDS/MAJOR REVISION. The survival-window redesign remains the correct structural fix and the defect *class* has shifted from round-1's "the design is wrong" to "the design is right but a few rulings, a forward-dependency relocation, and a mechanical sweep aren't done." Defect surface is shrinking. But this is the 2nd full 6-spec panel run against a document with known-open design blockers — full panel cost for partial-panel value, twice.

### Blocking items — Group B (round-2 carryover) — ALL CONFIRMED STILL OPEN

- **B1** victory-proximity rule undefined (C.5.6a/BCT4 = "≥1 alive" anywhere) → activate-and-scatter beats holding the beacon; breaks Section B fantasy + Pillar 2. *(game-designer, qa-lead, CD)*
- **B2** aid-suite-necessity asserted as fact in C.5.6a but unsubstantiated; canister-stack-and-bunker is the probable dominant line; depends on unwritten RM/PA. F.4 still missing the PA min-aggression forward obligation. *(game-designer, economy-designer)*
- **B4** cross-wall placement exploit — clamp + downward-raycast (C.5.5/BCT2/H.75) has no LOS reachability raycast. *(systems-designer, network-programmer, qa-lead)*
- **B5** survival-window timer never pinned to `RunService.Heartbeat` → E.25/H.77 tie-break determinism unenforceable if `task.delay`. *(systems-designer, network-programmer)*
- **B6** single-tap beacon activation (UI.2) violates art-bible tap-hold lock + is inconsistent with two-tap reversible recipe commit; irreversible placement has no friction model. *(ux-designer, game-designer)*
- **B7** H.80 zero-yield AC covers 3 of 8 state-mutating handlers → double-consume race on UseItem/EquipItem, double-spawn PlaceItem, double-transfer ActivateRelay. *(network-programmer, qa-lead)*
- **B8** H.27 (`±0.0002`) + H.61 (client-side count) non-deterministic — part of a 13-AC cluster needing a test-harness dt/timer-injection API. *(qa-lead)*
- **B9** H.74 (crash) + H.77 (tie-break) have no test-injection mechanism. *(qa-lead, systems-designer)*

### Blocking items — NEW this round (prior passes missed)

- D.1 has no guard against `CRAFT_BASE_DWELL_TIME = 0` → div-by-zero → instant craft. *(systems-designer)*
- **H.23 ("Relay consumed at placement") directly contradicts C.6 ("consumed on activation").** *(qa-lead, network-programmer)*
- G.6 tuning range `≈35–70 s` unsupported by the decay formula (at HALF_LIFE 45 s → ~24.6 s; 180 s → ~98.5 s). Nominal ~49 s derivation confirmed correct. *(systems-designer)*
- `RequestActivateRelay` has no per-player rate limit; `RequestEquipItem` has no atomic-step operation order. *(network-programmer)*
- No declared tie-break when craftProgress hits 1.0 on the same Heartbeat the last crafter cancels (BT3 vs BT5). *(systems-designer)*
- Solo-play (squad=1) fully unaddressed (BCT-DEFEAT trivial, inventory-lock soft-lock, fantasy collapse). *(game-designer)*

### Recommended

Signal Anchor lifetime 45 s < window ≈49 s; Relay dominated by Canister in bunkered play; "bench is exposure" may invert during the window; C.2 sanity-check rewrite (validates the dominant strategy); BIOMASS sink absent; RELAY tier 0.20 inside HYSTERESIS_BAND of MID 0.18; global rate-limit burst is a no-op; `BindToClose` during BC4 undefined; iPhone-SE "no scroll" false at accessibility text sizes; countdown-ring vs art-bible single-circle; BC4 9-surface HUD density unaudited; reduced-motion / WCAG 2.3.1 flash-frequency for flora pulse; BC2/BC3 unnamed RunEnded-cleanup transitions; benchPosition omitted from BT1 side-effects; beaconActivationTime non-nil invariant undeclared.

### Specialist note (positive dissent)

network-programmer affirmed the win-condition authority chain and attribution chain are **sound — no forge path.** Protect this when applying any B1 proximity change.

### Binding creative rulings (user may override)

- **B1 → Victory requires proximity:** ≥1 squad member alive AND within `BEACON_HOLD_RADIUS` (new knob, nominal ~30 studs) of the beacon at window-end. Makes Section B's fantasy consonant with mechanics; converts single-player-sacrifice into a fellowship test; makes B2 solvable.
- **B6 → Beacon placement AND activation are tap-hold** (`TAP_HOLD_COMMIT_DURATION`, ≥0.5 s; support going longer). Consistency-violation fix per the art-bible lock.
- **B2 deferred, not ruled:** relocate aid-necessity to named RM + PA forward obligations (RM oxygen-drain floor; PA BC4 min-aggression). Not a Crafting defect — a forward dependency.

### Sequencing guidance (CD)

Next session must be an **authoring session, not a review**, in order: (1) land B1/B6 rulings + solo handling; (2) relocate B2 to RM/PA forward obligations; (3) declare the test-injection API + pin the Heartbeat timer (B5); (4) mechanical-translation sweep for the arithmetic/contradiction defects — **with a self-stress pass before claiming done.** Only then a round-4 full panel against a document with zero open design decisions. **Do NOT predict APPROVED for round-4.** Squad Relay on watch as a possible cut candidate (two independent "does it justify itself?" signals — the round-1 Patch/Wrap pattern).

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-2 patched + Group-A reconciled & committed)
- Cross-cited: `design/gdd/player-controller.md` (round-6 MAJOR REVISION), `design/gdd/ecological-disturbance.md` (owns derived window length); Not-Started: `resource-management.md`, `predator-ai.md`, `resource-node.md`, `hud.md`

---

## Round-3 Authoring Pass Applied — 2026-06-01 — NOT YET RE-REVIEWED

**This is a patch record, not a review verdict.** It resolves the round-3 MAJOR REVISION blockers (Group B carryover B1–B9 + the new-blocking surface) via an authoring session, per the CD's "next session must be authoring, not a review" sequencing. A real round-4 `/design-review` (full depth) is the **next step** — do not treat this entry as APPROVED.

**Design decisions (user-approved this session):** B1 → proximity victory (`BEACON_HOLD_RADIUS = 30 studs`); B6 → tap-hold for beacon place AND activate; solo-play → unsupported at start (`MIN_SQUAD_SIZE = 2` upstream); Squad Relay → KEPT, burst merged to MID 0.18.

### Resolution by round-3 blocker

| Blocker | Resolution |
|---|---|
| **B1** victory-proximity | Victory requires ≥1 alive AND within `BEACON_HOLD_RADIUS = 30 studs` at window-end (C.5.6a, C.9 BC5/BCT4). New **scatter** defeat (alive but none in radius) → `OnBeaconWindowFailed(reason="scatter")` → PC defeat (the wipe path can't catch it since players are alive). Knob added to G.6 + registry; game-concept win-condition reconciled. E.27 + H.85. |
| **B2** aid-necessity | C.5.6a "load-bearing" assertion rewritten to a design *intent contingent on* two named forward obligations: RM **oxygen-drain floor** + PA **min-aggression** during BC4 (F.4 rows). No longer asserted as fact. |
| **B4** cross-wall placement | Server-side **LOS reachability raycast** (player→clamped candidate) added to the place-validation order (C.5.5, BCT2, C.15); `reason="unreachable-placement"`. E.28 + H.83. |
| **B5** Heartbeat timer | Survival-window completion pinned to a per-`RunService.Heartbeat` comparison (NOT `task.delay`) — C.5.6, C.9 BCT3, F.5. Static AC H.86. |
| **B6** activation friction | Beacon place AND activate are tap-hold (`TAP_HOLD_COMMIT_DURATION = 0.5 s`) — C.5.2, C.12.4 (contradiction fixed), UI.2 (all input methods), UI.5. H.87. |
| **B7** zero-yield | H.80 extended from 3 → all 8 state-mutating handlers (adds UseItem/EquipItem/PlaceItem/ActivateRelay). |
| **B8/B9** determinism | New **C.16 test-harness injection seam** (DI'd `_clock`/`_step(dt)`/`_simulateRestart`); H.27/H.28/H.30/H.31/H.39/H.41/H.46/H.61/H.74/H.77 rewritten to exact (no `±` tolerance / no client-side count). Section-H determinism preamble. ADR added to F.4. |
| D.1 div-by-zero | `CRAFT_BASE_DWELL_TIME > 0` startup invariant (`CRAFT_DWELL_TIME_FLOOR = 0.5 s`), fail-fast. D.1 guard + G.3 + H.82. |
| H.23/C.6 contradiction | Relay consume reconciled — item leaves inventory **at placement**, deployable **spent at activation**. C.2/C.6/H.23. |
| G.6 range | Window is derived `= BEACON_HALF_LIFE × 0.5476`; design band ~[35,70]s ⟹ ED `BEACON_HALF_LIFE` should tighten to ~[64,128]s (registry note + OQ.14). |
| Relay rate / Equip order | `RequestActivateRelay` per-player rate limit added; `RequestEquipItem` atomic-step order declared (C.6, C.15). |
| BT3/BT5 tie-break | Completion-first tie-break declared (C.8) + E.29 + H.81. |
| Solo-play | `MIN_SQUAD_SIZE = 2` upstream (C.17); lone-survivor mid-run path documented (E.30, H.84). |
| Relay cut-watch | KEPT; burst merged to MID 0.18 (`MAGNITUDE_CRAFT_RELAY` retired — C.2/G.4/VA.1/registry). Canister-vs-Relay balance → RM GDD. |

### Cheap recommended items also closed
`BindToClose` during BC4 (E.31 + C.9); `benchPosition` in BT1 side-effects; `beaconActivationTime` non-nil invariant (C.10); Anchor-lifetime-vs-window rationale; C.2 sanity-check rewritten to an aid-inclusive run; reduced-motion/flash + countdown-ring + HUD-density flagged to `/ux-design` (UI.5).

### Counts reconciled
Edge cases 24 → **29** (E.27–E.31, 12 categories); ACs 73 → **80** (H.81–H.87); craft-magnitude constants 5 → **4** (RELAY retired); recipes still 5; VA moments still 25 (Moment 26 retitled).

### Self-stress pass
Ran post-authoring. Caught + fixed one real defect: the **scatter** defeat has alive players, so PC's all-dead `RunEnded(defeat)` path cannot fire it — added the `OnBeaconWindowFailed` Crafting→PC signal (C.9, C.12.1, C.14, C.15, F.2, F.4, E.27, H.85, UI.3). Grep sweep reconciled stale victory phrasings (E.9, H.44, C.12.1, BC5) to the proximity rule and removed retired-`RELAY` references.

### Files touched
`design/gdd/crafting-and-items.md` (primary), `design/registry/entities.yaml` (add `BEACON_HOLD_RADIUS` + `MIN_SQUAD_SIZE`; retire `MAGNITUDE_CRAFT_RELAY`; `BEACON_HALF_LIFE` window-lock note; `onBeaconRejectedReason` enum), `design/gdd/game-concept.md` (win-condition proximity). **Not committed** (awaiting user instruction).

### Next
Round-4 full `/design-review` against a document with **zero open design decisions**. **Do NOT predict APPROVED for round-4.** Squad Relay still on watch (now MID-tier; revisit with RM oxygen values). OQ.14 (`BEACON_HALF_LIFE` window-lock) is a live cross-GDD decision for ED's next revision.

---

## Review — 2026-06-02 — Verdict: MAJOR REVISION NEEDED (round-4 re-review)

**Scope signal:** L (verging XL — 5+ dependencies, two load-bearing sibling GDDs still unwritten, a cross-GDD timing lock, a Relay cut rippling through C.2/C.6/G.3/G.4/VA/UI/registry)
**Specialists:** game-designer, systems-designer, economy-designer, ux-designer, network-programmer, qa-lead, creative-director (senior synthesis) — full 7-spec adversarial panel
**Review depth:** full
**Prior verdict resolved:** Round-3 Group B (B1–B9) + new-blocking + cheap-recommended — YES, the round-3 authoring pass landed them at the rule level (verified). But the authoring pass left a recurring **reconciliation-miss** residue and exposed two genuinely-new sharp defects.

### Summary

Senior verdict (creative-director): **sound thesis, one step from convergence — held at MAJOR on methodology, not design.** By defect volume/class-shift alone this is NEEDS REVISION (the class shifted from "design is wrong" to "design is right, execution incomplete + 2 new sharp findings"). The CD held it at MAJOR because the reconciliation-miss class named in rounds 2 AND 3 survived a round-3 session that ran a self-stress pass and declared itself converged — when a named class survives its own dedicated sweep, the sweep methodology is the failure. Specialist split: game/systems/economy → NEEDS REVISION; qa/network/ux → MAJOR REVISION NEEDED. **Positive (protect):** network-programmer affirmed the win-condition authority chain + attribution chain are SOUND after the B1 proximity change — no forge path; BCT4 reads server-authoritative `HumanoidRootPart.Position`.

### Blocking items — round-4 (~15, grouped)

1. **Reconciliation misses** (same class as round-2/3 Group A) — *[ux-designer, systems-designer, lead]* — G.8 still lists `TAP_HOLD_COMMIT_DURATION` as "Reserved for future crafting tap-hold flows (none in MVP)" (line 980), contradicting the B6 ruling (C.5.2/C.12.4/UI.2/H.87); VA.5 audio-contract item 3 still enumerates the retired "RELAY" tier (line 1075).
2. **`OnSignalAnchorTripped` payload contradiction** — *[systems-designer, network-programmer, game-designer]* — `anchorPosition` (C.7.3/C.14/C.15) vs `predatorPosition` (F.2/UI.3). Survived 3 rounds; live cross-doc defect for the unwritten HUD GDD. Needs a payload ruling.
3. **Tie-break production-determinism** — *[systems-designer, network-programmer]* — C.8/C.9 declare completion-first / window-survival-first but the prose concedes "whichever the scheduler orders first wins." Roblox has no Heartbeat connection-priority API; C.16 makes the unit tests deterministic but not production. Fix: buffer death/disconnect state and evaluate INSIDE the Heartbeat handler. The rule covers `Humanoid.Died` but NOT `Players.PlayerRemoving` (clean disconnect) at window-end → non-deterministic scatter-vs-victory for a legitimately held beacon.
4. **IEEE-754 float accumulation (new, sharp)** — *[qa-lead]* — H.28/H.30/H.31/H.41 assert exact equality after 300–600 sequential additions in D.1's accumulator. Closed-form `600×(1/60)/10 == 1.0` is exact; the accumulator drifts (overshoot 1.0000000000000095 / undershoot 0.9999999999999961 so BT3 never fires on the claimed step). The C.16 seam fixes inputs, not the algorithm. The round-3 "exact, no tolerance" claim is false for these four ACs.
5. **C.16 self-contradiction** — *[network-programmer]* — C.16 says a handler calling `workspace:GetServerTimeNow()` directly "is a regression reviewers MUST reject," but C.9 BCT3 step 2 (+ C.10/C.4 schema comments) instruct exactly that.
6. **Economy** — *[economy-designer, game-designer]* — (a) the C.2 "realistic" 18-gather sanity check makes an unsupported factual claim (RESONANT-disturbance math missing; explicitly un-validatable until RM/PA land per OQ.13); (b) Squad Relay (kept off cut-watch round-3, merged to MID) is economically dominated by stacked Oxygen Canisters under the 30-stud hold — position-ping differentiator near-worthless when the squad must cluster. "Zero open design decisions" claim is therefore false.
7. **OQ.14 is a blocking under-spec, not an open question** — *[systems-designer, game-designer]* — `BEACON_SURVIVAL_WINDOW` derived from ED `BEACON_HALF_LIFE` ∈ [45,180]s → windows [24.6,98.9]s, both endpoints degenerate. (Coefficient is 0.5484, not 0.5476 — negligible; integer band survives.)
8. **UX** — *[ux-designer]* — BC4 HUD density (9–10 concurrent surfaces on iPhone SE at the highest-stakes 49 s — successor to round-1's iPhone-SE pillar collision) deferred to `/ux-design`; scatter-defeat hold-zone legibility (a LOSE condition) left as a UX deferral; WCAG 2.3.1 flash-frequency for activation flora mis-marked Recommended.
9. **AC coverage gaps** — *[qa-lead]* — missing ACs for `RequestActivateRelay` rate limit, `RequestEquipItem` double-equip outcome, `OnBeaconWindowSurvived`/`Failed` mutual-exclusion, BindToClose-during-BC4, `beaconActivationTime != nil` invariant, exact-30.0-stud boundary. H.73/H.76 still mislabeled [P0] Logic when they depend on PC's unverified contracts — round-2's B3 ("mark integration/unverified-until-PC") was never resolved and silently dropped from round-3's list.

### Recommended (deferred to round-5 authoring)
`RequestEquipItem` no burst clause (round-1 B12 class); BIOMASS sink absent (canister-bunker is the quietest winning line); Signal Anchor single-shot + 45 s lifetime may be a window trap-recipe; D.6 `DAMPENER_REDUCTION` ceiling rationale arithmetically misleading; `ActiveDeployables.squadRelay.lifetimeStart` dead field (no `SQUAD_RELAY_LIFETIME`); `RunSession.beaconCrafterId` written-never-read; D.6a `clamp_floor()` notation reads as math.clamp not no-emit; Coil 10 s warning color-only (violates UI.4); "no-scroll" panel false at large accessibility text sizes; bench-to-beacon distance vs `BEACON_HOLD_RADIUS` is an un-flagged level-design coordination gap.

### Specialist note (positive dissent — protect)
network-programmer: the win-condition authority chain + attribution chain are **sound — no forge path** after B1. BCT4 reads server-authoritative `HumanoidRootPart.Position`; flag guards airtight. Any B1/tie-break fix must NOT touch the server-authoritative completion/attribution path.

### Binding creative rulings (user may override)
- **R4-1 (OQ.14):** ED tightens `BEACON_HALF_LIFE` to ~[64,128]s; Crafting does NOT decouple — relocate to an ED forward obligation + registry lock. This is what lets round-5 honestly claim "zero open design decisions."
- **R4-2 (Squad Relay): CUT.** 3rd round on watch; now economically dominated under the 30-stud hold (the Composite Patch/Wrap pattern). Also shrinks the reconciliation surface.
- **R4-3 (D.1 float):** respecify as from-start `progress = craftRate × stepCount × dt` (exact); do NOT retreat to range-asserted ACs.
- **R4-4 (C.16):** narrow the prohibition to handler bodies; `_clock()` is the sanctioned wrapper; schema comments may stand.
- **R4-5 (tie-break):** buffer death/disconnect inside the Heartbeat handler (not independent signal connections); cover `Players.PlayerRemoving`, not only `Humanoid.Died`.

### Sequencing guidance (CD)
Round-5 = an **authoring session + TWO narrow fresh-agent gates only** (qa-lead scoped to determinism ACs; network-programmer scoped to C.16 + attribution-chain-regression) — **NOT a full panel** (full-panel cost for partial-panel value, now 3 rounds running). The full 7-spec panel returns at **round-6** as the single closure gate. The round-5 self-stress pass MUST carry an explicit **reconciliation-fanout checklist** (the generic self-stress missed this class twice). **DO NOT predict APPROVED for round-6.**

### Files Referenced
- Target: `design/gdd/crafting-and-items.md` (round-3 authoring pass; 1802 lines; NOT committed)
- Cross-cited: `design/gdd/player-controller.md` (round-6 MAJOR REVISION — T8/`OnBeaconWindowFailed`/all-dead contracts unverified), `design/gdd/ecological-disturbance.md` (owns `BEACON_HALF_LIFE` → OQ.14 / R4-1); Not-Started: `resource-management.md`, `predator-ai.md`, `resource-node.md`, `hud.md`
- Registry: `design/registry/entities.yaml` (R4-1 `BEACON_HALF_LIFE` lock + R4-2 Relay cut land here in round-5)

---

## Round-5 Authoring Pass Applied — 2026-06-02 — NOT YET RE-REVIEWED

**This is a patch record, not a review verdict.** It applies CD rulings R4-1..R4-5 + the ~15 round-4 blocking items + the recommended sweep via an authoring session, per the CD's "round-5 = authoring + TWO narrow gates, NOT a full panel" sequencing. The next step is the **two narrow fresh-agent gates** (qa-lead scoped to determinism ACs; network-programmer scoped to C.16 + attribution-regression), then a **round-6 full `/design-review`** as the single closure gate. **Do NOT treat this entry as APPROVED. Do NOT predict APPROVED for round-6.**

**Design decisions (user-approved this session):** Squad Relay → **CUT** (R4-2); `OnSignalAnchorTripped` payload → **`anchorPosition`** (canonical; F.2/UI.3 were the outliers); scatter-defeat hold zone → **world-ring + HUD in/out-of-radius state, both required** (no longer /ux-design-deferred).

### Resolution by round-4 blocker

| Round-4 blocker | Round-5 resolution |
|---|---|
| #1 Reconciliation misses (G.8 stale tap-hold; VA.5 stale RELAY tier) | G.8 `TAP_HOLD_COMMIT_DURATION` row rewritten to the B6 beacon place/activate use; VA.5 item 3 RELAY removed (folded into the Relay cut). Ran a **reconciliation-fanout sweep** (grep `Relay/RELAY/predatorPosition/clamp_floor/GetServerTimeNow` + count statements) to catch the full fan-out. |
| #2 `OnSignalAnchorTripped` payload contradiction (3 rounds open) | Ruled **`anchorPosition`** canonical (consistent with C.7.4 single-shot "one piece of intel, not a tracking minimap"); fixed the two outliers F.2 + UI.3. |
| #3 Tie-break production-determinism (no Heartbeat priority API) + disconnect-at-window-end | **R4-5:** death (`Humanoid.Died`) AND disconnect (`Players.PlayerRemoving`) buffered into `_pendingDepartures`, drained **inside** the one Heartbeat handler **after** the window-survival/completion check — completion/survival-first is now a property of straight-line handler code, not connection-priority luck. C.8/C.9 rewritten; E.25/E.29 cover disconnect; H.77/H.81/H.86 updated; BCT-DEFEAT covers `PlayerRemoving`. |
| #4 IEEE-754 float accumulation (H.28/30/31/41) | **R4-3:** D.1 respecified as from-start closed form `progressAtRateAnchor + (stepsSinceRateAnchor × dt × mult)/CRAFT_BASE_DWELL_TIME` (piecewise across rate changes; divides by dwell, matching the AC arithmetic). CraftSession schema gains `progressAtRateAnchor`/`stepsSinceRateAnchor`. Registry formula updated. |
| #5 C.16 self-contradiction (BCT3 step 2 vs the blanket forbid) | **R4-4:** C.16 forbid narrowed to **handler bodies**; C.9 BCT3 step 2 + C.4/C.10 schema comments + C.5.6 + C.11.1 rewritten to `_clock()`; F.5 + C.16 seam-table "production default" column explicitly exempted. |
| #6 Economy (C.2 "realistic" claim; Relay dominance) | C.2 "realistic" → "illustrative (not validatable until RM/PA — OQ.13)"; **Relay CUT** (R4-2) removes the dominated line; new OQ.15 flags the thinning BIOMASS sink. |
| #7 OQ.14 blocking under-spec | **R4-1:** ED tightens `BEACON_HALF_LIFE`→`[64,128]s` (no decouple) — relocated to ED forward obligation (F.4) + registry lock (G.6/G.8 + entities.yaml); OQ.14 marked **RESOLVED/CLOSED**. |
| #8 UX (scatter-zone legibility; WCAG flora-flash) | Hold zone **locked** to world-ring + HUD state (VA Moment 26, UI.1 surface 13, UI.5); WCAG 2.3.1 flora-flash **escalated to a blocking ED obligation** (F.4 ED row, UI.5). BC4 HUD-density iPhone-SE audit kept as `/ux-design` work but the surface set is now **capped** (no new BC4 surface without re-audit). |
| #9 AC gaps + H.73/H.76 mislabel | H.73/H.76 relabeled **Integration + unverified-until-PC** (round-2 B3 finally resolved) with cross-GDD locks. New ACs **H.88** (double-equip behavioral), **H.89** (window survived/failed mutual-exclusion), **H.90** (BindToClose-during-BC4), **H.91** (`beaconActivationTime` invariant), **H.92** (exact-30.0-stud `<=` boundary). |

### Recommended items also closed
`beaconCrafterId` annotated analytics-only; `ActiveDeployables.squadRelay` removed (dead-field moot); `D.6a clamp_floor()` → `floor_discard()` (with no-not-math.clamp note); Coil final-10s warning made non-color-only (UI.1 surface 4 / UI.4); bench-to-beacon-plinth vs `BEACON_HOLD_RADIUS` level-design coordination note added (F.2 LD row); global-rate-limit re-summed (~5.4, was ~6.4) after the Relay-event removal.

### Counts reconciled
Recipes 5 → **4**; squad item types 5 → **4**; VA moments 25 → **23** (24/25 retired); ACs 80 → **84** (H.23 retired, H.88–H.92 added, numbered through H.92); edge cases **29** (unchanged — disconnect folded into E.25); client-initiated RemoteEvents 8 → **7**.

### Reconciliation-fanout checklist (round-5 self-stress — the class that survived twice)
Ran explicit grep sweeps for every cut/renamed token and every count: `Relay/RELAY/squadRelay/RequestActivateRelay/OnOxygenTransfer` (all live refs retired or annotated; retirement stubs kept), `predatorPosition` (→ `anchorPosition`, 1 outlier fixed), `clamp_floor(` (→ `floor_discard`, only the rename-explainer references the old name), `GetServerTimeNow` (handler-body uses → `_clock()`; production-default/schema-comment uses annotated and exempt), and all count statements (`recipes`/`item types`/`moments`/`ACs`/`distinct types`). Residual matches verified intentional (retirement notes, production-default annotations, historical change-log parentheticals).

### Files touched
`design/gdd/crafting-and-items.md` (primary — ~60 edits), `design/registry/entities.yaml` (`BEACON_HALF_LIFE` lock note; `MAGNITUDE_CRAFT_MID`/`HEAVY` Relay-cut notes; `SQUAD_INVENTORY_TYPE_CAP` 5→4; `craftProgress` formula → clock-elapsed closed form; `multiCrafterDwellRate` naming note). **Not committed** (awaiting user instruction). `game-concept.md` not re-touched (already on the survival-window win condition since round-2).

### Round-5 narrow gates RAN this session (both returned DEFECTS — all resolved in-session)

Per the CD process, the round-5 authoring was immediately gated by TWO narrow fresh-agent reviews (NOT a full panel). Both found genuine defects; all were fixed in the same session.

- **qa-lead gate (determinism scope):** confirmed the round-4 IEEE-754 accumulation finding is closed by the closed form, but flagged 3 BLOCKING + 4 RECOMMENDED. The load-bearing catch: the CD's **literal R4-3 form `craftRate × stepCount × dt` is itself defective** — (a) **incorrect under variable Heartbeat `dt`** (`storedSteps × currentDt` ≠ true elapsed time; real `dt` is jittery), and (b) **not provably exact** (`600 × (1/60)/10 == 1.0` is unverified in IEEE-754 double on the Roblox runtime). **Resolution (refines R4-3 to honor its intent):** D.1 respecified as a **clock-elapsed** closed form `progressAtRateAnchor + ((_clock() − rateAnchorClock) × crafterSpeedMultiplier(N)) / CRAFT_BASE_DWELL_TIME` — correct for any `dt`, no accumulation, and **provably exact** because the C.16 seam sets `_clock()` to exact dwell boundaries (`10.0/10.0`, `5.0×2/10.0`, `2.0/2.0`, `2.5×2/10.0` — all exactly representable). Also consistent with the survival-window timer (already `_clock()`-based). `CraftSession.stepsSinceRateAnchor` → `rateAnchorClock`. H.27–H.31/H.41 rewritten to clock-boundary assertions; registry formula updated. Other fixes: variable-name unification (`crafterSpeedMultiplier(N)` canonical; registry `effective_N` annotated as the same); H.73/H.76 split into a blockable Logic Part 1 + a deferred Integration Part 2; H.88 mechanism corrected to direct back-to-back handler invocation (not the `_step` seam); H.92 boundary negative changed `30.0 + ε` → `31.0 studs`.
- **network-programmer gate (C.16 + tie-break + attribution scope):** CONFIRMED all three protected claims — "C.16 self-contradiction resolved" (handler-body boundary is crisp + mechanically applicable), "buffered tie-break is production-deterministic and covers `Players.PlayerRemoving`" (no connection-priority dependency; internally consistent across C.8/C.9/E.25/E.29/H.77/H.81/H.86), and **"win-condition authority + attribution chains remain SOUND — no forge path after round-5"** (BCT3→`beaconPlacerId`, BCT4→server `HumanoidRootPart.Position`, flags server-only/monotonic; Relay cut orphaned no attribution path; H.88/H.91/H.92 open no client-trust hole). Found 1 BLOCKING + 1 RECOMMENDED: **F.4's PC-obligation event list still named the cut `RequestActivateRelay`** (a reconciliation miss of exactly the flagged class) — FIXED (now 7 events, matching C.15 + H.80); and the `_pendingDepartures` buffer scope (bench-`CraftSession` vs RunSession-beacon) was implicit — FIXED with an explicit two-scope disambiguation in C.8.

The gates were not re-run after the fixes (round-6's full panel is the closure gate). Note that the clock-elapsed D.1 refinement is a deliberate, gate-driven deviation from the *literal* R4-3 wording — it better achieves R4-3's stated goal; the user/CD may revisit it at round-6.

### Next
**TWO narrow fresh-agent gates ONLY** (qa-lead → determinism ACs incl. the new D.1 closed form + H.88–H.92; network-programmer → C.16 handler-body narrowing + the buffered-departure tie-break + attribution-chain non-regression). NOT a full panel. **Then round-6 full `/design-review`** as the closure gate. **Do NOT predict APPROVED for round-6.** Still cross-GDD-pending: ED applies the `BEACON_HALF_LIFE`→[64,128]s registry edit (R4-1) at its next revision; PC (round-6 MAJOR) must wire `OnBeaconWindowSurvived`→T8 + subscribe `OnBeaconWindowFailed` (H.73/H.76 unverified-until-PC).

---

## Review — 2026-06-02 — Verdict: MAJOR REVISION NEEDED (round-6 closure-gate re-review)

**Scope signal:** L (verging XL — 6 dependencies, 4 unwritten with 2 load-bearing; 7 formulas; 5 ADRs flagged; 84 ACs; win-condition cross-cutting)
**Specialists:** game-designer, systems-designer, economy-designer, ux-designer, network-programmer, qa-lead, creative-director (senior synthesis) — full 7-spec panel (the designated single closure gate)
**Review depth:** full
**Prior verdict resolved:** Round-4 named blockers + the round-5 authoring pass — **YES at the rule level, verified.** D.1 IEEE-754 drift (clock-elapsed form is bit-exact), C.16 self-contradiction, the `predatorPosition`→`anchorPosition` payload (3-round defect), and the round-4 named reconciliation-misses (G.8 tap-hold, VA.5 RELAY) are all CLOSED. But the panel found the root cause moved upstream (see methodology note).

### Summary

5th consecutive non-APPROVED — but the CD synthesis is **"converging, not treading water."** Specialist verdict split: **5 NEEDS REVISION** (game-designer, systems-designer, ux-designer, network-programmer, qa-lead) / **1 MAJOR REVISION NEEDED** (economy-designer). The CD adjudicated **MAJOR**, with the economy finding (Group B) setting the floor: it is a *structural* breakage **introduced by a prior binding ruling** (R4-2 cut the Squad Relay, worsening canister-bunker dominance) whose load-bearing balance claim is unfalsifiable until two unwritten sibling GDDs land — this cannot be averaged down to the five locally-closeable NEEDS-REVISION findings.

**Positive finding to PROTECT (confirmed, no regression):** network-programmer re-affirmed the **win-condition authority + attribution chain is SOUND — no forge path** (`beaconPlacerId` server-set, `Emit` uses placer not activator, flags server-only/monotonic, Relay cut orphaned no path). No Group-A/B fix may touch the server-authoritative completion/attribution path.

### Blocking items — round-6 (grouped)

**Group A — win-condition data model unspecified (3-lens convergence: systems + network + qa — most reliable signal):**
1. **Alive-set has no schema field** (C.10). BCT4 victory + BCT-DEFEAT evaluate "members alive AND within `BEACON_HOLD_RADIUS`" with no declared data model. *[systems SM2-F1, network Finding 1]*
2. **Two sources of truth.** C.9 (line 231) reads each member's **live** `HumanoidRootPart.Position`, while the H.77 tie-break reads a **pre-drain buffered** alive set — undermining the very production-determinism R4-5 was meant to deliver; the live read can also race character destruction in the `PlayerRemoving` handler. *[network Finding 5]*
3. **`_pendingDepartures` dual-scope dispatch** (bench `CraftSession` vs RunSession beacon) is intent-without-mechanism — an implementer can build a single-consumer queue that silently drops one scope. *[network Finding 2]*
4. **`benchMaxCraftersEffective`** gates BT2 + drives D.2 but has no storage field in any schema. *[systems SCH1-F1, qa C4]*
5. **D6a Stage-2 ownership undefined** — which service applies PC's `STATIONARY_EMISSION_FACTOR`? Double-apply/omit breaks the Coil floor-discard. *[systems D6a-F1]*

**Group B (decisive) — economy: win-condition balance claim is unfalsifiable:**
6. **Canister-bunker is still the dominant quiet winning line, and R4-2 made it WORSE** — cutting the Squad Relay removed the only alternative oxygen source; the entire oxygen burden now rests on the cheapest/quietest 2/0/0 recipe (stackable ×10). Aid-necessity (C.5.6a) is an explicit "design target contingent on two UNWRITTEN GDDs" (RM oxygen-drain floor + PA min-aggression). *[economy Finding 2, game-designer #2]*
7. **BIOMASS sink degenerate** — in the dominant line BIOMASS ≈ 67% of gathers; MINERAL/RESONANT serve only the mandatory Beacon → Medium nodes are dead content. A structural material-tier decision mis-filed as a "tuning" question (OQ.15). *[economy Finding 3/7]*

**Group C — UX on the primary platform:**
8. **BC4 HUD density** (~8–9 concurrent surfaces, 375pt iPhone SE, highest-stakes 49s) is self-described in UI.5 item 6 as "blocking-for-implementation"; "capped + deferred to `/ux-design`" is not closure. *[ux Finding 1]*
9. **Scatter hold-state underspecified** — the locked HUD in/out-of-radius indicator needs per-member live distance, but no signal carries it during BC4 (proximity is evaluated only at window-end); a scattered off-screen player gets "HOLD THE BEACON" with no specified directional cue. *[ux Finding 2]*
10. **WCAG 2.3.1 flora-flash** — Crafting fires the activation + Section B writes "pulse faster than ever," but the only cap is a hand-off to the unwritten ED flora author; no Crafting-owned cap or AC. *[ux Finding 3]*

**Group D — AC testability:**
11. **H.90 (BindToClose-during-BC4) not headlessly testable** — C.16 declares only `_clock`/`_step`/`_simulateRestart`; needs a `_simulateBindToClose` seam. *[qa A1]*
12. **H.15 mislabeled Integration** → unreachable sprint gate (depends on PC's unbuilt T8); needs the H.73/H.76 Logic-P1/Integration-P2 split. *[qa E1]*
13. **H.39 midpulse float-trap** — "bit-exact" only holds at the default `CRAFT_BEACON_MIDPULSE_PROGRESS = 0.5`; the tunable range [0.4,0.6] contains non-representable values, contradicting the determinism preamble. *[qa Section 1]*

### Recommended (deferred to the round-7 authoring pass)
Player Fantasy (Section B) overstates the Coil (BC4 value is positional freedom, not noise reduction) and the Anchor (single-shot fires at max constraint; 45s < 49s lifetime-inversion → it's a pre-activation recipe) — revise B or adjust Anchor lifetime; the "predator commits" emotional center lives in the unwritten PA GDD; 2-player bench has no coordination decision (cap=1); the "nobody-watches" round-2 fix only holds for squads that *start* at 2 (a 3→2 mid-run drop keeps cap=2, unacknowledged); `RequestEquipItem` missing burst clause; `RequestCraftCancel` buffering ambiguity; global rate-limit window misalignment (2s vs 3s); new stale "Moment 25" ref in UI.4; missing ACs (BT2 wrong-recipe rejection, BT4 anchor-reset, global-limit burst-window, `_enqueueDeparture` test seam); test-type mislabels (H.38/H.63/H.64/H.65/H.66, H.10 unverified-until-PC note).

### Specialist Disagreement (adjudicated)
Economy-designer = MAJOR; the other five = NEEDS REVISION. CD adjudicated MAJOR — Group B is structural and was introduced by a prior ruling (R4-2), and its load-bearing claim cannot be verified until RM/PA exist. Network's "authority chain SOUND" is a constraint on the fix, not a counter-verdict.

### Senior Verdict (creative-director)
Three real BLOCKING groups. The round-5 reconciliation-fanout checklist *worked* on the round-4 named class — but the root cause moved upstream: **rules land while the mechanisms beneath them stay implicit**, and the alive-set gap (Group A) was arguably *created by* the R4-5 tie-break fix and found independently by three lenses. That is a *different* class, so it was not held against the old one — but it requires a schema-completeness sweep layer going forward. Group B sets the floor at MAJOR.

### Recommended next-step sequence (CD)
1. **CD design ruling on Group B BEFORE authoring** (structural balance call — e.g. a Crafting-side counter to canister-stacking now, vs. converting C.5.6a into a falsifiable forward-obligation on RM/PA, vs. re-adding an alternative oxygen line). User's call given the RM/PA timeline.
2. ONE authoring pass for Groups A + C + D + the AC/Recommended tail (with a new schema-completeness sweep alongside the reconciliation-fanout checklist).
3. **THREE narrow fresh-agent gates for round-7** (economy; systems + network jointly on the Group-A schema; ux) — NOT a full panel.
4. **DO NOT predict APPROVED for round-7.** Protect the network-confirmed authority/attribution chain at all costs.

**User chose to STOP and revise in a separate session.** Branch `crafting-round2-patch`; round-3/4/5/6 work all still NOT committed.

### Files Referenced
- Target: `design/gdd/crafting-and-items.md` (round-5 authoring pass; 1864 lines; NOT committed) — load-bearing confirmations at lines 231 (live position read), 494 (`benchMaxCraftersEffective`), 777 (canister economy)
- Cross-cited: `design/gdd/player-controller.md` (round-6 MAJOR — T8/`OnBeaconWindowFailed`/all-dead contracts unverified-until-PC), `design/gdd/ecological-disturbance.md` (owns the derived window; owes the `BEACON_HALF_LIFE`→[64,128]s registry edit per R4-1); Not-Started: `resource-management.md`, `predator-ai.md` (both load-bearing for the Group-B aid-necessity claim), `resource-node.md`, `hud.md`
- Registry: `design/registry/entities.yaml` (R4-1 lock note present; default 90s inside the new band — verified)

---

## Round-7 Authoring Pass Applied — 2026-06-02 — NOT YET RE-REVIEWED

**This is a patch record, not a review verdict.** It applies the CD's round-6 sequencing — a CD design ruling on the decisive Group-B economy blocker FIRST, then ONE authoring pass for Groups A + C + D + the AC/Recommended tail, with a reconciliation-fanout checklist AND a new schema-completeness sweep. The next step is **THREE narrow fresh-agent gates** (economy; systems + network jointly on the Group-A schema; ux) — **NOT a full panel** — then a **round-8 full `/design-review`** as the closure gate. **Do NOT treat this entry as APPROVED. Do NOT predict APPROVED for round-8.** Patch plan: `design/gdd/reviews/crafting-and-items-round7-patch-plan.md`.

**Design decisions (user-approved this session):** Group-B direction → **Hybrid A+B** (Crafting-owned in-window Canister-use emission + falsifiable RM/PA forward-obligation contracts); Finding-7 BIOMASS sink → **structural fix now** (Signal Anchor re-weight 1/1/1 → 2/1/0); Anchor lifetime-inversion → **revise Section B prose** (keep the intentional 45 s < 49 s design); BC4 HUD density → **lock the ≤ 4-surface cap + suppress-list** (not a /ux-design deferral). The creative-director produced the binding Group-B ruling recommendation (Hybrid A+B + Anchor re-weight) before authoring.

### Resolution by round-6 blocker group

| Round-6 blocker | Round-7 resolution |
|---|---|
| **Group B #6 — canister-bunker dominance (decisive, MAJOR floor)** | **Hybrid A+B.** Structural-now: in-window Oxygen Canister *use* emits `MAGNITUDE_CANISTER_INWINDOW_USE = 0.18` at the using player's server-tracked position **only while the beacon is in BC4** (C.6, C.2, C.11, C.15, G.4, E.32, VA Moment 28, H.93) — the bunker line is no longer free even before RM/PA land. Deferred-but-falsifiable: F.4 RM (`OXYGEN_DRAIN_BC4_FLOOR`) + PA (`PREDATOR_BC4_MIN_COMMIT`) obligations rewritten as numeric inequality contracts each with a binding AC the future GDD must satisfy. C.5.6a rewritten: full necessity is a *target gated on the two F.4 ACs*, but the bunker line is non-free in their absence. |
| **Group B #7 — degenerate BIOMASS sink** | **Structural fix.** Signal Anchor re-weighted 1/1/1 → 2/1/0 (C.2, G.3, OQ.13) — BIOMASS gains a 3rd consumer; all three node tiers keep a non-Beacon draw; cost-neutral at 3 gathers. OQ.15 structural question marked RESOLVED (only exact-weight tuning remains). |
| **Group A — win-condition data model (3-lens convergence)** | (1)+(2) Single per-tick **`windowAliveInRadius` snapshot** (C.10) — built once at the top of the BC4 tick before the drain; BCT4 victory + scatter checks both read it; kills the round-6 "live read vs buffered set" two-sources-of-truth (C.9 reconciled; H.77 + H.99). (3) **`_enqueueDeparture` fan-out seam** (C.8) — one event updates BOTH bench + RunSession scopes, no single-consumer queue (H.101). (4) **`benchMaxCraftersEffective` storage field** added to RunSession (C.10, H.100). (5) **D.6a Stage-2 ownership ruled** — applied once by the pulse's publishing service (PC for Light pulses); never doubled/omitted (H.38 relabel). |
| **Group C — UX** | (8) BC4 HUD **≤ 4-surface cap + suppress-list** (suppress personal-inv + bench rings during BC4; collapse squad inv to a compact aid strip; merge beacon chevron into hold indicator) — UI.5 item 7 (replaces the "deferred" non-closure). (9) New **`OnBeaconHoldStateChanged(playerId, inRadius)`** signal carries live per-member in/out-of-radius state during BC4 (C.14/C.15/UI.1/UI.3, H.94; presentation-only — does not change the win evaluation). (10) **Crafting-owned WCAG 2.3.1 cap** on Crafting's own BC4 surfaces (countdown ring, hold world-ring, Coil warning), ED keeps the flora cap (UI.5 item 6, H.95). |
| **Group D — AC testability** | (11) **`_simulateBindToClose` seam** added to C.16; H.90 rewritten to use it. (12) **H.15 split** into Logic Part-1 (sprint-gate) + Integration Part-2 (unverified-until-PC). (13) **H.39 reframed** as a `>=` crossing test (robust to non-default-threshold representability); removed from the bit-exact-equality cluster in the determinism preamble. |

### Recommended tail closed
Section B Coil/Anchor prose (honest BC4 roles — Coil = positional freedom + breaking the predator's read; Anchor = reactive ~45-of-49 s read); C.3.5 acknowledges the 3→2-mid-run cap-never-shrinks transient; `RequestEquipItem` burst clause added (C.15, round-1 B12 class); `RequestCraftCancel` effect routed through `_enqueueDeparture` (C.8 buffering clarity); global rate-limit burst window aligned 2 s → 3 s (C.15, H.98); stale "Moment 25" removed from UI.4; 9 new ACs H.93–H.101; test-type relabels (H.63/H.64/H.66 → Performance-advisory; H.65 → Logic; H.10 + H.38 → unverified-until-PC).

### Counts reconciled
Recipes **4**, item types **4** (unchanged); VA moments 23 → **24** (Moment 28); edge cases 29 → **30** (E.32); ACs 84 → **93** (H.93–H.101); Craft-magnitude knobs (G.4) 4 → **5** (`MAGNITUDE_CANISTER_INWINDOW_USE`); client-initiated RemoteEvents **7** (unchanged; +1 server-pushed `OnBeaconHoldStateChanged`).

### Self-stress passes ran (both — the round-6-mandated layers)
1. **Reconciliation-fanout checklist** — grep sweep of every new/renamed token (`MAGNITUDE_CANISTER_INWINDOW_USE`, `OnBeaconHoldStateChanged`, `_simulateBindToClose`, `_enqueueDeparture`, `windowAliveInRadius`) + every count statement. **Caught a genuine pre-existing round-5 miss:** the recipe panel was still described as "5 rows" in VA.3 Moment 2 / UI.1 surface 1 / UI.2 / UI.4 while the catalog is 4 recipes (Relay cut) — all four reconciled to "4 rows." All retired-token references verified as historical "was/removed" notes (no stale active refs).
2. **Schema-completeness sweep** (new round-7 layer) — confirmed every new RULE has a named DATA MODEL: canister-emission gate reads existing `beaconActivated`/`beaconWindowSurvived`; hold-state signal reads `windowAliveInRadius` (C.10); `benchMaxCraftersEffective` has a storage field; dual-scope dispatch has the `_enqueueDeparture` seam. No rule landed without its mechanism.
3. **Authority-chain protection** — confirmed no edit touched the server-authoritative BCT3 (`beaconPlacerId` Emit) or BCT4 completion/attribution path; the new canister emission uses server-tracked position + the using player's id on the already-validated `RequestUseItem` handler, opening no forge path.

### Files touched
`design/gdd/crafting-and-items.md` (primary — ~40 edits, 1864 → ~1950 lines), `design/registry/entities.yaml` (new `MAGNITUDE_CANISTER_INWINDOW_USE`; `onCraftRejectedReason` enum + `recipe-mismatch`/`already-equipped`; Anchor cost lives in the GDD, not the registry — no registry cost edit needed). **Not committed** (awaiting user instruction).

### Next
**THREE narrow fresh-agent gates** (economy → does a non-bunker line beat the bunker line AND do Canisters stay worth crafting + the F.4 contracts are checkable inequalities; systems+network jointly → the Group-A `windowAliveInRadius` / `_enqueueDeparture` / `benchMaxCraftersEffective` schema + non-regression of the authority chain; ux → the ≤4 BC4 cap + the hold-state signal). NOT a full panel. **Then round-8 full `/design-review`.** **Do NOT predict APPROVED for round-8.**

---

---

## Review — 2026-06-03 — Verdict: MAJOR REVISION NEEDED
Scope signal: XL
Specialists: game-designer, systems-designer, economy-designer, network-programmer, ux-designer, qa-lead, gameplay-programmer, creative-director (senior synthesis)
Blocking items: ~13 | Recommended: ~14
Prior verdict resolved: No — 8th consecutive non-APPROVED. Round-6 was MAJOR (Group-B bunker + win-condition data-model methodology); the round-7 authoring pass attempted to close it.

**This is the round-8 full `/design-review` (the designated closure gate after the round-7 authoring pass + the three narrow gates the CD scheduled). Run against the round-7 document. NOT committed.**

### Specialist verdicts
- **game-designer = MAJOR REVISION NEEDED**
- systems-designer = NEEDS REVISION
- economy-designer = NEEDS REVISION
- **network-programmer = NEEDS REVISION; AUTHORITY-CHAIN STATUS: SOUND** (round-7 preserved win-condition authority + attribution — the new in-window canister emission uses server-tracked position + server session id, no forge path, touches no beacon flag)
- ux-designer = NEEDS REVISION
- qa-lead = NEEDS REVISION
- gameplay-programmer = NEEDS REVISION

### BLOCKING (grouped by lens; source-tagged)

**Recurring root-cause class — round-7's own additions introduced fresh mechanism-implicit / schema-omission defects:**
1. `[systems][gameplay][qa]` **`OnBeaconHoldStateChanged` crossing-detection contradiction.** C.10 states `windowAliveInRadius` is "NOT stored across ticks," but detecting a `BEACON_HOLD_RADIUS` boundary-cross (C.14 / H.94) requires the previous tick's membership. No previous-snapshot storage, no first-tick case, no throttle/re-arm bound specified. Unimplementable as written; H.94 not unit-testable (no position-injection seam in C.16). Found independently by three lenses.
2. `[gameplay][qa]` **`_pendingDepartures` queue absent from schemas; `_enqueueDeparture` absent from the C.16 seam table.** The buffer is referenced ~6× across the C.8/C.9 tie-break spine and is the load-bearing determinism mechanism, but it appears in neither the `CraftSession` nor `RunSession` schema (C.10), and its lifecycle (create/scope/drain/discard) is unstated. `_enqueueDeparture` is cited as a test seam in H.99/H.101 but is not in C.16's four-row table. This is the exact B7/B8 schema-omission class the round-7 schema-completeness sweep was supposed to catch.
3. `[gameplay]` **`windowAliveInRadius` alive-predicate undefined.** The "snapshot is safe vs a half-destroyed `HumanoidRootPart`" determinism claim rests entirely on the alive check, but what "alive" means against Roblox's deferred character teardown (`Players.PlayerRemoving` vs `Humanoid.Health` vs a server-authoritative alive-set) is never specified — two implementers write two predicates with different race behavior.

**Determinism / state machine:**
4. `[systems]` D.1 + the survival-window comparison have **no guard against backward server-time slew** (NTP / VM migration) — a negative `_clock() - rateAnchorClock` freezes craft progress and can deny BCT4 victory. C.16 tests only a monotonically-advanced injected clock, so the path is untestable under the current seam.
5. `[systems]` **BCT-DEFEAT wipe has two firing paths** (Crafting's departure drain detecting an empty alive-set AND PC's all-dead `RunEnded(defeat)` path) with no specified mutual-exclusion guard → double-cleanup risk.
6. `[systems]` **`RequestCraftCancel` double-enqueue**: the validate-in-handler / enqueue-effect split lets two cancels in one Heartbeat both pass validation (caller still in `crafters`) and both enqueue → double-drain of a possibly-cleared session. No de-dup on `{playerId, scope}` specified.
7. `[systems]` **`BEACON_HALF_LIFE` R4-1 registry edit is UNAPPLIED** — entities.yaml range remains [45,180]s (a "TIGHTENING" note, not an executed edit), so the G.6 derived window can be 24.6s; OQ.14 is marked CLOSED but the guard is not in place and there is no Crafting-side init assertion on the half-life.

**Economy / fantasy (game-designer MAJOR case):**
8. `[game][economy]` **Group-B bunker fix is taxed, not closed.** The in-window emission fires only on *voluntary* canister use; a squad that holds silently near the beacon without breathing is untouched, and the actual structural fix lives in two unwritten GDDs. The F.4 RM inequality has two undefined operands (`canister_restore`, `OXYGEN_DRAIN_BC4_FLOOR`) and cannot be evaluated now.
9. `[economy]` **Inverse degenerate** ("never use canisters in BC4, tank oxygen damage") is flagged in G.4 but has **no closing AC**; structurally possible at the default 0.18.
10. `[game]` **Scatter-defeat feedback trap** — continuous in/out-radius HUD vs a single-tick window-end win evaluation; kiting is implicitly permitted (members may leave/re-enter) but punished at one frame; hold-the-line-vs-return-before-timer intent undefined.
11. `[game]` **Anchor "deliberately 45s < 49s" is false across ED's range** — at `BEACON_HALF_LIFE = 64s` the window is ~35s < the 45s Anchor lifetime, making it the full-window sensor the design claims to avoid.

**UX:**
12. `[ux]` **≤4-surface BC4 cap breached** — surface 5 (Coil Billboard) + surface 9 (Anchor chevron) are not on the UI.5 item-7 suppress-list and can co-exist with surfaces 13/11/4 during BC4; no priority/suppression rule for them.
13. `[ux]` **"Merge surface 8 into 13" directional semantics undefined** — whether the merged element carries a direction vector is unspecified, so the scatter-defeat "never unsignalled" promise for a scattered off-screen player is unverifiable; tap-hold release-to-cancel feedback unspecified on all three platforms.

### Recommended (selected)
- `[network]` Document the same-tick canister-emission-on-victory-tick disposition; give `OnBeaconHoldStateChanged` a concrete re-arm bound (currently a 60/s flood is possible); lock `OnOxygenPulseRequest` as fire-and-forget or H.80's yield-safety guarantee breaks for `RequestUseItem`.
- `[economy]` MINERAL is near-dead in the oxygen-heavy loadout (only the Coil consumes it off-Beacon) — update OQ.15 honestly rather than "structurally resolved"; provide a provisional `canister_restore` so the F.4 inequality is at least directionally evaluable.
- `[qa]` H.39 gives no concrete `_clock` for non-default thresholds; H.38 Stage-1 mislabeled P2; H.39 has no priority tag; add `_enqueueDeparture` + a position-injection seam to C.16; add the "stays-in-radius fires once" negative AC for H.94; add a seam-integrity AC (`_enqueueDeparture` ≡ a real `Humanoid.Died`).
- `[gameplay]` Specify the Coil "until next bench visit" expiry mechanism for non-crafters; resolve the C.7.5-vs-H.21 trip-vs-lifetime contradiction; define `estimatedCompletionTime`; enumerate the `OnCraftRejected` reason set as a closed enum; cite the `LIGHT_PULSE_INTERVAL` source in H.37.
- `[game]` OQ.9 (unnamed bench-open RemoteEvent) has now persisted all 8 rounds.

### Specialist Disagreement (adjudicated)
game-designer = MAJOR vs the other six = NEEDS REVISION. The CD adjudicated **MAJOR**, but on *methodology* grounds — not the game-designer's bunker case (which is a legitimate forward obligation gated on RM/PA, not a hard blocker). The six NEEDS-REVISION votes are correct that each defect is locally closeable; they are wrong that the defects sum to NEEDS REVISION, because the binding question at round 8 is whether the document's **self-verification can be trusted** — and the mandated schema-completeness sweep self-certified as clean while missing its own target class (`_pendingDepartures` absent from schema). Network's "authority chain SOUND" is a constraint the fix satisfies, not a counter-verdict.

### Senior Verdict (creative-director)
Round-7 **repeated the root-cause pattern**: all three of its own additions (`windowAliveInRadius`, `OnBeaconHoldStateChanged`, `_enqueueDeparture`/`_pendingDepartures`) introduced fresh mechanism-implicit / schema-omission defects — structurally identical to how the R4-5 tie-break fix created the round-6 alive-set gap. The schema-completeness sweep failed the same way the round-3 reconciliation sweep did: a self-administered checklist self-certified as clean. Group-B is taxed-and-relocated, not closed. The authority/attribution chain remains SOUND and was protected. Verdict held at **MAJOR REVISION NEEDED** on self-verification methodology.

### Recommended next-step sequence (CD)
1. **Stop adding self-administered checklists** — they self-certify and have now failed twice (round-3 reconciliation sweep, round-7 schema sweep).
2. **Invert the authoring order**: author the schemas + state model FIRST (every queue/field/predicate named in C.10 before any rule references it), then write the rules against the locked schema.
3. **Fresh-agent build-from-artifact gate**: hand a subagent ONLY the schemas + state machines and ask it to implement the BC4 Heartbeat handler + the departure drain. Every field it has to invent is a confirmed omission — this catches the schema-omission class that self-checklists miss.
4. Account for the live cross-GDD blockers: ED owes the unapplied `BEACON_HALF_LIFE`→[64,128]s registry edit (R4-1); RM + PA are unwritten and the economy / aid-necessity is gated on them; PC is in MAJOR REVISION. The Group-B economy items (8-9) and the fantasy items (10-11) cannot fully close until those land — fence them explicitly as forward obligations rather than re-litigating them each round.
5. **DO NOT predict APPROVED for the next round.**

### Files referenced
- Target: `design/gdd/crafting-and-items.md` (round-7 authoring pass; ~1958 lines; NOT committed). Load-bearing: `windowAliveInRadius` no-store + undefined alive-predicate (C.10), `OnBeaconHoldStateChanged` boundary-cross contradiction (C.14), C.10 schemas missing `_pendingDepartures`, C.16 seam table missing `_enqueueDeparture`.
- Cross-cited still-blocking: `player-controller.md` (MAJOR REVISION round-6 — T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed` / all-dead contracts unverified-until-PC); `ecological-disturbance.md` (owns the derived window; owes the unapplied R4-1 `BEACON_HALF_LIFE`→[64,128]s registry edit); Not-Started + load-bearing for Group-B: `resource-management.md`, `predator-ai.md`; also Not-Started: `resource-node.md`, `hud.md`.
- Registry: `design/registry/entities.yaml` (`BEACON_HALF_LIFE` still ranged [45,180]s with a tightening NOTE, not an executed edit).

---

## Round-9 Authoring Pass Applied — 2026-06-03 — NOT YET RE-REVIEWED

**This is a patch record, not a review verdict.** It applies the round-8 CD remedy via an authoring session: **invert the authoring order (schema + state model FIRST), then reconcile rules against the locked schema, then run a fresh-agent build-from-artifact gate** — explicitly **replacing the self-administered checklist** that self-certified clean and missed its own target class in rounds 3 and 7. The next step is a **round-10 full `/design-review`** as the closure gate. **Do NOT treat this entry as APPROVED. Do NOT predict APPROVED for round-10.**

**Design decisions (user-approved this session, 4-tab widget):** Blocker #1 hold-state → **add a named `_windowPrevInRadius` prev-tick field** (edge-detection, presentation-only); Blocker #3 alive-predicate → **server-authoritative `aliveMembers` set** (mutated only via the `_enqueueDeparture` drain + respawn); Blocker #10 kiting → **window-end-only evaluation, kiting allowed, HUD advisory**; Blocker #11 Anchor → **fix Section B prose range-honest** (no mechanical change). User approved the full changeset including the **single-decision-point wipe ownership** change (Blocker #5).

### Resolution by round-8 blocker

| Round-8 blocker | Round-9 resolution |
|---|---|
| **#1** `OnBeaconHoldStateChanged` crossing-detection needs cross-tick state C.10 forbade storing | New named `RunSession._windowPrevInRadius` set (C.10) — edge-detection by set-difference, presentation-only, **walled off from the win path** (the win snapshot stays un-stored/per-tick). `{}` at BCT3; cleared on any BC4 exit. H.94 now testable via the new `_memberPosition` seam. |
| **#2** `_pendingDepartures` absent from schemas; `_enqueueDeparture` absent from C.16 | Both queues NAMED with full lifecycle (create/append/drain/discard) — `RunSession._pendingDepartures` (window scope) + `CraftSession._pendingDepartures` (bench scope), C.10. `_enqueueDeparture` + `_memberPosition` added to the C.16 seam table. |
| **#3** `windowAliveInRadius` alive-predicate undefined | "Alive" ≝ membership in the server-authoritative `RunSession.aliveMembers` (C.10) — decoupled from character teardown; the position read is guarded by membership. One unambiguous predicate (H.103). |
| **#4** D.1 + window comparison no backward-time-slew guard | `_clock()` contractually monotonic non-decreasing (production `max`-clamp wrapper) + `max(0, …)` defense-in-depth in D.1 and the C.9 window comparison; a slew freezes but never reverses progress and never denies a held victory (H.102). |
| **#5** BCT-DEFEAT wipe two firing paths, no mutual-exclusion | **Single decision point:** the BC4 Heartbeat handler owns all three outcomes (survived/scatter/**wipe**), guarded by the idempotent `runOutcomeResolved` latch; wipe now fires `OnBeaconWindowFailed(reason="wipe")`; PC's all-dead path is authoritative only outside BC4. `OnBeaconWindowFailed.reason ∈ {scatter,wipe}` (C.9/C.14/C.15/F.4; H.103). |
| **#6** `RequestCraftCancel` double-enqueue | `_enqueueDeparture` is idempotent per `{playerId, scope}` — a same-Heartbeat double-cancel enqueues once, drains once (C.8/C.10; H.104). |
| **#7** `BEACON_HALF_LIFE` R4-1 registry edit unapplied + no Crafting init assertion | Crafting-side **fail-fast init assertion** (G.6/H.105): refuses to start if the derived window ∉ [35,70]s — so an unapplied ED edit can't reach a live run. The authoritative range edit stays ED's fenced forward obligation (ED-owned constant; coordination rules forbid Crafting changing it unilaterally); entities.yaml note records the guard. |
| **#8** Group-B bunker fix taxed, not closed; F.4 RM inequality has undefined operands | **Fenced** explicitly as RM+PA forward obligations (per CD direction — stop re-litigating); provisional `canister_restore ≈ 4–6 s` added so the F.4 RM inequality is directionally evaluable. |
| **#9** Inverse degenerate ("never breathe, tank damage") has no closing AC | F.4 RM contract extended to close BOTH over-supply AND tank-the-damage; H.106 (Integration, unverified-until-RM). |
| **#10** Scatter-defeat feedback trap / kiting intent undefined | **Window-end-only** evaluation locked; kiting in/out allowed; HUD in/out indicator is **advisory** (UI.1 surface 13). |
| **#11** Anchor "deliberately 45s < 49s" false across ED's band | Section B prose rewritten range-honest — the 45 s lifetime is a sensor property, not tuned to the window; the single-shot rule (not the lifetime) is what prevents minimap behavior. No mechanical change. |
| **#12** ≤4-surface BC4 cap breached (surfaces 5, 9 not suppressed) | Surface 5 (Coil Billboard) + surface 9 (Anchor chevron) added to the BC4 suppress-list (UI.5 item 7, UI.1); ≤4 restored. |
| **#13** Merged surface-8→13 direction semantics + tap-hold release feedback undefined | Merged element carries the beacon-direction vector when out-of-radius (UI.1 surface 13); per-platform release-to-cancel feedback specified (UI.2; H.107). |

### The fresh-agent build-from-artifact gate (the CD's #3 remedy — REPLACES the self-checklist)
A `gameplay-programmer` subagent was given ONLY C.8/C.9/C.10/C.16 (+ D.1) and asked to implement the BC4 Heartbeat handler + departure drain, reporting every symbol it had to invent. **It returned 19 omissions + 3 contradictions.** Triage: ~10 were artifacts of the strict walling (constants/paths defined in deliberately-out-of-scope sections — G.6, C.11, E.8 — not real gaps); **7 were genuine schema-omission/ambiguity defects of the exact recurring class**, all fixed in-session: (#1) the position-**read** seam was unnamed → added `_memberPosition(playerId)` reader to C.16; (Contradiction-1) `_enqueueDeparture` window-scope predicate mismatched between C.8 ("window active") and C.10 ("participant AND active") → reconciled to "window active" + idempotent drain; the `dist3D` axis was ambiguous → pinned to 3D Euclidean; `_windowPrevInRadius` clear-on-exit wasn't enumerated in the transition tables → centralised in run-end cleanup; the service-level bench→session map was unnamed → added `_craftSessions`; (Contradiction-3) BCT5 didn't set `runOutcomeResolved` → added; the respawn re-add event was unnamed → named `OnSquadMemberAliveChanged` as a non-blocking PC forward obligation. **This is the validation of the methodology change: a self-administered checklist would have declared clean (it did, twice); the build-from-artifact gate caught the recurring class.**

### Counts reconciled
Recipes **4**, item types **4** (unchanged); VA moments **24** (unchanged); edge cases **30** (unchanged — fixes were schema/rule-level); ACs 93 → **99** (H.102–H.107); client-initiated RemoteEvents **7** (unchanged; `OnBeaconWindowFailed.reason` extended to {scatter,wipe}). New schema fields: `aliveMembers`, `RunSession._pendingDepartures`, `CraftSession._pendingDepartures`, `_windowPrevInRadius`, `runOutcomeResolved`, `_craftSessions`; new seams `_enqueueDeparture` / `_memberPosition` tabled.

### Files touched
`design/gdd/crafting-and-items.md` (primary — ~28 edits), `design/registry/entities.yaml` (Crafting init-guard note appended to `BEACON_HALF_LIFE`; ED's value/range left unchanged per coordination rules). **Not committed** (awaiting user instruction).

### Authority chain (protect — unverified this session, must be re-confirmed at round-10)
No edit touched the server-authoritative BCT3 (`beaconPlacerId` Emit) or BCT4 completion/attribution path. The win-condition reads `aliveMembers` (server-set) + `_memberPosition` (server-tracked) — no client-trust hole introduced. **Round-10's network-programmer must re-confirm SOUND** (the new `aliveMembers`/`runOutcomeResolved`/wipe-signal surface had no fresh-agent network adversary this round — the gate was a build-completeness gate, not a security gate).

### Next
**Round-10 full `/design-review`** (closure gate). **Do NOT predict APPROVED.** Still cross-GDD-pending: ED applies the `BEACON_HALF_LIFE`→[64,128]s registry edit (R4-1) — now backstopped by Crafting's H.105 init assertion; RM owes `OXYGEN_DRAIN_BC4_FLOOR` + `canister_restore` (F.4, H.106 fenced); PA owes `PREDATOR_BC4_MIN_COMMIT`; PC owes T8 wiring + `OnBeaconWindowFailed({scatter,wipe})` subscription + the new `OnSquadMemberAliveChanged` respawn signal.

---

## Review — 2026-06-03 — Verdict: NEEDS REVISION (round-10 closure-gate re-review)

**Scope signal:** L (verging XL — 6 dependencies, 4 unwritten with 2 load-bearing; 7 formulas; win-condition cross-cutting; multiple new-ADR obligations)
**Specialists:** game-designer, systems-designer, economy-designer, network-programmer, ux-designer, qa-lead, gameplay-programmer (build-from-artifact lens) + creative-director (senior synthesis) — full panel (the designated single closure gate after the round-9 schema-first authoring pass)
**Review depth:** full
**Prior verdict resolved:** Round-8 (13 blockers) + the round-9 schema-first authoring pass — **YES at the rule/schema level, verified.** The build-from-artifact gate's 7 fixes genuinely closed; the round-8 methodology-MAJOR concern is **resolved** (see CD verdict).

### Summary

**First non-MAJOR verdict in the document's 10-round history, and the first unsplit panel — all 7 specialists returned NEEDS REVISION (none MAJOR, none APPROVED).** 9th consecutive non-APPROVED, but the trajectory inverted: the defect *class* moved from "the design/mechanism is wrong/absent" to "the mechanism is specified but a handful of *seams* the round-9 build-from-artifact gate did not cover are still implicit." The round-9 additions did re-introduce the recurring fix-creates-next-gap pattern three times — but at seams the BC4-scoped gate provably excluded (the cross-system PC boundary; outside-BC4 lifecycle; AC-vs-prose), not inside a sweep that self-certified clean. **Positive finding to PROTECT (re-confirmed, no regression):** network-programmer affirmed the win-condition **authority + attribution chain is SOUND — no forge path**, including against the new round-9 surface (`aliveMembers`/`runOutcomeResolved`/wipe-signal/`_memberPosition` open no client-trust hole; `beaconPlacerId` server-set; Emit uses placer not activator).

### Blocking convergences (independent lenses on the same defect — the most reliable signal)

1. **`aliveMembers` not maintained outside BC4 / across respawn — TRIPLE-lens** *(network B-NET-3, gameplay BLOCK-1, systems BLOCK-4)*. A pre-activation death (or respawn) never drains from `aliveMembers` (the RunSession-scope enqueue is gated on "window active"), so the first `windowAliveInRadius` snapshot can count a dead player. **Fresh defect created by round-9's own "window active" reconciliation.** Fix: widen the RunSession-scope enqueue to any active run (idempotent drain already makes over-enqueue safe), or specify a separate pre-BC4 drain.
2. **`runOutcomeResolved` cross-system latch timing vs PC — DOUBLE-lens** *(network B-NET-1, gameplay BLOCK-2)*. The latch is set inside the Heartbeat handler, but PC's all-dead `RunEnded(defeat)` can fire synchronously from `Humanoid.Died` *before* the latch is written → same-frame double-cleanup. The "single decision point" claim needs an explicit protocol (PC checks the latch, or Crafting pre-sets it in the callback). Fresh, from round-9 Blocker #5.
3. **H.89 wipe reconciliation miss — DOUBLE-lens** *(qa REC-1, systems)*. Round-9's Blocker #5 changed wipe to fire `OnBeaconWindowFailed(reason="wipe")` but H.89 variant (c) still reads "neither signal fires" — the named reconciliation-miss class, recurring, introduced by the round-9 fix itself.
4. **`OnBeaconHoldStateChanged` flood/hysteresis — DOUBLE-lens** *(network B-NET-2, ux UX-R2)*. A player at the 30-stud boundary with normal jitter floods ~120 events/s × squad against the bandwidth budget; no re-arm/hysteresis knob exists (G.6).
5. **Advisory-vs-evaluative HUD feedback trap — DOUBLE-lens** *(game-designer B3, ux UX-B3)*. Continuous in/out indicator vs a single-frame window-end win check; "HOLD THE BEACON" LOSE-legibility + escalation cue unspecified.

### Other blocking items (single-lens)

- **[systems BLOCK-3]** `DAMPENER_REDUCTION` 0.70 ceiling is only safe IF PC applies the D.6a Stage-2 stationary factor; until PC lands, a moving Coil player isn't silenced as the tuning rationale claims — needs an interim cap (≤0.56) or flagged PC-dependency.
- **[economy EC-1/EC-2/EC-3]** F.4 RM inequality directionally **violated** at the short-window end (10-stack 40 s > 35 s window at provisional `canister_restore`); OQ.15 "structurally resolved" overclaims (Anchor re-weight *reduced* MINERAL demand); **new "scatter-to-breathe" line** — in-window canister emission fires at the *scattered* player's position, possibly drawing the predator off the beacon (owes a CD design ruling on beacon-vs-player emission position).
- **[qa BLOCK-1/2/3]** AC-coverage gaps for the round-9 mechanisms: H.94 missing the "stays-in-radius fires zero times" negative; no AC for the `runOutcomeResolved` "second terminal path is a no-op"; no seam-integrity AC that `_enqueueDeparture` ≡ a real `Humanoid.Died`/`PlayerRemoving` (production-divergence class).
- **[game-designer B1]** 2-player squad (minimum supported config) has bench cap=1 → Section B's "the bench is a coordination problem / someone has to choose" fantasy is false for it.
- **[ux UX-B1/B2]** surface-11 multi-instance banner density on iPhone SE (the ≤4 cap is surface-ID, not density); reduced-motion variants for the 3 Crafting pulsing BC4 surfaces never affirmatively required (H.95 closes WCAG 2.3.1 at default timing only).

### Recommended

Section B honesty notes for RM/PA-contingent fantasy beats (game B2, R1); RemoteEvent-vs-`_step` ordering contract (systems BLOCK-2); `_windowPrevInRadius` cleanup enumeration (systems BLOCK-1 — *gameplay-programmer partially refuted: the E.8 path is named*); Anchor short-window planning implication (game B4); in-window-canister-on-victory-tick disposition (network B-NET-4); `OnOxygenPulseRequest` fire-and-forget confirmation for H.80 (network R-NET-3); `_clock()` monotonic-wrapper in the C.16 production-default column (systems REC-2); OQ.9 bench-open RemoteEvent unnamed after 10 rounds.

### Specialist note (positive dissent — protect)

network-programmer: **AUTHORITY-CHAIN STATUS: SOUND** — re-confirmed against the new round-9 surface; no forge path; no client-trust hole. Any fix MUST NOT regress the server-authoritative completion/attribution path — authority wins over blocker-closure in any conflict.

### Senior Verdict (creative-director)

**The round-6/8 methodology-MAJOR arc is RESOLVED — for the first time.** The fresh-agent build-from-artifact gate is a structurally different, **non-self-certifying** mechanism (it attempts construction and fails loudly rather than asking the author "did you remember X?"). It caught 100% of its in-scope target class — the 7 schema omissions a self-checklist missed twice (rounds 3, 7). The recurrence (3 fresh instances of the named class) is confined to seams the gate's scope **provably excluded** — that is an *under-scoped* gate (fixable by widening scope), not an *untrustworthy* one, which is the discriminator that separates this from round-7 (where the class sat *inside* the sweep's own scope while it reported clean). The CD explicitly rejected a "zero-downstream-defects = converged" bar as unfalsifiable. Held at **NEEDS REVISION** (the unanimous panel read, upheld, not overridden).

### Recommended next-step sequence (CD)

1. **Round-11 = an AUTHORING pass** (not a full panel) closing the convergences + the single-lens blockers, plus a **CD design ruling on EC-3** (beacon-vs-player emission position for the in-window canister counter).
2. **WIDEN the proven build-from-artifact gate** by the three excluded seams: hand the build-agent the **PC contract** (cross-system timing) + the **full-run lifecycle** (not only BC4) + an explicit **AC-vs-prose reconciliation** pass for any mechanism the authoring changes.
3. Add **one narrow network security gate** to re-confirm the authority chain against the round-11 edits (per the round-9 protect note).
4. The full 7-spec panel returns at **round-12** as the closure gate. **DO NOT predict APPROVED for round-11.**
5. Fence (do not re-litigate): the RM/PA/PC/ED forward obligations (F.4) — these cannot fully close until those GDDs exist; the economy aid-necessity claim stays a falsifiable AC-bearing forward obligation.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-9 authoring pass; 2020 lines; NOT committed)
- Cross-cited: `design/gdd/player-controller.md` (round-6 MAJOR — T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed` / all-dead / the new `OnSquadMemberAliveChanged` respawn contracts unverified-until-PC); `design/gdd/ecological-disturbance.md` (owns `BEACON_HALF_LIFE`; owes the R4-1 `[64,128]s` registry edit — backstopped by H.105); Not-Started + load-bearing: `resource-management.md`, `predator-ai.md`; also Not-Started: `resource-node.md`, `hud.md`
- Registry: `design/registry/entities.yaml` (`BEACON_HALF_LIFE` Crafting init-guard note present; ED value/range unchanged per coordination rules)

---

## Round-11 Authoring Pass Applied — 2026-06-04 — NOT YET RE-REVIEWED

**This is a patch record, not a review verdict.** It applies the CD's round-10 sequencing: an **AUTHORING pass** closing the round-10 convergences + single-lens blockers (plus a CD design ruling on EC-3), then the **WIDENED build-from-artifact gate** (PC contract + full-run lifecycle + AC-vs-prose) + a **narrow network security gate**. The next step is the **round-12 full `/design-review`** (the full 7-spec panel returns as the closure gate). **Do NOT treat this entry as APPROVED. Do NOT predict APPROVED for round-12.**

**Design decisions (user/CD-approved this session, 3-tab widget):** **EC-3** → in-window Oxygen Canister emission fires at **`RunSession.beaconWorldPosition`** during BC4 (not the using player's position) — structurally forecloses the scatter-to-breathe bait; **DAMPENER_REDUCTION** → **interim ceiling 0.56** (default 0.50) until PC's D.6a Stage-2 lands, 0.70 the post-PC ceiling; **game-B1** → **prose-honesty fix** (2-player bench coordination is "who crafts / who watches"; the spike-vs-speed multi-crafter choice is a 3–4-player decision), keep cap=1.

### Resolution by round-10 blocker

| Round-10 blocker | Round-11 resolution |
|---|---|
| **Conv #1** `aliveMembers` stale outside-BC4 / across respawn [TRIPLE] | RunSession-scope `_enqueueDeparture` + drain **widened to the whole run** (death/disconnect drains `aliveMembers` every Heartbeat from RunStarted, not only during BC4), so the first BC4 snapshot is accurate. Respawn re-add is now load-bearing → PC's `OnSquadMemberAliveChanged` **upgraded to BLOCKING** (F.4/C.12), with an interim self-sourced `CharacterAdded` re-add until PC lands. C.8/C.9/C.10 + new **H.108** (split Logic/Integration). |
| **Conv #2** `runOutcomeResolved` cross-system latch vs PC [DOUBLE] | Explicit mutual-exclusion protocol: **PC suppresses its all-dead `RunEnded(defeat)` for the whole post-activation lifecycle** (gate on `beaconActivated == true` alone — widened by build-gate A4 from the racy `&& !beaconWindowSurvived`); the `runOutcomeResolved` latch is defense-in-depth. C.9/C.12.1/F.4 + new **H.109**. |
| **Conv #3** H.89 wipe reconciliation [DOUBLE] | Reconciled the stale "wipe → PC's all-dead path, no Crafting signal" in **five** places the AC-vs-prose pass found: H.89 variant (c), E.24, H.76, C.12.1, **and F.2 PC row** → all now `OnBeaconWindowFailed(reason="wipe")` per round-9 C.9 single decision point. |
| **Conv #4** `OnBeaconHoldStateChanged` flood/hysteresis [DOUBLE] | New knob **`BEACON_HOLD_HYSTERESIS` (~3 studs)**: Schmitt band on the *presentation* crossing signal (enter `<= R`, leave `> R + HYST`); the **win snapshot stays strict `<= R`** (walled off). C.9/C.10/C.14/C.15/UI.1 + H.94 extended (negatives). |
| **Conv #5** advisory-vs-evaluative HUD trap [DOUBLE] | Window-end **escalation cue** (knob `BEACON_HOLD_ESCALATION_LEAD = 10 s`): out-of-radius + final lead → "HOLD THE BEACON" escalates with direction vector; client-derived from `OnBeaconActivated.windowDurationSeconds` + `OnBeaconHoldStateChanged`. UI.1 surface 13 / C.14. |
| DAMPENER 0.70 PC-dep [systems BLOCK-3] | G.5 range → interim **0.30–0.56**; D.6/D.6a flag the silencing rationale as PC-Stage-2-dependent. |
| Economy EC-1 (RM inequality violated short-window) | F.4 RM inequality must hold at the **shortest 35 s window**; provisional `canister_restore` tightened to **≈ 3 s** (10-stack ≈ 30 s < 35 s); `OXYGEN_DRAIN_BC4_FLOOR` calibrated vs 35 s. F.4/OQ.13/H.106. |
| Economy EC-2 (OQ.15 overclaim) | OQ.15 softened: structurally *improved*, not "resolved"; MINERAL/RESONANT practical demand thin in the oxygen-heavy line; fenced on RM/PA. |
| Economy EC-3 (scatter-to-breathe) | **CD ruling: emit at beacon position** (above). C.6/C.11/E.32/H.93/C.2/G.4 + registry. |
| qa AC-coverage [BLOCK-1/2/3] | H.94 negatives (stays-in-radius / jitter fires zero); **H.109** (terminal no-op); new **H.110** (`_enqueueDeparture` ≡ real `Humanoid.Died`/`PlayerRemoving` seam-integrity). |
| game-B1 (2-player bench) | Section B prose-honesty (above). |
| ux UX-B1/B2 | Surface-11 **BC4 density cap** (≤ 2 concurrent banners, coalesce); **reduced-motion variants affirmatively required** for the 3 pulsing BC4 surfaces (UI.5 item 6/7 + new **H.111**). |

### The two round-11 gates RAN this session (both returned findings — all resolved in-session)

- **Network security gate (narrow — authority-chain non-regression):** returned **AUTHORITY-CHAIN STATUS: SOUND** against all five round-11 edit targets (EC-3 beacon-position emission, whole-run `aliveMembers` drain, `runOutcomeResolved`/PC-suppression, hysteresis presentation signal, BCT3/BCT4 core). 0 BLOCKING; 1 RECOMMENDED (make the interim `CharacterAdded` re-add idempotency explicit) — **applied**. No forge path / client-trust hole introduced. *(The gameplay-programmer subagent type failed to deliver its report twice this session — a harness delivery issue specific to that agent type; the build-from-artifact gate was run via a general-purpose fresh agent instead, which delivered fully.)*
- **Widened build-from-artifact gate (PC contract + full-run lifecycle + AC-vs-prose):** a fresh agent given only the schema/state-machine/contract sections returned **16 findings** (6 omissions, 3 contradictions, 4 ambiguities, 3 AC-vs-prose mismatches) — **all genuine, none artifacts of out-of-scope walling, all fixed in-session.** The load-bearing catches: **C3** — the whole-run fan-out (Conv #1) would have let a benign `RequestCraftCancel` drain `aliveMembers` and fire a false wipe → **reason-gated the alive scope to `{death, disconnect}` only** (new **H.112**); **A4** — the PC suppression gate `&& !beaconWindowSurvived` opened a post-victory defeat-race → widened to `beaconActivated == true` alone; **C2** — a PC-owned outside-BC4 `RunEnded` never latched `runOutcomeResolved` → added Crafting's **`RunEnded` subscription** that latches + halts the whole-run drain (new **H.113**); **O2/O3/A1** — pinned the **single `_step` Heartbeat connection** + drain-exactly-once ordering (snapshot-before-drain on BC4 ticks); **O1** — added the **`RunStarted` init contract** (roster source + field-population order); **O5** — the Conv #5 escalation was unbuildable (no published window-end) → added **`windowDurationSeconds`** to the activation payloads. C1 (alive-set invariant), O4 (interim/canonical supersession switch), A2 (dead member not fired as "out of radius"), A3 (respawn position-validity), O6 (`OnCraftRejected` catch-all channel), M1/M2 (H.110 re-add exemption / H.108 split) all fixed.

### Counts reconciled
ACs **99 → 105** (H.108–H.113); knobs **+2** (`BEACON_HOLD_HYSTERESIS`, `BEACON_HOLD_ESCALATION_LEAD`, G.6); DAMPENER_REDUCTION range → interim 0.30–0.56; edge cases **30** (unchanged); VA moments **24** (unchanged — Moment 28 position note only); recipes **4** / item types **4** (unchanged). New RemoteEvent payload field `windowDurationSeconds` on `OnBeaconActivated`/`OnEscapeBeaconActivated`.

### Cross-GDD forward obligations (updated/created)
- **PC (round-6 MAJOR):** `OnSquadMemberAliveChanged(playerId, isAlive)` respawn signal **now BLOCKING** (whole-run drain makes the re-add mandatory); **BC4 all-dead suppression BLOCKING** (gate `beaconActivated == true`, BCT3→`RunEnded`); maps `OnBeaconWindowFailed{scatter,wipe}` → defeat; T8 ← `OnBeaconWindowSurvived`. Crafting also subscribes to PC's `RunEnded` (C2).
- **RM:** `canister_restore ≈ 3 s` provisional; `OXYGEN_DRAIN_BC4_FLOOR` calibrated at the 35 s short-window; inequality + inverse-degenerate ACs (H.106, unverified-until-RM).
- **ED:** `BEACON_HALF_LIFE` → `[64,128] s` registry edit (R4-1, backstopped by H.105); WCAG flora flash cap.
- **PA:** `PREDATOR_BC4_MIN_COMMIT` (F.4).

### Files touched
`design/gdd/crafting-and-items.md` (primary — ~45 edits; header/Status updated round-7→round-11), `design/registry/entities.yaml` (`MAGNITUDE_CANISTER_INWINDOW_USE` beacon-position note; `DAMPENER_REDUCTION` interim-cap note; new `BEACON_HOLD_HYSTERESIS` + `BEACON_HOLD_ESCALATION_LEAD` constants). **Not committed** (awaiting user instruction).

### Next
**Round-12 full `/design-review`** (the full 7-spec panel returns as the closure gate, per the round-10 CD prescription). **Do NOT predict APPROVED for round-12.** Fenced (do not re-litigate): RM/PA/PC/ED forward obligations (F.4).

---

## Review — 2026-06-04 — Verdict: NEEDS REVISION (round-12 full-panel closure gate)

**Scope signal:** L (verging XL — 6 dependencies, 4 unwritten with 2 load-bearing; 7 formulas; win-condition cross-cutting; multiple new-ADR obligations; 113 ACs)
**Specialists:** game-designer, systems-designer, economy-designer, network-programmer, ux-designer, qa-lead, gameplay/build-from-artifact lens (via general-purpose — the gameplay-programmer agent type's prior delivery failures), creative-director (senior synthesis) — full 7-spec panel, the designated single closure gate after the round-11 authoring pass + two gates.
**Review depth:** full
**Prior verdict resolved:** Round-10 convergences + the round-11 authoring pass — **YES at the rule/schema level, verified.** All 5 round-10 convergences (aliveMembers whole-run drain, runOutcomeResolved/PC-suppression, H.89 wipe reconciliation, OnBeaconHoldStateChanged hysteresis, advisory-vs-evaluative HUD escalation) + the EC-3/DAMPENER/game-B1 rulings genuinely closed. But round-11's OWN edits re-opened the recurring reconciliation-miss class a 3rd time, at seams the widened build-from-artifact gate's scope provably excluded.

### Summary

**Unanimous NEEDS REVISION — all 7 specialists (none MAJOR, none APPROVED). 12th consecutive non-APPROVED; 3rd consecutive non-MAJOR.** The CD synthesis: **converging decisively, with KITING as the one genuine non-reconciliation exception.** The four blocking convergences are all one-line-to-one-paragraph fixes at section seams the round-11 gate did not cover; the recurring reconciliation-miss class held its *count* but its per-occurrence blast radius collapsed an order of magnitude (round-2/3 were cross-section rule contradictions; round-12 are two position-args, three field-enumerations, one guard-hoist). The round-6/8 methodology-MAJOR arc stays resolved — the build-from-artifact gate is non-self-certifying, caught its 16 in-scope round-11 findings, and leaked only at its scope edge (under-scoped, not untrustworthy). **Positive finding to PROTECT (re-confirmed 4th consecutive round, no regression):** network-programmer — **AUTHORITY-CHAIN STATUS: SOUND**; no forge path against the full round-11 surface (EC-3 beacon-position emission, whole-run aliveMembers drain, runOutcomeResolved/PC-suppression, hysteresis band all open no client-trust hole; `usingPlayerId` attribution correct; client beacon position still a clamped hint). Authority wins over blocker-closure in any conflict.

### Blocking convergences (independent lenses on the same defect — most reliable signal)

1. **C.15 `RequestUseItem` validation cell CONTRADICTS C.6/C.11/E.32/H.93 on in-window Canister emission position — QUAD-lens** *(systems BLOCK-3, build-from-artifact Finding-2, qa-lead, + VA twin)*. C.15 still says "at the using player's server-tracked position"; the round-11 EC-3 ruling (everywhere else) says `RunSession.beaconWorldPosition`. An implementer building the handler from the C.15 surface table **reintroduces the scatter-to-breathe exploit EC-3 closed.** VFX twin: VA.3 Moment 28 prose says player-position while VA.4 says beacon. **The cleanest fresh fix-creates-next-gap instance** — EC-3 reconciled in C.6/C.11/E.32 but missed in the C.15 handler cell. Attribution/authority itself untouched (only the `position` arg is wrong) — fix changes ONLY the position arg.
2. **`windowDurationSeconds` (round-11 O5 fix) incompletely propagated — TRIPLE-lens** *(network ×2, systems BLOCK-4, qa-lead)*. C.14/C.15 carry it; C.9 BCT3 normative side-effects column omits it from the fired payload, UI.3 omits it, and **no AC asserts `windowDurationSeconds == BEACON_SURVIVAL_WINDOW`.** Built from C.9 → truncated payload → client countdown + Conv-#5 escalation break, all sprint-gate ACs stay green.
3. **`runOutcomeResolved` guard-scope contradiction — DOUBLE-lens** *(systems BLOCK-1/2, build-from-artifact Finding-1 "sharpest")*. Build-gate C2 (round-11) added "Crafting ceases ALL `_step` run-scope work on RunEnded" (H.113), but the pre-existing C.9 guard is "first statement of the BC4 segment" only. Built from C.9, the non-BC4 bench-progress + alive-drain segments keep running against an already-ended run (pre-activation PC all-dead, or the between-ticks Knit-subscription gap). Fix: hoist the guard to the top of `_step`.
4. **Bench BT3 completion on the BC4-terminal tick unadjudicated — DOUBLE-lens** *(systems BLOCK-5, build-from-artifact Finding-4)*. A non-Beacon craft completing at `_step` segment (1) on the same tick the BC4 segment (3) fires a terminal: is BT3 suppressed, or does it grant an item + emit + fire `OnCraftCompleted` racing the win/defeat signal? Undefined.

### Headline finding (design-level — NOT a one-line fix)

- **KITING [game-designer B1]** — the single-frame, window-end-only alive-and-in-radius check makes the optimal line "activate, scatter to safe geometry for ~38 s, regroup for the final ~10 s," recovering the scatter-dominance the round-3 proximity-hold was created to kill. **Not an exploit — game-legal optimal play that directly contradicts Section B's "hold the line."** Requires a CD design ruling on a sustained-presence mechanism, not a transcription fix. **ux-B12-2 is bound to it** (the 3-stud hysteresis band lets a player shown "in-radius" at 32 studs still LOSE — an affirmatively-wrong HUD signal violating the design's own "scatter-defeat is never unsignalled" promise; resolve via the same ruling).

### Other blocking (single-lens)

- **[ux UX-B12-1]** Surface-13 renders up to 5 elements incl. up to 4 per-member hold-rows on a 375pt iPhone-SE screen with no row cap/collapse rule; the ≤4-surface cap is by surface-ID — `/ux-design` has no locked constraint.
- **[economy EC-1a/EC-1b/Sanity-1]** F.4 RM inequality conflates squad-pool item count with per-member oxygen coverage (un-writable as a deterministic AC); no `canister_restore < 3.5 s` ceiling (RM could pick a re-violating value); C.2 18-gather sanity check (2 Canisters) inconsistent with the EC-1 full-stack arithmetic (understates grind ~1.5–2×, mis-feeds LD node density).
- **[qa-lead]** H.37/H.22 time-dependent ACs don't cite the C.16 `_clock` seam (invite forbidden `task.wait`); DAMPENER 0.56 interim cap has no covering AC.

### Recommended (deferred to the round-13 authoring pass)

VA.3 Moment 28 ↔ VA.4 VFX-position reconciliation; `OnBeaconWindowFailed` payload typed `string` (C.15) vs `"scatter"|"wipe"` union (C.12/C.14); make the "queue-emptied-every-tick ⇒ respawn-safe" invariant explicit (systems REC-3) + run-end `_craftSessions` BT5 sweep unspecified (systems REC-5); `RequestUseItem` zero-yield vs a possibly-yielding RM restore (network); H.110 BLOCKING/advisory split; reconnect-during-BC4 AC + `BEACON_HOLD_HYSTERESIS` bandwidth-bound AC (network); Signal Anchor window-value prose overstates a single-shot sensor vs a straight-line committed predator (game R1); Coil bench-visit-expiry anticipatory cue (game R4); `OnRunStarted` vs `RunStarted` method-vs-signal naming (build-from-artifact); out-of-bench-range departure `reason` string literal unnamed (build-from-artifact).

### Specialist Disagreements (adjudicated by creative-director)

- **Aid-suite-necessity IOU** — game-designer treated it as a design blocker; economy-designer as a legitimately-fenced forward obligation. **CD ruling: economy is correct — FENCED** (claim gated on two unwritten GDDs; `open ≠ design-closure blocker`). The economy *precision* items (EC-1a/b, Sanity-1) are in-scope; the *closure* of the aid-necessity claim is fenced.
- **KITING severity** — **CD ruling: a genuine round-12 design finding and the headline of the round, but NEEDS REVISION not MAJOR** — a flaw in one rule's implementation of a sound thesis, with a bounded fix space, not a flaw in the thesis.

### Senior Verdict (creative-director)

Converging decisively. The reconciliation-miss class re-opening a 3rd time is real but its severity is collapsing toward zero per occurrence; the recurrence is confined to seams provably outside the round-11 gate's scope (within-section validation cells, side-effect columns, the H.113↔C.9 interaction) — the signature of a fixable under-scoped gate, not an untrustworthy design. Methodology-MAJOR arc stays resolved (round-10 determination strengthened, not weakened). KITING is the most important finding because, unlike the reconciliation misses, it requires a design ruling. Held at **NEEDS REVISION**.

### Binding CD rulings / next-step sequence (user may override)

- **Round-13 Step 1 — CD design ruling on KITING BEFORE authoring.** Three bounded mechanisms to present: **(a)** sustained-presence integral (cumulative in-radius ≥ X% of window); **(b)** fail-fast "line breaks" (window fails if the hold radius empties of all alive members for > grace seconds) — *CD-recommended*: most directly restores the round-3 intent, trivially HUD-honest (binary line state, dissolves ux-B12-2), cheapest to make server-authoritative; **(c)** periodic check-in with a grace budget. User's call (a more forgiving for the casual co-op profile).
- **Step 2 — ONE authoring pass** closing KITING (per the ruling) + ux-B12-2 (bound to it) + the 4 convergences + qa AC seam-citations + the economy precision items + ux-B12-1 surface-13 row cap. The pass MUST carry an explicit **reconciliation-fanout checklist that includes within-section validation cells and normative side-effect columns** — the two seam-types that leaked this round.
- **Step 3 — round-13 gates (NOT a full panel):** a **widened build-from-artifact gate** (general-purpose fresh agent) explicitly scoped to include within-section table/prose desync + side-effect-column completeness; **a narrow network gate** on the KITING server-authority surface (new per-tick in-radius state — confirm no forge regression). Reserve the full 7-spec panel for round-14.
- **Authority chain is a hard constraint on every fix.** Conv-1 must change only the position arg (not `usingPlayerId`); the KITING mechanism's in-radius determination must stay server-authoritative (no client "I'm in radius" claim). Authority wins over blocker-closure.
- **DO NOT predict APPROVED for round-13** — the KITING mechanism choice could itself open new HUD/economy/authority seams a 13th round must catch.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-11 authoring pass; ~2090 lines; NOT committed). Load-bearing defects: C.15 `RequestUseItem` cell (stale player-position), C.9 BCT3 side-effects (omits `windowDurationSeconds`), the C.9-local vs H.113 whole-`_step` `runOutcomeResolved` guard scope, the C.5.6a/C.9 BCT4 single-frame window-end check (KITING).
- Cross-cited still-blocking: `player-controller.md` (round-6 MAJOR — T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` contracts unverified-until-PC); `ecological-disturbance.md` (owns `BEACON_HALF_LIFE`; owes the R4-1 `[64,128]s` registry edit — backstopped by H.105); Not-Started + load-bearing for the fenced aid-necessity: `resource-management.md`, `predator-ai.md`; also Not-Started: `resource-node.md`, `hud.md`.
- Registry: `design/registry/entities.yaml` (`BEACON_HALF_LIFE` Crafting init-guard note present; ED value/range unchanged per coordination rules).

**User chose to STOP and revise in a separate session.** Branch `crafting-round2-patch`; rounds 3–12 work all still NOT committed.

---

## Round 13 — 2026-06-04 — AUTHORING PASS + BOTH NARROW GATES (a patch, NOT a verdict)
Scope signal: L (continuous-hold inversion of the win condition + a new buffered re-add seam)
Specialists: none (per the round-12 CD plan, round-13 = ruling → one authoring pass → two narrow gates, NOT a full panel; the full 7-spec panel is reserved for round-14)
Blocking items closed: all round-12 (4 convergences + KITING headline + ux/economy/qa single-lens) | Gate findings closed: build-from-artifact 1 BLOCKING + 2 IMPORTANT + 3 MINOR; network 3 MINOR
Prior verdict resolved: round-12 NEEDS REVISION → addressed by this authoring pass (verification deferred to the round-14 full panel)

**Executed the CD-prescribed round-13 sequence.**

**Step 1 — KITING design ruling (user):** of the three CD-offered mechanisms, the user chose **(b) fail-fast line-breaks** — the survival window now requires CONTINUOUS in-radius presence (was a single window-end check). User also chose two sub-options: a **~3 s regroup grace** (`BEACON_LINE_BREAK_GRACE`) so a knockback/jitter does not instantly lose, and **Conv-4 outcome-first** (the BC4 segment resolves before the bench tick, suppressing a same-tick BT3).

**Step 2 — one authoring pass (all round-12 blockers closed):**
- **KITING (game B1 headline)** — inverted to continuous-hold: every BC4 tick, an empty `windowAliveInRadius` snapshot while members are alive starts the `_lineBreakEmptySince` grace clock; staying empty for `BEACON_LINE_BREAK_GRACE` → scatter line-break defeat; a full wipe (`aliveMembers` empty) is immediate, no grace. Victory = window elapses while held. New knob `BEACON_LINE_BREAK_GRACE` (G.6 + registry), field `_lineBreakEmptySince`, signal `OnBeaconLineBreak` (strict squad-level HOLDING/BROKEN binary — dissolves ux-B12-2). The round-9 "advisory, kiting unpunished" framing (Blocker #10/Q3) is REVERSED — touched C.5.6a, C.8 `_step` order, C.9 (BCT3/BCT4/BCT-DEFEAT + the handler bullet), C.10 (schema/eval/invariants), E.24/E.27, C.14/C.15/UI.3 signals, UI.1 surface 13, UI.5 item 7, VA.3 Moment 26.
- **Conv-1** — C.15 `RequestUseItem` cell + VA.3 Moment 28 in-window canister position → `RunSession.beaconWorldPosition` (EC-3 reconciled; the position-arg-only fix, attribution untouched).
- **Conv-2** — `windowDurationSeconds` propagated through C.9 BCT3, C.12.1, UI.3, H.14; new H.116 asserts `== BEACON_SURVIVAL_WINDOW`.
- **Conv-3** — `runOutcomeResolved` guard hoisted to the very top of `_step` (C.8 ordering, C.10 field text).
- **Conv-4** — outcome-first ordering: the BC4 segment runs before the bench progress tick; a post-segment guard suppresses same-tick BT3.
- **ux UX-B12-1** — surface-13 collapses per-member hold-rows to an "N/M holding" count on 375pt; **UX-B12-2** dissolved by the strict squad-level binary.
- **economy EC-1a/1b/Sanity-1** — F.4 RM per-member-vs-pool clarified, `canister_restore < 3.5 s` ceiling stated; C.2 18-gather reconciled as illustrative-vs-floor-stress.
- **qa** — H.22/H.37 now cite the C.16 `_clock` seam; new H.117 (Dampener interim 0.56 cap config guard).
- ACs 105 → **109** (H.114 line-break grace, H.115 wipe-immediate-vs-scatter-grace, H.116 windowDurationSeconds, H.117 dampener cap; H.73/H.85/H.89 revised to the continuous model).

**Step 3 — both narrow gates (general-purpose agents; gameplay-programmer type still avoided per prior delivery failures):**
- **Network gate → AUTHORITY-CHAIN SOUND (5th round, PROTECT).** No BLOCKING/IMPORTANT. The continuous in-radius determination is fully server-authoritative (positions via the `_memberPosition` seam, never a client claim); `OnBeaconLineBreak` is pure server→client presentation (the client grace countdown is cosmetic, the server decides the terminal); Conv-1 removes (not adds) a client-position surface; Conv-2 `windowDurationSeconds` is server-derived push-only. 3 MINOR hardening applied (debounce promoted to normative MUST; H.114 gained a client-independence negative; the A3 positioned-respawn invariant flagged as protected).
- **Build-from-artifact gate → 1 BLOCKING + 2 IMPORTANT + 3 MINOR, ALL FIXED in-session:**
  - **BLOCKING** — the round-11 respawn re-add was a *direct* `CharacterAdded` write racing the buffered departure drain (ordering unspecified, re-opening the R4-5 buffered-vs-direct asymmetry). **Fix:** routed the re-add through a new buffered `_pendingReadds` queue + `_enqueueReadd` seam, drained in `_step` AFTER the departure drain (so a same-tick death+respawn nets to alive). The round-11 "sanctioned direct add" exemption (H.110) is RETIRED — no direct alive-set mutation remains. Updated C.10 schema/desc, C.8 `_step` order, C.9 step c (wipe checked after BOTH drains), C.16 seam, H.108, H.110, init, invariant.
  - **IMPORTANT-1** — C.10 "never set for wipe" contradicted step (b) stamping the grace clock on a wipe tick → reworded to acknowledge the benign transient (stamped but never read; wipe resolves the same tick).
  - **IMPORTANT-2** — C.14 + C.15 `OnBeaconWindowFailed` rows still defined `scatter` as the retired window-END condition → updated to the continuous-hold definition.
  - **3 MINOR** — BC5 description round-3 semantics (fixed); BCT4/BCT-DEFEAT side-effect cells omit `_lineBreakEmptySince=nil` (covered by the centralized cleanup, accepted); H.73 negative (adequately references H.85/H.114).

**Verdict shape:** the recurring reconciliation-miss class re-appeared a 4th time (2 signal-table rows + a side-effect contradiction) AND the continuous-hold widening newly exposed the round-11 respawn seam — all caught by the widened build-from-artifact gate, all fixed in-session, and confined to seams the gate's new within-section/side-effect scope is designed to catch. The KITING thesis (continuous hold = "hold the line") is sound and the authority chain held a 5th round. **Round-13 is a patch, not a verdict.** NEXT = round-14 full 7-spec `/design-review` (the closure gate); the round-14 self-stress MUST carry the within-section table/prose + side-effect-column + respawn-seam reconciliation checklist. **DO NOT predict APPROVED for round-14.** Registry: `BEACON_LINE_BREAK_GRACE` added; BEACON_HOLD_RADIUS/ESCALATION_LEAD notes updated. Branch `crafting-round2-patch`; rounds 3–13 work all still NOT committed. **User chose to STOP — round-14 in a fresh session.**

---

## Review — 2026-06-05 — Verdict: NEEDS REVISION (round-14 full-panel closure gate)

**Scope signal:** L (verging XL — 6 dependencies, 4 unwritten with 2 load-bearing [RM, PA]; 7 formulas; win-condition cross-cutting; 109 ACs; multiple new-ADR obligations)
**Specialists:** game-designer, economy-designer, network-programmer, ux-designer, qa-lead, build-from-artifact lens (via general-purpose — gameplay-programmer subagent type avoided per prior delivery failures), creative-director (senior synthesis). **systems-designer's dedicated lens failed to deliver (twice this session — its final message was a truncated reasoning line both times); its formula/state-machine domain was absorbed by the build-from-artifact trace, which independently found the load-bearing ordering defects (B-1 precedence, the _step reorder seams).**
**Review depth:** full — the designated single closure gate after the round-13 authoring pass + two narrow gates.
**Prior verdict resolved:** Round-13's authoring pass (KITING fail-fast continuous-hold + grace; the 5 round-12 convergences; the buffered respawn re-add) — **YES at the rule/schema level, verified.** Conv-1 (canister→beacon-position, all 7 co-referencing cells) and Conv-2 (windowDurationSeconds everywhere + H.116) are confirmed reconciled clean. But round-13's OWN additions (the new `OnBeaconLineBreak` signal + the C.9 step b/c/d reorder) re-opened the recurring reconciliation/spec class a 5th time at that new surface.

### Summary

**Unanimous NEEDS REVISION — all six delivering lenses (none MAJOR, none APPROVED). 13th consecutive non-APPROVED; 4th consecutive non-MAJOR.** CD synthesis: **trajectory still converging, not stalled — but this is the first round whose blocking surface is design-deep rather than spec-mechanical.** The round-13 continuous-hold thesis is **SOUND — protect it** (it genuinely closes KITING and dissolves the ux-B12-2 hysteresis trap, verified in C.9/C.10). **Positive finding to PROTECT (re-confirmed a 6th consecutive round, no regression):** network — **AUTHORITY-CHAIN STATUS: SOUND**; the continuous in-radius determination is fully server-authoritative (positions via `_memberPosition`, never a client claim), the grace clock is server-only, `OnBeaconLineBreak` is push-only, `_pendingReadds` is never client-asserted, Conv-1/Conv-2 carry no client coordinate, BCT3 attribution + the `runOutcomeResolved` latch integrity hold. Neither network BLOCKING is a forge hole. Authority wins over blocker-closure.

### Headline finding (design-level — needs a CD ruling, not a transcription fix)

- **The "SENTRY" successor to KITING [game-designer F1].** Closing KITING pushed optimal play one ring outward: `BEACON_HOLD_RADIUS = 30` (a 60-stud-diameter sphere covering most of a safe room) + the `>=1-in-radius` rule make the optimal line "appoint ONE member to camp a defensible corner at ~28 studs while everyone else plays freely" — not Section B's "hold the line." Not an exploit; game-legal optimal play that contradicts the fantasy. The G.6 "too high" note only addresses 45+ studs; the 30 default may already be too generous. **Ruling needed:** reduce the radius (~10-15 studs) and/or require `ceil(aliveMembers/2)` holders rather than `>=1`.

### Strongest convergence (the most reliable signal)

- **QUADRUPLE-lens — the `OnBeaconLineBreak broken=false` debounce is a normative MUST with no concrete algorithm** *(network N14-B2, ux Finding-2, qa F-T3-2, build-from-artifact I-2)*. "Debounce to the `_lineBreakEmptySince` reset" is circular (the reset is what flaps). Result: every implementer builds a different debounce; a boundary-oscillating sole holder flaps the **squad-level win-state banner** at up to 60 Hz — a WCAG 2.3.1 flash violation H.95 doesn't cover, with no covering AC. Fix: add a `BEACON_LINE_BREAK_RESTORE_DEBOUNCE` knob + a concrete rule (min consecutive non-empty ticks) + an AC; extend H.95.

### Other blocking — design rulings needed

- **[game F2]** Signal Anchor's BC4 value is structurally degraded under continuous-hold (can't reposition/dodge by relocating; single-shot; the predator's commit is already audible). Section B's "decisive during the survival window" is now partly false. Redesign its BC4 role or honestly reframe it as pre-activation recon.
- **[game F4 vs ux F1 — the load-bearing DISAGREEMENT]** `BEACON_LINE_BREAK_GRACE` is over-constrained from BOTH ends: game-designer wants the upper bound CAPPED (~4 s — G.6 itself says 6 s reopens kiting; no config-guard like H.105) while ux-designer shows the 3 s default is mobile-UNRECOVERABLE (perception ~0.3-0.8 s + orientation ~0.3-0.6 s + traverse >=1.4 s ~ 3.0 s mid-case, breaking the "scatter-defeat is never an unsignalled loss" promise — a signalled-but-impossible loss is worse than a silent one). Likely resolved by changing a DIFFERENT variable — shrink the hold radius (ruling above) so a shorter grace is traversable. **This is the CD's load-bearing round-15 ruling.**
- **[game F5]** In-window scatter-to-craft line: a member can leave the hold, craft a Canister at a bench (the craft burst emits at `benchPosition`, not the beacon), and re-enter before grace. In-window *use* emits at the beacon (EC-3); in-window *craft* does not. Ruling on whether this is acceptable.
- **[game F6]** The "loud finale" threat is entirely deferred to unwritten PA; under continuous-hold the squad can't flee, so if PA one-shots the holder, BC4 is a guaranteed loss. Escalate `PREDATOR_BC4_MIN_COMMIT` from "an AC the future GDD must satisfy" to a design note specifying the predator-vs-held-squad interaction.
- **[economy E-1]** The `canister_restore < 3.5 s` ceiling derivation is circular/unit-dependent — it implicitly assumes `OXYGEN_DRAIN_BC4_FLOOR` is normalized to 1.0/s; RM could declare compliance in absolute units while the economy breaks. Restate the F.4 inequality unit-independently (`ITEM_STACK_MAX * canister_restore_s * DRAIN_per_s < oxygen_pool_critical`).
- **[economy E-2 — CD adjudicated economy correct vs the standing fence]** RESONANT's only non-Beacon consumer is the Coil, whose value is PA-gated — so pre-PA, 2 of 3 node tiers are Beacon-components-only and the catalog is "2 decorative items + 1 win-con." The *values* are fenced, but the *structural* "does any node tier have a rational non-Beacon consumer pre-PA" question is in-scope. Add a binding minimum (RM/PA must make >=1 Coil worth crafting per winning run) or honestly declare RESONANT a Beacon-only material.

### Other blocking — mechanical / spec-completeness (no ruling needed)

- **[build-from-artifact B-1 — sharpest]** Scatter-vs-wipe precedence inverts on the grace-expiry-and-death tick: C.9 step (b) fires `OnBeaconWindowFailed(reason="scatter")` and latches `runOutcomeResolved` BEFORE step (c)'s wipe drain — contradicting "wipe takes precedence" (E.24/H.115). Make step (b) compute-only; fire the scatter terminal after step (c), gated on `aliveMembers` still non-empty.
- **[network N14-B1]** `OnBeaconLineBreak` fires on the wipe tick, contradicting C.14's "NOT fired for the wipe path." Add a `runOutcomeResolved` guard before C.9 step (d) + an AC that it never fires on a tick `OnBeaconWindowFailed` fires.
- **[ux F3]** The HOLDING/BROKEN binary — the most safety-critical HUD element — has no colorblind-safe (shape/icon) encoding, unlike the locked surface-4 Coil fix. Lock a shape/icon redundancy + AC.
- **[build B-3]** The position-validity re-add gate is untestable: `_enqueueReadd` fires "only after the HRP exists AND is positioned" but "positioned" has no observable predicate. Specify the concrete production trigger.
- **[build B-5]** `OnBeaconActivated` and `OnEscapeBeaconActivated` both fire on the same tick with identical payloads and both "open the survival-window countdown" — no rule for which the client acts on; UI.3 lists only the former. Assign each a single non-overlapping consumer + add the missing UI.3 row.
- **[qa F-T2-1]** H.108 doesn't drive the re-add through the `_enqueueReadd` seam in its WHEN (a tester could use a real `CharacterAdded` — an illegal live dependency), and there is no AC for the `_enqueueReadd` de-dup. Add both.
- **[qa F-T3-1]** No AC for the "break-within-grace -> recover -> subsequently win" path — the exact scenario that justifies the grace existing. An impl that resets the clock but still fires scatter at window-end would pass the current suite.

### Recommended (fold into the round-15 authoring pass)

game: 2-player bench-vs-hold inversion -> make bench<->beacon spacing a BLOCKING F.2 LD obligation; Section B honesty on the 3-4-player "overlapping 2-holder coverage" optimal; 3D-distance upper-floor safe-hide; surface-13 line-break-countdown vs escalation-lead overlap priority; the 31-33-stud hysteresis-band vs strict-binary residual disagreement. economy: EC-3 made the beacon-position Canister emission a stale bunker-counter rationale (reframe G.4/E.32/C.5.6a — the predator is already committed to the beacon); C.2 18-gather sanity check understates Canister demand ~4-5x; add the gather-budget order-of-magnitude (a real LD node-density dependency); `SQUAD_INVENTORY_TYPE_CAP=8` is a dead knob. network: lock `OnOxygenPulseRequest` fire-and-forget (else breaks H.80 zero-yield); add `AND NOT runOutcomeResolved` to the in-window Canister emission (post-wipe emission into an ended run); specify `_craftSessions` RunEnded cleanup (round-12 REC-5 still open). ux: add the BROKEN grace-countdown to H.111 reduced-motion; lock the beacon direction-vector in the collapsed "N/M holding" state on 375pt; scope the gamepad abort-haptic gamepad-only + distinguish abort/commit pulses; define the Conv-5 escalation animation; <=2-banner coalesce priority. build: define a named `_runEndCleanup()` with an explicit clear-list (the "centralized cleanup" claim has no named function); pin D.1 BT2/BT4 anchor-reset timing; bind the interim re-add connections + supersession-latch lifecycle at RunStarted; state the one-tick enqueue->drain lag's effect on the continuous grace. qa: ~14 AC fixes (H.38 Logic/Integration split; H.114(d) trivially-true headless; H.115/H.116/H.73/H.89 setup ambiguities; H.57 mislabel; H.95/H.111 dual-label; H.66 split; second-break-recover-cycle AC; Conv-4 BT3-suppression AC).

### Specialist Disagreements (adjudicated by creative-director)

- **Grace duration (game-designer vs ux-designer)** — genuinely incompatible constraints on the same dial (cap ~4 s vs raise to 5-6 s). CD: not silently resolved — flagged as the load-bearing round-15 ruling; likely resolved by shrinking `BEACON_HOLD_RADIUS` so a shorter grace is traversable. **User's call.**
- **Aid-necessity fence (economy E-2 vs the standing CD fence)** — CD ruling: the *values* are fenced on RM/PA, but the *structural* node-tier-consumer question is in-scope — economy is correct on the structural half.

### Senior Verdict (creative-director)

Trajectory still converging, not stalled. The reconciliation-miss class re-opening a 5th time is real but confined to the round-13 thesis's OWN new surface (the C.9 step b/c/d reorder + the `OnBeaconLineBreak` signal) while every old seam is confirmed reconciled — the under-scoped-gate signature (de-escalates), not the survived-a-converged-sweep signature (holds at MAJOR). Methodology-MAJOR arc stays resolved; network authority SOUND a 6th round. The continuous-hold thesis is sound; closing KITING simply exposed the next ring of optimal play (sentry-camping) and the new grace mechanism's spec gaps. Held at **NEEDS REVISION**.

### Binding CD next-step sequence (user may override)

- **Round-15 Step 1 — CD ruling session FIRST**, before any authoring: the 7 design rulings (BEACON_HOLD_RADIUS/holder-count, Signal Anchor BC4 role, the grace dial [the load-bearing one — resolve jointly with the radius], scatter-to-craft emission position, PA predator-vs-held-squad interaction, the unit-independent canister inequality, the RESONANT/Coil minimum-consumer).
- **Step 2 — ONE authoring pass** closing the rulings + the ~9 mechanical/spec blockers (B-1 precedence, the debounce algorithm, the wipe-tick `OnBeaconLineBreak` guard, the colorblind encoding, the re-add predicate, the dual-signal consumer, the H.108 seam + de-dup AC, the break-within-grace-win AC, the mobile-recoverability AC). The pass MUST carry a reconciliation checklist covering the new-signal/new-mechanism seam class (a new signal must inherit its sibling's already-solved contracts — debounce, win-tick suppression, colorblind, reduced-motion).
- **Step 3 — round-15 gates (NOT a full panel):** a re-scoped build-from-artifact gate (general-purpose fresh agent) covering the C.9 step b/c/d ordering + the new-signal contracts; a narrow network gate re-confirming authority on the radius/grace/debounce changes. Reserve the full 7-spec panel for round-16.
- **Authority chain is a hard constraint on every fix.** **DO NOT predict APPROVED for round-16.**

### Process note

The gameplay-programmer subagent type remains unusable (not attempted this round); the systems-designer subagent type failed to deliver its final report twice this session (truncated reasoning line both times) — for round-15 gates, prefer the general-purpose agent type for the build-from-artifact lens, and if a dedicated systems lens is needed, instruct it explicitly that its FINAL message must BE the report. Two reusable patterns the CD recorded: **exploit-closure-exposes-next-ring** (closing one degenerate line moves optimal play one ring outward — re-stress the new boundary) and **new-signal-must-inherit-sibling's-solved-contract** (a newly-added signal must carry the debounce/suppression/accessibility contracts its sibling signals already solved).

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-13 authoring pass; ~2122 lines; NOT committed). Load-bearing defects: C.9 step (b)/(c)/(d) ordering (B-1 precedence + N14-B1 wipe-tick fire); the `OnBeaconLineBreak` debounce spec (C.10/C.14/C.15); `BEACON_HOLD_RADIUS = 30` (G.6, the sentry finding); `BEACON_LINE_BREAK_GRACE = 3 s` (G.6, the grace-dial disagreement); the C.10 `_pendingReadds`/`_enqueueReadd` position-validity predicate; the dual activation-signal HUD consumer (C.9 BCT3, C.14, UI.3); F.4 RM inequality (economy E-1) + OQ.15 (economy E-2).
- Cross-cited still-blocking: `player-controller.md` (round-6 MAJOR — owes T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` respawn — all unverified-until-PC); `ecological-disturbance.md` (owns `BEACON_HALF_LIFE`; owes the R4-1 `[64,128]s` registry edit, backstopped by H.105). Not-Started + load-bearing for the fenced aid-necessity: `resource-management.md` (`OXYGEN_DRAIN_BC4_FLOOR`, `canister_restore`), `predator-ai.md` (`PREDATOR_BC4_MIN_COMMIT`); also Not-Started: `resource-node.md`, `hud.md`.
- Registry: `design/registry/entities.yaml` (round-13 `BEACON_LINE_BREAK_GRACE` present; ED `BEACON_HALF_LIFE` value/range unchanged per coordination rules).

**User chose to STOP and revise in a fresh session.** Branch `crafting-round2-patch`; rounds 3-14 work all still NOT committed.

---

## Authoring Pass — 2026-06-05 — Round-15 (CD ruling session + ~9 mechanical blockers) — NOT a verdict

**Type:** Authoring pass (the CD-prescribed round-15: CD ruling session FIRST → ONE authoring pass → [pending] two narrow gates). This is a patch, NOT a `/design-review` verdict. Reconciliation checklist: `reviews/crafting-and-items-round15-patch-plan.md`.

### CD rulings locked (user-approved 2026-06-05; all 4 forks = recommended option)
1. **Hold-zone + grace (load-bearing):** `BEACON_HOLD_RADIUS` 30→**12**; hold requirement `>=1`→**`requiredHolders = ceil(#aliveMembers/2)`** (`held ⟺ #windowAliveInRadius >= requiredHolders`); `BEACON_LINE_BREAK_GRACE` kept **3 s**, range capped 0–6→**0–4**; mid-window line-break threshold moves "empty"→"below requiredHolders". Resolves the round-14 game-vs-ux grace disagreement by shrinking the radius (3 s is mobile-traversable in a 12-stud zone) rather than stretching the grace. Closes the **SENTRY** line (one of four can no longer hold for the rest). Lone survivor still wins (`ceil(1/2)=1`).
2. **Signal Anchor (game F2):** reframed as **pre-activation / opening-read recon**; dropped the "decisive during the survival window" claim (Section B + C.7).
3. **In-window craft (game F5):** in-window craft burst **emits at beacon position** (E.17 rewrite + C.8 BT3 BC4-conditional `emitPosition` + H.52 rewrite), parallel to in-window Canister use (E.32).
4. **RESONANT (economy E-2):** **binding RM/PA forward obligation** — ≥1 Dampener Coil worth crafting per winning run (F.4 PA row (d) + OQ.15 update; honest fallback = declare RESONANT Beacon-only + recut the Coil).
5. **E-1 (default):** F.4 RM oxygen inequality restated **unit-independently** (`oxygen_pool_start + ITEM_STACK_MAX × canister_restore_oxygen < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR`, all in oxygen units) — the `< 3.5 s` ceiling is now illustrative only.
6. **F6 (default):** `PREDATOR_BC4_MIN_COMMIT` escalated to a **two-sided** binding obligation (F.4 PA row (c)): telegraph the BC4 commit with reaction lead + no one-shot of a sole holder; **BC4 must be winnable by holding** (C.5.6a aid-necessity note).

### Mechanical blockers closed (no ruling)
- **Quadruple-lens debounce (the strongest round-14 signal):** new `BEACON_LINE_BREAK_RESTORE_DEBOUNCE` knob (6 ticks) + `_lineBreakRestoreTicks` RunSession counter + **concrete rule** (`broken=true` immediate, `broken=false` only after N consecutive at-threshold ticks) — **replacing the circular "debounce to the `_lineBreakSince` reset" in the C.14 signal-def**; extended H.95 + new H.119.
- **B-1 scatter-vs-wipe precedence:** C.9 step (b) is now compute-only; the scatter terminal fires in step (c) after both drains, gated on `aliveMembers` non-empty, so a same-tick wipe wins (H.115).
- **N14-B1 wipe-tick guard:** step (d) (and `OnBeaconLineBreak`) skipped entirely when `runOutcomeResolved` is set this tick.
- **ux F3 colorblind:** HOLDING/BROKEN carries a closed-ring/broken-ring shape glyph, not color alone (C.9 step d, C.10, C.14, UI-13, H.95).
- **B-3 positioned predicate:** concrete observable `hrp.Position.Magnitude > POSITION_SETTLED_EPSILON` (new G.6 knob) gating `_enqueueReadd` (C.10).
- **B-5 dual activation signal:** `OnBeaconActivated` = activation cue only; `OnEscapeBeaconActivated` = countdown owner (single non-overlapping consumers; added the missing UI.3 row).
- **qa F-T2-1:** H.108 WHEN now drives the re-add through `_enqueueReadd` + a de-dup variant.
- **qa F-T3-1:** new H.120 (break-within-grace → recover → WIN).
- **ux F1:** new H.121 (mobile-recoverability: 12-stud traverse < 3 s grace).

### Field rename
`_lineBreakEmptySince` → `_lineBreakSince` (the trigger is now "below threshold", not "empty") — global; 0 occurrences of the old name remain in the GDD.

### Reconciliation checklist (the round-14-mandated new-signal-inherits-sibling's-contracts sweep)
Every hold-predicate surface moved from `>=1`/"empty"/30-stud to `requiredHolders`/"below threshold"/12-stud: Section B, C.5.6a (victory/defeat/aid), C.9 (BC5/BCT4/BCT-DEFEAT/concurrency/steps a–d/post-prose), C.10 (windowAliveInRadius derivation/`_lineBreakSince`/hold-state/invariants/init/`aliveMembers`), C.12/C.14 (PC contract + `OnBeaconWindowFailed`/`OnBeaconLineBreak` defs), E.17/E.24/E.27/E.30, F.2/F.4 PC rows, UI surface 13, and ACs H.44/H.52/H.73/H.77/H.85/H.89/H.92/H.108/H.114. Confirmed only the unrelated `SIGNAL_ANCHOR_DETECTION_RADIUS = 30` remains at 30.

### Counts
ACs 109→**113** (H.118 respawn, H.119 restore-debounce, H.120 break-recover-win, H.121 mobile-recoverability); edge cases +1 (E.33); knobs +3 (`BEACON_HOLD_MIN_HOLDERS` derived, `BEACON_LINE_BREAK_RESTORE_DEBOUNCE`, `POSITION_SETTLED_EPSILON`) + 1 range cap; RunSession +1 field (`_lineBreakRestoreTicks`). `entities.yaml` updated (radius 12, grace 0–4, rename, +3 constants).

### Flagged to user (awaiting confirmation)
**E.33 — respawn raises `requiredHolders` mid-window** (2→3 alive moves required 1→2; a respawned member spawns out-of-radius, so a previously-sufficient hold can briefly fall below threshold and must recover within the grace). A deliberate consequence of "half the *living* squad holds"; documented + made recoverable (12-stud radius + 3 s grace), but a feel trade the user should confirm. Easy denominator swap (max-alive-so-far / starting count) if it plays badly.

### Round-15 narrow gates — RAN SAME SESSION (2026-06-05), findings fixed in-session

Both CD-prescribed narrow gates ran (build-from-artifact via **general-purpose**; network via **network-programmer** — both delivered):

- **Network re-confirm → AUTHORITY CHAIN SOUND (7th consecutive round, PROTECT).** All 5 vectors SOUND, **0 BLOCKING**: holder-threshold determination (positions via server `_memberPosition`, `requiredHolders` server-derived, no client assertion); respawn re-add (`_enqueueReadd`/`POSITION_SETTLED_EPSILON` server-side + idempotent); line-break terminal fail-closed + debounce/B-1 reorder open no race; in-window craft emits at server `beaconWorldPosition` (no client coordinate); `runOutcomeResolved` single-fire intact across the B-1 reorder. 3 non-blocking ADR-clarity notes (1 folded in — see below; 2 are forward ADR obligations: the near-origin-spawn `POSITION_SETTLED_EPSILON` fallback, already noted in C.10; and "the in-step return must precede (d)", now explicit).
- **Build-from-artifact → 2 BLOCKING + 3 IMPORTANT + 3 MINOR, ALL fixed in-session** (BLOCKING + IMPORTANT + the dangling-ref MINOR; 2 cosmetic MINOR left, gate-confirmed harmless):
  - **BLOCKING-1 (a defect this pass introduced):** the restore-debounce had a reset-on-fire contradiction (C.10 hold-state para said "resets the counter when it reaches the knob", contradicting the edge-trigger intent → duplicate `broken=false` fires every N ticks while holding). **Fixed:** the restore fires on the single tick `_lineBreakRestoreTicks` becomes *exactly equal* to the knob; NOT reset on fire (only reset to 0 on a below-threshold tick) → exactly one restore per line-break episode. Reconciled across C.9 step (d), the C.10 schema field, and the C.10 hold-state para; H.119 already asserts "exactly one".
  - **BLOCKING-2 (a miss the sweep didn't catch):** the PC contract C.12.1(b) still encoded the retired round-3/9 scatter predicate ("window elapses … none within `BEACON_HOLD_RADIUS`"). **Fixed** to "below `requiredHolders` for the full grace, resolvable at any BC4 tick", matching C.9/E.27/C.14.
  - **IMPORTANT-1:** the "post-segment guard returns before (d)" justification was structurally false (the post-segment guard runs *after* the segment that contains (d)). **Fixed:** (d) begins with its own in-step `if runOutcomeResolved then return`; reconciled in C.9 step (d) + C.10.
  - **IMPORTANT-2:** `graceElapsed` local now explicitly initialised `false` before the (a)/(b) branch (C.9 steps intro) so step (c) reads it on either path.
  - **IMPORTANT-3:** H.92 negative reworded — the 13.0-stud lone holder yields scatter **only after the grace elapses**, not an immediate terminal.
  - **MINOR (fixed):** G.6 `BEACON_HOLD_MIN_HOLDERS` row dangling ref "E.34" → **E.33**.
  - **Network note-1 folded in:** `requiredHolders` is computed from the **same pre-drain `aliveMembers`** the snapshot reads (top of tick), so numerator/denominator share one alive-set (C.10).
  - **Build-gate VERDICT (post-fix):** the BC4 tick algorithm — snapshot → (a) victory / (b) compute line-break / (c) drain-then-wipe-vs-scatter / (d) presentation — and the `requiredHolders` threshold are self-consistent and buildable.

### NEXT
**Round-15 is COMPLETE** (authoring + both narrow gates, gate findings fixed). NEXT = **round-16 full 7-spec `/design-review`** (the full panel, deferred from round-15 per the CD prescription) in a fresh session. **DO NOT predict APPROVED for round-16** (the empirical "DO NOT predict APPROVED" caution has held 13 rounds). Branch `crafting-round2-patch`; rounds 3–15 all still NOT committed.

---

## Review — 2026-06-06 — Verdict: NEEDS REVISION (round-16 full-panel closure gate)

**Scope signal:** XL (cross-cutting win-condition system; 6 declared dependencies, 4 not-yet-authored with 2 load-bearing [RM, PA]; 7+ formulas; 121 ACs; 5 flagged ADR obligations)
**Specialists:** game-designer, systems-designer (via general-purpose — the systems-designer subagent type's prior delivery-failure), economy-designer, ux-designer (via general-purpose — re-spawned after the ux-designer subagent type returned only intermediate output, no final report), network-programmer, qa-lead (via general-purpose — re-spawned for the same non-delivery reason), creative-director (senior synthesis). **All six delivering lenses returned NEEDS REVISION.**
**Review depth:** full — the single closure gate after the round-15 authoring pass + two narrow gates (deferred from round-15 per the CD prescription).
**Prior verdict resolved:** Round-15's authoring pass (the SENTRY fix `BEACON_HOLD_RADIUS` 30→12 + `requiredHolders = ceil(#aliveMembers/2)`; the quadruple-lens restore debounce; B-1 scatter-vs-wipe precedence; N14-B1 wipe-tick guard; ux F3 colorblind; B-3 positioned predicate; B-5 dual signal; the 4 CD rulings) — **YES at the rule/schema level for most items, verified.** But **both round-15 headline deliverables failed to fully hold** (the 30→12 radius left 5 stale `30 studs` literals; the restore debounce fixed only the `broken=false` edge while its ACs assert the `broken=true` behaviour backwards), so the recurring reconciliation/spec class re-appeared a 6th time — again confined to round-15's OWN new surface.

### Summary

**Unanimous NEEDS REVISION across all six delivering lenses + CD (none MAJOR, none APPROVED). 14th consecutive non-APPROVED; 5th consecutive non-MAJOR.** The continuous-hold + holder-threshold thesis is **SOUND — protect it.** **Network re-confirmed AUTHORITY/ATTRIBUTION CHAIN SOUND an 8th consecutive round (PROTECT)** — all 5 forge vectors re-derived against the round-15 changes (the `requiredHolders` derivation, the in-window Canister emission position, the buffered re-add, the restore debounce); no forge path. Held at NEEDS REVISION (not MAJOR): the prior MAJOR holds (rounds 4/6/8/10/14) were *sweep-methodology* failures; round-16 is a closure gate against a ruling+authoring round where the recurrence is **single-mechanism and fully enumerable** (seven concentrated misses, not a diffuse class) and qa verified the AC section's hold-rule wording is itself clean. Every blocker is closable in one authoring pass.

### Strongest convergences

- **Stale `BEACON_HOLD_RADIUS = 30 studs` survives the 30→12 change in 3 player-facing locations [systems B1 / game B-2 / ux B-UX-1 — TRIPLE].** Worst: **VA.3 Moment 26 (~line 1136)** — the worldspace ground-ring (the primary in-world "where do I stand to win" cue) authored at **2.5× the real win radius**, actively mis-signalling the win zone → manufactures the unsignalled loss the continuous-hold redesign fights. Also **F.2 LD row (~line 895)** (LD validation at 2.5× radius) and **UI.5 item 4 (~lines 1262/1264)** (the `/ux-design` brief). *(`SIGNAL_ANCHOR_DETECTION_RADIUS = 30` is a different, legitimate knob — leave it.)*
- **The round-15 restore-debounce is mechanically incomplete + its ACs invert the rule [systems B2 (strongest) / qa B1 — AC-vs-spec contradiction; ux R-UX-1 concurs].** Only `broken=false` is debounced; `broken=true` re-fires on EVERY below-threshold tick (~30/s for a boundary oscillation). **H.119 + H.95 assert "at most one `broken=true`"** — an impl matching the C.9 step-(d)/C.10 rule FAILS H.119; one passing H.119 VIOLATES the spec. The "quadruple-lens flap fix" only half-closed.
- **Post-defeat orphaned in-window Canister emission [network BLOCKING-1 / qa B2 — double].** `beaconActivated && !beaconWindowSurvived` stays true after a *defeat* (the flag is set only on victory); a `RequestUseItem` interleaving with the Heartbeat handler between ticks fires `DisturbanceService:Emit` at a stale `beaconWorldPosition` into an ended run. Fix: predicate → `beaconActivated && not runOutcomeResolved` in C.6/C.11/E.32/C.15 + a covering AC (none exists). *(Carryover from round-14 REC — not applied in round-15.)*
- **E.33 respawn-raises-`requiredHolders` [game B-4 / ux B-UX-2 / systems R2 / qa R3 — QUADRUPLE].** A respawn (2→3 alive) raises the threshold 1→2 and can force a line-break the holders didn't cause — flagged "awaiting user confirm." Contradicts Section B; has **no HUD affordance explaining the cause**; H.118 [P0] locks the gate to an unconfirmed denominator.

### Other blocking

- **F.6 line 941 "Replace with the 8 named events" → should be 7** [game B-1 / systems B3 / qa R1] — the Squad Relay cut made it 7 everywhere else; would steer the PC author to a non-existent 8th event.
- **C.15 `OnBeaconWindowFailed` scatter description still uses round-13 "none in radius"** [game B-3] — not the round-15 `requiredHolders` rule; a HUD/PC programmer would implement scatter as "zero holders," wrong for 3–4-player squads.
- **Economy honesty [economy ×3]:** the Signal Anchor's section claims it "bears directly on the window" while its own round-15 spec calls its in-window value "honestly limited" (internal contradiction; possible next cut candidate); RESONANT is functionally Beacon-components-only at MVP (only non-Beacon sink is the PA-gated Coil); the aid-necessity fence is buried in F.4 rather than surfacing at the point of each Overview/C.5.6a/Player-Fantasy claim. Also **C.6 Signal Anchor "deliberately shorter than the window" rationale is stale** vs the round-15 "pre-activation recon" reframe [game B-5].
- **No AC for the round-15 `POSITION_SETTLED_EPSILON` re-add predicate** [qa B3] — the only round-15 rule with a named test seam and no AC.

### Recommended

economy: write the F.4 RM inverse inequality (tank-the-damage line) as a formula parallel to the supply-side one (H.106 currently non-exhaustive); state the C.2 illustrative-loadout opportunity cost. network (round-14 carryover, still unapplied): `reason` typed `"scatter"|"wipe"` union not `string`; specify `RequestUseItem`→RM call fire-and-forget (else threatens H.80 zero-yield); sweep `_craftSessions` at `RunEnded` (+AC); F.5 acknowledges `HumanoidRootPart.Position` is client-replicated (platform exploit caveat on the hold-radius predicate). ux: H.121 mobile recoverability is asserted not resolved (omits the knockback displacement that causes line-breaks + touch latency + unverified PC `MoveSpeed`) — re-run as a real gate once PC locks `MoveSpeed`; BC4 surface-13 internal overload on 375pt needs a worst-case wireframe. qa: `requiredHolders` enumeration AC for 1/2/3/4 alive = `{1,1,2,2}`; tighten H.121 to arithmetic; H.118 [P0] note that the denominator is a tuning knob pending playtest.

### Nice-to-have

systems: non-monotonic difficulty cliff (losing a 3rd teammate, 3→2 alive, *relaxes* `requiredHolders` 2→1) — surface as intended or flag. network: reconnect-during-BC4 end-to-end AC; `OnBeaconHoldStateChanged` bandwidth-bound AC. qa: cross-link H.120 from H.114; same-tick scatter-grace-expiry-AND-wipe sub-assertion (B-1 ordering as a test, not just prose). OQ.9 (bench-open RemoteEvent still unnamed after 16 rounds).

### Specialist Disagreements (adjudicated by creative-director)

- **F.6 "8 named events":** network-programmer read line 941 as "8 was the old count, consistent, no miss" — a MISREAD (the line is an instruction to use 8). game/systems/qa + the literal text say it's a stale reconciliation miss. **Adjudicated: real reconciliation miss → BLOCKING.**
- **`broken=true` re-fire severity:** ux argues it's not a WCAG 2.3.1 flash (the banner stays visually BROKEN) and reframes the harm as alarm-fatigue + bandwidth; systems/qa hold it BLOCKING as an AC-vs-spec contradiction. **Adjudicated: BLOCKING — the AC-vs-spec contradiction is domain-independent of the WCAG question; ux's reframe is additive, not exculpatory.**

### Binding CD rulings (user may override)

- **R16-1 — E.33 denominator → FREEZE `requiredHolders` at window-open** (compute from the alive-set at BCT3, do not raise on a mid-window respawn) — eliminates the respawn-punishes-holders fantasy violation; a respawned member still helps by re-entering the hold but never *raises the bar*. (Alternates the user may pick: max-alive-so-far ratchet, or keep the current live-count.)
- **R16-2 — `broken=true` → fire once per episode** (edge-triggered on the HOLDING→BROKEN transition, suppressed while `_lineBreakSince ~= nil`), reconciling C.9 step (d) / C.10 / C.14 with a corrected H.119 + H.95.
- **R16-3 — Signal Anchor → reframe as an out-of-window (pre-activation) recon tool**; drop the "bears directly on the window" claim from C.2/Overview/Section B; reconcile the C.6 lifetime rationale.
- **R16-4 — RESONANT → keep as a Beacon-justified premium material**; surface the aid-necessity honesty hedge at the point of each claim (Overview, C.5.6a, Player Fantasy) rather than recutting the Coil now; the binding RM/PA "≥1 Coil per winning run" AC (F.4 PA row d) stands.

### Sequencing guidance (CD)

Round-17 = **ONE authoring pass** (R16-1..R16-4 + the 7 BLOCKING + the recommended sweep) carrying **(a) a mandatory canonical-literal fanout sweep** — grep every constant *value* (not just the named-changed surface): all `30 studs` / `>=1` / "none in radius" / "8 events" residue — **and (b) a mandatory AC-vs-rule consistency pass** (the H.119 class: every AC re-derived against the rule it cites). Then **TWO narrow fresh-agent gates**: a network re-confirm (authority on the predicate + emission-guard changes) and a `general-purpose` build-from-artifact gate (the `broken=true` edge + the post-defeat emission guard + the stale-literal sweep verification) — **NOT the systems-designer / gameplay-programmer subagent types** (they fail to deliver in this harness; the ux-designer and qa-lead subagent types also returned no final report this round — prefer general-purpose with explicit "your final message must BE the report" instruction). Reserve the full 7-spec panel for round-18. **Authority chain is a hard constraint on every fix. DO NOT predict APPROVED for round-17.**

### Process note

This round, FOUR custom subagent types (systems-designer, gameplay-programmer per prior rounds; ux-designer + qa-lead this round) failed to deliver a final report — the systems lens was routed through general-purpose from the start; ux + qa were re-spawned through general-purpose after returning only intermediate output. **For future Crafting panels, route the systems / build / ux / qa lenses through general-purpose with an explicit "FINAL message must BE the structured report" instruction; only game-designer, economy-designer, network-programmer, and creative-director delivered as their native types this round.** No `SendMessage` continuation tool is available in this harness — a non-delivering agent must be re-spawned.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-15 authoring pass; 2165 lines; NOT committed). Load-bearing defects: stale `BEACON_HOLD_RADIUS = 30` at F.2 (~895) / VA.3 Moment 26 (~1136) / UI.5 item 4 (~1262/1264); the `broken=true` re-fire (C.9 step d ~212, C.10 ~246/255, H.119 ~2119, H.95); the in-window Canister emission guard (C.6 ~126, C.11 ~317, E.32, C.15 ~404); F.6 "8 events" (~941); C.15 `OnBeaconWindowFailed` scatter prose (~419); E.33 / H.118 denominator (~867 / ~2109); C.6 Signal Anchor lifetime rationale (~128); economy honesty (Overview / C.5.6a / Section B / OQ.15).
- Cross-cited still-blocking: `player-controller.md` (MAJOR REVISION — owes T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` — all unverified-until-PC, and PC `MoveSpeed` for H.121); `ecological-disturbance.md` (owns `BEACON_HALF_LIFE`; owes the R4-1 `[64,128]s` registry edit, backstopped by H.105). Not-Started + load-bearing for the fenced aid-necessity: `resource-management.md` (`OXYGEN_DRAIN_BC4_FLOOR`, `canister_restore_oxygen`), `predator-ai.md` (`PREDATOR_BC4_MIN_COMMIT` + the RESONANT/Coil consumer AC); also Not-Started: `resource-node.md`, `hud.md`.
- Registry: `design/registry/entities.yaml` (round-15 `BEACON_HOLD_RADIUS = 12` + `requiredHolders` present; ED `BEACON_HALF_LIFE` unchanged per coordination rules).

**User chose to STOP and revise in a fresh session.** Branch `crafting-round2-patch`; rounds 3–16 work all still NOT committed.

---

## Authoring Pass — 2026-06-06 — Round-17 (CD rulings R16-1..R16-4 + 7 BLOCKING + recommended sweep + both narrow gates) — NOT a verdict

**Type:** Authoring pass executing the round-16 CD-prescribed sequence (ONE authoring pass carrying a mandatory canonical-literal fanout sweep + AC-vs-rule consistency pass → TWO narrow fresh-agent gates; the full panel is reserved for round-18). This is a patch, NOT a `/design-review` verdict. **DO NOT predict APPROVED for round-18.**

### CD rulings applied (user-approved 2026-06-06; all 3 forks = the recommended option; R16-2 applied as prescribed)

1. **R16-1 — `requiredHolders` FROZEN at window-open.** New `RunSession.requiredHoldersBaseline` (set ONCE at BCT3 step 6 = `ceil(#aliveMembers/2)`, frozen, cleared in `_runEndCleanup`); per-tick `requiredHolders = min(requiredHoldersBaseline, #aliveMembers)`. The `min` clamps DOWN to current alive (preserves the lone-survivor win `min(baseline,1)=1`; never demands more holders than alive) but NEVER UP — so a mid-window respawn can never raise the bar above the activation baseline (closes the round-16 quadruple-lens E.33 fantasy violation) and a death never relaxes it below baseline (monotonic difficulty — also closes the round-16 systems non-monotonic-cliff nice-to-have). Touched C.5.6a, C.9 BC5/BCT3 step 6/BCT4/BCT-DEFEAT/step a, C.10 schema + window-participant derivation + invariants + init + cleanup, G.6 `BEACON_HOLD_MIN_HOLDERS`, E.33 (rewritten — "respawn never raises the bar above the activation baseline"), H.118 (rewritten to test the freeze), new H.124 (baseline enumeration `{1,1,2,2}`). Added a C.10 **shorthand convention** note so the ~15 inline `ceil(#aliveMembers/2)` glosses are sanctioned shorthand for the frozen value.
2. **R16-2 — `broken=true` EDGE-TRIGGERED (fire once per episode).** New `RunSession._lineBreakBroadcast` boolean (the last `broken` value pushed; false=HOLDING). `OnBeaconLineBreak(broken=true)` fires only on the HOLDING→BROKEN edge (when `_lineBreakBroadcast` was false), `broken=false` only on BROKEN→HOLDING after the `_lineBreakRestoreTicks` debounce — completing the round-15 restore debounce (which fixed only `broken=false`). Resolves the round-16 systems-B2/qa-B1 AC-vs-spec contradiction (H.119/H.95 assert "at most one `broken=true`"; the round-15 spec re-fired it every below-threshold tick). Touched C.9 step d, C.10 schema + hold-state para, C.14, H.119 (rewritten).
3. **R16-3 — Signal Anchor reframed to pre-activation recon** at every claim point: C.2 effect cell + catalog note, C.6 lifetime rationale (the stale "deliberately shorter, place it during the window" framing retired), C.7 (already reframed round-15), Overview, OQ.15. Resolves the economy internal contradiction ("bears directly on the window" vs "honestly limited") + game B-5.
4. **R16-4 — RESONANT kept Beacon-premium + honesty hedge surfaced** at the Overview + C.5.6a claim points (was buried in F.4): pre-PA, RESONANT is functionally a Beacon-premium material (its only non-Beacon sink, the Coil, is PA-gated); closure is the binding F.4 PA row (d) AC, with the honest fallback (declare Beacon-only + recut the Coil) noted.

### The 7 BLOCKING + recommended sweep

- **Stale `BEACON_HOLD_RADIUS = 30`→12** swept at F.2 LD row, VA.3 Moment 26 (the worldspace ground-ring — the worst miss, was at 2.5× the real win radius), UI.5 item 4 (+ a "render the ring at the true `BEACON_HOLD_RADIUS`, read from config" lock so it can't drift again). `SIGNAL_ANCHOR_DETECTION_RADIUS = 30` correctly left untouched (different knob).
- **Post-defeat orphaned Canister emission (network BLOCKING-1):** guard changed `beaconActivated && !beaconWindowSurvived` → **`beaconActivated && not runOutcomeResolved`** at C.6, C.11, E.32, C.15 `RequestUseItem`, H.93 (variant c added) — `runOutcomeResolved` is set by every terminal (victory AND defeat) whereas `beaconWindowSurvived` flips only on victory, so the new guard closes the post-defeat orphaned-emission window.
- **F.6 "8 named events"→7** (game/systems/qa); **C.15 `OnBeaconWindowFailed` scatter prose** "none in radius" → "fewer than `requiredHolders`" (game B-3); **`OnBeaconWindowFailed.reason`** typed `"scatter"|"wipe"` union (was `string`); **`POSITION_SETTLED_EPSILON` re-add predicate AC** added (H.123, qa B3 — the only round-15 rule with a named seam and no AC); **`_craftSessions` `_runEndCleanup` sweep** (H.122, round-12 REC-5 / network recommended); **RM fire-and-forget** note on `OnOxygenPulseRequest` (protects H.80 zero-yield).

### Counts
ACs 113→**116** (H.122 run-end cleanup sweep, H.123 re-add predicate, H.124 baseline enumeration; H.118 + H.119 revised; AC-section header corrected — it was stale at "109/H.117," predating round-15). +2 RunSession fields (`_lineBreakBroadcast`, `requiredHoldersBaseline`). Edge cases/VA moments/knobs unchanged. `entities.yaml`: `BEACON_HOLD_MIN_HOLDERS` (freeze) + `BEACON_LINE_BREAK_RESTORE_DEBOUNCE` (edge-trigger) notes updated.

### Round-17 narrow gates — RAN same session (2026-06-06), findings fixed in-session

- **Network re-confirm (network-programmer) → AUTHORITY/ATTRIBUTION CHAIN SOUND a 9th consecutive round (PROTECT); 0 BLOCKING.** Verified the frozen `requiredHolders` is fully server-derived (no client input; the `min` clamp not gameable), `_lineBreakBroadcast` is server-only push, the post-defeat guard closes the orphaned-emission window with attribution intact, the typed `reason` union has no security impact, and RM fire-and-forget is consistent with zero-yield. 2 clarity notes **folded in:** (1) BCT3 step 6 reads `aliveMembers` before the first BC4 drain (baseline + first snapshot share the pre-drain set); (2) `graceSeconds` is ignored on the `broken=false` payload.
- **Build-from-artifact (general-purpose) → BUILDABLE; 0 BLOCKING.** Verified the R16-1 freeze is consistent end-to-end (declared/set/cleared/read; no surviving "recomputed each tick from current" claim; lone-survivor preserved; E.33/H.118/H.124 correct), the R16-2 edge-trigger is consistent across C.9/C.10/C.14/H.119, the post-defeat guard agrees across 5 locations, the 30→12 sweep is complete, and the 116-AC arithmetic is correct. **1 IMPORTANT fixed in-session:** the C.15 `RequestUseItem` cell still used the loose "if the beacon is in BC4" trigger → corrected to the authoritative `beaconActivated && not runOutcomeResolved` (the 5th canister-guard location). 1 MINOR label fixed (H.119 retagged round-16); MIN-2 bare glosses confirmed sanctioned by the C.10 shorthand convention (no fix).

### NEXT
**Round-18 full 7-spec `/design-review`** (the closure gate, reserved per the round-16 CD prescription). **DO NOT predict APPROVED for round-18** (the "DO NOT predict APPROVED" caution has held 14 rounds). **Process note:** route the systems / build / ux / qa lenses through **general-purpose** with an explicit "your FINAL message must BE the report" instruction; only game-designer, economy-designer, network-programmer, and creative-director deliver as their native subagent types in this harness; no `SendMessage` continuation exists — a non-delivering agent must be re-spawned.

### Files Referenced
- Target: `design/gdd/crafting-and-items.md` (round-17 authoring pass; NOT committed).
- Registry: `design/registry/entities.yaml` (`BEACON_HOLD_MIN_HOLDERS` freeze + `BEACON_LINE_BREAK_RESTORE_DEBOUNCE` edge-trigger notes; ED `BEACON_HALF_LIFE` unchanged per coordination rules).
- Cross-cited still-blocking (unchanged): `player-controller.md` (MAJOR REVISION — T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` / `MoveSpeed`); `ecological-disturbance.md` (`BEACON_HALF_LIFE` → `[64,128]s` registry edit, backstopped by H.105); Not-Started + load-bearing: `resource-management.md`, `predator-ai.md`; also Not-Started: `resource-node.md`, `hud.md`.

**Branch `crafting-round2-patch`; rounds 3–17 work all still NOT committed.**

---

## Review — 2026-06-06 — Verdict: NEEDS REVISION (round-18 full-panel closure gate)

**Scope signal:** XL (cross-cutting win-condition system; 6 declared dependencies, 4 not-yet-authored with 2 load-bearing [RM, PA]; 7+ formulas; 116 ACs; 5 flagged ADR obligations)
**Specialists:** game-designer, economy-designer, network-programmer (native types); systems-designer, ux-designer, qa-lead, and a build-from-artifact gate (all via general-purpose per the round-16/17 process note — the native systems/ux/qa subagent types fail to deliver a final report in this harness); creative-director (senior synthesis). **All seven delivering lenses + CD.**
**Review depth:** full — the single closure gate after the round-17 authoring pass (4 CD rulings R16-1..R16-4 + 7 BLOCKING + recommended sweep) and its two narrow gates.
**Prior verdict resolved:** Round-17's authoring pass — **YES at the rule/schema level, verified.** The round-16 HEADLINE (the AC-vs-spec contradiction on `broken=true`) is **closed correctly** by R16-2: H.119 now tests the edge-trigger off `_lineBreakBroadcast` and AGREES with the C.9 step-d/C.10 rule (qa confirmed). The R16-1 freeze, the post-defeat Canister guard, F.6→7, and the 116-AC arithmetic all verified consistent. The defect class did NOT recur on the edge-trigger/freeze surface — but the 30→12 sweep recurred a 7th time on its own surface (see below).

### Summary

**NEEDS REVISION across all seven delivering lenses + CD (none MAJOR, none APPROVED). 15th consecutive non-APPROVED; 6th consecutive NEEDS REVISION.** Thesis (continuous-hold + frozen holder-threshold) **SOUND — protect it.** **Network re-confirmed AUTHORITY/ATTRIBUTION CHAIN SOUND a 10th consecutive round (PROTECT)** — frozen `requiredHolders` fully server-derived, `min`-clamp ungameable, `_lineBreakBroadcast` server-only, post-defeat guard correct at all 5 locations; no forge path through the round-17 surface. Held at NEEDS REVISION not MAJOR: the recurring reconciliation class this round is **single-mechanism and fully enumerable** (the 30→12 sweep again skipping non-executable prose — 4 literals), an authoring-round self-inflicted miss, NOT a sweep-methodology failure (the sweep caught every executable hit; it under-scoped to prose/seam/label text). Every blocker is closable in one authoring pass once two design forks are decided.

### Strongest convergences

- **Stale `BEACON_HOLD_RADIUS = 30` literals survive the round-17 30→12 sweep in non-executable prose [build-from-artifact ×3-4].** C.10 hysteresis rationale (~L257), C.16 `_memberPosition` seam descriptions (~L458/L467 — **load-bearing: these would make an implementer write the H.92 boundary test at 30.0 not 12.0**), H.92 summary label (~L1875). `SIGNAL_ANCHOR_DETECTION_RADIUS = 30` correctly NOT flagged (different knob). This is the round-16-prescribed-fanout-sweep miss class recurring on the round's own surface (7th time).
- **NEW degenerate line — "activate-late-for-low-baseline" [game-designer B-1 + economy-designer R-4 — double].** R16-1's freeze closed respawn-RAISES-bar but opened the symmetric lane: a 4-player squad that delays activation until 2 teammates are dead locks `requiredHoldersBaseline = 1` for the whole window (needs 1 holder, not 2). Contradicts the "activate together at peak tension" fantasy + Pillar 2. The genuine new design fork round-17's own ruling opened.
- **H.121 mobile recoverability asserted, not substantiated [ux-designer B-1 + qa-lead B-2 — double].** The 3s-grace model assumes the displaced holder is exactly at the 12-stud edge, but the knockback that CAUSES most line-breaks pushes outward (20–30 studs → traverse exceeds 3s); omits touch latency + unverified PC `MoveSpeed`. An advisory narrated-prose AC cannot close "the load-bearing game-vs-ux disagreement." Includes the still-missing BC4 worst-case surface-13 wireframe / pixel budget for 375pt.
- **Frozen-baseline legibility [game-designer B-2 + ux-designer R-1 — double].** The "N/M holding" denominator (`M = requiredHolders`) changes silently mid-finale (death lowers it, respawn restores toward baseline) with no rule/AC/HUD cue explaining why.
- **Signal Anchor trap-recipe [game-designer B-3 + economy-designer B-3/N-1 — double].** Post-R16-3 reframe its value is "honestly limited" but it costs as much as the Coil; by the GDD's own Patch/Wrap/Relay cut criteria it qualifies for cut-scrutiny; only structural defense is the PA-gated OQ.15 BIOMASS sink.

### Other blocking

- **Position-replication trust gap [network-programmer N18-B1, P0].** `HumanoidRootPart.Position` is client-replicated in Roblox — `_memberPosition` reads the client's last-replicated value. Spoof into radius = forge-win (`OnBeaconWindowSurvived`/T8); spoof out = grief line-break. Escalated round-16-nice-to-have → BLOCKING because R16-1's `requiredHolders=2`-for-a-4-squad means one spoofed position flips the threshold. No exploit edge case (E.20–E.28), no AC, no F.5 caveat.
- **`graceSeconds` on `broken=false` [network-programmer N18-B2].** Relies on an unwritten HUD GDD honoring a "client IGNORES it" parenthetical; send `graceSeconds=0` server-side + AC.

### Recommended

economy: write the inverse-degenerate inequality `oxygen_pool_start < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR` explicitly (F.4 RM / H.106 — round-16 recommendation still unfulfilled); propagate the R16-4 RESONANT honesty hedge to G.3 (the balance-pass entry point); include in-window Canister noise cost in the C.2 18-gather opportunity-cost framing; give MINERAL the same explicit sink analysis RESONANT now gets. qa: H.124 straddles (make the respawn sub-case a concrete THEN, don't cross-ref H.118); add a standalone AC for the same-tick scatter-grace-expiry-AND-wipe precedence (B-1 wipe-wins ordering); add a reconnect-during-BC4 end-to-end AC (mobile backgrounding). systems: tighten E.33 "monotonic difficulty" wording (the baseline is monotone; the live `requiredHolders` is non-monotone 2→1→2 by design); add shorthand-convention pointers inline to the bare `ceil(#aliveMembers/2)` glosses in P0 ACs H.73/H.85/E.27. game: write the Signal Anchor BIOMASS-sink justification now if keeping (R18-2).

### Nice-to-have

qa: H.95 (WCAG flash cap on the safety-critical win banner) labeled P2 → bump to P1. ux: affordability dimming (C.3.3/H.2) is color/opacity-only — add a text deficit label (violates the GDD's own colorblind rule); tap-hold 0.5s should respect the OS hold-duration accessibility setting.

### Specialist Disagreements (adjudicated by creative-director)

- **C.14 `OnBeaconLineBreak` (L389) stale?** systems-designer B-1 read it as still carrying round-13 "broken=false on re-establish" text → a BLOCKING reconciliation miss. build-from-artifact (sweep item-3 PASS) + ux-designer both verified it consistent. **Adjudicated (CD confirmed by re-reading L389): systems-designer MISREAD — L389 contains the full round-16 `_lineBreakBroadcast` edge-trigger + restore-debounce contract. DISMISSED, not a defect.** This keeps the recurrence single-mechanism (the stale-30 sweep), not two.
- **N18-B1 severity:** systems/build read position-replication as out-of-scope; network escalated to BLOCKING. **Adjudicated: network is RIGHT — newly load-bearing because R16-1 made one spoofed position sufficient to flip the threshold.**

### Binding CD rulings (user may override)

- **R18-1 (USER FORK) — activate-late exploit → default: max-alive-so-far ratchet baseline** (compute `requiredHoldersBaseline` from the high-water alive count, ratcheted from run start, not the activation snapshot — delaying activation buys nothing; preserves R16-1's anti-respawn-raise + the lone-survivor `min`-clamp). Alternative: accept the late-activate lane as a legitimate tactical choice. CD recommends the ratchet (the lane contradicts the stated peak-tension fantasy and is a degenerate-optimal line, the class Patch/Wrap/Relay were cut for).
- **R18-2 (USER FORK) — Signal Anchor → default: KEEP with the BIOMASS-sink justification written now** (as a concrete F.4 forward obligation, not implicit). Alternative: cut to a 4-recipe set. CD recommends KEEP (it is the only pre-activation read-the-threat tool, Pillar 1; not economically dominated the way Relay was).
- **R18-3 (binding) — position-spoof → FENCE-style explicit risk-acceptance for MVP** (E.20–E.28 exploit edge case + F.5 caveat naming forge-win + grief-line-break vectors) + name the server-side position-delta velocity sanity check as the designated post-MVP hardening with a forward-obligation AC. Document-and-fence, do NOT build anti-cheat now (out of MVP scope; protects the 18-round-stabilized authority chain).
- **R18-4 (binding) — send `graceSeconds = 0` on the `broken=false` payload** server-side + add AC; remove the "client IGNORES it" instruction.
- **R18-5 — E.33 respawn-raises-live-`requiredHolders` feel (the round-17 "awaiting user confirm") is RESOLVED by R18-1** (under the ratchet, restore-toward-baseline is the intended legible recovery).

### Sequencing guidance (CD)

Round-19 = **confirm R18-1/R18-2 forks FIRST** → **ONE authoring pass** (5 BLOCKING + 10 recommended; all enumerable, no design unknowns once the forks land) ending in a **MANDATORY canonical-literal fanout sweep** — grep every numeric literal that appears in any executable rule (`12`, `3`, `6`, the holder threshold, the grace) across ALL prose/seam/label/AC text, not just rule sections (the durable fix for the recurring sweep-skips-prose class) — plus an AC-vs-rule consistency pass. Then **TWO narrow fresh-agent gates only**: network re-confirm (authority chain + the N18-B1/B2 caveats landed) and a re-scoped general-purpose build-from-artifact gate (literal fanout verified, R18-1 ratchet buildable). **Reserve the full 7-spec panel for round-20** (two full panels — 16, 18 — have now returned the same enumerable class; a third would confirm, not find). **Authority chain is a hard constraint on every fix. DO NOT predict APPROVED for round-19.**

### Process note

Native subagent types game-designer, economy-designer, network-programmer, creative-director delivered as themselves this round. The systems / ux / qa / build-from-artifact lenses were routed through **general-purpose** with an explicit "your FINAL message must BE the structured report" instruction and all delivered cleanly. No `SendMessage` continuation tool exists in this harness — a non-delivering agent must be re-spawned.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-17 authoring pass; 2197 lines; NOT committed). Round-18 fix targets: stale-30 at C.10 ~L257 / C.16 ~L458/L467 / H.92 label ~L1875; E.33 activate-late + freeze ~L873-877 + C.9 BCT3 step 6 ~L198 + C.10 baseline derivation ~L248/L255; N18-B1 exploit edge case in E.20–E.28 + F.5 ~L933; N18-B2 `graceSeconds` C.9 step d ~L212 / C.14 ~L389; H.121 ~L2137-2142 + surface-13 wireframe UI.5 item 7.
- Registry: `design/registry/entities.yaml` (round-15/16/17 values present; ED `BEACON_HALF_LIFE` unchanged per coordination rules).
- Cross-cited still-blocking (unchanged): `player-controller.md` (MAJOR REVISION — T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` / `MoveSpeed`); `ecological-disturbance.md` (`BEACON_HALF_LIFE` → `[64,128]s` registry edit, backstopped by H.105). Not-Started + load-bearing for the fenced aid-necessity: `resource-management.md` (`OXYGEN_DRAIN_BC4_FLOOR`, `canister_restore_oxygen`), `predator-ai.md` (`PREDATOR_BC4_MIN_COMMIT` + RESONANT/Coil consumer AC); also Not-Started: `resource-node.md`, `hud.md`.

**User chose to STOP and revise in a fresh session.** Branch `crafting-round2-patch`; rounds 3–17 work all still NOT committed.

---

## Authoring Pass — 2026-06-06 — Round-19 (R18-1/R18-2 forks confirmed + 5 BLOCKING + 10 recommended + 3 nice-to-haves + both narrow gates) — NOT a verdict

**Type:** Authoring pass executing the round-18 CD-prescribed sequence (confirm the two USER FORKS → ONE authoring pass closing all 5 BLOCKING + 10 recommended, ending in the MANDATORY canonical-literal fanout sweep + AC-vs-rule pass → TWO narrow fresh-agent gates; the full panel is reserved for round-20). This is a patch, NOT a `/design-review` verdict. **DO NOT predict APPROVED for round-19/20.**

### User forks confirmed (both = the CD-recommended option)
- **R18-1 → max-alive-so-far ratchet baseline** (recommended). Closes the "activate-late-for-low-baseline" degenerate lane.
- **R18-2 → KEEP the Signal Anchor (5 recipes) with the BIOMASS-sink justification written** (recommended).

### The 5 BLOCKING — all closed
1. **Stale `BEACON_HOLD_RADIUS = 30`→12 fanout sweep.** Fixed the 4 flagged prose/seam/label literals (C.10 hysteresis rationale; C.16 `_memberPosition` seam ×2 — the load-bearing H.92-calibration ones; H.92 section label) PLUS 2 the round-18 list missed (the Squad-Relay-cut rationale prose at C.2 + the recipe-table CUT row, genericised to `BEACON_HOLD_RADIUS`). A full re-grep confirms the only surviving `30`s are legitimate (`SIGNAL_ANCHOR_DETECTION_RADIUS = 30`, the `1–30`-tick debounce range, `1/30 s` Heartbeat dt, oxygen `30 s`, AC numbers, and intentional `30→12` history notes).
2. **R18-1 — `requiredHoldersBaseline` now `ceil(peakAliveCount/2)` from a new max-alive-so-far ratchet field** (`peakAliveCount`: a RunSession field, init `#squadRoster` at RunStarted, ratcheted `max(...,#aliveMembers)` every tick, read once at BCT3 step 6), NOT the activation snapshot. Closes the activate-late lane (a 4-squad that waits for 2 deaths still gets baseline 2, not 1). Touched the C.10 schema + RunStarted init + the every-tick drain + BCT3 step 6 + the window-participant derivation + the shorthand convention + the invariants + C.5.6a + G.6 `BEACON_HOLD_MIN_HOLDERS`. **E.33 rewritten** to cover BOTH baseline edges (respawn-never-raises [freeze] + activate-late-never-lowers [ratchet]) with the tightened monotonic wording (baseline monotone-frozen; live `requiredHolders` non-monotone 2→1→2). **H.118 rewritten** peak-consistent with a freeze-discriminating variant; **H.124 restated** to the peak-source + a concrete inline respawn THEN (qa straddle fix); **new H.129** tests the ratchet / activate-late closure.
3. **R18-3 — position-replication trust gap FENCED.** New exploit edge case **E.34** (forge-win + grief-line-break vectors, bounded MVP risk-acceptance, NOT anti-cheat) + an **F.5 caveat** (the `HumanoidRootPart.Position` client-replication note) + a **post-MVP velocity-check forward-obligation AC (H.126)** (`MAX_PLAYER_SPEED` teleport detector). Document-and-fence; no anti-cheat built in MVP.
4. **R18-4 — `graceSeconds = 0` on the `broken=false` payload, sent server-side** (C.9 step d + both C.14 tables + new **H.125**); the round-16 "client IGNORES it" convention is retired.
5. **H.121 mobile-recoverability substantiated.** Reframed from an asserted radius-edge claim into a **falsifiable JOINT inequality** `t_react + t_latency + (displacement / MoveSpeed) < BEACON_LINE_BREAK_GRACE`, where the displacement is bounded by a **new PA forward obligation `PREDATOR_BC4_MAX_KNOCKBACK`** (F.4 PA row c-mobile) — resolving the load-bearing game-vs-ux grace disagreement by bounding the knockback (PA), NOT stretching the grace (stays ≤ 4 s). Marked Integration / unverified-until-PA+PC. PLUS the locked **BC4 worst-case surface-13 375pt pixel budget** (UI.5 item 7 — ≤ 25% safe-area height, no row-expansion at 375pt, concrete wireframe a required `/ux-design` deliverable).

### The 10 RECOMMENDED — all closed
Explicit inverse-degenerate inequality `oxygen_pool_start < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR` (F.4 RM); R16-4 RESONANT honesty hedge + a MINERAL sink analysis propagated to G.3 (the balance entry point); in-window Canister noise opportunity-cost in the C.2 18-gather framing; H.124 straddle → concrete respawn THEN; new **H.127** (same-tick scatter-grace-expiry-AND-wipe → wipe precedence) + **H.128** (reconnect-during-BC4); E.33 monotonic-difficulty wording tightened; shorthand-convention pointers added inline to H.73/H.85/E.27; Signal Anchor keep-justification written (R18-2 — sole pre-activation recon tool + BIOMASS/MINERAL sink, with an F.4 PA readable-approach forward fence).

### Nice-to-haves (3, cheap)
H.95 P2→P1 (it guards the safety-critical win banner); affordability text-deficit label on the dimmed-recipe AC H.2 (colorblind rule); tap-hold respects the OS hold-duration accessibility setting (UI.2).

### Counts
ACs **116 → 121** (H.125–H.129; H.118/H.121/H.124 revised). Edge cases corrected **→ 32** (E.34 added; the "30 through E.32" header was stale — E.33 was round-16 — corrected to "32 through E.34"). +1 RunSession field (`peakAliveCount`). +1 PA forward obligation (`PREDATOR_BC4_MAX_KNOCKBACK`). Registry `BEACON_HOLD_MIN_HOLDERS` updated to the ratchet source (denominator source now LOCKED, no longer a pending swap).

### Round-19 narrow gates — RAN same session (2026-06-06), findings fixed in-session
- **Network re-confirm (network-programmer) → AUTHORITY/ATTRIBUTION CHAIN SOUND an 11th consecutive round (PROTECT); 0 BLOCKING.** Verified `peakAliveCount` is fully server-derived and the ratchet+`min`-clamp ungameable; the E.34 position-spoof fence is honestly scoped and bounded (a client can spoof only its OWN one position; server-only flags + attribution untouched; no larger forge path — a spoof cannot skip the window or set the victory flag); `graceSeconds = 0` is presentation-only with zero security impact; H.125–H.129 + E.34 consistent with the server-authority model. 3 non-blocking clarity notes.
- **Build-from-artifact (general-purpose) → BUILDABLE; 0 BLOCKING, 0 IMPORTANT.** Verified the R18-1 ratchet is consistent end-to-end (declared/init/ratcheted/read; no surviving activation-snapshot baseline computation; worked numbers correct; lone-survivor preserved), the 30→12 sweep is complete (only legitimate 30s remain), E.34/F.5/H.126 + graceSeconds=0 + H.121/PA-cap mutually consistent, and the counts are arithmetically correct (121 ACs through H.129, no dup/skip; 32 edge cases through E.34). **1 MINOR fixed in-session:** the second C.14 formal-table row omitted the `graceSeconds = 0` value for `broken=false` (a parallel-table parity gap, not a contradiction) — added.

### NEXT
**Round-20 full 7-spec `/design-review`** (the closure gate, reserved per the round-18 CD prescription — two full panels [16, 18] have now returned the same enumerable reconciliation class; the third confirms, not finds). **DO NOT predict APPROVED for round-20** (the caution has held 15 rounds). Process note: route the systems / ux / qa / build-from-artifact lenses through **general-purpose** ("your FINAL message must BE the report"); only game-designer, economy-designer, network-programmer, creative-director deliver as native types; no `SendMessage` — re-spawn a non-deliverer.

### Files Referenced
- Target: `design/gdd/crafting-and-items.md` (round-19 authoring pass; NOT committed).
- Registry: `design/registry/entities.yaml` (`BEACON_HOLD_MIN_HOLDERS` → ratchet source).
- Cross-cited still-blocking (unchanged): `player-controller.md` (MAJOR REVISION — T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` / `MoveSpeed`); `ecological-disturbance.md` (`BEACON_HALF_LIFE` → `[64,128]s`, backstopped by H.105). Not-Started + load-bearing: `resource-management.md` (`OXYGEN_DRAIN_BC4_FLOOR`, `canister_restore_oxygen`), `predator-ai.md` (`PREDATOR_BC4_MIN_COMMIT` + `PREDATOR_BC4_MAX_KNOCKBACK` + RESONANT/Coil consumer AC + Anchor-readable-approach); also Not-Started: `resource-node.md`, `hud.md`.

**Branch `crafting-round2-patch`; rounds 3–19 work all still NOT committed.**

---

## Review — 2026-06-06 — Verdict: NEEDS REVISION → **APPROVED (accepted)** (round-20 full-panel closure gate + same-session closure pass)

**Scope signal:** L (the GDD itself; cross-cutting win-condition system, 6 declared dependencies / 4 not-yet-authored with 2 load-bearing, 7+ formulas, 122 ACs, 5 flagged ADRs) — but the *remaining work* after the panel was **S** (one registry line + two design rulings with recommended defaults + one UX requirement+AC + clarity adds).
**Specialists:** game-designer, economy-designer, network-programmer (native types); systems-designer, ux-designer, qa-lead, and a build-from-artifact gate (all via general-purpose per the round-16/17/18 process note — the native systems/ux/qa subagent types fail to deliver a final report in this harness); creative-director (senior synthesis). **All seven delivering lenses + CD.**
**Review depth:** full — the third full panel (the closure gate reserved per the round-18 CD prescription: two full panels [16, 18] had returned the same enumerable reconciliation class; round-20 confirms, not finds).
**Prior verdict resolved:** Round-19's authoring pass (R18-1 max-alive-so-far ratchet baseline; R18-2 keep Signal Anchor + BIOMASS-sink justification; the 5 round-18 BLOCKING + 10 recommended + the mandatory canonical-literal fanout sweep + AC-vs-rule pass) — **YES, verified.** The 19-round stale-literal/AC-vs-rule recurring class **did NOT recur in the GDD** (systems + build lenses both confirmed the sweep CLEAN; the C.10 shorthand convention is the structural fix that extinguished it). The class did, however, **relocate to the registry** (see RBI-1).

### Summary

**Panel verdict: NEEDS REVISION across all seven delivering lenses' synthesis (split 3 APPROVED/clean + 1 BUILDABLE vs 3 NEEDS REVISION) + CD. 16th consecutive non-APPROVED, 7th non-MAJOR.** Thesis (continuous-hold + frozen/ratcheted holder-threshold) **SOUND — PROTECT. Network re-confirmed AUTHORITY/ATTRIBUTION CHAIN SOUND a 12th consecutive round (0 BLOCKING — PROTECT):** the `peakAliveCount` ratchet is fully server-derived and ungameable; the E.34 position-spoof fence is honestly bounded (one own position only, no larger forge path, attribution intact); `graceSeconds=0` has no security impact; the post-defeat Canister guard is correct at all 5 sites; rate-limit math sound. **The mechanical spine is clean for the first time in 20 rounds** — AC arithmetic verified (122 live, no dup/skip; 32 edge cases), every formula boundary-safe, buildable-from-artifact, the AC-vs-rule contradiction class (the round-16 headline) closed and staying closed. The four open items were: one concrete registry contradiction, one UX legibility gap, two design positions the document had never explicitly staked, and an economy justification gap. **The user reviewed the closure pass and ACCEPTED the revisions, marking Crafting & Items APPROVED** (electing not to run a 7th full panel — the spine is verified clean by four independent lenses and the remaining items are advisory).

### Required-before-implementation (4 BLOCKING) — ALL CLOSED in-session

- **RBI-1 [economy EC-B1, verified by orchestrator]** — `design/registry/entities.yaml` had a **duplicate `notes:` key** on `MAGNITUDE_CANISTER_INWINDOW_USE` (L549 + L550). YAML resolves duplicate keys to the *last*, so a registry reader got L550 — which carried **both** the pre-EC-3 reversed emission position ("USING player's `HumanoidRootPart.Position`" instead of `beaconWorldPosition`) **and** the round-17-superseded guard (`beaconActivated && !beaconWindowSurvived` instead of `not runOutcomeResolved`). A build from it would reintroduce the scatter-to-breathe defect EC-3 foreclosed. → **Deleted L550; consolidated into one correct note.** *(This is the 19-round recurring reconciliation class, relocated from the GDD into the registry — the GDD's own sweep was clean.)*
- **RBI-2 [game-designer G-B1]** — the "Pillar 1 enforced economically" claim (C.2) self-contradicted the all-BIOMASS gather line (gather cheap Light/BIOMASS, pool Beacon mats, stack Oxygen Canisters, rarely touch loud RESONANT/Heavy nodes — so quiet routing is *rewarded* in the gather phase, not *forced*). **Ruling (user, recommended default): accept it explicitly.** → C.2 narrowed: Pillar 1 in the gather phase rewards quiet routing but does not mandate loud gathers; the unavoidable loud beat is the finale. No forcing function added (would risk a new trap/dominant line of the Patch/Wrap/Relay class).
- **RBI-3 [game-designer G-B2]** — 2-player squad → `requiredHolders = ceil(2/2) = 1`, so the 2nd player is free during the finale; the "hold the loudest thing TOGETHER / Pillar 2" fantasy doesn't bind for 2-player squads. **Ruling (user, recommended default): intended asymmetry.** → Section B note: one holds, one works the predator — the 2-player shape of the Pillar-2 fellowship test; a 2-holder floor is rejected (it would break the lone-survivor win C.17/E.30).
- **RBI-4 [ux-designer UX-B1]** — the "N/M holding" denominator (M = `requiredHolders`) changes mid-finale (death lowers it via the min-clamp; respawn raises it toward the frozen baseline); E.33 *claimed* legibility but no UI requirement or AC delivered a cause cue — a silently shifting win-target reads as unfairness (worst when a respawn raises 1→2). → **Surface-13 REQUIRED denominator-change cue** (text + non-color, names the new value AND its cause; presentation-only; client-derivable; WCAG/reduced-motion bound) + covering AC **H.130**.

### Also closed in-session (economy marked BLOCKING; CD treated as a clarity add since the inequality is mathematically sound)

- **EC-B2** — the F.4 RM over-supplied oxygen inequality stresses against a full `ITEM_STACK_MAX = 10` Canister stack, but the justification for why 10 (vs a realistic ~3–4) is the right stress denominator was absent. → Added a BIOMASS-ceiling argument (Canisters cost 2 BIOMASS each, BIOMASS is the cheapest/most-plentiful tier, so a real run can stack to near-cap; RM must calibrate `OXYGEN_DRAIN_BC4_FLOOR` against the full-stack denominator).

### Recommended (deferred to implementation / polish — NOT applied, logged here)

- **economy:** G.3 should note MINERAL's "two consumers" edge over RESONANT collapses to one PA-gated consumer if the Anchor fails PA review (F.4 PA row e); the "Anchor cost-neutral at 3 gathers" phrasing is gather-count-neutral but ~31% cheaper in *disturbance* — reword; OQ.13 should note Canister-use *timing* (not just count) is a calibration lever.
- **game-designer:** acknowledge the Anchor may be "nice-if-time" not decision-forcing (intended); add HUD forward obligations for per-member hold-status indicators and a "Beacon-craftable" squad signal (Pillar 2 legibility, F.4 HUD row).
- **ux:** H.121's worked envelope hard-codes `MoveSpeed ≈ 16` — require re-derivation if PC ships a lower BC4 speed; promote the tap-hold OS-accessibility honoring from SHOULD to an AC-backed requirement.
- **qa:** refresh the stale determinism-preamble enumeration (L1295) to include H.118/H.120/H.127/H.128 (no testability gap — each individually cites C.16).
- **network:** stub a CI test for the H.126 post-MVP velocity check so the hardening doesn't slip a sprint gate; clarify `peakAliveCount` ratchets after *both* the departure and re-add drains; HUD-author note that `graceSeconds=0` on `broken=false`.

### Specialist disagreements (adjudicated by creative-director)

1. **Verdict split** (network/systems/qa APPROVED + build BUILDABLE vs game/economy/ux NEEDS REVISION) → the three clean lenses own the implementability spine (sound for the first time); the three NEEDS-REVISION lenses own pillar fidelity / legibility / economy honesty (open). Different axes, both right; verdict reflects the lower.
2. **Has the recurring reconciliation class been extinguished?** → Extinguished in the GDD (systems + build verified CLEAN), but relocated to the registry (RBI-1). NEEDS REVISION not MAJOR — a single enumerable scope gap (the round-19 sweep covered the GDD, not `entities.yaml`), not a methodology failure.
3. **Are G-B1/G-B2 blocking?** → BLOCKING at a closure gate (a self-contradicting pillar claim + an unexamined pillar edge), but closable by ruling + prose, not redesign.

### Specialist note (positive dissent — PROTECT)

network-programmer: the win-condition AUTHORITY/ATTRIBUTION chain is **SOUND — no forge path** (12th consecutive round). All five round-19-surface vectors re-derived. Any future change MUST NOT touch the server-authoritative completion/attribution path.

### Counts

ACs 121 → **122** (H.130 added). Edge cases unchanged (32). Both G-B1/G-B2 rulings = the user-confirmed recommended defaults. GDD header + Last-Updated + systems-index (row 6 status + effort row + approved/needing-revision metrics) all updated. `entities.yaml` `MAGNITUDE_CANISTER_INWINDOW_USE` de-duplicated.

### Cross-GDD obligations still owed by siblings (unchanged, tracked for the implementation phase)

- **PC** (MAJOR REVISION): T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` / `MoveSpeed`.
- **ED** (In Review): `BEACON_HALF_LIFE` → `[64,128]s` registry edit (backstopped by H.105).
- **RM** (Not Started, load-bearing): `OXYGEN_DRAIN_BC4_FLOOR`, `canister_restore_oxygen` (the F.4 oxygen inequalities + H.106).
- **PA** (Not Started, load-bearing): `PREDATOR_BC4_MIN_COMMIT` + `PREDATOR_BC4_MAX_KNOCKBACK` + the RESONANT/Coil consumer AC + the Anchor readable-approach expectation.
- **HUD** (Not Started): consume the C.14 client-bound signals incl. the new surface-13 denominator-change cue.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-20 closure pass; 122 ACs; NOT committed). Edits: C.2 Pillar-1 claim narrowed; Section B 2-player asymmetry note; F.4 RM `ITEM_STACK_MAX` ceiling justification; UI.1 surface 13 denominator-change cue requirement; new AC H.130; header + Last-Updated + AC-section count (121→122) reconciled.
- Registry: `design/registry/entities.yaml` (`MAGNITUDE_CANISTER_INWINDOW_USE` duplicate `notes:` key deleted).
- Systems index: `design/gdd/systems-index.md` (Crafting row 6 → APPROVED-by-acceptance; effort row; approved 0→1 / needing-revision 3→2).

**User ACCEPTED the revisions and marked Crafting & Items APPROVED. Branch `crafting-round2-patch`; rounds 3–20 work all still NOT committed (awaiting user instruction per CLAUDE.md).**

---

## Review — 2026-06-08 — Verdict: NEEDS REVISION (round-21 full-panel re-verification) → doc-integrity reconciliation applied; round-20 APPROVED-by-acceptance UNCHANGED

**Scope signal:** Remaining work **S** (5 doc-integrity edits + a few clarity adds; no redesign, nothing touching the protected thesis or authority chain). The GDD as a whole remains XL.
**Specialists:** game-designer, economy-designer, network-programmer (native); systems-designer, ux-designer, qa-lead, build-from-artifact gate (general-purpose per the standing harness process note); creative-director (senior synthesis). **All seven delivering lenses + CD.** Process note: native subagent types game-designer + network-programmer FAILED to deliver this round (returned mid-work text) — re-spawned via general-purpose, which delivered. economy-designer + creative-director delivered native. No `SendMessage` continuation tool exists in this harness — re-spawn a non-deliverer.
**Review depth:** full — the first genuine fresh full panel against the post-round-20-acceptance GDD (round-20's APPROVED was a user-acceptance decision, NOT a clean panel verdict; no full panel has ever returned a clean APPROVED in 16 prior attempts — now 17).
**Prior verdict resolved:** Round-20's closure pass — **YES, verified.** The mechanical spine, thesis, and server-authoritative win/attribution chain all re-confirmed clean.

### Summary

**Panel verdict NEEDS REVISION (17th consecutive non-APPROVED) — but it did NOT overturn the round-20 user acceptance.** Every finding was either (a) enumerable doc-integrity residue (now fixed) or (b) a design critique re-opening a user-accepted ruling. **Network re-confirmed the AUTHORITY/ATTRIBUTION CHAIN SOUND a 13th consecutive round (0 BLOCKING — PROTECT):** no forge path; `peakAliveCount` server-derived, min-clamp ungameable, E.34 position-spoof fence honestly bounded, `graceSeconds=0` presentation-only, rate-limits sound. **Build BUILDABLE; systems boundary-safe (all formulas D.1–D.7 degenerate-free at extremes; survival-window derivation exact at [64,128]→[35,70]s); AC arithmetic exact (122 live through H.130; 32 edge cases through E.34).** The headline finding: **the 19-round recurring reconciliation class recurred a 20th time** — the round-20 build lens had wrongly declared it "extinct," but it had merely relocated (GDD→registry at round-20; now back into ACs + the determinism preamble at round-21), found by the systems + qa lenses and MISSED by the build lens (under-scoped to the radius literal again, same pattern as prior rounds).

### Required-before-clean-APPROVED (3 doc-integrity BLOCKING) — ALL CLOSED in-session

- **B-1 [qa-lead, verified]** — the determinism preamble (L1295) time-driven enumeration was STALE (stopped at the round-13 ACs H.85/H.114/H.115; omitted H.118/H.120/H.127/H.128 — the EXACT round-20 deferred item, not fixed). A test author reading the stale list could reintroduce a wall-clock grace timer. → Extended the enumeration to include H.118/H.120/H.127/H.128 (+ noted the `_step`-edge H.119/H.123/H.130) and added a **forward-maintenance rule** ("any new time-dependent AC MUST be appended") so the list can't silently go stale again.
- **B-2 [systems-designer, verified]** — stale **2-field** `OnEscapeBeaconActivated(activatorPlayerId, timestamp)` at H.15 (L1401), H.56 (L1655), and the F.2 PC row (L912) contradicted the canonical **3-field** form (`+ windowDurationSeconds`, round-13 Conv-2) at C.12.1/C.15/UI.3/schema — a genuine AC-vs-rule contradiction the PC implementer reads to wire T8. → All three updated to the 3-field form; grep confirms 0 stale 2-field call forms remain.
- **B-3 [qa-lead, verified]** — H.105 carried a contradictory dual "Logic / Config-Data" label and asserted the survival-window band via the rounded `0.5476` coefficient rather than the closed form the service computes (the 64 s boundary was ambiguous). → THEN pinned to `log₂(MAGNITUDE_BEACON/HUNT_THRESHOLD)` = `log₂(0.95/0.65)` with the boundary predicate `>= 35.0 AND <= 70.0` (64 s → 35.05 s, in-band); label settled to **Logic**.

### Recommended — closed in-session (cheap sweep)

- **[economy EC-21-1]** F.4 (L938) labeled the inverse-degenerate inequality "**strictly stronger**" — mathematically backwards (the over-supplied form is the stronger one; OS ⟹ ID). Functionally mitigated (the sentence requires "both hold" + H.106 binds the over-supplied form, so the bunker line was never actually open), but the inverted rationale was a real correctness defect. → Corrected to "**strictly weaker**," stated the implication direction, and made explicit that RM MUST carry the over-supplied inequality (H.106) as the binding AC.
- **[systems R3]** the bare `requiredHolders = ceil(#aliveMembers/2)` gloss at the C.12.1 T8 contract row omitted the freeze/ratchet qualifier (governed by the C.10 convention but load-bearing where PC wires T8). → Spelled out `min(requiredHoldersBaseline, #aliveMembers)` with `requiredHoldersBaseline = ceil(peakAliveCount/2)` frozen-at-activation.
- **[systems R2]** orphaned "relay-activate" tokens at C.12.4 (L356, twice) to the round-5-cut Squad Relay. → Scrubbed both.

### Deferred (advisory, NOT applied — logged for the implementation/polish phase)

- **economy:** state the full-cap Canister-stockpile disturbance ratio vs the Beacon line (C.2/OQ.13); reword "cost-neutral at 3 gathers" to separate gather-count from disturbance; note MINERAL's two-consumer health is contingent on the Anchor surviving PA review; assemble a dominant-line disturbance budget.
- **ux:** re-measure the surface-13 375pt pixel budget to include the H.130 cue (now a 5th element) + specify its placement vs the BROKEN grace countdown; pin `BEACON_LINE_BREAK_GRACE` to its 4 s upper bound as the pre-PC/PA default; add a respawn-driven-line-break recoverability clause (H.121 covers only knockback displacement); add the cue to the H.95/H.111 flash/reduced-motion GIVEN sets; "capacity restored" framing for the 1→2 raise.
- **qa:** stub a `pending` CI test for H.126 (post-MVP velocity check); broaden C.16 seam coverage beyond departures; add the D.2 2-player clamp test; H.52/H.130 split-label tidy.
- **network:** doc the race-free guard read in C.11 §1; note the grief-vector continuous exercisability for the post-MVP hardening priority.

### Specialist disagreements (adjudicated by creative-director)

1. **build "stale-literal class extinct" vs systems/qa "it recurred."** → **Systems/qa RIGHT** (orchestrator verified all three recurrences against source): the class recurred a 20th time on new surfaces (payload arity, preamble enumeration, relay orphan); the build lens under-scoped to the radius literal again. **NEEDS REVISION, not MAJOR** — single-mechanism, enumerable, the 20th instance of a known class, not a methodology collapse. The round-20 "extinguished" claim was premature.
2. **economy EC-21-1 severity.** → **RECOMMENDED, not BLOCKING** — mislabeled rationale, not a functional hole (both-hold required + H.106 binds the stronger form).
3. **game B1 (2-player asymmetry) / B2 (Signal Anchor) re-open user-accepted round-20 rulings (RBI-3 "intended asymmetry"; R18-2 "keep Anchor").** → **Closed by user ruling — a fresh panel surfaces the critique but cannot overturn a decision the user already made and accepted.** Noted for the record; NOT blocking. (Live forks if the user ever wants to revisit: floor `requiredHolders = min(2, peakAliveCount)` for the 2-player co-stand; upgrade F.4 PA(e) SHOULD→MUST or cut to 4 recipes for the Anchor.)

### Specialist note (positive dissent — PROTECT)

network-programmer: the win-condition AUTHORITY/ATTRIBUTION chain is **SOUND — no forge path** (13th consecutive round). Any future change MUST NOT touch the server-authoritative completion/attribution path.

### Counts

ACs unchanged (**122**, H.130 the highest). Edge cases unchanged (**32**, through E.34). 6 GDD locations edited (preamble, H.15, H.56, F.2 PC row, H.105, F.4 economy label, C.12.1 T8 row, C.12.4 relay scrub) + header + Last-Updated. No registry edit (entities.yaml clean — round-20 dup-key fix held; build lens re-confirmed no dup keys).

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-21 reconciliation pass; 122 ACs; NOT committed).
- Systems index: `design/gdd/systems-index.md` (Crafting row 6 — round-21 note added; status unchanged at APPROVED-by-acceptance).
- Cross-GDD obligations still owed by siblings (unchanged): **PC** (MAJOR REVISION — T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` / `MoveSpeed`); **ED** (`BEACON_HALF_LIFE` → `[64,128]s`, backstopped by H.105); **RM** (Not Started, load-bearing — `OXYGEN_DRAIN_BC4_FLOOR`, `canister_restore_oxygen`); **PA** (Not Started, load-bearing — `PREDATOR_BC4_MIN_COMMIT` / `PREDATOR_BC4_MAX_KNOCKBACK` / RESONANT-Coil consumer AC / Anchor readable-approach); **HUD** (Not Started — C.14 signals incl. the surface-13 denominator-change cue).

**User chose to STOP after the reconciliation pass. Branch `crafting-round2-patch`; rounds 3–21 work all still NOT committed (awaiting user instruction per CLAUDE.md).**

---

## Review — 2026-06-08 — Verdict: NEEDS REVISION (round-22 full-panel re-verification) → 6 doc-integrity BLOCKING fixed in-session; round-20 APPROVED-by-acceptance UNCHANGED

**Scope signal:** Remaining work **S** (6 one-clause doc-integrity edits + a small canonical-literal fanout; no redesign, nothing touching the protected thesis or authority chain). The GDD as a whole remains **XL**.
**Specialists:** game-designer, systems-designer, economy-designer (native); network-programmer, qa-lead, ux-designer, build-from-artifact gate (general-purpose); creative-director (senior synthesis). **All seven delivering lenses + CD delivered natively this round (no re-spawn needed — unlike rounds 14/16/21).**
**Review depth:** full — first fresh full panel against the post-round-21 GDD. 18th consecutive non-APPROVED full-panel verdict; round-20 APPROVED-by-acceptance stands (a fresh panel cannot overturn a user-accepted ruling).
**Prior verdict resolved:** Round-21's reconciliation pass — **partially. The 6 round-21 edits were individually correct, but 5 of 7 lenses found that round-21's OWN same-day edits SPAWNED new instances of the recurring reconciliation class** (the documented "fix-creates-next-gap" pattern). Verified and fixed this pass.

### Summary

**Panel verdict NEEDS REVISION (18th consecutive non-APPROVED full panel) — did NOT overturn the round-20 user acceptance.** Every finding was enumerable doc-integrity residue; all 6 BLOCKING fixed in-session. **Network re-confirmed the AUTHORITY/ATTRIBUTION CHAIN SOUND a 14th consecutive round (0 BLOCKING — PROTECT):** no forge path; all 5 exploit vectors re-derived; E.34 position-spoof fence honestly bounded; round-21 edits did not perturb the chain. **Build BUILDABLE; systems boundary-safe (all D.1–D.7 degenerate-free at extremes EXCEPT the window-derivation upper edge — B1); AC arithmetic exact (122 live through H.130; 32 edge cases through E.34).** Headline: **the recurring reconciliation class recurred a 22nd time, self-inflicted by round-21's own same-day edits** — H.105's closed-form pin opened a boundary degeneracy; the new preamble forward-maintenance rule shipped with a still-incomplete list; the arity fix elsewhere left stale siblings at H.109 + surface-13. The build lens AGAIN returned APPROVED/BUILDABLE by under-scoping to only the round-21-edited surfaces, missing the 4 new instances the systems/qa/ux/game lenses caught — the documented durable weakness of that lens (it confirms build-wiring; it is NOT a closure gate).

### Required-before-clean-APPROVED (6 doc-integrity BLOCKING) — ALL CLOSED in-session

- **B1 [systems-designer, verified]** — H.105's round-21 closed-form pin created a boundary crash: `k = log₂(0.95/0.65) = 0.547488`, so the CD-mandated ED upper-band edge `BEACON_HALF_LIFE = 128 s` → window = `70.08 s`, which FAILED H.105's own `<= 70.0` startup predicate → `CraftingService` refuses to start at a legal, mandated config. G.6 L1065 already wrote the band as `[35.0, 70.1]`, so H.105 was the outlier. → predicate ceiling loosened to `<= 70.1` (the CD-recommended tolerance fix, not an ED band re-tighten); H.105 header band + boundary-case parenthetical (both edges shown) + rationale updated; **G.6 L1067 aligned to the exact closed form `log₂(0.95/0.65)` + `[35.0, 70.1] s`** and L1061's rounded constant marked `≈` (folds in the H.105↔G.6 form residue). *(crafting-and-items.md:2021, :2024, :1061, :1067)*
- **B2 [game-designer, verified]** — H.109's THEN still read `beaconActivated && !beaconWindowSurvived` — the RETIRED narrower suppression gate (build-gate A4 dropped `&& !beaconWindowSurvived` because it released suppression at the victory write and reopened a post-victory defeat-race). Every governing rule uses `beaconActivated == true` alone (C.9 L202/L348, F.2 L912, F.4 L934). As written, the AC would certify the post-victory defeat-race the design exists to prevent. → corrected to the whole-lifecycle gate. *(crafting-and-items.md:2058)*
- **B3 [ux-designer, verified]** — UI.1 surface-13 (the load-bearing finale HUD surface) carried the stale `requiredHolders = ceil(#aliveMembers/2)` (pre-round-16 live-recompute form), contradicting the locked frozen-baseline model `min(requiredHoldersBaseline, #aliveMembers)`, baseline `ceil(peakAliveCount/2)` frozen at BCT3 (H.118 "denominator-source decision is locked"; H.124/H.129/C.10). A HUD programmer reading the authoritative surface-13 spec would mis-render the `N/M holding` win-target — the exact perceived-unfairness bug H.130's cue exists to prevent. → corrected to the frozen-baseline form. *(crafting-and-items.md:1224)*
- **B4 [qa-lead, verified]** — the determinism preamble's round-21 forward-maintenance rule shipped with a list still omitting ≥5 time-dependent ACs: **H.22** (Signal Anchor `SIGNAL_ANCHOR_LIFETIME` expiry — cites the preamble but wasn't in it), **H.37** (Dampener Coil 60 s `expiresAt`), **H.92** (window-end grace), **H.102** (backward server-time-slew window guard), **H.129** (activate-late ratchet); also **H.125** (`broken=false` restore `_step` edge). → all appended to the enumeration (H.125 in the `_step`-edge list). *(crafting-and-items.md:1295)*
- **B5 [economy-designer, verified]** — the H.102–H.107 group-header index (L1998) labeled H.106 "RM inverse-degenerate forward obligation," but H.106 now binds BOTH the over-supplied bunker line AND the inverse-degenerate tank-the-damage line — an RM author could miss it's the binding AC for the full canister-stacking strategy. → index relabeled "closes BOTH the over-supplied bunker line AND the inverse-degenerate tank-the-damage line." *(crafting-and-items.md:1998)*
- **B6 [economy-designer, verified]** — F.4 (L938) "~16 BIOMASS (8 Light-node pulls) funds ~8 Canisters after the Beacon's 2 BIOMASS" was wrong: `16 − 2 = 14 → 7` Canisters; 8 needs 18 BIOMASS. The worked claim justifying `ITEM_STACK_MAX` as the stress denominator had bad arithmetic. → corrected to ~18 BIOMASS (9 pulls at ~2 each) → 8 Canisters with the `(18−2)/2 = 8` working. *(crafting-and-items.md:938)*

### Recommended — deferred (advisory, NOT applied; logged for the implementation/polish phase)

- **economy:** F.4 "strictly weaker" prose is correct but easy to misread — add a clarifying gloss; add an OQ.15 "≥1 Signal Anchor per winning run" floor analogous to RESONANT's binding Coil AC; add a caveat that H.106's per-member form closes the bunker line only if RM does not pool oxygen across members.
- **qa:** H.92 carries the bare `ceil(1/2)` shorthand not the frozen-baseline gloss its siblings carry (value correct); H.52/H.130 split-label tidy still open; H.126 CI `pending` stub still deferred.
- **ux:** UI.1/VA Moment-26 still say the countdown is "opened by `OnBeaconActivated`/`OnEscapeBeaconActivated`" while UI.3 (authoritative) says `OnEscapeBeaconActivated` alone owns it; H.121 worked envelope hard-codes `MoveSpeed≈16` with no published BC4 floor; surface-13 ≤25%-height pixel budget (L1287) doesn't enumerate the H.130 cue as a concurrent element; tap-hold OS-accessibility is SHOULD not AC-backed (prior-ruled advisory).
- **game:** Section B "~49 s" reads as a fixed beat while the window is variable `[35,70] s` — add a one-clause hedge.
- **network:** C.15 L445 cosmetic stale literal ("16 events/2 s" in one clause vs the canonical "3 s burst window" elsewhere).

### Specialist disagreements (adjudicated by creative-director)

1. **Verdict split — network + build APPROVED vs game/systems/economy/qa/ux NEEDS REVISION.** Not a real disagreement: network (authority chain) and build (mechanical wiring) verify *contracts*; the 5 content lenses verify *doc content*. Disjoint surfaces, both correct. Verdict follows the content axis.
2. **Build lens APPROVED while missing 4 real defects** (H.109, H.105 boundary, surface-13, preamble omissions). CD ruling: the build-from-artifact gate's documented structural scope is build-wiring confirmation; it is NOT a closure gate and never overrides the content lenses.
3. **Severity — MAJOR vs NEEDS REVISION.** NEEDS REVISION: the class did not survive a sweep that targeted it (that would be methodology failure) — it relocated to surfaces the round-21 arity fix never claimed to cover. Enumerable, single-class, all one-clause fixes.

### Specialist note (positive dissent — PROTECT)

network-programmer: the win-condition AUTHORITY/ATTRIBUTION chain is **SOUND — no forge path** (14th consecutive round). Any future change MUST NOT touch the server-authoritative completion/attribution path.

### Counts

ACs unchanged (**122**, H.130 the highest). Edge cases unchanged (**32**, through E.34). 8 GDD locations edited (H.105 header + THEN, G.6 L1061 + L1067, H.109, surface-13, determinism preamble, H.106 index, F.4 arithmetic) + header Status + Last-Updated + systems-index row 6. No registry edit.

**User chose to apply the 6 BLOCKING fixes in-session and keep the system APPROVED (residue sweep, not a verdict change). Branch `crafting-round2-patch`; rounds 3–22 work all still NOT committed (awaiting user instruction per CLAUDE.md).**

---

## Review — 2026-06-08 — Verdict: NEEDS REVISION (round-23 full-panel re-verification) → 3 doc-integrity BLOCKING fixed in-session; round-20 APPROVED-by-acceptance UNCHANGED

**Scope signal:** Fix-pass **S** (~30 min + a 3-locus canonical-literal fanout; no redesign, nothing touching the protected thesis or authority chain). GDD overall remains **XL**.
**Specialists:** systems-designer, qa-lead, game-designer, economy-designer, ux-designer, network-programmer, build-from-artifact gate (game/economy native; systems/qa/ux/network/build via general-purpose); creative-director (senior synthesis). **All seven delivering lenses + CD delivered natively — zero re-spawns, 2nd consecutive round.**
**Review depth:** full — triggered specifically to check whether round-22's 6 same-day edits spawned new instances of the recurring reconciliation class. 19th consecutive non-APPROVED full-panel verdict; round-20 APPROVED-by-acceptance stands.
**Prior verdict resolved:** Round-22's reconciliation pass — **partially.** 4 of 6 round-22 edits were clean; **2 spawned new contradictions**, and a 3rd pre-existing stale sibling (untouched by all 22 prior rounds) was reached this round.

### Summary

**Panel verdict NEEDS REVISION (19th consecutive non-APPROVED full panel) — did NOT overturn the round-20 user acceptance.** Split: game/ux/network/build = APPROVED; systems/qa = NEEDS REVISION. All 3 BLOCKING fixed in-session. **Network re-confirmed the AUTHORITY/ATTRIBUTION CHAIN SOUND a 15th consecutive round (0 BLOCKING — PROTECT):** no forge path; H.109's round-22 edit *strengthens* the mutual-exclusion protocol; position-spoof (E.34) honestly fenced with H.126. **Systems: all D.1–D.7 degenerate-free at boundaries; window derivation exact at both `[64,128]→[35.04,70.08]` edges admitted by the new `<=70.1` predicate; counts exact (122 live / E.34=32).** Headline: **the recurring reconciliation class recurred a 23rd time — 2 self-inflicted by round-22's own edits + 1 pre-existing stale sibling the prior 22 rounds never reached.**

### Required-before-clean-APPROVED (3 doc-integrity BLOCKING) — ALL CLOSED in-session

- **B1 [qa-lead, decisive — the only one on a LIVE path] — H.52 (L1623/L1625) + C.8 BT3 (L166)** carried the retired `beaconActivated and not beaconWindowSurvived` predicate as the in-window **CRAFT** emit-position selector. The sibling in-window **USE** path was hardened round-16 (`beaconActivated == true && not runOutcomeResolved`; H.93(c) locks it) and H.109's suppression gate was fixed round-22 — but the craft sibling was never reconciled. A craft completing AFTER a scatter/wipe defeat (`beaconWindowSurvived==false`, `runOutcomeResolved==true`, in the window between the terminal tick and the H.122 `_craftSessions` sweep) would **emit at a stale `beaconWorldPosition` into an ended run** — the exact orphaned-emit bug H.93(c) forecloses for the use path. → L166 + L1623 changed to `beaconActivated == true and not runOutcomeResolved`; H.52 GIVEN/THEN extended with variant (c) (post-resolution craft → `benchPosition`, never the stale beacon position). *(CD adjudicated the build-vs-qa contradiction in qa's favor — the build lens grepped the suppression-guard form and missed this emit-selector form, its documented under-scoping.)*
- **B2 [systems-designer] — H.105 THEN (L2024)** prose still said the window "falls outside `[35,70] s`" while the same sentence's predicate is `<= 70.1` — the CD-mandated `128 s → 70.08 s` edge "falls outside [35,70]" literally but is admitted by `<=70.1`, re-seeding the round-22 startup-crash trap for a QA author. Self-inflicted by the round-22 edit (predicate loosened, prose band literal left stale). → prose band → `[35.0, 70.1] s` (the enforced predicate band).
- **B3 [systems-designer / qa-lead] — determinism preamble (L1295)** still omitted **H.97** (bit-exact clock-boundary, `_clock()=startClock+2.5 → 0.50` exact, structurally identical to the enumerated H.27/H.30/H.31/H.41) and **H.89** (window-elapse + full-grace line-break) — the round-22 forward-maintenance rule's first application already violated it. → H.97 appended to the bit-exact cluster; H.89 to the time-driven cluster.

### Recommended — deferred (advisory, NOT applied; logged for the implementation/polish phase)

- **[systems]** H.105 lower-edge prints `35.05 s` where the closed form gives `35.04 s` (`64 × 0.547488 = 35.039`); add a normative gloss distinguishing the design-target band `~[35,70]` from the enforced predicate band `[35.0,70.1]` (the durable fix for the band-literal recurrence).
- **[qa]** H.52 type label Integration → Logic (matches sibling H.93, now that variant (c) makes it a deterministic position-argument assertion); H.130 dual-label → explicit Part-1/Part-2 split; H.92 shorthand gloss; H.126 CI stub.
- **[ux]** UI.1 surface-13 + VA Moment-26 still credit `OnBeaconActivated` as a countdown opener vs UI.3's authoritative `OnEscapeBeaconActivated`-alone (cleanest remaining instance of the class — low severity, same-tick same-payload, no runtime double-open); H.121 has no published BC4 MoveSpeed FLOOR (could silently invert mobile-recoverability if PC ships a BC4 slow); surface-13 ≤25% pixel budget omits the H.130 cue; H.130↔H.95/H.111 enumeration loop is one-directional.
- **[game]** "49 vs 49.3 s" display gloss.
- **[process / TD+qa]** a **CI grep hook** for the determinism-preamble enumeration + the canonical band literal, to retire the author-discipline dependence the forward-maintenance rule currently relies on (logged as a separate, larger tech-debt task — NOT this fix pass).

### Specialist disagreements (adjudicated by creative-director)

1. **Build "the `beaconWindowSurvived==false` form is extinct" vs qa "it's LIVE at H.52/C.8-BT3."** → **qa RIGHT** (CD verified L166/L1623 directly). The build lens grepped the suppression-guard form and missed the emit-selector form of the same predicate — its **3rd consecutive round** returning APPROVED while a content lens caught a real stale instance. **CD ruling: the build lens is trustworthy for wiring/lifecycle/arity (a PROTECT-grade signal like network's) but structurally CANNOT catch a class that mutates its surface form (a grep tracks one form; the class moved guard→selector). Reconciliation-clearance moves PERMANENTLY to the content axis (systems/qa); add a CI grep hook to remove the author-discipline dependence; do not run another full panel for this class.**
2. **systems (BLOCKING) vs qa (RECOMMENDED) on the H.105 band literal + preamble omission.** → **systems RIGHT** — for a doc whose entire failure history is implementers calibrating against stale literals, both are BLOCKING for the fix pass (the trap framing beats the residue framing). Rank B1 > B2 > B3 (active mis-instruction on a live path > stale trap > latent omission).
3. **Severity — MAJOR vs NEEDS REVISION.** → **NEEDS REVISION.** 23rd instance of one known class: 2 self-inflicted by round-22's non-sweep touch-up edits + 1 pre-existing stale sibling. A recurring class holds MAJOR only when it survives a sweep that *claimed to target it* — round-22 was a 6-edit touch-up, not a sweep. Enumerable, trivial fixes, sound spine.

### Specialist note (positive dissent — PROTECT)

network-programmer: the win-condition AUTHORITY/ATTRIBUTION chain is **SOUND — no forge path** (15th consecutive round). Any future change MUST NOT touch the server-authoritative completion/attribution path.

### Counts

ACs unchanged (**122**, H.130 the highest). Edge cases unchanged (**32**, through E.34). 5 GDD locations edited (C.8 BT3 L166, H.52 L1623/L1625, H.105 THEN L2024, determinism preamble L1295 ×2) + header Status + Last-Updated + systems-index row 6. No registry edit.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (round-23 reconciliation pass; 122 ACs; NOT committed).
- Systems index: `design/gdd/systems-index.md` (Crafting row 6 — round-23 note prepended; status unchanged at APPROVED-by-acceptance).
- Cross-GDD obligations still owed by siblings (unchanged): **PC** (MAJOR REVISION — T8 / `OnBeaconWindowSurvived` / `OnBeaconWindowFailed{scatter,wipe}` / all-dead suppression / `OnSquadMemberAliveChanged` / `MoveSpeed`); **ED** (`BEACON_HALF_LIFE` → `[64,128]s`, backstopped by H.105); **RM** (Not Started, load-bearing — `OXYGEN_DRAIN_BC4_FLOOR`, `canister_restore_oxygen`); **PA** (Not Started, load-bearing — `PREDATOR_BC4_MIN_COMMIT` / `PREDATOR_BC4_MAX_KNOCKBACK` / RESONANT-Coil consumer AC / Anchor readable-approach); **HUD** (Not Started — C.14 signals incl. the surface-13 denominator-change cue).

**User chose to apply the 3 BLOCKING fixes in-session and keep the system APPROVED (residue sweep, not a verdict change). Branch `crafting-round2-patch`; rounds 3–23 work all still NOT committed (awaiting user instruction per CLAUDE.md).**

---

## Review — 2026-06-16 — Verdict: NEEDS REVISION (round-24 FOCUSED arbiter review) → uncommitted RunController-arbiter migration BACKED OUT; round-20 APPROVED-by-acceptance UNCHANGED

**Scope signal:** Focused (NOT a full panel) — the user elected a scoped 3-lens review of one uncommitted change rather than the 8-lens closure panel, after the working tree was found to contain unlogged, half-applied cross-GDD architecture. Resolution work = **S** (a `git restore` + one F.4 forward-obligation note). GDD overall remains **XL**.
**Specialists:** network-programmer (native) + systems-designer + build-from-artifact (both general-purpose). No creative-director synthesis — the three lenses converged unanimously, so the orchestrator synthesized directly (scope was deliberately 3-lens, not the full panel).
**Review depth:** focused / scoped (`--depth full` was requested for Crafting, but re-scoped by user decision to the arbiter change after triage).
**Prior verdict resolved:** N/A — this round did NOT review the round-23 doc. It reviewed an **uncommitted, unlogged working-tree change** sitting on top of the committed round-23 baseline (`620e67a`).

### Why this round exists (triage finding)

`/design-review` was invoked with no target; the user chose Crafting & Items + full depth. On loading, the working tree (not `git status`-clean since `620e67a`) was found to hold **two bodies of uncommitted, unlogged work**: (1) a ~36-line propagation into the Crafting GDD introducing a **`RunController` arbiter** as the sole `RunEnded` broadcaster (Crafting raises `RunEndConditionRaised`; PC consumes the arbiter broadcast; `OnBeaconWindowFailed` demoted to a HUD cue) — cited as PC ruling `[R16-1]`; and (2) a ~106-line batch of **Player Controller** registry additions in `entities.yaml` (R16/18/20/22 PC constants + stamina-range corrections — PC-session spillover, not Crafting). Because (1) modifies the run-end **authority chain** network has affirmed SOUND for 15 rounds, the user re-scoped to a focused arbiter review rather than fire a full panel against half-applied work.

### Findings — the arbiter migration is real, half-applied, and NOT buildable (3-lens, unanimous)

- **B1 [TRIPLE-lens: network + systems + build — BLOCKING] — Victory/defeat broadcaster asymmetry.** The defeat path was rerouted through the arbiter ("the SOLE `RunEnded` broadcaster — neither PC nor Crafting broadcasts it", C.12.1 defeat bullet), but the **victory** path still has **PC broadcast `RunEnded(victory)` directly** (C.12.1 victory bullet; C.9 BCT4 `To`=BC5; C.14 "PC's T8 victory subscription"; C.5.6a victory bullet; E.25). "Sole broadcaster" is therefore **false as written**, and the arbiter's own `RUN_END_DEFEAT_HOLD ≈ 0.5 s` victory-precedence rule is **unbuildable** — victory never reaches the arbiter for it to pre-empt the held wipe. Five stale victory surfaces vs five migrated defeat surfaces.
- **B2 [network + build — BLOCKING] — `RunController` / `RunEndConditionRaised` defined NOWHERE.** Referenced ~10× across C.9/C.12.1/C.14/E.24/F.4/H.89/H.113 but with no payload, arity, `reason` enum, direction, or trust-boundary; not in the C.15 RemoteEvent surface; not in `entities.yaml` (the only crumb is `RUN_END_DEFEAT_HOLD`, a PC-owned *provisional* constant). The arbiter's server-only authority is implied, not specified — the chain can't be re-certified SOUND against an unspecified intermediary.
- **B3 [systems + build — BLOCKING] — RunController declared as a dependency NOWHERE.** F.1 (hard), F.2 (soft), F.5 (engine) all omit it, yet Crafting now structurally cannot end a defeat run without it. Violates the bidirectional-dependency rule — the document's signature 23-round failure class (a fix lands on normative surfaces but misses the dependency table).
- **B4 [network — BLOCKING] — `RUN_END_DEFEAT_HOLD` split-brain window.** During the 0.5 s hold, Crafting's `runOutcomeResolved` latch is set (terminal) while the arbiter has not yet broadcast `RunEnded` — a new "resolved-but-not-ended" interval; H.89's exactly-once mutual-exclusion guarantee becomes untestable across the arbiter boundary; the victory-precedence resolution rule is unspecified and "provisional."
- **B5 [systems + build — IMPORTANT] — `[R16-1]` citation collision.** The bracketed `[R16-1]` (PC's arbiter ruling) collides with Crafting's own unbracketed "round-16 R16-1" = the holder-threshold **freeze** ruling (E.33, H.118, H.124, G.6, C.9 — often in the same line-region). Disambiguate (e.g. `PC-R16-1` vs `CR-R16-1`).
- **I1 [systems — IMPORTANT] — H.89 not verified.** Cited as a reconciled sibling (E.24/C.12.1) but absent from the change; likely still carries the old "PC maps `OnBeaconWindowFailed`→`RunEnded`" model. Open and check during any future re-apply.

### Network position (PROTECT)

network-programmer: the chain is **AT-RISK, not BROKEN** — attribution (`beaconPlacerId`) untouched, no forge path *if* the arbiter raisers are server-side, but the win-condition authority chain CANNOT be re-certified SOUND against an arbiter whose trust boundary the GDD never specifies. The 15-round "MUST NOT touch the server-authoritative completion/attribution path" standing instruction is exactly what this change touches.

### Resolution (user decision: BACK IT OUT)

`git restore design/gdd/crafting-and-items.md` → GDD returned to the committed round-23 APPROVED baseline (all 8 uncommitted GDD hunks were arbiter-related; verified post-restore that zero arbiter content remains on any normative surface — C.9 / C.12.1 / schema / C.15 / E.24 / E.27 all clean; the arbiter tokens now appear on exactly 3 lines: the Status header, the Last-Updated header, and one F.4 note). Added a **DEFERRED forward-obligation note** to the F.4 Player Controller row capturing the full re-apply checklist (migrate the victory half too; declare RunController in F.1/F.2; register `RunEndConditionRaised` + its trust boundary + the `RUN_END_DEFEAT_HOLD` resolution rule; reconcile the `runOutcomeResolved` latch; disambiguate the citation; demote `OnBeaconWindowFailed` to HUD-only) — gated on the RunController GDD being authored + the signal registered. The round-23 model stands unchanged until then.

### Not done (intentional)

- **The 106-line PC registry batch in `entities.yaml` was NOT touched** — it is PC-session spillover (R16/18/20/22 PC constants), a separate decision the user elected to investigate next.
- **No git commit** (per CLAUDE.md — awaiting user instruction). Branch `crafting-round2-patch`; rounds 3–23 + this round-24 back-out all still uncommitted.

### Files Referenced

- Target: `design/gdd/crafting-and-items.md` (restored to round-23 baseline + Status/Last-Updated round-24 notes + F.4 deferred forward-obligation note; 122 ACs / 32 edge cases unchanged; NOT committed).
- Systems index: `design/gdd/systems-index.md` (Crafting row 6 — round-24 note prepended; status unchanged at APPROVED-by-acceptance).
- Untouched: `design/registry/entities.yaml` (106-line PC registry batch left uncommitted for a separate decision).

**User chose to BACK OUT the arbiter migration and record the focused review. The arbiter is tracked as an F.4 deferred forward-obligation, to be applied deliberately once the RunController GDD exists + the signal is registered. Branch `crafting-round2-patch`; NOT committed.**
