extends PanelContainer

@onready var equipment_list := $Control/ScrollContainer/EquipmentList
@onready var show_purchased_toggle := $Control/ShowPurchasedToggle

func _ready() -> void:
    GameState.changed.connect(_refresh)
    show_purchased_toggle.toggled.connect(_on_show_purchased_toggled)
    _refresh()

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _refresh() -> void:
    _rebuild_equipment_list()

func _on_show_purchased_toggled(_pressed: bool) -> void:
    _rebuild_equipment_list()

func _rebuild_equipment_list() -> void:
    for child in equipment_list.get_children():
        child.queue_free()

    var defs_by_cat: Dictionary = GameState.get_equipment_defs_by_category(show_purchased_toggle.button_pressed)
    var category_order: Array = GameState.get_equipment_category_order()
    var remaining := defs_by_cat.keys()
    var added_any := false

    for category in category_order:
        var defs: Array = defs_by_cat.get(category, [])
        if defs.is_empty():
            continue
        _add_category_header(str(category))
        for def in defs:
            if typeof(def) != TYPE_DICTIONARY:
                continue
            equipment_list.add_child(_create_equipment_card(def))
            added_any = true
        remaining.erase(category)

    for category in remaining:
        var defs: Array = defs_by_cat.get(category, [])
        if defs.is_empty():
            continue
        _add_category_header(str(category))
        for def in defs:
            if typeof(def) != TYPE_DICTIONARY:
                continue
            equipment_list.add_child(_create_equipment_card(def))
            added_any = true

    if not added_any:
        var empty_label := Label.new()
        empty_label.text = "All equipment purchased."
        equipment_list.add_child(empty_label)

func _add_category_header(category: String) -> void:
    var header := Label.new()
    header.text = category.capitalize()
    equipment_list.add_child(header)

func _create_equipment_card(def: Dictionary) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 72)

    var hbox := HBoxContainer.new()
    hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_child(hbox)

    var stripe := ColorRect.new()
    stripe.custom_minimum_size = Vector2(14, 0)
    stripe.size_flags_vertical = Control.SIZE_EXPAND_FILL
    stripe.color = Color(0, 0, 0, 0)
    hbox.add_child(stripe)

    var vbox := VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(vbox)

    var id_str: String = str(def.get("equipment_id", ""))
    var tier: int = int(def.get("tier", 0))
    var name_text: String = str(def.get("display_name", "Equipment"))
    if tier > 0:
        name_text = "%s (Tier %d)" % [name_text, tier]

    var name_label := Label.new()
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    name_label.text = name_text
    vbox.add_child(name_label)

    var desc_label := Label.new()
    desc_label.text = str(def.get("description", ""))
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(desc_label)

    var stats_label := Label.new()
    stats_label.text = _format_equipment_stats(id_str)
    stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stats_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0, 1.0))
    vbox.add_child(stats_label)

    var buy_btn := Button.new()
    var owned := GameState.owns_equipment(id_str)
    if owned:
        stripe.color = Color(0.0, 0.8, 0.25, 1.0)
        if GameState.is_equipment_maxed(id_str):
            buy_btn.text = "Max level" if GameState.get_equipment_max_level(id_str) > 1 else "Purchased"
            buy_btn.disabled = true
            buy_btn.modulate = Color(0.0, 0.9, 0.3, 1.0)
        else:
            var upgrade_cost := GameState.get_equipment_upgrade_cost(id_str)
            buy_btn.text = "Upgrade ($%d)" % upgrade_cost
            buy_btn.disabled = not GameState.can_upgrade_equipment(id_str)
        buy_btn.pressed.connect(_on_upgrade_pressed.bind(id_str))
        hbox.add_child(buy_btn)
        return card
    else:
        var lock_reason := GameState.get_equipment_lock_reason(id_str)
        if lock_reason != "":
            buy_btn.text = lock_reason
            buy_btn.disabled = true
            buy_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
            buy_btn.tooltip_text = lock_reason
        else:
            buy_btn.text = "Buy ($%d)" % GameState.get_equipment_cost(id_str)
    buy_btn.pressed.connect(_on_buy_pressed.bind(id_str))
    hbox.add_child(buy_btn)

    return card

func _on_buy_pressed(id: String) -> void:
    GameState.purchase_equipment(id)

func _on_upgrade_pressed(id: String) -> void:
    GameState.upgrade_equipment(id)

# "Speeds up: Smoke · Lv 2/4 · speed x1.25 (next x1.50)"
func _format_equipment_stats(id: String) -> String:
    var parts: Array = []
    var process_names: Array = GameState.get_equipment_process_names(id)
    if not process_names.is_empty():
        parts.append("Speeds up: %s" % ", ".join(process_names))
    var max_level := GameState.get_equipment_max_level(id)
    var level := GameState.get_equipment_level(id)
    if max_level > 1:
        parts.append("Lv %d/%d" % [level, max_level])
    if level > 0:
        var speed := GameState.get_equipment_speed(id)
        var speed_text := "speed x%.2f" % speed
        if level < max_level:
            var per_level := float(GameState.get_equipment_def(id).get("base_speed_multiplier", 1.0)) * GameState.EQUIPMENT_SPEED_PER_LEVEL
            speed_text += " (next x%.2f)" % (speed + per_level)
        parts.append(speed_text)
    return " · ".join(parts)
