# Terranova — Master Architecture

## Document Status

- Version: 0.3 (TD sign-off complete, 4 concerns fixed in-document)
- Last Updated: 2026-07-06
- Engine: Roblox Studio (live platform, pinned 2026-04-29) / Luau (`--!strict`) / Knit / Rojo
- GDDs Covered: crafting-and-items.md, ecological-disturbance.md (+ verification.md, forward-obligations.md), hud.md, player-controller.md, predator-ai.md, resource-management.md, resource-node.md
- ADRs Referenced: none yet — zero ADRs exist in `docs/architecture/`
- Technical Director Sign-Off: 2026-07-06 — **APPROVED WITH CONDITIONS** (CONCERNS verdict; all 4 concerns fixed in this same revision: the TR-coverage overclaim was corrected with an explicit clarification, the `RequestSquadOxygenSpend` dedup-key signature was pinned to match RM's GDD, the death-fan-out consumer count/`ReleasePredatorLock`-caller contradiction was resolved [PA only, not PC], and RunController's read direction was mandated as event-subscriber-only, never a synchronous state-puller)
- Lead Programmer Feasibility: *(skipped — Lean review mode per `production/review-mode.txt`)*

---

## Engine Knowledge Gap Summary

**Engine**: Roblox Studio (live platform, auto-updating) · **LLM training cutoff**: ~January 2026 · **Overall platform risk**: HIGH

### HIGH RISK (must verify against current Roblox/Knit docs before deciding)
- **Locomotion / Character Controller Library** — legacy `Humanoid` vs. the post-cutoff Character Controller Library. Shared unresolved decision between Player Controller and Predator AI (both need consistent movement-primitive semantics for the `WALK_SPEED < PREDATOR_HUNT_APPROACH_SPEED < SPRINT_SPEED` invariant).
- **Input Action System** (new keycodes incl. `TouchPosition`) — Player Controller's touch/gamepad/KBM parity model is unverified against this post-cutoff surface.
- **`require()`-based module-private singleton reliability** — Ecological Disturbance's RegistrationHandshake pattern (the mechanism that eliminates the KnitStart-ordering race) assumes same-instance module caching across services; asserted in the GDD, not confirmed against the engine.
- **`BindableEvent:Fire` synchronous-dispatch guarantee** — the entire `Humanoid.Died`-monopoly / `OnPlayerDied` fan-out depends on zero-yield synchronous callback dispatch, in registration order, before `:Fire` returns.
- **Knit `RemoteSignal` API surface** (`:Fire`/`:FireAll` vs. the nonexistent `:FireClient`/`:FireAllClients`) — already corrected once mid-design (a fixture was built against the wrong method names); version-specific, needs pinning against the actual Knit build.
- **Inter-service `KnitStart` ordering** — assumed undefined-between-services by multiple designs (ED's register-time-subscribe pattern, HUD's KnitInit-not-KnitStart mounting rule); needs confirming once, project-wide, not re-solved per system.
- **AST-tooling feasibility** for ED's H.39e/H.39f call-graph and alias-resolution CI lints — currently honor-system pending a `luau-lsp`-class tool; a genuine open engineering risk, not just a scheduling one.

### MEDIUM RISK (verify key APIs)
- **`PathfindingService:FindPathAsync`** real-world cost against actual level navmesh geometry for an oversized NPC agent — needed to validate Predator AI's ≤2ms per-burst ceiling.
- **`workspace:GetServerTimeNow()` monotonicity** under server migration/restart — every decay formula in ED and every timer in PC/RM depends on it never jumping backward.
- **Cross-Signal delivery ordering** — Resource Management's own text assumes Roblox does not guarantee cross-Signal FIFO ordering across different signal channels; the "self-heals within one sync interval" mitigation needs validating, not assuming.
- **Non-yielding critical-section safety** — Resource Management's oxygen check-and-set and Resource Node's gather-lock both rely on Luau's cooperative scheduling making these atomic; any hidden yield (including inside some Knit/Signal internals) breaks the guarantee.
- **`Tween:Cancel()` rest-state semantics** — HUD's FlashArbiter rebuild depends on knowing whether a cancelled tween freezes mid-value or snaps to a defined state.
- **No native drop-shadow Instance** — HUD's figure/ground opacity model may need a `UIStroke`+duplicate-Frame workaround; must not threaten the 2ms mobile HUD budget.
- **StreamingEnabled + `loadedChunks` trigger** — ED's own text flags this as unresolved (N1) and says to escalate to creative-director if no zero-client-writable-property API exists — the single most concrete open engine-capability question in the whole requirements baseline.

### LOW RISK (in training data, stable)
Core physics/constraint system, TestEZ, ProfileStore, the basic RemoteEvent/RemoteFunction client-server model, DataStoreService retry patterns — all long-standing, well-documented, not touched by post-cutoff changes.

### Systems touching HIGH/MEDIUM risk domains
| System | Domain | Risk |
|---|---|---|
| Player Controller | Locomotion, Input Action System | HIGH |
| Predator AI | Locomotion, PathfindingService, RemoteSignal API | HIGH/MEDIUM |
| Ecological Disturbance | `require()` singleton, BindableEvent sync, RemoteSignal API, KnitStart ordering, AST tooling, StreamingEnabled | HIGH/MEDIUM |
| Resource Management / Resource Node | Cross-Signal ordering, non-yielding critical sections, `GetServerTimeNow()` | MEDIUM |
| HUD | Tween cancel semantics, no native drop-shadow | MEDIUM |
| Crafting & Items | Heartbeat connection-priority (confirmed absent; already designed around in-GDD) | LOW (resolved) |

**Recurring cross-system questions that should each get ONE ADR-phase verification, not one per system**: the locomotion driver choice; Knit `RemoteSignal`/`KnitStart` behavior; non-yielding-section safety.

---

## Technical Requirements Baseline

**218 requirements extracted across 8 sources** (7 GDDs + cross-cutting items from `game-concept.md`'s own Technical Considerations/Risks sections). Full per-system tables were produced by dedicated extraction passes and are the source of truth for `docs/architecture/tr-registry.yaml` population (via `/architecture-review`). Summary:

| System | TR count | ID range |
|---|---|---|
| Ecological Disturbance | 35 | TR-ed-001–035 |
| Predator AI | 29 | TR-pa-001–029 |
| Player Controller | 33 | TR-pc-001–033 |
| Resource Management | 18 | TR-rm-001–018 |
| Resource Node | 16 | TR-rn-001–016 |
| Crafting & Items | 40 | TR-craft-001–040 |
| HUD | 31 | TR-hud-001–031 |
| Cross-cutting (game-concept.md) | 16 | TR-xcut-001–016 |
| **Total** | **218** | |

**Cross-cutting requirements (TR-xcut-001–016)**, binding on architecture but owned by no single GDD:
1. RemoteEvent trust-boundary — 11 named surfaces, each needs per-event + per-player-global rate limits and server-side *plausibility* validation (not just legality).
2. Cosmetic purchase idempotency — `ProcessReceipt` writes an idempotency key to ProfileStore before returning `PurchaseGranted`; no-charge-without-grant is a hard requirement.
3. Client-prediction scope restricted to movement/visual only; every gameplay-consequential outcome is server-confirmed-only.
4. Character replication is the primary bandwidth consumer (~15–30 KB/s of the 50 KB/s budget from 3 remote players before any game code runs) — must be profiled before trusting any per-system signal budget.
5. Mobile thermal-throttle graceful-degradation mode (trigger: sustained client frame-time >40ms p95).
6. DataStore/ProfileStore is the only persistence surface in the MVP (cross-run cosmetics/meta only) — verified by a forced-disconnect-reconnect smoke test.
7–9. Predator FindPathAsync throttle, raycast cadence, and always-broadcast state policy (concept-level constraints Predator AI's own TRs implement).
10. Analytics event schema for the MVP hypothesis gate (`PredatorEncountered`, `RunStarted`, `RunEnded{exitReason}`, `DeathStatePayload`) — routes through the unauthored RunController.
11. **RunController** — sole owner of `RunEnded` + win/lose precedence. Unauthored; a real arbiter design was attempted and backed out at commit `3747c3c` (round-24) for migrating only the defeat half and leaving `RunEndConditionRaised` unregistered — worth mining for the re-authoring pass. Load-bearing for Player Controller, Crafting & Items, and Resource Node's completability gate.
12. **Camera** — unauthored (PC OQ.3); blocks dead-player quick-ping/emote billboards and spectator camera; HUD has provisional wiring against it.
13. **Locomotion driver** — Humanoid vs. Character Controller Library, shared unresolved decision between Player Controller and Predator AI.
14. Disconnect-mid-run emission decay (maps to ED's E.4).
15. No-in-run-save verification test.
16. 4-client desync-tolerance integration test (±0.5 units at every Heartbeat boundary).

**Known open defects surfaced by extraction** (carried from prior reviews, now consolidated as architecture inputs, not new findings): HUD's FlashArbiter window-model bug (TR-hud-007), D.1/D.5/D.7 NaN-bypass guards (TR-hud-024/026), the unresolved threat-edge loud-ground micro-fork (TR-hud-028), and OQ.6's oxygen-color/predator-hue contradiction (TR-hud-031).

---

## System Layer Map

Roblox/Knit has no engine-native "Platform Layer" module — that layer is implicitly Roblox Studio + Knit + Rojo, the substrate every other layer sits on. Layer assignments below follow `systems-index.md`'s existing designations for the 7 authored systems, plus two known-unauthored systems and one system-shaped gap with no GDD at all.

```
┌─────────────────────────────────────────────────────────────────────┐
│  PRESENTATION LAYER                                                  │
│  HUD                                                                  │
├─────────────────────────────────────────────────────────────────────┤
│  FEATURE LAYER                                                        │
│  Predator AI · Resource Node · Camera (UNAUTHORED)                    │
├─────────────────────────────────────────────────────────────────────┤
│  CORE LAYER                                                            │
│  Resource Management · Crafting & Items                                │
├─────────────────────────────────────────────────────────────────────┤
│  FOUNDATION LAYER                                                       │
│  Ecological Disturbance (event bus, zero deps)                          │
│  Player Controller (movement/death lifecycle — near-universal dependency)│
│  RunController (UNAUTHORED — sole RunEnded broadcaster, win/lose precedence) │
│  Save/Load — Cosmetic Persistence (UNAUTHORED — no GDD exists at all)        │
├─────────────────────────────────────────────────────────────────────┤
│  PLATFORM LAYER  (implicit — Roblox Studio + Knit + Rojo; no game-specific module) │
└─────────────────────────────────────────────────────────────────────┘
```

**Noted judgment calls (approved 2026-07-06):**
1. **RunController inverts the usual Foundation-layer flow — RESOLVED 2026-07-06 (TD sign-off).** ED is Foundation and genuinely dependency-free. RunController is Foundation by function (everything depends on its `RunEnded` verdict), and the original draft left ambiguous whether it *reads* Core/Feature-layer state by subscription or by synchronous pull — the TD sign-off flagged this as the headline risk, since a pull-based implementation would create real upward compile-time dependencies from a Foundation module into Core/Feature, undoing the layering this map exists to establish. **Mandated resolution: event-subscriber only** — PC/Crafting/RN publish their own lifecycle events upward; RunController subscribes and aggregates, exactly like ED's own publish-only shape. See the Module Ownership table's RunController row and ADR 2 for the binding version of this rule.
2. **Camera placed in Feature, not Core** — presentation-of-self rather than shared infrastructure, though tightly coupled to the Foundation-layer Player Controller. Revisit if the RunController/Camera authoring pass finds otherwise.
3. **Cosmetic persistence has no GDD at all** — surfaced here only because `TR-xcut-002`/`TR-xcut-006` are real, binding requirements from `game-concept.md` with nowhere else to live. May warrant a `/design-system` pass; for architecture purposes it needs at least a Foundation-layer ADR (ProfileStore schema, `ProcessReceipt` idempotency).

**Engine-risk flags on Core/Foundation systems**: Player Controller (Foundation) carries the two HIGH RISK items (locomotion driver, Input Action System). Ecological Disturbance (Foundation) carries the `require()`-singleton, `BindableEvent:Fire`, and Knit-`RemoteSignal` HIGH RISK items. Resource Management/Resource Node (Core) carry the MEDIUM RISK cross-Signal-ordering and non-yielding-critical-section questions.

---

## Module Ownership

### Foundation Layer

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Ecological Disturbance** (`DisturbanceService`) | Live point-source list + spatial grid; attribution archive; per-position/squad field values; tier-classification state; flora chunk saturation; RegistrationHandshake module | Server-internal: `Emit()`, `GetHottestHotspot()`, `GetSquadAggregateT(excludePlayer?)`, `RegisterPredatorLock`/`ReleasePredatorLock`, `GetOnPlayerDiedSignal()` (the sole `Humanoid.Died` relay), `TierCrossedEvent`, `OnDisturbanceBandCrossed`. Client-facing: `OnMeterUpdate`, `OnDisturbanceAlert`, `OnDeathAttributionPushed` (3 RemoteSignals) + `FloraChunkUpdate`/`FloraChunkInitialSnapshot` (2 server-fire-only RemoteEvents) | Nothing from MVP systems (dependency-free) — only Roblox `Players`, `Humanoid.Died`, `workspace:GetServerTimeNow()`, `RunService.Heartbeat` | `BindableEvent` (HIGH), Knit `RemoteSignal` (HIGH), `require()` singleton (HIGH), `GetServerTimeNow()` (MED), `Humanoid.Died` (LOW but architecturally load-bearing) |
| **Player Controller** (`PlayerControllerService`) | Locomotion/stamina/lantern state; death/respawn lifecycle (S4/S5); `deathEventId` minting + `DeathCostReconciliation`; ping/emote rate limits | `OnPlayerS4Entered`/`OnPlayerT6Respawned` (→ PA); calls out to `ReleasePredatorLock`; client-facing state pushes + `RequestSprintToggle`/`RequestLanternToggle`/`RequestPing`/`RequestEmote` intake | ED's `Emit()` (caller) + `GetOnPlayerDiedSignal()` (death trigger); RM's `OnPlayerOxygenExpired()` + pool-read accessor + `RequestSquadOxygenSpend`; ED's `OnDisturbanceBandCrossed`; RunController's `RunEndConditionRaised` (UNAUTHORED — blocked); Camera's spectator surface (UNAUTHORED — blocked) | `Humanoid` (HIGH — locomotion driver), `UserInputService`/`ContextActionService` (HIGH — Input Action System) |
| **RunController** *(UNAUTHORED)* | Would own: run-lifecycle state machine, win/lose precedence, the sole `RunEnded(exitReason)` broadcast | Would expose: `RunEndConditionRaised` (caller-side), `RunEnded` (broadcast to all systems) | **MANDATED PATTERN (TD sign-off 2026-07-06): event-subscriber only, never a synchronous state-puller.** PC/Crafting/RN MUST publish their own lifecycle events upward (e.g., PC fires a squad-wipe event, Crafting fires its own beacon-window-resolved event) which RunController subscribes to and aggregates into a verdict — the same publish-only shape ED already uses. RunController must NOT call synchronous accessor methods on PC/Crafting/RN to pull their current state; doing so would create upward compile-time dependencies from a Foundation-layer module into Core/Feature layers, which is exactly the layering violation this pattern exists to avoid. This mandate resolves the read-direction ambiguity the TD sign-off flagged as the headline risk in the original draft — bind it into ADR 2. | — |
| **Save/Load — Cosmetic Persistence** *(UNAUTHORED, no GDD)* | Would own: ProfileStore profile, `ProcessReceipt` idempotency ledger | Would expose: cosmetic equip/purchase surface | Would consume: `MarketplaceService` callbacks only (isolated) | `DataStoreService`/ProfileStore (LOW), `MarketplaceService:ProcessReceipt` (LOW) |

### Core Layer

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Resource Management** (`ResourceService`) | Squad-shared oxygen scalar `P` [0,600]; Healthy/Critical/Empty state machine; death-cost idempotency dedup set | `RequestSquadOxygenSpend`, read-only pool accessor, `OnPlayerOxygenExpired()`, `OnOxygenPulseRequest` intake; client-facing `OnOxygenChanged`/`OnOxygenDeducted`/`OnOxygenRestored` | Crafting's Beacon-Charge-Tier accessor (`GetCurrentBeaconChargeTier()`, ADR-0009 — fixed 2026-07-06, was misattributed to ED); Crafting's `CRAFT_CONCURRENCY_CAP`; RN's `canisterCycleTime` (init-time cross-validation) | `RunService.Heartbeat` (fixed-order tick application) |
| **Crafting & Items** (`CraftingService`) | Bench state (BT1-4); `benchMaxCraftersEffective` (frozen both directions); recipe catalog; two-tier inventory; Beacon lifecycle (BC1-6); `requiredHoldersBaseline`/`peakAliveCount`; `MAX_ACTIVE_BEACONS` enforcement | `OnBeaconWindowSurvived`/`OnBeaconWindowFailed` (currently → PC directly, pending RunController); 7 client-facing request events | ED's `GetOnPlayerDiedSignal()` (death relay) + `Emit()` (caller); RN's `OnGatherCompleted`; PC's alive-tracking (until RunController exists); PA's BC4 model (RESONANT sink — **unverified**, cross-review W1) | `RunService.Heartbeat` (single `_step` handler — no connection-priority reliance) |

### Feature Layer

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **Predator AI** (`PredatorService`) | FSM state; Hunt timers; lock-target + debounce; top-3 attribution cache; `SetNetworkOwner(nil)` enforcement | Channel A `OnPredatorStateChanged` (internal); Channel B `OnPredatorLockChanged` + `OnPredatorSense` (client-facing, split-frequency) | ED's `GetHottestHotspot`/`GetSquadAggregateT`/`TierCrossedEvent`/handshake; PC's S4/T6 signals; `PathfindingService` | `PathfindingService:FindPathAsync` (MED), `Humanoid`/locomotion (HIGH, shared w/ PC), Knit split-channel `RemoteSignal` (HIGH, shared w/ ED) |
| **Resource Node** (`ResourceNodeService`) | `NodeRecord` registry (7-state); arm-scan loop; lock state; respawn/generation-tokens | `OnGatherCompleted`; client-facing `OnNodeFullStateSnapshot`/`OnNodeStateChanged` | ED's `Emit("Gather",...)` (caller, emit-before-reward); PC's `RequestGather` + lantern state | `CollectionService` (node tags), `RunService.Heartbeat` (10Hz arm-scan — coroutine-leak flag) |
| **Camera** *(UNAUTHORED)* | Would own: spectator-camera state, sprint FOV, respawn fade | — | Would consume: PC's death/respawn lifecycle | — |

### Presentation Layer

| Module | Owns | Exposes | Consumes | Engine APIs (risk) |
|---|---|---|---|---|
| **HUD** (`HUDController`, client-only) | Zero authoritative state (pure subscriber); FlashArbiter/FigureArbiter presentation state | `GetGatherPromptMount()`/`GetEmoteWheelMount()` (split render/originate ownership) | ED's 3 signals; PA's Channel A/B; RM's oxygen pushes; Crafting's beacon-window broadcasts; RN's node snapshots; PC's state pushes | `TweenService` (MED — Cancel semantics), no native drop-shadow (MED workaround) |

### Dependency Diagram

```
PRESENTATION   HUD (pure subscriber — reads everything below, writes nothing back)
                 ▲  ▲    ▲       ▲        ▲       ▲
FEATURE       Predator AI │  Resource Node │    Camera(?)
                 │  │      │       │        │
                 │  └──────┼───────┼────────┘
CORE          Resource Mgmt◄────Crafting & Items
                 ▲              ▲      ▲
                 │              │      │
FOUNDATION    Ecological Disturbance ◄──┤ (event bus — everything publishes here)
              Player Controller ────────┘ (death/movement — near-universal dependency)
              RunController(?) ◄── reads state FROM PC/Crafting/RN, broadcasts RunEnded TO everything
              Save/Load(?) ── isolated, no MVP-system edges
                 ▲
PLATFORM      Roblox Studio + Knit + Rojo
```

**Notes (approved 2026-07-06):**
1. **Ecological Disturbance is the busiest module by far** — every other system either publishes emissions into it or consumes one of its query/signal surfaces (the "event bus" role per its own GDD). Its HIGH RISK engine questions (BindableEvent sync guarantee, RemoteSignal API surface, `require()` singleton) therefore sit on the critical path for every other system, not just ED's own.
2. **Crafting → Predator AI is a soft/unverified edge** (the RESONANT sink dependency) — included as "consumes" above but flagged open in the cross-review, not a confirmed contract.

---

## Data Flow

### Flow 1 — Frame/Core-Loop Update Path (Input → Core → State → Rendering)

The canonical example is the gather action, since it touches every layer in one pass:

```
CLIENT (touch tap-hold, 500ms wall-clock commit)
  │
  ▼ RequestGather({nodeId})                                    [RemoteEvent, client→server]
RESOURCE NODE (server)
  │  validate: payload→rate-limit→alive→registry→Available→
  │  unreserved→arm-timestamp→teleport-delta→proximity→inventory→lantern
  │  lock node, start NODE_EXTRACT_TIME_tier timer
  ▼ (RunService.Heartbeat, timer elapses)
  │  DisturbanceService:Emit("Gather", pos, magnitude, playerId)    [sync call — emit BEFORE reward]
  │  OnGatherCompleted → Crafting.PersonalInventory += material     [signal/event]
  │  OnNodeStateChanged → all clients                                [signal, server→client]
  ▼
ECOLOGICAL DISTURBANCE (same/next Heartbeat pass, 5Hz field-update)
  │  recompute fieldValue at the gather position
  │  IF boundary crossed: TierCrossedEvent fires                     [BindableEvent, server-internal]
  │  OnMeterUpdate → all clients (playerT/squadT)                    [RemoteSignal, 5Hz push]
  ▼
PREDATOR AI (next 4Hz decision tick, independent cadence)
  │  GetHottestHotspot reads the updated field
  │  may transition Patrol→Investigate
  ▼
HUD (client, reactive to every push above)
  │  gather-ring progress, inventory count, squad meter fill — all tweened, never polled
```

Four independent cadences run concurrently here (Heartbeat 60Hz, ED field-update 5Hz, PA decision 4Hz, HUD sync ≥2Hz) — none blocks another; each system reads the most recent value the slower producer has published.

### Flow 2 — Event/Signal Patterns (how systems decouple)

Four distinct mechanisms are used project-wide, and mixing them up is exactly the defect class that recurred throughout design (the `:FireClient`-vs-`:Fire` confusion, the Channel A/B bearing mix-up):

| Pattern | Examples | Crosses client boundary? | When to use |
|---|---|---|---|
| **Server-internal BindableEvent** | `TierCrossedEvent`, `OnDisturbanceBandCrossed`, `OnPredatorStateChanged`, `OnPlayerDied` | Never | Cross-service decoupling within one server process |
| **Knit RemoteSignal — targeted** | `OnMeterUpdate` (per-player `:Fire`), `OnPredatorSense` (per-client `:Fire`), `OnPredatorLockChanged` (locked-player-only) | Yes, server→client | Recipient-specific payloads (bearing, personal spike alerts) |
| **Knit RemoteSignal — broadcast** | Predator state-change broadcast, `OnWorldResponseCue` | Yes, server→client | Squad-wide, identical payload |
| **Direct synchronous method call** | `GetHottestHotspot`, `GetSquadAggregateT`, `RequestSquadOxygenSpend`, `GetOnPlayerDiedSignal()` | Never | Caller needs an immediate return value, not a decoupled notification |
| **RegistrationHandshake module-private `require()`** | ED↔PA cross-service wiring only | Never | The ONE case where even a BindableEvent reference itself needs decoupled, order-independent acquisition (see Flow 4) |

The 11 client→server RemoteEvent surfaces (`TR-xcut-001`) are the only path data enters this list from outside the server; everything else here is server-authoritative broadcast or internal.

### Flow 3 — Save/Load Path

This is the shortest flow in the game, by design (Pillar 4, "Rounds, Not Saves" — no in-run save):

```
MarketplaceService:ProcessReceipt(receiptInfo)
  │
  ▼ Save/Load module (UNAUTHORED — this flow is scoped now, blocked on authoring)
  │  check idempotency ledger for receiptInfo.PurchaseId
  │  IF already granted: return PurchaseGranted (no re-charge)
  │  IF not: write idempotency key to ProfileStore FIRST, then grant cosmetic, THEN return PurchaseGranted
  ▼
ProfileStore (DataStoreService wrapper)
  │  persists: cosmetic unlocks, meta-progression counters
  │  NEVER persists: oxygen, disturbance field, node state, bench/inventory, beacon state,
  │  predator FSM state, or anything else server-session-scoped
```

Every other module in the game is confirmed zero-persistence (ED's F.6, Crafting's TR-craft-028, RN's `ResetAllNodes()` on run reset). The `BindToClose` final-save requirement (`technical-preferences.md`'s forbidden-patterns list) applies only to this one module.

### Flow 4 — Initialization Order

Roblox/Knit's actual guarantee is narrower than "boot in dependency order": **all `KnitInit`s complete before any `KnitStart` fires, but ordering between services' `KnitStart` calls is undefined.** This is a HIGH RISK item three separate systems (ED, PA, HUD) independently designed workarounds for — generalized here into one project-wide rule rather than letting each system re-solve it:

> **Principle**: any object, signal, or accessor that another service might need to synchronously read during ITS OWN `KnitStart` MUST be constructed during `KnitInit`, never `KnitStart`. Where a live `:Connect()` subscription is unavoidable across the `KnitStart` boundary (ED↔PA), use the register-time-subscribe pattern (RegistrationHandshake module) rather than assuming call order.

```
SERVER BOOT
  Phase 1 — KnitInit (all services, order unspecified, no cross-service reads except via
            module-private require() — the RegistrationHandshake pattern)
    ED: construct live-source list, spatial grid, RegistrationHandshake slots
    PC: construct per-player state tables (empty, no players yet)
    RM: construct oxygen pool (P=600)
    Crafting: construct empty bench/inventory state
    PA: construct FSM (Patrol), spawn predator, SetNetworkOwner(nil)
    RN: enumerate NodeRecords via CollectionService tag
    HUD: construct mount Instances (gather-ring, emote-wheel) — CR.9's KnitInit rule
  Phase 2 — KnitStart (order UNDEFINED between services)
    ED↔PA: register via RegistrationHandshake (order-independent by construction)
    Everyone else: connect to already-KnitInit-constructed signals — safe regardless of order

PLAYER JOIN (per-player, independent of server boot)
  PlayerAdded → CharacterAdded
    → PC: per-player state init
    → RM/Crafting: player added to shared-pool/alive-set accounting
    → ED: FloraChunkInitialSnapshot (bootstrap BEFORE any incremental FloraChunkUpdate)
    → RN: OnNodeFullStateSnapshot (bootstrap BEFORE any incremental OnNodeStateChanged —
       TR-hud-027's ordering requirement)
    → HUD: resolves initial Figure-Ground state from the snapshot batch, THEN starts reacting to deltas
```

**RunController, once authored, needs to initialize early** (Foundation-tier) since both PC and Crafting call out to it — but per the same undefined-`KnitStart`-order rule, its `RunEndConditionRaised`/`RunEnded` signal objects must exist from `KnitInit`, same as everything else.

---

## API Boundaries

Documenting the **load-bearing boundaries** — the contracts whose exact invariants determine whether the game works, several the subject of prior review-round disputes. A full per-method manifest is `/create-control-manifest`'s job once ADRs land.

### Boundary 1 — `DisturbanceService` (the busiest interface in the game)

```luau
-- Server-internal only. Zero client-callable path to any of these.
function DisturbanceService:Emit(
    emissionType: "Gather" | "Sprint" | "Light" | "Craft" | "Beacon",
    position: Vector3,
    initialMagnitude: number,  -- must be finite; NaN/Inf rejected at the door
    sourcePlayerId: number
): ()
-- GUARANTEE: emission is recorded in the live-source list before this call returns
--            (callers rely on this for "emit-before-reward" ordering — RN's TR-rn-008)
-- INVARIANT (caller-side): never called from any Client-reachable code path

function DisturbanceService:GetHottestHotspot(
    callerPosition: Vector3, searchRadius: number, minimumTier: Tier
): HotspotResult?
-- GUARANTEE: non-nil result always meets minimumTier; hotspotId is stable across
--            representative-position turnover within the same dedup cell
-- CALLER: Predator AI only, at its fixed 4Hz tick

function DisturbanceService:GetSquadAggregateT(excludePlayer: Player?): number
-- GUARANTEE: nil -> unfiltered max; sole-remaining-player-excluded -> that player's own T
--            (never 0/nil on a non-empty server); zero connected players -> 0.0;
--            NaN/+Inf fail-quiet to 0.0
-- CALLER: Predator AI's Hunt->Disengage quiet-check (excludeLockedPlayer)

function DisturbanceService:GetOnPlayerDiedSignal(): BindableEvent
-- GUARANTEE: fires synchronously, same Luau frame as the underlying Humanoid.Died,
--            exactly once per death, callback body MUST be yield-free
-- INVARIANT: this is the ONLY legal way any other service learns of a player death —
--            no service may hold its own Humanoid.Died:Connect (CI-enforced, H.39e)
-- CALLERS (3, corrected 2026-07-06 — TD sign-off caught a miscount/contradiction):
--   Player Controller, Crafting & Items (both re-anchored 2026-07-05), AND Predator AI
--   (subscribes independently, per ED's C.1.11 ordering, to call ReleasePredatorLock —
--   see Boundary 1 above)

function DisturbanceService:RegisterPredatorLock(predatorId: string, emissionIds: {string}): ()
function DisturbanceService:ReleasePredatorLock(predatorId: string): ()
-- INVARIANT: merge-on-re-register (union, never replace); 5.0s retention grace on release
-- CALLER: Predator AI ONLY — called from inside PA's own GetOnPlayerDiedSignal() handler
--         (per ED's C.1.11 sub-step ordering). Player Controller does NOT call this method;
--         PC's role in the death fan-out is limited to firing OnPlayerS4Entered/
--         OnPlayerT6Respawned as a separate, parallel signal (TD-fix 2026-07-06, resolves
--         a Boundary-1-vs-Boundary-5 contradiction the TD sign-off caught)
```

### Boundary 2 — RegistrationHandshake (the ED↔PA decoupling mechanism)

```luau
-- src/server/services/DisturbanceService/RegistrationHandshake.luau
-- Module-private. Acquired via require(), NOT Knit.GetService — this is what makes it
-- immune to the undefined-KnitStart-order problem (see Data Flow Phase 4).
return {
    RegisterPredatorLockChangedSignal: (signal: RemoteSignal) -> (),
    RegisterPredatorStateChangedSignal: (bindable: BindableEvent) -> (),
    setOnPredatorStateChangedHandler: (handler: (PredatorState) -> ()) -> (),
    getOnPredatorLockChangedSignal: () -> RemoteSignal?,
    getOnPredatorStateChangedBindable: () -> BindableEvent?,
}
-- INVARIANT: exactly these 5 exports, nothing else — this is a minimal-surface API
--            by design; a 6th export or a Knit.GetService call inside this module
--            is a regression (H.39c-lint-enforced)
```

### Boundary 3 — `ResourceService` (oxygen)

```luau
function ResourceService:RequestSquadOxygenSpend(
    deadPlayerUserId: number, amount: number, reason: string, deathEventId: string
): ()
-- GUARANTEE: idempotent per the COMPOUND key (deadPlayerUserId, deathEventId) — matching
--            RM's own GDD text verbatim ("written before the deduction executes... the
--            (userId, deathEventId) dedup set"). A duplicate call with the same compound
--            key is a no-op, never double-charges. (deathEventId alone IS already
--            session-lifetime-unique per player-death per PC's own guarantee, making the
--            userId technically redundant for uniqueness — but RM's GDD specifies the
--            compound key as defense-in-depth against a deathEventId-generation bug, so
--            the signature carries both. TD sign-off 2026-07-06: this parameter was
--            missing from the original signature — added, not newly designed.)
-- CALLER: Player Controller only, on the death path

-- Read-only pool accessor (name TBD at implementation — server-internal, no client path)
function ResourceService:_getPool(): number
-- CALLER: Player Controller, ONLY for the oxygen-grace-timer expiry re-check

-- signal
ResourceService.OnPlayerOxygenExpired: Signal<()>
-- GUARANTEE: argument-less, squad-wide, fires exactly once per Empty-state ENTRY
--            (edge-triggered, never re-fires while P stays at 0)
-- CONSUMER: Player Controller — starts the ratified OXYGEN_GRACE_DURATION=5s timer
```

### Boundary 4 — `HUDController` mount contract (CR.9 split render/originate ownership)

```luau
-- Exposed BY HUD, called BY Resource Node / Player Controller to attach input bindings.
-- This is the one boundary where a KNOWN carried defect (CR.9's mounting-sequence bug)
-- makes the invariant below load-bearing, not decorative.
function HUDController:GetGatherPromptMount(): Frame
function HUDController:GetEmoteWheelMount(): Frame
-- INVARIANT (HUD side): these Instances MUST be constructed during HUDController's
--            KnitInit, never KnitStart (Knit does not guarantee cross-controller
--            KnitStart order — a KnitStart-time construction races the producer's
--            attach call). Must persist for the full run — no Destroy/rebuild across
--            respawn, or the producer's input binding silently disconnects.
-- INVARIANT (HUD's own code): zero input :Connect() calls, zero :FireServer()/
--            :InvokeServer() calls anywhere in HUDController source (statically
--            enforced) — HUD renders, it never originates a network call.
```

### Boundary 5 — Player-death fan-out (cross-cutting, 3 consumers)

```luau
-- Every consumer of DisturbanceService:GetOnPlayerDiedSignal() must independently
-- satisfy this shared invariant — it's one contract, enforced at 3 call sites
-- (corrected 2026-07-06 — TD sign-off caught a miscounted "4" and a contradiction
-- with Boundary 1 over who calls ReleasePredatorLock; PA does, not PC):
GetOnPlayerDiedSignal():Connect(function(payload: DeathPayload)
    -- MUST be yield-free (no task.wait/spawn/delay, no coroutine.yield, no
    -- :InvokeServer/Client) for the ENTIRE synchronous chain reachable from here
    -- MUST NOT itself subscribe to Humanoid.Died directly (CI-enforced monopoly)
end)
-- The 3 consumers, each independently subscribed:
--   1. Player Controller — T5 death flow (RequestSquadOxygenSpend, timers, S4/S5 state)
--   2. Crafting & Items — departure enqueue (bench/beacon alive-set bookkeeping)
--   3. Predator AI — calls DisturbanceService:ReleasePredatorLock(predatorId) from
--      INSIDE its own handler here (per ED's C.1.11 snapshot-before-purge ordering) —
--      this is the ONLY caller of ReleasePredatorLock; PC does not call it (see Boundary 1)
```

### Engine-type flags on these boundaries

- `RemoteSignal`/`BindableEvent` types throughout — **HIGH RISK**, per the Engine Knowledge Gap Summary (sync-dispatch and API-surface questions apply to every boundary above that uses them).
- `Player?` as an optional parameter type (Boundary 1's `excludePlayer`) — standard Luau, LOW risk, but the *nil-handling contract* is the part that broke Predator AI's quiet-check before round-23 fixed it; the type signature alone doesn't capture the invariant, which is why it's spelled out in prose above.
- No `Frame`/`ScreenGui` type-signature risk on Boundary 4 — stable, long-standing Roblox UI types (LOW risk); the risk here is entirely in the *timing* invariant, not the type surface.

---

## ADR Audit

**ADR Quality Check**: trivial — zero ADRs exist in `docs/architecture/`. Nothing to audit.

**Traceability Coverage Check**: 0 of 218 requirements have ADR coverage (expected for a fresh Technical Setup phase). **Coverage clarification (TD sign-off 2026-07-06 — the original draft overclaimed here):** the 16 ADRs below explicitly cite roughly 40 of the 218 TR-IDs. The remaining ~178 are NOT gaps — they are already unambiguously specified by their APPROVED GDD (exact constants, formulas, state machines) and require no new architectural DECISION, only implementation. An ADR is warranted only where (a) an engine-capability question is genuinely open, (b) a cross-system contract needs pinning, or (c) a pattern recurs across systems and deserves one project-wide answer. The concrete 218→ADR/story mapping is `/architecture-review` Phase 8's job (via `tr-registry.yaml`), not this document's. Two spot-checks the TD sign-off ran: **TR-ed-018/019/020** (ED's performance-fence requirements) have no separate ADR because they are performance budgets the *implementation* of ADR 3 must meet, not a design decision in their own right — verify against them when ADR 3 is written, don't ADR them separately. **TR-ed-021/022** (ED's CI-lint enforcement requirements) route through the AST-tooling open question already listed above, not a standalone ADR. **TR-ed-024** (test-infrastructure provisioning) is a `/test-setup` concern, not an architecture decision at all.

---

## Required ADRs

### Must have before coding starts (Foundation & Core)

| # | ADR Title | Covers | Why first |
|---|---|---|---|
| 1 | **Locomotion Driver: Humanoid vs. Character Controller Library** | TR-pc-003, TR-pa-022, TR-xcut-013 | HIGH RISK, blocks both PC and PA; the `WALK_SPEED < HUNT_APPROACH_SPEED < SPRINT_SPEED` invariant is meaningless until this is decided |
| 2 | **RunController Architecture** — MUST mandate the event-subscriber pattern (publish-upward from PC/Crafting/RN, RunController subscribes/aggregates), never a synchronous state-puller (TD sign-off 2026-07-06) | TR-xcut-011, TR-pc-024, TR-craft-032/033/034 | Flagged by all 4 gate-check directors as the top Foundation gap; a prior migration attempt exists (commit `3747c3c`'s revert message) but was never committed — treat as a lesson (defeat-only migrations don't work), not salvageable code. Likely needs a short GDD, not just an ADR. |
| 3 | **DisturbanceService Core Architecture** (spatial field + RegistrationHandshake pattern) | TR-ed-001–017, TR-ed-025–035 (N1–N11) | The busiest module in the game; every other system's correctness depends on getting this right once |
| 4 | **Death & Respawn Lifecycle** (cross-cutting: PC/RM/ED) | TR-pc-016–022, TR-rm-007/008/012, TR-ed-010/011, N10 | Idempotent `deathEventId` + grace-timer contracts span 3 systems; converges the C4 ruling and the seam-patch re-anchor work |
| 5 | **RemoteEvent Trust Boundary & Rate-Limiting** | TR-xcut-001, TR-pc-032 | Explicitly flagged as an ADR PC's own GDD "could not close alone"; the 11-surface enumeration already exists at concept-level |
| 6 | **KnitInit/KnitStart Ordering Discipline** (project-wide principle) | Recurring across ED, PA, HUD | Three systems independently reinvented this; one ADR, not three |
| 7 | **Save/Load & Cosmetic Persistence** (ProfileStore schema) | TR-xcut-002/006 | The only persistence surface in the MVP; currently has no GDD at all |
| 8 | **Character Replication Bandwidth Baseline & NetworkOwnership Strategy** | TR-xcut-004, TR-pa-002 | Primary bandwidth consumer (~15–30 KB/s before any game code runs) — every other system's signal budget is provisional until this is profiled |

### Should have before the relevant system is built (Core/Feature)

| # | ADR Title | Covers |
|---|---|---|
| 9 | **Resource Economy Cross-Validation** (fail-fast init asserts) | TR-rm-014/015/016, TR-rn-007/013 |
| 10 | **Beacon Activation × `MAX_ACTIVE_BEACONS` Cross-Lock** | TR-craft-016/017, TR-ed-016 |
| 11 | **Non-Yielding Critical-Section Enforcement Pattern** (project-wide, like #6) | RM's oxygen check-and-set, RN's gather-lock, Crafting's `_step` ordering, ED's H.39e lint |
| 12 | **Predator AI Locomotion & Pathfinding Implementation** | TR-pa-020/021/023/024 — gated on the `/prototype predator-ai` spike game-concept.md itself recommends |

### Can defer to implementation

| # | ADR Title | Covers |
|---|---|---|
| 13 | HUD FlashArbiter/FigureArbiter formalization (fixes 4 known open defects) | TR-hud-007/012/024/026/028 |
| 14 | Camera system architecture | TR-pc-025 — only cut/provisional features wait on it, not core loop |
| 15 | Analytics/telemetry pipeline | TR-xcut-010 — additive instrumentation |
| 16 | Cosmetic Boundary Rule automated enforcement (TestEZ mechanical-equivalence test) | game-concept.md MVP requirement #9 — defer until cosmetic content exists |

---

## Architecture Principles

1. **Server-authoritative, always** — every gameplay-consequential state lives on the server; clients render and predict movement/visuals only, never outcomes (`technical-preferences.md` + TR-xcut-003).
2. **One event bus, one direction** — Ecological Disturbance is the sole cross-system signal, publish-only from every other system's perspective; no system reaches back into another's internals except through the named boundaries in this document.
3. **KnitInit builds, KnitStart connects** — any object another service might synchronously need is constructed at `KnitInit`; cross-service `:Connect()` subscriptions never assume `KnitStart` ordering.
4. **Relocate, don't re-litigate** — this project's own design history shows non-design accretion (test scaffolding, CI YAML, forward-obligations) inflating GDDs to the point of non-convergence; the same discipline applies to ADRs (one decision per ADR).
5. **Rounds, not saves** — zero in-run persistence anywhere except the isolated cosmetic/meta-progression module; every other system's state is discarded at run end by construction, not by convention.

---

## Open Questions

- Locomotion driver (ADR 1) — blocks PC + PA implementation start.
- RunController design + authoring (ADR 2) — blocks PC/Crafting/RN completability.
- Camera system (ADR 14, deferred) — blocks 2 named PC/HUD features, not core loop.
- 3 recurring HIGH/MEDIUM RISK engine questions (Knit RemoteSignal API, BindableEvent sync guarantee, `require()` singleton reliability) — need one empirical verification each, ideally before ADRs 3/6 are written.
- OQ.6 (HUD oxygen-color vs. predator-hue contradiction) — blocks the planned automated HSV CI gate specifically.
- The RESONANT/Dampener-Coil PA-obligation reconciliation (cross-review W1) — still unverified against PA's actual ACs.
