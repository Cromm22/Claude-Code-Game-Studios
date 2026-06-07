---
name: Severity floor for server-authoritative seams
description: When an IMPORTANT-severity finding lands on the primary write-side seam of a server-authoritative gameplay system, auto-promote to BLOCKING regardless of the specialist's original tag — server-authoritative seams violated by honor-system rules trip the project Forbidden Patterns rule against trusting client-supplied values for gameplay-critical state.
type: feedback
---

When adjudicating a review's BLOCKING-vs-IMPORTANT severity calls, apply this severity-floor rule for server-authoritative gameplay systems:

**Rule:** If a specialist finding lands on the primary write-side seam of a server-authoritative gameplay system AND the proposed mitigation is honor-system or guidance-text (not a runtime enforcement), auto-promote the finding to BLOCKING regardless of the specialist's original severity tag.

**Why:** The Roblox technical-preferences explicitly forbid "trusting client-supplied values for gameplay-critical state (always validate server-side)." A primary write-side seam on a server-authoritative system that is enforced only by honor-system rules WILL be violated by future implementers because the system's correctness gate depends on the implementer remembering the rule, not on a runtime/lint mechanism. The defect is structurally the same as the project's anti-patterns list — it is just located one level higher (in the GDD's contract surface rather than in implementation code).

The round-14 ED verdict surfaced this rule in adjudication of qa-lead's B10 elevation request:
- Original finding: R13-I4 path filter gap covering `:ReleasePredatorLock` primary write-side seam — specialist-tagged IMPORTANT.
- qa-lead elevation request: BLOCKING (the seam is the canonical predator-state mutation path; honor-system enforcement on a server-authoritative write path violates project Forbidden Patterns rule).
- CD adjudication: BLOCKING. The rule above codifies the adjudication for future application.

**How to apply:**

1. **Identify the seam class.** A "primary write-side seam" is a code path that mutates server-authoritative gameplay state with no compensating runtime check elsewhere in the contract. Examples: predator lock registry mutation, datastore write paths, RemoteEvent server-fire paths that mutate gameplay state, position/velocity authority transfer points, save-data deserialisation paths.
2. **Identify the mitigation class.** If the proposed mitigation is "implementer should not call X" or "ADR will document the rule" or "documentation in F.4 forbids it", the mitigation is honor-system. If the proposed mitigation is "lint AC verifies", "runtime guard returns nil/error", "type system rejects via published type", the mitigation is enforced — leave at original severity.
3. **Promote to BLOCKING if both criteria above are met.** Document the promotion in the review verdict's CD adjudication section with explicit reference to this memory file.
4. **Do NOT apply this rule to read-side seams.** A read-side seam (a query path) does not trip the rule because honor-system rules on read paths cause fewer correctness defects (the read either succeeds with stale-but-honest data or returns nil; it does not corrupt server-authoritative state).

**Boundary cases:**
- A write-side seam that is NOT primary (e.g., a debug-only mutation path gated by a `RunService:IsStudio()` check) does not trip the rule — secondary seams have a structural runtime gate already.
- A primary seam whose mitigation is "honor-system + the consumer system's GDD will reverse-cite this contract" is still honor-system; the cross-GDD reference does not constitute runtime enforcement. Promote to BLOCKING.
- A primary seam whose mitigation is "honor-system + a planned future H.X AC" is still honor-system at the time of the finding — the AC has not yet been authored. Promote to BLOCKING and require the AC to be authored as part of the closure.

**Cross-references:**
- `.claude/docs/technical-preferences.md` — "Forbidden Patterns: trusting client-supplied values for gameplay-critical state (always validate server-side)."
- `feedback_mechanical_translation_ceiling.md` — round-15 static-analysis-first protocol layer is one of the runtime-enforcement mechanisms that converts honor-system mitigations into enforced ones, raising the severity-floor in advance of CD adjudication.
