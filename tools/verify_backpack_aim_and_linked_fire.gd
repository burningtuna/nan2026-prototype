extends SceneTree


class LinkedFireAgent extends AiMechAgent:
	var fired_parts: Array[StringName] = []

	func _fire_weapon(weapon: WeaponRuntime, _reserved_energy := 0.0) -> bool:
		fired_parts.append(weapon.part_name)
		weapon.cooldown_remaining = 1.0
		return true


func _initialize() -> void:
	_verify_offset_backpack_aim()
	_verify_all_weapons_continues_after_preparation()
	_verify_single_selection_still_waits()
	_verify_second_preparation_does_not_replace_first()
	print("BACKPACK_AIM_LINKED_FIRE_CHECK passed")
	quit(0)


func _verify_offset_backpack_aim() -> void:
	var agent := AiMechAgent.new()
	agent.player_controlled = true
	agent.upper_body = Node2D.new()
	agent.add_child(agent.upper_body)
	agent.head_aim_node = Node2D.new()
	agent.upper_body.add_child(agent.head_aim_node)
	var runtime := _runtime(&"Backpack", 0.0, 14.0)
	runtime.muzzles[0].position = Vector2(10.0, -3.0)
	agent.upper_body.add_child(runtime.muzzles[0])
	agent.weapons.append(runtime)

	agent.manual_aim_position = Vector2(0.0, -20.0)
	agent._aim_at_opponent(0.0)
	assert(agent.weapon_aim_valid == [true])
	agent.manual_aim_position = Vector2(10.0, -20.0)
	agent._aim_at_opponent(0.0)
	assert(agent.weapon_aim_valid == [false])

	runtime.visual.free()
	agent.free()


func _verify_all_weapons_continues_after_preparation() -> void:
	var agent := LinkedFireAgent.new()
	var prepared := _runtime(&"LeftArm", 2.0)
	var immediate := _runtime(&"RightArm", 0.0)
	agent.player_controlled = true
	agent.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_ALL
	agent.weapons.assign([prepared, immediate])
	agent.weapon_aim_valid.assign([true, true])

	agent._try_fire_linked_group()
	assert(agent.preparing_weapon_index == 0)
	assert(agent.preparation_started_count == 1)
	assert(agent.fired_parts == [&"RightArm"])
	assert(agent.next_weapon_index == 0)

	_free_linked_agent(agent)


func _verify_single_selection_still_waits() -> void:
	var agent := LinkedFireAgent.new()
	var prepared := _runtime(&"LeftArm", 2.0)
	var immediate := _runtime(&"RightArm", 0.0)
	agent.player_controlled = true
	agent.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_LEFT
	agent.weapons.assign([prepared, immediate])
	agent.weapon_aim_valid.assign([true, true])

	agent._try_fire_linked_group()
	assert(agent.preparing_weapon_index == 0)
	assert(agent.fired_parts.is_empty())

	_free_linked_agent(agent)


func _verify_second_preparation_does_not_replace_first() -> void:
	var agent := LinkedFireAgent.new()
	var first := _runtime(&"LeftArm", 2.0)
	var second := _runtime(&"RightArm", 3.0)
	var immediate := _runtime(&"Backpack", 0.0)
	agent.player_controlled = true
	agent.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_ALL
	agent.weapons.assign([first, second, immediate])
	agent.weapon_aim_valid.assign([true, true, true])

	agent._try_fire_linked_group()
	assert(agent.preparing_weapon_index == 0)
	assert(agent.preparation_started_count == 1)
	assert(agent.fired_parts == [&"Backpack"])

	_free_linked_agent(agent)


func _runtime(
	part_name: StringName,
	preparation_time: float,
	traverse_limit_degrees := 30.0
) -> WeaponRuntime:
	var spec := WeaponSpec.new()
	spec.preparation_time = preparation_time
	spec.traverse_limit_degrees = traverse_limit_degrees
	var runtime := WeaponRuntime.new()
	runtime.setup(spec, Sprite2D.new(), [Marker2D.new()], part_name, 1.0)
	return runtime


func _free_linked_agent(agent: LinkedFireAgent) -> void:
	for weapon in agent.weapons:
		weapon.visual.free()
		for muzzle in weapon.muzzles:
			muzzle.free()
	agent.free()
