extends SceneTree


func _initialize() -> void:
	var catalog := WeaponCatalog.new()
	assert(catalog.load_file("res://data/weapons.json"))
	_verify_reload(catalog.weapon("test_cannon"))
	_verify_reload(catalog.weapon("test_energy_cannon"))
	_verify_reload(catalog.weapon("weapon_ballistic_heavy"))
	_verify_reload(catalog.weapon("weapon_missile_rapid"))
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
	runtime.tick(spec.reload_duration + 0.01)
	assert(runtime.ammo == spec.magazine_capacity)
	assert(runtime.reload_completed_count == 1)
	runtime.visual.free()
	muzzle.free()
