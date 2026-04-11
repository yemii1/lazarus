extends Node

# Variables base que ahora son modificables
var base_walk_speed = 5.0
var base_sprint_speed = 8.0
var crouch_speed = 2.5
var jump_velocity = 4.5
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var waiting_for_sprint_release: bool = false

@onready var player = get_parent() # El componente habla con el Jefe
@onready var status = $"../StatusManager"

func _physics_process(delta):
	if not player.is_multiplayer_authority(): return

	# --- SISTEMA DE PESO DINÁMICO ---
	# Leemos el peso del inventario del Jefe. Cada 10kg = -1 de velocidad
	var weight_penalty = player.total_inventory_weight * 0.1 
	
	# La velocidad nunca bajará de 1.0 aunque lleves 1000 kilos (para no quedarte atascado)
	var current_speed = max(1.0, base_walk_speed - weight_penalty)

	# Gravedad
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta

	# Salto
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		# Si llevas mucho peso, saltarás menos
		player.velocity.y = max(1.0, jump_velocity - (weight_penalty * 0.5))

	# --- CONTROL DE FATIGA (EL PARCHE) ---
	# Si llegas a 0 de estamina, activamos el castigo
	if status.is_exhausted:
		waiting_for_sprint_release = true
		
	# El castigo solo se levanta cuando el jugador SUELTA la tecla Shift
	if not Input.is_action_pressed("sprint"):
		waiting_for_sprint_release = false


	# --- ESTADOS DE MOVIMIENTO ---
	if Input.is_action_pressed("crouch"):
		current_speed = crouch_speed
		status.regen_stamina(delta) 
		
	# Añadimos la condición "not waiting_for_sprint_release" para bloquear el auto-sprint
	elif Input.is_action_pressed("sprint") and player.is_on_floor() and not status.is_exhausted and not waiting_for_sprint_release:
		current_speed = max(2.0, base_sprint_speed - weight_penalty)
		status.drain_stamina(delta) 
		
	else:
		current_speed = max(1.0, base_walk_speed - weight_penalty)
		status.regen_stamina(delta)

	# Movimiento WASD
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = direction.x * current_speed
		player.velocity.z = direction.z * current_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, current_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, current_speed)

	# El subordinado le dice al Jefe que ejecute las físicas
	player.move_and_slide()
