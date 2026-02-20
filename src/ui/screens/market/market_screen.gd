extends PanelContainer

@export var red_style: StyleBoxFlat
@export var green_style: StyleBoxFlat

@onready var sell_mode_button := $Control/MainRow/Sidebar/SidebarVBox/ModeButtons/SellModeButton
@onready var buy_mode_button := $Control/MainRow/Sidebar/SidebarVBox/ModeButtons/BuyModeButton
@onready var content_title := $Control/MainRow/Content/ContentTitle
@onready var item_grid := $Control/MainRow/Content/ContentSplit/ItemListPanel/ItemScroll/ItemGrid
@onready var detail_title := $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/DetailTitle
@onready var detail_info := $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/DetailInfo
@onready var action_button := $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/ActionButton
@onready var qty_buttons := [
    $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/QtyButtons/Qty1,
    $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/QtyButtons/Qty5,
    $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/QtyButtons/Qty10,
    $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/QtyButtons/Qty25,
    $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/QtyButtons/Qty50,
    $Control/MainRow/Content/ContentSplit/DetailPanel/DetailVBox/QtyButtons/Qty100
]

enum Mode { SELL, BUY }
var _mode: Mode = Mode.SELL
var _list_entries: Array = []
var _selected_id: String = ""
var _selected_type: String = ""
var _buy_qty: int = 1

func _ready() -> void:
    sell_mode_button.pressed.connect(_on_sell_mode_pressed)
    buy_mode_button.pressed.connect(_on_buy_mode_pressed)
    action_button.pressed.connect(_on_action_pressed)
    item_grid.item_selected.connect(_on_item_grid_selected)
    _setup_qty_buttons()
    _refresh_mode_buttons()
    _rebuild_list()
    GameState.changed.connect(_refresh_list_counts)

func _on_close_button_pressed() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _on_sell_mode_pressed() -> void:
    _set_mode(Mode.SELL)

func _on_buy_mode_pressed() -> void:
    _set_mode(Mode.BUY)

func _set_mode(mode: Mode) -> void:
    if _mode == mode:
        return
    _mode = mode
    _refresh_mode_buttons()
    _rebuild_list()

func _refresh_mode_buttons() -> void:
    sell_mode_button.button_pressed = _mode == Mode.SELL
    buy_mode_button.button_pressed = _mode == Mode.BUY
    var sell_style := green_style if sell_mode_button.button_pressed else red_style
    var buy_style := green_style if buy_mode_button.button_pressed else red_style
    sell_mode_button.add_theme_stylebox_override("normal", sell_style)
    sell_mode_button.add_theme_stylebox_override("hover", sell_style)
    sell_mode_button.add_theme_stylebox_override("pressed", sell_style)
    sell_mode_button.add_theme_stylebox_override("hover_pressed", sell_style)
    buy_mode_button.add_theme_stylebox_override("normal", buy_style)
    buy_mode_button.add_theme_stylebox_override("hover", buy_style)
    buy_mode_button.add_theme_stylebox_override("pressed", buy_style)
    buy_mode_button.add_theme_stylebox_override("hover_pressed", buy_style)
    content_title.text = "Sell" if _mode == Mode.SELL else "Buy"

func _setup_qty_buttons() -> void:
    var group := ButtonGroup.new()
    for b in qty_buttons:
        b.button_group = group
        b.pressed.connect(_on_qty_button_pressed.bind(b))
    _buy_qty = 1

func _on_qty_button_pressed(button: Button) -> void:
    var qty := int(button.text)
    _buy_qty = max(1, qty)
    _refresh_detail()

func _rebuild_list() -> void:
    _list_entries = _build_list_entries()
    var prev_id := _selected_id
    var prev_type := _selected_type
    _selected_id = ""
    _selected_type = ""

    var entries_for_grid: Array = []
    for entry in _list_entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var entry_dict: Dictionary = entry
        var entry_id: String = str(entry_dict.get("id", ""))
        var entry_type: String = str(entry_dict.get("type", ""))
        if entry_id == "" or entry_type == "":
            continue
        entries_for_grid.append({
            "id": entry_id,
            "label": str(entry_dict.get("label", entry_id)),
            "count": int(entry_dict.get("count", 0)),
            "payload": {"type": entry_type}
        })
        if _selected_id == "" and entry_id == prev_id and entry_type == prev_type:
            _selected_id = entry_id
            _selected_type = entry_type

    if _selected_id == "" and not entries_for_grid.is_empty():
        var first: Dictionary = entries_for_grid[0]
        _selected_id = str(first.get("id", ""))
        var payload: Dictionary = first.get("payload", {})
        _selected_type = str(payload.get("type", ""))

    item_grid.set_items(entries_for_grid, _selected_id)
    _refresh_detail()

func _build_list_entries() -> Array:
    if _mode == Mode.BUY:
        return _build_vendor_entries()
    return GameState.get_inventory_entries(false)

func _build_vendor_entries() -> Array:
    var out: Array = []
    var defs: Array = GameState.get_vendor_item_defs()
    for def in defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        var item_id := str(def.get("ingredient_id", def.get("item_id", "")))
        if item_id == "":
            continue
        var name := str(def.get("display_name", item_id))
        var count := GameState.get_item_count(item_id)
        out.append({
            "type": "item",
            "id": item_id,
            "label": name,
            "count": count,
            "description": str(def.get("description", "")),
            "rarity": str(def.get("rarity", "")),
            "category": str(def.get("category", "")),
            "tags": def.get("tags", []),
            "cost": int(def.get("base_cost", 0)),
            "sell_value": int(def.get("sell_value", 0))
        })
    return out

func _on_item_grid_selected(entry_id: String, payload: Dictionary) -> void:
    _selected_id = entry_id
    _selected_type = str(payload.get("type", ""))
    _refresh_detail()

func _refresh_list_counts() -> void:
    _rebuild_list()

func _refresh_detail() -> void:
    if _selected_id == "":
        detail_title.text = "Select an item"
        detail_info.text = "Click an item to see details."
        action_button.text = "Select an item"
        action_button.disabled = true
        return

    var entry := _get_selected_entry()
    if entry.is_empty():
        detail_title.text = "Select an item"
        detail_info.text = "Click an item to see details."
        action_button.text = "Select an item"
        action_button.disabled = true
        return

    var label := str(entry.get("label", _selected_id))
    var desc := str(entry.get("description", ""))
    var rarity := str(entry.get("rarity", ""))
    var category := str(entry.get("category", ""))
    var count := int(entry.get("count", 0))
    var tags: Array = entry.get("tags", [])
    var tag_text: String = "" if typeof(tags) != TYPE_ARRAY or tags.is_empty() else "Tags: %s" % ", ".join(tags)
    var cost := int(entry.get("cost", 0))
    var sell_value := int(entry.get("sell_value", 0))

    detail_title.text = label
    detail_info.text = "Rarity: %s\nCategory: %s\nOwned: %d\n%s\n%s" % [
        rarity,
        category,
        count,
        tag_text,
        desc
    ]

    if _mode == Mode.BUY:
        var total_cost: int = cost * _buy_qty
        action_button.text = "Buy %d ($%d)" % [_buy_qty, total_cost]
        action_button.disabled = cost <= 0
    else:
        var total_sell: int = sell_value * min(_buy_qty, count)
        action_button.text = "Sell %d ($%d)" % [_buy_qty, total_sell]
        action_button.disabled = count <= 0 or sell_value <= 0

func _get_selected_entry() -> Dictionary:
    for entry in _list_entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var entry_dict: Dictionary = entry
        if str(entry_dict.get("id", "")) == _selected_id and str(entry_dict.get("type", "")) == _selected_type:
            return entry_dict
    return {}

func _on_action_pressed() -> void:
    if _selected_id == "":
        return
    if _mode == Mode.BUY:
        if not GameState.buy_item(_selected_id, _buy_qty):
            return
        _refresh_list_counts()
        return

    var entry := _get_selected_entry()
    if entry.is_empty():
        return
    var count := int(entry.get("count", 0))
    if count <= 0:
        return
    var qty: int = min(_buy_qty, count)
    var entry_type := str(entry.get("type", ""))
    match entry_type:
        "fish":
            GameState.sell_fish(qty)
        "tin":
            GameState.sell_tins(qty)
        "item":
            GameState.sell_item(_selected_id, qty)
        _:
            return
    _refresh_list_counts()

func _build_slot_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.12, 0.12, 0.12, 0.9)
    style.border_color = Color(0.3, 0.3, 0.3, 1)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    return style
