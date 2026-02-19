# Abyssal Idle — Repo Inventory (Current State)

## Overview
- Engine: Godot 4.5 (GL Compatibility)
- Main scene: `main.tscn`
- Global state: `GameState` autoload (`scripts/game_state.gd`)
- Current gameplay loop: fish (minigame) -> sell -> money -> upgrades/skills -> cannery -> tins -> sell -> prestige -> endings

## Project Structure (Top-Level)
- `main.tscn` / `main.gd`: HUD + modal screen wiring, timers (sell/autosave), UI orchestration
- `*_screen.tscn` / `*_screen.gd`: Modal panels for core interactions
- `scripts/game_state.gd`: Single source of truth for economy, upgrades, timers, save/load, prestige, endings
- `data/`: JSON data for upgrades, skill tree, and cannery options
- `scenes/ui/`: Reusable UI assets (close button, button styles)
- `docs/`: Design, architecture, and planning docs

## Autoloads
- `GameState` (`scripts/game_state.gd`)

## Core Systems (Implemented)
- Economy
- Resources: `fish_count`, `tin_count`, `money`, `garlic_count`
- Passive sales: `sell_tick()` every second, `SellMode` (fish or tins)
- Prices and counts: `get_fish_sell_price()`, `get_tin_sell_price()`, `get_fish_sell_count()`
- Cannery
- Unlock discovery at lifetime earnings thresholds
- Tinning cooldown (`tin_cooldown_remaining`) and base time (`TIN_MAKE_BASE_TIME`)
- Manual tinning with method/ingredient selection
- Auto-tinning upgrade uses current selections
- Tracks `tin_inventory` by recipe key and `recipes_unlocked`
- Crew
- Unlock discovery at lifetime earnings thresholds
- Crew trip timers and rewards (duration, catch amount)
- Auto-send upgrade support
- Upgrades (including mutually exclusive policy pairs)
- Loaded from `data/upgrades.json`
- Requirements: cannery/crew unlock flags, upgrade levels, and policy stages
- Effects applied via `*_get_effect_total*()` helpers (plus skill effects)
- Prestige + MetaState
- Per-run `tins_sold`, `fish_sold`, run time, and prestige gate at 100 tins
- MetaState: reputation, prestige count, permanent skill choices
- Ocean Health
- Run-state `ocean_health` with regen + pressure, UI meter, and average tracking
- Endings
- Three endings with central checks in `GameState`, ending modal, and run summary
- Save/Load
- JSON save at `user://save.json` (versioned)
- Save includes run state, MetaState, ocean health, ending state, and visible upgrade slots

## Screens / UI
- `start_screen.tscn` / `start_screen.gd`
- Start menu with new/load
- `fishing_screen.tscn` / `fishing_screen.gd`
- Timing-bar minigame, SPACE or button to catch
- Green zone size driven by `GameState.get_green_zone_ratio()`
- `market_screen.tscn` / `market_screen.gd`
- Sell mode toggle (fish/tins)
- Garlic purchase with quantity selector
- `cannery_screen.tscn` / `cannery_screen.gd`
- Method + ingredient selection from `data/cannery_options.json`
- Tin cooldown progress UI
- `upgrade_screen.tscn` / `upgrade_screen.gd`
- Runtime-generated upgrade cards from JSON (category headers, policy pairs side-by-side)
- `skill_tree_screen.tscn` / `skill_tree_screen.gd`
- Skill tree modal with draggable graph + hover details and buy button
- `inventory_screen.tscn` / `inventory_screen.gd`
- Grid listing fish, garlic, and tins by recipe
- `recipe_screen.tscn` / `recipe_screen.gd`
- Grid listing unlocked recipes
- `crew_screen.tscn` / `crew_screen.gd`
- Placeholder list (currently one default entry)
- `scenes/ui/close_button.tscn` / `scenes/ui/close_button.gd`
- Reusable close button emitting `close_requested`
- Ending modal is embedded in `main.tscn`

## Data Files
- `data/upgrades.json`
- Defines upgrade metadata, costs, requirements, and effects
- Includes cannery/crew effects and policy pairs
- `data/skill_tree.json`
- Defines skill tree nodes, positions, costs, requirements, and effects
- `data/cannery_options.json`
- Defines available tin methods and ingredients

## Timers / Loops
- `main.gd`
- Sell timer at `SELL_INTERVAL` (1s)
- Autosave timer at `AUTOSAVE_INTERVAL` (30s)
- `GameState._process()`
- Crew trip countdown and auto-send
- Tin cooldown and auto-tin loop
- Ocean health regen + run-time tracking + ending checks

## Current Architecture Notes
- UI uses a modal pattern: screens are shown/hidden by `main.gd` with a `Dimmer` overlay
- `GameState` emits `changed` plus granular signals (`ocean_health_changed`, `skills_changed`, `reputation_changed`)
- Data-driven upgrades, skill tree, and cannery options are in place

## Not Yet Implemented (From Updated Planning)
- Fish quality and rarity systems (for sustainable/dual endings)
- Multiple fish types, quality, and higher-tier processing
- NG+ mode and full meta progression tuning
