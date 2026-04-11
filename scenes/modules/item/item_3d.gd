extends RigidBody3D

@export var item_id: String = "chatarra":
	set(nuevo_id):
		item_id = nuevo_id
		_cargar_datos_item()

var item_data: Dictionary

func _ready():
	# Forzamos que la autoridad sea el servidor para la física y destrucción
	set_multiplayer_authority(1)
	_cargar_datos_item()

func _cargar_datos_item():
	# Esperamos un frame si el nodo no está en el árbol para evitar errores de setup
	if not is_inside_tree(): await ready
	
	item_data = DataManager.get_item(item_id)
	
	if item_data.is_empty():
		if item_id != "chatarra": # Ignoramos el aviso para el ID por defecto
			push_error("Item3D: El ID '" + item_id + "' no existe en el JSON.")
	else:
		# Aquí es donde en el futuro pondrás:
		# _actualizar_modelo_visual(item_data.get("escena_visual"))
		pass

# --- LÓGICA DE INTERACCIÓN ---

func interactuar(target_player: CharacterBody3D):
	# Intentamos añadir el objeto siguiendo un orden lógico de prioridad
	var exito = false
	
	# 1. Intentar en Cinturón (si es herramienta) o directamente en Mochila
	if item_data.get("tipo") == "herramienta":
		exito = target_player.cinturon.auto_add_item(item_id)
	
	# 2. Si no es herramienta o el cinturón está lleno, intentar en mochila
	if not exito:
		exito = target_player.mochila.auto_add_item(item_id)
		
	if exito:
		_notificar_recogida_servidor()
	else:
		print("📦 Inventario lleno: No se puede recoger ", item_id)

# --- SINCRONIZACIÓN DE RED ---

func _notificar_recogida_servidor():
	if multiplayer.is_server():
		destruir_en_red.rpc()
	else:
		solicitar_destruccion_al_servidor.rpc_id(1)

@rpc("any_peer", "call_remote", "reliable")
func solicitar_destruccion_al_servidor():
	# Solo el servidor tiene permiso para borrar objetos del mundo
	if not multiplayer.is_server(): return
	destruir_en_red.rpc()

@rpc("any_peer", "call_local", "reliable")
func destruir_en_red():
	# call_local asegura que el servidor también lo borre para sí mismo
	queue_free()
