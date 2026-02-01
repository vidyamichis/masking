extends Control

@onready var slot_labels = [
	$VBoxContainer/Slots/Slot1,
	$VBoxContainer/Slots/Slot2,
	$VBoxContainer/Slots/Slot3,
	$VBoxContainer/Slots/Slot4,
]
## @onready var hint_label = $VBoxContainer/Hint
## @onready var fade_rect = $FadeLayer/FadeRect
@onready var status_label = $StatusLabel
@onready var start_button = $StartButton
@onready var fade_rect = $FadeLayer/FadeRect

const JOIN_BUTTON = 0

func _update_ui():
	var joined_count = Lobby.get_joined_devices().size()

	if joined_count < 2:
		status_label.visible = true
		start_button.visible = false
	else:
		status_label.visible = false
		start_button.visible = true

func _ready() -> void:
	_update_ui()
	fade_rect.fade_in()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.button_index == JOIN_BUTTON and event.pressed:
		Lobby.join_device(event.device)
		_update_ui()
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			Lobby.join_device(-1)
			_update_labels()
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			_try_start_match()
			return

	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_START and event.pressed:
		_try_start_match()

func _try_start_match() -> void:
	var joined = Lobby.get_joined_devices()
	if joined.size() >= 2 or Debug.allow_single_player:
		get_tree().change_scene_to_file("res://scenes/Game/Game.tscn")

func _update_labels() -> void:
	var joined = Lobby.get_joined_devices()
	for index in range(slot_labels.size()):
		if index < joined.size():
			var device = joined[index]
			var label = "Keyboard" if device == -1 else "Gamepad %d" % device
			slot_labels[index].text = "Player %d: %s" % [index + 1, label]
		else:
			slot_labels[index].text = "Player %d: Not joined" % (index + 1)
	var min_text = "Need 2+ players to start"
	if Debug.allow_single_player:
		min_text = "Single-player start enabled"
	


func _on_atras_pressed() -> void:
	fade_rect.fade_out()
	fade_rect.fade_finished.connect(_on_fade_out_finished)
	
func _on_fade_out_finished():
	get_tree().change_scene_to_file(
		"res://scenes/Title Screen/title_screen.tscn"
	)


func _on_start_button_pressed() -> void:
	pass # Replace with function body.
