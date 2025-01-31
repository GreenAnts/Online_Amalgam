extends Node

# Steam
var is_on_steam_deck: bool
var is_online: bool
var is_owned: bool
var steam_id: int
var steam_username: String

# Offset for centering things on the board intersections
var intersection_offset : Vector2 = Vector2(20,20)
# Stores the animation for clicks
var clicked_animations : Array = []

# Gameplay Settings
var game_mode = "sandbox"
var time_limit = ""

@onready var gameplay_scene = preload("res://Scenes/Gameplay/Gameplay.tscn")

func _process(delta: float) -> void:
	Steam.run_callbacks()

func _ready() -> void:
	initialize_steam()

func _init() -> void:
	# Set your game's Steam app ID here
	OS.set_environment("SteamAppId", str(480))
	OS.set_environment("SteamGameId", str(480))

func initialize_steam() -> void:
	var initialize_response: Dictionary = Steam.steamInitEx()
	print("Did Steam initialize?: %s " % initialize_response)
	
	if initialize_response['status'] > 0:
		print("Failed to initialize Steam, shutting down: %s" % initialize_response)
		#get_tree().quit()
	else:
		is_on_steam_deck = Steam.isSteamRunningOnSteamDeck()
		is_online = Steam.loggedOn()
		is_owned = Steam.isSubscribed()
		steam_id = Steam.getSteamID()
		steam_username = Steam.getPersonaName()
