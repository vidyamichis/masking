extends CharacterBody3D

# How fast the player moves in meters per second.
@export var speed = 14

# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75

var target_velocity = Vector3.ZERO

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

	if direction.length() > 0.0:
		# Rotate to face movement direction (optional)
		$Pivot.basis = Basis.looking_at(direction.normalized(), Vector3.UP)

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
