extends PanelContainer

@onready var upgrades_list := $Control/ScrollContainer/UpgradesList
@onready var show_purchased_toggle := $Control/ShowPurchasedToggle

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    GameState.changed.connect(_refresh)
    show_purchased_toggle.toggled.connect(_on_show_purchased_toggled)
    _refresh()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()


func _refresh() -> void:
    _rebuild_upgrade_list()

func _on_show_purchased_toggled(_pressed: bool) -> void:
    _rebuild_upgrade_list()

func _rebuild_upgrade_list() -> void:
    for child in upgrades_list.get_children():
        child.queue_free()

    var categories := ["core", "fishing", "cannery", "policy"]
    var defs_by_cat: Dictionary = GameState.get_visible_upgrade_defs_by_category()
    for category in categories:
        var defs: Array = defs_by_cat.get(category, [])
        var header := Label.new()
        header.text = category.capitalize()
        upgrades_list.add_child(header)
        if defs.is_empty():
            var empty_label := Label.new()
            empty_label.text = "No upgrades available"
            upgrades_list.add_child(empty_label)
            continue

        var pair_order: Array = []
        var pairs: Dictionary = {}
        var singles: Array = []
        for def in defs:
            if typeof(def) != TYPE_DICTIONARY:
                continue
            var id_str := str(def.get("id", ""))
            if (not show_purchased_toggle.button_pressed) and GameState.get_upgrade_level(id_str) > 0:
                if str(def.get("pair_id", "")) == "":
                    continue
            var pair_id := str(def.get("pair_id", ""))
            if pair_id == "":
                singles.append(def)
                continue
            if not pairs.has(pair_id):
                pairs[pair_id] = []
                pair_order.append(pair_id)
            pairs[pair_id].append(def)

        for pair_id in pair_order:
            var hbox := HBoxContainer.new()
            hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            hbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
            var defs_in_pair: Array = pairs.get(pair_id, [])
            for def in defs_in_pair:
                var card := _create_upgrade_card(def)
                card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                hbox.add_child(card)
            upgrades_list.add_child(hbox)

        for def in singles:
            var card := _create_upgrade_card(def)
            upgrades_list.add_child(card)

func _create_upgrade_card(def: Dictionary) -> Control:
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

    var id_str: String = str(def.get("id", ""))
    var status_label: Label = null
    var is_pair := str(def.get("pair_id", "")) != ""
    var is_chosen := GameState.get_upgrade_level(id_str) > 0 and is_pair
    if is_chosen:
        status_label = Label.new()
        status_label.text = "CHOSEN"
        status_label.add_theme_color_override("font_color", Color(0.2, 0.95, 0.4, 1.0))
        vbox.add_child(status_label)

    var name_label := Label.new()
    name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var level: int = GameState.get_upgrade_level(id_str)
    var max_level: int = int(def.get("max_level", 1))
    var level_text: String = ""
    if max_level < 0:
        level_text = " (Lv %d)" % level
    elif max_level > 1:
        level_text = " (Lv %d/%d)" % [level, max_level]
    var name_text: String = str(def.get("name", "Upgrade"))
    name_label.text = "%s%s" % [name_text, level_text]
    vbox.add_child(name_label)

    var desc_label := Label.new()
    desc_label.text = str(def.get("desc", ""))
    desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
    desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vbox.add_child(desc_label)

    var buy_btn := Button.new()
    buy_btn.text = _get_upgrade_button_text(def)
    var lock_reason := GameState.get_upgrade_lock_reason(id_str)
    buy_btn.disabled = lock_reason != ""
    if is_chosen:
        stripe.color = Color(0.0, 0.95, 0.25, 1.0)
        name_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.75, 1.0))
        desc_label.add_theme_color_override("font_color", Color(0.65, 1.0, 0.75, 1.0))
        buy_btn.text = "Chosen"
        buy_btn.disabled = true
        buy_btn.modulate = Color(0.0, 0.95, 0.25, 1.0)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0, 0, 0, 0)
        style.border_width_left = 3
        style.border_width_right = 3
        style.border_width_top = 3
        style.border_width_bottom = 3
        style.border_color = Color(0.0, 0.95, 0.25, 1.0)
        card.add_theme_stylebox_override("panel", style)
    elif lock_reason == "Locked (other chosen)":
        stripe.color = Color(0.5, 0.5, 0.5, 1.0)
        buy_btn.modulate = Color(0.7, 0.7, 0.7, 1.0)
        card.remove_theme_stylebox_override("panel")
    else:
        card.remove_theme_stylebox_override("panel")
    buy_btn.pressed.connect(_on_buy_pressed.bind(id_str))
    hbox.add_child(buy_btn)

    return card

func _get_upgrade_button_text(def: Dictionary) -> String:
    var id := str(def.get("id", ""))
    var reason := GameState.get_upgrade_lock_reason(id)
    var cost := GameState.get_upgrade_cost(id)
    if reason == "":
        return "Buy ($%d)" % cost
    if reason.begins_with("Need"):
        return reason
    return reason

func _on_buy_pressed(id: String) -> void:
    GameState.purchase_upgrade(id)
