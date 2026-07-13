# Prototype Report: Predator-AI Quiet-Lever (n=2 structural gate)

> PROTOTYPE — NOT FOR PRODUCTION. Date: 2026-06-19. Review mode: lean (no CD playtest gate).
> Scope: Bucket B (structural balance) only. Engine/runtime items (OQ.6 pathfinding,
> OQ.14 ≤2 ms budget, OQ.5 ED-accessor cost) are deferred to a Studio-based prototype.

## Hypothesis

The BLOCKING gates **H.66** and **OQ.12** ask: at the n=2 primary squad, is "quiet" a
real lever? Specifically — is there a gather cadence that keeps the **non-locked
survivor's** emission field `T` strictly below `effectiveQuietThreshold(2) = 0.38`
(forcing predator **Disengage**) **WHILE** still gathering the win-critical **RESONANT**
in time? OQ.12's kill condition: *if no value can separate "working quietly" from "loud,"
the n=2 disengage model itself must change.*

Going in, one authored coupling looked dangerous: the Beacon needs **3 RESONANT**
(RN line 80), RESONANT comes **only** from **Heavy** nodes, and a Heavy gather emits
**0.40** — which is **above the 0.38 threshold**. So the win-critical action is, by the
numbers, inherently "loud."

## Approach

A single-file headless Python simulation (`quiet_lever_sim.py`, ~260 lines, no RNG,
deterministic). It models the ED field exactly as the predator's `GetSquadAggregateT(exclude
locked)` sees it at n=2 — which reduces to **`fieldValue` at the non-locked survivor's own
position** (the locked player is excluded per OQ.10; their distant emissions fall outside
`INFLUENCE_RADIUS`).

All **emission/decay/threshold constants are authored and cited inline**:
`STANDARD_HALF_LIFE=30 s`, `λ=ln2/30`, `MAGNITUDE_FLOOR=0.02`, `INFLUENCE_RADIUS=24`,
falloff `(1−d/r)²`, gather magnitudes `{L 0.15, M 0.25, H 0.40}`, threshold(2)=0.38,
`RETREAT_SUSTAIN_DURATION=30 s`. Win-economy timings (walk speed 12/s, node spacing,
schedule) are **labeled prototype assumptions and swept**, not trusted. Four analyses:
single-gather spike duration; feasible-threshold-band sweep; node-spacing sensitivity;
half-life sensitivity. Built and run in one pass.

## Result

**1 — The supra-threshold spike from a Heavy gather is brief.** A Heavy gather (0.40)
holds the survivor's field ≥ 0.38 for only **~0.05 s** if they walk away at 12/s (distance
falloff dominates) or **2.23 s** if they stand still — versus the **30 s** sustained-quiet
the predator needs to Disengage. Light and Medium never cross 0.38 at all.

**2 — A ≥30 s sub-threshold window survives a realistic 3-Heavy run with huge margin.**
Over a representative schedule `[M,H,L,M,H,M,L,H]` (3 Heavy = Beacon, plus Medium/Light for
survival mats), the longest continuous sub-0.38 window is **60.1 s** — twice the 30 s the
predator needs. **Quiet IS a lever** in the between-nodes movement state H.66 specifies.

**3 — The viable threshold band is `[0.26 .. 0.40]`; 0.38 is inside, near the top edge.**
Sweeping the threshold:
- **> 0.40** → even Heavy reads silent → predator never sheds via field → lever **DEAD**.
- **≤ 0.25** → even Medium reads loud → survivor can't do routine work quietly → lever **DEAD**.
- **0.26 – 0.40** → Medium quiet, Heavy loud, 30 s window alive → **VIABLE**.

So OQ.12's separating value **EXISTS**, and the authored 0.38 sits inside the band — but
with only **0.02 (5%) headroom** beneath Heavy's 0.40. The band is asymmetric: 0.13 of slack
under it (to Medium 0.25), 0.02 over it (to Heavy 0.40).

**4 — Node spacing is a hidden hard constraint.** Three Medium gathers clustered at **6
studs** apart stack spatially to **peak 0.422 > 0.38** — the survivor reads *loud from
routine Medium work alone*, silently killing the lever. At ≥ 10 studs the peak stays under;
at ≥ `INFLUENCE_RADIUS` (24) each gather is fully isolated at 0.25.

**5 — Half-life is not a sensitivity.** Across the authored 15–60 s range, peak (0.40) and
the 30 s window are unchanged, because gathers are temporally well-separated. The lever does
not depend on half-life tuning.

## Metrics

| Metric | Value |
|---|---|
| Longest sub-0.38 window, realistic 3-Heavy run | **60.1 s** (need ≥ 30 s) → PASS, 2× margin |
| Heavy-gather time ≥ 0.38 (walking / standing) | 0.05 s / 2.23 s |
| Viable threshold band (quiet-AND-productive) | **[0.26, 0.40]**, width 0.14 |
| Headroom of authored 0.38 below Heavy 0.40 | **0.02 (5%)** — knife-edge |
| Min node spacing before Medium stacks > 0.38 | **~8–10 studs** (safe ≥ 24 = INFLUENCE_RADIUS) |
| Half-life sensitivity (15–60 s) | none (window stays 60.1 s) |

## Recommendation: PROCEED — with two constraints pinned

The n=2 disengage model does **not** need a redesign: **H.66 PASSES** (a ≥30 s sub-threshold
window survives the win-critical run with 2× margin) and **OQ.12 is answered** — a separating
value exists and 0.38 is inside the viable band. The scary coupling (Heavy 0.40 > threshold
0.38) turns out to be *intended and survivable*: the win material punctuates the field with
spikes too brief (≤2.2 s) to block a 30 s Disengage, encoding a real "you can't silently mine
the win material" tension rather than a structural trap.

But the prototype converts two *implicit* assumptions into *explicit, must-pin* constraints —
both currently unstated in the GDDs, both able to **silently kill the lever** if they drift:

1. **The knife-edge magnitude invariant.** The whole lever rests on
   `MAGNITUDE_GATHER_HEAVY (0.40) > effectiveQuietThreshold(2) (0.38) > MAGNITUDE_GATHER_MEDIUM
   (0.25)`, with only 0.02 between the first two. ED owns the magnitudes; PA owns the
   threshold; **nothing currently locks the relationship.** A startup config-gate must assert
   this ordering as a cross-GDD invariant (same tier as PA's existing D.1 gates). If Heavy
   drifts down or threshold(2) drifts up past 0.40, Heavy goes silent and quiet stops being a
   lever; if threshold(2) drifts below 0.25, routine Medium work becomes unavoidably loud.

2. **A node-spacing floor.** Resource Node placement / level design must guarantee a minimum
   separation between same-tier nodes (≥ ~10 studs hard, ≥ `INFLUENCE_RADIUS` 24 preferred), or
   spatial stacking of routine Medium gathers pushes the survivor over 0.38 with no Heavy
   involved. This is not pinned in RN or the level-design guidance today.

### If Proceeding (what to feed back into the docs)

- **PA + ED:** add the magnitude/threshold ordering invariant + a startup config-gate AC
  (mirrors PA H.14 / FIX-22 style). Tie `OQ.12` resolution to it. Update **H.66** to note
  explicitly that the assertion is measured in the **between-nodes movement state** and that
  Heavy-completion instants are *expected* to momentarily exceed 0.38 by design (so a tester
  doesn't sample at the gather instant and false-fail it).
- **Resource Node:** add a `NODE_MIN_SPACING` constraint (≥ ~10 studs, target ≥ 24) with a
  placement-validation AC; cross-link to ED `INFLUENCE_RADIUS`.
- **OQ.15 (loud-kiter at n≥3)** and the **per-gather-completion spike** remain to be checked
  with real emission timing in the Studio/runtime prototype, alongside the deferred Bucket A
  items (OQ.6 / OQ.14 / OQ.5).

### Lessons Learned

- The n=2 quiet lever is **structurally sound but tuning-fragile**: its viability is governed
  by a 0.02-wide knife-edge (Heavy vs threshold) and a level-geometry floor (node spacing),
  neither of which is currently a locked invariant. The prototype's value was not "does it
  work" (it does) but **surfacing the two silent-failure modes** so they become explicit gates
  before implementation rather than balance bugs discovered in playtest.
- The "scary" authored coupling (win material is inherently loud) is a *feature*: brief,
  unavoidable spikes during win-critical extraction are exactly the asymmetric-pressure the
  game's quiet-beats-loud pillar wants — provided the spike stays sub-`RETREAT_SUSTAIN`, which
  it does by ~14×.
```
```
Run: `python prototypes/predator-ai-quiet-lever/quiet_lever_sim.py`
