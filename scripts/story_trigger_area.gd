@tool
class_name StoryTriggerArea
extends Node2D

signal activated(trigger: StoryTriggerArea)

@export var trigger_id: StringName = &"TRIGGER-01"
@export var area_size := Vector2(320.0, 240.0):
	set(value):
		area_size = value.max(Vector2.ONE)
		queue_redraw()
@export var once := true
@export var spawn_group: StringName = &""
@export var campaign_flag: StringName = &""
@export var campaign_value := true
@export var message := ""
@export var display_color := Color("ffd34d")

var has_activated := false


func contains_global_point(point: Vector2) -> bool:
	return Rect2(-area_size * 0.5, area_size).has_point(to_local(point))


func try_activate(point: Vector2) -> bool:
	if (once and has_activated) or not contains_global_point(point):
		return false
	has_activated = true
	activated.emit(self)
	queue_redraw()
	return true


func _draw() -> void:
	var color := Color("718b8e") if has_activated else display_color
	var rect := Rect2(-area_size * 0.5, area_size)
	draw_rect(rect, Color(color, 0.1))
	draw_dashed_line(rect.position, Vector2(rect.end.x, rect.position.y), color, 4.0, 12.0)
	draw_dashed_line(Vector2(rect.end.x, rect.position.y), rect.end, color, 4.0, 12.0)
	draw_dashed_line(rect.end, Vector2(rect.position.x, rect.end.y), color, 4.0, 12.0)
	draw_dashed_line(Vector2(rect.position.x, rect.end.y), rect.position, color, 4.0, 12.0)
