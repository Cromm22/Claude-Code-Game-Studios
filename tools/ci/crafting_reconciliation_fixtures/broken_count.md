<!-- crafting-reconciliation hook self-test fixture: BROKEN (REC-1). Reproduces the
     count-drift class: the AC preamble claims 4 live ACs but only 3 live headers
     exist (a live AC was cut without updating the count), and the edge preamble
     claims "through E.4" while the max edge header is E.3. REC-1 MUST report a
     count mismatch on both. -->

# Fixture GDD (minimal)

## Acceptance Criteria

This section enumerates 4 live acceptance criteria (numbered through H.5; 2 retired — H.2/H.4 in the round-2 cut) validating the rules.

**H.1 — first live AC**
- **THEN** something
- **Test type**: Logic

**H.2, H.4 — *REMOVED (round-2, 2026-06-01)*** — two cut recipes; numbers retired in place, not reused.

**H.3 — second live AC**
- **THEN** something
- **Test type**: Logic

**H.5 — third live AC**
- **THEN** something
- **Test type**: Logic

## Edge Cases

This section enumerates 2 live edge cases (numbered through E.4; E.2 retired in the round-2 catalog cut) organised by category.

**E.1 — first edge**
- **THEN** something

**E.2 — *RETIRED (round-2, 2026-06-01)*** — a cut edge case; number retired in place.

**E.3 — third edge**
- **THEN** something
