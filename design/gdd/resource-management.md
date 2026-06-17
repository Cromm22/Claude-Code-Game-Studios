# Resource Management

> **Status**: In Design
> **Author**: chrusht + claude-opus-4-8
> **Last Updated**: 2026-06-17
> **Implements Pillar**: Pillar 2 (The Squad Is the Experience — shared oxygen = shared fragility); serves Pillar 1 (the drain is the clock that forces loud play) + Pillar 4 (Rounds, Not Saves)

## Overview

Resource Management owns Terranova's single survival resource for the MVP: **oxygen**, held as one **squad-shared pool** rather than per-player bars. A server-authoritative tick drains the pool continuously across the run, and the squad replenishes it by gathering and converting resources into breathable oxygen — so the pool is the run's clock, counting down toward suffocation unless the squad keeps feeding it. Because the pool is shared, every member's survival is coupled to every other's: one player's death spends the squad's oxygen, and one player's wastefulness starves the rest. RM is **infrastructure** — it owns the pool's data model, the drain and replenish math, the death-cost deduction, and the server-authoritative contracts that Player Controller, Crafting, Resource Node, and the HUD all read or write — but its **player-facing effect** is the felt pressure of a shared bar ticking down: the reason the squad must keep gathering (loud, and therefore hunted) instead of hiding quietly forever. Without Resource Management there is no survival pressure, no reason to make the noise the predator hunts, and no shared stake binding the squad together — the game would be a quiet walk with no clock.

## Player Fantasy

**The Shared Breath.**

There is one bar, and it belongs to all of you. Not four bars — one. It has been falling since you landed, slowly, the way a held breath gives out, and right now it is dipping toward red while the four of you crouch in the dark deciding what to do about it. Nobody owns a private reserve to fall back on; nobody can hand their air to a friend or hoard it from one. The only things you can do about the falling bar are the two loud, dangerous things the game keeps asking of you: *consume less* — stay still, stay quiet, don't die — or *feed it* — go out into the open and gather, which the planet hears. So you watch the number together, and you feel it as a single shared stake: your survival is not yours, it is the squad's, and the squad is watching the same bar you are.

**The clock that forces noise.** Quiet would be safe if the bar held — but it doesn't. The drain is the reason hiding is never a winning move: stay silent long enough and you suffocate in the dark with nothing hunting you at all. So someone has to stand up. You watch a teammate break cover and walk toward a node, and you *hear* the gather carry across the map, and you know the thing that hunts noise just got a fix on where you are. That is the bargain Resource Management writes into every minute of the run: the only way to keep breathing is to make the noise that gets you found. Quiet is power — but the clock means quiet is never *enough*.

**Spending the dead.** And then, at the sharpest edge, a teammate goes down — and the bar lurches, because their death just cost the squad air, and bringing them back will cost more. The game refuses to soften the choice: spend the squad's breath on the revive, or leave them to spectate and keep what little you have. Either way, you all paid for it. No other survival game makes you budget your friends; this one does, with a single shared number everyone watches going down.

**Pillars served**
- **Pillar 2 — The Squad Is the Experience** *(primary)*: the shared pool is the most literal rendering of shared fragility — one resource, one fate; a death or a waste is everyone's loss.
- **Pillar 1 — Quiet Is Power**: the drain makes quiet *insufficient* — without it, hiding forever is optimal and the predator never matters. RM is why the squad must go loud.
- **Pillar 4 — Rounds, Not Saves**: within a run, oxygen spent is gone and a death's cost is permanent; the bar only goes one way unless you earn it back.

**What the player should feel** — that they are breathing on borrowed, shared air, and that every quiet minute is also a falling one. Not the power-fantasy of a full tank, but the intimacy and dread of a single number four people are keeping alive together — and the knowledge that the only way to keep it up is to risk being heard.

## Detailed Design

### Core Rules

**CR.1 — Pool data model.** Oxygen is a single server-side scalar `P`, owned exclusively by `ResourceService` (Knit Service, server-only), clamped to `[0, OXYGEN_POOL_START]`. It is **one undifferentiated squad-shared resource**: there are no per-player bars, no private reserves, and no mechanism to hoard, gift, or allocate oxygen between members. The only levers any player has are *consume-less* (stay alive, avoid the deaths that spend it) and *feed-more* (gather → craft → use Canisters). Clients receive a **read-only** projection only; they never predict or mutate `P`. Acceptable client display lag is ±0.5 units.

**CR.2 — Per-band drain schedule.** Drain is continuous and **ramps with the current escalation band (Beacon Charge Tier, BC1→BC4)**, flat within a band, and **independent of how many players are alive** (flat squad drain). Unit convention: `OXYGEN_DRAIN_BC1 = 1.0` unit/s *by definition* (1 oxygen unit = 1 second of BC1 drain).

| Band | Constant | Value (units/s) |
|---|---|---|
| BC1 (baseline) | `OXYGEN_DRAIN_BC1` | 1.0 |
| BC2 | `OXYGEN_DRAIN_BC2` | 1.5 |
| BC3 | `OXYGEN_DRAIN_BC3` | 2.2 |
| BC4 (Beacon survival window) | `OXYGEN_DRAIN_BC4_FLOOR` | 3.5 |

RM **reads** the current band from the escalation authority each tick; it owns no band state (see Interactions). BC4 is specifically the Beacon survival window, and `OXYGEN_DRAIN_BC4_FLOOR` is the value Crafting H.106 references.

**CR.3 — Per-tick drain application (60 Hz).** Every `RunService.Heartbeat` tick, server-side:
`P ← max(0, P − drainRate(band) × dt)`, where `dt` is the Heartbeat delta, max-guarded at `dt ≥ 0` (negative-`dt` guard, same clock-seam discipline as Crafting). `drainRate(band)` maps the current Beacon Charge Tier to the CR.2 table.

**CR.4 — Death-cost deduction.** On `RequestSquadOxygenSpend(amount, reason, deathEventId)` (server-internal Knit call, **never a RemoteEvent** — no client trust surface): for `reason = "death"`, deduct `amount × DEATH_OXYGEN_COST` (normally `amount = 1` ⇒ `DEATH_OXYGEN_COST = 72`), clamped at 0. **Idempotent** per `(userId, deathEventId)`: a duplicate `deathEventId` for the same player is a no-op. `DEATH_OXYGEN_COST` is RM-owned and satisfies DP-2 (`DEATH_OXYGEN_COST / OXYGEN_POOL_START ∈ [0.10, 0.15]`). The `(userId, deathEventId)` dedup set lives in RM's run-session state and is cleared at run end; `deathEventId` is PC-owned (the cross-service idempotency key).

**CR.5 — Respawn.** There is no separate respawn deduction — the CR.4 death cost is the entire cost of a death. PC owns the `RESPAWN_DELAY = 30 s` timer; RM owns only the pool math.

**CR.6 — Canister restore (the single faucet).** On `OnOxygenRestoreRequested(amount)` (fire-and-forget server-internal signal from Crafting's `RequestUseItem("OxygenCanister")`): `P ← min(OXYGEN_POOL_START, P + CANISTER_RESTORE_OXYGEN)`. **RM owns the restore math**: the event's `amount` parameter is audit/logging only and is *not* trusted for the calculation (prevents a compromised event from over-restoring). By construction `CANISTER_RESTORE_OXYGEN (10) < DEATH_OXYGEN_COST (72)` — a Canister can never refund a death. **This is the only oxygen faucet**: there is no passive regeneration and no direct gather-to-oxygen path. Gather nodes yield crafting materials; oxygen exists only after BIOMASS → Canister → use.

**CR.7 — Bounds.** Floor `P ≥ 0` (reaching 0 enters Empty, see States). Ceiling `P ≤ OXYGEN_POOL_START` (Canister restores clamp here; no overfill). Oxygen is never negative and never exceeds its starting value during a run.

**CR.8 — Anti-idle invariant (DEG-1).** Because the faucet is Canister-only, a squad that hides and does not gather restores **zero** oxygen while drain continues — net oxygen is strictly negative at every band. Hiding is therefore always a losing stall. Even optimal active play yields a *small* restore (CR.6), so the squad can slow the clock but not stop it: the pool trends down across the run and gathering only buys time.

**CR.9 — BC4-entry oxygen cap (shared-pool anti-bunker fence).** On the rising edge into BC4 (the Beacon survival window opening), RM applies a **one-time** clamp `P ← min(P, OXYGEN_BC4_ENTRY_CAP)` (candidate `OXYGEN_BC4_ENTRY_CAP = 15`). This is the shared-pool restatement of Crafting's per-member anti-bunker contract (F.2 / H.106): because the shared pool is large (600), a squad could otherwise enter BC4 healthy and **silently coast** the survival window without using Canisters (Canister use is loud via Crafting's in-window emission). Capping the pool at window-entry guarantees that a squad using **zero** Canisters runs out before the window ends (`15 / 3.5 ≈ 4.3 s < 35 s`), and that even a full Canister stack cannot fully cover it (D.5) — forcing continuous, loud Canister/gather use in the finale. The clamp fires once on the edge (idempotent; never re-applied while already BC4) and only ever *reduces* `P` (if `P < OXYGEN_BC4_ENTRY_CAP` at entry, no change). *(Narratively: the beacon's ignition thins the air. Notable new finale mechanic — flagged for CD/playtest validation, OQ.8.)*

### States and Transitions

The pool has one **squad-wide** state (not per-player). Thresholds use a 2-unit hysteresis on recovery to prevent `OnOxygenStateChanged` flapping near the boundary.

| State | Entry condition | Exits to | Server event on entry |
|---|---|---|---|
| **Healthy** | `P > OXYGEN_CRITICAL_THRESHOLD (35)` | → Critical when `P ≤ 35` | `OnOxygenStateChanged("Healthy")` (fires from Critical only when `P > 35 + 2`) |
| **Critical** | `0 < P ≤ 35` | → Healthy when `P > 37`; → Empty when `P = 0` | `OnOxygenStateChanged("Critical")` (HUD red-warning) |
| **Empty** | `P = 0` (after tick clamp) | → **Critical** (or Healthy) only if a Canister restore lands the same frame and lifts `P > 0` | `OnOxygenStateChanged("Empty")` → `OnPlayerOxygenExpired(playerId)` broadcast to all alive players |

**Empty → death cascade.** On entering Empty, RM fires `OnPlayerOxygenExpired` **once** (edge-triggered on entry, *not* every tick while `P = 0`) for every connected alive player (one squad-wide broadcast); PC consumes it and runs its oxygen-empty death path + grace timer (PC-owned). The pool stays at 0 and further drain ticks are no-ops. A Canister restore that arrives in the same server frame `P` reaches 0 is still applied (CR.6) — a last-moment refuel can pull the squad out of Empty before the death path resolves; a single Canister yields `P = 10`, so the squad re-enters **Critical** (not Healthy).

### Interactions with Other Systems

| System | Direction | Interface | Status |
|---|---|---|---|
| **Player Controller** | PC → RM | `RequestSquadOxygenSpend(amount=1, reason="death", deathEventId)` — server-internal Knit; RM dedups per `(userId, deathEventId)`, deducts `amount × DEATH_OXYGEN_COST` | **Confirmed** (PC approved) |
| | RM → PC | `OnPlayerOxygenExpired(playerId)` on Empty; PC reads `OXYGEN_POOL_START` at run start for its DP-2 config gate | **Confirmed** |
| **Crafting & Items** | Crafting → RM | `OnOxygenRestoreRequested(amount)` fire-and-forget on Canister use; RM owns restore math (ignores `amount`) | **Confirmed** (Crafting committed) |
| | RM → Crafting (read) | Crafting reads RM-owned `OXYGEN_DRAIN_BC4_FLOOR` + `CANISTER_RESTORE_OXYGEN` for its H.106 init assertion. **Reconciliation note:** H.106 is worded "per member"; RM is shared-pool — RM carries H.106's math reinterpreted for the shared pool, and a forward-obligation is logged to update H.106's wording on Crafting's next revision | **Forward-obligation** |
| **Resource Node** | — | None direct. Oxygen is reached only indirectly: nodes → materials → Crafting → Canister → `OnOxygenRestoreRequested` | n/a |
| **Ecological Disturbance / Beacon** | ED/Beacon → RM | RM reads the **current Beacon Charge Tier (BC1–BC4)** each tick via a server-internal accessor; RM owns no band state. BC4 = the Beacon survival window | **Forward-pending** — exact accessor + pre-Beacon band mapping must be confirmed with ED (Session B) + the Beacon charge model (see Open Questions) |
| **HUD** | RM → HUD | `OnOxygenChanged(amount)` delta-suppressed push (≥ 2 Hz, plus immediate on any state transition); `OnOxygenStateChanged(state)`. HUD reads `OXYGEN_POOL_START` + `OXYGEN_CRITICAL_THRESHOLD` for bar rendering | **Forward-pending** (HUD GDD unauthored) |

## Formulas

All math is in RM oxygen units (1 unit = 1 second of BC1 drain). Candidate constant values are shown here and listed as tunable in Tuning Knobs.

**D.1 — Continuous drain (per Heartbeat tick)**

`P_next = clamp(P − drainRate(BCT) × dt, 0, OXYGEN_POOL_START)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `P` | float | [0, 600] | Current shared pool |
| `drainRate(BCT)` | float | {1.0, 1.5, 2.2, 3.5} | Drain for current Beacon Charge Tier (CR.2) |
| `dt` | float | (0, ~0.0167] | Heartbeat delta, max-guarded `≥ 0` |
| `OXYGEN_POOL_START` | float | 600 (tunable) | Pool ceiling = run-start value |

**Output range:** [0, 600], clamped both ends. **Example:** `P = 400`, BC3, `dt = 1/60` → `400 − 2.2 × 0.01667 = 399.963`.

**D.2 — Canister restore (the single faucet)**

`P_next = clamp(P + CANISTER_RESTORE_OXYGEN, 0, OXYGEN_POOL_START)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `CANISTER_RESTORE_OXYGEN` | float | 10 (tunable, `< DEATH_OXYGEN_COST`) | Units restored per Canister use |

**Output range:** [0, 600]. **Example:** `P = 50` → `min(600, 50 + 10) = 60`.

**D.3 — Death deduction**

`P_next = clamp(P − amount × DEATH_OXYGEN_COST, 0, OXYGEN_POOL_START)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `amount` | int | ≥ 1 (normally 1) | Death-count multiplier from PC's spend call |
| `DEATH_OXYGEN_COST` | float | 72 (RM-owned, tunable within the DP-2 band) | Units per death |

**Output range:** [0, 600]. **Example:** `P = 300`, `amount = 1` → `300 − 72 = 228`.

**D.4 — DP-2 death-cost ratio invariant** *(config-validation, carried from PC H.87; asserted fail-fast at server init)*

`DEATH_OXYGEN_COST / OXYGEN_POOL_START ∈ [0.10, 0.15]`

**Evaluated:** `72 / 600 = 0.12` ✓. Plus the dependent invariant `CANISTER_RESTORE_OXYGEN < DEATH_OXYGEN_COST` → `10 < 72` ✓.

**D.5 — BC4 anti-bunker invariants** *(config-validation, carried from Crafting F.2/H.106 — restated in shared-pool terms using the CR.9 entry cap; both must hold at the 35 s window, fail-fast at init)*

Crafting's committed contract states two lines per member; under RM's shared pool they become, with the CR.9 entry cap as the bound on oxygen-at-window-entry:

- **(a) Over-supply** (a full Canister stack + the capped entry pool cannot cover the window):
  `OXYGEN_BC4_ENTRY_CAP + ITEM_STACK_MAX × CANISTER_RESTORE_OXYGEN < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR`
- **(b) Inverse / tank-the-damage** (a squad using zero Canisters hits empty before window-end):
  `OXYGEN_BC4_ENTRY_CAP < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR`

| Variable | Source | Value |
|---|---|---|
| `ITEM_STACK_MAX` | Crafting (owns) | 10 |
| `BEACON_SURVIVAL_WINDOW_min` | Crafting (owns) | 35 s |
| `OXYGEN_BC4_ENTRY_CAP` | RM (CR.9) | 15 |

**Evaluated:** (a) `15 + 10 × 10 = 115 < 35 × 3.5 = 122.5` ✓ (margin only 7.5 — sensitive to tuning, see Tuning Knobs); (b) `15 < 122.5` ✓. (a) is strictly stronger and implies (b). Both fences hold ⇒ neither stockpiling nor abstention lets the squad coast the BC4 window silently.

**D.6 — Net-oxygen rate / anti-idle (DEG-1)**

`dP/dt = restoreRate − drainRate(BCT)`, where `restoreRate = CANISTER_RESTORE_OXYGEN / canisterCycleTime` (and `restoreRate = 0` when the squad does not gather).

| Variable | Type | Range | Description |
|---|---|---|---|
| `canisterCycleTime` | float | ~10–14 s (RN-dependent — see note) | Best-case gather→craft→use cycle per Canister |
| `restoreRate` | float | 0 when hiding; ≈ 0.7–1.0 units/s at best play | Sustained faucet throughput |

**DEG-1 result:** hiding ⇒ `restoreRate = 0` ⇒ `dP/dt = −drainRate < 0` at **every** band — hiding is always net-negative. At best play `restoreRate ≲ 1.0 units/s`, so `dP/dt < 0` for all bands above BC1 — the squad can slow the clock but not stop it (the "always a countdown" decision). **Note:** `canisterCycleTime` depends on BIOMASS gather time, owned by the unauthored Resource Node GDD (provisional ~8 s/gather) — flagged as a forward dependency.

**Worked run example (the countdown):** a representative 600 s run at 180 s BC1 / 240 s BC2 / 120 s BC3 / 60 s BC4 drains `180·1.0 + 240·1.5 + 120·2.2 + 60·3.5 = 180 + 360 + 264 + 210 = 1014` units. Pool (600) plus Canister restores must cover the rest (~414 units ≈ 42 Canisters' worth) — the squad survives only by gathering continuously, and never by hiding.

## Edge Cases

- **If `P` reaches 0 (Empty):** RM fires `OnPlayerOxygenExpired` squad-wide; the pool holds at 0; subsequent drain ticks are no-ops. PC owns the resulting deaths.
- **If a Canister restore lands the same server frame `P` hits 0:** the restore is still applied (CR.6); if it lifts `P > 0` the squad exits Empty before PC's death path resolves — a legitimate last-moment save (a single Canister yields `P = 10` ⇒ the squad re-enters **Critical**, not Healthy).
- **If a Canister restore would push `P` above `OXYGEN_POOL_START`:** clamp at 600; the overflow is lost. Oxygen cannot be banked above the run-start value — there is no stockpiling *inside the pool* (only as un-used Canister items, which Crafting caps at `ITEM_STACK_MAX`).
- **If a duplicate death spend arrives (same `(userId, deathEventId)`):** no-op (idempotent, CR.4). Pathological replication double-fires cannot double-charge a death.
- **If a death spend arrives when `P ≤ DEATH_OXYGEN_COST`:** deduct and clamp at 0, which triggers the Empty cascade. A death can be the event that empties the pool.
- **If `dt ≤ 0` on a Heartbeat tick (clock step / NTP correction / VM migration):** the `max(0, …)` guard means that tick applies **no** drain and can **never** add oxygen. Drain only ever reduces `P`.
- **If the Beacon-Charge-Tier accessor is unavailable / `nil`** (ED/Beacon not yet initialized, or a transient read failure): RM defaults to **BC1 (slowest drain)** for that tick and logs — fail-safe; never stalls the pool and never over-drains on missing data. *(Forward-pending until the ED/Beacon accessor is finalized.)*
- **If the squad has no reachable bench or no BIOMASS** (the Canister-only consequence): the squad **cannot** replenish at all and the pool drains to 0 → loss. This is intended (the bench + materials are a survival dependency), but it imposes a **level-design constraint**: every map MUST guarantee reachable BIOMASS nodes and bench access, or the run is unwinnable by construction. *(Flagged to Resource Node + Level design.)*
- **If a player disconnects mid-run (`PlayerRemoving`, not a death):** **no** oxygen is charged (a disconnect is not `reason="death"`), and because drain is flat-headcount the rate is unchanged — the squad simply loses that player's gather contribution.
- **If a death and a Canister restore resolve in the same tick:** RM applies queued pool deltas in **arrival order**, clamping after each, then applies the once-per-tick drain. Order is deterministic; no delta is dropped.
- **If `amount ≤ 0` or non-integer in a death spend:** reject as a no-op (defensive validation, even on the server-internal path).
- **If the band rises to BC4 while `P > OXYGEN_BC4_ENTRY_CAP`:** `P` is clamped down to the cap **once** on the window-open edge (CR.9); if `P` is already at/below the cap, no change. The clamp never re-fires while the band stays BC4 and never *raises* `P`.
- **Degenerate strategies (scanned, all non-exploitable):** *suicide-to-respawn* loses 72 units + 30 s of gather capacity for zero benefit; *Canister stockpiling* can't trivialize BC4 (D.5 caps a full stack below the window drain, and the Beacon hold — not oxygen — is the win condition); *hoard-then-dump* is bounded by `MATERIAL_STACK_MAX` and the dead-player inventory lock; *2-player flat-drain* is strictly **harder** (same drain, half the gather bandwidth), not easier.

## Dependencies

| System | Direction / Type | Interface | Status |
|---|---|---|---|
| **Player Controller** | Bidirectional, **hard** | RM→PC `OnPlayerOxygenExpired(playerId)`; PC→RM `RequestSquadOxygenSpend(amount=1, reason="death", deathEventId)`; PC reads `OXYGEN_POOL_START` for its DP-2 config gate | **Confirmed** — PC approved; PC's F.2 RM row already reverse-cites |
| **Crafting & Items** | Bidirectional, **hard** | Crafting→RM `OnOxygenRestoreRequested(amount)` (the *only* faucet); RM exposes `OXYGEN_DRAIN_BC4_FLOOR` + `CANISTER_RESTORE_OXYGEN` for Crafting's H.106 init assertion. **Forward-obligation:** update H.106's "per member" wording to shared-pool on Crafting's next revision | **Confirmed** (Crafting committed) + 1 reconciliation obligation |
| **Ecological Disturbance / Beacon** | Upstream, **hard** | RM reads the current **Beacon Charge Tier (BC1–BC4)** each tick to select the drain rate; RM owns no band state. BC4 = Beacon survival window | **Forward-pending** — exact accessor + pre-Beacon band mapping (ED Session B + Beacon charge model). ED/Beacon must add an RM reverse-cite when authored |
| **Resource Node** | Upstream, **soft / indirect** | No direct interface. The faucet's throughput (`canisterCycleTime`, D.6) depends on RN's BIOMASS gather time (provisional ~8 s) | **Forward-pending** — RN unauthored; RN should register `BIOMASS_GATHER_TIME` and RM will cite it |
| **HUD** | Downstream, **hard for HUD** | RM→HUD `OnOxygenChanged(amount)` + `OnOxygenStateChanged(state)`; HUD reads `OXYGEN_POOL_START` + `OXYGEN_CRITICAL_THRESHOLD` | **Forward-pending** — HUD GDD unauthored; must consume these when authored |
| **Level design** | Downstream, **constraint** | Every map MUST guarantee reachable BIOMASS + bench, or the run is unwinnable (Edge Cases) | **Forward-pending** — flagged to Level design |

**Bidirectional consistency:** PC and Crafting already reference RM. ED/Beacon, Resource Node, HUD, and Level design carry forward-obligations to reverse-cite RM when they are authored — listed in Open Questions so they aren't lost.

## Tuning Knobs

| Knob | Default | Safe range | Too low | Too high | Coupling |
|---|---|---|---|---|---|
| `OXYGEN_POOL_START` | 600 | 300–900 | Run too short; deaths near-instantly fatal; DP-2 forces a tiny death cost | Countdown too forgiving; hiding less punished; run drags | **DP-2:** `DEATH_OXYGEN_COST` must stay 0.10–0.15× this |
| `OXYGEN_DRAIN_BC1` | 1.0 | **anchor — do not retune freely** | — | — | **Unit definition** (1 unit ≡ 1 s BC1). Changing it rescales every oxygen value |
| `OXYGEN_DRAIN_BC2` | 1.5 | 1.1–1.8 | BC2 indistinguishable from BC1 | Mid-run pressure spikes too early | Must keep `BC1 < BC2 < BC3 < BC4` |
| `OXYGEN_DRAIN_BC3` | 2.2 | 1.8–2.8 | Hunt phase doesn't bite | Squad can't keep pace before BC4 | monotonic band order |
| `OXYGEN_DRAIN_BC4_FLOOR` | 3.5 | 3.0–5.0 (a **floor**) | H.106 may break (a Canister stack could cover the window); BC4 stops feeling like a crisis | BC4 unsurvivable regardless of play | **H.106:** `10 × CANISTER_RESTORE_OXYGEN < 35 × this`; referenced by Crafting |
| `DEATH_OXYGEN_COST` | 72 | [0.10, 0.15] × pool = 60–90 | Deaths inconsequential; Pillar 2 (shared risk) weakens | First death near-fatal; death spiral brutal (no circuit-breaker) | **DP-2** with pool; must stay `> CANISTER_RESTORE_OXYGEN` |
| `CANISTER_RESTORE_OXYGEN` | 10 | 4–12 | Faucet useless; gathering not worth the noise | Violates H.106 / lets the faucet out-pace drain (breaks "always a countdown") | `< 3.5 × OXYGEN_DRAIN_BC4_FLOOR` **and** `< DEATH_OXYGEN_COST` |
| `OXYGEN_CRITICAL_THRESHOLD` | 35 | 20–60 | No warning window before Empty | Red-alert fatigue; HUD warns constantly | recovery hysteresis = +2 |
| `OXYGEN_BC4_ENTRY_CAP` | 15 | 5–25 | Finale instantly near-empty; punishing | BC4 anti-bunker fence (D.5) breaks — squad can silently coast the window | **D.5:** `CAP + 10 × CANISTER_RESTORE_OXYGEN < 35 × OXYGEN_DRAIN_BC4_FLOOR` (margin only 7.5 at defaults — fragile) |
| `OXYGEN_SYNC_HZ` | 2 | 1–5 | HUD bar lags / feels stale | Needless network traffic (delta-suppressed anyway) | client display tolerance ±0.5 units |

**Coupled-knob warnings (a balance pass must re-check all together):** (1) `DEATH_OXYGEN_COST ÷ OXYGEN_POOL_START ∈ [0.10, 0.15]`; (2) BC4 anti-bunker (D.5): `OXYGEN_BC4_ENTRY_CAP + 10 × CANISTER_RESTORE_OXYGEN < 35 × OXYGEN_DRAIN_BC4_FLOOR` **and** `OXYGEN_BC4_ENTRY_CAP < 35 × OXYGEN_DRAIN_BC4_FLOOR`; (3) `CANISTER_RESTORE_OXYGEN < DEATH_OXYGEN_COST`; (4) `OXYGEN_DRAIN_BC1 < BC2 < BC3 < BC4`. **Note:** the D.5(a) margin is only 7.5 units at defaults — raising `CANISTER_RESTORE_OXYGEN` or lowering `OXYGEN_DRAIN_BC4_FLOOR` can break it; consider raising `OXYGEN_DRAIN_BC4_FLOOR` (OQ.8) for headroom.

## Visual/Audio Requirements

- **Audio (the shared breath):** a low, continuous respirator/breathing ambient layer keyed to pool state, intensifying as `P` falls; on **Critical** entry a distinct squad-wide alarm/heartbeat cue. Per the game's anti-pillar, all oxygen audio uses **fixed UI/non-positional channels** — it must never be a diegetic positional sound the predator's noise model could read. Canister restore = a brief relief-intake cue; a death deduction = a sharp "lurch" sting tied to the bar. Continuous drain has no per-tick sound.
- **Visual:** the single shared bar is the literal rendering of shared fragility (see UI). Critical = red pulse; Empty hands off to PC's death visual; restore = a bar tick-up flash; death = a visible lurch-down.
- RM specifies the **state triggers**; the HUD and Audio GDDs own the actual asset specs and mix. *(Art/audio-director consult deferred — infrastructure; the bar's visual/sonic identity is a HUD + art-bible job.)*

## UI Requirements

- **The shared oxygen bar:** one, squad-shared, prominently placed; renders identically for every member (server-authoritative, ±0.5 display tolerance). Shows current value vs `OXYGEN_POOL_START`, a marked `OXYGEN_CRITICAL_THRESHOLD` line, and state color (Healthy / Critical / Empty).
- **Events to render:** `OnOxygenChanged` (smooth bar interpolation), `OnOxygenStateChanged` (color + alarm), the death lurch, and the restore tick-up.
- **Platform:** must scale via `UIScale` / aspect constraints, legible on iPhone-SE-class, no hover-only affordances (per technical preferences).

> **📌 UX Flag — Resource Management:** the shared oxygen bar is a HUD element. When the HUD GDD is authored, run `/ux-design` for the HUD before writing stories that touch the oxygen bar; stories should cite the HUD UX spec, not this GDD directly.

## Acceptance Criteria

Given-When-Then, independently verifiable. **Forward-pending** ACs are marked and must not be reported Done until their dependency exists. Totals: 40 ACs — 27 Logic / 9 Integration / 3 Security / 3 Config-Data.

**H.1** — GIVEN the server starts a new run, WHEN `ResourceService` initialises, THEN `P = 600` server-side and no client holds a write handle (read-only snapshot only). *(Integration)*

**H.2** — GIVEN BCT = BC1, WHEN one Heartbeat fires (dt=1/60), THEN `P` decreases by exactly `1.0 × dt`, clamped at 0. *(Logic; forward-pending: BCT accessor — stub-testable now)*

**H.3** — GIVEN BCT = BC2, WHEN one Heartbeat fires, THEN `P` decreases by `1.5 × dt`. *(Logic; forward-pending: BCT accessor)*

**H.4** — GIVEN BCT = BC3, WHEN one Heartbeat fires, THEN `P` decreases by `2.2 × dt`. *(Logic; forward-pending: BCT accessor)*

**H.5** — GIVEN BCT = BC4, WHEN one Heartbeat fires, THEN `P` decreases by `3.5 × dt` (`OXYGEN_DRAIN_BC4_FLOOR`). *(Logic; forward-pending: BCT accessor)*

**H.6** — GIVEN a run is active, WHEN a Heartbeat fires with `dt ≤ 0` (clock anomaly), THEN `P` is unchanged and no error is thrown. *(Logic)*

**H.7** — GIVEN `P = 0.005` at BC1, WHEN one Heartbeat fires (drain ≈ 0.0167), THEN `P` clamps to exactly 0 and `OnPlayerOxygenExpired` fires squad-wide that tick. *(Logic)*

**H.8** — GIVEN `P = 590`, WHEN a Canister restore fires, THEN `P = min(600, 590+10) = 600` (no overfill). *(Logic)*

**H.9** — GIVEN `P = 580`, WHEN a Canister restore fires, THEN `P = 590`. *(Logic)*

**H.10** — GIVEN `P = 40`, WHEN `RequestSquadOxygenSpend(amount=1, reason="death", deathEventId="evt-001")` fires, THEN `P = max(0, 40−72) = 0`. *(Logic)*

**H.11** — GIVEN `P = 300`, WHEN a death spend (`evt-002`) fires once, THEN `P = 228`. *(Logic)*

**H.12** — GIVEN `P = 228` and `(userId=12345, evt-002)` already applied, WHEN the same pair fires again, THEN `P` stays `228` (idempotent, no error). *(Logic)*

**H.13** — GIVEN `P = 228` and the same user dies under a new `evt-003`, WHEN the spend fires, THEN `P = 156` (new key applies). *(Logic)*

**H.14** — GIVEN a death cost was deducted, WHEN the player respawns after `RESPAWN_DELAY = 30 s`, THEN RM applies **no** additional cost (death cost is the whole cost). *(Integration)*

**H.15** — GIVEN `P = 40` (Healthy), WHEN drain takes `P` to `34.9`, THEN state → Critical and `OnOxygenStateChanged("Critical")` fires. *(Integration)*

**H.16** — GIVEN `P = 34` (Critical), WHEN a restore lifts `P` to `36`, THEN state stays **Critical** (recovery needs `P > 37`). *(Logic)*

**H.17** — GIVEN `P = 34` (Critical), WHEN restores lift `P` to `38`, THEN state → Healthy and `OnOxygenStateChanged("Healthy")` fires. *(Logic)*

**H.18** — GIVEN `P = 1` (Critical) at BC1, WHEN one Heartbeat drains `P` to 0, THEN state → Empty and `OnPlayerOxygenExpired` broadcasts squad-wide that tick. *(Integration)*

**H.19** — GIVEN `P = 0` (Empty) and a Canister restore fires the same tick, WHEN processed, THEN `P = 10`, Empty clears to **Critical** (10 ≤ 35), and `OnPlayerOxygenExpired` is **not** re-broadcast. *(Logic)*

**H.20** — GIVEN server `P = 300`, WHEN a client renders the bar, THEN the displayed value is within `±0.5` of the server `P` at last sync, delivered **within one sync interval** (`OXYGEN_SYNC_HZ = 2` ⇒ ≤ 0.5 s + network RTT); no client predicts/mutates `P`. *(Integration)*

**H.21** — GIVEN BCT changes BC2→BC3 mid-run, WHEN the next Heartbeat fires, THEN drain uses `2.2/s` (current BCT at tick time, not cached at run-start). *(Integration; forward-pending: BCT accessor)*

**H.22** — GIVEN `P = 600`, the squad hides (zero Canister use) at BC1, WHEN one second elapses, THEN `P` decreased by exactly `1.0` (net strictly negative — DEG-1 structural). *(Logic)*

**H.23** — GIVEN a single gatherer at maximum Canister throughput, WHEN compared against BC4 drain (`3.5/s`), THEN net oxygen is strictly negative. *(Logic; **forward-pending: blocked until Resource Node `canisterCycleTime` is authored** — do not mark Done before RN APPROVED)*

**H.24** — GIVEN a new run, WHEN `ResourceService` initialises, THEN it asserts `DEATH_OXYGEN_COST / OXYGEN_POOL_START = 0.12 ∈ [0.10, 0.15]` (fail-fast; run does not start on failure). *(Config-Data)*

**H.25** — GIVEN a new run, WHEN initialising, THEN it asserts `CANISTER_RESTORE_OXYGEN (10) < DEATH_OXYGEN_COST (72)` (fail-fast). *(Config-Data)*

**H.26** — GIVEN a new run, WHEN initialising, THEN it asserts both BC4 anti-bunker invariants (D.5): (a) `OXYGEN_BC4_ENTRY_CAP + ITEM_STACK_MAX × CANISTER_RESTORE_OXYGEN < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR` (`15+100 = 115 < 122.5`) AND (b) `OXYGEN_BC4_ENTRY_CAP < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR` (`15 < 122.5`); fail-fast. RM imports `ITEM_STACK_MAX` + window from Crafting. *(Config-Data; partial — Crafting owns two constants)*

**H.27** — GIVEN a client attempts to invoke `RequestSquadOxygenSpend` directly (RemoteEvent/Function/exploit), WHEN it reaches the server, THEN it is rejected/ignored and `P` is not mutated (no client-invoke path). *(Security)*

**H.28** — GIVEN a client attempts to fire a spoofed `OnOxygenRestoreRequested`, WHEN it reaches the server, THEN `P` is not restored (server-internal only). *(Security)*

**H.29** — GIVEN a client attempts to write `P` directly (shared module / mutable return), WHEN attempted, THEN server `P` is unchanged (`P` never passed by reference to client). *(Security)*

**H.30** — GIVEN `P = 600` (ceiling), WHEN a Canister restore fires, THEN `P` stays `600` (no-op, no error). *(Logic)*

**H.31** — GIVEN `P = 0` (floor), WHEN a Heartbeat drains at any band, THEN `P` stays `0` (no underflow). *(Logic)*

**H.32** — GIVEN `P = 35` exactly, WHEN state is evaluated, THEN it is **Critical** (Healthy requires strict `P > 35`). *(Logic)*

**H.33** — GIVEN `P = 37` exactly in Critical, WHEN re-evaluated after a restore, THEN state stays **Critical** (recovery requires strict `P > 37`). *(Logic)*

**H.34** — GIVEN a run with N connected clients, WHEN the `OXYGEN_SYNC_HZ` timer fires, THEN every connected client receives the current `P` within one sync interval (reconnected/late clients get it on their next sync). *(Integration)*

**H.35** — GIVEN `P = 36` (Critical) draining at BC1, WHEN drain pushes `P` below 35, THEN the Critical signal fires but `OnPlayerOxygenExpired` does **not** fire until `P = 0`. *(Logic)*

**H.36** — GIVEN `P = 0` and `OnPlayerOxygenExpired` already fired, WHEN further Heartbeats run, THEN it does **not** re-fire (one-shot per Empty transition). *(Logic)*

**H.37** — GIVEN two runs (1 player vs 4 players) both at BC2, WHEN one Heartbeat fires in each, THEN `P` decreases by exactly `1.5 × dt` in both (drain is flat-headcount). *(Logic)*

**H.38** — GIVEN `P = 400` and the band rises to BC4 (survival window opens), WHEN RM processes the rising edge, THEN `P` is clamped once to `OXYGEN_BC4_ENTRY_CAP = 15`; a subsequent BC4 tick does **not** re-clamp (idempotent on the edge). *(Logic; forward-pending: BCT/window-open accessor)*

**H.39** — GIVEN `P` capped to 15 at BC4 entry and the squad uses **zero** Canisters, WHEN BC4 drain (`3.5/s`) runs, THEN `P` reaches 0 in ≈ 4.3 s — before the 35 s minimum window — forcing Canister use to survive (the shared-pool anti-bunker fence, D.5b). *(Logic; forward-pending: BCT accessor)*

**H.40** — GIVEN `P = 10` (already below the cap) at BC4 entry, WHEN RM applies the CR.9 clamp, THEN `P` is unchanged (the clamp only ever reduces). *(Logic)*

## Open Questions

- **OQ.1 — BCT transition semantics** (qa GAP-1): when the band changes mid-run, the new rate applies on the first Heartbeat that observes the new BCT (rate read at tick start). Confirm this matches the ED/Beacon escalation model. *(Owner: systems-designer + ED author; when: ED Session B / Beacon model.)*
- **OQ.2 — Pre-Beacon band mapping** (qa GAP-8): which BCT applies before a Beacon exists? Provisional: BC1 baseline at run start, escalating with disturbance/charge. Confirm whether ED disturbance drives BC1–BC3 pre-Beacon or the band is purely Beacon-charge. *(Owner: ED + Crafting Beacon; when: ED Session B.)*
- **OQ.3 — Squad-size-aware ratio + death-spiral circuit-breaker** (= PC OQ.15): MVP is flat drain + no breaker (user-ruled). Revisit whether 2-player needs a squad-size-aware death cost or a last-stand floor. *(Owner: game-designer / CD; when: first playtest.)*
- **OQ.4 — 2-player BC4 viability**: a 2-player squad runs net-negative at BC4 even at best play (intended by flat drain). Validate the difficulty is intended, not punishing. *(Owner: game-designer; when: first playtest.)*
- **OQ.5 — Run-length / pool pacing**: `OXYGEN_POOL_START = 600` sets the countdown length; validate the "always a countdown" feel fits 5–20 min sessions. *(Owner: game-designer; when: `/prototype`.)*
- **OQ.6 — `CANISTER_RESTORE_OXYGEN` final value**: locked at 10 within H.106 headroom (< 12.25) and `< DEATH_OXYGEN_COST`; re-tune against RN `BIOMASS_GATHER_TIME` once authored. *(Owner: economy-designer; when: after RN.)*
- **OQ.7 — Reverse-cite / forward obligations** (so they aren't lost): **ED/Beacon** must expose the BCT accessor + reverse-cite RM; **Resource Node** must register `BIOMASS_GATHER_TIME` + carry the indirect materials→Canister chain; **HUD** must consume `OnOxygenChanged` + `OnOxygenStateChanged` and read `OXYGEN_POOL_START` / `OXYGEN_CRITICAL_THRESHOLD`; **Level design** must guarantee reachable bench + BIOMASS per map.
- **OQ.8 — Crafting F.2/H.106 reconciliation** (surfaced by `/consistency-check` 2026-06-17, **doc-integrity, RM-initiated**): (i) Crafting's F.2 binding contract (crafting-and-items.md line 938) states the over-supply inequality **with** an `oxygen_pool_start +` term and a separate inverse `oxygen_pool_start < 35 × OXYGEN_DRAIN_BC4_FLOOR`, while the **H.106 AC (line 2031) is a stale simplified restatement missing both** — an internal Crafting inconsistency; (ii) Crafting's contract is framed for **per-member oxygen**, but RM is **shared-pool** (user-ruled, supersedes). RM resolves both by restating the fence in shared-pool terms via the **CR.9 `OXYGEN_BC4_ENTRY_CAP`** as the bound on oxygen-at-window-entry (D.5). Crafting's next revision MUST: align H.106 (line 2031) with F.2 (line 938), and replace the per-member framing with the shared-pool / entry-cap form. *(Owner: Crafting GDD next revision + CD. Durable record: this OQ + the `/consistency-check` finding 2026-06-17.)*
- **OQ.9 — BC4-entry-cap mechanism validation**: `OXYGEN_BC4_ENTRY_CAP` (CR.9) is a **new finale mechanic** (the pool is clamped to ~15 when the survival window opens — a dramatic "air thins" spike that flattens pre-BC4 pool relevance). Validate the feel; the D.5(a) over-supply margin is only **7.5 units** at defaults (fragile) — consider raising `OXYGEN_DRAIN_BC4_FLOOR` (e.g. ~6–8) for headroom, which the systems-designer flagged needs a CD ruling on BC4 drain feel. *(Owner: CD + game-designer; when: first playtest / balance pass.)*
