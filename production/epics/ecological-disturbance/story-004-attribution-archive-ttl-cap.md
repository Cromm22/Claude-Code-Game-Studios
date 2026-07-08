# Story 004: Attribution Archive (write-once store, TTL, count-cap FIFO)

> **Epic**: Ecological Disturbance
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-06

## Context

**GDD**: `design/gdd/ecological-disturbance.md`
**Requirement**: `TR-ed-002` (attribution archive half of the two-store model), `TR-ed-020` (`MAX_ATTRIBUTION_ARCHIVE_ENTRIES=4000`, FIFO evict-oldest skipping locked), `TR-ed-048` (`ATTRIBUTION_ARCHIVE_TTL=1200s`, longest-of lifetime + fenced purge), `TR-ed-051` (lazy expiry, low-frequency maintenance cull pass)
**ADR Governing Implementation**: ADR-0004 (DisturbanceService Core Architecture)
**ADR Decision Summary**: The archive is a write-once-on-emission record keyed by `emissionId`, independent of the live-source list. Retained for the **longest** of: (a) `ATTRIBUTION_ARCHIVE_TTL` seconds from `emissionTime`, (b) until all players who could reference it have left the server, or (c) while the `emissionId` appears in any predator's currently-locked attribution list. Count-capped at `MAX_ATTRIBUTION_ARCHIVE_ENTRIES=4000`; on overflow, evict-oldest by `emissionTime` (FIFO), **skipping** any entry currently referenced by a live predator-lock registration.

**Engine**: Roblox Studio (live platform) + Luau + Knit | **Risk**: MEDIUM
**Engine Notes**: No post-cutoff API risk — pure server-side data-lifecycle logic. The GDD's own verification companion doc explicitly defers the TTL-purge unit test to this ADR/epic ("Archive TTL purge behaviour is not directly tested in this GDD's ACs; defer a TTL-purge unit test to the DisturbanceService ADR") — this story is where that deferred test lands.

**Control Manifest Rules (Core layer)**:
- Required: Clean up any per-player table (`loadedChunks`, dedup sets, rate-limit counters) on `Players.PlayerRemoving` — source: ADR-0004, ADR-0006 (analogous discipline applies to the archive's player-departure condition)
- Guardrail: Attribution archive bounded at `MAX_ATTRIBUTION_ARCHIVE_ENTRIES` — source: ADR-0004

---

## Acceptance Criteria

*From GDD C.1.11 (archive lifetime rule — no dedicated H.x number exists for TTL/cap behavior per the verification companion doc; the C.1.11 rule text below is the authoritative testable contract, per this epic's explicit deferral to the ADR/implementation story):*

- [ ] The archive is a write-once-on-emission record keyed by `emissionId`, containing `{emissionId, sourcePlayerId, emissionType, position, emissionTime, attributionChain}`. Archive entries survive source expiry/eviction and are NOT used by any field-value math.
- [ ] An archive entry is retained for the **longer** of: (a) `ATTRIBUTION_ARCHIVE_TTL` seconds (default 1200s = 20 min) from `emissionTime`, OR (b) until all players who could reference it (the `sourcePlayerId` and any player who has died with this `emissionId` in their attribution chain) have left the server, OR (c) while the `emissionId` appears in any predator's currently-locked attribution list (registered via `RegisterPredatorLock` — see Story 011). After the longest of those three conditions, the archive entry is purged.
- [ ] **Count cap**: the archive enforces `MAX_ATTRIBUTION_ARCHIVE_ENTRIES` (default 4000). On overflow, evict-oldest by `emissionTime` (FIFO) with an ops-log entry — SKIPPING any entry currently referenced by a live predator-lock registration (condition (c) entries are eviction-exempt until their lock releases; eviction advances to the next-oldest unreferenced entry).
- [ ] Archive maintenance (TTL purge + cap enforcement) is a fenced, measured workload (see Story 017's H.36a workload 11 — the profilebegin instrumentation must enclose this).
- [ ] The cap-hit caveat (GDD C.1.11): when a `MAX_LIVE_SOURCES` cap drop occurs (Story 003's eviction), **no archive entry is written** for the evicted emission — but note this is about the *live-source* eviction of Story 003, and is distinct from this story's own *archive* cap eviction. Confirm the two eviction paths are independent and do not interact incorrectly.

---

## Implementation Notes

Type declaration (per the F.2a-IMPORTANT forward-obligations cross-reference and ADR-0004's Architecture Diagram):
```luau
type AttributionArchiveEntry = {
    emissionId: string,
    sourcePlayerId: number,
    emissionType: EmissionType,
    position: Vector3,
    emissionTime: number,
    attributionChain: {string},
}
```
Derivation note from the GDD (cite for the default's rationale, do not re-derive): sustained natural play ≈ 3.1 emissions/s × the 1200s TTL ≈ 3,720 worst-case natural accumulation — the 4000 default admits the natural worst case with ≈7% headroom (thin by design; raise within the safe range if playtest emission rates exceed this assumption).

The archive's condition-(c) eviction-exemption requires reading the predator-lock registry (Story 011) at eviction time — this creates a dependency: this story's cap-eviction logic must call into (or share a data source with) Story 011's registry. If Story 011 is not yet implemented when this story starts, stub the "is this emissionId currently locked" check to always return `false` and add a `-- TODO(Story 011)` marker; do not block this story's own tests on Story 011's completion, but do add an integration test once Story 011 lands (tracked in Story 012).

Player-departure condition (b) requires listening to `Players.PlayerRemoving` and re-evaluating whether the departed player was the last remaining referencer of any archive entries — this is O(archive size) per departure in the naive implementation, acceptable at the 4000-entry cap.

---

## Out of Scope

- Story 003: live-source list eviction (a distinct store with a distinct, simpler oldest-first-no-exemptions policy).
- Story 011: the predator-lock registry itself (`RegisterPredatorLock`/`ReleasePredatorLock`) — this story only needs to *query* whether an `emissionId` is currently locked, not implement the lock registry.
- Story 012: resolving archive entries into a `DeathAttributionPayload` for HUD consumption (this story only owns the archive's own lifecycle, not its consumption).

---

## QA Test Cases

- **AC — write-once record**: Given: `Emit()` is called with a valid payload — When: the archive is queried by the resulting `emissionId` — Then: an `AttributionArchiveEntry` exists with all 6 fields matching the emission exactly, and it is retrievable even after the corresponding live source has expired/decayed below `MAGNITUDE_FLOOR`.
- **AC — TTL purge (condition a)**: Given: an archive entry with `emissionTime = T` and `ATTRIBUTION_ARCHIVE_TTL = 1200`, with no players referencing it (condition b/c both false) — When: the test clock advances to `T + 1201` and a maintenance pass runs — Then: the entry is purged. Edge case: at exactly `T + 1200` (boundary — verify whether this is inclusive or exclusive per the "longer of" wording; test both `T+1199.9` retained and `T+1200.1` purged, treating 1200.0 as the documented boundary to pin down in the test).
- **AC — player-departure retention (condition b)**: Given: an archive entry whose `sourcePlayerId` is still connected, TTL has expired — When: a maintenance pass runs — Then: the entry is RETAINED (condition b keeps it alive past TTL because the source player hasn't left). Edge case: the source player disconnects — entry should now purge on the next maintenance pass IF TTL has also expired AND no predator lock references it (condition c).
- **AC — predator-lock retention (condition c)**: Given: an archive entry currently referenced by a live `RegisterPredatorLock` registration, TTL expired, source player departed — When: a maintenance pass runs — Then: the entry is RETAINED (condition c overrides). Edge case: once the predator lock releases (Story 011's grace window expires), the entry purges on the NEXT maintenance pass after release, not immediately mid-frame.
- **AC — count-cap FIFO with lock-exemption**: Given: the archive is at `MAX_ATTRIBUTION_ARCHIVE_ENTRIES` (4000), the oldest entry is currently predator-lock-referenced — When: a new emission arrives, triggering cap overflow — Then: the oldest UNREFERENCED entry is evicted instead (eviction skips the locked oldest entry and advances to the next-oldest), and an ops-log entry records the eviction. Edge case: ALL 4000 entries are locked (pathological/unreachable in practice, but test that the implementation doesn't crash — e.g., it should log a distinct "cannot evict, cap exceeded" warning rather than silently growing unbounded or throwing).
- **AC — independence from live-source eviction**: Given: a live source is evicted per Story 003's cap-eviction policy — When: the archive is queried — Then: the archive entry for that emission is untouched (still present, following its own independent TTL/lock/cap rules), confirming the two stores are decoupled.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ecological-disturbance/attribution-archive-ttl-cap_test.luau` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 002, 003
- Unlocks: 010, 012

---

## Completion Notes
**Completed**: 2026-07-08
**Criteria**: 5/5 passing
**Deviations**: A BLOCKING bug was found in code review — introduced by the sibling story ed-5's later addition, not by this story: `self._decayCache` was never cleared on Story 003's pre-existing cap-eviction path in `Emit()`, an unbounded per-process leak. Found and fixed same-session (`src/gameplay/services/DisturbanceService.luau`), re-verified 12/12 test files passing.
**Test Evidence**: `tests/unit/ecological-disturbance/attribution-archive-ttl-cap_test.luau` — passing
**Code Review**: Complete (combined ed-4+ed-5 review) — CHANGES REQUIRED → fixed → clean
**Tech debt**: TD-004 (prior open item from `ed-3`) resolved by this story's own test suite.
