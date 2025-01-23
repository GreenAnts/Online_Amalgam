extends Panel

@onready var user_name = $VBoxContainer/Profile/HBoxContainer/VBoxContainer/Username
@onready var user_avatar = $VBoxContainer/Profile/HBoxContainer/Avatar

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	user_name.text = Global.steam_username
