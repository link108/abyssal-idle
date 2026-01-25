extends Control


const SELL_INTERVAL := 1.0  # seconds
const AUTOSAVE_INTERVAL := 30.0

@onready var fishing_screen := $ModalLayer/FishingScreen
@onready var cannery_screen := $ModalLayer/CanneryScreen
@onready var upgrade_screen := $ModalLayer/UpgradeScreen
@onready var start_screen := $ModalLayer/StartScreen
@onready var fish_label := $FishLabel
@onready var tin_label := $TinLabel
@onready var money_label := $MoneyLabel
@onready var lifetime_earnings_label := $LifetimeEarningsLabel
@onready var cannery_button := $CanneryButton
@onready var crew_button := $CrewButton
@onready var crew_progress := $CrewProgress
@onready var crew_status_label := $CrewStatusLabel
@onready var crew_select_button := $CrewSelectButton

var sell_timer: Timer
var autosave_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    GameState.changed.connect(_update_hud)
    GameState.crew_trip_updated.connect(_update_crew_ui)
    
    fishing_screen.fish_caught.connect(_on_fish_caught)
    cannery_screen.make_tin_requested.connect(_on_make_tin_requested)
    GameState.cannery_unlocked.connect(_on_cannery_unlocked)
    start_screen.load_requested.connect(_on_load_requested)
    start_screen.new_requested.connect(_on_new_requested)
    start_screen.set_has_save(GameState.save_exists())
    cannery_button.visible = GameState.is_cannery_unlocked
    _update_hud()
    fishing_screen.visibility_changed.connect(_on_fishing_visibility_changed)

func _on_sell_tick() -> void:
    GameState.sell_tick()

func _on_autosave_tick() -> void:
    GameState.save_game()

func _update_hud() -> void:
    fish_label.text = "Fish: %d" % GameState.fish_count
    tin_label.text = "Tins: %d" % GameState.tin_count
    money_label.text = "Money: $%d" % GameState.money
    lifetime_earnings_label.text = "Total Earnings: $%d" % GameState.lifetime_money_earned
    _update_crew_ui()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    _update_crew_ui()

func _on_fish_caught(amount: int) -> void:
    GameState.catch_fish(amount)


func _on_cannery_unlocked() -> void:
    cannery_button.show()

func _on_make_tin_requested() -> void:
    GameState.make_tin()
    
func _on_boat_button_pressed() -> void:
    print("Boat clicked")
    get_viewport().gui_release_focus()
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

func _on_load_requested() -> void:
    GameState.load_game()
    _start_game()

func _on_new_requested() -> void:
    GameState.new_game()
    _start_game()

func _on_crew_button_pressed() -> void:
    if GameState.crew_unlock_is_visible() and GameState.can_purchase_crew():
        GameState.purchase_unlocked_crew()
        return
    if GameState.is_crew_unlocked:
        GameState.start_crew_trip()

func _on_crew_select_button_pressed() -> void:
    if not GameState.is_crew_unlocked:
        return
    $ModalLayer/Dimmer.show()
    $ModalLayer/CrewScreen.show()

func _on_fishing_visibility_changed() -> void:
    GameState.set_crew_trip_paused(fishing_screen.visible)

func _update_crew_ui() -> void:
    if GameState.is_crew_unlocked:
        crew_button.visible = true
        crew_progress.visible = true
        crew_status_label.visible = true
        crew_select_button.visible = true
        crew_button.text = "Send Crew"
        crew_button.disabled = GameState.crew_trip_active
        if GameState.crew_trip_active:
            crew_status_label.text = "At sea: %ds" % int(ceil(GameState.crew_trip_remaining))
            crew_progress.value = GameState.get_crew_trip_progress()
        else:
            crew_status_label.text = "Ready"
            crew_progress.value = 0.0
    elif GameState.crew_unlock_is_visible():
        crew_button.visible = true
        crew_progress.visible = true
        crew_status_label.visible = true
        crew_select_button.visible = false
        if GameState.can_purchase_crew():
            crew_button.text = "Unlock Crew ($%d)" % GameState.CREW_UNLOCK_COST
            crew_button.disabled = false
            crew_status_label.text = "Crew available"
        else:
            var remaining := GameState.CREW_UNLOCK_COST - GameState.money
            crew_button.text = "Unlock Crew (Need $%d)" % remaining
            crew_button.disabled = true
            crew_status_label.text = "Crew locked"
        crew_progress.value = 0.0
    else:
        crew_button.visible = false
        crew_progress.visible = false
        crew_status_label.visible = false
        crew_select_button.visible = false

func _start_game() -> void:
    start_screen.hide()
    $ModalLayer/Dimmer.hide()
    _ensure_timers()
    _update_hud()

func _ensure_timers() -> void:
    if sell_timer == null:
        sell_timer = Timer.new()
        sell_timer.wait_time = SELL_INTERVAL
        sell_timer.autostart = true
        sell_timer.timeout.connect(_on_sell_tick)
        add_child(sell_timer)
    if autosave_timer == null:
        autosave_timer = Timer.new()
        autosave_timer.wait_time = AUTOSAVE_INTERVAL
        autosave_timer.autostart = true
        autosave_timer.timeout.connect(_on_autosave_tick)
        add_child(autosave_timer)
