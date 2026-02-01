# Archivo: lobby.gd
extends Node

# Esta lista guarda quiénes están conectados (ej: [0, 1] son dos joysticks)
var joined_devices: Array = []

# Pregunta: ¿Este control ya está unido?
func is_device_joined(device_id: int) -> bool:
	return device_id in joined_devices

# Acción: Unir un control a la lista
func join_device(device_id: int) -> void:
	if not is_device_joined(device_id):
		joined_devices.append(device_id)
		print("Se unió el dispositivo: ", device_id)

# Acción: Sacar un control de la lista
func leave_device(device_id: int) -> void:
	if is_device_joined(device_id):
		joined_devices.erase(device_id)
		print("Salió el dispositivo: ", device_id)

# Pregunta: Dame la lista completa de jugadores
func get_joined_devices() -> Array:
	return joined_devices
