extends RefCounted

const RequiresEval = preload("res://src/requires/requires_eval.gd")

const KNOWN_REQUIRE_TYPES := [
    "always",
    "flag_true",
    "money_at_least",
    "depth_tier_at_least",
    "upgrade_purchased",
    "upgrade_level_at_least",
    "exclusive_group_unchosen",
    "policy_stage_at_least",
    "item_owned_at_least"
]

static func validate_all(data_registry: Object) -> void:
    var report = _new_report()

    validate_unique_ids(data_registry.upgrades, "upgrade_id", "upgrades.json", report)
    validate_unique_ids(data_registry.skill_nodes, "id", "skill_tree.json", report)
    validate_unique_ids(data_registry.fish, "fish_id", "fish.json", report)
    validate_unique_ids(data_registry.recipes, "recipe_id", "recipes.json", report)
    validate_unique_ids(data_registry.items, "ingredient_id", "items.json", report, true)
    validate_unique_ids(data_registry.equipment, "equipment_id", "equipment.json", report)
    validate_unique_ids(data_registry.processes, "process_id", "processes.json", report)
    var registries = {
        "upgrades": data_registry.upgrades_by_id,
        "skills": data_registry.skill_nodes_by_id,
        "fish": data_registry.fish_by_id,
        "fish_by_name": data_registry.fish_by_name,
        "recipes": data_registry.recipes_by_id,
        "items": data_registry.items_by_id,
        "equipment": data_registry.equipment_by_id,
        "processes": data_registry.processes_by_id
    }

    validate_upgrades(data_registry.upgrades, registries, report)
    validate_skill_tree(data_registry.skill_nodes, registries, report)
    validate_fish(data_registry.fish, registries, report)
    validate_recipes(data_registry.recipes, registries, report)
    validate_items(data_registry.items, registries, report)
    validate_equipment(data_registry.equipment, registries, report)
    validate_processes(data_registry.processes, registries, report)
    validate_cannery_options(data_registry.cannery_options, registries, report)

    _emit_report(report, OS.is_debug_build())


static func validate_unique_ids(entries: Array, id_field: String, file_label: String, report: Dictionary, allow_item_fallback: bool = false) -> void:
    var seen: Dictionary = {}
    for idx in range(entries.size()):
        var entry = entries[idx]
        if typeof(entry) != TYPE_DICTIONARY:
            _push_error(report, "%s[%d]: entry must be an object." % [file_label, idx])
            continue
        var entry_dict: Dictionary = entry
        var entry_id = str(entry_dict.get(id_field, ""))
        if entry_id == "" and allow_item_fallback:
            entry_id = str(entry_dict.get("item_id", ""))
        if entry_id == "":
            _push_error(report, "%s[%d]: missing %s." % [file_label, idx, id_field])
            continue
        if seen.has(entry_id):
            _push_error(report, "%s: duplicate id '%s'." % [file_label, entry_id])
            continue
        seen[entry_id] = true


static func validate_requires(obj: Dictionary, file_label: String, id_for_logs: String, registries: Dictionary, report: Dictionary) -> void:
    var reqs: Array = RequiresEval.get_requires(obj)
    if typeof(reqs) != TYPE_ARRAY:
        _push_error(report, "%s (%s): requires must be an array." % [file_label, id_for_logs])
        return
    for req_idx in range(reqs.size()):
        var req = reqs[req_idx]
        if typeof(req) != TYPE_DICTIONARY:
            _push_error(report, "%s (%s): requires[%d] must be an object." % [file_label, id_for_logs, req_idx])
            continue
        var req_dict: Dictionary = req
        var req_type = str(req_dict.get("type", ""))
        if req_type == "":
            _push_error(report, "%s (%s): requires[%d] missing type." % [file_label, id_for_logs, req_idx])
            continue
        if not KNOWN_REQUIRE_TYPES.has(req_type):
            _push_error(report, "%s (%s): requires[%d] unknown type '%s'." % [file_label, id_for_logs, req_idx, req_type])
            continue

        match req_type:
            "flag_true":
                var flag = str(req_dict.get("flag", req_dict.get("value", "")))
                if flag == "":
                    _push_error(report, "%s (%s): requires[%d] flag_true missing flag." % [file_label, id_for_logs, req_idx])
            "money_at_least":
                if not _is_number(req_dict.get("value", null)):
                    _push_error(report, "%s (%s): requires[%d] money_at_least value must be numeric." % [file_label, id_for_logs, req_idx])
            "depth_tier_at_least":
                if not _is_number(req_dict.get("value", null)):
                    _push_error(report, "%s (%s): requires[%d] depth_tier_at_least value must be numeric." % [file_label, id_for_logs, req_idx])
            "upgrade_purchased", "upgrade_level_at_least":
                var upgrade_id = _get_string_id(req_dict, "upgrade_id")
                if upgrade_id == "":
                    upgrade_id = _get_string_id(req_dict, "value")
                if upgrade_id == "":
                    _push_error(report, "%s (%s): requires[%d] %s missing upgrade_id." % [file_label, id_for_logs, req_idx, req_type])
                elif not registries["upgrades"].has(upgrade_id):
                    _push_error(report, "%s (%s): requires[%d] unknown upgrade_id '%s'." % [file_label, id_for_logs, req_idx, upgrade_id])
                if req_type == "upgrade_level_at_least" and not _is_number(req_dict.get("value", null)):
                    _push_error(report, "%s (%s): requires[%d] upgrade_level_at_least value must be numeric." % [file_label, id_for_logs, req_idx])
            "item_owned_at_least":
                var item_id = _get_string_id(req_dict, "item_id")
                if item_id == "":
                    item_id = _get_string_id(req_dict, "value")
                if item_id == "":
                    _push_error(report, "%s (%s): requires[%d] item_owned_at_least missing item_id." % [file_label, id_for_logs, req_idx])
                elif not registries["items"].has(item_id):
                    _push_error(report, "%s (%s): requires[%d] unknown item_id '%s'." % [file_label, id_for_logs, req_idx, item_id])
            "exclusive_group_unchosen":
                var group_id = str(req_dict.get("group_id", ""))
                if group_id == "":
                    _push_error(report, "%s (%s): requires[%d] exclusive_group_unchosen missing group_id." % [file_label, id_for_logs, req_idx])
            "policy_stage_at_least":
                var policy_group = str(req_dict.get("group_id", ""))
                if policy_group == "":
                    _push_error(report, "%s (%s): requires[%d] policy_stage_at_least missing group_id." % [file_label, id_for_logs, req_idx])
                if not _is_number(req_dict.get("stage", null)):
                    _push_error(report, "%s (%s): requires[%d] policy_stage_at_least stage must be numeric." % [file_label, id_for_logs, req_idx])
            _:
                pass

        var equipment_id = str(req_dict.get("equipment_id", ""))
        if equipment_id != "" and not registries["equipment"].has(equipment_id):
            _push_error(report, "%s (%s): requires[%d] unknown equipment_id '%s'." % [file_label, id_for_logs, req_idx, equipment_id])


static func validate_upgrades(entries: Array, registries: Dictionary, report: Dictionary) -> void:
    var policy_stage_by_group: Dictionary = {}
    var policy_groups_by_stage: Dictionary = {}
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var upgrade: Dictionary = entry
        var upgrade_id = _get_string_id(upgrade, "upgrade_id")
        var id_for_logs = _label_id("upgrade_id", upgrade_id)
        _require_fields(upgrade, [
            ["upgrade_id", TYPE_STRING],
            ["display_name", TYPE_STRING],
            ["description", TYPE_STRING],
            ["category", TYPE_STRING],
            ["base_cost", [TYPE_INT, TYPE_FLOAT]],
            ["max_level", [TYPE_INT, TYPE_FLOAT]],
            ["effects", TYPE_ARRAY]
        ], "upgrades.json", id_for_logs, report)
        validate_requires(upgrade, "upgrades.json", id_for_logs, registries, report)
        if bool(upgrade.get("exclusive_choice", false)):
            var group_id = str(upgrade.get("exclusive_group_id", ""))
            if group_id == "":
                _push_error(report, "upgrades.json (%s): exclusive_choice true but exclusive_group_id missing." % id_for_logs)
        if str(upgrade.get("category", "")) != "policy":
            continue
        var policy_group_id := str(upgrade.get("exclusive_group_id", ""))
        var policy_stage := int(upgrade.get("policy_stage", 0))
        if policy_group_id == "":
            _push_error(report, "upgrades.json (%s): policy upgrade missing exclusive_group_id." % id_for_logs)
        if policy_stage <= 0:
            _push_error(report, "upgrades.json (%s): policy upgrade missing/invalid policy_stage." % id_for_logs)
        if policy_group_id != "":
            var existing_stage := int(policy_stage_by_group.get(policy_group_id, 0))
            if existing_stage > 0 and policy_stage > 0 and existing_stage != policy_stage:
                _push_error(report, "upgrades.json (%s): policy group '%s' has inconsistent policy_stage values." % [id_for_logs, policy_group_id])
            elif policy_stage > 0:
                policy_stage_by_group[policy_group_id] = policy_stage
                if not policy_groups_by_stage.has(policy_stage):
                    policy_groups_by_stage[policy_stage] = []
                var groups_at_stage: Array = policy_groups_by_stage[policy_stage]
                if not groups_at_stage.has(policy_group_id):
                    groups_at_stage.append(policy_group_id)
                    policy_groups_by_stage[policy_stage] = groups_at_stage

    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var upgrade: Dictionary = entry
        if str(upgrade.get("category", "")) != "policy":
            continue
        var upgrade_id = _get_string_id(upgrade, "upgrade_id")
        var id_for_logs = _label_id("upgrade_id", upgrade_id)
        var policy_stage := int(upgrade.get("policy_stage", 0))
        if policy_stage <= 1:
            continue
        var prev_stage_groups: Array = policy_groups_by_stage.get(policy_stage - 1, [])
        if prev_stage_groups.is_empty():
            _push_error(report, "upgrades.json (%s): no policy group found for previous stage %d." % [id_for_logs, policy_stage - 1])
            continue
        var has_valid_prev_requirement := false
        var reqs: Array = RequiresEval.get_requires(upgrade)
        for req in reqs:
            if typeof(req) != TYPE_DICTIONARY:
                continue
            var req_dict: Dictionary = req
            if str(req_dict.get("type", "")) != "policy_stage_at_least":
                continue
            var req_group := str(req_dict.get("group_id", ""))
            var req_stage := int(req_dict.get("stage", 0))
            if req_stage == (policy_stage - 1) and prev_stage_groups.has(req_group):
                has_valid_prev_requirement = true
                break
        if not has_valid_prev_requirement:
            _push_error(report, "upgrades.json (%s): stage %d policy must require previous stage (%d) from a valid prior group." % [id_for_logs, policy_stage, policy_stage - 1])


static func validate_skill_tree(entries: Array, registries: Dictionary, report: Dictionary) -> void:
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var node: Dictionary = entry
        var node_id = _get_string_id(node, "id")
        var id_for_logs = _label_id("id", node_id)
        _require_fields(node, [
            ["id", TYPE_STRING],
            ["name", TYPE_STRING],
            ["desc", TYPE_STRING],
            ["branch", TYPE_STRING],
            ["cost", [TYPE_INT, TYPE_FLOAT]],
            ["order", [TYPE_INT, TYPE_FLOAT]],
            ["pos", TYPE_ARRAY],
            ["effects", TYPE_ARRAY]
        ], "skill_tree.json", id_for_logs, report)
        var pos: Array = node.get("pos", [])
        if typeof(pos) == TYPE_ARRAY and pos.size() >= 2:
            if not _is_number(pos[0]) or not _is_number(pos[1]):
                _push_error(report, "skill_tree.json (%s): pos must be numeric pair." % id_for_logs)
        var reqs: Array = node.get("requires", [])
        if typeof(reqs) == TYPE_ARRAY:
            for req_id in reqs:
                if typeof(req_id) != TYPE_STRING:
                    _push_error(report, "skill_tree.json (%s): requires entries must be strings." % id_for_logs)
                    continue
                if not registries["skills"].has(req_id):
                    _push_error(report, "skill_tree.json (%s): unknown required skill id '%s'." % [id_for_logs, req_id])


static func validate_fish(entries: Array, registries: Dictionary, report: Dictionary) -> void:
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var fish: Dictionary = entry
        var fish_id = _get_string_id(fish, "fish_id")
        var id_for_logs = _label_id("fish_id", fish_id)
        _require_fields(fish, [
            ["fish_id", TYPE_STRING],
            ["display_name", TYPE_STRING],
            ["rarity", TYPE_STRING],
            ["biome", TYPE_STRING],
            ["depth_min_m", [TYPE_INT, TYPE_FLOAT]],
            ["depth_max_m", [TYPE_INT, TYPE_FLOAT]]
        ], "fish.json", id_for_logs, report)
        var tinned_ids: Array = fish.get("tinned_recipe_ids", [])
        if typeof(tinned_ids) == TYPE_ARRAY:
            for recipe_id in tinned_ids:
                if typeof(recipe_id) != TYPE_STRING:
                    _push_error(report, "fish.json (%s): tinned_recipe_ids must be strings." % id_for_logs)
                    continue
                if not registries["recipes"].has(recipe_id):
                    _push_error(report, "fish.json (%s): unknown recipe_id '%s' in tinned_recipe_ids." % [id_for_logs, recipe_id])
        validate_requires(fish, "fish.json", id_for_logs, registries, report)


static func validate_recipes(entries: Array, registries: Dictionary, report: Dictionary) -> void:
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var recipe: Dictionary = entry
        var recipe_id = _get_string_id(recipe, "recipe_id")
        var id_for_logs = _label_id("recipe_id", recipe_id)
        _require_fields(recipe, [
            ["recipe_id", TYPE_STRING]
        ], "recipes.json", id_for_logs, report)
        var fish_id = _get_string_id(recipe, "required_fish_id")
        var fish_name = _get_string_id(recipe, "required_fish_name")
        if fish_id != "":
            if not registries["fish"].has(fish_id):
                _push_error(report, "recipes.json (%s): unknown required_fish_id '%s'." % [id_for_logs, fish_id])
        elif fish_name != "":
            if not registries["fish_by_name"].has(fish_name):
                _push_error(report, "recipes.json (%s): unknown required_fish_name '%s'." % [id_for_logs, fish_name])
            else:
                _push_warning(report, "recipes.json (%s): uses required_fish_name; prefer required_fish_id." % id_for_logs)
        else:
            _push_error(report, "recipes.json (%s): missing required_fish_id/required_fish_name." % id_for_logs)

        var ingredients: Array = recipe.get("ingredients", [])
        if typeof(ingredients) != TYPE_ARRAY:
            _push_error(report, "recipes.json (%s): ingredients must be an array." % id_for_logs)
        else:
            for ingredient in ingredients:
                if typeof(ingredient) != TYPE_DICTIONARY:
                    _push_error(report, "recipes.json (%s): ingredient entries must be objects." % id_for_logs)
                    continue
                var ingredient_dict: Dictionary = ingredient
                var item_id = _get_string_id(ingredient_dict, "item_id")
                if item_id == "":
                    _push_error(report, "recipes.json (%s): ingredient missing item_id." % id_for_logs)
                    continue
                if not _is_number(ingredient_dict.get("qty", null)):
                    _push_error(report, "recipes.json (%s): ingredient '%s' qty must be numeric." % [id_for_logs, item_id])
                if registries["items"].has(item_id):
                    continue
                if item_id.begins_with("fish_"):
                    var fish_ref = item_id.substr(5)
                    if registries["fish"].has(fish_ref):
                        continue
                _push_error(report, "recipes.json (%s): unknown ingredient item_id '%s'." % [id_for_logs, item_id])

        var processes: Array = recipe.get("processes", [])
        if typeof(processes) != TYPE_ARRAY:
            _push_error(report, "recipes.json (%s): processes must be an array." % id_for_logs)
        else:
            for process_id in processes:
                if typeof(process_id) != TYPE_STRING:
                    _push_error(report, "recipes.json (%s): process ids must be strings." % id_for_logs)
                    continue
                if not registries["processes"].has(process_id):
                    _push_error(report, "recipes.json (%s): unknown process_id '%s'." % [id_for_logs, process_id])

        validate_requires(recipe, "recipes.json", id_for_logs, registries, report)


static func validate_items(entries: Array, registries: Dictionary, report: Dictionary) -> void:
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var item: Dictionary = entry
        var item_id = _get_item_id(item)
        var id_for_logs = _label_id("item_id", item_id)
        if item_id == "":
            _push_error(report, "items.json: item missing ingredient_id/item_id.")
            continue
        if not _is_number(item.get("base_cost", null)):
            _push_error(report, "items.json (%s): base_cost must be numeric." % id_for_logs)
        validate_requires(item, "items.json", id_for_logs, registries, report)


static func validate_equipment(entries: Array, registries: Dictionary, report: Dictionary) -> void:
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var equipment: Dictionary = entry
        var equipment_id = _get_string_id(equipment, "equipment_id")
        var id_for_logs = _label_id("equipment_id", equipment_id)
        _require_fields(equipment, [
            ["equipment_id", TYPE_STRING]
        ], "equipment.json", id_for_logs, report)
        validate_requires(equipment, "equipment.json", id_for_logs, registries, report)


static func validate_processes(entries: Array, registries: Dictionary, report: Dictionary) -> void:
    for entry in entries:
        if typeof(entry) != TYPE_DICTIONARY:
            continue
        var process: Dictionary = entry
        var process_id = _get_string_id(process, "process_id")
        var id_for_logs = _label_id("process_id", process_id)
        _require_fields(process, [
            ["process_id", TYPE_STRING]
        ], "processes.json", id_for_logs, report)
        var required_equipment: Array = process.get("required_equipment", [])
        if typeof(required_equipment) == TYPE_ARRAY:
            for equipment_id in required_equipment:
                if typeof(equipment_id) != TYPE_STRING:
                    _push_error(report, "processes.json (%s): required_equipment ids must be strings." % id_for_logs)
                    continue
                if not registries["equipment"].has(equipment_id):
                    _push_error(report, "processes.json (%s): unknown equipment_id '%s'." % [id_for_logs, equipment_id])
        validate_requires(process, "processes.json", id_for_logs, registries, report)


static func validate_cannery_options(options: Dictionary, _registries: Dictionary, report: Dictionary) -> void:
    if typeof(options) != TYPE_DICTIONARY:
        _push_error(report, "cannery_options.json: root must be an object.")
        return
    var methods: Array = options.get("methods", [])
    var ingredients: Array = options.get("ingredients", [])
    _validate_cannery_group(methods, "methods", report)
    _validate_cannery_group(ingredients, "ingredients", report)


static func _validate_cannery_group(entries: Array, label: String, report: Dictionary) -> void:
    if typeof(entries) != TYPE_ARRAY:
        _push_error(report, "cannery_options.json: %s must be an array." % label)
        return
    var seen: Dictionary = {}
    for idx in range(entries.size()):
        var entry = entries[idx]
        if typeof(entry) != TYPE_DICTIONARY:
            _push_error(report, "cannery_options.json: %s[%d] must be an object." % [label, idx])
            continue
        var entry_dict: Dictionary = entry
        var entry_id = str(entry_dict.get("id", ""))
        var entry_name = str(entry_dict.get("name", ""))
        if entry_id == "":
            _push_error(report, "cannery_options.json: %s[%d] missing id." % [label, idx])
        if entry_name == "":
            _push_error(report, "cannery_options.json: %s[%d] missing name." % [label, idx])
        if entry_id != "":
            if seen.has(entry_id):
                _push_error(report, "cannery_options.json: duplicate %s id '%s'." % [label, entry_id])
            seen[entry_id] = true


static func _validate_cannery_unique_ids(options: Dictionary, report: Dictionary) -> void:
    if typeof(options) != TYPE_DICTIONARY:
        return
    _validate_cannery_group(options.get("methods", []), "methods", report)
    _validate_cannery_group(options.get("ingredients", []), "ingredients", report)


static func _require_fields(entry: Dictionary, fields: Array, file_label: String, id_for_logs: String, report: Dictionary) -> void:
    for field_info in fields:
        var key: String = field_info[0]
        var expected = field_info[1]
        if not entry.has(key):
            _push_error(report, "%s (%s): missing %s." % [file_label, id_for_logs, key])
            continue
        var value = entry.get(key, null)
        if typeof(expected) == TYPE_INT:
            if typeof(value) != expected:
                _push_error(report, "%s (%s): %s has wrong type." % [file_label, id_for_logs, key])
        else:
            var allowed_types: Array = expected
            var is_match = false
            for allowed in allowed_types:
                if typeof(value) == allowed:
                    is_match = true
                    break
            if not is_match:
                _push_error(report, "%s (%s): %s has wrong type." % [file_label, id_for_logs, key])


static func _get_item_id(entry: Dictionary) -> String:
    var ingredient_id = str(entry.get("ingredient_id", ""))
    if ingredient_id != "":
        return ingredient_id
    return str(entry.get("item_id", ""))


static func _get_string_id(entry: Dictionary, key: String) -> String:
    var value = entry.get(key, "")
    if typeof(value) != TYPE_STRING:
        return ""
    return str(value)


static func _is_number(value) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _label_id(key: String, value: String) -> String:
    if value == "":
        return "%s=unknown" % key
    return "%s=%s" % [key, value]


static func _new_report() -> Dictionary:
    return {
        "errors": [],
        "warnings": []
    }


static func _push_error(report: Dictionary, message: String) -> void:
    report["errors"].append(message)


static func _push_warning(report: Dictionary, message: String) -> void:
    report["warnings"].append(message)


static func _emit_report(report: Dictionary, is_debug: bool) -> void:
    var errors: Array = report.get("errors", [])
    var warnings: Array = report.get("warnings", [])
    if is_debug:
        for message in warnings:
            push_warning(message)
        if errors.size() > 0:
            for message in errors:
                push_error(message)
            assert(false)
    else:
        for message in warnings:
            push_warning(message)
        for message in errors:
            push_warning(message)
