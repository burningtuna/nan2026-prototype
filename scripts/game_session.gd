extends Node

var player_mech_loadout: MechLoadout


func confirm_player_loadout(loadout: MechLoadout) -> void:
	assert(loadout != null and loadout.is_valid())
	player_mech_loadout = loadout.copy()
