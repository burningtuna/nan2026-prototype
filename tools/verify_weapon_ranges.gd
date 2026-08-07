extends SceneTree


func _initialize() -> void:
	var catalog := WeaponCatalog.new()
	assert(catalog.load_file("res://data/weapons.json"))
	var cyclone := catalog.weapon("weapon_scatter_rapid")
	assert(cyclone != null and is_equal_approx(cyclone.fire_rate, 2.0))
	assert(is_equal_approx(cyclone.projectile.damage, 5.0))
	assert(is_equal_approx(cyclone.heat_cost, 24.0))
	assert(is_zero_approx(cyclone.preparation_time))
	assert(is_equal_approx(cyclone.preparation_move_speed_multiplier, 1.0))
	assert(is_equal_approx(cyclone.preparation_turn_speed_multiplier, 1.0))
	var agent := AiMechAgent.new()
	var nova_checked := false
	for weapon_value in catalog.weapons_by_id.values():
		var spec := weapon_value as WeaponSpec
		assert(spec.projectile != null)
		assert(spec.projectile.speed > 0.0)
		assert(spec.effective_range > 0.0)
		assert(spec.max_range >= spec.effective_range)

		var visual := Sprite2D.new()
		var muzzle := Marker2D.new()
		muzzle.position = Vector2(37.0, -11.0)
		var runtime := WeaponRuntime.new()
		runtime.setup(spec, visual, [muzzle], &"LeftArm", 1.0)
		agent.weapons.assign([runtime])
		agent.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_LEFT
		agent.weapon_range_multiplier = 1.0
		assert(is_equal_approx(agent.weapon_effective_range(runtime), spec.effective_range))
		assert(is_equal_approx(agent.weapon_maximum_range(runtime), spec.max_range))
		assert(is_equal_approx(agent.selected_weapon_maximum_range(), spec.max_range))

		agent.weapon_range_multiplier = 0.5
		var runtime_range := spec.max_range * 0.5
		assert(is_equal_approx(agent.weapon_maximum_range(runtime), runtime_range))
		var projectile := spec.projectile.projectile_scene.instantiate() as BallisticProjectile
		projectile.configure(
			spec.projectile,
			Vector2.RIGHT,
			agent.weapon_maximum_range(runtime),
			agent,
			&"LeftArm",
			1,
			0.0,
			spec.weapon_family,
			null
		)
		assert(is_equal_approx(projectile.max_distance, runtime_range))
		projectile.free()
		visual.free()
		muzzle.free()

		if spec.display_name == "Nova Beam Cannon":
			nova_checked = true
			agent.weapon_range_multiplier = 1.0
			assert(is_equal_approx(agent.weapon_maximum_range(runtime), 3500.0))
	assert(nova_checked)
	agent.weapons.clear()
	agent.free()
	print("WEAPON_RANGE_CHECK passed")
	quit(0)
