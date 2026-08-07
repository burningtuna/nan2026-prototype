class_name StoryMission
extends "res://scripts/story_combat_test.gd"

const STAGE_SELECT_PATH := "res://scenes/story_stage_select.tscn"
const RESULT_DELAY_SECONDS := 2.5

@export var finish_from_team_result := true

var mission_finished := false


func _on_combat_bound() -> void:
	super._on_combat_bound()
	if finish_from_team_result and not battle.battle_finished.is_connected(_on_story_battle_finished):
		battle.battle_finished.connect(_on_story_battle_finished)


func finish_mission(success: bool, message := "") -> void:
	if mission_finished:
		return
	mission_finished = true
	if not message.is_empty():
		system_messages.push_message(message)
	if success:
		overlay.show_result_message("STAGE CLEAR")
	else:
		overlay.show_result_message("MISSION FAILED")
	if _is_smoke_test():
		return
	await get_tree().create_timer(RESULT_DELAY_SECONDS).timeout
	SceneTransition.transition_to(STAGE_SELECT_PATH)


func _on_story_battle_finished(winner_team_id: int) -> void:
	finish_mission(winner_team_id == 0, "MISSION COMPLETE" if winner_team_id == 0 else "MISSION FAILED")


func _is_smoke_test() -> bool:
	for argument in OS.get_cmdline_user_args():
		if argument.ends_with("-smoke"):
			return true
	return false
