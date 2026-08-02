class_name SpriteAnchorMap
extends RefCounted

const COLOR_TO_ANCHOR := {
	"FF0000": &"mount",
	"FF8000": &"head_socket",
	"80FF00": &"legs_socket",
	"FFFF00": &"left_arm_socket",
	"00FF00": &"right_arm_socket",
	"8000FF": &"backpack_socket",
	"FF00FF": &"aim_pivot",
	"0000FF": &"muzzle",
	"00FFFF": &"boost",
	"FF0080": &"casing_eject",
}


static func load_map(texture_path: String) -> Dictionary:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_error("Unable to load anchor texture: %s" % texture_path)
		return {}

	var image := texture.get_image()
	var anchors := {}

	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a < 0.99:
				continue

			var color_key := color.to_html(false).to_upper()
			var anchor_name: StringName = COLOR_TO_ANCHOR.get(color_key, &"")
			if anchor_name.is_empty():
				push_warning("Unknown anchor color #%s in %s at (%d, %d)" % [color_key, texture_path, x, y])
				continue

			if not anchors.has(anchor_name):
				anchors[anchor_name] = []
			anchors[anchor_name].append(_pixel_to_local(image.get_size(), Vector2i(x, y)))

	return {
		"size": image.get_size(),
		"anchors": anchors,
	}


static func one(anchor_map: Dictionary, anchor_name: StringName) -> Vector2:
	var points := many(anchor_map, anchor_name)
	if points.size() != 1:
		push_error("Anchor '%s' must occur exactly once, found %d" % [anchor_name, points.size()])
		return Vector2.ZERO
	return points[0]


static func many(anchor_map: Dictionary, anchor_name: StringName) -> Array[Vector2]:
	var anchors: Dictionary = anchor_map.get("anchors", {})
	var raw_points: Array = anchors.get(anchor_name, [])
	var points: Array[Vector2] = []
	for point in raw_points:
		points.append(point as Vector2)
	return points


static func _pixel_to_local(image_size: Vector2i, pixel: Vector2i) -> Vector2:
	return Vector2(pixel) + Vector2(0.5, 0.5) - Vector2(image_size) * 0.5
