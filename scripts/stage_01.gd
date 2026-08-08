extends StoryMission

const HEAT_WARNING_RATIO := 0.6
const STAGE_02_PATH := "res://scenes/stage_02.tscn"
const HANGAR_PATH := "res://scenes/hangar_screen.tscn"
const STAGE_01_DIALOGUE_PATH := "res://data/scenarios/stage_01_events.json"
const INTRO_EVENT := &"INTRO"
const HEAT_WARNING_EVENT := &"HEAT_WARNING"
const PART_DESTROYED_EVENT := &"PART_DESTROYED"
const MISSILE_TUTORIAL_EVENT := &"MISSILE_TUTORIAL"
const VICTORY_EVENT := &"VICTORY"

var heat_warning_played := false
var part_destroyed_dialogue_played := false
var missile_tutorial_played := false
var mission_finishing := false
var dialogue_events := {}
var dialogue_queue: Array[Dictionary] = []
var active_stage_dialogue_id := ""


func _process(delta: float) -> void:
	super(delta)
	if (
		heat_warning_played
		or mission_finishing
		or not is_instance_valid(combat_player)
		or combat_player.heat_ratio() < HEAT_WARNING_RATIO
	):
		return
	heat_warning_played = true
	_queue_stage_dialogue(HEAT_WARNING_EVENT)


func _on_combat_bound() -> void:
	super._on_combat_bound()
	if not _load_dialogue_events():
		push_error("Unable to load Stage 01 dialogue events")
	scenario_dialogue.dialogue_finished.connect(_on_stage_dialogue_finished)
	combat_player.weapon_fired.connect(_on_player_weapon_fired)
	var enemies: Array[AiMechAgent] = battle.enemies_for(combat_player)
	_randomize_dummy_facings(enemies)
	for enemy in enemies:
		enemy.part_destroyed.connect(_on_dummy_part_destroyed)
	if not _is_smoke_test():
		_queue_stage_dialogue(INTRO_EVENT)
	if OS.get_cmdline_user_args().has("--stage-01-smoke"):
		call_deferred("_run_stage_smoke")


func _randomize_dummy_facings(enemies: Array[AiMechAgent]) -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()
	for enemy in enemies:
		var facing := random.randf_range(-PI, PI)
		enemy.upper_body.rotation = facing
		enemy.lower_body.rotation = facing


func _on_dummy_part_destroyed(_part_name: StringName) -> void:
	if part_destroyed_dialogue_played or mission_finishing:
		return
	part_destroyed_dialogue_played = true
	_queue_stage_dialogue(PART_DESTROYED_EVENT)


func _on_player_weapon_fired(weapon: WeaponRuntime) -> void:
	if (
		missile_tutorial_played
		or mission_finishing
		or weapon.part_name != &"RightArm"
		or combat_player.mech_loadout.right_arm == null
		or combat_player.mech_loadout.right_arm.part_id != "tempest_rocket"
	):
		return
	missile_tutorial_played = true
	_queue_stage_dialogue(MISSILE_TUTORIAL_EVENT)


func _on_story_battle_finished(winner_team_id: int) -> void:
	if winner_team_id != 0:
		super._on_story_battle_finished(winner_team_id)
		return
	if mission_finished or mission_finishing:
		return
	mission_finishing = true
	_queue_stage_dialogue(VICTORY_EVENT)


func _load_dialogue_events() -> bool:
	if not FileAccess.file_exists(STAGE_01_DIALOGUE_PATH):
		return false
	var file := FileAccess.open(STAGE_01_DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return false
	var document: Dictionary = parser.data
	var events = document.get("events")
	if int(document.get("schema_version", 0)) != 1 or not events is Dictionary:
		return false
	dialogue_events = events
	return true


func _queue_stage_dialogue(event_id: StringName) -> void:
	var event_key := String(event_id)
	if not dialogue_events.has(event_key) or not dialogue_events[event_key] is Dictionary:
		push_error("Unknown Stage 01 dialogue event: %s" % event_id)
		return
	var document: Dictionary = dialogue_events[event_key]
	document = document.duplicate(true)
	document["schema_version"] = 1
	dialogue_queue.append(document)
	_play_next_stage_dialogue()


func _play_next_stage_dialogue() -> void:
	if not active_stage_dialogue_id.is_empty() or scenario_dialogue.active or dialogue_queue.is_empty():
		return
	var document: Dictionary = dialogue_queue.pop_front()
	active_stage_dialogue_id = str(document["id"])
	if not scenario_dialogue.play_document(document, STAGE_01_DIALOGUE_PATH):
		active_stage_dialogue_id = ""
		_play_next_stage_dialogue()


func _on_stage_dialogue_finished(scenario_id: String) -> void:
	if scenario_id != active_stage_dialogue_id:
		return
	active_stage_dialogue_id = ""
	if scenario_id == "stage_01_victory":
		GameSession.selected_game_mode = GameSession.GameMode.STORY
		GameSession.story_deployment_scene_path = STAGE_02_PATH
		GameSession.story_stage_selected_directly = false
		finish_mission(true, "MISSION COMPLETE")
		return
	_play_next_stage_dialogue()


func _mission_transition_path(success: bool) -> String:
	return HANGAR_PATH if success else super._mission_transition_path(success)


func _run_stage_smoke() -> void:
	assert(story_stage.initialized)
	assert(dialogue_events.size() == 5)
	assert(battle.agents.size() == 5)
	var player: AiMechAgent = battle.player_agent()
	assert(player != null)
	var player_arms := {
		&"LeftArm": player.mech_loadout.left_arm,
		&"RightArm": player.mech_loadout.right_arm,
	}
	for part_name: StringName in player_arms:
		var arm := player_arms[part_name] as MechPartSpec
		if arm != null:
			assert(is_equal_approx(
				float(player.part_max_durability[part_name]),
				arm.armor * AiMechAgent.PLAYER_ARM_DURABILITY_MULTIPLIER
			))
	var team_counts := {0: 0, 1: 0}
	var enemies: Array[AiMechAgent] = []
	for agent: AiMechAgent in battle.agents:
		team_counts[agent.team_id] = team_counts.get(agent.team_id, 0) + 1
		if agent.team_id == 1:
			enemies.append(agent)
			assert(is_zero_approx(agent.cruise_speed))
			assert(is_zero_approx(agent.dash_speed))
			assert(is_zero_approx(agent.acceleration))
			assert(not agent.combat_actions_enabled)
			assert(not agent.is_defeated())
			assert(is_equal_approx(agent.upper_body.rotation, agent.lower_body.rotation))
			for weapon in agent.weapons:
				assert(not weapon.disabled)
	assert(team_counts[0] == 1)
	assert(team_counts[1] == 4)
	assert(not enemies[0].upper_body.rotation == enemies[1].upper_body.rotation)
	_queue_stage_dialogue(INTRO_EVENT)
	assert(scenario_dialogue.current_text() == "갑작스럽지만, 이런 투기장에 배치가 되었으니 싸울 방법은 알려줘야겠지.")
	for _index in scenario_dialogue.dialogue.size():
		scenario_dialogue.advance()
	assert(combat_player.mech_loadout.right_arm.part_id == "tempest_rocket")
	var missile_weapon: WeaponRuntime
	for weapon in combat_player.weapons:
		if weapon.part_name == &"RightArm":
			missile_weapon = weapon
	assert(missile_weapon != null)
	combat_player.weapon_fired.emit(missile_weapon)
	assert(missile_tutorial_played)
	assert(
		scenario_dialogue.current_text().begins_with("미사일은 타겟이 락온되어야 유도가 되서 날아가."),
		"Unexpected dialogue: %s (queued: %d)" % [
			scenario_dialogue.current_text(), dialogue_queue.size(),
		]
	)
	for _index in scenario_dialogue.dialogue.size():
		scenario_dialogue.advance()
	combat_player.weapon_fired.emit(missile_weapon)
	assert(not scenario_dialogue.active)

	combat_player.current_heat = AiMechAgent.MAX_HEAT * HEAT_WARNING_RATIO
	_process(0.0)
	assert(heat_warning_played)
	assert(scenario_dialogue.current_text() == "지금 실탄계 무기를 연사를 하는 바람에 기체 온도가 올라가고 있어.")
	for _index in scenario_dialogue.dialogue.size():
		scenario_dialogue.advance()
	enemies[0].part_destroyed.emit(&"LeftArm")
	assert(part_destroyed_dialogue_played)
	assert(scenario_dialogue.current_text() == "타겟의 파츠를 파괴했네, 적의 공격 기능이 모두 제거되면 격파 판정이 돼.")
	_on_story_battle_finished(0)
	assert(mission_finishing)
	assert(dialogue_queue.size() == 1)
	scenario_dialogue.advance()
	assert(scenario_dialogue.current_text() == "좋아, 기본적 전투 기능은 전부 테스트를 해 본 거 같네.")
	for _index in scenario_dialogue.dialogue.size():
		scenario_dialogue.advance()
	assert(mission_finished)
	assert(GameSession.story_deployment_scene_path == STAGE_02_PATH)
	assert(_mission_transition_path(true) == HANGAR_PATH)
	print("STAGE_01_CHECK passed")
	get_tree().quit(0)
