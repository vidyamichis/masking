extends CharacterBody3D

# How fast the player moves in meters per second.
@export var speed = 6
@export var acceleration = 40.0
@export var deceleration = 100.0

# Dash speed in meters per second.
@export var dash_speed = 20

# How long the dash lasts in seconds.
@export var dash_duration = 0.12

# Time before another dash is allowed.
@export var dash_cooldown = 0.65

# Portion of dash duration where invulnerable.
@export var dash_invulnerable_ratio = 0.5

@export var slap_duration = 0.12
@export var slap_cooldown = 0.6
@export var slap_offset = Vector3(0.0, 0.6, -1.0)
@export var slap_scene: PackedScene = preload("res://scenes/powers/Slap/Slap.tscn")
@export var slap_knockback = 24.0
@export var slap_knockback_decay = 48.0
@export var slap_stun_duration = 0.45
@export var has_mask = false
@export var input_device = -1
@export var move_deadzone = 0.2
@export var dash_button = 0
@export var action_button = 2
@export var debug_button = 4

# The downward acceleration when in the air, in meters per second squared.
@export var fall_acceleration = 75
@export var slap_target_mask = 2
@export var mask_anchor_path: NodePath = NodePath("Pivot/MaskAnchor")
@export var mask_discard_scene: PackedScene = preload("res://scenes/masks/mask_discard.tscn")
@export var mask_drop_distance_factor = 0.75
@export var mask_drop_height = 0.3
@export var mask_drop_angle_deg = 45.0
@export var mask_drop_decay = 18.0
@export var mask_drop_strength = 0.35

signal slap_hit(body: Node3D)

var target_velocity = Vector3.ZERO
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var dash_invulnerable_left := 0.0
var dash_direction := Vector3.ZERO
var is_invulnerable := false
var slap_time_left := 0.0
var slap_cooldown_left := 0.0
var stun_time_left := 0.0
var knockback_velocity := Vector3.ZERO
var slap_basis := Basis.IDENTITY
var slap_position := Vector3.ZERO
var slap_hitbox: Area3D
var mask_anchor: Node3D
var equipped_mask: Node3D
var last_slap_knockback = 0.0
var slap_debug_mesh: MeshInstance3D
var input_vector := Vector2.ZERO
var dash_triggered := false
var action_triggered := false
var debug_triggered := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	slap_hitbox = _create_slap_hitbox()
	mask_anchor = get_node_or_null(mask_anchor_path) as Node3D


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if input_device < 0 or event.device != input_device:
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

func set_input_device(device: int) -> void:
	if input_device == device:
		return
	input_device = device
	input_vector = Vector2.ZERO
	dash_triggered = false
	action_triggered = false
	debug_triggered = false

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
	area.collision_mask = slap_target_mask
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
	if slap_hitbox == null or slap_time_left <= 0.0:
		return
	slap_hitbox.global_position = slap_position
	slap_hitbox.global_basis = slap_basis

func _on_slap_body_entered(body: Node3D) -> void:
	if body == self:
		return
	if Debug.show_hitboxes:
		print("Slap hit: ", body.name)
	if body.has_method("apply_slap"):
		body.apply_slap(global_position, slap_knockback, slap_stun_duration)
	slap_hit.emit(body)

func apply_slap(from_position: Vector3, knockback: float, stun_duration: float) -> void:
	if is_invulnerable:
		return
	var knockback_direction = (global_position - from_position).normalized()
	if knockback_direction.is_zero_approx():
		knockback_direction = -$Pivot.basis.z.normalized()
	knockback_velocity = Vector3(knockback_direction.x, 0.0, knockback_direction.z) * knockback
	stun_time_left = max(stun_time_left, stun_duration)
	last_slap_knockback = knockback
	if equipped_mask != null:
		_drop_equipped_mask(knockback_direction)

func equip_mask(mask: Node3D) -> void:
	if mask_anchor == null or mask == null:
		return
	if equipped_mask != null:
		_spawn_discard_mask(equipped_mask.global_transform, equipped_mask)
		equipped_mask.queue_free()
		equipped_mask = null
	if mask.has_method("mark_picked"):
		mask.mark_picked()
	var mask_parent = mask.get_parent()
	if mask_parent != null:
		mask_parent.call_deferred("remove_child", mask)
	mask_anchor.call_deferred("add_child", mask)
	mask.call_deferred("set", "transform", Transform3D.IDENTITY)
	equipped_mask = mask
	has_mask = true

func _drop_equipped_mask(hit_direction: Vector3) -> void:
	if equipped_mask == null:
		return
	var dropped_mask = equipped_mask
	equipped_mask = null
	has_mask = false
	if dropped_mask.has_method("drop_from_hit"):
		dropped_mask.drop_from_hit(
			global_position,
			hit_direction,
		last_slap_knockback,
		mask_drop_distance_factor,
		mask_drop_height,
		mask_drop_angle_deg,
		mask_drop_decay,
		mask_drop_strength
	)


func _spawn_discard_mask(mask_transform: Transform3D, source_mask: Node3D) -> void:
	if mask_discard_scene == null:
		return
	var discard = mask_discard_scene.instantiate() as Node3D
	if discard == null:
		return
	discard.global_transform = mask_transform
	get_tree().current_scene.add_child(discard)
	var mesh = _find_mesh_instance(source_mask)
	var discard_mesh = _find_mesh_instance(discard)
	if mesh != null and discard_mesh != null:
		discard_mesh.mesh = mesh.mesh
		discard_mesh.scale = mesh.scale
		discard_mesh.rotation = mesh.rotation

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found != null:
			return found
	return null

func _physics_process(delta: float) -> void:
	# Gamepad movement vector (deadzone handled)
	var input_vec: Vector2 = input_vector

	# Convert to 3D direction on the XZ plane
	var direction := Vector3(input_vec.x, 0.0, input_vec.y)

	if dash_cooldown_left > 0.0:
		dash_cooldown_left = max(0.0, dash_cooldown_left - delta)

	if slap_cooldown_left > 0.0:
		slap_cooldown_left = max(0.0, slap_cooldown_left - delta)

	if stun_time_left > 0.0:
		stun_time_left = max(0.0, stun_time_left - delta)
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, slap_knockback_decay * delta)

	if debug_triggered:
		Debug.show_hitboxes = not Debug.show_hitboxes
		debug_triggered = false

	if direction.length() > 0.0 and stun_time_left <= 0.0:
		# Rotate to face movement direction (optional)
		$Pivot.basis = Basis.looking_at(direction.normalized(), Vector3.UP)

	if stun_time_left <= 0.0:
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
			slap_basis = $Pivot.global_basis
			slap_position = $Pivot.global_position + (slap_basis * slap_offset)


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
	elif stun_time_left > 0.0:
		target_velocity.x = 0.0
		target_velocity.z = 0.0
	else:
		if direction.length() > 0.0:
			# Ground velocity
			var desired_velocity = direction * speed
			target_velocity.x = move_toward(target_velocity.x, desired_velocity.x, acceleration * delta)
			target_velocity.z = move_toward(target_velocity.z, desired_velocity.z, acceleration * delta)
		else:
			# If you want the character to stop when no input:
			target_velocity.x = move_toward(target_velocity.x, 0.0, deceleration * delta)
			target_velocity.z = move_toward(target_velocity.z, 0.0, deceleration * delta)

	# Gravity
	if not is_on_floor():
		target_velocity.y -= fall_acceleration * delta
	else:
		# Optional: keep grounded / avoid accumulating small downward velocity
		target_velocity.y = 0.0

	# Apply movement
	if stun_time_left > 0.0:
		velocity.x = knockback_velocity.x
		velocity.z = knockback_velocity.z
		velocity.y = target_velocity.y
		move_and_slide()
	else:
		velocity = target_velocity
		move_and_slide()
