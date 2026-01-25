extends Node

signal changed
signal cannery_unlocked
signal cannery_discovered

# Economy
var fish_count: int = 0
var tin_count: int = 0
var money: int = 0

# Upgrades: Cannery
const CANNERY_UNLOCK_COST := 200
const CANNERY_DISCOVERY_EARNED := 50
var is_cannery_discovered: bool = false
var is_cannery_unlocked: bool = false
var lifetime_money_earned: int = 0

# Market
enum SellMode { FISH, TINS }
var sell_mode: SellMode = SellMode.FISH

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass

func catch_fish(amount: int = 1) -> void:
    fish_count += amount
    changed.emit()

func make_tin() -> bool:
    if fish_count <= 0:
        return false
    fish_count -= 1
    tin_count += 1
    changed.emit()
    return true

func _add_money(amount: int) -> void:
    if amount <= 0:
        return
    money += amount
    lifetime_money_earned += amount
    _check_cannery_discovery()
    changed.emit()

func sell_tick() -> void:
    match sell_mode:
        SellMode.FISH:
            if fish_count > 0:
                fish_count -= 1
                _add_money(2)
        SellMode.TINS:
            if tin_count > 0:
                tin_count -= 1
                _add_money(10)
    changed.emit()

#########
# Cannery
#########
func _check_cannery_discovery() -> void:
    if is_cannery_discovered:
        return
    if lifetime_money_earned >= CANNERY_DISCOVERY_EARNED:
        is_cannery_discovered = true
        cannery_discovered.emit()
        changed.emit()

func cannery_upgrade_is_visible() -> bool:
    # Visible only when discovered and not already purchased
    return is_cannery_discovered and (not is_cannery_unlocked)        

func can_purchase_cannery() -> bool:
    # Clickable when visible + you have enough money
    return cannery_upgrade_is_visible() and money >= CANNERY_UNLOCK_COST

func purchase_unlocked_cannery() -> bool:
    if not can_purchase_cannery():
        return false
    money -= CANNERY_UNLOCK_COST
    is_cannery_unlocked = true
    cannery_unlocked.emit()
    return true
