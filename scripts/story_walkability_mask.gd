class_name StoryWalkabilityMask
extends StoryWalkableArea

@export var mask_texture: Texture2D
@export var map_rect := Rect2(-3000.0, -1630.0, 6000.0, 3260.0)

var mask_image: Image


func _ready() -> void:
	add_to_group(&"projectile_mask_blockers")
	if mask_texture != null:
		mask_image = mask_texture.get_image()


func contains_global_point(point: Vector2) -> bool:
	return _is_accessible_local(to_local(point))


func contains_agent_at(center_global: Vector2, radius: float) -> bool:
	if not contains_global_point(center_global):
		return false
	if radius <= 0.0:
		return true
	var sample_count := maxi(ceili(TAU * radius / 4.0), 12)
	for index in sample_count:
		var sample := center_global + Vector2.from_angle(TAU * float(index) / float(sample_count)) * radius
		if not contains_global_point(sample):
			return false
	return true


func contains_agent_motion(start_global: Vector2, end_global: Vector2, radius: float) -> bool:
	var distance := start_global.distance_to(end_global)
	var step_size := maxf(radius * 0.5, 4.0)
	var steps := maxi(ceili(distance / step_size), 1)
	for index in range(steps + 1):
		var sample := start_global.lerp(end_global, float(index) / float(steps))
		if not contains_agent_at(sample, radius):
			return false
	return true


func resolve_sliding_motion(start_global: Vector2, end_global: Vector2, radius: float) -> Vector2:
	if start_global.is_equal_approx(end_global) or not contains_agent_at(start_global, radius):
		return start_global
	var impact_position := _furthest_valid_position(start_global, end_global, radius)
	var remaining := end_global - impact_position
	if remaining.length_squared() <= 1.0:
		return impact_position
	var normal := _blocked_normal(impact_position, radius, remaining.normalized())
	var slide := remaining - normal * remaining.dot(normal)
	if slide.length_squared() <= 1.0:
		return impact_position
	return _furthest_valid_position(impact_position, impact_position + slide, radius)


func _furthest_valid_position(start_global: Vector2, end_global: Vector2, radius: float) -> Vector2:
	var distance := start_global.distance_to(end_global)
	var step_size := maxf(radius * 0.25, 4.0)
	var steps := maxi(ceili(distance / step_size), 1)
	var last_valid := start_global
	for index in range(1, steps + 1):
		var sample := start_global.lerp(end_global, float(index) / float(steps))
		if not contains_agent_at(sample, radius):
			break
		last_valid = sample
	return last_valid


func _blocked_normal(center_global: Vector2, radius: float, fallback: Vector2) -> Vector2:
	var normal := Vector2.ZERO
	var probe_distance := maxf(radius * 0.35, 6.0)
	for index in 24:
		var direction := Vector2.from_angle(TAU * float(index) / 24.0)
		if not contains_agent_at(center_global + direction * probe_distance, radius):
			normal += direction
	return normal.normalized() if not normal.is_zero_approx() else fallback


func projectile_block_position(start_global: Vector2, end_global: Vector2):
	var start_local := to_local(start_global)
	var end_local := to_local(end_global)
	var distance := start_local.distance_to(end_local)
	var steps := maxi(ceili(distance / 4.0), 1)
	for index in range(steps + 1):
		var sample := start_local.lerp(end_local, float(index) / float(steps))
		if not _is_accessible_local(sample):
			return to_global(sample)
	return null


func _is_accessible_local(local_point: Vector2) -> bool:
	if mask_image == null or mask_image.is_empty():
		return false
	if not map_rect.has_point(local_point):
		return false
	var normalized := (local_point - map_rect.position) / map_rect.size
	var pixel := Vector2i(
		clampi(floori(normalized.x * mask_image.get_width()), 0, mask_image.get_width() - 1),
		clampi(floori(normalized.y * mask_image.get_height()), 0, mask_image.get_height() - 1)
	)
	var color := mask_image.get_pixelv(pixel)
	return color.r > color.b
