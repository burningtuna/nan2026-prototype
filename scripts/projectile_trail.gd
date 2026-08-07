class_name ProjectileTrail
extends Node2D

const MAX_MISSILE_POINTS := 64
const MULTI_MISSILE_LIFETIME_MULTIPLIER := 0.2

var weapon_family := WeaponSpec.WeaponFamily.BALLISTIC
var launch_direction := Vector2.RIGHT
var width_multiplier := 1.0
var sample_lifetime := 0.12
var sample_spacing := 2.0
var finish_lifetime := 1.0
var finish_elapsed := 0.0
var finished := false
var max_missile_points := MAX_MISSILE_POINTS
var fill_sample_gaps := false
var smoke_expansion_speed_multiplier := 1.0
var points: Array[Vector2] = []
var ages: Array[float] = []


func setup(
	family: WeaponSpec.WeaponFamily,
	direction: Vector2,
	trail_width_multiplier := 1.0,
	trail_lifetime_multiplier := 1.0,
	multi_projectile_missile := false
) -> void:
	weapon_family = family
	launch_direction = direction.normalized()
	width_multiplier = maxf(trail_width_multiplier, 0.1)
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE:
		sample_lifetime = 1.0
		sample_spacing = 6.0
	elif weapon_family == WeaponSpec.WeaponFamily.ENERGY:
		sample_lifetime = 0.16
	var lifetime_multiplier := maxf(trail_lifetime_multiplier, 0.05)
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE and multi_projectile_missile:
		lifetime_multiplier *= MULTI_MISSILE_LIFETIME_MULTIPLIER
	sample_lifetime *= lifetime_multiplier
	finish_lifetime *= lifetime_multiplier


func add_sample(world_position: Vector2) -> void:
	if finished:
		return
	if not points.is_empty():
		var previous_position := points[-1]
		var sample_distance := previous_position.distance_to(world_position)
		if sample_distance < sample_spacing:
			return
		if weapon_family == WeaponSpec.WeaponFamily.MISSILE and fill_sample_gaps:
			var sample_direction := previous_position.direction_to(world_position)
			var offset := sample_spacing
			while offset < sample_distance:
				_append_sample(previous_position + sample_direction * offset)
				offset += sample_spacing
	points.append(world_position)
	ages.append(0.0)
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE and points.size() > max_missile_points:
		points.pop_front()
		ages.pop_front()
	queue_redraw()


func _append_sample(world_position: Vector2) -> void:
	points.append(world_position)
	ages.append(0.0)
	if points.size() > max_missile_points:
		points.pop_front()
		ages.pop_front()


func finish() -> void:
	finished = true


func set_direction(direction: Vector2) -> void:
	launch_direction = direction.normalized()


func _process(delta: float) -> void:
	if finished:
		finish_elapsed += delta
		if finish_elapsed >= finish_lifetime:
			queue_free()
			return

	for index in ages.size():
		ages[index] += delta
	while not ages.is_empty() and ages[0] >= sample_lifetime:
		ages.pop_front()
		points.pop_front()

	if finished and points.is_empty():
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE:
		_draw_missile_trail()
	elif weapon_family == WeaponSpec.WeaponFamily.ENERGY:
		_draw_streak(Color(0.35, 0.82, 1.0, 0.55))
	else:
		_draw_streak(Color(1.0, 0.78, 0.2, 0.55))


func _draw_streak(outer_color: Color) -> void:
	if points.size() < 2:
		return
	for index in points.size() - 1:
		var alpha := 1.0 - ages[index] / sample_lifetime
		var faded_outer := outer_color
		faded_outer.a *= alpha
		draw_line(points[index], points[index + 1], faded_outer, 3.0 * width_multiplier)
		draw_line(
			points[index],
			points[index + 1],
			Color(1.0, 1.0, 1.0, alpha * 0.9),
			width_multiplier
		)


func _draw_missile_trail() -> void:
	var trail_width := 3.0 * width_multiplier
	var finish_ratio := clampf(finish_elapsed / finish_lifetime, 0.0, 1.0) if finished else 0.0
	var finish_alpha := 1.0 - finish_ratio
	if points.size() >= 2:
		var line_points := PackedVector2Array(points)
		var line_colors := PackedColorArray()
		for index in points.size():
			var age_ratio := clampf(ages[index] / sample_lifetime, 0.0, 1.0)
			var trail_alpha := (1.0 - age_ratio) * 0.5 * finish_alpha
			line_colors.append(Color(0.88, 0.9, 0.92, trail_alpha))
		draw_polyline_colors(line_points, line_colors, trail_width)
	for index in points.size():
		var age_ratio := clampf(ages[index] / sample_lifetime, 0.0, 1.0)
		var smoke_alpha := (1.0 - age_ratio) * 0.5 * finish_alpha
		var expansion_ratio := clampf(
			age_ratio * smoke_expansion_speed_multiplier,
			0.0,
			1.0
		)
		var smoke_radius := (
			lerpf(3.0, 15.0, maxf(expansion_ratio, finish_ratio)) * width_multiplier
		)
		draw_circle(points[index], smoke_radius, Color(0.9, 0.92, 0.94, smoke_alpha))

	if not finished and not points.is_empty():
		var flame_position := points[-1] - launch_direction * 3.0 * width_multiplier
		draw_circle(
			flame_position,
			2.0 * width_multiplier,
			Color(1.0, 0.78, 0.18, 0.85)
		)
