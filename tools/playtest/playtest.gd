extends SceneTree

# Automated playtest: runs the real main.tscn at fixed, accelerated time and
# plays it like a person would, then writes milestones and samples as JSON.
# Run through tools/playtest/run.sh (headless, own user data dir).
#
# User args (after --): profile=sustainable|industrial hours=4 manual=0.5
#   explore=0.5 seed=1 out=res://.vdisplay/playtest/<name>.json
#
# Player model:
# - Alternates 2-minute blocks: fishes manually for `manual` of each block
#   (crew trips pause while the boat screen is open, as in the UI), then
#   tends the crew, shop and cannery for the rest.
# - Manual fishing: one attempt per 1.5s; hit chance grows with the green zone.
# - Shopping: crew/cannery unlocks and the profile's policies first, then the
#   cheapest affordable upgrade or equipment.
# - Cannery: `explore` of cannery actions are experiments that hill-climb on
#   the score and follow the hint (it names the missing note, and item tags
#   are visible in the market); the rest make the best discovered recipe.
# - Prestige once all five policies are bought (or after 45 min), then spend
#   reputation on core, own-branch and meta skills.

const TICK := 0.25
const BLOCK_SECONDS := 120.0
const ATTEMPT_SECONDS := 1.5
const SAMPLE_SECONDS := 60.0
const SHOP_SECONDS := 5.0
const FISH_RESERVE := 12
const PRESTIGE_FALLBACK_SECONDS := 45.0 * 60.0
const POLICY_PREFIX := {"sustainable": "sust_", "industrial": "ind_"}

var profile := "sustainable"
var max_seconds := 4.0 * 3600.0
var manual_share := 0.5
var explore_share := 0.5
var out_path := ""

var gs
var main: Node
var rng := RandomNumberGenerator.new()
var started := false
var t := 0.0
var run_t := 0.0
var attempt_acc := 0.0
var shop_acc := 0.0
var sample_acc := 0.0
var milestones := {}
var events: Array = []
var samples: Array = []
var counters := {"manual_attempts": 0, "manual_catches": 0, "experiments": 0, "recipe_tins": 0, "purchases": 0}
var last_lifetime := 0
var runs_done := 0

# Experiment state.
var exp_fish := ""
var exp_best_score := -1
var exp_best := {}
var exp_attempts_by_fish := {}


func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        var kv := str(arg).split("=", true, 1)
        if kv.size() != 2:
            continue
        match kv[0]:
            "profile": profile = kv[1]
            "hours": max_seconds = float(kv[1]) * 3600.0
            "manual": manual_share = float(kv[1])
            "explore": explore_share = float(kv[1])
            "seed": rng.seed = int(kv[1])
            "out": out_path = kv[1]
    if out_path == "":
        out_path = "res://.vdisplay/playtest/%s.json" % profile
    change_scene_to_file("res://main.tscn")


func _process(delta: float) -> bool:
    if not started:
        if current_scene == null:
            return false
        main = current_scene
        gs = root.get_node("GameState")
        main._on_new_requested()
        gs._rng.seed = rng.seed
        started = true
        _event("start", "profile=%s manual=%.2f explore=%.2f" % [profile, manual_share, explore_share])
        return false
    t += delta
    run_t += delta
    _tick(delta)
    if gs.get_ending_state() != gs.EndingState.NONE:
        _event("ending", str(gs.EndingState.keys()[gs.get_ending_state()]))
        _finish()
        return true
    if t >= max_seconds:
        _event("time_cap", "%.1fh" % (t / 3600.0))
        _finish()
        return true
    return false


func _tick(delta: float) -> void:
    var fishing := fmod(run_t, BLOCK_SECONDS) < manual_share * BLOCK_SECONDS
    gs.set_crew_trip_paused(fishing and gs.is_crew_unlocked)
    if fishing:
        attempt_acc += delta
        while attempt_acc >= ATTEMPT_SECONDS:
            attempt_acc -= ATTEMPT_SECONDS
            _manual_attempt()
    else:
        _tend_crew()
        _tend_cannery()
    _set_sell_mode()
    shop_acc += delta
    if shop_acc >= SHOP_SECONDS:
        shop_acc = 0.0
        _shop()
        _maybe_prestige()
    _check_milestones()
    sample_acc += delta
    if sample_acc >= SAMPLE_SECONDS:
        sample_acc = 0.0
        _sample()


# --- Fishing -------------------------------------------------------------

func _manual_attempt() -> void:
    var hit_chance: float = min(0.95, 0.35 + gs.get_green_zone_ratio() * 3.5)
    var outcome: Dictionary = gs.attempt_manual_catch(rng.randf() < hit_chance)
    counters["manual_attempts"] += 1
    if bool(outcome.get("success", false)):
        counters["manual_catches"] += int(outcome.get("count", 1))


func _tend_crew() -> void:
    if not gs.is_crew_unlocked or gs.crew_trip_active:
        return
    var target := _pick_destination()
    if target != "" and target != gs.crew_destination_id:
        gs.select_crew_destination(target)
    gs.start_crew_trip()


func _pick_destination() -> String:
    var unlocked: Array = []
    for def in gs.get_destination_defs():
        var id := str(def.get("destination_id", ""))
        if gs.is_destination_unlocked(id):
            unlocked.append(id)
    if unlocked.is_empty():
        return ""
    if profile == "industrial":
        return str(unlocked[unlocked.size() - 1])
    # Sustainable players rotate to avoid zone fatigue.
    var idx := unlocked.find(gs.crew_last_trip_destination_id)
    return str(unlocked[(idx + 1) % unlocked.size()])


func _set_sell_mode() -> void:
    if gs.tin_count > 0:
        gs.set_sell_mode(gs.SellMode.TINS)
    elif not gs.is_cannery_unlocked or gs.fish_count > FISH_RESERVE:
        gs.set_sell_mode(gs.SellMode.FISH)
    else:
        gs.set_sell_mode(gs.SellMode.TINS)


# --- Shopping ------------------------------------------------------------

func _shop() -> void:
    if gs.can_purchase_crew():
        gs.purchase_unlocked_crew()
        _event("buy", "crew")
        return
    if gs.cannery_upgrade_is_visible() and gs.can_purchase_upgrade("unlock_cannery"):
        gs.purchase_upgrade("unlock_cannery")
        _event("buy", "unlock_cannery")
        return
    var policy := _next_policy_id()
    if policy != "":
        if gs.can_purchase_upgrade(policy):
            gs.purchase_upgrade(policy)
            _event("policy", policy)
            return
        # Save up for the policy once it's within reach.
        if gs.money >= gs.get_upgrade_cost(policy) * 0.5:
            return
    var best_cost := INF
    var best_action := Callable()
    var best_label := ""
    var visible: Dictionary = gs.get_visible_upgrade_defs_by_category(false)
    for category in visible:
        if str(category) == "policy":
            continue
        for def in visible[category]:
            var id := str(def.get("upgrade_id", ""))
            if id == "" or not gs.can_purchase_upgrade(id):
                continue
            var cost: float = gs.get_upgrade_cost(id)
            if cost < best_cost:
                best_cost = cost
                best_action = gs.purchase_upgrade.bind(id)
                best_label = id
    if gs.is_cannery_unlocked:
        for def in gs.get_equipment_defs():
            var id := str(def.get("equipment_id", ""))
            if gs.can_purchase_equipment(id) and gs.get_equipment_cost(id) < best_cost:
                best_cost = gs.get_equipment_cost(id)
                best_action = gs.purchase_equipment.bind(id)
                best_label = "equip:" + id
            elif gs.can_upgrade_equipment(id) and gs.get_equipment_upgrade_cost(id) < best_cost:
                best_cost = gs.get_equipment_upgrade_cost(id)
                best_action = gs.upgrade_equipment.bind(id)
                best_label = "equip_up:" + id
    if best_action.is_valid():
        best_action.call()
        counters["purchases"] += 1
        _event("buy", "%s $%d" % [best_label, int(best_cost)])


func _next_policy_id() -> String:
    var prefix := str(POLICY_PREFIX.get(profile, ""))
    for def in gs.get_upgrade_defs():
        var id := str(def.get("upgrade_id", ""))
        if not id.begins_with(prefix) or str(def.get("category", "")) != "policy":
            continue
        if gs.get_upgrade_level(id) > 0:
            continue
        # Skip policies that can't be bought at any price (e.g. still locked
        # after a prestige) instead of saving up for them forever.
        if gs.can_show_upgrade(def) and gs._meets_requirements(def) and not gs._is_exclusive_group_locked(def):
            return id
    return ""


func _policies_owned() -> int:
    var count := 0
    for def in gs.get_upgrade_defs():
        var id := str(def.get("upgrade_id", ""))
        if id.begins_with(str(POLICY_PREFIX.get(profile, ""))) and gs.get_upgrade_level(id) > 0:
            count += 1
    return count


# --- Cannery -------------------------------------------------------------

func _tend_cannery() -> void:
    if not gs.is_cannery_unlocked or not gs.can_make_tin():
        return
    if gs.get_auto_tin_enabled() and rng.randf() >= explore_share:
        return  # auto-tin handles production
    var recipe := _best_known_recipe()
    if recipe != "" and rng.randf() >= explore_share:
        _make_recipe_tin(recipe)
    else:
        _experiment()


func _best_known_recipe() -> String:
    var best := ""
    var best_value := 0
    for recipe_id in gs.meta_state.get("discovered_recipe_ids", []):
        var def: Dictionary = gs.recipe_defs_by_id.get(str(recipe_id), {})
        var fish_id: String = gs._get_recipe_fish_id(def)
        if int(gs.fish_stock_by_id.get(fish_id, 0)) <= 0:
            continue
        var value: int = gs.get_recipe_tin_price(str(recipe_id)) * gs.get_fish_cannery_yield(fish_id)
        if value > best_value and _ensure_items(gs.get_recipe_addon_ids(def)) and _processes_available(def.get("processes", [])):
            best_value = value
            best = str(recipe_id)
    return best


func _make_recipe_tin(recipe_id: String) -> void:
    gs.apply_recipe_to_selection(recipe_id)
    if gs.try_run_cannery_attempt(gs.tin_ingredient_ids, true):
        counters["recipe_tins"] += 1


func _experiment() -> void:
    var fish := _pick_experiment_fish()
    if fish == "":
        return
    if fish != exp_fish:
        exp_fish = fish
        exp_best_score = -1
        exp_best = {"addons": [], "processes": {"prep": [], "transform": [], "heat": [], "preserve": []}}
    var candidate := _mutate(exp_best)
    _apply_selection(fish, candidate)
    if not _ensure_items(candidate["addons"]):
        candidate["addons"] = []
        _apply_selection(fish, candidate)
    var before: Array = gs.meta_state.get("discovered_recipe_ids", []).duplicate()
    if not gs.try_run_cannery_attempt(gs.tin_ingredient_ids, true):
        return
    counters["experiments"] += 1
    exp_attempts_by_fish[fish] = int(exp_attempts_by_fish.get(fish, 0)) + 1
    var score := int(gs.get_last_craft_feedback().get("score", 0))
    if score >= exp_best_score:
        exp_best_score = score
        exp_best = candidate
    for recipe_id in gs.meta_state.get("discovered_recipe_ids", []):
        if not before.has(recipe_id):
            _event("recipe", "%s after %d experiments on this fish (%d total)" % [recipe_id, exp_attempts_by_fish[fish], counters["experiments"]])
            exp_fish = ""


func _pick_experiment_fish() -> String:
    var best := ""
    var best_count := 0
    for fish_id in gs.fish_stock_by_id:
        var count := int(gs.fish_stock_by_id[fish_id])
        if count <= 0 or not _has_undiscovered_recipe(str(fish_id)):
            continue
        if str(fish_id) == exp_fish:
            return exp_fish
        if count > best_count:
            best_count = count
            best = str(fish_id)
    return best


func _has_undiscovered_recipe(fish_id: String) -> bool:
    for recipe_id in gs.recipe_ids_by_fish_id.get(fish_id, []):
        if not gs.is_recipe_discovered(str(recipe_id)):
            return true
    return false


# One change, steered by the hint for the last attempt when there is one.
func _mutate(base: Dictionary) -> Dictionary:
    var next := {"addons": (base["addons"] as Array).duplicate(), "processes": (base["processes"] as Dictionary).duplicate(true)}
    var tag := _hinted_tag()
    if tag != "" and rng.randf() < 0.8:
        if _add_source_for_tag(next, tag):
            return next
    match rng.randi_range(0, 3):
        0:
            if not next["addons"].is_empty():
                next["addons"].remove_at(rng.randi_range(0, next["addons"].size() - 1))
        1:
            var category: String = ["prep", "transform", "heat", "preserve"][rng.randi_range(0, 3)]
            if not next["processes"][category].is_empty():
                next["processes"][category].remove_at(0)
        _:
            var items: Array = gs.get_vendor_item_defs()
            if not items.is_empty() and next["addons"].size() < 4:
                var item_id := str(items[rng.randi_range(0, items.size() - 1)].get("ingredient_id", ""))
                if item_id != "" and not next["addons"].has(item_id):
                    next["addons"].append(item_id)
    return next


# The note the hint names, read from the same scoring the hint text uses.
func _hinted_tag() -> String:
    var entry: Dictionary = gs.get_last_experiment_attempt()
    var silhouette: Dictionary = gs.silhouette_defs_by_id.get(str(entry.get("matched_silhouette_id", "")), {})
    if silhouette.is_empty() or str(entry.get("fish_id", "")) != exp_fish:
        return ""
    var result: Dictionary = gs._score_attempt_against_silhouette({
        "attempt_tags": entry.get("derived_tags", []),
        "process_ids": entry.get("process_ids", [])
    }, silhouette)
    for key in ["missing_required_tags", "missing_preferred_tags"]:
        for tag in result.get(key, []):
            if not str(tag).begins_with("fish:"):
                return str(tag)
    return ""


func _add_source_for_tag(sel: Dictionary, tag: String) -> bool:
    var items: Array = []
    for def in gs.get_vendor_item_defs():
        if gs._string_array(def.get("tags", [])).has(tag):
            items.append(str(def.get("ingredient_id", "")))
    var processes: Array = []
    for def in gs.process_defs:
        if gs._string_array(def.get("adds_tags", [])).has(tag) and _processes_available([def.get("process_id", "")]):
            processes.append(def)
    if not items.is_empty():
        var item_id := str(items[rng.randi_range(0, items.size() - 1)])
        if sel["addons"].has(item_id):
            return false
        if sel["addons"].size() >= 4:
            sel["addons"].remove_at(0)
        sel["addons"].append(item_id)
        return true
    if not processes.is_empty():
        var def: Dictionary = processes[rng.randi_range(0, processes.size() - 1)]
        var category := str(def.get("category", ""))
        var list: Array = sel["processes"].get(category, [])
        var process_id := str(def.get("process_id", ""))
        if list.has(process_id):
            return false
        if list.size() >= 2:
            list.remove_at(0)
        list.append(process_id)
        sel["processes"][category] = list
        return true
    return false


func _apply_selection(fish: String, sel: Dictionary) -> void:
    gs.tin_fish_id = fish
    gs.set_tin_ingredients(sel["addons"])
    var processes: Dictionary = {}
    for category in sel["processes"]:
        var kept: Array = []
        for process_id in sel["processes"][category]:
            if _processes_available([process_id]):
                kept.append(process_id)
        processes[category] = kept
    gs.selected_processes = processes


# Pack + seal are added automatically and aren't gated by equipment.
func _processes_available(process_ids: Array) -> bool:
    for process_id in process_ids:
        if process_id == "tin_pack" or process_id == "tin_seal":
            continue
        for equipment_id in gs._string_array(gs.get_process_def(str(process_id)).get("required_equipment", [])):
            if not gs.owns_equipment(equipment_id):
                return false
    return true


func _ensure_items(item_ids: Array) -> bool:
    for item_id in item_ids:
        if gs.get_item_count(str(item_id)) <= 0 and not gs.buy_item(str(item_id), 3):
            return false
    return true


# --- Prestige and skills ---------------------------------------------------

func _maybe_prestige() -> void:
    if not gs.can_prestige():
        return
    if _policies_owned() < 5 and run_t < PRESTIGE_FALLBACK_SECONDS:
        return
    var gain: int = gs.get_prestige_reputation_gain()
    if gs.prestige():
        runs_done += 1
        _event("prestige", "#%d after %s, +%d rep" % [runs_done, _fmt(run_t), gain])
        run_t = 0.0
        exp_fish = ""
        _buy_skills()


func _buy_skills() -> void:
    var bought := true
    while bought:
        bought = false
        var best_id := ""
        var best_cost := INF
        for def in gs.get_skill_defs():
            var id := str(def.get("id", ""))
            var branch := str(def.get("branch", ""))
            if branch != "core" and branch != "meta" and branch != profile:
                continue
            if gs.can_purchase_skill(id) and gs.get_skill_cost(id) < best_cost:
                best_cost = gs.get_skill_cost(id)
                best_id = id
        if best_id != "":
            gs.purchase_skill(best_id)
            _event("skill", "%s (%d rep)" % [best_id, int(best_cost)])
            bought = true


# --- Logging ---------------------------------------------------------------

func _check_milestones() -> void:
    _milestone("first_catch", gs.fish_count > 0 or gs.lifetime_money_earned > 0)
    _milestone("earned_100", gs.lifetime_money_earned >= 100)
    _milestone("crew_unlocked", gs.is_crew_unlocked)
    _milestone("cannery_unlocked", gs.is_cannery_unlocked)
    _milestone("first_tin_sold", gs.tins_sold > 0)
    _milestone("first_recipe", not gs.meta_state.get("discovered_recipe_ids", []).is_empty())
    _milestone("crew_auto_send", gs.get_upgrade_level("crew_auto_send") > 0)
    _milestone("auto_tin", gs.get_auto_tin_enabled())
    _milestone("all_policies", _policies_owned() >= 5)
    _milestone("prestige_ready", gs.can_prestige())
    _milestone("earned_10k", gs.lifetime_money_earned >= 10000)
    _milestone("earned_50k", gs.lifetime_money_earned >= 50000)


func _milestone(name: String, reached: bool) -> void:
    var key := "%s#%d" % [name, runs_done]
    if reached and not milestones.has(key):
        milestones[key] = t
        _event("milestone", key)


func _event(kind: String, detail: String) -> void:
    events.append({"t": snappedf(t, 0.1), "kind": kind, "detail": detail})
    print("[%s] %s %s" % [_fmt(t), kind, detail])


func _sample() -> void:
    var lifetime: int = gs.lifetime_money_earned
    samples.append({
        "t": int(t),
        "run": runs_done,
        "money": gs.money,
        "lifetime": lifetime,
        "income_per_min": lifetime - last_lifetime,
        "fish": gs.fish_count,
        "tins": gs.tin_count,
        "tins_sold": gs.tins_sold,
        "ocean": snappedf(gs.get_ocean_health_ratio(), 0.01),
        "upgrades": gs._get_total_upgrade_levels(),
        "recipes": gs.meta_state.get("discovered_recipe_ids", []).size(),
        "rep": gs.get_reputation()
    })
    last_lifetime = lifetime


func _finish() -> void:
    var report := {
        "profile": profile,
        "manual_share": manual_share,
        "explore_share": explore_share,
        "seconds": int(t),
        "counters": counters,
        "milestones": milestones,
        "silhouette_best": _silhouette_best(),
        "events": events,
        "samples": samples
    }
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_path.get_base_dir()))
    var file := FileAccess.open(out_path, FileAccess.WRITE)
    file.store_string(JSON.stringify(report, "  "))
    file.close()
    print("wrote ", out_path)
    quit(0)


func _silhouette_best() -> Dictionary:
    var out := {}
    var progress: Dictionary = gs.meta_state.get("silhouette_progress_by_id", {})
    for silhouette_id in progress:
        out[silhouette_id] = int(progress[silhouette_id].get("best_score", 0))
    return out


func _fmt(seconds: float) -> String:
    return "%d:%02d:%02d" % [int(seconds) / 3600, (int(seconds) / 60) % 60, int(seconds) % 60]
