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

func setup(jugador_ref: CharacterBody3D):
	player = jugador_ref
	# Conectamos las señales del jugador a este menú
	if not player.mochila.peso_actualizado.is_connected(_actualizar_todo):
		player.mochila.peso_actualizado.connect(_actualizar_todo)
		player.cinturon.peso_actualizado.connect(_actualizar_todo)
		player.mano.peso_actualizado.connect(_actualizar_todo)
	
	# Dibujamos los slots por primera vez
	_actualizar_todo(0)

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

# --- LÓGICA DE DIBUJADO (OPTIMIZADA) ---

func _actualizar_todo(_peso_ignorante):
	if not is_instance_valid(player): 
		return # SOLO abortamos si el jugador no existe
	
	# Si llega aquí, dibuja siempre (esté abierto o cerrado)
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
