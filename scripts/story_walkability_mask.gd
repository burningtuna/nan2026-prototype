class_name StoryWalkabilityMask
extends StoryWalkableArea

const WALL_SLIDE_SPEED_MULTIPLIER := 0.65
const SLIDE_EPSILON := 0.0001
const SLIDE_DIRECTION_EPSILON := 0.001

@export var mask_texture: Texture2D
@export var map_rect := Rect2(-3000.0, -1630.0, 6000.0, 3260.0)
@export_range(2, 32, 1) var collision_cell_pixels := 8
@export_range(0, 3, 1) var blocked_margin_cells := 1

var mask_image: Image
var collision_grid := PackedByteArray()
var collision_grid_size := Vector2i.ZERO


func _ready() -> void:
	add_to_group(&"projectile_mask_blockers")
	add_to_group(&"radar_terrain_masks")
	if mask_texture != null:
		mask_image = mask_texture.get_image()
		_build_collision_grid()


func contains_global_point(point: Vector2) -> bool:
	return _is_accessible_local(to_local(point))


func radar_point_is_accessible(world_point: Vector2) -> bool:
	return contains_global_point(world_point)


func contains_agent_at(center_global: Vector2, radius: float) -> bool:
	if not contains_global_point(center_global):
		return false
	if radius <= 0.0:
		return true
	var cell_world_size := maxf(
		map_rect.size.x / maxf(float(collision_grid_size.x), 1.0),
		map_rect.size.y / maxf(float(collision_grid_size.y), 1.0)
	)
	var ring_step := maxf(cell_world_size * 0.5, 4.0)
	var ring_radius := ring_step
	while ring_radius < radius:
		if not _is_accessible_ring(center_global, ring_radius, ring_step):
			return false
		ring_radius += ring_step
	if not _is_accessible_ring(center_global, radius, ring_step):
		return false
	return true


func _is_accessible_ring(center_global: Vector2, radius: float, arc_step: float) -> bool:
	var sample_count := maxi(ceili(TAU * radius / maxf(arc_step, 1.0)), 12)
	for index in sample_count:
		var sample := center_global + Vector2.from_angle(TAU * float(index) / float(sample_count)) * radius
		if not contains_global_point(sample):
			return false
	return true


func contains_agent_motion(start_global: Vector2, end_global: Vector2, radius: float) -> bool:
	var distance := start_global.distance_to(end_global)
	var step_size := 2.0
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
	if remaining.length_squared() <= SLIDE_EPSILON ** 2:
		return impact_position
	var normal := _blocked_normal(impact_position, radius, remaining.normalized())
	var slide := remaining - normal * remaining.dot(normal)
	if slide.length_squared() <= remaining.length_squared() * SLIDE_DIRECTION_EPSILON ** 2:
		return impact_position
	var scaled_slide := slide * WALL_SLIDE_SPEED_MULTIPLIER
	var slide_candidates: Array[Vector2] = [scaled_slide]
	# A small outward bias keeps the tangent clear of stepped collision-grid edges.
	for outward_ratio in [0.025, 0.05, 0.1]:
		slide_candidates.append(
			scaled_slide - normal * scaled_slide.length() * outward_ratio
		)
	var best_position := impact_position
	var tangent_direction := slide.normalized()
	var best_tangent_progress := (impact_position - start_global).dot(tangent_direction)
	for candidate_motion in slide_candidates:
		var candidate := _furthest_valid_position(
			impact_position,
			impact_position + candidate_motion,
			radius
		)
		var tangent_progress := (candidate - start_global).dot(tangent_direction)
		if tangent_progress > best_tangent_progress:
			best_position = candidate
			best_tangent_progress = tangent_progress
	return best_position


func _furthest_valid_position(start_global: Vector2, end_global: Vector2, radius: float) -> Vector2:
	var distance := start_global.distance_to(end_global)
	var step_size := 2.0
	var steps := maxi(ceili(distance / step_size), 1)
	var last_valid := start_global
	for index in range(1, steps + 1):
		var sample := start_global.lerp(end_global, float(index) / float(steps))
		if not contains_agent_at(sample, radius):
			var invalid_position := sample
			for _refinement in 6:
				var midpoint := last_valid.lerp(invalid_position, 0.5)
				if contains_agent_at(midpoint, radius):
					last_valid = midpoint
				else:
					invalid_position = midpoint
			return last_valid
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
	var steps := maxi(ceili(distance / 2.0), 1)
	for index in range(steps + 1):
		var sample := start_local.lerp(end_local, float(index) / float(steps))
		if not _is_accessible_local(sample):
			return to_global(sample)
	return null


func _is_accessible_local(local_point: Vector2) -> bool:
	if mask_image == null or mask_image.is_empty() or collision_grid.is_empty():
		return false
	if not map_rect.has_point(local_point):
		return false
	var normalized := (local_point - map_rect.position) / map_rect.size
	var cell := Vector2i(
		clampi(floori(normalized.x * collision_grid_size.x), 0, collision_grid_size.x - 1),
		clampi(floori(normalized.y * collision_grid_size.y), 0, collision_grid_size.y - 1)
	)
	return collision_grid[cell.y * collision_grid_size.x + cell.x] == 0


func _build_collision_grid() -> void:
	var cell_size := maxi(collision_cell_pixels, 2)
	collision_grid_size = Vector2i(
		ceili(float(mask_image.get_width()) / float(cell_size)),
		ceili(float(mask_image.get_height()) / float(cell_size))
	)
	var raw_grid := PackedByteArray()
	raw_grid.resize(collision_grid_size.x * collision_grid_size.y)
	for cell_y in collision_grid_size.y:
		for cell_x in collision_grid_size.x:
			var blocked_samples := 0
			for sample_y in 3:
				for sample_x in 3:
					var pixel := Vector2i(
						mini(cell_x * cell_size + floori((float(sample_x) + 0.5) * cell_size / 3.0), mask_image.get_width() - 1),
						mini(cell_y * cell_size + floori((float(sample_y) + 0.5) * cell_size / 3.0), mask_image.get_height() - 1)
					)
					var color := mask_image.get_pixelv(pixel)
					if color.b > color.r:
						blocked_samples += 1
			raw_grid[cell_y * collision_grid_size.x + cell_x] = 1 if blocked_samples >= 3 else 0
	collision_grid = raw_grid.duplicate()
	for cell_y in collision_grid_size.y:
		for cell_x in collision_grid_size.x:
			if raw_grid[cell_y * collision_grid_size.x + cell_x] == 0:
				continue
			for offset_y in range(-blocked_margin_cells, blocked_margin_cells + 1):
				for offset_x in range(-blocked_margin_cells, blocked_margin_cells + 1):
					var target_x := cell_x + offset_x
					var target_y := cell_y + offset_y
					if target_x >= 0 and target_x < collision_grid_size.x and target_y >= 0 and target_y < collision_grid_size.y:
						collision_grid[target_y * collision_grid_size.x + target_x] = 1
