# Systems Index — Review Log

Revision history for `design/gdd/systems-index.md`. The systems-index is a project-state tracking document, not a system GDD; reviews here audit accuracy/consistency of declared statuses, dependencies, progress counts, and risk surfacing rather than the standard 8-section GDD checklist.

---

## Review — 2026-05-01 — Verdict: NEEDS REVISION (minor / accuracy) → REVISED IN-SESSION → Accepted

Scope signal: S
Specialists: None (Phase 3b skipped — target is a tracking/registry document with no domain-specific design content; specialist adversarial review would produce no actionable findings)
Blocking items: 3 | Recommended: 6 | Nice-to-have: 2
Prior verdict resolved: First review

### Summary

First-pass accuracy audit of the post-pivot Roblox-scope systems-index. Three items materially misled readers: stale `/art-bible` Next Steps row (file exists on disk but row showed `[ ]`), stale `/design-system crafting-and-items` description (said "Designed pending review" when round-1 review had already completed with NEEDS REVISION verdict), and the camera-system scope risk (PC OQ.3 may raise MVP system count from 7→8) was not surfaced in the High-Risk Systems table despite being captured in Next Steps prose. Six recommended improvements addressed effort-estimate staleness, missing high-risk entries (PC + Crafting both proved high-risk empirically with 28 + 24 BLOCKING items respectively), publish-side dependency convention inconsistency, and Foundation Layer narrative overcommitment. Two nice-to-haves added trajectory context to the Progress Tracker. The dependency-graph claims and review-log file references all checked out as accurate.

### Decisions Locked

- **Dependency convention** → **Inverted Bus** (user-locked). The "Depends On" column tracks consumer-side coupling only (i.e., systems that read/query another system's API). Publish-side relationships (publishers emitting to the bus) are forward-obligations recorded in each system's GDD F.2a, not in the index. Result: ED has zero in-bound deps in the systems table; only Predator AI and HUD are true ED consumers.
- **Effort table format** → split into "Effort (forecast)" + "Effort (actual to date)" columns. Forecasts preserved; actuals recorded as observed cost including review/revision cycles.
- **Three Required items deliberately not fixed in this session**: (a) game-concept.md GDD header "Draft" vs index "In Review" — downstream defect in the GDD itself, not the index; (b) Rec 9 (encyclopedic status fields in rows 1+6) — would lose useful inline context; future polish item; (c) NtH 11 (round-2 target dates) — no source data.

### Specialist Disagreements

None — Phase 3b skipped.

### Files Modified

- `design/gdd/systems-index.md` — 9 edits across Next Steps (3 stale rows fixed), High-Risk Systems table (3 rows added: PC, Crafting, Camera-OQ.3), Recommended Design Order table (split forecast/actual columns), Dependency Map (added Inverted-Bus convention blockquote, updated narrative for layers 1–7), Progress Tracker (trajectory footnote), and 2 systems-table cells (Crafting + Resource Node Depends On — removed ED per inverted convention).
- `design/gdd/reviews/systems-index-review-log.md` — new file, this entry.

### Downstream Defects Surfaced (For Future Cleanup)

- `design/gdd/crafting-and-items.md` header line 3: `Status: In Design` should be `NEEDS REVISION` per the round-1 review verdict on 2026-05-01.
- `design/gdd/player-controller.md` header line 3: `Status: In Design` should be `NEEDS REVISION` per the round-1 review verdict on 2026-05-01.
- `design/gdd/game-concept.md` header line 4: `Status: Draft (round-2 revisions applied; awaiting round-3 fresh-session re-review)` should align with systems-index vocabulary "In Review."

These three are not blocking and can be addressed when each GDD is next opened for revision.

### Status After Revision

Status: Accepted (post-revision). User opted to skip a fresh-session re-review on the basis that the target is a meta-tracking document with no domain content; specialist re-review would add little. All revisions are surgical text edits with no architectural implications.

---
