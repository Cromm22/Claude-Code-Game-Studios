# QA Sign-Off Report — Sprint 1

**Sprint**: Sprint 1 (2026-07-06 → 2026-07-20) — "Stand up the minimal cross-service spine"
**Cycle**: `/team-qa sprint` close-out (retroactive; sprint began without a QA plan, gap closed this cycle)
**Date**: 2026-07-11
**Build/commit**: `46103e0`, branch `crafting-round2-patch`
**QA Lead sign-off**: Reviewed and signed below. This report supersedes the tally error in `production/qa/smoke-2026-07-11.md`'s original summary line; all figures here are drawn from `production/sprint-status.yaml` directly.

---

## 1. Scope

- **In scope**: 22 done stories across 3 Foundation epics (RunController, Ecological Disturbance, Player Controller).
- **Out of scope**: 12 backlog stories (unimplemented — nothing to test) and live-build manual QA (no bootable build exists; `Packages/` unvendored — TD-019).
- **Strategy approved by**: user, 2026-07-11 (Phase 2 gate). Evidence audit performed by qa-lead against the approved strategy; no deviations.

---

## 2. Test Coverage Summary

### By Epic

| Epic | Stories Done | Result |
|---|---|---|
| RunController | 2 | PASS (2/2) |
| Ecological Disturbance | 11 | PASS (11/11) |
| Player Controller | 9 | PASS (9/9) |
| **Total** | **22** | **PASS (22/22)** |

### Per-Story Detail

| Story | Type | Test Evidence | Result |
|---|---|---|---|
| rc-1 Core Aggregator | Logic | `tests/unit/runcontroller/` (aggregator suite) | PASS |
| rc-2 GetRunEndedSignal | Integration | `tests/integration/runcontroller/get_run_ended_signal_test.luau` | PASS |
| ed-1 Constants/Bootstrap | Integration | `tests/integration/ecological-disturbance/service-bootstrap-config-validation_test.luau` | PASS |
| ed-2 Emit() intake | Logic | `tests/unit/ecological-disturbance/emission-schema-server-emit-intake_test.luau` | PASS |
| ed-3 Spatial grid | Logic | `tests/unit/ecological-disturbance/spatial-grid-live-source-cap-eviction_test.luau` | PASS |
| ed-4 Attribution archive | Logic | `tests/unit/ecological-disturbance/attribution-archive-ttl-cap_test.luau` | PASS |
| ed-5 Decay/fieldValue | Logic | decay/falloff suites (incl. NaN-clamp regression) | PASS |
| ed-6 Tier classification | Integration | `tests/integration/ecological-disturbance/tier-crossed-signal-subscription_test.luau` | PASS |
| ed-7 Squad aggregate t | Logic | `tests/unit/ecological-disturbance/squad-aggregate-t-accessor_test.luau` | PASS |
| ed-8 Hottest hotspot | Logic | hotspot query suite | PASS |
| ed-9 Band-crossed signal | Integration | `tests/integration/ecological-disturbance/disturbance-band-crossed-signal_test.luau` | PASS |
| ed-10 Died monopoly/fan-out | Integration | `tests/integration/ecological-disturbance/humanoid-died-monopoly-onplayerdied-fanout_test.luau` | PASS |
| ed-14 Streaming/flora push | Integration | `tests/integration/ecological-disturbance/streaming-chunk-membership-flora-push_test.luau` | PASS |
| pc-1 Locomotion/stamina | Logic | locomotion/stamina suite | PASS |
| pc-2 Lantern/gather gate | Logic | `tests/unit/player-controller/lantern-gather-gate_test.luau` | PASS |
| pc-3 Emission publisher | Logic | `tests/unit/player-controller/disturbance-emission-publisher_test.luau` | PASS |
| pc-4 Death-cost reconciliation | Logic | `tests/unit/player-controller/death-cost-reconciliation-core_test.luau` | PASS |
| pc-5 T5/T6 side-effects | Integration | `tests/integration/player-controller/death-respawn-side-effects_test.luau` | PASS |
| pc-6 Path B/grace timer | Logic | `tests/unit/player-controller/path-b-oxygen-grace-timer_test.luau` | PASS |
| pc-7 Input locks/renderScope | Integration | `tests/integration/player-controller/dead-player-input-locks-renderscope_test.luau` | PASS |
| pc-9 Run-end contract | Integration | `tests/integration/player-controller/run-end-contract_test.luau` | PASS |
| pc-11 NetworkOwnership/bandwidth | Integration | `tests/integration/player-controller/networkownership-bandwidth_test.luau` | PASS (2 PERF ACs deferred to prototype spike, per story's own Out-of-Scope — not a gap) |

**Automated suite**: 24/24 test files, exit 0. Independently re-verified 3 times this close-out (smoke check, qa-lead evidence audit, coordinator).

**Manual QA**: N/A-by-strategy this cycle (no bootable build exists — stage-appropriate, per ADR-0008/Pre-Production state). The evidence audit + documentation-consistency pass served as this cycle's manual-equivalent labor:
1. Automated-evidence audit — qa-lead independently re-ran the suite and cross-checked all 22 Completion Notes against actual evidence files. No phantom claims found.
2. Documentation-consistency QA — 1 finding (below), corrected same-session.

---

## 3. Findings / Bugs

| ID | Title | Severity | Status | Notes |
|---|---|---|---|---|
| QA-F1 | Smoke report / session-state "15 done stories" tally error vs. authoritative 22 (`production/sprint-status.yaml`) | S4 - Trivial | Fixed | Documentation-only, no code or test impact. Corrected same-session in `production/qa/smoke-2026-07-11.md` (see its dated correction footnote). Process note recorded: derive done/backlog counts programmatically from the yaml, never by hand-tally, to prevent recurrence. |

No S1/S2/S3 bugs open. No entries required in `production/qa/bugs/` — this was a documentation defect caught and fixed within the same QA cycle, not a shippable-code bug.

**0 stories FAIL. 0 stories BLOCKED.**

---

## 4. Sign-Off Conditions (Carried Obligations)

These do not block this sprint's verdict but must not be silently dropped. They are scoped to the first successful Studio/Rojo boot (budget ~2-4 hours; natural home: the `/prototype predator-ai` spike or a TD-019 vendoring micro-story + boot):

1. `Player:LoadCharacter()` synchronous-completion contract (pc-4/pc-5 respawn path)
2. `Humanoid.UseJumpPower`/`JumpHeight` per-rig behavior vs. the capture-and-restore jump lock (pc-7, TD-017-adjacent)
3. `game:BindToClose` live firing → Abandoned transitions (pc-4/pc-9)
4. Vendored Signal `:Fire()` synchronous-until-first-yield semantics (pc-9 wipe-before-respawn ordering, TD-019)
5. PERF H.28 (CPU: 4-player, 300-tick Heartbeat, injected RM fault) + H.29 (bandwidth: 60-frame steady-state) — currently `pending()` in pc-11's suite
6. Live RemoteEvent rate-limit behavior under real network conditions (logic already automated)
7. H.26 (pc-1 locomotion feel) + H.32 (pc-3 manual-device) placeholders

---

## 5. Risk Callouts (carried into next cycle)

- **Highest watch — TD-015 + TD-017 (bundled)**: Both are RM-async activation-class gaps (stale-dispatch race / commit-gated S4 input-lock window). Both are dormant only because RM is currently a synchronous stub; both go live the moment the RM epic lands a real async `RequestSquadOxygenSpend`. A single ruling covering both is needed before or at that point.
- **TD-014 + TD-018 — before HUD**: `OnPlayerDied`'s 2-arg payload (missing `deathTimestamp`/`deathEventId`) and `SquadStateSnapshot`'s stale exported type must be fixed before any HUD/analytics story consumes `GetRunEndedSignal()` or the death-broadcast signal — a breaking-change pass later is strictly more expensive.
- **TD-005 — mobile/touch data untrustworthy**: `platform` is hardcoded `"pc"` at the emission-heartbeat call site; do not trust any mobile/touch playtest results until a real platform-classification signal lands.
- **TD-019 — vendoring**: `Packages/` is empty; recommend a dedicated micro-story to vendor Knit/Signal before any Studio boot is attempted, rather than folding it silently into a feature story.
- **TD-016 — PA ruling**: PredatorService seams are userId-keyed in pc-5's implementation vs. `(player)`-keyed in the approved PC GDD cross-service table. Needs reconciliation at the Predator AI epic's first touch (either GDD text sync or ratify userId-keyed explicitly).
- **CI never fired**: `.github/workflows/tests.yml` is configured but has never actually run — no PR to `main` and no push to `main` has occurred yet. Recommend one PR to `main` next cycle specifically to prove the CI net catches what the local Lune runner catches.

---

## 6. Verdict

# APPROVED WITH CONDITIONS

**Justification**: All 22 in-scope stories PASS their required automated evidence (24/24 suite, exit 0, independently re-verified 3 times). Zero S1/S2/S3 bugs are open against this sprint's scope; the sole finding (QA-F1, S4/documentation) is already fixed. Nothing here blocks declaring this sprint's own delivered scope Done. However, a plain APPROVED would understate real, named risk carried forward — the 7-item first-boot manual backlog (Section 4) and the two RM-async-activation-class tech-debt items (TD-015/TD-017) are not hypothetical: they are disclosed, reproducible-on-paper gaps that will activate as soon as specific upcoming work (first Studio boot; the real RM async call) lands. Recording them as conditions rather than silently deferring them is the honest verdict and keeps them visible at the next gate.

## Next Steps

1. Run `/gate-check` toward the next milestone — this sprint's own scope is clear to proceed.
2. Before Sprint 2 planning closes: schedule the TD-015+TD-017 bundled ruling to land at (or before) the RM epic's first real async oxygen-spend call.
3. Before any HUD/analytics story starts consuming `GetRunEndedSignal()` or the death-broadcast signal: land TD-014 (payload widening) and TD-018 (type sync).
4. Schedule the 7-item first-boot manual backlog (Section 4) against the `/prototype predator-ai` spike or a dedicated TD-019 vendoring micro-story — do not let it silently drop from tracking.
5. Land one PR to `main` next cycle to prove CI actually fires (currently unverified in practice).
6. Run `/qa-plan` at the *start* of Sprint 2 rather than retroactively — this cycle's QA plan gap (no plan existed until close-out) should not repeat.
