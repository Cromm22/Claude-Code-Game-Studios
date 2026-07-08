# ADR-0011: Player Controller Sprint-State Authority & Stamina Lifecycle

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + Knit framework |
| **Domain** | Core (locomotion state machine, server-authoritative resource) |
| **Knowledge Risk** | LOW — this ADR reuses `Humanoid.WalkSpeed` (already ratified as the shared locomotion primitive, ADR-0003) and `RunService.Heartbeat`; no new engine API is introduced. |
| **References Consulted** | `design/gdd/player-controller.md` (F.2 sprint-state authority, F.2a stamina knobs, C.9 RemoteEvent surface, H.12a), ADR-0003 (Locomotion Driver), ADR-0006 (RemoteEvent Trust Boundary — this ADR's `RequestSprintToggle` handling follows its canonical 6-step order verbatim), ADR-0001 (KnitInit/KnitStart Ordering Discipline) |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | None beyond ADR-0003's own mid-sprint `WalkSpeed` reassignment smoothness check (the `/prototype predator-ai` spike). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0003 (Locomotion Driver — this ADR's S1/S2 states are expressed as `Humanoid.WalkSpeed` values); ADR-0006 (RemoteEvent Trust Boundary — `RequestSprintToggle` follows its canonical validation order). |
| **Enables** | Player Controller epic — one of PC's own three self-flagged, previously-unauthored ADRs (per `production/epics/player-controller/EPIC.md`). |
| **Blocks** | No other ADR, but every PC Logic story touching sprint or stamina depends on this ADR. |
| **Ordering Note** | Independent of ADR-0012 (this project's other PC ADR) — the two can be Accepted in either order. |

## Context

### Problem Statement

Player Controller's own GDD (F.2/F.2a) specifies a server-gated two-state sprint
model (S1 Walk / S2 Sprint) backed by a server-authoritative stamina resource,
but explicitly deferred the actual authority model and drain/regen tick to "an
architecture ADR" that was never written — one of three ADRs PC's own F.4 section
named as necessary. Without this decision, the sprint toggle's server-side
validation has no state machine to validate against, and stamina has no
tick-loop home.

### Constraints

- Sprint is client-toggleable (touch) or hold-based (KB+M/gamepad), per the
  Hold-vs-Toggle Action pattern already documented in `design/ux/interaction-patterns.md`
  — this ADR governs the server-side authority model underneath both input shapes,
  not the input binding itself (that's PC's own GDD + the UX pattern library's job).
- `RequestSprintToggle` must be validated via ADR-0006's canonical 6-step order
  (alive-guard → rate/burst → global budget → payload → server-side re-derivation
  → domain validation) — this ADR's job is step 6 (the domain validation: is the
  player actually allowed to sprint right now).
- Stamina must be server-authoritative; the client never gates its own input based
  on a locally-tracked stamina value (the server is the sole decider of whether
  a sprint request succeeds).
- Must guard against a "ghost sprint" — a client that stops sending `PlayerHeartbeat`
  (PC's own liveness ping, C.9) while still flagged as sprinting server-side, e.g.
  after a dropped connection that hasn't yet triggered `PlayerRemoving`.

### Requirements

- A two-state server-authoritative locomotion state (S1 Walk / S2 Sprint) with
  `Humanoid.WalkSpeed` set server-side on every transition.
- `STAMINA_MAX = 100`, drain rate `12.5/s` while in S2, regen rate `10/s` after a
  `REGEN_DELAY = 1.5s` of not sprinting, forced transition to S1 at `stamina <= 0`.
- `OnStaminaChanged` pushed to the owning client only, rate-limited to `<=5Hz`.
- A client-liveness timeout (`SPRINT_CLIENT_TIMEOUT = 3s`) that force-reverts a
  sprinting player to S1 if their `PlayerHeartbeat` ping goes stale.

## Decision

**A two-state server-authoritative locomotion state, `S1 (Walk)` / `S2 (Sprint)`,
owned entirely by `PlayerControllerService`, transitioning only in response to a
validated `RequestSprintToggle` (or a forced-revert condition), never a client-asserted state:**

1. **`RequestSprintToggle` handling** (ADR-0006 steps 1–5 apply generically; this
   ADR is step 6, the domain validation): a toggle request is only honored if
   `currentState == S1` and `stamina > 0`. A request to sprint at `stamina <= 0`
   is silently ignored (no state change, no error) — this is the "sprint input
   ignored until stamina>0" rule from PC's own F.2. A request to stop sprinting
   (`S2 -> S1`) is always honored, server-side, immediately.

2. **`Humanoid.WalkSpeed` set on every transition**: `S1 -> WALK_SPEED (12)`,
   `S2 -> SPRINT_SPEED (20)` — both already-ratified constants from ADR-0003.
   The assignment happens server-side, inside the same handler that processes
   the toggle, never client-side.

3. **Stamina tick** (`RunService.Heartbeat`-bound, connected in `KnitStart` per
   the same reasoning as ADR-0010's tick — an engine-event connection, not a
   cross-service-visible object ADR-0001 Rule 1 governs): while in S2, drain
   `12.5 * dt` per tick, clamped to `[0, STAMINA_MAX]`. While in S1 and at least
   `REGEN_DELAY (1.5s)` has elapsed since the player last left S2, regen
   `10 * dt` per tick, clamped to `[0, STAMINA_MAX]`. **Forced transition**: if
   stamina reaches `0` while in S2, the server immediately force-transitions to
   S1 (sets `Humanoid.WalkSpeed = WALK_SPEED`) in the same tick that stamina hits
   zero — the player is never left in S2 with 0 stamina, even for one frame.

4. **`OnStaminaChanged` push**: rate-limited to `<=5Hz`, sent only to the owning
   client (never `:FireAll`), carrying the current stamina value. The client
   never uses this value to gate its own input — it is display-only.

5. **Ghost-sprint guard**: `PlayerHeartbeat` (PC's own C.9 liveness ping, sent by
   the client at 1Hz while in S2 only) is tracked server-side as
   `_lastHeartbeatTime[player]`. A separate Heartbeat-bound watchdog checks: if
   `currentState == S2` and `now - _lastHeartbeatTime[player] > SPRINT_CLIENT_TIMEOUT (3s)`,
   force-transition to S1, identical to the stamina-exhaustion force-transition
   above (server sets `WalkSpeed`, no client round-trip required).

### Architecture Diagram

```
                    RequestSprintToggle (validated per ADR-0006 steps 1-5)
                              │
                              ▼
              ┌───────────────────────────────┐
              │  currentState == S1?           │
              │  AND stamina > 0?               │──NO──► silently ignored (no state change)
              └───────────────┬─────────────────┘
                              │ YES
                              ▼
                    S1 ──────────────► S2
                    WALK_SPEED=12      SPRINT_SPEED=20
                    (Humanoid.WalkSpeed set server-side on every transition)
                              │
                    ┌─────────┴──────────┐
                    │  While in S2:        │
                    │  drain 12.5/s tick   │
                    │  (Heartbeat-bound)   │
                    └─────────┬──────────┘
                              │
              ┌───────────────┴────────────────┐
              │ stamina reaches 0?               │──YES──► FORCE S2->S1 (same tick, no client round-trip)
              │ OR PlayerHeartbeat stale >3s?     │──YES──► FORCE S2->S1 (ghost-sprint guard)
              └───────────────┬────────────────┘
                              │ NO (still sprinting normally)
                              ▼
                    stays in S2 until player releases / toggles off (always honored)
                              │
                              ▼
                    S2 -> S1: regen 10/s begins after REGEN_DELAY=1.5s elapsed
```

### Key Interfaces

```luau
--!strict
local STAMINA_MAX = 100
local STAMINA_DRAIN_RATE = 12.5      -- per second, while in S2
local STAMINA_REGEN_RATE = 10        -- per second, while in S1 and past REGEN_DELAY
local REGEN_DELAY = 1.5              -- seconds since leaving S2
local SPRINT_CLIENT_TIMEOUT = 3.0    -- seconds of stale PlayerHeartbeat before force-revert

-- PC's own C.11 clock-injection seam (production default; tests override this
-- field directly). Added 2026-07-06 re-verification fix — the original draft
-- called workspace:GetServerTimeNow() inline in two places below, which PC's
-- GDD explicitly forbids and grep-gates for exactly this reason.
PlayerControllerService.getServerTime = function() return workspace:GetServerTimeNow() end

type LocomotionState = "S1" | "S2"

-- Domain validation (ADR-0006 step 6) for RequestSprintToggle.
function PlayerControllerService:_handleSprintToggleRequest(player: Player): ()
    local state = self._playerState[player]
    if state.locomotion == "S1" then
        if state.stamina <= 0 then
            return  -- silently ignored — F.2's "sprint input ignored until stamina>0"
        end
        self:_transitionTo(player, "S2")
    else
        self:_transitionTo(player, "S1")  -- stopping sprint is always honored
    end
end

function PlayerControllerService:_transitionTo(player: Player, newState: LocomotionState): ()
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    local state = self._playerState[player]
    state.locomotion = newState
    humanoid.WalkSpeed = if newState == "S2" then SPRINT_SPEED else WALK_SPEED
    if newState == "S1" then
        state.lastLeftSprintAt = self.getServerTime()  -- C.11 seam, NOT inline workspace:GetServerTimeNow() (fixed 2026-07-06 re-verification — see review report Conflict #7)
    end
end

-- Stamina + ghost-sprint watchdog tick, connected in KnitStart.
-- NOTE (engine-specialist review 2026-07-06): the original draft called an
-- undefined `now_since_left_sprint(state)` helper from a branch where a local
-- `now` declared in a sibling `if` branch was out of scope — both fixed below
-- by computing `now` once at the top of the loop body and inlining the
-- regen-eligibility check.
-- NOTE (2026-07-06 re-verification, review report Conflict #7): the original
-- draft also called workspace:GetServerTimeNow() inline here, bypassing PC's
-- own C.11 clock-injection seam (grep-gated by PC's GDD) — fixed below.
function PlayerControllerService:_onStaminaTick(dt: number): ()
    local now = self.getServerTime()  -- C.11 seam, NOT inline workspace:GetServerTimeNow()
    for player, state in self._playerState do
        if state.locomotion == "S2" then
            state.stamina = math.clamp(state.stamina - STAMINA_DRAIN_RATE * dt, 0, STAMINA_MAX)
            if state.stamina <= 0 then
                self:_transitionTo(player, "S1")  -- forced, same tick, no client round-trip
            end
            -- Ghost-sprint guard: stale liveness ping force-reverts.
            if now - (state.lastHeartbeatAt or 0) > SPRINT_CLIENT_TIMEOUT then
                self:_transitionTo(player, "S1")
            end
        elseif now - (state.lastLeftSprintAt or 0) >= REGEN_DELAY then
            state.stamina = math.clamp(state.stamina + STAMINA_REGEN_RATE * dt, 0, STAMINA_MAX)
        end
    end
end

-- Cleanup: without this, self._playerState leaks a table per departed player
-- for the life of the server (the same class of leak ADR-0004/ADR-0006 already
-- guard against for their own per-player tables).
Players.PlayerRemoving:Connect(function(player: Player)
    PlayerControllerService._playerState[player] = nil
end)
```

## Alternatives Considered

### Alternative 1: Client-side stamina prediction with server reconciliation
- **Description**: Let the client locally simulate stamina drain/regen for responsiveness, with the server periodically reconciling and correcting drift.
- **Pros**: Could reduce perceived input latency on the stamina-gated sprint-toggle decision.
- **Cons**: `game-concept.md`'s client-prediction scope is explicitly restricted to movement and visual feedback only — stamina is a gameplay-consequential resource (it gates sprint availability), not movement/visual feedback, so predicting it client-side would violate that project-wide rule. It also reintroduces exactly the reconciliation-drift class of bug ADR-0005 already had to solve once for oxygen.
- **Rejection Reason**: Violates the project's own client-prediction scope rule; server-authoritative-only is both simpler and already the established pattern for every other gameplay resource.

### Alternative 2: No ghost-sprint guard — rely solely on `PlayerRemoving` for cleanup
- **Description**: Skip the `PlayerHeartbeat`-staleness watchdog; only force a player out of S2 when they fully disconnect (`PlayerRemoving`).
- **Pros**: One fewer watchdog to implement.
- **Cons**: A client that stops responding but hasn't fully disconnected (e.g., a frozen client, a network partition short of a full drop) would remain in S2 — sprinting, at `SPRINT_SPEED`, indefinitely, from the server's perspective, until the connection times out at the platform level (which can take much longer than 3 seconds). This is exactly the "ghost sprint" PC's own C.9 already names as a risk.
- **Rejection Reason**: PC's own GDD already identified this risk and named the `SPRINT_CLIENT_TIMEOUT` constant; omitting the guard would leave a known, already-scoped risk unaddressed.

## Consequences

### Positive
- Sprint-state authority now has an explicit, implementable model — one of PC's three previously-unauthored, self-flagged ADRs is closed.
- The forced-transition-on-zero-stamina rule (same tick, no client round-trip) prevents any frame where a player is visibly sprinting at zero stamina, closing a plausible visual/logical inconsistency before it could occur.
- The ghost-sprint guard closes a named risk from PC's own GDD using a mechanism (a Heartbeat-bound liveness check) consistent with patterns already established elsewhere in this project (ADR-0010's tick loop).

### Negative
- Adds a second per-player Heartbeat-bound watchdog (stamina + ghost-sprint) alongside RM's own tick loop (ADR-0010) and ED's field-update loop (ADR-0004) — three independent server tick loops now exist. Each is individually cheap, but this is worth noting as a pattern to watch if a fourth or fifth system wants its own tick loop (a shared tick-dispatcher might become worth considering at that point, though not yet).

### Risks
- **Engine-specialist review (2026-07-06) fixes**: the Key Interfaces sample called an undefined `now_since_left_sprint(state)` helper from a branch where the `now` timestamp (declared inside a sibling `if` branch) was out of scope — both would have failed to compile under `--!strict`. Fixed by computing `now` once at the top of `_onStaminaTick`'s loop body and inlining the regen-eligibility check directly. Also added an explicit `PlayerRemoving` cleanup for `_playerState`, which the original draft omitted — without it, this table leaks one entry per departed player for the life of the server, the same class of leak this project's other per-player tables (ADR-0004, ADR-0006) already guard against.
- **`/architecture-review` re-verification fix (2026-07-06)**: the original Key Interfaces sample called `workspace:GetServerTimeNow()` inline in `_transitionTo` and `_onStaminaTick`, bypassing PC's own C.11 clock-injection seam — a GDD-mandated, CI-grep-gated rule this ADR itself is supposed to implement for. This is the same bug class already caught once in ADR-0005 (still unfixed there as of this ADR's authoring). Fixed by adding `PlayerControllerService.getServerTime` as a seam (production default wraps `workspace:GetServerTimeNow()`, test-overridable) and routing both call sites through it.
- **`Humanoid.WalkSpeed` mid-sprint reassignment smoothness is unverified** — this is the same risk ADR-0003 already names and defers to the `/prototype predator-ai` spike; this ADR does not re-verify it, only inherits the same open item.
- **`FindFirstChildOfClass("Humanoid")` spawn-timing race** — the same risk ADR-0003 already flags; this ADR's `_transitionTo` function should use `:WaitForChild("Humanoid")` at character-setup time rather than assuming the Humanoid exists at call time, per ADR-0003's own guidance.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| player-controller.md | F.2 sprint-state authority model (server-gated T1/T2, forced-walk at 0 stamina, sprint input ignored until stamina>0); F.2a stamina knobs (`STAMINA_MAX=100`, drain 12.5/s, regen 10/s, `REGEN_DELAY=1.5s`); C.9 `OnStaminaChanged` ≤5Hz push; C.9 `PlayerHeartbeat`/`SPRINT_CLIENT_TIMEOUT` ghost-sprint guard | All five requirements directly implemented in the Decision section |

## Performance Implications
- **CPU**: Negligible — a per-player arithmetic update and one liveness-timestamp comparison per Heartbeat tick, bounded by squad size (max 4).
- **Memory**: One small per-player state table (`locomotion`, `stamina`, `lastLeftSprintAt`, `lastHeartbeatAt`), already implicit in any GDD that assumed this state existed.
- **Load Time**: None.
- **Network**: `OnStaminaChanged` rate-limited to ≤5Hz per player, already accounted for in ADR-0008's bandwidth budget (listed there as one of PC's signals).

## Migration Plan
No migration — sprint/stamina is not implemented yet.

## Validation Criteria
- Unit test: a `RequestSprintToggle` at `stamina == 0` produces no state change.
- Unit test: stamina reaching exactly 0 while in S2 forces an immediate S2→S1 transition within the same tick (not the next tick).
- Unit test: a simulated stale `PlayerHeartbeat` (no ping for >3s) while in S2 forces an S2→S1 transition.
- Unit test: regen does not begin until `REGEN_DELAY` has elapsed since leaving S2, even if the player immediately stops moving.

## Related Decisions
- Depends on ADR-0003 (Locomotion Driver) and ADR-0006 (RemoteEvent Trust Boundary).
- `design/gdd/player-controller.md` F.2, F.2a, C.9.
- `design/ux/interaction-patterns.md` — Hold-vs-Toggle Action pattern (the input-shape layer above this ADR's server-side authority model).
