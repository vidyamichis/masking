extends CharacterBody3D

# How fast the player moves in meters per second.
@export var speed = 14

# Dash speed in meters per second.
@export var dash_speed = 28

# How long the dash lasts in seconds.
@export var dash_duration = 0.18

# Time before another dash is allowed.
@export var dash_cooldown = 0.35

# Portion of dash duration where invulnerable.
@export var dash_invulnerable_ratio = 0.5

# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75

var target_velocity = Vector3.ZERO
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var dash_invulnerable_left := 0.0
var dash_direction := Vector3.ZERO
var is_invulnerable := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	# Gamepad/keyboard movement vector (deadzone handled)
	var input_vec: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	# Convert to 3D direction on the XZ plane
	var direction := Vector3(input_vec.x, 0.0, input_vec.y)

	if dash_cooldown_left > 0.0:
		dash_cooldown_left = max(0.0, dash_cooldown_left - delta)

	if direction.length() > 0.0:
		# Rotate to face movement direction (optional)
		$Pivot.basis = Basis.looking_at(direction.normalized(), Vector3.UP)

	if Input.is_action_just_pressed("dash") and dash_time_left <= 0.0 and dash_cooldown_left <= 0.0:
		if direction.length() > 0.0:
			dash_direction = direction.normalized()
		else:
			dash_direction = -$Pivot.basis.z.normalized()
		dash_time_left = dash_duration
		dash_invulnerable_left = dash_duration * dash_invulnerable_ratio
		dash_cooldown_left = dash_cooldown

	if dash_invulnerable_left > 0.0:
		dash_invulnerable_left = max(0.0, dash_invulnerable_left - delta)
	is_invulnerable = dash_invulnerable_left > 0.0

	if dash_time_left > 0.0:
		dash_time_left = max(0.0, dash_time_left - delta)
		target_velocity.x = dash_direction.x * dash_speed
		target_velocity.z = dash_direction.z * dash_speed
	else:
		if direction.length() > 0.0:
			# Ground velocity
			target_velocity.x = direction.x * speed
			target_velocity.z = direction.z * speed
		else:
			# If you want the character to stop when no input:
			target_velocity.x = move_toward(target_velocity.x, 0.0, speed)
			target_velocity.z = move_toward(target_velocity.z, 0.0, speed)

	# Gravity
	if not is_on_floor():
		target_velocity.y -= fall_acceleration * delta
	else:
		# Optional: keep grounded / avoid accumulating small downward velocity
		target_velocity.y = 0.0

	# Apply movement
	velocity = target_velocity
	move_and_slide()
