extends Control

@onready var start_timer = $StartTimer
@onready var chat = $HBoxContainer/MarginContainer/VBoxContainer/Panel/HBoxContainer/VBoxContainer/ScrollContainer/MatchLobbyChat
@onready var start_btn = $HBoxContainer/MarginContainer/VBoxContainer/MarginContainer/HBoxContainer/MarginContainer/VBoxContainer2/StartMatch
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if start_timer.is_stopped() == false:
		start_btn.text = (str(int(start_timer.time_left)))
		start_btn.modulate = Color("775588")

func reset_start_btn():
	start_btn.text = ("Start Match")
	start_btn.modulate = Color("ffffff")
