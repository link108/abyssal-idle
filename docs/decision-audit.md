# Decision Audit

An audit of every system against Sid Meier's test from his GDC 2012 talk, "a
game is a series of interesting decisions": does the system present a choice
with a real tradeoff, or would a player always pick the same option?
Written 2026-11-10 against branch `interesting-decisions-ocean` (ABYSS-11),
after the ocean, recipe-discovery, destination and balance work in ABYSS-2..14.

Verdicts are proposals. Nothing has been cut; each rework/merge/cut has a
Backlog ticket for the owner to decide on.

| System | Decision presented | Tradeoff | Always the same pick? | Timescale | Verdict |
|---|---|---|---|---|---|
| Fishing minigame (`src/ui/screens/fishing/fishing_screen.gd`) | When to stop the timing bar | Skill, not choice; catch chance from `catch_difficulty` | n/a (dexterity, like Meier's rhythm-game exception) | seconds | **Keep**: the hands-on start of the cozy loop; adds feel, not decisions |
| Crew + destinations (`data/raw/destinations.json`, `game_state.gd` destinations section) | Where to send each trip | Trip time vs catch vs ocean pressure; zone fatigue rewards rotating | No: shallows are fast and safe, the trench is rich and costly, and repeating a spot costs more | minutes | **Keep** |
| Cannery experimentation (`_evaluate_attempt_outcome`, `cannery_screen.gd`) | Which fish, add-ons and processes to try | Experimental tins sell at $6-10 (below raw for most fish); a found recipe sells at a premium; the cannery shows both next to the raw price | No: depends on fish, hints and what's undiscovered | minutes | **Keep** |
| Recipes + silhouettes (`data/raw/recipes.json`, `_build_silhouette_from_recipe`) | Which recipe to chase or reuse ("Use recipe") | Recipe tins sell at cost-plus (fish + add-ons) times a rarity margin, 1.25x Common to 2.25x Mythic (`get_recipe_tin_price`, ABYSS-16) | No: rarer recipes and pricier fish pay more, but take more experiments to find | hours | **Keep** |
| Equipment (`data/raw/equipment.json`, `equipment_screen.gd`) | What to buy | None: it only unlocks processes; `max_level`, `base_speed_multiplier`, `capacity` are never read | Yes: buy everything eventually | minutes | **Merge**: [ABYSS-18](#proposals) |
| Processes (`data/raw/processes.json`) | Which steps to apply | Shapes tags and score; `base_duration_s` and `quality_modifier` are unused | No for discovery; yes once known ("Use recipe") | minutes | **Keep**; dead fields covered by ABYSS-18 |
| Cannery method dropdown (`data/raw/cannery_options.json`) | Raw vs smoked | Duplicates the Smoke process and the derived `raw` tag | Yes: redundant with processes | seconds | **Cut**: [ABYSS-19](#proposals) |
| Items / vendor (`data/raw/items.json`, market buy mode) | Which ingredients to stock | Money now vs recipes later; flavor tags now act as clues | No | minutes | **Keep** |
| Market sell mode (`sell_tick`, `sell_tins_by_key`) | Sell fish raw or which tins | Raw fish vs experimental tins (usually worse) vs recipe tins (always better); each tin kind is listed with its own price | No: depends on what's in stock | minutes | **Keep** |
| Run upgrades (`data/raw/upgrades.json`, non-policy) | Purchase order | Mostly pure upside stat bumps | Yes: buy all in cost order | minutes | **Keep** as pacing; **rework** Rod/Bait: [ABYSS-17](#proposals), since they don't affect manual catches as described |
| Policies (`upgrades.json` `policy_*` groups) | Sustainable vs industrial, five exclusive stages | Catch/tin speed vs ocean pressure/regen, now applied (ABYSS-2); balanced by `test_ocean_balance.gd` | No: both paths viable (sustainable earns 57% of industrial over 30 min but keeps the ocean, rare fish and its ending) | hours | **Keep**: the core decision |
| Skill tree (`data/raw/skill_tree.json`) | Which node to buy next with reputation | Order only: no exclusivity, reputation persists across prestiges | Yes in the long run: everything gets bought | hours | **Rework**: [ABYSS-20](#proposals) |
| Collections (`collections_screen.gd`) | None | n/a | n/a | n/a | **Keep**: Meier's "the world matters too"; also hosts "Use recipe" |
| Prestige (`can_prestige`, `_apply_reputation_gain_from_run_metrics`) | When to reset (100 tins sold) | Reset progress vs reputation; gain shaped by run alignment | No: timing depends on the run | hours | **Keep** |
| Endings (`_check_endings`) | Outcome of the policy/ocean path | Industrial collapse vs sustainable equilibrium vs dual mastery | n/a (consequence) | hours | **Keep** |
| Ocean health (`game_state.gd` ocean section, HUD) | Indirect: how hard to fish | Catch now scales with health (`OCEAN_HEALTH_CATCH_FLOOR`); rare vs mutated fish; trend + status copy | No | minutes–hours | **Keep** |

## Proposals

Each is a Backlog child of ABYSS-1; none are implemented.

- ~~**ABYSS-16: Price tins by recipe so discovery pays off**~~ (rework, high). Done: see the Recipes row.
- **ABYSS-17: Make Rod/Bait upgrades do what they say** (rework, medium). "+1 fish per catch" only applies to crew trips; manual catches always add 1.
- **ABYSS-18: Merge equipment into process unlocks, or make levels matter** (merge, medium). Equipment levels and process durations/quality are dead data.
- **ABYSS-19: Cut the cannery Method dropdown** (cut, low). It duplicates the Smoke process.
- **ABYSS-20: Make skill tree branch choice matter** (rework, low). No exclusivity, so it becomes a checklist.

## Notes

- Pacing (Meier: neither too many hard decisions at once nor long stretches of
  trivial ones) is reasonable now. Seconds: fishing. Minutes: destinations,
  experiments, purchases. Hours: policies, prestige, endings.
- ABYSS-16 closed the biggest gap: experimentation now drives income, since
  recipe tins beat selling raw and experimental tins mostly don't.
