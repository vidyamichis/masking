extends Marker3D

@export var min_distance = 10.0
@export var max_distance = 30.0
@export var padding = 1.5
@export var pan_smooth = 5.0
@export var zoom_smooth = 5.0

@onready var camera = $Camera3D

func _process(delta: float) -> void:
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return

	var center = Vector3.ZERO
	var min_pos = Vector3(INF, INF, INF)
	var max_pos = Vector3(-INF, -INF, -INF)
	var count = 0
	for node in players:
		if node is Node3D:
			var position = node.global_position
			center += position
			min_pos = min_pos.min(position)
			max_pos = max_pos.max(position)
			count += 1
	if count == 0:
		return
	center /= float(count)

	var span = max_pos - min_pos
	var radius = max(span.x, span.z) * 0.5 + padding
	var desired_distance = _distance_for_radius(radius)
	desired_distance = clamp(desired_distance, min_distance, max_distance)

	var pan_factor = _smooth_factor(pan_smooth, delta)
	global_position = global_position.lerp(center, pan_factor)

	var zoom_factor = _smooth_factor(zoom_smooth, delta)
	camera.position = camera.position.lerp(Vector3(0.0, 0.0, desired_distance), zoom_factor)

func _distance_for_radius(radius: float) -> float:
	var fov = deg_to_rad(camera.fov)
	var viewport = camera.get_viewport()
	if viewport == null:
		return radius / tan(fov * 0.5)
	var size = viewport.get_visible_rect().size
	if size.y == 0.0:
		return radius / tan(fov * 0.5)
	var aspect = size.x / size.y
	var horizontal_fov = 2.0 * atan(tan(fov * 0.5) * aspect)
	var distance_v = radius / tan(fov * 0.5)
	var distance_h = radius / tan(horizontal_fov * 0.5)
	return max(distance_v, distance_h)

func _smooth_factor(speed: float, delta: float) -> float:
	return 1.0 - pow(2.0, -speed * delta)
