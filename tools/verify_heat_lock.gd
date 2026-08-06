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
	assert(agent.clear_overheat() == AiMechAgent.MAX_HEAT)
	assert(agent.current_heat == 0.0 and not agent.heat_generation_locked)
	agent.current_energy = 1.0
	assert(agent.restore_energy_full() == AiMechAgent.DEFAULT_MAX_ENERGY - 1.0)

	var hud := GameHud.new()
	hud._build_audio()
	root.add_child(hud)
	hud.player = agent
	agent.heat_generation_locked = false
	agent.current_heat = AiMechAgent.MAX_HEAT * 0.6
	hud.set_resource_ratios(1.0, agent.heat_ratio())
	hud._update_heat_audio()
	assert(hud.heat_audio_state == 1)
	assert(hud.heat_alarm.stream == hud.heat_warning_stream)
	agent.current_heat = AiMechAgent.MAX_HEAT * 0.8
	hud.set_resource_ratios(1.0, agent.heat_ratio())
	hud._update_heat_audio()
	assert(hud.heat_audio_state == 2)
	assert(hud.heat_alarm.stream == hud.heat_critical_stream)
	agent.heat_generation_locked = true
	hud._update_heat_audio()
	assert(hud.heat_audio_state == 0)
	assert(not hud.heat_alarm.playing)

	hud.free()
	agent.free()
	print("HEAT_LOCK_CHECK passed")
	quit(0)
