class_name StoryMission
extends "res://scripts/story_combat_test.gd"

const STAGE_SELECT_PATH := "res://scenes/story_stage_select.tscn"
const STORY_HANGAR_PATH := "res://scenes/hangar_screen.tscn"
const RESULT_DELAY_SECONDS := 2.5
const FAILURE_RESTART_SMOKE_STATE := &"story_failure_restart_smoke_state"

@export var finish_from_team_result := true
@export_file("*.tscn") var next_story_stage_path := ""

var mission_finished := false


func _on_combat_bound() -> void:
	super._on_combat_bound()
	if finish_from_team_result and not battle.battle_finished.is_connected(_on_story_battle_finished):
		battle.battle_finished.connect(_on_story_battle_finished)
	if OS.get_cmdline_user_args().has("--story-failure-restart-smoke"):
		call_deferred("_run_failure_restart_smoke")


func finish_mission(success: bool, message := "") -> void:
	if mission_finished:
		return
	mission_finished = true
	if success and not next_story_stage_path.is_empty():
		_prepare_story_continuation(next_story_stage_path)
	if not message.is_empty():
		system_messages.push_message(message)
	if success:
		overlay.show_result_message("STAGE CLEAR")
	else:
		overlay.show_result_message("MISSION FAILED")
	if _is_smoke_test():
		return
	await get_tree().create_timer(RESULT_DELAY_SECONDS).timeout
	SceneTransition.transition_to(_mission_transition_path(success))


func _on_story_battle_finished(winner_team_id: int) -> void:
	finish_mission(winner_team_id == 0, "MISSION COMPLETE" if winner_team_id == 0 else "MISSION FAILED")


func _mission_transition_path(success: bool) -> String:
	if not success:
		var current_stage_path := _current_story_stage_path()
		return current_stage_path if not current_stage_path.is_empty() else STAGE_SELECT_PATH
	return STORY_HANGAR_PATH if not next_story_stage_path.is_empty() else STAGE_SELECT_PATH


func _current_story_stage_path() -> String:
	var current_scene := get_tree().current_scene
	if current_scene == null or not GameSession.is_story_stage_path(current_scene.scene_file_path):
		return ""
	return current_scene.scene_file_path


func _run_failure_restart_smoke() -> void:
	var current_stage_path := _current_story_stage_path()
	assert(not current_stage_path.is_empty())
	if GameSession.has_meta(FAILURE_RESTART_SMOKE_STATE):
		var previous_state: Dictionary = GameSession.get_meta(FAILURE_RESTART_SMOKE_STATE)
		GameSession.remove_meta(FAILURE_RESTART_SMOKE_STATE)
		assert(current_stage_path == str(previous_state["scene_path"]))
		assert(get_instance_id() != int(previous_state["instance_id"]))
		assert(not mission_finished)
		print("STORY_FAILURE_RESTART_CHECK passed")
		get_tree().quit(0)
		return
	GameSession.set_meta(FAILURE_RESTART_SMOKE_STATE, {
		"scene_path": current_stage_path,
		"instance_id": get_instance_id(),
	})
	finish_mission(false, "MISSION FAILED // RESTART SMOKE")
	assert(mission_finished)
	assert(_mission_transition_path(false) == current_stage_path)
	var error := SceneTransition.transition_to(current_stage_path)
	if error != OK:
		GameSession.remove_meta(FAILURE_RESTART_SMOKE_STATE)
	assert(error == OK, "Unable to restart story stage: %s" % error_string(error))


func _prepare_story_continuation(stage_path: String) -> void:
	GameSession.selected_game_mode = GameSession.GameMode.STORY
	GameSession.story_deployment_scene_path = stage_path
	GameSession.story_stage_selected_directly = false


func _is_smoke_test() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.ends_with("-smoke"):
			return true
	return false
