extends Control

# Referencias exactas según tu imagen
@onready var view_vacio = $JugadorAusente
@onready var view_ocupado = $JugadorSeleccionado

func _ready():
	# IMPORTANTE: Esto es lo que evita que se vean encimados al inicio.
	# Forzamos a que empiece en estado "vacío".
	set_empty()

# Función: Muestra "UNITE" y oculta "SALIR"
func set_empty():
	view_vacio.visible = true
	view_ocupado.visible = false
	
	# Opcional: bajarle la opacidad para que se vea que "falta gente"
	modulate.a = 0.6 

# Función: Muestra "SALIR" y el control, oculta "UNITE"
func set_joined(device_id: int):
	view_vacio.visible = false
	view_ocupado.visible = true
	
	# Restauramos la opacidad al 100%
	modulate.a = 1.0
