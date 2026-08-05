class_name DroneAgent
extends AiMechAgent

enum DroneKind {
	HEAD,
	LEGS,
	ARM,
}

const DRONE_HITBOX := preload("res://scripts/part_hitbox.gd")
const ARM_DAMAGE_MULTIPLIER := 1.0 / 3.0
const ARM_FIRE_RATE_MULTIPLIER := 1.0 / 5.0

var drone_kind := DroneKind.HEAD
var drone_part: MechPartSpec
var drone_part_name: StringName = &"Head"
var contact_damage := 25.0
var drone_speed := 110.0
var defeated_once := false
var weapon_runtime: WeaponRuntime
var arm_projectile_spec: ProjectileSpec


func setup_drone(
	part: MechPartSpec,
	kind: DroneKind,
	shot_parent: Node2D,
	movement_arena: Rect2,
	target: AiMechAgent,
	sequence: int
) -> void:
	drone_part = part
	drone_kind = kind
	projectile_layer = shot_parent
	arena = movement_arena
	team_id = 1
	unit_class = UnitClass.DRONE
	opponent = target
	rng.seed = 70000 + sequence * 3571
	name = "DRONE-%s-%03d" % [DroneKind.keys()[kind], sequence]
	scale = Vector2.ONE * 4.0
	match kind:
		DroneKind.HEAD:
			drone_part_name = &"Head"
			drone_speed = 110.0
			contact_damage = 25.0
		DroneKind.LEGS:
			drone_part_name = &"Legs"
			drone_speed = 185.0
			contact_damage = 40.0
		DroneKind.ARM:
			drone_part_name = &"LeftArm"
			drone_speed = 85.0
			contact_damage = 0.0
	var maximum := maxf(part.armor, 0.0) * 0.1
	part_max_durability = {drone_part_name: maximum}
	part_durability = {drone_part_name: maximum}


func _ready() -> void:
	add_to_group(&"mech_combatants")
	var texture := load(drone_part.art_path) as Texture2D
	var sprite := Sprite2D.new()
	sprite.name = "DroneSprite"
	sprite.texture = texture
	sprite.modulate = drone_part.preview_tint
	sprite.z_index = 3
	add_child(sprite)
	var hitbox := DRONE_HITBOX.new() as PartHitbox
	hitbox.setup(self, drone_part_name, texture, 1)
	sprite.add_child(hitbox)
	_build_contact_detector()
	if drone_kind == DroneKind.ARM and drone_part.weapon != null:
		_build_arm_weapon(sprite)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_defeated() or not is_instance_valid(opponent) or opponent.is_defeated():
		velocity = Vector2.ZERO
		return
	var target_vector := opponent.global_position - global_position
	if target_vector.length_squared() <= 0.001:
		return
	var target_direction := target_vector.normalized()
	if drone_kind == DroneKind.ARM:
		_update_arm_drone(delta, target_vector, target_direction)
	else:
		velocity = velocity.move_toward(target_direction * drone_speed, 300.0 * delta)
		rotation = rotate_toward(rotation, target_direction.angle() + PI * 0.5, 3.5 * delta)
		global_position += velocity * delta
	global_position = global_position.clamp(arena.position, arena.end)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(1.5, 2.0), 8.0, Color(0.01, 0.02, 0.025, 0.42))


func _update_arm_drone(delta: float, target_vector: Vector2, target_direction: Vector2) -> void:
	rotation = rotate_toward(rotation, target_direction.angle(), 2.8 * delta)
	var desired_range := maxf(drone_part.weapon.effective_range * 0.7, 240.0)
	var movement := Vector2.ZERO
	if target_vector.length() > desired_range:
		movement = target_direction
	elif target_vector.length() < desired_range * 0.55:
		movement = -target_direction
	velocity = velocity.move_toward(movement * drone_speed, 220.0 * delta)
	global_position += velocity * delta
	if weapon_runtime == null:
		return
	weapon_runtime.tick(delta)
	if target_vector.length() <= drone_part.weapon.max_range and weapon_runtime.can_fire():
		_fire_arm_weapon(target_direction)


func _build_contact_detector() -> void:
	var detector := Area2D.new()
	detector.name = "ContactDetector"
	detector.collision_layer = 0
	detector.collision_mask = 2
	detector.monitoring = drone_kind != DroneKind.ARM
	detector.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	detector.add_child(shape)
	detector.area_entered.connect(_on_contact_area_entered)
	add_child(detector)


func _build_arm_weapon(sprite: Sprite2D) -> void:
	var anchor_map := SpriteAnchorMap.load_map(drone_part.anchor_path)
	var muzzle_positions := SpriteAnchorMap.many(anchor_map, &"muzzle")
	if muzzle_positions.is_empty():
		push_error("Arm drone part '%s' requires a muzzle anchor" % drone_part.part_id)
		return
	var muzzles: Array[Marker2D] = []
	for index in muzzle_positions.size():
		var muzzle := Marker2D.new()
		muzzle.name = "Muzzle%d" % (index + 1)
		muzzle.position = muzzle_positions[index]
		add_child(muzzle)
		muzzles.append(muzzle)
	weapon_runtime = WeaponRuntime.new()
	weapon_runtime.setup(
		drone_part.weapon,
		sprite,
		muzzles,
		drone_part_name,
		ARM_FIRE_RATE_MULTIPLIER
	)
	arm_projectile_spec = drone_part.weapon.projectile.duplicate() as ProjectileSpec
	arm_projectile_spec.damage *= ARM_DAMAGE_MULTIPLIER
	weapons.append(weapon_runtime)


func _fire_arm_weapon(target_direction: Vector2) -> void:
	var muzzle := weapon_runtime.fire()
	if muzzle == null:
		return
	var projectile_spec := arm_projectile_spec
	for projectile_index in drone_part.weapon.projectiles_per_shot:
		var arc_ratio := (
			0.0
			if drone_part.weapon.projectiles_per_shot <= 1
			else float(projectile_index) / float(drone_part.weapon.projectiles_per_shot - 1) - 0.5
		)
		var spread := arc_ratio * drone_part.weapon.volley_arc_degrees
		var launch_direction := target_direction.rotated(deg_to_rad(spread))
		var projectile := projectile_spec.projectile_scene.instantiate() as BallisticProjectile
		projectile.configure(
			projectile_spec,
			launch_direction,
			drone_part.weapon.max_range,
			self,
			drone_part_name,
			rng.randi(),
			absf(spread),
			drone_part.weapon.weapon_family,
			opponent,
			opponent.global_position,
			opponent.velocity,
			opponent.is_dashing(),
			true,
			drone_part.weapon.projectiles_per_shot > 1
		)
		projectile_layer.add_child(projectile)
		projectile.global_position = muzzle.global_position
	weapon_fired.emit(weapon_runtime)


func _on_contact_area_entered(area: Area2D) -> void:
	if is_defeated() or area.get_script() != PART_HITBOX or area.mech == self:
		return
	if is_ally_of(area.mech):
		return
	var impact_direction := velocity.normalized()
	if impact_direction.is_zero_approx():
		impact_direction = (area.mech.global_position - global_position).normalized()
	area.mech.register_hit(area.part_name, impact_direction, contact_damage)
	_destroy_drone()


func register_hit(part_name: StringName, incoming_direction: Vector2, damage := 0.0) -> StringName:
	last_hit_part = drone_part_name
	last_hit_aspect = &"FRONT"
	part_durability[drone_part_name] = maxf(
		float(part_durability.get(drone_part_name, 0.0)) - damage,
		0.0
	)
	hit_received.emit(drone_part_name, last_hit_aspect)
	if is_defeated():
		_destroy_drone()
	return last_hit_aspect


func is_defeated() -> bool:
	return float(part_durability.get(drone_part_name, 1.0)) <= 0.0


func _part_durability_snapshot() -> Dictionary:
	return {drone_part_name: part_durability_ratio(drone_part_name)}


func _destroy_drone() -> void:
	if defeated_once:
		return
	defeated_once = true
	part_durability[drone_part_name] = 0.0
	velocity = Vector2.ZERO
	for node in find_children("*", "Area2D", true, false):
		node.set_deferred("monitoring", false)
		node.set_deferred("monitorable", false)
		node.set_deferred("collision_layer", 0)
		node.set_deferred("collision_mask", 0)
	part_destroyed.emit(drone_part_name)
	defeated.emit()
	visible = false
