extends PanelContainer

signal make_tin_requested

const RequiresEval = preload("res://src/requires/requires_eval.gd")
const MAX_INGREDIENTS := 4
const PLUS_COLOR := Color(0.3, 1.0, 0.4, 1.0)
const NORMAL_COLOR := Color(1.0, 1.0, 1.0, 1.0)

const RecipeTags = preload("res://src/data/recipe_tags.gd")
const ExperimentLogPanel = preload("res://src/ui/components/experiment_log/experiment_log_panel.gd")
const PROCESS_CATEGORIES := [
	{"id": "prep", "label": "Prep (max 2)", "max": RecipeTags.PROCESS_CATEGORY_LIMITS["prep"]},
	{"id": "transform", "label": "Transform (max 2)", "max": RecipeTags.PROCESS_CATEGORY_LIMITS["transform"]},
	{"id": "heat", "label": "Heat (optional, max 2)", "max": RecipeTags.PROCESS_CATEGORY_LIMITS["heat"]},
	{"id": "preserve", "label": "Preserve (optional, max 2)", "max": RecipeTags.PROCESS_CATEGORY_LIMITS["preserve"]}
]

enum PickerMode { NONE, FISH, ADDON }

@onready var fish_slot_button: Button = $Control/FishSlotButton
@onready var addon_slot_buttons := [
	$Control/AddonSlots/AddonSlot0,
	$Control/AddonSlots/AddonSlot1,
	$Control/AddonSlots/AddonSlot2,
	$Control/AddonSlots/AddonSlot3
]
@onready var produce_toggle: CheckBox = $Control/ProduceToggle
@onready var make_tin_button := $Control/MakeTinButton
@onready var make_tin_progress := $Control/MakeTinButton/MakeTinProgress
@onready var last_made_label := $Control/LastMadeLabel
@onready var feedback_label := $Control/FeedbackLabel
@onready var hint_label := $Control/HintLabel
@onready var refine_last_button := $Control/RefineLastButton
@onready var risk_label := $Control/RiskLabel
@onready var log_label := $Control/LogLabel
@onready var open_log_button: Button = $Control/OpenLogButton
@onready var prep_list := $Control/ProcessPanel/PrepGroup/PrepList
@onready var transform_list := $Control/ProcessPanel/TransformGroup/TransformList
@onready var heat_list := $Control/ProcessPanel/HeatGroup/HeatList
@onready var preserve_list := $Control/ProcessPanel/PreserveGroup/PreserveList
@onready var finish_label := $Control/ProcessPanel/FinishLabel
@onready var picker_modal: Control = $Control/PickerModal
@onready var picker_title: Label = $Control/PickerModal/ModalPanel/ModalVBox/PickerTitle
@onready var picker_grid = $Control/PickerModal/ModalPanel/ModalVBox/PickerGrid
@onready var picker_clear_button: Button = $Control/PickerModal/ModalPanel/ModalVBox/PickerButtons/PickerClearButton
@onready var picker_close_button: Button = $Control/PickerModal/ModalPanel/ModalVBox/PickerButtons/PickerCloseButton

var _process_lists: Dictionary = {}
var _selected_process_ids: Dictionary = {
	"prep": [],
	"transform": [],
	"heat": [],
	"preserve": []
}
var _selected_fish_id: String = ""
var _selected_ingredient_ids: Array = []
var _picker_mode: PickerMode = PickerMode.NONE
var _picker_addon_index: int = -1
var _log_panel: Control

func _ready() -> void:
	_process_lists = {
		"prep": prep_list,
		"transform": transform_list,
		"heat": heat_list,
		"preserve": preserve_list
	}
	_load_processes()
	GameState.changed.connect(_refresh_counts)
	GameState.changed.connect(_refresh_process_state)
	GameState.changed.connect(_refresh_experiment_feedback)
	produce_toggle.toggled.connect(_on_produce_toggle_toggled)
	refine_last_button.pressed.connect(_on_refine_last_button_pressed)
	fish_slot_button.pressed.connect(_on_fish_slot_pressed)
	for i in range(addon_slot_buttons.size()):
		var button: Button = addon_slot_buttons[i]
		button.pressed.connect(_on_addon_slot_pressed.bind(i))
	picker_grid.item_selected.connect(_on_picker_item_selected)
	picker_clear_button.pressed.connect(_on_picker_clear_pressed)
	picker_close_button.pressed.connect(_close_picker_modal)
	picker_modal.hide()
	_log_panel = ExperimentLogPanel.new()
	$Control.add_child(_log_panel)
	_log_panel.attempt_applied.connect(_on_log_attempt_applied)
	open_log_button.pressed.connect(_log_panel.open)
	make_tin_progress.show_percentage = false
	_sync_selection_from_game_state()
	produce_toggle.button_pressed = GameState.cannery_produce_enabled
	_sync_selection_to_game_state()
	_refresh_counts()
	_refresh_process_state()
	_refresh_experiment_feedback()
	visibility_changed.connect(_on_visibility_changed)

func _on_visibility_changed() -> void:
	# The selection can change elsewhere (e.g. "Use recipe" in Collections).
	if not visible:
		return
	_sync_selection_from_game_state()
	_load_processes()
	_refresh_selection_buttons()

func _process(_delta: float) -> void:
	_update_cooldown_ui()

func _on_close_button_close_requested() -> void:
	picker_modal.hide()
	get_parent().get_node("Dimmer").hide()
	hide()

func _on_make_tin_button_pressed() -> void:
	if _selected_fish_id == "":
		return
	var ingredient_ids: Array = _selected_ingredient_ids.duplicate()
	var produce_tin := produce_toggle.button_pressed
	var made: bool = GameState.try_run_cannery_attempt(ingredient_ids, produce_tin)
	if made:
		var process_summary := _format_process_summary()
		var feedback: Dictionary = GameState.get_last_craft_feedback()
		var summary := str(feedback.get("summary", GameState.format_recipe(GameState.tin_method_id, ingredient_ids)))
		var prefix := "Made" if produce_tin else "Tested"
		last_made_label.text = "%s: %s%s" % [prefix, summary, process_summary]
	make_tin_requested.emit()
	_refresh_counts()
	_refresh_experiment_feedback()

func _refresh_counts() -> void:
	_sync_selection_from_game_state()
	_refresh_selection_buttons()

func _refresh_selection_buttons() -> void:
	_refresh_fish_button()
	_refresh_addon_buttons()
	_refresh_risk_label()

func _refresh_risk_label() -> void:
	var lines: Array = []
	for line in [GameState.get_tin_value_text(), GameState.get_experiment_risk_text()]:
		if line != "":
			lines.append(line)
	risk_label.text = "\n".join(lines)

func _refresh_fish_button() -> void:
	if _selected_fish_id == "":
		fish_slot_button.text = "+"
		fish_slot_button.modulate = PLUS_COLOR
		return
	var fish_name := _get_fish_display_name(_selected_fish_id)
	var count := int(GameState.fish_stock_by_id.get(_selected_fish_id, 0))
	fish_slot_button.text = "%s x%d" % [fish_name, count]
	fish_slot_button.modulate = NORMAL_COLOR

func _refresh_addon_buttons() -> void:
	for i in range(addon_slot_buttons.size()):
		var button: Button = addon_slot_buttons[i]
		if i >= _selected_ingredient_ids.size():
			button.text = "+"
			button.modulate = PLUS_COLOR
			continue
		var item_id := str(_selected_ingredient_ids[i])
		if item_id == "":
			button.text = "+"
			button.modulate = PLUS_COLOR
			continue
		var item_def := GameState.get_item_def(item_id)
		var label := str(item_def.get("display_name", item_id))
		var count := GameState.get_item_count(item_id)
		button.text = "%s x%d" % [label, count]
		button.modulate = NORMAL_COLOR

func _on_fish_slot_pressed() -> void:
	_open_picker_modal(PickerMode.FISH, -1)

func _on_addon_slot_pressed(index: int) -> void:
	_open_picker_modal(PickerMode.ADDON, index)

func _open_picker_modal(mode: PickerMode, addon_index: int) -> void:
	_picker_mode = mode
	_picker_addon_index = addon_index
	var title_text := "Choose Fish" if mode == PickerMode.FISH else "Choose Add-on"
	picker_title.text = title_text
	var entries := _build_picker_entries(mode)
	picker_grid.set_items(entries, "")
	var can_clear := false
	if mode == PickerMode.FISH:
		can_clear = _selected_fish_id != ""
	else:
		can_clear = addon_index >= 0 and addon_index < _selected_ingredient_ids.size()
	picker_clear_button.disabled = not can_clear
	picker_modal.show()

func _build_picker_entries(mode: PickerMode) -> Array:
	var out: Array = []
	var entries: Array = GameState.get_inventory_entries(false)
	var blocked_addons: Dictionary = {}
	if mode == PickerMode.ADDON:
		for i in range(_selected_ingredient_ids.size()):
			if i == _picker_addon_index:
				continue
			var selected_id := str(_selected_ingredient_ids[i])
			if selected_id != "":
				blocked_addons[selected_id] = true
	for entry in entries:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var entry_dict: Dictionary = entry
		var entry_type := str(entry_dict.get("type", ""))
		var item_id := str(entry_dict.get("id", ""))
		var count := int(entry_dict.get("count", 0))
		if count <= 0 or item_id == "":
			continue
		if mode == PickerMode.FISH and entry_type != "fish":
			continue
		if mode == PickerMode.ADDON:
			if entry_type != "item":
				continue
			var item_def := GameState.get_item_def(item_id)
			if not bool(item_def.get("is_consumable", true)):
				continue
			if blocked_addons.has(item_id):
				continue
		out.append({
			"id": "%s:%s" % [entry_type, item_id],
			"label": str(entry_dict.get("label", item_id)),
			"count": count,
			"payload": {
				"id": item_id
			}
		})
	return out

func _on_picker_item_selected(_grid_id: String, payload: Dictionary) -> void:
	var item_id := str(payload.get("id", ""))
	if item_id == "":
		return
	match _picker_mode:
		PickerMode.FISH:
			_selected_fish_id = item_id
		PickerMode.ADDON:
			_select_addon_at_slot(_picker_addon_index, item_id)
		_:
			return
	_sync_selection_to_game_state()
	_refresh_selection_buttons()
	_close_picker_modal()

func _on_picker_clear_pressed() -> void:
	match _picker_mode:
		PickerMode.FISH:
			_selected_fish_id = ""
		PickerMode.ADDON:
			if _picker_addon_index >= 0 and _picker_addon_index < _selected_ingredient_ids.size():
				_selected_ingredient_ids.remove_at(_picker_addon_index)
		_:
			return
	_sync_selection_to_game_state()
	_refresh_selection_buttons()
	_close_picker_modal()

func _close_picker_modal() -> void:
	picker_modal.hide()
	_picker_mode = PickerMode.NONE
	_picker_addon_index = -1

func _select_addon_at_slot(slot_index: int, item_id: String) -> void:
	_selected_ingredient_ids.erase(item_id)
	if slot_index < 0:
		return
	if slot_index < _selected_ingredient_ids.size():
		_selected_ingredient_ids[slot_index] = item_id
		return
	if _selected_ingredient_ids.size() >= MAX_INGREDIENTS:
		return
	_selected_ingredient_ids.append(item_id)

func _get_fish_display_name(fish_id: String) -> String:
	var defs: Array = GameState.get_collection_fish_defs()
	for fish_def in defs:
		if typeof(fish_def) != TYPE_DICTIONARY:
			continue
		if str(fish_def.get("fish_id", "")) != fish_id:
			continue
		return str(fish_def.get("display_name", fish_id))
	return fish_id

func _update_cooldown_ui() -> void:
	var produce_tin: bool = produce_toggle.button_pressed
	var ready: bool = true if not produce_tin else GameState.can_make_tin()
	if _selected_fish_id == "":
		ready = false
	elif int(GameState.fish_stock_by_id.get(_selected_fish_id, 0)) <= 0:
		ready = false
	make_tin_button.disabled = not ready
	make_tin_button.modulate = Color(1, 1, 1, 1) if ready else Color(0.6, 0.6, 0.6, 1)
	var action_label := _get_action_label()
	if _selected_fish_id == "":
		make_tin_button.text = "Select fish"
		make_tin_progress.value = 0.0
		return
	if int(GameState.fish_stock_by_id.get(_selected_fish_id, 0)) <= 0:
		make_tin_button.text = "Fish unavailable"
		make_tin_progress.value = 0.0
		return
	if not produce_tin:
		make_tin_progress.value = 1.0
		make_tin_button.text = action_label
		return
	var total: float = GameState.get_tin_cooldown_total()
	var remaining: float = GameState.tin_cooldown_remaining
	if total <= 0.0:
		make_tin_progress.value = 1.0
		make_tin_button.text = action_label
	else:
		var progress: float = 1.0 - (remaining / total)
		var clamped: float = clamp(progress, 0.0, 1.0)
		make_tin_progress.value = clamped
		var pct: int = int(round(clamped * 100.0))
		if ready or pct >= 100:
			make_tin_button.text = action_label
		else:
			make_tin_button.text = "%d%%" % pct

func _sync_selection_to_game_state() -> void:
	GameState.set_tin_ingredients(_selected_ingredient_ids)
	GameState.set_tin_fish_selection(_selected_fish_id)

func _sync_selection_from_game_state() -> void:
	_selected_fish_id = str(GameState.get_tin_selected_fish_id())
	_selected_ingredient_ids = (GameState.tin_ingredient_ids as Array).duplicate()
	if _selected_ingredient_ids.size() > MAX_INGREDIENTS:
		_selected_ingredient_ids = _selected_ingredient_ids.slice(0, MAX_INGREDIENTS)

func _on_refine_last_button_pressed() -> void:
	if not GameState.apply_attempt_to_selection():
		return
	_on_log_attempt_applied()

func _on_log_attempt_applied() -> void:
	_sync_selection_from_game_state()
	_load_processes()
	_refresh_selection_buttons()
	_refresh_experiment_feedback()

func _on_produce_toggle_toggled(pressed: bool) -> void:
	GameState.set_cannery_produce_enabled(pressed)
	if not pressed:
		GameState.clear_tin_cooldown()
	_update_cooldown_ui()

func _get_action_label() -> String:
	return "Make tin" if produce_toggle.button_pressed else "Run test"

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
	checkbox.text = "%s  +%.1fs" % [label, GameState.get_process_duration(process_id) * GameState.PROCESS_TIME_SCALE]
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
	_refresh_risk_label()

func _format_process_summary() -> String:
	var sequence: Array = GameState.build_process_sequence()
	if sequence.is_empty():
		return ""
	return " [%s]" % ", ".join(sequence)

func _refresh_experiment_feedback() -> void:
	var feedback: Dictionary = GameState.get_last_craft_feedback()
	if feedback.is_empty():
		feedback_label.text = "Score: --"
		hint_label.text = "Hint: Run an experiment to get feedback."
	else:
		feedback_label.text = "Score: %d%%" % int(feedback.get("score", 0))
		hint_label.text = "Hint: %s" % str(feedback.get("hint", ""))
	var recent: Array = GameState.get_experiment_log_view("newest").slice(0, 3)
	if recent.is_empty():
		log_label.text = "Recent experiments: none"
	else:
		var lines: Array = ["Recent experiments:"]
		for entry in recent:
			lines.append("#%d  %d%%%s  %s" % [
				int(entry.get("attempt_id", 0)),
				int(entry.get("score", 0)),
				" ★" if bool(entry.get("is_closest", false)) else "",
				str(entry.get("result_key", "experimental_tin_rough")).replace("_", " ")
			])
		var closest: Dictionary = GameState.get_closest_attempt_for_fish(_selected_fish_id)
		if not closest.is_empty():
			lines.append("★ Closest so far for this fish: %d%% (#%d)" % [int(closest.get("score", 0)), int(closest.get("attempt_id", 0))])
		log_label.text = "\n".join(lines)
