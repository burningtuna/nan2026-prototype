extends SceneTree

const TEST_PATH := "/tmp/opencode/nan2026_loadout_test.json"


func _initialize() -> void:
	var catalog := MechPartCatalog.new()
	assert(catalog.load_file("res://data/mech_parts.json"))
	var session = load("res://scripts/game_session.gd").new()
	var loadout := catalog.create_default_loadout()
	loadout.head = catalog.parts_by_id["bastion_array"]
	loadout.body = catalog.parts_by_id["bulwark_core"]
	loadout.legs = catalog.parts_by_id["anvil_legs"]
	loadout.right_arm = catalog.parts_by_id["viper_rotary_arm"]
	assert(loadout.is_valid())

	session.loadout_save_path = TEST_PATH
	session.confirm_player_loadout(loadout)
	assert(FileAccess.file_exists(TEST_PATH))
	session.player_mech_loadout = null
	var restored = session.load_saved_player_loadout(catalog)
	assert(restored != null)
	assert(restored.head.part_id == "bastion_array")
	assert(restored.body.part_id == "bulwark_core")
	assert(restored.legs.part_id == "anvil_legs")
	assert(restored.right_arm.part_id == "viper_rotary_arm")

	DirAccess.remove_absolute(TEST_PATH)
	session.free()
	restored = null
	loadout = null
	catalog = null
	print("LOADOUT_PERSISTENCE_CHECK passed")
	quit(0)
