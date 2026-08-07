extends SceneTree

const PARTS_DATA_PATH := "res://data/mech_parts.json"
const WEAPONS_DATA_PATH := "res://data/weapons.json"
const HEAVY_ARMS := [
	"siege_rail_cannon_arm",
	"nova_beam_cannon_arm",
	"longbow_cruise_arm",
	"avalanche_flak_arm",
]
const HEAVY_BACKPACKS := [
	"siege_rail_backpack",
	"nova_beam_backpack",
	"longbow_cruise_backpack",
	"avalanche_flak_backpack",
]


func _initialize() -> void:
	var weapon_catalog := WeaponCatalog.new()
	assert(weapon_catalog.load_file(WEAPONS_DATA_PATH))
	var part_catalog := MechPartCatalog.new()
	assert(part_catalog.load_file(PARTS_DATA_PATH, weapon_catalog))

	_verify_heavy_weapon_limits(part_catalog)
	_verify_repair_backpack(part_catalog)
	print("REPAIR_BACKPACK_CHECK passed")
	quit(0)


func _verify_heavy_weapon_limits(catalog: MechPartCatalog) -> void:
	for arm_id in HEAVY_ARMS:
		assert(is_equal_approx(catalog.parts_by_id[arm_id].weight, 29.0))
	for backpack_id in HEAVY_BACKPACKS:
		assert(is_equal_approx(catalog.parts_by_id[backpack_id].weight, 37.0))
	for arm_id in HEAVY_ARMS:
		for backpack_id in HEAVY_BACKPACKS:
			var strider := _loadout(
				catalog, "strider_legs", arm_id, arm_id, backpack_id
			)
			assert(not strider.is_valid())
			assert("WEIGHT LIMIT EXCEEDED" in strider.validation_errors())
			var anvil := _loadout(catalog, "anvil_legs", arm_id, arm_id, backpack_id)
			assert(anvil.is_valid())


func _verify_repair_backpack(catalog: MechPartCatalog) -> void:
	var repair_backpack := catalog.parts_by_id["field_repair_backpack"] as MechPartSpec
	assert(is_equal_approx(repair_backpack.weight, 68.0))
	assert(is_equal_approx(repair_backpack.power_generation, 30.0))
	assert(is_equal_approx(repair_backpack.repair_power_generation, 10.0))
	assert(is_equal_approx(repair_backpack.repair_rate, 5.0))

	var courier := _loadout(
		catalog, "courier_legs", "arc_repeater_arm", "", "field_repair_backpack"
	)
	assert(not courier.is_valid())
	var strider := _loadout(
		catalog, "strider_legs", "arc_repeater_arm", "", "field_repair_backpack"
	)
	assert(strider.is_valid())
	var loaded_anvil := _loadout(
		catalog,
		"anvil_legs",
		"siege_rail_cannon_arm",
		"siege_rail_cannon_arm",
		"field_repair_backpack"
	)
	assert(loaded_anvil.is_valid())
	assert(is_equal_approx(float(loaded_anvil.stats()["weight"]), 155.0))

	var agent := AiMechAgent.new()
	agent.mech_loadout = strider
	agent._initialize_part_durability()
	var base_capacity := agent.energy_capacity()
	assert(is_equal_approx(base_capacity, 106.0))

	agent.part_durability[&"Body"] = 100.0
	agent.part_durability[&"Head"] = 150.0
	agent._update_repair_backpack(1.0)
	assert(agent.repair_backpack_active)
	assert(is_equal_approx(float(agent.part_durability[&"Body"]), 105.0))
	assert(is_equal_approx(float(agent.part_durability[&"Head"]), 150.0))
	assert(is_equal_approx(agent.energy_capacity(), base_capacity - 20.0))

	agent.part_durability[&"Body"] = 190.0
	agent.part_durability[&"Head"] = 100.0
	agent._update_repair_backpack(0.5)
	assert(is_equal_approx(float(agent.part_durability[&"Body"]), 190.0))
	assert(is_equal_approx(float(agent.part_durability[&"Head"]), 102.5))

	for part_name in agent.part_max_durability:
		agent.part_durability[part_name] = agent.part_max_durability[part_name]
	agent.part_durability[&"Backpack"] = 150.0
	agent._update_repair_backpack(1.0)
	assert(is_equal_approx(float(agent.part_durability[&"Backpack"]), 155.0))

	for part_name in agent.part_max_durability:
		agent.part_durability[part_name] = agent.part_max_durability[part_name]
	agent._update_repair_backpack(1.0)
	assert(not agent.repair_backpack_active)
	assert(is_equal_approx(agent.energy_capacity(), base_capacity))
	agent.free()


func _loadout(
	catalog: MechPartCatalog,
	legs_id: String,
	left_arm_id: String,
	right_arm_id: String,
	backpack_id: String
) -> MechLoadout:
	var loadout := MechLoadout.new()
	loadout.body = catalog.parts_by_id["swift_core"]
	loadout.head = catalog.parts_by_id["falcon_sensor"]
	loadout.legs = catalog.parts_by_id[legs_id]
	loadout.left_arm = catalog.parts_by_id.get(left_arm_id)
	loadout.right_arm = catalog.parts_by_id.get(right_arm_id)
	loadout.backpack = catalog.parts_by_id.get(backpack_id)
	return loadout
