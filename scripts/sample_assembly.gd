extends Node2D

const AI_MECH := preload("res://scripts/ai_mech_agent.gd")
const TEST_CANNON := preload("res://data/test_cannon.tres")
const TEST_SHOTGUN := preload("res://data/test_shotgun.tres")
const TEST_MISSILE := preload("res://data/test_missile.tres")
const TEST_ENERGY_CANNON := preload("res://data/test_energy_cannon.tres")
const STEEL_FLOOR_TILE := preload("res://Sprites/Environment/Stage-01-Steel-Floor.png")
const RANDOM_ARM_WEAPONS := [
	preload("res://data/weapon_ballistic_rapid.tres"),
	preload("res://data/weapon_ballistic_standard.tres"),
	preload("res://data/weapon_ballistic_heavy.tres"),
	preload("res://data/weapon_energy_rapid.tres"),
	preload("res://data/weapon_energy_standard.tres"),
	preload("res://data/weapon_energy_heavy.tres"),
	preload("res://data/weapon_missile_rapid.tres"),
	preload("res://data/weapon_missile_standard.tres"),
	preload("res://data/weapon_missile_heavy.tres"),
	preload("res://data/weapon_scatter_rapid.tres"),
	preload("res://data/weapon_scatter_standard.tres"),
	preload("res://data/weapon_scatter_heavy.tres"),
]
const RANDOM_BACKPACK_WEAPONS := [
	preload("res://data/weapon_ballistic_heavy.tres"),
	preload("res://data/weapon_energy_heavy.tres"),
	preload("res://data/weapon_missile_rapid.tres"),
	preload("res://data/weapon_missile_standard.tres"),
	preload("res://data/weapon_missile_heavy.tres"),
	preload("res://data/weapon_scatter_heavy.tres"),
]

@export var arena := Rect2(-5000.0, -5000.0, 10000.0, 10000.0)
@export var framing_margin := Vector2(72.0, 58.0)
@export var minimum_zoom := 0.14
@export var maximum_zoom := 1.8
@export var zoom_in_smoothing := 3.0
@export var two_vs_two := false
@export var enable_player_control := false
@export var randomize_loadouts := false

@onready var camera: Camera2D = $DynamicCamera
@onready var projectile_layer: Node2D = $Projectiles
@onready var camera_status: Label = $UI/CameraStatus
@onready var agent_status: Label = $UI/AgentStatus
@onready var impact_status: Label = $UI/ImpactStatus

var agents: Array = []
var smoke_test_enabled := false
var smoke_elapsed := 0.0
var observed_min_distance := INF
var observed_max_distance := 0.0
var observed_min_zoom := INF
var observed_max_zoom := 0.0
var framing_failed := false
var loadout_rng := RandomNumberGenerator.new()
var initial_camera_zoom := 0.0


func _ready() -> void:
	smoke_test_enabled = OS.get_cmdline_user_args().has("--camera-smoke")
	if randomize_loadouts:
		loadout_rng.randomize()
	_spawn_agents()
	camera.enabled = true
	_update_camera(0.0, true)
	queue_redraw()


func _process(delta: float) -> void:
	_update_camera(delta)
	_update_status()
	queue_redraw()
	if smoke_test_enabled:
		_update_smoke_test(delta)


func _draw() -> void:
	draw_texture_rect(STEEL_FLOOR_TILE, arena.grow(500.0), true)
	draw_rect(arena, Color("485960"), false, 2.0)

	if agents.size() >= 2:
		var direction_line_width := 2.0 / maxf(camera.zoom.x, 0.001)
		for agent in agents:
			if agent.player_controlled:
				continue
			var forward: Vector2 = agent.torso_forward()
			var direction_color := Color("ffd34d") if agent.is_preparing_attack() else Color(0.25, 1.0, 0.35, 0.9)
			var traverse_limit := deg_to_rad(agent.maximum_weapon_traverse_limit_degrees())
			for side in [-1.0, 1.0]:
				var traverse_edge := forward.rotated(traverse_limit * side)
				draw_line(
					agent.position + traverse_edge * 30.0,
					agent.position + traverse_edge * 110.0,
					Color(0.35, 0.8, 1.0, 0.45),
					1.0 / maxf(camera.zoom.x, 0.001)
				)
			draw_line(
				agent.position + forward * 30.0,
				agent.position + forward * 150.0,
				direction_color,
				direction_line_width
			)


func _spawn_agents() -> void:
	var first_loadout: Array[WeaponSpec] = [TEST_CANNON, TEST_MISSILE]
	var second_loadout: Array[WeaponSpec] = [TEST_ENERGY_CANNON, TEST_SHOTGUN, TEST_MISSILE]
	var colors := [Color("8fe5ff"), Color("ff9b8f")]
	var starts := [Vector2(-1000.0, 0.0), Vector2(1000.0, 0.0)]
	var agent_count := 2
	if two_vs_two:
		colors = [Color("71d9e8"), Color("8faeff"), Color("ff776d"), Color("ffb05f")]
		starts = [
			Vector2(-1000.0, -260.0),
			Vector2(-1000.0, 260.0),
			Vector2(1000.0, -260.0),
			Vector2(1000.0, 260.0),
		]
		agent_count = 4
	for index in agent_count:
		var agent = AI_MECH.new()
		var uses_close_range_build := index == 0 or (two_vs_two and index == 1)
		if uses_close_range_build:
			agent.fire_rate_multiplier = 0.5
			agent.weapon_range_multiplier = 0.5
			agent.movement_type = AiMechAgent.MovementType.AGGRESSIVE
		else:
			agent.cruise_speed *= 0.5
			agent.acceleration *= 0.5
			agent.dash_cooldown *= 0.5
			agent.dash_speed *= 0.5
			agent.upper_turn_speed_degrees *= 0.5
			agent.movement_type = AiMechAgent.MovementType.RANGE_KEEPER
			agent.preferred_range = 2000.0
			agent.evasion_range = 1500.0
		var first_enemy_index := 2 if two_vs_two else 1
		agent.team_id = 0 if index < first_enemy_index else 1
		agent.player_controlled = two_vs_two and enable_player_control and index == 0
		var configured_loadout: MechLoadout
		var loadout: Array[WeaponSpec]
		if agent.player_controlled and GameSession.player_mech_loadout != null:
			configured_loadout = GameSession.player_mech_loadout.copy()
			loadout = _weapons_from_mech_loadout(configured_loadout)
		else:
			loadout = (
				_random_weapon_loadout()
				if randomize_loadouts
				else first_loadout if uses_close_range_build else second_loadout
			)
		var agent_name := "AI-%02d" % (index + 1)
		if two_vs_two:
			agent_name = ["PLAYER", "ALLY-01", "ENEMY-01", "ENEMY-02"][index]
		if randomize_loadouts:
			var weapon_names: Array[String] = []
			for weapon_spec in loadout:
				weapon_names.append(weapon_spec.display_name)
			print_verbose("%s LOADOUT: %s" % [agent_name, " / ".join(weapon_names)])
		agent.setup(
			agent_name,
			projectile_layer,
			arena,
			1200 + index * 7919,
			colors[index],
			loadout,
			configured_loadout
		)
		agent.position = starts[index]
		add_child(agent)
		agents.append(agent)

	if two_vs_two:
		var allies := [agents[0], agents[1]]
		var enemies := [agents[2], agents[3]]
		for ally in allies:
			ally.set_opponents(enemies)
		for enemy in enemies:
			enemy.set_opponents(allies)
	else:
		agents[0].set_opponent(agents[1])
		agents[1].set_opponent(agents[0])


func _random_weapon_loadout() -> Array[WeaponSpec]:
	var result: Array[WeaponSpec] = []
	for _arm_slot in 2:
		result.append(RANDOM_ARM_WEAPONS[loadout_rng.randi_range(0, RANDOM_ARM_WEAPONS.size() - 1)])
	result.append(
		RANDOM_BACKPACK_WEAPONS[
			loadout_rng.randi_range(0, RANDOM_BACKPACK_WEAPONS.size() - 1)
		]
	)
	return result


func _weapons_from_mech_loadout(loadout: MechLoadout) -> Array[WeaponSpec]:
	var result: Array[WeaponSpec] = []
	for part in [loadout.left_arm, loadout.right_arm, loadout.backpack]:
		if part != null and part.weapon != null:
			result.append(part.weapon)
	return result


func _update_camera(delta: float, snap := false) -> void:
	var camera_subjects := _camera_subjects()
	if camera_subjects.is_empty():
		return

	var minimum_position: Vector2 = camera_subjects[0].global_position
	var maximum_position := minimum_position
	for agent in camera_subjects:
		minimum_position = minimum_position.min(agent.global_position)
		maximum_position = maximum_position.max(agent.global_position)
	var separation := maximum_position - minimum_position
	var required_size: Vector2 = separation + framing_margin * 2.0
	var viewport_size := get_viewport_rect().size
	var target_zoom := clampf(
		minf(viewport_size.x / required_size.x, viewport_size.y / required_size.y),
		minimum_zoom,
		maximum_zoom
	)
	if initial_camera_zoom <= 0.0:
		initial_camera_zoom = target_zoom
	else:
		target_zoom = maxf(target_zoom, initial_camera_zoom)

	var desired_camera_position := (minimum_position + maximum_position) * 0.5
	var visible_half_extent := viewport_size / target_zoom * 0.5
	var player_safe_extent := (visible_half_extent - framing_margin).max(Vector2.ZERO)
	var player_position: Vector2 = camera_subjects[0].global_position
	desired_camera_position.x = clampf(
		desired_camera_position.x,
		player_position.x - player_safe_extent.x,
		player_position.x + player_safe_extent.x
	)
	desired_camera_position.y = clampf(
		desired_camera_position.y,
		player_position.y - player_safe_extent.y,
		player_position.y + player_safe_extent.y
	)
	camera.global_position = desired_camera_position
	if snap or target_zoom < camera.zoom.x:
		camera.zoom = Vector2.ONE * target_zoom
	else:
		var blend := 1.0 - exp(-zoom_in_smoothing * delta)
		camera.zoom = Vector2.ONE * lerpf(camera.zoom.x, target_zoom, blend)


func _camera_subjects() -> Array[AiMechAgent]:
	var result: Array[AiMechAgent] = []
	var player: AiMechAgent
	for agent in agents:
		if is_instance_valid(agent) and agent.player_controlled:
			player = agent
			break
	if player == null and not agents.is_empty() and is_instance_valid(agents[0]):
		player = agents[0]
	if player == null:
		return result

	result.append(player)
	for agent in agents:
		if (
			is_instance_valid(agent)
			and agent != player
			and agent.team_id != player.team_id
		):
			result.append(agent)
	return result


func _update_status() -> void:
	if agents.size() < 2:
		return
	var distance: float = agents[0].position.distance_to(agents[1].position)
	var visible_size := get_viewport_rect().size / camera.zoom
	camera_status.text = "DIST %3d  ZOOM %.2fx  VIEW %dx%d" % [
		roundi(distance),
		camera.zoom.x,
		roundi(visible_size.x),
		roundi(visible_size.y),
	]
	agent_status.text = "AI1 CLOSE S%02d R%02d SH%02d   AI2 HOLD S%02d R%s SH%02d" % [
		roundi(agents[0].velocity.length()),
		agents[0].reload_count_for(WeaponSpec.WeaponFamily.MISSILE),
		agents[0].shot_count,
		roundi(agents[1].velocity.length()),
		"ON" if agents[1].is_reloading_ballistic() else "--",
		agents[1].shot_count,
	]
	impact_status.text = "F/S/R %02d/%02d/%02d  PREP 01:%s 02:%s" % [
		agents[0].aspect_hits(&"FRONT") + agents[1].aspect_hits(&"FRONT"),
		agents[0].aspect_hits(&"SIDE") + agents[1].aspect_hits(&"SIDE"),
		agents[0].aspect_hits(&"REAR") + agents[1].aspect_hits(&"REAR"),
		agents[0].preparation_label(),
		agents[1].preparation_label(),
	]


func _update_smoke_test(delta: float) -> void:
	var distance: float = agents[0].position.distance_to(agents[1].position)
	observed_min_distance = minf(observed_min_distance, distance)
	observed_max_distance = maxf(observed_max_distance, distance)
	observed_min_zoom = minf(observed_min_zoom, camera.zoom.x)
	observed_max_zoom = maxf(observed_max_zoom, camera.zoom.x)
	var visible_half_extent := get_viewport_rect().size / camera.zoom * 0.5
	for agent in _camera_subjects():
		var occupied_extent: Vector2 = (agent.global_position - camera.global_position).abs() + Vector2.ONE * 32.0
		if occupied_extent.x > visible_half_extent.x or occupied_extent.y > visible_half_extent.y:
			framing_failed = true
	smoke_elapsed += delta
	if smoke_elapsed < 20.0:
		return

	var ballistic_hits: int = (
		agents[0].landed_hits_for(WeaponSpec.WeaponFamily.BALLISTIC)
		+ agents[1].landed_hits_for(WeaponSpec.WeaponFamily.BALLISTIC)
	)
	var missile_hits: int = (
		agents[0].landed_hits_for(WeaponSpec.WeaponFamily.MISSILE)
		+ agents[1].landed_hits_for(WeaponSpec.WeaponFamily.MISSILE)
	)
	var energy_hits: int = (
		agents[0].landed_hits_for(WeaponSpec.WeaponFamily.ENERGY)
		+ agents[1].landed_hits_for(WeaponSpec.WeaponFamily.ENERGY)
	)
	var ballistic_shots: int = (
		agents[0].fired_shots_for(WeaponSpec.WeaponFamily.BALLISTIC)
		+ agents[1].fired_shots_for(WeaponSpec.WeaponFamily.BALLISTIC)
	)
	var missile_shots: int = (
		agents[0].fired_shots_for(WeaponSpec.WeaponFamily.MISSILE)
		+ agents[1].fired_shots_for(WeaponSpec.WeaponFamily.MISSILE)
	)
	var energy_shots: int = (
		agents[0].fired_shots_for(WeaponSpec.WeaponFamily.ENERGY)
		+ agents[1].fired_shots_for(WeaponSpec.WeaponFamily.ENERGY)
	)
	var front_hits: int = agents[0].aspect_hits(&"FRONT") + agents[1].aspect_hits(&"FRONT")
	var side_hits: int = agents[0].aspect_hits(&"SIDE") + agents[1].aspect_hits(&"SIDE")
	var rear_hits: int = agents[0].aspect_hits(&"REAR") + agents[1].aspect_hits(&"REAR")
	var preparation_started: int = agents[0].preparation_started_count + agents[1].preparation_started_count
	var preparation_completed: int = agents[0].preparation_completed_count + agents[1].preparation_completed_count
	var preparation_cancelled: int = agents[0].preparation_cancelled_count + agents[1].preparation_cancelled_count
	var prediction_blocked: int = (
		agents[0].preparation_prediction_blocked_count
		+ agents[1].preparation_prediction_blocked_count
	)
	var rocket_reloads: int = (
		agents[0].reload_count_for(WeaponSpec.WeaponFamily.MISSILE)
		+ agents[1].reload_count_for(WeaponSpec.WeaponFamily.MISSILE)
	)
	var burst_reloads: int = agents[1].reload_count_for(WeaponSpec.WeaponFamily.BALLISTIC)
	var burst_reload_completions: int = agents[1].reload_completed_count_for(WeaponSpec.WeaponFamily.BALLISTIC)
	var missile_paths: int = (
		agents[0].missile_approaches[&"LEFT"]
		+ agents[0].missile_approaches[&"RIGHT"]
		+ agents[0].missile_approaches[&"REAR"]
		+ agents[1].missile_approaches[&"LEFT"]
		+ agents[1].missile_approaches[&"RIGHT"]
		+ agents[1].missile_approaches[&"REAR"]
	)
	var passed: bool = (
		ballistic_shots + missile_shots + energy_shots > 0
		and agents[1].fired_shots_for(WeaponSpec.WeaponFamily.BALLISTIC) > 0
		and agents[1].projectile_count > agents[1].shot_count
		and missile_shots > 0
		and agents[0].dash_count > 0
		and agents[1].dash_count > 0
		and agents[0].homing_adjustment_count + agents[1].homing_adjustment_count > 0
		and is_equal_approx(agents[0].fire_rate_multiplier, 0.5)
		and is_equal_approx(agents[1].fire_rate_multiplier, 1.0)
		and front_hits + side_hits + rear_hits == agents[0].hit_count + agents[1].hit_count
		and side_hits + rear_hits > 0
		and preparation_started > 0
		and preparation_completed > 0
		and missile_paths > 0
		and agents[0].evasion_count + agents[1].evasion_count > 0
		and agents[0].range_blocked_count > 0
		and agents[0].aim_blocked_count + agents[1].aim_blocked_count > 0
		and rocket_reloads > 0
		and burst_reloads > 0
		and burst_reload_completions > 0
		and agents[1].reload_evasion_count > 0
		and agents[0].hitbox_count == 6
		and agents[1].hitbox_count == 6
		and observed_max_distance > 1900.0
		and observed_max_distance - observed_min_distance > 5.0
		and observed_max_zoom - observed_min_zoom > 0.01
		and not framing_failed
	)
	print(
		"camera_smoke distance=%.1f..%.1f zoom=%.3f..%.3f shots=%d/%d fired=%d/%d/%d hits=%d/%d/%d aspect=%d/%d/%d dash=%d/%d evade=%d/%d blocked=%d/%d prep=%d/%d/%d predict=%d reload=%d/%d/%d re_evasion=%d paths=%d guide=%d boxes=%d/%d framed=%s" % [
			observed_min_distance,
			observed_max_distance,
			observed_min_zoom,
			observed_max_zoom,
			agents[0].shot_count,
			agents[1].shot_count,
			ballistic_shots,
			missile_shots,
			energy_shots,
			ballistic_hits,
			missile_hits,
			energy_hits,
			front_hits,
			side_hits,
			rear_hits,
			agents[0].dash_count,
			agents[1].dash_count,
			agents[0].evasion_count,
			agents[1].evasion_count,
			agents[0].range_blocked_count,
			agents[0].aim_blocked_count + agents[1].aim_blocked_count,
			preparation_started,
			preparation_completed,
			preparation_cancelled,
			prediction_blocked,
			rocket_reloads,
			burst_reloads,
			burst_reload_completions,
			agents[1].reload_evasion_count,
			missile_paths,
			agents[0].homing_adjustment_count + agents[1].homing_adjustment_count,
			agents[0].hitbox_count,
			agents[1].hitbox_count,
			str(not framing_failed),
		]
	)
	get_tree().quit(0 if passed else 1)
