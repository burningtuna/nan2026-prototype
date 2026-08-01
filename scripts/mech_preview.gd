class_name MechPreview
extends Node2D

const AnchorMap := preload("res://scripts/sprite_anchor_map.gd")

var _assembly_root: Node2D


func _ready() -> void:
	_assembly_root = Node2D.new()
	add_child(_assembly_root)


func display(loadout: MechLoadout) -> void:
	if _assembly_root == null:
		return
	for child in _assembly_root.get_children():
		_assembly_root.remove_child(child)
		child.queue_free()
	if loadout == null or loadout.body == null:
		return

	var body_map := AnchorMap.load_map(loadout.body.anchor_path)
	_add_sprite(_assembly_root, loadout.body, Vector2.ZERO, 3)
	_attach_static(loadout.backpack, body_map, &"backpack_socket", 1)
	_attach_static(loadout.legs, body_map, &"legs_socket", 2)
	_attach_static(loadout.head, body_map, &"head_socket", 5)
	_attach_arm(loadout.left_arm, body_map, &"left_arm_socket")
	_attach_arm(loadout.right_arm, body_map, &"right_arm_socket")


func _attach_static(part: MechPartSpec, body_map: Dictionary, socket: StringName, layer: int) -> void:
	if part == null:
		return
	var socket_position := AnchorMap.one(body_map, socket)
	var part_map := AnchorMap.load_map(part.anchor_path)
	var mount := AnchorMap.one(part_map, &"mount")
	_add_sprite(_assembly_root, part, socket_position - mount, layer)


func _attach_arm(part: MechPartSpec, body_map: Dictionary, socket: StringName) -> void:
	if part == null:
		return
	var socket_position := AnchorMap.one(body_map, socket)
	var part_map := AnchorMap.load_map(part.anchor_path)
	var mount := AnchorMap.one(part_map, &"mount")
	var pivot := AnchorMap.one(part_map, &"aim_pivot")
	var aim_root := Node2D.new()
	aim_root.position = socket_position + pivot - mount
	aim_root.rotation = -PI * 0.5
	_assembly_root.add_child(aim_root)
	_add_sprite(aim_root, part, -pivot, 4)


func _add_sprite(parent: Node2D, part: MechPartSpec, sprite_position: Vector2, layer: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = load(part.art_path) as Texture2D
	sprite.position = sprite_position
	sprite.modulate = part.preview_tint
	sprite.z_index = layer
	parent.add_child(sprite)
