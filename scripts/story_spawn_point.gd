@tool
class_name StorySpawnPoint
extends Marker2D

enum SpawnMode {
	PREPLACED,
	TRIGGERED,
}

@export var unit_id := "UNIT-01"
@export var team_id := 1
@export var player_controlled := false
@export var spawn_mode := SpawnMode.PREPLACED
@export var spawn_group: StringName = &""
@export_enum("Aggressive", "Balanced", "Defensive") var movement_type := 0
@export var random_seed := 1200
@export var team_color := Color("ff776d")
@export_group("Combat Tuning")
@export var stationary := false
@export var weapons_disabled := false
@export_enum("Drone", "Mech", "Boss") var unit_class := 1
@export_range(0.0, 5.0, 0.05) var movement_speed_scale := 1.0
@export_range(0.0, 5.0, 0.05) var fire_rate_scale := 1.0
@export_range(0.05, 5.0, 0.05) var incoming_damage_scale := 1.0
@export_group("Fixed Loadout")
@export var head_id := "raven_sensor"
@export var body_id := "kestrel_core"
@export var left_arm_id := "rx_autocannon"
@export var right_arm_id := ""
@export var backpack_id := "grid_generator"
@export var legs_id := "strider_legs"


func _ready() -> void:
	queue_redraw()


func part_ids() -> Dictionary:
	return {
		"head": head_id,
		"body": body_id,
		"left_arm": left_arm_id,
		"right_arm": right_arm_id,
		"backpack": backpack_id,
		"legs": legs_id,
	}


func _draw() -> void:
	var color := Color("5ce1d0") if team_id == 0 else team_color
	draw_circle(Vector2.ZERO, 22.0, Color(color, 0.22))
	draw_circle(Vector2.ZERO, 22.0, color, false, 3.0)
	draw_line(Vector2(-30.0, 0.0), Vector2(30.0, 0.0), color, 2.0)
	draw_line(Vector2(0.0, -30.0), Vector2(0.0, 30.0), color, 2.0)
	draw_line(Vector2.ZERO, Vector2(28.0, 0.0), color, 3.0)
