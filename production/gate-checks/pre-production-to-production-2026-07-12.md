# Gate Check: Pre-Production → Production

**Date**: 2026-07-12
**Checked by**: `/gate-check` (lean review mode — full 4-director panel)
**Purpose**: Run intentionally to produce the formal gap-list (user directive: "run the gate for the gap-list"). A FAIL is the expected, useful outcome — this document is Sprint 2/3's charter, not a setback.
**Stage change**: NONE — `production/stage.txt` stays `Pre-Production`.

---

## Verdict: **FAIL** (expected — gap-list mode)

Two directors returned NOT READY (panel rule → minimum FAIL). The FAIL is narrow and unanimous in character: **the design, architecture, and art are mature; engine-reality and core-loop-fun have simply never been observed.** No director found incoherence or a re-architecture need. The path back is a boot, a spike, a CI run, two rulings, three systems' story authoring, a thin-slice build, and three playtests — roughly two sprints.

**Chain-of-Verification**: 5 questions checked — verdict unchanged (FAIL).

---

## Director Panel

| Director | Verdict | One-line |
|---|---|---|
| Creative | **NOT READY** | Core fantasy never experienced by a human; 3 Pillar-critical risks flagged-but-untested. |
| Technical | **NOT READY** | Foundation has never executed on the target engine (`Packages/` empty → first Rojo boot fails at load). |
| Producer | **CONCERNS** | 0/6 vertical-slice validation items; slice can't be assembled from current backlog (RM/Crafting/PA unstoried). |
| Art | **READY** | Art foundation comprehensive; open items are HUD-epic preconditions, not Production-entry blockers. |

---

## The Single Load-Bearing Blocker

**The Foundation spine has never booted in Roblox Studio.** All 24 test files pass only under the headless Lune mock harness. `Packages/` contains only `.gitkeep` (Knit/Signal never vendored — TD-019), and `default.project.json` maps `Packages` to that empty folder, so the first real Rojo boot fails at `require`. Consequences:
- The load-bearing `Signal:Fire()` synchronous-until-first-yield assumption — which the pc-9 wipe-before-respawn ordering and the whole T5/T6 death chain depend on — is unverified.
- Two HIGH-risk post-cutoff engine bets are unaddressed in reality: ADR-0003 locomotion driver (Character Controller library, GA post-cutoff) and ADR-0008 bandwidth baseline (<50 KB/s ceiling).
- CI (`tests.yml`) has never fired — it triggers only on push/PR to `main`, and `main` holds only template commits. The green suite is a local gitignored binary, not a pipeline signal.

Everything else is downstream of this one fact. Entering Production means stacking the Core layer on an unbooted Foundation; if the first boot invalidates a locomotion / Signal-ordering / Knit-lifecycle assumption, that rework cascades through everything above it.

---

## Required Artifacts (gate scorecard)

| Item | Status |
|---|---|
| ≥1 prototype in `prototypes/` with README | ✅ `predator-ai-quiet-lever/` (Python sim — NOT an in-engine spike) |
| First sprint plan | ✅ `sprint-1.md` (closed) |
| Art bible complete (9 sections) + AD sign-off | ⚠️ 10 sections complete; AD-ART-BIBLE sign-off SKIPPED (lean) — AD offers this review as substitute, log as `APPROVED (via AD-PHASE-GATE 2026-07-12)` |
| Character visual profiles | ✅ Embedded in art-bible §5 (predator + player gear, thorough) — AD corrected the intake false-alarm |
| All MVP GDDs complete | ✅ 7/7 approved/accepted |
| Master architecture doc + traceability | ✅ current |
| ≥3 Foundation ADRs | ✅ 14 Accepted ADRs |
| Control manifest | ✅ current |
| Epics (Foundation + Core) | ⚠️ Foundation storied; **RM + Crafting epics exist with ZERO stories; Predator AI has NO epic at all** |
| **Vertical Slice build exists + playable** | ❌ scope doc only, no build |
| **Vertical Slice playtested ≥3 sessions** | ❌ `production/playtests/` does not exist |
| Vertical Slice playtest report | ❌ none |
| UX specs: main menu, HUD, pause | ⚠️ HUD spec exists (accepted w/ 15 carried obligations); no main-menu/pause (correctly deferred) |
| Key screen UX specs passed `/ux-review` | ❌ hud.md never run through `/ux-review` |

**Vertical Slice Validation (FAIL if any NO): 0 of 6 satisfied** — no human has played the loop; nothing communicates the goal in 2 min; no complete start→challenge→resolution cycle; core mechanic feel unverified. This block alone forces FAIL per the gate's own rule.

---

## Minimal Path to a Real PASS (director-convergent, 2 sprints)

### Sprint 2 — De-risk & Enable (author + boot, NOT slice-complete)
Ordered so highest-risk validation happens first, with runway to react:
1. **TD-019 keystone — vendor Knit + Signal, first Studio/Rojo boot, open a PR to `main` to fire CI.** Confirm `Signal:Fire()` synchronicity in-engine. (~1.5–2d) *Nothing else validates until this lands.*
2. **`/prototype predator-ai` spike IN STUDIO** — clears the two HIGH-risk ADR checkpoints (ADR-0003 locomotion re-eval, ADR-0008 bandwidth baseline). The Python sim does not count.
3. **pc-8 spectator camera (HIGH engine risk)** immediately after first boot — most likely story to break on real Studio; front-load it.
4. **TD-018** type sync + ADR-0002 addendum (~0.5d); **TD-014** OnPlayerDied payload widen — both before any HUD/analytics consumer.
5. **Rule TD-015 + TD-017 (bundled)** — the RM-async activation class — before RM's first genuine async `RequestSquadOxygenSpend` lands.
6. **Author RM + Crafting + Predator AI stories** (`/create-stories`; slice scope only — flat-drain oxygen, single beacon recipe + activation + survival-hold + win/lose banner, PA 4-state FSM). **Author `/qa-plan sprint-2` BEFORE implementation** (fixes the retroactive-QA debt).

### Sprint 3 — Assemble, Play, Gate
7. Implement + integrate the thin slice from the Sprint-2-authored stories.
8. Create `production/playtests/`; run **≥3 documented sessions** (≥1 naive pair) hitting the three Pillar-critical questions: (a) is the 2-player BC4 survivor window actually survivable, (b) does the squad feel like a squad during gather, (c) does quiet-vs-loud read as a real choice.
9. Run **CD-PLAYTEST** on the results — *that* gate, not this one, is where the core fantasy earns its verdict.
10. Re-run `/gate-check` — the four PHASE-GATEs then judge a real playable artifact.

---

## Recommendations (non-blocking, close before dependent work)
- HUD epic preconditions (AD): rule OQ.6 (CONTACT `#FFF0C8` in predator reserved-hue band), close CR.8 figure/ground arbitration, run hud.md through `/ux-review` — all *before* HUD stories are sprinted, not before Production entry.
- Log the art-bible AD sign-off explicitly (`APPROVED via AD-PHASE-GATE 2026-07-12`) rather than leaving "Skipped" as the permanent record.
- Short technical-artist Studio spike to sanity-check 2–3 signature visual specs (Slate/Neon response, iPhone-SE silhouette pixel-counts) before the first real asset pass.
- Ratify sprint capacity with real data but conservatively — Sprint 1's Foundation-logic velocity won't transfer to cross-system integration + first-boot debugging.
- TD-005 (mobile/touch misclassification): do not trust any mobile playtest data until platform classification lands.
- TD-016 (userId-vs-player seam): rule at Predator AI epic authoring, before the real PredatorService is written.

---

## Bottom Line
A healthy FAIL. Sprint 1 delivered a genuinely strong, well-tested Foundation spine ahead of schedule; the gate is held not on the quality of that work but on the two things Production must stand on — *that the engine runs it* and *that the loop is fun* — neither of which has been observed yet. Both are days-to-a-sprint of bounded, named work, not re-architecture. Do Sprint 2 (de-risk + author), Sprint 3 (build + playtest), gate at the end of Sprint 3.
