extends StoryMission

const STAGE_03_INTRO_PATH := "res://data/scenarios/stage_03_events.json"
const BOSS_ARMORED_PARTS: Array[StringName] = [
	&"Body", &"Head", &"LeftArm", &"RightArm", &"Backpack",
]
const LEG_DESTROYED_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_03_legs_destroyed",
	"dialogue": [{
		"speaker": "아레나 보스",
		"text": "정말 지독하군. 감정 없는 인간하고 싸우는 기분이야.",
	}],
}
const LEG_DAMAGED_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_03_legs_damaged",
	"dialogue": [{
		"speaker": "오퍼레이터",
		"text": "효과가 있어요, 다리를 끊으면 보스의 기동력을 제거할 수 있어요",
	}],
}
const STAGE_END_FADE_SECONDS := 0.5
const STAGE_END_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_03_end_image",
	"dialogue": [{
		"speaker": "군 지휘관",
		"text": "AI던 사람이던 상관없어, 지금 싸울 사람이 부족하다고. 당장 가지고 전장으로 재배치해",
	}],
}
const VICTORY_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_03_victory",
	"dialogue": [
		{"speaker": "군 지휘관", "text": "경기를 중단한다, 여기 있는 싸울 수 있는 전력은 모두 징집해"},
		{"speaker": "오퍼레이터", "text": "잠깐만요. 이쪽은 아직 준비되지 않았어요."},
		{"speaker": "군 지휘관", "text": "방금 싸우는 걸 봤다. 충분해."},
		{"speaker": "오퍼레이터", "text": "아직 사람과 함께 싸워 본 적도 없어요."},
		{"speaker": "군 지휘관", "text": "사람하고는 싸워 봤잖아."},
	],
}

@onready var stage_end_presentation: Control = $StageEndPresentation
@onready var stage_end_image: TextureRect = $StageEndPresentation/Image
@onready var stage_end_fade: ColorRect = $StageEndPresentation/Fade
@onready var stage_end_dialogue: ScenarioDialogue = $StageEndPresentation/Dialogue

var boss: AiMechAgent
var stage_end_ready := false
var boss_base_dash_cooldown := 0.0
var boss_base_dash_speed := 0.0
var boss_base_turn_speed := 0.0
var boss_legs_warning_played := false


func _on_combat_bound() -> void:
	super._on_combat_bound()
	boss = _find_boss()
	if boss != null:
		_configure_boss()
	scenario_dialogue.dialogue_finished.connect(_on_stage_03_dialogue_finished)
	stage_end_dialogue.dialogue_finished.connect(_on_stage_end_dialogue_finished)
	if not _is_smoke_test():
		scenario_dialogue.play_file(STAGE_03_INTRO_PATH)
	if OS.get_cmdline_user_args().has("--story-deploy-smoke"):
		call_deferred("_run_story_deploy_smoke")
	if OS.get_cmdline_user_args().has("--stage-03-smoke"):
		call_deferred("_run_stage_smoke")


func _find_boss() -> AiMechAgent:
	for agent: AiMechAgent in battle.agents:
		if agent.unit_class == AiMechAgent.UnitClass.BOSS:
			return agent
	return null


func _configure_boss() -> void:
	for part_name in BOSS_ARMORED_PARTS:
		boss.incoming_damage_multipliers_by_part[part_name] = 0.1
	boss_base_dash_cooldown = boss.dash_cooldown
	boss_base_dash_speed = boss.dash_speed
	boss_base_turn_speed = boss.upper_turn_speed_degrees
	boss.movement_speed_multiplier *= 2.0
	boss.dash_cooldown /= 3.0
	boss.dash_speed *= 2.0
	boss.upper_turn_speed_degrees *= 2.0
	boss.hit_and_run_enabled = true
	boss.hit_and_run_retreat_distance = 1200.0
	boss.prefer_non_player_targets = true
	boss.hit_received.connect(_on_boss_hit_received)
	boss.part_destroyed.connect(_on_boss_part_destroyed)


func _on_boss_hit_received(part_name: StringName, _aspect: StringName) -> void:
	if (
		boss_legs_warning_played
		or part_name != &"Legs"
		or boss.part_durability_ratio(&"Legs") > 0.5
	):
		return
	boss_legs_warning_played = true
	if not mission_finished:
		scenario_dialogue.play_document(LEG_DAMAGED_DIALOGUE, "stage_03.gd")


func _on_boss_part_destroyed(part_name: StringName) -> void:
	if part_name != &"Legs":
		return
	boss.incoming_damage_multipliers_by_part.clear()
	boss.movement_speed_multiplier /= 2.0
	boss.dash_cooldown = boss_base_dash_cooldown
	boss.dash_speed = 0.0
	boss.upper_turn_speed_degrees = boss_base_turn_speed
	boss.hit_and_run_enabled = false
	boss.hit_and_run_retreating = false
	boss.hit_and_run_retreat_time_remaining = 0.0
	if not mission_finished:
		scenario_dialogue.play_document(LEG_DESTROYED_DIALOGUE, "stage_03.gd")


func _on_story_battle_finished(winner_team_id: int) -> void:
	if winner_team_id != 0:
		super._on_story_battle_finished(winner_team_id)
		return
	if mission_finished:
		return
	mission_finished = true
	set_process(false)
	_set_player_hud_visible(false)
	scenario_dialogue.play_document(VICTORY_DIALOGUE, "stage_03.gd")


func _on_stage_03_dialogue_finished(scenario_id: String) -> void:
	if scenario_id != "stage_03_victory":
		return
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	_show_stage_end()


func _show_stage_end() -> void:
	stage_end_presentation.visible = true
	stage_end_image.visible = false
	stage_end_fade.color = Color(0.0, 0.0, 0.0, 0.0)
	if _is_smoke_test():
		stage_end_image.visible = true
		_play_stage_end_dialogue()
		return
	var fade_out := create_tween()
	fade_out.tween_property(stage_end_fade, "color", Color.BLACK, STAGE_END_FADE_SECONDS)
	await fade_out.finished
	stage_end_image.visible = true
	var fade_in := create_tween()
	fade_in.tween_property(
		stage_end_fade,
		"color",
		Color(0.0, 0.0, 0.0, 0.0),
		STAGE_END_FADE_SECONDS
	)
	await fade_in.finished
	_play_stage_end_dialogue()


func _play_stage_end_dialogue() -> void:
	stage_end_dialogue.play_document(STAGE_END_DIALOGUE, "stage_03.gd")


func _on_stage_end_dialogue_finished(scenario_id: String) -> void:
	if scenario_id != "stage_03_end_image":
		return
	if _is_smoke_test():
		stage_end_ready = true
		return
	_finish_stage_03()


func _finish_stage_03() -> void:
	var error := SceneTransition.transition_to(STAGE_SELECT_PATH)
	if error != OK:
		push_error("Unable to finish Stage 03: %s" % error_string(error))
		_play_stage_end_dialogue()
	else:
		GameSession.set_story_flag(&"stage_03_complete", true)


func _run_story_deploy_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.STORY)
	assert(GameSession.story_deployment_scene_path == "res://scenes/stage_03.tscn")
	assert(GameSession.player_mech_loadout != null)
	for slot in MechLoadout.MechSlot.values():
		var deployed_part := combat_player.mech_loadout.part_for_slot(slot)
		var confirmed_part := GameSession.player_mech_loadout.part_for_slot(slot)
		assert(deployed_part == confirmed_part)
	print("STORY_DEPLOY_CHECK passed")
	get_tree().quit(0)


func _run_stage_smoke() -> void:
	assert(story_stage.initialized)
	assert(battle.agents.size() == 3)
	assert(battle.player_agent() != null)
	var team_counts := {0: 0, 1: 0}
	for agent: AiMechAgent in battle.agents:
		team_counts[agent.team_id] = team_counts.get(agent.team_id, 0) + 1
	assert(team_counts[0] == 2)
	assert(team_counts[1] == 1)
	assert(boss != null and boss.movement_type == AiMechAgent.MovementType.AGGRESSIVE)
	assert(boss.mech_loadout.body.part_id == "swift_core")
	assert(boss.mech_loadout.head.part_id == "falcon_sensor")
	assert(boss.mech_loadout.left_arm.part_id == "cyclone_flechette_arm")
	assert(boss.mech_loadout.right_arm == null)
	assert(boss.mech_loadout.backpack.part_id == "grid_generator")
	assert(boss.mech_loadout.legs.part_id == "courier_legs")
	assert(is_equal_approx(boss.movement_speed_multiplier, 2.0))
	assert(is_equal_approx(
		boss.movement_speed(),
		float(boss.mech_loadout.stats()["mobility"])
		* AiMechAgent.MOBILITY_SPEED_MULTIPLIER
		* 2.0
	))
	assert(is_equal_approx(boss.dash_cooldown, boss_base_dash_cooldown / 3.0))
	assert(is_equal_approx(boss.dash_speed, boss_base_dash_speed * 2.0))
	assert(is_equal_approx(boss.upper_turn_speed_degrees, boss_base_turn_speed * 2.0))
	assert(boss.hit_and_run_enabled)
	assert(boss.prefer_non_player_targets)
	var ally: AiMechAgent
	for agent: AiMechAgent in battle.agents:
		if agent.team_id == 0 and not agent.player_controlled:
			ally = agent
	assert(ally != null)
	boss.sensor_snapshot.units.assign([
		{"target": combat_player, "position": boss.global_position + Vector2(100.0, 0.0)},
		{"target": ally, "position": boss.global_position + Vector2(500.0, 0.0)},
	])
	boss._select_opponent(boss.global_position)
	assert(boss.opponent == ally)
	boss.hit_and_run_retreating = true
	boss.hit_and_run_retreat_time_remaining = boss.hit_and_run_retreat_duration
	boss.observed_target_position = boss.global_position + Vector2(500.0, 0.0)
	boss.opponent = combat_player
	boss._update_strategy_direction()
	assert(boss.movement_direction.x < 0.0)
	var shots_before_retreat := boss.shot_count
	boss._try_fire_linked_group()
	assert(boss.shot_count == shots_before_retreat)
	boss.observed_target_position = boss.global_position + Vector2(1300.0, 0.0)
	boss._update_strategy_direction()
	assert(not boss.hit_and_run_retreating)
	var body_before := float(boss.part_durability[&"Body"])
	boss.register_hit(&"Body", Vector2.RIGHT, 100.0)
	assert(is_equal_approx(float(boss.part_durability[&"Body"]), body_before - 10.0))
	var legs_half_damage := float(boss.part_max_durability[&"Legs"]) * 0.5
	boss.register_hit(&"Legs", Vector2.RIGHT, legs_half_damage)
	assert(boss_legs_warning_played)
	assert(scenario_dialogue.current_text() == "효과가 있어요, 다리를 끊으면 보스의 기동력을 제거할 수 있어요")
	scenario_dialogue.advance()
	boss.register_hit(&"Legs", Vector2.RIGHT, float(boss.part_durability[&"Legs"]))
	assert(boss.is_part_destroyed(&"Legs"))
	assert(boss.incoming_damage_multipliers_by_part.is_empty())
	assert(is_zero_approx(boss.dash_speed))
	assert(scenario_dialogue.current_text() == "정말 지독하군. 감정 없는 인간하고 싸우는 기분이야.")
	assert(not stage_end_presentation.visible)
	scenario_dialogue.advance()
	_on_story_battle_finished(0)
	assert(mission_finished)
	assert(not sidebar.visible)
	assert(scenario_dialogue.current_speaker() == "군 지휘관")
	assert(scenario_dialogue.current_text() == "경기를 중단한다, 여기 있는 싸울 수 있는 전력은 모두 징집해")
	assert(scenario_dialogue.dialogue.size() == 5)
	for _index in scenario_dialogue.dialogue.size():
		scenario_dialogue.advance()
	assert(not stage_end_ready)
	assert(stage_end_presentation.visible)
	assert(stage_end_image.visible)
	assert(is_zero_approx(stage_end_fade.color.a))
	assert(stage_end_dialogue.active)
	assert(stage_end_dialogue.current_speaker() == "군 지휘관")
	assert(stage_end_dialogue.current_text() == "AI던 사람이던 상관없어, 지금 싸울 사람이 부족하다고. 당장 가지고 전장으로 재배치해")
	stage_end_dialogue.advance()
	assert(stage_end_ready)
	assert(not stage_end_dialogue.active)
	assert(battle.process_mode == Node.PROCESS_MODE_DISABLED)
	print("STAGE_03_CHECK passed")
	get_tree().quit(0)
