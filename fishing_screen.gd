extends PanelContainer

signal fish_caught(amount: int)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass



func _on_catch_button_pressed() -> void:
    fish_caught.emit(1)


func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()
