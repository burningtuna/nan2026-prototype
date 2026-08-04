extends StoryMission


func _on_combat_bound() -> void:
	super._on_combat_bound()
	if OS.get_cmdline_user_args().has("--stage-02-smoke"):
		call_deferred("_run_stage_smoke")


func _run_stage_smoke() -> void:
	assert(story_stage.initialized)
	assert(battle.agents.size() == 4)
	assert(battle.player_agent() != null)
	var team_counts := {0: 0, 1: 0}
	for agent: AiMechAgent in battle.agents:
		team_counts[agent.team_id] = team_counts.get(agent.team_id, 0) + 1
		if not agent.player_controlled:
			assert(agent.movement_type == AiMechAgent.MovementType.BALANCED)
	assert(team_counts[0] == 2)
	assert(team_counts[1] == 2)
	print("STAGE_02_CHECK passed")
	get_tree().quit(0)
