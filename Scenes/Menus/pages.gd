extends Control

# Lobbies (List) Nodes
@onready var lobbies_page = $LobbiesPage
@onready var lobby_list = $LobbiesPage/VBoxContainer/MarginContainer/ScrollContainer/CenterContainer/LobbyList
@onready var game_mode_options = $LobbiesPage/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/GameModeOptions
@onready var restrictions_options = $LobbiesPage/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/RestrictionsOptions
@onready var time_options = $LobbiesPage/VBoxContainer/MarginContainer2/HBoxContainer/VBoxContainer/HBoxContainer/TimeOptions
# Lobby Nodes
@onready var lobby_page = $LobbyPage
@onready var lobby_page_chat = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/VBoxContainer/ScrollContainer/MatchLobbyChat
@onready var lobby_page_message = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/VBoxContainer/MatchLobbyMessage
@onready var player_one_label = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer/Control/PlayerOneData/VBoxContainer/PlayerOneName
@onready var player_two_label = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer2/Control/PlayerOneData/VBoxContainer/PlayerTwoName
@onready var player_one_avatar = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer/Control/PlayerOneData/PlayerOneAvatar
@onready var player_two_avatar = $LobbyPage/HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/MarginContainer2/Control/PlayerOneData/PlayerTwoAvatar
# Scenes
@onready var lobby_data_scene = preload("res://Scenes/Menus/LobbyData/LobbyData.tscn")

const PACKET_READ_LIMIT: int = 32

var lobby_data
var lobby_id: int = 0
var lobby_members: Array = []
var lobby_members_max: int = 2
var lobby_vote_kick: bool = false
# Steam ID
# > Global.steam_id
# Steam Username
# > Global.steam_username

# Create Lobby Data > _on_create_lobby_pressed()
var game_mode : int = 0
var time_limit : int
var restrictions : int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Connect signals from SignalBus Global
	SignalBus.join_lobby.connect(join_lobby)
	
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
				#join_lobby(int(these_arguments[1]))

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
		Steam.setLobbyData(lobby_id, "mode", "Amalgam")
		Steam.setLobbyData(lobby_id, "name", str(Global.steam_username))
		Steam.setLobbyData(lobby_id, "game_mode", str(game_mode))
		Steam.setLobbyData(lobby_id, "time_limit", str(time_limit))
		Steam.setLobbyData(lobby_id, "restrictions", str(restrictions))
		# Allow P2P connections to fallback to being relayed through Steam if needed
		var set_relay: bool = Steam.allowP2PPacketRelay(true)
		print("Allowing Steam to be relay backup: %s" % set_relay)

func _get_lobby_list() -> void:
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	print("Requesting a lobby list")
	Steam.requestLobbyList()

func _on_lobby_match_list(these_lobbies: Array) -> void:
	for lobby in lobby_list.get_children():
		lobby.queue_free()
	for this_lobby in these_lobbies:
		if Steam.getLobbyData(this_lobby, "mode") == "Amalgam":
			# Pull lobby data from Steam, these are specific to our example
			var lobby_name: String = Steam.getLobbyData(this_lobby, "name")
			var lobby_time_limit: String = Steam.getLobbyData(this_lobby, "time_limit")
			var lobby_ranked: String = Steam.getLobbyData(this_lobby, "ranked")
			var lobby_restrictions: String = Steam.getLobbyData(this_lobby, "restrictions")
			# Get the current number of members
			var lobby_num_members: int = Steam.getNumLobbyMembers(this_lobby)
			# Create a button for the lobby
			var lobby_data = lobby_data_scene.instantiate()
			lobby_data.username = lobby_name
			lobby_data.time_limit = lobby_time_limit
			lobby_data.restrictions = lobby_restrictions
			lobby_data.id = this_lobby
			# Add the new lobby to the list
			lobby_list.add_child(lobby_data)

func _on_lobby_joined(this_lobby_id: int, _permissions: int, _locked: bool, response: int) -> void:
	# If joining was successful
	if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
		# Set this lobby ID as your lobby ID
		lobby_id = this_lobby_id
		# Get the lobby members
		get_lobby_members()
		# Make the initial handshake
		make_p2p_handshake()
		# Set the Scene Nodes to properly display player data.
		player_one_label.text = Global.steam_username
		player_two_label.text = "Waiting for Player..."
		# Change from lobby list to match lobby
		lobbies_page.visible = false
		lobby_page.visible = true
		# Join Message into match lobby chat
		var join_message = Label.new()
		join_message.text = str(Global.steam_username) + " has joined the lobby"
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

func make_p2p_handshake() -> void:
	print("Sending P2P handshake to the lobby")
	send_message(0, {"message": "handshake", "from": Global.steam_id})

func _on_lobby_chat_update(this_lobby_id: int, change_id: int, making_change_id: int, chat_state: int) -> void:
	# Get the user who has made the lobby change
	var changer_name: String = Steam.getFriendPersonaName(change_id)
	# If a player has joined the lobby
	if chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_ENTERED:
		print("%s has joined the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has joined the lobby." % changer_name
		lobby_page_chat.add_child(message)
	# Else if a player has left the lobby
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		print("%s has left the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has left the lobby." % changer_name
		lobby_page_chat.add_child(message)
	# Else if a player has been kicked
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
		print("%s has been kicked from the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has been kicked from the lobby." % changer_name
		lobby_page_chat.add_child(message)
	# Else if a player has been banned
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
		print("%s has been banned from the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has been banned from the lobby." % changer_name
		lobby_page_chat.add_child(message)
	# Else there was some unknown change
	else:
		print("%s did... something." % changer_name)
	# Update the lobby now that a change has occurred
	get_lobby_members()

func _on_lobby_message(this_lobby_id: int, user: int, buffer: String, chat_type: int) -> void:
	print("Message Recieved")
	var message = Label.new()
	message.text = buffer
	lobby_page_chat.add_child(message)

#############
#    P2P    #
#############
func _on_network_messages_session_request(remote_id: int) -> void:
	# Get the requester's name
	var this_requester: String = Steam.getFriendPersonaName(remote_id)
	print("%s is requesting a P2P session" % this_requester)
	# Accept the P2P session; can apply logic to deny this request if needed
	Steam.acceptSessionWithUser(remote_id)
	# Make the initial handshake
	make_p2p_handshake()

func read_messages() -> void:
	var messages: Array = Steam.receiveMessagesOnChannel(0, 1000)
	for message in messages:
		if message.is_empty() or message == null:
			print("WARNING: read an empty message with non-zero size!")
		else:
			message.payload = bytes_to_var_with_objects(message.payload).decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
			# Get the remote user's ID
			var message_sender: int = message['remote_steam_id']
			# Print the packet to output
			print("Message Payload: %s" % message.payload)
			# Append logic here to deal with message data.

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

func _on_network_messages_session_failed(steam_id: int, session_error: int, state: int, debug_msg: String) -> void:
	print(debug_msg)

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
		# Change pages from LobbyPage to the LobbiesPage via signal to main.gd
		SignalBus.change_pages.emit("lobbies")

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
