extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Buttons
func _on_quick_match_pressed() -> void:
	# Let the Handler know that we are automatching
	NetworkingHandler.automatch = true
	# Set the matchmaking process to start over
	NetworkingHandler.matchmaking_phase = 0
	# Start the loop!
	NetworkingHandler.matchmaking_loop()
