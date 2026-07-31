class_name PartHitbox
extends Area2D

var mech: Node
var part_name: StringName
var hit_priority := 0


func setup(source_mech: Node, source_part: StringName, texture: Texture2D, priority: int) -> void:
	mech = source_mech
	part_name = source_part
	hit_priority = priority
	collision_layer = 2
	collision_mask = 0
	monitoring = false
	monitorable = true

	var image := texture.get_image()
	var used_rect := image.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		push_error("Part '%s' has no opaque pixels" % part_name)
		return

	position = (
		Vector2(used_rect.position)
		+ Vector2(used_rect.size) * 0.5
		- Vector2(image.get_size()) * 0.5
	)
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(used_rect.size)
	var collision_shape := CollisionShape2D.new()
	collision_shape.shape = rectangle
	add_child(collision_shape)
