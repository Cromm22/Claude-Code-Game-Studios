# Epic: Save/Load — Cosmetic Persistence

> **Layer**: Foundation
> **GDD**: None — this module has no GDD; ADR-0007 is its sole design authority
> **Architecture Module**: `CosmeticPersistenceService`
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories cosmetic-persistence`

## Overview

This is the sole persistence surface in the entire game (Architecture Principle
#5, "Rounds, not saves") — every other system's state is discarded at run end by
construction. It owns a ProfileStore-backed schema covering owned/equipped
cosmetics and a purchase-receipt idempotency ledger, plus an idempotent
`MarketplaceService.ProcessReceipt` callback that never double-charges and never
silently loses a grant across a server crash ("no charge without grant").
Cosmetic purchase is not core-loop-critical for MVP, so this epic is not on the
critical path to a vertical slice, but it must exist before any cosmetic content ships.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-------------------|-------------|
| ADR-0007: Save/Load & Cosmetic Persistence | ProfileStore schema (`OwnedCosmetics`/`EquippedCosmetics`/`ProcessedReceipts`); durable-write-before-grant `ProcessReceipt` gate; hard isolation boundary — no other system may ever touch ProfileStore | LOW/MEDIUM |

## GDD Requirements

**No TR-registry entries exist for this module** — like RunController, this
system predates the GDD-driven `tr-registry.yaml` and has no GDD at all.
Requirements are traced directly from ADR-0007:

| Requirement (from ADR-0007) | Status |
|---|---|
| `CosmeticProfileData` schema (OwnedCosmetics, EquippedCosmetics, ProcessedReceipts, reserved MetaProgression) | ✅ Specified in ADR |
| `MarketplaceService.ProcessReceipt` idempotency gate, keyed by `receiptInfo.PurchaseId` | ✅ Specified in ADR |
| Isolation boundary — no other system may call `ProfileStore:GetProfile` or `DataStoreService` | ✅ Specified in ADR (enforced at code review, not mechanically yet) |

**⚠️ Verification Required (named explicitly in ADR-0007, unresolved)**: the exact
ProfileStore synchronous-save-and-confirm API used in the ADR's sample code
(`profile:Save()`) is unverified against the pinned ProfileStore version — the
engine specialist could not confirm this method name from training data alone.
Must be checked against `https://madstudioroblox.github.io/ProfileStore/` before
implementation.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- The ProfileStore synchronous-save API is verified against the pinned version
  before any story implementing `ProcessReceipt` is marked Done
- Integration tests confirm: a simulated `ProcessReceipt` call followed by a
  simulated crash before the mocked save resolves results in Roblox's retry
  receiving `NotProcessedYet`, with exactly one grant on a subsequent successful retry
- A grep-based code-review check confirms no second `ProfileStore:GetProfile`-style
  call exists outside this module anywhere in the codebase

## Next Step

Run `/create-stories cosmetic-persistence` to break this epic into implementable stories.
