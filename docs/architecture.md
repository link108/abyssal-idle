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
