extends Node

signal changed
signal cannery_unlocked
signal cannery_discovered
signal crew_trip_updated
signal crew_discovered
signal crew_unlocked
signal ocean_health_changed
signal reputation_changed
signal skills_changed
signal ending_reached(ending_id, summary)

const UPGRADE_DATA_PATH := "res://data/raw/upgrades.json"
const SKILL_TREE_DATA_PATH := "res://data/raw/skill_tree.json"
const FISH_DATA_PATH := "res://data/raw/fish.json"
const RECIPE_DATA_PATH := "res://data/raw/recipes.json"
const ITEM_DATA_PATH := "res://data/raw/items.json"
const EQUIPMENT_DATA_PATH := "res://data/raw/equipment.json"
const PROCESS_DATA_PATH := "res://data/raw/processes.json"
const SAVE_PATH := "user://save.json"
const GREEN_ZONE_BASE_RATIO := 0.10
const TIN_MAKE_BASE_TIME := 3.0
const SAVE_VERSION := 11
const PRESTIGE_TINS_REQUIRED := 100
const REPUTATION_MONEY_DIVISOR := 100
const OCEAN_HEALTH_MAX := 100.0
const OCEAN_HEALTH_MIN := 0.0
const OCEAN_HEALTH_FISH_COST := 1.0
const OCEAN_HEALTH_REGEN_PER_SEC := 1000.0
const OCEAN_HEALTH_COLLAPSE_THRESHOLD := 0.0
# Ending tuning and proxies (quality/legendary not implemented yet).
const SUSTAINABLE_HEALTH_AVG_THRESHOLD := 0.85
const SUSTAINABLE_MIN_SECONDS := 3.0 * 60.0 * 60.0
const INDUSTRIAL_MIN_SECONDS := 2.0 * 60.0 * 60.0
const DUAL_MIN_SECONDS := 6.0 * 60.0 * 60.0
const INDUSTRIAL_MIN_LIFETIME_MONEY := 50000
const SUSTAINABLE_MIN_TOTAL_UPGRADES := 12
const DUAL_MIN_LIFETIME_MONEY := 250000
const UPGRADES_VISIBLE_PER_CATEGORY := 3

const SUSTAINABLE_FISH_SELL_ADD_PER_LEVEL := 1
const SUSTAINABLE_GREEN_ZONE_ADD_PCT_PER_LEVEL := 0.01
const INDUSTRIAL_TIN_SELL_ADD_PER_LEVEL := 1
const INDUSTRIAL_TIN_TIME_ADD_PER_LEVEL := -0.1
const RequiresEval = preload("res://src/requires/requires_eval.gd")

# Economy
var fish_count: int = 0
var tin_count: int = 0
var money: int = 0
var garlic_count: int = 0
var fish_stock_by_id: Dictionary = {}
var tin_inventory: Dictionary = {}
var recipes_unlocked: Array = []
var tin_cooldown_remaining: float = 0.0
var tin_method_id: String = "raw"
var tin_ingredient_id: String = "none"
var tins_sold: int = 0
var fish_sold: int = 0
var ocean_health: float = OCEAN_HEALTH_MAX
var ocean_health_time_accum: float = 0.0
var ocean_health_time_total: float = 0.0
var run_time_seconds: float = 0.0
var run_paused: bool = false

enum EndingState { NONE, INDUSTRIAL_COLLAPSE, SUSTAINABLE_EQUILIBRIUM, DUAL_MASTERY }
var ending_state: EndingState = EndingState.NONE

# MetaState (persists across runs)
var meta_state: Dictionary = {
    "reputation": 0,
    "prestige_count": 0,
    "sustainable_bonus_level": 0,
    "industrial_bonus_level": 0,
    "skills_owned": [],
    "discovered_fish_ids": [],
    "fish_lifetime_stats": {},
    "discovered_recipe_ids": [],
    "recipe_lifetime_stats": {}
}

# Upgrades: Cannery
const CANNERY_UNLOCK_COST := 200
const CANNERY_DISCOVERY_EARNED := 50
var is_cannery_discovered: bool = false
var is_cannery_unlocked: bool = false
var lifetime_money_earned: int = 0

# Crew unlock
const CREW_UNLOCK_COST := 120
const CREW_DISCOVERY_EARNED := 80
var is_crew_discovered: bool = false
var is_crew_unlocked: bool = false

# Market
enum SellMode { FISH, TINS }
var sell_mode: SellMode = SellMode.FISH
const GARLIC_PRICE := 5

# Crew trips
const CREW_TRIP_BASE_DURATION := 12.0
const CREW_TRIP_BASE_CATCH := 3
var crew_trip_active: bool = false
var crew_trip_remaining: float = 0.0
var crew_trip_paused: bool = false
var _rng := RandomNumberGenerator.new()

# Upgrades
var upgrade_defs: Array = []
var upgrade_defs_by_id: Dictionary = {}
var upgrade_levels: Dictionary = {}
var upgrade_pairs: Dictionary = {}
var upgrade_order_by_category: Dictionary = {}
var visible_upgrades_by_category: Dictionary = {}
var chosen_exclusive_groups: Dictionary = {}
var policy_stage_chosen: Dictionary = {}
var skill_defs: Array = []
var skill_defs_by_id: Dictionary = {}
var fish_defs: Array = []
var fish_defs_by_id: Dictionary = {}
var fish_name_to_id: Dictionary = {}
var recipe_defs: Array = []
var recipe_defs_by_id: Dictionary = {}
var recipe_ids_by_fish_id: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    _load_upgrades()
    _load_skill_tree()
    _load_fish_defs()
    _load_recipe_defs()
    _validate_requires_data_dev()
    _rng.randomize()

func save_game() -> void:
    var data := {
        "version": SAVE_VERSION,
        "fish_count": fish_count,
        "tin_count": tin_count,
        "money": money,
        "garlic_count": garlic_count,
        "fish_stock_by_id": fish_stock_by_id,
        "lifetime_money_earned": lifetime_money_earned,
        "sell_mode": int(sell_mode),
        "is_cannery_discovered": is_cannery_discovered,
        "is_cannery_unlocked": is_cannery_unlocked,
        "is_crew_discovered": is_crew_discovered,
        "is_crew_unlocked": is_crew_unlocked,
        "upgrade_levels": upgrade_levels,
        "tin_inventory": tin_inventory,
        "recipes_unlocked": recipes_unlocked,
        "crew_trip_active": crew_trip_active,
        "crew_trip_remaining": crew_trip_remaining,
        "tins_sold": tins_sold,
        "fish_sold": fish_sold,
        "meta_state": meta_state,
        "ocean_health": ocean_health,
        "ocean_health_time_accum": ocean_health_time_accum,
        "ocean_health_time_total": ocean_health_time_total,
        "run_time_seconds": run_time_seconds,
        "ending_state": int(ending_state),
        "visible_upgrades_by_category": visible_upgrades_by_category,
        "chosen_exclusive_groups": chosen_exclusive_groups,
        "policy_stage_chosen": policy_stage_chosen
    }
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(data))
    file.close()

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    var raw := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    _apply_save(parsed)
    reputation_changed.emit()
    skills_changed.emit()
    changed.emit()
    return true

func new_game() -> void:
    fish_count = 0
    tin_count = 0
    money = 0
    garlic_count = 0
    fish_stock_by_id.clear()
    tin_inventory.clear()
    recipes_unlocked.clear()
    lifetime_money_earned = 0
    tins_sold = 0
    fish_sold = 0
    ocean_health = OCEAN_HEALTH_MAX
    ocean_health_time_accum = 0.0
    ocean_health_time_total = 0.0
    visible_upgrades_by_category.clear()
    run_time_seconds = 0.0
    run_paused = false
    ending_state = EndingState.NONE
    sell_mode = SellMode.FISH
    is_cannery_discovered = false
    is_cannery_unlocked = false
    is_crew_discovered = false
    is_crew_unlocked = false
    upgrade_levels.clear()
    visible_upgrades_by_category.clear()
    chosen_exclusive_groups.clear()
    policy_stage_chosen.clear()
    crew_trip_active = false
    crew_trip_remaining = 0.0
    crew_trip_paused = false
    meta_state = {
        "reputation": 0,
        "prestige_count": 0,
        "sustainable_bonus_level": 0,
        "industrial_bonus_level": 0,
        "skills_owned": [],
        "discovered_fish_ids": [],
        "fish_lifetime_stats": {},
        "discovered_recipe_ids": [],
        "recipe_lifetime_stats": {}
    }
    reputation_changed.emit()
    skills_changed.emit()
    changed.emit()
    save_game()

func save_exists() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func _apply_save(data: Dictionary) -> void:
    var version := int(data.get("version", 1))
    fish_count = int(data.get("fish_count", 0))
    tin_count = int(data.get("tin_count", 0))
    money = int(data.get("money", 0))
    garlic_count = int(data.get("garlic_count", 0))
    fish_stock_by_id = data.get("fish_stock_by_id", {})
    lifetime_money_earned = int(data.get("lifetime_money_earned", 0))
    sell_mode = int(data.get("sell_mode", 0)) as SellMode
    is_cannery_discovered = bool(data.get("is_cannery_discovered", false))
    is_cannery_unlocked = bool(data.get("is_cannery_unlocked", false))
    is_crew_discovered = bool(data.get("is_crew_discovered", false))
    is_crew_unlocked = bool(data.get("is_crew_unlocked", false))
    upgrade_levels = data.get("upgrade_levels", {})
    tin_inventory = data.get("tin_inventory", {})
    recipes_unlocked = data.get("recipes_unlocked", [])
    crew_trip_active = bool(data.get("crew_trip_active", false))
    crew_trip_remaining = float(data.get("crew_trip_remaining", 0.0))
    tins_sold = int(data.get("tins_sold", 0))
    fish_sold = int(data.get("fish_sold", 0))
    meta_state = data.get("meta_state", meta_state)
    ocean_health = float(data.get("ocean_health", OCEAN_HEALTH_MAX))
    ocean_health_time_accum = float(data.get("ocean_health_time_accum", 0.0))
    ocean_health_time_total = float(data.get("ocean_health_time_total", 0.0))
    run_time_seconds = float(data.get("run_time_seconds", 0.0))
    ending_state = int(data.get("ending_state", EndingState.NONE)) as EndingState
    visible_upgrades_by_category = data.get("visible_upgrades_by_category", {})
    var has_chosen_groups := data.has("chosen_exclusive_groups")
    var has_stage_chosen := data.has("policy_stage_chosen")
    chosen_exclusive_groups = data.get("chosen_exclusive_groups", {})
    policy_stage_chosen = data.get("policy_stage_chosen", {})
    if typeof(visible_upgrades_by_category) != TYPE_DICTIONARY:
        visible_upgrades_by_category = {}
    if typeof(chosen_exclusive_groups) != TYPE_DICTIONARY:
        chosen_exclusive_groups = {}
    if typeof(policy_stage_chosen) != TYPE_DICTIONARY:
        policy_stage_chosen = {}
    if typeof(fish_stock_by_id) != TYPE_DICTIONARY:
        fish_stock_by_id = {}
    run_paused = ending_state != EndingState.NONE
    _normalize_meta_state()
    _normalize_policy_state()
    if not has_chosen_groups or not has_stage_chosen:
        _rebuild_policy_state()
    _reconcile_fish_stock()
    _reconcile_recipe_state()
    if version < SAVE_VERSION:
        _migrate_save(version)

func _migrate_save(version: int) -> void:
    if version < 2:
        _normalize_meta_state()
    if version < 3:
        ocean_health = OCEAN_HEALTH_MAX
    if version < 4:
        ocean_health_time_accum = 0.0
        ocean_health_time_total = 0.0
    if version < 5:
        run_time_seconds = 0.0
        ending_state = EndingState.NONE
    if version < 6:
        _normalize_meta_state()
    if version < 7:
        visible_upgrades_by_category.clear()
    if version < 8:
        fish_stock_by_id.clear()
        _normalize_meta_state()
        _reconcile_fish_stock()
    if version < 9:
        _normalize_meta_state()
        _reconcile_recipe_state()
    if version < 10:
        _reset_recipe_tracking_from_inventory()
    if version < 11:
        _rebuild_policy_state()

func _normalize_meta_state() -> void:
    if typeof(meta_state) != TYPE_DICTIONARY:
        meta_state = {}
    if not meta_state.has("reputation"):
        meta_state["reputation"] = 0
    if not meta_state.has("prestige_count"):
        meta_state["prestige_count"] = 0
    if not meta_state.has("sustainable_bonus_level"):
        meta_state["sustainable_bonus_level"] = 0
    if not meta_state.has("industrial_bonus_level"):
        meta_state["industrial_bonus_level"] = 0
    if not meta_state.has("skills_owned"):
        meta_state["skills_owned"] = []
    if not meta_state.has("discovered_fish_ids"):
        meta_state["discovered_fish_ids"] = []
    if not meta_state.has("fish_lifetime_stats"):
        meta_state["fish_lifetime_stats"] = {}
    if not meta_state.has("discovered_recipe_ids"):
        meta_state["discovered_recipe_ids"] = []
    if not meta_state.has("recipe_lifetime_stats"):
        meta_state["recipe_lifetime_stats"] = {}
    if typeof(meta_state["discovered_fish_ids"]) != TYPE_ARRAY:
        meta_state["discovered_fish_ids"] = []
    if typeof(meta_state["fish_lifetime_stats"]) != TYPE_DICTIONARY:
        meta_state["fish_lifetime_stats"] = {}
    if typeof(meta_state["discovered_recipe_ids"]) != TYPE_ARRAY:
        meta_state["discovered_recipe_ids"] = []
    if typeof(meta_state["recipe_lifetime_stats"]) != TYPE_DICTIONARY:
        meta_state["recipe_lifetime_stats"] = {}
    var discovered: Array = meta_state["discovered_fish_ids"]
    var all_stats: Dictionary = meta_state["fish_lifetime_stats"]
    for fish_id in all_stats.keys():
        var stats: Dictionary = all_stats.get(fish_id, {})
        if typeof(stats) != TYPE_DICTIONARY:
            continue
        if int(stats.get("caught", 0)) > 0 and not discovered.has(str(fish_id)):
            discovered.append(str(fish_id))
    meta_state["discovered_fish_ids"] = discovered
    var discovered_recipes: Array = meta_state["discovered_recipe_ids"]
    var recipe_stats: Dictionary = meta_state["recipe_lifetime_stats"]
    for recipe_id in recipe_stats.keys():
        var stats: Dictionary = recipe_stats.get(recipe_id, {})
        if typeof(stats) != TYPE_DICTIONARY:
            continue
        if int(stats.get("produced", 0)) > 0 and not discovered_recipes.has(str(recipe_id)):
            discovered_recipes.append(str(recipe_id))
    meta_state["discovered_recipe_ids"] = discovered_recipes

func _normalize_policy_state() -> void:
    if typeof(chosen_exclusive_groups) != TYPE_DICTIONARY:
        chosen_exclusive_groups = {}
    if typeof(policy_stage_chosen) != TYPE_DICTIONARY:
        policy_stage_chosen = {}

func _rebuild_policy_state() -> void:
    chosen_exclusive_groups = {}
    policy_stage_chosen = {}
    for def in upgrade_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        var upgrade_id := str(def.get("upgrade_id", ""))
        if upgrade_id == "":
            continue
        if get_upgrade_level(upgrade_id) <= 0:
            continue
        var group_id := _get_exclusive_group_id(def)
        if group_id != "" and bool(def.get("exclusive_choice", false)):
            if not chosen_exclusive_groups.has(group_id):
                chosen_exclusive_groups[group_id] = upgrade_id
        var stage := _get_policy_stage(def)
        if group_id != "" and stage > 0:
            var existing := int(policy_stage_chosen.get(group_id, 0))
            if stage > existing:
                policy_stage_chosen[group_id] = stage

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    if run_paused:
        return
    if crew_trip_active and not crew_trip_paused:
        crew_trip_remaining = max(0.0, crew_trip_remaining - delta)
        if crew_trip_remaining <= 0.0:
            _complete_crew_trip()
    if _should_auto_send_crew():
        start_crew_trip()
    if tin_cooldown_remaining > 0.0:
        tin_cooldown_remaining = max(0.0, tin_cooldown_remaining - delta)
    if get_auto_tin_enabled() and _can_auto_tin():
        try_make_tin(tin_method_id, tin_ingredient_id)
    _regenerate_ocean_health(delta)
    _track_ocean_health(delta)
    _track_run_time(delta)
    _check_endings()

func catch_fish(amount: int = 1) -> void:
    var bonus: int = _get_effect_total("catch_add") + _get_skill_effect_total_int("catch_add")
    var mult: float = 1.0 + _get_effect_total_float("catch_mult") + _get_skill_effect_total_float("catch_mult")
    mult = max(0.1, mult)
    var catch_total: int = max(1, int(round(float(amount + bonus) * mult)))
    fish_count += catch_total
    _record_caught_fish(catch_total)
    _apply_ocean_health_pressure(catch_total)
    changed.emit()

func make_tin() -> bool:
    if fish_count <= 0:
        return false
    fish_count -= 1
    tin_count += 1
    var consumed_fish_id := _consume_fish_from_stock()
    if consumed_fish_id != "":
        _increment_fish_lifetime_stat(consumed_fish_id, "tins_produced", 1)
    changed.emit()
    return true

func make_tin_with(_method_id: String, _ingredient_id: String) -> bool:
    if fish_count <= 0:
        return false
    if _ingredient_id != "none" and garlic_count <= 0:
        return false
    fish_count -= 1
    tin_count += 1
    if _ingredient_id == "garlic":
        garlic_count -= 1
    var consumed_fish_id := _consume_fish_from_stock()
    if consumed_fish_id != "":
        _increment_fish_lifetime_stat(consumed_fish_id, "tins_produced", 1)
    var recipe_id := _select_recipe_for_tinning(consumed_fish_id, _method_id, _ingredient_id)
    if recipe_id != "":
        _mark_recipe_discovered(recipe_id)
        _increment_recipe_lifetime_stat(recipe_id, "produced", 1)
    var key: String = _make_tin_key(_method_id, _ingredient_id)
    tin_inventory[key] = int(tin_inventory.get(key, 0)) + 1
    _unlock_recipe(recipe_id, _method_id, _ingredient_id)
    changed.emit()
    return true

func try_make_tin(method_id: String, ingredient_id: String) -> bool:
    if not can_make_tin():
        return false
    if not is_cannery_unlocked:
        return false
    if not make_tin_with(method_id, ingredient_id):
        return false
    start_tin_cooldown()
    return true

func _remove_random_tin() -> String:
    if tin_inventory.is_empty():
        return ""
    var keys: Array = tin_inventory.keys()
    if keys.is_empty():
        return ""
    var idx: int = _rng.randi_range(0, keys.size() - 1)
    var key: String = str(keys[idx])
    var count: int = int(tin_inventory.get(key, 0))
    if count <= 1:
        tin_inventory.erase(key)
    else:
        tin_inventory[key] = count - 1
    return key

func _add_money(amount: int) -> void:
    if amount <= 0:
        return
    money += amount
    lifetime_money_earned += amount
    _check_cannery_discovery()
    _check_crew_discovery()
    changed.emit()

func buy_garlic(count: int) -> bool:
    if count <= 0:
        return false
    var cost: int = GARLIC_PRICE * count
    if money < cost:
        return false
    money -= cost
    garlic_count += count
    changed.emit()
    return true

func sell_tick() -> void:
    match sell_mode:
        SellMode.FISH:
            if fish_count > 0:
                var count: int = min(fish_count, get_fish_sell_count())
                fish_count -= count
                fish_sold += count
                _record_fish_sales(count)
                _add_money(get_fish_sell_price() * count)
        SellMode.TINS:
            if tin_count > 0:
                tin_count -= 1
                var sold_recipe_key := _remove_random_tin()
                # Sanity: tins_sold should only advance when a tin is sold.
                tins_sold += 1
                var sale_price := get_tin_sell_price()
                _record_recipe_sale(sold_recipe_key, sale_price)
                _add_money(sale_price)
    changed.emit()

func set_sell_mode(mode: SellMode) -> void:
    if sell_mode == mode:
        return
    sell_mode = mode
    changed.emit()

#########
# Cannery
#########
func _check_cannery_discovery() -> void:
    if is_cannery_discovered:
        return
    if lifetime_money_earned >= CANNERY_DISCOVERY_EARNED:
        is_cannery_discovered = true
        cannery_discovered.emit()
        changed.emit()

func cannery_upgrade_is_visible() -> bool:
    # Visible only when discovered and not already purchased
    return is_cannery_discovered and (not is_cannery_unlocked)        

func can_purchase_cannery() -> bool:
    # Clickable when visible + you have enough money
    return cannery_upgrade_is_visible() and money >= CANNERY_UNLOCK_COST

func purchase_unlocked_cannery() -> bool:
    if not can_purchase_cannery():
        return false
    money -= CANNERY_UNLOCK_COST
    is_cannery_unlocked = true
    cannery_unlocked.emit()
    return true

########
# Crew
########
func _check_crew_discovery() -> void:
    if is_crew_discovered:
        return
    if lifetime_money_earned >= CREW_DISCOVERY_EARNED:
        is_crew_discovered = true
        crew_discovered.emit()
        changed.emit()

func crew_unlock_is_visible() -> bool:
    return is_crew_discovered and (not is_crew_unlocked)

func can_purchase_crew() -> bool:
    return crew_unlock_is_visible() and money >= CREW_UNLOCK_COST

func purchase_unlocked_crew() -> bool:
    if not can_purchase_crew():
        return false
    money -= CREW_UNLOCK_COST
    is_crew_unlocked = true
    crew_unlocked.emit()
    changed.emit()
    return true

################
# Upgrade System
################
func _load_upgrades() -> void:
    if upgrade_defs.size() > 0:
        return
    if not FileAccess.file_exists(UPGRADE_DATA_PATH):
        return
    var file := FileAccess.open(UPGRADE_DATA_PATH, FileAccess.READ)
    var raw := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_ARRAY:
        return
    upgrade_defs = parsed
    upgrade_defs_by_id.clear()
    upgrade_pairs.clear()
    upgrade_order_by_category.clear()
    for def in upgrade_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        if not def.has("upgrade_id"):
            continue
        var upgrade_id := str(def.get("upgrade_id", ""))
        if upgrade_id == "":
            continue
        upgrade_defs_by_id[upgrade_id] = def
        var group_id := _get_exclusive_group_id(def)
        if group_id != "":
            if not upgrade_pairs.has(group_id):
                upgrade_pairs[group_id] = []
            upgrade_pairs[group_id].append(upgrade_id)
        var category := str(def.get("category", "misc"))
        if not upgrade_order_by_category.has(category):
            upgrade_order_by_category[category] = []
        upgrade_order_by_category[category].append(upgrade_id)

func _load_skill_tree() -> void:
    if skill_defs.size() > 0:
        return
    if not FileAccess.file_exists(SKILL_TREE_DATA_PATH):
        return
    var file := FileAccess.open(SKILL_TREE_DATA_PATH, FileAccess.READ)
    var raw := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_ARRAY:
        return
    skill_defs = parsed
    skill_defs_by_id.clear()
    for def in skill_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        if not def.has("id"):
            continue
        skill_defs_by_id[def.id] = def

func _load_fish_defs() -> void:
    fish_defs.clear()
    fish_defs_by_id.clear()
    fish_name_to_id.clear()
    if not FileAccess.file_exists(FISH_DATA_PATH):
        return
    var file := FileAccess.open(FISH_DATA_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_ARRAY:
        return
    fish_defs = parsed
    for fish_def in fish_defs:
        if typeof(fish_def) != TYPE_DICTIONARY:
            continue
        var fish_id := str(fish_def.get("fish_id", ""))
        if fish_id == "":
            continue
        fish_defs_by_id[fish_id] = fish_def
        var display_name := str(fish_def.get("display_name", ""))
        if display_name != "":
            fish_name_to_id[display_name] = fish_id

func _load_recipe_defs() -> void:
    recipe_defs.clear()
    recipe_defs_by_id.clear()
    recipe_ids_by_fish_id.clear()
    if not FileAccess.file_exists(RECIPE_DATA_PATH):
        return
    var file := FileAccess.open(RECIPE_DATA_PATH, FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_ARRAY:
        return
    recipe_defs = parsed
    for recipe_def in recipe_defs:
        if typeof(recipe_def) != TYPE_DICTIONARY:
            continue
        var recipe_id := str(recipe_def.get("recipe_id", ""))
        if recipe_id == "":
            continue
        recipe_defs_by_id[recipe_id] = recipe_def
        var required_fish_name := str(recipe_def.get("required_fish_name", ""))
        var fish_id := str(fish_name_to_id.get(required_fish_name, ""))
        if fish_id == "":
            continue
        if not recipe_ids_by_fish_id.has(fish_id):
            recipe_ids_by_fish_id[fish_id] = []
        var ids: Array = recipe_ids_by_fish_id[fish_id]
        ids.append(recipe_id)
        recipe_ids_by_fish_id[fish_id] = ids

func _validate_requires_data_dev() -> void:
    if not OS.is_debug_build():
        return
    var valid_upgrade_ids: Dictionary = {}
    for upgrade_id in upgrade_defs_by_id.keys():
        valid_upgrade_ids[str(upgrade_id)] = true

    var valid_item_ids: Dictionary = {}
    var item_defs := _read_json_array(ITEM_DATA_PATH)
    for item_def in item_defs:
        if typeof(item_def) != TYPE_DICTIONARY:
            continue
        var ingredient_id := str(item_def.get("ingredient_id", ""))
        if ingredient_id == "":
            continue
        valid_item_ids[ingredient_id] = true

    var files := [
        {"path": UPGRADE_DATA_PATH, "id_key": "upgrade_id"},
        {"path": FISH_DATA_PATH, "id_key": "fish_id"},
        {"path": ITEM_DATA_PATH, "id_key": "ingredient_id"},
        {"path": EQUIPMENT_DATA_PATH, "id_key": "equipment_id"},
        {"path": RECIPE_DATA_PATH, "id_key": "recipe_id"},
        {"path": PROCESS_DATA_PATH, "id_key": "process_id"}
    ]
    for file_info in files:
        var data_path := str(file_info.get("path", ""))
        var id_key := str(file_info.get("id_key", "id"))
        var defs := _read_json_array(data_path)
        if defs.is_empty():
            continue
        _validate_requires_entries(data_path, defs, id_key, valid_upgrade_ids, valid_item_ids)

func _read_json_array(path: String) -> Array:
    if not FileAccess.file_exists(path):
        return []
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return []
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_ARRAY:
        return []
    return parsed

func _validate_requires_entries(data_path: String, defs: Array, id_key: String, valid_upgrade_ids: Dictionary, valid_item_ids: Dictionary) -> void:
    for index in range(defs.size()):
        var def = defs[index]
        if typeof(def) != TYPE_DICTIONARY:
            continue
        var entry: Dictionary = def
        var entry_id := str(entry.get(id_key, ""))
        if entry_id == "":
            entry_id = "index=%d" % index

        if entry.has("requires") and typeof(entry.get("requires", null)) != TYPE_ARRAY:
            push_warning("Requires validation (%s, %s): requires must be an Array." % [data_path, entry_id])
            continue

        var reqs: Array = RequiresEval.get_requires(entry)
        for req_idx in range(reqs.size()):
            var req = reqs[req_idx]
            if typeof(req) != TYPE_DICTIONARY:
                push_warning("Requires validation (%s, %s, req[%d]): condition must be a Dictionary." % [data_path, entry_id, req_idx])
                continue
            var req_dict: Dictionary = req
            var req_type := str(req_dict.get("type", ""))
            if req_type == "":
                push_warning("Requires validation (%s, %s, req[%d]): missing condition type." % [data_path, entry_id, req_idx])
                continue

            if req_type == "upgrade_purchased" or req_type == "upgrade_level_at_least":
                var req_upgrade_id := str(req_dict.get("upgrade_id", ""))
                if req_upgrade_id == "":
                    var value = req_dict.get("value", null)
                    if typeof(value) == TYPE_STRING:
                        req_upgrade_id = str(value)
                if req_upgrade_id != "" and not valid_upgrade_ids.has(req_upgrade_id):
                    push_warning("Requires validation (%s, %s, req[%d]): unknown upgrade_id '%s'." % [data_path, entry_id, req_idx, req_upgrade_id])

            if req_type == "item_owned_at_least":
                var req_item_id := str(req_dict.get("item_id", ""))
                if req_item_id == "":
                    var item_value = req_dict.get("value", null)
                    if typeof(item_value) == TYPE_STRING:
                        req_item_id = str(item_value)
                if req_item_id != "" and not valid_item_ids.has(req_item_id):
                    push_warning("Requires validation (%s, %s, req[%d]): unknown item_id '%s'." % [data_path, entry_id, req_idx, req_item_id])

func get_collection_fish_defs() -> Array:
    return fish_defs

func get_collection_recipe_defs() -> Array:
    return recipe_defs

func is_fish_discovered(fish_id: String) -> bool:
    var discovered: Array = meta_state.get("discovered_fish_ids", [])
    return discovered.has(fish_id)

func get_fish_lifetime_stats(fish_id: String) -> Dictionary:
    var all_stats: Dictionary = meta_state.get("fish_lifetime_stats", {})
    var stats: Dictionary = all_stats.get(fish_id, {})
    if typeof(stats) != TYPE_DICTIONARY:
        stats = {}
    return {
        "caught": int(stats.get("caught", 0)),
        "sold": int(stats.get("sold", 0)),
        "tins_produced": int(stats.get("tins_produced", 0))
    }

func is_recipe_discovered(recipe_id: String) -> bool:
    var discovered: Array = meta_state.get("discovered_recipe_ids", [])
    return discovered.has(recipe_id)

func get_recipe_lifetime_stats(recipe_id: String) -> Dictionary:
    var all_stats: Dictionary = meta_state.get("recipe_lifetime_stats", {})
    var stats: Dictionary = all_stats.get(recipe_id, {})
    if typeof(stats) != TYPE_DICTIONARY:
        stats = {}
    return {
        "produced": int(stats.get("produced", 0)),
        "revenue_generated": int(stats.get("revenue_generated", 0))
    }

func _record_caught_fish(count: int) -> void:
    for _i in range(count):
        var fish_id := _pick_catchable_fish_id()
        if fish_id == "":
            continue
        fish_stock_by_id[fish_id] = int(fish_stock_by_id.get(fish_id, 0)) + 1
        _mark_fish_discovered(fish_id)
        _increment_fish_lifetime_stat(fish_id, "caught", 1)

func _record_fish_sales(count: int) -> void:
    for _i in range(count):
        var fish_id := _consume_fish_from_stock()
        if fish_id == "":
            break
        _increment_fish_lifetime_stat(fish_id, "sold", 1)

func _consume_fish_from_stock() -> String:
    for fish_id in fish_stock_by_id.keys():
        var id_str := str(fish_id)
        var count: int = int(fish_stock_by_id[id_str])
        if count <= 0:
            continue
        if count == 1:
            fish_stock_by_id.erase(id_str)
        else:
            fish_stock_by_id[id_str] = count - 1
        return id_str
    return ""

func _mark_fish_discovered(fish_id: String) -> void:
    if fish_id == "":
        return
    var discovered: Array = meta_state.get("discovered_fish_ids", [])
    if discovered.has(fish_id):
        return
    discovered.append(fish_id)
    meta_state["discovered_fish_ids"] = discovered

func _increment_fish_lifetime_stat(fish_id: String, stat_key: String, amount: int) -> void:
    if fish_id == "" or amount <= 0:
        return
    var all_stats: Dictionary = meta_state.get("fish_lifetime_stats", {})
    var stats: Dictionary = all_stats.get(fish_id, {})
    if typeof(stats) != TYPE_DICTIONARY:
        stats = {}
    stats[stat_key] = int(stats.get(stat_key, 0)) + amount
    all_stats[fish_id] = stats
    meta_state["fish_lifetime_stats"] = all_stats

func _mark_recipe_discovered(recipe_id: String) -> void:
    if recipe_id == "":
        return
    var discovered: Array = meta_state.get("discovered_recipe_ids", [])
    if discovered.has(recipe_id):
        return
    discovered.append(recipe_id)
    meta_state["discovered_recipe_ids"] = discovered

func _increment_recipe_lifetime_stat(recipe_id: String, stat_key: String, amount: int) -> void:
    if recipe_id == "" or amount <= 0:
        return
    var all_stats: Dictionary = meta_state.get("recipe_lifetime_stats", {})
    var stats: Dictionary = all_stats.get(recipe_id, {})
    if typeof(stats) != TYPE_DICTIONARY:
        stats = {}
    stats[stat_key] = int(stats.get(stat_key, 0)) + amount
    all_stats[recipe_id] = stats
    meta_state["recipe_lifetime_stats"] = all_stats

func _select_recipe_for_tinning(fish_id: String, method_id: String, ingredient_id: String) -> String:
    if fish_id == "":
        return ""
    var recipe_ids: Array = recipe_ids_by_fish_id.get(fish_id, [])
    if recipe_ids.is_empty():
        return ""
    var seed_text := "%s|%s|%s" % [fish_id, method_id, ingredient_id]
    var hash_val: int = int(abs(seed_text.hash()))
    return str(recipe_ids[hash_val % recipe_ids.size()])

func _record_recipe_sale(recipe_id: String, revenue: int) -> void:
    if recipe_id == "":
        return
    if not recipe_defs_by_id.has(recipe_id):
        return
    _increment_recipe_lifetime_stat(recipe_id, "revenue_generated", max(0, revenue))

func _pick_catchable_fish_id() -> String:
    var available_defs := _get_catchable_fish_defs()
    if available_defs.is_empty():
        return _get_fallback_fish_id()

    var total_weight: int = 0
    for fish_def in available_defs:
        var fish_dict: Dictionary = fish_def
        var spawn_weight := int(fish_dict.get("spawn_weight", 1))
        total_weight += max(1, spawn_weight)
    if total_weight <= 0:
        return _get_fallback_fish_id()

    var roll := _rng.randi_range(1, total_weight)
    var running := 0
    for fish_def in available_defs:
        var fish_dict: Dictionary = fish_def
        running += max(1, int(fish_dict.get("spawn_weight", 1)))
        if roll <= running:
            return str(fish_dict.get("fish_id", ""))
    return _get_fallback_fish_id()

func _get_catchable_fish_defs() -> Array:
    var out: Array = []
    for fish_def in fish_defs:
        if typeof(fish_def) != TYPE_DICTIONARY:
            continue
        if _is_fish_requires_met(fish_def):
            out.append(fish_def)
    return out

func _is_fish_requires_met(fish_def: Dictionary) -> bool:
    var reqs := RequiresEval.get_requires(fish_def)
    return RequiresEval.is_met(reqs, self)

func _get_fallback_fish_id() -> String:
    if fish_defs.is_empty():
        return ""
    var first_def = fish_defs[0]
    if typeof(first_def) != TYPE_DICTIONARY:
        return ""
    var fish_dict: Dictionary = first_def
    return str(fish_dict.get("fish_id", ""))

func _reconcile_fish_stock() -> void:
    var total: int = 0
    for fish_id in fish_stock_by_id.keys():
        total += int(fish_stock_by_id[fish_id])
    var delta := fish_count - total
    if delta > 0:
        var fallback_id := _get_fallback_fish_id()
        if fallback_id != "":
            fish_stock_by_id[fallback_id] = int(fish_stock_by_id.get(fallback_id, 0)) + delta
    elif delta < 0:
        var to_remove := -delta
        for fish_id in fish_stock_by_id.keys():
            if to_remove <= 0:
                break
            var id_str := str(fish_id)
            var count: int = int(fish_stock_by_id[id_str])
            if count <= to_remove:
                to_remove -= count
                fish_stock_by_id.erase(id_str)
            else:
                fish_stock_by_id[id_str] = count - to_remove
                to_remove = 0

func _reconcile_recipe_state() -> void:
    var discovered: Array = meta_state.get("discovered_recipe_ids", [])
    meta_state["discovered_recipe_ids"] = discovered

    var all_stats: Dictionary = meta_state.get("recipe_lifetime_stats", {})
    for key in tin_inventory.keys():
        var recipe_id := str(key)
        if not recipe_defs_by_id.has(recipe_id):
            continue
        var inv_count := int(tin_inventory[key])
        var stats: Dictionary = all_stats.get(recipe_id, {})
        if typeof(stats) != TYPE_DICTIONARY:
            stats = {}
        var produced := int(stats.get("produced", 0))
        if inv_count > produced:
            stats["produced"] = inv_count
        all_stats[recipe_id] = stats
    meta_state["recipe_lifetime_stats"] = all_stats

func _reset_recipe_tracking_from_inventory() -> void:
    var discovered: Array = []
    var all_stats: Dictionary = {}
    for key in tin_inventory.keys():
        var recipe_id := str(key)
        if not recipe_defs_by_id.has(recipe_id):
            continue
        if not discovered.has(recipe_id):
            discovered.append(recipe_id)
        var produced := int(tin_inventory[key])
        all_stats[recipe_id] = {
            "produced": produced,
            "revenue_generated": 0
        }
    meta_state["discovered_recipe_ids"] = discovered
    meta_state["recipe_lifetime_stats"] = all_stats

func get_skill_defs() -> Array:
    return skill_defs

func get_skill_defs_by_branch(branch: String) -> Array:
    var out: Array = []
    for def in skill_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        if str(def.get("branch", "")) != branch:
            continue
        out.append(def)
    return out

func get_skill_def(id: String) -> Dictionary:
    return skill_defs_by_id.get(id, {})

func get_reputation() -> int:
    return int(meta_state.get("reputation", 0))

func is_skill_owned(id: String) -> bool:
    var owned: Array = meta_state.get("skills_owned", [])
    return owned.has(id)

func get_skill_cost(id: String) -> int:
    var def: Dictionary = get_skill_def(id)
    if def.is_empty():
        return 0
    return int(def.get("cost", 0))

func get_skill_prereqs(id: String) -> Array:
    var def: Dictionary = get_skill_def(id)
    if def.is_empty():
        return []
    return def.get("requires", [])

func get_skill_lock_reason(id: String) -> String:
    var def: Dictionary = get_skill_def(id)
    if def.is_empty():
        return "Unavailable"
    if is_skill_owned(id):
        return "Owned"
    if not _meets_skill_prereqs(def):
        return "Locked"
    var cost := get_skill_cost(id)
    if get_reputation() < cost:
        return "Need %d rep" % cost
    return ""

func can_purchase_skill(id: String) -> bool:
    var def: Dictionary = get_skill_def(id)
    if def.is_empty():
        return false
    if is_skill_owned(id):
        return false
    if not _meets_skill_prereqs(def):
        return false
    return get_reputation() >= get_skill_cost(id)

func _meets_skill_prereqs(def: Dictionary) -> bool:
    var reqs: Array = def.get("requires", [])
    for req in reqs:
        if not is_skill_owned(str(req)):
            return false
    return true

func purchase_skill(id: String) -> bool:
    if not can_purchase_skill(id):
        return false
    var def: Dictionary = get_skill_def(id)
    var cost := get_skill_cost(id)
    meta_state["reputation"] = get_reputation() - cost
    var owned: Array = meta_state.get("skills_owned", [])
    owned.append(id)
    meta_state["skills_owned"] = owned
    skills_changed.emit()
    reputation_changed.emit()
    changed.emit()
    return true

func get_upgrade_defs() -> Array:
    return upgrade_defs

func get_visible_upgrade_defs_by_category(show_purchased: bool = false) -> Dictionary:
    _ensure_visible_upgrades()
    var result: Dictionary = {}
    for category in upgrade_order_by_category.keys():
        if str(category) == "policy":
            var policy_ids: Array = visible_upgrades_by_category.get("policy", [])
            result[category] = _defs_from_ids(policy_ids)
            continue
        result[category] = _get_non_policy_defs_for_ui(str(category), show_purchased)
    return result

func _ensure_visible_upgrades() -> void:
    for category in upgrade_order_by_category.keys():
        _ensure_visible_upgrades_for_category(str(category))

func _ensure_visible_upgrades_for_category(category: String) -> void:
    if category == "policy":
        _ensure_visible_policy_upgrades()
        return
    var visible: Array = visible_upgrades_by_category.get(category, [])
    var order: Array = upgrade_order_by_category.get(category, [])
    var filtered: Array = []
    for id in visible:
        var id_str := str(id)
        var def = upgrade_defs_by_id.get(id_str, null)
        if def == null:
            continue
        if is_upgrade_maxed(id_str) and not bool(def.get("exclusive_choice", false)):
            continue
        filtered.append(id_str)
    visible = filtered
    var added := true
    while _count_visible_slots(visible) < UPGRADES_VISIBLE_PER_CATEGORY and added:
        added = false
        for id in order:
            var id_str := str(id)
            if visible.has(id_str):
                continue
            var def = upgrade_defs_by_id.get(id_str, null)
            if def == null:
                continue
            if is_upgrade_maxed(id_str) and not bool(def.get("exclusive_choice", false)):
                continue
            if not can_show_upgrade(def):
                continue
            var group_id := _get_exclusive_group_id(def)
            if group_id != "":
                var slot_count := _count_visible_slots(visible)
                if slot_count >= UPGRADES_VISIBLE_PER_CATEGORY:
                    continue
                var group_ids: Array = upgrade_pairs.get(group_id, [])
                for gid in group_ids:
                    var gid_str := str(gid)
                    if visible.has(gid_str):
                        continue
                    visible.append(gid_str)
                added = true
                break
            visible.append(id_str)
            added = true
            break
    visible_upgrades_by_category[category] = visible

func _ensure_visible_policy_upgrades() -> void:
    var visible: Array = []
    var highest_stage := 0
    for def in upgrade_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        if str(def.get("category", "")) != "policy":
            continue
        var upgrade_id := str(def.get("upgrade_id", ""))
        if upgrade_id == "":
            continue
        if get_upgrade_level(upgrade_id) > 0:
            if not visible.has(upgrade_id):
                visible.append(upgrade_id)
            var stage := _get_policy_stage(def)
            if stage > highest_stage:
                highest_stage = stage
    for group_id in policy_stage_chosen.keys():
        highest_stage = max(highest_stage, int(policy_stage_chosen.get(group_id, 0)))

    var next_stage := highest_stage + 1
    if next_stage > 0:
        for def in upgrade_defs:
            if typeof(def) != TYPE_DICTIONARY:
                continue
            if str(def.get("category", "")) != "policy":
                continue
            if _get_policy_stage(def) != next_stage:
                continue
            var upgrade_id := str(def.get("upgrade_id", ""))
            if upgrade_id == "":
                continue
            if not visible.has(upgrade_id):
                visible.append(upgrade_id)

    visible_upgrades_by_category["policy"] = visible

func _count_visible_slots(visible: Array) -> int:
    var slots := 0
    var seen_pairs: Dictionary = {}
    for id in visible:
        var def = upgrade_defs_by_id.get(str(id), null)
        if def == null:
            continue
        var group_id := _get_exclusive_group_id(def)
        if group_id != "":
            if not seen_pairs.has(group_id):
                seen_pairs[group_id] = true
                slots += 1
        else:
            slots += 1
    return slots

func _defs_from_ids(ids: Array) -> Array:
    var defs: Array = []
    for id in ids:
        var def = upgrade_defs_by_id.get(str(id), null)
        if def == null:
            continue
        defs.append(def)
    return defs

func _get_non_policy_defs_for_ui(category: String, show_purchased: bool) -> Array:
    var order: Array = upgrade_order_by_category.get(category, [])
    var purchased: Array = []
    var available: Array = []
    var locked: Array = []
    var locked_counts: Array = []
    for id in order:
        var id_str := str(id)
        var def = upgrade_defs_by_id.get(id_str, null)
        if def == null:
            continue
        var level := get_upgrade_level(id_str)
        if is_upgrade_maxed(id_str):
            continue
        if level > 0:
            purchased.append(def)
        if show_purchased:
            if _meets_requirements(def):
                available.append(def)
            continue
        if _meets_requirements(def):
            available.append(def)
        else:
            locked.append(def)
            locked_counts.append(_count_unmet_requirements(def))
    if show_purchased:
        var merged: Array = []
        var seen: Dictionary = {}
        for def in purchased:
            var upgrade_id := str(def.get("upgrade_id", ""))
            if upgrade_id == "" or seen.has(upgrade_id):
                continue
            merged.append(def)
            seen[upgrade_id] = true
        for def in available:
            var upgrade_id := str(def.get("upgrade_id", ""))
            if upgrade_id == "" or seen.has(upgrade_id):
                continue
            merged.append(def)
            seen[upgrade_id] = true
        return merged
    if not available.is_empty():
        return available
    if locked.is_empty():
        return []
    var indices := []
    for i in range(locked.size()):
        indices.append(i)
    indices.sort_custom(func(a, b):
        var ca := int(locked_counts[a])
        var cb := int(locked_counts[b])
        if ca == cb:
            return a < b
        return ca < cb
    )
    var out: Array = []
    for i in indices:
        out.append(locked[i])
        if out.size() >= 2:
            break
    return out

func _count_unmet_requirements(def: Dictionary) -> int:
    var reqs: Array = RequiresEval.get_requires(def)
    if reqs.is_empty():
        return 0
    var current_id := str(def.get("upgrade_id", ""))
    var count := 0
    for req in reqs:
        if not RequiresEval.is_met([req], self, {"current_upgrade_id": current_id}):
            count += 1
    return count

func get_upgrade_level(id: String) -> int:
    if id == "unlock_cannery":
        return 1 if is_cannery_unlocked else 0
    return int(upgrade_levels.get(id, 0))

func get_upgrade_cost(id: String) -> int:
    var def = upgrade_defs_by_id.get(id, null)
    if def == null:
        return 0
    var base_cost := int(def.get("base_cost", 0))
    var cost_model: Dictionary = def.get("cost_model", {})
    var cost_mult := float(cost_model.get("mult", 1.0))
    var level := get_upgrade_level(id)
    return int(round(base_cost * pow(cost_mult, level)))

func is_upgrade_maxed(id: String) -> bool:
    if id == "unlock_cannery":
        return is_cannery_unlocked
    var def = upgrade_defs_by_id.get(id, null)
    if def == null:
        return true
    var max_level := int(def.get("max_level", 1))
    if max_level < 0:
        return false
    return get_upgrade_level(id) >= max_level

func can_purchase_upgrade(id: String) -> bool:
    if is_upgrade_maxed(id):
        return false
    if id == "unlock_cannery":
        return can_purchase_cannery()
    var def = upgrade_defs_by_id.get(id, null)
    if def == null:
        return false
    if _is_exclusive_group_locked(def):
        return false
    if not _meets_requirements(def):
        return false
    return money >= get_upgrade_cost(id)

func purchase_upgrade(id: String) -> bool:
    if id == "unlock_cannery":
        return purchase_unlocked_cannery()
    if not can_purchase_upgrade(id):
        return false
    var cost := get_upgrade_cost(id)
    money -= cost
    upgrade_levels[id] = get_upgrade_level(id) + 1
    var def = upgrade_defs_by_id.get(id, null)
    if def != null:
        _record_policy_purchase(def)
    changed.emit()
    return true

func can_show_upgrade(def: Dictionary) -> bool:
    if def.get("upgrade_id", "") == "unlock_cannery":
        return cannery_upgrade_is_visible()
    if _is_exclusive_group_def(def):
        return _meets_requirements(def, true)
    return _meets_requirements(def)

func _meets_requirements(def: Dictionary, ignore_exclusive_lock: bool = false) -> bool:
    var reqs: Array = RequiresEval.get_requires(def)
    var ctx := {
        "current_upgrade_id": str(def.get("upgrade_id", ""))
    }
    if ignore_exclusive_lock:
        ctx["ignore_types"] = ["exclusive_group_unchosen"]
    return RequiresEval.is_met(reqs, self, ctx)

func _is_requirement_flag_true(flag: String) -> bool:
    match flag:
        "cannery_unlocked":
            return is_cannery_unlocked
        "crew_unlocked":
            return is_crew_unlocked
    return false

func is_flag_true(flag: String) -> bool:
    return _is_requirement_flag_true(flag)

func _is_exclusive_group_unchosen(group_id: String, current_id: String) -> bool:
    if group_id == "":
        return true
    if chosen_exclusive_groups.has(group_id):
        return false
    var ids: Array = upgrade_pairs.get(group_id, [])
    for other_id in ids:
        var other_id_str := str(other_id)
        if other_id_str == current_id:
            continue
        if get_upgrade_level(other_id_str) > 0:
            return false
    return true

func _is_policy_stage_at_least(group_id: String, stage: int) -> bool:
    if group_id == "":
        return true
    return int(policy_stage_chosen.get(group_id, 0)) >= stage

func _is_exclusive_group_locked(def: Dictionary) -> bool:
    var group_id := _get_exclusive_group_id(def)
    if group_id == "":
        return false
    var current_id := str(def.get("upgrade_id", ""))
    if chosen_exclusive_groups.has(group_id):
        return str(chosen_exclusive_groups.get(group_id, "")) != current_id
    var ids: Array = upgrade_pairs.get(group_id, [])
    for other_id in ids:
        if str(other_id) == current_id:
            continue
        if get_upgrade_level(str(other_id)) > 0:
            return true
    return false

func _record_policy_purchase(def: Dictionary) -> void:
    var group_id := _get_exclusive_group_id(def)
    if group_id == "":
        return
    if bool(def.get("exclusive_choice", false)):
        chosen_exclusive_groups[group_id] = str(def.get("upgrade_id", ""))
    var stage := _get_policy_stage(def)
    if stage > 0:
        var existing := int(policy_stage_chosen.get(group_id, 0))
        if stage > existing:
            policy_stage_chosen[group_id] = stage

func _get_policy_stage(def: Dictionary) -> int:
    if def.has("policy_stage"):
        return int(def.get("policy_stage", 0))
    var ui: Dictionary = def.get("ui", {})
    if typeof(ui) == TYPE_DICTIONARY and ui.has("policy_stage"):
        return int(ui.get("policy_stage", 0))
    return 0

func _is_exclusive_group_def(def: Dictionary) -> bool:
    return _get_exclusive_group_id(def) != "" and bool(def.get("exclusive_choice", false))

func _get_policy_requirement_reason(def: Dictionary) -> String:
    if str(def.get("category", "")) != "policy" and _get_policy_stage(def) <= 0:
        return ""
    var reqs: Array = RequiresEval.get_requires(def)
    for req in reqs:
        if typeof(req) != TYPE_DICTIONARY:
            continue
        var req_type := str(req.get("type", ""))
        match req_type:
            "flag_true":
                if str(req.get("flag", "")) == "cannery_unlocked" and not RequiresEval.is_met([req], self):
                    return "Locked (need cannery)"
            "policy_stage_at_least":
                var ctx := {"current_upgrade_id": str(def.get("upgrade_id", ""))}
                if not RequiresEval.is_met([req], self, ctx):
                    return "Locked (complete previous policy stage)"
    return ""

func _get_exclusive_group_id(def: Dictionary) -> String:
    var group_val = def.get("exclusive_group_id", "")
    if group_val == null:
        return ""
    return str(group_val)

func get_upgrade_lock_reason(id: String) -> String:
    if is_upgrade_maxed(id):
        return "Maxed"
    if id == "unlock_cannery":
        if can_purchase_cannery():
            return ""
        return "Locked"
    var def = upgrade_defs_by_id.get(id, null)
    if def == null:
        return "Unavailable"
    if _is_exclusive_group_locked(def):
        var group_id := _get_exclusive_group_id(def)
        var chosen_id := str(chosen_exclusive_groups.get(group_id, ""))
        if chosen_id == "":
            var ids: Array = upgrade_pairs.get(group_id, [])
            for other_id in ids:
                var other_id_str := str(other_id)
                if other_id_str == id:
                    continue
                if get_upgrade_level(other_id_str) > 0:
                    chosen_id = other_id_str
                    break
        var chosen_def: Dictionary = upgrade_defs_by_id.get(chosen_id, {})
        var chosen_name := str(chosen_def.get("display_name", chosen_id))
        if chosen_name == "":
            chosen_name = chosen_id
        return "Policy already chosen: %s" % chosen_name
    if not _meets_requirements(def):
        var policy_reason := _get_policy_requirement_reason(def)
        if policy_reason != "":
            return policy_reason
        return "Locked"
    var cost := get_upgrade_cost(id)
    if money < cost:
        return "Need $%d" % cost
    return ""

func _get_effect_total(effect_type: String) -> int:
    var total := 0
    for def in upgrade_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        var id := str(def.get("upgrade_id", ""))
        var level := get_upgrade_level(id)
        if level <= 0:
            continue
        var effects: Array = def.get("effects", [])
        for effect in effects:
            if typeof(effect) != TYPE_DICTIONARY:
                continue
            if effect.get("type", "") == effect_type:
                total += int(effect.get("value", 0)) * level
    return total

func _get_effect_total_float(effect_type: String) -> float:
    var total := 0.0
    for def in upgrade_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        var id := str(def.get("upgrade_id", ""))
        var level := get_upgrade_level(id)
        if level <= 0:
            continue
        var effects: Array = def.get("effects", [])
        for effect in effects:
            if typeof(effect) != TYPE_DICTIONARY:
                continue
            if effect.get("type", "") == effect_type:
                total += float(effect.get("value", 0.0)) * level
    return total

func get_fish_sell_price() -> int:
    return 20 + _get_effect_total("fish_sell_add") + _get_meta_bonus_int("fish_sell_add") + _get_skill_effect_total_int("fish_sell_add")

func get_tin_sell_price() -> int:
    return 10 + _get_effect_total("tin_sell_add") + _get_meta_bonus_int("tin_sell_add") + _get_skill_effect_total_int("tin_sell_add")

func get_fish_sell_count() -> int:
    return 1 + _get_effect_total("fish_sell_count_add") + _get_skill_effect_total_int("fish_sell_count_add")

func get_green_zone_ratio() -> float:
    return min(1.0, GREEN_ZONE_BASE_RATIO + _get_effect_total_float("green_zone_add_pct") + _get_meta_bonus_float("green_zone_add_pct") + _get_skill_effect_total_float("green_zone_add_pct"))

func get_tin_make_time() -> float:
    var time := TIN_MAKE_BASE_TIME + _get_effect_total_float("tin_time_add") + _get_meta_bonus_float("tin_time_add") + _get_skill_effect_total_float("tin_time_add")
    return max(0.5, time)

func get_auto_tin_enabled() -> bool:
    return _get_effect_total("auto_tin") > 0

func can_make_tin() -> bool:
    return tin_cooldown_remaining <= 0.0

func start_tin_cooldown() -> void:
    tin_cooldown_remaining = get_tin_make_time()

func set_tin_selection(method_id: String, ingredient_id: String) -> void:
    tin_method_id = method_id
    tin_ingredient_id = ingredient_id

func _can_auto_tin() -> bool:
    if not can_make_tin():
        return false
    if fish_count <= 0:
        return false
    if tin_ingredient_id != "none" and garlic_count <= 0:
        return false
    return true

################
# Inventory/Recipes
################
func get_inventory_items() -> Array:
    var items: Array = []
    items.append({"name": "Fish", "count": fish_count})
    items.append({"name": "Garlic", "count": garlic_count})
    for key in tin_inventory.keys():
        var label := "Tin: %s" % _format_recipe_from_key(str(key))
        items.append({"name": label, "count": int(tin_inventory[key])})
    return items

func get_recipe_list() -> Array:
    var out: Array = []
    for recipe_id in recipes_unlocked:
        var id_str := str(recipe_id)
        var recipe_def: Dictionary = recipe_defs_by_id.get(id_str, {})
        if recipe_def.is_empty():
            out.append(id_str)
            continue
        out.append(str(recipe_def.get("display_name", id_str)))
    return out

func _unlock_recipe(recipe_id: String, method_id: String, ingredient_id: String) -> void:
    if recipe_id != "":
        if not recipes_unlocked.has(recipe_id):
            recipes_unlocked.append(recipe_id)
        return
    var label := _format_recipe(method_id, ingredient_id)
    if not recipes_unlocked.has(label):
        recipes_unlocked.append(label)

func _make_tin_key(method_id: String, ingredient_id: String) -> String:
    return "%s|%s" % [method_id, ingredient_id]

func _format_recipe_from_key(key: String) -> String:
    if recipe_defs_by_id.has(key):
        var recipe_def: Dictionary = recipe_defs_by_id.get(key, {})
        return str(recipe_def.get("display_name", key))
    var parts := key.split("|")
    if parts.size() < 2:
        return _title(key)
    return _format_recipe(parts[0], parts[1])

func _format_recipe(method_id: String, ingredient_id: String) -> String:
    var method_name := _title(method_id)
    var ingredient_name := "Plain" if ingredient_id == "none" else _title(ingredient_id)
    return "%s + %s" % [method_name, ingredient_name]

func format_recipe(method_id: String, ingredient_id: String) -> String:
    return _format_recipe(method_id, ingredient_id)

func _title(text: String) -> String:
    var parts := text.replace("_", " ").split(" ")
    for i in range(parts.size()):
        var p: String = parts[i]
        if p.length() > 0:
            parts[i] = p.substr(0, 1).to_upper() + p.substr(1)
    return " ".join(parts)

##############
# Crew Trips
##############
func can_start_crew_trip() -> bool:
    return not crew_trip_active and is_crew_unlocked

func start_crew_trip() -> bool:
    if not can_start_crew_trip():
        return false
    crew_trip_active = true
    crew_trip_remaining = get_crew_trip_duration()
    crew_trip_updated.emit()
    changed.emit()
    return true

func _complete_crew_trip() -> void:
    crew_trip_active = false
    crew_trip_remaining = 0.0
    var catch_amount := get_crew_trip_catch()
    catch_fish(catch_amount)
    crew_trip_updated.emit()

func get_crew_trip_duration() -> float:
    var mult := 1.0 + _get_effect_total_float("crew_trip_duration_mult")
    return max(2.0, CREW_TRIP_BASE_DURATION * mult)

func get_crew_trip_catch() -> int:
    return CREW_TRIP_BASE_CATCH + _get_effect_total("crew_trip_catch_add")

func _should_auto_send_crew() -> bool:
    if crew_trip_paused:
        return false
    if not is_crew_unlocked:
        return false
    if crew_trip_active:
        return false
    return _get_effect_total("crew_auto_send") > 0

func get_crew_trip_progress() -> float:
    if not crew_trip_active:
        return 0.0
    var duration := get_crew_trip_duration()
    if duration <= 0.0:
        return 1.0
    return 1.0 - (crew_trip_remaining / duration)

func set_crew_trip_paused(paused: bool) -> void:
    crew_trip_paused = paused

################
# Prestige/Meta
################
func can_prestige() -> bool:
    return tins_sold >= PRESTIGE_TINS_REQUIRED

func get_prestige_progress() -> int:
    return tins_sold

func get_prestige_reputation_gain() -> int:
    return _calculate_reputation_gain()

func prestige() -> bool:
    if not can_prestige():
        return false
    var rep_gain := _calculate_reputation_gain()
    _apply_reputation_gain(rep_gain)
    meta_state["reputation"] = int(meta_state.get("reputation", 0)) + rep_gain
    meta_state["prestige_count"] = int(meta_state.get("prestige_count", 0)) + 1
    print("Prestige complete. Rep gained:", rep_gain, "Total rep:", meta_state["reputation"])
    print("Prestige weights. Avg health:", get_ocean_health_average_ratio(), "Fish sold:", fish_sold, "Tins sold:", tins_sold)
    _reset_run_state()
    save_game()
    reputation_changed.emit()
    skills_changed.emit()
    changed.emit()
    return true

func _calculate_reputation_gain() -> int:
    # Simple measurable formula for tuning: 1 reputation per $100 earned.
    var base_gain := float(lifetime_money_earned) / float(REPUTATION_MONEY_DIVISOR)
    var mult := 1.0 + _get_skill_effect_total_float("reputation_gain_mult")
    return int(floor(base_gain * mult))

func _apply_reputation_gain(rep_gain: int) -> void:
    if rep_gain <= 0:
        return
    var total_sales: int = fish_sold + tins_sold
    if total_sales <= 0:
        meta_state["sustainable_bonus_level"] = int(meta_state.get("sustainable_bonus_level", 0)) + rep_gain
        return
    var avg_health_ratio: float = get_ocean_health_average_ratio()
    var fish_share: float = float(fish_sold) / float(total_sales)
    var tin_share: float = float(tins_sold) / float(total_sales)
    # Combined weighting for tuning:
    # sustainable_score = 0.5 * avg_health_ratio + 0.5 * fish_share
    # industrial_score = 0.5 * (1 - avg_health_ratio) + 0.5 * tin_share
    var sustainable_score: float = (avg_health_ratio * 0.5) + (fish_share * 0.5)
    var industrial_score: float = ((1.0 - avg_health_ratio) * 0.5) + (tin_share * 0.5)
    var total_score: float = sustainable_score + industrial_score
    if total_score <= 0.0:
        sustainable_score = 0.5
        industrial_score = 0.5
        total_score = 1.0
    var sustainable_gain: int = int(floor(rep_gain * (sustainable_score / total_score)))
    var industrial_gain: int = rep_gain - sustainable_gain
    meta_state["sustainable_bonus_level"] = int(meta_state.get("sustainable_bonus_level", 0)) + sustainable_gain
    meta_state["industrial_bonus_level"] = int(meta_state.get("industrial_bonus_level", 0)) + industrial_gain

func _reset_run_state() -> void:
    fish_count = 0
    tin_count = 0
    money = 0
    garlic_count = 0
    fish_stock_by_id.clear()
    tin_inventory.clear()
    recipes_unlocked.clear()
    lifetime_money_earned = 0
    tins_sold = 0
    fish_sold = 0
    sell_mode = SellMode.FISH
    is_cannery_discovered = false
    is_cannery_unlocked = false
    is_crew_discovered = false
    is_crew_unlocked = false
    upgrade_levels.clear()
    crew_trip_active = false
    crew_trip_remaining = 0.0
    crew_trip_paused = false
    ocean_health = OCEAN_HEALTH_MAX
    ocean_health_time_accum = 0.0
    ocean_health_time_total = 0.0

func _get_meta_bonus_int(effect_type: String) -> int:
    var sustainable_level := int(meta_state.get("sustainable_bonus_level", 0))
    var industrial_level := int(meta_state.get("industrial_bonus_level", 0))
    match effect_type:
        "fish_sell_add":
            return sustainable_level * SUSTAINABLE_FISH_SELL_ADD_PER_LEVEL
        "tin_sell_add":
            return industrial_level * INDUSTRIAL_TIN_SELL_ADD_PER_LEVEL
    return 0

func _get_meta_bonus_float(effect_type: String) -> float:
    var sustainable_level := int(meta_state.get("sustainable_bonus_level", 0))
    var industrial_level := int(meta_state.get("industrial_bonus_level", 0))
    match effect_type:
        "green_zone_add_pct":
            return sustainable_level * SUSTAINABLE_GREEN_ZONE_ADD_PCT_PER_LEVEL
        "tin_time_add":
            return industrial_level * INDUSTRIAL_TIN_TIME_ADD_PER_LEVEL
    return 0.0

func _get_skill_effect_total_int(effect_type: String) -> int:
    var total: int = 0
    var owned: Array = meta_state.get("skills_owned", [])
    for id in owned:
        var def: Dictionary = skill_defs_by_id.get(str(id), {})
        if def.is_empty():
            continue
        var effects: Array = def.get("effects", [])
        for effect in effects:
            if typeof(effect) != TYPE_DICTIONARY:
                continue
            if effect.get("type", "") == effect_type:
                total += int(effect.get("value", 0))
    return total

func _get_skill_effect_total_float(effect_type: String) -> float:
    var total: float = 0.0
    var owned: Array = meta_state.get("skills_owned", [])
    for id in owned:
        var def: Dictionary = skill_defs_by_id.get(str(id), {})
        if def.is_empty():
            continue
        var effects: Array = def.get("effects", [])
        for effect in effects:
            if typeof(effect) != TYPE_DICTIONARY:
                continue
            if effect.get("type", "") == effect_type:
                total += float(effect.get("value", 0.0))
    return total

################
# Ocean Health
################
func _apply_ocean_health_pressure(fish_caught: int) -> void:
    if fish_caught <= 0:
        return
    var pressure_mult: float = max(0.1, 1.0 + _get_skill_effect_total_float("ocean_pressure_mult"))
    ocean_health = clamp(ocean_health - (float(fish_caught) * OCEAN_HEALTH_FISH_COST * pressure_mult), OCEAN_HEALTH_MIN, OCEAN_HEALTH_MAX)

func _regenerate_ocean_health(delta: float) -> void:
    if ocean_health >= OCEAN_HEALTH_MAX:
        return
    var regen_mult: float = max(0.1, 1.0 + _get_skill_effect_total_float("ocean_regen_mult"))
    ocean_health = clamp(ocean_health + (OCEAN_HEALTH_REGEN_PER_SEC * regen_mult * delta), OCEAN_HEALTH_MIN, OCEAN_HEALTH_MAX)
    ocean_health_changed.emit()

func get_ocean_health_ratio() -> float:
    if OCEAN_HEALTH_MAX <= 0.0:
        return 0.0
    return clamp(ocean_health / OCEAN_HEALTH_MAX, 0.0, 1.0)

func _track_ocean_health(delta: float) -> void:
    if delta <= 0.0:
        return
    ocean_health_time_accum += ocean_health * delta
    ocean_health_time_total += delta

func get_ocean_health_average_ratio() -> float:
    if ocean_health_time_total <= 0.0:
        return get_ocean_health_ratio()
    var avg := ocean_health_time_accum / ocean_health_time_total
    if OCEAN_HEALTH_MAX <= 0.0:
        return 0.0
    return clamp(avg / OCEAN_HEALTH_MAX, 0.0, 1.0)

func _track_run_time(delta: float) -> void:
    if delta <= 0.0:
        return
    run_time_seconds += delta

func set_run_paused(paused: bool) -> void:
    run_paused = paused

func get_run_time_seconds() -> float:
    return run_time_seconds

################
# Endings
################
func _check_endings() -> void:
    if ending_state != EndingState.NONE:
        return
    if int(meta_state.get("prestige_count", 0)) <= 0:
        return
    if _check_industrial_collapse():
        _set_ending_state(EndingState.INDUSTRIAL_COLLAPSE)
        return
    if _check_sustainable_equilibrium():
        _set_ending_state(EndingState.SUSTAINABLE_EQUILIBRIUM)
        return
    if _check_dual_mastery():
        _set_ending_state(EndingState.DUAL_MASTERY)

func _check_industrial_collapse() -> bool:
    if run_time_seconds < INDUSTRIAL_MIN_SECONDS:
        return false
    if lifetime_money_earned < INDUSTRIAL_MIN_LIFETIME_MONEY:
        return false
    return ocean_health <= OCEAN_HEALTH_COLLAPSE_THRESHOLD

func _check_sustainable_equilibrium() -> bool:
    if run_time_seconds < SUSTAINABLE_MIN_SECONDS:
        return false
    if _get_total_upgrade_levels() < SUSTAINABLE_MIN_TOTAL_UPGRADES:
        return false
    return get_ocean_health_average_ratio() >= SUSTAINABLE_HEALTH_AVG_THRESHOLD

func _check_dual_mastery() -> bool:
    if run_time_seconds < DUAL_MIN_SECONDS:
        return false
    return lifetime_money_earned >= DUAL_MIN_LIFETIME_MONEY

func _get_total_upgrade_levels() -> int:
    var total: int = 0
    for id in upgrade_levels.keys():
        total += int(upgrade_levels[id])
    return total

func _set_ending_state(state: EndingState) -> void:
    ending_state = state
    run_paused = true
    var summary := _build_run_summary()
    ending_reached.emit(int(state), summary)

func _build_run_summary() -> Dictionary:
    return {
        "time_seconds": run_time_seconds,
        "fish_sold": fish_sold,
        "tins_sold": tins_sold,
        "lifetime_money_earned": lifetime_money_earned,
        "avg_ocean_health_ratio": get_ocean_health_average_ratio(),
        "final_ocean_health_ratio": get_ocean_health_ratio(),
        "prestige_count": int(meta_state.get("prestige_count", 0))
    }

func get_run_summary() -> Dictionary:
    return _build_run_summary()

func get_ending_state() -> EndingState:
    return ending_state
