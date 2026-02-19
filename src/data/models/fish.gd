extends RefCounted

var fish_id: String = ""
var display_name: String = ""
var requires: Array = []

func from_dict(data: Dictionary) -> void:
    fish_id = str(data.get("fish_id", ""))
    display_name = str(data.get("display_name", ""))
    requires = data.get("requires", [])
