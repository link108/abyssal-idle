extends RefCounted

const DEFAULT_REQUIRES := [
    {"type": "always", "value": true}
]


static func get_requires(obj: Dictionary) -> Array:
    if typeof(obj) != TYPE_DICTIONARY:
        return DEFAULT_REQUIRES.duplicate(true)
    var reqs = obj.get("requires", null)
    if typeof(reqs) == TYPE_ARRAY:
        return reqs
    var unlock_conditions = obj.get("unlock_conditions", null)
    if typeof(unlock_conditions) == TYPE_ARRAY:
        return unlock_conditions
    var unlock_condition = obj.get("unlock_condition", null)
    if typeof(unlock_condition) == TYPE_DICTIONARY:
        return [unlock_condition]
    return DEFAULT_REQUIRES.duplicate(true)


static func is_met(requires: Array, game_state: Object, context: Dictionary = {}) -> bool:
    if typeof(requires) != TYPE_ARRAY:
        return false
    if requires.is_empty():
        return true
    var ignore_types: Array = context.get("ignore_types", [])
    for req in requires:
        if typeof(req) != TYPE_DICTIONARY:
            return false
        var req_dict: Dictionary = req
        var req_type := str(req_dict.get("type", ""))
        if req_type == "":
            return false
        if ignore_types.has(req_type):
            continue
        if not _is_condition_met(req_dict, game_state, context):
            return false
    return true


static func _is_condition_met(req: Dictionary, game_state: Object, context: Dictionary) -> bool:
    var req_type := str(req.get("type", ""))
    match req_type:
        "always":
            return bool(req.get("value", false))
        "flag_true":
            var flag := str(req.get("flag", req.get("value", "")))
            if flag == "":
                return false
            if game_state.has_method("is_flag_true"):
                return bool(game_state.call("is_flag_true", flag))
            if game_state.has_method("_is_requirement_flag_true"):
                return bool(game_state.call("_is_requirement_flag_true", flag))
            return false
        "money_at_least":
            var needed_money := int(req.get("value", 0))
            if _has_property(game_state, "lifetime_money_earned"):
                return int(game_state.get("lifetime_money_earned")) >= needed_money
            if _has_property(game_state, "money"):
                return int(game_state.get("money")) >= needed_money
            return false
        "depth_tier_at_least":
            # Depth tiers are currently proxied by prestige count.
            var needed_depth := int(req.get("value", 0))
            if not _has_property(game_state, "meta_state"):
                return false
            var meta: Dictionary = game_state.get("meta_state")
            return int(meta.get("prestige_count", 0)) >= needed_depth
        "upgrade_purchased":
            var purchased_id := _get_upgrade_id(req)
            if purchased_id == "":
                return false
            return int(game_state.call("get_upgrade_level", purchased_id)) > 0
        "upgrade_level_at_least":
            var level_id := _get_upgrade_id(req)
            if level_id == "":
                return false
            var needed_level := int(req.get("value", 0))
            return int(game_state.call("get_upgrade_level", level_id)) >= needed_level
        "exclusive_group_unchosen":
            var group_id := str(req.get("group_id", ""))
            var current_id := str(context.get("current_upgrade_id", ""))
            if game_state.has_method("_is_exclusive_group_unchosen"):
                return bool(game_state.call("_is_exclusive_group_unchosen", group_id, current_id))
            return true
        "policy_stage_at_least":
            var policy_group := str(req.get("group_id", ""))
            var stage := int(req.get("stage", 0))
            if game_state.has_method("_is_policy_stage_at_least"):
                return bool(game_state.call("_is_policy_stage_at_least", policy_group, stage))
            return true
        "item_owned_at_least":
            var item_id := _get_item_id(req)
            if item_id == "":
                return false
            var needed_count := _get_item_needed_count(req)
            var owned_count := _get_item_owned_count(game_state, item_id)
            return owned_count >= needed_count
        _:
            return false


static func _get_upgrade_id(req: Dictionary) -> String:
    var upgrade_id := str(req.get("upgrade_id", ""))
    if upgrade_id != "":
        return upgrade_id
    var value = req.get("value", null)
    if typeof(value) == TYPE_STRING:
        return str(value)
    return ""


static func _get_item_id(req: Dictionary) -> String:
    var item_id := str(req.get("item_id", ""))
    if item_id != "":
        return item_id
    var value = req.get("value", null)
    if typeof(value) == TYPE_STRING:
        return str(value)
    return ""


static func _get_item_needed_count(req: Dictionary) -> int:
    if req.has("count"):
        return int(req.get("count", 1))
    if req.has("qty"):
        return int(req.get("qty", 1))
    if req.has("amount"):
        return int(req.get("amount", 1))
    var value = req.get("value", null)
    if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
        return int(value)
    return 1


static func _get_item_owned_count(game_state: Object, item_id: String) -> int:
    if game_state.has_method("get_item_owned_count"):
        return int(game_state.call("get_item_owned_count", item_id))
    if game_state.has_method("get_item_count"):
        return int(game_state.call("get_item_count", item_id))
    if game_state.has_method("has_item"):
        return 1 if bool(game_state.call("has_item", item_id)) else 0
    if _has_property(game_state, "inventory"):
        var inventory: Dictionary = game_state.get("inventory")
        if typeof(inventory) == TYPE_DICTIONARY:
            return int(inventory.get(item_id, 0))
    return 0


static func _has_property(game_state: Object, property_name: String) -> bool:
    for prop in game_state.get_property_list():
        if str(prop.get("name", "")) == property_name:
            return true
    return false
