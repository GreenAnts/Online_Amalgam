extends Control

@onready var pages = $Pages
@onready var landing_page = $Pages/LandingPage
@onready var lobbies_page = $Pages/LobbiesPage
@onready var lobby_page = $Pages/LobbyPage
@onready var profile_page = $Pages/ProfilePage
@onready var side_panel = $Pages/SidePanel
@onready var gameplay_wrapper = $GameplayWrapper
@onready var panel_avatar = $Pages/SidePanel/VBoxContainer/Profile/HBoxContainer/CenterContainer/Panel/Avatar
@onready var confirm_exit = $ConfirmExit
@onready var confirm_leave_match = $ConfirmLeaveMatch
@onready var quick_match_fail_confirmation = $QuickMatchFail

var remember_open_page : int = 0
var pages_options 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pages_options = [landing_page, lobbies_page, lobby_page, profile_page, side_panel]
	SignalBus.change_pages.connect(change_page)

func start_match():
	#Exit the Menus and start the match
	var gameplay_scene = Global.gameplay_scene.instantiate()
	gameplay_wrapper.add_child(gameplay_scene)
	change_page("gameplay")

# # # # # # #
#  Buttons  #
# # # # # # #
# Go to Gameplay (FROM: LandingPage)
func _on_solo_play_pressed() -> void:
	start_match()
# Go to LobbiesPage (FROM: LandingPage)
func _on_custom_game_pressed() -> void:
	change_page("lobbies")
# Go to LandingPage (FROM: LobbyPage)
func _on_back_btn_pressed() -> void:
	change_page("landing")
# Hide ProfilePage (FROM: ProfilePage)
func _on_hide_btn_pressed() -> void:
	panel_avatar.button_pressed = false
# Toggle Hide/Show ProfilePage (FROM: SideMenu)
func _on_avatar_toggled(toggled_on: bool) -> void:
	change_page("profile")
# Toggle to hide/show the profile page
func change_page(page):
	lobbies_page.visible = false
	lobby_page.visible = false
	landing_page.visible = false
	gameplay_wrapper.visible = false
	side_panel.visible = false
	# GameplayWrapper
	if page == "gameplay":
		gameplay_wrapper.visible = true
	else:
		# Ensure Side Panel is shown for all menus
		side_panel.visible = true
		# Landing Page [0]
		if page == "landing":
			landing_page.visible = true
			remember_open_page = 0
		# Lobbies Page [1]
		elif page == "lobbies":
			SignalBus.update_lobby_listings.emit()
			lobbies_page.visible = true
			remember_open_page = 1
		# Lobby Page [2]
		elif page == "lobby":
			lobby_page.visible = true
			remember_open_page = 2
		# Profile Page [3]
		elif page == "profile":
			if profile_page.visible == true:
				profile_page.visible = false
				pages_options[remember_open_page].visible = true
			else:
				profile_page.visible = true
		# Show the Dialog box for failing to find a automatch
		elif page == "quick_match_fail":
			quick_match_fail_confirmation.visible = true
			landing_page.visible = true

# # # # # # #
# Exit Game #
# # # # # # #
# Exit Confirmation on Exit Button
func _on_exit_pressed() -> void:
	confirm_exit.visible = true
# Exit Confirmation on hotkey (ESC)
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		if landing_page.visible == true:
			confirm_exit.visible = true
			quick_match_fail_confirmation.visible = false
		elif lobbies_page.visible == true:
			change_page("landing")
		elif lobby_page.visible == true:
			change_page("lobbies")
		elif profile_page.visible == true:
			change_page("profile")
		elif gameplay_wrapper.visible == true:
			confirm_leave_match.visible = true

# Exit Game after Confirmation
func _on_confirm_exit_confirmed() -> void:
	get_tree().quit()

# Leaving a match
func _on_confirm_leave_match_confirmed() -> void:
	change_page("landing")
	NetworkingHandler.leave_lobby()
	var gameplay = gameplay_wrapper.get_child(0)
	gameplay.reset_all()
	gameplay.queue_free()
	gameplay.abandon()

# No available Lobbies > agree to create a new lobby
func _on_quick_match_fail_confirmed() -> void:
	NetworkingHandler.create_lobby()
