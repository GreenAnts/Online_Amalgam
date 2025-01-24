extends Panel

@onready var user_name = $VBoxContainer/Profile/HBoxContainer/VBoxContainer/Username
@onready var user_avatar = $VBoxContainer/Profile/HBoxContainer/CenterContainer/Panel/Avatar
@onready var top_players = $VBoxContainer/MarginContainer/Leaderboards/Panel/MarginContainer/VBoxContainer/TopPlayers

var leaderboard_handles: Dictionary = {
	"top_rank": null,
	"most_wins": null,
	"most_games": null
	}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	user_name.text = Global.steam_username
	Steam.leaderboard_find_result.connect(_on_leaderboard_find_result)
	Steam.leaderboard_score_uploaded.connect(_on_leaderboard_score_uploaded)
	Steam.leaderboard_scores_downloaded.connect(_on_leaderboard_scores_downloaded)
	Steam.findOrCreateLeaderboard("amalgam_leaderboard", 1, 1)
	await(get_tree().create_timer(1).timeout)
	_debug_upload_score()
	_request_leaderboard()

func _on_leaderboard_find_result(handle: int, found: int) -> void:
	if found == 1:
		leaderboard_handles["top_rank"] = handle
		print("Leaderboard handle found: %s" % leaderboard_handles["top_rank"])
	else:
		print("No handle was found")

func _on_leaderboard_score_uploaded(success: int, this_handle: int, this_score: Dictionary) -> void:
	if success == 1:
		print("Successfully uploaded scores!")
		#print(this_score['score']) # the new score as it stands
		#print(this_score['score_changed']) # if the score was changed (0 if false, 1 if true)
		#print(this_score['new_rank']) # the new global rank of this player
		#print(this_score['prev_rank']) # the previous rank of this player
		# Add additional logic to use other variables passed back
	else:
		print("Failed to upload scores!")

func _debug_upload_score():
	Steam.uploadLeaderboardScore(1, false, var_to_bytes(Global.steam_username).to_int32_array(), leaderboard_handles["top_rank"])

func _request_leaderboard():
	Steam.downloadLeaderboardEntries( 1, 10, Steam.LEADERBOARD_DATA_REQUEST_GLOBAL, leaderboard_handles["top_rank"] )

func _on_leaderboard_scores_downloaded(message: String, this_leaderboard_handle: int, result: Array) -> void:
	print("Scores downloaded message: %s" % message)

	# Save this for later leaderboard interactions, if you want
	var leaderboard_handle: int = this_leaderboard_handle
	var counter = 0
	# Add logic to display results
	for this_result in result:
		# Use each entry that is returned
		var details = this_result['details'].to_byte_array()
		var score = this_result['score']
		top_players.get_child(counter).text = bytes_to_var(details) + " | " + str(score)
		counter += 1
		#score: this user's score
		#steam_id: this user's Steam ID; you can use this to get their avatar, name, etc.
		#global_rank: obviously their global ranking for this leaderboard
		#ugc_handle: handle for any UGC that is attached to this entry
		#details: any details you stored with this entry for later use
