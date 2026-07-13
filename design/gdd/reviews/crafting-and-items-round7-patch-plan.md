# Crafting & Items — Round-7 Authoring Patch Plan

> **Status**: APPLIED 2026-06-02 — full changeset authored to `crafting-and-items.md` + `entities.yaml`; self-stress sweeps ran (reconciliation-fanout caught a stale round-5 5→4 recipe-panel-row miss; schema-completeness clean; authority chain protected). User-approved decisions: Hybrid A+B, Anchor 2/1/0, revise-Section-B-prose, lock ≤4 BC4 cap. NOT re-reviewed (3 narrow gates → round-8 next). NOT committed.
> **Created**: 2026-06-02
> **Sequencing**: Per the round-6 CD recommendation — (1) Group B design ruling [DONE, user-approved below]; (2) ONE authoring pass for Groups A + C + D + the AC/Recommended tail, with a schema-completeness sweep AND a reconciliation-fanout checklist; (3) THREE narrow fresh-agent gates for round-7 (economy; systems+network jointly on the Group-A schema; ux) — NOT a full panel; round-8 is the next full panel.
> **HARD CONSTRAINT**: No edit may touch the network-confirmed server-authoritative completion/attribution path (BCT3→`beaconPlacerId`; BCT4→server `HumanoidRootPart.Position`; flags server-only/monotonic). The network gate re-verifies non-regression.
> **DO NOT predict APPROVED for round-7.**

---

## Group B — design decisions (user-approved 2026-06-02)

- **Group B direction**: **Hybrid A+B** — own a Crafting-side counter to canister-bunker dominance NOW (in-window canister-use emission) AND convert the RM/PA aid-necessity claim into falsifiable numeric forward-obligations with binding ACs.
- **Finding 7 (BIOMASS sink)**: **structural fix now** — re-weight Signal Anchor `1/1/1 → 2/1/0` (cost-neutral at 3 gathers; gives BIOMASS a 3rd consumer; drops the Anchor's weak RESONANT draw).

---

## Group B — edits

### B-1 In-window Oxygen Canister emission (the bunker counter)
- **C.6 Oxygen Canister bullet**: change "Use generates **no additional disturbance**" to the BC4-conditional rule: outside BC4 → silent (craft burst already paid); **while `RunSession.beaconActivated == true && beaconWindowSurvived == false` (BC4)** → after the RM oxygen restore, server fires `DisturbanceService:Emit("Craft", <user's server-tracked HumanoidRootPart.Position>, MAGNITUDE_CANISTER_INWINDOW_USE, usingPlayerId)`. Attribution = the using player (their breath, their position), NOT the bench. Position is server-tracked (RequestUseItem payload carries no position → no spoof).
- **C.2 Oxygen Canister row**: append a note that in-window use emits `MAGNITUDE_CANISTER_INWINDOW_USE` (the "every breath during the finale is heard" rule).
- **C.11 (publisher contract)**: add a 4th Craft-emission trigger (in-window canister use), with position = user HRP, sourcePlayerId = user, magnitude = `MAGNITUDE_CANISTER_INWINDOW_USE`; reserved-band compliant (≤0.35).
- **C.15 `RequestUseItem`**: add note that in BC4 the handler fires the in-window Craft emission after the RM restore (still no client position trusted).
- **G.4**: add knob `MAGNITUDE_CANISTER_INWINDOW_USE` default **0.18 (MID)**, range 0.10–0.35; update the section header "Four magnitudes" → "Five". Coupled-tuning note: at MID, ~3 clustered in-window uses sum at the squad's position into a Hunt-floor-saturating fixed point the committing predator reads.
- **VA.3**: add **Moment 28** — "Oxygen Canister in-window use burst" — reuses F1 Craft-Burst at XS-tier vocabulary at the using player's position (world-space VFX + 3D SFX; NOT a HUD surface, so it does not hit the BC4 HUD-density cap). Update moment count 23 → **24**. Add to VA.4 Family F1 usage list.
- **E.32 (new edge case)**: Oxygen Canister used during BC4 emits at the user's position (even if scattered far from the beacon); used outside BC4 is silent; used on the exact window-end tick still emits (the use is processed in its own handler, independent of the window-survival check). Edge-case count 29 → **30**.
- **H.93 (new AC) [P0] Logic**: canister use in BC4 fires exactly one `Craft` emission at the user's server-tracked position with `MAGNITUDE_CANISTER_INWINDOW_USE`; canister use outside BC4 fires zero emissions; position is server-tracked, not client-supplied.

### B-2 Falsifiable RM/PA forward obligations + C.5.6a rewrite
- **F.4 Resource Management row clause (c)**: replace the prose "design target" with a numeric, AC-bearing contract — RM MUST define `OXYGEN_DRAIN_BC4_FLOOR` such that a `MIN_SQUAD_SIZE` squad carrying a full `ITEM_STACK_MAX` (10) of Canisters, used optimally, CANNOT cover the full `BEACON_SURVIVAL_WINDOW` without ≥1 member hitting the critical oxygen threshold; **RM MUST carry an AC asserting this inequality at default tunings**.
- **F.4 Predator AI row clause (b)**: replace with a numeric, AC-bearing contract — PA MUST define `PREDATOR_BC4_MIN_COMMIT` guaranteeing a stationary clustered squad inside `BEACON_HOLD_RADIUS` taking no defensive action suffers ≥1 forced damage/displacement event before window-end at default tunings; **PA MUST carry an AC** asserting a stationary-bunker squad is engaged at least once per full window.
- **C.5.6a**: rewrite the aid-necessity paragraph to state plainly: Crafting owns ONE structural counter to the bunker line (the in-window canister emission, C.6/G.4) so the bunker line is **not free even before RM/PA land**; the remaining necessity is gated on the two F.4 contracts, each with a binding AC; until both land, full aid-suite necessity is a *target*, not asserted fact.
- **OQ.13**: note the in-window canister emission as a new calibration input (`MAGNITUDE_CANISTER_INWINDOW_USE` tunes with the RM drain floor).

### B-3 Signal Anchor re-weight 1/1/1 → 2/1/0 (BIOMASS sink fix)
- **C.2 row 3 (Signal Anchor)**: `1 / 1 / 1` → `2 / 1 / 0`.
- **C.2 sanity check**: "1 Signal Anchor (3)" stays 3 gathers (cost-neutral) — no budget churn; update the B/M/R breakdown text if it enumerates Anchor materials.
- **G.3 Signal Anchor row**: `1/1/1` → `2/1/0`; update the "touches all three materials" note → "BIOMASS-weighted; gives the third BIOMASS consumer so Medium/MINERAL and Heavy/RESONANT tiers are not the only non-Beacon draws" (and RESONANT stays live via Coil + Beacon).
- **OQ.15**: mark the *structural* question RESOLVED (Anchor re-weighted toward BIOMASS; all three node tiers now have a live non-Beacon consumer); leave only the pure-tuning weight question open (economy pass with OQ.13).
- **entities.yaml**: Anchor recipe cost 1/1/1 → 2/1/0.
- **C.1 narrative**: BIOMASS "soft seals / sensors" already fits the Anchor — confirm no contradiction (no edit expected).

---

## Group A — win-condition data model (the round-6 decisive structural class)

### A-1 + A-2 Single canonical alive/participant set (kills the two-sources-of-truth)
- **C.10 RunSession schema**: add an explicit **window-participant snapshot** model. Proposed: at the top of each BC4 Heartbeat tick the handler builds `windowAliveInRadius` — the set of members who are (alive) AND (`dist3D(member.HumanoidRootPart.Position, beaconWorldPosition) <= BEACON_HOLD_RADIUS`) — computed ONCE per tick, BEFORE draining `_pendingDepartures`. This single per-tick computation is the sole source of truth for BOTH the BCT4 victory check and the tie-break; there is no second "live read." Document that the live `HumanoidRootPart.Position` read is performed only inside this single per-tick snapshot (resolving "C.9 reads live position, H.77 reads buffered set" into one model). Add a field/COMMENT making explicit that membership is a per-tick derived value, not stored across ticks, and that a member whose character is being destroyed in `PlayerRemoving` is excluded because their departure is already buffered and they are not counted alive in the snapshot.
- **C.9 BCT4 + line 207/231 + BCT-DEFEAT**: reconcile the prose so "live HumanoidRootPart.Position" and "pre-drain alive set" are the SAME per-tick snapshot. The snapshot is taken at the top of the tick (before drain); the window-survival check and the scatter check both read it; the drain runs after.
- **H.77**: update to reference the single per-tick `windowAliveInRadius` snapshot (no behavioral change — it already favors the squad; this just names the data model).
- **H.99 (new AC) [P0] Logic**: BCT4 victory check and the tie-break read the SAME per-tick participant snapshot (one source of truth); a member destroyed via `PlayerRemoving` on the window-end tick is excluded from the snapshot only via the buffered-departure path, never via a racing live read.

### A-3 `_pendingDepartures` dual-scope dispatch mechanism
- **C.8 buffer-scope paragraph**: make the dual-scope dispatch a concrete mechanism, not intent. Specify: a single `Humanoid.Died` / `Players.PlayerRemoving` event enqueues ONE departure record that is dispatched to BOTH drains (bench `CraftSession` scope AND RunSession BC4 scope) — e.g. each scope keeps its own queue fed by one shared `_enqueueDeparture(playerId, reason)` that appends to every active scope, so neither drain can consume the event in a way that hides it from the other. Name the seam `_enqueueDeparture`.
- **H.100-style coverage** (fold into a new AC, see H.101 below): a single departure updates BOTH scopes.

### A-4 `benchMaxCraftersEffective` storage field
- **C.10 RunSession schema** (or CraftSession): add `benchMaxCraftersEffective: int` as a stored field, computed ONCE at `RunStarted` from `min(BENCH_MAX_CRAFTERS, ceil(squadSize/2))`, read by BT2's entry guard and D.2. (C.3.5/C.8/D.2 already reference it; this gives it a home.) Document it is computed at run start and never recomputed on death/disconnect (cap never shrinks mid-run).
- **H.100 (new AC) [P0] Logic**: `benchMaxCraftersEffective` is stored at run start = `min(BENCH_MAX_CRAFTERS, ceil(squadSize/2))`, drives BT2's guard + D.2, and is not recomputed on departure.

### A-5 D.6a Stage-2 ownership (who applies PC's STATIONARY_EMISSION_FACTOR)
- **D.6a**: add an explicit ownership ruling — the Stage-2 PC stationary-attenuation factor is applied by the **single emission-publishing service that owns the pulse** (the system firing `DisturbanceService:Emit` for that pulse applies BOTH its own Stage-1 modifier and the Stage-2 stationary factor in the one canonical chain, exactly once). For Light pulses the lantern/PC pulse owner applies the chain; Crafting's Coil contributes the Stage-1 factor as data the pulse owner reads. State plainly: the factor is applied exactly once by the pulse's publishing service — never double-applied (Crafting AND PC both multiplying) nor omitted. Cross-reference PC.D.4.
- **H.38 relabel**: note H.38 depends on PC.D.4's stationary factor being applied in the one canonical chain — add an **unverified-until-PC** annotation on the Stage-2 half (the Coil Stage-1 half is testable now; the chained product with PC's factor is verified when PC lands). Keep [P2].

---

## Group C — UX on the primary platform

### C-1 BC4 HUD-density: concrete in-GDD cap (replace "deferred to /ux-design")
- **UI.5 item 6 + UI.1 surface 13**: replace "capped + deferred" with a concrete BC4 Crafting surface BUDGET. Rule: during BC4, Crafting's HUD contribution is consolidated to a hard set — (1) survival-window countdown + hold-state (surface 13); (2) a single **compact aid-count strip** (the squad inventory readout collapses during BC4 to show only consumable counts that matter in the window — primarily Oxygen Canister); (3) the equipped-effect badge (surface 4) ONLY if a Coil is active; (4) the alert overlay (surface 11). The **personal inventory readout (surface 6) and bench progress rings (surfaces 2/3) are SUPPRESSED during BC4** (no gathering/crafting at the beacon during the window). The beacon waypoint chevron (surface 8) merges into the hold-state indicator. **Hard cap: ≤ 4 concurrent Crafting-owned HUD surfaces during BC4.** `/ux-design` owns pixel layout; the surface budget + the suppress-list is locked here. (NOTE — judgment call flagged for user/ux-gate.)
- **H.94-adjacent**: no AC needed for suppression (UI/advisory), but state the cap as the auditable contract.

### C-2 Scatter hold-state needs a live per-member signal during BC4
- **C.14 + C.15 + UI.3**: add a client-bound signal **`OnBeaconHoldStateChanged(playerId, inRadius: bool)`** pushed when a member crosses the `BEACON_HOLD_RADIUS` boundary during BC4 (boundary-cross, throttled — NOT a per-Heartbeat flood). This is what lets the HUD render the per-member "HOLD THE BEACON" in/out-of-radius state (surface 13) during the window — the round-6 gap (proximity was evaluated only at window-end, so no signal carried live per-member distance). The per-tick `windowAliveInRadius` snapshot (A-1) is the natural source: when a member's in-radius status flips between ticks, push the signal. Does NOT change the win condition (still evaluated only at window-end) — it is presentation only. A scattered off-screen player gets a directional cue to the beacon via the existing waypoint chevron + this in/out state.
- **C.15 client-event count**: 7 → 7 client-initiated unchanged (this is server→client); add `OnBeaconHoldStateChanged` to the server-pushed list.
- **H.94 (new AC) [P0] Logic**: `OnBeaconHoldStateChanged(playerId, inRadius)` fires when a member crosses `BEACON_HOLD_RADIUS` during BC4 (both directions), throttled to boundary-cross; it does NOT alter the window-end victory/scatter evaluation (presentation only).

### C-3 WCAG 2.3.1 flash cap — Crafting-owned AC for Crafting-owned surfaces
- **F.4 ED row**: keep the ED flora flash-cap obligation (ED owns flora rendering).
- **UI.5 item 6 / UI.1**: add a **Crafting-owned** cap: the Crafting-owned activation surfaces (survival-window countdown ring pulse, the `BEACON_HOLD_RADIUS` world-ring pulse, any Coil-warning pulse) MUST NOT flash faster than **3 flashes/second** (WCAG 2.3.1). This is the cap Crafting CAN own (its own surfaces); the flora stays ED's.
- **H.95 (new AC) [P2] Config/UI**: Crafting-owned BC4 activation surfaces (countdown ring, hold world-ring, Coil-final-10s warning) flash ≤ 3/s.

---

## Group D — AC testability

### D-1 `_simulateBindToClose` seam (H.90 testability)
- **C.16 seam table**: add a 4th seam `_simulateBindToClose()` (production = bound to `game:BindToClose`; test = invokes the shutdown-cleanup path deterministically).
- **H.90 GIVEN**: change "the test invokes the `game:BindToClose` handler" to "the test invokes the C.16 `_simulateBindToClose()` seam."
- **F.4 Architecture ADR (5) / C.16 forbidden list**: note the new seam.

### D-2 H.15 Logic-P1 / Integration-P2 split
- **H.15**: split like H.73/H.76 — **Part 1 (Logic, sprint-gate, testable now)**: `OnEscapeBeaconActivated` fires exactly once with correct payload; `beaconActivated=true`; survival-window timer starts; `OnBeaconWindowSurvived` does NOT fire at activation. **Part 2 (Integration, unverified-until-PC)**: that PC does not fire T8 on `OnEscapeBeaconActivated`. Relabel Test type accordingly.

### D-3 H.39 midpulse float-trap
- **H.39 + determinism preamble**: reframe H.39 as a **crossing test** (the midpulse fires exactly once on the first `_step` where `craftProgress >= CRAFT_BEACON_MIDPULSE_PROGRESS`) — NOT an exact-equality assertion — so float-representability of non-default thresholds (0.4/0.6) is irrelevant (a `>=` crossing is robust). Remove H.39 from the bit-exact-EQUALITY cluster in the preamble (keep H.27/28/30/31/41 there); note the default-0.5 worked example is exactly representable but the AC does not depend on it.

---

## Recommended tail (round-6)

- **Section B**: revise Coil prose (BC4 value is *positional freedom* + breaking the predator's read on a loud cluster — RAISED by the new canister-emission rule — not noise reduction); revise Anchor prose to the honest 45 s < 49 s framing (a reactive tool placed *during* the window that reads the approach for ~45 of the ~49 s — matches C.6's intentional lifetime-vs-window note). **(JUDGMENT CALL flagged: revise Section B prose [recommended, keeps the deliberate 45<49 design] vs. bump `SIGNAL_ANCHOR_LIFETIME` to ≥ window.)** Note "predator commits" emotional center lives in the unwritten PA GDD.
- **C.3.5 / C.17**: acknowledge (a) 2-player bench has no coordination decision (cap=1, BS3 unreachable — already stated; add that this is the deliberate "one crafts, one watches"); (b) the "nobody-watches" fix only holds for squads that *start* at 2 — a 3→2 mid-run drop keeps cap=2 (cap never shrinks), so a late-game 2-survivor squad that started at 3 can have both craft; document as an accepted transient (the cap-never-shrinks rule deliberately avoids mid-craft disruption).
- **C.15 / G.7 `RequestEquipItem`**: add a burst clause "burst up to 3 per 3 s" for parity (round-1 B12 class — sustained 1/s with no burst throttles legitimate retry-after-rejection).
- **C.8 / C.15 `RequestCraftCancel` buffering**: clarify the cancel REQUEST is received directly but its EFFECT (crafter removal) is buffered into `_pendingDepartures` and drained in the Heartbeat handler (same as death/disconnect), so the BT3-vs-cancel tie-break is deterministic.
- **C.15 global rate-limit window**: align the global burst window to **16 events / 3 s** (was 2 s) to match the per-event 3-s burst windows; note the alignment.
- **UI.4 line 1186**: remove the stale "Moment 25" from the 2D squad-broadcast tones list (Relay activation, retired round-5).
- **New ACs (recommended-tail)**:
  - **H.96 [P0] Logic** — BT2 wrong-recipe rejection: a second player firing `RequestCraft` for a DIFFERENT recipe than the active session is rejected (`OnCraftRejected(reason="recipe-mismatch")`), not joined.
  - **H.97 — D.2/BT4 rate-anchor reset**: on BT4 departure the handler captures `progressAtRateAnchor = current craftProgress` and `rateAnchorClock = _clock()` (progress preserved, rate drops to N=1) — clock-boundary exact.
  - **H.98 — global-limit burst-window**: 16 events within 3 s pass; the 17th in the same 3-s window is dropped (burst-window boundary).
  - **H.101 [P0] Logic — dual-scope departure dispatch (A-3)**: a single `Humanoid.Died`/`Players.PlayerRemoving` event updates BOTH the bench `CraftSession.crafters` scope AND the RunSession BC4 alive-snapshot scope (neither drain hides the event from the other).
- **Test-type relabels**: H.63/H.64/H.66 → "Performance (advisory — requires playtest measurement)"; H.65 → Logic (DataStore call-count is a spy assertion, not Integration); H.10 → add "unverified-until-PC" note (depends on PC respawn S4→S1 event); H.38 → unverified-until-PC on the Stage-2 chained-product half (A-5).

---

## Count reconciliation (post-patch targets)
- Recipes: **4** (unchanged).
- Squad item types: **4** (unchanged).
- VA moments: 23 → **24** (Moment 28 added — in-window canister burst).
- Edge cases: 29 → **30** (E.32 added).
- ACs: 84 → **92** (H.93, H.94, H.95, H.96, H.97, H.98, H.99, H.100, H.101 added = 9 new → recount: 84+9 = **93**, numbered through H.101). *(Confirm exact count at write time; some recommended ACs may fold.)*
- Craft-magnitude knobs (G.4): 4 → **5** (`MAGNITUDE_CANISTER_INWINDOW_USE`).
- Client-initiated RemoteEvents: **7** (unchanged); server-pushed events +1 (`OnBeaconHoldStateChanged`).

## Self-stress (run BEFORE declaring done)
1. **Reconciliation-fanout checklist** (grep every renamed/new token + every count): `MAGNITUDE_CANISTER_INWINDOW_USE`, `OnBeaconHoldStateChanged`, `_simulateBindToClose`, `_enqueueDeparture`, `windowAliveInRadius`, `benchMaxCraftersEffective`, Anchor `1/1/1`→`2/1/0` (all references), `Moment 25` (stale), and all count statements (recipes / item types / moments / ACs / edge cases / knobs / events).
2. **Schema-completeness sweep** (the NEW round-7 layer): every new RULE has a named DATA MODEL — the BC4 canister-emission gate reads `beaconActivated` (existing); the hold-state signal reads `windowAliveInRadius` (A-1); `benchMaxCraftersEffective` has a storage field (A-4); the dual-scope dispatch has the `_enqueueDeparture` seam (A-3). No rule lands without its mechanism.
3. Protect the authority/attribution chain — confirm no edit touched BCT3/BCT4 server-authoritative completion/attribution.

## Files touched
- `design/gdd/crafting-and-items.md` (primary).
- `design/registry/entities.yaml` (Anchor cost 2/1/0; new `MAGNITUDE_CANISTER_INWINDOW_USE`; `OnBeaconHoldStateChanged` enum if registry tracks signals).
- `design/gdd/reviews/crafting-and-items-review-log.md` (round-7 authoring-pass record).
- `design/gdd/systems-index.md` (status note).
- `production/session-state/active.md`.
- **NOT committed** (awaiting user instruction).
