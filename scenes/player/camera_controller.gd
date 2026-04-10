extends Node3D

const MOUSE_SENSITIVITY = 0.002
const BOB_FREQ = 2.0
const BOB_AMP = 0.04
var t_bob = 0.0

@onready var camera = $Camera3D
@onready var player = get_parent() # El componente habla con el Jefe

func _ready():
	if player.is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event):
	if not player.is_multiplayer_authority(): return
	
	if Input.is_action_just_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * MOUSE_SENSITIVITY)
		rotate_x(-event.relative.y * MOUSE_SENSITIVITY)
		rotation.x = clamp(rotation.x, deg_to_rad(-89), deg_to_rad(89))

func _process(delta):
	if not player.is_multiplayer_authority(): return

	# Agacharse (Solo la cámara baja, las colisiones las bajaremos luego si hace falta)
	if Input.is_action_pressed("crouch"):
		position.y = lerp(position.y, 0.0, delta * 10)
	else:
		position.y = lerp(position.y, 0.6, delta * 10)

	# Head Bobbing leyendo la velocidad real del Jefe
	var current_velocity = Vector3(player.velocity.x, 0, player.velocity.z)
	
	if player.is_on_floor() and current_velocity.length() > 0.1:
		t_bob += delta * current_velocity.length()
		var effort_ratio = current_velocity.length() / 8.0 # 8.0 es el sprint base
		var bob_data = _calculate_headbob(t_bob, effort_ratio)
		camera.transform.origin = bob_data[0]
		camera.rotation.z = bob_data[1]
	else:
		t_bob = 0.0
		camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 10)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 10)

func _calculate_headbob(time, effort_ratio) -> Array:
	var pos = Vector3.ZERO
	var dynamic_amp = BOB_AMP * effort_ratio
	pos.y = sin(time * BOB_FREQ) * dynamic_amp
	pos.x = cos(time * BOB_FREQ / 2) * dynamic_amp
	var tilt = cos(time * BOB_FREQ / 2) * (dynamic_amp * 0.15)
	return [pos, tilt]
