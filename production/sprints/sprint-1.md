# Sprint 1 (2026-07-06 to 2026-07-20, 2-week sprint)

> **Capacity assumption**: Solo dev, 2-week sprint (~10 total days, 20% buffer = 8 available days for planned work). **PENDING RATIFICATION** — adopted on a 60s `AskUserQuestion` timeout, per this project's established precedent; confirm or amend team size / sprint length before treating this as final.

> ⚠️ **No QA Plan**: This sprint was started without a QA plan (`production/qa/qa-plan-sprint-1.md` does not exist — checked before writing this document). Run `/qa-plan sprint` before the last Must-Have story is implemented. The Production → Polish gate requires a QA sign-off report, which requires a QA plan. This warning is itself the Phase 5 QA Plan Gate's default fallback (option B — "skip for now, warn"), adopted because the interactive confirmation for this choice also timed out; running `/qa-plan sprint` itself was deliberately NOT triggered automatically since that's a separate, substantial skill invocation this session was not explicitly asked to run.

> ⚠️ **PR-SPRINT feasibility gate skipped** — Lean review mode (per `production/review-mode.txt`) skips the producer feasibility spawn for non-phase-gate sprint plans. The Must-Have list below is flagged as running ~44% over the stated 8-day budget; treat this as the manual equivalent of a CONCERNS verdict — see Risks.

## Sprint Goal

Stand up the minimal cross-service spine — RunController's event-fan-in arbiter, Ecological Disturbance's emission-intake-and-death-fanout core, and Player Controller's movement/death/respawn loop — so a player can move, sprint, die, and respawn with the disturbance-emission and death-event contracts flowing correctly between all three Foundation-layer services.

## Capacity

- Total days: 10 (solo dev, 2-week sprint)
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days

## Tasks

### Must Have (Critical Path) — estimated 11.5 days (**flags over the 8-day budget by ~3.5 days / 44% — see Risks**)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| RC-001 | RunController Core Aggregator (RunEndConditionRaised, latch, defeatReason) | gameplay-programmer | 0.5 | None | `production/epics/runcontroller/story-001-core-aggregator.md` |
| RC-002 | GetRunEndedSignal Accessor & KnitInit/KnitStart Subscriber-Safety | gameplay-programmer | 0.5 | RC-001 | `production/epics/runcontroller/story-002-getrunendedsignal-accessor.md` |
| ED-001 | Constants Module, Service Bootstrap & 5Hz Field-Update Loop Driver | gameplay-programmer | 1.0 | None | `production/epics/ecological-disturbance/story-001-constants-bootstrap-field-update-loop.md` |
| ED-002 | Emission Schema & Server-Authoritative Emit() Intake | gameplay-programmer | 1.0 | ED-001 | `production/epics/ecological-disturbance/story-002-emission-schema-emit-intake.md` |
| ED-003 | Spatial Hash Grid, Live-Source List & Cap Eviction | gameplay-programmer | 1.0 | ED-001, ED-002 | `production/epics/ecological-disturbance/story-003-spatial-grid-live-source-cap-eviction.md` |
| ED-010 | Humanoid.Died Monopoly & OnPlayerDied Fan-out | gameplay-programmer | 1.0 | ED-001, ED-004* | `production/epics/ecological-disturbance/story-010-humanoid-died-monopoly-onplayerdied-fanout.md` |
| PC-001 | Locomotion & Sprint-State Authority + Stamina + Ghost-Sprint Guard | gameplay-programmer | 1.5 | None | `production/epics/player-controller/story-001-locomotion-sprint-stamina-authority.md` |
| PC-003 | Disturbance Emission Publisher (Sprint/Light Pulses) | gameplay-programmer | 1.5 | PC-001, PC-002*; ED-002/003 | `production/epics/player-controller/story-003-disturbance-emission-publisher.md` |
| PC-004 | Death-Cost Reconciliation Core (deathEventId + State Machine) | gameplay-programmer | 2.0 | ED-010; RM's oxygen-spend receiver (cross-epic, not in this sprint — stub/mock) | `production/epics/player-controller/story-004-death-cost-reconciliation-core.md` |
| PC-005 | Death/Respawn Side-Effects & Cross-Service Signals (T5/T6) | gameplay-programmer | 1.5 | PC-004 | `production/epics/player-controller/story-005-death-respawn-side-effects.md` |

**Must-Have total: 11.5 days.**

\* ED-010's own story lists "Depends on: 001, 004" (Story 004 = Attribution Archive) — its own `_deathLockSnapshot` write only needs the predator-lock registry (Story 011) to be meaningful long-term, but the core `Humanoid.Died` fan-out mechanism itself does not require Story 004 to be complete to compile and fire correctly for PC's purposes; Story 004 is listed as Should-Have below and can follow in parallel without blocking PC-004/005's own work against a stubbed/no-op snapshot. \* PC-003 depends on PC-002 (lantern) per its story file, but Sprint 1 defers PC-002 to Should-Have — PC-003's Sprint-pulse half can be implemented and tested independently; its Light-pulse half is blocked until PC-002 lands (flag as a partial-completion risk, not a hard blocker for the sprint goal).

### Should Have — estimated 12.5 days (Sprint 2 candidates)

| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| ED-004 | Attribution Archive (write-once, TTL, count-cap FIFO) | gameplay-programmer | 1.0 | ED-002, ED-003 | story-004 |
| ED-005 | Decay Formula, Spatial Falloff & fieldValue() | gameplay-programmer | 1.0 | ED-003 | story-005 |
| ED-006 | Tier Classification w/ Hysteresis, TierCrossedEvent | gameplay-programmer | 1.0 | ED-005 | story-006 |
| ED-007 | Squad Aggregate t & GetSquadAggregateT | gameplay-programmer | 0.5 | ED-005 | story-007 |
| ED-008 | GetHottestHotspot Query & topContributorsAt | gameplay-programmer | 1.0 | ED-003, ED-005 | story-008 |
| ED-009 | OnDisturbanceBandCrossed Signal | gameplay-programmer | 0.5 | ED-006, ED-007 | story-009 |
| PC-002 | Lantern Axis, Light-to-Gather Gate & Tap-Hold Gather | gameplay-programmer | 1.0 | None | story-002 |
| PC-006 | Path B Disconnect Predicate, Oxygen Grace Timer & Respawn Wait | gameplay-programmer | 1.5 | PC-004; RM (cross-epic) | story-006 |
| PC-007 | Dead-Player Input Locks & renderScope (S4/S5) | gameplay-programmer | 1.0 | PC-004, PC-005 | story-007 |
| PC-008 | Minimal Spectator Camera | gameplay-programmer | 1.5 | PC-007 | story-008 |
| PC-009 | Run-End Contract (T7 Wipe / T8 Victory) | gameplay-programmer | 1.5 | PC-004, PC-005; RunController (RC-001/002, done Sprint 1); Crafting (cross-epic, not yet started) | story-009 |

### Nice to Have — estimated 15.5 days (deferred; needs Predator AI / HUD / Crafting epics to exist to be meaningful)

| ID | Task | Est. Days | Notes |
|----|------|-----------|-------|
| ED-011 | RegistrationHandshake Module & Predator-Lock Registry | 1.5 | Needs Predator AI epic to consume it |
| ED-012 | Death Attribution Resolution & DeathAttributionPayload | 1.0 | Needs HUD epic to consume it |
| ED-013 | HUD Meter & Alert Wiring | 1.0 | Needs HUD epic to exist |
| ED-014 | StreamingEnabled Chunk Membership & Flora Push | 1.5 | Needs flora rendering subsystem |
| ED-015 | Beacon Stationary-Squad Hunt-Floor Cap | 2.0 | Needs Crafting's Beacon to exist |
| ED-016 | Security Hardening — CI Lints & Test-Seam Enforcement | 1.5 | Best done once 011-014 land |
| ED-017 | Performance Instrumentation & Ops-Log Observability | 1.5 | Needs a fuller system to profile meaningfully |
| PC-010 | RemoteEvent Trust Boundary Application (retrofit) | 1.0 | Hardening pass, not core-loop-blocking |
| PC-011 | NetworkOwnership & Character Replication Bandwidth | 1.0 | Needs the `/prototype predator-ai` spike for real numbers |
| PC-012 | Quick-Ping | 1.0 | Secondary feature |
| PC-013 | Emote Wheel & Cosmetic Boundary | 1.0 | Secondary feature |
| PC-014 | Haptic Feedback | 0.5 | Polish |
| PC-015 | C.12 Contract-Completeness CI Hook Extension | 1.0 | Needs all 14 other PC stories done first |

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| N/A | This is Sprint 1 — no previous sprint exists | — |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Must-Have list (11.5 days) exceeds the 8-day available capacity by ~44% | High (by construction) | Sprint likely runs 3-4 days over, or 2-3 Must-Have stories slip to Sprint 2 | Flagged explicitly rather than silently undercounted (PR-SPRINT feasibility gate was skipped per lean review mode — this is the equivalent manual flag). Recommend trimming ED-010 and PC-005 to Should-Have if a strict 8-day cap must hold, since a partial death/respawn loop (without full T5/T6 side-effects) is still a defensible Sprint 1 cut. |
| PC-004 (Death-Cost Reconciliation Core) depends on Resource Management's `RequestSquadOxygenSpend` receiving service, which has no epic/stories yet | High | PC-004's oxygen-deduction call must be mocked/stubbed for Sprint 1 — real RM integration deferred | Story's own Implementation Notes already scope this as a cross-epic dependency; use a mock RM service in PC-004's tests, exactly as the story's QA Test Cases already assume |
| PC-009 depends on Crafting's `OnEscapeBeaconActivated`/`OnBeaconWindowSurvived` stub emitters, and Crafting has no stories yet either | Medium (only relevant if PC-009 is pulled forward from Should-Have) | N/A for Must-Have scope this sprint | Already mocked per PC-009's own story design; not a Must-Have risk this sprint |
| No previous sprint velocity data exists — all estimates are first-pass, unvalidated | High | Actual completion rate may differ significantly from estimates | Treat Sprint 1 as a calibration sprint; `/retrospective` after close should specifically capture actual-vs-estimated days per story to calibrate Sprint 2's estimates |
| Capacity assumption (solo dev, 2-week sprint) itself was adopted on a user-response timeout, not confirmed | Medium | The whole plan's sizing could be wrong if the real team/timeline differs | Explicitly flagged as PENDING RATIFICATION at the top of this document; re-confirm with the user at the next opportunity |

## Dependencies on External Factors

- The `/prototype predator-ai` spike (mentioned in ADR-0003/ADR-0008 as a pending pre-production task) has not run yet — PC-001's `Humanoid.WalkSpeed` mid-sprint reassignment smoothness and PC-011's bandwidth baseline both remain provisional until it does. Not blocking for Sprint 1's Must-Have scope.
- Resource Management and Crafting & Items epics have no stories yet — several Should-Have/Nice-to-Have PC stories name them as cross-epic dependencies (mocked for now, real integration is future work).

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-1.md`) — **currently missing, see QA Plan Gate warning above**
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
