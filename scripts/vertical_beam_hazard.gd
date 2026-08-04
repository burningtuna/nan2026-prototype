class_name VerticalBeamHazard
extends Node2D

signal warning_started(target_x: float)
signal firing_started(target_x: float)

enum State {
	WARNING,
	FIRING,
	COOLDOWN,
}

@export var warning_duration := 2.0
@export var firing_duration := 0.35
@export var cooldown_duration := 3.0
@export var beam_width := 200.0

var arena := Rect2(-3000.0, -3000.0, 6000.0, 6000.0)
var player: AiMechAgent
var state := State.COOLDOWN
var state_remaining := 0.0
var target_x := 0.0
var damaged_this_firing := false
var active := false


func setup(movement_arena: Rect2, combat_player: AiMechAgent) -> void:
	arena = movement_arena
	player = combat_player
	active = true
	_begin_warning()


func _process(delta: float) -> void:
	if not active:
		return
	state_remaining -= delta
	if state_remaining > 0.0:
		return
	match state:
		State.WARNING:
			_begin_firing()
		State.FIRING:
			_begin_cooldown()
		State.COOLDOWN:
			_begin_warning()


func _draw() -> void:
	if not active or state == State.COOLDOWN:
		return
	var beam_rect := Rect2(
		Vector2(target_x - beam_width * 0.5, arena.position.y) - global_position,
		Vector2(beam_width, arena.size.y)
	)
	if state == State.WARNING:
		draw_rect(beam_rect, Color(1.0, 0.72, 0.12, 0.2), true)
		draw_rect(beam_rect, Color(1.0, 0.88, 0.3, 0.95), false, 5.0)
		draw_line(
			Vector2(target_x, arena.position.y) - global_position,
			Vector2(target_x, arena.end.y) - global_position,
			Color(1.0, 0.95, 0.62, 0.9),
			2.0
		)
	else:
		draw_rect(beam_rect, Color(1.0, 0.08, 0.12, 0.82), true)
		draw_rect(beam_rect.grow(-18.0), Color(1.0, 0.88, 0.72, 0.9), true)
		draw_rect(beam_rect, Color.WHITE, false, 7.0)


func _begin_warning() -> void:
	state = State.WARNING
	state_remaining = warning_duration
	damaged_this_firing = false
	if is_instance_valid(player):
		target_x = player.global_position.x
	warning_started.emit(target_x)
	queue_redraw()


func _begin_firing() -> void:
	state = State.FIRING
	state_remaining = firing_duration
	firing_started.emit(target_x)
	_damage_player_once()
	queue_redraw()


func _begin_cooldown() -> void:
	state = State.COOLDOWN
	state_remaining = cooldown_duration
	queue_redraw()


func _damage_player_once() -> void:
	if damaged_this_firing or not is_instance_valid(player) or player.is_defeated():
		return
	damaged_this_firing = true
	if absf(player.global_position.x - target_x) > beam_width * 0.5:
		return
	var body_durability := float(player.part_durability.get(&"Body", 0.0))
	if body_durability > 0.0:
		player.register_hit(&"Body", Vector2.UP, body_durability)
