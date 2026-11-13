extends "res://tests/headless/test_base.gd"

# Endings judge the whole game (all runs), not just the current run.
# prestige() saves; tests/run_headless_tests.sh isolates user data.


func run_tests(gs) -> void:
    _test_industrial_game_fresh_run(gs)
    _test_sustainable_game(gs)
    _test_old_save(gs)


func _clear_game(gs) -> void:
    gs.meta_state["past_runs"] = {}
    gs.meta_state["prestige_count"] = 0
    gs.upgrade_levels = {}
    gs.chosen_exclusive_groups = {}
    gs.policy_stage_chosen = {}


# Plays one run of `seconds` at `ocean_ratio` average health, with
# `policy_id` bought, then prestiges.
func _play_run(gs, policy_id: String, seconds: float, ocean_ratio: float) -> void:
    gs.is_cannery_unlocked = true
    gs.money = 1000000
    gs.tins_sold = gs.PRESTIGE_TINS_REQUIRED
    gs.lifetime_money_earned = 60000
    check(gs.purchase_upgrade(policy_id), "buy %s" % policy_id)
    gs.ocean_health_time_total = seconds
    gs.ocean_health_time_accum = seconds * ocean_ratio * gs.OCEAN_HEALTH_MAX
    check(gs.prestige(), "prestige after a %s run" % policy_id)


# A developed fresh run (12+ upgrade levels, clean ocean, no policy yet).
func _start_fresh_run(gs, run_seconds: float, game_seconds: float) -> void:
    gs.ocean_health = gs.OCEAN_HEALTH_MAX
    gs.ocean_health_time_total = run_seconds
    gs.ocean_health_time_accum = run_seconds * gs.OCEAN_HEALTH_MAX
    gs.run_time_seconds = game_seconds
    gs.upgrade_levels = {"rod_strength": 6, "bait_bucket": 6}


# The ABYSS-21 bug: an industrial game got Sustainable Equilibrium 8 minutes
# into a fresh run because only that run's ocean average counted.
func _test_industrial_game_fresh_run(gs) -> void:
    _clear_game(gs)
    _play_run(gs, "ind_overdrive", 3.0 * 3600.0, 0.3)
    _start_fresh_run(gs, 480.0, 3.2 * 3600.0)
    var average: float = gs.get_game_ocean_health_average_ratio()
    var share: float = gs.get_game_sustainable_share()
    check(average < 0.4, "game ocean average includes the drained run (%.2f)" % average)
    check(share < 0.1, "game path is industrial (%.2f sustainable)" % share)
    check(not gs._check_sustainable_equilibrium(), "an industrial game can't reach Sustainable Equilibrium in a fresh run")
    check(not gs._check_industrial_collapse(), "no collapse while this run's ocean is full")
    gs.ocean_health = 0.0
    check(gs._check_industrial_collapse(), "industrial game collapses when the ocean empties")
    gs.lifetime_money_earned = 5000
    var summary: Dictionary = gs.get_run_summary()
    check(int(summary["lifetime_money_earned"]) == 65000, "summary earnings cover both runs ($%d)" % int(summary["lifetime_money_earned"]))
    check(int(summary["tins_sold"]) == gs.PRESTIGE_TINS_REQUIRED, "summary tins include past runs (%d)" % int(summary["tins_sold"]))
    gs.ocean_health = gs.OCEAN_HEALTH_MAX


func _test_sustainable_game(gs) -> void:
    _clear_game(gs)
    _play_run(gs, "sust_harvest_standards", 3.0 * 3600.0, 0.95)
    _start_fresh_run(gs, 600.0, 3.2 * 3600.0)
    check(gs.get_game_sustainable_share() > 0.9, "game path is sustainable (%.2f)" % gs.get_game_sustainable_share())
    check(gs._check_sustainable_equilibrium(), "a sustainable game reaches Sustainable Equilibrium")
    gs.ocean_health = 0.0
    check(not gs._check_industrial_collapse(), "a sustainable game doesn't get the industrial ending")
    gs.ocean_health = gs.OCEAN_HEALTH_MAX
    _clear_game(gs)
    gs.run_time_seconds = 0.0


func _test_old_save(gs) -> void:
    var meta: Dictionary = gs.meta_state.duplicate(true)
    meta.erase("past_runs")
    gs._apply_save({"version": 15, "meta_state": meta, "ocean_health_time_total": 100.0, "ocean_health_time_accum": 70.0 * gs.OCEAN_HEALTH_MAX})
    check(typeof(gs.meta_state.get("past_runs")) == TYPE_DICTIONARY, "a save without past runs loads")
    check(is_equal_approx(gs.get_game_ocean_health_average_ratio(), gs.get_ocean_health_average_ratio()), "with no past runs the game average is the run average")
    _clear_game(gs)
