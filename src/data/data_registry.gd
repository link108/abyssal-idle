extends Node

const UPGRADES_PATH := "res://data/raw/upgrades.json"
const SKILL_TREE_PATH := "res://data/raw/skill_tree.json"
const FISH_PATH := "res://data/raw/fish.json"
const RECIPES_PATH := "res://data/raw/recipes.json"
const ITEMS_PATH := "res://data/raw/items.json"
const EQUIPMENT_PATH := "res://data/raw/equipment.json"
const PROCESSES_PATH := "res://data/raw/processes.json"
const CANNERY_OPTIONS_PATH := "res://data/raw/cannery_options.json"

var upgrades: Array = []
var skill_nodes: Array = []
var fish: Array = []
var recipes: Array = []
var items: Array = []
var equipment: Array = []
var processes: Array = []
var cannery_options: Dictionary = {}

var upgrades_by_id: Dictionary = {}
var skill_nodes_by_id: Dictionary = {}
var fish_by_id: Dictionary = {}
var fish_by_name: Dictionary = {}
var recipes_by_id: Dictionary = {}
var items_by_id: Dictionary = {}
var equipment_by_id: Dictionary = {}
var processes_by_id: Dictionary = {}

func load_all(include_optional: bool = false) -> void:
    upgrades = _read_json_array(UPGRADES_PATH)
    skill_nodes = _read_json_array(SKILL_TREE_PATH)
    fish = _read_json_array(FISH_PATH)
    recipes = _read_json_array(RECIPES_PATH)
    cannery_options = _read_json_object(CANNERY_OPTIONS_PATH)

    if include_optional:
        items = _read_json_array(ITEMS_PATH)
        equipment = _read_json_array(EQUIPMENT_PATH)
        processes = _read_json_array(PROCESSES_PATH)
    else:
        items = []
        equipment = []
        processes = []

    _build_maps()


func clear_cache() -> void:
    upgrades.clear()
    skill_nodes.clear()
    fish.clear()
    recipes.clear()
    items.clear()
    equipment.clear()
    processes.clear()
    cannery_options.clear()
    upgrades_by_id.clear()
    skill_nodes_by_id.clear()
    fish_by_id.clear()
    fish_by_name.clear()
    recipes_by_id.clear()
    items_by_id.clear()
    equipment_by_id.clear()
    processes_by_id.clear()


func _build_maps() -> void:
    upgrades_by_id.clear()
    for entry in upgrades:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var upgrade_id := str(entry.get("upgrade_id", ""))
        if upgrade_id != "":
            upgrades_by_id[upgrade_id] = entry

    skill_nodes_by_id.clear()
    for entry in skill_nodes:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var node_id := str(entry.get("id", ""))
        if node_id != "":
            skill_nodes_by_id[node_id] = entry

    fish_by_id.clear()
    fish_by_name.clear()
    for entry in fish:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var fish_id := str(entry.get("fish_id", ""))
        if fish_id != "":
            fish_by_id[fish_id] = entry
        var display_name := str(entry.get("display_name", ""))
        if display_name != "":
            fish_by_name[display_name] = fish_id

    recipes_by_id.clear()
    for entry in recipes:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var recipe_id := str(entry.get("recipe_id", ""))
        if recipe_id != "":
            recipes_by_id[recipe_id] = entry

    items_by_id.clear()
    for entry in items:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var item_id := _get_item_id(entry)
        if item_id != "":
            items_by_id[item_id] = entry

    equipment_by_id.clear()
    for entry in equipment:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var equipment_id := str(entry.get("equipment_id", ""))
        if equipment_id != "":
            equipment_by_id[equipment_id] = entry

    processes_by_id.clear()
    for entry in processes:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var process_id := str(entry.get("process_id", ""))
        if process_id != "":
            processes_by_id[process_id] = entry


func _get_item_id(entry: Dictionary) -> String:
    var ingredient_id := str(entry.get("ingredient_id", ""))
    if ingredient_id != "":
        return ingredient_id
    return str(entry.get("item_id", ""))


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


func _read_json_object(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return {}
    return parsed
