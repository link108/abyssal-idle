# Abyssal Idle - Architecture

## Goals
- Keep runtime gameplay logic centralized and stable.
- Keep content data-driven via JSON in `data/raw/`.
- Make data validation + typed model mapping incremental and safe.

## Current Structure (Refactored)
- `res://main.tscn` + `res://main.gd`: top-level UI and game loop wiring
- `res://src/core/game_state.gd`: core state + loading + progression logic
- `res://src/requires/requires_eval.gd`: shared requirement evaluation
- `res://src/ui/screens/*`: co-located screen scenes/scripts
- `res://src/ui/components/*`: reusable UI components and style resources
- `res://data/raw/*.json`: raw gameplay data definitions

## Runtime Data Loading (Current)
- `GameState` loads raw JSON directly from `data/raw/`.
- Loaded defs are stored as dictionaries and looked up by ID maps.
- Requires gating is centralized in `RequiresEval`.

## Data Loading & Validation Approach (Future)
- Keep `data/raw/*.json` as source-of-truth content files.
- Add lightweight schema checks in `src/data/validators.gd`:
  - shape checks (required fields, basic types)
  - cross-reference checks (IDs across files)
  - clear, contextual warnings for fast authoring feedback
- Add typed-ish model mapping in `src/data/models/`:
  - parse raw dictionaries into explicit model objects
  - keep `from_dict` parsing simple and deterministic
- Add per-domain loaders in `src/data/loaders/`:
  - file read + validation + model construction
  - return arrays/maps ready for game systems
- Add `src/data/data_registry.gd` as an integration point:
  - centralized cache of loaded model sets
  - single `load_all()` entrypoint for startup
  - support dev-only reload/clear flows

This migration should be incremental: start with one dataset (fish), verify parity, then move other datasets.

## Headless Tests

Run `tests/run_headless_tests.sh` from the repo root. It runs every
`tests/headless/test_*.gd` script and then boots `main.tscn` headless, and exits
non-zero if any check fails or the boot prints an error. It uses `godot` when on
PATH, otherwise the Flathub build (`flatpak run org.godotengine.Godot`).

To add a test, create `tests/headless/test_<name>.gd` extending
`res://tests/headless/test_base.gd`, override `run_tests(gs)` and call
`check(condition, label)`. The runner gives Godot its own user data dir
(`.vdisplay/test-data`), so code that saves (`new_game()`, `prestige()`) never
touches the player's `user://save.json`. Run tests through the runner, not
Godot directly, and prefer setting state on `gs` directly.

## Virtual Display (screenshots and play)

`tools/vdisplay/` runs the real game on a hidden X display, so it never opens
a window on the desktop. It needs `xvfb` and `xdotool`.

```
Xvfb :99 -screen 0 1152x648x24 -ac -nolisten tcp &   # once per session
tools/vdisplay/play.sh                                # the game, on :99
DISPLAY=:99 xdotool mousemove 575 360 click 1         # input
tools/vdisplay/shot.py out.png                        # screenshot
tools/vdisplay/fish_bot.py 20                         # play the catch minigame
tools/vdisplay/play.sh --script res://tools/vdisplay/capture_example.gd
```

Runs use their own user data dir (`.vdisplay/data`, gitignored), so they
never touch your save. `capture_example.gd` is a driver that sets state,
opens screens and saves PNGs to `.vdisplay/shots`; copy and adapt it.

## Playtest Bot and Pacing Check

`tools/playtest/run.sh profile=sustainable hours=2 [runs=N seed=S]` plays the
real game headless at fixed time and writes a JSON report;
`tools/playtest/summarize.py` prints it. `tools/playtest/pacing.sh` plays the
first run of both policy profiles (~15 minutes) and checks the milestones
against the pacing targets in `tools/playtest/check_pacing.py`. Run it after
changing costs, prices, catch rates or prestige; it is too slow for
`run_headless_tests.sh`, which instead runs the quick ocean/income sim in
`test_ocean_balance.gd`.
