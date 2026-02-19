extends PanelContainer

signal load_requested
signal new_requested

@onready var load_button := $Control/LoadButton

func set_has_save(has_save: bool) -> void:
    load_button.disabled = not has_save
    load_button.visible = has_save

func _on_load_button_pressed() -> void:
    load_requested.emit()

func _on_new_button_pressed() -> void:
    new_requested.emit()
