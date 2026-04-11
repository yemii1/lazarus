extends Node

# --- SEÑALES ---
signal peso_actualizado(nuevo_peso: float)
signal objeto_soltado_fisicamente(item_id: String)
signal objeto_consumido(data: Dictionary)

@export_group("Configuración de Contenedor")
@export var grid_width: int = 8
@export var grid_height: int = 6
@export_enum("any", "recurso", "herramienta", "consumible") var filtro_tipo: String = "any"

@export_group("Modo Especial")
@export var es_slot_de_mano: bool = false 

var inventory_items: Array = []
var total_weight: float = 0.0 # Variable caché que el Player leerá directamente

func actualizar_tamano(nuevo_ancho: int, nuevo_alto: int):
	grid_width = nuevo_ancho
	grid_height = nuevo_alto
	_recalcular_peso_completo()

# --- GESTIÓN DE PESO OPTIMIZADA ---

func _recalcular_peso_completo():
	total_weight = 0.0
	for item in inventory_items:
		var d = DataManager.get_item(item["id"])
		if not d.is_empty(): 
			total_weight += d.get("peso", 0.0)
	peso_actualizado.emit(total_weight)

func _actualizar_peso_item(item_id: String, añadir: bool):
	var d = DataManager.get_item(item_id)
	if d.is_empty(): return
	
	var peso_item = d.get("peso", 0.0)
	if añadir:
		total_weight += peso_item
	else:
		total_weight -= peso_item
	
	# Avisamos al Player de que el peso de este inventario ha cambiado
	peso_actualizado.emit(total_weight)

# --- LÓGICA DE ADICIÓN ---

func auto_add_item(item_id: String) -> bool:
	var data = DataManager.get_item(item_id)
	if data.is_empty(): return false
	
	if filtro_tipo != "any" and data.get("tipo") != filtro_tipo: return false
	
	if es_slot_de_mano:
		if inventory_items.size() == 0:
			inventory_items.append({"id": item_id, "x": 0, "y": 0, "rotated": false})
			_actualizar_peso_item(item_id, true)
			return true
		return false

	var hueco = _find_first_free_space(data["grid_width"], data["grid_height"])
	if hueco.x == -1: return false
	
	inventory_items.append({"id": item_id, "x": int(hueco.x), "y": int(hueco.y), "rotated": false})
	_actualizar_peso_item(item_id, true)
	return true

func add_item_at(item_id: String, tx: int, ty: int, is_rotated: bool) -> bool:
	var data = DataManager.get_item(item_id)
	if data.is_empty(): return false
	if filtro_tipo != "any" and data.get("tipo") != filtro_tipo: return false
	
	if es_slot_de_mano: return auto_add_item(item_id)

	var w = data["grid_height"] if is_rotated else data["grid_width"]
	var h = data["grid_width"] if is_rotated else data["grid_height"]
	
	if is_space_free(tx, ty, w, h):
		inventory_items.append({"id": item_id, "x": tx, "y": ty, "rotated": is_rotated})
		_actualizar_peso_item(item_id, true)
		return true
	return false

# --- INTERACCIÓN ---

func drop_item(item_index: int):
	if item_index < 0 or item_index >= inventory_items.size(): return
	var item_id = inventory_items[item_index]["id"]
	
	inventory_items.remove_at(item_index)
	_actualizar_peso_item(item_id, false)
	objeto_soltado_fisicamente.emit(item_id)

func use_item(item_index: int):
	if item_index < 0 or item_index >= inventory_items.size(): return
	var data = DataManager.get_item(inventory_items[item_index]["id"])
	
	if data.get("tipo") == "consumible":
		var item_id = inventory_items[item_index]["id"]
		inventory_items.remove_at(item_index)
		_actualizar_peso_item(item_id, false)
		objeto_consumido.emit(data)

# --- MATEMÁTICAS DEL GRID ---

func is_space_free(tx: int, ty: int, tw: int, th: int) -> bool:
	if tx < 0 or ty < 0 or (tx + tw) > grid_width or (ty + th) > grid_height: return false
	
	for item in inventory_items:
		var d = DataManager.get_item(item["id"])
		var sw = d["grid_height"] if item.get("rotated", false) else d["grid_width"]
		var sh = d["grid_width"] if item.get("rotated", false) else d["grid_height"]
		
		if tx < (item["x"] + sw) and (tx + tw) > item["x"] and ty < (item["y"] + sh) and (ty + th) > item["y"]:
			return false
	return true

func _find_first_free_space(w: int, h: int) -> Vector2:
	for y in range(grid_height):
		for x in range(grid_width):
			if is_space_free(x, y, w, h): return Vector2(x, y)
	return Vector2(-1, -1)

# --- TRANSFERENCIA ---

func transfer_to(item_index: int, target_inv: Node, tx: int = -1, ty: int = -1, is_rot: bool = false) -> bool:
	if item_index < 0 or item_index >= inventory_items.size(): return false
	
	var item = inventory_items[item_index]
	var item_id = item["id"]
	var old_x = item["x"]
	var old_y = item["y"]
	var old_rot = item.get("rotated", false)
	
	# Quitamos temporalmente (incluyendo peso)
	inventory_items.remove_at(item_index)
	_actualizar_peso_item(item_id, false)
	
	var exito = false
	if tx == -1:
		exito = target_inv.auto_add_item(item_id)
	else:
		exito = target_inv.add_item_at(item_id, tx, ty, is_rot)
	
	if exito:
		return true
	else:
		# Fallo: Restauramos posición y peso
		inventory_items.insert(item_index, {"id": item_id, "x": old_x, "y": old_y, "rotated": old_rot})
		_actualizar_peso_item(item_id, true)
		return false
