extends "res://scripts/combat_hud_test.gd"

const SMOKE_SAVE_PATH := "/tmp/opencode/nan2026_story_stage_test.json"

@onready var story_stage: StoryStage = $CombatContainer/CombatViewport/StoryStage


func _on_combat_bound() -> void:
	story_stage.message_requested.connect(system_messages.push_message)
	for cover in story_stage.blockers:
		if cover is StoryDestructibleCover:
			cover.cover_destroyed.connect(_on_cover_destroyed)
	if OS.get_cmdline_user_args().has("--story-stage-smoke"):
		call_deferred("_run_story_stage_smoke")


func _on_cover_destroyed(cover_id: StringName) -> void:
	system_messages.push_message("COVER DESTROYED: %s" % cover_id)


func _run_story_stage_smoke() -> void:
	assert(story_stage.initialized)
	assert(battle.agents.size() == 2)
	assert(combat_player.mech_loadout.head.part_id == "raven_sensor")
	assert(combat_player.mech_loadout.body.part_id == "kestrel_core")
	assert(combat_player.mech_loadout.left_arm.part_id == "rx_autocannon")

	var original_path: String = GameSession.story_progress_path
	GameSession.story_progress_path = SMOKE_SAVE_PATH
	GameSession.delete_story_progress()

	var blocked_position: Vector2 = story_stage.get_node("Geometry/BlockedProbe").global_position
	var resolved := story_stage.resolve_agent_motion(combat_player.global_position, blocked_position, 28.0)
	assert(resolved == combat_player.global_position)

	combat_player.global_position = story_stage.get_node("Triggers/ReinforcementTrigger").global_position
	story_stage._physics_process(0.0)
	assert(battle.agents.size() == 4)
	story_stage._physics_process(0.0)
	assert(battle.agents.size() == 4)

	combat_player.global_position = story_stage.get_node("Triggers/RescueTrigger").global_position
	story_stage._physics_process(0.0)
	assert(GameSession.story_flag(&"rescued_en_support", false))
	GameSession.story_progress.clear()
	assert(GameSession.story_flag(&"rescued_en_support", false))

	var cover := story_stage.get_node("Geometry/DestructibleCover") as StoryDestructibleCover
	cover.receive_projectile_hit(cover.maximum_durability, Vector2.RIGHT, cover.global_position)
	assert(cover.destroyed)
	assert(not cover.blocks_agent_at(cover.global_position, 28.0))

	GameSession.delete_story_progress()
	GameSession.story_progress_path = original_path
	print("STORY_STAGE_CHECK passed")
	get_tree().quit(0)
