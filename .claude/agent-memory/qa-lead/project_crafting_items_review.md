---
name: crafting_items_review
description: QA review state for crafting-and-items.md — findings from 72-AC analysis, edge case coverage audit, and hard questions
type: project
---

QA review performed 2026-05-01 against `design/gdd/crafting-and-items.md` (72 ACs, 23 edge cases).

**Why:** Sprint-start QA gate for Crafting & Items before stories are written. Findings below inform which stories need test classification corrections before sprint planning.

**How to apply:** Future QA sessions on this GDD should start from this baseline. Key open defects:
- H.27 tolerance bug (BLOCKING)
- H.61 boundary ambiguity (BLOCKING)
- H.63/H.64 P2 priority too low for performance budgets (RECOMMENDED upgrade to P1)
- H.67–H.72 checklist path unspecified (ADVISORY)
- E.2, E.4, E.11, E.15, E.19 missing ACs (RECOMMENDED)
- Visual/Audio and UI sections produce zero ACs — gap is acknowledged but unresolved
