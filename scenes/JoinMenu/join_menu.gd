extends Control

# Referencias a los slots (asegúrate de que las rutas coincidan con tu árbol de nodos)
@onready var slots = [
	$Slot1,
	$Slot2,
	$Slot3,
	$Slot4,
]

@onready var status_label = $StatusLabel      # Texto "FALTAN JUGADORES"
@onready var start_button = $StartButton      # Botón Start
@onready var fade_rect = $FadeLayer/FadeRect

# Constantes de botones (Mapeo estándar de Xbox/Generic)
const INPUT_JOIN = JOY_BUTTON_A      # Botón A (0)
const INPUT_BACK = JOY_BUTTON_B      # Botón B (1)
const INPUT_START = JOY_BUTTON_START # Botón Start (6)

func _ready() -> void:
	_update_ui()
	if fade_rect:
		fade_rect.fade_in()

func _unhandled_input(event: InputEvent) -> void:
	# --- CONTROL (GAMEPAD) ---
	if event is InputEventJoypadButton and event.pressed:
		var device = event.device
		
		# 1. UNIRSE (Botón A)
		if event.button_index == INPUT_JOIN:
			if not Lobby.is_device_joined(device):
				Lobby.join_device(device)
				_update_ui()
				get_viewport().set_input_as_handled()
		
		# 2. SALIR DEL SLOT o VOLVER ATRÁS (Botón B)
		elif event.button_index == INPUT_BACK:
			if Lobby.is_device_joined(device):
				# Si ya estaba unido, lo sacamos (vuelve a "Unite")
				Lobby.leave_device(device)
				_update_ui()
				get_viewport().set_input_as_handled()
			else:
				# Si NO estaba unido, volvemos al menú anterior
				_on_atras_pressed()

		# 3. INICIAR PARTIDA (Botón Start)
		elif event.button_index == INPUT_START:
			_try_start_match()

	# --- TECLADO (Para pruebas) ---
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: # Espacio para unir teclado
			if not Lobby.is_device_joined(-1):
				Lobby.join_device(-1)
				_update_ui()
		elif event.keycode == KEY_ENTER: # Enter para iniciar
			_try_start_match()
		elif event.keycode == KEY_ESCAPE: # Esc para salir
			_on_atras_pressed()

func _update_ui():
	# Obtenemos la lista de dispositivos conectados [0, 1, -1, etc.]
	var joined_devices = Lobby.get_joined_devices()
	var joined_count = joined_devices.size()

	# 1. Actualizar visualmente cada Slot (Círculos)
	for i in range(slots.size()):
		if i < joined_count:
			# El slot está ocupado: Mostramos icono Joystick y "SALIR"
			slots[i].set_joined(joined_devices[i])
		else:
			# El slot está libre: Mostramos "UNITE"
			slots[i].set_empty()

	# 2. Actualizar Centro (Texto vs Botón Start)
	var can_start = joined_count >= 2 or (Debug.has_method("allow_single_player") and Debug.allow_single_player)
	
	if can_start:
		status_label.visible = false
		start_button.visible = true
		if not start_button.has_focus():
			start_button.grab_focus() # Opcional: enfocar el botón
	else:
		status_label.visible = true
		start_button.visible = false

func _try_start_match() -> void:
	var joined_count = Lobby.get_joined_devices().size()
	
	# Verificamos si hay suficientes jugadores
	if joined_count >= 2 or (Debug.has_method("allow_single_player") and Debug.allow_single_player):
		print("Iniciando juego con ", joined_count, " jugadores.")
		get_tree().change_scene_to_file("res://scenes/Game/Game.tscn")

func _on_atras_pressed() -> void:
	# Animación de salida
	if fade_rect:
		fade_rect.fade_out()
		if not fade_rect.fade_finished.is_connected(_on_fade_out_finished):
			fade_rect.fade_finished.connect(_on_fade_out_finished)
	else:
		_on_fade_out_finished()

func _on_fade_out_finished():
	get_tree().change_scene_to_file("res://scenes/Title Screen/title_screen.tscn")

func _on_start_button_pressed() -> void:
	_try_start_match()
