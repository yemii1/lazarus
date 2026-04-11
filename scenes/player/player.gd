extends CharacterBody3D

signal recurso_consumido(tipo: String, cantidad: float)
signal peso_total_actualizado(nuevo_peso: float)

@export var is_sprinting: bool = false
var is_exhausted: bool = false
var total_inventory_weight: float = 0.0

@onready var mochila = $Backpack
@onready var cinturon = $ToolBelt
@onready var mano = $HandSlot
@onready var status = $StatusManager

const ITEM_SCENE = preload("res://scenes/modules/item/item_3d.tscn")

func _enter_tree():
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready():
	_configurar_posicion_inicial()
	
	if is_multiplayer_authority():
		_conectar_componentes()
		mochila.auto_add_item("soldador_plasma")

func _conectar_componentes():
	# Conexión de Inventarios
	var contenedores = [mochila, cinturon, mano]
	for inv in contenedores:
		inv.peso_actualizado.connect(_on_peso_cambiado)
		inv.objeto_soltado_fisicamente.connect(_on_objeto_soltado)
		inv.objeto_consumido.connect(_on_objeto_consumido)
	
	# Conexión con StatusManager
	self.recurso_consumido.connect(status._on_recurso_recibido)
	status.ha_muerto.connect(self.morir)
	status.agotado.connect(func(v): is_exhausted = v)

func _on_peso_cambiado(_p: float):
	total_inventory_weight = mochila.total_weight + cinturon.total_weight + mano.total_weight
	peso_total_actualizado.emit(total_inventory_weight)

func _on_objeto_consumido(data: Dictionary):
	if data.has("valor_recarga"): recurso_consumido.emit("oxigeno", data["valor_recarga"])
	if data.has("valor_curacion"): recurso_consumido.emit("salud", data["valor_curacion"])

# --- SISTEMA DE SPAWN EN RED ---

func _on_objeto_soltado(item_id: String):
	var spawn_pos = global_position + (global_transform.basis.z * -1.5) + Vector3(0, 1.0, 0)
	if multiplayer.is_server():
		_spawnear_objeto_fisico(item_id, spawn_pos)
	else:
		solicitar_spawn_servidor.rpc_id(1, item_id, spawn_pos)

@rpc("any_peer", "call_remote", "reliable")
func solicitar_spawn_servidor(item_id: String, pos: Vector3):
	if multiplayer.is_server(): _spawnear_objeto_fisico(item_id, pos)

func _spawnear_objeto_fisico(item_id: String, pos: Vector3):
	var nuevo = ITEM_SCENE.instantiate()
	nuevo.item_id = item_id 
	nuevo.name = item_id + "_" + str(Time.get_ticks_msec())
	var contenedor = get_tree().current_scene.find_child("PlayersContainer", true, false)
	if contenedor:
		contenedor.add_child(nuevo, true)
		nuevo.global_position = pos
		if nuevo is RigidBody3D:
			nuevo.apply_central_impulse((pos - global_position).normalized() * 3.0)

func morir():
	set_physics_process(false)

func _configurar_posicion_inicial():
	var my_id = str(name)
	if NetworkManager.spawn_positions.has(my_id):
		global_position = NetworkManager.spawn_positions[my_id]
