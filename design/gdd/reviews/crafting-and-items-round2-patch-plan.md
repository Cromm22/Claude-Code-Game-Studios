# Crafting & Items — Round-2 Patch Plan

> **Status**: APPROVED design direction (decisions locked this session) — execution split across 2 sessions
> **Created**: 2026-05-30
> **Resolves**: round-1 design-review verdict MAJOR REVISION NEEDED (24 BLOCKING, 2026-05-01)
> **Source decisions**: this session's brainstorm + `project_crafting_round2_lock` memory (2026-05-01)
> **Target doc**: `design/gdd/crafting-and-items.md` (1609 lines at round-1)

---

## Locked Design Decisions

| # | Decision | Rationale |
|---|----------|-----------|
| **D1** | **Beacon stays the sole win condition.** No alternative win-cons. | Avoids MVP scope expansion + keeps PC's T8 contract structurally intact. Resolves the `project_crafting_round2_lock` "one option among several" as: several ways to *set up and survive* the Beacon, not several win-cons. |
| **D2** | **Activation starts a survival window; victory fires only on surviving it.** ≥1 squad member alive at window-end = **victory**; full-squad wipe during the window = **defeat**. | This is the keystone. It makes the aid suite *necessary* (the round-1 dominance fix) and finally delivers Section B's "49 s holding the loudest thing" fantasy. Current C.5.6 ("T8 fires immediately at activation") is the root cause of Beacon-rush dominance — instant-win means nothing after activation matters. |
| **D3** | **Cut Composite Patch + Quiet Step Wrap.** Catalog → 5 recipes: Oxygen Canister, Dampener Coil, Signal Anchor, Squad Relay, Escape Beacon. | Both were gather/sprint-noise reducers flagged as traps in round-1 (gather emissions mostly decay before they matter). The new finale pressure is the *post-activation window*, where gather-phase reducers are even less relevant. Slots freed for post-launch content (OQ.12). |
| **D4** | **Order-of-operations collapses to a 2-stage chain.** Canonical pipeline: `base → gameplay modifiers (Dampener Coil ×0.50) → PC stationary attenuation (×0.30) → MAGNITUDE_FLOOR discard`. | With Patch + Wrap gone, the Coil is the only remaining emission modifier. The four-angle round-1 ambiguity (B5/B6/B7 + E.15 missing AC) collapses to one declared 2-stage chain. |
| **D5** | **Bench cap scales with squad size:** `BENCH_MAX_CRAFTERS_effective = min(2, ceil(squad_size / 2))`. | Round-1 B19: fixed cap=2 created a degenerate "nobody watches" state in 2-player squads (a supported config). At squad=2 → cap 1 (one crafts, one watches); squad 3–4 → cap 2. |
| **D6** | **Execution split:** Phase A (design-substance) this session; Phase B (hygiene sweep) a follow-up `/clear` session. | The window redesign ripples through ~8 sections; all-24-blockers-plus-window in one session risks context exhaustion mid-edit on a 1609-line doc. |

---

## Phase A — Design-Substance Edits (THIS session)

These edits *require* the locked decisions above. Order chosen so dependencies land before dependents.

### A1 — Recipe catalog cut (C.2)
- Remove rows 2 (Composite Patch) + 3 (Quiet Step Wrap). Renumber to 5 recipes.
- Update the "Seven recipes" / "4–8 minor recipes" prose to five / "four aid items."
- Update the Beacon-assembly worked sanity check if it referenced the cut items.

### A2 — Survival window: Beacon lifecycle (C.5 + C.9)
- **C.5.6** rewrite: BCT3 fires the `0.95` emission + `OnBeaconActivated` cue but **NOT** T8. Window starts.
- **New states** in C.9: `BC4 Beacon-Active-Window` (emitting; window counting down; T8 not fired) → `BC5 Beacon-Survived` (T8 fires) ‖ `RunEnded(defeat)` on full wipe. Decay/cleanup → `BC6`.
- **New transition** `BCT_win`: window timer reaches end AND ≥1 squad member alive → fire `OnBeaconWindowSurvived` → PC T8. Window length is **ED-owned** (`ED.D.7` ~49 s Hunt-floor lure window) — referenced, not redefined.
- **New defeat path**: full-squad wipe during BC4 → `RunEnded(defeat)`; beacon BasePart cleaned via run-end path (no `OnBeaconDecayed`, consistent with E.8).
- Update C.5.7 decay note: decay (BC6) is still object-cleanup-only and now strictly after BC5.

### A3 — PC victory contract (C.12.1 + C.15 + F.2/F.4)
- C.12.1: PC's T8 now subscribes to **`OnBeaconWindowSurvived`** (fired at window-end), not `OnEscapeBeaconActivated`.
- `OnEscapeBeaconActivated` (renamed concept: activation cue) still fires at BCT3 for HUD/audio (window-start), but is no longer the victory trigger.
- Add `OnBeaconWindowSurvived` to the C.15 RemoteEvent surface + C.14 HUD signals.
- Update F.2/F.4 PC obligations to cite the new victory signal + window semantics.

### A4 — Order-of-operations declaration (new sub-section near D.6)
- Declare the canonical 2-stage pipeline (D4). State Coil-then-stationary order explicitly.
- This is the home the round-1 four-angle ambiguity resolves into.

### A5 — Bench-cap scaling (C.3.5 + C.8 + D.2 + G.1)
- Replace fixed `BENCH_MAX_CRAFTERS = 2` with the squad-scaled effective cap (D5). Keep the constant as the ceiling; derive effective cap from squad size.
- Update D.2 `min(N, BENCH_MAX_CRAFTERS)` → `min(N, effectiveCap)`.

### A6 — Cascade deletes from the catalog cut (design-level only in Phase A)
- C.6: delete Composite Patch + Quiet Step Wrap effect bullets.
- C.10 `EquippedEffects` schema: delete `compositePatch` + `quietStepWrap` fields (keep `dampenerCoil`).
- C.13 / F.2: delete the Composite Patch ↔ Resource Node `GetEquippedEffect` interaction (simplifies RN contract).
- D.4 (Composite Patch downgrade) + D.5 (Quiet Step Wrap) formulas: delete.
- *(Edge cases, ACs, VA moments, UI badges, knobs that reference the cut items → flagged for Phase B full reconciliation, but obvious orphans removed in Phase A where cheap.)*

---

## Phase B — Hygiene Sweep (FOLLOW-UP `/clear` session)

Deterministic cleanup that *follows from* Phase A. Maps to the remaining round-1 blockers.

- **B-schema**: add `benchPosition` + `primaryCrafterId` to `CraftSession` (round-1 B8/B7); document server-crash + server-migration cleanup paths (round-1 B11) + AC.
- **B-net**: `RequestBeaconPlace` / `RequestPlaceItem` treat client position as **direction hint** bounded by server-tracked player position (round-1 B13); fix rate-limit burst math self-contradiction (round-1 B12); zero-yield-in-handler AC (round-1 B14); reassess `CRAFTING_GLOBAL_RATE_LIMIT` reachability (round-1 B15).
- **B-AC**: full Section H reconciliation against the new 5-recipe catalog + survival window — delete H.18/H.19/H.20/H.34/H.35/H.36 (cut items); add ACs for window victory, full-wipe defeat, window-survival edge cases; qa-lead rewrites (H.27 determinism, H.61 tick-window, H.63/H.64 reclassification); add the 5 missing edge-case ACs (E.2, E.4, E.11, E.19 + startup-invariant) noting E.15 is now moot (Wrap cut).
- **B-edge**: new edge cases — squad wipe DURING window (defeat), last-player-dies-at-window-end boundary, beacon decay vs window-survival ordering. Delete E.14 (Patch floor) + E.15 (Wrap grace).
- **B-VA/UI**: visual fallback for audio-only Moment 13 (Beacon activation — now also needs a window-survival visual beat); delete Moments 15–17 (Patch/Wrap equip/consume) + their UI badges; renumber.
- **B-knobs**: delete `QUIET_STEP_WRAP_REDUCTION`; window-length reference knob (ED-owned, cited); reconcile G.4 magnitude family (HEAVY still Beacon-completion).
- **B-registry**: `design/registry/entities.yaml` — remove Composite Patch + Quiet Step Wrap; add window/victory entities if any.
- **B-header**: update doc `Last Updated`, status, and append round-2 review-log entry.

---

## Phase B Reconciliation Targets Created by Phase A (precise list)

Phase A (executed 2026-05-30) deliberately left these intermediate inconsistencies for the Phase B sweep. Each is a known, tracked item — not a defect:

**Victory-timing ACs still asserting victory-at-activation (must be rewritten to window-survival):**
- `H.14` — asserts BCT3 fires emission; OK, but verify it does NOT imply victory.
- `H.15` — "BCT3 also fires PC's T8 victory signal" → **rewrite**: BCT3 fires `OnEscapeBeaconActivated` (window-start), T8 now fires on `OnBeaconWindowSurvived` at BCT4. Split into two ACs (activation-fires-window-start + window-survival-fires-T8).
- `H.44` (E.9) — "the run ends in victory" at activation → **rewrite**: activation succeeds despite activator death, but victory is at window-end; add the activator-dies-but-squad-survives-window case.
- `H.56` — "OnEscapeBeaconActivated fires exactly once" → keep, but add a sibling AC for `OnBeaconWindowSurvived` firing exactly once at BCT4.
- **New ACs needed**: window-survival victory (≥1 alive at window-end → T8); full-squad-wipe-during-window → defeat (BCT-DEFEAT); window tie-break (death on exact window-end tick favors squad).

**BCT/BC renumber citations (old BCT4=decay → now BCT5; old BC5=Decayed → now BC6; new BC5=Survived):**
- `E.8` — references "distinct from BCT4" (decay) → update to BCT5; still valid logic.
- `H.16` — "BCT4: beacon removed on natural decay" → renumber to BCT5; clarify decay is now the defensive fallback.
- `VA.3 Moment 14` (Beacon-Decay "BCT4 natural") → BCT5; consider whether a decay moment is still needed given it's normally unreachable; ADD a window-survival victory moment + a window-countdown HUD moment.
- Any other `BCT4`-as-decay references.

**Cut-item references remaining in Phase B sections (delete/renumber):**
- Edge cases: `E.1` why-note (mentions Patch/Wrap consumption semantics — reword), `E.14` (Patch floor — DELETE), `E.15` (Wrap grace — DELETE), `E.17` (Composite Patch craft example — reword to a surviving recipe).
- Knobs: `G.3` recipe-cost table rows for Patch/Wrap (DELETE), `G.5` `QUIET_STEP_WRAP_REDUCTION` (DELETE), `G.8` reused-constants rows citing D.4/D.5 (DELETE `MAGNITUDE_GATHER_*`-for-Patch + `FIRST_PULSE_GRACE_WINDOW`-for-Wrap), `MAGNITUDE_CRAFT_LIGHT` orphan in `G.4` (DELETE — only Patch/Wrap used 0.12).
- VA: Moments `15` (equip Patch/Wrap/Coil — reduce to Coil only), `16` (Patch consume — DELETE), `17` (Wrap consume — DELETE); `VA.5` audio bullet 2 (Wrap SFX — DELETE); UI badges `ui_icon_patch_32`, `ui_icon_wrap_32` (DELETE from VA.6).
- ACs: `H.18`, `H.19`, `H.20` (Patch/Wrap inventory — DELETE), `H.34`, `H.35` (D.4 — DELETE), `H.36` (D.5 — DELETE), `H.52` (Composite Patch craft example — reword), `H.55` (Patch death-return — reword to Coil-only), `H.59` (GetEquippedEffect accessor — DELETE).
- UI: `UI.1` surface 4 (equipped-effect badge — Coil only), badge list; `H.2` AC + `UI.1` "7-row" / "7 recipes" → 5.
- Count refs: `G.2` "only 7 distinct item types" → 5; `G.3` "7 recipes" → 5; `UI.1` "7-row recipe list" → 5; `H.2` "all 7 recipes" → 5.
- Open Questions: `OQ.1` (MAGNITUDE_CRAFT_LIGHT Patch/Wrap divergence — DELETE/obsolete), resolved-log "6 aid items" → "4 aid items".

**Cap reference:** `E.2` "Enforces BENCH_MAX_CRAFTERS = 2" → reword to `benchMaxCraftersEffective`.

## Cross-GDD Forward Obligations Created by This Patch

| Receiving GDD | New obligation | Source |
|---|---|---|
| **Player Controller** | T8 now fires on `OnBeaconWindowSurvived` (window-end), not on activation. PC.F.2 row + T8 trigger semantics need update. | D2, A3 |
| **Ecological Disturbance** | Window length (~49 s) is ED-owned (`ED.D.7`); Crafting references it. ED's Beacon section may need a reverse-cite that the lure window now gates victory. Confirm `ED.D.7` actually defines the window (verify when ED resumes). | D2, A2 |
| **Resource Node** | Composite Patch ↔ RN `GetEquippedEffect` interaction is **removed** — RN contract simplifies (no gather-downgrade read). | D3, A6 |
| **HUD** | New `OnBeaconWindowSurvived` + window-countdown surface; Patch/Wrap badges removed. | A3, B-VA/UI |

## Mapping to Round-1 Blocker Themes (24 BLOCKING)

| Round-1 theme | Resolved by |
|---|---|
| 1. Recipe catalog dominated strategy (Patch trap, Beacon dominance) | D1 + D2 + D3 (window makes aid necessary; traps cut) |
| 2. Modifier order-of-operations non-deterministic | D4 (2-stage chain; collapses with Patch/Wrap cut) |
| 3. Schema + state-machine defects (benchPosition, crash path) | Phase B (B-schema) + A2 (state machine rewrite) |
| 4. Networking + exploits (client-position trust, rate-limit math) | Phase B (B-net) |
| 5. UX/accessibility (iPhone SE panel, Beacon friction, visual fallback) | Phase B (B-VA/UI); panel now 5 rows not 7 (eases iPhone SE) |
| 6. Bench cap pillar collision in 2-player squads | D5 + A5 |
