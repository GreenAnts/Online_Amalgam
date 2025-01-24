extends Control

@onready var intersection_scene = preload("res://Scenes/Gameplay/SubScenes/IntersectionSlot.tscn")
@onready var sandbox_scene = preload("res://Scenes/Gameplay/GameMode/Sandbox/Sandbox.tscn")
@onready var standard_scene = preload("res://Scenes/Gameplay/GameMode/Standard/Standard.tscn")
@onready var board_grid = $TextureRect/BoardGrid

var game_mode : String = "Sandbox"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Add Board Intersections
	loop_to_fill_grid()
	# Set Game Mode
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
	#add new intersection scene
	var new_intersection = intersection_scene.instantiate()
	board_grid.add_child(new_intersection)
	#update the id of each intersection
	new_intersection.id = Vector2(xcor, ycor)
	#Update the Board Dictionary to carry the correct node
	if BoardData.board_dict.has(new_intersection.id):
		BoardData.board_dict[new_intersection.id] = new_intersection
		if BoardData.golden_lines_dict.has(new_intersection.id):
			new_intersection.get_node("Standard").visible = false
			new_intersection.get_node("Golden").visible = true
	else:
		new_intersection.get_node("Standard").visible = false

###################
#  Adding Pieces  #
###################

func _add_piece(piece : int) -> void:
	pass
	
######################
#  Selector-Buttons  #
######################
enum {NONE, RUBY, PEARL, AMBER, JADE, AMALGAM, VOID, PORTAL}

func _on_ruby_btn_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.

func _on_pearl_btn_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.

func _on_amber_btn_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.

func _on_jade_btn_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.

func _on_amalgam_btn_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.

func _on_void_btn_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.

func _on_portal_btn_toggled(toggled_on: bool) -> void:
	pass # Replace with function body.
