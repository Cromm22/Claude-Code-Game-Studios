# Crafting & Items

> **Status**: In Design — round-2 patch applied (2026-06-01)
> **Author**: chrusht + Claude Code (game-designer, economy-designer, systems-designer, ux-designer, art-director, qa-lead pending consult)
> **Last Updated**: 2026-06-01 (round-2 patch: survival-window redesign + 5-recipe cut; Phase A design-substance 2026-05-30, Phase B hygiene sweep 2026-06-01)
> **Implements Pillar**: Pillar 3 (The World Watches) primary — every craft action publishes disturbance; Pillar 1 (Quiet Is Power) secondary — crafting is part of the noise budget; Pillar 4 (Rounds Not Saves) structural — no in-run inventory persistence.

## Overview

Crafting & Items is the squad's progression rail across a single 5–20 minute run. As **infrastructure** it owns the item schema, the deterministic recipe catalog, the per-player runtime inventory, and the server-authoritative craft and beacon-activate contracts that downstream systems consume — Resource Management's oxygen consumable, Resource Node's gather yields, HUD's inventory readout, and Player Controller's victory-state hand-off all flow through definitions written in this GDD. As **player loop** it is where the squad converts the noise they made — gathered raw materials — into the means of escape: the **Escape Beacon** is the single, named win-condition recipe of the MVP, and every other recipe sits between "more time alive" and "louder, faster, sooner." Players engage actively and directly, interacting with a crafting bench using the same tap-hold / proximity-gate pattern Player Controller already specified, queueing recipes that consume materials and spend craft-time, then placing and activating the beacon when the recipe completes. Craft actions publish disturbance via `DisturbanceService:Emit` (per ED.C.3.6 for the beacon, and via the four reserved emission enum slots for any other emitting recipes this GDD elects to introduce), making this system a primary contributor to Pillar 3 ("The World Watches"): there is no *quiet* way to craft, only a *quieter* way. Without this system there is no win condition, no progression arc, and no mechanical translation between "we gathered carefully" and "we escaped" — the game would collapse into a survival timer with no way out.

## Player Fantasy

**The Beacon is the loudest thing the squad will ever raise.** Every recipe in this game is a small bargain with the planet — *this much noise, in exchange for this much capability* — and the Escape Beacon is the bargain that ends the run. The instant a player's hand touches the activation switch, the ambient stem cuts, the Hunt stem rises, and the bioluminescent flora around the plinth saturate to maximum and pulse faster than the squad has ever seen them pulse. The squad has ~49 seconds of Hunt-floor lure window before the Beacon's signal decays — 49 seconds of holding the loudest thing they have ever made while the predator commits across the map toward them. The recipes are not blueprints. They are invocations. The bench is not a workstation. It is an altar the squad lights on fire to leave. This is Pillar 3 ("The World Watches") at its most direct: the moment the squad most clearly understands that *this planet has been listening the whole time*.

**The bench is exposure, not refuge.** Crafting in Terranova is the one place in the run where the squad chooses, together, to make noise on purpose, and the choice is never private. A teammate crouches at the bench, the lantern's pool tightened around their forearms; the progress ring fills in soft increments. The other squad members do not craft beside them. They face outward, watching the lantern-pool's edge, listening for the shift in the ambient stem, watching the squad meter tick up with every pulse the bench leaks. Two crafters at the same bench halve dwell time but double the spike. One crafter alone leaks longer. Someone has to choose, and the choice is the section of the loop that earns Pillar 2 ("The Squad Is the Experience") most directly — the bench is a coordination problem disguised as a UI screen.

**Every other recipe is a noise debt.** Beyond the Beacon, the four aid recipes this GDD defines exist so the squad can spend disturbance for a survival edge — an oxygen pulse, a small dampener for the lantern, a sensor that reads the predator's approach, a squad oxygen relay. The fantasy at the rim of these recipes is triage panic, briefly suspended: oxygen at 22%, three-second progress ring, the flora at the rim of the lantern pool brighter when the player stands than when they crouched, *something* in their inventory and a hard need to move. Pillar 1 ("Quiet Is Power") names the constraint these recipes operate inside. There is no quiet way to craft, only a *quieter* way. There is no version of crafting in Terranova that feels like getting away with something — completion is followed immediately by exposure, and the squad's job is to spend disturbance *well*, not to avoid it.

## Detailed Design

### Core Rules

#### C.1 — Material Types

Three raw materials, mapping 1:1 onto the three Resource Node gather tiers locked in ED's registry:

| Material | Symbol | Source node tier | Gather emission magnitude | Narrative role |
|---|---|---|---|---|
| Biomass Shard | `BIOMASS` | Light node | `MAGNITUDE_GATHER_LIGHT = 0.15` (ED-locked) | Organic matter — flexible polymers, soft seals; used in survival consumables |
| Mineral Core | `MINERAL` | Medium node | `MAGNITUDE_GATHER_MEDIUM = 0.25` (ED-locked) | Dense crystal — energy-coupling elements, structural frames; used in energy-related recipes |
| Resonant Ore | `RESONANT` | Heavy node | `MAGNITUDE_GATHER_HEAVY = 0.40` (ED-locked) | Rare high-energy deposit — unstable compounds; powers the Beacon and advanced suppression tech |

The three-tier material list is intentionally aligned with the three gather magnitudes — gathering Beacon-critical material (RESONANT) is the loudest pre-activation thing the squad does. Pillar 1 (Quiet Is Power) is enforced economically: the win condition's ingredients cost the most disturbance to assemble.

#### C.2 — Recipe Catalog

Five recipes including the Beacon. All recipes are deterministic (no RNG yields, per game-concept anti-pillar). All recipes are available from run start (no progression gating, per Pillar 4). Burst-at-completion magnitudes are constants registered in this GDD's section G:

> **Round-2 catalog revision (2026-05-30)**: the Composite Patch and Quiet Step Wrap recipes were **cut** in the round-2 patch. Both were gather/sprint-noise reducers flagged as trap recipes in round-1 (gather emissions mostly decay before they matter), and the round-2 redesign moves the run's decisive pressure to the post-activation Beacon survival window (C.5), where gather-phase noise reduction is irrelevant. The four aid recipes that remain all bear directly on setting up and surviving that window. The two freed emission/recipe slots are reserved for post-launch content (Open Questions OQ.12).

| # | Recipe | BIOMASS | MINERAL | RESONANT | Craft time | Burst at completion | Effect (summary — full rules in C.6) |
|---|---|---|---|---|---|---|---|
| 1 | Oxygen Canister | 2 | 0 | 0 | 2 s | `MAGNITUDE_CRAFT_XS = 0.10` | Single-use consumable; restores an oxygen pulse to the squad shared pool (exact value defined in Resource Management GDD). A survival-window staple — the cheapest way to buy oxygen during the loud finale. |
| 2 | Dampener Coil | 0 | 2 | 1 | 5 s | `MAGNITUDE_CRAFT_MID = 0.18` | Time-limited; reduces equipped player's Light pulse magnitude by 50 % for `DAMPENER_DURATION = 60 s` OR until next bench visit, whichever comes first. Lets a player reposition with the lantern up during the survival window without spiking the field. |
| 3 | Signal Anchor | 1 | 1 | 1 | 5 s | `MAGNITUDE_CRAFT_MID = 0.18` | Placed passive sensor (BasePart). Pings the squad HUD when the predator passes within `SIGNAL_ANCHOR_DETECTION_RADIUS = 30 studs` of the Anchor. Active for `SIGNAL_ANCHOR_LIFETIME = 45 s`. **The Anchor does NOT emit disturbance** — it is a sensor, not a decoy. See C.7. Reading the predator's approach vector is decisive during the survival window. |
| 4 | Squad Relay | 2 | 2 | 1 | 6 s | `MAGNITUDE_CRAFT_RELAY = 0.20` | Placed item; on activation by any squad member, transfers a fixed oxygen amount between pool segments (Resource Management GDD owns the transfer math) and pings its position to all squad members. Single-use; consumed on activation. The Relay's burst sits one tier above MID (Coil/Anchor 0.18) to reflect its squad-coordination scope: activating broadcasts a position ping to all squad members, not just affecting one player. Pre-placed before activation, it is an emergency squad-oxygen lifeline during the window. |
| 5 | Escape Beacon | 2 | 3 | 3 | 10 s | `MAGNITUDE_CRAFT_HEAVY = 0.35` (completion burst) + `MAGNITUDE_CRAFT_BEACON_MIDPULSE = 0.18` (one-time mid-craft pulse at `CRAFT_BEACON_MIDPULSE_TIME = 5 s` from craft start) + `MAGNITUDE_BEACON = 0.95` on activation per ED.C.3.6 | The win-condition recipe. Crafting completes the Beacon item into the squad shared pool; placement and activation are separate steps (C.5). Activation does **not** win instantly — it opens the survival window (C.5); the squad wins only by living through it. |

**Reserved-band compliance**: per ED.C.1.2, all non-Beacon emissions MUST have `initialMagnitude < 0.85`. The completion bursts (0.10–0.35) and the Beacon midpulse (0.18) clear this constraint by construction. The Beacon's activation emission of 0.95 sits inside the [0.85, 1.00] reserved Beacon-only band per ED.C.3.6.

**Total Beacon assembly cost**: 2 BIOMASS + 3 MINERAL + 3 RESONANT = 8 gather actions across the squad. Worked sanity check (3-player squad, 10 min run): one Oxygen Canister + Beacon = 10 total gather actions, well inside achievable pace. The recipe is reachable in a 5-minute minimum run without grinding; the RESONANT requirement creates intentional Hunt-tier disturbance spikes during heavy-node gathering.

#### C.3 — Bench Interaction

The crafting bench is a level-design-placed `BasePart` in safe rooms. One bench per safe room; immobile (level-design owns placement; the bench is not destroyable nor relocatable in MVP). The interaction follows the proximity-gate pattern PC GDD C.7 already specified:

1. **Approach**: player's `HumanoidRootPart` enters within `GATHER_PROXIMITY_RADIUS = 4 studs` of the bench (PC-locked constant). Server fires `OnBenchArmed(benchId)` to the owning client; client renders a contextual prompt ("Press E / tap to open bench").
2. **Open**: player commits via single tap (touch) or `E` (PC) once the gate is armed. Server transitions the bench from `BS1 Bench-Idle` to `BS2 Bench-Occupied-Single` (state machine in C.8); records the player as `crafter[1]` in a new `CraftSession` record.
3. **Recipe selection**: bench UI lists the 5 recipes. Each row shows material costs, craft time, expected completion-burst magnitude, and effect summary. Rows the squad cannot currently afford (insufficient combined personal-inventory materials) render *dimmed* but remain visible — players need the affordability legibility to plan future gathers.
4. **Commit craft**: player selects a recipe and confirms. Server validates: alive; within bench range; recipe valid; combined personal-pool material availability; if Beacon, `RunSession.beaconCrafted == false`. On success, server creates / updates the `CraftSession` and starts the per-Heartbeat progress timer (D.1).
5. **Multi-occupant** (effective cap `benchMaxCraftersEffective`, see below): a second player may join an in-progress craft session by approaching the bench and selecting the *same* recipe via the UI. Server transitions BS2 → BS3 if `craftProgress < CRAFT_JOIN_CUTOFF = 0.85` **AND** the bench's current crafter count is below `benchMaxCraftersEffective`. Each crafter contributes their own `sourcePlayerId` to the emission set. Dwell time scales as 1/N (D.2). Disturbance emission scales as **N concurrent independent emissions** at completion (D.3) — preserves attribution and ED.C.1.2 reserved-band compliance.
   - **Squad-scaled cap (round-2 fix for the 2-player "nobody watches" collision)**: the per-bench crafter cap is **not** the fixed constant `BENCH_MAX_CRAFTERS = 2`. It is `benchMaxCraftersEffective = min(BENCH_MAX_CRAFTERS, ceil(squadSize / 2))`, computed once at run start from the RunSession's squad size (the count of players who started the run; not recomputed on death/disconnect, so the cap never shrinks mid-craft). `BENCH_MAX_CRAFTERS = 2` is the hard ceiling. Concrete values: **squad 2 → cap 1** (one crafts, one keeps watch — the bench stays "exposure, not refuge" per Section B); **squad 3 → cap 2**; **squad 4 → cap 2**. Round-1 flagged the fixed cap=2 as a degenerate "nobody watches" state in 2-player squads (a supported config); scaling the cap with squad size resolves it while leaving 3–4-player coordination unchanged.
6. **Material deduction (atomic at completion)**: materials are NOT deducted at craft start. They are deducted from the combined personal pool atomically at completion, prioritizing in this order: (a) the crafting player(s)' own personal inventories, summed; (b) the rest of the alive squad's personal inventories in `UserId` order. **Dead players' personal inventories are LOCKED** — their materials cannot be auto-pooled until the player respawns. If the squad's combined personal inventory drops below recipe cost during the craft window (e.g., a concurrent craft at another bench consumes a shared material first), the server cancels the craft via `CraftCancelled(reason="insufficient-materials")`.
7. **Cancel**: any crafter may fire `RequestCraftCancel`. If others remain, BS3 → BS2 (or BS2 → BS1 if N=1 cancels). **No partial credit on cancel** — Pillar 4 (Rounds Not Saves) — `craftProgress` resets to 0.0 on full cancel.
8. **Bench cosmetic-boundary**: cosmetic skins on the bench texture / progress-ring style / recipe icons MUST pass the dual-clause test (no predator-AI input mods; no player-survival-decision mods). Forbidden: cosmetics that change craft time, change emission magnitude, change material cost, or hide / obfuscate the burst-at-completion event.

#### C.4 — Inventory Model (Hybrid)

Two-tier server-authoritative inventory. All inventory state is purely runtime — never written to DataStore (per Pillar 4 / no in-run save).

| Tier | Scope | Contents | Purpose |
|---|---|---|---|
| **Personal** | Per-player; transient | Raw materials only (BIOMASS, MINERAL, RESONANT) | Forces gather → converge-at-bench: each player gathers their own; squad must physically travel to a bench to pool materials. Preserves Section B's "the bench is a coordination problem." |
| **Squad shared** | Per-RunSession; transient | Crafted items only (Oxygen Canister, Dampener Coil, Signal Anchor, Squad Relay, Beacon) | Any alive squad member can use any crafted item. Eliminates the "dead crafter locked the Beacon" soft-lock; preserves squad reactivity. |

**Schemas** (server-side):

```
PersonalInventory[playerId] = {
    biomass:      int,    -- 0..MATERIAL_STACK_MAX
    mineral:      int,    -- 0..MATERIAL_STACK_MAX
    resonant:     int,    -- 0..MATERIAL_STACK_MAX
    lastModified: number, -- workspace:GetServerTimeNow() at last mutation (analytics)
}

SquadInventory = {
    items:        { [itemId: string]: { count: int, craftedAt: number } },
    -- Beacon: itemId="Beacon"; count is 0 or 1 only (once-per-run enforced separately on the RunSession flag, not on this count)
    -- Consumables stack up to ITEM_STACK_MAX
}
```

**Caps**: `MATERIAL_STACK_MAX = 20` per material per player; `SQUAD_INVENTORY_TYPE_CAP = 8` distinct item types in squad pool; `ITEM_STACK_MAX = 10` per stack (consumables only — Beacon is single-instance). The MATERIAL_STACK_MAX cap creates "drop these at the bench before gathering more" tension once a heavy gatherer fills up.

**Equipped-item ownership**: the Dampener Coil (the only item with a localized equipped effect post-round-2) has an implicit owner — the player who equipped it — recorded at equip-time on the SquadInventory entry. Effects apply only to the owner. **Ownership cannot be transferred mid-effect** (would create exploit paths around the consumable rule). On equipped player's death, the active effect terminates immediately.

#### C.5 — Beacon Lifecycle

The Beacon is the only recipe whose post-craft lifecycle requires a separate state machine (full machine in C.9). Concept-level rules:

1. **Once-per-run constraint** is enforced on `RunSession.beaconCrafted: bool`, set at recipe-completion. **Per-squad, not per-player** — preventing two-Beacon spam exploits and rationalizing the "this is a squad event" framing of Section B.
2. **Two-step lifecycle**: completing the Beacon recipe places a single-instance `Beacon` item in the squad shared inventory (state BC2). Placement is a separate explicit interaction (`RequestBeaconPlace`) that any alive squad member can fire while holding the Beacon item; on success the Beacon item is removed from the shared pool and a `Beacon` BasePart is spawned at the validated placement position (state BC3). Activation is a third explicit interaction (`RequestBeaconActivate`) that any alive squad member within `GATHER_PROXIMITY_RADIUS = 4 studs` of the placed Beacon can fire (state BC4 — emission live).
3. **No pickup after placement**: state BC3 is terminal-pre-activation; the Beacon BasePart cannot be returned to inventory. Bad placements stand. This serves Pillar 1 — even placement is a transaction the squad cannot undo without spending more noise.
4. **Cross-player rescue**: the placing player may die between BCT2 (place) and BCT3 (activate). Any alive squad member within range can activate. Server uses `RunSession.beaconPlacerId` for `sourcePlayerId` in the `Emit` call (preserves attribution per ED.C.3.6's `"BeaconPlaced"` action label semantics) — not the activator's ID.
5. **Placement validity (server-checked)**: the client-supplied position is a **direction hint, not a trusted coordinate** (round-2 B13) — the server first clamps it to within `BEACON_PLACE_MAX_RANGE = 8 studs` of the player's server-tracked position, then raycasts downward from the *clamped* candidate to find a valid floor, then checks for overlap with existing geometry / other beacons within a small bounding box. Invalid positions are rejected with `BeaconRejected(reason="invalid-placement")`. Specific surface-type rules (slope tolerance, level-designer-defined exclusion zones) are level-design's authoring responsibility — flagged in Section F.
6. **Active emission + window start**: at BCT3 (activate), server calls `DisturbanceService:Emit("Beacon", beaconWorldPosition, 0.95, beaconPlacerId)` per ED.C.3.6, fires `OnBeaconActivated` (the HUD/audio activation cue), fires `OnEscapeBeaconActivated` (the window-**start** signal — see C.5.6a below; this is **no longer the victory trigger**), and starts the survival-window timer. **T8 does NOT fire at BCT3.** Activation opens the survival window; it does not win the run. *(Round-2 change, 2026-05-30: pre-round-2 this rule fired T8 immediately at activation, which made the run end the instant the Beacon was activated and rendered every aid item dominated strategy — the round-1 Beacon-dominance finding. Victory now requires surviving the window.)*
   - **6a — Survival window (the win condition)**: activation starts the **Beacon survival window**, `BEACON_SURVIVAL_WINDOW ≈ 49 s`. This length is **derived from ED's beacon-decay math** — the interval the Beacon holds at or above `HUNT_THRESHOLD = 0.65` (`MAGNITUDE_BEACON = 0.95` decaying at `BEACON_HALF_LIFE = 90 s` crosses 0.65 at age ≈ 49 s), i.e. the predator's peak-threat commit window per ED.D.7 / the ED beacon worked example. **ED owns the length; this GDD references it** and registers `BEACON_SURVIVAL_WINDOW` as a derived value (G.6), exactly as `CRAFT_BEACON_MIDPULSE_TIME` is derived. During the window the predator commits to the beacon at Hunt-floor and the squad must survive its peak pressure.
     - **Victory**: when the window timer elapses with **≥ 1 squad member alive**, the server fires `OnBeaconWindowSurvived` → Player Controller's T8 (squad escape → victory) transition. See C.9 transition BCT4.
     - **Defeat**: if **every** squad member is dead before the window elapses (full-squad wipe while the beacon is in BC4), the run ends in defeat — `RunEnded(defeat)`. See C.9 transition BCT-DEFEAT.
     - This window is what makes the aid suite **load-bearing**: a squad that rushed the Beacon with no aid preparation faces ~49 s of maximum predator pressure unaided. Coils to reposition with the lantern up, an Anchor to read the predator's approach, a pre-placed Relay or stockpiled Oxygen Canisters to survive the drain — the four aid recipes all earn their cost here.
7. **Decay (defensive fallback)**: natural source-expiry — ED detecting `m(t, age) <= MAGNITUDE_FLOOR = 0.02` (~501 s after activation per ED.D.1) — fires `OnBeaconDecayed` and removes the Beacon BasePart at BCT5. **This is now normally unreachable**: the run ends in victory or defeat at window-end (~49 s), ~10× sooner than the ~501 s natural decay, and beacon cleanup then runs through the run-end cleanup path (as in E.8), not BCT5. The decay state is retained only as a defensive fallback for any path that would otherwise leave a beacon source live past natural expiry. *(Round-2 note: pre-round-2 this was C.5.7 "Decay at BCT4" and was the squad's post-victory cleanup; it keeps the same C.5.7 number and the same decay semantics, only demoted to a fallback.)*
8. **Beacon cosmetic-boundary**: cosmetic skins on the Beacon BasePart's appearance MUST NOT change the placement BasePart's bounding volume, the beacon's emission position (always the BasePart center), the activation emission magnitude (locked at 0.95), or the visibility of activation feedback. Forbidden: cosmetics that would change the predator AI's read of the beacon's spatial signature, or change which players can identify a beacon as a beacon.

#### C.6 — Aid Item Effects

All aid items are **consumables or time-limited deployables** — never permanent — to mitigate the degenerate "stack permanent silence" strategy. Effect rules per item:

> **Round-2 cut (2026-05-30)**: the **Composite Patch** and **Quiet Step Wrap** items were removed from the catalog (C.2). Their effect bullets, the `D.4` / `D.5` formulas, the `EquippedEffects.compositePatch` / `.quietStepWrap` schema fields, the Composite-Patch ↔ Resource-Node accessor (C.13), and their edge cases/ACs/VA-moments are removed or stubbed. The four aid items below are the full round-2 set.

- **Oxygen Canister**: server-authored consumable. Any alive player can equip + use via `RequestUseItem("OxygenCanister")`. On use, server fires `OnOxygenPulseRequest(amount)` to Resource Management Service (RM owns the actual transfer math). Item removed from shared pool. Use generates **no additional disturbance** — the disturbance was paid at craft completion. Use is instant (no progress ring). During the Beacon survival window (C.5.6a) this is the squad's cheapest source of emergency oxygen.
- **Dampener Coil**: equip via `RequestEquipItem("DampenerCoil")`. Reduces equipped player's Light pulse magnitude by 50 % for **`DAMPENER_DURATION = 60 s` real-time OR until next bench visit OR equipped player's death, whichever comes first**. Stacking rule: one per player. Multiple players may each equip their own Coil. Effect terminates at expiry; item is fully consumed. **The only remaining emission modifier in the game** — its interaction with PC stationary-attenuation is the sole entry in the canonical order-of-operations (D.6a).
- **Signal Anchor**: place via `RequestPlaceItem("SignalAnchor", position)`. Server validates position (raycast-to-floor; overlap check), spawns the Anchor BasePart, starts a `SIGNAL_ANCHOR_LIFETIME = 45 s` lifetime timer. The Anchor is a sensor — see C.7. Single-use placement; item is consumed on placement (not on lifetime expiry). Maximum **one Signal Anchor live in the world at a time per squad** (placing a second cancels the first).
- **Squad Relay**: place via `RequestPlaceItem("SquadRelay", position)`. Server validates position; spawns Relay BasePart. Any alive squad member within `GATHER_PROXIMITY_RADIUS = 4 studs` may fire `RequestActivateRelay()` — server fires `OnOxygenTransferRequest(amount, position)` to Resource Management (RM owns the math) and pings the Relay's position to all squad members. Item is consumed on activation (not on placement). **Maximum one Relay live at a time per squad** (placing a second cancels the first; activation consumes immediately).

**Scaling-with-N rule for equipped/placed items**: the burst-at-completion magnitude in C.2 is the *total* emission for the recipe regardless of how many crafters. Multi-crafter scaling (D.3) doubles the *number* of emissions, not the per-emission magnitude. So two crafters making a Dampener Coil emit two Coil bursts at 0.18 each — the squad *receives* one Coil item, but the world hears the bench twice.

#### C.7 — Signal Anchor Sensor

The Signal Anchor is a passive sensor — the only crafted item that does NOT publish disturbance. This is a deliberate design choice: a Gather-pulse-emitting Anchor would be a decoy (which the user explicitly excluded from the MVP scope at the design-frame stage). The Anchor sense-but-don't-broadcast model preserves a useful coordination tool without violating the "no decoys / distractors" rule.

**Mechanic**:
1. On placement (C.6 above), server spawns the Anchor BasePart and registers it with `PredatorPerceptionService` (or equivalent server-side predator-tracking surface — the exact subscription channel is the Predator AI GDD's territory; this GDD assumes the predator's server-tracked position is queryable by Crafting Service).
2. Server runs a per-Heartbeat distance check (or equivalent throttled cadence — recommended `SENSOR_CHECK_HZ = 5` matching ED's `FIELD_UPDATE_HZ`) between the Anchor position and the predator's current server-tracked position.
3. When `dist3D(anchor, predator) <= SIGNAL_ANCHOR_DETECTION_RADIUS = 30 studs` for the first time within the Anchor's lifetime (single-shot trigger — the Anchor reports the predator's first proximity-cross, not every tick of proximity), server fires `OnSignalAnchorTripped(anchorId, anchorPosition)` to all alive squad clients. The HUD GDD owns the visual presentation (a directional indicator pointing to the Anchor's position; spec deferred to HUD GDD).
4. **Single-shot trigger** means each Anchor reports *one* detection event per lifetime. Subsequent predator approaches within range during the same Anchor's lifetime do NOT re-trigger. Rationale: a re-triggering Anchor becomes a continuous tracking device, which would render the predator-as-puzzle / Pillar 1 tension into a UI readout. Single-shot preserves the "the world watches" reciprocity — the squad gets one piece of intel, not a permanent sensor net.
5. **Lifetime expiry**: at `SIGNAL_ANCHOR_LIFETIME = 45 s` (or whichever comes first: trip, lifetime expiry, or run end), server removes the Anchor BasePart and fires `OnSignalAnchorExpired(anchorId)`.

**Cosmetic-boundary**: cosmetic skins on the Anchor's appearance MUST NOT change the detection radius, the trigger condition, or the visual indicator on the HUD. Forbidden: cosmetics that increase detection radius or convert the Anchor to a multi-shot sensor.

### States and Transitions

#### C.8 — Bench State Machine

Crafting bench states. The per-bench crafter cap is the squad-scaled `benchMaxCraftersEffective = min(BENCH_MAX_CRAFTERS, ceil(squadSize / 2))` (C.3.5), with hard ceiling `BENCH_MAX_CRAFTERS = 2`. In a 2-player squad the effective cap is 1, so BS3 is unreachable and BT2 never fires (one player crafts, one watches); in 3–4-player squads the cap is 2 and BS3 is reachable. The state machine generalizes to N but only states for N ≤ 2 are MVP. No separate "interrupted" state — BT4 and BT5 cover crafter-departure cleanly.

| State ID | Name | Description |
|---|---|---|
| BS1 | Bench-Idle | No crafter present. Bench is available. `craftProgress = 0.0`; no `CraftSession` record. |
| BS2 | Bench-Occupied-Single | Exactly one crafter. `craftProgress` incrementing per D.1 at single-rate. |
| BS3 | Bench-Occupied-Multi | Up to `benchMaxCraftersEffective` crafters (= 2 only when squad size ≥ 3; **unreachable in a 2-player squad**). `craftProgress` incrementing per D.1 at 1/N-accelerated rate (D.2). |

**Transitions:**

| ID | Trigger | From | To | Side Effects |
|---|---|---|---|---|
| BT1 | Player fires `RequestCraft(recipeId)`, server validation passes (alive; within `GATHER_PROXIMITY_RADIUS = 4 studs`; recipe in catalog; combined personal-pool has materials; if Beacon, `RunSession.beaconCrafted == false`) | BS1 | BS2 | Server: create `CraftSession {benchId, recipeId, crafters=[playerId], craftProgress=0.0, startTime=now, lastCrafterCount=1, midpulseFired=false}`; fire `OnCraftStarted(benchId, crafterId, recipeId, estimatedCompletionTime)` to squad |
| BT2 | Second player fires `RequestCraft(recipeId)` for the SAME recipe while bench in BS2; validation passes AND `craftProgress < CRAFT_JOIN_CUTOFF = 0.85` AND current crafter count (1) `< benchMaxCraftersEffective` (i.e. squad size ≥ 3) | BS2 | BS3 | Server: append second player to `CraftSession.crafters`; recalculate `craftRate` from current `craftProgress` at N=2 rate (D.2); update `lastCrafterCount = 2`; fire `OnCraftStarted` for the joining player + `OnBenchOccupancyChanged(benchId, 2)` to squad. *(In a 2-player squad `benchMaxCraftersEffective = 1`, so this guard fails and the join is rejected with `OnCraftRejected(reason="bench-full")` per E.2.)* |
| BT3 | `craftProgress >= 1.0` (D.1 reaches completion threshold) | BS2 or BS3 | BS1 | Server (atomic, in this order): (1) deduct materials from combined personal pool per C.3.6; (2) add crafted item to squad shared pool (or set `RunSession.beaconCrafted = true` for Beacon); (3) for each crafter `i`, call `DisturbanceService:Emit("Craft", benchPosition, recipeBurstMagnitude, crafterId_i)` per D.3; (4) fire `OnCraftCompleted(benchId, recipeId, crafterIds)` to squad + `OnInventoryChanged` to relevant clients; (5) clear `CraftSession`; reset bench to BS1 |
| BT4 | One crafter departs (player death, disconnect, exits range > `GATHER_PROXIMITY_RADIUS + 2 studs` tolerance, OR fires `RequestCraftCancel`) while bench in BS3 | BS3 | BS2 | Server: remove departed crafter from `CraftSession.crafters`; recalculate `craftRate` from current `craftProgress` at N=1 rate (D.2); update `lastCrafterCount = 1`; fire `OnBenchOccupancyChanged(benchId, 1)` to squad. **Progress is preserved** (no setback for predator-driven mid-craft interruption). |
| BT5 | All crafters depart before completion (last remaining crafter triggers any of the BT4 conditions) | BS2 or BS3 | BS1 | Server: clear `CraftSession`; **`craftProgress` discarded** — no partial credit (Pillar 4: Rounds Not Saves); materials NOT deducted (craft did not complete); fire `OnCraftCancelled(benchId, recipeId, reason)` to squad |
| BT6 | Server-side detection of insufficient materials mid-craft (rare race with concurrent inventory mutations) | BS2 or BS3 | BS1 | Server: clear `CraftSession`; fire `OnCraftCancelled(benchId, recipeId, reason="insufficient-materials")`; identical to BT5 otherwise |

**Disconnect / death handling**:
- Disconnect mid-craft: detected via `Players.PlayerRemoving`. Removes player from `CraftSession.crafters`; fires BT4 (others remain) or BT5 (crafter alone). **Progress is not preserved** across the disconnect — the player rejoining cannot resume the craft.
- Death mid-craft: detected via `Humanoid.Died`. Same path as disconnect — removes player from session; fires BT4 or BT5. The dead player's existing crafted items in the squad shared pool are unaffected. Their personal raw-material inventory is locked until respawn (per C.3.6 dead-player-locked rule).

#### C.9 — Beacon State Machine

The Beacon's lifecycle from recipe-completion through emission decay. Single-instance per `RunSession` (once-per-run constraint enforced via `RunSession.beaconCrafted`).

| State ID | Name | Description |
|---|---|---|
| BC1 | Beacon-Unbuilt | Recipe not yet completed. No `Beacon` item in squad shared pool. `RunSession.beaconCrafted == false`. Initial state at run start. |
| BC2 | Beacon-InInventory | `Beacon` item exists in `SquadInventory` (`count = 1`). Not yet placed in world. `RunSession.beaconCrafted == true`; `RunSession.beaconPlaced == false`. |
| BC3 | Beacon-Placed-Inert | Beacon BasePart spawned at `RunSession.beaconWorldPosition`. Not emitting disturbance yet. `RunSession.beaconPlaced == true`; `RunSession.beaconActivated == false`. |
| BC4 | Beacon-Active-Window | `DisturbanceService:Emit` has been called; Beacon source is live in ED's source list, decaying per ED.D.1. **The survival window (C.5.6a) is counting down. T8 has NOT fired yet.** `RunSession.beaconActivated == true`; `RunSession.beaconWindowSurvived == false`. |
| BC5 | Beacon-Survived | Survival window elapsed with **≥ 1 squad member alive**. **T8 (squad escape → victory) fires on entry.** Run ends in victory; the Beacon BasePart is removed via the run-end cleanup path. `RunSession.beaconWindowSurvived == true`. Terminal (victory). |
| BC6 | Beacon-Decayed | Natural source-expiry in ED (`m(t, age) <= MAGNITUDE_FLOOR = 0.02`). BasePart removed from world. Terminal. **Defensive fallback — normally unreachable** (the run ends at window-end ~49 s, ~10× before the ~501 s natural decay). |

**Transitions:**

| ID | Trigger | From | To | Side Effects |
|---|---|---|---|---|
| BCT1 | Beacon recipe craft-completion (BT3 with `recipeId == "Beacon"`) | BC1 | BC2 | Server (atomic): set `RunSession.beaconCrafted = true`; set `RunSession.beaconCrafterId = CraftSession.primaryCrafterId` (the BT1 initiator, stable across any BT4 departures — round-2 B7); add `Beacon` item with `count = 1` to `SquadInventory`; fire `OnInventoryChanged` to all squad clients |
| BCT2 | Any alive squad member fires `RequestBeaconPlace(position)` while `Beacon` in `SquadInventory.count >= 1`; server validates (alive; `RunSession.beaconPlaced == false`; client `position` **clamped to** `BEACON_PLACE_MAX_RANGE = 8 studs` of player's server-tracked position per B13; raycast-to-floor from the clamped candidate succeeds; no overlap with existing geometry / other beacons) | BC2 | BC3 | Server: spawn Beacon BasePart at the validated (clamped) position; remove `Beacon` from `SquadInventory`; set `RunSession.beaconPlaced = true`; set `RunSession.beaconWorldPosition = position`; set `RunSession.beaconPlacerId = playerId`; fire `OnBeaconPlaced(position, placerPlayerId)` to squad |
| BCT3 | Any alive squad member fires `RequestBeaconActivate()` while within `GATHER_PROXIMITY_RADIUS = 4 studs` of `RunSession.beaconWorldPosition`; server validates (alive; `RunSession.beaconActivated == false`; range check) | BC3 | BC4 | Server (in this order): (1) set `RunSession.beaconActivated = true`; (2) call `DisturbanceService:Emit("Beacon", RunSession.beaconWorldPosition, 0.95, RunSession.beaconPlacerId)` — uses placer's ID, not activator's, per ED.C.3.6 attribution semantics; (3) fire `OnBeaconActivated(position, activatorPlayerId)` to squad; (4) fire `OnEscapeBeaconActivated(activatorPlayerId, timestamp)` to squad — the window-**start** signal (HUD/audio), **NOT** the victory trigger; (5) start the survival-window timer (`BEACON_SURVIVAL_WINDOW`, C.5.6a); (6) start the defensive decay-watch timer that polls ED for source expiry. **T8 does NOT fire here.** |
| BCT4 | Survival-window timer elapses (`now - activationTime >= BEACON_SURVIVAL_WINDOW`) **AND ≥ 1 squad member alive** at that moment | BC4 | BC5 | Server: set `RunSession.beaconWindowSurvived = true`; fire `OnBeaconWindowSurvived(timestamp)` to squad → drives Player Controller's T8 (squad escape → victory); run ends in victory; Beacon BasePart removed via the run-end cleanup path; clear the survival-window + decay-watch timers. **This is the victory transition** (it replaces the pre-round-2 "T8 at BCT3" behavior). |
| BCT-DEFEAT | The **last living** squad member's `Humanoid.Died` fires while the beacon is in BC4 (`beaconActivated == true && beaconWindowSurvived == false` and no squad member remains alive) | BC4 | `RunEnded(defeat)` | Server: end the run in defeat; remove Beacon BasePart via the run-end cleanup path; clear the survival-window + decay-watch timers. **`OnBeaconWindowSurvived` does NOT fire; `OnBeaconDecayed` does NOT fire** (consistent with E.8 run-end cleanup vs. natural decay). |
| BCT5 | Defensive decay-watch detects ED source expiry (`m(t, age) <= MAGNITUDE_FLOOR`); ~501 s after activation per ED.D.1 example | BC4 or BC5 | BC6 | Server: remove Beacon BasePart from workspace if still present; fire `OnBeaconDecayed()` to squad; clear decay-watch timer. **Defensive fallback only** — normally the run has already ended (BCT4 victory or BCT-DEFEAT) long before this fires. Was `BCT4` pre-round-2. |

**Concurrency / once-per-run guarantees**:
- BCT1 cannot fire twice in the same run because BT1's pre-validation checks `RunSession.beaconCrafted == false` for the Beacon recipe; the second `RequestCraft("Beacon")` is rejected before BT1 transitions. Same-Heartbeat double-fire is prevented by Roblox's single-threaded Luau scheduler — the second request is sequenced after the first sets the flag.
- BCT2 cannot fire twice because the `Beacon` item is removed from inventory at BCT2; subsequent `RequestBeaconPlace` calls find no item and reject.
- BCT3 cannot fire twice because of the `RunSession.beaconActivated == false` guard. Even a same-Heartbeat double-fire is sequenced by Luau's single-threaded execution; the second receives `BeaconRejected(reason="already-activated")`.
- BCT4 (window survived) fires at most once because it sets `RunSession.beaconWindowSurvived = true` and ends the run; the survival-window timer is cleared on the same tick, so a second elapse cannot fire.
- **BCT4 vs. BCT-DEFEAT are mutually exclusive and exhaustive over BC4's exit** (other than the defensive BCT5 fallback): on each Heartbeat while in BC4 the server evaluates, in order, (a) is the window elapsed with ≥1 alive → BCT4 victory; (b) did the last living squad member just die → BCT-DEFEAT. Because Luau is single-threaded, a death and a window-elapse cannot be processed in the same instant — whichever the scheduler orders first wins, and it sets a terminal flag that suppresses the other. **Tie-break rule (a death on the exact Heartbeat the window would elapse): evaluate window-survival FIRST** — a squad that lived to the window boundary escapes even if a member dies on that same tick (favors the squad, consistent with E.9's "activator dies on activation Heartbeat still wins").
- The placing player may die between BCT2 and BCT3 — see C.5.4 cross-player rescue rule. The `RunSession.beaconPlacerId` field is preserved; activation by a different alive player still uses the placer's ID for `Emit` attribution.

**Beacon BasePart cleanup edge cases**:
- Run ends before BCT3 (squad wipes at BC3, beacon placed but never activated): the `RunEnded` event triggers cleanup of all RunSession-scoped state; the Beacon BasePart is removed without firing BCT4, BCT-DEFEAT, or BCT5 (see E.8 — `OnBeaconDecayed` is suppressed for run-end cleanup).
- **Full-squad wipe during the survival window (BC4)**: this is BCT-DEFEAT, a gameplay outcome (defeat), not a cleanup edge case — the beacon BasePart is removed via the run-end path; `OnBeaconDecayed` is suppressed.
- Server crash between BCT3 (activation) and BCT4 (window survived): ED's source list and the survival-window timer are purely runtime; both are lost on server restart. No persistence concern (Pillar 4) — there is no in-run save, so a crashed run does not resume mid-window.

#### C.10 — Server-Side Session Data Model

Three server-side data structures govern Crafting & Items state. All are purely runtime — never written to DataStore.

**RunSession** (one per active server, lifecycle = `RunStarted` to `RunEnded`):

```
RunSession = {
    runId:              string,    -- unique session identifier
    runStartTime:       number,    -- workspace:GetServerTimeNow() at session start
    beaconCrafted:      boolean,   -- true once BCT1 fires; once-per-run guard
    beaconPlaced:       boolean,   -- true once BCT2 fires
    beaconActivated:    boolean,   -- true once BCT3 fires; guards against duplicate Emit; also marks the start of the survival window
    beaconWindowSurvived: boolean, -- true once BCT4 fires (window elapsed with >=1 alive); the victory guard
    beaconActivationTime: number?, -- workspace:GetServerTimeNow() at BCT3; nil before; window elapses at beaconActivationTime + BEACON_SURVIVAL_WINDOW
    beaconWorldPosition: Vector3?, -- set at BCT2; nil before
    beaconCrafterId:    number?,   -- UserId; set at BCT1
    beaconPlacerId:     number?,   -- UserId; set at BCT2; passed as sourcePlayerId in BCT3 Emit call
}
```

**CraftSession** (one per active bench, lifecycle = BT1 to BT3 or BT5/BT6):

```
CraftSession = {
    benchId:           string,    -- level-design-assigned bench identifier
    benchPosition:     Vector3,   -- the bench's immutable server-tracked world position; snapshotted at BT1 from the level-design bench record. The `position` argument for every D.3 / D.7 Emit call (round-2 B8: referenced by D.3/D.7 but previously absent from the schema)
    recipeId:          string,    -- recipe being crafted
    crafters:          { number },-- ordered array of UserIds; length 1..BENCH_MAX_CRAFTERS
    primaryCrafterId:  number,    -- UserId of the BT1 initiator; set once at BT1 and NEVER reassigned (round-2 B7: a stable attribution field, distinct from crafters[1] which can shift if the initiator departs via BT4). Drives D.7 midpulse attribution and BCT1 beaconCrafterId
    craftProgress:     number,    -- 0.0..1.0
    startTime:         number,    -- workspace:GetServerTimeNow() at BT1
    lastCrafterCount:  number,    -- N; updated on BT2/BT4 to drive D.2 rate calculation
    midpulseFired:     boolean,   -- Beacon-only: tracks whether the 5s mid-craft pulse has fired (per C.2.7)
}
```

**Server-crash mid-craft (round-1 B11)**: `CraftSession` is purely runtime (per C.4 / Pillar 4). A server crash between BT1 and BT3 loses the entire session with no persistence and no resume — on restart there is no in-run save to recover (consistent with the BCT3→BCT4 crash note in C.9). No materials were deducted (deduction is atomic at BT3 only, C.3.6), so nothing is lost from player inventories; the player simply re-approaches the bench and restarts. The bench returns to `BS1` by default because no `CraftSession` survives the restart. Verified by H.74.

**ActiveDeployables** (squad-scoped; tracks live placed items):

```
ActiveDeployables = {
    signalAnchor: { anchorId: string, position: Vector3, lifetimeStart: number, tripped: boolean }?,
    squadRelay:   { relayId: string,  position: Vector3, lifetimeStart: number }?,
    -- Beacon BasePart tracked via RunSession.beaconWorldPosition + beaconActivated flag, not here
}
```

Constraint: `signalAnchor != nil` is mutually exclusive with itself across time (placing a second Anchor cancels the first per C.6 Signal Anchor rule). Same for `squadRelay`. Server enforces by clearing the existing entry on the new `RequestPlaceItem` validation pass before spawning the replacement.

**EquippedEffects** (per-player, lifecycle = equip event to consumption / expiry / death):

```
EquippedEffects[playerId] = {
    dampenerCoil:   { equippedAt: number, expiresAt: number }?,    -- expiresAt = equippedAt + DAMPENER_DURATION OR next bench visit OR death; nil if not equipped
    -- (round-2: compositePatch + quietStepWrap fields removed with the recipe cut — DampenerCoil is the only equipped effect)
}
```

**Death-cleanup invariant**: when a player enters `Dead-Respawning` (per PC.S4), the server clears all entries in `EquippedEffects[playerId]`. Effects terminate; consumable items return to the squad shared pool only if they were not already consumed. This is the implementation of "On equipped player's death, effect terminates immediately" from C.4.

**Inventory schemas** (already defined in C.4): `PersonalInventory[playerId]` (per-player; raw materials only) and `SquadInventory` (squad-wide; crafted items only). Both are part of the Crafting Service's runtime state; both are cleared at `RunEnded`.

### Interactions with Other Systems

#### C.11 — Disturbance System Contract (publisher)

Crafting & Items publishes two emission types per ED.C.3.6: `Beacon` (already locked) and `Craft` (new — consumes 1 of 4 reserved enum slots; registry update in Phase 5). Per ED.F.3a, this section is normative — drift between this section and ED is a defect against ED.

1. **Craft emission** — fired by the server at recipe-completion (BT3) for each crafter:
   - `DisturbanceService:Emit(emissionType="Craft", position=benchPosition, initialMagnitude=recipeBurstMagnitude, sourcePlayerId=crafterId_i)` where `recipeBurstMagnitude` is the recipe's `MAGNITUDE_CRAFT_*` constant per C.2 (range: 0.10 – 0.35).
   - **N concurrent independent emissions** at BT3 — one Emit call per crafter (preserves attribution + ED.C.1.2 reserved-band compliance per D.3).
   - **Position semantics**: `benchPosition` is the bench's server-tracked world position (immutable per level-design). NOT the crafting player's `HumanoidRootPart.Position`.
   - **Server clock**: same `workspace:GetServerTimeNow()` rule as ED.D.1.
   - **No client-callable Emit path**: ED.C.1.8 / ED.F.4 forbid client-driven Emit. `RequestCraft` is a *request* to start a craft; the Emit fires server-internally only on legitimate craft completion (BT3 with all guards passed).
2. **Beacon emission** — fired by the server at BCT3:
   - `DisturbanceService:Emit(emissionType="Beacon", position=RunSession.beaconWorldPosition, initialMagnitude=MAGNITUDE_BEACON=0.95, sourcePlayerId=RunSession.beaconPlacerId)`.
   - **Single emission per run** — guarded by `RunSession.beaconActivated`.
   - Position per ED.C.3.6: beacon's world position, NOT the activator's. Already locked.
   - `attributionChain` includes placer's UserId + action label `"BeaconPlaced"` per ED.C.3.6.
3. **Beacon mid-craft pulse** — fired once when `craftProgress >= CRAFT_BEACON_MIDPULSE_PROGRESS = 0.5` for the Beacon recipe only:
   - `DisturbanceService:Emit(emissionType="Craft", position=benchPosition, initialMagnitude=MAGNITUDE_CRAFT_BEACON_MIDPULSE=0.18, sourcePlayerId=crafters[1])` (single emission; uses the primary crafter's ID, not duplicated for N=2).
   - At default tunings (Beacon craft time 10 s, N=1), this fires at wall-clock 5 s (the `CRAFT_BEACON_MIDPULSE_TIME = 5 s` worked example in C.2.7 is the derived value at default; the *registered tunable* is the progress fraction, not the seconds).
   - Tracked by `CraftSession.midpulseFired` boolean. BT2 multi-crafter join does NOT re-fire the midpulse if it has already fired.
4. **No client-bound Service.Client surface**: Crafting & Items' Knit `Service:Client` exposes ZERO RemoteFunctions (matches ED.F.4 "RemoteFunctions intentionally absent from the client surface" rule). All client→server communication is via Knit RemoteSignal (one-way fire-and-forget). Adding any client-callable RemoteFunction is a regression that reviewers MUST reject.
5. **Reserved-band compliance**: all `Craft` emissions are below 0.85 (max 0.35 per C.2). All `Beacon` emissions are exactly 0.95 (locked). No emission this GDD publishes can violate ED.C.1.2.

#### C.12 — Player Controller Contract

Per PC.F.2 (provisional contracts when authored), Crafting & Items resolves both rows:

1. **Crafting → PC: victory + window signals** *(round-2 change — the victory trigger moved from activation to window-survival)*:
   - **`OnBeaconWindowSurvived()`** — fired at **BCT4** (survival window elapsed with ≥1 squad member alive). **This is the T8 victory trigger.** PC subscribes for its T8 (squad escape → victory) state transition. Payload: `{timestamp: number}`. Fires at most once per run (guarded by `RunSession.beaconWindowSurvived`). PC's behaviour on receipt: broadcast `RunEnded(victory)`; lock all inputs (per PC.C.6 T8 transition).
   - **`OnEscapeBeaconActivated()`** — fired at **BCT3** (activation). **No longer the victory trigger** — it now signals the *start* of the survival window, for HUD (window countdown) + audio (Hunt-stem rise per Section B). Payload: `{activatorPlayerId: UserId, timestamp: number}`. Fires once per run (guarded by `RunSession.beaconActivated`). PC may use it to enter a "beacon active / surviving the window" presentation state, but PC MUST NOT fire T8 on this signal.
   - **Defeat path**: a full-squad wipe during the window (BCT-DEFEAT) ends the run in defeat via the squad-wipe path PC already owns (PC's existing all-dead → `RunEnded(defeat)` logic). Crafting does not fire a separate defeat signal; the beacon being active does not change PC's standard squad-wipe defeat handling. The only new Crafting→PC coupling is that PC must **not** treat beacon activation as victory and must wait for `OnBeaconWindowSurvived`.
2. **PC → Crafting: `RequestInteract(targetId)`** — PC fires this for crafting bench, beacon, and squad relay interactions. Crafting & Items owns the **receive-side validation**. The `targetId` routes to the appropriate handler:
   - If `targetId` resolves to a bench: server treats as `RequestCraft`'s prerequisite (open the bench UI). Validates per BT1 prelim.
   - If `targetId` resolves to the placed Beacon (BC3 only): server treats as `RequestBeaconActivate`. Validates per BCT3 prelim.
   - If `targetId` resolves to a placed Squad Relay: server treats as `RequestActivateRelay`. Validates per C.6 Squad Relay rule.
   - If `targetId` resolves to nothing this system owns: server returns `InteractRejected(reason="not-crafting-target")` and PC may try other systems.

   This is a routing convenience. The bench-open / beacon-activate / relay-activate flows have their own dedicated RemoteEvents (`RequestCraft`, `RequestBeaconActivate`, `RequestActivateRelay`); the `RequestInteract` from PC is the user-input-level abstraction that maps to those system-specific calls. Architecture phase will reconcile via an ADR.
3. **PC's `Dead-Respawning` (S4) state**: per PC.C.5, gather/interact/craft inputs are denied on the client. Crafting Service additionally rejects ALL Crafting-system RemoteEvents from dead players server-side (defense-in-depth). The `EquippedEffects[playerId]` cleanup at S4 entry (per C.10) ensures equipped effects do not persist through death.
4. **Reuse of PC-locked constants**: Crafting reuses `GATHER_PROXIMITY_RADIUS = 4 studs` for bench-open / beacon-activate / relay-activate ranges; reuses `TAP_HOLD_COMMIT_DURATION = 0.5 s` for any future crafting-system tap-hold flows (none in MVP — bench / beacon / relay use single-tap-with-prompt, not tap-hold). **Crafting does NOT redefine these constants** — PC owns them.

#### C.13 — Resource Management & Resource Node Contracts

Both downstream systems are **Not Started** at this GDD's authoring. Provisional contracts for the interfaces this GDD requires:

**Resource Management** (downstream — RM consumes Crafting's item definitions):
- Crafting GDD owns the **Oxygen Canister item definition** (recipe + cost + craft-burst). RM owns the oxygen-pulse transfer math (how much oxygen a Canister adds; whether it adds to a player's segment or the squad pool; rate limits).
- Crafting GDD provides the signal: `OnOxygenPulseRequest(amount, requestingPlayerId)` fires from Crafting Service when a player uses an Oxygen Canister or activates a Squad Relay. Amount is recipe-defined (TBD in RM GDD); requestingPlayerId is the using/activating player.
- RM is responsible for the squad oxygen pool's data model, decay tick, and per-player grace timer (per PC.C.5.1).
- **Bidirectional consistency obligation**: RM GDD MUST list Crafting & Items as a dependency (Crafting → RM: oxygen item definition + transfer requests).

**Resource Node** (downstream — RN consumes Crafting's material definitions):
- Crafting GDD owns the **3 material definitions** (BIOMASS, MINERAL, RESONANT). RN owns the per-node yield rates (how many materials per gather; node respawn cadence; node placement).
- Crafting GDD provides the signal: `OnGatherCompleted(playerId, nodeId, materialType, count)` fires from Resource Node Service when a gather succeeds. Crafting Service handles this by adding `count` units of `materialType` to the gathering player's `PersonalInventory`, capped at `MATERIAL_STACK_MAX = 20` per material.
- RN owns the gather emission per ED.C.3.1 (`MAGNITUDE_GATHER_LIGHT/MEDIUM/HEAVY`). Crafting & Items does NOT publish gather emissions — RN does.
- **(round-2: removed)** The Composite Patch ↔ Resource Node gather-downgrade interaction is **gone** with the Patch cut. Crafting no longer exposes a `GetEquippedEffect` accessor to RN, and RN no longer reads any equipped-effect state before computing gather emission magnitude — **a net simplification of the RN contract**. RN's gather emission is now computed solely from node tier (`MAGNITUDE_GATHER_LIGHT/MEDIUM/HEAVY`) with no Crafting-side modifier. *(The H.59 AC that tested this accessor is removed in Phase B.)*
- **Bidirectional consistency obligation**: RN GDD MUST list Crafting & Items as a dependency (Crafting → RN: material definitions; RN → Crafting: gather completions).

#### C.14 — HUD Contract

The HUD GDD is **Not Started**. Provisional contract for the data Crafting & Items publishes for HUD consumption:

| Server-pushed signal | Payload | HUD render expectation |
|---|---|---|
| `OnInventoryChanged` | `{playerId, scope: "personal"\|"squad", itemId, newCount, delta}` | HUD updates inventory readout (personal: this client's bag; squad: shared pool). |
| `OnCraftStarted` | `{benchId, crafterId, recipeId, estimatedCompletionTime}` | HUD shows progress ring on the crafting player's screen (and a smaller indicator on watching squadmates' HUDs). |
| `OnCraftProgressUpdate` | `{benchId, progress: 0.0..1.0}` | ≤ 5 Hz push to the owning client; HUD lerps the progress ring toward the latest server value. |
| `OnCraftCompleted` | `{benchId, recipeId, crafterIds}` | HUD plays a brief completion animation; updates inventory readout via the simultaneous `OnInventoryChanged`. |
| `OnCraftCancelled` | `{benchId, recipeId, reason}` | HUD plays a "fail" animation on the progress ring; dismisses. |
| `OnBenchOccupancyChanged` | `{benchId, crafterCount}` | HUD shows N=2 vs N=1 indicator (squad coordination read). |
| `OnBeaconPlaced` | `{position, placerPlayerId}` | HUD shows a Beacon waypoint marker for all squad members. |
| `OnBeaconActivated` | `{position, activatorPlayerId, timestamp}` | HUD plays the activation cue (white column + flora-snap-to-off) AND **opens the survival-window countdown** — activation is the *window-start* beat, not victory (round-2 change). HUD shows a `BEACON_SURVIVAL_WINDOW` countdown for all squad members. |
| `OnBeaconWindowSurvived` | `{timestamp}` | HUD plays the **victory** sequence (per art-bible §4.4 "Victory" beat). Fires at window-end (BCT4). This is the beat that was previously tied to activation. |
| `OnSignalAnchorTripped` | `{anchorId, anchorPosition}` | HUD shows a directional indicator pointing to the Anchor for `SIGNAL_ANCHOR_INDICATOR_DURATION` (TBD in HUD GDD). |
| `OnEquippedEffectStarted` | `{playerId, effectName, equippedAt, expiresAt?}` | HUD shows an active-effect badge for the equipping player (only the owner sees their own badge by default). |
| `OnEquippedEffectExpired` | `{playerId, effectName, reason}` | HUD removes the active-effect badge. |

**HUD inventory readout obligations** (passed as design intent; HUD GDD owns the visual spec):
- Personal inventory: 3 material counts (BIOMASS, MINERAL, RESONANT) per player; this client sees only their own.
- Squad inventory: 5 item types' counts (Oxygen Canister, Dampener Coil, Signal Anchor, Squad Relay, Beacon); visible to all alive squad members; updates in real time as items are crafted / consumed.
- Bench-armed prompt: when player enters bench `GATHER_PROXIMITY_RADIUS`, HUD shows interaction prompt ("Press E / tap to open bench"). Same pattern as PC's gather proximity prompt.
- **Beacon-cap visual cue**: per ED.F.2a row 7, HUD MAY render a beacon-cap-active indicator when ED's round-5 stationary-squad cap engages. **This is an ED↔HUD obligation, not a Crafting↔HUD obligation** — flagged here for cross-GDD visibility; this GDD does not publish the cap-state signal (ED owns it).

#### C.15 — RemoteEvent Surface

Following PC GDD C.9 format. All client → server requests are validated server-side; rate limits are enforced per-player. All server-pushed events are scoped per the "Direction" column.

| Event | Direction | Payload | Rate Limit | Server Validation |
|---|---|---|---|---|
| `RequestCraft` | C → S | `{recipeId: string}` | 1/s/player sustained; burst up to 3 per 3 s | Per BT1 prelim: alive (not S4/S5); within `GATHER_PROXIMITY_RADIUS` of a bench; recipe in catalog; combined personal-pool has materials; if Beacon, `RunSession.beaconCrafted == false`; player not already a crafter on this bench session |
| `RequestCraftCancel` | C → S | `{}` (bench inferred from active session) | 1/s/player | Player is currently registered as a crafter in an active `CraftSession` |
| `RequestBeaconPlace` | C → S | `{position: Vector3}` — **direction hint only** (round-2 B13) | 1/5 s/player | Alive; has Beacon item in `SquadInventory` (`count >= 1`); `RunSession.beaconPlaced == false`. **Position is NOT trusted as an absolute coordinate**: the server first clamps the requested `position` to lie within `BEACON_PLACE_MAX_RANGE = 8 studs` of the player's **server-tracked** `HumanoidRootPart.Position` (the client value is treated as a direction/target hint, and the clamped point — not the raw client value — is the candidate); then raycast-to-floor from the clamped candidate; then overlap check vs. existing geometry / other beacons. A client value outside max range is clamped to the range boundary, never honored verbatim. See E.22 + H.75. |
| `RequestBeaconActivate` | C → S | `{}` (position is server-tracked via `RunSession.beaconWorldPosition`) | 1/run/squad (enforced by `RunSession.beaconActivated`) | Alive; within `GATHER_PROXIMITY_RADIUS` of `RunSession.beaconWorldPosition`; Beacon in BC3 (`beaconPlaced == true && beaconActivated == false`) |
| `RequestUseItem` | C → S | `{itemId: string}` (Oxygen Canister; instant-use) | 1/s/player sustained; burst up to 3 per 3 s | Alive; item in `SquadInventory` (`count >= 1`); itemId is an instant-use type (currently only Oxygen Canister) |
| `RequestEquipItem` | C → S | `{itemId: string}` (Dampener Coil — the only equippable item post-round-2) | 1/s/player | Alive; item in `SquadInventory`; itemId is an equippable type; player does not have an active equipped instance of the same type |
| `RequestPlaceItem` | C → S | `{itemId: string, position: Vector3}` — **direction hint only** (round-2 B13) | 1/5 s/player | Alive; item in `SquadInventory`; itemId is a placeable type. Same client-position handling as `RequestBeaconPlace`: the requested `position` is clamped to within `BEACON_PLACE_MAX_RANGE` of the player's **server-tracked** position before raycast-to-floor + overlap check; the raw client value is never trusted as an absolute coordinate. See H.75. |
| `RequestActivateRelay` | C → S | `{}` (relay inferred from server's `ActiveDeployables`) | 1/run/squad (consumed at activation) | Alive; within `GATHER_PROXIMITY_RADIUS` of `ActiveDeployables.squadRelay.position`; relay is live |
| `OnInventoryChanged` | S → owning C (personal scope) or squad (shared scope) | `{playerId, scope, itemId, newCount, delta}` | On mutation only | n/a (server-pushed) |
| `OnCraftStarted` | S → C (squad) | `{benchId, crafterId, recipeId, estimatedCompletionTime}` | On BT1/BT2 only | n/a |
| `OnCraftProgressUpdate` | S → owning C only | `{benchId, progress: 0.0..1.0}` | ≤ 5 Hz | n/a |
| `OnCraftCompleted` | S → C (squad) | `{benchId, recipeId, crafterIds: { number }}` | On BT3 only | n/a |
| `OnCraftCancelled` | S → C (squad) | `{benchId, recipeId, reason: string}` | On BT5/BT6 only | n/a |
| `OnBenchArmed` / `OnBenchDisarmed` | S → owning C only | `{benchId}` | On range-cross only | n/a |
| `OnBenchOccupancyChanged` | S → C (squad) | `{benchId, crafterCount}` | On occupancy change only | n/a |
| `OnBeaconPlaced` | S → C (squad) | `{position: Vector3, placerPlayerId: number}` | On BCT2 only | n/a |
| `OnBeaconActivated` | S → C (squad) | `{position: Vector3, activatorPlayerId: number, timestamp: number}` | On BCT3 only | n/a |
| `OnEscapeBeaconActivated` | S → C (squad) | `{activatorPlayerId: number, timestamp: number}` | On BCT3 only — window-**start** cue (HUD countdown + audio Hunt-stem rise). **NOT** the victory trigger (round-2 change) | n/a |
| `OnBeaconWindowSurvived` | S → C (squad) | `{timestamp: number}` | On BCT4 only — **PC's T8 victory subscription** (round-2). Guarded by `RunSession.beaconWindowSurvived` | n/a |
| `OnBeaconDecayed` | S → C (squad) | `{}` | On BCT5 only (defensive decay fallback; normally unreached — run ends at window-end). NOT fired on run-end cleanup per E.8 | n/a |
| `OnSignalAnchorTripped` | S → C (squad) | `{anchorId, anchorPosition: Vector3}` | On single-shot trip only | n/a |
| `OnSignalAnchorExpired` | S → C (squad) | `{anchorId}` | On lifetime expiry only | n/a |
| `OnEquippedEffectStarted` | S → C (squad — owner sees their own badge; squadmates may see a small indicator) | `{playerId, effectName, equippedAt, expiresAt?}` | On equip event only | n/a |
| `OnEquippedEffectExpired` | S → C (squad) | `{playerId, effectName, reason}` | On consumption / expiry / death only | n/a |
| `OnCraftRejected` | S → owning C only | `{reason: string}` | On rejection only | n/a |
| `OnBeaconRejected` | S → owning C only | `{reason: string}` | On rejection only | n/a |

**Trust-boundary enumeration vs. game-concept registry**:
- The game-concept's RemoteEvent enumeration (#2 Craft request, #3 Beacon activation) corresponds to this GDD's `RequestCraft` (#2) and `RequestBeaconActivate` (#3). This GDD's surface adds: `RequestCraftCancel`, `RequestBeaconPlace`, `RequestUseItem`, `RequestEquipItem`, `RequestPlaceItem`, `RequestActivateRelay` — operational sub-events of the same crafting trust boundary. Architecture phase will reconcile via an ADR enumerating the full Crafting trust boundary.
- **Per-player global RemoteEvent budget** (game-concept tech risk row): this GDD adds 8 client-initiated events. Combined with PC's 4 events + ED's 0 client-initiated + RN's expected 1 (RequestGather) = 13 client-initiated total at MVP. Budget headroom remains for HUD's pings/emotes (already 2 in PC), Predator AI, and future content.

**Per-event rate limits + per-player global rate limit** (game-concept tech risk): each event has a per-player rate limit above. The architecture phase ADR additionally enforces a per-player **global** rate limit across ALL Crafting events combined to defend against the spam-multiple-low-rate-limited-events bypass pattern surfaced in game-concept. Recommended ceiling: `CRAFTING_GLOBAL_RATE_LIMIT = 8 events/s/player` with a 2 s burst window of 16 events.

**Global-limit reachability (round-2 B15)**: round-1 flagged that a single legitimately-motivated player might reach `8 events/s`. Re-assessed: the global limit is an **abuse backstop, not an expected operating point**. Summing the per-event sustained ceilings for one player — `RequestCraft` (1/s) + `RequestUseItem` (1/s) + `RequestCraftCancel` (1/s) + `RequestEquipItem` (1/s) + the 1/5-s-gated place/beacon events (~0.2/s each) + the 1/run/squad activate events (~0/s sustained) — yields a legitimate sustained ceiling of **~4–5 events/s** even for a player frantically cycling every flow at once, comfortably under 8. The burst window (16 events / 2 s) absorbs legitimate retry-after-rejection bursts (the B12 fix) without tripping. The limit therefore gates only genuine cycle-between-events abuse; no legitimate single-player pattern reaches it. The constant is left at `8` (range 4–16 per G.7) — lowering toward 4 would risk false positives on a 4-action squad burst; raising it weakens the backstop. Verified by H.64 (legitimate multi-bench burst stays under) + H.26 (abuse pattern blocked).

## Formulas

### D.1 — Craft Progress (per-Heartbeat update)

Server-authoritative accumulator running while a `CraftSession` is active (bench states BS2/BS3). Client receives `OnCraftProgressUpdate` at ≤ 5 Hz for visual rendering; the server's value is canonical. Drives BT3 (`craftProgress >= 1.0`).

`progress_new = clamp(progress + craftRate * dt, 0.0, 1.0)`

where `craftRate = 1.0 / (CRAFT_BASE_DWELL_TIME * crafterSpeedMultiplier(N))`

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current progress | `progress` | float | 0.0–1.0 | Craft progress at start of this Heartbeat tick |
| Frame delta | `dt` | float | typical 1/60 s; up to 1/30 s on slow servers | Seconds since previous Heartbeat; sourced from `RunService.Heartbeat` event arg |
| Per-recipe dwell time | `CRAFT_BASE_DWELL_TIME` | float | 2 s – 10 s (locked per recipe in C.2) | Seconds to complete the recipe at N=1. Not a global constant — varies per recipe |
| Crafter speed multiplier | `crafterSpeedMultiplier(N)` | float | 1.0–2.0 | Output of D.2; scales effective rate by crafter count |
| Craft rate | `craftRate` | float | 0.0167 s⁻¹ – 1.0 s⁻¹ | Fractional progress gained per second at the current N |
| Result | `progress_new` | float | 0.0–1.0 | Progress after this tick |

**Output Range**: `[0.0, 1.0]`, hard clamped. Upper clamp means the formula is idempotent once completion is reached — the tick that crosses 1.0 transitions BT3 atomically and the `CraftSession` is cleared before the next Heartbeat.

**Worked example** (Escape Beacon, N=1, 60 Hz server): `craftRate = 1.0 / (10.0 × 1.0) = 0.10 progress/s`. Per tick: `progress_new ≈ 0.00167`. Time to completion: 10.0 s = 600 ticks. Oxygen Canister (2 s dwell, N=1): `craftRate = 0.50 progress/s`; completes in 2.0 s / 120 ticks.

### D.2 — Multi-Crafter Dwell-Time Reduction

Derives the effective craft rate when N players are at the same bench. Applied by D.1 as `crafterSpeedMultiplier(N)`.

`crafterSpeedMultiplier(N) = min(N, benchMaxCraftersEffective)`

Equivalently: `dwell_effective = CRAFT_BASE_DWELL_TIME / min(N, benchMaxCraftersEffective)`

where `benchMaxCraftersEffective = min(BENCH_MAX_CRAFTERS, ceil(squadSize / 2))` (C.3.5) — the squad-scaled cap (round-2). In a 2-player squad this is 1, so `crafterSpeedMultiplier ≡ 1.0` (no multi-crafter speedup is possible — BS3 is unreachable); in 3–4-player squads it is 2.

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Current crafter count | `N` | int | 1–`benchMaxCraftersEffective` | `|CraftSession.crafters|` at the current Heartbeat; sourced from `CraftSession.lastCrafterCount` |
| Effective per-bench cap | `benchMaxCraftersEffective` | int | 1–2 | `min(BENCH_MAX_CRAFTERS, ceil(squadSize/2))`; computed at run start; enforced by BT2 entry guard |
| Max crafters constant (ceiling) | `BENCH_MAX_CRAFTERS` | int | 2 (locked) | Hard ceiling on the effective cap |
| Result (multiplier) | `crafterSpeedMultiplier` | float | 1.0–2.0 | Multiplier applied to `craftRate` in D.1 |
| Result (effective dwell) | `dwell_effective` | float | `CRAFT_BASE_DWELL_TIME / 2` – `CRAFT_BASE_DWELL_TIME` s | Actual wall-clock completion time |

**Output Range**: discrete set `{1.0, 2.0}` under MVP rules (and `{1.0}` only, in a 2-player squad). The `min()` clamp guards against any race condition that could yield N > cap — BT2's pre-transition guard is the primary defence; this clamp is the secondary.

**Rate-change on BT2/BT4**: when `N` changes mid-craft, `craftRate` is recalculated at the new `N` from the *current* `progress`. Progress is preserved; only the going-forward rate changes. No retroactive credit.

**Worked example** (Escape Beacon, 10 s base dwell): N=1 → `craftRate = 0.100/s`, dwell 10 s. N=2 → `craftRate = 0.200/s`, dwell 5 s. If the second crafter joins at `progress = 0.5` (5 s elapsed at N=1), remaining = `0.5 / 0.200 = 2.5 s`; total wall-clock = 7.5 s — faster than solo 10 s, slower than full N=2 5 s. Demonstrates "progress preserved, rate changed" semantics.

### D.3 — Multi-Crafter Disturbance Emission at Completion

A dispatch rule, not a scalar formula. At BT3 (craft completion) with `N` crafters in `CraftSession.crafters`, the server fires `N` independent `DisturbanceService:Emit` calls — one per crafter — each carrying the recipe's full base burst magnitude.

```
for each crafterId_i in CraftSession.crafters:
    DisturbanceService:Emit(
        emissionType     = "Craft",
        position         = benchPosition,        -- immutable world position; NOT player HumanoidRootPart
        initialMagnitude = recipeBurstMagnitude, -- from C.2 per-recipe constant
        sourcePlayerId   = crafterId_i
    )
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Crafter count | `N` | int | 1–2 | `|CraftSession.crafters|` at BT3 moment |
| Per-recipe burst magnitude | `recipeBurstMagnitude` | float | 0.10–0.35 | `MAGNITUDE_CRAFT_*` constant from C.2 for the completing recipe; same value used for all N calls |
| Bench world position | `benchPosition` | Vector3 | world-space (XZ significant) | Immutable; set at level-design time |
| Total field contribution at bench (instantaneous) | `totalContribution` | float | `N × recipeBurstMagnitude × falloff(0)` ≈ `N × recipeBurstMagnitude` | At `dist2D = 0`, falloff = 1.0; bench position receives the full sum immediately post-emission |

**Output Range**: each individual emission is bounded `[0.10, 0.35]` — well below ED.C.1.2's reserved-band ceiling of 0.85. N=2 worst-case raw sum: `2 × 0.35 = 0.70` at the bench — still below 0.85, reserved-band compliant.

**Attribution rationale**: individual `sourcePlayerId` per emission preserves the ED attribution chain (C.11.1) and per-player analytics. It does not create an exploit because per-emission magnitudes are locked recipe constants, not user-supplied.

**Worked example** (Escape Beacon, N=2, `recipeBurstMagnitude = 0.35`): two `Emit` calls fire atomically at BT3. At the bench position post-emission: `fieldValue ≥ min(1.0, 0.35 + 0.35) = 0.70` (Hunt-tier spike, `t > HUNT_THRESHOLD = 0.65`). A solo crafter on the same recipe produces `t = 0.35` (Tense tier) — the coordination cost to the squad for going 2× faster is a Hunt-floor lure window instead of a Tense spike.

### D.4 — Composite Patch Gather-Magnitude Downgrade — *REMOVED (round-2, 2026-05-30)*

> The Composite Patch recipe was cut (C.2 round-2 catalog revision). This formula and its `PATCH_DOWNGRADE_TABLE` lookup are removed. The section header is retained (numbering preserved so `D.6` / `D.7` and their citations are unaffected). Resource Node no longer applies any gather-magnitude downgrade — it emits the nominal node-tier magnitude (`MAGNITUDE_GATHER_LIGHT/MEDIUM/HEAVY`) directly. The H.34 / H.35 ACs that tested this formula are removed in Phase B.

### D.5 — Quiet Step Wrap Sprint-Magnitude Reduction — *REMOVED (round-2, 2026-05-30)*

> The Quiet Step Wrap recipe was cut (C.2 round-2 catalog revision). This formula and `QUIET_STEP_WRAP_REDUCTION` are removed; the constant is deleted from G.5 in Phase B. The section header is retained (numbering preserved). With the Wrap gone, the only remaining emission modifier is the Dampener Coil (D.6), and the canonical order-of-operations collapses to the single 2-stage chain in D.6a. The H.36 AC and the E.15 edge case that tested the Wrap × grace-window interaction are removed in Phase B.

### D.6 — Dampener Coil Light-Magnitude Reduction

Applied to ALL Light pulse emissions fired by the equipped player while the Coil is active (duration `DAMPENER_DURATION = 60 s`, or until next bench visit or death). Each covered pulse is reduced; the Coil is not consumed per pulse — it expires on time/condition.

`effective_light_magnitude = MAGNITUDE_LIGHT_PULSE × (1 − DAMPENER_REDUCTION)`

where `DAMPENER_REDUCTION = 0.50` (50 % reduction).

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Base light magnitude | `MAGNITUDE_LIGHT_PULSE` | float | 0.08 (locked, ED registry) | Nominal light pulse magnitude before any modification |
| Coil reduction factor | `DAMPENER_REDUCTION` | float | 0.50 (tunable; range 0.30–0.70) | Fractional reduction applied to every Light pulse while active |
| Coil active duration | `DAMPENER_DURATION` | float | 60 s (locked, C.2) | Real-time remaining for the Coil effect; tracked via `EquippedEffects[playerId].dampenerCoil.expiresAt` |
| Result | `effective_light_magnitude` | float | 0.024–0.056 over tuning range | Magnitude forwarded to `DisturbanceService:Emit` for each covered Light pulse |

**Output Range**: at default tunings, `0.08 × 0.50 = 0.04`. Over the tuning range `[0.30, 0.70]`, output spans `[0.024, 0.056]`. The lower bound (0.024) approximates a stationary-attenuated Light pulse (PC D.4) — at `DAMPENER_REDUCTION = 0.70`, the Coil's effect matches maximum stationary attenuation even while moving, which would make raising the lantern while moving nearly silent; this is why 0.70 is the ceiling, not a recommendation.

**Non-linear threshold effect**: a stationary Coil-equipped player's effective Light pulse is `0.04 × STATIONARY_EMISSION_FACTOR = 0.04 × 0.30 = 0.012` — below `MAGNITUDE_FLOOR = 0.02`. The pulse expires immediately. The Coil's true value at default tunings is *making stationary lantern-bearers effectively silent* in the disturbance field, not the linear 50 % reduction.

**Worked example**: player equips Dampener Coil at run-second 60; raises lantern. Light pulses at seconds 64, 68, 72, …, 116 are each: `effective_light_magnitude = 0.08 × 0.50 = 0.04`. At second 120 (`expiresAt = 60 + 60 = 120 s`), Coil expires. Pulse at second 120: nominal 0.08. The 15 covered pulses each cost the squad 0.04 instead of 0.08 — a half-price lantern window for 60 real seconds.

### D.6a — Canonical Emission-Modifier Order of Operations

**This is the single, normative pipeline for computing any modified emission magnitude.** Round-1 flagged the modifier order-of-operations as non-deterministic across four review angles (Wrap × grace-window contradiction, Coil × stationary-attenuation order, midpulse attribution, yield-contingent race). The round-2 catalog cut removed the Composite Patch and Quiet Step Wrap, leaving the **Dampener Coil** as the *only* emission-magnitude modifier this GDD owns. The four-angle ambiguity therefore collapses to one declared 2-stage chain.

**Canonical chain** (applied to any pulse emission whose owner has gameplay modifiers active):

```
magnitude_final = clamp_floor(
    base_magnitude                       -- nominal pulse magnitude (ED registry; e.g. MAGNITUDE_LIGHT_PULSE = 0.08)
    × gameplay_modifier                  -- Stage 1: Dampener Coil ×(1 − DAMPENER_REDUCTION) if active on a Light pulse; else ×1.0
    × pc_stationary_attenuation,         -- Stage 2: PC.D.4 stationary factor (×STATIONARY_EMISSION_FACTOR = 0.30 when stationary; else ×1.0)
    MAGNITUDE_FLOOR                      -- discard: if result < MAGNITUDE_FLOOR = 0.02, the emission is NOT fired (ED zero-magnitude rejection)
)
```

**Stage order is fixed and total:**

| Stage | Operator | Owner | Applies to | Notes |
|---|---|---|---|---|
| 0 — Base | `base_magnitude` | ED registry | all pulses | The nominal per-action magnitude. |
| 1 — Gameplay modifier | `× (1 − DAMPENER_REDUCTION)` | Crafting (D.6) | Light pulses only, Coil active | The only Crafting-owned modifier post-round-2. If no Coil (or non-Light pulse), factor is 1.0. |
| 2 — PC stationary attenuation | `× STATIONARY_EMISSION_FACTOR` | Player Controller (PC.D.4) | any pulse, when the emitter is stationary | Movement-state attenuation. Independent of Stage 1. |
| 3 — Floor discard | `< MAGNITUDE_FLOOR → no emit` | ED (zero-magnitude rejection) | all | The pulse is dropped, not clamped to the floor. |

**Why Stage 1 before Stage 2**: the two factors are independent multipliers, so the *product* is order-independent arithmetically — but the **discard decision** (Stage 3) is evaluated once, on the final product, after both factors apply. Declaring Stage 1 → Stage 2 → Stage 3 as the canonical sequence removes the round-1 ambiguity about whether a gameplay modifier could push a pulse below floor "before" or "after" stationary attenuation: it is always the single final product that is floor-tested. This is the resolution of round-1 blockers B5/B6/B7 and the missing E.15 AC (E.15 itself is removed with the Wrap, but the Coil × stationary case it half-covered is now the canonical worked example below).

**Worked example (Coil + stationary)**: a stationary Coil-equipped player's Light pulse: `0.08 × 0.50 (Coil) × 0.30 (stationary) = 0.012 < MAGNITUDE_FLOOR = 0.02` → **no emission fired** (Stage 3 discard). This matches the "Non-linear threshold effect" in D.6 and is the single authoritative computation; H.38 in Section H tests exactly this chain. The Coil is **not** consumed by a discarded pulse (the Coil is duration-based, not per-pulse — D.6).

**Determinism guarantee**: because there is exactly one modifier and one declared chain, the project-standard determinism rule (`coding-standards.md` testing determinism) is satisfiable — the same inputs always produce the same `magnitude_final`, testable without playtest.

### D.7 — Beacon Mid-Craft Pulse Trigger

A conditional single-emission rule applied during the Escape Beacon's craft session only. The trigger is idempotent — fires exactly once per craft session regardless of N or mid-craft rate changes.

```
if CraftSession.recipeId == "Beacon"
   AND craftProgress >= CRAFT_BEACON_MIDPULSE_PROGRESS
   AND CraftSession.midpulseFired == false:

    DisturbanceService:Emit(
        emissionType     = "Craft",
        position         = benchPosition,
        initialMagnitude = MAGNITUDE_CRAFT_BEACON_MIDPULSE = 0.18,
        sourcePlayerId   = CraftSession.primaryCrafterId   -- stable BT1 initiator; NOT crafters[1] (which can shift on BT4 departure — round-2 B7); not duplicated for N=2
    )
    CraftSession.midpulseFired = true
```

| Variable | Symbol | Type | Range | Description |
|---|---|---|---|---|
| Midpulse progress threshold | `CRAFT_BEACON_MIDPULSE_PROGRESS` | float | 0.5 (tunable; range 0.4–0.6) | Fractional progress at which the pulse fires |
| Midpulse magnitude | `MAGNITUDE_CRAFT_BEACON_MIDPULSE` | float | 0.18 (locked, C.2) | Emission magnitude of the mid-craft pulse; equals `MAGNITUDE_CRAFT_MID` |
| Idempotency flag | `CraftSession.midpulseFired` | bool | {false, true} | Set true after firing; prevents re-fire in same session |
| Attribution | `CraftSession.primaryCrafterId` | int (UserId) | — | Stable BT1 initiator (round-2 B7 — NOT `crafters[1]`, which can shift if the initiator departs via BT4); midpulse uses single attribution, not N |

**Output Range**: zero or one emission per craft session. The `midpulseFired` flag makes the trigger boolean. Does not fire if Beacon craft is cancelled before threshold.

**Wall-clock timing** (proportional, not time-absolute):

| N | `dwell_effective` | Wall-clock at midpulse (progress = 0.5) |
|---|---|---|
| 1 | 10.0 s | ~5.0 s |
| 2 | 5.0 s | ~2.5 s |

At N=2, the squad hears the bench twice in short succession (midpulse at 2.5 s, completion burst at 5.0 s) — concentrating the crafting noise into 2.5 seconds rather than spreading over 10 s. Multi-crafter Beacon crafting is faster but acoustically denser.

**Tuning note**: `CRAFT_BEACON_MIDPULSE_PROGRESS = 0.5` creates a halftime beat — the squad hears the bench at the midpoint and again at completion, two equal warning beats. Below 0.4 fires the midpulse too early; above 0.6 clusters midpulse and completion too tightly.

## Edge Cases

This section enumerates 24 live edge cases (numbered through E.26; E.14 + E.15 retired in the round-2 catalog cut) organized into 11 categories. Each case specifies the triggering condition, the exact server-authoritative outcome, the rule from C/D it protects, and any cross-GDD interaction. **[P0]** marks exploit / race / data-corruption risks; unmarked entries are degenerate-strategy or attribution-correctness cases. Design-gap resolutions applied per the systems-designer review (2026-04-30) are noted inline. The round-2 patch (2026-06-01) added E.24–E.26 for the Beacon survival window.

### Inventory & Equipped Effects

**E.1 — Equipped Dampener Coil owner dies mid-effect**
- **If**: Player has an active `DampenerCoil` (within `DAMPENER_DURATION = 60 s` window) and dies (PC.T5 fires).
- **Then**: Atomically on the same Heartbeat as `Humanoid.Died`, before any pending input from that tick is processed: clear `EquippedEffects[playerId].dampenerCoil`; do **NOT** return the Coil to `SquadInventory`; fire `OnEquippedEffectExpired(playerId, "DampenerCoil", reason="death")`.
- **Why**: Per C.6, the Dampener Coil is *consumed on equip* — it is the only equippable item in the round-2 catalog. Death after equip therefore does not return the Coil to the squad pool: it was already spent at equip-time, and the active effect simply terminates. Documents the consume-on-equip semantic so implementers do not mistakenly add a death-return path for it.
- **Cross-system**: PC.S4 entry. Atomicity guarantee per gap-resolution G2.

### Bench Occupancy

**E.2 — Third player attempts to join an in-progress craft**
- **If**: Bench is in BS3 (two crafters active) and a third player fires `RequestCraft(recipeId)` for the same recipe.
- **Then**: Reject with `OnCraftRejected(reason="bench-full")`. Bench remains armed for the third player (no `OnBenchDisarmed` fires) — they may retry once a crafter departs.
- **Why**: Enforces the effective cap `benchMaxCraftersEffective = min(BENCH_MAX_CRAFTERS, ceil(squadSize/2))` (C.3.5) — the hard ceiling `BENCH_MAX_CRAFTERS = 2` is reached only in 3–4-player squads; in a 2-player squad the effective cap is 1 and even a *second* joiner is rejected here. Without explicit rejection an over-cap `sourcePlayerId` would enter D.3's emission loop, producing an extra independent emission and breaking the dwell-rate model.

**E.3 — Join attempt at exactly `craftProgress = 0.85`**
- **If**: A second player fires `RequestCraft(recipeId)` and server-side `craftProgress` is exactly `0.85` at validation moment.
- **Then**: Reject with `OnCraftRejected(reason="too-late-to-join")`. The cutoff uses **strict less-than** (`craftProgress < CRAFT_JOIN_CUTOFF`); `0.849999...` admits, `0.85` does not.
- **Why**: Floating-point boundary contract. A `<=` mistake would let a player join in the final 15% and receive D.3 attribution for trivial contribution.

**E.4 — Simultaneous join attempts from two players**
- **If**: Two players fire `RequestCraft(recipeId)` for the same recipe on the same Heartbeat while bench is BS2 with `craftProgress < 0.85`.
- **Then**: Roblox Luau's single-threaded server execution sequences them. First admitted (BS2 → BS3, N=2). Second now sees `|crafters| = BENCH_MAX_CRAFTERS` and is rejected with `bench-full`.
- **Why**: The single-threaded scheduler is the architectural race-guard. No mutex required. Implementations MUST NOT introduce async patterns (coroutines yielding inside the handler) that break the guarantee.

**E.5 — Original crafter cancels late while joiner has passed cutoff**
- **If**: Bench is in BS3 with `craftProgress = 0.90`. Crafter[1] fires `RequestCraftCancel`.
- **Then**: BT4 fires: crafter[1] removed from `CraftSession.crafters`; bench → BS2 with crafter[2] at progress 0.90. When crafter[2] reaches BT3, **only crafter[2]'s emission fires** — D.3 iterates `CraftSession.crafters` at the moment of BT3, not historical members.
- **Why**: Closes the "join, leave at 0.84, let the other complete" deserter exploit — the leaver pays nothing, the completer pays the full per-crafter emission. Confirms attribution is snapshotted at BT3.

### Material Deduction Races

**E.6 [P0] — Squad pool drops below recipe cost between BT1 validation and BT3 completion**
- **If**: At BT1 the combined personal pool is sufficient. During the craft window, a concurrent craft on a different bench fires its BT3 first and deducts a material that puts the running craft's pool below cost.
- **Then**: At the running craft's BT3, the atomic deduction fails. BT6 fires: `OnCraftCancelled(benchId, recipeId, reason="insufficient-materials")`. No materials deducted, no item added, no emission. The other (already-completed) craft retains its emission — only the failing craft is rolled back.
- **Why**: Two independent CraftSessions racing for the same shared pool. The HUD must distinguish this mid-craft cancellation from player-initiated cancel and from pre-craft `OnCraftRejected`.
- **Cross-system**: HUD GDD reason taxonomy.

**E.7 [P0] — Solo crafter dies with all Beacon materials in personal inventory**
- **If**: Solo player at bench (BS2), all 8 Beacon materials in their personal inventory, `craftProgress = 0.70`. Player dies.
- **Then**: BT5 fires: `CraftSession` cleared, progress discarded, no emission, no materials deducted. The dead player's `PersonalInventory` is **LOCKED** (per C.3.6) — not cleared. On respawn the inventory unlocks with the full material count intact; the player can re-approach the bench and start over.
- **Why**: Two failure modes prevented: (a) materials permanently lost on death (they aren't — death locks, not wipes); (b) the locked inventory being mistakenly drawn from by a concurrent BT3 deduction on a different bench. The LOCK is the critical guarantee.
- **Cross-system**: PC.S4, C.3.6 inventory-lock, C.10 death-cleanup.

### Beacon Lifecycle

**E.8 — Beacon placed but not activated when squad wipes**
- **If**: Beacon is in BC3 (placed, inert). All squad members enter PC.S4 simultaneously with no alive player within `GATHER_PROXIMITY_RADIUS = 4 studs` of the beacon.
- **Then**: `RunEnded` fires. Beacon BasePart removed from workspace via the **run-end cleanup path**, which is distinct from the defensive decay transition BCT5: `OnBeaconDecayed` MUST NOT fire (BCT5 requires natural source-expiry, not a forced cleanup). `RunSession.beaconPlaced` cleared with the session.
- **Why**: HUD must suppress `OnBeaconDecayed` for run-end removal — otherwise the squad's last frame shows a "beacon decayed" notification on top of the defeat screen, which is misleading. Distinct code path is contractual. *(Round-2 renumber: the decay transition was BCT4 pre-round-2; it is now BCT5 because the new victory transition took the BCT4 slot — see C.9.)*

**E.9 [P0] — Beacon activator dies on the same Heartbeat as activation**
- **If**: Player fires `RequestBeaconActivate` and `Humanoid.Died` fires for them on the same Heartbeat.
- **Then**: Server validates `alive` inside the `RequestBeaconActivate` handler. If validation passes (the Died event has not yet been processed by the server's event order this tick), BCT3 fires atomically: `RunSession.beaconActivated = true`; `DisturbanceService:Emit(magnitude=0.95, sourcePlayerId=RunSession.beaconPlacerId, ...)`; `OnEscapeBeaconActivated` fires; T8 fires. The activating player's death does **NOT** affect attribution — the emission is attributed to `beaconPlacerId`, not the activator. **Run ends in victory regardless of activator survival.**
- **Why**: The win condition must be valid if the Beacon was legitimately activated before or concurrent with death. The `alive` guard is defense-in-depth against a dead player's buffered request completing after their PC state transitions to S4.

**E.10 — Attempted second Beacon craft when `RunSession.beaconCrafted = true`**
- **If**: Beacon already crafted (`beaconCrafted = true`) — whether currently in inventory, placed, or activated — and a player fires `RequestCraft(recipeId="EscapeBeacon")`.
- **Then**: BT1 pre-validation rejects with `OnCraftRejected(reason="beacon-already-crafted")`. No `CraftSession` created; no materials deducted.
- **Why**: Once-per-run gate. `RunSession.beaconCrafted` is set true at BC2 and **never reset within a RunSession** — only cleared at `RunEnded`. Documents the invariant any future BC2-rollback bug would violate.

### Multi-Crafter Completion

**E.11 — One crafter cancels at exactly `craftProgress = 0.84`**
- **If**: Bench in BS3 with `craftProgress = 0.84`. Crafter[1] fires `RequestCraftCancel`.
- **Then**: BT4: crafter[1] removed; bench → BS2; crafter[2] continues at 0.84 with N=1 rate. At any later moment while `craftProgress < 0.85`, a *third* player MAY join (BT2 fires again, bench → BS3 with new crafters[]). The cutoff applies to **join decisions**, not to cancel decisions.
- **Why**: BT4 reduces N but does not close the join window. The `< 0.85` rule is the only gate on joining.

**E.12 [P0] — Both crafters die simultaneously at `craftProgress = 0.50`**
- **If**: Both crafters of a BS3 session die on the same Heartbeat.
- **Then**: Death handlers process sequentially per Luau scheduler. First death: BT4 (BS3 → BS2 with crafter[2] still in `crafters`, but they are also dead and will be processed next). Second death: handler MUST check `if removing this crafter empties the array, fire BT5; else fire BT4`. With this check, second death fires BT5: `CraftSession` cleared, no emission, no deduction, both inventories LOCKED.
- **Why**: A naive implementation that always fires BT4 leaves a zombie session in BS2 with no crafters — never resolves. The post-removal emptiness check is the implementation invariant.

**E.13 [P0] — Crafter exits bench radius without firing `RequestCraftCancel`**
- **If**: Player in BS2 walks > `GATHER_PROXIMITY_RADIUS + 2 studs = 6 studs` from the bench while `craftProgress = 0.40`, without sending a cancel RemoteEvent.
- **Then**: A **server-side** proximity watcher running at `FIELD_UPDATE_HZ = 5` cadence (gap-resolution G5) detects the violation and fires BT5: session cleared, progress discarded, no emission, no deduction, `OnCraftCancelled(reason="out-of-range")`. The check is server-authoritative — never client-reported — to prevent a client from suppressing position updates to maintain a phantom session.
- **Why**: Without server-driven detection, a client that stops sending input while walking away holds an indefinite craft slot. The 5 Hz cadence inherits ED's field-update cadence; an architecture ADR will pin the exact watcher mechanism per gap-resolution G5.

### Aid Item Effects

**E.14, E.15 — *REMOVED (round-2, 2026-06-01)*** — both covered cut recipes: E.14 was the Composite Patch Light-node floor case (D.4), E.15 was the Quiet Step Wrap × `FIRST_PULSE_GRACE_WINDOW` interaction (D.5). With the Patch and Wrap cut from the catalog (C.2 round-2 revision), neither edge case exists. The numbers are retired (not reused) so downstream citations resolve unambiguously. The Dampener Coil — the only remaining equippable — is covered by E.1 (death) and the canonical order-of-operations D.6a (its single interaction with PC stationary attenuation, formerly the half-covered concern behind E.15).

### Signal Anchor

**E.16 — Multiple Anchors: second placement while first is live**
- **If**: Squad has two Signal Anchors in inventory. First placed and live (within `SIGNAL_ANCHOR_LIFETIME = 45 s`). A player places the second.
- **Then**: Server cancels the first: (1) remove first Anchor BasePart; (2) fire `OnSignalAnchorExpired(anchorId, reason="replaced")` — the reason enum is `replaced | lifetime | tripped` per gap-resolution G8; (3) spawn second Anchor BasePart; (4) update `ActiveDeployables.signalAnchor`. Second Anchor's item is consumed only on successful placement.
- **Why**: Single-Anchor-at-a-time prevents a perimeter of Anchors around a safe room — that would constitute base-building, violating the game-concept anti-pillar. The cancel-on-place rule is the mechanical enforcement.
- **Cross-system**: HUD GDD branches on `OnSignalAnchorExpired.reason` for distinct UI feedback.

### Disturbance & Attribution

**E.17 — Craft emission fires during active Beacon window (Hunt-floor cap interaction)**
- **If**: Beacon is in BC4 (active) and ED.C.3.6's Hunt-floor cap is engaged at the beacon position. A squad member completes a Signal Anchor craft at a bench (Craft burst at bench position).
- **Then**: The cap is **position-specific** — it clamps `fieldValue(beacon-position)` only. The bench position's `fieldValue` is computed independently per D.3 and includes the bench's Craft burst plus the Beacon's spatial-falloff contribution (zero if bench-to-beacon distance > `INFLUENCE_RADIUS = 24 studs`). The cap does **NOT** affect bench emissions.
- **Why**: Clarifies cap scope. Squad crafting during the Beacon window adds a secondary disturbance hotspot at the bench — a deliberate distraction vector, not a bug.
- **Cross-system**: ED.C.3.6 (cap rule), ED.E.25 (cap engagement). Crafting-side behaviour during the cap window — does not duplicate ED.E.25.

**E.18 — N=2 crafters complete simultaneously: two emissions at same position**
- **If**: BS3 reaches BT3. D.3 fires two `Emit` calls — both at `benchPosition`, same `initialMagnitude`, different `sourcePlayerId`.
- **Then**: Per ED.C.1.5 + ED.E.3, the two sources do **NOT** merge in the live-source list — they are independent attributable sources. Bench position `fieldValue` immediately post-emission: `min(1.0, 2 × initialMagnitude)`. The hotspot dedup grid (`HOTSPOT_DEDUP_GRID_SIZE = 4 studs`) collapses them to a single hotspot **candidate** for predator targeting, but both sources decay independently in the live-source list. Attribution preserved per crafter.
- **Why**: Confirms D.3 dispatch produces two-emission output and ED handles it correctly. Surface so future implementers don't add a "same position, same tick → merge" optimization that would corrupt attribution.

### Player Controller Interactions

**E.19 — Player dies while registered as crafter: emission attribution**
- **If**: Player is in `CraftSession.crafters` and dies mid-craft. (The session continues if N was 2 before the death; cancels if N was 1 — covered by E.7 / E.12.)
- **Then**: When N=2 becomes 1, BT4 removes the dead player from `CraftSession.crafters`. At BT3 of the surviving crafter, D.3's emission loop iterates only the surviving member — the dead player receives **no completion emission attribution**. Their personal inventory is LOCKED until respawn; the BT3 deduction draws from alive squad members per E.7's order.
- **Why**: Attribution is determined by the *array contents at the moment of BT3*, not by historical membership. A dead crafter who left at BT4 is not attributed. The disturbance log correctly records the completion as the surviving crafter's action.

### Server-Authority & Exploit Attempts

**E.20 [P0] — Client claims craft completion early (timing attack on RequestUseItem)**
- **If**: A malicious client fires `RequestUseItem` for an item before the server's BT3 has fired (item is not yet in `SquadInventory`).
- **Then**: Validation: `item in SquadInventory AND count >= 1` fails. Reject with `OnCraftRejected(reason="item-unavailable")`. Server BT3 timeline is unaffected; no item effect fires; no emission.
- **Why**: The server is the sole authority for `SquadInventory`. Items do not exist until BT3's atomic creation step. Defense is the inventory-presence check; rate limit is the secondary throttle.

**E.21 [P0] — Client claims material count mismatch (inventory inflation attack)**
- **If**: A malicious client fires `RequestCraft(recipeId="EscapeBeacon")` while their server-side personal inventory has insufficient materials.
- **Then**: BT1 reads `PersonalInventory[playerId]` directly from server-authoritative state and computes the alive-squad combined pool. If insufficient, reject with `OnCraftRejected(reason="insufficient-materials")`. **The `RequestCraft` payload contains only `recipeId` (per C.15) — no material-count field exists to spoof.**
- **Why**: Schema-level defense. The server never reads material counts from the request payload. Documents the schema design as the primary exploit closure, not just a runtime check.

**E.22 [P0] — Client fires RequestBeaconActivate before Beacon is placed (false-victory attempt)**
- **If**: A malicious client fires `RequestBeaconActivate` while `RunSession.beaconPlaced = false`.
- **Then**: BCT3 pre-validation requires `beaconPlaced == true AND beaconActivated == false`. Both flags are server-authoritative and never exposed as writable client inputs. Reject with `OnBeaconRejected(reason="beacon-not-placed")`. No emission, no T8, no win.
- **Why**: Two-layer flag validation. An attacker must bypass two server-only flags to trigger a false win — neither is reachable from the client side. The most-exploitable RemoteEvent in the system is closed by schema + flag invariants.

**E.23 — `RequestCraft` and `RequestBeaconActivate` flood (rate limit coverage)**
- **If**: A client floods the server with 50 `RequestCraft` calls in 1 s.
- **Then**: Per-event rate limit (`RequestCraft: 1/s/player sustained; burst 3 per 3 s` — round-2 B12) gates the first wave. After burst exhaustion, excess requests are **silently dropped** (no `OnCraftRejected` per excess to avoid log-flooding the client). The global limit `CRAFTING_GLOBAL_RATE_LIMIT = 8 events/s/player` caps the combined per-player Crafting RemoteEvent traffic, preventing cycle-between-events bypass. Server logs the first excess request per player per second for the ops trail.
- **Why**: ED.E.12's `MAX_LIVE_SOURCES = 500` is the downstream defense against emission spam; this case covers the RemoteEvent layer before any Emit is reached. Two-layer rate-limit pairing per C.15.

### Beacon Survival Window (round-2)

**E.24 [P0] — Full-squad wipe during the survival window (defeat)**
- **If**: Beacon is in BC4 (activated; survival window counting down) and the **last living** squad member dies (`Humanoid.Died`) before `now - beaconActivationTime >= BEACON_SURVIVAL_WINDOW`.
- **Then**: BCT-DEFEAT fires (C.9): the run ends in defeat via PC's existing all-dead `RunEnded(defeat)` path; the Beacon BasePart is removed via the run-end cleanup path; the survival-window + decay-watch timers are cleared. **`OnBeaconWindowSurvived` does NOT fire** (no victory) and **`OnBeaconDecayed` does NOT fire** (run-end cleanup, not natural decay — consistent with E.8). Crafting fires no separate defeat signal.
- **Why**: Activation is no longer an instant win (round-2 keystone). A squad that rushed the Beacon with no aid preparation can be wiped during its own loud finale — this is the design-intended failure mode that makes the aid suite load-bearing. The "no `OnBeaconWindowSurvived`/`OnBeaconDecayed`" rule prevents a victory cue or a "beacon decayed" notification from painting over the defeat screen.
- **Cross-system**: PC all-dead `RunEnded(defeat)` path; C.9 BCT-DEFEAT.

**E.25 [P0] — Last living player dies on the exact window-end Heartbeat (tie-break)**
- **If**: On a single Heartbeat, both conditions are true for the beacon in BC4: the survival-window timer has elapsed (`now - beaconActivationTime >= BEACON_SURVIVAL_WINDOW`) **AND** the last living squad member's `Humanoid.Died` fires.
- **Then**: **Window-survival is evaluated FIRST** (C.9 tie-break rule): BCT4 fires → `OnBeaconWindowSurvived` → T8 victory. The squad that lived *to* the window boundary escapes even though a member dies on that same tick. BCT-DEFEAT is suppressed because BCT4 set the terminal `beaconWindowSurvived` flag and ended the run on the same tick.
- **Why**: Single-threaded Luau cannot process a death and a window-elapse "simultaneously" — the scheduler orders them. Declaring window-survival first makes the boundary deterministic and favors the squad, consistent with E.9 ("activator dies on activation Heartbeat still wins"). A QA tester must get the same victory result every run for this input — the determinism rule (`coding-standards.md`) requires the tie-break be declared, not left to scheduler luck.
- **Cross-system**: C.9 BCT4 vs BCT-DEFEAT mutual-exclusion + tie-break.

**E.26 — Beacon natural decay vs window-survival ordering**
- **If**: A run somehow leaves a beacon source live in ED past the survival window without the run having ended (a defensive-only path — e.g. a bug that suppressed both BCT4 and BCT-DEFEAT).
- **Then**: The defensive decay-watch (BCT5) eventually detects ED source-expiry (`m(t, age) <= MAGNITUDE_FLOOR`, ~501 s after activation) and removes the BasePart, firing `OnBeaconDecayed`. Under all *normal* paths this is unreachable: the run ends in victory (BCT4, ~49 s) or defeat (BCT-DEFEAT) roughly 10× before natural decay. BCT5 is retained only so a stuck beacon source cannot persist indefinitely in ED's live-source list.
- **Why**: Documents that decay is strictly ordered *after* window resolution and is a safety net, not a gameplay outcome. Prevents an implementer from wiring victory/cleanup to the decay event (the pre-round-2 behavior) instead of to the window timer.
- **Cross-system**: ED.D.1 source-expiry; C.9 BCT5.

## Dependencies

Per `ED.F.3a` (Cross-GDD Author Checklist, round-3 addition), this section embeds the bidirectional dependency contract.

### F.1 — Hard Dependencies (Crafting & Items cannot function without)

| Upstream System | What this GDD consumes | Status |
|---|---|---|
| **Player Controller** (`design/gdd/player-controller.md`) | `HumanoidRootPart.Position` for bench proximity gate (C.3.1) and the server-side proximity watcher (E.13). Tap-hold / `E` commit input for bench open (C.3.2). Alive state for all RemoteEvent validation (C.15). `Humanoid.Died` for BT4 / BT5 cleanup (C.8) and equipped-effect death termination (E.1). PC's stationary-attenuation factor (`STATIONARY_EMISSION_FACTOR`) for the canonical Coil × stationary order-of-operations (D.6a). PC-locked constants reused: `TAP_HOLD_COMMIT_DURATION = 0.5 s`, `GATHER_PROXIMITY_RADIUS = 4 studs`. | **GDD exists** — pending design-review (2026-04-30) |
| **Ecological Disturbance** (`design/gdd/ecological-disturbance.md`) | `DisturbanceService:Emit("Beacon" \| "Craft", position, magnitude, sourcePlayerId)` per ED.C.3.6 (Beacon) plus the new `Craft` emission type registered against ED's reserved enum (consumes 1 of 4 reserved slots). ED-locked constants referenced: `MAGNITUDE_BEACON = 0.95`, `BEACON_HALF_LIFE = 90 s`, `MAGNITUDE_FLOOR = 0.02`, `INFLUENCE_RADIUS = 24 studs`, `FIELD_UPDATE_HZ = 5 Hz` (reused for E.13 bench proximity watcher), `HOTSPOT_DEDUP_GRID_SIZE = 4 studs` (E.18 attribution), `BEACON_STATIONARY_*` (E.17 cap-scope clarification). | **In Review** — round-6 fresh-session re-review pending |
| **Roblox `Humanoid` + `Knit` framework** | Engine + framework primitives. Verified at engine setup. | Built-in |

### F.2 — Soft Dependencies (downstream — provisional contracts apply until the dependent GDD is authored)

| System | Direction | Interface | Status |
|---|---|---|---|
| **Resource Node** | RN → Crafting | `OnGatherCompleted(playerId, materialType, count)` adds to `PersonalInventory[playerId]` per C.13. RN owns the gather emission (publishes `Gather` to ED); Crafting receives only the inventory delta. Surplus over `MATERIAL_STACK_MAX = 20` is silently discarded by Crafting (per the discard-on-overflow rule in C.4). | Not Started — provisional contract |
| **Resource Management** | Crafting → RM | (a) Oxygen Canister consumption: `RequestUseItem("OxygenCanister")` triggers RM's oxygen-pool restore — RM owns the restore math (per C.13). (b) Squad Relay activation: `OnOxygenTransferRequest(amount, position)` fires from Crafting on relay activation — RM owns the transfer math and the zero-pool no-op response (per E.26 deferred). | Not Started — provisional contract |
| **Player Controller** | Crafting → PC | **`OnBeaconWindowSurvived(timestamp)`** fires at BCT4 — **PC's T8 (squad escape → victory) trigger** (round-2 change). Fires at most once per RunSession, gated by `RunSession.beaconWindowSurvived` (C.5.6a, C.9). Separately, `OnEscapeBeaconActivated(activatorPlayerId, timestamp)` fires at BCT3 as the survival-window **start** cue (HUD/audio) — PC MUST NOT fire T8 on it. Full-squad wipe during the window (BCT-DEFEAT) routes through PC's existing all-dead `RunEnded(defeat)` path; Crafting fires no separate defeat signal. | **GDD exists** — PC.F.2 + T8 timing need update (see F.4 / F.6) |
| **HUD** | Crafting → HUD | Client-bound signals declared at C.14: `OnBenchArmed(benchId)`, `OnBenchDisarmed(benchId)`, `OnCraftStarted(benchId, recipeId, crafters[])`, `OnCraftProgress(benchId, progress)`, `OnCraftCompleted(benchId, recipeId)`, `OnCraftCancelled(benchId, recipeId, reason)`, `OnCraftRejected(reason)`, `OnInventoryChanged(scope, delta)`, `OnEquippedEffectExpired(playerId, itemId, reason)`, `OnSignalAnchorTripped(anchorId, predatorPosition)`, `OnSignalAnchorExpired(anchorId, reason)` — reason enum `replaced \| lifetime \| tripped` per E.16, `OnBeaconPlaced(position)`, `OnBeaconActivated(...)` — opens the survival-window countdown (round-2), `OnBeaconWindowSurvived(timestamp)` — victory beat at window-end (round-2), `OnBeaconDecayed(beaconId)` — fired only on the defensive natural-decay fallback BCT5, NOT on run-end cleanup per E.8. HUD owns the rendering; Crafting owns the data. *(Full signal-count + Patch/Wrap-badge removal reconciled in Phase B.)* | Not Started — provisional contract |
| **Predator AI** | indirect via ED | The Beacon serves as a Hunt-floor lure target — Predator AI consumes the disturbance field at the beacon position via ED's existing `GetHottestHotspot` API; no direct Crafting → Predator AI contract. Signal Anchor sensor (C.7) reads predator position via Roblox `workspace`/`RaycastParams` queries — also no direct PA contract; the sensor is a passive geometry check that pings the squad HUD. | Not Started — no direct PA contract required |
| **Level Design** | LD → Crafting | Bench `BasePart` placement: one bench per safe room, immobile, level-design owns placement (per C.3). Anchor placement raycast-to-floor distance (G7) inherits level-design's ground-detection convention. | Not Started — flagged for level-design coordination |

### F.3 — Reverse-Cite to ED.F.3a (Cross-GDD Author Checklist)

Per `ED.F.3a`, this GDD must paste/adapt the Crafting & Items block. Doing so here:

> **Section F dependency — Ecological Disturbance**
>
> This system depends on Ecological Disturbance per ED.C.3.6 (Beacon emission contract) plus the new `Craft` emission type (registered against ED's reserved 4-slot enum allocation; consumes 1 slot).
>
> - **Cross-GDD value lock cited**: Crafting & Items does NOT redefine `TENSE_THRESHOLD`, `HUNT_THRESHOLD`, `RETREAT_THRESHOLD`, `HYSTERESIS_BAND`, `STANDARD_HALF_LIFE`, `BEACON_HALF_LIFE`, `MAGNITUDE_FLOOR`, or `INFLUENCE_RADIUS`. ED is the source of truth. The Beacon-specific constants `MAGNITUDE_BEACON = 0.95`, `BEACON_HALF_LIFE = 90 s`, and the `BEACON_STATIONARY_*` family are also ED-owned and referenced (not redefined) here.
> - **Publishing path**: Crafting publishes via `DisturbanceService:Emit(...)` per ED.C.3.6 (Beacon) and the new `Craft` emission type. Crafting does NOT bypass and write to the spatial grid directly. Magnitude per emission type: `MAGNITUDE_BEACON = 0.95` is owned by ED; the `Craft`-type magnitudes (`MAGNITUDE_CRAFT_XS`, `MAGNITUDE_CRAFT_MID`, `MAGNITUDE_CRAFT_RELAY`, `MAGNITUDE_CRAFT_HEAVY`, `MAGNITUDE_CRAFT_BEACON_MIDPULSE`) are owned by THIS GDD's Section G.
> - **Subscribing path**: Crafting & Items does NOT subscribe to any disturbance signal. It is a pure publisher. The Signal Anchor sensor reads predator position directly via Roblox `workspace` queries — it does NOT consume `OnMeterUpdate`, `OnDisturbanceAlert`, or any other ED-owned RemoteSignal. Crafting honours ED's zero-RemoteFunction-on-Client rule (ED.F.4) and the no-client-Emit rule (ED.C.1.8) — see E.20 + E.22 for the server-authority enforcement.
> - **Predator AI F.2a obligations resolved**: NOT APPLICABLE — Crafting & Items is not the Predator AI GDD.

### F.4 — Open Cross-System Obligations Crafting & Items Owes Forward

| Receiving System | Obligation Crafting owes | Notes |
|---|---|---|
| **Player Controller GDD** | PC.F.2 row "Crafting & Items" currently lists `RequestInteract(targetId)` as a placeholder. When PC's next revision opens, replace with the named events from C.15: `RequestCraft`, `RequestBeaconActivate`, `RequestBeaconPlace`, `RequestEquipItem`, `RequestUseItem`, `RequestPlaceItem`, `RequestActivateRelay`, `RequestCraftCancel`. Also note: the bench-OPEN commit (C.3.2) currently has no explicit named RemoteEvent — surface in C revision before architecture. **Round-2 (2026-05-30) — T8 retiming (load-bearing):** PC's T8 (squad escape → victory) transition must now subscribe to **`OnBeaconWindowSurvived`** (fired at BCT4, window-end), **NOT** `OnEscapeBeaconActivated` (which is now only the window-*start* cue). PC must keep its inputs/state active through the ~49 s `BEACON_SURVIVAL_WINDOW` after activation, and only fire T8 on window-survival. Full-squad wipe during the window must resolve as defeat via PC's existing all-dead `RunEnded(defeat)` path. | Surfaced in F.6 below; coordinated update after Crafting locks. **PC GDD is itself in MAJOR REVISION (round-6) — fold this T8 retiming into that revision.** |
| **Ecological Disturbance GDD** | The `Craft` emission type added to ED's reserved 4-slot enum (consuming 1 slot — 3 remain). ED.F.2 row for Crafting currently states "TBD pending Crafting GDD" for trigger conditions and magnitude — this GDD's C.2 + Section G resolve the TBD. Registry update in Phase 5 will register `MAGNITUDE_CRAFT_*` constants and the `Craft` enum value. | Phase 5 registry write. |
| **HUD GDD** | When the HUD GDD is authored, it MUST reverse-cite Crafting's C.14 contract and consume the client-bound signals listed in F.2 / C.14 (round-2 added `OnBeaconActivated` window-start + `OnBeaconWindowSurvived` victory; removed the Patch/Wrap equipped-effect badges). HUD MUST distinguish the cancellation signals (`OnCraftCancelled` reasons: `player-initiated`, `out-of-range`, `insufficient-materials`, `death`) from `OnCraftRejected` (pre-craft validation failure) and from `OnEquippedEffectExpired` (consumable lifecycle end). | HUD reason taxonomy per E.6. |
| **Resource Node GDD** | When RN is authored, it MUST emit `OnGatherCompleted(playerId, materialType, count)` after firing its own `Gather` ED emission. The order matters: the gather emission is RN's responsibility (uses `MAGNITUDE_GATHER_LIGHT/MEDIUM/HEAVY`); the inventory delta is Crafting's responsibility. RN MUST NOT re-raise the gather emission on `MATERIAL_STACK_MAX` overflow (E.1 deferred — but the rule applies regardless). | Surfaced for RN author. |
| **Resource Management GDD** | When RM is authored, it MUST own: (a) Oxygen Canister `OnOxygenRestoreRequested(amount)` consumption — Crafting fires from `RequestUseItem`; RM does the math. (b) Squad Relay `OnOxygenTransferRequest(amount, position)` consumption — RM does the segment-to-segment transfer math and the zero-pool no-op. (c) Crafting does NOT touch RM's oxygen pool directly. | Server-authority boundary. |
| **Predator AI GDD** | When PA is authored, it should add an AC verifying that the Beacon's stationary-squad cap (ED.C.3.6, `BEACON_STATIONARY_CAP_FIELD_VALUE = 0.65`) interacts correctly with PA's locked-target logic (ED.F.2a row 6). No new Crafting interface required. | Already an ED.F.2a row; cross-referenced here for completeness. |
| **Architecture (`/create-architecture`)** | Three ADRs flagged for authorship: (1) **Bench Proximity Watcher** — server-side cadence + mechanism per E.13 / G5 (recommend `RunService.Heartbeat` accumulator at `FIELD_UPDATE_HZ = 5`, but pin in ADR). (2) **Signal Anchor Placement Validation** — raycast-to-floor distance and overlap-check thresholds per E.16 / G7. (3) **Crafting RemoteEvent Trust Boundary** — rate limits, payload schemas, server-authority invariants per C.15 + E.20–E.23. | Architecture phase deliverable. |
| **All future GDDs** | The cosmetic-boundary rule (game-concept + C.3.8) means no equipped cosmetic on bench / recipe icons / craft animations may change craft time, change emission magnitude, change material cost, or hide / obfuscate the burst-at-completion event. Cosmetic items that touch this system MUST pass the dual-clause cosmetic-boundary checklist. | Live-ops + monetization defence. |

### F.5 — Engine and Library Dependencies

| Dependency | Used For | Verification |
|---|---|---|
| **Roblox `BasePart` + `Humanoid`** | Bench placement (BasePart in safe rooms); proximity gate via `HumanoidRootPart.Position` distance check | Engine built-in; verified |
| **Roblox `RunService.Heartbeat`** | Per-Heartbeat craft progress accumulator (D.1) and bench proximity watcher (E.13) | Engine built-in; verified |
| **Roblox `workspace:GetServerTimeNow()`** | All server-side timing: craft start, equipped-effect duration timers, anchor lifetime, beacon midpulse trigger time. Forbidden: `os.time()`, `tick()`, `os.clock()` per ED.D.1. | Engine built-in; verified |
| **Roblox `RaycastParams`** | Signal Anchor placement validation (raycast-to-floor per E.16) and Anchor sensor predator-position queries (C.7) | Engine built-in; verified |
| **Roblox `RemoteEvent` via Knit `RemoteSignal`** | All client-bound craft signals (C.14) and all client-to-server craft requests (C.15). Routed through Knit for unified rate-limit + audit surface. | Library; confirmed at engine setup |
| **Knit `Service` + `Controller`** | `CraftingService` (server) + `CraftingController` (client). All cross-boundary state mutations route through `CraftingService`; client owns only render/input. | Library; confirmed at engine setup |
| **No `DataStoreService` / ProfileStore dependency** | All Crafting state is purely runtime (per C.4) — no persistence across sessions. ProfileStore is used for cosmetics only, not Crafting state. | Verified by C.4 + C.10 |

### F.6 — Bidirectional Back-Reference Audit

Audit performed 2026-04-30 against the GDDs that exist at this round. Items requiring reverse-citation in OTHER GDDs:

| Other GDD | Current state | Required update | Owner | Priority |
|---|---|---|---|---|
| `design/gdd/player-controller.md` F.2 | Lists `RequestInteract(targetId)` placeholder for Crafting interaction surface | Replace with the 8 named events from this GDD's C.15 (see F.4 row). Optionally also add a row for the bench-OPEN commit RemoteEvent once C.3.2 names it. | Player Controller GDD author | Coordinated update after Crafting locks |
| `design/gdd/ecological-disturbance.md` F.2 (Crafting & Items row) | States "(partially TBD) ... Crafting & Items GDD owns Beacon trigger conditions + magnitude (TBD pending Crafting GDD)" | Update to reflect: (a) trigger conditions resolved in Crafting C.5 + C.9 (placement + activation lifecycle); (b) `MAGNITUDE_BEACON = 0.95` confirmed at default; (c) new `Craft` emission type added to ED's reserved enum (1 of 4 slots consumed); (d) midpulse trigger at `CRAFT_BEACON_MIDPULSE_TIME = 5 s` from craft start per D.7. | Ecological Disturbance GDD author | Phase 5 registry update + ED next revision |
| `design/gdd/ecological-disturbance.md` F.3 | States "Crafting & Items GDD must declare: 'Publishes Beacon emission with reserved magnitude range [0.85, 1.0] per ED.C.3.6'" | **Satisfied by F.3 of this GDD** — no update required to ED. ✓ |
| `design/gdd/ecological-disturbance.md` F.3a | Author checklist template | **Satisfied by F.3 of this GDD** — no update required to ED. ✓ |

GDDs not yet authored (Resource Node, Resource Management, HUD, Predator AI) will inherit the contracts in F.2 and F.4 above; their authors must reverse-cite this GDD's relevant sections when those GDDs are written.

### F.7 — Out-of-Scope (NOT dependencies of this system)

These systems do NOT interact with Crafting & Items, by design:

- **Roblox `DataStoreService` / ProfileStore** — Crafting state is purely runtime; no persistence (per C.4). ProfileStore is used for cosmetics only.
- **Roblox `PathfindingService`** — Predator AI uses pathfinding to reach the Beacon, but Crafting publishes no pathfinding hints. Crafting's interface to PA is purely via the disturbance field.
- **Audio system** (post-MVP) — bench / craft / beacon SFX will be authored when the Audio system is added; no current Crafting → Audio contract. Crafting may emit Knit signals on craft events that the Audio system can subscribe to passively, with no Crafting-side change required.
- **Multiplayer matchmaking** — Crafting operates within a single RunSession; matchmaking is upstream and out of scope.

## Tuning Knobs

All knobs are **server-authoritative** and live in a single config module (consumed by Knit `CraftingService`). Categories: **Feel** (player-perceived responsiveness), **Curve** (drives a formula or progression shape), **Gate** (rate-limit / cap / threshold). Knobs flagged "**ED-locked**" or "**PC-locked**" are owned by the Ecological Disturbance / Player Controller registries and **MUST NOT** be redefined here — listed only to surface their relevance.

### G.1 — Bench Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `BENCH_MAX_CRAFTERS` (ceiling) | 2 | 2–4 | Gate | C.3.5, C.8 | n/a — this is the **ceiling** on the squad-scaled effective cap `benchMaxCraftersEffective = min(BENCH_MAX_CRAFTERS, ceil(squadSize/2))` (round-2). Below 2 would force every squad to cap 1 and remove multi-crafting entirely | At 3+, the completion-emission stack (D.3) breaches ED's reserved-band logic — three independent emissions at the same position can saturate the bench-position fieldValue; cap dwell-reduction value also flattens (1/3 vs 1/2 returns). **Round-2: do not raise — the cap now scales with squad size; raising the ceiling re-opens the round-1 reserved-band concern.** Effective cap is 1 for 2-player squads (fixes the "nobody watches" collision), 2 for 3–4-player squads |
| `CRAFT_JOIN_CUTOFF` | 0.85 | 0.50–0.95 | Gate | C.3.5, C.8, E.3 | At 0.50, late-joiners get half the dwell window for full emission attribution — joining becomes a cheap way to halve craft cost | At 0.95, joiners can enter the final 5% of a craft and pay full per-crafter emission for trivial contribution — the deserter-exploit (E.5) reopens |
| `BENCH_RANGE_TOLERANCE` | 2 studs | 1–4 | Feel | C.8, E.13 | At 1, network position jitter creates false out-of-range cancellations on stable players | At 4+, players can sprint freely around the bench without losing craft progress — breaks the "stay at the bench" affordance |

### G.2 — Inventory Caps

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `MATERIAL_STACK_MAX` | 20 | 10–50 | Gate | C.4 | At 10, every other gather forces a bench round-trip — pacing collapses to material-shuttle | At 50+, the "drop-at-bench-before-gathering" tension disappears; one player can hoard all squad materials |
| `SQUAD_INVENTORY_TYPE_CAP` | 8 | 5–12 | Gate | C.4 | Below 5, squad cannot hold one of each crafted item simultaneously (5 distinct types exist in MVP) | Above 12, no practical effect — only 5 distinct item types exist in MVP (round-2 cut) |
| `ITEM_STACK_MAX` | 10 | 3–25 | Gate | C.4 | At 3, hoarding consumables breaks down; squad runs out mid-Hunt-tier with no resupply path | At 25+, late-game runs accumulate item piles that flatten Pillar 4's "rounds not saves" pacing |

### G.3 — Recipe Cost & Craft-Time Knobs

The 5 recipes' material costs and craft times are **structural** — adjusting any single recipe shifts the squad's gather budget for the whole run. Tune as a set, not individually.

| Recipe | Material cost (B/M/R) | Craft time | Cost-time category | Notes |
|---|---|---|---|---|
| Oxygen Canister | 2/0/0 | 2 s | Curve | Cheapest aid; baseline disturbance-vs-survival exchange. Reducing time below 1.5 s makes the burst feel ungated; raising above 4 s undermines its "quick triage" role |
| Dampener Coil | 0/2/1 | 5 s | Curve | Time-limited 50% Light reduction (D.6). 1 RESONANT cost is the "expensive but stackable" floor |
| Signal Anchor | 1/1/1 | 5 s | Curve | Balanced cost — touches all three materials. Single-shot sensor (C.7); cost reflects coordination value, not raw power |
| Squad Relay | 2/2/1 | 6 s | Curve | Highest non-Beacon cost. Reflects squad-scope effect (transfer + position broadcast) |
| Escape Beacon | 2/3/3 | 10 s | Curve | **Win condition** — total 8 gathers across squad. RESONANT-heavy. Craft time chosen so a 2-crafter run completes in 5 s (D.2) — the longest bench-dwell decision in the game |

**Coupled tuning note**: shortening any non-Beacon craft time below 1.5 s collapses the multi-crafter dwell-reduction differentiation (D.2) — at very short dwells, N=1 vs N=2 is sub-second. The Beacon's 10 s craft time is the most-tunable single value in this section: at 6 s, N=2 dwell drops to 3 s and the bench-as-exposure beat (Section B) feels rushed; at 15 s, the squad's defensive window during the craft becomes the longest commitment in the game.

### G.4 — Recipe Burst Magnitude Knobs (Craft emission family)

Five magnitudes drive the disturbance burst published at `BT3` (per D.3) and the Beacon midpulse (per D.7). All are emitted via `DisturbanceService:Emit("Craft", position, magnitude, sourcePlayerId)` — the new `Craft` enum slot consumes 1 of ED's 4 reserved emission types. *(Round-2: `MAGNITUDE_CRAFT_LIGHT = 0.12` was retired with the Composite Patch + Quiet Step Wrap cut — it was the only tier those two recipes used; no surviving recipe sits in the LIGHT band.)*

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `MAGNITUDE_CRAFT_XS` | 0.10 | 0.05–0.18 | Curve | C.2 (Oxygen Canister) | At 0.05, oxygen canister becomes "free" — Pillar 1 weakens for the most-frequently-crafted item | At 0.18, lapses toward MID tier — the "cheap craft" tier collapses |
| `MAGNITUDE_CRAFT_MID` | 0.18 | 0.12–0.30 | Curve | C.2 (Coil + Anchor) | At 0.12, MID tier collapses toward XS — recipe tier differentiation weakens | At 0.30, MID approaches HEAVY — Coil/Anchor crafts become predator-magnets |
| `MAGNITUDE_CRAFT_RELAY` | 0.20 | 0.15–0.32 | Curve | C.2 (Squad Relay) | At 0.15, RELAY collapses into MID — the "squad-coordination scope" justification erodes | At 0.32, lapses into HEAVY — Relay becomes nearly as loud as Beacon completion |
| `MAGNITUDE_CRAFT_HEAVY` | 0.35 | 0.25–0.55 | Curve | C.2 (Beacon completion) | At 0.25, the Beacon's pre-activation craft burst feels indistinguishable from MID-tier — the win-condition's "loudest pre-activation craft" framing collapses | At 0.55, the completion burst contributes ≥0.50 to bench-position fieldValue at zero distance, pushing the bench into Hunt-tier on completion alone |
| `MAGNITUDE_CRAFT_BEACON_MIDPULSE` | 0.18 | 0.10–0.35 | Curve | C.2, D.7 (Beacon midpulse) | At 0.10, the midpulse fades below "warning" perceptibility — the squad doesn't hear the halftime beat | At 0.35, equals HEAVY — squad effectively gets two completion bursts during the craft, which double-fires the predator-investigation event at the bench |

**Coupled tuning note**: the magnitude tier ratios (XS:MID:RELAY:HEAVY ≈ 1 : 1.8 : 2 : 3.5) encode the "every craft is a noise bargain" framing from Section B. Adjusting any one magnitude in isolation breaks the squad's mental model of which recipes are "loud." Tune the family proportionally.

**`MAGNITUDE_CRAFT_BEACON_MIDPULSE` is intentionally a separate constant from `MAGNITUDE_CRAFT_MID`** even though they share value (0.18) at default. The midpulse and the Beacon completion have different acoustic functions: the midpulse is a warning beat, the completion is the loudest pre-activation event. A future tuning pass may want to diverge them (e.g., midpulse 0.15, MID 0.20) without consequence — keep them split.

### G.5 — Aid Item Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `DAMPENER_DURATION` | 60 s | 20–180 | Curve | C.6, D.6 | At 20 s, the Coil's window barely covers two Light-pulse intervals — feels worthless given the 5-s craft cost | At 180 s, the Coil persists across multiple Hunt-tier transitions; effectively permanent silent-lantern for that player |
| `DAMPENER_REDUCTION` | 0.50 | 0.30–0.70 | Curve | C.6, D.6 | At 0.30, the Coil's perceived effect feels marginal (0.08 → 0.056 — a thin slice) | At 0.70, stationary Coil-equipped players fall below `MAGNITUDE_FLOOR = 0.02` and become silently invisible to the disturbance field — Pillar 1 weakens |
| `SIGNAL_ANCHOR_LIFETIME` | 45 s | 15–120 | Curve | C.6, C.7, E.16 | At 15 s, the Anchor expires before the squad can reposition to react to its trip event | At 120 s, the Anchor becomes a near-permanent perimeter sensor — approaches base-building behaviour (game-concept anti-pillar). The single-Anchor-at-a-time rule (E.16) mitigates this; lifetime is the secondary brake |
| `SIGNAL_ANCHOR_DETECTION_RADIUS` | 30 studs | 12–60 | Gate | C.7 | At 12, the predator can pass within 15 studs of the Anchor undetected — Anchor feels broken | At 60+, the Anchor covers ~2.5× INFLUENCE_RADIUS and becomes a "predator-tracking minimap" — over-powers the squad's spatial awareness loop |
| `SENSOR_CHECK_HZ` | 5 Hz | 2–10 | Gate | C.7 | At 2 Hz, fast predator transits past the Anchor can slip between samples (an accepted false-negative per systems-designer review) | At 10 Hz, doubled server CPU cost for marginal accuracy improvement |

### G.6 — Beacon Lifecycle Knobs

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `CRAFT_BEACON_MIDPULSE_PROGRESS` | 0.5 | 0.4–0.6 | Feel | D.7 | Below 0.4, the midpulse fires too early — feels like a "craft started" cue, not a halftime warning | Above 0.6, midpulse and completion cluster too tightly — the halftime-beat cadence collapses |
| `BEACON_PLACE_MAX_RANGE` | 8 studs | 4–16 | Gate | C.15 | At 4, players cannot place the Beacon at the most strategic plinth corner of a safe room — placement feels overconstrained | At 16, players can place the Beacon while sprinting past the plinth — "ritual placement" framing breaks |
| `BEACON_SURVIVAL_WINDOW` (derived) | ≈ 49 s | derived (≈ 35–70 s effective range) | Curve | C.5.6a, C.9 | Below ~35 s the survival window is too short to demand aid — squad can just bunker through it, and the round-1 Beacon-rush dominance partially returns | Above ~70 s the window outlasts the predator's peak-threat commit (the beacon has decayed below Hunt-floor) and becomes a dead waiting period; also risks oxygen-starvation feeling unfair |

The wall-clock value `CRAFT_BEACON_MIDPULSE_TIME = 5 s` is a **derived** value at default tunings (`CRAFT_BEACON_MIDPULSE_PROGRESS × CRAFT_BASE_DWELL_TIME = 0.5 × 10 s`), not an independently tunable knob. The progress fraction is the registered tunable; the seconds value follows from it.

`BEACON_SURVIVAL_WINDOW ≈ 49 s` is likewise a **derived** value, **owned by Ecological Disturbance** (the interval the Beacon holds at or above `HUNT_THRESHOLD = 0.65`, computed from ED's `MAGNITUDE_BEACON = 0.95`, `BEACON_HALF_LIFE = 90 s`, and `HUNT_THRESHOLD`). This GDD does **not** redefine it — it reads the value from ED's beacon worked example (ED.D.7). If ED retunes any of those three constants, the survival window length follows automatically. Tuning the window means tuning ED's beacon decay, not adding a Crafting-side constant. *(OQ — playtest, owner game-designer: confirm ~49 s produces the intended "loud finale" tension at 2–4 players; if it needs to diverge from the ED-derived value, that becomes a decision about decoupling Crafting's victory timer from ED's decay — surface to creative-director.)*

### G.7 — Rate Limit Knobs

All RemoteEvent rate limits are server-enforced per the C.15 trust boundary. The per-event limits gate individual flows; the global limit caps cycle-between-events bypass attempts.

| Knob | Default | Range | Category | Section | Too Low | Too High |
|---|---|---|---|---|---|---|
| `RequestCraft_RATE` | 1/s/player sustained; burst 3 per 3 s | (0.5–2)/s | Gate | C.15 | At 0.5/s, legitimate retry-after-rejection patterns (insufficient-materials race) get throttled | At 2/s+, rapid-fire craft spam approaches global-limit; logging volume increases. Burst ceiling (3/3 s) ≥ sustained rate (1/s) so a same-second retry is permitted (round-2 B12 fix — round-1 'burst 2/3 s' was *below* the 1/s sustained rate, a self-contradiction that throttled legitimate retries) |
| `RequestUseItem_RATE` | 1/s/player sustained; burst 3 per 3 s | (0.5–3)/s | Gate | C.15 | At 0.5/s, a legitimate back-to-back Oxygen Canister sequence during Hunt-tier flight gets throttled | At 3/s+, exploit surface widens for buffered rapid-equip-then-use chains. C.15 sets the canonical value; this knob's tuning range is narrower than other rate limits because item-use is intentionally a deliberate action. Burst ceiling ≥ sustained rate (round-2 B12) so retry-after-rejection is not falsely throttled |
| `RequestPlaceItem_RATE` | 1/(5 s)/player | (3–15) s | Gate | C.15 | At 3 s, players can spam Anchor placements during Hunt-tier (single-Anchor rule limits damage but still increases server load) | At 15 s, players cannot place a second Anchor in a Hunt-tier emergency — Anchor utility diminishes |
| `RequestPlaceBeacon_RATE` | 1/(5 s)/player | (3–10) s | Gate | C.15 | At 3 s, ritual placement is not gated against fat-finger re-fires | At 10 s, legitimate retry after `invalid-placement` rejection feels punishing |
| `CRAFTING_GLOBAL_RATE_LIMIT` | 8 events/s/player | 4–16 | Gate | C.15 | At 4, legitimate squad with 4 simultaneous bench actions hits the cap | At 16, the global cap stops gating — falls back to per-event limits only, which the game-concept tech risk identifies as bypassable |

### G.8 — Reused Constants (NOT redefined here)

These constants are owned by other GDDs and referenced from this system. **Do NOT redefine them in `CraftingService` — read from the source of truth.**

| Constant | Owner | Value (default) | Used in this GDD |
|---|---|---|---|
| `GATHER_PROXIMITY_RADIUS` | PC (`design/gdd/player-controller.md`) | 4 studs | Bench proximity gate (C.3.1), beacon-activate range (C.5), relay-activate range (C.6) |
| `TAP_HOLD_COMMIT_DURATION` | PC | 0.5 s | Reserved for future crafting tap-hold flows (none in MVP) |
| `FIELD_UPDATE_HZ` | ED | 5 Hz | Bench proximity watcher cadence (E.13) |
| `MAGNITUDE_FLOOR` | ED | 0.02 | Coil floor edge case + canonical order-of-operations floor discard (D.6, D.6a) |
| `STATIONARY_EMISSION_FACTOR` | ED | 0.30 | Coil non-linear threshold (D.6); Stage 2 of the canonical order-of-operations (D.6a) |
| `INFLUENCE_RADIUS` | ED | 24 studs | Cap-scope clarification (E.17) |
| `HOTSPOT_DEDUP_GRID_SIZE` | ED | 4 studs | Multi-crafter attribution (E.18) |
| `MAGNITUDE_BEACON` | ED | 0.95 | Beacon activation emission (C.5, C.9) |
| `BEACON_HALF_LIFE` | ED | 90 s | Beacon Hunt-floor lure window (C.9) |
| `BEACON_STATIONARY_*` family | ED | (varies) | Cap-scope clarification (E.17) |
| `MAGNITUDE_GATHER_LIGHT/MEDIUM/HEAVY` | ED | 0.15 / 0.25 / 0.40 | Material-tier ↔ gather-magnitude alignment (C.1); RN owns the gather emission (no Crafting-side modifier post-round-2) |

## Visual/Audio Requirements

This section specifies the visual and audio language for all 25 distinct Crafting moments (numbered 1–27; Moments 16 + 17 retired in the round-2 catalog cut, Moments 26 + 27 added for the round-2 survival window — net 25 live moments). Authored 2026-04-30 by `art-director` consult, anchored to `design/art/art-bible.md` Sections 1, 2.4, 2.7, 3.3, 4.2, 4.3, 4.5, 4.8, 7.3, 7.4. The crafting visual vocabulary is intentionally consolidated into 6 effect families (see VA.4) so the implementation surface is much smaller than 25 separate effects suggest.

### VA.1 — Craft Tier Intensity Vocabulary

All burst-at-completion moments (and the Beacon midpulse) reference this tier table. The four tiers correspond 1:1 to the `MAGNITUDE_CRAFT_*` family in G.4 (the LIGHT tier was retired with the round-2 Composite Patch + Quiet Step Wrap cut — no surviving recipe sits in the LIGHT band).

| Tier | Magnitude | Particles (PC / mobile) | PointLight Brightness | Flash duration | Range |
|---|---|---|---|---|---|
| **XS** | 0.10 | 8 / 4 | 1.5 | 120 ms | 2 studs |
| **MID** | 0.18 | 18 / 9 | 2.8 | 200 ms | 5 studs |
| **RELAY** | 0.20 | 22 / 11 | 3.0 | 220 ms | 6 studs |
| **HEAVY** | 0.35 | 40 / 20 | 5.0 | 350 ms | 8 studs |

All burst PointLights use **cool-white** `Color3.fromRGB(200, 210, 230)` (gap-resolution G-A1, matching wrist lantern — "same light source" vocabulary). Particles are spherical Neon-material Parts spawned at the bench center, traveling outward 1–2 studs, fading over 200–400 ms. Mobile-safe via Neon Part + PointLight Tween (no GPU particle instancing required). No burst PointLight persists beyond its flash duration.

Tool events (Anchor trip + Relay activation) use **teal-white** `Color3.fromRGB(95, 255, 216)` instead of cool-white, distinguishing "tool event" from "craft event" vocabulary.

### VA.2 — Locked design-gap resolutions

| Gap | Resolution | Source |
|---|---|---|
| **G-A1** Craft burst color | Cool-white `Color3.fromRGB(200, 210, 230)`. Reuses wrist lantern color; consistent with art-bible Principles 1 + 3. | locked 2026-04-30 |
| **G-A2** Bench idle appearance | `SmoothPlastic`, color Equipment Slate `#2E3138`, **no emissive at rest** (BS1 state). | locked 2026-04-30 (level-design phase confirms) |
| **G-A3** Bench/craft/aid SFX family | Mechanical-mineral-organic blend; distinct from predator's purely biological signature. | locked 2026-04-30 (Audio system ADR will detail) |
| **G-A5** Dampener Coil world-space cue | Subtle Billboard icon on Coil-equipped player visible to squadmates, consistent with art-bible §5.3 "key resource carrier" pattern. | locked 2026-04-30 (HUD GDD obligation) |
| **G-A4** Anchor + Relay BasePart visual identity | **Deferred to `/asset-spec`** — see VA.6 follow-up #5/#6. | deferred 2026-04-30 |

### VA.3 — Per-Moment Specifications

The 25 live moments (numbered 1–27; 16 + 17 retired round-2, 26 + 27 added round-2). Cosmetic-boundary clearance applies to ALL: every cue is either HUD-non-skinnable or rendered on a scripted, non-skinnable child Part of the relevant BasePart. Cross-platform: all cues work on touch / mouse / gamepad (no hover-only states).

| # | Moment | Visual | Audio | HUD |
|---|---|---|---|---|
| 1 | Bench-Armed | None at bench (avoids decorating lit-pool boundary per Principle 1) | Soft 2D proximity chime, < 200 ms, mid-range (1–2 kHz) | Interaction prompt fade-in 0.15s `Cubic/Out`; rectangular UIStroke 1px `#F0F0F0`, fill `#1A1E2B` @ 60% |
| 2 | Bench-Open | None at bench | UI panel-open click, < 150 ms, 2D, mechanical-crisp | Recipe-list panel Tween-in 0.15 s; 5 rows always visible (unaffordable rows dimmed per H.2) |
| 3 | Recipe-Selection | Selected row UIStroke thickens 1px → 2px over 0.05 s | Selection tick < 80 ms 2D for browse; recipe-commit click ~150 ms with resonance | Per-row highlight on focus; commit closes panel 0.10s `Cubic/In` |
| 4 | Craft-In-Progress | **Bench ambient leak**: PointLight at bench center, Brightness oscillates 0.2 → 0.6 → 0.2 (period 2.0s), Color `(180, 195, 220)`, Range 2 studs only | Low-amplitude continuous hum 200–400 Hz; spatial 3D rolloff 8–12 studs; periodic harmonic shift matches PointLight period; cuts immediately on cancel | Crafter HUD: 48px progress ring, UIGradient cool-white, lerps to server progress at 5 Hz. Squadmates: 24px version with squad-color crafter dots + bench chevron icon |
| 5 | Multi-Crafter Join | None at bench | Warm 2D "second hand joins" tone ~200 ms, broadcast to all squad | Squad-color second crafter dot added to progress indicator over 0.10s; joining crafter's UI shows "JOIN CRAFT" with recipe pre-selected at current progress |
| 6 | Craft-Complete | Burst per VA.1 tier table at bench center; tier matches recipe's `MAGNITUDE_CRAFT_*` constant | 3D spatial completion sound at bench, ~200–400 ms (longer for higher tier); rolloff 12–25 studs | "RECIPE COMPLETE" GothamMedium 16px alert for crafter, 0.6s; squad inventory icon flash for new item |
| 7 | Craft-Cancel | Bench ambient leak (Moment 4) cuts immediately; no burst | 3D spatial "abort" cue, ~150 ms; player-initiated cancel = neutral tone; system-cancel (insufficient-materials / out-of-range / death) = sharper warning tone | Progress ring fades to 0 over 0.20s; alert text varies by reason (`OnCraftCancelled.reason` enum drives text label) |
| 8 | Craft-Rejected | None at bench (rejection happens at UI-side before BS1→BS2) | 2D rejection click ~100 ms, distinctly negative tone | Reason text shown below recipe row, GothamMedium 14px, fades over 1.5s; reason enum from C.15 |
| 9 | Beacon Midpulse | **Variant** of burst family at MID tier (18/9 particles) but with **upward column direction** instead of radial — visually telegraphs "halftime warning" distinctly from a completion burst | 3D spatial "halftime beat" tone, ~250 ms, deeper register than completion sound; rolloff 15 studs | Brief "BEACON MIDPULSE" alert text for crafters only, GothamMedium 14px, 0.4s |
| 10 | Beacon-Crafted (BT3 for Beacon recipe) | Burst at HEAVY tier per VA.1 (40/20 particles, PointLight Brightness 5.0, 350 ms, Range 8 studs); cool-white | 3D spatial completion sound at bench, ~500 ms, deepest register of any craft sound; rolloff 25 studs | Squad-wide "ESCAPE BEACON CRAFTED" GothamBold 20px alert, 0.08s in / 0.5s out; squad inventory shows Beacon icon |
| 11 | Beacon-Placement (BCT2) | Placement ring (Family 2) at Beacon position, larger diameter (~1.5 studs); Beacon BasePart spawns with no emissive at this state | 3D spatial placement sound, ~400 ms, ceremonial register; rolloff 25 studs | Squad-wide "BEACON PLACED" alert + squad-wide waypoint chevron pointing at Beacon position (per art-bible §7.6) |
| 12 | Beacon-Pre-Activation (idle BC3) | Beacon BasePart has subtle white pulse: PointLight Brightness 0.4 → 0.8 → 0.4, period 3.0 s, Color `(220, 225, 235)`, Range 4 studs — slow-recognizable "this is the win condition" pulse | Quiet spatial drone at Beacon, very low amplitude (below ambient stem), period matches PointLight pulse; rolloff 20 studs | Persistent waypoint chevron for all squad |
| 13 | Beacon-Activation (BCT3) | **Crafting fires `Emit(0.95)` only** — the visual response is delegated: art-bible §2.7's "single vertical PointLight column — pure white, full brightness — overrides all bioluminescent pulse and collapses FogEnd to near-zero" is owned by the **environment/lighting system** as a response to `OnBeaconActivated`. Flora response is owned by ED's flora subsystem | **Audio system contract**: ambient stem cuts; Hunt stem rises (per Section B). Crafting does not own the audio mix transition — formalized in Audio system ADR | Activation is the **window-START** beat (round-2), NOT victory: HUD opens the survival-window countdown (Moment 26); PC enters its "surviving the window" state but does NOT fire T8 here — victory is Moment 27 at window-end |
| 14 | Beacon-Decay (BCT5 natural — defensive fallback) | Beacon BasePart emissive fades over 1.0 s; BasePart removed | 3D spatial decline cue, ~600 ms, rolloff 25 studs | "BEACON DECAYED" GothamMedium 16px alert + waypoint marker fade. **Normally unreachable** (run ends at window-end ~49 s, ~10× before decay) — **NOT fired on run-end cleanup or window resolution** (per E.8 / E.26) |
| 15 | Dampener Coil Equip | Coil wrist pulse: PointLight at HumanoidRootPart, Brightness 1.2, ~200 ms, pale-blue `(180, 200, 230)` | 2D equip click ~120 ms, Coil-distinct timbre | HUD badge appears for the equipped Coil, 32px outlined icon, persistent until expire |
| 16, 17 | *RETIRED (round-2)* — were "Composite Patch consumes (D.4)" + "Quiet Step Wrap consumes (D.5)"; both recipes cut in C.2. Numbers retired (not reused). | — | — | The Coil — the only remaining equippable — equips at Moment 15 and expires at Moment 19 |
| 18 | Dampener Coil active state (D.6) | **Billboard icon on Coil-equipped player** visible to squadmates (gap-resolution G-A5): 24px outlined Coil icon, faint cool-blue, persistent for `DAMPENER_DURATION = 60 s` window | Coil-modified Light pulses use a softer SFX variant — Audio system contract | Coil HUD badge persistent with countdown ring (60s timer); badge color shifts pale-blue → orange in final 10 s |
| 19 | Dampener Coil expiry | Billboard icon fade over 0.5 s | Quiet 2D "effect ended" tone ~150 ms | "COIL EXPIRED" alert text varies by reason: `expired` (60s timer) / `bench-visit` (G6) / `death` |
| 20 | Anchor Placement | Placement ring at Anchor position, 0.5 stud diameter, transient 1.0 s; Anchor BasePart spawns with persistent Neon emitter, teal-white `(95, 255, 216)`, slow period 3.0 s | 3D spatial placement sound, ~150 ms, rolloff 12 studs | Squad-wide waypoint chevron pointing at Anchor position; "ANCHOR PLACED" alert for placing player only |
| 21 | Anchor active idle (during 45s lifetime) | Persistent slow Neon pulse on Anchor BasePart per Moment 20 | Continuous very-low-amplitude drone at Anchor position; rolloff 8 studs | Persistent waypoint chevron for all squad |
| 22 | Anchor Trip (single-shot) | Anchor Neon emitter flash → extinguish (Anchor is spent). Quick teal-white burst at Anchor position, 12/6 particles | Sharp 2D broadcast tone heard by ALL squad ~200 ms; 3D spatial event at Anchor position too | Squad-wide screen-edge chevron in teal-white pointing at Anchor position; GothamBold 20px "ANCHOR TRIPPED" alert 0.08s in / 0.5s out |
| 23 | Anchor Expiry (3 reasons) | **Lifetime / Replaced**: Anchor element fade over 0.5 s + BasePart removed. **Tripped** (after Moment 22): BasePart fades Transparency 0 → 1 over 1.0 s + removed | Lifetime/Replaced: quiet 3D spatial tone ~100 ms. Tripped: silent (Moment 22 was the sonic event) | Waypoint marker fades; reason-distinct text per `OnSignalAnchorExpired.reason` enum |
| 24 | Relay Placement | Placement ring at Relay position, 0.8 stud diameter, transient 1.0 s; Relay BasePart spawns with persistent Neon indicator, neutral cool-dark `(180, 195, 220)`, slower period 4.0 s | 3D spatial placement sound, ~200 ms, rolloff 15 studs | Squad-wide waypoint chevron in cool-white (squad-scope); "RELAY PLACED" alert for placing player |
| 25 | Relay Activation | Burst at RELAY tier per VA.1 (22/11 particles, PointLight 3.0 / 220 ms) at Relay position, **teal-white** `(95, 255, 216)`; Relay BasePart fades Transparency 0 → 1 over 0.5 s + removed (single-use) | 3D spatial activation burst at Relay ~300 ms; **2D squad-broadcast tone** heard by ALL alive squad regardless of distance (Pillar 2 squad-coordination signal) | Squad-wide screen-edge chevron pointing at Relay position; "RELAY ACTIVATED" GothamBold 20px alert; squad waypoint marker disappears |
| 26 | Beacon Survival-Window Countdown (BC4, round-2) | The Beacon BasePart holds the activation-state white column (owned by environment/lighting per Moment 13) for the window's duration; no new Crafting-owned world effect — the visual fallback is the HUD countdown (so the window read is never audio-only) | **Audio system contract**: the Hunt stem sustains at floor for the window; the squad hears the predator commit. No new Crafting-owned SFX | Squad-wide **survival-window countdown** opened by `OnBeaconActivated` / `OnEscapeBeaconActivated`: a `BEACON_SURVIVAL_WINDOW ≈ 49 s` ring/timer for all squad members, draining to zero at window-end. This is the visual fallback resolving the round-1 "Moment 13 audio-only" gap — the countdown is on-screen text/ring, not just an audio cue |
| 27 | Beacon Window Survived → Victory (BCT4, round-2) | Victory beat is delegated: the environment/lighting + HUD victory sequence (art-bible §4.4 "Victory") fires on `OnBeaconWindowSurvived` at window-end — this is the beat that was previously (pre-round-2) tied to activation | **Audio system contract**: victory stem / resolution cue on window-survival; ambient returns. Crafting does not own the mix | Squad-wide **victory** sequence; PC owns the T8 transition (now driven by `OnBeaconWindowSurvived`, not activation); HUD owns the victory screen. Fires once per run (guarded by `RunSession.beaconWindowSurvived`) |

### VA.4 — Consolidation Families (effect re-use)

The 25 moments compose from 6 implementable effect families:

| Family | Implementation | Used by moments |
|---|---|---|
| **F1 — Craft Burst** | `craftBurst(tier, position, color)` — cool-white default, teal-white for tool events | 6, 9 (variant: upward column), 10, 25 |
| **F2 — Placement Ring** | `placementRing(diameter, position, color)` | 11 (Beacon), 20 (Anchor), 24 (Relay) |
| **F3 — Item Equip Pulse** | `equipPulse(item, player)` — per-item color + duration parameters | 15 (Coil) |
| **F4 — Waypoint Chevron** | Reuses art-bible §7.6 screen-edge marker system; color parameter distinguishes player ping (white) from tool event (teal-white) | 11, 20, 22, 24, 25 |
| **F5 — Expiry Fade** | `expireFade(element, duration, removeAfter)` | 14 (Beacon), 19 (Coil), 23 (Anchor) |
| **F6 — HUD Alert Text** | Reuses art-bible §7.3 alert sequence; `craftAlert(text, style)` parameter on existing alert system | 5, 6, 7, 8, 10, 11, 13, 22, 25, 27 |

*(Round-2 note: Moment 26 — the survival-window countdown — is a HUD timer/ring surface, not an alert-text or burst family; it reuses the art-bible §7.6 waypoint-marker + a countdown ring rather than a new effect family. Moment 27's victory beat reuses F6 for its alert + the HUD/art-bible §4.4 victory sequence.)*

### VA.5 — Audio System Contracts (forward obligations)

These are not implemented in this GDD — they are obligations on the Audio system / Audio GDD when authored:

1. **`OnBeaconActivated` audio mix transition**: ambient stem cuts; Hunt stem rises at window-start (Section B obligation). The Hunt stem sustains for the `BEACON_SURVIVAL_WINDOW`, then resolves to a victory/return cue on `OnBeaconWindowSurvived` (round-2 — Moment 27) or is cut by the defeat path on a full-squad wipe (BCT-DEFEAT). Audio ADR will formalize the crossfade contract.
2. **Coil-modified Light pulse SFX variant**: softer Light sound when `EquippedEffects[playerId].dampenerCoil` is active. *(Round-2: the former Wrap-modified Sprint-pulse SFX variant was removed with the Quiet Step Wrap cut.)*
3. **Per-recipe completion SFX scaling**: each tier (XS / MID / RELAY / HEAVY) has a distinct sound family — players learn "loud vs. quiet" through both visual and audio.
4. **Bench ambient leak hum** (Moment 4): the spatial 3D loop with periodic harmonic shift matching the PointLight pulse.
5. **2D squad-broadcast tones** (Moments 5 join, 13 activation, 22 anchor trip, 25 relay activation): non-spatial tones heard by all alive squad members regardless of distance.

### VA.6 — Asset Spec Hooks (`/asset-spec` follow-up)

After the art bible is finalized, run `/asset-spec system:crafting-and-items` to generate per-asset visual specifications. Specific asset categories required:

1. **Bench BasePart hero asset** — material, color, form factor, no-emissive-at-rest constraint per G-A2
2. **Bench progress ring** — confirm HUD-anchored UIGradient (recommended) vs. world-space Neon ring
3. **Beacon BasePart hero asset** — silhouette read at predator-encounter distance per art-bible §2.7 column commitment
4. **Signal Anchor BasePart asset** — sensor read (not weapon/creature), teal-white emitter position
5. **Squad Relay BasePart asset** — visually distinct from Anchor, squad-link iconography
6. **Per-item HUD badge icons** — `ui_icon_coil_32`, `ui_icon_anchor_32`, `ui_icon_relay_32`, `ui_icon_beacon_objective_32` (32px canvas, 2px outline, no fill, art-bible §7.2 vocabulary). *(Round-2: `ui_icon_patch_32` + `ui_icon_wrap_32` dropped with the Composite Patch + Quiet Step Wrap cut.)*
7. **Audio SFX asset specifications** — full sound asset specs deferred to Audio GDD authoring; this section names the design contracts
8. **Beacon activation white column + FogEnd** — environment/lighting system implementation; technical-artist confirms 80-stud PointLight vs. Neon Part geometry; iPhone SE mobile-downgrade variant needs profiling
9. **Audio stem crossfade contracts** — formalized in Audio ADR once Audio GDD is started
10. **Cosmetic asset checklist** — review-time gate verifying dual-clause compliance per H.67–H.72

> **📌 Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:crafting-and-items` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

This section catalogs the player-facing UI surfaces this system contributes. Visual treatment is locked in Visual/Audio (VA.1–VA.6); this section names the surfaces, their data bindings, and their interaction patterns. Detailed flow design (recipe-selection screen wireframe, multi-crafter join visualization, accessibility patterns) is deferred to `/ux-design crafting-bench` per the UX flag at UI.5.

### UI.1 — Surface Inventory

| # | Surface | Type | Visible to | Source moments | Data binding |
|---|---|---|---|---|---|
| 1 | **Bench Recipe Panel** | Modal panel (per-player) | Bench-Open through commit | VA.3 Moments 2–3, 5 | 5-row recipe list (round-2 cut); per-row affordability computed from squad combined personal pool; multi-crafter join state pre-selects active recipe |
| 2 | **Crafting Progress Ring (crafter)** | HUD overlay (own player) | BS2/BS3 active for this player | VA.3 Moment 4 | 48px UIGradient ring; lerps to server `craftProgress` at 5 Hz cadence (per H.61) |
| 3 | **Crafting Progress Ring (squadmate)** | HUD overlay (squad) | BS2/BS3 active for any squad member | VA.3 Moments 4–5 | 24px UIGradient ring with bench-icon + crafter squad-color dots |
| 4 | **Equipped-Effect Badge** | Persistent HUD icon | Per-player (own equipment) | VA.3 Moments 15, 18, 19 | Coil 32px outlined icon (the only equippable post-round-2); includes 60s countdown ring + final-10s color shift pale-blue → orange |
| 5 | **Coil Billboard Indicator** | Worldspace Billboard (squad-visible) | Coil-equipped player visible to squadmates | VA.3 Moment 18, gap-resolution G-A5 | 24px outlined Coil icon faint cool-blue; persistent for `DAMPENER_DURATION` window |
| 6 | **Personal Inventory Readout** | Persistent HUD panel (own) | Always | (consumed by HUD GDD) | BIOMASS / MINERAL / RESONANT counts; updates on `OnInventoryChanged(scope="personal")` |
| 7 | **Squad Inventory Readout** | Persistent HUD panel (squad) | Always | (consumed by HUD GDD) | Per-item-type counts (Oxygen Canister / Coil / Anchor / Relay / Beacon — 5 types post-round-2); updates on `OnInventoryChanged(scope="squad")` |
| 8 | **Beacon Waypoint Chevron** | Screen-edge marker (squad-wide) | After BCT2; persists through BC4 / RunEnded | VA.3 Moments 11, 12 | Chevron points at `RunSession.beaconWorldPosition`; uses art-bible §7.6 marker system |
| 9 | **Anchor Waypoint Chevron** | Screen-edge marker (squad-wide) | While Anchor live | VA.3 Moments 20, 21 | Chevron points at Anchor BasePart position; teal-white color variant |
| 10 | **Relay Waypoint Chevron** | Screen-edge marker (squad-wide) | While Relay live (placed but not activated) | VA.3 Moment 24 | Chevron points at Relay position; cool-white color (squad-scope) |
| 11 | **Alert Text Overlay** | Transient HUD banner | Squad-wide for major events; per-player for minor | VA.3 Moments 5, 6, 7, 8, 10, 11, 13, 14, 19, 22, 25, 27 | Reuses art-bible §7.3 alert sequence; `craftAlert(text, style)` with GothamBold 20px (urgent) / GothamMedium 16px (info) / GothamMedium 14px (subtle) |
| 12 | **Rejection Feedback** | Inline below recipe row | Per-player; bench panel must be open | VA.3 Moment 8 | Reason text from `OnCraftRejected.reason` enum; GothamMedium 14px; fades over 1.5s |
| 13 | **Beacon Survival-Window Countdown** | Persistent HUD timer/ring (squad-wide) | Round-2 | From `OnBeaconActivated` (BCT3) to window-end | VA.3 Moment 26 | `BEACON_SURVIVAL_WINDOW ≈ 49 s` countdown ring/timer for all squad members; opened by `OnBeaconActivated`/`OnEscapeBeaconActivated`, cleared at window-end (victory, Moment 27) or full-wipe defeat. The on-screen visual fallback that resolves the round-1 "Moment 13 audio-only" gap |

### UI.2 — Interaction Patterns

| Surface | Touch (mobile) | Mouse (PC) | Gamepad |
|---|---|---|---|
| Bench Recipe Panel: navigation | Tap row to highlight | Click row to highlight | D-pad up/down or stick |
| Bench Recipe Panel: commit | **Two-tap pattern** (tap to highlight, tap again to commit — prevents accidental commits) | Single click on selected row OR Enter | A / X button |
| Bench Recipe Panel: cancel | Tap close button (44pt minimum target) OR back swipe | Esc key OR click outside panel | B / Circle button |
| Bench Recipe Panel: scroll (5 rows post-round-2 — fits iPhone SE without scroll in most layouts; `ScrollingFrame` retained as a safety net) | Vertical scroll via `ScrollingFrame` | Mouse wheel | Right stick or D-pad |
| Item equip / use (HUD badge) | Tap badge | Number key (1–6) bound per item | Bumper + face button |
| Item place (Anchor / Relay / Beacon) | Tap-hold targeting cursor at desired position | Click at position | Stick-aimed reticle + commit |
| Beacon activation (proximity-gated) | Single tap on activation prompt | Single click OR E key | A / X button |
| Anchor / Relay placement at active aim point | Tap to confirm placement | Click to confirm | A / X button |

**No hover-only states**: every interactive surface has an explicit press / tap / button press. Tap-hold confirm radial arcs (per art-bible §7.7) appear on touch only — not on PC / gamepad — to avoid wait-on-input mismatch.

### UI.3 — Data Binding Contracts (Crafting → HUD)

The client-bound RemoteSignals declared at C.14 / C.15 drive these surfaces (round-2 added `OnBeaconActivated` window-start + `OnBeaconWindowSurvived` victory). HUD GDD MUST consume each:

| Signal (from C.14) | Drives surface(s) | Update cadence |
|---|---|---|
| `OnBenchArmed(benchId)` | Interaction prompt (Moment 1) | Event-driven |
| `OnBenchDisarmed(benchId)` | Interaction prompt fade-out | Event-driven |
| `OnCraftStarted(benchId, recipeId, crafters[])` | Progress ring init; bench panel close | Event-driven |
| `OnCraftProgress(benchId, progress)` | Progress ring lerp target | ≤ 5 Hz (per H.61) |
| `OnCraftCompleted(benchId, recipeId)` | Burst feedback; alert text; squad inventory icon flash | Event-driven |
| `OnCraftCancelled(benchId, recipeId, reason)` | Progress ring fade-out; reason-distinct alert text | Event-driven |
| `OnCraftRejected(reason)` | Rejection feedback inline | Event-driven |
| `OnInventoryChanged(scope, delta)` | Personal/squad inventory readouts (surfaces 6, 7) | Event-driven |
| `OnEquippedEffectExpired(playerId, itemId, reason)` | Equipped-effect badge fade; reason-distinct alert text | Event-driven |
| `OnSignalAnchorTripped(anchorId, predatorPosition)` | Squad-wide directional indicator + alert text | Event-driven |
| `OnSignalAnchorExpired(anchorId, reason)` | Anchor waypoint marker fade; reason-distinct text | Event-driven |
| `OnBeaconPlaced(position, playerId)` | Beacon waypoint chevron creation; alert text | Event-driven |
| `OnBeaconActivated(position, activatorPlayerId, timestamp)` | Activation cue (Moment 13) + opens the survival-window countdown (surface 13, Moment 26) — round-2 | Event-driven |
| `OnBeaconWindowSurvived(timestamp)` | Victory sequence (Moment 27); clears the survival-window countdown — round-2 | Event-driven |
| `OnBeaconDecayed(beaconId)` | Beacon waypoint marker fade (NOT fired on run-end per E.8, nor on window resolution per E.26) | Event-driven |

### UI.4 — Cross-Platform Requirements

- **Lowest-tier mobile target**: iPhone SE-class (375pt screen). All touch targets minimum 44pt. The 5-row recipe panel (round-2 cut from 7) fits the iPhone SE viewport without scrolling in the default layout — directly relieving the round-1 "iPhone SE panel scrolling extends bench dwell" pillar-collision finding; the `ScrollingFrame` is retained only as a safety net for accessibility text-scaling.
- **HUD safe area**: respect device notches and home-indicator zones on iOS/Android.
- **Gamepad rumble**: short pulse (100 ms, low intensity) on activating player's gamepad only for personal-confirmation moments (craft commit, beacon activate, relay activate) — not for squad-broadcast events. Mobile: no haptic beyond tap.
- **Colorblind safety**: HUD alerts use both color and text label (e.g., "ANCHOR TRIPPED" GothamBold 20px label backs the teal-white directional indicator). Squad-color crafter dots use shape variants in addition to color (per art-bible accessibility section if present).
- **Audio fallback**: 2D squad-broadcast tones (Moments 5, 13, 22, 25) work on all platforms with no positional spatial-audio fallback required.

### UI.5 — UX Flag for `/ux-design`

> **📌 UX Flag — Crafting & Items**: This system has UI requirements covering bench recipe panel flow (5 rows post-round-2), multi-crafter join state visualization, equipped-effect badge layout (Coil only post-round-2), the Beacon survival-window countdown surface, and inventory readout density (squad pool with up to 5 distinct item types). In Phase 4 (Pre-Production), run `/ux-design crafting-bench` to create a UX spec for the bench recipe panel BEFORE writing epics. Stories that reference UI should cite `design/ux/crafting-bench.md`, not this section directly.
>
> Specifically, the following flows need detailed UX specification before implementation:
> 1. **Bench recipe panel** — recipe-selection flow with affordability + multi-crafter join state (5 rows)
> 2. **Equipped-effect badge** — the single Coil badge with its 60 s countdown ring + final-10s color shift (round-2: no longer a simultaneous-multi-effect layout problem)
> 3. **Squad inventory readout** — readability with 5 distinct item types in tight HUD real estate
> 4. **Beacon activation prompt + survival-window countdown** — clarity that activation is a single-action commit (no confirm dialog) given its run-opening consequence — must read as "ritual placement" not "accidental tap"; and the survival-window countdown must read clearly as "survive this, then you win" (round-2: activation opens the window, victory is at window-end)
> 5. **Multi-crafter join visualization** — the "JOIN CRAFT" prompt + recipe pre-selected state when joining mid-craft
>
> Update the systems index for Crafting & Items to flag this UX dependency.

## Acceptance Criteria

This section enumerates 73 live acceptance criteria (numbered through H.80; 7 retired in the round-2 cut — H.18/H.19/H.20/H.34/H.35/H.36/H.59 — and 8 added — H.73–H.80) validating Sections C, D, E, and F. Each AC is independently testable by a QA tester without reading the GDD. Format: GIVEN / WHEN / THEN + Test type (Logic / Integration / Visual-Feel / UI / Config-Data) + Source citation. **[P0]** marks BLOCKING (sprint-exit gate); unmarked entries are P1 (milestone gate); **[P2]** marks advisory. 85% of these ACs are tractable for automated testing per qa-lead review (2026-04-30); the 15% requiring playtest are noted in Test type.

### H.1–H.26 — Core Rule ACs (per C.1–C.15)

**H.1 — Material count cap enforced on gather**
- **GIVEN** a player's `PersonalInventory.biomass = 20` (at `MATERIAL_STACK_MAX`)
- **WHEN** `OnGatherCompleted(playerId, "BIOMASS", 1)` fires from Resource Node
- **THEN** `PersonalInventory.biomass` remains 20; the incoming delta is silently discarded; no `OnInventoryChanged` fires for that player
- **Test type**: Logic
- **Source**: C.4, G.2

**H.2 [P2] — Recipe listing: unaffordable recipes remain visible but dimmed**
- **GIVEN** a player opens the bench UI and the squad's combined personal pool cannot afford the Dampener Coil (requires 2 MINERAL, 1 RESONANT)
- **WHEN** the bench UI renders the recipe list
- **THEN** the Dampener Coil row is present in the list AND visually marked dimmed (not hidden or removed); all 5 recipes are always listed
- **Test type**: UI
- **Source**: C.3.3

**H.3 [P0] — BT1 fires only when player is alive and within range**
- **GIVEN** a player in PC.S4 (Dead-Respawning) fires `RequestCraft("OxygenCanister")` from any position
- **WHEN** the server validates the request
- **THEN** the server rejects with `OnCraftRejected(reason="not-alive")` and no `CraftSession` is created
- **Test type**: Logic
- **Source**: C.3.4, C.15, E.20

**H.4 [P0] — BT1 proximity gate: rejection beyond bench range**
- **GIVEN** a player is at a server-tracked distance of `GATHER_PROXIMITY_RADIUS + 2 studs = 6 studs` from the bench
- **WHEN** the player fires `RequestCraft("OxygenCanister")`
- **THEN** the server rejects with `OnCraftRejected(reason="out-of-range")` and no `CraftSession` is created
- **Test type**: Logic
- **Source**: C.3.1, C.15

**H.5 — Bench state machine: BS1 → BS2 → BS3 on valid join**
- **GIVEN** bench is in BS2 with `craftProgress = 0.50` and a second player within range fires `RequestCraft` for the same recipe
- **WHEN** the server validates the join (progress < `CRAFT_JOIN_CUTOFF = 0.85`; bench has room)
- **THEN** bench transitions to BS3; `CraftSession.crafters` array has length 2; `OnBenchOccupancyChanged(benchId, 2)` fires to all squad clients
- **Test type**: Logic
- **Source**: C.3.5, C.8 BT2

**H.6 — BT2 join cutoff: strict less-than at 0.85**
- **GIVEN** bench is in BS2 with `craftProgress = 0.85` exactly
- **WHEN** a second player fires `RequestCraft` for the same recipe
- **THEN** the server rejects with `OnCraftRejected(reason="too-late-to-join")`; bench remains in BS2
- **Test type**: Logic
- **Source**: C.3.5, C.8, E.3

**H.7 [P0] — BT3 atomic material deduction and item grant**
- **GIVEN** bench in BS2 with `craftProgress` about to reach 1.0; squad has exactly the required materials for Oxygen Canister (2 BIOMASS, in the crafting player's personal inventory)
- **WHEN** `craftProgress >= 1.0` on a Heartbeat tick
- **THEN** in a single atomic operation: (1) 2 BIOMASS deducted from personal inventory; (2) one Oxygen Canister added to `SquadInventory`; (3) `DisturbanceService:Emit("Craft", benchPosition, 0.10, crafterId)` called; (4) `OnCraftCompleted` fires to squad; (5) `CraftSession` cleared; (6) bench returns to BS1 — all within the same server Heartbeat
- **Test type**: Logic
- **Source**: C.3.6, C.8 BT3, D.3

**H.8 [P0] — BT5: no partial credit on full cancel**
- **GIVEN** bench in BS2 with `craftProgress = 0.70`
- **WHEN** the sole crafter fires `RequestCraftCancel`
- **THEN** `craftProgress` is discarded (reset to 0.0 internally; `CraftSession` cleared); no materials are deducted; no item is added; no `DisturbanceService:Emit` is called; `OnCraftCancelled(benchId, recipeId, reason="player-initiated")` fires to squad
- **Test type**: Logic
- **Source**: C.3.7, C.8 BT5

**H.9 [P0] — Dead player inventory lock: not cleared, not poolable**
- **GIVEN** a player dies (PC.T5 fires) while holding BIOMASS=5, MINERAL=3, RESONANT=2 in their `PersonalInventory`
- **WHEN** a concurrent BT3 on a different bench attempts to deduct materials from the alive-squad combined pool
- **THEN** the dead player's personal inventory values are excluded from the combined-pool calculation; `PersonalInventory` for the dead player remains {5, 3, 2} throughout the death state
- **Test type**: Logic
- **Source**: C.3.6, C.7, E.7

**H.10 — Inventory unlocks on respawn**
- **GIVEN** a player in PC.S4 has BIOMASS=5 locked in `PersonalInventory`
- **WHEN** PC fires the respawn event (S4 → S1 transition)
- **THEN** `PersonalInventory[playerId]` is readable again by BT1 combined-pool checks; `OnInventoryChanged` fires to the returning client with the correct material counts
- **Test type**: Integration
- **Source**: C.3.6, C.10, E.7

**H.11 [P0] — Beacon once-per-run guard at BT1**
- **GIVEN** `RunSession.beaconCrafted = true` (Beacon already exists in some lifecycle state)
- **WHEN** any player fires `RequestCraft("EscapeBeacon")`
- **THEN** server rejects with `OnCraftRejected(reason="beacon-already-crafted")`; no CraftSession created; `RunSession.beaconCrafted` remains true
- **Test type**: Logic
- **Source**: C.3.4, C.5.1, E.10

**H.12 [P0] — Beacon lifecycle BCT1: flags set atomically at craft completion**
- **GIVEN** the Escape Beacon recipe reaches `craftProgress >= 1.0`
- **WHEN** BT3 fires for the Beacon recipe
- **THEN** atomically: `RunSession.beaconCrafted = true`; `SquadInventory` contains exactly one Beacon item (`count=1`); `RunSession.beaconPlaced` is still `false`; bench returns to BS1
- **Test type**: Logic
- **Source**: C.5.1, C.9 BCT1

**H.13 [P0] — BCT2: beacon placed, removed from inventory, placement flags set**
- **GIVEN** Beacon is in BC2 (`SquadInventory.Beacon.count = 1`); an alive player within `BEACON_PLACE_MAX_RANGE = 8 studs` fires `RequestBeaconPlace(position)` with a valid position
- **WHEN** the server validates and processes the request
- **THEN** `SquadInventory.Beacon.count = 0`; a Beacon BasePart exists in workspace at the validated position; `RunSession.beaconPlaced = true`; `RunSession.beaconWorldPosition` equals the validated position; `OnBeaconPlaced(position, playerId)` fires to all squad
- **Test type**: Logic
- **Source**: C.5.2, C.9 BCT2

**H.14 [P0] — BCT3: activation fires emission with placer attribution**
- **GIVEN** Beacon is in BC3; an alive player (not the original placer) within `GATHER_PROXIMITY_RADIUS = 4 studs` fires `RequestBeaconActivate`
- **WHEN** the server validates (alive; `beaconActivated == false`; within range)
- **THEN** `DisturbanceService:Emit("Beacon", RunSession.beaconWorldPosition, 0.95, RunSession.beaconPlacerId)` is called — `sourcePlayerId` is the PLACER's UserId, NOT the activator's; `RunSession.beaconActivated = true`; `OnEscapeBeaconActivated(activatorPlayerId, timestamp)` fires to squad; `OnBeaconActivated` fires to squad
- **Test type**: Logic
- **Source**: C.5.4, C.9 BCT3

**H.15 [P0] — BCT3 fires the window-START signal, NOT victory (round-2)**
- **GIVEN** Beacon is in BC3
- **WHEN** BCT3 fires (activation succeeds)
- **THEN** `OnEscapeBeaconActivated(activatorPlayerId, timestamp)` fires exactly once per RunSession on the squad channel as the survival-window **start** cue; the survival-window timer starts; `RunSession.beaconActivated = true`. **`OnBeaconWindowSurvived` does NOT fire here, and Player Controller MUST NOT fire T8 on `OnEscapeBeaconActivated`** — victory is verified separately at window-end by H.73. This AC verifies the signal fires with correct payload AND that no victory transition is triggered at activation.
- **Test type**: Integration
- **Source**: C.5.6, C.5.6a, C.9 BCT3, C.12.1, F.2
- *(Round-2: pre-patch this AC asserted "BCT3 also fires PC's T8 victory signal" — the root of the round-1 Beacon-dominance finding. Victory now fires at BCT4; see H.73.)*

**H.16 — BCT5: beacon BasePart removed on natural decay only; run-end uses distinct path**
- **GIVEN** Beacon is in BC3 and `RunEnded` fires (squad wipe, no activation)
- **WHEN** the run-end cleanup path executes
- **THEN** the Beacon BasePart is removed from workspace WITHOUT firing `OnBeaconDecayed`; `OnBeaconDecayed` remains unfired for this run (the decay transition is now BCT5, a defensive fallback normally unreachable per E.26)
- **Test type**: Logic
- **Source**: C.5.7, C.9, E.8
- *(Round-2 renumber: decay was BCT4 pre-patch; it is now BCT5 — the BCT4 slot is the new window-survival victory transition.)*

**H.17 — Dampener Coil: bench-visit terminates effect**
- **GIVEN** a player has an active Dampener Coil (`EquippedEffects[playerId].dampenerCoil` is non-nil, with `expiresAt` 30 seconds in the future)
- **WHEN** the player enters `GATHER_PROXIMITY_RADIUS = 4 studs` of any bench (`OnBenchArmed` fires per gap-resolution G6)
- **THEN** `EquippedEffects[playerId].dampenerCoil` is cleared; `OnEquippedEffectExpired(playerId, "DampenerCoil", reason="bench-visit")` fires; the Coil item is NOT returned to `SquadInventory` (it was consumed on equip)
- **Test type**: Logic
- **Source**: C.6, D.6, G6 gap-resolution

**H.18, H.19, H.20 — *REMOVED (round-2, 2026-06-01)*** — all three tested cut recipes: H.18 was Composite Patch equip-replace, H.19 was Quiet Step Wrap consume-on-first-sprint-pulse (D.5), H.20 was Quiet Step Wrap death-return. With both recipes cut from the catalog (C.2), these ACs have no referent. Numbers retired (not reused). The surviving Dampener Coil's equip/expiry/death behaviour is covered by H.17 (bench-visit expiry), H.37 (Light-pulse reduction), and H.55 (death cleanup).

**H.21 — Signal Anchor: single-shot trip, no re-trigger**
- **GIVEN** a Signal Anchor is live and its first predator-proximity trip has already fired (`tripped = true`)
- **WHEN** the predator moves within `SIGNAL_ANCHOR_DETECTION_RADIUS = 30 studs` of the Anchor a second time during the same Anchor's lifetime
- **THEN** no second `OnSignalAnchorTripped` fires; the Anchor continues its lifetime timer normally
- **Test type**: Logic
- **Source**: C.7.4

**H.22 — Signal Anchor does not publish disturbance on placement or during lifetime**
- **GIVEN** a Signal Anchor is placed and lives its full `SIGNAL_ANCHOR_LIFETIME = 45 s`
- **WHEN** the lifetime elapses
- **THEN** `DisturbanceService:Emit` has NOT been called by the Anchor at any point during its lifetime; `OnSignalAnchorExpired(anchorId, reason="lifetime")` fires
- **Test type**: Logic
- **Source**: C.7, C.2 recipe 5

**H.23 — Squad Relay: consumed on activation, not on placement**
- **GIVEN** a Squad Relay is placed in the world (item deducted from `SquadInventory` at placement)
- **WHEN** no player activates it and `RunEnded` fires
- **THEN** the relay was fully consumed at placement; no relay item returns to `SquadInventory`; `ActiveDeployables.squadRelay` is cleared on run-end
- **Test type**: Logic
- **Source**: C.6

**H.24 [P0] — No client-callable RemoteFunction on crafting service**
- **GIVEN** the Knit `CraftingService.Client` surface is introspected at service startup
- **WHEN** the client surface is enumerated
- **THEN** zero `RemoteFunction` members are present; all client-facing members are `RemoteSignal` (one-way fire-and-forget) only
- **Test type**: Logic
- **Source**: C.11.4, ED.F.4

**H.25 [P0] — Rate limit: excess RequestCraft calls silently dropped after burst**
- **GIVEN** a player sends `RequestCraft` at a rate exceeding 2 per 3 s (burst exhausted)
- **WHEN** the 3rd request within 3 s is processed
- **THEN** the excess request is silently dropped server-side; no `OnCraftRejected` is fired to the client for the excess; server logs the first excess per player per second
- **Test type**: Logic
- **Source**: C.15, E.23, G.7

**H.26 [P0] — Global rate limit: cycle-between-events bypass blocked**
- **GIVEN** a player sends 9 distinct Crafting RemoteEvents within 1 s (any combination from the C.15 event list)
- **WHEN** the 9th event is processed
- **THEN** the global per-player ceiling `CRAFTING_GLOBAL_RATE_LIMIT = 8 events/s/player` gates it; the 9th is dropped; no downstream handler is invoked for the 9th event
- **Test type**: Logic
- **Source**: C.15, G.7

### H.27–H.41 — Formula ACs (per D.1–D.7)

**H.27 — D.1: craft progress accumulates correctly at N=1 (Oxygen Canister)**
- **GIVEN** bench in BS2 with a single crafter and recipe `OxygenCanister` (craft time 2 s); `craftProgress = 0.0` at tick start; server running at 60 Hz (dt = 1/60 s)
- **WHEN** one Heartbeat fires
- **THEN** `craftProgress ≈ 0.00833` (= 1/120, i.e. `1.0 / 2.0 × 1/60`) ± 0.0002
- **Test type**: Logic
- **Source**: D.1

**H.28 — D.1: craft progress accumulates correctly at N=1 (Escape Beacon)**
- **GIVEN** bench in BS2, single crafter, recipe `EscapeBeacon` (craft time 10 s), `craftProgress = 0.0`
- **WHEN** 600 Heartbeat ticks fire at 60 Hz (10 s elapsed)
- **THEN** `craftProgress >= 1.0` and BT3 has fired exactly once; total wall-clock elapsed ≈ 10.0 s ± 0.1 s
- **Test type**: Logic
- **Source**: D.1

**H.29 [P0] — D.1: progress clamped at 1.0, does not overflow**
- **GIVEN** `craftProgress = 0.9999` on a Heartbeat where `craftRate × dt` would push it to 1.0017
- **WHEN** the accumulator runs
- **THEN** `craftProgress` is clamped to exactly 1.0 (not 1.0017); BT3 fires; no second BT3 fires on the subsequent tick
- **Test type**: Logic
- **Source**: D.1

**H.30 — D.2: N=2 halves effective dwell time**
- **GIVEN** bench in BS3 with 2 crafters on Escape Beacon (10 s base dwell); `craftProgress = 0.0`
- **WHEN** 300 Heartbeat ticks fire at 60 Hz (5 s elapsed)
- **THEN** `craftProgress >= 1.0` and BT3 has fired; total elapsed ≈ 5.0 s ± 0.1 s (half of solo 10 s)
- **Test type**: Logic
- **Source**: D.2

**H.31 — D.2: progress preserved when N changes mid-craft**
- **GIVEN** bench in BS2 with `craftProgress = 0.50` (5 s elapsed at N=1 on a 10 s Beacon)
- **WHEN** a second crafter joins (BT2) and 150 more Heartbeat ticks fire (2.5 s at N=2)
- **THEN** `craftProgress >= 1.0` at approximately 7.5 s total elapsed; BT3 fires; the surviving progress from before the join was not discarded
- **Test type**: Logic
- **Source**: D.2

**H.32 [P0] — D.3: two independent Emit calls fire at N=2 completion**
- **GIVEN** bench in BS3 with crafters A and B completing Escape Beacon (`craftProgress` reaches 1.0)
- **WHEN** BT3 fires
- **THEN** `DisturbanceService:Emit` is called exactly twice — once with `sourcePlayerId = A.UserId`, once with `sourcePlayerId = B.UserId` — both at `benchPosition`, both with `initialMagnitude = MAGNITUDE_CRAFT_HEAVY = 0.35`; the two calls are independent (not merged)
- **Test type**: Logic
- **Source**: D.3, C.11.1

**H.33 — D.3: N=2 bench-position field does not breach reserved band**
- **GIVEN** two crafters complete Escape Beacon simultaneously (D.3 fires two Emit calls at 0.35 each)
- **WHEN** `fieldValue(benchPosition)` is queried immediately after both Emit calls
- **THEN** `fieldValue <= 1.0` (clamped) AND no individual emission had `initialMagnitude > 0.85` (reserved-band constraint per ED.C.1.2); the two 0.35 emissions are independently below 0.85
- **Test type**: Logic
- **Source**: D.3, C.11.5

**H.34, H.35, H.36 — *REMOVED (round-2, 2026-06-01)*** — all three tested cut-recipe formulas: H.34 + H.35 tested the Composite Patch gather-magnitude downgrade (D.4, Heavy→Medium and the Light floor case), H.36 tested the Quiet Step Wrap sprint-pulse reduction (D.5). D.4 and D.5 are themselves removed (round-2 stubs); these ACs have no referent. Numbers retired (not reused). The only surviving emission modifier — the Dampener Coil — is tested by H.37 (Light-pulse reduction) and H.38 (the canonical Coil × stationary order-of-operations floor-discard, D.6a).

**H.37 — D.6: Dampener Coil reduces Light pulse to 0.04 for 60 s**
- **GIVEN** a player equips Dampener Coil at server time T; 5 Light pulse emissions fire at T+4, T+8, T+12, T+16, T+20 (each at 4 s intervals per `LIGHT_PULSE_INTERVAL`)
- **WHEN** each emission fires during the Coil's active window (`DAMPENER_DURATION = 60 s`)
- **THEN** each of the 5 calls to `DisturbanceService:Emit` carries `initialMagnitude = 0.08 × 0.50 = 0.04`; the Coil is NOT consumed per pulse; at T+60 the Coil expires and the next pulse fires at 0.08
- **Test type**: Logic
- **Source**: D.6

**H.38 [P2] — D.6: stationary Coil-equipped player's effective pulse falls below MAGNITUDE_FLOOR**
- **GIVEN** a player equips Dampener Coil and is stationary (`movement_delta < EMITTER_MOVEMENT_DELTA_FLOOR`)
- **WHEN** a Light pulse fires (Coil applies 0.50 reduction to nominal magnitude; PC.D.4 then applies `STATIONARY_EMISSION_FACTOR = 0.30`)
- **THEN** the chained reduction yields `0.08 × 0.50 × 0.30 = 0.012`, which is below `MAGNITUDE_FLOOR = 0.02`; ED's schema validation discards the emission; `DisturbanceService:Emit` is NOT called; the Coil is NOT consumed for this pulse
- **Test type**: Logic
- **Source**: D.6, ED zero-magnitude rejection

**H.39 — D.7: Beacon mid-craft pulse fires exactly once per craft session**
- **GIVEN** a Beacon craft is in progress at N=1 with `craftProgress` advancing from 0 to 1.0
- **WHEN** `craftProgress` first crosses `CRAFT_BEACON_MIDPULSE_PROGRESS = 0.5`
- **THEN** `DisturbanceService:Emit("Craft", benchPosition, MAGNITUDE_CRAFT_BEACON_MIDPULSE=0.18, crafters[1])` fires exactly once; `CraftSession.midpulseFired = true`; subsequent ticks do not re-fire the midpulse in the same session
- **Test type**: Logic
- **Source**: D.7

**H.40 — D.7: midpulse does not fire if Beacon craft cancelled before threshold**
- **GIVEN** a Beacon craft is in progress and `craftProgress = 0.40` (below `CRAFT_BEACON_MIDPULSE_PROGRESS = 0.5`)
- **WHEN** the crafter fires `RequestCraftCancel` (BT5 fires)
- **THEN** `DisturbanceService:Emit` has NOT been called for the midpulse at any point during this session; `CraftSession.midpulseFired` was never set to `true` before clearing
- **Test type**: Logic
- **Source**: D.7

**H.41 — D.7: N=2 midpulse wall-clock at ~2.5 s with primary-crafter attribution**
- **GIVEN** Beacon craft starts at N=2 (two crafters already joined at BT1/BT2)
- **WHEN** server time advances 2.5 s (at 60 Hz: 150 ticks)
- **THEN** `craftProgress ≈ 0.50` and the midpulse has already fired (`midpulseFired = true`) within the preceding 1 tick window; the midpulse uses `sourcePlayerId = CraftSession.primaryCrafterId` (the stable BT1-initiator field — round-2 B7; NOT `crafters[1]`, which can shift if the initiator departs via BT4, and NOT crafters[2])
- **Test type**: Logic
- **Source**: D.7

### H.42–H.55 — Edge Case ACs (8 P0 + selected P1 from E)

**H.42 [P0] — E.6: mid-craft material race: BT6 fires, no partial deduction**
- **GIVEN** bench in BS2 crafting Dampener Coil (requires 2 MINERAL, 1 RESONANT); at BT1 the combined pool had sufficient materials; a concurrent BT3 on another bench deducts those materials before this bench reaches completion
- **WHEN** this bench's `craftProgress >= 1.0` and BT3's atomic deduction is attempted
- **THEN** the deduction fails; BT6 fires: no materials deducted, no item added to `SquadInventory`, no `DisturbanceService:Emit` called; `OnCraftCancelled(benchId, recipeId, reason="insufficient-materials")` fires to squad; bench returns to BS1
- **Test type**: Logic
- **Source**: C.3.6, C.8 BT6, E.6

**H.43 [P0] — E.7: solo crafter dies; inventory locked, not wiped**
- **GIVEN** player P is the sole crafter in BS2 with all Beacon materials (BIOMASS=2, MINERAL=3, RESONANT=3) in personal inventory; `craftProgress = 0.70`
- **WHEN** `Humanoid.Died` fires for player P
- **THEN** BT5 fires (session cleared, progress discarded); `PersonalInventory[P]` values remain {2, 3, 3} (not cleared); a concurrent `RequestCraft` from another bench's BT3 combined-pool check CANNOT include P's locked inventory; `PersonalInventory[P]` becomes accessible again only after PC's respawn event fires
- **Test type**: Logic
- **Source**: C.3.6, C.7, E.7

**H.44 [P0] — E.9: activator dies on same Heartbeat as activation; activation still succeeds (round-2)**
- **GIVEN** a player fires `RequestBeaconActivate` and `Humanoid.Died` fires for that player on the same Heartbeat; the activate request is processed first (Luau single-threaded ordering); at least one other squad member remains alive
- **WHEN** BCT3 validates (alive check passes; `beaconActivated == false`)
- **THEN** BCT3 fires atomically: `RunSession.beaconActivated = true`; `DisturbanceService:Emit("Beacon", beaconWorldPosition, 0.95, beaconPlacerId)` called; `OnEscapeBeaconActivated` fires (window-start); the player's subsequent death does NOT rollback the activation and does NOT end the run. **The survival window opens; victory is NOT awarded at activation** — it is awarded only if ≥1 squad member is alive at window-end (BCT4, H.73). The activator's death merely removes one survivor from the window; the run continues. *(Round-2: pre-patch this AC asserted "the run ends in victory" at activation — corrected to window-survival semantics.)*
- **Test type**: Logic
- **Source**: C.9, E.9, C.5.6a

**H.45 [P0] — E.12: both crafters die simultaneously; no zombie CraftSession**
- **GIVEN** bench in BS3 with crafters A and B; both `Humanoid.Died` events fire on the same Heartbeat
- **WHEN** the death handlers process sequentially (Luau scheduler orders A first, then B)
- **THEN** A's handler fires BT4 (bench → BS2 with B still in crafters, but B is also dead); B's handler detects `crafters` array would be empty after removal and fires BT5 instead of BT4; `CraftSession` is cleared; no emission; bench is in BS1 with no orphaned session
- **Test type**: Logic
- **Source**: C.8, E.12

**H.46 [P0] — E.13: server-side proximity watcher cancels craft on range violation**
- **GIVEN** a player is in BS2 crafting and walks to `GATHER_PROXIMITY_RADIUS + 2 studs = 6 studs` from the bench WITHOUT sending `RequestCraftCancel`
- **WHEN** the server-side proximity watcher fires at its `FIELD_UPDATE_HZ = 5` cadence
- **THEN** within 0.2 s of the range violation, the watcher fires BT5: `CraftSession` cleared, progress discarded, no emission, `OnCraftCancelled(benchId, recipeId, reason="out-of-range")` fires to squad; the check is server-authoritative (client-reported position is NOT used for this determination)
- **Test type**: Logic
- **Source**: C.8, E.13, G.5

**H.47 [P0] — E.20: item-use before BT3 fires; rejected**
- **GIVEN** a player fires `RequestUseItem("OxygenCanister")` before the server's BT3 has added the item to `SquadInventory`
- **WHEN** the server processes the request
- **THEN** `SquadInventory["OxygenCanister"].count = 0` check fails; request rejected with `OnCraftRejected(reason="item-unavailable")`; no oxygen pulse is fired; `DisturbanceService` is not called
- **Test type**: Logic
- **Source**: C.6, C.15, E.20

**H.48 [P0] — E.21: inventory inflation attack rejected at schema level**
- **GIVEN** a malicious client fires `RequestCraft("EscapeBeacon")` when the server's `PersonalInventory[playerId]` has RESONANT=0 (below the 3 needed)
- **WHEN** BT1 validation reads the server-authoritative inventory
- **THEN** the combined-pool check fails (RESONANT is 0 on server); request rejected with `OnCraftRejected(reason="insufficient-materials")`; the `RequestCraft` payload contains only `recipeId` — no material-count field is present for the client to manipulate
- **Test type**: Logic
- **Source**: C.15, E.21

**H.49 [P0] — E.22: false victory via RequestBeaconActivate before placement**
- **GIVEN** `RunSession.beaconPlaced = false` (Beacon not yet placed)
- **WHEN** a player fires `RequestBeaconActivate`
- **THEN** BCT3 pre-validation checks `beaconPlaced == true` and fails; request rejected with `OnBeaconRejected(reason="beacon-not-placed")`; no `DisturbanceService:Emit` called; no `OnEscapeBeaconActivated` fires; `RunSession.beaconActivated` remains `false`
- **Test type**: Logic
- **Source**: C.15, E.22

**H.50 — E.5: deserter exploit closed; emission at BT3 uses current crafters array**
- **GIVEN** bench in BS3 with `craftProgress = 0.90`; crafter[1] fires `RequestCraftCancel`
- **WHEN** BT4 removes crafter[1] and crafter[2] later reaches BT3
- **THEN** D.3 iterates `CraftSession.crafters` at the moment of BT3, which contains only crafter[2]; exactly one `DisturbanceService:Emit` fires (attributed to crafter[2]); crafter[1] receives no attribution
- **Test type**: Logic
- **Source**: C.8, D.3, E.5

**H.51 — E.16: second Signal Anchor placement cancels first**
- **GIVEN** a live Signal Anchor is deployed (within its `SIGNAL_ANCHOR_LIFETIME = 45 s`); a player places a second Signal Anchor
- **WHEN** the server validates the second placement request
- **THEN** the first Anchor's BasePart is removed; `OnSignalAnchorExpired(firstAnchorId, reason="replaced")` fires to squad; the second Anchor BasePart spawns; `ActiveDeployables.signalAnchor` points to the second Anchor; only one Signal Anchor exists in the world
- **Test type**: Logic
- **Source**: C.6, C.10, E.16

**H.52 — E.17: bench Craft emission independent of Beacon position cap**
- **GIVEN** Beacon is in BC4 (active); ED's stationary-squad cap is engaged at the Beacon position; a Signal Anchor craft completes at a bench more than `INFLUENCE_RADIUS = 24 studs` from the Beacon
- **WHEN** BT3 fires and `DisturbanceService:Emit("Craft", benchPosition, 0.18, crafterId)` is called
- **THEN** the Beacon-position cap does NOT suppress or reduce the bench's Craft emission; `fieldValue(benchPosition)` reflects the bench's own emissions independently; the cap only affects `fieldValue(beaconPosition)`
- **Test type**: Integration
- **Source**: E.17, ED.C.3.6

**H.53 — E.18: N=2 emissions at same position: two independent sources in ED live-source list**
- **GIVEN** D.3 fires two Emit calls at BT3 (same `benchPosition`, same `initialMagnitude`, different `sourcePlayerId`)
- **WHEN** ED processes both emissions
- **THEN** two distinct source entries exist in the live-source list with distinct `emissionId`s; they do NOT merge into one entry; both decay independently; `sourcePlayerId` is distinct for each entry
- **Test type**: Integration
- **Source**: D.3, E.18, ED.C.1.5

**H.54 [P0] — Once-per-run flags never reset within a RunSession**
- **GIVEN** `RunSession.beaconCrafted` has been set to `true` at BCT1
- **WHEN** any server-side code path is executed before `RunEnded` fires (including beacon placement, activation, or decay)
- **THEN** `RunSession.beaconCrafted` remains `true`; similarly `RunSession.beaconPlaced` remains `true` after BCT2 and `RunSession.beaconActivated` remains `true` after BCT3; none of these flags are ever set back to `false` within the same RunSession
- **Test type**: Logic
- **Source**: C.5.1, C.9, E.10

**H.55 [P0] — Equipped effect death cleanup: same-Heartbeat atomicity (round-2: Coil-only)**
- **GIVEN** a player with an active Dampener Coil (the only equippable post-round-2) dies (PC.T5 fires)
- **WHEN** `Humanoid.Died` is processed on the server
- **THEN** on the SAME Heartbeat as the death event: `EquippedEffects[playerId].dampenerCoil` is cleared; `OnEquippedEffectExpired(playerId, "DampenerCoil", reason="death")` fires; the Coil is NOT returned to SquadInventory (it was consumed on equip — E.1); no pending input from that tick can read a stale equipped-state for the dead player
- **Test type**: Logic
- **Source**: C.10, C.6, E.1, G2 gap-resolution
- *(Round-2: pre-patch this AC also covered a Composite Patch death-return path; with the Patch cut, only the Coil's consume-on-equip semantic remains.)*

### H.56–H.62 — Cross-System Contract ACs (per F.1–F.4)

**H.56 [P0] — F.1/F.2: OnEscapeBeaconActivated fires exactly once per RunSession**
- **GIVEN** BCT3 fires (beacon activated)
- **WHEN** `OnEscapeBeaconActivated(activatorPlayerId, timestamp)` is fired
- **THEN** the signal fires to the squad channel exactly once; if BCT3 is somehow invoked a second time (defended against by `beaconActivated` guard), `OnEscapeBeaconActivated` does NOT fire a second time within the same RunSession
- **Test type**: Logic
- **Source**: C.5.6, C.9 BCT3, C.12.1, F.2

**H.57 — F.2: RequestInteract routing to correct Crafting handler**
- **GIVEN** Player Controller fires `RequestInteract(targetId)` where `targetId` resolves to a crafting bench
- **WHEN** the Crafting Service's interaction router processes the request
- **THEN** the request is routed to the bench-open handler (equivalent to BT1 prerequisites); if `targetId` resolves to nothing owned by Crafting, `InteractRejected(reason="not-crafting-target")` is returned; PC may then try other systems
- **Test type**: Integration
- **Source**: C.12.2, F.2

**H.58 — F.2/C.13: OnGatherCompleted adds to PersonalInventory, capped**
- **GIVEN** `PersonalInventory[playerId].mineral = 18` and RN fires `OnGatherCompleted(playerId, "MINERAL", 3)`
- **WHEN** Crafting Service processes the signal
- **THEN** `PersonalInventory[playerId].mineral = 20` (capped at `MATERIAL_STACK_MAX`); the extra 1 unit is silently discarded; `OnInventoryChanged` fires to the owning client with delta reflecting the actual change (2, not 3)
- **Test type**: Integration
- **Source**: C.4, C.13, F.2

**H.59 — *REMOVED (round-2, 2026-06-01)*** — tested the Composite Patch ↔ Resource Node `GetEquippedEffect` accessor (the gather-magnitude-downgrade read). With the Patch cut, RN no longer reads any Crafting-side equipped-effect state before computing gather emission, and Crafting exposes no such accessor — a net simplification of the RN contract (C.13). Number retired (not reused).

**H.60 — F.2/C.14: HUD receives OnInventoryChanged on every squad inventory mutation**
- **GIVEN** a craft completes (BT3 fires) and adds one Oxygen Canister to `SquadInventory`
- **WHEN** BT3's atomic step 4 fires `OnInventoryChanged`
- **THEN** `OnInventoryChanged({scope="squad", itemId="OxygenCanister", newCount=<N+1>, delta=+1})` is pushed to all alive squad clients; the signal fires simultaneously with `OnCraftCompleted` on the same tick
- **Test type**: Integration
- **Source**: C.14, F.2

**H.61 — F.2/C.14: OnCraftProgressUpdate rate-limited to ≤ 5 Hz**
- **GIVEN** bench is in BS2 with an active CraftSession running at 60 Hz server tick
- **WHEN** the server accumulates `craftProgress` over 1 second (60 ticks)
- **THEN** the owning client receives at most 5 `OnCraftProgressUpdate` signals within that 1 s window; the server's canonical `craftProgress` value continues to accumulate at 60 Hz regardless of the push rate
- **Test type**: Integration
- **Source**: C.14, C.15

**H.62 — F.2/C.13: RN must fire OnGatherCompleted AFTER its own Gather Emit**
- **GIVEN** a gather event fires from Resource Node
- **WHEN** RN's gather completion sequence executes
- **THEN** `DisturbanceService:Emit("Gather", nodePosition, magnitude, playerId)` fires BEFORE `OnGatherCompleted` is signaled; Crafting's inventory update cannot precede the disturbance emission (ordering per ED.C.3.1)
- **Test type**: Integration
- **Source**: C.13, F.4 (RN obligation)

### H.63–H.66 — Performance & Budget ACs

**H.63 [P2] — Server tick budget: CraftSession accumulator does not spike frame time**
- **GIVEN** a maximum-load scenario: `BENCH_MAX_CRAFTERS = 2` benches fully occupied across a squad, all running simultaneously (maximum 1 active CraftSession per bench, up to N safe rooms' worth of benches in the level)
- **WHEN** `RunService.Heartbeat` fires at 60 Hz
- **THEN** the aggregate time spent by the Crafting Service's per-Heartbeat progress accumulation (D.1 loop across all active CraftSessions) is < 0.5 ms per Heartbeat on the server; measured via Roblox MicroProfiler tag `CraftingService_ProgressTick`
- **Test type**: Logic (performance — REQUIRES PLAYTEST measurement)
- **Source**: `.claude/docs/technical-preferences.md` (60 Hz server, performance budgets)

**H.64 [P2] — RemoteEvent throughput: multi-bench burst stays under global rate**
- **GIVEN** 4 players each send 2 distinct Crafting RemoteEvents within a 1 s window (8 total events across all players)
- **WHEN** the global rate limiter evaluates per-player budgets
- **THEN** each individual player's event count is 2, well below `CRAFTING_GLOBAL_RATE_LIMIT = 8 events/s/player`; no events are dropped; no false positive rate-limit fires
- **Test type**: Logic (performance — REQUIRES PLAYTEST measurement)
- **Source**: C.15, G.7

**H.65 [P0] — DataStore write count: zero during a RunSession**
- **GIVEN** a full RunSession runs from start to `RunEnded` including Beacon craft + place + activate
- **WHEN** `RunEnded` fires
- **THEN** `DataStoreService` (or ProfileStore) has been called zero times by `CraftingService` for any Crafting state mutation during that run; all Crafting state (`PersonalInventory`, `SquadInventory`, `CraftSession`, `RunSession` flags, `ActiveDeployables`, `EquippedEffects`) exists only in server memory; cleared at `RunEnded`
- **Test type**: Integration
- **Source**: C.4, C.10, F.7

**H.66 [P2] — Signal Anchor sensor check does not exceed budget**
- **GIVEN** a Signal Anchor is live for its full `SIGNAL_ANCHOR_LIFETIME = 45 s`
- **WHEN** the per-Anchor proximity check loop runs at `SENSOR_CHECK_HZ = 5 Hz`
- **THEN** the loop fires at most 225 times (45 × 5) during the Anchor's lifetime; total server CPU cost of the 225 distance-checks is < 0.1 ms cumulative (negligible at the per-check scale of a single distance comparison); no Heartbeat spike attributable to Anchor proximity logic
- **Test type**: Logic (performance)
- **Source**: C.7.2, G.5

### H.67–H.72 — Cosmetic Boundary ACs

**H.67 [P2] — Bench cosmetic: no craft-time modification**
- **GIVEN** a cosmetic skin is applied to a bench (changes texture / progress-ring style / recipe icon art)
- **WHEN** a recipe is crafted with the skin applied
- **THEN** `CRAFT_BASE_DWELL_TIME` for each recipe matches the locked values in C.2 (2 s, 3 s, 3.5 s, 5 s, 5 s, 6 s, 10 s); the cosmetic skin's data contains no override for craft time; verified by a pre-ship cosmetic review checklist gate
- **Test type**: Config-Data (REQUIRES PLAYTEST checklist gate)
- **Source**: C.3.8

**H.68 [P2] — Bench cosmetic: burst-at-completion magnitude not hidden or altered**
- **GIVEN** a cosmetic skin is applied to a bench
- **WHEN** a craft completes (BT3 fires) and `DisturbanceService:Emit` is called
- **THEN** the emission magnitude matches the recipe's locked `MAGNITUDE_CRAFT_*` constant from C.2; the cosmetic contains no visual suppression of the completion-burst feedback (the HUD's burst indicator fires normally); verified by cosmetic review checklist
- **Test type**: Config-Data (REQUIRES PLAYTEST checklist gate)
- **Source**: C.3.8

**H.69 [P2] — Beacon cosmetic: bounding volume unchanged**
- **GIVEN** a cosmetic skin is applied to the Beacon BasePart
- **WHEN** `RequestBeaconPlace` is processed with the cosmetic active
- **THEN** the Beacon BasePart's bounding volume (used for placement overlap check) is identical to the default Beacon BasePart bounding volume; the cosmetic skin does not scale, shift, or replace the BasePart's collision extents; verified by cosmetic review checklist
- **Test type**: Config-Data (REQUIRES PLAYTEST checklist gate)
- **Source**: C.5.8

**H.70 [P2] — Beacon cosmetic: activation emission magnitude unchanged**
- **GIVEN** a cosmetic skin is applied to the Beacon BasePart
- **WHEN** BCT3 fires
- **THEN** `DisturbanceService:Emit("Beacon", beaconWorldPosition, 0.95, beaconPlacerId)` is called with `initialMagnitude = MAGNITUDE_BEACON = 0.95` regardless of which cosmetic skin is active; the cosmetic contains no data field that routes to the magnitude parameter
- **Test type**: Config-Data (REQUIRES PLAYTEST checklist gate)
- **Source**: C.5.8

**H.71 [P2] — Signal Anchor cosmetic: detection radius unchanged**
- **GIVEN** a cosmetic skin is applied to a Signal Anchor
- **WHEN** the predator proximity check runs
- **THEN** the detection threshold used is `SIGNAL_ANCHOR_DETECTION_RADIUS = 30 studs` regardless of which cosmetic is active; the cosmetic cannot set a `detectionRadius` override; verified by cosmetic review checklist (the dual-clause cosmetic-boundary test)
- **Test type**: Config-Data (REQUIRES PLAYTEST checklist gate)
- **Source**: C.7, game-concept cosmetic-boundary dual-clause

**H.72 [P2] — Cosmetic review gate: dual-clause checklist is a hard approval gate**
- **GIVEN** any new cosmetic affecting a bench, Beacon, or Signal Anchor is submitted for review
- **WHEN** the cosmetic review checklist gate runs
- **THEN** the checklist verifies both clauses: (1) no predator-AI input modification (emission position, magnitude, or detection radius unaffected); (2) no player-survival-decision modification (craft time, material cost, recipe visibility unaffected); a cosmetic that fails either clause is REJECTED and cannot ship
- **Test type**: Config-Data (REQUIRES PLAYTEST checklist gate)
- **Source**: C.3.8, C.5.8, C.7, game-concept anti-pillars

### H.73–H.80 — Round-2 Additions (survival window, schema, networking)

Added by the round-2 patch (2026-06-01). H.73–H.78 validate the new survival-window win/lose model; H.79–H.80 validate the schema + networking blocker fixes. The retired ACs (H.18/H.19/H.20/H.34/H.35/H.36/H.59) freed no numbers (numbers are not reused); these new ACs append at H.73+.

**H.73 [P0] — Window-survival victory: ≥1 alive at window-end fires T8**
- **GIVEN** Beacon is in BC4 (activated; survival window counting down); at least one squad member is alive when `now - RunSession.beaconActivationTime >= BEACON_SURVIVAL_WINDOW`
- **WHEN** the survival-window timer elapses on a Heartbeat
- **THEN** BCT4 fires: `RunSession.beaconWindowSurvived = true`; `OnBeaconWindowSurvived(timestamp)` fires once to the squad → drives PC's T8 (squad escape → victory); the run ends in victory; the Beacon BasePart is removed via the run-end cleanup path; the survival-window + decay-watch timers are cleared. **No T8 fired earlier at activation (H.15).**
- **Test type**: Logic
- **Source**: C.5.6a, C.9 BCT4, C.12.1

**H.74 [P0] — Server crash mid-craft: no persistence, no resume, no material loss**
- **GIVEN** a `CraftSession` is active (BS2/BS3, `craftProgress` between 0 and 1) and the server process restarts (crash)
- **WHEN** the server comes back up
- **THEN** no `CraftSession` survives (purely-runtime state, per C.4 / Pillar 4); the bench is in `BS1`; no materials were deducted (deduction is atomic at BT3 only); the player's `PersonalInventory` is intact; there is no resume path and no `DataStoreService` read/write attributable to the lost session
- **Test type**: Integration
- **Source**: C.4, C.10 (server-crash note), C.9, F.7

**H.75 [P0] — RequestBeaconPlace / RequestPlaceItem clamp client position to server-tracked range (B13)**
- **GIVEN** a client fires `RequestBeaconPlace(position)` with a `position` that is 40 studs from the player's server-tracked `HumanoidRootPart.Position` (well beyond `BEACON_PLACE_MAX_RANGE = 8 studs`)
- **WHEN** the server validates the request
- **THEN** the raw client `position` is NOT used as the placement coordinate; the server clamps the candidate to within 8 studs of the server-tracked player position and raycasts-to-floor from the clamped point; if no valid floor results, `BeaconRejected(reason="invalid-placement")` fires; in no case is a beacon spawned at the 40-stud client-claimed location. Identical handling for `RequestPlaceItem` (Anchor / Relay).
- **Test type**: Logic
- **Source**: C.5.5, C.15, E.22

**H.76 [P0] — Full-squad wipe during window: defeat, no victory/decay signal**
- **GIVEN** Beacon is in BC4; the last living squad member dies before `now - beaconActivationTime >= BEACON_SURVIVAL_WINDOW`
- **WHEN** that `Humanoid.Died` is processed
- **THEN** BCT-DEFEAT fires: the run ends in defeat via PC's all-dead `RunEnded(defeat)` path; the Beacon BasePart is removed via the run-end cleanup path; the survival-window + decay-watch timers are cleared; **`OnBeaconWindowSurvived` does NOT fire** and **`OnBeaconDecayed` does NOT fire**
- **Test type**: Logic
- **Source**: C.9 BCT-DEFEAT, E.24

**H.77 [P0] — Window tie-break: death on the exact window-end Heartbeat favors the squad**
- **GIVEN** on a single Heartbeat, the window has elapsed (`now - beaconActivationTime >= BEACON_SURVIVAL_WINDOW`) AND the last living squad member's `Humanoid.Died` fires
- **WHEN** the server evaluates BC4's exit conditions in declared order
- **THEN** window-survival is evaluated FIRST: BCT4 fires (victory, `OnBeaconWindowSurvived`); BCT-DEFEAT is suppressed by the terminal `beaconWindowSurvived` flag set on the same tick; the result is deterministic victory every run for this input
- **Test type**: Logic
- **Source**: C.9 tie-break, E.25

**H.78 [P0] — OnBeaconWindowSurvived fires exactly once per RunSession**
- **GIVEN** BCT4 fires (window survived)
- **WHEN** `OnBeaconWindowSurvived(timestamp)` is fired
- **THEN** the signal fires to the squad channel exactly once; `RunSession.beaconWindowSurvived` is set true and the survival-window timer is cleared on the same tick, so no second elapse can re-fire it; a subsequent Heartbeat does not re-fire (sibling guarantee to H.56 for `OnEscapeBeaconActivated`)
- **Test type**: Logic
- **Source**: C.9 BCT4, C.15

**H.79 [P0] — CraftSession schema carries benchPosition + primaryCrafterId, used by D.3/D.7**
- **GIVEN** a `CraftSession` is created at BT1
- **WHEN** the session record is inspected and a Craft / midpulse emission fires
- **THEN** `CraftSession.benchPosition` is present and equals the bench's immutable world position, and every D.3 / D.7 `Emit` call passes it as `position`; `CraftSession.primaryCrafterId` is present, equals the BT1 initiator's UserId, and is NEVER reassigned across BT2/BT4 — the D.7 midpulse and BCT1 `beaconCrafterId` both read `primaryCrafterId`, not `crafters[1]`
- **Test type**: Logic
- **Source**: C.10, D.3, D.7

**H.80 [P0] — RemoteEvent handlers do not yield before state mutation (B14)**
- **GIVEN** the `RequestCraft`, `RequestBeaconPlace`, and `RequestBeaconActivate` server handlers (whose race-safety relies on Luau single-threaded sequencing per E.4 / E.9 / E.22)
- **WHEN** each handler is statically inspected from entry to its first authoritative state mutation (flag set, inventory deduct, session create)
- **THEN** no yielding call (`task.wait`, `:WaitForChild`, async `:GetAsync`, event `:Wait`, or any coroutine yield) executes on the path between validation and the state mutation; the validate→mutate sequence is atomic within one Heartbeat, preserving the single-threaded race-guarantee the edge cases depend on
- **Test type**: Logic (static analysis)
- **Source**: E.4, E.9, E.22, C.9 concurrency guarantees

## Open Questions

Items surfaced during authoring (rounds 1–2, 2026-04-30) that did not fully resolve. Each has owner + target-resolution date. Categories: **Tuning** (playtest validates), **Asset spec** (deferred to `/asset-spec`), **Cross-system** (answered when other GDDs are authored), **Architecture** (answered by ADR work).

| ID | Question | Category | Owner | Target resolution |
|---|---|---|---|---|
| **OQ.1** | ~~Should `MAGNITUDE_CRAFT_LIGHT` diverge per recipe between Composite Patch and Quiet Step Wrap?~~ **OBSOLETE (round-2, 2026-06-01)** — both recipes were cut and `MAGNITUDE_CRAFT_LIGHT` was retired (C.2 / G.4). No open question remains. | — | — | Closed by round-2 cut |
| **OQ.2** | Is `CRAFT_BASE_DWELL_TIME = 10 s` for the Beacon the right floor? G.3 noted this as the most-tunable value in the section. At 6 s a 2-crafter run completes in 3 s and the bench-as-exposure beat (Section B) feels rushed; at 15 s the squad's defensive window during the craft becomes the longest commitment in the game. Playtest target: 2–4 player squads with PA prototype to find the wall-clock that produces the right tension. | Tuning | game-designer | Pre-Production playtest sprint 1 |
| **OQ.3** | Should Beacon activation have a short cutscene gap before T8 fires? MVP locked: 0 s (immediate). Future content may want a 1–3 s "the world holds its breath" beat between BCT3 and the victory transition. | Tuning | game-designer | Post-MVP polish phase |
| **OQ.4** | Audio direction sign-off on G-A3 (mechanical-mineral-organic SFX family, distinct from predator's biological signature). Locked provisionally pending Audio GDD authoring; may revise. | Cross-system | audio-director | Audio GDD authoring |
| **OQ.5** | Bench BasePart hero asset: material, color, form factor, no-emissive-at-rest constraint per G-A2. Lock is provisional pending level-design phase. | Asset spec | art-director + level-designer | `/asset-spec system:crafting-and-items` (Pre-Production) |
| **OQ.6** | Anchor + Relay BasePart visual identity (G-A4 deferred). Each must read as a deployed sensor / coordination tool, not weapon / creature, at close range. | Asset spec | art-director | `/asset-spec system:crafting-and-items` |
| **OQ.7** | Beacon activation white column + FogEnd implementation (per art-bible §2.7). Confirm whether 80-stud PointLight achieves the column read or whether Neon Part geometry is required. iPhone SE mobile-downgrade variant needs profiling. | Architecture | technical-artist | Architecture phase ADR (Beacon visual rendering) |
| **OQ.8** | Predator AI Beacon-cap interaction AC: when `fieldValue(beacon-pos) == 0.65` exactly (cap engaged), PA's response should be Investigate, not attack-commit. Cross-system AC obligation per ED.F.2a row 6 + this GDD's F.4. | Cross-system | Predator AI GDD author | Predator AI GDD authoring (after `/prototype predator-ai`) |
| **OQ.9** | Bench-OPEN commit RemoteEvent: C.3.2 describes the action (single tap or `E` once gate is armed) but doesn't name a specific RemoteEvent for the bench-open transition. Surfaced in F.4 as a PC GDD update obligation; may also need adding to C.15 in next revision. | Architecture | this GDD's next revision OR Architecture ADR | Architecture phase OR design-review revision |
| **OQ.10** | HUD GDD reverse-cite obligations: the client-bound signals from C.14 (incl. round-2 `OnBeaconActivated` window-start + `OnBeaconWindowSurvived` victory), plus surface inventory from UI.1 (incl. the survival-window countdown, surface 13), plus alert reason taxonomy from E.6. HUD GDD MUST consume each when authored. | Cross-system | HUD GDD author | HUD GDD authoring |
| **OQ.11** | Architecture ADR triplet: (1) **Bench Proximity Watcher** mechanism + cadence per E.13 / G5 (recommend `RunService.Heartbeat` accumulator at `FIELD_UPDATE_HZ = 5`, but pin in ADR); (2) **Signal Anchor Placement Validation** raycast-to-floor distance + overlap-check thresholds per E.16 / G7; (3) **Crafting RemoteEvent Trust Boundary** rate limits, payload schemas, server-authority invariants per C.15 + E.20–E.23. | Architecture | technical-director + gameplay-programmer | Architecture phase deliverable |
| **OQ.12** | Reserved emission enum slots (3 remaining after `Craft` consumes 1 of 4 ED-reserved slots). Future post-launch content may add: decoy items, noise-makers, ambient-disturbance items. Each new emission type goes through ED's reserved-band logic. | Cross-system | live-ops-designer + Crafting GDD next revision | Live-ops post-launch update authoring |
| **OQ.13** | Recipe cost calibration. The 8-gather Beacon assembly cost (2 BIOMASS + 3 MINERAL + 3 RESONANT) and the 4 aid-item costs (Oxygen Canister 2/0/0, Coil 0/2/1, Anchor 1/1/1, Relay 2/2/1) are economy-designer-validated provisional. Round-2 added a new calibration target: the costs must make the aid suite *necessary* for surviving the post-activation window (C.5.6a) without making it grindy. Playtest may calibrate. | Tuning | economy-designer | Pre-Production playtest sprint 1 |

### Resolved during this round (logged for traceability)

The following game-concept / ED-owned questions were resolved by this GDD. They are NOT open — listed only to confirm the obligations have been met:

- **ED.Q1 / Q2** (Beacon `initialMagnitude` exact value) — RESOLVED at `MAGNITUDE_BEACON = 0.95` per ED.C.3.6 default, registered in ED. Documented in C.2 row 7 + C.5.4 + this GDD's H.14.
- **ED.Q4** (whether crafted items beyond Beacon publish their own emission types) — RESOLVED: a single new `Craft` emission type is added to ED's reserved 4-slot enum (consumes 1 slot; 3 reserved slots remain for future post-launch content). All MVP non-Beacon Crafting bursts use this single `Craft` type with magnitude tier per VA.1.
- **Game-concept open question** (Crafting tree purpose: 4–8 items beyond the win-condition pair) — RESOLVED: **4 aid items** defined (Oxygen Canister + Dampener Coil + Signal Anchor + Squad Relay), all consumable / time-limited, all respecting cosmetic-boundary rule, all serving survival aid / disturbance reduction / coordination roles per Section B. *(Round-2, 2026-06-01: cut from 6 — the Composite Patch and Quiet Step Wrap were removed as trap recipes; the remaining four all bear directly on setting up and surviving the Beacon survival window, C.5.6a.)*
