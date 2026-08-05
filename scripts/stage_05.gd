extends StoryMission

const DRONE_AGENT := preload("res://scripts/drone_agent.gd")
const PARTS_DATA_PATH := "res://data/mech_parts.json"
const DRONE_TARGET := 20
const MAX_LIVING_DRONES := 4
const DRONE_SPAWN_INTERVAL := 1.5

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


func pause_menu_context() -> Dictionary:
	var context := super.pause_menu_context()
	context["drones_defeated"] = drones_defeated
	context["drone_target"] = DRONE_TARGET
	context["drones_active"] = _living_drone_count() if is_instance_valid(battle) else 0
	context["survivors"] = survivor_count
	return context


func _process(delta: float) -> void:
	super(delta)
	if not running or mission_finished or drones_spawned >= DRONE_TARGET:
		return
	spawn_remaining -= delta
	if spawn_remaining <= 0.0 and _living_drone_count() < MAX_LIVING_DRONES:
		spawn_drone()
		spawn_remaining = DRONE_SPAWN_INTERVAL


func _on_combat_bound() -> void:
	super._on_combat_bound()
	survivor_count = int(GameSession.story_flag(&"stage_04_survivors", 0))
	part_catalog = MechPartCatalog.new()
	if not part_catalog.load_file(PARTS_DATA_PATH, battle.weapon_catalog):
		push_error("Unable to initialize Stage 5 part catalog")
		return
	rng.seed = 5052026
	battle.agent_defeated.connect(_on_stage_agent_defeated)
	combat_player.defeated.connect(_on_stage_player_defeated)
	beam_hazard.warning_started.connect(_on_beam_warning_started)
	beam_hazard.firing_started.connect(_on_beam_firing_started)
	running = true
	beam_hazard.setup(battle.arena, combat_player)
	spawn_remaining = 0.25
	system_messages.push_message(
		"STAGE 05 // STAGE 04 SURVIVORS: %d" % survivor_count
	)
	if OS.get_cmdline_user_args().has("--stage-05-smoke"):
		call_deferred("_run_stage_05_smoke")


func spawn_drone(forced_kind := -1) -> DroneAgent:
	if not is_instance_valid(combat_player) or part_catalog == null:
		return null
	if forced_kind < 0 and (
		drones_spawned >= DRONE_TARGET
		or _living_drone_count() >= MAX_LIVING_DRONES
	):
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
	drones_defeated += 1
	system_messages.push_message("DRONE DESTROYED // %02d/%02d" % [drones_defeated, DRONE_TARGET])
	_remove_drone_after_frame(agent)
	if drones_defeated >= DRONE_TARGET:
		running = false
		beam_hazard.active = false
		beam_hazard.queue_redraw()
		finish_mission(true, "MISSION COMPLETE // DRONE SCREEN ELIMINATED")


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


func _on_beam_warning_started(_target_x: float) -> void:
	if running:
		system_messages.push_message("VERTICAL BEAM WARNING // MOVE CLEAR")


func _on_beam_firing_started(_target_x: float) -> void:
	if running:
		system_messages.push_message("VERTICAL BEAM FIRING")


func _run_stage_05_smoke() -> void:
	assert(DRONE_TARGET == 20)
	assert(MAX_LIVING_DRONES == 4)
	assert(not battle.floor_tile_enabled)
	var black_floor := $CombatContainer/CombatViewport/BlackFloor as Polygon2D
	assert(black_floor.color == Color.BLACK and black_floor.z_index < 0)
	assert(is_equal_approx(beam_hazard.beam_width, 200.0))
	assert(is_equal_approx(beam_hazard.warning_duration, 2.0))
	assert(survivor_count == int(GameSession.story_flag(&"stage_04_survivors", 0)))
	assert(pause_menu_context()["drone_target"] == 20)
	assert(pause_menu_context()["drones_defeated"] == 0)
	spawn_remaining = 999.0
	var forced_drone := spawn_drone(DroneAgent.DroneKind.ARM)
	assert(forced_drone != null and forced_drone.drone_kind == DroneAgent.DroneKind.ARM)
	assert(drones_spawned == 1 and _living_drone_count() == 1)
	for kind in [DroneAgent.DroneKind.HEAD, DroneAgent.DroneKind.LEGS, DroneAgent.DroneKind.ARM]:
		assert(spawn_drone(kind) != null)
	assert(_living_drone_count() == MAX_LIVING_DRONES)
	assert(spawn_drone() == null)
	var spawned_before_target_check := drones_spawned
	drones_spawned = DRONE_TARGET
	assert(spawn_drone() == null)
	drones_spawned = spawned_before_target_check
	var event_counts := [0, 0]
	beam_hazard.warning_started.connect(func(_x: float) -> void: event_counts[0] += 1)
	beam_hazard.firing_started.connect(func(_x: float) -> void: event_counts[1] += 1)
	var original_player := beam_hazard.player
	beam_hazard._begin_warning()
	beam_hazard.player = null
	beam_hazard._begin_firing()
	beam_hazard._begin_cooldown()
	beam_hazard.player = original_player
	assert(event_counts == [1, 1])
	assert(beam_hazard.state == VerticalBeamHazard.State.COOLDOWN)
	assert(not combat_player.is_defeated())
	beam_hazard.player = combat_player
	beam_hazard.target_x = combat_player.global_position.x
	beam_hazard.damaged_this_firing = false
	beam_hazard._damage_player_once()
	assert(combat_player.is_defeated())
	print("STAGE_05_CHECK passed")
	get_tree().quit(0)
