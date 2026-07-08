# ADR-0001: KnitInit/KnitStart Ordering Discipline

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + Knit framework |
| **Domain** | Core (Scripting / Architecture) |
| **Knowledge Risk** | HIGH — Knit's own documented guarantee ("all `KnitInit`s complete before any `KnitStart` fires") is confirmed in Knit's public docs, but the *absence* of an ordering guarantee between different services' `KnitStart` calls is a common source of race conditions in Knit projects and is easy to get wrong under the live-platform LLM knowledge gap. |
| **References Consulted** | `docs/engine-reference/roblox/VERSION.md`, `docs/engine-reference/roblox/breaking-changes.md`, `docs/engine-reference/roblox/deprecated-apis.md`, `.claude/docs/technical-preferences.md` (Knit as confirmed Architecture Framework) |
| **Post-Cutoff APIs Used** | None — this ADR does not introduce any new Roblox API; it constrains *how* existing Knit lifecycle hooks (`KnitInit`, `KnitStart`) and `require()` are used. |
| **Verification Required** | Confirm against the actual pinned Knit build that (a) `require()` of the same ModuleScript instance from two different services returns the identical table reference, from the default serial script context only (module-private singleton reliability — flagged HIGH RISK in `docs/architecture/architecture.md`'s Engine Knowledge Gap Summary; does NOT hold across `Actor` parallel-execution boundaries — see Risks); (b) if raw `BindableEvent` is used anywhere instead of Knit's bundled `Signal` class, confirm the pinned `Workspace.SignalBehavior` value (`Default`/`Immediate`/`Deferred`) and pin it explicitly rather than relying on the platform default. Both are load-bearing assumptions for the RegistrationHandshake pattern below and must be spiked in Studio before the Foundation layer is implemented. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | ADR-0002 (RunController Architecture) — RunController's event-subscriber mandate assumes this ordering discipline is settled; DisturbanceService Core Architecture ADR — RegistrationHandshake is generalized here from ED's GDD-level design; Death & Respawn Lifecycle ADR — the `OnPlayerDied` BindableEvent's `KnitInit`-time construction relies on this rule |
| **Blocks** | No epic directly — but every Foundation and Core layer epic (ED, PC, RunController, RM, Crafting) implicitly depends on this rule being settled before their services are implemented, since all of them declare `KnitInit`-time construction of cross-service-visible objects |
| **Ordering Note** | This should be the first ADR Accepted — it is a project-wide pattern rule, not a single system's architecture, and three GDDs (ED, PA, HUD) already assume it is settled |

## Context

### Problem Statement

Knit's documented lifecycle guarantee is narrower than developers often assume: **all services' `KnitInit` methods complete before any service's `KnitStart` fires, but the order in which different services' `KnitStart` methods run relative to each other is undefined.** A service cannot assume any other specific service has already run its `KnitStart` when its own `KnitStart` executes.

This project's design process reached this same conclusion three times independently, at the GDD layer, before architecture was formalized:

- **Ecological Disturbance** (`design/gdd/ecological-disturbance.md`) needed Predator AI to be able to synchronously acquire a lock-state signal from DisturbanceService, but could not assume DisturbanceService's `KnitStart` ran before Predator AI's. It solved this with a bespoke **RegistrationHandshake** module — a module-private table acquired via `require()` rather than `Knit.GetService()`, immune to `KnitStart` ordering because `require()` caching happens independently of the Knit lifecycle.
- **Predator AI** consumes ED's RegistrationHandshake as the correct answer to the same problem, without re-deriving it.
- **HUD** (`design/gdd/hud.md`, CR.9) independently arrived at a **"construct mount Instances during `KnitInit`, never `KnitStart`"** rule for the same underlying reason — a producer's `KnitStart`-time attach call could race a `KnitStart`-time construction on the consumer side.

Without a single project-wide ADR, every future service would need to re-derive this rule from scratch, with no guarantee of reaching the same (correct) answer, and no single place to point new contributors at. The architecture document (`docs/architecture/architecture.md`, Data Flow → Flow 4 and Architecture Principle #3) already states the rule in prose; this ADR is the binding decision record that principle traces back to.

### Constraints

- Must work within Knit's actual lifecycle API — this project does not fork or monkey-patch Knit.
- Must not require services to know each other's boot order (Roblox/Knit gives no supported way to force `KnitStart` ordering between services).
- Must remain a single, generalizable pattern — not a special case per pair of services (ED↔PA, PC↔RunController, etc.), per Architecture Principle #4 ("Relocate, don't re-litigate").
- Zero-yield constraint: several downstream systems (ED's `OnPlayerDied` fan-out, its H.39e CI lint) depend on synchronous, non-yielding dispatch through any object this rule governs the construction of.

### Requirements

- Any object, signal, or accessor that another service might need to **synchronously read or call during its own `KnitStart`** must already exist and be fully constructed by the time any `KnitStart` runs.
- Where a **live subscription** (`:Connect()`) must be established *across* the `KnitStart` boundary between two specific services, and simple `KnitInit`-time construction of the signal object is insufficient (e.g., the subscribing side also needs to register itself with the owning side, not just listen), the interaction must use the order-independent **RegistrationHandshake** pattern rather than assuming call order.
- The rule must be stated once, generally, and referenced by every service's GDD/ADR rather than restated per system.

## Decision

Adopt a single, two-part project-wide discipline, binding on every Knit service and controller:

**Rule 1 — "`KnitInit` builds, `KnitStart` connects."** Every object, signal (`BindableEvent`/`RemoteSignal`), or accessor method that another service or controller might need to synchronously read, call, or connect to during **its own** `KnitStart` MUST be fully constructed inside the owning service's `KnitInit`, never deferred to `KnitStart`. `KnitStart` bodies are reserved for establishing connections *to already-`KnitInit`-constructed* objects (subscribing to signals, calling accessor methods) — never for constructing the objects being connected to.

**Rule 2 — RegistrationHandshake for live cross-service subscriptions.** In the one class of case Rule 1 cannot fully cover — where service A must register itself (not just passively listen) with service B, and neither side can assume the other's `KnitStart` has already run — use the **RegistrationHandshake module-private pattern**, generalized from Ecological Disturbance's ED↔PA design:

- The owning service exposes a plain ModuleScript (not a Knit service, not `Knit.GetService()`) alongside its Knit service, containing a small set of registration functions (e.g., `RegisterXChangedSignal(signal)`, `ReleaseX(...)`).
- Both sides acquire this module via `require()`, which Luau caches per-instance independent of Knit's lifecycle — `require()` resolution happens at the moment either side calls it, not gated by `KnitStart` order.
- Because the module is acquired via `require()` rather than `Knit.GetService()`, either side may call into it during its own `KnitInit` or `KnitStart` without needing the other service's `KnitStart` to have already run.
- This pattern is reserved for the live-subscription case; it is not a general substitute for Knit services, and must not be used to bypass Knit's own service/controller boundary for anything that Rule 1's plain `KnitInit`-construction already solves.

### Architecture Diagram

```
SERVER BOOT
  Phase 1 — KnitInit (all services, order unspecified)
    Every service constructs, for itself:
      - all BindableEvents/RemoteSignals other services might connect to
      - all RegistrationHandshake module slots it owns
      - all per-run state tables (even if empty at this point)
    NO service may assume another service's KnitInit has already run —
    only that ALL KnitInits complete before Phase 2 begins.

  Phase 2 — KnitStart (order UNDEFINED between services)
    Each service:
      - connects to already-KnitInit-constructed signals (safe, any order)
      - for the one live-registration case per pair of services:
          registers via the pair's RegistrationHandshake module (order-independent
          by construction — require() caching, not KnitStart sequencing)
    NO service may call another service's public Knit API (Knit.GetService(...):Method())
    from inside its own KnitStart and assume that service has finished booting its
    KnitStart-time connections — only KnitInit-constructed objects are guaranteed ready.

PLAYER JOIN (per-player, independent of server boot — Rules 1/2 do not apply;
  ordinary Knit service calls are safe once both services have completed KnitStart,
  which player-join always postdates)
```

### Key Interfaces

```luau
-- Every service that owns a cross-service-visible signal or accessor follows this shape.
-- PREFERRED: use Knit's bundled GC-free Signal class (RbxUtil), not Instance.new("BindableEvent") --
-- Signal:Fire() synchronicity is a plain-Luau-call guarantee, independent of Roblox's
-- Workspace.SignalBehavior property (which governs engine-dispatched events like BindableEvent
-- and has been drifting toward Deferred by default across Roblox releases — see Risks).

local Signal = require(ReplicatedStorage.Packages.Signal)

function SomeService:KnitInit()
    -- REQUIRED: constructed here, not KnitStart
    self._someChangedSignal = Signal.new()
    -- RegistrationHandshake modules are SERVER-ONLY — require() cache identity does not
    -- cross the client/server boundary, and must not be relied on to.
    self._registrationHandshake = require(script.Parent.SomeServiceRegistrationHandshake)
    self._registrationHandshake._bind(self)  -- module-private binding, not part of Client API
end

function SomeService:KnitStart()
    -- Safe: connecting to another service's KnitInit-constructed signal
    local other = Knit.GetService("OtherService")
    other:GetSomeSignal():Connect(function(...) ... end)

    -- Safe: registering via RegistrationHandshake (order-independent)
    local handshake = require(game.ServerScriptService.OtherServiceRegistrationHandshake)
    handshake.RegisterXChangedSignal(self._someChangedSignal)

    -- FORBIDDEN: calling another service's public method and assuming it has
    -- already completed KnitStart-time setup that isn't KnitInit-guaranteed.
end
```

## Alternatives Considered

### Alternative 1: Centralized post-KnitInit/pre-KnitStart bootstrap phase
- **Description**: Wrap `Knit.Start()` with a custom third lifecycle phase that runs after all `KnitInit`s complete but before any `KnitStart`, explicitly sequencing every known cross-service handshake in one authored order.
- **Pros**: Handshake ordering becomes explicit and centrally readable in one file.
- **Cons**: Requires forking/wrapping Knit's own `Start()` entry point (a maintenance burden against a framework this project does not want to fork); every new cross-service dependency requires editing the shared bootstrap file, which becomes a bottleneck and merge-conflict magnet as more services are added; does not match how Knit is documented or how other Knit projects are commonly structured, raising onboarding cost.
- **Rejection Reason**: Higher maintenance cost and framework-fighting for a problem the module-private `require()` pattern already solves with zero Knit modification.

### Alternative 2: Gate all cross-service reads on the whole `Knit.Start():andThen()` promise
- **Description**: Have every service defer any cross-service interaction until after `Knit.Start()`'s returned promise resolves (i.e., wait for the entire framework to finish starting, not just the specific dependency).
- **Pros**: Simple mental model — "nothing touches another service until everything is up."
- **Cons**: Does not solve the actual problem for the cases that motivated this ADR — ED's `OnPlayerDied` BindableEvent and HUD's mount Instances must exist and be connectable *during* other services' `KnitStart`, not after all of them finish; deferring everything to post-`Start()` would delay time-sensitive registration (e.g., PA's predator-lock registration) by an indeterminate amount and reintroduces a different race between "first player join" and "post-Start() callback fired."
- **Rejection Reason**: Solves a narrower problem than the one three GDDs already ran into, and doesn't cover the live-registration case at all.

## Consequences

### Positive
- One documented rule, cited by ED, PA, and HUD's GDDs, instead of three independently-reasoned-about workarounds — new systems (RunController, Camera, Save/Load) inherit the rule instead of re-deriving it.
- No modification to Knit itself — the pattern uses only `KnitInit`/`KnitStart` and standard Luau `require()` caching, both already part of the confirmed stack.
- Directly closes the "Cluster-1" race conditions ED's own GDD identified (B-CC1-A through B-CC1-E) by generalizing the fix ED already designed, rather than treating it as ED-specific.

### Negative
- Adds a small amount of ceremony: services must remember to construct cross-service-visible objects in `KnitInit` even when it would be more natural (in a non-Knit codebase) to construct them lazily in `KnitStart` or on first use.
- The RegistrationHandshake pattern is a second cross-service communication idiom alongside Knit's own service/controller pattern — contributors must learn when to use which (Rule 2 applies only to the live-registration case; everything else is Rule 1 plain `KnitInit` construction, or an ordinary Knit service/signal call in `KnitStart`).

### Risks
- **`require()`-based module-private singleton reliability is unverified against the pinned Roblox/Knit build** (flagged HIGH RISK in `docs/architecture/architecture.md`). If `require()` does not return the identical cached table instance to both sides in every code path (e.g., if a service is required from two different script contexts that don't share the same module cache), the entire RegistrationHandshake mechanism silently breaks. **Mitigation**: spike this in Studio before Foundation-layer implementation begins — write a minimal two-ModuleScript `require()` round-trip and confirm identity equality.
- **`BindableEvent:Fire` synchronous-dispatch guarantee is unverified, and is governed by the `Workspace.SignalBehavior` property (`Default`/`Immediate`/`Deferred`)** (also flagged HIGH RISK). Roblox has been drifting the ecosystem default toward `Deferred` dispatch across recent releases — a live-platform risk this ADR must name explicitly, not just treat as an empirical one-time test. ED's `OnPlayerDied` fan-out and its H.39e CI lint assume zero-yield, registration-order synchronous dispatch. **Mitigation (revised, gameplay-programmer engine-specialist review 2026-07-06)**: prefer Knit's bundled GC-free `Signal` class (RbxUtil) over raw `Instance.new("BindableEvent")` wherever this ADR's patterns are implemented — `Signal:Fire()` synchronicity is a plain-Luau-call guarantee, independent of `Workspace.SignalBehavior` entirely, and eliminates this risk rather than merely mitigating it. Where a raw `BindableEvent` is still used (e.g., existing GDD text that predates this ADR), the Studio spike must explicitly check and pin `Workspace.SignalBehavior`, not just empirically test dispatch order once.
  - **Carve-out, fixed 2026-07-06 (`/architecture-review` re-verification)**: `OnPlayerDied` specifically stays a raw `BindableEvent`, not `Signal` — ED's own GDD (C.1.11, round-11 BLOCK-3/red-team I-3 closure) already froze this as a literal `BindableEvent` with its yield-free correctness proofs argued from that exact mechanism, before this ADR existed. This ADR's general "prefer Signal" guidance governs *new* channels going forward; it does not silently override an already-closed GDD decision. ADR-0004 pins `Workspace.SignalBehavior = Enum.SignalBehavior.Immediate` at boot for this specific channel, per this ADR's own fallback stated above — see ADR-0004's dedicated Decision subsection.
- **Parallel Luau / `Actor` boundary risk** (identified by gameplay-programmer engine-specialist review 2026-07-06): `require()` module-cache identity is scoped per Luau execution context. If any Foundation/Core service is later moved into an `Actor` for parallel execution, `require()`-ing the same ModuleScript from inside that Actor returns a *separate* cached table from the main serial context, silently breaking the RegistrationHandshake singleton assumption with no error. **Mitigation**: RegistrationHandshake modules must only be `require()`d from the default serial script context; this constraint is binding, not advisory, until/unless a future ADR explicitly re-examines parallel Luau adoption.
- A contributor unfamiliar with this ADR could still write `KnitStart`-time construction of a cross-service-visible object; nothing except code review currently catches this mechanically. **Mitigation**: `docs/architecture/control-manifest.md` (once generated by `/create-control-manifest`) should encode this as a Foundation-layer Required/Forbidden rule so it's checked at story-review time, not just ADR-read time.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| ecological-disturbance.md | RegistrationHandshake module-private `require()` pattern for ED↔PA cross-service wiring (C.1.x, Boundary 2); `OnPlayerDied` BindableEvent constructed during `KnitInit` | Generalizes ED's bespoke pattern into the project-wide Rule 2; Rule 1 states the `KnitInit`-construction requirement ED's GDD already assumed |
| predator-ai.md | Consumes ED's RegistrationHandshake for predator-lock registration without re-deriving the ordering problem | Rule 2 is now the named, documented mechanism PA's GDD can cite instead of assuming ED's private design |
| hud.md | CR.9 — mount Instances (gather-ring, emote-wheel) must be constructed during `KnitInit`, never `KnitStart` | Rule 1 directly covers this; HUD's CR.9 becomes an instance of the general rule rather than a HUD-specific one |

## Performance Implications
- **CPU**: Negligible — `require()` caching and `KnitInit`-time construction cost is one-time at server boot, not per-frame.
- **Memory**: Negligible — no additional objects beyond what each service would construct regardless; only the *timing* of construction changes, not the count.
- **Load Time**: Negligible — server boot already runs all `KnitInit`s before any gameplay begins; no player-facing load-time impact.
- **Network**: None — this is a server-internal lifecycle discipline; no network surface is touched.

## Migration Plan
No migration — no service code has been implemented yet (project is in Technical Setup, pre-implementation). This ADR is the baseline every Foundation/Core service is written against from the start, not a retrofit.

## Validation Criteria
- A Studio spike (see Risks above) confirms `require()` module-instance identity and `BindableEvent:Fire` synchronous-dispatch ordering before any Foundation-layer service is implemented.
- Code review for every new service checks: (a) no cross-service-visible object is constructed inside `KnitStart`, (b) any live cross-service registration uses a RegistrationHandshake module, not a direct `Knit.GetService()` call assuming boot order.
- Once `/create-control-manifest` runs, this rule appears as an explicit Foundation-layer Required/Forbidden entry, checked at `/story-done` time.

## Related Decisions
- `docs/architecture/architecture.md` — Data Flow → Flow 4 (Initialization Order) and Architecture Principle #3 state this rule in prose; this ADR is its formal record.
- Enables ADR-0002 (RunController Architecture) and the future DisturbanceService Core Architecture and Death & Respawn Lifecycle ADRs, all of which assume this ordering discipline is settled.
- `design/gdd/ecological-disturbance.md` (RegistrationHandshake origin), `design/gdd/hud.md` (CR.9), `design/gdd/predator-ai.md` (consumer).
