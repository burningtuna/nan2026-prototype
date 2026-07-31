extends Node2D

const AI_MECH := preload("res://scripts/ai_mech_agent.gd")
const TEST_CANNON := preload("res://data/test_cannon.tres")
const TEST_BURST_CANNON := preload("res://data/test_burst_cannon.tres")
const TEST_MISSILE := preload("res://data/test_missile.tres")
const TEST_ENERGY_CANNON := preload("res://data/test_energy_cannon.tres")

@export var arena := Rect2(-5000.0, -5000.0, 10000.0, 10000.0)
@export var framing_margin := Vector2(72.0, 58.0)
@export var minimum_zoom := 0.18
@export var maximum_zoom := 1.8
@export var zoom_in_smoothing := 3.0

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


func _ready() -> void:
	smoke_test_enabled = OS.get_cmdline_user_args().has("--camera-smoke")
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
	draw_rect(arena.grow(500.0), Color("111820"))
	for x in range(int(arena.position.x), int(arena.end.x) + 1, 32):
		draw_line(Vector2(x, arena.position.y), Vector2(x, arena.end.y), Color("18232d"))
	for y in range(int(arena.position.y), int(arena.end.y) + 1, 32):
		draw_line(Vector2(arena.position.x, y), Vector2(arena.end.x, y), Color("18232d"))
	draw_rect(arena, Color("324552"), false, 2.0)

	if agents.size() == 2:
		draw_dashed_line(agents[0].position, agents[1].position, Color("37505e"), 1.0, 8.0)
		var direction_line_width := 2.0 / maxf(camera.zoom.x, 0.001)
		for agent in agents:
			var forward: Vector2 = agent.torso_forward()
			var direction_color := Color("ffd34d") if agent.is_preparing_attack() else Color(0.25, 1.0, 0.35, 0.9)
			var traverse_limit := deg_to_rad(agent.weapon_traverse_limit_degrees)
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
	var colors := [Color("8fe5ff"), Color("ff9b8f")]
	var starts := [Vector2(-1000.0, 0.0), Vector2(1000.0, 0.0)]
	var first_loadout: Array[WeaponSpec] = [TEST_CANNON, TEST_MISSILE]
	var second_loadout: Array[WeaponSpec] = [TEST_ENERGY_CANNON, TEST_BURST_CANNON]
	for index in 2:
		var agent = AI_MECH.new()
		if index == 0:
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
		var loadout := first_loadout if index == 0 else second_loadout
		agent.setup(
			"AI-%02d" % (index + 1),
			projectile_layer,
			arena,
			1200 + index * 7919,
			colors[index],
			loadout
		)
		agent.position = starts[index]
		add_child(agent)
		agents.append(agent)

	agents[0].set_opponent(agents[1])
	agents[1].set_opponent(agents[0])


func _update_camera(delta: float, snap := false) -> void:
	if agents.size() < 2:
		return

	var first_position: Vector2 = agents[0].global_position
	var second_position: Vector2 = agents[1].global_position
	var separation: Vector2 = (second_position - first_position).abs()
	var required_size: Vector2 = separation + framing_margin * 2.0
	var viewport_size := get_viewport_rect().size
	var target_zoom := clampf(
		minf(viewport_size.x / required_size.x, viewport_size.y / required_size.y),
		minimum_zoom,
		maximum_zoom
	)

	camera.global_position = (first_position + second_position) * 0.5
	if snap or target_zoom < camera.zoom.x:
		camera.zoom = Vector2.ONE * target_zoom
	else:
		var blend := 1.0 - exp(-zoom_in_smoothing * delta)
		camera.zoom = Vector2.ONE * lerpf(camera.zoom.x, target_zoom, blend)


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
	for agent in agents:
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
	var rocket_reloads: int = agents[0].reload_count_for(WeaponSpec.WeaponFamily.MISSILE)
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
