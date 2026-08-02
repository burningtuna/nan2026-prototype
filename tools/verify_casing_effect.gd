extends SceneTree

const VAPOR_EFFECT := preload("res://scripts/vapor_effect.gd")


func _initialize() -> void:
	var weapon_catalog := WeaponCatalog.new()
	assert(weapon_catalog.load_file("res://data/weapons.json"))
	var part_catalog := MechPartCatalog.new()
	assert(part_catalog.load_file("res://data/mech_parts.json", weapon_catalog))
	_verify_required_anchors(part_catalog)
	_verify_mirrored_arm_eject(weapon_catalog)
	_verify_backpack_art(part_catalog)
	_verify_casing_motion(weapon_catalog)
	_verify_vapor_motion(weapon_catalog)
	_verify_spawn_filter(weapon_catalog)
	print("CASING_EFFECT_CHECK passed")
	quit(0)


func _verify_required_anchors(part_catalog: MechPartCatalog) -> void:
	for part_value in part_catalog.parts_by_id.values():
		var part := part_value as MechPartSpec
		if part.weapon == null or part.weapon.weapon_family == WeaponSpec.WeaponFamily.MISSILE:
			continue
		var anchor_map := SpriteAnchorMap.load_map(part.anchor_path)
		assert(SpriteAnchorMap.many(anchor_map, &"casing_eject").size() == 1)


func _verify_mirrored_arm_eject(weapon_catalog: WeaponCatalog) -> void:
	var agent := AiMechAgent.new()
	var parent := Node2D.new()
	var anchor_map := {
		"anchors": {&"casing_eject": [Vector2(10.0, 4.0)]},
	}
	var pivot := Vector2(4.0, 6.0)
	var spec := weapon_catalog.weapon("test_cannon")
	var left := agent._attach_casing_eject(parent, anchor_map, pivot, spec)
	var right := agent._attach_casing_eject(parent, anchor_map, pivot, spec, true)
	assert(left.position == Vector2(6.0, -2.0))
	assert(right.position == Vector2(6.0, 2.0))
	parent.free()
	agent.free()


func _verify_backpack_art(part_catalog: MechPartCatalog) -> void:
	var expected_art := {
		"siege_rail_backpack": "res://Sprites/Backpack-Rail-0001.svg",
		"nova_beam_backpack": "res://Sprites/Backpack-Energy-0001.svg",
		"longbow_cruise_backpack": "res://Sprites/Backpack-Missile-0001.svg",
		"avalanche_flak_backpack": "res://Sprites/Backpack-Flak-0001.svg",
	}
	for part_id in expected_art:
		var part := part_catalog.parts_by_id[part_id] as MechPartSpec
		assert(part.art_path == expected_art[part_id])
		assert((load(part.art_path) as Texture2D).get_size() == Vector2(24.0, 12.0))


func _verify_casing_motion(weapon_catalog: WeaponCatalog) -> void:
	var scatter := weapon_catalog.weapon("weapon_scatter_heavy")
	var casing := CasingEffect.new()
	get_root().add_child(casing)
	casing.setup(scatter.projectile, scatter.projectiles_per_shot, Vector2.RIGHT, 1234)
	assert(absf(casing.rotation) <= deg_to_rad(30.0))
	assert(is_equal_approx(casing.casing_size.x, scatter.projectile.visual_scale * 2.0))
	assert(is_equal_approx(
		casing.casing_size.y,
		scatter.projectile.visual_scale * scatter.projectiles_per_shot / 3.0
	))
	var initial_rotation := casing.rotation
	var initial_shadow_distance := casing.shadow_offset.length()
	casing._process(0.5)
	assert(is_equal_approx(casing.rotation, initial_rotation))
	assert(casing.shadow_offset.length() < initial_shadow_distance)
	assert(casing.elapsed < CasingEffect.LIFETIME)
	casing._process(0.5)
	assert(casing.is_queued_for_deletion())


func _verify_vapor_motion(weapon_catalog: WeaponCatalog) -> void:
	var energy := weapon_catalog.weapon("weapon_energy_standard")
	var vapor := VAPOR_EFFECT.new()
	get_root().add_child(vapor)
	vapor.setup(energy.projectile, Vector2.RIGHT, 1234)
	assert(absf(vapor.velocity.angle()) <= deg_to_rad(30.0))
	var initial_speed := vapor.velocity.length()
	vapor._process(VAPOR_EFFECT.LIFETIME * 0.5)
	assert(vapor.velocity.length() < initial_speed)
	vapor._process(VAPOR_EFFECT.LIFETIME * 0.5)
	assert(vapor.is_queued_for_deletion())


func _verify_spawn_filter(weapon_catalog: WeaponCatalog) -> void:
	var projectile_layer := Node2D.new()
	get_root().add_child(projectile_layer)
	var agent := AiMechAgent.new()
	agent.projectile_layer = projectile_layer
	var eject := Marker2D.new()
	projectile_layer.add_child(eject)
	var ballistic := _runtime(weapon_catalog.weapon("test_cannon"), eject)
	agent._spawn_casing(ballistic, Vector2.RIGHT, 7)
	assert(projectile_layer.get_child_count() == 2)
	assert(projectile_layer.get_child(1) is CasingEffect)
	var missile := _runtime(weapon_catalog.weapon("test_missile"), null)
	agent._spawn_casing(missile, Vector2.RIGHT, 7)
	assert(projectile_layer.get_child_count() == 2)
	agent.combat_visuals_enabled = false
	agent._spawn_casing(ballistic, Vector2.RIGHT, 7)
	assert(projectile_layer.get_child_count() == 2)
	agent.combat_visuals_enabled = true
	var energy := _runtime(weapon_catalog.weapon("test_energy_cannon"), eject)
	agent._spawn_vapor(energy, Vector2.RIGHT, 7)
	assert(projectile_layer.get_child_count() == 3)
	agent._spawn_casing(energy, Vector2.RIGHT, 7)
	assert(projectile_layer.get_child_count() == 3)
	ballistic.visual.free()
	missile.visual.free()
	energy.visual.free()
	agent.free()
	projectile_layer.free()


func _runtime(spec: WeaponSpec, eject: Marker2D) -> WeaponRuntime:
	var runtime := WeaponRuntime.new()
	runtime.setup(spec, Sprite2D.new(), [], &"Test", 1.0, eject)
	return runtime
