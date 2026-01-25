extends PanelContainer

signal fish_caught(amount: int)

@export var cursor_speed: float = 420.0
@onready var bar_container := $Root/Minigame/BarContainer
@onready var green_zone := $Root/Minigame/BarContainer/BarGreen
@onready var cursor := $Root/Minigame/BarContainer/Cursor
@onready var result_label := $Root/Minigame/ResultLabel

var _cursor_x: float = 0.0
var _bar_width: float = 0.0
var _cursor_width: float = 0.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
    _rng.randomize()
    _bar_width = bar_container.size.x
    _cursor_width = cursor.size.x
    _reset_cursor()

func _process(delta: float) -> void:
    _bar_width = bar_container.size.x
    _cursor_x += cursor_speed * delta
    if _cursor_x > _bar_width - _cursor_width:
        _cursor_x = 0.0
    cursor.position.x = _cursor_x

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
        _attempt_catch()
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _attempt_catch()

func _attempt_catch() -> void:
    var cursor_center: float = _cursor_x + (_cursor_width * 0.5)
    var green_start: float = green_zone.position.x
    var green_end: float = green_zone.position.x + green_zone.size.x
    if cursor_center >= green_start and cursor_center <= green_end:
        fish_caught.emit(1)
        _show_result(true)
    else:
        _show_result(false)
    _reset_cursor()

func _reset_cursor() -> void:
    _cursor_x = 0.0
    cursor.position.x = _cursor_x
    _randomize_green_zone()

func _randomize_green_zone() -> void:
    _bar_width = bar_container.size.x
    var green_width: float = green_zone.size.x
    var max_x: float = max(0.0, _bar_width - green_width)
    green_zone.position.x = _rng.randf_range(0.0, max_x)

func _show_result(success: bool) -> void:
    result_label.visible = true
    result_label.modulate.a = 1.0
    if success:
        result_label.text = "Nice catch!"
        result_label.modulate = Color(0.2, 0.9, 0.2, 1)
    else:
        result_label.text = "You scared the fish away!"
        result_label.modulate = Color(0.9, 0.2, 0.2, 1)
    var tween := create_tween()
    tween.tween_property(result_label, "modulate:a", 0.0, 0.6)
    tween.finished.connect(func(): result_label.visible = false)

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()
