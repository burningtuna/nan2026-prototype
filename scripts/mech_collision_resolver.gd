class_name MechCollisionResolver
extends RefCounted


static func resolve(combatants: Array) -> void:
	for first_index in combatants.size():
		var first := combatants[first_index] as AiMechAgent
		if not is_instance_valid(first) or first.is_defeated() or not first.mech_collision_enabled:
			continue
		for second_index in range(first_index + 1, combatants.size()):
			var second := combatants[second_index] as AiMechAgent
			if not is_instance_valid(second) or second.is_defeated() or not second.mech_collision_enabled:
				continue
			_resolve_pair(first, second)


static func _resolve_pair(first: AiMechAgent, second: AiMechAgent) -> void:
	var separation := second.global_position - first.global_position
	var minimum_distance := first.mech_collision_radius + second.mech_collision_radius
	if separation.length_squared() >= minimum_distance * minimum_distance:
		return
	if first.is_dashing():
		first.cancel_dash_after_collision()
	if second.is_dashing():
		second.cancel_dash_after_collision()
	var distance := separation.length()
	var normal := separation / distance if distance > 0.001 else Vector2.RIGHT
	var correction := normal * (minimum_distance - distance)
	if first.player_controlled:
		second.global_position += correction
	elif second.player_controlled:
		first.global_position -= correction
	else:
		first.global_position -= correction * 0.5
		second.global_position += correction * 0.5

	var first_inward_speed := first.velocity.dot(normal)
	if first_inward_speed > 0.0:
		first.velocity -= normal * first_inward_speed
	var second_inward_speed := second.velocity.dot(normal)
	if second_inward_speed < 0.0:
		second.velocity -= normal * second_inward_speed
