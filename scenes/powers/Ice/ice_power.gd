extends "res://scenes/powers/power_hitbox.gd"

const ICE_FRAMES = [
	preload("res://resources/powers/ice/1.png"),
	preload("res://resources/powers/ice/2.png"),
	preload("res://resources/powers/ice/3.png"),
	preload("res://resources/powers/ice/4.png"),
	preload("res://resources/powers/ice/5.png"),
]

@export var frame_rate = 10.0
@export var form_frame_repeats = 2
@export var speed = 12.0
@export var lifetime = 3.0
@export var max_bounces = 3
@export var wall_collision_mask = 1
@export var icicle_collision_layer = 4
@export var bounce_offset = 0.02

@export var sprite_rotation_offset = 0.0
@export var forward_spawn_offset = 0.6

@onready var icicle_sprite = $IcicleSprite as Sprite3D
@onready var cast_audio_player = $CastSound as AudioStreamPlayer3D
@onready var bounce_audio_player = $BounceSound as AudioStreamPlayer3D

var frame_elapsed := 0.0
var flip_state := false
var form_index := 0
var form_repeat := 0
var launched := false
var velocity := Vector3.ZERO
var life_left := 0.0
var bounces_left := 0

func _ready() -> void:
	super._ready()
	add_to_group("ice_projectile")
	area_entered.connect(_on_area_entered)
	if icicle_sprite != null:
		icicle_sprite.texture = ICE_FRAMES[0]
		icicle_sprite.flip_h = false
		icicle_sprite.rotation.z = 0.0
	if cast_audio_player != null:
		cast_audio_player.stop()
	monitoring = false
	_update_debug()

func activate(spawn_basis: Basis, spawn_position: Vector3, target_mask: int, source: Node3D = null) -> void:
	global_basis = spawn_basis
	global_position = spawn_position + (-spawn_basis.z.normalized() * forward_spawn_offset)
	collision_layer = icicle_collision_layer
	collision_mask = target_mask
	source_player = source
	monitoring = false
	form_index = 0
	form_repeat = 0
	frame_elapsed = 0.0
	flip_state = false
	launched = false
	life_left = lifetime
	bounces_left = max_bounces
	velocity = -spawn_basis.z.normalized() * speed
	_set_frame(0)
	_update_orientation()
	if cast_audio_player != null:
		cast_audio_player.global_position = global_position
		cast_audio_player.play()
	_update_debug()

func _process(delta: float) -> void:
	if icicle_sprite == null:
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
		icicle_sprite.flip_h = flip_state
		form_repeat += 1
		if form_repeat >= max(1, form_frame_repeats):
			form_repeat = 0
			form_index += 1
			if form_index >= 4:
				_launch_icicle()
				break
			_set_frame(form_index)

func _process_active(frame_time: float, delta: float) -> void:
	while frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		flip_state = not flip_state
		icicle_sprite.flip_h = flip_state
	life_left = max(0.0, life_left - delta)
	if life_left <= 0.0:
		queue_free()
		return
	_move_with_bounce(delta)
	_update_billboard_orientation()

func _launch_icicle() -> void:
	launched = true
	monitoring = true
	_set_frame(4)
	_update_orientation()
	_update_billboard_orientation()
	_update_debug()

func _move_with_bounce(delta: float) -> void:
	var displacement = velocity * delta
	if displacement.length() <= 0.0:
		return
	var target_position = global_position + displacement
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, target_position)
	query.exclude = [self]
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.collision_mask = wall_collision_mask
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		global_position = target_position
		return
	if bounces_left <= 0:
		queue_free()
		return
	var normal = result.normal
	global_position = result.position + normal * bounce_offset
	velocity = velocity.bounce(normal)
	bounces_left -= 1
	if bounce_audio_player != null:
		bounce_audio_player.global_position = global_position
		bounce_audio_player.play()
	_update_orientation()
	if bounces_left <= 0:
		queue_free()

func _update_orientation() -> void:
	if velocity.length() <= 0.0:
		return
	global_basis = Basis.looking_at(velocity.normalized(), Vector3.UP)
	if icicle_sprite != null:
		icicle_sprite.rotation.z = _get_sprite_rotation_z(velocity)

func _set_frame(frame_index: int) -> void:
	if icicle_sprite == null:
		return
	icicle_sprite.texture = ICE_FRAMES[frame_index]

func _get_sprite_rotation_z(direction: Vector3) -> float:
	var flat = Vector2(direction.x, direction.z)
	if flat.length() <= 0.001:
		return 0.0
	var base = Vector2(0.0, -1.0)
	return base.angle_to(flat.normalized()) + sprite_rotation_offset

func _update_billboard_orientation() -> void:
	if icicle_sprite == null:
		return
	var camera = get_viewport().get_camera_3d()
	if camera == null:
		return
	var look_position = camera.global_position
	look_at(look_position, camera.global_basis.y)
	icicle_sprite.rotation.z = _get_sprite_rotation_z(velocity)

func _on_body_entered(body: Node3D) -> void:
	if not launched:
		return
	super._on_body_entered(body)
	queue_free()

func _on_area_entered(area: Area3D) -> void:
	if not launched:
		return
	if area == null or area == self:
		return
	if area.is_in_group("ice_projectile"):
		area.queue_free()
		queue_free()
		return
