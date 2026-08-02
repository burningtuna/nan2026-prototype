extends SceneTree

const BATCH_MATCH := preload("res://scripts/combat_batch_match.gd")
const PARTS_DATA_PATH := "res://data/mech_parts.json"
const WEAPONS_DATA_PATH := "res://data/weapons.json"
const PHYSICS_HZ := 60
const DEFAULT_TIMEOUT_SECONDS := 180.0
const DEFAULT_CONCURRENCY := 12
const DEFAULT_OUTPUT_PATH := "res://docs/balance_batch_results.json"

const HEADS := [
	{"id": "falcon_sensor", "tier": "LIGHT"},
	{"id": "raven_sensor", "tier": "MEDIUM"},
	{"id": "bastion_array", "tier": "SUPERHEAVY"},
]
const BODIES := [
	{"id": "swift_core", "tier": "LIGHT"},
	{"id": "kestrel_core", "tier": "MEDIUM"},
	{"id": "bulwark_core", "tier": "SUPERHEAVY"},
]
const LEGS := [
	{"id": "courier_legs", "tier": "LIGHT"},
	{"id": "strider_legs", "tier": "MEDIUM"},
	{"id": "anvil_legs", "tier": "SUPERHEAVY"},
]
const WEAPON_PANELS := [
	{"id": "BALLISTIC", "arm_part_id": "viper_rotary_arm"},
	{"id": "ENERGY", "arm_part_id": "arc_repeater_arm"},
	{"id": "MISSILE", "arm_part_id": "wasp_micro_missile_arm"},
	{"id": "SCATTER", "arm_part_id": "cyclone_flechette_arm"},
]

var weapon_catalog: WeaponCatalog
var part_catalog: MechPartCatalog
var builds: Array[Dictionary] = []
var configs: Array[Dictionary] = []
var active_matches: Array[CombatBatchMatch] = []
var results: Array[Dictionary] = []
var next_config_index := 0
var timeout_seconds := DEFAULT_TIMEOUT_SECONDS
var concurrency := DEFAULT_CONCURRENCY
var maximum_matches := 0
var output_path := DEFAULT_OUTPUT_PATH
var shard_index := 0
var shard_count := 1


func _initialize() -> void:
	Engine.physics_ticks_per_second = PHYSICS_HZ
	call_deferred("_run")


func _run() -> void:
	_parse_arguments()
	if not _load_catalogs() or not _build_experiment():
		quit(1)
		return
	if shard_count > 1:
		var shard_configs: Array[Dictionary] = []
		for config in configs:
			if int(config["match_index"]) % shard_count == shard_index:
				shard_configs.append(config)
		configs = shard_configs
	if maximum_matches > 0:
		configs.resize(mini(maximum_matches, configs.size()))
	print(
		"BALANCE_BATCH start matches=%d builds=%d appearances_per_build=%d timeout=%.1fs concurrency=%d" % [
			configs.size(),
			builds.size(),
			int(configs.size() * 2.0 / builds.size()),
			timeout_seconds,
			concurrency,
		]
	)

	_start_available_matches()
	while not active_matches.is_empty():
		await physics_frame
		for index in range(active_matches.size() - 1, -1, -1):
			var batch_match := active_matches[index]
			if not batch_match.completed:
				continue
			results.append(batch_match.result)
			active_matches.remove_at(index)
			batch_match.free()
			if results.size() % 50 == 0 or results.size() == configs.size():
				print("BALANCE_BATCH progress=%d/%d" % [results.size(), configs.size()])
		_start_available_matches()
	await process_frame

	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["match_index"]) < int(b["match_index"])
	)
	if not _write_results():
		quit(1)
		return
	print("BALANCE_BATCH complete output=%s" % output_path)
	quit(0)


func _parse_arguments() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--timeout="):
			timeout_seconds = maxf(float(argument.get_slice("=", 1)), 1.0)
		elif argument.begins_with("--concurrency="):
			concurrency = maxi(int(argument.get_slice("=", 1)), 1)
		elif argument.begins_with("--max-matches="):
			maximum_matches = maxi(int(argument.get_slice("=", 1)), 0)
		elif argument.begins_with("--output="):
			output_path = argument.get_slice("=", 1)
		elif argument.begins_with("--shard-index="):
			shard_index = maxi(int(argument.get_slice("=", 1)), 0)
		elif argument.begins_with("--shard-count="):
			shard_count = maxi(int(argument.get_slice("=", 1)), 1)
	if shard_index >= shard_count:
		push_error("Shard index must be smaller than shard count")
		shard_index = 0
		shard_count = 1


func _load_catalogs() -> bool:
	weapon_catalog = WeaponCatalog.new()
	if not weapon_catalog.load_file(WEAPONS_DATA_PATH):
		return false
	part_catalog = MechPartCatalog.new()
	return part_catalog.load_file(PARTS_DATA_PATH, weapon_catalog)


func _build_experiment() -> bool:
	for head in HEADS:
		for body in BODIES:
			for legs in LEGS:
				builds.append({
					"id": "%s_%s_%s" % [head["tier"], body["tier"], legs["tier"]],
					"head_id": head["id"],
					"head_tier": head["tier"],
					"body_id": body["id"],
					"body_tier": body["tier"],
					"legs_id": legs["id"],
					"legs_tier": legs["tier"],
				})

	for build in builds:
		for panel in WEAPON_PANELS:
			var loadout := _create_loadout(build, panel)
			if not loadout.is_valid():
				push_error(
					"Invalid experimental loadout %s/%s: %s" % [
						build["id"], panel["id"], ", ".join(loadout.validation_errors())
					]
				)
				return false

	var match_index := 0
	for first_index in builds.size():
		for second_index in range(first_index + 1, builds.size()):
			for panel_index in WEAPON_PANELS.size():
				var first_on_team_zero := panel_index % 2 == 0
				var team_zero_build: Dictionary = builds[first_index if first_on_team_zero else second_index]
				var team_one_build: Dictionary = builds[second_index if first_on_team_zero else first_index]
				configs.append({
					"match_index": match_index,
					"seed": 20260802 + match_index * 104729,
					"panel_id": WEAPON_PANELS[panel_index]["id"],
					"panel_index": panel_index,
					"team_build_ids": [team_zero_build["id"], team_one_build["id"]],
					"team_build_indices": [
						first_index if first_on_team_zero else second_index,
						second_index if first_on_team_zero else first_index,
					],
					"team_ids": [match_index * 2, match_index * 2 + 1],
				})
				match_index += 1
	return true


func _start_available_matches() -> void:
	while active_matches.size() < concurrency and next_config_index < configs.size():
		var config := configs[next_config_index]
		var panel: Dictionary = WEAPON_PANELS[int(config["panel_index"])]
		var team_loadouts: Array = [
			_create_loadout(builds[int(config["team_build_indices"][0])], panel),
			_create_loadout(builds[int(config["team_build_indices"][1])], panel),
		]
		var batch_match := BATCH_MATCH.new() as CombatBatchMatch
		batch_match.setup(config, team_loadouts, PHYSICS_HZ, timeout_seconds)
		var grid_column := int(config["match_index"]) % 40
		var grid_row := int(config["match_index"]) / 40
		batch_match.position = Vector2(grid_column, grid_row) * 12000.0
		get_root().add_child(batch_match)
		active_matches.append(batch_match)
		next_config_index += 1


func _create_loadout(build: Dictionary, panel: Dictionary) -> MechLoadout:
	var loadout := MechLoadout.new()
	loadout.head = part_catalog.parts_by_id.get(build["head_id"]) as MechPartSpec
	loadout.body = part_catalog.parts_by_id.get(build["body_id"]) as MechPartSpec
	loadout.legs = part_catalog.parts_by_id.get(build["legs_id"]) as MechPartSpec
	loadout.left_arm = part_catalog.parts_by_id.get(panel["arm_part_id"]) as MechPartSpec
	loadout.right_arm = part_catalog.parts_by_id.get(panel["arm_part_id"]) as MechPartSpec
	loadout.backpack = null
	return loadout


func _write_results() -> bool:
	var file := FileAccess.open(output_path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write batch results: %s" % output_path)
		return false
	var document := {
		"schema_version": 1,
		"physics_hz": PHYSICS_HZ,
		"timeout_seconds": timeout_seconds,
		"shard_index": shard_index,
		"shard_count": shard_count,
		"arena": [-3000.0, -3000.0, 6000.0, 6000.0],
		"builds": builds,
		"weapon_panels": WEAPON_PANELS,
		"matches": results,
	}
	file.store_string(JSON.stringify(document))
	return true
