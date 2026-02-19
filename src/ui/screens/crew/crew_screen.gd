extends PanelContainer

@onready var crew_list := $Control/CrewList

func _ready() -> void:
    _refresh()

func _refresh() -> void:
    crew_list.clear()
    crew_list.add_item("Deckhand (Default)")

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()
