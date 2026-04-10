extends Node

var peer = ENetMultiplayerPeer.new()
var is_host_mode = false
const PORT = 7000
const IP_ADDRESS = "127.0.0.1"

# Diccionario de posiciones: {"1": Vector3(...), "2531": Vector3(...)}
var spawn_positions = {}
var players_loaded = 0

# ¡IMPORTANTE! Arrastra aquí tus 3 escenas
var player_scene = preload("res://scenes/player/player.tscn") 
var world_scene = preload("res://scenes/world/world.tscn")  
var menu_scene = preload("res://scenes/modules/menu/menu.tscn")   

signal player_joined(id)

func _ready():
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func setup_multiplayer():
	if is_host_mode:
		var error = peer.create_server(PORT)
		if error == OK:
			multiplayer.multiplayer_peer = peer
	else:
		var error = peer.create_client(IP_ADDRESS, PORT)
		if error == OK:
			multiplayer.multiplayer_peer = peer

# --- FASE 1: PREPARACIÓN Y VIAJE ---

func start_game():
	if multiplayer.is_server():
		_prepare_spawn_map()
		# Mandamos el mapa a todos
		rpc("rpc_receive_spawn_positions", spawn_positions)
		# Ordenamos viajar al 3D
		rpc("rpc_load_world")

func _prepare_spawn_map():
	spawn_positions.clear()
	
	var all_ids = [1] # El Host siempre es 1
	all_ids.append_array(multiplayer.get_peers()) # Añadimos a los clientes
	
	for i in range(all_ids.size()):
		var id_str = str(all_ids[i]) # Forzamos Texto para la red
		
		# Altura Y=5 para nacer en el aire. Eje X se separa 2 metros por jugador.
		var spawn_pos = Vector3(i * 2.0, 5.0, 0.0) 
		spawn_positions[id_str] = spawn_pos

@rpc("authority", "call_local", "reliable")
func rpc_receive_spawn_positions(pos_dict):
	spawn_positions = pos_dict

@rpc("call_local", "reliable")
func rpc_load_world():
	players_loaded = 0 # Reseteamos el contador
	get_tree().change_scene_to_packed(world_scene)

# --- FASE 2: SINCRONIZACIÓN Y SPAWN ---

func on_world_ready():
	if multiplayer.is_server():
		_check_all_ready()
	else:
		rpc_id(1, "rpc_client_ready")

@rpc("any_peer", "call_remote", "reliable")
func rpc_client_ready():
	if multiplayer.is_server():
		_check_all_ready()

func _check_all_ready():
	players_loaded += 1
	var total_players = multiplayer.get_peers().size() + 1
	
	if players_loaded == total_players:
		# Cuando TODOS han cargado, leemos las claves (IDs) y spawneamos
		for id_str in spawn_positions.keys():
			_spawn_player(id_str)

func _spawn_player(id_str):
	var container = get_tree().current_scene.get_node_or_null("PlayersContainer")
	if not container or container.has_node(id_str): 
		return
		
	var player = player_scene.instantiate()
	player.name = id_str # El nombre del nodo es el ID en texto
	
	# NO forzamos la posición aquí. El jugador lo hará en su propio script.
	container.add_child(player)

# --- GESTIÓN DE CONEXIONES ---

func _on_peer_connected(id): 
	player_joined.emit(id)

func _on_peer_disconnected(id):
	if multiplayer.is_server():
		var p = get_tree().current_scene.get_node_or_null("PlayersContainer/" + str(id))
		if p: p.queue_free()

func _on_connection_failed(): _return_to_menu()
func _on_server_disconnected(): _return_to_menu()

func _return_to_menu():
	multiplayer.multiplayer_peer = null
	call_deferred("_deferred_change_scene")

func _deferred_change_scene():
	get_tree().change_scene_to_packed(menu_scene)
