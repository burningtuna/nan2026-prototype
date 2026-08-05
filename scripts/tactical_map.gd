class_name TacticalMap
extends Control

const PANEL_COLOR := Color("101b24")
const GRID_COLOR := Color("29404d")
const PLAYER_COLOR := Color("71d9e8")
const ALLY_COLOR := Color("8faeff")
const THREAT_COLOR := Color("ff4b4b")
const TERRAIN_ACCESSIBLE_COLOR := Color(0.08, 0.34, 0.29, 0.68)
const TERRAIN_BLOCKED_COLOR := Color(0.45, 0.14, 0.17, 0.72)
const TERRAIN_SAMPLE_SIZE := 2.0

var player: AiMechAgent
var allies: Array[AiMechAgent] = []
var enemies: Array[AiMechAgent] = []
var projectile_layer: Node2D
var terrain_provider: Node


func _ready() -> void:
	custom_minimum_size.y = 62.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(combat_player: AiMechAgent, combat_allies: Array, combat_enemies: Array, projectiles: Node2D) -> void:
	player = combat_player
	projectile_layer = projectiles
	set_roster(combat_allies, combat_enemies)


func set_roster(combat_allies: Array, combat_enemies: Array) -> void:
	allies.assign(combat_allies)
	enemies.assign(combat_enemies)
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_COLOR)
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(4.0, 9.0), "TACTICAL MAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, Color("7f9aaa"))
	var center := Vector2(size.x * 0.5, 37.0)
	var radius := minf(size.x * 0.36, 21.0)
	draw_circle(center, radius, Color("0b1218"))
	_draw_terrain_overlay(center, radius)
	draw_arc(center, radius, 0.0, TAU, 48, GRID_COLOR, 1.0)
	draw_arc(center, radius * 0.5, 0.0, TAU, 32, GRID_COLOR, 1.0)
	draw_line(center - Vector2(radius, 0.0), center + Vector2(radius, 0.0), GRID_COLOR, 1.0)
	draw_line(center - Vector2(0.0, radius), center + Vector2(0.0, radius), GRID_COLOR, 1.0)

	if not is_instance_valid(player):
		return
	draw_circle(center, 2.0, PLAYER_COLOR)
	for ally in allies:
		if is_instance_valid(ally):
			draw_circle(_radar_position(ally.global_position, center, radius), 2.5, ALLY_COLOR)
	for enemy in enemies:
		if is_instance_valid(enemy) and player.can_detect_unit(enemy):
			draw_circle(_radar_position(player.observed_unit_position(enemy), center, radius), 3.5, THREAT_COLOR)
	if not is_instance_valid(projectile_layer):
		return
	for projectile in player.detected_hostile_projectiles(projectile_layer):
		if projectile.weapon_family != WeaponSpec.WeaponFamily.MISSILE:
			continue
		draw_circle(_radar_position(player.observed_projectile_position(projectile), center, radius), 1.25, THREAT_COLOR)


func _draw_terrain_overlay(center: Vector2, radius: float) -> void:
	if not is_instance_valid(player):
		return
	var provider := _terrain_provider()
	if provider == null:
		return
	var radar_range := _radar_range()
	var sample_radius := ceili(radius / TERRAIN_SAMPLE_SIZE)
	for sample_y in range(-sample_radius, sample_radius + 1):
		for sample_x in range(-sample_radius, sample_radius + 1):
			var radar_offset := Vector2(sample_x, sample_y) * TERRAIN_SAMPLE_SIZE
			if radar_offset.length_squared() > radius * radius:
				continue
			var world_point := player.global_position + radar_offset * (radar_range / radius)
			var accessible := bool(provider.radar_point_is_accessible(world_point))
			draw_rect(
				Rect2(center + radar_offset - Vector2.ONE * TERRAIN_SAMPLE_SIZE * 0.5, Vector2.ONE * TERRAIN_SAMPLE_SIZE),
				TERRAIN_ACCESSIBLE_COLOR if accessible else TERRAIN_BLOCKED_COLOR
			)


func _terrain_provider() -> Node:
	if is_instance_valid(terrain_provider) and terrain_provider.get_viewport() == player.get_viewport():
		return terrain_provider
	terrain_provider = null
	for candidate in get_tree().get_nodes_in_group(&"radar_terrain_masks"):
		if (
			is_instance_valid(candidate)
			and candidate.get_viewport() == player.get_viewport()
			and candidate.has_method("radar_point_is_accessible")
		):
			terrain_provider = candidate
			break
	return terrain_provider


func _radar_position(world_position: Vector2, center: Vector2, radius: float) -> Vector2:
	var radar_range := _radar_range()
	var offset := (world_position - player.global_position) * (radius / radar_range)
	if offset.length() > radius:
		offset = offset.normalized() * radius
	return center + offset


func _radar_range() -> float:
	if not is_instance_valid(player):
		return 1.0
	var combat_viewport := player.get_viewport()
	var active_camera := combat_viewport.get_camera_2d()
	if is_instance_valid(active_camera):
		var camera_zoom := active_camera.zoom.abs()
		var visible_world_size := combat_viewport.get_visible_rect().size / Vector2(
			maxf(camera_zoom.x, 0.001),
			maxf(camera_zoom.y, 0.001)
		)
		return maxf(minf(visible_world_size.x, visible_world_size.y) * 0.5, 1.0)
	return maxf(player.sensor_range(), 1.0)
