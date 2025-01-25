extends Node

############
#  Steam   #
############
#Lobby Connections
signal join_lobby(id)
signal change_pages(page)
signal update_lobby_listings()

##############
#  Gameplay  #
##############
# Intersections
signal intersection_clicked(coordinates : Vector2)
