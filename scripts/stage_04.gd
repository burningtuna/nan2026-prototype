extends StoryMission

const STAGE_04_SMOKE_SAVE_PATH := "/tmp/opencode/nan2026_stage_04_smoke.json"
const RESCUE_IDS: Array[StringName] = [
	&"RESCUE_1",
	&"RESCUE_2",
	&"RESCUE_3",
	&"RESCUE_4",
]

var active_rescues := {}
var completed_rescues := {}
var destination_reached := false
var boss_agent: AiMechAgent


func pause_menu_context() -> Dictionary:
	var context := super.pause_menu_context()
	context["phase"] = "boss" if destination_reached else "advance"
	context["rescued"] = completed_rescues.size()
	context["rescue_total"] = RESCUE_IDS.size()
	return context


func _on_combat_bound() -> void:
	super._on_combat_bound()
	story_stage.trigger_activated.connect(_on_stage_trigger_activated)
	battle.agent_defeated.connect(_on_stage_agent_defeated)
	if not combat_player.defeated.is_connected(_on_stage_player_defeated):
		combat_player.defeated.connect(_on_stage_player_defeated)
	if OS.get_cmdline_user_args().has("--stage-04-smoke"):
		call_deferred("_run_stage_04_smoke")


func _on_stage_trigger_activated(trigger_id: StringName) -> void:
	if trigger_id in RESCUE_IDS:
		active_rescues[trigger_id] = true
		_check_rescue_completion(trigger_id)
	elif trigger_id == &"DESTINATION":
		_reach_destination()


func _on_stage_agent_defeated(agent: AiMechAgent) -> void:
	if mission_finished:
		return
	if agent == boss_agent:
		_finish_success()
		return
	for rescue_id in RESCUE_IDS:
		if active_rescues.has(rescue_id) and not completed_rescues.has(rescue_id):
			_check_rescue_completion(rescue_id)


func _on_stage_player_defeated() -> void:
	finish_mission(false, "MISSION FAILED // PLAYER UNIT LOST")


func _check_rescue_completion(rescue_id: StringName) -> void:
	if completed_rescues.has(rescue_id):
		return
	var enemy_group := StringName("%s_ENEMIES" % rescue_id)
	var found_group := false
	for point in story_stage.spawn_points:
		if point.spawn_group != enemy_group:
			continue
		found_group = true
		var enemy := _spawned_agent(point)
		if enemy == null or not enemy.is_defeated():
			return
	if found_group:
		_complete_rescue(rescue_id)


func _complete_rescue(rescue_id: StringName) -> void:
	if completed_rescues.has(rescue_id) or destination_reached:
		return
	completed_rescues[rescue_id] = true
	var ally_group := StringName("%s_ALLY" % rescue_id)
	for point in story_stage.spawn_points:
		if point.spawn_group == ally_group:
			story_stage._spawn_point(point)
			break
	system_messages.push_message("ALLY RESCUED // %d OF 4" % completed_rescues.size())


func _reach_destination() -> void:
	if destination_reached:
		return
	destination_reached = true
	for point in story_stage.spawn_points:
		if point.spawn_group == &"BOSS_WAVE":
			boss_agent = _spawned_agent(point)
			break
	system_messages.push_message("DESTINATION SECURED // ELIMINATE COMMAND UNIT")


func _finish_success() -> void:
	if not GameSession.set_story_flag(&"stage_04_survivors", completed_rescues.size()):
		push_error("Unable to save Stage 04 survivor count")
	finish_mission(true, "MISSION COMPLETE // %d OF 4 ALLIES RESCUED" % completed_rescues.size())


func _spawned_agent(point: StorySpawnPoint) -> AiMechAgent:
	return story_stage.spawned_points.get(point.get_instance_id()) as AiMechAgent


func _run_stage_04_smoke() -> void:
	assert(story_stage.initialized)
	assert(battle.agents.size() == 1)
	assert(combat_player != null and combat_player.player_controlled)
	assert(not battle.automatic_agent_spawn)
	assert(not battle.automatic_battle_completion)
	assert(pause_menu_context()["phase"] == "advance")
	assert(pause_menu_context()["rescued"] == 0)
	var rescue_triggers := 0
	var rescue_allies := 0
	for trigger in story_stage.triggers:
		if trigger.trigger_id in RESCUE_IDS:
			rescue_triggers += 1
	for point in story_stage.spawn_points:
		if point.spawn_group in [
			&"RESCUE_1_ALLY", &"RESCUE_2_ALLY", &"RESCUE_3_ALLY", &"RESCUE_4_ALLY"
		]:
			rescue_allies += 1
			assert(point.team_id == 0 and point.stationary and point.weapons_disabled)
			assert(point.spawn_mode == StorySpawnPoint.SpawnMode.TRIGGERED)
	assert(rescue_triggers == 4 and rescue_allies == 4)

	battle.process_mode = Node.PROCESS_MODE_DISABLED
	var rescue_one := story_stage.get_node("Triggers/Rescue1") as StoryTriggerArea
	combat_player.global_position = rescue_one.global_position
	story_stage._physics_process(0.0)
	assert(active_rescues.has(&"RESCUE_1"))
	for point in story_stage.spawn_points:
		if point.spawn_group != &"RESCUE_1_ENEMIES":
			continue
		var enemy := _spawned_agent(point)
		assert(enemy != null)
		enemy.register_hit(&"Body", Vector2.RIGHT, float(enemy.part_durability[&"Body"]))
	assert(completed_rescues.has(&"RESCUE_1"))
	assert(completed_rescues.size() == 1)

	var destination := story_stage.get_node("Triggers/Destination") as StoryTriggerArea
	combat_player.global_position = destination.global_position
	story_stage._physics_process(0.0)
	assert(destination_reached)
	assert(boss_agent != null and boss_agent.unit_class == AiMechAgent.UnitClass.BOSS)
	assert(completed_rescues.size() == 1)
	assert(pause_menu_context()["phase"] == "boss")
	assert(pause_menu_context()["rescued"] == 1)

	var original_path: String = GameSession.story_progress_path
	GameSession.story_progress_path = STAGE_04_SMOKE_SAVE_PATH
	GameSession.delete_story_progress()
	_finish_success()
	assert(GameSession.story_flag(&"stage_04_survivors", -1) == 1)
	GameSession.delete_story_progress()
	GameSession.story_progress.clear()
	GameSession.story_progress_path = original_path
	print("STAGE_04_CHECK passed")
	get_tree().quit(0)
