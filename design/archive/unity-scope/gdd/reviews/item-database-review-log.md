# Review Log: Item Database

---

## Review — 2026-04-22 — Verdict: MAJOR REVISION NEEDED → Revised In-Session
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior)
Blocking items: 10 | Recommended: 7
Summary: The core design premise (items as vocabulary, knowledge as progression) was sound, but the GDD had critical schema gaps (missing `persistent_footprint_per_hour` field, broken Disturbance Muffle ToolType), formula expressions with unguarded edge cases (division by zero, negative output at n=0, unguarded negative RestoreAmount), an undefined in-game day duration constant rendering the Ecological Anchor gate untunable, and a static description field that could not mechanically deliver the stated Player Fantasy. All 10 blockers were resolved in-session: schema updated, formulas fixed with explicit clamps and validation rules, Muffle redesigned as Modifier ToolType, description split into description_hidden/description_revealed with authoring contract, in_game_day_duration_s=1200 registered, Crafting Bench recipe specified, and 8 acceptance criteria rewritten plus 8 new validation ACs added.
Prior verdict resolved: First review — no prior verdict.

### Blockers Resolved

| # | Blocker | Resolution |
|---|---------|------------|
| 1 | Disturbance Muffle mutually exclusive with harvesting tool | New Modifier ToolType; passive slot separate from active tool slot |
| 2 | Missing `persistent_footprint_per_hour` in Structure schema | Field added to Rule 3 Structure category fields |
| 3 | Formula 1 clamp in prose only; MaxCarryWeight=0 division by zero | clamp() in expression; ITEM-019 validation rule added |
| 4 | Formula 2 n off-by-one; StackingPenalty unbound | n definition clarified; ITEM-020 enforces StackingPenalty ≤ 1.0 |
| 5 | Formula 3 negative RestoreAmount unguarded | ITEM-021 rejects negative restore values at import |
| 6 | In-game day duration undefined | EC-10 added; registered in entities.yaml as in_game_day_duration_s = 1200 |
| 7 | Crafting Bench recipe absent | Specified: 6× Dried Root Fibre + 3× Bioluminescent Cap |
| 8 | Player Fantasy authoring contract missing | description → description_hidden + description_revealed; ITEM-022 warning added |
| 9 | AC-5, AC-10 depend on undesigned Ecological Disturbance system | Rewritten as pure formula unit tests |
| 10 | AC-1 wrong record count; AC-8,9,11,12,13 undesigned-system dependencies | All rewritten to Item Database scope; AC-15 through AC-22 added |

### Open Items (for re-review)

- Carapace Blade gate timing variance accepted as design risk (EC-9) — not a blocker
- TLC bootstrap now requires 2 world prop crystals (revised from 1) — verify in EC-1
- Raw material records not formally authored — flagged in Open Questions
- Modifier slot Inventory rules (slot count, durability model) deferred to Inventory GDD
- Compound gate multi-condition hint strategy deferred to Crafting GDD

---

## Review — 2026-04-22 — Verdict: MAJOR REVISION NEEDED (re-review)
Scope signal: L
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director (senior)
Blocking items: 16 | Recommended: 14
Summary: The prior review's 10 blockers were addressed structurally, but the re-review found 10 new category-(a) blockers (must fix before downstream GDD authoring begins) and 6 category-(b) blockers (must fix before implementation). Key new findings: (1) `description_revealed` trigger is ambiguous — must fire at recipe-gate satisfaction, not first-craft, or the Player Fantasy anchor moment is mechanically broken; (2) the Modifier ToolType resolution added a concept (passive slot, movement degradation, disturbance dampening) but none of the required schema fields to implement any of it — degradation rate field, dampening multiplier field, and tick interval constant all missing; (3) the Interactions section's Inventory and Crafting rows still reference the deprecated `description` field (stale from prior revision); (4) ACs 8, 9, 12, 13 were claimed resolved in the prior review but still depend on undesigned systems (regression). The creative-director recommends against a third in-session revision pass due to context fatigue.
Prior verdict resolved: No — MAJOR REVISION NEEDED returned.

### New Blocking Items (category a — before downstream GDD authoring)

| # | Blocker |
|---|---------|
| 1 | `description_revealed` trigger must specify gate-satisfaction (not first-craft) |
| 2 | ITEM-022 exemption must be category-based (Component/Tool/Structure), not tier-based |
| 3 | Stale `description` field in Interactions — Inventory and Crafting rows must use split fields |
| 4 | Modifier tool degradation rate: no schema field, unit undefined, no validation rule |
| 5 | `persistent_footprint_per_hour` tick interval undefined — not in entities.yaml |
| 6 | `SustainedBehavior.params` shape for `dual_structure_active` undefined |
| 7 | Disturbance Muffle 0.7 dampening value has no schema field — effect unimplementable |
| 8 | AC-19 OR between hard-reject and soft-warn — design decision required |
| 9 | Retroactive-realisation fantasy scope overstated — applies to ~2 items, not universally |
| 10 | Dried Root Fibre hand-harvestability must be confirmed explicitly |

### New Blocking Items (category b — before implementation)

| # | Blocker |
|---|---------|
| 11 | `ActivityCount.action` has no enumerated valid values |
| 12 | ACs 8, 9, 12, 13 must be split Logic/Integration — regression from prior review |
| 13 | AC-22 detection rule (regex for numeric values, item_id matching) unspecified |
| 14 | AC-6 must be split: Logic (formula unit test) + UI (deferred, BLOCKED-ON Inventory UI GDD) |
| 15 | AC-14 fixed vent fracture coordinates not registered in entities.yaml |
| 16 | Ember Cell durability model undefined for Oxygen ToolType |

### Open Items (for re-review)

- Ecological Anchor gate antagonism (dual_structure_active + no_hunt_triggered) — document as acknowledged risk
- Thermal Lance bootstrap soft-lock on death before crafting — flag as progression risk
- Tool obsolescence pattern (Spike after Blade, Lance after Vent Tap) — flag at GDD level
- Rift Zone food economy — flag as cross-biome dependency
- Membrane Filter gate same risk as EC-9 — add edge case note
- Tuning table NoiseSensitivityMultiplier=1.5 description incorrect (clamp makes 2.0 ceiling hard)
- Open Questions `in_game_day_duration_s` note is stale — constant already registered
