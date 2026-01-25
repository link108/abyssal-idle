extends PanelContainer

@export var red_style: StyleBoxFlat
@export var green_style: StyleBoxFlat
@onready var buttons := [$Control/SellFishButton, $Control/SellTinsButton]

func _ready() -> void:
    for b in buttons:
          b.toggled.connect(_on_any_toggled)
    _refresh_styles()

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
