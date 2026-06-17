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

**CR.1 — Pool data model.** Oxygen is a single server-side scalar `P`, owned exclusively by `ResourceService` (Knit Service, server-only), clamped to `[0, OXYGEN_POOL_START]`. It is **one undifferentiated squad-shared resource**: there are no per-player bars, no private reserves, and no mechanism to hoard, gift, or allocate oxygen between members. The only levers any player has are *consume-less* (stay alive, avoid the deaths that spend it) and *feed-more* (gather → craft → use Canisters). Clients receive a **read-only**, server-authoritative projection; they never hold a write handle to `P` and never mutate it. To keep the bar smooth under the high finale drain, the client **dead-reckons**: it renders `P_displayed = P_lastSync − drainRate_lastSync × timeSinceSync` (extrapolating downward at the last-synced band drain), snapping to the authoritative value on every sync. Display tolerance is therefore **±0.5 units of the dead-reckoned estimate**, *except* within one sync interval after an un-forecast discrete event (a Canister restore or a death deduction the client has not yet received), which resolves on the next sync. The sync payload carries both `P` **and** the current `drainRate` (band) so the client can dead-reckon (RBI-4 fix — at 8.0 u/s a naïve ±0.5 bound is unachievable between 2 Hz syncs: the bar would be up to 4 units stale).

**CR.2 — Per-band drain schedule.** Drain is continuous and **ramps with the current escalation band (Beacon Charge Tier, BC1→BC4)**, flat within a band, and **independent of how many players are alive** (flat squad drain). Unit convention: `OXYGEN_DRAIN_BC1 = 1.0` unit/s *by definition* (1 oxygen unit = 1 second of BC1 drain).

| Band | Constant | Value (units/s) |
|---|---|---|
| BC1 (baseline) | `OXYGEN_DRAIN_BC1` | 1.0 |
| BC2 | `OXYGEN_DRAIN_BC2` | 1.5 |
| BC3 | `OXYGEN_DRAIN_BC3` | 2.2 |
| BC4 (Beacon survival window) | `OXYGEN_DRAIN_BC4_FLOOR` | 8.0 |

RM **reads** the current band from the escalation authority each tick; it owns no band state (see Interactions). BC4 is specifically the Beacon survival window, and `OXYGEN_DRAIN_BC4_FLOOR` is the value Crafting H.106 references. **Round-2 change:** BC4 drain was raised 3.5 → 8.0 when the CR.9 BC4-entry oxygen cap was removed (user ruling, RBI-2) — the steep BC4 drain is now the **sole** shared-pool anti-bunker fence (a silent, zero-Canister squad survives the 35 s window only if it enters with ≥ 280 oxygen; see D.5). The `_FLOOR` suffix is historical: this is now a flat BC4 drain, tunable upward, not a floor beneath a removed cap.

**CR.3 — Per-tick drain application (60 Hz).** Every `RunService.Heartbeat` tick, server-side:
`P ← max(0, P − drainRate(band) × dt)`, where `dt` is the Heartbeat delta, max-guarded at `dt ≥ 0` (negative-`dt` guard, same clock-seam discipline as Crafting). `drainRate(band)` maps the current Beacon Charge Tier to the CR.2 table.

**CR.4 — Death-cost deduction.** On `RequestSquadOxygenSpend(amount, reason, deathEventId)` (server-internal Knit call, **never a RemoteEvent** — no client trust surface): for `reason = "death"`, deduct `amount × DEATH_OXYGEN_COST` (normally `amount = 1` ⇒ `DEATH_OXYGEN_COST = 72`), clamped at 0. **Idempotent** per `(userId, deathEventId)`: a duplicate `deathEventId` for the same player is a no-op. `DEATH_OXYGEN_COST` is RM-owned and satisfies DP-2 (`DEATH_OXYGEN_COST / OXYGEN_POOL_START ∈ [0.10, 0.15]`). The `(userId, deathEventId)` dedup set lives in RM's run-session state and is cleared at run end; `deathEventId` is PC-owned (the cross-service idempotency key).

**CR.5 — Respawn.** There is no separate respawn deduction — the CR.4 death cost is the entire cost of a death. PC owns the `RESPAWN_DELAY = 30 s` timer; RM owns only the pool math.

**CR.6 — Canister restore (the single faucet).** On `OnOxygenPulseRequest(amount, requestingPlayerId)` (fire-and-forget server-internal Knit **`Signal`** — not a `RemoteSignal`, no client trust surface — from Crafting's `RequestUseItem("OxygenCanister")`): `P ← min(OXYGEN_POOL_START, P + CANISTER_RESTORE_OXYGEN)`. **RM conforms to Crafting's published signature** (the caller owns the contract, per the round-1 CD ruling). **RM owns the restore math**: *both* the `amount` and `requestingPlayerId` parameters are audit/logging only and are *not* trusted for the calculation — RM always restores its own `CANISTER_RESTORE_OXYGEN` constant (prevents a compromised or spoofed event from over-restoring). *(Forward-pending reconciliation, RBI-1: Crafting is internally inconsistent — it publishes `OnOxygenPulseRequest` at crafting-and-items.md:364 + 4 sites but names it `OnOxygenRestoreRequested` once at line 938. RM tracks the published-majority name `OnOxygenPulseRequest`; Crafting's next revision must converge on the single name.)* By construction `CANISTER_RESTORE_OXYGEN (10) < DEATH_OXYGEN_COST (72)` — a Canister can never refund a death. **This is the only oxygen faucet**: there is no passive regeneration and no direct gather-to-oxygen path. Gather nodes yield crafting materials; oxygen exists only after BIOMASS → Canister → use.

**CR.7 — Bounds.** Floor `P ≥ 0` (reaching 0 enters Empty, see States). Ceiling `P ≤ OXYGEN_POOL_START` (Canister restores clamp here; no overfill). Oxygen is never negative and never exceeds its starting value during a run.

**CR.8 — Anti-idle invariant (DEG-1).** Because the faucet is Canister-only, a squad that hides and does not gather restores **zero** oxygen while drain continues — net oxygen is strictly negative at **every** band. Hiding is therefore always a losing stall. Active play replenishes through a **bench-bottlenecked** faucet (Crafting caps concurrent crafting at `CRAFT_CONCURRENCY_CAP = 2` for a full squad — gathering parallelizes across all members, but turning BIOMASS into Canisters does not), so squad throughput is bounded well below the top-band drains: the squad can sustain or slightly grow the pool at the low bands (BC1/BC2) **only by committing the whole squad to loud gathering**, but at BC3 and especially BC4 even maximum throughput is net-negative. The run therefore always trends toward a forced, loud finale — quiet never sustains the pool at any band, and no amount of gathering stops the clock once escalation reaches the top bands (full derivation in D.6).

*(Round-2: CR.9 — the BC4-entry oxygen cap / `OXYGEN_BC4_ENTRY_CAP` — was **removed** per the round-1 user ruling (RBI-2). It was an anti-competence silent clamp (better play → bigger confiscation) with an undefined idempotency edge and a one-frame bar-crater that read as a bug. The shared-pool anti-bunker fence is now carried entirely by the raised BC4 drain (CR.2, 8.0 u/s) — see D.5.)*

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
| **Crafting & Items** | Crafting → RM | `OnOxygenPulseRequest(amount, requestingPlayerId)` fire-and-forget (Knit `Signal`) on Canister use; RM conforms to Crafting's published signature and owns the restore math (ignores both params) | **Forward-pending** (RBI-1) — RM conforms to the published-majority name; Crafting is internally inconsistent (`OnOxygenRestoreRequested` once at line 938) and must converge on its next revision |
| | RM → Crafting (read) | Crafting reads RM-owned `OXYGEN_DRAIN_BC4_FLOOR` (now 8.0) + `CANISTER_RESTORE_OXYGEN` for its H.106 init assertion. **Reconciliation note:** H.106 is worded "per member"; RM is shared-pool — RM carries the anti-bunker fence reinterpreted for the shared pool via the raised BC4 drain (D.5; the CR.9 entry cap was removed), and a forward-obligation is logged to update H.106's wording on Crafting's next revision | **Forward-obligation** |
| **Resource Node** | — | None direct. Oxygen is reached only indirectly: nodes → materials → Crafting → Canister → `OnOxygenPulseRequest` | n/a |
| **Ecological Disturbance / Beacon** | ED/Beacon → RM | RM reads the **current Beacon Charge Tier (BC1–BC4)** each tick via a server-internal accessor; RM owns no band state. BC4 = the Beacon survival window | **Forward-pending** — exact accessor + pre-Beacon band mapping must be confirmed with ED (Session B) + the Beacon charge model (see Open Questions) |
| **HUD** | RM → HUD | Continuous: `OnOxygenChanged(amount, drainRate)` delta-suppressed push (≥ 2 Hz, plus immediate on any state transition; carries `drainRate` for client dead-reckoning); `OnOxygenStateChanged(state)`. **Distinct semantic events (RBI-5)** so the HUD can give each beat its own WCAG-safe treatment: `OnOxygenRestored(amount, source)` (Canister tick-up flash), `OnOxygenDeducted(amount, reason, simultaneousCount)` (death lurch-down; `simultaneousCount` lets the HUD coalesce N same-tick deductions into one cue, RBI-6). HUD reads `OXYGEN_POOL_START` + `OXYGEN_CRITICAL_THRESHOLD` for bar rendering | **Forward-pending** (HUD GDD unauthored) |

## Formulas

All math is in RM oxygen units (1 unit = 1 second of BC1 drain). Candidate constant values are shown here and listed as tunable in Tuning Knobs.

**D.1 — Continuous drain (per Heartbeat tick)**

`P_next = clamp(P − drainRate(BCT) × dt, 0, OXYGEN_POOL_START)`

| Variable | Type | Range | Description |
|---|---|---|---|
| `P` | float | [0, 600] | Current shared pool |
| `drainRate(BCT)` | float | {1.0, 1.5, 2.2, 8.0} | Drain for current Beacon Charge Tier (CR.2) |
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

**D.5 — BC4 anti-bunker fence** *(restated in shared-pool terms — the CR.9 entry cap was removed, RBI-2; the raised BC4 drain is now the sole fence)*

With CR.9 gone, the bound on oxygen-at-window-entry is no longer a fixed cap — it is whatever pool the squad carries in, which the countdown backbone (D.6) drives down over the run. The fence is now two properties of the BC4 drain:

- **(a) Over-supply — HARD init assertion** (a full Canister stack, by itself, cannot cover the window's drain):
  `ITEM_STACK_MAX × CANISTER_RESTORE_OXYGEN < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR`
- **(b) Always-a-countdown at the finale** (sustained squad faucet throughput is strictly below BC4 drain — *partly forward-pending on RN's `canisterCycleTime`*):
  `CRAFT_CONCURRENCY_CAP × CANISTER_RESTORE_OXYGEN / canisterCycleTime < OXYGEN_DRAIN_BC4_FLOOR`

| Variable | Source | Value |
|---|---|---|
| `ITEM_STACK_MAX` | Crafting (owns) | 10 |
| `BEACON_SURVIVAL_WINDOW_min` | Crafting (owns) | 35 s |
| `CRAFT_CONCURRENCY_CAP` | Crafting (owns, = `min(2, ceil(squad/2))`) | 2 (full squad) |
| `OXYGEN_DRAIN_BC4_FLOOR` | RM | 8.0 |

**Evaluated:** (a) `10 × 10 = 100 < 35 × 8.0 = 280` ✓ (margin 180 — far healthier than the old CR.9 7.5). (b) `2 × 10 / ~12 ≈ 1.67 < 8.0` ✓ (holds for any plausible `canisterCycleTime ≥ 2.5 s`).

**Coast threshold (the residual the user accepted by removing CR.9):** a **silent**, zero-Canister squad survives the 35 s window iff it enters with `P ≥ BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR = 280`. With **active** play (squad restore ≈ 1.67 u/s) the break-even entry pool is `35 × (8.0 − 1.67) ≈ 222`. So the fence is honest, not absolute: a squad arriving at BC4 above ~280 oxygen *can* coast silently — but the countdown (D.6) makes a pool that high at the finale implausible, and the ~58-unit gap between the silent (280) and loud (222) thresholds is the concrete reward for going loud. Validated at playtest (OQ.9).

**D.6 — Net-oxygen rate / anti-idle (DEG-1), squad-total** *(RBI-3 — restated as an explicit squad-total invariant; the round-1 form mis-treated a per-gatherer rate as squad-total)*

`dP/dt = restoreRate_squad − drainRate(BCT)`, where
`restoreRate_squad = min(N_gatherers, CRAFT_CONCURRENCY_CAP) × CANISTER_RESTORE_OXYGEN / canisterCycleTime` (and `= 0` when the squad does not gather).

| Variable | Type | Range | Description |
|---|---|---|---|
| `N_gatherers` | int | 1–4 | Squad members actively running the gather→craft→use loop |
| `CRAFT_CONCURRENCY_CAP` | int | 2 (full squad; `= min(2, ceil(squad/2))`, Crafting-owned) | Concurrent-crafting bottleneck — gathering parallelizes, Canister crafting does not |
| `canisterCycleTime` | float | ~10–14 s (RN-dependent — see note) | Best-case gather→craft→use cycle per Canister |
| `restoreRate_squad` | float | 0 hiding; ≈ 1.5–1.7 units/s at full loud play | Bench-bottlenecked sustained faucet throughput |

**Why the cap is the backbone (RBI-3 fix):** the round-1 doc treated `restoreRate ≈ 0.7–1.0 u/s` as squad-total; in fact it is *per-gatherer*, and four independent gatherers (≈ 3.3 u/s) would out-pace BC3's 2.2 → a net-positive pool, breaking "always a countdown." The real ceiling is Crafting's **concurrent-crafting cap of 2** for a full squad: no matter how many members gather, only two Canisters are produced at a time, so `restoreRate_squad ≈ 2 × (10 / ~12) ≈ 1.67 u/s`.

**DEG-1 result (band-by-band, full loud play):**
- **Hiding:** `restoreRate_squad = 0` ⇒ `dP/dt = −drainRate < 0` at **every** band — hiding is always net-negative (rock-solid).
- **BC1 (1.0):** `dP/dt ≈ +0.67` — the squad *can* grow the pool, but only by committing everyone to loud gathering (Pillar 1 pressure: maximally hunted).
- **BC2 (1.5):** `dP/dt ≈ +0.17` — roughly sustainable, still loud.
- **BC3 (2.2):** `dP/dt ≈ −0.53` — net-negative; throughput can no longer keep pace.
- **BC4 (8.0):** `dP/dt ≈ −6.33` — steeply net-negative; the finale is a hard clock no faucet can hold.

**Restated invariant:** the run **always trends toward a forced, loud finale**. A squad may sustain or slightly grow the pool at the low bands *only by being maximally loud*, and once escalation reaches BC3/BC4 no throughput stops the clock. Quiet never sustains the pool at any band.

**BIOMASS allocation tension (IMPORTANT, folded in):** `restoreRate_squad` is an *upper bound* — in practice the squad must also divert BIOMASS to **Beacon materials** (Crafting's win-condition), so real sustained restore is lower than 1.67 u/s. Canisters-for-survival vs Beacon-materials-for-winning is a live strategic tension that makes the countdown bite harder than the raw faucet math implies.

**Note:** `canisterCycleTime` depends on BIOMASS gather time, owned by the unauthored Resource Node GDD (provisional ~8 s/gather) — forward dependency. **Soft constraint on RN/Level (forward-pending):** keep `canisterCycleTime` long enough that `CRAFT_CONCURRENCY_CAP × CANISTER_RESTORE_OXYGEN / canisterCycleTime` leaves BC1 only *marginally* positive (a too-fast cycle lets the squad bank oxygen trivially at low bands). At `canisterCycleTime ≈ 12 s` this holds; RN must re-validate once `BIOMASS_GATHER_TIME` is authored.

**Worked run example (the countdown):** a representative 600 s run at 180 s BC1 / 240 s BC2 / 120 s BC3 / 60 s BC4 drains `180·1.0 + 240·1.5 + 120·2.2 + 60·8.0 = 180 + 360 + 264 + 480 = 1284` units. Pool (600) plus Canister restores must cover the rest (~684 units ≈ 68 Canisters' worth) — the squad survives only by gathering continuously, and never by hiding. The BC4 portion alone (480 units over 60 s) shows why the finale is a hard clock.

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
- **If a death and a Canister restore resolve in the same tick:** RM applies queued discrete deltas in a **fixed deterministic order** — (1) all death deductions, (2) all Canister restores, (3) the once-per-tick continuous drain — clamping to `[0, OXYGEN_POOL_START]` after each step. The Empty state and the `OnPlayerOxygenExpired` cascade are evaluated on the **final** `P` after all three steps, so a same-tick restore that lifts `P > 0` legitimately prevents the cascade (the "last-moment save" edge). This replaces the round-1 "arrival order" wording, which was network-arrival-dependent and therefore non-deterministic (RBI-5). No delta is dropped.
- **If `amount ≤ 0` or non-integer in a death spend:** reject as a no-op (defensive validation, even on the server-internal path).
- **If the band rises to BC4 (survival window opens):** RM does **nothing special to `P`** — the CR.9 entry clamp was removed (RBI-2). The squad simply meets the much steeper BC4 drain (8.0 u/s) from whatever pool the run left them; the steep drain is the anti-bunker fence (D.5).
- **If a 2-player squad takes a BC4 death (honest worst-case framing, IMPORTANT):** the death costs 72 oxygen, and with only one gatherer left the squad's `restoreRate_squad` halves (the bench cap no longer binds — 1 crafter ≈ 0.83 u/s) while BC4 drain stays flat at 8.0 (headcount-independent, OQ.3). Net ≈ −7.2 u/s after a death: a 2-player squad that takes even one BC4 death is, in practice, **near-unrecoverable** within the window. This is intended under the flat-drain ruling (OQ.3/OQ.4), **not** a bug — the deferred lever, if playtests show it is too brutal, is a squad-size-aware death cost **or** a last-stand oxygen floor, triggered when `aliveCount ≤ 2` (named here so it is not lost; owner game-designer/CD, OQ.3).
- **Degenerate strategies (scanned, all non-exploitable):** *suicide-to-respawn* loses 72 units + 30 s of gather capacity for zero benefit; *Canister stockpiling* can't trivialize BC4 (D.5(a): a full stack of 100 units < the 280 the window drains, and the Beacon hold — not oxygen — is the win condition); *hoard-then-dump* is bounded by `ITEM_STACK_MAX` and the dead-player inventory lock; *coast-on-a-fat-pool* is bounded by the coast threshold (D.5: needs ≥ 280 oxygen at BC4 entry, which the countdown makes implausible); *2-player flat-drain* is strictly **harder** (same drain, half the gather bandwidth), not easier.

## Dependencies

| System | Direction / Type | Interface | Status |
|---|---|---|---|
| **Player Controller** | Bidirectional, **hard** | RM→PC `OnPlayerOxygenExpired(playerId)`; PC→RM `RequestSquadOxygenSpend(amount=1, reason="death", deathEventId)`; PC reads `OXYGEN_POOL_START` for its DP-2 config gate | **Confirmed** — PC approved; PC's F.2 RM row already reverse-cites |
| **Crafting & Items** | Bidirectional, **hard** | Crafting→RM `OnOxygenPulseRequest(amount, requestingPlayerId)` (Knit `Signal`; the *only* faucet); RM exposes `OXYGEN_DRAIN_BC4_FLOOR` (now 8.0) + `CANISTER_RESTORE_OXYGEN` for Crafting's H.106 init assertion. **Two reconciliation obligations on Crafting's next revision:** (1) converge on the single faucet name `OnOxygenPulseRequest` (line 938 stale, RBI-1); (2) update H.106's "per member" wording to the shared-pool / raised-BC4-drain form (CR.9 entry cap removed) | **Forward-pending** (RBI-1) + 2 reconciliation obligations |
| **Ecological Disturbance / Beacon** | Upstream, **hard** | RM reads the current **Beacon Charge Tier (BC1–BC4)** each tick to select the drain rate; RM owns no band state. BC4 = Beacon survival window | **Forward-pending** — exact accessor + pre-Beacon band mapping (ED Session B + Beacon charge model). ED/Beacon must add an RM reverse-cite when authored |
| **Resource Node** | Upstream, **soft / indirect** | No direct interface. The faucet's throughput (`canisterCycleTime`, D.6) depends on RN's BIOMASS gather time (provisional ~8 s) | **Forward-pending** — RN unauthored; RN should register `BIOMASS_GATHER_TIME` and RM will cite it |
| **HUD** | Downstream, **hard for HUD** | RM→HUD `OnOxygenChanged(amount, drainRate)` + `OnOxygenStateChanged(state)` + the semantic events `OnOxygenRestored(amount, source)` / `OnOxygenDeducted(amount, reason, simultaneousCount)`; HUD reads `OXYGEN_POOL_START` + `OXYGEN_CRITICAL_THRESHOLD` | **Forward-pending** — HUD GDD unauthored; must consume these when authored |
| **Level design** | Downstream, **constraint** | Every map MUST guarantee reachable BIOMASS + bench, or the run is unwinnable (Edge Cases) | **Forward-pending** — flagged to Level design |

**Bidirectional consistency:** PC and Crafting already reference RM. ED/Beacon, Resource Node, HUD, and Level design carry forward-obligations to reverse-cite RM when they are authored — listed in Open Questions so they aren't lost.

## Tuning Knobs

| Knob | Default | Safe range | Too low | Too high | Coupling |
|---|---|---|---|---|---|
| `OXYGEN_POOL_START` | 600 | 300–900 | Run too short; deaths near-instantly fatal; DP-2 forces a tiny death cost | Countdown too forgiving; hiding less punished; run drags | **DP-2:** `DEATH_OXYGEN_COST` must stay 0.10–0.15× this |
| `OXYGEN_DRAIN_BC1` | 1.0 | **anchor — do not retune freely** | — | — | **Unit definition** (1 unit ≡ 1 s BC1). Changing it rescales every oxygen value |
| `OXYGEN_DRAIN_BC2` | 1.5 | 1.1–1.8 | BC2 indistinguishable from BC1 | Mid-run pressure spikes too early | Must keep `BC1 < BC2 < BC3 < BC4` |
| `OXYGEN_DRAIN_BC3` | 2.2 | 1.8–2.8 | Hunt phase doesn't bite | Squad can't keep pace before BC4 | monotonic band order |
| `OXYGEN_DRAIN_BC4_FLOOR` | 8.0 | 5.0–12.0 | Coast threshold rises (silent squads survive the window on a mid pool); D.5(a) margin shrinks; BC4 stops feeling like a crisis | Oxygen-death overshadows the predator as the dominant finale failure (the ~17 u/s "burn full 600 in 35 s" ceiling is the hard cap) | **D.5(a):** `10 × CANISTER_RESTORE_OXYGEN < 35 × this`; sets coast threshold = `35 × this`; referenced by Crafting H.106 |
| `DEATH_OXYGEN_COST` | 72 | [0.10, 0.15] × pool = 60–90 | Deaths inconsequential; Pillar 2 (shared risk) weakens | First death near-fatal; death spiral brutal (no circuit-breaker — see OQ.3) | **DP-2** with pool; must stay `> CANISTER_RESTORE_OXYGEN` |
| `CANISTER_RESTORE_OXYGEN` | 10 | 6–14 | Faucet useless; gathering not worth the noise | Violates D.5(a) (`> 28` lets a full stack cover the window) / lets the faucet approach drain (weakens "always a countdown") | `< 35 × OXYGEN_DRAIN_BC4_FLOOR ÷ ITEM_STACK_MAX (= 28)` **and** `< DEATH_OXYGEN_COST` |
| `OXYGEN_CRITICAL_THRESHOLD` | 35 | 20–60 | No warning window before Empty | Red-alert fatigue; HUD warns constantly | recovery hysteresis = +2 |
| `OXYGEN_SYNC_HZ` | 2 | 1–5 | HUD bar lags between dead-reckon corrections | Needless network traffic (delta-suppressed anyway) | client **dead-reckons** between syncs (CR.1); tolerance ±0.5 of the estimate |

**Coupled-knob warnings (a balance pass must re-check all together):** (1) `DEATH_OXYGEN_COST ÷ OXYGEN_POOL_START ∈ [0.10, 0.15]`; (2) BC4 over-supply fence (D.5a): `ITEM_STACK_MAX × CANISTER_RESTORE_OXYGEN < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR` (`100 < 280`, margin 180); (3) `CANISTER_RESTORE_OXYGEN < DEATH_OXYGEN_COST`; (4) `OXYGEN_DRAIN_BC1 < BC2 < BC3 < BC4`; (5) coast threshold `= BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR` (`280` at defaults) — the silent-survival entry pool, a *feel* dial validated at playtest (OQ.9). **Note (RBI-4 resolved):** every safe range above is re-derived against these couplings — there are no longer any safe-range values that overlap a startup-crash zone (the old `OXYGEN_BC4_ENTRY_CAP` knob and its fragile 7.5-unit margin are gone with CR.9).

## Visual/Audio Requirements

- **Audio (the shared breath):** a low, continuous respirator/breathing ambient layer keyed to pool state, intensifying as `P` falls; on **Critical** entry a distinct squad-wide alarm/heartbeat cue. Per the game's anti-pillar, all oxygen audio uses **fixed UI/non-positional channels** — it must never be a diegetic positional sound the predator's noise model could read. Canister restore = a brief relief-intake cue; a death deduction = a sharp "lurch" sting tied to the bar. Continuous drain has no per-tick sound.
- **Visual:** the single shared bar is the literal rendering of shared fragility (see UI). Critical = red pulse; Empty hands off to PC's death visual; restore = a bar tick-up flash; death = a visible lurch-down.
- **Accessibility floor (RBI-6 — the game-concept's own floor, BLOCKING for the HUD that consumes these triggers):**
  - **Critical state must not rely on red alone** — the red pulse requires a redundant **shape/icon** channel (e.g. a warning glyph + a text/numeric state label) so colorblind players read the crisis.
  - **The pulse must obey WCAG 2.3.1** — no more than **3 flashes per second**; the "red pulse" cadence is capped accordingly (RM caps the *trigger* rate it can emit; the HUD enforces the visual bound).
  - **The principal pre-death warning must not be audio-only** — the alarm/heartbeat cue requires a **visual redundancy** (the Critical state's own visual treatment) so deaf/HoH players are not denied the warning.
  - **Coalescing rule:** when N death deductions or restores resolve in the same tick, RM emits the semantic event **once** with `simultaneousCount = N` (UI/Dependencies); the HUD renders **one** coalesced cue, never N stacked flashes (prevents a 4-simultaneous-death strobe).
- RM specifies the **state triggers and the distinct semantic events** (drain vs death-lurch vs canister-restore — RBI-5); the HUD and Audio GDDs own the actual asset specs, the WCAG-bounded animation, and the mix. *(Art/audio-director consult deferred — infrastructure; the bar's visual/sonic identity is a HUD + art-bible job.)*

## UI Requirements

- **The shared oxygen bar:** one, squad-shared, prominently placed; renders identically for every member (server-authoritative; client **dead-reckons** between syncs per CR.1, ±0.5 of the estimate). Shows current value vs `OXYGEN_POOL_START`, a marked `OXYGEN_CRITICAL_THRESHOLD` line, and state color (Healthy / Critical / Empty).
- **Events to render (distinct, RBI-5):** `OnOxygenChanged(amount, drainRate)` (smooth bar via client dead-reckoning, CR.1), `OnOxygenStateChanged` (color + alarm + redundant shape/icon, RBI-6), `OnOxygenDeducted(amount, reason, simultaneousCount)` (the death lurch-down, coalesced), and `OnOxygenRestored(amount, source)` (the Canister tick-up). The HUD must give each its own treatment — a drain tick, a death lurch, and a restore flash must be visually distinguishable.
- **Platform:** must scale via `UIScale` / aspect constraints, legible on iPhone-SE-class, no hover-only affordances (per technical preferences).

> **📌 UX Flag — Resource Management:** the shared oxygen bar is a HUD element. When the HUD GDD is authored, run `/ux-design` for the HUD before writing stories that touch the oxygen bar; stories should cite the HUD UX spec, not this GDD directly.

## Acceptance Criteria

Given-When-Then, independently verifiable. **Forward-pending** ACs are marked and must not be reported Done until their dependency exists. Totals: **46 live ACs — 31 Logic / 8 Integration / 4 Security / 3 Config-Data** (round-2: H.38–H.40 retired in place, numbers not reused; H.41–H.49 added).

**H.1** — GIVEN the server starts a new run, WHEN `ResourceService` initialises, THEN `P == 600` server-side, AND `ResourceService.Client` exposes **no** method or `RemoteProperty` that writes `P` (the client gets a read-only projection only) — verified by introspecting the service's client surface for any `P`-mutating member (mirrors Crafting H.24). *(Integration)*

**H.2** — GIVEN BCT = BC1, WHEN one Heartbeat fires (dt=1/60), THEN `P` decreases by exactly `1.0 × dt`, clamped at 0. *(Logic; forward-pending: BCT accessor — stub-testable now)*

**H.3** — GIVEN BCT = BC2, WHEN one Heartbeat fires, THEN `P` decreases by `1.5 × dt`. *(Logic; forward-pending: BCT accessor)*

**H.4** — GIVEN BCT = BC3, WHEN one Heartbeat fires, THEN `P` decreases by `2.2 × dt`. *(Logic; forward-pending: BCT accessor)*

**H.5** — GIVEN BCT = BC4, WHEN one Heartbeat fires, THEN `P` decreases by `8.0 × dt` (`OXYGEN_DRAIN_BC4_FLOOR`). *(Logic; forward-pending: BCT accessor)*

**H.6** — GIVEN a run is active, WHEN a Heartbeat fires with `dt ≤ 0` (clock anomaly), THEN `P` is unchanged and no error is thrown. *(Logic)*

**H.7** — GIVEN `P = 0.005` at BC1, WHEN one Heartbeat fires (drain ≈ 0.0167), THEN `P` clamps to exactly 0 and `OnPlayerOxygenExpired` fires squad-wide that tick. *(Logic)*

**H.8** — GIVEN `P = 590`, WHEN a Canister restore fires, THEN `P = min(600, 590+10) = 600` (no overfill). *(Logic)*

**H.9** — GIVEN `P = 580`, WHEN a Canister restore fires, THEN `P = 590`. *(Logic)*

**H.10** — GIVEN `P = 40`, WHEN `RequestSquadOxygenSpend(amount=1, reason="death", deathEventId="evt-001")` fires, THEN `P = max(0, 40−72) = 0`. *(Logic)*

**H.11** — GIVEN `P = 300`, WHEN a death spend (`evt-002`) fires once, THEN `P = 228`. *(Logic)*

**H.12** — GIVEN `P = 228` and `(userId=12345, evt-002)` already applied, WHEN the same pair fires again, THEN `P` stays `228` (idempotent, no error). *(Logic)*

**H.13** — GIVEN `P = 228` and the same user dies under a new `evt-003`, WHEN the spend fires, THEN `P = 156` (new key applies). *(Logic)*

**H.14** — GIVEN a death cost was deducted for `(userId, deathEventId)`, WHEN PC signals that player's respawn (the respawn event, not a wall-clock wait), THEN RM applies **no** additional pool deduction (the death cost is the whole cost; respawn carries no RM-side charge). *(Logic — assert on the respawn signal, not a real 30 s timer)*

**H.15** — GIVEN `P = 40` (Healthy), WHEN drain takes `P` to `34.9`, THEN state → Critical and `OnOxygenStateChanged("Critical")` fires. *(Integration)*

**H.16** — GIVEN `P = 34` (Critical), WHEN a restore lifts `P` to `36`, THEN state stays **Critical** (recovery needs `P > 37`). *(Logic)*

**H.17** — GIVEN `P = 34` (Critical), WHEN restores lift `P` to `38`, THEN state → Healthy and `OnOxygenStateChanged("Healthy")` fires. *(Logic)*

**H.18** — GIVEN `P = 1` (Critical) at BC1, WHEN one Heartbeat drains `P` to 0, THEN state → Empty and `OnPlayerOxygenExpired` broadcasts squad-wide that tick. *(Integration)*

**H.19** — GIVEN a tick where drain would take `P` to 0 **and** a Canister restore is queued the same tick, WHEN RM processes the tick in the fixed order (deductions → restores → drain, Empty evaluated on the final `P`), THEN `P > 0` (the restore lands), the squad does **not** enter Empty, and `OnPlayerOxygenExpired` does **not** fire — deterministic regardless of network arrival order. *(Logic)*

**H.20** — GIVEN the client received a sync `(P_lastSync = 300, drainRate = 8.0)` and `t` seconds have elapsed with no newer sync and no un-forecast discrete event, WHEN the client renders the bar, THEN the displayed value equals `300 − 8.0 × t` within `±0.5` (dead-reckoned, CR.1); AND the client never writes `P`. *(Integration — asserts the dead-reckoning math against a fixed `t`, no live RTT in the assertion)*

**H.21** — GIVEN BCT changes BC2→BC3 mid-run, WHEN the next Heartbeat fires, THEN drain uses `2.2/s` (current BCT at tick time, not cached at run-start). *(Integration; forward-pending: BCT accessor)*

**H.22** — GIVEN `P = 600`, the squad hides (zero Canister use) at BC1, WHEN one second elapses, THEN `P` decreased by exactly `1.0` (net strictly negative — DEG-1 structural). *(Logic)*

**H.23** — GIVEN the full-squad bench-bottlenecked Canister throughput (`restoreRate_squad`, D.6), WHEN compared against BC4 drain (`8.0/s`), THEN net oxygen is strictly negative. *(Logic; **forward-pending: blocked until Resource Node `canisterCycleTime` is authored** — do not mark Done before RN APPROVED)*

**H.24** — GIVEN a new run, WHEN `ResourceService` initialises, THEN it asserts `DEATH_OXYGEN_COST / OXYGEN_POOL_START = 0.12 ∈ [0.10, 0.15]` (fail-fast; run does not start on failure). *(Config-Data)*

**H.25** — GIVEN a new run, WHEN initialising, THEN it asserts `CANISTER_RESTORE_OXYGEN (10) < DEATH_OXYGEN_COST (72)` (fail-fast). *(Config-Data)*

**H.26** — GIVEN a new run, WHEN initialising, THEN it asserts the BC4 over-supply fence (D.5a): `ITEM_STACK_MAX × CANISTER_RESTORE_OXYGEN < BEACON_SURVIVAL_WINDOW_min × OXYGEN_DRAIN_BC4_FLOOR` (`10 × 10 = 100 < 35 × 8.0 = 280`); fail-fast (run does not start on failure). RM imports `ITEM_STACK_MAX` + `BEACON_SURVIVAL_WINDOW_min` from Crafting. *(Config-Data; partial — Crafting owns two constants; the CR.9 entry-cap leg was removed with CR.9, RBI-2)*

**H.27** — GIVEN a client attempts to invoke `RequestSquadOxygenSpend` directly (RemoteEvent/Function/exploit), WHEN it reaches the server, THEN it is rejected/ignored and `P` is not mutated (no client-invoke path). *(Security)*

**H.28** — GIVEN a client attempts to fire a spoofed `OnOxygenPulseRequest`, WHEN it reaches the server, THEN `P` is not restored (it is a server-internal Knit `Signal`, not a `RemoteSignal` — no client publish path exists). *(Security)*

**H.29** — GIVEN a client attempts to write `P` directly (shared module / mutable return), WHEN attempted, THEN server `P` is unchanged (`P` never passed by reference to client). *(Security)*

**H.30** — GIVEN `P = 600` (ceiling), WHEN a Canister restore fires, THEN `P` stays `600` (no-op, no error). *(Logic)*

**H.31** — GIVEN `P = 0` (floor), WHEN a Heartbeat drains at any band, THEN `P` stays `0` (no underflow). *(Logic)*

**H.32** — GIVEN `P = 35` exactly, WHEN state is evaluated, THEN it is **Critical** (Healthy requires strict `P > 35`). *(Logic)*

**H.33** — GIVEN `P = 37` exactly in Critical, WHEN re-evaluated after a restore, THEN state stays **Critical** (recovery requires strict `P > 37`). *(Logic)*

**H.34** — GIVEN a run with N connected clients, WHEN the `OXYGEN_SYNC_HZ` timer fires, THEN every connected client receives the current `P` within one sync interval (reconnected/late clients get it on their next sync). *(Integration)*

**H.35** — GIVEN `P = 36` (Critical) draining at BC1, WHEN drain pushes `P` below 35, THEN the Critical signal fires but `OnPlayerOxygenExpired` does **not** fire until `P = 0`. *(Logic)*

**H.36** — GIVEN `P = 0` and `OnPlayerOxygenExpired` already fired, WHEN further Heartbeats run, THEN it does **not** re-fire (one-shot per Empty transition). *(Logic)*

**H.37** — GIVEN two runs (1 player vs 4 players) both at BC2, WHEN one Heartbeat fires in each, THEN `P` decreases by exactly `1.5 × dt` in both (drain is flat-headcount). *(Logic)*

**H.38** — *RETIRED (round-2, RBI-2 — CR.9 BC4-entry cap removed). Number not reused.*

**H.39** — *RETIRED (round-2, RBI-2). Number not reused.*

**H.40** — *RETIRED (round-2, RBI-2). Number not reused.*

**H.41** — GIVEN the Beacon-Charge-Tier accessor returns `nil` (ED/Beacon uninitialised or a transient read failure), WHEN a Heartbeat fires, THEN RM applies **BC1 (slowest, 1.0/s)** drain for that tick and logs the fallback — never stalls the pool, never over-drains on missing data (fail-safe, GAP-1). *(Logic; forward-pending: BCT accessor)*

**H.42** — GIVEN a player leaves mid-run via `PlayerRemoving` (a disconnect, not a death), WHEN RM handles it, THEN **no** oxygen is charged (it is not `reason="death"`) AND the drain rate is unchanged (flat-headcount) — the squad only loses that player's gather contribution (GAP-2). *(Logic)*

**H.43** — GIVEN one death deduction and one Canister restore queued in the same tick where drain alone would not empty the pool, WHEN RM processes them, THEN the result is `clamp(clamp(P − DEATH_OXYGEN_COST) + CANISTER_RESTORE_OXYGEN) − drainRate×dt` in that fixed order (deductions → restores → drain), independent of network arrival order. *(Logic)*

**H.44** — GIVEN N players die in the same tick (N ≥ 1), WHEN RM deducts their costs, THEN it deducts `N × DEATH_OXYGEN_COST` (clamped) AND emits `OnOxygenDeducted` **once** with `reason="death"` and `simultaneousCount = N` (coalesced — the HUD renders one cue, not N flashes, RBI-6). *(Integration)*

**H.45** — GIVEN a Canister restore is applied, WHEN `P` increases, THEN RM emits `OnOxygenRestored(amount = CANISTER_RESTORE_OXYGEN, source = "canister")` exactly once for that restore (distinct from the drain/death events). *(Logic)*

**H.46** — GIVEN an `OXYGEN_SYNC_HZ` push, WHEN the client receives it, THEN the payload carries **both** the current `P` and the current `drainRate` (band), so the client can dead-reckon the bar between syncs (CR.1). *(Integration)*

**H.47** — GIVEN the running `ResourceService`, WHEN its `.Client` table is introspected, THEN it exposes **no** client-callable method or `RemoteFunction`/`RemoteEvent` that mutates `P` or invokes `RequestSquadOxygenSpend` (the spend path is server-internal only; mirrors Crafting's H.24 enforcement AC). *(Security)*

**H.48** — GIVEN a death spend arrives with `amount ≤ 0` or a non-integer `amount`, WHEN RM validates it, THEN it is rejected as a no-op and `P` is unchanged (defensive validation even on the server-internal path). *(Logic)*

**H.49** — GIVEN a silent, zero-Canister squad enters BC4 at the coast boundary, WHEN BC4 drain (`8.0/s`) runs for the 35 s minimum window, THEN a squad entering at `P = 279` reaches 0 **before** 35 s (loss) and a squad entering at `P = 281` survives (`281 − 280 > 0`) — documenting the D.5 coast threshold of `35 × 8.0 = 280`. *(Logic; forward-pending: BCT accessor + Crafting `BEACON_SURVIVAL_WINDOW_min`)*

## Open Questions

- **OQ.1 — BCT transition semantics** (qa GAP-1): when the band changes mid-run, the new rate applies on the first Heartbeat that observes the new BCT (rate read at tick start). Confirm this matches the ED/Beacon escalation model. *(Owner: systems-designer + ED author; when: ED Session B / Beacon model.)*
- **OQ.2 — Pre-Beacon band mapping** (qa GAP-8): which BCT applies before a Beacon exists? Provisional: BC1 baseline at run start, escalating with disturbance/charge. Confirm whether ED disturbance drives BC1–BC3 pre-Beacon or the band is purely Beacon-charge. *(Owner: ED + Crafting Beacon; when: ED Session B.)*
- **OQ.3 — Squad-size-aware ratio + death-spiral circuit-breaker** (= PC OQ.15): MVP is flat drain + no breaker (user-ruled). Revisit whether 2-player needs a squad-size-aware death cost or a last-stand floor. *(Owner: game-designer / CD; when: first playtest.)*
- **OQ.4 — 2-player BC4 viability**: a 2-player squad runs net-negative at BC4 even at best play (intended by flat drain). Validate the difficulty is intended, not punishing. *(Owner: game-designer; when: first playtest.)*
- **OQ.5 — Run-length / pool pacing**: `OXYGEN_POOL_START = 600` sets the countdown length; validate the "always a countdown" feel fits 5–20 min sessions. *(Owner: game-designer; when: `/prototype`.)*
- **OQ.6 — `CANISTER_RESTORE_OXYGEN` final value**: locked at 10 within H.106 headroom (< 12.25) and `< DEATH_OXYGEN_COST`; re-tune against RN `BIOMASS_GATHER_TIME` once authored. *(Owner: economy-designer; when: after RN.)*
- **OQ.7 — Reverse-cite / forward obligations** (so they aren't lost): **ED/Beacon** must expose the BCT accessor + reverse-cite RM; **Resource Node** must register `BIOMASS_GATHER_TIME` + carry the indirect materials→Canister chain; **HUD** must consume `OnOxygenChanged` + `OnOxygenStateChanged` and read `OXYGEN_POOL_START` / `OXYGEN_CRITICAL_THRESHOLD`; **Level design** must guarantee reachable bench + BIOMASS per map.
- **OQ.8 — Crafting F.2/H.106 reconciliation + faucet-name convergence** (RBI-1 + the `/consistency-check` 2026-06-17 finding, **doc-integrity, RM-initiated**): Crafting's next revision MUST, on its own side: (i) converge on the single faucet name **`OnOxygenPulseRequest`** (it publishes that at crafting-and-items.md:364 +4 sites but names it `OnOxygenRestoreRequested` once at line 938); (ii) align the H.106 AC (line 2031) with the F.2 binding contract (line 938); and (iii) replace the **per-member** anti-bunker framing with RM's **shared-pool** form — which is now carried by the raised BC4 drain (D.5), *not* a per-member entry cap (the CR.9 `OXYGEN_BC4_ENTRY_CAP` was removed, RBI-2). RM has already conformed to Crafting's published faucet signature and restated the fence; these are Crafting-side obligations. *(Owner: Crafting GDD next revision + CD. Durable record: this OQ + the `/consistency-check` finding 2026-06-17.)*
- **OQ.9 — BC4 drain feel + coast-threshold validation** (RBI-2, the load-bearing round-2 tuning): `OXYGEN_DRAIN_BC4_FLOOR` was raised 3.5 → **8.0** to make the steep drain the sole shared-pool anti-bunker fence after CR.9 was removed. Validate at first playtest that (a) oxygen pressure forces loud Canister use in the finale **without** oxygen-death overshadowing the predator as the dominant failure (8.0 was chosen over the ~17 u/s "no-coast-at-any-pool" ceiling precisely to avoid that), and (b) the **coast threshold of 280** (the entry pool a silent squad can ride through the 35 s window, D.5/H.49) is reached implausibly rarely given the D.6 countdown. If oxygen-death dominates, lower toward 5.0; if silent coasting is observed, raise toward 12.0. *(Owner: CD + game-designer; when: first playtest / balance pass.)*
