extends StoryMission

const INTRO_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_02_intro",
	"dialogue": [
		{"speaker": "오퍼레이터", "text": "첫 실전이네, 잘 해보라고."},
		{"speaker": "적", "text": "폐품 몇 개 붙였다고 파일럿이 되는 건 아니지."},
	],
}
const FIRST_ENEMY_DEFEATED_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_02_first_enemy_defeated",
	"dialogue": [
		{"speaker": "적", "text": "저런 깡통에게 내가 진다고?"},
		{"speaker": "오퍼레이터", "text": "잘 했어, 한 사람 몫을 하고 있네"},
	],
}
const VICTORY_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_02_victory",
	"dialogue": [
		{"speaker": "오퍼레이터", "text": "이번 경기는 이겼어, 다음은 아레나 최고 보스에게 도전할 기회를 얻게 되었네"},
		{"speaker": "오퍼레이터", "text": "지금 외부 상황 때문에 새로운 중고 파츠들이 새로 생기고 있어, 더 다양한 파츠로 전투를 준비해 보자고."},
	],
}

var first_enemy_defeat_played := false
var mission_finishing := false
var dialogue_queue: Array[Dictionary] = []
var active_stage_dialogue_id := ""


func _on_combat_bound() -> void:
	super._on_combat_bound()
	scenario_dialogue.dialogue_finished.connect(_on_stage_dialogue_finished)
	for enemy: AiMechAgent in battle.enemies_for(combat_player):
		enemy.defeated.connect(_on_enemy_defeated_for_dialogue)
	if not _is_smoke_test():
		_queue_stage_dialogue(INTRO_DIALOGUE)
	if OS.get_cmdline_user_args().has("--stage-02-smoke"):
		call_deferred("_run_stage_smoke")


func _on_enemy_defeated_for_dialogue() -> void:
	if first_enemy_defeat_played or mission_finishing:
		return
	first_enemy_defeat_played = true
	_queue_stage_dialogue(FIRST_ENEMY_DEFEATED_DIALOGUE)


func _on_story_battle_finished(winner_team_id: int) -> void:
	if winner_team_id != 0:
		super._on_story_battle_finished(winner_team_id)
		return
	if mission_finished or mission_finishing:
		return
	mission_finishing = true
	_queue_stage_dialogue(VICTORY_DIALOGUE)


func _queue_stage_dialogue(document: Dictionary) -> void:
	dialogue_queue.append(document)
	_play_next_stage_dialogue()


func _play_next_stage_dialogue() -> void:
	if not active_stage_dialogue_id.is_empty() or scenario_dialogue.active or dialogue_queue.is_empty():
		return
	var document: Dictionary = dialogue_queue.pop_front()
	active_stage_dialogue_id = str(document["id"])
	if not scenario_dialogue.play_document(document, "stage_02.gd"):
		active_stage_dialogue_id = ""
		_play_next_stage_dialogue()


func _on_stage_dialogue_finished(scenario_id: String) -> void:
	if scenario_id != active_stage_dialogue_id:
		return
	active_stage_dialogue_id = ""
	if scenario_id == "stage_02_victory":
		finish_mission(true, "MISSION COMPLETE")
		return
	_play_next_stage_dialogue()


func _run_stage_smoke() -> void:
	assert(story_stage.initialized)
	assert(battle.agents.size() == 4)
	var player := battle.player_agent() as AiMechAgent
	assert(player != null)
	assert(player.mech_loadout.body.part_id == "kestrel_core")
	assert(player.mech_loadout.head.part_id == "falcon_sensor")
	assert(player.mech_loadout.legs.part_id == "strider_legs")
	assert(player.mech_loadout.left_arm.part_id == "rx_autocannon")
	assert(player.mech_loadout.right_arm.part_id == "rx_autocannon")
	assert(player.mech_loadout.backpack.part_id == "grid_generator")
	var team_counts := {0: 0, 1: 0}
	var enemies: Array[AiMechAgent] = []
	for agent: AiMechAgent in battle.agents:
		team_counts[agent.team_id] = team_counts.get(agent.team_id, 0) + 1
		if not agent.player_controlled:
			assert(agent.movement_type == AiMechAgent.MovementType.AGGRESSIVE)
		if agent.team_id == 1:
			enemies.append(agent)
	assert(team_counts[0] == 2)
	assert(team_counts[1] == 2)

	_queue_stage_dialogue(INTRO_DIALOGUE)
	assert(scenario_dialogue.current_text() == "첫 실전이네, 잘 해보라고.")
	for _index in scenario_dialogue.dialogue.size():
		scenario_dialogue.advance()
	enemies[0].defeated.emit()
	assert(first_enemy_defeat_played)
	assert(scenario_dialogue.current_text() == "저런 깡통에게 내가 진다고?")
	for _index in scenario_dialogue.dialogue.size():
		scenario_dialogue.advance()
	_on_story_battle_finished(0)
	assert(mission_finishing)
	assert(scenario_dialogue.current_text() == "이번 경기는 이겼어, 다음은 아레나 최고 보스에게 도전할 기회를 얻게 되었네")
	for _index in scenario_dialogue.dialogue.size():
		scenario_dialogue.advance()
	assert(mission_finished)
	assert(GameSession.story_deployment_scene_path == "res://scenes/stage_03.tscn")
	assert(_mission_transition_path(true) == STORY_HANGAR_PATH)
	print("STAGE_02_CHECK passed")
	get_tree().quit(0)
