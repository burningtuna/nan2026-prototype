class_name MuzzleFlash
extends Node2D

var flash_color := Color.WHITE
var effect_id: StringName = &"ballistic_small"
var lifetime := 0.06
var remaining := 0.06


func setup(direction: Vector2, color: Color, duration: float, fire_effect_id: StringName) -> void:
	rotation = direction.angle()
	flash_color = color
	effect_id = fire_effect_id
	lifetime = duration
	remaining = duration


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
		return
	var ratio := remaining / lifetime
	modulate.a = ratio
	scale = Vector2.ONE * lerpf(0.7, 1.2, ratio)


func _draw() -> void:
	var flash_length := 7.0 if effect_id == &"cannon_heavy" else 4.0
	var flash_width := 2.0 if effect_id == &"cannon_heavy" else 1.0
	var points := PackedVector2Array([
		Vector2.ZERO,
		Vector2(flash_length, -flash_width),
		Vector2(flash_length * 0.6, 0.0),
		Vector2(flash_length, flash_width),
	])
	draw_colored_polygon(points, flash_color)
