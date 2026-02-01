extends Node3D

@export var player_scene: PackedScene = preload("res://scenes/Player/Player.tscn")
@export var max_players = 4
@export var player_shadow_radius = 0.7
@export var player_shadow_height = 0.05
@export var player_shadow_offset = 0.02
@export var player_shadow_alpha = 0.65
@export var match_duration_seconds = 180.0
@export var countdown_seconds = 3
@export var results_delay_seconds = 5.0

const MASK_TEXTURES = {
	1: preload("res://resources/masks/1.png"),
	2: preload("res://resources/masks/2.png"),
	3: preload("res://resources/masks/3.png"),
	4: preload("res://resources/masks/4.png"),
	5: preload("res://resources/masks/5.png"),
	6: preload("res://resources/masks/6.png"),
	7: preload("res://resources/masks/7.png"),
	8: preload("res://resources/masks/8.png"),
}

var players: Array[Node3D] = []
var spawn_points: Array[Node3D] = []
var player_shadows: Dictionary = {}
var player_indices: Dictionary = {}
var player_status_rows: Array[Dictionary] = []
var match_time_left = 0.0

const PLAYER_COLORS = [
	Color(1.0, 0.2, 0.2),
	Color(0.2, 0.4, 1.0),
	Color(0.2, 1.0, 0.4),
	Color(1.0, 0.9, 0.2),
]

const PLAYER_POSITIONS = [
	"top_left",
	"top_right",
	"bottom_left",
	"bottom_right",
]
var match_active := false
var match_finished := false

@onready var music_player = $Music as AudioStreamPlayer
@onready var player_status_container = $HUD/PlayerStatusContainer as Control
@onready var countdown_label = $HUD/CountdownLabel as Label
@onready var timer_label = $HUD/TimerLabel as Label
@onready var match_end_label = $HUD/MatchEndLabel as Label

func _enter_tree() -> void:
	Match.assign_powers_to_masks()

func _ready() -> void:
	_ensure_music_looping()
	spawn_points = _get_spawn_points()
	_spawn_players()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_setup_match_state()
	_set_players_controls_enabled(false)
	await _start_countdown()
	_set_players_controls_enabled(true)

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	_assign_devices()

func _spawn_players() -> void:
	_clear_players()
	var devices = _get_devices_for_match()
	var count = min(max_players, spawn_points.size(), devices.size())
	_clear_player_shadows()
	player_indices.clear()
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
		player_indices[player] = index
		_spawn_player_shadow(player, index)
	var mask_spawner = get_node_or_null("MaskSpawner")
	if mask_spawner != null and mask_spawner.has_method("set_desired_spawn_count"):
		mask_spawner.set_desired_spawn_count(count)
	_setup_player_status_rows()

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
	player_indices.clear()

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

func _process(delta: float) -> void:
	for player in player_shadows.keys():
		if player == null or not is_instance_valid(player):
			continue
		var shadow = player_shadows[player] as MeshInstance3D
		if shadow == null:
			continue
		shadow.global_position = player.global_position + Vector3(0.0, player_shadow_offset, 0.0)
		shadow.global_basis = player.global_basis
	_update_match_timer(delta)
	_update_player_status_rows()

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

func _setup_match_state() -> void:
	match_time_left = max(0.0, match_duration_seconds)
	match_active = false
	match_finished = false
	if timer_label != null:
		timer_label.text = _format_time(match_time_left)
	if match_end_label != null:
		match_end_label.visible = false
	if countdown_label != null:
		countdown_label.visible = false

func _setup_player_status_rows() -> void:
	player_status_rows.clear()
	if player_status_container == null:
		return
	for child in player_status_container.get_children():
		child.queue_free()
	for index in range(players.size()):
		var row = VBoxContainer.new()
		row.name = "PlayerRow%d" % (index + 1)
		row.add_theme_constant_override("separation", 6)
		row.set_anchors_preset(Control.PRESET_TOP_LEFT)
		row.position = Vector2.ZERO
		row.size = Vector2(160, 160)
		row.alignment = BoxContainer.ALIGNMENT_END if index % 2 == 1 else BoxContainer.ALIGNMENT_BEGIN

		var name_label = Label.new()
		name_label.text = "Player %d" % (index + 1)
		name_label.add_theme_font_size_override("font_size", 18)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if index % 2 == 1 else HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(name_label)

		var mask_frame = ColorRect.new()
		mask_frame.custom_minimum_size = Vector2(96, 96)
		mask_frame.color = _get_player_color(index)
		mask_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(mask_frame)

		var mask_texture = TextureRect.new()
		mask_texture.custom_minimum_size = Vector2(72, 72)
		mask_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mask_texture.visible = false
		mask_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
		mask_texture.offset_left = 0.0
		mask_texture.offset_top = 0.0
		mask_texture.offset_right = 0.0
		mask_texture.offset_bottom = 0.0
		mask_frame.add_child(mask_texture)

		var kills_label = Label.new()
		kills_label.text = "Kills: 0"
		kills_label.add_theme_font_size_override("font_size", 16)
		kills_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if index % 2 == 1 else HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(kills_label)

		var deaths_label = Label.new()
		deaths_label.text = "Muertes: 0"
		deaths_label.add_theme_font_size_override("font_size", 16)
		deaths_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if index % 2 == 1 else HORIZONTAL_ALIGNMENT_LEFT
		row.add_child(deaths_label)

		if index >= 2:
			row.move_child(mask_frame, 1)

		player_status_container.add_child(row)
		player_status_rows.append({
			"row": row,
			"mask_icon": mask_texture,
			"mask_frame": mask_frame,
			"name_label": name_label,
			"kills": kills_label,
			"deaths": deaths_label,
		})
	_update_player_status_rows()

func _update_player_status_rows() -> void:
	if player_status_rows.is_empty():
		return
	for index in range(players.size()):
		if index >= player_status_rows.size():
			continue
		var player = players[index]
		var row = player_status_rows[index]
		var mask_icon = row.get("mask_icon") as TextureRect
		var mask_frame = row.get("mask_frame") as ColorRect
		var name_label = row.get("name_label") as Label
		var kills_label = row.get("kills") as Label
		var deaths_label = row.get("deaths") as Label
		var container = row.get("row") as Control
		if container != null:
			container.position = _get_player_status_position(index)
		if player == null or not is_instance_valid(player):
			if name_label != null:
				name_label.text = "Player %d" % (index + 1)
			continue
		if name_label != null:
			name_label.text = "Player %d" % (index + 1)
		var has_mask = false
		if player.has_method("get"):
			var has_mask_value = player.get("has_mask")
			if typeof(has_mask_value) == TYPE_BOOL:
				has_mask = has_mask_value
		if mask_frame != null:
			mask_frame.color = _get_player_color(index)
		if mask_icon != null:
			mask_icon.visible = false
			mask_icon.texture = null
		if has_mask:
			var mask_id = 0
			if player.has_method("_get_equipped_mask_id"):
				mask_id = player.call("_get_equipped_mask_id")
			var texture = MASK_TEXTURES.get(mask_id, null)
			if texture != null and mask_icon != null:
				mask_icon.texture = texture
				mask_icon.visible = true
		if kills_label != null:
			var kills = 0
			if player.has_method("get"):
				var kill_value = player.get("kill_count")
				if typeof(kill_value) == TYPE_INT:
					kills = kill_value
			kills_label.text = "Kills: %d" % kills
		if deaths_label != null:
			var deaths = 0
			if player.has_method("get"):
				var death_value = player.get("death_count")
				if typeof(death_value) == TYPE_INT:
					deaths = death_value
			deaths_label.text = "Muertes: %d" % deaths


func _start_countdown() -> void:
	if countdown_label == null:
		return
	countdown_label.visible = true
	countdown_label.text = str(countdown_seconds)
	await get_tree().process_frame
	for second in range(countdown_seconds, 0, -1):
		countdown_label.text = str(second)
		await get_tree().create_timer(1.0).timeout
	countdown_label.text = "¡A pelear!"
	await get_tree().create_timer(1.0).timeout
	countdown_label.visible = false
	_start_match()

func _start_match() -> void:
	match_active = true
	match_finished = false
	match_time_left = max(0.0, match_duration_seconds)
	_update_timer_label()
	_connect_player_kills()
	_reset_match_stats()

func _update_match_timer(delta: float) -> void:
	if not match_active or match_finished:
		return
	match_time_left = max(0.0, match_time_left - delta)
	_update_timer_label()
	if match_time_left <= 0.0:
		_end_match()

func _connect_player_kills() -> void:
	for player in players:
		if player == null:
			continue
		if player.has_signal("player_killed"):
			if player.is_connected("player_killed", _on_player_killed):
				player.disconnect("player_killed", _on_player_killed)
			player.connect("player_killed", _on_player_killed)

func _reset_match_stats() -> void:
	for player in players:
		if player == null:
			continue
		if player.has_method("set"):
			player.set("kill_count", 0)
			player.set("death_count", 0)

func _on_player_killed(victim: Node3D, killer: Node3D) -> void:
	if killer == null:
		return
	if killer.has_method("get"):
		var current = killer.get("kill_count")
		if typeof(current) == TYPE_INT:
			killer.set("kill_count", current + 1)

func _update_timer_label() -> void:
	if timer_label == null:
		return
	timer_label.text = _format_time(match_time_left)

func _end_match() -> void:
	match_finished = true
	match_active = false
	if match_end_label != null:
		match_end_label.visible = true
		match_end_label.text = "¡Fin the la partida!"
	Match.store_results(_build_match_results())
	await get_tree().create_timer(results_delay_seconds).timeout
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/Results/Results.tscn")

func _build_match_results() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for index in range(players.size()):
		var player = players[index]
		if player == null:
			continue
		var kills = 0
		var deaths = 0
		if player.has_method("get"):
			var kill_value = player.get("kill_count")
			if typeof(kill_value) == TYPE_INT:
				kills = kill_value
			var death_value = player.get("death_count")
			if typeof(death_value) == TYPE_INT:
				deaths = death_value
		results.append({
			"player_index": index + 1,
			"kills": kills,
			"deaths": deaths,
		})
	return results

func _format_time(seconds: float) -> String:
	var total = int(ceil(seconds))
	var minutes = total / 60
	var remaining = total % 60
	return "%d:%02d" % [minutes, remaining]

func _get_player_color(index: int) -> Color:
	return PLAYER_COLORS[index] if index < PLAYER_COLORS.size() else Color(1.0, 1.0, 1.0)

func _get_player_status_position(index: int) -> Vector2:
	var padding = 16.0
	var bottom_padding = 32.0
	var size = get_viewport().get_visible_rect().size
	var row_size = Vector2(160, 160)
	match index:
		0:
			return Vector2(padding, padding)
		1:
			return Vector2(size.x - row_size.x - padding, padding)
		2:
			return Vector2(padding, size.y - row_size.y - bottom_padding)
		3:
			return Vector2(size.x - row_size.x - padding, size.y - row_size.y - bottom_padding)
	return Vector2(padding, padding)

func _set_players_controls_enabled(enabled: bool) -> void:
	for player in players:
		if player == null:
			continue
		if player.has_method("set_controls_enabled"):
			player.call("set_controls_enabled", enabled)
