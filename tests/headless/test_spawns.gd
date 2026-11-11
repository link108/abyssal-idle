extends "res://tests/headless/test_base.gd"


func run_tests(gs) -> void:
    var choirfin: Dictionary = gs.fish_defs_by_id["choirfin_seraph"]
    var hollowgill: Dictionary = gs.fish_defs_by_id["hollowgill_remnant"]
    var saltblind: Dictionary = gs.fish_defs_by_id["saltblind_choir"]

    gs.meta_state["prestige_count"] = 2
    _set_ratio(gs, 0.61)
    check(gs._is_fish_requires_met(choirfin), "choirfin catchable at 61% ocean")
    _set_ratio(gs, 0.59)
    check(not gs._is_fish_requires_met(choirfin), "choirfin not catchable at 59% ocean")

    _set_ratio(gs, 0.36)
    check(not gs._is_fish_requires_met(hollowgill), "hollowgill absent at 36% ocean")
    _set_ratio(gs, 0.34)
    check(gs._is_fish_requires_met(hollowgill), "hollowgill appears below 35% ocean")

    _set_ratio(gs, 0.14)
    check(gs._is_fish_requires_met(saltblind), "saltblind appears below 15% at depth tier 2")
    _set_ratio(gs, 0.16)
    check(not gs._is_fish_requires_met(saltblind), "saltblind absent at 16% ocean")
    gs.meta_state["prestige_count"] = 1
    _set_ratio(gs, 0.10)
    check(not gs._is_fish_requires_met(saltblind), "saltblind needs depth tier 2")


func _set_ratio(gs, ratio: float) -> void:
    gs.ocean_health = gs.OCEAN_HEALTH_MAX * ratio
