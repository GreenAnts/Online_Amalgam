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
@onready var sandbox_scene = preload("res://Scenes/Gameplay/GameMode/Sandbox/Sandbox.tscn")
@onready var standard_scene = preload("res://Scenes/Gameplay/GameMode/Standard/Standard.tscn")
# Networking GodotSteam
	# Class > SendData


@onready var piece_selector_container = $PieceSelectors
@onready var pieces_container = $PiecesContainer
@onready var board_grid = $TextureRect/BoardGrid

# Gamemode Selected (passed from previous scene)
var game_mode : String = "Sandbox" # Default Mode
# Player is Squares or Circles (passed from previous scene)
enum {CIRCLES, SQUARES}
var player_side : int = CIRCLES

var intersection_offset : Vector2 = Vector2(20,20)

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
	###################
	#  Set Game Mode  #
	###################
	if game_mode == "Sandbox":
		var sandbox = sandbox_scene.instantiate()
		add_child(sandbox)
	elif game_mode == "Standard":
		var standard = standard_scene.instantiate()
		add_child(standard)

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

func _intersection_clicked(intersection : Vector2) -> void:
	if selected_piece_to_add != NONE:
		_add_piece(selected_piece_to_add, intersection)

###################
#  Adding Pieces  #
###################
func _add_piece(piece_type: int, intersection : Vector2) -> void:
	var new_piece = piece_scene.instantiate()
	if player_side == CIRCLES:
		# Make the correct node visible for Circles.
		new_piece.get_node("Circle").visible = true
		# Each animation is a different piece. Animation name is a number correlating to the ENUM.
		new_piece.get_node("Circle").play(str(piece_type))
	elif player_side == SQUARES:
		# Make the correct node visible for Circles.
		new_piece.get_node("Square").visible = true
		# Each animation is a different piece. Animation name is a number correlating to the ENUM.
		new_piece.get_node("Square").play(str(piece_type))
	# Add the Piece to the scene in the correct container node
	pieces_container.add_child(new_piece)
	# Make the position equal to the intersection button node plus the offset to center it.
	new_piece.global_position = BoardData.board_dict[intersection].global_position + intersection_offset
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
		# If the button is not the corresponding piece passed into the function, unpress it.
		if button != piece_selector_container.get_child(piece - 1):
			button.button_pressed = false

#################################
#  Send Turn-Data Over Network  #
#################################
var turn_data : Dictionary = {"message" : [Vector2(0,0), Vector2(1,1)]}

func _send_turn_data(data : Dictionary) -> void:
	SendData.send_message_to_opponent(opponent_id, turn_data)
