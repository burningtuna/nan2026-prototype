class_name WeaponCatalog
extends RefCounted

const FAMILY_BY_NAME := {
	"BALLISTIC": WeaponSpec.WeaponFamily.BALLISTIC,
	"MISSILE": WeaponSpec.WeaponFamily.MISSILE,
	"ENERGY": WeaponSpec.WeaponFamily.ENERGY,
}
const RESOURCE_TYPE_BY_NAME := {
	"NONE": WeaponSpec.ResourceType.NONE,
	"AMMO": WeaponSpec.ResourceType.AMMO,
	"EN": WeaponSpec.ResourceType.EN,
}

var projectiles_by_id: Dictionary = {}
var weapons_by_id: Dictionary = {}


func load_file(path: String) -> bool:
	projectiles_by_id.clear()
	weapons_by_id.clear()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open weapon catalog: %s" % path)
		return false

	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	if error != OK:
		push_error("Invalid weapon catalog at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return false
	if not parser.data is Dictionary:
		push_error("Weapon catalog root must be an object: %s" % path)
		return false

	var document: Dictionary = parser.data
	if int(document.get("schema_version", 0)) != 1:
		push_error("Unsupported weapon catalog schema version in %s" % path)
		return false
	for data in document.get("projectiles", []):
		if not data is Dictionary or not _add_projectile(data):
			return false
	for data in document.get("weapons", []):
		if not data is Dictionary or not _add_weapon(data):
			return false
	return true


func weapon(weapon_id: String) -> WeaponSpec:
	return weapons_by_id.get(weapon_id) as WeaponSpec


func _add_projectile(data: Dictionary) -> bool:
	var projectile_id := str(data.get("id", ""))
	if projectile_id.is_empty() or projectiles_by_id.has(projectile_id):
		push_error("Missing or duplicate projectile id: %s" % projectile_id)
		return false
	var spec := ProjectileSpec.new()
	spec.projectile_scene = load(str(data.get("projectile_scene", ""))) as PackedScene
	if spec.projectile_scene == null:
		push_error("Unable to load projectile scene for '%s'" % projectile_id)
		return false
	spec.speed = float(data.get("speed", spec.speed))
	spec.collision_radius = float(data.get("collision_radius", spec.collision_radius))
	var texture_path := str(data.get("visual_texture", ""))
	if not texture_path.is_empty():
		spec.visual_texture = load(texture_path) as Texture2D
		if spec.visual_texture == null:
			push_error("Unable to load projectile texture for '%s': %s" % [projectile_id, texture_path])
			return false
	spec.visual_scale = float(data.get("visual_scale", spec.visual_scale))
	spec.trail_width_multiplier = float(data.get("trail_width_multiplier", spec.trail_width_multiplier))
	spec.trail_lifetime_multiplier = float(
		data.get("trail_lifetime_multiplier", spec.trail_lifetime_multiplier)
	)
	spec.damage = float(data.get("damage", spec.damage))
	spec.damage_type = StringName(str(data.get("damage_type", spec.damage_type)))
	spec.penetration = float(data.get("penetration", spec.penetration))
	spec.splash_radius = float(data.get("splash_radius", spec.splash_radius))
	spec.color = Color(str(data.get("color", spec.color.to_html(true))))
	spec.lifetime = float(data.get("lifetime", spec.lifetime))
	spec.homing = bool(data.get("homing", spec.homing))
	spec.homing_turn_speed_degrees = float(
		data.get("homing_turn_speed_degrees", spec.homing_turn_speed_degrees)
	)
	projectiles_by_id[projectile_id] = spec
	return true


func _add_weapon(data: Dictionary) -> bool:
	var weapon_id := str(data.get("id", ""))
	if weapon_id.is_empty() or weapons_by_id.has(weapon_id):
		push_error("Missing or duplicate weapon id: %s" % weapon_id)
		return false
	var family_name := str(data.get("weapon_family", ""))
	var resource_name := str(data.get("resource_type", ""))
	if not FAMILY_BY_NAME.has(family_name) or not RESOURCE_TYPE_BY_NAME.has(resource_name):
		push_error("Invalid weapon family or resource type for '%s'" % weapon_id)
		return false
	var projectile_id := str(data.get("projectile_id", ""))
	var projectile := projectiles_by_id.get(projectile_id) as ProjectileSpec
	if projectile == null:
		push_error("Unknown projectile '%s' for weapon '%s'" % [projectile_id, weapon_id])
		return false

	var spec := WeaponSpec.new()
	spec.display_name = str(data.get("display_name", weapon_id))
	spec.weapon_family = FAMILY_BY_NAME[family_name]
	spec.fire_effect_id = StringName(str(data.get("fire_effect_id", spec.fire_effect_id)))
	spec.fire_rate = float(data.get("fire_rate", spec.fire_rate))
	spec.resource_type = RESOURCE_TYPE_BY_NAME[resource_name]
	spec.resource_cost = float(data.get("resource_cost", spec.resource_cost))
	spec.heat_cost = float(data.get("heat_cost", spec.heat_cost))
	spec.magazine_capacity = int(data.get("magazine_capacity", spec.magazine_capacity))
	spec.reload_duration = float(data.get("reload_duration", spec.reload_duration))
	spec.effective_range = float(data.get("effective_range", spec.effective_range))
	spec.max_range = float(data.get("max_range", spec.max_range))
	spec.traverse_limit_degrees = float(data.get("traverse_limit_degrees", spec.traverse_limit_degrees))
	spec.launch_offset_degrees = float(data.get("launch_offset_degrees", spec.launch_offset_degrees))
	spec.projectiles_per_shot = int(data.get("projectiles_per_shot", spec.projectiles_per_shot))
	spec.volley_arc_degrees = float(data.get("volley_arc_degrees", spec.volley_arc_degrees))
	spec.base_spread_degrees = float(data.get("base_spread_degrees", spec.base_spread_degrees))
	spec.max_spread_degrees = float(data.get("max_spread_degrees", spec.max_spread_degrees))
	spec.spread_curve = float(data.get("spread_curve", spec.spread_curve))
	spec.visual_recoil_distance = float(data.get("visual_recoil_distance", spec.visual_recoil_distance))
	spec.visual_recoil_recovery = float(data.get("visual_recoil_recovery", spec.visual_recoil_recovery))
	spec.visual_recoil_limit = float(data.get("visual_recoil_limit", spec.visual_recoil_limit))
	spec.muzzle_flash_color = Color(str(data.get("muzzle_flash_color", spec.muzzle_flash_color.to_html(true))))
	spec.muzzle_flash_duration = float(data.get("muzzle_flash_duration", spec.muzzle_flash_duration))
	spec.preparation_time = float(data.get("preparation_time", spec.preparation_time))
	spec.preparation_move_speed_multiplier = float(
		data.get("preparation_move_speed_multiplier", spec.preparation_move_speed_multiplier)
	)
	spec.preparation_turn_speed_multiplier = float(
		data.get("preparation_turn_speed_multiplier", spec.preparation_turn_speed_multiplier)
	)
	spec.projectile = projectile
	weapons_by_id[weapon_id] = spec
	return true
