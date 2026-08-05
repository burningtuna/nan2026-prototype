@tool
class_name StoryStage
extends Node2D

signal message_requested(message: String)
signal trigger_activated(trigger_id: StringName)

const PARTS_DATA_PATH := "res://data/mech_parts.json"

@export var stage_id := "story_map_test"
@export var battle_path: NodePath
@export var editor_guides_visible_in_game := true

var battle
var part_catalog: MechPartCatalog
var spawn_points: Array[StorySpawnPoint] = []
var triggers: Array[StoryTriggerArea] = []
var walkable_areas: Array[StoryWalkableArea] = []
var blockers: Array[StoryBlocker] = []
var spawned_points := {}
var last_valid_positions := {}
var initialized := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	process_physics_priority = 200
	call_deferred("_initialize_stage")


func _initialize_stage() -> void:
	battle = get_node_or_null(battle_path)
	if battle == null or not battle.has_method("spawn_story_mech"):
		push_error("StoryStage requires a battle node with spawn_story_mech()")
		return
	part_catalog = MechPartCatalog.new()
	if not part_catalog.load_file(PARTS_DATA_PATH, battle.weapon_catalog):
		push_error("Unable to load story stage part catalog")
		return
	_collect_authoring_nodes(self)
	for area in walkable_areas:
		area.visible = editor_guides_visible_in_game
	for trigger in triggers:
		trigger.visible = editor_guides_visible_in_game
		trigger.activated.connect(_on_trigger_activated)
	for point in spawn_points:
		point.visible = editor_guides_visible_in_game
		if point.spawn_mode == StorySpawnPoint.SpawnMode.PREPLACED:
			_spawn_point(point)
	initialized = true
	message_requested.emit("STORY MAP READY // %s" % stage_id.to_upper())


func _physics_process(_delta: float) -> void:
	if not initialized:
		return
	for agent in battle.agents:
		if not is_instance_valid(agent) or agent.is_defeated():
			continue
		var instance_id: int = agent.get_instance_id()
		var current: Vector2 = agent.global_position
		var previous: Vector2 = last_valid_positions.get(instance_id, current)
		var resolved := _resolve_agent_footprint(previous, current, agent.environment_collision_radius())
		agent.global_position = resolved
		last_valid_positions[instance_id] = resolved
	var player: AiMechAgent = battle.player_agent() as AiMechAgent
	if player == null or player.is_defeated():
		return
	for trigger in triggers:
		trigger.try_activate(player.global_position)


func resolve_agent_motion(previous: Vector2, proposed: Vector2, radius: float, allow_wall_slide := false) -> Vector2:
	var resolved := proposed
	if not _is_walkable_motion(previous, proposed, radius):
		resolved = _resolve_wall_slide(previous, proposed, radius) if allow_wall_slide else previous
	for blocker in blockers:
		if is_instance_valid(blocker) and blocker.blocks_agent_at(resolved, radius):
			return previous
	return resolved


func _resolve_agent_footprint(previous: Vector2, current: Vector2, radius: float) -> Vector2:
	if not _is_walkable(current, radius):
		return previous
	for blocker in blockers:
		if is_instance_valid(blocker) and blocker.blocks_agent_at(current, radius):
			return previous
	return current


func _resolve_wall_slide(previous: Vector2, proposed: Vector2, radius: float) -> Vector2:
	var best_position := previous
	var best_distance_squared := 0.0
	for area in walkable_areas:
		if not area.has_method("resolve_sliding_motion"):
			continue
		var candidate: Vector2 = area.resolve_sliding_motion(previous, proposed, radius)
		var distance_squared := previous.distance_squared_to(candidate)
		if distance_squared > best_distance_squared:
			best_position = candidate
			best_distance_squared = distance_squared
	return best_position


func _is_walkable_motion(previous: Vector2, proposed: Vector2, radius: float) -> bool:
	var has_motion_constraint := false
	for area in walkable_areas:
		if not area.has_method("contains_agent_motion"):
			continue
		has_motion_constraint = true
		if area.contains_agent_motion(previous, proposed, radius):
			return true
	return false if has_motion_constraint else _is_walkable(proposed, radius)


func _is_walkable(point: Vector2, radius := 0.0) -> bool:
	if walkable_areas.is_empty():
		return true
	for area in walkable_areas:
		if radius > 0.0 and area.has_method("contains_agent_at"):
			if area.contains_agent_at(point, radius):
				return true
		elif area.contains_global_point(point):
			return true
	return false


func _collect_authoring_nodes(root: Node) -> void:
	for child in root.get_children():
		if child is StorySpawnPoint:
			spawn_points.append(child)
		elif child is StoryTriggerArea:
			triggers.append(child)
		elif child is StoryWalkableArea:
			walkable_areas.append(child)
		elif child is StoryBlocker:
			blockers.append(child)
		_collect_authoring_nodes(child)


func _spawn_point(point: StorySpawnPoint) -> AiMechAgent:
	var point_id: int = point.get_instance_id()
	if spawned_points.has(point_id):
		return spawned_points[point_id]
	var loadout := _loadout_for(point)
	if loadout == null:
		return null
	var agent: AiMechAgent = battle.spawn_story_mech(
		point.unit_id,
		battle.to_local(point.global_position),
		point.team_id,
		point.player_controlled,
		loadout,
		point.random_seed,
		point.team_color,
		point.movement_type
	)
	if agent == null:
		return null
	agent.unit_class = point.unit_class
	agent.movement_speed_multiplier *= point.movement_speed_scale
	agent.fire_rate_multiplier *= point.fire_rate_scale
	agent.incoming_damage_multiplier *= point.incoming_damage_scale
	if point.stationary:
		agent.cruise_speed = 0.0
		agent.dash_speed = 0.0
		agent.acceleration = 0.0
	if point.weapons_disabled:
		agent.combat_actions_enabled = false
	agent.set_movement_constraint(self)
	spawned_points[point_id] = agent
	last_valid_positions[agent.get_instance_id()] = agent.global_position
	return agent


func _loadout_for(point: StorySpawnPoint) -> MechLoadout:
	if point.use_session_loadout and GameSession.player_mech_loadout != null:
		return GameSession.player_mech_loadout.copy()
	var loadout := MechLoadout.new()
	var slot_by_key := {
		"head": MechLoadout.MechSlot.HEAD,
		"body": MechLoadout.MechSlot.BODY,
		"left_arm": MechLoadout.MechSlot.LEFT_ARM,
		"right_arm": MechLoadout.MechSlot.RIGHT_ARM,
		"backpack": MechLoadout.MechSlot.BACKPACK,
		"legs": MechLoadout.MechSlot.LEGS,
	}
	for key in slot_by_key:
		var part_id: String = str(point.part_ids()[key])
		if part_id.is_empty():
			continue
		var part := part_catalog.parts_by_id.get(part_id) as MechPartSpec
		if part == null:
			push_error("Unknown story part '%s' on %s" % [part_id, point.unit_id])
			return null
		loadout.set_part(slot_by_key[key], part)
	if not loadout.is_valid():
		push_error("Invalid story loadout on %s: %s" % [point.unit_id, ", ".join(loadout.validation_errors())])
		return null
	return loadout


func _on_trigger_activated(trigger: StoryTriggerArea) -> void:
	if not trigger.spawn_group.is_empty():
		for point in spawn_points:
			if point.spawn_mode == StorySpawnPoint.SpawnMode.TRIGGERED and point.spawn_group == trigger.spawn_group:
				_spawn_point(point)
	if not trigger.campaign_flag.is_empty():
		GameSession.set_story_flag(trigger.campaign_flag, trigger.campaign_value)
	if not trigger.message.is_empty():
		message_requested.emit(trigger.message)
	trigger_activated.emit(trigger.trigger_id)
