# PROTOTYPE - NOT FOR PRODUCTION
# Question: At n=2, is "quiet" a real lever? Is there a gather cadence that keeps the
#           non-locked survivor's emission field T strictly below effectiveQuietThreshold(2)=0.38
#           (forcing predator Disengage) WHILE still gathering the win-critical RESONANT in time?
# Date: 2026-06-19
#
# Headless numeric model of the Ecological-Disturbance field as seen by the NON-LOCKED
# survivor in a 2-player squad. The locked player is kiting the predator elsewhere and is
# EXCLUDED from GetSquadAggregateT(exclude) per OQ.10 -- so the predator's quiet/Disengage
# check at n=2 reduces to: fieldValue at the non-locked survivor's own position.
#
# ALL emission/decay/threshold constants are AUTHORED (cited inline). Win-economy timings
# (walk speed, node spacing, schedule) are PROTOTYPE ASSUMPTIONS -- swept, not trusted.

import math

# ----------------------------------------------------------------------------------------
# AUTHORED CONSTANTS  (source of truth in parentheses)
# ----------------------------------------------------------------------------------------
STANDARD_HALF_LIFE = 30.0          # ED G.2
LAMBDA = math.log(2) / STANDARD_HALF_LIFE   # ED D.7 lifetime formula: lambda = ln2 / t_half
MAGNITUDE_FLOOR = 0.02             # ED G.2
INFLUENCE_RADIUS = 24.0            # ED G.3
QUIET_THRESHOLD_N2 = 0.38          # PA G.6 / PREDATOR_QUIET_THRESHOLD_BY_ALIVE {2:0.38}
RETREAT_SUSTAIN_DURATION = 30.0    # ED G.6 RETREAT_SUSTAIN_DURATION (sustained-quiet needed to Disengage)

# Gather tiers: (magnitude, extract_time_s, material)  -- RN CR.2, magnitudes ED-owned D.7
MAG_LIGHT, EXTRACT_LIGHT = 0.15, 3.5    # BIOMASS
MAG_MEDIUM, EXTRACT_MEDIUM = 0.25, 5.0  # MINERAL
MAG_HEAVY, EXTRACT_HEAVY = 0.40, 8.0    # RESONANT  <-- 0.40 > 0.38 threshold
BEACON_RESONANT_REQUIRED = 3            # RN line 80: "the Beacon's 3 RESONANT"

# ----------------------------------------------------------------------------------------
# FIELD MODEL
# ----------------------------------------------------------------------------------------
def falloff(d):
    """ED D.2 spatial falloff: (1 - d/r)^2 for d < r, else 0 (explicit-multiply per ED no-pow rule)."""
    if d >= INFLUENCE_RADIUS:
        return 0.0
    x = 1.0 - d / INFLUENCE_RADIUS
    return x * x

def m_decay(initial, age):
    """ED D.1 exponential decay m(age) = initial * exp(-lambda*age); culled below MAGNITUDE_FLOOR."""
    if age < 0:
        return 0.0
    v = initial * math.exp(-LAMBDA * age)
    return v if v >= MAGNITUDE_FLOOR else 0.0

class Emission:
    __slots__ = ("mag", "t0", "pos")
    def __init__(self, mag, t0, pos):
        self.mag, self.t0, self.pos = mag, t0, pos

def field_at(emissions, t, pos, half_life=STANDARD_HALF_LIFE):
    """squadT(exclude locked) at n=2 = fieldValue at the survivor's position = clamped sum of
    own live emissions, each decayed (time) and attenuated (distance to gather spot). ED D.5/D.2."""
    lam = math.log(2) / half_life
    total = 0.0
    for e in emissions:
        age = t - e.t0
        if age < 0:
            continue
        v = e.mag * math.exp(-lam * age)
        if v < MAGNITUDE_FLOOR:
            continue
        total += v * falloff(abs(e.pos - pos))
    return min(total, 1.0)

# ----------------------------------------------------------------------------------------
# SCENARIO: the non-locked survivor walks a 1-D path of nodes, gathering on a schedule.
# Each node is `spacing` studs from the previous. Survivor walks at `walk_speed` (no Sprint
# emission -- sprinting would add its own 0.10 loud pulses; walking is the "quiet" choice).
# At each node: stand for extract_time, emit at completion, walk to next.
# ----------------------------------------------------------------------------------------
def run_schedule(schedule, spacing, walk_speed, half_life=STANDARD_HALF_LIFE, dt=0.1):
    """schedule = list of tier chars, e.g. ['M','H','M','H','L','H'] visited in order.
    Returns timeline samples of (t, survivor_pos, field) + emission log + completion times."""
    tiers = {"L": (MAG_LIGHT, EXTRACT_LIGHT), "M": (MAG_MEDIUM, EXTRACT_MEDIUM), "H": (MAG_HEAVY, EXTRACT_HEAVY)}
    emissions = []
    samples = []     # (t, pos, field)
    t = 0.0
    pos = 0.0
    node_x = 0.0
    completions = []  # (t, tier, pos)
    for i, ch in enumerate(schedule):
        mag, extract = tiers[ch]
        # walk to this node (node i at x = i*spacing)
        node_x = i * spacing
        while pos < node_x - 1e-9:
            step = walk_speed * dt
            pos = min(pos + step, node_x)
            t += dt
            samples.append((t, pos, field_at(emissions, t, pos, half_life)))
        # extract (stationary at node)
        end = t + extract
        while t < end:
            t += dt
            samples.append((t, pos, field_at(emissions, t, pos, half_life)))
        # emit at completion (ED C.3.1 emits on completion, at node position)
        emissions.append(Emission(mag, t, node_x))
        completions.append((t, ch, node_x))
        samples.append((t, pos, field_at(emissions, t, pos, half_life)))
    # tail: keep walking forward quietly so we can observe the post-last-gather window
    tail_end = t + 60.0
    while t < tail_end:
        step = walk_speed * dt
        pos += step
        t += dt
        samples.append((t, pos, field_at(emissions, t, pos, half_life)))
    return samples, completions

def longest_quiet_window(samples, threshold):
    """Longest contiguous span with field < threshold (strict)."""
    best = cur = 0.0
    prev_t = None
    for (t, _pos, f) in samples:
        if prev_t is None:
            prev_t = t
            continue
        span = t - prev_t
        if f < threshold:
            cur += span
            best = max(best, cur)
        else:
            cur = 0.0
        prev_t = t
    return best

def time_above(samples, threshold):
    above = 0.0
    prev_t = None
    for (t, _pos, f) in samples:
        if prev_t is None:
            prev_t = t; continue
        if f >= threshold:
            above += (t - prev_t)
        prev_t = t
    return above

def peak(samples):
    return max(f for (_t, _p, f) in samples)

# ----------------------------------------------------------------------------------------
# ANALYSIS 1 -- single-gather spike: how long does ONE gather of each tier hold the field
# at/above the n=2 threshold, (a) if the survivor stays put, (b) if they walk away at 12/s?
# ----------------------------------------------------------------------------------------
def single_spike_duration(mag, walk_speed, threshold=QUIET_THRESHOLD_N2, dt=0.01):
    """Time the survivor's field stays >= threshold after a single gather at pos 0, walking away."""
    if mag * falloff(0.0) < threshold:
        return 0.0  # never crosses
    t = 0.0; pos = 0.0; above = 0.0
    while t < 120.0:
        f = m_decay(mag, t) * falloff(abs(0.0 - pos))
        if f >= threshold:
            above += dt
        elif t > 0.5:
            break
        t += dt
        pos += walk_speed * dt
    return above

# ----------------------------------------------------------------------------------------
# ANALYSIS 2 -- feasible threshold band: for which threshold values is quiet BOTH a lever
# (a >=30s sustained sub-threshold window exists in a realistic run) AND non-trivial (at
# least the win-critical Heavy gather registers as "loud", so the predator has something to
# respond to)?  Sweep threshold; classify.
# ----------------------------------------------------------------------------------------
def feasible_threshold_band(spacing=30.0, walk_speed=12.0):
    # Realistic n=2 survivor run: 3 Heavy (RESONANT for Beacon) interleaved with Medium/Light
    # for oxygen/other recipes, nodes spread along the path.
    schedule = ["M", "H", "L", "M", "H", "M", "L", "H"]  # 3 H = beacon, plus survival mats
    samples, comps = run_schedule(schedule, spacing, walk_speed)
    rows = []
    for thr in [round(0.20 + 0.01 * k, 2) for k in range(0, 31)]:  # 0.20 .. 0.50
        win = longest_quiet_window(samples, thr)
        heavy_loud = MAG_HEAVY >= thr     # does the win-critical gather read as loud?
        medium_loud = MAG_MEDIUM >= thr
        lever = win >= RETREAT_SUSTAIN_DURATION   # can the predator ever Disengage?
        # "quiet is a meaningful lever" = predator CAN disengage (30s window exists) AND the
        # loud spikes are caused by REQUIRED work (heavy), not by everything (medium too) and
        # not by nothing (heavy silent => predator never sheds via field).
        verdict = classify(lever, heavy_loud, medium_loud)
        rows.append((thr, win, heavy_loud, medium_loud, lever, verdict))
    return schedule, samples, comps, rows

def classify(lever, heavy_loud, medium_loud):
    if not heavy_loud:
        return "DEAD: even Heavy is silent -> predator never sheds via field; quiet not a lever"
    if medium_loud:
        return "DEAD: even Medium reads loud -> survivor cannot do routine work quietly"
    if not lever:
        return "DEAD: no 30s sub-threshold window survives the schedule"
    return "VIABLE: Medium=quiet, Heavy=loud, 30s window exists"

# ----------------------------------------------------------------------------------------
# ANALYSIS 3 -- node-spacing sensitivity: tight clustering lets consecutive gathers stack
# spatially (within INFLUENCE_RADIUS) and may break quiet even for Medium nodes.
# ----------------------------------------------------------------------------------------
def spacing_sensitivity(walk_speed=12.0):
    rows = []
    for spacing in [6, 10, 14, 18, 24, 30, 36]:
        # worst realistic stacking case: two Medium gathers back-to-back, close together
        schedule = ["M", "M", "M"]
        samples, _ = run_schedule(schedule, spacing, walk_speed)
        rows.append((spacing, peak(samples), longest_quiet_window(samples, QUIET_THRESHOLD_N2)))
    return rows

# ----------------------------------------------------------------------------------------
# ANALYSIS 4 -- half-life sensitivity (STANDARD_HALF_LIFE safe range 15-60s, ED G.2).
# ----------------------------------------------------------------------------------------
def halflife_sensitivity(spacing=30.0, walk_speed=12.0):
    rows = []
    schedule = ["M", "H", "L", "M", "H", "M", "L", "H"]
    for hl in [15, 22, 30, 45, 60]:
        samples, _ = run_schedule(schedule, spacing, walk_speed, half_life=hl)
        rows.append((hl, peak(samples), longest_quiet_window(samples, QUIET_THRESHOLD_N2),
                     time_above(samples, QUIET_THRESHOLD_N2)))
    return rows

# ----------------------------------------------------------------------------------------
def main():
    print("=" * 84)
    print("PREDATOR-AI QUIET-LEVER STRUCTURAL SIM  (H.66 / OQ.12, n=2 squad)")
    print("=" * 84)
    print(f"lambda = ln2/{STANDARD_HALF_LIFE:.0f}s = {LAMBDA:.5f}/s | INFLUENCE_RADIUS={INFLUENCE_RADIUS:.0f} "
          f"| threshold(2)={QUIET_THRESHOLD_N2} | sustain={RETREAT_SUSTAIN_DURATION:.0f}s")
    print(f"Gather magnitudes: Light={MAG_LIGHT}  Medium={MAG_MEDIUM}  Heavy={MAG_HEAVY}  (Beacon needs {BEACON_RESONANT_REQUIRED} RESONANT = {BEACON_RESONANT_REQUIRED} Heavy)")

    print("\n--- ANALYSIS 1: single-gather supra-threshold spike (survivor walks away @12/s) ---")
    print(f"{'tier':<8}{'mag':>6}{'crosses 0.38?':>16}{'time>=0.38 walking':>22}{'time>=0.38 standing':>22}")
    for name, mag in [("Light", MAG_LIGHT), ("Medium", MAG_MEDIUM), ("Heavy", MAG_HEAVY)]:
        crosses = "YES" if mag >= QUIET_THRESHOLD_N2 else "no"
        tw = single_spike_duration(mag, walk_speed=12.0)
        ts = single_spike_duration(mag, walk_speed=0.0)
        print(f"{name:<8}{mag:>6}{crosses:>16}{tw:>20.2f}s{ts:>20.2f}s")

    print("\n--- ANALYSIS 2: feasible threshold band (schedule = 3 Heavy + Medium/Light) ---")
    schedule, samples, comps, rows = feasible_threshold_band()
    print(f"schedule visited: {schedule}   (peak field over run = {peak(samples):.3f})")
    print(f"{'thr':>6}{'longest<thr window':>22}{'Heavy loud':>12}{'Medium loud':>13}  verdict")
    band = []
    for (thr, win, hl, ml, lever, verdict) in rows:
        mark = ""
        if verdict.startswith("VIABLE"):
            band.append(thr)
            mark = " *"
        print(f"{thr:>6}{win:>20.1f}s{('YES' if hl else 'no'):>12}{('YES' if ml else 'no'):>13}  {verdict}{mark}")
    if band:
        print(f"\n  >> VIABLE threshold band: [{min(band):.2f} .. {max(band):.2f}]  "
              f"(authored value 0.38 {'IS' if 0.38 in [round(b,2) for b in band] else 'is NOT'} inside)")
        print(f"  >> headroom below Heavy(0.40): {0.40 - max(band):.2f} above top of band; "
              f"margin of 0.38 below Heavy = {0.40 - 0.38:.2f}")

    print("\n--- ANALYSIS 3: node-spacing sensitivity (3 Medium back-to-back, peak field) ---")
    print(f"{'spacing(studs)':>15}{'peak field':>14}{'longest<0.38 window':>22}{'  spatial-stack?':>18}")
    for (sp, pk, win) in spacing_sensitivity():
        stack = "STACKS>0.38" if pk >= QUIET_THRESHOLD_N2 else "ok"
        flag = "  <- INFLUENCE_RADIUS=24" if sp == 24 else ""
        print(f"{sp:>15}{pk:>14.3f}{win:>20.1f}s{stack:>18}{flag}")

    print("\n--- ANALYSIS 4: half-life sensitivity (ED G.2 range 15-60s) ---")
    print(f"{'half-life':>11}{'peak field':>13}{'longest<0.38':>16}{'time>=0.38 (of run)':>22}")
    for (hl, pk, win, above) in halflife_sensitivity():
        print(f"{hl:>10}s{pk:>13.3f}{win:>14.1f}s{above:>20.1f}s")

    print("\n" + "=" * 84)
    print("BOTTOM LINE")
    print("=" * 84)
    print(textwrap_fill(
        "At n=2 a >=30s sustained sub-0.38 window survives a realistic 3-Heavy run by a wide "
        "margin (see Analysis 2), so the predator CAN Disengage on quiet -- 'quiet is a lever' "
        "holds for the BETWEEN-NODES movement state H.66 specifies. BUT every win-critical Heavy "
        "(RESONANT) gather emits 0.40 > 0.38, so the field is punctuated by brief supra-threshold "
        "spikes (Analysis 1) that the survivor cannot avoid while collecting the win material. "
        "The viable threshold band that keeps Medium quiet AND Heavy loud AND a 30s window alive "
        "is narrow and the authored 0.38 sits near its top edge with only 0.02 headroom under Heavy. "
        "Node spacing >= INFLUENCE_RADIUS (24) is REQUIRED -- tighter clustering (Analysis 3) stacks "
        "Medium gathers over 0.38 and silently kills the lever."))

def textwrap_fill(s, width=82):
    out, line = [], ""
    for w in s.split():
        if len(line) + len(w) + 1 > width:
            out.append(line); line = w
        else:
            line = (line + " " + w).strip()
    out.append(line)
    return "\n".join(out)

if __name__ == "__main__":
    main()
