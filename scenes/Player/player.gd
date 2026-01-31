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

@export var slap_duration = 0.12
@export var slap_cooldown = 0.3
@export var slap_offset = Vector3(0.0, 0.6, -1.0)
@export var slap_scene: PackedScene = preload("res://scenes/powers/Slap/Slap.tscn")
@export var has_mask = false
@export var input_device = 0
@export var move_deadzone = 0.2
@export var dash_button = 0
@export var action_button = 2
@export var debug_button = 4

# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75

signal slap_hit(body: Node3D)

var target_velocity = Vector3.ZERO
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var dash_invulnerable_left := 0.0
var dash_direction := Vector3.ZERO
var is_invulnerable := false
var slap_time_left := 0.0
var slap_cooldown_left := 0.0
var slap_hitbox: Area3D
var slap_debug_mesh: MeshInstance3D
var input_vector := Vector2.ZERO
var dash_triggered := false
var action_triggered := false
var debug_triggered := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	slap_hitbox = _create_slap_hitbox()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.device != input_device:
		return
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_X:
			input_vector.x = _apply_deadzone(event.axis_value)
		elif event.axis == JOY_AXIS_LEFT_Y:
			input_vector.y = _apply_deadzone(event.axis_value)
	elif event is InputEventJoypadButton:
		if event.button_index == dash_button and event.pressed:
			dash_triggered = true
		elif event.button_index == action_button and event.pressed:
			action_triggered = true
		elif event.button_index == debug_button and event.pressed:
			debug_triggered = true

func _apply_deadzone(value: float) -> float:
	return 0.0 if abs(value) < move_deadzone else value

func _create_slap_hitbox() -> Area3D:
	var slap_instance = slap_scene.instantiate()
	add_child(slap_instance)
	var area = slap_instance as Area3D
	if area == null:
		area = slap_instance.get_node_or_null("Area3D") as Area3D
	if area == null:
		push_error("Slap scene must be an Area3D or contain an Area3D node named Area3D.")
		return null
	area.monitoring = false
	area.monitorable = true
	area.body_entered.connect(_on_slap_body_entered)

	var shape = area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		slap_debug_mesh = MeshInstance3D.new()
		slap_debug_mesh.mesh = BoxMesh.new()
		slap_debug_mesh.mesh.size = shape.shape.size
		slap_debug_mesh.visible = false
		area.add_child(slap_debug_mesh)

	return area

func _update_slap_hitbox_transform() -> void:
	if slap_hitbox == null:
		return
	var pivot_basis = $Pivot.global_basis
	var offset = pivot_basis * slap_offset
	slap_hitbox.global_position = $Pivot.global_position + offset
	slap_hitbox.global_basis = pivot_basis

func _on_slap_body_entered(body: Node3D) -> void:
	if body == self:
		return
	slap_hit.emit(body)

func _physics_process(delta: float) -> void:
	# Gamepad movement vector (deadzone handled)
	var input_vec: Vector2 = input_vector

	# Convert to 3D direction on the XZ plane
	var direction := Vector3(input_vec.x, 0.0, input_vec.y)

	if dash_cooldown_left > 0.0:
		dash_cooldown_left = max(0.0, dash_cooldown_left - delta)

	if slap_cooldown_left > 0.0:
		slap_cooldown_left = max(0.0, slap_cooldown_left - delta)

	if debug_triggered:
		Debug.show_hitboxes = not Debug.show_hitboxes
		debug_triggered = false

	if direction.length() > 0.0:
		# Rotate to face movement direction (optional)
		$Pivot.basis = Basis.looking_at(direction.normalized(), Vector3.UP)

	if dash_triggered and dash_time_left <= 0.0 and dash_cooldown_left <= 0.0:
		if direction.length() > 0.0:
			dash_direction = direction.normalized()
		else:
			dash_direction = -$Pivot.basis.z.normalized()
		dash_time_left = dash_duration
		dash_invulnerable_left = dash_duration * dash_invulnerable_ratio
		dash_cooldown_left = dash_cooldown

	if action_triggered and slap_time_left <= 0.0 and slap_cooldown_left <= 0.0:
		if not has_mask:
			slap_time_left = slap_duration
			slap_cooldown_left = slap_cooldown

	dash_triggered = false
	action_triggered = false

	if dash_invulnerable_left > 0.0:
		dash_invulnerable_left = max(0.0, dash_invulnerable_left - delta)
	is_invulnerable = dash_invulnerable_left > 0.0

	if slap_time_left > 0.0:
		slap_time_left = max(0.0, slap_time_left - delta)
	_update_slap_hitbox_transform()
	if slap_hitbox != null:
		slap_hitbox.monitoring = slap_time_left > 0.0
	if slap_debug_mesh != null:
		slap_debug_mesh.visible = Debug.show_hitboxes and slap_time_left > 0.0

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
