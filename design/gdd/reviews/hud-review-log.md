# HUD GDD — Review Log

Revision history for `design/gdd/hud.md`. Most recent entry first.

---

## Review — 2026-07-03 — Verdict: NEEDS REVISION (narrow-gate round 2) — **ACCEPTED AS-IS BY USER**
Scope signal: L
Specialists: systems-designer + ui-programmer (gate a: formula/feasibility); qa-lead + ux-designer (gate b: testability/accessibility) — the two CD-prescribed narrow fresh-agent gates, NOT a re-panel. No CD spawned (PA round-7 / RN round-5 closing-gate precedent).
Blocking items: 15 (consolidated from ~21 raw) | Recommended: ~12 | Nice-to-have: 6
Prior verdict resolved: Yes — the MAJOR-REVISION must-fix gate (7 items) was fully addressed by the 2026-06-19 ruling pass; 5 of the 7 fixes have execution defects, which is this round's entire content.

**Headline:** all four gate agents returned FAIL, but the defect class dropped a full tier: both user-ruled load-bearing decisions (CR.8 figure-ground, CR.9 render-vs-originate) **HELD** under independent adversarial scrutiny; no missing decision found; the pure-subscriber spine stayed sound. Failures are mechanism precision + AC coverage. **USER DECISION: accepted as-is 2026-07-03** (governance precedent: user acceptance overrides panel critique). **The items below are carried as OPEN pre-implementation obligations, not resolved.**

**Blocking (carried obligations):**
1. **[systems-designer + qa-lead, convergent]** D.6 window model incorrect: a 0.333 s min-gap debounce ≠ "≤3 onsets in any 1 s sliding window" — onsets at t = 0, ⅓, ⅔, 1.0 (or 0/0.34/0.68/0.99 under jitter) put 4 in one window; decimal-truncated `0.333` worsens it. Fix: trailing-1 s onset-timestamp count, exact-`1/3` semantics, `≥`/half-open window pinned, explicit boundary fixtures in H.6.
2. **[systems-designer + ui-programmer, convergent]** D.6 preemption produces real luminance transitions the counter ignores: `Tween:Cancel()` freezes at a mid-value (cut path must explicitly set the defined rest value); cut+restart is pixel-wise two transitions; alternating higher-priority preemptions can chain continuous flashing while bookkeeping reads "1 onset."
3. **[ui-programmer + ux-designer, convergent]** D.6 "ALL elements" scope conflicts with CR.8's never-silenced loud-ground throbs (Critical-oxygen dying-pulse can be priority-dropped; cap-cue state-B's pulse is its *only* A/B distinction and is also strippable by UI.7 reduced-motion). Needs a data-pulse vs emphasis-flash classification + loud-ground exemption slot.
4. **[systems-designer]** D.1 `drainRate` has no source on 2 of 3 re-anchor paths: RM's approved `OnOxygenDeducted`/`OnOxygenRestored` payloads carry `P_after` + `serverSendTime` but NO `drainRate` → nil-arithmetic error on the first death as written. Fix: P/T-only re-anchor on those events; `drainRate_lastSync` persists from the last `OnOxygenChanged`. OQ.10 is answerable now, not an open confirm.
5. **[systems-designer]** D.5/D.7 `≤ 0` guards miss NaN (IEEE-754: `NaN ≤ 0` is false) → NaN propagates into `Size`/`Rotation` (same class ED already patched). Fix predicate: `not (x > 0)`.
6. **[systems-designer]** CR.8's 0.75 s dwell has no higher-priority-preemption carve-out: BCT3 firing mid-dwell can hold the countdown out of the figure for ≤0.75 s at the run's most critical instant, contradicting the overlay section. Needs a preempt rule + AC.
7. **[qa-lead]** CR.8 lacks a `FigureArbiter` pure-function commitment (mirroring D.6's FlashArbiter) + explicit output model incl. an `isLoudGround` flag — without it H.30–H.33 are [L]-tagged but only verifiable by live-Instance inspection.
8. **[ux-designer]** D.4 × CR.8 opacity composition unspecified: multiply → ground FAR chevron at 0.27 (sub-floor); override → demotion *brightens* it (0.45→0.6). No AC exercises the combination.
9. **[ui-programmer]** CR.9 mount lifecycle: build mounts in `KnitInit` (Knit guarantees no cross-controller `KnitStart` ordering — accessor race otherwise) + explicit persist-for-run invariant (Destroy/rebuild silently disconnects producer input after respawn).
10. **[ui-programmer]** D.2b's "cancel-and-restart TweenService tween" contradicts H.21's own no-churn prerequisite (Tweens can't retarget) → specify manual Heartbeat interpolation in the consolidated loop.
11. **[qa-lead]** H.1b scan gaps: relay-through-utility bypass (scan the require-closure, or forbid any Remote reference/`Remotes` namespace in HUD files) + bare `:BindAction(` token (`CAS` aliasing evades the qualified form).
12. **[qa-lead]** Missing companion static check (new H.6b): nothing verifies all flash/throb tweens actually route through the FlashArbiter — a direct `TweenService:Create` bypass is invisible to both H.1b and H.6.
13. **[qa-lead]** Two fully-specified mechanisms have NO AC: the VA.5 audio drop-not-queue gate (spec itself says "unit-testable") and D.1's stale-sync rejection.
14. **[ux-designer]** Oxygen tick marks lack a contrast requirement: white notches over the light amber Warning stop plausibly fail exactly at the boundary they mark. Add WCAG 1.4.11 ≥3:1 vs the local gradient color (worst case) + a fallback treatment.
15. **[ux-designer] MICRO-FORK — needs a user/CD ruling:** threat-edge loud-ground asymmetry during the Beacon-Window overlay (Critical-oxygen got a loud-ground carve-out; an active predator-lock did not, with no stated rationale; mitigated by UI.5 never dropping attack captions) + no AC tests the 3-way BC4-peak state (window + lock + Critical) the design names as its own hardest case.

**Important (~12, also carried):** H.21 = 2.0 ms figure plausible but **NOT SIGNED OFF** — methodology needs a `debug.profilebegin("HUD")`/`profileend()` wrap point, a reproducible fixture (define "all cues active"), and a [P] evidence-type mapping (no slot in testing standards; no headless-CI equivalent exists) [ui-programmer + qa-lead]; iPhone SE has no notch/home-indicator — name a second notched verification device for the inset path [ui-programmer]; H.20b has no defined check method (token list or explicit manual-review tag) [qa-lead]; D.3 `angularDelta` range documented backwards — true range `[−180, 180)`, masked at runtime by the snap but a literal unit test fails [systems-designer]; make the CR.8 fill-exemption list explicit for all 6 persistent elements (only oxygen + chevron worked out) [ux-designer]; H.1b polling-input vector (`UserInputService:IsMouseButtonPressed` in Heartbeat) — forbid or declare accepted residual risk [qa-lead]; OQ.6(b) AD sign-off should add the peripheral scenario (bottom-of-screen predator bearing coincident with oxygen-Warning; the triad argument is foveal/HUD-internal as framed) [ux-designer]; UI.7: classify the 3 unclassified reactive animations; add CONTACT 4px→8px stroke escalation to OQ.9's device pass; ground-opacity text-contrast check; H.7 should carry its own distinction→channel table; `MouseButton*` must be a regex prefix match in CI [ux-designer + qa-lead].

**Nice-to-have:** D.1 upper-clamp example unreachable via real inputs; same-tick `≥` tie-break overstated; check for a newer Roblox safe-area API; ultrawide "single scaling model" framing; H.7 Empty-state omission; generalize the UI.5 flash audit to any figure transition.

**Record note:** the systems-index Next-Steps line previously referenced a "narrow two-gate re-review 2026-06-29 (7 must-fix, MF-1/MF-2)" with no entry in this log, contradicting the session state ("gates not yet started") — apparently an unlogged or crashed session. This 2026-07-03 round is the authoritative narrow-gate record; the index line was reconciled to it.

---

## Ruling pass — 2026-06-19 — Design-ruling session applied (NOT a verdict; addresses the MAJOR-REVISION must-fix gate)

Followed the CD-recommended path: focused design-ruling session → precision/testability fanout → (next) two narrow fresh-agent gates. NOT a re-panel.

**Two load-bearing decisions (user-ruled, then authored):**
1. **Figure-Ground emphasis model → new `CR.8`.** User ruled **Threat outranks.** Figure-selection arbiter (highest wins): Beacon-Window countdown › predator-lock (YOU›SQUAD) › oxygen. Critical-oxygen is **loud ground** (keeps its VA.1 dying-pulse), never seizes the figure. Figure = `FIGURE_OPACITY` 1.0 + idle anim + fill; ground = data-channel-full but emphasis-dropped (`GROUND_OPACITY` 0.6, no idle anim, fill→stroke-only). Ground keeps its voice (own transients fire once → causal chain survives — the B.2 Pillar-1 fix). 0.75 s figure dwell. Maps onto §3.3 fill-vs-stroke grammar (no new vocabulary). Dissolves B.1–B.4. New ACs H.30–H.33; new knobs FIGURE_OPACITY/GROUND_OPACITY; overlay paragraph + CR.4 cross-ref updated.
2. **Render-vs-originate input pattern → new `CR.9`.** User ruled **HUD renders, producer binds.** HUD creates+owns the Instance + layout/lifecycle/CR.8 emphasis, exposes a typed Knit accessor (`GetGatherPromptMount()`/`GetEmoteWheelMount()`); the producer (RN/PC) binds input + owns the client→server call. HUD source: ZERO input `:Connect`, ZERO `:FireServer` — static AC **H.1b**. CR.2 IgnoreGuiInset "contradiction" resolved (deliberate opt-out-then-pad-manually; not double-applied). Wired into CR.1 + UI.1.

**Precision/testability fanout (must-fix gate items 3–7):**
3. **Formula guards/conventions** — D.1 `max(0, elapsed)` (no upward drift on out-of-order packet) + anchor `T_lastSync` to `serverSendTime` in all 3 re-anchor paths (= RM H.51 latency-projection) + stale-sync rejection (monotonic anchor); D.3 explicit `angularDelta` shortest-arc wrap + stated **CW-from-north** convention with contract-assert (OQ.4 BLOCKING → one-line confirm); D.5/D.7 zero/negative-duration guards; drainRate/extractionDuration reworded as producer-pushed (HUD never hardcodes).
4. **Testability** — H.21 quantified (**≤ 2.0 ms/frame** @ 30 fps iPhone-SE, ≈6% of 33.3 ms budget; TD-proposed, flagged for TD sign-off) + impl prereqs; H.3 objective (zero AABB∩GuiInset, ≥14 px text, no hover); H.6 onset defined + 1 s sliding window; H.7 greyscale per-distinction non-color-channel-present.
5. **Colorblind + hue arithmetic** — oxygen Warning/Critical **static positional tick marks** (disturbance stays band-less by design); **arithmetic corrected**: `#FFF0C8` = hue ≈ 43.6° **INSIDE** the 18–48° band (passes only by the S≈22% sat-gate) — VA.3's "~50°, outside" was **wrong** → **UIStroke `4px→8px→4px` flipped to PRIMARY/locked**, cream demoted to optional-pending-AD-signoff. **Also found:** warning `#FFD060` ≈ 42° INSIDE the band at S≈62% **ABOVE** the gate — survives only by the §4.5 triad; corrected + added to OQ.6 AD confirmation (load-bearing, stays).
6. **D.6 buildable artifact** — single **`FlashArbiter`** module (only path that may start a flash tween; cues submit `{elementId, priority, semanticEventId}`; 0.333 s sliding window; preempt-or-drop-to-static; semanticEventId collapse = CR.5a/H.26; pure (request-stream, clock)→onset-schedule, fake-clock unit-testable).
7. **Two seams** — bearing-triangulation ruled (HUD single-frame only, no bearing time-series, new AC **H.20b**; not fully closeable HUD-side → durable fix = PA bearing **quantization**, new security **OQ.11**); VA.5 audio-gate made an explicit state machine that mirrors CR.4 **precedence but drops-not-queues** (visual queues, audio drops). H.17/H.18b remain PROVISIONAL-tagged (unauthored RunController/Camera).

**Net new/changed:** CR.8, CR.9 (new); CR.1/CR.2/UI.1 + overlay (edited); D.1/D.3/D.5/D.6/D.7 (guards/mechanism); H.1b/H.20b/H.30/H.31/H.32/H.33 (new ACs), H.3/H.6/H.7/H.21 (quantified); VA.1/VA.3/VA.5 (corrected); FIGURE_OPACITY/GROUND_OPACITY (new knobs); OQ.6 (flipped), OQ.11 (new). Status header → "In revision". **NOT committed. Next = the two narrow fresh-agent gates. DO NOT predict APPROVED.**

---

## Review — 2026-06-19 — Verdict: MAJOR REVISION NEEDED
Scope signal: L–XL
Specialists: game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, network-programmer, performance-analyst, art-director, audio-director, creative-director (senior synthesis)
Blocking items: 30+ across 9 domains (collapse to 5 root patterns + 2 missing load-bearing decisions) | Recommended: ~12 | Nice-to-have: ~8
Prior verdict resolved: First review (no prior log)

**Completeness:** 8/8 sections + Visual/Audio + UI + 12 Open Questions. Dependency graph clean — 6 producer GDDs exist; RunController + Camera unauthored but correctly flagged provisional (OQ.1/OQ.3).

**Summary (creative-director synthesis):** A genuinely strong first draft with a SOUND spine — correct pure-subscriber authority model, server-clock dead-reckoning, reserved-hue discipline, owns no balance values. Thorough but not yet convergent: it accreted element-by-element across six subscriptions without the holistic reduction-and-precision pass a terminal presentation layer needs. MAJOR (not polish) because two *load-bearing decisions* are missing, not just detail. Do NOT re-run a full nine-specialist panel — close the rulings, then gate re-review on two narrow fresh-agent passes.

**Five root patterns:**
1. **Accretion without a figure-ground reduction pass** — 15–18 simultaneous reads at BC4 peak vs. the "read it like breathing" fantasy. CR.4's 7-level suppression ladder is a symptom: it never decided what the player may NOT see at peak load. (game-designer B.1–B.4; ux-designer; art-director — convergent.)
2. **Formula precision debt** — D.1 no `max(0,elapsed)` guard (out-of-order packet drifts oxygen bar UPWARD); D.1 re-anchor omits RM's mandated latency-projection (incomplete vs approved RM H.51); D.3 lerpAngle shorter-arc/wrap unspecified; bearing convention (OQ.4) is BLOCKING; D.5/D.7 zero-duration degenerates. (systems-designer, 8 BLOCKING.)
3. **Untestable acceptance language at the ACs that matter most** — H.21 "within budget/no jank" (no number, 30fps floor uncited), H.3 "readable", H.6 flash-measurement method, H.7 "distinguishable". (qa-lead + performance-analyst convergent.)
4. **One unowned cross-controller input boundary, hit independently 4×** — producer-owned input on HUD-created Instances has no render-vs-originate pattern; default impl violates CR.1 or CR.2; CR.2 IgnoreGuiInset+manual GetGuiInset is self-contradictory; H.1 no-echo test is behavioral-only (misses the input-binding relay vector). (ui-programmer #4 + network-programmer F2.)
5. **Accessibility/color claims outrun verification** — oxygen/disturbance continuous fill LEVEL is color-only (colorblind continuous-read gap); `#FFF0C8` CONTACT hue arithmetic is provably wrong (≈44°, INSIDE the 18–48° exclusion band the GDD claims it's outside) → UIStroke fallback should be primary; reduced-motion (UI.7) references a non-existent flag/surface. (ux-designer, art-director, qa-lead.)

**Adjudicated over-reach (CD):** game-designer B.1 "reduce the element inventory" — right diagnosis, wrong prescription. A terminal consumer of 6 approved systems cannot drop a system's information. Fix = **reframe to a figure-ground emphasis model** (one figure, rest as readable-at-rest ground), which dissolves B.1/B.2/B.3/B.4 at once. World-response/spike cues become *ground* (present-but-quiet), never suppressed-to-absent — the causal chain must survive (B.2 is a Pillar-1 violation as written).

**Must-fix gate (re-review blocks on these):**
1. Author the **figure-ground emphasis model** (parent ruling — do first).
2. Specify the **cross-controller input-ownership pattern** + resolve IgnoreGuiInset contradiction + add static-analysis AC for the relay vector.
3. Add **formula guards/conventions** (D.1 max(0,·) + latency-projection; D.3 wrap + bearing OQ.4; D.5/D.7 zero-duration); reference constant names not literals.
4. **Quantify H.21** (TD frame-budget number, cite 30fps) + give H.3/H.6/H.7 objective pass conditions.
5. Close the **colorblind continuous-read gap**; correct/retire the `#FFF0C8` arithmetic (commit to UIStroke fallback).
6. Specify the **D.6 combined-flash coalescing mechanism** as a buildable, testable artifact.
7. Name & rule on the two unowned seams: **bearing-triangulation** (RR-4 defends single-frame only; sequential samples + own motion → predator world-position in 3–5s) and the **VA.5 audio-gate state machine** (named but unspecified; "mirrors CR.4 exactly" is false — audio drops, visual queues). Tag H.17/H.18b PROVISIONAL (unauthored RunController/Camera).

**Performance (must accompany impl):** consolidate the 3 RunService loops, short-circuit D.3 when unlocked, pre-create+pool transient cues and Tweens (no 5 Hz cancel-restart churn), set an instance ceiling.

**Defer (not gated):** reduced-motion flag wiring (PROVISIONAL against unauthored accessibility surface); Run-End duck sequencing (OQ.8) and world-response audio-visual sync (OQ.7) stay as forward obligations.

**Useful clarification (systems-designer):** the pre-review worry that D.1 `drainRate {1.0,1.5,2.2,8.0}` conflicts with RM is FALSE — 8.0 is current RM CR.2 (it superseded the old 3.5 when the BC4 oxygen cap was removed). No mismatch; just reference the constant names.

**Recommended re-review path (CD):** focused design-ruling session (the 2–3 missing decisions) → precision/testability fanout → two narrow fresh-agent gates (systems+ui-programmer feasibility/formula; qa+ux testability/accessibility). NOT a full re-panel.
