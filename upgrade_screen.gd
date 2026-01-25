extends PanelContainer

@onready var upgrades_list := $Control/ScrollContainer/UpgradesList

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    GameState.changed.connect(_refresh)
    _refresh()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()


func _refresh() -> void:
    _rebuild_upgrade_list()

func _rebuild_upgrade_list() -> void:
    for child in upgrades_list.get_children():
        child.queue_free()

    var defs := GameState.get_upgrade_defs()
    for def in defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        if not GameState.can_show_upgrade(def):
            continue
        var card := _create_upgrade_card(def)
        upgrades_list.add_child(card)

func _create_upgrade_card(def: Dictionary) -> Control:
    var card := PanelContainer.new()
    card.custom_minimum_size = Vector2(0, 72)

    var hbox := HBoxContainer.new()
    hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    card.add_child(hbox)

    var vbox := VBoxContainer.new()
    vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    hbox.add_child(vbox)

    var name_label := Label.new()
    var level := GameState.get_upgrade_level(def.get("id", ""))
    var max_level := int(def.get("max_level", 1))
    var level_text := ""
    if max_level < 0:
        level_text = " (Lv %d)" % level
    elif max_level > 1:
        level_text = " (Lv %d/%d)" % [level, max_level]
    name_label.text = "%s%s" % [str(def.get("name", "Upgrade")), level_text]
    vbox.add_child(name_label)

    var desc_label := Label.new()
    desc_label.text = str(def.get("desc", ""))
    vbox.add_child(desc_label)

    var buy_btn := Button.new()
    buy_btn.text = _get_upgrade_button_text(def)
    buy_btn.disabled = not GameState.can_purchase_upgrade(def.get("id", ""))
    buy_btn.pressed.connect(_on_buy_pressed.bind(def.get("id", "")))
    hbox.add_child(buy_btn)

    return card

func _get_upgrade_button_text(def: Dictionary) -> String:
    var id := str(def.get("id", ""))
    if GameState.is_upgrade_maxed(id):
        return "Maxed"
    var cost := GameState.get_upgrade_cost(id)
    if GameState.can_purchase_upgrade(id):
        return "Buy ($%d)" % cost
    return "Need $%d" % cost

func _on_buy_pressed(id: String) -> void:
    GameState.purchase_upgrade(id)
