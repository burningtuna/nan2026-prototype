class_name AlienInfestationOverlay
extends Node2D

const META_KEY := &"alien_infestation_overlay"
const GLOW_COLOR := Color(0.9, 0.55, 1.0, 0.88)
const POINT_COUNT := 2

static var opaque_pixels_by_texture := {}

var target: Node2D
var pulse_time := 0.0
var infestation_points: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


static func attach_to(host: Node2D) -> AlienInfestationOverlay:
	if not is_instance_valid(host) or host.get_parent() == null:
		return null
	var existing := (
		host.get_meta(META_KEY) as AlienInfestationOverlay
		if host.has_meta(META_KEY)
		else null
	)
	if is_instance_valid(existing):
		return existing
	var overlay := AlienInfestationOverlay.new()
	overlay.target = host
	overlay.z_as_relative = false
	overlay.z_index = 20
	host.get_parent().add_child(overlay)
	host.set_meta(META_KEY, overlay)
	host.tree_exiting.connect(overlay._on_target_exiting)
	overlay._sync_to_target()
	overlay.rng.seed = host.get_instance_id()
	overlay._select_infestation_points()
	return overlay


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		queue_free()
		return
	pulse_time += delta
	_sync_to_target()
	if _visible_point_count() < POINT_COUNT:
		_select_infestation_points()
	queue_redraw()


func _draw() -> void:
	var pulse := (sin(pulse_time * 3.2) + 1.0) * 0.5
	var glow := Color(GLOW_COLOR, lerpf(0.65, 0.95, pulse))
	for point in infestation_points:
		var sprite := point["sprite"] as Sprite2D
		if not is_instance_valid(sprite) or not sprite.is_visible_in_tree():
			continue
		var position := to_local(sprite.to_global(point["local_position"]))
		draw_circle(position, lerpf(1.0, 1.6, pulse), glow)


func _select_infestation_points() -> void:
	infestation_points.clear()
	var entries: Array[Dictionary] = []
	var total_pixels := 0
	for node in target.find_children("*", "Sprite2D", true, false):
		var sprite := node as Sprite2D
		if not _is_visible_part_sprite(sprite):
			continue
		var pixels := _opaque_pixels(sprite.texture)
		if pixels.is_empty():
			continue
		entries.append({"sprite": sprite, "pixels": pixels})
		total_pixels += pixels.size()
	if total_pixels <= 0:
		return

	var selected_indices := {}
	while infestation_points.size() < mini(POINT_COUNT, total_pixels):
		var selected := rng.randi_range(0, total_pixels - 1)
		if selected_indices.has(selected):
			continue
		selected_indices[selected] = true
		var entry := _entry_for_pixel_index(entries, selected)
		var sprite := entry["sprite"] as Sprite2D
		var pixel := entry["pixel"] as Vector2
		infestation_points.append({
			"sprite": sprite,
			"local_position": _pixel_to_sprite_position(sprite, pixel),
		})


func _is_visible_part_sprite(sprite: Sprite2D) -> bool:
	if not is_instance_valid(sprite) or not sprite.visible or sprite.texture == null:
		return false
	for child in sprite.get_children():
		if child is PartHitbox:
			return true
	return false


func _opaque_pixels(texture: Texture2D) -> PackedVector2Array:
	var key := texture.resource_path
	if key.is_empty():
		key = str(texture.get_instance_id())
	if opaque_pixels_by_texture.has(key):
		return opaque_pixels_by_texture[key]
	var pixels := PackedVector2Array()
	var image := texture.get_image()
	if image != null:
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.1:
					pixels.append(Vector2(x, y))
	opaque_pixels_by_texture[key] = pixels
	return pixels


func _entry_for_pixel_index(entries: Array[Dictionary], selected: int) -> Dictionary:
	var offset := selected
	for entry in entries:
		var pixels: PackedVector2Array = entry["pixels"]
		if offset < pixels.size():
			return {"sprite": entry["sprite"], "pixel": pixels[offset]}
		offset -= pixels.size()
	return {}


func _pixel_to_sprite_position(sprite: Sprite2D, pixel: Vector2) -> Vector2:
	var position := pixel + Vector2(0.5, 0.5) + sprite.offset
	if sprite.centered:
		position -= sprite.texture.get_size() * 0.5
	return position


func _visible_point_count() -> int:
	var count := 0
	for point in infestation_points:
		var sprite := point["sprite"] as Sprite2D
		if is_instance_valid(sprite) and sprite.is_visible_in_tree():
			count += 1
	return count


func _sync_to_target() -> void:
	global_transform = target.global_transform
	modulate.a = 0.5 if target.has_method("is_defeated") and target.is_defeated() else 1.0


func _on_target_exiting() -> void:
	target = null
	queue_free()
