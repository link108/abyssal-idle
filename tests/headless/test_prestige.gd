extends "res://tests/headless/test_base.gd"

# Prestige must reset per-run choices and keep meta bonuses small.
# prestige() saves; tests/run_headless_tests.sh isolates user data.


func run_tests(gs) -> void:
    _test_policies_reopen(gs)


func _prepare_run(gs) -> void:
    gs.is_cannery_unlocked = true
    gs.money = 1000000
    gs.tins_sold = gs.PRESTIGE_TINS_REQUIRED
    gs.lifetime_money_earned = 10000


func _test_policies_reopen(gs) -> void:
    gs.chosen_exclusive_groups = {}
    gs.policy_stage_chosen = {}
    _prepare_run(gs)
    check(gs.purchase_upgrade("sust_harvest_standards"), "buy a stage-1 policy")
    check(not gs.can_purchase_upgrade("ind_overdrive"), "the other option is locked during the run")
    check(gs.prestige(), "prestige")
    check(gs.chosen_exclusive_groups.is_empty() and gs.policy_stage_chosen.is_empty(), "prestige clears the policy choices")
    _prepare_run(gs)
    check(gs.can_purchase_upgrade("sust_harvest_standards") and gs.can_purchase_upgrade("ind_overdrive"), "both stage-1 policies can be bought again")
    check(gs.purchase_upgrade("ind_overdrive"), "a new run can pick the other path")
