# QA Plan — Sprint 1 (retroactive, close-out cycle)

**Sprint**: Sprint 1 (2026-07-06 → 2026-07-20) — "Stand up the minimal cross-service spine"
**Written**: 2026-07-11, as part of the `/team-qa sprint` close-out cycle (the sprint began without a QA plan — the ⚠ No QA Plan warning in `production/sprints/sprint-1.md` records that gap; this document closes it retroactively and serves as the template for Sprint 2's *pre-sprint* plan)
**Strategy approved by**: user, 2026-07-11 (Phase 2 gate)
**Build/commit**: `46103e0`, branch `crafting-round2-patch`

---

## Scope

- **In scope**: the 22 done stories (rc-1/2; ed-1..10, ed-14; pc-1..7, pc-9, pc-11) — every Must-Have plus the user-directed should-have pull-in.
- **Out of scope**: the 12 unimplemented backlog stories (ed-11/12/13/15/16/17, pc-8/10/12/13/14/15) — nothing to test; and all live-build manual QA (no bootable build exists — `Packages/` unvendored, TD-019).

## Story Classification

All 22 done stories are **Logic** or **Integration** (BLOCKING automated-evidence gate). Zero Visual/Feel, UI, or Config/Data stories landed this sprint. The full per-story classification/evidence table lives in the qa-lead's strategy (reproduced in the smoke report's coverage table, `production/qa/smoke-2026-07-11.md`) — every story has passing evidence at its declared path.

## Automated Test Requirements

- Suite: `.tools/lune.exe run tests/run_tests.lua tests/unit tests/integration` → must be 24/24 files, exit 0 (verified three independent times this close-out: smoke check, qa-lead audit, coordinator).
- CI: `.github/workflows/tests.yml` (Foreman-installed Lune) — **configured but never fired**; requires a PR to `main` or a push to `main`. Validating CI is a named exit item for the next cycle, not this one.

## Manual QA Scope (this cycle — per the approved strategy)

Traditional build-playtest QA is impossible (no boot). This cycle's manual-QA-equivalent labor:
1. **Automated-evidence audit** — COMPLETE: qa-lead independently re-ran the suite and cross-checked all 22 Completion Notes against actual evidence files; no phantom claims.
2. **Documentation-consistency QA** — COMPLETE: one S4-class finding (the smoke report's/session state's "15 done" tally error vs the authoritative 22) — corrected same-session.

## Deferred-to-First-Studio-Boot Manual Backlog (named, must not silently drop)

Budget ~2–4 hours at the first successful boot (designated home: the `/prototype predator-ai` spike or a TD-019 vendoring micro-story + boot):
1. `Player:LoadCharacter()` synchronous-completion contract (pc-4/pc-5 respawn path)
2. `Humanoid.UseJumpPower`/`JumpHeight` per-rig behavior vs the capture-and-restore jump lock (pc-7, TD-017-adjacent)
3. `game:BindToClose` live firing → Abandoned transitions (pc-4/pc-9)
4. Vendored Signal `:Fire()` synchronous-until-first-yield semantics (pc-9 wipe-before-respawn ordering, TD-019)
5. PERF H.28 (CPU: 4-player, 300-tick Heartbeat, injected RM fault) + H.29 (bandwidth: 60-frame steady-state) — `pending()` in pc-11's suite
6. Live RemoteEvent rate-limit behavior under real network conditions (logic already automated)
7. H.26 (pc-1 locomotion feel) + H.32 (pc-3 manual-device) placeholders

## Entry Criteria (met)

- Smoke check PASS (`production/qa/smoke-2026-07-11.md`)
- Working tree committed (`46103e0`), suite green

## Exit Criteria (this cycle)

- All in-scope stories PASS the evidence audit (met — 22/22)
- All consistency findings fixed or filed (met — 1 finding, fixed)
- Sign-off report written with an explicit verdict + carried conditions (`production/qa/qa-signoff-sprint-1-2026-07-11.md`)

## Risk Register Snapshot (carried into sign-off)

TD-015 + TD-017 (RM-async activation class — **highest watch**, bundled ruling needed); TD-014 + TD-018 (fix before any HUD/analytics consumer); TD-005 (mobile/touch data untrustworthy until platform classification lands); TD-019 (vendor Knit/Signal before any boot — recommend a dedicated micro-story); TD-016 (userId-keyed seam ruling at PA-epic first touch); CI unfired (one PR to `main` to prove the net). Full register: `docs/tech-debt-register.md` (TD-001..019; TD-004/TD-013 Resolved).
