#!/usr/bin/env python3
"""
Determinism-preamble Invariant — executable CI hook for the Crafting & Items GDD.

This is the round-25 CD-logged standing falsifier for `design/gdd/crafting-and-items.md`.
It replaces "a future review panel will notice the enumeration drifted" with a
machine-checked gate, retiring the author-discipline dependence the determinism
preamble's own "Forward-maintenance" rule currently relies on. The recurring
reconciliation class it kills cost this GDD a documented run of same-day full
panels (rounds 21-25): a timing AC is added/edited and the preamble enumeration
(or the canonical band literal) is left stale.

It asserts the two invariants the determinism preamble declares:

  DET-1  Enumeration completeness (the "Forward-maintenance" rule made executable).
         Every acceptance criterion whose TEST drives the C.16 clock-injection seam
         -- detected as a body that contains `_clock(` OR (`_step` AND a
         duration/grace/window keyword) -- must be EITHER named in the determinism
         preamble enumeration OR on the explicit, reason-tagged EXCLUDED_ACS
         allowlist below. A new timing AC the author forgets to enumerate (and does
         not consciously allowlist) is a LEAK -> RED. This is exactly the H.97 /
         H.89 / H.116 / H.22 / H.37 / H.92 / H.102 / H.125 / H.129 class.

  DET-2  Canonical band-literal consistency.
         The enforced survival-window predicate is `<= 70.1` and the enforced band
         is `[35.0, 70.1]`. The stale decimal-less band `[35,70]` and the
         pre-round-22 crash predicate `<= 70.0` keep re-seeding a startup-assert
         trap (round-22 / round-23 H.105). This invariant forbids the `70.0` window
         bound anywhere and requires the H.105 config-gate AC to carry the canonical
         `[35.0, 70.1]` band and never the decimal-less `[35,70]` form. The
         legitimate ED-*derived-range* prose ("the window varies across [35,70] s")
         lives OUTSIDE H.105 and is deliberately NOT flagged.

DESIGN NOTE (why this lives in tools/ci as a GDD-static linter, mirroring
c12_completeness_check.py): the project is pre-production -- there is no Crafting
Luau source yet, so the only artifact carrying the determinism contract today is
the GDD prose. When Crafting code lands, the seam detector and band rules are
unchanged; extend the detectors to also scan the .luau test files.

Falsification rule (mirrors the c12 hook): if the enumeration/band class recurs on
a surface THIS HOOK COVERS, the hook is broken -- fix it. If it recurs OUTSIDE the
hook's coverage (a new timing-AC shape the detector misses, or a band literal in a
new location), WIDEN the hook -- add a detector arm or an EXCLUDED_ACS entry; do
not silence a genuine omission.

Usage:
    python tools/ci/determinism_check.py             # check the real Crafting GDD
    python tools/ci/determinism_check.py --self-test # prove the hook has teeth
    python tools/ci/determinism_check.py --gdd <path>

Exit codes: 0 = both invariants GREEN; 1 = an invariant FAILED (red); 2 = hook
self-test or I/O error (the hook itself is broken -- treat as a build failure too).
"""

from __future__ import annotations

import argparse
import os
import re
import sys

# --- Repo-relative defaults -------------------------------------------------

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, "..", ".."))
DEFAULT_GDD = os.path.join(_REPO, "design", "gdd", "crafting-and-items.md")
FIXTURES = os.path.join(_HERE, "determinism_fixtures")

# --- The auditable, explicit part of the contract ---------------------------

# ACs whose body matches the DET-1 seam detector but which are DELIBERATELY not
# enumeration members -- each is a conscious "not a clock-duration assertion"
# declaration a reviewer can audit. Adding to this list is a deliberate act;
# a NEW genuinely-timing AC must NOT be silenced here -- it must be enumerated in
# the preamble (the round-25 gate found H.29 this way and enumerated it, did NOT
# allowlist it).
EXCLUDED_ACS = {
    86:  "static code-inspection AC: asserts the survival-window timer is "
         "Heartbeat-polled (NOT task.delay) -- it ENFORCES the no-wall-clock rule, "
         "it is not a seam-driven duration assertion (Test type: Logic / static analysis).",
    94:  "OnBeaconHoldStateChanged fires on a BEACON_HOLD_RADIUS *position* boundary-cross "
         "during BC4 -- driven by member movement on a `_step`, presentation-only; not a "
         "clock-duration assertion.",
    99:  "data-model invariant: window-end reads ONE per-tick alive-in-radius snapshot "
         "(single source of truth) -- a structural single-read assertion, not a duration/"
         "boundary timing assertion.",
    113: "run-lifecycle latch: a run that ends outside BC4 latches runOutcomeResolved "
         "exactly once -- ordering/latch correctness, not a clock-duration assertion.",
}

# --- DET-1 seam detector ----------------------------------------------------
# An AC's test "drives the C.16 clock-injection seam" if it asserts against an
# injected clock VALUE (`_clock(`) or steps an edge tied to a DURATION/grace/window
# (`_step` AND a duration keyword). `_step` alone is intentionally NOT sufficient:
# position-crossing, tie-break-ordering, wiring and lifecycle ACs step the seam
# without being timing-duration assertions -- they are caught by EXCLUDED_ACS when
# they also carry a duration keyword, and ignored otherwise.
_CLOCK = re.compile(r"_clock\(")
_STEP = re.compile(r"`_step`|\b_step\b")
_DURATION = re.compile(
    r"\bgrace\b|graceSeconds|window-end|window elapse|window still|"
    r"SURVIVAL_WINDOW|HALF_LIFE|LINE_BREAK_GRACE|\blifetime\b|expir|_LIFETIME"
)


def _is_seam_driven(body: str) -> bool:
    return bool(_CLOCK.search(body) or (_STEP.search(body) and _DURATION.search(body)))


# --- Parsing ----------------------------------------------------------------

def _preamble_line(text: str) -> str:
    """The single determinism-preamble blockquote line (starts with
    '> **Determinism preamble'). Empty string if absent."""
    for ln in text.splitlines():
        if ln.startswith("> **Determinism preamble"):
            return ln
    return ""


def extract_enumerated(text: str) -> set[int]:
    """AC numbers named anywhere in the determinism-preamble line. An id appearing
    in the preamble at all means the author consciously placed it (membership or the
    explicit H.39 exclusion note) -- either way it is 'accounted for' in the contract."""
    return {int(n) for n in re.findall(r"H\.(\d+)", _preamble_line(text))}


def extract_acs(text: str) -> dict[int, str]:
    """{ac_number: body} for every AC under the '## Acceptance Criteria' header.
    An AC starts at a line matching '**H.NN' and runs to the next such line."""
    acs: dict[int, str] = {}
    cur: int | None = None
    buf: list[str] = []
    started = False
    for ln in text.splitlines():
        if ln.startswith("## Acceptance Criteria"):
            started = True
        if not started:
            continue
        m = re.match(r"\*\*H\.(\d+)[a-z]?\b", ln)
        if m:
            if cur is not None:
                acs[cur] = "\n".join(buf)
            cur = int(m.group(1))
            buf = [ln]
        elif cur is not None:
            buf.append(ln)
    if cur is not None:
        acs[cur] = "\n".join(buf)
    return acs


# --- DET-1 ------------------------------------------------------------------

def check_det1(text: str) -> tuple[bool, list[str], dict]:
    enum = extract_enumerated(text)
    acs = extract_acs(text)
    accounted = enum | set(EXCLUDED_ACS)
    seam_driven = sorted(h for h, body in acs.items() if _is_seam_driven(body))
    leaks = [h for h in seam_driven if h not in accounted]
    msgs = []
    for h in leaks:
        why = "contains `_clock(`" if _CLOCK.search(acs[h]) else "drives `_step` with a duration/grace/window keyword"
        msgs.append(
            f"  LEAK: H.{h} {why} (its test drives the C.16 seam) but is neither in the "
            f"determinism-preamble enumeration nor on the EXCLUDED_ACS allowlist. "
            f"Enumerate it in the preamble, or -- if it is not a clock-duration assertion -- "
            f"add it to EXCLUDED_ACS with a reason."
        )
    stats = {"seam": len(seam_driven), "enum": len(enum), "excluded": len(EXCLUDED_ACS)}
    return (not leaks), msgs, stats


# --- DET-2 ------------------------------------------------------------------

# The stale ENFORCED predicate form `<= 70.0` / `< 70.0` (the round-22 startup-crash
# literal). Narrowed to a comparison operator immediately before 70.0 so it does NOT
# flag legitimate explanatory prose ("it exceeds a naive `70.0` ceiling", the round-23
# gloss distinguishing the design-target ceiling from the enforced predicate `<= 70.1`).
_STALE_BOUND = re.compile(r"<\s*=?\s*`?\s*70\.0(?!\d)")
_DECIMALLESS_BAND = re.compile(r"\[\s*35\s*,\s*70\b")  # [35,70] / [35, 70] -- decimal-less band
_CANONICAL_BAND = "[35.0, 70.1]"

# DET-2 scans the SPEC, not the history. The leading metadata header (Status /
# Last-Updated narrate "<=70.0 -> <=70.1", "[35,70] -> [35.0, 70.1]" as the record of
# a fix) and HTML comments (fixture documentation) legitimately quote the stale
# literals. The enforced band lives in the H.105 AC + the Formulas/Rules sections;
# rule 2 anchors enforcement at H.105 regardless.
_HTML_COMMENT = re.compile(r"<!--.*?-->", re.DOTALL)
_META_HEADER = re.compile(r"^> \*\*(Status|Last[- ]Updated|Author|Implements Pillar|Implements)\b")


def _strip_noise(text: str) -> str:
    """Remove HTML comments and the leading metadata-header blockquote lines so DET-2's
    global scan sees the spec, not the fix-history narration that quotes stale literals."""
    text = _HTML_COMMENT.sub("", text)
    return "\n".join(ln for ln in text.splitlines() if not _META_HEADER.match(ln))


def _h105_body(text: str) -> str:
    return extract_acs(text).get(105, "")


def check_det2(text: str) -> tuple[bool, list[str], dict]:
    msgs = []
    scoped = _strip_noise(text)
    # Rule 1 (spec-wide): the stale 70.0 window bound must appear nowhere in the spec --
    # the enforced predicate is <= 70.1 and the closed-form upper edge prints 70.08, never 70.0.
    for m in _STALE_BOUND.finditer(scoped):
        ctx = scoped[max(0, m.start() - 40):m.end() + 10].replace("\n", " ")
        msgs.append(f"  STALE PREDICATE: `<= 70.0` window bound (the enforced predicate is `<= 70.1`): ...{ctx.strip()}...")
        break  # one report is enough; the fix is global

    # Rule 2 (H.105 config-gate AC): must carry the canonical band, never the decimal-less form.
    h105 = _h105_body(text)
    if h105:
        if _CANONICAL_BAND not in h105:
            msgs.append(f"  BAND DRIFT: the H.105 config-gate AC does not carry the canonical band `{_CANONICAL_BAND}`.")
        if _DECIMALLESS_BAND.search(h105):
            msgs.append("  BAND DRIFT: the H.105 config-gate AC carries the stale decimal-less band `[35,70]` "
                        "(the enforced band is `[35.0, 70.1]`; the decimal-less form is the ED *derived-range* "
                        "prose and must not appear inside the enforcement AC).")
    stats = {"h105_present": bool(h105)}
    return (not msgs), msgs, stats


# --- Runner -----------------------------------------------------------------

def run(gdd_path: str) -> int:
    with open(gdd_path, encoding="utf-8") as fh:
        gdd = fh.read()
    print(f"Determinism-preamble Invariant — checking {os.path.relpath(gdd_path, _REPO)}")
    ok1, m1, s1 = check_det1(gdd)
    ok2, m2, s2 = check_det2(gdd)

    detail = {"DET-1 enumeration": m1, "DET-2 band-literal": m2}

    def line(label, ok, summary):
        dots = "." * max(2, 26 - len(label))
        print(f"  {label} {dots} {'PASS' if ok else 'FAIL'}  {summary}")
        if not ok:
            for msg in detail[label]:
                print(msg)

    line("DET-1 enumeration", ok1, f"({s1['seam']} seam-driven, {s1['enum']} enumerated, {s1['excluded']} excluded)")
    line("DET-2 band-literal", ok2, "(H.105 present)" if s2["h105_present"] else "(H.105 NOT FOUND)")

    all_ok = ok1 and ok2
    print(f"  RESULT: {'GREEN' if all_ok else 'RED'}")
    return 0 if all_ok else 1


# --- Self-test (proves the hook actually goes RED on a seeded defect) --------

def self_test() -> int:
    print("Determinism hook self-test — proving the checker has teeth")
    failures = []
    clean = os.path.join(FIXTURES, "clean_min.md")
    missing = os.path.join(FIXTURES, "broken_missing_enum.md")
    band = os.path.join(FIXTURES, "broken_stale_band.md")
    for p in (clean, missing, band):
        if not os.path.exists(p):
            print(f"  MISSING FIXTURE: {p}")
            return 2

    def read(p):
        with open(p, encoding="utf-8") as fh:
            return fh.read()

    ok1, _, _ = check_det1(read(clean))
    ok2, _, _ = check_det2(read(clean))
    print(f"  clean_min.md          -> DET-1 {'PASS' if ok1 else 'FAIL'}, DET-2 {'PASS' if ok2 else 'FAIL'} (expect PASS, PASS)")
    if not (ok1 and ok2):
        failures.append("clean fixture should pass both invariants but did not")

    ok1, msgs1, _ = check_det1(read(missing))
    caught = (not ok1) and any("H.200" in m for m in msgs1)
    print(f"  broken_missing_enum.md -> DET-1 {'FAIL (leak detected)' if caught else 'PASS'} (expect FAIL on H.200)")
    if not caught:
        failures.append("broken_missing_enum fixture (un-enumerated H.200) should fail DET-1 but did not")

    ok2, msgs2, _ = check_det2(read(band))
    caught = (not ok2) and any("70.0" in m or "[35,70]" in m for m in msgs2)
    print(f"  broken_stale_band.md  -> DET-2 {'FAIL (band drift detected)' if caught else 'PASS'} (expect FAIL on band)")
    if not caught:
        failures.append("broken_stale_band fixture (stale [35,70]/<= 70.0) should fail DET-2 but did not")

    if failures:
        print("  SELF-TEST: BROKEN")
        for f in failures:
            print("   - " + f)
        return 2
    print("  SELF-TEST: OK (checker passes the clean fixture and catches both seeded defects)")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Determinism-preamble Invariant CI hook (Crafting & Items GDD)")
    ap.add_argument("--gdd", default=DEFAULT_GDD)
    ap.add_argument("--self-test", action="store_true", help="run the fixture-based teeth test and exit")
    args = ap.parse_args(argv)
    try:
        if args.self_test:
            return self_test()
        return run(args.gdd)
    except OSError as exc:
        print(f"determinism hook I/O error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
