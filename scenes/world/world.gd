extends Node3D

func _ready():
	# Avisamos al NetworkManager de que ya tenemos el suelo dibujado
	# y el PlayersContainer está listo para recibir nodos.
	NetworkManager.on_world_ready()
