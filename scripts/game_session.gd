extends Node

const LOADOUT_SAVE_PATH := "user://last_loadout.json"
const LOADOUT_SCHEMA_VERSION := 1
const SLOT_CONFIG := {
	"head": [MechLoadout.MechSlot.HEAD, MechPartSpec.PartType.HEAD],
	"body": [MechLoadout.MechSlot.BODY, MechPartSpec.PartType.BODY],
	"left_arm": [MechLoadout.MechSlot.LEFT_ARM, MechPartSpec.PartType.ARM_EQUIPMENT],
	"right_arm": [MechLoadout.MechSlot.RIGHT_ARM, MechPartSpec.PartType.ARM_EQUIPMENT],
	"backpack": [MechLoadout.MechSlot.BACKPACK, MechPartSpec.PartType.BACKPACK],
	"legs": [MechLoadout.MechSlot.LEGS, MechPartSpec.PartType.LEGS],
}

var player_mech_loadout: MechLoadout
var loadout_save_path := LOADOUT_SAVE_PATH


func confirm_player_loadout(loadout: MechLoadout) -> void:
	assert(loadout != null and loadout.is_valid())
	player_mech_loadout = loadout.copy()
	_save_player_loadout(player_mech_loadout)


func load_saved_player_loadout(part_catalog: MechPartCatalog) -> MechLoadout:
	if player_mech_loadout != null:
		return player_mech_loadout.copy()
	if part_catalog == null or not FileAccess.file_exists(loadout_save_path):
		return null

	var file := FileAccess.open(loadout_save_path, FileAccess.READ)
	if file == null:
		push_warning("Unable to read saved loadout: %s" % error_string(FileAccess.get_open_error()))
		return null
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	if error != OK or not parser.data is Dictionary:
		push_warning("Ignoring invalid saved loadout")
		return null
	var document: Dictionary = parser.data
	if int(document.get("schema_version", 0)) != LOADOUT_SCHEMA_VERSION:
		return null
	var part_ids = document.get("parts")
	if not part_ids is Dictionary:
		return null

	var loadout := MechLoadout.new()
	for key in SLOT_CONFIG:
		var part_id_value = part_ids.get(key)
		if part_id_value == null:
			continue
		var part := part_catalog.parts_by_id.get(str(part_id_value)) as MechPartSpec
		var expected_type: MechPartSpec.PartType = SLOT_CONFIG[key][1]
		if part == null or part.part_type != expected_type:
			push_warning("Ignoring saved loadout with unknown part '%s'" % part_id_value)
			return null
		var slot: MechLoadout.MechSlot = SLOT_CONFIG[key][0]
		loadout.set_part(slot, part)
	if not loadout.is_valid():
		push_warning("Ignoring saved loadout that is no longer deployable")
		return null
	player_mech_loadout = loadout.copy()
	return loadout


func _save_player_loadout(loadout: MechLoadout) -> void:
	var parts := {}
	for key in SLOT_CONFIG:
		var slot: MechLoadout.MechSlot = SLOT_CONFIG[key][0]
		var part := loadout.part_for_slot(slot)
		parts[key] = part.part_id if part != null else null
	var file := FileAccess.open(loadout_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save loadout: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({
		"schema_version": LOADOUT_SCHEMA_VERSION,
		"parts": parts,
	}))
	file.flush()
	file.close()
