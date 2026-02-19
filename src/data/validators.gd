extends RefCounted

# TODO: Add schema-level validation for all data/raw JSON files.
# TODO: Validate cross-file references (fish ids, item ids, upgrade ids).
# TODO: Provide editor/dev-friendly error formatting.

static func validate_entry(_entry: Dictionary, _context: Dictionary = {}) -> Array:
    # Return an array of warning/error strings.
    return []


static func validate_file(_path: String, _entries: Array) -> Array:
    # Return an array of warning/error strings.
    return []
