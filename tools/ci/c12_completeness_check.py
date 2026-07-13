#!/usr/bin/env python3
"""
C.12 Contract Completeness Invariant — executable CI hook.

This is the round-28 CD-mandated standing falsifier for the Player Controller GDD
(`design/gdd/player-controller.md`). It replaces "a future review panel will catch
the under-enumeration" with a machine-checked completeness gate.

It asserts the three C.12 invariants the GDD declares (player-controller.md C.12):

  #1  Canonical-table completeness — every server-signal / cross-service call PC
      *wires* in its prose (subscribe / raise / push / call site) has exactly one
      row in a C.9 canonical table (RemoteEvent surface, outbound server-internal,
      or inbound-subscription), OR is an explicitly-recorded deliberate
      non-subscription, OR is an other-GDD-owned name on the external allowlist.
      Sub-check 1b: every S->C push event also appears in the F.2 HUD push-contract.

  #2  Floor-field declaration sites — every authored mix field a G.9 floor gates
      against is declared in BOTH the G.9.1 table AND entities.yaml.

  #3  Sign-knob domain gates — the sign/domain-sensitive stamina-curve knobs AND the
      emission-attenuation factor STATIONARY_EMISSION_FACTOR (round-30 clause (vi)) are
      each asserted in the H.12a config-validation gate, whose clauses (i)-(vi) all exist.

DESIGN NOTE (why this lives in tools/ci as a GDD-static linter, not a Luau test):
the project is pre-production — there is no PC Luau source to grep yet, so the only
artifact that contains PC's wiring today is the GDD prose. When PC code lands, extend
`extract_body_wiring()` to also scan the .luau call sites; the invariants are unchanged.

Falsification rule (CD round-27 refinement, recorded in C.12): re-architecture is
warranted only if the under-enumeration class recurs on a surface THIS HOOK COVERS.
If it recurs outside the hook's coverage, widen the hook — do not re-architect.

Usage:
    python tools/ci/c12_completeness_check.py            # check the real PC GDD
    python tools/ci/c12_completeness_check.py --self-test  # prove the hook has teeth
    python tools/ci/c12_completeness_check.py --gdd <path> --entities <path>

Exit codes: 0 = all invariants GREEN; 1 = an invariant FAILED (red); 2 = hook self-test
or I/O error (the hook itself is broken — treat as a build failure too).
"""

from __future__ import annotations

import argparse
import os
import re
import sys

# --- Repo-relative defaults -------------------------------------------------

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, "..", ".."))
DEFAULT_GDD = os.path.join(_REPO, "design", "gdd", "player-controller.md")
DEFAULT_ENTITIES = os.path.join(_REPO, "design", "registry", "entities.yaml")
FIXTURES = os.path.join(_HERE, "c12_fixtures")

# --- Allowlists (the auditable, explicit part of the contract) --------------

# Other-GDD-owned signal names that legitimately appear in PC prose as cross-
# references but are NOT PC's to declare in a C.9 canonical row. Each entry is a
# deliberate "owned elsewhere" declaration; adding to this list is a conscious act
# that a reviewer can audit. A *new* PC-wired signal must NOT be silenced here —
# it must get a real canonical row.
EXTERNAL_OWNED = {
    "RequestCraft":          "Crafting C.15 (crafting-and-items.md) — PC references the trust boundary only",
    "RequestBeaconActivate": "Crafting C.15 — Crafting-owned receive-side event",
    "OnPlayerStatusUnknown": "HUD GDD (F.4 HUD row) — optional interim roster state PC owes HUD, not a PC wiring",
    "Emit":                  "ED DisturbanceService:Emit (ED.C.3.2) — a pre-existing ED API PC calls; modeled in C.10, not a PC-introduced C.9 signal",
    # round-30 widen (build-from-artifact G-1): the GatherNode* consumer-event family
    # escaped BOTH matcher arms before round-30 (no On/Request/Run prefix, not Service:Method),
    # so the hook was BLIND to it. The round-30 _TOK_CONSUMER arm now SEES it; these two are
    # Resource-Node-owned S->C events PC's C.7 proximity UI subscribes to (RN F.2 row, C.9 line
    # cross-ref) — accounted here, not silenced. A future *PC-owned* `<Noun>Armed/Disarmed` event
    # would now be SEEN-and-leak rather than invisible (the point of widening).
    "GatherNodeArmed":       "Resource Node GDD (F.2 RN row / C.9 cross-ref) — RN-owned S->C proximity-prompt event PC consumes in C.7, not a PC-introduced signal",
    "GatherNodeDisarmed":    "Resource Node GDD (F.2 RN row / C.9 cross-ref) — RN-owned S->C proximity-prompt event PC consumes in C.7, not a PC-introduced signal",
}

# Identifiers that match the signal-token shape (On*/Request*/Run*) but are system /
# service / type NAMES, not signals — they never need a canonical row. Kept explicit
# and small so a reviewer can audit that nothing real is being silenced here.
NON_SIGNAL_NAMES = {
    "RunController",  # the run-lifecycle arbiter service name (F.4), not a signal
    "RunSession",     # Crafting's run-state table type (referenced in cross-refs), not a signal
}

# Signal-token shape: the event/RPC naming convention (On*/Request*/Run*) plus the
# qualified cross-service call forms (XxxService:Method, RunController:Method) and the
# bare method names they resolve to. The ReleasePredatorLock round-28 leak did NOT
# match On/Request/Run — it was only reachable via the Service:Method form, so that
# arm is load-bearing, not decorative.
_TOK_PLAIN = re.compile(r"`((?:On|Request|Run)[A-Z]\w+)`")
_TOK_QUALIFIED = re.compile(r"`(?:[A-Z]\w*Service|RunController)\s*:\s*(\w+)`")
# round-30 widen (build-from-artifact G-1/G-2): two signal-wiring forms escaped the two arms
# above before round-30 and were therefore invisible (net out balanced, no false RED, but also
# UNCHECKED for completeness):
#   - the C->S RemoteEvent `PlayerHeartbeat` (no On/Request/Run prefix) — it HAS a C.9 row, but
#     the hook never verified that; if its row were deleted it would have leaked silently.
#   - the `<Noun>Armed/Disarmed` consumer-event family (e.g. RN's GatherNodeArmed/Disarmed).
# This arm makes both visible on BOTH the canonical (C.9 first-column) and the wired (body) sides,
# so each must now be accounted by a real row or an EXTERNAL_OWNED entry. Kept narrow + explicit
# (a named event + a specific suffix family) so a reviewer can audit that nothing real is silenced;
# extend the alternation when a new non-prefixed PC signal shape appears.
_TOK_CONSUMER = re.compile(r"`(PlayerHeartbeat|[A-Z]\w+(?:Armed|Disarmed))`")

# The full matcher set used everywhere a token shape is scanned (canonical first-columns, body
# wiring, S->C direction rows). Adding an arm here widens ALL three consistently.
_ALL_TOKS = (_TOK_PLAIN, _TOK_QUALIFIED, _TOK_CONSUMER)


def _normalize(name: str) -> str:
    """Strip any `XxxService:` / `RunController:` qualifier to the bare method name."""
    return name.split(":")[-1].strip()


# --- Section / table parsing ------------------------------------------------

def _section_slice(text: str, header_re: str) -> str:
    """Return the text from a header matching header_re up to the next same-or-higher
    markdown header (####/###/##), or end of doc."""
    lines = text.splitlines()
    start = None
    start_level = None
    for i, ln in enumerate(lines):
        m = re.match(r"^(#{2,4})\s+(.*)$", ln)
        if m and re.search(header_re, m.group(2)):
            start = i
            start_level = len(m.group(1))
            break
    if start is None:
        return ""
    out = [lines[start]]
    for ln in lines[start + 1:]:
        m = re.match(r"^(#{2,4})\s+", ln)
        if m and len(m.group(1)) <= start_level:
            break
        out.append(ln)
    return "\n".join(out)


def _table_first_column_names(section: str) -> set[str]:
    """Backtick signal-names found in the FIRST content cell of any markdown table
    row in `section`. First-column = the row's subject (the declared signal)."""
    names: set[str] = set()
    for ln in section.splitlines():
        s = ln.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if not cells:
            continue
        col1 = cells[0]
        if set(col1) <= {"-", ":", " "}:  # separator row
            continue
        for rx in _ALL_TOKS:
            for m in rx.finditer(col1):
                names.add(_normalize(m.group(1)))
    return names


def _table_rows(section: str) -> list[list[str]]:
    rows = []
    for ln in section.splitlines():
        s = ln.strip()
        if not s.startswith("|"):
            continue
        cells = [c.strip() for c in s.strip("|").split("|")]
        if cells and set(cells[0]) <= {"-", ":", " "}:
            continue
        rows.append(cells)
    return rows


def extract_canonical_names(text: str) -> set[str]:
    """All signal names declared (have a first-column row) anywhere in the C.9 section."""
    c9 = _section_slice(text, r"C\.9\b")
    return _table_first_column_names(c9)


def extract_s2c_events(text: str) -> set[str]:
    """S->C push events: C.9 RemoteEvent-table rows whose direction cell is 'S -> C'."""
    c9 = _section_slice(text, r"C\.9\b")
    out: set[str] = set()
    for cells in _table_rows(c9):
        if len(cells) < 2:
            continue
        direction = cells[1].replace("→", "->")
        # Tolerant of "S -> C", "S -> C (broadcast)" and "S -> owning C only".
        if re.search(r"\bS\s*->.*\bC\b", direction):
            for rx in _ALL_TOKS:
                for m in rx.finditer(cells[0]):
                    out.add(_normalize(m.group(1)))
    return out


def extract_nonsubscriptions(text: str) -> set[str]:
    """Deliberate non-subscriptions the body records so the hook doesn't false-flag them.
    Detects: 'PC does NOT subscribe to `X`' and 'Deliberate NON-subscription ... `X`'."""
    out: set[str] = set()
    for m in re.finditer(r"does NOT subscribe to\s+`([A-Za-z0-9]+)`", text):
        out.add(_normalize(m.group(1)))
    for m in re.finditer(r"NON-subscription[^.]*?`([A-Za-z0-9]+)`", text):
        out.add(_normalize(m.group(1)))
    return out


def _f2_hud_pushrow(text: str) -> str:
    """The F.2 table row(s) whose first cell names HUD — the PC->HUD push-contract row.
    Returns the joined HUD-row text, or the whole F.2 slice as a fallback if no HUD row
    is found (so a future restructure degrades gracefully, never false-REDs)."""
    f2 = _section_slice(text, r"F\.2\b")
    hud_rows = []
    for cells in _table_rows(f2):
        if cells and re.search(r"\bHUD\b", cells[0]):
            hud_rows.append(" | ".join(cells))
    return "\n".join(hud_rows) if hud_rows else f2


def extract_body_wiring(text: str) -> set[str]:
    """Every signal-shaped token referenced anywhere in the doc (the things PC wires
    in prose). When PC code exists, also scan the .luau call sites here."""
    out: set[str] = set()
    for rx in _ALL_TOKS:
        for m in rx.finditer(text):
            name = _normalize(m.group(1))
            if name not in NON_SIGNAL_NAMES:
                out.add(name)
    return out


# --- The three invariants ---------------------------------------------------

def check_inv1(text: str) -> tuple[bool, list[str], dict]:
    canonical = extract_canonical_names(text)
    nonsub = extract_nonsubscriptions(text)
    external = set(EXTERNAL_OWNED)
    wired = extract_body_wiring(text)

    accounted = canonical | nonsub | external
    leaks = sorted(n for n in wired if n not in accounted)

    # 1b: every S->C push event must also appear in the F.2 HUD push-contract ROW.
    # round-30 (build-from-artifact R-1): tightened from "anywhere in the F.2 slice" to the
    # specific HUD push-row(s) — the row(s) whose first table cell names HUD. The looser form
    # would be satisfied by any incidental mention of the event name elsewhere in F.2 (e.g. the
    # OnBeaconWindowFailed row or cross-ref prose), so it verified "appears somewhere in F.2,"
    # not "is in the PC->HUD push contract." Falls back to the full slice only if no HUD row is
    # found (so a future F.2 restructure degrades to the old behaviour rather than false-RED).
    s2c = extract_s2c_events(text)
    hud_scope = _f2_hud_pushrow(text)
    hud_missing = sorted(n for n in s2c if not re.search(rf"`{re.escape(n)}`", hud_scope))

    ok = not leaks and not hud_missing
    msgs = []
    for n in leaks:
        msgs.append(f"  LEAK: `{n}` is wired in the body but has no C.9 canonical-table row "
                    f"(and is neither a recorded non-subscription nor on the external allowlist).")
    for n in hud_missing:
        msgs.append(f"  LEAK: S->C event `{n}` is missing from the F.2 HUD push-contract row.")
    stats = {
        "canonical": len(canonical), "nonsub": len(nonsub),
        "external": len(external), "wired": len(wired), "s2c": len(s2c),
    }
    return ok, msgs, stats


def check_inv2(gdd: str, entities: str) -> tuple[bool, list[str], dict]:
    g91 = _section_slice(gdd, r"G\.9\.1\b")
    fields = sorted(_table_first_column_names_backtick(g91))
    if not fields:
        return False, ["  G.9.1 authored-mix-field table not found or empty."], {"fields": 0}
    msgs = []
    for f in fields:
        if not re.search(rf"`{re.escape(f)}`", g91):
            msgs.append(f"  `{f}` not declared in the G.9.1 table.")
        if not re.search(rf"\b{re.escape(f)}\b", entities):
            msgs.append(f"  `{f}` has no declaration site in entities.yaml.")
    return (not msgs), msgs, {"fields": len(fields)}


def _table_first_column_names_backtick(section: str) -> set[str]:
    """First-column backtick identifiers from the AUTHORED-FIELD table only.

    round-30 (build-from-artifact R-2): anchored to the table whose header row's first cell
    labels the field column ("Authored field"), instead of "first column of ANY table in the
    slice." The old form happened to be correct (G.9.1 holds exactly one table) but a second
    table added to G.9.1, or a floor-gated field authored in a non-first column, would have
    been miscounted. We switch ON at the labelled header and only collect backtick names from
    its first column.
    """
    names: set[str] = set()
    in_field_table = False
    for cells in _table_rows(section):
        if not cells:
            continue
        first = cells[0]
        if "`" not in first:
            # A header / label row. Switch into the field table only at the labelled header.
            in_field_table = bool(re.search(r"(?i)\b(authored\s+)?field\b", first))
            continue
        if not in_field_table:
            continue
        for m in re.finditer(r"`([A-Za-z_][A-Za-z0-9_]*)`", first):
            names.add(m.group(1))
    return names


STAMINA_KNOBS = ["STAMINA_MAX", "STAMINA_REGEN_RATE", "STAMINA_REGEN_DELAY", "STAMINA_DRAIN_RATE"]
# round-30 (systems): STATIONARY_EMISSION_FACTOR is the emission-path sign-sensitive knob C.12
# invariant #3 always named but H.12a left ungated until clause (vi). It is gated in clause (vi),
# whose context line names "emission-attenuation factor domain gate" — so the domain context the
# hook scans is widened to include that clause-(vi) line (below).
SIGN_KNOBS = STAMINA_KNOBS + ["STATIONARY_EMISSION_FACTOR"]


def check_inv3(text: str) -> tuple[bool, list[str], dict]:
    msgs = []
    clauses = ["(i)", "(ii)", "(iii)", "(iv)", "(v)", "(vi)"]  # round-30: (vi) added for STATIONARY_EMISSION_FACTOR
    present = [c for c in clauses if re.search(rf"clause\s*{re.escape(c)}", text)]
    if len(present) != len(clauses):
        missing = [c for c in clauses if c not in present]
        msgs.append(f"  H.12a config-validation gate is missing clause(s): {', '.join(missing)}.")
    # The H.12a/G.2 domain-gate block must assert each sign-sensitive knob.
    g2 = _section_slice(text, r"G\.2\b")
    domain_ctx = g2 + "\n" + "\n".join(
        ln for ln in text.splitlines()
        if "stamina-curve domain gate" in ln
        or "H.12a clause (v)" in ln
        or "emission-attenuation factor domain gate" in ln  # round-30 clause (vi) context
        or "clause (vi)" in ln)
    for k in SIGN_KNOBS:
        if not re.search(rf"\b{re.escape(k)}\b", domain_ctx):
            msgs.append(f"  sign-sensitive knob `{k}` has no domain-gate assertion in the H.12a/G.2 block.")
    return (not msgs), msgs, {"clauses": len(present)}


# --- Runner -----------------------------------------------------------------

def run(gdd_path: str, entities_path: str) -> int:
    with open(gdd_path, encoding="utf-8") as fh:
        gdd = fh.read()
    with open(entities_path, encoding="utf-8") as fh:
        entities = fh.read()

    print(f"C.12 Contract Completeness Invariant — checking {os.path.relpath(gdd_path, _REPO)}")
    ok1, m1, s1 = check_inv1(gdd)
    ok2, m2, s2 = check_inv2(gdd, entities)
    ok3, m3, s3 = check_inv3(gdd)

    def line(label, ok, detail):
        dots = "." * max(2, 26 - len(label))
        print(f"  {label} {dots} {'PASS' if ok else 'FAIL'}  {detail}")
        if not ok:
            for msg in detail_msgs.get(label, []):
                print(msg)

    detail_msgs = {
        "inv#1 canonical-table": m1,
        "inv#2 floor-fields": m2,
        "inv#3 sign-knob gates": m3,
    }
    line("inv#1 canonical-table", ok1,
         f"({s1['canonical']} canonical, {s1['s2c']} S->C, {s1['wired']} wired, {s1['nonsub']} non-sub)")
    line("inv#2 floor-fields", ok2, f"({s2['fields']} declared)")
    line("inv#3 sign-knob gates", ok3, f"(clauses i-vi: {s3['clauses']}/6)")

    all_ok = ok1 and ok2 and ok3
    print(f"  RESULT: {'GREEN' if all_ok else 'RED'}")
    return 0 if all_ok else 1


# --- Self-test (proves the hook actually goes RED on a real leak) -----------

def self_test() -> int:
    print("C.12 hook self-test — proving the checker has teeth")
    failures = []

    clean = os.path.join(FIXTURES, "clean_min.md")
    broken = os.path.join(FIXTURES, "broken_missing_row.md")
    for p in (clean, broken):
        if not os.path.exists(p):
            print(f"  MISSING FIXTURE: {p}")
            return 2

    with open(clean, encoding="utf-8") as fh:
        ok, msgs, _ = check_inv1(fh.read())
    print(f"  clean_min.md          -> inv#1 {'PASS' if ok else 'FAIL'} (expect PASS)")
    if not ok:
        failures.append("clean fixture should pass inv#1 but failed: " + "; ".join(msgs))

    with open(broken, encoding="utf-8") as fh:
        ok, msgs, _ = check_inv1(fh.read())
    leaked = (not ok) and any("ReleasePredatorLock" in m for m in msgs)
    print(f"  broken_missing_row.md -> inv#1 {'FAIL (leak detected)' if leaked else 'PASS'} (expect FAIL on ReleasePredatorLock)")
    if not leaked:
        failures.append("broken fixture (missing ReleasePredatorLock row) should fail inv#1 but did not")

    if failures:
        print("  SELF-TEST: BROKEN")
        for f in failures:
            print("   - " + f)
        return 2
    print("  SELF-TEST: OK (checker passes the clean fixture and catches the seeded leak)")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="C.12 Contract Completeness Invariant CI hook")
    ap.add_argument("--gdd", default=DEFAULT_GDD)
    ap.add_argument("--entities", default=DEFAULT_ENTITIES)
    ap.add_argument("--self-test", action="store_true", help="run the fixture-based teeth test and exit")
    args = ap.parse_args(argv)
    try:
        if args.self_test:
            return self_test()
        return run(args.gdd, args.entities)
    except OSError as exc:
        print(f"c12 hook I/O error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
