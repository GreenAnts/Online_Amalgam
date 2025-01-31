extends Node

############
#  Steam   #
############
# Signal to Main for changing the Menu Page
signal change_pages(page)
# LobbiesPage > Auto update listings
signal update_lobby_listings()

##################################################
#  # From NetworkHandler to various Menu Pages   #
##################################################
# To LobbiesPages to remove listings og all the lobbies
signal clear_lobbies()
# To LobbiesPages to add the LobbyData
signal add_lobby_data(lobby_data)
# To LobbyPage to add a message into the chat
signal add_chat_message(message)
# Updates the player info in the lobby on LobbyPage
signal update_lobby_player_info(lobby_id)
# Sent to LobbyPage to start set the timer
signal set_timer(boolean)
# Sent to LobbyPage to start the match
signal start_match()

##############
#  Gameplay  #
##############
# Intersections
signal intersection_clicked(coordinates : Vector2)
# Read P2P Turn-Data Sent
signal received_turn_data(data : Dictionary)
signal winner(username : String)
