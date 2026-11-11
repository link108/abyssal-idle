extends "res://tests/headless/test_base.gd"


func run_tests(gs) -> void:
    check(gs.get_manual_catch_amount() == 1, "a manual catch lands 1 fish with no upgrades")

    gs.upgrade_levels = {"rod_strength": 5, "bait_bucket": 2}
    check(gs.get_manual_catch_amount() == 8, "rod 5 + bait 2 land 8 fish per manual catch (got %d)" % gs.get_manual_catch_amount())

    # Rod and bait don't touch crew hauls.
    gs.fish_count = 0
    gs.catch_fish(2)
    check(gs.fish_count == 2, "rod/bait don't add to a crew haul (got %d)" % gs.fish_count)

    gs.upgrade_levels = {"rod_strength": 5, "ind_overdrive": 1}
    check(gs.get_manual_catch_amount() == 8, "industrial catch_mult scales manual catches: 6 x 1.35 = 8 (got %d)" % gs.get_manual_catch_amount())
    gs.upgrade_levels = {"rod_strength": 5, "sust_harvest_standards": 1}
    check(gs.get_manual_catch_amount() == 5, "sustainable catch_mult scales manual catches: 6 x 0.85 = 5 (got %d)" % gs.get_manual_catch_amount())

    gs.upgrade_levels = {"rod_strength": 5, "bait_bucket": 5}
    gs.ocean_health = 0.0
    var depleted: int = gs.get_manual_catch_amount()
    check(depleted == int(round(11.0 * gs.OCEAN_HEALTH_CATCH_FLOOR)), "an empty ocean shrinks the manual haul (got %d)" % depleted)
    gs.upgrade_levels = {}
    check(gs.get_manual_catch_amount() == 1, "a manual catch always lands at least 1 fish")
    gs.ocean_health = gs.OCEAN_HEALTH_MAX

    gs.upgrade_levels = {"rod_strength": 3}
    gs.fish_count = 0
    gs.fish_stock_by_id = {}
    var outcome: Dictionary = {}
    for _i in range(50):
        outcome = gs.attempt_manual_catch(true)
        if bool(outcome.get("success", false)):
            break
    check(bool(outcome.get("success", false)), "a manual catch succeeds within 50 tries")
    check(int(outcome.get("count", 0)) == 4 and gs.fish_count == 4, "a successful catch adds rod fish to stock (count %d, stock %d)" % [int(outcome.get("count", 0)), gs.fish_count])
    var stocked := int(gs.fish_stock_by_id.get(str(outcome.get("fish_id", "")), 0))
    check(stocked == 4, "extra fish are the same species")
    check(gs.ocean_health < gs.OCEAN_HEALTH_MAX, "extra fish add ocean pressure")
    gs.upgrade_levels = {}
