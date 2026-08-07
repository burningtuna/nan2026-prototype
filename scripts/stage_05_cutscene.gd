extends StoryMission

const DIALOGUE_PATH := "res://data/scenarios/stage_05_cutscene.json"
const FINAL_BATTLE_PATH := "res://scenes/final_battle.tscn"
const DRONE_AGENT := preload("res://scripts/drone_agent.gd")
const ALIEN_INFESTATION_OVERLAY := preload("res://scripts/alien_infestation_overlay.gd")
const CUTSCENE_SNAPSHOT := preload("res://scripts/stage_05_cutscene_snapshot.gd")
const PROJECTILE_TRAIL := preload("res://scripts/projectile_trail.gd")
const WRECK_FIRE_EFFECT := preload("res://scripts/wreck_fire_effect.gd")
const BEAM_TEXTURE := preload("res://Sprites/Effects/Stage5-Boss-Laser-Beam.png")
const BEAM_STREAM := preload("res://Sounds/combat/doomsday_laser_cannon_midium_.wav")
const DASH_FRAMES := [
	"res://Sprites/Dash-0001.png",
	"res://Sprites/Dash-0002.png",
	"res://Sprites/Dash-0003.png",
]
const BOSS_START_OFFSET := Vector2(-480.0, 320.0)
const BOSS_FLIGHT_OFFSET := Vector2(480.0, -11500.0)
const CAMERA_TRAIL_OFFSET := Vector2(0.0, 300.0)
const BOSS_FLIGHT_SECONDS := 7.0
const UFO_BASE_RADIUS := 768.0
const IMPACT_FLASH_SECONDS := 0.45
const BEAM_PREPARATION_SECONDS := 5.0
const BEAM_FLIGHT_DELAY_SECONDS := BEAM_PREPARATION_SECONDS
const BEAM_FIRING_SECONDS := 0.35
const BEAM_FADE_SECONDS := 2.0
const BEAM_WIDTH := 200.0
const BEAM_LENGTH := 6000.0
const BOSS_TRAIL_SPACING_MULTIPLIER := 0.25
const BOSS_TRAIL_MAX_POINTS := 256
const UFO_SHAKE_STRENGTH := 28.0
const UFO_SHAKE_STEP_SECONDS := 0.055
const DEFAULT_DRONE_PARTS := {
	"HEAD": "raven_sensor",
	"LEGS": "strider_legs",
	"ARM": "viper_rotary_arm",
}

@onready var impact_flash: ColorRect = \
	$CombatContainer/CombatViewport/OverlayLayer/ImpactFlash
@onready var ufo_placeholder: Node2D = \
	$CombatContainer/CombatViewport/UfoPlaceholder
@onready var cutscene_world: SubViewport = $CombatContainer/CombatViewport

var snapshot: Dictionary
var dialogue_data: Dictionary
var boss: AiMechAgent
var spawned_allies: Array[AiMechAgent] = []
var spawned_enemies: Array[DroneAgent] = []
var static_unit_positions := {}
var phase := &"preparing"
var boss_flight_target := Vector2.ZERO
var flight_camera_zoom := Vector2.ONE
var cutscene_complete := false
var boss_strike_audio: AudioStreamPlayer
var boss_strike_beam: Sprite2D
var boss_trail: ProjectileTrail
var boss_fire: WreckFireEffect
var ufo_shake_tween: Tween
var camera_rest_offset := Vector2.ZERO


func _on_combat_bound() -> void:
	super._on_combat_bound()
	if not _load_dialogue_data():
		push_error("Unable to load Stage 5 cutscene dialogue")
		_abort_cutscene()
		return
	snapshot = CUTSCENE_SNAPSHOT.normalize(GameSession.take_stage_05_cutscene_snapshot())
	_apply_snapshot()
	_freeze_battle()
	_configure_flight_composition()
	_configure_boss_strike_audio()
	scenario_dialogue.dialogue_finished.connect(_on_cutscene_dialogue_finished)
	scenario_dialogue.line_changed.connect(_on_cutscene_line_changed)
	phase = &"opening"
	if not scenario_dialogue.play_document(_opening_dialogue(), DIALOGUE_PATH):
		_abort_cutscene()
		return
	if OS.get_cmdline_user_args().has("--stage-05-cutscene-smoke"):
		call_deferred("_run_stage_05_cutscene_smoke")


func _load_dialogue_data() -> bool:
	if not FileAccess.file_exists(DIALOGUE_PATH):
		return false
	var file := FileAccess.open(DIALOGUE_PATH, FileAccess.READ)
	if file == null:
		return false
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return false
	dialogue_data = parser.data
	if not (
		int(dialogue_data.get("schema_version", 0)) == 1
		and dialogue_data.get("opening") is Array
		and dialogue_data.get("branches") is Dictionary
		and dialogue_data.get("aftermath") is Array
	):
		return false
	var branches: Dictionary = dialogue_data["branches"]
	return (
		_valid_dialogue_lines(dialogue_data["opening"])
		and _valid_dialogue_lines(dialogue_data["aftermath"])
		and branches.has_all(["low", "normal", "high"])
		and _valid_dialogue_lines(branches["low"])
		and _valid_dialogue_lines(branches["normal"])
		and _valid_dialogue_lines(branches["high"])
	)


func _valid_dialogue_lines(lines) -> bool:
	if not lines is Array or lines.is_empty():
		return false
	for entry in lines:
		if (
			not entry is Dictionary
			or str(entry.get("speaker", "")).strip_edges().is_empty()
			or str(entry.get("text", "")).strip_edges().is_empty()
		):
			return false
	return true


func _apply_snapshot() -> void:
	combat_player.global_position = snapshot["player"]["position"]
	for ally_data: Dictionary in snapshot["allies"]:
		var point := _spawn_point_for_unit(str(ally_data["unit_id"]))
		if point == null:
			continue
		var ally := story_stage._spawn_point(point)
		if ally == null:
			continue
		ally.global_position = ally_data["position"]
		spawned_allies.append(ally)
	_spawn_snapshot_enemies()
	boss = _spawned_agent_for_unit("ARENA-BOSS")
	if is_instance_valid(boss):
		boss.global_position = combat_player.global_position + BOSS_START_OFFSET
		boss_flight_target = boss.global_position + BOSS_FLIGHT_OFFSET
		ufo_placeholder.global_position = boss_flight_target
		_configure_boss_flight_visual()
	var camera_data: Dictionary = snapshot["camera"]
	battle.camera.global_position = camera_data["position"]
	battle.camera.zoom = camera_data["zoom"]
	for agent in battle.agents:
		if not is_instance_valid(agent):
			continue
		agent.combat_actions_enabled = false
		agent.velocity = Vector2.ZERO
		static_unit_positions[agent.get_instance_id()] = agent.global_position


func _spawn_snapshot_enemies(enemy_entries = null) -> void:
	var entries: Array = snapshot["enemies"] if enemy_entries == null else enemy_entries
	var sequence := 0
	for enemy_data: Dictionary in entries:
		sequence += 1
		var kind := _drone_kind(str(enemy_data["kind"]))
		var part := _drone_part(enemy_data, kind)
		if part == null:
			continue
		var drone := DRONE_AGENT.new() as DroneAgent
		drone.setup_drone(
			part,
			kind,
			battle.projectile_layer,
			battle.arena,
			combat_player,
			900 + sequence
		)
		drone.name = str(enemy_data["unit_id"])
		drone.position = enemy_data["position"]
		drone.rotation = float(enemy_data["rotation"])
		battle.add_combatant(drone)
		ALIEN_INFESTATION_OVERLAY.attach_to(drone)
		spawned_enemies.append(drone)


func _configure_boss_flight_visual() -> void:
	var flight_direction := BOSS_FLIGHT_OFFSET.normalized()
	boss.rotation = flight_direction.angle() + PI * 0.5
	boss.lower_body.rotation = 0.0
	boss.upper_body.rotation = 0.0
	var frames := SpriteFrames.new()
	frames.add_animation(&"cutscene_dash")
	frames.set_animation_loop(&"cutscene_dash", true)
	frames.set_animation_speed(&"cutscene_dash", 12.0)
	for texture_path in DASH_FRAMES:
		frames.add_frame(&"cutscene_dash", load(texture_path) as Texture2D)
	for boost in boss.boost_sprites:
		boost.sprite_frames = frames
		boost.animation = &"cutscene_dash"
		boost.position += Vector2(0.0, 1.5)
		boost.visible = false
		boost.stop()


func _set_boss_dash_visible(value: bool) -> void:
	if not is_instance_valid(boss):
		return
	for boost in boss.boost_sprites:
		boost.visible = value
		if value:
			boost.play(&"cutscene_dash")
		else:
			boost.stop()


func _drone_kind(kind_name: String) -> DroneAgent.DroneKind:
	match kind_name:
		"LEGS":
			return DroneAgent.DroneKind.LEGS
		"ARM":
			return DroneAgent.DroneKind.ARM
	return DroneAgent.DroneKind.HEAD


func _drone_part(enemy_data: Dictionary, kind: DroneAgent.DroneKind) -> MechPartSpec:
	var requested_id := str(enemy_data.get("part_id", ""))
	if requested_id.is_empty():
		requested_id = DEFAULT_DRONE_PARTS[str(enemy_data["kind"])]
	var part := story_stage.part_catalog.parts_by_id.get(requested_id) as MechPartSpec
	var expected_type := MechPartSpec.PartType.HEAD
	if kind == DroneAgent.DroneKind.LEGS:
		expected_type = MechPartSpec.PartType.LEGS
	elif kind == DroneAgent.DroneKind.ARM:
		expected_type = MechPartSpec.PartType.ARM_EQUIPMENT
	if part == null or part.part_type != expected_type or (kind == DroneAgent.DroneKind.ARM and part.weapon == null):
		part = story_stage.part_catalog.parts_by_id.get(
			DEFAULT_DRONE_PARTS[str(enemy_data["kind"])]
		) as MechPartSpec
	return part


func _spawn_point_for_unit(unit_id: String) -> StorySpawnPoint:
	for point in story_stage.spawn_points:
		if point.unit_id == unit_id:
			return point
	return null


func _spawned_agent_for_unit(unit_id: String) -> AiMechAgent:
	var point := _spawn_point_for_unit(unit_id)
	return story_stage.spawned_points.get(point.get_instance_id()) as AiMechAgent if point != null else null


func _freeze_battle() -> void:
	_set_player_hud_visible(false)
	overlay.set_combat_hud_visible(false)
	system_messages.visible = false
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	set_process(false)


func _configure_flight_composition() -> void:
	var zoom_value: float = battle._map_fit_zoom()
	flight_camera_zoom = Vector2.ONE * zoom_value
	var viewport_height := float(battle.get_viewport_rect().size.y)
	ufo_placeholder.scale = Vector2.ONE * (
		viewport_height / maxf(zoom_value, 0.0001) / UFO_BASE_RADIUS
	)


func _configure_boss_strike_audio() -> void:
	boss_strike_audio = AudioStreamPlayer.new()
	boss_strike_audio.name = "BossStrikeAudio"
	boss_strike_audio.stream = BEAM_STREAM
	add_child(boss_strike_audio)


func _opening_dialogue() -> Dictionary:
	var lines: Array = dialogue_data["opening"].duplicate(true)
	var branches: Dictionary = dialogue_data["branches"]
	lines.append_array(branches[_branch_key()].duplicate(true))
	return {
		"schema_version": 1,
		"id": "stage_05_cutscene_opening",
		"dialogue": lines,
	}


func _branch_key() -> String:
	var rescued_count := int(snapshot["rescued_ally_count"])
	if rescued_count <= 0:
		return "low"
	if rescued_count >= 4:
		return "high"
	return "normal"


func _aftermath_dialogue() -> Dictionary:
	return {
		"schema_version": 1,
		"id": "stage_05_cutscene_aftermath",
		"dialogue": dialogue_data["aftermath"].duplicate(true),
	}


func _on_cutscene_dialogue_finished(scenario_id: String) -> void:
	if scenario_id == "stage_05_cutscene_opening" and phase == &"opening":
		_start_boss_flight()
	elif scenario_id == "stage_05_cutscene_aftermath" and phase == &"aftermath":
		_complete_cutscene()


func _on_cutscene_line_changed(index: int, speaker: String, _text: String) -> void:
	if (
		scenario_dialogue.scenario_id == "stage_05_cutscene_aftermath"
		and index == 0
		and speaker == "오퍼레이터"
	):
		_start_ufo_camera_shake()


func _start_ufo_camera_shake() -> void:
	_stop_ufo_camera_shake()
	camera_rest_offset = battle.camera.offset
	ufo_shake_tween = create_tween().set_loops()
	for offset_direction in [
		Vector2(0.8, -0.45),
		Vector2(-0.65, 0.7),
		Vector2(0.4, 0.8),
		Vector2(-0.85, -0.35),
		Vector2(0.25, -0.75),
		Vector2.ZERO,
	]:
		ufo_shake_tween.tween_property(
			battle.camera,
			"offset",
			camera_rest_offset + offset_direction * UFO_SHAKE_STRENGTH,
			UFO_SHAKE_STEP_SECONDS
		)


func _stop_ufo_camera_shake() -> void:
	if is_instance_valid(ufo_shake_tween):
		ufo_shake_tween.kill()
		ufo_shake_tween = null
	if is_instance_valid(battle) and is_instance_valid(battle.camera):
		battle.camera.offset = camera_rest_offset


func _start_boss_flight() -> void:
	if not is_instance_valid(boss):
		_play_aftermath_dialogue()
		return
	boss_strike_audio.play()
	_begin_boss_flight()


func _fire_boss_strike() -> void:
	_spawn_boss_strike_beam()
	_attach_boss_impact_fire()


func _spawn_boss_strike_beam() -> void:
	boss_strike_beam = Sprite2D.new()
	boss_strike_beam.name = "BossStrikeBeam"
	boss_strike_beam.texture = BEAM_TEXTURE
	boss_strike_beam.scale = Vector2(
		BEAM_WIDTH / float(BEAM_TEXTURE.get_width()),
		BEAM_LENGTH / float(BEAM_TEXTURE.get_height())
	)
	boss_strike_beam.z_index = 12
	cutscene_world.add_child(boss_strike_beam)
	boss_strike_beam.global_position = boss.global_position
	var fade := create_tween()
	fade.tween_interval(BEAM_FIRING_SECONDS)
	fade.tween_property(
		boss_strike_beam,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		BEAM_FADE_SECONDS
	)
	fade.finished.connect(boss_strike_beam.queue_free)


func _attach_boss_trail() -> void:
	var flight_direction := BOSS_FLIGHT_OFFSET.normalized()
	boss_trail = PROJECTILE_TRAIL.new() as ProjectileTrail
	boss_trail.name = "BossRocketTrail"
	boss_trail.setup(WeaponSpec.WeaponFamily.MISSILE, flight_direction, 4.0, 2.5)
	boss_trail.sample_spacing *= BOSS_TRAIL_SPACING_MULTIPLIER
	boss_trail.max_missile_points = BOSS_TRAIL_MAX_POINTS
	boss_trail.fill_sample_gaps = true
	boss_trail.smoke_expansion_speed_multiplier = 4.0
	boss_trail.process_mode = Node.PROCESS_MODE_ALWAYS
	boss_trail.top_level = true
	boss_trail.z_index = boss.z_index - 1
	cutscene_world.add_child(boss_trail)
	boss_trail.global_position = Vector2.ZERO
	boss_trail.add_sample(boss.global_position)


func _attach_boss_impact_fire() -> void:
	boss_fire = WRECK_FIRE_EFFECT.new() as WreckFireEffect
	boss_fire.name = "BossImpactFire"
	boss_fire.setup(5055300)
	boss_fire.process_mode = Node.PROCESS_MODE_ALWAYS
	boss_fire.position = Vector2(0.0, 4.0)
	boss_fire.scale = Vector2.ONE * 4.0
	boss_fire.z_index = 4
	boss.add_child(boss_fire)


func _begin_boss_flight() -> void:
	phase = &"flight"
	_attach_boss_trail()
	_set_boss_dash_visible(true)
	ufo_placeholder.visible = true
	if OS.get_cmdline_user_args().has("--stage-05-cutscene-smoke"):
		var strike_progress := BEAM_FLIGHT_DELAY_SECONDS / BOSS_FLIGHT_SECONDS
		boss.global_position += BOSS_FLIGHT_OFFSET * strike_progress * strike_progress
		boss_trail.add_sample(boss.global_position)
		_fire_boss_strike()
		boss.global_position = boss_flight_target
		battle.camera.global_position = boss_flight_target + CAMERA_TRAIL_OFFSET
		battle.camera.zoom = flight_camera_zoom
		_on_boss_flight_finished()
		return
	_fire_boss_strike_after_delay()
	var flight := create_tween().set_parallel(true)
	flight.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	flight.tween_property(boss, "global_position", boss_flight_target, BOSS_FLIGHT_SECONDS)
	flight.tween_property(
		battle.camera,
		"global_position",
		boss_flight_target + CAMERA_TRAIL_OFFSET,
		BOSS_FLIGHT_SECONDS
	)
	flight.tween_property(battle.camera, "zoom", flight_camera_zoom, BOSS_FLIGHT_SECONDS)
	flight.tween_method(_sample_boss_trail, 0.0, 1.0, BOSS_FLIGHT_SECONDS)
	flight.finished.connect(_on_boss_flight_finished)


func _fire_boss_strike_after_delay() -> void:
	await get_tree().create_timer(BEAM_FLIGHT_DELAY_SECONDS).timeout
	if phase == &"flight" and is_instance_valid(boss):
		_fire_boss_strike()


func _sample_boss_trail(_progress: float) -> void:
	if is_instance_valid(boss) and is_instance_valid(boss_trail):
		boss_trail.add_sample(boss.global_position)


func _on_boss_flight_finished() -> void:
	_set_boss_dash_visible(false)
	if is_instance_valid(boss_trail):
		if is_instance_valid(boss):
			boss_trail.add_sample(boss.global_position)
		boss_trail.finish()
	if is_instance_valid(boss):
		boss.visible = false
	impact_flash.visible = true
	impact_flash.color = Color.WHITE
	if OS.get_cmdline_user_args().has("--stage-05-cutscene-smoke"):
		impact_flash.color = Color(1.0, 1.0, 1.0, 0.0)
		_play_aftermath_dialogue()
		return
	var flash := create_tween()
	flash.tween_property(
		impact_flash,
		"color",
		Color(1.0, 1.0, 1.0, 0.0),
		IMPACT_FLASH_SECONDS
	)
	await flash.finished
	_play_aftermath_dialogue()


func _play_aftermath_dialogue() -> void:
	phase = &"aftermath"
	if not scenario_dialogue.play_document(_aftermath_dialogue(), DIALOGUE_PATH):
		_abort_cutscene()


func _complete_cutscene() -> void:
	phase = &"complete"
	cutscene_complete = true
	_stop_ufo_camera_shake()
	if OS.get_cmdline_user_args().has("--stage-05-cutscene-smoke"):
		return
	var destination := FINAL_BATTLE_PATH
	if not ResourceLoader.exists(destination):
		push_warning("Final battle scene is not available yet: %s" % destination)
		destination = STAGE_SELECT_PATH
	var error := SceneTransition.transition_to(destination)
	if error != OK:
		push_error("Unable to finish Stage 5 cutscene: %s" % error_string(error))


func _abort_cutscene() -> void:
	phase = &"aborted"
	_stop_ufo_camera_shake()
	if OS.get_cmdline_user_args().has("--stage-05-cutscene-smoke"):
		get_tree().quit(1)
		return
	var error := SceneTransition.transition_to(STAGE_SELECT_PATH)
	if error != OK:
		push_error("Unable to leave invalid Stage 5 cutscene: %s" % error_string(error))


func _run_stage_05_cutscene_smoke() -> void:
	assert(snapshot["rescued_ally_count"] == 4)
	assert(combat_player.global_position.is_equal_approx(Vector2.ZERO))
	var map_background := $CombatContainer/CombatViewport/MapBackground as Sprite2D
	assert(map_background.texture.resource_path == "res://Sprites/Background/Stage5.png")
	assert(map_background.position == Vector2(0.0, -500.0))
	assert(map_background.material is ShaderMaterial)
	assert(spawned_allies.size() == 4 and spawned_enemies.is_empty())
	for index in spawned_allies.size():
		assert(spawned_allies[index].global_position.is_equal_approx(
			CUTSCENE_SNAPSHOT.DEFAULT_ALLY_POSITIONS[index]
		))
	assert(is_instance_valid(boss) and boss.unit_class == AiMechAgent.UnitClass.BOSS)
	var expected_boss_rotation := BOSS_FLIGHT_OFFSET.angle() + PI * 0.5
	assert(is_equal_approx(boss.rotation, expected_boss_rotation))
	assert(ufo_placeholder.global_position.is_equal_approx(boss_flight_target))
	assert(is_equal_approx(BOSS_FLIGHT_SECONDS, 7.0))
	assert(is_equal_approx(BEAM_PREPARATION_SECONDS, 5.0))
	assert(is_equal_approx(BEAM_FLIGHT_DELAY_SECONDS, 5.0))
	assert(is_equal_approx(BEAM_FADE_SECONDS, 2.0))
	assert(boss_strike_audio.stream.resource_path == BEAM_STREAM.resource_path)
	assert(is_equal_approx(flight_camera_zoom.x, battle._map_fit_zoom()))
	assert(is_equal_approx(
		UFO_BASE_RADIUS * ufo_placeholder.scale.x * flight_camera_zoom.x,
		battle.get_viewport_rect().size.y
	))
	for boost in boss.boost_sprites:
		assert(boost.sprite_frames.get_frame_texture(&"cutscene_dash", 0).resource_path == DASH_FRAMES[0])
	assert(battle.process_mode == Node.PROCESS_MODE_DISABLED)
	assert(_branch_key() == "high")
	assert(scenario_dialogue.active and scenario_dialogue.dialogue.size() == 6)

	var custom: Dictionary = CUTSCENE_SNAPSHOT.normalize({
		"schema_version": 1,
		"rescued_ally_count": 2,
		"player": {"position": Vector2(12.0, 34.0)},
		"allies": [{"unit_id": "ALLY-02", "position": Vector2(56.0, 78.0)}],
		"enemies": [
			{"unit_id": "TEST-HEAD", "kind": "HEAD", "position": Vector2(90.0, 12.0)},
			{"unit_id": "TEST-LEGS", "kind": "LEGS", "position": Vector2(110.0, 32.0)},
			{"unit_id": "TEST-ARM", "kind": "ARM", "position": Vector2(130.0, 52.0)},
		],
	})
	assert(custom["rescued_ally_count"] == 2)
	assert(custom["player"]["position"] == Vector2(12.0, 34.0))
	assert(custom["enemies"][2]["kind"] == "ARM")
	_spawn_snapshot_enemies(custom["enemies"])
	assert(spawned_enemies.size() == 3)
	for index in spawned_enemies.size():
		var restored_drone := spawned_enemies[index]
		assert(restored_drone.drone_kind == index)
		assert(restored_drone.drone_part.part_id == DEFAULT_DRONE_PARTS[
			CUTSCENE_SNAPSHOT.DRONE_KINDS[index]
		])
		static_unit_positions[restored_drone.get_instance_id()] = restored_drone.global_position

	var original_rescued_count := int(snapshot["rescued_ally_count"])
	for branch_case in [[0, "low", 5], [2, "normal", 5], [4, "high", 6]]:
		snapshot["rescued_ally_count"] = branch_case[0]
		assert(_branch_key() == branch_case[1])
		assert(_opening_dialogue()["dialogue"].size() == branch_case[2])
	snapshot["rescued_ally_count"] = original_rescued_count

	var fixed_positions := static_unit_positions.duplicate()
	var opening_line_count := scenario_dialogue.dialogue.size()
	for _line in opening_line_count:
		scenario_dialogue.advance()
	assert(phase == &"aftermath")
	assert(is_instance_valid(ufo_shake_tween))
	assert(boss_strike_audio.playing)
	assert(is_instance_valid(boss_strike_beam))
	assert(boss_strike_beam.global_position.x > BOSS_START_OFFSET.x)
	assert(boss_strike_beam.global_position.x < boss_flight_target.x)
	assert(is_instance_valid(boss_trail) and boss_trail.points.size() > 2)
	assert(is_equal_approx(boss_trail.sample_spacing, 1.5))
	assert(boss_trail.max_missile_points == BOSS_TRAIL_MAX_POINTS)
	assert(boss_trail.fill_sample_gaps)
	assert(is_equal_approx(boss_trail.smoke_expansion_speed_multiplier, 4.0))
	assert(is_instance_valid(boss_fire))
	assert(boss.global_position.is_equal_approx(boss_flight_target))
	assert(battle.camera.global_position.is_equal_approx(boss_flight_target + CAMERA_TRAIL_OFFSET))
	assert(battle.camera.zoom.is_equal_approx(flight_camera_zoom))
	for agent in battle.agents:
		if is_instance_valid(agent) and agent != boss:
			assert(agent.global_position.is_equal_approx(fixed_positions[agent.get_instance_id()]))
	assert(scenario_dialogue.active and scenario_dialogue.dialogue.size() == 2)
	scenario_dialogue.advance()
	assert(scenario_dialogue.current_speaker() == "군 지휘관")
	assert(is_instance_valid(ufo_shake_tween))
	scenario_dialogue.advance()
	assert(not is_instance_valid(ufo_shake_tween))
	assert(battle.camera.offset == camera_rest_offset)
	assert(cutscene_complete)
	boss_strike_audio.stop()
	print("STAGE_05_CUTSCENE_CHECK passed")
	get_tree().quit(0)
