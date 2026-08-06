extends SceneTree


func _initialize() -> void:
	var catalog := WeaponCatalog.new()
	assert(catalog.load_file("res://data/weapons.json"))
	_verify_reload(catalog.weapon("test_cannon"))
	_verify_reload(catalog.weapon("test_energy_cannon"))
	_verify_reload(catalog.weapon("weapon_ballistic_heavy"))
	_verify_reload(catalog.weapon("weapon_missile_rapid"))
	_verify_reload_multiplier(catalog.weapon("test_missile"), 0.2)
	_verify_reload_multiplier(catalog.weapon("test_cannon"), 0.0)
	_verify_forced_reload(catalog.weapon("test_cannon"))
	_verify_selected_forced_reload(catalog.weapon("test_cannon"))
	print("WEAPON_RELOAD_CHECK passed")
	quit(0)


func _verify_reload(spec: WeaponSpec) -> void:
	assert(spec != null and spec.reload_duration > 0.0)
	var muzzle := Marker2D.new()
	var muzzles: Array[Marker2D] = [muzzle]
	var runtime := WeaponRuntime.new()
	runtime.setup(spec, Sprite2D.new(), muzzles, &"TestArm", 1.0)
	for shot_index in spec.magazine_capacity:
		assert(runtime.fire() != null)
		if shot_index < spec.magazine_capacity - 1:
			runtime.tick(spec.fire_interval() + 0.01)
	assert(runtime.ammo == 0)
	assert(runtime.reload_remaining > 0.0)
	assert(runtime.reload_audio.stream == WeaponRuntime.RELOAD_START_STREAM)
	assert(runtime.reload_end_pending == (runtime.reload_duration() >= WeaponRuntime.LONG_RELOAD_SECONDS))
	runtime.tick(spec.reload_duration + 0.01)
	assert(runtime.ammo == spec.magazine_capacity)
	assert(runtime.reload_completed_count == 1)
	if spec.reload_duration >= WeaponRuntime.LONG_RELOAD_SECONDS:
		assert(runtime.reload_audio.stream == WeaponRuntime.RELOAD_END_STREAM)
	runtime.visual.free()
	muzzle.free()


func _verify_reload_multiplier(spec: WeaponSpec, multiplier: float) -> void:
	var muzzle := Marker2D.new()
	var runtime := WeaponRuntime.new()
	runtime.setup(spec, Sprite2D.new(), [muzzle], &"TestArm", 1.0)
	runtime.reload_duration_multiplier = multiplier
	for shot_index in spec.magazine_capacity:
		assert(runtime.fire() != null)
		if shot_index < spec.magazine_capacity - 1:
			runtime.tick(spec.fire_interval() + 0.01)
	if multiplier > 0.0:
		assert(is_equal_approx(runtime.reload_remaining, spec.reload_duration * multiplier))
	else:
		assert(is_zero_approx(runtime.reload_remaining))
		assert(runtime.ammo == spec.magazine_capacity)
	runtime.visual.free()
	muzzle.free()


func _verify_forced_reload(spec: WeaponSpec) -> void:
	var muzzle := Marker2D.new()
	var runtime := WeaponRuntime.new()
	runtime.setup(spec, Sprite2D.new(), [muzzle], &"LeftArm", 1.0)
	runtime.ammo -= 1
	assert(runtime.force_reload())
	assert(runtime.reload_remaining > 0.0)
	assert(runtime.reload_count == 1)
	assert(runtime.reload_audio.stream == WeaponRuntime.RELOAD_START_STREAM)
	assert(not runtime.force_reload())
	runtime.disabled = true
	runtime.tick(0.0)
	assert(is_zero_approx(runtime.reload_remaining))
	assert(not runtime.reload_end_pending)
	assert(runtime.ammo < spec.magazine_capacity)
	runtime.visual.free()
	muzzle.free()


func _verify_selected_forced_reload(spec: WeaponSpec) -> void:
	var left := _runtime_for_selection(spec, &"LeftArm")
	var right := _runtime_for_selection(spec, &"RightArm")
	left.ammo -= 1
	right.ammo -= 1
	var agent := AiMechAgent.new()
	agent.weapons.assign([left, right])
	agent.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_LEFT
	assert(agent.force_reload_selected_weapons() == 1)
	assert(left.is_reloading() and not right.is_reloading())
	agent.selected_weapon_mask = AiMechAgent.WEAPON_SELECT_ALL
	assert(agent.force_reload_selected_weapons() == 1)
	assert(right.is_reloading())
	agent.free()
	left.visual.free()
	right.visual.free()
	for muzzle in left.muzzles + right.muzzles:
		muzzle.free()


func _runtime_for_selection(spec: WeaponSpec, part_name: StringName) -> WeaponRuntime:
	var runtime := WeaponRuntime.new()
	runtime.setup(spec, Sprite2D.new(), [Marker2D.new()], part_name, 1.0)
	return runtime
