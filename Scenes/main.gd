extends Control

@onready var landing_page = $Pages/LandingPage
@onready var lobbies_page = $Pages/LobbiesPage
@onready var lobby_page = $Pages/LobbyPage
@onready var profile_page = $Pages/ProfilePage
@onready var side_panel = $Pages/SidePanel
@onready var panel_avatar = $Pages/SidePanel/VBoxContainer/Profile/HBoxContainer/CenterContainer/Panel/Avatar
@onready var pages = $Pages
@onready var confirm_exit = $ConfirmExit
@onready var quick_match_fail_confirmation = $QuickMatchFail

var remember_open_page : int = 0
var pages_options 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pages_options = [landing_page, lobbies_page, lobby_page, profile_page, side_panel]
	SignalBus.change_pages.connect(change_page)

# # # # # # #
#  Buttons  #
# # # # # # #
# Go to Gameplay (FROM: LandingPage)
func _on_solo_play_pressed() -> void:
	pages.start_match()
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
	#profile_page.visible = false
	if page == "landing":
		landing_page.visible = true
		remember_open_page = 0
	elif page == "lobbies":
		SignalBus.update_lobby_listings.emit()
		lobbies_page.visible = true
		remember_open_page = 1
	elif page == "lobby":
		lobby_page.visible = true
		remember_open_page = 2
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
		confirm_exit.visible = true
		quick_match_fail_confirmation.visible = false
# Exit Game after Confirmation
func _on_confirm_exit_confirmed() -> void:
	get_tree().quit()
# No available Lobbies > agree to create a new lobby
func _on_quick_match_fail_confirmed() -> void:
	pages.create_lobby()
