extends Area3D

@export var float_height = 0.15
@export var float_speed = 2.5
@export var rotate_speed = 2.0
@export var lifetime = 0.0
@export var target_collision_mask = 2
@export var float_offset = Vector3(0.0, 1.0, 0.0)
@export var spawn_duration = 0.6
@export var spawn_rise = 0.6
@export var mask_id = 0

var elapsed := 0.0
var spawn_elapsed := 0.0
var spawn_position := Vector3.ZERO
var spawn_position_set := false
var is_picked_up := false
var is_spawning := true
var mesh_instance: MeshInstance3D
var spawn_material: ShaderMaterial
var base_material: StandardMaterial3D
var drop_velocity := Vector3.ZERO
var drop_decay = 0.0
var pickup_locked := false

func _ready() -> void:
	monitoring = true
	collision_mask = target_collision_mask
	body_entered.connect(_on_body_entered)
	mesh_instance = _find_mesh_instance(self)
	if mesh_instance != null:
		base_material = _get_base_material(mesh_instance)
		spawn_material = _make_spawn_material(base_material)
		spawn_material.resource_local_to_scene = true
		mesh_instance.material_override = spawn_material

func _process(delta: float) -> void:
	if is_picked_up:
		return
	if not spawn_position_set:
		spawn_position = global_position + float_offset
		global_position = spawn_position - Vector3.UP * spawn_rise
		spawn_position_set = true
	if is_spawning:
		spawn_elapsed += delta
		var t = min(spawn_elapsed / spawn_duration, 1.0)
		global_position = spawn_position - Vector3.UP * (spawn_rise * (1.0 - t))
		_update_spawn_material(t)
		if t >= 1.0:
			is_spawning = false
			if mesh_instance != null:
				mesh_instance.material_override = base_material
			spawn_material = null
		else:
			return
	if drop_velocity.length() > 0.0:
		spawn_position += drop_velocity * delta
		drop_velocity = drop_velocity.move_toward(Vector3.ZERO, drop_decay * delta)
		if drop_velocity.length() <= 0.01:
			drop_velocity = Vector3.ZERO
			pickup_locked = false

	elapsed += delta
	global_position = spawn_position + Vector3.UP * sin(elapsed * float_speed) * float_height
	rotate_y(rotate_speed * delta)
	if lifetime > 0.0 and elapsed >= lifetime:
		banish()

func _on_body_entered(body: Node3D) -> void:
	if is_picked_up or pickup_locked:
		return
	if body.has_method("equip_mask"):
		var spawner = get_meta("spawner")
		if spawner != null and spawner.has_method("on_mask_picked"):
			spawner.on_mask_picked(self)
		if mesh_instance != null:
			mesh_instance.material_override = base_material
		spawn_material = null
		body.call_deferred("equip_mask", self)
		return


func mark_picked() -> void:
	is_picked_up = true
	set_deferred("monitoring", false)

func banish() -> void:
	if is_picked_up:
		return
	mark_picked()
	var parent_spawner = get_meta("spawner")
	if parent_spawner != null and parent_spawner.has_method("on_mask_banished"):
		parent_spawner.on_mask_banished(self)
	queue_free()

func reset_spawn(new_position: Vector3) -> void:
	spawn_position = new_position + float_offset
	spawn_position_set = true
	is_spawning = true
	spawn_elapsed = 0.0
	elapsed = 0.0
	global_position = spawn_position - Vector3.UP * spawn_rise
	if mesh_instance != null:
		base_material = _get_base_material(mesh_instance)
		spawn_material = _make_spawn_material(base_material)
		spawn_material.resource_local_to_scene = true
		mesh_instance.material_override = spawn_material
	set_deferred("monitoring", true)
	is_picked_up = false
	pickup_locked = false
	drop_velocity = Vector3.ZERO
	drop_decay = 0.0

func apply_drop_velocity(velocity: Vector3, decay: float) -> void:
	drop_velocity = velocity
	drop_decay = decay

func drop_from_hit(origin_position: Vector3, hit_direction: Vector3, knockback: float, drop_distance_factor: float, drop_height: float, drop_angle_deg: float, drop_decay_value: float, strength: float) -> void:
	pickup_locked = true
	is_spawning = false
	spawn_elapsed = 0.0
	var world_scene = get_tree().current_scene
	if world_scene == null:
		return
	var angle = deg_to_rad(drop_angle_deg)
	if randf() < 0.5:
		angle = -angle
	var drop_direction = hit_direction.rotated(Vector3.UP, angle).normalized()
	var start_position = origin_position + Vector3.UP * drop_height
	var drop_distance = max(knockback * drop_distance_factor * strength, 0.0)
	var drop_speed = 0.0
	if drop_distance > 0.0:
		drop_speed = sqrt(2.0 * drop_decay_value * drop_distance)
	var drop_velocity_value = drop_direction * drop_speed
	var current_parent = get_parent()
	if current_parent != null:
		current_parent.call_deferred("remove_child", self)
	world_scene.call_deferred("add_child", self)
	call_deferred("set", "global_position", start_position)
	call_deferred("set", "global_basis", Basis.IDENTITY)
	spawn_position = start_position + float_offset
	spawn_position_set = true
	is_spawning = false
	spawn_material = null
	elapsed = 0.0
	is_picked_up = false
	set_deferred("monitoring", true)
	apply_drop_velocity(drop_velocity_value, drop_decay_value)
	pickup_locked = drop_velocity_value.length() > 0.1
	if mesh_instance != null:
		mesh_instance.material_override = base_material

func _get_base_material(target_mesh: MeshInstance3D) -> StandardMaterial3D:
	var material = target_mesh.get_active_material(0)
	if material is StandardMaterial3D:
		return material
	return StandardMaterial3D.new()

func _make_spawn_material(original: StandardMaterial3D) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
		shader_type spatial;
		uniform sampler2D mask_texture : source_color;
		uniform float whiten : hint_range(0.0, 1.0) = 1.0;
		uniform float alpha : hint_range(0.0, 1.0) = 0.0;
		void fragment() {
			vec4 tex_color = texture(mask_texture, UV);
			vec3 base = mix(tex_color.rgb, vec3(1.0), whiten);
			ALBEDO = base;
			ALPHA = tex_color.a * alpha;
		}
	"""
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("whiten", 1.0)
	material.set_shader_parameter("alpha", 0.0)
	material.set_shader_parameter("mask_texture", original.albedo_texture)
	material.render_priority = original.render_priority
	return material

func _update_spawn_material(t: float) -> void:
	if spawn_material == null:
		return
	spawn_material.set_shader_parameter("whiten", 1.0 - t)
	spawn_material.set_shader_parameter("alpha", t)

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found != null:
			return found
	return null
