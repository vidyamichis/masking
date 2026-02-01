extends "res://scenes/powers/power_hitbox.gd"

const WIND_FRAMES = [
	preload("res://resources/powers/wind/1.png"),
	preload("res://resources/powers/wind/2.png"),
	preload("res://resources/powers/wind/3.png"),
	preload("res://resources/powers/wind/4.png"),
	preload("res://resources/powers/wind/5.png"),
]

@export var frame_rate = 10.0
@export var form_frame_repeats = 2

@export var speed_start = 4.0
@export var speed_peak = 10.0
@export var speed_end = 2.0
@export var accelerate_duration = 0.6
@export var cruise_duration = 1.0
@export var decelerate_duration = 0.6
@export var fade_duration = 0.6

@export var pull_radius = 4.0
@export var pull_strength = 4.0

@export var wind_collision_layer = 4

@onready var wind_sprite = $WindSprite as Sprite3D
@onready var cast_audio_player = $CastSound as AudioStreamPlayer3D

var frame_elapsed := 0.0
var flip_state := false
var form_index := 0
var form_repeat := 0
var launched := false
var move_direction := Vector3.ZERO
var velocity := Vector3.ZERO
var life_left := 0.0
var total_lifetime := 0.0
var base_modulate := Color.WHITE

func _ready() -> void:
	super._ready()
	add_to_group("wind_projectile")
	if wind_sprite != null:
		wind_sprite.texture = WIND_FRAMES[0]
		wind_sprite.flip_h = false
		base_modulate = wind_sprite.modulate
	if cast_audio_player != null:
		cast_audio_player.stop()
	monitoring = false
	_update_debug()

func activate(spawn_basis: Basis, spawn_position: Vector3, target_mask: int, source: Node3D = null) -> void:
	global_basis = spawn_basis
	global_position = spawn_position
	collision_layer = wind_collision_layer
	collision_mask = target_mask
	source_player = source
	monitoring = false
	form_index = 0
	form_repeat = 0
	frame_elapsed = 0.0
	flip_state = false
	launched = false
	move_direction = -spawn_basis.z.normalized()
	velocity = move_direction * speed_start
	total_lifetime = _get_total_lifetime()
	life_left = total_lifetime
	_set_frame(0)
	_set_alpha(1.0)
	if cast_audio_player != null:
		cast_audio_player.global_position = global_position
		cast_audio_player.play()
	_update_debug()

func _process(delta: float) -> void:
	if wind_sprite == null:
		return
	var frame_time = 1.0 / max(frame_rate, 0.01)
	frame_elapsed += delta
	if not launched:
		_process_forming(frame_time)
		_update_billboard_orientation()
		return
	_process_active(frame_time, delta)

func _physics_process(delta: float) -> void:
	if not launched:
		return
	_apply_pull(delta)

func _process_forming(frame_time: float) -> void:
	if form_index >= 5:
		return
	while frame_elapsed >= frame_time and not launched:
		frame_elapsed -= frame_time
		flip_state = not flip_state
		wind_sprite.flip_h = flip_state
		form_repeat += 1
		if form_repeat >= max(1, form_frame_repeats):
			form_repeat = 0
			form_index += 1
			if form_index >= 5:
				_launch_tornado()
				break
			_set_frame(form_index)

func _process_active(frame_time: float, delta: float) -> void:
	while frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		flip_state = not flip_state
		wind_sprite.flip_h = flip_state
	life_left = max(0.0, life_left - delta)
	if life_left <= 0.0:
		queue_free()
		return
	_update_speed(delta)
	_update_fade()

func _launch_tornado() -> void:
	launched = true
	monitoring = true
	_set_frame(4)
	_update_debug()


func _update_speed(delta: float) -> void:
	var elapsed = total_lifetime - life_left
	var speed = _get_speed_for_elapsed(elapsed)
	velocity = move_direction * speed
	global_position += velocity * delta
	_update_billboard_orientation()

func _get_speed_for_elapsed(elapsed: float) -> float:
	if accelerate_duration > 0.0 and elapsed < accelerate_duration:
		return lerp(speed_start, speed_peak, elapsed / accelerate_duration)
	var cruise_end = accelerate_duration + cruise_duration
	if elapsed < cruise_end:
		return speed_peak
	var decel_end = cruise_end + decelerate_duration
	if decelerate_duration > 0.0 and elapsed < decel_end:
		return lerp(speed_peak, speed_end, (elapsed - cruise_end) / decelerate_duration)
	return speed_end

func _update_fade() -> void:
	var fade_start = accelerate_duration + cruise_duration + decelerate_duration
	if fade_duration <= 0.0:
		_set_alpha(1.0)
		return
	var elapsed = total_lifetime - life_left
	if elapsed <= fade_start:
		_set_alpha(1.0)
		return
	var fade_t = clamp((elapsed - fade_start) / fade_duration, 0.0, 1.0)
	_set_alpha(lerp(1.0, 0.0, fade_t))

func _apply_pull(delta: float) -> void:
	if pull_radius <= 0.0 or pull_strength <= 0.0:
		return
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return
	for player in players:
		if player == null:
			continue
		var player_node = player as Node3D
		if player_node == null:
			continue
		var offset = global_position - player_node.global_position
		offset.y = 0.0
		var distance = offset.length()
		if distance <= 0.001 or distance > pull_radius:
			continue
		if not player_node.has_method("apply_wind_pull"):
			continue
		var pull_velocity = offset.normalized() * pull_strength
		player_node.apply_wind_pull(pull_velocity)

func _update_billboard_orientation() -> void:
	if wind_sprite == null:
		return
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var look_position = camera.global_position
	look_at(look_position, camera.global_basis.y)

func _set_frame(frame_index: int) -> void:
	if wind_sprite == null:
		return
	wind_sprite.texture = WIND_FRAMES[frame_index]

func _set_alpha(alpha: float) -> void:
	if wind_sprite == null:
		return
	var color = base_modulate
	color.a = alpha
	wind_sprite.modulate = color

func _get_total_lifetime() -> float:
	return max(0.01, accelerate_duration + cruise_duration + decelerate_duration + fade_duration)

func _on_body_entered(body: Node3D) -> void:
	if not launched:
		return
	super._on_body_entered(body)
