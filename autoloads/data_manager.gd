extends Node

var item_database: Dictionary = {}

func _ready():
	_cargar_base_de_datos()

func _cargar_base_de_datos():
	var ruta = "res://Data/items.json"
	if not FileAccess.file_exists(ruta):
		print("❌ DataManager: No se encontró el archivo JSON en: ", ruta)
		return
	
	var file = FileAccess.open(ruta, FileAccess.READ)
	var json_string = file.get_as_text()
	var json = JSON.new()
	if json.parse(json_string) == OK:
		item_database = json.data
		print("🧠 DataManager: Base de datos cargada (", item_database.size(), " objetos).")

func get_item(id: String) -> Dictionary:
	return item_database.get(id, {})
