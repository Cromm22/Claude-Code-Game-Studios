# Biome System

> **Status**: Draft — Revised (2026-04-22). Re-review pending.
> **Author**: Game Designer + Systems Designer + World Builder
> **Last Updated**: 2026-04-22
> **Implements Pillar**: Pillar 1 (The World Is Alive), Pillar 2 (Knowledge Is Survival)

## Summary

A biome is a named environment zone defined by a fixed set of properties that downstream systems consume to modulate their behavior. Biomes are static authored records — not runtime systems — that answer one question for each consumer: "how does this environment change what you do?" MVP scope is 2 biomes; full vision is 6+ across 3+ planets.

> **Quick reference** — Layer: `Foundation` · Priority: `MVP` · Key deps: `None`

## Overview

A biome is a named environment type in Terranova, defined by a set of fixed properties that three downstream systems read to govern their runtime behavior. Biomes do not change state during play — they are authored data records, established at world-generation time and held constant until the player transitions to a new planet.

Three systems consume biome properties:
- **Resource Management** reads drain-rate modifiers to accelerate or slow the depletion of oxygen, food, and water by environment
- **Ecological Disturbance** reads biological density tier to determine propagation distance and decay speed of disturbance signals through the local ecosystem
- **World Generation** reads the biome set and their transition rules to tile and layout the planet surface

Each biome has a distinct ecological personality — defined by biological density, ambient temperature offset, succession stage distribution, dominant transition type to adjacent biomes, and the specific subset of art-bible visual rules that apply to it. These authored properties are the foundation from which all runtime world behavior in that zone emerges.

**MVP scope**: 2 biomes — The Shallows (dense biological, humid, high disturbance propagation) and The Rift Zone (sparse geological, cold, low propagation with concentrated hydrothermal pockets).

**Full vision scope**: 6+ biomes across 3+ planets. Each planet's biome set has a distinct resource identity and ecological personality. Second planet validates the multi-world loop; biome definitions must be authored per planet, not reused across them.

## Player Fantasy

The biome system exists because tension must have texture. A survival game with one environment can sustain pressure, but not *variety* of pressure — and variety is what prevents desensitization across a multi-hour session.

In The Shallows, danger is proximity. The predator moves through dense biological growth the player cannot see through, cannot move silently across, and cannot quickly navigate. Disturbance radiates readily through the humid, biologically rich medium. The player's dread is about what is already reacting to them.

In The Rift Zone, danger is exposure. The biological density that provided resource richness and cover in The Shallows is gone. Resources cluster near hydrothermal vents — fixed, visible locations the player must commit to visiting. The player can see farther and be seen farther. The dread is different: not what is reacting to them, but what is watching.

The player fantasy is of a world that challenges survival fluency differently in every zone. The Shallows teaches the player to read biological signals and move with ecological care. The Rift Zone teaches exposure management and resource commitment under visibility pressure. Mastery of one does not grant mastery of the other.

Each biome is a distinct stage the predator uses. Its behavioral logic is constant; the environment is the variable that determines how that logic expresses as threat. Two biomes produce two textures of fear from one predator.

**What the Biome system delivers directly:** Higher resource drain in The Rift Zone makes exposure consequential — the player cannot simply wait out a threat by standing still. Different propagation parameters make the disturbance footprint of identical actions feel qualitatively different per biome.

**What downstream systems must deliver for the full fantasy:** The predator's sensory inputs and behavioral expression differ per biome (→ Predator Perception GDD, Predator State Machine GDD). The ambient audio layer communicates ecological density as a learnable signal (→ Adaptive Audio GDD). The ecological disturbance signal type readable by the player changes between biomes (→ Ecological Disturbance GDD). The biome system is a substrate that makes the fantasy legible and consequential — not its sole carrier.

**Serves**: Pillar 4 (Tension Over Comfort — primary), Pillar 1 (The World Is Alive — the ecology of each biome genuinely shapes how threat operates), Pillar 2 (Knowledge Is Survival — biome-specific knowledge does not transfer automatically).

## Detailed Design

### Core Rules

1. A biome is a static authored data record. Biomes do not change state at runtime — they are read at world-generation time and held constant for the duration of the session.
2. Every biome record contains exactly this property schema:

| Property | Type | Range | Consuming System | How Used |
|---|---|---|---|---|
| `biome_id` | string (enum) | e.g. `"shallows"`, `"rift_zone"` | World Generation | Unique lookup key; transition rule resolution |
| `display_name` | string | — | UI | Scanner readout label |
| `ambient_temperature_offset_k` | float | −1200 to +600 K | Art pipeline (lighting) | Added to planet baseline color temp; drives shadow fill tint. Read-only at runtime — no gameplay effect. |
| `biological_density_tier` | enum | `Sparse`, `Medium`, `Dense` | Ecological Disturbance | Authoring sanity check only; explicit float values override at runtime |
| `oxygen_drain_modifier` | float | 0.5–2.0 | Resource Management | Multiplied against base O₂ drain rate |
| `food_drain_modifier` | float | 0.5–2.0 | Resource Management | Multiplied against base food drain rate |
| `water_drain_modifier` | float | 0.5–2.0 | Resource Management | Multiplied against base water drain rate |
| `propagation_radius_m` | float | 20–200 m | Ecological Disturbance | Max radius a disturbance signal expands from its origin before reaching zero |
| `propagation_decay_rate` | float/sec | 0.01–0.20 | Ecological Disturbance | Exponential strength decay over time |
| `transition_type` | enum | `Gradual`, `Hard` | World Generation | `Gradual` = blended band; `Hard` = immediate boundary |
| `transition_band_width_m` | float | 0–80 m | World Generation | Width of blended overlap band; ignored if `Hard` |
| `allowed_adjacent_biomes` | string[] | any biome_id | World Generation | Prevents ecologically nonsensical adjacency |

3. Drain modifiers are multiplicative with all other drain-rate factors (activity level, equipment). They do not cap or floor the effective drain rate.
4. In a **Gradual** transition band, drain modifiers and propagation parameters begin interpolating the moment the player crosses into the band. Full target biome values apply only after the player exits the far edge of the band. There is no step-function snap; the interpolation is the transition. In a **Hard** transition, properties snap to the new biome's values at the boundary line with no interpolation.
5. In a Gradual transition band, all three drain modifiers and both propagation parameters interpolate linearly between V_A (entry biome) and V_B (destination biome) based on the player's normalized position across the band width. Interpolation begins at x = 0 (band entry edge) and completes at x = W (band exit edge).
6. When a disturbance event fires, the Ecological Disturbance system queries the biome at the event origin point. Signal strength at point P at time t: `S(P,t) = InitialStrength × (1 − dist(origin,P) / propagation_radius_m) × e^(−decay_rate × t)`, clamped [0, 1]. Points beyond `propagation_radius_m` receive zero signal.
7. `biological_density_tier` is an authoring sanity check. Explicit float values always win at runtime.
8. Biome boundary polygons and transition zone geometry are baked into terrain metadata at world-generation time. They are not computed at runtime.
9. No structures may be placed within 5 m of any biome boundary (either side). Enforced at build time by World Generation boundary data.

---

### Biome Profiles

#### The Shallows

**Diegetic identity**: Low-elevation basin retaining atmospheric condensate. High moisture and nutrient-rich sediment produce a high-productivity zone — the planet's ecological baseline. Dense ambient bioluminescence is a byproduct of inter-organism signaling at high population density: organisms that cannot move fast use light to communicate threat, attract mates, and warn competitors. High density = high signal traffic = persistent ambient glow.

**Resource distribution**: Abundance is real. Organic resources (food, fiber, biological reagents) are diffusely distributed because productive pressure fills every available niche. No single node is uniquely valuable. The cost of extraction is ecological saturation everywhere — every gathering action disturbs an existing relationship.

**Predator behavior**: The predator reads the bioluminescent signal network as a sensory layer. Disturbance propagates through that network like ripples — organisms react, light patterns shift, the medium transmits. The predator reads the medium, not the player directly. Response time is fast; closing distance is slow (dense terrain). The player is warned by the ecosystem before the predator arrives.

| Property | Value | Rationale |
|---|---|---|
| `ambient_temperature_offset_k` | +300 K (≈5500 K) | Humid, warm — art bible locked |
| `biological_density_tier` | Dense | art bible locked |
| `oxygen_drain_modifier` | 0.80 | Dense biological growth implies higher ambient O₂ partial pressure |
| `food_drain_modifier` | 1.10 | High metabolic cost from heat and biological activity |
| `water_drain_modifier` | 0.75 | High humidity reduces evaporative water loss |
| `propagation_radius_m` | 120 m | Dense medium; a single tool strike can alert the predator across a medium clearing |
| `propagation_decay_rate` | 0.04/sec | Slow decay; the ecosystem stays agitated after disturbance |
| `transition_type` | Gradual | art bible locked — ecological gradient transition |
| `transition_band_width_m` | 40 m | Canonical width for the Shallows↔Rift Zone boundary. Applied in both crossing directions (see Formulas — single W per biome pair rule). |

---

#### The Rift Zone

**Diegetic identity**: Tectonically active fracture system exposing subsurface geology. Cold from altitude and loss of the insulating moisture layer that keeps The Shallows temperate. Geological instability and thermal extremes prevent the dense substrate networks of The Shallows from establishing. Life exists only at hydrothermal vents where geothermal energy replaces solar productivity. Sparse bioluminescence follows: low population density means near-zero inter-organism signaling pressure.

**Resource distribution**: Mineral resources (rare earths, thermal compounds, structural materials) cluster at vent systems and fracture edges — fixed, limited, and visually unambiguous (steam venting, color-shifted rock, heat shimmer). The player cannot miss them. The player also cannot approach them without being visible from a distance. Resource commitment is mandatory: open ground must be crossed to reach the only places the needed materials exist.

**Predator behavior**: Without the bioluminescent signal medium, the predator loses its passive sensory network. It hunts by direct observation — movement, heat differential, sound traveling across open terrain with no biological dampening. Response time is slow; closing distance is fast (open ground, the predator's terrain advantage). The player has no ecosystem warning. The predator may not know the player is present — until it does, at which point it has clear sight.

| Property | Value | Rationale |
|---|---|---|
| `ambient_temperature_offset_k` | −800 K (≈4400 K) | Cold, geological — art bible locked |
| `biological_density_tier` | Sparse | art bible locked |
| `oxygen_drain_modifier` | 1.40 | Thin/cold atmosphere increases breathing effort |
| `food_drain_modifier` | 1.20 | Cold increases caloric cost |
| `water_drain_modifier` | 1.50 | Dry, cold, high desiccation; makes vent runs time-pressured |
| `propagation_radius_m` | 35 m | Sparse medium; disturbance is nearly local |
| `propagation_decay_rate` | 0.12/sec | Fast decay; the sparse ecosystem does not sustain signal |
| `transition_type` | Gradual | art bible locked — geological boundary is 10–15 m wide |
| `transition_band_width_m` | 40 m | Slightly wider than minimum to allow visible terrain shift before rift edge |

---

### States and Transitions

Biomes themselves are stateless — they do not change during play. The following rules govern transition zone behavior when the player moves between biomes.

| Condition | Behavior |
|---|---|
| Player enters a `Gradual` transition band | Drain modifiers and propagation parameters begin linear interpolation between the two adjacent biome values |
| Player exits the transition band into a new biome | Interpolation ends; target biome values apply fully |
| Player crosses the rift edge terrain discontinuity | Canopy absent, ground surface converts to geological base within 5 m; audio crossfade should be complete by this point |
| Disturbance event fires within a transition band | Disturbance system queries interpolated propagation values at the event's origin point |
| Player attempts to build within 5 m of any boundary | Build action blocked; World Generation boundary data enforces this at the placement validation step |

---

### Survival Knowledge Transfer

What a player who has mastered The Shallows knows — and what transfers to The Rift Zone. **These non-transfers are design targets, not behaviors enforced by the Biome data records alone.** Each row below identifies a required behavior from a downstream GDD — the Biome system provides the parameter difference that makes the non-transfer possible; the named system must implement the divergent behavior.

| Skill | Transfers | What Changes |
|---|---|---|
| Reading disturbance signals | No | Signal medium changes entirely. Bioluminescent pulse-reading is useless. Audio travels farther with no biological dampening. |
| Resource extraction technique | Partially | Same physical technique; radically different disturbance consequence. A strike that caused diffuse ripple in The Shallows creates a loud, directional signal in The Rift Zone. |
| Predator pattern-reading | No | The predator's behavioral logic is constant; its sensory input and behavioral expression change completely. "Wait for bioluminescent calm before moving" fails immediately. |
| Movement discipline | Yes, inverted | The Shallows: minimize organism disturbance underfoot. The Rift Zone: minimize audio and visual silhouetting — opposite spatial attention. |
| Resource prioritization | No | The Shallows trains the player to treat abundance as given. The Rift Zone reintroduces scarcity as the primary constraint. |

**The key unlearn**: The Shallows teaches that the environment is watching you through biology. The Rift Zone teaches that the environment is not watching you at all — which means the predator uses entirely different methods to locate you, and the player's threat-detection repertoire must be rebuilt from scratch.

---

### Spatial Rules

1. Biome boundaries are authored at world-generation time, not generated procedurally at runtime.
2. The Rift Zone boundary is defined by a hand-authored geological discontinuity contour placed by level design. The Shallows boundary is derived from it.
3. No biome boundary may be placed within 200 m of the player spawn point.
4. The transition zone between The Shallows and The Rift Zone is 10–15 m wide, measured perpendicular to the rift edge. Width may vary per segment within that range.
5. Biological substrate does not cross the rift edge: flora and ground-cover organisms terminate 0–3 m from the rift edge on the Shallows side. Geological base material begins 0–5 m from the rift edge on the Rift Zone side.
6. The predator may path through the transition zone without restriction. The boundary is not a behavioral fence.

**Player orientation signals** *(each must be independently sufficient; no text or waypoint markers):*
- **Terrain drop**: Rift edge has a minimum 3 m vertical drop within 5 m of the geological boundary, visible from 40 m on the Shallows approach.
- **Canopy termination**: Biological canopy must be absent within 20 m of the rift edge. Open sky above the transition zone is required.
- **Ground surface contrast**: Biological substrate underfoot shifts to bare geological material within the transition zone, readable at the player's eye height (approx. 1.7 m).
- **Audio crossfade**: Ambient biome audio begins crossfading at 30 m from the rift edge and completes by 5 m past it. (Audio director owns the crossfade curve; the spatial trigger point is a level design constraint.)
- **Bioluminescent drop**: In low-light conditions, the drop in bioluminescent frequency is a secondary orientation signal. Not reliable in daylight.

**Biome size targets:**

| Biome | Minimum Area | Maximum Area | Rationale |
|---|---|---|---|
| The Shallows | 90,000 m² | 640,000 m² | Min: accommodates 15-minute gathering session; Max: end-to-end crossing ≤ 2.5 min at walking speed |
| The Rift Zone | 40,000 m² | 250,000 m² | Min: ≥ 3 spatially separated hydrothermal vent clusters; Max: hostile zone stays secondary play space in MVP |

*Cross-biome traversal target*: Walking from the far edge of The Shallows to the far edge of The Rift Zone, including transition, should take 3–5 minutes at walking speed. (Movement speed assumed from genre norms — confirm with Player Controller GDD before locking size constraints.)

---

### Interactions with Other Systems

| System | Direction | Interface |
|---|---|---|
| Resource Management | Reads from Biome | Reads `oxygen_drain_modifier`, `food_drain_modifier`, `water_drain_modifier` on biome entry; linearly interpolates in transition bands. Applied as multiplier to base drain rates. |
| Ecological Disturbance | Reads from Biome | Reads `propagation_radius_m` and `propagation_decay_rate` at event origin point; applies exponential signal strength formula. `biological_density_tier` used for authoring validation only. |
| World Generation | Reads from Biome | Reads full biome record set at planet generation time. Uses `transition_type`, `transition_band_width_m`, and `allowed_adjacent_biomes` to construct layout and bake boundary metadata into terrain. |
| Art Pipeline / Lighting | Reads from Biome | Reads `ambient_temperature_offset_k` to configure color temperature offset and secondary shadow fill tint. Runtime read-only — no gameplay modification. |

## Formulas

### Formula 1: Transition Band Property Interpolation

The Biome system owns one formula — the interpolation of float properties across a Gradual transition band.

```
V(x) = V_A + (V_B − V_A) × (x / W)
```

**Variables:**

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Origin biome value | V_A | float | property-dependent | Property value in the entering biome (origin side) |
| Destination biome value | V_B | float | property-dependent | Property value in the destination biome |
| Player position in band | x | float | 0 – W meters | Distance into the transition band, measured perpendicular to the boundary from the origin biome edge |
| Band width | W | float | 0–80 m | `transition_band_width_m` of the receiving biome record |
| Interpolated value | V(x) | float | [min(V_A, V_B), max(V_A, V_B)] | Applied property value at position x |

**Output range:** Strictly bounded between V_A and V_B when x ∈ [0, W]. Outside this range, the formula extrapolates and produces values outside [V_A, V_B] — this is not a design intent but a mathematical consequence.

**Caller contract (required):** All callers must validate that x ∈ [0, W] before invoking the formula. This is enforced by transition band entry/exit logic: x is only computed while the player is confirmed to be inside the band. No internal clamping is performed. If x arrives outside [0, W], the calling system has a logic error in its position tracking.

**Applies to these properties:** `oxygen_drain_modifier`, `food_drain_modifier`, `water_drain_modifier`, `propagation_radius_m`, `propagation_decay_rate`. Does not apply to enum properties (`biological_density_tier`, `transition_type`) or art-pipeline-only properties (`ambient_temperature_offset_k`).

**Single W per biome pair:** Each biome pair shares one canonical transition_band_width_m, applied symmetrically in both crossing directions. For the Shallows↔Rift Zone boundary, W = 40 m in both directions. The `transition_band_width_m` field on each biome record must match for any shared boundary — World Generation must validate this at generation time. Asymmetric W values at a shared boundary are an authoring error.

**Example** — Shallows → Rift Zone, `propagation_radius_m` at the midpoint of a 40 m band:
- V_A = 120 m, V_B = 35 m, W = 40 m, x = 20 m
- `V(20) = 120 + (35 − 120) × (20 / 40) = 120 − 42.5 = **77.5 m**`

At the midpoint, the Ecological Disturbance system uses a propagation radius of 77.5 m — meaningfully reduced from The Shallows but not yet the near-local Rift Zone value.

---

### Cross-System Formula References

The following formulas are formally owned by downstream GDDs. The Biome system supplies their inputs; it does not own the computations.

**Disturbance Signal Strength** (owned by Ecological Disturbance GDD):
```
S(P,t) = InitialStrength × (1 − d / propagation_radius_m) × e^(−decay_rate × t)
```
Biome supplies: `propagation_radius_m`, `propagation_decay_rate` at the event origin point. When a disturbance event fires inside a transition band, the values passed to this formula are the interpolated outputs V(x) — not the raw values of either adjacent biome.

**Effective Drain Rate** (owned by Resource Management GDD):
```
EffectiveDrainRate = BaseDrainRate × biome_drain_modifier × [additional modifiers]
```
Biome supplies: `oxygen_drain_modifier`, `food_drain_modifier`, `water_drain_modifier`.

## Edge Cases

**EC-1 — Player stands exactly on the boundary line (x = 0 or x = W):**
Apply the formula normally. `x = 0` resolves to `V_A` exactly; `x = W` resolves to `V_B` exactly. No special boundary-snapping or sentinel value needed.

**EC-2 — Player traverses the transition band in reverse (Rift Zone → Shallows):**
`V_A` and `V_B` do not swap based on travel direction. `V_A` is always anchored to the biome the player entered the band from; `V_B` is always the biome at the far exit edge. If the player reverses, `x` counts back toward 0 using the same anchors — the values remain bounded and the formula stays valid.

**State ownership:** The Biome system is stateless. **Resource Management GDD owns the `band_entry_biome` player state field.** Resource Management records the entry biome when the player first crosses a transition band edge and uses it to anchor V_A and V_B for all formula evaluations during that band traversal. This field is reset when the player exits the band on either side. Resource Management must document this field and its update triggers explicitly in its GDD.

**EC-3 — Gradual transition biome with `transition_band_width_m = 0`:**
This creates a division-by-zero in `V(x)`. World Generation must validate that `W > 0` for any biome flagged as `Gradual` — this is a content authoring error that must never reach runtime. If a zero-width Gradual biome somehow reaches the game, treat it as `Hard` at runtime and log the authoring error.

**EC-4 — Player position discontinuity (death/respawn, future fast-travel):**
Crossing-based transition detection will not fire for position teleports. Resource Management must query the current biome from the player's new position after any discontinuity — not rely on boundary-crossing events alone. This is a required interface contract that the Resource Management GDD must document.

**Mid-band respawn fallback:** If a position discontinuity drops the player inside a transition band with no recorded entry direction (fresh query, no `band_entry_biome` in state), Resource Management assigns V_A = the biome with the lower `biome_id` (lexicographic, consistent with EC-7) and V_B = the other biome. This is a deterministic fallback with no gameplay significance — the player will exit the band within seconds and the correct biome will apply.

**EC-5 — Disturbance event originates inside a transition band:**
The disturbance signal uses the interpolated `V(x)` values at the event origin for all receivers. No per-receiver biome re-query is performed. This is established in Rule 5 (Detailed Design) and confirmed in Formulas. The Ecological Disturbance GDD must acknowledge it receives interpolated values, not raw biome values, when the origin is in a transition zone.

**EC-6 — Two simultaneous disturbance events from different biomes, signals overlap in space:**
The signals are independent; each carries its own interpolated parameters from its origin point. How overlapping signals compose (sum, max, weighted blend) is owned entirely by the Ecological Disturbance GDD — the Biome system has no composition logic. Flag as an open interface question for the Ecological Disturbance GDD author.

**EC-7 — Player stands exactly on a Hard boundary line between two adjacent biomes:**
Assign the boundary line to the biome with the higher `biome_id` (lexicographic sort). This is a deterministic authoring rule — no runtime ambiguity. The specific ordering does not affect gameplay meaningfully since Hard transitions are instantaneous; consistency matters more than which biome "wins."

**EC-8 — Player exploits transition band edges to maintain favorable drain modifiers:**
Valid and intentional. The linear interpolation formula produces genuinely intermediate values — standing near the Shallows end of a Shallows→Rift Zone band produces near-Shallows drain rates. Players who learn to read terrain and position deliberately are rewarded. The 5m no-build exclusion zone prevents permanent base exploitation; predator access through the band prevents indefinite loitering.

**EC-9 — Player oscillates repeatedly across a boundary to reset disturbance state:**
No exploit exists. Disturbance signal decay is time-based, not position-based — the Ecological Disturbance system tracks accumulated disturbance over time regardless of player position. Crossing a boundary does not reset or reduce disturbance level.

**EC-10 — 5m no-build exclusion zone creates a predictable navigation funnel:**
If transition boundaries are placed near key locations, players may learn to use the no-build corridor as a traversal route. This is a level design and spawn-placement concern, not a systems constraint. The Biome system correctly enforces the zone; how Level Design positions boundaries relative to key locations is out of scope here.

## Dependencies

### Upstream Dependencies (systems Biome depends on)

*None.* The Biome system is a Foundation-layer data record. It has no runtime dependencies on other systems — all biome properties are authored constants.

### Downstream Dependents (systems that depend on Biome)

| System | What It Reads from Biome | Interface Type | When Queried |
|--------|--------------------------|----------------|--------------|
| **Resource Management** | `oxygen_drain_modifier`, `food_drain_modifier`, `water_drain_modifier` | Read — drain modifier floats | On biome entry; on position discontinuity (EC-4) |
| **Ecological Disturbance** | `biological_density_tier`, `propagation_radius_m`, `propagation_decay_rate` | Read — propagation parameters | On disturbance event origin; passes interpolated values if origin is in transition band (EC-5) |
| **World Generation** | Full biome record set: `transition_type`, `transition_band_width_m`, `allowed_adjacent_biomes`, all resource placement hints | Read — authoring-time layout rules | At world generation time only; no runtime queries |

### Indirect Dependents (systems that depend on a dependent)

| System | Depends Via | What Changes |
|--------|-------------|--------------|
| **Predator State Machine** | Ecological Disturbance | Disturbance signal strength and radius differ by biome; predator response intensity scales with signal |
| **Predator Perception** | Ecological Disturbance | Disturbance signal propagation affects detection range in biome |
| **Fauna AI** | Ecological Disturbance | Scatter response radius and panic duration are downstream of disturbance parameters |
| **Resource Node** | World Generation | Resource node density and type distribution are biome-keyed |
| **HUD** | Resource Management | Drain rate changes manifest as HUD drain-rate display changes |
| **Base Building** | World Generation | No-build exclusion zone is enforced against world-generation-placed biome boundary data |

### Bidirectionality Requirement

Per design rules, each dependent GDD must reference the Biome system. The following contracts must be documented in their respective GDDs:

- **Resource Management GDD** must document: reads drain modifiers from Biome; re-queries on position discontinuity (not only on crossing events); owns and manages the `band_entry_biome` player state field used to anchor V_A and V_B for transition band interpolation (see EC-2)
- **Ecological Disturbance GDD** must document: reads propagation parameters from Biome; receives interpolated V(x) values when disturbance origin is in a transition band
- **World Generation GDD** must document: reads full biome record set; validates `transition_band_width_m > 0` for all Gradual biomes before generation

## Tuning Knobs

All biome properties are per-record authored constants — "tuning" the Biome system means editing biome records in the data layer (ScriptableObjects or equivalent). The knobs below are the properties most likely to require adjustment during playtesting, with safe ranges and the gameplay dimension each affects.

### Per-Biome Drain Modifier Knobs

| Knob | Current Value | Safe Range | Gameplay Dimension Affected | Risk If Tuned Too Low | Risk If Tuned Too High |
|------|---------------|------------|-----------------------------|-----------------------|------------------------|
| `oxygen_drain_modifier` (Shallows) | 0.80 | 0.60 – 1.00 | Oxygen survival pressure in dense biome | Below 0.60: The Shallows becomes a safe zone, removing ecological dread | Above 1.00: becomes indistinguishable from Rift Zone; biome contrast lost |
| `oxygen_drain_modifier` (Rift Zone) | 1.40 | 1.10 – 1.80 | Oxygen pressure in exposed/cold biome | Below 1.10: Rift Zone doesn't feel meaningfully more hostile than Shallows | Above 1.80: Rift Zone becomes effectively impassable without advanced gear |
| `food_drain_modifier` (Shallows) | 1.10 | 0.70 – 1.30 | Food pressure in dense biome | Negligible below 0.70 — food drain is secondary pressure | Above 1.30: food becomes primary pressure in Shallows, competes with oxygen dread. Note: current value 1.10 sits near the upper end — avoid tuning up without intentional justification |
| `food_drain_modifier` (Rift Zone) | 1.20 | 1.00 – 1.50 | Food pressure in exposed biome | Below 1.00: resource scarcity in Rift Zone has no survival cost | Above 1.50: stacks with oxygen pressure to make Rift Zone punishing before players adapt |
| `water_drain_modifier` (Shallows) | 0.75 | 0.55 – 0.95 | Water pressure; secondary to oxygen | Below 0.55: Shallows feels unrealistically forgiving for water | Above 0.95: water pressure approaches parity with food pressure |
| `water_drain_modifier` (Rift Zone) | 1.50 | 1.10 – 1.80 | Water pressure in arid cold — primary Rift Zone secondary stressor | Below 1.10: desiccation pressure not felt meaningfully | Above 1.80: stacks with O2 to make Rift Zone impassable without water gear |

### Per-Biome Disturbance Propagation Knobs

| Knob | Current Value | Safe Range | Gameplay Dimension Affected | Risk If Too Low | Risk If Too High |
|------|---------------|------------|-----------------------------|--------------------|-----------------|
| `propagation_radius_m` (Shallows) | 120m | 80m – 160m | How far a single disturbance event radiates in the dense biome | Below 80m: Shallows no longer feels "ecologically reactive"; small actions have negligible reach | Above 160m: nearly all player actions in The Shallows create overlapping signal fields; predator becomes omniscient |
| `propagation_radius_m` (Rift Zone) | 35m | 20m – 55m | Disturbance radius in sparse biome | Below 20m: Rift Zone resource extraction feels unpunished | Above 55m: Rift Zone propagation approaches Shallows baseline; biome contrast lost |
| `propagation_decay_rate` (Shallows) | 0.04/s | 0.02 – 0.08/s | How quickly disturbance fades between player actions in the dense biome | Below 0.02: signals never meaningfully fade; predator never loses the trail | Above 0.08: decay approaches Rift Zone baseline; The Shallows loses its persistent-signal identity |
| `propagation_decay_rate` (Rift Zone) | 0.12/s | 0.06 – 0.20/s | Faster decay makes each action a discrete, forgettable event | Below 0.06: Rift Zone disturbances persist like Shallows; different ecology not felt | Above 0.20: Rift Zone disturbances are effectively noise; predator loses the Rift Zone behavioral expression |

### Structural Knobs (World Generation Authoring)

| Knob | Current Value | Safe Range | Gameplay Dimension Affected |
|------|---------------|------------|------------------------------|
| `transition_band_width_m` (Shallows↔Rift Zone) | 40m | 25m – 80m | How long the transition experience lasts; 40m at average walk speed is ~8s of gradual interpolation. Applies symmetrically in both crossing directions | Below 25m: transition feels rushed; properties shift before environmental read is complete | Above 80m: player spends 16+ seconds in an intermediate survival state; valid but may reduce biome contrast clarity |
| Minimum biome size (Shallows) | 800m × 800m | 500m – unlimited | Ensures biome has enough interior to develop behavioral routines | Below 500m: players can't establish stable patterns before hitting transition |
| Minimum biome size (Rift Zone) | 600m × 600m | 400m – unlimited | Exposed biome; smaller minimum acceptable due to lower density | — |
| Spawn distance from biome boundary | 200m minimum | 150m – 300m | Ensures players learn The Shallows baseline before encountering Rift Zone | Below 150m: players may reach The Rift Zone before internalizing The Shallows rules |

### Knobs Not to Tune During Playtesting

- `ambient_temperature_offset_k` — World-building property that drives art direction (fog density, particle behavior, color temperature). Does not affect survival systems; change only if biome visual identity needs revision.
- `biological_density_tier` — Authoring-check field, not a continuous variable. Three valid values (Sparse, Moderate, Dense); does not interpolate and should not be treated as a dial.
- `allowed_adjacent_biomes` — Structural graph constraint. Changing it requires World Generation re-validation. Do not modify during playtesting.

## Visual/Audio Requirements

### Biome Visual Identity (Art Bible Cross-Reference)

Each biome has a distinct visual signature defined in the art bible. These are the constraints the Biome system places on art production — not style preferences but legibility requirements.

**The Shallows:**
- Dense biological canopy with bioluminescent undergrowth (Art Bible Section 5 — Biome Profiles: The Shallows). Haeckel-derived organic recursion in geometry (Art Bible Section 3 — Shape Language).
- High humidity particle layer: persistent mist/condensation at ground level. Visibility: medium range (~40m before foliage occlusion).
- The biological density must be visually legible — the player should feel enclosed, not open. Predator movement through the Shallows should produce visible canopy disturbance.

**The Rift Zone:**
- Sparse, exposed geology. Hydrothermal vent clusters serve as landmark anchors — the only biologically interesting fixed points in a visually austere field (Art Bible Section 5 — Biome Profiles: The Rift Zone).
- Low particle layer. High visibility range: player can see across the biome. This visual openness is the gameplay condition: the player can see far, and so can the predator.
- Color temperature significantly cooler than The Shallows. Art Bible Section 4 (Color System) defines the palette shift between biomes.

**Biome Boundary (both transition types):**
- The approaching transition must be legible within 20m of the transition band edge — the player should read environment change before they enter the band, not after. Visual legibility does not require UI labels; it requires the environmental change to be readable as a signal.
- Gradual boundaries: slow color temperature shift, progressive reduction in canopy density. Hard boundaries: cliff face, rock formation, or chemistry-visible geology change. Level Design owns boundary placement and the specific visual form of each boundary instance.
- The 5m no-build exclusion zone has no visible marker in the world (no waypoints, no highlighted edges per art bible anti-pillar). Players discover it by attempting to build.

### Biome Audio Requirements

- **The Shallows ambient layer**: rich biological soundscape — high density of creature presence, rustling, proximity indicators. Biological activity that communicates "this ecosystem is reacting." Adaptive Audio (VS scope) will consume biome state to mix the ambient layer.
- **The Rift Zone ambient layer**: sparse, wind-dominant, occasional geothermal sound (low-frequency hydrothermal events). Significantly less biological noise. Silence is the signal — absence of creature sound communicates the ecosystem's sparseness.
- **Biome transition (Gradual)**: ambient layers crossfade using an **equal-power curve** (each layer at -3 dB at the midpoint, producing approximately 0 dB net perceived output) across the 40 m transition band width. The crossfade shares the same spatial extent as the drain modifier interpolation but uses a different curve — drain modifiers use linear interpolation; audio uses equal-power. Conflating these two curves would produce a perceptual suck-out at the band midpoint. Adaptive Audio GDD (VS scope) owns full implementation.
- **Biome transition (Hard)**: ambient layer snaps at the boundary. No crossfade.
- No non-diegetic biome-entry notification sound at any boundary type. A Hard boundary ambient snap is diegetic (the world changed) and is permitted. It must not use a musical stinger, whoosh, or any sound that exists outside the world.
- **MVP audio fallback (before Adaptive Audio is implemented):** A simplified static-layer crossfade placeholder plays at MVP. Two fixed ambient layers (one per biome) crossfade based on the player's distance from the boundary, with no game-state-based mixing. The full Adaptive Audio system replaces this at VS scope. Visual and terrain cues carry primary orientation weight in MVP.

## UI Requirements

- The HUD is a diegetic visor projection system — it does not display a biome name, biome indicator, or boundary proximity warning at any time. Players learn which biome they are in through environmental reading. This is non-negotiable per Pillar 2 (Knowledge Is Survival) and the game's anti-UI-exposition stance.
- The HUD does display resource drain rates (or their visual proxy — the rate at which resource gauges deplete). When the player enters a transition band and drain modifiers begin interpolating, the drain rate display must track the interpolated value continuously without flickering or snapping. The display should feel like the environment is changing, not like a value is being updated.
- No HUD element is added to mark biome transitions, boundary proximity, or transition band entry. If playtesting reveals that players cannot learn the biome system through observation alone, the solution is environmental visual design — not UI labels.
- The HUD System GDD (Presentation layer, MVP scope) must reference these constraints as a requirements input.

## Acceptance Criteria

*Story type classification per coding-standards.md: Logic → automated unit test required (blocking). Integration → integration test or documented playtest required (blocking).*

**AC-1 — Shallows biome record contains correct drain modifier values:** The Shallows biome ScriptableObject (or equivalent data record) contains exactly `oxygen_drain_modifier = 0.80`, `food_drain_modifier = 1.10`, `water_drain_modifier = 0.75`. → Unit test (EditMode): load the Shallows biome record asset directly; read each field; assert equals authored value within `float.Epsilon`. No Resource Management call — this tests the data record, not its consumer. *Story type: Logic — automated unit test required.*

**AC-2 — Rift Zone biome record contains correct drain modifier values:** The Rift Zone biome record contains exactly `oxygen_drain_modifier = 1.40`, `food_drain_modifier = 1.20`, `water_drain_modifier = 1.50`. Cross-record consistency check: `rift.oxygen_drain_modifier / shallows.oxygen_drain_modifier = 1.75 ± 0.001`. → Unit test (EditMode): load both records; assert individual fields and ratio. Ratio check guards against silent drift in either record. *Story type: Logic.*

**AC-3 — Biome records contain correct propagation parameter values:** The Shallows record contains `propagation_radius_m = 120`, `propagation_decay_rate = 0.04`. The Rift Zone record contains `propagation_radius_m = 35`, `propagation_decay_rate = 0.12`. → Unit test (EditMode): load each record; assert field values directly. *Story type: Logic.*

*Note: A cross-system test verifying that Ecological Disturbance reads these values correctly at runtime — rather than using hardcoded fallbacks — requires an injection interface defined in the Ecological Disturbance GDD. That test belongs in `tests/integration/ecological-disturbance/` and is blocked pending the Ecological Disturbance GDD.*

**AC-4 — Transition band interpolation: midpoint value:** When a disturbance event fires at the midpoint of a Shallows→Rift Zone Gradual band (x = W/2, W = 40m), the propagation radius passed to Ecological Disturbance equals 120 + (35 − 120) × (20/40) = 77.5m. → Unit test (EditMode): supply V_A = 120, V_B = 35, W = 40, x = 20 to the interpolation function; assert output = 77.5 ± 0.001. Run the same test for all five interpolated properties with known inputs. *Story type: Logic.*

**AC-5 — Transition band interpolation: boundary endpoint values:** At x = 0, `V(0)` equals V_A exactly. At x = W, `V(W)` equals V_B exactly. No sample point in the band exceeds max(V_A, V_B) or falls below min(V_A, V_B). → Unit test (EditMode): check x = 0, x = W, and 50 evenly spaced sample points for any of the five interpolated properties; assert all fall within [V_A, V_B]. *Story type: Logic.*

**AC-6 — No-build zone enforced at biome boundaries (≤ 5m = blocked):** Placing any structure at distance ≤ 5m from a biome boundary polygon is blocked; placement at > 5m is allowed. The exclusion is inclusive of the 5m boundary (`distance ≤ 5m` is blocked). → Integration test or manual walkthrough: load the generated world; attempt build tool placement at 4m, 5m (blocked), and 6m (allowed) from a known boundary marker.

To confirm the block originates from World Generation boundary data (not a hardcoded distance check), the `BuildValidator` must expose a `GetLastBlockReason()` method returning a typed enum including `BlockReason.BiomeBoundary`. This instrumented interface must be specified in the World Generation GDD. Until that interface exists, manual verification suffices: check that the 5m zone matches the authored boundary polygon position, not a player-relative distance check. *Story type: Integration — integration test or documented playtest required.*

**AC-7 — Player spawn distance from biome boundary:** Every world generation run places the player spawn ≥200m from the nearest biome boundary, across all seeds. → Unit test (EditMode): generate 10 worlds with different seeds; query distance from spawn to nearest boundary polygon; assert all ≥200m. *Story type: Logic.*

**AC-8 — Position discontinuity re-queries biome:** After a death/respawn that places the player inside The Rift Zone, drain rates reflect Rift Zone modifiers (1.40 O2 modifier) within 50ms of the new position being set — without a boundary-crossing event firing. → PlayMode integration test: start in The Shallows; assert Shallows O2 drain modifier is 0.80; trigger a respawn to a confirmed Rift Zone interior position (>40m from any boundary); assert O2 drain modifier equals 1.40 within a 50ms measurement window after position set. *Story type: Integration.*

**AC-9 — Hard boundary resolves deterministically:** When the player stands exactly on a Hard boundary between two biomes, the system assigns the biome with the lexicographically higher `biome_id`. This assignment is stable across 100 repeated queries at the same coordinate. → Unit test (EditMode): place a Hard boundary between `"rift_zone"` and `"shallows"`; query biome at boundary coordinate 100 times; assert all results equal `"shallows"`. *Story type: Logic.*

**AC-10 — EC-3: Zero-width Gradual biome caught at generation time:** A biome record with `transition_type = Gradual` and `transition_band_width_m = 0` causes world generation to fail with a validation error before any terrain data is produced. The runtime interpolation code path is never reached. → Unit test (EditMode): pass a Gradual biome record with W = 0 to the world generation validator; assert it returns a non-null error and produces no terrain output. *Story type: Logic.*

**AC-11 — Disturbance event in transition band uses interpolated parameters:** When a disturbance event fires at x = W/2 of a known transition band, Ecological Disturbance receives a `propagation_radius_m` value that equals the formula result — neither V_A nor V_B exactly. → Unit test (EditMode): fire a disturbance event at band midpoint; capture propagation_radius_m passed to the signal formula; assert it differs from both V_A and V_B and equals the interpolated result within float epsilon. *Story type: Logic.*

**AC-12 — Biomes are stateless across the session:** After 5 minutes of disturbance events, resource gathering, and a respawn, all biome record float properties equal their world-generation-time values within `1e-6f` epsilon. → PlayMode integration test: cache all float property values from both biome records at session start; execute a scripted 5-minute session; re-read all values; assert `Mathf.Abs(cached - current) < 1e-6f` for each property. ("Byte-for-byte" equality is not used — float values require epsilon comparison.) *Story type: Integration.*

**AC-13 — Reverse traversal produces bounded interpolation (EC-2 regression guard):** When the player enters a Shallows→Rift Zone transition band and then reverses direction, interpolated property values at each position remain bounded within [V_A, V_B] and do not exceed either endpoint. V_A and V_B anchors do not swap on reversal. → Unit test (EditMode): simulate traversal from x=0 to x=W to x=0 again (full band entry and reversal) using the interpolation function; sample V(x) at 20 evenly spaced points in each direction; assert all values are within [min(V_A, V_B), max(V_A, V_B)] and that the anchor assignment at x=0 equals V_A in both traversal directions. *Story type: Logic.*

**AC-14 — Transition band exploitation produces interpolated values, not snapped values (EC-8 regression guard):** A player standing at x=5m in a 40m Shallows→Rift Zone band receives oxygen_drain_modifier = V(5) = 0.80 + (1.40 − 0.80) × (5/40) = 0.875, not 0.80 (Shallows) or 1.40 (Rift Zone). This intentional behavior must not be "corrected" by adding clamping. → Unit test (EditMode): supply V_A=0.80, V_B=1.40, W=40, x=5; assert output = 0.875 ± 0.001. *Story type: Logic.*

## Open Questions

1. **Third biome design constraints**: When a third biome is added, what properties must it have that The Shallows and The Rift Zone don't yet cover? Is `biological_density_tier = Moderate` reserved for a middle biome, or should it remain unused in MVP? Recommend deciding before the biome schema is finalized in code, as adding a Moderate-density biome later is low-cost but removing a hardcoded assumption is not.

2. **Multi-planet biome reuse**: The GDD states "biome definitions must be authored per planet, not reused across them." This rule ensures each planet has a distinct resource identity but has not been validated against the full multi-planet concept (deferred to Full Release). Validate this constraint before the biome schema is locked in the data layer — shared biome records across planets may be architecturally simpler.

3. **Weather and time-varying modifiers**: The current biome property schema has no time-varying fields. If a future design adds weather or day/night cycles that affect drain modifiers, these would be a separate modifier layer stacked on top of biome values — not changes to the biome record itself. Confirm this architecture before the Resource Management GDD locks its drain formula, as that formula must know whether to expect one modifier or two.

4. **Hard boundary visual form**: The art bible defines palette shifts and geometry transitions but does not specify whether Hard boundaries require a distinct visual marker (cliff, rock line, chemistry change). Level Design owns boundary placement, but the Biome system must be consistent in what Hard vs. Gradual transition types communicate. Coordinate with Level Design before shipping the first world to ensure Hard transitions are discoverable without UI.
