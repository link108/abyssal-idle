extends PanelContainer

signal make_tin_requested

const OPTIONS_PATH := "res://data/raw/cannery_options.json"

@onready var method_select := $Control/MethodSelect
@onready var ingredient_select := $Control/IngredientSelect
@onready var garlic_label := $Control/GarlicCountLabel
@onready var make_tin_button := $Control/MakeTinButton
@onready var make_tin_progress := $Control/MakeTinButton/MakeTinProgress
@onready var last_made_label := $Control/LastMadeLabel

var methods: Array = []
var ingredients: Array = []

func _ready() -> void:
    _load_options()
    _populate_options()
    GameState.changed.connect(_refresh_counts)
    _refresh_counts()
    make_tin_progress.show_percentage = false
    method_select.item_selected.connect(_on_method_selected)
    ingredient_select.item_selected.connect(_on_ingredient_selected)
    _sync_selection_to_game_state()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    _update_cooldown_ui()

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _on_make_tin_button_pressed() -> void:
    var method_id: String = _get_selected_id(method_select, "raw")
    var ingredient_id: String = _get_selected_id(ingredient_select, "none")
    var made: bool = GameState.try_make_tin(method_id, ingredient_id)
    if made:
        last_made_label.text = "Made: %s" % GameState.format_recipe(method_id, ingredient_id)
    make_tin_requested.emit()
    _refresh_counts()

func _load_options() -> void:
    if not FileAccess.file_exists(OPTIONS_PATH):
        return
    var file := FileAccess.open(OPTIONS_PATH, FileAccess.READ)
    var raw := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    methods = parsed.get("methods", [])
    ingredients = parsed.get("ingredients", [])

func _populate_options() -> void:
    method_select.clear()
    ingredient_select.clear()
    for m in methods:
        if typeof(m) == TYPE_DICTIONARY:
            method_select.add_item(str(m.get("name", "Method")))
            method_select.set_item_metadata(method_select.item_count - 1, m.get("id", "raw"))
    for i in ingredients:
        if typeof(i) == TYPE_DICTIONARY:
            ingredient_select.add_item(str(i.get("name", "Ingredient")))
            ingredient_select.set_item_metadata(ingredient_select.item_count - 1, i.get("id", "none"))

func _get_selected_id(option: OptionButton, fallback: String) -> String:
    if option.item_count <= 0:
        return fallback
    var idx: int = option.selected
    var meta: Variant = option.get_item_metadata(idx)
    if meta == null:
        return fallback
    return str(meta)

func _refresh_counts() -> void:
    garlic_label.text = "Garlic: %d" % GameState.garlic_count


func _update_cooldown_ui() -> void:
    var ready: bool = GameState.can_make_tin()
    make_tin_button.disabled = not ready
    make_tin_button.modulate = Color(1, 1, 1, 1) if ready else Color(0.6, 0.6, 0.6, 1)
    var total: float = GameState.get_tin_make_time()
    var remaining: float = GameState.tin_cooldown_remaining
    if total <= 0.0:
        make_tin_progress.value = 1.0
        make_tin_button.text = "Make tin"
    else:
        var progress: float = 1.0 - (remaining / total)
        var clamped: float = clamp(progress, 0.0, 1.0)
        make_tin_progress.value = clamped
        var pct: int = int(round(clamped * 100.0))
        if ready or pct >= 100:
            make_tin_button.text = "Make tin"
        else:
            make_tin_button.text = "%d%%" % pct


func _on_method_selected(_index: int) -> void:
    _sync_selection_to_game_state()

func _on_ingredient_selected(_index: int) -> void:
    _sync_selection_to_game_state()

func _sync_selection_to_game_state() -> void:
    var method_id: String = _get_selected_id(method_select, "raw")
    var ingredient_id: String = _get_selected_id(ingredient_select, "none")
    GameState.set_tin_selection(method_id, ingredient_id)
