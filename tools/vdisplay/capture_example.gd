extends SceneTree

# Example screenshot driver: sets state directly, opens screens, saves PNGs.
# Never calls new_game()/save_game(). Copy and adapt, then run with
# tools/vdisplay/play.sh --script res://tools/vdisplay/capture_example.gd
const OUT := "res://.vdisplay/shots"
var _main: Node
var _step := 0
var _wait := 0

func _initialize() -> void:
    change_scene_to_file("res://main.tscn")

func _process(_delta: float) -> bool:
    if _wait > 0:
        _wait -= 1
        return false
    var gs = root.get_node("GameState")
    _main = current_scene
    if _main == null:
        return false
    var modal = _main.get_node("ModalLayer")
    match _step:
        0:
            gs.run_paused = true
            gs.is_cannery_unlocked = true
            gs.meta_state["prestige_count"] = 2
            gs.meta_state["owned_equipment_ids"] = ["knife", "smoker", "mixing_vat", "canning_table", "canning_press"]
            modal.get_node("StartScreen").hide()
            gs.meta_state["experiment_log"] = [
                {"attempt_id": 1, "fish_id": "choirfin_seraph", "ingredient_ids": ["salt"], "process_ids": ["clean", "tin_pack", "tin_seal"], "derived_tags": ["fish:choirfin_seraph", "salty"], "score": 40, "matched_silhouette_id": "choirfin_golden_oil", "matched_recipe_id": "choirfin_golden_oil", "result_key": "experimental_tin_odd", "timestamp_unix": 100},
                {"attempt_id": 2, "fish_id": "choirfin_seraph", "ingredient_ids": ["oil_golden", "white_pepper"], "process_ids": ["clean", "poach", "tin_pack", "tin_seal"], "derived_tags": ["fish:choirfin_seraph", "oily"], "score": 68, "matched_silhouette_id": "choirfin_golden_oil", "matched_recipe_id": "choirfin_golden_oil", "result_key": "experimental_tin_stable", "timestamp_unix": 200},
                {"attempt_id": 3, "fish_id": "veilscale_mourner", "ingredient_ids": [], "process_ids": ["tin_pack", "tin_seal"], "derived_tags": ["fish:veilscale_mourner"], "score": 20, "matched_silhouette_id": "veilscale_simple_brine", "matched_recipe_id": "veilscale_simple_brine", "result_key": "experimental_tin_rough", "timestamp_unix": 300}
            ]
            gs.tin_fish_id = "choirfin_seraph"
            gs.fish_stock_by_id = {"choirfin_seraph": 2}
            gs.fish_count = 2
            gs.selected_processes = {"prep": ["clean"], "transform": [], "heat": ["smoke"], "preserve": []}
            gs.changed.emit()
            modal.get_node("CanneryScreen").show()
        1: _shot("cannery")
        2:
            var cannery = modal.get_node("CanneryScreen")
            cannery._log_panel.open()
            cannery._log_panel._select_attempt(2)
        3: _shot("experiment_log")
        4:
            modal.get_node("CanneryScreen")._log_panel.hide()
            modal.get_node("CanneryScreen").hide()
            gs.meta_state["skills_owned"] = ["core_market_entry", "sust_artisan_pricing", "sust_selective_netting"]
            gs.meta_state["reputation"] = 100
            gs.reputation_changed.emit()
            gs.skills_changed.emit()
            var skills = modal.get_node("SkillTreeScreen")
            skills.show()
            skills._hovered_id = "ind_bulk_contracts"
            skills._refresh_details_panel()
        5: _shot("skills")
        6:
            quit(0)
            return true
    _step += 1
    _wait = 8
    return false

func _shot(name: String) -> void:
    root.get_texture().get_image().save_png("%s/%s.png" % [OUT, name])
    print("saved ", name)
