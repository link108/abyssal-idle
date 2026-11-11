extends RefCounted

# Recipe tags that describe a tin but are never produced by any input.
# They are display-only: excluded from silhouette scoring and hints.
const DISPLAY_ONLY_RECIPE_TAGS := [
    "starter",
    "simple",
    "comfort",
    "bulk",
    "snack",
    "savory",
    "meaty",
    "sausaged"
]

# Tags nearly every attempt produces; too common to identify a recipe.
const GENERIC_SILHOUETTE_TAGS := [
    "clean",
    "cleaned",
    "cut",
    "mixed",
    "packed",
    "sealed",
    "seasoning",
    "preservation",
    "liquid",
    "salty",
    "raw",
    "unstable",
    "putrid"
]

const MAX_RECIPE_ADDONS := 4


static func is_display_only(tag: String) -> bool:
    return DISPLAY_ONLY_RECIPE_TAGS.has(tag)


static func is_generic(tag: String) -> bool:
    return GENERIC_SILHOUETTE_TAGS.has(tag)
