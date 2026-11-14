#!/usr/bin/env python3
# Check playtest reports against the pacing targets (ABYSS-25). Exits
# non-zero if any first-run milestone, reputation gain or ocean average is
# out of range. Usage: tools/playtest/check_pacing.py .vdisplay/pace/*.json
import json
import sys

# Design targets, in in-run minutes for an active player's first run.
MILESTONE_TARGETS = {
    "crew_unlocked": (2.0, 3.0),
    "cannery_unlocked": (4.0, 6.0),
    "first_policy": (10.0, 20.0),
    "all_policies": (60.0, 100.0),
    "prestige_ready": (45.0, 90.0),
}
# One seeded run varies by ~15% between seeds, so the check allows 25%
# either side of the target: it catches regressions (ABYSS-17 made the early
# game 5-10x faster), not seed noise.
TOLERANCE = 0.25
FIRST_PRESTIGE_REP = (20, 120)
SUSTAINABLE_MIN_OCEAN_AVG = 0.85
OCEAN_TOLERANCE = 0.02


def check_report(path):
    report = json.load(open(path))
    profile = report["profile"]
    failures = []

    def check(ok, label):
        print("%s %s: %s" % ("PASS" if ok else "FAIL", profile, label))
        if not ok:
            failures.append(label)

    for name, (low, high) in MILESTONE_TARGETS.items():
        t = report["milestones"].get("%s#0" % name)
        if t is None:
            check(False, "%s never reached (target %g-%g min)" % (name, low, high))
            continue
        minutes = t / 60.0
        ok = low * (1 - TOLERANCE) <= minutes <= high * (1 + TOLERANCE)
        note = "" if low <= minutes <= high else ", within tolerance" if ok else ""
        check(ok, "%s at %.1f min (target %g-%g%s)" % (name, minutes, low, high, note))
    runs = report.get("runs", [])
    if not runs:
        check(False, "no prestige within %d min" % (report["seconds"] // 60))
        return failures
    first = runs[0]
    low, high = FIRST_PRESTIGE_REP
    check(low <= first["rep"] <= high, "first prestige pays %d rep (target %d-%d)" % (first["rep"], low, high))
    if profile == "sustainable":
        check(first["ocean_avg"] >= SUSTAINABLE_MIN_OCEAN_AVG - OCEAN_TOLERANCE,
              "first run ocean average %d%% (target >= %d%%)" % (round(first["ocean_avg"] * 100), SUSTAINABLE_MIN_OCEAN_AVG * 100))
    return failures


failures = []
for path in sys.argv[1:]:
    failures += check_report(path)
print("PACING: %s" % ("ok" if not failures else "%d failure(s)" % len(failures)))
sys.exit(1 if failures else 0)
