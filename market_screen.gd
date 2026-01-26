extends PanelContainer

@export var red_style: StyleBoxFlat
@export var green_style: StyleBoxFlat
@onready var buttons := [
    $Control/LeftPanel/SellButtons/SellFishButton,
    $Control/LeftPanel/SellButtons/SellTinsButton
]
@onready var qty_buttons := [
    $Control/RightPanel/QtyButtons/Qty1,
    $Control/RightPanel/QtyButtons/Qty5,
    $Control/RightPanel/QtyButtons/Qty10,
    $Control/RightPanel/QtyButtons/Qty25,
    $Control/RightPanel/QtyButtons/Qty50,
    $Control/RightPanel/QtyButtons/Qty100
]
@onready var garlic_button := $Control/RightPanel/ItemGrid/GarlicSlot/GarlicButton
@onready var garlic_slot := $Control/RightPanel/ItemGrid/GarlicSlot
@onready var hover_label := $Control/RightPanel/HoverLabel
@onready var garlic_count_label := $Control/RightPanel/GarlicCountLabel

var _buy_qty: int = 1

func _ready() -> void:
    for b in buttons:
        b.toggled.connect(_on_any_toggled)
    _setup_qty_buttons()
    _setup_item_slot()
    _refresh_styles()
    GameState.changed.connect(_refresh_counts)
    _refresh_counts()

func _on_any_toggled(_pressed: bool) -> void:
    _refresh_styles()

func _refresh_styles() -> void:
    for b in buttons:
        var style := green_style if b.button_pressed else red_style
        b.add_theme_stylebox_override("normal", style)
        b.add_theme_stylebox_override("hover", style)
        b.add_theme_stylebox_override("pressed", style)
        b.add_theme_stylebox_override("hover_pressed", style)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_close_button_pressed() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()


func _on_sell_fish_button_pressed() -> void:
    GameState.set_sell_mode(GameState.SellMode.FISH)


func _on_sell_tins_button_pressed() -> void:
    GameState.set_sell_mode(GameState.SellMode.TINS)

func _setup_qty_buttons() -> void:
    var group := ButtonGroup.new()
    for b in qty_buttons:
        b.button_group = group
        b.pressed.connect(_on_qty_button_pressed.bind(b))
    _buy_qty = 1

func _on_qty_button_pressed(button: Button) -> void:
    var qty := int(button.text)
    _buy_qty = max(1, qty)

func _setup_item_slot() -> void:
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
    garlic_slot.add_theme_stylebox_override("panel", style)
    garlic_button.mouse_entered.connect(_on_garlic_hover)
    garlic_button.mouse_exited.connect(_on_item_hover_exit)

func _on_garlic_button_pressed() -> void:
    if not GameState.buy_garlic(_buy_qty):
        _flash_slot(garlic_slot)

func _on_garlic_hover() -> void:
    hover_label.text = "Garlic ($%d)" % GameState.GARLIC_PRICE

func _on_item_hover_exit() -> void:
    hover_label.text = ""

func _refresh_counts() -> void:
    garlic_count_label.text = "Garlic: %d" % GameState.garlic_count

func _flash_slot(slot: Control) -> void:
    var original := slot.modulate
    slot.modulate = Color(1.0, 0.35, 0.35, 1.0)
    var tween := create_tween()
    tween.tween_property(slot, "modulate", original, 0.2)
