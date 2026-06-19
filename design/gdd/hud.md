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

[To be designed]

## Edge Cases

[To be designed]

## Dependencies

[To be designed]

## Tuning Knobs

[To be designed]

## Visual/Audio Requirements

[To be designed]

## UI Requirements

[To be designed]

## Acceptance Criteria

[To be designed]

## Open Questions

[To be designed]
