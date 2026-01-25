extends PanelContainer

signal unlock_cannery_requested
@onready var unlock_cannery_btn := $Control/UnlockCanneryButton

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
    GameState.changed.connect(_refresh)
    _refresh()



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
    pass


func _on_close_button_close_requested() -> void:
    get_parent().get_node("Dimmer").hide()
    hide()


func _on_unlock_cannery_button_pressed() -> void:
    unlock_cannery_requested.emit()
    
func _refresh() -> void:
    # Visibility: only when discovered AND not purchased
    unlock_cannery_btn.visible = GameState.cannery_upgrade_is_visible()

    if not unlock_cannery_btn.visible:
        return

    # Clickable state
    unlock_cannery_btn.disabled = not GameState.can_purchase_cannery()

    # Text: show cost or remaining amount
    if GameState.can_purchase_cannery():
        unlock_cannery_btn.text = "Unlock Cannery ($%d)" % GameState.CANNERY_UNLOCK_COST
    else:
        var remaining := GameState.CANNERY_UNLOCK_COST - GameState.money
        unlock_cannery_btn.text = "Unlock Cannery (Need $%d)" % remaining
