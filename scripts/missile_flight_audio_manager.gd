class_name MissileFlightAudioManager
extends Node2D

const MAX_FLIGHT_CHANNELS := 3
const FLIGHT_STREAM := preload("res://Sounds/combat/missile_flight.ogg")

var flight_players: Array[AudioStreamPlayer2D] = []
var flight_targets: Array = []


func _ready() -> void:
	var loop_stream := FLIGHT_STREAM.duplicate() as AudioStreamOggVorbis
	loop_stream.loop = true
	for index in MAX_FLIGHT_CHANNELS:
		var player := AudioStreamPlayer2D.new()
		player.name = "MissileFlightAudio%d" % (index + 1)
		player.stream = loop_stream
		player.volume_db = -6.0
		player.max_distance = 2200.0
		add_child(player)
		flight_players.append(player)
		flight_targets.append(null)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		_set_selected_missiles([])
		return
	var missiles: Array[BallisticProjectile] = []
	for child in get_children():
		var projectile := child as BallisticProjectile
		if (
			projectile != null
			and projectile.weapon_family == WeaponSpec.WeaponFamily.MISSILE
			and not projectile.is_queued_for_deletion()
		):
			missiles.append(projectile)
	var listener_position := camera.global_position
	missiles.sort_custom(func(a: BallisticProjectile, b: BallisticProjectile) -> bool:
		var a_distance := listener_position.distance_squared_to(a.global_position)
		var b_distance := listener_position.distance_squared_to(b.global_position)
		if is_equal_approx(a_distance, b_distance):
			return a.get_instance_id() < b.get_instance_id()
		return a_distance < b_distance
	)
	_set_selected_missiles(missiles.slice(0, mini(missiles.size(), MAX_FLIGHT_CHANNELS)))


func _set_selected_missiles(selected: Array) -> void:
	for index in flight_targets.size():
		var target = flight_targets[index]
		if not is_instance_valid(target) or not selected.has(target):
			flight_targets[index] = null
			flight_players[index].stop()
	for missile in selected:
		if flight_targets.has(missile):
			continue
		var empty_index := flight_targets.find(null)
		if empty_index >= 0:
			flight_targets[empty_index] = missile
	for index in flight_targets.size():
		var target = flight_targets[index]
		if not is_instance_valid(target):
			continue
		flight_players[index].global_position = target.global_position
		if not flight_players[index].playing:
			flight_players[index].play()


func active_flight_channel_count() -> int:
	var count := 0
	for target in flight_targets:
		if is_instance_valid(target):
			count += 1
	return count


func selected_missile_ids() -> Array[int]:
	var result: Array[int] = []
	for target in flight_targets:
		if is_instance_valid(target):
			result.append(target.get_instance_id())
	return result
