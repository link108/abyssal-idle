extends "res://tests/headless/test_base.gd"

# Headless balance sim: 30 minutes at 1s ticks per player profile, using the
# real catch, trip, destination, fatigue and ocean functions.

const SIM_SECONDS := 1800
# Assumed successful manual catches per second while the player is active;
# rod/bait upgrades add fish to each one.
const MANUAL_CATCHES_PER_SEC := 0.25
const RNG_SEED := 1108

const MID_UPGRADES := {
    "unlock_cannery": 1,
    "auto_tin": 1,
    "rod_strength": 5,
    "bait_bucket": 3,
    "crew_trip_speed": 3,
    "crew_trip_yield": 3,
    "crew_auto_send": 1
}
const LATE_UPGRADES := {
    "unlock_cannery": 1,
    "auto_tin": 1,
    "tin_speed": 3,
    "rod_strength": 5,
    "bait_bucket": 5,
    "crew_trip_speed": 3,
    "crew_trip_yield": 8,
    "crew_auto_send": 1
}
const INDUSTRIAL_POLICIES := ["ind_overdrive", "ind_conveyor", "ind_open_expansion", "ind_auto_fleet", "ind_commodity_dominance"]
const SUSTAINABLE_POLICIES := ["sust_harvest_standards", "sust_small_batch", "sust_protected_zones", "sust_local_crews", "sust_certified_label"]


func run_tests(gs) -> void:
    var early := _simulate(gs, "early", {}, [], 0, false, ["shallows"])
    var mid := _simulate(gs, "mid", MID_UPGRADES, [], 1, true, ["shallows", "midnight_drop"])
    var late_ind := _simulate(gs, "late industrial", LATE_UPGRADES, INDUSTRIAL_POLICIES, 2, true, ["deep_trench"])
    var late_sust := _simulate(gs, "late sustainable", LATE_UPGRADES, SUSTAINABLE_POLICIES, 2, true, ["shallows", "midnight_drop", "deep_trench"])

    print("profile            |  5m |  10m |  20m |  30m |  avg | first<=5% | fish/s | income")
    for result in [early, mid, late_ind, late_sust]:
        print("%-18s | %3d%% | %3d%% | %3d%% | %3d%% | %3d%% | %9s | %6.2f | $%d" % [
            result["name"], result["at"][300], result["at"][600], result["at"][1200], result["at"][1800],
            int(round(result["avg"] * 100.0)),
            ("%dm%02ds" % [result["collapse_at"] / 60, result["collapse_at"] % 60]) if result["collapse_at"] >= 0 else "never",
            result["fish_per_sec"],
            result["income"]
        ])

    check(early["at"][1800] >= 90, "early: ocean >= 90%% at 30 min (%d%%)" % early["at"][1800])
    check(mid["at"][1800] >= 40 and mid["at"][1800] <= 85, "mid: ocean ends between 40%% and 85%% (%d%%)" % mid["at"][1800])
    var collapse: int = late_ind["collapse_at"]
    check(collapse >= 600 and collapse <= 2400, "late industrial: reaches <= 5%% between 10 and 40 min (%ds)" % collapse)
    check(late_sust["avg"] >= gs.SUSTAINABLE_HEALTH_AVG_THRESHOLD, "late sustainable: average ocean >= %.2f (%.2f)" % [gs.SUSTAINABLE_HEALTH_AVG_THRESHOLD, late_sust["avg"]])
    var share: float = float(late_sust["income"]) / max(1.0, float(late_ind["income"]))
    check(share >= 0.55, "late sustainable earns >= 55%% of industrial (%d%%)" % int(round(share * 100.0)))
    # Industrial must still pay more, or the policy choice has no tradeoff.
    check(share <= 0.9, "late industrial out-earns sustainable by 10%%+ (%d%%)" % int(round(share * 100.0)))


func _simulate(gs, profile_name: String, upgrades: Dictionary, policies: Array, prestige: int, crew: bool, rotation: Array) -> Dictionary:
    reset_state(gs)
    gs._rng.seed = RNG_SEED
    var levels := upgrades.duplicate()
    for policy_id in policies:
        levels[policy_id] = 1
    gs.upgrade_levels = levels
    gs.meta_state["prestige_count"] = prestige
    gs.lifetime_money_earned = 100000
    gs.is_crew_unlocked = crew
    gs.is_cannery_unlocked = levels.has("unlock_cannery")
    gs.crew_trip_active = false
    gs._reset_crew_destination_state()

    var at := {}
    var ratio_sum := 0.0
    var collapse_at := -1
    var manual_owed := 0.0
    var rotation_index := 0
    for second in range(1, SIM_SECONDS + 1):
        manual_owed += MANUAL_CATCHES_PER_SEC
        while manual_owed >= 1.0:
            manual_owed -= 1.0
            gs._land_manual_catch(gs._pick_catchable_fish_id())
        if crew:
            if not gs.crew_trip_active:
                gs.select_crew_destination(str(rotation[rotation_index % rotation.size()]))
                rotation_index += 1
                gs.start_crew_trip()
            gs.crew_trip_remaining -= 1.0
            if gs.crew_trip_remaining <= 0.0:
                gs._complete_crew_trip()
        gs._regenerate_ocean_health(1.0)
        var ratio: float = gs.get_ocean_health_ratio()
        ratio_sum += ratio
        if collapse_at < 0 and ratio <= 0.05:
            collapse_at = second
        if second in [300, 600, 1200, 1800]:
            at[second] = int(round(ratio * 100.0))
    return {
        "name": profile_name,
        "at": at,
        "avg": ratio_sum / float(SIM_SECONDS),
        "collapse_at": collapse_at,
        "fish_per_sec": float(gs.fish_count) / float(SIM_SECONDS),
        "income": _income(gs, prestige >= 2)
    }


# Income over the sim: tins fish while the cannery has time (best gain per
# second first), then sells within the per-tick sell cap, priciest first.
# A tin uses the fish's best recipe (cost-plus price minus add-on costs, its
# processes' time with equipment speed) when the profile knows recipes, else
# the experimental stable tin.
func _income(gs, knows_recipes: bool) -> int:
    var cannery_seconds := 0.0
    if gs.is_cannery_unlocked and gs.get_auto_tin_enabled():
        cannery_seconds = float(SIM_SECONDS)
    var entries: Array = []
    for fish_id in gs.fish_stock_by_id:
        var tin := _best_tin(gs, str(fish_id), knows_recipes)
        entries.append({
            "count": int(gs.fish_stock_by_id[fish_id]),
            "raw": gs.get_fish_sell_price_for_id(str(fish_id)),
            "yield": gs.get_fish_cannery_yield(str(fish_id)),
            "tin_price": tin["price"],
            "addon_cost": tin["addon_cost"],
            "seconds": tin["seconds"]
        })
    entries.sort_custom(func(a, b): return _tin_gain_per_sec(a) > _tin_gain_per_sec(b))
    var units: Array = []  # [price, count] of everything put up for sale
    var costs := 0
    for entry in entries:
        var count: int = entry["count"]
        var tinned := 0
        if _tin_gain_per_sec(entry) > 0.0:
            tinned = mini(count, int(cannery_seconds / float(entry["seconds"])))
            cannery_seconds -= float(tinned) * float(entry["seconds"])
        costs += tinned * int(entry["addon_cost"])
        units.append([int(entry["tin_price"]), tinned * int(entry["yield"])])
        units.append([int(entry["raw"]), count - tinned])
    units.sort_custom(func(a, b): return a[0] > b[0])
    var sell_left: int = gs.get_sell_count_per_tick() * SIM_SECONDS
    var income := -costs
    for unit in units:
        var sold := mini(int(unit[1]), sell_left)
        sell_left -= sold
        income += sold * int(unit[0])
    return income


func _tin_gain_per_sec(entry: Dictionary) -> float:
    var gain: float = float(entry["yield"] * entry["tin_price"] - entry["addon_cost"] - entry["raw"])
    return gain / float(entry["seconds"])


func _best_tin(gs, fish_id: String, knows_recipes: bool) -> Dictionary:
    var best := {
        "price": gs.get_tin_sell_price_for_key("experimental_tin_stable"),
        "addon_cost": 0,
        "seconds": gs.get_tin_make_time_for_processes(["tin_pack", "tin_seal"])
    }
    if not knows_recipes:
        return best
    for recipe_def in gs.recipe_defs:
        if gs._get_recipe_fish_id(recipe_def) != fish_id:
            continue
        var addon_cost := 0
        for item_id in gs.get_recipe_addon_ids(recipe_def):
            addon_cost += gs.get_item_cost(str(item_id))
        var candidate := {
            "price": gs.get_recipe_tin_price(str(recipe_def.get("recipe_id", ""))),
            "addon_cost": addon_cost,
            "seconds": gs.get_tin_make_time_for_processes(recipe_def.get("processes", []))
        }
        var yield_count: int = gs.get_fish_cannery_yield(fish_id)
        var candidate_rate := float(candidate["price"] * yield_count - addon_cost) / float(candidate["seconds"])
        var best_rate := float(best["price"] * yield_count - int(best["addon_cost"])) / float(best["seconds"])
        if candidate_rate > best_rate:
            best = candidate
    return best
