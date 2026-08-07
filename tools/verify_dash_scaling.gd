extends SceneTree

const PARTS_DATA_PATH := "res://data/mech_parts.json"
const WEAPONS_DATA_PATH := "res://data/weapons.json"


class BlockingConstraint extends Node:
	func resolve_agent_motion(
		previous: Vector2,
		_proposed: Vector2,
		_radius: float,
		_allow_wall_slide: bool
	) -> Vector2:
		return previous


class HalfPlaneWalkabilityMask extends StoryWalkabilityMask:
	func contains_agent_at(center_global: Vector2, _radius: float) -> bool:
		return center_global.x <= 0.001

	func _blocked_normal(_center: Vector2, _radius: float, _fallback: Vector2) -> Vector2:
		return Vector2.RIGHT


class AngledHalfPlaneWalkabilityMask extends StoryWalkabilityMask:
	const NORMAL := Vector2(0.70710678, 0.70710678)

	func contains_agent_at(center_global: Vector2, _radius: float) -> bool:
		return center_global.dot(NORMAL) <= 0.001

	func _blocked_normal(_center: Vector2, _radius: float, _fallback: Vector2) -> Vector2:
		return NORMAL


func _initialize() -> void:
	var weapon_catalog := WeaponCatalog.new()
	assert(weapon_catalog.load_file(WEAPONS_DATA_PATH))
	var part_catalog := MechPartCatalog.new()
	assert(part_catalog.load_file(PARTS_DATA_PATH, weapon_catalog))

	var fastest := _loadout(part_catalog, [
		"swift_core", "falcon_sensor", "courier_legs",
		"arc_repeater_arm", "arc_repeater_arm", "",
	])
	var slowest := _loadout(part_catalog, [
		"bulwark_core", "bastion_array", "anvil_legs",
		"longbow_cruise_arm", "longbow_cruise_arm", "nova_beam_backpack",
	])
	var lightest := _loadout(part_catalog, [
		"swift_core", "falcon_sensor", "courier_legs", "arc_repeater_arm", "", "",
	])
	var heaviest := _loadout(part_catalog, [
		"bulwark_core", "bastion_array", "anvil_legs",
		"avalanche_flak_arm", "avalanche_flak_arm", "avalanche_flak_backpack",
	])

	var agent := AiMechAgent.new()
	agent.mech_loadout = fastest
	assert(is_equal_approx(agent.effective_dash_speed(), agent.dash_speed))
	agent.mech_loadout = slowest
	assert(is_equal_approx(agent.effective_dash_speed(), agent.dash_speed / 3.0))
	agent.player_controlled = true
	assert(is_equal_approx(agent.player_mobility_turn_multiplier(), 1.0))
	assert(is_equal_approx(agent.effective_upper_turn_speed_degrees(), 67.5))
	assert(is_equal_approx(agent.effective_arm_turn_speed_degrees(), 45.0))
	agent.mech_loadout = fastest
	assert(is_equal_approx(agent.player_mobility_turn_multiplier(), 2.0))
	assert(is_equal_approx(agent.effective_upper_turn_speed_degrees(), 135.0))
	assert(is_equal_approx(agent.effective_arm_turn_speed_degrees(), 90.0))
	agent.player_controlled = false
	assert(is_equal_approx(agent.player_mobility_turn_multiplier(), 1.0))
	agent.mech_loadout = lightest
	assert(is_equal_approx(
		agent.effective_dash_distance(),
		agent.dash_speed * agent.dash_duration * 1.5
	))
	agent.mech_loadout = heaviest
	assert(is_equal_approx(
		agent.effective_dash_distance(),
		agent.dash_speed * agent.dash_duration * 0.5
	))
	assert(is_equal_approx(
		agent.effective_dash_speed() * agent.effective_dash_duration(),
		agent.effective_dash_distance()
	))
	agent.dash_direction = Vector2.RIGHT
	assert(agent._dash_movement_was_blocked(Vector2(0.0, 50.0), 100.0))
	assert(not agent._dash_movement_was_blocked(Vector2(30.0, 50.0), 100.0))
	assert(not agent._dash_movement_was_blocked(Vector2(2.0, 0.0), 2.0))
	agent.player_controlled = true
	agent.dash_time_remaining = 0.5
	agent.velocity = Vector2(100.0, 0.0)
	agent.cancel_dash_after_collision()
	assert(not agent.is_dashing())
	assert(agent.velocity.is_zero_approx())
	agent.wall_blocked_last_step = false
	agent._apply_movement_step(Vector2(10.0, 0.0))
	assert(not agent.wall_blocked_last_step)
	var blocking_constraint := BlockingConstraint.new()
	agent.movement_constraint = blocking_constraint
	agent._apply_movement_step(Vector2(10.0, 0.0), true)
	assert(agent.wall_blocked_last_step)
	assert(agent.wall_turn_speed_multiplier() == 2.0)
	agent.movement_constraint = null
	blocking_constraint.free()
	agent._apply_movement_step(Vector2(10.0, 0.0), true)
	assert(not agent.wall_blocked_last_step)
	assert(agent.wall_turn_speed_multiplier() == 1.0)

	var test_mask := HalfPlaneWalkabilityMask.new()
	var diagonal_motion := Vector2(4.0, 4.0)
	var diagonal_slide := test_mask.resolve_sliding_motion(
		Vector2.ZERO,
		diagonal_motion,
		0.0
	)
	assert(absf(diagonal_slide.x) < 0.01)
	assert(diagonal_slide.y > 0.0 and diagonal_slide.y < diagonal_motion.y)
	var frontal_slide := test_mask.resolve_sliding_motion(
		Vector2.ZERO,
		Vector2(4.0, 0.0),
		0.0
	)
	assert(absf(frontal_slide.x) < 0.01 and is_zero_approx(frontal_slide.y))
	test_mask.free()

	var angled_mask := AngledHalfPlaneWalkabilityMask.new()
	var angled_motion := Vector2(4.0, 0.0)
	var angled_slide := angled_mask.resolve_sliding_motion(
		Vector2.ZERO,
		angled_motion,
		0.0
	)
	assert(angled_slide.dot(AngledHalfPlaneWalkabilityMask.NORMAL) <= 0.01)
	assert(angled_slide.x > 0.0 and angled_slide.y < 0.0)
	assert(angled_slide.length() < angled_motion.length())
	var angled_frontal := angled_mask.resolve_sliding_motion(
		Vector2.ZERO,
		AngledHalfPlaneWalkabilityMask.NORMAL * 4.0,
		0.0
	)
	assert(angled_frontal.length() < 0.01)
	angled_mask.free()

	agent.player_controlled = false
	agent.dash_direction = Vector2.RIGHT
	agent.dash_time_remaining = 0.0
	agent.velocity = Vector2(100.0, 0.0)
	agent.cancel_dash_after_collision(true)
	assert(agent.is_ai_wall_recovering())
	assert(agent.velocity.is_zero_approx())

	agent.player_actions_release_gate = true
	agent._update_player_actions_release_gate_state(true, false)
	assert(agent.player_actions_release_gate and agent.dash_input_was_pressed)
	agent._update_player_actions_release_gate_state(false, true)
	assert(agent.player_actions_release_gate and not agent.dash_input_was_pressed)
	agent._update_player_actions_release_gate_state(false, false)
	assert(not agent.player_actions_release_gate)

	agent.part_max_durability[&"Legs"] = 100.0
	agent.part_durability[&"Legs"] = 100.0
	agent.dash_time_remaining = 10.0
	agent.velocity = Vector2(100.0, 0.0)
	agent.register_hit(&"Legs", Vector2.LEFT, 100.0)
	assert(not agent.is_dashing() and agent.velocity.is_zero_approx())
	var energy_before_failed_dash := agent.current_energy
	assert(not agent._consume_dash_resources())
	assert(agent.current_energy == energy_before_failed_dash)
	agent.part_durability[&"Legs"] = 100.0
	agent.dash_time_remaining = INF
	agent._sanitize_dash_state()
	assert(not agent.is_dashing() and agent.velocity.is_zero_approx())
	agent.dash_speed = 0.0
	assert(not agent._consume_dash_resources())

	assert(is_equal_approx(weapon_catalog.projectiles_by_id["projectile_missile_rapid"].damage, 0.45))
	assert(is_equal_approx(weapon_catalog.projectiles_by_id["projectile_missile_standard"].damage, 1.875))
	assert(is_equal_approx(weapon_catalog.projectiles_by_id["projectile_missile_heavy"].damage, 3.75))

	agent.free()
	print("DASH_SCALING_CHECK passed")
	quit(0)


func _loadout(catalog: MechPartCatalog, ids: Array[String]) -> MechLoadout:
	var loadout := MechLoadout.new()
	loadout.body = catalog.parts_by_id[ids[0]]
	loadout.head = catalog.parts_by_id[ids[1]]
	loadout.legs = catalog.parts_by_id[ids[2]]
	loadout.left_arm = catalog.parts_by_id.get(ids[3])
	loadout.right_arm = catalog.parts_by_id.get(ids[4])
	loadout.backpack = catalog.parts_by_id.get(ids[5])
	assert(loadout.is_valid())
	return loadout
