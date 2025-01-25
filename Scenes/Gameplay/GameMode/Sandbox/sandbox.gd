extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func validate_add_piece(player: int, piece: int, intersection : Vector2) -> bool:
	if not BoardData.piece_dict.has(intersection):
		return true
	else:
		return false

func check_clicked_piece(player: int, piece, intersection : Vector2) -> Vector2:
	return intersection

func check_empty_intersection(player: int, piece, intersection : Vector2) -> bool:
	return true
