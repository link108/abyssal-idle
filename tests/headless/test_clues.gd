extends "res://tests/headless/test_base.gd"

const RecipeTags = preload("res://src/data/recipe_tags.gd")


func run_tests(gs) -> void:
    _test_feedback_hints(gs)
    _test_progressive_hints(gs)
    _test_hint_tags(gs)
    _test_experiment_risk(gs)


func _test_feedback_hints(gs) -> void:
    var golden: Dictionary = gs.silhouette_defs_by_id["choirfin_golden_oil"]
    var bare: Dictionary = gs._build_craft_attempt("choirfin_seraph", "raw", [], ["tin_pack", "tin_seal"])
    var hint: String = gs._build_feedback_hint(gs._score_attempt_against_silhouette(bare, golden))
    check(hint.contains("oil"), "missing oily points at an oil: '%s'" % hint)

    var unsourced: Array = []
    var unhelpful: Array = []
    for recipe_def in gs.recipe_defs:
        var recipe_id := str(recipe_def.get("recipe_id", ""))
        var def: Dictionary = gs.silhouette_defs_by_id[recipe_id]
        for tag in gs._string_array(def.get("required_tags", [])):
            if not tag.begins_with("fish:") and gs.get_tag_source_phrase(tag) == "":
                unsourced.append("%s:%s" % [recipe_id, tag])
        var attempt: Dictionary = gs._build_craft_attempt(gs._get_recipe_fish_id(recipe_def), "raw", [], ["tin_pack", "tin_seal"])
        var result: Dictionary = gs._score_attempt_against_silhouette(attempt, def)
        var missing: Array = result["missing_required_tags"]
        if missing.is_empty():
            continue
        var phrase: String = gs.get_tag_source_phrase(str(missing[0]))
        if not gs._build_feedback_hint(result).contains(phrase):
            unhelpful.append(recipe_id)
    check(unsourced.is_empty(), "every required tag has a source to hint at %s" % str(unsourced))
    check(unhelpful.is_empty(), "every hint names the missing tag's source %s" % str(unhelpful))


func _test_progressive_hints(gs) -> void:
    var recipe_id := "lanternjaw_black_salt_brine"
    var tags: Array = gs.get_recipe_hint_tags(gs.recipe_defs_by_id[recipe_id])
    check(tags.size() >= 2, "recipe has at least two hint tags")
    var first: String = gs._humanize_tag(str(tags[0]))
    var second: String = gs._humanize_tag(str(tags[1]))

    gs.meta_state["silhouette_progress_by_id"] = {}
    var hint0: String = gs.get_recipe_silhouette_hint(recipe_id)
    check(hint0.begins_with("A hidden recipe") and not hint0.contains(first), "no progress reveals only the fish: '%s'" % hint0)

    gs.meta_state["silhouette_progress_by_id"] = {recipe_id: {"state": "hinted", "best_score": 30}}
    var hint1: String = gs.get_recipe_silhouette_hint(recipe_id)
    check(hint1.contains(first) and not hint1.contains(second), "under 50%% reveals one tag: '%s'" % hint1)

    gs.meta_state["silhouette_progress_by_id"] = {recipe_id: {"state": "hinted", "best_score": 60}}
    var hint2: String = gs.get_recipe_silhouette_hint(recipe_id)
    check(hint2.contains(first) and hint2.contains(second), "50%%+ reveals two tags: '%s'" % hint2)
    gs.meta_state["silhouette_progress_by_id"] = {}


func _test_hint_tags(gs) -> void:
    var bad: Array = []
    for recipe_def in gs.recipe_defs:
        for tag in gs.get_recipe_hint_tags(recipe_def):
            if RecipeTags.is_display_only(tag) or RecipeTags.is_generic(tag):
                bad.append("%s:%s" % [recipe_def.get("recipe_id", ""), tag])
    check(bad.is_empty(), "hints never reveal display-only or generic tags %s" % str(bad))


func _test_experiment_risk(gs) -> void:
    gs.meta_state["discovered_recipe_ids"] = []
    gs.tin_fish_id = "choirfin_seraph"
    gs.tin_ingredient_ids = ["salt"]
    var risk: String = gs.get_experiment_risk_text()
    check(risk.contains("$120"), "risk shown for an undiscovered $120 fish: '%s'" % risk)

    gs.tin_fish_id = "veilscale_mourner"
    check(gs.get_experiment_risk_text() == "", "no risk text for a cheap fish")

    gs._mark_recipe_discovered("choirfin_golden_oil")
    gs.apply_recipe_to_selection("choirfin_golden_oil")
    check(gs.get_experiment_risk_text() == "", "no risk text when the selection is a discovered recipe")
    gs.tin_ingredient_ids = []
    check(gs.get_experiment_risk_text() != "", "risk returns once the selection drifts from the recipe")
    gs.meta_state["discovered_recipe_ids"] = []
