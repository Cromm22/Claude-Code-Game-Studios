# Story 016: Security Hardening — Client-Surface Lints & Test-Seam Enforcement

> **Epic**: Ecological Disturbance
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-063` (zero client-callable RemoteFunctions), `TR-ed-067` (all test seams server-internal, grep-verified), `TR-ed-068` (raw flora RemoteEvents zero `OnServerEvent`, CI-enforced), `TR-ed-069` (CI BLOCKING lint gates are load-bearing architecture)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: This story is the mechanical CI enforcement of security invariants established by Stories 002/010/011/013/014 — it does not introduce new gameplay behavior, only static/grep-based verification gates that must exist and pass as **required, blocking** CI checks before any PR touching the relevant surfaces merges.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: MEDIUM
**Engine Notes**: No Roblox API risk — this is CI tooling (grep/AST-based static checks) rather than runtime game code. Risk is MEDIUM because the reflection/alias-resolution forms these lints must catch (table-index-form, local-alias, reflection) are genuinely hard to enumerate exhaustively; the GDD itself notes AST-tooling forward obligations (R15-I1, R15-I2) for the highest-fidelity versions of these lints.

**Control Manifest Rules (Core layer)**:
- Forbidden: Never respond to a rejected/rate-limited RemoteEvent with an explicit error response to the client — silent-drop only (applies by analogy to this story's schema-rejection paths, cross-referenced from ADR-0006, not directly ED-owned but consistent).
- Required: Every system's bandwidth budget must be evaluated against `50 KB/s minus the measured character-replication baseline` — cross-referenced for Story 017, not this story directly.

---

## Acceptance Criteria

- [ ] **H.39** — GIVEN the DisturbanceService source, WHEN grep runs for four declaration forms (method-sugar, dot-form, assignment-form, table-index-form) on `.Client` AND for `:Emit(` inside those bodies, THEN: (a) only `OnMeterUpdate`, `OnDisturbanceAlert`, `OnDeathAttributionPushed` are declared on `.Client` (no more, no fewer); (b) zero direct `:Emit(` calls in any client-method body.
- [ ] **H.39b** — GIVEN the source, WHEN inspected via the same four-form grep, THEN `.Client` contains zero RemoteFunctions and only the exact three named signals.
- [ ] **H.39c** — GIVEN the source AND the handshake module, WHEN inspected, THEN: (a) all test seams (`_setTestClock`, `_advanceTestClock`, `_setExpFn`, `_injectSyntheticEmission`, `_runFieldUpdatePass`, `_setRingBufferState`, `_captureDeathLockSnapshot`, `_setLiveSourceState`, `_resetCapCueDecayPassesRemaining`, `_setExtendedStationarySegmentActive`) are server-internal, never `.Client`; (b) `RegisterPredatorLockChangedSignal`/`RegisterPredatorStateChangedSignal` are module-private (not on `DisturbanceService` or `.Client`), exported from the handshake module with EXACTLY five canonical names; (b-vi) `KnitStart`'s handshake-call ordering — both getters lexically before `setOnPredatorStateChangedHandler`; (c) the handshake module path is binding — relocation requires updating this AC in the same PR.
- [ ] **H.39d** — GIVEN the source, WHEN two engineers independently inspect the call graph reachable from each `.Client` handler, THEN no reachable path leads to `self:Emit(...)` without first passing a named server-side authority validator. Evidence file `production/qa/evidence/H39d-[sprint-id]-call-graph-review.md` with both reviewers' GitHub usernames + attestation. CI gate MUST be a required check on PRs touching the `.Client` surface (recursive filter + content-grep); **implementation epic BLOCKED on gate's presence.**
- [ ] **H.39e** — GIVEN the entire server codebase, WHEN a CI grep gate runs three lints: (a) exactly ONE `Humanoid.Died:Connect` in the whole codebase, nested inside `DisturbanceService:KnitInit`; (b) zero yield primitives reachable via call-graph traversal from `OnPlayerDied:Connect` callback roots; (c) zero synchronous server-side observers on `OnPredatorLockChanged`'s fire path, THEN the gate exits 0 on all-clean, non-zero with file/line/lint-name on violation. **Required check, BLOCKING on presence before any `.Client` method or BindableEvent subscription path is introduced.**
- [ ] **H.39f** — GIVEN the entire server codebase, WHEN a CI grep gate checks `OnServerEvent` access on `FloraChunkUpdate`/`FloraChunkInitialSnapshot` across five syntactic forms (direct, local-alias-on-RemoteEvent, local-alias-on-OnServerEvent, table-index, reflection), THEN zero matches anywhere (reflection forms flagged for manual review, not silent-pass).
- [ ] **H.31b** — GIVEN the source AND a grep/AST pass over all `KnitInit`-reachable code, WHEN run, THEN: (a) zero occurrences of `"ReplicationFocus"`; (b) zero `Player:GetPropertyChangedSignal("ReplicationFocus")`; (c) zero direct reads of `Player.ReplicationFocus`; (d) zero `GetPropertyChangedSignal` on any client-writable Player property in the chunk-load code path; (e) zero `Player.Character.*.Position`-polling loops. **BLOCKING.**
- [ ] **H.31c** — GIVEN the `_injectSyntheticEmission` test-only seam, WHEN executed via three SEPARATE invocations (each violating exactly one of: non-finite position, `initialMagnitude` outside `(0,1.00]`, invalid `emissionType`), THEN each raises a hard error independently, no source inserted, each error identifies the violated invariant. Exact-strict boundary semantics: `1.00` accepts, `1.0000001` rejects.
- [ ] All CI gates (`h39d-evidence-gate.yml`, `h30c-i-evidence-gate.yml` — the latter is Story 010/011's joint concern, cross-referenced here for completeness) trigger on BOTH `pull_request` and direct `push` to `main` (not PR-only — closes the admin/branch-protection-bypass gap).

---

## Implementation Notes

The four-declaration-form grep (method-sugar `function Service.Client:Foo`, dot-form `Service.Client.Foo = function`, assignment-form `Service.Client["Foo"] = ...`, table-index-form) must be exhaustive — a lint that only catches method-sugar leaves 3 exploitable declaration shapes undetected.

H.39d and H.30c-i (Story 010/011's cross-cutting evidence gate) both use the same normative CI YAML shape (recursive `paths-filter` over `src/server/services/DisturbanceService/**/*.luau`, content-grep narrowing to actual `.Client`-surface-touching changes, evidence-file existence + two-distinct-reviewer + attestation-line checks). Reuse the same GitHub Actions job structure for both gates rather than inventing a second shape — see `ecological-disturbance-verification.md`'s fully-worked YAML for both gates; copy the pattern, do not re-derive it.

Evidence file templates (required structure, cite verbatim):
```markdown
# H.39d Call-Graph Review — Sprint [sprint-id]
- date: 2026-MM-DD
- @reviewer-one
- @reviewer-two
- attestation: @reviewer-one — no client-reachable path leads to self:Emit(...) without a server-side authority validator. Traversal: [summary].
- attestation: @reviewer-two — no client-reachable path leads to self:Emit(...) without a server-side authority validator. Traversal: [summary].
- flagged_paths: [none / list]
```

The `.Client` recursive path-filter fix (round-23 B7/QA-1) is REQUIRED: the filter must match `'src/server/services/DisturbanceService/**/*.luau'` recursively, not a `Client/` subdirectory-only pattern — under the standard single-file Knit layout (Service.Client methods declared inline in `Init.luau`), a subdirectory-only filter would never fire, silently disabling the gate.

---

## Out of Scope

- The actual game-code correctness these lints verify (that's Stories 002, 010, 011, 013, 014's own scope) — this story only builds and lands the CI mechanism.
- DevOps pipeline infrastructure beyond these specific gates (general CI/CD setup is `/test-setup`'s scope, already completed per session state).

---

## QA Test Cases

- **AC-H.39**: Given: the DisturbanceService source after Stories 002-015 land — When: the 4-form grep + `:Emit(` inner-body check runs — Then: (a) exactly 3 named signals on `.Client`; (b) zero `:Emit(` calls in any `.Client` method body. Edge case: a deliberately-introduced violation (a test-only fixture PR with a 4th signal or an in-body `:Emit(` call) MUST cause the lint to fail — a positive control proving the lint isn't vacuous.
- **AC-H.39b**: Given: the source — When: inspected — Then: zero RemoteFunctions on `.Client`, only the 3 named signals present.
- **AC-H.39c**: Given: the source + handshake module — When: inspected — Then: all 10 named test seams are server-internal only; handshake exports exactly 5 names; KnitStart ordering (getters-before-setter) verified via source-text grep; handshake path is pinned. Edge case: a test seam accidentally declared on `.Client` (positive control) must be caught.
- **AC-H.39d**: Given: two independent reviewers examine the `.Client`-reachable call graph — When: the evidence file is produced — Then: it lists 2 distinct GitHub usernames and 2 independent attestation narratives (not copy-pasted); the CI gate fails the build if the evidence file is missing or has <2 distinct reviewers.
- **AC-H.39e**: Given: the full server codebase — When: the 3-part lint runs — Then: exits 0 on the clean codebase. Edge case (positive control): temporarily introduce a second `Humanoid.Died:Connect` site elsewhere in a test fixture — the lint MUST fail and report the file/line.
- **AC-H.39f**: Given: the full server codebase — When: the 5-syntactic-form `OnServerEvent` grep runs against the two raw flora RemoteEvents — Then: zero matches. Edge case: a reflection-form access (e.g., via `instance[methodNameString]`) is flagged for MANUAL REVIEW rather than silently passing — verify the lint actually surfaces this case distinctly rather than missing it entirely.
- **AC-H.31b**: Given: the chunk-load code path (Story 014) — When: the ReplicationFocus/property-polling grep runs — Then: zero matches across all 5 sub-checks.
- **AC-H.31c**: Given: 3 separate `_injectSyntheticEmission` invocations, each violating exactly one invariant — When: each runs independently — Then: each raises a distinct hard error identifying its specific violated invariant. Edge case: `initialMagnitude = 1.00` exactly is ACCEPTED (boundary-inclusive); `1.0000001` is REJECTED (boundary-exclusive on the high end) — test both explicitly.
- **AC — trigger-on-push-and-PR**: Given: the CI YAML for both gates — When: inspected — Then: both `on: pull_request` and `on: push: branches: [main]` triggers are present (not PR-only).

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/ecological-disturbance/security-client-surface-lints_test.luau` — must exist and pass (plus the two CI YAML files `.github/workflows/h39d-evidence-gate.yml` and the shared H.39e/H.39f grep-gate workflow, and the evidence-file templates under `production/qa/evidence/`)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 002, 010, 011, 013, 014
- Unlocks: None (final hardening pass before Story 017)
