extends Control

func _ready() -> void:
	# 1. Rompemos las cadenas: le decimos que NO se ancle a su padre CanvasGroup
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	
	_resync_size()
	get_tree().get_root().size_changed.connect(_resync_size)

func _resync_size() -> void:
	var viewport_size = get_viewport_rect().size
	
	# 2. Forzamos el tamaño a mano, ignorando al padre
	custom_minimum_size = viewport_size
	size = viewport_size
	
	# 3. Lo clavamos en la esquina superior izquierda
	position = Vector2.ZERO
