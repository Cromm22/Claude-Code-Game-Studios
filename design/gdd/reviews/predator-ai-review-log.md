# Predator AI — Design Review Log

Revision history for `design/gdd/predator-ai.md`. Most recent entry first.

---

## Round-6 full panel + authoring pass — 2026-06-19 — Verdict: NEEDS REVISION (bounded, converging)
Scope signal: XL
Specialists: game-designer, systems-designer, ai-programmer, network-programmer, performance-analyst, ux-designer, qa-lead, creative-director (senior synthesis)
Blocking items: 11 (after dedup; 1 new correctness + a convergent mechanism cluster + perf + AC sub-cases + 8 ux completeness) | Recommended: ~20 | Nice-to-have: ~6
Prior verdict resolved: Yes — round-5 patch (committed `98cb926`) was the prior state; this is the round-6 binding closure gate.

**Process:** all 7 specialists delivered natively (no re-spawns). ALL 7 returned NEEDS REVISION. The two historically-fragile axes came back CLEAN: **systems independently re-verified the reconciliation-drift class is CLOSED** (`0.85` at every D.4 gate site; surviving `0.75` are legitimate worked-examples), and **qa independently re-counted AC = 74 exact** (no dupes/gaps/orphans). **Network re-affirmed the authority spine SOUND on all 7 previously-reviewed surfaces (a 6th-round PROTECT).**

**Headline — the only genuinely-NEW correctness defect:** **NET-C-1** — Roblox auto-assigns NPC `NetworkOwnership` to a proximate client unless the server calls `SetNetworkOwner(nil)`. CR1 claimed server-authority but never asserted this; a proximate exploiter could reposition the predator, corrupting contact/lock/LOS. Not interrogated in 7 prior rounds (a real new surface, not residue). This single item is what earns the verdict.

**Convergent "mechanism-implicit" cluster (ai + qa + perf hit the same gaps — authored as ONE sub-section):** FIX 25 stale-token contract unspecified (storage/increment/comparison); FIX 24 handshake storage form (fields-on-table vs upvalue) not mandated; FSM Hunt-exit doesn't enumerate which 3 timers cancel; debounce counter reset-at-boundary ambiguous. Plus perf H.64 self-consistency (per-client bearing budget ambiguous → could breach 2 ms; protocol undersamples the transition-burst spike), OQ.5 either/or → unconditional reservation; qa AC sub-cases (H.25 RD-6, H.33 truism); 8 ux HUD-brief completeness lines.

**Governance call (CD) — the 3 game-designer "design BLOCKINGs" all RE-ARGUE settled user rulings; NO new ruling taken:** F1 (n=2 quiet-lever prototype-contingent) already governed by RD-9 + H.66 + OQ.12; F2 (loud-kiter dominant at n≥3) already governed by RD-8 + OQ.15; F3 (BC4 predator-as-non-threat) — the no-one-shot keystone is PROTECTED (RR-3/RD-4, ruled), legitimate residue is a one-paragraph Player-Fantasy prose-honesty fix only. Per precedent a panel CANNOT overturn a user-accepted ruling. **One qa "blocking" (H.31 missing `[FWD: OQ.1]`) was a FALSE POSITIVE — H.31 already carries the tag.**

**Authoring pass (ONE pass, this session):** all 11 blocking + recommended folded with reconciliation-fanout. New constants/fixes: H.68 (NET-C-1), H.69 (`PREDATOR_PATH_REQUEST_TIMEOUT` config-gate), FIX 24-b/25-b/26/27, `INVESTIGATE_MIN_DWELL_DURATION` named. **AC 74 → 76** (header accounting + coverage map + [FWD]/[PROTO] lines reconciled; grep-verified 76 definitions; reconciliation drift NOT recurred). Spine + network authority + formulas + AC count all clean.

**CD-prescribed closing path:** round-7 = a NARROW gate (network re-confirm — PROTECT, do not re-panel; + ai/qa/systems anchor on the mechanism cluster + new ACs), NOT a full 7-spec panel. **PROTECT (do not re-open):** the 7 network surfaces, all formulas + the closed drift class, the no-one-shot BC4 keystone, and RD-7..RD-10 as ruled. **DO NOT predict APPROVED for round-7.** Registry/`entities.yaml` registration still DEFERRED. Committed this session (branch `crafting-round2-patch`).

---

## Round-5 full panel + ruling session (RD-7..RD-10) + authoring pass — 2026-06-19 — Verdict: NEEDS REVISION (bounded)
Scope signal: XL
Specialists: game-designer, systems-designer, ai-programmer, network-programmer, performance-analyst, qa-lead, ux-designer, creative-director (senior synthesis)
Blocking items: 12 (4 design forks RD-7..RD-10 + ~8 mechanical/spec/testability) | Recommended: ~15 | Nice-to-have: ~9
Prior verdict resolved: Yes — round-4 NEEDS REVISION (bounded) patch is superseded; this is the round-5 binding closure gate.

**Process:** all 7 specialists delivered natively (no re-spawns). ALL 7 returned NEEDS REVISION from their domain. **Network re-affirmed the authority + attribution chain SOUND a 6th consecutive round (PROTECT).** qa-lead independently re-counted AC = 70 exact pre-pass (no dupes/gaps/orphans; the letter-insert class did NOT recur in the AC IDs).

**Headline (the recurring reconciliation class, 4th recurrence — DE-ESCALATES not escalates):** stale D.4 grace-floor arithmetic — round-4 corrected H.22a to `8/20 + 0.30 + 0.15 = 0.85` (gate-max constants) but left **H.42 "≈0.75 at defaults"** and the **Crafting-interaction note (line 66) "8/20 + 0.35 ≈ 0.75"** (a 3rd, differently-wrong derivation omitting `t_latency`). systems+qa convergent, BLOCKING. CD verified directly that the gate FORMULA is correct at every live site (line 128/233) — only worked-example/prose figures are stale, and round-5 was a ruling+authoring round (not a sweep claiming this class closed) — so the recurrence is the panel finding what narrow gates structurally cannot see, hence NEEDS REVISION not MAJOR.

**Other convergent findings:** D.5 no-one-shot atomic-read race is inter-callback not intra (game+ai+qa); RD-1/OQ.12 Pillar-1 "quiet is a lever" prototype-contingent + H.53 mislabeled [P0] (game+qa); CONTACT distanceBand leaks sub-visual position before LOS (network+ux); ≤2 ms ceiling has no sub-budget/measurement protocol + ED-freeze gate (perf+qa); HUD forward-reference losses ×3 (ux); handshake lazy-read not Luau-prescriptive (ai+network).

**4 user rulings (all = CD recommendation):**
- **RD-7** — CONTACT distanceBand re-tied to `PREDATOR_VISUAL_RANGE` (not `PREDATOR_MELEE_RANGE`): CONTACT means "within LOS/visual range," so no sub-visual position is inferable before LOS. Band def + H.48a anti-leak assertion updated.
- **RD-8** — loud-kiter-at-range (~55 studs, just inside `PREDATOR_LOCK_RELEASE_RANGE`) accepted as a **bounded division-of-labor tradeoff** (costs one whole player; RD-1 cost at n=2, 25–33% throughput at n≥3). Documented in the kiting edge case + new **OQ.15** (prototype-balance sufficiency at n≥3).
- **RD-9** — "quiet is always a lever" marked **prototype-contingent at the n=2 primary squad in the Player Fantasy** (structurally guaranteed only at n≥3); H.53 scoped to threshold-comparison-logic-only; new **H.66 [PROTO][BLOCKING]** for the RD-1 n=2 structural bound (real gather-cadence T vs threshold).
- **RD-10** — ≤2 ms server-frame ceiling given a per-component **sub-budget** (raycasts ≤1.0 / ED accessors ≤0.4 / lock+waypoint-ingestion ≤0.4 / per-client bearing ≤0.2) + a **p95 measurement protocol** in H.64 + an **ED pre-freeze BLOCKING gate** on the OQ.5 push-cache reservation.

**Authoring pass (ONE pass, reconciliation-fanout):** the decisive `0.75`→`0.85` propagation; D.5 inter-callback `Health>1` guard (FIX 23, new H.65); FSM-table Hunt→Patrol 5 s direct-locomotion-cap row (was Edge-Cases-only); handshake lazy-read storage prescription (FIX 24); `PREDATOR_PATH_REQUEST_TIMEOUT` separate in-flight timeout + stale-token discard (FIX 25); `DISENGAGE_SPEED ≤ Patrol` config-gate (FIX 22, range 4–8→4–6, folded into H.14 + D.1); ReleasePredatorLock nil-target no-op guard (B-3); HUD closes — `attackCaption` wire field + new H.67, `telegraphCaption` enumerated string table, Patrol `PRESENCE ABSENT` baseline cue, eye-shine one-way gate stated FIRST as mandatory, ux I-3 caption-preempt + network I-2 Channel-B precedence; H.61 split → H.61a/H.61b, H.31 → [P0][FWD]. **AC 70 → 74** (header accounting + coverage map + [FWD]/[PROTO] lines all reconciled; count grep-verified at 74, all stale-arithmetic patterns at 0 occurrences).

**CD-prescribed closing path:** TWO-to-THREE narrow fresh-agent gates (systems+qa anchor on the reconciliation/AC fixes; network re-confirm only — PROTECT, do not re-panel; ai-programmer recommended on FIX 24/25 + the 5 s-cap row) → reserve the full 7-spec panel for **round-6** (binding gate). **DO NOT predict APPROVED for round-6.** NOT committed (branch `crafting-round2-patch`). Registry/`entities.yaml` registration still DEFERRED.

**Narrow gates RUN — 2026-06-19 — ALL THREE CLEAN (round-5 pass VERIFIED):**
- **systems-designer → GATE: PASS.** The DECISIVE D.4 grace-floor reconciliation class is **CLOSED** — `0.85` present at every gate-assertion site (D.4 config-gate, H.22a, H.42, Crafting note); the 3 surviving `0.75` occurrences are all legitimate (budget-case worked example + history); the differently-wrong `8/20 + 0.35 ≈ 0.75` derivation is gone (grep `0.35` = 0). FIX 22 (`DISENGAGE_SPEED ≤ Patrol`, range 4–6) consistent at D.1/H.14/Tuning; FIX 25 (`PREDATOR_PATH_REQUEST_TIMEOUT`) in Tuning + Edge-Cases; D.5↔H.65 inter-callback `Health>1` guard consistent; FSM Hunt row carries the 5 s direct-loco-cap→Patrol exit. No other numeric contradiction.
- **qa-lead → GATE: PASS.** Independent re-count = **74 exact** (67 ints − 5 split standalones + 10 a/b + 2 letter-inserts). No dupes/gaps/orphans H.1–H.67. H.61a/H.61b/H.65/H.66/H.67 present, testable, correctly tagged ([P0]/[P0][FWD]/[P0]/[PROTO][BLOCKING]/[U]); H.31 = [P0][FWD: OQ.1]. Header accounting + [FWD]/[PROTO] summary lines + coverage map all reconcile; no phantom IDs.
- **network-programmer → AUTHORITY SPINE: SOUND (7th round).** RD-7 distanceBand re-tie to `PREDATOR_VISUAL_RANGE` + H.48a anti-leak assertion CLOSE the pre-LOS sub-visual position leak with no new leak (CONTACT never resolves without LOS-precondition range). Zero `worldPosition` on either broadcast channel (all 8 doc occurrences are negations/history). Split-channel A(server-internal)/B(client) intact after the HUD wire-up; Channel-B lock-status precedence correct. FIX 23/24/25 + HUD changes introduce zero client-trusted gameplay value.
- ai-programmer gate on FIX 24/25 was OPTIONAL (CD-recommended, not user-requested) — NOT run; deferred to the round-6 panel's ai-programmer.

**NEXT = round-6 full 7-spec panel (binding closure gate, fresh session). DO NOT predict APPROVED.** Committed this session.

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
