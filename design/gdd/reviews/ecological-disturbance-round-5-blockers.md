# Ecological Disturbance — Round-5 Blocker Handoff

**Created**: 2026-04-30 (round-5 fresh-session re-review)
**Verdict**: NEEDS REVISION
**Specialist coverage**: game-designer + systems-designer + ai-programmer + network-programmer + performance-analyst + gameplay-programmer + qa-lead + creative-director (synthesis)
**Pattern**: converging (revision residue from round-4 + Luau/Knit-specific defects + deeper specialist layer + 1 emergent design concern). NOT diverging.
**Total**: 13 Tier-1 blockers, 7 Tier-2 recommended, 5+ Tier-3 nice-to-have
**Scope signal**: M (mechanical-heavy with 2 design adjustments)

This document is the round-6 fresh-session input. After `/clear`, run `/design-system ecological-disturbance` and reference this doc. Expected outcome: APPROVED at round 6.

---

## Locked design intent — decide BEFORE editing begins

These two design-decision blockers (#10 Beacon-decoy, #14 H.PB1 redesign) need a creative-director ruling at the start of the round-6 revision session. Round-4 ruled the P0 ReplicationFocus mitigation (Option A) at session-start; round-6 should do the same for these.

### Decision-1: Beacon decoy degenerate-strategy mitigation
The optimal squad strategy at the win condition is currently to fan out and stand still while the beacon decoys the predator (49s Hunt-floor window). This violates Pillar 1 (Quiet Is Power) in spirit while gaming it in letter. Three candidate fixes (CD recommends evaluating all three before picking):
- **Option A — Hunt-floor cap while squad is stationary near beacon**: cap beacon-driven Hunt-floor benefit when >50% of squad is within R studs of beacon AND has moved <D studs in T seconds. Forces movement at activation.
- **Option B — Stationary-sprint contributes to beacon's effective magnitude**: a stationary squad member near the beacon raises the beacon's local field above 1.0 (Retreat tier with shorter half-life), making "hide near beacon" into "be at maximum aggression near beacon." Inverts the incentive.
- **Option C — Per-player presence required for beacon protection window**: beacon Hunt-floor only sustains while at least one player is within R studs of beacon. Beacon at 0 players collapses to standard Beacon decay. Forces an active-defender role.

Recommended: surface this as the round-6 single-AskUserQuestion design ruling at session start, mirroring the round-4 ReplicationFocus → Option A flow.

### Decision-2: H.PB1 redesign approach
Three problems: (i) Q5 wording primes blame attribution by naming a specific cause, (ii) N=8 is statistically thin (CI ±27-32pp), (iii) criteria (ii) and (iii) collapse to n=1 under sparse-event cases. CD recommendation:
- Mark H.PB1 as **directional signal — not pass/fail authority**; explicit confirmation gate at N≥30 in Beta playtest milestone
- Redesign Q5: remove cause-priming wording. Sample replacement: "At some point the world went into high-brightness state. What was your read on what caused it?" with options like "(a) Our squad caused this together (b) A specific teammate (c) Mixed (d) Don't know"
- Replace BLAME≤50% with positive criterion: **≥60% report squad-support** ("(a) FELLOWSHIP" or "(c) NEUTRAL with positive-affect free-form")
- Add minimum affected-participant floor (≥3) for criteria (ii) and (iii); below floor → INCONCLUSIVE → trigger redesigned scenario, not pass/fail

---

## Tier-1 BLOCKERS (must fix before APPROVED)

### Mechanical / arithmetic (revision residue from round-4)

**1. D.7 lifetime arithmetic wrong** — table at lines 672-679. Replace:
- Sprint row: `~77 s` → **`~70 s`** (correct: `ln(0.10/0.02) / (ln(2)/30) ≈ 69.65 s`)
- Light row: `~71 s` → **`~60 s`** (correct: `ln(0.08/0.02) / (ln(2)/30) ≈ 60.0 s`)
- Gather-medium row: `~117 s` → **`~109 s`** (correct: `ln(0.25/0.02) / (ln(2)/30) ≈ 109.3 s`)
- Light/Heavy/Beacon rows: already correct. Do not change.
- Add table footer: `Lifetime = ln(initialMagnitude / MAGNITUDE_FLOOR) / λ where λ = ln(2) / t½`

After updating D.7, **re-confirm H.36 line 1125** uses these values consistently. The H.36 derivation already uses ~69.7s and ~60.0s — just verify the cross-reference reads cleanly.

**2. H.36 source-count range coherent at corrected lifetimes** — line 1125. Current "150–220" is incoherent across its own arithmetic. Use a single point estimate `~207 sources at 60s mark (worst-case continuous-sprint+lantern, 4-player upper-bound)` with a separate stationary-squad lower-bound note (`~103 sources` per fully-attenuated-sprint case). Do NOT keep the 150-220 range — choose point estimate + scenario-bound. [systems-designer B4; performance-analyst B3+R2]

**3. D.4 cascade loop iteration count** — line 525, H.34b line 1113. Worst case Retreat→Calm cascade actually executes the loop body 4 times (Retreat→Hunt→Tense→Calm→stop), not 3. Change "at most three iterations" → **"at most four iterations"** in BOTH places. The O(1) safety claim is unaffected. (Alternative fix: rewrite the cascade loop to count transitions instead of body-executions, but the simple text fix is preferable.) [systems-designer B3]

**4. H.31b undefined** — referenced at line 297 but never authored. Add to Section H Security/Anti-Exploit Regression block:
> **H.31b** — AUTO-UNIT (no-`ReplicationFocus` regression check) — GIVEN the `DisturbanceService` source code, WHEN a grep/AST-level search runs over all code paths reachable from `DisturbanceService:KnitInit()` and the field-update / chunk-load detection paths, THEN: (a) zero occurrences of the string `"ReplicationFocus"` in any context (subscription, property read, or comment); (b) zero occurrences of `Player:GetPropertyChangedSignal("ReplicationFocus")`; (c) zero direct reads of `Player.ReplicationFocus` or `.ReplicationFocus`. Mirrors H.39's grep-based pattern. Verifies C.3.5 / F.4 round-4 P0 mitigation. [unanimous: 5 specialists]

### Luau/Knit implementability defects

**5. D.4 cascade `previousTierAtPosition[P]` uses Vector3 as table key** — lines 511-517. Luau userdata uses reference equality; recomputed `Vector3.new(x,y,z)` calls produce different keys, so lookup always misses → cascade never settles → silent always-Calm bug. Mandate canonical string-key encoding: `local key = string.format("%d_%d", math.floor(P.X), math.floor(P.Z))`. Update the snippet AND prose. [gameplay-programmer B1]

**6. D.6 dedup tuple key is invalid Luau** — `cellKey = (math.floor(X / k), math.floor(Z / k))` is a multi-return tuple, not a table key. Replace canonical form with `cellKey = math.floor(X / k) .. "_" .. math.floor(Z / k)` (string concat) or nested table-of-tables `seen[xBucket] = seen[xBucket] or {}; seen[xBucket][zBucket] = ...`. Pick one and mandate it. [gameplay-programmer B3]

**7. C.3.4 Knit RemoteSignal API** — `OnMeterUpdate:FireClient(player, ...)` is wrong. Knit RemoteSignal exposes `:Fire(player, ...)`; `:FireClient` is the raw RemoteEvent API and is not a method on Knit RemoteSignal objects. Replace `:FireClient(player, payload)` → **`:Fire(player, payload)`** throughout C.3.4 (3 locations: `OnMeterUpdate`, `OnDisturbanceAlert`, `OnDeathAttributionPushed`). Add a normative note: "Knit RemoteSignal fires to a specific client via `:Fire(player, ...)`; `:FireClient` is raw `RemoteEvent` API and is not available on Knit signals." Also update H.29b prose if it cites the wrong method name. [gameplay-programmer B4]

### Cross-doc consistency

**8. Disengage / Retreat naming collision** — concept-doc round-2 (line 201) renamed predator state from "Retreat" to "Disengage" to eliminate naming collision with disturbance tier "Retreat" (t=1.0). C.3.3's signal-to-state mapping (~line 182) and Retreat-trigger prose use unqualified "Retreat" — ambiguous to Predator AI GDD author. Replace every unqualified "Retreat" referring to predator behavior with **"Disengage (predator state)"** in C.3.3 prose. Disturbance tier `"Retreat"` in Luau types and D.4 is unambiguous and stays. [ai-programmer B3]

### Architectural / contract gaps

**9. STREAMINGENABLED chunk-load API requires GDD-level safeguard** — F.4 row 5 currently defers the API choice to the DisturbanceService ADR. Roblox does not expose a documented clean server-side-only "chunk loaded for player X" event. Promote the ADR action item to GDD-level normative requirement:
> Implementation MUST use a server-only chunk-tracking mechanism for the `loadedChunks` membership set. If the DisturbanceService ADR cannot identify a Roblox API that populates `loadedChunks` without reading any client-writable property (including but not limited to `Player.ReplicationFocus`, `Player.Character.PrimaryPart.Position` polling, or any `Player:GetPropertyChangedSignal` subscription), the design decision MUST be raised back to creative-director before sprint entry. The implementation epic for this GDD is BLOCKED until the ADR confirms a safe API.

Add automated grep AC alongside H.31b: zero occurrences of `ReplicationFocus`, `Position`-poll, or any client-property subscription in the chunk-load detection code path. [network-programmer B-2]

**10. Beacon decoy degenerate strategy** — see Decision-1 above. Apply the chosen Option A/B/C in C.3.6 + D.7 + G.5 + new edge case + new H AC. Encode the cross-system implication: this affects Predator AI GDD's locked-target logic and HUD GDD's beacon-active indicator. [game-designer R3]

**11. C.3.5 chunk stream-out-before-delivery race** — server fires `FloraChunkInitialSnapshot`, chunk streams out before packet delivery; client receives stale snapshot for unloaded chunk. Existing E.10 partially covers but doesn't address per-flora last-pushed-t cache reset timing. Add E.22:
> **E.22 — Chunk stream-out before snapshot delivery.** When the server fires `FloraChunkInitialSnapshot` and the chunk streams out on the target client BEFORE packet delivery completes, [...]: (a) the membership-gate is checked at fire-time, so post-fire stream-out is not retroactively applied; (b) the per-flora last-pushed-t cache reset MUST occur AFTER FireClient returns, NOT before the packet is delivered (Roblox does not expose delivery acknowledgment); (c) on next stream-in, the membership set adds the chunk fresh and a new snapshot fires — recovery is bounded to one snapshot cycle. The intermediate state (cache says-pushed but client hasn't applied) is acceptable; corruption is bounded by the next snapshot.

Add H AC verifying recovery within 1 snapshot cycle after stream-out / stream-in. [network-programmer B-3]

**12. `_injectSyntheticEmission` invariants** — H.38b says the seam bypasses schema validation. Define minimum invariants in Test Infrastructure Prerequisites table (~line 1187) AND in a brief E entry: payload MUST satisfy (a) finite Vector3 position (no NaN/Inf — same E.16 check), (b) `initialMagnitude` in `(0, 1.05]` to allow Beacon ceiling, (c) valid `EmissionType`. Bypassing schema validation is for stress-testing live-source-list ceiling, not for testing with arbitrary garbage. [network-programmer B-4]

**13. `MAGNITUDE_TENSE_TRIGGERING_SUM` constant unnamed** — H.28c uses it but it is not in G or D. Replace the formula with a concrete example value: "advance the test clock past `ln(0.31 / MAGNITUDE_FLOOR) / (ln(2) / STANDARD_HALF_LIFE) ≈ 119 s`" using a representative triggering-sum value just above TENSE_THRESHOLD. Or define `MAGNITUDE_TENSE_TRIGGERING_SUM = 0.31` as a test constant in the Test Infrastructure Prerequisites table. [systems-designer R5]

### Predator coordination

**14. `RegisterPredatorLock` release semantics on respawn** — C.1.11 retention condition (c) says entries held while emissionId in any predator's locked attribution. Predator respawn / server reset path is undefined. Add to C.1.11:
> `RegisterPredatorLock` is idempotent and silently drops any `emissionId` in the registration list that no longer resolves in the archive (does NOT treat unresolvable IDs as retention holds). On predator respawn or transition out of Hunt/Investigate/Disengage with an unreleased registration, `DisturbanceService` purges all entries the predator had locked.

Add edge case E.23 covering predator-registration-with-expired-emissionIds. [ai-programmer B2]

---

## Tier-2 RECOMMENDED (fix in same revision pass)

**15. H.PB1 redesign** — see Decision-2 above. Redraft Q5 wording, lower BLAME→positive squad-support criterion, mark as directional signal with N≥30 Beta gate, add ≥3-affected-participant minimum floors. [game-designer B3+R4; qa-lead B2-B5]

**16. First-pulse exemption grace window** — extend C.1.1's first-pulse exemption to the first 1.0s of any sprint state (not just the first pulse) to avoid "instant Tense on first sprint after gather sequence." Update D.7 worked example. [game-designer R1]

**17. AFK / mobile analog drift** — currently relies on Level Design GDD that doesn't exist. Add explicit Player Controller AC obligation in F.2a (new row 6): "Player Controller GDD MUST define a platform-specific (touch input) movement-delta threshold accounting for analog drift; the EMITTER_MOVEMENT_DELTA_FLOOR default of 1 stud may need to be ≥2 studs on touch." [game-designer R2]

**18. H.36 thermal derating policy** — add normative: PERF-DEVICE test MUST run at thermal steady-state (sustained ≥10 minutes before MicroProfiler 5-second sample window). Apply ≥1.4× margin on the 2 ms target to account for ARM CPU throttling under sustained mobile load. [performance-analyst B4]

**19. H.37 bandwidth headroom re-frame** — restate 30 KB/s engine replication as **ceiling assumption requiring profile validation at architecture phase**, not a target. Add: "If profiled character-replication baseline exceeds 30 KB/s under coordinated 4-player movement, the disturbance sub-budget must be lowered to preserve 50 KB/s ceiling." [network-programmer R5; performance-analyst B5]

**20. H.39d two-engineer sign-off enforcement** — add named evidence artifact path: `production/qa/evidence/H39d-[sprint-id]-call-graph-review.md`. Specify CODEOWNERS or PR-template requirement that two reviewers' GitHub names appear in the evidence file. [qa-lead B6]

**21. `hotspotCount` MAY-use-for-flank-deprioritization recommendation** — D.6 round-3 note contradicts the dedup caveat in the same paragraph. Either (a) downgrade "MAY use" to "MUST NOT use for flanked-position logic until Predator AI GDD has verified the caveat is acceptable for that use," or (b) remove the consumer note entirely and add a row to F.2a asking the Predator AI GDD to evaluate. Recommend (a). [ai-programmer R2]

---

## Tier-3 NICE-TO-HAVE (defer to next revision or post-Alpha)

- Stationary-sprint asymptote degenerates at G.5 upper bounds — add G.7 knob-interaction warning [systems-designer R3]
- E.19 cell-radius equality boundary safety proof (one sentence) [systems-designer R1]
- D.2 dist2D doc-comment "ONLY call after dist2DSquared cull" [gameplay-programmer R3]
- C.1.13 `^` operator rationale tightening [gameplay-programmer R1]
- C.3.5 raw RemoteEvent parenting/creation note [gameplay-programmer R2]
- D.6 topContributorsAt return type clarification (tuple vs named-field table) [gameplay-programmer R4]
- D.1 GetServerTimeNow Creator-Docs URL footnote [gameplay-programmer R5]
- E.16 NaN-detection idiom (`x ~= x`) explicit [gameplay-programmer R6]
- `_setExpFn` seam: production code calls `self._expFn` not `math.exp` directly [gameplay-programmer R7]
- F.2a row 3 OnPredatorLockChanged naming-collision-with-H.39 risk note [gameplay-programmer R8]
- C.1.13 graceful-skip framing during sustained hitches [performance-analyst R3]
- H.38b 2× multiplier rationale → ~3.5ms derived [performance-analyst R4]
- H.36a profilebegin scope ambiguity for topContributorsAt [performance-analyst N1]
- H.9c C=5 candidate count derivation note [performance-analyst N2]
- AC coverage gaps: TTL purge, teleport-while-sprinting, signal-wired-not-just-declared [qa-lead R1-R7]
- E.20 GUID collision DEBUG-mode assertion AC [network-programmer R4]
- Disconnect-to-cooldown predator-lock case in E.4 [network-programmer R1]
- OnDisturbanceAlert "triggering player" disambiguation [network-programmer R2]
- Ops-log DOS rate-limit on E.21 path [network-programmer R3]

---

## Round-6 revision protocol

1. Read this doc and `design/gdd/ecological-disturbance.md` only — DO NOT re-spawn round-5 specialists. Their findings are captured here.
2. Surface Decision-1 (Beacon mitigation A/B/C) and Decision-2 (H.PB1 redesign approach) as a single AskUserQuestion at session start before any edits.
3. Apply Tier-1 #1-9 (mechanical fixes, no design judgment needed) sequentially. Each fix touches 1-3 lines; do them in order so cross-references stay coherent.
4. Apply Tier-1 #10 (Beacon mitigation per Decision-1) — touches C.3.6, D.7, G.5, new E entry, new H AC.
5. Apply Tier-1 #11-14 (architectural / contract / coordination — moderate complexity).
6. Apply Tier-2 #15 (H.PB1 redesign per Decision-2) — touches Section H prose + Section B 4th-bullet (a) and (b) reverse-citations.
7. Apply Tier-2 #16-21.
8. Update GDD header status, systems-index status note, append round-5 review log entry + revision entry.
9. Run round-6 fresh-session `/design-review design/gdd/ecological-disturbance.md`. Target: APPROVED.

---

## Carry-forward cross-system action items (rounds 1-4 still open, verified intact in round-5)

- Art Bible §6.4 Beat 3 must be revised before flora-rendering implementation (Q10)
- Player Controller GDD: movement-delta detection (Q9), Calm-tier first-zone teaching beat (Q11), `EMITTER_MOVEMENT_DELTA_FLOOR` interval-sampling logic, mobile analog-drift threshold (Tier-2 #17)
- HUD GDD: persistent zone-presence indicator, predator-locked-on indicator, MAY-explore per-player contribution display
- DisturbanceService ADR: chunk-membership data structure, exp-seam pattern, cap-eviction policy (Q3), grid data-structure choice, StreamingEnabled chunk-load API (with Tier-1 #9 GDD-level safeguard), MockRemoteSignalRecorder + MockTweenService + `_injectSyntheticEmission` seam invariants (Tier-1 #12)
- Predator AI GDD: F.2a 5 obligations + new "nav-target clear on Disengage exit" obligation (Tier-1 #14)
