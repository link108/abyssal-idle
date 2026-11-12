extends "res://tests/headless/test_base.gd"


func run_tests(gs) -> void:
    gs.meta_state["skills_owned"] = ["core_market_entry"]
    gs.meta_state["reputation"] = 0
    check(gs.get_skill_cost("ind_bulk_contracts") == 15, "industrial node at base cost with no sustainable skills")
    check(gs.get_skill_cost_note("ind_bulk_contracts") == "", "no cost note at base cost")

    gs.meta_state["skills_owned"] = ["core_market_entry", "sust_artisan_pricing", "sust_selective_netting"]
    check(gs.get_skill_cost("ind_bulk_contracts") == 60, "two sustainable skills quadruple an industrial node (got %d)" % gs.get_skill_cost("ind_bulk_contracts"))
    check(gs.get_skill_cost_note("ind_bulk_contracts") == "x4: you own 2 Sustainable skills", "cost note explains the multiplier: '%s'" % gs.get_skill_cost_note("ind_bulk_contracts"))
    check(gs.get_skill_cost("sust_rotational_zones") == 35, "own-branch nodes keep their base cost")
    check(gs.get_skill_cost("meta_fast_start") == 20, "meta nodes are never raised")

    gs.meta_state["reputation"] = 59
    check(not gs.can_purchase_skill("ind_bulk_contracts"), "the raised cost is enforced")
    gs.meta_state["reputation"] = 60
    check(gs.purchase_skill("ind_bulk_contracts") and gs.get_reputation() == 0, "purchase spends the raised cost")
    check(gs.get_skill_cost("sust_rotational_zones") == 70, "owning an industrial skill raises the sustainable branch too")
    check(gs.get_skill_cost_note("ind_bulk_contracts") == "", "owned skills have no cost note")

    # After a full sustainable branch, the industrial branch costs x32.
    gs.meta_state["skills_owned"] = ["core_market_entry", "sust_artisan_pricing", "sust_selective_netting", "sust_rotational_zones", "sust_artisan_processing", "sust_habitat_restoration"]
    var base_total := 0
    var raised_total := 0
    for def in gs.get_skill_defs_by_branch("industrial"):
        base_total += int(def["cost"])
        raised_total += gs.get_skill_cost(str(def["id"]))
    check(raised_total == base_total * 32, "after a full branch, the other costs x32 (%d rep, base %d)" % [raised_total, base_total])
    gs.meta_state["skills_owned"] = []
    gs.meta_state["reputation"] = 0
