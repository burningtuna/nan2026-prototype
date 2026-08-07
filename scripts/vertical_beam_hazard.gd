class_name VerticalBeamHazard
extends Node2D

const BEAM_TEXTURE := preload("res://Sprites/Effects/Stage5-Boss-Laser-Beam.png")
const PREPARATION_STREAM := preload(
	"res://Sounds/combat/doomsday_laser_cannon_midium_.wav"
)

signal warning_started(target_x: float)
signal firing_started(target_x: float)
signal lethal_hit_imminent(target_x: float)

enum State {
	WARNING,
	FIRING,
	COOLDOWN,
}

@export var warning_duration := 5.0
@export var firing_duration := 0.35
@export var cooldown_duration := 9.65
@export var beam_width := 200.0
@export var firing_beam_length := 6000.0
@export var fade_out_duration := 2.0

var arena := Rect2(-3000.0, -3000.0, 6000.0, 6000.0)
var player: AiMechAgent
var state := State.COOLDOWN
var state_remaining := 0.0
var target_x := 0.0
var damaged_this_firing := false
var intercepted_this_firing := false
var active := false
var fade_remaining := 0.0
var preparation_audio: AudioStreamPlayer


func _ready() -> void:
	preparation_audio = AudioStreamPlayer.new()
	preparation_audio.name = "PreparationAudio"
	preparation_audio.stream = PREPARATION_STREAM
	add_child(preparation_audio)


func setup(movement_arena: Rect2, combat_player: AiMechAgent, activate_immediately := true) -> void:
	arena = movement_arena
	player = combat_player
	active = false
	if activate_immediately:
		activate()


func activate() -> void:
	if active:
		return
	active = true
	_begin_warning()


func _process(delta: float) -> void:
	if not active:
		return
	if fade_remaining > 0.0:
		fade_remaining = maxf(fade_remaining - delta, 0.0)
		queue_redraw()
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
	if not active or (state == State.COOLDOWN and fade_remaining <= 0.0):
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
		var firing_beam_rect := Rect2(
			Vector2(
				target_x - beam_width * 0.5,
				arena.get_center().y - firing_beam_length * 0.5
			) - global_position,
			Vector2(beam_width, firing_beam_length)
		)
		var beam_alpha := 1.0
		if state == State.COOLDOWN:
			beam_alpha = fade_remaining / maxf(fade_out_duration, 0.001)
		draw_texture_rect(
			BEAM_TEXTURE,
			firing_beam_rect,
			false,
			Color(1.0, 1.0, 1.0, beam_alpha)
		)


func _begin_warning() -> void:
	state = State.WARNING
	state_remaining = warning_duration
	fade_remaining = 0.0
	damaged_this_firing = false
	intercepted_this_firing = false
	if is_instance_valid(player):
		target_x = player.global_position.x
	if preparation_audio.playing:
		preparation_audio.stop()
	preparation_audio.play()
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
	fade_remaining = fade_out_duration
	queue_redraw()


func _damage_player_once() -> void:
	if damaged_this_firing or not is_instance_valid(player) or player.is_defeated():
		return
	damaged_this_firing = true
	if absf(player.global_position.x - target_x) > beam_width * 0.5:
		return
	lethal_hit_imminent.emit(target_x)
	if intercepted_this_firing:
		return
	var body_durability := float(player.part_durability.get(&"Body", 0.0))
	if body_durability > 0.0:
		player.register_hit(&"Body", Vector2.UP, body_durability)


func intercept_current_firing() -> void:
	intercepted_this_firing = true
