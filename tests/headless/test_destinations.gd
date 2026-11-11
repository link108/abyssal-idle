extends "res://tests/headless/test_base.gd"


func run_tests(gs) -> void:
    gs.is_crew_unlocked = true
    gs.crew_trip_active = false
    gs._reset_crew_destination_state()
    _test_multipliers(gs)
    _test_locking(gs)
    _test_species(gs)
    _test_fatigue(gs)
    _test_save(gs)


func _test_multipliers(gs) -> void:
    gs.meta_state["prestige_count"] = 2
    var expected := {
        "shallows": [9.0, 2, 1.0],
        "midnight_drop": [12.0, 3, 1.0],
        "deep_trench": [19.2, 4, 1.5]
    }
    for destination_id in expected:
        check(gs.select_crew_destination(destination_id), "can select %s" % destination_id)
        var want: Array = expected[destination_id]
        check(is_equal_approx(gs.get_crew_trip_duration(), want[0]), "%s trip time %.1fs (got %.2f)" % [destination_id, want[0], gs.get_crew_trip_duration()])
        check(gs.get_crew_trip_catch() == want[1], "%s catch %d (got %d)" % [destination_id, want[1], gs.get_crew_trip_catch()])

    # Deep trench pressure: 4 fish x per-fish cost x 1.5 destination.
    gs.crew_last_trip_destination_id = ""
    gs.ocean_health = gs.OCEAN_HEALTH_MAX
    gs.select_crew_destination("deep_trench")
    gs.start_crew_trip()
    gs._complete_crew_trip()
    var expected_loss: float = 4.0 * gs.OCEAN_HEALTH_FISH_COST * 1.5
    check(is_equal_approx(gs.OCEAN_HEALTH_MAX - gs.ocean_health, expected_loss), "deep trench applies its pressure multiplier (lost %.3f, want %.3f)" % [gs.OCEAN_HEALTH_MAX - gs.ocean_health, expected_loss])
    gs.meta_state["prestige_count"] = 0
    gs._reset_crew_destination_state()


func _test_locking(gs) -> void:
    gs.meta_state["prestige_count"] = 0
    gs.select_crew_destination("midnight_drop")
    check(not gs.select_crew_destination("deep_trench"), "locked destination can't be selected")
    check(gs.crew_destination_id == "midnight_drop", "selection unchanged after a locked pick")
    check(gs.get_destination_lock_reason("deep_trench") != "", "locked destination has a reason")
    check(not gs.select_crew_destination("nowhere"), "unknown destination can't be selected")


func _test_species(gs) -> void:
    gs.meta_state["prestige_count"] = 2
    gs.lifetime_money_earned = 1000
    gs.ocean_health = gs.OCEAN_HEALTH_MAX
    var deep: Dictionary = gs.get_destination_def("deep_trench")
    var deep_biomes: Array = deep["biomes"]
    var stray: Array = []
    for _i in range(200):
        var fish_id: String = gs._pick_catchable_fish_id(deep_biomes)
        var biome := str(gs.fish_defs_by_id[fish_id].get("biome", ""))
        if not deep_biomes.has(biome) and not stray.has(fish_id):
            stray.append(fish_id)
    check(stray.is_empty(), "deep trench catches only trench fish %s" % str(stray))

    # Nothing catchable in the rift yet: falls back to the shallows pool.
    gs.meta_state["prestige_count"] = 0
    var shallows_biomes: Array = gs.get_destination_def("shallows")["biomes"]
    var fallback_ok := true
    for _i in range(50):
        var fish_id: String = gs._pick_catchable_fish_id(["Abyssal Rift"])
        if not shallows_biomes.has(str(gs.fish_defs_by_id[fish_id].get("biome", ""))):
            fallback_ok = false
    check(fallback_ok, "empty destination pool falls back to the shallows")


func _test_fatigue(gs) -> void:
    gs.meta_state["prestige_count"] = 0
    gs._reset_crew_destination_state()
    gs.select_crew_destination("shallows")
    var bonuses: Array = []
    for _i in range(8):
        gs.start_crew_trip()
        bonuses.append(gs.get_zone_fatigue_bonus())
        gs._complete_crew_trip()
    check(is_equal_approx(bonuses[0], 0.0), "first trip has no fatigue")
    check(is_equal_approx(bonuses[1], 0.1), "second consecutive trip adds +0.1")
    check(is_equal_approx(bonuses[7], 0.5), "fatigue caps at +0.5 (got %.2f)" % bonuses[7])
    check(is_equal_approx(gs.get_next_trip_fatigue_bonus("shallows"), 0.5), "next-trip fatigue preview stays capped")
    check(is_equal_approx(gs.get_next_trip_fatigue_bonus("midnight_drop"), 0.0), "switching previews no fatigue")
    gs.select_crew_destination("midnight_drop")
    gs.start_crew_trip()
    check(is_equal_approx(gs.get_zone_fatigue_bonus(), 0.0), "switching destination resets fatigue")
    gs._complete_crew_trip()


func _test_save(gs) -> void:
    gs._apply_save({
        "version": gs.SAVE_VERSION,
        "crew_destination_id": "midnight_drop",
        "crew_trip_destination_id": "midnight_drop",
        "crew_last_trip_destination_id": "midnight_drop",
        "crew_zone_fatigue_trips": 2
    })
    check(gs.crew_destination_id == "midnight_drop" and gs.crew_zone_fatigue_trips == 2, "destination and fatigue load from a save")

    gs._apply_save({"version": gs.SAVE_VERSION, "crew_destination_id": "atlantis"})
    check(gs.crew_destination_id == "shallows", "unknown saved destination falls back to the shallows")

    gs._apply_save({
        "version": 13,
        "crew_destination_id": "midnight_drop",
        "crew_zone_fatigue_trips": 3
    })
    check(gs.crew_destination_id == "shallows" and gs.crew_zone_fatigue_trips == 0, "v13 save migrates to the shallows with no fatigue")
