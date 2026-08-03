extends SceneTree


func _initialize() -> void:
	var weapon_catalog := WeaponCatalog.new()
	assert(weapon_catalog.load_file("res://data/weapons.json"))
	var part_catalog := MechPartCatalog.new()
	assert(part_catalog.load_file("res://data/mech_parts.json", weapon_catalog))

	var falcon := part_catalog.parts_by_id["falcon_sensor"] as MechPartSpec
	var raven := part_catalog.parts_by_id["raven_sensor"] as MechPartSpec
	var bastion := part_catalog.parts_by_id["bastion_array"] as MechPartSpec
	assert(is_equal_approx(falcon.sensor_period, 0.5))
	assert(falcon.enemy_track_limit == 2 and falcon.projectile_track_limit == 4)
	assert(is_equal_approx(raven.sensor_period, 0.25))
	assert(raven.enemy_track_limit == 4 and raven.projectile_track_limit == 8)
	assert(is_equal_approx(bastion.sensor_period, 0.125))
	assert(bastion.enemy_track_limit == 8 and bastion.projectile_track_limit == 16)
	_verify_head_profiles(falcon, raven, bastion, weapon_catalog)

	var projectile_layer := Node2D.new()
	var observer_loadout := part_catalog.create_default_loadout()
	observer_loadout.head = raven
	var target_loadout := part_catalog.create_default_loadout()
	var observer := _make_agent("Observer", projectile_layer, observer_loadout)
	var target := _make_agent("Target", projectile_layer, target_loadout)
	observer.position = Vector2.ZERO
	target.position = Vector2(2300.0, 0.0)
	observer.set_opponent(target)
	observer.sensor_scan_count = 0
	observer.sensor_time_remaining = 0.0
	assert(observer._update_sensor(0.0))
	assert(observer.sensor_scan_count == 1)
	assert(not observer._update_sensor(0.24))
	assert(observer._update_sensor(0.02))
	assert(observer.sensor_scan_count == 2)
	observer._scan_sensor()
	assert(observer.can_detect_unit(target))
	var observed_position := observer.observed_unit_position(target)
	target.position.x += 100.0
	assert(observer.observed_unit_position(target).is_equal_approx(observed_position))
	observer._scan_sensor()
	assert(observer.observed_unit_position(target).is_equal_approx(target.position))

	observer.mech_loadout.head = falcon
	observer._scan_sensor()
	assert(not observer.can_detect_unit(target))
	observer.mech_loadout.head = bastion
	observer._scan_sensor()
	assert(observer.can_detect_unit(target))

	var cannon_runtime := _weapon_runtime(weapon_catalog.weapon("test_cannon"), &"LeftArm")
	var missile_runtime := _weapon_runtime(weapon_catalog.weapon("weapon_missile_heavy"), &"Backpack")
	observer.weapons.assign([cannon_runtime, missile_runtime])
	observer.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_LEFT
	assert(is_equal_approx(observer.selected_weapon_maximum_range(), 500.0))
	observer.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_ALL
	assert(is_equal_approx(observer.selected_weapon_maximum_range(), 5000.0))
	_free_weapon_runtime(cannon_runtime)
	_free_weapon_runtime(missile_runtime)
	observer.weapons.clear()

	observer.part_durability[&"Head"] = 0.0
	observer._scan_sensor()
	assert(observer.tracked_enemy_count() == 0)

	assert(is_equal_approx(_decision_period(AiMechAgent.MovementType.AGGRESSIVE), 0.25))
	assert(is_equal_approx(_decision_period(AiMechAgent.MovementType.BALANCED), 0.5))
	assert(is_equal_approx(_decision_period(AiMechAgent.MovementType.DEFENSIVE), 1.0))
	_verify_freed_projectile_snapshot()
	_verify_sensor_guided_missile()
	_verify_target_cycle()
	_verify_backpack_muzzle_positions()
	assert(not target.is_defeated())
	target.combat_visuals_enabled = false
	target.register_hit(&"Body", Vector2.RIGHT, float(target.part_max_durability[&"Body"]))
	assert(target.is_part_destroyed(&"Body"))
	assert(target.is_defeated())

	observer.free()
	target.free()
	projectile_layer.free()
	print("SENSOR_BEHAVIOR_CHECK passed")
	quit(0)


func _make_agent(agent_name: String, projectile_layer: Node2D, loadout: MechLoadout) -> AiMechAgent:
	var agent := AiMechAgent.new()
	var weapons: Array[WeaponSpec] = []
	for part in [loadout.left_arm, loadout.right_arm, loadout.backpack]:
		if part != null and part.weapon != null:
			weapons.append(part.weapon)
	agent.setup(
		agent_name,
		projectile_layer,
		Rect2(-3000.0, -3000.0, 6000.0, 6000.0),
		1234,
		Color.WHITE,
		weapons,
		loadout
	)
	return agent


func _verify_head_profiles(
	falcon: MechPartSpec,
	raven: MechPartSpec,
	bastion: MechPartSpec,
	weapon_catalog: WeaponCatalog
) -> void:
	var falcon_texture := load(falcon.art_path) as Texture2D
	var raven_texture := load(raven.art_path) as Texture2D
	var bastion_texture := load(bastion.art_path) as Texture2D
	assert(falcon_texture.get_size() == Vector2(6.0, 6.0))
	assert(raven_texture.get_size() == Vector2(12.0, 12.0))
	assert(bastion_texture.get_size() == Vector2(24.0, 24.0))
	var falcon_hit_area := falcon_texture.get_image().get_used_rect().get_area()
	var raven_hit_area := raven_texture.get_image().get_used_rect().get_area()
	var bastion_hit_area := bastion_texture.get_image().get_used_rect().get_area()
	assert(falcon_hit_area < raven_hit_area and raven_hit_area < bastion_hit_area)
	assert((load(falcon.wireframe_art_path) as Texture2D).get_size() == Vector2(8.0, 7.0))
	assert((load(bastion.wireframe_art_path) as Texture2D).get_size() == Vector2(32.0, 14.0))
	var longest_weapon_range := 0.0
	for weapon_value in weapon_catalog.weapons_by_id.values():
		var weapon := weapon_value as WeaponSpec
		longest_weapon_range = maxf(longest_weapon_range, weapon.max_range)
	assert(is_equal_approx(bastion.sensor_range, longest_weapon_range))


func _decision_period(type: AiMechAgent.MovementType) -> float:
	var agent := AiMechAgent.new()
	agent.movement_type = type
	var result := agent.ai_decision_period()
	agent.free()
	return result


func _weapon_runtime(spec: WeaponSpec, part_name: StringName) -> WeaponRuntime:
	var muzzle := Marker2D.new()
	var muzzles: Array[Marker2D] = [muzzle]
	var runtime := WeaponRuntime.new()
	runtime.setup(spec, Sprite2D.new(), muzzles, part_name, 1.0)
	return runtime


func _free_weapon_runtime(runtime: WeaponRuntime) -> void:
	runtime.visual.free()
	for muzzle in runtime.muzzles:
		muzzle.free()


func _verify_sensor_guided_missile() -> void:
	var spec := ProjectileSpec.new()
	spec.homing = true
	spec.homing_turn_speed_degrees = 360.0
	spec.speed = 100.0
	var target := Node2D.new()
	target.position = Vector2(100.0, 100.0)
	var source := Node.new()
	var projectile := BallisticProjectile.new()
	projectile.configure(
		spec,
		Vector2.RIGHT,
		1000.0,
		source,
		&"Test",
		1,
		0.0,
		WeaponSpec.WeaponFamily.MISSILE,
		target,
		Vector2(100.0, 0.0),
		Vector2.ZERO,
		false,
		true
	)
	projectile.visuals_enabled = false
	projectile._update_homing_direction(0.1)
	assert(absf(projectile.direction.y) < 0.001)
	projectile.update_homing_observation(Vector2(0.0, 100.0), Vector2.ZERO, false)
	projectile._update_homing_direction(0.1)
	assert(projectile.direction.y > 0.0)
	projectile.free()
	target.free()
	source.free()


func _verify_freed_projectile_snapshot() -> void:
	var snapshot := SensorSnapshot.new()
	var projectile := BallisticProjectile.new()
	snapshot.projectiles.append({"projectile": projectile})
	projectile.free()
	assert(snapshot.tracked_projectiles().is_empty())


func _verify_target_cycle() -> void:
	var player := AiMechAgent.new()
	var first := AiMechAgent.new()
	var second := AiMechAgent.new()
	player.sensor_snapshot.units.assign([
		{"target": first},
		{"target": second},
	])
	player._cycle_sensor_target()
	assert(player.selected_sensor_target == first)
	player._cycle_sensor_target()
	assert(player.selected_sensor_target == second)
	player.sensor_snapshot.units.clear()
	player._cycle_sensor_target()
	assert(player.selected_sensor_target == null)
	player.free()
	first.free()
	second.free()


func _verify_backpack_muzzle_positions() -> void:
	var agent := AiMechAgent.new()
	var anchored := agent._backpack_muzzle_local_positions({
		"mount": Vector2(2.0, 3.0),
		"map": {"anchors": {&"muzzle": [Vector2(5.0, 7.0), Vector2(8.0, 9.0)]}},
	})
	assert(anchored == [Vector2(3.0, 4.0), Vector2(6.0, 6.0)])
	var fallback := agent._backpack_muzzle_local_positions({
		"mount": Vector2(2.0, 3.0),
		"map": {"anchors": {}},
	})
	assert(fallback == [Vector2(0.0, -6.0)])
	agent.free()
