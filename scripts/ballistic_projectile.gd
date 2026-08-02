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
var source_part: StringName
var shot_seed := 0
var launch_spread_degrees := 0.0
var trail
var trail_started := false
var hit_candidates: Array[Area2D] = []
var hit_resolution_queued := false
var homing_reported := false
var hit_resolved := false
var source_hitbox_rids: Array[RID] = []


func configure(
	projectile_spec: ProjectileSpec,
	launch_direction: Vector2,
	travel_limit: float,
	shot_source: Node,
	part_name: StringName,
	seed: int,
	spread_degrees: float,
	family: WeaponSpec.WeaponFamily,
	target: Node2D
) -> void:
	spec = projectile_spec
	direction = launch_direction.normalized()
	max_distance = travel_limit
	source_mech = shot_source
	source_part = part_name
	shot_seed = seed
	launch_spread_degrees = spread_degrees
	weapon_family = family
	homing_target = target
	rotation = direction.angle()


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
	trail = PROJECTILE_TRAIL.new()
	trail.setup(weapon_family, direction)
	trail.top_level = true
	trail.z_index = 1
	get_parent().add_child(trail)
	trail.global_position = Vector2.ZERO
	_collect_source_hitboxes()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not trail_started:
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
	global_position = end_position
	traveled_distance += frame_distance
	trail.add_sample(global_position)
	if traveled_distance >= max_distance or (spec.lifetime > 0.0 and elapsed_time >= spec.lifetime):
		queue_free()


func _update_homing_direction(delta: float) -> void:
	if not spec.homing or not is_instance_valid(homing_target):
		return
	var target_direction := homing_target.global_position - global_position
	if target_direction.length_squared() <= 1.0:
		return
	var next_direction := target_direction.normalized()
	var turn_angle := direction.angle_to(next_direction)
	var max_turn := deg_to_rad(spec.homing_turn_speed_degrees) * delta
	var applied_turn := turn_angle if max_turn <= 0.0 else clampf(turn_angle, -max_turn, max_turn)
	if not homing_reported and absf(applied_turn) > 0.001:
		homing_reported = true
		if source_mech.has_method("register_homing_adjustment"):
			source_mech.register_homing_adjustment()
	direction = direction.rotated(applied_turn).normalized()
	rotation = direction.angle()
	trail.set_direction(direction)


func _collect_source_hitboxes() -> void:
	if not is_instance_valid(source_mech):
		return
	for mech in get_tree().get_nodes_in_group(&"mech_combatants"):
		if not source_mech.has_method("is_ally_of") or not source_mech.is_ally_of(mech):
			continue
		for node in mech.find_children("*", "Area2D", true, false):
			if node.get_script() == PART_HITBOX:
				source_hitbox_rids.append(node.get_rid())


func _check_swept_hit(start_position: Vector2, end_position: Vector2) -> bool:
	if start_position.is_equal_approx(end_position):
		return false
	var query := PhysicsRayQueryParameters2D.create(
		start_position,
		end_position,
		2,
		source_hitbox_rids
	)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_world_2d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var hitbox = result.get("collider")
	if hitbox == null or hitbox.get_script() != PART_HITBOX:
		return false
	_apply_hit(hitbox, result.get("position", end_position))
	return true


func _exit_tree() -> void:
	if is_instance_valid(trail):
		trail.finish()


func _on_area_entered(area: Area2D) -> void:
	if (
		hit_resolved
		or area.get_script() != PART_HITBOX
		or area.mech == source_mech
		or (source_mech.has_method("is_ally_of") and source_mech.is_ally_of(area.mech))
	):
		return
	hit_candidates.append(area)
	if not hit_resolution_queued:
		hit_resolution_queued = true
		call_deferred("_resolve_hit_candidates")


func _resolve_hit_candidates() -> void:
	if hit_resolved or is_queued_for_deletion() or hit_candidates.is_empty():
		return

	var selected_hitbox: Area2D = hit_candidates[0]
	for hitbox in hit_candidates:
		if hitbox.hit_priority > selected_hitbox.hit_priority:
			selected_hitbox = hitbox
		elif hitbox.hit_priority == selected_hitbox.hit_priority:
			if String(hitbox.part_name) < String(selected_hitbox.part_name):
				selected_hitbox = hitbox

	_apply_hit(selected_hitbox, global_position)


func _apply_hit(hitbox: Area2D, hit_position: Vector2) -> void:
	if hit_resolved:
		return
	hit_resolved = true
	var effect = IMPACT_EFFECT.new()
	effect.setup(weapon_family, direction, shot_seed)
	effect.scale = Vector2.ONE * 3.0
	effect.z_index = 3
	get_parent().add_child(effect)
	effect.global_position = hit_position
	hitbox.mech.register_hit(hitbox.part_name, direction)
	if source_mech.has_method("register_landed_hit"):
		source_mech.register_landed_hit(weapon_family)
	queue_free()


func _draw() -> void:
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
