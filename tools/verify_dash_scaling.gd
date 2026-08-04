extends SceneTree

const PARTS_DATA_PATH := "res://data/mech_parts.json"
const WEAPONS_DATA_PATH := "res://data/weapons.json"


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
