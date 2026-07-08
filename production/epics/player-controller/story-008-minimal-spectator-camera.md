# Story 008: Minimal Spectator Camera

> **Epic**: Player Controller
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/player-controller.md`
**Requirement**: `TR-pc-033` (spectator camera + `StreamingEnabled` chunk-load guard via `HasChunkLoaded()`; dead-player experience)

**ADR Governing Implementation**: ADR-0012: Player Controller Dead-Player Input Lock & Minimal Spectator State
**ADR Decision Summary**: While in S4, the dead player's camera subject is set to the `HumanoidRootPart` of the nearest currently-alive squad member, re-evaluated once at S4 entry and once every 5 seconds thereafter (not continuously). If no squadmate is alive, the camera holds the dead player's own last position. **`HasChunkLoaded()` is confirmed NOT a real Roblox API** — two concrete mitigations must be verified before implementation: (1, preferred) `Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent` on player character models; (2, fallback) `Player.ReplicationFocus` plus a bounded 1-second grace period.

**Engine**: Roblox Studio (live platform) | **Risk**: HIGH
**Engine Notes**: The input-lock/`renderScope` portions of ADR-0012 are LOW risk; this story's specific slice — the chunk-load guard — is the HIGH-risk piece. `HasChunkLoaded()` does not exist as a documented Roblox API. **Verification Required before implementation**: confirm whether `Model.ModelStreamingMode.Persistent` or `Player.ReplicationFocus` (both confirmed to exist) is the correct mitigation at the pinned Studio version, per `docs/engine-reference/roblox/VERSION.md`'s verification workflow — WebSearch/devforum-verify against the pinned version; exact enum members may drift on this live platform.

**Control Manifest Rules (Presentation layer, applied to a server-driven signal)**:
- Required: Server-pushed-only surfaces (the camera-target push here is analogous) register zero `OnServerEvent` callbacks.
- Required: All interactive prompts must work with touch tap, mouse click, and gamepad button — N/A here (spectator camera has no direct input surface in this story), but any future spectator re-target control must honor this.
- Guardrail: no per-frame polling of camera state — this story's 5-second re-evaluation interval, not a continuous follow, is the binding pattern (avoids visible camera snapping).

---

## Acceptance Criteria

- [ ] **ADR-0012 Validation Criteria (Integration test)** — a simulated whole-squad wipe results in the last-dying player's camera holding its own last position (no crash from an absent "nearest alive squadmate").
- [ ] **Camera-subject re-evaluation cadence** — the dead player's camera subject is re-evaluated exactly once at S4 entry and once every 5 seconds thereafter while still in S4 — never continuously, never on every Heartbeat.
- [ ] **Chunk-load guard mitigation confirmed** (Manual Studio verification, per ADR-0012's own Validation Criteria) — confirm whether a client-readable chunk-load-status API exists before implementing the guard; document the finding in this story's evidence.
- [ ] **Generation-counter guard against a stacked polling loop** — a second death in the same run for the same player does not stack a second concurrent camera-re-evaluation loop.

---

## Implementation Notes

- **Camera-subject resolution**: `_updateSpectatorCameraTarget(deadPlayer)` resolves to a **`Player` reference, NOT a `HumanoidRootPart` instance** — the client-side consumer re-resolves the live `HumanoidRootPart` at render time, avoiding a race if the target squadmate's character is destroyed/recreated between server-side resolution and client-side use (an engine-specialist review caught and fixed this in the ADR's own draft).
- **Re-evaluation loop, guarded by a generation counter**: on S4 entry, increment `self._spectatorLoopGeneration[player]` and capture it locally; the `task.spawn`'d re-evaluation loop checks both `renderScope[player] == "dead-respawning"` AND `self._spectatorLoopGeneration[player] == generation` before each `task.wait(5)` iteration and before acting — this prevents a second death in the same run from stacking a second concurrent polling loop for the same player (an engine-specialist review caught this gap in the ADR's own draft).
- **Chunk-load guard — do NOT implement against the GDD's own named `HasChunkLoaded()`** — it does not exist. Verify, in preference order: (1) `Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent` applied to player character models (eliminates the streaming pop-in risk entirely if confirmed available); (2) `Player.ReplicationFocus` set on the dead player to the target squadmate's position, force-prioritizing streaming, combined with a 1-second fallback grace period. If neither mitigation is confirmed available, fall back to holding the camera on the dead player's own last position for a fixed 1-second grace period after any subject switch.
- **Known implementation gotcha (engine-specialist review, 2026-07-06)**: the default Roblox `PlayerModule` camera script may silently re-lock `Camera.CameraSubject` back to the local `Humanoid` on its own `CharacterAdded`/`Heartbeat` logic — the client controller consuming the `OnSpectatorTargetChanged` push must explicitly override or disable that default behavior while `renderScope == "dead-respawning"`, or the spectator subject switch will be silently undone.
- Clean up `self._spectatorLoopGeneration[player] = nil` on `Players.PlayerRemoving`.
- Per the vertical-slice scope and this ADR's own explicit boundary: this is a **minimal** spectator behavior — no cinematic framing, no spectator FOV curves, no respawn fade. The full Camera system (spectator FOV, sprint FOV, respawn fade) is `architecture.md`'s can-defer ADR #14 and out of scope here; if/when that ADR is written it should treat this story's minimal behavior as its MVP baseline, not a placeholder to discard.

---

## Out of Scope

- Story 007: `renderScope` minting and input locks (this story only consumes `renderScope == "dead-respawning"` as its gating signal).
- Full Camera system (spectator FOV, sprint FOV, respawn fade, cinematic framing) — deferred to `architecture.md`'s can-defer ADR #14, not part of this epic's MVP scope.
- Re-anchoring smoothness when the "nearest alive squadmate" flips between two roughly-equidistant squadmates — flagged as a playtest polish item, not fixed preemptively (per the vertical-slice scope's explicit "no spectator camera polish" note).

---

## QA Test Cases

- **AC-1 (whole-squad-wipe camera safety)**:
  - Given: the last player alive dies (whole-squad wipe).
  - When: the spectator-camera-target resolution runs.
  - Then: no crash; camera holds the dead player's own last position (no "nearest alive squadmate" to resolve to).
  - Edge cases: this should coincide almost immediately with `RunEnded` firing (Story 009) — verify no dangling camera-update loop persists past S5 entry.
- **AC-2 (re-evaluation cadence)**:
  - Given: a player enters S4 with two squadmates alive.
  - When: 12 seconds elapse (simulated clock or `task.wait` mock).
  - Then: exactly 3 camera-target re-evaluations occur (S4-entry + 2 five-second intervals), never more.
  - Edge cases: a squadmate's alive-state changing between re-evaluation ticks is picked up only at the NEXT scheduled tick, not immediately.
- **AC-3 (generation-counter guard)**:
  - Given: a player dies, respawns, and dies again within one 5-second re-evaluation window.
  - When: the first death's polling loop's `task.wait(5)` resolves after the second death has already started a new loop.
  - Then: the first (stale-generation) loop's iteration is a no-op — only the current generation's loop acts.
  - Edge cases: confirm via a mock recording call counts per generation, not just absence of a crash.
- **Manual verification (chunk-load guard)**:
  - Setup: two players in a squad, one far enough apart that the dead player's target squadmate's chunk may not be loaded on the dead player's client.
  - Verify: no visible void-fall or pop-in beyond the documented 1-second grace window (if the fallback mitigation is what's confirmed available).
  - Pass condition: camera either freezes gracefully or the confirmed streaming-persistence mitigation prevents the issue entirely; document which mitigation was actually used in the evidence file.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/player-controller/spectator-camera_test.luau` (subject-resolution and generation-guard logic) + `production/qa/evidence/spectator-camera-chunk-load-verification.md` (the Manual Studio verification of which chunk-load mitigation is actually available)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 007
- Unlocks: None internal (this closes PC's MVP dead-player experience obligation; the full Camera system, if authored, builds on top of this — cross-epic, future)
