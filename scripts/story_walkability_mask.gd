class_name StoryWalkabilityMask
extends StoryWalkableArea

const WALL_SLIDE_SPEED_MULTIPLIER := 0.65
const SLIDE_EPSILON := 0.0001
const SLIDE_DIRECTION_EPSILON := 0.001
const COLLISION_CELL_SIZE := 128.0

@export var mask_texture: Texture2D
@export var map_rect := Rect2(-3000.0, -1630.0, 6000.0, 3260.0)
@export_file("*.json") var collision_polygons_path := ""

var blocked_polygons: Array[PackedVector2Array] = []
var blocked_edges: Array = []
var blocked_polygon_bounds: Array[Rect2] = []
var blocked_edge_cells := {}
var blocked_edge_query_marks := PackedInt32Array()
var blocked_edge_query_id := 0
var mask_image: Image


func _ready() -> void:
	add_to_group(&"projectile_mask_blockers")
	add_to_group(&"radar_terrain_masks")
	_load_collision_polygons()
	if mask_texture != null:
		mask_image = mask_texture.get_image()


func contains_global_point(point: Vector2) -> bool:
	return _is_accessible_local(to_local(point))


func radar_point_is_accessible(world_point: Vector2) -> bool:
	var local_point := to_local(world_point)
	if not map_rect.has_point(local_point):
		return false
	if mask_image == null or mask_image.is_empty():
		return _is_accessible_local(local_point)
	var normalized := (local_point - map_rect.position) / map_rect.size
	var pixel := Vector2i(
		clampi(floori(normalized.x * mask_image.get_width()), 0, mask_image.get_width() - 1),
		clampi(floori(normalized.y * mask_image.get_height()), 0, mask_image.get_height() - 1)
	)
	var color := mask_image.get_pixelv(pixel)
	return color.b <= color.r


func contains_agent_at(center_global: Vector2, radius: float) -> bool:
	if not contains_global_point(center_global):
		return false
	if radius <= 0.0:
		return true
	var center_local := to_local(center_global)
	var local_radius := to_local(center_global + Vector2(radius, 0.0)).distance_to(center_local)
	if not map_rect.grow(-local_radius).has_point(center_local):
		return false
	var radius_squared := local_radius ** 2
	var query_rect := Rect2(
		center_local - Vector2.ONE * local_radius,
		Vector2.ONE * local_radius * 2.0
	)
	for edge_index in _edge_indices_in_rect(query_rect):
		var edge = blocked_edges[edge_index]
		var closest := Geometry2D.get_closest_point_to_segment(center_local, edge[0], edge[1])
		if center_local.distance_squared_to(closest) < radius_squared:
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
	var center_local := to_local(center_global)
	var fallback_local := to_local(center_global + fallback) - center_local
	var best_normal := Vector2.ZERO
	var best_distance_squared := INF
	var best_alignment := -INF
	var edge_indices := _edge_indices_in_rect(
		Rect2(center_local - Vector2.ONE * (radius + 2.0), Vector2.ONE * (radius + 2.0) * 2.0)
	)
	var corners := [
		map_rect.position,
		Vector2(map_rect.end.x, map_rect.position.y),
		map_rect.end,
		Vector2(map_rect.position.x, map_rect.end.y),
	]
	var nearby_edges: Array = []
	for edge_index in edge_indices:
		nearby_edges.append(blocked_edges[edge_index])
	for index in 4:
		nearby_edges.append([corners[index], corners[(index + 1) % 4]])
	for edge in nearby_edges:
		var closest := Geometry2D.get_closest_point_to_segment(center_local, edge[0], edge[1])
		var offset := closest - center_local
		if offset.is_zero_approx():
			continue
		var distance_squared := offset.length_squared()
		var alignment := offset.normalized().dot(fallback_local.normalized())
		if (
			distance_squared < best_distance_squared - 0.01
			or (
				is_equal_approx(distance_squared, best_distance_squared)
				and alignment > best_alignment
			)
		):
			best_normal = offset.normalized()
			best_distance_squared = distance_squared
			best_alignment = alignment
	if best_normal.is_zero_approx():
		return fallback
	return (to_global(center_local + best_normal) - center_global).normalized()


func projectile_block_position(start_global: Vector2, end_global: Vector2):
	var start_local := to_local(start_global)
	var end_local := to_local(end_global)
	if not _is_accessible_local(start_local):
		return start_global
	var nearest_hit = null
	var nearest_distance_squared := INF
	var segment_rect := Rect2(start_local, end_local - start_local).abs().grow(0.01)
	for edge_index in _edge_indices_in_rect(segment_rect):
		var edge = blocked_edges[edge_index]
		var hit = Geometry2D.segment_intersects_segment(
			start_local,
			end_local,
			edge[0],
			edge[1]
		)
		if not hit is Vector2:
			continue
		var distance_squared := start_local.distance_squared_to(hit)
		if distance_squared < nearest_distance_squared:
			nearest_hit = hit
			nearest_distance_squared = distance_squared
	if nearest_hit is Vector2:
		return to_global(nearest_hit)
	if not map_rect.has_point(end_local):
		var corners := [
			map_rect.position,
			Vector2(map_rect.end.x, map_rect.position.y),
			map_rect.end,
			Vector2(map_rect.position.x, map_rect.end.y),
		]
		for index in 4:
			var hit = Geometry2D.segment_intersects_segment(
				start_local,
				end_local,
				corners[index],
				corners[(index + 1) % 4]
			)
			if not hit is Vector2:
				continue
			var distance_squared := start_local.distance_squared_to(hit)
			if distance_squared < nearest_distance_squared:
				nearest_hit = hit
				nearest_distance_squared = distance_squared
	return to_global(nearest_hit) if nearest_hit is Vector2 else null


func _is_accessible_local(local_point: Vector2) -> bool:
	if blocked_polygons.is_empty():
		return false
	if not map_rect.has_point(local_point):
		return false
	for index in blocked_polygons.size():
		if not blocked_polygon_bounds[index].has_point(local_point):
			continue
		var polygon := blocked_polygons[index]
		if Geometry2D.is_point_in_polygon(local_point, polygon):
			return false
	return true


func _load_collision_polygons() -> void:
	blocked_polygons.clear()
	blocked_edges.clear()
	blocked_polygon_bounds.clear()
	blocked_edge_cells.clear()
	blocked_edge_query_marks.clear()
	if collision_polygons_path.is_empty() or not FileAccess.file_exists(collision_polygons_path):
		push_error("Missing vector collision data: %s" % collision_polygons_path)
		return
	var file := FileAccess.open(collision_polygons_path, FileAccess.READ)
	if file == null:
		push_error("Unable to read vector collision data: %s" % collision_polygons_path)
		return
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		push_error("Invalid vector collision data: %s" % collision_polygons_path)
		return
	var document: Dictionary = parser.data
	var source_size_data = document.get("source_size", [])
	var polygon_data = document.get("blocked_polygons", [])
	if (
		int(document.get("schema_version", 0)) != 1
		or not source_size_data is Array
		or source_size_data.size() != 2
		or not polygon_data is Array
	):
		push_error("Unsupported vector collision data: %s" % collision_polygons_path)
		return
	var source_size := Vector2(float(source_size_data[0]), float(source_size_data[1]))
	if source_size.x <= 0.0 or source_size.y <= 0.0:
		push_error("Invalid vector collision source size: %s" % collision_polygons_path)
		return
	for serialized_polygon in polygon_data:
		if not serialized_polygon is Array or serialized_polygon.size() < 3:
			continue
		var polygon := PackedVector2Array()
		for serialized_point in serialized_polygon:
			if not serialized_point is Array or serialized_point.size() != 2:
				continue
			var source_point := Vector2(
				float(serialized_point[0]),
				float(serialized_point[1])
			)
			polygon.append(map_rect.position + source_point / source_size * map_rect.size)
		if polygon.size() < 3:
			continue
		blocked_polygons.append(polygon)
		var polygon_bounds := Rect2(polygon[0], Vector2.ZERO)
		for point in polygon:
			polygon_bounds = polygon_bounds.expand(point)
		blocked_polygon_bounds.append(polygon_bounds)
		for index in polygon.size():
			blocked_edges.append([polygon[index], polygon[(index + 1) % polygon.size()]])
	_build_edge_index()


func _build_edge_index() -> void:
	blocked_edge_cells.clear()
	blocked_edge_query_marks.resize(blocked_edges.size())
	blocked_edge_query_marks.fill(0)
	blocked_edge_query_id = 0
	for edge_index in blocked_edges.size():
		var edge = blocked_edges[edge_index]
		var edge_rect := Rect2(edge[0], edge[1] - edge[0]).abs().grow(0.01)
		var first_cell := _collision_cell(edge_rect.position)
		var last_cell := _collision_cell(edge_rect.end)
		for cell_y in range(first_cell.y, last_cell.y + 1):
			for cell_x in range(first_cell.x, last_cell.x + 1):
				var cell := Vector2i(cell_x, cell_y)
				if not blocked_edge_cells.has(cell):
					blocked_edge_cells[cell] = []
				blocked_edge_cells[cell].append(edge_index)


func _edge_indices_in_rect(query_rect: Rect2) -> Array[int]:
	var result: Array[int] = []
	if blocked_edges.is_empty():
		return result
	blocked_edge_query_id += 1
	var first_cell := _collision_cell(query_rect.position)
	var last_cell := _collision_cell(query_rect.end)
	for cell_y in range(first_cell.y, last_cell.y + 1):
		for cell_x in range(first_cell.x, last_cell.x + 1):
			var edge_indices = blocked_edge_cells.get(Vector2i(cell_x, cell_y), [])
			for edge_index in edge_indices:
				if blocked_edge_query_marks[edge_index] == blocked_edge_query_id:
					continue
				blocked_edge_query_marks[edge_index] = blocked_edge_query_id
				result.append(edge_index)
	return result


func _collision_cell(point: Vector2) -> Vector2i:
	return Vector2i(
		floori(point.x / COLLISION_CELL_SIZE),
		floori(point.y / COLLISION_CELL_SIZE)
	)
