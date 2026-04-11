extends Node

@onready var player = get_parent()


# Exportamos las variables para poder ajustarlas en el editor
@export_category("Estadísticas Máximas")
@export var max_health: float = 100.0
@export var max_oxygen: float = 100.0
@export var max_stamina: float = 100.0

@export_category("Tasas de Consumo")
@export var oxygen_depletion_rate: float = 5.0 # Cuánto oxígeno pierdes por segundo
@export var stamina_drain_rate: float = 20.0 # Cuánta estamina cuesta esprintar por segundo
@export var stamina_regen_rate: float = 15.0 

# Variables actuales
var current_health: float
var current_oxygen: float
var current_stamina: float

# Banderas de estado (Para que los otros scripts pregunten)
var is_exhausted: bool = false
var is_suffocating: bool = false
var in_vacuum: bool = false # Si es true, estamos en el espacio/agua sin casco

func _ready():
	# Inicializamos al máximo al nacer
	current_health = max_health
	current_oxygen = max_oxygen
	current_stamina = max_stamina

func _process(delta):
	# Solo calculamos esto si somos el jugador local (Autoridad)
	if not player.is_multiplayer_authority(): return
	
	_gestionar_oxigeno(delta)
	_gestionar_salud(delta)

# Las funciones de Estamina las llamará el MovementController cuando decida correr
func drain_stamina(delta):
	current_stamina -= stamina_drain_rate * delta
	if current_stamina <= 0:
		current_stamina = 0
		is_exhausted = true

func regen_stamina(delta):
	current_stamina += stamina_regen_rate * delta
	
	# Te obligamos a recuperar al menos el 30% del aire antes de quitarte el estado exhausto
	if current_stamina > (max_stamina * 0.3): 
		is_exhausted = false
		
	if current_stamina > max_stamina:
		current_stamina = max_stamina

func _gestionar_oxigeno(delta):
	if in_vacuum:
		current_oxygen -= oxygen_depletion_rate * delta
	else:
		current_oxygen += (oxygen_depletion_rate * 2) * delta # Se recupera el doble de rápido

	current_oxygen = clamp(current_oxygen, 0, max_oxygen)
	is_suffocating = (current_oxygen <= 0)

func _gestionar_salud(delta):
	if is_suffocating:
		# Perder 10 de vida por segundo sin aire
		current_health -= 10.0 * delta
		
	current_health = clamp(current_health, 0, max_health)
	
	if current_health <= 0:
		print("💀 HAS MUERTO")
		# Aquí llamaremos a la lógica de reaparición más adelante
