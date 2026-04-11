extends CharacterBody3D

# --- VARIABLES DE ESTADO ---
@export var is_sprinting: bool = false
var total_inventory_weight: float = 0.0

# --- REFERENCIAS A NODOS ---
# Los nombres aquí deben coincidir con los nodos en escena
@onready var mochila = $Backpack
@onready var cinturon = $ToolBelt
@onready var mano = $HandSlot
@onready var status = $StatusManager

# --- PRELOADS ---
const ITEM_SCENE = preload("res://scenes/modules/item/item_3d.tscn")

# --- CONFIGURACIÓN DE RED ---
func _enter_tree():
	# El nombre del nodo debe ser el ID único del peer para autoridad de red
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

func _ready():
	# Sincronización de posición inicial mediante el NetworkManager
	var my_id_str = str(name)
	if NetworkManager.spawn_positions.has(my_id_str):
		global_position = NetworkManager.spawn_positions[my_id_str]
	
	# --- CONEXIÓN DE SEÑALES ---
	# Solo el dueño del personaje gestiona sus señales de inventario
	if is_multiplayer_authority():
		var contenedores = [mochila, cinturon, mano]
		for inv in contenedores:
			inv.peso_actualizado.connect(_on_peso_cambiado)
			inv.objeto_soltado_fisicamente.connect(_on_objeto_soltado)
			inv.objeto_consumido.connect(_on_objeto_consumido)
		print("Sistemas de inventario conectados para el jugador: ", name)

# --- SISTEMA DE MEJORAS (UPGRADES) ---

func mejorar_mochila(nuevo_w: int, nuevo_h: int):
	mochila.actualizar_tamano(nuevo_w, nuevo_h)
	print("Mochila mejorada a: ", nuevo_w, "x", nuevo_h)

func mejorar_cinturon(nuevo_w: int):
	cinturon.actualizar_tamano(nuevo_w, 1)
	print("Cinturón mejorado a: ", nuevo_w, " slots")

# --- CALLBACKS DE SEÑALES ---

func _on_peso_cambiado(_peso_del_nodo_emisor: float):
	# Recalculamos el peso total sumando los tres contenedores
	total_inventory_weight = mochila.calcular_peso_total() + \
							 cinturon.calcular_peso_total() + \
							 mano.calcular_peso_total()
	# Aquí podrías emitir una señal a la UI si fuera necesario

func _on_objeto_consumido(data: Dictionary):
	# El Player actúa como mediador entre el Inventario y el Cuerpo (Status)
	if data.has("valor_recarga"):
		status.añadir_oxigeno(data["valor_recarga"])
	
	if data.has("valor_curacion"):
		status.curar(data["valor_curacion"])
	
	print("Consumido: ", data.get("nombre", "Objeto desconocido"))

func _on_objeto_soltado(item_id: String):
	# Calculamos posición de spawn: 1.5m adelante, 1m arriba
	var spawn_pos = global_position + (global_transform.basis.z * -1.5) + Vector3(0, 1.0, 0)
	# Disparamos el RPC para que todos los jugadores vean el objeto
	generar_en_red.rpc(item_id, spawn_pos)

# --- MULTIJUGADOR: SPAWN DE OBJETOS ---

@rpc("any_peer", "call_local", "reliable")
func generar_en_red(id: String, pos: Vector3):
	var nuevo_objeto = ITEM_SCENE.instantiate()
	nuevo_objeto.item_id = id 
	get_tree().current_scene.add_child(nuevo_objeto)
	nuevo_objeto.global_position = pos
	
	# Pequeño impulso físico hacia adelante
	if nuevo_objeto is RigidBody3D:
		var dir = (pos - global_position).normalized()
		nuevo_objeto.apply_central_impulse(dir * 3.0)

func morir():
	print("Muerte detectada. Desactivando procesos...")
	set_physics_process(false)
	# Aquí podrías añadir lógica de ragdoll o pantalla de Game Over

# --- SISTEMA DE PRUEBAS ---

func _unhandled_input(event):
	if not is_multiplayer_authority(): return

	# [Tecla 1] Probar Filtros (Intenta meter batería en cinturón y mochila)
	if event.is_action_pressed("ui_accept"): # Usaremos Enter como ejemplo
		print("\n--- TEST: Intentando añadir BATERÍA (Recurso) ---")
		mochila.auto_add_item("bateria_litio")
		cinturon.auto_add_item("bateria_litio") # Debería fallar por filtro

	# [Tecla 2] Probar Mano y Herramientas
	if Input.is_key_pressed(KEY_2):
		print("\n--- TEST: Añadiendo SOLDADOR (Herramienta) a la Mano ---")
		mano.auto_add_item("soldador_plasma") # Debería entrar aunque sea 2x2

	# [Tecla 3] Probar Consumo de O2
	if Input.is_key_pressed(KEY_3):
		print("\n--- TEST: Añadir y Consumir O2 ---")
		if mochila.auto_add_item("capsula_oxigeno"):
			# Usamos el último objeto de la mochila
			mochila.use_item(mochila.inventory_items.size() - 1)

	# [Tecla 4] Probar Soltar
	if Input.is_key_pressed(KEY_4):
		print("\n--- TEST: Soltando primer objeto de la mochila ---")
		if mochila.inventory_items.size() > 0:
			mochila.drop_item(0)

	# [Tecla 5] Probar Mejora de Cinturón
	if Input.is_key_pressed(KEY_5):
		mejorar_cinturon(6)

	# [Tecla P] Reporte de consola
	if Input.is_key_pressed(KEY_P):
		print("\n--- REPORTE DE JUGADOR ---")
		print("- Peso Total: ", total_inventory_weight, " kg")
		print("- Oxígeno: ", status.current_oxygen, " %")
		print("- Slots Cinturón: ", cinturon.grid_width)
