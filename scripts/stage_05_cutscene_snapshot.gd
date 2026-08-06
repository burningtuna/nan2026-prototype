class_name Stage05CutsceneSnapshot
extends RefCounted

const SCHEMA_VERSION := 1
const DEFAULT_CAMERA_ZOOM := Vector2(0.35, 0.35)
const DEFAULT_ALLY_POSITIONS := [
	Vector2(-220.0, 120.0),
	Vector2(220.0, 120.0),
	Vector2(-220.0, -120.0),
	Vector2(220.0, -120.0),
]
const ALLY_IDS := ["ALLY-01", "ALLY-02", "ALLY-03", "ALLY-04"]
const DRONE_KINDS := ["HEAD", "LEGS", "ARM"]


static func fallback_snapshot() -> Dictionary:
	var allies: Array[Dictionary] = []
	for index in ALLY_IDS.size():
		allies.append({
			"unit_id": ALLY_IDS[index],
			"position": DEFAULT_ALLY_POSITIONS[index],
		})
	return {
		"schema_version": SCHEMA_VERSION,
		"rescued_ally_count": 4,
		"camera": {
			"position": Vector2.ZERO,
			"zoom": DEFAULT_CAMERA_ZOOM,
		},
		"player": {"position": Vector2.ZERO},
		"allies": allies,
		"enemies": [],
	}


static func normalize(snapshot: Dictionary) -> Dictionary:
	if snapshot.is_empty():
		return fallback_snapshot()
	if int(snapshot.get("schema_version", 0)) != SCHEMA_VERSION:
		return fallback_snapshot()
	var player = snapshot.get("player")
	var allies = snapshot.get("allies")
	var enemies = snapshot.get("enemies")
	if not player is Dictionary or not allies is Array or not enemies is Array:
		return fallback_snapshot()
	var player_position = player.get("position")
	if not _valid_vector(player_position):
		return fallback_snapshot()

	var normalized_allies: Array[Dictionary] = []
	var seen_allies := {}
	for value in allies:
		if not value is Dictionary:
			return fallback_snapshot()
		var unit_id := str(value.get("unit_id", ""))
		var position = value.get("position")
		if unit_id not in ALLY_IDS or seen_allies.has(unit_id) or not _valid_vector(position):
			return fallback_snapshot()
		seen_allies[unit_id] = true
		normalized_allies.append({"unit_id": unit_id, "position": position})

	var normalized_enemies: Array[Dictionary] = []
	var seen_enemies := {}
	for value in enemies:
		if not value is Dictionary:
			return fallback_snapshot()
		var unit_id := str(value.get("unit_id", ""))
		var kind := str(value.get("kind", "")).to_upper()
		var position = value.get("position")
		if unit_id.is_empty() or seen_enemies.has(unit_id) or kind not in DRONE_KINDS or not _valid_vector(position):
			return fallback_snapshot()
		seen_enemies[unit_id] = true
		normalized_enemies.append({
			"unit_id": unit_id,
			"kind": kind,
			"part_id": str(value.get("part_id", "")),
			"position": position,
			"rotation": float(value.get("rotation", 0.0)),
		})

	var camera_position: Vector2 = player_position
	var camera_zoom := DEFAULT_CAMERA_ZOOM
	var camera = snapshot.get("camera", {})
	if camera is Dictionary:
		if _valid_vector(camera.get("position")):
			camera_position = camera["position"]
		if _valid_vector(camera.get("zoom")) and camera["zoom"].x > 0.0 and camera["zoom"].y > 0.0:
			camera_zoom = camera["zoom"]

	return {
		"schema_version": SCHEMA_VERSION,
		"rescued_ally_count": clampi(int(snapshot.get("rescued_ally_count", 0)), 0, 4),
		"camera": {"position": camera_position, "zoom": camera_zoom},
		"player": {"position": player_position},
		"allies": normalized_allies,
		"enemies": normalized_enemies,
	}


static func _valid_vector(value) -> bool:
	return value is Vector2 and is_finite(value.x) and is_finite(value.y)
