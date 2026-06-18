# Resource Node — Review Log

Revision history for `design/gdd/resource-node.md`. Most recent entry first.

---

## Revision — 2026-06-17 — Round-4 (CD prescription: ruling session → one authoring pass → two narrow gates)
Executed the round-3 CD prescription verbatim (NO fresh full panel). **4 user/CD rulings** applied: (1) **pin cap=2** — `CRAFT_CONCURRENCY_CAP = min(2, ceil(squad/2))`; D.1a "2 players → 2 slots → 3.33 u/s" was wrong (2p = cap 1); the floor assert pins cap=2 as the full-squad worst case (conservative, squad-size unknown at KnitInit). (2) **decouple positionAtArm** — `firstArmTimestamp` FROZEN at first entry (hold-bypass defense), `positionAtArm` REFRESHED every in-range 10 Hz tick (teleport reference); kills the legal walk-out-and-back false-reject without weakening the same-frame teleport guard. (3) **synchronous runActive re-check in T2** — step-(0) re-read of `runActive` + `node.state=="Gathering"` as the literal first non-yielding line of resolve; makes same-tick T2-vs-run-end safe and T2-vs-T3 order-independent; new H.37. (4) **strike D.4/skill-loop overclaims** — cut "races the predator" (D.4) + "expert at being small" mastery-loop (Player Fantasy) as unauthored-ED/Predator overclaims; H.29a reframed from an H.4 restatement into a genuinely independent RELATIONAL invariant.

**~7 mechanical blockers also applied:** #2 yield-domain guard (yields ≥ 1 + all respawns > 0 as init invariant 0; div-by-zero + vacuous-H.30 closed; every "13" relabeled "at defaults"; cap floats with `OXYGEN_DRAIN_BC3`); #3 `ResetAllNodes()` full spec (token-bump → release → Available → snapshot, non-yielding); #6 H.9 reframed (runtime EXCLUSIVITY outcome + no-yield as code-review/lint static obligation); #7 AC defects (H.1 all 9 NodeRecord fields incl. new `lockTimestamp`; +H.38 Gathering payload; H.31 Logic→Integration; H.32 Security→Logic; named H.15/H.28 stub seams); #9 UX (hands-free in-range tether, T3 pre-cancel warning, gamepad parity, binding aggregate-WCAG-flash); #10 audio (source dBFS authoritative / carry distances derived; "resonant hum"→low-mid >500 Hz; **shimmer ducks 8–12 dB in Hunt, NOT silence** — preserves Beat-1 advertise affordance); #11 PointLight cap scoped to RN's own node lights + emissive fallback, aggregate budget handed to tech-art (OQ.12). Key RECs: `lockTimestamp` added to NodeRecord; OQ.3 tax arithmetic fixed (~1.5% vs RM's ~68-Canister demand, not 7–13%); H.30 "co-primary vs backstop" reconciled; H.11 ≤100 ms latency assertion.

**Reconciliation-fanout checklist (mandatory, the recurring defect class):** grep-swept every touched token. Caught one genuine stale sibling in-pass — the audio-budget line still said the shimmer "silences in Hunt" (contradicting the duck change) — and fixed it. Confirmed cap, positionAtArm, runActive, "13", D.4/skill-loop, co-covered all reconciled.

**Two narrow gates (NOT a full panel):**
- **network-programmer (spine re-confirm) → SPINE SOUND.** positionAtArm decoupling PASS with explicit slow-drift exploit reasoning (self-limiting via the independent commit-time proximity gate); all 6 spine items SOUND (authority / emit-before-grant / single client event / attribution incl. server-set `lockTimestamp` / rate limit / ResetAllNodes race-safety); zero new network defects; E.9 honesty caveat intact.
- **systems-designer + qa-lead (decisive) → RESIDUE.** All 7 round-3 systems blockers + 6 qa items (A–G) CLOSED. **qa independently recounted AC = 42 = 38 BLOCKING + 4 ADVISORY — header arithmetic CORRECT.** Residues, all fixed in-session + self-verified: T3 table row didn't clear the arm record (stale sibling vs CR.4 step 1/H.24/T4 — fixed; also propagated to T5 for consistency); H.30 co-primary/backstop label reconciled to one authoritative framing; domain guard extended to Medium/Heavy respawn; H.37 Case B/C spy-coverage + both-orderings harness specified; H.38 `extractionStartTimestamp == lockTimestamp` equality pinned (drift ambiguity closed); shimmer-duck advisory Feel evidence gate noted.

**Net result:** round-3's defect character (reconciliation/propagation tails) held — the gates found doc-integrity residue, not design failure; spine SOUND a 4th consecutive round; thesis intact. **Status:** pending fresh-session round-5 verdict (or user commit). **DO NOT predict APPROVED for round-5.** Not committed (branch `crafting-round2-patch`).

---

## Review — 2026-06-17 — Verdict: NEEDS REVISION (round-3)
Scope signal: L (unchanged)
Specialists: economy-designer, game-designer, systems-designer, network-programmer, gameplay-programmer (Roblox/Luau feasibility), qa-lead, ux-designer, audio-director, performance-analyst, creative-director (senior synthesis)
Depth: full (9-agent adversarial panel + senior synthesis)
Blocking items: ~11 | Recommended: ~25 | Nice-to-have: several
Prior verdict resolved: Yes — round-2 NEEDS REVISION. Round-2's structural fixes confirmed CLOSED (false "always a countdown" headline gone; RESONANT-as-risk coherent). Defect class narrowed one more ring: round-1 structural → round-2 calibration → round-3 reconciliation + interface-completeness + test-harness precision.

**Completeness:** 8/8 sections (+ Visual/Audio, UI, Open Questions). AC count independently verified consistent: 39 = 36 BLOCKING + 3 ADVISORY (H.18 redirect-stub excluded; ADVISORY = H.26/H.27/H.36). **Dependency graph:** ED/Crafting/PC/RM exist (RM APPROVED, D.6 invariant cited correctly); Predator AI + HUD do not (correctly forward-pending).

**Spine SOUND a 3rd consecutive round** — network (authority / single client event / emit-before-grant / firstArm anchor / teleport-delta) and performance (10 Hz all-pairs arm-scan ~2,400 tests/s; bandwidth ~0.23 KB/s Beacon-push worst case; no 60 Hz hot path) both re-confirmed independently.

**~11 BLOCKING (decisive first):**
1. `CRAFT_CONCURRENCY_CAP` squad-size conflation re-entered on RN's primary floor invariant — D.1a "2 players → 2 craft slots → 3.33 u/s" needs a 3–4 player squad (2-player cap=1 per RM); H.12 treats cap as static=2 without pinning it as the full-squad worst case (squad size unknown at KnitInit). Same class RM corrected in RBI-3. [economy, systems]
2. Yield-domain cluster — `NODE_YIELD_LIGHT=0` → div-by-zero in D.1b cap + H.30 passes vacuously; no init guard; "13 Light nodes" headline slides with RM's `OXYGEN_DRAIN_BC3` (1.8–2.8 → cap 10.8–16.8); "1–2" safe range misleading (yield 2 breaks H.12). [systems]
3. `ResetAllNodes()` referenced (T6/E.14) but never specified — reset-state, broadcast, sync/yield, lock-release-vs-token-increment ordering. [systems]
4. `positionAtArm`-on-rearm behavior unspecified — if frozen at first detection, legal walk-out-and-back triggers FALSE out-of-range rejects (teleport-delta vs stale anchor). [network]
5. Same-tick run-end-wins rule asserted but not mechanized — T2 `task.delay` callback may fire before RunEnded sets `runActive=false` same Heartbeat → grant issues; needs synchronous re-check + AC. Also leaves T2-vs-T3 same-tick undefined. [systems ×2, qa, gameplay, perf]
6. H.9 still not implementable / proves wrong thing — yield-injection sub-test proves harness sensitivity not production non-yielding; "stepped once" no defined Luau/Lemur scheduler interface; sub-test no GIVEN/WHEN/THEN. Reframe as language-invariant + code-review/linter. (2nd round on H.9.) [gameplay, qa]
7. AC defects — H.31 mislabeled Logic→Integration (same fix H.24 got); H.32 Security→Logic; H.1 asserts only 3 of 7 NodeRecord fields; no AC for Gathering broadcast payload; no AC for T2/T4 same-tick rule; H.15 RunEnded API + H.28 mock-lantern seam unnamed though "stubbable." [qa]
8. Player-Fantasy overclaims leaked (F-A fork propagation) — D.4 "races the predator, exactly the intended Pillar 1/3 interaction" + closing "expert at being small" skill-loop; H.29a is H.4 restated ("co-covered"), not independent. [game-designer]
9. UX commit-and-wait gaps — hands-free invisible tether (no in-range indicator for ≤8.5 s; arm-ring persistence unspecified); T3 cancel no pre-warning (silent on mobile); "rate-limited → silent" reads as input failure; gamepad model unspecified; motion-reduction distinguishability + aggregate WCAG flash budget non-binding "e.g."/"may" prose, no AC. [ux]
10. Audio incoherence — dBFS ladder (−18/−13/−8) AND carry distances (15/25/35–40) both stated but mutually inconsistent under any rolloff; "resonant hum" contradicts 500 Hz floor; Heavy shimmer "silences entirely in Hunt" kills the advertise affordance during the Beacon-push (duck 8–12 dB or drop the Beat-1 claim). [audio]
11. Mobile ≤8-PointLight cap unowned/unenforceable — "inclusive of flora" claims a cross-system budget RN can't enforce; no owner, no AC, no SE-class derivation, no emissive-fallback trigger. [perf]

**Recommended (~25):** H.30 "co-primary" overstated (RM bench cap saturates ~10 nodes < 13); OQ.3 "dozen Canisters/7–13% tax" ~5× off vs RM's ~68-Canister demand (real ≈1.5%); explicit character+rootPart CR.5 stage + teleport-delta-before-arm-hold + arm hysteresis; `error()` in KnitInit doesn't abort server (specify kick-guard); client `GetServerTimeNow()` clock-offset drifts HUD; mockable scheduling-interface API undefined; `lockTimestamp` missing from NodeRecord type; H.11 missing ≤100 ms latency assertion; ~12-clip audio budget under-counts 8–16; document hands-free "held-breath" tradeoff + add node-legibility-at-distance AC; E.4 mid-extract phantom; D.1a mis-cites RM D.5/D.6.

**Specialist disagreement (CD-adjudicated):** game-designer raised Beat-1 cost-legibility-vs-restraint-experience as BLOCKING; CD declined — it re-derives RN's already-accepted F-A down-scope (a panel can't reopen a user-ruled fork). Logged as a playtest watch-item. (The *propagation* leaks of that fork — D.4 + "expert at being small" — remain blocking.)

**Senior verdict (CD):** NEEDS REVISION, held one notch below round-1. A converging GDD whose spine is confirmed sound a 3rd consecutive round; new blockers dominated by self-inflicted propagation tails of round-2's own fixes ("converged in substance, leaking in propagation"). **Prescription for round-4:** NO fresh full panel (it confirms, not finds) — short ruling session (pin cap=2; decouple positionAtArm; synchronous runActive re-check in T2; strike D.4/skill-loop overclaims) → ONE authoring pass with a mandatory reconciliation-fanout checklist → TWO narrow gates (systems/qa decisive + network spine re-confirm). **Do not predict APPROVED for round-4.** Completability gate stands (RN ≠ Done until ED Emit API, PC death-signal/lantern, RunEnded signals lock).

**Status:** User chose stop-and-revise in a fresh session. Not committed (branch `crafting-round2-patch`).

---

## Revision — 2026-06-17 — Round-2 blockers applied (one authoring pass, revise-now)
Applied in response to the Round-2 NEEDS REVISION verdict below, in the same session (user chose revise-now). Four design forks decided by the user (all the recommended option); the remaining ~24 blockers + key RECs applied mechanically. AC count **33 → 39** (36 BLOCKING + 3 ADVISORY), recounted and verified internally consistent.

**User design forks (4):**
- **F-A loud moment → HONEST PROSE.** No pre-Beacon RESONANT consumer (Crafting untouched). Player Fantasy rewritten in two beats: Beat-1 (RN-owned, deliverable now — the "advertise before you touch it" approach-decision is RN's restraint signal); Beat-2 (world's response — ED + Predator AI contingent, H.29b/OQ.1). Honest "quiet until the Beacon demands loud" framing.
- **F-B oxygen floor → ALIGN WITH RM D.6.** Dropped "always a countdown" for RM's "always trends toward a forced, loud finale"; full-squad BC1/BC2 net-positive-under-loud is INTENDED; RM's `CRAFT_CONCURRENCY_CAP` is the production backbone (≤1.67 u/s); RN's owned gates H.12 (per-cycle >9.09s) + H.30 (BC3 supply bound) are now **co-primary** (H.30 no longer "THE floor-bearing gate").
- **F-C arm scan → SIMPLIFY to 10Hz all-pairs.** Spatial grid removed entirely (perf: ~2,400 tests/s trivial at 2–4 players); CR.4/H.31/Tuning-Knobs de-gridded.
- **F-D hold model → COMMIT-AND-WAIT, HANDS-FREE.** 0.5s commit then hands-free; stay-in-range (T3 cancels). Pinned in CR.4 + UI.

**Other blockers applied:** CR.1 `--!strict` NodeRecord type; CR.5 full ordered validation chain + `firstArmTimestamp` anchor (H.32) + `GATHER_MAX_TELEPORT_DELTA` teleport-delta (H.34) + rootPart nil-guard; CR.4 ProximityPrompt-NOT-used + extraction watcher reuses 10Hz tick + pcall-of-non-yielding clarification; CR.7 `MIN_LIGHT_NODES=6`/`MIN_MEDIUM_NODES=4`/prefer ≥5 Heavy/`HEAVY_NODE_MIN_RESPAWN_STAGGER=15s`; States `OnNodeFullStateSnapshot` join bootstrap (H.33) + T5 state no-op + generation-token spec + same-tick T2/T4 run-end-wins + OnNodeStateChanged carries extraction timestamps; D.1 var-table 3.1→3.25; D.2 `min(P,n)>0` precondition + win-window claim → forward-pending + ≤1-adverse-node qualifier; H.9 rewrite (two real coroutines + yield-injection); H.6/H.19/H.20/H.21 injectable mock clock; H.18 redirect-stub; H.24 Logic→Integration; H.29 split → H.29a (testable now)/H.29b (forward-pending); H.12/H.22/H.30 `KnitInit` error + kick-guard (no Roblox "refuses to start"); +H.35 (CR.5 short-circuit order) +H.36 (reject-cue distinguishability, ADVISORY); completability gate note. Audio: 250→500Hz provisional protected floor (forward-pending Predator AI, OQ.11) + shimmer proximity-gate/Hunt-silence/voice-cap; Visual: segmented-ring motion fallback + PointLight ≤8 cap; UI: distinguishable reject cues + dark-zone precondition indicator + captions-required HUD bar; level-design flash flag → enforced stagger gate. OQ.2 reframe, OQ.9 ≥5, OQ.10 drop ProximityPrompt, +OQ.11.

**Status:** pending fresh-session round-3 re-review. Not committed (branch `crafting-round2-patch`).

---

## Review — 2026-06-17 — Verdict: NEEDS REVISION (round-2)
Scope signal: L (unchanged from round-1)
Specialists: economy-designer, game-designer, systems-designer, network-programmer, gameplay-programmer (Roblox/Luau feasibility), qa-lead, ux-designer, audio-director, performance-analyst, creative-director (senior synthesis)
Depth: full (9-agent adversarial panel + senior synthesis)
Blocking items: 28 | Recommended: ~20 | Nice-to-have: several
Prior verdict resolved: Partial — round-1 MAJOR REVISION NEEDED; of its 5 load-bearing issues, #3 (RESONANT scarcity) and #4 (arm-detection + 60Hz perf) genuinely fixed; #2 (forced loud moment) RELABELED not fixed; #1 (oxygen floor) partially fixed with a new self-inflicted defect; #5 (honesty) mostly fixed but H.9 determinism test itself broken + new unsourced invariants.

**Completeness:** 8/8 sections (+ Visual/Audio, UI, Open Questions). **Dependency graph:** ED/Crafting/PC/RM exist (RM APPROVED); Predator AI + HUD do not exist (correctly forward-pending).

**Senior verdict (CD):** Spine independently confirmed sound (network: authority/emit-ordering/single-event clean; perf: arm-scan/bandwidth/scheduler genuinely fixed). But round-1 #2 was relabeled (supply→risk) rather than redesigned — the loud act is still recipe-forced — and #1's fix derived the floor against the wrong drain band (BC3) while its own "always a countdown" headline is false at BC1/BC2 (contradicting APPROVED RM D.6). The floor defect changed character from structural (round-1) to calibration/reconciliation (round-2), and the spine no longer carries a second MAJOR-class axis → one notch below round-1, NEEDS REVISION not MAJOR. Only true design decision = the loud-moment fork (CD recommended honest prose). Do not predict APPROVED for round-3.

**Specialist disagreements:** None genuine. Productive tension: perf judged the round-1 spatial grid over-engineered (10Hz all-pairs equally cheap at 2–4 players) while gameplay flagged it under-specified — compatible (grid valid-but-not-required; resolved by simplifying to all-pairs).

## Revision — 2026-06-17 — Round-1 blockers applied (one authoring pass)
Applied in response to the Round-1 MAJOR REVISION NEEDED verdict below. The GDD was unrevised since that verdict (re-review would have reproduced the same 12 blockers), so a revision pass was run instead of a re-review. Three CD rulings were genuine design forks resolved by the user; the rest were applied mechanically.

**User design decisions (3 forks):**
- **RN-1 floor model → Sustained-faucet floor.** The real net-negative invariant is sustained BIOMASS-respawn throughput, not the per-cycle number; bursts are tolerated/intended.
- **RN-2 restraint legibility → Down-scope prose honestly.** RN owns the cost half only; restraint-reward is a forward obligation on unauthored ED + Predator AI.
- **RN-3 RESONANT scarcity → Risk bottleneck, not supply.** ≥4 Heavy nodes means respawn never binds; scarcity = exposure cost.

**Fixes applied:**
- **RN-1:** new D.1a (parallel-burst acknowledgment ~3.33 oxygen/s) + D.1b sustained-faucet floor (`lightNodeCount < 13.2` at defaults); per-cycle gate demoted to secondary; both init asserts read named constants incl. `NODE_YIELD_LIGHT`/`TAP_HOLD`. New **H.30** (floor-bearing sustained assert); **H.12** relabeled secondary; `NODE_EXTRACT_TIME_LIGHT` safe range corrected to state `TAP_HOLD` coupling (3.25–8.0).
- **RN-2:** Player-Fantasy pillar paragraph + downstream-obligation note down-scoped; new **H.29** (forward-pending on ED/Predator AI); OQ.1 rewritten.
- **RN-3:** CR.2 / D.2 / OQ.9 reframed to risk bottleneck; `NODE_RESPAWN_TIME_HEAVY` relabeled rarely-binds backstop.
- **RN-4:** CR.4 step 1 specifies server spatial-grid arm scan at `ARM_SCAN_HZ = 10` (no all-pairs poll); CR.4 step 3 + CR.6 mandate the non-yielding critical section as a hard contract; new `ARM_SCAN_HZ` knob; new **H.31**.
- **RN-5:** E.9 anti-forge claim corrected (root position is client-owned under default network ownership; hardening levers → OQ.10); Heavy idle hum re-spec'd to >250 Hz 3D `GatherSFX` shimmer; **AC count corrected 23 → 33** (31 BLOCKING + 2 ADVISORY); **H.9** made determinism-pinned; status header updated.

**Status:** pending fresh-session re-review. Not committed (branch `crafting-round2-patch`).

---

## Review — 2026-06-17 — Verdict: MAJOR REVISION NEEDED
Scope signal: L (upgraded from authoring-time S — parallel-floor re-derivation + per-node cost-legibility HUD/ED contract may require an ADR)
Specialists: game-designer, systems-designer, economy-designer, network-programmer, gameplay-programmer (Roblox/Luau feasibility), qa-lead, ux-designer, audio-director, performance-analyst, creative-director (senior)
Depth: full (10-agent panel + senior synthesis)
Blocking items: 12 | Recommended: ~30 | Nice-to-have: ~6
Prior verdict resolved: First review (no prior log)

**Completeness:** 8/8 required sections present (+ Visual/Audio, UI, Open Questions).

**Dependency graph:** ED / Crafting / PC / RM exist (RM APPROVED). Predator AI and HUD GDDs do NOT exist yet — RN's contracts to them are correctly marked forward-pending. PC reverse-cite (OQ.4) and RM stale "~8 s" provisional (OQ.7) correctly flagged.

**The 5 load-bearing issues (CD synthesis):**
1. **9.09 s `canisterCycleTime` floor genuinely breached at two independent points** (DECISIVE). (a) Safe-range minimums: `2×(0.3+3.1)+2 = 8.8 s < 9.09 s` — the `NODE_EXTRACT_TIME_LIGHT` safe range never states its `TAP_HOLD` dependency. (b) **Parallel-gather case:** D.1 models single-player *serial* production, but the system supports concurrent producers — 2 players feeding 2 bench slots → effective ~6.0 s cycle → 3.33 u/s > BC3 drain 2.2/s → "always a countdown" backbone breaks. H.12 config-assert guards neither (and is also blind to `NODE_YIELD_LIGHT` ≠ 1).
2. **Player-Fantasy thesis asserted, not delivered.** "Mastery is when *not* to gather," but no mechanic rewards restraint; noise tradeoff legible only in the HUD aggregate, not at the node decision point; the only loud moment (endgame RESONANT) is *forced*, never *chosen*. Fixable in scope, but elevates verdict to MAJOR in combination with the floor breach.
3. **RESONANT scarcity is economically incoherent.** 4 Heavy nodes > 3 required → no squad ever waits the 120 s respawn → `NODE_RESPAWN_TIME_HEAVY` is an inert knob; "binding bottleneck" framing false (it's a noise + extraction-time bottleneck, not supply). Document also simultaneously claims it over-binds 2-player squads.
4. **Proximity arm-detection mechanism entirely unspecified** (3-lens converge: network atomicity, gameplay feasibility, performance cost — naïve 60Hz poll ≈ 14,400 checks/s at 60 nodes). The "single non-yielding path" lock guarantee (CR.6/E.2) is unprovable until this is pinned.
5. **Honesty + AC defects.** E.9 anti-forge claim incorrect (`HumanoidRootPart.Position` is client-reported under Roblox network ownership — teleport-hack can pass the proximity check); Heavy idle-hum contradicts the <250 Hz predator-protection floor and mis-teaches the audio vocabulary; AC count wrong (header "23" vs actual **30**); H.12/H.22 mislabeled; **E.12 (arm-with-lantern → lower → fire) uncovered exploit path**; H.9 non-deterministic.

**CD binding rulings (user may override) — RN-1..RN-5:** RN-1 re-derive floor for parallel production + assert against safe-range minimums; RN-2 make per-node noise cost legible at the decision point + add a legible-consequence AC, or honestly down-scope the prose (don't discharge a pillar to an unauthored, untested dependency); RN-3 pick one coherent RESONANT scarcity model; RN-4 specify server spatial-query proximity detection on sub-60Hz cadence + mandate the non-yielding critical section + armTimestamp eviction; RN-5 re-spec Heavy idle hum to non-sub-bass 3D `GatherSFX` + state the server-authority position ceiling honestly.

**Specialist disagreements:** None genuine. The apparent RESONANT "over-binds vs never-binds" tension is the GDD being internally incoherent about its own scarcity model, not two reviewers disagreeing (resolved by RN-3).

**Prescription:** CD/design ruling session FIRST (not a mechanical sweep) → one authoring pass → full re-review. The spine is sound in concept (server-authority model, single client event `RequestGather`, emit-before-grant ordering). **Do not predict APPROVED for round 2.**

**Not committed** (branch `crafting-round2-patch`).
