extends PanelContainer

const NODE_SIZE := Vector2(48, 48)
const BORDER_THICKNESS := 3

@onready var rep_label := $Control/RepLabel
@onready var graph := $Control/Graph
@onready var hover_title := $Control/HoverPanel/HoverVBox/HoverTitle
@onready var hover_body := $Control/HoverPanel/HoverVBox/HoverBody
@onready var hover_buy_button := $Control/HoverPanel/HoverVBox/HoverBuyButton

var _node_by_id: Dictionary = {}
var _hovered_id: String = ""
var _selected_id: String = ""

func _ready() -> void:
    GameState.skills_changed.connect(_refresh_nodes)
    GameState.reputation_changed.connect(_refresh_reputation)
    hover_buy_button.pressed.connect(_on_buy_selected_pressed)
    _build_graph()
    _refresh_reputation()
    _refresh_nodes()

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _refresh_reputation() -> void:
    rep_label.text = "Reputation: %d" % GameState.get_reputation()

func _build_graph() -> void:
    for child in graph.get_children():
        child.queue_free()
    _node_by_id.clear()

    var defs: Array = GameState.get_skill_defs()
    for def in defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        var node := _create_skill_node(def)
        var pos_arr: Array = def.get("pos", [0, 0])
        var pos := Vector2(float(pos_arr[0]), float(pos_arr[1]))
        node.position = pos
        graph.add_child(node)
        _node_by_id[str(def.get("id", ""))] = node

    var edges: Array = []
    for def in defs:
        if typeof(def) != TYPE_DICTIONARY:
            continue
        var id_str: String = str(def.get("id", ""))
        var reqs: Array = def.get("requires", [])
        for req in reqs:
            var from_id := str(req)
            if not _node_by_id.has(from_id):
                continue
            var from_node: Control = _node_by_id[from_id]
            var to_node: Control = _node_by_id[id_str]
            edges.append({
                "from": from_node.position + (from_node.size * 0.5),
                "to": to_node.position + (to_node.size * 0.5)
            })
    graph.set_edges(edges)

func _refresh_nodes() -> void:
    for id_str in _node_by_id.keys():
        var node: Control = _node_by_id[id_str]
        _update_node_state(node, id_str)
    _refresh_details_panel()

func _create_skill_node(def: Dictionary) -> Control:
    var container := Control.new()
    container.custom_minimum_size = NODE_SIZE
    container.size = NODE_SIZE

    var border := ColorRect.new()
    border.anchor_right = 1.0
    border.anchor_bottom = 1.0
    border.color = Color(0.2, 0.2, 0.2, 1.0)
    border.mouse_filter = Control.MOUSE_FILTER_IGNORE
    container.add_child(border)

    var icon := ColorRect.new()
    icon.color = _color_for_id(str(def.get("id", "")))
    icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    icon.position = Vector2(BORDER_THICKNESS, BORDER_THICKNESS)
    icon.size = NODE_SIZE - Vector2(BORDER_THICKNESS * 2, BORDER_THICKNESS * 2)
    container.add_child(icon)

    var btn := Button.new()
    btn.text = ""
    btn.flat = true
    btn.anchor_right = 1.0
    btn.anchor_bottom = 1.0
    btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
    container.add_child(btn)

    var id_str: String = str(def.get("id", ""))
    btn.pressed.connect(_on_skill_selected.bind(id_str))
    btn.mouse_entered.connect(_on_skill_hovered.bind(id_str))
    btn.mouse_exited.connect(_on_skill_hovered.bind(""))

    container.set_meta("icon", icon)
    container.set_meta("border", border)
    container.set_meta("button", btn)
    return container

func _update_node_state(node: Control, id_str: String) -> void:
    var def: Dictionary = GameState.get_skill_def(id_str)
    var reason := GameState.get_skill_lock_reason(id_str)
    var btn: Button = node.get_meta("button", null)
    if btn != null:
        btn.tooltip_text = _format_tooltip(def, reason)
    _apply_lock_style(node, id_str, reason)

func _apply_lock_style(node: Control, id_str: String, reason: String) -> void:
    var icon: ColorRect = node.get_meta("icon", null)
    var border: ColorRect = node.get_meta("border", null)
    if icon == null or border == null:
        return
    if GameState.is_skill_owned(id_str):
        border.color = Color(0.2, 0.8, 0.3, 1.0)
        icon.color = _color_for_id(id_str).lerp(Color(0.9, 0.95, 0.9, 1.0), 0.15)
        return
    if _selected_id == id_str:
        border.color = Color(0.95, 0.85, 0.2, 1.0)
    elif reason != "":
        border.color = Color(0.35, 0.35, 0.35, 1.0)
    else:
        border.color = Color(0.1, 0.1, 0.1, 1.0)
    if reason != "":
        icon.color = _color_for_id(id_str).lerp(Color(0.2, 0.2, 0.2, 1.0), 0.6)
    else:
        icon.color = _color_for_id(id_str)

func _refresh_details_panel() -> void:
    if _selected_id != "":
        var def: Dictionary = GameState.get_skill_def(_selected_id)
        var reason := GameState.get_skill_lock_reason(_selected_id)
        _set_details(def, reason)
        return
    if _hovered_id != "":
        var def_h: Dictionary = GameState.get_skill_def(_hovered_id)
        var reason_h := GameState.get_skill_lock_reason(_hovered_id)
        _set_details(def_h, reason_h)
        return
    hover_title.text = "Hover a skill"
    hover_body.text = "Details will appear here."
    hover_buy_button.visible = false

func _format_tooltip(def: Dictionary, reason: String) -> String:
    var cost := int(def.get("cost", 0))
    var base := "%s\nCost: %d rep" % [str(def.get("name", "Skill")), cost]
    var effects := _format_effects(def)
    if reason != "" and reason != "Owned":
        var reqs := _format_requirements(def)
        if reqs != "":
            return "%s\n%s\n%s\n%s" % [base, effects, reason, reqs]
        return "%s\n%s\n%s" % [base, effects, reason]
    return "%s\n%s" % [base, effects]

func _format_effects(def: Dictionary) -> String:
    var effects: Array = def.get("effects", [])
    if effects.is_empty():
        return "No effects"
    var lines: Array = []
    for effect in effects:
        if typeof(effect) != TYPE_DICTIONARY:
            continue
        var t: String = str(effect.get("type", ""))
        var v = effect.get("value", 0)
        lines.append(_format_effect_line(t, v))
    return "\n".join(lines)

func _format_effect_line(effect_type: String, value) -> String:
    match effect_type:
        "fish_sell_add":
            return "Fish sell +%d" % int(value)
        "tin_sell_add":
            return "Tin sell +%d" % int(value)
        "fish_sell_count_add":
            return "Fish sold/tick +%d" % int(value)
        "catch_add":
            return "Catch +%d" % int(value)
        "green_zone_add_pct":
            return "Green zone +%d%%" % int(round(float(value) * 100.0))
        "tin_time_add":
            var secs := float(value)
            if secs < 0.0:
                return "Tin time %0.2fs" % secs
            return "Tin time +%0.2fs" % secs
        "ocean_pressure_mult":
            return "Ocean pressure %d%%" % int(round(float(value) * 100.0))
        "ocean_regen_mult":
            return "Ocean regen +%d%%" % int(round(float(value) * 100.0))
        "reputation_gain_mult":
            return "Reputation gain +%d%%" % int(round(float(value) * 100.0))
        _:
            return "%s: %s" % [effect_type, str(value)]

func _on_skill_hovered(id_str: String) -> void:
    _hovered_id = id_str
    _refresh_details_panel()

func _on_skill_selected(id_str: String) -> void:
    _selected_id = id_str
    _refresh_nodes()

func _set_details(def: Dictionary, reason: String) -> void:
    hover_title.text = str(def.get("name", "Skill"))
    var cost := int(def.get("cost", 0))
    var lines := [
        "Cost: %d rep" % cost,
        _format_effects(def)
    ]
    if reason != "" and reason != "Owned":
        lines.append(reason)
        var reqs := _format_requirements(def)
        if reqs != "":
            lines.append(reqs)
    hover_body.text = "\n".join(lines)

    if GameState.is_skill_owned(str(def.get("id", ""))):
        hover_buy_button.visible = true
        hover_buy_button.text = "Owned"
        hover_buy_button.disabled = true
        hover_buy_button.modulate = Color(0.6, 0.9, 0.6, 1.0)
        return
    if reason != "":
        hover_buy_button.visible = true
        hover_buy_button.text = reason
        hover_buy_button.disabled = true
        hover_buy_button.modulate = Color(0.6, 0.6, 0.6, 1.0)
        return
    hover_buy_button.visible = true
    hover_buy_button.text = "Buy (%d rep)" % cost
    hover_buy_button.disabled = false
    hover_buy_button.modulate = Color(0.2, 0.9, 0.3, 1.0)

func _format_requirements(def: Dictionary) -> String:
    var reqs: Array = def.get("requires", [])
    if reqs.is_empty():
        return ""
    var missing: Array = []
    for req in reqs:
        var req_id := str(req)
        if not GameState.is_skill_owned(req_id):
            var req_def: Dictionary = GameState.get_skill_def(req_id)
            missing.append(str(req_def.get("name", req_id)))
    if missing.is_empty():
        return ""
    return "Requires: %s" % ", ".join(missing)

func _color_for_id(id_str: String) -> Color:
    var hash := 0
    for i in range(id_str.length()):
        hash = int((hash * 31 + id_str.unicode_at(i)) % 360)
    var hue := float(hash) / 360.0
    return Color.from_hsv(hue, 0.75, 0.95)

func _on_buy_selected_pressed() -> void:
    if _selected_id == "":
        return
    print("Buy pressed for skill:", _selected_id, "rep:", GameState.get_reputation())
    GameState.purchase_skill(_selected_id)
    _refresh_nodes()
    _refresh_reputation()
