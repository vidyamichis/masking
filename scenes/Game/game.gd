extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/Player/Player.tscn")
@export var max_players = 4
@export var player_shadow_radius = 0.7
@export var player_shadow_height = 0.05
@export var player_shadow_offset = 0.02
@export var player_shadow_alpha = 0.65

var players: Array[Node3D] = []
var spawn_points: Array[Node3D] = []
var player_shadows: Dictionary = {}

@onready var music_player = $Music as AudioStreamPlayer

func _enter_tree() -> void:
	Match.assign_powers_to_masks()

func _ready() -> void:
	_ensure_music_looping()
	spawn_points = _get_spawn_points()
	_spawn_players()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_assign_devices()

func _spawn_players() -> void:
	_clear_players()
	var devices = _get_devices_for_match()
	var count = min(max_players, spawn_points.size(), devices.size())
	_clear_player_shadows()
	for index in range(count):
		var player = player_scene.instantiate() as Node3D
		add_child(player)
		var spawn_transform = spawn_points[index].global_transform
		player.global_transform = spawn_transform
		if player.has_method("set_spawn_point"):
			player.set_spawn_point(spawn_transform.origin, spawn_transform.basis)
		if player.has_method("set_input_device"):
			player.set_input_device(devices[index])
		player.add_to_group("players")
		players.append(player)
		_spawn_player_shadow(player, index)
	var mask_spawner = get_node_or_null("MaskSpawner")
	if mask_spawner != null and mask_spawner.has_method("set_desired_spawn_count"):
		mask_spawner.set_desired_spawn_count(count)

func _assign_devices() -> void:
	if players.is_empty():
		return
	var devices = _get_devices_for_match()
	for index in range(players.size()):
		var device = devices[index] if index < devices.size() else -1
		players[index].set_input_device(device)

func _clear_players() -> void:
	for player in players:
		player.queue_free()
	players.clear()
	_clear_player_shadows()

func _get_devices_for_match() -> Array:
	var devices: Array = Lobby.get_joined_devices()
	if devices.is_empty():
		devices = Input.get_connected_joypads()
	if Debug.force_extra_players:
		while devices.size() < max_players:
			devices.append(-1)
	return devices

func _get_spawn_points() -> Array[Node3D]:
	var found: Array[Node3D] = []
	var container = get_node_or_null("PlayerSpawns")
	if container == null:
		return found
	var indexed: Dictionary = {}
	var extras: Array[Node3D] = []
	for child in container.get_children():
		if child is Node3D:
			var index = _extract_trailing_index(child.name)
			if index > 0:
				indexed[index] = child
			else:
				extras.append(child)
	var max_index = 0
	for index in indexed.keys():
		max_index = max(max_index, int(index))
	for index in range(1, max_index + 1):
		if indexed.has(index):
			found.append(indexed[index])
	found.append_array(extras)
	return found

func _spawn_player_shadow(player: Node3D, index: int) -> void:
	var mesh_instance = MeshInstance3D.new()
	var mesh = CylinderMesh.new()
	mesh.top_radius = player_shadow_radius
	mesh.bottom_radius = player_shadow_radius
	mesh.height = player_shadow_height
	mesh.radial_segments = 32
	mesh_instance.mesh = mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = _get_player_shadow_color(index)
	material.albedo_color.a = player_shadow_alpha
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	add_child(mesh_instance)
	var offset = Vector3(0.0, player_shadow_offset, 0.0)
	mesh_instance.global_position = player.global_position + offset
	mesh_instance.global_basis = player.global_basis
	player_shadows[player] = mesh_instance

func _get_player_shadow_color(index: int) -> Color:
	match index:
		0:
			return Color(1.0, 0.0, 0.0)
		1:
			return Color(0.0, 1.0, 0.0)
		2:
			return Color(0.0, 0.0, 1.0)
		3:
			return Color(1.0, 1.0, 0.0)
	return Color(1.0, 1.0, 1.0)

func _clear_player_shadows() -> void:
	for shadow in player_shadows.values():
		if shadow != null:
			shadow.queue_free()
	player_shadows.clear()

func _process(_delta: float) -> void:
	for player in player_shadows.keys():
		if player == null or not is_instance_valid(player):
			continue
		var shadow = player_shadows[player] as MeshInstance3D
		if shadow == null:
			continue
		shadow.global_position = player.global_position + Vector3(0.0, player_shadow_offset, 0.0)
		shadow.global_basis = player.global_basis

func _extract_trailing_index(name: String) -> int:
	var digits := ""
	for index in range(name.length() - 1, -1, -1):
		var character = name[index]
		if character >= "0" and character <= "9":
			digits = character + digits
			continue
		break
	if digits.is_empty():
		return -1
	return int(digits)

func _ensure_music_looping() -> void:
	if music_player == null:
		return
	if music_player.stream == null:
		return
	if music_player.stream is AudioStreamOggVorbis:
		var ogg_stream = music_player.stream as AudioStreamOggVorbis
		ogg_stream.loop = true
		ogg_stream.loop_offset = 0.0
