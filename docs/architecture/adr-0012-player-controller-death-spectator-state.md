# ADR-0012: Player Controller Dead-Player Input Lock & Minimal Spectator State

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) |
| **Domain** | Core (state machine, client-facing render contract) + Networking (input-lock enforcement) |
| **Knowledge Risk** | MEDIUM — the input-lock and `renderScope` contract are LOW risk (standard RemoteEvent server-authority patterns already governed by ADR-0006), but the spectator camera's chunk-load guard names a method (`HasChunkLoaded()`) in Player Controller's own GDD that does not correspond to a confirmed, documented Roblox API as of this project's engine reference library — flagged HIGH risk for that specific piece only. |
| **References Consulted** | `design/gdd/player-controller.md` (T5/S4/S5 states, C.9 dead-player guards, F.4's flagged "Dead-Player Input Lock & Spectator State" ADR), ADR-0005 (Death & Respawn Lifecycle — T5/T6, `RESPAWN_DELAY`), ADR-0002 (RunController — the `RunEnded` signal that drives S5), ADR-0006 (RemoteEvent Trust Boundary — the alive/state guard step this ADR's input locks implement), `docs/engine-reference/roblox/VERSION.md`, `breaking-changes.md`, `deprecated-apis.md` |
| **Post-Cutoff APIs Used** | None confirmed — see Verification Required. |
| **Verification Required** | **Engine-specialist review (2026-07-06) confirms `HasChunkLoaded()` does not exist** — Roblox streaming is distance/region-based via `Workspace.StreamingEnabled`, not chunk-based, so no client-readable "is region X loaded" boolean exists under that name. Two concrete, higher-confidence candidates to verify before implementation: (1) `Player.ReplicationFocus` (settable, confirmed to exist) — the server can set this on the dead player to *force-prioritize* streaming around the target squadmate's position rather than polling whether it's already loaded; (2) `Model.ModelStreamingMode` (e.g. `Enum.ModelStreamingMode.Persistent`) applied to player character models — would prevent characters from streaming out at all regardless of distance, eliminating the pop-in risk this ADR's fallback exists to bound, rather than merely working around it. WebSearch/devforum-verify both against the pinned Studio version per `VERSION.md`'s workflow; exact enum members may drift. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0005 (Death & Respawn Lifecycle — this ADR's S4 state is entered via the same T5 transition ADR-0005 already governs); ADR-0002 (RunController — S5 is entered via `RunEnded`); ADR-0006 (RemoteEvent Trust Boundary — the input-lock guards are this ADR's instance of ADR-0006's step-1 alive/state guard). |
| **Enables** | Player Controller epic — the third of PC's own three self-flagged, previously-unauthored ADRs. |
| **Blocks** | Full camera system polish (spectator FOV, sprint FOV, respawn fade) remains explicitly out of scope — see `architecture.md`'s can-defer ADR #14 (Camera system architecture). This ADR only covers the minimal spectating behavior needed for the vertical slice (`production/vertical-slice-scope.md` explicitly scopes out "spectator camera polish" for the slice). |
| **Ordering Note** | Independent of ADR-0011 — the two PC ADRs can be Accepted in either order. |

## Context

### Problem Statement

Player Controller's own GDD defines two post-alive states — S4 (Dead-Respawning,
entered at T5 death, exits at T6 respawn) and S5 (Post-Run, entered at `RunEnded`
regardless of alive/dead status) — but never formalized what input is locked in
each state, how the client is told which state it's in without trusting its own
tracking, or what the dead player actually sees in the interim. PC's own F.4
section flagged this as needing a dedicated ADR; it was never written. This ADR
closes it, scoped narrowly to what MVP needs — not a general-purpose camera system.

### Constraints

- Input locks must be server-authoritative — a client cannot simply choose not
  to enforce its own lock; every RemoteEvent PC exposes must independently reject
  calls from a player in S4 or S5, per ADR-0006's step-1 alive/state guard.
- The client must be told which state it's in via a server-minted value
  (`renderScope`), never inferred purely client-side, since the client's local
  state could desync from the server's (e.g., during a `Humanoid.Died` double-fire
  race, already guarded against server-side per ADR-0005).
- The full Camera system (spectator FOV curves, sprint FOV, respawn fade) is
  explicitly deferred (`architecture.md` can-defer ADR #14) — this ADR must not
  attempt to design that system, only the minimal "where does the camera point"
  behavior needed so a dead player isn't staring at nothing for 30 seconds.
- Per the vertical-slice scope, spectator camera polish is explicitly out of
  scope for the slice — this ADR's minimal behavior must be simple enough to not
  require the deferred Camera system to exist first.

## Decision

### S4 (Dead-Respawning) input locks

Entered via ADR-0005's T5 transition (`Humanoid.Died` → death handler → PC's own
T5 entry). While in S4:
- `RequestGather`, `RequestLanternToggle`, `RequestSprintToggle` are all rejected
  at ADR-0006's step-1 alive/state guard (before rate limit or any other check) —
  the same pattern PC's own C.9 already establishes for these events, now formalized
  as binding for the S4 state specifically.
- `RequestPing` is rejected in S4 (and S5) — a dead or post-run player cannot ping.
- Movement is locked by setting `Humanoid.WalkSpeed = 0` (not by destroying the
  character or removing the Humanoid — the character remains a valid Instance so
  the camera has something to reference; see Spectator Camera below) and
  `Humanoid.JumpPower = 0`.
- The player's `renderScope` (see below) is set to `"dead-respawning"`.

### S5 (Post-Run) input locks

Entered via `RunEnded` (ADR-0002), regardless of the player's S1-S4 status at
that moment. While in S5:
- Every client-fired RemoteEvent this project defines is rejected at the same
  step-1 guard — S5 is a strictly stricter superset of S4's locks (nothing is
  permitted in S5 that isn't also blocked in S4).
- `renderScope` is set to `"post-run"`, driving the client to show the
  victory/defeat banner (HUD's own `RunEnded` subscription, ADR-0002) instead of
  any gameplay HUD.

### `renderScope`: a server-minted, non-inferred client render-state signal

**Decision**: `renderScope` is a `"alive" | "dead-respawning" | "post-run"` enum,
pushed to the owning client only, exactly once per state transition (not
polled), server-minted inside the same handler that performs the S1/S4/S5
transition — never left for the client to infer from its own local Humanoid
state, health, or any other client-observable signal. This directly closes the
"renderScope server-minted" requirement from PC's own C.9, generalizing it as
this ADR's binding contract for all three states.

### Minimal Spectator Camera (MVP scope only)

**Decision**: while in S4, the dead player's camera subject is set to the
`HumanoidRootPart` of the **nearest currently-alive squad member** (server-computed,
using the same server-tracked position reads PC already performs for other
systems), re-evaluated once at S4 entry and once every 5 seconds thereafter (not
continuously — a dead player watching a squadmate does not need frame-perfect
subject-following, and re-evaluating too often risks visible camera snapping if
the nearest alive squadmate changes). If no squadmate is alive (whole-squad
wipe, which should coincide with `RunEnded` firing almost immediately per
ADR-0002), the camera holds on the dead player's own last position instead of
attempting a subject switch.

**Chunk-load guard (Verification Required before implementation)**: before
switching camera subject to a squadmate who may be far from the dead player's
own last-loaded area, the risk is a visible pop-in or a camera pointed at
unloaded geometry. **PC's own GDD names a method `HasChunkLoaded()` for this
check — engine-specialist review confirms this does not exist as a real Roblox
API** (Roblox streaming is distance-based, not chunk-based). Two real
mitigations to verify before implementation, in preference order:
1. **Preferred**: apply `Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent`
   to player character models. If this holds at the pinned engine version, it
   eliminates the streaming pop-in risk entirely (character models never stream
   out regardless of distance), and the 1-second fallback grace period below
   becomes unnecessary.
2. **If Persistent mode is unavailable or too costly at scale**: set
   `Player.ReplicationFocus` on the dead player to the target squadmate's
   position at the moment of the camera-subject switch, to force-prioritize
   streaming around that position, combined with the 1-second grace period
   fallback below as a bounded worst case.

**Fallback (if neither mitigation above is confirmed available)**: hold the
camera on the dead player's own last position for a fixed 1-second grace period
after any subject switch, rather than switching instantly — this bounds the
worst-case pop-in window without depending on an unverified API.

### Architecture Diagram

```
Humanoid.Died (ED's sole subscription, ADR-0004)
        │
        ▼ (ADR-0005's fan-out reaches PC)
PC's T5 entry:
    renderScope = "dead-respawning"
    Humanoid.WalkSpeed = 0, JumpPower = 0
    camera subject -> nearest alive squadmate's HumanoidRootPart
      (re-evaluated every 5s; holds own position if no squadmate alive)
    input locks: Gather/Lantern/Sprint/Ping all rejected (ADR-0006 step 1)
        │
        ▼ (T6 respawn, ADR-0005)
    renderScope = "alive"
    Humanoid.WalkSpeed restored, JumpPower restored
    camera returns to the player's own character
    input locks lifted

RunEnded fires (ADR-0002) at any point, regardless of S1-S4:
        │
        ▼
    renderScope = "post-run"
    ALL client-fired RemoteEvents rejected (superset of S4's locks)
    HUD shows victory/defeat banner (ADR-0002's own HUD subscription)
```

### Key Interfaces

```luau
--!strict
type RenderScope = "alive" | "dead-respawning" | "post-run"

-- Server-minted, pushed once per transition — never inferred client-side.
function PlayerControllerService:_setRenderScope(player: Player, scope: RenderScope): ()
    self._renderScope[player] = scope
    self._onRenderScopeChanged:Fire(player, scope)  -- per-client targeted push
end

-- ADR-0006 step-1 alive/state guard, reused verbatim by every PC RemoteEvent handler.
function PlayerControllerService:_isEligibleForGameplayEvents(player: Player): boolean
    local scope = self._renderScope[player]
    return scope == "alive"
end

-- S4 entry (called from PC's T5 handler, which ADR-0005 already governs).
function PlayerControllerService:_enterDeadRespawningState(player: Player): ()
    self:_setRenderScope(player, "dead-respawning")
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid then
        humanoid.WalkSpeed = 0
        humanoid.JumpPower = 0
    end
    self:_updateSpectatorCameraTarget(player)  -- initial evaluation
    -- Re-evaluate every 5s while still in S4. Guarded by a generation counter
    -- (engine-specialist review 2026-07-06) so a second death in the same run
    -- cannot stack a second concurrent polling loop for the same player.
    local generation = (self._spectatorLoopGeneration[player] or 0) + 1
    self._spectatorLoopGeneration[player] = generation
    task.spawn(function()
        while self._renderScope[player] == "dead-respawning"
            and self._spectatorLoopGeneration[player] == generation do
            task.wait(5)
            if self._renderScope[player] == "dead-respawning"
                and self._spectatorLoopGeneration[player] == generation then
                self:_updateSpectatorCameraTarget(player)
            end
        end
    end)
end

function PlayerControllerService:_updateSpectatorCameraTarget(deadPlayer: Player): ()
    -- Resolve to a Player, not a HumanoidRootPart, and let the client-side
    -- consumer re-resolve the live HumanoidRootPart at render time (engine-
    -- specialist review 2026-07-06) — avoids a race if the target squadmate's
    -- character is destroyed/recreated between resolution here and use on
    -- the client.
    local nearest = self:_findNearestAliveSquadMember(deadPlayer)
    if nearest then
        -- Client-side camera controller applies this via the per-client
        -- OnSpectatorTargetChanged push; the chunk-load/streaming mitigation
        -- (Verification Required above) and the 1s fallback grace period are
        -- implemented client-side. NOTE: the default Roblox PlayerModule
        -- camera script may re-lock Camera.CameraSubject to the local
        -- Humanoid on its own CharacterAdded/Heartbeat logic — the client
        -- controller consuming this push must explicitly override or disable
        -- that default behavior while renderScope == "dead-respawning", or
        -- the spectator subject switch will be silently undone.
        self._onSpectatorTargetChanged:Fire(deadPlayer, nearest)
    end
    -- If no squadmate alive: fire nothing — client holds its last camera position.
end

-- Cleanup: stop any in-flight spectator polling loop and clear generation
-- tracking on respawn or disconnect.
Players.PlayerRemoving:Connect(function(player: Player)
    PlayerControllerService._spectatorLoopGeneration[player] = nil
end)

-- S5 entry (called from the RunController RunEnded subscription, ADR-0002).
function PlayerControllerService:_enterPostRunState(player: Player): ()
    self:_setRenderScope(player, "post-run")
    -- All RemoteEvent handlers already check _isEligibleForGameplayEvents,
    -- which returns false for both "dead-respawning" and "post-run" — no
    -- separate S5-specific rejection logic is needed.
end
```

## Alternatives Considered

### Alternative 1: Destroy the character on death, recreate at respawn
- **Description**: Instead of setting `WalkSpeed = 0`/`JumpPower = 0` on the existing character, destroy the character Instance entirely on death and only recreate it at respawn.
- **Pros**: Guarantees no stray input can affect a "dead" character at all, since it doesn't exist.
- **Cons**: The spectator camera needs a `HumanoidRootPart`-equivalent to reference for a smooth transition; destroying the character removes that reference and would require an alternate camera-anchor mechanism (a server-tracked position-only spectator point) that adds complexity for no correctness benefit, since server-side input rejection already fully prevents any gameplay effect from a "dead" character regardless of whether it still exists.
- **Rejection Reason**: Adds implementation complexity (a second camera-anchor mechanism) without closing any gap the input-lock approach doesn't already close.

### Alternative 2: Client infers `renderScope` from its own Humanoid.Health/died state
- **Description**: Skip the explicit server-pushed `renderScope` signal; have the client derive its own render state from `Humanoid.Health <= 0` or a similar locally-observable signal.
- **Pros**: One fewer signal to push.
- **Cons**: PC's own GDD already names `renderScope` as server-minted specifically to avoid this — a client-inferred state is exactly the kind of thing a `Humanoid.Died` double-fire race (already guarded against server-side, ADR-0005) or a replication-timing quirk could desync. This project's whole architecture leans on "server decides, client renders" as a load-bearing principle (`current-best-practices.md`'s Server Authority section) — inferring render state client-side from a proxy signal (health) rather than being told explicitly is the exact anti-pattern that principle exists to avoid.
- **Rejection Reason**: Contradicts the project's own server-authority principle and PC's own GDD, which already named this as server-minted.

## Consequences

### Positive
- Closes the third and final of PC's self-flagged, previously-unauthored ADRs.
- The 5-second camera re-evaluation interval (rather than continuous following) avoids a visible snapping/jittering spectator camera, a concrete UX improvement over an unspecified "just follow someone" behavior.
- The `HasChunkLoaded()` uncertainty is handled the same way this project's other ADRs have handled uncertain post-cutoff APIs — named explicitly, with a safe fallback, rather than guessed at with false confidence.

### Negative
- The 1-second fallback grace period (if no chunk-load-check API exists) is a rougher user experience than a confirmed instant, pop-in-free switch would be — accepted as a bounded, known trade-off pending the API verification.
- The minimal spectator camera (nearest-alive-squadmate only, no cinematic framing) is explicitly not a polished experience — deferred to the full Camera system ADR (#14, can-defer) if/when that's authored.

### Risks
- **Engine-specialist review (2026-07-06) findings, all folded in**: (1) `HasChunkLoaded()` confirmed not to exist — replaced with two concrete candidates (`Model.ModelStreamingMode.Persistent`, `Player.ReplicationFocus`) in the Decision section above. (2) The `task.spawn` re-evaluation loop had no guard against a second death in the same run stacking a second concurrent polling loop for the same player — fixed with a generation counter. (3) `_updateSpectatorCameraTarget` now resolves to a `Player` reference (not a `HumanoidRootPart` instance) to avoid a race if the target squadmate's character is destroyed/recreated between server-side resolution and client-side use. (4) Flagged a real implementation gotcha: the default Roblox `PlayerModule` camera script may silently re-lock `Camera.CameraSubject` back to the local Humanoid on its own logic, undoing this ADR's spectator subject push unless the client controller explicitly overrides it — noted inline in the Decision section.
- **`FindFirstChildOfClass("Humanoid")` spawn-timing race** — same class of risk ADR-0003 already flags; `_enterDeadRespawningState` should use `:WaitForChild` patterns consistent with that ADR's guidance if the character is mid-respawn when this fires.
- **Re-anchoring the spectator camera every 5s could still feel jarring if the "nearest alive squadmate" flips between two squadmates who are both roughly equidistant** — a minor polish risk, not a correctness issue; flagged as a playtest item, not fixed preemptively here (per the vertical-slice scope's explicit "no spectator camera polish" note).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| player-controller.md | S4/S5 dead-player input locks (`RequestPing` rejected, movement/gather locked); `renderScope` server-minted; spectator camera + StreamingEnabled chunk-load guard (`HasChunkLoaded()`) | All three requirements addressed; the chunk-load guard is explicitly flagged Verification Required rather than assumed |

## Performance Implications
- **CPU**: Negligible — the 5-second re-evaluation interval is a `task.wait`-driven per-dead-player loop, not a per-frame cost.
- **Memory**: One small per-player render-scope + camera-target state, bounded by squad size.
- **Load Time**: None.
- **Network**: `OnRenderScopeChanged` and `OnSpectatorTargetChanged` are both low-frequency, per-transition pushes (not continuous), negligible against the bandwidth budget (ADR-0008).

## Migration Plan
No migration — S4/S5 input locks and the spectator camera are not implemented yet.

## Validation Criteria
- Unit test: a `RequestGather`/`RequestLanternToggle`/`RequestSprintToggle`/`RequestPing` call from a player in S4 or S5 is rejected with no state mutation.
- Unit test: `renderScope` transitions exactly once per state change, never polled or re-sent redundantly.
- Integration test: a simulated whole-squad wipe results in the last-dying player's camera holding its own last position (no crash from an absent "nearest alive squadmate").
- Manual Studio verification (per Verification Required): confirm whether a client-readable chunk-load-status API exists before implementing the camera's chunk-load guard; document the finding in this ADR's Validation Criteria section once resolved.

## Related Decisions
- Depends on ADR-0005 (Death & Respawn Lifecycle) and ADR-0002 (RunController Architecture).
- Explicitly scoped narrower than `architecture.md`'s can-defer ADR #14 (Camera system architecture) — that ADR, if written, should treat this one's minimal spectator behavior as its MVP baseline, not a placeholder to discard.
- `design/gdd/player-controller.md` S4/S5, C.9.
- `production/vertical-slice-scope.md` — explicitly defers spectator camera polish for the slice.
