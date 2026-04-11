extends Node

signal salud_cambiada(actual: float, max: float)
signal oxigeno_cambiada(actual: float, max: float)
signal hambre_cambiada(actual: float, max: float)
signal sed_cambiada(actual: float, max: float)
signal estamina_cambiada(actual: float, max: float)
signal agotado(v: bool)
signal ha_muerto()

@export var max_health: float = 100.0
@export var max_oxygen: float = 100.0
@export var max_hunger: float = 100.0
@export var max_thirst: float = 100.0
@export var max_stamina: float = 100.0

@onready var current_health = max_health
@onready var current_oxygen = max_oxygen
@onready var current_hunger = max_hunger
@onready var current_thirst = max_thirst
@onready var current_stamina = max_stamina

var is_dead: bool = false
@onready var player = owner

func _process(delta):
	if not is_multiplayer_authority() or is_dead: return
	
	_manejar_metabolismo(delta)
	_manejar_estamina(delta)
		
	# Emitir señales
	salud_cambiada.emit(current_health, max_health)
	oxigeno_cambiada.emit(current_oxygen, max_oxygen)
	hambre_cambiada.emit(current_hunger, max_hunger)
	sed_cambiada.emit(current_thirst, max_thirst)
	estamina_cambiada.emit(current_stamina, max_stamina)

func _manejar_metabolismo(delta):
	# 1. Oxígeno (0.5 por seg)
	if current_oxygen > 0: current_oxygen -= 0.5 * delta
	else: recibir_daño(5.0 * delta)
	
	# 2. Hambre (0.1 por seg -> ~16 min totales)
	current_hunger = clamp(current_hunger - 0.1 * delta, 0, max_hunger)
	
	# 3. Sed (0.15 por seg -> ~11 min totales)
	current_thirst = clamp(current_thirst - 0.15 * delta, 0, max_thirst)
	
	# Daño por falta de comida o agua
	if current_hunger <= 0 or current_thirst <= 0:
		recibir_daño(2.0 * delta)

func _manejar_estamina(delta):
	if player.is_on_floor() and player.velocity.length() > 0.1 and player.is_sprinting:
		_modificar_estamina(-20.0 * delta)
	else:
		# Penalización: Si tienes mucha sed, recuperas estamina más lento
		var factor_sed = 0.5 if current_thirst < 20.0 else 1.0
		_modificar_estamina(10.0 * delta * factor_sed)

func _modificar_estamina(cantidad: float):
	current_stamina = clamp(current_stamina + cantidad, 0, max_stamina)
	if current_stamina <= 0: agotado.emit(true)
	elif current_stamina > 20.0: agotado.emit(false)

func recibir_daño(cantidad: float):
	current_health = clamp(current_health - cantidad, 0, max_health)
	if current_health <= 0 and not is_dead:
		is_dead = true
		ha_muerto.emit()

# Receptor de recursos actualizado para ser dinámico
func _on_recurso_recibido(tipo: String, cantidad: float):
	match tipo:
		"oxigeno": current_oxygen = clamp(current_oxygen + cantidad, 0, max_oxygen)
		"salud": current_health = clamp(current_health + cantidad, 0, max_health)
		"hambre": current_hunger = clamp(current_hunger + cantidad, 0, max_hunger)
		"sed": current_thirst = clamp(current_thirst + cantidad, 0, max_thirst)
