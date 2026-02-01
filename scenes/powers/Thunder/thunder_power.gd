extends "res://scenes/powers/power_hitbox.gd"

const THUNDER_FRAMES = [
	preload("res://resources/powers/thunder/1.png"),
	preload("res://resources/powers/thunder/2.png"),
	preload("res://resources/powers/thunder/3.png"),
	preload("res://resources/powers/thunder/4.png"),
	preload("res://resources/powers/thunder/5.png"),
]

const TELEGRAPH_FRAMES = [0, 1]
const TRANSITION_FRAMES = [2, 2, 3, 3]
const TRANSITION_MIRRORS = [false, true, false, true]
const DAMAGE_FRAME_INDEX = 4

enum Phase {
	TELEGRAPH,
	TRANSITION,
	DAMAGE,
}

@export var frame_rate = 26.0
@export var telegraph_duration = 0.5
@export var damage_duration = 0.4
@export var ring_radius = 0.8
@export var height_offset = 0.7
@export var forward_offset = -0.4
@export var scale_min = 1.8
@export var scale_max = 2.3
@export var stun_duration = 1.2
@export var caster_stun_duration = 1.2

var caster: Node3D

@onready var cast_audio_player = $CastSound as AudioStreamPlayer3D

var thunder_sprites: Array[Sprite3D] = []
var base_scales: Array[Vector3] = []
var base_flips: Array[bool] = []
var frame_elapsed := 0.0
var phase := Phase.TELEGRAPH
var telegraph_left := 0.0
var damage_left := 0.0
var transition_step := 0
var mirror_state := false
var current_frame := 0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	super._ready()
	rng.randomize()
	thunder_sprites = _collect_thunder_sprites()
	for sprite in thunder_sprites:
		base_scales.append(sprite.scale)
		base_flips.append(sprite.flip_h)
		sprite.texture = THUNDER_FRAMES[0]
		sprite.visible = false
	if cast_audio_player != null:
		cast_audio_player.stop()

func activate(spawn_basis: Basis, spawn_position: Vector3, target_mask: int, source: Node3D = null) -> void:
	caster = source
	if caster != null:
		spawn_position = caster.global_position
	spawn_position += Vector3(0.0, 0.0, forward_offset)
	super.activate(spawn_basis, spawn_position, target_mask)
	monitoring = false
	phase = Phase.TELEGRAPH
	telegraph_left = telegraph_duration
	damage_left = damage_duration
	transition_step = 0
	mirror_state = false
	current_frame = TELEGRAPH_FRAMES[0]
	frame_elapsed = 0.0
	_set_ring_positions()
	_randomize_sprite_variation()
	_set_sprites_visible(true)
	_set_frame(current_frame)
	_apply_mirror(false)
	var frame_time = 1.0 / max(frame_rate, 0.01)
	time_left = telegraph_duration + damage_duration + (frame_time * TRANSITION_FRAMES.size())
	delay_left = 0.0
	if caster != null and cast_audio_player != null:
		var sound_position = caster.global_position
		sound_position.y += height_offset
		cast_audio_player.global_position = sound_position
	_update_debug()

func _process(delta: float) -> void:
	super._process(delta)
	if caster != null and is_instance_valid(caster):
		global_position = caster.global_position + Vector3(0.0, 0.0, forward_offset)
	if thunder_sprites.is_empty():
		return
	var frame_time = 1.0 / max(frame_rate, 0.01)
	frame_elapsed += delta
	match phase:
		Phase.TELEGRAPH:
			_update_telegraph(delta, frame_time)
		Phase.TRANSITION:
			_update_transition(frame_time)
		Phase.DAMAGE:
			_update_damage(delta, frame_time)

func _update_telegraph(delta: float, frame_time: float) -> void:
	telegraph_left = max(0.0, telegraph_left - delta)
	while frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		_advance_telegraph()
	if telegraph_left <= 0.0:
		_start_transition()

func _update_transition(frame_time: float) -> void:
	while frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		_advance_transition()

func _update_damage(delta: float, frame_time: float) -> void:
	damage_left = max(0.0, damage_left - delta)
	while frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		_advance_damage()
	if damage_left <= 0.0:
		_end_damage()

func _advance_telegraph() -> void:
	if not mirror_state:
		mirror_state = true
		_apply_mirror(true)
		return
	mirror_state = false
	current_frame = TELEGRAPH_FRAMES[1] if current_frame == TELEGRAPH_FRAMES[0] else TELEGRAPH_FRAMES[0]
	_set_frame(current_frame)
	_apply_mirror(false)

func _start_transition() -> void:
	phase = Phase.TRANSITION
	frame_elapsed = 0.0
	transition_step = 0
	current_frame = TRANSITION_FRAMES[transition_step]
	mirror_state = TRANSITION_MIRRORS[transition_step]
	_set_frame(current_frame)
	_apply_mirror(mirror_state)

func _advance_transition() -> void:
	transition_step += 1
	if transition_step >= TRANSITION_FRAMES.size():
		_start_damage()
		return
	current_frame = TRANSITION_FRAMES[transition_step]
	mirror_state = TRANSITION_MIRRORS[transition_step]
	_set_frame(current_frame)
	_apply_mirror(mirror_state)

func _start_damage() -> void:
	phase = Phase.DAMAGE
	frame_elapsed = 0.0
	mirror_state = false
	current_frame = DAMAGE_FRAME_INDEX
	_set_frame(current_frame)
	_apply_mirror(false)
	_enable_hitbox()
	if cast_audio_player != null:
		cast_audio_player.play()
	if caster != null and caster.has_method("apply_stun"):
		caster.apply_stun(caster_stun_duration)

func _advance_damage() -> void:
	mirror_state = not mirror_state
	_apply_mirror(mirror_state)

func _end_damage() -> void:
	monitoring = false
	_update_debug()
	queue_free()

func _set_frame(frame: int) -> void:
	var texture = THUNDER_FRAMES[frame]
	for sprite in thunder_sprites:
		sprite.texture = texture

func _apply_mirror(is_mirrored: bool) -> void:
	for index in range(thunder_sprites.size()):
		var sprite = thunder_sprites[index]
		sprite.flip_h = base_flips[index] if not is_mirrored else not base_flips[index]

func _set_ring_positions() -> void:
	var count = max(1, thunder_sprites.size())
	for index in range(thunder_sprites.size()):
		var angle = TAU * float(index) / float(count)
		var offset = Vector3(cos(angle), 0.0, sin(angle)) * ring_radius
		offset.y = height_offset
		thunder_sprites[index].position = offset

func _randomize_sprite_variation() -> void:
	for index in range(thunder_sprites.size()):
		var sprite = thunder_sprites[index]
		var scale_factor = rng.randf_range(scale_min, scale_max)
		sprite.scale = base_scales[index] * scale_factor
		var flipped = rng.randi_range(0, 1) == 1
		base_flips[index] = flipped
		sprite.flip_h = flipped

func _set_sprites_visible(is_visible: bool) -> void:
	for sprite in thunder_sprites:
		sprite.visible = is_visible

func _collect_thunder_sprites() -> Array[Sprite3D]:
	var sprites: Array[Sprite3D] = []
	for child in get_children():
		if child is Sprite3D:
			sprites.append(child)
	sprites.sort_custom(func(a: Sprite3D, b: Sprite3D) -> bool:
		return a.name < b.name
	)
	return sprites

func _enable_hitbox() -> void:
	if monitoring:
		return
	monitoring = true
	_update_debug()

func _on_body_entered(body: Node3D) -> void:
	if body == null or body == self or body == caster:
		return
	if body.has_method("apply_power"):
		body.apply_power(global_position)
	hit.emit(body)
