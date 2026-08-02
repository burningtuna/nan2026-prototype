class_name CombatOverlay
extends Control

const TARGET_COLOR := Color("ff4747")
const PREP_COLOR := Color("ffd15c")
const LABEL_COLOR := Color("ffdede")
const RANGE_READY_COLOR := Color("65f0d0")
const RANGE_BLOCKED_COLOR := Color("ff6259")
const ALLY_MARKER_COLOR := Color("62ed8c")
const UNIT_MARKER_MARGIN := 24.0
const TARGET_PANEL_SIZE := Vector2(76.0, 76.0)
const TARGET_PANEL_MARGIN := 4.0
const TARGET_PREVIEW := preload("res://scripts/mech_wireframe_preview.gd")

var player: AiMechAgent
var allies: Array[AiMechAgent] = []
var enemies: Array[AiMechAgent] = []
var projectile_layer: Node2D
var attack_flash_remaining := {}
var pending_attack_flashes := {}
var observed_sensor_sequence := -1
var winning_team_number := -1
var target_preview: MechWireframePreview
var displayed_target: AiMechAgent


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	target_preview = TARGET_PREVIEW.new()
	target_preview.scale = Vector2.ONE * 0.9
	target_preview.visible = false
	add_child(target_preview)
	set_process(false)


func bind(combat_player: AiMechAgent, combat_allies: Array, combat_enemies: Array, projectiles: Node2D) -> void:
	player = combat_player
	allies.assign(combat_allies)
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
	if is_instance_valid(player) and player.sensor_snapshot.sequence != observed_sensor_sequence:
		observed_sensor_sequence = player.sensor_snapshot.sequence
		for enemy in enemies:
			var enemy_id := enemy.get_instance_id()
			if pending_attack_flashes.has(enemy_id) and player.can_detect_unit(enemy):
				attack_flash_remaining[enemy_id] = 0.45
		pending_attack_flashes.clear()
	_update_target_preview()
	queue_redraw()


func _on_enemy_weapon_fired(_weapon: WeaponRuntime, enemy: AiMechAgent) -> void:
	pending_attack_flashes[enemy.get_instance_id()] = true


func show_team_victory(team_number: int) -> void:
	winning_team_number = team_number
	queue_redraw()


func _draw() -> void:
	_draw_team_victory()
	if not is_instance_valid(player):
		return
	var canvas_transform := get_viewport().get_canvas_transform()
	_draw_target_panel()
	var safe_rect := Rect2(
		Vector2.ONE * UNIT_MARKER_MARGIN,
		size - Vector2.ONE * UNIT_MARKER_MARGIN * 2.0
	)
	for ally in allies:
		if not is_instance_valid(ally):
			continue
		var ally_position: Vector2 = canvas_transform * ally.global_position
		if not safe_rect.has_point(ally_position):
			_draw_offscreen_unit_marker(ally_position, safe_rect, ALLY_MARKER_COLOR)
	for enemy in enemies:
		if not is_instance_valid(enemy) or not player.can_detect_unit(enemy):
			continue
		var enemy_position: Vector2 = canvas_transform * player.observed_unit_position(enemy)
		if safe_rect.has_point(enemy_position):
			_draw_target_marker(enemy_position, enemy)
		else:
			_draw_offscreen_unit_marker(enemy_position, safe_rect, TARGET_COLOR)
	_draw_cursor_range(canvas_transform)
	if not is_instance_valid(projectile_layer):
		return
	for projectile in player.detected_hostile_projectiles(projectile_layer):
		if (
			projectile.weapon_family != WeaponSpec.WeaponFamily.MISSILE
			or projectile.homing_target != player
		):
			continue
		var missile_position: Vector2 = canvas_transform * player.observed_projectile_position(projectile)
		_draw_missile_marker(missile_position)


func _draw_team_victory() -> void:
	if winning_team_number < 0:
		return
	var banner_size := Vector2(minf(size.x - 32.0, 220.0), 46.0)
	var banner_rect := Rect2((size - banner_size) * 0.5, banner_size)
	draw_rect(banner_rect, Color(0.01, 0.025, 0.03, 0.9))
	draw_rect(banner_rect, Color("66e6dc"), false, 2.0)
	draw_string(
		ThemeDB.fallback_font,
		banner_rect.position + Vector2(0.0, 29.0),
		"DRAW" if winning_team_number == 0 else "TEAM %d WIN" % winning_team_number,
		HORIZONTAL_ALIGNMENT_CENTER,
		banner_rect.size.x,
		18,
		Color("d7fffa")
	)


func _draw_cursor_range(canvas_transform: Transform2D) -> void:
	if not is_instance_valid(player) or not player.player_controlled:
		return
	var cursor_position: Vector2 = canvas_transform * player.manual_aim_position
	var distance := player.global_position.distance_to(player.manual_aim_position)
	var maximum_range := player.selected_weapon_maximum_range()
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
	var label_rect := Rect2(label_position, label_size)
	var panel_rect := _target_panel_rect()
	if target_preview.visible and label_rect.intersects(panel_rect):
		label_position.y = minf(panel_rect.end.y + 3.0, size.y - label_size.y - 3.0)
	draw_string_outline(
		ThemeDB.fallback_font,
		label_position + Vector2(3.0, 8.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		7,
		2,
		Color(0.0, 0.0, 0.0, 0.9)
	)
	draw_string(
		ThemeDB.fallback_font,
		label_position + Vector2(3.0, 8.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		7,
		color
	)


func _update_target_preview() -> void:
	if not is_instance_valid(player):
		target_preview.visible = false
		return
	var target := player.opponent
	if not is_instance_valid(target) or not player.can_detect_unit(target):
		displayed_target = null
		target_preview.visible = false
		return
	if target != displayed_target:
		displayed_target = target
		target_preview.display(target.mech_loadout)
	target_preview.visible = true
	target_preview.modulate = Color.WHITE
	target_preview.position = _target_panel_rect().get_center() + Vector2(0.0, 4.0)
	for part_name in [&"Body", &"Head", &"Legs", &"LeftArm", &"RightArm", &"Backpack"]:
		target_preview.set_part_durability(part_name, player.observed_part_durability(target, part_name))


func _target_panel_rect() -> Rect2:
	return Rect2(
		Vector2(size.x - TARGET_PANEL_SIZE.x - TARGET_PANEL_MARGIN, TARGET_PANEL_MARGIN),
		TARGET_PANEL_SIZE
	)


func _draw_target_panel() -> void:
	if target_preview == null or not target_preview.visible or not is_instance_valid(displayed_target):
		return
	var panel_rect := _target_panel_rect()
	draw_rect(panel_rect, Color(0.005, 0.01, 0.012, 0.5))
	draw_rect(panel_rect, TARGET_COLOR.darkened(0.25), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		panel_rect.position + Vector2(4.0, 9.0),
		"TARGET // %s" % displayed_target.name.to_upper().left(10),
		HORIZONTAL_ALIGNMENT_LEFT,
		panel_rect.size.x - 8.0,
		6,
		LABEL_COLOR
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
	if player.observed_unit_is_preparing(enemy):
		draw_arc(screen_position, radius + 3.0, 0.0, TAU, 32, PREP_COLOR, 2.0)


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


func _draw_offscreen_unit_marker(screen_position: Vector2, safe_rect: Rect2, color: Color) -> void:
	var center := safe_rect.get_center()
	var direction := (screen_position - center).normalized()
	if direction.is_zero_approx():
		return
	var half_size := safe_rect.size * 0.5
	var x_scale := INF if is_zero_approx(direction.x) else half_size.x / absf(direction.x)
	var y_scale := INF if is_zero_approx(direction.y) else half_size.y / absf(direction.y)
	var tip := center + direction * minf(x_scale, y_scale)
	var base := tip - direction * 11.0
	var normal := Vector2(-direction.y, direction.x) * 5.0
	var points := PackedVector2Array([tip, base + normal, base - normal])
	draw_colored_polygon(points, color)
	draw_polyline(PackedVector2Array([tip, base + normal, base - normal, tip]), color.lightened(0.25), 1.0)


func _enemy_state(enemy: AiMechAgent) -> String:
	if player.observed_unit_is_preparing(enemy):
		return "ATTACK PREP"
	if attack_flash_remaining.has(enemy.get_instance_id()):
		return "ATTACK"
	if player.observed_unit_velocity(enemy).length_squared() > 4.0:
		return "MOVING"
	return "TRACKED"
