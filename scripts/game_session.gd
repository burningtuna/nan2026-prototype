extends Node

const LOADOUT_SAVE_PATH := "user://last_loadout.json"
const STORY_PROGRESS_PATH := "user://story_progress.json"
const ENDLESS_PROGRESS_PATH := "user://endless_progress.json"
const LOADOUT_SCHEMA_VERSION := 1
const PROGRESS_SCHEMA_VERSION := 1

enum GameMode {
	STORY,
	SKIRMISH,
	ENDLESS,
}
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
var story_progress_path := STORY_PROGRESS_PATH
var endless_progress_path := ENDLESS_PROGRESS_PATH
var selected_game_mode := GameMode.SKIRMISH
var story_deployment_scene_path := ""
var endless_player_balance_enabled := true
var endless_missile_reload_multiplier := 0.2
var endless_other_reload_multiplier := 0.0
var endless_player_damage_multiplier := 0.2
var endless_intro_shown := false
var story_progress: Dictionary = {}


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


func load_endless_high_score() -> int:
	var document := _load_progress_document(endless_progress_path)
	return maxi(int(document.get("high_score", 0)), 0)


func submit_endless_score(score: int) -> int:
	var previous_high_score := load_endless_high_score()
	var high_score := maxi(previous_high_score, maxi(score, 0))
	if high_score == previous_high_score:
		return high_score
	return high_score if _save_progress_document(endless_progress_path, {"high_score": high_score}) else previous_high_score


func delete_story_progress() -> bool:
	story_progress.clear()
	return _delete_progress_file(story_progress_path)


func load_story_progress() -> Dictionary:
	story_progress = _load_progress_document(story_progress_path)
	story_progress.erase("schema_version")
	return story_progress.duplicate(true)


func story_flag(key: StringName, default_value = false):
	if story_progress.is_empty() and FileAccess.file_exists(story_progress_path):
		load_story_progress()
	var flags: Dictionary = story_progress.get("flags", {})
	return flags.get(String(key), default_value)


func set_story_flag(key: StringName, value) -> bool:
	if story_progress.is_empty() and FileAccess.file_exists(story_progress_path):
		load_story_progress()
	var flags: Dictionary = story_progress.get("flags", {}).duplicate(true)
	flags[String(key)] = value
	story_progress["flags"] = flags
	return _save_progress_document(story_progress_path, story_progress)


func delete_endless_score() -> bool:
	return _delete_progress_file(endless_progress_path)


func _load_progress_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	var document: Dictionary = parser.data
	return document if int(document.get("schema_version", 0)) == PROGRESS_SCHEMA_VERSION else {}


func _save_progress_document(path: String, values: Dictionary) -> bool:
	var document := values.duplicate()
	document["schema_version"] = PROGRESS_SCHEMA_VERSION
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null:
		push_warning("Unable to save progress: %s" % error_string(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(document))
	file.flush()
	file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary_path := ProjectSettings.globalize_path(temporary_path)
	var absolute_backup_path := ProjectSettings.globalize_path(path + ".bak")
	DirAccess.remove_absolute(absolute_backup_path)
	if FileAccess.file_exists(path):
		var backup_error := DirAccess.rename_absolute(absolute_path, absolute_backup_path)
		if backup_error != OK:
			DirAccess.remove_absolute(absolute_temporary_path)
			return false
	var rename_error := DirAccess.rename_absolute(absolute_temporary_path, absolute_path)
	if rename_error != OK:
		DirAccess.remove_absolute(absolute_temporary_path)
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.rename_absolute(absolute_backup_path, absolute_path)
		return false
	DirAccess.remove_absolute(absolute_backup_path)
	return true


func _delete_progress_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK
