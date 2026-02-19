extends PanelContainer

signal make_tin_requested

const OPTIONS_PATH := "res://data/raw/cannery_options.json"
const RequiresEval = preload("res://src/requires/requires_eval.gd")

const PROCESS_CATEGORIES := [
    {"id": "prep", "label": "Prep (max 2)", "max": 2},
    {"id": "transform", "label": "Transform (max 1)", "max": 1},
    {"id": "heat", "label": "Heat (optional)", "max": 1},
    {"id": "preserve", "label": "Preserve (optional)", "max": 1}
]

@onready var method_select := $Control/MethodSelect
@onready var ingredient_select := $Control/IngredientSelect
@onready var garlic_label := $Control/GarlicCountLabel
@onready var make_tin_button := $Control/MakeTinButton
@onready var make_tin_progress := $Control/MakeTinButton/MakeTinProgress
@onready var last_made_label := $Control/LastMadeLabel
@onready var prep_list := $Control/ProcessPanel/PrepGroup/PrepList
@onready var transform_list := $Control/ProcessPanel/TransformGroup/TransformList
@onready var heat_list := $Control/ProcessPanel/HeatGroup/HeatList
@onready var preserve_list := $Control/ProcessPanel/PreserveGroup/PreserveList
@onready var finish_label := $Control/ProcessPanel/FinishLabel

var methods: Array = []
var ingredients: Array = []
var _process_lists: Dictionary = {}
var _selected_process_ids: Dictionary = {
    "prep": [],
    "transform": [],
    "heat": [],
    "preserve": []
}

func _ready() -> void:
    _load_options()
    _populate_options()
    _process_lists = {
        "prep": prep_list,
        "transform": transform_list,
        "heat": heat_list,
        "preserve": preserve_list
    }
    _load_processes()
    GameState.changed.connect(_refresh_counts)
    GameState.changed.connect(_refresh_process_state)
    _refresh_counts()
    make_tin_progress.show_percentage = false
    method_select.item_selected.connect(_on_method_selected)
    ingredient_select.item_selected.connect(_on_ingredient_selected)
    _sync_selection_to_game_state()
    _refresh_process_state()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    _update_cooldown_ui()

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _on_make_tin_button_pressed() -> void:
    var method_id: String = _get_selected_id(method_select, "raw")
    var ingredient_id: String = _get_selected_id(ingredient_select, "none")
    var made: bool = GameState.try_make_tin(method_id, ingredient_id)
    if made:
        var process_summary := _format_process_summary()
        last_made_label.text = "Made: %s%s" % [GameState.format_recipe(method_id, ingredient_id), process_summary]
    make_tin_requested.emit()
    _refresh_counts()

func _load_options() -> void:
    if not FileAccess.file_exists(OPTIONS_PATH):
        return
    var file := FileAccess.open(OPTIONS_PATH, FileAccess.READ)
    var raw := file.get_as_text()
    file.close()
    var parsed = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    methods = parsed.get("methods", [])
    ingredients = parsed.get("ingredients", [])

func _populate_options() -> void:
    method_select.clear()
    ingredient_select.clear()
    for m in methods:
        if typeof(m) == TYPE_DICTIONARY:
            method_select.add_item(str(m.get("name", "Method")))
            method_select.set_item_metadata(method_select.item_count - 1, m.get("id", "raw"))
    for i in ingredients:
        if typeof(i) == TYPE_DICTIONARY:
            ingredient_select.add_item(str(i.get("name", "Ingredient")))
            ingredient_select.set_item_metadata(ingredient_select.item_count - 1, i.get("id", "none"))

func _get_selected_id(option: OptionButton, fallback: String) -> String:
    if option.item_count <= 0:
        return fallback
    var idx: int = option.selected
    var meta: Variant = option.get_item_metadata(idx)
    if meta == null:
        return fallback
    return str(meta)

func _refresh_counts() -> void:
    garlic_label.text = "Garlic: %d" % GameState.garlic_count


func _update_cooldown_ui() -> void:
    var ready: bool = GameState.can_make_tin()
    make_tin_button.disabled = not ready
    make_tin_button.modulate = Color(1, 1, 1, 1) if ready else Color(0.6, 0.6, 0.6, 1)
    var total: float = GameState.get_tin_make_time()
    var remaining: float = GameState.tin_cooldown_remaining
    if total <= 0.0:
        make_tin_progress.value = 1.0
        make_tin_button.text = "Make tin"
    else:
        var progress: float = 1.0 - (remaining / total)
        var clamped: float = clamp(progress, 0.0, 1.0)
        make_tin_progress.value = clamped
        var pct: int = int(round(clamped * 100.0))
        if ready or pct >= 100:
            make_tin_button.text = "Make tin"
        else:
            make_tin_button.text = "%d%%" % pct


func _on_method_selected(_index: int) -> void:
    _sync_selection_to_game_state()

func _on_ingredient_selected(_index: int) -> void:
    _sync_selection_to_game_state()

func _sync_selection_to_game_state() -> void:
    var method_id: String = _get_selected_id(method_select, "raw")
    var ingredient_id: String = _get_selected_id(ingredient_select, "none")
    GameState.set_tin_selection(method_id, ingredient_id)

func _load_processes() -> void:
    _selected_process_ids = {
        "prep": GameState.get_selected_processes("prep"),
        "transform": GameState.get_selected_processes("transform"),
        "heat": GameState.get_selected_processes("heat"),
        "preserve": GameState.get_selected_processes("preserve")
    }
    _rebuild_process_groups()

func _refresh_process_state() -> void:
    finish_label.text = "Finish: Pack + Seal" if GameState.is_cannery_unlocked else "Finish: Unlock cannery to pack + seal"
    _rebuild_process_groups()

func _rebuild_process_groups() -> void:
    var processes_by_category: Dictionary = GameState.get_process_defs_by_category()
    for category_info in PROCESS_CATEGORIES:
        var category_id: String = category_info["id"]
        var list_node: VBoxContainer = _process_lists.get(category_id, null)
        if list_node == null:
            continue
        for child in list_node.get_children():
            child.queue_free()
        var defs: Array = processes_by_category.get(category_id, [])
        for process_def in defs:
            if typeof(process_def) != TYPE_DICTIONARY:
                continue
            _add_process_checkbox(list_node, category_info, process_def)

func _add_process_checkbox(list_node: VBoxContainer, category_info: Dictionary, process_def: Dictionary) -> void:
    var process_id := str(process_def.get("process_id", ""))
    var label := str(process_def.get("display_name", process_id))
    var checkbox := CheckBox.new()
    checkbox.text = label
    checkbox.button_pressed = _selected_process_ids[category_info["id"]].has(process_id)

    var availability := _get_process_availability(process_def)
    checkbox.disabled = not availability["available"]
    if not availability["available"]:
        checkbox.tooltip_text = availability["reason"]

    checkbox.toggled.connect(_on_process_toggled.bind(category_info, process_id, checkbox))
    list_node.add_child(checkbox)

func _get_process_availability(process_def: Dictionary) -> Dictionary:
    var reason_parts: Array = []
    var reqs: Array = RequiresEval.get_requires(process_def)
    if not RequiresEval.is_met(reqs, GameState):
        reason_parts.append("Requires not met")
    var required_equipment: Array = process_def.get("required_equipment", [])
    var missing: Array = []
    if typeof(required_equipment) == TYPE_ARRAY:
        for equipment_id in required_equipment:
            if typeof(equipment_id) != TYPE_STRING:
                continue
            if not GameState.owns_equipment(equipment_id):
                missing.append(equipment_id)
    if missing.size() > 0:
        reason_parts.append("Missing equipment: %s" % ", ".join(missing))
    var available := reason_parts.is_empty()
    return {
        "available": available,
        "reason": "; ".join(reason_parts)
    }

func _on_process_toggled(pressed: bool, category_info: Dictionary, process_id: String, checkbox: CheckBox) -> void:
    var category_id: String = category_info["id"]
    var max_count: int = int(category_info["max"])
    var selected: Array = _selected_process_ids.get(category_id, [])
    if pressed:
        if selected.size() >= max_count:
            checkbox.button_pressed = false
            return
        if not selected.has(process_id):
            selected.append(process_id)
    else:
        selected.erase(process_id)
    _selected_process_ids[category_id] = selected
    GameState.set_selected_processes(category_id, selected)

func _format_process_summary() -> String:
    var sequence: Array = GameState.build_process_sequence()
    if sequence.is_empty():
        return ""
    return " [%s]" % ", ".join(sequence)
