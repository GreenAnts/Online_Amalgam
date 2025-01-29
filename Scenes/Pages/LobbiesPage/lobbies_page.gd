extends Control

@onready var no_lobby_notice = $VBoxContainer/MarginContainer/NoLobbyNotice
@onready var lobby_list = $VBoxContainer/MarginContainer/ScrollContainer/CenterContainer/LobbyList
@onready var timer = $UpdateTimer
@onready var timer_label = $HBoxContainer/TimerText
@onready var game_mode_options = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/GameModeOptions
@onready var restrictions_options = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/RestrictionsOptions
@onready var time_options = $VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/TimeOptions

#@onready var lobby_data_scene = preload("res://Scenes/Pages/LobbyData/LobbyData.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SignalBus.clear_lobbies.connect(on_clear_lobby_list)
	SignalBus.add_lobby_data.connect(on_add_lobby_data)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if self.visible == true:
		if lobby_list.get_child_count() == 0:
			no_lobby_notice.visible = true
		else:
			no_lobby_notice.visible = false
		timer_label.text = str(int(timer.time_left))
	

func _on_timer_timeout() -> void:
	if self.visible == true:
		print("Fetching an Updated Lobby List...")
		SignalBus.update_lobby_listings.emit()

# Signaled from NetworkingHandler
func on_clear_lobby_list():
	for lobby in lobby_list.get_children():
		lobby.queue_free()

# Signaled from NetworkingHandler [_on_lobby_match_list]
func on_add_lobby_data(lobby_data) -> void:
	# Add the new lobby to the list
	lobby_list.add_child(lobby_data)

func _on_create_lobby_pressed() -> void:
	# Select the type of Game Mode (eg: Sandbox or Standard)
	NetworkingHandler.game_mode = game_mode_options.button_pressed
	# restrictions and time_limit: Value based on order of item index in button
	NetworkingHandler.restrictions = restrictions_options.selected
	# Time Limits: 0, 5, 10, 15, 20, 30
	NetworkingHandler.time_limit = time_options.selected
	NetworkingHandler.create_lobby()

func _on_refresh_lobbies_list_pressed() -> void:
	NetworkingHandler.get_lobby_list()
	timer.stop()
	timer.start()
