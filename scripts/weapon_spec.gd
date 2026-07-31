class_name WeaponSpec
extends Resource

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
@export var fire_rate := 2.0
@export var resource_type := ResourceType.AMMO
@export var resource_cost := 1.0
@export var ammo_capacity := 30
@export var effective_range := 140.0
@export var max_range := 220.0
@export var base_spread_degrees := 0.5
@export var max_spread_degrees := 4.0
@export var spread_curve := 1.5
@export var visual_recoil_distance := 2.0
@export var visual_recoil_recovery := 12.0
@export var visual_recoil_limit := 3.0
@export var muzzle_flash_color := Color("fff1b5")
@export var muzzle_flash_duration := 0.06
@export var projectile: ProjectileSpec


func fire_interval() -> float:
	return 1.0 / maxf(fire_rate, 0.001)


func spread_at_distance(distance: float) -> float:
	if distance <= effective_range or max_range <= effective_range:
		return base_spread_degrees
	var ratio := clampf(
		(distance - effective_range) / (max_range - effective_range),
		0.0,
		1.0
	)
	return lerpf(base_spread_degrees, max_spread_degrees, pow(ratio, spread_curve))
