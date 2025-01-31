extends Control

@onready var lobby_data_scene = preload("res://Scenes/Pages/LobbyData/LobbyData.tscn")

const PACKET_READ_LIMIT: int = 32

var lobby_data
var lobby_id: int = 0
var opponent_id : int
var lobby_members: Array = []
var lobby_members_max: int = 2
var matchmaking_phase: int = 0
# are you automatching?
var automatch : bool = false

# Not Yet Used.
#		var lobby_vote_kick: bool = false

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
	SignalBus.update_lobby_listings.connect(get_lobby_list)
	
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

# From LobbyData Button
func join_lobby(this_lobby_id: int) -> void:
	print("Attempting to join lobby %s" % lobby_id)
	# Clear any previous lobby members lists, if you were in a previous lobby
	lobby_members.clear()
	# Make the lobby join request to Steam
	Steam.joinLobby(this_lobby_id)

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

func get_lobby_list() -> void:
	# Set distance to worldwide
	Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)
	print("Requesting a lobby list")
	add_lobby_list_filter()
	Steam.requestLobbyList()

func add_lobby_list_filter():
	Steam.addRequestLobbyListStringFilter("game", "Amalgam", Steam.LOBBY_COMPARISON_EQUAL)
	
func _on_lobby_match_list(these_lobbies: Array) -> void:
	# clear the list of lobby from the scene
	SignalBus.clear_lobbies.emit()
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
				# Instatiate the LobbyData to then be added to the List of lobbies
				var lobby_data = lobby_data_scene.instantiate()
				lobby_data.game_mode = lobby_game_mode
				lobby_data.username = lobby_name
				lobby_data.time_limit = lobby_time_limit
				lobby_data.restrictions = lobby_restrictions
				lobby_data.id = this_lobby
				# Signal is sent to the lobbies page to add_child
				SignalBus.add_lobby_data.emit(lobby_data)

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
		SignalBus.update_lobby_player_info.emit(this_lobby_id)
		# Join Message into match lobby chat
		var join_message = Label.new()
		join_message.text = ("%s has joined the lobby" % str(Global.steam_username))
		join_message.modulate = Color("0000ff")
		SignalBus.add_chat_message.emit(join_message)
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
		get_lobby_list()

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
		lobby_members.append({"steam_id": member_steam_id, "steam_name": member_steam_name, "avatar": null})
		

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
		SignalBus.add_chat_message.emit(message)
	# Else if a player has left the lobby
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_LEFT:
		print("%s has left the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has left the lobby." % changer_name
		message.modulate = Color("ff0000")
		SignalBus.add_chat_message.emit(message)
	# Else if a player has been kicked
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_KICKED:
		print("%s has been kicked from the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has been kicked from the lobby." % changer_name
		message.modulate = Color("8f00ff")
		SignalBus.add_chat_message.emit(message)
	# Else if a player has been banned
	elif chat_state == Steam.CHAT_MEMBER_STATE_CHANGE_BANNED:
		print("%s has been banned from the lobby." % changer_name)
		var message = Label.new()
		message.text = "%s has been banned from the lobby." % changer_name
		message.modulate = Color("ef224b")
		SignalBus.add_chat_message.emit(message)
	# Else there was some unknown change
	else:
		print("%s did... something." % changer_name)
	# If the player is still in a lobby
	if lobby_id > 0:
		# Update the lobby now that a change has occurred
		get_lobby_members()
		SignalBus.update_lobby_player_info.emit(this_lobby_id)

func _on_lobby_message(this_lobby_id: int, user: int, buffer: String, chat_type: int) -> void:
	print("Message Recieved")
	var message = Label.new()
	message.text = buffer
	SignalBus.add_chat_message.emit(message)
	
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
		add_lobby_list_filter()
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
			# During a Lobby
			if message.payload.has('timer'):
				# Start Timer > Countdown to match start
				if message.payload['timer'] == "start_timer":
					SignalBus.set_timer.emit(true)
				# Stop Timer > abort countdown
				elif message.payload['timer'] == "stop_timer":
					SignalBus.set_timer.emit(false)
			elif message.payload.has('start_match'):
				# Start Match > transition to gameplay scene with correct details
					SignalBus.start_match.emit(message.payload['start_match'])
			# During Gameplay
			else:
				SignalBus.received_turn_data.emit(message.payload)

func _on_network_messages_session_failed(steam_id: int, session_error: int, state: int, debug_msg: String) -> void:
	print(debug_msg)
