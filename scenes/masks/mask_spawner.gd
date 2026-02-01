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
@export var respawn_gauge_radius = 0.45
@export var respawn_gauge_height = 0.05
@export var respawn_gauge_offset = 0.02
@export var respawn_gauge_color = Color(0.3, 0.8, 1.0, 0.8)

var spawn_points: Array[Node3D] = []
var active_masks: Dictionary = {}
var respawn_pending: Dictionary = {}
var respawn_end_times: Dictionary = {}
var respawn_durations: Dictionary = {}
var respawn_gauges: Dictionary = {}
var desired_spawn_count := 1

func _ready() -> void:
	spawn_points = _get_spawn_points()
	for point in spawn_points:
		respawn_gauges[point] = _create_respawn_gauge(point)
	desired_spawn_count = _get_player_count()
	_apply_spawn_count()

func set_desired_spawn_count(count: int) -> void:
	desired_spawn_count = max(count, 1)
	_apply_spawn_count()

func _spawn_mask(point: Node3D) -> void:
	if mask_scenes.is_empty():
		return
	if not _is_spawn_enabled(point):
		return
	if active_masks.has(point):
		return
	if respawn_pending.has(point):
		return
	respawn_pending.erase(point)
	var scene = _pick_mask_scene()
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
	if respawn_pending.has(point):
		return
	active_masks.erase(point)
	respawn_pending[point] = true
	var tree = get_tree()
	if tree == null:
		return
	var delay = randf_range(respawn_min, respawn_max)
	var timer = tree.create_timer(delay)
	respawn_end_times[point] = Time.get_ticks_msec() / 1000.0 + delay
	respawn_durations[point] = delay
	_set_gauge_visible(point, true)
	await timer.timeout
	respawn_pending.erase(point)
	respawn_end_times.erase(point)
	respawn_durations.erase(point)
	_set_gauge_visible(point, false)
	if active_masks.has(point):
		return
	_spawn_mask(point)

func _on_mask_tree_exited(point: Node3D) -> void:
	if active_masks.get(point, null) == null:
		return
	active_masks.erase(point)
	if not respawn_pending.has(point):
		respawn_pending[point] = true
		var tree = get_tree();
		if tree == null:
			return
		var delay = randf_range(respawn_min, respawn_max)
		var timer = tree.create_timer(delay)
		respawn_end_times[point] = Time.get_ticks_msec() / 1000.0 + delay
		respawn_durations[point] = delay
		_set_gauge_visible(point, true)
		await timer.timeout
		respawn_pending.erase(point)
		respawn_end_times.erase(point)
		respawn_durations.erase(point)
		_set_gauge_visible(point, false)
		if active_masks.has(point):
			return
		_spawn_mask(point)


func _pick_mask_scene() -> PackedScene:
	var eligible_scenes: Array[PackedScene] = []
	for scene in mask_scenes:
		if scene == null:
			continue
		if Match.enabled_mask_ids.is_empty():
			eligible_scenes.append(scene)
			continue
		if _mask_scene_is_enabled(scene):
			eligible_scenes.append(scene)
	if eligible_scenes.is_empty():
		eligible_scenes = mask_scenes
	return eligible_scenes[randi() % eligible_scenes.size()]

func _mask_scene_is_enabled(scene: PackedScene) -> bool:
	if scene == null:
		return false
	var instance = scene.instantiate() as Node
	if instance == null:
		return false
	var mask_id = instance.get("mask_id") if instance.has_method("get") else 0
	instance.queue_free()
	return Match.enabled_mask_ids.has(mask_id)

func _get_spawn_points() -> Array[Node3D]:
	var found: Array[Node3D] = []
	var container = get_node_or_null("MaskSpawns")
	if container == null:
		return found
	var indexed: Dictionary = {}
	var extras: Array[Node3D] = []
	for child in container.get_children():
		if child is Node3D:
			var index = _extract_trailing_index(child.name)
			if index > 0:
				indexed[index] = child
			else:
				extras.append(child)
	var max_index = 0
	for index in indexed.keys():
		max_index = max(max_index, int(index))
	for index in range(1, max_index + 1):
		if indexed.has(index):
			found.append(indexed[index])
	found.append_array(extras)
	return found

func _extract_trailing_index(name: String) -> int:
	var digits := ""
	for index in range(name.length() - 1, -1, -1):
		var character = name[index]
		if character >= "0" and character <= "9":
			digits = character + digits
			continue
		break
	if digits.is_empty():
		return -1
	return int(digits)

func _is_spawn_enabled(point: Node3D) -> bool:
	var index = spawn_points.find(point)
	if index < 0:
		return false
	return index < desired_spawn_count

func _get_player_count() -> int:
	var player_count = get_tree().get_nodes_in_group("players").size()
	return max(player_count, 1)

func _apply_spawn_count() -> void:
	for point in spawn_points:
		if _is_spawn_enabled(point) and not active_masks.has(point):
			_spawn_mask(point)

func _process(_delta: float) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	for point in respawn_end_times.keys():
		_update_gauge(point, now)

func _create_respawn_gauge(point: Node3D) -> MeshInstance3D:
	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = respawn_gauge_radius
	mesh.bottom_radius = respawn_gauge_radius
	mesh.height = respawn_gauge_height
	mesh.radial_segments = 32
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = respawn_gauge_color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	mesh_instance.visible = false
	add_child(mesh_instance)
	var basis = point.global_basis
	var offset = basis * Vector3(0.0, respawn_gauge_offset, 0.0)
	mesh_instance.global_position = point.global_position + offset
	mesh_instance.global_basis = basis
	return mesh_instance

func _set_gauge_visible(point: Node3D, is_visible: bool) -> void:
	var gauge = respawn_gauges.get(point, null) as MeshInstance3D
	if gauge == null:
		return
	gauge.visible = is_visible

func _update_gauge(point: Node3D, now: float) -> void:
	var gauge = respawn_gauges.get(point, null) as MeshInstance3D
	if gauge == null:
		return
	var end_time = respawn_end_times.get(point, null)
	var duration = respawn_durations.get(point, null)
	if end_time == null or duration == null:
		return
	var remaining = max(0.0, float(end_time) - now)
	var progress = 1.0 - (remaining / max(float(duration), 0.01))
	var scale_value = max(0.0, 1.0 - progress)
	gauge.scale = Vector3(scale_value, 1.0, scale_value)
