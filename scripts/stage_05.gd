extends StoryMission

const DRONE_AGENT := preload("res://scripts/drone_agent.gd")
const ALIEN_INFESTATION_OVERLAY := preload("res://scripts/alien_infestation_overlay.gd")
const PARTS_DATA_PATH := "res://data/mech_parts.json"
const STAGE_05_CUTSCENE_PATH := "res://scenes/stage_05_cutscene.tscn"
const DRONE_TARGET := 20
const MAX_LIVING_DRONES := 4
const DRONE_SPAWN_INTERVAL := 1.5
const BEAM_UNLOCK_DRONE_KILLS := 2
const ALLY_COUNT := 4
const RELOAD_SUPPORT_MULTIPLIER := 5.0
const SUPPORT_APPROACH_SECONDS := 0.35
const SUPPORT_OFFSETS := [
	Vector2(-90.0, 70.0),
	Vector2(90.0, 70.0),
	Vector2(-90.0, -70.0),
	Vector2(0.0, -90.0),
]
const ALLY_4_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_05_ally_4_sacrifice",
	"dialogue": [{
		"speaker": "아군4",
		"text": "한눈 팔았군, 두번은 도와줄 수 없으니 다음엔 실수하지 마!",
	}],
}
const BEAM_WARNING_DIALOGUE := {
	"schema_version": 1,
	"id": "stage_05_beam_warning",
	"dialogue": [{
		"speaker": "오퍼레이터",
		"text": "적 모선에서 강력한 에너지포가 발사되려 합니다! 예상 착탄 지점을 표시할테니 피하세요",
	}],
}

@onready var beam_hazard: VerticalBeamHazard = \
	$CombatContainer/CombatViewport/StoryStage/VerticalBeamHazard

var part_catalog: MechPartCatalog
var rng := RandomNumberGenerator.new()
var survivor_count := 0
var drone_sequence := 0
var drones_spawned := 0
var drones_defeated := 0
var spawn_remaining := 0.0
var running := false
var allies: Array[AiMechAgent] = []
var observed_reload_count := 0
var player_was_cooling := false
var energy_support_armed := true
var ally_support_tweens := {}
var beam_intro_played := false
var beam_intro_active := false


func pause_menu_context() -> Dictionary:
	var context := super.pause_menu_context()
	context["drones_defeated"] = drones_defeated
	context["drone_target"] = DRONE_TARGET
	context["drones_active"] = _living_drone_count() if is_instance_valid(battle) else 0
	context["survivors"] = survivor_count
	return context


func _process(delta: float) -> void:
	super(delta)
	if not running or mission_finished:
		return
	if beam_intro_active:
		return
	_update_ally_support()
	spawn_remaining -= delta
	if spawn_remaining <= 0.0 and _living_drone_count() < MAX_LIVING_DRONES:
		spawn_drone()
		spawn_remaining = DRONE_SPAWN_INTERVAL


func _on_combat_bound() -> void:
	super._on_combat_bound()
	var direct_demo := GameSession.story_stage_selected_directly or OS.get_cmdline_user_args().has("--stage-05-smoke")
	survivor_count = ALLY_COUNT if direct_demo else clampi(
		int(GameSession.story_flag(&"stage_04_survivors", 0)),
		0,
		ALLY_COUNT
	)
	part_catalog = MechPartCatalog.new()
	if not part_catalog.load_file(PARTS_DATA_PATH, battle.weapon_catalog):
		push_error("Unable to initialize Stage 5 part catalog")
		return
	rng.seed = 5052026
	battle.agent_defeated.connect(_on_stage_agent_defeated)
	combat_player.defeated.connect(_on_stage_player_defeated)
	beam_hazard.warning_started.connect(_on_beam_warning_started)
	beam_hazard.firing_started.connect(_on_beam_firing_started)
	beam_hazard.lethal_hit_imminent.connect(_on_beam_lethal_hit_imminent)
	scenario_dialogue.dialogue_finished.connect(_on_stage_05_dialogue_finished)
	_spawn_surviving_allies()
	observed_reload_count = _player_reload_count()
	running = true
	beam_hazard.setup(battle.arena, combat_player, false)
	spawn_remaining = 0.25
	system_messages.push_message(
		"STAGE 05 // STAGE 04 SURVIVORS: %d" % survivor_count
	)
	if OS.get_cmdline_user_args().has("--stage-05-smoke"):
		call_deferred("_run_stage_05_smoke")


func _spawn_surviving_allies() -> void:
	allies.clear()
	for ally_index in ALLY_COUNT:
		var ally: AiMechAgent
		if ally_index < survivor_count:
			var group := StringName("STAGE_05_ALLY_%d" % (ally_index + 1))
			for point in story_stage.spawn_points:
				if point.spawn_group == group:
					ally = story_stage._spawn_point(point)
					break
		allies.append(ally)


func _update_ally_support() -> void:
	if not is_instance_valid(combat_player) or combat_player.is_defeated():
		return
	var reload_count := _player_reload_count()
	if reload_count > observed_reload_count and _ally_can_support(0):
		for weapon in combat_player.weapons:
			weapon.accelerate_reload(RELOAD_SUPPORT_MULTIPLIER)
		_begin_support_approach(0)
		system_messages.push_message("아군1 / 재장전을 도와줄게!")
	observed_reload_count = reload_count

	if combat_player.energy_ratio() <= 0.5 and energy_support_armed and _ally_can_support(1):
		energy_support_armed = false
		combat_player.restore_energy_full()
		_begin_support_approach(1)
		system_messages.push_message("아군2 / 배터리라면 내가 충전해줄 수 있어!")
	elif combat_player.energy_ratio() > 0.55:
		energy_support_armed = true

	var cooling := combat_player.heat_generation_locked
	if cooling and not player_was_cooling and _ally_can_support(2):
		combat_player.clear_overheat()
		_begin_support_approach(2)
		system_messages.push_message("아군3 / 방열이 필요한가?")
	player_was_cooling = combat_player.heat_generation_locked


func _player_reload_count() -> int:
	var count := 0
	for weapon in combat_player.weapons:
		count += weapon.reload_count
	return count


func _ally_can_support(index: int) -> bool:
	return (
		index >= 0
		and index < allies.size()
		and is_instance_valid(allies[index])
		and not allies[index].is_defeated()
	)


func _begin_support_approach(index: int) -> void:
	if not _ally_can_support(index):
		return
	var ally := allies[index]
	var previous_tween := ally_support_tweens.get(index) as Tween
	if previous_tween != null and previous_tween.is_valid():
		previous_tween.kill()
	ally.combat_actions_enabled = false
	var destination: Vector2 = combat_player.global_position + SUPPORT_OFFSETS[index]
	var tween := create_tween()
	tween.tween_property(ally, "global_position", destination, SUPPORT_APPROACH_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_finish_support_approach.bind(index, ally))
	ally_support_tweens[index] = tween


func _finish_support_approach(index: int, ally: AiMechAgent) -> void:
	ally_support_tweens.erase(index)
	if is_instance_valid(ally) and not ally.is_defeated():
		ally.combat_actions_enabled = true


func spawn_drone(forced_kind := -1) -> DroneAgent:
	if not is_instance_valid(combat_player) or part_catalog == null:
		return null
	if forced_kind < 0 and _living_drone_count() >= MAX_LIVING_DRONES:
		return null
	var kind := forced_kind
	if kind < 0:
		kind = drone_sequence % 3
	var part_type := MechPartSpec.PartType.HEAD
	match kind:
		DroneAgent.DroneKind.LEGS:
			part_type = MechPartSpec.PartType.LEGS
		DroneAgent.DroneKind.ARM:
			part_type = MechPartSpec.PartType.ARM_EQUIPMENT
	var candidates: Array = part_catalog.parts_by_type[part_type]
	if kind == DroneAgent.DroneKind.ARM:
		candidates = candidates.filter(func(part: MechPartSpec) -> bool:
			return part.weapon != null
		)
	if candidates.is_empty():
		push_error("Stage 5 has no valid drone parts for kind %d" % kind)
		return null
	drone_sequence += 1
	var part := candidates[rng.randi_range(0, candidates.size() - 1)] as MechPartSpec
	var drone := DRONE_AGENT.new() as DroneAgent
	drone.setup_drone(
		part,
		kind,
		battle.projectile_layer,
		battle.arena,
		combat_player,
		drone_sequence
	)
	drone.position = _drone_spawn_position()
	battle.add_combatant(drone)
	ALIEN_INFESTATION_OVERLAY.attach_to(drone)
	drones_spawned += 1
	return drone


func _drone_spawn_position() -> Vector2:
	var minimum: Vector2 = battle.arena.position + Vector2.ONE * 80.0
	var maximum: Vector2 = battle.arena.end - Vector2.ONE * 80.0
	for _attempt in 12:
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var candidate := (combat_player.global_position + direction * rng.randf_range(900.0, 1300.0)).clamp(
			minimum,
			maximum
		)
		if candidate.distance_to(combat_player.global_position) >= 800.0:
			return candidate
	return minimum if minimum.distance_squared_to(combat_player.global_position) > maximum.distance_squared_to(combat_player.global_position) else maximum


func _living_drone_count() -> int:
	var count := 0
	for agent in battle.agents:
		if (
			is_instance_valid(agent)
			and agent.unit_class == AiMechAgent.UnitClass.DRONE
			and not agent.is_defeated()
		):
			count += 1
	return count


func _on_stage_agent_defeated(agent: AiMechAgent) -> void:
	if not running or not is_instance_valid(agent) or agent.unit_class != AiMechAgent.UnitClass.DRONE:
		return
	if agent is DroneAgent and agent.destroyed_by_contact:
		return
	drones_defeated += 1
	system_messages.push_message("DRONE DESTROYED // %02d/%02d" % [drones_defeated, DRONE_TARGET])
	_remove_drone_after_frame(agent)
	if drones_defeated >= BEAM_UNLOCK_DRONE_KILLS and not beam_hazard.active:
		beam_hazard.activate()
	if drones_defeated >= DRONE_TARGET:
		running = false
		beam_hazard.active = false
		beam_hazard.queue_redraw()
		_finish_stage_success()


func _remove_drone_after_frame(agent: AiMechAgent) -> void:
	await get_tree().process_frame
	if is_instance_valid(battle) and is_instance_valid(agent):
		battle.remove_combatant(agent)


func _on_stage_player_defeated() -> void:
	if not running:
		return
	running = false
	beam_hazard.active = false
	beam_hazard.queue_redraw()
	finish_mission(false, "MISSION FAILED // COMBAT UNIT DISABLED")


func _finish_stage_success() -> void:
	if mission_finished:
		return
	mission_finished = true
	system_messages.push_message("MISSION COMPLETE // DRONE SCREEN ELIMINATED")
	overlay.show_result_message("STAGE CLEAR")
	GameSession.set_stage_05_cutscene_snapshot(_capture_cutscene_snapshot())
	if _is_smoke_test():
		return
	await get_tree().create_timer(RESULT_DELAY_SECONDS).timeout
	var error := SceneTransition.transition_to(STAGE_05_CUTSCENE_PATH)
	if error != OK:
		push_error("Unable to start Stage 5 cutscene: %s" % error_string(error))


func _capture_cutscene_snapshot() -> Dictionary:
	var surviving_allies: Array[Dictionary] = []
	for ally in allies:
		if is_instance_valid(ally) and not ally.is_defeated():
			surviving_allies.append({
				"unit_id": str(ally.name),
				"position": ally.global_position,
			})
	var surviving_enemies: Array[Dictionary] = []
	for agent in battle.agents:
		if not agent is DroneAgent or not is_instance_valid(agent) or agent.is_defeated():
			continue
		var drone := agent as DroneAgent
		surviving_enemies.append({
			"unit_id": str(drone.name),
			"kind": DroneAgent.DroneKind.keys()[drone.drone_kind],
			"part_id": drone.drone_part.part_id,
			"position": drone.global_position,
			"rotation": drone.rotation,
		})
	return {
		"schema_version": 1,
		"rescued_ally_count": survivor_count,
		"camera": {
			"position": battle.camera.global_position,
			"zoom": battle.camera.zoom,
		},
		"player": {"position": combat_player.global_position},
		"allies": surviving_allies,
		"enemies": surviving_enemies,
	}


func _on_beam_warning_started(_target_x: float) -> void:
	if running:
		system_messages.push_message("VERTICAL BEAM WARNING // MOVE CLEAR")
	if not running or beam_intro_played:
		return
	beam_intro_played = true
	beam_intro_active = true
	beam_hazard.process_mode = Node.PROCESS_MODE_DISABLED
	if not scenario_dialogue.play_document(BEAM_WARNING_DIALOGUE, "stage_05.gd"):
		_resume_after_beam_intro()


func _on_stage_05_dialogue_finished(scenario_id: String) -> void:
	if scenario_id == "stage_05_beam_warning":
		_resume_after_beam_intro()


func _resume_after_beam_intro() -> void:
	beam_intro_active = false
	beam_hazard.process_mode = Node.PROCESS_MODE_INHERIT


func _on_beam_firing_started(_target_x: float) -> void:
	if running:
		system_messages.push_message("VERTICAL BEAM FIRING")


func _on_beam_lethal_hit_imminent(_target_x: float) -> void:
	if not running or not _ally_can_support(3):
		return
	var ally := allies[3]
	beam_hazard.intercept_current_firing()
	ally.global_position = combat_player.global_position + combat_player.torso_forward() * 90.0
	ally.rotation = combat_player.rotation
	if not scenario_dialogue.play_document(ALLY_4_DIALOGUE, "stage_05.gd"):
		system_messages.push_message("아군4 / 한눈 팔았군, 두번은 도와줄 수 없으니 다음엔 실수하지 마!")
	var body_durability := float(ally.part_durability.get(&"Body", 0.0))
	if body_durability > 0.0:
		ally.register_hit(&"Body", Vector2.UP, body_durability)


func _run_stage_05_smoke() -> void:
	assert(DRONE_TARGET == 20)
	assert(ResourceLoader.exists(STAGE_05_CUTSCENE_PATH, "PackedScene"))
	assert(MAX_LIVING_DRONES == 4)
	assert(not battle.floor_tile_enabled)
	var black_floor := $CombatContainer/CombatViewport/BlackFloor as Polygon2D
	assert(black_floor.color == Color.BLACK and black_floor.z_index < 0)
	var map_background := $CombatContainer/CombatViewport/MapBackground as Sprite2D
	assert(map_background.texture.resource_path == "res://Sprites/Background/Stage5.png")
	assert(map_background.position == Vector2(0.0, -500.0))
	assert(battle.arena == Rect2(-1600.0, -250.0, 3200.0, 750.0))
	assert(map_background.material is ShaderMaterial)
	assert(is_equal_approx(beam_hazard.beam_width, 200.0))
	assert(is_equal_approx(beam_hazard.warning_duration, 5.0))
	var maximum_visible_height: float = (
		battle.get_viewport_rect().size.y / battle._map_fit_zoom()
	)
	assert(beam_hazard.firing_beam_length >= battle.arena.size.y + maximum_visible_height)
	assert(is_equal_approx(beam_hazard.fade_out_duration, 2.0))
	assert(is_equal_approx(
		beam_hazard.warning_duration
		+ beam_hazard.firing_duration
		+ beam_hazard.cooldown_duration,
		15.0
	))
	assert(not beam_hazard.active and BEAM_UNLOCK_DRONE_KILLS == 2)
	assert(survivor_count == ALLY_COUNT and allies.size() == ALLY_COUNT)
	for ally in allies:
		assert(is_instance_valid(ally) and not ally.is_defeated())
	assert(pause_menu_context()["drone_target"] == 20)
	assert(pause_menu_context()["drones_defeated"] == 0)
	var reload_weapon := combat_player.weapons[0]
	reload_weapon.ammo = maxi(reload_weapon.ammo - 1, 0)
	assert(reload_weapon.force_reload())
	var reload_before_support := reload_weapon.reload_remaining
	_update_ally_support()
	assert(is_equal_approx(reload_weapon.reload_remaining, reload_before_support / RELOAD_SUPPORT_MULTIPLIER))
	combat_player.current_energy = combat_player.energy_capacity() * 0.5
	_update_ally_support()
	assert(is_equal_approx(combat_player.energy_ratio(), 1.0))
	combat_player.current_heat = AiMechAgent.MAX_HEAT
	combat_player.heat_generation_locked = true
	_update_ally_support()
	assert(is_zero_approx(combat_player.current_heat) and not combat_player.heat_generation_locked)
	spawn_remaining = 999.0
	var forced_drone := spawn_drone(DroneAgent.DroneKind.ARM)
	assert(forced_drone != null and forced_drone.drone_kind == DroneAgent.DroneKind.ARM)
	assert(forced_drone.has_meta(ALIEN_INFESTATION_OVERLAY.META_KEY))
	var infestation := forced_drone.get_meta(ALIEN_INFESTATION_OVERLAY.META_KEY) as AlienInfestationOverlay
	assert(infestation.infestation_points.size() == AlienInfestationOverlay.POINT_COUNT)
	assert(is_equal_approx(forced_drone.weapon_runtime.fire_rate_multiplier, 1.0 / 5.0))
	assert(is_equal_approx(
		forced_drone.arm_projectile_spec.damage,
		forced_drone.drone_part.weapon.projectile.damage / 3.0
	))
	assert(drones_spawned == 1 and _living_drone_count() == 1)
	var spawned_test_drones: Array[DroneAgent] = [forced_drone]
	for kind in [DroneAgent.DroneKind.HEAD, DroneAgent.DroneKind.LEGS, DroneAgent.DroneKind.ARM]:
		var spawned_test_drone := spawn_drone(kind)
		assert(spawned_test_drone != null)
		spawned_test_drones.append(spawned_test_drone)
	assert(_living_drone_count() == MAX_LIVING_DRONES)
	assert(spawn_drone() == null)
	var removed_test_drone: DroneAgent = spawned_test_drones.pop_back()
	battle.remove_combatant(removed_test_drone)
	drones_spawned = DRONE_TARGET
	assert(spawn_drone() != null)
	drones_defeated = BEAM_UNLOCK_DRONE_KILLS - 1
	_on_stage_agent_defeated(forced_drone)
	assert(beam_hazard.active and beam_intro_active)
	assert(scenario_dialogue.current_speaker() == "오퍼레이터")
	assert(beam_hazard.process_mode == Node.PROCESS_MODE_DISABLED)
	scenario_dialogue.advance()
	assert(not beam_intro_active and beam_hazard.process_mode == Node.PROCESS_MODE_INHERIT)
	drones_defeated = 0
	var event_counts := [0, 0]
	beam_hazard.warning_started.connect(func(_x: float) -> void: event_counts[0] += 1)
	beam_hazard.firing_started.connect(func(_x: float) -> void: event_counts[1] += 1)
	var original_player := beam_hazard.player
	beam_hazard._begin_warning()
	assert(beam_hazard.preparation_audio.playing)
	beam_hazard.player = null
	beam_hazard._begin_firing()
	beam_hazard._begin_cooldown()
	assert(is_equal_approx(beam_hazard.fade_remaining, 2.0))
	beam_hazard.player = original_player
	assert(event_counts == [1, 1])
	assert(beam_hazard.state == VerticalBeamHazard.State.COOLDOWN)
	assert(not combat_player.is_defeated())
	beam_hazard.player = combat_player
	beam_hazard.target_x = combat_player.global_position.x
	beam_hazard.damaged_this_firing = false
	beam_hazard.intercepted_this_firing = false
	beam_hazard._damage_player_once()
	assert(beam_hazard.intercepted_this_firing)
	assert(allies[3].is_defeated())
	assert(not combat_player.is_defeated())
	assert(scenario_dialogue.active)
	assert(scenario_dialogue.current_speaker() == "아군4")
	combat_player.dash_direction = Vector2.LEFT
	combat_player.dash_time_remaining = 0.5
	combat_player.velocity = Vector2.LEFT * 100.0
	forced_drone._on_contact_area_entered(combat_player.part_hitboxes[&"Body"])
	assert(forced_drone.is_defeated())
	assert(drones_defeated == 0)
	assert(not combat_player.is_dashing() and combat_player.velocity.is_zero_approx())
	_finish_stage_success()
	assert(mission_finished and not GameSession.stage_05_cutscene_snapshot.is_empty())
	GameSession.clear_stage_05_cutscene_snapshot()
	beam_hazard.preparation_audio.stop()
	print("STAGE_05_CHECK passed")
	get_tree().quit(0)
