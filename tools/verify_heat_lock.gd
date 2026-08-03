extends SceneTree


func _initialize() -> void:
	var agent := AiMechAgent.new()
	agent.current_energy = AiMechAgent.DEFAULT_MAX_ENERGY
	agent.current_heat = AiMechAgent.MAX_HEAT - AiMechAgent.DASH_HEAT_COST
	assert(agent._consume_dash_resources())
	assert(agent.current_heat == AiMechAgent.MAX_HEAT)
	assert(agent.heat_generation_locked)

	var energy_after_overheat := agent.current_energy
	assert(not agent._consume_dash_resources())
	assert(agent.current_energy == energy_after_overheat)
	assert(agent.current_heat == AiMechAgent.MAX_HEAT)

	var heated_weapon := WeaponRuntime.new()
	heated_weapon.spec = WeaponSpec.new()
	heated_weapon.spec.heat_cost = 1.0
	assert(not agent._has_weapon_resources(heated_weapon))
	var cool_weapon := WeaponRuntime.new()
	cool_weapon.spec = WeaponSpec.new()
	assert(agent._has_weapon_resources(cool_weapon))

	agent.current_heat = 0.0
	agent._update_resources(0.0)
	assert(not agent.heat_generation_locked)
	assert(agent._has_weapon_resources(heated_weapon))
	agent.current_heat = AiMechAgent.MAX_HEAT - 1.0
	heated_weapon.spec.heat_cost = 50.0
	assert(agent._has_weapon_resources(heated_weapon))
	agent._add_heat(heated_weapon.spec.heat_cost)
	assert(agent.current_heat == AiMechAgent.MAX_HEAT)
	assert(agent.heat_generation_locked)

	agent.free()
	print("HEAT_LOCK_CHECK passed")
	quit(0)
