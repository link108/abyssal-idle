extends PanelContainer

@onready var destination_list := $Control/DestinationList

func _ready() -> void:
    GameState.changed.connect(_refresh)
    GameState.crew_trip_updated.connect(_refresh)
    visibility_changed.connect(_refresh)
    _refresh()

func _refresh() -> void:
    if not is_visible_in_tree():
        return
    for child in destination_list.get_children():
        child.queue_free()
    var title := Label.new()
    title.text = "Send the crew to:"
    destination_list.add_child(title)
    for def in GameState.get_destination_defs():
        if typeof(def) != TYPE_DICTIONARY:
            continue
        destination_list.add_child(_make_destination_button(def))
    var hint := Label.new()
    hint.text = "Fishing the same grounds trip after trip adds ocean pressure. Rotate to let them recover."
    hint.autowrap_mode = TextServer.AUTOWRAP_WORD
    hint.modulate = Color(0.8, 0.8, 0.8, 1.0)
    destination_list.add_child(hint)

func _make_destination_button(def: Dictionary) -> Button:
    var destination_id := str(def.get("destination_id", ""))
    var button := Button.new()
    button.toggle_mode = true
    button.button_pressed = destination_id == GameState.crew_destination_id
    button.alignment = HORIZONTAL_ALIGNMENT_LEFT
    button.autowrap_mode = TextServer.AUTOWRAP_WORD
    var lines: Array = [str(def.get("display_name", destination_id)), _format_stats(def)]
    var fatigue := GameState.get_next_trip_fatigue_bonus(destination_id)
    if fatigue > 0.0:
        lines.append("Fatigue +%d%% pressure" % int(round(fatigue * 100.0)))
    var lock_reason := GameState.get_destination_lock_reason(destination_id)
    if lock_reason != "":
        lines.append(lock_reason)
        button.disabled = true
    else:
        button.tooltip_text = str(def.get("description", ""))
    button.text = "\n".join(lines)
    button.pressed.connect(_on_destination_pressed.bind(destination_id))
    return button

func _format_stats(def: Dictionary) -> String:
    return "Trip time x%.2f · Catch x%.2f · Ocean pressure x%.2f" % [
        float(def.get("trip_duration_mult", 1.0)),
        float(def.get("catch_mult", 1.0)),
        float(def.get("ocean_pressure_mult", 1.0))
    ]

func _on_destination_pressed(destination_id: String) -> void:
    GameState.select_crew_destination(destination_id)
    _refresh()

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()
