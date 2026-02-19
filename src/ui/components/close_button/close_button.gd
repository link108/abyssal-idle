extends Button

signal close_requested


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pressed.connect(_on_pressed)
    pass # Replace with function body.

func _on_pressed() -> void:
    close_requested.emit()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass
