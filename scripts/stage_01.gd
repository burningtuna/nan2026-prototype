extends StoryMission


func _on_combat_bound() -> void:
	super._on_combat_bound()
	if OS.get_cmdline_user_args().has("--stage-01-smoke"):
		call_deferred("_run_stage_smoke")


func _run_stage_smoke() -> void:
	assert(story_stage.initialized)
	assert(battle.agents.size() == 5)
	assert(battle.player_agent() != null)
	var team_counts := {0: 0, 1: 0}
	for agent: AiMechAgent in battle.agents:
		team_counts[agent.team_id] = team_counts.get(agent.team_id, 0) + 1
		if agent.team_id == 1:
			assert(is_zero_approx(agent.cruise_speed))
			assert(is_zero_approx(agent.dash_speed))
			assert(is_zero_approx(agent.acceleration))
			assert(not agent.combat_actions_enabled)
			assert(not agent.is_defeated())
			for weapon in agent.weapons:
				assert(not weapon.disabled)
	assert(team_counts[0] == 1)
	assert(team_counts[1] == 4)
	print("STAGE_01_CHECK passed")
	get_tree().quit(0)
