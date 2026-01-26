extends Node

signal changed
signal cannery_unlocked
signal cannery_discovered
signal crew_trip_updated
signal crew_discovered
signal crew_unlocked

const UPGRADE_DATA_PATH := "res://data/upgrades.json"
const SAVE_PATH := "user://save.json"
const GREEN_ZONE_BASE_RATIO := 0.10
const TIN_MAKE_BASE_TIME := 3.0

# Economy
var fish_count: int = 0
var tin_count: int = 0
var money: int = 0
var garlic_count: int = 0
var tin_inventory: Dictionary = {}
var recipes_unlocked: Array = []

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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    _load_upgrades()
    _rng.randomize()

func save_game() -> void:
    var data := {
        "version": 1,
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
        "crew_trip_remaining": crew_trip_remaining
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
    sell_mode = SellMode.FISH
    is_cannery_discovered = false
    is_cannery_unlocked = false
    is_crew_discovered = false
    is_crew_unlocked = false
    upgrade_levels.clear()
    crew_trip_active = false
    crew_trip_remaining = 0.0
    crew_trip_paused = false
    changed.emit()
    save_game()

func save_exists() -> bool:
    return FileAccess.file_exists(SAVE_PATH)

func _apply_save(data: Dictionary) -> void:
    fish_count = int(data.get("fish_count", 0))
    tin_count = int(data.get("tin_count", 0))
    money = int(data.get("money", 0))
    garlic_count = int(data.get("garlic_count", 0))
    lifetime_money_earned = int(data.get("lifetime_money_earned", 0))
    sell_mode = int(data.get("sell_mode", 0))
    is_cannery_discovered = bool(data.get("is_cannery_discovered", false))
    is_cannery_unlocked = bool(data.get("is_cannery_unlocked", false))
    is_crew_discovered = bool(data.get("is_crew_discovered", false))
    is_crew_unlocked = bool(data.get("is_crew_unlocked", false))
    upgrade_levels = data.get("upgrade_levels", {})
    tin_inventory = data.get("tin_inventory", {})
    recipes_unlocked = data.get("recipes_unlocked", [])
    crew_trip_active = bool(data.get("crew_trip_active", false))
    crew_trip_remaining = float(data.get("crew_trip_remaining", 0.0))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    if crew_trip_active and not crew_trip_paused:
        crew_trip_remaining = max(0.0, crew_trip_remaining - delta)
        if crew_trip_remaining <= 0.0:
            _complete_crew_trip()
    if _should_auto_send_crew():
        start_crew_trip()

func catch_fish(amount: int = 1) -> void:
    var bonus := _get_effect_total("catch_add")
    fish_count += max(1, amount + bonus)
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
                _add_money(get_fish_sell_price() * count)
        SellMode.TINS:
            if tin_count > 0:
                tin_count -= 1
                _remove_random_tin()
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
    for def in upgrade_defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        if not def.has("id"):
            continue
        upgrade_defs_by_id[def.id] = def

func get_upgrade_defs() -> Array:
    return upgrade_defs

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
    return _meets_requirements(def)

func _meets_requirements(def: Dictionary) -> bool:
    var reqs: Dictionary = def.get("requires", {})
    if reqs.is_empty():
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
    return true

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
    return 20 + _get_effect_total("fish_sell_add")

func get_tin_sell_price() -> int:
    return 10 + _get_effect_total("tin_sell_add")

func get_fish_sell_count() -> int:
    return 1 + _get_effect_total("fish_sell_count_add")

func get_green_zone_ratio() -> float:
    return min(1.0, GREEN_ZONE_BASE_RATIO + _get_effect_total_float("green_zone_add_pct"))

func get_tin_make_time() -> float:
    var time := TIN_MAKE_BASE_TIME + _get_effect_total_float("tin_time_add")
    return max(0.5, time)

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
