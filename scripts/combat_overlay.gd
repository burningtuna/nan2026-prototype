class_name CombatOverlay
extends Control

const TARGET_COLOR := Color("ff4747")
const PREP_COLOR := Color("ffd15c")
const LABEL_COLOR := Color("ffdede")
const RANGE_READY_COLOR := Color("65f0d0")
const RANGE_BLOCKED_COLOR := Color("ff6259")

var player: AiMechAgent
var enemies: Array[AiMechAgent] = []
var projectile_layer: Node2D
var attack_flash_remaining := {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


func bind(combat_player: AiMechAgent, combat_enemies: Array, projectiles: Node2D) -> void:
	player = combat_player
	enemies.assign(combat_enemies)
	projectile_layer = projectiles
	for enemy in enemies:
		enemy.weapon_fired.connect(_on_enemy_weapon_fired.bind(enemy))
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	for enemy_id in attack_flash_remaining.keys():
		var remaining: float = attack_flash_remaining[enemy_id] - delta
		if remaining <= 0.0:
			attack_flash_remaining.erase(enemy_id)
		else:
			attack_flash_remaining[enemy_id] = remaining
	queue_redraw()


func _on_enemy_weapon_fired(_weapon: WeaponRuntime, enemy: AiMechAgent) -> void:
	attack_flash_remaining[enemy.get_instance_id()] = 0.45


func _draw() -> void:
	var canvas_transform := get_viewport().get_canvas_transform()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var enemy_position: Vector2 = canvas_transform * enemy.global_position
		_draw_target_marker(enemy_position, enemy)
	_draw_cursor_range(canvas_transform)
	if not is_instance_valid(projectile_layer):
		return
	for node in projectile_layer.get_children():
		var projectile := node as BallisticProjectile
		if (
			projectile == null
			or projectile.weapon_family != WeaponSpec.WeaponFamily.MISSILE
			or projectile.homing_target != player
		):
			continue
		var missile_position: Vector2 = canvas_transform * projectile.global_position
		_draw_missile_marker(missile_position)


func _draw_cursor_range(canvas_transform: Transform2D) -> void:
	if not is_instance_valid(player) or not player.player_controlled:
		return
	var cursor_position: Vector2 = canvas_transform * player.manual_aim_position
	var distance := player.global_position.distance_to(player.manual_aim_position)
	var maximum_range := player.maximum_weapon_range()
	var is_in_range := distance <= maximum_range
	var color := RANGE_READY_COLOR if is_in_range else RANGE_BLOCKED_COLOR

	draw_arc(cursor_position, 5.0, 0.0, TAU, 16, color, 1.0)
	draw_line(cursor_position + Vector2(7.0, 0.0), cursor_position + Vector2(11.0, 0.0), color, 1.0)
	var text := "D%04d / R%04d" % [roundi(distance), roundi(maximum_range)]
	var label_size := Vector2(76.0, 11.0)
	var label_position := cursor_position + Vector2(10.0, -13.0)
	if label_position.x + label_size.x > size.x - 3.0:
		label_position.x = cursor_position.x - label_size.x - 10.0
	label_position.y = clampf(label_position.y, 3.0, size.y - label_size.y - 3.0)
	draw_rect(Rect2(label_position, label_size), Color(0.02, 0.04, 0.05, 0.82))
	draw_rect(Rect2(label_position, label_size), color.darkened(0.35), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		label_position + Vector2(3.0, 8.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		7,
		color
	)


func _draw_target_marker(screen_position: Vector2, enemy: AiMechAgent) -> void:
	var radius := 16.0
	draw_arc(screen_position, radius, 0.0, TAU, 32, TARGET_COLOR, 1.5)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var start := screen_position + Vector2.from_angle(angle) * (radius + 3.0)
		var finish := screen_position + Vector2.from_angle(angle) * (radius + 8.0)
		draw_line(start, finish, TARGET_COLOR, 1.5)

	var state := _enemy_state(enemy)
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		screen_position + Vector2(-24.0, -23.0),
		state,
		HORIZONTAL_ALIGNMENT_CENTER,
		48.0,
		8,
		PREP_COLOR if state == "ATTACK PREP" else LABEL_COLOR
	)
	if enemy.is_preparing_attack():
		var weapon := enemy.weapons[enemy.preparing_weapon_index]
		var duration := maxf(weapon.spec.preparation_time * enemy.weapon_range_multiplier, 0.001)
		var progress := 1.0 - enemy.preparation_time_remaining / duration
		draw_arc(screen_position, radius + 3.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, PREP_COLOR, 2.0)


func _draw_missile_marker(screen_position: Vector2) -> void:
	var safe_rect := Rect2(Vector2(8.0, 8.0), size - Vector2(16.0, 16.0))
	var marker_position := screen_position
	var is_offscreen := not safe_rect.has_point(screen_position)
	if is_offscreen:
		marker_position = screen_position.clamp(safe_rect.position, safe_rect.end)
	var pulse := 2.0 + sin(Time.get_ticks_msec() * 0.012) * 1.5
	draw_arc(marker_position, 7.0 + pulse, 0.0, TAU, 20, TARGET_COLOR, 1.5)
	draw_arc(marker_position, 4.0, 0.0, TAU, 16, TARGET_COLOR, 1.0)
	if is_offscreen:
		var direction := (screen_position - marker_position).normalized()
		draw_line(marker_position, marker_position + direction * 8.0, TARGET_COLOR, 2.0)


func _enemy_state(enemy: AiMechAgent) -> String:
	if enemy.is_preparing_attack():
		return "ATTACK PREP"
	if attack_flash_remaining.has(enemy.get_instance_id()):
		return "ATTACK"
	if enemy.is_reloading_ballistic():
		return "RELOADING"
	if not enemy.has_fireable_weapon():
		return "NO SHOT"
	if enemy.velocity.length_squared() > 4.0:
		return "MOVING"
	return "IDLE"
