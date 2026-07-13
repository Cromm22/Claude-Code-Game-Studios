# Architecture Traceability Index

Last Updated: 2026-07-06 (re-verification pass — ADR-0009..0014)
Engine: Roblox Studio (live platform) + Luau + Knit + Rojo

## Coverage Summary

- Total requirements: 269
- Covered: 108 (40.1%)
- Partial: 70 (26.0%)
- Gap: 91 (33.8%)

Per-system breakdown, engine-specialist findings, cross-document conflicts, and the
verdict live in `docs/architecture/architecture-review-2026-07-06.md` — this file
is the full matrix only. Rows changed in this pass are marked `[UPDATED]` in their
ADR Coverage cell.

---

## Player Controller (`design/gdd/player-controller.md`) — 29 / 12 / 12 (53 total)

| TR-ID | Requirement | Domain | ADR Coverage | Status |
|---|---|---|---|---|
| TR-pc-001 | Locomotion driver is `Humanoid.WalkSpeed`; server sets `WALK_SPEED=12`/`SPRINT_SPEED=20` on S1↔S2 transitions | Locomotion | ADR-0003 | ✅ |
| TR-pc-002 | Per-platform sprint binding (touch toggle / KB+M hold / gamepad L3-hold) via `UserInputService`+`ContextActionService` | Input | — | ❌ |
| TR-pc-003 | Jump enabled mid-sprint; pulse timers are server-clock interval-based, never reset-on-interrupt (bunny-hop precluded) | Locomotion | ADR-0003 (Humanoid jump only) | ⚠️ |
| TR-pc-004 | Sprint-state authority model: server-gated T1/T2, forced-walk at 0 stamina, sprint input ignored until stamina>0 | Locomotion | ADR-0011 — the ADR's sample code had an unrelated clock-seam violation (review report Conflict #7), fixed same session [UPDATED] | ✅ |
| TR-pc-005 | Server-authoritative stamina: `STAMINA_MAX=100`, drain 12.5/s, regen 10/s, `REGEN_DELAY=1.5s`, ticked on `RunService.Heartbeat` | Stamina | ADR-0011 [UPDATED] | ✅ |
| TR-pc-006 | `OnStaminaChanged` pushed ≤5 Hz to owning client only; client never gates input | Stamina/Bandwidth | ADR-0008, ADR-0006 | ✅ |
| TR-pc-007 | Lantern axis (S3a/S3b); Light publishes on server-authoritative `lanternRaised` set by `RequestLanternToggle` validation | Lantern | ADR-0004 (Emit), ADR-0006 | ✅ |
| TR-pc-008 | Light-to-gather gate: dual radii, coupled-knob config validation, server-authoritative dark-zone classification | Lantern/Gather | — (RN-owned, mock seam) | ❌ |
| TR-pc-009 | Mid-gather lantern-lower cancels in-progress gather server-side | Gather | — | ❌ |
| TR-pc-010 | PC publishes Sprint & Light emissions via `DisturbanceService:Emit(type, position, magnitude, sourcePlayerId)` | Emission | ADR-0004 | ✅ |
| TR-pc-011 | Emission position = server-observed `HumanoidRootPart.Position`; client-predicted positions forbidden | Emission | ADR-0004, ADR-0008 | ✅ |
| TR-pc-012 | Pulse cadence, `FIRST_PULSE_GRACE_WINDOW`, `GRACE_REENTRY_COOLDOWN`, magnitude attenuation, `SPRINT_HOLD_FLOOR` | Emission | — | ❌ |
| TR-pc-013 | Clock-injection seam (`getServerTime()` DI); inline `workspace:GetServerTimeNow()` forbidden + CI grep gate | Testability | — (ADR-0005 sample violates this) | ❌ |
| TR-pc-014 | Mobile analog-drift threshold; XZ interval displacement sampling | Emission/Input | — | ❌ |
| TR-pc-015 | Sprint-pulse flora micro-pulse (ED render-side response) | Emission | — | ❌ |
| TR-pc-016 | Death moment via `DisturbanceService:GetOnPlayerDiedSignal()` — not a direct `Humanoid.Died` subscription | Death | ADR-0004 | ✅ |
| TR-pc-017 | Server-authoritative `RESPAWN_DELAY=30s` timer at `Humanoid.Died`; idempotent guard | Death | ADR-0005 | ✅ |
| TR-pc-018 | Oxygen deduction via `RequestSquadOxygenSpend` — server-internal, idempotent per `(userId, deathEventId)` | Death | ADR-0005 | ✅ |
| TR-pc-019 | `DeathCostReconciliation` state machine (Pending/InFlight/Committed/Abandoned) w/ post-yield re-check | Death | ADR-0005 | ✅ |
| TR-pc-020 | `deathEventId` = PC-minted monotonic per-session counter; record survives T6 | Death | ADR-0005 | ✅ |
| TR-pc-021 | Reconciliation tick on Heartbeat every 5s; staleness-sweep re-arm | Death | ADR-0005 (sweep interval Open Question) | ⚠️ |
| TR-pc-022 | Path B `PlayerRemoving` imminent-death predicate; cross-service teardown-order race | Death | ADR-0005 (predicate/ordering unresolved) | ⚠️ |
| TR-pc-023 | `OXYGEN_GRACE_DURATION=5s`, PC-owned, squad-wide; hard config error <2s | Death | ADR-0005 (C4 + R7c-I4) | ✅ |
| TR-pc-024 | `OnPlayerOxygenExpired()` argument-less, squad-wide RM→PC trigger | Death | ADR-0005 (arity not specified) | ⚠️ |
| TR-pc-025 | T5 pre-yield side-effect ordering (`ReleasePredatorLock`/`OnPlayerS4Entered`/`OnSquadMemberAliveChanged`) | Death | ADR-0004/0005 (ordering discipline not) | ⚠️ |
| TR-pc-026 | T7 whole-squad-wipe raises `RunController:RunEndConditionRaised("wipe", squadState)` | Run-lifecycle | ADR-0002 | ✅ |
| TR-pc-027 | T8 victory raises `("victory", …)`; victory-over-wipe precedence | Run-lifecycle | ADR-0002 | ✅ |
| TR-pc-028 | `RUN_END_DEFEAT_HOLD` 0.5s arbiter hold window | Run-lifecycle | ADR-0002 (hold window not modeled) | ⚠️ |
| TR-pc-029 | `_beaconActivated` latch cleared on `RunEnded` or `BEACON_LATCH_TIMEOUT` self-heal | Run-lifecycle | ADR-0002 (RunEnded clear only) | ⚠️ |
| TR-pc-030 | PC subscribes to `RunEnded(outcome)`; drives S4→S5 + input lock; idempotent | Run-lifecycle | ADR-0002 | ✅ |
| TR-pc-031 | Oxygen-gated respawn wait: T6 withheld if pool<1 | Death | ADR-0005 (T6 covered; withhold not) | ⚠️ |
| TR-pc-032 | Sprint hard-reset on death; respawn spawns S1 with stamina=MAX | Death | ADR-0005 (general lifecycle) | ⚠️ |
| TR-pc-033 | Spectator camera + StreamingEnabled chunk-load guard; dead-player experience | Death/Camera | ADR-0012 — closes GDD OQ.4; `HasChunkLoaded()` confirmed fictitious, replaced with `Model.ModelStreamingMode`/`Player.ReplicationFocus` [UPDATED] | ✅ |
| TR-pc-034 | Dead-player input state guards (`RequestPing` rejected S4/S5, `renderScope` server-minted) | RemoteEvent | ADR-0006 | ✅ |
| TR-pc-035 | Client-fired RemoteEvent canonical validation, drop-first (no state mutation on reject) | RemoteEvent | ADR-0006 | ✅ |
| TR-pc-036 | Per-player global RemoteEvent budget | RemoteEvent | ADR-0006 | ✅ |
| TR-pc-037 | Server-pushed-only events register zero `OnServerEvent` callbacks | RemoteEvent | ADR-0006 | ✅ |
| TR-pc-038 | Ping: server re-runs raycast, origin within tolerance of server position | RemoteEvent | ADR-0006 | ✅ |
| TR-pc-039 | `PlayerHeartbeat` S2-only 1Hz; `SPRINT_CLIENT_TIMEOUT=3s` ghost-sprint force-revert | RemoteEvent/Locomotion | ADR-0006, ADR-0011 (ghost-sprint watchdog implements the 3s timeout) [UPDATED] | ✅ |
| TR-pc-040 | PredatorService-owned `lastPredatorDamageTimestamp`+`predatorCausedImminent` latch | Cross-service | — | ❌ |
| TR-pc-041 | PredatorService S4 lifecycle pair `OnPlayerS4Entered`/`OnPlayerT6Respawned` | Cross-service | — | ❌ |
| TR-pc-042 | `PredatorService:ReleasePredatorLock(player)` idempotent | Cross-service | ADR-0004, ADR-0005 | ✅ |
| TR-pc-043 | `OnSquadMemberAliveChanged(playerId, isAlive)` server-internal edge to Crafting | Cross-service | ADR-0005 (arity unspecified) | ⚠️ |
| TR-pc-044 | Server-tracked `HumanoidRootPart.Position` is PA's perception input; no client-predicted positions | Cross-service/Net | ADR-0008/0003 | ⚠️ |
| TR-pc-045 | `KnitInit` builds cross-service signals + bootstrap tables; `KnitStart` connects | Lifecycle | ADR-0001 | ✅ |
| TR-pc-046 | `KnitInit` config-validation hard-error requires `game:Shutdown()` bootstrap catch | Lifecycle | ADR-0005 | ✅ |
| TR-pc-047 | Player characters default automatic `NetworkOwnership` | Networking | ADR-0008 | ✅ |
| TR-pc-048 | Character-replication bandwidth baseline; PC signal budget within <50 KB/s | Networking | ADR-0008, ADR-0006 | ✅ |
| TR-pc-049 | Emote slots cosmetically replaceable; no cosmetic may alter gameplay values | Persistence | ADR-0007 | ✅ |
| TR-pc-050 | Tap-hold gather 500ms wall-clock; gather ring only client-predicted UI | Input | ADR-0006/0008 (wall-clock/ring not) | ⚠️ |
| TR-pc-051 | Two-finger ping gesture detection (`PING_TWO_FINGER_WINDOW=150ms`) | Input | — | ❌ |
| TR-pc-052 | `HapticService` rumble wrapped in `IsMotorSupported()` guard | Input | — | ❌ |
| TR-pc-053 | C.12 contract-completeness CI hook | Tooling/CI | — | ❌ |

## Resource Management (`design/gdd/resource-management.md`) — 14 / 7 / 7 (28 total)

| TR-ID | Requirement | Domain | ADR Coverage | Status |
|---|---|---|---|---|
| TR-rm-001 | Pool is a single server-side scalar, owned exclusively by `ResourceService`, clamped `[0, OXYGEN_POOL_START]` | Data model | ADR-0005 sketch only | ⚠️ |
| TR-rm-002 | Clients get read-only server-authoritative projection — never a write handle | Networking/trust | ADR-0006 general boundary only | ⚠️ |
| TR-rm-003 | Client dead-reckons `P_displayed`; sync payload carries `P` + current `drainRate`/band | Networking | — | ❌ |
| TR-rm-004 | Discrete events `OnOxygenDeducted`/`OnOxygenRestored` carry authoritative `P_after` | Networking | — | ❌ |
| TR-rm-005 | Latency-pop bound: events carry `serverSendTime`; client latency-projects before adopting | Networking/latency | — | ❌ |
| TR-rm-006 | Per-band drain keyed to Beacon Charge Tier; RM reads band from ED accessor each tick | Cross-system read | ADR-0009 — accessor lives on `CraftingService`, not ED [UPDATED] | ✅ |
| TR-rm-007 | Fail-safe: if BCT accessor nil, default to BC1 for that tick | Cross-system resilience | ADR-0009 [UPDATED] | ✅ |
| TR-rm-008 | 60Hz Heartbeat per-tick deterministic order (deductions → restores → drain) | Timing/determinism | ADR-0010 [UPDATED] | ✅ |
| TR-rm-009 | `MAX_TICK_DT=0.1s` cap + non-negative dt guard | Timing | ADR-0010 [UPDATED] | ✅ |
| TR-rm-010 | Death-cost deduction: `RequestSquadOxygenSpend(...)` server-internal, idempotent per `(userId,deathEventId)` | Death/cost | ADR-0005 (param-order drift vs RM text) | ✅ |
| TR-rm-011 | Idempotency write-before-throwable-work | Idempotency | ADR-0005 | ✅ |
| TR-rm-012 | `deathEventId` PC-owned, session-lifetime-unique; RM treats as opaque | Cross-service contract | ADR-0005 | ✅ |
| TR-rm-013 | Run-end race guard: spend rejected once run ended; dedup-set cleared at run end | Run lifecycle | ADR-0002/0005 (specific ordering not) | ⚠️ |
| TR-rm-014 | Respawn carries no RM charge; PC owns `RESPAWN_DELAY=30s` | Death lifecycle | ADR-0005 | ✅ |
| TR-rm-015 | Canister faucet `OnOxygenPulseRequest` fire-and-forget server-internal Knit Signal | Cross-service/security | ADR-0001/0006 general only | ⚠️ |
| TR-rm-016 | Squad-wide oxygen state machine (Healthy/Critical/Empty) w/ hysteresis | State machine | — | ❌ |
| TR-rm-017 | Empty→death cascade: `OnPlayerOxygenExpired()` argument-less squad-wide broadcast | Cross-service death trigger | ADR-0005, ADR-0010 — arity confirmed argument-less, fired exactly once at Empty entry [UPDATED] | ✅ |
| TR-rm-018 | Oxygen-empty grace timer: `OXYGEN_GRACE_DURATION=5s`, PC-owned; hard-error <2.0s | Death/config-validation | ADR-0005 C4 + R7c-I4 | ✅ |
| TR-rm-019 | DP-2 death-cost ratio init assertion, fail-fast | Config-validation | ADR-0005 halt mechanism only | ⚠️ |
| TR-rm-020 | Other fail-fast init fences (cross-GDD constant dependencies) | Config-validation | ADR-0005 halt mechanism only | ⚠️ |
| TR-rm-021 | `RequestSquadOxygenSpend` structurally server-internal, no client-callable endpoint | Security/trust | ADR-0005, ADR-0006, ADR-0002 | ✅ |
| TR-rm-022 | HUD signal surface: `OnOxygenChanged`/`OnOxygenStateChanged`/deducted/restored | Networking/presentation | — | ❌ |
| TR-rm-023 | Sync bandwidth: `OXYGEN_SYNC_HZ=2` delta-suppressed push, fits <50 KB/s | Bandwidth | ADR-0008 (aggregate only) | ⚠️ |
| TR-rm-024 | Same-tick death coalescing to a single `OnOxygenDeducted` with applied count | Death path/presentation | ADR-0005, ADR-0010 (step 2 coalesces multiple same-tick deductions into one event) [UPDATED] | ✅ |
| TR-rm-025 | Anti-idle/anti-camping RM×ED jointly-owned invariant | Cross-system balance | — | ❌ |
| TR-rm-026 | Beacon-survival win-check evaluated before `OnPlayerOxygenExpired` on boundary tick | Cross-system win-condition ordering | ADR-0010 (step 5 before step 6, per H.49) [UPDATED] | ✅ |
| TR-rm-027 | D1 2-player BC4 last-stand kill-criterion, analytics segmentation | Balance/analytics/run-end | ADR-0005, ADR-0002 | ✅ |
| TR-rm-028 | Player disconnect: no oxygen charged; flat-headcount drain unchanged | Lifecycle edge | — | ❌ |

## Resource Node (`design/gdd/resource-node.md`) — 4 / 8 / 19 (31 total)

| TR-ID | Requirement | Domain | ADR Coverage | Status |
|---|---|---|---|---|
| TR-rn-001 | `NodeRecord` server-side data structure | Data structure | — | ❌ |
| TR-rn-002 | Node enumeration at boot via `CollectionService` tag; server-resident regardless of StreamingEnabled | Engine/init | — | ❌ |
| TR-rn-003 | Per-tier config constants data-driven, not hardcoded | Config/data | — | ❌ |
| TR-rn-004 | Server arm-scan loop @ `ARM_SCAN_HZ=10` via `task.wait` loop | Threading/timing | — | ❌ |
| TR-rn-005 | All-pairs proximity distance² test; explicit no-spatial-grid choice | Perf/data structure | — (unreviewed vs ED's spatial-hash choice) | ❌ |
| TR-rn-006 | Two decoupled arm records + arm/disarm hysteresis | State/data | — | ❌ |
| TR-rn-007 | `RequestGather` sole client event; server-side validation order & re-derivation | Networking/trust | ADR-0006 | ✅ |
| TR-rn-008 | Per-player rate limit 1/1.5s sustained, burst 2/3s | Networking | ADR-0006 | ✅ |
| TR-rn-009 | Teleport-delta sanity + position-spoof hardening (OQ.10 per-gather ownership) | Networking/authority | ADR-0006/0008 (per-gather ownership lever unadopted) | ⚠️ |
| TR-rn-010 | Non-yielding critical section for lock check-and-set | Concurrency | — (ADR-0001 scopes zero-yield to KnitInit/cross-service only) | ❌ |
| TR-rn-011 | Alive/not-dead-respawning guard on `RequestGather` | Trust/state | ADR-0006 | ✅ |
| TR-rn-012 | Extraction/respawn/safety-valve timers on a mockable scheduling interface | Testing arch | — | ❌ |
| TR-rn-013 | Node-count config gates asserted at `KnitInit` via `error()` | Config validation | ADR-0005 halt mechanism; content RN-owned | ⚠️ |
| TR-rn-014 | `HEAVY_NODE_MIN_RESPAWN_STAGGER=15s` enforced at server-init | Config validation/a11y | ADR-0005 mechanism only | ⚠️ |
| TR-rn-015 | Dark-zone node spacing floor; couples to PC DC-5 lantern/dark-zone | Level-design/cross-system | — | ❌ |
| TR-rn-016 | `OnNodeStateChanged` broadcast + client per-node last-state buffering | Networking/replication | ADR-0006 (server-pushed-only rule only) | ⚠️ |
| TR-rn-017 | `OnNodeFullStateSnapshot` join/respawn bootstrap | Networking/replication | ADR-0006 (generalized rule only) | ⚠️ |
| TR-rn-018 | `Gathering` payload carries duration+start timestamp for drift-free HUD progress | Timing/replication | — | ❌ |
| TR-rn-019 | T1–T7 node state machine, synchronous non-yielding resolve ordering | State machine/concurrency | — | ❌ |
| TR-rn-020 | Respawn via `task.delay` + per-node `generationToken` invalidation | Timing/state | — | ❌ |
| TR-rn-021 | Same-tick run-end race: RN subscribes to `RunEnded` to drive `ResetAllNodes` | Cross-system lifecycle | ADR-0002 | ✅ |
| TR-rn-022 | Safety-valve force-release (lock-age timeout) | State/reliability | — | ❌ |
| TR-rn-023 | `DisturbanceService:Emit("Gather", ...)` publisher call, non-yielding, emit-before-grant | Cross-system/ED | ADR-0004 (Emit not enumerated) | ⚠️ |
| TR-rn-024 | `OnGatherCompleted(...)` → Crafting; single inventory write path | Cross-system | — | ❌ |
| TR-rn-025 | PC player-death signal consumed by RN's T4 mid-extract release | Cross-system/death | ADR-0005 (RN not a listed OnPlayerDied consumer) | ⚠️ |
| TR-rn-026 | Lantern-raised/`isDarkZone` accessor (PC-owned) for dark-zone gather validation | Cross-system | — | ❌ |
| TR-rn-027 | `canisterCycleTime>9.09s` floor + BC3 supply bound at `KnitInit` | Config validation/balance | ADR-0005 mechanism; content RN-owned | ⚠️ |
| TR-rn-028 | `MAX_NODE_POINTLIGHTS_IN_FRUSTUM=4` dynamic-light budget + LOD | Perf/rendering | — | ❌ |
| TR-rn-029 | Mobile perf budget (iPhone-SE 30fps) | Perf | — | ❌ |
| TR-rn-030 | Aggregate completion-flash WCAG 2.3.1 ≤3/s gating | Accessibility/cross-system | — | ❌ |
| TR-rn-031 | Cross-input parity + persistent tether/commit-confirm render | UI/UX | — | ❌ |

## Ecological Disturbance (`design/gdd/ecological-disturbance*.md`) — 33 / 17 / 22 (72 total)

| TR-ID | Requirement | Domain | ADR Coverage | Status |
|---|---|---|---|---|
| TR-ed-001 | Table-of-tables spatial hash grid (32-stud cells, 3×3 neighborhood scan) | DS | ADR-0004 | ✅ |
| TR-ed-002 | Two-store model: live-source list + write-once attribution archive | DS | ADR-0004 | ✅ |
| TR-ed-003 | `EmissionPayload` fixed 7-field record, no optional fields | DS | ADR-0006 generic only | ⚠️ |
| TR-ed-004 | `HotspotResult` exactly-6-field non-optional return; stable `hotspotId` | DS | ADR-0004 (fields not enumerated) | ⚠️ |
| TR-ed-005 | Published payload types (Meter/Alert/DeathAttribution/OnPlayerDied) | DS | ADR-0004 N4/N6 partial | ⚠️ |
| TR-ed-006 | Per-player XZ ring buffer for stationary integral | DS | — | ❌ |
| TR-ed-007 | Per-beacon `BeaconCapEvalEntry` cache | DS | — | ❌ |
| TR-ed-008 | Server-side `loadedChunks[player]` membership set, server-computed only | DS | ADR-0004 N1 | ✅ |
| TR-ed-009 | Per-player per-flora last-pushed-t cache | DS | ADR-0004 N2/N9 | ✅ |
| TR-ed-010 | `_capCueDecayPassesRemaining` cadence-derived decay counter | DS | — | ❌ |
| TR-ed-011 | `previousTierAtPosition` keyed by canonical string | DS | ADR-0004 N11 (different table) | ⚠️ |
| TR-ed-012 | `_deathLockSnapshot` single-writer mailbox | DS | ADR-0004 N10 | ✅ |
| TR-ed-013 | Predator-lock registry = single source of truth | DS | ADR-0004 | ✅ |
| TR-ed-014 | `DisturbanceService_Update` budget ≤1.43ms avg / 2.86ms p99 | Perf | ADR-0004 (budget not ratified) | ⚠️ |
| TR-ed-015 | `DisturbanceService_HotspotQuery` ≤1ms avg / 2ms p99 | Perf | ADR-0004 (budget GDD-only) | ⚠️ |
| TR-ed-016 | Two `debug.profilebegin` fences | Perf | — | ❌ |
| TR-ed-017 | Per-source decay caching (`m(age)` evaluated ≤once/source/pass) | Perf | — | ❌ |
| TR-ed-018 | Forbidden transcendentals in inner loop | Perf | — | ❌ |
| TR-ed-019 | `MAX_LIVE_SOURCES=500` hard cap + cap-hit policy | Perf | ADR-0004 Q3 — **CONFLICT: ADR evicts oldest, GDD drops new** | ⚠️ |
| TR-ed-020 | Attribution archive count cap `MAX_ATTRIBUTION_ARCHIVE_ENTRIES=4000` | Perf/SP | ADR-0004 | ✅ |
| TR-ed-021 | Cap-formula full live-source scan measured inside stress budget | Perf | — | ❌ |
| TR-ed-022 | Query-position count anchoring | Perf | — | ❌ |
| TR-ed-023 | PERF-DEVICE budgets valid only at `FIELD_UPDATE_HZ=5` and `activeBeacons≤3` | Perf | — | ❌ |
| TR-ed-024 | Memory ceiling <1GB; session-scoped field discarded at run-end | Perf/SP | ADR-0007, ADR-0008 | ⚠️ |
| TR-ed-025 | Canonical clock `workspace:GetServerTimeNow()`; other clocks forbidden on emission path | Eng | — | ❌ |
| TR-ed-026 | 5Hz field-update loop on Heartbeat w/ accumulator + graceful-skip catch-up | Eng/T-T | ADR-0004 | ✅ |
| TR-ed-027 | `emissionId` via `HttpService:GenerateGUID(false)`, server-side only | Eng/Net | — | ❌ |
| TR-ed-028 | Knit `DisturbanceService`+`DisturbanceController`; 3 `.Client` RemoteSignals | Eng/XSC | ADR-0004, ADR-0006 | ✅ |
| TR-ed-029 | Two raw RemoteEvents `FloraChunkUpdate`/`FloraChunkInitialSnapshot`, server-fire-only | Eng/Net | ADR-0004 N5, ADR-0006 | ✅ |
| TR-ed-030 | Server-internal `OnPlayerDied` BindableEvent, synchronous, KnitInit-constructed | Eng/XSC | ADR-0001/0004/0005 (type tension w/ Signal recommendation) | ✅ |
| TR-ed-031 | StreamingEnabled chunk-load detection; `ReplicationFocus` forbidden | Eng | ADR-0004 N1 | ✅ |
| TR-ed-032 | `Humanoid.Died` sole subscriber, registered in KnitInit, CI-enforced | Eng/Net | ADR-0004/0005 — **CONFLICT: diagram shows KnitStart** | ✅ |
| TR-ed-033 | `Character.PrimaryPart` nil-guard before `.Position` on ring-buffer writes | Eng | ADR-0003 (analogous guard, not this one) | ⚠️ |
| TR-ed-034 | Predator nav via `PathfindingService:FindPathAsync`; ED supplies targets only | Eng/XSC | ADR-0003, ADR-0004 | ✅ |
| TR-ed-035 | HUD meter tween client-side; server pushes only `targetT` scalars | Eng | — | ❌ |
| TR-ed-036 | `KnitInit` config-validation fatal error (H.3d/H.3e) | Eng/T-T | ADR-0005 R7c-I4 | ✅ |
| TR-ed-037 | Server-internal `TierCrossedEvent` (position-keyed, coalesced) | XSC | — | ❌ |
| TR-ed-038 | Server-internal `OnDisturbanceBandCrossed` squad-aggregate signal | XSC | — | ❌ |
| TR-ed-039 | `OnPredatorStateChanged` subscribed for defense-in-depth lock purge | XSC | ADR-0004, ADR-0001 | ✅ |
| TR-ed-040 | `RegisterPredatorLock`/`ReleasePredatorLock`, merge-on-reregister, 5s grace | XSC | ADR-0004 | ✅ |
| TR-ed-041 | Module-private `RegistrationHandshake.luau`, exactly 5 exports | XSC | ADR-0001, ADR-0004 | ✅ |
| TR-ed-042 | Register-time-subscribe pattern; KnitStart getters-before-setter order | T-T/XSC | ADR-0001, ADR-0004 | ✅ |
| TR-ed-043 | `Emit(emissionType, position, magnitude, sourcePlayerId)` server-internal publisher | XSC/Net | ADR-0006 general only (Emit signature not ADR'd) | ⚠️ |
| TR-ed-044 | `GetOnPlayerDiedSignal(): BindableEvent` single death channel | XSC/T-T | ADR-0004, ADR-0005 | ✅ |
| TR-ed-045 | `GetSquadAggregateT(excludePlayer: Player?): number` exclusion-form semantics | XSC | ADR-0004 | ✅ |
| TR-ed-046 | `GetHottestHotspot(callerPosition, searchRadius, minimumTier)` | XSC | ADR-0004 | ✅ |
| TR-ed-047 | Cross-GDD constant locks (tiers, hysteresis, half-lives, `MAX_ACTIVE_BEACONS=3`) | XSC | — | ❌ |
| TR-ed-048 | Attribution archive TTL, longest-of lifetime + fenced purge | SP | ADR-0004 (TTL-purge deferred) | ⚠️ |
| TR-ed-049 | Session-scoped field, no cross-run persistence | SP | ADR-0007 | ✅ |
| TR-ed-050 | Sources persist server-side independent of StreamingEnabled; keyed by `emissionId` | SP/Net | ADR-0004 (implied only) | ⚠️ |
| TR-ed-051 | Lazy expiry; low-frequency maintenance cull pass | T-T | — | ❌ |
| TR-ed-052 | Yield-free single-Luau-frame death path | T-T | ADR-0004/0005/0001 | ✅ |
| TR-ed-053 | KnitInit/KnitStart ordering discipline | T-T | ADR-0001 | ✅ |
| TR-ed-054 | Post-hitch multi-tier cascade settle loop | T-T | — | ❌ |
| TR-ed-055 | Predator queries synchronous at PA's 4Hz; ED cadence-agnostic | T-T | ADR-0004 (implied) | ⚠️ |
| TR-ed-056 | Same-frame `Fire(false)`-before-`Fire(true)` ordering on lock pivot | T-T | ADR-0004 | ✅ |
| TR-ed-057 | iPhone SE-class binding performance + bandwidth floor | Plat | ADR-0008 (perf floor GDD-only) | ⚠️ |
| TR-ed-058 | Touch tap-toggle sprint → fairness telemetry | Plat | — | ❌ |
| TR-ed-059 | `BEACON_CUMULATIVE_DISTANCE_THRESHOLD` provisional pending measurement | Plat | — | ❌ |
| TR-ed-060 | StreamingEnabled chunk `CHUNK_DIMENSIONS=64×64` studs | Plat/Eng | ADR-0004 N1 | ✅ |
| TR-ed-061 | Server sole authority; emission data plain Luau tables, never Instance/Workspace | Net | ADR-0004, ADR-0007 | ✅ |
| TR-ed-062 | No client-callable `Emit()` path | Net | ADR-0006 | ✅ |
| TR-ed-063 | Zero client-callable RemoteFunctions across the whole system | Net | ADR-0006 | ✅ |
| TR-ed-064 | `ReplicationFocus` never trusted; `loadedChunks` sole snapshot authority | Net | ADR-0004 | ✅ |
| TR-ed-065 | Full server-side emission schema validation (reject NaN/Inf/out-of-enum) | Net | ADR-0006 generic step-4 only | ⚠️ |
| TR-ed-066 | Per-player targeted routing on 3 RemoteSignals (`:FireAll` forbidden) | Net | ADR-0004 (privacy mandate not explicit) | ⚠️ |
| TR-ed-067 | All test seams server-internal, never `.Client`, grep-verified | Net | — | ❌ |
| TR-ed-068 | Raw flora RemoteEvents register zero `OnServerEvent` callbacks | Net | ADR-0004 N5, ADR-0006 | ✅ |
| TR-ed-069 | CI BLOCKING lint gates are load-bearing architecture | Net/CI | ADR-0004/0005 call these "optional hardening" — **tension** | ⚠️ |
| TR-ed-070 | Stateful tier classification: hysteresis ±0.03 downward-only | DS/Algo | — | ❌ |
| TR-ed-071 | `squadT` = max over connected players + guards | DS/Algo | ADR-0004 | ✅ |
| TR-ed-072 | Beacon stationary-squad Hunt-floor cap | DS/Algo | — | ❌ |

**N1–N11 individual closure check (all 11 have a concrete ADR-0004 decision — see review report for detail)**: N1–N9, N11 closed; N10's mechanism is closed but its companion AC (`H.30d`) is explicitly deferred, not yet authored in the GDD.

## Predator AI (`design/gdd/predator-ai.md`) — 13 / 8 / 11 (32 total)

| TR-ID | Requirement | Domain | ADR Coverage | Status |
|---|---|---|---|---|
| TR-pa-001 | Exactly one server-authoritative predator instance/server; never despawns mid-run | Lifecycle | ADR-0002 (run-boundary only) | ⚠️ |
| TR-pa-002 | Server NetworkOwnership: `SetNetworkOwner(nil)`, re-assert on respawn | Networking | ADR-0008 | ✅ |
| TR-pa-003 | Field-only perception via ED accessors at 4Hz; no direct player-read bypass | Cross-system (ED) | ADR-0004 | ✅ |
| TR-pa-004 | ED must expose `GetSquadAggregateT(excludePlayer)` | Cross-system data contract | ADR-0004 | ✅ |
| TR-pa-005 | Raycast perception budget ≤16 rays/tick @4Hz | Performance/perception | — (prototype-gated, intentional) | ❌ |
| TR-pa-006 | `PREDATOR_AUDIO_RANGE > PREDATOR_VISUAL_RANGE` invariant; LOS required | Config invariant | — (prototype-gated, intentional) | ❌ |
| TR-pa-007 | Deterministic no-RNG targeting total order | Determinism/algorithm | ADR-0004 N11 (partial) | ⚠️ |
| TR-pa-008 | Player lock `argmin dist²`; reads server-authoritative HRP.Position | Cross-system (PC position) | ADR-0003, ADR-0008 | ✅ |
| TR-pa-009 | Lock re-eval single decision point, debounce persists across boundaries | State machine/timing | — (PA-internal) | ❌ |
| TR-pa-010 | Lock-clear owned solely by `ReleasePredatorLock` | Cross-system ownership | ADR-0004, ADR-0005 | ✅ |
| TR-pa-011 | `PredatorEncountered` analytics once/player/session | Session state/analytics | — (PA-internal) | ❌ |
| TR-pa-012 | Navmesh-bound movement, per-state WalkSpeed, startup config-gate | Movement/config | ADR-0003, ADR-0005 | ✅ |
| TR-pa-013 | Combat: melee+LOS Lunge, one-shot guard, cooldown, knockback | Combat formula | — (PA-internal) | ❌ |
| TR-pa-014 | Inter-callback `Health>1` guard for same-Heartbeat concurrent damage | Threading/timing | ADR-0005 (general, not this guard) | ⚠️ |
| TR-pa-015 | BC4 beacon-commit `max(actualBeaconT, 0.65)`; quiet→Disengage suppressed | Logic/state | — (PA-internal) | ❌ |
| TR-pa-016 | BC4 loseability cross-GDD constraint (O2 rate vs window duration) | Cross-system config gate | ADR-0005 (D1 covered; O2-vs-window gate open) | ⚠️ |
| TR-pa-017 | Two-channel publication: server-internal BindableEvent + client RemoteSignal, KnitInit-constructed | Networking architecture | ADR-0001, ADR-0006 | ✅ |
| TR-pa-018 | RegistrationHandshake push module, 5 exports, KnitStart strict ordering | Cross-service wiring | ADR-0001, ADR-0004 | ✅ |
| TR-pa-019 | Death attribution: top-3 `emissionId`s; eager `GetDeathAttributionPayload` | Cross-system data | ADR-0004 N6 | ✅ |
| TR-pa-020 | Deterministic 4-state FSM; state-exit nav-target + timer cancel | State machine | — (PA-internal) | ❌ |
| TR-pa-021 | HUD replication: bearing+distanceBand, per-client targeted fire @10–20Hz | Networking/bandwidth | ADR-0006, ADR-0008 (fan-out architecture not in either) | ⚠️ |
| TR-pa-022 | Telegraph + state-change ship as one combined RemoteEvent | Networking ordering | — | ❌ |
| TR-pa-023 | Pathfinding fallback: throttle, direct-locomotion fallback, stuck detection, stale-token | Pathfinding/threading | ADR-0003 (driver only; fallback deferred to ADR #12) | ⚠️ |
| TR-pa-024 | Float-determinism precision contract w/ ED (FIX 13/OQ.11) | Cross-system determinism | — (real gap, ED-freeze-timed) | ❌ |
| TR-pa-025 | ED must reserve dirty-flag/push-cache accessor path before interface freeze | Performance/cross-system | ADR-0004 (mitigates cost, doesn't reserve path) | ⚠️ |
| TR-pa-026 | PredatorService per-burst CPU ceiling ≤2ms p95 | Performance constraint | — (prototype-gated, intentional) | ❌ |
| TR-pa-027 | PC integration: kill→T5 death path; latch cleared on respawn/release/run-end | Cross-system (PC) | ADR-0005 | ✅ |
| TR-pa-028 | RunController `RunEnded` subscription: synchronous idempotent teardown | Cross-system lifecycle | ADR-0002 | ✅ |
| TR-pa-029 | Locomotion driver choice — Humanoid vs Character Controller Library (OQ.7) | Engine capability | ADR-0003 | ✅ |
| TR-pa-030 | Client-side cosmetic FSM from broadcast; rigged anims; eye-shine one-way gate | Client rendering/replication | — (Presentation, expected) | ❌ |
| TR-pa-031 | Cross-GDD config gates (audio/visual range, beacon-line-break grace) | Cross-system config | ADR-0005 mechanism only (values open, OQ.4) | ⚠️ |
| TR-pa-032 | Startup config-validation framework: hard error → `game:Shutdown()` | Config-validation infra | ADR-0005 | ✅ |

## Crafting & Items (`design/gdd/crafting-and-items.md`) — 11 / 11 / 3 (25 total)

| TR-ID | Requirement | Domain | ADR Coverage | Status |
|---|---|---|---|---|
| TR-craft-001 | Beacon activation opens survival window; victory fires only on window-survival — currently routed through PC, not RunController | Run lifecycle | ADR-0002 (migration deferred, not applied) | ⚠️ |
| TR-craft-002 | BCT-DEFEAT: `OnBeaconWindowFailed(reason ∈ {"scatter","wipe"})` | Run lifecycle | ADR-0002 (enum can't represent "scatter"; stale C.5.8 cite) | ⚠️ |
| TR-craft-003 | `runOutcomeResolved` idempotent terminal latch, ≥2 firing paths | Concurrency | ADR-0002 `_hasEnded` is the analogue; Crafting keeps a parallel latch | ⚠️ |
| TR-craft-004 | CraftingService subscribes to `RunEnded` to latch `runOutcomeResolved` | Run lifecycle | ADR-0002 | ✅ |
| TR-craft-005 | Survival-window timer: per-Heartbeat `_clock()` comparison, never `task.delay` | Threading/timing | ADR-0013 — originally used an inline `workspace:GetServerTimeNow()` call instead of the `_clock()` seam (review report Conflict #8), fixed same session [UPDATED] | ✅ |
| TR-craft-006 | CraftingService must not subscribe to `Humanoid.Died` directly | Cross-system events | ADR-0004, ADR-0005 | ✅ |
| TR-craft-007 | Death/departure callback body yield-free; buffered drain in `_step` | Threading/timing | ADR-0001 partial (H.80 handler-body rule otherwise domain) | ⚠️ |
| TR-craft-008 | Publisher contract: `DisturbanceService:Emit("Beacon"\|"Craft", ...)` | Cross-system events | ADR-0004 (Emit signature not enumerated) | ⚠️ |
| TR-craft-009 | `MAX_ACTIVE_BEACONS=3` enforced at Crafting publish site before Emit | Cross-system/capacity | — | ❌ |
| TR-craft-010 | `RequestCraft`/`RequestBeaconActivate` client→server, rate-limited, silent-drop | Networking/trust | ADR-0006 | ✅ |
| TR-craft-011 | 5 further client-fired events awaiting ADR reconciliation | Networking/trust | ADR-0006 pattern (events not individually enumerated) | ⚠️ |
| TR-craft-012 | Crafting-owned global limit `CRAFTING_GLOBAL_RATE_LIMIT=8/s` | Networking/trust | ADR-0006 (project-wide 30/s not reconciled w/ 8/s) | ⚠️ |
| TR-craft-013 | Placement validation order: clamp→LOS raycast→floor raycast→overlap | Networking/engine | ADR-0014 — full 4-step order, engine-specialist-confirmed raycast code [UPDATED] | ✅ |
| TR-craft-014 | BC4 hold check reads server-tracked `HumanoidRootPart.Position` | Networking/state | ADR-0008 | ✅ |
| TR-craft-015 | Test-harness DI seam (`_clock`/`_step`/`_enqueueDeparture`/etc.) | Testability/infra | — (Crafting's own F.4-flagged ADR, never authored) | ❌ |
| TR-craft-016 | All Crafting state purely runtime; zero DataStore writes during a run | Persistence | ADR-0007 | ✅ |
| TR-craft-017 | `BindToClose` during BC4 = forced cleanup, no victory/defeat/decay | Threading/persistence | ADR-0007/0005 touch BindToClose, not this path | ⚠️ |
| TR-craft-018 | KnitInit-time construction of cross-service-visible signals | Core/lifecycle | ADR-0001 | ✅ |
| TR-craft-019 | Knit `CraftingService`+`CraftingController`; server owns all mutation | Architecture/framework | ADR-0001 | ✅ |
| TR-craft-020 | Bench proximity watcher: server-side, `SENSOR_CHECK_HZ=5` via Heartbeat | Threading/timing | ADR-0013 [UPDATED] | ✅ |
| TR-craft-021 | Server CPU budgets: progress evaluator <0.5ms, anchor sensor <0.1ms | Performance | ADR-0013 (qualitative "negligible" treatment only, no ratified ms budget) [UPDATED] | ⚠️ |
| TR-craft-022 | Bandwidth discipline: progress ≤5Hz, hold-state hysteresis, edge-triggered break | Networking/bandwidth | ADR-0008 | ✅ |
| TR-craft-023 | RunStarted init: roster delivered by upstream matchmaking gate; `MIN_SQUAD_SIZE=2` | Run lifecycle | — (ADR-0002 is run-*end* only) | ❌ |
| TR-craft-024 | New `Craft` emission type registered against ED's reserved enum slot | Cross-system/registry | ADR-0004 references enum, not this registration | ⚠️ |
| TR-craft-025 | Cosmetic-boundary invariants on bench/beacon/anchor | Persistence/monetization | ADR-0007 (can-defer ADR #16 explicitly deferred) | ⚠️ |

## HUD (`design/gdd/hud.md`) — 4 / 7 / 17 (28 total)

| TR-ID | Requirement | Domain | ADR Coverage | Status |
|---|---|---|---|---|
| TR-hud-001 | Pure-subscriber consumer: no authoritative state, no echo-upstream, no RemoteFunction poll | Trust/server-authority | ADR-0006 (direction/surfaces only) | ⚠️ |
| TR-hud-002 | Single persistent `ScreenGui`, `ResetOnSpawn=false`, manual safe-area | Engine capability/UI | — (Presentation, expected) | ❌ |
| TR-hud-003 | Root `UIScale`+`UIAspectRatioConstraint`, cross-aspect layout | Platform | — (Presentation, expected) | ❌ |
| TR-hud-004 | CR.9 split-ownership seam: HUD owns mount Instance, producer owns input/FireServer | Cross-controller lifecycle | ADR-0001 Rule 1 (explicitly cited) | ✅ |
| TR-hud-005 | HUD controllers connect all producer signal handlers during KnitStart | Lifecycle/timing | ADR-0001 | ✅ |
| TR-hud-006 | Apply full-state snapshot before any incremental event (mid-run joiners) | Cross-system ordering | — (RN unauthored) | ❌ |
| TR-hud-007 | Transient alert-channel precedence structure | Data structure/state machine | — (Presentation, expected) | ❌ |
| TR-hud-008 | `FlashArbiter` module: sole flash/throb code path, ≤3 onsets/sec WCAG | Data structure/algorithm/timing | — (Presentation, expected) | ❌ |
| TR-hud-009 | Client interpolation loops never exceed producer cadence | Timing/threading | — (HUD-owned) | ❌ |
| TR-hud-010 | Oxygen dead-reckoning off `serverSendTime`; needs RM `{P,drainRate,serverSendTime}` | Timing/cross-system contract | — (RM has no core ADR) | ❌ |
| TR-hud-011 | Bearing→screen chevron; depends on PA `OnPredatorSense` convention | Timing/cross-system | — (PA-owned convention, no PA core ADR) | ❌ |
| TR-hud-012 | Server-clock-derived timers for gather ring & survival-window countdown | Engine capability/cross-system | ADR-0013 covers the Crafting side; RN still has no core ADR [UPDATED] | ⚠️ |
| TR-hud-013 | Startup config-assert: opacity/scale triples strictly monotone | Config validation | — (HUD-specific, SHOULD only) | ❌ |
| TR-hud-014 | Consume ED producer signals (`OnMeterUpdate`, `OnDisturbanceAlert`, `OnDeathAttributionPushed`) | Cross-system comms | ADR-0004 (producer side only) | ⚠️ |
| TR-hud-015 | Consume PC `OnPlayerDied`/`OnSquadMemberAliveChanged` | Cross-system comms | ADR-0005, ADR-0004 (producer side only) | ⚠️ |
| TR-hud-016 | Consume PA `OnPredatorSense`/`OnPredatorLockChanged`/state-change broadcast | Cross-system comms | — (PA has no core ADR) | ❌ |
| TR-hud-017 | Consume RM oxygen signals; coalesce simultaneous-death lurch | Cross-system comms | ADR-0005 (death-cost path only; display signals uncovered) | ⚠️ |
| TR-hud-018 | Consume RN `OnNodeStateChanged`/armed/disarmed/snapshot | Cross-system comms | — (RN unauthored) | ❌ |
| TR-hud-019 | Subscribe to `RunEnded(outcome)` for victory/defeat banner + input-lock | Cross-system/lifecycle | ADR-0002 (explicitly names HUD end-screen) | ✅ |
| TR-hud-020 | Consume Crafting beacon charge/BCT/survival-window pushes | Cross-system comms | ADR-0009/ADR-0010/ADR-0013 give Crafting a mechanism now; the HUD-facing push-signal shape is still undefined [UPDATED] | ⚠️ |
| TR-hud-021 | Dead/Spectating macro-state: respawn-timer countdown, oxygen-gated | Lifecycle state/cross-system | ADR-0005, ADR-0012 (renderScope + spectator camera now cover the overlay/Camera side) [UPDATED] | ✅ |
| TR-hud-022 | Eye-shine screen-space treatment, never world-anchored | Security/position-privacy | — (PA-owned, no PA ADR) | ❌ |
| TR-hud-023 | Bearing single-frame privacy: no client-readable time-series | Security | — (PA-owned, read-side leak) | ❌ |
| TR-hud-024 | Performance budget: HUD per-frame CPU ≤2.0ms at 30fps mobile floor | Performance | — (TD-proposed, not signed off; no perf ADR) | ❌ |
| TR-hud-025 | Bandwidth: HUD requests no higher push-rate than producers publish | Bandwidth/networking | ADR-0008 (accounts for HUD in budget) | ⚠️ |
| TR-hud-026 | Touch/platform: 44pt min touch targets, hit-area decoupled from visual size | Platform | — (Presentation, expected) | ❌ |
| TR-hud-027 | Reduced-motion: read external flag, degrade load-bearing vs decorative | Accessibility/config dependency | — (accessibility system unauthored) | ❌ |
| TR-hud-028 | Audio precedence gate: 2D non-diegetic layer, drop-not-queue | Cross-system audio ownership | — (audio architecture unauthored) | ❌ |

---

## Superseded Requirements

None — no TR-ID has been deprecated or superseded across either review pass.

## Review History

| Date | Covered / Partial / Gap | Verdict | Notes |
|---|---|---|---|
| 2026-07-06 (initial) | 93 / 72 / 104 (34.6%) | FAIL | First run; TR registry created (269 requirements) |
| 2026-07-06 (re-verification) | 108 / 70 / 91 (40.1%) | CONCERNS | ADR-0009..0014 (all new, Status: Proposed) closed both of RM's blocking gaps, PC's 3 self-flagged gaps, and 2 of Crafting's 4 self-flagged gaps. 2 new conflicts found (clock-seam violations in ADR-0011 and ADR-0013 — same bug class as the still-unresolved ADR-0005 violation) plus a stale `architecture.md` line — **all 3 fixed same session**. 6 conflicts from the initial pass remain open, unchanged, in already-Accepted ADR-0002/0004/0005 — these are the only thing left standing between CONCERNS and PASS. See `architecture-review-2026-07-06.md` for full detail. |
| 2026-07-06 (follow-up fix pass) | 108 / 70 / 91 (40.1%, unchanged — conflict fixes, not new coverage) | **PASS** | User requested the 6 carried-forward conflicts be fixed. All 6 fixed directly in source: ED's GDD Q3 resolved + tuning table synced to ADR-0004's evict-oldest; ADR-0004's `KnitStart`→`KnitInit` diagram slip corrected; `OnPlayerDied` kept as raw `BindableEvent` (respecting ED's frozen C.1.11 closure) with `Workspace.SignalBehavior` pinned instead of silently switching to Signal; ADR-0005's clock-seam violation fixed (3rd instance of the same bug class, now all 3 closed); ADR-0002's stale `C.5.8`→`C.9` citation fixed, caller list corrected to PC-only (Crafting's actual GDD model routes through PC, not the arbiter directly), `defeatReason` field added for `"scatter"`; RM's `RequestSquadOxygenSpend` GDD signature patched to match ADR-0005's ratified 4-param form in 4 locations. One non-blocking residual item flagged (PC/Crafting GDD prose tension on the BC4-forwarding path) rather than silently resolved. See `architecture-review-2026-07-06.md`'s "Carried-Forward Conflicts: RESOLVED" section for full detail. |
