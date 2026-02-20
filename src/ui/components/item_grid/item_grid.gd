extends GridContainer

signal item_selected(item_id: String, payload: Dictionary)

@export var slot_size: Vector2 = Vector2(96, 96)
@export var base_bg_color: Color = Color(0.12, 0.12, 0.12, 0.9)
@export var base_border_color: Color = Color(0.3, 0.3, 0.3, 1)
@export var selected_border_color: Color = Color(0.2, 0.9, 0.3, 1.0)
@export var selected_glow_color: Color = Color(0.2, 0.9, 0.3, 0.3)

var _slot_style := StyleBoxFlat.new()
var _selected_style := StyleBoxFlat.new()

func _ready() -> void:
    _build_styles()

func _build_styles() -> void:
    _slot_style.bg_color = base_bg_color
    _slot_style.border_color = base_border_color
    _slot_style.border_width_left = 1
    _slot_style.border_width_right = 1
    _slot_style.border_width_top = 1
    _slot_style.border_width_bottom = 1
    _slot_style.corner_radius_top_left = 6
    _slot_style.corner_radius_top_right = 6
    _slot_style.corner_radius_bottom_left = 6
    _slot_style.corner_radius_bottom_right = 6

    _selected_style.bg_color = base_bg_color
    _selected_style.border_color = selected_border_color
    _selected_style.border_width_left = 2
    _selected_style.border_width_right = 2
    _selected_style.border_width_top = 2
    _selected_style.border_width_bottom = 2
    _selected_style.corner_radius_top_left = 6
    _selected_style.corner_radius_top_right = 6
    _selected_style.corner_radius_bottom_left = 6
    _selected_style.corner_radius_bottom_right = 6
    _selected_style.shadow_color = selected_glow_color
    _selected_style.shadow_size = 6
    _selected_style.shadow_offset = Vector2(0, 0)

func set_items(items: Array, selected_id: String = "") -> void:
    for child in get_children():
        child.queue_free()

    for entry in items:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var entry_dict: Dictionary = entry
        var item_id: String = str(entry_dict.get("id", ""))
        if item_id == "":
            continue
        var label: String = str(entry_dict.get("label", item_id))
        var count: int = int(entry_dict.get("count", 0))
        var show_count: bool = true if not entry_dict.has("show_count") else bool(entry_dict.get("show_count", true))
        var disabled: bool = bool(entry_dict.get("disabled", false))
        var tooltip: String = str(entry_dict.get("tooltip", ""))
        var modulate_color: Color = Color(1, 1, 1, 1)
        if entry_dict.has("modulate") and typeof(entry_dict.get("modulate", null)) == TYPE_COLOR:
            modulate_color = entry_dict.get("modulate", modulate_color)
        var payload: Dictionary = {}
        if entry_dict.has("payload") and typeof(entry_dict.get("payload", null)) == TYPE_DICTIONARY:
            payload = entry_dict.get("payload", {})
        var is_selected: bool = selected_id != "" and item_id == selected_id
        var icon_texture: Texture2D = null
        if entry_dict.has("icon") and entry_dict.get("icon") is Texture2D:
            icon_texture = entry_dict.get("icon")
        elif entry_dict.has("icon_path"):
            var icon_path := str(entry_dict.get("icon_path", ""))
            if icon_path != "":
                var loaded := load(icon_path)
                if loaded is Texture2D:
                    icon_texture = loaded

        var slot := PanelContainer.new()
        slot.custom_minimum_size = slot_size
        slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
        slot.add_theme_stylebox_override("panel", _selected_style if is_selected else _slot_style)

        if icon_texture != null:
            var icon_rect := TextureRect.new()
            icon_rect.texture = icon_texture
            icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
            icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            icon_rect.anchor_left = 0.0
            icon_rect.anchor_top = 0.0
            icon_rect.anchor_right = 1.0
            icon_rect.anchor_bottom = 1.0
            icon_rect.offset_left = 6.0
            icon_rect.offset_top = 6.0
            icon_rect.offset_right = -6.0
            icon_rect.offset_bottom = -6.0
            icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
            slot.add_child(icon_rect)

        var button := Button.new()
        button.layout_mode = 1
        button.anchors_preset = Control.PRESET_FULL_RECT
        button.clip_text = true
        button.autowrap_mode = TextServer.AUTOWRAP_OFF
        button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        button.alignment = HORIZONTAL_ALIGNMENT_CENTER
        button.disabled = disabled
        button.modulate = modulate_color
        button.text = "%s x%d" % [label, count] if show_count else label
        if tooltip != "":
            button.tooltip_text = tooltip
        if not disabled:
            button.pressed.connect(_on_item_pressed.bind(item_id, payload))

        slot.add_child(button)
        add_child(slot)

func _on_item_pressed(item_id: String, payload: Dictionary) -> void:
    item_selected.emit(item_id, payload)
