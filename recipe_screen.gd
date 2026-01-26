extends PanelContainer

@export var columns: int = 5
@export var rows: int = 4

@onready var grid := $Control/ScrollContainer/Grid

var slot_style := StyleBoxFlat.new()

func _ready() -> void:
    _setup_style()
    _refresh()

func _setup_style() -> void:
    slot_style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
    slot_style.border_color = Color(0.35, 0.35, 0.4, 1)
    slot_style.border_width_left = 1
    slot_style.border_width_right = 1
    slot_style.border_width_top = 1
    slot_style.border_width_bottom = 1
    slot_style.corner_radius_top_left = 6
    slot_style.corner_radius_top_right = 6
    slot_style.corner_radius_bottom_left = 6
    slot_style.corner_radius_bottom_right = 6

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _on_visibility_changed() -> void:
    if visible:
        _refresh()

func _refresh() -> void:
    for child in grid.get_children():
        child.queue_free()
    grid.columns = columns

    var recipes: Array = GameState.get_recipe_list()
    var total_slots: int = columns * rows
    var count: int = min(recipes.size(), total_slots)

    for i in range(count):
        var label: String = str(recipes[i])
        grid.add_child(_make_slot(label))

    for _i in range(total_slots - count):
        grid.add_child(_make_slot(""))

func _make_slot(text: String) -> Control:
    var slot := PanelContainer.new()
    slot.custom_minimum_size = Vector2(72, 72)
    slot.add_theme_stylebox_override("panel", slot_style)

    var label := Label.new()
    label.text = text
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.custom_minimum_size = Vector2(64, 64)
    slot.add_child(label)
    return slot
