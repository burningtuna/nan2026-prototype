extends StoryMission

const ALIEN_INFESTATION_OVERLAY := preload("res://scripts/alien_infestation_overlay.gd")
const STAGE_04_SMOKE_SAVE_PATH := "/tmp/opencode/nan2026_stage_04_smoke.json"
const STAGE_04_DIALOGUE_PATH := "res://data/scenarios/stage_04_events.json"
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
var dialogue_events := {}
var dialogue_queue: Array[StringName] = []
var active_stage_dialogue: StringName = &""
var arena_boss_reaction_played := false
var infestation_explained := false

@onready var blocked_overlay: Sprite2D = \
	$CombatContainer/CombatViewport/StoryStage/BlockedOverlay


func _unhandled_key_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if (
		key_event == null
		or key_event.physical_keycode != KEY_B
		or not key_event.pressed
		or key_event.echo
	):
		return
	_toggle_blocked_overlay()
	get_viewport().set_input_as_handled()


func _toggle_blocked_overlay() -> void:
	if is_instance_valid(blocked_overlay):
		blocked_overlay.visible = not blocked_overlay.visible


func pause_menu_context() -> Dictionary:
	var context := super.pause_menu_context()
	context["phase"] = "boss" if destination_reached else "advance"
	context["rescued"] = completed_rescues.size()
	context["rescue_total"] = RESCUE_IDS.size()
	return context


func _on_combat_bound() -> void:
	super._on_combat_bound()
	if not _load_dialogue_events():
		push_error("Unable to load Stage 04 dialogue events")
	story_stage.trigger_activated.connect(_on_stage_trigger_activated)
	battle.agent_defeated.connect(_on_stage_agent_defeated)
	scenario_dialogue.dialogue_finished.connect(_on_stage_dialogue_finished)
	if not combat_player.defeated.is_connected(_on_stage_player_defeated):
		combat_player.defeated.connect(_on_stage_player_defeated)
	if OS.get_cmdline_user_args().has("--stage-04-smoke"):
		call_deferred("_run_stage_04_smoke")


func _on_stage_trigger_activated(trigger_id: StringName) -> void:
	if trigger_id in RESCUE_IDS:
		active_rescues[trigger_id] = true
		_queue_stage_dialogue(StringName("%s_DISTRESS" % trigger_id))
		_check_rescue_completion(trigger_id)
	elif trigger_id == &"DESTINATION":
		_reach_destination()
	var infested_count := _mark_spawned_enemies()
	if infested_count > 0 and not infestation_explained:
		infestation_explained = true
		_queue_stage_dialogue(&"ALIEN_INFESTATION_EXPLAINED")


func _mark_spawned_enemies() -> int:
	var marked := 0
	for value in story_stage.spawned_points.values():
		var agent := value as AiMechAgent
		if not is_instance_valid(agent) or agent.team_id == combat_player.team_id:
			continue
		if not agent.has_meta(ALIEN_INFESTATION_OVERLAY.META_KEY):
			marked += 1
		ALIEN_INFESTATION_OVERLAY.attach_to(agent)
	return marked


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
	_queue_stage_dialogue(StringName("%s_RESCUED" % rescue_id))


func _load_dialogue_events() -> bool:
	if not FileAccess.file_exists(STAGE_04_DIALOGUE_PATH):
		return false
	var file := FileAccess.open(STAGE_04_DIALOGUE_PATH, FileAccess.READ)
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
	if not dialogue_events.has(String(event_id)):
		push_error("Unknown Stage 04 dialogue event: %s" % event_id)
		return
	dialogue_queue.append(event_id)
	_play_next_stage_dialogue()


func _play_next_stage_dialogue() -> void:
	if not active_stage_dialogue.is_empty() or scenario_dialogue.active or dialogue_queue.is_empty():
		return
	active_stage_dialogue = dialogue_queue.pop_front()
	var entry: Dictionary = dialogue_events[String(active_stage_dialogue)]
	var document := {
		"schema_version": 1,
		"id": "stage_04_%s" % String(active_stage_dialogue).to_lower(),
		"dialogue": [{
			"speaker": str(entry.get("speaker", "ALLY")),
			"text": str(entry.get("text", "...")),
		}],
	}
	if not scenario_dialogue.play_document(document, STAGE_04_DIALOGUE_PATH):
		active_stage_dialogue = &""
		call_deferred("_play_next_stage_dialogue")


func _on_stage_dialogue_finished(scenario_id: String) -> void:
	if active_stage_dialogue.is_empty():
		call_deferred("_play_next_stage_dialogue")
		return
	var expected_id := "stage_04_%s" % String(active_stage_dialogue).to_lower()
	if scenario_id != expected_id:
		return
	var finished_event := active_stage_dialogue
	active_stage_dialogue = &""
	if String(finished_event).ends_with("_RESCUED") and is_instance_valid(combat_player):
		combat_player.restore_all_parts()
		system_messages.push_message("FIELD REPAIR COMPLETE // ALL PARTS RESTORED")
		if completed_rescues.size() >= 3 and not arena_boss_reaction_played:
			arena_boss_reaction_played = true
			dialogue_queue.push_front(&"ARENA_BOSS_REACTION")
	call_deferred("_play_next_stage_dialogue")


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
	assert(dialogue_events.size() == 10)
	var distress_texts := {}
	var rescued_texts := {}
	for rescue_id in RESCUE_IDS:
		distress_texts[dialogue_events["%s_DISTRESS" % rescue_id]["text"]] = true
		rescued_texts[dialogue_events["%s_RESCUED" % rescue_id]["text"]] = true
	assert(distress_texts.size() == 4 and rescued_texts.size() == 4)
	assert(battle.agents.size() == 1)
	assert(combat_player != null and combat_player.player_controlled)
	assert(not battle.automatic_agent_spawn)
	assert(not battle.automatic_battle_completion)
	assert(not battle.floor_tile_enabled)
	assert(battle.arena == Rect2(-2800.0, -1630.0, 6000.0, 3260.0))
	assert(story_stage.walkable_areas.size() == 1)
	var map_background := story_stage.get_node("MapBackground") as Sprite2D
	var walkability_mask := story_stage.get_node("WalkabilityMask") as StoryWalkabilityMask
	var part_collision_radius := combat_player.environment_collision_radius()
	assert(part_collision_radius >= combat_player.mech_collision_radius)
	assert(map_background.z_index == -100)
	assert(blocked_overlay != null and blocked_overlay.z_index == -90)
	assert(not blocked_overlay.visible)
	assert(map_background.z_index < blocked_overlay.z_index and blocked_overlay.z_index < 0)
	_toggle_blocked_overlay()
	assert(blocked_overlay.visible)
	_toggle_blocked_overlay()
	assert(not blocked_overlay.visible)
	assert(walkability_mask.is_in_group(&"projectile_mask_blockers"))
	assert(walkability_mask.is_in_group(&"radar_terrain_masks"))
	assert(hud.tactical_map._terrain_provider() == walkability_mask)
	var active_camera := combat_player.get_viewport().get_camera_2d()
	assert(active_camera != null)
	var initial_camera_zoom := active_camera.zoom
	var initial_radar_range := hud.tactical_map._radar_range()
	active_camera.zoom = initial_camera_zoom * 2.0
	assert(is_equal_approx(hud.tactical_map._radar_range(), initial_radar_range * 0.5))
	active_camera.zoom = initial_camera_zoom
	assert(walkability_mask.radar_point_is_accessible(combat_player.global_position))
	assert(not walkability_mask.radar_point_is_accessible(Vector2(-2580.0, -330.0)))
	assert(walkability_mask.contains_agent_at(combat_player.global_position, part_collision_radius))
	var footprint_probe = null
	for index in range(1, 201):
		var candidate := combat_player.global_position.lerp(
			Vector2(-2580.0, -330.0),
			float(index) / 200.0
		)
		if walkability_mask.contains_global_point(candidate) and not walkability_mask.contains_agent_at(candidate, part_collision_radius):
			footprint_probe = candidate
			break
	assert(footprint_probe is Vector2)
	assert(story_stage.resolve_agent_motion(
		combat_player.global_position,
		footprint_probe,
		part_collision_radius
	) == combat_player.global_position)
	var dash_collision_origin := combat_player.global_position
	combat_player.dash_direction = (footprint_probe - dash_collision_origin).normalized()
	combat_player.dash_time_remaining = 0.5
	combat_player.velocity = combat_player.dash_direction * 100.0
	story_stage.last_valid_positions[combat_player.get_instance_id()] = dash_collision_origin
	combat_player.global_position = footprint_probe
	story_stage._physics_process(0.0)
	assert(combat_player.global_position.is_equal_approx(dash_collision_origin))
	assert(not combat_player.is_dashing())
	assert(combat_player.velocity.is_zero_approx())
	var slide_result = null
	for slide_target in [
		Vector2(-2580.0, -330.0),
		Vector2(-1600.0, -1200.0),
		Vector2(-200.0, -100.0),
		Vector2(450.0, 1400.0),
		Vector2(1800.0, 200.0),
	]:
		var stopped := story_stage.resolve_agent_motion(
			combat_player.global_position,
			slide_target,
			part_collision_radius,
			false
		)
		var slid := story_stage.resolve_agent_motion(
			combat_player.global_position,
			slide_target,
			part_collision_radius,
			true
		)
		if stopped == combat_player.global_position and not slid.is_equal_approx(combat_player.global_position):
			slide_result = slid
			break
	assert(slide_result is Vector2)
	assert(walkability_mask.contains_agent_at(slide_result, part_collision_radius))
	var projectile_wall_hit = walkability_mask.projectile_block_position(
		combat_player.global_position,
		Vector2(-2580.0, -330.0)
	)
	assert(projectile_wall_hit is Vector2)
	var projectile_target := Vector2(-2580.0, -330.0)
	var projectile_distance := combat_player.global_position.distance_to(projectile_target)
	var test_projectile := BallisticProjectile.new()
	var test_projectile_spec := ProjectileSpec.new()
	test_projectile_spec.speed = projectile_distance
	test_projectile_spec.collision_radius = 1.0
	test_projectile.configure(
		test_projectile_spec,
		(projectile_target - combat_player.global_position).normalized(),
		projectile_distance,
		combat_player,
		&"LeftArm",
		404,
		0.0,
		WeaponSpec.WeaponFamily.BALLISTIC,
		null
	)
	battle.projectile_layer.add_child(test_projectile)
	test_projectile.global_position = combat_player.global_position
	var impact_audio_count: int = battle.projectile_layer.find_children(
		"CombatAudioOneShot", "AudioStreamPlayer2D", false, false
	).size()
	assert(test_projectile._projectile_mask_hit(
		combat_player.global_position,
		projectile_target
	) is Vector2)
	test_projectile._physics_process(1.0)
	assert(test_projectile.hit_resolved)
	assert(battle.projectile_layer.find_children(
		"CombatAudioOneShot", "AudioStreamPlayer2D", false, false
	).size() == impact_audio_count)
	var invalid_spawns: Array[String] = []
	for point in story_stage.spawn_points:
		if not story_stage._is_walkable(point.global_position, part_collision_radius):
			invalid_spawns.append(point.name)
	assert(invalid_spawns.is_empty(), "Spawns outside walkable map: %s" % ", ".join(invalid_spawns))
	var invalid_triggers: Array[String] = []
	for trigger in story_stage.triggers:
		if not story_stage._is_walkable(trigger.global_position):
			invalid_triggers.append(trigger.name)
	assert(invalid_triggers.is_empty(), "Triggers outside walkable map: %s" % ", ".join(invalid_triggers))
	for blocked_point in [Vector2(-2580.0, -330.0), Vector2(-200.0, -100.0), Vector2(450.0, 1400.0)]:
		assert(not story_stage._is_walkable(blocked_point))
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
			assert(point.team_color == Color(0.35, 0.85, 0.42, 1.0))
			assert(point.spawn_mode == StorySpawnPoint.SpawnMode.TRIGGERED)
	assert(rescue_triggers == 4 and rescue_allies == 4)

	battle.process_mode = Node.PROCESS_MODE_DISABLED
	var rescue_one := story_stage.get_node("Triggers/Rescue1") as StoryTriggerArea
	combat_player.global_position = rescue_one.global_position
	story_stage.last_valid_positions[combat_player.get_instance_id()] = combat_player.global_position
	story_stage._physics_process(0.0)
	assert(active_rescues.has(&"RESCUE_1"))
	assert(active_stage_dialogue == &"RESCUE_1_DISTRESS")
	assert(scenario_dialogue.current_text() == "여기 사람 있어요! 도와줘요!")
	scenario_dialogue.advance()
	await get_tree().process_frame
	assert(infestation_explained)
	assert(active_stage_dialogue == &"ALIEN_INFESTATION_EXPLAINED")
	assert(scenario_dialogue.current_speaker() == "오퍼레이터")
	scenario_dialogue.advance()
	await get_tree().process_frame
	var damaged_part := &"Head"
	combat_player.register_hit(
		damaged_part,
		Vector2.RIGHT,
		float(combat_player.part_durability[damaged_part])
	)
	await get_tree().process_frame
	assert(combat_player.is_part_destroyed(damaged_part))
	var spawned_rescue_enemies: Array[AiMechAgent] = []
	for point in story_stage.spawn_points:
		if point.spawn_group != &"RESCUE_1_ENEMIES":
			continue
		var enemy := _spawned_agent(point)
		assert(enemy != null and enemy.unit_class == AiMechAgent.UnitClass.MECH)
		var body_sprite := enemy.get_node("UpperBody/BodySprite") as Sprite2D
		assert(body_sprite.visible and body_sprite.texture != null)
		assert(enemy.has_meta(ALIEN_INFESTATION_OVERLAY.META_KEY))
		assert(overlay.enemies.has(enemy) and hud.tactical_map.enemies.has(enemy))
		spawned_rescue_enemies.append(enemy)
	assert(spawned_rescue_enemies.size() == 2)
	assert(overlay._enemy_roster().size() == 2)
	assert(overlay._enemy_roster_rect().size.y > 0.0)
	var recovery_tested := false
	for enemy in spawned_rescue_enemies:
		if not recovery_tested:
			recovery_tested = true
			enemy.dash_direction = Vector2.RIGHT
			assert(enemy._dash_movement_was_blocked(Vector2.ZERO, 100.0))
			assert(not enemy._dash_movement_was_blocked(Vector2(30.0, 0.0), 100.0))
			enemy._begin_ai_wall_recovery(Vector2.RIGHT)
			assert(enemy.is_ai_wall_recovering())
			enemy._update_ai_wall_recovery(0.1)
			assert(enemy.movement_direction.is_equal_approx(Vector2.LEFT))
			enemy.ai_wall_backoff_remaining = 0.0
			enemy._update_ai_wall_recovery(0.1)
			assert(is_zero_approx(enemy.movement_direction.dot(Vector2.RIGHT)))
			assert(is_equal_approx(enemy.movement_direction.length(), 1.0))
			enemy.ai_wall_turn_remaining = 0.0
		enemy.register_hit(&"Body", Vector2.RIGHT, float(enemy.part_durability[&"Body"]))
	assert(recovery_tested)
	assert(completed_rescues.has(&"RESCUE_1"))
	assert(completed_rescues.size() == 1)
	assert(active_stage_dialogue == &"RESCUE_1_RESCUED")
	assert(scenario_dialogue.current_text() == "덕분에 살았습니다. 감사합니다!")
	scenario_dialogue.advance()
	await get_tree().process_frame
	assert(not combat_player.is_part_destroyed(damaged_part))
	assert(combat_player.part_durability[damaged_part] == combat_player.part_max_durability[damaged_part])
	var restored_hitbox := combat_player.part_hitboxes[damaged_part] as PartHitbox
	assert(restored_hitbox.monitorable and restored_hitbox.collision_layer == 2)
	assert((restored_hitbox.get_parent() as Sprite2D).visible)

	completed_rescues[&"RESCUE_2"] = true
	completed_rescues[&"RESCUE_3"] = true
	_queue_stage_dialogue(&"RESCUE_3_RESCUED")
	assert(scenario_dialogue.current_text() == "이 은혜는 절대 잊지 않겠습니다!")
	scenario_dialogue.advance()
	await get_tree().process_frame
	assert(arena_boss_reaction_played)
	assert(active_stage_dialogue == &"ARENA_BOSS_REACTION")
	assert(scenario_dialogue.current_speaker() == "아레나 보스")
	assert(scenario_dialogue.current_text() == "...")
	scenario_dialogue.advance()
	await get_tree().process_frame
	completed_rescues.erase(&"RESCUE_2")
	completed_rescues.erase(&"RESCUE_3")

	var destination := story_stage.get_node("Triggers/Destination") as StoryTriggerArea
	combat_player.global_position = destination.global_position
	story_stage.last_valid_positions[combat_player.get_instance_id()] = combat_player.global_position
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
