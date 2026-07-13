# Resource Management — Design Review Log

Revision history for `design/gdd/resource-management.md`. Most recent entry first.

---

## Review — 2026-06-17 — Verdict: APPROVED (round-4 — two narrow gates + in-session fix)
Scope signal: S (precision pass — RM-only, no new ADR, no formula changes)
Gates (CD round-4 prescription — NOT a fresh full panel; user-selected): **network-programmer** (authority spine re-confirm) + **qa-lead** (determinism + AC integrity)
Blocking items: network 0 / qa 6 (all fixed in-session) | IMPORTANT: network 2 (both folded) + qa 5 advisories (all folded) | Prior verdict resolved: Yes — round-3 NEEDS REVISION, all 9 + R3-1/R3-2/R3-3 applied

**Gate results.** **network = PASS** (spine SOUND, no round-4 regression): pool `P` still write-unreachable; `serverSendTime` + latency-projection strictly display-only (server stamps, never reads client copy); H.47 retirement opened no introspection gap (H.27 absorbed the identical `.Client` assert); idempotent `k`-coalescing correct + retry-safe, per-player attribution preserved server-side. **qa = NEEDS REVISION** — but AC-miscount class GREP-CONFIRMED CLOSED (independent re-count 52 = 35/10/3/4 exact; retired set clean; no dangling H.47 refs; WCAG trigger-vs-flash intact; CR.3/CR.4 sub-step consistent). The 6 qa blockers were ALL determinism/AC-precision on the round-4-touched ACs — none touched spine/arithmetic/economy/design.

**In-session fix (user chose "fix all now"; self-verified, not re-gated):** all 6 qa blockers + both network IMPORTANTs + all 5 qa advisories applied, reconciliation-fanout-checklisted —
- **Q1** H.49 → stub-testable-now label (consistent w/ H.2–H.5; body + header).
- **Q2** H.50 → pinned `≥` predicate + exact-`t=0.334 s` boundary sub-assertion.
- **Q3** H.52 → pinned `dt=1/60` + dt-independent invariant `P ≥ 9.2`.
- **Q4** H.55 → narrowed to RM-side emission only; PC-consumption → PC GDD's AC.
- **Q5** H.56 → exact strict predicate `… < OXYGEN_DRAIN_BC3` ⇔ `canisterCycleTime > 9.09 s` + 9.0/9.1 boundary checks.
- **Q6** H.49 → threshold 280 = formula equality; float-safe test values (272 loss / 288 survive) + tie as single-tick R3-2 policy (no 2100-tick IEEE-754 accumulation).
- **N1** CR.4 → run-end flip is end-of-tick after step ① (final-tick death still charges; later-tick spends rejected).
- **N2** CR.1 → "prevents false-Empty flash" softened to best-effort; Empty *cue* driven only by authoritative `OnOxygenStateChanged`, periodic sync is the correctness guarantee.
- Advisories A1–A5: H.54 starting-P, H.51 server-P precondition, H.44 dup-key identity, H.20 pinned `t=0.4`, H.50 rate-vs-gap note.

AC totals unchanged by the patch (H.55 narrowed in place): **52 live = 35 Logic / 10 Integration / 3 Security / 4 Config-Data**, 4 retired (H.38/39/40/47), 9 forward-pending (7 BCT-accessor [stub-testable now] + H.23/H.56 RN).

**Verdict: APPROVED (by user acceptance — determinism axis closed-by-fix).** The network spine PASSED outright; the AC-miscount class is grep-confirmed closed; every round-4 blocker was RM-only AC-precision and is now fixed + self-verified. User accepted in lieu of a final independent re-gate (the fixes are mechanical precision with no design change). Forward-pending obligations remain correctly flagged (BCT accessor — ED Session B; RN `canisterCycleTime`; HUD GDD consumption incl. combined-flash WCAG bound; Crafting OQ.8 faucet-name + H.106 + OQ.10 per-squad stack cap). **Approval is on RM's own design/contracts; it does not close the cross-GDD reconciliation obligations owned by ED / Crafting / RN / HUD.** NOT committed (branch `crafting-round2-patch`).

---

## Revision — 2026-06-17 — Round-3 blockers applied (pre round-4 re-review)
Type: Revision pass (NOT a verdict) — ONE authoring pass per the CD round-4 prescription, reconciliation-fanout-checklisted (6 of 9 blockers were self-inflicted fix-creates-next-gap instances).
Applied: all 9 round-3 blockers + CD rulings R3-1/R3-2/R3-3 + the IMPORTANT fold-in.

**Reconciliation-fanout checklist (every site each fix touched, to prevent the recurring next-gap):**
- **B1 (R3-3 per-squad cap):** D.5(a) bullet (multi-stack honesty + R3-3) → coast-threshold ¶ (arithmetic replaces circular dismissal: banked items ≤ 100 of the 280 needed, rest must be a deep carried pool the countdown drains) → degenerate-scan (stockpiling/hoard/coast bullets) → new **OQ.10** (lock `ITEM_STACK_MAX` per-squad with Crafting; H.26 + D.5(a) now conditional on it). BC4=8.0 untouched.
- **B2 (`P_after` sub-step):** CR.1 dead-reckon ¶ (pinned: Deducted = post-step-①, Restored = post-step-②; emission in sub-step order) → CR.3 emit line → Interactions HUD row → Dependencies HUD row → UI Reqs → H.51 → H.52. + IMPORTANT latency-pop: `serverSendTime` + client forward-projection added to CR.1/H.51/event sigs.
- **B3 (R3-1 strike HUD obligations):** Interactions HUD row + OQ.7 + Dependencies HUD row — `OnBandChanged`/`wasCriticalSave`/death-spiral+`aliveCount` struck wholesale to the HUD GDD (`aliveCount` PC-owned; RM tracks no headcount).
- **B4 (H.27/H.47 dup):** H.47 RETIRED (number not reused) + merged "mirrors Crafting H.24" note into H.27; header enum + totals updated (Security 4→3).
- **B5 (WCAG flash ≠ trigger):** Accessibility WCAG bullet (RM caps only the state-change trigger; restore/death flashes uncapped ⇒ combined ≤3/s visual bound is a named HUD obligation) → Tuning row → H.50 → OQ.7 → Accessibility coalescing rule.
- **B6 (H.44 idempotent-coalesce):** CR.4 new idempotency×coalescing ¶ (applied total `k×cost`, `simultaneousCount=k`, `k=0`⇒no event) → CR.3 step① → H.44 (worked k=2 example) → H.52 → event sigs → Accessibility coalescing rule.
- **B7 (H.50 determinism):** H.50 rewritten with injected monotonic clock + scripted timestamps `t=[0,0.1,…,0.5]` ⇒ emits only at t=0 and t=0.4 (2 emissions, no wall-clock dependency).
- **B8 (MAX_TICK_DT AC):** new **H.54** (Logic) — `dt=0.5 s` at BC4 ⇒ `dtₑ=min(0.5,0.1)=0.1` ⇒ drains 0.8 not 4.0; header enum + totals updated.
- **B9 (Player Fantasy honesty):** "clock that forces noise" ¶ split into two-truths framing (hiding always loses vs deep-pool coast is reachable only by gathering, not hiding) + explicit 2-player-net-negative-at-all-bands (modal Roblox case) acknowledgment.

**CD rulings applied:** R3-1 (strike HUD obligations, B3); R3-2 (coast tie at `≥`: H.49 → `P=280` survives, `279` dies; stale `BEACON_SURVIVAL_WINDOW_min` forward-pending tag fixed — constant exists today); R3-3 (per-squad Canister-stack cap, B1/OQ.10).

**IMPORTANT folded in:** latency-pop bound (serverSendTime projection); `OnPlayerOxygenExpired` argless silent-nil gating → new **H.55** (Integration, testable now); D.5(b) `≥2.5s`→strict `>2.5s` + 9.1 s HARD floor governs; BC3 HARD floor → new **H.56** init-assert (Config-Data, forward-pending RN); H.51 numeric; H.17 exact-37.001 boundary; H.49 tag; run-end dedup-clear race → CR.4 run-state guard; BIOMASS diversion noted Crafting-cost-dependent (conservative, OQ.6/OQ.9).

**AC accounting (grep-verified, self-auditable):** round-3 50 → **round-4 52 live = 35 Logic / 10 Integration / 3 Security / 4 Config-Data** (−1 H.47 retired; +3 H.54/H.55/H.56). 9 forward-pending of 52 (H.2/3/4/5/21/41/49 BCT accessor; H.23/H.56 RN). H.55 testable now. NOT committed.

---

## Revision — 2026-06-17 — Round-2 blockers applied (pre round-3 re-review)
Type: Revision pass (NOT a verdict)
Applied: all 9 round-2 blockers + the IMPORTANT fold-in.

- **B1** AC header recounted + per-AC enumerated (self-auditable), H.1 acknowledged Integration, 8 forward-pending + 1 import-partial disclosed.
- **B2** D.5(a) `oxygen_pool_start` drop named intentional under shared pool (R2-1); entry-reserve carried by coast threshold.
- **B3** `=28` literal → formula `BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR ÷ ITEM_STACK_MAX` (= 28 at defaults).
- **B4** BC3 net-negativity hedged conditional (`canisterCycleTime > 20/2.2 ≈ 9.1 s`), forward-pending; HARD RN floor stated, [7.5,11.1] overlap flagged.
- **B5** DP-2 "no crash zones" corrected — 3/4 corners violate; pool-relative range; H.24 init-assert = real defense.
- **B6** `OXYGEN_STATE_CHANGE_MIN_INTERVAL = 0.334 s` knob + H.50 + accessibility-floor ref.
- **B7** CR.1 dead-reckon base reset via authoritative `P_after` on semantic events; H.51; propagated to all event signatures.
- **B8** D.6 per-squad-size dP/dt table (2-player cap=1 ⇒ net-negative at all bands incl. BC1); CR.8 + Player Fantasy made honest.
- **B9** Coast-residual framing softened guarantee→probability (Player Fantasy, D.5, degenerate scan); OQ.9 elevated.
- **IMPORTANT** dt cap (MAX_TICK_DT=0.1 in CR.3/D.1); normative per-tick order in CR.3; 68-Canister relabel total-run; `deathEventId` uniqueness + write-before-throw (CR.4); H.27/28/29 reframed structural; `OnPlayerOxygenExpired` → argless squad-wide; H.52/H.53 added; HUD-contract obligations named in OQ.7; "spending the dead" prose reconciled to CR.5.

ACs 46 → **50 live** (added H.50–H.53). NOT committed.

---

## Review — 2026-06-17 — Verdict: NEEDS REVISION (round-3)
Scope signal: M (one cross-GDD ruling + a fanout-checklisted precision pass; no new ADR)
Specialists: game-designer, systems-designer, economy-designer, network-programmer, qa-lead, ux-designer, creative-director (synthesis)
Blocking items: 9 (grouped; all RM-addressable) | Recommended (IMPORTANT): ~10 | Prior verdict resolved: Yes — round-2 NEEDS REVISION, all 9 blockers applied

**Summary:** First full-panel re-review against the round-3 revision. Unanimous NEEDS REVISION, **none MAJOR** — a genuinely converging design. The recurring **AC-miscount class is RESOLVED**: qa-lead AND systems-designer independently re-counted and confirmed **50 live = 34 Logic / 9 Integration / 4 Security / 3 Config-Data** with the forward-pending list accurate. systems-designer verified ALL round-3 arithmetic correct (BC3 9.1 s floor, the per-squad-size dP/dt table, D.5a 100<280, DP-2 corners, H.52). network-programmer re-confirmed the **authority/attribution spine SOUND** with no new client-write path and the **vacuous-security-AC class CLOSED** (H.27/28/29 reframe now substantively testable). The defect surface narrowed from arithmetic/framing (round-2) to **implementation-contract precision** (round-3) — and **6 of the 9 new blockers are self-inflicted fix-creates-next-gap instances** from the round-3 edits (the `P_after` feature, the OQ.7 HUD-contract naming, the MAX_TICK_DT cap, the `OnPlayerOxygenExpired` arity change).

**CD binding rulings (R3-x):**
- **R3-1:** STRIKE the half-named HUD-contract obligations (`OnBandChanged`, `wasCriticalSave`, death-spiral-trajectory + `aliveCount`) from OQ.7 — defer fully to the HUD GDD; do not ship dangling signatures. (`aliveCount` is PC-owned; RM tracks no headcount.)
- **R3-2:** Coast-threshold tie resolves at **`≥`** — a squad entering BC4 at exactly 280 survives the window (the Beacon-survival check wins the final-tick tie over oxygen-empty). H.49 to use 280 (not 281) as the survive boundary.
- **R3-3 (user ruling, 2026-06-17):** the multi-stack BC4 fence resolves as a **per-squad Canister-stack cap** — Canister supply is squad-bounded (one effective stack) so `100 < 280` holds and the protected **BC4=8.0 is untouched**. RM must lock/confirm `ITEM_STACK_MAX` per-squad semantics with Crafting (cross-GDD obligation, new OQ).

### Blocking items (round-4 targets; ⚠ = self-inflicted by round-3 edits)
1. **[economy+game] Multi-stack inventory scope / coast-banking** — resolve via R3-3 (per-squad cap); restate D.5(a) honestly; replace the circular "coast-on-a-fat-pool" degenerate dismissal with arithmetic.
2. ⚠ **[systems+network DOUBLE] `P_after` sub-step timing** — pin `OnOxygenDeducted.P_after`=post-step-1, `OnOxygenRestored.P_after`=post-step-2.
3. ⚠ **[ux+game+network CONV] OQ.7 HUD-contract obligations half-named** — resolve via R3-1 (strike to HUD GDD).
4. **[network+qa+systems TRIPLE] H.27/H.47 duplicate Security ACs** — merge/retire one (Security count → effectively 3 distinct).
5. **[economy+game] H.50/WCAG** — state-change rate-limit ≠ visual-flash cap; `OnOxygenRestored` flash uncapped; HUD-side bound must be a named obligation.
6. **[systems+network DOUBLE] H.44 coalescing vs CR.4 idempotency** — pin per-death idempotent application, coalesced emission, `amount` = applied total.
7. **[qa+ux] H.50 not deterministically testable** — rewrite with injected timestamps.
8. ⚠ **[qa+economy DOUBLE] MAX_TICK_DT cap has no AC** — add one (e.g. dt=0.5 s drains only drain×0.1).
9. **[game] Player Fantasy half-updated** — still reads as full-squad guarantee then self-contradicts; never acknowledges 2-player (modal) net-negative at all bands.

### Recommended (IMPORTANT — same pass)
Dead-reckon latency-pop at BC4 (re-base to a `P_after` stale by latency×8.0 → violates ±0.5 on mobile; consider send-timestamp projection or bound the pop); `OnPlayerOxygenExpired` argless silent-nil risk + a gating integration AC; D.5(b) `≥2.5s`→strict `>2.5s` + cross-ref the 9.1 s HARD floor; BC3 HARD constraint needs an RM-owned forward-pending init-assert AC; BIOMASS allocation tension unquantified (cite Crafting Beacon cost or log OQ); run-end dedup-clear race vs in-flight spends (run-state guard on `RequestSquadOxygenSpend`); H.51 missing numeric assertion; H.17 exact-37.001 boundary; H.49 stale `BEACON_SURVIVAL_WINDOW_min` forward-pending tag (constant exists today).

### Convergences (≥2 independent lenses — strongest)
`P_after` sub-step timing (systems+network); H.27/H.47 duplicate (network+qa+systems); multi-stack fence / coast-banking (economy+game); H.44 coalescing-vs-idempotency (systems+network); MAX_TICK_DT no AC (qa+economy); HUD-contract dangling (ux+game+network); run-end dedup race (network+economy).

### Forward-pending (correctly flagged, NOT gating APPROVED)
Final `canisterCycleTime`/`restoreRate` + H.23 (Resource Node); BCT accessor + pre-Beacon mapping (ED Session B); HUD consumption of the events (HUD GDD).

### Next
Round-4 (CD prescription): one ruling-confirm → ONE authoring pass with an explicit reconciliation-fanout checklist (6 of 9 are self-inflicted) → TWO narrow gates (qa-determinism + network re-confirm), **not** a fresh full panel. User chose revise-in-a-fresh-session. **DO NOT predict APPROVED for round-4** — but the trajectory is strongly converging (spine SOUND, arithmetic SOUND, miscount class closed; remaining surface is contract-precision + the round-3 self-inflicted gaps).

---

## Review — 2026-06-17 — Verdict: NEEDS REVISION (round-2)
Scope signal: L (system surface) / M (the revision itself — one self-contained authoring pass, no upstream blocker)
Specialists: game-designer, systems-designer, economy-designer, network-programmer, qa-lead, ux-designer, creative-director (synthesis)
Blocking items: 9 (all RM-only / derivable-now) | Recommended (IMPORTANT): ~10 | Prior verdict resolved: Yes — round-1 NEEDS REVISION, all 6 clusters (RBI-1..RBI-6) addressed at the rule level

**Summary:** First full-panel re-review against the post-round-1-revision GDD. All six round-1 clusters confirmed resolved; the server-authority spine is AIRTIGHT (network), the shared-pool→Pillar-2 fantasy is consonant, and the user's round-2 BC4=8.0 / no-CR.9 ruling is PROTECTED and untouched. Verdict held at NEEDS REVISION (not MAJOR) — the defect surface narrowed cleanly from architecture/design-decision (round-1) to **arithmetic-precision, framing-honesty, and AC hygiene** (round-2), the trajectory of a converging design. Every blocking item is enumerable, single-mechanism, and fixable in RM alone now; no upstream system must be authored to reach APPROVED.

**CD process ruling R2-1 (binding):** RM's shared-pool over-supply form (`ITEM_STACK_MAX × CANISTER_RESTORE < window × drain` → `100 < 280`) GOVERNS; Crafting H.106's `oxygen_pool_start`-bearing form does not survive the per-member→shared-pool reinterpretation (there is no per-member starting reserve; the entry-reserve question is instead carried by RM's coast threshold). RM must name the dropped term as intentional; Crafting H.106 reconciles to the shared-pool model (already logged OQ.8(iii)).

### Blocking items (all RM-only, fixable now)
1. **[qa] AC type-split miscount** — header claims 31 Logic / 8 Integration; actual **30 Logic / 9 Integration** (H.1 is Integration in its own text). Total 46 correct, breakdown wrong — the same class round-1 flagged, recurred. Also undisclosed: ~8–9 ACs forward-pending (BCT accessor / RN) not noted in the "46 live" header.
2. **[systems, conv. w/ Crafting F.4] D.5(a) silently drops `oxygen_pool_start`** vs Crafting H.106's binding form (`600+100 < 280` FALSE at defaults). Resolve via R2-1 — add one sentence naming the dropped term as intentional under shared-pool.
3. **[systems] "=28" parenthetical** in the `CANISTER_RESTORE_OXYGEN` coupling is BC4=8.0-specific → replace with `< BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR / ITEM_STACK_MAX`.
4. **[systems + economy CONVERGED] "BC3 always net-negative" asserted as structural fact** but conditional on `canisterCycleTime ≥ ~9.1 s`; D.5(b)'s "any ≥ 2.5 s" admits breaking values; H.23 hedges only BC4. Hedge BC3 forward-pending + state the RN constraint (`canisterCycleTime ∈ ~[7.5, 11.1] s`) as a HARD requirement, not a soft advisory.
5. **[systems] DP-2 "no crash zones" claim false** — 3 of 4 corners of (pool 300–900 × cost 60–90) violate [0.10,0.15]; H.24 init-assert is the real defense. State `DEATH_OXYGEN_COST` safe range pool-relative; note the two knobs are mutually constrained.
6. **[ux] WCAG trigger-rate cap named but never valued** (RM owns the emission side of the round-1 RBI-6 floor). Add `OXYGEN_STATE_CHANGE_MIN_INTERVAL` (≥334 ms ⇒ ≤3 events/s) + an AC.
7. **[ux] Dead-reckon base reset on semantic events undefined** — specify in CR.1 that `OnOxygenDeducted`/`OnOxygenRestored` carry authoritative `P_after` that resets the client base (one fix resolves the death-lurch legibility + adjacent-tick coalescing + BC3-transition visual error together).
8. **[economy + game CONVERGED] 2-player net-negative at ALL bands incl. BC1** (bench cap = `min(2,ceil(2/2))` = 1 → restoreRate ≈ 0.83 < 1.0). D.6's "+0.67 / +0.17" table is silently the 4-player experience; 2-player is modal on Roblox. Add a squad-size caveat to D.6; make CR.8/Player-Fantasy honest that "can grow the pool at low bands" is a full-squad property.
9. **[game + economy CONVERGED] Coast-residual framing honesty** — Player Fantasy says "quiet is never enough" as a guarantee; D.5 makes it a probability (coast threshold 280 is achievable by a Canister-maximizing squad — "implausible" is too confident). Match the prose to D.5's honest framing; raise OQ.9 priority. **(Does NOT reopen the user BC4=8.0 ruling — playtest-validate.)**

### Recommended (IMPORTANT — same pass)
D.6 "68 Canisters" worked example proves total-run balance but reads as covering BC4 specifically (temporally infeasible in-window) — relabel + clarify BC4 covered by entry pool; no `dt` upper-bound cap (lag spike at BC4 craters pool) — add `min(dt, MAX_TICK_DT)`; missing boundary ACs (`P=37.000` stays Critical; "N deaths→0 then same-tick Canister lifts→no cascade"); pin `deathEventId` cross-run uniqueness + dedup-write-before-throwable-work (reconciliation double-fire); reframe H.27/H.28/H.29 as structural/introspection asserts (test non-existent client surfaces, pass trivially) [conv. network + qa]; resolve `OnPlayerOxygenExpired(playerId)` singular-vs-"every alive player" arity + run-end dedup-cleanup AC; name the HUD-contract obligations now (`OnBandChanged` escalation cue, `wasCriticalSave` flag, net-drain-rate + aliveCount for death-spiral trajectory) via OQ.7; put per-tick ordering in normative CR.3; soften "spending the dead" / "last-moment save" prose to match the automatic/deterministic mechanics; disclose forward-pending AC count in the header.

### Forward-pending (cannot close now — correctly flagged, NOT gating APPROVED)
Final `canisterCycleTime`/`restoreRate` value + H.23 (Resource Node); BCT accessor signature + pre-Beacon BC2/BC3 mapping (ED Session B — game-designer confirms the drain ramp above BC1 is unimplementable until then); HUD consumption of the semantic events (HUD GDD).

### Cross-GDD reconciliation owned by Crafting (does NOT gate RM — RM is clean, logged OQ.8)
Crafting F.4 **line 938** still names the old `OnOxygenRestoreRequested(amount)` on the authoritative obligation row (network B1, CD-verified) — blocks the *Crafting* gate, not this one. R2-1 confirms RM's shared-pool form governs, so Crafting H.106 reconciles to RM.

### Convergences (≥2 independent lenses — strongest)
2-player net-negative-all-bands (economy + game); BC3-net-negative conditional-not-structural (systems + economy); coast-280 achievable / "implausible" too confident (economy + game); BC3-transition dead-reckon error ~2.9u > ±0.5 tolerance, visual-only (systems + network); H.27/28/29 vacuous security ACs (network + qa).

### Next
Round-3 `/design-review design/gdd/resource-management.md` in a fresh session after the revision pass (user chose revise-in-new-session). DO NOT predict APPROVED for round-3 — but the trajectory is genuinely converging (defect surface shifted from design-decision to arithmetic/framing).

---

## Revision — 2026-06-17 — Round-1 blockers addressed (pre round-2 re-review)
Type: Revision pass (NOT a verdict — round-2 `/design-review` pending in a fresh session)
Clusters resolved: 6 blocking + IMPORTANT fold-in

**Load-bearing decision (user ruling):** removed CR.9 / `OXYGEN_BC4_ENTRY_CAP` entirely and raised `OXYGEN_DRAIN_BC4_FLOOR` **3.5 → 8.0** as the sole shared-pool anti-bunker fence. BC4-drain magnitude chosen **8.0 u/s** (over 5.0 / 12.0 options) — coast threshold 280, predator stays primary finale threat while oxygen is a real co-equal clock; the ~17 u/s "no-coast-at-any-pool" ceiling was rejected as making oxygen-death dominate the finale. Locked as the OQ.9 playtest tuning anchor (lower toward 5.0 if oxygen-death dominates; raise toward 12.0 if silent coasting observed).

**Fixes by cluster:**
- **RBI-1** — Faucet conformed to Crafting's published `OnOxygenPulseRequest(amount, requestingPlayerId)` (Knit `Signal`); RM keeps ignore-params/own-constant posture; interface status → Forward-pending; Crafting's stale `line 938` name + per-member H.106 wording logged as 2 reconciliation obligations (OQ.8). Updated CR.6, both interface tables, H.28, Resource Node chain.
- **RBI-2** — CR.9 rule + edge case + `OXYGEN_BC4_ENTRY_CAP` knob + D.5 entry-cap legs removed; H.38–H.40 retired-in-place (numbers not reused). `OXYGEN_DRAIN_BC4_FLOOR` → 8.0 in CR.2 / D.1 / H.5. D.5 restated as over-supply init-assert (`100 < 280`, margin 180) + honest coast-threshold disclosure (280 silent / 222 loud).
- **RBI-3** — D.6 restated **squad-total**: `restoreRate_squad = min(N_gatherers, CRAFT_CONCURRENCY_CAP=2) × CANISTER_RESTORE / canisterCycleTime ≈ 1.67 u/s`; band-by-band net rates (BC1/BC2 sustainable-when-loud, BC3/BC4 net-negative); BIOMASS allocation tension + RN `canisterCycleTime` soft-constraint folded in. CR.8 + H.23 updated.
- **RBI-4** — All Tuning-Knob safe ranges re-derived against couplings (no crash-zone overlaps; entry-cap knob gone). Tolerance restated as client dead-reckoning (CR.1 + `drainRate` in sync payload); H.20 rewritten with no RTT in assertion.
- **RBI-5** — H.1/H.14/H.19/H.20/H.26 rewritten testable; deterministic per-tick order (deductions→restores→drain) specified (edge case + H.43); added H.41–H.49 (BCT-nil fail-safe, `PlayerRemoving`, coalescing, semantic events, `.Client` introspection, negative `amount`, coast boundary). Distinct HUD semantic events `OnOxygenRestored` / `OnOxygenDeducted(…, simultaneousCount)` added. Totals: **46 live ACs — 31 Logic / 8 Integration / 4 Security / 3 Config-Data** (round-1's 40-but-summed-42 miscount corrected).
- **RBI-6** — Critical-state shape/icon redundancy + WCAG 2.3.1 ≤3 flash/s bound + audio→visual redundancy + N-simultaneous coalescing rule added (Visual/Audio + UI).
- **IMPORTANT** — 2-player BC4 death worst-case framed honestly (net ≈ −7.2 u/s, near-unrecoverable; deferred lever named → OQ.3); Knit `Signal` vs `RemoteSignal` specified; H.48 negative case.

**Still forward-pending (correctly flagged, not gating APPROVED):** final `canisterCycleTime`/`restoreRate` (Resource Node GDD); BCT accessor signature + pre-Beacon band mapping (ED Session B). HUD consumption of the events (HUD GDD unauthored).

**Next:** round-2 `/design-review design/gdd/resource-management.md` in a fresh session. DO NOT predict APPROVED for round-2.

---

## Review — 2026-06-17 — Verdict: NEEDS REVISION
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, network-programmer, qa-lead, ux-designer, creative-director (synthesis)
Blocking items: 6 clusters | Recommended: ~7 | First review (round-1)

**Summary:** First full-panel review of the authored RM GDD. The spine is sound — the shared-pool fantasy genuinely renders Pillar 2, server-authority posture is correct, idempotency is correct, float accumulation is a non-issue in Luau doubles, and "always a countdown" is the right core tension *if* the throughput math holds. Verdict held at NEEDS REVISION (not MAJOR): the architecture is intact; the defects are reconciliation, derivable-now arithmetic that was hidden inside "validate at playtest" framing, and one finale-mechanic design decision. Nearly all fixes are RM-only; only two values (final `canisterCycleTime`/`restoreRate`, and the BCT accessor signature) are genuinely blocked on the unauthored Resource Node / ED Session B and must stay forward-pending. No upstream system must be authored first to reach APPROVED.

**Prior verdict resolved:** First review — none.

### Blocking clusters (priority order)
1. **RBI-1 [network, VERIFIED] — dead faucet + false "Confirmed" status.** Crafting publishes `OnOxygenPulseRequest(amount, requestingPlayerId)` (crafting-and-items.md:364 + 4 sites); RM subscribes to `OnOxygenRestoreRequested(amount)` — name + arity mismatch on the game's only oxygen faucet. RM marks the interface "Confirmed (Crafting committed)" — false. **CD ruling:** RM conforms to Crafting's published signature (caller owns the contract), keeps CR.6's ignore-`amount`/use-own-constant posture, downgrades status to Forward-pending until Crafting reconciles. (Crafting is itself internally inconsistent — line 938 uses the RM name once.)
2. **RBI-2 [game + economy + ux + systems, QUADRUPLE] — CR.9 / `OXYGEN_BC4_ENTRY_CAP` not shippable as a silent clamp.** Anti-competence rug-pull (better play = bigger confiscation); creates a dominant pre-BC4 "let pool drain, stockpile Canister items" strategy that hollows the mid-run economy; ~400→15 one-frame bar crater with no player-facing communication (reads as a bug); "rising edge" idempotency undefined (RM holds no band state; BCT monotonicity unconfirmed). **USER RULING (2026-06-17): REMOVE the clamp + raise `OXYGEN_DRAIN_BC4_FLOOR`** so a full pool can't silently coast the window; the drain alone enforces the anti-bunker fence (D.5 removed). *Open tuning question for the revision:* the ~17 u/s "burn full pool in 35 s" figure is the upper anchor — combined with the Crafting hold-the-beacon win-con it may over-punish; derive BC4 drain so the pool can't coast the window WITHOUT oxygen-death dominating the finale.
3. **RBI-3 [economy + systems] — DEG-1 "always a countdown" unverified / likely false at 4 players.** D.6's `restoreRate ≈ 0.7–1.0 u/s` is per-gatherer but DEG-1 treats it squad-total; 4 gatherers ≈ 4.0 u/s > BC4's 3.5 → net-positive pool, breaking the backbone invariant. (If RN gather time <10 s, even BC1's 1.0 u/s is out-paced.) Restate DEG-1 as an explicit squad-total invariant that drives the drain schedule. Derivable now.
4. **RBI-4 [systems + economy + network] — Tuning-Knobs "safe ranges" overlap startup-crash zones + ±0.5 tolerance impossible.** `CANISTER_RESTORE_OXYGEN` listed 4–12 but D.5(a) fail-fasts above 10.75; `OXYGEN_DRAIN_BC4_FLOOR` floor 3.0 breaks D.5(a) (needs ≥3.3); DP-2 + pool=300 mutually exclusive with death cost 60–90. At 2 Hz × 3.5 u/s the bar is ~1.75 u stale between syncs (3.5× the claimed ±0.5) — H.20/CR.1 unachievable. Re-derive every safe range against all coupled invariants; restate tolerance band-dependently (CD recommends client-side dead-reckoning). *(Several of these dissolve once CR.9/D.5 are removed per RBI-2.)*
5. **RBI-5 [qa + ux] — AC set not Done-ready + HUD event surface under-specced.** 8 blocking ACs (H.1 untestable "no write handle"; H.14 real 30 s wall-clock; H.19 arrival-order non-deterministic; H.20 network RTT in assertion; H.28 tests a non-existent client attack surface; H.39 "≈4.3 s" not pass/fail; + missing GAP-1 BCT-nil fail-safe, GAP-2 `PlayerRemoving` disconnect). RM exports only `OnOxygenChanged`/`OnOxygenStateChanged` — HUD needs distinct semantic events (death-lurch vs drain vs canister-restore vs the CR.9 beat) for WCAG-safe feedback.
6. **RBI-6 [ux] — accessibility floor violations (game-concept's own floor).** Critical "red pulse" lacks colorblind shape/icon redundancy + WCAG 2.3.1 flash-rate bound; "alarm/heartbeat" audio lacks visual redundancy (deaf/HoH miss the principal pre-death warning); death-lurch/restore-flash lack a coalescing rule (4 simultaneous deaths = 4 flashes).

### Recommended (IMPORTANT)
2-player death spiral is derivable now (~147 u for one BC4 death, ~unrecoverable at two) — keep flat drain (OQ.3) but state the worst-case explicitly and name the deferred circuit-breaker/floor lever + trigger; Knit `.Client` enforcement AC (mirror Crafting H.24) + specify Knit `Signal` vs `RemoteSignal`; specify per-tick restore/drain processing order (or strike the "arrival order" claim); document `deathEventId` session-lifetime-monotonic guarantee as a PC contract; add CR.9 edge-state if kept (moot per ruling); add negative/fail-fast cases to H.24–26; model the BIOMASS allocation tension (Canisters-for-survival vs Beacon-materials-for-winning).

### Forward-pending (cannot close at round-1 — blocked on unauthored systems)
- Final `canisterCycleTime` / `restoreRate` value + the H.23 anti-idle AC — **Resource Node GDD** (BIOMASS gather time) + **Level design** (bench travel time, node-sharing semantics).
- Exact BCT accessor signature + pre-Beacon band mapping + BCT monotonicity — **ED Session B / Beacon charge model** (OQ.1, OQ.2).
- HUD consumption of `OnOxygenChanged`/`OnOxygenStateChanged` + the new semantic events — **HUD GDD** (unauthored).

### Next
Round-2 `/design-review design/gdd/resource-management.md` in a fresh session after the revision pass. Revision was chosen for a separate session (L-scope, clean context). DO NOT predict APPROVED for round-2.
