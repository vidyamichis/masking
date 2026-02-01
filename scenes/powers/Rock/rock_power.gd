extends "res://scenes/powers/power_hitbox.gd"

const ROCK_FRAMES = [
	preload("res://resources/powers/earth/1.png"),
	preload("res://resources/powers/earth/2.png"),
	preload("res://resources/powers/earth/3.png"),
	preload("res://resources/powers/earth/4.png"),
	preload("res://resources/powers/earth/5.png"),
]

@export var frame_rate = 10.0
@export var form_frame_repeats = 2
@export var travel_speed = 10.0
@export var travel_distance = 8.0
@export var arc_height = 0.6
@export var rock_collision_layer = 4
@export var impact_spawn_count = 3
@export var impact_spread = 0.6
@export var impact_fall_speed = 1.8
@export var impact_fade_duration = 0.2
@export var impact_lifetime = 0.4
@export var impact_gravity = 8.0
@export var impact_launch_speed_min = 1.4
@export var impact_launch_speed_max = 2.6
@export var impact_launch_up_min = 2.0
@export var impact_launch_up_max = 3.4
@export var impact_launch_angle = 25.0
@export var rotation_speed_min = 4.0
@export var rotation_speed_max = 10.0
@export var rotation_jitter = 0.6
@export var rock_scale = Vector3(1.3, 1.3, 1.3)
@export var forward_spawn_offset = 0.6

@onready var rock_sprite = $RockSprite as Sprite3D
@onready var cast_audio_player = $CastSound as AudioStreamPlayer3D
@onready var impact_audio_player = $ImpactSound as AudioStreamPlayer3D

const ROCK_SHARD_SCRIPT = preload("res://scenes/powers/Rock/rock_shard.gd")

var frame_elapsed := 0.0
var flip_state := false
var form_index := 0
var form_repeat := 0
var launched := false
var move_direction := Vector3.ZERO
var velocity := Vector3.ZERO
var start_position := Vector3.ZERO
var distance_traveled := 0.0
var arc_phase := 0.0
var base_modulate := Color.WHITE
var rotation_speed := 0.0
var rng := RandomNumberGenerator.new()
var impacted := false

func _ready() -> void:
	super._ready()
	rng.randomize()
	add_to_group("rock_projectile")
	if rock_sprite != null:
		rock_sprite.texture = ROCK_FRAMES[0]
		rock_sprite.flip_h = false
		rock_sprite.scale = rock_scale
		base_modulate = rock_sprite.modulate
	if cast_audio_player != null:
		cast_audio_player.stop()
	if impact_audio_player != null:
		impact_audio_player.stop()
	monitoring = false
	_update_debug()

func activate(spawn_basis: Basis, spawn_position: Vector3, target_mask: int) -> void:
	global_basis = spawn_basis
	global_position = spawn_position + (-spawn_basis.z.normalized() * forward_spawn_offset)
	collision_layer = rock_collision_layer
	collision_mask = target_mask
	monitoring = false
	form_index = 0
	form_repeat = 0
	frame_elapsed = 0.0
	flip_state = false
	launched = false
	impacted = false
	distance_traveled = 0.0
	arc_phase = 0.0
	move_direction = -spawn_basis.z.normalized()
	velocity = move_direction * travel_speed
	start_position = global_position
	rotation_speed = rng.randf_range(rotation_speed_min, rotation_speed_max)
	if rock_sprite != null:
		rock_sprite.rotation.z = rng.randf_range(0.0, TAU)
	_set_frame(0)
	_set_alpha(1.0)
	if rock_sprite != null:
		rock_sprite.scale = rock_scale
	if cast_audio_player != null:
		cast_audio_player.global_position = global_position
		cast_audio_player.play()
	_update_debug()

func _process(delta: float) -> void:
	if rock_sprite == null:
		return
	if impacted:
		return
	var frame_time = 1.0 / max(frame_rate, 0.01)
	frame_elapsed += delta
	if not launched:
		_process_forming(frame_time)
		_update_billboard_orientation()
		return
	_process_active(frame_time, delta)

func _process_forming(frame_time: float) -> void:
	if form_index >= 4:
		return
	while frame_elapsed >= frame_time and not launched:
		frame_elapsed -= frame_time
		flip_state = not flip_state
		rock_sprite.flip_h = flip_state
		form_repeat += 1
		if form_repeat >= max(1, form_frame_repeats):
			form_repeat = 0
			form_index += 1
			if form_index >= 4:
				_launch_rock()
				break
			_set_frame(form_index)

func _process_active(frame_time: float, delta: float) -> void:
	while frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		flip_state = not flip_state
		rock_sprite.flip_h = flip_state
		var spin_speed = rotation_speed + rng.randf_range(-rotation_jitter, rotation_jitter)
		rock_sprite.rotation.z += spin_speed * frame_time
	_apply_motion(delta)
	_update_billboard_orientation()

func _apply_motion(delta: float) -> void:
	var displacement = velocity * delta
	if displacement.length() <= 0.0:
		return
	var target_position = global_position + displacement
	var next_distance = distance_traveled + displacement.length()
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, target_position)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = collision_mask
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		global_position = result.position
		_handle_impact()
		return
	global_position = target_position
	distance_traveled = next_distance
	arc_phase = clamp(distance_traveled / max(travel_distance, 0.01), 0.0, 1.0)
	_apply_arc_offset()
	if distance_traveled >= travel_distance:
		_handle_impact()

func _apply_arc_offset() -> void:
	var arc = sin(arc_phase * PI) * arc_height
	global_position.y = start_position.y + arc

func _launch_rock() -> void:
	launched = true
	monitoring = true
	_set_frame(4)
	_update_debug()

func _handle_impact() -> void:
	if impacted:
		return
	impacted = true
	monitoring = false
	_update_debug()
	if rock_sprite != null:
		rock_sprite.visible = false
	if impact_audio_player != null:
		impact_audio_player.global_position = global_position
		impact_audio_player.play()
	_spawn_impact_shards()
	if impact_audio_player != null and impact_audio_player.playing:
		impact_audio_player.finished.connect(queue_free, CONNECT_ONE_SHOT)
		return
	queue_free()

func _spawn_impact_shards() -> void:
	if rock_sprite == null:
		return
	var parent = get_parent()
	if parent == null:
		return
	for index in range(impact_spawn_count):
		var shard = Sprite3D.new()
		shard.texture = ROCK_FRAMES[2]
		shard.pixel_size = rock_sprite.pixel_size
		shard.billboard = rock_sprite.billboard
		shard.modulate = base_modulate
		shard.flip_h = rng.randi_range(0, 1) == 1
		shard.rotation.z = rng.randf_range(0.0, TAU)
		shard.set_script(ROCK_SHARD_SCRIPT)
		parent.add_child(shard)
		shard.global_position = global_position + Vector3(
			rng.randf_range(-impact_spread, impact_spread),
			rng.randf_range(0.0, impact_spread * 0.5),
			rng.randf_range(-impact_spread, impact_spread)
		)
		var launch_speed = rng.randf_range(impact_launch_speed_min, impact_launch_speed_max)
		var launch_up = rng.randf_range(impact_launch_up_min, impact_launch_up_max)
		var angle_offset = rng.randf_range(-impact_launch_angle, impact_launch_angle)
		var direction = Vector3(
			cos(deg_to_rad(angle_offset)),
			0.0,
			sin(deg_to_rad(angle_offset))
		)
		var launch_velocity = direction * launch_speed
		launch_velocity.y = launch_up
		var shard_fall_speed = rng.randf_range(impact_fall_speed * 0.7, impact_fall_speed * 1.3)
		var shard_gravity = impact_gravity * shard_fall_speed
		if shard.has_method("configure"):
			shard.configure(impact_lifetime, launch_velocity, shard_gravity, impact_fade_duration, base_modulate)

func _set_frame(frame_index: int) -> void:
	if rock_sprite == null:
		return
	rock_sprite.texture = ROCK_FRAMES[frame_index]

func _set_alpha(alpha: float) -> void:
	if rock_sprite == null:
		return
	var color = base_modulate
	color.a = alpha
	rock_sprite.modulate = color

func _update_billboard_orientation() -> void:
	if rock_sprite == null:
		return
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var look_position = camera.global_position
	look_at(look_position, camera.global_basis.y)

func _on_body_entered(body: Node3D) -> void:
	if not launched:
		return
	super._on_body_entered(body)
	_handle_impact()
