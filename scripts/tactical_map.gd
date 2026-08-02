class_name TacticalMap
extends Control

const PANEL_COLOR := Color("101b24")
const GRID_COLOR := Color("29404d")
const PLAYER_COLOR := Color("71d9e8")
const ALLY_COLOR := Color("8faeff")
const THREAT_COLOR := Color("ff4b4b")

var player: AiMechAgent
var allies: Array[AiMechAgent] = []
var enemies: Array[AiMechAgent] = []
var projectile_layer: Node2D


func _ready() -> void:
	custom_minimum_size.y = 62.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(combat_player: AiMechAgent, combat_allies: Array, combat_enemies: Array, projectiles: Node2D) -> void:
	player = combat_player
	allies.assign(combat_allies)
	enemies.assign(combat_enemies)
	projectile_layer = projectiles
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


func _radar_position(world_position: Vector2, center: Vector2, radius: float) -> Vector2:
	var radar_range := maxf(player.sensor_range(), 1.0)
	var offset := (world_position - player.global_position) * (radius / radar_range)
	if offset.length() > radius:
		offset = offset.normalized() * radius
	return center + offset
