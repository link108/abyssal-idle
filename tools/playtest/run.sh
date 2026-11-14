#!/usr/bin/env bash
# Run the automated playtest headless (no window anywhere) at fixed time.
# Usage: tools/playtest/run.sh profile=sustainable hours=4 [manual=0.5 explore=0.5 seed=1 runs=N]
# Writes .vdisplay/playtest/<profile>.json (override with out=res://...).
# Each run gets its own throwaway user data dir, so runs can go in parallel.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1
mkdir -p .vdisplay/playtest
DATA="$(mktemp -d "$ROOT/.vdisplay/playtest-data.XXXXXX")"
trap 'rm -rf "$DATA"' EXIT
flatpak run --filesystem="$ROOT" --env=XDG_DATA_HOME="$DATA" \
    org.godotengine.Godot --headless --path "$ROOT" --fixed-fps 4 \
    --script res://tools/playtest/playtest.gd -- "$@"
