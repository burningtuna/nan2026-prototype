class_name WeaponRuntime
extends RefCounted

var spec: WeaponSpec
var visual: Sprite2D
var muzzles: Array[Marker2D] = []
var part_name: StringName
var ammo := 0
var cooldown_remaining := 0.0
var recoil_offset := 0.0
var next_muzzle := 0
var rest_position := Vector2.ZERO
var fire_rate_multiplier := 1.0
var reload_remaining := 0.0
var reload_count := 0
var reload_completed_count := 0


func setup(
	weapon_spec: WeaponSpec,
	weapon_visual: Sprite2D,
	weapon_muzzles: Array[Marker2D],
	source_part: StringName,
	fire_rate_scale: float
) -> void:
	spec = weapon_spec
	visual = weapon_visual
	muzzles = weapon_muzzles
	part_name = source_part
	fire_rate_multiplier = fire_rate_scale
	ammo = spec.magazine_capacity
	rest_position = visual.position


func tick(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if reload_remaining > 0.0:
		reload_remaining = maxf(reload_remaining - delta, 0.0)
		if reload_remaining <= 0.0:
			ammo = spec.magazine_capacity
			reload_completed_count += 1
	recoil_offset = move_toward(recoil_offset, 0.0, spec.visual_recoil_recovery * delta)
	# Cannon art points along local +X, so visual recoil moves toward local -X.
	visual.position = rest_position + Vector2(-recoil_offset, 0.0)


func can_fire() -> bool:
	if cooldown_remaining > 0.0 or reload_remaining > 0.0 or muzzles.is_empty():
		return false
	if spec.resource_type == WeaponSpec.ResourceType.AMMO:
		return ammo >= ceili(spec.resource_cost)
	return spec.resource_type == WeaponSpec.ResourceType.NONE


func fire() -> Marker2D:
	if not can_fire():
		return null

	if spec.resource_type == WeaponSpec.ResourceType.AMMO:
		ammo -= ceili(spec.resource_cost)
		if ammo < ceili(spec.resource_cost) and spec.reload_duration > 0.0:
			reload_remaining = spec.reload_duration
			reload_count += 1
	cooldown_remaining = spec.fire_interval() / maxf(fire_rate_multiplier, 0.001)
	recoil_offset = minf(
		recoil_offset + spec.visual_recoil_distance,
		spec.visual_recoil_limit
	)

	var muzzle := muzzles[next_muzzle]
	next_muzzle = (next_muzzle + 1) % muzzles.size()
	return muzzle


func is_reloading() -> bool:
	return reload_remaining > 0.0
