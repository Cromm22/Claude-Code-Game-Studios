# Cross-GDD Review Report — 2026-07-05

> `/review-all-gdds` full mode. GDDs reviewed: **7** (+ game-concept.md, systems-index.md, design/registry/entities.yaml, and the two ED companion files).
> Systems: Crafting & Items, Ecological Disturbance, HUD, Player Controller, Predator AI, Resource Management, Resource Node.
> Method: 4 parallel review agents — consistency (2 passes: ED-outbound + remainder), design-theory holism, cross-system scenario walkthrough — with every headline blocker independently re-verified against the artifacts by the coordinating session (grep + line-range reads on both sides of each claim).
> **Coverage disclosure (union across seats):** every GDD was fully read by at least one seat EXCEPT: Crafting's own Acceptance-Criteria table was not cross-checked in full against sibling ACs, and Player Controller's AC/Open-Questions tail had only partial coverage. The ED companion files were lightly touched this run (they were exhaustively audited in ED rounds 22–24 days prior). These gaps are marked NOT-CHECKED in seat reports, not silently assumed clean.
> **Widget note:** the write-report and flag-GDDs approvals timed out (user AFK); the recommended options were adopted per this project's established timeout precedent (2026-07-03) — **pending user ratification**.

---

## Consistency Issues

### Blocking (must resolve before architecture begins)

**🔴 C1 — Player Controller never landed ED's death-signal re-anchor (CI-enforced mandate).**
ED F.6 "PC-T5 mandate": DisturbanceService is the **sole** `Humanoid.Died` subscriber (H.39e Lint (a), CI-enforced); PC MUST re-anchor its T5 death trigger to `DisturbanceService:GetOnPlayerDiedSignal()` — "MUST land before any PlayerControllerService implementation epic enters sprint planning." Verified: `player-controller.md` contains **34** `Humanoid.Died` references and **zero** `GetOnPlayerDiedSignal` references; PC F.4 additionally blesses Crafting's parallel direct listener ("the dual source is harmless"), directly contrary to ED's monopoly rule. ED's own tracker row (`ecological-disturbance-forward-obligations.md` PC-T5) still reads "IN-FLIGHT ... as of 2026-05-08" — never re-touched across ~25 subsequent PC rounds; PC reached APPROVED without discharging it. **Authoritative: ED.** Fix: PC re-anchors the subscription (many of the 34 sites are timing descriptions — the mechanical change is the T5 subscription + wording sweep); ED tracker row flipped when landed.

**🔴 C2 — Crafting & Items C.8, same defect.**
Crafting C.8 "Death mid-craft: `Humanoid.Died` enqueues {player, "death"}" + ~30 references, zero re-anchors, despite ED F.6's identical Crafting-C.8 mandate (tracker row status "PENDING"). Crafting is APPROVED/COMMITTED (`620e67a`). **Authoritative: ED.** Same fix shape as C1.

**🔴 C3 — `MAX_ACTIVE_BEACONS = 3` never authored.**
ED H.36's perf-PASS scope clause is **bidirectionally locked** on Crafting authoring a runtime `MAX_ACTIVE_BEACONS = 3` constraint (reject Beacon publishes beyond cap, with an AUTO-UNIT). Verified: zero occurrences in `crafting-and-items.md` and in `entities.yaml`. Without it, a silent Crafting revision could invalidate ED's measured perf envelope (the R11-I8 grid-mandate would become binding unnoticed). **Authoritative: ED.** Fix: author the cap + AC in Crafting; register the constant.

**🔴 C4 — Oxygen-empty grace timer: mutual disownment between two APPROVED GDDs.**
`player-controller.md:123`: "the grace timer is **owned by the Resource Management GDD** — Player Controller subscribes to an `OnPlayerOxygenExpired` signal from that service, when authored." `resource-management.md:89`: "PC consumes it and runs its oxygen-empty death path + grace timer for every currently-alive player **(PC-owned)**." No `OXYGEN_GRACE_*` constant, duration, or mechanism exists in either document (verified). Whether oxygen-empty is an instant squad-death cliff or a timed reprieve — and its length, per-player vs squad scope, and owner — is **undefined**. This bites hardest in the oxygen-crisis-during-Hunt scenario. **Needs an ownership + duration DESIGN DECISION (user/CD), then authoring in the chosen owner.**

**🔴 C5 — HUD wires the threat bearing to the wrong PA channel.**
PA (FIX 17, `predator-ai.md:72`): "`bearing` is per-client ... delivered via a per-client targeted fire `OnPredatorSense:Fire(player, {bearing, distanceBand})` once per alive client per tick, NOT one broadcast." HUD (`hud.md:120` Interactions + D.3 + Hard Dependencies) attributes `bearing`/`distanceBand` to **Channel B `OnPredatorLockChanged`** — which PA fires **only to the locked player** — and contains **zero** references to `OnPredatorSense` (verified). As written, non-locked squadmates never receive the bearing chevron that HUD's own CR.2 zone table and CR.8 figure arbiter assume for the SQUAD threat-edge state. **Authoritative: PA.** Fix: HUD adds the `OnPredatorSense` dependency row and re-attributes bearing/band to it; Channel B keeps the lock-specific fields.

**🔴 C6 — Entity-registry integrity (mechanical).**
(a) `entities.yaml` `squadAggregateT` formula entry still publishes the pre-round-23 zero-arg form — the exact Pillar-1-inverting signature ED round-23 fixed (`GetSquadAggregateT(excludePlayer: Player?)`); any future GDD consulting the registry would reproduce the defect. (b) `MAX_ATTRIBUTION_ARCHIVE_ENTRIES` (ED round-24, default 4000) was never registered — the class of gap the registry exists to prevent. Fix: update both entries.

### Warnings (should resolve; not blocking)

- ⚠️ **`OnPlayerOxygenExpired` arity mismatch** — PC F.2 cites `(playerId)`; RM's authored contract is argument-less squad-wide (RM OQ.7 tracks it; PC never discharged). Fold into the C4 fix.
- ⚠️ **RN's "Needs PC reverse-cite" is half-stale** — PC F.2 already reverse-cites the gather-gesture contract; the **death-signal-to-RN** half remains genuinely missing from PC's F.2.
- ⚠️ **PC misattributes Crafting's requested `BEACON_HALF_LIFE` band** — PC (~line 369) states "ED's `BEACON_HALF_LIFE ∈ [64,128] s`"; ED's actual registered value is 90 s / [45,180]; [64,128] is Crafting's R4-1 *forward obligation asking* ED to tighten. PC's margin conclusion is unaffected; the attribution is wrong.
- ⚠️ **RM's RN forward-pending tags stale (benign)** — RN landed `canisterCycleTime = 10.0 s` satisfying RM's floor; RM's "RN unauthored" dependency line + H.23/H.56 "forward-pending" gates should close out (RN already self-flagged this).
- ⚠️ **ED registries grooming** (known/carried): forward-obligations receiver-table row statuses; Q1/Q8 → HUD next-touch.

---

## Game Design Issues

### Blocking

**🔴 D1 — 2-player BC4 oxygen collapse at the modal squad size.**
RM's own D.6 arithmetic: a 2-player squad is net-oxygen-negative in every band, and one BC4 death leaves the lone survivor at ≈ **−7.2 u/s** — RM's text calls this "in practice, near-unrecoverable" — during the sole win-condition's 35–70 s window. RM names two fallbacks (squad-size-aware death cost; last-stand floor at `aliveCount ≤ 2`) but defers both to playtest **without committing to either** (RM OQ.4). 2-player is the stated modal Roblox case. The scenario seat adds the sharper frame: the instant 72-unit death cost is an **unannounced second wipe vector** stacked on the designed, telegraphed 3 s line-break grace — cross-referenced in neither GDD. **Needs a ruling before architecture:** author one fallback behind a playtest A/B, OR explicitly accept with a stated playtest kill-criterion (e.g., "if 2-player BC4 win-rate < X%, ship fallback Y").

### Warnings

- ⚠️ **Crafting F.4's five PA-row obligations unverified against PA's actual ACs** (Coil-worthwhile AC, `PREDATOR_BC4_MIN_COMMIT`, `PREDATOR_BC4_MAX_KNOCKBACK`, mobile variant, Anchor pre-activation read) — RESONANT's only non-Beacon sink hangs on these; a targeted reconciliation read is owed (candidate for PA's next-touch batch).
- ⚠️ **The anti-camping guarantee is jointly owned but not jointly documented** — full-passive camping is closed *only* by RM's always-on drain, not by ED's field model; RM's drain knobs have wide safe ranges. Add a cross-GDD invariant note in both RM and ED ("do not retune drain toward zero-equivalent without re-verifying ED's permanent-Calm attractor instrument").
- ⚠️ **Gather-phase dispersal is mechanically optimal with no proximity benefit** (RN D.2 rewards splitting; nothing makes clustering safer) — bounded Pillar-2 risk; named playtest target ("did the squad feel like a squad during the gather phase").
- ⚠️ **BC4 is the self-acknowledged attention-congestion peak** (HUD UI.5); the CR.8 figure-ground model resolves it on paper — make BC4-on-iPhone-SE a named first-playtest validation target.
- ⚠️ **Bench-cap freeze rule silent on mid-run join** — `benchMaxCraftersEffective` is "computed once at run start ... not recomputed on death/disconnect"; the join-grows-squad case is unspecified (compounds the known unauthored RunController gap).

### Notes / Strengths
No progression-loop competition (beacon is the singular point; persistence is cosmetic-only). Anti-pillars cleanly enforced at every surface checked (no difficulty toggle; cosmetic boundary actively enforced; solo-start disallowed / lone-survivor supported consistently). Historically degenerate beacon strategies (KITING, SENTRY, bunker-with-Canisters) genuinely closed with load-bearing mechanisms. Settled rulings corroborated in-text (respawn-at-squad-cost wired without double-charging; sabotage social-accept consistent with Crafting E.24/E.27; PA's exclusion-form quiet-check is a real designed escape valve). Five independently-authored GDDs converge on one vocabulary and identity — the design-theory seat's overall read: **"unusually mature and internally coherent."** The cross-run cosmetic-earn economy remains the one resource loop with zero authored mechanics (already an open question in game-concept.md; post-prototype/economy-designer).

---

## Cross-System Scenario Issues

Scenarios walked: 5 — S1 death/respawn (both halves), S2 beacon endgame, S3 oxygen crisis during Hunt, S4 gather chain, S5 mid-run join/leave.

- 🔴 **S1/S3 — PC × RM** — the C4 grace-timer contradiction (filed above; this is where it bites).
- ⚠️ **S2 — Crafting × RM × PA** — BC4 death oxygen shock (the D1/second-wipe-vector finding, filed above).
- ⚠️ **S1 — PC × RM** — `OnPlayerOxygenExpired` arity (filed above).
- ⚠️ **S5 — Crafting** — bench-cap join case (filed above).
- ℹ️ RunController (sole `RunEnded` broadcaster, victory-over-wipe precedence) remains unauthored and load-bearing for S1's wipe half — known/registered.
- ℹ️ Verified clean: the T5 pre-yield ordering chain (lock-release + S4-gate + alive-changed before the oxygen-spend yield); `deathEventId` idempotency contract (exact match PC↔RM); emit-before-reward (ED H.26); PA's S4 no-re-acquire + T6 table flush (no respawn-targeting bias).
- ℹ️ NOT-CHECKED residue: ED beacon-cap engage/clear mid-window vs Crafting's window (S2); the full RN→ED→PA→PC→HUD tick-level race analysis (S4) beyond the H.26 ordering guarantee; RM's squad-size input timing for `CRAFT_CONCURRENCY_CAP` (S5).

### Verified-clean cross-GDD highlights (consistency seats)
RN CR.7 ↔ PC OQ.13(b) dark-zone spacing reciprocal · PC↔PA damage/lock lifecycle tables match in detail · PC↔PA speed invariant `12 < 16 < 20` exact both sides · RN↔Crafting `OnGatherCompleted` satisfied bidirectionally · PA↔RM BC4 defeat-ownership (RR-3) consistent · HUD's Hard-Dependencies enumerate exactly the six producers that name HUD (modulo C5) · registry spot-checks: 13 core ED constants match GDD text.

---

## GDDs Flagged for Revision

| GDD | Reason | Type | Priority |
|-----|--------|------|----------|
| player-controller.md | C1 death-signal re-anchor; C4 grace-timer ownership; OnPlayerOxygenExpired arity; RN death-signal reverse-cite; BEACON_HALF_LIFE attribution | Consistency | Blocking |
| crafting-and-items.md | C2 death-signal re-anchor; C3 MAX_ACTIVE_BEACONS; bench-cap join rule | Consistency | Blocking |
| hud.md | C5 OnPredatorSense wiring; Q1/Q8 content (carried) | Consistency | Blocking |
| resource-management.md | C4 grace-timer ownership; D1 2-player BC4 ruling; stale RN forward-pending tags | Consistency + Design | Blocking |
| design/registry/entities.yaml | C6 stale squadAggregateT + missing MAX_ATTRIBUTION_ARCHIVE_ENTRIES | Consistency | Blocking (mechanical) |
| predator-ai.md | Verify Crafting F.4's five PA-row obligations against PA's ACs (fold into PA next-touch batch) | Consistency | Warning |
| ecological-disturbance.md | Joint anti-camping invariant note (with RM); registries grooming (carried) | Design | Warning |

---

## Verdict: **FAIL**

Seven blocking issues (C1–C6 + D1) must be resolved before architecture begins. Character of the failure: **not** design incoherence — the design-theory read is strongly positive — but seam debt: two CI-enforced ED mandates never landed in their approved receivers, one unauthored safety constant, one mutually-disowned mechanic, one mis-wired HUD channel, two registry lags, and one squad-size viability question awaiting a ruling.

### Required before re-running / architecture
1. PC + Crafting: death-signal re-anchor rewrites (C1, C2) + fold the arity fix and RN death-signal reverse-cite into the same PC touch.
2. Crafting: author `MAX_ACTIVE_BEACONS = 3` + AC (C3) + the bench-cap join rule.
3. **DECISION:** grace-timer owner + duration (C4) → author in the chosen GDD.
4. HUD: `OnPredatorSense` dependency + bearing re-attribution (C5).
5. Registry: update `squadAggregateT`, add `MAX_ATTRIBUTION_ARCHIVE_ENTRIES` (C6).
6. **DECISION:** 2-player BC4 — author a fallback vs accept-with-kill-criterion (D1).
7. Warning batch at each GDD's next touch (PA reconciliation read; joint anti-camping note; playtest-target flags).
