# Requires Unification Notes

## Supported condition types
- `always`
- `flag_true`
- `money_at_least`
- `depth_tier_at_least`
- `upgrade_purchased`
- `upgrade_level_at_least`
- `exclusive_group_unchosen`
- `policy_stage_at_least`
- `item_owned_at_least`

## Migrated files
- `data/raw/upgrades.json`
- `data/raw/fish.json`
- `data/raw/items.json`
- `data/raw/equipment.json`
- `data/raw/recipes.json`
- `data/raw/processes.json`

Notes:
- `unlock_conditions` and `unlock_condition` were migrated to `requires` where present.
- Entries in migrated files that had no gating fields were given a default:
  `[{ "type": "always", "value": true }]`.
- Runtime compatibility remains via `RequiresEval.get_requires(...)` fallback for legacy fields.
