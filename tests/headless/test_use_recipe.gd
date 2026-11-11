extends "res://tests/headless/test_base.gd"

# Two transforms (blend + mix): exercises the per-category process limit.
const RECIPE_ID := "choirfin_roe_spread"


func run_tests(gs) -> void:
    gs.meta_state["discovered_recipe_ids"] = []
    gs.tin_fish_id = ""
    gs.tin_ingredient_ids = []
    var before: Dictionary = gs.selected_processes.duplicate(true)

    check(not gs.apply_recipe_to_selection(RECIPE_ID), "undiscovered recipe is rejected")
    check(gs.tin_fish_id == "" and gs.tin_ingredient_ids.is_empty() and gs.selected_processes == before,
        "rejected recipe leaves the selection unchanged")
    check(not gs.apply_recipe_to_selection("no_such_recipe"), "unknown recipe is rejected")

    gs._mark_recipe_discovered(RECIPE_ID)
    check(gs.apply_recipe_to_selection(RECIPE_ID), "discovered recipe loads")
    var recipe_def: Dictionary = gs.recipe_defs_by_id[RECIPE_ID]
    check(gs.tin_fish_id == "choirfin_seraph", "fish is loaded")
    var expected_addons: Array = gs._normalize_ingredient_ids(gs.get_recipe_addon_ids(recipe_def))
    check(gs.tin_ingredient_ids == expected_addons, "add-ons are loaded")
    var sequence: Array = gs.build_process_sequence()
    for process_id in gs._string_array(recipe_def.get("processes", [])):
        check(sequence.has(process_id), "process sequence includes %s" % process_id)
    check(gs.tin_method_id == "raw", "method is raw without a smoke process")

    # With stock in hand, making a tin produces this recipe.
    gs.is_cannery_unlocked = true
    gs.tin_cooldown_remaining = 0.0
    gs.fish_count = 1
    gs.fish_stock_by_id = {"choirfin_seraph": 1}
    for item_id in gs.tin_ingredient_ids:
        gs.item_counts[item_id] = 5
    gs.tin_inventory = {}
    check(gs.try_run_cannery_attempt(gs.tin_method_id, gs.tin_ingredient_ids, true), "cannery attempt runs")
    check(int(gs.tin_inventory.get(RECIPE_ID, 0)) > 0, "the tin produced is the recipe")

    gs.meta_state["discovered_recipe_ids"] = []
    gs._mark_recipe_discovered("obsidian_smoked_gloommaw")
    gs.apply_recipe_to_selection("obsidian_smoked_gloommaw")
    check(gs.tin_method_id == "smoked", "method is smoked when the recipe smokes")
