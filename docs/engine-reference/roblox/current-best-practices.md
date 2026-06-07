# Roblox — Current Best Practices

> **Last verified**: 2026-04-29
> **Scope**: Modern idiomatic patterns for new code in this project.
> Roblox is a live platform — this document is a living reference. Update as the team converges on patterns.

---

## Strict Typing

- Add `--!strict` to the top of every new ModuleScript, LocalScript, and Script
- Annotate function parameters and return types explicitly
- Use `type` aliases for shared shapes (e.g., `type DisturbanceEvent = { ... }`)
- Use `typeof()` for runtime type derivation in tests
- Type errors at edit time are blockers — fix them, do not silence with `:: any`

---

## Server Authority (always)

- Every gameplay-affecting action originates from a `RemoteEvent:FireServer()` call
- The server validates: identity, ownership, cooldown, range, resource availability, anti-cheat heuristics
- The server is the source of truth for all gameplay state
- Clients render and predict but never write

**Pattern:**
```luau
-- BAD: client decides
LocalScript: ResourceNode.Health -= 10  -- never replicates

-- GOOD: server decides
LocalScript: ResourceService:RequestGather(node)  -- via RemoteEvent
ServerScript: validate → mutate → fire OnGathered to clients
```

---

## Architecture: Knit Services + Controllers

- Server-side: `Services` (e.g., `ResourceService`, `PredatorService`, `DisturbanceService`)
- Client-side: `Controllers` (e.g., `HUDController`, `InputController`)
- Cross-boundary: `Service:Client` table exposes RemoteEvent-backed methods automatically
- Avoid direct `script.Parent` traversal — modules reference each other through Knit

**Reference**: https://sleitnick.github.io/Knit/

---

## DataStore: ProfileStore

- Never call `DataStoreService` directly for player data
- Use ProfileStore for per-player profiles: handles retry, session-locking, conflict resolution, `BindToClose` saves
- Schema migrations belong in the profile template version field

**Reference**: https://madstudioroblox.github.io/ProfileStore/

---

## File Layout (Rojo)

A typical Rojo-driven project structure:

```
src/
├── ServerScriptService/
│   ├── Services/                  # Knit Services (server-only)
│   │   ├── ResourceService.luau
│   │   ├── PredatorService.luau
│   │   └── DisturbanceService.luau
│   └── ServerInit.server.luau     # Knit.Start() entry
├── ReplicatedStorage/
│   ├── Modules/                   # Shared ModuleScripts
│   ├── Knit/                      # Knit framework
│   └── Types.luau                 # Shared type aliases
├── StarterPlayerScripts/
│   ├── Controllers/               # Knit Controllers (client-only)
│   │   ├── HUDController.luau
│   │   └── InputController.luau
│   └── ClientInit.client.luau     # Knit.Start() entry
└── tests/
    └── *.spec.luau                # TestEZ test files
```

`default.project.json` describes the mapping to Roblox Studio's tree.

---

## Networking Patterns

- **One RemoteEvent per logical concept**, not per script — group related actions
- **Validate before mutating, mutate before broadcasting**
- **Rate-limit incoming RemoteEvent calls server-side** — exploit-resistance
- **Never round-trip via RemoteFunction for fire-and-forget actions** — use RemoteEvent

---

## Performance

- Use `Heartbeat` for variable-rate per-frame logic; `RunService.Stepped` for physics-tied logic
- Avoid `Heartbeat:Wait()` in tight loops — prefer event-driven where possible
- Use `task.wait()` for time-based delays (cheaper than `Heartbeat:Wait()`)
- Profile with Studio's MicroProfiler before optimizing — most "slow" code is fine
- For mass entity simulation (predator + ecosystem creatures), batch updates per Heartbeat tick rather than per-entity threads

---

## UI

- Use `UIScale` + `UIAspectRatioConstraint` for cross-device layout
- Build UI on top of `ScreenGui` with `ResetOnSpawn = false` for persistent HUD
- Test on a 16:9 PC, 4:3 emulated, and a tall mobile aspect (e.g., 19.5:9)
- Always provide both touch-tap and gamepad-button affordances; no hover-only states

---

## Testing (TestEZ)

- Place tests next to the module under test: `ResourceService.luau` + `ResourceService.spec.luau`
- Run via TestService inside Studio for interactive runs
- Run via Lemur (or equivalent) for headless CI on every push
- Cover: pure formulas (deterministic), server-authority validation, exploit-resistance edge cases
- Don't unit-test rendering, animation, or audio — manual playtest evidence

**Reference**: https://github.com/Roblox/testez

---

## Anti-Cheat Posture

- Assume every client is hostile
- All gameplay state mutations server-side
- Sanitize every RemoteEvent argument (type check, range check, ownership check)
- Rate-limit per player per RemoteEvent
- Server-side line-of-sight / range checks for any ability that targets a position

---

## How to Add New Entries

When the team adopts a new pattern as standard:

1. Add a section here with: pattern name, when to use it, code/structure example, reference link
2. If the pattern deprecates an older approach, add a row to `deprecated-apis.md`
3. Update `Last verified` date at top of this file
