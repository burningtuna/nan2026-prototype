extends Node2D

const AI_MECH := preload("res://scripts/ai_mech_agent.gd")

@export var arena := Rect2(-360.0, -220.0, 720.0, 440.0)
@export var framing_margin := Vector2(72.0, 58.0)
@export var minimum_zoom := 0.55
@export var maximum_zoom := 1.8
@export var zoom_in_smoothing := 3.0

@onready var camera: Camera2D = $DynamicCamera
@onready var projectile_layer: Node2D = $Projectiles
@onready var camera_status: Label = $UI/CameraStatus
@onready var agent_status: Label = $UI/AgentStatus

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


func _spawn_agents() -> void:
	var colors := [Color("8fe5ff"), Color("ff9b8f")]
	var starts := [Vector2(-120.0, -45.0), Vector2(120.0, 45.0)]
	for index in 2:
		var agent = AI_MECH.new()
		agent.setup("AI-%02d" % (index + 1), projectile_layer, arena, 1200 + index * 7919, colors[index])
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
	agent_status.text = "AI-01 SPD %2d AMMO %02d SHOTS %03d   AI-02 SPD %2d AMMO %02d SHOTS %03d" % [
		roundi(agents[0].velocity.length()),
		agents[0].ammo_remaining(),
		agents[0].shot_count,
		roundi(agents[1].velocity.length()),
		agents[1].ammo_remaining(),
		agents[1].shot_count,
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
	if smoke_elapsed < 6.0:
		return

	var passed: bool = (
		agents[0].shot_count > 0
		and agents[1].shot_count > 0
		and observed_max_distance - observed_min_distance > 5.0
		and observed_max_zoom - observed_min_zoom > 0.01
		and not framing_failed
	)
	print(
		"camera_smoke distance=%.1f..%.1f zoom=%.3f..%.3f shots=%d/%d framed=%s" % [
			observed_min_distance,
			observed_max_distance,
			observed_min_zoom,
			observed_max_zoom,
			agents[0].shot_count,
			agents[1].shot_count,
			str(not framing_failed),
		]
	)
	get_tree().quit(0 if passed else 1)
