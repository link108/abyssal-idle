extends PanelContainer

signal make_tin_requested

const OPTIONS_PATH := "res://data/cannery_options.json"

@onready var method_select := $Control/MethodSelect
@onready var ingredient_select := $Control/IngredientSelect
@onready var garlic_label := $Control/GarlicCountLabel

var methods: Array = []
var ingredients: Array = []

func _ready() -> void:
    _load_options()
    _populate_options()
    GameState.changed.connect(_refresh_counts)
    _refresh_counts()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _on_make_tin_button_pressed() -> void:
    var method_id: String = _get_selected_id(method_select, "raw")
    var ingredient_id: String = _get_selected_id(ingredient_select, "none")
    GameState.make_tin_with(method_id, ingredient_id)
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
