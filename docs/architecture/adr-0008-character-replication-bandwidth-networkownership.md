# ADR-0008: Character Replication Bandwidth Baseline & NetworkOwnership Strategy

## Status
Proposed

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) |
| **Domain** | Networking (character replication, `NetworkOwnership`) |
| **Knowledge Risk** | HIGH — the exact per-character baseline replication cost (`Humanoid`/`HumanoidRootPart` CFrame + property replication) is engine-version- and network-settings-dependent, and this project's own architecture document already flags it as unverified ("~15–30 KB/s before any game code runs" is a rough estimate, not a measured figure). `NetworkOwnership` semantics themselves are long-standing and well-documented (LOW risk on that specific sub-topic), but the actual bandwidth number requires empirical profiling, not documentation lookup. |
| **References Consulted** | `docs/architecture/architecture.md` (Required ADR #8, TR-xcut-004/TR-pa-002), ADR-0003 (Locomotion Driver — confirms `Humanoid` as the shared movement primitive this ADR's replication cost is computed against), `design/gdd/predator-ai.md` (H.30 always-broadcast state policy, `PREDATOR_T_LATENCY_MAX`, OQ.6(b) replication-smoothness prototype dependency), `.claude/docs/technical-preferences.md` (< 50 KB/s per-client advisory ceiling) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | The actual baseline per-character replication cost at the pinned Studio version, for a 4-player + 1-predator scene, MUST be measured empirically (e.g., via the Roblox Studio Network stats overlay or `Stats` service during the `/prototype predator-ai` spike) before any other system's bandwidth budget is treated as final — this is exactly what `architecture.md` itself already states ("every other system's signal budget is provisional until this is profiled"). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Locomotion Driver) — the replication cost model below assumes `Humanoid`-driven characters, not a `CharacterController`-based alternative. |
| **Enables** | Finalizes the bandwidth-budget accounting every other system's signal design (ED's H.37 ≈8.2 KB/s figure, PA's own broadcast policy, HUD's rate-limited signals) has been provisionally designed against. |
| **Blocks** | No epic is directly blocked, but `architecture.md` names this as the ADR that makes every other system's bandwidth budget non-provisional — it should be accepted (or at minimum, its empirical profiling step run) before a final cross-system bandwidth rollup is trusted. |
| **Ordering Note** | Should be profiled during the same `/prototype predator-ai` spike ADR-0003 and PA's OQ.6 already require, since both need the same running scene (4 players + 1 predator) to measure against. |

## Context

### Problem Statement

Every system's own bandwidth accounting in this project (ED's H.37 ≈8.2 KB/s disturbance-signal figure, PA's always-broadcast predator-state policy, HUD's rate-limited signals) is designed against the `< 50 KB/s per-client` advisory ceiling in `technical-preferences.md` — but none of them account for the **baseline cost of character replication itself** (Humanoid state, `HumanoidRootPart` CFrame, per player character, before any of this project's own game-code signals are added). `architecture.md` already names this gap explicitly: "Primary bandwidth consumer (~15–30 KB/s before any game code runs) — every other system's signal budget is provisional until this is profiled." This ADR establishes the accounting baseline and, separately, the `NetworkOwnership` strategy (who — client or server — owns the physics simulation of which characters), which affects both bandwidth and input responsiveness.

### Constraints

- Movement and visual feedback ARE allowed to be client-predicted (`game-concept.md`: "Client prediction scope is restricted to movement and visual feedback only"); gameplay-consequential state (gather/craft/disturbance/oxygen/beacon outcomes) is NOT — this constrains which characters can safely use default client-side `NetworkOwnership` without violating server authority.
- The predator NPC's positioning is entirely server-driven (`PathfindingService:FindPathAsync` results, server FSM state) — PA's own GDD already establishes `SetNetworkOwner(nil)` (explicit server ownership) for the predator, this ADR ratifies rather than re-derives that.
- `< 50 KB/s` per-client is the advisory ceiling every system budgets against; this ADR's baseline consumes a share of that budget before any game-specific signal exists.

### Requirements

- A `NetworkOwnership` decision for both player characters and the predator NPC.
- A documented (even if provisional-pending-profiling) baseline bandwidth accounting so other systems' budgets can be checked against a real total, not each system's isolated assumption.

## Decision

### NetworkOwnership strategy

**Player characters: default automatic `NetworkOwnership`** (Roblox's standard behavior — the owning client's machine simulates its own character's physics for local responsiveness). This is compatible with server authority because:
- `Humanoid.WalkSpeed` is still server-set (Player Controller's own S1/S2 transitions) — the client cannot locally increase its own speed beyond what the server has assigned, since `WalkSpeed` itself replicates server→client, not the reverse.
- Movement *feel* (client-side physics simulation smoothness) is exactly the category `game-concept.md` permits client prediction for; gameplay outcomes (gather, craft, disturbance emission, oxygen deduction, beacon activation) are all server-validated RemoteEvent round-trips (ADR-0006), never inferred from client-owned physics state.
- This is the Roblox-idiomatic default for player-controlled characters — deviating from it (forcing server ownership of every player character) would remove local responsiveness for zero server-authority benefit, since the actual gameplay-critical state is already protected by RemoteEvent validation, not by physics ownership.
- **Distinction from ownerless-prop proximity handoff** (engine-specialist review 2026-07-06): automatic `NetworkOwnership`'s well-known "reassigns to whichever client is nearest" behavior applies to *ownerless physics props* (loose items, resource nodes, ragdolls) — it does NOT apply to a player's own controlled character assembly, which Roblox always automatically owns by that specific player regardless of other players' proximity. This ADR's default-ownership choice for player characters is stable, not proximity-based; the proximity-handoff behavior is a separate concern relevant to future ownerless-prop systems (e.g., Resource Node physics), not to this decision.

**Predator NPC: explicit server `NetworkOwnership`** (`predatorHumanoid.RootPart:SetNetworkOwner(nil)`, already established in Predator AI's own approved GDD — this ADR ratifies it as the binding cross-system decision, since it's also a bandwidth/architecture concern this ADR is responsible for). The predator has no owning client to delegate physics simulation to (it's not player-controlled), and its position is driven entirely by server-side `PathfindingService` results — client ownership would be meaningless and would also violate PA's own explicit design (all predator state changes must broadcast to all clients within one replication cycle, H.30, which assumes server-authoritative predator state as the single source of truth).

### Baseline bandwidth accounting (provisional pending empirical profiling)

**Decision**: treat `architecture.md`'s own **~15–30 KB/s "before any game code runs"** figure as a **provisional planning ceiling**, not a design input to be treated as precise, until the `/prototype predator-ai` spike empirically measures the actual figure for a representative 4-player + 1-predator scene at this project's pinned Studio version. Until that measurement exists:
- Every system's own bandwidth budget (ED's ≈8.2 KB/s, PA's broadcast policy, HUD's rate-limited signals) should be evaluated against **`50 KB/s minus the measured baseline`**, not against the full 50 KB/s ceiling as if character replication were free.
- Using the provisional 15–30 KB/s range as a placeholder, remaining budget for all game-specific signals combined is provisionally **20–35 KB/s** — comfortably above ED's own ≈8.2 KB/s figure, but this ADR does not certify the combined total is safe until the baseline is actually measured.

This ADR's role is to make the accounting explicit and binding (every future system's own bandwidth section should subtract from the *measured* baseline, once it exists, not budget against the full ceiling), not to assert a false precision this project cannot currently back up from documentation alone.

### Architecture Diagram

```
Per-client bandwidth budget: < 50 KB/s (technical-preferences.md advisory ceiling)
        │
        ├── Character replication baseline (THIS ADR)
        │     - N player characters' Humanoid/HumanoidRootPart state (client-owned,
        │       server WalkSpeed authority) — provisional ~15-30 KB/s combined,
        │       PENDING EMPIRICAL MEASUREMENT at /prototype predator-ai
        │     - 1 predator NPC's Humanoid/HumanoidRootPart state (server-owned,
        │       SetNetworkOwner(nil), always-broadcast per PA's H.30)
        │
        └── Remaining budget for all game-specific signals combined
              - Ecological Disturbance: ≈8.2 KB/s (H.37, already derived)
              - HUD: rate-limited signals (≤5 Hz OnStaminaChanged, etc.)
              - Predator AI: state-change broadcasts (H.30, ≤250ms cycle)
              - Player Controller: RemoteEvent surface (ADR-0006)
              - (any future system's signals)
```

### Key Interfaces

```luau
--!strict
-- Predator NPC: explicit server ownership (ratifies PA's own existing GDD design).
-- GOTCHAS (engine-specialist review 2026-07-06):
--   1. SetNetworkOwner throws if the part is Anchored — if a future "freeze"/stagger
--      state is ever implemented via anchoring rather than WalkSpeed = 0, this call
--      will error at runtime. Do not anchor the predator's HumanoidRootPart.
--   2. Ownership is set per PART INSTANCE, not persisted on a template/model — this
--      call MUST be re-invoked on every predator respawn/recreate, not just initial
--      spawn, or the new HumanoidRootPart instance silently defaults back to
--      automatic ownership.
local predatorRoot = predatorCharacter:FindFirstChild("HumanoidRootPart") :: BasePart
predatorRoot:SetNetworkOwner(nil)  -- server-owned; no client simulates predator physics
-- MANDATE: this exact call must be re-invoked from Predator AI's own respawn/recreate
-- code path (wherever the predator's character is destroyed and rebuilt), not just
-- from initial spawn — this ADR does not itself own that code path, only the requirement.

-- Player characters: NO explicit SetNetworkOwner call — Roblox's default automatic
-- ownership behavior is retained. Server-authoritative gameplay state (WalkSpeed,
-- death, RemoteEvent outcomes) is enforced through the normal server-authority
-- mechanisms (ADR-0006's trust boundary), NOT through forcing NetworkOwnership.
```

## Alternatives Considered

### Alternative 1: Server-owned NetworkOwnership for all characters (players included)
- **Description**: Force every character, player and predator alike, onto explicit server `NetworkOwnership`, maximizing server authority over physics.
- **Pros**: Removes any theoretical client-side physics manipulation surface.
- **Cons**: Loses local movement responsiveness for every player (input-to-visual-feedback latency becomes round-trip-bound rather than locally simulated), for a benefit this project doesn't need — gameplay-consequential outcomes are already protected by RemoteEvent server validation (ADR-0006), not by physics ownership, and `game-concept.md` explicitly permits client-predicted movement/visual feedback.
- **Rejection Reason**: Pure cost (input latency, player-perceived responsiveness) with no corresponding gameplay-authority benefit this project's threat model requires.

### Alternative 2: Defer this ADR entirely until post-implementation profiling
- **Description**: Don't write a bandwidth ADR now; just implement and measure later, adjusting other systems' budgets reactively.
- **Pros**: Avoids asserting a provisional number that could be wrong.
- **Cons**: `architecture.md` explicitly names this as a must-have-before-coding ADR precisely because every OTHER system's already-approved GDD (ED's H.37, PA's H.30, HUD's rate limits) was designed assuming SOME baseline exists — deferring the ADR entirely leaves those existing numbers unaccountable against anything, which is worse than an explicitly-provisional but present accounting.
- **Rejection Reason**: `architecture.md`'s own Required ADRs list already treats this as blocking-tier for exactly this reason; a provisional-but-explicit number is more useful than no number at all.

## Consequences

### Positive
- `NetworkOwnership` strategy is now explicit and binding for both player characters and the predator, formalizing what PA's GDD already assumed for the predator and stating the (previously implicit) default-ownership choice for players.
- The bandwidth accounting model (subtract measured baseline from the 50 KB/s ceiling before evaluating other systems' budgets) is now the binding method, even though the baseline number itself is still provisional.

### Negative
- This ADR cannot certify the combined bandwidth total is safe until the empirical measurement exists — it formalizes the accounting method and the NetworkOwnership decision, but explicitly does NOT close the risk `architecture.md` flagged.

### Risks
- **Engine-specialist review (2026-07-06) fixes/notes**: `SetNetworkOwner` throws if called on an `Anchored` part — noted as a constraint on how any future predator "freeze"/stagger state must be implemented (via `WalkSpeed = 0`, not anchoring); `SetNetworkOwner` is set per part instance, not persisted on a template, so it must be re-invoked on every predator respawn/recreate, not just initial spawn — flagged as a mandate on Predator AI's own respawn code path; added an explicit distinction between player-character ownership (stable, always owned by that player) and ownerless-prop ownership (proximity-based handoff) so future readers don't conflate the two when designing physics for Resource Node or other prop systems.
- **The 15–30 KB/s baseline figure is unverified** — if the actual measured figure is at or above the high end of that range, ED's own ≈8.2 KB/s plus HUD/PA signals could push the combined total uncomfortably close to the 50 KB/s ceiling, especially under the mobile baseline's tighter constraints. **Mitigation**: this is exactly why the gate-check's own day-1 recommendations called for front-loading this empirical verification; the `/prototype predator-ai` spike should measure it before Production sprint planning treats any system's bandwidth budget as final.
- **Default player `NetworkOwnership` combined with a laggy/high-latency client** could, in principle, create a wider gap between client-simulated position and server-tracked position that Predator AI (which reads server-tracked `HumanoidRootPart.Position`, per ADR-0003) never sees — this is a normal Roblox replication-lag characteristic, not a bug introduced by this ADR, and is already accounted for by PA's own `PREDATOR_T_LATENCY_MAX = 0.15s` config gate.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| predator-ai.md | `SetNetworkOwner(nil)` for the predator (already implicit in PA's own GDD text), H.30 always-broadcast state policy, OQ.6(b) replication-smoothness prototype dependency | Ratifies the server-ownership choice as a binding cross-system architecture decision; ties the bandwidth accounting to the same prototype spike OQ.6 already names |
| ecological-disturbance.md | H.37 ≈8.2 KB/s disturbance-signal bandwidth figure | This ADR's accounting model treats ED's figure as consuming from the *remaining* budget after the (currently provisional) character-replication baseline, not the full 50 KB/s ceiling |

## Performance Implications
- **CPU**: NetworkOwnership choice affects which machine (client vs. server) runs physics simulation for a given character — no change to total simulation work, only where it runs.
- **Memory**: None beyond standard per-character replication state, already implicit in every GDD that assumed characters exist.
- **Load Time**: None.
- **Network**: This ADR IS the network-bandwidth accounting decision — see Decision and Architecture Diagram above.

## Migration Plan
No migration — no characters are implemented yet.

## Validation Criteria
- The `/prototype predator-ai` spike measures actual per-client bandwidth for a representative 4-player + 1-predator scene (via Studio's Network stats or `Stats` service), before Production sprint planning treats any system's bandwidth budget as final.
- Once measured, this ADR should be revisited to replace the provisional 15–30 KB/s range with the actual figure — flagged as an Open Question below, not silently left stale.

## Related Decisions
- Depends on ADR-0003 (Locomotion Driver).
- `docs/architecture/architecture.md` — Required ADR #8, `.claude/docs/technical-preferences.md`'s `< 50 KB/s` ceiling.
- `design/gdd/predator-ai.md` H.30, OQ.6(b).

## Open Questions
- **Actual measured baseline bandwidth figure** — this ADR's 15–30 KB/s range is provisional; the `/prototype predator-ai` spike's measurement should replace it, and every other system's bandwidth accounting should be re-checked against the real number once available, not left assuming the provisional range indefinitely.
