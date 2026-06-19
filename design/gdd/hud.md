# HUD

> **Status**: In Design
> **Author**: chrusht + Claude Code (game-designer, ux-designer, ui-programmer, art-director, creative-director)
> **Last Updated**: 2026-06-19
> **Implements Pillar**: Pillar 2 (The Squad Is the Experience) primary — coordination without voice; Pillar 1 (Quiet Is Power) — the disturbance bar is the proactive-quiet signal; Pillar 3 (The World Watches) — makes the world's reaction legible.

## Overview

The HUD is Terranova's player-facing **presentation layer**: a server-authoritative readout that subscribes to the gameplay systems' pushed signals — the squad's shared **oxygen** pool and **disturbance** level, each player's **stamina** and the **world-response cue**, the **predator's** lock and proximity, **resource-node** states and gather progress, and the **Beacon's** charge and survival-window countdown — and renders them so the squad can act on them. The player does not so much *use* the HUD as **read** it: it is almost entirely a non-interactive display driven by server pushes (≤ 5 Hz), and the few interactive surfaces it shows (the gather progress ring, the emote wheel) are owned and driven by the systems that raise them, not by the HUD itself. It exists because Terranova is a **voiceless co-op survival game** whose every decision — walk or sprint, lantern up or down, gather here or one zone over, hold the Beacon or run — is a trade between quiet and loud, and none of those trades are legible without a readout. The HUD is where the shared oxygen clock, the rising disturbance, the predator turning toward you, and the world's reaction become things the squad can *see* and coordinate around — its **shared nervous system**, the one surface through which Pillar 2 (coordination without voice), Pillar 1 (the disturbance bar as the proactive-quiet signal), and Pillar 3 (making the world's reaction legible) all reach the player.

## Player Fantasy

**The Shared Pulse.**

In a game where no one is assumed to be speaking, the HUD is the squad's **shared nervous system** — the one surface where you feel your teammates and the watching world at a glance, without a word. You don't operate it; you *read* it, the way you read your own breathing. The shared **oxygen** pool says it plainest: one bar, four people drawing on it, ticking down while you hide — you are spending the same breath, and you each know it without saying so. A teammate's **stamina** sliver creeping back up beside you is a held-still promise you can see. This is coordination as *feeling*, not chat.

And it is how you feel the world lean in. You rarely see the predator first — you feel it on the HUD. Someone breaks into a sprint to close a gap and you watch the **disturbance bar** climb; then the **world-response cue** pulses once, upward, a cold acknowledgment that the squad just got louder than it should have been. A half-second later the **predator-lock** indicator tightens at the edge of your eye: it's reading *you* now. Your stomach drops before anything has happened. This is *Alien: Isolation*'s motion-tracker register — a readout that raises your pulse precisely because it tells you something is wrong without showing you the thing.

The HUD never cries wolf, and it never tells you you're safe. The disturbance bar shows your standing, but its alarm only ever *rises* — quiet is a felt reward, never a green light to optimize toward (it is a feeling, not a meter to solve). Because the instrument stays calm and honest through the long quiet stretches — Beacon charge creeping up, disturbance low — you believe it instantly the moment it spikes, and you move. The trust it earns in the silence is what makes its alarm land.

**Anchor moment** — the 2–5 seconds this surface must deliver: crouched in the dark waiting out a patrol, you glance down — shared oxygen ticking, your teammate's stamina recovering beside you — and in the same glance the predator-lock indicator catches your eye: it's *you* it's reading now. The calm instrument you'd stopped consciously watching just spoke. You don't type, you don't ping; you both already know, and you move as one.

**Pillars served**
- **Pillar 2 — The Squad Is the Experience** (primary): the HUD is the shared nervous system that makes voiceless coordination and shared fragility *visible*.
- **Pillar 3 — The World Watches**: the HUD is the felt instrument of the world's attention; the predator-lock and world-response cue are how "the world watches" reaches the player.
- **Pillar 1 — Quiet Is Power**: the climbing disturbance bar makes loud play viscerally costly at a glance, and the one-directional world-response cue keeps quiet a felt reward, not a solvable meter.

**Reference grounding**: *Alien: Isolation* (the motion-tracker — dread from a readout that warns without revealing); *Subnautica* (a calm, diegetic instrument that earns trust through restraint, so its alarms are believed); *Doors* / *Apeirophobia* (Roblox co-op fragility — restraint over reflex, expressed through shared state).

**What the player should feel** — not in command of a dashboard, but plugged into a shared body they trust: calm until it isn't, and when it isn't, they move together without a word.

## Detailed Design

### Core Rules

**CR.1 — Pure-subscriber consumer model (no authoritative state, no client trust).** The HUD holds no authoritative gameplay state and validates nothing client-side — the server is authoritative for every value it displays. Each HUD controller connects its producer signals during `KnitStart` and renders on receipt. The HUD MUST NOT echo any received value back to the server, and MUST NOT request data more frequently than producers publish it (subscribe-only; no `RemoteFunction` poll, no per-frame service getters). It never relays `OnPredatorLockChanged` (Channel B) upstream — mirroring it would break the Predator-AI server-authority spine. Interactive surfaces the HUD shows (the gather ring, the emote wheel) are owned and fired by their producer systems (Resource Node / Player Controller); the HUD renders the result, it does not originate the request.

**CR.2 — Single persistent ScreenGui, five named zones.** All elements live under one `ScreenGui` (`ResetOnSpawn = false`, `IgnoreGuiInset = true`, elevated `DisplayOrder`), with safe-area padding from `GuiService:GetGuiInset()` and a root `UIScale` + `UIAspectRatioConstraint` scaling from iPhone-SE-class to desktop. Zones:

| Zone | Anchor | Holds |
|---|---|---|
| **Squad Vitals** | bottom-centre + upper strip | shared oxygen bar + band; roster/liveness; disturbance bar + per-player contribution |
| **Self Vitals** | bottom-right | own stamina bar |
| **Threat Edge** | screen edges | predator-lock (YOU/SQUAD) + distance-band/bearing chevron + eye-shine/CONTACT treatment |
| **Banners** | centre/top (elevated ZIndex) | world-response swell; beacon charge + survival-window countdown; victory/defeat; death/recovery captions |
| **Contextual Prompts** | near the actioned target | gather progress ring + reject reason; attack/telegraph captions |

Layering is by `ZIndex` within the one ScreenGui, never competing ScreenGuis. No element requires hover; passive readouts are always-visible-when-relevant and readable at rest (touch/mouse/gamepad parity).

**CR.3 — Persistent vs transient.** *Persistent* elements (oxygen, disturbance bar, stamina, roster, and — when relevant — beacon charge/countdown, predator-lock-while-locked) render continuously in their own zones and are never preempted. *Transient* cues (spike alerts, world-response swell, attack/telegraph & death/recovery captions, banners) trigger-and-fade and share a single **alert channel** governed by CR.4. Honored persistence windows: predator-lock YOU/SQUAD holds a **0.75 s minimum display** before it can change; the beacon cap-cue `nearby`/`stationary_nearby` pips hold **1.0 s after disengage** (ED-owned counter).

**CR.4 — Cue-precedence ladder (transient alert channel).** When two or more transient cues would occupy the alert channel in the same instant, the higher-priority cue **preempts**; equal-priority cues **queue** (FIFO); persistent vitals are zone-isolated and always render. Priority, highest first:
1. **Run-End banner** (victory/defeat) — terminal; owns the screen, input locked.
2. **Reconciliation-recovery** ("[Name] status confirmed: down") — owns its moment; **suppresses** any predator alert that would otherwise composite on it (no fresh-kill alarm on a recovery).
3. **Own-death screen / death caption** ("[Name] is down").
4. **Predator attack caption** (STRIKE — YOU / STRIKE — SQUAD).
5. **Predator-lock status change** (YOU/SQUAD acquired/lost) — preempts state-change cues (Channel-B lock-status precedence, PC); honors the 0.75 s min-display.
6. **World-response swell** (upward band-crossing only).
7. **Spike alerts** (ACTIVE / PASSIVE).

**CR.5 — Accessibility is a Core Rule, not a visual afterthought.** **(a) Combined flash ceiling:** the HUD enforces **≤ 3 flashes/second across ALL simultaneously-flashing elements** (WCAG 2.3.1), not per-element — when multiple flashing cues coincide, the alert channel coalesces them (one animation per coalesced semantic event, mirroring RM's simultaneous-death coalescing) and **priority-drops** lower cues' flash to a static/queued render rather than stacking strobes. The HUD owns this *combined* bound even though individual triggers (e.g. RM's `OXYGEN_STATE_CHANGE_MIN_INTERVAL`) are producer-owned. **(b) No color-only state:** every binary/tri-state distinction that drives a squad decision carries a non-color channel (shape, icon, text, caption, or animation direction) — oxygen Critical, predator-lock YOU vs SQUAD, STRIKE-YOU vs STRIKE-SQUAD, distance-band, and victory vs defeat. **(c) Caption parity:** the predator `telegraphCaption`/`attackCaption` and the world-response cue carry text captions for deaf/HoH parity.

**CR.6 — Client-side interpolation (the world leads, the HUD follows).** The HUD smooths producer pushes without ever exceeding their cadence: the disturbance meter uses a cancel-and-restart `0.25 s Sine/InOut` tween to each 5 Hz push; the oxygen bar **dead-reckons** between RM syncs on `Heartbeat` (`P_displayed = P_lastSync − drainRate × elapsed`, re-anchored on `OnOxygenDeducted`/`OnOxygenRestored`); the predator bearing chevron lerps its rotation between the 10–20 Hz sense updates with a snap threshold for large deltas; the gather progress ring derives its fill from `(GetServerTimeNow() − extractionStartTimestamp) / extractionDuration`, NOT a local timer from signal receipt. No HUD path requests a higher push rate than the producer publishes.

**CR.7 — Element inventory (organized by purpose).** The HUD renders exactly the elements its producers push, grouped by design purpose: **Vitals** (oxygen, stamina, roster), **Threat-legibility** (predator-lock YOU/SQUAD, distance-band/bearing, eye-shine/CONTACT, predator-state + attack/telegraph captions, Patrol PRESENCE-ABSENT baseline — suppressed during the beacon window per the States overlay), **Squad-coordination** (disturbance bar + per-player contribution, spike alerts, world-response swell, gather ring + reject reasons), **Objective** (beacon charge + 3-state cap-cue + proximity pips, survival-window countdown), **Outcome** (victory/defeat banner, death caption, reconciliation-recovery). The per-element data contract is specified in "Interactions with Other Systems" below.

### States and Transitions

The HUD moves through three run-level **macro-states** the player experiences, plus a **Beacon-Window overlay** modifier that can apply during two of them. The macro-states reorganize *which* elements render; the overlay reorganizes *emphasis* without a layout reset.

| Macro-state | Enter | Exit | What renders |
|---|---|---|---|
| **Alive** | run start (character spawn) | own death (T5) → Dead/Spectating; `RunEnded` → Run-End | Full HUD — all Vitals, Threat-legibility, Squad-coordination, Objective. Outcome hidden. |
| **Dead / Spectating** *(PROVISIONAL — co-owned with the Camera GDD, OQ.3)* | own death (T5) | T6 respawn → Alive; `RunEnded` → Run-End | Own vitals (stamina, own spike alerts, gather ring) **hidden**; replaced by the spectator view (Camera-owned) + a **respawn-timer countdown** (`RESPAWN_DELAY = 30 s`, PC-owned) and the oxygen-gated "respawn delayed — squad oxygen depleted" state. **Persist:** roster, disturbance bar, threat indicators, objective (the dead player still coordinates by awareness + emote). Emote renders **squad-ui scope only** (`OnEmoteBroadcast.renderScope`). |
| **Run-End** | `RunEnded(outcome ∈ {victory, defeat})` | terminal | Full-screen victory/defeat banner (distinguished by **shape + text**, not color alone); roster persists (who survived); all other elements hidden; **all input locked** (no provisional defeat UI shown then retracted — the banner that arrives after arbitration is authoritative). |

**Beacon-Window overlay** (a modifier on **Alive** and **Dead/Spectating**, NOT a separate macro-state) — active while `beaconActivated == true and not runOutcomeResolved` (Crafting BCT3 → resolution): the **survival-window countdown** ascends to the dominant centre Banner slot; the beacon-charge display collapses to "ACTIVE"; **beacon proximity pips** (`BEACON_HOLD_RADIUS = 12 studs`) become a primary read; predator-lock emphasis increases. **Binding suppression:** the Patrol "PRESENCE-ABSENT" / Disengage baseline cue is **suppressed** for the whole overlay (the predator does not disengage in BC4 — showing a false-calm cue during the highest-stakes window is a must-not). The overlay never resets the layout — it re-weights emphasis within the active macro-state.

**Transition notes:**
- **Alive → Dead/Spectating (T5):** immediately suppress own-vitals + gather interactions; surface the respawn timer; retain roster/threat/objective so the spectator stays a meaningful contributor.
- **Dead/Spectating → Alive (T6):** restore own vitals; fired only after the respawned character exists and is positioned (so the roster `isAlive=true` edge and the HUD restore agree).
- **→ Run-End:** can arrive from either Alive or Dead/Spectating, as victory (window survived) or defeat (wipe / window expired). A coincident wipe+victory is resolved by the RunController's defeat-hold (victory precedence); the HUD shows no provisional banner during that hold — only the single authoritative `RunEnded`.
- **Beacon-Window overlay on/off:** toggles on at `beaconActivated` (BCT3), off at `runOutcomeResolved` — independent of the macro-state transitions above.

### Interactions with Other Systems

The HUD is the terminal consumer of six systems. Every interaction flows **inbound only** (server → HUD); the HUD renders and never writes back (CR.1). "Targeting" notes whether the producer fires per-player (`:Fire(player, …)`) or to the living-squad broadcast.

| Producer | Inbound signal (interface) | Targeting | HUD renders |
|---|---|---|---|
| **Ecological Disturbance** | `OnMeterUpdate {playerT, squadT, beaconCapState, nearby?, stationary_nearby?}` (5 Hz) | per-player | disturbance bar (squad) + per-player contribution + 3-state cap-cue (A/B/C) + proximity pips |
| | `OnDisturbanceAlert {crossedTier, subtype}` | per-player | ACTIVE / PASSIVE spike alert |
| | `OnDeathAttributionPushed {attributionChain}` | per-player (on death) | death-cause caption |
| **Player Controller** | `OnStaminaChanged {stamina}` (≤ 5 Hz) | per-player | own stamina bar |
| | `OnWorldResponseCue {newTier}` (upward only) | squad | world-response swell + caption (non-positional) |
| | `OnPlayerDied {deathCause, deathEventId}` | squad | death caption; on `deathCause=="reconciliation-recovery"` → non-alarming "[Name] status confirmed: down" roster-settle (no world SFX, CR.4 #2) |
| | `OnSquadMemberAliveChanged {playerId, isAlive}` | squad | roster / liveness |
| | `OnEmoteBroadcast {renderScope}` | squad | squad emote — **`squad-ui` scope only** (world scope suppressed for dead players) |
| **Predator AI** | `OnPredatorLockChanged {locked, distanceBand, bearing, audioSignature, lockedPlayerId, attackCaption, telegraphCaption}` (Channel B) | per-locked-player | predator-lock **YOU** + distance-band/bearing chevron + eye-shine/CONTACT treatment + attack/telegraph captions |
| | predator state-change broadcast | squad | predator-lock **SQUAD**; Patrol "PRESENCE-ABSENT" baseline (suppressed during the Beacon-Window overlay) |
| **Resource Node** | `OnNodeStateChanged {state, extractionStartTimestamp, extractionDuration}` + `GatherNodeArmed`/`GatherNodeDisarmed`; `OnNodeFullStateSnapshot` on join | mixed (squad state + per-player arm) | gather prompt + progress ring (server-clock-derived, CR.6) + reject reason on failure |
| **Resource Management** | `OnOxygenChanged {P, drainRate, serverSendTime}` (≥ 2 Hz + on transition); `OnOxygenStateChanged`; `OnOxygenDeducted {simultaneousCount}`; `OnOxygenRestored`; `OnPlayerOxygenExpired` | squad | shared oxygen bar (dead-reckoned, CR.6) + band + Empty cue; **coalesced** lurch on simultaneous deaths (one animation regardless of `simultaneousCount`, CR.5a) |
| **Crafting / RunController** | beacon charge + BCT + survival-window pushes; `RunEnded {outcome}` | squad | beacon charge / cap-cue + survival-window countdown (Beacon-Window overlay); victory/defeat banner |

**Interface ownership + init order.** Every interface above is **owned by the producer GDD** — the HUD owns none, it consumes them. HUD controllers connect all handlers during `KnitStart`, and MUST apply `OnNodeFullStateSnapshot` (and any analogous bootstrap snapshot) **before** acting on incremental per-node events, so a mid-run joiner renders correct state rather than reacting only to events that fired before it was present.

**Eye-shine resolution (closes the ui-programmer feasibility flag).** "Eye-shine" is NOT a field in the PA broadcast (PA retired exact `worldPosition` to prevent a wallhack, RR-4). The HUD renders eye-shine as a **screen-space treatment on the predator-lock indicator, triggered by `distanceBand == "CONTACT"`** (which is tied to `PREDATOR_VISUAL_RANGE`, RD-7 — i.e. "it can see you"), never a world-anchored glow at the predator's position. Whether a *diegetic* world-space eye-shine effect should also exist is an art-direction decision deferred to Visual/Audio + Open Questions (it would be a world VFX owned by Predator-AI/art, not a HUD element).

**No-echo invariant (restates CR.1 at the boundary).** No inbound signal triggers an outbound write. The HUD never calls `RequestSquadOxygenSpend`, never relays `OnPredatorLockChanged`, never re-fires a node request — every producer interface is render-only. The only client→server traffic adjacent to the HUD (`RequestGather`, ping, emote, sprint toggle) originates in the Player Controller / Resource Node input layer, not the HUD.

## Formulas

The HUD owns **no balance values** — every input below is a producer-owned value it consumes. These are the deterministic **presentation/interpolation** mappings the HUD performs to turn pushed values into screen-space. Presentation *constants* (tween duration, chevron lerp/snap, opacity/scale steps) are HUD-owned **Tuning Knobs** (Section G), not formula inputs. `FLASH_RATE_CEILING = 3` (D.6) is a fixed WCAG safety constant, not tunable. All server-clock reads use `workspace:GetServerTimeNow()`.

**D.1 — Oxygen dead-reckoned display value**
`P_displayed = clamp(P_lastSync − drainRate_lastSync × (T_now − T_lastSync), 0, OXYGEN_POOL_START)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `P_lastSync` | float | [0, 600] | pool at last RM sync (RM-owned, `OnOxygenChanged`) |
| `drainRate_lastSync` | float | {1.0, 1.5, 2.2, 8.0} | band drain u/s at sync (RM-owned) |
| `T_now`, `T_lastSync` | float | [0, ∞) | server clock now / `serverSendTime` at sync |
| `OXYGEN_POOL_START` | float | 600 | pool ceiling (RM-owned, registry) |

**Output:** [0, 600], clamped both ends (floor guards over-projection across a sync gap; ceiling guards a Canister restore landing between syncs). **Re-anchor** `P_lastSync`/`T_lastSync` on `OnOxygenDeducted`/`OnOxygenRestored`. **Example:** `480 − 1.5 × 0.35 = 479.475`.

**D.2 — Bar fill fractions** (each ∈ [0, 1] by construction)
- **D.2a Oxygen:** `fillOxygen = P_displayed / OXYGEN_POOL_START` (example: `360 / 600 = 0.6`).
- **D.2b Disturbance:** `fillDisturbance_target = squadT` (ED-owned, already ∈ [0, 1]); the *displayed* value is the 0.25 s `Sine/InOut` tween chasing the target, cancel-and-restarted on each 5 Hz push (CR.6). No numeric tier-boundary overlay (CR must-not). Tween duration/easing → Section G.
- **D.2c Stamina:** `fillStamina = stamina / STAMINA_MAX` (PC-owned `STAMINA_MAX = 100`; example: `75 / 100 = 0.75`).

**D.3 — Bearing → screen-space chevron angle**
`θ_screen = (bearing − cameraYaw + 360) mod 360`; per-frame `θ_rendered = lerpAngle(θ_rendered, θ_screen, CHEVRON_LERP_ALPHA)` on the shorter arc, **bypassed (snaps directly) when** `|angularDelta(θ_rendered, θ_screen)| > CHEVRON_SNAP_THRESHOLD`.

| Variable | Type | Range | Description |
|---|---|---|---|
| `bearing` | float | [0, 360) | world-space angle player→predator (PA-owned, `OnPredatorLockChanged`) |
| `cameraYaw` | float | [0, 360) | client camera heading (local read each frame) |
| `θ_screen` / `θ_rendered` | float | [0, 360) | target / rendered chevron polar angle (0 = predator ahead) |

`CHEVRON_LERP_ALPHA` (≈ 0.25) + `CHEVRON_SNAP_THRESHOLD` (≈ 90°) → Section G. **Example:** `bearing 45°, cameraYaw 30° → θ_screen 15°`.

**D.4 — Distance-band → chevron prominence (stepped lookup, NOT a continuous formula — the HUD never receives raw distance, only the band; preserves the RR-4 position-privacy ruling)**

| `distanceBand` | opacity | scale |
|---|---|---|
| FAR | `CHEVRON_OPACITY_FAR` (0.45) | `CHEVRON_SCALE_FAR` (0.85×) |
| NEAR | `CHEVRON_OPACITY_NEAR` (0.75) | `CHEVRON_SCALE_NEAR` (1.0×) |
| CONTACT | `CHEVRON_OPACITY_CONTACT` (1.0) | `CHEVRON_SCALE_CONTACT` (1.25×) — eye-shine trigger |

The six step values are HUD-owned Tuning Knobs (Section G). A band change MUST carry a non-opacity redundant cue (shape / label / animation) per CR.5b.

**D.5 — Gather ring fill**
`ringFill = clamp((T_now − extractionStartTimestamp) / extractionDuration, 0, 1)` — both inputs RN-owned (`extractionDuration ∈ {3.5, 5.0, 8.0}`); no local timer from signal receipt (CR.6). **Example:** `3.0 / 5.0 = 0.6`.

**D.6 — Combined-flash budget (WCAG ≤ 3/s coalescing, CR.5a)**
`T_inter_flash_min = 1 / FLASH_RATE_CEILING = 1/3 ≈ 0.333 s`. `FLASH_RATE_CEILING = 3` is a fixed WCAG 2.3.1 safety constant (NOT a tuning knob — changing it requires WCAG re-review). When two or more flashing cues coincide within a 0.333 s window, the alert channel plays the highest-priority cue's flash once (CR.4 ladder) and priority-drops the lower coincident cues to a static/held render.

**D.7 — Beacon survival-window countdown**
`timeRemaining = clamp(windowEndTimestamp − T_now, 0, survivalWindowDuration)` — `windowEndTimestamp` is Crafting/RunController-pushed at BCT3. Structurally parallel to D.5 but a distinct producer + UI surface (the dominant Banner slot during the Beacon-Window overlay).

**Cross-GDD consistency flags (carried to Dependencies / Open Questions):** (1) `OnOxygenDeducted`/`OnOxygenRestored` must carry `{P, drainRate, serverSendTime}` for the D.1 re-anchor — forward-obligation to RM; (2) the `bearing` reference convention (CW-from-north assumed) — confirm with PA; (3) `distanceBand` stud thresholds remain prototype-gated on PA's side (the HUD needs only the three enum labels — fine); (4) `windowEndTimestamp` push at BCT3 — confirm with Crafting/RunController.

## Edge Cases

- **If an RM oxygen sync is delayed (latency spike) and D.1 dead-reckoning over-projects:** the displayed pool clamps at 0 (never negative); on the next `OnOxygenChanged`/`OnOxygenDeducted`/`OnOxygenRestored` the HUD re-anchors and the bar snaps to truth. A brief visible correction is acceptable — the server value is authoritative — not a bug.
- **If the HUD initializes mid-run before the first push / `OnNodeFullStateSnapshot` arrives:** render neutral defaults (zeroed/empty bars, no node prompts, no predator indicator) until the first producer push; never fabricate state. The snapshot is applied before any incremental node event (Interactions init-order rule).
- **If more than three flash-producing cues fire within one 0.333 s window:** the alert channel coalesces per D.6 — the highest-priority cue (CR.4 ladder) plays its flash; all lower coincident cues render static/held for that window. Combined rate never exceeds 3/s regardless of how many producers fire.
- **If `OnPredatorLockChanged` flips YOU↔SQUAD (or acquired↔lost) faster than the 0.75 s minimum display:** the HUD holds the current indicator for the remainder of the 0.75 s window, then applies the most-recent state (queue-latest, never sub-0.75 s flicker).
- **If a reconciliation-recovery ("status confirmed: down") and a predator alert would composite in the same instant:** the recovery owns the moment (CR.4 #2); the predator alert is suppressed/queued — no fresh-kill alarm or world-anchored death SFX is layered on a recovery.
- **If `RunEnded` arrives during the Beacon-Window overlay or while the local player is in S4 (dead/spectating):** the victory/defeat banner preempts everything (CR.4 #1); the overlay and spectator surfaces yield; all input locks. No provisional banner is shown during the RunController defeat-hold — only the single authoritative `RunEnded`.
- **If `bearing` jumps a large delta (predator re-locks to a player on the opposite side, or repositions):** the chevron snaps directly to the new `θ_screen` (D.3 snap threshold) rather than lerping across the wrong half of the screen.
- **If `distanceBand == "CONTACT"` (within `PREDATOR_VISUAL_RANGE`, RD-7):** the eye-shine/CONTACT treatment triggers off the band alone — the HUD has no separate LOS field and never reconstructs the predator's world position (RR-4).
- **If a run never crosses an upward disturbance band (a fully-quiet run):** the world-response cue fires zero times — correct (silence-as-reward, GD-8); the HUD shows no "all-clear" pulse, and the disturbance bar alone communicates standing. A zero-cue run is not a broken feature.
- **If simultaneous deaths produce a coalesced `OnOxygenDeducted {simultaneousCount = k}`:** the oxygen bar plays exactly one lurch-down animation regardless of `k` (CR.5a), not `k` stacked flashes; the magnitude reflects the coalesced deduction.
- **If the Camera GDD is not yet authored when an S4 spectator state is entered:** the HUD's S4 overlay (respawn-timer countdown, roster, squad-ui-scope emote) renders over whatever the default camera shows; the spectator camera-feed is Camera-owned and PROVISIONAL — its absence does not block the HUD overlay (flat ZIndex layer).
- **If a producer signal is dropped and never arrives:** the HUD holds last-known-good and relies on the producer's own self-heal (e.g., PC's `BEACON_LATCH_TIMEOUT`, RM's periodic re-sync); the HUD never invents a recovery value. The sole message-driven clear the HUD depends on is the single authoritative `RunEnded`, which the arbiter guarantees to deliver exactly once.

## Dependencies

The HUD is the **terminal consumer** in the system graph — it has **no downstream dependents** (no system reads from the HUD). All dependencies are **upstream** and, with one exception, **hard**: the HUD cannot render its core readouts without each producer's pushed signals. Every interface is **producer-owned** (the HUD owns none); the contracts are tabled in "Interactions with Other Systems."

### Hard Dependencies (HUD cannot function without)

| Producer GDD | Inbound interface | What breaks without it |
|---|---|---|
| **Ecological Disturbance** | `OnMeterUpdate`, `OnDisturbanceAlert`, `OnDeathAttributionPushed` | disturbance bar, per-player contribution, 3-state cap-cue + pips, spike alerts, death-cause caption |
| **Player Controller** | `OnStaminaChanged`, `OnWorldResponseCue`, `OnPlayerDied` (+ reconciliation-recovery variant), `OnSquadMemberAliveChanged`, `OnEmoteBroadcast` | stamina bar, world-response cue, death/recovery captions, roster, squad emote |
| **Resource Management** | `OnOxygenChanged`, `OnOxygenStateChanged`, `OnOxygenDeducted`, `OnOxygenRestored`, `OnPlayerOxygenExpired` | oxygen bar + band + Empty cue (the squad's shared life-clock) |
| **Predator AI** | `OnPredatorLockChanged` (Channel B) + predator state-change broadcast | predator-lock YOU/SQUAD, distance-band/bearing chevron, eye-shine/CONTACT, attack/telegraph captions, Patrol baseline |
| **Resource Node** | `OnNodeStateChanged`, `GatherNodeArmed`/`Disarmed`, `OnNodeFullStateSnapshot` | gather prompt + progress ring + reject reasons |
| **Crafting & Items / RunController** | beacon charge / BCT / survival-window pushes; `RunEnded(outcome)` | beacon charge/cap-cue, survival-window countdown, victory/defeat banner |

> **RunController note:** the single `RunEnded` broadcaster is the unauthored RunController arbiter (PC F.4). Until it exists, the HUD's victory/defeat banner + run-end input-lock are **provisional against PC's caller-side `RunEndConditionRaised`/`RunEnded` contract**; reverse-cite when RunController is authored.

### Soft / Provisional Dependency

| System | Interface | Nature |
|---|---|---|
| **Camera GDD** (unauthored, OQ.3) | S4 spectator camera-feed (which character to follow, framing) | **PROVISIONAL** — the HUD's S4 overlay (respawn timer, roster, squad-ui emote) is a flat layer that renders over whatever the camera shows; the HUD is *enhanced by* but not *blocked on* the Camera GDD. The spectator-camera behavior is Camera-owned; the HUD owns only the overlay. |

### Downstream Dependents

**None.** The HUD is purely terminal — no system consumes data from it.

### Bidirectional consistency

Each producer GDD lists the HUD as a dependent / routes HUD obligations to it (ED F.2 "Hard Dependents" includes HUD; PC/RM/PA/RN/Crafting each carry explicit "HUD GDD owns the render" forward-obligations). Section D surfaced **cross-GDD forward-obligations** the producers must honor for the HUD's formulas to bind: RM (`OnOxygenDeducted`/`OnOxygenRestored` carry `{P, drainRate, serverSendTime}`), PA (the `bearing` reference convention), Crafting/RunController (`windowEndTimestamp` at BCT3) — tracked in Open Questions.

## Tuning Knobs

All HUD tuning knobs are **presentation constants** — they affect *feel and legibility*, never gameplay balance (the HUD owns no balance values; see Formulas).

| Knob | Default | Safe range | Too high | Too low | Affects |
|---|---|---|---|---|---|
| `TWEEN_DURATION_DISTURBANCE` | 0.25 s | 0.10–0.50 s | bar lags reality — dread decouples from cause | bar jitters on each 5 Hz push (no smoothing) | D.2b disturbance bar catch-up |
| `TWEEN_EASING_DISTURBANCE` | `Sine/InOut` | (qualitative) | — | — | a linear ease reads mechanical; a sharp ease reads alarming |
| `CHEVRON_LERP_ALPHA` | 0.25 | 0.15–0.50 | chevron jitters frame-to-frame | chevron laggy/spongy — points where the predator *was*, eroding trust | D.3 bearing smoothing |
| `CHEVRON_SNAP_THRESHOLD` | 90° | 60–135° | chevron swims across the wrong half on a re-lock/teleport | snaps on ordinary relative motion (jarring) | D.3 large-delta snap |
| `CHEVRON_OPACITY_FAR / NEAR / CONTACT` | 0.45 / 0.75 / 1.0 | monotone increasing, each ∈ (0, 1] | FAR too bright → constant alarm, no escalation headroom | steps too close → bands indistinguishable | D.4 proximity prominence |
| `CHEVRON_SCALE_FAR / NEAR / CONTACT` | 0.85× / 1.0× / 1.25× | monotone increasing, > 0 | CONTACT dominates the screen | no felt size-step between bands | D.4 proximity prominence |

**Invariant:** the FAR/NEAR/CONTACT opacity and scale triples MUST be strictly monotone increasing (FAR < NEAR < CONTACT) — a non-monotone set inverts the dread escalation. A startup config-assert SHOULD verify this (mirroring the sibling GDDs' config-gate discipline).

**Referenced, NOT owned (do not duplicate — point to source):**
- predator-lock **0.75 s minimum display** — PA/PC-owned (Channel-B lock-status precedence).
- beacon cap-cue **1.0 s post-disengage persistence** of the `nearby`/`stationary_nearby` pips — ED-owned (`_capCueDecayPassesRemaining`, cadence-derived).
- `FLASH_RATE_CEILING = 3` (D.6) — a fixed **WCAG 2.3.1 safety constant**, NOT a tunable knob.
- all gameplay values the HUD displays (oxygen pool, drain rates, stamina max, extraction durations, tier thresholds) — owned by RM / PC / RN / ED respectively.

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

Tags: **[L]** Logic (automated unit, BLOCKING) · **[I]** Integration (automated/playtest, BLOCKING) · **[UI]** UI/visual (manual walkthrough/screenshot, ADVISORY) · **[S]** Security · **[P]** Performance. qa-validated.

- **H.1 [S/L]** — GIVEN the HUD receives each producer signal, WHEN handled, THEN zero outbound `RemoteEvent`/`RemoteFunction` fires from any HUD controller (the HUD never echoes; CR.1).
- **H.2 [L]** — GIVEN HUD init, WHEN `KnitStart` completes, THEN every producer signal is connected AND no `RemoteFunction` poll and no per-frame *service getter* exists. (The D.1 `Heartbeat` dead-reckon is a local interpolation loop, not a server getter — compliant.)
- **H.3 [UI]** — GIVEN iPhone-SE-class → desktop viewports, WHEN the HUD renders, THEN all five zones are present and readable, nothing renders under a notch/safe-area inset, and no element requires hover.
- **H.4 [L]** — GIVEN two transient cues of differing priority injected the same tick, WHEN the alert channel resolves, THEN the higher-priority cue preempts and the lower queues; equal-priority cues resolve FIFO (CR.4).
- **H.5 [L]** — GIVEN a reconciliation-recovery and a predator alert coincide, WHEN resolved, THEN no predator alert composites on the recovery (recovery owns the moment; CR.4 #2).
- **H.6 [L]** — GIVEN ≥ 4 flash-producing cues within 1 s, WHEN rendered, THEN observed flash onsets ≤ 3/s (min inter-flash 0.333 s) and lower coincident cues render static (CR.5a / D.6).
- **H.7 [UI]** — GIVEN each decision-driving distinction rendered with color disabled — oxygen Critical, lock YOU vs SQUAD, STRIKE-YOU vs STRIKE-SQUAD, `distanceBand` band-change, `beaconCapState` A/B/C, eye-shine/CONTACT, victory vs defeat — THEN each remains distinguishable via shape/icon/text/animation (CR.5b).
- **H.8 [L]** — GIVEN `P_lastSync=480, drainRate=1.5, elapsed=0.35 s`, WHEN D.1 evaluates, THEN `P_displayed = 479.475 ± 0.01`.
- **H.9 [L]** — GIVEN a delayed sync projecting `P_displayed < 0`, THEN it clamps at 0; GIVEN a restore landing between syncs (`P_lastSync=590`, projected `615`), THEN it clamps at `OXYGEN_POOL_START = 600` (D.1).
- **H.10 [L]** — GIVEN `P_displayed=360` (`OXYGEN_POOL_START=600`), `squadT=0.55`, `stamina=75` (`STAMINA_MAX=100`), THEN `fillOxygen = 0.6`, `fillDisturbance_target = 0.55` (the tween target; the displayed value converges over 0.25 s), `fillStamina = 0.75` (D.2).
- **H.11 [UI]** — GIVEN the disturbance bar at any value (including a tier boundary), THEN no numeric value and no tier-boundary overlay is shown (the bar is a feeling, not a meter; D.2b / CR must-not).
- **H.12 [L]** — GIVEN `bearing=45°, cameraYaw=30°`, THEN `θ_screen = 15° ± 0.5°`; GIVEN an inter-update delta `> CHEVRON_SNAP_THRESHOLD`, THEN `θ_rendered` snaps directly (no lerp) (D.3).
- **H.13 [L]** — GIVEN `distanceBand="NEAR"`, THEN chevron opacity/scale = the NEAR knobs; AND a startup config-assert rejects a non-monotone FAR/NEAR/CONTACT opacity or scale triple (D.4 / Tuning-Knob invariant).
- **H.14 [L]** — GIVEN `extractionStartTimestamp` + `extractionDuration=5.0`, `T_now − start = 3.0`, THEN `ringFill = 0.6 ± 0.01`, derived from `GetServerTimeNow()` (NOT a local timer from signal receipt) (D.5).
- **H.15 [L]** — GIVEN `windowEndTimestamp`, WHEN `T_now ≥ windowEndTimestamp`, THEN `timeRemaining` displays 0; WHEN it is in the future, THEN the countdown decrements correctly against the server clock (D.7). *(Cross-GDD: the upper-clamp `survivalWindowDuration` source is a forward-obligation on Crafting/RunController — Open Questions.)*
- **H.16 [I]** — GIVEN a mid-run join, WHEN `OnNodeFullStateSnapshot` + the first `OnMeterUpdate` arrive, THEN the HUD renders correct state and never acted on a pre-join incremental event; before the first push it shows neutral defaults (Interactions init-order).
- **H.17 [UI, PROVISIONAL]** — GIVEN own death (T5), THEN own-vitals + gather hide; the respawn-timer countdown + roster + threat + objective persist; emote renders `squad-ui` scope only. *(Spectator camera-feed is Camera-GDD-owned; this AC is provisional pending OQ.3.)*
- **H.18a [L]** — GIVEN `RunEnded(outcome ∈ {victory, defeat})`, THEN the matching banner shows (distinguished by shape + text, not color alone) and all input locks.
- **H.18b [I]** — GIVEN a coincident wipe and an in-flight victory during the RunController defeat-hold, THEN the HUD shows NO provisional banner during the hold — only the single authoritative `RunEnded`.
- **H.19 [L]** — GIVEN `beaconActivated == true and not runOutcomeResolved`, THEN the Patrol "PRESENCE-ABSENT" / Disengage baseline cue is suppressed (Beacon-Window overlay).
- **H.20 [S]** — GIVEN an `OnPredatorLockChanged` payload, THEN it contains no `worldPosition` field and the HUD renders only `bearing` + `distanceBand` (no position reconstruction; RR-4).
- **H.21 [P]** — GIVEN a 4-player BC4 scenario with all cues active on an iPhone-SE-class device, THEN HUD frame cost stays within budget (no jank) and the HUD issues no push-rate increase.
- **H.22 [L]** — GIVEN `OnPredatorLockChanged` with `distanceBand="CONTACT"`, THEN the eye-shine/CONTACT treatment is active on the predator-lock indicator; GIVEN `"NEAR"` or `"FAR"`, THEN eye-shine is absent (and no world position is read).
- **H.23 [L]** — GIVEN `OnMeterUpdate {playerT=0.7, squadT=0.4}`, THEN the per-player contribution element renders `playerT` distinctly from the squad disturbance fill (no bleed between the two).
- **H.24 [L]** — GIVEN `OnDisturbanceAlert {subtype="ACTIVE"}` vs `{subtype="PASSIVE"}`, THEN each produces a distinct rendered cue ("you caused this" vs "you walked into this").
- **H.25 [L]** — GIVEN a predator-lock state-flip injected `< 0.75 s` after the previous change, THEN the displayed indicator holds the current state until the 0.75 s minimum-display window expires, then applies the latest (CR.3; no sub-0.75 s flicker).
- **H.26 [L]** — GIVEN `OnOxygenDeducted {simultaneousCount=3}`, THEN exactly one oxygen-bar lurch animation plays (not 3 stacked), its magnitude reflecting the coalesced deduction (CR.5a).
- **H.27 [UI]** — GIVEN an `attackCaption`/`telegraphCaption` field on `OnPredatorLockChanged`, THEN a non-empty text caption renders; GIVEN `OnWorldResponseCue`, THEN a text caption is visible (CR.5c deaf/HoH parity).
- **H.28 [I]** — GIVEN `OnMeterUpdate` with `beaconCapState ∈ {A, B, C}`, THEN the correct one of the three cap-cue visual states renders; AND `nearby`/`stationary_nearby` drive the proximity pips (CR.7 / ED F.2a row 7).
- **H.29 [L]** — GIVEN `P_lastSync=300, drainRate=1.5`, WHEN `OnOxygenRestored {P=450, drainRate=1.5, serverSendTime=T}` arrives, THEN `P_lastSync` re-anchors to 450 and subsequent D.1 dead-reckoning projects from 450, not 300.

> **Cross-system coverage:** H.1/H.20 (no-echo, no-position) verify the server-authority boundary; H.16/H.28 verify multi-producer integration; H.18b verifies the RunController arbitration seam. **Provisional/forward-pending:** H.15 (`survivalWindowDuration` source), H.17 (Camera GDD spectator), H.18b (RunController arbiter) — all reverse-cited in Open Questions.

## Open Questions

[To be designed]
