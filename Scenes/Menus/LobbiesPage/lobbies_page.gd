extends Control

@onready var no_lobby_notice = $VBoxContainer/MarginContainer/NoLobbyNotice
@onready var lobby_list = $VBoxContainer/MarginContainer/ScrollContainer/CenterContainer/LobbyList
@onready var timer = $Timer
@onready var timer_label = $HBoxContainer/TimerText

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if self.visible == true:
		if lobby_list.get_child_count() == 0:
			no_lobby_notice.visible = true
		else:
			no_lobby_notice.visible = false
		timer_label.text = str(int(timer.time_left))
	
func _on_timer_timeout() -> void:
	print("Fetching an Updated Lobby List...")
	SignalBus.update_lobby_listings.emit()
