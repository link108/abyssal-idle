#!/usr/bin/env bash
# Pacing regression check: plays the first run of each policy profile
# (seeded, headless, in parallel) and checks it against the targets in
# check_pacing.py. Takes ~10-15 minutes. Usage: tools/playtest/pacing.sh
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1
OUT=.vdisplay/pace
mkdir -p "$OUT"
for profile in sustainable industrial; do
    tools/playtest/run.sh profile=$profile hours=2.5 runs=1 seed=1 \
        out=res://$OUT/pacing_$profile.json > "$OUT/pacing_$profile.log" 2>&1 &
done
wait
exec tools/playtest/check_pacing.py "$OUT"/pacing_sustainable.json "$OUT"/pacing_industrial.json
