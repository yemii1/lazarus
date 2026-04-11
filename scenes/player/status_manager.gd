extends Node

@onready var player = get_parent()

var max_health = 100.0
var current_health = 100.0
var max_oxygen = 100.0
var current_oxygen = 100.0
var max_stamina = 100.0
var current_stamina = 100.0

var is_suffocating: bool = false
var is_exhausted: bool = false
var is_dead: bool = false

func _process(delta):
	if not player.is_multiplayer_authority() or is_dead: return
	_manejar_oxigeno(delta)

func _manejar_oxigeno(delta):
	if current_oxygen > 0:
		current_oxygen -= 0.5 * delta
		is_suffocating = false
	else:
		is_suffocating = true
		recibir_daño(5.0 * delta)

func drain_stamina(delta):
	current_stamina = move_toward(current_stamina, 0, 20.0 * delta)
	if current_stamina <= 0:
		is_exhausted = true
		player.is_sprinting = false

func regen_stamina(delta):
	current_stamina = move_toward(current_stamina, max_stamina, 10.0 * delta)
	if current_stamina > 20.0: is_exhausted = false

func recibir_daño(cantidad):
	current_health = clamp(current_health - cantidad, 0, max_health)
	if current_health <= 0 and not is_dead:
		is_dead = true
		player.morir()

func curar(cantidad):
	current_health = clamp(current_health + cantidad, 0, max_health)

func añadir_oxigeno(cantidad):
	current_oxygen = clamp(current_oxygen + cantidad, 0, max_oxygen)
