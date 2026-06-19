# Predator AI — Design Review Log

Revision history for `design/gdd/predator-ai.md`. Most recent entry first.

---

## Round-4 ruling session + authoring pass + two narrow gates — 2026-06-18 — (a PATCH, NOT a verdict)

Executed the CD-prescribed path after the round-4 full panel: ruling session (RD-1..RD-6) → one reconciliation-fanout authoring pass → two narrow fresh-agent gates. The round-5 full panel is the next binding gate. NOT committed. **DO NOT predict APPROVED for round 5.**

**6 rulings (4 user-decided, all = CD recommendation; 2 folded):**
- **RD-1 (keystone)** — structural T-bound guarantee at the 2-player squad (Pillar-1): `effectiveQuietThreshold(2)` MUST be tuned strictly above a working-quietly survivor's T (BLOCKING prototype gate, OQ.12); the loud kiter pays for the squad's Disengage with their own exposure (kite-and-craft costs one of two players entirely).
- **RD-2** — OQ.14 pinned as a **hard ≤2 ms server-frame ceiling** in the body (worst-case composition enumerated) + ED dirty-flag/push-cache reservation before interface freeze; new H.64.
- **RD-3** — lock transfers are **globally telegraphed** like state changes (new H.60); preserves "every escalation announces itself."
- **RD-4** — RR-3 made a *mechanism*: named cross-GDD constraint that `BEACON_WINDOW_DURATION`/oxygen rate make an undamaged 1-HP squad loseable on air (new H.61; OQ.13 extended).
- **RD-5 (folded)** — FIX-5 grace-floor closure + D.2-margin-vs-ED-hysteresis (0.06) confirmation remain producer cross-GDD obligations.
- **RD-6 (folded)** — the 20 s sustain timer is reset only by a `≥ effectiveQuietThreshold(n)` tick, never by an n-change (death/respawn).

**Authoring pass:** rulings + the no-ruling spec/reconciliation fixes, fanned across all sections. Headlines: the two verified arithmetic traps (H.4 raycast 160→**640**; H.22a budget→gate-max **0.85**); the coverage-map letter-insert gap (H.11b/H.23b/H.56 now CR-attributed — the same class that burned Crafting rounds 21-23); H.40 double-fire negative assertion + two ReleasePredatorLock trigger paths; D.1 Patrol range 4–9→**4–7** (pairwise-safe); ai-implementability (FIX 15–17: debounce per-challenger-id scope, closed cadence-exemption list, handshake lazy-read contract + single canonical guard, per-client bearing fan-out + `PREDATOR_BEARING_UPDATE_HZ` 10–20); UX deaf-parity (FIX 21: distanceBand visual mandate, telegraphCaption, BC4 5-surface cull order, HUD GDD Brief); H.28 pinned beaconT, H.41 strict-sequence + buffered-fire coverage, H.25 reset wording, D.5 atomic-read, 1-path timeout recovery, eye-shine one-way LOD gate. **AC 65 → 70 (H.60–H.64).**

**Two narrow gates (fresh agents, REVISED doc) — BOTH clean:**
- **Gate 1 (network + performance) — SOUND.** All 5 contracts (bearing fan-out, H.40 negative assert, RD-2 ceiling, lock-transfer telegraph, replication budget) correctly + completely applied; no worldPosition leak; **network authority chain SOUND a 5th consecutive round.**
- **Gate 2 (systems + qa) — PASS.** AC count **70 confirmed exact**; both arithmetic traps + D.1 range + coverage map + H.28/H.41/H.25/H.40 rewrites verified; H.60–H.64 independently testable. One S3 residue (H.64 missing test-type letter) **fixed in-session** (→ tagged I).

**NEXT = round-5 full 7-spec `/design-review` (binding closure gate) in a fresh session.** Registry/`entities.yaml` registration still DEFERRED. NOT committed (branch `crafting-round2-patch`).

---

## Round-3 full panel + ruling session + authoring pass + two narrow gates — 2026-06-18 — (verdict + PATCH)

Round-3 full 7-spec panel → **NEEDS REVISION** (bounded — CD ruled the residue was 1 survived contradiction + 1 wrong formula + ~9 mechanical reconciles + accessibility hygiene; network authority SOUND, AC count exact, spine sound). Resolved via 4 user rulings (RR-1 lock = closest-to-hotspot; RR-2 squad-size-scaled quiet threshold; RR-3 BC4 defeat = oxygen/timer-owned; RR-4 broadcast = bearing+distance-band, retiring worldPosition) + one authoring pass (~24 fixes) + two narrow gates (both SOUND). AC 56 → 65. (Logged retroactively in round-4 — this entry was pending at the time.)

---

## Round-2 authoring pass + two narrow gates — 2026-06-18 — (a PATCH, NOT a verdict)

Executed the CD-prescribed path: ruling session → one authoring pass (reconciliation-fanout checklist) → two narrow fresh-agent gates. The round-3 full 7-spec panel remains the binding closure gate. NOT committed. **DO NOT predict APPROVED for round 3.**

**Ruling session (user-decided, all matched the CD recommendation — a coherent package):**
- **R5 (keystone)** — `GetSquadAggregateT` split: ESCALATION reads `max(player T)` (loud summons the hunt); Hunt→Disengage QUIET-CHECK reads `GetSquadAggregateT(excludeLockedPlayer)` (the chased player's forced sprint can't block the squad's earned disengage). New ED obligation: expose `GetSquadAggregateT(excludePlayer)` / per-player T.
- **R1** — solo/last-alive: empty exclude-set falls back to the lone player's own T (solo must break LOS + go quiet; hardest case by design).
- **R2** — guaranteed 12 s Disengage window OUTSIDE BC4; during BC4 the beacon-commit OVERRIDES the quiet path (no quiet-disengage in the finale — hold-and-survive or wipe). Inverted H.29 + the fully-quiet-in-BC4 edge case.
- **R3** — lock is not permanently sticky: periodic re-evaluation (`PREDATOR_LOCK_REEVAL_INTERVAL` ~3 s) re-targets the now-loudest; a quiet kiter loses the lock.
- **R4** — release on field-magnitude margin (`PREDATOR_RETARGET_FIELD_MARGIN` 0.05, > `HOTSPOT_TIE_EPSILON`); OQ.8 knob renamed + resolved.

**Authoring pass:** all 5 rulings + the 14 BLOCKING mechanical/spec fixes applied with a reconciliation-fanout audit (every normative change fanned out to FSM table / Core Rules / Formulas / Edge Cases / Tuning Knobs / ACs / Dependencies / OQs). Headline fixes: authored the absent ED.F.2a split-channel architecture (`OnPredatorStateChanged` BindableEvent + `OnPredatorLockChanged` RemoteSignal + handshake module + KnitStart ordering); reconciled Investigate→Hunt to per-hotspot fieldValue; fixed D.5 hits-to-death (`ceil(1/frac)`; worked example `100→70→40→10→1`); Investigate-speed < WALK config-gate; 5 cross-GDD config-gate ACs; FSM nil/stale recovery + F5/F6 knobs; BC4 clamp scoped to the field-read; ReleasePredatorLock ownership + no-op guard; latch lifecycle + RunEnded teardown ordering; client interpolation/≥10 Hz + single combined cue+state event; NoPath stuck-actor timeout; weak-AC rewrites + new ACs (33→56); float-precision contract + Hunt target debounce; accessibility (colorblind-safe arc, cool-neutral hit, full caption vocabulary + YOU/SQUAD, mobile lead-time gate).

**Two narrow gates (fresh agents, REVISED doc):**
- **Gate 1 (ai-programmer + network) — SOUND.** All 9 in-scope items resolved; split-channel authority/encapsulation correct, no client-trust, handshake ordering clean. Residue (fixed in-session): NET-RR-1 (`ReleasePredatorLock` needed a `runOutcomeResolved` early-return guard); NET-RR-2 (exact-worldPosition wallhack recorded as a TD ratification watch-item); coverage-map H.35-under-R2 labeling.
- **Gate 2 (systems-designer + qa-lead) — SOUND.** D.5 arithmetic correct at all three boundaries; D.1/D.4/D.2/R4 boundaries clean; new knobs non-conflicting. Residue (fixed in-session): "≈1.20 s at defaults" prose (actually 0.75 s default / 1.20 s worst-case box); AC count 58→**56** (H.22/H.32 replaced by a/b splits); H.31 `[FWD: OQ.1]` tag on the Patrol/Hunt min-duration sub-assertion.

**All residue closed in-session** (6 edits). AC count now 56. Registry/`entities.yaml` registration still DEFERRED. **NEXT = round-3 full 7-spec `/design-review` (closure gate) in a fresh session.**

---

## Review — 2026-06-18 — Verdict: MAJOR REVISION NEEDED
Scope signal: XL
Specialists: game-designer, systems-designer, ai-programmer, network-programmer, performance-analyst, qa-lead, ux-designer, creative-director (senior synthesis)
Blocking items: 19 (5 design rulings + 14 mechanical/spec) | Recommended: ~15 | Nice-to-have: ~8
Prior verdict resolved: First review

**Summary:** First full 7-spec panel on the concept-flagged highest-risk MVP system. The CD's verdict is MAJOR not because the design is weak — the thesis is sound and the spine (deterministic FSM, field-only perception, no-one-shot, navmesh-bound) is the right architecture — but because defect **classes stack across four independent axes**: a thesis-level Pillar-1 fantasy gap the math may falsify; a provable worked-example arithmetic incoherence (D.5); an entirely-absent mandated architecture the codebase already expects (ED.F.2a split-channel); and five cross-domain convergences. It is a propagation/reconciliation problem plus five real design forks, not a broken concept.

### Completeness
8/8 required sections present (Detailed Design = Detailed Rules), plus Visual/Audio, UI Requirements, Open Questions.

### Dependency graph
ED / Player Controller / Crafting & Items / Resource Node GDDs all exist. **HUD GDD does NOT exist** — the doc routes 4 player-facing surfaces + the `{state, worldPosition, audioSignature, lockedPlayerId}` broadcast contract to a nonexistent HUD GDD; UX flags the contract as too thin to build from regardless.

### Cross-domain convergences (high confidence — found by 2+ specialists)
1. **Absent ED.F.2a split-channel architecture** (`OnPredatorStateChanged` BindableEvent + `OnPredatorLockChanged` RemoteSignal, hardened over ~20 ED rounds) — ai-programmer, network, ux. Largest single PA-vs-codebase gap.
2. **Investigate→Hunt trigger contradiction** — per-hotspot `fieldValue` (FSM table + ED contract) vs `GetSquadAggregateT` (H.24). Different quantities. ai-programmer, game-designer, systems-designer.
3. **"Quiet is a reliable lever" may be FALSE at 2-player** — locked sprinter keeps aggregate ≥0.30, 20s sustain timer never completes, Disengage never fires → death spiral. Pillar 1. game-designer, systems-designer, performance.
4. **Sticky-lock kite degenerate** — one kiter (sprint 20 vs Hunt 16, stays just under LOCK_RELEASE_RANGE 60) frees 3 crafters; lock never releases. game-designer, ai-programmer, systems-designer.
5. **IEEE-754 float drift breaks determinism** — H.7/H.8 [P0] not guaranteed against accumulated drift in ED's decay sum; no precision contract. This class has bitten sibling GDDs repeatedly. systems-designer, qa-lead, ai-programmer.

### BLOCKING — design rulings the user must make (decide first; R5 is the keystone)
- **R5** — `GetSquadAggregateT` aggregation semantics: max / mean / min? R1–R4 all resolve differently depending on it. Decide first.
- **R1** — Is "quiet is a reliable lever" true at the 2-player primary squad? (Pillar 1.)
- **R2** — Guaranteed Disengage window vs "never truly leaves"? Incoherent today (enables spike→hit→quiet→safe-craft loop; makes BC4 incoherent). CD recommends: guaranteed window + beacon-commit overrides quiet during BC4.
- **R3** — Sticky-lock kite: intended bait or unintended dominant strategy? Make kiting costly, not free.
- **R4** — Define "genuinely hotter hotspot" for lock release. OQ.8 knob named in studs (spatial) but rule says "hotter" (magnitude); H.12 untestable.

### BLOCKING — mechanical / spec fixes (no ruling needed)
1. Author the absent ED.F.2a split-channel architecture (pull from ED.F.2a row 3 verbatim); also fixes the thin HUD contract.
2. Reconcile Investigate→Hunt trigger across FSM table, H.24, ED contract.
3. Fix D.5 hits-to-death arithmetic — "exactly 4 hits" only true at 0.30 (5 at 0.20, 3 at 0.40); `timeToDeath` hardcodes `(4−1)×3`; worked example `100→30→60→30→0` incoherent (→ `100→70→40→10→1`).
4. Investigate-speed invariant — safe-range max 14 > WALK 12 contradicts "sub-walk"; cap <12 or add config-gate.
5. Cross-GDD config-gates + ACs — min `BEACON_LINE_BREAK_GRACE` (D.4 unrecoverable at grace=0); `AUDIO_RANGE > SIGNAL_ANCHOR_DETECTION_RADIUS`; `MELEE_RANGE < BEACON_HOLD_RADIUS` AC; `HOTSPOT_TIE_EPSILON < MAGNITUDE_FLOOR` + `DAMAGE_FRACTION < 1.0` ACs.
6. FSM nil/stale-signal recovery — Patrol→Investigate stale-signal rule; re-eval-before-lock guard on Hunt entry; publish `STALE_AGE_THRESHOLD` + `INVESTIGATE_FALLBACK_DURATION` knobs (ED.F.2a F5/F6, both absent).
7. BC4 clamp contradiction — H.28 clamps all reads, H.29 needs raw; clamp only the beacon-field read for commit, not the aggregate-T disengage check.
8. `ReleasePredatorLock` ownership + not-locked no-op guard — PA says "PC fires," ED.C.1.11 routes via OnPlayerDied fan-out (double-call risk).
9. `predatorCausedImminent` latch clear lifecycle + `runOutcomeResolved` teardown ordering — orphaned-imminent false oxygen deduction; named `RunEnded` subscription + teardown idempotency.
10. Client interpolation / replication rate — ≤4Hz = 4–5.6 studs of melee-creature lurch under latency; specify interpolation/dead-reckoning or raise to ≥10Hz (~1KB/s, in budget). Changes the contract — not deferrable.
11. NoPath stuck-actor timeout — direct-locomotion can fight geometry 15s; 2s stuck-detection re-path + max direct-locomotion duration.
12. Missing/weak ACs — Disengage 12s-duration (H.26 passes a 0.1s Disengage), capped-Hunt-tier AC (ED.F.2a row 6), heard-before-seen behavioral trigger, knockback navmesh-clamp; rewrite H.2/H.4/H.16/H.22/H.28/H.31/H.32/H.33.
13. Float-determinism precision contract + Hunt target-change debounce — coordinate with ED before its interface freezes.
14. Accessibility (doc promises it in prose, under-delivers) — amber vignette arc hue-only (fails ~8% of men); 3-caption vocabulary collapses Investigate & Hunt into "APPROACHING", no attack caption. Add shape/luminance redundancy + expand captions (+ "YOU vs squadmate locked").

### Recommended (non-blocking)
Investigate sub-walk out-walkable (burst-gather-then-quiet optimal); death attribution magnitude- not recency-weighted; HUNT=19 sprint advantage only 1 stud/s; D.3 closest-to-hotspot can lock a far player; dist² 3D-vs-XZ vs ED's XZ grid; **TD-ratification watch-item:** "no relevancy gating" broadcasts exact worldPosition = wallhack destroying heard-before-seen (consider bearing+distance-band); OQ.5 ED-accessor cost — reserve dirty-flag push-cache option in ED contract now; RaycastParams whitelist + ray-length cap; Neon LOD dwell floor; repath throttle as named knob; BC4 HUD density (9–11 elements on iPhone-SE); min audio-vs-visual delta; caption font-size/reduced-motion.

### Nice-to-have
`PREDATOR_LUNGE_DAMAGE` vs `DAMAGE_FRACTION_PER_HIT` naming mismatch; `PREDATOR_BC4_MAX_KNOCKBACK` self-described as misnamed — resolve before `entities.yaml` registration; sticky-kite inverse AC; O2-jerk compound-animation; caption text-change debounce.

### CD-recommended path (do NOT run a fresh full panel next)
1. **Ruling session first** — resolve R5 (keystone) → R1 → R2 → R3 → R4 in dependency order.
2. **ONE authoring pass** with a mandatory reconciliation-fanout checklist — apply rulings + all mechanical fixes + accessibility fixes; fan out every normative change to the FSM table, ACs, worked examples, Tuning Knobs, AND the ED/PC/Crafting cross-GDD obligations.
3. **TWO narrow fresh-agent gates** — (i) ai-programmer + network on the ED.F.2a split-channel contract + the replication-rate decision; (ii) systems-designer + qa-lead on the D.5 arithmetic, the determinism/precision contract, and the rewritten ACs.
4. **Reserve the full 7-spec panel for round 3** as the single closure gate.
- If ED is near interface-freeze, the ED.F.2a contract + the OQ.5 push-cache reservation jump to the front regardless of the ruling session.

**DO NOT predict APPROVED for round 2.** Registry constant registration remains DEFERRED until the numbers settle. Consider `/prototype predator-ai` (highest-risk, OQ.6). NOT committed (branch `crafting-round2-patch`).
