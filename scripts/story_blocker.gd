@tool
class_name StoryBlocker
extends Area2D

@export var blocker_size := Vector2(240.0, 120.0):
	set(value):
		blocker_size = value.max(Vector2.ONE)
		_sync_collision_shape()
		queue_redraw()
@export var blocks_projectiles := true
@export var display_color := Color("25383d")

var collision_shape: CollisionShape2D


func _ready() -> void:
	collision_layer = 2 if blocks_projectiles else 0
	collision_mask = 0
	monitoring = false
	monitorable = blocks_projectiles
	_sync_collision_shape()
	queue_redraw()


func blocks_agent_at(global_point: Vector2, radius: float) -> bool:
	var local_point := to_local(global_point)
	return Rect2(-blocker_size * 0.5 - Vector2.ONE * radius, blocker_size + Vector2.ONE * radius * 2.0).has_point(local_point)


func receive_projectile_hit(_damage: float, _direction: Vector2, _hit_position: Vector2) -> void:
	pass


func _sync_collision_shape() -> void:
	if not is_inside_tree():
		return
	if collision_shape == null:
		collision_shape = CollisionShape2D.new()
		collision_shape.name = "CollisionShape2D"
		add_child(collision_shape)
	var rectangle := RectangleShape2D.new()
	rectangle.size = blocker_size
	collision_shape.shape = rectangle


func _draw() -> void:
	var rect := Rect2(-blocker_size * 0.5, blocker_size)
	draw_rect(rect, display_color)
	draw_rect(rect, display_color.lightened(0.35), false, 3.0)
