extends StoryMission


func _on_combat_bound() -> void:
	super._on_combat_bound()
	if OS.get_cmdline_user_args().has("--story-deploy-smoke"):
		call_deferred("_run_story_deploy_smoke")
	if OS.get_cmdline_user_args().has("--stage-03-smoke"):
		call_deferred("_run_stage_smoke")


func _run_story_deploy_smoke() -> void:
	assert(GameSession.selected_game_mode == GameSession.GameMode.STORY)
	assert(GameSession.story_deployment_scene_path == "res://scenes/stage_03.tscn")
	assert(GameSession.player_mech_loadout != null)
	for slot in MechLoadout.MechSlot.values():
		var deployed_part := combat_player.mech_loadout.part_for_slot(slot)
		var confirmed_part := GameSession.player_mech_loadout.part_for_slot(slot)
		assert(deployed_part == confirmed_part)
	print("STORY_DEPLOY_CHECK passed")
	get_tree().quit(0)


func _run_stage_smoke() -> void:
	assert(story_stage.initialized)
	assert(battle.agents.size() == 3)
	assert(battle.player_agent() != null)
	var team_counts := {0: 0, 1: 0}
	var boss: AiMechAgent
	for agent: AiMechAgent in battle.agents:
		team_counts[agent.team_id] = team_counts.get(agent.team_id, 0) + 1
		if agent.team_id == 1:
			boss = agent
	assert(team_counts[0] == 2)
	assert(team_counts[1] == 1)
	assert(boss != null)
	assert(boss.unit_class == AiMechAgent.UnitClass.BOSS)
	assert(boss.movement_type == AiMechAgent.MovementType.AGGRESSIVE)
	assert(is_equal_approx(boss.movement_speed_multiplier, 1.35))
	assert(is_equal_approx(boss.fire_rate_multiplier, 1.4))
	assert(is_equal_approx(boss.incoming_damage_multiplier, 0.5))
	print("STAGE_03_CHECK passed")
	get_tree().quit(0)
