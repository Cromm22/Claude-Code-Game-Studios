# Player Controller GDD — Review Log

Revision history for `design/gdd/player-controller.md`. Each entry records the verdict, scope, specialists consulted, and a summary of load-bearing findings. Used by re-reviews to verify that prior blocking items were addressed.

---

## Review — 2026-05-01 — Verdict: MAJOR REVISION NEEDED

**Scope signal:** L+ (foundational, not targeted; producer should verify before sprint planning). Heavier than crafting-and-items round-2 — multi-section rewrites required, not surgical fixes. Estimated round-2 effort: 1.5–2× round-1 effort.
**Specialists:** game-designer, systems-designer, gameplay-programmer (Roblox/Luau fallback per technical-preferences.md), network-programmer, ux-designer, ai-programmer, audio-director, performance-analyst, qa-lead, accessibility-specialist, creative-director (senior synthesis)
**Blocking items:** 28 CRITICAL | **Recommended:** ~50 IMPORTANT | **Nice-to-have:** ~22
**Prior verdict resolved:** First review (no prior log)
**Review depth:** full (per `/design-review` default; `production/review-mode.txt` is `lean` but `--depth` is independent of project review mode)

### Summary

The 28 BLOCKING items collapse into four themes:

1. **Transaction integrity is undelivered at the rule level (Pillar 1 failure).** The grace-window first-pulse exploit (G1) lets a player fire 0.10-magnitude pulses every 2.625s via micro-sprint cadence with 31% of full sprint cost. Disconnect-before-death (N1) inverts C.5.3's stated guarantee — the squad-oxygen cost is paid only if the player allows the death. `SPRINT_CLIENT_TIMEOUT` heartbeat signal is undefined (N2); if the signal IS `RequestSprintToggle`, exploit chains 2.9s re-toggles for infinite sprint. Sprint footstep "louder cadence" (Au2) trains players that predator reacts to *audio volume*, not the mechanical pulse contract — player mental model error. Section B player-fantasy promises a "deliberate transaction"; C–H currently let loud play be the easy mode.

2. **Roblox API claims are unverified on a live platform.** `workspace:HasChunkLoaded()` (P2) likely doesn't exist as named — entire C.5.6 spectator chunk-guard has no verified implementation path. `Humanoid.Died` semantics (P3) under the post-cutoff Character Controller Library GA may have changed — entire death flow gated on this signal. `workspace:GetServerTimeNow()` (P1) needs verification against current docs. Roblox VERSION.md explicitly flags this risk: live platform, post-cutoff GA features, "verify before recommending."

3. **Downstream contract (publish-side) is internally inconsistent.** D.2 clock-skew lockout (S1) — ED.D.1 uses `math.max(0, age)` pattern; PC's D.2 doesn't. D.4 nil/unknown platform silently skips drift floor (S2). D.4 claimed output range `{0.024, 0.03, 0.08, 0.10}` is incorrect post-modifier — Crafting GDD's Quiet Step Wrap (0.5×) and Dampener Coil (0.5×) produce 0.05, 0.04, 0.012 reaching ED (S3) — i.e., PC's documentation lies about what ED will actually see. F.4 commits position-only as predator perception input (A2); credible predator needs velocity, facing, alive-status. No `OnPlayerDied` / `OnPlayerRespawned` signal flows to predator for tracking flush (A3). OQ.1 (walk-audio perception) is unresolved and Pillar 1 collapses if answered wrong (A1).

4. **Mobile-first commitment contradicted at the rule level.** Lantern button upper-left position unreachable mid-encounter on iPhone SE-class (U1). Quick-ping uses red/green/yellow/white colors with NO shape differentiation (Ac4) — direct violation of game-concept's published accessibility-floor commitment ("all color cues have shape/icon redundancy"); red/green is the highest-frequency colorblind confusion pair. Captions queue undefined when multiple events fire simultaneously (U3, Ac3) — WCAG 1.2.2/1.2.4 violation. Vignettes (death/respawn) and lantern PointLight ramp absent from motion-reduction substitution list (Ac1, Ac2). Walk footstep using Roblox default (Au1) violates Pillar 3 in first 10 seconds. Bandwidth peak ~2.3 KB/s during ping/emote bursts (Pf1) violates the H.29 "<1 KB/s" claim during the exact scenarios this controller is designed for.

### Senior Verdict (creative-director)

> **Section B is genuinely strong.** Multiple specialists called the player-fantasy framing out as load-bearing and well-articulated. Round-2 must rewrite C–H to *deliver* B, not edit B to match C–H. The publish-contract approach (F.2a + F.4) is architecturally correct; the flaws are in the contract's *contents*. Section H is structurally right; fill the gaps, don't restructure.
>
> **Pillar 1 (Quiet Is Power): NOT DELIVERED at the rule level.** G1 + N1 + N2 + Au2 collectively let a competent player sprint freely. Pillar 1 says quiet play is the only easy mode; the rules currently allow loud play to be the easy mode. This is the single most important blocker theme.
>
> **Pillar 2 (The Squad Is the Experience): PARTIALLY DELIVERED.** Spectator chunk-guard (blocked on P2) and respawn affordance are in scope. But U2 (gather lockout invisibility), U3 (caption queue), and A3 (no death/respawn signal to predator) all degrade the squad-coordination surface.
>
> Round-2 must close Pillar 1 at the rule level. That is non-negotiable — it's what the game IS.

### Specialist Convergences

- **Cost-attribution lifecycle** — flagged from four angles: game-designer (G1 grace exploit), network-programmer (N1 disconnect, N2 heartbeat), audio-director (Au2 mental model). All four cluster around the same architectural seam: the controller emits gameplay-consequential events but does not own the cost-attribution lifecycle.
- **Roblox API verification** — flagged by gameplay-programmer (P1, P2, P3) and qa-lead (Q1 non-headless-testable). Same theme from implementation and test angles.
- **Captions queue/priority undefined** — flagged independently by ux-designer (U3) and accessibility-specialist (Ac3). Cross-domain convergence on a single defect.
- **Mobile floor regressions** — flagged by ux-designer (U1, U2, U3), accessibility-specialist (Ac1, Ac2, Ac3, Ac4 — the heaviest specialist load on this GDD), performance-analyst (Pf1), audio-director (Au1).

### Specialist Disagreements

None substantial. All specialists converged on the same four themes. Minor difference in tone: gameplay-programmer noted Roblox API uncertainty as "must verify before architecture" (deferring to architecture phase), while creative-director treated unverified APIs as a CRITICAL blocker for round-2.

### Recommended Round-2 Sequence

Fresh session(s), one theme per session, write to file incrementally per `.claude/docs/context-management.md`:

1. **Theme 1 (transaction integrity, Pillar 1 closure):** Rewrite grace-window rule (C.8.1, D.4, E.C). Add disconnect-before-death cost-finalization rule (C.5.3). Specify `SPRINT_CLIENT_TIMEOUT` heartbeat signal as a separate keepalive that does not extend sprint authorization (E.D, G.6, H.33). Add design note to V/A.3 that sprint audio is not a predator-perception channel (Au2). New ACs for each.
2. **Theme 2 (Roblox API verification):** WebSearch + Creator Docs verify `workspace:HasChunkLoaded()`, `workspace:GetServerTimeNow()`, `Humanoid.Died` semantics under Character Controller Library GA. Resolve OQ.4. If `HasChunkLoaded` doesn't exist as named, replace C.5.6's chunk-guard with a verified API or rewrite the spectator-camera chunk handling.
3. **Theme 3 (downstream contract):** Adopt ED's `math.max(0, age)` pattern in D.2 verbatim. Add platform-validation gate to D.4. Document the post-modifier output range that actually reaches ED (consume Crafting GDD's modifier stack). Add velocity, facing, alive-status to F.4. Add `OnPlayerDied` / `OnPlayerRespawned` to predator-obligation list. Pre-decide OQ.1 (walk-audio perception).
4. **Theme 4 (mobile-floor / accessibility):** Reposition lantern button or accept the trade-off explicitly (U.2). Add shape/icon differentiation to quick-ping categories (Ac4 — game-concept floor regression). Specify captions queue + priority + hold-time rules (U3, Ac3). Add lantern PointLight ramp + vignettes to motion-reduction substitution list (Ac1, Ac2). Commit custom walk SFX as MVP (Au1). Update H.29 bandwidth claim to acknowledge peak vs. steady-state.
5. **Theme cross-cut (testability):** Sweep qa-lead AC rewrites (H.16 split, H.22 cross-instance race, H.27/H.32 hardware fallback). Add ACs for T2/T6/T7/T8 (currently uncovered). Add Visual/Audio ACs per coding-standards ADVISORY gate.
6. **Camera GDD decision (OQ.3):** Pre-decide whether spectator camera is a new system (raising MVP system count from 7 to 8) or folded into Player Controller. Update systems-index accordingly.

### Files Referenced

- Target: `design/gdd/player-controller.md` (832 lines, status: NEEDS REVISION)
- Upstream: `design/gdd/ecological-disturbance.md` (round-5 done, awaiting round-6 re-review), `design/gdd/crafting-and-items.md` (NEEDS REVISION — round-2 pending; PC's D.4 must consume its modifier stack)
- Cross-cited: `design/gdd/game-concept.md` (Pillar 1, Pillar 2, accessibility floor, anti-pillars, trust-boundary RE registry), `design/gdd/systems-index.md`, `design/registry/entities.yaml` (22 PC constants confirmed registered with consistent values)
- Standards: `.claude/docs/coding-standards.md`, `.claude/docs/technical-preferences.md`, `docs/engine-reference/roblox/VERSION.md`

### Strengths to Preserve in Round-2

1. **Section B (Player Fantasy) is the strongest articulation in this GDD.** "The Loud Choice" framing, the Anchor Moment ("Ninety seconds without anyone speaking aloud"), the reference grounding (*Alien: Isolation*, *Doors*, *Apeirophobia*, *Subnautica*) all land. Do not edit Section B in round-2.
2. **Section H is structurally exhaustive (34 ACs).** Flaws are gaps and aspirational claims, not structural defects.
3. **The publish-contract approach (F.2a + F.4) is the right architecture.** PC explicitly documents what it emits to ED and to Predator. Foundation-layer correctness pattern.
4. **Touch-input parity is taken seriously throughout.** Intent is correctly placed; the contradiction is at the rule level, not the framing level.
5. **Open Questions are flagged honestly (OQ.4 chunk-load API).** Mature design-doc hygiene; preserve it.

---

## Review — 2026-05-02 — Verdict: NEEDS REVISION (Round-2 Theme 1 validation; Theme-1-round-2 patch required)

**Scope signal:** M (single fresh session, 7 rule-level fixes to existing sections — C.5.3, E.D, F.4, V/A.3, D.4. No new sections required. Producer should verify before sprint planning.)
**Specialists:** game-designer, systems-designer, network-programmer, audio-director, qa-lead, ai-programmer, performance-analyst, creative-director (senior synthesis)
**Blocking items:** 7 BLOCKING | **Recommended:** 14 IMPORTANT | **Nice-to-have:** 7
**Prior verdict resolved:** Partially — round-1 finding "Pillar 1 (Quiet Is Power) NOT DELIVERED at the rule level" is **closed for the G1/L1 grace-cycle exploit** (D.4 per-axis cooldown logic, E.C three new edge cases, T5 cooldown-reset on death — clean closure). However, **Theme 1 introduced 7 new BLOCKING items of equivalent severity** centered on Pillar 2 cost-attribution (Path B false-positive arms) and N2 lifecycle (`_lastHeartbeatTime` and `_deathCostPaid` atomicity).
**Review depth:** full (per `/design-review` default; 7 specialists spawned in parallel, then creative-director senior synthesis)

### Summary

Theme 1 closed 4 of the 28 round-1 BLOCKING items (G1 grace-cycle exploit, N1 disconnect-before-death cost rule, N2 PlayerHeartbeat protocol definition, Au2 sprint-audio mental model + OQ.1 closure). The G1/L1 closure is sound — per-axis `GRACE_REENTRY_COOLDOWN = 6.0 s` with cooldown-reset on T5, paired with three new E.C edge cases that make the cooldown-blocked-but-moving / cooldown-blocked-but-stationary cases explicit. Round-1 grace-cycle Pillar 1 finding is closed for both Sprint and Light axes.

However, Theme 1 introduced 7 new BLOCKING items of equivalent severity to what it closed:

1. **`_deathCostPaid` check-and-set is not atomic across Luau yield boundary** [network-programmer]. T5's call to `RequestSquadOxygenSpend` may yield (RemoteFunction round-trip), allowing both Path A (`Humanoid.Died`) and Path B (`PlayerRemoving`) handlers to observe `false` and both proceed → double squad-oxygen deduction under lethal-disconnect race. The entire idempotency claim of N1 rests on this guarantee. Fix: mandate set-before-yield discipline in C.5.3.

2. **`_lastHeartbeatTime` initialization on T1 unspecified** [network-programmer]. GDD specifies the timeout check (in S2, `(now - _lastHeartbeatTime) > 3 s` forces T2) but never specifies when `_lastHeartbeatTime` is initialized or reset. Result: every legitimate sprint-after-walk-pause >3 s would be force-reverted immediately on T1. **N2 is broken at the rule level without this.**

3. **`lastPredatorDamageTimestamp` lifecycle/clearance unspecified** [ai-programmer + performance-analyst, independent convergence]. No clearance rule. Stale entries on player rejoin (same userId) trigger false Path B on next disconnect. Fix: F.4 row must require PredatorService to flush entry on `PlayerRemoving` AND clear on `PlayerAdded` for new sessions; key by Player object not userId.

4. **Path B fires on non-predator damage via health arm** [ai-programmer]. The health arm fires unconditionally; a player at HP=24 from oxygen-depletion ticks who disconnects pays squad oxygen even though predator was never near. **Pillar 2 violation introduced by Theme 1.** Fix: constrain Path B to fire only when at least one arm references predator damage, or explicitly accept "any near-death disconnect costs oxygen regardless of cause" with explanatory design note (CD sign-off needed).

5. **PredatorService init-order race causing runtime error** [ai-programmer + network-programmer, independent convergence]. `nil - number` runtime error in C.5.3 predicate if `lastPredatorDamageTimestamp[player]` is unset at PlayerRemoving fire-time. Theme 1 introduces a hard crash path. Fix: mandate explicit nil-guard in predicate prose; specify PredatorService MUST initialize the table to `{}` (empty, not nil) before any player can join.

6. **OQ.1 closure contradicts V/A.3 walk footstep row** [audio-director]. OQ.1 (closed) says walk audio is NOT a predator-perception channel. V/A.3 walk row still says: "Whether Predator AI's perception consumes footstep audio is a Predator AI GDD decision, not this GDD's — flagged in Section F.4." Both languages survive Theme 1 edits. Fix: single-line edit to walk row.

7. **D.4 variable name inconsistency: `t_entry` vs `t_0`** [systems-designer + main-review Phase 3]. Formula expression uses `t_entry`; recording line uses `t_0`; variables table only defines `t_0`. Same value, two names. Fix: rename consistently throughout D.4.

### Senior Verdict (creative-director)

> Round-2 Theme 1 partially delivers Pillar 1 at the rule level. The G1/L1 grace-cooldown closure is sound — D.4's per-axis cooldown logic, E.C's three new edge cases, and the cooldown-reset on T5 close the round-1 grace-cycle exploit cleanly. However, Theme 1 ships two new defects of equivalent severity to what it closed: (a) the composite OR predicate fires on non-predator damage (Pillar 2 cost-attribution violation), and (b) the `_deathCostPaid` atomicity claim is asserted without proof against Luau cooperative scheduling (idempotency hole — entire load-bearing mechanism of N1).
>
> The Au2 closure is mechanically clean (predator-perception channel correctly separated from player-feedback channel) but the audio mix tuning may train the wrong mental model. This is a tuning-validation concern, not a rule defect.
>
> Round-1 finding "Pillar 1 not delivered at rule level": closed for the grace-cycle exploit. New round-2 finding: "Pillar 2 cost-attribution rule introduces two false-positive paths and one atomicity hole" — equivalent severity to what was closed.
>
> Seven blocking fixes (BLOCKING items 1–7 above). All are rule-level, single-fresh-session scope. Atomicity and lifecycle holes must close at the GDD level before architecture phase begins; deferring them to round-3 means rebuilding Theme 1 once the round-2 ED revision invalidates assumptions. **Do not proceed to Theme 2 until these seven fixes land.**

### Specialist Convergences

- **`_lastHeartbeatTime` lifecycle defect** — flagged independently by network-programmer (force-revert on every re-sprint) and performance-analyst (stale entries on rejoin). Same defect from two angles.
- **Cross-service init-order race for `lastPredatorDamageTimestamp`** — flagged independently by network-programmer (Knit cross-service direct table access) and ai-programmer (PredatorService init order; nil-arithmetic crash). Same defect from two angles.
- **Audio mental model failure** — three-angle convergence from game-designer (F5: +3-4 dB undermines effort framing), audio-director (F1: design note re-argues rather than re-engineers), and audio-director (F5: caption cycle parity creates wrong mental model for deaf players).
- **Composite OR false-positive paths** — flagged independently by game-designer (mobile Wi-Fi flap on iPhone SE) and ai-programmer (non-predator damage triggers health arm). Two different false-positive paths in the same predicate.
- **D.5 trace silence on cooldown effect** — flagged independently by game-designer and systems-designer. Trace shows stamina but not pulse magnitude under cooldown-blocked grace.
- **Variable name `t_entry` vs `t_0` defect** — flagged by systems-designer and confirmed by main-review Phase 3 structural pass.

### Specialist Disagreements

- **audio-director vs creative-director on Au2 severity**: audio-director rated F1 (mental model) as CRITICAL — argues +3–4 dB undermines effort framing. CD reframed as IMPORTANT — argues Au2 architecture (predator-perception channel separated from player-feedback channel) is engineered correctly; the +3–4 dB is a tuning value not a rule defect. CD's view binds for the verdict; surface here for adjudication if Au2 is revisited.
- **game-designer on GRACE_REENTRY_COOLDOWN floor**: rated IMPORTANT (Sprint axis 3.5 s floor only protected by Light's 4.0 s coincidence). CD downgraded to NICE-TO-HAVE based on 4.0 s documented minimum + 6.0 s default having 2.0 s margin.
- **qa-lead 6 CRITICAL findings**: rated as Theme 1 CRITICAL by qa-lead; CD reclassifies as Theme 4 / cross-cut testability scope (already a planned future workstream). Theme 1 does not block on AC testability gaps.
- **performance-analyst F5 (4-player thundering disconnect race)**: rated CRITICAL; CD acknowledges as CRITICAL but classifies as architecture-phase forward-obligation to Resource Management (the squad oxygen pool write is RM's responsibility, not PC's). Record as F.6 forward obligation, not as a Theme 1 blocker.

### Recommended Theme-1-round-2 Sequence

Single fresh session per `.claude/docs/context-management.md` "one theme per session" guidance:

1. Fix `_deathCostPaid` atomicity — specify lock-before-yield discipline in C.5.3.
2. Specify `_lastHeartbeatTime` lifecycle (init at T1 entry, clear on T2/T5/PlayerRemoving) in E.D.
3. Specify `lastPredatorDamageTimestamp` lifecycle (initialize on `PlayerAdded`, clear on death/respawn, clear on rejoin) — add row to F.4 forward obligation to PredatorService.
4. Constrain Path B recent-damage arm to predator-source damage only — rename or scope in C.5.3 predicate.
5. Add PredatorService init-order guard in C.5.3 (nil-check on `lastPredatorDamageTimestamp[player]` before subtraction; treat nil as "no recent damage").
6. Resolve V/A.3 walk row vs OQ.1 contradiction — single-line edit in walk-row cell.
7. Rename `t_entry` → `t_0` (or vice versa) consistently throughout D.4.

After Theme-1-round-2 patch closes, run `/design-review design/gdd/player-controller.md` in another fresh session to validate before advancing to Theme 2.

### Files Referenced (round-2 Theme 1 review)

- Target: `design/gdd/player-controller.md` (906 lines, status: NEEDS REVISION; round-2 Theme 1 applied 2026-05-01, round-2 Theme 1 review 2026-05-02)
- Upstream: `design/gdd/ecological-disturbance.md` (round-7 pending), `design/gdd/crafting-and-items.md` (round-2 pending)
- Cross-cited: `design/gdd/game-concept.md`, `design/gdd/systems-index.md`, `design/registry/entities.yaml`
- Standards: `.claude/docs/coding-standards.md`, `.claude/docs/technical-preferences.md`, `docs/engine-reference/roblox/VERSION.md`

---

## Review — 2026-05-02 — Verdict: NEEDS REVISION (no-op re-review against unchanged text)

**Scope signal:** M (unchanged from prior review — 7 rule-level fixes still required, no new findings)
**Specialists:** None this session — Phase 3b adversarial spawn skipped per user choice (lean-equivalent depth). Reuses 2026-05-02 full-mode specialist findings (game-designer, systems-designer, network-programmer, audio-director, qa-lead, ai-programmer, performance-analyst, creative-director synthesis).
**Blocking items:** 7 BLOCKING (identical to prior entry — items 1–7) | **Recommended:** 14 IMPORTANT (carried) | **Nice-to-have:** 7 (carried)
**Prior verdict resolved:** No — document text is unchanged since prior review (verified by line-level grep on `_deathCostPaid`, `_lastHeartbeatTime`, `lastPredatorDamageTimestamp`, `t_entry`/`t_0`, `isImminentDeath`, V/A.3 walk-row, OQ.1). All seven defective lines from prior entry confirmed in place.
**Review depth:** lean-equivalent (per user response to upfront question; full-mode default was offered and declined since re-spawning 7+ specialists on identical text would re-discover identical findings)

### Summary

User invoked `/design-review` after `/clear` without first applying the Theme-1-round-2 patch. Phase 1 detected the situation and offered the user three options: skip Phase 3b, run full Phase 3b anyway, or stop and apply the patch first. User chose to skip Phase 3b and confirm prior verdict.

Phase 1-3 structural pass independently confirmed:
- All 8 required sections present.
- All 7 BLOCKING items from 2026-05-02 prior entry are still in the document text at the original line numbers (C.5.3 lines 109-116; E.D `_lastHeartbeatTime` rules absent at line 463; F.4 line 539 PredatorService row missing clearance rules; D.4 lines 330/334/336/350/377 still mix `t_entry` and `t_0`; V/A.3 line 679 walk row still defers to Predator AI GDD contradicting OQ.1 closure at line 899).
- Dependency graph unchanged: ED + Crafting & Items GDDs exist; Resource Management, Resource Node, Predator AI, HUD remain provisional contracts per F.2 (acceptable per project soft-dep convention); Camera GDD still pending per OQ.3.

### Senior Verdict (carried forward)

> Carried verbatim from prior 2026-05-02 entry — creative-director synthesis on the same 7 items. No re-adjudication this session.

### Recommendation

User selected "Stop — revise in fresh session." The Theme-1-round-2 patch sequence (steps 1–7 in prior entry's Recommended Theme-1-round-2 Sequence) is the binding plan; nothing changes about it. After applying the patch, run `/design-review design/gdd/player-controller.md` in another fresh session to validate before advancing to Theme 2.

### Files Referenced (re-review)

- Target: `design/gdd/player-controller.md` (906 lines, unchanged since prior review)
- Review-log file: this file
- Systems index: `design/gdd/systems-index.md` (updated this session with brief re-review note in PC row)

---

## Patch Applied — 2026-05-02 — Theme-1-round-2 (NOT a review verdict; closes 7 BLOCKING items from prior 2026-05-02 entry)

**Type:** Patch session, not a review. The next `/design-review` of this GDD is the binding validation gate.
**Scope signal:** M (matches prior review's M-scope estimate — 6 surgical edits to 5 existing sections, no new sections, 0 ADRs touched).
**Specialists:** None spawned this session (patch-only; the prior 2026-05-02 review already established the binding fix list).
**Editor:** Single fresh session per `.claude/docs/context-management.md` "one theme per session" guidance.
**File delta:** `design/gdd/player-controller.md` grew 906 → 935 lines (+29 net; 6 edit sites).

### Edits Applied (1:1 with prior review's 7 BLOCKING items + Recommended Theme-1-round-2 Sequence)

| # | BLOCKING item from prior 2026-05-02 entry | Section edited | Edit |
|---|---|---|---|
| 1 | `_deathCostPaid` check-and-set not atomic across Luau yield boundary | C.5.3 idempotency | Added "Set-before-yield discipline (atomicity rule — load-bearing)" with mandatory 5-step ordering: read flag → no-op-if-true → SET flag BEFORE any yield-capable call → invoke `RequestSquadOxygenSpend` → broadcast `OnPlayerDied`. Steps 1-3 specified as a single non-yielding atomic span. Yield-capable Luau calls explicitly enumerated (`RemoteFunction:InvokeServer`, `Signal:Wait`, `task.wait`, `pcall(:GetAsync)`, `Knit:GetService(...):Method()`). |
| 2 | `_lastHeartbeatTime` initialization on T1 unspecified | E.D `PlayerHeartbeat` para | Added "`_lastHeartbeatTime` lifecycle (load-bearing for the timeout-safety rule)" sub-section: init on T1 (state-entry timestamp counts as implicit first heartbeat); first-heartbeat grace = full `SPRINT_CLIENT_TIMEOUT` window via T1-seeded timestamp; clearance on T2/T5/`PlayerRemoving`; no-write on `PlayerAdded`; bootstrap-init table to `{}` (not `nil`) at `PlayerControllerService` startup. |
| 3 | `lastPredatorDamageTimestamp` lifecycle/clearance unspecified | F.4 PredatorService row | Expanded the row from one sentence to a full lifecycle spec: keyed by `Player` instance NOT `userId` (Wi-Fi flap defence); bootstrap init to `{}` before `Knit:Start()` returns; no-write on `PlayerAdded`; only-writer = predator-damage application; clear on T6 (respawn) and `PlayerRemoving`. Cross-references C.5.3 nil-guard. |
| 4 | Path B fires on non-predator damage via health arm (Pillar 2 violation) | C.5.3 imminent-death predicate | Predicate rewritten — both arms of the OR now require `lastPredatorDamageTimestamp[player] ~= nil`. Health arm: `(Humanoid.Health < HP_IMMINENT_THRESHOLD AND lastPredatorDamageTimestamp[player] ~= nil)`. Time arm: `(lastPredatorDamageTimestamp[player] ~= nil AND (now - last) < DAMAGE_RECENT_WINDOW)`. Added "Pillar 2 (cost attribution) — both arms are predator-scoped" prose paragraph documenting the rationale + the closed exploit ("HP=24 from oxygen-depletion + disconnect = NO Path B"). |
| 5 | PredatorService init-order race (`nil - number` runtime crash) | C.5.3 predicate prose + F.4 mandate | Added "Init-order safety — nil-guard explicit" paragraph in C.5.3 documenting that both predicate arms short-circuit on `~= nil` BEFORE any subtraction; Luau short-circuit AND semantics guarantee no `nil - number` arithmetic ever evaluates. F.4 separately mandates `PredatorService` initializes the table to `{}` before any `PlayerAdded` can fire. Defence-in-depth: arm-level nil-check + table-level bootstrap init. |
| 6 | OQ.1 closure contradicts V/A.3 walk footstep row | V/A.3 walk row | Replaced the contradicting sentence ("Whether Predator AI's perception consumes footstep audio is a Predator AI GDD decision, not this GDD's") with: "**Walk footstep audio is NOT a predator-perception input** (OQ.1 closed, Theme 1) — predator consumes only the discrete `DisturbanceService:Emit()` mechanical contracts (`SprintEmission`, `LightEmission`); positional walk audio is player-feedback only." Added cosmetic-boundary clauses (volume / radius / cadence locked; timbre is the only permitted cosmetic dimension). |
| 7 | `t_entry` vs `t_0` variable name inconsistency | D.4 + C.8 + H.11b | Renamed `t_entry` → `t_0` in 6 occurrences across the doc: D.4 formula expression (line 330 prior), D.4 example prose (line 377 prior), C.8.1 sprint cooldown rule (line 210 prior, both subtraction and assignment uses), C.8.2 light cooldown rule (line 219 prior, both uses), and H.11b AC's WHEN clause (line 849 prior). `t_0` was already the canonical name in the variables table and in E.C — chose `t_0` over `t_entry` for that reason. |

### Items Intentionally NOT Touched (Out of Patch Scope)

- **H.22b AC** (line ~855) — its setup (`Humanoid.Health = 20`, no mention of predator damage) no longer triggers Path B under the new predicate. This was reclassified as Theme 4 / cross-cut testability per CD's prior verdict; not a Theme-1-round-2 BLOCKING item. Producer + qa-lead should rewrite H.22b in the Theme 4 sweep to add a `lastPredatorDamageTimestamp[A] != nil` precondition.
- **All RECOMMENDED items (14)** — including D.4 nil-guard short-circuit dependency note, D.5 30 s trace pulse-magnitude column, axis = emissionType future-proofing, GRACE_REENTRY_COOLDOWN per-axis floor docs, PlayerHeartbeat S1-flood DoS guard, etc. These remain RECOMMENDED-tier; deferred to Theme 2/3/4 fresh sessions.
- **All NICE-TO-HAVE items (7)** — deferred.
- **Themes 2/3/4 + cross-cut + OQ.3** — explicitly out of scope; CD's prior verdict was "do not proceed to Theme 2 until these seven Theme-1-round-2 fixes land," which this patch satisfies.

### Verification (read-back / grep)

- `t_entry` count after patch: **0** (verified via grep on full file).
- `_deathCostPaid` references: 4 in C.5.3 (was 1) + 1 H.22b + 1 H.21 references kept intact.
- `_lastHeartbeatTime` references: now spans full lifecycle in E.D + 1 H.33c reference kept intact.
- `lastPredatorDamageTimestamp` references: predicate, prose, F.4 lifecycle, H.22c reference kept intact.
- "Predator AI GDD decision, not this GDD" phrasing (the OQ.1-contradicting V/A.3 walk-row text): **0 occurrences** remaining (was 1).

### Recommended Next Action

**Run `/design-review design/gdd/player-controller.md` in a fresh session** to validate the patch before advancing to Theme 2. Per the `/design-review` skill default, this will spawn the same 7 specialists as the prior review (game-designer, systems-designer, network-programmer, audio-director, qa-lead, ai-programmer, performance-analyst) plus creative-director synthesis. Expected outcome if patch is sound: verdict APPROVED for Theme 1, releasing the gate for Theme 2 (Roblox API verification per the round-1 review's Recommended Round-2 Sequence step 2).

### Files Modified This Session

- `design/gdd/player-controller.md` — 906 → 935 lines (the patch itself; 6 edits across C.5.3, C.8.1, C.8.2, D.4, E.D, F.4, V/A.3, H.11b).
- `design/gdd/systems-index.md` — PC row updated with patch-applied note + status-summary line 178 updated to reflect re-review pending.
- `design/gdd/reviews/player-controller-review-log.md` — this entry appended.
- `production/session-state/active.md` — replaced with patch-complete state.
- Auto-memory `project_terranova.md` — updated to reflect patch landed.

---

## Review — 2026-05-02 — Round-3 — Verdict: NEEDS REVISION (Theme-1-round-2 patch validation)

**Scope signal:** S (single fresh session, 5 surgical edits + 1 AC + 1 user design decision; no new sections; no new ADRs. Smaller than the round-2 Theme-1 patch which was M.)
**Specialists:** game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead, creative-director (senior synthesis). 6 specialists spawned in parallel adversarially; CD synthesized.
**Blocking items:** 5 BLOCKING (B1–B5) + 1 AC addition (H.22d) | **Recommended:** ~14 IMPORTANT | **Nice-to-have:** ~6
**Prior verdict resolved:** Partially — patch closed roughly 5 of 7 prior BLOCKING items at the rule level (set-before-yield discipline; `_lastHeartbeatTime` lifecycle; predicate scoping intent; init-order nil-guard; `t_entry`→`t_0` rename in GDD prose). Three closures are incomplete in ways that re-open the exact failure modes the patch targeted (HP-arm Pillar 2 violation; yield-enumeration completeness; F.4 nil-table-vs-nil-entry distinction). One closure (V/A.3 walk-row OQ.1) is rule-level correct in the table cell but the governing prose at line 704 still implies sprint-only scope. One AC (H.22b) directly contradicts the patched predicate.
**Review depth:** full (per `/design-review` default; 6 specialists spawned in parallel adversarially, then creative-director senior synthesis)

### Summary

The round-3 re-review found the patch's 7 claimed closures break down as **GDD-rule-closed: 0/7 fully clean**; **PARTIAL: 6/7 (closures are structurally correct but have a residual defect)**; **GDD-side closed but registry-side open: 1/7 (`t_entry` rename completed in GDD; `entities.yaml` lines 726-727 still reference `t_entry`)**. The most severe finding is that **Pillar 2 (cost attribution) is still NOT delivered at the rule level** — the HP arm of the imminent-death predicate has no time bound, so a 600-second-old predator graze on a player whose proximate cause of low HP is oxygen-depletion still triggers Path B. This is the same defect class round-2 Theme 1 was designed to close, narrowed in surface area but not eliminated.

### Patch Closure Audit (1:1 with prior 2026-05-02 7 BLOCKING items)

| # | Patch item | Status | Residual defect |
|---|---|---|---|
| 1 | `_deathCostPaid` set-before-yield atomicity | **PARTIAL** | Yield-point enumeration omits `BindableEvent:Wait()`, bare `coroutine.yield`, deferred Knit signal dispatch; includes `:InvokeServer` (client-side API; category error on server side) [network-programmer CRIT-1; systems-designer Item 9] |
| 2 | `_lastHeartbeatTime` initialization on T1 lifecycle | **PARTIAL** | `PlayerHeartbeat` rate-limit-vs-write ordering not specified — flood at 100/s could update timestamp before drop check, defeating `SPRINT_CLIENT_TIMEOUT` [network-programmer CRIT-2]. T2-then-T1 same-tick ordering gap [game-designer F5] |
| 3 | `lastPredatorDamageTimestamp` lifecycle/clearance | **PARTIAL** | F.4 bootstrap-init `{}` defends nil-entry but not nil-table — early `Players.PlayerRemoving` before `KnitStart()` completes still crashes [network-programmer CRIT-3; ai-programmer Important-4]. T6 transition table row in C.6 lacks cross-ref to F.4 clearance obligation [game-designer F6] |
| 4 | Predicate health-arm predator-scoped | **NOT CLOSED at fantasy level** | HP arm has no time bound: 600s-old predator graze + oxygen-depletion → Path B fires. "Predator demonstrably contributed" framing not defensible at 600s timescales when oxygen is proximate cause [game-designer F3 + ai-programmer Critical-1 — convergent]. Same defect class as round-1, narrowed but not eliminated. |
| 5 | Init-order nil-guard prose | **PARTIAL** | Line 120 prose is imprecise about which arm provides which protection (arm 1 nil-check is right-operand and serves predator-scope gate, not nil-arithmetic protection) [ai-programmer Critical-2]. Logic is correct; future implementer could misread. |
| 6 | V/A.3 walk row OQ.1 alignment | **PARTIAL** | Table cell aligned (line 708). Governing prose at line 704 still sprint-only — boundary paragraph implies exhaustive perception list of `SprintEmission`+`LightEmission` for sprint footstep audio only; walk exclusion lives only in table cell [audio-director F1]. V/A.6 walk cosmetic-equivalence test now incoherent (verifies "disturbance generation unchanged" — a property walk audio doesn't possess post-OQ.1) [audio-director F2]. |
| 7 | `t_entry` → `t_0` rename | **GDD-CLOSED, REGISTRY-OPEN** | 0 occurrences in GDD (grep confirmed). `design/registry/entities.yaml` lines 726-727 still reference `t_entry` in formula expression and variables list — binding registry-vs-GDD divergence [systems-designer Item 8]. |

### Senior Verdict (creative-director)

> The patch closed roughly **5 of 7 BLOCKING items at the rule level** — set-before-yield discipline, `_lastHeartbeatTime` lifecycle, predicate scoping intent, init-order nil-guard, GDD-side `t_entry` rename. But three closures are incomplete in ways that re-open the exact failure modes the patch targeted, plus one closure has a contradicting AC left in-place that will produce a false regression bug.
>
> **Pillar 1** (deliberate transaction at the rule level): **mostly delivered.** T1 + T2 lifecycle is now precise; set-before-yield discipline gives the audio commitment teeth at the spec level. Walk-row OQ.1 reconciliation closes the asymmetry that contradicted the fantasy.
>
> **Pillar 2** (predator damage costs are paid, not absorbed by oxygen ticks): **NOT delivered.** The HP arm with no time bound means a 10-minute-old graze still triggers Path B when oxygen is the proximate cause of death. This is the *same fantasy violation* round-2 was meant to close — narrowed in surface area, but the framing at line 118 ("predator demonstrably contributed") is not defensible at 600-second timescales. Two specialists converging on the same defect class as round-1 is dispositive.
>
> Theme 1 is not closed. Five binding fixes (B1–B5) plus one AC addition (H.22d). B1 is the only one requiring a user design decision; B2–B5 are mechanical. Round-3-patch effort: B1 user-decision + ~60 min implementation; B2–B5 ~30 min combined. One more focused session, then fresh-context re-review, then Theme 1 ships.

### Specialist Convergences

- **HP arm time bound** — game-designer (F3) + ai-programmer (Critical-1, Important-3). Same Pillar 2 defect class as round-1, narrowed but not eliminated. Two-angle convergence on the load-bearing claim "predator demonstrably contributed."
- **H.22b contradicts patched predicate** — game-designer (F2) + qa-lead (CRIT-1). Two-angle convergence on AC-vs-rule contradiction.
- **F.4 bootstrap-init defends nil-entry, not nil-table** — network-programmer (CRIT-3) + ai-programmer (Important-4). Two-angle convergence on init-order race scope.
- **Yield-point enumeration incompleteness** — network-programmer (CRIT-1) + systems-designer (Item 9). Two-angle convergence on the set-before-yield rule's enumeration completeness as load-bearing.
- **V/A.3 boundary prose vs table cell** — audio-director (F1, F5). Single-angle but high-confidence: rule statements must be self-defending; table cell is data, paragraph is the rule.

### Specialist Disagreements (CD-resolved)

1. **HP arm severity** — game-designer + ai-programmer say CRITICAL; patch claimed closed. **CD ruling: CRITICAL stands** — "predator demonstrably contributed" framing not defensible at 600s timescales. Binding fix B1.
2. **H.22b severity** — game-designer + qa-lead say CRITICAL; network-programmer says NICE-TO-HAVE; patch log said deferred. **CD ruling: CRITICAL stands** — internally-contradicting AC will produce false-fail regression bug. Binding fix B2.
3. **V/A.3 line 704 prose** — audio-director says CRITICAL; patch addressed table cell only. **CD ruling: audio-director correct** — rule statements must be self-defending. Binding fix B4.

### Binding Fixes (must close before Theme 2 begins)

| ID | Fix | Section | Specialist source |
|---|---|---|---|
| **B1** | Add a time bound to the predicate's HP arm. **USER DECISION LOCKED 2026-05-02: Option A** — mirror arm 2 with `(now - lastPredatorDamageTimestamp[player]) < HP_ARM_RECENT_WINDOW`. **Default `HP_ARM_RECENT_WINDOW = 30 s`** per CD recommendation (preserves the "hunted moment" without absorbing slow-death scenarios). Round-3 patch must: (a) update C.5.3 predicate HP arm to add the time-bound conjunct; (b) rewrite line 118 prose to defend the 30s window (no longer "no time bound — the predator caused the state"); (c) register `HP_ARM_RECENT_WINDOW` in `design/registry/entities.yaml` and add a row to G.6 Death/Respawn Knobs (recommend range 15–60 s; Too Low: legitimate "lethal combo in flight" misclassified as non-predator; Too High: stale-graze false-positive class re-opens). | C.5.3 lines 109-118; G.6; entities.yaml | game-designer F3 + ai-programmer Critical-1 + creative-director synthesis |
| **B2** | Fix or annotate H.22b. Preferred: update setup to include `lastPredatorDamageTimestamp[A] != nil` (predator damage at t-5s). Acceptable: inline `[DEFERRED — Theme 4]` notice. | H.22b line 884 | qa-lead CRIT-1 + game-designer F2 |
| **B3** | Rewrite E.E line 503 predicate summary using the patched predicate verbatim (both nil-checks; post-B1 time bound). Edge case section must describe the same predicate as the rules section. | E.E line 503 | game-designer F1 |
| **B4** | Update V/A.3 governing paragraph (line 704) so walk and sprint are both covered by the rule statement, not just the table data row. Suggested form: "Footstep audio (walk and sprint) is positional 3D feedback for player-to-player perception; predator AI consumes the disturbance signal, not the audio." Closes F5 OQ.1-conflict by pre-establishing PC-side scope. | V/A.3 line 704 | audio-director F1 + F5 |
| **B5** | Rename `t_entry` → `t_0` in `design/registry/entities.yaml` lines 726-727 (formula expression + variables list). Registry-vs-GDD divergence is binding-violation class. | `design/registry/entities.yaml` lines 726-727 | systems-designer Item 8 |
| **H.22d** | Add new AC for Path B time-arm in isolation (HP=100, recent timestamp). Arm 2 of patched predicate has zero coverage. | Section H | qa-lead CRIT-2 |

### Forward-Obligation List (NOT blocking Theme 1 — defer to Themes 2/3/4)

Document these in the round-3 patch session so they don't fall through:

- **Theme 2 (Roblox API verification)**: Yield-point enumeration completeness (BindableEvent:Wait, coroutine.yield, deferred Knit signals). PlayerHeartbeat rate-limit timestamp-write ordering. PlayerRemoving signal-ordering claim citation. Cross-service direct table read Knit-idiom note.
- **Theme 3 (downstream contract)**: Sprint row +3-4 dB self-defending prose. V/A.4 walk caption row asymmetry. Lantern raise/Death SFX predator-perception annotations. OQ.1 closure text "plus any contracts" phrasing reconciliation with line 704.
- **Theme 4 (mobile-floor / accessibility / cross-cut)**: F.4 nil-table-vs-nil-entry distinction. T6 cross-ref to `lastPredatorDamageTimestamp` clearance. `_deathCostPaid` lifecycle clearance rule. 0-timestamp sentinel exclusion in F.4. AC additions H.33d (T1 seeding), H.33e (T2/T5 clearance), H.22e (concurrent-path race). C.5.3 atomicity structural mandate (`_tryClaimDeathCost(player): bool` named helper). Line 120 prose precision on which arm provides which protection. T2-then-T1 same-tick ordering for `_lastHeartbeatTime`. KnitInit (not KnitStart, not "construction") for F.4 bootstrap-init.

### Recommended Round-3 Patch Sequence

Single fresh session per `.claude/docs/context-management.md` "one theme per session" guidance:

1. **B1 user design decision** — present the three options to the user upfront via `AskUserQuestion`; cascade the resulting choice through C.5.3 predicate, C.5.3 prose at line 118, and any AC that depends on arm 1 semantics (H.22b setup if Option A selected).
2. **B2 H.22b correction** — update setup to align with patched predicate.
3. **B3 E.E line 503 rewrite** — propagate patched predicate to edge case summary.
4. **B4 V/A.3 line 704 governing paragraph rewrite** — extend boundary prose to cover walk + sprint.
5. **B5 `entities.yaml` rename** — `t_entry` → `t_0` in expression + variables list.
6. **H.22d new AC** — Path B time-arm in isolation.

After this round-3 patch closes, run `/design-review design/gdd/player-controller.md` in another fresh session to validate before advancing to Theme 2 (Roblox API verification).

### Files Referenced (round-3 review)

- Target: `design/gdd/player-controller.md` (935 lines, status: NEEDS REVISION; round-2 Theme-1 patch applied 2026-05-02; round-3 review complete 2026-05-02)
- Registry: `design/registry/entities.yaml` (lines 726-727 — `t_entry` divergence flagged as B5)
- Upstream: `design/gdd/ecological-disturbance.md` (round-7 pending), `design/gdd/crafting-and-items.md` (round-2 pending)
- Cross-cited: `design/gdd/game-concept.md`, `design/gdd/systems-index.md`, `docs/engine-reference/roblox/VERSION.md`
- Standards: `.claude/docs/coding-standards.md`, `.claude/docs/technical-preferences.md`, `design/CLAUDE.md`, `.claude/rules/design-docs.md`

---

## Patch Applied — 2026-05-02 — Round-3 (NOT a review verdict; closes 5 BLOCKING items B1–B5 + H.22d from prior 2026-05-02 round-3 entry)

**Type:** Patch session, not a review. The next `/design-review` of this GDD is the binding validation gate.
**Scope signal:** S (matches prior review's S-scope estimate — 5 surgical edits + 1 new AC; no new sections; no new ADRs touched. B1 user decision was already locked at the prior review.).
**Specialists:** None spawned this session (patch-only; the prior 2026-05-02 round-3 review already established the binding fix list and the B1 design decision).
**Editor:** Single fresh session per `.claude/docs/context-management.md` "one theme per session" guidance.
**File delta:** `design/gdd/player-controller.md` grew 935 → 938 lines (+3 net; 6 edit sites, content additions outweighed by some removed boilerplate). `design/registry/entities.yaml` gained one constant entry (`HP_ARM_RECENT_WINDOW`) and one rename in the `pulseEmissionMagnitude` formula (`t_entry` → `t_0`).

### Edits Applied (1:1 with prior review's 5 BLOCKING items + H.22d)

| # | BLOCKING item from prior 2026-05-02 round-3 entry | Section edited | Edit |
|---|---|---|---|
| B1 | HP arm has no time bound (Pillar 2 stale-graze false-positive — same defect class as round-1, narrowed but not eliminated) | C.5.3 predicate (lines 109-115); C.5.3 prose (line 118); G.6 (Death/Respawn Knobs); `design/registry/entities.yaml` (between `DAMAGE_RECENT_WINDOW` and `GRACE_REENTRY_COOLDOWN`) | Per locked user decision (Option A, default 30 s): (a) added `AND (workspace:GetServerTimeNow() - lastPredatorDamageTimestamp[player]) < HP_ARM_RECENT_WINDOW` conjunct to predicate's HP arm; (b) updated `where` line to add `HP_ARM_RECENT_WINDOW = 30.0 s` (default; range 15–60); (c) rewrote line 118 Pillar 2 prose — replaced "no time bound — the predator caused the state" with the 30 s defence (recent graze + current low HP makes predator credible proximate cause; explicit closure of the round-3 600 s stale-graze defect; tuning band articulated for both directions); (d) added G.6 row with too-low / too-high text; (e) registered `HP_ARM_RECENT_WINDOW = 30.0 s` constant in entities.yaml with cross-system note about reading from PredatorService-owned table. |
| B2 | H.22b AC contradicts patched predicate (would file false regression bug — tester sees Path B not firing despite low HP) | H.22b (line ~884) | Setup now reads `Humanoid.Health = 20` AND `lastPredatorDamageTimestamp[A] = workspace:GetServerTimeNow() - 5` (5 s ago — within 30 s `HP_ARM_RECENT_WINDOW`, outside 3 s `DAMAGE_RECENT_WINDOW`, so only arm 1 carries). Verifies clause expanded to "all three conjuncts satisfied: low HP, non-nil timestamp, timestamp within `HP_ARM_RECENT_WINDOW`." |
| B3 | E.E line 503 predicate summary describes pre-patch un-scoped OR (rules-vs-edge-case divergence) | E.E line 503 | Replaced informal summary `(Health < HP_IMMINENT_THRESHOLD OR (now - lastPredatorDamageTimestamp) < DAMAGE_RECENT_WINDOW)` with full patched predicate verbatim — both arms predator-scoped (nil-check) AND time-bounded against the predator timestamp (HP arm via `HP_ARM_RECENT_WINDOW`, time arm via `DAMAGE_RECENT_WINDOW`). Added closing sentence noting non-predator near-death disconnects pay nothing. |
| B4 | V/A.3 line 704 governing prose covers sprint footstep only; walk exclusion lives only in table cell (rule statements must be self-defending) | V/A.3 line 704 | Replaced "Sprint footstep audio is positional 3D feedback for the sprinting player and nearby squad members only..." with "**Footstep audio — both walk and sprint — is positional 3D feedback for player-to-player perception (own player + nearby squad members) only.** Neither walk nor sprint footstep audio is consumed by the predator AI..." Added explicit "predator does not 'hear' walking any more than it 'hears' sprinting" parallel + closing "Walk footsteps remain low-volume aural feedback at the same boundary" sentence. OQ.1 closure now lives in the rule statement, not just the table data row. |
| B5 | `design/registry/entities.yaml` lines 726-727 reference `t_entry` (registry-vs-GDD divergence; binding-violation class) | `design/registry/entities.yaml` lines 726-727 | Renamed `t_entry` → `t_0` in formula expression (cooldown subtraction). Removed `t_entry` from variables list (`t_0` was already present). Net: 0 occurrences of `t_entry` remaining anywhere in the registry or the GDD. |
| H.22d | Path B time-arm (arm 2) had zero coverage — qa-lead CRIT-2 | H.22d (new AC inserted between H.22c and H.23) | Added new AC: HP=100 (above `HP_IMMINENT_THRESHOLD`, so arm 1 cannot fire — guarded explicitly by the nil-check on its own `lastPredatorDamageTimestamp` conjunct AND the HP threshold) AND `lastPredatorDamageTimestamp[A] = workspace:GetServerTimeNow() - 1.5` (within `DAMAGE_RECENT_WINDOW = 3.0 s`). THEN squad oxygen decrements; `OnPlayerDied(deathCause="disconnect-while-damaged")` broadcast. Verifies arm 2 carries the predicate in isolation. |

### Items Intentionally NOT Touched (Out of Patch Scope)

- **All RECOMMENDED items (~14) and NICE-TO-HAVE items (~6)** — yield-point enumeration completeness (BindableEvent:Wait, coroutine.yield, deferred Knit signals), `PlayerHeartbeat` rate-limit timestamp-write ordering, F.4 nil-table-vs-nil-entry, T6 cross-ref to `lastPredatorDamageTimestamp` clearance, `_deathCostPaid` lifecycle clearance rule, AC additions H.33d/H.33e/H.22e, V/A.4 walk caption parity, OQ.1 closure text "plus any contracts" phrasing, line 120 prose precision on which arm provides which protection, etc. All deferred to Themes 2/3/4 fresh sessions per CD's prior verdict.
- **Themes 2/3/4 + cross-cut + OQ.3** — explicitly out of scope; CD's prior verdict was "do not proceed to Theme 2 until these five round-3 fixes plus H.22d land," which this patch satisfies.

### Verification (read-back / grep)

- `t_entry` count after patch in **entities.yaml**: **0** (was 2). `t_entry` count in player-controller.md: **0** (already closed in prior round-2 patch). Both files now consistently use `t_0`.
- `HP_ARM_RECENT_WINDOW` references after patch: 6 in player-controller.md (predicate body, where-line, line 118 prose × 2, G.6 row, H.22b verifies clause), 1 in entities.yaml (registered constant + notes), 1 in systems-index.md, 1 in this review log.
- `no time bound — the predator caused the state` (the round-3-defective phrase): **0** occurrences (was 1).
- H.22 sequence: H.22 → H.22b → H.22c → H.22d → H.23 (verified by grep `^- \*\*H\.22`).
- Read-back of patched C.5.3 predicate + line 118 prose: **OK** (predicate → predator-scope-AND-time-bounded prose → init-order safety → idempotency intro → set-before-yield discipline reads cleanly top-to-bottom; the new 30 s defence integrates with the existing Pillar 2 paragraph without contradiction).
- File line counts: player-controller.md **935 → 938** (+3 net, 6 edit sites — most edits expanded existing content rather than adding new); entities.yaml gained one constant entry (~7 lines) and adjusted one formula entry (-1 var token).

### Recommended Next Action

**Run `/design-review design/gdd/player-controller.md` in a fresh session** to validate the round-3 patch before advancing to Theme 2. Per the `/design-review` skill default, this will spawn the same 6 specialists as the round-3 review (game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead) plus creative-director synthesis. Expected outcome if patch is sound: verdict APPROVED for Theme 1, releasing the gate for Theme 2 (Roblox API verification per the round-1 review's Recommended Round-2 Sequence step 2).

### Files Modified This Session

- `design/gdd/player-controller.md` — 935 → 938 lines (the patch itself; 6 edit sites across C.5.3, G.6, V/A.3, E.E, H.7).
- `design/registry/entities.yaml` — added `HP_ARM_RECENT_WINDOW` constant entry; renamed `t_entry` → `t_0` in `pulseEmissionMagnitude` formula expression + variables list.
- `design/gdd/systems-index.md` — PC row updated with round-3 patch-applied note + status-summary line updated to reflect round-3 patch closure pending re-review.
- `design/gdd/reviews/player-controller-review-log.md` — this entry appended.
- `production/session-state/active.md` — replaced with round-3 patch-complete state.
- Auto-memory `project_terranova.md` — updated to reflect round-3 patch landed.

---

## Review — 2026-05-02 — Round-4 — Verdict: MAJOR REVISION NEEDED (Round-3 patch validation)

**Scope signal:** M (single fresh session, 6 surgical edits + ~6 IMPORTANT prose/AC additions; no new sections; 1 new "Testability Contract" subsection. ~2-3 hours focused single-session patch effort.)
**Specialists:** game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead, creative-director (senior synthesis). 6 specialists spawned in parallel adversarially; CD synthesized.
**Blocking items:** 6 BLOCKING (B6–B11) | **Recommended:** ~14 IMPORTANT | **Nice-to-have:** ~12
**Prior verdict resolved:** Partially — round-3 B1–B5 + H.22d closed at the rule level (predicate, prose, registry, AC mutually consistent). However, round-3 closure perimeter was wrong: the patch focused on the predicate, while round-4 found the **predicate's downstream Path B execution is broken in 3 independent ways** plus 3 additional Theme-1 defects.
**Review depth:** full (per `/design-review` default; 6 specialists spawned in parallel adversarially, then creative-director senior synthesis)

### Summary

The round-3 patch closed its 5 named items + H.22d at the rule level — predicate, prose, registry, and AC are mutually consistent and the patch executed as described. **However, two-specialist convergences surfaced 6 new BLOCKING items inside Theme 1 scope (rule-level cost attribution for Path B), not deferrable to Themes 2/3/4.** Most severely:

- **Pillar 2 NOT delivered at the rule level** (3-way convergence on Path B downstream): (1) `_deathCostPaid` never cleared on T6 — second death per session pays zero squad oxygen [ai-programmer F1]; (2) PlayerRemoving teardown-order race between PredatorService and PC silently nulls the patched HP-arm predicate [network-programmer C2 + ai-programmer F2]; (3) no rollback path when `RequestSquadOxygenSpend` fails [network-programmer C1].
- **Round-3 H.22d/B2 closures are conditionally paper** without a clock-injection seam — `workspace:GetServerTimeNow()` cannot be mocked in TestEZ/Lemur, making H.22b/H.22c/H.22d/H.33a/H.33b non-executable as written [qa-lead F1].
- **G1 exploit class re-opens under server jitter** — missed-grace-window pulses do not consume grace eligibility; under thermally-throttled mobile servers the exploit returns [systems-designer F5].
- **Boundary semantics undocumented** — HP=25 exactly does NOT fire arm 1 due to strict `<`; same for `< HP_ARM_RECENT_WINDOW` [systems-designer F10 + ai-programmer F4 — convergent].

### Patch Closure Audit (1:1 with prior round-3 5 BLOCKING items + H.22d)

| # | Patch item | Status | Residual defect |
|---|---|---|---|
| B1 | HP arm time bound `HP_ARM_RECENT_WINDOW = 30s` | **CLOSED at predicate level** | Downstream Path B execution broken in 3 places (B6/B7/B8); patch closed the predicate but missed the predicate's downstream lifecycle/race/atomicity |
| B2 | H.22b setup updated | **CONDITIONALLY CLOSED** | Paper-only without clock-injection seam (B10) — TestEZ/Lemur cannot mock `workspace:GetServerTimeNow()` |
| B3 | E.E line 504 predicate summary rewritten | **CLOSED** | None |
| B4 | V/A.3 line 706 governing prose | **CLOSED with prose ambiguity** | "the same boundary" antecedent ambiguous in closing sentence [audio-director F1-R4 IMPORTANT] |
| B5 | entities.yaml `t_entry`→`t_0` rename + `HP_ARM_RECENT_WINDOW` registered | **CLOSED** | Verified line 474 + lines 732-735 |
| H.22d | New AC for arm 2 in isolation | **CONDITIONALLY CLOSED** | Same paper-only as B2; observability gap (cannot distinguish which arm fired without white-box predicate inspection) |

### Senior Verdict (creative-director)

> **Pillar 2 not delivered at the rule level.** ai-programmer F1 (`_deathCostPaid` never clears on T6) + network-programmer C2 (PlayerRemoving teardown race) + network-programmer C1 (no rollback) form a three-way convergent break of "every death must feel earned." From life #2 onward, OR under realistic Knit teardown ordering, OR under any RemoteFunction failure, the squad pays nothing. The round-3 patch fixed the predicate; round-4 found the predicate's downstream is broken in three places.
>
> **The round-3 closure of H.22d/B2 is conditionally paper.** Without B10 (clock-injection seam), the AC that round-3 added cannot be written into TestEZ. qa-lead F1 is dispositive — ACs that cannot be written into TestEZ are not ACs.
>
> **G1 exploit class re-opens under server jitter** [systems-designer F5]. Realistic on Roblox mobile servers — a Pillar 2 anti-exploit invariant that fails under thermal throttling is a Theme-1 defect, not a Theme-2 deferral.
>
> **Theme-1 perimeter was wrong.** Round-3 patched 5 named items inside the predicate; round-4 found the predicate's lifecycle, atomicity, jitter behaviour, and testability all broken. Closing Theme 1 requires expanding scope to the full Path-B execution chain.
>
> Two-specialist convergences (B6/B7 ai+network; B11 systems+ai) are binding evidence, not noise. Six binding fixes (B6–B11) plus ~6 IMPORTANT prose/AC additions. Round-4 patch effort: ~2-3 hours focused single-session. Then fresh-context re-review (round 5). Then, and only then, advance to Theme 2.

### Specialist Convergences

- **PlayerRemoving teardown-order race** [network-programmer C2 + ai-programmer F2] — PredatorService clears `lastPredatorDamageTimestamp` on PlayerRemoving; PC reads it. Knit-service connection ordering non-deterministic. Two angles, same defect: round-3 patch is conditionally vacuous depending on Knit teardown order.
- **HP_IMMINENT_THRESHOLD + HP_ARM_RECENT_WINDOW boundary semantics** [systems-designer F10 + ai-programmer F4] — `<` strict; HP=25 exactly does NOT fire arm 1. Same for `< 30.0s`. Convergent flag: undocumented boundary semantics in the same predicate the round-3 patch touched.
- **Scenario C false-negative class** [game-designer F1 + ai-programmer F3] — 35s post-graze panic-flee + oxygen-depletion disconnect pays nothing under 30s upper bound. Line 119 prose acknowledges only the false-positive direction; the false-negative class is silent.
- **Cost-attribution lifecycle** (carries from round-3 to round-4) — ai-programmer F1's `_deathCostPaid` T6 clearance gap was vaguely mentioned in round-3's forward-obligation list as "Theme 4 cleanup" but is in fact a Pillar 2 break at the rule level, not a cleanup item.

### Specialist Disagreements (CD-resolved)

1. **game-designer F4/F5 severity** — game-designer rated CRITICAL (Path B legibility for returning player + emote-wheel HP/stamina coordination). **CD overruled to IMPORTANT** with rationale: both are HUD GDD scope, not Theme-1 rule-level cost attribution. **Defer as forward obligations to the HUD GDD.**
2. **B10 (clock-injection) Theme-1 vs Theme-4** — Lenient reading would defer testability to Theme 4 cross-cut. **CD overruled to Theme-1 BLOCKING**: ACs that cannot be written into TestEZ are not ACs; round-3 closure of H.22d/B2 is performative without this seam.
3. **B9 (jitter exploit) Theme-1 vs Theme-2** — Could be deferred as Roblox API verification. **CD overruled to Theme-1 BLOCKING**: Roblox mobile thermals make the trigger plausible; a Pillar 2 anti-exploit invariant that fails under thermal throttling is a Theme-1 defect.

### Binding Fixes (must close before Theme 2 begins)

| ID | Fix | Section | Specialist source |
|---|---|---|---|
| **B6** | `_deathCostPaid` lifecycle clearance on T6 — add `_deathCostPaid[player] = false` to T6 transition table side-effects column; update line 123 prose to specify "init false at session start AND on every T6 (respawn) transition." Add AC verifying second-death-per-session decrements squad oxygen. | T6 transition table (line ~180); C.5.3 line 123; H.7 (new AC) | ai-programmer F1 |
| **B7** | PlayerRemoving teardown-order race — PC's `PlayerRemoving` handler MUST read-and-cache `lastPredatorDamageTimestamp[player]` into a local AS THE FIRST STATEMENT, before any await/yield. Spec must state read-cache-evaluate ordering explicitly. Optionally add cross-service ordering contract (PredatorService MUST NOT clear on PlayerRemoving until after PC handler completes). | C.5.3 Path B handler entry (lines ~104-105); F.4 PredatorService row (line 569) | network-programmer C2 + ai-programmer F2 (convergent) |
| **B8** | Rollback path for `RequestSquadOxygenSpend` failure — Path B handler must protect `_deathCostPaid` set with `pcall`-protected RemoteFunction call; on failure, clear flag back to false and surface to a server log channel. Add AC verifying flag-rollback on simulated RemoteFunction failure. | C.5.3 set-before-yield discipline (lines 125-135); H.7 (new AC) | network-programmer C1 |
| **B9** | D.4 grace-window jitter exploit — record `t_lastGracePulse[axis] = t_0` whenever `grace_eligible == true` at evaluation time, regardless of whether grace-window check passes. Update G.6 invariants to document the new rule. | D.4 formula (lines 346-359); G.6 row | systems-designer F5 |
| **B10** | Clock-injection seam mandated in spec — add new "Testability Contract" subsection (under Dependencies or as new C.x) requiring DI seam (e.g., `getServerTime()` function reference, not direct `workspace:GetServerTimeNow()` calls inside time-sensitive logic). H.22b/H.22c/H.22d/H.33a/H.33b's GIVEN clauses must reference the injectable clock. | New subsection (Dependencies or C.x); H.22b/H.22c/H.22d/H.33a/H.33b GIVEN clauses | qa-lead F1 |
| **B11** | HP_IMMINENT_THRESHOLD + HP_ARM_RECENT_WINDOW boundary semantics — document `<` vs `<=` choice (HP=25 exactly does NOT fire arm 1 under current `<`); apply same documentation to `< HP_ARM_RECENT_WINDOW`. Consider aligning with line 515 `>=` precedent. G.6 + entities.yaml + predicate prose must align. | C.5.3 predicate (line 110); G.6 (lines 643, 648); entities.yaml | systems-designer F10 + ai-programmer F4 (convergent) |

### Recommended (NOT BLOCKING — close with B6-B11 patch or in next theme)

- **Audio cluster (close with patch)**: V/A.3 line 706 antecedent ambiguity (audio-director F1-R4); V/A.4 walk caption parity note (F3-R4); lantern SFX negative rule against per-LightEmission-pulse wiring (F4-R4); Path B death SFX positional 3D character-removal cut (F6-R4).
- **QA AC cluster (close with B10)**: H.22e/H.22f negation tests for arm 1 time-bound enforcement (qa-lead F2); H.10 subjective THEN clause rewrite (F4); H.33b should also verify `_lastHeartbeatTime` non-update under flood (F6); H.11f/H.11g for Light-axis cooldown coverage (F7); H.33c verifiability through public interface (F8); H.21/H.22 atomicity gap acknowledgment (F9).
- **Game-design IMPORTANT**: Line 118 prose acknowledge 30s is first-pass design intent (F1); Scenario C false-negative class acknowledgment in line 119 prose (F3, convergent with ai-programmer F3); RESPAWN_DELAY 2-player vs 4-player squad note (F9); HP_ARM_RECENT_WINDOW vs DAMAGE_RECENT_WINDOW 10:1 ratio rationale (F11).
- **Other IMPORTANT**: Player instance key validity on PlayerRemoving (ai-programmer F5); D.4 cooldown anchor documentation `t_0` vs pulse-fire time (systems-designer F4).

### Forward-Obligation List (NOT blocking Theme 1 — defer to Themes 2/3/4 / HUD GDD)

- **HUD GDD forward obligations**: Path B legibility for returning player (game-designer F4); emote-wheel HP/stamina coordination semantics OR squad-HUD HP visibility threshold-cross signal (game-designer F5).
- **Theme 2 (Roblox API verification)**: yield-point enumeration completeness; PlayerHeartbeat rate-limit-vs-write ordering; `OnPlayerDied` squad scoping mechanism (network-programmer I1); `RequestPing` `PING_ORIGIN_TOLERANCE` constant (I2); `RequestEmote` integer-typed slot validation (I3); `math.max(0, dt)` guard in D.1/D.2 (systems-designer F1); D.3 divide-by-zero precondition (F2).
- **Theme 3 (downstream contract)**: Danger emote vs Danger ping redundancy (game-designer F6); LANTERN_VISIBILITY_RADIUS contradiction 12 vs 20 studs (F7); V/A.6 sprint/walk volume lock vs OQ.1 closure (F8); Sprint button greying vs body-as-liability framing (F10); D.4 output range claim post-Crafting modifier stack (systems-designer F7); arm 1 prose precision (F11); audio F2/F5 (deferred from round-3).
- **Theme 4 (cross-cut testability)**: H.22e concurrent-path race; H.27/H.32 hardware fallback documentation; H.31 level-design prerequisite note; F.4 nil-table-vs-nil-entry distinction.
- **OQ.3** (Camera GDD decision) — pending before `/create-architecture`.

### Recommended Round-4 Patch Sequence

Single fresh session per `.claude/docs/context-management.md` "one theme per session" guidance:

1. **B6 — `_deathCostPaid` T6 clearance** (highest priority — Pillar 2 silent break). Update T6 transition table side-effects + line 123 lifecycle prose + add new AC.
2. **B7 — PlayerRemoving teardown ordering**. Update C.5.3 prose + F.4 PredatorService row.
3. **B8 — RequestSquadOxygenSpend rollback path**. Update set-before-yield discipline + add new AC.
4. **B9 — D.4 grace-window jitter fix**. One-line formula edit + G.6 invariant note.
5. **B10 — Clock-injection seam**. New "Testability Contract" subsection + cross-references in time-sensitive ACs.
6. **B11 — Boundary semantics documentation**. Predicate prose + G.6 + entities.yaml alignment.
7. **IMPORTANT cluster (audio + qa AC additions + game-design prose)**: ~30 min of additive prose/AC edits.

After this round-4 patch closes, run `/design-review design/gdd/player-controller.md` in another fresh session to validate before advancing to Theme 2.

### Files Referenced (round-4 review)

- Target: `design/gdd/player-controller.md` (938 lines, status: NEEDS REVISION; round-3 patch applied 2026-05-02; round-4 review complete 2026-05-02)
- Registry: `design/registry/entities.yaml` (B5 verified clean — `HP_ARM_RECENT_WINDOW = 30.0s` at line 474; `t_0` only in `pulseEmissionMagnitude` at lines 732-735)
- Upstream: `design/gdd/ecological-disturbance.md` (round-7 pending), `design/gdd/crafting-and-items.md` (round-2 pending)
- Cross-cited: `design/gdd/game-concept.md`, `design/gdd/systems-index.md`, `docs/engine-reference/roblox/VERSION.md`, `design/CLAUDE.md`, `.claude/rules/design-docs.md`
- Standards: `.claude/docs/coding-standards.md`, `.claude/docs/technical-preferences.md`

### Files Modified This Session

- `design/gdd/reviews/player-controller-review-log.md` — this entry appended.
- `design/gdd/systems-index.md` — PC row updated with round-4 verdict; status-summary line updated.
- `production/session-state/active.md` — replaced with round-4-pending state.

---

## Round-4 Patch — 2026-05-02 — Status: APPLIED

**Source:** Round-4 design-review entry above (`Review — 2026-05-02 — Round-4`). Single fresh session per `.claude/docs/context-management.md` "one theme per session" guidance. Full patch authorized by user — B6–B11 + IMPORTANT cluster.

**Patch effort:** ~2 hours single-session (scope M as forecast). 6 surgical BLOCKING edits + 6 IMPORTANT prose/AC additions + 1 new "Testability Contract" subsection. File grew 938 → ~1010 lines.

**Edits applied — 1:1 with binding fix list (B6–B11):**

| ID | Edit | Section(s) | Verification |
|---|---|---|---|
| **B6** | (1) C.5.3 line 123 prose updated to "init `false` at session start AND cleared back to `false` on every T6 (respawn) transition" with explicit "Without the T6 clearance, the second death of a session pays zero squad oxygen" rationale. (2) T6 transition table side-effects column adds `_deathCostPaid[player] = false` with cross-reference back to C.5.3 idempotency prose. (3) New AC **H.22e** added — verifies second-death-per-session decrements squad oxygen (T5 fires successfully on second life, oxygen 4→3). | C.5.3 line 123; C.6 T6 row; H.7 (new H.22e) | Pillar 2 multi-life closure |
| **B7** | (1) C.5.3 Path B handler entry now includes a full "Read-and-cache discipline" block stating "PC's `Players.PlayerRemoving` handler MUST read `lastPredatorDamageTimestamp[player]` into a local variable AS THE FIRST STATEMENT of the handler, before any yield-capable call" with an illustrative Luau code skeleton showing cache-first ordering. (2) F.4 PredatorService row expanded with a new bullet "Cross-service teardown ordering contract" mandating PC's cache-first ordering as the binding contract (PredatorService deferral is OPTIONAL belt-and-braces). (3) F.4 also adds a "Player instance key validity on `PlayerRemoving`" bullet covering the `Character`/`Humanoid` may-be-`nil` case via `FindFirstChild`. | C.5.3 ~line 105; F.4 PredatorService row | network-programmer C2 + ai-programmer F2 convergent close |
| **B8** | C.5.3 set-before-yield discipline replaced. New 6-step ordering: read flag → return if true → set true (atomic, before any yield) → invoke RemoteFunction inside `pcall` → on failure, roll back flag to false + log to server channel + skip broadcast → on success, broadcast `OnPlayerDied` and clear sprint state. New "try-or-rollback transaction at the rule level" rationale added. New AC **H.22f** verifies flag-rollback on simulated RemoteFunction failure (squad oxygen unchanged, `_deathCostPaid` ends at false). | C.5.3 lines 125–135; H.7 (new H.22f) | network-programmer C1 close |
| **B9** | (1) D.4 formula updated with a new Step 0a `if grace_eligible: t_lastGracePulse[axis] = t_0` block — anchor recorded on eligibility resolution, NOT on grace-window pass. The old `t_lastGracePulse[axis] = t_0` line inside the grace branch removed. (2) Anchor-on-eligibility rationale paragraph added — "the cost of an unfortunate jitter pulse is that the player loses one grace exemption they were entitled to; the benefit is that the G1 invariant holds under any server delivery latency." (3) G.6 `GRACE_REENTRY_COOLDOWN` row gains an "G.6 invariants" block with three points documenting the anchor rule + Pillar 1 enforcement asymmetry (cost-paid never cost-skipped). (4) New AC **H.11h** verifies the missed-grace-window jitter case — first pulse arrives at `t_0 + 1.5 s` (past grace window), `t_lastGracePulse[Sprint]` STILL set to `t_0` regardless, subsequent S2 entry at `t_0 + 5 s` observes `grace_eligible = false`. | D.4 lines 346–360; G.6 row; H.4 (new H.11h) | systems-designer F5 close |
| **B10** | New **C.11 — Testability Contract (clock-injection seam)** subsection added after C.10. Mandates `getServerTime()` DI seam wiring (production: `function() return workspace:GetServerTimeNow() end`; test: `function() return mockedTime end`). Lists every PC consumer of server time (sprint timer, light timer, regen delay, respawn timer, `_lastHeartbeatTime`, `SPRINT_CLIENT_TIMEOUT`, `lastPredatorDamageTimestamp`, C.5.3 predicate, C.5.3 cache snippet). Forbids inline `workspace:GetServerTimeNow()` calls inside PC code paths. Aligned with ED.D.1 by making the seam a thin wrapper. ACs **H.22b**, **H.22c**, **H.22d**, **H.33a**, **H.33b** all updated with `getServerTime()` injected (`getServerTime()` returns fixed `T`; timestamps expressed as `T - 5`, `T - 1.5` etc.) plus `**Test executability requires the C.11 clock-injection seam.**` annotation. | New C.11 subsection; H.22b/c/d, H.33a/b GIVEN clauses | qa-lead F1 close |
| **B11** | (1) C.5.3 predicate prose adds a new "Boundary semantics (B11 — comparators are strict `<`, not `<=`)" block documenting that HP=25.0 exactly does NOT fire arm 1 and that the same applies to both window comparators. Includes a principled-asymmetry rationale relative to E.F's `>=` ping cooldown precedent (player-friendly accept at boundary vs. squad-friendly reject at boundary). Practical "use 24.99 / 25.01" tuning guidance added. (2) G.6 boundary-comparator semantics block appended after the `HP_ARM_RECENT_WINDOW` row. (3) `entities.yaml` notes for `HP_IMMINENT_THRESHOLD`, `HP_ARM_RECENT_WINDOW`, `DAMAGE_RECENT_WINDOW` all extended with "Boundary semantics (B11 round-4): comparator is strict `<`, NOT `<=`." | C.5.3 line 117 area; G.6; entities.yaml | systems-designer F10 + ai-programmer F4 convergent close |

**IMPORTANT cluster (additive prose/AC):**

- **Audio (V/A.3 line 706 antecedent ambiguity)**: closing sentence rewritten — "Walk footsteps remain low-volume aural feedback **on the same player-feedback-only side of the audio-perception boundary defined above**" — disambiguating "the same boundary" by naming it explicitly (audio-director F1-R4).
- **C.5.3 prose — design-intent acknowledgment**: 30 s value of `HP_ARM_RECENT_WINDOW` is explicitly named as "first-pass design intent, not playtest-validated" with cross-reference to G.8.1 (game-designer F1).
- **C.5.3 prose — Scenario C false-negative class**: explicit acknowledgment that the strict 30 s upper bound classifies post-graze panic-flee + oxygen-depletion disconnects as non-payable, named as a chosen trade-off (alternative re-opens round-3 false-positive class), and flagged for future revision via tiered predicate (game-designer F1 + ai-programmer F3 convergent).
- **D.4 variable table — `t_lastGracePulse[axis]` semantics**: row description rewritten to capture B9 anchor-on-eligibility — "the state-entry timestamp `t_0` (NOT the pulse-fire time `t`) at the most recent state-entry on this axis that resolved `grace_eligible == true`. Anchored on eligibility, not on pulse fire." Source attributed to the C.11 seam-injected `getServerTime()` (systems-designer F4).
- **H.11f / H.11g — Light-axis cooldown coverage parity**: two new ACs mirroring H.11b/H.11c on the Light axis (cooldown active stationary → 0.024; cooldown active moving → 0.08). Closes round-1 lantern toggle-cycle 10× exploit at the AC level (qa-lead F7).
- **F.4 PredatorService — `getServerTime()` alignment**: PredatorService writer of `lastPredatorDamageTimestamp` updated from `workspace:GetServerTimeNow()` to `getServerTime()` per C.11 (qa-lead F1 spillover).

**Header status block updated**: Round-4 closures listed inline. Last Updated → 2026-05-02 (round-4 patch applied).

**Files Modified This Session:**

- `design/gdd/player-controller.md` — all B6–B11 + IMPORTANT edits; header status block updated.
- `design/registry/entities.yaml` — boundary semantics annotation appended to `HP_IMMINENT_THRESHOLD`, `HP_ARM_RECENT_WINDOW`, `DAMAGE_RECENT_WINDOW` notes.
- `design/gdd/systems-index.md` — PC row prose extended with round-4 patch closure record; Progress Tracker line updated.
- `design/gdd/reviews/player-controller-review-log.md` — this entry appended.
- `production/session-state/active.md` — replaced with round-5-pending state.

**Next action**: Run `/design-review design/gdd/player-controller.md` in a fresh session to validate the round-4 patch (round-5 review). Then, and only then, advance to Theme 2 (Roblox API verification). HUD GDD forward obligations (game-designer F4/F5 — Path B legibility for returning player; emote-wheel HP/stamina coordination) carry forward to whichever session authors `/design-system hud`.

---

## Review — 2026-05-04 — Round-5 — Verdict: NEEDS REVISION (Round-4 patch validation)

**Scope signal:** M (single fresh session, 6 surgical edits — 5 textual + 1 design decision on R5-B2 failure-recovery semantics; ~3–4 IMPORTANT pair-bound prose additions; ~2–3 hours focused single-session patch effort similar to round-4.)
**Specialists:** game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead, creative-director (senior synthesis). 6 specialists spawned in parallel adversarially; CD synthesized.
**Blocking items:** 6 BLOCKING (R5-B1–R5-B6) | **Recommended:** ~12 IMPORTANT | **Nice-to-have:** ~8
**Prior verdict resolved:** Partially — round-4 B6–B11 closed at the GDD rule level (predicate, prose, ACs mutually consistent and patch executed as described). However, round-4 patch closure perimeter was wrong: the patch focused on rule-level Pillar closure, while round-5 found **the new prose introduced/exposed defects at three seams** — Path B execution chain, B8 rollback prose, and GDD-internal/registry consistency. Round-4 quality bar was high; round-5 is the cleanup pass against it.
**Review depth:** full (per `/design-review` default; 6 specialists spawned in parallel adversarially, then creative-director senior synthesis)

### Summary

Round-4 closed B6–B11 cleanly at the rule level. Round-5 surfaced 6 new BLOCKING items, all of which are **prose-and-coordination defects rather than system-design defects**. Five of the six resolve with single-paragraph or single-line edits. R5-B2 (B8 concurrent-path rollback race) is the deepest — it requires a real rewrite of step 5's "retry path" language and a design decision on failure-recovery semantics. CD verdict: "Not the design is broken. The patch prose introduced ambiguity at three seams. Round-5 is the cleanup pass."

Most severely:

- **R5-B1 (Pillar 1 silent-emission)** [game-designer + audio-director convergent]: Path B does not invoke T4 (lantern force-lower) before player removal. C.5.3 step 6 cites only C.5.5 (sprint hard-reset); T5 transition row lists "force T4 if S3b active" but Path B prose does not invoke the full T5 side-effect set. A player in S3b disconnecting via Path B continues emitting Light pulses for up to 4 s on a `HumanoidRootPart` of a destroyed character. Phantom emissions + potential runtime error reading `HumanoidRootPart.Position` on a destroyed model.
- **R5-B2 (Pillar 2 silent cost-loss)** [ai-programmer + network-programmer + game-designer + audio-director — 4-specialist convergence]: B8 rollback's "OTHER death path firing" retry path is factually wrong in the concurrent-path race. Race: Path B sets flag, yields, Path A short-circuits at `_deathCostPaid = true`, Path B's pcall fails and rolls back to false. No retry path exists in the cooperative scheduler — both paths have already returned. Squad oxygen never decrements; `OnPlayerDied` never broadcasts. **The C.5.3 prose at line ~162 names a retry mechanism that does not exist.** Single most load-bearing BLOCKING in the round-5 set.
- **R5-B3 (testability contract violation)** [qa-lead]: C.5.3 predicate prose at lines ~135 and ~138 contains inline `workspace:GetServerTimeNow()` calls; C.11 line ~344 explicitly forbids these. C.11 line ~341 lists C.5.3 in its seam-required scope. Predicate prose contradicts C.11 — undoes round-4 B10 closure for the predicate path. H.22b/c/d/e/f become paper-only if implementation follows predicate prose verbatim.
- **R5-B4 (registry-vs-GDD divergence — same class as round-3 B5)** [systems-designer]: `entities.yaml` line ~734 `pulseEmissionMagnitude` formula expression encodes pre-B9 ordering — `record t_lastGracePulse[axis] = t_0` is INSIDE the grace-AND-grace-window branch, not at Step 0a (eligibility-anchored). Implementer reading registry alone reproduces the G1 exploit B9 was patched to close.
- **R5-B5 (B11 incomplete application)** [systems-designer]: `entities.yaml` `GRACE_REENTRY_COOLDOWN` (lines ~482–487) missing `>=` (inclusive) eligibility-comparator semantics annotation. B11 mirrored strict `<` semantics into entities.yaml for `HP_IMMINENT_THRESHOLD`, `HP_ARM_RECENT_WINDOW`, `DAMAGE_RECENT_WINDOW` (lines 464, 472, 480) but missed the analogous `>=` documentation for the cooldown. Same implementer-confusion class B11 was designed to close.
- **R5-B6 (trust-boundary spec-completeness — CD-reframed from network-programmer Theme-1-vs-Theme-2 dispute)** [network-programmer]: `RequestPing` C.9 / C.4.1 specify "ray origin matches server-tracked position within tolerance" but `PING_ORIGIN_TOLERANCE` does not exist anywhere in the GDD or `entities.yaml`. C.4.1 also specifies "camera angle" validation but the server tracks no camera state. CD ruling: spec completeness is Theme 1 (constant must exist as placeholder); value tuning is Theme 2.

### Patch Closure Audit (1:1 with round-4 6 BLOCKING items + IMPORTANT cluster)

| # | Patch item | Status | Residual defect |
|---|---|---|---|
| B6 | `_deathCostPaid` T6 clearance | **CLOSED at GDD level** | T7 silence (game-designer rated IMPORTANT, CD held IMPORTANT — S5-terminal-state invariant makes flag persistence non-load-bearing in MVP) |
| B7 | PlayerRemoving read-and-cache discipline | **CLOSED at rule level** | Skeleton "Now safe to yield" comment ambiguity at line ~127 (game-designer I.2 IMPORTANT) |
| B8 | RemoteFunction rollback path | **CLOSED for single-path; NEW BLOCKING for concurrent-path (R5-B2)** | "OTHER death path firing" retry-path prose at line ~162 factually wrong in concurrent-path race |
| B9 | D.4 anchor-on-eligibility | **CLOSED at GDD; NEW BLOCKING for registry divergence (R5-B4)** | entities.yaml line ~734 still encodes pre-B9 ordering |
| B10 | Clock-injection seam (C.11) | **CLOSED at C.11; NEW BLOCKING for predicate-prose contradiction (R5-B3)** | C.5.3 predicate at lines ~135, ~138 inline-calls `workspace:GetServerTimeNow()` violating C.11 forbid-list |
| B11 | Strict `<` boundary semantics | **CLOSED for 3 constants; NEW BLOCKING for missing 4th constant (R5-B5)** | entities.yaml `GRACE_REENTRY_COOLDOWN` missing `>=` annotation |

**Round-4 IMPORTANT cluster audit (audio-director):** F1-R4 (V/A.3 antecedent) and F3-R4 (V/A.4 caption note) confirmed CLOSED. **F4-R4 (lantern SFX per-pulse negative rule) and F6-R4 (Path B death SFX positional 3D character-removal) NOT applied** in round-4 patch — review log claimed they would be in IMPORTANT cluster but they are absent from the GDD. Carried as round-5 IMPORTANT (process-integrity flag for round-4 review log overstatement).

### Senior Verdict (creative-director)

> **Not MAJOR REVISION. The structure is intact. The pillars are intact.** Round-4 closed six legitimate Pillar-rule defects. Round-5 found six new BLOCKING items, all of which are *prose-and-coordination* defects rather than *system-design* defects. Five of the six BLOCKING items resolve with single-paragraph or single-line edits. R5-B2 (the B8 concurrent-path race) is the deepest — it requires a real rewrite of step 5's 'retry path' language and a design decision on failure-recovery semantics.
>
> This is not 'the design is broken.' This is 'the patch prose introduced ambiguity at three seams.' The patch quality bar of round-4 was high — it did real Pillar-rule work — but it landed under load and cross-contaminated three sections (C.5.3, C.5.5/T5, entities.yaml) without enforcing self-consistency across them. Round-5 is the cleanup pass.
>
> **Pillar 1 (Quiet Is Power) holds at the rule level except R5-B1 phantom-emission case.** **Pillar 2 (The Squad Is the Experience) holds across multi-life and jitter; R5-B2 introduces a concurrent-path silent-cost-loss class** the patch must close honestly (deferred-retry, accepted-loss, or path-aware rollback). **Pillar 4 (Rounds Not Saves) holds.**
>
> Do not advance to Theme 2 until round-5 patches land AND a round-6 fresh-session review verdicts APPROVED.

### Specialist Convergences

- **B8 rollback chain (4-specialist convergence)** — ai-programmer (concurrent-path total-evasion race) + network-programmer (race-1 confirmation) + game-designer (B8 retry under-specification I.4) + audio-director (I-A1 rollback silence on death SFX). All four flag the same downstream failure class.
- **Path B execution chain (3-specialist convergence)** — game-designer R5-B1 (lantern axis not reset; phantom Light emissions) + ai-programmer concurrent race + audio-director I-A1 (Path B death SFX nil anchor). All three identify gaps in the Path B execution chain that round-4 B7/B8 did not fully cover.
- **Registry-vs-GDD / GDD-internal divergence (3-defect convergence)** — systems-designer R5-B4 (registry pulseEmissionMagnitude missing B9 anchor) + systems-designer R5-B5 (GRACE_REENTRY_COOLDOWN comparator missing) + qa-lead R5-B3 (predicate prose inline-call violates C.11). All three are GDD-internal-or-registry inconsistency defects of the same class as round-3 B5.

### Specialist Disagreements (CD-resolved)

1. **PING_ORIGIN_TOLERANCE Theme classification (network-programmer NEW-B12 vs round-4 deferral)** — round-4 deferred to Theme 2; network-programmer disagreed (Theme 1 trust-boundary). **CD ruling: BLOCKING for spec-completeness (Theme 1); deferred for value-tuning (Theme 2).** Add `PING_ORIGIN_TOLERANCE` placeholder to G.4 + entities.yaml with `value: TBD (Theme 2 platform characterization)`. Resolve camera-angle clause by deletion or convert to forward-obligation. → **Adopted as R5-B6.**
2. **Audio carried IMPORTANTs (F4-R4 + F6-R4) — escalate to BLOCKING?** audio-director found round-4 IMPORTANT cluster claimed but did not deliver them. **CD ruling: hold as IMPORTANT, pair-bind to R5-B1 + R5-B2.** Process-integrity concern flagged in this entry. → **Bundled with R5-B1 / R5-B2 patches.**
3. **Scenario C player-experience prose (ai-programmer + game-designer convergent)** — should the GDD add explicit player-experience prose about what surviving squad members observe? **CD ruling: IMPORTANT, not BLOCKING — HUD GDD forward obligation, not PC rule defect.** → **HUD F.4 forward-obligation row addition.**
4. **B6 T7 residual silence (game-designer)** — game-designer rated IMPORTANT; CD considered escalating but **kept IMPORTANT** per S5-terminal-state invariant. → **Hold as IMPORTANT.**
5. **qa-lead BLOCKING-R5-02 (squad-oxygen cross-service observation)** — **CD downgraded to IMPORTANT** because call-spy patterns are standard TestEZ idiom; AC is salvageable with a contract addition (squad-oxygen observability contract in C.11). → **Hold as IMPORTANT.**

### Binding Fixes (must close before Theme 2 begins)

| ID | Fix | Section | Specialist source |
|---|---|---|---|
| **R5-B1** | Path B step 6 must invoke the full T5 transition side-effects (per C.6 T5 row including the lantern force-T4 if S3b active), not just C.5.5 (sprint hard-reset). Replace "clear sprint state per C.5.5" with "invoke the full T5 transition side-effects per C.6 T5 row, which includes the C.5.5 sprint hard-reset and the force-T4 lantern-lower side effect." | C.5.3 step 6 (line ~163); optionally extend C.5.5 (line ~180) prose to mention lantern parity | game-designer R5-B12 + audio-director I-A1 (downstream) |
| **R5-B2** | B8 rollback's "retry path" prose must be made factually correct in the concurrent-path race. Three resolution options: **(a)** deferred-Heartbeat reconciliation tick that scans for `_deathCostPaid = false` AND player-already-removed states; **(b)** acknowledge accepted-loss via operator log only (Pillar 2 weakly violated); **(c)** path-aware rollback that preserves flag if other path observed it. **CD recommends (a)** — single-frame-deferred reconciliation tick is cleanest and preserves Pillar 2 cost legitimacy. **User design decision required before patch lands.** Add new AC for the concurrent-path failure case. | C.5.3 step 5 prose (lines ~162–166); H.7 (new AC for concurrent-path) | ai-programmer + network-programmer + game-designer + audio-director (4-specialist convergence) |
| **R5-B3** | C.5.3 predicate body must replace both inline `workspace:GetServerTimeNow()` calls (lines ~135, ~138) with `getServerTime()` (the C.11 seam). Preferred form: capture `local cachedNow = getServerTime()` as an additional cache line in the read-and-cache snippet, then use `cachedNow` in both predicate arms. | C.5.3 lines ~132–138 + skeleton lines ~115–125 | qa-lead BLOCKING-R5-01 |
| **R5-B4** | `entities.yaml` `pulseEmissionMagnitude` formula expression (line ~734) must encode B9 Step 0a — `record t_lastGracePulse[axis] = t_0` as a separate pre-branch statement whenever `grace_eligible == true`, NOT inside the grace-window-pass branch. Update notes field to reference D.4 Step 0a. | `entities.yaml` lines ~732–739 | systems-designer R5-B12 |
| **R5-B5** | `entities.yaml` `GRACE_REENTRY_COOLDOWN` notes (line ~487) must add boundary-semantics annotation: "Boundary semantics: eligibility check uses `>=` (NOT `>`): elapsed time exactly equal to 6.0 s IS eligible (grants new grace exemption). Consistent with E.F ping-cooldown precedent." Optionally add one-line annotation to GDD D.4 Step 0 + C.8.1 prose. | `entities.yaml` line ~487; optionally GDD D.4 / C.8.1 | systems-designer R5-B13 |
| **R5-B6** | Add `PING_ORIGIN_TOLERANCE` placeholder constant to G.4 (Coordination Knobs) + register in `entities.yaml` with `value: TBD (Theme 2 platform characterization)`. Resolve camera-angle validation clause: either (a) delete from C.9 / C.4.1 and replace with "ray direction geometric consistency" (verifiable from submitted payload), OR (b) convert to forward-obligation requiring camera angle on `RequestPing` payload with explicit trust-boundary acknowledgment that camera angle is client-supplied advisory. **CD recommends (a)** — server has no camera-angle data; geometric consistency is the meaningful guard. | C.9 + C.4.1; G.4; `entities.yaml` | network-programmer NEW-B12 (CD-reframed) |

### Recommended (NOT BLOCKING — close with R5-B1–B6 patch or in next theme)

- **Audio cluster (close with R5-B1 + R5-B2 patch)**: V/A.3 Death SFX Path B nil-anchor qualifier + B8 rollback silence acknowledgment (audio-director I-A1, **carried-unfulfilled from round-4 F6-R4**); V/A.3 lantern raise/lower SFX rows need explicit "T3/T4 transitions only — NOT per-LightEmission-pulse" negative rule (audio-director I-A2, **carried-unfulfilled from round-4 F4-R4**); V/A.6 sprint/walk volume-lock Clause 2 (player-information) justification (I-A3); V/A.4 caption sprint pulse-transaction parity gap (I-A4 — v2 candidate).
- **HUD forward obligations (close in F.4 with R5-B2 patch)**: Scenario C player-experience prose (HUD owes squad-experience prose for the silent-loss class — surviving squad observes a teammate vanish with no oxygen tick, no `OnPlayerDied`); B8 rollback death-signal gap (HUD owes definition for delayed/absent death notification under RM failure).
- **Game-design IMPORTANT**: B6 T7 residual silence one-line note (game-designer I.1 — kept IMPORTANT per CD); B7 skeleton "Now safe to yield" comment disambiguation (I.2); B8 retry-after-rollback under-specification, including Path-B-specific permanent-loss class acknowledgment (I.4 — paired with R5-B2 design decision); `_deathCostPaid` PlayerAdded init lifecycle clarification (ai-programmer I.1 — mirror PredatorService F.4 init contract); `HP_IMMINENT_THRESHOLD = 25` first-pass-design-intent annotation (ai-programmer I.3 — asymmetric with `HP_ARM_RECENT_WINDOW` round-4 treatment).
- **Cross-system / Predator AI**: F.4 missing Predator AI target-tracking flush forward-obligation row (ai-programmer I.4 — Theme 3 deliverable but currently undocumented); C.11 cross-service clock-seam coherence (game-designer I.3 + network-programmer — integration tests must wire both PC and PredatorService seams to the same mock).
- **QA AC cluster**: H.22f THEN clause (1) white-box mid-execution rewrite (qa-lead I5-01); H.22b/c/d/e/f squad-oxygen call-spy contract addition to C.11 (qa-lead BLOCKING-R5-02 → IMPORTANT after CD review); H.10 subjective THEN clause rewrite (qa-lead F4 — carried-unclosed from round-4); H.33c `_lastHeartbeatTime` not-updated white-box rewrite (qa-lead F8); H.11h white-box `t_lastGracePulse[Sprint]` THEN clause removal (qa-lead I5-05 — surrogate is sufficient); C.11 clock-advancement pattern documentation (qa-lead I5-06); H.22e negation test (qa-lead I5-10); coverage gap ACs — H.22g (read-and-cache under adversarial teardown), H.22h (T6 `lastPredatorDamageTimestamp` clearance), HP=25.0 exact-boundary (qa-lead I5-07/08/09).
- **Network**: H.29 bandwidth claim re-derivation for steady-state-vs-burst (network-programmer I2 — **carried-unclosed from round-1**); `PlayerHeartbeat` flood DoS exceeds H.28 budget concern (network-programmer I3); B8 rollback no operator/RM retry contract specified (network-programmer I4 — paired with R5-B2 design decision).

### Forward-Obligation List (NOT blocking Theme 1 — defer to Themes 2/3/4 / HUD GDD)

- **HUD GDD forward obligations** (carried from round-4 + new round-5): Path B legibility for returning player (game-designer F4 round-4); emote-wheel HP/stamina coordination semantics (game-designer F5 round-4); **NEW round-5**: Scenario C silent-loss player-experience prose; B8 rollback death-signal gap definition; squad-experience under transient RM failure.
- **Theme 2 (Roblox API verification)** (carried + new): yield-point enumeration completeness; `PlayerHeartbeat` rate-limit-vs-write ordering; `OnPlayerDied` squad scoping mechanism; `RequestEmote` int-typed slot validation; `math.max(0, dt)` guard in D.1/D.2; D.3 divide-by-zero precondition; **NEW round-5**: `PING_ORIGIN_TOLERANCE` value tuning (placeholder constant added in R5-B6 patch; value belongs to Theme 2); `PlayerHeartbeat` flood DoS budget verification; H.29 bandwidth re-derivation; `--!strict` Luau cast in C.5.3 skeleton (ai-programmer NTH-3); Roblox `Players.PlayerRemoving` single-thread sequential contract citation (network-programmer NTH-3).
- **Theme 3 (downstream contract)** (carried + new): Danger emote vs Danger ping redundancy; LANTERN_VISIBILITY_RADIUS contradiction 12 vs 20 studs; V/A.6 sprint/walk volume lock vs OQ.1 closure; Sprint button greying vs body-as-liability framing; D.4 output range claim post-Crafting modifier stack; arm 1 prose precision; audio F2/F5; **NEW round-5**: Predator AI target-tracking flush F.4 row; OQ.1 latent seam in "plus any contracts the Predator AI GDD's Perception submodule defines" clause; quick-ping audio category-differentiation v2 candidate; spectral-loudness timbre cosmetic-boundary edge case.
- **Theme 4 (cross-cut testability)** (carried): H.22e concurrent-path race (now subsumed by R5-B2 — promoted to Theme 1); H.27/H.32 hardware fallback documentation; H.31 level-design prerequisite note; F.4 nil-table-vs-nil-entry distinction.
- **OQ.3** (Camera GDD decision) — pending before `/create-architecture`.

### Recommended Round-5 Patch Sequence

Single fresh session per `.claude/docs/context-management.md` "one theme per session" guidance. Order by Pillar criticality and dependency:

1. **R5-B2 first (Pillar 2 silent-loss).** Resolve the concurrent-path race in B8 rollback. **Bring the design decision to the user** before any prose edit — option (a) deferred-Heartbeat reconciliation tick (CD-recommended), (b) accepted-loss with operator log, or (c) path-aware rollback. Rewrite step 5 prose accordingly. Add new AC for concurrent-path failure case. Pair-bind audio I-A1 (Path B death SFX nil anchor + rollback silence) and game-designer I.4 (retry under-specification).
2. **R5-B1 (Pillar 1 silent-emission).** Path B step 6 invokes full T5 side-effects, not just C.5.5. Trivial textual fix.
3. **R5-B3 (testability contract violation).** Replace inline `workspace:GetServerTimeNow()` in C.5.3 predicate with `getServerTime()` seam reference. Trivial.
4. **R5-B4 + R5-B5 (registry divergence).** Update entities.yaml `pulseEmissionMagnitude` expression for B9; add `>=` annotation to `GRACE_REENTRY_COOLDOWN` notes. Trivial.
5. **R5-B6 (PING_ORIGIN_TOLERANCE spec gap).** Add constant placeholder; resolve camera-angle clause via CD-recommended option (a) deletion + geometric-consistency replacement.
6. **Bundled IMPORTANTs**: audio I-A1 (paired with R5-B1+B2); audio I-A2 (lantern SFX trigger negative rule, **carried-unfulfilled from round-4**); HUD F.4 forward-obligation rows (Scenario C + B8 rollback gap); `_deathCostPaid` PlayerAdded init clarification; B7 skeleton comment disambiguation; HP_IMMINENT_THRESHOLD first-pass-intent annotation; F.4 Predator AI target-flush row.
7. **Run round-6 design-review in fresh session after patch lands.**

After this round-5 patch closes, run `/design-review design/gdd/player-controller.md` in another fresh session to validate before advancing to Theme 2.

### Files Referenced (round-5 review)

- Target: `design/gdd/player-controller.md` (1033 lines, status: NEEDS REVISION; round-4 patch applied 2026-05-02; round-5 review complete 2026-05-04)
- Registry: `design/registry/entities.yaml` (R5-B4 + R5-B5 verified — line 487 missing `>=` annotation; line 734 still encoding pre-B9 ordering)
- Upstream: `design/gdd/ecological-disturbance.md` (round-7 pending), `design/gdd/crafting-and-items.md` (round-2 pending)
- Cross-cited: `design/gdd/game-concept.md`, `design/gdd/systems-index.md`, `docs/engine-reference/roblox/VERSION.md`, `design/CLAUDE.md`, `.claude/rules/design-docs.md`
- Standards: `.claude/docs/coding-standards.md`, `.claude/docs/technical-preferences.md`, `.claude/docs/context-management.md`

### Files Modified This Session

- `design/gdd/reviews/player-controller-review-log.md` — this entry appended.
- `design/gdd/systems-index.md` — PC row updated with round-5 verdict; status-summary line updated.
- `production/session-state/active.md` — replaced with round-5-patch-pending state.

---

## Round-5 Patch — 2026-05-04/05 — Status: PARTIALLY APPLIED

**Source:** Round-5 design-review entry above. **Patch was incomplete** — only the two design-decision-required items (R5-B1, R5-B2) were applied to the GDD body; the four trivial textual fixes (R5-B3, R5-B4, R5-B5, R5-B6) were skipped. This partial-patch state is what round-6 reviewed against.

**Edits applied:**

| ID | Edit | Section | Verification |
|---|---|---|---|
| **R5-B1** | C.5.3 step 6 (lines 188-197) now invokes the full T5 transition side-effects per the C.6 T5 row, including (a) sprint hard-reset, (b) lantern force-T4 if S3b active (line 191 carries `(R5-B1 round-5 closure: ...)` annotation closing the phantom-emission class for Path B players), (c) freeze stamina at current value, (d) reset `t_lastGracePulse_*` (Path A only — Path B has no next life), (e) activate spectator camera (Path A only), (f) lock client-side input (Path A only). | C.5.3 step 6, lines 188-197 | Pillar 1 phantom-emission closure for the success path |
| **R5-B2** | **User-confirmed option (a) — deferred-Heartbeat reconciliation tick (CD-recommended)** applied 2026-05-04. Full reconciliation-tick design at C.5.3 lines 162-187: introduces `RECONCILIATION_TICK_INTERVAL = 5.0 s` constant, `deathDeductionCommitted[player]` per-player flag, eligibility predicate `(player ∈ S4 OR player no longer in Players service) AND _deathCostPaid[player] == false AND deathDeductionCommitted[player] ~= true`, worst-case 10 s retry latency bound, persistence boundary (in-memory per session, does NOT cross BindToClose), HUD forward-obligation flagged for delayed-notification class. New death cause string `"reconciliation-recovery"` introduced. Path B players keyed by `userId` snapshotted at PlayerRemoving time. | C.5.3 lines 162-187 | Pillar 2 silent-cost-loss closure for the concurrent-path race (success path); introduces new design surface |

**Edits NOT applied (carried-unapplied to round-6):**

- R5-B3 (predicate inline `workspace:GetServerTimeNow()` violates C.11) — predicate body at C.5.3 lines 135, 138 unchanged.
- R5-B4 (entities.yaml `pulseEmissionMagnitude` pre-B9 ordering) — registry expression at line 734 unchanged.
- R5-B5 (entities.yaml `GRACE_REENTRY_COOLDOWN` missing `>=` annotation) — notes field at line 488 unchanged.
- R5-B6 (`PING_ORIGIN_TOLERANCE` placeholder + camera-angle clause resolution) — C.4.1 line 86 + C.9 line 324 unchanged; constant absent from G.4 + entities.yaml.

**Patch effort:** ~1 hour partial single-session. File grew 1033 → 1067 lines (R5-B1 ~5 lines + R5-B2 ~25 lines + minor prose).

**Files Modified This Session:**

- `design/gdd/player-controller.md` — R5-B1 + R5-B2 closures applied; Header status block NOT updated (still says NEEDS REVISION round-1 verdict).
- `design/registry/entities.yaml` — NOT modified.
- `design/gdd/reviews/player-controller-review-log.md` — this entry appended (retroactively documented in round-6 session).

**Process integrity flag:** Round-5 patch session ended without applying the four trivial textual fixes (R5-B3/B4/B5/B6). These were explicitly listed as "Trivial — single ... addition" / "Trivial textual fix" in the round-5 review log binding-fixes table. The deepest design surface (R5-B2) was patched in the same session but the trivial fixes were not. **Pattern observation: heavy design surface co-resident with trivial fixes ate the trivial fixes.** Round-7 must split: trivial sweep FIRST in a fresh session, reconciliation-tick lifecycle SECOND in a separate fresh session.

---

## Review — 2026-05-05 — Round-6 — Verdict: MAJOR REVISION NEEDED (Round-5 partial-patch validation + reconciliation-tick stress-test)

**Scope signal:** L (split across two fresh sessions — see Round-7 patch sequencing recommendation). Producer should verify before sprint planning. Effort: ~30-45 min trivial sweep + ~2-3 hours reconciliation-tick lifecycle patch + AC bundle.
**Specialists:** game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead, creative-director (senior synthesis). 6 specialists spawned in parallel adversarially; CD synthesized.
**Blocking items:** 12 BLOCKING (R6-B1–R6-B12) | **Recommended:** 12 IMPORTANT (R6-I1–R6-I12) | **Nice-to-have:** ~6
**Prior verdict resolved:** Partially — round-5 R5-B1 + R5-B2 closed at the GDD rule level (success path). However, **(a) round-5 R5-B3/B4/B5/B6 were NEVER APPLIED in the round-5 patch session and remain open as carried BLOCKING items**, and **(b) the new R5-B2 reconciliation-tick design surface introduced 8 new BLOCKING defects of the same defect classes prior rounds had supposedly closed (multi-life flag-clearance same-class-as-B6, registry divergence same-class-as-R5-B4, AC coverage gap, audio-as-feedback contract violation, dual-table keying contradiction with F.4)**.
**Review depth:** full (per `/design-review` default; 6 specialists spawned in parallel adversarially, then creative-director senior synthesis)

### Summary

Round-5 review surfaced 6 BLOCKING items. The round-5 patch session closed only the 2 design-decision-required items (R5-B1, R5-B2) and skipped the 4 trivial textual fixes (R5-B3/B4/B5/B6). Round-6 confirmed the 4 unapplied items remain open AND found 8 new BLOCKING defects introduced by R5-B2's reconciliation-tick design — the deepest new design surface in the document's history was patched without (a) corresponding AC coverage, (b) cross-section invariant propagation (the new flag `deathDeductionCommitted` was not added to T6 clearance, mirroring round-4 B6 defect class), or (c) audio-as-feedback contract update for the new `reconciliation-recovery` broadcast cause.

CD verdict: "**Patch perimeter has regressed.** Pillar 1 holds at the rule level for the success path; reopens through the failure-then-reconciliation path (R6-B8 — phantom Light pulses for up to 10s on destroyed `HumanoidRootPart`). **Pillar 2 does NOT hold honestly** — three new silent-loss sub-classes (T6-clearance defect, 10-second `OnPlayerDied` gap, dual-table userId/Player keying contradiction). Pillar 4 reopens through the multi-life flag-clearance defect."

### Round-6 BLOCKING Items (R6-B1 — R6-B12)

| ID | Defect | Pillar at risk | Specialist origin | Severity rationale |
|---|---|---|---|---|
| **R6-B1** | C.5.3 predicate body at lines 135, 138 still inline-calls `workspace:GetServerTimeNow()` in violation of C.11 line 378's own forbid-list. C.11 line 375 explicitly lists C.5.3 in seam-required scope. | **Pillar 4 / testability** | game-designer F8 + systems-designer R6-B1 + network-programmer F1 + ai-programmer F3 + qa-lead F1 (**5-specialist convergence**) | R5-B3 carried-unapplied. H.22b/c/d/e/f remain paper-only ACs. |
| **R6-B2** | `entities.yaml` line 734 `pulseEmissionMagnitude` formula expression encodes pre-B9 ordering — `record t_lastGracePulse[axis] = t_0` is INSIDE the grace-AND-grace-window branch. Concrete failing input: `t - t_0 = 1.001 s` (Heartbeat delayed 1ms past 1s window) → no anchor recorded → next state-entry observes `grace_eligible = true` → G1 reopens under thermally-throttled mobile. | **Pillar 1** consistency | systems-designer R6-B2 | R5-B4 carried-unapplied. Same registry divergence class as round-3 B5. |
| **R6-B3** | `entities.yaml` `GRACE_REENTRY_COOLDOWN` notes (line 488) missing `>=` (inclusive) eligibility-comparator annotation. B11 mirrored strict `<` to three constants but missed analogous `>=` for the cooldown. Implementer defaults to strict `>` and silently denies legitimate first pulses at exact 6.0s boundary. | **Pillar 1** consistency | systems-designer R6-B3 | R5-B5 carried-unapplied. Trivial — single `notes:` field addition. |
| **R6-B4** | `PING_ORIGIN_TOLERANCE` absent from G.4 + entities.yaml; C.4.1 line 86 + C.9 line 324 reference camera-angle data the server does not track. | **Pillar 4 / trust boundary** | game-designer F6 + systems-designer R6-B4 + network-programmer F2 + qa-lead F10 (**4-specialist convergence**) | R5-B6 carried-unapplied. CD round-5 mandated option (a) — delete camera-angle clause + add `PING_ORIGIN_TOLERANCE` placeholder. |
| **R6-B5** | `deathDeductionCommitted[player]` is NOT cleared on T6. C.6 T6 transition row at line 248 only clears `_deathCostPaid`. **Multi-life Pillar 2 silent break — same defect class as round-4 B6 reproduced for the new flag introduced by R5-B2's patch itself.** Failing sequence: Player A dies Life 1, reconciliation commits → `deathDeductionCommitted[A] = true`. T6 fires (clears only `_deathCostPaid`). Player A dies Life 2, RemoteFunction fails, rollback. Reconciliation predicate `_deathCostPaid == false AND deathDeductionCommitted ~= true` evaluates **FALSE** because flag persists from Life 1. Squad oxygen for Life 2 permanently lost. | **Pillar 2 + Pillar 4** | systems-designer R6-B5 + ai-programmer F1 + qa-lead F3g (**3-specialist convergence**) | The single most load-bearing defect in the round-6 set — round-5 patch reproduced its own B6 defect class. |
| **R6-B6** | `RECONCILIATION_TICK_INTERVAL = 5.0 s` not registered in entities.yaml. Same registry-divergence class as R5-B4. Constant governs the 10s Pillar 2 SLA bound and HUD player-experience expectation. | **Pillar 1** consistency | systems-designer R6-B5 | New BLOCKING from R5-B2 patch surface. |
| **R6-B7** | Reconciliation tick has NO entry in C.11 seam scope table (lines 366-377). Tick interval gate read of server-time bypasses the seam. | **Pillar 4 / testability** | qa-lead F2 | Without this, every reconciliation tick AC (R6-B11 cluster) is unwritable. |
| **R6-B8** | Reconciliation tick success path at C.5.3 line 175 sets `deathDeductionCommitted = true` and broadcasts `OnPlayerDied(deathCause="reconciliation-recovery")` but does NOT invoke T5 side-effects (a) and (b) (sprint pulse-timer stop, lantern force-T4). For Path B players whose initial `pcall` failed BEFORE step 6 was reached, pulse timers were never stopped. Phantom Sprint/Light pulses run for up to 10 seconds on a destroyed `HumanoidRootPart`. **R5-B1 closure regressed for the failure-then-reconciliation path.** | **Pillar 1** silent break | game-designer F4 + ai-programmer F5 (CD-unified) | New BLOCKING — round-5 patch closed Pillar 1 for the success path but reopened it for the rollback-then-reconciliation path. |
| **R6-B9** | `userId`-keyed reconciliation rows (line 177) contradict F.4-mandated `Player`-instance keying for `lastPredatorDamageTimestamp` (line 685). Re-keying step at PlayerRemoving time unspecified. Rejoin-during-reconciliation race undefined. | **Pillar 2** | game-designer F5 + network-programmer F3 + ai-programmer F4 (**3-specialist convergence**) | Dual-table keying contract missing. |
| **R6-B10** | Step 5 rollback prose calls `warn("[PlayerController] RequestSquadOxygenSpend failed for " .. player.Name .. ": ...")`. For Path B reconciliation retry attempts, the `Player` instance is destroyed by tick time — `player.Name` access raises a nil-parent runtime error, **crashing the reconciliation handler for every subsequent retry attempt for the entire server session**. | **Pillar 2** runtime crash | game-designer F2 | Snapshot `playerName` alongside `userId` at PlayerRemoving time. |
| **R6-B11** | Reconciliation tick has ZERO acceptance-criteria coverage in Section H. 8 missing ACs: F3a Path A rollback-then-tick recovery, F3b Path B rollback-then-tick recovery (userId-keyed), F3c double-deduction guard, F3d 10s worst-case bound, F3e success-path exit, F3f first-tick timing gate, F3g `deathDeductionCommitted` T6 clearance (binary signal for R6-B5), F3h BindToClose in-flight row loss documented invariant. | **Pillar 4 / testability** | qa-lead F3a-h | The largest new design surface in the document's history shipped without test evidence. |
| **R6-B12** | V/A.3 Death SFX fires on the delayed `OnPlayerDied(deathCause="reconciliation-recovery")` broadcast. Squad hears a death SFX 10 seconds after the player vanished, implying a fresh death event. **Horror-game audio-as-feedback contract cannot tolerate false death cues — trains players to misread predator activity.** | **Pillar 3 / audio mental model** | audio-director F3 (CD-confirmed BLOCKING despite single-specialist) | Spec must mandate Death SFX MUST NOT fire on `deathCause="reconciliation-recovery"`; HUD-only delayed notification. |

### Round-6 IMPORTANT Items (R6-I1 — R6-I12 cluster)

| ID | Defect | Specialist | Notes |
|---|---|---|---|
| **R6-I1** | D.2 stamina regen boundary comparator (`>` vs `>=` at exact `STAMINA_REGEN_DELAY` boundary) undocumented. Same B11 class. | systems-designer R6-B6 | Add boundary annotation to D.2 + entities.yaml. |
| **R6-I2** | F.4 PredatorService deferral contract should be upgraded from OPTIONAL to BINDING. The cache-first ordering closes mid-yield races but does NOT close the PredatorService-clears-first-then-PC-runs race. | ai-programmer F2 | CD-resolved IMPORTANT not BLOCKING; current prose misdescribes which race the mitigation addresses. Mandatory close in round-7. |
| **R6-I3** | F.4 missing HUD row for `deathCause="reconciliation-recovery"` delayed-notification class. Surviving squad observes teammate vanish for up to 10 seconds with no UI signal. | game-designer F3 | Add HUD forward-obligation row. |
| **R6-I4** | `deathCause` string set not enumerated in C.9 OnPlayerDied row. | network-programmer F4 | Two strings now exist; protocol underspecified. |
| **R6-I5** | Multi-player reconciliation yield is unbounded. H.28's 0.1ms claim false for eligible rows: 4 simultaneous reconciliation attempts × 50-150ms RemoteFunction roundtrip = 200-600ms blocking on Heartbeat callback. | network-programmer F5 | Fix: `task.spawn` each retry off the Heartbeat handler OR add per-tick attempt cap. |
| **R6-I6** | E.D heartbeat lines 598, 602 still inline `workspace:GetServerTimeNow()` — same C.11 violation as R6-B1 at a different call site. | network-programmer F6 | Missed by round-4 patch. Replace with `getServerTime()`. |
| **R6-I7** | V/A.3 lantern lower SFX fires from destroyed character on Path B force-T4. | audio-director F1 | Add Path B suppression qualifier. |
| **R6-I8** | Death SFX positional 3D nil-anchor on Path B. Snapshot `lastKnownPosition` server-side before destruction; play via `AudioService` world-anchor. | audio-director F2 | **Carried-unfulfilled 2 rounds (F6-R4).** CD: escalation rule — process-integrity flag. |
| **R6-I9** | V/A.3 lantern raise/lower SFX missing "T3/T4 transitions only — NOT per-`LightEmission`-pulse" negative rule. | audio-director F5 | **Carried-unfulfilled 2 rounds (F4-R4).** Same process-integrity flag. |
| **R6-I10** | V/A.4 captions: `"[Name] is down"` text fires 10s late on reconciliation-recovery — out-of-context reads as fresh death. | audio-director F4 | Suppress caption on `deathCause="reconciliation-recovery"`. |
| **R6-I11** | Reconciliation tick T5 re-invocation for removed players: explicitly suppress side-effects (c)-(f) (Path-A-only). Document `_deathCostPaid` `Players.PlayerAdded` initialization (must be `false`, not nil). | ai-programmer F5, F6 | Init contract mirrors F.4 PredatorService init mandate. |
| **R6-I12** | AC cleanup cluster: H.22f white-box clause rewrite (qa-lead I5-01), H.10 subjective rewrite (F4 carried), H.33c state-inspection seam (I5-05), H.22e/f C.11 annotation, paired negation tests, exact-boundary ACs (HP=25.0 / 30s / 3s — qa-lead I5-07/08/09), Lemur fidelity caveat (F11), state-inspection seam mandate in C.11 (F12). | qa-lead F4-F9, F11, F12 | Bundle for round-7 session 2. |

### Senior Verdict (creative-director)

> **MAJOR REVISION NEEDED.** Round-5 patch closed 2 of 6 items but introduced 8+ new BLOCKING defects of the same classes prior rounds had supposedly closed. **Patch perimeter has regressed.**
>
> **Pillar 1 (Quiet Is Power):** Holds at the rule level for the success path; reopens through the failure-then-reconciliation path (R6-B8 — phantom Light pulses for up to 10s on destroyed `HumanoidRootPart`). Single-fix closeable.
>
> **Pillar 2 (The Squad Is the Experience): Does NOT hold honestly.** Three new silent-loss sub-classes: T6-clearance defect for `deathDeductionCommitted` (3-specialist convergence — same defect class as round-4 B6 reproduced for the new flag), 10-second `OnPlayerDied` gap with no surviving-squad UX, dual-table userId/Player keying contract undocumented (3-specialist convergence).
>
> **Pillar 4 (Rounds Not Saves):** Reopens through the multi-life flag-clearance defect.
>
> **Meta-pattern observation:** round-5's heavy R5-B2 design surface (the reconciliation tick) was patched in the same session as the trivial R5-B1 fix, leaving R5-B3/B4/B5/B6 (textual) entirely unapplied. The deepest design surface should have landed AFTER the trivial sweeps closed, not concurrent with them. **Round-7 must split: (1) a quick-fix sweep for R6-B1/B2/B3/B4/I7-I9 (~30-45 min) before (2) the heavy reconciliation-tick lifecycle/contract patch (R6-B5 through B12, ~2-3 hours). Two fresh sessions, sequential. Do not attempt them in one session.**
>
> Do not advance to Theme 2 until round-7 patches land AND a round-8 fresh-session review verdicts APPROVED.

### Specialist Convergences (binding evidence)

- **R5-B3 unapplied (5-specialist convergence)**: game-designer F8 + systems-designer R6-B1 + network-programmer F1 + ai-programmer F3 + qa-lead F1. Predicate inline-calls `workspace:GetServerTimeNow()` at lines 135, 138.
- **R5-B6 unapplied (4-specialist convergence)**: game-designer F6 + systems-designer R6-B4 + network-programmer F2 + qa-lead F10. `PING_ORIGIN_TOLERANCE` absent + camera-angle clause unenforceable.
- **`deathDeductionCommitted` not cleared on T6 (3-specialist convergence)**: systems-designer R6-B5 + ai-programmer F1 + qa-lead F3g. Same defect class as round-4 B6 reproduced for the new flag.
- **`userId` vs `Player`-instance keying mismatch (3-specialist convergence)**: game-designer F5 + network-programmer F3 + ai-programmer F4.
- **Reconciliation tick zero AC coverage (2-specialist convergence)**: qa-lead F3a-h (8 missing ACs) + game-designer F9.

### Specialist Disagreements (CD-resolved)

1. **F.4 PredatorService deferral binding contract** → CD: IMPORTANT (R6-I2), but the prose currently misdescribes which race the mitigation addresses; rewrite is mandatory in round-7.
2. **Reconciliation success-path side-effects (a)(b)** → CD: unified into R6-B8 — reconciliation must invoke (a)(b) and explicitly suppress (c)-(f).
3. **Audio carried-unfulfilled IMPORTANTs (F4-R4, F6-R4)** → CD: process-integrity escalation rule — treated as R6-I8/R6-I9 with mandatory close in round-7. Carried-unfulfilled three rounds → escalate to BLOCKING.
4. **Lemur `Players.PlayerRemoving` fidelity** → CD: IMPORTANT (R6-I12 cluster) — add caveat paragraph to C.11; do not block on it.
5. **Audio Death SFX on reconciliation-recovery** → CD: BLOCKING (R6-B12) — domain authority on horror audio-as-feedback contract is sufficient; false predator cues are Pillar-3-adjacent.

### Recommended Round-7 Patch Sequencing (TWO SEQUENTIAL FRESH SESSIONS)

Per CD's meta-pattern observation and `.claude/docs/context-management.md` "one theme per session" guidance:

**Session 1 — Trivial-fix sweep (scope S, ~30-45 min)**: R6-B1 + R6-B2 + R6-B3 + R6-B4 + R6-I6 + R6-I7 + R6-I8 + R6-I9. Pure textual / registry-update work; closes 8+ items with zero design-decision risk. Header status block update at end. **Run round-6.5 mini-validation (lean review, --depth lean)** after to confirm closure before opening Session 2.

**Session 2 — Reconciliation-tick lifecycle and contract patch (scope M, ~2-3 hours)**: R6-B5 + R6-B6 + R6-B7 + R6-B8 + R6-B9 + R6-B10 + R6-B11 + R6-B12 + R6-I1-I5 + R6-I10 + R6-I11 + R6-I12 cluster. Multi-section coordinated edits across C.5.3 (reconciliation tick lifecycle), C.6 (T6 row), C.11 (seam table + Lemur caveat), F.4 (HUD row + PredatorService deferral upgrade), V/A.3 (audio rules), V/A.4 (captions), Section H (8 new ACs + cleanup cluster), entities.yaml (`RECONCILIATION_TICK_INTERVAL`).

**After both sessions land, run `/design-review design/gdd/player-controller.md` round-8 in another fresh session.** If APPROVED at round-8, advance to Theme 2 (Roblox API verification). If NEEDS REVISION at round-8, the converging defect-rate pattern requires reconsideration of the reconciliation-tick architecture itself.

### Forward-Obligation List (NOT blocking Theme 1 — defer to Themes 2/3/4 / HUD GDD)

- **HUD GDD forward obligations** (carried + new round-6): Path B legibility for returning player (game-designer F4 round-4); emote-wheel HP/stamina coordination (F5 round-4); Scenario C silent-loss player-experience prose (round-5); B8 rollback death-signal gap (round-5); **NEW round-6**: `deathCause="reconciliation-recovery"` delayed-notification UX (10s gap player-experience); `OnPlayerStatusUnknown` placeholder UI state during gap.
- **Theme 2 (Roblox API verification)** (carried + new): yield-point completeness; PlayerHeartbeat rate-limit-vs-write ordering; OnPlayerDied squad scoping; RequestEmote int-typed slot; D.1/D.2 dt guards; D.3 divide-by-zero precondition; PING_ORIGIN_TOLERANCE value tuning; PlayerHeartbeat flood DoS budget; H.29 bandwidth re-derivation; `--!strict` Luau cast in C.5.3 skeleton; `Players.PlayerRemoving` single-thread sequential contract citation; **NEW round-6**: Roblox `Sound`-on-destroyed-instance playback semantics (audio I-A1 anchor question); Lemur `PlayerRemoving` fidelity verification (qa-lead F11).
- **Theme 3 (downstream contract)** (carried + new): Danger emote vs ping redundancy; LANTERN_VISIBILITY_RADIUS contradiction; V/A.6 sprint/walk volume lock vs OQ.1 closure; Sprint button greying; D.4 output range post-Crafting modifier; arm 1 prose precision; audio F2/F5; Predator AI target-tracking flush F.4 row; OQ.1 latent seam; quick-ping audio category-differentiation v2; spectral-loudness timbre cosmetic-boundary edge case; **NEW round-6**: V/A.6 cosmetic-boundary edge case for `reconciliation-recovery` cause string (audio-director F7).
- **Theme 4 (cross-cut testability)** (carried): H.22e concurrent-path race (subsumed by R5-B2); H.27/H.32 hardware fallback; H.31 level-design prereq; F.4 nil-table-vs-nil-entry distinction.
- **OQ.3** (Camera GDD decision) — pending before `/create-architecture`.
- **NEW OQ candidate**: `Players.PlayerRemoving` instance-validity contract verification (network-programmer F9). Currently asserted as fact at F.4 line 685 without citation.

### Files Referenced (round-6 review)

- Target: `design/gdd/player-controller.md` (1067 lines, status: NEEDS REVISION header but body has R5-B1 + R5-B2 closures applied; R5-B3/B4/B5/B6 carried open)
- Registry: `design/registry/entities.yaml` (lines 458-496 PC constants; line 488 `GRACE_REENTRY_COOLDOWN` missing `>=` annotation; line 734 `pulseEmissionMagnitude` still pre-B9 ordering; `PING_ORIGIN_TOLERANCE` and `RECONCILIATION_TICK_INTERVAL` absent)
- Upstream: `design/gdd/ecological-disturbance.md` (round-7 pending), `design/gdd/crafting-and-items.md` (round-2 pending)
- Cross-cited: `design/gdd/game-concept.md`, `design/gdd/systems-index.md`, `docs/engine-reference/roblox/VERSION.md`, `design/CLAUDE.md`, `.claude/rules/design-docs.md`
- Standards: `.claude/docs/coding-standards.md`, `.claude/docs/technical-preferences.md`, `.claude/docs/context-management.md`

### Files Modified This Session

- `design/gdd/reviews/player-controller-review-log.md` — Round-5 partial-patch entry (retroactively documented) + this round-6 entry appended.
- `design/gdd/systems-index.md` — PC row updated with round-6 verdict; status-summary line updated.
- `production/session-state/active.md` — replaced with round-7-split-patch-pending state.

---

## Round-7 Session 1 Patch — 2026-06-07 — Status: APPLIED (trivial-fix sweep)

**Context:** A `/design-review` was invoked on `player-controller.md`, but the GDD was found to be **byte-unchanged since the round-6 MAJOR REVISION verdict** — `player-controller.md` has exactly one commit in its history (`8fcbd3c`, the "accumulated design backlog" commit; first-committed as-is with round-6 body content). All 12 round-6 BLOCKING items provably carried forward (spot-checked: R6-B1 inline `workspace:GetServerTimeNow()` at predicate lines, R6-B5 `deathDeductionCommitted` absent from T6 clearance, R6-B8–B12 reconciliation-tick unchanged). Rather than re-run the full 7-agent panel to re-derive the known verdict (a documented no-op class — cf. the 2026-05-02 "no-op re-review against unchanged text" entry), the user elected to **skip the panel and execute the CD-prescribed Round-7 Session 1 trivial-fix sweep** directly. This entry records that patch. **No verdict is implied — this is a patch, not a review.**

**Scope:** Session 1 of the round-6 CD two-session prescription — the trivial-fix sweep (scope S). The heavy reconciliation-tick lifecycle/contract patch (Session 2) is explicitly deferred to a separate fresh session, then a round-8 `/design-review`.

**Edits applied (8 items across 2 files):**

| ID | Severity | Fix | Section / file |
|---|---|---|---|
| **R6-B1** | BLOCKING (5-spec convergence) | C.5.3 read-and-cache skeleton gains `local cachedNow = getServerTime()` (passed into `isImminentDeath_cached(...)`); both predicate arms now call `getServerTime()` (C.11 seam), not inline `workspace:GetServerTimeNow()`. Unblocks the paper-only ACs H.22b–f. | `player-controller.md` C.5.3 |
| **R6-B2** | BLOCKING | `pulseEmissionMagnitude` formula expression rewritten to anchor `t_lastGracePulse[axis] = t_0` in a Step-0a anchor-on-eligibility clause (out of the grace-AND-window branch), matching the GDD D.4 B9 fix. Closes the 1ms-past-window jitter reopening of G1 under thermally-throttled mobile. | `entities.yaml` `pulseEmissionMagnitude` |
| **R6-B3** | BLOCKING | `GRACE_REENTRY_COOLDOWN` notes gain the inclusive `>=` eligibility-comparator annotation (eligible again at exactly the cooldown boundary), explicitly contrasted with the strict-`<` B11 comparators and aligned to the `PING_COOLDOWN_PER_PLAYER` `>=` precedent. | `entities.yaml` `GRACE_REENTRY_COOLDOWN` |
| **R6-B4** | BLOCKING (4-spec convergence) | Unenforceable camera-angle plausibility clause deleted from C.4.1 + C.9 (camera orientation is not server-tracked); server now validates ray origin within `PING_ORIGIN_TOLERANCE` + re-runs the raycast server-side (client `candidateTargetId` advisory). New knob `PING_ORIGIN_TOLERANCE` = 8 studs (first-pass placeholder, Theme-2-tuned) added to G.4 + registry. | `player-controller.md` C.4.1/C.9/G.4 + `entities.yaml` |
| **R6-I6** | IMPORTANT | E.D heartbeat timeout predicate + T1-seed both route through `getServerTime()` (C.11 seam). | `player-controller.md` E.D |
| **R6-I7** | IMPORTANT | V/A.3 lantern-lower SFX gains Path-B suppression qualifier (no character-attached sound on a destroyed/destroying character). | `player-controller.md` V/A.3 |
| **R6-I8** | IMPORTANT (carried-unfulfilled 2 rounds — process-integrity escalation) | V/A.3 Death SFX gains Path-B anchoring: snapshot `lastKnownPosition` at `PlayerRemoving` before destruction, play remote cue from a world-anchored character-detached emitter (exact audio API deferred to Theme 2 per the post-cutoff flag); own-player Death SFX N/A on Path B. | `player-controller.md` V/A.3 |
| **R6-I9** | IMPORTANT (carried-unfulfilled 2 rounds — process-integrity escalation) | V/A.3 lantern raise + lower SFX gain the "fires on the T3/T4 state transition ONLY — NOT per `LightEmission` pulse" negative rule. | `player-controller.md` V/A.3 |

**Header status block** refreshed (was 4 reviews stale — said "round-4 applied / round-5 pending"). Now reflects round-6 MAJOR REVISION + round-7 Session 1 applied + Session 2 pending.

**Verification:** Post-edit grep confirms zero remaining `workspace:GetServerTimeNow()` *call-site* violations in C.5.3 or E.D; the 9 surviving references are all legitimate (C.8.4 ED.D.1 primitive rule, C.11 seam definition/prose, D.4 variable descriptions, F.4/F.5 prose, H.22d AC). This grep + clean-apply pass served as the CD-prescribed round-6.5 mini-validation for the trivial sweep.

**Patch effort:** ~single-session, 11 edits (8 GDD + 3 registry), zero design-decision risk per the round-6 CD adjudication.

**Carried-open to Round-7 Session 2 (separate fresh session, scope M):** R6-B5 (`deathDeductionCommitted` not cleared on T6 — 3-spec convergence, same defect class as round-4 B6), R6-B6 (`RECONCILIATION_TICK_INTERVAL` not registered), R6-B7 (reconciliation tick absent from C.11 seam scope table), R6-B8 (reconciliation success path doesn't invoke T5 side-effects (a)/(b) — phantom pulses), R6-B9 (`userId` vs `Player`-instance keying contradiction — 3-spec convergence), R6-B10 (`player.Name` access on destroyed instance crashes the handler), R6-B11 (8 missing reconciliation ACs), R6-B12 (Death SFX must not fire on `deathCause="reconciliation-recovery"`), plus R6-I1–I5/I10/I11/I12 cluster. **After Session 2 lands, run a round-8 `/design-review` in a fresh session. DO NOT predict APPROVED for round-8** — the converging defect-rate pattern means a NEEDS REVISION tail is plausible.

**Note (minor, not flagged round-6, deferred):** D.4 variable-table descriptions still describe `t` / `t_0` as `workspace:GetServerTimeNow()` at the primitive level; these are descriptive variable definitions, not call sites, and the `t_lastGracePulse` variable already cites the seam. Optional consistency cleanup for a future pass.

### Files Modified This Session

- `design/gdd/player-controller.md` — 8 edits (R6-B1, B4-prose, B4-knob, I6, I7, I8, I9 + header).
- `design/registry/entities.yaml` — 3 edits (R6-B2 formula, R6-B3 notes, R6-B4 `PING_ORIGIN_TOLERANCE` registration).
- `design/gdd/reviews/player-controller-review-log.md` — this Round-7 Session 1 entry appended.
- `production/session-state/active.md` — refreshed to round-7-Session-2-pending state.
- `design/gdd/systems-index.md` — NOT modified (status correctly remains MAJOR REVISION NEEDED; heavy items open).

---

## Review — 2026-06-08 — Lean re-review (Round-7 Session 1 validation) — Verdict: MAJOR REVISION NEEDED

**Scope signal:** M (remaining = the deferred Round-7 Session 2 reconciliation-tick lifecycle/contract patch — multi-section coordinated edits + 8 ACs + 1 registry constant; ~2–3 hours, one fresh session, 1 likely user design decision at R6-B9).
**Specialists:** None this session — Phase 3b adversarial spawn intentionally skipped (user chose lean depth after the situation was surfaced). No re-adjudication of the round-6 panel's findings; this entry re-affirms the standing verdict from direct file inspection.
**Blocking items:** 8 BLOCKING (R6-B5–R6-B12, carried open by design) | **Recommended:** R6-I1–I5/I10/I11/I12 cluster (carried) | **Nice-to-have:** D.4 variable-table primitive-level cleanup
**Prior verdict resolved:** Partially — Round-7 **Session 1** (trivial sweep) cleanly closed R6-B1/B2/B3/B4 + R6-I6/I7/I8/I9 (verified: predicate routes through `getServerTime()`; `PING_ORIGIN_TOLERANCE` registered in `entities.yaml`; camera-angle clause deleted from C.4.1/C.9; V/A.3 Path-B audio rules added). Round-7 **Session 2** (the heavy reconciliation-tick lifecycle/contract patch) has **not** run — the 8 R6-B5–B12 blockers remain open *by design, not regression*.
**Review depth:** lean (no panel; the GDD is in a known intermediate state — full 7-agent spawn would re-derive the standing verdict on items provably open before it spawns; cf. the 2026-05-02 "no-op re-review against unchanged text" precedent).

### Summary

A `/design-review` was invoked on `player-controller.md` with no path argument; the user selected PC as the target and then chose lean depth after being shown that PC sits at a known MAJOR REVISION (Session 2 deferred by design). Structural Phases 1–4 ran; Phase 3b was skipped.

Direct file-inspection confirmed all 8 carried blockers still live:

- **R6-B5** — C.6 T6 row (line 250) clears only `_deathCostPaid`, not `deathDeductionCommitted` (multi-life Pillar-2 silent break; same class as round-4 B6). **The single load-bearing item.**
- **R6-B6** — `RECONCILIATION_TICK_INTERVAL = 5.0 s` absent from `entities.yaml` (grep: 0 hits).
- **R6-B7** — reconciliation tick has no row in the C.11 seam-scope table (lines 368–378).
- **R6-B8** — C.5.3 reconciliation success path (~line 177) re-invokes deduction + broadcast only, not T5 side-effects (a)/(b) (phantom Sprint/Light pulses on destroyed `HumanoidRootPart` on the rollback-then-reconcile path; R5-B1 Pillar-1 closure regressed for the failure path).
- **R6-B9** — reconciliation rows `userId`-keyed (line 179) contradict F.4 `Player`-instance keying (line 687); re-keying + rejoin-during-reconciliation race unspecified.
- **R6-B10** — step-5 rollback `warn(... player.Name ...)` (line 164) crashes the handler for the rest of the session on Path-B reconciliation retries (instance destroyed by tick time).
- **R6-B11** — reconciliation tick has zero AC coverage (8 missing: F3a–F3h).
- **R6-B12** — V/A.3 Death SFX row (line 842) lacks the `deathCause="reconciliation-recovery"` suppression clause (false death cue 10s late; Pillar-3 audio-as-feedback).

No new structural defects were introduced by Session 1 (grep: zero `workspace:GetServerTimeNow()` call-site violations remain in C.5.3/E.D).

### Senior Verdict (structural — no creative-director synthesis this session)

> The GDD is exactly where the round-6 CD prescription expected it: Session 1 closed 8 items cleanly; Session 2 has not run. The 8 carried blockers cluster entirely on the R5-B2 reconciliation-tick surface (the youngest, deepest design surface in the document). The CD's standing meta-warning holds — if round-8 (after Session 2) again returns NEEDS REVISION, reconsider the reconciliation-tick *architecture* rather than patching a further round. **Verdict re-affirmed: MAJOR REVISION NEEDED. Do not advance to Theme 2 until Session 2 lands and a round-8 fresh-session panel verdicts APPROVED. DO NOT predict APPROVED for round-8.**

### Recommendation

User chose **Stop here — apply Round-7 Session 2 in a fresh session**. Binding plan unchanged: the round-6 Session 2 patch list (R6-B5–B12 + R6-I1–I5/I10/I11/I12) in a clean fresh session, then a round-8 `/design-review`.

### Files Modified This Session

- `design/gdd/reviews/player-controller-review-log.md` — this lean re-review entry appended.
- `design/gdd/systems-index.md` — PC status row updated (Session 1 applied note + lean re-review note; Status unchanged at MAJOR REVISION NEEDED).
- `design/gdd/player-controller.md` — NOT modified (read-only review).
- `production/session-state/active.md` — NOT modified (Session 1 state remains accurate; Session 2 still pending).

---

## Review — 2026-06-08 — Full-mode re-review (second same-day) — Verdict: MAJOR REVISION NEEDED

**Scope signal:** M (unchanged — the deferred Round-7 Session 2 reconciliation-tick lifecycle/contract patch: multi-section coordinated edits across C.5.3/C.6/C.11/F.4/V/A.3/V/A.4/Section H + 8 ACs + 1 registry constant; ~2–3 hrs, one fresh session, 1 likely user design decision at R6-B9).
**Specialists:** None spawned. `/design-review` was invoked in **full** mode (default), but Phase 3b was skipped by explicit user choice after the no-op situation was surfaced. No re-adjudication — standing round-6 panel findings carried.
**Blocking items:** 8 BLOCKING (R6-B5–R6-B12, carried open by design) | **Recommended:** R6-I1–I5/I10/I11/I12 cluster (carried) | **Nice-to-have:** D.4 variable-table primitive-level cleanup.
**Prior verdict resolved:** No — `player-controller.md` is **byte-unchanged since the Round-7 Session 1 sweep (2026-06-07)**; today's earlier lean re-review modified only the review log + systems-index, not the GDD. All 8 R6-B5–B12 blockers re-confirmed live by direct file inspection (T6 row at line 250 clears only `_deathCostPaid`; `RECONCILIATION_TICK_INTERVAL` absent from registry; reconciliation tick absent from C.11 seam table; success path omits T5 (a)/(b); `userId` keying vs F.4 `Player` keying; `player.Name` crash on Path-B retry; zero tick AC coverage; Death-SFX suppression clause absent).
**Review depth:** lean-equivalent (full mode invoked; panel declined as a documented no-op — a 7-agent spawn would re-derive the standing verdict on items provably open *before* it spawns; cf. the 2026-05-02 "no-op re-review against unchanged text" and 2026-06-08 lean re-review precedents).

### Summary

A `/design-review` (full, no `--depth` flag) was invoked on `player-controller.md` with no path argument; the user selected PC as the target. Phase 1–2 completeness (8/8 sections) and Phase 3 structural/dependency-graph passes ran; before Phase 3b, the no-op situation was surfaced (GDD unchanged since today's lean re-review, which had itself re-affirmed MAJOR REVISION NEEDED with Session 2 open by design). User chose to skip the panel and re-affirm the verdict. The 8 carried blockers cluster entirely on the R5-B2 reconciliation-tick surface — the youngest, deepest design surface in the document.

### Senior Verdict (carried — creative-director round-6, re-affirmed)

> The GDD is exactly where the round-6 prescription expected it: Session 1 closed 8 items cleanly; Session 2 has not run. **Standing meta-warning holds** — if round-8 (after Session 2 lands) again returns NEEDS REVISION, reconsider the reconciliation-tick *architecture* rather than patching a further round. Do not advance to Theme 2 until Session 2 lands and a round-8 fresh-session panel verdicts APPROVED. **DO NOT predict APPROVED for round-8.**

### Recommendation

User chose **Stop here — apply Round-7 Session 2 in a fresh session**. Binding plan unchanged: the round-6 Session 2 patch list (R6-B5–B12 + R6-I1–I5/I10/I11/I12) in a clean `/clear` session, then a round-8 `/design-review`.

### Process note (reusable)

This is the second same-day re-review re-deriving an unchanged verdict on unchanged text. Same class as the Crafting & Items re-review loop the user broke on 2026-06-08. **Precedent: when a GDD is byte-unchanged since the last review and its open blockers are provably live before any panel spawns, surface the no-op and let the user choose rather than auto-spawning Phase 3b.** The durable fix is to land Session 2, not to re-run panels.

### Files Modified This Session

- `design/gdd/reviews/player-controller-review-log.md` — this entry appended.
- `design/gdd/systems-index.md` — PC row note appended (second same-day re-confirmation; Status unchanged at MAJOR REVISION NEEDED).
- `design/gdd/player-controller.md` — NOT modified (read-only review).

---

## Round-7 Session 2 Patch — 2026-06-08 — Status: APPLIED (reconciliation-tick lifecycle/contract patch)

**Type:** Patch session, NOT a review verdict. The next `/design-review` of this GDD (round-8, fresh session) is the binding validation gate. **DO NOT predict APPROVED for round-8** — the standing round-6 CD meta-warning holds: if round-8 again returns NEEDS REVISION, reconsider the reconciliation-tick *architecture* rather than patching a further round.

**Scope:** Session 2 of the round-6 CD two-session prescription — the heavy reconciliation-tick lifecycle/contract patch (scope M). Closes all 8 carried BLOCKING items (R6-B5–B12) plus the R6-I1/I2/I3/I4/I5/I10/I11/I12 IMPORTANT cluster. Multi-section coordinated edits across C.5.3, C.6, C.9, C.11, D.2, F.4, V/A.3, V/A.4, G.6, Section H + `entities.yaml`.

**One user design decision (R6-B9 keying), locked 2026-06-08:** death-cost reconciliation rows for **removed (Path B) players** are keyed by a per-death-event **`deathEventId`** (monotonic server-session counter), snapshotting `{deathEventId, userId, playerName, lastKnownPosition}`. Live per-player flags (`_deathCostPaid`, `deathDeductionCommitted`) for **present (Path A)** players remain `Player`-instance-keyed (consistent with F.4). The two keying domains are disjoint. The rejoin-during-reconciliation race is closed: a rejoin is a fresh `Player` instance with fresh flags and never collides with the independent pending `deathEventId` row. (Options considered: deathEventId token [chosen], Player-instance-keyed-throughout, (userId, joinEpoch) composite.)

**Edits applied (8 BLOCKING + 8 IMPORTANT across 2 files):**

| ID | Severity | Fix | Section / file |
|---|---|---|---|
| **R6-B5** | BLOCKING (3-spec convergence) | C.6 T6 row now clears **both** `_deathCostPaid` AND `deathDeductionCommitted` to `false`; C.5.3 idempotency prose rewritten to explain the two-flag clearance and the multi-life silent-break it prevents (same class as round-4 B6). | `player-controller.md` C.6 T6 + C.5.3 |
| **R6-B6** | BLOCKING | `RECONCILIATION_TICK_INTERVAL = 5.0 s` registered in `entities.yaml` + added to G.6 knobs table with the `2 × interval < RESPAWN_DELAY` invariant. | `entities.yaml` + `player-controller.md` G.6 |
| **R6-B7** | BLOCKING | Reconciliation-tick interval gate added as a row in the C.11 seam-scope table (must route through `getServerTime()`; unblocks the F3a–F3h ACs). | `player-controller.md` C.11 |
| **R6-B8** | BLOCKING | Reconciliation success path now invokes T5 side-effects **(a) sprint pulse-timer stop + (b) lantern force-T4** and explicitly **suppresses (c)–(f)**; idempotent re-stop is safe on both initial-T5 and reconciliation paths. Closes the phantom Sprint/Light pulse class on destroyed `HumanoidRootPart` for the rollback-then-reconcile path (R5-B1 Pillar-1 closure restored for the failure path). | `player-controller.md` C.5.3 |
| **R6-B9** | BLOCKING (3-spec convergence) | Reconciliation working-set re-keyed to per-death-event `deathEventId` (user decision); two disjoint keying domains documented; rejoin-during-reconciliation race closed; F.4 keying-scope note added. | `player-controller.md` C.5.3 + F.4 |
| **R6-B10** | BLOCKING | Rollback `warn(...)` reads `deathContext.playerName` (snapshotted at death-event creation), never live `player.Name` — closes the destroyed-instance nil-parent crash that killed the handler for the whole session on Path-B retries. | `player-controller.md` C.5.3 |
| **R6-B11** | BLOCKING (2-spec convergence) | 8 reconciliation ACs **H.35–H.42** added (new H.7r block) mapping qa-lead F3a–F3h: Path-A recovery, Path-B deathEventId recovery, double-deduction guard, 10 s SLA bound, success-path exit, first-tick timing gate, `deathDeductionCommitted` T6-clearance binary signal, BindToClose in-flight loss invariant. | `player-controller.md` Section H |
| **R6-B12** | BLOCKING (audio-director, CD-confirmed) | V/A.3 Death SFX MUST NOT fire on `deathCause="reconciliation-recovery"` (false death cue ≤10 s late); delayed notification is HUD-only. | `player-controller.md` V/A.3 |
| **R6-I1** | IMPORTANT | D.2 regen-gate boundary comparator documented as strict `>` (not `>=`) + `entities.yaml` `STAMINA_REGEN_DELAY` note. | `player-controller.md` D.2 + `entities.yaml` |
| **R6-I2** | IMPORTANT | F.4 PredatorService deferral prose corrected: cache-first read closes the mid-yield race (Race 1) ONLY; the PredatorService-clears-before-PC-entry race (Race 2, a Pillar-2-safe false-negative) is closed by a BINDING `task.defer` of PredatorService's clearance. | `player-controller.md` F.4 |
| **R6-I3** | IMPORTANT | F.4 HUD forward-obligation row added for the `reconciliation-recovery` ≤10 s delayed-notification UX (HUD-only since SFX + caption are suppressed). | `player-controller.md` F.4 |
| **R6-I4** | IMPORTANT | C.9 `OnPlayerDied` `deathCause` enumerated: `{"died", "disconnect-while-damaged", "reconciliation-recovery"}`. | `player-controller.md` C.9 |
| **R6-I5** | IMPORTANT | Each reconciliation retry `task.spawn`'d off the Heartbeat handler (the tick body only scans + dispatches), with an in-flight guard — closes the unbounded 200–600 ms Heartbeat-block that falsified H.28. | `player-controller.md` C.5.3 |
| **R6-I10** | IMPORTANT | V/A.4 "[Name] is down" caption suppressed on `reconciliation-recovery` (caption/audio parity with R6-B12). | `player-controller.md` V/A.4 |
| **R6-I11** | IMPORTANT | C.5.3 lifecycle: `_deathCostPaid`/`deathDeductionCommitted` initialized to `false` (not nil) on `Players.PlayerAdded`; `reconcileRows` bootstrap-init to `{}`; (c)–(f) suppression for removed players documented. | `player-controller.md` C.5.3 |
| **R6-I12** | IMPORTANT | C.11 Lemur `PlayerRemoving` fidelity caveat added (Path-B + reconciliation ACs confirmed in live Studio, not solely Lemur); exact-boundary AC **H.43** added (HP=25.0 / 30.0 s / 3.0 s neither-fires, paired off-boundary). H.22f already adequately white-box (verifies internal flag transitions). | `player-controller.md` C.11 + Section H |

**Header status block** refreshed (Session 2 applied; round-8 pending; DO-NOT-predict-APPROVED warning carried).

**Patch effort:** single fresh session, ~17 edit sites across 2 files, 1 user design decision (R6-B9) per the round-6 CD adjudication.

**Verification (read-back / grep):** zero remaining `userId`-keyed / `userId index` reconciliation-row references in the GDD (the round-6 B9 contradiction text is fully replaced by the deathEventId model). All 8 R6-B5–B12 closures land at the rule level; the R6-I cluster lands inline. `deathDeductionCommitted` now appears in C.5.3 idempotency prose, C.6 T6 clearance, the reconcile-eligible predicate, and AC H.41 (binary signal).

**Carried forward to round-8 `/design-review` (fresh session):** the full 7-spec panel re-validates the reconciliation-tick surface. Standing CD meta-warning: a third NEEDS REVISION on this surface should trigger an architecture reconsideration of the reconciliation tick, not a round-9 patch. Themes 2/3/4 + OQ.3 (Camera GDD) remain out of scope and PENDING.

### Files Modified This Session

- `design/gdd/player-controller.md` — Session 2 edits across C.5.3, C.6, C.9, C.11, D.2, F.4, V/A.3, V/A.4, G.6, Section H + header (~14 edit sites; 8 new ACs H.35–H.43).
- `design/registry/entities.yaml` — `RECONCILIATION_TICK_INTERVAL` registered; `STAMINA_REGEN_DELAY` boundary note (R6-I1).
- `design/gdd/reviews/player-controller-review-log.md` — this Round-7 Session 2 entry appended.
- `design/gdd/systems-index.md` — PC row updated (Session 2 applied; Status stays MAJOR REVISION NEEDED — round-8 is the gate).
- `production/session-state/active.md` — refreshed to round-8-pending state.

---

## Review — 2026-06-08 — Round-8 (binding gate; first fresh full panel against the round-7-patched GDD) — Verdict: NEEDS REVISION

**Scope signal:** M trending L (producer should verify before sprint planning). Round-9 = a CD ruling session + one structural authoring pass (a state-machine refactor of the death-cost flag cluster) + two narrow gates; reserve the full 7-spec panel for round-10.
**Specialists:** game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead, gameplay-programmer (build-from-artifact lens), creative-director (senior synthesis). 7 lenses spawned in parallel adversarially; CD synthesized. (The ai-programmer lens truncated on first spawn and was re-run via a general-purpose agent per the no-SendMessage harness precedent.)
**Blocking items:** ~14 BLOCKING | **Recommended:** ~11 IMPORTANT | **Nice-to-have:** several
**Prior verdict resolved:** Yes — all 12 round-6 BLOCKING (R6-B1–B12) + 12 IMPORTANT confirmed closed at the rule level by the round-7 Session 1 + Session 2 patches. This was a genuine fresh full panel against the materially-changed GDD (NOT a no-op re-review). The round-8 BLOCKING items are NEW / second-order, not carried R6 items.
**Review depth:** full (7 lenses + CD synthesis).

### The DO-NOT-predict-APPROVED caution held
Round-8 returned NEEDS REVISION, the empirically-expected non-APPROVED outcome the standing caution predicted. The meaningful good news beneath it: the spine is sound on three independent axes and the architecture is NOT being torn up.

### What the panel confirmed genuinely CLEAN (previously-broken surfaces)
- **Server-authority + cost-attribution chain SOUND** [network-programmer] — no client trust for gameplay-critical state; deathEventId keying resolves the rejoin race; no exploit/DoS regression.
- **All formulas D.1–D.6 degenerate-free; D.5 30 s trace verified row-by-row; registry 28/28 PC constants ZERO divergence** [systems-designer] — the recurring registry-divergence class (R3-B5/R5-B4/R6-B2/B6) is clean this round.
- **Predicate nil-safety sound; Race 1 + Race 2 pair correctly reasoned; strict-`<` boundary semantics correct + Pillar-2-safe; R6-B10 destroyed-instance log crash closed** [ai-programmer].
- **All round-6 audio items (R6-B12/I7/I8/I9/I10) genuinely closed with normative language** [audio-director] — not nominal closures.
- **Overall buildability = BUILDABLE-WITH-FIXES; the two-keying-domain architecture is conceptually sound** [gameplay-programmer].

### Round-8 BLOCKING — convergences (binding multi-lens evidence)
- **CONV-1 — In-flight marker lifecycle unspecified [FIVE-lens: systems, network B1, gameplay F2, qa GAP-1/IMP-2/IMP-3, game-designer B2].** C.5.3 names a per-row in-flight marker in one sentence but never specifies set / clear-on-success / **clear-on-failure**. Naive impl leaves a row permanently in-flight after any transient RM failure → squad oxygen permanently lost (Pillar-2 silent break). **This is the 4th reproduction of the "flag SET specified, CLEAR-ON-FAILURE omitted" class** (`_deathCostPaid`-on-T6 = R4-B6; `deathDeductionCommitted` = R6-B5; in-flight marker = R8). No AC covers the failure path.
- **CONV-2 — `task.defer` Race 2/Race 3 [TRIPLE-lens: network B2, ai B-AI-1, gameplay F5].** The binding Race-2 closure rests on an unverified post-cutoff Roblox API ordering claim (`task.defer` vs Knit's `PlayerRemoving` dispatch); and the defer opens a new Race 3 (deferred-clear instance-key semantics not pinned — must clear the exact `Player` instance key, never userId, with a no-op-if-replaced guard; else a Wi-Fi-flap rejoin reopens the stale-entry false-positive/negative class).
- **CONV-3 — deathContext snapshot surface incomplete [TRIPLE-lens: game-designer B1, gameplay F1+F3, audio F1].** (a) Path-A `deathContext` existence ambiguous (C.5.3 says every death creates one, but Path A uses Player-instance flags with no reconcileRows entry — implementers either omit it (breaking the rollback log) or add a reconcileRows entry (creating double-dispatch)); (b) Path-B `PlayerRemoving` skeleton omits `lastKnownPosition`/`playerName` from the pre-yield cache block + no nil-coalesce for `HumanoidRootPart.Position` (nil propagates to the world-anchored Death SFX); (c) Path A vs B remote-Death-SFX emitter-attachment strategy unspecified.
- **CONV-4 — Path-A SLA claim false [DOUBLE-lens: systems Finding 1, game-designer B3].** A T5 failure within the last tick-interval before T6 → T6 clears both flags + moves the player to S1 before the next tick → tick finds them not-in-S4 → cost permanently lost. And the "10 s" bound assumes a retry completes within one interval (false under RM load; true worst case is N×interval).

### Round-8 BLOCKING — singles (concrete)
- **systems Finding 4** — cross-knob invariant `2 × RECONCILIATION_TICK_INTERVAL < RESPAWN_DELAY` is VIOLATED within the stated G.6 ranges (`RECONCILIATION_TICK_INTERVAL ∈ [2,10]`, `RESPAWN_DELAY ∈ [10,60]`; at 10 & 10 → 20<10 false). Must be a coupled-knob constraint, not a too-high note citing only the default.
- **network B3** — `OnPlayerDied(deathCause="reconciliation-recovery")` recipient set unspecified for a player who has LEFT the server (Path B). Who receives it? Late-joiners with unknown playerId? Must be specified in C.9.
- **ai B-AI-2** — predator target-lock / aggro release on player death is an UNFLAGGED forward obligation (flagged round-1 A3 AND round-5 I.4, still absent from F.4); now incoherent with T6 clearing `lastPredatorDamageTimestamp`. CD escalated to BLOCKING (carried-unfulfilled rule); **PC's contract to own** (caller owns the contract).
- **game-designer B4** — `RunEnded` authority conflict: PC T7 (all-S4 + oxygen<1) and Crafting's Beacon victory/window-fail path can BOTH broadcast RunEnded for a full-squad-wipe during the Beacon window (common at 2-player floor). T8 victory leaves S4-player handling undefined. CD ruling: **PC emits, does not broadcast (single owner).**
- **game-designer B5** — "Scenario C" acknowledged false-negative escalated to BLOCKING **at the 2-player floor** — a systematic Pillar-2 cost-evasion path framed as an accepted design choice without 2-player analysis. **CD design ruling required** (recommend closing the evasion window; user may override to explicitly accept).
- **game-designer B6** — `t_lastGracePulse_sprint/_light` NOT reset on `Players.PlayerAdded` (only on Humanoid.Died/T5, suppressed for Path B) → Wi-Fi-flap rejoin within 6 s carries a stale grace-cooldown anchor into the new life (Pillar-1 wrong magnitude + Pillar-4 unfairness).
- **qa BLK-1..4** — H.41 is a downstream proxy, not the binary R6-B5 signal it claims; H.42 BindToClose is not Lemur-injectable but is labeled AUTO-INTEGRATION; H.36/H.38/H.39 per-AC Lemur-caveat labeling inconsistent with C.11; H.28 perf budget doesn't exercise the reconciliation scan + no longer covers the `task.spawn` dispatch model.

### Round-8 IMPORTANT (representative)
audio F2 (Respawn SFX/caption no `reconciliation-recovery` guard — timeline compression), audio F3 (walk-SFX mechanical-equivalence test vacuous post-OQ.1; walk volume floor unprotected), network I1 (PlayerHeartbeat drop-first write ordering not normative), network I4 (RequestEmote slot type/integer constraint), systems (FIRST_PULSE_GRACE_WINDOW + RECONCILIATION_TICK_INTERVAL + SPRINT_CLIENT_TIMEOUT boundary comparators undocumented — B11 class), ai I1 (only-predator-writes-timestamp not architecturally enforceable), ai I2 (Scenario-C sibling — single-scalar last-writer-wins makes attribution graze-timing-sensitive), qa coverage gaps (in-flight mid-retry skip + rejoin-during-reconciliation race — both untested; the latter load-bearing for the R6-B9 deathEventId decision), Themes 2/3/4 accumulated debt after 8 rounds, Scenario C documented in C.5.3 prose not E.E.

### Senior Verdict (creative-director)

> **NEEDS REVISION (scope M trending L). Architecture reconsideration NOT triggered.** The meta-warning's real target is whack-a-mole, and the panel evidence shows the *opposite* of a wrong architecture — three independent lenses confirm the spine sound (authority SOUND, formulas degenerate-free, registry zero-divergence, buildable). What recurs (the in-flight marker, the 4th instance of the flag-set/clear-omitted class) is a **missing abstraction inside a sound architecture**, not a flawed architecture. **ONE more round is authorized — but a STRUCTURAL one that earns the reprieve:** encapsulate the three scattered death-cost booleans (`_deathCostPaid`, `deathDeductionCommitted`, in-flight marker) into a single `DeathCostReconciliation` state record (Pending / InFlight / Committed / Abandoned) with one mandatory set / clear-on-success / clear-on-failure contract per transition, so a fifth free boolean can't be added with a missing clear path.
>
> **Binding bar: if round-9's "fifth-flag" design test still answers 'a new free boolean, clear-path TBD,' architecture reconsideration triggers at round-10 with no further warning.**
>
> **Design rulings to lock before authoring:** B5 Scenario-C at 2-player floor (BLOCKING — recommend closing the evasion window, user override available); B4 RunEnded single-owner (PC emits, does not broadcast); CONV-2 `task.defer` API posture (do not ship a binding correctness claim on an unverified post-cutoff API — verify or downgrade to an intent claim); B-AI-2 predator target-lock = PC's contract to own (escalated to BLOCKING per the carried-unfulfilled rule).
>
> **Round-9 structure:** CD ruling session → one authoring pass (the state-machine refactor as the spine + the ~14 BLOCKING) → two re-scoped narrow gates (network re-confirm + build-lens transition-completeness, NOT old flag-name greps). Reserve the full 7-spec panel for round-10. **Do not predict APPROVED for round-10.** Themes 2/3/4 + OQ.3 (Camera GDD) remain out of scope and PENDING until round-10 verdicts APPROVED.

### Recommendation

User chose **Stop here — apply round-9 in a fresh `/clear` session** (matching the established PC patch cadence + the context-management "one heavy surface per session" rule). Binding plan: the round-9 CD ruling session (lock B5/B4/CONV-2/B-AI-2) → the `DeathCostReconciliation` state-machine authoring pass closing the ~14 BLOCKING → network + build narrow gates → then a round-10 full `/design-review`.

### Files Modified This Session

- `design/gdd/reviews/player-controller-review-log.md` — this round-8 entry appended.
- `design/gdd/systems-index.md` — PC row updated with the round-8 verdict + the CD round-9 structural prescription (Status stays MAJOR REVISION NEEDED — round-8 is the gate, not yet APPROVED).
- `design/gdd/player-controller.md` — NOT modified (read-only review).
- `production/session-state/active.md` — to be refreshed to round-9-pending state.

---

## Patch — 2026-06-08 — Round-9 (CD-prescribed STRUCTURAL authoring pass + two narrow gates) — Type: PATCH, not a verdict

**Type:** Authoring pass, NOT a review verdict. The binding gate is a **round-10 full 7-spec `/design-review` in a fresh session. DO NOT predict APPROVED for round-10.** Status stays MAJOR REVISION NEEDED until round-10 verdicts APPROVED. GDD heavily edited this session; NOT committed (branch `crafting-round2-patch`).

### What round-9 was
The single CD-authorized structural round from the round-8 synthesis: dissolve the recurring "flag SET specified, CLEAR-ON-FAILURE omitted" defect class (4 reproductions: R4-B6, R6-B5, R8 CONV-1) by replacing the three scattered death-cost booleans (`_deathCostPaid`, `deathDeductionCommitted`, in-flight marker) with a single per-death-event **`DeathCostReconciliation` state record** — states **Pending / InFlight / Committed / Abandoned**, keyed by `deathEventId`, with a `currentDeathRecord[player]` convergence pointer. Reconcile-eligibility collapses to `state == "Pending"`. Architecture reconsideration was NOT triggered (CD round-8 ruling); this is the "missing abstraction inside a sound architecture" fix.

### 2 user design rulings locked this session
- **B5 (Scenario-C cost-evasion) → CLOSE the evasion window.** Implemented as imminent-death predicate **arm 3** + a PredatorService-owned `predatorCausedImminent` latch (set on predator damage crossing/striking-below `HP_IMMINENT_THRESHOLD`; cleared on HP-recovery or T6). Sidesteps the damage-magnitude ADR the round-4 prose feared (keys on threshold-crossing causality, not magnitude). Stale-graze round-3 false-positive stays closed.
- **CONV-2 (`task.defer` Race-2) → DOWNGRADE to a Studio-verify intent.** The binding correctness claim on the unverified post-cutoff scheduler ordering is removed; correctness now rests on the robust no-op-if-replaced exact-`Player`-instance-key guard (closes Race 3 regardless of scheduler order). Race 2 residual is the accepted Pillar-2-safe under-charge. Added to the Theme-2 API-verification list.

### CD-ruled items applied (no user fork)
- **B4 RunEnded single-owner:** PC raises the T7 whole-squad-wipe *condition*; does NOT broadcast. Single arbiter (forward-flagged `RunController`) broadcasts once with **victory(T8)-over-wipe(T7) precedence**. T8 + S4 player = rescued (S4→S5 victory, respawn cancelled, counted survivor).
- **B-AI-2 predator target-lock release:** new F.4 row — on T5 (either path) PC's contract triggers `PredatorService:ReleasePredatorLock(player)` (caller owns the contract), paired with the T6 `lastPredatorDamageTimestamp` + latch clearance. Carried-unfulfilled since round-1 A3 / round-5 I.4 — now closed.

### Keystone dissolutions (one refactor closed five round-8 findings)
CONV-1 (in-flight marker lifecycle) → InFlight is a first-class state with mandatory exits. CONV-3(a) (Path-A deathContext existence) → Path A/B unified (every death mints a record). CONV-4 + systems Finding 4 (cost lost if T6 respawns before a failed tick recovers; cross-knob `2×INTERVAL<RESPAWN_DELAY` violable) → a `Pending` record is `deathEventId`-keyed and survives T6; the cross-knob relation downgraded to an advisory UX coupling (G.6). R6-B5/H.41 (second-life pays zero) → structurally impossible; H.41 re-pointed to assert record independence.

### Other BLOCKING closed
CONV-3(b)/(c) (Path-B pre-yield snapshot + nil-coalesce + world-anchored Death-SFX emitter strategy for both paths, V/A.3); network B3 (`OnPlayerDied` reconciliation-recovery recipient set, C.9); game B6 (`t_lastGracePulse_*` reset on `PlayerAdded`, E.E); qa BLK-1..4 (H.41 re-point; H.42 re-label MANUAL/in-Studio + Abandoned transition; H.36/H.38/H.39 Lemur-caveat labels; H.28 extended to the reconciliation scan + `task.spawn` dispatch). IMPORTANT cluster folded: audio F2 (Respawn SFX/caption guarded vs reconciliation-recovery), F3 (walk-volume floor `WALK_FOOTSTEP_VOLUME_FLOOR` + de-vacuous equivalence test), network I1 (heartbeat drop-first-write normative), I4 (`slot` integer ∈{1..6}), systems gate-comparator docs (G.6), Scenario C relocated to E.E as CLOSED, +3 new coverage ACs (H.44 arm-3, H.45 mid-retry skip, H.46 rejoin-during-reconciliation).

### Two narrow gates (CD-prescribed — NOT a full panel)
- **Network re-confirm [network-programmer, native]: SOUND — 0 BLOCKING, 2 IMPORTANT (both closed in-session).** Server-authority + exactly-once attribution preserved under the state record; two-path convergence race-safe under the InFlight guard; CONV-2 downgrade robust; B3/B4 sound; no new exploit/DoS/forge path from arm-3 latch, drop-first-write, or slot-integer validation. N-F1 (latch HP-recovery clear had no named watcher) + N-F2 (late-joiner × reconciliation-recovery HUD guidance) → both fixed (F.4 named forward obligation; C.9 HUD contract note).
- **Build-lens transition-completeness [general-purpose, native]: BUILDABLE-WITH-FIXES — 1 BLOCKING, 3 IMPORTANT (all closed in-session).** The "fifth-flag" CD bar **PASSED** (no surviving free boolean with an undefined clear path). **BLOCKING B-F1:** an `InFlight` row could be stranded forever if the `task.spawn`'d retry coroutine errored between step 2 and the outcome classification (tick only re-selects `Pending`) — the exact stuck-state the refactor was meant to preclude. **Closed** by mandating a whole-span error guard (any thrown error after `Pending→InFlight` → `InFlight→Pending`), plus an optional staleness-sweep backstop. IMPORTANT: B-F2 (`currentDeathRecord` clear-on-removal had no implementation site → named the `PlayerRemoving` teardown bullet); B-F3 (`nextDeathEventId()` counter + `lastServerTrackedPosition` referenced but undeclared → defined both in bootstrap init); B-F4 (no AC asserted the `currentDeathRecord` clear → added a THEN clause to H.22e). All closed.

### Next
**Round-10 = full 7-spec `/design-review` in a fresh `/clear` session. DO NOT predict APPROVED for round-10.** Binding bar from round-8 CD still stands: if round-9's "fifth-flag" test had answered "a new free boolean, clear-path TBD," architecture reconsideration would trigger at round-10 — it did NOT (the state record passed the bar), so the reprieve is earned, but round-10 is a fresh adversarial gate. Themes 2/3/4 + OQ.3 (Camera GDD) remain PENDING until round-10 APPROVED.

### Files Modified This Session
- `design/gdd/player-controller.md` — round-9 structural authoring pass applied across C.5.3 (state-record refactor), C.5.8 (RunEnded arbiter), C.6 (T5/T6/T7/T8), C.9 (B3/I1/I4), E.E, F.4 (CONV-2/B5 latch/B-AI-2/B4), G.6 (coupled-knob + gate comparators), V/A.3/V/A.4 (CONV-3c/F2/F3), Section H (H.22b/d/e/f, H.28, H.35–H.43 reworked + H.44/H.45/H.46 new), header status block. Both narrow gates' findings closed inline.
- `design/gdd/reviews/player-controller-review-log.md` — this round-9 entry.
- `design/gdd/systems-index.md` — PC row → round-9 applied (Status stays MAJOR REVISION NEEDED — round-10 is the gate).
- `production/session-state/active.md` — refreshed to round-9-complete / round-10-pending.

---

## Review — 2026-06-08 — Round-10 (binding gate; first fresh full 7-spec panel against the round-9 DeathCostReconciliation refactor) — Verdict: NEEDS REVISION

**Scope signal:** M trending L (producer should verify before sprint planning). Round-11 = a CD ruling session + ONE authoring pass + ONE re-scoped narrow gate; the full 7-spec panel is reserved for round-12 as the closure gate.
**Specialists:** game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead, gameplay-programmer (build-from-artifact lens), creative-director (senior synthesis). 7 lenses spawned in parallel adversarially; CD synthesized.
**Blocking items:** ~10 BLOCKING clusters | **Recommended:** ~15 IMPORTANT | **Nice-to-have:** several
**Prior verdict resolved:** Yes — the round-9 structural authoring pass (DeathCostReconciliation state-record refactor + ~14 round-8 BLOCKING) was confirmed applied. This is a genuine fresh full panel against the materially-changed GDD. Round-8 qa items VERIFIED CLOSED (H.41 now a genuine binary signal, H.42 relabeled MANUAL, H.28 exercises the reconciliation scan).
**Review depth:** full (7 lenses + CD synthesis).

### The DO-NOT-predict-APPROVED caution held — but the texture is the healthiest in 10 rounds
Round-10 returned NEEDS REVISION (the empirically-expected non-APPROVED). Beneath it: the spine is verified sound on three independent axes and the defect surface is migrating OUTWARD to the seams.

### Architecture-reconsideration ruling: NOT triggered; fifth-flag bar PASSED and retired for the death-cost record
The round-8 binding bar measured one thing — can a new lifecycle concern be bolted onto the death-cost surface as a free boolean with no clear path? The round-10 build-from-artifact lens re-confirmed BUILDABLE-WITH-FIXES + fifth-flag PASS: the two new build BLOCKING are undeclared **scalars** (`lastTickTime`, a dispatch timestamp), not sticky booleans. The `DeathCostReconciliation` record's transitions are complete. **CD ruling: the new defect cluster (the `predatorCausedImminent` latch) is provably OUTSIDE the record's abstraction scope** — it is a PredatorService-owned predicate input introduced by the round-9 B5 user-ruling, found by a fresh adversarial gate doing its job ("the next ring," not a missed sweep). Class-name identity ≠ scope identity. A recurrence *inside* the record's surface fails the bar; a recurrence *outside* it is the next ring — cured with the same medicine the record got (name its states, mandate every transition's clear-watcher, assign PredatorService the binding F.4 obligation), NOT a re-architecture.

### What the panel confirmed genuinely CLEAN
- **Build:** state machine complete; the round-9 whole-span error guard is correctly placed INSIDE the `task.spawn` body (the pcall catches the spawned coroutine's throws), so the "stuck-InFlight cannot exist" claim is TRUE — no sibling hole.
- **Network:** server-authority + cost-attribution chain intact; deathEventId keying holds; no forge/DoS regression in the core machinery.
- **Systems:** D.1–D.6 boundary-checked degenerate-free; D.5 30s trace arithmetically correct row-by-row.
- **qa:** the four round-8 qa BLOCKING all verified closed.

### Round-10 BLOCKING clusters
- **(a) `lastTickTime`/`_lastReconcileTick` uninitialized [systems B4 + build B2 — DOUBLE, clean show-stopper].** The tick gate reads `(now − lastTickTime)` but the symbol is never declared/seeded in bootstrap → first-Heartbeat `now − nil` arithmetic crash kills the entire reconciliation tick (the whole Pillar-2 safety net) for the server session. One-line fix.
- **(b) `:ReleasePredatorLock(player)` missing from C.5.3 step-5 enumeration [systems B6/B9 + ai].** Present in the C.6 T5 row + F.4 but absent from the (a)–(f) block the implementer copies. Add as row (g), both paths.
- **(c) Arm-3 latch lifecycle cluster [network 2.1 + ai + qa — round-9's own headline fix spawned this round's headline].** N-F1 HP-recovery watcher mis-specified (a `HealthChanged` clear with no `>= HP_IMMINENT_THRESHOLD` guard clears on every sub-threshold hit); permanent-latch over-charge tail (fires on a disconnect after long pure-oxygen draining — weak attribution the GDD doesn't acknowledge); latch Race-2 re-opens Scenario C entirely (it inherited the timestamp's race without the timestamp's mitigation).
- **(d) RunController arbiter + T7/T8 [game B3/B4 + network 6.1 + qa — TRIPLE].** PC correctly raises-not-broadcasts (B4 single-owner landed), but the arbiter has no provisional contract and T7 (whole-squad-wipe) + T8 (S4-player rescue) have ZERO covering ACs (flagged round-1, still open). Caller owns the contract.
- **(e) Double-deduct race [network 1.3].** Path A commits, removes the row, clears `currentDeathRecord[player]=nil`; Path B then arrives, sees nil, mints a NEW deathEventId → second deduction. Needs a terminal-record guard before Path B mints.
- **(f) Reconciliation-success (a)/(b) pulse-timer-stop unverified [qa] + H.8 tests the wrong regen-delay boundary (proves `>=` not the documented strict-`>`) [systems] + caption queue/priority for simultaneous multi-death unspecified → WCAG floor regression [audio].**
- **(g) Staleness-sweep reads a dispatch-timestamp field the record schema doesn't carry [build B1 + systems].** Add `dispatchedAt` to the record, set at the Pending→InFlight transition.
- **(h) H.22b/H.22d/H.22f/H.44 missing the C.11 Lemur-caveat label [qa].** Same `PlayerRemoving` instance-lifecycle path round-8 flagged for H.36/H.38/H.39.

### Specialist disagreement (CD-resolved)
network 1.1 ("error guard must be the first statement inside `task.spawn` or a pre-pcall throw strands the row") vs build N1 (traced the skeleton; the guard IS inside the spawned body → stuck-InFlight-impossibility is TRUE). **CD resolved in build's favor** — network's point downgrades to an IMPORTANT hardening preference. The "staleness-sweep MUST not MAY" half stands as IMPORTANT.

### CD design rulings R10-1..R10-6 (lock before round-11 authoring; user owns R10-1 + R10-6)
- **R10-1 (USER)** — arm-3 permanent-latch vs time-bounded → recommend a long outer staleness ceiling (`LATCH_MAX_AGE ≈ 120s`, range 60–180s) capping the weak-attribution over-charge tail without re-opening Scenario C. Alternative: pure-permanent, accepting the over-charge tail as the symmetric price (must be stated, not left unacknowledged).
- **R10-2 (CD)** — latch Race-2 → CLOSE by inheriting the `lastPredatorDamageTimestamp` mitigation (cache-first read [already done] + the `task.defer` no-op-if-replaced instance-key guard).
- **R10-3 (CD)** — double-deduct race → CLOSE via a terminal-record guard: Path B's mint gates on "no Committed/InFlight record for this player's current life," not just a live pointer.
- **R10-4 (CD)** — silence-at-vanish-time → make it intentional AND stated (Pillar 3 — the squad notices the absence); enforce nil-position caption/audio parity; author the multi-death caption queue+priority+hold-time rule (WCAG; deferred since round-1 U3/Ac3).
- **R10-5 (CD)** — RunController → author the caller-side provisional contract NOW (`RunEndConditionRaised(conditionType, squadState)` + victory-T8-over-wipe-T7 precedence) so the arbiter conforms to PC; add the T7/T8 ACs against it.
- **R10-6 (USER)** — stationary-sprint Pillar-1 policy → recommend floor-and-feel (cost = the act of holding sprint, not displacement; kills the 0.03 stealth-sprint micro-exploit). Alternative: disallow/auto-revert stationary sprint. Genuine design fork touching the core fantasy + mobile-input story (game I6).

### Senior Verdict (creative-director)
> NEEDS REVISION (not MAJOR; not APPROVED). Scope M→L. Architecture reconsideration NOT triggered; fifth-flag bar PASSED and retired for the death-cost record. The recurrence is the next ring (the latch seam the round-9 B5 ruling introduced), not whack-a-mole — rounds 1–8 the recurrences were INSIDE the core cost-attribution machinery; round-10 that machinery is verified clean on three axes and the live defects have migrated OUTWARD to the seams (predator-side wiring, an undeclared tick scalar, a forward-system arbiter contract, missing ACs on already-correct rules). That is the signature of a GDD approaching done. Not MAJOR because there is no methodology failure and no unsound spine. Not APPROVED because six BLOCKING clusters remain, including a clean show-stopper (the uninitialized tick scalar) and a Pillar-1 fantasy question (R10-6). **New round-11 binding bar: if the `predatorCausedImminent` latch can be left in any state with no specified clear-watcher after round-11, that holds the verdict — the latch must leave round-11 with the same lifecycle rigor the record got.** If round-11 lands these seams cleanly, round-12 is a credible APPROVED.

### Recommendation
User chose **Stop here — apply round-11 in a fresh `/clear` session** (matching the established PC patch cadence + the context-management "one heavy surface per session" rule). Binding plan: round-11 CD ruling session (lock R10-1..R10-6) → ONE authoring pass (trivial-first sweep: `lastTickTime` bootstrap, `:ReleasePredatorLock` enumeration, (a)/(b) + T7/T8 ACs; THEN the heavy seams: latch state-discipline, double-deduct guard, caption queue, RunController contract — do NOT co-resident) → ONE re-scoped narrow gate (build transition-completeness + network re-confirm), NOT a full panel → then a round-12 full `/design-review` closure gate. **DO NOT predict APPROVED for round-12.** Themes 2/3/4 + OQ.3 (Camera GDD) remain out of scope and PENDING until round-12 verdicts APPROVED.

### Files Modified This Session
- `design/gdd/reviews/player-controller-review-log.md` — this round-10 entry appended.
- `design/gdd/systems-index.md` — PC row updated with the round-10 verdict + the CD round-11 prescription (Status stays MAJOR REVISION NEEDED — round-10 is the gate, round-12 is the closure gate).
- `design/gdd/player-controller.md` — NOT modified (read-only review).
- `production/session-state/active.md` — to be refreshed to round-11-pending state.

---

## Review — 2026-06-09 — Round-11 (full 7-lens panel, run against the UNMODIFIED round-9 disk artifact per user choice) — Verdict: NEEDS REVISION

**Scope signal:** L (multi-system cost-attribution + cross-GDD contract + accessibility; 6 formulas; RunController ADR still owed).
**Specialists:** game-designer, systems-designer, network-programmer, ai-programmer, audio-director, qa-lead, build-from-artifact (general-purpose) + creative-director (senior synthesis). **All 7 lenses + CD delivered natively (zero re-spawns).**
**Blocking items:** 12 BLOCKING clusters (10 re-confirming round-10 (a)-(h) + 5 NEW seam-level findings; some overlap) | **Recommended:** ~18 IMPORTANT | **Nice-to-have:** several
**Prior verdict resolved:** No — the GDD is byte-unchanged since the round-9 DeathCostReconciliation refactor; the CD-prescribed round-11 **authoring pass had NOT been applied**. The user invoked `/design-review` on Player Controller anyway (warned it would largely re-confirm round-10). The panel re-confirmed all round-10 clusters AND surfaced 5 new seam findings. Status remains **MAJOR REVISION NEEDED**.
**Review depth:** full (7 specialists spawned in parallel adversarially, then creative-director synthesis).

### Summary

Run against the unmodified round-9 artifact, so re-confirmation of the round-10 clusters was the expected floor — the panel met it and exceeded it with 5 NEW findings that justify having run it.

**Re-confirmed round-10 clusters (a)-(h):** (a) `lastTickTime` uninit [build+systems+network triple-lens — show-stopper]; (b) `:ReleasePredatorLock` absent from C.5.3 step-5 enum [systems+ai]; (c) arm-3 HP-recovery watcher unguarded/un-deploy-gated [network+ai+qa]; (d) RunController arbiter contract undefined + T7/T8 zero ACs [game+qa+network]; (e) double-deduct [network — now a traced reproduction]; (f) H.8 wrong regen comparator + multi-death caption queue [systems+qa, audio]; (g) staleness-sweep reads undeclared schema field [build]; (h) reconciliation-recovery silence/caption-parity [audio].

**5 NEW seam-level findings (what round-10 missed):**
1. **GD-02 [cross-GDD, VERIFIED]** — PC's T8 victory subscribes to `OnEscapeBeaconActivated()` (activation edge), but `crafting-and-items.md` (round-2) explicitly designates `OnBeaconWindowSurvived` (BCT4) as "PC's T8 victory subscription" and marks `OnEscapeBeaconActivated` "**NOT** the victory trigger." PC would declare victory the instant the beacon lights, bypassing Crafting's entire survival-window thesis. A regression where Crafting moved and PC didn't follow.
2. **N-2** — double-deduct traced concretely: step-5 success sets Committed -> removes row -> clears pointer; a replayed `Humanoid.Died` (C.5.2 admits it fires twice) then mints a fresh `deathEventId` -> second squad-oxygen deduction.
3. **N-3** — arm-3 has no recency check, so Race-2 lets H.44 (auto-integration AC) pass in controlled-order test and fail in production.
4. **AI-3** — `lastServerTrackedPosition` not in the T6 respawn clearance list -> predator can read a 30s-stale death-point position. A3 closed for death, not respawn.
5. **SD-B4** — the whole-span error-guard claim ("ANY error rolls InFlight->Pending") contradicts step-5's commit-before-side-effects ordering: the row is Committed+removed before T5 side-effects run, so a side-effect error has no InFlight row to roll back to.

**Confirmed CLEAN / PROTECT:** network authority + cost-attribution chain re-confirmed SOUND (no client forge path on `deathEventId`/record/`RequestSquadOxygenSpend`) — ~11th round, PROTECT. Formula boundary sweep D.1/D.2/D.6 clean; D.5 30 s trace re-verified line-by-line CLEAN. Build: 4-state transitions complete, InFlight double-dispatch guard no off-by-one, error guard correctly placed inside the `task.spawn` body, no forbidden patterns. OQ.1 footstep perception boundary CONFIRMED CLEAN (audio).

### Senior Verdict (creative-director)

> NEEDS REVISION; status holds at MAJOR REVISION NEEDED. The show-stopper (`lastTickTime`) is a one-line bootstrap **omission**, not a logic defect; the authority chain re-confirmed SOUND; and every NEW finding lands at the seams (cross-GDD boundary, replay/race edges, respawn flush, a step-5 ordering statement) — none recur inside the `DeathCostReconciliation` record abstraction. **Governance: next-ring UPHELD, fifth-flag bar PASSED, NO re-architecture.** The arm-3 latch recurrences live in PredatorService/heal-path territory outside the record's enclosed surface = next ring, cured with one ruling, not a treadmill. SD-B4 is the closest to an internal inconsistency but is a prose/ordering defect (fix the order, the abstraction is coherent), not a structural flaw.

### CD Design Rulings Locked (R11-D1..D5 — user may override)

- **R11-D1** — Re-point T8 from `OnEscapeBeaconActivated()` to Crafting's window-survived emit `OnBeaconWindowSurvived` (BCT4). VERIFIED against `crafting-and-items.md` C.9. PC owns conforming to Crafting's caller contract; no prereq review on Crafting.
- **R11-D2** — Close N-2 + SD-B4 **together**: **retain the Committed row** until T6/PlayerRemoving (rather than a `lastCommittedDeathEventId` guard) — it gives a replayed `Died` a Committed row to short-circuit against AND gives the error guard something to roll back to. Reorder step-5 so side-effects run before row removal, OR explicitly scope the guard to the pre-removal span; the guarantee prose MUST match the order.
- **R11-D3 (USER-OWNED — still open)** — Stationary-sprint vs Pillar 1 (R10-6). The fork: (a) floor-and-feel (stationary sprint produces a real disturbance pulse) vs (b) min-magnitude floor (clamp to tiny non-zero, effectively free). CD recommends (a) — Pillar-1 honesty — but this is the user's vision call.
- **R11-D4** — audio-director authors the multi-death caption queue (order = death-event timestamp; explicit hold-time; dedup by `deathEventId`; polyphony cap with overflow->caption-only). Authoring task, not a fork.
- **R11-D5** — STATE the reconciliation-recovery silence as intentional AND require caption parity: "[Name] is down" caption fires regardless of the nil-position SFX suppression. No fork.

### Round-11 Prescription (UNCHANGED in shape; gate scope widened)

CD ruling session (lock R11-D1..D5 + R10-1..R10-5) -> **ONE authoring pass**: Phase 1 trivial sweep first (Tier-0 `lastTickTime` init; schema-field declarations; H.8 comparator flip; missing-AC stubs), Phase 2 heavy seams **separate/NON-co-resident** (Tier-1 cost-attribution N-2/SD-B4 ordering + arm-3 gated watcher/deploy-gate/recency; Tier-3 RunController contract + GD-02 re-point; Tier-4 audio) -> **TWO narrow gates**: (1) build-from-artifact re-scoped (lastTickTime init, schema fields, enum/arity) + (2) **network re-confirm** (verify the retain-row fix closes N-2, arm-3 recency holds, authority chain still SOUND post-edit). Full 7-lens panel reserved for **round-12 as the closure gate**. **DO NOT predict APPROVED for round-12.**

### Round-11 BLOCKING — ranked authoring queue

- **Tier 0:** (1) `lastTickTime` bootstrap omission [build-F1 / SD-B1 / N-4].
- **Tier 1:** (2) N-2 double-deduct + (3) SD-B4 error-guard ordering [R11-D2, one fix]; (4) arm-3 watcher deploy-gate + threshold guard + recency [N-1 / AI-2 / N-3 / qa].
- **Tier 2:** (5) `:ReleasePredatorLock` into C.5.3 step-5 enum [SD-B2 / AI-1]; (6) staleness-sweep schema field [build-F2]; (7) `lastServerTrackedPosition` into T6 clearance [AI-3].
- **Tier 3:** (8) GD-02 T8 re-point [R11-D1]; (9) RunController provisional contract + N-6 defeat-hold window + T7/T8 ACs [GD-01 / qa / network]; (10) H.8 comparator + 4 missing-AC gaps + QA-NEW-1/2/4/5 [systems / qa].
- **Tier 4:** (11) multi-death caption queue + polyphony [AD-1 / R11-D4]; (12) reconciliation-recovery silence + caption parity [AD-2 / R11-D5].

### Specialist Disagreements

None substantive. All 7 lenses converged on NEEDS REVISION. Build returned BUILDABLE-WITH-FIXES (both BLOCKINGs are the `now-nil` arithmetic class — mechanical); network re-confirmed authority SOUND (PROTECT) — scoped soundness confirmations, not disagreements with the verdict.

### Files Referenced (round-11 review)

- Target: `design/gdd/player-controller.md` (1157 lines; unchanged round-9 artifact).
- Cross-verified: `design/gdd/crafting-and-items.md` (C.9 `OnBeaconWindowSurvived` vs `OnEscapeBeaconActivated` — GD-02 confirmed).
- Cross-cited: `design/gdd/game-concept.md`, `design/gdd/systems-index.md`, `docs/engine-reference/roblox/VERSION.md`.

### Files Modified This Session

- `design/gdd/reviews/player-controller-review-log.md` — this round-11 entry appended.
- `design/gdd/systems-index.md` — PC row updated with the round-11 verdict + R11-D1..D5 rulings (Status stays MAJOR REVISION NEEDED).
- `design/gdd/player-controller.md` — NOT modified (read-only review).
- `production/session-state/active.md` — refreshed to round-11-complete / round-11-authoring-pending state.

---

## Authoring Pass — 2026-06-09 — Round-11 (applies the round-11 panel findings; a PATCH, not a verdict)

**This is the CD-prescribed round-11 authoring pass** that closes the round-11 full-panel NEEDS REVISION (above). It is NOT a verdict — the round-12 full 7-lens `/design-review` is the binding gate. **DO NOT predict APPROVED for round-12.** GDD modified; review-log + systems-index + active.md updated. NOT committed (branch `crafting-round2-patch`).

### Two user-owned forks resolved (2026-06-09, both CD-recommended option)
- **R10-6 / R11-D3 — stationary-sprint** → **floor-and-feel**: `magnitude = max(SPRINT_HOLD_FLOOR, computed)`, Sprint axis only, `SPRINT_HOLD_FLOOR = 0.06` (60% of full; stationary sprint 0.03→0.06; kills the near-free stealth-sprint read, preserves moving>holding gradient). **ED-registry-owned** (emission magnitude per G.7) → F.4 forward obligation to ED + provisional reference in PC.
- **R10-1 — arm-3 latch lifetime** → **outer staleness ceiling** `LATCH_MAX_AGE = 120 s` (range 60–180; renewed on each qualifying predator hit; bounds the weak-attribution over-charge tail without re-opening Scenario C, which needs >30 s).

### Tier 0–4 BLOCKING queue — all applied
- **Tier 0** — `lastTickTime` bootstrap seeded to `getServerTime()` + set each scan (C.5.3 Bootstrap; H.40 strengthened). **Show-stopper closed.**
- **Tier 1a** — N-2 + SD-B4 [R11-D2]: success path → `Committed` → broadcast + side-effects → **retain row + `currentDeathRecord` pointer until T6/PlayerRemoving** (replayed-`Died` resolves the retained record, no-ops; closes the double-deduct). Error guard **scoped to the InFlight window** (post-`Committed` errors logged, never rolled back; closes the re-deduct hazard). Orphaned-row exception for a reconciliation-tick commit with no live pointer. Termination/T6/teardown/E.E + H.22e/H.37/H.39/H.41 reconciled to the retain-then-remove model.
- **Tier 1b** — arm-3 [R10-1/N-1/AI-2/N-3]: `LATCH_MAX_AGE` ceiling conjunct on a new `predatorCausedImminentSetTimestamp` (`~= nil`-guarded); F.4 HP-recovery watcher made **deploy-gated** (dormant until a heal path exists; named obligation) + **threshold-guarded** (clears only on crossing back `≥ HP_IMMINENT_THRESHOLD`, never on intra-band `HealthChanged`); H.44 annotated with the Race-2 production caveat + ceiling paired-negative; G.6 knob registered; E.E ceiling note.
- **Tier 2** — `:ReleasePredatorLock` added to the C.5.3 step-5 side-effect enum (g), both paths + reconciliation-success subset [SD-B2/AI-1]; `inFlightSince` declared in the record schema, set at `Pending→InFlight`, cleared on rollback, read by the staleness sweep [build-F2]; `lastServerTrackedPosition` reset to the respawn anchor on T6 [AI-3]; **H.8** boundary aligned with D.2 strict `>` (advance past 1.5 s).
- **Tier 3** — **GD-02 T8 re-point** `OnEscapeBeaconActivated → OnBeaconWindowSurvived` (BCT4) across C.6/C.5(rule 8)/C.10/F.2/F.4 [R11-D1]; `RunController:RunEndConditionRaised(conditionType, squadState)` caller-side provisional contract + victory-over-wipe precedence + **`RUN_END_DEFEAT_HOLD` defeat-hold window** (N-6) [R10-5]; new T7/T8 ACs **H.47–H.51** (+ `:ReleasePredatorLock` AC).
- **Tier 4** — multi-death **caption queue V/A.4a** (order by death-event timestamp; 3 s hold; **dedup by `deathEventId`**; overflow→caption-only) + **Death-SFX polyphony cap** `DEATH_SFX_MAX_VOICES` (V/A.3) [R11-D4]; **nil-position caption parity** ("[Name] is down" fires even when positional SFX suppressed) + reconciliation-recovery silence stated intentional (Pillar 3) [R11-D5]; ACs **H.52/H.53**.

### Two narrow gates (CD-prescribed) — BOTH GREEN
- **Build-from-artifact (re-scoped, general-purpose agent): BUILDABLE.** All 7 edit-clusters CONFIRMED wired/declared/arity-consistent; Tier-0 show-stopper confirmed closed; retain-row lifecycle traced with no stranded-row path; no stray `OnEscapeBeaconActivated`-as-victory, no leftover Sprint-stationary `0.03` emitted value, no undeclared-field read, single `isImminentDeath_cached` call site (5-arg) — no arity mismatch. 2 non-blocking doc-anchor nits (C.5-rule-8 method-name echo — **fixed**; "C.5.8" dotted-ref — left, it is the doc's established `C.5.N`=rule-N convention, identical to the 30+ `C.5.3` uses).
- **Network re-confirm (network-programmer): AUTHORITY CHAIN SOUND.** All 3 seams CONFIRMED — retain-row closes N-2 (exactly one deduction per death event; error guard correctly InFlight-scoped); arm-3 ceiling is a conjunct that strictly narrows toward under-charge (no new over-charge/forge path; Race-2 accepted-under-charge honestly annotated); GD-02 re-point preserves the single-broadcaster invariant and removes the "victory on beacon-light" bug. **PROTECT re-confirmed SOUND (~12th round): no client forge path on `deathEventId` / record state / `RequestSquadOxygenSpend`.**

### Counts / deltas
ACs added: H.47–H.53 (run-end T7/T8, `:ReleasePredatorLock`, caption dedup, nil-position parity). New knobs: `LATCH_MAX_AGE` (G.6), `SPRINT_HOLD_FLOOR` (G.7, ED-owned), `RUN_END_DEFEAT_HOLD` + `DEATH_SFX_MAX_VOICES` (provisional, owner-flagged). New record field: `inFlightSince`. New PredatorService obligation: `predatorCausedImminentSetTimestamp` + deploy-gated/threshold-guarded HP-recovery watcher. New caller-side contract: `RunController:RunEndConditionRaised`.

### NEXT
Round-12 full 7-lens `/design-review` (closure gate) in a fresh `/clear` session. **DO NOT predict APPROVED for round-12.** Open forward obligations created: ED owes `SPRINT_HOLD_FLOOR` registry add; RunController (unauthored) owes the `RunEndConditionRaised` arbiter + `RUN_END_DEFEAT_HOLD`; HUD owes the reconciliation-recovery / `OnPlayerStatusUnknown` / multi-death-caption UX; heal-feature author owes the deploy-gated latch-clear watcher.

### Files Modified This Session
- `design/gdd/player-controller.md` — round-11 authoring pass applied (header status + Tier 0–4 + R10-1/R10-6/R11-D1..D5).
- `design/gdd/reviews/player-controller-review-log.md` — this round-11 authoring-pass entry.
- `design/gdd/systems-index.md` — PC row updated (round-11 authoring applied; status stays MAJOR REVISION NEEDED until the round-12 gate).
- `production/session-state/active.md` — refreshed to round-11-authoring-complete / round-12-pending.

---
