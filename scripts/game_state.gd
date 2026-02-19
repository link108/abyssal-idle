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

const UPGRADE_DATA_PATH := "res://data/upgrades.json"
const SKILL_TREE_DATA_PATH := "res://data/skill_tree.json"
const SAVE_PATH := "user://save.json"
const GREEN_ZONE_BASE_RATIO := 0.10
const TIN_MAKE_BASE_TIME := 3.0
const SAVE_VERSION := 7
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

# Economy
var fish_count: int = 0
var tin_count: int = 0
var money: int = 0
var garlic_count: int = 0
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
    "skills_owned": []
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
var skill_defs: Array = []
var skill_defs_by_id: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    _load_upgrades()
    _load_skill_tree()
    _rng.randomize()

func save_game() -> void:
    var data := {
        "version": SAVE_VERSION,
        "fish_count": fish_count,
        "tin_count": tin_count,
        "money": money,
        "garlic_count": garlic_count,
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
        "visible_upgrades_by_category": visible_upgrades_by_category
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
    crew_trip_active = false
    crew_trip_remaining = 0.0
    crew_trip_paused = false
    meta_state = {
        "reputation": 0,
        "prestige_count": 0,
        "sustainable_bonus_level": 0,
        "industrial_bonus_level": 0,
        "skills_owned": []
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
    if typeof(visible_upgrades_by_category) != TYPE_DICTIONARY:
        visible_upgrades_by_category = {}
    run_paused = ending_state != EndingState.NONE
    _normalize_meta_state()
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
    _apply_ocean_health_pressure(catch_total)
    changed.emit()

func make_tin() -> bool:
    if fish_count <= 0:
        return false
    fish_count -= 1
    tin_count += 1
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
    var key: String = _make_tin_key(_method_id, _ingredient_id)
    tin_inventory[key] = int(tin_inventory.get(key, 0)) + 1
    _unlock_recipe(_method_id, _ingredient_id)
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

func _remove_random_tin() -> void:
    if tin_inventory.is_empty():
        return
    var keys: Array = tin_inventory.keys()
    if keys.is_empty():
        return
    var idx: int = _rng.randi_range(0, keys.size() - 1)
    var key: String = str(keys[idx])
    var count: int = int(tin_inventory.get(key, 0))
    if count <= 1:
        tin_inventory.erase(key)
    else:
        tin_inventory[key] = count - 1

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
                _add_money(get_fish_sell_price() * count)
        SellMode.TINS:
            if tin_count > 0:
                tin_count -= 1
                _remove_random_tin()
                # Sanity: tins_sold should only advance when a tin is sold.
                tins_sold += 1
                _add_money(get_tin_sell_price())
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
        if not def.has("id"):
            continue
        upgrade_defs_by_id[def.id] = def
        var pair_id := str(def.get("pair_id", ""))
        if pair_id != "":
            if not upgrade_pairs.has(pair_id):
                upgrade_pairs[pair_id] = []
            upgrade_pairs[pair_id].append(str(def.id))
        var category := str(def.get("category", "misc"))
        if not upgrade_order_by_category.has(category):
            upgrade_order_by_category[category] = []
        upgrade_order_by_category[category].append(str(def.id))

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

func get_visible_upgrade_defs_by_category() -> Dictionary:
    _ensure_visible_upgrades()
    var result: Dictionary = {}
    for category in upgrade_order_by_category.keys():
        var ids: Array = visible_upgrades_by_category.get(category, [])
        var defs: Array = []
        for id in ids:
            var def = upgrade_defs_by_id.get(str(id), null)
            if def == null:
                continue
            if is_upgrade_maxed(str(id)) and not def.has("pair_id"):
                continue
            defs.append(def)
        result[category] = defs
    return result

func _ensure_visible_upgrades() -> void:
    for category in upgrade_order_by_category.keys():
        _ensure_visible_upgrades_for_category(str(category))

func _ensure_visible_upgrades_for_category(category: String) -> void:
    var visible: Array = visible_upgrades_by_category.get(category, [])
    var order: Array = upgrade_order_by_category.get(category, [])
    var filtered: Array = []
    for id in visible:
        var id_str := str(id)
        var def = upgrade_defs_by_id.get(id_str, null)
        if def == null:
            continue
        if is_upgrade_maxed(id_str) and not def.has("pair_id"):
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
            if is_upgrade_maxed(id_str) and not def.has("pair_id"):
                continue
            if not can_show_upgrade(def):
                continue
            var pair_id := str(def.get("pair_id", ""))
            if pair_id != "":
                var slot_count := _count_visible_slots(visible)
                if slot_count >= UPGRADES_VISIBLE_PER_CATEGORY:
                    continue
                var pair_ids: Array = upgrade_pairs.get(pair_id, [])
                for pid in pair_ids:
                    var pid_str := str(pid)
                    if visible.has(pid_str):
                        continue
                    visible.append(pid_str)
                added = true
                break
            visible.append(id_str)
            added = true
            break
    visible_upgrades_by_category[category] = visible

func _count_visible_slots(visible: Array) -> int:
    var slots := 0
    var seen_pairs: Dictionary = {}
    for id in visible:
        var def = upgrade_defs_by_id.get(str(id), null)
        if def == null:
            continue
        var pair_id := str(def.get("pair_id", ""))
        if pair_id != "":
            if not seen_pairs.has(pair_id):
                seen_pairs[pair_id] = true
                slots += 1
        else:
            slots += 1
    return slots

func get_upgrade_level(id: String) -> int:
    if id == "unlock_cannery":
        return 1 if is_cannery_unlocked else 0
    return int(upgrade_levels.get(id, 0))

func get_upgrade_cost(id: String) -> int:
    var def = upgrade_defs_by_id.get(id, null)
    if def == null:
        return 0
    var base_cost := int(def.get("base_cost", 0))
    var cost_mult := float(def.get("cost_mult", 1.0))
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
    if _is_upgrade_pair_locked(def):
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
    changed.emit()
    return true

func can_show_upgrade(def: Dictionary) -> bool:
    if def.get("id", "") == "unlock_cannery":
        return cannery_upgrade_is_visible()
    if def.has("pair_id"):
        var stage := int(def.get("pair_stage", 0))
        if stage > 0 and not _is_pair_stage_unlocked(stage):
            return false
        return _meets_requirements(def)
    return _meets_requirements(def)

func _meets_requirements(def: Dictionary) -> bool:
    var reqs: Dictionary = def.get("requires", {})
    if reqs.is_empty():
        if def.get("chain_prev", false) and not def.has("pair_id"):
            return _has_prev_upgrade(def)
        return true
    if reqs.get("cannery", false) and not is_cannery_unlocked:
        return false
    if reqs.get("crew", false) and not is_crew_unlocked:
        return false
    var upgrade_reqs: Dictionary = reqs.get("upgrades", {})
    for req_id in upgrade_reqs.keys():
        var needed := int(upgrade_reqs[req_id])
        if get_upgrade_level(str(req_id)) < needed:
            return false
    if def.get("chain_prev", false) and not def.has("pair_id") and not _has_prev_upgrade(def):
        return false
    return true

func _has_prev_upgrade(def: Dictionary) -> bool:
    if def.has("pair_id"):
        return true
    var category := str(def.get("category", "misc"))
    var order: Array = upgrade_order_by_category.get(category, [])
    var id_str := str(def.get("id", ""))
    var idx := order.find(id_str)
    if idx <= 0:
        return true
    var prev_id := str(order[idx - 1])
    return get_upgrade_level(prev_id) > 0

func _is_upgrade_pair_locked(def: Dictionary) -> bool:
    var pair_id := str(def.get("pair_id", ""))
    if pair_id == "":
        return false
    var ids: Array = upgrade_pairs.get(pair_id, [])
    var current_id := str(def.get("id", ""))
    for other_id in ids:
        if str(other_id) == current_id:
            continue
        if get_upgrade_level(str(other_id)) > 0:
            return true
    return false

func _is_pair_stage_unlocked(stage: int) -> bool:
    if stage <= 1:
        return is_cannery_unlocked
    return _is_pair_stage_completed(stage - 1)

func _is_pair_stage_completed(stage: int) -> bool:
    for def in upgrade_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        var def_stage := int(def.get("pair_stage", 0))
        if def_stage != stage:
            continue
        var id := str(def.get("id", ""))
        if get_upgrade_level(id) > 0:
            return true
    return false

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
    if def.has("pair_id") and _is_upgrade_pair_locked(def):
        return "Locked (other chosen)"
    if not _meets_requirements(def):
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
        var id := str(def.get("id", ""))
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
        var id := str(def.get("id", ""))
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
    return recipes_unlocked

func _unlock_recipe(method_id: String, ingredient_id: String) -> void:
    var label := _format_recipe(method_id, ingredient_id)
    if not recipes_unlocked.has(label):
        recipes_unlocked.append(label)

func _make_tin_key(method_id: String, ingredient_id: String) -> String:
    return "%s|%s" % [method_id, ingredient_id]

func _format_recipe_from_key(key: String) -> String:
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
    fish_count += catch_amount
    crew_trip_updated.emit()
    changed.emit()

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
