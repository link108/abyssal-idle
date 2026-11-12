extends "res://tests/headless/test_base.gd"

const LOG := [
    {"attempt_id": 1, "fish_id": "choirfin_seraph", "ingredient_ids": ["salt"], "process_ids": ["clean", "tin_pack", "tin_seal"], "derived_tags": ["fish:choirfin_seraph", "salty"], "score": 40, "matched_silhouette_id": "choirfin_golden_oil", "matched_recipe_id": "choirfin_golden_oil", "result_key": "experimental_tin_odd", "timestamp_unix": 100},
    {"attempt_id": 2, "fish_id": "choirfin_seraph", "ingredient_ids": ["oil_golden"], "process_ids": ["clean", "poach", "tin_pack", "tin_seal"], "derived_tags": ["fish:choirfin_seraph", "oily"], "score": 68, "matched_silhouette_id": "choirfin_golden_oil", "matched_recipe_id": "choirfin_golden_oil", "result_key": "experimental_tin_stable", "timestamp_unix": 200},
    {"attempt_id": 3, "fish_id": "veilscale_mourner", "ingredient_ids": [], "process_ids": ["tin_pack", "tin_seal"], "derived_tags": ["fish:veilscale_mourner"], "score": 20, "matched_silhouette_id": "veilscale_simple_brine", "matched_recipe_id": "veilscale_simple_brine", "result_key": "experimental_tin_rough", "timestamp_unix": 300},
    {"attempt_id": 4, "fish_id": "choirfin_seraph", "ingredient_ids": ["oil_golden"], "process_ids": ["poach", "tin_pack", "tin_seal"], "derived_tags": ["fish:choirfin_seraph", "oily"], "score": 68, "matched_silhouette_id": "choirfin_golden_oil", "matched_recipe_id": "choirfin_golden_oil", "result_key": "experimental_tin_stable", "timestamp_unix": 400}
]


func run_tests(gs) -> void:
    gs.meta_state["experiment_log"] = LOG.duplicate(true)
    gs.meta_state["discovered_recipe_ids"] = []
    _test_view(gs)
    _test_closest(gs)
    _test_labels(gs)
    _test_detail(gs)
    _test_panel(gs)
    _test_save(gs)
    gs.meta_state["experiment_log"] = []


func _ids(entries: Array) -> Array:
    var out: Array = []
    for entry in entries:
        out.append(int(entry["attempt_id"]))
    return out


func _test_view(gs) -> void:
    check(_ids(gs.get_experiment_log_view("newest")) == [4, 3, 2, 1], "newest first")
    check(_ids(gs.get_experiment_log_view("score")) == [4, 2, 1, 3], "highest score first, newest breaks ties")
    check(_ids(gs.get_experiment_log_view("newest", "veilscale_simple_brine")) == [3], "filter by silhouette")


func _test_closest(gs) -> void:
    var closest: Dictionary = gs.get_closest_attempt_ids()
    check(int(closest["choirfin_golden_oil"]) == 2, "closest is the earliest best score (#2, not the tie #4)")
    var flagged: Array = []
    for entry in gs.get_experiment_log_view("newest"):
        if bool(entry["is_closest"]):
            flagged.append(int(entry["attempt_id"]))
    flagged.sort()
    check(flagged == [2, 3], "one closest attempt per silhouette %s" % str(flagged))
    check(int(gs.get_closest_attempt_for_fish("choirfin_seraph").get("attempt_id", 0)) == 2, "closest for a fish")
    gs._mark_recipe_discovered("choirfin_golden_oil")
    check(gs.get_closest_attempt_for_fish("choirfin_seraph").is_empty(), "discovered recipes drop out of 'closest for this fish'")
    gs.meta_state["discovered_recipe_ids"] = []


func _test_labels(gs) -> void:
    var hidden: String = gs.get_silhouette_label("choirfin_golden_oil")
    check(hidden == "Hidden Choirfin Seraph recipe", "undiscovered label names only the fish: '%s'" % hidden)
    gs._mark_recipe_discovered("choirfin_golden_oil")
    check(gs.get_silhouette_label("choirfin_golden_oil") == str(gs.recipe_defs_by_id["choirfin_golden_oil"]["display_name"]), "discovered label is the recipe name")
    gs.meta_state["discovered_recipe_ids"] = []
    check(gs.get_experiment_log_silhouette_ids().size() == 2, "filter lists each logged silhouette once")
    var inputs: String = gs.format_experiment_inputs(LOG[1])
    check(inputs.contains("Choirfin Seraph") and inputs.contains("Poach") and not inputs.contains("Pack"), "inputs line lists fish, add-ons and processes, not pack/seal: '%s'" % inputs)


func _test_detail(gs) -> void:
    var detail: Dictionary = gs.get_experiment_attempt_detail(2)
    check(int(detail["score"]) == 68 and bool(detail["is_closest"]), "detail has score and closest flag")
    var text := "\n".join(detail["lines"])
    check(text.contains("needs 75%") and text.contains("Key notes:") and text.contains("Process steps:") and text.contains("Hint:"), "detail explains how close it was: %s" % text)
    # The hint line reuses the cannery hint (one missing note + its source);
    # the count lines must not reveal tags.
    var counts := "\n".join((detail["lines"] as Array).filter(func(line): return not str(line).begins_with("Hint:")))
    var silhouette: Dictionary = gs.silhouette_defs_by_id["choirfin_golden_oil"]
    var leaks: Array = []
    for tag in silhouette["required_tags"] + silhouette["preferred_tags"]:
        if counts.contains(str(tag)):
            leaks.append(tag)
    check(leaks.is_empty(), "count lines don't list hidden tags %s" % str(leaks))
    check(gs.get_experiment_attempt_detail(999).is_empty(), "unknown attempt has no detail")

    check(gs.apply_attempt_to_selection(2), "refine loads an attempt from the log")
    check(gs.tin_fish_id == "choirfin_seraph" and gs.tin_ingredient_ids == ["oil_golden"] and gs.build_process_sequence().has("poach"), "refined selection matches the attempt")


func _test_panel(gs) -> void:
    gs.meta_state["experiment_log"] = LOG.duplicate(true)
    var panel = load("res://src/ui/components/experiment_log/experiment_log_panel.gd").new()
    root.add_child(panel)
    var applied := [false]
    panel.attempt_applied.connect(func(): applied[0] = true)
    panel.open()
    check(panel.visible, "panel opens")
    check(panel._filter_select.item_count == 3, "filter has All + 2 recipes")
    var rows: Array = panel._rows.get_children().filter(func(row): return row is Button)
    check(rows.size() == 4 and str(rows[0].text).begins_with("#4 "), "rows list every attempt, newest first")
    panel._select_attempt(2)
    check(str(panel._detail_title.text).begins_with("Attempt #2: 68%") and not panel._refine_button.disabled, "selecting a row shows its detail")
    panel._on_refine_pressed()
    check(applied[0] and not panel.visible and gs.tin_fish_id == "choirfin_seraph", "Refine this loads the attempt and closes")
    panel.queue_free()


func _test_save(gs) -> void:
    # Migration safety: junk entries are dropped, fields are coerced, and the
    # attempt counter catches up with the highest logged id.
    var meta: Dictionary = gs.meta_state.duplicate(true)
    meta["experiment_log"] = [LOG[0], "junk", {"attempt_id": "7", "score": "55", "process_ids": "bad"}]
    meta["attempt_counter"] = 0
    meta["silhouette_progress_by_id"] = {"choirfin_golden_oil": {"state": "hinted", "best_score": 40}, "bogus": 5}
    gs._apply_save({"version": gs.SAVE_VERSION, "meta_state": meta})
    var log: Array = gs.meta_state["experiment_log"]
    check(log.size() == 2, "junk log entries are dropped (%d left)" % log.size())
    check(int(log[1]["attempt_id"]) == 7 and int(log[1]["score"]) == 55 and log[1]["process_ids"] == [], "fields are coerced")
    check(int(gs.meta_state["attempt_counter"]) == 7, "attempt counter catches up to the log")
    var progress: Dictionary = gs.meta_state["silhouette_progress_by_id"]
    check(progress.has("choirfin_golden_oil") and int(progress["choirfin_golden_oil"]["best_score"]) == 40, "silhouette progress survives a load")
