class_name CombatAudio
extends RefCounted


static func play_2d(
	parent: Node,
	stream: AudioStream,
	world_position: Vector2,
	volume_db := 0.0
) -> AudioStreamPlayer2D:
	if not is_instance_valid(parent) or stream == null:
		return null
	var player := AudioStreamPlayer2D.new()
	player.name = "CombatAudioOneShot"
	player.stream = stream
	player.volume_db = volume_db
	player.max_distance = 3000.0
	parent.add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()
	return player
