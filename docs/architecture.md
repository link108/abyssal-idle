# Abyssal Idle - Architecture

## Goals
- Simple, data-driven systems.
- Minimal scene coupling.
- Easy to add content via JSON.

## Project Structure
res://
  scenes/
    main/
      Main.tscn
    ui/
      close_button.tscn
    minigames/
      FishingMinigame.tscn
  scripts/
    game_state.gd
    ui/
      upgrade_screen.gd
      market_screen.gd
  data/
    upgrades.json
  docs/
    game_design.md
    architecture.md
    plan.md

## Autoloads
- GameState (global economy + upgrades + save later)

## Core Systems
### Economy (GameState)
- fish_count, tin_count, money
- sell_mode (fish/tins)
- sell_tick() for passive sales

### Upgrades (GameState)
- Loaded from `res://data/upgrades.json`
- Effects:
  - catch_add
  - fish_sell_add
  - fish_sell_count_add
  - tin_sell_add

### Upgrade UI
- `upgrade_screen.gd` builds cards from JSON.
- Uses GameState to check requirements and buy upgrades.

## UI / Scenes
- Main.tscn contains HUD + modal screens.
- Modal screens:
  - FishingScreen
  - CanneryScreen
  - MarketScreen
  - UpgradeScreen

## Data Format (Upgrades)
```
{
  "id": "rod_strength",
  "name": "Stronger Rod",
  "desc": "+1 fish per catch.",
  "category": "fishing",
  "requires": {
    "cannery": true,
    "upgrades": { "rod_strength": 5 }
  },
  "base_cost": 10,
  "cost_mult": 1.5,
  "max_level": 5,
  "effects": [
    { "type": "catch_add", "value": 1 }
  ]
}
```

## Near-Term Additions
- Save/load with versioning.
- Ocean health system.
- Fishing minigame scene with timing bar.
