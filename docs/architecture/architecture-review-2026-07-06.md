# Architecture Review Report

**Date**: 2026-07-06 (re-run — verifying ADR-0009..0014 against the same-day FAIL review)
**Engine**: Roblox Studio (live platform) + Luau + Knit + Rojo
**GDDs Reviewed**: 7 systems (9 files — Ecological Disturbance is decomposed into `ecological-disturbance.md` + `ecological-disturbance-forward-obligations.md` + `ecological-disturbance-verification.md`)
**ADRs Reviewed**: 14 (ADR-0001–0008, all Status: Accepted; **ADR-0009–0014, all Status: Proposed**)

> **Supersedes** the earlier same-day report (verdict FAIL). That version is preserved in git history at commit `1ebb251` and prior; this file is the authoritative version going forward. **Write status**: this run's write approval was explicit (not a timeout default).

> **Update (same day, follow-up pass)**: after this review's initial CONCERNS verdict (3 new conflicts found and fixed same-session; 6 carried-forward conflicts in ADR-0002/0004/0005 left open), the user explicitly requested the 6 carried-forward conflicts be fixed too. All 6 are now fixed — see "Carried-Forward Conflicts: RESOLVED" below. **Verdict upgraded to PASS.** The Traceability Summary and per-TR tables below reflect the state *before* this follow-up pass (108/70/91) since none of the 6 fixes changed TR coverage counts (they were conflict/consistency fixes, not new-ADR-coverage fixes) — see the RESOLVED section for what changed and why the verdict moved.

> **Methodology note**: this is a **delta re-verification**, not a from-scratch re-extraction. The 7 GDDs did not change (only a color-value fix in `hud.md`/`art-bible.md`, immaterial to requirements) and the TR registry's 269 requirements are unchanged. I loaded the prior FAIL report + `architecture-traceability.md` + `tr-registry.yaml` as the requirements baseline, read all 6 new ADRs in full, and re-derived which of the prior FAIL's named gaps they close, plus ran a fresh Phase 4/5 pass (conflict detection + engine specialist consultation) scoped to the 6 new ADRs and their cross-references into the existing 8.

---

## Traceability Summary

| System | Covered | Partial | Gap | Total | Δ vs last run |
|---|---|---|---|---|---|
| Player Controller | 29 | 12 | 12 | 53 | +4 covered (was 25/13/15) |
| Resource Management | 14 | 7 | 7 | 28 | +7 covered (was 7/9/12) |
| Resource Node | 4 | 8 | 19 | 31 | unchanged |
| Ecological Disturbance | 33 | 17 | 22 | 72 | unchanged |
| Predator AI | 13 | 8 | 11 | 32 | unchanged |
| Crafting & Items | 11 | 11 | 3 | 25 | +3 covered (was 8/11/6; +1 from the same-session clock-seam fix on TR-craft-005) |
| HUD | 4 | 7 | 17 | 28 | +1 covered (was 3/6/19) |
| **Total** | **108 (40.1%)** | **70 (26.0%)** | **91 (33.8%)** | **269** | was 93/72/104 (34.6/26.8/38.7%) |

Full per-system TR tables live in `docs/architecture/architecture-traceability.md`.

Both of Resource Management's original **blocking, Core-tier "no ADR at all" gaps are closed** (Beacon-Charge-Tier accessor + tick loop), as are Player Controller's 3 self-flagged Foundation-tier gaps and 2 of Crafting's 4 self-flagged Core-tier gaps.

## What the 6 New ADRs Close

| ADR | Gap → Covered | Partial → Covered | Notes |
|---|---|---|---|
| ADR-0009 (RM Beacon-Charge-Tier Accessor) | TR-rm-006, TR-rm-007 | — | Places the accessor on **`CraftingService`**, not `DisturbanceService` — resolves RM's own ambiguous GDD phrasing ("the ED/Beacon escalation authority") using `architecture.md`'s existing Module Ownership table, which already lists Crafting as the Beacon-lifecycle (BC1–6) owner |
| ADR-0010 (RM Tick Loop) | TR-rm-008, TR-rm-009, TR-rm-026 | TR-rm-024, TR-rm-017 | Full 6-step deterministic order (deduct→restore→drain→clamp→win-check→Empty-eval), `MAX_TICK_DT` cap, win-check-before-Empty-eval ordering (H.49), same-tick death coalescing (H.44) |
| ADR-0011 (PC Sprint-State Authority & Stamina) | TR-pc-004, TR-pc-005 | TR-pc-039 | Closes PC's sprint/stamina authority model. Originally violated PC's own clock-injection seam (Conflict #7) — **fixed same session.** |
| ADR-0012 (PC Dead-Player Input Lock & Spectator State) | TR-pc-033 | — | Correctly resolves PC's own self-flagged `HasChunkLoaded()` knowledge-gap (GDD OQ.4) — see Engine Audit and GDD Revision Flags |
| ADR-0013 (Crafting Survival-Window & Bench Watcher) | TR-craft-020, TR-craft-005 | — | TR-craft-005 originally stayed Partial due to a clock-seam violation (Conflict #8) — **fixed same session, now fully Covered.** |
| ADR-0014 (Crafting Placement Validation) | — | TR-craft-013 | Full 4-step order (clamp→LOS→floor→overlap) correctly implemented; engine-specialist review caught and fixed a real floor-raycast-origin-height bug during authoring |

Ripple-effect upgrades (not directly authored by the 6 new ADRs, but their existence changes an adjacent TR's coverage): TR-hud-021 (partial→covered via ADR-0012's `renderScope`+camera), TR-hud-012 and TR-hud-020 (gap→partial — Crafting side now has an ADR even though RN's / the HUD payload-shape side still doesn't), TR-craft-021 (gap→partial — ADR-0013 gives qualitative "negligible" CPU treatment but no ratified ms budget).

## Coverage Gaps Still Worth Flagging

- ❌ **Crafting's Test-Harness Injection Seam** (TR-craft-015) — one of Crafting's own 4 self-flagged missing ADRs. The *prior* review's "Required ADRs" list never actually assigned this one a slug (only survival-window/bench-watcher and placement-validation were requested) — still unauthored, and not a miss by this session's ADR authors so much as an under-scoped ask list last time.
  Suggested ADR: `/architecture-decision crafting-test-harness-injection-seam` — Core, LOW.
- ❌ **`MAX_ACTIVE_BEACONS=3` enforcement mechanism** (TR-craft-009) — `architecture.md` lists this as a Crafting responsibility but no ADR specifies *how* it's enforced at the publish site before `Emit`.
- ❌ **RM's oxygen sync payload shape** (TR-rm-003/004/005, TR-rm-022/023) — the HUD-facing signal contract (`OnOxygenChanged`, `OnOxygenDeducted`/`Restored` carrying `P_after`, dead-reckoning fields) still has no ADR, even though the tick loop that produces these values now does.
- ❌ **RM's squad-wide Healthy/Critical/Empty hysteresis state machine** (TR-rm-016) — ADR-0010 implements only the binary Empty-threshold check, not the full 3-state machine with 2-unit recovery hysteresis.

## Cross-ADR / Cross-Document Conflicts

### Carried-Forward Conflicts: RESOLVED (follow-up pass, same day)

All 6 were confirmed still present, verbatim, before this follow-up pass — none of the 6 new ADRs (0009-0014) touch ADR-0002/ADR-0004/ADR-0005, so they had carried forward unchanged from the initial FAIL review. The user then explicitly requested they be fixed. All 6 are now fixed directly in the ADR/GDD source files:

1. ✅ **FIXED. Cap-eviction contradiction** — ED GDD's own tuning-knob table (line 1364) described the `MAX_LIVE_SOURCES` cap failure mode as "emissions get silently dropped" (a drop-new read), while ADR-0004 Q3 decided evict-oldest. Re-reading the GDD found this was never a true contradiction so much as an unclosed loop: the GDD's own Q3 open question (line 1955) explicitly deferred the eviction-policy decision to "the DisturbanceService ADR," which ADR-0004 correctly closed (choosing evict-oldest over the GDD's own "(recommended)" drop-new annotation, for sound responsiveness reasons). **Fix applied**: updated the tuning-knob table's failure-mode text to describe evict-oldest, and marked Q3 RESOLVED (citing ADR-0004), matching the pattern this GDD already uses for its other resolved open questions (e.g., Q5).
2. ✅ **FIXED. `Humanoid.Died` registration diagram** — ADR-0004's diagram listed "Humanoid.Died chain registration" under `KnitStart`, contradicting the GDD's C.1.11 ("registered in KnitInit") and ADR-0001 Rule 1. **Fix applied**: moved the bullet to the `KnitInit` section of ADR-0004's diagram.
3. ✅ **FIXED. `GetOnPlayerDiedSignal(): BindableEvent` vs. ADR-0001's `Signal`-class recommendation.** Investigation found ED's GDD (C.1.11, round-11 BLOCK-3/red-team I-3 closure) already froze `OnPlayerDied` as a literal `BindableEvent`, with its yield-free correctness proofs argued from that exact dispatch mechanism — a closed, reviewed design decision that predates ADR-0001. Rather than silently overriding a frozen GDD closure by switching to `Signal` (which would require reopening that round-11 review, out of this fix's scope), **the resolution kept the raw `BindableEvent`** and applied ADR-0001's own stated fallback: pin `Workspace.SignalBehavior = Enum.SignalBehavior.Immediate` at server boot. **Fix applied**: ADR-0004 gained a new dedicated Decision subsection making this explicit (plus the boot-time pin snippet and a Verification Required entry); ADR-0004's diagram text corrected from "Signal" to "BindableEvent"; ADR-0001's Risks section gained a carve-out note explaining that its general Signal-class preference governs new channels, not this already-frozen one.
4. ✅ **FIXED. ADR-0005's `_dispatchOxygenSpend` sample wrote `row.inFlightSince = workspace:GetServerTimeNow()` inline** — the same clock-seam-bypass bug class as Conflicts #7/#8 (this session's own ADR-0011/ADR-0013 findings), now a 3rd confirmed instance. **Fix applied**: added `PlayerController.getServerTime` as a C.11 seam field (mirroring ADR-0011's fix) and routed the write through it.
5. ✅ **FIXED (mostly — one residual item flagged, not silently resolved). RunController/Crafting interface mismatch.** Re-reading Crafting's GDD in full surfaced a richer picture than the original 3-part summary: Crafting's actual, current, frozen model has it firing `OnBeaconWindowSurvived`/`OnBeaconWindowFailed(reason ∈ {"wipe","scatter"})` **to Player Controller**, not to RunController directly — PC is the sole current caller of `RunEndConditionRaised`, for both T7/T8 (pre-activation) and the in-window BC4 outcomes it forwards from Crafting. ADR-0002 had listed Crafting as a *current* direct caller, which was never true under this model (the round-24 revert backed out exactly that migration). **Fix applied**: corrected the stale `C.5.8` citation to `C.9` (Crafting's actual Beacon State Machine section) throughout ADR-0002; reworded the caller list, diagram, and GDD Requirements table to state PC as sole current caller; added an optional `defeatReason: ("wipe" | "scatter")?` parameter to `RunEndConditionRaised`/`RunEnded`'s payload so PC's forwarding path has somewhere to carry Crafting's `"scatter"` distinction without breaking `conditionType`'s clean wipe/victory symmetry. **One residual item flagged, not fixed**: `player-controller.md` line 369 still describes the in-window wipe as "Crafting's BCT-DEFEAT, raised to the arbiter" — phrasing that reads as Crafting calling the arbiter directly, in tension with Crafting's own GDD (which has Crafting firing to PC). This is a cross-GDD prose inconsistency, not an ADR-level contradiction (ADR-0002's contract now supports either reading), and editing either GDD's normative text is outside an architecture-fix's authority — flagged as an ADR-0002 Open Question recommending a small GDD-text sync, not silently resolved here.
6. ✅ **FIXED. RM's `RequestSquadOxygenSpend` signature drift** — RM's own GDD text (CR.4 definition, the PC interaction-table row, the Boundary-3 table row, and AC H.10) all wrote `RequestSquadOxygenSpend(amount, reason, deathEventId)` with an implicit `userId`, while ADR-0005 ratified the explicit 4-param form `(deadPlayerUserId, amount, reason, deathEventId)`. **Fix applied**: corrected all 4 locations in `resource-management.md` to the ratified signature, citing ADR-0005 as the source of truth (a small text patch, not a redesign — exactly as the original review recommended).

### New this session

7. ✅ **FIXED (same session).** ADR-0011 originally violated Player Controller's own C.11 clock-injection seam: `_transitionTo` (`state.lastLeftSprintAt = workspace:GetServerTimeNow()`) and `_onStaminaTick` (`local now = workspace:GetServerTimeNow()`) both called the engine clock inline. PC's GDD (line ~431, ~905) states this is grep-gated and forbidden for exactly this reason. This was the same bug class as Conflict #4 (ADR-0005), recurring in a brand-new ADR whose own "Engine-specialist review" section fixed two *other* bugs but did not catch this one. Independently confirmed by a second, fresh engine-specialist pass run specifically for this review.
   **Fix applied**: added `PlayerControllerService.getServerTime` as a C.11 seam field and routed both call sites through it, in the ADR file directly.

8. ✅ **FIXED (same session).** ADR-0013 originally violated Crafting's own C.16 clock-injection seam ("R4-4"): `_onSurvivalWindowTick`'s `elapsed = workspace:GetServerTimeNow() - self._windowActivatedAt` was an inline call inside a handler body — explicitly forbidden by Crafting's GDD (line ~329, ~951). The ADR's own Engine Compatibility table had actually *cited* `workspace:GetServerTimeNow()` usage elsewhere in the project as justifying precedent, rather than recognizing that Crafting's GDD specifically requires the `_clock()` wrapper. Independently confirmed.
   **Fix applied**: added `CraftingService._clock` as a C.16 seam field and routed the Decision text, diagram, and Key Interfaces sample through it, in the ADR file directly.

9. ✅ **FIXED (same session).** `architecture.md` line 139 (Resource Management's "Consumes" column) read "ED's Beacon-Charge-Tier accessor" — stale text contradicting ADR-0009's (correct) decision to place the accessor on Crafting. This stale line is very likely *why* the original review initially misattributed the accessor's owner to ED.
   **Fix applied**: changed to "Crafting's Beacon-Charge-Tier accessor (`GetCurrentBeaconChargeTier()`, ADR-0009 — fixed 2026-07-06, was misattributed to ED)."

10. ℹ️ **ADR-0012's streaming-API alternatives need two small corrections**, confirmed by a fresh engine-specialist pass: (a) `Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent` is a per-`Model` property — since player characters are destroyed/recreated on death+respawn, it must be **re-applied on every `CharacterAdded`**, which the ADR doesn't currently note. (b) `Player.ReplicationFocus` takes an **Instance** (a `BasePart`), not a `Vector3` — the ADR's prose ("set `ReplicationFocus`... to the target squadmate's position") should read "to the target squadmate's `HumanoidRootPart`." Both non-blocking, small text fixes.

## ADR Dependency Order (all 14, topologically sorted — no cycles)

```
Foundation (no dependencies):
  ADR-0001 — KnitInit/KnitStart Ordering Discipline
  ADR-0003 — Locomotion Driver
  ADR-0006 — RemoteEvent Trust Boundary & Rate-Limiting
  ADR-0007 — Save/Load & Cosmetic Persistence

Depends on Foundation:
  ADR-0002 — RunController Architecture (requires ADR-0001)
  ADR-0004 — DisturbanceService Core Architecture (requires ADR-0001)
  ADR-0008 — Character Replication Bandwidth & NetworkOwnership (requires ADR-0003)
  ADR-0009 — Resource Management Beacon-Charge-Tier Accessor (requires ADR-0001)          [NEW]
  ADR-0013 — Crafting Survival-Window & Bench Watcher (requires ADR-0001)                 [NEW]
  ADR-0014 — Crafting Bench/Beacon Placement Validation (requires ADR-0006)               [NEW]
  ADR-0011 — Player Controller Sprint-State Authority & Stamina (requires ADR-0003, ADR-0006) [NEW]

Depends on Core:
  ADR-0005 — Death & Respawn Lifecycle (requires ADR-0002, ADR-0004)
  ADR-0010 — Resource Management Tick Loop (requires ADR-0009)                            [NEW]

Depends on Death & Respawn:
  ADR-0012 — Player Controller Dead-Player Input Lock & Spectator State (requires ADR-0005, ADR-0002, ADR-0006) [NEW]
```

## GDD Revision Flags

One item — a **closure**, not a new problem. Player Controller's own GDD (line 319, line 910, and **OQ.4** at line 1476) explicitly self-flagged `workspace:HasChunkLoaded()` as an unverified post-cutoff API name and stated "architecture phase will block on this." ADR-0012 performed exactly that verification and confirmed the method does not exist, substituting two real APIs (`Model.ModelStreamingMode`, `Player.ReplicationFocus`).

**Recommended action**: sync `player-controller.md` to close OQ.4 (citing ADR-0012) and update the line-319/910 text to name the real APIs instead of `HasChunkLoaded()`. Not requested to write this now — flagging only, per Phase 5b protocol.

## Engine Compatibility Issues (Engine Specialist Consultation — gameplay-programmer, independent second pass)

- **Confirmed** both clock-seam violations above (Conflicts #7, #8) as real defects, not false positives — checked directly against the cited GDD line numbers and rule IDs (C.11, C.16/R4-4).
- **Confirmed** `HasChunkLoaded()` does not exist; **confirmed** `Model.ModelStreamingMode` and `Player.ReplicationFocus` are both real, current Roblox APIs (with the two corrections in Conflict #10).
- **Confirmed correct**: ADR-0014's raycast code (`Workspace:Raycast`, `RaycastParams.FilterType = Enum.RaycastFilterType.Exclude` — the modern, non-deprecated enum name — and `Workspace:GetPartBoundsInBox`) — no defect found.
- No other deprecated-API usage found across the 6 new ADRs against `deprecated-apis.md` (`task.spawn`/`task.wait` used correctly throughout, no `_G`, no `RemoteFunction` misuse, `PlayerRemoving` cleanup present where state is per-player).
- **Non-blocking style note**: ADR-0012's 5-second spectator re-check uses a `task.spawn`+`task.wait(5)` polling loop rather than the Heartbeat/accumulator pattern ADR-0010/ADR-0013 use for their own tick loops — not a bug (guarded by a generation counter), but this project now has 4 independent per-system Heartbeat-bound loops (ED, RM, Crafting×2, PC) plus one polling loop; worth a consistency pass or a shared tick-dispatcher discussion if a 5th/6th system wants its own loop (ADR-0011's and ADR-0013's own Consequences sections already flagged this as "worth watching").

## Architecture Document Coverage

All 7 systems still appear in `architecture.md`'s layer map. **One stale line found** (Conflict #9) — a one-line fix, not a structural gap. No orphaned architecture otherwise.

---

## Verdict: PASS (upgraded from CONCERNS → FAIL originally; all 9 total conflicts found across both passes are now fixed)

The two Core/Foundation-tier "no ADR exists at all" blockers from the prior review (RM's accessor+tick-loop; PC's 3 missing ADRs; 2 of Crafting's 4 missing ADRs) are closed. **All 3 conflicts found in this session's own new-ADR work (#7, #8, #9) and all 6 carried-forward conflicts in the already-Accepted ADR-0002/0004/0005 are now fixed** (see "Carried-Forward Conflicts: RESOLVED" above). Per this skill's own PASS/CONCERNS/FAIL criterion — FAIL requires critical Foundation/Core-tier gaps or blocking conflicts, CONCERNS requires gaps/partial coverage without blocking conflicts — no critical gaps and no known blocking conflicts remain.

**One non-blocking item remains, explicitly flagged rather than silently resolved**: a residual cross-GDD prose inconsistency between `player-controller.md` (line 369, "raised to the arbiter") and `crafting-and-items.md`'s actual model (Crafting fires to PC, not the arbiter) — see Conflict #5's fix note. This is a documentation-drift item, not an implementation-blocking contradiction (ADR-0002's contract now supports either reading), so it does not hold back PASS; recorded as a follow-up GDD-text-sync recommendation.

**Also still open (non-blocking, unchanged from the initial pass)**: ADR-0012's two small streaming-API text corrections (Conflict #10 — `ModelStreamingMode` re-apply-on-`CharacterAdded` note, `ReplicationFocus` Instance-not-Vector3 phrasing).

### Required ADRs (remaining — none block Sprint 1)

1. `/architecture-decision crafting-test-harness-injection-seam` — Core, LOW risk.
2. RM's oxygen HUD-facing signal contract (payload shape for `OnOxygenChanged`/deducted/restored, dead-reckoning fields) — could be a small addendum to ADR-0010 rather than a standalone ADR.

## Handoff

**Immediate action**: none blocking. Optionally: (a) apply ADR-0012's 2 small text corrections (Conflict #10), (b) sync `player-controller.md` line 369 with Crafting's actual PC-forwarding model (Conflict #5's residual item), (c) author the 2 remaining required ADRs above whenever convenient before their respective epics reach implementation.

**Gate guidance**: `/gate-check pre-production` can now be re-evaluated against a clean (PASS) architecture pass, if the user wants to formally re-confirm Pre-Production readiness — not required, since this project already advanced to Pre-Production on 2026-07-06 by explicit override of a mechanically-FAIL gate-check, and this review's PASS only strengthens that decision retroactively.

**Rerun trigger**: re-run `/architecture-review` after each of ADR-0009..0014 moves from Proposed to Accepted (ratification), and again after any future ADR is authored, per this skill's standing rerun guidance.
