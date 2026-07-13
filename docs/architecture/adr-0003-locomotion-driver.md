# ADR-0003: Locomotion Driver — Humanoid vs. Character Controller Library

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) |
| **Domain** | Core (Movement / Animation) |
| **Knowledge Risk** | HIGH — the Character Controller Library reached full release post-LLM-cutoff (per `docs/engine-reference/roblox/breaking-changes.md`); legacy `Humanoid`-driven movement is well-represented in training data but its post-cutoff interaction with newer systems (Input Action System, `CharacterController`) is not. |
| **References Consulted** | `docs/engine-reference/roblox/VERSION.md`, `docs/engine-reference/roblox/breaking-changes.md` ("Character Controller Library — Full Release"), `docs/engine-reference/roblox/deprecated-apis.md`, `design/gdd/player-controller.md` (F.2a knobs, S1/S2 locomotion states), `design/gdd/predator-ai.md` (OQ.7, `PathfindingService:FindPathAsync` usage) |
| **Post-Cutoff APIs Used** | None chosen by this ADR — `Humanoid` predates the cutoff. If a future ADR revisits this in favor of `CharacterController`, that library is itself post-cutoff and would require its own knowledge-gap treatment at that time. |
| **Verification Required** | Before Foundation-layer implementation begins: confirm in Studio that `Humanoid.WalkSpeed` mid-sprint reassignment (PC's S1↔S2 transitions) produces no visible pop/snap at the `WALK_SPEED`/`SPRINT_SPEED` values chosen (12/20 studs/s), and that `PathfindingService:FindPathAsync` correctly routes an over-sized predator agent through representative level geometry (PA's own OQ.6(a)) — both are named in `game-concept.md`'s recommended `/prototype predator-ai` spike. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0008 (Character Replication Bandwidth Baseline & NetworkOwnership Strategy) — `NetworkOwnership` strategy is only meaningful once the locomotion driver (and therefore which parts replicate: `Humanoid` state vs. a custom controller's state) is fixed. Also unblocks Predator AI's own locomotion implementation (architecture.md's ADR #12, deferred to the should-have tier, gated on the `/prototype predator-ai` spike). |
| **Blocks** | Player Controller and Predator AI implementation start — the `WALK_SPEED < HUNT_APPROACH_SPEED < SPRINT_SPEED` invariant (both GDDs' own config-validation gate) is meaningless until a driver is chosen, since the two systems must agree on the same underlying movement primitive. |
| **Ordering Note** | Should be accepted early — both PC and PA GDDs explicitly deferred this decision to "an architecture ADR" rather than resolving it themselves (PC: "driver choice deferred to an ADR"; PA: "the locomotion driver ... are implementation decisions deferred to an architecture ADR"). |

## Context

### Problem Statement

Both Player Controller and Predator AI GDDs explicitly deferred the choice of movement/locomotion primitive to this ADR rather than resolving it themselves. Roblox now offers two viable primitives: the long-standing `Humanoid`-driven movement (well-represented in training data, `Humanoid.WalkSpeed`/`MoveTo`/`Died` idioms this project's GDDs already assume throughout) and the post-cutoff Character Controller Library (full release, offers finer control over jump curves, slope handling, and custom states, per `breaking-changes.md`). Predator AI's own author already recorded a **recommendation** on this exact question at OQ.7: *"Legacy Humanoid + `MoveDirection` is recommended over the new CharacterController library (live-platform + NPC-documentation risk); re-evaluate at prototype."* This ADR is the formal decision record for that recommendation, made after cross-checking it against Player Controller's independent needs.

### Constraints

- Every GDD written so far (`player-controller.md`, `predator-ai.md`) already writes its locomotion rules in `Humanoid` terms (`Humanoid.WalkSpeed`, `Humanoid.Health`, `Humanoid.Died`, `HumanoidRootPart.Position`) — dozens of ACs across both GDDs are phrased against these exact APIs. Choosing `CharacterController` would require rewriting a large surface of already-approved, already-AC-tested GDD text, not just an implementation detail.
- `breaking-changes.md` explicitly states `Humanoid` "still works — this is additive, not a removal," and its migration guidance is "existing projects using Humanoid need not migrate; new projects should evaluate Character Controller Library first" — a recommendation for greenfield projects to *evaluate*, not a mandate to adopt.
- Predator AI's NPC locomotion has the least training-data and devforum coverage under the Character Controller Library (a genuinely new-NPC-authoring surface); Player Controller's own author flagged the same live-platform risk.
- Both systems need the SAME driver — a split decision (PC on one, PA on the other) would break the `WALK_SPEED < HUNT_APPROACH_SPEED < SPRINT_SPEED` invariant's meaning, since it compares values that must live on comparable movement primitives.

### Requirements

- A single driver choice for both Player Controller and Predator AI.
- Must support server-authoritative speed control (`Humanoid.WalkSpeed`-equivalent) with no client-side override — server-authoritative movement is a hard project rule (`technical-preferences.md`).
- Must support `PathfindingService:FindPathAsync`-driven NPC movement for Predator AI without requiring a from-scratch physics-driven controller.
- Must not require rewriting the dozens of already-approved GDD ACs that are phrased in `Humanoid` terms.

## Decision

**Adopt legacy `Humanoid`-driven movement (via `Humanoid.WalkSpeed` and `MoveDirection`/`Humanoid:Move()`) as the locomotion driver for both Player Controller and Predator AI, ratifying Predator AI's own OQ.7 recommendation project-wide**, with an explicit re-evaluation checkpoint at the `/prototype predator-ai` spike rather than treating this as permanently closed.

This decision is made now, before either system is implemented, specifically so both systems share one driver from the start — not because the risk profile has been fully resolved (it has not; see Risks). The choice is justified by:
1. **Zero GDD rewrite cost.** Every `Humanoid`-phrased AC across `player-controller.md` and `predator-ai.md` remains valid as written. Choosing `CharacterController` would invalidate dozens of already-approved, already-tested acceptance criteria and require a design-review re-pass on both GDDs before implementation could even begin.
2. **Lower live-platform risk for THIS project's specific use case (NPC pathfinding-driven pursuit).** `CharacterController`'s documented strengths (jump curves, slope handling, custom states) serve player-controlled locomotion feel, which is not this project's stated risk area — PA's own author already identified NPC-authoring documentation coverage as the weaker of the two under the newer library.
3. **`Humanoid` is not deprecated** — `breaking-changes.md` is explicit that it "still works... this is additive, not a removal." Choosing it is not choosing a legacy/deprecated path; it is choosing the better-documented of two currently-supported options for this project's specific risk profile.

**This is explicitly NOT a permanent, unconditional decision.** The Verification Required checkpoint above (mid-sprint `WalkSpeed` reassignment smoothness, `FindPathAsync` routing through real level geometry) is the re-evaluation point PA's OQ.7 already named ("re-evaluate at prototype"). If the `/prototype predator-ai` spike surfaces a `Humanoid`-specific defect that `CharacterController` would avoid, this ADR should be revisited and superseded — not silently patched around.

### Architecture Diagram

```
Player Controller                Predator AI
   Humanoid.WalkSpeed                Humanoid.WalkSpeed
   (server sets: WALK_SPEED             (server sets: PREDATOR_PATROL_SPEED /
    / SPRINT_SPEED per S1/S2)             INVESTIGATE_SPEED / HUNT_APPROACH_SPEED /
   Humanoid.Died (T5 death path)          DISENGAGE_SPEED per FSM state)
   HumanoidRootPart.Position          PathfindingService:FindPathAsync
   (server-tracked, read by PA)          (drives Humanoid:MoveTo() waypoints)
        │                                       │
        └───────────── shared invariant ────────┘
        WALK_SPEED < PREDATOR_HUNT_APPROACH_SPEED < SPRINT_SPEED
        (both GDDs' own config-validation gate — meaningless unless
         both systems compare values on the SAME movement primitive)
```

### Key Interfaces

```luau
--!strict
-- Both PC and PA read/write the SAME Humanoid-based interface. No new engine API
-- surface is introduced by this ADR — this section documents the shared contract,
-- not new code.

-- Player Controller (server-authoritative speed control)
local humanoid = character:FindFirstChildOfClass("Humanoid") :: Humanoid
humanoid.WalkSpeed = WALK_SPEED   -- or SPRINT_SPEED, per S1/S2 transition (PC C.9)

-- Predator AI (NPC pathfinding-driven pursuit)
-- NOTE: Path:ComputeAsync() returns nothing — it mutates path.Status in place.
-- ComputeAsync also runs synchronously on the calling thread; wrap repath calls
-- in task.spawn for a frequently-repathing predator so a slow compute doesn't
-- stall the server Heartbeat (engine-specialist review 2026-07-06).
local path = PathfindingService:CreatePath({AgentRadius = PREDATOR_AGENT_RADIUS, ...})
local computeOk = pcall(function()
    path:ComputeAsync(predatorRoot.Position, targetPosition)
end)
if computeOk and path.Status == Enum.PathStatus.Success then
    path.Blocked:Connect(function(blockedWaypointIndex)
        -- dynamic obstructions (other players, physics props) invalidate an
        -- in-flight path; trigger a repath rather than continuing blindly.
        triggerRepath()
    end)
    for _, waypoint in path:GetWaypoints() do
        predatorHumanoid:MoveTo(waypoint.Position)
        predatorHumanoid.MoveToFinished:Wait()  -- sequence waypoints one at a time
    end
end
```

## Alternatives Considered

### Alternative 1: Character Controller Library for both systems
- **Description**: Adopt the post-cutoff Character Controller Library uniformly, rewriting PC's and PA's `Humanoid`-phrased GDD text against its API.
- **Pros**: Finer-grained movement control (jump curves, slope handling, custom states); Roblox's own migration guidance recommends new projects evaluate it first.
- **Cons**: Invalidates dozens of already-approved GDD acceptance criteria on both PC and PA, requiring a design-review re-pass before implementation can start; weakest documentation/training-data coverage is specifically in NPC-authoring (PA's exact use case, per its own author's OQ.7 note); this project's stated risk (predator pursuit feel, pathfinding-driven pursuit) is not the axis this library's documented strengths target.
- **Rejection Reason**: Higher migration cost and higher risk on exactly the axis (NPC locomotion) this project's own design process already flagged as the weak point.

### Alternative 2: Split decision — Humanoid for PC, Character Controller for PA
- **Description**: Let each system choose independently, since PC's needs (player-perceived feel) and PA's needs (NPC pursuit) are different problems.
- **Pros**: Each system could theoretically use the primitive best suited to its own concern.
- **Cons**: Breaks the `WALK_SPEED < PREDATOR_HUNT_APPROACH_SPEED < SPRINT_SPEED` invariant's meaning — both GDDs' own config-validation gate compares raw speed values assuming they live on a comparable movement primitive; a `Humanoid.WalkSpeed` value and a `CharacterController`-equivalent speed parameter are not guaranteed to be numerically comparable without an explicit conversion layer neither GDD specifies.
- **Rejection Reason**: Directly breaks an existing, approved, cross-system invariant both GDDs already depend on.

## Consequences

### Positive
- Zero rewrite cost to either already-approved GDD — every `Humanoid`-phrased AC remains valid.
- Both systems share one movement primitive, preserving the `WALK_SPEED < HUNT_APPROACH_SPEED < SPRINT_SPEED` invariant's validity.
- Formally ratifies a recommendation PA's own author already made (OQ.7), rather than leaving it as an unresolved open question into implementation.

### Negative
- Forgoes `CharacterController`'s finer movement control (custom jump curves, slope handling) — acceptable for MVP scope per both GDDs' current feature set, none of which currently requires those capabilities.
- Explicitly provisional: this ADR commits to a re-evaluation checkpoint rather than a final answer, which means a possible ADR revision mid-Pre-Production if the prototype spike surfaces a defect. This is a deliberate trade-off (decide now so both systems can start implementation) rather than an oversight.

### Risks
- **Live-platform documentation gap for `Humanoid` + Character Controller Library co-existence**: since Character Controller is additive, not a replacement, `Humanoid` in a build alongside the newer library is not a fully training-data-covered configuration (the two systems' documented interaction, if any, post-dates the cutoff). **Mitigation**: this project does not currently use `CharacterController` anywhere, so co-existence is moot for now; flag for re-check if any future system (e.g., the deferred Camera ADR) is authored against `CharacterController`.
- **Mid-sprint `WalkSpeed` reassignment smoothness is unverified** — PC's own S1↔S2 transition (T1/T2, C.9) reassigns `Humanoid.WalkSpeed` server-side; whether this produces a visible pop vs. a smooth accelerate/decelerate is a Studio-verifiable behavior, not something confirmable from documentation alone. **Mitigation**: named explicitly in Verification Required; part of the `/prototype predator-ai` spike's PC-adjacent smoke check (or a small standalone PC prototype, if the predator-ai spike doesn't cover PC movement feel directly).
- **`FindFirstChildOfClass("Humanoid")` spawn-timing race** (identified by gameplay-programmer engine-specialist review 2026-07-06): calling this before `CharacterAdded` has fully resolved can return nil; prefer `:WaitForChild("Humanoid")` at character-setup time to avoid a nil dereference on fresh spawns.
- **`PathfindingService:FindPathAsync` cost and routing quality through real (non-blockout) level geometry is unverified** — PA's own OQ.6(a) already names this as a must-validate item before its numbers (repath delta, agent radius) are trusted. **Mitigation**: this is the `/prototype predator-ai` spike's primary purpose; this ADR's locomotion-driver choice does not resolve it, only shares the same open item PA already flagged.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| player-controller.md | `WALK_SPEED`/`SPRINT_SPEED` (F.2a knobs), S1/S2 locomotion states (C.9), driver choice explicitly "deferred to an architecture ADR" | Confirms `Humanoid.WalkSpeed` as the mechanism; no GDD text requires revision |
| predator-ai.md | OQ.7 (locomotion driver recommendation), the `WALK_SPEED < PREDATOR_HUNT_APPROACH_SPEED < SPRINT_SPEED` config-validation invariant, `PathfindingService:FindPathAsync` usage | Ratifies OQ.7's own recommendation; confirms both systems share one comparable movement primitive so the invariant remains meaningful |

## Performance Implications
- **CPU**: No change from either GDD's existing assumptions — both already assumed `Humanoid`-based movement in their formulas and ACs; this ADR changes nothing about runtime cost, only confirms the assumption formally.
- **Memory**: None beyond standard `Humanoid`/`HumanoidRootPart` per-character overhead, already implicit in both GDDs.
- **Load Time**: None.
- **Network**: Deferred to ADR-0008 (Character Replication Bandwidth Baseline & NetworkOwnership Strategy), which depends on this ADR's driver choice.

## Migration Plan
No migration — neither system is implemented yet. This ADR is the baseline both GDDs already assumed informally; formalizing it now prevents the two systems from independently drifting to different choices during implementation.

## Validation Criteria
- The `/prototype predator-ai` spike (already recommended by `game-concept.md`) explicitly tests: (a) mid-sprint `Humanoid.WalkSpeed` reassignment smoothness at the chosen `WALK_SPEED`/`SPRINT_SPEED` values, (b) `FindPathAsync` routing an oversized predator agent through representative (non-blockout) level geometry.
- If either check fails in a way `CharacterController` would plausibly avoid, this ADR must be revisited and explicitly superseded — not silently worked around in implementation.

## Related Decisions
- Enables ADR-0008 (Character Replication Bandwidth Baseline & NetworkOwnership Strategy).
- `design/gdd/predator-ai.md` OQ.7 (the recommendation this ADR ratifies), OQ.6(a) (the same prototype-spike dependency).
- `design/gdd/player-controller.md` (driver choice deferral note, S1/S2 locomotion states).
- `docs/architecture/architecture.md` — Required ADRs #1, Open Questions (locomotion driver).
