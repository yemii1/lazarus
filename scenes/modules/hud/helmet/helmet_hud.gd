extends CanvasLayer

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

@onready var degree_label = $%DegreeLabel
@onready var cardinal_label = $%CardinalLabel

# --- [NUEVO] VARIABLES PARA LA ANIMACIÓN ---
var animacion_en_curso: bool = false
var animacion_tween: Tween
# -------------------------------------------

# ==========================================
# CONFIGURACIÓN DE INERCIA (SWAY)
# ==========================================
@export var sway_amount: float = 0.05
@export var max_sway: float = 30.0
@export var sway_speed: float = 8.0

var base_position: Vector2
var target_offset: Vector2 = Vector2.ZERO

# ==========================================
# VARIABLES DE ESTADO LOCALES 
# ==========================================
var status_manager: Node = null
var player: CharacterBody3D = null
var player_camera: Camera3D = null
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
func setup(player_node: CharacterBody3D, camera_node: Camera3D):
	player = player_node
	status_manager = player.status
	player_camera = camera_node
	
	# Conectamos las señales a nuestras funciones receptoras
	if not status_manager.salud_cambiada.is_connected(_update_health):
		status_manager.salud_cambiada.connect(_update_health)
		status_manager.oxigeno_cambiada.connect(_update_oxygen)
		status_manager.hambre_cambiada.connect(_update_hunger)
		status_manager.sed_cambiada.connect(_update_thirst)
		status_manager.estamina_cambiada.connect(_update_stamina)

# --- SISTEMA DE ENCENDIDO/APAGADO ---
func reproducir_animacion_casco(esta_puesto: bool, instantaneo: bool = false): # <-- Añadimos el parámetro
	if animacion_tween and animacion_tween.is_running():
		animacion_tween.kill()
		
	# Si instantáneo (al cargar la partida)
	if instantaneo:
		visible = esta_puesto
		set_process(esta_puesto)
		set_process_input(esta_puesto)
		animacion_en_curso = false
		
		if not esta_puesto:
			# Lo dejamos todo apagado visualmente de golpe
			health_bar.value = 0.0
			stamina_bar.value = 0.0
			oxygen_bar.value = 0.0
			hunger_label.text = "-%"
			thirst_label.text = "-%"
			degree_label.modulate.a = 0.0
			cardinal_label.modulate.a = 0.0
		return # para no crear la animación

	# --- NO INSTANTÁNEO, (ANIMACIÓN NORMAL) ---
	animacion_tween = create_tween()
	animacion_en_curso = true
	
	if esta_puesto:
		# 1. Todo se enciende y empieza a calcular
		visible = true
		set_process(true)
		set_process_input(true)
		
		# 2. Reseteamos los elementos a 0 o invisibles
		health_bar.value = 0.0
		stamina_bar.value = 0.0
		oxygen_bar.value = 0.0
		hunger_label.text = "-%"
		thirst_label.text = "-%"
		degree_label.modulate.a = 0.0
		cardinal_label.modulate.a = 0.0
		
		# 3. Llenamos todas las barras a la vez (.set_parallel)
		animacion_tween.set_parallel(true)
		animacion_tween.tween_property(health_bar, "value", pct_salud, 0.8).set_trans(Tween.TRANS_SINE)
		animacion_tween.tween_property(stamina_bar, "value", pct_estamina, 0.8).set_trans(Tween.TRANS_SINE)
		animacion_tween.tween_property(oxygen_bar, "value", pct_oxigeno, 0.8).set_trans(Tween.TRANS_SINE)
		
		# 4. Al terminar de llenarse, ejecutamos la función de éxito y hacemos aparecer la brújula
		animacion_tween.chain().tween_callback(_on_encendido_completado)
		animacion_tween.tween_property(degree_label, "modulate:a", 1.0, 0.3)
		animacion_tween.tween_property(cardinal_label, "modulate:a", 1.0, 0.3)
		
	else:
		# 1. Quitamos los números al instante
		hunger_label.text = "-%"
		thirst_label.text = "-%"
		
		# 2. Desvanecemos la brújula rápido
		animacion_tween.set_parallel(true)
		animacion_tween.tween_property(degree_label, "modulate:a", 0.0, 0.2)
		animacion_tween.tween_property(cardinal_label, "modulate:a", 0.0, 0.2)
		
		# 3. Vaciamos las barras de golpe
		animacion_tween.chain().tween_property(health_bar, "value", 0.0, 0.4).set_trans(Tween.TRANS_EXPO)
		animacion_tween.tween_property(stamina_bar, "value", 0.0, 0.4).set_trans(Tween.TRANS_EXPO)
		animacion_tween.tween_property(oxygen_bar, "value", 0.0, 0.4).set_trans(Tween.TRANS_EXPO)
		
		# 4. Apagamos todo el HUD de verdad
		animacion_tween.chain().tween_callback(_on_apagado_completado)

func _on_encendido_completado():
	animacion_en_curso = false
	# Restauramos los textos de los porcentajes
	hunger_label.text = str(int(pct_hambre)) + "%"
	thirst_label.text = str(int(pct_sed)) + "%"

func _on_apagado_completado():
	animacion_en_curso = false
	visible = false
	set_process(false)
	set_process_input(false)
# ----------------------------------------------------

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
	# ¡Esto sigue funcionando aunque se esté animando! Da un efecto genial de encendido en movimiento.
	sway_container.position = sway_container.position.lerp(base_position + target_offset, delta * sway_speed)
	target_offset = target_offset.lerp(Vector2.ZERO, delta * (sway_speed * 0.5))
	
	# --- [NUEVO] BLOQUEO DE ANIMACIÓN ---
	# Si estamos animando el arranque/apagado, cortamos aquí para no pisar el Tween
	if animacion_en_curso: return
	# ------------------------------------
	
	# 2. FLUIDEZ AAA: Deslizamos visualmente las barras hacia su objetivo
	if is_instance_valid(health_bar):
		health_bar.value = lerpf(health_bar.value, pct_salud, 10.0 * delta)
		stamina_bar.value = lerpf(stamina_bar.value, pct_estamina, 10.0 * delta)
		oxygen_bar.value = lerpf(oxygen_bar.value, pct_oxigeno, 10.0 * delta)
	
	# 3. Revisamos constantemente el estado de las alarmas
	if is_instance_valid(status_manager):
		_revisar_alertas()
	
	if is_instance_valid(player_camera):
		_update_compass(player_camera)

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
	if not animacion_en_curso:
		hunger_label.text = str(int(pct_hambre)) + "%"

func _update_thirst(actual: float, max_v: float):
	pct_sed = (actual / max_v) * 100.0
	if not animacion_en_curso:
		thirst_label.text = str(int(pct_sed)) + "%"
	
func _update_compass(camera: Camera3D):
	# 1. Obtener la rotación real en grados (0 a 360)
	var rot_y = camera.global_transform.basis.get_euler().y
	var heading = wrapf(rad_to_deg(-rot_y), 0.0, 360.0)
	
	# 2. Formatear a 3 dígitos (ej. "005°", "045°", "350°")
	degree_label.text = "%03d°" % int(heading)
	
	# 3. Calcular la letra (Matemática de Sectores)
	var directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW", "N"]
	
	# Calculamos en qué "porción" de la tarta estamos (0 a 8)
	var sector = int(round(fmod(heading + 22.5, 360.0) / 45.0))
	
	# 4. Asignamos la letra
	cardinal_label.text = directions[sector]
	

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
