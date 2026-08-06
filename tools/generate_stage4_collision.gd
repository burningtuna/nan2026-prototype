extends SceneTree

const SOURCE_PATH := "res://Sprites/Background/Stage4_Structure.png"
const OUTPUT_PATH := "res://data/stage4_collision_polygons.json"
const SIMPLIFICATION_EPSILON := 2.0


func _initialize() -> void:
	var texture := load(SOURCE_PATH) as Texture2D
	assert(texture != null)
	var image := texture.get_image()
	assert(image != null and not image.is_empty())
	var bitmap := BitMap.new()
	bitmap.create(image.get_size())
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			bitmap.set_bit(x, y, color.b > color.r)
	var polygons := bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, image.get_size()),
		SIMPLIFICATION_EPSILON
	)
	var serialized_polygons: Array = []
	var vertex_count := 0
	for polygon: PackedVector2Array in polygons:
		if polygon.size() < 3:
			continue
		var points: Array = []
		for point in polygon:
			points.append([snappedf(point.x, 0.01), snappedf(point.y, 0.01)])
		serialized_polygons.append(points)
		vertex_count += points.size()
	var sample_count := 0
	var mismatch_count := 0
	for y in range(4, image.get_height(), 8):
		for x in range(4, image.get_width(), 8):
			var source_color := image.get_pixel(x, y)
			var source_blocked := source_color.b > source_color.r
			var vector_blocked := false
			for polygon: PackedVector2Array in polygons:
				if Geometry2D.is_point_in_polygon(Vector2(x, y), polygon):
					vector_blocked = true
					break
			if source_blocked != vector_blocked:
				mismatch_count += 1
			sample_count += 1
	var mismatch_ratio := float(mismatch_count) / maxf(float(sample_count), 1.0)
	assert(
		mismatch_ratio < 0.01,
		"Vector collision differs from source at %.2f%% of samples" % (mismatch_ratio * 100.0)
	)
	var document := {
		"schema_version": 1,
		"source": SOURCE_PATH,
		"source_size": [image.get_width(), image.get_height()],
		"simplification_epsilon": SIMPLIFICATION_EPSILON,
		"blocked_polygons": serialized_polygons,
	}
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(document, "  ") + "\n")
	file.close()
	print(
		"STAGE4_VECTOR_COLLISION generated %d polygons / %d vertices / %.3f%% mismatch" % [
			serialized_polygons.size(), vertex_count, mismatch_ratio * 100.0,
		]
	)
	quit(0)
