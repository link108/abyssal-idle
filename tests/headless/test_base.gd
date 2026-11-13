extends SceneTree

# Base for headless tests. Subclasses override run_tests(gs).
# Run tests through tests/run_headless_tests.sh: it gives Godot its own user
# data dir, so code that saves (new_game(), prestige()) can't touch the
# player's save. Prefer setting state directly anyway.

var _failures := 0
var _started := false


func _process(_delta: float) -> bool:
    if _started:
        return false
    _started = true
    var gs = root.get_node("GameState")
    gs.run_paused = true
    reset_state(gs)
    run_tests(gs)
    if _failures > 0:
        print("RESULT: %d failure(s)" % _failures)
        quit(1)
    else:
        print("RESULT: ok")
        quit(0)
    return false


func run_tests(_gs) -> void:
    pass


func check(condition: bool, label: String) -> void:
    if condition:
        print("PASS %s" % label)
    else:
        _failures += 1
        print("FAIL %s" % label)


func reset_state(gs) -> void:
    gs.upgrade_levels = {}
    gs.ocean_health = gs.OCEAN_HEALTH_MAX
    gs._reset_ocean_trend()
    gs.meta_state["prestige_count"] = 0
    gs.meta_state["skills_owned"] = []
    gs.lifetime_money_earned = 0
    gs.money = 0
    gs.fish_count = 0
    gs.fish_stock_by_id = {}
