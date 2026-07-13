# Gate Check: Technical Setup → Pre-Production

**Date**: 2026-07-06
**Review mode**: lean
**Checked by**: gate-check skill

## Required Artifacts: 5/13 present

- [x] Engine chosen — Roblox Studio + Luau + Knit + Rojo (CLAUDE.md)
- [x] Technical preferences configured — populated (naming, budgets, forbidden patterns)
- [x] Art bible — `design/art/art-bible.md`, all 9 sections with real content
- [x] ≥3 ADRs covering Foundation-layer systems — 8 Accepted ADRs (ADR-0001 Knit lifecycle, ADR-0002 RunController, ADR-0007 Save/Load, +5 more)
- [x] Engine reference docs — `docs/engine-reference/roblox/` (VERSION, breaking-changes, current-best-practices, deprecated-apis)
- [ ] Test framework (`tests/unit/`, `tests/integration/`) — **MISSING**, no `tests/` directory exists at all
- [ ] CI/CD test workflow (`.github/workflows/tests.yml`) — **MISSING** (only `gdd-invariants.yml` exists)
- [ ] Example test file — **MISSING**
- [x] Master architecture document — `docs/architecture/architecture.md` (v0.3, TD sign-off)
- [ ] Architecture traceability index (`docs/architecture/architecture-traceability.md`) — **MISSING** (`tr-registry.yaml` exists but is a distinct artifact — a TR-ID registry, not a traceability matrix)
- [ ] `/architecture-review` has been run — **MISSING**, no report anywhere in `docs/architecture/`
- [ ] `design/accessibility-requirements.md` — **MISSING** (`design/ux/` doesn't exist at all)
- [ ] `design/ux/interaction-patterns.md` — **MISSING**

## Quality Checks: 6/9 passing

- [x] Architecture decisions cover core systems (movement, RemoteEvent trust, death/respawn, persistence)
- [x] Technical preferences have naming conventions + performance budgets
- [ ] Accessibility tier defined — **FAIL** (no doc)
- [ ] At least one screen's UX spec started — **FAIL** (no `design/ux/`)
- [x] All 8 ADRs have Engine Compatibility sections stamped with engine version
- [x] All 8 ADRs have GDD Requirements Addressed sections
- [x] No ADR references deprecated APIs (manually cross-checked against `deprecated-apis.md` — no `wait()`/`spawn()`, no raw DataStoreService, no `_G`, no cross-boundary BindableEvent)
- [x] All HIGH RISK engine domains (Character Controller Library, StreamingEnabled, bandwidth) explicitly flagged with Verification Required + mitigation
- [ ] Architecture traceability matrix has zero Foundation-layer gaps — **UNVERIFIABLE**, no traceability doc exists to check

**ADR Circular Dependency Check**: No cycles (0002→0001, 0004→0001, 0005→0004+0002, 0008→0003 — all one-directional). **PASS**

**Engine Validation**: Post-cutoff APIs correctly flagged HIGH/MEDIUM risk (ADR-0003, 0004, 0008); all ADRs agree on the same engine/version. `/architecture-review`'s own deprecated-API audit has never run — this specific check is unverifiable by process, only by manual read. **CONCERNS**

## Director Panel Assessment

| Director | Verdict | Key point |
|---|---|---|
| Creative Director | CONCERNS | Pillars faithfully carried through to architecture; flagged the 2-player BC4 oxygen collapse as the #1 prototype validation target (already user-ruled, non-blocking) |
| Technical Director | CONCERNS | Architecture is sound; but `/architecture-review` was never run, ADRs 3/4/6/8 shipped ahead of their own named empirical spikes, and there's no test harness — flagged as must-close-before-implementation, not before-entering |
| Producer | CONCERNS | Entering the phase is fine; sprint 1 must be scoped as scaffolding (epics, slice definition, RunController/Camera authoring) not feature work — no epics/sprints exist yet |
| Art Director | CONCERNS | Art bible is strong and complete; but no `design/ux/` layer exists, and there's a live self-contradiction in the bible (oxygen-warning color `#FFD060` fails its own predator-hue exclusion rule) that should be ruled on before the HUD prototype is built |

No director returned NOT READY — the panel's floor is CONCERNS, not FAIL.

## Blockers (from the artifact checklist, independent of the panel's framing)

1. **No test framework or CI test path** — `/test-setup` is explicitly meant to run "once during Technical Setup... before the first sprint begins" per its own description. It never ran.
2. **No `/architecture-review` has ever been run** — `docs/CLAUDE.md` mandates this "after completing a set of ADRs." Eight Accepted ADRs have never been cross-validated, and this is also what's supposed to generate `architecture-traceability.md`.
3. **No accessibility or UX layer exists** (`design/accessibility-requirements.md`, `design/ux/interaction-patterns.md`, any screen spec) — required quality checks for this gate, currently unaddressed.

## Recommendations

- Minimal path to a clean PASS is 3 skill runs: `/test-setup` → `/architecture-review` → accessibility doc + `/ux-design` (at least HUD). All three are quick, mechanical, and don't touch design substance.
- Independently of this gate: rule on the Art Director's `#FFD060`/predator-hue contradiction before it's baked into a CI gate script.

## Verdict: FAIL — OVERRIDDEN BY USER 2026-07-06

Mechanical reasoning for the FAIL draft: 8 of 13 required artifacts and 3 of 9 quality checks are simply absent, not thin — including two items (`/test-setup`, `/architecture-review`) whose own skill descriptions state they belong *in* Technical Setup, before this exact transition.

**Chain-of-Verification**: 5 questions checked — verdict unchanged (FAIL) prior to override. Key finding: the fail condition is fully resolvable via 3 existing skills with no design rework implied — this is a process/sequencing gap, not a deeper design problem.

**User decision**: presented with the tension between the mechanical FAIL (artifact-checklist letter) and the director panel's own floor (CONCERNS — all four directors judged the missing items as first-week Pre-Production groundwork, not entry blockers), the user explicitly chose to override and advance to Pre-Production now. `production/stage.txt` updated to `Pre-Production` on this basis.

**Carried-forward obligations (not blocking, but now first-week Pre-Production debt):**
- Run `/test-setup` to scaffold TestEZ + CI test workflow
- Run `/architecture-review` (also produces `architecture-traceability.md`)
- Author `design/accessibility-requirements.md` (pick a tier) + `design/ux/interaction-patterns.md` + at least a HUD UX spec
- Rule on the Art Director's `#FFD060` oxygen-warning-color / predator-hue-exclusion contradiction (art-bible §4.2 vs §4.5) before any HSV CI gate is authored
- Scope sprint 1 as scaffolding (epics, vertical-slice definition, RunController/Camera GDD authoring), not feature implementation, per the Producer's assessment
- Treat the 2-player BC4 oxygen-collapse kill-criterion as the primary prototype/playtest validation target, per the Creative Director's assessment
