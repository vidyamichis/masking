extends CharacterBody3D

# How fast the player moves in meters per second.
@export var speed = 6
@export var acceleration = 40.0
@export var deceleration = 100.0

# Dash speed in meters per second.
@export var dash_speed = 20

# How long the dash lasts in seconds.
@export var dash_duration = 0.12
@export var dash_animation_speed = 3

# Time before another dash is allowed.
@export var dash_cooldown = 0.65

# Portion of dash duration where invulnerable.
@export var dash_invulnerable_ratio = 0.5

@export var slap_duration = 0.12
@export var slap_animation_speed = 3
@export var slap_cooldown = 0.6
@export var slap_offset = Vector3(0.0, 0.6, -1.0)
@export var slap_scene: PackedScene = preload("res://scenes/powers/Slap/Slap.tscn")
@export var slap_knockback = 24.0
@export var slap_knockback_decay = 48.0
@export var slap_stun_duration = 0.45
@export var slap_hit_sound: AudioStream = preload("res://resources/sounds/slap.ogg")
@export var slap_hit_extra_sound: AudioStream = preload("res://resources/sounds/japish.ogg")
@export var damage_sound: AudioStream = preload("res://resources/sounds/dead.ogg")
@export var power_down_sound: AudioStream = preload("res://resources/sounds/power-down.ogg")
@export var dead_ko_sound: AudioStream = preload("res://resources/sounds/dead-ko.ogg")
@export var power_up_sound: AudioStream = preload("res://resources/sounds/power-up-2.ogg")
@export var step_sound: AudioStream = preload("res://resources/sounds/step.ogg")
@export var dash_sound: AudioStream = preload("res://resources/sounds/dash.ogg")
@export var power_offset = Vector3(0.0, 0.6, -1.0)
@export var fire_scene: PackedScene = preload("res://scenes/powers/Fire/Fire.tscn")
@export var ice_scene: PackedScene = preload("res://scenes/powers/Ice/Ice.tscn")
@export var thunder_scene: PackedScene = preload("res://scenes/powers/Thunder/Thunder.tscn")
@export var wind_scene: PackedScene = preload("res://scenes/powers/Wind/Wind.tscn")
@export var rock_scene: PackedScene = preload("res://scenes/powers/Rock/Rock.tscn")
@export var poison_scene: PackedScene = preload("res://scenes/powers/Poison/Poison.tscn")
@export var light_scene: PackedScene = preload("res://scenes/powers/Light/Light.tscn")
@export var dark_scene: PackedScene = preload("res://scenes/powers/Dark/Dark.tscn")
@export var fire_cooldown = 1.2
@export var ice_cooldown = 1.2
@export var thunder_cooldown = 1.2
@export var wind_cooldown = 1.2
@export var rock_cooldown = 1.2
@export var poison_cooldown = 1.2
@export var light_cooldown = 1.2
@export var dark_cooldown = 1.2
@export var power_target_mask = 2
@export var fire_pillar_count = 5
@export var fire_pillar_delay = 0.3
@export var fire_pillar_duration = 3.0
@export var fire_pillar_activation_delay = 0.5
@export var fire_pillar_max_casts = 2
@export var fire_pillar_spawn_sound: AudioStream = preload("res://resources/sounds/fire.ogg")
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
@export var respawn_delay = 5.0
@export var death_fade_duration = 0.6
@export var hurt_invulnerable_duration = 1.0
@export var power_death_delay = 0.45

signal slap_hit(body: Node3D)

var target_velocity = Vector3.ZERO
var dash_time_left := 0.0
var dash_cooldown_left := 0.0
var dash_invulnerable_left := 0.0
var dash_direction := Vector3.ZERO
var is_invulnerable := false
var hurt_invulnerable_left := 0.0
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
var power_cooldown_left = 0.0
var fire_pillar_casts_active := 0
var is_respawning := false
var is_dead := false
var respawn_position := Vector3.ZERO
var respawn_basis := Basis.IDENTITY
var spawn_position := Vector3.ZERO
var spawn_basis := Basis.IDENTITY
var fade_elapsed := 0.0
var fade_meshes: Array[MeshInstance3D] = []
var animation_tree: AnimationTree
var animation_playback: AnimationNodeStateMachinePlayback
var animation_player: AnimationPlayer
var attack_time_left := 0.0
var attack_animation_length := 0.0
var animation_speed_state := ""
var wind_pull_velocity := Vector3.ZERO
var slap_audio_player: AudioStreamPlayer3D
var slap_extra_audio_player: AudioStreamPlayer3D
var fire_pillar_audio_player: AudioStreamPlayer3D
var damage_audio_player: AudioStreamPlayer3D
var power_down_audio_player: AudioStreamPlayer3D
var dead_ko_audio_player: AudioStreamPlayer3D
var power_up_audio_player: AudioStreamPlayer3D
var step_audio_player: AudioStreamPlayer3D
var dash_audio_player: AudioStreamPlayer3D
var step_interval_left := 0.0
var was_moving := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	slap_hitbox = _create_slap_hitbox()
	mask_anchor = get_node_or_null(mask_anchor_path) as Node3D
	spawn_position = global_position
	spawn_basis = $Pivot.global_basis
	_setup_animation_tree()
	_setup_slap_audio()
	_setup_fire_audio()
	_setup_combat_audio()
	_setup_movement_audio()


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
			_play_animation("Dash")
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

func _setup_animation_tree() -> void:
	animation_player = $Pivot/player/AnimationPlayer
	animation_tree = $Pivot/player/AnimationTree
	if animation_tree == null:
		return
	animation_tree.active = true
	var playback = animation_tree.get("parameters/playback")
	if playback is AnimationNodeStateMachinePlayback:
		animation_playback = playback
	if animation_player != null:
		var attack_animation = animation_player.get_animation("Attack")
		if attack_animation != null:
			attack_animation_length = attack_animation.length

func _play_animation(state_name: String) -> void:
	if animation_playback == null:
		return
	animation_playback.travel(state_name)
	if animation_player == null:
		return
	if state_name == animation_speed_state:
		return
	animation_speed_state = state_name
	if state_name == "Dash":
		animation_player.speed_scale = dash_animation_speed
	elif state_name == "Slap":
		animation_player.speed_scale = slap_animation_speed
	else:
		animation_player.speed_scale = 1.0

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

func _setup_slap_audio() -> void:
	slap_audio_player = AudioStreamPlayer3D.new()
	slap_audio_player.stream = slap_hit_sound
	add_child(slap_audio_player)
	slap_extra_audio_player = AudioStreamPlayer3D.new()
	slap_extra_audio_player.stream = slap_hit_extra_sound
	add_child(slap_extra_audio_player)

func _setup_fire_audio() -> void:
	fire_pillar_audio_player = AudioStreamPlayer3D.new()
	fire_pillar_audio_player.stream = fire_pillar_spawn_sound
	add_child(fire_pillar_audio_player)

func _setup_combat_audio() -> void:
	damage_audio_player = AudioStreamPlayer3D.new()
	damage_audio_player.stream = damage_sound
	add_child(damage_audio_player)
	power_down_audio_player = AudioStreamPlayer3D.new()
	power_down_audio_player.stream = power_down_sound
	add_child(power_down_audio_player)
	dead_ko_audio_player = AudioStreamPlayer3D.new()
	dead_ko_audio_player.stream = dead_ko_sound
	add_child(dead_ko_audio_player)
	power_up_audio_player = AudioStreamPlayer3D.new()
	power_up_audio_player.stream = power_up_sound
	add_child(power_up_audio_player)

func _setup_movement_audio() -> void:
	step_audio_player = AudioStreamPlayer3D.new()
	step_audio_player.stream = step_sound
	add_child(step_audio_player)
	dash_audio_player = AudioStreamPlayer3D.new()
	dash_audio_player.stream = dash_sound
	add_child(dash_audio_player)

func _on_slap_body_entered(body: Node3D) -> void:
	if body == self:
		return
	if Debug.show_hitboxes:
		print("Slap hit: ", body.name)
	if body.has_method("apply_slap"):
		body.apply_slap(global_position, slap_knockback, slap_stun_duration)
	_play_slap_hit_sounds()
	slap_hit.emit(body)

func _play_slap_hit_sounds() -> void:
	if slap_audio_player != null:
		slap_audio_player.play()
	if slap_extra_audio_player != null:
		slap_extra_audio_player.play()

func _play_fire_pillar_spawn_sound(spawn_position: Vector3) -> void:
	if fire_pillar_audio_player == null:
		return
	fire_pillar_audio_player.global_position = spawn_position
	fire_pillar_audio_player.play()

func _play_damage_sounds(play_power_down: bool, play_ko: bool) -> void:
	if damage_audio_player != null:
		damage_audio_player.play()
	if play_power_down and power_down_audio_player != null:
		power_down_audio_player.play()
	if play_ko and dead_ko_audio_player != null:
		dead_ko_audio_player.play()

func _play_power_up_sound() -> void:
	if power_up_audio_player != null:
		power_up_audio_player.play()

func _play_dash_sound() -> void:
	if dash_audio_player != null:
		dash_audio_player.play()

func _update_step_audio(direction: Vector3, delta: float) -> void:
	var moving = direction.length() > 0.1 and stun_time_left <= 0.0 and dash_time_left <= 0.0
	if not moving:
		step_interval_left = 0.0
		was_moving = false
		return
	if not was_moving:
		step_interval_left = 0.3
		was_moving = true
		return
	step_interval_left = max(0.0, step_interval_left - delta)
	if step_interval_left <= 0.0:
		if step_audio_player != null:
			step_audio_player.play()
		step_interval_left = 0.3

func apply_slap(from_position: Vector3, knockback: float, stun_duration: float) -> void:
	if is_invulnerable or is_respawning or is_dead:
		return
	_apply_damage(from_position, knockback, stun_duration, true)

func apply_power(from_position: Vector3) -> void:
	if is_invulnerable or is_respawning or is_dead:
		return
	_apply_damage(from_position, slap_knockback, slap_stun_duration, false)

func apply_wind_pull(pull_velocity: Vector3) -> void:
	if is_invulnerable or is_respawning or is_dead:
		return
	wind_pull_velocity = pull_velocity

func _apply_damage(from_position: Vector3, knockback: float, stun_duration: float, is_slap: bool) -> void:
	var knockback_direction = (global_position - from_position).normalized()
	if knockback_direction.is_zero_approx():
		knockback_direction = -$Pivot.basis.z.normalized()
	knockback_velocity = Vector3(knockback_direction.x, 0.0, knockback_direction.z) * knockback
	hurt_invulnerable_left = max(hurt_invulnerable_left, hurt_invulnerable_duration)
	stun_time_left = max(stun_time_left, stun_duration)
	last_slap_knockback = knockback
	if is_slap:
		if equipped_mask != null:
			_drop_equipped_mask(knockback_direction)
		return
	if equipped_mask != null:
		_play_damage_sounds(true, false)
		_destroy_equipped_mask()
		return
	_play_damage_sounds(false, true)
	_start_respawn_cycle(power_death_delay)

func equip_mask(mask: Node3D) -> void:
	if mask_anchor == null or mask == null:
		return
	if equipped_mask != null:
		_spawn_discard_mask(equipped_mask.global_transform, equipped_mask)
		equipped_mask.queue_free()
		equipped_mask = null
	if mask.has_method("mark_picked"):
		mask.mark_picked()
	_play_power_up_sound()
	var mask_parent = mask.get_parent()
	if mask_parent != null:
		mask_parent.call_deferred("remove_child", mask)
	mask_anchor.call_deferred("add_child", mask)
	mask.call_deferred("set", "transform", Transform3D.IDENTITY)
	equipped_mask = mask
	has_mask = true
	power_cooldown_left = 0.0

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

func _destroy_equipped_mask() -> void:
	if equipped_mask == null:
		return
	var destroyed_mask = equipped_mask
	equipped_mask = null
	has_mask = false
	_spawn_discard_mask(destroyed_mask.global_transform, destroyed_mask)
	destroyed_mask.queue_free()

func _start_respawn_cycle(delay: float = 0.0) -> void:
	if is_respawning or is_dead:
		return
	is_respawning = true
	respawn_position = spawn_position
	respawn_basis = spawn_basis
	fade_elapsed = 0.0
	fade_meshes = _get_fade_meshes()
	_play_animation("Die")
	call_deferred("_handle_respawn", delay)

func _handle_respawn(delay: float) -> void:
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	is_dead = true
	await _fade_out_player()
	if not is_inside_tree():
		return
	await get_tree().create_timer(respawn_delay).timeout
	if not is_inside_tree():
		return
	global_position = respawn_position
	$Pivot.global_basis = respawn_basis
	velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	stun_time_left = 0.0
	_reset_fade()
	hurt_invulnerable_left = 0.0
	is_dead = false
	is_respawning = false

func _fade_out_player() -> void:
	if fade_meshes.is_empty() or death_fade_duration <= 0.0:
		visible = false
		return
	var elapsed = 0.0
	while elapsed < death_fade_duration:
		var t = elapsed / death_fade_duration
		_set_fade_alpha(1.0 - t)
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	_set_fade_alpha(0.0)
	visible = false

func _reset_fade() -> void:
	visible = true
	_set_fade_alpha(1.0)

func _set_fade_alpha(alpha: float) -> void:
	if alpha >= 1.0:
		for mesh in fade_meshes:
			if mesh == null or not is_instance_valid(mesh):
				continue
			mesh.material_override = null
		return
	for mesh in fade_meshes:
		if mesh == null or not is_instance_valid(mesh):
			continue
		var material = mesh.get_active_material(0)
		if material is StandardMaterial3D:
			var override = material.duplicate() as StandardMaterial3D
			override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			override.albedo_color.a = alpha
			mesh.material_override = override

func _get_fade_meshes() -> Array[MeshInstance3D]:
	var meshes: Array[MeshInstance3D] = []
	for child in get_children():
		_collect_meshes(child, meshes)
	return meshes

func _collect_meshes(node: Node, meshes: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		meshes.append(node)
	for child in node.get_children():
		_collect_meshes(child, meshes)


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

func _use_power() -> void:
	if equipped_mask == null:
		return
	var mask_id = _get_equipped_mask_id()
	var power_type = Match.get_power_for_mask_id(mask_id)
	var scene = _get_power_scene(power_type)
	if scene == null:
		return
	var basis = $Pivot.global_basis
	var position = $Pivot.global_position + (basis * power_offset)
	if power_type == Match.PowerType.FIRE:
		_trigger_fire_power(scene, basis, position)
	else:
		_spawn_power_hitbox(scene, basis, position, _get_power_cooldown(power_type))

func _get_equipped_mask_id() -> int:
	if equipped_mask == null:
		return 0
	if equipped_mask.has_method("get"):
		var id = equipped_mask.get("mask_id")
		if typeof(id) == TYPE_INT:
			return id
	return 0

func _get_power_scene(power_type: int) -> PackedScene:
	match power_type:
		Match.PowerType.FIRE:
			return fire_scene
		Match.PowerType.ICE:
			return ice_scene
		Match.PowerType.THUNDER:
			return thunder_scene
		Match.PowerType.WIND:
			return wind_scene
		Match.PowerType.ROCK:
			return rock_scene
		Match.PowerType.POISON:
			return poison_scene
		Match.PowerType.LIGHT:
			return light_scene
		Match.PowerType.DARK:
			return dark_scene
	return null

func _get_power_cooldown(power_type: int) -> float:
	match power_type:
		Match.PowerType.FIRE:
			return fire_cooldown
		Match.PowerType.ICE:
			return ice_cooldown
		Match.PowerType.THUNDER:
			return thunder_cooldown
		Match.PowerType.WIND:
			return wind_cooldown
		Match.PowerType.ROCK:
			return rock_cooldown
		Match.PowerType.POISON:
			return poison_cooldown
		Match.PowerType.LIGHT:
			return light_cooldown
		Match.PowerType.DARK:
			return dark_cooldown
	return 1.0

func _spawn_power_hitbox(scene: PackedScene, basis: Basis, position: Vector3, cooldown: float) -> void:
	var instance = scene.instantiate()
	var area = instance as Area3D
	if area == null:
		return
	get_tree().current_scene.add_child(area)
	if area.has_method("activate"):
		area.call_deferred("activate", basis, position, power_target_mask)
	power_cooldown_left = cooldown

func _trigger_fire_power(scene: PackedScene, basis: Basis, start_position: Vector3) -> void:
	if fire_pillar_casts_active >= max(1, fire_pillar_max_casts):
		return
	fire_pillar_casts_active += 1
	var cooldown = fire_cooldown
	var timer = get_tree().create_timer(0.0)
	var pillar_size = _get_power_box_size(scene)
	var offset_direction = (-basis.z).normalized()
	for index in range(fire_pillar_count):
		await timer.timeout
		var spawn_position = start_position + offset_direction * (pillar_size.z * index)
		var instance = scene.instantiate() as Area3D
		if instance != null:
			instance.set("active_duration", fire_pillar_duration)
			instance.set("activation_delay", fire_pillar_activation_delay)
			get_tree().current_scene.add_child(instance)
			if instance.has_method("activate"):
				instance.call_deferred("activate", basis, spawn_position, power_target_mask)
			_play_fire_pillar_spawn_sound(spawn_position)
		timer = get_tree().create_timer(fire_pillar_delay)
	await get_tree().create_timer(fire_pillar_duration + fire_pillar_activation_delay).timeout
	fire_pillar_casts_active = max(0, fire_pillar_casts_active - 1)
	power_cooldown_left = cooldown

func _get_power_box_size(scene: PackedScene) -> Vector3:
	if scene == null:
		return Vector3.ONE
	var instance = scene.instantiate() as Area3D
	if instance == null:
		return Vector3.ONE
	var shape = instance.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var size = Vector3.ONE
	if shape != null and shape.shape is BoxShape3D:
		size = shape.shape.size
	instance.queue_free()
	return size

func _physics_process(delta: float) -> void:
	# Gamepad movement vector (deadzone handled)
	var input_vec: Vector2 = input_vector

	# Convert to 3D direction on the XZ plane
	var direction := Vector3(input_vec.x, 0.0, input_vec.y)

	if dash_cooldown_left > 0.0:
		dash_cooldown_left = max(0.0, dash_cooldown_left - delta)

	if slap_cooldown_left > 0.0:
		slap_cooldown_left = max(0.0, slap_cooldown_left - delta)

	if power_cooldown_left > 0.0:
		power_cooldown_left = max(0.0, power_cooldown_left - delta)

	if attack_time_left > 0.0:
		attack_time_left = max(0.0, attack_time_left - delta)

	if stun_time_left > 0.0:
		stun_time_left = max(0.0, stun_time_left - delta)
		knockback_velocity = knockback_velocity.move_toward(Vector3.ZERO, slap_knockback_decay * delta)
	if is_dead:
		target_velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		move_and_slide()
		return

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
			_play_dash_sound()

	if action_triggered:
		if not has_mask and slap_time_left <= 0.0 and slap_cooldown_left <= 0.0:
			slap_time_left = slap_duration
			slap_cooldown_left = slap_cooldown
			slap_basis = $Pivot.global_basis
			slap_position = $Pivot.global_position + (slap_basis * slap_offset)
			_play_animation("Slap")
		elif has_mask and power_cooldown_left <= 0.0:
			var attack_duration = slap_duration
			if attack_animation_length > 0.0:
				attack_duration = attack_animation_length
			attack_time_left = max(attack_time_left, attack_duration)
			_play_animation("Attack")
			call_deferred("_use_power")


	dash_triggered = false
	action_triggered = false


	if dash_invulnerable_left > 0.0:
		dash_invulnerable_left = max(0.0, dash_invulnerable_left - delta)
	if hurt_invulnerable_left > 0.0:
		hurt_invulnerable_left = max(0.0, hurt_invulnerable_left - delta)
	is_invulnerable = dash_invulnerable_left > 0.0 or hurt_invulnerable_left > 0.0

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

	_update_animation_state(direction)
	_update_step_audio(direction, delta)

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
		if wind_pull_velocity.length() > 0.0:
			velocity.x += wind_pull_velocity.x
			velocity.z += wind_pull_velocity.z
		wind_pull_velocity = Vector3.ZERO
		move_and_slide()

func _update_animation_state(direction: Vector3) -> void:
	if animation_playback == null:
		return
	if is_dead or is_respawning:
		_play_animation("Die")
		return
	if dash_time_left > 0.0:
		_play_animation("Dash")
		return
	if attack_time_left > 0.0:
		_play_animation("Attack")
		return
	if slap_time_left > 0.0:
		_play_animation("Slap")
		return
	if stun_time_left > 0.0:
		_play_animation("Damage")
		return
	if direction.length() > 0.1:
		_play_animation("Running")
	else:
		_play_animation("Idle")
