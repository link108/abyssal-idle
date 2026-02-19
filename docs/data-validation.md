# Data Validation

This repo validates raw JSON gameplay data in debug builds to catch schema issues early. Validation runs once at startup after core data is loaded and before UI uses it.

## When It Runs

- Debug builds: validation runs and asserts on hard failures.
- Release builds: validation is skipped (or only logs warnings if you call it manually).

Entry point:
- `src/core/game_state.gd` calls `Validators.validate_all(DataRegistry)` in `_run_data_validation()`.

## What It Validates

Structural/type checks:
- Required fields and basic types for each file.
- Cannery options must have `methods` and `ingredients` arrays with `id` and `name`.

Referential integrity:
- `recipes.json` references `fish.json`, `items.json`, and `processes.json`.
- `processes.json` references `equipment.json`.
- `fish.json` references `recipes.json` for `tinned_recipe_ids`.
- `requires` conditions reference valid upgrade/item/equipment IDs.

Duplicate IDs:
- Each file is checked for duplicate IDs (per its ID key).

Requires validation:
- Uses `src/requires/requires_eval.gd` to read `requires`, `unlock_conditions`, or `unlock_condition`.
- All condition objects must have a known `type`.
- Type-specific fields (like `upgrade_id`, `item_id`, `stage`, etc.) are checked for presence and type.

## Files Covered

- `data/raw/upgrades.json`
- `data/raw/skill_tree.json`
- `data/raw/fish.json`
- `data/raw/recipes.json`
- `data/raw/items.json`
- `data/raw/equipment.json`
- `data/raw/processes.json`
- `data/raw/cannery_options.json`

## How To Extend

1. Update `src/data/data_registry.gd` to load any new data file and add lookup maps.
2. Add or extend validation in `src/data/validators.gd`.
3. If new `requires` types are introduced, add them to `KNOWN_REQUIRE_TYPES` and extend `validate_requires`.
