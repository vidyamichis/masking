extends ColorRect

signal fade_finished

@export var fade_duration := 0.5

func fade_in():
	# Negro → transparente
	visible = true
	modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_duration)
	tween.finished.connect(_on_fade_finished)

func fade_out():
	# Transparente → negro
	visible = true
	modulate.a = 0.0

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_duration)
	tween.finished.connect(_on_fade_finished)

func _on_fade_finished():
	emit_signal("fade_finished")
