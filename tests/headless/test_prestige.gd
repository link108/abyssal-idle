extends "res://tests/headless/test_base.gd"

# Prestige must reset per-run choices and keep meta bonuses small.
# prestige() saves; tests/run_headless_tests.sh isolates user data.


func run_tests(gs) -> void:
    _test_policies_reopen(gs)
    _test_bonus_levels(gs, "sust_harvest_standards")
    _test_bonus_levels(gs, "ind_overdrive")
    _test_migration(gs)


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


# Three prestiges on one path: one bonus level each, fish prices stay within
# 2x their base, and industrial never pushes fish below base.
func _test_bonus_levels(gs, policy_id: String) -> void:
    gs.meta_state["sustainable_bonus_level"] = 0
    gs.meta_state["industrial_bonus_level"] = 0
    gs.upgrade_levels = {}
    gs.chosen_exclusive_groups = {}
    gs.policy_stage_chosen = {}
    for _i in range(3):
        _prepare_run(gs)
        gs.lifetime_money_earned = 1000000  # a big run: 10000 rep
        check(gs.purchase_upgrade(policy_id), "buy %s" % policy_id)
        gs.prestige()
    var sustainable := float(gs.meta_state["sustainable_bonus_level"])
    var industrial := float(gs.meta_state["industrial_bonus_level"])
    var label := "sustainable" if policy_id.begins_with("sust_") else "industrial"
    var own := sustainable if label == "sustainable" else industrial
    check(is_equal_approx(sustainable + industrial, 3.0) and is_equal_approx(own, 3.0), "%s: 3 prestiges grant 3 %s levels, not reputation-sized ones (%.1f + %.1f)" % [label, label, sustainable, industrial])
    var base := int(gs.fish_defs_by_id["veilscale_mourner"]["base_value"])
    var price: int = gs.get_fish_sell_price_for_id("veilscale_mourner")
    check(price >= base and price <= base * 2, "%s: Veilscale sells for $%d (base $%d)" % [label, price, base])
    if label == "industrial":
        check(gs.get_tin_sell_price() > gs.TIN_BASE_PRICE, "industrial: levels still raise the tin price ($%d)" % gs.get_tin_sell_price())
    gs.meta_state["sustainable_bonus_level"] = 0
    gs.meta_state["industrial_bonus_level"] = 0


func _test_migration(gs) -> void:
    var meta: Dictionary = gs.meta_state.duplicate(true)
    meta["prestige_count"] = 3
    meta["sustainable_bonus_level"] = 500
    meta["industrial_bonus_level"] = 100
    gs._apply_save({"version": 14, "meta_state": meta})
    var sustainable := float(gs.meta_state["sustainable_bonus_level"])
    var industrial := float(gs.meta_state["industrial_bonus_level"])
    check(is_equal_approx(sustainable, 2.5) and is_equal_approx(industrial, 0.5), "v14 save rescales 500/100 to one level per prestige, keeping the split (%.2f / %.2f)" % [sustainable, industrial])
    gs.meta_state["prestige_count"] = 0
    gs.meta_state["sustainable_bonus_level"] = 0
    gs.meta_state["industrial_bonus_level"] = 0
