extends RigidBody3D

@export var item_id: String = "chatarra"
var item_data: Dictionary

func _ready():
	item_data = DataManager.get_item(item_id)
	if item_data.is_empty():
		push_error("Item3D: El ID '" + item_id + "' no existe en el JSON.")

# 1. El jugador interactúa (Esto ocurre de forma LOCAL en su PC)
func interactuar(mochila: Node):
	var exito = mochila.auto_add_item(item_id)
	
	if exito:
		# ¡CAMBIO AQUÍ! En lugar de borrarlo solo en mi PC, doy la orden por radio
		destruir_en_red.rpc()
	else:
		# Si no hay hueco, no hacemos nada (o suena un error)
		pass

# 2. La función de Red (Esto ocurre en TODOS los PCs conectados)
@rpc("any_peer", "call_local", "reliable")
func destruir_en_red():
	queue_free()
