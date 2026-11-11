extends "res://tests/headless/test_base.gd"

const RecipeTags = preload("res://src/data/recipe_tags.gd")
const METHODS := ["raw", "smoked"]


func run_tests(gs) -> void:
    var undiscoverable: Array = []
    var collisions: Array = []
    var too_many_addons: Array = []
    for recipe_def in gs.recipe_defs:
        var recipe_id := str(recipe_def.get("recipe_id", ""))
        if gs.get_recipe_addon_ids(recipe_def).size() > RecipeTags.MAX_RECIPE_ADDONS:
            too_many_addons.append(recipe_id)
        var own_def: Dictionary = gs.silhouette_defs_by_id.get(recipe_id, {})
        var best_own := 0
        var best_winner := ""
        for method_id in METHODS:
            var attempt := _selection_attempt(gs, recipe_def, method_id, true)
            var own_score := int(gs._score_attempt_against_silhouette(attempt, own_def)["score"])
            if own_score >= best_own:
                best_own = own_score
                best_winner = _winning_recipe(gs, attempt)
        if best_own < int(own_def.get("unlock_threshold", 75)):
            undiscoverable.append("%s (%d)" % [recipe_id, best_own])
        elif best_winner != recipe_id:
            collisions.append("%s -> %s" % [recipe_id, best_winner])

    check(undiscoverable.is_empty(), "every recipe is discoverable through the cannery selection %s" % str(undiscoverable))
    check(collisions.is_empty(), "every recipe's exact inputs match that recipe %s" % str(collisions))
    check(too_many_addons.is_empty(), "no recipe needs more than %d add-ons %s" % [RecipeTags.MAX_RECIPE_ADDONS, str(too_many_addons)])

    var trivial: Array = []
    for fish_def in gs.fish_defs:
        var fish_id := str(fish_def.get("fish_id", ""))
        for method_id in METHODS:
            var attempt: Dictionary = gs._build_craft_attempt(fish_id, method_id, [], ["tin_pack", "tin_seal"])
            var winner := _winning_recipe(gs, attempt)
            if winner != "":
                trivial.append("%s/%s -> %s" % [fish_id, method_id, winner])
    check(trivial.is_empty(), "no recipe is discoverable from a bare fish %s" % str(trivial))

    # Ingredients must matter: the right processes alone should rarely unlock.
    var processes_only: Array = []
    for recipe_def in gs.recipe_defs:
        var attempt := _selection_attempt(gs, recipe_def, "raw", false)
        if _winning_recipe(gs, attempt) == str(recipe_def.get("recipe_id", "")):
            processes_only.append(str(recipe_def.get("recipe_id", "")))
    check(processes_only.size() <= gs.recipe_defs.size() / 10, "at most 10%% of recipes unlock without add-ons %s" % str(processes_only))

    var display_scored: Array = []
    for silhouette_def in gs.silhouette_defs:
        for tag in gs._string_array(silhouette_def.get("required_tags", [])) + gs._string_array(silhouette_def.get("preferred_tags", [])):
            if RecipeTags.is_display_only(tag):
                display_scored.append("%s:%s" % [silhouette_def.get("silhouette_id", ""), tag])
    check(display_scored.is_empty(), "display-only tags are never scored %s" % str(display_scored))


# Builds an attempt the way the cannery does: load the recipe into the
# selection, then use build_process_sequence (which applies category limits).
func _selection_attempt(gs, recipe_def: Dictionary, method_id: String, with_addons: bool) -> Dictionary:
    gs._apply_recipe_selection(recipe_def)
    var addons: Array = gs.tin_ingredient_ids if with_addons else []
    return gs._build_craft_attempt(gs.tin_fish_id, method_id, addons, gs.build_process_sequence())


# The recipe an attempt would discover, or "" if none reaches its threshold.
func _winning_recipe(gs, attempt: Dictionary) -> String:
    var best_score := 0
    var best_def: Dictionary = {}
    for silhouette_id in gs.silhouette_ids_by_fish_id.get(str(attempt.get("fish_id", "")), []):
        var def: Dictionary = gs.silhouette_defs_by_id.get(str(silhouette_id), {})
        var score := int(gs._score_attempt_against_silhouette(attempt, def)["score"])
        if score > best_score:
            best_score = score
            best_def = def
    if best_def.is_empty() or best_score < int(best_def.get("unlock_threshold", 75)):
        return ""
    return str(best_def.get("recipe_id", ""))
