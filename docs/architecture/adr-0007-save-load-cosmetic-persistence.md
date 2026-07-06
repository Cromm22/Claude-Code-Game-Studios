# ADR-0007: Save/Load & Cosmetic Persistence

## Status
Accepted (ratified by the user 2026-07-06)

## Date
2026-07-06

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Roblox Studio (live platform) + ProfileStore (confirmed DataStore wrapper, `.claude/docs/technical-preferences.md`) |
| **Domain** | Core (persistence / monetization) |
| **Knowledge Risk** | LOW/MEDIUM — `MarketplaceService:ProcessReceipt` and `DataStoreService` are long-standing, well-documented APIs; ProfileStore's exact synchronous-save method name is a MEDIUM item this ADR flags for Studio verification rather than guesses at, since the specific wrapper's API surface is not in the engine-reference library yet. |
| **References Consulted** | `design/gdd/game-concept.md` (Monetization section, Cosmetic Boundary Rule, Cosmetic purchase write path), `.claude/docs/technical-preferences.md` (ProfileStore confirmed, forbidden raw `DataStoreService` patterns), `docs/engine-reference/roblox/deprecated-apis.md` (DataStore Patterns table), `docs/architecture/architecture.md` (Architecture Principle #5 "Rounds, not saves") |
| **Post-Cutoff APIs Used** | None |
| **Verification Required** | ProfileStore's exact synchronous-save/flush API (see Decision) — verify against the pinned ProfileStore version (`https://madstudioroblox.github.io/ProfileStore/`) before implementation; do not assume a specific method name from training data alone. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None |
| **Enables** | Cosmetic purchase implementation (`MarketplaceService:ProcessReceipt`), the cosmetic-boundary TestEZ mechanical-equivalence test (architecture.md's can-defer ADR #16), and any future meta-progression feature. |
| **Blocks** | No epic is currently blocked — cosmetic purchase is not core-loop-critical for MVP — but this is the only persistence surface in the entire game (Architecture Principle #5), so it must exist before any cosmetic content ships. |
| **Ordering Note** | Fully independent of the other five remaining must-have ADRs; this system has literally no GDD, so this ADR is also its architectural specification, not just an implementation decision layered on an existing design. |

## Context

### Problem Statement

Save/Load & Cosmetic Persistence has **no GDD at all** — it exists only as scattered requirements in `game-concept.md` (Monetization section, the Cosmetic Boundary Rule, and the "Cosmetic purchase write path" paragraph) and as `TR-xcut-002`/`TR-xcut-006` in the Technical Requirements Baseline. This project's own Architecture Principle #5 ("Rounds, not saves") makes this the **sole persistence surface in the entire game** — every other system's state is discarded at run end by construction. This ADR authors the full architecture for that one surface: the ProfileStore schema, the `ProcessReceipt` idempotency gate, and the hard boundary that nothing else may ever persist through this module.

### Constraints

- `.claude/docs/technical-preferences.md` forbids raw `DataStoreService:GetAsync()`/`:SetAsync()` — ProfileStore (or an equivalent retry/backoff/session-lock wrapper) is mandatory.
- `game-concept.md`'s own hard requirement: **"no charge without grant"** — Robux must never be deducted unless the cosmetic is durably granted; a server crash between the DataStore write and the `PurchaseGranted` return must not result in a silent double-charge (Roblox retries the callback) or a lost grant.
- Every purchase must show a full-rotation cosmetic preview before confirmation (MVP requirement, `game-concept.md`).
- A visible "purchase failed — Robux not deducted" toast on any non-grant outcome, plus a persistent failure ledger at `production/qa/evidence/purchase-failures.md`.
- Per Architecture Principle #5, this module must be fully isolated — no run-state (squad state, disturbance state, oxygen pool, crafting inventory) may ever be written through this persistence path, even accidentally.

### Requirements

- A ProfileStore-backed profile schema covering owned cosmetics, equipped cosmetics, and a purchase-receipt idempotency ledger.
- An idempotent `ProcessReceipt` callback that never double-charges and never silently loses a grant across a crash.
- A hard, enforced boundary: this module owns cosmetic/meta-progression data ONLY.

## Decision

### ProfileStore schema

```luau
type CosmeticProfileData = {
    OwnedCosmetics: {[string]: boolean},        -- cosmeticId -> true (owned)
    EquippedCosmetics: {
        skin: string?,
        emoteSlots: {string?},                  -- 6 slots per PC's C.4.2 emote wheel
        lobbyDecor: {string},                   -- cross-run-persistent profile-space items only
    },
    ProcessedReceipts: {[string]: boolean},     -- PurchaseId -> true (idempotency ledger, see below)
    MetaProgression: {},                        -- reserved, empty for MVP — no meta-progression system authored yet
}

local PROFILE_TEMPLATE: CosmeticProfileData = {
    OwnedCosmetics = {},
    EquippedCosmetics = {skin = nil, emoteSlots = {}, lobbyDecor = {}},
    ProcessedReceipts = {},
    MetaProgression = {},
}
```

`ProcessedReceipts` is the idempotency ledger `game-concept.md`'s cosmetic purchase write path requires — keyed by Roblox's own `receiptInfo.PurchaseId` (globally unique per purchase, per Roblox's `ProcessReceipt` contract), not by product or player, since a single player could legitimately purchase the same product twice (e.g., a consumable, though this project's cosmetics are all one-time unlocks — the ledger is still keyed by `PurchaseId` for correctness against Roblox's own retry contract, not because repeat purchases of the same cosmetic are expected).

### `ProcessReceipt` idempotency gate

```luau
-- NOTE: MarketplaceService.ProcessReceipt is a singleton assignment — any other
-- script setting it later silently overwrites this one with no warning. This
-- module MUST be the sole owner of this assignment across the whole codebase
-- (engine-specialist review 2026-07-06).
MarketplaceService.ProcessReceipt = function(receiptInfo)
    local ok, decision = pcall(processReceiptBody, receiptInfo)
    if not ok then
        -- An uncaught error here would otherwise escape silently to Roblox's own
        -- retry machinery with nothing logged to purchase-failures.md.
        logPurchaseFailure(receiptInfo, "uncaught-error: " .. tostring(decision))
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end
    return decision
end

function processReceiptBody(receiptInfo)
    local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
    if not player then
        -- Player not currently in this server instance (e.g., purchased via a
        -- different flow, or disconnected mid-purchase) — Roblox retries on next
        -- login per its own ProcessReceipt contract. Do NOT grant here.
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    local profile = ProfileStore:GetProfile(player)  -- verify exact API name against pinned ProfileStore version
    if not profile then
        -- Profile not yet loaded for this player (race with join-time load) —
        -- ask Roblox to retry; do NOT grant against an unloaded profile.
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    -- IDEMPOTENCY GATE: if this exact PurchaseId was already processed, the
    -- cosmetic is already granted (from a prior call — possibly a Roblox retry
    -- after this exact callback previously returned PurchaseGranted but the
    -- server crashed before Roblox recorded that). Re-granting is a no-op;
    -- returning PurchaseGranted again is correct and expected.
    if profile.Data.ProcessedReceipts[receiptInfo.PurchaseId] then
        return Enum.ProductPurchaseDecision.PurchaseGranted
    end

    local cosmeticId = mapProductIdToCosmeticId(receiptInfo.ProductId)
    profile.Data.OwnedCosmetics[cosmeticId] = true
    profile.Data.ProcessedReceipts[receiptInfo.PurchaseId] = true

    -- CRITICAL ORDERING: the receipt must be durably persisted BEFORE this
    -- function returns PurchaseGranted, per game-concept.md's own "no charge
    -- without grant" requirement — a return without a durable write risks a
    -- server crash losing the grant while Robux has already been charged.
    -- VERIFY (engine-specialist review 2026-07-06 could not confirm this API from
    -- training data alone — WebSearch/devforum-check required before implementation):
    -- it is uncertain whether ProfileStore exposes a synchronous save-and-confirm
    -- method shaped like this, or relies on periodic autosave with confirmation only
    -- via a separate signal/callback. If the latter, this rollback branch must be
    -- restructured around that callback rather than an inline boolean — a real
    -- control-flow risk, not just a naming detail. A manual save call here may also
    -- compete with ProfileStore's own periodic autosave on the same DataStore key,
    -- risking the ~6s per-key write cooldown stalling this callback longer than
    -- expected under load.
    local saveOk = profile:Save()
    if not saveOk then
        -- Roll back the in-memory mutation; ask Roblox to retry rather than
        -- returning PurchaseGranted against an unpersisted state.
        profile.Data.OwnedCosmetics[cosmeticId] = nil
        profile.Data.ProcessedReceipts[receiptInfo.PurchaseId] = nil
        logPurchaseFailure(receiptInfo, "save-failed")  -- production/qa/evidence/purchase-failures.md
        return Enum.ProductPurchaseDecision.NotProcessedYet
    end

    return Enum.ProductPurchaseDecision.PurchaseGranted
end
```

### Isolation boundary (Architecture Principle #5, enforced here explicitly)

**This module owns exactly one persisted schema — `CosmeticProfileData` above — and nothing else.** No other system (Resource Management's oxygen pool, Crafting's inventory, Ecological Disturbance's live-source list, Player Controller's squad state) may ever write through ProfileStore or any other DataStore path. This is not merely a convention: any future PR that introduces a second `ProfileStore:GetProfile`-style call outside this module's own service is an architecture violation of Architecture Principle #5 and should be rejected at code review, the same class of enforcement ADR-0004's N5 and this ADR's own sibling boundary rules establish elsewhere.

### Architecture Diagram

```
Player joins
    │
    ▼
CosmeticPersistenceService:KnitInit / player-join handler
    │
    ▼
ProfileStore:GetProfile(player) — session-locked profile load, retry/backoff internal to ProfileStore
    │
    ▼
profile.Data reconciled against PROFILE_TEMPLATE (new fields default-filled for existing profiles)
    │
    ├──► Cosmetic equip/unequip UI reads/writes profile.Data.EquippedCosmetics (in-memory,
    │      persisted on ProfileStore's normal save cycle — no purchase-path urgency)
    │
    └──► MarketplaceService.ProcessReceipt(receiptInfo)
              │
              ▼
         idempotency gate (ProcessedReceipts[PurchaseId]) → grant once, durably, before
         returning PurchaseGranted (see Decision)

Player leaves / BindToClose → ProfileStore releases the session lock, final save.

NOTHING ELSE in this game ever calls ProfileStore or DataStoreService — every other
system's state is discarded at run end by construction (Architecture Principle #5).
```

### Key Interfaces

(See the `ProcessReceipt` code block above — this ADR's primary interface.)

```luau
-- Cosmetic Boundary Rule enforcement hook (architecture.md's can-defer ADR #16
-- consumes this module's OwnedCosmetics/EquippedCosmetics as its data source;
-- this ADR does not itself implement the TestEZ mechanical-equivalence test,
-- only guarantees the data this module owns is available to it)
function CosmeticPersistenceService:GetEquippedCosmetics(player: Player): CosmeticProfileData
```

## Alternatives Considered

### Alternative 1: Grant immediately, save asynchronously (fire-and-forget)
- **Description**: Mutate `profile.Data` and return `PurchaseGranted` immediately, letting ProfileStore's normal periodic autosave persist the change whenever it next runs, without an explicit synchronous save call.
- **Pros**: Simpler; no explicit save call, no rollback-on-save-failure branch.
- **Cons**: Directly violates `game-concept.md`'s own explicit requirement to store the idempotency key "before returning `PurchaseGranted`" — a server crash between the in-memory mutation and the next periodic autosave would lose the grant entirely while Robux was already charged, exactly the failure mode the requirement exists to prevent.
- **Rejection Reason**: Explicitly contradicts a stated hard requirement in `game-concept.md`.

### Alternative 2: A dedicated "purchase ledger" DataStore separate from ProfileStore
- **Description**: Store `ProcessedReceipts` in its own raw `DataStoreService` key, separate from the player's ProfileStore-managed profile, to decouple purchase-processing reliability from general profile load/save timing.
- **Pros**: Purchase-ledger writes wouldn't be blocked by, or coupled to, unrelated profile-save timing.
- **Cons**: Directly reintroduces the forbidden raw `DataStoreService` pattern (`.claude/docs/technical-preferences.md`'s explicit ban), loses ProfileStore's retry/backoff/session-locking, and creates a second persistence surface this ADR's own Isolation Boundary decision exists to prevent.
- **Rejection Reason**: Violates the project's own forbidden-pattern rule and this ADR's single-schema isolation principle.

## Consequences

### Positive
- One schema, one service, one persistence surface for the entire game — trivially auditable against Architecture Principle #5.
- The idempotency gate closes the exact crash-recovery race `game-concept.md` names, using Roblox's own `ProcessReceipt` retry contract as the safety net rather than fighting it.
- `NotProcessedYet` is used correctly for both "player not present" and "save failed" cases, letting Roblox's own retry mechanism do the recovery work rather than this ADR inventing a custom retry scheme.

### Negative
- The `profile:Save()` call (or whatever ProfileStore's actual synchronous-save API turns out to be) blocks the `ProcessReceipt` callback until it resolves — Roblox's own `ProcessReceipt` documentation expects callbacks to resolve reasonably promptly; if ProfileStore's save call has significant latency under load, this could risk timeout. **Accepted trade-off**: correctness (no ungranted charge) is prioritized over callback latency; flagged in Risks.

### Risks
- **Engine-specialist review (2026-07-06) fixes/notes**: the `ProcessReceipt` body lacked a `pcall` wrapper — an uncaught error (e.g., from `mapProductIdToCosmeticId`) would have escaped to Roblox's retry machinery with nothing logged to `purchase-failures.md`; fixed by wrapping the whole body and logging uncaught errors explicitly. `MarketplaceService.ProcessReceipt` is a singleton assignment with no built-in protection against a second script silently overwriting it — noted explicitly as a single-owner requirement. A manual `profile:Save()` inside this callback may compete with ProfileStore's own periodic autosave on the same DataStore key (the ~6s per-key write cooldown could stall the callback longer than expected under load) — noted inline. `BindToClose` timing vs. an in-flight `ProcessReceipt` during server shutdown is an edge case this ADR does not fully resolve; Roblox's own retry contract is the backstop (an incomplete callback at shutdown is retried on next login), consistent with this ADR's existing crash-recovery reasoning, but worth a dedicated look during implementation.
- **ProfileStore's exact synchronous-save API is unverified** — this ADR uses `profile:Save()` as a placeholder pending Studio/devforum verification against the pinned ProfileStore version. If no synchronous save-and-confirm API exists in the actual library, this decision needs revision (e.g., using `Profile:Reconcile()` + observing a save-completion signal, if ProfileStore exposes one). **Mitigation**: named explicitly as Verification Required; do not implement against the exact method name shown here without confirming it first.
- **`ProcessReceipt` callback latency** if the synchronous save blocks for an unusually long time under DataStore rate-limit backoff (60 req/min/server per `game-concept.md`'s own cited limit). **Mitigation**: `game-concept.md` already names this exact rate limit as a known constraint; if latency becomes an issue, the fix is DataStore request budgeting, not abandoning the durable-write-before-grant requirement.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| game-concept.md | Monetization (F2P, cosmetic-only, 3 categories), Cosmetic Boundary Rule, Cosmetic purchase write path ("no charge without grant", idempotency, preview pane, failure toast + ledger) | Schema covers all 3 cosmetic categories; `ProcessReceipt` gate implements the idempotency + durable-write-before-grant requirement; preview pane and failure toast are UI-layer requirements this ADR's data model supports but does not itself implement (UI-programmer's job) |

## Performance Implications
- **CPU**: Negligible — `ProcessReceipt` fires only on purchase, not per-frame.
- **Memory**: One profile per connected player, released on `PlayerRemoving`/`BindToClose`.
- **Load Time**: Profile load at join adds a DataStore round-trip to player-join latency, standard for any ProfileStore-based game.
- **Network**: None directly — persistence is a server-only DataStore concern.

## Migration Plan
No migration — this is a greenfield system with no prior implementation and no GDD.

## Validation Criteria
- Integration test: a simulated `ProcessReceipt` call followed by a simulated server crash (before the mocked save resolves) results in Roblox's retry receiving `NotProcessedYet`, and a subsequent successful retry grants exactly once (no double-grant, no lost grant).
- Integration test: a duplicate `ProcessReceipt` call for an already-processed `PurchaseId` returns `PurchaseGranted` without re-mutating `OwnedCosmetics`.
- Manual smoke test (per `.claude/docs/coding-standards.md`'s Testing Standards, Config/Data tier): a forced-disconnect-reconnect confirms the profile reloads with previously-granted cosmetics intact.

## Related Decisions
- `docs/architecture/architecture.md` — Architecture Principle #5 ("Rounds, not saves"), Module Ownership's Save/Load row.
- Feeds architecture.md's can-defer ADR #16 (Cosmetic Boundary Rule automated enforcement — deferred until cosmetic content exists).
- `design/gdd/game-concept.md` — Monetization, Cosmetic Boundary Rule, Cosmetic purchase write path.

## Open Questions
- **No GDD exists for this system at all** — this ADR is presently the only design authority for cosmetic persistence. A future `/design-system` pass (flagged in project memory) may be warranted if the cosmetic feature set grows beyond what this ADR's schema anticipates (e.g., a real meta-progression system, currently just a reserved empty field).
