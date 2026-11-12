extends PanelContainer

# Full experiment log over the cannery: sort, filter by recipe, inspect an
# attempt and load it back into the cannery ("Refine this").

signal attempt_applied

const SORTS := [["newest", "Newest"], ["score", "Highest score"]]
const CLOSEST_MARK := "★"

var _sort_select: OptionButton
var _filter_select: OptionButton
var _rows: VBoxContainer
var _detail_title: Label
var _detail_inputs: Label
var _detail_lines: Label
var _refine_button: Button
var _selected_attempt_id := -1


func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    offset_left = 40.0
    offset_top = 40.0
    offset_right = -40.0
    offset_bottom = -40.0
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.06, 0.07, 0.09, 1)
    style.border_color = Color(0.3, 0.3, 0.35, 1)
    style.set_border_width_all(1)
    style.set_corner_radius_all(6)
    style.set_content_margin_all(12)
    add_theme_stylebox_override("panel", style)
    _build()
    hide()


func open() -> void:
    _rebuild_filter()
    _rebuild_rows()
    show()


func _build() -> void:
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 10)
    add_child(root)

    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation", 8)
    root.add_child(header)
    var title := _label("Experiment Log", false)
    title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    header.add_child(title)
    header.add_child(_label("Sort", false))
    _sort_select = OptionButton.new()
    for sort in SORTS:
        _sort_select.add_item(str(sort[1]))
    _sort_select.item_selected.connect(func(_i): _rebuild_rows())
    header.add_child(_sort_select)
    header.add_child(_label("Recipe", false))
    _filter_select = OptionButton.new()
    _filter_select.custom_minimum_size = Vector2(240, 0)
    _filter_select.item_selected.connect(func(_i): _rebuild_rows())
    header.add_child(_filter_select)
    var close := Button.new()
    close.text = "Close"
    close.pressed.connect(hide)
    header.add_child(close)

    var body := HBoxContainer.new()
    body.size_flags_vertical = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 16)
    root.add_child(body)

    var scroll := ScrollContainer.new()
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_stretch_ratio = 1.6
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    body.add_child(scroll)
    _rows = VBoxContainer.new()
    _rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(_rows)

    var detail := VBoxContainer.new()
    detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    detail.add_theme_constant_override("separation", 8)
    body.add_child(detail)
    _detail_title = _label("Select an attempt")
    detail.add_child(_detail_title)
    _detail_inputs = _label("")
    detail.add_child(_detail_inputs)
    _detail_lines = _label("")
    _detail_lines.add_theme_color_override("font_color", Color(0.75, 0.85, 1.0, 1))
    detail.add_child(_detail_lines)
    _refine_button = Button.new()
    _refine_button.text = "Refine this"
    _refine_button.disabled = true
    _refine_button.pressed.connect(_on_refine_pressed)
    detail.add_child(_refine_button)
    detail.add_child(_label("%s = closest so far for that recipe" % CLOSEST_MARK))


func _label(text: String, wrap: bool = true) -> Label:
    var label := Label.new()
    label.text = text
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label


func _rebuild_filter() -> void:
    var previous := _selected_filter_id()
    _filter_select.clear()
    _filter_select.add_item("All")
    _filter_select.set_item_metadata(0, "")
    for silhouette_id in GameState.get_experiment_log_silhouette_ids():
        _filter_select.add_item(GameState.get_silhouette_label(str(silhouette_id)))
        _filter_select.set_item_metadata(_filter_select.item_count - 1, str(silhouette_id))
        if str(silhouette_id) == previous:
            _filter_select.select(_filter_select.item_count - 1)


func _selected_filter_id() -> String:
    if _filter_select == null or _filter_select.item_count == 0 or _filter_select.selected < 0:
        return ""
    return str(_filter_select.get_item_metadata(_filter_select.selected))


func _rebuild_rows() -> void:
    for child in _rows.get_children():
        child.queue_free()
    var sort := str(SORTS[maxi(0, _sort_select.selected)][0])
    var entries: Array = GameState.get_experiment_log_view(sort, _selected_filter_id())
    if entries.is_empty():
        _rows.add_child(_label("No experiments yet."))
    for entry in entries:
        var attempt_id := int(entry.get("attempt_id", 0))
        var row := Button.new()
        row.alignment = HORIZONTAL_ALIGNMENT_LEFT
        row.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
        row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.toggle_mode = true
        row.button_pressed = attempt_id == _selected_attempt_id
        row.text = "#%d  %3d%% %s  %s" % [
            attempt_id,
            int(entry.get("score", 0)),
            CLOSEST_MARK if bool(entry.get("is_closest", false)) else " ",
            GameState.format_experiment_inputs(entry)
        ]
        row.pressed.connect(_select_attempt.bind(attempt_id))
        _rows.add_child(row)
    _show_detail()


func _select_attempt(attempt_id: int) -> void:
    _selected_attempt_id = attempt_id
    for row in _rows.get_children():
        if row is Button:
            row.button_pressed = row.text.begins_with("#%d " % attempt_id)
    _show_detail()


func _show_detail() -> void:
    var detail: Dictionary = GameState.get_experiment_attempt_detail(_selected_attempt_id)
    if detail.is_empty():
        _detail_title.text = "Select an attempt"
        _detail_inputs.text = "Pick an experiment to see how close it came."
        _detail_lines.text = ""
        _refine_button.disabled = true
        return
    var closest := "  %s closest so far" % CLOSEST_MARK if bool(detail.get("is_closest", false)) else ""
    _detail_title.text = "Attempt #%d: %d%%%s" % [int(detail["attempt_id"]), int(detail["score"]), closest]
    _detail_inputs.text = "Tried: %s\nResult: %s\nClosest recipe: %s" % [detail["inputs"], detail["result"], detail["target"]]
    _detail_lines.text = "\n".join(detail.get("lines", []))
    _refine_button.disabled = false


func _on_refine_pressed() -> void:
    if not GameState.apply_attempt_to_selection(_selected_attempt_id):
        return
    hide()
    attempt_applied.emit()
