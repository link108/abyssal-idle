extends Node

signal changed
signal cannery_unlocked
signal cannery_discovered

const UPGRADE_DATA_PATH := "res://data/upgrades.json"

# Economy
var fish_count: int = 0
var tin_count: int = 0
var money: int = 0

# Upgrades: Cannery
const CANNERY_UNLOCK_COST := 200
const CANNERY_DISCOVERY_EARNED := 50
var is_cannery_discovered: bool = false
var is_cannery_unlocked: bool = false
var lifetime_money_earned: int = 0

# Market
enum SellMode { FISH, TINS }
var sell_mode: SellMode = SellMode.FISH

# Upgrades
var upgrade_defs: Array = []
var upgrade_defs_by_id: Dictionary = {}
var upgrade_levels: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    _load_upgrades()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass

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

func _add_money(amount: int) -> void:
    if amount <= 0:
        return
    money += amount
    lifetime_money_earned += amount
    _check_cannery_discovery()
    changed.emit()

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
    var def = upgrade_defs_by_id.get(id, null)
    if def == null:
        return false
    if not _meets_requirements(def):
        return false
    return money >= get_upgrade_cost(id)

func purchase_upgrade(id: String) -> bool:
    if not can_purchase_upgrade(id):
        return false
    var cost := get_upgrade_cost(id)
    money -= cost
    upgrade_levels[id] = get_upgrade_level(id) + 1
    changed.emit()
    return true

func can_show_upgrade(def: Dictionary) -> bool:
    return _meets_requirements(def)

func _meets_requirements(def: Dictionary) -> bool:
    var reqs: Dictionary = def.get("requires", {})
    if reqs.is_empty():
        return true
    if reqs.get("cannery", false) and not is_cannery_unlocked:
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

func get_fish_sell_price() -> int:
    return 20 + _get_effect_total("fish_sell_add")

func get_tin_sell_price() -> int:
    return 10 + _get_effect_total("tin_sell_add")

func get_fish_sell_count() -> int:
    return 1 + _get_effect_total("fish_sell_count_add")
