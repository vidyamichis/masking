extends Node

enum PowerType {
	FIRE,
	ICE,
	THUNDER,
	WIND,
	ROCK,
	POISON,
	LIGHT,
	DARK,
}

const MAX_MASKS := 8

@export var enabled_powers: Array[PowerType] = [
	PowerType.FIRE,
	PowerType.ICE,
	PowerType.THUNDER,
	PowerType.WIND,
	PowerType.ROCK,
]

var mask_power_map: Dictionary = {}
var enabled_mask_ids: Array[int] = []
var last_results: Array[Dictionary] = []

func assign_powers_to_masks() -> void:
	mask_power_map.clear()
	enabled_mask_ids.clear()
	if Debug.force_fire_powers:
		for index in range(MAX_MASKS):
			mask_power_map[index + 1] = PowerType.FIRE
			enabled_mask_ids.append(index + 1)
		return
	if Debug.force_ice_powers:
		for index in range(MAX_MASKS):
			mask_power_map[index + 1] = PowerType.ICE
			enabled_mask_ids.append(index + 1)
		return
	if Debug.force_wind_powers:
		for index in range(MAX_MASKS):
			mask_power_map[index + 1] = PowerType.WIND
			enabled_mask_ids.append(index + 1)
		return
	if Debug.force_thunder_powers:
		for index in range(MAX_MASKS):
			mask_power_map[index + 1] = PowerType.THUNDER
			enabled_mask_ids.append(index + 1)
		return
	if Debug.force_rock_powers:
		for index in range(MAX_MASKS):
			mask_power_map[index + 1] = PowerType.ROCK
			enabled_mask_ids.append(index + 1)
		return
	randomize()
	var powers = enabled_powers.duplicate()
	if powers.is_empty():
		powers = [
			PowerType.FIRE,
			PowerType.ICE,
			PowerType.THUNDER,
			PowerType.WIND,
			PowerType.ROCK,
		]
	powers.shuffle()
	var mask_ids: Array[int] = []
	for index in range(MAX_MASKS):
		mask_ids.append(index + 1)
	mask_ids.shuffle()
	var selected_masks = mask_ids.slice(0, powers.size())
	for index in range(powers.size()):
		mask_power_map[selected_masks[index]] = powers[index]
		enabled_mask_ids.append(selected_masks[index])

func get_power_for_mask_id(mask_id: int) -> int:
	return mask_power_map.get(mask_id, PowerType.FIRE)

func store_results(results: Array[Dictionary]) -> void:
	last_results = results.duplicate(true)
