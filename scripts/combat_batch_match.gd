class_name CombatBatchMatch
extends Node2D

const AI_MECH := preload("res://scripts/ai_mech_agent.gd")
const ARENA := Rect2(-3000.0, -3000.0, 6000.0, 6000.0)
const STARTS := [
	Vector2(-1000.0, -260.0),
	Vector2(-1000.0, 260.0),
	Vector2(1000.0, -260.0),
	Vector2(1000.0, 260.0),
]

var match_config: Dictionary
var agents: Array[AiMechAgent] = []
var projectile_layer: Node2D
var elapsed_ticks := 0
var timeout_ticks := 0
var completed := false
var result: Dictionary = {}


func setup(config: Dictionary, team_loadouts: Array, physics_hz: int, timeout_seconds: float) -> void:
	match_config = config
	timeout_ticks = maxi(roundi(timeout_seconds * physics_hz), 1)
	projectile_layer = Node2D.new()
	projectile_layer.name = "Projectiles"
	add_child(projectile_layer)

	for index in 4:
		var team_index := 0 if index < 2 else 1
		var loadout := (team_loadouts[team_index] as MechLoadout).copy()
		var agent := AI_MECH.new() as AiMechAgent
		agent.team_id = int(config["team_ids"][team_index])
		agent.player_controlled = false
		agent.combat_visuals_enabled = false
		agent.movement_type = (
			AiMechAgent.MovementType.AGGRESSIVE
			if index % 2 == 0
			else AiMechAgent.MovementType.RANGE_KEEPER
		)
		if String(config["panel_id"]) == "MISSILE":
			agent.preferred_range = 4000.0
			agent.evasion_range = 2500.0
		else:
			agent.preferred_range = 350.0
			agent.evasion_range = 250.0
		agent.setup(
			"M%04d-T%d-A%d" % [int(config["match_index"]), team_index, index % 2],
			projectile_layer,
			ARENA,
			int(config["seed"]) + index * 7919,
			Color.WHITE,
			_weapons_from_loadout(loadout),
			loadout
		)
		agent.position = STARTS[index]
		add_child(agent)
		agents.append(agent)

	var team_zero: Array = [agents[0], agents[1]]
	var team_one: Array = [agents[2], agents[3]]
	agents[0].set_opponents(team_one)
	agents[1].set_opponents(team_one)
	agents[2].set_opponents(team_zero)
	agents[3].set_opponents(team_zero)


func _physics_process(_delta: float) -> void:
	if completed:
		return
	elapsed_ticks += 1
	var team_zero_alive := not agents[0].is_defeated() or not agents[1].is_defeated()
	var team_one_alive := not agents[2].is_defeated() or not agents[3].is_defeated()
	if not team_zero_alive or not team_one_alive:
		if team_zero_alive != team_one_alive:
			_finish("WIN", 0 if team_zero_alive else 1)
		else:
			_finish("DRAW", -1)
	elif elapsed_ticks >= timeout_ticks:
		_finish("TIMEOUT", -1)


func _finish(outcome: String, winner_team_index: int) -> void:
	completed = true
	result = match_config.duplicate(true)
	result["outcome"] = outcome
	result["winner_team_index"] = winner_team_index
	result["winner_build_id"] = (
		String(result["team_build_ids"][winner_team_index]) if winner_team_index >= 0 else ""
	)
	result["elapsed_ticks"] = elapsed_ticks
	result["agents"] = []
	for index in agents.size():
		result["agents"].append(_agent_summary(agents[index], 0 if index < 2 else 1))
	process_mode = Node.PROCESS_MODE_DISABLED


func _agent_summary(agent: AiMechAgent, team_index: int) -> Dictionary:
	var durability := {}
	var maximum_durability := {}
	var destroyed_parts: Array[String] = []
	for part_name in agent.part_max_durability:
		var key := String(part_name)
		durability[key] = float(agent.part_durability.get(part_name, 0.0))
		maximum_durability[key] = float(agent.part_max_durability[part_name])
		if agent.is_part_destroyed(part_name):
			destroyed_parts.append(key)
	destroyed_parts.sort()
	return {
		"team_index": team_index,
		"defeated": agent.is_defeated(),
		"durability": durability,
		"maximum_durability": maximum_durability,
		"destroyed_parts": destroyed_parts,
		"incoming_hits": agent.hit_count,
		"front_hits": agent.aspect_hits(&"FRONT"),
		"side_hits": agent.aspect_hits(&"SIDE"),
		"rear_hits": agent.aspect_hits(&"REAR"),
		"shots": agent.shot_count,
		"projectiles": agent.projectile_count,
		"landed_hits": (
			agent.landed_hits_for(WeaponSpec.WeaponFamily.BALLISTIC)
			+ agent.landed_hits_for(WeaponSpec.WeaponFamily.ENERGY)
			+ agent.landed_hits_for(WeaponSpec.WeaponFamily.MISSILE)
		),
		"dashes": agent.dash_count,
	}


func _weapons_from_loadout(loadout: MechLoadout) -> Array[WeaponSpec]:
	var result_specs: Array[WeaponSpec] = []
	for part in [loadout.left_arm, loadout.right_arm, loadout.backpack]:
		if part != null and part.weapon != null:
			result_specs.append(part.weapon)
	return result_specs
