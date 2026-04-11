extends Control

# --- CONFIGURACIÓN ---
@export var slot_scene: PackedScene = preload("res://scenes/modules/inventory/inventory_slot.tscn")

@onready var backpack_grid = %BackpackGrid
@onready var toolbelt_grid = %ToolBeltGrid
@onready var hand_slot_ui = %HandSlotUI

var player: CharacterBody3D = null

# ESTADO DE ARRASTRE (Para rotación con 'R')
var dragged_preview_node: Control = null
var dragged_is_rotated: bool = false

func _ready():
	visible = false
	_esperar_jugador_local()

func _esperar_jugador_local():
	var mi_id = str(multiplayer.get_unique_id())
	var target = get_tree().current_scene.find_child(mi_id, true, false)
	
	# Verificación de "Seguridad Triple":
	# 1. ¿Existe el nodo jugador?
	# 2. ¿Tiene el script correcto?
	# 3. ¿Sus variables @onready ya se inicializaron? (no son null)
	if target and "mochila" in target and target.mochila != null:
		player = target
		_conectar_senales_jugador()
	else:
		# Si no está listo, esperamos un frame y reintentamos
		await get_tree().process_frame 
		_esperar_jugador_local()

func _conectar_senales_jugador():
	# Doble protección con is_instance_valid por si el jugador se desconecta justo ahora
	if not is_instance_valid(player): return
	
	# Usamos una técnica más segura: conectar solo si no están conectadas
	if not player.mochila.peso_actualizado.is_connected(_actualizar_todo):
		player.mochila.peso_actualizado.connect(_actualizar_todo)
		player.cinturon.peso_actualizado.connect(_actualizar_todo)
		player.mano.peso_actualizado.connect(_actualizar_todo)
	
	_actualizar_todo(0)

# --- SISTEMA DE ROTACIÓN ---

func _process(_delta):
	if not visible: return
	
	# Si Godot detecta que estamos arrastrando algo...
	if get_viewport().gui_is_dragging():
		if Input.is_action_just_pressed("rotate_item") and is_instance_valid(dragged_preview_node):
			dragged_is_rotated = !dragged_is_rotated
			
			# Invertimos las dimensiones del preview visual
			var current_size = dragged_preview_node.custom_minimum_size
			dragged_preview_node.custom_minimum_size = Vector2(current_size.y, current_size.x)
	else:
		dragged_preview_node = null

# --- INPUT Y VISIBILIDAD ---

func _input(event):
	if not player: return 
	
	if event.is_action_pressed("inventory"): 
		visible = !visible
		if visible:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			_actualizar_todo(0)
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# --- LÓGICA DE DIBUJADO (OPTIMIZADA) ---

func _actualizar_todo(_peso_ignorante):
	if not player or not visible: return 
	
	_dibujar_contenedor(backpack_grid, player.mochila)
	_dibujar_contenedor(toolbelt_grid, player.cinturon)
	_dibujar_contenedor(hand_slot_ui, player.mano)

func _dibujar_contenedor(ui_container: Control, backend: Node):
	# Limpieza rápida
	for child in ui_container.get_children():
		child.queue_free()
	
	if ui_container is GridContainer:
		ui_container.columns = backend.grid_width
	
	var total_slots = backend.grid_width * backend.grid_height
	
	for i in range(total_slots):
		var slot_x = i % backend.grid_width
		var slot_y = int(i / backend.grid_width)
		var item_id_found = ""
		
		# Buscamos qué item ocupa esta celda
		for item in backend.inventory_items:
			var d = DataManager.get_item(item["id"])
			if d.is_empty(): continue
			
			if backend.get("es_slot_de_mano"):
				item_id_found = item["id"]
				break
			
			# Calculamos el área ocupada por el item (teniendo en cuenta su rotación)
			var is_rot = item.get("rotated", false)
			var w = d["grid_height"] if is_rot else d["grid_width"]
			var h = d["grid_width"] if is_rot else d["grid_height"]
			
			if slot_x >= item["x"] and slot_x < item["x"] + w and \
			   slot_y >= item["y"] and slot_y < item["y"] + h:
				item_id_found = item["id"]
				break
		
		var new_slot = slot_scene.instantiate()
		ui_container.add_child(new_slot)
		new_slot.setup(i, backend, item_id_found, self)
