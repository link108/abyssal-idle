#!/usr/bin/env bash
# Run the game on a virtual X display (default :99) so nothing appears on the
# desktop. Uses its own user data dir (.vdisplay/data), never your save.
# Start the display first: Xvfb :99 -screen 0 1152x648x24 -ac -nolisten tcp &
# Usage: tools/vdisplay/play.sh [godot args...]   e.g. --script res://path/to/driver.gd
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 1
mkdir -p .vdisplay/data .vdisplay/shots
DISPLAY="${VDISPLAY:-:99}" exec flatpak run --filesystem="$ROOT" --env=XDG_DATA_HOME="$ROOT/.vdisplay/data" \
    org.godotengine.Godot --path "$ROOT" --resolution 1152x648 --position 0,0 "$@"
