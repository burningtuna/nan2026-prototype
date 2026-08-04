@tool
class_name StoryWalkableArea
extends Polygon2D

@export var show_in_game := true


func _ready() -> void:
	if not Engine.is_editor_hint() and not show_in_game:
		visible = false


func contains_global_point(point: Vector2) -> bool:
	return polygon.size() >= 3 and Geometry2D.is_point_in_polygon(to_local(point), polygon)
