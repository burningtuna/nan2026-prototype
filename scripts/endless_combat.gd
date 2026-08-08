extends "res://scripts/combat_hud_test.gd"

const ENDLESS_SCENE_PATH := "res://scenes/endless_combat.tscn"

@onready var director: EndlessDirector = $EndlessDirector
@onready var endless_hud: EndlessHud = \
	$CombatContainer/CombatViewport/OverlayLayer/EndlessHud


func _process(delta: float) -> void:
	super(delta)
	if director != null:
		_update_endless_player_damage(director.elapsed_seconds)
		endless_hud.set_time(director.elapsed_seconds, director.tier)


func _on_combat_bound() -> void:
	var smoke := OS.get_cmdline_user_args().has("--endless-smoke")
	_apply_endless_player_balance()
	if not director.setup(battle, combat_player, not smoke):
		push_error("Unable to initialize Endless Mode")
		return
	director.score_changed.connect(endless_hud.set_score)
	director.tier_changed.connect(_on_tier_changed)
	director.mech_wave_started.connect(_on_mech_wave_started)
	director.run_finished.connect(_on_run_finished)
	combat_player.parts_repaired.connect(_on_field_repair)
	endless_hud.retry_requested.connect(_retry)
	endless_hud.hangar_requested.connect(_return_to_endless_hangar)
	SceneTransition.transition_failed.connect(_on_endless_transition_failed)
	endless_hud.set_score(director.score, director.high_score)
	if smoke:
		call_deferred("_run_endless_smoke")
	if OS.get_cmdline_user_args().has("--endless-entry-smoke"):
		call_deferred("_run_endless_entry_smoke")


func _apply_endless_player_balance() -> void:
	if not GameSession.endless_player_balance_enabled:
		return
	_update_endless_player_damage(0.0)
	combat_player.ignore_weapon_preparation = true
	combat_player.ignore_preparation_move_speed_penalty = true
	combat_player.endless_non_missile_penetration_enabled = true
	combat_player.missile_damage_multiplier = GameSession.endless_missile_damage_multiplier
	combat_player.missile_splash_radius_multiplier = (
		GameSession.endless_missile_splash_radius_multiplier
	)
	for weapon in combat_player.weapons:
		weapon.reload_duration_multiplier = (
			GameSession.endless_missile_reload_multiplier
			if weapon.spec.weapon_family == WeaponSpec.WeaponFamily.MISSILE
			else GameSession.endless_other_reload_multiplier
		)


func _update_endless_player_damage(elapsed_seconds: float) -> void:
	if not GameSession.endless_player_balance_enabled or not is_instance_valid(combat_player):
		return
	var completed_minutes := floori(maxf(elapsed_seconds, 0.0) / 60.0)
	combat_player.incoming_damage_multiplier = (
		GameSession.endless_player_damage_multiplier
		+ completed_minutes * GameSession.endless_damage_growth_per_minute
	)


func _on_tier_changed(next_tier: int, elapsed: float) -> void:
	_update_endless_player_damage(elapsed)
	system_messages.push_message("THREAT TIER %02d" % (next_tier + 1))


func _on_mech_wave_started(count: int) -> void:
	system_messages.push_message("MECH WAVE INBOUND // %d" % count)


func _on_field_repair() -> void:
	system_messages.push_message("FIELD REPAIR // ACTIVE PARTS +20%")


func _on_run_finished(score: int, high_score: int) -> void:
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	endless_hud.show_game_over(score, high_score)


func _retry() -> void:
	battle.process_mode = Node.PROCESS_MODE_INHERIT
	var error := SceneTransition.transition_to(ENDLESS_SCENE_PATH)
	if error != OK:
		_on_endless_transition_failed(ENDLESS_SCENE_PATH, error)


func _return_to_endless_hangar() -> void:
	battle.process_mode = Node.PROCESS_MODE_INHERIT
	GameSession.selected_game_mode = GameSession.GameMode.ENDLESS
	var error := SceneTransition.transition_to(HANGAR_SCENE_PATH)
	if error != OK:
		_on_endless_transition_failed(HANGAR_SCENE_PATH, error)


func _on_endless_transition_failed(scene_path: String, error: Error) -> void:
	if scene_path not in [ENDLESS_SCENE_PATH, HANGAR_SCENE_PATH]:
		return
	battle.process_mode = Node.PROCESS_MODE_DISABLED
	system_messages.push_message("TRANSFER FAILED // %s" % error_string(error))


func _run_endless_smoke() -> void:
	assert(battle.agents.size() == 1)
	assert(not battle.automatic_battle_completion)
	assert(is_equal_approx(
		combat_player.incoming_damage_multiplier,
		GameSession.endless_player_damage_multiplier
	))
	assert(combat_player.ignore_weapon_preparation)
	assert(combat_player.ignore_preparation_move_speed_penalty)
	assert(combat_player.endless_non_missile_penetration_enabled)
	assert(is_equal_approx(
		combat_player.missile_damage_multiplier,
		GameSession.endless_missile_damage_multiplier
	))
	assert(is_equal_approx(
		combat_player.missile_splash_radius_multiplier,
		GameSession.endless_missile_splash_radius_multiplier
	))
	for weapon in combat_player.weapons:
		var expected_reload_multiplier := (
			GameSession.endless_missile_reload_multiplier
			if weapon.spec.weapon_family == WeaponSpec.WeaponFamily.MISSILE
			else GameSession.endless_other_reload_multiplier
		)
		assert(is_equal_approx(weapon.reload_duration_multiplier, expected_reload_multiplier))
		assert(is_zero_approx(combat_player.effective_weapon_preparation_time(weapon)))
	director.spawn_remaining = 999.0
	var head_drone := director.spawn_drone(DroneAgent.DroneKind.HEAD)
	assert(head_drone != null and head_drone.unit_class == AiMechAgent.UnitClass.DRONE)
	assert(head_drone.has_meta(AlienInfestationOverlay.META_KEY))
	assert(is_equal_approx(
		float(head_drone.part_max_durability[&"Head"]),
		head_drone.drone_part.armor * 0.1
	))
	assert(not head_drone.appears_in_enemy_roster())
	head_drone.register_hit(&"Head", Vector2.RIGHT, 100000.0)
	assert(director.score == 10)
	var leg_drone := director.spawn_drone(DroneAgent.DroneKind.LEGS)
	assert(leg_drone.drone_speed > head_drone.drone_speed)
	leg_drone.register_hit(&"Legs", Vector2.RIGHT, 100000.0)
	var arm_drone := director.spawn_drone(DroneAgent.DroneKind.ARM)
	assert(arm_drone.weapon_runtime != null)
	arm_drone.register_hit(&"LeftArm", Vector2.RIGHT, 100000.0)
	assert(director.score == 60)
	await get_tree().create_timer(0.1).timeout
	for agent in battle.agents:
		assert(agent.unit_class != AiMechAgent.UnitClass.DRONE or not agent.is_defeated())

	var repair_part: StringName = &"Body"
	var maximum := float(combat_player.part_max_durability[repair_part])
	var durability_before_hit := float(combat_player.part_durability[repair_part])
	combat_player.register_hit(repair_part, Vector2.RIGHT, 10.0)
	assert(is_equal_approx(
		float(combat_player.part_durability[repair_part]),
		durability_before_hit - 10.0 * GameSession.endless_player_damage_multiplier
	))
	combat_player.part_durability[repair_part] = maximum * 0.4
	var destroyed_part: StringName = &"Head"
	combat_player.part_durability[destroyed_part] = 0.0
	combat_player.register_hit(
		&"LeftArm",
		Vector2.RIGHT,
		100000.0
	)
	assert(combat_player._part_weapon_is_disabled(&"LeftArm"))
	director.elapsed_seconds = 59.9
	_update_endless_player_damage(director.elapsed_seconds)
	assert(is_equal_approx(
		combat_player.incoming_damage_multiplier,
		GameSession.endless_player_damage_multiplier
	))
	director.next_mech_time = 60.0
	director._process(0.2)
	assert(is_equal_approx(
		combat_player.incoming_damage_multiplier,
		GameSession.endless_player_damage_multiplier
		+ GameSession.endless_damage_growth_per_minute
	))
	_update_endless_player_damage(8.0 * 60.0)
	assert(is_equal_approx(combat_player.incoming_damage_multiplier, 1.0))
	_update_endless_player_damage(9.0 * 60.0)
	assert(is_equal_approx(combat_player.incoming_damage_multiplier, 1.1))
	assert(director._living_mechs() == 1)
	var mech: AiMechAgent
	for agent in battle.agents:
		if agent.unit_class == AiMechAgent.UnitClass.BOSS and not agent.is_defeated():
			mech = agent
			break
	assert(mech != null and mech.appears_in_enemy_roster())
	assert(mech.has_meta(AlienInfestationOverlay.META_KEY))
	assert(is_equal_approx(mech.incoming_damage_multiplier, 1.0))
	assert(not mech.ignore_weapon_preparation)
	assert(not mech.ignore_preparation_move_speed_penalty)
	assert(not mech.endless_non_missile_penetration_enabled)
	assert(is_equal_approx(mech.missile_damage_multiplier, 1.0))
	assert(is_equal_approx(mech.missile_splash_radius_multiplier, 1.0))
	for weapon in mech.weapons:
		assert(is_equal_approx(weapon.reload_duration_multiplier, 1.0))
	mech.register_hit(&"Body", Vector2.RIGHT, float(mech.part_durability[&"Body"]))
	assert(director.score == 310)
	assert(is_equal_approx(combat_player.part_durability[repair_part], maximum * 0.6))
	assert(is_zero_approx(float(combat_player.part_durability[destroyed_part])))
	assert(is_zero_approx(float(combat_player.part_durability[&"LeftArm"])))

	combat_player.register_hit(
		&"Body",
		Vector2.RIGHT,
		100000.0
	)
	await get_tree().process_frame
	assert(not director.running)
	assert(endless_hud.result_panel.visible)
	print("ENDLESS_MODE_CHECK passed")
	get_tree().quit(0)


func _run_endless_entry_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.ENDLESS)
	assert(battle.solo_player and battle.agents.size() == 1)
	print("ENDLESS_ENTRY_CHECK passed")
	get_tree().quit(0)
