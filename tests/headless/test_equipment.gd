extends "res://tests/headless/test_base.gd"


func run_tests(gs) -> void:
    gs.meta_state["owned_equipment_ids"] = []
    gs.meta_state["equipment_levels"] = {}
    gs.selected_processes = {"prep": [], "transform": [], "heat": [], "preserve": []}
    _test_base_time(gs)
    _test_process_time(gs)
    _test_levels(gs)
    _test_speed_tools(gs)
    _test_cooldown(gs)
    gs.meta_state["owned_equipment_ids"] = []
    gs.meta_state["equipment_levels"] = {}
    gs.selected_processes = {"prep": [], "transform": [], "heat": [], "preserve": []}


func _test_base_time(gs) -> void:
    check(is_equal_approx(gs.get_selected_tin_make_time(), gs.get_tin_make_time()), "pack + seal alone take the base tin time")


func _test_process_time(gs) -> void:
    gs.selected_processes = {"prep": [], "transform": [], "heat": ["smoke"], "preserve": []}
    var want: float = gs.get_tin_make_time() + 15.0 * gs.PROCESS_TIME_SCALE
    check(is_equal_approx(gs.get_selected_tin_make_time(), want), "smoke adds 15s x scale (%.2f, want %.2f)" % [gs.get_selected_tin_make_time(), want])
    gs.selected_processes = {"prep": [], "transform": [], "heat": ["smoke"], "preserve": ["ferment"]}
    check(gs.get_selected_tin_make_time() > want, "more processes take longer")


func _test_levels(gs) -> void:
    check(gs.get_equipment_level("smoker") == 0 and not gs.can_upgrade_equipment("smoker"), "unowned equipment has no level and can't upgrade")
    gs.meta_state["owned_equipment_ids"] = ["smoker"]
    check(gs.get_equipment_level("smoker") == 1, "owned equipment starts at level 1")
    var base_duration: float = gs.get_process_duration("smoke")
    check(is_equal_approx(base_duration, 15.0), "level 1 smoker runs smoke at its base duration")

    gs.money = 0
    check(not gs.upgrade_equipment("smoker"), "can't upgrade without the money")
    var cost: int = gs.get_equipment_upgrade_cost("smoker")
    check(cost == int(round(400 * gs.EQUIPMENT_UPGRADE_COST_MULT)), "upgrade cost scales from the base cost ($%d)" % cost)
    gs.money = cost
    check(gs.upgrade_equipment("smoker") and gs.money == 0, "upgrade spends the money")
    check(gs.get_equipment_level("smoker") == 2, "smoker is level 2")
    check(is_equal_approx(gs.get_process_duration("smoke"), 15.0 / 1.25), "level 2 runs smoke 25%% faster (%.2f)" % gs.get_process_duration("smoke"))
    check(gs.get_equipment_upgrade_cost("smoker") > cost, "next upgrade costs more")

    gs.meta_state["equipment_levels"] = {"smoker": gs.get_equipment_max_level("smoker")}
    gs.money = 1000000
    check(gs.is_equipment_maxed("smoker") and not gs.upgrade_equipment("smoker"), "maxed equipment can't upgrade")
    gs.meta_state["owned_equipment_ids"] = ["knife"]
    check(gs.get_equipment_max_level("knife") == 1 and gs.is_equipment_maxed("knife"), "non-upgradeable equipment is maxed at level 1")
    gs.money = 0


func _test_speed_tools(gs) -> void:
    gs.meta_state["owned_equipment_ids"] = ["knife"]
    gs.meta_state["equipment_levels"] = {}
    var plain: float = gs.get_process_duration("extract")
    gs.meta_state["owned_equipment_ids"] = ["knife", "precision_tools"]
    var tooled: float = gs.get_process_duration("extract")
    check(is_equal_approx(tooled, plain / 1.75), "precision tools speed up extract (%.2f -> %.2f)" % [plain, tooled])
    check(gs.get_equipment_process_names("precision_tools").has("Extract"), "precision tools list the process they speed up")
    var unused: Array = []
    for def in gs.equipment_defs:
        var equipment_id := str(def.get("equipment_id", ""))
        if gs.get_equipment_process_names(equipment_id).is_empty():
            unused.append(equipment_id)
    check(unused.is_empty(), "every piece of equipment runs or speeds up a process %s" % str(unused))


func _test_cooldown(gs) -> void:
    gs.meta_state["owned_equipment_ids"] = ["smoker"]
    gs.meta_state["equipment_levels"] = {}
    gs.selected_processes = {"prep": [], "transform": [], "heat": ["smoke"], "preserve": []}
    gs.start_tin_cooldown()
    check(is_equal_approx(gs.tin_cooldown_remaining, gs.get_selected_tin_make_time()), "cooldown uses the selection's tin time")
    check(is_equal_approx(gs.get_tin_cooldown_total(), gs.tin_cooldown_remaining), "cooldown total matches for the progress bar")
    gs.clear_tin_cooldown()
