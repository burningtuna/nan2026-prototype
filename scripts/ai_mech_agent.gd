class_name AiMechAgent
extends Node2D

signal hit_received(part_name: StringName, aspect: StringName)
signal hit_landed(weapon_family: WeaponSpec.WeaponFamily)
signal weapon_fired(weapon: WeaponRuntime)

enum MovementType {
	AGGRESSIVE,
	RANGE_KEEPER,
}

const AnchorMap := preload("res://scripts/sprite_anchor_map.gd")
const MUZZLE_FLASH_SCENE := preload("res://scenes/muzzle_flash.tscn")
const PART_HITBOX := preload("res://scripts/part_hitbox.gd")

const BODY_ART := "res://Sprites/Body-0001.png"
const BODY_ANCHORS := "res://Sprites/Body-0001.anchors.png"
const HEAD_ART := "res://Sprites/Head-0001.png"
const HEAD_ANCHORS := "res://Sprites/Head-0001.anchors.png"
const LEGS_ART := "res://Sprites/Legs-0001.png"
const LEGS_ANCHORS := "res://Sprites/Legs-0001.anchors.png"
const ARM_ART := "res://Sprites/Arm-Cannon-0001.png"
const ARM_ANCHORS := "res://Sprites/Arm-Cannon-0001.anchors.png"
const BACKPACK_ART := "res://Sprites/Backpack-Generator-0001.png"
const BACKPACK_ANCHORS := "res://Sprites/Backpack-Generator-0001.anchors.png"
const BOOST_FRAMES := [
	"res://Sprites/Boost-0001.png",
	"res://Sprites/Boost-0002.png",
	"res://Sprites/Boost-0003.png",
]

@export var cruise_speed := 70.0
@export var acceleration := 180.0
@export var upper_turn_speed_degrees := 67.5
@export var head_traverse_limit_degrees := 30.0
@export var arm_visual_turn_speed_degrees := 45.0
@export var linked_fire_stagger := 0.12
@export var dash_speed := 140.0
@export var dash_duration := 0.5
@export var dash_cooldown := 1.0
@export var fire_rate_multiplier := 1.0
@export var weapon_range_multiplier := 1.0
@export var movement_type := MovementType.AGGRESSIVE
@export var preferred_range := 2000.0
@export var evasion_range := 1500.0
@export var player_controlled := false
@export var team_id := 0

var opponent: AiMechAgent
var opponents: Array[AiMechAgent] = []
var velocity := Vector2.ZERO
var shot_count := 0
var projectile_count := 0
var dash_count := 0
var homing_adjustment_count := 0
var hitbox_count := 0
var hit_count := 0
var last_hit_part: StringName = &""
var last_hit_aspect: StringName = &""
var aspect_hit_counts := {
	&"FRONT": 0,
	&"SIDE": 0,
	&"REAR": 0,
}
var landed_hits := {
	WeaponSpec.WeaponFamily.BALLISTIC: 0,
	WeaponSpec.WeaponFamily.MISSILE: 0,
	WeaponSpec.WeaponFamily.ENERGY: 0,
}
var fired_shots := {
	WeaponSpec.WeaponFamily.BALLISTIC: 0,
	WeaponSpec.WeaponFamily.MISSILE: 0,
	WeaponSpec.WeaponFamily.ENERGY: 0,
}
var missile_approaches := {
	&"LEFT": 0,
	&"RIGHT": 0,
	&"REAR": 0,
}

var arena := Rect2(-360.0, -220.0, 720.0, 440.0)
var projectile_layer: Node2D
var lower_body: Node2D
var upper_body: Node2D
var head_aim_node: Node2D
var arm_aim_nodes: Array[Node2D] = []
var boost_sprites: Array[AnimatedSprite2D] = []
var weapons: Array[WeaponRuntime] = []
var weapon_aim_valid: Array[bool] = []
var movement_direction := Vector2.ZERO
var maneuver_side := 1.0
var evading := false
var evasion_count := 0
var reload_evasion_count := 0
var reload_evasion_active := false
var direction_time_remaining := 0.0
var dash_decision_time_remaining := 0.0
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0
var dash_direction := Vector2.ZERO
var linked_fire_cooldown := 0.0
var next_weapon_index := 0
var rng := RandomNumberGenerator.new()
var weapon_specs: Array[WeaponSpec] = []
var mech_loadout: MechLoadout
var preparing_weapon_index := -1
var preparation_time_remaining := 0.0
var preparation_started_count := 0
var preparation_completed_count := 0
var preparation_cancelled_count := 0
var preparation_prediction_blocked_count := 0
var aim_blocked_count := 0
var range_blocked_count := 0
var manual_aim_position := Vector2.ZERO


func setup(
	agent_name: String,
	shot_parent: Node2D,
	movement_arena: Rect2,
	random_seed: int,
	team_color: Color,
	loadout: Array[WeaponSpec],
	configured_loadout: MechLoadout = null
) -> void:
	name = agent_name
	projectile_layer = shot_parent
	arena = movement_arena
	rng.seed = random_seed
	modulate = team_color
	scale = Vector2.ONE * 4.0
	weapon_specs = loadout
	mech_loadout = configured_loadout.copy() if configured_loadout != null else null


func set_opponent(target: AiMechAgent) -> void:
	opponent = target
	opponents.clear()
	if is_instance_valid(target):
		opponents.append(target)
	_choose_direction()


func set_opponents(targets: Array) -> void:
	opponents.clear()
	for target in targets:
		var mech := target as AiMechAgent
		if is_instance_valid(mech) and mech != self:
			opponents.append(mech)
	opponent = opponents[0] if not opponents.is_empty() else null
	_choose_direction()


func is_ally_of(other: Node) -> bool:
	var other_mech := other as AiMechAgent
	return is_instance_valid(other_mech) and team_id == other_mech.team_id


func ammo_remaining() -> int:
	var total := 0
	for weapon in weapons:
		total += weapon.ammo
	return total


func register_hit(part_name: StringName, incoming_direction: Vector2) -> StringName:
	hit_count += 1
	last_hit_part = part_name
	last_hit_aspect = _classify_hit_aspect(incoming_direction)
	aspect_hit_counts[last_hit_aspect] = aspect_hit_counts.get(last_hit_aspect, 0) + 1
	hit_received.emit(last_hit_part, last_hit_aspect)
	return last_hit_aspect


func torso_forward() -> Vector2:
	if upper_body == null:
		return Vector2.UP
	return -upper_body.global_transform.y.normalized()


func aspect_hits(aspect: StringName) -> int:
	return aspect_hit_counts.get(aspect, 0)


func _classify_hit_aspect(incoming_direction: Vector2) -> StringName:
	var direction_to_attacker := -incoming_direction.normalized()
	var forward_dot := torso_forward().dot(direction_to_attacker)
	if forward_dot >= cos(PI * 0.25):
		return &"FRONT"
	if forward_dot <= -cos(PI * 0.25):
		return &"REAR"
	return &"SIDE"


func register_landed_hit(family: WeaponSpec.WeaponFamily) -> void:
	landed_hits[family] = landed_hits.get(family, 0) + 1
	hit_landed.emit(family)


func landed_hits_for(family: WeaponSpec.WeaponFamily) -> int:
	return landed_hits.get(family, 0)


func fired_shots_for(family: WeaponSpec.WeaponFamily) -> int:
	return fired_shots.get(family, 0)


func register_homing_adjustment() -> void:
	homing_adjustment_count += 1


func register_missile_approach(approach: StringName) -> void:
	missile_approaches[approach] = missile_approaches.get(approach, 0) + 1


func is_preparing_attack() -> bool:
	return preparing_weapon_index >= 0


func preparation_label() -> String:
	if preparing_weapon_index < 0:
		return "--"
	return "%s %.1f" % [weapons[preparing_weapon_index].spec.display_name, preparation_time_remaining]


func has_fireable_weapon() -> bool:
	for weapon_index in weapons.size():
		if _can_execute_weapon(weapon_index):
			return true
	return false


func maximum_weapon_range() -> float:
	var maximum_range := 0.0
	for weapon in weapons:
		maximum_range = maxf(maximum_range, weapon.spec.max_range * weapon_range_multiplier)
	return maximum_range


func maximum_weapon_traverse_limit_degrees() -> float:
	var maximum_limit := 0.0
	for weapon in weapons:
		maximum_limit = maxf(maximum_limit, weapon.spec.traverse_limit_degrees)
	return maximum_limit


func is_reloading_ballistic() -> bool:
	for weapon in weapons:
		if weapon.spec.weapon_family == WeaponSpec.WeaponFamily.BALLISTIC and weapon.is_reloading():
			return true
	return false


func reload_count_for(family: WeaponSpec.WeaponFamily) -> int:
	var count := 0
	for weapon in weapons:
		if weapon.spec.weapon_family == family:
			count += weapon.reload_count
	return count


func reload_completed_count_for(family: WeaponSpec.WeaponFamily) -> int:
	var count := 0
	for weapon in weapons:
		if weapon.spec.weapon_family == family:
			count += weapon.reload_completed_count
	return count


func _ready() -> void:
	add_to_group(&"mech_combatants")
	lower_body = Node2D.new()
	lower_body.name = "LowerBody"
	add_child(lower_body)

	upper_body = Node2D.new()
	upper_body.name = "UpperBody"
	add_child(upper_body)

	_build_mech()
	maneuver_side = -1.0 if rng.randi_range(0, 1) == 0 else 1.0
	_choose_direction()
	dash_decision_time_remaining = rng.randf_range(0.5, 1.5)


func _physics_process(delta: float) -> void:
	if player_controlled:
		_update_player_movement(delta)
		_select_opponent(manual_aim_position)
	else:
		_select_opponent(global_position)
		_update_random_movement(delta)
	_aim_at_opponent(delta)
	_update_weapons(delta)
	_update_boost_effect()
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 13.0, Color(0.2, 0.34, 0.42, 0.75), false, 0.25)
	draw_circle(Vector2.ZERO, 17.0, Color(0.12, 0.22, 0.28, 0.65), false, 0.25)
	if preparing_weapon_index >= 0:
		var spec := weapons[preparing_weapon_index].spec
		var progress := 1.0 - preparation_time_remaining / maxf(
			spec.preparation_time * weapon_range_multiplier,
			0.001
		)
		draw_arc(Vector2.ZERO, 20.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, Color("ffd34d"), 1.0)


func _update_random_movement(delta: float) -> void:
	direction_time_remaining -= delta
	if direction_time_remaining <= 0.0:
		_choose_direction()
	_update_strategy_direction()

	var margin := 45.0
	var safe_arena := arena.grow(-margin)
	if not safe_arena.has_point(position):
		movement_direction = (arena.get_center() - position).normalized()
		direction_time_remaining = minf(direction_time_remaining, 0.6)

	var turn_multiplier := 1.0
	var move_multiplier := 1.0
	if preparing_weapon_index >= 0:
		var preparation_spec := weapons[preparing_weapon_index].spec
		turn_multiplier = preparation_spec.preparation_turn_speed_multiplier
		move_multiplier = preparation_spec.preparation_move_speed_multiplier

	var desired_rotation := movement_direction.angle() + PI * 0.5
	upper_body.rotation = rotate_toward(
		upper_body.rotation,
		desired_rotation,
		deg_to_rad(upper_turn_speed_degrees) * turn_multiplier * delta
	)
	lower_body.rotation = upper_body.rotation
	var forward := torso_forward()
	var alignment := maxf(forward.dot(movement_direction), 0.0)
	var target_velocity := forward * cruise_speed * move_multiplier * alignment
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	var movement_step := velocity * delta
	dash_cooldown_remaining = maxf(dash_cooldown_remaining - delta, 0.0)
	if dash_time_remaining > 0.0:
		var dash_step := minf(delta, dash_time_remaining)
		movement_step += dash_direction * dash_speed * dash_step
		dash_time_remaining = maxf(dash_time_remaining - delta, 0.0)
	else:
		dash_decision_time_remaining -= delta
		if (
			dash_decision_time_remaining <= 0.0
			and dash_cooldown_remaining <= 0.0
			and preparing_weapon_index < 0
			and alignment >= cos(deg_to_rad(10.0))
		):
			_start_random_dash()
	position += movement_step
	position = position.clamp(arena.position, arena.end)


func _update_player_movement(delta: float) -> void:
	manual_aim_position = get_global_mouse_position()
	var input_direction := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W))
	).normalized()
	var target_velocity := input_direction * cruise_speed
	velocity = velocity.move_toward(target_velocity, acceleration * delta)
	position += velocity * delta
	position = position.clamp(arena.position, arena.end)
	if input_direction.length_squared() > 0.0:
		lower_body.rotation = rotate_toward(
			lower_body.rotation,
			input_direction.angle() + PI * 0.5,
			deg_to_rad(upper_turn_speed_degrees) * delta
		)
	var aim_vector := manual_aim_position - global_position
	if aim_vector.length_squared() > 1.0:
		upper_body.rotation = rotate_toward(
			upper_body.rotation,
			aim_vector.angle() + PI * 0.5,
			deg_to_rad(upper_turn_speed_degrees) * delta
		)


func _select_opponent(reference_position: Vector2) -> void:
	var nearest: AiMechAgent
	var nearest_distance := INF
	for target in opponents:
		if not is_instance_valid(target):
			continue
		var distance := reference_position.distance_squared_to(target.global_position)
		if distance < nearest_distance:
			nearest = target
			nearest_distance = distance
	opponent = nearest


func _aim_target_position() -> Vector2:
	return manual_aim_position if player_controlled else opponent.global_position

func _choose_direction() -> void:
	direction_time_remaining = rng.randf_range(0.8, 2.2)
	if rng.randf() < 0.35:
		maneuver_side *= -1.0
	if not is_instance_valid(opponent):
		movement_direction = Vector2.from_angle(rng.randf_range(-PI, PI))


func _update_strategy_direction() -> void:
	if not is_instance_valid(opponent):
		return
	var target_vector := opponent.global_position - global_position
	var distance := target_vector.length()
	if distance <= 1.0:
		return
	var toward_target := target_vector / distance
	var orbit_direction := toward_target.rotated(PI * 0.5 * maneuver_side)

	if movement_type == MovementType.AGGRESSIVE:
		var should_evade := opponent.is_preparing_attack()
		if should_evade and not evading:
			evasion_count += 1
			dash_decision_time_remaining = 0.0
		evading = should_evade
		if evading:
			movement_direction = (orbit_direction - toward_target * 0.35).normalized()
		elif distance > maximum_weapon_range() * 0.85:
			movement_direction = toward_target
		else:
			movement_direction = orbit_direction
		return

	if is_reloading_ballistic():
		if not reload_evasion_active:
			reload_evasion_count += 1
		reload_evasion_active = true
		evading = true
		movement_direction = (-toward_target + orbit_direction * 0.35).normalized()
		return
	reload_evasion_active = false
	if is_preparing_attack():
		evading = false
		return
	if _has_ready_weapon_in_range(distance):
		evading = false
		movement_direction = toward_target
		return
	var should_evade := distance < evasion_range
	if should_evade and not evading:
		evasion_count += 1
	evading = should_evade
	if distance < evasion_range:
		movement_direction = (-toward_target + orbit_direction * 0.25).normalized()
	elif distance > preferred_range * 1.05:
		movement_direction = toward_target
	elif distance < preferred_range * 0.95:
		movement_direction = -toward_target
	else:
		movement_direction = orbit_direction

	var center_pull := arena.get_center() - position
	if center_pull.length() > minf(arena.size.x, arena.size.y) * 0.35:
		movement_direction = (movement_direction + center_pull.normalized() * 0.8).normalized()


func _start_random_dash() -> void:
	dash_direction = torso_forward()
	dash_time_remaining = dash_duration
	dash_cooldown_remaining = dash_cooldown
	dash_decision_time_remaining = rng.randf_range(1.2, 3.2)
	dash_count += 1


func _aim_at_opponent(delta: float) -> void:
	if not player_controlled and not is_instance_valid(opponent):
		return
	var target_position := _aim_target_position()

	var head_vector := target_position - head_aim_node.global_position
	var head_target_rotation := wrapf(
		head_vector.angle() + PI * 0.5 - upper_body.global_rotation,
		-PI,
		PI
	)
	var head_traverse_limit := deg_to_rad(head_traverse_limit_degrees)
	head_aim_node.rotation = (
		head_target_rotation
		if absf(head_target_rotation) <= head_traverse_limit
		else 0.0
	)

	weapon_aim_valid.clear()
	for weapon_index in arm_aim_nodes.size():
		var aim_node := arm_aim_nodes[weapon_index]
		var arm_vector := target_position - aim_node.global_position
		var desired_local_rotation := wrapf(arm_vector.angle() - upper_body.global_rotation, -PI, PI)
		var traverse_delta := angle_difference(-PI * 0.5, desired_local_rotation)
		var traverse_limit := deg_to_rad(weapons[weapon_index].spec.traverse_limit_degrees)
		var aim_is_valid := absf(traverse_delta) <= traverse_limit
		var visual_target_rotation := desired_local_rotation if aim_is_valid else -PI * 0.5
		aim_node.rotation = rotate_toward(
			aim_node.rotation,
			visual_target_rotation,
			deg_to_rad(arm_visual_turn_speed_degrees) * delta
		)
		weapon_aim_valid.append(aim_is_valid)
	for weapon_index in range(arm_aim_nodes.size(), weapons.size()):
		var weapon := weapons[weapon_index]
		var aim_origin := global_position
		if not weapon.muzzles.is_empty():
			aim_origin = weapon.muzzles[0].global_position
		var aim_vector := target_position - aim_origin
		var desired_local_rotation := wrapf(
			aim_vector.angle() - upper_body.global_rotation,
			-PI,
			PI
		)
		var traverse_delta := angle_difference(-PI * 0.5, desired_local_rotation)
		var traverse_limit := deg_to_rad(weapon.spec.traverse_limit_degrees)
		weapon_aim_valid.append(absf(traverse_delta) <= traverse_limit)


func _update_weapons(delta: float) -> void:
	for weapon in weapons:
		weapon.tick(delta)
	linked_fire_cooldown = maxf(linked_fire_cooldown - delta, 0.0)
	if preparing_weapon_index >= 0:
		preparation_time_remaining = maxf(preparation_time_remaining - delta, 0.0)
		if preparation_time_remaining <= 0.0:
			_finish_preparation()
		return

	if not player_controlled or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_try_fire_linked_group()


func _has_ready_weapon_in_range(distance: float) -> bool:
	for weapon in weapons:
		if weapon.can_fire() and distance <= weapon.spec.max_range * weapon_range_multiplier:
			return true
	return false


func _try_fire_linked_group() -> void:
	if (
		linked_fire_cooldown > 0.0
		or weapons.is_empty()
		or (not player_controlled and not is_instance_valid(opponent))
		or dash_time_remaining > 0.0
		or (
			not player_controlled
			and movement_type == MovementType.RANGE_KEEPER
			and is_reloading_ballistic()
		)
	):
		return

	for offset in weapons.size():
		var weapon_index := (next_weapon_index + offset) % weapons.size()
		var weapon := weapons[weapon_index]
		if not weapon.can_fire():
			continue
		if (
			not player_controlled
			and global_position.distance_to(opponent.global_position)
			> weapon.spec.max_range * weapon_range_multiplier
		):
			range_blocked_count += 1
			continue
		if weapon_index >= weapon_aim_valid.size() or not weapon_aim_valid[weapon_index]:
			aim_blocked_count += 1
			continue
		if weapon.spec.preparation_time > 0.0:
			if not _can_complete_preparation(weapon_index):
				preparation_prediction_blocked_count += 1
				continue
			_start_preparation(weapon_index)
		else:
			_fire_weapon(weapon)
		next_weapon_index = (weapon_index + 1) % weapons.size()
		linked_fire_cooldown = linked_fire_stagger
		return


func _start_preparation(weapon_index: int) -> void:
	preparing_weapon_index = weapon_index
	preparation_time_remaining = weapons[weapon_index].spec.preparation_time * weapon_range_multiplier
	preparation_started_count += 1


func _can_complete_preparation(weapon_index: int) -> bool:
	var weapon_spec := weapons[weapon_index].spec
	var duration := weapon_spec.preparation_time * weapon_range_multiplier
	if duration <= 0.0 or not is_instance_valid(opponent):
		return true
	if player_controlled:
		return weapon_index < weapon_aim_valid.size() and weapon_aim_valid[weapon_index]

	var future_self_position := global_position + velocity * weapon_spec.preparation_move_speed_multiplier * duration
	var future_target_position := opponent.global_position + opponent.velocity * duration
	var future_aim_vector := future_target_position - future_self_position
	if future_aim_vector.length_squared() <= 1.0:
		return true

	var desired_torso_rotation := movement_direction.angle() + PI * 0.5
	var turn_amount := (
		deg_to_rad(upper_turn_speed_degrees)
		* weapon_spec.preparation_turn_speed_multiplier
		* duration
	)
	var future_torso_rotation := rotate_toward(
		upper_body.global_rotation,
		desired_torso_rotation,
		turn_amount
	)
	var future_local_aim := wrapf(
		future_aim_vector.angle() - future_torso_rotation,
		-PI,
		PI
	)
	var future_traverse := absf(angle_difference(-PI * 0.5, future_local_aim))

	var possible_target_displacement := (
		opponent.cruise_speed * duration
		+ opponent.dash_speed * opponent.dash_duration
	)
	var target_distance := maxf(future_aim_vector.length(), 1.0)
	var maneuver_margin := asin(clampf(possible_target_displacement / target_distance, 0.0, 0.95))
	var fixed_margin := deg_to_rad(2.0)
	var traverse_limit := deg_to_rad(weapon_spec.traverse_limit_degrees)
	return future_traverse + maneuver_margin + fixed_margin <= traverse_limit


func _finish_preparation() -> void:
	var weapon_index := preparing_weapon_index
	preparing_weapon_index = -1
	preparation_time_remaining = 0.0
	if not _can_execute_weapon(weapon_index):
		preparation_cancelled_count += 1
		return
	_fire_weapon(weapons[weapon_index])
	preparation_completed_count += 1


func _fire_weapon(weapon: WeaponRuntime) -> void:
	var weapon_index := weapons.find(weapon)
	if not _can_execute_weapon(weapon_index):
		return
	var muzzle := weapon.fire()
	if muzzle == null:
		return

	var aim_vector := _aim_target_position() - muzzle.global_position
	if aim_vector.length_squared() <= 1.0:
		aim_vector = muzzle.global_transform.x

	var spread_degrees := weapon.spec.spread_at_distance(
		aim_vector.length() / maxf(weapon_range_multiplier, 0.001)
	)
	var volley_size := maxi(weapon.spec.projectiles_per_shot, 1)
	var base_direction := aim_vector.normalized()
	var volley_rng := RandomNumberGenerator.new()
	volley_rng.seed = rng.randi()
	for projectile_index in volley_size:
		var arc_offset_degrees := 0.0
		if volley_size > 1:
			arc_offset_degrees = lerpf(
				-weapon.spec.volley_arc_degrees * 0.5,
				weapon.spec.volley_arc_degrees * 0.5,
				float(projectile_index) / float(volley_size - 1)
			)
		var launch_angle := deg_to_rad(
			weapon.spec.launch_offset_degrees
			+ arc_offset_degrees
			+ volley_rng.randf_range(-spread_degrees, spread_degrees)
		)
		var launch_direction := base_direction.rotated(launch_angle)
		_spawn_projectile(
			weapon,
			muzzle.global_position,
			launch_direction,
			volley_rng.randi(),
			spread_degrees
		)
		projectile_count += 1
	var flash_direction := base_direction.rotated(deg_to_rad(weapon.spec.launch_offset_degrees))
	_spawn_muzzle_flash(weapon.spec, muzzle.global_position, flash_direction)
	shot_count += 1
	fired_shots[weapon.spec.weapon_family] = fired_shots.get(weapon.spec.weapon_family, 0) + 1
	weapon_fired.emit(weapon)


func _can_execute_weapon(weapon_index: int) -> bool:
	if (
		weapon_index < 0
		or weapon_index >= weapons.size()
		or weapon_index >= weapon_aim_valid.size()
		or dash_time_remaining > 0.0
		or not weapon_aim_valid[weapon_index]
		or not weapons[weapon_index].can_fire()
	):
		return false
	if player_controlled:
		return true
	if not is_instance_valid(opponent):
		return false
	if movement_type == MovementType.RANGE_KEEPER and is_reloading_ballistic():
		return false
	return global_position.distance_to(opponent.global_position) <= (
		weapons[weapon_index].spec.max_range * weapon_range_multiplier
	)


func _spawn_projectile(
	weapon: WeaponRuntime,
	spawn_position: Vector2,
	direction: Vector2,
	shot_seed: int,
	spread_degrees: float
) -> void:
	var projectile_spec := weapon.spec.projectile
	var projectile := projectile_spec.projectile_scene.instantiate() as BallisticProjectile
	projectile.configure(
		projectile_spec,
		direction,
		weapon.spec.max_range * weapon_range_multiplier,
		self,
		weapon.part_name,
		shot_seed,
		spread_degrees,
		weapon.spec.weapon_family,
		opponent
	)
	projectile_layer.add_child(projectile)
	projectile.global_position = spawn_position


func _spawn_muzzle_flash(
	weapon_spec: WeaponSpec,
	spawn_position: Vector2,
	direction: Vector2
) -> void:
	var flash := MUZZLE_FLASH_SCENE.instantiate() as MuzzleFlash
	flash.setup(
		direction,
		weapon_spec.muzzle_flash_color,
		weapon_spec.muzzle_flash_duration,
		weapon_spec.fire_effect_id
	)
	projectile_layer.add_child(flash)
	flash.global_position = spawn_position


func _build_mech() -> void:
	var body_art := BODY_ART
	var body_anchors := BODY_ANCHORS
	if mech_loadout != null:
		body_art = mech_loadout.body.art_path
		body_anchors = mech_loadout.body.anchor_path
	var body_map := AnchorMap.load_map(body_anchors)
	var body_sprite := _create_sprite(body_art, 3)
	body_sprite.name = "BodySprite"
	upper_body.add_child(body_sprite)
	_attach_hitbox(body_sprite, &"Body", 3)

	var backpack := {}
	if mech_loadout == null or mech_loadout.backpack != null:
		var backpack_art := BACKPACK_ART
		var backpack_anchors := BACKPACK_ANCHORS
		if mech_loadout != null:
			backpack_art = mech_loadout.backpack.art_path
			backpack_anchors = mech_loadout.backpack.anchor_path
		var backpack_socket := AnchorMap.one(body_map, &"backpack_socket")
		backpack = _attach_static_part(
			upper_body,
			"Backpack",
			backpack_art,
			backpack_anchors,
			backpack_socket,
			1
		)

	var legs_socket := AnchorMap.one(body_map, &"legs_socket")
	var legs_art := LEGS_ART
	var legs_anchors := LEGS_ANCHORS
	if mech_loadout != null:
		legs_art = mech_loadout.legs.art_path
		legs_anchors = mech_loadout.legs.anchor_path
	var legs := _attach_static_part(lower_body, "Legs", legs_art, legs_anchors, legs_socket, 2)
	_attach_boosts(legs)

	var head_socket := AnchorMap.one(body_map, &"head_socket")
	var head_art := HEAD_ART
	var head_anchors := HEAD_ANCHORS
	if mech_loadout != null:
		head_art = mech_loadout.head.art_path
		head_anchors = mech_loadout.head.anchor_path
	head_aim_node = _attach_rotating_head(upper_body, head_socket, head_art, head_anchors, 5)

	if mech_loadout == null or mech_loadout.left_arm != null:
		var left_art := ARM_ART
		var left_anchors := ARM_ANCHORS
		var left_weapon: WeaponSpec
		if mech_loadout != null:
			left_art = mech_loadout.left_arm.art_path
			left_anchors = mech_loadout.left_arm.anchor_path
			left_weapon = mech_loadout.left_arm.weapon
		else:
			left_weapon = weapon_specs[0]
		var left_arm_socket := AnchorMap.one(body_map, &"left_arm_socket")
		var left_arm := _attach_aiming_arm(
			upper_body, "LeftArm", left_arm_socket, left_art, left_anchors, 4, left_weapon
		)
		if left_arm.has("weapon"):
			arm_aim_nodes.append(left_arm["aim"] as Node2D)
			weapons.append(left_arm["weapon"] as WeaponRuntime)

	if mech_loadout == null or mech_loadout.right_arm != null:
		var right_art := ARM_ART
		var right_anchors := ARM_ANCHORS
		var right_weapon: WeaponSpec
		if mech_loadout != null:
			right_art = mech_loadout.right_arm.art_path
			right_anchors = mech_loadout.right_arm.anchor_path
			right_weapon = mech_loadout.right_arm.weapon
		else:
			right_weapon = weapon_specs[1]
		var right_arm_socket := AnchorMap.one(body_map, &"right_arm_socket")
		var right_arm := _attach_aiming_arm(
			upper_body, "RightArm", right_arm_socket, right_art, right_anchors, 4, right_weapon
		)
		if right_arm.has("weapon"):
			arm_aim_nodes.append(right_arm["aim"] as Node2D)
			weapons.append(right_arm["weapon"] as WeaponRuntime)

	# Keep arm weapons aligned with arm_aim_nodes; backpack weapons have unrestricted aim.
	if mech_loadout != null:
		if mech_loadout.backpack != null and mech_loadout.backpack.weapon != null:
			_attach_backpack_weapon(backpack, mech_loadout.backpack.weapon)
	elif weapon_specs.size() > 2:
		_attach_backpack_weapon(backpack, weapon_specs[2])


func _attach_static_part(
	parent: Node2D,
	part_name: String,
	art_path: String,
	anchor_path: String,
	socket_position: Vector2,
	z_index_value: int
) -> Dictionary:
	var anchor_map := AnchorMap.load_map(anchor_path)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var part_root := Node2D.new()
	part_root.name = part_name
	part_root.position = socket_position
	parent.add_child(part_root)

	var sprite := _create_sprite(art_path, z_index_value)
	sprite.name = "%sSprite" % part_name
	sprite.position = -mount
	part_root.add_child(sprite)
	_attach_hitbox(sprite, StringName(part_name), z_index_value)

	return {
		"root": part_root,
		"map": anchor_map,
		"mount": mount,
		"sprite": sprite,
	}


func _attach_backpack_weapon(backpack: Dictionary, weapon_spec: WeaponSpec) -> void:
	var backpack_root := backpack["root"] as Node2D
	var muzzle := Marker2D.new()
	muzzle.name = "BackpackMuzzle"
	muzzle.position = Vector2(0.0, -6.0)
	backpack_root.add_child(muzzle)

	# The test backpack has no weapon art yet, so recoil is applied to an invisible proxy.
	var recoil_proxy := Sprite2D.new()
	recoil_proxy.name = "BackpackWeaponProxy"
	backpack_root.add_child(recoil_proxy)
	var muzzles: Array[Marker2D] = [muzzle]
	var weapon := WeaponRuntime.new()
	weapon.setup(weapon_spec, recoil_proxy, muzzles, &"Backpack", fire_rate_multiplier)
	weapons.append(weapon)


func _attach_aiming_arm(
	parent: Node2D,
	part_name: String,
	socket_position: Vector2,
	art_path: String,
	anchor_path: String,
	z_index_value: int,
	weapon_spec: WeaponSpec
) -> Dictionary:
	var anchor_map := AnchorMap.load_map(anchor_path)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var aim_pivot := AnchorMap.one(anchor_map, &"aim_pivot")
	var mount_root := Node2D.new()
	mount_root.name = "%sMount" % part_name
	mount_root.position = socket_position
	parent.add_child(mount_root)

	var aim_node := Node2D.new()
	aim_node.name = "%sAimPivot" % part_name
	aim_node.position = aim_pivot - mount
	aim_node.rotation = -PI * 0.5
	mount_root.add_child(aim_node)

	var sprite := _create_sprite(art_path, z_index_value)
	sprite.name = "%sSprite" % part_name
	sprite.position = -aim_pivot
	aim_node.add_child(sprite)
	_attach_hitbox(sprite, StringName(part_name), z_index_value)

	var muzzles: Array[Marker2D] = []
	var muzzle_positions := AnchorMap.many(anchor_map, &"muzzle")
	for index in muzzle_positions.size():
		var muzzle := Marker2D.new()
		muzzle.name = "Muzzle%d" % (index + 1)
		muzzle.position = muzzle_positions[index] - aim_pivot
		aim_node.add_child(muzzle)
		muzzles.append(muzzle)

	var result := {"aim": aim_node}
	if weapon_spec != null:
		var weapon := WeaponRuntime.new()
		weapon.setup(weapon_spec, sprite, muzzles, StringName(part_name), fire_rate_multiplier)
		result["weapon"] = weapon
	return result


func _attach_rotating_head(
	parent: Node2D,
	socket_position: Vector2,
	art_path: String,
	anchor_path: String,
	z_index_value: int
) -> Node2D:
	var anchor_map := AnchorMap.load_map(anchor_path)
	var mount := AnchorMap.one(anchor_map, &"mount")
	var aim_node := Node2D.new()
	aim_node.name = "HeadAimPivot"
	aim_node.position = socket_position
	parent.add_child(aim_node)

	var sprite := _create_sprite(art_path, z_index_value)
	sprite.name = "HeadSprite"
	sprite.position = -mount
	aim_node.add_child(sprite)
	_attach_hitbox(sprite, &"Head", z_index_value)
	return aim_node


func _attach_hitbox(sprite: Sprite2D, part_name: StringName, priority: int) -> void:
	var hitbox = PART_HITBOX.new()
	hitbox.name = "%sHitbox" % part_name
	hitbox.setup(self, part_name, sprite.texture, priority)
	sprite.add_child(hitbox)
	hitbox_count += 1


func _attach_boosts(legs: Dictionary) -> void:
	var legs_root := legs["root"] as Node2D
	var legs_map: Dictionary = legs["map"]
	var legs_mount: Vector2 = legs["mount"]
	var frames := SpriteFrames.new()
	frames.add_animation(&"burn")
	frames.set_animation_loop(&"burn", true)
	frames.set_animation_speed(&"burn", 8.0)
	for texture_path in BOOST_FRAMES:
		frames.add_frame(&"burn", load(texture_path) as Texture2D)

	var boost_anchors := AnchorMap.many(legs_map, &"boost")
	for index in boost_anchors.size():
		var boost := AnimatedSprite2D.new()
		boost.name = "Boost%d" % (index + 1)
		boost.sprite_frames = frames
		boost.animation = &"burn"
		boost.position = boost_anchors[index] - legs_mount + Vector2(0, 2.5)
		boost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		boost.z_index = 1
		legs_root.add_child(boost)
		boost.play()
		boost_sprites.append(boost)


func _update_boost_effect() -> void:
	for boost in boost_sprites:
		boost.visible = velocity.length_squared() > 4.0


func _create_sprite(texture_path: String, z_index_value: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(texture_path) as Texture2D
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z_index_value
	var shadow := Sprite2D.new()
	shadow.name = "SilhouetteShadow"
	shadow.texture = sprite.texture
	shadow.centered = true
	shadow.position = Vector2(2.0, 5.0)
	shadow.modulate = Color(0.01, 0.02, 0.025, 0.32)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_as_relative = false
	shadow.z_index = 0
	shadow.show_behind_parent = true
	sprite.add_child(shadow)
	return sprite
