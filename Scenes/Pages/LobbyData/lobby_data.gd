extends MarginContainer

@onready var name_label = $VBoxContainer/HBoxContainer/Username
@onready var rank_label = $VBoxContainer/HBoxContainer/Rank
@onready var time_label = $VBoxContainer/TimeLimit
@onready var game_mode_label = $VBoxContainer/GameMode
@onready var restrictions_label = $VBoxContainer/Restrictions

# User Data
var username
var user_rank

# Game Data
var game_mode
var time_limit
var restrictions
var id

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set Name Label
	name_label.text = str(username)
	match time_limit:
		"0":
			time_limit = "None"
		"1":
			time_limit = "5 Min"
		"2":
			time_limit = "10 Min"
		"3":
			time_limit = "15 Min"
		"4":
			time_limit = "20 Min"
		"5":
			time_limit = "30 Min"
	time_label.text = str(time_limit)
	# Game Mode (currently only one)
	game_mode_label.text = "Standard Game"
	# Set Restrictions Label
	match restrictions:
		"0":
			restrictions = "Same Skill"
		"1":
			restrictions = "+/- 1 Skill"
		"2":
			restrictions = "+/- 2 Skill"
		"3":
			restrictions = "+/- 3 Skill"
		"4":
			restrictions = "Any Skill"
	restrictions_label.text = str(restrictions)
	rank_label.text = str(user_rank)

func _on_join_lobby_pressed() -> void:
	NetworkingHandler.join_lobby(int(id))
