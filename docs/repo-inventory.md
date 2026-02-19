# Abyssal Idle — Repo Inventory (Current State)

## Overview
- Engine: Godot 4.5 (GL Compatibility)
- Main scene: `main.tscn`
- Global state: `GameState` autoload (`scripts/game_state.gd`)
- Current gameplay loop: fish (minigame) -> sell -> money -> upgrades -> cannery -> tins -> sell

## Project Structure (Top-Level)
- `main.tscn` / `main.gd`: HUD + modal screen wiring, timers (sell/autosave), UI orchestration
- `*_screen.tscn` / `*_screen.gd`: Modal panels for core interactions
- `scripts/game_state.gd`: Single source of truth for economy, upgrades, timers, save/load
- `data/`: JSON data for upgrades and cannery options
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
- Upgrades
- Loaded from `data/upgrades.json`
- Requirements: cannery/crew unlock flags and upgrade levels
- Effects applied via `*_get_effect_total*()` helpers
- Save/Load
- JSON save at `user://save.json`
- Save includes economy, unlock flags, upgrades, recipes, crew trip state
- Save currently captures run state only (no MetaState yet)

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
- Runtime-generated upgrade cards from JSON
- `inventory_screen.tscn` / `inventory_screen.gd`
- Grid listing fish, garlic, and tins by recipe
- `recipe_screen.tscn` / `recipe_screen.gd`
- Grid listing unlocked recipes
- `crew_screen.tscn` / `crew_screen.gd`
- Placeholder list (currently one default entry)
- `scenes/ui/close_button.tscn` / `scenes/ui/close_button.gd`
- Reusable close button emitting `close_requested`

## Data Files
- `data/upgrades.json`
- Defines upgrade metadata, costs, requirements, and effects
- Includes cannery and crew effects (auto-send, tin speed, etc.)
- `data/cannery_options.json`
- Defines available tin methods and ingredients

## Timers / Loops
- `main.gd`
- Sell timer at `SELL_INTERVAL` (1s)
- Autosave timer at `AUTOSAVE_INTERVAL` (30s)
- `GameState._process()`
- Crew trip countdown and auto-send
- Tin cooldown and auto-tin loop

## Current Architecture Notes
- UI uses a modal pattern: screens are shown/hidden by `main.gd` with a `Dimmer` overlay
- `GameState` emits `changed` and other signals to refresh UI
- Data-driven upgrades and cannery options are already in place

## Not Yet Implemented (From Updated Planning)
- Prestige availability gate at 100 tins sold
- Reputation system and MetaState persistence
- Permanent tech tree and reputation spend
- Ocean health system (hidden or visible)
- Industrial vs sustainable behavior weighting
- Endings and run summary
- Multiple fish types, quality, and higher-tier processing
