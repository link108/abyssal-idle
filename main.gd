extends Control


const SELL_INTERVAL := 1.0  # seconds
const AUTOSAVE_INTERVAL := 30.0

@onready var fishing_screen := $ModalLayer/FishingScreen
@onready var cannery_screen := $ModalLayer/CanneryScreen
@onready var upgrade_screen := $ModalLayer/UpgradeScreen
@onready var start_screen := $ModalLayer/StartScreen
@onready var inventory_screen := $ModalLayer/InventoryScreen
@onready var market_screen := $ModalLayer/MarketScreen
@onready var crew_screen := $ModalLayer/CrewScreen
@onready var skill_tree_screen := $ModalLayer/SkillTreeScreen
@onready var collections_screen := $ModalLayer/CollectionsScreen
@onready var fish_label := $FishLabel
@onready var tin_label := $TinLabel
@onready var money_label := $MoneyLabel
@onready var lifetime_earnings_label := $LifetimeEarningsLabel
@onready var reputation_label := $ReputationLabel
@onready var ocean_health_bar := $OceanHealthBar
@onready var ocean_health_fill := $OceanHealthBar/OceanHealthFill
@onready var cannery_button := $CanneryButton
@onready var crew_button := $CrewButton
@onready var crew_progress := $CrewProgress
@onready var crew_status_label := $CrewStatusLabel
@onready var crew_select_button := $CrewSelectButton
@onready var prestige_button := $PrestigeButton
@onready var prestige_confirm := $PrestigeConfirm
@onready var ending_screen := $ModalLayer/EndingScreen
@onready var ending_title := $ModalLayer/EndingScreen/EndingVBox/EndingTitle
@onready var ending_subtitle := $ModalLayer/EndingScreen/EndingVBox/EndingSubtitle
@onready var ending_stats := $ModalLayer/EndingScreen/EndingVBox/EndingStats
@onready var ending_hint := $ModalLayer/EndingScreen/EndingVBox/EndingHint

var sell_timer: Timer
var autosave_timer: Timer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    GameState.changed.connect(_update_hud)
    GameState.crew_trip_updated.connect(_update_crew_ui)
    GameState.ocean_health_changed.connect(_update_ocean_health_ui)
    GameState.ending_reached.connect(_on_ending_reached)
    
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
    reputation_label.text = "Reputation: %d (Prestige: %d)" % [
        int(GameState.meta_state.get("reputation", 0)),
        int(GameState.meta_state.get("prestige_count", 0))
    ]
    cannery_button.visible = GameState.is_cannery_unlocked
    _update_ocean_health_ui()
    _update_prestige_button()
    _update_crew_ui()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    _update_crew_ui()

func _on_fish_caught(amount: int) -> void:
    GameState.catch_fish(amount)


func _on_cannery_unlocked() -> void:
    cannery_button.show()

func _on_make_tin_requested() -> void:
    # Cannery screen handles tin creation (method/ingredient).
    pass
    
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

func _on_skill_tree_button_pressed() -> void:
    $ModalLayer/Dimmer.show()
    skill_tree_screen.show()

func _on_market_button_pressed() -> void:
    $ModalLayer/Dimmer.show()
    $ModalLayer/MarketScreen.show()

func _on_prestige_button_pressed() -> void:
    if not GameState.can_prestige():
        return
    var rep_gain := GameState.get_prestige_reputation_gain()
    prestige_confirm.dialog_text = "Prestige now?\nGain reputation: %d" % rep_gain
    prestige_confirm.popup_centered()

func _on_prestige_confirmed() -> void:
    if GameState.prestige():
        _update_hud()

func _on_inventory_button_pressed() -> void:
    $ModalLayer/Dimmer.show()
    inventory_screen.show()

func _on_collections_button_pressed() -> void:
    $ModalLayer/Dimmer.show()
    collections_screen.show()

func _on_load_requested() -> void:
    GameState.load_game()
    if GameState.get_ending_state() != GameState.EndingState.NONE:
        _show_ending_screen(GameState.get_ending_state(), GameState.get_run_summary())
        return
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

func _update_prestige_button() -> void:
    prestige_button.visible = true
    var progress := GameState.get_prestige_progress()
    if GameState.can_prestige():
        prestige_button.text = "Prestige"
        prestige_button.disabled = false
    else:
        prestige_button.text = "Prestige (%d/%d)" % [progress, GameState.PRESTIGE_TINS_REQUIRED]
        prestige_button.disabled = true

func _update_ocean_health_ui() -> void:
    var ratio: float = GameState.get_ocean_health_ratio()
    var bar_size: Vector2 = ocean_health_bar.size
    ocean_health_fill.set_deferred("size", Vector2(bar_size.x * ratio, bar_size.y))
    ocean_health_fill.color = _get_ocean_health_color(ratio)

func _get_ocean_health_color(ratio: float) -> Color:
    var clamped: float = clamp(ratio, 0.0, 1.0)
    var red: Color = Color(0.9, 0.2, 0.2, 0.9)
    var green: Color = Color(0.2, 0.8, 0.3, 0.9)
    var blue: Color = Color(0.2, 0.6, 1.0, 0.9)
    if clamped < 0.5:
        return red.lerp(green, clamped / 0.5)
    return green.lerp(blue, (clamped - 0.5) / 0.5)

func _start_game() -> void:
    start_screen.hide()
    $ModalLayer/Dimmer.hide()
    ending_screen.hide()
    GameState.set_run_paused(false)
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

func _on_ending_reached(ending_id: int, summary: Dictionary) -> void:
    _show_ending_screen(ending_id, summary)

func _show_ending_screen(ending_id: int, summary: Dictionary) -> void:
    _stop_game_timers()
    GameState.set_run_paused(true)
    fishing_screen.hide()
    cannery_screen.hide()
    upgrade_screen.hide()
    market_screen.hide()
    crew_screen.hide()
    inventory_screen.hide()
    collections_screen.hide()
    skill_tree_screen.hide()
    ending_title.text = _get_ending_title(ending_id)
    ending_subtitle.text = _get_ending_subtitle(ending_id)
    ending_stats.text = _format_ending_stats(summary)
    ending_hint.text = "New Game+ will be available after completion."
    $ModalLayer/Dimmer.show()
    ending_screen.show()

func _on_ending_return_pressed() -> void:
    $ModalLayer/Dimmer.hide()
    ending_screen.hide()
    start_screen.show()

func _stop_game_timers() -> void:
    if sell_timer != null:
        sell_timer.stop()
    if autosave_timer != null:
        autosave_timer.stop()

func _format_ending_stats(summary: Dictionary) -> String:
    var time_seconds: float = float(summary.get("time_seconds", 0.0))
    var fish_sold: int = int(summary.get("fish_sold", 0))
    var tins_sold: int = int(summary.get("tins_sold", 0))
    var money: int = int(summary.get("lifetime_money_earned", 0))
    var avg_health: float = float(summary.get("avg_ocean_health_ratio", 0.0))
    var final_health: float = float(summary.get("final_ocean_health_ratio", 0.0))
    var prestige_count: int = int(summary.get("prestige_count", 0))
    return "Time: %s\nFish sold: %d\nTins sold: %d\nLifetime earnings: $%d\nAvg ocean health: %s\nFinal ocean health: %s\nPrestige count: %d" % [
        _format_time(time_seconds),
        fish_sold,
        tins_sold,
        money,
        _format_percent(avg_health),
        _format_percent(final_health),
        prestige_count
    ]

func _format_time(seconds: float) -> String:
    var total: int = int(floor(seconds))
    var hours: int = total / 3600
    var minutes: int = (total % 3600) / 60
    return "%dh %dm" % [hours, minutes]

func _format_percent(ratio: float) -> String:
    return "%d%%" % int(round(clamp(ratio, 0.0, 1.0) * 100.0))

func _get_ending_title(ending_id: int) -> String:
    match ending_id:
        GameState.EndingState.INDUSTRIAL_COLLAPSE:
            return "Industrial Collapse"
        GameState.EndingState.SUSTAINABLE_EQUILIBRIUM:
            return "Sustainable Equilibrium"
        GameState.EndingState.DUAL_MASTERY:
            return "Dual Mastery"
        _:
            return "Ending Reached"

func _get_ending_subtitle(ending_id: int) -> String:
    match ending_id:
        GameState.EndingState.INDUSTRIAL_COLLAPSE:
            return "The ocean could not withstand the extraction."
        GameState.EndingState.SUSTAINABLE_EQUILIBRIUM:
            return "A steady balance holds between harvest and renewal."
        GameState.EndingState.DUAL_MASTERY:
            return "Both paths culminate in a legendary catch."
        _:
            return "Your run has concluded."
