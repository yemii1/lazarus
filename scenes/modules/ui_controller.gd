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
		# Buscamos la cámara dentro del jugador
		# Usa get_node_or_null para evitar crasheos 
		var player_camera = player.get_node_or_null("Head/Camera3D")
		
		if player_camera:
			helmet_hud.setup(player, player_camera) 
		else:
			print("No se encontró la cámara en Head/Camera3D")
		
		# Conectamos la señal del jugador a nuestra función
		if not player.casco_toggled.is_connected(_on_casco_toggled):
			player.casco_toggled.connect(_on_casco_toggled)
		
		# Forzamos el estado inicial para que coincida )
		_on_casco_toggled(player.tiene_casco_puesto)
		
	# 2. ENCENDEMOS EL INVENTARIO
	if is_instance_valid(inventory_menu):
		inventory_menu.setup(player)
		
	_actualizar_mouse()

func _on_casco_toggled(esta_puesto: bool):
	print("2. [UI]: Señal recibida. HUD visible = ", esta_puesto) # <-- AÑADE ESTO
	if is_instance_valid(helmet_hud):
		helmet_hud.visible = esta_puesto
		
		# Apagamos/Encendemos el cerebro del HUD para ahorrar recursos de la gráfica
		helmet_hud.set_process(esta_puesto)
		helmet_hud.set_process_input(esta_puesto)

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
