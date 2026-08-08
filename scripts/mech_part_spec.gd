class_name MechPartSpec
extends Resource

enum PartType {
	HEAD,
	BODY,
	ARM_EQUIPMENT,
	BACKPACK,
	LEGS,
}

@export var display_name := "Unnamed Part"
@export var part_id := ""
@export var designation := "--"
@export_multiline var description := ""
@export var part_type := PartType.BODY
@export_file("*.png") var art_path := ""
@export_file("*.png") var anchor_path := ""
@export_file("*.png") var splash_art_path := ""
@export_file("*.png") var wireframe_art_path := ""
@export_file("*.png") var wireframe_anchor_path := ""
@export var preview_tint := Color.WHITE
@export var weapon: WeaponSpec
@export var armor := 0.0
@export var weight := 0.0
@export var power_generation := 0.0
@export var power_draw := 0.0
@export var cooling := 0.0
@export var mobility := 0.0
@export var firepower := 0.0
@export var weight_capacity := 0.0
@export var sensor_range := 0.0
@export var sensor_period := 1.0
@export var enemy_track_limit := 0
@export var projectile_track_limit := 0
@export var repair_rate := 0.0
@export var repair_power_generation := 0.0
@export var missile_speed_multiplier := 1.0
@export var missile_preparation_time_override := -1.0
@export var missile_reload_duration_override := -1.0
@export var missile_seeker_angle_degrees := 0.0
@export var missile_turn_speed_override_degrees := -1.0
@export var missile_max_spread_degrees := -1.0
@export var missile_proximity_fuse_radius_multiplier := 1.0
@export var missile_damage_multiplier := 1.0
@export var missile_ignores_evasion := false


func provides_weapon() -> bool:
	return weapon != null
