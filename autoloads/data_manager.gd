extends Node

# La base de datos vive aquí durante toda la ejecución
var item_database: Dictionary = {}

# Definimos un "Item de Error" para evitar que el juego crashee si falla un ID
const FALLBACK_ITEM = {
	"nombre": "Error de Datos",
	"descripcion": "Este objeto no existe en el JSON.",
	"peso": 0.0,
	"grid_width": 1,
	"grid_height": 1,
	"tipo": "recurso"
}

func _ready():
	_cargar_base_de_datos()

func _cargar_base_de_datos():
	var ruta = "res://Data/items.json"
	
	if not FileAccess.file_exists(ruta):
		push_error("DataManager: ARCHIVO NO ENCONTRADO en: " + ruta)
		return
	
	var file = FileAccess.open(ruta, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close() # Cerramos el archivo manualmente
	
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error == OK:
		if typeof(json.data) == TYPE_DICTIONARY:
			item_database = json.data
			print("DataManager: " + str(item_database.size()) + " objetos cargados.")
		else:
			push_error("DataManager: El formato del JSON no es un Diccionario.")
	else:
		push_error("DataManager: Error al parsear JSON en línea " + str(json.get_error_line()) + ": " + json.get_error_message())

# --- FUNCIÓN DE ACCESO SEGURO ---

func get_item(id: String) -> Dictionary:
	if id == "" or id == null:
		return {}
		
	if item_database.has(id):
		return item_database[id]
	
	# ID no existe
	push_warning("DataManager: El ID '" + id + "' no existe. Devolviendo objeto de seguridad.")
	return FALLBACK_ITEM.duplicate()
