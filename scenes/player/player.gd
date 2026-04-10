extends CharacterBody3D

# --- ESTADÍSTICAS DE SUPERVIVENCIA (Variables dinámicas) ---
var max_health = 100.0
var current_health = 100.0
var inventory_weight = 0.0 # Más adelante, coger objetos subirá esto

func _enter_tree():
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready():
	var my_id_str = str(name)
	if NetworkManager.spawn_positions.has(my_id_str):
		global_position = NetworkManager.spawn_positions[my_id_str]
