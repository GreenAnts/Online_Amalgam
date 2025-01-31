extends Control

# Scenes for each slots in the Grid to fill board spaces
@onready var intersection_scene = preload("res://Scenes/Gameplay/SubScenes/Slots/IntersectionSlot.tscn")
@onready var empty_grid_slot_scene = preload("res://Scenes/Gameplay/SubScenes/Slots/EmptySlot.tscn")
# Scene for each piece added to the board
@onready var piece_scene = preload("res://Scenes/Gameplay/SubScenes/Pieces/Piece.tscn")
# # # # # # # # # # #
#  Import Scripts   #
# # # # # # # # # # #
# Logic for Game Modes
const sandbox_script = preload("res://Scenes/Gameplay/GameMode/Sandbox/sandbox.gd")
const standard_script = preload("res://Scenes/Gameplay/GameMode/Standard/standard.gd")
# Networking GodotSteam
	# Class > NetworkingHandler


@onready var piece_selector_container = $PieceSelectors
@onready var pieces_container = $PiecesContainer
@onready var board_grid = $TextureRect/BoardGrid

# Gamemode Selected (passed from previous scene)
var game_mode : String = "sandbox" # Default Mode
var game_rules # Will be the script for the correct ruleset to use

# Player is Squares or Circles (passed from previous scene)
enum {CIRCLES, SQUARES}
var player_side : int = CIRCLES

# Player Data
var opponent_id : int

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Setup Board Intersections
	loop_to_fill_grid()
	#############
	#  SignaLS  #
	#############
	SignalBus.intersection_clicked.connect(_intersection_clicked)
	SignalBus.received_turn_data.connect(_receive_turn_data)
	###################
	#  Set Game Mode  #
	###################
	if game_mode == "sandbox":
		# Load sandbox rules
		game_rules = load("res://Scenes/Gameplay/GameMode/Sandbox/sandbox.gd").new()
	elif game_mode == "standard":
		# Load standard rules
		game_rules = load("res://Scenes/Gameplay/GameMode/Standard/standard.gd").new()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# If the player is connected, read packets
		NetworkingHandler.read_messages()

##########################
#  Setting up the Board  #
##########################
# Loop through to add the correct id based on x/y coordinates
func loop_to_fill_grid():
	var ycor = 12
	for i in range(25):
		var xcor = -12
		for n in range(25):
			create_intersection_slot(xcor, ycor)
			xcor += 1
		ycor -= 1

func create_intersection_slot(xcor, ycor):
	if BoardData.board_dict.has(Vector2(xcor,ycor)):
		# Add new intersection scene
		var new_intersection = intersection_scene.instantiate()
		board_grid.add_child(new_intersection)
		# Update the id of each intersection
		new_intersection.id = Vector2(xcor, ycor)
		#Update the Board Dictionary to carry the correct node
		BoardData.board_dict[new_intersection.id] = new_intersection
		if BoardData.golden_lines_dict.has(new_intersection.id):
			# Intersections on the golden line will show the different node
			new_intersection.get_node("Standard").visible = false
			new_intersection.get_node("Golden").visible = true
	else:
		# Add an empty control node instead of a button
		var new_empty = empty_grid_slot_scene.instantiate()
		board_grid.add_child(new_empty)

#################################
#  Handle Clicked Intersection  #
#################################
enum {NONE, RUBY, PEARL, AMBER, JADE, AMALGAM, VOID, PORTAL}
var last_clicked_piece # Vector2 or NULL

func _intersection_clicked(intersection : Vector2) -> void:
#=-*-=#=-* Add Piece *-=#=-*-=#
	if selected_piece_to_add != NONE:
		# Validate the piece can be added based off the current game rules.
		if game_rules.validate_add_piece(player_side, selected_piece_to_add, intersection) == true:
			# Set Turn-Data
			turn_data['add'] = [selected_piece_to_add, intersection]
			# Add piece for your own piece type at the clicked intersection
			_add_piece(player_side, selected_piece_to_add, intersection)
#=-*-=#=-* Click Piece *-=#=-*-=#
	elif BoardData.piece_dict.has(intersection):
		# Check the gamerules for clicking on another piece
		var check = game_rules.check_clicked_piece(player_side, last_clicked_piece, intersection)
		# if the rules return an intersection...
		if check != null:
			# Set the "last_clicked_piece" variable with the node of the clicked piece
			last_clicked_piece = check
			print(last_clicked_piece)
	# Ensure the "last_clicked_piece" variable has a piece node set
#=-*-=#=-* Move Piece  *-=#=-*-=#
	elif last_clicked_piece != null:
		if game_rules.check_empty_intersection(player_side, last_clicked_piece, intersection):
			# Move the piece
			_move_piece(last_clicked_piece, intersection)
			# Set Turn-Data
			turn_data['move'] = [last_clicked_piece, intersection]
			# Reset the variable
			last_clicked_piece = null
	# Send the data
	_send_turn_data(turn_data)
	# Reset Turn-Data
	reset_turn_data()

# Move a piece from one intersection to the other
func _move_piece(from_intersection, to_intersection):
	if BoardData.piece_dict.has(from_intersection):
		# Move the piece
		BoardData.piece_dict[from_intersection].global_position = BoardData.board_dict[to_intersection].global_position + Global.intersection_offset
		# Set the NEW coordinates and node into the piece_dict 
		BoardData.piece_dict[to_intersection] = BoardData.piece_dict[from_intersection]
		# Erase the OLD coordinates and node from piece_dict
		BoardData.piece_dict.erase(from_intersection)
	
###################
#  Adding Pieces  #
###################
func _add_piece(player : int, piece_type: int, intersection : Vector2) -> void:
	var new_piece = piece_scene.instantiate()
	if player == CIRCLES:
		# Make the correct node visible for Circles.
		new_piece.get_node("Circle").visible = true
		# Each animation is a different piece. Animation name is a number correlating to the ENUM.
		new_piece.get_node("Circle").play(str(piece_type))
	elif player == SQUARES:
		# Make the correct node visible for Circles.
		new_piece.get_node("Square").visible = true
		# Each animation is a different piece. Animation name is a number correlating to the ENUM.
		new_piece.get_node("Square").play(str(piece_type))
	# Add the Piece to the scene in the correct container node
	pieces_container.add_child(new_piece)
	# Make the position equal to the intersection button node plus the offset to center it.
	new_piece.global_position = BoardData.board_dict[intersection].global_position + Global.intersection_offset
	# Add piece to the piece_dict 
	BoardData.piece_dict[intersection] = new_piece
	# If the function was not called form a networking signal
	if player == player_side:
		# Reset the selector variable.
		selected_piece_to_add = NONE
		# Ensure buttons are untoggled.
		_untoggle_selector_btns(NONE)

######################
#  Selector-Buttons  #
######################
var selected_piece_to_add = NONE
# Toggle Signals for each button 
func _on_ruby_btn_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_untoggle_selector_btns(RUBY)
		selected_piece_to_add = RUBY
	else:
		selected_piece_to_add = NONE
func _on_pearl_btn_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_untoggle_selector_btns(PEARL)
		selected_piece_to_add = PEARL
	else:
		selected_piece_to_add = NONE
func _on_amber_btn_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_untoggle_selector_btns(AMBER)
		selected_piece_to_add = AMBER
	else:
		selected_piece_to_add = NONE
func _on_jade_btn_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_untoggle_selector_btns(JADE)
		selected_piece_to_add = JADE
	else:
		selected_piece_to_add = NONE
func _on_amalgam_btn_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_untoggle_selector_btns(AMALGAM)
		selected_piece_to_add = AMALGAM
	else:
		selected_piece_to_add = NONE
func _on_void_btn_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_untoggle_selector_btns(VOID)
		selected_piece_to_add = VOID
	else:
		selected_piece_to_add = NONE
func _on_portal_btn_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		_untoggle_selector_btns(PORTAL)
		selected_piece_to_add = PORTAL
	else:
		selected_piece_to_add = NONE
# Ensure all buttons are deselected.
func _untoggle_selector_btns(piece : int) -> void:
	# Loop through all Selector Buttons
	for button in piece_selector_container.get_children():
		if piece != NONE:
			# If the button is not the corresponding piece passed into the function, unpress it.
			if button != piece_selector_container.get_child(piece - 1):
				button.button_pressed = false
		else:
			button.button_pressed = false

#################################
#  Send Turn-Data Over Network  #
#################################
var turn_data : Dictionary = { "add" : null, "move" : null, "ability" : null }

func reset_turn_data():
	turn_data = { "add" : null, "move" : null, "ability" : null }
	
func _send_turn_data(data : Dictionary) -> void:
	NetworkingHandler.send_message(opponent_id, turn_data)
	
func _receive_turn_data(data : Dictionary) -> void:
	var player
	#Send the data for the opposite piece type of your own.
	if player_side == CIRCLES:
		player = SQUARES
	else:
		player = CIRCLES
	if data["add"] != null:
		#arg1 > player | arg2 > piece_type | arg3 > location
		_add_piece(player, data["add"][0], data["add"][1])
	if data["move"] != null:
		#arg1 > From_Pos | arg2 > To_Pos
		_move_piece(data["move"][0], data["move"][1])

func reset_all() -> void:
	# Ensure all data is reset for a new game
	BoardData.piece_dict = {}
	Global.clicked_animations = []
