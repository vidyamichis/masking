extends Node3D

@export var fade_duration = 1.4
@export var rise_height = 0.8

var elapsed := 0.0
var start_position := Vector3.ZERO
var mesh_instance: MeshInstance3D
var discard_material: ShaderMaterial
var source_material: StandardMaterial3D

func _ready() -> void:
	start_position = global_transform.origin
	mesh_instance = _find_mesh_instance(self)
	if mesh_instance == null:
		queue_free()
		return
	source_material = _get_base_material(mesh_instance)
	discard_material = _make_discard_material(source_material)
	discard_material.resource_local_to_scene = true
	mesh_instance.set_surface_override_material(0, discard_material)
	if source_material.albedo_texture != null:
		mesh_instance.material_override = source_material

func _process(delta: float) -> void:
	elapsed += delta
	var t = min(elapsed / fade_duration, 1.0)
	global_position = start_position + Vector3.UP * (t * rise_height)
	if discard_material != null:
		discard_material.set_shader_parameter("whiten", t)
		discard_material.set_shader_parameter("alpha", 1.0 - t)
		mesh_instance.material_override = discard_material
	if t >= 1.0:
		queue_free()

func _get_base_material(target_mesh: MeshInstance3D) -> StandardMaterial3D:
	var material = target_mesh.get_active_material(0)
	if material is StandardMaterial3D:
		return material
	return StandardMaterial3D.new()

func _make_discard_material(original: StandardMaterial3D) -> ShaderMaterial:
	var shader = Shader.new()
	shader.code = """
		shader_type spatial;
		uniform sampler2D mask_texture : source_color;
		uniform float whiten : hint_range(0.0, 1.0);
		uniform float alpha : hint_range(0.0, 1.0) = 1.0;
		void fragment() {
			vec4 tex_color = texture(mask_texture, UV);
			vec3 base = mix(tex_color.rgb, vec3(1.0), whiten);
		ALBEDO = base;
		ALPHA = tex_color.a * alpha;

		}
	"""
	var material = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("whiten", 0.0)
	material.set_shader_parameter("alpha", 1.0)
	material.set_shader_parameter("mask_texture", original.albedo_texture)
	material.render_priority = original.render_priority
	material.set_meta("requires_blend", true)
	return material

func _find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node
	for child in node.get_children():
		var found = _find_mesh_instance(child)
		if found != null:
			return found
	return null
