# Abyssal Idle — Repo Inventory

## Overview
- Engine: Godot 4.5 (GL Compatibility)
- Main scene: `res://main.tscn`
- Autoload: `GameState` at `res://src/core/game_state.gd`

## Layout Conventions
- `src/core/`: game-wide state and core systems
- `src/requires/`: shared requirement-evaluation logic
- `src/ui/screens/<screen_name>/`: each modal screen scene + script co-located
- `src/ui/components/`: reusable UI scenes/scripts/styles
- `data/raw/`: source JSON data files
- `data/schemas/`: schema placeholder for future validation specs
- `planning/`: milestone/project planning docs (renamed from `projects/`)

## Key Runtime Files
- `main.tscn`, `main.gd`: HUD, modal orchestration, timers
- `src/core/game_state.gd`: economy, upgrades, fish/recipe defs, save/load, endings
- `src/requires/requires_eval.gd`: shared `requires` compatibility + evaluator

## UI Screens
- `src/ui/screens/start/start_screen.tscn`
- `src/ui/screens/fishing/fishing_screen.tscn`
- `src/ui/screens/cannery/cannery_screen.tscn`
- `src/ui/screens/market/market_screen.tscn`
- `src/ui/screens/upgrade/upgrade_screen.tscn`
- `src/ui/screens/skill_tree/skill_tree_screen.tscn`
- `src/ui/screens/skill_tree/skill_tree_graph.gd`
- `src/ui/screens/inventory/inventory_screen.tscn`
- `src/ui/screens/recipe/recipe_screen.tscn`
- `src/ui/screens/crew/crew_screen.tscn`
- `src/ui/screens/collections/collections_screen.tscn`

## UI Components
- `src/ui/components/close_button/close_button.tscn`
- `src/ui/components/styles/button_color_normal.tres`
- `src/ui/components/styles/button_color_pressed.tres`
- `src/ui/components/styles/market-sell-button-group.tres`

## Data Files
- `data/raw/upgrades.json`
- `data/raw/skill_tree.json`
- `data/raw/fish.json`
- `data/raw/recipes.json`
- `data/raw/items.json`
- `data/raw/equipment.json`
- `data/raw/processes.json`
- `data/raw/cannery_options.json`

## Next-Phase Scaffolding
- `src/data/data_registry.gd`
- `src/data/validators.gd`
- `src/data/models/fish.gd`
- `src/data/loaders/fish_loader.gd`
