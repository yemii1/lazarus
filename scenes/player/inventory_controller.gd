extends Node

signal peso_actualizado(nuevo_peso: float)
signal objeto_soltado_fisicamente(item_id: String)
signal objeto_consumido(data: Dictionary)

@export_group("Configuración de Contenedor")
@export var grid_width: int = 8
@export var grid_height: int = 6
@export_enum("any", "recurso", "herramienta", "consumible") var filtro_tipo: String = "any"

@export_group("Modo Especial")
@export var es_slot_de_mano: bool = false # Si es true, ignora el tamaño del grid

var inventory_items: Array = []

func actualizar_tamano(nuevo_ancho: int, nuevo_alto: int):
	grid_width = nuevo_ancho
	grid_height = nuevo_alto
	peso_actualizado.emit(calcular_peso_total())

func auto_add_item(item_id: String) -> bool:
	var data = DataManager.get_item(item_id)
	if data.is_empty(): return false
	
	# 1. Validar Filtro de Tipo
	if filtro_tipo != "any" and data.get("tipo") != filtro_tipo:
		print("🚫 ", name, " no acepta: ", data.get("tipo"))
		return false
	
	# 2. Lógica Especial para la Mano
	if es_slot_de_mano:
		if inventory_items.size() == 0:
			# En la mano, siempre guardamos en 0,0 sin importar el tamaño
			inventory_items.append({"id": item_id, "x": 0, "y": 0, "rotated": false})
			peso_actualizado.emit(calcular_peso_total())
			return true
		else:
			print("🚫 La mano ya está ocupada")
			return false

	# 3. Lógica Normal de Cuadrícula (Mochila y Cinturón)
	var hueco = _find_first_free_space(data["grid_width"], data["grid_height"])
	if hueco.x == -1: 
		print("🚫 No hay espacio en ", name)
		return false
	
	inventory_items.append({"id": item_id, "x": int(hueco.x), "y": int(hueco.y), "rotated": false})
	peso_actualizado.emit(calcular_peso_total())
	return true

func drop_item(item_index: int):
	if item_index < 0 or item_index >= inventory_items.size(): return
	var item_id = inventory_items[item_index]["id"]
	inventory_items.remove_at(item_index)
	peso_actualizado.emit(calcular_peso_total())
	objeto_soltado_fisicamente.emit(item_id)

func use_item(item_index: int):
	if item_index < 0 or item_index >= inventory_items.size(): return
	var data = DataManager.get_item(inventory_items[item_index]["id"])
	if data.get("tipo") == "consumible":
		inventory_items.remove_at(item_index)
		peso_actualizado.emit(calcular_peso_total())
		objeto_consumido.emit(data)

func calcular_peso_total() -> float:
	var total = 0.0
	for item in inventory_items:
		var d = DataManager.get_item(item["id"])
		if not d.is_empty(): total += d["peso"]
	return total

func is_space_free(tx: int, ty: int, tw: int, th: int) -> bool:
	if tx < 0 or ty < 0 or (tx + tw) > grid_width or (ty + th) > grid_height: return false
	for item in inventory_items:
		var d = DataManager.get_item(item["id"])
		var sw = d["grid_height"] if item["rotated"] else d["grid_width"]
		var sh = d["grid_width"] if item["rotated"] else d["grid_height"]
		if tx < (item["x"] + sw) and (tx + tw) > item["x"] and ty < (item["y"] + sh) and (ty + th) > item["y"]:
			return false
	return true

func _find_first_free_space(w: int, h: int) -> Vector2:
	for y in range(grid_height):
		for x in range(grid_width):
			if is_space_free(x, y, w, h): return Vector2(x, y)
	return Vector2(-1, -1)

# Transfiere un objeto de ESTE inventario a OTRO (destino)
func transfer_to(item_index: int, target_inventory: Node) -> bool:
	if item_index < 0 or item_index >= inventory_items.size():
		return false
	
	var item = inventory_items[item_index]
	
	# Intentamos añadirlo al otro inventario
	if target_inventory.auto_add_item(item["id"]):
		# Si el destino lo aceptó, lo borramos de aquí
		inventory_items.remove_at(item_index)
		peso_actualizado.emit(calcular_peso_total())
		return true
		
	return false
