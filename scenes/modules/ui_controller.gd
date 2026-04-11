extends CanvasLayer

@onready var helmet_hud = $HelmetHUD
@onready var inventory_menu = $InventoryMenu

var player: CharacterBody3D = null

func _ready():
	# El inventario empieza apagado, el casco encendido
	inventory_menu.visible = false
	_esperar_jugador()

func _esperar_jugador():
	var mi_id = str(multiplayer.get_unique_id())
	var target = get_tree().current_scene.find_child(mi_id, true, false)
	
	if target and "status" in target and target.status != null:
		player = target
		_iniciar_interfaces()
	else:
		await get_tree().process_frame
		_esperar_jugador()

func _iniciar_interfaces():
	# 1. Encendemos el casco
	if is_instance_valid(helmet_hud):
		helmet_hud.setup(player)
		
	# 2. ENCENDEMOS EL INVENTARIO (Esta línea es la clave)
	if is_instance_valid(inventory_menu):
		inventory_menu.setup(player)
		
	_actualizar_mouse()

func _input(event):
	if not is_instance_valid(player): return
	
	# Abrir/Cerrar inventario
	if event.is_action_pressed("inventory"):
		inventory_menu.visible = !inventory_menu.visible
		_actualizar_mouse()

func _actualizar_mouse():
	if inventory_menu.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
