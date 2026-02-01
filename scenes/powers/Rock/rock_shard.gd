extends Sprite3D

var age := 0.0
var lifetime := 0.5
var fade_duration := 0.3
var base_modulate := Color.WHITE
var velocity := Vector3.ZERO
var gravity := 6.0

func _ready() -> void:
	set_process(true)

func configure(new_lifetime: float, new_velocity: Vector3, new_gravity: float, new_fade_duration: float, base_color: Color) -> void:
	age = 0.0
	lifetime = new_lifetime
	velocity = new_velocity
	gravity = new_gravity
	fade_duration = new_fade_duration
	base_modulate = base_color
	modulate = base_color
	set_process(true)

func _process(delta: float) -> void:
	age += delta
	velocity.y -= gravity * delta
	global_position += velocity * delta
	if age >= lifetime:
		queue_free()
		return
	if fade_duration <= 0.0:
		return
	var fade_start = max(lifetime - fade_duration, 0.0)
	if age < fade_start:
		return
	var t = clamp((age - fade_start) / fade_duration, 0.0, 1.0)
	var color = base_modulate
	color.a = lerp(base_modulate.a, 0.0, t)
	modulate = color
