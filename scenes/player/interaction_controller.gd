extends Node

# --- REFERENCIAS ---
@onready var player = owner # El CharacterBody3D
var raycast: RayCast3D

func _ready():
	# Buscamos el RayCast de forma dinámica para evitar errores de ruta
	raycast = player.find_child("RayCast3D", true, false)
	
	if not raycast:
		push_warning("⚠️ InteractionController: No se encontró RayCast3D en el jugador.")

func _unhandled_input(event):
	if not player.is_multiplayer_authority(): return
	
	if event.is_action_pressed("interact"):
		_intentar_interaccionar()

func _intentar_interaccionar():
	if not raycast or not raycast.is_colliding(): return
	
	var objetivo = raycast.get_collider()
	
	if objetivo.has_method("interactuar"):
		# IMPORTANTE: Pasamos al 'player' entero, no solo la mochila.
		# Así el objeto puede decidir si guardarse en mochila, cinturón o mano.
		objetivo.interactuar(player)

func _process(_delta):
	# Aquí es donde en el futuro emitiremos una señal para el HUD
	# Ejemplo: if raycast.is_colliding(): signal_mirando_objeto.emit(objetivo.name)
	pass
