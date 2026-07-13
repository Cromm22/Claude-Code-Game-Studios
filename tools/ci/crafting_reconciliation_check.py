#!/usr/bin/env python3
"""
Crafting & Items reconciliation invariant — executable CI hook.

A round-25 hardening pass companion to `tools/ci/determinism_check.py`, for
`design/gdd/crafting-and-items.md`. It machine-checks the ONE broad-reconciliation
sub-class that is robustly grep-able: the section-preamble COUNT CLAIMS.

  REC-1  Count consistency. The AC section preamble claims "enumerates N live
         acceptance criteria (numbered through H.M; K retired ...)"; the Edge-Cases
         section preamble claims "enumerates N2 live edge cases (numbered through
         E.M2 ...)". This invariant recomputes the actuals from the headers
         (live = `**H.NN`/`**E.NN` headers NOT marked with the italic stub form
         `*REMOVED (round-X)*` / `*RETIRED (round-X)*`; retired = the stub headers)
         and asserts every claimed number matches. Count drift is a documented
         recurring reconciliation defect (reviews repeatedly hand-verify "122/32").

WHY ONLY COUNTS (the deliberate scope, recorded so a later author does not "widen"
this into a noisy linter): the DOMINANT reconciliation class — a fix landing on one
normative surface while a sibling surface stays stale — is NOT reliably grep-able for
this GDD. The document legitimately narrates its own history and reuses tokens with
multiple meanings, so a forbidden-token linter is dominated by false positives. Worked
examples from the round-25 hardening investigation:
  - "30 studs" is SIGNAL_ANCHOR_DETECTION_RADIUS (legitimately 30), NOT the stale
    BEACON_HOLD_RADIUS (12);
  - "8 events/s" is the rate-limit reachability discussion, NOT the "7 named events" count;
  - "Squad Relay" / "RELAY" (40+ mentions) is legitimate narration of the round-5 cut;
  - `requiredHolders = ceil(#aliveMembers/2)` is an accepted round-15 shorthand that
    coexists with the canonical round-19 `min(requiredHoldersBaseline, #aliveMembers)`
    — a gloss-vs-canonical split a grep cannot adjudicate.
The two precisely-checkable surfaces (the determinism-preamble enumeration and the
canonical band literal) are covered by determinism_check.py; the C.9 contract surface
by c12_completeness_check.py. The residual stale-sibling class stays a human review-
discipline item by necessity, NOT for lack of effort.

Falsification rule (mirrors the c12 / determinism hooks): if a count claim drifts
from the headers, this hook is the gate that catches it. If a NEW count claim appears
(e.g. a VA-moment total), widen REC-1 to parse it; never relax an assertion to make a
real drift pass.

Usage:
    python tools/ci/crafting_reconciliation_check.py             # check the real GDD
    python tools/ci/crafting_reconciliation_check.py --self-test # prove the hook has teeth
    python tools/ci/crafting_reconciliation_check.py --gdd <path>

Exit codes: 0 = REC-1 GREEN; 1 = a count claim FAILED (red); 2 = hook self-test or
I/O error (the hook itself is broken -- treat as a build failure too).
"""

from __future__ import annotations

import argparse
import os
import re
import sys

_HERE = os.path.dirname(os.path.abspath(__file__))
_REPO = os.path.abspath(os.path.join(_HERE, "..", ".."))
DEFAULT_GDD = os.path.join(_REPO, "design", "gdd", "crafting-and-items.md")
FIXTURES = os.path.join(_HERE, "crafting_reconciliation_fixtures")

# The italic stub marker a retired AC/edge header carries, e.g.
#   **H.18, H.19, H.20 — *REMOVED (round-2, 2026-06-01)*** — ...
#   **H.23 — *RETIRED (round-5, R4-2)*** — ...
# Anchored to the parenthesised round so it does NOT match a LIVE header whose title
# merely contains the word "retired"/"removed" (e.g. H.37, H.55 do).
_STUB = re.compile(r"\*(?:REMOVED|RETIRED)\s*\(", re.I)

# Section-preamble count claims.
_AC_CLAIM = re.compile(
    r"enumerates\s+(\d+)\s+live acceptance criteria\s*\(numbered through H\.(\d+);\s*(\d+)\s+retired")
_EC_CLAIM = re.compile(
    r"enumerates\s+(\d+)\s+live edge cases\s*\(numbered through E\.(\d+)")


def _header_title(line: str) -> str:
    """The header text up to the first em-dash / ' - ' separator (the part that names
    the AC/edge number(s); a retired stub may list several, a live header names one)."""
    for sep in ("—", " - "):
        if sep in line:
            return line.split(sep, 1)[0]
    return line


def _classify(prefix: str, text: str) -> tuple[set[int], set[int]]:
    """Return (live, retired) sets of NN for headers `**{prefix}.NN`.
    live = the leading number of a non-stub header; retired = all numbers in a stub header."""
    live: set[int] = set()
    retired: set[int] = set()
    hdr = re.compile(rf"^\*\*{re.escape(prefix)}\.(\d+)\b")
    for line in text.splitlines():
        if not hdr.match(line):
            continue
        title = _header_title(line)
        nums = [int(n) for n in re.findall(rf"{re.escape(prefix)}\.(\d+)", title)]
        if not nums:
            continue
        if _STUB.search(line):
            retired.update(nums)
        else:
            live.add(nums[0])
    return live, retired


def check_rec1(text: str) -> tuple[bool, list[str], dict]:
    msgs = []
    stats = {}

    # --- Acceptance Criteria ---
    m = _AC_CLAIM.search(text)
    if not m:
        msgs.append("  AC count claim sentence not found "
                    "(expected 'enumerates N live acceptance criteria (numbered through H.M; K retired').")
        ac_claim = None
    else:
        ac_claim = (int(m.group(1)), int(m.group(2)), int(m.group(3)))  # live, maxH, retired
    live_ac, ret_ac = _classify("H", text)
    if ac_claim:
        claim_live, claim_max, claim_ret = ac_claim
        if len(live_ac) != claim_live:
            msgs.append(f"  AC LIVE COUNT: claim {claim_live}, actual {len(live_ac)} live `**H.NN` headers.")
        if (max(live_ac) if live_ac else 0) != claim_max:
            msgs.append(f"  AC MAX: claim 'through H.{claim_max}', actual max live H.{max(live_ac) if live_ac else 0}.")
        if len(ret_ac) != claim_ret:
            msgs.append(f"  AC RETIRED COUNT: claim {claim_ret}, actual {len(ret_ac)} retired stub(s) {sorted(ret_ac)}.")
    stats["ac_live"] = len(live_ac)
    stats["ac_retired"] = len(ret_ac)

    # --- Edge Cases ---
    m = _EC_CLAIM.search(text)
    if not m:
        msgs.append("  Edge-case count claim sentence not found "
                    "(expected 'enumerates N live edge cases (numbered through E.M').")
        ec_claim = None
    else:
        ec_claim = (int(m.group(1)), int(m.group(2)))  # live, maxE
    live_ec, _ret_ec = _classify("E", text)
    if ec_claim:
        claim_live, claim_max = ec_claim
        if len(live_ec) != claim_live:
            msgs.append(f"  EDGE LIVE COUNT: claim {claim_live}, actual {len(live_ec)} live `**E.NN` headers.")
        if (max(live_ec) if live_ec else 0) != claim_max:
            msgs.append(f"  EDGE MAX: claim 'through E.{claim_max}', actual max live E.{max(live_ec) if live_ec else 0}.")
    stats["ec_live"] = len(live_ec)

    return (not msgs), msgs, stats


def run(gdd_path: str) -> int:
    with open(gdd_path, encoding="utf-8") as fh:
        gdd = fh.read()
    print(f"Crafting reconciliation invariant — checking {os.path.relpath(gdd_path, _REPO)}")
    ok, msgs, s = check_rec1(gdd)
    label = "REC-1 count-consistency"
    dots = "." * max(2, 26 - len(label))
    summary = f"({s.get('ac_live', 0)} live ACs, {s.get('ac_retired', 0)} retired, {s.get('ec_live', 0)} live edges)"
    print(f"  {label} {dots} {'PASS' if ok else 'FAIL'}  {summary}")
    if not ok:
        for msg in msgs:
            print(msg)
    print(f"  RESULT: {'GREEN' if ok else 'RED'}")
    return 0 if ok else 1


def self_test() -> int:
    print("Crafting reconciliation hook self-test — proving the checker has teeth")
    failures = []
    clean = os.path.join(FIXTURES, "clean_min.md")
    broken = os.path.join(FIXTURES, "broken_count.md")
    for p in (clean, broken):
        if not os.path.exists(p):
            print(f"  MISSING FIXTURE: {p}")
            return 2

    def read(p):
        with open(p, encoding="utf-8") as fh:
            return fh.read()

    ok, _, _ = check_rec1(read(clean))
    print(f"  clean_min.md     -> REC-1 {'PASS' if ok else 'FAIL'} (expect PASS)")
    if not ok:
        failures.append("clean fixture should pass REC-1 but did not")

    ok, msgs, _ = check_rec1(read(broken))
    caught = (not ok) and any("LIVE COUNT" in m or "MAX" in m for m in msgs)
    print(f"  broken_count.md  -> REC-1 {'FAIL (drift detected)' if caught else 'PASS'} (expect FAIL on count + max)")
    if not caught:
        failures.append("broken_count fixture (claim 4 vs 3 live, E.4 vs E.3) should fail REC-1 but did not")

    if failures:
        print("  SELF-TEST: BROKEN")
        for f in failures:
            print("   - " + f)
        return 2
    print("  SELF-TEST: OK (checker passes the clean fixture and catches the seeded count drift)")
    return 0


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Crafting & Items reconciliation (count-consistency) CI hook")
    ap.add_argument("--gdd", default=DEFAULT_GDD)
    ap.add_argument("--self-test", action="store_true", help="run the fixture-based teeth test and exit")
    args = ap.parse_args(argv)
    try:
        if args.self_test:
            return self_test()
        return run(args.gdd)
    except OSError as exc:
        print(f"crafting reconciliation hook I/O error: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
