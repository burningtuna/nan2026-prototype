class_name ProjectileSpec
extends Resource

@export var projectile_scene: PackedScene
@export var speed := 260.0
@export var collision_radius := 1.0
@export var visual_texture: Texture2D
@export_range(0.1, 10.0, 0.1) var visual_scale := 1.0
@export_range(0.1, 5.0, 0.1) var trail_width_multiplier := 1.0
@export_range(0.05, 5.0, 0.05) var trail_lifetime_multiplier := 1.0
@export var damage := 10.0
@export var damage_type: StringName = &"kinetic"
@export var penetration := 0.0
@export var splash_radius := 0.0
@export var color := Color("ffd37a")
@export var lifetime := 0.0
@export var homing := false
@export var homing_turn_speed_degrees := 0.0
