class_name BallisticProjectile
extends Area2D

const PROJECTILE_TRAIL := preload("res://scripts/projectile_trail.gd")
const PART_HITBOX := preload("res://scripts/part_hitbox.gd")
const IMPACT_EFFECT := preload("res://scripts/impact_effect.gd")

var spec: ProjectileSpec
var weapon_family := WeaponSpec.WeaponFamily.BALLISTIC
var direction := Vector2.RIGHT
var homing_target: Node2D
var max_distance := 0.0
var traveled_distance := 0.0
var elapsed_time := 0.0
var source_mech: Node
var source_team_id := -1
var source_part: StringName
var shot_seed := 0
var launch_spread_degrees := 0.0
var trail
var trail_started := false
var hit_candidates: Array[Area2D] = []
var hit_resolution_queued := false
var homing_reported := false
var homing_observation_position := Vector2.ZERO
var homing_observation_velocity := Vector2.ZERO
var homing_observation_age := 0.0
var homing_observation_valid := false
var homing_observation_enabled := true
var hit_resolved := false
var source_hitbox_rids: Array[RID] = []
var visuals_enabled := true
var multi_projectile_launch := false


func configure(
	projectile_spec: ProjectileSpec,
	launch_direction: Vector2,
	travel_limit: float,
	shot_source: Node,
	part_name: StringName,
	seed: int,
	spread_degrees: float,
	family: WeaponSpec.WeaponFamily,
	target: Node2D,
	observed_position := Vector2.ZERO,
	observed_velocity := Vector2.ZERO,
	target_was_dashing := false,
	observation_valid := false,
	launched_in_multi_projectile_volley := false
) -> void:
	spec = projectile_spec
	direction = launch_direction.normalized()
	max_distance = travel_limit
	source_mech = shot_source
	if is_instance_valid(source_mech):
		var team_value = source_mech.get("team_id")
		if team_value != null:
			source_team_id = int(team_value)
	visuals_enabled = not source_mech.has_method("visuals_enabled") or source_mech.visuals_enabled()
	source_part = part_name
	shot_seed = seed
	launch_spread_degrees = spread_degrees
	weapon_family = family
	multi_projectile_launch = launched_in_multi_projectile_volley
	homing_target = target
	if is_instance_valid(target) and observation_valid:
		update_homing_observation(observed_position, observed_velocity, target_was_dashing)
	rotation = direction.angle()


func update_homing_observation(position_value: Vector2, velocity_value: Vector2, dashing: bool) -> void:
	homing_observation_position = position_value
	homing_observation_velocity = velocity_value
	homing_observation_age = 0.0
	homing_observation_valid = true
	homing_observation_enabled = not dashing


func _ready() -> void:
	var collision_shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = spec.collision_radius
	collision_shape.shape = circle
	add_child(collision_shape)
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	area_entered.connect(_on_area_entered)
	z_index = 2
	if visuals_enabled:
		trail = PROJECTILE_TRAIL.new()
		trail.setup(
			weapon_family,
			direction,
			spec.trail_width_multiplier,
			spec.trail_lifetime_multiplier,
			multi_projectile_launch
		)
		trail.top_level = true
		trail.z_index = 1
		get_parent().add_child(trail)
		trail.global_position = Vector2.ZERO
	_collect_source_hitboxes()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if visuals_enabled and not trail_started:
		trail.add_sample(global_position)
		trail_started = true
	_update_homing_direction(delta)
	elapsed_time += delta
	var remaining_distance := maxf(max_distance - traveled_distance, 0.0)
	var frame_distance := minf(spec.speed * delta, remaining_distance)
	var start_position := global_position
	var end_position := start_position + direction * frame_distance
	if _check_swept_hit(start_position, end_position):
		return
	if _check_proximity_fuse(start_position, end_position):
		return
	global_position = end_position
	traveled_distance += frame_distance
	if visuals_enabled:
		trail.add_sample(global_position)
	if traveled_distance >= max_distance or (spec.lifetime > 0.0 and elapsed_time >= spec.lifetime):
		queue_free()


func _update_homing_direction(delta: float) -> void:
	homing_observation_age += delta
	if (
		not spec.homing
		or not homing_observation_valid
		or not homing_observation_enabled
	):
		return
	var estimated_target_position := (
		homing_observation_position + homing_observation_velocity * homing_observation_age
	)
	var target_direction := estimated_target_position - global_position
	if target_direction.length_squared() <= 1.0:
		return
	var next_direction := target_direction.normalized()
	var turn_angle := direction.angle_to(next_direction)
	var max_turn := deg_to_rad(spec.homing_turn_speed_degrees) * delta
	var applied_turn := turn_angle if max_turn <= 0.0 else clampf(turn_angle, -max_turn, max_turn)
	if not homing_reported and absf(applied_turn) > 0.001:
		homing_reported = true
		if is_instance_valid(source_mech) and source_mech.has_method("register_homing_adjustment"):
			source_mech.register_homing_adjustment()
	direction = direction.rotated(applied_turn).normalized()
	rotation = direction.angle()
	if visuals_enabled:
		trail.set_direction(direction)


func _collect_source_hitboxes() -> void:
	if not is_instance_valid(source_mech):
		return
	for mech in source_mech.get_parent().get_children():
		if not source_mech.has_method("is_ally_of") or not source_mech.is_ally_of(mech):
			continue
		for node in mech.find_children("*", "Area2D", true, false):
			if node.get_script() == PART_HITBOX:
				source_hitbox_rids.append(node.get_rid())


func _check_swept_hit(start_position: Vector2, end_position: Vector2) -> bool:
	if start_position.is_equal_approx(end_position):
		return false
	var ray_start := start_position
	var exclusions := source_hitbox_rids.duplicate()
	while true:
		var query := PhysicsRayQueryParameters2D.create(ray_start, end_position, 2, exclusions)
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var result := get_world_2d().direct_space_state.intersect_ray(query)
		if result.is_empty():
			return false
		var hitbox = result.get("collider")
		if hitbox != null and hitbox.has_method("receive_projectile_hit"):
			_apply_environment_hit(hitbox, result.get("position", end_position))
			return true
		if hitbox == null or hitbox.get_script() != PART_HITBOX:
			return false
		if hitbox.mech == source_mech or _is_allied_target(hitbox.mech):
			exclusions.append(hitbox.get_rid())
			ray_start = Vector2(result.get("position", ray_start)).move_toward(end_position, 0.01)
			continue
		_apply_hit(hitbox, result.get("position", end_position))
		return true
	return false


func _check_proximity_fuse(start_position: Vector2, end_position: Vector2) -> bool:
	if (
		weapon_family != WeaponSpec.WeaponFamily.MISSILE
		or spec.proximity_fuse_radius <= 0.0
		or not is_instance_valid(homing_target)
		or homing_target == source_mech
		or _is_allied_target(homing_target)
	):
		return false
	var fuse_position := Geometry2D.get_closest_point_to_segment(
		homing_target.global_position,
		start_position,
		end_position
	)
	if (
		fuse_position.distance_squared_to(homing_target.global_position)
		> spec.proximity_fuse_radius ** 2
	):
		return false
	_detonate(fuse_position)
	return true


func _exit_tree() -> void:
	if is_instance_valid(trail):
		trail.finish()


func _on_area_entered(area: Area2D) -> void:
	if not hit_resolved and area.has_method("receive_projectile_hit"):
		_apply_environment_hit(area, global_position)
		return
	if (
		hit_resolved
		or area.get_script() != PART_HITBOX
		or area.mech == source_mech
		or _is_allied_target(area.mech)
	):
		return
	hit_candidates.append(area)
	if not hit_resolution_queued:
		hit_resolution_queued = true
		call_deferred("_resolve_hit_candidates")


func _resolve_hit_candidates() -> void:
	if hit_resolved or is_queued_for_deletion() or hit_candidates.is_empty():
		return
	var valid_candidates: Array[Area2D] = []
	for hitbox in hit_candidates:
		if is_instance_valid(hitbox) and is_instance_valid(hitbox.mech):
			valid_candidates.append(hitbox)
	hit_candidates.clear()
	if valid_candidates.is_empty():
		return
	var selected_hitbox: Area2D = valid_candidates[0]
	for hitbox in valid_candidates:
		if hitbox.hit_priority > selected_hitbox.hit_priority:
			selected_hitbox = hitbox
		elif hitbox.hit_priority == selected_hitbox.hit_priority:
			if String(hitbox.part_name) < String(selected_hitbox.part_name):
				selected_hitbox = hitbox

	_apply_hit(selected_hitbox, global_position)


func _apply_hit(hitbox: Area2D, hit_position: Vector2) -> void:
	if hit_resolved:
		return
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE and spec.splash_radius > 0.0:
		_detonate(hit_position)
		return
	hit_resolved = true
	_spawn_impact_effect(hit_position)
	hitbox.mech.register_hit(hitbox.part_name, direction, spec.damage)
	if is_instance_valid(source_mech) and source_mech.has_method("register_landed_hit"):
		source_mech.register_landed_hit(weapon_family)
	queue_free()


func _apply_environment_hit(target: Node, hit_position: Vector2) -> void:
	if hit_resolved:
		return
	if weapon_family == WeaponSpec.WeaponFamily.MISSILE and spec.splash_radius > 0.0:
		target.receive_projectile_hit(spec.damage, direction, hit_position)
		_detonate(hit_position)
		return
	hit_resolved = true
	_spawn_impact_effect(hit_position)
	target.receive_projectile_hit(spec.damage, direction, hit_position)
	queue_free()


func _detonate(hit_position: Vector2) -> void:
	if hit_resolved:
		return
	hit_resolved = true
	_spawn_impact_effect(hit_position)
	var damaged_hitboxes := 0
	var radius_squared := spec.splash_radius ** 2
	var scene_tree := source_mech.get_tree() if is_instance_valid(source_mech) else get_tree()
	if scene_tree == null:
		queue_free()
		return
	for target in scene_tree.get_nodes_in_group(&"mech_combatants"):
		if (
			not is_instance_valid(target)
			or target == source_mech
			or _is_allied_target(target)
			or (target.has_method("is_defeated") and target.is_defeated())
		):
			continue
		for node in target.find_children("*", "Area2D", true, false):
			var hitbox := node as Area2D
			if (
				hitbox == null
				or hitbox.get_script() != PART_HITBOX
				or hitbox.global_position.distance_squared_to(hit_position) > radius_squared
			):
				continue
			var impact_direction := (hitbox.global_position - hit_position).normalized()
			if impact_direction.is_zero_approx():
				impact_direction = direction
			hitbox.mech.register_hit(hitbox.part_name, impact_direction, spec.damage)
			damaged_hitboxes += 1
	if (
		damaged_hitboxes > 0
		and is_instance_valid(source_mech)
		and source_mech.has_method("register_landed_hit")
	):
		source_mech.register_landed_hit(weapon_family)
	queue_free()


func _spawn_impact_effect(hit_position: Vector2) -> void:
	if not visuals_enabled:
		return
	var effect = IMPACT_EFFECT.new()
	effect.setup(weapon_family, direction, shot_seed)
	effect.scale = Vector2.ONE * maxf(spec.splash_radius / 12.0, 3.0)
	effect.z_index = 3
	get_parent().add_child(effect)
	effect.global_position = hit_position


func _is_allied_target(target: Node) -> bool:
	if not is_instance_valid(target):
		return false
	if is_instance_valid(source_mech) and source_mech.has_method("is_ally_of"):
		return source_mech.is_ally_of(target)
	var target_team_value = target.get("team_id")
	return (
		source_team_id >= 0
		and target_team_value != null
		and int(target_team_value) == source_team_id
	)


func _draw() -> void:
	if not visuals_enabled:
		return
	var shadow_offset := Vector2(1.5, 2.0).rotated(-global_rotation)
	if spec.visual_texture != null:
		var visual_size := spec.visual_texture.get_size() * spec.visual_scale
		if weapon_family != WeaponSpec.WeaponFamily.ENERGY:
			draw_texture_rect(
				spec.visual_texture,
				Rect2(-visual_size * 0.5 + shadow_offset, visual_size),
				false,
				Color(0.01, 0.02, 0.025, 0.38)
			)
		draw_texture_rect(
			spec.visual_texture,
			Rect2(-visual_size * 0.5, visual_size),
			false,
			spec.color
		)
		return
	if weapon_family != WeaponSpec.WeaponFamily.ENERGY:
		draw_set_transform(shadow_offset, 0.0, Vector2.ONE * spec.visual_scale)
		draw_rect(Rect2(-2.0, -0.5, 4.0, 1.0), Color(0.01, 0.02, 0.025, 0.38))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * spec.visual_scale)
	draw_rect(Rect2(-2.0, -0.5, 4.0, 1.0), spec.color)
	draw_circle(Vector2(1.5, 0.0), 1.0, Color.WHITE)
