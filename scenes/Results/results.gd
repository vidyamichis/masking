extends Control

@onready var scoreboard_container = $VBoxContainer/Scoreboard as VBoxContainer
@onready var winner_label = $VBoxContainer/Winner as Label
@onready var return_button = $VBoxContainer/ReturnButton as Button

func _ready() -> void:
	if return_button != null:
		return_button.pressed.connect(_on_return_pressed)
	_render_results()

func _render_results() -> void:
	if scoreboard_container == null:
		return
	for child in scoreboard_container.get_children():
		child.queue_free()
	var results = Match.last_results.duplicate(true)
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("kills", 0)) > int(b.get("kills", 0))
	)
	if winner_label != null:
		if results.is_empty():
			winner_label.text = "Ganador: -"
		else:
			var top_player = results[0].get("player_index", 1)
			winner_label.text = "Ganador: Player %d" % int(top_player)
	for entry in results:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		var name_label = Label.new()
		name_label.text = "Player %d" % int(entry.get("player_index", 0))
		row.add_child(name_label)
		var kills_label = Label.new()
		kills_label.text = "Kills: %d" % int(entry.get("kills", 0))
		row.add_child(kills_label)
		var deaths_label = Label.new()
		deaths_label.text = "Muertes: %d" % int(entry.get("deaths", 0))
		row.add_child(deaths_label)
		scoreboard_container.add_child(row)

func _on_return_pressed() -> void:
	Match.last_results.clear()
	Lobby.joined_devices.clear()
	Match.assign_powers_to_masks()
	get_tree().change_scene_to_file("res://scenes/JoinMenu/JoinMenu.tscn")
