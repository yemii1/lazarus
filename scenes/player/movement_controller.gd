extends Node

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 4.5

@onready var player = owner
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var waiting_for_sprint_release: bool = false

func _physics_process(delta):
	if not player.is_multiplayer_authority(): return

	var weight_penalty = player.total_inventory_weight * 0.1
	
	# Gravedad y Salto
	if not player.is_on_floor():
		player.velocity.y -= gravity * delta
	elif Input.is_action_just_pressed("jump"):
		player.velocity.y = max(1.0, jump_velocity - (weight_penalty * 0.5))

	# Determinar velocidad
	var speed = walk_speed
	if Input.is_action_pressed("crouch"):
		speed = crouch_speed
	elif Input.is_action_pressed("sprint") and not player.is_exhausted and not waiting_for_sprint_release:
		speed = sprint_speed
		player.is_sprinting = true
	else:
		player.is_sprinting = false
		if player.is_exhausted: waiting_for_sprint_release = true
	
	if not Input.is_action_pressed("sprint"): waiting_for_sprint_release = false
	
	var final_speed = max(1.5, speed - weight_penalty)
	
	# Aplicar movimiento
	var input_dir = Input.get_vector("left", "right", "forward", "backward")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		player.velocity.x = direction.x * final_speed
		player.velocity.z = direction.z * final_speed
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, final_speed)
		player.velocity.z = move_toward(player.velocity.z, 0, final_speed)

	player.move_and_slide()
