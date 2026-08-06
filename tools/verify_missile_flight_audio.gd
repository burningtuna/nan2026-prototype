extends SceneTree


class TestMissile extends BallisticProjectile:
	func _ready() -> void:
		pass

	func _physics_process(_delta: float) -> void:
		pass


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var camera := Camera2D.new()
	root.add_child(camera)
	camera.enabled = true
	camera.global_position = Vector2.ZERO

	var manager := MissileFlightAudioManager.new()
	root.add_child(manager)
	assert(manager.flight_players.size() == MissileFlightAudioManager.MAX_FLIGHT_CHANNELS)

	var missiles: Array[TestMissile] = []
	for distance in [500.0, 100.0, 300.0, 200.0, 400.0]:
		var missile := TestMissile.new()
		missile.weapon_family = WeaponSpec.WeaponFamily.MISSILE
		manager.add_child(missile)
		missile.global_position = Vector2(distance, 0.0)
		missiles.append(missile)
	var ballistic := TestMissile.new()
	ballistic.weapon_family = WeaponSpec.WeaponFamily.BALLISTIC
	manager.add_child(ballistic)
	ballistic.global_position = Vector2(1.0, 0.0)

	manager._process(0.0)
	assert(manager.active_flight_channel_count() == 3)
	var selected := manager.selected_missile_ids()
	assert(selected.has(missiles[1].get_instance_id()))
	assert(selected.has(missiles[2].get_instance_id()))
	assert(selected.has(missiles[3].get_instance_id()))
	assert(not selected.has(ballistic.get_instance_id()))
	for index in manager.flight_targets.size():
		if is_instance_valid(manager.flight_targets[index]):
			assert(manager.flight_players[index].playing)

	camera.global_position = Vector2(500.0, 0.0)
	manager._process(0.0)
	selected = manager.selected_missile_ids()
	assert(selected.has(missiles[0].get_instance_id()))
	assert(selected.has(missiles[2].get_instance_id()))
	assert(selected.has(missiles[4].get_instance_id()))
	assert(manager.active_flight_channel_count() == 3)
	var removed_id := missiles[0].get_instance_id()
	missiles[0].free()
	manager._process(0.0)
	assert(not manager.selected_missile_ids().has(removed_id))
	assert(manager.active_flight_channel_count() == 3)

	manager.free()
	camera.free()
	print("MISSILE_FLIGHT_AUDIO_CHECK passed")
	quit(0)
