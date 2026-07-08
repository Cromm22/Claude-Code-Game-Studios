# Control Manifest

> **Engine**: Roblox Studio (live platform — auto-updating) + Luau
> **Last Updated**: 2026-07-06
> **Manifest Version**: 2026-07-06
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004, ADR-0005, ADR-0006, ADR-0007, ADR-0008
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules. Always matches
`Last Updated` — they are the same date, serving different consumers.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: scene management, event architecture, save/load, engine initialisation*

### Required Patterns
- **"`KnitInit` builds, `KnitStart` connects"** — any object, signal, or accessor another service might need to synchronously read or call during its own `KnitStart` MUST be fully constructed inside the owning service's `KnitInit` — source: ADR-0001
- **RegistrationHandshake pattern** — where a live cross-service subscription requires one side to register itself (not just listen) and neither side can assume boot order, use the module-private `require()`-acquired RegistrationHandshake pattern — source: ADR-0001
- **Prefer Knit's bundled `Signal` class (RbxUtil)** over raw `Instance.new("BindableEvent")` for cross-service signals — `Signal:Fire()` synchronicity is independent of `Workspace.SignalBehavior` — source: ADR-0001
- **RegistrationHandshake modules must only be `require()`d from the default serial Luau script context** — never from inside an `Actor` used for parallel execution, or the module-cache singleton assumption silently breaks — source: ADR-0001
- **RunController exposes exactly one server-internal method**, `RunEndConditionRaised(conditionType: "wipe"|"victory", squadState)`, callable by any server-side Knit service; RunController never calls back into the caller to independently verify state — source: ADR-0002
- **RunController fires `RunEnded` exactly once per run** via a one-shot idempotency latch (`_hasEnded` flag); subsequent calls in the same run are silent no-ops logged at `warn` level — source: ADR-0002
- **`RunEnded` payload `timestamp` uses `os.time()`** (wall-clock Unix epoch seconds), never `workspace:GetServerTimeNow()` (seconds-since-server-start, meaningless to a cross-session analytics pipeline) — source: ADR-0002
- **Mount Instances (HUD gather-ring, emote-wheel, etc.) must be constructed during `KnitInit`, never `KnitStart`** — an instance of the general Rule 1 above — source: ADR-0001
- **Cosmetic persistence must use ProfileStore** (or an equivalent retry/backoff/session-lock wrapper), never raw `DataStoreService` — source: ADR-0007, technical-preferences.md
- **`MarketplaceService.ProcessReceipt` is assigned exactly once, in one module**, its body wrapped in `pcall`, with uncaught errors logged to `production/qa/evidence/purchase-failures.md` — source: ADR-0007
- **`ProcessReceipt` idempotency**: dedupe by `receiptInfo.PurchaseId` in a `ProcessedReceipts` ledger; return `Enum.ProductPurchaseDecision.NotProcessedYet` (not an error) when the player is absent or their profile isn't loaded, letting Roblox's own retry contract recover — source: ADR-0007
- **"No charge without grant"**: the cosmetic grant + idempotency-key write must be durably persisted BEFORE returning `PurchaseGranted` — source: ADR-0007
- **Any `KnitInit`-time config-validation hard error (`error()`) MUST be paired with a server bootstrap `catch` handler that calls `game:Shutdown()`** (or an equivalent hard-stop) — a `catch(warn)`-only boilerplate logs but does not halt startup, silently defeating the hard-error's purpose. Binding project-wide, not just for the ADR that names it — source: ADR-0005

### Forbidden Approaches
- **Never construct a cross-service-visible object (signal, accessor) inside `KnitStart`** — source: ADR-0001
- **Never call another service's public Knit API from your own `KnitStart` and assume that service's `KnitStart`-time setup has already completed** — source: ADR-0001
- **Never fork or wrap Knit's own `Start()` with a custom centralized bootstrap phase** to sequence handshakes — rejected in favor of the module-private `require()` pattern, which needs no Knit modification — source: ADR-0001
- **Never let RunController poll Crafting/Resource-Node/Player-Controller state synchronously each tick** — violates the event-subscriber-only mandate and creates an upward Foundation→Core/Feature dependency — source: ADR-0002
- **Never split run-ending ownership** (e.g. RunController owns defeat, Player Controller broadcasts victory directly) — exactly the defect a prior migration attempt introduced and had reverted (`3747c3c`) — source: ADR-0002
- **Never expose `RunEndConditionRaised` under a Knit service's `.Client` table** — it must remain a plain, server-internal method; placing it under `.Client` would let any connected client end the run for the whole squad — source: ADR-0002
- **Never add a second, ad-hoc DataStore/ProfileStore access point outside the cosmetic-persistence module** — this is the sole persistence surface in the entire game (Architecture Principle #5, "Rounds, not saves") — source: ADR-0007
- **Never grant a cosmetic and defer the durable save to periodic autosave (fire-and-forget)** — a crash before the next autosave loses the grant after the Robux charge — source: ADR-0007
- **Never create a dedicated separate raw-DataStore purchase ledger outside ProfileStore** — reintroduces the forbidden raw `DataStoreService` pattern and a second persistence surface — source: ADR-0007

### Performance Guardrails
- **Knit lifecycle overhead**: negligible, one-time cost at server boot, not per-frame — source: ADR-0001
- **RunController**: one `Signal` instance + one boolean per server instance for the run's lifetime, discarded at run end — source: ADR-0002
- **Cosmetic persistence**: one profile per connected player, released on `PlayerRemoving`/`BindToClose` — source: ADR-0007

---

## Core Layer Rules

*Applies to: core gameplay loop, main player systems, physics, collision*

### Required Patterns
- **Locomotion driver for both Player Controller and Predator AI is `Humanoid`-driven movement** (`Humanoid.WalkSpeed`, `MoveDirection`/`Humanoid:Move()`) — a single shared primitive so the `WALK_SPEED < HUNT_APPROACH_SPEED < SPRINT_SPEED` invariant stays meaningful — source: ADR-0003
- **Use `:WaitForChild("Humanoid")` at character-setup time**, not `FindFirstChildOfClass("Humanoid")` immediately after `CharacterAdded`, to avoid a nil-dereference spawn-timing race — source: ADR-0003
- **Wrap `Path:ComputeAsync()` in `pcall`** and `task.spawn` a frequently-repathing agent's compute call so a slow path calc doesn't stall the server `Heartbeat` — source: ADR-0003
- **DisturbanceService's spatial index is a plain Luau table-of-tables hash grid**, keyed by integer cell coordinates, cell size `SPATIAL_GRID_CELL_SIZE = 32` studs; a source's cell is computed once at emission and only recomputed if its position is later mutated — source: ADR-0004
- **Cap-eviction at `MAX_LIVE_SOURCES = 500`**: evict the single oldest live source (by `emissionTime`, ascending) to make room for a new emission — never refuse the new emission — source: ADR-0004
- **StreamingEnabled chunk-membership (`loadedChunks[player]`) is computed entirely server-side from the player's own server-tracked position** — never from any client-fired signal or client-writable property — source: ADR-0004
- **Chunk-stream-in is one atomic, yield-free sequence per player per chunk**: membership add → snapshot compute → `Fire` → per-flora cache reset — source: ADR-0004
- **`FloraChunkUpdate`/`FloraChunkInitialSnapshot` are raw `RemoteEvent`s with zero `OnServerEvent` registrations** on the server (server-fire-only; enforceable via a grep for zero matches) — source: ADR-0004
- **`GetDeathAttributionPayload` is constructed eagerly and synchronously inside the same `Humanoid.Died` handler** that builds the rest of the death snapshot, cached by `deathEventId` — source: ADR-0004
- **At the start of each field-update pass, snapshot the predator-lock registry once (pass-scoped)** before processing any `Humanoid.Died` callbacks in that pass, so simultaneous same-pass deaths see consistent lock state — source: ADR-0004
- **`hotspot.id` tie-break comparisons use Luau's native string `<` operator** (byte-lexicographic), not a numeric parse of the encoded coordinates — source: ADR-0004
- **Clean up any per-player table (`loadedChunks`, dedup sets, rate-limit counters) on `Players.PlayerRemoving`** — source: ADR-0004, ADR-0006
- **Player Controller mints `deathEventId` from a monotonic per-server-session counter** (`nextDeathEventId()`); it is the sole minter — Resource Management and any other consumer treat it as an opaque key — source: ADR-0005
- **`RequestSquadOxygenSpend(deadPlayerUserId, amount, reason, deathEventId)` is deduplicated by Resource Management against the compound key `(deadPlayerUserId, deathEventId)`**; a duplicate call is a silent no-op — source: ADR-0005
- **The async oxygen-spend charge follows the Pending → InFlight → Committed/Abandoned state machine.** On the success path, the caller MUST re-check `row.state == "InFlight"` AFTER the yield resolves before treating the call as committed — a late success on a row re-armed by the staleness sweep is discarded (logged, not committed, not rolled back) — source: ADR-0005
- **If `RequestSquadOxygenSpend` is ever made genuinely async via a Promise, the caller must `:await()`/`:expect()` it inside the `pcall`** — never bare-call-and-check `ok`, which would report success the instant the Promise is constructed, not once it resolves — source: ADR-0005
- **`Humanoid.Died` handling must guard against re-entry** (`_deathInProgress` flag) — a pathological double-fire must not reset the 30 s respawn timer or mint a second `deathEventId` — source: ADR-0005
- **`OXYGEN_GRACE_DURATION = 5 s` (safe range 4–8 s), owned by Player Controller, squad-wide**; config-validation must hard-error (and halt startup via the `game:Shutdown()` pattern above) for any configured value below the 2.0 s floor — source: ADR-0005
- **D1 kill-criterion**: `aliveCount ≤ 2` is the pre-committed last-stand floor after Beacon-Collapse-4; the analytics pipeline must segment 2-player-squad win/loss outcomes from 3/4-player squads so the criterion is measurable from real data — source: ADR-0005
- **Every client-fired `RemoteEvent` handler evaluates this exact 6-step order**: (1) alive/state guard, (2) per-event rate limit + burst cap, (3) per-player global RemoteEvent budget, (4) payload shape validation, (5) server-side plausibility re-derivation (never trust a client-supplied id/position/distance claim — re-derive from server-tracked state), (6) deep/domain validation owned by the receiving service — source: ADR-0006
- **A dropped event (steps 1–4) must not mutate any state**, including cooldown/grace-timer anchors — a flood of rejected events must not be usable to perturb a legitimate cooldown window — source: ADR-0006
- **Enforce a per-player global RemoteEvent budget of 30 accepted fires/sec** (tumbling 1.0 s window), checked after the per-event rate limit, incremented only on events that pass steps 1–2 — source: ADR-0006
- **Any future `RemoteFunction` (none exist today) must always return a value on every path, including rejection** — never reuse the silent-drop convention, or the calling client's coroutine yields indefinitely — source: ADR-0006
- **Server-pushed-only surfaces (respawn, squad join/leave, AFK kick, death confirmation, flora chunk subscription) register zero `OnServerEvent` callbacks** on their `RemoteEvent` — source: ADR-0006
- **Player characters use Roblox's default automatic `NetworkOwnership`** (client-owned physics simulation for local responsiveness) — gameplay-consequential state stays server-validated via RemoteEvents, never inferred from client-owned physics — source: ADR-0008
- **Every system's bandwidth budget must be evaluated against `50 KB/s minus the measured character-replication baseline`**, not the full 50 KB/s ceiling — source: ADR-0008

### Forbidden Approaches
- **Never let Predator AI and Player Controller use different locomotion primitives** — breaks the `WALK_SPEED < HUNT_APPROACH_SPEED < SPRINT_SPEED` invariant's numeric comparability — source: ADR-0003
- **Never use `Region3`/`Workspace:FindPartsInRegion3` for DisturbanceService's spatial queries** — sources are pure data (position + magnitude + age), not physical Instances; this would add real per-emission Instance overhead for a problem a plain table already solves in O(1) — source: ADR-0004
- **Never read or watch `Player.ReplicationFocus` for chunk-membership/streaming decisions** — client-writable, not a trustworthy signal, an exploit-class regression — source: ADR-0004
- **Never wrap `FloraChunkUpdate`/`FloraChunkInitialSnapshot` in a Knit `RemoteSignal`** — they must remain raw, bandwidth-efficient `RemoteEvent`s — source: ADR-0004
- **Never fire-and-forget the oxygen-spend charge without Pending/InFlight/Committed/Abandoned tracking** — cannot safely handle a `BindToClose` mid-call or a staleness-sweep race — source: ADR-0005
- **Never let Resource Management (or anything but Player Controller) mint `deathEventId`** — source: ADR-0005
- **Never respond to a rejected/rate-limited RemoteEvent with an explicit error response to the client** — gives an attacker a clean oracle to tune against; silent-drop only — source: ADR-0006
- **Never rely on per-event rate limits alone without the per-player global budget** — a client can alternate low-rate events to bypass per-event caps — source: ADR-0006
- **Never force server-owned `NetworkOwnership` on player characters** — removes local movement responsiveness for zero server-authority benefit, since gameplay-critical state is already RemoteEvent-validated — source: ADR-0008
- **Never anchor the predator's `HumanoidRootPart`** while it has `SetNetworkOwner(nil)` set — `SetNetworkOwner` throws on an `Anchored` part; use `WalkSpeed = 0` for a freeze/stagger state instead — source: ADR-0008

### Performance Guardrails
- **`GetHottestHotspot`/`fieldValue()`**: touch only ~4–9 grid cells per query — source: ADR-0004
- **`OnDisturbanceAlert`**: rate-limited to 5 fires/sec per player; simultaneous same-pass tier-crossings coalesce into one payload rather than firing multiple times — source: ADR-0004
- **Global RemoteEvent budget**: 30 accepted fires/sec per player (tumbling 1.0 s window) — source: ADR-0006
- **Character replication baseline**: provisional 15–30 KB/s per client before any game-code signals — MUST be empirically re-measured during the `/prototype predator-ai` spike; every other system's bandwidth budget must be re-derived from `(50 KB/s − measured baseline)` once the real figure is known, not assumed safe against the provisional range — source: ADR-0008
- **< 50 KB/s per-client advisory ceiling**, inclusive of the character-replication baseline above — source: technical-preferences.md, ADR-0008

---

## Feature Layer Rules

*Applies to: secondary mechanics, AI systems, secondary features*

### Required Patterns
- **Predator AI locomotion uses the same `Humanoid`-driven primitive as Player Controller** (shared driver decision, not a per-system choice) — source: ADR-0003
- **Predator AI consumes DisturbanceService's `GetHottestHotspot` / `GetSquadAggregateT(excludePlayer)` / `GetOnPlayerDiedSignal()` via the frozen, ADR-specified contracts** — do not re-derive or rename them — source: ADR-0004
- **Predator AI's lock release goes through the RegistrationHandshake module (`ReleasePredatorLock`)**, which only Predator AI calls — source: ADR-0004
- **Crafting & Items reports BCT-DEFEAT to RunController via `RunEndConditionRaised("victory"|"wipe", squadState)`** — the exact same single contract Player Controller uses, no bespoke path — source: ADR-0002
- **Crafting's `RequestCraft`/`RequestBeaconActivate` RemoteEvents follow the same 6-step canonical validation order** as every other client-fired event — source: ADR-0006
- **Resource Node's `RequestGather` receive-side owns its own deep/domain validation (step 6)** after the shared steps 1–5 — source: ADR-0006
- **The predator NPC uses explicit server `NetworkOwnership`** (`SetNetworkOwner(nil)` on its `HumanoidRootPart`); this call MUST be re-invoked on every predator respawn/recreate, not just initial spawn, since ownership is set per part instance, not persisted on a template — source: ADR-0008

### Forbidden Approaches
- **Never let Predator AI assume a specific `KnitStart` ordering relative to DisturbanceService** — use the RegistrationHandshake / `KnitInit`-constructed accessors instead — source: ADR-0001, ADR-0004
- **Never let Crafting & Items broadcast a run-ending condition directly, bypassing RunController** — this is the exact defect a prior migration attempt introduced and had reverted (`3747c3c`) — source: ADR-0002
- **Never give the predator NPC client-owned `NetworkOwnership`** — it has no controlling client, and Predator AI's always-broadcast design (H.30) assumes server-authoritative predator state as the single source of truth — source: ADR-0008

### Performance Guardrails
- **Predator AI state-change broadcasts**: ≤250 ms cycle (H.30), budgeted from the remaining per-client bandwidth after the character-replication baseline — source: ADR-0008

---

## Presentation Layer Rules

*Applies to: rendering, audio, UI, VFX, shaders, animations*

### Required Patterns
- **HUD mount Instances (gather-ring, emote-wheel, etc.) must be constructed during the owning controller/service's `KnitInit`, never `KnitStart`** — source: ADR-0001
- **HUD's end-screen (and any other `RunEnded` subscriber) connects to `RunController:GetRunEndedSignal()` during its own `KnitStart`** — safe because the `Signal` is guaranteed constructed at `KnitInit` — source: ADR-0002
- **All UI scales via `UIScale` and `UIAspectRatioConstraint`**, using scale-based `UDim2` — source: technical-preferences.md, current-best-practices.md
- **All interactive prompts must work with touch tap, mouse click, and gamepad button** — no hover-only interactions — source: technical-preferences.md

### Forbidden Approaches
- **Never use hardcoded pixel sizes** — use `UIScale`/`UIAspectRatioConstraint`/scale-based `UDim2` — fails on mobile / different aspect ratios — source: deprecated-apis.md
- **Never use hover-only affordances** — mobile and gamepad have no hover — source: deprecated-apis.md
- **Never poll `Mouse:GetPosition()` per-frame** — use `UserInputService.InputChanged` events instead — source: deprecated-apis.md

### Performance Guardrails
- No Presentation-layer-specific guardrails beyond the Global performance budgets below.

---

## Global Rules (All Layers)

### Naming Conventions
| Element | Convention | Example |
|---------|-----------|---------|
| Modules / Services / Controllers | PascalCase | `PlayerService`, `EcologicalDisturbanceController` |
| Public Methods / Properties | PascalCase | `TakeDamage()`, `MoveSpeed` |
| Local Variables | camelCase | `currentHealth`, `disturbanceLevel` |
| Private Members (table fields) | `_camelCase` | `_internalState` |
| Constants | UPPER_SNAKE_CASE | `MAX_OXYGEN`, `DEFAULT_MOVE_SPEED` |
| Files | PascalCase matching module name | `PlayerController.luau` |
| Knit Services | `<Domain>Service` | `ResourceService`, `PredatorService` |
| Knit Controllers | `<Domain>Controller` | `HUDController` |
| RemoteEvents / RemoteFunctions | PascalCase verb-form | `RequestGather`, `OnDisturbanceChanged` |

### Performance Budgets
| Target | Value |
|--------|-------|
| Framerate | 60fps mid-range PC; 30fps mobile baseline (lowest-tier device) |
| Server tick rate | 60Hz (Roblox default Heartbeat) |
| Network bandwidth | < 50 KB/s per client (advisory ceiling) |
| Memory ceiling | < 1GB total client memory on lowest-tier mobile |
| Asset budget | < 200MB total place asset weight |

### Approved Libraries / Addons
- **Knit** — architecture framework (Service/Controller pattern, built-in networking) — confirmed at engine setup
- **Rojo** — file-based sync between this repo and Roblox Studio — confirmed at engine setup
- **ProfileStore** — DataStore wrapper for the sole persistence surface (cosmetic profiles) — source: ADR-0007, technical-preferences.md

### Forbidden APIs (Roblox Studio, live platform)
These APIs are deprecated or anti-patterns for this project — source: `docs/engine-reference/roblox/deprecated-apis.md`:

**Coroutine / Scheduling**
- `wait(t)` → use `task.wait(t)`
- `spawn(f)` → use `task.spawn(f)`
- `delay(t, f)` → use `task.delay(t, f)`
- `coroutine.wrap` for game logic → use `task.spawn`

**DataStore Patterns**
- Raw `:GetAsync()`/`:SetAsync()` → use ProfileStore
- `:UpdateAsync` without `pcall` → always wrap in `pcall`
- Saving on every property change → periodic save + `BindToClose` final save

**Networking**
- Trusting client-supplied numbers → server validation + clamping
- `RemoteFunction` for fire-and-forget → use `RemoteEvent`
- `BindableEvent` across client/server → use `RemoteEvent`/`RemoteFunction` (BindableEvents don't cross the network boundary)

**Scripting / Architecture**
- `_G` for cross-script state → ModuleScripts + Knit Services
- Polling `Workspace:WaitForChild` in tight loops → signal-driven (`:GetPropertyChangedSignal`, attribute-changed events)
- `script.Parent` chaining (3+ levels) → top-level module reference

**UI**
- Hardcoded pixel sizes → `UIScale`, `UIAspectRatioConstraint`, scale-based `UDim2`
- Hover-only affordances → tap/click + visible state
- Per-frame `Mouse:GetPosition()` → `UserInputService.InputChanged` events

**Type System**
- Implicit `any` types in new scripts → explicit type annotations
- `--!nonstrict` (default) for new scripts → `--!strict`

### Cross-Cutting Constraints
- **Server authority, always** — every gameplay-affecting action originates from a `RemoteEvent:FireServer()` call; the server validates identity, ownership, cooldown, range, resource availability, and anti-cheat heuristics before mutating state — source: technical-preferences.md, current-best-practices.md
- **`--!strict` is required on all new scripts** — type errors at edit time are blockers, not to be silenced with `:: any` — source: technical-preferences.md, current-best-practices.md, breaking-changes.md
- **One RemoteEvent per logical concept, not per script** — validate before mutating, mutate before broadcasting — source: current-best-practices.md
- **Rate-limit every incoming RemoteEvent server-side** — see the Core layer's 6-step canonical validation order (ADR-0006) for the binding, project-wide implementation of this principle
- **`Humanoid`-driven movement is the confirmed locomotion baseline** (ADR-0003) — the post-cutoff Character Controller Library is not adopted project-wide; re-evaluate only per ADR-0003's named checkpoint (the `/prototype predator-ai` spike), never adopted silently mid-implementation
- **This project's Roblox version is a live, auto-updating platform** — any Roblox API not already named in an Accepted ADR or this manifest should be verified against `docs/engine-reference/roblox/` and current Creator Docs before use, per `VERSION.md`'s verification workflow
