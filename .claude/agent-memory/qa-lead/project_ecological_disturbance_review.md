---
name: Ecological disturbance GDD review state
description: Five adversarial review rounds; 6 blockers remain after round-4 revision; GDD is IN REVISION (round 5 verdict: NEEDS REVISION light)
type: project
---

Ecological disturbance GDD (`design/gdd/ecological-disturbance.md`) has completed five review rounds.

- Review 1 (2026-04-29): 21 blockers. Verdict: NEEDS REVISION.
- Revision pass 1 (2026-04-29): 18 mechanical blockers resolved; 3 design-decision blockers deferred to Q9–Q11.
- Review 2 (2026-04-29, adversarial): 22 blockers. Verdict: NEEDS REVISION.
- Revision pass 2 (2026-04-29): All 22 blockers + 18 recommended fixes applied. Q9/Q10/Q11 design rulings encoded. Large AC expansion.
- Review 3 (2026-04-29, fresh-session): 9 blockers. Verdict: NEEDS REVISION (light).
- Revision pass 3 (2026-04-29): All 9 blockers + 16 recommended fixes applied. D.4 flat dispatch, TierCrossedEvent coalescing, H.39 split, Section B 4th bullet added.
- Review 4 (2026-04-29, fresh-session): 17 blockers (P0 ReplicationFocus regression + mechanical). Verdict: NEEDS REVISION.
- Revision pass 4 (2026-04-30): All 17 blockers fixed. P0 → Option A (server-tracked chunk membership). H.PB1 expanded to 6 questions. H.31b cited at line 297 but NOT DEFINED — this is a carry-forward blocker.
- Review 5 (2026-04-30, adversarial QA-lead): 6 blockers. Verdict: NEEDS REVISION (light).

**Open blockers from Review 5 (QA-lead):**
1. **B1 — H.31b undefined** — Referenced at line 297 as the ReplicationFocus no-read enforcement AC, but H.31b does not exist in Section H. The P0 Option A invariant (ReplicationFocus never read) has no automated regression gate. Required AC: grep-level check for GetPropertyChangedSignal("ReplicationFocus") in DisturbanceService source → zero matches.
2. **B2 — H.PB1 Q4 disjunction collapses to n=1** — If the level design succeeds at eliminating stationary-sprint terrain but one AFK participant triggers a single event, the "≥70% rate fair" gate applies to n=1. One bad response = FAIL; one good response = PASS. Both are statistically meaningless. Fix: require ≥3 affected participants before the rating gate applies; otherwise mark INCONCLUSIVE.
3. **B3 — H.PB1 Q5 (d)-cohort renders gate meaningless** — If ≥75% of participants choose (d) "didn't experience," the BLAME≤50% gate applies to n=1. Fix: require ≥3 participants in (a)/(b)/(c) before the gate applies; otherwise mark INCONCLUSIVE and redesign the playtest scenario to exercise squad-max-aggregation.
4. **B4 — H.PB1 N=8 statistically insufficient** — 95% CI half-width at n=8 for a 70% proportion is ±32pp. The criterion cannot distinguish "design is fine" from "got lucky." Fix: raise minimum to N≥20 OR require 75% pass rate (6/8) at n=8 as the threshold to account for the wide CI.
5. **B5 — H.36 5-second/25-sample window too small for 99th-percentile** — The empirical 99th percentile at n=25 is a single worst value (OS noise, not structural budget overrun). Fix: extend window to 60 seconds (300 cycles at 5 Hz) OR replace 99th-percentile framing with "no individual cycle exceeds 6 ms" which is testable at small n.
6. **B6 — H.39d two-engineer sign-off has no enforcement mechanism** — No PR template, no CODEOWNERS rule, no named artifact location. A one-line "LGTM" comment satisfies the letter of the AC. Fix: nominate a named evidence artifact (e.g., `production/qa/evidence/H39d-[sprint].md`) or cite a specific PR template section.

**Recommended additions (R1–R7):** iPhone SE device procurement status column in prereqs table; H.PB1/H.PB2 blocking-vs-advisory clarification for GDD APPROVED; C.1.11 TTL-purge deferral moved to Open Questions with ADR obligation; E.13 teleport-while-sprinting AC or explicit delegation note; H.39/H.39b "declared and wired" gap (signals declared but not fired pass both ACs); F.3a Cross-GDD checklist enforcement AC; H.9c Luau ^ AST tooling mechanism specified.

**Nice-to-have:** E.20 duplicate-ID debug assertion in ADR; H.39d review scope defined; H.36a added to prereqs table; H.35d insertion invariant for same-position same-tick two-player scenario.

**Why:** B1 means the P0 security invariant has no automated regression gate. B2–B4 mean H.PB1 can pass on statistical noise or single-participant results. B5 means the PERF-DEVICE criterion asserts a statistical measure with a sample too small to support it. B6 means the only MANUAL-REVIEW AC has no evidence record.

**How to apply:** All 6 blockers are mechanical AC text additions or number changes — no new design decisions required. Target is round-5 revision + round-6 re-review for APPROVED verdict.
