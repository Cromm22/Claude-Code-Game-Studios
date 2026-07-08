# Vertical Slice Scope

> **Status**: Draft — first scoping pass, Pre-Production
> **Last Updated**: 2026-07-06
> **Author**: producer (this session), pending game-designer/creative-director confirmation
> **Purpose**: Define the minimal thin playable cut of Terranova's core loop, per
> the Producer director's 2026-07-06 gate-check finding: "A vertical slice is a
> *thin* playable cut, not all seven systems at full GDD depth... the single
> biggest risk is over-scoping the slice."

---

## Why All 7 Systems, But Thin

Unlike a game where a vertical slice can validate one system in isolation (e.g.,
"just combat"), Terranova's core fantasy — the squad disturbs the ecology, the
ecology's predator hunts along that disturbance, oxygen pressure forces risk — is
inherently the *interaction* of Player Controller, Ecological Disturbance,
Predator AI, Resource Management, Resource Node, Crafting & Items, and HUD. There
is no meaningful subset of these seven that demonstrates the pillars without the
others. **The scoping lever here is depth per system, not which systems to cut.**
Every system below is scoped to its single load-bearing mechanic; every secondary
feature is explicitly deferred.

## In Scope (minimal implementation per system)

| System | In-Scope Mechanic | Explicitly Deferred |
|---|---|---|
| **Player Controller** | Movement, sprint (KB+M + gamepad only for the slice), lantern raise/lower, gather tap-hold, basic death/respawn (T5/T6, no spectator camera polish) | Full cross-platform input parity (touch can follow in Production), ping, emote wheel, cosmetics-visible variation |
| **Ecological Disturbance** | Spatial field + `Emit()` for sprint/lantern/gather, `GetHottestHotspot`, tier classification (Calm/Tense/Hunt), the `Humanoid.Died` fan-out | Flora chunk visual streaming polish, `TierCrossedEvent`/`OnDisturbanceBandCrossed` (if HUD's slice cut doesn't need the separate squad-aggregate signal — confirm during story breakdown), full N7/N8 ops-log monitoring |
| **Predator AI** | 4-state FSM (Patrol→Investigate→Hunt→Disengage) working end-to-end against ED's field, melee kill, no-one-shot guard | Full attribution/death-cause detail beyond the top-1 cause, eye-shine/bearing-privacy polish, cosmetic FSM animation refinement |
| **Resource Management** | Oxygen pool, a **flat drain rate** (not the full BCT-band-dynamic drain — see Scope Note below), death-cost deduction, grace timer | The Beacon-Charge-Tier accessor and per-band drain scaling (both blocked on an unwritten ADR anyway — see Resource Management epic) |
| **Resource Node** | Gather loop, a **single node tier** (not Light/Medium/Heavy), basic respawn | Multi-tier yield curves, dark-zone lantern-gate nuance, aggregate completion-flash tuning |
| **Crafting & Items** | Bench craft of the escape beacon (minimal recipe set — beacon + at most 1 support item), beacon activation, survival-window hold, win/lose banner | Full item/recipe catalog, cosmetic bench/beacon skins, `MAX_ACTIVE_BEACONS` multi-beacon logic (single beacon is sufficient for the slice) |
| **HUD** | Oxygen bar, disturbance meter, predator bearing chevron, squad roster, victory/defeat banner | FlashArbiter refinement beyond the basic WCAG ceiling, full colorblind-mode implementation, reduced-motion classification per element (documented in `design/ux/hud.md`, implemented post-slice) |
| **RunController** | `RunEndConditionRaised`/`RunEnded` wired from Player Controller only (wipe + victory) | The Crafting migration (still deferred per its own GDD) — Crafting's win/lose continues to route through PC directly for the slice, consistent with the current (non-migrated) design |
| **Save/Load — Cosmetic Persistence** | **Not needed for the slice at all.** No cosmetic purchase flow is required to validate the core loop. | Everything — this epic can be built any time before cosmetic content ships, independent of the slice timeline |

### Scope Note: Resource Management's flat-drain simplification

RM's epic has two blocking ADRs (the BCT-band accessor and the tick loop). Rather
than block the entire vertical slice on those, the slice can implement RM with a
**single flat drain rate** (no per-band scaling) — this still delivers the "oxygen
is a countdown pressure" fantasy and the D1 2-player kill-criterion is still
testable, just without the escalating-drain nuance. The two blocking ADRs should
still be written before Production begins (they're required for the real GDD
behavior), but they do not need to gate the slice itself.

## Primary Playtest Validation Targets

Per this session's `/gate-check` director panel, the slice's playtest should
specifically target:

1. **The 2-player BC4 oxygen-collapse kill-criterion** (Creative Director's #1
   flag) — is a lone survivor's win window actually survivable, or does it read
   as near-unrecoverable? This is the single biggest risk to both the core
   fantasy and the "Squad Is the Experience" pillar.
2. **Did the squad feel like a squad during gather?** (Resource Node's D.2
   dispersal tension, flagged by the Creative Director as a bounded but real
   Pillar-2 concern.)
3. **Core mechanic feel**: does quiet-vs-loud play as a meaningful choice, or
   does the predator's threat feel arbitrary? (Per `/gate-check`'s own Vertical
   Slice Validation checklist — this is the #1 cause of production failure per
   GDC postmortem data, and the reason a Vertical Slice gate exists at all.)

## What "Done" Looks Like for This Slice

Per the Pre-Production → Production gate's own Vertical Slice Validation
checklist (all must be YES):
- [ ] A human plays through the core loop without developer guidance
- [ ] The game communicates what to do within the first 2 minutes of play
- [ ] No critical "fun blocker" bugs exist
- [ ] The core mechanic feels good to interact with (subjective — ask the playtesters)
- [ ] At least one complete [start → challenge → resolution] cycle works end-to-end
- [ ] At least 3 playtest sessions are documented (`/playtest-report`)

## Sequencing Note (from the Producer's gate-check assessment)

Sprint 1 should be scaffolding, not feature work: epics (done, this session) →
this scope document (done, this session) → author the two blocking Resource
Management ADRs (or accept the flat-drain simplification above and defer them) →
author the four blocking Player Controller / Crafting ADRs named in their
respective epics, at least for whichever stories the slice actually needs →
begin implementation. Treating sprint 1 as feature implementation would derail
the phase, per the Producer's explicit warning.

## Open Questions

| Question | Owner | Resolution |
|---|---|---|
| Does the slice need the flat-drain RM simplification, or is it worth writing the BCT-band-accessor ADR before Sprint 1 instead? | producer + technical-director | Unresolved — recommend the simplification to avoid blocking Sprint 1 on an ADR, but flag for confirmation |
| Single gather-node tier for the slice — Light, or a purpose-built slice-only tier? | game-designer | Unresolved |
| Does the slice's HUD need `design/ux/hud.md`'s full element set, or a reduced subset? | ui-programmer + producer | Unresolved — recommend the reduced Must-Show set only (oxygen, disturbance, roster, predator chevron) plus the win/lose banner |
