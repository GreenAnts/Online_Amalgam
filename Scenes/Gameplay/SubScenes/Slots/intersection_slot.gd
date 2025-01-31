extends Control

var id : Vector2
var clicked_scene = load("res://Scenes/Gameplay/SubScenes/click/ClickAnim.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	
func _on_pressed() -> void:
	SignalBus.intersection_clicked.emit(id)
	# Change cursor to indicate that it is over a piece (if it is)
	_on_mouse_entered()
	# If there is no piece, show the click animation
	if BoardData.piece_dict.has(id) == false:
		play_click_anim("intersection")
	# If there is a piece
	else:
		play_click_anim("piece")

func _on_mouse_entered() -> void:
	if BoardData.piece_dict.has(id):
		self.set_default_cursor_shape(2)

func _on_mouse_exited() -> void:
	self.set_default_cursor_shape(0)

func play_click_anim(type) -> void:
	# If there is already an animation playing
	if get_child_count() < 3: #(EDIT IF ADDING MORE PRIMARY CHILDREN TO THIS SCENE)
		# Play clicked animation
		var clicked = clicked_scene.instantiate()
		clicked.type = type
		# Add node to the global array for tracking
		Global.clicked_animations.append(clicked)
		# Add to Scene
		add_child(clicked)
		# Set positon to the center of the intersection
		clicked.global_position = self.global_position + Global.intersection_offset
