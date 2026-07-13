# Crafting & Items — Round-15 Patch Plan (Reconciliation Checklist)

**Created**: 2026-06-05 — round-15 authoring pass (CD rulings + ~9 mechanical blockers).
**Mandate**: the round-14 CD required this pass carry an explicit reconciliation checklist for
the new-signal / new-mechanism seam class ("a new signal must inherit its sibling's solved
contracts — debounce, win-tick suppression, colorblind, reduced-motion").
**This file is the checklist.** Every box must be ticked before the round-15 narrow gates.

---

## CD RULINGS (user-approved 2026-06-05; all 4 forks = recommended option)

| # | Ruling | Decision |
|---|--------|----------|
| 1 | Hold-zone + grace (load-bearing) | `BEACON_HOLD_RADIUS` 30→**12**; hold req `≥1`→**`requiredHolders = ceil(#aliveMembers/2)`**; `BEACON_LINE_BREAK_GRACE` stays **3 s**, range cap 0–6→**0–4**; line-break threshold moves "empty"→"below requiredHolders" |
| 2 | Signal Anchor (game F2) | Reframe as **pre-activation / opening-read recon**; drop "decisive during the survival window" |
| 3 | In-window craft (game F5) | In-window craft burst **emits at beacon position** (extend EC-3 beacon-position rule to crafts) |
| 4 | RESONANT (economy E-2) | Binding RM/PA forward obligation — **≥1 Coil worth crafting per winning run** (F.4) |
| 5 | E-1 (default) | Restate F.4 oxygen inequality unit-independently: `ITEM_STACK_MAX × canister_restore_s × DRAIN_per_s < oxygen_pool_critical` |
| 6 | F6 (default) | `PREDATOR_BC4_MIN_COMMIT` → binding F.4 obligation: telegraph BC4 commit w/ reaction lead + no one-shot of a sole holder; BC4 winnable by holding |

---

## THE CANONICAL TRANSFORM (apply identically at every touch point)

- **New derived value**: `requiredHolders = math.ceil(#RunSession.aliveMembers / 2)`, recomputed **each BC4 tick** from the current alive-set. `ceil(1/2)=1` (lone survivor needs 1 — himself); `ceil(0/2)=0` but `aliveMembers`-empty is the **wipe** path, evaluated separately.
- **Held predicate**: `held ⟺ #windowAliveInRadius >= requiredHolders`.
- "snapshot **non-empty** / hold intact" → "snapshot meets the holder threshold (`#windowAliveInRadius >= requiredHolders`)".
- "snapshot **empty** / line broken" **(scatter context)** → "snapshot **below** the holder threshold (`#windowAliveInRadius < requiredHolders`) while members remain alive".
- **WIPE context unchanged**: still `aliveMembers` empty (immediate, no grace).
- **Field rename**: `_lineBreakEmptySince` → **`_lineBreakSince`** (the name "Empty" encoded the old binary; the trigger is now "below threshold", not "empty"). Stamped when `#windowAliveInRadius < requiredHolders`; reset when `>= requiredHolders`.
- `BEACON_HOLD_RADIUS` 30 → **12** studs.
- `BEACON_LINE_BREAK_GRACE` stays 3 s, range 0–6 → **0–4** (game-designer anti-kiting cap; now traversable in a 12-stud zone, resolving the ux mobile-recoverability finding).
- **NEW knob `BEACON_LINE_BREAK_RESTORE_DEBOUNCE`** (the quadruple-lens debounce fix): default **6 ticks**, range 1–30, category Feel. Governs ONLY the `OnBeaconLineBreak(broken=false)` HUD restore edge — see "mechanical blockers" below.

### Lone-survivor & respawn edges (must be documented, not silent)
- **Lone survivor**: `alive=1 ⇒ required=1` — the lone survivor wins iff they are in-radius at window-end; their death = wipe. (Unchanged outcome; reworded to reference `requiredHolders`.)
- **Respawn raises the bar (NEW edge case — add to E)**: a respawn grows `aliveMembers`, so `requiredHolders` can rise mid-window (2→3 alive moves required 1→2). The respawned member spawns out-of-radius, so a hold that was sufficient can momentarily fall below threshold and start the grace; a roamer/the respawned member must reach the beacon within `BEACON_LINE_BREAK_GRACE`. Logical ("half the living squad holds") and recoverable in the 12-stud radius. **FLAG to user in final summary for confirmation.**

---

## TOUCH-POINT MAP (the reconciliation checklist — tick each)

### A. Rule home / fantasy
- [ ] **Section B** (L14, L18): "hold the line" fantasy still true (it is — the holder-count change *strengthens* it). Signal Anchor prose (L18): drop "decisive during the survival window", reframe as pre-activation recon (Ruling 2).
- [ ] **C.5 point 6a Victory** (L111): `≥1 … within BEACON_HOLD_RADIUS=30` → `requiredHolders within BEACON_HOLD_RADIUS=12`; "~30 studs leaves room to kite around the plinth" line → rewrite for 12-stud tight central hold.
- [ ] **C.5 point 6a Defeat-line-break** (L112): "snapshot empty" → "below requiredHolders"; grace prose.
- [ ] **C.5 point 6a Aid-necessity** (L113): fold F6 `PREDATOR_BC4_MIN_COMMIT` ruling (telegraph + no one-shot) — escalate wording from target to binding.
- [ ] **C.5 point 5** (L108 tail): RequestPlaceItem clamp order — radius unaffected, no change needed (verify).

### B. State machine (C.9)
- [ ] **BC5** (L189): `≥1 … within 30` → `requiredHolders within 12`.
- [ ] **BCT4** (L199): "non-empty snapshot … ≥1 … within 30" → "snapshot `>= requiredHolders` … within 12".
- [ ] **BCT-DEFEAT** (L200): wipe (aliveMembers empty — unchanged) + scatter ("snapshot empty while members alive" → "snapshot below requiredHolders while members alive"); `_lineBreakEmptySince`→`_lineBreakSince`.
- [ ] **Concurrency block** (L208): "non-empty snapshot" phrasings → threshold.
- [ ] **C.9 step (a)** (L209): "if non-empty, hold intact" → "if `>= requiredHolders`".
- [ ] **C.9 step (b)** (L210): "if empty, line broken" → "if `< requiredHolders`". **B-1 fix**: make step (b) **compute-only** (stamp/check grace, set a `pendingScatter` flag) — do NOT fire the scatter terminal here; fire it AFTER step (c) gated on `aliveMembers` still non-empty (so wipe wins the tick). **N14-B1 fix**: `OnBeaconLineBreak` must NOT fire on a wipe tick — guard on `not runOutcomeResolved` and on `aliveMembers` non-empty.
- [ ] **C.9 step (c)** (L211): wipe check (aliveMembers empty — unchanged); now also: if a `pendingScatter` was computed in (b) AND aliveMembers still non-empty after both drains AND grace elapsed → fire scatter here (B-1 ordering).
- [ ] **C.9 step (d)** (L212): hold-state crossing + squad HOLDING/BROKEN — HOLDING ⟺ `>= requiredHolders`; add the `BEACON_LINE_BREAK_RESTORE_DEBOUNCE` rule; colorblind shape/icon (ux F3); B-5 dual-signal consumer.
- [ ] **C.9 post-steps prose** (L213): "window-survival (a) requires non-empty" → threshold; continuous-hold prose.

### C. Data model (C.10)
- [ ] **aliveMembers** (L241): victory-snapshot references → threshold; `requiredHolders` mention.
- [ ] **_lineBreakSince** (L245, rename from `_lineBreakEmptySince`): trigger "snapshot EMPTY while ≥1 alive" → "snapshot BELOW requiredHolders while ≥1 alive"; B-1 transient-stamp note still valid.
- [ ] **windowAliveInRadius derivation** (L252): add `requiredHolders` definition; radius 30→12; "both checks read this snapshot" → both apply the threshold to it.
- [ ] **hold-state crossing** (L254): squad-level `OnBeaconLineBreak` on HOLDING↔BROKEN edge of `(#snapshot >= requiredHolders)`; add debounce; colorblind.
- [ ] **invariants** (L256): `_lineBreakSince` non-nil "members alive, none in radius" → "members alive, fewer than requiredHolders in radius".
- [ ] **RunStarted init** (L250): `_lineBreakEmptySince`→`_lineBreakSince`; add restore-debounce counter field init if needed.

### D. Edge cases (E)
- [ ] **E.24** (L807): wipe (unchanged semantics; verify wording).
- [ ] **E.27** (L828): "no alive member within BEACON_HOLD_RADIUS" → "fewer than requiredHolders within"; radius 30→12; `_lineBreakEmptySince`→`_lineBreakSince`.
- [ ] **E.25 / E.26** variants: threshold + radius.
- [ ] **Lone-survivor clause** (L475): "≥1 alive within 30" → "requiredHolders (=1 when alive=1) within 12"; confirm lone survivor still wins.
- [ ] **NEW E.## — respawn-raises-requiredHolders** edge case (document the feel consequence).
- [ ] **EC-3 / in-window emission**: extend beacon-position emission to in-window CRAFT burst (Ruling 3) — Signal Anchor craft case (L766 area) + F1 craft burst (L1136).

### E. Tuning knobs (G.6 / G.7)
- [ ] **BEACON_HOLD_RADIUS** row (L1019): 30→12, range 15–45→8–20, rewrite Too-Low/Too-High.
- [ ] **BEACON_LINE_BREAK_GRACE** row (L1022): range 0–6→0–4, note traversability@12.
- [ ] **NEW BEACON_LINE_BREAK_RESTORE_DEBOUNCE** row.
- [ ] **NEW (optional) requiredHolders derivation note** under G.6 (it is derived, not a free knob).

### F. Signals / HUD (C.14 / UI)
- [ ] **OnBeaconWindowSurvived** (L336): "≥1 … within BEACON_HOLD_RADIUS" → threshold + 12.
- [ ] **OnBeaconLineBreak** (L1232): debounce note; colorblind; B-5 single consumer; "N/M holding" now meaningful (M = requiredHolders).
- [ ] **UI surface 13**: HOLDING/BROKEN + colorblind shape/icon + "N/M holding" + debounce.
- [ ] **UI.3**: add the dual-signal consumer row (B-5) — `OnBeaconActivated` vs `OnEscapeBeaconActivated`.
- [ ] **Moments 26/27**: hold ring radius 30→12.

### G. Forward obligations (F.4)
- [ ] **RM oxygen inequality** (E-1): restate unit-independently.
- [ ] **PA min-commit** (F6): telegraph + no-one-shot, binding.
- [ ] **RESONANT/Coil minimum** (E-2): ≥1 Coil worth crafting per winning run.

### H. Acceptance Criteria
- [ ] **H.73** (L1742): victory ≥1@30 → requiredHolders@12.
- [ ] **H.76 / H.77 / H.78**: tie-break variants → threshold + radius.
- [ ] **H.89** (L2074): wipe vs scatter variants → threshold.
- [ ] **H.92** (L1889): boundary `==30.0` → `==12.0`.
- [ ] **H.94** (hold-state signal): threshold + debounce.
- [ ] **H.95** (WCAG flash cap): EXTEND to cover `OnBeaconLineBreak` banner (quadruple-lens).
- [ ] **H.108** (respawn re-add): drive through `_enqueueReadd` seam in WHEN (qa F-T2-1); add de-dup AC.
- [ ] **H.114** (L2062): `_lineBreakSince` rename; threshold.
- [ ] **H.115 / H.116**: scatter-vs-wipe precedence (B-1); windowDurationSeconds.
- [ ] **NEW AC — restore-debounce** (the `OnBeaconLineBreak(broken=false)` min-consecutive-ticks rule).
- [ ] **NEW AC — break-within-grace → recover → WIN** (qa F-T3-1).
- [ ] **NEW AC — mobile-recoverability** (ux F1: a member can traverse the 12-stud radius back inside the 3 s grace).
- [ ] **NEW AC — respawn-raises-requiredHolders** edge.

### I. Registry
- [ ] **entities.yaml**: `BEACON_HOLD_RADIUS` 30→12; `BEACON_LINE_BREAK_GRACE` range; add `BEACON_LINE_BREAK_RESTORE_DEBOUNCE`; `requiredHolders` note.

---

## MECHANICAL BLOCKERS (no ruling — close in this pass)
1. [ ] **Quadruple-lens debounce**: `BEACON_LINE_BREAK_RESTORE_DEBOUNCE` knob (6 ticks) + rule: `OnBeaconLineBreak(broken=true)` fires immediately on first below-threshold tick (fail-fast alarm); `broken=false` fires only after `BEACON_LINE_BREAK_RESTORE_DEBOUNCE` **consecutive** at-or-above-threshold ticks. HUD-only; the `_lineBreakSince` terminal grace clock is the authority and is unaffected. Extend H.95.
2. [ ] **B-1 scatter-vs-wipe precedence**: step (b) compute-only; fire scatter after step (c), gated `aliveMembers` non-empty.
3. [ ] **N14-B1 wipe-tick line-break guard**: `OnBeaconLineBreak` never fires on a tick `OnBeaconWindowFailed` fires; guard on `runOutcomeResolved` + aliveMembers non-empty. New AC.
4. [ ] **ux F3 colorblind**: HOLDING/BROKEN gets a shape/icon redundancy (not color-only), mirroring the Coil surface-4 fix. New/extended AC.
5. [ ] **B-3 re-add positioned predicate**: define the concrete production trigger for "HumanoidRootPart positioned" (e.g. first server Heartbeat after `CharacterAdded` on which `HumanoidRootPart.Position` is non-origin / a `RunService.Stepped` post-spawn settle). Make it observable/testable.
6. [ ] **B-5 dual-signal consumer**: assign `OnBeaconActivated` (HUD activation cue) vs `OnEscapeBeaconActivated` (window-start countdown) each a single non-overlapping client consumer; add the missing UI.3 row.
7. [ ] **qa F-T2-1**: H.108 WHEN drives the re-add through `_enqueueReadd`; add `_pendingReadds` de-dup AC.
8. [ ] **qa F-T3-1**: break-within-grace → recover → subsequently WIN AC.
9. [ ] **ux F1 mobile-recoverability AC**.

---

## PROGRESS LOG
- 2026-06-05: plan created; rulings locked.
- 2026-06-05: **DONE** — field rename `_lineBreakEmptySince`→`_lineBreakSince` (global); G.6 (radius 30→12, BEACON_HOLD_MIN_HOLDERS derived row, grace range 0–4, BEACON_LINE_BREAK_RESTORE_DEBOUNCE row); C.10 (windowAliveInRadius+requiredHolders, _lineBreakSince trigger, _lineBreakRestoreTicks field+init, hold-state crossing debounce+colorblind+wipe-guard, invariants, 12-stud LD note); C.9 (BC5, BCT4, BCT-DEFEAT wipe/scatter+B-1, single-decision-point, steps a/b/c/d w/ B-1 compute-only + N14-B1 skip-on-resolved + debounce + colorblind, post-steps prose); C.5.6a (victory, defeat, aid-necessity F6); stragglers (schema beaconWindowSurvived, OnBeaconWindowSurvived signal, lone-survivor clause, E.27, E.28-why); NEW E.33 respawn-raises-requiredHolders.
- 2026-06-05: **DONE (batch 2)** — F.4 RM row E-1 unit-independent inequality; F.4 PA row (c) winnable-by-holding + (d) RESONANT/Coil minimum; OQ.15 updated; Signal Anchor reframe (Section B + C.7); EC-3/Ruling-3 in-window CRAFT emits at beacon (E.17 rewrite + BT3 BC4-conditional + H.52 rewrite).
- 2026-06-05: **DONE (batch 3)** — ACs H.73/H.77/H.85/H.89/H.92/H.95/H.108/H.114 (threshold + radius + B-1 + debounce); new H.118 (respawn), H.119 (restore-debounce), H.120 (break-within-grace→win, qa F-T3-1), H.121 (mobile-recoverability, ux F1); UI surface 13 (threshold/colorblind/debounce/N-of-M); UI.3 dual-signal split (B-5) + colorblind row; C.14 `OnBeaconLineBreak` signal-def CONCRETE debounce (was circular — quadruple-lens); B-3 `POSITION_SETTLED_EPSILON` concrete predicate (C.10 + G.6); entities.yaml (radius 12, grace 0–4, `_lineBreakSince` rename, + `BEACON_HOLD_MIN_HOLDERS`/`BEACON_LINE_BREAK_RESTORE_DEBOUNCE`/`POSITION_SETTLED_EPSILON`); GDD header status + Last-Updated.
- 2026-06-05: **DONE (sweep)** — straggler reconciliation: C.5/C.9/C.10/C.12/C.14/E.17/E.24/E.27/E.30/F.2/F.4 PC rows + H.44/H.52 win-predicate phrasings all moved to `requiredHolders`/12-stud; confirmed only `SIGNAL_ANCHOR_DETECTION_RADIUS = 30` (unrelated) remains at 30; `_lineBreakEmptySince` fully renamed in the GDD (0 left); the C.14 signal-def circular debounce REPLACED with the concrete rule.
- 2026-06-05: **ALL CHECKLIST ITEMS COMPLETE.** Next = systems-index + review-log update, then the round-15 narrow gates (re-scoped build-from-artifact + narrow network re-confirm) in a fresh session. **DO NOT predict APPROVED for round-16.** **FLAG to user: E.33 respawn-raises-requiredHolders feel consequence — confirm or switch denominator.**
