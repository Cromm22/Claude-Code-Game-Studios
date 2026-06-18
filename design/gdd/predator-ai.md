# Predator AI

> **Status**: In Design
> **Author**: chrusht + Claude Code (game-designer, systems-designer, ai-programmer, creative-director, qa-lead)
> **Last Updated**: 2026-06-18
> **Implements Pillar**: Pillar 1 (Quiet Is Power) primary — loud play accelerates the predator; Pillar 3 (The World Watches) — the predator IS how the world watches; Pillar 2 (The Squad Is the Experience) — a single shared threat the squad coordinates against.

## Overview

Predator AI is the server-authoritative behavioral core that turns ecological disturbance into consequence: a single apex hunter, one instance per server, that reads the disturbance field the squad creates and commits to whoever is loudest. It is specified as three data-driven submodules — **Perception** (what the predator can sense: the hottest hotspot via `DisturbanceService:GetHottestHotspot`, line-of-sight raycasts, and the squad-aggregate quiet level via `GetSquadAggregateT`), **Decision** (a deterministic 4-state machine — Patrol → Investigate → Hunt → Disengage — with telegraphed transitions, dwell-time floors, and a no-randomness target-selection rule), and **Navigation** (throttled pathfinding toward the chosen hotspot within a server tick budget). The data-driven split exists so post-launch predator variants are cheap re-parameterizations, not rewrites.

To the player, this system *is* the horror. The predator is the planet answering back — heard before it is seen (its audio reach deliberately exceeds its visual detection range), summoned not by scripting but by the squad's own gathering, lights, sprints, and beacon. Its behavior is **readable, never random**: every state change is globally telegraphed (warning cue → state change → a minimum state duration), it never one-shots, and quiet play visibly cools it down — so the squad always understands *why* it was found and always has a lever to lose it. Without Predator AI there is no teeth to "The World Watches" and no cost to being loud: the disturbance system would be an unread meter, oxygen pressure would be the only threat, and the game's entire differentiator — *the hunt rides your noise* — would not exist.

> *Behavior-level specification only. The locomotion driver (Roblox CharacterController vs legacy Humanoid) and the concrete PathfindingService usage are implementation decisions deferred to an architecture ADR.*

## Player Fantasy

**You are not the hunter. You are the wound.** The planet was here first, and it was quiet first — and everything you do to survive, every canister you crack and lantern you raise and panicked sprint you make, is a fever it runs to flush you out. The first time you notice it is not a jump scare: you're heads-down over a node, the work going well, and underneath the ambience you catch it — breathing, low and organic, *closer than it was.* That is the whole game in one beat. The horror is not random. The planet is answering the noise you made.

**It cannot be fought, and was never meant to be — it is read.** This is not a creature you beat; it is one you *lose.* It telegraphs everything: every escalation announces itself, every state-change is earned, nothing is a cheap shot, and it never ends you in a single blow. You learn its language — the swell of subsonic pressure when it commits to the loudest of you, the stretch of silence it takes to give up — until you stop reacting and start anticipating. Survival is literacy, not reflex, and going quiet is always a lever in your hands.

**And the dread is never yours alone — it is the squad's.** It hunts the loudest point, so four people learn each other in the silence: a held position, a pointed direction, the discipline of someone who freezes instead of bolting. The predator doesn't only threaten the crew; it *creates* it. The beacon-window standoff — when the signal is lit and it bears down at full weight while you all hold the line together — is the moment four players become a crew.

> *Reading the predator belongs to everyone: the heard-before-seen contract carries full visual redundancy — directional indicators and breathing/footstep captions — so a deaf or hard-of-hearing player reads the hunt exactly as well. Accessibility here is fantasy-positive, designed in, not bolted on.*

## Detailed Design

### Core Rules

1. **Instance & lifecycle.** Exactly **one** predator instance per server, server-authoritative, spawned at session start in **Patrol** (the world is already watching — it does not spawn on a threshold). It never despawns mid-run; on full-squad wipe or run-end it is cleaned up with the run.
2. **Perception is two-channel.** (a) **Hearing = the disturbance field** — the predator's only sense of player-generated noise. At the 4 Hz decision tick it calls `DisturbanceService:GetHottestHotspot(predatorPosition, PREDATOR_SEARCH_RADIUS, minimumTier)`, `GetSquadAggregateT()`, and reacts to `TierCrossedEvent`. **The predator senses player disturbance *only* through this field API** (hard rule — guarantees the Dampener Coil and all emission modifiers always work upstream; the predator must never add a direct player-raycast targeting path that would bypass an emission reducer). (b) **Sight = raycasts** — ≤16 rays at 4 Hz, allocated 4 direct-LOS (one per alive player) + 4 forward-arc + 8 shoulder-offset. **Audio range exceeds visual range** (binding constraint): the predator navigates toward a hotspot it cannot see, but **a hit requires unobstructed LOS** to the target.
3. **Targeting (deterministic, no RNG).** The predator pursues the **hottest hotspot** within `PREDATOR_SEARCH_RADIUS` (200 studs). Total-order tie-break: higher field value wins (equal within `HOTSPOT_TIE_EPSILON` = 0.005) → else closer to the predator (squared distance) → else lowest stable `hotspot.id`. If `GetHottestHotspot` returns nil → Patrol fallback (ED E.5/E.5b).
4. **Player lock.** On entering Hunt, the predator locks the **closest alive player to the hotspot** (`argmin` of squared distance over alive players in search radius; tie broken by ascending `UserId`). The lock is **sticky** until: the target dies/disconnects (PC fires `ReleasePredatorLock`), the target exceeds `PREDATOR_LOCK_RELEASE_RANGE` (~60 studs) and a genuinely hotter hotspot has emerged, or the FSM exits Hunt. `PredatorEncountered` analytics fires once per lock per player per session, carrying `lockedPlayerId` and `distanceToHotspot`.
5. **Movement.** Navmesh-bound only (no teleport, no shortcut that bypasses the navmesh). Per-state speed: Patrol 6, Investigate 10, **Hunt 16**, Disengage 6 studs/s. A config-validation gate asserts `WALK_SPEED (12) < PREDATOR_HUNT_APPROACH_SPEED (16) < SPRINT_SPEED (20)` — sprinting is a reliable escape, walking is not (Pillar 1). Investigate (10) is deliberately sub-walk so a player who caused a disturbance still has time to leave before the predator arrives.
6. **Attack & kill (never one-shots).** On contact within `PREDATOR_MELEE_RANGE` (6 studs, strictly less than `BEACON_HOLD_RADIUS` 12) **with LOS**, a Lunge deals `≈ 30% of PLAYER_MAX_HP`; `ATTACK_COOLDOWN` = 3 s between attempts; **4 hits to death** (~9 s if every hit lands uninterrupted). Hard one-shot guard: `effectiveDamage = min(damage, Humanoid.Health − 1)`, so a single hit can never reduce a full-health player to 0. A hit applies a **bounded outward impulse capped at `PREDATOR_BC4_MAX_KNOCKBACK` (8 studs)** (the `_BC4` suffix is a misnomer inherited from the PC GDD — the cap applies in all states; flagged to the PC author). After any hit the player has the cooldown window to sprint out of melee range and break the attack chain — "you lose it, you don't tank it."
7. **Beacon-window commit.** During BC4 (from `beaconActivated == true` until `runOutcomeResolved == true`), the predator reads the beacon hotspot at `max(actualBeaconT, PREDATOR_BC4_COMMIT_T_FLOOR = 0.65)` — it commits to the beacon at peak threat — **but the squad can still lose it** by driving `GetSquadAggregateT()` below 0.30 sustained ≥ 20 s. The FSM does not change during BC4; only the beacon hotspot's effective floor does. (Satisfies ED forward-obligation F8: the predator continues its hotspot path on a capped beacon rather than entering a special state.)
8. **Telegraphs.** Every state change is **globally broadcast to all connected clients** in the form `warning cue → state change → minimum state duration`; the audio cue precedes the visual reveal; a directional indicator + breathing/footstep captions provide full visual redundancy (accessibility is designed in).
9. **Death attribution.** On lock, the predator stores the **top-3 contributing `emissionId`s** from the `HotspotResult` (ED.C.1.11) so the locked player's death screen can name the dominant disturbance type, its magnitude, and seconds-before-death (per the game concept's death-state teaching layer).

### States and Transitions

The Decision submodule is a deterministic 4-state machine. Names are disambiguated from the ED disturbance tiers ("Disengage" was renamed from "Retreat" to avoid collision with the ED tier "Retreat" at t=1.00).

| State | Behavior | Speed (studs/s) | Transitions out |
|---|---|---|---|
| **Patrol** | Waypoint patrol; reads the field each decision tick | 6 | → **Investigate** when a hotspot crosses **Tense (0.30)** (`TierCrossedEvent`) |
| **Investigate** | Path to the hotspot; sight-confirm at ≤40 studs; **minimum 8 s dwell** before Hunt is eligible | 10 | → **Hunt** when the hotspot crosses **Hunt (0.65)** *and* ≥8 s dwell elapsed; → **Patrol** if `GetHottestHotspot` is nil for **15 s** |
| **Hunt** | Lock the closest player; pursue; Lunge on contact + LOS | 16 | → **Disengage** when `GetSquadAggregateT() < 0.30` (`RETREAT_DROPOUT_THRESHOLD`) sustained **≥20 s** (reset semantics — any tick ≥0.30 restarts the timer); → **Patrol** if the hottest hotspot is nil for **15 s** |
| **Disengage** | **Committed 12 s cooldown** (`PREDATOR_DISENGAGE_DURATION`): move to the farthest-from-squad navmesh waypoint and ignore all hotspots — a guaranteed breathing-room window the squad can rely on | 6 | → **Patrol** on timer expiry (resumes patrol waypoints; may immediately re-Investigate on the first tick that reads a hotspot ≥0.30 — Disengage grants a window, not immunity) |

- **Hysteresis** ±0.03 on every tier boundary (ED-canonical). All tier thresholds are ED-owned tuning knobs; this GDD consumes them, it does not redefine them.
- **Two distinct "we lost it" feels, both preserving the 4-state count:** Hunt→**Disengage** (lost via sustained quiet — committed cooldown, distinct retreat audio) vs. Hunt/Investigate→**Patrol-timeout** (the hotspot decayed to nil — different, quieter audio so the squad can tell the two apart). No fifth "Searching" state is needed.
- **Telegraph + minimum state duration** gate every transition so no state can flicker at the boundary; the minimum-duration floor is what makes the global telegraph readable.
- **Spawn:** the predator exists from session start in Patrol (not spawned on a threshold).

### Interactions with Other Systems

- **Ecological Disturbance (hard upstream — the predator consumes the field).** Subscribes to `TierCrossedEvent` (server-internal Knit signal); calls `GetHottestHotspot(predatorPosition, searchRadius, minimumTier)` (nil → patrol) and `GetSquadAggregateT()`; stores the top-3 contributing `emissionId`s for death attribution. ED owns the tier thresholds, hysteresis, and all field math; the predator only reads. Registry: `PREDATOR_SEARCH_RADIUS` = 200 studs (bound 32–512), `RETREAT_DROPOUT_THRESHOLD` = 0.30. The predator supplies its own world position to the accessor; ED never reverse-pulls the predator's position (ED.F.1 preservation). Satisfies ED forward-obligation **F8** (continue the hotspot path on a capped beacon).
- **Player Controller (hard).** Reads each player's server-authoritative `HumanoidRootPart.Position` for lock and contact; writes `lastPredatorDamageTimestamp` and the `predatorCausedImminent` latch that PC's imminent-death predicate consumes; a kill drives PC's **T5 death** path (→ 30 s respawn if ≥1 squad member alive, else run-end). Speed bound `WALK_SPEED < PREDATOR_HUNT_APPROACH_SPEED < SPRINT_SPEED`. **Forward obligation:** `PLAYER_MAX_HP` is PC-owned and not yet authored — predator damage is specified as a **fraction (≈30%)**; the absolute HP value is re-derived once PC pins `PLAYER_MAX_HP`. **Flag to PC author:** tighten G.1's `≤ SPRINT` to a strict `< SPRINT` (equality is an escape treadmill), and clarify that `PREDATOR_BC4_MAX_KNOCKBACK` applies in all states, not only BC4.
- **Crafting & Items (the predator's behavior is what Crafting's items act against).** `PREDATOR_BC4_MIN_COMMIT` is realized as `PREDATOR_BC4_COMMIT_T_FLOOR` (the beacon-commit floor); `PREDATOR_BC4_MAX_KNOCKBACK` = 8 studs satisfies PC H.121 (a knocked-back mobile holder sprints back inside `BEACON_HOLD_RADIUS` 12 within `BEACON_LINE_BREAK_GRACE` ~3 s: 8/20 + 0.35 ≈ 0.75 s ≪ 3 s); the **no-one-shot** rule satisfies "PA winnable-by-holding." **Dampener Coil:** no special predator logic — it reduces the player's emission upstream in ED, and the predator reads the quieter field (its only sense), so it is demonstrably less attentive to a coil-user. **Signal Anchor:** the predator's approach is navmesh-bound and telegraphed (audio precedes visual), and the Anchor fires at the predator's **audio range** for early recon. *(Cross-GDD note to Crafting C.7: the Signal Anchor reports the predator's presence/audio-range arrival, not imminent melee contact — at Hunt speed 16 the 30-stud contact radius would give only ~1.9 s, below the ~4 s readable floor; audio-range framing restores the early-warning value.)*
- **HUD (downstream).** Consumes the globally-broadcast predator state (replicated to all clients at ≤4 Hz, no relevancy gating — anti-exploit): a state label, a directional indicator toward the predator, and captions for the breathing/footstep audio. Spike/telegraph visuals obey the project WCAG flash policy.
- **Resource Node (soft).** The Signal-Anchor readable-approach guarantee applies identically to any Anchor-equivalent recon sensor RN surfaces.

> *New constants introduced here (registered in entities.yaml during Phase 5, formula values defined in Section D): `PREDATOR_PATROL_SPEED`, `PREDATOR_INVESTIGATE_SPEED`, `PREDATOR_HUNT_APPROACH_SPEED`, `PREDATOR_DISENGAGE_SPEED`, `PREDATOR_LOCK_RELEASE_RANGE`, `PREDATOR_MELEE_RANGE`, `PREDATOR_ATTACK_COOLDOWN`, `PREDATOR_LUNGE_DAMAGE` (fraction of `PLAYER_MAX_HP`), `PREDATOR_BC4_MAX_KNOCKBACK`, `PREDATOR_BC4_COMMIT_T_FLOOR` (≙ `PREDATOR_BC4_MIN_COMMIT`), `PREDATOR_DISENGAGE_DURATION`, `PREDATOR_DISENGAGE_RETREAT_RANGE`, `PREDATOR_REPATH_DELTA`, `HOTSPOT_TIE_EPSILON`, `PREDATOR_AUDIO_RANGE`, `PREDATOR_VISUAL_RANGE`. No conflicts with existing registry values; `PREDATOR_SEARCH_RADIUS` and `RETREAT_DROPOUT_THRESHOLD` already exist.*

## Formulas

All values are tuning knobs (full safe ranges and extreme behaviors in Section G). Specialist source: systems-designer (numeric model) + game-designer (kill/commit rulings).

### D.1 — Per-state movement speed & the escape-guarantee inequality

`PREDATOR_SPEED(state) ∈ { Patrol: 6, Investigate: 10, Hunt: 16, Disengage: 6 }` studs/s.

| Variable | Type | Range | Description |
|---|---|---|---|
| `WALK_SPEED` | float | 12 (PC-owned) | Player walk speed |
| `SPRINT_SPEED` | float | 20 (PC-owned) | Player sprint speed |
| `PREDATOR_HUNT_APPROACH_SPEED` | float | 13–19 (def 16) | Hunt closing speed |

**Invariant (config-validation gate, asserted at startup):** `WALK_SPEED < PREDATOR_HUNT_APPROACH_SPEED < SPRINT_SPEED` — strict on both sides.
**Output / behavior:** at 16, a sprinter gains `20 − 16 = 4` studs/s (8 s of stamina → ~32-stud lead → breaks line of sight); a walker loses `16 − 12 = 4` studs/s.
**Extremes:** at `= SPRINT_SPEED` it is an inescapable treadmill (Pillar-1 break); at `≤ WALK_SPEED` walking becomes safe and the core mechanic inverts. Investigate (10) is intentionally sub-walk.

### D.2 — Hotspot selection (deterministic total order)

`preferred(a, b)`: if `|field(a) − field(b)| ≥ HOTSPOT_TIE_EPSILON` → the higher `field` wins; else if `dist²(pred, a) ≠ dist²(pred, b)` → the smaller wins; else the lower `hotspot.id` wins.

| Variable | Type | Range | Description |
|---|---|---|---|
| `field(h)` | float | 0.0–1.0 | Disturbance field value at the hotspot |
| `HOTSPOT_TIE_EPSILON` | float | 0.001–0.01 (def 0.005) | Field-equality band; **must be < `MAGNITUDE_FLOOR` (0.02)** |
| `dist²(pred, h)` | float | 0–40000 studs² | Squared predator→hotspot distance (avoids sqrt) |

**Output:** a single chosen hotspot, identical for identical world state (no RNG).
**Example:** field 0.713 vs 0.710 (Δ 0.003 < ε → tied) → the closer one wins; field 0.720 vs 0.710 (Δ 0.010 ≥ ε) → 0.720 wins regardless of distance.
**Extremes:** ε below 0.001 lets float-accumulation drift swap ordering between ticks (path stutter); ε above 0.01 collapses genuine "loudest wins" differences into the distance tie-break.

### D.3 — Player lock (closest alive player)

`lockTarget = argmin over { alive players within PREDATOR_SEARCH_RADIUS } of dist²(predator, player.HumanoidRootPart)`; ties broken by ascending `UserId`. If the set is empty → no lock; start the Hunt→Patrol nil timer.
**Example:** P1 at (15, 0, 8) → dist² 289; P2 at (10, 0, 12) → dist² 244 → lock P2.

### D.4 — BC4 knockback cap (PC H.121 re-entry guarantee)

`PREDATOR_BC4_MAX_KNOCKBACK / SPRINT_SPEED + t_react + t_latency ≤ BEACON_LINE_BREAK_GRACE`

| Variable | Type | Range | Description |
|---|---|---|---|
| `PREDATOR_BC4_MAX_KNOCKBACK` | float | 2–15 (def 8) studs | Max outward displacement from a hit |
| `t_react` | float | 0.15–0.30 (budget 0.25) s | Mobile reaction time |
| `t_latency` | float | 0.05–0.15 (budget 0.10) s | Replication round-trip |
| `BEACON_LINE_BREAK_GRACE` | float | 3 s (Crafting-owned) | Hold-zone re-entry grace |

**Example:** `8/20 + 0.25 + 0.10 = 0.75 s ≤ 3 s` ✓ (still holds if grace tightens to 1.5 s: `0.75 ≤ 1.5` ✓).
**Extreme:** the binding degenerate is grace itself at 0 (no hit is survivable regardless of knockback), not the cap.

### D.5 — Damage / hits-to-death (never one-shots)

`damagePerHit = PLAYER_MAX_HP × DAMAGE_FRACTION_PER_HIT`; `hitsToDeath = ceil(1 / DAMAGE_FRACTION_PER_HIT)`; `effectiveDamage = min(damagePerHit, Humanoid.Health − 1)`.

| Variable | Type | Range | Description |
|---|---|---|---|
| `DAMAGE_FRACTION_PER_HIT` | float | 0.20–0.40 (def 0.30) | Fraction of max HP per hit |
| `ATTACK_COOLDOWN` | float | 2.0–4.0 (def 3.0) s | Minimum time between hit attempts |
| `PREDATOR_MELEE_RANGE` | float | 4–8 (def 6) studs | Hit range; **must be < `BEACON_HOLD_RADIUS` (12)** |
| `PLAYER_MAX_HP` | int | PC-owned (assumed 100) | **Forward obligation** — absolute damage re-derived when PC pins it |

**Output:** 4 hits → death; `timeToDeath = (4 − 1) × 3.0 = 9 s` uninterrupted. The `Health − 1` floor makes a single hit incapable of killing a full-HP player (the no-one-shot guarantee, enforced for all game states).
**Example:** 100 HP → 30 → 60 → 30 → 0 across 9 s; one 3 s sprint after any hit opens ~6 studs of net distance → clears the 6-stud melee range → breaks the chain.
**Extremes:** `DAMAGE_FRACTION_PER_HIT ≥ 1.0` would allow a one-shot (forbidden — config-gate rejects it); `ATTACK_COOLDOWN < 2 s` makes the post-hit reaction window too short for mobile.

## Edge Cases

- **If `GetHottestHotspot` returns nil** (no live sources, or none meet `minimumTier`): the predator falls back to Patrol behavior (ED E.5/E.5b). No error. In Hunt/Investigate this arms the 15 s nil→Patrol timeout.
- **If the locked player dies or disconnects mid-Hunt:** PC fires `ReleasePredatorLock`; the predator drops the lock and re-evaluates the field next tick (re-locks the new closest player if a hotspot ≥0.65 persists, else runs the nil-timer toward Patrol).
- **If all players die (full wipe):** the predator stops, the run ends, and the instance is cleaned up with the run. No respawn-hunt.
- **If `FindPathAsync` fails or returns `NoPath`:** the predator uses **direct locomotion** toward the target position (it never freezes the Heartbeat) and retries a path on the next re-path gate. A sustained unreachable target resolves via the 15 s Hunt→Patrol timeout.
- **If the target moves while a path is in flight:** continue following the last valid waypoint list; discard + re-path only when the target delta exceeds `PREDATOR_REPATH_DELTA` (~10 studs) and no async path is already pending (the 1-concurrent flag).
- **If two hotspots tie on field value:** resolve by squared distance, then by lowest `hotspot.id` — a total order, never random (D.2).
- **If two alive players are equidistant from the hotspot:** lock the lower `UserId` (D.3).
- **If `squadT` crosses back above 0.30 during the Disengage-arming window:** the 20 s sustain timer **resets** — Disengage commits only on uninterrupted quiet (ED forward-obligation #2, reset semantics).
- **If the squad goes fully quiet during BC4:** even with the beacon read at the `0.65` commit floor, if `GetSquadAggregateT()` stays below 0.30 for ≥20 s the predator disengages — BC4 is winnable by sustained squad discipline, not only by waiting out the timer.
- **If a louder hotspot than the beacon appears during BC4** (a player bolts and spikes the field above the `0.65` floor): the predator may briefly redirect to it — intended; breaking from the hold pulls the hunt onto the breaker (a fair, readable consequence, Pillar 2).
- **If a hit would reduce the target to ≤0 in one blow from full or near-full HP:** `effectiveDamage = min(damage, Health − 1)` caps it — a single hit never kills (no one-shot, all states).
- **If knockback would push a player into geometry / off the navmesh:** the outward impulse is bounded (≤8 studs) and clamped to a valid navmesh position — never a wall-clip or a fling into a kill zone.
- **If the locked player outruns the predator past `PREDATOR_LOCK_RELEASE_RANGE`:** the lock releases **only if** a genuinely hotter hotspot has emerged; otherwise it is sticky (a fast lone player can kite, which is intended and Pillar-2-positive as bait play).
- **If a huge hotspot appears mid-Disengage:** the predator does **not** re-enter Hunt during the committed 12 s cooldown — Disengage is a guaranteed window; it re-evaluates only after returning to Patrol.
- **If LOS to the target is blocked at melee range:** no hit lands (sight-gated) — the predator repositions for LOS rather than dealing damage through walls.
- **If the run ends (victory or wipe) while the predator is mid-path or mid-attack:** all predator state is torn down with the run; no orphaned attack resolves after `runOutcomeResolved`.
- **If a single solo / last-alive player goes quiet:** they can cycle the predator into Disengage repeatedly — intended; the predator is designed to be loseable by quiet play in every squad size.

## Dependencies

| System | Direction | Nature | Interface |
|---|---|---|---|
| **Ecological Disturbance** | PA → ED (consume) | **Hard** — PA cannot function without the field | `GetHottestHotspot(pos, radius, minTier) → HotspotResult?`, `GetSquadAggregateT() → number`, subscribe `TierCrossedEvent`; reads top-3 `emissionId`s; registry `PREDATOR_SEARCH_RADIUS`, `RETREAT_DROPOUT_THRESHOLD`. ED owns tiers / hysteresis / field math. |
| **Player Controller** | PA ↔ PC | **Hard** — bidirectional | PA reads server `HumanoidRootPart.Position`; PA writes `lastPredatorDamageTimestamp` + `predatorCausedImminent` latch; **PC owns** the kill → T5 death path, `WALK_SPEED` / `SPRINT_SPEED`, and `PLAYER_MAX_HP`. |
| **Crafting & Items** | Crafting → PA (consumes PA's behavior) | **Soft** | PA defines `PREDATOR_BC4_MIN_COMMIT` (commit floor), `PREDATOR_BC4_MAX_KNOCKBACK`, and the no-one-shot guarantee; Dampener Coil acts upstream in ED (no PA logic); Signal Anchor = audio-range early warning. |
| **HUD** | HUD → PA (consume) | **Soft** | Globally-broadcast predator state (≤4 Hz, all clients): state label + directional indicator + breathing/footstep captions. |
| **Resource Node** | RN → PA (consume) | **Soft** | Signal-Anchor readable-approach guarantee. |
| **Roblox engine** | — | Platform | `PathfindingService:FindPathAsync`, raycasting, Humanoid locomotion (driver choice deferred to an ADR). |

**Bidirectional obligations to reconcile in sibling GDDs (per the design-doc rule that dependencies are bidirectional):**
- **ED** already lists Predator AI as Subscriber + Querier ✓.
- **Player Controller** must add "depended on by Predator AI," the `lastPredatorDamageTimestamp` / `predatorCausedImminent` / `ReleasePredatorLock` contract, the strict `WALK < PREDATOR_HUNT_APPROACH_SPEED < SPRINT` bound, and must author `PLAYER_MAX_HP`.
- **Crafting & Items** must record the Signal-Anchor audio-range reframe (C.7) and the `PREDATOR_BC4_MIN_COMMIT` / `PREDATOR_BC4_MAX_KNOCKBACK` realizations.

## Tuning Knobs

| Knob | Default | Safe range | Too low / Too high | Interactions |
|---|---|---|---|---|
| `PREDATOR_PATROL_SPEED` | 6 | 4–10 | invisible drift / outruns ambient pacing | < Investigate |
| `PREDATOR_INVESTIGATE_SPEED` | 10 | 8–14 | never arrives / catches walkers | keep < `WALK_SPEED` (12) |
| `PREDATOR_HUNT_APPROACH_SPEED` | 16 | 13–19 | walkers escape / sprint treadmill | **`WALK < x < SPRINT`** (config-gate) |
| `PREDATOR_DISENGAGE_SPEED` | 6 | 4–8 | — | ≤ Patrol |
| `PREDATOR_MELEE_RANGE` | 6 | 4–8 | hits feel buggy / hits land from outside the hold zone | **< `BEACON_HOLD_RADIUS` (12)** |
| `PREDATOR_ATTACK_COOLDOWN` | 3.0 s | 2.0–4.0 | mobile can't react / loses urgency | vs `BEACON_LINE_BREAK_GRACE` |
| `DAMAGE_FRACTION_PER_HIT` | 0.30 | 0.20–0.40 | too tanky / 2-hit harsh | **< 1.0 (hard gate — no one-shot)** |
| `PREDATOR_BC4_MAX_KNOCKBACK` | 8 | 2–15 | cheap-feel / un-re-enterable | bound by D.4 inequality |
| `PREDATOR_BC4_COMMIT_T_FLOOR` | 0.65 | 0.30–0.80 | beacon pull-off-able / standoff too hard | ≙ `PREDATOR_BC4_MIN_COMMIT` |
| `PREDATOR_LOCK_RELEASE_RANGE` | 60 | 40–100 | lock feels random / inescapable | tied to the 20 s Disengage sustain |
| `PREDATOR_DISENGAGE_DURATION` | 12 s | 6–20 | no breathing room / pacing dead-time | run length 5–20 min |
| `PREDATOR_DISENGAGE_RETREAT_RANGE` | 40 | 20–80 | "it left" unreadable / exits navmesh | map size |
| `PREDATOR_REPATH_DELTA` | 10 | 5–20 | path thrash (cost) / stale pursuit | `FindPathAsync` 0.5 s throttle |
| `HOTSPOT_TIE_EPSILON` | 0.005 | 0.001–0.01 | path stutter / "loudest wins" lost | **< `MAGNITUDE_FLOOR` (0.02)** |
| `PREDATOR_AUDIO_RANGE` | TBD (prototype) | — | Anchor warning fires too late | **> `PREDATOR_VISUAL_RANGE`** (binding) |
| `PREDATOR_VISUAL_RANGE` | TBD (prototype) | — | — | < audio range |

*ED-owned, referenced but not redefined here: tier thresholds (0.30 / 0.65 / 1.00), ±0.03 hysteresis, `PREDATOR_SEARCH_RADIUS` = 200, `RETREAT_DROPOUT_THRESHOLD` = 0.30, and the 8 s / 20 s / 15 s FSM dwell-and-timeout floors.*

## Visual/Audio Requirements

**Visual identity.** The predator is a **dark void that reveals itself**, not a glowing creature — ~90% near-black warm-dark mass (`#1C1814`, Slate material), with **amber eye-shine (`#E8871A`) as the only emissive accent**. It reads first as *absence*: a horizontal silhouette mass (dorsal ridge ~4–6 player-heights, head low and forward) larger than anything the environment produces. The world's bioluminescence is the alarm; the predator stays dark against it — "the planet called it, and now it is here." First-sighting staging: silhouette-dark (scale) → amber eye-shine on advance (it sees you) → dim dorsal thermal seams at close range (biological) — never all three at once.

**Per-state visual + audio language.** State must read at lantern-edge distance (~12 studs) on an iPhone-SE-class device — movement speed, body posture, and eye-shine are the primary carriers; the flora disturbance tier is the parallel context read (the predator does not need its own state-color system because the world already communicates the same escalation).

| State | Visual read | Transition warning cue (global telegraph) | Audio |
|---|---|---|---|
| **Patrol** (6) | Deliberate stalk, long settle holds, body low/horizontal; eye-shine only when facing a player | — (baseline) | Slow breathing + spaced weighted footfalls, low subsonic floor |
| **Investigate** (10) | Head lower/forward ("following a scent"), purposeful sub-walk | **Pause-and-pivot** (0.4–0.6 s freeze → turn) + audio quickening | Breathing quickens; footfall cadence rises |
| **Hunt** (16) | Low-slung lean, fast — the speed contrast IS the escalation; eye-shine tracks the locked player | **Dorsal-ridge bristle** (single-frame hackle-raise) + **sub-bass swell** | Heavy breathing + fast footfalls + subsonic pressure; **ambient/music ducks** |
| **Disengage** (6) | Drawn-back posture, moves consistently *outward* (vs. Patrol's circling); eye-shine fades to the rear | **Body-shake** (0.3 s weight-drop) + a distinct cue → signals the 12 s window has started | Footsteps receding; pressure releases — *audibly distinct* from the quieter nil-timeout |

**Sonic identity (binding):** biological/organic — breathing + footstep cadence + low subsonic presence, **non-vocalising** (never roars or screams). **Audio reach exceeds visual reach** — the predator is heard before it is seen. Audio priority: predator audio + spike alerts highest; ambient/music ducked during Hunt.

**Heard-before-seen visual redundancy (3 channels, fire before the world model is visible):**
- **A — screen-edge vignette arc** toward the predator's off-screen direction; desaturated amber, ~1.5 s pulse (0.67 Hz, well under the ≤3/s WCAG 2.3.1 ceiling), decoupled from the flora pulse; an edge arc, never a full-screen flash.
- **B — directional chevron** at the screen edge (ping/waypoint grammar) once the predator is within `PREDATOR_AUDIO_RANGE` of any squad member; moves toward center and fades when the predator is on-screen.
- **C — always-on caption strip** for deaf/hard-of-hearing players: `BREATHING DETECTED` / `APPROACHING` / `FOOTSTEPS RECEDING` (fantasy-positive — always on, not an accessibility toggle).

**Hit / attack feedback** (must read in < 0.5 s, never a full-screen or red flash): a four-edge **vignette crush** (neutral dark, ~0.15 s onset → ~0.4 s release — deliberately *not* amber, so "amber" stays "predator," not "damage"); the **knockback motion itself** is the kinetic read (no camera shake — mobile motion-sickness concern); the hit player's **oxygen pack briefly flashes warm-white** (a squad-visible damage tell, distinct from the downed-red signal); a momentary O2-meter jerk on the victim's own HUD. The hit fully resolves in ~0.55 s, leaving a clean screen before the 3 s-cooldown next hit.

**Technical-artist handoff:** (a) eye-shine Neon LOD enable/disable with a ~5-stud hysteresis band so there is no pop entering lantern range; (b) the directional vignette-arc UIGradient updates at the ≤4 Hz HUD rate, not per-frame (iPhone-SE budget); (c) all state-transition cues are **client-side cosmetic plays** triggered by the ≤4 Hz FSM broadcast — rigged keyframe animations, never per-Part Tweens that would compete with the server locomotion driver. No custom shaders for MVP (built-in Slate / Neon only).

> 📌 **Asset Spec** — Visual/Audio requirements are defined. After the art bible is confirmed current, run `/asset-spec system:predator-ai` to produce per-asset visual descriptions, dimensions, and generation prompts from this section.

## UI Requirements

Predator AI owns **no standalone UI screens**. Its player-facing surfaces are HUD elements it *feeds with data*, rendered and owned by the **HUD GDD**:

1. **Directional predator indicator** — screen-edge chevron + vignette arc pointing toward the predator when it is within `PREDATOR_AUDIO_RANGE` of any squad member.
2. **Caption strip** — always-on `BREATHING DETECTED` / `APPROACHING` / `FOOTSTEPS RECEDING` text (audio redundancy for deaf/HoH players).
3. **State-telegraph cue** — the global warning-cue surface when the predator changes state.
4. **Hit feedback** — the four-edge vignette crush + the victim's O2-meter jerk.

**Interface:** Predator AI supplies `{ state, worldPosition, audioSignature, lockedPlayerId }` via the **≤4 Hz global broadcast** (no relevancy gating — anti-exploit); the HUD renders it. These are **non-interactive readouts** (no input), so touch / mouse / gamepad parity is display-only. All flash behavior obeys WCAG 2.3.1 (edge vignettes, ≤3/s, no full-screen flashes). Exact layout and pixel budgets belong to the HUD GDD, not here.

> **📌 UX Flag — Predator AI:** This system feeds HUD surfaces (directional indicator, caption strip, state telegraph, hit feedback). In Pre-Production, run `/ux-design` for the HUD's predator-indicator + caption elements **before** writing epics; HUD stories should cite `design/ux/hud.md`, not this GDD directly. Note this in the systems index for HUD.

## Acceptance Criteria

This section enumerates **33 acceptance criteria** (H.1–H.33). Format: GIVEN / WHEN / THEN + Test type (L = Logic, I = Integration, V = Visual-Feel, U = UI, C = Config-Data). **[P0]** = blocking sprint-exit gate; **[PROTO]** = gated on the Predator AI prototype (this is the concept-doc-flagged "prototype before final GDD" system); **[FWD]** = absolute value forward-pending on an unauthored system. Each AC is independently verifiable by a QA tester without reading the GDD.

### Lifecycle
- **H.1 [P0]** — GIVEN a new session starts, WHEN the server initialises, THEN exactly one Predator exists in state Patrol, and no second instance can be created while the session is live. (L)
- **H.2 [P0]** — GIVEN a Predator exists, WHEN the run ends (win or wipe), THEN the instance is removed, all its Heartbeat/event connections are disconnected, and no Predator-owned RemoteEvents fire afterward. (I)

### Perception & Sensing
- **H.3 [P0]** — GIVEN the Predator samples the field, WHEN it senses player disturbance, THEN it reads only `GetHottestHotspot` / `GetSquadAggregateT` / `TierCrossedEvent`; no alternate player-state read path fires. (I — stub the ED API)
- **H.4 [P0]** — GIVEN perception is running, WHEN measured over 10 s, THEN total raycasts ≤ 160 (16 × 4 Hz × 10 s). (L)
- **H.5 [P0]** — GIVEN a player is in visual range AND a raycast is issued toward them, WHEN a solid obstacle fully occludes the line, THEN the result is "no hit" and that player yields no threat read. (L — mocked RaycastResult)
- **H.6 [PROTO]** — GIVEN audio and visual detection ranges are both non-zero, WHEN config loads, THEN `PREDATOR_AUDIO_RANGE > PREDATOR_VISUAL_RANGE` strictly; no config may invert it. (C — values prototype-gated)

### Deterministic Hotspot Targeting
- **H.7 [P0]** — GIVEN ≥2 active hotspots with a unique max field value, WHEN targeting runs, THEN the Predator picks that hotspot every time regardless of iteration order. (L)
- **H.8 [P0]** — GIVEN two hotspots tie within `HOTSPOT_TIE_EPSILON` = 0.005, WHEN the tie resolves, THEN lower squared-distance wins, else lower `hotspot.id`; identical across repeated calls on the same world state (D.2 determinism). (L)
- **H.9 [P0]** — GIVEN `GetHottestHotspot` returns nil, WHEN targeting runs, THEN the Predator falls back to Patrol and never paths to a nil position. (L)

### Player Lock
- **H.10 [P0]** — GIVEN Hunt is entered with a resolved hotspot, WHEN the lock is chosen, THEN it locks the closest alive player to the hotspot; ties by ascending `UserId`; deterministic (D.3). (L)
- **H.11 [P0]** — GIVEN a held lock, WHEN the locked player dies/disconnects and `PC:ReleasePredatorLock` fires, THEN the lock releases within the same Heartbeat, and `PredatorEncountered` does not re-fire for that player this session. (I)
- **H.12 [P0]** — GIVEN a held lock, WHEN the locked player exceeds `PREDATOR_LOCK_RELEASE_RANGE` AND a strictly-hotter hotspot exists, THEN the lock releases and targeting re-evaluates; it does NOT release if no hotter hotspot exists. (L)
- **H.13 [P0]** — GIVEN a player is locked for the first time this session, WHEN the lock is established, THEN `PredatorEncountered` fires exactly once for that player (not on re-locks). (L)

### Speed & Movement
- **H.14 [P0]** — GIVEN speed constants load, WHEN the startup config-gate runs, THEN it asserts `WALK(12) < HUNT(16) < SPRINT(20)` strictly; a violation throws a startup error and the session does not begin. (C)
- **H.15 [P0]** — GIVEN each FSM state, WHEN active, THEN `WalkSpeed` equals exactly Patrol 6 / Investigate 10 / Hunt 16 / Disengage 6; no state applies an out-of-set speed. (L)
- **H.16 [P0][PROTO]** — GIVEN the Predator navigates, WHEN it moves, THEN it uses navmesh locomotion only (no teleport); per-frame displacement ≤ `HUNT_SPEED × (1/60)` + physics tolerance. (I — navigable env required)

### Attack & Damage
- **H.17 [P0]** — GIVEN Hunt + locked player within `PREDATOR_MELEE_RANGE` = 6, WHEN an attack is attempted, THEN it lands only if an unobstructed LOS raycast succeeds; an obstructed player at ≤6 studs is not damaged. (L)
- **H.18 [P0][FWD]** — GIVEN a successful hit, WHEN damage is computed, THEN `damage / PLAYER_MAX_HP ≈ 0.30 ± 0.01`. (L — ratio; absolute pends PC)
- **H.19 [P0][FWD]** — GIVEN a player at 1 HP is hit, WHEN `effectiveDamage = min(rawDamage, Health − 1)` applies, THEN HP is set to 1 and the player does not die from this hit (one-shot guard fires server-side before any death signal). (L)
- **H.20 [P0][FWD]** — GIVEN a player starts at `PLAYER_MAX_HP` with no healing, WHEN hit repeatedly under the guard, THEN exactly 4 hits reduce them to 1 HP (hits 1–3 by ~0.30×MAX each, hit 4 via the guard). (L)
- **H.21 [P0]** — GIVEN a successful hit, WHEN cooldown begins, THEN no further damage for `ATTACK_COOLDOWN` = 3 s; a player re-entering melee at 2.9 s is not damaged. (L — time-mocked)
- **H.22 [P0]** — GIVEN a hit applies knockback, WHEN displacement is computed (D.4), THEN magnitude ≤ 8 studs AND `8/HUNT_SPEED + 0.35 ≤ ATTACK_COOLDOWN` holds by config (`8/16 + 0.35 = 0.85 ≤ 3.0`). (C + runtime magnitude assert)

### FSM Transitions
- **H.23 [P0]** — GIVEN Patrol, WHEN `TierCrossedEvent` signals Tense (T ≥ 0.30), THEN → Investigate within one perception tick (≤250 ms). (L)
- **H.24 [P0]** — GIVEN Investigate, WHEN `GetSquadAggregateT` ≥ 0.65 AND dwell ≥ 8 s, THEN → Hunt; if either condition is false, no transition (test both sub-cases). (L)
- **H.25 [P0]** — GIVEN Hunt, WHEN `GetSquadAggregateT` < 0.30 sustained ≥ 20 s, THEN → Disengage; any tick ≥ 0.30 resets the 20 s timer (reset semantics). (L)
- **H.26 [P0]** — GIVEN Disengage, WHEN any hotspot becomes hottest, THEN the Predator does NOT re-enter Hunt/Investigate; it serves the full committed 12 s then → Patrol. (L)
- **H.27 [P0]** — GIVEN Hunt or Investigate, WHEN `GetHottestHotspot` is nil ≥ 15 s continuously, THEN → Patrol; a single non-nil sample resets the countdown. (L)

### Beacon Commit (BC4)
- **H.28 [P0]** — GIVEN BC4 active, WHEN the Predator reads aggregate T, THEN effective T = `max(actualT, 0.65)`; a quiet squad does not drop it out of Hunt on that basis alone. (L)
- **H.29 [P0]** — GIVEN BC4 + Hunt, WHEN `GetSquadAggregateT` < 0.30 sustained ≥ 20 s, THEN → Disengage (the squad can still force a Disengage during BC4). (L)

### Replication & Broadcast
- **H.30 [P0]** — GIVEN any state transition on the server, WHEN it fires, THEN a state-change event broadcasts to ALL clients within one replication cycle (≤250 ms); no client excluded by distance. (I)
- **H.31 [P0]** — GIVEN a client receives a transition, WHEN observed, THEN order is always (1) warning cue → (2) state change → (3) no second change for that state for at least its minimum state duration; never out of order. (I)

### Death Attribution
- **H.32 [PROTO]** — GIVEN a player dies to the Predator, WHEN the death screen shows, THEN the top-3 contributing `emissionId`s (rank order **provided by ED's `HotspotResult`, ED.C.1.11** — PA stores/displays, it does not compute the weighting) are displayed; fewer than 3 shows all available with no fabricated slots. (I)

### Pathfinding
- **H.33 [P0][PROTO]** — GIVEN the Predator calls `FindPathAsync`, WHEN it returns `NoPath`, THEN the Predator falls back to direct locomotion toward the target; it does NOT freeze the Heartbeat, throw, or enter a nil-target state. (L — stubbed `FindPathAsync`)

### Coverage & forward/prototype flags
- **Coverage:** every Core Rule (1–9) and every Formula (D.1–D.5) and every FSM transition has ≥1 AC (map: rules→H.1–H.32; D.1→H.14/H.15, D.2→H.7/H.8, D.3→H.10, D.4→H.22, D.5→H.18/H.19/H.20; transitions→H.23–H.27).
- **[FWD] H.18/H.19/H.20** — absolute damage pends PC authoring `PLAYER_MAX_HP`; written as ratios now; the one-shot guard logic is independently testable today.
- **[PROTO] H.6/H.16/H.32/H.33** — gated on the prototype (audio/visual range constants, a navigable navmesh env, full run lifecycle).
- **Open per qa-lead (→ Open Questions):** per-state **minimum state duration** values (referenced by H.31) are not yet pinned; audio-mix *quality* is a Visual-Feel lead sign-off (`production/qa/evidence/`), not an automated AC.

## Open Questions

- **OQ.1 — Per-state minimum state duration values.** H.31 requires a minimum duration per state for telegraph readability, but only the dwell/timeout floors (Investigate 8 s, Disengage 12 s, nil-timeout 15 s) are pinned. Patrol/Hunt minimum-telegraph-durations are unset. *Owner: systems-designer + game-designer; resolve at/before prototype.* (Will add `PREDATOR_MIN_STATE_DURATION_*` knobs.)
- **OQ.2 — `PREDATOR_AUDIO_RANGE` / `PREDATOR_VISUAL_RANGE` values.** Only the invariant (audio > visual) is fixed; the absolute studs are **prototype-gated** (they also set the Signal-Anchor early-warning lead). *Owner: prototype.*
- **OQ.3 — `PLAYER_MAX_HP` forward dependency.** PC-owned and unauthored; predator damage is specified as a fraction (≈30%) until PC pins it. *Owner: Player Controller GDD.*
- **OQ.4 — Cross-GDD obligations to land** (bidirectional-dependency rule): Crafting C.7 Signal-Anchor **audio-range reframe**; PC tighten G.1 to strict `< SPRINT`, author `PLAYER_MAX_HP`, record the `lastPredatorDamageTimestamp` / `predatorCausedImminent` / `ReleasePredatorLock` contract, and fix the `PREDATOR_BC4_MAX_KNOCKBACK` "all states" label. *Owner: producer to propagate.*
- **OQ.5 — ED accessor cost under load.** If `GetHottestHotspot` / `GetSquadAggregateT` pulled at 4 Hz prove expensive at full field state, ED may need a push-cache (dirty-flag) instead of pull-per-tick. *Owner: prototype + ED ADR.*
- **OQ.6 — Prototype-first validation (this is the concept-flagged highest-risk system).** Three must-validate items before the numbers are trusted: (a) PathfindingService routing an oversized agent through real level geometry; (b) ≤4 Hz state/position replication smoothness under 80–150 ms simulated latency; (c) ED accessor cost (OQ.5). *Owner: `/prototype predator-ai`.*
- **OQ.7 — Locomotion driver.** Legacy Humanoid + `MoveDirection` is recommended over the new CharacterController library (live-platform + NPC-documentation risk); re-evaluate at prototype. *Owner: architecture ADR.*
- **OQ.8 — `PREDATOR_RETARGET_HOTSPOT_DISTANCE`.** The "a hotter hotspot emerged" re-lock threshold (provisional ~4 studs) governs how easily a fast lone player kites the predator off the squad. *Owner: game-designer ruling at playtest.*
