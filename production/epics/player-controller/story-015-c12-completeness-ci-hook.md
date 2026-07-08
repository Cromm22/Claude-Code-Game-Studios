# Story 015: C.12 Contract-Completeness CI Hook Extension

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-053` (C.12 contract-completeness CI hook: every signal in the canonical table, floor-gated fields declared, sign-sensitive knobs domain-gated)

**ADR Governing Implementation**: ADR-0006: RemoteEvent Trust Boundary & Rate-Limiting (closest fit — the hook's invariant #1, "every signal PC consumes or produces appears in its canonical table," is the same signal-registry discipline ADR-0006 establishes for RemoteEvents specifically, generalized here to ALL of PC's signals)
**ADR Decision Summary**: No ADR directly governs this GDD-authored CI tooling. The GDD's own C.12 section specifies three machine-checkable completeness invariants (every consumed/produced signal has a canonical-table row; every floor-gated field has a declaration site; every sign-sensitive knob has a domain gate), already implemented as a GDD-static linter (`tools/ci/c12_completeness_check.py`) that runs GREEN against the GDD's own prose. This story is the code-side extension named as an open TD/qa obligation.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: LOW
**Engine Notes**: This is a Python static-analysis tool (not Roblox-engine code) that will need to additionally grep PC's own `.luau` source once it exists — no Roblox API risk, but the extension's correctness depends on PC's actual Luau code following the naming/structure conventions the existing GDD-prose parser already assumes.

**Control Manifest Rules (Foundation layer, generalized)**:
- Required: Verification-driven development — every implementation should have a way to prove it works (`.claude/docs/coding-standards.md`). This story IS that proof mechanism for PC's own signal surface.
- Required: Server-pushed-only surfaces register zero `OnServerEvent` callbacks — the hook's grep extension must be able to detect a violation of this rule automatically, not just the presence/absence of a canonical-table row.

---

## Acceptance Criteria

- [ ] **Invariant #1 re-verified against real code** — every server-internal signal PC raises (Stories 004/005/009's `RequestSquadOxygenSpend`, `RunEndConditionRaised`, `OnPlayerS4Entered`, `OnPlayerT6Respawned`, `ReleasePredatorLock`, `OnSquadMemberAliveChanged`) and every signal PC subscribes to (`RunEnded`, `OnDisturbanceBandCrossed`, `OnEscapeBeaconActivated`, `OnBeaconWindowSurvived`, `OnPlayerOxygenExpired`) has exactly one canonical-table row when the hook is re-run against the actual `.luau` source, not just the GDD prose.
- [ ] **Invariant #1 extended to RemoteEvents** — every client-fired `RemoteEvent` handler built in Stories 001/002/005/009/012/013 (`RequestSprintToggle`, `RequestLanternToggle`, `RequestGather`, `RequestInteract`, `RequestPing`, `RequestEmote`, `PlayerHeartbeat`) and every server-pushed event (`OnSprintStateChanged`, `OnLanternStateChanged`, `OnStaminaChanged`, `OnSprintPulse`, `OnPingBroadcast`, `OnEmoteBroadcast`, `OnPlayerDied`, `OnPlayerRespawned`, `OnWorldResponseCue`) is discovered by the hook's grep against real source, not just named in the GDD.
- [ ] **Self-test still catches the seeded leak** — the hook's `--self-test` fixture (`tools/ci/c12_fixtures/broken_missing_row.md`, the `ReleasePredatorLock`-omission leak) still goes RED after the extension; the extension must not accidentally weaken the existing GDD-prose check.
- [ ] **CI wiring** — the hook runs as a blocking gate on every push/PR touching `src/**/PlayerController*.luau` (per the epic's own F.4 obligation to TD+qa: "wire it into CI as a blocking gate").

---

## Implementation Notes

- The hook already exists and runs GREEN against the GDD prose (`tools/ci/c12_completeness_check.py`, built round-29, fixture-self-tested against a seeded `ReleasePredatorLock`-omission leak). This story's job is `extract_body_wiring()`'s extension to ALSO grep PC's own `.luau` subscribe/connect/fire/emit call sites once the code from Stories 001–014 exists — the three invariants themselves are UNCHANGED by this extension (per the round-27 CD "widen, don't re-architect" ruling).
- **Do not re-derive the three invariants** — they are already correctly specified in the GDD's C.12 section: (1) every consumed/produced signal has a canonical-table row (or an explicit non-subscription note, e.g. PC's own documented non-subscription to `OnBeaconWindowFailed`); (2) every floor-gated field (G.9.1's four authored mix fields) has a declaration site in both G.9.1 and `entities.yaml`; (3) every sign-sensitive knob (the stamina-curve knobs, the emission hierarchy, `STATIONARY_EMISSION_FACTOR`) is asserted in the H.12a config-validation gate.
- Use the existing `EXTERNAL_OWNED` allowlist (other-GDD names PC only cross-references — `RequestCraft`/`RequestBeaconActivate`/`OnPlayerStatusUnknown`/ED's `Emit`) and `NON_SIGNAL_NAMES` (`RunController`/`RunSession`) patterns already in the script — extend them only if a genuinely new cross-reference class is discovered while grepping real code, not preemptively.
- **Falsification rule carries forward**: re-architecture of a leaf feature is warranted only if the under-enumeration class recurs on a surface the hook COVERS; if it recurs on a surface the hook does NOT cover, widen the hook, do not re-architect.
- No dedicated ADR governs this tooling — it is a GDD-authored, TD/qa-owned CI obligation. If a genuine ambiguity arises in how to grep Luau reliably (e.g., distinguishing a `Signal:Fire()` call from an unrelated method with the same name), escalate to `/architecture-decision` rather than guessing.

---

## Out of Scope

- Re-litigating or changing the three completeness invariants themselves — only their code-side detection mechanism.
- Extending the hook to other epics' GDDs (Resource Management, Crafting, etc.) — this story's scope is PC's own signal surface only.
- Wiring a *general* Luau static-analysis framework — this is a narrow, purpose-built completeness linter, not a general linter.

---

## QA Test Cases

- **AC-1 (real-code invariant #1 — server-internal signals)**:
  - Given: PC's actual `.luau` source (post Stories 004/005/009).
  - When: the hook's extended `extract_body_wiring()` runs.
  - Then: every raised/subscribed signal has exactly one canonical-table row; zero unaccounted signals.
- **AC-2 (real-code invariant #1 — RemoteEvents)**:
  - Given: PC's actual RemoteEvent handlers (post Stories 001/002/005/009/012/013).
  - When: the hook runs.
  - Then: every client-fired and server-pushed event is discovered and accounted for.
- **AC-3 (self-test regression guard)**:
  - Given: the existing seeded-leak fixture.
  - When: `--self-test` runs after the extension.
  - Then: still RED (the extension did not accidentally mask the fixture's leak).
- **AC-4 (CI gate)**:
  - Given: a PR touching PC's `.luau` files with a deliberately introduced missing canonical-table row.
  - When: CI runs.
  - Then: the build fails, blocking merge.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/c12-completeness-hook_test.luau` (or a Python test suite alongside `tools/ci/c12_completeness_check.py`, per the tool's own existing test convention) + confirmation the hook is wired into `.github/workflows/tests.yml`
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001, Story 002, Story 003, Story 004, Story 005, Story 006, Story 007, Story 008, Story 009, Story 010, Story 011, Story 012, Story 013, Story 014 (extends the completeness grep to real PC `.luau` call sites — needs all of them to exist to verify full coverage)
- Unlocks: None (closes the epic's own F.4 TD/qa obligation)
