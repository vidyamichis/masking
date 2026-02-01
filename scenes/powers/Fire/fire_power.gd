extends "res://scenes/powers/power_hitbox.gd"

const FIRE_FRAMES = [
	preload("res://resources/powers/fire/1.png"),
	preload("res://resources/powers/fire/2.png"),
	preload("res://resources/powers/fire/3.png"),
	preload("res://resources/powers/fire/4.png"),
	preload("res://resources/powers/fire/5.png"),
]

@export var frame_rate = 10.0
@export var active_scale_step = 0.05

@onready var fire_sprite = $FireSprite as Sprite3D

var frame_elapsed := 0.0
var idle_index := 0
var active_stage := 0
var was_active := false
var base_scale := Vector3.ONE
var flip_state := false
var scale_pulse := 1

func _ready() -> void:
	super._ready()
	if fire_sprite != null:
		base_scale = fire_sprite.scale
		_set_frame(0)

func _process(delta: float) -> void:
	super._process(delta)
	_update_animation(delta)

func _update_animation(delta: float) -> void:
	if fire_sprite == null:
		return
	var frame_time = 1.0 / max(frame_rate, 0.01)
	frame_elapsed += delta
	var active_now = monitoring

	if active_now and not was_active:
		was_active = true
		active_stage = 0
		frame_elapsed = 0.0
		_set_frame(3)
		return

	if not active_now and was_active:
		was_active = false
		active_stage = 0
		frame_elapsed = 0.0
		idle_index = 0
		flip_state = false
		scale_pulse = 1
		fire_sprite.flip_h = false
		fire_sprite.scale = base_scale
		_set_frame(0)
		return

	if frame_elapsed < frame_time:
		return

	while frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		if active_now:
			if active_stage == 0:
				active_stage = 1
				_set_frame(4)
			else:
				_set_frame(4)
				_apply_active_pulse()
		else:
			idle_index = (idle_index + 1) % 3
			_set_frame(idle_index)

func _apply_active_pulse() -> void:
	flip_state = not flip_state
	fire_sprite.flip_h = flip_state
	scale_pulse *= -1
	var scale_factor = 1.0 + active_scale_step * scale_pulse
	fire_sprite.scale = base_scale * scale_factor

func _set_frame(frame_index: int) -> void:
	fire_sprite.texture = FIRE_FRAMES[frame_index]
