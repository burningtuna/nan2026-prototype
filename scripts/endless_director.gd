class_name EndlessDirector
extends Node

signal score_changed(score: int, high_score: int)
signal tier_changed(tier: int, elapsed_seconds: float)
signal mech_wave_started(count: int)
signal run_finished(score: int, high_score: int)

const DRONE_AGENT := preload("res://scripts/drone_agent.gd")
const ALIEN_INFESTATION_OVERLAY := preload("res://scripts/alien_infestation_overlay.gd")
const PARTS_DATA_PATH := "res://data/mech_parts.json"
const DRONE_SCORES := {
	DroneAgent.DroneKind.HEAD: 10,
	DroneAgent.DroneKind.LEGS: 20,
	DroneAgent.DroneKind.ARM: 30,
}
const MECH_SCORE := 250
const MAX_LIVING_MECHS := 8

var battle
var player: AiMechAgent
var part_catalog: MechPartCatalog
var rng := RandomNumberGenerator.new()
var running := false
var persist_score := true
var elapsed_seconds := 0.0
var score := 0
var high_score := 0
var tier := 0
var spawn_remaining := 0.0
var next_mech_time := 60.0
var drone_sequence := 0
var mech_sequence := 0


func setup(combat_battle, combat_player: AiMechAgent, should_persist := true) -> bool:
	battle = combat_battle
	player = combat_player
	persist_score = should_persist
	part_catalog = MechPartCatalog.new()
	if not part_catalog.load_file(PARTS_DATA_PATH, battle.weapon_catalog):
		return false
	rng.seed = 12122026
	high_score = GameSession.load_endless_high_score() if persist_score else 0
	battle.agent_defeated.connect(_on_agent_defeated)
	player.defeated.connect(_on_player_defeated)
	running = true
	spawn_remaining = 0.1
	score_changed.emit(score, high_score)
	return true


func _process(delta: float) -> void:
	if not running or not is_instance_valid(player):
		return
	elapsed_seconds += delta
	var next_tier := floori(elapsed_seconds / 30.0)
	if next_tier != tier:
		tier = next_tier
		tier_changed.emit(tier, elapsed_seconds)
	spawn_remaining -= delta
	if spawn_remaining <= 0.0 and _living_drones() < _drone_limit():
		spawn_drone()
		spawn_remaining = maxf(2.0 - tier * 0.15, 0.45)
	while elapsed_seconds >= next_mech_time:
		var target_mechs := mini(floori(next_mech_time / 60.0), MAX_LIVING_MECHS)
		var spawn_count := maxi(target_mechs - _living_mechs(), 0)
		for _index in spawn_count:
			spawn_mech()
		if spawn_count > 0:
			mech_wave_started.emit(spawn_count)
		next_mech_time += 60.0


func spawn_drone(forced_kind := -1) -> DroneAgent:
	if not is_instance_valid(player):
		return null
	var kind := forced_kind
	if kind < 0:
		var maximum_kind := mini(tier, DroneAgent.DroneKind.ARM)
		kind = rng.randi_range(DroneAgent.DroneKind.HEAD, maximum_kind)
	var part_type := MechPartSpec.PartType.HEAD
	match kind:
		DroneAgent.DroneKind.LEGS:
			part_type = MechPartSpec.PartType.LEGS
		DroneAgent.DroneKind.ARM:
			part_type = MechPartSpec.PartType.ARM_EQUIPMENT
	var candidates: Array = part_catalog.parts_by_type[part_type]
	if kind == DroneAgent.DroneKind.ARM:
		candidates = candidates.filter(func(part: MechPartSpec) -> bool:
			return part.weapon != null
		)
	var part := candidates[rng.randi_range(0, candidates.size() - 1)] as MechPartSpec
	drone_sequence += 1
	var drone := DRONE_AGENT.new() as DroneAgent
	drone.setup_drone(part, kind, battle.projectile_layer, battle.arena, player, drone_sequence)
	drone.position = _spawn_position()
	battle.add_combatant(drone)
	ALIEN_INFESTATION_OVERLAY.attach_to(drone)
	return drone


func spawn_mech() -> AiMechAgent:
	mech_sequence += 1
	var mech: AiMechAgent = battle.spawn_endless_mech(_spawn_position(), mech_sequence)
	ALIEN_INFESTATION_OVERLAY.attach_to(mech)
	return mech


func _spawn_position() -> Vector2:
	var minimum: Vector2 = battle.arena.position + Vector2.ONE * 80.0
	var maximum: Vector2 = battle.arena.end - Vector2.ONE * 80.0
	for _attempt in 12:
		var direction := Vector2.from_angle(rng.randf_range(0.0, TAU))
		var candidate := (player.global_position + direction * rng.randf_range(900.0, 1300.0)).clamp(
			minimum,
			maximum
		)
		if candidate.distance_to(player.global_position) >= 800.0:
			return candidate
	var corners := [minimum, Vector2(maximum.x, minimum.y), maximum, Vector2(minimum.x, maximum.y)]
	var farthest: Vector2 = corners[0]
	for corner: Vector2 in corners:
		if corner.distance_squared_to(player.global_position) > farthest.distance_squared_to(player.global_position):
			farthest = corner
	return farthest


func _drone_limit() -> int:
	return mini(6 + tier * 2, 24)


func _living_drones() -> int:
	var count := 0
	for agent in battle.agents:
		if is_instance_valid(agent) and agent.unit_class == AiMechAgent.UnitClass.DRONE and not agent.is_defeated():
			count += 1
	return count


func _living_mechs() -> int:
	var count := 0
	for agent in battle.agents:
		if is_instance_valid(agent) and agent.unit_class == AiMechAgent.UnitClass.BOSS and not agent.is_defeated():
			count += 1
	return count


func _on_agent_defeated(agent: AiMechAgent) -> void:
	if not running or not is_instance_valid(agent) or agent.team_id == player.team_id:
		return
	if agent.unit_class == AiMechAgent.UnitClass.DRONE:
		var drone := agent as DroneAgent
		score += int(DRONE_SCORES.get(drone.drone_kind, 10))
		_remove_after(agent, 0.05)
	else:
		score += MECH_SCORE
		player.repair_surviving_parts(0.2)
		_remove_after(agent, 3.0)
	high_score = maxi(high_score, score)
	score_changed.emit(score, high_score)


func _remove_after(agent: AiMechAgent, seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
	if is_instance_valid(battle) and is_instance_valid(agent):
		battle.remove_combatant(agent)


func _on_player_defeated() -> void:
	if not running:
		return
	running = false
	high_score = GameSession.submit_endless_score(score) if persist_score else maxi(high_score, score)
	run_finished.emit(score, high_score)
