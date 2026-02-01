extends Control

const START_BUTTON = 0

@onready var fade_rect = $FadeLayer/FadeRect
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	fade_rect.fade_in()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.button_index == START_BUTTON and event.pressed:
		_on_empezar_pressed()

func _on_empezar_pressed() -> void:
	get_tree().root.set_process_input(false)
	fade_rect.fade_out()
	fade_rect.fade_finished.connect(_on_fade_out_finished)
	get_tree().change_scene_to_file(
		"res://scenes/JoinMenu/JoinMenu.tscn"
	)
	
func _on_fade_out_finished():
	get_tree().change_scene_to_file(
		"res://scenes/JoinMenu/JoinMenu.tscn"
	)
	get_tree().root.set_process_input(true)

func _on_salir_pressed() -> void:
	get_tree().quit()
