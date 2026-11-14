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
| Equipment (`data/raw/equipment.json`, `equipment_screen.gd`) | What to buy and which to upgrade | Upgrades (1.6x cost per level) speed up the processes the equipment runs; speed tools (`speeds_up`) only speed up a process. Faster processes mean faster tins (ABYSS-18) | No: worth upgrading only what your recipes use | minutes | **Keep** |
| Processes (`data/raw/processes.json`) | Which steps to apply | Shapes tags and score; each process adds `base_duration_s` x 0.25 to tin time, so complex recipes are slower but worth more | No for discovery; yes once known ("Use recipe") | minutes | **Keep** |
| Cannery method dropdown (removed) | n/a | Cut in ABYSS-19: the method is derived from processes (`get_method_for_processes`: smoked iff Smoke is chosen) | n/a | n/a | **Cut** (done) |
| Items / vendor (`data/raw/items.json`, market buy mode) | Which ingredients to stock | Money now vs recipes later; flavor tags now act as clues | No | minutes | **Keep** |
| Market sell mode (`sell_tick`, `sell_tins_by_key`) | Sell fish raw or which tins | Raw fish vs experimental tins (usually worse) vs recipe tins (always better); each tin kind is listed with its own price | No: depends on what's in stock | minutes | **Keep** |
| Run upgrades (`data/raw/upgrades.json`, non-policy) | Purchase order; active (Rod/Bait: fish per manual catch) vs idle (Bigger Nets: crew haul) | Mostly pure upside stat bumps, but Rod/Bait only pay while you play the minigame (ABYSS-17); priced so crew and cannery come at ~3 and ~5 min (ABYSS-25) | Mostly yes: buy all in cost order | minutes | **Keep** as pacing |
| Policies (`upgrades.json` `policy_*` groups) | Sustainable vs industrial, five exclusive stages | Catch/tin speed vs ocean pressure/regen, now applied (ABYSS-2); balanced by `test_ocean_balance.gd` | No: both paths viable (sustainable earns 76% of industrial over 30 min in the sim, which now prices recipes, process time and the sell cap, but keeps the ocean, rare fish and its ending; the sim checks 55-90%). $5k-45k each, so the first comes ~15-20 min in and all five take ~60-100 min (ABYSS-25) | hours | **Keep**: the core decision |
| Skill tree (`data/raw/skill_tree.json`) | Which branch to commit to with reputation | Each skill owned in the opposing branch (sustainable vs industrial) doubles the other branch's costs (ABYSS-20), so the first branch picks a style and the second is a long-term goal (and the dual-mastery ending) | No: committing first is far cheaper than mixing | hours | **Keep** |
| Collections (`collections_screen.gd`) | None | n/a | n/a | n/a | **Keep**: Meier's "the world matters too"; also hosts "Use recipe" |
| Prestige (`can_prestige`, `_calculate_reputation_gain`) | When to reset (opens at $400k earned in the run, ~55-80 min; ABYSS-25) | Reset progress vs reputation (square root of run earnings, so longer runs pay less per hour); one bonus level split by run alignment | No: timing depends on the run | hours | **Keep** |
| Endings (`_check_endings`) | Outcome of the policy/ocean path | Industrial collapse vs sustainable equilibrium vs dual mastery, judged over the whole game: ocean average, earnings and the time-weighted policy path accumulate across runs (ABYSS-24). Sustainable needs a sustainable-leaning game; collapse an industrial-leaning one | n/a (consequence) | hours | **Keep** |
| Ocean health (`game_state.gd` ocean section, HUD) | Indirect: how hard to fish | Catch now scales with health (`OCEAN_HEALTH_CATCH_FLOOR`); rare vs mutated fish; trend + status copy | No | minutes–hours | **Keep** |

## Proposals

Each is a Backlog child of ABYSS-1; none are implemented.

- ~~**ABYSS-16: Price tins by recipe so discovery pays off**~~ (rework, high). Done: see the Recipes row.
- ~~**ABYSS-17: Make Rod/Bait upgrades do what they say**~~ (rework, medium). Done: they add fish per manual catch (`manual_catch_add`); crew hauls use Bigger Nets.
- ~~**ABYSS-18: Merge equipment into process unlocks, or make levels matter**~~ (merge, medium). Done: levels and process durations now set tin time; dead fields removed.
- ~~**ABYSS-19: Cut the cannery Method dropdown**~~ (cut, low). Done: removed with `cannery_options.json`.
- ~~**ABYSS-20: Make skill tree branch choice matter**~~ (rework, low). Done: cross-branch cost escalation (x2 per opposing skill owned).

## Notes

- Pacing (Meier: neither too many hard decisions at once nor long stretches of
  trivial ones) is reasonable now. Seconds: fishing. Minutes: destinations,
  experiments, purchases. Hours: policies, prestige, endings.
- ABYSS-16 closed the biggest gap: experimentation now drives income, since
  recipe tins beat selling raw and experimental tins mostly don't.
