extends RefCounted

# Shared player-facing text for upgrade/skill effects.

static func format_effects(effects: Array) -> Array:
    var lines: Array = []
    for effect in effects:
        if typeof(effect) != TYPE_DICTIONARY:
            continue
        lines.append(format_effect_line(str(effect.get("type", "")), effect.get("value", 0)))
    return lines


static func format_effect_line(effect_type: String, value) -> String:
    match effect_type:
        "fish_sell_add":
            return "Fish sell %s" % _signed_int(value)
        "tin_sell_add":
            return "Tin sell %s" % _signed_int(value)
        "fish_sell_count_add":
            return "Fish sold/tick %s" % _signed_int(value)
        "catch_add":
            return "Catch %s" % _signed_int(value)
        "catch_mult":
            return "Catch %s" % _signed_pct(value)
        "crew_trip_catch_add":
            return "Crew catch %s" % _signed_int(value)
        "crew_trip_duration_mult":
            return "Crew trip time %s" % _signed_pct(value)
        "green_zone_add_pct":
            return "Green zone %s" % _signed_pct(value)
        "tin_time_add":
            var secs := float(value)
            if secs < 0.0:
                return "Tin time %0.2fs" % secs
            return "Tin time +%0.2fs" % secs
        "ocean_pressure_mult":
            return "Ocean pressure %s" % _signed_pct(value)
        "ocean_regen_mult":
            return "Ocean regen %s" % _signed_pct(value)
        "reputation_gain_mult":
            return "Reputation gain %s" % _signed_pct(value)
        "auto_tin":
            return "Auto-tins"
        "crew_auto_send":
            return "Crew auto-sends"
        "unlock_cannery":
            return "Unlocks cannery"
        _:
            return "%s: %s" % [effect_type, str(value)]


static func is_ocean_effect(effect_type: String) -> bool:
    return effect_type == "ocean_pressure_mult" or effect_type == "ocean_regen_mult"


static func _signed_int(value) -> String:
    var v := int(value)
    if v >= 0:
        return "+%d" % v
    return "%d" % v


static func _signed_pct(value) -> String:
    var pct := int(round(float(value) * 100.0))
    if pct >= 0:
        return "+%d%%" % pct
    return "%d%%" % pct
