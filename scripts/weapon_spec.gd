class_name WeaponSpec
extends Resource

const MIN_ENERGY_COOLDOWN_SECONDS := 0.3

enum WeaponFamily {
	BALLISTIC,
	MISSILE,
	ENERGY,
}

enum ResourceType {
	NONE,
	AMMO,
	EN,
}

@export var display_name := "Unnamed Weapon"
@export var weapon_family := WeaponFamily.BALLISTIC
@export var fire_effect_id: StringName = &"ballistic_small"
@export var fire_sound: AudioStream
@export var fire_rate := 2.0
@export var resource_type := ResourceType.AMMO
@export var resource_cost := 1.0
@export var heat_cost := 0.0
@export var magazine_capacity := 30
@export var reload_duration := 0.0
@export var effective_range := 140.0
@export var max_range := 220.0
@export_range(0.0, 180.0) var traverse_limit_degrees := 30.0
@export_range(-180.0, 180.0) var launch_offset_degrees := 0.0
@export_range(1, 32, 1) var projectiles_per_shot := 1
@export_range(0.0, 180.0) var volley_arc_degrees := 0.0
@export var base_spread_degrees := 0.5
@export var max_spread_degrees := 4.0
@export var spread_curve := 1.5
@export var visual_recoil_distance := 2.0
@export var visual_recoil_recovery := 12.0
@export var visual_recoil_limit := 3.0
@export var muzzle_flash_color := Color("fff1b5")
@export var muzzle_flash_duration := 0.06
@export var preparation_time := 0.0
@export_range(0.0, 1.0) var preparation_move_speed_multiplier := 1.0
@export_range(0.0, 1.0) var preparation_turn_speed_multiplier := 1.0
@export var projectile: ProjectileSpec


func fire_interval() -> float:
	return 1.0 / maxf(fire_rate, 0.001)


func cooldown_duration(fire_rate_multiplier: float = 1.0) -> float:
	var duration := fire_interval() / maxf(fire_rate_multiplier, 0.001)
	if resource_type == ResourceType.EN:
		return maxf(duration, MIN_ENERGY_COOLDOWN_SECONDS)
	return duration


func spread_at_distance(distance: float) -> float:
	if distance <= effective_range or max_range <= effective_range:
		return base_spread_degrees
	var ratio := clampf(
		(distance - effective_range) / (max_range - effective_range),
		0.0,
		1.0
	)
	return lerpf(base_spread_degrees, max_spread_degrees, pow(ratio, spread_curve))
