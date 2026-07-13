# Item Database

> **Status**: Draft — Revised (2026-04-22, post-review)
> **Author**: User + Claude agents
> **Last Updated**: 2026-04-22
> **Implements Pillar**: Pillar 5 (Mastery Feels Earned), Pillar 3 (Every Action Has Weight)

## Overview

The Item Database is Terranova's static, authoritative registry of every item, resource, and material in the game. It contains one authored record per item, defining the properties that all item-consuming systems read: canonical item ID, display name, tier, category, stack behaviour, weight, required knowledge gates for crafting, and disturbance footprint cost for placed structures. The database owns no runtime state — quantities, ownership, and discovery flags belong to Inventory, Crafting, Resource Management, and Save/Load respectively. It is a read-only data contract: the vocabulary that makes cross-system consistency possible. At MVP scope the database covers approximately 10 craftable items across three tiers and five base structure types; the record schema must be extensible to multi-planet content without structural revision.

## Player Fantasy

The Item Database delivers its fantasy through indirection: players don't encounter a database, they encounter objects whose meaning is withheld. An alien root fibre, a crystalline secretion, a heat-hardened carapace plate — each arrives in the inventory before the player understands it. The fantasy is not acquisition; it is the slow, earned resolution from "I don't know what this is" to "I know exactly what this was always going to become."

This is the emotional shape of **Pillar 5 (Mastery Feels Earned)** applied to physical objects: unlocking a knowledge-gated recipe doesn't feel like finding a blueprint; it feels like the moment a grammar rule you already knew crystallizes into a sentence. The item was always going to be part of that sentence — the player just hadn't read enough of this planet yet. It also serves **Pillar 2 (Knowledge Is Survival)**: items as vocabulary, recipes as grammar, and mastery as fluency in an alien language no one translated for you.

**Anchoring moment:** Three sessions in, the player has a stockpile of a crystalline secretion they've never used. A knowledge-gated recipe unlocks. The recipe calls for that secretion. The realisation is retroactive — the game wasn't teaching a recipe; it was teaching that the crystal was always meant for this, and the player had to notice it first.

**Design test:** A player picks up a new item for the first time. Within 30 seconds, do they feel the pull of incomprehension — the specific tension of *not knowing what this is for* but believing it matters? If the reaction is neutral acquisition ("got a thing, added to inventory"), item presentation — description language, sound design, animation weight, UI treatment — has failed to deliver the fantasy. This test is a cross-department contract: audio, narrative, and UI must all serve this moment.

**Authoring contract for `description_hidden`:** The Item Database mechanically encodes the knowledge arc through the `description_hidden` / `description_revealed` field split (see Rule 2). The Item Database's contribution to the 30-second test is the `description_hidden` text. This field MUST:
- Describe the item through sensory properties only: texture, smell, appearance, sound, temperature, weight
- NOT contain any mechanical numbers (damage, restore amounts, multipliers)
- NOT contain any named item_id strings or recipe terms
- NOT use the item's `display_name` in a way that implies its function

Example pass: *"A crystalline growth that hums faintly when held. The edges are sharper than they appear."* Example fail: *"A crystal used to craft the Thermal Lance."* This rule is enforced at import by validation warning ITEM-022 (AC-22). The `description_revealed` field has no such restriction.

## Detailed Design

### Core Rules

**Rule 1 — The Item Record Is Static**
The database is a read-only collection of authored item records. No record stores runtime values — quantities, ownership, durability current value, and discovery or unlock state all belong to consuming systems. The database is the vocabulary; consuming systems own the state of that vocabulary during play.

**Rule 2 — Base Schema (All Item Types)**

Every record contains these fields regardless of category:

| Field | Type | Description |
|-------|------|-------------|
| `item_id` | `string` | Canonical kebab-case identifier. Unique across all records. Primary key for every consuming system. Never changed after first use in save data. Example: `"fissure-spike"`. |
| `display_name` | `string` | Player-facing name shown in inventory and crafting UI. |
| `description_hidden` | `string` | 1–2 sentence in-world text shown before the player has ever crafted a recipe using this item. **Authoring rule:** must not contain mechanical numbers, recipe terms, or named item IDs. Must describe the item through sensory properties only — texture, smell, appearance, sound. Validated by ITEM-022. |
| `description_revealed` | `string` | 1–2 sentence in-world text shown after the player first crafts or unlocks a recipe using this item. May name the item's function precisely. Displayed by Crafting system when that item's recipe state transitions to `known` in the player's Knowledge/Progression record. |
| `category` | `enum ItemCategory` | Values: `RawMaterial`, `Consumable`, `Component`, `Tool`, `Structure`. |
| `tier` | `int` | Values: {1, 2, 3}. Governs crafting access, world node density, and knowledge gate requirements. |
| `stack_size_max` | `int` | Maximum units per inventory slot. Category defaults: RawMaterial (biological) = 20; RawMaterial (geological) = 12; Component = 5; Consumable = 8; Structure = 3; Tool = 1. |
| `weight_kg` | `float` | Mass per unit (min: 0.01). Summed across all slots to produce `TotalCarryWeight`, which feeds `MovementNoiseFactor` (see Formulas). |
| `is_placeable` | `bool` | True only for Structure category. All others: false. |
| `icon_asset_path` | `string` | Addressable asset key for inventory slot icon. |
| `world_model_prefab_path` | `string` | Addressable asset key for in-world drop or held-item prefab. Empty string for Component items (no world presence). |

**Rule 3 — Category-Specific Fields**

*`RawMaterial` — world-gathered resources; always Tier 1; never crafted:*
- `biome_affinity: string[]` — biome_ids where this material's resource nodes may spawn. Empty = unrestricted (spawns in any biome).
- `node_drop_quantity_min: int` — minimum units dropped per harvest (min value: 1).
- `node_drop_quantity_max: int` — maximum units dropped per harvest. Must be ≥ `min`.
- `harvest_tool_required: string` — `item_id` of required equipped tool, or `""` for hand-harvestable.

*`Consumable` — single-use items that restore survival resources:*
- `food_restore: float` — food units restored on use (range: 0–100).
- `water_restore: float` — water units restored on use (range: 0–100).
- `oxygen_restore: float` — oxygen units restored on use (range: 0–100; represents a compressed canister, not food).
- `consume_duration_s: float` — seconds of consume animation before restore is applied (min: 0.5). Player cannot sprint or interact during this window.
- At least one restore field must be > 0 (validation rule ITEM-013).

*`Component` — intermediate crafted items; no world presence, no direct use action:*
- `assembly_description: string` — one sentence of in-world fiction describing what the component physically is. Surfaces in crafting UI detail panel.

*`Tool` — equippable items that enable or modify player actions; always `stack_size_max = 1`:*
- `tool_type: enum ToolType` — values: `Harvesting`, `Building`, `Scanning`, `Oxygen`, `Modifier`. `Modifier` tools equip in a dedicated passive slot separate from the active tool slot, allowing simultaneous use alongside a Harvesting or Building tool.
- `efficiency_multiplier: float` — multiplies base action speed or output quantity (range: 0.5–5.0). Not applicable to `Modifier` type — may be 1.0 as a default.
- `durability_max: int` — maximum durability (range: 50–500). Degrades 1 per use action. At 0, tool is destroyed. Current durability is runtime state owned by Inventory and Save/Load. `Modifier` tools degrade on player movement rather than discrete use actions — rate specified per record.
- `disturbance_footprint_cost_per_use: float` — ecological disturbance points generated per use action (range: 0.0–50.0). `Harvesting` and `Building` tool types must have value > 0 (enforced by ITEM-014 and ITEM-015). `Scanning`, `Oxygen`, and `Modifier` types may be 0.

*`Structure` — placeable world objects; always `stack_size_max = 1`, `is_placeable = true`:*
- `structure_type: enum StructureType` — values: `Shelter`, `Storage`, `Workbench`, `ResourceExtractor`, `Utility`.
- `footprint_width_m: float` — physical width in metres (placement collision + biome boundary exclusion check).
- `footprint_depth_m: float` — physical depth in metres.
- `disturbance_footprint_cost: float` — disturbance points generated at placement (range: 0.0–200.0). Upfront cost only; structures that also emit persistently specify a per-hour rate in Tuning Knobs.
- `disturbance_radius_override_m: float` — if > 0, overrides the biome's `propagation_radius_m` for the **placement event only**. Persistent per-hour disturbance events from this structure use the biome's default `propagation_radius_m`. Use 0 to mean "use biome default for all events."
- `persistent_footprint_per_hour: float` — ecological disturbance points emitted continuously per in-game hour while the structure is placed (range: 0.0–20.0). Use 0.0 for structures with no persistent footprint. Processed by Base Building on a regular tick interval via the Ecological Disturbance event system.
- `placed_prefab_path: string` — addressable key for the fully-placed world prefab instantiated by Base Building.

**Rule 4 — Tier System**

| Tier | Name | Crafting Station | Input Constraint | Knowledge Gate Requirement |
|------|------|-----------------|-----------------|---------------------------|
| 1 | Survival Primitives | None (hand-craft) | RawMaterials only | None |
| 2 | Capability Expansion | Crafting Bench (Workbench) | At least one Component input | ≥ 1 gate on recipe |
| 3 | Mastery | Crafting Bench (Workbench) | At least one Tier-2 Component input | ≥ 2 gates; at least one must be Geographic type |

Additional tier constraints: RawMaterial records are always Tier 1. A Component's tier equals the tier of its highest-tier ingredient. A Tool or Structure record's tier must be ≥ the highest-tier ingredient in its recipe.

**Rule 5 — Knowledge Gate Schema**

Gate lists are owned by the **Crafting system** (on recipe records). The item database defines the `KnowledgeGate` type only — not individual gate lists. Each recipe's gate list is evaluated as logical AND — all conditions must be simultaneously satisfied.

```
KnowledgeGate {
    gate_type     : enum GateType     // Event | Geographic | ActivityCount | SustainedBehavior
    condition     : string            // JSON-encoded parameters (gate_type-specific format below)
    display_hint  : string            // Diegetic in-world blocked-state text shown in crafting UI
}
```

| `gate_type` | `condition` format | Met when... |
|-------------|-------------------|-------------|
| `Event` | `{"event_id": "string"}` | Named event occurred ≥ 1 time. MVP event IDs: `"hunt_state_escaped_shallows"`, `"toxin_response_received"`, `"rift_zone_hunt_escaped"`. |
| `Geographic` | `{"zone": "string", "continuous_s": int}` | Player occupied named zone continuously for ≥ `continuous_s` seconds. Zone values: `biome_id` or `"transition_band"`. A `continuous_s` of 0 means "entered once." |
| `ActivityCount` | `{"action": "string", "item_id": "string", "context_biome": "string", "count": int}` | Player performed action `count` times using specified item in specified biome (`"any"` for no biome restriction). |
| `SustainedBehavior` | `{"behavior": "string", "duration_days": float, "params": {}}` | Player maintained named behavior for stated in-game day duration. MVP behaviors: `"no_hunt_triggered"` (predator never entered Hunt state targeting player); `"dual_structure_active"` (two item_ids active within 30m simultaneously ≥ 1 in-game day — params specify item_ids). |

**Rule 6 — MVP Item Set**

| # | Item | Category | Tier | Function |
|---|------|----------|------|----------|
| 1 | Fissure Spike | Tool | 1 | Enables harvesting of mineral and carapace resource nodes; without it, those node types cannot be harvested at all. |
| 2 | Root Pulp Compress | Consumable | 1 | Restores food. Crafted from the most abundant Tier-1 organic materials. |
| 3 | Condensate Trap | Structure (Utility) | 1 | Passive water collection. Yields Condensate Glob over time; significantly slower output in Rift Zone due to low ambient humidity. |
| 4 | Ember Cell | Tool (Oxygen) | 1 | Reduces oxygen drain rate by 15% in Rift Zone by maintaining body temperature. No light emission; does not advertise position. |
| 5 | Carapace Blade | Tool (Harvesting) | 2 | High-efficiency extraction: harvests same resource classes as Fissure Spike at 3× speed and 60% less disturbance per action. Gate: `hunt_state_escaped_shallows`. |
| 6 | Membrane Filter | Consumable | 2 | Purifies alien fluid sources into drinkable water; without it, consuming raw fluids triggers a toxin response (food drain penalty). Gate: `toxin_response_received`. |
| 7 | Spore-Resin Shelter | Structure (Shelter) | 2 | Resting shelter: halves food/water drain while inside; reduces predator proximity detection radius by 15%. Gate: entered Rift Zone biome and returned to Shallows. |
| 8 | Disturbance Muffle | Tool (Modifier) | 2 | Passive dampening wrap: equipped in the Modifier slot (not the active tool slot). While equipped, multiplies the active Harvesting tool's `disturbance_footprint_cost_per_use` by 0.7 (30% reduction). Stacks multiplicatively with other disturbance modifiers. Can be worn simultaneously with any Harvesting tool. Material only grows in transition bands. Gate: 90 continuous seconds in transition band. |
| 9 | Thermal Lance | Tool (Harvesting) | 3 | Enables harvesting of Rift Zone deep-vein deposits (only source of Thermal Lattice Crystal). High per-use disturbance. Gate: ≥5 Rift Zone harvests with Carapace Blade AND `rift_zone_hunt_escaped`. |
| 10 | Ecological Anchor | Structure (Utility) | 3 | Reduces `InitialStrength` of any disturbance event generated within 15m by 40% before propagation. Has its own persistent footprint. Gate: Disturbance Muffle crafted + 3 in-game days `no_hunt_triggered` + `dual_structure_active` (Condensate Trap + Spore-Resin Shelter within 30m). |

*MVP intermediate component (required by Tier 2 recipes; not counted in the 10-item set):*
**Root-Cord Binding** — Component, Tier 1. Produced at Crafting Bench from 2× Dried Root Fibre. Required inputs for: Carapace Blade, Disturbance Muffle. Introduces the processing-step concept to the player before Tier 2 gates unlock.

**Rule 7 — MVP Structure Set and Footprint Costs**

| Structure | Tier | Type | Placement Footprint | Persistent Footprint | Stacking Multiplier |
|-----------|------|------|--------------------|--------------------|---------------------|
| Condensate Trap | 1 | Utility | 0.3 | None | 1.2× per duplicate |
| Storage Cache | 1 | Storage | 0.4 | None | 1.2× per duplicate |
| Crafting Bench | 1 | Workbench | 0.4 presence | Per-action disturbance via Crafting system event (not a persistent footprint) | 1.0× (no stacking penalty) |
| Spore-Resin Shelter | 2 | Shelter | 1.0 | 0.1 per in-game hour | 1.4× per duplicate |
| Thermal Vent Tap | 3 | ResourceExtractor | 3.0 | 0.3 per in-game hour | 1.5× per duplicate |

Effective footprint when placing the Nth structure of the same `item_id`: see Formulas section for the stacking formula. Stacking is keyed to `item_id`, not `structure_type` — placing a Condensate Trap does not increase `n` for an Ecological Anchor placement even though both are `StructureType.Utility`.

**Crafting Bench recipe (Tier 1, hand-craftable, no gate):** 6× Dried Root Fibre + 3× Bioluminescent Cap. Both inputs are hand-harvestable biological materials — no Fissure Spike required. This ensures the Crafting Bench is reachable without any tool prerequisite, keeping Tier 1 truly gate-free.

Condensate Trap (#3) and Spore-Resin Shelter (#7) from the item set are the same records as structures 1 and 4 here. The full MVP database contains **13 craftable/structure item records**: 10 primary craftable items + Storage Cache + Crafting Bench + Thermal Vent Tap. Raw material records (approximately 10) are additional — see Rule 6 for the named raw material inputs; these are counted separately from the 13 craftable records.

**Rule 8 — Weight as Movement-Noise Disturbance Signal**

`TotalCarryWeight` (sum of `weight_kg × quantity` across all occupied inventory slots) feeds the `MovementNoiseFactor` calculation used by Ecological Disturbance to scale per-step movement noise. Heavier loads produce louder movement — more disturbance per step. There is no hard carry limit and no encumbrance speed penalty; weight is a disturbance signal only. Players are never blocked from picking up items due to weight. See Formulas section for the `MovementNoiseFactor` expression and per-category weight reference values.

---

### States and Transitions

The Item Database is a static data system with no runtime states and no state transitions. All dynamic state associated with items is owned by consuming systems:

| Dynamic State | Owned By |
|--------------|----------|
| Item quantities and slot assignments | Inventory |
| Recipe unlock / knowledge gate evaluation | Crafting |
| Item discovery state (items ever seen or held) | Crafting |
| Tool durability current value | Inventory + Save/Load |
| Structure placement state (active, location) | Base Building + Save/Load |

---

### Interactions with Other Systems

The item database is read-only from every consuming system's perspective. No consuming system modifies records.

**Resource Management** — reads `Consumable` category:
`item_id`, `food_restore`, `water_restore`, `oxygen_restore`, `consume_duration_s`

**Resource Node** — reads `RawMaterial` category:
`item_id`, `node_drop_quantity_min/max`, `harvest_tool_required`, `stack_size_max`, `biome_affinity` (at world-generation time to filter node placement zones)

**Inventory** — reads all categories:
`item_id`, `display_name`, `description`, `category`, `tier`, `stack_size_max`, `weight_kg`, `icon_asset_path`, `is_placeable`, `durability_max` (Tool only). Sums `weight_kg × quantity` across all slots and passes `TotalCarryWeight` to Ecological Disturbance for `MovementNoiseFactor` calculation.

**Crafting** — reads all categories:
`item_id`, `display_name`, `description`, `tier`, `category`, `icon_asset_path`, `stack_size_max`. Crafting owns recipe records and gate lists. The `tier` field tells Crafting which station is required and whether gates apply. Knowledge gate evaluation (`KnowledgeGate` conditions) is Crafting's responsibility — not the item database's.

**Base Building** — reads `Structure` category and `disturbance_footprint_cost_per_use` from `Tool` category:
Structure: `item_id`, `is_placeable`, `structure_type`, `footprint_width_m`, `footprint_depth_m`, `disturbance_footprint_cost`, `disturbance_radius_override_m`, `placed_prefab_path`, `display_name`, `world_model_prefab_path`. The biome boundary exclusion zone (5m from boundary polygon) is environmental data from World Generation — not an item record field.

**World Generation** — reads `RawMaterial` category at generation time only:
`item_id`, `tier`, `biome_affinity`. Builds a biome-filtered list of raw materials at world-generation time to determine which resource nodes to place. Does not access the database at runtime.

## Formulas

**Formula 1 — `MovementNoiseFactor`**

Used by Ecological Disturbance to scale per-step movement noise based on total carried weight.

```
MovementNoiseFactor = clamp(1.0 + (TotalCarryWeight / MaxCarryWeight) × NoiseSensitivityMultiplier, 1.0, 2.0)
```

| Variable | Type | Description |
|----------|------|-------------|
| `TotalCarryWeight` | float (kg) | Sum of `weight_kg × quantity` across all occupied inventory slots. Computed by Inventory, passed to Ecological Disturbance. |
| `MaxCarryWeight` | float (kg) | Reference normalisation constant — the carry weight at which `MovementNoiseFactor` reaches its maximum. Must be > 0 (enforced by ITEM-019). See Tuning Knobs. |
| `NoiseSensitivityMultiplier` | float | Scale of the weight effect. See Tuning Knobs for safe range. Values above 1.0 do not raise the maximum beyond 2.0 — the clamp is hard. |

Output range: [1.0, 2.0] after clamp. Carrying beyond `MaxCarryWeight` does not further increase disturbance. At `NoiseSensitivityMultiplier = 1.0` and full load: factor = 2.0 (fully-loaded player generates 2× baseline movement noise). At empty inventory: factor = 1.0.

---

**Formula 2 — Structure Footprint Stacking**

Used by Base Building when placing the Nth structure of the same `item_id`.

```
EffectiveFootprintCost(n) = BaseFootprintCost × (1 + (n − 1) × StackingPenalty)
```

| Variable | Type | Description |
|----------|------|-------------|
| `BaseFootprintCost` | float | The `disturbance_footprint_cost` from the item record being placed. |
| `n` | int | Count of already-placed structures with the same `item_id`, plus 1 (to include the structure being placed). n ≥ 1 always — the "+1" is baked into the definition, preventing n = 0. At n = 1 (no prior placements of this item_id): no penalty. |
| `StackingPenalty` | float | Per-item-id stacking coefficient (range: 0.0–1.0). Values above 1.0 produce negative effective costs and are rejected by ITEM-020. See Tuning Knobs for values per structure. |

Output is unbounded above — there is no hard cap on n. Example at `StackingPenalty = 0.4`: 1st = 1.0×, 2nd = 1.4×, 3rd = 1.8×, 4th = 2.2× of base cost.

---

**Formula 3 — Resource Restoration (Clamped)**

Used by Resource Management when a Consumable is used:

```
NewResourceLevel = min(BaselineMaximum, CurrentResourceLevel + RestoreAmount)
```

| Variable | Type | Description |
|----------|------|-------------|
| `CurrentResourceLevel` | float | Player's current food, water, or oxygen at moment of use. |
| `RestoreAmount` | float | The item record's `food_restore`, `water_restore`, or `oxygen_restore` value. Must be ≥ 0.0 — enforced at import by ITEM-021. A negative authored value would drain the resource on use; this is rejected as a hard error. |
| `BaselineMaximum` | float | Fixed ceiling for the resource bar. Global constant — not a per-player variable. See Tuning Knobs. |

Over-restoration is silently clamped. No UI displays wasted restoration — invisible waste incentivises players to let meters deplete before consuming.

## Edge Cases

**EC-1 — Thermal Lance bootstrap (crafting paradox)**
The Thermal Lance recipe requires 2× Thermal Lattice Crystal (TLC) as input. TLC is normally only available from Rift Zone deep-vein deposits, which require the Thermal Lance to harvest. To break the paradox: **two** TLC specimens are placed as static world objects at a surface-accessible vent fracture near the Rift Zone boundary. These bootstrap crystals are not dropped by resource nodes — they are fixed world props with item pickup interactions. World prop pickups bypass the `harvest_tool_required` field check (which applies only to resource node harvest interactions, not to world prop pickups). The **Resource Node GDD must specify this contract** — the tool requirement check is on the node, not on the item record. Consequence: the first Thermal Lance is craftable from the two bootstrap crystals without any Lance prerequisite. All subsequent TLC supply requires deep-vein harvesting (Thermal Lance) or the Thermal Vent Tap (which requires 5× TLC to build — obtained from multiple deep-vein runs). World Generation must reserve the bootstrap spawn location as a fixed point, not procedurally placed. The Crafting GDD owns the recipe ingredient quantities; these values are stated here for cross-reference only.

**EC-2 — Compound gate partial satisfaction**
Compound gate conditions (items #9 and #10) are evaluated as logical AND at craft time, not at event time. Each condition is tracked independently in the player's knowledge state. A player who meets Gate F Condition 2 (3 days `no_hunt_triggered`) before Condition 1 (Disturbance Muffle crafted) does not lose that progress — both conditions remain true simultaneously if the player later crafts the Muffle and maintains quiet play. The Crafting system evaluates all conditions at the moment of craft attempt.

**EC-3 — Consuming at full resource level**
If the player activates a consumable when the target resource is already at `BaselineMaximum`, the consume action proceeds and the restoration is silently clamped to zero net effect. The consume animation plays, the item is destroyed, and nothing is restored. No "wasted" notification is shown. This preserves Pillar 3 (Every Action Has Weight) — consuming carelessly has a real cost. The UI must not block the consume action when the resource is near-full; blocking would require displaying the wasted state, which contradicts the "world teaches through consequence" philosophy.

**EC-4 — Multiple Ecological Anchors with overlapping radii**
The Ecological Anchor reduces `InitialStrength` of disturbance events within 15m by 40%. If two Anchors are placed with overlapping zones, events in the overlap are reduced multiplicatively: `InitialStrength × 0.6 × 0.6 = 0.36 × InitialStrength` (64% total reduction). This is intentional — players who understand the system well enough to place overlapping Anchors earn the stacking benefit. The Ecological Disturbance GDD must specify that `InitialStrength` modification is applied before propagation and that multiple modifiers stack multiplicatively.

**EC-5 — `harvest_tool_required` references a non-existent item_id at runtime**
Authoring error — validation rule ITEM-018 catches this at import time. If it reaches runtime (pre-release builds): Resource Node defaults to no tool required (hand-harvestable fallback) and logs an error. No crash. The Resource Node GDD must specify this as the standard error recovery path.

**EC-6 — Gate D and transition band movement speed**
Gate D requires 90 continuous seconds in the biome transition band. The transition band is 40m wide (per biome GDD). A player walking at nominal speed would cross the band in approximately 30–40 seconds — insufficient to meet the gate. The gate is designed to require deliberate presence, not accidental transit. The `continuous_s` counter resets if the player exits the band before 90 seconds. The Dampening Spore Mass material grows in the transition band and is visually distinctive enough to draw players in and give them reason to stop, creating the gate condition organically.

**EC-7 — Save data references an `item_id` that no longer exists in the database**
Post-launch scenario if an item is renamed. Rule: item_ids are never changed or deleted after first use in save data (enforced by ITEM-001). Items removed from the game are set to a `deprecated` authoring status — their records are retained, never deleted. Inventory slots containing deprecated items display a placeholder icon with a `deprecated` badge and cannot be used or crafted with. The Save/Load GDD must enforce this record retention contract.

**EC-8 — Player attempts to place a Structure in the biome transition band**
The biome boundary exclusion zone (`biome_boundary_no_build_radius_m` = 5m) blocks placement within 5m of the boundary polygon. The transition band begins at the boundary polygon. Placement within the transition band (but > 5m from the boundary polygon) is permitted — the exclusion zone is measured from the polygon, not the edge of the band. Base Building must query the boundary polygon geometry, not the transition band bounds, for placement validation.

**EC-9 — Carapace Blade gate timing for low-disturbance players (design risk)**
The `hunt_state_escaped_shallows` gate requires the predator to have entered Hunt state targeting the player and the player to have escaped. A player who generates very low disturbance may not trigger a Hunt for an extended period, delaying T2 access indefinitely. **Design decision:** this is accepted as an intentional feature — the game targets players who are actively managing disturbance, not avoiding it entirely. The pacing variance is a known tradeoff. If playtesting shows this is a significant barrier for the target audience, the Crafting GDD should add a time-in-Shallows fallback gate (e.g., 120 cumulative minutes in The Shallows meets the gate regardless of Hunt status). This fallback is not specified here because it is a Crafting-system gate evaluation decision, not an Item Database schema decision.

**EC-10 — In-game day duration**
Several SustainedBehavior gate conditions use `duration_days: float`. One in-game day equals **1,200 real-world seconds (20 minutes)**. This constant must be registered in `design/registry/entities.yaml` as `in_game_day_duration_s = 1200` before the Crafting GDD is authored. The Ecological Anchor compound gate requires 3 in-game days (`no_hunt_triggered`) = 3,600 seconds of continuous calm play. All systems interpreting `duration_days` must use this constant, not a hardcoded value.

## Dependencies

**Upstream dependencies (Item Database depends on):**

None. The Item Database is a Foundation layer system with no upstream dependencies. It defines the vocabulary; no other designed system's decisions constrain what this GDD can specify.

*Cross-reference note:* The `biome_affinity` field on `RawMaterial` records references `biome_id` string values defined in `design/gdd/biome.md`. This is not a design dependency (the schema is valid without consulting biome.md) but is a **content authoring dependency** — raw material records cannot be fully populated until biome_ids are finalized. World Generation GDD authors must cross-reference biome.md when populating `biome_affinity` values.

---

**Downstream dependents (systems that depend on Item Database):**

| System | Status | What It Requires From This GDD | What It Owns |
|--------|--------|-------------------------------|--------------|
| **Resource Management** | Not Started | `Consumable` record fields: `food_restore`, `water_restore`, `oxygen_restore`, `consume_duration_s`. `BaselineMaximum` constant (Tuning Knobs). | Resource meter current values; drain rates; whether to allow the consume action when resource is full. |
| **Resource Node** | Not Started | `RawMaterial` fields: `item_id`, drop quantities, `harvest_tool_required`, `stack_size_max`, `biome_affinity`. | Node density, node HP, respawn rules (or depletion rules), world placement. |
| **Inventory** | Not Started | All base fields + category-specific display fields. `TotalCarryWeight` computation and `MovementNoiseFactor` formula interface. | Slot count, slot assignment rules, equip-slot routing, durability current value. |
| **Crafting** | Not Started | All base fields for recipe I/O. `KnowledgeGate` type schema (gate_type enum, condition format, display_hint). `tier` field to determine station requirements. | Recipe records, gate lists per recipe, gate evaluation logic, craft output delivery to inventory. |
| **Base Building** | Not Started | `Structure` category fields including `disturbance_footprint_cost`, `disturbance_radius_override_m`, `structure_type`. Stacking formula (Section D). `biome_boundary_no_build_radius_m` constant (registry). | Placement validation, placement collision detection, structure lifecycle (health, demolition). |
| **World Generation** | Not Started | `RawMaterial` fields: `item_id`, `tier`, `biome_affinity`. TLC bootstrap spawn (EC-1). | Node density curves per tier, procedural placement within biome zones, vent fracture location. |

**Bidirectionality requirement:** Each downstream GDD listed above must reference the Item Database as a dependency when it is authored. The interface contracts defined in Section C (Interactions with Other Systems) are the authoritative specification for those references.

## Tuning Knobs

**Group 1 — MovementNoiseFactor**

| Knob | Reference Value | Safe Range | Governs |
|------|----------------|-----------|---------|
| `MaxCarryWeight` | 25 kg | 15–40 kg | The carry weight at which noise factor reaches its maximum (2.0×). Lower = small loads feel loud; higher = only extreme overloading matters. |
| `NoiseSensitivityMultiplier` | 1.0 | 0.5–1.5 | Scale of the weight-to-noise effect. At 0.5: full load = 1.5× noise. At 1.5: full load = 2.5× noise. Values above 1.5 make weight punishing enough to discourage gathering runs. |

---

**Group 2 — Structure Footprint Costs**

| Structure | Placement Footprint | Persistent Footprint (per in-game hour) | Stacking Penalty per Duplicate | Safe Ranges |
|-----------|--------------------|-----------------------------------------|-------------------------------|-------------|
| Condensate Trap | 0.3 | None | 0.2 | Placement: 0.1–0.8; Stacking: 0.1–0.4 |
| Storage Cache | 0.4 | None | 0.2 | Placement: 0.2–0.8; Stacking: 0.1–0.4 |
| Crafting Bench | 0.4 | None (per-action only) | 0.0 | Placement: 0.2–0.8 |
| Spore-Resin Shelter | 1.0 | 0.1 | 0.4 | Placement: 0.5–2.0; Persistent: 0.05–0.3; Stacking: 0.2–0.7 |
| Thermal Vent Tap | 3.0 | 0.3 | 0.5 | Placement: 1.5–5.0; Persistent: 0.1–0.5; Stacking: 0.3–1.0 |

*Tuning intent:* A minimum-survival base (1× Condensate Trap + 1× Storage Cache + 1× Crafting Bench) totals 1.1 placement footprint. Adding 1× Shelter brings it to ≈ 2.1 — designed to sit in the Elevated predator aggression tier. A Tier 3 base with a Vent Tap reaches 5.5+ total, entering the Hunting tier — consistent with late-game difficulty escalation.

---

**Group 3 — Resource Restoration**

| Knob | Reference Value | Safe Range | Governs |
|------|----------------|-----------|---------|
| `BaselineMaximum` (food, water, oxygen) | 100 units (each) | 80–150 | The resource bar ceiling. Changing this invalidates all authored restore values — change only at a pre-production milestone, not during playtesting. |
| Root Pulp Compress `food_restore` | 25 units | 15–35 | 25% of baseline per use. Below 15: food management becomes too punishing. Above 35: food pressure disappears. |
| Membrane Filter `water_restore` | 55 units | 35–70 | Higher than food because water is also managed passively via Condensate Trap — the filter is used situationally, not continuously. |

*Note: no MVP oxygen consumable exists. Oxygen is managed through Ember Cell (drain reduction) and biome awareness. If an oxygen consumable is added post-MVP, reference restore should not exceed 40 units — higher amounts convert oxygen from a managed pressure into an emergency button.*

---

**Group 4 — Tool Efficiency and Disturbance**

| Tool | `efficiency_multiplier` | `disturbance_footprint_cost_per_use` | Safe Ranges |
|------|------------------------|--------------------------------------|-------------|
| Fissure Spike | 1.0 (baseline) | 10.0 | Efficiency: fixed baseline; Disturbance: 5–20 |
| Carapace Blade | 3.0 | 4.0 (60% less than Fissure Spike) | Efficiency: 2.0–4.0; Disturbance: must remain ≤ 40% of Fissure Spike value |
| Ember Cell | — | 0.0 | See Group 5 for passive drain reduction |
| Disturbance Muffle | Modifier: ×0.7 multiplier to active Harvesting tool `disturbance_footprint_cost_per_use` | 0.0 (Modifier type) | Multiplier safe range: 0.55–0.85 (i.e., 15%–45% reduction). Below 0.55: stealth becomes trivial. Above 0.85: effect is barely perceptible. |
| Thermal Lance | 3.0 | 22.0 | Efficiency: 2.5–4.0; Disturbance: 15–35 |

---

**Group 5 — Tool Passive Effects**

| Knob | Reference Value | Safe Range | Governs |
|------|----------------|-----------|---------|
| Ember Cell oxygen drain reduction | 15% | 5–25% | Amount by which Ember Cell reduces the player's oxygen drain rate. Above 25%: Rift Zone loses tension. Below 5%: tool feels useless. |
| Ecological Anchor suppression radius | 15 m | 8–25 m | Radius within which disturbance `InitialStrength` is reduced. Below 8m: working zone is too small. Above 25m: Anchor becomes base-wide immunity, removing consequence. |
| Ecological Anchor `InitialStrength` reduction | 40% | 20–60% | Disturbance reduction before propagation. Below 20%: effect imperceptible. Above 60%: effectively nullifies disturbance in base area. |

---

**Group 6 — Per-Category Reference Weights**

Authoring guidelines, not enforced per-record values. Authors should use these as starting points.

| Category | Reference Weight (kg/unit) | Safe Range | Rationale |
|----------|---------------------------|------------|-----------|
| RawMaterial (biological) | 0.5 | 0.2–1.0 | Light, abundant — stacks to 20; total slot weight manageable |
| RawMaterial (geological) | 1.0 | 0.5–2.0 | Denser — stacks to 12; heavier per slot |
| Component | 0.5 | 0.2–1.0 | Dense but small; stacks to 5 |
| Consumable | 0.5 | 0.2–1.0 | Carried in quantity; should not dominate carry weight |
| Tool | 2.0 | 1.0–4.0 | Significant — 2 tools equal the weight of 8 biological material stacks |
| Structure | 3.0 | 2.0–5.0 | Heaviest — carrying 2 unbuilt shelters generates noticeable movement noise |

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

**AC-1 — Schema validation passes (hard errors)**
Given: the full MVP item database is loaded into the validation pipeline (13 craftable/structure records + approximately 10 raw material records). When: validation runs. Then: zero ITEM-001 through ITEM-022 hard errors are reported and all records are accepted. Any single missing required field, duplicate item_id, or constraint violation causes the load to be rejected with a specific error code. Note: raw material records are counted separately from the 13 craftable records; the validation pipeline must accept the full set.

**AC-2 — RawMaterial records are always Tier 1**
Given: any item record with `category = RawMaterial`. When: its `tier` field is read. Then: the value is `1`. Any RawMaterial record with tier ≠ 1 triggers validation error ITEM-011 and is rejected.

**AC-3 — Tool and Structure stack sizes enforced**
Given: a Tool or Structure record with `stack_size_max` authored at any value other than 1. When: the validation pipeline runs. Then: hard error ITEM-006 or ITEM-007 is raised and the record does not load. When the record has `stack_size_max = 1`: validation passes.

**AC-4 — MovementNoiseFactor formula output at reference values**
Given: `MaxCarryWeight = 25 kg`, `NoiseSensitivityMultiplier = 1.0`. When: player carries `TotalCarryWeight = 0 kg`. Then: `MovementNoiseFactor = 1.0` (± 1e-6f). When: player carries `TotalCarryWeight = 25 kg`. Then: `MovementNoiseFactor = 2.0` (± 1e-6f). When: player carries `TotalCarryWeight = 30 kg` (above MaxCarryWeight). Then: `MovementNoiseFactor` is clamped at 2.0.

**AC-5 — Structure stacking formula correctness at n = 2**
Given: `BaseFootprintCost = 1.0` (Spore-Resin Shelter), `StackingPenalty = 0.4`, `n = 2` (one already placed). When: `EffectiveFootprintCost(n)` is computed. Then: the result equals `1.0 × (1 + 1 × 0.4) = 1.4` (± 0.01). This is a pure formula unit test — it does not depend on the Ecological Disturbance system. Integration testing of disturbance event delivery is deferred to the Ecological Disturbance GDD.

**AC-6 — Resource restoration clamping**
Given: player food level at 90 units. When: player uses a Root Pulp Compress (`food_restore = 25`). Then: food level becomes 100 (not 115). No "wasted restoration" value is surfaced to the player in any UI element.

**AC-7 — `harvest_tool_required` blocks without correct tool**
Given: any RawMaterial record with `harvest_tool_required = "fissure-spike"` (non-empty). When: player attempts to harvest a resource node of this type without a Fissure Spike in the active tool slot. Then: the harvest action does not execute and no items are added to inventory. When: player equips a Fissure Spike and attempts harvest. Then: the harvest succeeds and drop quantities are within `[node_drop_quantity_min, node_drop_quantity_max]`.

**AC-8 — Knowledge gate `craftable` flag evaluates false when gate unmet**
Given: the Carapace Blade recipe record has gate `gate_type = Event`, `event_id = "hunt_state_escaped_shallows"`. When: Knowledge/Progression Tracking reports that event has not been triggered. Then: the Crafting system's `craftable` evaluation for that recipe returns `false`. Note: this AC tests the gate evaluation logic within Item Database schema scope. The Crafting and UI GDDs own the test for how a `craftable = false` recipe is visually presented.

**AC-9 — Compound gate requires ALL conditions simultaneously**
Given: the Thermal Lance recipe has two gate conditions: `ActivityCount` (≥5 Rift Zone harvests with Carapace Blade) and `Event` (`rift_zone_hunt_escaped`). When: only one condition is satisfied (either one). Then: the compound gate `craftable` evaluation returns `false`. When: both conditions are simultaneously satisfied. Then: the evaluation returns `true` synchronously. The timing of crafting UI refresh is a Crafting system concern, not an Item Database concern.

**AC-10 — Structure footprint stacking computation fires on placement**
Given: any Structure with `disturbance_footprint_cost > 0` is placed. When: placement completes. Then: `EffectiveFootprintCost(n)` is computed using the current count of same-item_id structures + 1, producing a value ≥ `disturbance_footprint_cost` (± 0.01). This value is passed to Ecological Disturbance as the event's initial strength. Ecological Disturbance event reception and propagation are tested in that system's GDD — this AC tests only that the correct value is computed and passed.

**AC-11a — `biome_affinity` field correctly encodes placement restriction**
Given: a RawMaterial record with `biome_affinity = ["shallows"]`. When: a biome placement query asks whether this material may spawn in `"rift-zone"`. Then: the field's value does not contain `"rift-zone"`, and the placement is rejected at the data layer. This AC tests the record's data content, not the World Generation system. AC-11b (World Generation placement enforcement from this field) is deferred to the World Generation GDD.

**AC-12 — Biome boundary exclusion zone blocks placement**
Given: player attempts to place any Structure at a point P measured at exactly 4.0m perpendicularly from the nearest biome boundary polygon segment. When: Base Building evaluates placement (querying boundary polygon geometry per EC-8). Then: placement is rejected. When the same test is run at 6.0m from the boundary polygon (all other constraints enumerated in the Base Building GDD being met): placement is accepted. Note: "all other constraints" is a precondition enumerated in the Base Building GDD — this AC is dependent on that list being defined before it can be fully executed.

**AC-13 — Deprecated item_id in save data loads without crash**
Given: a save file containing an `item_id` that is marked `deprecated` in the current database. When: the save is loaded. Then: (a) the game does not crash or throw an unhandled exception, (b) the deprecated item occupies its original save slot displaying a `deprecated` badge, (c) stack/split/drop/consume actions on non-deprecated items in adjacent slots execute without error, (d) use and equip actions on the deprecated slot produce no effect and no inventory change.

**AC-14 — TLC bootstrap crystals exist at fixed world locations**
Given: World Generation runs with any procedural seed value. When: the world is generated. Then: exactly **two** Thermal Lattice Crystal world props exist at the designated fixed vent fracture location near the Rift Zone boundary. This count must not vary with seed (the props are not procedurally placed). Verifiable by querying world prop positions at generation time against the fixed coordinates reserved in World Generation.

**AC-15 — Consumable with all restore fields at zero is rejected**
Given: a Consumable record with `food_restore = 0`, `water_restore = 0`, `oxygen_restore = 0`. When: the validation pipeline runs. Then: hard error ITEM-013 is raised and the record does not load.

**AC-16 — `node_drop_quantity_min > node_drop_quantity_max` is rejected**
Given: a RawMaterial record with `node_drop_quantity_min = 5`, `node_drop_quantity_max = 3`. When: the validation pipeline runs. Then: a hard validation error is raised and the record does not load.

**AC-17 — `weight_kg` below minimum is rejected**
Given: any item record with `weight_kg = 0.005` (below the 0.01 minimum). When: the validation pipeline runs. Then: a hard validation error is raised and the record does not load.

**AC-18 — `efficiency_multiplier` out of range is rejected**
Given: a Tool record with `efficiency_multiplier = 6.0` (above the 5.0 maximum). When: the validation pipeline runs. Then: a hard validation error is raised and the record does not load.

**AC-19 — Dangling `harvest_tool_required` reference is caught at load**
Given: a RawMaterial record with `harvest_tool_required = "nonexistent-tool-id"` (no matching item_id in the database). When: the validation pipeline runs. Then: validation error ITEM-018 is raised and the record does not load (or a soft warning is raised and logged, per ITEM-018 specification).

**AC-20 — `is_placeable = true` on a non-Structure record is rejected**
Given: a Tool record with `is_placeable = true`. When: the validation pipeline runs. Then: a hard validation error is raised and the record does not load.

**AC-21 — Deprecated item_id cannot be reused for a new record**
Given: an authored record whose `item_id` matches an existing record with `status = deprecated` in the database. When: the validation pipeline runs. Then: a hard validation error (duplicate item_id) is raised and the new record does not load.

**AC-22 — `description_hidden` contains no mechanical numbers or item IDs (ITEM-022)**
Given: a Tier 1 item record whose `description_hidden` field contains a numeric value (e.g., "restores 25 food") or a named item_id (e.g., "used in fissure-spike crafting"). When: the validation pipeline runs. Then: validation warning ITEM-022 is raised. This is a soft warning (not a hard error) — records with the violation load but are flagged for content review. Tier 2 and 3 records are exempt from this check.

## Open Questions

- **`in_game_day_duration_s` registration**: EC-10 defines 1,200 seconds (20 real-world minutes) as one in-game day. This constant must be registered in `design/registry/entities.yaml` before the Crafting GDD is authored (any SustainedBehavior gate using `duration_days` depends on it). Pending registry update.
- **Modifier slot equip rules**: The Modifier ToolType introduces a new passive equip slot. The Inventory GDD must specify: (a) how many Modifier slots exist (1? 2?), (b) whether Modifier tools degrade on timer or not at all, (c) whether they appear on the player character's visible model. These are Inventory decisions that reference this GDD's ToolType definition.
- **Compound gate multi-condition hint strategy**: The GDD defines a single `display_hint` string per KnowledgeGate entry. For compound gates (Thermal Lance, Ecological Anchor), the player cannot tell which specific condition is blocking them. The Crafting GDD must decide: show one hint per unmet condition, or show a single compound hint? This affects crafting UI complexity.
- **Thermal Vent Tap recipe**: The Vent Tap requires 5× TLC (noted in EC-1). Its full recipe (other ingredients, Crafting Bench tier requirement, any additional gates) is owned by the Crafting GDD. Flag for the Crafting GDD author.
- **Raw material record authoring**: Approximately 10 raw material records (Dried Root Fibre, Fractured Flint Shard, Condensate Glob, Stretched Membrane, Hardened Carapace Plate, Crystalline Secretion, Bioluminescent Cap, Silicate Powder, Dampening Spore Mass, Thermal Lattice Crystal) are referenced as crafting inputs in Rule 6 but not formally authored in this document. Their full records (biome_affinity, drop quantities, harvest_tool_required) must be authored before the Resource Node GDD is finalized.
