class_name WeaponRuntime
extends RefCounted

const RELOAD_START_STREAM := preload("res://Sounds/combat/reload_start.ogg")
const RELOAD_END_STREAM := preload("res://Sounds/combat/reload_end.ogg")
const LONG_RELOAD_SECONDS := 5.0

var spec: WeaponSpec
var visual: Sprite2D
var muzzles: Array[Marker2D] = []
var casing_eject: Marker2D
var fire_audio: AudioStreamPlayer2D
var reload_audio: AudioStreamPlayer2D
var effect_z_index := 4
var part_name: StringName
var ammo := 0
var cooldown_remaining := 0.0
var recoil_offset := 0.0
var next_muzzle := 0
var rest_position := Vector2.ZERO
var fire_rate_multiplier := 1.0
var reload_duration_multiplier := 1.0
var reload_duration_override := -1.0
var reload_remaining := 0.0
var reload_count := 0
var reload_completed_count := 0
var reload_end_pending := false
var disabled := false


func setup(
	weapon_spec: WeaponSpec,
	weapon_visual: Sprite2D,
	weapon_muzzles: Array[Marker2D],
	source_part: StringName,
	fire_rate_scale: float,
	casing_eject_marker: Marker2D = null,
	visual_effect_z_index: int = 4
) -> void:
	spec = weapon_spec
	visual = weapon_visual
	muzzles = weapon_muzzles
	if spec.fire_sound != null:
		fire_audio = AudioStreamPlayer2D.new()
		fire_audio.name = "FireAudio"
		fire_audio.stream = spec.fire_sound
		fire_audio.max_polyphony = 16
		visual.add_child(fire_audio)
	reload_audio = AudioStreamPlayer2D.new()
	reload_audio.name = "ReloadAudio"
	reload_audio.max_polyphony = 2
	visual.add_child(reload_audio)
	part_name = source_part
	fire_rate_multiplier = fire_rate_scale
	casing_eject = casing_eject_marker
	effect_z_index = visual_effect_z_index
	ammo = spec.magazine_capacity
	rest_position = visual.position


func tick(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - delta, 0.0)
	if disabled and reload_remaining > 0.0:
		reload_remaining = 0.0
		reload_end_pending = false
	if reload_remaining > 0.0:
		reload_remaining = maxf(reload_remaining - delta, 0.0)
		if reload_remaining <= 0.0:
			ammo = spec.magazine_capacity
			reload_completed_count += 1
			if reload_end_pending:
				_play_reload_sound(RELOAD_END_STREAM)
			reload_end_pending = false
	recoil_offset = move_toward(recoil_offset, 0.0, spec.visual_recoil_recovery * delta)
	# Cannon art points along local +X, so visual recoil moves toward local -X.
	visual.position = rest_position + Vector2(-recoil_offset, 0.0)


func can_fire() -> bool:
	if disabled or cooldown_remaining > 0.0 or reload_remaining > 0.0 or muzzles.is_empty():
		return false
	var magazine_cost := _magazine_cost()
	return magazine_cost <= 0 or ammo >= magazine_cost


func fire() -> Marker2D:
	if not can_fire():
		return null

	var magazine_cost := _magazine_cost()
	if magazine_cost > 0:
		ammo -= magazine_cost
		if ammo < magazine_cost:
			var duration := reload_duration()
			if duration > 0.0:
				_begin_reload(duration)
			else:
				ammo = spec.magazine_capacity
	cooldown_remaining = spec.fire_interval() / maxf(fire_rate_multiplier, 0.001)
	recoil_offset = minf(
		recoil_offset + spec.visual_recoil_distance,
		spec.visual_recoil_limit
	)

	var muzzle := muzzles[next_muzzle]
	next_muzzle = (next_muzzle + 1) % muzzles.size()
	if fire_audio != null and fire_audio.is_inside_tree():
		fire_audio.play()
	return muzzle


func is_reloading() -> bool:
	return reload_remaining > 0.0


func force_reload() -> bool:
	if disabled or is_reloading() or spec.magazine_capacity <= 0 or ammo >= spec.magazine_capacity:
		return false
	var duration := reload_duration()
	if duration > 0.0:
		_begin_reload(duration)
	else:
		ammo = spec.magazine_capacity
		reload_completed_count += 1
	return true


func accelerate_reload(speed_multiplier: float) -> bool:
	if reload_remaining <= 0.0 or speed_multiplier <= 1.0:
		return false
	reload_remaining /= speed_multiplier
	return true


func reload_duration() -> float:
	if reload_duration_override >= 0.0:
		return reload_duration_override
	return maxf(spec.reload_duration * reload_duration_multiplier, 0.0)


func _begin_reload(duration: float) -> void:
	reload_remaining = duration
	reload_count += 1
	reload_end_pending = duration >= LONG_RELOAD_SECONDS
	if spec.weapon_family != WeaponSpec.WeaponFamily.MISSILE:
		_play_reload_sound(RELOAD_START_STREAM)


func _play_reload_sound(stream: AudioStream) -> void:
	if reload_audio == null:
		return
	reload_audio.stream = stream
	if reload_audio.is_inside_tree():
		reload_audio.play()


func _magazine_cost() -> int:
	if spec.resource_type == WeaponSpec.ResourceType.AMMO:
		return maxi(ceili(spec.resource_cost), 1)
	if spec.resource_type in [WeaponSpec.ResourceType.NONE, WeaponSpec.ResourceType.EN]:
		return 1
	return 0
