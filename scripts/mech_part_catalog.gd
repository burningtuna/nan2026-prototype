class_name MechPartCatalog
extends RefCounted

const WEAPONS_DATA_PATH := "res://data/weapons.json"
const TYPE_BY_NAME := {
	"HEAD": MechPartSpec.PartType.HEAD,
	"BODY": MechPartSpec.PartType.BODY,
	"ARM_EQUIPMENT": MechPartSpec.PartType.ARM_EQUIPMENT,
	"BACKPACK": MechPartSpec.PartType.BACKPACK,
	"LEGS": MechPartSpec.PartType.LEGS,
}
const SLOT_BY_KEY := {
	"head": MechLoadout.MechSlot.HEAD,
	"body": MechLoadout.MechSlot.BODY,
	"left_arm": MechLoadout.MechSlot.LEFT_ARM,
	"right_arm": MechLoadout.MechSlot.RIGHT_ARM,
	"backpack": MechLoadout.MechSlot.BACKPACK,
	"legs": MechLoadout.MechSlot.LEGS,
}
const WIREFRAME_PATHS := {
	MechPartSpec.PartType.HEAD: [
		"res://Sprites/Wireframe/Head-0001.png",
		"res://Sprites/Wireframe/Head-0001.anchors.png",
	],
	MechPartSpec.PartType.BODY: [
		"res://Sprites/Wireframe/Body-0001.png",
		"res://Sprites/Wireframe/Body-0001.anchors.png",
	],
	MechPartSpec.PartType.ARM_EQUIPMENT: [
		"res://Sprites/Wireframe/Arm-Cannon-0001.png",
		"res://Sprites/Wireframe/Arm-Cannon-0001.anchors.png",
	],
	MechPartSpec.PartType.BACKPACK: [
		"res://Sprites/Wireframe/Backpack-Generator-0001.png",
		"res://Sprites/Wireframe/Backpack-Generator-0001.anchors.png",
	],
	MechPartSpec.PartType.LEGS: [
		"res://Sprites/Wireframe/Legs-0001.png",
		"res://Sprites/Wireframe/Legs-0001.anchors.png",
	],
}

var parts_by_type: Dictionary = {}
var parts_by_id: Dictionary = {}
var default_part_ids: Dictionary = {}
var weapon_catalog: WeaponCatalog


func load_file(path: String, shared_weapon_catalog: WeaponCatalog = null) -> bool:
	parts_by_type.clear()
	parts_by_id.clear()
	default_part_ids.clear()
	weapon_catalog = shared_weapon_catalog
	if weapon_catalog == null:
		weapon_catalog = WeaponCatalog.new()
		if not weapon_catalog.load_file(WEAPONS_DATA_PATH):
			return false
	for type in TYPE_BY_NAME.values():
		parts_by_type[type] = []

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open mech part catalog: %s" % path)
		return false

	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	if error != OK:
		push_error("Invalid mech part catalog at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return false
	if not parser.data is Dictionary:
		push_error("Mech part catalog root must be an object: %s" % path)
		return false

	var document: Dictionary = parser.data
	if int(document.get("schema_version", 0)) != 1:
		push_error("Unsupported mech part schema version in %s" % path)
		return false
	default_part_ids = document.get("default_loadout", {}).duplicate()

	var raw_parts: Array = document.get("parts", [])
	for raw_part in raw_parts:
		if not raw_part is Dictionary or not _add_part(raw_part):
			return false
	return true


func create_default_loadout() -> MechLoadout:
	var loadout := MechLoadout.new()
	for key in SLOT_BY_KEY:
		var part_id_value = default_part_ids.get(key)
		if part_id_value == null:
			continue
		var part := parts_by_id.get(str(part_id_value)) as MechPartSpec
		if part == null:
			push_error("Unknown default mech part '%s' for slot '%s'" % [part_id_value, key])
			continue
		loadout.set_part(SLOT_BY_KEY[key], part)
	return loadout


func _add_part(data: Dictionary) -> bool:
	var type_name := str(data.get("type", ""))
	if not TYPE_BY_NAME.has(type_name):
		push_error("Unknown mech part type: %s" % type_name)
		return false
	var part_id_value := str(data.get("id", ""))
	if part_id_value.is_empty() or parts_by_id.has(part_id_value):
		push_error("Missing or duplicate mech part id: %s" % part_id_value)
		return false

	var part_type: MechPartSpec.PartType = TYPE_BY_NAME[type_name]
	var stats: Dictionary = data.get("stats", {})
	var part := MechPartSpec.new()
	part.part_id = part_id_value
	part.part_type = part_type
	part.display_name = str(data.get("display_name", part_id_value))
	part.designation = str(data.get("designation", "--"))
	part.description = str(data.get("description", ""))
	part.art_path = str(data.get("art_path", ""))
	part.anchor_path = str(data.get("anchor_path", ""))
	part.splash_art_path = str(data.get("splash_art_path", ""))
	var tint_value = data.get("preview_tint", Color.WHITE)
	if tint_value is Color:
		part.preview_tint = tint_value
	else:
		part.preview_tint = Color(str(tint_value))
	part.armor = float(stats.get("armor", 0.0))
	part.weight = float(stats.get("weight", 0.0))
	part.power_generation = float(stats.get("power_generation", 0.0))
	part.power_draw = float(stats.get("power_draw", 0.0))
	part.cooling = float(stats.get("cooling", 0.0))
	part.mobility = float(stats.get("mobility", 0.0))
	part.firepower = float(stats.get("firepower", 0.0))
	part.weight_capacity = float(stats.get("weight_capacity", 0.0))
	part.sensor_range = float(stats.get("sensor_range", part.sensor_range))
	part.projectile_track_limit = int(stats.get("projectile_track_limit", part.projectile_track_limit))

	var wireframe_paths: Array = WIREFRAME_PATHS[part_type]
	part.wireframe_art_path = wireframe_paths[0]
	part.wireframe_anchor_path = wireframe_paths[1]

	var weapon_value = data.get("weapon_id")
	if weapon_value != null:
		var weapon_id := str(weapon_value)
		part.weapon = weapon_catalog.weapon(weapon_id)
		if part.weapon == null:
			push_error("Unknown weapon '%s' for mech part '%s'" % [weapon_id, part_id_value])
			return false

	parts_by_id[part_id_value] = part
	var typed_parts: Array = parts_by_type[part_type]
	typed_parts.append(part)
	return true
