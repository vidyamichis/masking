extends Node3D

@export var mask_scenes: Array[PackedScene] = [
	preload("res://scenes/masks/Mask1.tscn"),
	preload("res://scenes/masks/Mask2.tscn"),
	preload("res://scenes/masks/Mask3.tscn"),
	preload("res://scenes/masks/Mask4.tscn"),
	preload("res://scenes/masks/Mask5.tscn"),
	preload("res://scenes/masks/Mask6.tscn"),
	preload("res://scenes/masks/Mask7.tscn"),
	preload("res://scenes/masks/Mask8.tscn"),
]
@export var respawn_min = 10.0
@export var respawn_max = 30.0

var spawn_points: Array[Node3D] = []
var active_masks: Dictionary = {}

func _ready() -> void:
	spawn_points = _get_spawn_points()
	for point in spawn_points:
		_spawn_mask(point)

func _spawn_mask(point: Node3D) -> void:
	if mask_scenes.is_empty():
		return
	var scene = mask_scenes[randi() % mask_scenes.size()]
	var mask = scene.instantiate() as Area3D
	if mask == null:
		return
	add_child(mask)
	mask.global_transform = point.global_transform
	active_masks[point] = mask
	mask.set_meta("spawn_point", point)
	mask.set_meta("spawner", self)
	mask.tree_exited.connect(_on_mask_tree_exited.bind(point))

func on_mask_picked(mask: Node3D) -> void:
	_schedule_respawn(mask)

func on_mask_banished(mask: Node3D) -> void:
	_schedule_respawn(mask)

func _schedule_respawn(mask: Node3D) -> void:
	if mask == null:
		return
	var point = mask.get_meta("spawn_point") as Node3D
	if point == null:
		return
	active_masks.erase(point)
	var delay = randf_range(respawn_min, respawn_max)
	var timer = get_tree().create_timer(delay)
	await timer.timeout
	_spawn_mask(point)

func _on_mask_tree_exited(point: Node3D) -> void:
	if active_masks.get(point, null) == null:
		return
	active_masks.erase(point)

func _get_spawn_points() -> Array[Node3D]:
	var found: Array[Node3D] = []
	var container = get_node_or_null("MaskSpawns")
	if container == null:
		return found
	for child in container.get_children():
		if child is Node3D:
			found.append(child)
	return found
