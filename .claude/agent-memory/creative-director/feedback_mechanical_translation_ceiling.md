---
name: Mechanical translation ceiling for L-scope GDDs
description: L-scope GDDs at round 7+ on the mechanical-translation authoring method exhibit a systematic ceiling — APPROVED-or-near-APPROVED predictions falsify with progressively-smaller residual defect tails; round-15+ requires a NEW protocol layer (static-analysis-first authoring pass) anchored to lint-and-typecheck-the-pseudocode-BEFORE-subagent-submission.
type: feedback
---

The mechanical-translation authoring method (used for the Ecological Disturbance GDD from round-7c onward — chrusht-direct authoring with batched design rulings at session start, agent-as-translator-not-author) has a documented ceiling for L-scope GDDs at round 7+. Empirical evidence as of 2026-05-07:

**Four consecutive falsified APPROVED-or-near-APPROVED predictions:**
- Round 7c → round 8: predicted APPROVED; returned MAJOR REVISION NEEDED.
- Round 9 → round 10: predicted APPROVED-or-NEEDS-REVISION-small-tail; returned NEEDS REVISION (heavy).
- Round 11 → round 12: predicted APPROVED-or-NEEDS-REVISION-small-tail; returned MAJOR REVISION NEEDED.
- Round 13 → round 14: predicted NEEDS REVISION (small tail); returned NEEDS REVISION (small tail). **First matched prediction; the structural-prediction model is now calibrated, but the implementability ceiling persists.**

**Why:** Each protocol-layer addition (round-9 self-stress, round-11 red-team gameplay-programmer subagent, round-13 cross-section consistency qa-lead subagent) closed the THEN-DOMINANT defect class but uncovered a new ceiling at the next layer. The defect-class progression maps to the visibility limits of the protocol's adversarial viewpoint:

- Mechanical-translation alone: surfaces **cross-section consumption mismatches** (round-7c → round-8 gap).
- + self-stress: surfaces **single-section adversarial defects authored by the same agent** (round-9 → round-10 gap).
- + red-team gameplay-programmer subagent: surfaces **single-section implementability defects from an outside viewpoint** (round-11 → round-12 gap).
- + cross-section consistency qa-lead subagent: surfaces **cross-section coherence defects re-emerged from architectural pivots** (round-13 → round-14 gap, partial close — qa-lead pass DID catch the cross-section class but the round-14 finding pattern shifted to single-section implementability micro-defects).
- + static-analysis-first authoring pass (round-15+ NEW; UNTRIED): hypothesised to surface **lint/typecheck-detectable defects in the pseudocode BEFORE subagent submission**, eliminating the implementability micro-defect class that B1-B8 of round-14 exemplifies.

**How to apply:**

1. **Do not predict APPROVED for the next round if the prior round added a NEW protocol layer.** The "fifth-consecutive-falsified-APPROVED-prediction rule" — if round-15 adds the static-analysis-first layer and round-16 verdict review returns APPROVED, that closes the streak; if round-16 returns NEEDS REVISION, the streak extends to five and the next intervention should be method shift, not protocol layer addition.
2. **Round-15 NEW protocol layer = static-analysis-first authoring pass.** Before submitting patches to the red-team + cross-section subagents, run lint and typecheck against the pseudocode and prose-cited Luau code blocks. This is conceptually equivalent to running `--!strict` on the pseudocode itself: any free variable, type annotation gap, alias-resolution gap, or sentinel-safety defect that a Luau type-checker would flag IS a round-15+ implementability defect. The B7 (closure self type annotation) and B8 (cap_engaged undeclared free variable) findings of round-14 are exactly the defect class a static-analysis pass would catch BEFORE submission.
3. **If round-16 fails AGAIN (fifth-consecutive failure with progressively-stronger interventions), escalate to method shift.** Two untried method shifts available: (a) **test-spec-first authoring** — write the AC body with its enforcement contract BEFORE writing the prose body; the AC's enforceability constrains the prose body's claims; (b) **specialist-pair-author method** — spawn 2 specialists (e.g., game-designer + qa-lead) to co-author patches in parallel; their independent texts reduce single-author residue.

**Severity threshold for invoking this memory:** This memory applies when an L-scope GDD has reached round 7+ AND has accumulated a continuous record of APPROVED-or-near-APPROVED predictions that falsified. Do NOT apply to S/M-scope GDDs (the ceiling is round-3-to-round-5, with fewer protocol layers in play) or to L-scope GDDs that never received an APPROVED prediction (no ceiling falsification has happened — the GDD is just iterating normally).

**Cross-references:**
- `feedback_cross_section_consistency_pass_partial_close.md` — round-13 protocol layer's role and limits.
- `feedback_severity_floor_for_server_authoritative_seams.md` — round-14 NEW severity-floor rule applied to B10.
- `feedback_metadata_severity_demotion.md` — round-14 NEW demotion rule applied to status header staleness.
