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
