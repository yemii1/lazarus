extends Node3D

@onready var player = owner
@onready var camera = $Camera3D
@onready var status = $"../StatusManager"

var normal_fov = 75.0
var t_bob = 0.0
var pulse_intensity: float = 0.0

func _ready():
	if player.is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		status.salud_cambiada.connect(_on_salud_update)
		status.agotado.connect(_on_agotado_update)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.002)
		rotate_x(-event.relative.y * 0.002)
		rotation.x = clamp(rotation.x, -1.5, 1.5)

func _process(delta):
	if not player.is_multiplayer_authority(): return
	
	# Agachado suave
	var target_y = 0.0 if Input.is_action_pressed("crouch") else 0.6
	position.y = lerp(position.y, target_y, delta * 10)
	
	# Headbob
	var vel = Vector3(player.velocity.x, 0, player.velocity.z).length()
	if player.is_on_floor() and vel > 0.1:
		t_bob += delta * vel
		camera.transform.origin.y = sin(t_bob * 2.0) * (0.04 * (vel/8.0))
		camera.rotation.z = lerp(camera.rotation.z, cos(t_bob) * 0.01, delta * 10)
	else:
		camera.transform.origin = camera.transform.origin.lerp(Vector3.ZERO, delta * 10)
		camera.rotation.z = lerp(camera.rotation.z, 0.0, delta * 10)

	# Efectos FOV
	var pulse = sin(Time.get_ticks_msec() * 0.005) * pulse_intensity
	camera.fov = lerp(camera.fov, normal_fov + pulse, delta * 5)

func _on_salud_update(a, _m): pulse_intensity = 5.0 if a < 30.0 else 0.0
func _on_agotado_update(v): if v: pulse_intensity = 2.0
