extends "res://tests/headless/test_base.gd"


func run_tests(gs) -> void:
    check(is_equal_approx(gs.get_ocean_pressure_mult(), 1.0), "base ocean pressure mult is 1.0")
    check(is_equal_approx(gs.get_ocean_regen_mult(), 1.0), "base ocean regen mult is 1.0")

    gs.upgrade_levels = {"sust_harvest_standards": 1}
    check(is_equal_approx(gs.get_ocean_pressure_mult(), 0.6), "policy pressure effect applies (0.6)")
    check(is_equal_approx(gs.get_ocean_regen_mult(), 1.3), "policy regen effect applies (1.3)")

    gs.upgrade_levels = {"ind_overdrive": 1}
    check(is_equal_approx(gs.get_ocean_pressure_mult(), 1.25), "industrial policy raises pressure (1.25)")

    gs.upgrade_levels = {}
    gs.ocean_health = gs.OCEAN_HEALTH_MAX
    gs._apply_ocean_health_pressure(20)
    var after_catch: float = gs.ocean_health
    check(after_catch < gs.OCEAN_HEALTH_MAX, "catching fish drains the ocean")

    gs._regenerate_ocean_health(1.0)
    check(gs.ocean_health > after_catch, "regen recovers some health")
    check(gs.ocean_health < gs.OCEAN_HEALTH_MAX, "regen does not instantly refill")

    # Regen is fastest mid-range and slow near empty.
    gs.ocean_health = gs.OCEAN_HEALTH_MAX * 0.5
    gs._regenerate_ocean_health(1.0)
    var mid_gain: float = gs.ocean_health - gs.OCEAN_HEALTH_MAX * 0.5
    gs.ocean_health = gs.OCEAN_HEALTH_MAX * 0.02
    gs._regenerate_ocean_health(1.0)
    var low_gain: float = gs.ocean_health - gs.OCEAN_HEALTH_MAX * 0.02
    check(mid_gain > low_gain, "regen is faster at half health than near empty")

    # Trend reports a decline while fishing outpaces regen.
    gs.ocean_health = gs.OCEAN_HEALTH_MAX
    gs._reset_ocean_trend()
    for _i in range(30):
        gs._apply_ocean_health_pressure(3)
        gs._regenerate_ocean_health(1.0)
        gs._sample_ocean_trend(1.0)
    check(gs.get_ocean_health_trend_per_min() < 0.0, "trend is negative while overfishing")
