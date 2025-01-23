extends Control

@onready var landing_page = $Pages/LandingPage
@onready var lobbies_page = $Pages/LobbiesPage
@onready var lobby_page = $Pages/LobbyPage
@onready var profile_page = $Pages/ProfilePage
@onready var side_panel = $Pages/SidePanel

var remember_open_page
var pages 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pages = [landing_page, lobbies_page, lobby_page, profile_page, side_panel]
	SignalBus.change_pages.connect(change_page)

# # # # # # #
#  Buttons  #
# # # # # # #
#DEBUG TEMP BUTTON
func _on_join_pressed() -> void:
	change_page("lobby")
# Go to LobbiesPage (FROM: LandingPage)
func _on_custom_game_pressed() -> void:
	change_page("lobbies")
# Go to LobbiesPage (FROM: LobbyPage)
func _on_leave_lobby_pressed() -> void:
	change_page("lobbies")
# Go to LandingPage (FROM: LobbyPage)
func _on_back_btn_pressed() -> void:
	change_page("landing")
# Hide ProfilePage (FROM: ProfilePage)
func _on_hide_btn_pressed() -> void:
	change_page("profile")
	$Pages/SidePanel/VBoxContainer/Profile/HBoxContainer/Avatar.button_pressed = false
# Toggle Hide/Show ProfilePage (FROM: SideMenu)
func _on_avatar_toggled(toggled_on: bool) -> void:
	change_page("profile")
# Toggle to hide/show the profile page
func change_page(page):
	lobbies_page.visible = false
	lobby_page.visible = false
	landing_page.visible = false
	profile_page.visible = false
	if page == "landing":
		landing_page.visible = true
		remember_open_page = 0
	elif page == "lobbies":
		lobbies_page.visible = true
		remember_open_page = 1
	elif page == "lobby":
		lobby_page.visible = true
		remember_open_page = 2
	elif page == "profile":
		if profile_page.visible == true:
			pages[remember_open_page].visible = true
		else:
			profile_page.visible = true
# # # # # # #
# Exit Game #
# # # # # # #
# Exit Confirmation on Exit Button
func _on_exit_pressed() -> void:
	$ConfirmationDialog.visible = true
# Exit Confirmation on hotkey (ESC)
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		$ConfirmationDialog.visible = true
# Exit Game after Confirmation
func _on_confirmation_dialog_confirmed() -> void:
	get_tree().quit()
