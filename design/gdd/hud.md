# HUD

> **Status**: **ACCEPTED AS-IS (user decision 2026-07-03)** after the narrow two-gate re-review (verdict: NEEDS REVISION — all 4 gate agents FAIL on mechanism precision/AC coverage; the CR.8/CR.9 rulings and the pure-subscriber spine HELD). **15 blocking + ~12 important items are carried as OPEN pre-implementation obligations, NOT resolved** — itemized in `reviews/hud-review-log.md` (round-2 entry). Implementers MUST read that list before building: it includes a reachable D.1 nil-crash, an incorrect D.6 window model, and one unresolved design micro-fork (threat-edge loud-ground during the Beacon-Window overlay). H.21 perf methodology not yet TD-signed-off.
> **Author**: chrusht + Claude Code (game-designer, systems-designer, qa-lead, ux-designer, ui-programmer, art-director, audio-director, creative-director)
> **Last Updated**: 2026-06-19
> **Creative Director Review (CD-GDD-ALIGN)**: Skipped — Lean review mode (not a phase gate).
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

**CR.1 — Pure-subscriber consumer model (no authoritative state, no client trust).** The HUD holds no authoritative gameplay state and validates nothing client-side — the server is authoritative for every value it displays. Each HUD controller connects its producer signals during `KnitStart` and renders on receipt. The HUD MUST NOT echo any received value back to the server, and MUST NOT request data more frequently than producers publish it (subscribe-only; no `RemoteFunction` poll, no per-frame service getters). It never relays `OnPredatorLockChanged` (Channel B) upstream — mirroring it would break the Predator-AI server-authority spine. Interactive surfaces the HUD shows (the gather ring, the emote wheel) are owned and fired by their producer systems (Resource Node / Player Controller); the HUD renders the result, it does not originate the request (the split-ownership mechanism is CR.9).

**CR.2 — Single persistent ScreenGui, five named zones.** All elements live under one `ScreenGui` (`ResetOnSpawn = false`, elevated `DisplayOrder`). `IgnoreGuiInset = true` is set **deliberately** to turn *off* Roblox's automatic topbar inset, so the HUD applies safe-area padding **manually and uniformly** via `GuiService:GetGuiInset()` (plus the mobile home-indicator inset) — automatic inset **OFF**, manual inset **ON**, one consistent safe-area model across notch / topbar / home-indicator on every device (not a double-applied inset — that was the apparent contradiction). A root `UIScale` + `UIAspectRatioConstraint` scale from iPhone-SE-class to desktop. Zones:

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

**CR.8 — Figure-Ground emphasis model (the persistent-readout counterpart to CR.4).** Where CR.4 governs the *transient alert channel* (which momentary cue preempts), CR.8 governs *persistent emphasis*: at any instant exactly **one** persistent readout is the **figure** and every other persistent readout is **ground**, never removed and never below a legibility floor. This is the holistic reduction pass a terminal six-system consumer needs — it answers "what may the player NOT see at the 15–18-read BC4 peak" with *nothing is removed; exactly one thing is loud and the rest stay quiet-but-legible*, which is what "read it like breathing" requires.

*Figure vs ground render (maps onto the §3.3 fill-vs-stroke grammar — no new vocabulary):* the **figure** renders at `FIGURE_OPACITY` (1.0) with its sanctioned idle animation, and fill where the element uses fill; **ground** keeps its *data* channel at full fidelity (a meter keeps its gradient level, the chevron keeps its rotation + band) but drops all *emphasis* channels — rendered at `GROUND_OPACITY` (≈ 0.6, ≥ legibility floor), **no idle animation**, fill suppressed to stroke-only where the element's data isn't carried by fill.

*Figure-selection arbiter (deterministic priority, highest wins):*
1. **Beacon-Window overlay active** → the **survival-window countdown** is the figure.
2. else **predator-lock active** → the **threat edge** (lock indicator + bearing chevron) is the figure (YOU outranks SQUAD).
3. else (default Alive) → the **shared oxygen** bar is the figure.

(In Dead/Spectating, own-vitals are hidden, so the figure is whichever of #1–#3 the surviving squad-state dictates.)

*Critical-oxygen exception (loud ground, not figure):* oxygen at Critical does **not** seize the figure from an active predator-lock (the acute threat-edge owns the eye, and the predator cannot one-shot — PA BC4 keystone), but Critical oxygen is never silenced: it retains its VA.1 dying-pulse throb as **loud ground**, so the lose-clock still shouts without breaking the one-figure rule.

*Ground keeps its voice:* a ground element that fires its own *transient* (spike alert, world-response swell, band-crossing tick) still plays that transient **once** — momentarily raising its voice without becoming the figure. The causal chain (disturbance → world-response → predator-lock) therefore survives at every emphasis level; world-response/spike are **ground, never suppressed-to-absent** (the Pillar-1 fix — suppress-to-absent was the B.2 violation).

*Figure transitions are dwell-governed:* a figure change holds a **0.75 s minimum dwell** (reuses the lock-min-display family) before another change applies, so a flickering state cannot thrash the figure. Like the Beacon-Window overlay, a figure change is an **emphasis re-weight, not a layout reset** — elements stay in their zones; only visual weight changes. This parent ruling dissolves the review's B.1–B.4 (accretion / element-count / suppression-ladder symptoms) at once.

**CR.9 — Render-vs-originate input pattern (the cross-controller seam).** The HUD renders interactive surfaces (gather prompt/ring, emote/signal wheel) but **never originates their input** (CR.1). The seam is resolved by **split ownership of a single Instance**: the **HUD creates and owns the visual Instance** — it lives in a HUD `ScreenGui` zone, and the HUD controls its layout, scaling, lifecycle, and CR.8 emphasis — and exposes it to the producer through a **typed Knit accessor** (e.g. `HUDController:GetGatherPromptMount()` / `:GetEmoteWheelMount()`) returning the Instance (or a stable mount Frame). The **producer controller** (Resource Node / Player Controller) attaches the input connection to that Instance and owns the resulting client→server call. **Invariant:** HUD controller source contains **no input `:Connect`** (`InputBegan`/`InputEnded`/`Activated`/`MouseButton*`/`ContextActionService:BindAction`) and **no `:FireServer`/`:InvokeServer`** — render-vs-originate is enforced statically (H.1b), not just behaviorally (H.1). The producer, holding the reference, owns both the input binding and the remote; the HUD holds neither. The Instance stays physically in the HUD tree (HUD owns layout + emphasis) while *origination* lives entirely producer-side.

### States and Transitions

The HUD moves through three run-level **macro-states** the player experiences, plus a **Beacon-Window overlay** modifier that can apply during two of them. The macro-states reorganize *which* elements render; the overlay reorganizes *emphasis* without a layout reset.

| Macro-state | Enter | Exit | What renders |
|---|---|---|---|
| **Alive** | run start (character spawn) | own death (T5) → Dead/Spectating; `RunEnded` → Run-End | Full HUD — all Vitals, Threat-legibility, Squad-coordination, Objective. Outcome hidden. |
| **Dead / Spectating** *(PROVISIONAL — co-owned with the Camera GDD, OQ.3)* | own death (T5) | T6 respawn → Alive; `RunEnded` → Run-End | Own vitals (stamina, own spike alerts, gather ring) **hidden**; replaced by the spectator view (Camera-owned) + a **respawn-timer countdown** (`RESPAWN_DELAY = 30 s`, PC-owned) and the oxygen-gated "respawn delayed — squad oxygen depleted" state. **Persist:** roster, disturbance bar, threat indicators, objective (the dead player still coordinates by awareness + emote). Emote renders **squad-ui scope only** (`OnEmoteBroadcast.renderScope`). |
| **Run-End** | `RunEnded(outcome ∈ {victory, defeat})` | terminal | Full-screen victory/defeat banner (distinguished by **shape + text**, not color alone); roster persists (who survived); all other elements hidden; **all input locked** (no provisional defeat UI shown then retracted — the banner that arrives after arbitration is authoritative). |

**Beacon-Window overlay** (a modifier on **Alive** and **Dead/Spectating**, NOT a separate macro-state) — active while `beaconActivated == true and not runOutcomeResolved` (Crafting BCT3 → resolution): the **survival-window countdown** ascends to the dominant centre Banner slot and becomes the **CR.8 figure**; the beacon-charge display collapses to "ACTIVE"; **beacon proximity pips** (`BEACON_HOLD_RADIUS = 12 studs`) become a primary read; predator-lock emphasis increases (it is the next-ranked figure if the lock fires). **Binding suppression:** the Patrol "PRESENCE-ABSENT" / Disengage baseline cue is **suppressed** for the whole overlay (the predator does not disengage in BC4 — showing a false-calm cue during the highest-stakes window is a must-not). The overlay never resets the layout — it re-weights emphasis within the active macro-state.

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
`P_displayed = clamp(P_lastSync − drainRate_lastSync × max(0, T_now − T_lastSync), 0, OXYGEN_POOL_START)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `P_lastSync` | float | [0, 600] | pool at last RM sync (RM-owned, `OnOxygenChanged`) |
| `drainRate_lastSync` | float | RM-pushed (per-band) | band drain u/s at sync, **consumed from the RM payload — the HUD never hardcodes the band drain set** (illustrative range {1.0, 1.5, 2.2, 8.0}; RM-owned) |
| `T_now`, `T_lastSync` | float | [0, ∞) | server clock now / the event's **`serverSendTime`** at sync (never local receipt time) |
| `OXYGEN_POOL_START` | float | 600 | pool ceiling (RM-owned, registry) |

**`max(0, ·)` elapsed guard:** an out-of-order or clock-skewed packet (where `T_lastSync > T_now`) would otherwise make `−drainRate × (negative)` *add* oxygen and drift the bar **upward** above truth; the `max(0, ·)` floors elapsed at 0 so a stale read holds, never inflates.
**Latency-projection (RM H.51):** `T_lastSync` anchors to the event's **`serverSendTime`**, not the moment of receipt, in **all three** re-anchor paths (`OnOxygenChanged`/`OnOxygenDeducted`/`OnOxygenRestored`); because the projection then runs from send-time to the live server clock, the displayed value already accounts for network latency — that *is* RM's mandated latency-projection.
**Stale-sync rejection:** re-anchor only when the incoming `serverSendTime ≥` the current anchor's `T_lastSync`; an older packet arriving late is ignored (monotonic anchor).
**Output:** [0, 600], clamped both ends (floor guards over-projection across a sync gap; ceiling guards a Canister restore landing between syncs). **Example:** `480 − 1.5 × 0.35 = 479.475`.

**D.2 — Bar fill fractions** (each ∈ [0, 1] by construction)
- **D.2a Oxygen:** `fillOxygen = P_displayed / OXYGEN_POOL_START` (example: `360 / 600 = 0.6`).
- **D.2b Disturbance:** `fillDisturbance_target = squadT` (ED-owned, already ∈ [0, 1]); the *displayed* value is the 0.25 s `Sine/InOut` tween chasing the target, cancel-and-restarted on each 5 Hz push (CR.6). No numeric tier-boundary overlay (CR must-not). Tween duration/easing → Section G.
- **D.2c Stamina:** `fillStamina = stamina / STAMINA_MAX` (PC-owned `STAMINA_MAX = 100`; example: `75 / 100 = 0.75`).

**D.3 — Bearing → screen-space chevron angle**
`θ_screen = (bearing − cameraYaw + 360) mod 360`; per-frame `θ_rendered = lerpAngle(θ_rendered, θ_screen, CHEVRON_LERP_ALPHA)` along the **signed shortest arc**, **bypassed (snaps directly) when** `|angularDelta(θ_rendered, θ_screen)| > CHEVRON_SNAP_THRESHOLD`.

**Shortest-arc wrap (explicit):** `angularDelta(a, b) = ((b − a + 540) mod 360) − 180 ∈ (−180, 180]` (the signed minimal rotation from `a` to `b`); `lerpAngle` moves `θ_rendered` by `CHEVRON_LERP_ALPHA × angularDelta(θ_rendered, θ_screen)`, so it never crosses the long way around at the 0/360 wrap.

| Variable | Type | Range | Description |
|---|---|---|---|
| `bearing` | float | [0, 360) | world-space angle player→predator (PA-owned, `OnPredatorLockChanged`) |
| `cameraYaw` | float | [0, 360) | client camera heading (local read each frame) |
| `θ_screen` / `θ_rendered` | float | [0, 360) | target / rendered chevron polar angle (0 = predator ahead) |

**Bearing convention (stated, contract-asserted):** D.3 assumes `bearing` and `cameraYaw` are both **clockwise-from-world-north, degrees [0, 360)**. The HUD is now unambiguous against this convention; a startup contract-assert documents the assumption, and OQ.4 is a **one-line confirm with PA** (down from BLOCKING — the HUD no longer guesses). If PA emits a different convention, the fix is a single sign/offset in `θ_screen`.

`CHEVRON_LERP_ALPHA` (≈ 0.25) + `CHEVRON_SNAP_THRESHOLD` (≈ 90°) → Section G. **Example:** `bearing 45°, cameraYaw 30° → θ_screen 15°`.

**Bearing-privacy (single-frame only, RR-4 extension):** the HUD renders `bearing` for the **current frame only** and keeps **no client-readable bearing time-series** (it retains the single smoothed `θ_rendered`, nothing more) — it never writes `bearing` to an Attribute, log, or any replicated surface (H.20b). Sequential raw-bearing samples + own motion could triangulate the predator's world position over 3–5 s, which RR-4 (single-frame) does not by itself prevent; this is **not fully closeable HUD-side** (the bearing is necessarily on-screen), so the durable mitigation is **PA-side bearing quantization** (emit `bearing` rounded to the chevron's angular sector rather than raw degrees) — forward-obligation to PA (OQ.11, security).

**D.4 — Distance-band → chevron prominence (stepped lookup, NOT a continuous formula — the HUD never receives raw distance, only the band; preserves the RR-4 position-privacy ruling)**

| `distanceBand` | opacity | scale |
|---|---|---|
| FAR | `CHEVRON_OPACITY_FAR` (0.45) | `CHEVRON_SCALE_FAR` (0.85×) |
| NEAR | `CHEVRON_OPACITY_NEAR` (0.75) | `CHEVRON_SCALE_NEAR` (1.0×) |
| CONTACT | `CHEVRON_OPACITY_CONTACT` (1.0) | `CHEVRON_SCALE_CONTACT` (1.25×) — eye-shine trigger |

The six step values are HUD-owned Tuning Knobs (Section G). A band change MUST carry a non-opacity redundant cue (shape / label / animation) per CR.5b.

**D.5 — Gather ring fill**
`ringFill = clamp((T_now − extractionStartTimestamp) / extractionDuration, 0, 1)` — both inputs RN-owned (`extractionDuration` is the RN-pushed per-node extraction constant; illustrative set {3.5, 5.0, 8.0}); no local timer from signal receipt (CR.6). **Zero-duration guard:** if `extractionDuration ≤ 0` (degenerate/missing push), `ringFill = 1` (treat as instant-complete) rather than divide by zero. **Example:** `3.0 / 5.0 = 0.6`.

**D.6 — Combined-flash budget (WCAG ≤ 3/s coalescing, CR.5a)**
`T_inter_flash_min = 1 / FLASH_RATE_CEILING = 1/3 ≈ 0.333 s`. `FLASH_RATE_CEILING = 3` is a fixed WCAG 2.3.1 safety constant (NOT a tuning knob — changing it requires WCAG re-review). When two or more flashing cues coincide within a 0.333 s window, the alert channel plays the highest-priority cue's flash once (CR.4 ladder) and priority-drops the lower coincident cues to a static/held render.

**Buildable artifact — the `FlashArbiter` module.** The combined ceiling is enforced by a single **`FlashArbiter`**, the *only* code path permitted to start a flash/throb/strobe tween on any HUD element; no cue tweens directly. A cue **submits** a request `{elementId, priority, semanticEventId}` (`priority` = the CR.4 rank; `semanticEventId` groups producer-coalesced events such as RM's simultaneous-death batch). The arbiter holds a **0.333 s sliding window** of the last onset and resolves each submit:
- **Window clear** → play this cue's flash now (record the onset timestamp).
- **Within the window, higher `priority`** → preempt: cut the in-flight lower cue to a static/held render, play this one (one onset still, the previous having already counted — preemption replaces, it does not add a second onset inside the window).
- **Within the window, equal/lower `priority`** → drop this cue to a static/held render for the remainder of the window (no new onset).
- **Same `semanticEventId`** as an onset already played → collapse to that one onset regardless of count (this is the CR.5a / H.26 simultaneous-death coalescing).

The arbiter is a **pure function of (request stream, clock) → onset schedule**, so it is unit-testable with a fake clock (H.6 injects N requests across 1 s and asserts onsets ≤ 3 and that dropped cues rendered static). This is the single mechanism behind CR.5a, the D.6 ceiling, and the H.6/H.26 ACs.

**D.7 — Beacon survival-window countdown**
`timeRemaining = clamp(windowEndTimestamp − T_now, 0, survivalWindowDuration)` — `windowEndTimestamp` + `survivalWindowDuration` are Crafting/RunController-pushed at BCT3. **Zero/negative-duration guard:** if `survivalWindowDuration ≤ 0` (degenerate/missing push), `timeRemaining = 0` (window treated as already over) rather than a negative or inverted clamp. Structurally parallel to D.5 but a distinct producer + UI surface (the dominant Banner slot during the Beacon-Window overlay).

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
| `FIGURE_OPACITY` | 1.0 | (fixed at 1.0) | — | figure no longer reads as the figure | CR.8 figure render weight |
| `GROUND_OPACITY` | 0.6 | 0.45–0.8 | no figure/ground separation (everything competes) | ground illegible (data lost) | CR.8 ground render weight |

**Invariant:** the FAR/NEAR/CONTACT opacity and scale triples MUST be strictly monotone increasing (FAR < NEAR < CONTACT) — a non-monotone set inverts the dread escalation. A startup config-assert SHOULD verify this (mirroring the sibling GDDs' config-gate discipline).

**Referenced, NOT owned (do not duplicate — point to source):**
- predator-lock **0.75 s minimum display** — PA/PC-owned (Channel-B lock-status precedence).
- beacon cap-cue **1.0 s post-disengage persistence** of the `nearby`/`stationary_nearby` pips — ED-owned (`_capCueDecayPassesRemaining`, cadence-derived).
- `FLASH_RATE_CEILING = 3` (D.6) — a fixed **WCAG 2.3.1 safety constant**, NOT a tunable knob.
- all gameplay values the HUD displays (oxygen pool, drain rates, stamina max, extraction durations, tier thresholds) — owned by RM / PC / RN / ED respectively.

## Visual/Audio Requirements

The HUD owns **no art or audio assets** outright — it renders within the **art bible's** locked UI palette (§4.5), shape grammar (§3.3), and animation-feel rules (§7.3), and triggers a thin **non-diegetic UI-audio layer** over producer-owned world audio. Across both channels the binding posture is **visual-primary, audio-secondary**: every gameplay-critical state is fully legible with device audio off (mobile-primary, iPhone-SE-class — audio-off is a normal operating condition), so audio never solely carries a decision (reinforces CR.5b/c). Values marked **[NEW — needs sign-off]** are proposals not yet locked in the bible.

### Visual — governing principles (art-bible)

Three bible rules bound every HUD visual choice: **(1) Reserved-Hue Exclusion (§4.2)** — no HUD element may enter hue 18°–48° at S > 50% (the predator's amber `#E8871A` lane must stay clean so peripheral amber means *only* "predator"); **(2) Shape Grammar (§3.3)** — `CornerRadius = 0` hard rectangles, **UIStroke-only at rest / fill = urgency**, UIGradient on meters only, the emote wheel the sole circle; **(3) Principle 3** — the *world* is the disturbance meter, the HUD bar is the lower-intensity **confirmation**, so the HUD never out-shouts the world (CR.6, "the world leads, the HUD follows").

### VA.1 — Per-event visual feedback

**Vitals.**
- **Oxygen bar** — the §4.5 horizontal UIGradient (drains left): critical `#FF8060` (0.0) → warning `#FFD060` (0.3) → safe `#5FFFD8` (1.0); the gradient *is* the band read (no separate color event). Non-color redundancy (CR.5b): label weight steps Medium→**Bold** at Warning; at Critical the bar UIStroke throbs `1px→2px→1px` @ 0.5 s (a slow dying-pulse, **not** a flash). **Colorblind continuous-read (CR.5b):** two **static positional tick marks** sit at the Warning and Critical fill-fraction boundaries (thin white notches on the bar frame) so the *band boundary* is legible by position even when the gradient hue is not perceived — a colorblind player reads "I'm below the Critical tick," not a hue **[NEW]**. (The disturbance bar has **no** such ticks by design — it carries no readable bands, H.11/CR must-not; its crossings surface through the world-response transient + caption, VA.7.) Empty: UIStroke throb @ 1 Hz + a one-shot `1.02×` scale punch at the zero-crossing **[NEW]**. The **coalesced simultaneous-death lurch** (CR.5a/H.26): exactly one horizontal-compression tween `1.0×→0.97×→1.0×` over 0.3 s regardless of `simultaneousCount`, magnitude = the coalesced deduction.
- **Disturbance bar** — §4.5 UIGradient cool-grey-blue `#3A4A60` → mid-violet `#46379A` → vivid violet-blue `#6040E0` (all keypoints verified cool-side, no amber); fills right; displayed value is the 0.25 s `Sine/InOut` tween chasing `squadT` (D.2b). **Per-player contribution** (H.23): a stroke-only white `#F0F0F0` (ImageTransparency ~0.6) inverted-chevron marker riding *above* the bar at `playerT`'s x-position — position is the non-color signal **[NEW]**. No numeric/tier overlay (CR must-not).
- **Stamina bar** — self-vital, bottom-right; flat white `#F0F0F0` fill on the cool-dark frame (a single flat color, distinct from the two gradient meters), drains left; low-stamina (<20%) UIStroke throb @ 1 Hz, lighter than oxygen-Critical (stamina regenerates) **[NEW]**.

**Threat-legibility.**
- **Predator-lock YOU vs SQUAD** (the single most important non-color distinction, CR.5b) — both are `CornerRadius=0` screen-edge rectangles in white `#F0F0F0`; they differ on **four non-color channels**: YOU = 4px stroke / **filled** (opaque `#1A1E2B`) / **Bold** "LOCK" / one-shot acquire pulse; SQUAD = 2px stroke / **unfilled** / Medium "P# LOCK" / no pulse. **[NEW — needs sign-off, verify 2px vs 4px legibility on iPhone-SE.]**
- **Bearing chevron + distance band** — §7.2 chevron (inverted-V, white, 60° tip), screen-space, rotates to `θ_screen` (D.3); the D.4 opacity/scale steps (FAR 0.45/0.85× · NEAR 0.75/1.0× · CONTACT 1.0/1.25×, i.e. 27→32→40 px) are the non-color band cue; a 0.15 s `1.15×` scale "tick" fires on each band change so the step *feels* discrete on mobile **[NEW]**.
- **Eye-shine / CONTACT treatment** (screen-space, off `distanceBand=="CONTACT"`, never a world position — RR-4) — a narrow (8–12px) **angular screen-edge vignette bracket** at the predator's bearing, white `#F0F0F0`, opacity tween `0→0.15→0` over 0.6 s (NOT a full-screen vignette — the death screen owns that). **PRIMARY (locked) escalation:** the YOU indicator's **pure-UIStroke escalation `4px→8px→4px` @ 0.4 s** — zero hue risk, ships by default. **OPTIONAL enhancement (does NOT ship unless AD signs off):** the YOU "LOCK" text additionally shifting `#F0F0F0` → warm-cream `#FFF0C8`. *Corrected arithmetic: `#FFF0C8` is hue **≈ 43.6° — INSIDE the 18°–48° reserved band** — at S ≈ 21.6%, so it passes the §4.2 exclusion **only by the S > 50% saturation gate**, not by being outside the band (the earlier "~50°, outside" note was wrong). Because it sits in-band by hue, it is gated behind explicit AD exclusion-zone sign-off (OQ.6); absent that sign-off the UIStroke escalation alone is the CONTACT treatment.* **[NEW]**

**Squad-coordination.**
- **Spike alerts ACTIVE vs PASSIVE** (H.24) — shared: frame UIStroke punch `1px→3px→1px` @ 0.2 s + Bold alert text fade-in 0.08 s / out 0.5 s. Non-color split: **text copy** ("DISTURBANCE — CAUSED" vs "ZONE ELEVATED") + a disturbance-meter scale punch `1.04×` on ACTIVE only (your meter moved *because of you*), none on PASSIVE.
- **World-response swell** (upward only) — deliberately **does not** share the spike's frame-flash signature (different cause, must feel different): a Banner-zone TextLabel ("WORLD STIRS") that **fades in at fixed position** (no slide — preserves the movement grammar) over a slower 1.5 s `Sine/Out`.
- **Gather ring** (D.5, server-clock-derived) — the §7.7 radial fill arc, white, `3px→5px→3px` UIStroke on complete. **Reject reason**: short text-only ("NOT IN RANGE" / "NODE DEPLETED"), no frame (a reject informs, it doesn't alarm — no equipment-panel treatment) **[NEW]**.

**Objective.**
- **Beacon charge** — flat white `#F0F0F0` fill ("collective progress toward escape," no semantic overlap with any resource meter; in the Objective zone, label "BEACON") **[NEW]**.
- **3-state cap-cue (A/B/C)** — three non-color channels: A = steady 1px stroke; B = 1 s-period pulse (§7.2 objective-marker spec); C = steady **3px** stroke + Bold "CAP" label **[NEW]**.
- **Proximity pips** (`nearby`/`stationary_nearby`, `BEACON_HOLD_RADIUS = 12` studs) — small 8×8px stroke-only boxes per in-range player; **fill toggles on `stationary_nearby`** (fill = the holding-still positive signal, the §3.3 urgency convention read positively in-window) **[NEW]**.
- **Survival-window countdown** — the dominant centre Banner during the Beacon-Window overlay: rectangular frame, 2px stroke, 80%-opaque fill, **RobotoMono** numeral + Bold "HOLD — BEACON" label; late-window escalation is by **weight, not rate** — the UIStroke pulse *intensifies* (heavier) as `timeRemaining→0` while the numeral stays authoritative; any pulse stays **< 3/s** and is subject to the D.6 combined-flash coalescing audit against coincident pulsing elements (cap-cue C, YOU-lock).

**Outcome.**
- **Roster/liveness** — §7.4 squad strip: alive = squad-color stroke, no fill; downed = same stroke + alert-red `#FF6060` fill (fill = urgency); dead = X icon, no fill. (Fully bible-specified.)
- **Death caption** ("[Name] is down") — §7.3 step-3 caption, Medium 16px white, Banner zone. **Reconciliation-recovery** ("[Name] status confirmed: down", CR.4 #2) — **smaller (14px), no frame, no death-screen sequence** (no desaturate/vignette/freeze — it's a roster correction, not a kill), 1 s fade. Explicitly differentiated so the implementer never applies the death-screen treatment to a recovery **[NEW]**.
- **Victory/Defeat banner** (H.18a, shape+text not color) — same near-opaque frame grammar both outcomes; differ by **text** ("ESCAPED" vs "FAILED", Bold, the largest text the HUD ever shows) + a **shape** cue: Defeat carries a 1px full-width horizontal separator line above the roster row, Victory has none; both show the survivor roster strip below. Run-End banner slide-in (from bottom, 0.5 s `Cubic/Out`) is the **one sanctioned translational HUD animation** — permissible only because input is locked and no world read competes.

### VA.2 — Motion grammar (HUD mirrors the world's flora rule)

Per §3.1's movement grammar (only teammates/predator translate; flora *scales in place*), the HUD's urgency vocabulary is **pulse-in-place** — UIStroke-weight and UIScale changes, never translation, during active gameplay (the chevron *rotates*/*scales*, it does not slide). Alert text **fades in at fixed position** (no sliding, which could read as a world-motion cue). All reactive animations ≤ 0.3 s (§7.3). The **sole exception** is the terminal Run-End banner slide-in (VA.1 Outcome). Fill-vs-stroke is load-bearing throughout: **fill = alarm**, stroke-only = passive readout (§3.3).

### VA.3 — Reserved-hue compliance (load-bearing disambiguation)

Three HUD warm values sit near the predator band; the **corrected** hue arithmetic (so future asset reviews neither wrongly fail nor wrongly pass them):
- **critical `#FF8060`** — hue ≈ **12°**, *below* the 18° lower bound → explicitly red-family, **outside** the band. Clean.
- **warning `#FFD060`** — hue ≈ **42° (INSIDE the 18°–48° band)** at S ≈ **62% (ABOVE the S > 50% gate)** → it does **not** clear the §4.2 exclusion by hue or saturation; it survives **only by the §4.5 disambiguation triad** (much-lighter value + fixed bottom-left meter position + it is a meter, not a peripheral alarm). The earlier "~50°, 2° outside the 48° bound" note was **wrong**. Because the warning band-colour is load-bearing (amber=warning is the universal convention and the band can't simply move), it stays — but it now carries an **explicit AD triad-confirmation** alongside the cream (OQ.6): AD must affirm the §4.5 triad covers an in-band, in-gate meter colour.
- **CONTACT warm-cream `#FFF0C8`** — hue ≈ **43.6° (INSIDE the band)** at S ≈ **22% (below the gate)** → passes only by the saturation gate; demoted to optional-pending-sign-off (VA.1 Threat-legibility, OQ.6).

No other HUD element approaches the band; the disturbance gradient and all banners stay cool/white.

### VA.4 — Audio: ownership boundary + per-cue intent

The HUD fires a **2D non-diegetic UI-audio layer** on signal receipt; it does **not** own or trigger world/diegetic audio (CR.1). Producer-owned (NOT HUD): the predator low-frequency rumble/sweep (Predator-AI world 3D audio, the §4.7 primary backup cue), the ambient stem crossfade (ED tier), gather-audio disturbance scaling (RN/ED), the first-pulse atmospheric shift (ED). HUD-owned cues:

| HUD-owned cue | Trigger | Intent / character | Type |
|---|---|---|---|
| Oxygen state blip | `OnOxygenStateChanged` | dry clinical "threshold passed" click; stepped softer→harder Healthy→Empty; no reverb | transient |
| Spike sting (ACTIVE/PASSIVE) | `OnDisturbanceAlert` | ACTIVE = sharp dry crack (personal); PASSIVE = low non-tonal pressure (environmental) | transient |
| Predator-lock YOU | `OnPredatorLockChanged` (you) | tight low-freq "snap into focus," harmonically adjacent to the PA rumble; **[NEW]** optional sub-80 Hz felt component (headphones only) | transient |
| Predator-lock SQUAD | state-change broadcast | lighter/higher sibling of YOU — "warning label," clearly secondary | transient |
| Predator-lock lose | lock clears | **silence** (the cessation of threat audio *is* the reward — no all-clear) **[NEW]** | — |
| Beacon countdown tick | D.7 window | dry organic mechanical tick @ **constant 1 s**, **gravity/weight increases** near zero (not rate) | persistent-periodic |
| Gather complete / reject | D.5 / reject | complete = quiet mechanical "lock" (not celebratory); reject = flat low "no" | transient |
| Victory / Defeat stinger | `RunEnded` | victory = short quiet organic *relief* swell (not a fanfare — surviving, not conquering); defeat = low subsidence/dimming | transient, terminal |
| Death / recovery | `OnPlayerDied` | death = quiet low transient; **reconciliation-recovery = silent or one neutral confirm click** (never an alarm, CR.4 #2) | transient |
| World-response swell | `OnWorldResponseCue` | low non-musical resonant "the world inhales"; **[NEW — ownership: HUD-fired 2D vs ambient-system-fired; resolve in OQ]** | transient |

### VA.5 — Audio precedence (mirrors CR.4)

Audio-visual desync on high-priority events erodes the trust the Player Fantasy is built on, so the audio channel **mirrors the CR.4 precedence *order* — but NOT its queue *behavior***: where the visual alert channel *queues* equal/lower cues (FIFO), the **audio gate DROPS them (never queues)**, because queued stings would produce the exact burst D.6 prevents. The gate is a small explicit state machine — states `{ idle, playing(priority, until_t) }`, and on each incoming sting request with rank `p` (the CR.4 rank):
- **idle** → play, transition to `playing(p, now + tail)`.
- **playing(q, ·) and `p` is higher-priority** → preempt: fade-cut the current sting, play the new one, `playing(p, …)`.
- **playing(q, ·) and `p` is equal/lower** → **drop** the request (no queue), stay `playing(q, …)`.
- requests sharing a producer-coalesced batch (e.g. simultaneous deaths) collapse to one sting (the D.6 `semanticEventId` parallel).

Applied to the ladder: **(1)** the Run-End stinger ducks/terminates all other audio (fade-in ≤ 0.5 s); **(2)** reconciliation-recovery audio **suppresses any coincident predator/fresh-kill sting** (CR.4 #2 — dropped, not queued); **(3)** own-death; **(4)** STRIKE sting; **(5)** lock-change preempts **(6)** world-response, which ducks beneath all above; **(7)** spike stings follow the same drop-not-queue rule (one sting fires, coincident lower stings dropped). The gate is unit-testable (a request stream + fake clock → the sting that actually plays). **[NEW — the Run-End duck of world audio (ambient/PA) is a SoundService group op the HUD must NOT own; ownership (RunController vs a dedicated AudioService) → OQ.8.]**

### VA.6 — The "calm instrument" prohibitions (named must-not list)

To keep the alarm believable ("it only ever rises — quiet is a felt reward, never a green light"), the HUD audio layer **MUST NOT**: play an all-clear/ascending chime on predator-lock lose; play a reassuring blip on oxygen restore (neutral re-anchor click at most); play a success fanfare on gather complete; play a positive "respawn ready" fanfare; or escalate the beacon tick by *rate* in a way that makes the early slow tick read as "safe." Permitted: upward severity *steps* within a cue family, and the single victory stinger (earned only because the run is over).

### VA.7 — Caption parity & mobile mix

Every decision-relevant audio cue has a **visual primary** (the audit confirms no audio-only carrier): predator attack/telegraph captions and the world-response cue carry **text captions** for deaf/HoH parity (CR.5c/H.27), and the audio sting must convey nothing the caption omits (no direction/intensity in audio alone). Mobile: audio latency (~50–100 ms) and OS interruptions mean **no HUD mechanic may depend on audio timing** — the beacon numeral, not the tick, is the authoritative "almost out" read; sub-bass cue components are headphone-only enhancements, fully legible without them.

> **📌 Asset Spec** — Visual/Audio requirements are defined. After the art bible is approved, run `/asset-spec system:hud` to produce per-asset visual descriptions, dimensions, and generation prompts. Flagged candidates: beacon-charge icon, cap-state rendering (icon vs stroke-only), world-response icon, proximity-pip render path (Frame vs ImageLabel — ui-programmer to resolve), and the survival-window Banner frame dimensions/ratio (a §7.4 layout gap).

## UI Requirements

The HUD is **passive-by-default**: the overwhelming majority of it is non-interactive readout that subscribes to server pushes and renders (CR.1). The few interactive surfaces it *shows* are **owned by their producer systems** — the HUD renders them; it never attaches input. All UI scales via the root `UIScale` + `UIAspectRatioConstraint` and respects `GuiService:GetGuiInset()` (CR.2), works on touch tap / mouse click / gamepad button with **no hover dependency** (CR.5), and is verified on iPhone-SE-class as the floor. Values marked **[NEW — needs UX sign-off]** are proposals not yet locked. This section is GDD-altitude; the per-screen pass is a later `/ux-design`.

### UI.1 — Input model (passive-by-default; producer-owned interaction)

Every Vitals, Threat-Edge, Banners, and proximity-pip element accepts **zero input on every platform** — touch, mouse, and gamepad all have identical (no) behavior. This is the design, not an omission. The narrow interactive surfaces the HUD renders — the **gather prompt/ring** (Resource Node), the **emote/signal wheel** and **quick-ping** triggers (Player Controller) — have their input connection in the producer layer via the **CR.9 split-ownership pattern**: the HUD creates and owns the Instance and exposes it through a typed Knit accessor (`HUDController:GetGatherPromptMount()` / `:GetEmoteWheelMount()`); the producer controller binds the input to that reference and owns the client→server call. **Implementer rule (CR.1/CR.9):** `HUDController` MUST NOT attach `InputBegan`/`Activated` to any element in its own zones; `button.Activated:Connect(...)` inside a HUD controller violates the no-echo invariant even when the downstream call looks harmless — enforced statically by H.1b.

### UI.2 — Input-parity matrix (no-hover, all three input methods)

| Surface | Owner | Touch | Mouse | Gamepad |
|---|---|---|---|---|
| **Gather prompt + ring** | Resource Node | tap-hold on prompt (§7.7 radial arc) | left-click | A/✕ when armed |
| **Emote/signal wheel** | Player Controller | hold-to-open trigger → drag-to-segment → release | hold LMB → drag → release | hold L1/LB (awaits PC input-map) → stick → release |
| **Quick-ping** | Player Controller | two-finger tap (PC C.4) | G key | L1/LB (PC C.4) |
| **Gather reject readout** | Resource Node | none (read-only) | none | none |
| All other HUD elements | — | none | none | none (pure readout) |

Interactive surfaces remain interactive in **Dead/Spectating**: the emote wheel keeps its full input contract (the dead player coordinates via emote); PC filters available slots via `OnEmoteBroadcast.renderScope = "squad-ui"` — the HUD renders what PC fires, it does not independently filter.

### UI.3 — Touch tap-targets (iPhone-SE floor)

Minimum touch target = **44 pt** (Apple HIG / Material floor, independently committed in game-concept; §7.4 ping/emote triggers are 48×48px, meeting it with headroom). **Hit area ≠ visual size:** in Roblox a `GuiButton`'s hit region is its `AbsoluteSize`, so a visually 12px stroke-only element uses a 44–48px transparent hit Frame. Per-element: ping trigger 48px ✓; emote trigger 48px ✓; **emote-wheel segments** — the §7.4 220px wheel diameter is the *minimum* that keeps 8 sectors ≥ 44pt arc, do **not** reduce below 220px; tap registers anywhere in the sector (not centroid-hit) **[NEW]**; emote **center cancel zone ≥ 44px diameter** **[NEW — art-bible gap, not previously sized]**; gather ring 48px hit Frame ✓. **Proximity pips (8×8px), roster tiles (12×12px), and all bars/indicators are readout-only — no hit area** (state explicitly so implementers don't add input to them). Safe-area: the bottom-right 100px trigger stack (48 ping + 4 gap + 48 emote) must clear the iPhone-SE home-indicator inset (~34pt) + §7.4's 16px clearance — verify in Studio's iPhone-SE preview **[NEW]**.

### UI.4 — Layout across aspect ratios

The five zones (CR.2) anchor on two bottom clusters (Squad-Vitals bottom-left/centre; Self-Vitals + PC triggers bottom-right), Threat-Edge wrapping all four edges, Banners centre, Contextual-Prompts in world-projected space.
- **iPhone SE (375×667pt):** §7.4 non-overlap holds; the tight axis is horizontal — bottom bars (~150pt) + right stack (48pt) leave a ~177pt gap. The real risk is *vertical* crowding in Banners during the Beacon-Window overlay (UI.5).
- **iPad / 4:3:** horizontally safe; bars at 40% Scale widen to ~307pt — a visual-register check, not a functional one.
- **Ultrawide (21:9+):** 40%-Scale bars stretch past 1000px, breaking the equipment-readout register and hurting fill-legibility. **Cap bar width at `min(0.40 × screenWidth, 600px)` via a max-Offset pattern** (mobile layout unaffected) **[NEW — needs UX + ui-programmer sign-off → Open Question UI.OQ.1]**.
- **Safe-area (binding implementation rule, not just an art note):** every zone anchors at Scale-0 + `GuiInset` offset + 8px padding; **all Threat-Edge screen-edge elements (incl. the eye-shine vignette bracket) clamp their rendered position to within `GuiInset` bounds, not the raw screen edge** **[NEW — Visual-section gap]**.
- **Contextual-Prompts gather ring:** follows the node's world→screen projection (like §7.6 ping markers), **clamps to within safe-area insets** when the projection nears an edge, and must not overlap the bottom-left bar cluster or bottom-right trigger stack at minimum approach distance **[NEW — layout gap, not in §7.4 grid]**.

### UI.5 — Beacon-Window overlay crowding (the highest-congestion moment)

On iPhone SE the Banners zone must hold the survival-window countdown, the collapsed "ACTIVE" beacon label, and any coincident predator caption / spike text / death-recovery caption at once. **Banners priority/collapse order (small-screen):** (1) **survival-window numeral** — never preempted (it is the macro-state's primary read); (2) "HOLD — BEACON" label → collapses to "HOLD" if vertical space is critical; (3) **predator attack/telegraph captions** — never dropped (CR.5c), shift *below* the numeral if both render; (4) death/recovery caption — shifts below; (5) world-response "WORLD STIRS" — lowest, defer/drop in-overlay if it would collide with the numeral. Rule: the countdown numeral takes the top-centre Banner anchor for the overlay; all else stacks below or queues per CR.4; CR.4 #2–#4 captions are never dropped, only repositioned. **CR.5/D.6 combined-flash audit applies at overlay onset** — when the countdown pulse, cap-cue-C pulse, and YOU-lock first render together, the implementer must verify combined rate ≤ 3/s on that first tick (a pre-launch gate, not only a runtime guard).

### UI.6 — OQ.14 (two-step touch friction) — HUD side CLOSED-BY-REFERRAL

The HUD's Contextual-Prompts zone renders the gather prompt and ring (governed by `GatherNodeArmed`/`GatherNodeDisarmed`, CR.1) and **renders no lantern-toggle affordance** (lantern state is PC-owned input). **HUD obligation (closed here):** never require a player to touch more than **one** HUD zone to complete a single gather action. The mechanical question — whether PC auto-raises the lantern on gather-arm in a dark zone (PC C.3.6 / DC-5 arm predicate already requires `lanternRaised`) vs. manual raise, which is what creates the opposing-corner three-gesture friction on touch — **forwards to the PC GDD**, which already co-owns OQ.14 (ux-designer + game-designer, "before/alongside HUD + Resource Node"). The HUD closes its half; PC closes the input-mechanic half.

### UI.7 — Reduced-motion (classification owned here; surface deferred)

The HUD reads a **`reducedMotion` flag** (set by an accessibility settings system *outside* the HUD — read-only here; the surface/toggle is deferred to the accessibility pass, PC OQ.16 / art-bible §7.8–§7.9 decision F). The HUD owns only the classification of its own animations:
- **Load-bearing (degrade to minimum functional form, never removed):** oxygen dead-reckon update, disturbance 0.25s tween (→ instant-snap allowed), bearing-chevron rotation (→ snap, never freeze — the rotation *is* the data), proximity-pip fill-toggle, survival-window decrement.
- **Decorative (replace with static fallback):** emote-wheel open/close easing, gather-complete flash, spike frame-flash (→ static 3px for the duration), banner slide-in (→ instant-appear), world-response fade-in (→ instant-on).
- The **D.6 combined-flash ceiling is NOT a reduced-motion feature** — it is an always-on WCAG baseline regardless of player settings; do not conflate.

> **📌 UX Flag — HUD**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the HUD's screens/elements (and the emote-wheel + gather-prompt interactions) **before** writing epics. Stories that reference UI should cite `design/ux/hud.md`, not the GDD directly.

## Acceptance Criteria

Tags: **[L]** Logic (automated unit, BLOCKING) · **[I]** Integration (automated/playtest, BLOCKING) · **[UI]** UI/visual (manual walkthrough/screenshot, ADVISORY) · **[S]** Security · **[P]** Performance. qa-validated.

- **H.1 [S/L]** — GIVEN the HUD receives each producer signal, WHEN handled, THEN zero outbound `RemoteEvent`/`RemoteFunction` fires from any HUD controller (the HUD never echoes; CR.1).
- **H.1b [S/L]** — GIVEN the HUD controller source, WHEN statically scanned, THEN it contains no input-binding call (`InputBegan`/`InputEnded`/`Activated`/`MouseButton*`/`ContextActionService:BindAction`) and no `:FireServer`/`:InvokeServer` — the render-vs-originate invariant (CR.9) is enforced at the source level, closing the input-binding relay vector that H.1's behavioral no-outbound test does not catch.
- **H.2 [L]** — GIVEN HUD init, WHEN `KnitStart` completes, THEN every producer signal is connected AND no `RemoteFunction` poll and no per-frame *service getter* exists. (The D.1 `Heartbeat` dead-reckon is a local interpolation loop, not a server getter — compliant.)
- **H.3 [UI]** — GIVEN iPhone-SE-class → desktop viewports, WHEN the HUD renders, THEN all five zones are present; **no element's rendered AABB intersects the `GuiInset`/notch region**; **every text element renders ≥ 14 px after `UIScale` on iPhone-SE-class** (the §7.3 caption floor); and no element requires hover (cross-checked against the UI.2 input-parity matrix).
- **H.4 [L]** — GIVEN two transient cues of differing priority injected the same tick, WHEN the alert channel resolves, THEN the higher-priority cue preempts and the lower queues; equal-priority cues resolve FIFO (CR.4).
- **H.5 [L]** — GIVEN a reconciliation-recovery and a predator alert coincide, WHEN resolved, THEN no predator alert composites on the recovery (recovery owns the moment; CR.4 #2).
- **H.6 [L]** — GIVEN ≥ 4 flash-producing cues submitted to the `FlashArbiter` within 1 s, WHEN resolved, THEN **flash onsets ≤ 3 in any 1 s sliding window** and lower coincident cues render static (CR.5a / D.6). *Onset = a luminance-increasing opacity/stroke transition of an element, counted across ALL simultaneously-animating elements; the arbiter's (request-stream, fake-clock) → onset-schedule is asserted directly.*
- **H.7 [UI]** — GIVEN each decision-driving distinction rendered with the **color channel disabled (forced greyscale)** — oxygen Critical, oxygen Warning/Critical **band boundary** (the static tick marks), lock YOU vs SQUAD, STRIKE-YOU vs STRIKE-SQUAD, `distanceBand` band-change, `beaconCapState` A/B/C, eye-shine/CONTACT, victory vs defeat — THEN for **each** listed distinction the named non-color channel (shape / icon / text / animation / position) is **present in the rendered greyscale output** and lets an observer name the state without color (asserted per-element in the manual walkthrough doc; CR.5b).
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
- **H.20b [S]** — GIVEN the HUD's bearing handling, THEN it retains no client-readable bearing time-series beyond the single smoothed `θ_rendered` and writes `bearing` to no Attribute, log, or replicated surface (D.3 single-frame bearing-privacy; the residual triangulation vector is mitigated PA-side by bearing quantization, OQ.11).
- **H.21 [P]** — GIVEN a 4-player BC4 scenario with all cues active on an iPhone-SE-class device, THEN **HUD per-frame CPU cost ≤ 2.0 ms** at the 30 fps mobile floor (≈ 6% of the 33.3 ms frame budget; technical-preferences performance budget), measured via MicroProfiler/`Stats` over the scenario, AND the HUD issues no push-rate increase. *(The 2.0 ms slice is TD-proposed — flagged for technical-director sign-off in the systems/ui-programmer gate. Impl prerequisites: consolidate the RunService loops, short-circuit D.3 when unlocked, and pre-create/pool transient cues + Tweens — no 5 Hz cancel-restart churn.)*
- **H.22 [L]** — GIVEN `OnPredatorLockChanged` with `distanceBand="CONTACT"`, THEN the eye-shine/CONTACT treatment is active on the predator-lock indicator; GIVEN `"NEAR"` or `"FAR"`, THEN eye-shine is absent (and no world position is read).
- **H.23 [L]** — GIVEN `OnMeterUpdate {playerT=0.7, squadT=0.4}`, THEN the per-player contribution element renders `playerT` distinctly from the squad disturbance fill (no bleed between the two).
- **H.24 [L]** — GIVEN `OnDisturbanceAlert {subtype="ACTIVE"}` vs `{subtype="PASSIVE"}`, THEN each produces a distinct rendered cue ("you caused this" vs "you walked into this").
- **H.25 [L]** — GIVEN a predator-lock state-flip injected `< 0.75 s` after the previous change, THEN the displayed indicator holds the current state until the 0.75 s minimum-display window expires, then applies the latest (CR.3; no sub-0.75 s flicker).
- **H.26 [L]** — GIVEN `OnOxygenDeducted {simultaneousCount=3}`, THEN exactly one oxygen-bar lurch animation plays (not 3 stacked), its magnitude reflecting the coalesced deduction (CR.5a).
- **H.27 [UI]** — GIVEN an `attackCaption`/`telegraphCaption` field on `OnPredatorLockChanged`, THEN a non-empty text caption renders; GIVEN `OnWorldResponseCue`, THEN a text caption is visible (CR.5c deaf/HoH parity).
- **H.28 [I]** — GIVEN `OnMeterUpdate` with `beaconCapState ∈ {A, B, C}`, THEN the correct one of the three cap-cue visual states renders; AND `nearby`/`stationary_nearby` drive the proximity pips (CR.7 / ED F.2a row 7).
- **H.29 [L]** — GIVEN `P_lastSync=300, drainRate=1.5`, WHEN `OnOxygenRestored {P=450, drainRate=1.5, serverSendTime=T}` arrives, THEN `P_lastSync` re-anchors to 450 and subsequent D.1 dead-reckoning projects from 450, not 300.
- **H.30 [L]** — GIVEN the Beacon-Window overlay active, THEN the survival-window countdown renders as the figure (`FIGURE_OPACITY` + its idle animation) and oxygen/disturbance/threat render as ground (`GROUND_OPACITY`, no idle animation, data channel still present); GIVEN no overlay AND an active predator-lock, THEN the threat edge is the figure; GIVEN neither, THEN oxygen is the figure (CR.8 arbiter).
- **H.31 [L]** — GIVEN oxygen at Critical AND an active predator-lock, THEN the threat edge is the figure AND the oxygen bar still plays its dying-pulse throb as loud ground (CR.8 Critical-oxygen exception; oxygen not silenced).
- **H.32 [L]** — GIVEN a ground element (e.g. the disturbance bar) receiving its own transient (a band-crossing / spike), THEN that transient plays exactly once while the element remains ground (CR.8 ground-keeps-its-voice; causal chain preserved).
- **H.33 [L]** — GIVEN a figure-eligible state that flips faster than 0.75 s, THEN the figure holds for the 0.75 s minimum dwell before changing (CR.8 dwell; no figure-thrash).

> **Cross-system coverage:** H.1/H.20 (no-echo, no-position) verify the server-authority boundary; H.16/H.28 verify multi-producer integration; H.18b verifies the RunController arbitration seam. **Provisional/forward-pending:** H.15 (`survivalWindowDuration` source), H.17 (Camera GDD spectator), H.18b (RunController arbiter) — all reverse-cited in Open Questions.

## Open Questions

Each item has an owner and a target resolution point. None blocks the GDD's internal completeness — they are cross-GDD seams, deferred design forks, and sign-off items. Grouped by kind. **OQ.3 (Camera)** and **UI.OQ.1/UI.OQ.2** are referenced by id elsewhere in this document.

### A. Cross-GDD forward-obligations (a producer must honor these for the HUD's contracts to bind)

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ.1** | The single `RunEnded(outcome)` broadcaster + run-end input-lock arbiter is the **unauthored RunController** (PC F.4). The victory/defeat banner, the defeat-hold "no provisional banner" rule (H.18b), and the input-lock are **provisional** against PC's caller-side `RunEndConditionRaised`/`RunEnded` contract until it exists. | RunController GDD (unauthored) | Reverse-cite when RunController is authored |
| **OQ.2** | **`survivalWindowDuration` source + shape** — the D.7 upper-clamp and the beacon-countdown design need this value, pushed with `windowEndTimestamp` at BCT3. Is it a fixed scalar or variable (per squad-size/difficulty)? This also gates the beacon-tick escalation (OQ-Audio). | Crafting / RunController | Before HUD implementation; confirm against Crafting BCT3 |
| **OQ.4** | **`bearing` reference convention** (D.3) — the HUD assumes clockwise-from-north for `θ_screen`; confirm PA emits the same convention on `OnPredatorLockChanged`. | Predator AI | Quick confirm with PA (a one-line contract check) |
| **OQ.10** | **D.1 re-anchor payload** — `OnOxygenDeducted`/`OnOxygenRestored` must carry `{P, drainRate, serverSendTime}` so the dead-reckon re-anchors correctly (H.29). RM specifies these on `OnOxygenChanged`; confirm the deduct/restore variants carry them too. | Resource Management | Reverse-cite into RM (already APPROVED — a non-reopening contract note) |
| **OQ.11** *(security)* | **PA bearing quantization** — the HUD renders `bearing` single-frame and stores no time-series (H.20b, D.3), but sequential raw-degree bearings + own motion can triangulate the predator's world position over 3–5 s — a vector RR-4 (single-frame) does not close and the HUD **cannot** fully close (bearing is on-screen). Durable mitigation is PA emitting `bearing` **quantized to the chevron's angular sector** (not raw degrees). | Predator AI + security-engineer | Reverse-cite into PA as a security forward-obligation (a contract note; PA already APPROVED) |

### B. Deferred design forks (need a decision before the relevant asset/system is built)

| ID | Question | Standing recommendation | Owner | Target |
|---|---|---|---|---|
| **OQ.5** | **Diegetic world-space eye-shine** — should a supplementary world VFX (PointLight/particle) accompany the predator's Neon eye Parts (art-bible §5.2) at CONTACT range, alongside the HUD's screen-space treatment? | **No** (AD): the §5.2 Neon Parts *are* the diegetic eye-shine; a glow inside the lantern pool risks Principle 1, and a visible VFX only fires when the predator is seen — undercutting the HUD cue's "it's on you even when you can't see it" dread. | creative-director (tone) + technical-artist (feasibility) | Before predator VFX production |
| **OQ-Audio** | **Beacon-countdown tick escalation** — locked to **weight-not-rate** (constant 1s tick, gravity increases). Final lock depends on OQ.2 (`survivalWindowDuration` scalar vs variable). | Weight/volume escalation, steady rate (honors the "alarm only ever rises" calm-instrument rule) | audio-director | Confirm once OQ.2 resolves |

### C. Sign-off items (proposed values/conventions awaiting their authority)

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ.6** | **In-band warm hues needing AD exclusion-zone sign-off** (corrected arithmetic, VA.1/VA.3): **(a)** CONTACT cream `#FFF0C8` (hue ≈ 43.6° INSIDE the band, S ≈ 22% — passes only by the sat-gate) — now an **optional enhancement**, does NOT ship unless signed off; **the locked primary CONTACT treatment is the pure-UIStroke `4px→8px→4px` escalation** (no sign-off needed). **(b)** Warning meter `#FFD060` (hue ≈ 42° INSIDE the band, S ≈ 62% ABOVE the gate) — load-bearing (amber=warning convention), stays, but AD must **affirm the §4.5 disambiguation triad** (lighter value + fixed bottom-left meter position + meter-not-peripheral) covers an in-band, in-gate meter colour. | art-director | Art-bible approval / asset-spec pass |
| **OQ.7** | **World-response-swell audio ownership** — HUD-fired 2D non-diegetic UI sound vs. ambient-system-fired world audio (the HUD always renders the visual banner regardless). | audio-director + producer (cross-system) | Audio architecture pass |
| **OQ.8** | **Run-End audio-duck ownership** — ducking world audio (ambient/PA) under the run-end stinger is a SoundService group op the **HUD must not own**; assign to RunController or a dedicated AudioService. | technical-director / RunController | When RunController + audio architecture are authored |
| **OQ.9** | **Predator-lock YOU vs SQUAD stroke legibility** — 4px (YOU) vs 2px (SQUAD) is a 2-logical-pixel delta; verify it reads at render size on iPhone-SE before locking. | ux-designer + ui-programmer | Studio iPhone-SE preview, pre-implementation |

### D. Provisional dependency (unauthored system)

| ID | Question | Owner | Target |
|---|---|---|---|
| **OQ.3** | **Camera GDD (unauthored)** — the S4 Dead/Spectating macro-state and its spectator camera-feed (which character to follow, framing) are Camera-owned. The HUD's S4 overlay (respawn timer, roster, squad-ui emote) is a flat layer that renders over whatever the camera shows — *enhanced by* but not *blocked on* the Camera GDD (H.17 is marked PROVISIONAL). | Camera GDD (unauthored) | Reverse-cite when Camera GDD is authored |

### E. UI/UX open questions

| ID | Question | Owner | Target |
|---|---|---|---|
| **UI.OQ.1** | **Ultrawide bar-width cap** — at 21:9+, 40%-Scale bars exceed 1000px, breaking the equipment-readout register and fill-legibility. Proposed cap `min(0.40 × screenWidth, 600px)`. | ux-designer + ui-programmer | Before implementation |
| **UI.OQ.2** | **Lantern-toggle touch location (OQ.14 PC-side closure)** — the HUD closed its half of OQ.14 (one gather prompt, no HUD-rendered lantern toggle, UI.6). The remaining question — where on touch the lantern raises/lowers, and whether PC auto-raises on gather-arm — is PC-owned. | ux-designer + game-designer (PC GDD) | Alongside PC + Resource Node implementation |
