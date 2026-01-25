extends Control


const SELL_INTERVAL := 1.0  # seconds

@onready var fishing_screen := $ModalLayer/FishingScreen
@onready var cannery_screen := $ModalLayer/CanneryScreen
@onready var upgrade_screen := $ModalLayer/UpgradeScreen
@onready var fish_label := $FishLabel
@onready var tin_label := $TinLabel
@onready var money_label := $MoneyLabel
@onready var lifetime_earnings_label := $LifetimeEarningsLabel
@onready var cannery_button := $CanneryButton


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    GameState.changed.connect(_update_hud)
    
    fishing_screen.fish_caught.connect(_on_fish_caught)
    cannery_screen.make_tin_requested.connect(_on_make_tin_requested)
    upgrade_screen.unlock_cannery_requested.connect(_on_unlock_cannery_requested)
    GameState.cannery_unlocked.connect(_on_cannery_unlocked)
    var sell_timer := Timer.new()
    sell_timer.wait_time = SELL_INTERVAL
    sell_timer.autostart = true
    sell_timer.timeout.connect(_on_sell_tick)
    add_child(sell_timer)
    cannery_button.visible = GameState.is_cannery_unlocked
    _update_hud()

func _on_sell_tick() -> void:
    GameState.sell_tick()

func _update_hud() -> void:
    fish_label.text = "Fish: %d" % GameState.fish_count
    tin_label.text = "Tins: %d" % GameState.tin_count
    money_label.text = "Money: $%d" % GameState.money
    lifetime_earnings_label.text = "Total Earnings: $%d" % GameState.lifetime_money_earned

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass

func _on_fish_caught(amount: int) -> void:
    GameState.catch_fish(amount)

func _on_unlock_cannery_requested() -> void:
    GameState.purchase_unlocked_cannery()

func _on_cannery_unlocked() -> void:
    cannery_button.show()

func _on_make_tin_requested() -> void:
    GameState.make_tin()
    
func _on_boat_button_pressed() -> void:
    print("Boat clicked")
    $ModalLayer/Dimmer.show()
    $ModalLayer/FishingScreen.show()

func _on_cannery_button_pressed() -> void:
    $ModalLayer/Dimmer.show()
    $ModalLayer/CanneryScreen.show()

func _on_upgrade_button_pressed() -> void:
    $ModalLayer/Dimmer.show()
    $ModalLayer/UpgradeScreen.show()


func _on_market_button_pressed() -> void:
    $ModalLayer/Dimmer.show()
    $ModalLayer/MarketScreen.show()
