extends Control

# ==========================================
# REFERENCIAS A LOS NODOS VISUALES
# ==========================================
@onready var sway_container = %SwayContainer
@onready var anim_player = $AnimationPlayer
@onready var alert_label = %AlertLabel

@onready var health_bar = %HealthBar
@onready var stamina_bar = %StaminaBar
@onready var oxygen_bar = %OxygenBar

@onready var hunger_label = %HungerLabel
@onready var thirst_label = %ThirstLabel


# ==========================================
# CONFIGURACIÓN DE INERCIA (SWAY)
# ==========================================
@export var sway_amount: float = 0.05
@export var max_sway: float = 30.0
@export var sway_speed: float = 8.0

var base_position: Vector2
var target_offset: Vector2 = Vector2.ZERO

# ==========================================
# VARIABLES DE ESTADO LOCALES (El "Cerebro" del HUD)
# ==========================================
var status_manager: Node = null
var player: CharacterBody3D = null # Aquí guardaremos al dueño del HUD
var alerta_actual: String = ""

# Guardamos copias locales de los porcentajes. 
# Así el HUD no tiene que "adivinar" los nombres de las variables en el servidor.
var pct_salud: float = 100.0
var pct_estamina: float = 100.0
var pct_oxigeno: float = 100.0
var pct_hambre: float = 100.0
var pct_sed: float = 100.0

func _ready():
	# Guardamos el centro exacto del casco para la inercia
	base_position = sway_container.position
	
	# Aseguramos que la etiqueta de alerta empieza oculta
	alert_label.visible = false

# ==========================================
# CONEXIÓN CON EL JUGADOR
# ==========================================
func setup(player_node: CharacterBody3D):
	player = player_node
	status_manager = player.status
	
	# Conectamos las señales a nuestras funciones receptoras
	if not status_manager.salud_cambiada.is_connected(_update_health):
		status_manager.salud_cambiada.connect(_update_health)
		status_manager.oxigeno_cambiada.connect(_update_oxygen)
		status_manager.hambre_cambiada.connect(_update_hunger)
		status_manager.sed_cambiada.connect(_update_thirst)
		status_manager.estamina_cambiada.connect(_update_stamina)

# ==========================================
# FÍSICA Y MOTOR DE ALERTAS (Bucle Principal)
# ==========================================
func _input(event):
	# Capturamos el ratón para mover el HUD en dirección contraria (Sway)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
		target_offset.x -= event.relative.x * sway_amount
		target_offset.y -= event.relative.y * sway_amount
		
		target_offset.x = clamp(target_offset.x, -max_sway, max_sway)
		target_offset.y = clamp(target_offset.y, -max_sway, max_sway)

func _process(delta):
	# 1. Aplicamos el movimiento elástico del casco (Sway)
	sway_container.position = sway_container.position.lerp(base_position + target_offset, delta * sway_speed)
	target_offset = target_offset.lerp(Vector2.ZERO, delta * (sway_speed * 0.5))
	
	# 2. FLUIDEZ AAA: Deslizamos visualmente las barras hacia su objetivo
	if is_instance_valid(health_bar):
		health_bar.value = lerpf(health_bar.value, pct_salud, 10.0 * delta)
		stamina_bar.value = lerpf(stamina_bar.value, pct_estamina, 10.0 * delta)
		oxygen_bar.value = lerpf(oxygen_bar.value, pct_oxigeno, 10.0 * delta)
	
	# 3. Revisamos constantemente el estado de las alarmas
	if is_instance_valid(status_manager):
		_revisar_alertas()

# ==========================================
# ACTUALIZACIÓN VISUAL (Recepción de Señales)
# ==========================================
func _update_health(actual: float, max_v: float):
	pct_salud = (actual / max_v) * 100.0

func _update_stamina(actual: float, max_v: float):
	pct_estamina = (actual / max_v) * 100.0

func _update_oxygen(actual: float, max_v: float):
	pct_oxigeno = (actual / max_v) * 100.0

func _update_hunger(actual: float, max_v: float):
	pct_hambre = (actual / max_v) * 100.0
	hunger_label.text = str(int(pct_hambre)) + "%"

func _update_thirst(actual: float, max_v: float):
	pct_sed = (actual / max_v) * 100.0
	thirst_label.text = str(int(pct_sed)) + "%"
	

# ==========================================
# SISTEMA DE PRIORIDAD DE ALARMAS
# ==========================================
func _revisar_alertas():
	# Prioridad 1: Asfixia
	if pct_oxigeno < 20.0:
		_disparar_alerta("OXYGEN LOW", "alerta_critica")
		
	# Prioridad 2: Daño severo
	elif pct_salud < 20.0:
		_disparar_alerta("CRITICAL DAMAGE", "alerta_critica")
		
	# Prioridad 3: Fatiga extrema
	elif pct_estamina < 15.0:
		_disparar_alerta("EXHAUSTION", "alerta_suave")
		
	# Todo bien, apagamos las alarmas
	else:
		_detener_alertas()

func _disparar_alerta(texto: String, animacion: String):
	alert_label.text = texto
	alert_label.visible = true
	
	# Solo cambiamos la animación si hay una nueva (evita que se reinicie cada frame)
	if alerta_actual != animacion and anim_player.has_animation(animacion):
		anim_player.play(animacion)
		alerta_actual = animacion

func _detener_alertas():
	if alert_label.visible:
		alert_label.visible = false
		alert_label.text = ""
		anim_player.stop()
		alerta_actual = ""
