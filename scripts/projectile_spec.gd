class_name ProjectileSpec
extends Resource

@export var projectile_scene: PackedScene
@export var speed := 260.0
@export var collision_radius := 1.0
@export var damage := 10.0
@export var damage_type: StringName = &"kinetic"
@export var penetration := 0.0
@export var splash_radius := 0.0
@export var color := Color("ffd37a")
