class_name MechWireframePreview
extends Node2D

enum PartState {
	HEALTHY,
	DAMAGED,
	CRITICAL,
	DESTROYED,
}

const AnchorMap := preload("res://scripts/sprite_anchor_map.gd")
const HEALTHY_COLOR := Color("35d070")
const DAMAGED_COLOR := Color("f2cf45")
const CRITICAL_COLOR := Color("ef4e42")
const DESTROYED_COLOR := Color("111719")

const SAMPLE_PATHS := {
	&"Body": [
		"res://Sprites/Wireframe/Body-0001.png",
		"res://Sprites/Wireframe/Body-0001.anchors.png",
	],
	&"Head": [
		"res://Sprites/Wireframe/Head-0001.png",
		"res://Sprites/Wireframe/Head-0001.anchors.png",
	],
	&"Legs": [
		"res://Sprites/Wireframe/Legs-0001.png",
		"res://Sprites/Wireframe/Legs-0001.anchors.png",
	],
	&"LeftArm": [
		"res://Sprites/Wireframe/Arm-Cannon-0001.png",
		"res://Sprites/Wireframe/Arm-Cannon-0001.anchors.png",
	],
	&"RightArm": [
		"res://Sprites/Wireframe/Arm-Cannon-0001.png",
		"res://Sprites/Wireframe/Arm-Cannon-0001.anchors.png",
	],
	&"Backpack": [
		"res://Sprites/Wireframe/Backpack-Generator-0001.png",
		"res://Sprites/Wireframe/Backpack-Generator-0001.anchors.png",
	],
}

var part_sprites: Dictionary = {}


func display_sample() -> void:
	_assemble(SAMPLE_PATHS)


func display(loadout: MechLoadout) -> void:
	if loadout == null or loadout.body == null:
		_clear()
		return
	var paths := {
		&"Body": _wireframe_paths(loadout.body),
		&"Head": _wireframe_paths(loadout.head),
		&"Legs": _wireframe_paths(loadout.legs),
		&"LeftArm": _wireframe_paths(loadout.left_arm),
		&"RightArm": _wireframe_paths(loadout.right_arm),
		&"Backpack": _wireframe_paths(loadout.backpack),
	}
	_assemble(paths)


func set_part_state(part_name: StringName, state: PartState) -> void:
	var sprite := part_sprites.get(part_name) as Sprite2D
	if sprite == null:
		return
	match state:
		PartState.HEALTHY:
			sprite.modulate = HEALTHY_COLOR
		PartState.DAMAGED:
			sprite.modulate = DAMAGED_COLOR
		PartState.CRITICAL:
			sprite.modulate = CRITICAL_COLOR
		PartState.DESTROYED:
			sprite.modulate = DESTROYED_COLOR


func _wireframe_paths(part: MechPartSpec) -> Array:
	if part == null or part.wireframe_art_path.is_empty() or part.wireframe_anchor_path.is_empty():
		return []
	return [part.wireframe_art_path, part.wireframe_anchor_path]


func _assemble(paths: Dictionary) -> void:
	_clear()
	var body_paths: Array = paths.get(&"Body", [])
	if body_paths.size() < 2:
		return
	var body_map := AnchorMap.load_map(body_paths[1])
	_add_part(&"Body", body_paths[0], Vector2.ZERO, 3)
	_attach_part(paths, body_map, &"Backpack", &"backpack_socket", 1)
	_attach_part(paths, body_map, &"Legs", &"legs_socket", 2)
	_attach_part(paths, body_map, &"LeftArm", &"left_arm_socket", 4)
	_attach_part(paths, body_map, &"RightArm", &"right_arm_socket", 4, true)
	_attach_part(paths, body_map, &"Head", &"head_socket", 5)


func _attach_part(
	paths: Dictionary,
	body_map: Dictionary,
	part_name: StringName,
	socket_name: StringName,
	layer: int,
	flip_h := false
) -> void:
	var part_paths: Array = paths.get(part_name, [])
	if part_paths.size() < 2:
		return
	var socket := AnchorMap.one(body_map, socket_name)
	var part_map := AnchorMap.load_map(part_paths[1])
	var mount := AnchorMap.one(part_map, &"mount")
	var sprite_position := socket - mount
	if flip_h:
		sprite_position.x = socket.x + mount.x
	var sprite := _add_part(part_name, part_paths[0], sprite_position, layer)
	sprite.flip_h = flip_h


func _add_part(part_name: StringName, art_path: String, sprite_position: Vector2, layer: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "%sWireframe" % part_name
	sprite.texture = load(art_path) as Texture2D
	sprite.position = sprite_position
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = layer
	sprite.modulate = HEALTHY_COLOR
	add_child(sprite)
	part_sprites[part_name] = sprite
	return sprite


func _clear() -> void:
	part_sprites.clear()
	for child in get_children():
		remove_child(child)
		child.queue_free()
