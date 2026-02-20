extends PanelContainer

@export var columns: int = 5
@export var rows: int = 4

@onready var item_grid := $Control/BodySplit/GridScroll/ItemGrid
@onready var detail_title := $Control/BodySplit/DetailPanel/DetailVBox/DetailTitle
@onready var detail_info := $Control/BodySplit/DetailPanel/DetailVBox/DetailInfo
@onready var fish_button: Button = $Control/CategoryButtons/FishButton
@onready var tins_button: Button = $Control/CategoryButtons/TinsButton
@onready var ingredients_button: Button = $Control/CategoryButtons/IngredientsButton
var _selected_grid_id: String = ""
var _selected_category: String = "fish"

func _ready() -> void:
    _refresh()
    GameState.changed.connect(_refresh)
    item_grid.item_selected.connect(_on_item_selected)
    fish_button.pressed.connect(_on_fish_button_pressed)
    tins_button.pressed.connect(_on_tins_button_pressed)
    ingredients_button.pressed.connect(_on_ingredients_button_pressed)
    _update_category_buttons()

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _on_visibility_changed() -> void:
    if visible:
        _refresh()

func _refresh() -> void:
    item_grid.columns = columns
    var entries: Array = _filtered_inventory_entries(GameState.get_inventory_entries(true))
    var total_slots: int = columns * rows
    if entries.size() > total_slots:
        entries = entries.slice(0, total_slots)
    var grid_entries: Array = []
    var prev_selected := _selected_grid_id
    _selected_grid_id = ""
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var entry_dict: Dictionary = entry
        var entry_id: String = str(entry_dict.get("id", ""))
        var entry_type: String = str(entry_dict.get("type", ""))
        if entry_id == "" or entry_type == "":
            continue
        var grid_id := "%s:%s" % [entry_type, entry_id]
        grid_entries.append({
            "id": "%s:%s" % [entry_type, entry_id],
            "label": str(entry_dict.get("label", entry_id)),
            "count": int(entry_dict.get("count", 0)),
            "payload": entry_dict
        })
        if _selected_grid_id == "" and grid_id == prev_selected:
            _selected_grid_id = grid_id
    if _selected_grid_id == "" and not grid_entries.is_empty():
        _selected_grid_id = str(grid_entries[0].get("id", ""))
    item_grid.set_items(grid_entries, _selected_grid_id)
    if _selected_grid_id == "":
        _clear_detail()

func _filtered_inventory_entries(entries: Array) -> Array:
    var out: Array = []
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var entry_dict: Dictionary = entry
        var entry_type := str(entry_dict.get("type", ""))
        if _selected_category == "fish" and entry_type != "fish":
            continue
        if _selected_category == "tins" and entry_type != "tin":
            continue
        if _selected_category == "ingredients" and entry_type != "item":
            continue
        out.append(entry_dict)
    return out

func _on_item_selected(_grid_id: String, payload: Dictionary) -> void:
    if payload.is_empty():
        _clear_detail()
        return
    _selected_grid_id = _grid_id
    var label := str(payload.get("label", "Item"))
    var desc := str(payload.get("description", ""))
    var rarity := str(payload.get("rarity", ""))
    var category := str(payload.get("category", ""))
    var count := int(payload.get("count", 0))
    var tags: Array = payload.get("tags", [])
    var tag_text: String = "" if typeof(tags) != TYPE_ARRAY or tags.is_empty() else "Tags: %s" % ", ".join(tags)
    var sell_value := int(payload.get("sell_value", 0))
    detail_title.text = label
    detail_info.text = "Rarity: %s\nCategory: %s\nOwned: %d\nSell: $%d\n%s\n\n%s" % [
        rarity,
        category,
        count,
        sell_value,
        tag_text,
        desc
    ]

func _clear_detail() -> void:
    detail_title.text = "Select an item"
    detail_info.text = "Click an item to see details."

func _on_fish_button_pressed() -> void:
    _set_category("fish")

func _on_tins_button_pressed() -> void:
    _set_category("tins")

func _on_ingredients_button_pressed() -> void:
    _set_category("ingredients")

func _set_category(category: String) -> void:
    if _selected_category == category:
        return
    _selected_category = category
    _selected_grid_id = ""
    _update_category_buttons()
    _refresh()

func _update_category_buttons() -> void:
    fish_button.button_pressed = _selected_category == "fish"
    tins_button.button_pressed = _selected_category == "tins"
    ingredients_button.button_pressed = _selected_category == "ingredients"
