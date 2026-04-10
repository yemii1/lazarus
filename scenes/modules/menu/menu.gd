extends Control

# ARRASTRA lobby.tscn
var lobby_scene = preload("res://scenes/modules/Lobby/lobby.tscn") 

func _ready():
	%HostButton.pressed.connect(_on_host_pressed)
	%JoinButton.pressed.connect(_on_join_pressed)

func _on_host_pressed():
	NetworkManager.is_host_mode = true
	get_tree().change_scene_to_packed(lobby_scene)

func _on_join_pressed():
	NetworkManager.is_host_mode = false
	get_tree().change_scene_to_packed(lobby_scene)
