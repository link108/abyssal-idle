extends "res://tests/headless/test_base.gd"


func run_tests(gs) -> void:
    _test_experimental_prices(gs)
    _test_recipe_prices(gs)
    _test_sell_by_key(gs)
    _test_sell_random(gs)
    _test_inventory_entries(gs)
    _test_value_text(gs)


func _test_experimental_prices(gs) -> void:
    var rough: int = gs.get_tin_sell_price_for_key("experimental_tin_rough")
    var odd: int = gs.get_tin_sell_price_for_key("experimental_tin_odd")
    var stable: int = gs.get_tin_sell_price_for_key("experimental_tin_stable")
    check(rough < odd and odd < stable, "rough < odd < stable ($%d, $%d, $%d)" % [rough, odd, stable])
    check(stable == gs.get_tin_sell_price(), "stable experimental tin sells at the base price")
    check(gs.get_tin_sell_price_for_key("raw|salt") == gs.get_tin_sell_price(), "legacy tin keys sell at the base price")


func _test_recipe_prices(gs) -> void:
    var unprofitable: Array = []
    var below_base: Array = []
    for recipe_def in gs.recipe_defs:
        var recipe_id := str(recipe_def.get("recipe_id", ""))
        var fish_id: String = gs._get_recipe_fish_id(recipe_def)
        var addon_cost := 0
        for item_id in gs.get_recipe_addon_ids(recipe_def):
            addon_cost += gs.get_item_cost(str(item_id))
        var price: int = gs.get_tin_sell_price_for_key(recipe_id)
        var tinned: int = price * gs.get_fish_cannery_yield(fish_id)
        if tinned <= gs.get_fish_sell_price_for_id(fish_id) + addon_cost:
            unprofitable.append(recipe_id)
        if price <= gs.get_tin_sell_price():
            below_base.append(recipe_id)
    check(unprofitable.is_empty(), "every recipe beats selling the fish raw plus add-on costs %s" % str(unprofitable))
    check(below_base.is_empty(), "every recipe tin beats the base tin price %s" % str(below_base))

    # Same fish, rarer recipe, sells for more per unit of input.
    var common: Dictionary = gs.recipe_defs_by_id["lanternjaw_black_salt_brine"]
    var rare: Dictionary = gs.recipe_defs_by_id["pickled_lanternjaw_tongue_murk_vinegar"]
    check(gs.RECIPE_TIN_RARITY_MARGINS[str(rare["rarity"])] > gs.RECIPE_TIN_RARITY_MARGINS[str(common["rarity"])], "rarer recipe has a higher margin")
    check(gs.get_recipe_tin_price("pickled_lanternjaw_tongue_murk_vinegar") > gs.get_recipe_tin_price("lanternjaw_black_salt_brine"), "rare lanternjaw tin sells above the common one")


func _test_sell_by_key(gs) -> void:
    var recipe_id := "choirfin_golden_oil"
    gs.tin_inventory = {recipe_id: 3, "experimental_tin_rough": 2}
    gs.tin_count = 5
    gs.tins_sold = 0
    gs.money = 0
    var price: int = gs.get_recipe_tin_price(recipe_id)
    check(gs.sell_tins_by_key(recipe_id, 2) == 2, "sells two recipe tins")
    check(gs.money == price * 2, "earns the recipe price for each ($%d, want $%d)" % [gs.money, price * 2])
    check(int(gs.tin_inventory[recipe_id]) == 1 and gs.tin_count == 3 and gs.tins_sold == 2, "inventory, tin count and tins sold update")
    check(gs.sell_tins_by_key(recipe_id, 5) == 1, "can't sell more than owned")
    check(not gs.tin_inventory.has(recipe_id), "sold-out kind is removed")
    check(gs.sell_tins_by_key("nothing_here", 1) == 0, "unknown kind sells nothing")


func _test_sell_random(gs) -> void:
    gs.tin_inventory = {"experimental_tin_rough": 2, "gloommaw_blood_sausage": 1}
    gs.tin_count = 3
    gs.money = 0
    var want: int = 2 * gs.get_tin_sell_price_for_key("experimental_tin_rough") + gs.get_recipe_tin_price("gloommaw_blood_sausage")
    check(gs.sell_tins(3) == 3, "sell_tins sells every tin")
    check(gs.money == want, "sell_tins prices each tin by its kind ($%d, want $%d)" % [gs.money, want])

    gs.tin_inventory = {"gloommaw_blood_sausage": 1}
    gs.tin_count = 1
    gs.money = 0
    gs.sell_mode = gs.SellMode.TINS
    gs.sell_tick()
    check(gs.money == gs.get_recipe_tin_price("gloommaw_blood_sausage"), "auto-sell prices the tin by its kind")


func _test_inventory_entries(gs) -> void:
    gs.tin_inventory = {"experimental_tin_odd": 4, "choirfin_golden_oil": 2}
    gs.tin_count = 6
    var tins: Array = []
    for entry in gs.get_inventory_entries(false):
        if str(entry.get("type", "")) == "tin":
            tins.append(entry)
    check(tins.size() == 2, "one inventory entry per tin kind")
    check(str(tins[0]["id"]) == "choirfin_golden_oil", "most valuable kind is listed first")
    check(int(tins[0]["sell_value"]) == gs.get_recipe_tin_price("choirfin_golden_oil") and str(tins[0]["rarity"]) == "Common", "recipe entry carries its price and rarity")
    check(str(tins[1]["rarity"]) == "Experimental", "experimental entry is marked experimental")
    gs.tin_inventory = {}
    gs.tin_count = 0


func _test_value_text(gs) -> void:
    gs.meta_state["discovered_recipe_ids"] = []
    gs.tin_fish_id = "choirfin_seraph"
    gs.tin_ingredient_ids = []
    var text: String = gs.get_tin_value_text()
    check(text.begins_with("Experiments make 3 tins") and text.contains("Its recipes sell for"), "undiscovered selection shows experimental and recipe prices: '%s'" % text)

    gs._mark_recipe_discovered("choirfin_golden_oil")
    gs.apply_recipe_to_selection("choirfin_golden_oil")
    var price: int = gs.get_recipe_tin_price("choirfin_golden_oil")
    text = gs.get_tin_value_text()
    check(text.contains("$%d each" % price) and text.contains("Raw fish: $120"), "known recipe shows its tin price and the raw price: '%s'" % text)
    gs.meta_state["discovered_recipe_ids"] = []
    gs.tin_fish_id = ""
    check(gs.get_tin_value_text() == "", "no value text without a fish")
