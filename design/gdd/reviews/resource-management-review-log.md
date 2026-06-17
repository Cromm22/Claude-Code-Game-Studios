# Resource Management — Design Review Log

Revision history for `design/gdd/resource-management.md`. Most recent entry first.

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
