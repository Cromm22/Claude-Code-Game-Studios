---
name: Metadata severity demotion
description: High specialist convergence on metadata defects (status header staleness, round number mismatches, file mtime drift, in-doc references to non-existent supporting files) does NOT inherit BLOCKING severity; metadata defects are demoted to NICE-TO-HAVE unless they create a load-bearing implementability defect downstream.
type: feedback
---

When adjudicating BLOCKING-vs-IMPORTANT-vs-NICE-TO-HAVE severity calls, apply this severity-demotion rule for metadata defects:

**Rule:** Convergence on a metadata defect (multiple specialists notice the same defect because it is highly visible — e.g., a stale "Round-N" header at the top of a GDD) does NOT inherit BLOCKING severity. Severity is assessed against the defect's load-bearing impact, NOT against the count of specialists who noticed it.

**Why:** Specialist convergence is a useful signal for severity ON DEFECT CLASSES THAT MATTER, but is also a strong noise signal for metadata defects: a stale status header is at the top of every spec's read path, so every specialist notices it on their first read. If the rule "N-of-7 specialists noticed it = BLOCKING" were applied uniformly, every stale metadata defect would block the review regardless of whether it changed any implementer's behaviour. The actual defect class for metadata is "the document is harder to date / version" — a documentation-quality defect, not an implementability defect.

The round-14 ED verdict surfaced this rule in adjudication of the round-11 status header staleness:
- Original finding: status header at lines 3-5 of GDD reads "Round-11 heavy patches APPLIED" but the GDD has been through rounds 12, 13, 14 — 7-of-7 specialists noticed.
- Specialist severity tags: 3 BLOCKING, 4 IMPORTANT/NICE-TO-HAVE — uneven distribution.
- CD adjudication: NICE-TO-HAVE. Convergence on noticing ≠ convergence on severity.

**How to apply:**

1. **Identify the defect class.** A metadata defect is one whose ONLY consequence is "the document is harder to date / version / cross-reference." Specifically: stale status headers, stale "Last Updated" timestamps, stale round-number references in headers / footers / file mtimes, in-doc references to supporting files that do not exist on disk (e.g., agent-memory files referenced as "updated" but the directory itself is missing), stale verdict-prediction references in the doc body.
2. **Identify the downstream impact.** If the metadata defect creates a load-bearing implementability defect downstream (e.g., a stale tunable name in the doc that the implementer would copy-paste into code, OR a stale cross-reference that misdirects an implementer to a deleted section), it is NOT a metadata defect — it is an implementability defect. Severity is BLOCKING or IMPORTANT per the load-bearing rule.
3. **If pure metadata, demote to NICE-TO-HAVE regardless of convergence count.** Document the demotion in the review verdict's CD adjudication section.
4. **Bundle metadata fixes into the next available trivial-sweep mini-session.** They should not block the heavy-cluster patch session; they should be folded into the trivial-sweep alongside other low-risk mechanical fixes. The audit-trail benefit (the document has an accurate header again) is real but small.

**Boundary cases:**
- An audit-trail defect where multiple prior round logs reference an agent-memory file as "updated each session" but the file does not exist on disk: this is metadata BUT the load-bearing impact is "future reviews cannot calibrate verdict predictions because the pattern memory the prior reviews claim to be updating does not exist." This crosses the line into implementability of the REVIEW PROCESS itself. Severity is NICE-TO-HAVE for the GDD-level review, but BLOCKING for the project-level audit-trail (require the directory to be created and files persisted as part of the trivial-sweep). The round-15 trivial-sweep applied this two-track adjudication — NICE-TO-HAVE for the GDD-level demotion, but the audit-trail closure was sequenced into the trivial-sweep work alongside B7 + B8.
- A stale tunable name in the GDD body where the registry has the new name: this is implementability, not metadata. Severity is IMPORTANT or BLOCKING depending on whether the implementer would copy-paste the stale name into code.

**Cross-references:**
- `feedback_mechanical_translation_ceiling.md` — round-15+ static-analysis-first protocol layer is orthogonal to this rule (lint/typecheck does not catch metadata staleness; metadata defects are a distinct class).
- `feedback_severity_floor_for_server_authoritative_seams.md` — the severity-floor rule has the opposite direction (promotion); the demotion rule and the floor rule together bracket the BLOCKING tier on both sides.
