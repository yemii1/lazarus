extends Node

@onready var player = get_parent()
@onready var raycast = $"../Head/Camera3D/RayCast3D"
@onready var mochila = $"../Backpack"

func _unhandled_input(event):
	# Solo interactúas tú, no los clones de red
	if not player.is_multiplayer_authority(): return
	
	# "interact" en tu Mapa de Entrada
	if event.is_action_pressed("interact"):
		_intentar_interaccionar()

func _intentar_interaccionar():
	# Si el láser está tocando algo
	if raycast.is_colliding():
		var objetivo = raycast.get_collider()
		
		# Objeto tiene la función "interactuar"
		if objetivo.has_method("interactuar"):
			# Le pasamos nuestra mochila para que intente meterse
			objetivo.interactuar(mochila)
