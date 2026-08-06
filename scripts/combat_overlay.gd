class_name CombatOverlay
extends Control

const TARGET_COLOR := Color("ff4747")
const PREP_COLOR := Color("ffd15c")
const LABEL_COLOR := Color("ffdede")
const RANGE_READY_COLOR := Color("65f0d0")
const RANGE_BLOCKED_COLOR := Color("ff6259")
const ALLY_MARKER_COLOR := Color("62ed8c")
const HEAT_WARNING_COLOR := Color("ffd15c")
const HEAT_CRITICAL_COLOR := Color("ff4747")
const COOLING_COLOR := Color("66e6dc")
const UNIT_MARKER_MARGIN := 24.0
const TARGET_PANEL_SIZE := Vector2(76.0, 76.0)
const TARGET_PANEL_MARGIN := 4.0
const ROSTER_ROW_HEIGHT := 10.0
const ROSTER_HEADER_HEIGHT := 13.0
const TARGET_PREVIEW := preload("res://scripts/mech_wireframe_preview.gd")

var player: AiMechAgent
var allies: Array[AiMechAgent] = []
var enemies: Array[AiMechAgent] = []
var projectile_layer: Node2D
var attack_flash_remaining := {}
var pending_attack_flashes := {}
var observed_sensor_sequence := -1
var winning_team_number := -1
var combat_hud_visible := true
var target_focus_active := false
var focused_target: AiMechAgent
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
	projectile_layer = projectiles
	set_roster(combat_allies, combat_enemies)
	set_process(true)
	queue_redraw()


func set_roster(combat_allies: Array, combat_enemies: Array) -> void:
	allies.assign(combat_allies)
	enemies.assign(combat_enemies)
	for enemy in enemies:
		var callback := _on_enemy_weapon_fired.bind(enemy)
		if not enemy.weapon_fired.is_connected(callback):
			enemy.weapon_fired.connect(callback)
	if is_instance_valid(displayed_target) and not enemies.has(displayed_target):
		displayed_target = null
		target_preview.visible = false
	queue_redraw()


func _process(delta: float) -> void:
	if not combat_hud_visible:
		target_preview.visible = false
		queue_redraw()
		return
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


func set_combat_hud_visible(value: bool) -> void:
	combat_hud_visible = value
	if not combat_hud_visible:
		target_preview.visible = false
	queue_redraw()


func set_target_focus(value: bool, target: AiMechAgent) -> void:
	target_focus_active = value and is_instance_valid(target)
	focused_target = target if target_focus_active else null
	queue_redraw()


func _draw() -> void:
	_draw_team_victory()
	if not combat_hud_visible or not is_instance_valid(player):
		return
	var canvas_transform := get_viewport().get_canvas_transform()
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
		if not is_instance_valid(enemy) or enemy.is_defeated() or not player.can_detect_unit(enemy):
			continue
		var enemy_position: Vector2 = canvas_transform * player.observed_unit_position(enemy)
		if safe_rect.has_point(enemy_position):
			_draw_target_marker(enemy_position, enemy)
		else:
			_draw_offscreen_unit_marker(enemy_position, safe_rect, TARGET_COLOR)
	_draw_cursor_range(canvas_transform)
	_draw_targeting_solution(canvas_transform)
	if is_instance_valid(projectile_layer):
		for projectile in player.detected_hostile_projectiles(projectile_layer):
			if (
				projectile.weapon_family != WeaponSpec.WeaponFamily.MISSILE
				or projectile.homing_target != player
			):
				continue
			var missile_position: Vector2 = canvas_transform * player.observed_projectile_position(projectile)
			_draw_missile_marker(missile_position)
	_draw_target_panel()
	_draw_enemy_roster()


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
	var range_weapon := player.selected_range_weapon()
	var range_origin := player.weapon_aim_origin(range_weapon)
	var distance := range_origin.distance_to(player.manual_aim_position)
	var maximum_range := player.weapon_maximum_range(range_weapon)
	var is_in_range := distance <= maximum_range
	var color := RANGE_READY_COLOR if is_in_range else RANGE_BLOCKED_COLOR
	var selected_weapons := player.selected_weapons()
	var displayed_weapons: Array[WeaponRuntime] = []
	for weapon in selected_weapons:
		if not weapon.disabled:
			displayed_weapons.append(weapon)
	var heat_status_text := ""
	var heat_status_color := Color.WHITE
	if player.heat_generation_locked:
		heat_status_text = "-- COOLING --"
		heat_status_color = COOLING_COLOR
	elif player.heat_ratio() >= 0.8:
		heat_status_text = "-- HEAT CRITICAL --"
		heat_status_color = HEAT_CRITICAL_COLOR
	elif player.heat_ratio() >= 0.6:
		heat_status_text = "-- HEAT WARNING --"
		heat_status_color = HEAT_WARNING_COLOR
	var heat_status_height := 8.0 if not heat_status_text.is_empty() else 0.0

	draw_arc(cursor_position, 5.0, 0.0, TAU, 16, color, 1.0)
	draw_line(cursor_position + Vector2(7.0, 0.0), cursor_position + Vector2(11.0, 0.0), color, 1.0)
	var text := "D%04d / R%04d" % [roundi(distance), roundi(maximum_range)]
	var label_size := Vector2(120.0, 11.0 + heat_status_height + displayed_weapons.size() * 8.0)
	var label_position := cursor_position + Vector2(10.0, -13.0)
	if label_position.x + label_size.x > size.x - 3.0:
		label_position.x = cursor_position.x - label_size.x - 10.0
	label_position.y = clampf(label_position.y, 3.0, size.y - label_size.y - 3.0)
	var label_rect := Rect2(label_position, label_size)
	var sidebar_rect := _target_sidebar_rect()
	if label_rect.intersects(sidebar_rect):
		label_position.x = maxf(sidebar_rect.position.x - label_size.x - 3.0, 3.0)
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
	if not heat_status_text.is_empty():
		var heat_status_position := label_position + Vector2(3.0, 17.0)
		draw_string_outline(
			ThemeDB.fallback_font,
			heat_status_position,
			heat_status_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			6,
			2,
			Color(0.0, 0.0, 0.0, 0.9)
		)
		draw_string(
			ThemeDB.fallback_font,
			heat_status_position,
			heat_status_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			6,
			heat_status_color
		)
	for index in displayed_weapons.size():
		var weapon := displayed_weapons[index]
		var weapon_name := weapon.spec.display_name.to_upper().trim_prefix("TEST ").left(16)
		var weapon_text := "%s RELOADING..." % weapon_name if weapon.is_reloading() else "%s %02d/%02d" % [
			weapon_name,
			weapon.ammo,
			weapon.spec.magazine_capacity,
		]
		var weapon_position := label_position + Vector2(3.0, 17.0 + heat_status_height + index * 8.0)
		draw_string_outline(
			ThemeDB.fallback_font,
			weapon_position,
			weapon_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			6,
			2,
			Color(0.0, 0.0, 0.0, 0.9)
		)
		draw_string(
			ThemeDB.fallback_font,
			weapon_position,
			weapon_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			6,
			ALLY_MARKER_COLOR
		)


func _update_target_preview() -> void:
	if not is_instance_valid(player):
		target_preview.visible = false
		return
	var target := (
		player.selected_sensor_target
		if is_instance_valid(player.selected_sensor_target)
		else player.opponent
	)
	if (
		not is_instance_valid(target)
		or target.is_defeated()
		or not player.can_detect_unit(target)
		or target.unit_class == AiMechAgent.UnitClass.DRONE
	):
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


func _enemy_roster() -> Array[AiMechAgent]:
	var roster: Array[AiMechAgent] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.is_defeated() and enemy.appears_in_enemy_roster():
			roster.append(enemy)
	return roster


func _enemy_roster_rect() -> Rect2:
	var panel_rect := _target_panel_rect()
	var roster_size := _enemy_roster().size()
	if roster_size <= 0:
		return Rect2(panel_rect.end.x - TARGET_PANEL_SIZE.x, panel_rect.end.y, 0.0, 0.0)
	var available_height := maxf(size.y - panel_rect.end.y - TARGET_PANEL_MARGIN * 2.0, 0.0)
	var row_count := mini(
		roster_size,
		maxi(floori((available_height - ROSTER_HEADER_HEIGHT) / ROSTER_ROW_HEIGHT), 0)
	)
	if row_count <= 0:
		return Rect2(panel_rect.end.x - TARGET_PANEL_SIZE.x, panel_rect.end.y, 0.0, 0.0)
	return Rect2(
		Vector2(panel_rect.position.x, panel_rect.end.y + TARGET_PANEL_MARGIN),
		Vector2(TARGET_PANEL_SIZE.x, ROSTER_HEADER_HEIGHT + row_count * ROSTER_ROW_HEIGHT)
	)


func _target_sidebar_rect() -> Rect2:
	var roster_rect := _enemy_roster_rect()
	if roster_rect.size.y > 0.0:
		return _target_panel_rect().merge(roster_rect)
	return _target_panel_rect() if target_preview.visible else Rect2()


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


func _draw_enemy_roster() -> void:
	var roster := _enemy_roster()
	var roster_rect := _enemy_roster_rect()
	if roster.is_empty() or roster_rect.size.y <= 0.0:
		return
	var row_count := floori((roster_rect.size.y - ROSTER_HEADER_HEIGHT) / ROSTER_ROW_HEIGHT)
	draw_rect(roster_rect, Color(0.005, 0.01, 0.012, 0.62))
	draw_rect(roster_rect, TARGET_COLOR.darkened(0.45), false, 1.0)
	draw_string(
		ThemeDB.fallback_font,
		roster_rect.position + Vector2(4.0, 9.0),
		"HOSTILES // %d" % roster.size(),
		HORIZONTAL_ALIGNMENT_LEFT,
		roster_rect.size.x - 8.0,
		6,
		LABEL_COLOR
	)
	for index in row_count:
		var enemy := roster[index]
		var detected := player.can_detect_unit(enemy)
		var selected := enemy == displayed_target
		var class_marker := "B" if enemy.unit_class == AiMechAgent.UnitClass.BOSS else "M"
		var state_marker := ">" if selected else ("-" if detected else "?")
		var color := LABEL_COLOR if detected else Color("856f73")
		if selected:
			color = ALLY_MARKER_COLOR
		draw_string(
			ThemeDB.fallback_font,
			roster_rect.position + Vector2(4.0, ROSTER_HEADER_HEIGHT + 7.0 + index * ROSTER_ROW_HEIGHT),
			"%s%s %s" % [state_marker, class_marker, enemy.name.to_upper().left(9)],
			HORIZONTAL_ALIGNMENT_LEFT,
			roster_rect.size.x - 8.0,
			6,
			color
		)


func _draw_target_marker(screen_position: Vector2, enemy: AiMechAgent) -> void:
	var radius := 16.0
	draw_arc(screen_position, radius, 0.0, TAU, 32, TARGET_COLOR, 1.5)
	if enemy == player.selected_sensor_target:
		draw_arc(screen_position, radius + 3.0, 0.0, TAU, 32, ALLY_MARKER_COLOR, 1.5)
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


func _draw_targeting_solution(canvas_transform: Transform2D) -> void:
	if (
		not target_focus_active
		or not is_instance_valid(player)
		or not is_instance_valid(focused_target)
		or focused_target.is_defeated()
		or not player.can_detect_unit(focused_target)
	):
		return
	var weapon := _targeting_weapon()
	if weapon == null or weapon.spec.projectile == null:
		return
	var origin := player.weapon_aim_origin(weapon)
	var target_position := player.observed_unit_position(focused_target)
	var target_velocity := player.observed_unit_velocity(focused_target)
	var lead_position := _intercept_position(
		origin,
		target_position,
		target_velocity,
		weapon.spec.projectile.speed
	)
	var aim_vector := lead_position - origin
	if aim_vector.is_zero_approx():
		return
	var aim_direction := aim_vector.normalized()
	var effective_range := player.weapon_effective_range(weapon)
	var maximum_range := player.weapon_maximum_range(weapon)
	var effective_end := origin + aim_direction * effective_range
	var maximum_end := origin + aim_direction * maximum_range
	var origin_screen: Vector2 = canvas_transform * origin
	var effective_screen: Vector2 = canvas_transform * effective_end
	var maximum_screen: Vector2 = canvas_transform * maximum_end
	var target_screen: Vector2 = canvas_transform * target_position
	var lead_screen: Vector2 = canvas_transform * lead_position
	draw_line(origin_screen, effective_screen, RANGE_READY_COLOR, 1.5)
	if maximum_range > effective_range:
		draw_line(effective_screen, maximum_screen, PREP_COLOR, 1.5)
	var lead_distance := aim_vector.length()
	var status_color := RANGE_READY_COLOR
	if lead_distance > maximum_range:
		status_color = RANGE_BLOCKED_COLOR
	elif lead_distance > effective_range:
		status_color = PREP_COLOR
	draw_arc(target_screen, 4.0, 0.0, TAU, 16, TARGET_COLOR, 1.0)
	draw_line(lead_screen - Vector2(4.0, 0.0), lead_screen + Vector2(4.0, 0.0), status_color, 1.0)
	draw_line(lead_screen - Vector2(0.0, 4.0), lead_screen + Vector2(0.0, 4.0), status_color, 1.0)
	var label := "%s  LEAD %d  R%d" % [
		weapon.spec.display_name.to_upper().trim_prefix("TEST ").left(16),
		roundi(target_position.distance_to(lead_position)),
		roundi(maximum_range),
	]
	draw_string_outline(
		ThemeDB.fallback_font,
		lead_screen + Vector2(6.0, -6.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		6,
		2,
		Color(0.0, 0.0, 0.0, 0.9)
	)
	draw_string(
		ThemeDB.fallback_font,
		lead_screen + Vector2(6.0, -6.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		6,
		status_color
	)


func _targeting_weapon() -> WeaponRuntime:
	return player.selected_range_weapon()


func _intercept_position(
	origin: Vector2,
	target_position: Vector2,
	target_velocity: Vector2,
	projectile_speed: float
) -> Vector2:
	if projectile_speed <= 0.0:
		return target_position
	var relative_position := target_position - origin
	var quadratic_a := target_velocity.length_squared() - projectile_speed * projectile_speed
	var quadratic_b := 2.0 * relative_position.dot(target_velocity)
	var quadratic_c := relative_position.length_squared()
	var intercept_time := -1.0
	if absf(quadratic_a) < 0.001:
		if absf(quadratic_b) > 0.001:
			intercept_time = -quadratic_c / quadratic_b
	else:
		var discriminant := quadratic_b * quadratic_b - 4.0 * quadratic_a * quadratic_c
		if discriminant >= 0.0:
			var root := sqrt(discriminant)
			var first_time := (-quadratic_b - root) / (2.0 * quadratic_a)
			var second_time := (-quadratic_b + root) / (2.0 * quadratic_a)
			if first_time > 0.0 and second_time > 0.0:
				intercept_time = minf(first_time, second_time)
			else:
				intercept_time = maxf(first_time, second_time)
	if intercept_time <= 0.0:
		return target_position
	return target_position + target_velocity * intercept_time


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
