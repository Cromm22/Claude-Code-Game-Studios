# Review Log: design/gdd/game-concept.md

This file tracks all reviews and revisions of the Terranova game concept document.
Append new entries at the bottom.

---

## Review — 2026-04-29 — Verdict: MAJOR REVISION NEEDED → REVISED IN-SESSION

Scope signal: L (Large)
Specialists: game-designer, systems-designer, ai-programmer, network-programmer, ux-designer, economy-designer, qa-lead, creative-director (synthesis)
Blocking items: 6 | Recommended: 15 | Disagreements: 3
Prior verdict resolved: First review

### Summary
First adversarial review of the post-pivot Roblox MVP concept doc. Six blockers
flagged independently by multiple specialists: (1) win condition TBD, (2)
Ecological Disturbance described as both event bus AND gameplay system, (3) co-op
disturbance aggregation model unspecified, (4) "cosmetic-only" boundary
undefined, (5) co-op coordination affordance gap, (6) core hypothesis untestable.
Creative-director synthesis ruled the concept's pillars/fantasy/hook/scope
strong but missing decided substrate for per-system GDD authoring. All 6
blockers fixed in-session via batched user decisions; ~15 RECOMMENDED items
also resolved (Predator AI submodule split, RemoteEvent trust boundary,
DataStore write path, accessibility floor, touch mis-tap mitigation, expanded
anti-pillars, onboarding paradox via death-state feedback, MDA reorder).

### Decisions Locked
- Win condition: **Escape Beacon** (craft + activate)
- Disturbance aggregation: **spatial-radius-merged**
- Coordination affordances: squad meter + auto-broadcast spike alerts + quick-ping + emote wheel
- MDA aesthetic order: Fellowship #1, Challenge #2, Sensation #3
- Cosmetic Boundary Rule: no measurable change to disturbance, oxygen rate, predator detection, movement speed, or crafting speed

### Specialist Disagreements (resolved by creative-director)
- MDA "Challenge vs Fellowship" tension: game-designer flagged as BLOCKER → creative-director downgraded; reordering aesthetics resolved it
- "Single consolidated state machine" critique: ai-programmer flagged as BLOCKER → creative-director downgraded to RECOMMENDED (concept prose acceptable; flag as Predator AI GDD requirement)
- Thumbnail strategy: game-designer + qa-lead pushed to concept → creative-director deferred to marketing milestone

### Status After Revision
Status: Approved (post-revision) pending re-review in a fresh session.
Next: re-review via `/design-review design/gdd/game-concept.md` after `/clear`,
then `/art-bible` and `/design-system ecological-disturbance` in dependency order.

---

## Review — 2026-04-30 — Verdict: NEEDS REVISION → REVISED IN-SESSION

Scope signal: L (Large)
Specialists: game-designer, systems-designer, ai-programmer, network-programmer, ux-designer, economy-designer, qa-lead, audio-director (FRESH LENS — not in round-1 set), performance-analyst, creative-director (synthesis)
Blocking items: 25 (validated by creative-director from ~45 raw specialist findings; ~12 downgraded to RECOMMENDED) | Recommended: ~16 advisory + 6 folded into revision | Disagreements: 5 cross-round + cross-specialist (resolved by creative-director)
Prior verdict resolved: Round-1 fixes audited; **3 ruled INSUFFICIENT** (cosmetic boundary "fixed" was list-based not principle-based — REGRESSION; MDA reordering "delivered" was stated not delivered; onboarding paradox "mitigated" was deferred not mitigated)

### Summary

Round-2 fresh-session re-review with full 9-specialist panel + senior creative-director synthesis. Round-1 fixed 6 surface blockers; round-2 surfaced 25 architectural blockers grouped into 7 themes — including 3 cases where round-1 verdicts did not hold under deeper scrutiny. Audio-director added as fresh lens (not in round-1) flagged a load-bearing audio-pillar contradiction. All 25 round-2 blockers resolved in-session with 4 P0 design decisions taken via batched AskUserQuestion (all 4 user picks aligned with creative-director recommendations). Document grew 278 → 360 lines; concept-level architectural contracts now locked for downstream system GDD authoring.

### Themes Resolved

1. **Cosmetic boundary REGRESSION** (3 specialists agreed) — replaced 5-exclusion list with principle (predator-AI inputs + player-information inputs) + explicit Roblox-native cosmetic rulings + sign-off chain + automated TestEZ regression test. Added NOT-random-pull / NOT-loot-box anti-pillar.
2. **Fellowship pillar mechanics** — spike alerts now zone-attributed (no player names) + private offender alert; mid-run respawn at squad cost (30s + oxygen tax) added as MVP item; spike-alert coalescing for WCAG 2.3.1 compliance.
3. **Predator FSM** — renamed predator state "Retreat" → "Disengage" (resolves naming collision with Disturbance tier); 4-state count preserved via Hunt-timeout (15s nil-hotspot → Patrol); Investigate min-dwell 8s; Disengage min-sustain 20s; tied-hotspot tie-break committed; numeric thresholds aligned with ED GDD as canonical.
4. **Onboarding** — two-layer teaching (pre-first-death in-world cue on first Tense-cross + death-state plain-language feedback). "Legible cause" rubric defined.
5. **Network/Performance substrate** — RemoteEvent enumeration expanded to 11 surfaces; `MarketplaceService:ProcessReceipt` callback contract + idempotency key + "no charge without grant" semantic; client prediction scoped to movement/visual ONLY; disturbance signals server-internal-only; Roblox character replication baseline added to bandwidth risk register; mobile thermal-degradation mode committed.
6. **Audio pillar** (FRESH LENS) — minimal adaptive audio in MVP (single ambient stem crossfade tied to Disturbance tier); predator sonic identity = biological/organic non-vocalising; gather audio scales with disturbance; ~60–80 audio asset estimate; audio priority hierarchy committed.
7. **AC independence** — `PredatorEncountered` event semantics defined (server Hunt-lock); session = 60-min server-scoped; `RunEnded.exitReason` enum committed; sample size raised 20→75; AND aggregation rule explicit; "no desync" defined numerically (±0.5 oxygen units).

### Decisions Locked (P0 design decisions taken via single batched AskUserQuestion)

- **Spike alert framing**: Private + zone (recommended)
- **In-run respawn rule**: Mid-run respawn at squad cost (recommended)
- **Audio adaptive scope**: Minimal adaptive in MVP (recommended)
- **Cosmetic boundary fix shape**: Principle + explicit list (recommended)

### Specialist Disagreements (resolved by creative-director)

- Cosmetic boundary "fully resolved" in round-1 → ruled FAILED; list-based fix not principle-based; redo as principle. **REGRESSION acknowledged.**
- MDA reordering "delivered" → ruled STATED, NOT DELIVERED; per-player spike alerts still served Challenge-first dynamics. Structural fix required.
- Onboarding paradox "mitigated" → ruled DEFERRED, NOT MITIGATED; death-state alone fails Roblox first-60-second mobile retention. Pre-death teaching surface required.
- Audio adaptive "v2 enhancement" → ruled CONTRADICTION with Sensation #3 + "audio teaches the world" claim. Compromise: minimal adaptive in MVP (single stem crossfade), full scoring v2.
- Bandwidth primary consumer (disturbance signals vs character replication) → ruled CHARACTER REPLICATION is the primary consumer (network-programmer + performance-analyst agreed). Concept's framing was wrong; corrected.

### Status After Revision

Status: NEEDS REVISION → revised in-session. Round-2 revisions complete; 25 blockers resolved; 6 recommendations folded in. Document at 360 lines.
Next: round-3 re-review via `/design-review design/gdd/game-concept.md` after `/clear`. If round-3 verdict is APPROVED, advance to `/design-system player-controller` (parallel-able with the in-progress ecological-disturbance round-5 review) per the design order.
