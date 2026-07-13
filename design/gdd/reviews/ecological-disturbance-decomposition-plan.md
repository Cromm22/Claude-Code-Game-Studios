# Ecological Disturbance GDD — Decomposition Migration Plan

> **Created**: 2026-05-30 (round-21 `/design-review` session — review aborted in favour of a structural intervention)
> **Decision**: Decompose by **content type** (CD's own deferred recommendation, see review-log round-20 entry).
> **Execution**: To be run in a **fresh `/clear` session**. Read this plan first, then execute section by section with per-write approval per the project collaboration protocol.
> **Status**: NOT STARTED.

---

## Why this plan exists

`design/gdd/ecological-disturbance.md` reached **2,397 lines / 619 KB** for a single system — too large to read in one pass (exceeds the 256 KB tool limit), ~7× the size of the whole-game concept doc (360 lines). It has been through **20 review rounds** without converging (BLOCKING counts: round-16 = 5, round-18 = 3, round-19 = 7 — not monotonically decreasing). Each round documents "revision residue": new defects introduced by the prior round's fixes.

Root cause is **non-design accretion**. The 8-section design standard is buried under:
- **Embedded CI YAML workflows** (full GitHub Actions files inside Acceptance Criteria).
- **Forward-obligation project tracking** (F.2a-IMPORTANT: R7c-I / R9-I / R11-I / R13-I / R15-I / R16-I clusters; F.2b registry; N1–N9 ADR obligations; T1–T7 sprint-backlog items).
- **Test-fixture implementation specs** (MockOrderingRecorder depth-counter semantics, call-stack nesting diagrams, AST-tooling specs).

None of these are *design*. Relocating them shrinks the GDD back toward a maintainable design document **without re-deriving any design content** — so this migration cannot introduce the residue class that has plagued every revision round. This is a **prerequisite** for convergence, **not a substitute** for the still-open Session B/C work (those BLOCKING items remain open — see "What this does NOT do" below).

---

## Target file layout (3 files)

### 1. `design/gdd/ecological-disturbance.md` (the GDD — stays, shrinks to ~700–900 lines)

Keeps the design content only:

| Section (header anchor) | Disposition |
|---|---|
| `# Ecological Disturbance` (title, ~L1) | KEEP |
| `## Overview` | KEEP |
| `## Player Fantasy` + `### Player Fantasy — Resolved Design Tensions` | KEEP |
| `## Detailed Design` → `### Core Rules`, `### States and Transitions`, `### Interactions with Other Systems` | KEEP (all of C.1.x / C.2 / C.3.x — this is design) |
| `## Formulas` → D.1–D.7 (incl. D.6b) | KEEP |
| `## Edge Cases` (E.x) | KEEP |
| `## Dependencies` → **F.1, F.2, F.3, F.3a, F.4, F.5, F.6** | KEEP (real dependency info) |
| `## Dependencies` → **F.2a, F.2a-IMPORTANT, F.2b** | **MOVE → file 3** (forward-obligations) |
| `## Section F dependency — Ecological Disturbance (paste/adapt...)` (~L1446) | **MOVE → file 3** (it is a cross-GDD paste template, not this doc's own dependency) |
| `## Tuning Knobs` → G.1–G.8 | KEEP |
| `## Visual/Audio Requirements`, `## UI Requirements` | KEEP |
| `## Acceptance Criteria` | KEEP the GIVEN/WHEN/THEN statements; **extract embedded scaffolding** (see AC rules below) |
| `### Test Infrastructure Prerequisites` (~L2327) | **MOVE → file 2** (verification) |
| `### AUTO-INTEGRATION Partner-System Dependency Map` (~L2351) | KEEP (dependency info) |
| `### Testability Flags` (~L2371) | **MOVE → file 2** (verification) |
| `## Open Questions` (~L2378) | KEEP |

### 2. `design/gdd/ecological-disturbance-verification.md` (QA / test-engineering spec — new file)

Holds the *how-it's-tested* mechanics, not the *what-must-be-true* contracts:
- All embedded CI YAML workflows: `h30c-i-evidence-gate.yml` (~L1767), the H.41m bandwidth-increment gate YAML (~L2012), the H.39d call-graph review template (~L2238), the H.30c sub-AC (i) evidence template (~L1888), the H.41m sub-AC (g) bandwidth review template (~L2012 area).
- Test-fixture implementation specs: `MockOrderingRecorder` depth-counter semantics + call-stack nesting diagram (the ```-fenced block at ~L1734–1746 and the surrounding fixture-mechanism prose in H.30c), `MockRemoteSignalRecorder`, `MockTweenService`, the seam list (`_setTestClock`, `_setExpFn`, `_injectSyntheticEmission`, `_setRingBufferState`, `_runFieldUpdatePass`, `_resetCapCueDecayPassesRemaining`, `_setExtendedStationarySegmentActive`, `_setLiveSourceState`).
- `### Test Infrastructure Prerequisites` (the 15-row T7 table).
- `### Testability Flags`.

### 3. `design/gdd/ecological-disturbance-forward-obligations.md` (cross-GDD coordination tracking — new file)

Holds the obligations registry (project-tracking, not design):
- `### F.2a — Predator AI Deferred Contracts` (rows 1–8).
- `### F.2a-IMPORTANT` — the entire cluster: R7c-I1–I4, R9-I1–I10, R11-I1–I8, R13-I1–I5, R15-I1–I3, R16-I residual, Art-Bible A1, the N1–N9 ADR obligations, T1–T7 test-infra obligations.
- `### F.2b — Forward-Obligations Registry` (the per-receiving-GDD tables: HUD GDD, Predator AI GDD, Crafting GDD, DisturbanceService ADR, Player Controller GDD).
- The `## Section F dependency` paste template.
- **This file holds the still-open Session B/C BLOCKING references** so they are not lost (see below).

---

## Acceptance Criteria extraction rule (the only interleaved section)

The AC section mixes testable contracts with enforcement scaffolding inside individual H.x entries. Apply this rule per AC:

- **STAYS in the GDD**: the behavioural contract — the `GIVEN / WHEN / THEN` statement, the PASS criteria, the test-type tag (AUTO-UNIT / AUTO-INTEGRATION / MANUAL-PLAYTEST / PERF-DEVICE), and the ordering/invariant predicate that states *what must be true*.
- **MOVES to file 2 (verification)**: any embedded ```yaml fenced block, any ```-fenced evidence-file/PR-template, any call-stack nesting diagram, and any paragraph specifying *how the mock/fixture detects* the condition (depth-counter mechanics, monotonic-counter requirements, grep/AST detection mechanism).
- **Replace each moved block** in the GDD with a one-line pointer, e.g.:
  `> Enforcement: see ecological-disturbance-verification.md §H.30c-gate.`
- **Ambiguity flag**: where the contract and the mechanism are fused in a single sentence (common in H.30c, H.39e, H.41m), keep the sentence in the GDD if it states a behavioural requirement; copy (don't move) the mechanism portion to file 2. When genuinely unsure, KEEP in the GDD and add a `<!-- TODO: verify split -->` marker rather than risk dropping a contract. **Do not delete any contract text — relocation only.**

Heaviest AC entries to handle carefully: **H.30c** (predator-respawn/cleanup — has the largest embedded YAML + nesting diagram + fixture prose), **H.39e/H.39f** (subscription-monopoly / OnServerEvent lints), **H.41m** (bandwidth gate), **H.39d** (call-graph review).

---

## Cross-reference integrity (critical — this is where residue would hide)

The document is dense with internal cites (`see F.2a row 3`, `per H.30c sub-AC (i)`, `round-15 R14-B10`, etc.). After moving a block:

1. **Before moving**, grep the *whole* GDD for references to the moved anchor (e.g., `grep -n "F.2b" ecological-disturbance.md`). Record every citing line.
2. **After moving**, update each citing line to point at the new file (e.g., `F.2b registry (see ecological-disturbance-forward-obligations.md)`).
3. The three new docs cross-link back to the GDD with a header note: `> Companion to design/gdd/ecological-disturbance.md`.
4. **Verification step** (run after each major move and once at the end): grep each of the 3 files for dangling anchors — any `F.2a` / `F.2b` / `H.30c-gate` / `T7` reference whose target is no longer in the same file must resolve to a `<filename> §<anchor>` form. Produce a dangling-reference report; zero dangling refs is the completion gate.

---

## Index, registry, and log updates (do these in the execution session)

- `design/gdd/systems-index.md` — update the ED entry: note the 3-file structure; record this as a **restructure**, not a verdict change (status stays whatever it was — the open BLOCKING items are unchanged).
- `design/gdd/reviews/ecological-disturbance-review-log.md` — append an entry: `## Restructure — 2026-05-30 — Decomposed by content type (3 files)`; summarise what moved where; state explicitly that **no design content changed and no BLOCKING item was resolved or introduced**.
- `design/registry/entities.yaml` — no change expected (constants/formulas stay in the GDD). Confirm no entity references point at moved sections.
- `production/session-state/active.md` — replace the round-20 Session A summary with the post-restructure state + pointer to this plan and the 3-file layout.
- Memory: update `project_next_steps.md` and `MEMORY.md` to record the restructure and that Session B/C are now to be done against the slimmed GDD.

---

## Suggested execution order (incremental, approval-gated)

Do the **lowest-risk, highest-volume** moves first so the GDD shrinks fast and the remaining work is easier to reason about:

1. **Create the two new files** with headers + companion back-links (empty section skeletons).
2. **Move file 3 content** (F.2a, F.2a-IMPORTANT, F.2b, Section F template) — this is the single biggest contiguous block of non-design text and the safest (pure project-tracking). Update back-references.
3. **Move file 2 content** (Test Infra Prereqs, Testability Flags, then the embedded YAML/templates/fixture-specs out of the AC entries per the AC rule). Update back-references.
4. **Sweep the slimmed GDD** for dangling references; fix all.
5. **Update** systems-index, review-log, active.md, memory.
6. **Final verification**: `wc -l` on the GDD (expect ~700–900); zero-dangling-reference grep across all 3 files; confirm the GDD reads as 8 clean sections.

Each Write/Edit gets explicit approval per `CLAUDE.md` collaboration protocol. Prefer moving whole header-delimited blocks in single edits to minimise edit count on the 619 KB file.

---

## What this does NOT do (read before executing)

- It does **not** resolve any open BLOCKING item. The round-20 Session B items (`B-CD18-1` SQUAD_T safe-range narrowing to `(0.272, 0.30)`; `B-R19-SD-1` `S_inf` pinning to `r = 2^(-1/15)`; `B-R19-SD-2` G.5 lower-bound rationale; `B-R19-SD-3` D.1 worked-example fix) and Session C items (`B-R19-AI-1` `:ReleasePredatorLock` yield-free vs pathfinding contract; the ~24 IMPORTANT residual) **remain open**. Record them in file 3 so they survive the move.
- It does **not** re-derive formulas, change any constant, or alter any AC contract. Relocation only. If the execution session is tempted to "fix while moving," STOP — that reintroduces the residue pattern this restructure exists to break.
- After the restructure lands, the correct next step is the Session B/C patch work **against the slimmed GDD**, then a round-21 `/design-review`. Decomposition makes that work tractable; it does not skip it.

## Open question for the execution session

The slimmed GDD's Acceptance Criteria may still be large (the H.x contract statements alone are numerous). After step 4, re-measure. If the GDD is still > ~1,200 lines, reconsider the **subsystem split** (field model vs. predator-query interface) that was deferred here — but only as a separate, separately-approved pass.
