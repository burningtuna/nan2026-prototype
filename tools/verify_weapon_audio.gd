extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var combat_scene := load("res://scenes/combat_hud_test.tscn") as PackedScene
	assert(combat_scene != null)
	var combat := combat_scene.instantiate()
	var combat_viewport := combat.get_node("CombatContainer/CombatViewport") as SubViewport
	assert(combat_viewport != null and combat_viewport.audio_listener_enable_2d)
	combat.free()

	var catalog := WeaponCatalog.new()
	assert(catalog.load_file("res://data/weapons.json"))
	var spec := catalog.weapon("weapon_ballistic_standard")
	assert(spec != null and spec.fire_sound != null)
	assert(spec.fire_sound.resource_path == "res://Sounds/weapons/ballistic_standard.ogg")
	for weapon_value in catalog.weapons_by_id.values():
		var weapon := weapon_value as WeaponSpec
		if weapon.weapon_family == WeaponSpec.WeaponFamily.MISSILE:
			assert(weapon.fire_sound != null)
			assert(
				weapon.fire_sound.resource_path
				== "res://Sounds/weapons/fire_sound_effect.mp3"
			)
	var test_stream := AudioStreamWAV.new()
	test_stream.format = AudioStreamWAV.FORMAT_8_BITS
	test_stream.mix_rate = 8000
	var sample_data := PackedByteArray()
	sample_data.resize(8000)
	test_stream.data = sample_data
	spec.fire_sound = test_stream

	var viewport := SubViewport.new()
	viewport.audio_listener_enable_2d = true
	root.add_child(viewport)
	var visual := Sprite2D.new()
	viewport.add_child(visual)
	var muzzle := Marker2D.new()
	visual.add_child(muzzle)
	var runtime := WeaponRuntime.new()
	runtime.setup(spec, visual, [muzzle], &"LeftArm", 1.0)
	assert(runtime.fire_audio != null and runtime.fire_audio.stream == test_stream)
	assert(runtime.reload_audio != null)
	assert(runtime.reload_audio.get_parent() == visual)
	viewport.free()
	runtime = null
	spec = null
	catalog = null
	test_stream = null
	print("WEAPON_AUDIO_CHECK passed")
	quit(0)
