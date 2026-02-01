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

var mask_power_map: Dictionary = {}

func assign_powers_to_masks() -> void:
	mask_power_map.clear()
	if Debug.force_fire_powers:
		for index in range(8):
			mask_power_map[index + 1] = PowerType.FIRE
		return
	randomize()
	var powers = [
		PowerType.FIRE,
		PowerType.ICE,
		PowerType.THUNDER,
		PowerType.WIND,
		PowerType.ROCK,
		PowerType.POISON,
		PowerType.LIGHT,
		PowerType.DARK,
	]
	powers.shuffle()
	for index in range(powers.size()):
		mask_power_map[index + 1] = powers[index]

func get_power_for_mask_id(mask_id: int) -> int:
	return mask_power_map.get(mask_id, PowerType.FIRE)
