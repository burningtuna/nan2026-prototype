extends SceneTree


class TestMech extends Node2D:
	var team_id := 0
	var damage_by_part: Dictionary = {}
	var landed_hits := 0

	func is_ally_of(other: Node) -> bool:
		var other_team = other.get("team_id")
		return other_team != null and int(other_team) == team_id

	func register_hit(part_name: StringName, _direction: Vector2, damage: float) -> void:
		damage_by_part[part_name] = float(damage_by_part.get(part_name, 0.0)) + damage

	func register_landed_hit(_family: WeaponSpec.WeaponFamily) -> void:
		landed_hits += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var projectile_spec := ProjectileSpec.new()
	projectile_spec.damage = 12.0
	projectile_spec.homing = false

	var weapon_spec := WeaponSpec.new()
	weapon_spec.weapon_family = WeaponSpec.WeaponFamily.BALLISTIC
	weapon_spec.max_range = 500.0
	weapon_spec.preparation_time = 2.0
	weapon_spec.preparation_move_speed_multiplier = 0.25
	weapon_spec.projectile = projectile_spec

	var visual := Sprite2D.new()
	var muzzle := Marker2D.new()
	var weapon := WeaponRuntime.new()
	weapon.setup(weapon_spec, visual, [muzzle], &"LeftArm", 1.0)
	var agent := AiMechAgent.new()
	assert(is_equal_approx(agent.effective_weapon_preparation_time(weapon), 2.0))
	assert(is_equal_approx(agent.effective_preparation_move_speed_multiplier(weapon), 0.25))
	assert(not agent._endless_projectile_penetrates_targets(weapon))

	agent.ignore_weapon_preparation = true
	agent.ignore_preparation_move_speed_penalty = true
	agent.endless_non_missile_penetration_enabled = true
	assert(is_zero_approx(agent.effective_weapon_preparation_time(weapon)))
	assert(is_equal_approx(agent.effective_preparation_move_speed_multiplier(weapon), 1.0))
	assert(agent._endless_projectile_penetrates_targets(weapon))
	assert(is_equal_approx(weapon_spec.preparation_time, 2.0))
	assert(is_equal_approx(weapon_spec.preparation_move_speed_multiplier, 0.25))

	weapon_spec.max_range = 499.0
	assert(not agent._endless_projectile_penetrates_targets(weapon))
	weapon_spec.max_range = 500.0
	weapon_spec.weapon_family = WeaponSpec.WeaponFamily.ENERGY
	assert(agent._endless_projectile_penetrates_targets(weapon))
	weapon_spec.weapon_family = WeaponSpec.WeaponFamily.MISSILE
	assert(not agent._endless_projectile_penetrates_targets(weapon))
	weapon_spec.weapon_family = WeaponSpec.WeaponFamily.BALLISTIC
	projectile_spec.homing = true
	assert(not agent._endless_projectile_penetrates_targets(weapon))
	projectile_spec.homing = false

	var source := TestMech.new()
	source.team_id = 0
	get_root().add_child(source)
	var first := _target(1, Vector2(20.0, 0.0), [&"Body", &"Head"])
	var second := _target(1, Vector2(40.0, 0.0), [&"Body"])
	var third := _target(1, Vector2(60.0, 0.0), [&"Body"])
	get_root().add_child(first)
	get_root().add_child(second)
	get_root().add_child(third)
	await physics_frame

	var projectile := BallisticProjectile.new()
	projectile.spec = projectile_spec
	projectile.source_mech = source
	projectile.source_team_id = source.team_id
	projectile.weapon_family = WeaponSpec.WeaponFamily.BALLISTIC
	projectile.penetrates_targets = true
	projectile.visuals_enabled = false
	get_root().add_child(projectile)
	assert(not projectile._check_swept_hit(Vector2.ZERO, Vector2(100.0, 0.0)))
	assert(first.damage_by_part.size() == 1)
	assert(second.damage_by_part.size() == 1)
	assert(third.damage_by_part.size() == 1)
	assert(source.landed_hits == 3)
	assert(projectile.penetrated_mech_ids.size() == 3)

	projectile.free()
	first.free()
	second.free()
	third.free()
	source.free()
	agent.free()
	visual.free()
	muzzle.free()
	print("ENDLESS_BALANCE_RULES_CHECK passed")
	quit(0)


func _target(team: int, target_position: Vector2, parts: Array[StringName]) -> TestMech:
	var target := TestMech.new()
	target.team_id = team
	target.position = target_position
	for part_name in parts:
		var hitbox := PartHitbox.new()
		hitbox.mech = target
		hitbox.part_name = part_name
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
