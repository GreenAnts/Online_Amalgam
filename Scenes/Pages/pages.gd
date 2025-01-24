extends Control

# Lobbies (List) Nodes
@onready var lobbies_page = $LobbiesPage
@onready var no_lobby_notice = $LobbiesPage/VBoxContainer/MarginContainer/NoLobbyNotice
@onready var lobby_list = $LobbiesPage/VBoxContainer/MarginContainer/ScrollContainer/CenterContainer/LobbyList
@onready var game_mode_options = $LobbiesPage/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/GameModeOptions
@onready var restrictions_options = $LobbiesPage/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/RestrictionsOptions
@onready var time_options = $LobbiesPage/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/TimeOptions
# Lobby Nodes
@onready var lobby_page = $LobbyPage
@onready var lobby_page_chat = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/VBoxContainer/ScrollContainer/MatchLobbyChat
@onready var lobby_page_message = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/VBoxContainer/MatchLobbyMessage
@onready var lobby_page_send_message = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/VBoxContainer/SendMessage
@onready var player_one_label = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer/Control/PlayerOneData/VBoxContainer/PlayerOneName
@onready var player_two_label = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer2/Control/PlayerOneData/VBoxContainer/PlayerTwoName
@onready var player_one_avatar = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer/Control/PlayerOneData/PlayerOneAvatar
@onready var player_two_avatar = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer2/Control/PlayerOneData/PlayerTwoAvatar
@onready var start_match = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer2/StartMatch
# Side Panel
@onready var side_panel = $SidePanel
# Scenes
@onready var gameplay_scene = preload("res://Scenes/Gameplay/Gameplay.tscn")
@onready var lobby_data_scene = preload("res://Scenes/Pages/LobbyData/LobbyData.tscn")

const PACKET_READ_LIMIT: int = 32

var lobby_data
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 2
var matchmaking_phase: int = 0
var lobby_vote_kick: bool = false
# are you automatching?
var automatch : bool = false

# Steam ID
# > Global.steam_id
# Steam Username
# > Global.steam_username

# Create Lobby Data > _on_create_lobby_pressed()
var game_mode : int = 0
var time_limit : int = 0
var restrictions : int = 4

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect signals from SignalBus Global
	SignalBus.join_lobby.connect(join_lobby)
	SignalBus.update_lobby_listings.connect(_get_lobby_list)
	
	# Avatar
	Steam.getPlayerAvatar()
	Steam.avatar_loaded.connect(_on_loaded_avatar)
	# Lobbies
	Steam.join_requested.connect(_on_lobby_join_requested)
	Steam.lobby_chat_update.connect(_on_lobby_chat_update)
	Steam.lobby_created.connect(_on_lobby_created)
	#Steam.lobby_data_update.connect(_on_lobby_data_update)
	#Steam.lobby_invite.connect(_on_lobby_invite)
	Steam.lobby_joined.connect(_on_lobby_joined)
	Steam.lobby_match_list.connect(_on_lobby_match_list)
	Steam.lobby_message.connect(_on_lobby_message)
	Steam.persona_state_change.connect(_on_persona_change)
	# P2P
	Steam.network_messages_session_request.connect(_on_network_messages_session_request)
	Steam.network_messages_session_failed.connect(_on_network_messages_session_failed)
	# Check for command line arguments
	check_command_line()

func _process(_delta) -> void:
	# If the player is connected, read packets
	if lobby_id > 0:
		read_messages()

# Avatar
func _on_loaded_avatar(user_id: int, avatar_size: int, avatar_buffer: PackedByteArray) -> void:
	print("Avatar for user: %s" % user_id)
	print("Size: %s" % avatar_size)
	# Create the image and texture for loading
	var avatar_image: Image = Image.create_from_data(avatar_size, avatar_size, false, Image.FORMAT_RGBA8, avatar_buffer)
	# Optionally resize the image if it is too large
	if avatar_size > 128:
		avatar_image.resize(128, 128, Image.INTERPOLATE_LANCZOS)
	# Apply the image to a texture
	var avatar_texture: ImageTexture = ImageTexture.create_from_image(avatar_image)
	# If avatar is players own, assign to panel
	if user_id ==  Global.steam_id:
		side_panel.user_avatar.set_texture_normal(avatar_texture)
	_set_avatars_to_lobby_members(user_id, avatar_texture)

func _set_avatars_to_lobby_members(user_id: int, avatar_texture: ImageTexture) -> void:
	for member in lobby_members:
		if member["steam_id"] == user_id:
			member["avatar"] = avatar_texture
			if lobby_id > 0 && member["steam_id"] == Global.steam_id:
				player_one_avatar.set_texture_normal(avatar_texture)
			elif lobby_id > 0 && member["steam_id"] != Global.steam_id:
				player_two_avatar.set_texture_normal(avatar_texture)

#############
#  Lobbies  #
#############
func check_command_line() -> void:
	var these_arguments: Array = OS.get_cmdline_args()
	# There are arguments to process
	if these_arguments.size() > 0:
		# A Steam connection argument exists
		if these_arguments[0] == "+connect_lobby":
			# Lobby invite exists so try to connect to it
			if int(these_arguments[1]) > 0:
				# At this point, you'll probably want to change scenes
				# Something like a loading into lobby screen
				print("Command line lobby ID: %s" % these_arguments[1])
				join_lobby(int(these_arguments[1]))

func create_lobby() -> void:
	# Make sure a lobby is not already set
	if lobby_id == 0:
		Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, lobby_members_max)

func _on_lobby_created(connect: int, this_lobby_id: int) -> void:
	if connect == 1:
		# Set the lobby ID
		lobby_id = this_lobby_id
		print("Created a lobby: %s" % lobby_id)
		# Set this lobby as joinable, just in case, though this should be done by default
		Steam.setLobbyJoinable(lobby_id, true)
		# Set some lobby data
		Steam.setLobbyData(lobby_id, "game", "Amalgam")
		Steam.setLobbyData(lobby_id, "name", str(Global.steam_username))
		Steam.setLobbyData(lobby_id, "time_limit", str(time_limit))
		Steam.setLobbyData(lobby_id, "game_mode", str(game_mode))
		Steam.setLobbyData(lobby_id, "restrictions", str(restrictions))
		# Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: %s" % set_relay)

func _get_lobby_list() -> void:
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	print("Requesting a lobby list")
	Steam.requestLobbyList()

func _clear_lobby_list():
	for lobby in lobby_list.get_children():
		lobby.queue_free()

func _on_lobby_match_list(these_lobbies: Array) -> void:
	# clear the list of lobby from the scene
	_clear_lobby_list()
	if automatch == true:
		_automatch_search(these_lobbies)
	else:
		for this_lobby in these_lobbies:
			if Steam.getLobbyData(this_lobby, "game") == "Amalgam":
				# Pull lobby data from Steam, these are specific to our example
				var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
				var lobby_time_limit: String = Steam.getLobbyData(this_lobby, "time_limit")
				var lobby_game_mode: String = Steam.getLobbyData(this_lobby, "game_mode")
				var lobby_restrictions: String = Steam.getLobbyData(this_lobby, "restrictions")
				# Get the current number of members
				var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)
				# Create a button for the lobby
				var lobby_data = lobby_data_scene.instantiate()
				lobby_data.game_mode = lobby_game_mode
				lobby_data.username = lobby_name
				lobby_data.time_limit = lobby_time_limit
				lobby_data.restrictions = lobby_restrictions
				lobby_data.id = this_lobby
				# Add the new lobby to the list
				lobby_list.add_child(lobby_data)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# If joining was successful
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		SignalBus.change_pages.emit("lobby")
		# Set this lobby ID as your lobby ID
		lobby_id = this_lobby_id
		# Get the lobby members
		get_lobby_members()
		# Make the initial handshake
		make_p2p_handshake()
		_update_lobby_player_info(this_lobby_id)
		# Change from lobby list to match lobby
		lobbies_page.visible = false
		lobby_page.visible = true
		# Join Message into match lobby chat
		var join_message = Label.new()
		join_message.text = ("%s has joined the lobby" % str(Global.steam_username))
		join_message.modulate = Color("0000ff")
		lobby_page_chat.add_child(join_message)
	# Else it failed for some reason
	else:
		# Get the failure reason
		var fail_reason: String
		match response:
			Steam.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST: fail_reason = "This lobby no longer exists."
			Steam.CHAT_ROOM_ENTER_RESPONSE_NOT_ALLOWED: fail_reason = "You don't have permission to join this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_FULL: fail_reason = "The lobby is now full."
			Steam.CHAT_ROOM_ENTER_RESPONSE_ERROR: fail_reason = "Uh... something unexpected happened!"
			Steam.CHAT_ROOM_ENTER_RESPONSE_BANNED: fail_reason = "You are banned from this lobby."
			Steam.CHAT_ROOM_ENTER_RESPONSE_LIMITED: fail_reason = "You cannot join due to having a limited account."
			Steam.CHAT_ROOM_ENTER_RESPONSE_CLAN_DISABLED: fail_reason = "This lobby is locked or disabled."
			Steam.CHAT_ROOM_ENTER_RESPONSE_COMMUNITY_BAN: fail_reason = "This lobby is community locked."
			Steam.CHAT_ROOM_ENTER_RESPONSE_MEMBER_BLOCKED_YOU: fail_reason = "A user in the lobby has blocked you from joining."
			Steam.CHAT_ROOM_ENTER_RESPONSE_YOU_BLOCKED_MEMBER: fail_reason = "A user you have blocked is in the lobby."
		print("Failed to join this chat room: %s" % fail_reason)
		#Reopen the lobby list
		_get_lobby_list()

func _update_lobby_player_info(this_lobby_id: int):
	Steam.getPlayerAvatar()
	player_one_label.text = Global.steam_username
	if lobby_members.size() > 1:
		# Loop through all members that aren't you
		for this_member in lobby_members:
			if this_member['steam_id'] != Global.steam_id:
				player_two_label.text = this_member['steam_name']
		start_match.disabled = false
	else:
		player_two_label.text = "Waiting for Player..."
		start_match.disabled = true

func _on_lobby_join_requested(this_lobby_id: int, friend_id: int) -> void:
	# Get the lobby owner's name
	var owner_name: String = Steam.getFriendPersonaName(friend_id)
	print("Joining %s's lobby..." % owner_name)
	# Attempt to join the lobby
	join_lobby(this_lobby_id)
	
func get_lobby_members() -> void:
	# Clear your previous lobby list
	lobby_members.clear()
	# Get the number of members from this lobby from Steam
	var num_of_members: int = Steam.getNumLobbyMembers(lobby_id)
	# Get the data of these players from Steam
	for this_member in range(0, num_of_members):
		# Get the member's Steam ID
		var member_steam_id: int = Steam.getLobbyMemberByIndex(lobby_id, this_member)
		# Get the member's Steam name
		var member_steam_name: String = Steam.getFriendPersonaName(member_steam_id)
		# Add them to the list
		lobby_members.append({"steam_id":member_steam_id, "steam_name":member_steam_name})
		

# A user's information has changed
func _on_persona_change(this_steam_id: int, _flag: int) -> void:
	# Make sure you're in a lobby and this user is valid or Steam might spam your console log
	if lobby_id > 0:
		print("A user (%s) had information change, update the lobby list" % this_steam_id)
		# Update the player list
		get_lobby_members()

func _on_lobby_chat_update(this_lobby_id: int, change_id: int, making_change_id: int, chat_state: int) -> void:
	# Get the user who has made the lobby change
	var changer_name: String = Steam.getFriendPersonaName(change_id)
	# If a player has joined the lobby
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print("%s has joined the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has joined the lobby." % changer_name
		message.modulate = Color("00ff22")
		lobby_page_chat.add_child(message)
	# Else if a player has left the lobby
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		print("%s has left the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has left the lobby." % changer_name
		message.modulate = Color("ff0000")
		lobby_page_chat.add_child(message)
	# Else if a player has been kicked
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
		print("%s has been kicked from the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has been kicked from the lobby." % changer_name
		message.modulate = Color("8f00ff")
		lobby_page_chat.add_child(message)
	# Else if a player has been banned
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
		print("%s has been banned from the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has been banned from the lobby." % changer_name
		message.modulate = Color("ef224b")
		lobby_page_chat.add_child(message)
	# Else there was some unknown change
	else:
		print("%s did... something." % changer_name)
	# Update the lobby now that a change has occurred
	get_lobby_members()
	_update_lobby_player_info(this_lobby_id)

func _on_lobby_message(this_lobby_id: int, user: int, buffer: String, chat_type: int) -> void:
	print("Message Recieved")
	var message = Label.new()
	message.text = buffer
	lobby_page_chat.add_child(message)
	
####################
#    Auto Match    #
####################
# Iteration for trying different distances
func matchmaking_loop() -> void:
	# If this matchmake_phase is 3 or less, keep going
	if matchmaking_phase < 4:
		###
		# Add other filters for things like game modes, etc.
		# Since this is an example, we cannot set game mode or text match features.
		# However you could use addRequestLobbyListStringFilter to look for specific
		# text in lobby metadata to match different criteria.
		###
		# Set the distance filter
		Steam.addRequestLobbyListDistanceFilter(matchmaking_phase)
		# Request a list
		Steam.requestLobbyList()
	else:
		automatch = false
		print("[STEAM] Failed to automatically match you with a lobby. Please try again.")
		SignalBus.change_pages.emit("quick_match_fail")
		

func _automatch_search(lobbies):
	var attempting_join: bool = false
	# Show the list 
	for this_lobby in lobbies:
		# Pull lobby data from Steam
		var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
		var lobby_nums: int = Steam.getNumLobbyMembers(this_lobby)
		# Due to testing on the demo gameID
		var lobby_game: String = Steam.getLobbyData(this_lobby, "game")
		
		# Attempt to join the first lobby that fits the criteria
		if lobby_game == "Amalgam" && lobby_nums < lobby_members_max and not attempting_join:
			# Turn on attempting_join
			attempting_join = true
			print("Attempting to join lobby...")
			Steam.joinLobby(this_lobby)
			automatch = false
		# No lobbies that matched were found, go onto the next phase
	if not attempting_join:
		# Increment the matchmake_phase
		matchmaking_phase += 1
		matchmaking_loop()

#############
#    P2P    #
#############
func make_p2p_handshake() -> void:
	print("Sending P2P handshake to the lobby")
	send_message(0, {"message": "handshake", "from": Global.steam_id})
	
func _on_network_messages_session_request(remote_id: int) -> void:
	# Get the requester's name
	var this_requester: String = Steam.getFriendPersonaName(remote_id)
	print("%s is requesting a P2P session" % this_requester)
	# Accept the P2P session; can apply logic to deny this request if needed
	Steam.acceptSessionWithUser(remote_id)
	# Make the initial handshake
	make_p2p_handshake()


func send_message(this_target: int, packet_data: Dictionary) -> void:
	# Set the send_type and channel
	var send_type: int = Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE
	var channel: int = 0
	# Create a data array to send the data through
	var this_data: PackedByteArray
	this_data.append_array(var_to_bytes(packet_data).compress(FileAccess.COMPRESSION_GZIP))
	# If sending a packet to everyone
	if this_target == 0:
		# If there is more than one user, send packets
		if lobby_members.size() > 1:
			# Loop through all members that aren't you
			for this_member in lobby_members:
				if this_member['steam_id'] != Global.steam_id:
					Steam.sendMessageToUser(this_member['steam_id'], this_data, send_type, channel)
	# Else send it to someone specific
	else:
		Steam.sendMessageToUser(this_target, this_data, send_type, channel)

func read_messages() -> void:
	var messages: Array = Steam.receiveMessagesOnChannel(0, 1000)
	for message in messages:
		if message.is_empty() or message == null:
			print("WARNING: read an empty message with non-zero size!")
		else:
			message.payload = bytes_to_var(message.payload.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP))
			# Get the remote user's ID
			var message_sender: int = message['identity']
			# Print the packet to output
			print("Message Payload: %s" % message.payload)
			# ########################################### #
			# Append logic here to deal with message data.
			# ########################################### #
			# Start Timer > Countdown to match start
			if message.payload['message'] == "start_timer":
				_set_timer(true)
			# Stop Timer > abort countdown
			elif message.payload['message'] == "stop_timer":
				_set_timer(false)
			# Start Match > transition to gameplay scene
			elif message.payload['message'] == "start_match":
				_start_match()

func _on_network_messages_session_failed(steam_id: int, session_error: int, state: int, debug_msg: String) -> void:
	print(debug_msg)
	
#########################
#    P2P-Start Match    #
#########################
func _request_set_timer(start_or_stop : bool) -> void:
	if start_or_stop == true:
		print("Starting Timer: Counting down until match start")
		send_message(0, {"message": "start_timer", "from": Global.steam_id})
	else:
		print("Stopping Timer: Aborting match start")
		send_message(0, {"message": "stop_timer", "from": Global.steam_id})

func _request_start_match() -> void:
	print("Match Starting: Requesting a transition from lobby page to gameplay scene")
	send_message(0, {"message": "start_match", "from": Global.steam_id})

#############
#  Buttons  #
#############
func _on_create_lobby_pressed() -> void:
	game_mode = game_mode_options.button_pressed
	# restrictions and time_limit: Value based on order of item index in button
	restrictions = restrictions_options.selected
	# Time Limits: 0, 5, 10, 15, 20, 30
	time_limit = time_options.selected
	create_lobby()

func _on_refresh_lobbies_list_pressed() -> void:
	_get_lobby_list()
	lobbies_page.timer.stop()
	lobbies_page.timer.start()


func _on_send_message_pressed() -> void:
	# Get the entered chat message with username attached
	var this_message: String = lobby_page_message.get_text()
	# If there is even a message
	if this_message.strip_edges().length() > 0:
		# Pass the message to Steam
		var was_sent: bool = Steam.sendLobbyChatMsg(lobby_id, str(Global.steam_username) + ": " + this_message)
		# Was it sent successfully?
		if not was_sent:
			print("ERROR: Chat message failed to send.")
	# Clear the chat input
	lobby_page_message.clear()

func _on_leave_lobby_pressed() -> void:
	# If in a lobby, leave it
	if lobby_id != 0:
		# Send leave request to Steam
		Steam.leaveLobby(lobby_id)
		# Wipe the Steam lobby ID then display the default lobby ID and player list title
		lobby_id = 0
		# Close session with all users
		for this_member in lobby_members:
			# Make sure this isn't your Steam ID
			if this_member['steam_id'] != Global.steam_id:
				# Close the P2P session
				Steam.closeP2PSessionWithUser(this_member['steam_id'])
		# Clear the local lobby list
		lobby_members.clear()
		for child in lobby_page_chat.get_children():
			child.queue_free()
		# Hide outdated lobbies listed
		_clear_lobby_list()
		# Change pages from LobbyPage to the LobbiesPage via signal to main.gd
		SignalBus.change_pages.emit("lobbies")
		# Refresh list of other lobbies available
		await(get_tree().create_timer(1).timeout)
		_get_lobby_list()

func _on_start_match_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_request_set_timer(true)
		_set_timer(true)
	else:
		_set_timer(false)
		_set_timer(false)


####################
#  Singal-Buttons  #
####################
# Via Signal from LobbyData JoinLobby Button
func join_lobby(this_lobby_id: int) -> void:
	print("Attempting to join lobby %s" % lobby_id)
	# Clear any previous lobby members lists, if you were in a previous lobby
	lobby_members.clear()
	# Make the lobby join request to Steam
	Steam.joinLobby(this_lobby_id)

func _on_match_lobby_message_gui_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_text_completion_accept"):
		get_viewport().set_input_as_handled()
		_on_send_message_pressed()

func _on_quick_match_pressed() -> void:
	automatch = true
	# Set the matchmaking process to start over
	matchmaking_phase = 0
	# Start the loop!
	matchmaking_loop()

func _on_start_timer_timeout() -> void:
	_start_match()

##########################
#  P2P Triggered Events  #
##########################
func _set_timer(start_or_stop : bool) -> void:
	var start_timer = $LobbyPage/StartTimer
	start_timer.start()
	if start_or_stop == true:
		lobby_page_message.visible = false
		lobby_page_send_message.visible = false
	else:
		start_timer.stop()
		lobby_page_message.visible = true
		lobby_page_send_message.visible = true
		lobby_page.reset_start_btn()
	
func _start_match():
	#Exit the Menus and start the match
	var gameplay = gameplay_scene.instantiate()
	get_parent().add_child(gameplay)
	self.queue_free()
