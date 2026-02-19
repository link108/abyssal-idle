extends PanelContainer

const CATEGORY_FISH := "fish"
const CATEGORY_RECIPES := "recipes"
const SLOT_WIDTH := 96
const SLOT_HEIGHT := 96

@export var columns: int = 5

@onready var fish_button: Button = $Control/MainRow/Sidebar/SidebarMargin/SidebarVBox/FishButton
@onready var recipes_button: Button = $Control/MainRow/Sidebar/SidebarMargin/SidebarVBox/RecipesButton
@onready var category_title: Label = $Control/MainRow/Content/ContentMargin/ContentVBox/CategoryTitle
@onready var grid_scroll: ScrollContainer = $Control/MainRow/Content/ContentMargin/ContentVBox/BodyRow/GridScroll
@onready var item_grid: GridContainer = $Control/MainRow/Content/ContentMargin/ContentVBox/BodyRow/GridScroll/ItemGrid
@onready var detail_panel: PanelContainer = $Control/MainRow/Content/ContentMargin/ContentVBox/BodyRow/DetailPanel
@onready var detail_name: Label = $Control/MainRow/Content/ContentMargin/ContentVBox/BodyRow/DetailPanel/DetailMargin/DetailVBox/DetailName
@onready var detail_meta: Label = $Control/MainRow/Content/ContentMargin/ContentVBox/BodyRow/DetailPanel/DetailMargin/DetailVBox/DetailMeta
@onready var detail_desc: Label = $Control/MainRow/Content/ContentMargin/ContentVBox/BodyRow/DetailPanel/DetailMargin/DetailVBox/DetailDescription
@onready var detail_extra: Label = $Control/MainRow/Content/ContentMargin/ContentVBox/BodyRow/DetailPanel/DetailMargin/DetailVBox/DetailExtra

var _slot_style := StyleBoxFlat.new()
var _selected_slot_style := StyleBoxFlat.new()
var _selected_category: String = CATEGORY_FISH
var _fish_defs: Array = []
var _recipe_defs: Array = []
var _selected_item_id: String = ""

func _ready() -> void:
    _setup_style()
    _load_data()
    fish_button.pressed.connect(_on_fish_button_pressed)
    recipes_button.pressed.connect(_on_recipes_button_pressed)
    GameState.changed.connect(_refresh_visible_category)
    _set_category(CATEGORY_FISH)

func _notification(what: int) -> void:
    if what == NOTIFICATION_RESIZED and visible:
        _refresh_visible_category()

func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()

func _on_visibility_changed() -> void:
    if visible:
        _refresh_visible_category()

func _on_fish_button_pressed() -> void:
    _set_category(CATEGORY_FISH)

func _on_recipes_button_pressed() -> void:
    _set_category(CATEGORY_RECIPES)

func _set_category(category: String) -> void:
    _selected_category = category
    var is_fish := _selected_category == CATEGORY_FISH
    fish_button.disabled = is_fish
    recipes_button.disabled = not is_fish
    category_title.text = "Fish Collection" if is_fish else "Recipe Collection"
    _clear_detail()
    _refresh_visible_category()

func _setup_style() -> void:
    _slot_style.bg_color = Color(0.1, 0.12, 0.16, 0.9)
    _slot_style.border_color = Color(0.35, 0.35, 0.4, 1)
    _slot_style.border_width_left = 1
    _slot_style.border_width_right = 1
    _slot_style.border_width_top = 1
    _slot_style.border_width_bottom = 1
    _slot_style.corner_radius_top_left = 6
    _slot_style.corner_radius_top_right = 6
    _slot_style.corner_radius_bottom_left = 6
    _slot_style.corner_radius_bottom_right = 6

    _selected_slot_style.bg_color = Color(0.16, 0.2, 0.26, 0.95)
    _selected_slot_style.border_color = Color(0.45, 0.8, 1.0, 1.0)
    _selected_slot_style.border_width_left = 2
    _selected_slot_style.border_width_right = 2
    _selected_slot_style.border_width_top = 2
    _selected_slot_style.border_width_bottom = 2
    _selected_slot_style.corner_radius_top_left = 6
    _selected_slot_style.corner_radius_top_right = 6
    _selected_slot_style.corner_radius_bottom_left = 6
    _selected_slot_style.corner_radius_bottom_right = 6

func _load_data() -> void:
    _fish_defs = GameState.get_collection_fish_defs()
    _recipe_defs = GameState.get_collection_recipe_defs()

func _refresh_visible_category() -> void:
    for child in item_grid.get_children():
        child.queue_free()

    item_grid.columns = _get_fitting_columns()
    if _selected_category == CATEGORY_FISH:
        _rebuild_fish_grid()
    else:
        _rebuild_recipe_grid()
    _refresh_selected_detail_after_grid_rebuild()

func _get_fitting_columns() -> int:
    var available_width := int(grid_scroll.size.x)
    if available_width <= 0:
        return max(1, columns)
    var spacing := int(item_grid.get_theme_constant("h_separation"))
    var per_column := SLOT_WIDTH + spacing
    if per_column <= 0:
        return 1
    var fit: int = max(1, int(floor(float(available_width + spacing) / float(per_column))))
    return clampi(fit, 1, max(1, columns))

func _rebuild_fish_grid() -> void:
    for fish_def in _fish_defs:
        if typeof(fish_def) != TYPE_DICTIONARY:
            continue
        var discovered := _is_fish_discovered(fish_def)
        item_grid.add_child(_make_item_slot(fish_def, discovered, CATEGORY_FISH))

func _rebuild_recipe_grid() -> void:
    for recipe_def in _recipe_defs:
        if typeof(recipe_def) != TYPE_DICTIONARY:
            continue
        var discovered := _is_recipe_discovered(recipe_def)
        item_grid.add_child(_make_item_slot(recipe_def, discovered, CATEGORY_RECIPES))

func _make_item_slot(item_def: Dictionary, discovered: bool, category: String) -> Control:
    var button := Button.new()
    button.custom_minimum_size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
    button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    button.clip_text = true
    button.autowrap_mode = TextServer.AUTOWRAP_OFF
    button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    button.alignment = HORIZONTAL_ALIGNMENT_CENTER
    var item_id := _get_item_id(item_def, category)
    var is_selected := discovered and item_id != "" and item_id == _selected_item_id
    var style: StyleBoxFlat = _selected_slot_style if is_selected else _slot_style
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_stylebox_override("hover", style)
    button.add_theme_stylebox_override("pressed", style)

    var display_name := str(item_def.get("display_name", "Unknown"))
    var placeholder_name := "???"
    var hint_text := str(item_def.get("lore_hint", "Undiscovered."))

    if category == CATEGORY_RECIPES:
        var req_fish := str(item_def.get("required_fish_name", "an unknown fish"))
        hint_text = "Requires %s" % req_fish

    if discovered:
        button.text = display_name
        button.modulate = Color(1, 1, 1, 1)
        button.pressed.connect(_on_item_selected.bind(item_def, category))
    else:
        button.text = placeholder_name
        button.modulate = Color(0.65, 0.65, 0.65, 1)
        button.tooltip_text = hint_text

    return button

func _on_item_selected(item_def: Dictionary, category: String) -> void:
    if category == CATEGORY_FISH and not _is_fish_discovered(item_def):
        return
    if category == CATEGORY_RECIPES and not _is_recipe_discovered(item_def):
        return

    _selected_item_id = _get_item_id(item_def, category)
    detail_panel.visible = true
    if category == CATEGORY_FISH:
        _show_fish_detail(item_def)
    else:
        _show_recipe_detail(item_def)
    _refresh_visible_category()

func _show_fish_detail(fish_def: Dictionary) -> void:
    var fish_id := str(fish_def.get("fish_id", ""))
    var name_text := str(fish_def.get("display_name", "Unknown Fish"))
    var rarity := str(fish_def.get("rarity", "Unknown"))
    var biome := str(fish_def.get("biome", "Unknown biome"))
    var min_depth := int(fish_def.get("depth_min_m", 0))
    var max_depth := int(fish_def.get("depth_max_m", 0))
    var desc := str(fish_def.get("description", "No description."))
    var stats := GameState.get_fish_lifetime_stats(fish_id)

    detail_name.text = name_text
    detail_meta.text = "Rarity: %s\nBiome: %s\nDepth: %dm-%dm" % [rarity, biome, min_depth, max_depth]
    detail_desc.text = desc
    detail_extra.text = "Lifetime Caught: %d\nLifetime Sold: %d\nTins Produced: %d" % [
        int(stats.get("caught", 0)),
        int(stats.get("sold", 0)),
        int(stats.get("tins_produced", 0))
    ]

func _show_recipe_detail(recipe_def: Dictionary) -> void:
    var recipe_id := str(recipe_def.get("recipe_id", ""))
    var name_text := str(recipe_def.get("display_name", "Unknown Recipe"))
    var rarity := str(recipe_def.get("rarity", "Unknown"))
    var tier := int(recipe_def.get("tier", 0))
    var required_fish := str(recipe_def.get("required_fish_name", "Unknown fish"))
    var ingredients: Array = recipe_def.get("ingredients", [])
    var processes: Array = recipe_def.get("processes", [])
    var yield_count := int(recipe_def.get("yield", 0))
    var stats := GameState.get_recipe_lifetime_stats(recipe_id)

    detail_name.text = name_text
    detail_meta.text = "Rarity: %s\nTier: %d\nRequired Fish: %s" % [rarity, tier, required_fish]
    detail_desc.text = "Ingredients: %d items\nProcesses: %d steps\nYield: %d" % [ingredients.size(), processes.size(), yield_count]
    detail_extra.text = "Lifetime Produced: %d\nRevenue Generated: $%d" % [
        int(stats.get("produced", 0)),
        int(stats.get("revenue_generated", 0))
    ]

func _clear_detail() -> void:
    detail_panel.visible = true
    _selected_item_id = ""
    detail_name.text = "Select an entry"
    detail_meta.text = "Choose a discovered fish or recipe to view details."
    detail_desc.text = "Undiscovered entries stay hidden but provide hints."
    detail_extra.text = ""

func _is_fish_discovered(fish_def: Dictionary) -> bool:
    return GameState.is_fish_discovered(str(fish_def.get("fish_id", "")))

func _is_recipe_discovered(recipe_def: Dictionary) -> bool:
    return GameState.is_recipe_discovered(str(recipe_def.get("recipe_id", "")))

func _get_item_id(item_def: Dictionary, category: String) -> String:
    if category == CATEGORY_FISH:
        return str(item_def.get("fish_id", ""))
    return str(item_def.get("recipe_id", ""))

func _refresh_selected_detail_after_grid_rebuild() -> void:
    if _selected_item_id == "":
        return
    if _selected_category == CATEGORY_FISH:
        for fish_def in _fish_defs:
            if typeof(fish_def) != TYPE_DICTIONARY:
                continue
            if str(fish_def.get("fish_id", "")) != _selected_item_id:
                continue
            if not _is_fish_discovered(fish_def):
                _clear_detail()
                return
            _show_fish_detail(fish_def)
            return
    else:
        for recipe_def in _recipe_defs:
            if typeof(recipe_def) != TYPE_DICTIONARY:
                continue
            if str(recipe_def.get("recipe_id", "")) != _selected_item_id:
                continue
            if not _is_recipe_discovered(recipe_def):
                _clear_detail()
                return
            _show_recipe_detail(recipe_def)
            return
    _clear_detail()
