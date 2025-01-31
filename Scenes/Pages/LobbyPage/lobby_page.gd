extends Control

@onready var start_timer = $StartTimer
@onready var chat = $HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/VBoxContainer/ScrollContainer/MatchLobbyChat
@onready var message = $HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/VBoxContainer/MatchLobbyMessage
@onready var send_message = $HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/VBoxContainer/SendMessage
@onready var start_btn = $HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer2/StartMatch
@onready var lobby_page_chat = $HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/VBoxContainer/ScrollContainer/MatchLobbyChat
@onready var player_one_label = $HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer/Control/PlayerOneData/VBoxContainer/PlayerOneName
@onready var player_two_label = $HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer2/Control/PlayerOneData/VBoxContainer/PlayerTwoName
@onready var player_one_avatar = $HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer/Control/PlayerOneData/PlayerOneAvatar
@onready var player_two_avatar = $HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer2/Control/PlayerOneData/PlayerTwoAvatar



func _ready() -> void:
	SignalBus.add_chat_message.connect(on_add_chat_message)
	SignalBus.update_lobby_player_info.connect(on_update_lobby_player_info)
	SignalBus.set_timer.connect(set_timer)
	SignalBus.start_match.connect(start_match)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Used to handle the timer and button text
	# If the timer is started
	if start_timer.is_stopped() == false:
		# Change Start Btn text to be the time left
		start_btn.text = (str(int(start_timer.time_left)))
		# Change the start button color
		start_btn.modulate = Color("775588")

# Signaled from NetworkHandler
func on_update_lobby_player_info(lobby_id: int):
	player_one_label.text = str(Global.steam_username)
	if NetworkingHandler.lobby_members.size() > 1:
		# Loop through all members that aren't you
		for this_member in NetworkingHandler.lobby_members:
			if this_member['steam_id'] != Global.steam_id:
				player_two_label.text = this_member['steam_name']
				NetworkingHandler.opponent_id = this_member['steam_id']
		start_btn.disabled = false
	else:
		player_two_label.text = "Waiting for Player..."
		start_btn.disabled = true

# CHAT
# Handle inputs within the chat message textbox
func _on_match_lobby_message_gui_input(event: InputEvent) -> void:
	# If "Enter" is pressed
	if event.is_action_pressed("ui_text_completion_accept"):
		# Handle the input and don't use "enter" to handle any other events that may trigger
		get_viewport().set_input_as_handled()
		# Send the message via the Network Handler
		_on_send_message_pressed()

# Signaled from NetworkHandler
func on_add_chat_message(message) -> void:
	if self.visible == true:
		lobby_page_chat.add_child(message)

# START MATCH
func _on_start_match_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_request_set_timer(true)
		set_timer(true)
	else:
		_request_set_timer(false)
		set_timer(false)

# Timer Setting
func set_timer(start_or_stop : bool) -> void:
	var start_timer = $StartTimer
	if start_or_stop == true:
		start_timer.start()
		message.visible = false
		send_message.visible = false
	else:
		start_timer.stop()
		reset_start_btn()

func reset_start_btn():
	start_btn.text = ("Start Match")
	start_btn.modulate = Color("ffffff")
	start_btn.button_pressed = false
	message.visible = true
	send_message.visible = true

# Actually Start the Match
func start_match():
	print("starting the match")
	# Exit the Menus and start the match
	# Probably not the best way to do this. I'll look into it more later. Maybe search from the top down...start at root?
	# maybe "get_tree()"?
	# Add Gameplay Scene
	var gameplay = Global.gameplay_scene.instantiate()
	self.get_parent().get_parent().get_node("GameplayWrapper").add_child(gameplay)
	# Change visibility of scenes
	SignalBus.change_pages.emit("gameplay")
	reset_start_btn()
	
func _on_start_timer_timeout() -> void:
	_request_start_match()
	#start_match()

func _on_send_message_pressed() -> void:
	# Get the entered chat message with username attached
	var this_message: String = message.get_text()
	# If there is even a message
	if this_message.strip_edges().length() > 0:
		# Pass the message to Steam
		var was_sent: bool = Steam.sendLobbyChatMsg(NetworkingHandler.lobby_id, str(Global.steam_username) + ": " + this_message)
		# Was it sent successfully?
		if not was_sent:
			print("ERROR: Chat message failed to send.")
	# Clear the chat input
	message.clear()

func _on_leave_lobby_pressed() -> void:
	# If in a lobby, leave it
	if NetworkingHandler.lobby_id != 0:
		_on_start_match_toggled(false)
		# Disconnect from the Steam Lobby
		NetworkingHandler.leave_lobby()
		# Clear the chat to be used in the next lobby
		for child in lobby_page_chat.get_children():
			child.queue_free()
		# Remove outdated lobbies listed
		SignalBus.clear_lobbies.emit()
		# Change pages from LobbyPage to the LobbiesPage via signal to main.gd
		SignalBus.change_pages.emit("lobbies")
		# Refresh list of other lobbies available
		await(get_tree().create_timer(1).timeout)
		NetworkingHandler.get_lobby_list()

##################
#  P2P REQUESTS  #
##################
# Send Requests to the other player to start the match timer
func _request_set_timer(start_or_stop : bool) -> void:
	if start_or_stop == true:
		print("Starting Timer: Counting down until match start")
		NetworkingHandler.send_message(0, {"timer": "start_timer", "from": Global.steam_id})
	else:
		print("Stopping Timer: Aborting match start")
		NetworkingHandler.send_message(0, {"timer": "stop_timer", "from": Global.steam_id})

# Actually start match
func _request_start_match() -> void:
	print("Match Starting: Requesting a transition from lobby page to gameplay scene")
	NetworkingHandler.send_message(0, {"start_match": "true", "from": Global.steam_id})
