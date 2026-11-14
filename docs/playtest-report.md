# Playtest Report (2026-11-12)

Automated playtests of `main` at `db93ce0` (ABYSS-21). A bot played the real
game headless at fixed time (`tools/playtest/`), like a person would: it pressed
New Game, fished manually, sold, shopped, ran the crew and cannery, followed the
cannery hints to discover recipes, bought its profile's policies, prestiged, and
spent reputation on skills.

## How it was run

```
tools/playtest/run.sh profile=sustainable hours=2      # or industrial; manual=0.15 for an idle player
tools/playtest/summarize.py .vdisplay/playtest/*.json
```

Player model (see the header of `tools/playtest/playtest.gd`):

- **Fishing.** Alternates 2-minute blocks. It fishes manually for half of each
  block (15% for the idle player), making one attempt every 1.5s. The hit
  chance is 70% at the base green zone, and the crew pauses while the boat is
  open. Then it tends the crew, shop and cannery.
- **Shopping.** Unlocks and the profile's policies come first, then the
  cheapest affordable upgrade or equipment.
- **Cannery.** Half of cannery actions are experiments that hill-climb on the
  score and follow the hint. The other half make the best known recipe, or it
  lets auto-tin run.
- **Prestige.** It prestiges once all five policies are bought, or after 45
  minutes.

Runs: sustainable and industrial for 2 h with an active player, plus 4 h idle
runs. The bugs below were confirmed with direct headless probes.

## Findings

### Bugs (block any balance work)

1. **Prestige bonuses run away.** `_apply_reputation_gain` adds the *whole*
   reputation gain to `sustainable_bonus_level` / `industrial_bonus_level`, and
   each level is worth ±$1 per fish (and +$1/tin for industrial).
   - **Sustainable:** the first prestige (100 rep) makes a $12 Veilscale sell
     for $112, and it compounds. Income reached $3M/min in run 5 and $20M/min
     in run 6 with *zero* upgrades.
   - **Industrial:** fish drop to the $1 floor, so later runs crawl. The first
     $100 takes 3–14 min and crew 7–60 min. Then income jumps to $159k/min once
     tins sell for +$1 per reputation point.
2. **Policies can't be bought again after a prestige.** `_reset_run_state`
   clears `upgrade_levels` but not `chosen_exclusive_groups` /
   `policy_stage_chosen`. Every policy is locked from the second run on, so the
   game's core decision disappears after the first prestige.
3. **Endings mix per-run and whole-game data.**
   - `run_time_seconds` isn't reset by prestige, but the ocean average is.
   - An industrial-policy player got **Sustainable Equilibrium** at 3:12 total,
     8 minutes into a fresh run with a clean ocean.
   - The policy path doesn't factor into the endings at all.
   - **Fixed (ABYSS-24):** endings now judge the whole game. The ocean
     average, earnings, sales and the time-weighted policy path accumulate
     across runs in `meta_state.past_runs`.

### Pacing (the early game is far too fast)

Active player, first run (in-run times):

| Milestone | Sustainable | Industrial | Idle (15% fishing) |
|---|---|---|---|
| Earned $100 | 0:18 | 0:13 | 2:01 |
| Crew unlocked | 0:35 | 0:20 | 2:20 |
| Cannery unlocked | 1:00 | 0:50 | 2:30 |
| All 5 policies | 3:20 | ~7:00 | 10:15 |
| Prestige ready (100 tins sold) | ~6:00 | 3:56 | 7:08 |
| Earned $10k | 5:25 | — | — |

4. **Rod/Bait snowball (regression from ABYSS-17).** Rod 1–5 costs $10–51, a
   price set back when it only added +1 fish per crew trip. Since ABYSS-17 it
   multiplies every manual catch: 6 fish per catch after 30 seconds, 11 with
   Bait. The first minute earns about $750.
5. **Policies are impulse buys.** They cost $300–1200 against $2–10k/min
   income, so the permanent, exclusive choice gets made in the first few
   minutes with no time to see the tradeoff.
6. **Prestige comes in minutes, not hours.** 100 tins sold takes 4–7 minutes.
   The decision audit treats prestige as an hours-scale decision.
7. **`core_market_entry` is a placeholder.** It costs 1 rep and gives +$20 per
   fish, more than most early fish are worth. Its text says "doubles fish sell
   value".
8. **The sustainable path still drains the ocean.** With heavy manual fishing
   (Rod/Bait at about 11 fish per catch), sustainable runs fell to about 54% by
   45 minutes. The policies' pressure cuts don't offset manual catch volume.

### What works

- **Recipe discovery by following hints** took 13–47 experiments per recipe,
  and 3–4 recipes were found per 2 hours. Hints that name the missing note plus
  visible item tags are enough to steer.
- **Unlock order** (crew → cannery → auto-send → auto-tin) feels right; only the
  speed is off.
- **Recipe tins and auto-tin** get used once recipes exist, and recipe tins
  beat raw fish as intended (ABYSS-16).

## Retune (ABYSS-25, 2026-11-13)

Findings 1-8 are fixed: 1-2 in ABYSS-22/23, 3 in ABYSS-24, 4-8 here.
`tools/playtest/pacing.sh` now checks these targets (ABYSS-26).

First run, in-run times, seeds 1 / 2:

| Milestone | Target | Sustainable | Industrial | Idle (15%, seed 1) |
|---|---|---|---|---|
| Crew | 2-3 min | 3:30 / 3:10 | 3:30 / 3:10 | 14:25 |
| Cannery | ~5 min | 4:40 / 5:00 | 4:35 / 5:15 | 15:45 |
| First policy | ~15 min | 15:50 / 20:15 | 14:35 / 13:25 | 28:20 |
| All 5 policies | 60+ min | 1:43 / 1:29 | 1:10 / 1:02 | 1:40 |
| Prestige ready | 45-90 min | 1:20 / 1:13 | 1:06 / 0:57 | 1:24 |
| First prestige rep | - | 74 / 72 | 66 / 66 | 72 |
| Run ocean average | sust >= 85% | 85% / 86% | 52% / 55% | 90% |

What changed:

- **Costs.** Crew $600, cannery $1,200, Rod $40 (x1.75), Bait $400 (x1.8),
  later run upgrades about 2-15x. Policies cost $5k / $15k / $22k / $32k /
  $45k, so the exclusive choice comes after ~15 minutes of play.
- **Bulk Crates sell tins too.** Tins sold one per tick no matter what, so
  income flatlined once the cannery took over.
- **Prestige opens at $400k earned in the run**, not 100 tins sold. A tin
  count can't fit both paths: industrial policies tin far faster by design.
  The button shows progress as a percentage.
- **Reputation is the square root of run earnings** (in $100s). A full run
  pays ~65-75 rep instead of thousands: a few skills per prestige.
- **Ocean.** Each fish costs 0.010 health instead of 0.012; Harvest Standards
  is -40% pressure / +30% regen and Protected Zones -20% / +35%.
- **Market Entry** gives +$3 per fish and says so.

Player model changes (`tools/playtest/playtest.gd`): saves for an unlock or
policy only when it is about a minute of income away, experiments at most
every 20 seconds, prestiges after all five policies (or 2 hours), and runs
in its own data dir so profiles can run in parallel.

Still open:

- **Fishing pauses the crew** (`main.gd` `_on_fishing_visibility_changed`),
  so manual fishing costs crew trips. The idle player out-earned the active
  one from ~45 minutes on in pass 1, and is only slightly behind now.
- **Equipment is bought from the first run's money** and persists, so the
  first run spends ~$4k on it in minutes 4-15. Fine for now; watch it if
  equipment gets more expensive.

## Recommended order

1. Fix the bugs: bonus runaway (1) and the policy lock (2). Every later number
   depends on them.
2. Decide what the endings should measure (3).
3. Retune early pacing (4–8) against explicit targets. For example: crew at
   2–3 min, cannery at about 5 min, first policy at about 15 min, all policies
   at 60+ min, prestige at 45–90 min.
4. Encode those targets as a playtest-based test, so pacing regressions like
   ABYSS-17's are caught automatically.
