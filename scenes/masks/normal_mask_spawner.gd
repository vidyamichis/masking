extends "res://scenes/masks/mask_spawner.gd"

func _ready() -> void:
	super._ready()
	desired_spawn_count = spawn_points.size()
	_apply_spawn_count()

func set_desired_spawn_count(_count: int) -> void:
	return
