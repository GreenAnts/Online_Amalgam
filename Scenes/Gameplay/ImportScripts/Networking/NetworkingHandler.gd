extends Node

class_name NetworkingHandler

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# P2P
	Steam.network_messages_session_request.connect(_on_network_messages_session_request)
	Steam.network_messages_session_failed.connect(_on_network_messages_session_failed)
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

#############
#    P2P    #
#############
func make_p2p_handshake() -> void:
	print("Sending P2P handshake to the lobby")
	send_message_to_opponent(0, {"message": "handshake", "from": Global.steam_id})
	
func _on_network_messages_session_request(remote_id: int) -> void:
	# Get the requester's name
	var this_requester: String = Steam.getFriendPersonaName(remote_id)
	print("%s is requesting a P2P session" % this_requester)
	# Accept the P2P session; can apply logic to deny this request if needed
	Steam.acceptSessionWithUser(remote_id)
	# Make the initial handshake
	make_p2p_handshake()

static func send_message_to_opponent(this_target: int, packet_data: Dictionary) -> void:
	# Set the send_type and channel
	var send_type: int = Steam.NETWORKING_SEND_RELIABLE_NO_NAGLE
	var channel: int = 0
	# Create a data array to send the data through
	var this_data: PackedByteArray
	this_data.append_array(var_to_bytes(packet_data).compress(FileAccess.COMPRESSION_GZIP))
	# If sending a packet to everyone
	Steam.sendMessageToUser(this_target, this_data, send_type, channel)

static func read_messages() -> void:
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
			print(message.payload)
			SignalBus.received_turn_data.emit(message.payload)

static func _on_network_messages_session_failed(steam_id: int, session_error: int, state: int, debug_msg: String) -> void:
	print(debug_msg)
