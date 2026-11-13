#!/usr/bin/env python3
# Summarize playtest JSON files: milestone times per run, prestiges,
# recipes, and income/ocean at fixed times.
# Usage: tools/playtest/summarize.py .vdisplay/playtest/*.json
import json
import sys

MILESTONES = ["earned_100", "crew_unlocked", "cannery_unlocked", "first_tin_sold", "first_recipe",
              "crew_auto_send", "auto_tin", "all_policies", "prestige_ready", "earned_10k", "earned_50k"]


def fmt(seconds):
    if seconds is None:
        return "-"
    seconds = int(seconds)
    return "%d:%02d:%02d" % (seconds // 3600, seconds // 60 % 60, seconds % 60)


for path in sys.argv[1:]:
    report = json.load(open(path))
    print("== %s  profile=%s manual=%.2f explore=%.2f  (%s played)" % (
        path, report["profile"], report["manual_share"], report["explore_share"], fmt(report["seconds"])))
    print("   counters:", report["counters"])
    runs = sorted({int(key.split("#")[1]) for key in report["milestones"]})
    run_starts = {0: 0.0}
    for event in report["events"]:
        if event["kind"] == "prestige":
            run_starts[len(run_starts)] = event["t"]
    print("   %-18s" % "milestone (in run)" + "".join("%11s" % ("run %d" % run) for run in runs[:6]))
    for name in MILESTONES:
        row = []
        for run in runs[:6]:
            t = report["milestones"].get("%s#%d" % (name, run))
            row.append(fmt(None if t is None else t - run_starts.get(run, 0.0)))
        print("   %-18s" % name + "".join("%11s" % cell for cell in row))
    for event in report["events"]:
        if event["kind"] in ("prestige", "recipe", "ending", "time_cap", "policy"):
            print("   %s %-8s %s" % (fmt(event["t"]), event["kind"], event["detail"]))
    print("   %-8s %4s %9s %11s %6s %6s %8s %4s" % ("time", "run", "$/min", "lifetime", "ocean", "upgr", "recipes", "rep"))
    for sample in report["samples"]:
        if sample["t"] % 900 < 60:
            print("   %-8s %4d %9d %11d %5d%% %6d %8d %4d" % (
                fmt(sample["t"]), sample["run"], sample["income_per_min"], sample["lifetime"],
                int(sample["ocean"] * 100), sample["upgrades"], sample["recipes"], sample["rep"]))
    print()
