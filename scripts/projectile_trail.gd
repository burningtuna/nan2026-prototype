class_name ProjectileTrail
extends Node2D

var weapon_family := WeaponSpec.WeaponFamily.BALLISTIC
var launch_direction := Vector2.RIGHT
var sample_lifetime := 0.12
var sample_spacing := 2.0
var finish_lifetime := 1.0
var finish_elapsed := 0.0
var finished := false
var points: Array[Vector2] = []
var ages: Array[float] = []


func setup(family: WeaponSpec.WeaponFamily, direction: Vector2) -> void:
	weapon_family = family
	launch_direction = direction.normalized()
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE:
		sample_lifetime = 5.0
		sample_spacing = 6.0
	elif weapon_family == WeaponSpec.WeaponFamily.ENERGY:
		sample_lifetime = 0.16


func add_sample(world_position: Vector2) -> void:
	if finished:
		return
	if not points.is_empty() and points[-1].distance_to(world_position) < sample_spacing:
		return
	points.append(world_position)
	ages.append(0.0)
	queue_redraw()


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
		draw_line(points[index], points[index + 1], faded_outer, 3.0)
		draw_line(points[index], points[index + 1], Color(1.0, 1.0, 1.0, alpha * 0.9), 1.0)


func _draw_missile_trail() -> void:
	var camera := get_viewport().get_camera_2d()
	var camera_zoom := camera.zoom.x if camera != null else 1.0
	var trail_width := 3.0 / maxf(camera_zoom, 0.001)
	var finish_alpha := 1.0 - clampf(finish_elapsed / finish_lifetime, 0.0, 1.0) if finished else 1.0
	for index in points.size() - 1:
		var age_ratio := clampf(ages[index] / sample_lifetime, 0.0, 1.0)
		var trail_alpha := (1.0 - age_ratio) * 0.5 * finish_alpha
		draw_line(
			points[index],
			points[index + 1],
			Color(0.88, 0.9, 0.92, trail_alpha),
			trail_width
		)
	for index in points.size():
		var age_ratio := clampf(ages[index] / sample_lifetime, 0.0, 1.0)
		var smoke_alpha := (1.0 - age_ratio) * 0.5 * finish_alpha
		var smoke_radius := lerpf(3.0, 8.0, age_ratio)
		draw_circle(points[index], smoke_radius, Color(0.9, 0.92, 0.94, smoke_alpha))

	if not finished and not points.is_empty():
		var flame_position := points[-1] - launch_direction * 3.0
		draw_circle(flame_position, 2.0, Color(1.0, 0.78, 0.18, 0.85))
