@tool
class_name StoryDestructibleCover
extends StoryBlocker

signal cover_destroyed(cover_id: StringName)

@export var cover_id: StringName = &"COVER-01"
@export var maximum_durability := 150.0

var current_durability := 0.0
var destroyed := false


func _ready() -> void:
	super._ready()
	current_durability = maximum_durability


func blocks_agent_at(global_point: Vector2, radius: float) -> bool:
	return not destroyed and super.blocks_agent_at(global_point, radius)


func receive_projectile_hit(damage: float, _direction: Vector2, _hit_position: Vector2) -> void:
	if Engine.is_editor_hint() or destroyed:
		return
	current_durability = maxf(current_durability - damage, 0.0)
	if current_durability > 0.0:
		return
	destroyed = true
	collision_layer = 0
	monitorable = false
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	queue_redraw()
	cover_destroyed.emit(cover_id)


func _draw() -> void:
	var rect := Rect2(-blocker_size * 0.5, blocker_size)
	var color := Color("31383a") if destroyed else Color("795448")
	draw_rect(rect, Color(color, 0.45 if destroyed else 1.0))
	draw_rect(rect, color.lightened(0.3), false, 3.0)
	if not destroyed:
		draw_line(rect.position, rect.end, Color("b98568"), 3.0)
		draw_line(
			Vector2(rect.end.x, rect.position.y),
			Vector2(rect.position.x, rect.end.y),
			Color("b98568"),
			3.0
		)
