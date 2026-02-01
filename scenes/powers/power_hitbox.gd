extends Area3D

@export var active_duration = 0.2
@export var activation_delay = 0.0

signal hit(body: Node3D)

var time_left := 0.0
var delay_left := 0.0
var debug_mesh: MeshInstance3D

func _ready() -> void:
	monitoring = false
	monitorable = true
	body_entered.connect(_on_body_entered)
	_setup_debug_mesh()

func activate(spawn_basis: Basis, spawn_position: Vector3, target_mask: int) -> void:
	global_basis = spawn_basis
	global_position = spawn_position
	collision_mask = target_mask
	time_left = active_duration
	delay_left = activation_delay
	monitoring = activation_delay <= 0.0
	_update_debug()

func _process(delta: float) -> void:
	if time_left <= 0.0:
		return
	if delay_left > 0.0:
		delay_left = max(0.0, delay_left - delta)
		if delay_left <= 0.0:
			monitoring = true
			_update_debug()
		return
	time_left = max(0.0, time_left - delta)
	if time_left <= 0.0:
		monitoring = false
		_update_debug()
		queue_free()
		return
	_update_debug()

func _on_body_entered(body: Node3D) -> void:
	if body == null or body == self:
		return
	if body.has_method("apply_power"):
		body.apply_power(global_position)
	hit.emit(body)

func _setup_debug_mesh() -> void:
	var shape = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is BoxShape3D:
		debug_mesh = MeshInstance3D.new()
		debug_mesh.mesh = BoxMesh.new()
		debug_mesh.mesh.size = shape.shape.size
		debug_mesh.visible = false
		add_child(debug_mesh)

func _update_debug() -> void:
	if debug_mesh == null:
		return
	debug_mesh.visible = Debug.show_hitboxes and monitoring
