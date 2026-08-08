extends SceneTree


func _initialize() -> void:
	var weapon_catalog := WeaponCatalog.new()
	assert(weapon_catalog.load_file("res://data/weapons.json"))
	var part_catalog := MechPartCatalog.new()
	assert(part_catalog.load_file("res://data/mech_parts.json", weapon_catalog))

	var falcon := part_catalog.parts_by_id["falcon_sensor"] as MechPartSpec
	var raven := part_catalog.parts_by_id["raven_sensor"] as MechPartSpec
	var bastion := part_catalog.parts_by_id["bastion_array"] as MechPartSpec
	var missile_radar := part_catalog.parts_by_id["field_missile_radar_backpack"] as MechPartSpec
	assert(is_equal_approx(falcon.sensor_period, 0.5))
	assert(falcon.enemy_track_limit == 2 and falcon.projectile_track_limit == 4)
	assert(is_equal_approx(raven.sensor_period, 0.25))
	assert(raven.enemy_track_limit == 4 and raven.projectile_track_limit == 8)
	assert(is_equal_approx(bastion.sensor_period, 0.125))
	assert(bastion.enemy_track_limit == 8 and bastion.projectile_track_limit == 16)
	assert(missile_radar != null and missile_radar.designation == "BP-15")
	assert(is_equal_approx(missile_radar.sensor_range, 20000.0))
	assert(is_zero_approx(missile_radar.sensor_period))
	assert(missile_radar.enemy_track_limit == 8 and missile_radar.projectile_track_limit == 32)
	assert(is_equal_approx(missile_radar.missile_speed_multiplier, 2.0))
	assert(is_zero_approx(missile_radar.missile_preparation_time_override))
	assert(is_equal_approx(missile_radar.missile_reload_duration_override, 5.0))
	assert(is_equal_approx(missile_radar.missile_seeker_angle_degrees, 30.0))
	assert(is_equal_approx(missile_radar.missile_turn_speed_override_degrees, 180.0))
	assert(is_equal_approx(missile_radar.missile_max_spread_degrees, 30.0))
	assert(is_equal_approx(missile_radar.missile_proximity_fuse_radius_multiplier, 3.0))
	assert(is_equal_approx(missile_radar.missile_damage_multiplier, 1.5))
	assert(missile_radar.missile_ignores_evasion)
	assert(is_equal_approx(weapon_catalog.weapon("weapon_missile_rapid").projectile.damage, 0.9))
	assert(is_equal_approx(weapon_catalog.weapon("weapon_missile_standard").projectile.damage, 3.75))
	assert(is_equal_approx(weapon_catalog.weapon("weapon_missile_heavy").projectile.damage, 7.5))
	assert(is_equal_approx(weapon_catalog.weapon("weapon_missile_sniper_backpack").projectile.damage, 200.0))
	_verify_head_profiles(falcon, raven, bastion, weapon_catalog)

	var projectile_layer := Node2D.new()
	var observer_loadout := part_catalog.create_default_loadout()
	observer_loadout.head = raven
	var target_loadout := part_catalog.create_default_loadout()
	var observer := _make_agent("Observer", projectile_layer, observer_loadout)
	observer.player_controlled = true
	var target := _make_agent("Target", projectile_layer, target_loadout)
	observer.position = Vector2.ZERO
	target.position = Vector2(2300.0, 0.0)
	observer.set_opponent(target)
	observer.sensor_scan_count = 0
	observer.sensor_time_remaining = 0.0
	assert(observer._update_sensor(0.0))
	assert(observer.sensor_scan_count == 1)
	assert(observer.selected_sensor_target == target)
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
	observer._update_player_target_selection()
	assert(observer.selected_sensor_target == null)
	observer.mech_loadout.head = bastion
	observer._scan_sensor()
	assert(observer.can_detect_unit(target))
	assert(observer.selected_sensor_target == target)

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
	_verify_freed_unit_target_selection()
	_verify_sensor_guided_missile()
	_verify_target_cycle()
	_verify_selected_target_persistence(part_catalog, projectile_layer)
	_verify_missile_radar_sensor(part_catalog, projectile_layer)
	_verify_missile_radar_guidance(part_catalog, projectile_layer)
	await _verify_charged_arm_and_dash_visuals(part_catalog)
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
	projectile.update_homing_observation(Vector2(0.0, 100.0), Vector2.ZERO, true)
	assert(not projectile.homing_observation_enabled)
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


func _verify_freed_unit_target_selection() -> void:
	var observer := AiMechAgent.new()
	var target := AiMechAgent.new()
	observer.sensor_snapshot.units.append({
		"target": target,
		"position": Vector2.ZERO,
	})
	target.free()
	observer._select_nearest_sensor_target()
	assert(observer.selected_sensor_target == null)
	observer.free()


func _verify_target_cycle() -> void:
	var player := AiMechAgent.new()
	var stale := AiMechAgent.new()
	var first := AiMechAgent.new()
	var second := AiMechAgent.new()
	player.sensor_snapshot.units.assign([
		{"target": stale},
		{"target": first},
		{"target": second},
	])
	stale.free()
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


func _verify_selected_target_persistence(
	part_catalog: MechPartCatalog,
	projectile_layer: Node2D
) -> void:
	var observer_loadout := part_catalog.create_default_loadout()
	observer_loadout.head = part_catalog.parts_by_id["falcon_sensor"]
	var target_loadout := part_catalog.create_default_loadout()
	var observer := _make_agent("LockObserver", projectile_layer, observer_loadout)
	observer.player_controlled = true
	observer.position = Vector2.ZERO
	var nearest := _make_agent("Nearest", projectile_layer, target_loadout)
	var middle := _make_agent("Middle", projectile_layer, target_loadout)
	var selected := _make_agent("Selected", projectile_layer, target_loadout)
	nearest.position = Vector2(100.0, 0.0)
	middle.position = Vector2(200.0, 0.0)
	selected.position = Vector2(300.0, 0.0)
	observer.set_opponents([nearest, middle, selected])
	observer._scan_sensor()
	assert(observer.tracked_enemy_count() == 2)
	observer.selected_sensor_target = selected
	observer._scan_sensor()
	assert(observer.tracked_enemy_count() == 2)
	assert(observer.sensor_snapshot.has_unit(selected))
	assert(observer.selected_sensor_target == selected)
	middle.position = Vector2(50.0, 0.0)
	observer._scan_sensor()
	assert(observer.sensor_snapshot.has_unit(selected))
	assert(observer.selected_sensor_target == selected)
	selected.part_durability[&"Body"] = 0.0
	observer._update_player_target_selection()
	assert(observer.selected_sensor_target == middle)
	selected.position = Vector2(observer.sensor_range() + 1.0, 0.0)
	observer._scan_sensor()
	assert(observer.selected_sensor_target != selected)
	observer.free()
	nearest.free()
	middle.free()
	selected.free()


func _verify_missile_radar_sensor(
	part_catalog: MechPartCatalog,
	projectile_layer: Node2D
) -> void:
	var loadout := part_catalog.create_default_loadout()
	loadout.backpack = part_catalog.parts_by_id["field_missile_radar_backpack"]
	var observer := _make_agent("RadarObserver", projectile_layer, loadout)
	observer.player_controlled = true
	assert(is_equal_approx(observer.sensor_range(), 20000.0))
	assert(is_zero_approx(observer.sensor_period()))
	assert(observer.enemy_track_limit() == 8)
	assert(observer.projectile_track_limit() == 32)
	observer.sensor_scan_count = 0
	assert(observer._update_sensor(0.0))
	assert(observer.sensor_scan_count == 1)
	assert(observer._update_sensor(0.0))
	assert(observer.sensor_scan_count == 2)
	observer.part_durability[&"Backpack"] = 0.0
	assert(is_equal_approx(observer.sensor_range(), loadout.head.sensor_range))
	observer.part_durability[&"Head"] = 0.0
	assert(is_zero_approx(observer.sensor_range()))
	observer.free()


func _verify_missile_radar_guidance(
	part_catalog: MechPartCatalog,
	projectile_layer: Node2D
) -> void:
	var loadout := part_catalog.create_default_loadout()
	loadout.backpack = part_catalog.parts_by_id["field_missile_radar_backpack"]
	var observer := _make_agent("GuidanceObserver", projectile_layer, loadout)
	observer.combat_visuals_enabled = false
	var missile_part := part_catalog.parts_by_id["tempest_guided_arm"] as MechPartSpec
	var missile_runtime := _weapon_runtime(missile_part.weapon, &"RightArm")
	assert(is_zero_approx(observer.effective_weapon_preparation_time(missile_runtime)))
	observer._update_missile_reload_override(missile_runtime)
	assert(is_equal_approx(missile_runtime.reload_duration(), 5.0))
	assert(is_equal_approx(observer.effective_weapon_volley_arc_degrees(missile_runtime), 30.0))
	var near_target := _make_agent("NearTarget", projectile_layer, part_catalog.create_default_loadout())
	var far_target := _make_agent("FarTarget", projectile_layer, part_catalog.create_default_loadout())
	var side_target := _make_agent("SideTarget", projectile_layer, part_catalog.create_default_loadout())
	near_target.position = Vector2(100.0, 10.0)
	far_target.position = Vector2(250.0, 0.0)
	side_target.position = Vector2(0.0, 1000.0)
	observer.set_opponents([side_target, far_target, near_target])
	observer.sensor_snapshot.units.assign([
		{"target": far_target, "position": far_target.position, "velocity": Vector2.ZERO, "dashing": false},
		{"target": near_target, "position": near_target.position, "velocity": Vector2.ZERO, "dashing": false},
	])
	observer.missile_damage_multiplier = 2.0
	observer.missile_splash_radius_multiplier = 2.0
	observer._spawn_projectile(
		missile_runtime,
		Vector2.ZERO,
		Vector2.RIGHT,
		0,
		0.0,
		near_target
	)
	var spawned := projectile_layer.get_child(projectile_layer.get_child_count() - 1) as BallisticProjectile
	assert(spawned != null)
	assert(is_equal_approx(spawned.damage_multiplier, 3.0))
	assert(is_equal_approx(
		spawned.effective_damage(),
		missile_runtime.spec.projectile.damage * 3.0
	))
	assert(spawned.ignores_homing_evasion)
	assert(is_equal_approx(spawned.splash_radius_multiplier, 2.0))
	assert(is_equal_approx(
		spawned.effective_splash_radius(),
		missile_runtime.spec.projectile.splash_radius * 2.0
	))
	spawned.free()
	var projectile_spec := ProjectileSpec.new()
	projectile_spec.speed = 100.0
	projectile_spec.homing = true
	projectile_spec.homing_turn_speed_degrees = 30.0
	projectile_spec.proximity_fuse_radius = 10.0
	var projectile := BallisticProjectile.new()
	projectile.configure(
		projectile_spec,
		Vector2.RIGHT,
		1000.0,
		observer,
		&"RightArm",
		1,
		0.0,
		WeaponSpec.WeaponFamily.MISSILE,
		null,
		Vector2.ZERO,
		Vector2.ZERO,
		false,
		false,
		false,
		false,
		2.0,
		30.0,
		180.0,
		3.0,
		1.5,
		true
	)
	assert(is_equal_approx(projectile.effective_speed(), 200.0))
	assert(is_equal_approx(projectile.effective_damage(), projectile_spec.damage * 1.5))
	assert(is_equal_approx(
		projectile.effective_proximity_fuse_radius(),
		30.0
	))
	assert(projectile.homing_target == null)
	projectile._update_homing_direction(0.25)
	assert(projectile.direction.is_equal_approx(Vector2.RIGHT))
	projectile_layer.add_child(projectile)
	observer._update_owned_missile_observations()
	assert(projectile.homing_target == near_target)
	assert(projectile.terminal_seeker_activated)
	assert(is_equal_approx(projectile.terminal_seeker_angle_degrees, 30.0))
	assert(is_equal_approx(projectile.homing_turn_speed_override_degrees, 180.0))
	projectile._update_homing_direction(0.25)
	assert(projectile.direction.angle() > 0.0)
	assert(projectile.direction.angle() <= deg_to_rad(45.0) + 0.001)
	projectile.update_homing_observation(Vector2(0.0, 100.0), Vector2.ZERO, true)
	assert(projectile.homing_observation_enabled)
	var distant_projectile := BallisticProjectile.new()
	distant_projectile.configure(
		projectile_spec,
		Vector2.RIGHT,
		1000.0,
		observer,
		&"RightArm",
		2,
		0.0,
		WeaponSpec.WeaponFamily.MISSILE,
		null,
		Vector2.ZERO,
		Vector2.ZERO,
		false,
		false,
		false,
		false,
		2.0,
		30.0,
		180.0
	)
	projectile_layer.add_child(distant_projectile)
	distant_projectile.global_position = Vector2(-1000.0, 0.0)
	observer._update_owned_missile_observations()
	assert(distant_projectile.homing_target == near_target)
	projectile.queue_free()
	distant_projectile.queue_free()
	_free_weapon_runtime(missile_runtime)
	observer.free()
	near_target.free()
	far_target.free()
	side_target.free()


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


func _verify_charged_arm_and_dash_visuals(part_catalog: MechPartCatalog) -> void:
	var projectile_layer := Node2D.new()
	get_root().add_child(projectile_layer)
	var loadout := part_catalog.create_default_loadout()
	loadout.left_arm = part_catalog.parts_by_id["nova_beam_cannon_arm"]
	loadout.right_arm = null
	var agent := _make_agent("ChargedAim", projectile_layer, loadout)
	agent.player_controlled = true
	get_root().add_child(agent)
	await process_frame
	agent.manual_aim_position = Vector2(1000.0, 0.0)
	agent._aim_at_opponent(10.0)
	assert(not agent.weapon_aim_valid[0])
	agent.preparing_weapon_index = 0
	agent.preparation_time_remaining = agent.effective_weapon_preparation_time(agent.weapons[0])
	agent._aim_at_opponent(10.0)
	assert(agent.weapon_aim_valid[0])
	assert(absf(angle_difference(
		agent.arm_aim_nodes[0].rotation,
		agent.manual_aim_position.angle()
	)) <= deg_to_rad(AiMechAgent.PREPARED_ARM_AIM_TOLERANCE_DEGREES))
	var shots_before := agent.shot_count
	agent._finish_preparation()
	assert(agent.shot_count == shots_before + 1)
	assert(not agent.boost_sprites.is_empty())
	agent.dash_direction = Vector2.RIGHT
	agent.dash_time_remaining = 0.5
	agent.velocity = Vector2.RIGHT * 100.0
	agent._update_boost_effect()
	for boost in agent.boost_sprites:
		assert(boost.animation == &"dash" and boost.visible)
		assert(boost.sprite_frames.get_frame_texture(&"dash", 0).resource_path == AiMechAgent.DASH_FRAMES[0])
		assert(is_equal_approx(boost.global_rotation, PI * 0.5))
		assert(boost.self_modulate == Color.WHITE)
	agent.dash_time_remaining = 0.0
	agent._update_boost_effect()
	for boost in agent.boost_sprites:
		assert(boost.animation == &"burn")
		assert(is_zero_approx(boost.rotation))
	agent.free()
	projectile_layer.free()
