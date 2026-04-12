extends PanelContainer

@onready var bg_color = $BgColor

var my_index: int = -1
var my_inventory: Node = null
var item_id: String = ""
var mi_menu: Control = null 

# --- CONFIGURACIÓN ---
func setup(index: int, inventory: Node, id: String, menu_ref: Control = null):
	my_index = index
	my_inventory = inventory
	item_id = id
	mi_menu = menu_ref 
	
	if item_id != "":
		bg_color.color = Color(0.2, 0.8, 0.2, 0.8) # Verde para ocupado
		var data = DataManager.get_item(item_id)
		
		if not data.is_empty():
			var nombre = data.get("nombre", "Objeto")
			var peso = data.get("peso", 0.0)
			var desc = data.get("descripcion", "")
			tooltip_text = nombre + "\n" + "Peso: " + str(peso) + " kg\n" + desc
	else:
		bg_color.color = Color(0.1, 0.1, 0.1, 0.5) # Oscuro para vacío
		tooltip_text = ""

# --- DRAG & DROP ---

func _get_drag_data(_at_position: Vector2):
	if item_id == "": return null
	
	var data_item = DataManager.get_item(item_id)
	var real_idx = _obtener_indice_real_del_item(item_id)
	if real_idx == -1: return null
	
	var current_rot = my_inventory.inventory_items[real_idx].get("rotated", false)
	
	# Creamos el preview (fantasma verde)
	var preview = ColorRect.new()
	preview.color = Color(0.2, 0.8, 0.2, 0.5)
	
	var w = data_item["grid_height"] if current_rot else data_item["grid_width"]
	var h = data_item["grid_width"] if current_rot else data_item["grid_height"]
	preview.custom_minimum_size = Vector2(w * 64, h * 64) 
	
	var drag_control = Control.new()
	drag_control.add_child(preview)
	set_drag_preview(drag_control)
	
	# Comunicamos el estado al menú principal para permitir rotación con 'R'
	if is_instance_valid(mi_menu):
		mi_menu.dragged_preview_node = preview
		mi_menu.dragged_is_rotated = current_rot
	
	return {"source_inv": my_inventory, "source_index": real_idx}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.has("source_inv")

func _drop_data(_at_position: Vector2, drag_data: Variant):
	# Si no hay referencia al menú, asumimos que no hay rotación extra
	var final_rot = mi_menu.dragged_is_rotated if is_instance_valid(mi_menu) else false
	
	var target_x = my_index % my_inventory.grid_width
	var target_y = int(my_index / my_inventory.grid_width)
	
	drag_data["source_inv"].transfer_to(drag_data["source_index"], my_inventory, target_x, target_y, final_rot)

# --- INTERACCIÓN Y MENÚ CONTEXTUAL ---

func _gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if item_id != "":
			_mostrar_menu_contextual(event.global_position)

func _mostrar_menu_contextual(pos_raton: Vector2):
	var data = DataManager.get_item(item_id)
	if data.is_empty(): return
	
	var popup = PopupMenu.new()
	
	if data.get("tipo") == "consumible":
		popup.add_item("Consumir", 0)
	popup.add_item("Tirar al suelo", 1)
	
	popup.id_pressed.connect(_on_menu_opcion_seleccionada)
	# IMPORTANTE: Que el popup se borre al cerrarse para no acumular basura
	popup.popup_hide.connect(func(): popup.queue_free())
	
	add_child(popup)
	popup.popup(Rect2(pos_raton.x, pos_raton.y, 150, 60))

func _on_menu_opcion_seleccionada(id_opcion: int):
	var real_index = _obtener_indice_real_del_item(item_id)
	if real_index == -1: return
	
	if id_opcion == 0:
		my_inventory.use_item(real_index)
	elif id_opcion == 1:
		my_inventory.drop_item(real_index)

# --- AUXILIARES ---

func _obtener_indice_real_del_item(id_a_buscar: String) -> int:
	# Buscamos en el array de diccionarios del backend
	for i in range(my_inventory.inventory_items.size()):
		if my_inventory.inventory_items[i]["id"] == id_a_buscar:
			return i
	return -1
