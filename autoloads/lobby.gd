extends Node

var joined_devices: Array[int] = []

func join_device(device: int) -> void:
	if device in joined_devices:
		return
	joined_devices.append(device)
	joined_devices.sort()

func leave_device(device: int) -> void:
	joined_devices.erase(device)

func clear_devices() -> void:
	joined_devices.clear()

func get_joined_devices() -> Array:
	return joined_devices.duplicate()
