extends Control

func _ready():
	# Si NO somos el Host, ocultamos el botón de empezar
	if not NetworkManager.is_host_mode:
		%StartButton.hide()
		%StatusLabel.text = "Esperando al Host..."
	else:
		%StatusLabel.text = "Sala Abierta. Esperando amigos..."
	
	%StartButton.pressed.connect(_on_start_pressed)
	
	# Escuchamos si entra alguien
	NetworkManager.player_joined.connect(_on_player_joined)
	
	# ¡Encendemos el router!
	NetworkManager.setup_multiplayer()

func _on_start_pressed():
	# Solo el Host puede pulsar esto
	NetworkManager.start_game()

func _on_player_joined(id):
	%StatusLabel.text = "¡Jugador conectado! (" + str(id) + ")"
