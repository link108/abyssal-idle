extends RefCounted

const FishModel = preload("res://src/data/models/fish.gd")

# TODO: Move fish parsing out of GameState into this loader.
# TODO: Call shared validators before constructing models.

static func load_fish_defs(_path: String) -> Array:
    # Placeholder loader returning typed-ish model instances.
    return []


static func create_model(data: Dictionary) -> RefCounted:
    var model = FishModel.new()
    model.from_dict(data)
    return model
