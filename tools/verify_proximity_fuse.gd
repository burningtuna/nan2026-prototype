extends SceneTree

class TestMech extends Node2D:
	var team_id := 0
	var damage_by_part := {}
	var missile_hits := 0

	func is_ally_of(other: Node) -> bool:
		var other_team = other.get("team_id")
		return other_team != null and int(other_team) == team_id

	func register_hit(part_name: StringName, _direction: Vector2, damage: float) -> void:
		damage_by_part[part_name] = damage_by_part.get(part_name, 0.0) + damage

	func register_landed_hit(family: WeaponSpec.WeaponFamily) -> void:
		if family == WeaponSpec.WeaponFamily.MISSILE:
			missile_hits += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var weapon_catalog := WeaponCatalog.new()
	assert(weapon_catalog.load_file("res://data/weapons.json"))
	var missile := weapon_catalog.weapon("weapon_missile_rapid").projectile
	assert(missile.proximity_fuse_radius == 8.0)
	assert(missile.splash_radius == 48.0)

	var source := TestMech.new()
	source.team_id = 0
	var target := _target(1, Vector2.ZERO, {&"Body": Vector2.ZERO, &"Head": Vector2(10.0, 0.0)})
	var nearby := _target(1, Vector2(35.0, 0.0), {&"Legs": Vector2.ZERO})
	var edge_overlap := _target(1, Vector2(52.0, 0.0), {&"Body": Vector2.ZERO})
	var distant := _target(1, Vector2(70.0, 0.0), {&"Body": Vector2.ZERO})
	var ally := _target(0, Vector2(20.0, 0.0), {&"Body": Vector2.ZERO})
	get_root().add_child(source)
	get_root().add_child(target)
	get_root().add_child(nearby)
	get_root().add_child(edge_overlap)
	get_root().add_child(distant)
	get_root().add_child(ally)
	for mech in [source, target, nearby, edge_overlap, distant, ally]:
		mech.add_to_group(&"mech_combatants")
	await physics_frame

	var outside := _projectile(missile, source, target)
	get_root().add_child(outside)
	assert(not outside._check_proximity_fuse(Vector2(-20.0, 9.0), Vector2(20.0, 9.0)))
	assert(target.damage_by_part.is_empty())
	outside.free()

	var fused := _projectile(missile, source, target)
	get_root().add_child(fused)
	assert(fused._check_proximity_fuse(Vector2(-20.0, 7.0), Vector2(20.0, 7.0)))
	assert(target.damage_by_part.size() == 2)
	assert(is_equal_approx(target.damage_by_part[&"Body"], missile.damage))
	assert(is_equal_approx(target.damage_by_part[&"Head"], missile.damage))
	assert(is_equal_approx(nearby.damage_by_part[&"Legs"], missile.damage))
	assert(is_equal_approx(edge_overlap.damage_by_part[&"Body"], missile.damage))
	assert(distant.damage_by_part.is_empty())
	assert(ally.damage_by_part.is_empty())
	assert(source.missile_hits == 1)

	print("PROXIMITY_FUSE_CHECK passed")
	quit(0)


func _projectile(
	spec: ProjectileSpec,
	source: TestMech,
	target: TestMech
) -> BallisticProjectile:
	var projectile := BallisticProjectile.new()
	projectile.spec = spec
	projectile.source_mech = source
	projectile.source_team_id = source.team_id
	projectile.homing_target = target
	projectile.weapon_family = WeaponSpec.WeaponFamily.MISSILE
	projectile.visuals_enabled = false
	return projectile


func _target(team_id: int, target_position: Vector2, parts: Dictionary) -> TestMech:
	var target := TestMech.new()
	target.team_id = team_id
	target.position = target_position
	for part_name in parts:
		var hitbox := PartHitbox.new()
		hitbox.mech = target
		hitbox.part_name = part_name
		hitbox.position = parts[part_name]
		hitbox.collision_layer = 2
		hitbox.collision_mask = 0
		hitbox.monitoring = false
		hitbox.monitorable = true
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(10.0, 10.0)
		shape.shape = rectangle
		hitbox.add_child(shape)
		target.add_child(hitbox)
	return target
