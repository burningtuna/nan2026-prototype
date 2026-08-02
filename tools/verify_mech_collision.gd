extends SceneTree

const MECH_COLLISION_RESOLVER := preload("res://scripts/mech_collision_resolver.gd")


func _initialize() -> void:
	var first := AiMechAgent.new()
	var second := AiMechAgent.new()
	first.position = Vector2.ZERO
	second.position = Vector2(10.0, 0.0)
	first.velocity = Vector2(20.0, 4.0)
	second.velocity = Vector2(-10.0, -3.0)
	MECH_COLLISION_RESOLVER.resolve([first, second])
	var minimum_distance := first.mech_collision_radius + second.mech_collision_radius
	assert(is_equal_approx(first.position.distance_to(second.position), minimum_distance))
	assert(first.velocity.x <= 0.001)
	assert(second.velocity.x >= -0.001)
	assert(is_equal_approx(first.velocity.y, 4.0))
	assert(is_equal_approx(second.velocity.y, -3.0))

	var settled_first_position := first.position
	var settled_second_position := second.position
	MECH_COLLISION_RESOLVER.resolve([first, second])
	assert(first.position.is_equal_approx(settled_first_position))
	assert(second.position.is_equal_approx(settled_second_position))

	second.part_max_durability[&"Body"] = 1.0
	second.part_durability[&"Body"] = 0.0
	second.position = first.position
	MECH_COLLISION_RESOLVER.resolve([first, second])
	assert(second.position.is_equal_approx(first.position))
	first.free()
	second.free()
	print("MECH_COLLISION_CHECK passed")
	quit(0)
