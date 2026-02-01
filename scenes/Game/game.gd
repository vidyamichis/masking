extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/Player/Player.tscn")
@export var max_players = 4

var players: Array[Node3D] = []
var spawn_points: Array[Node3D] = []

@onready var music_player = $Music as AudioStreamPlayer

func _ready() -> void:
	Match.assign_powers_to_masks()
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
	for index in range(count):
		var player = player_scene.instantiate() as Node3D
		add_child(player)
		player.global_transform = spawn_points[index].global_transform
		if player.has_method("set_input_device"):
			player.set_input_device(devices[index])
		player.add_to_group("players")
		players.append(player)

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

func _get_devices_for_match() -> Array:
	var devices: Array = Lobby.get_joined_devices()
	if devices.is_empty():
		devices = Input.get_connected_joypads()
	devices.sort()
	if Debug.force_extra_players:
		while devices.size() < max_players:
			devices.append(-1)
	return devices

func _get_spawn_points() -> Array[Node3D]:
	var found: Array[Node3D] = []
	var container = get_node_or_null("PlayerSpawns")
	if container == null:
		return found
	for child in container.get_children():
		if child is Node3D:
			found.append(child)
	found.sort_custom(func(a, b): return a.name < b.name)
	return found

func _ensure_music_looping() -> void:
	if music_player == null:
		return
	if music_player.stream == null:
		return
	if music_player.stream is AudioStreamOggVorbis:
		var ogg_stream = music_player.stream as AudioStreamOggVorbis
		ogg_stream.loop = true
		ogg_stream.loop_offset = 0.0
