class_name WreckFireEffect
extends Node2D

const BURN_DURATION := 6.0

var burn_remaining := BURN_DURATION
var spawn_accumulator := 0.0
var particles: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func setup(random_seed: int) -> void:
	rng.seed = random_seed


func _process(delta: float) -> void:
	burn_remaining = maxf(burn_remaining - delta, 0.0)
	if burn_remaining > 0.0:
		spawn_accumulator += delta * 22.0
		while spawn_accumulator >= 1.0:
			spawn_accumulator -= 1.0
			_spawn_particle()

	for index in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[index]
		particle["life"] = float(particle["life"]) - delta
		if float(particle["life"]) <= 0.0:
			particles.remove_at(index)
			continue
		particle["position"] = particle["position"] + particle["velocity"] * delta
		particle["velocity"] = particle["velocity"] * maxf(1.0 - delta * 1.5, 0.0)
		particles[index] = particle

	if burn_remaining <= 0.0 and particles.is_empty():
		queue_free()
		return
	queue_redraw()


func _spawn_particle() -> void:
	var is_smoke := rng.randf() < 0.42
	var lifetime := rng.randf_range(0.8, 1.5) if is_smoke else rng.randf_range(0.25, 0.55)
	particles.append({
		"kind": &"smoke" if is_smoke else &"flame",
		"position": Vector2(rng.randf_range(-3.5, 3.5), rng.randf_range(-1.0, 2.0)),
		"velocity": Vector2(rng.randf_range(-5.0, 5.0), rng.randf_range(-24.0, -11.0)),
		"life": lifetime,
		"max_life": lifetime,
		"size": rng.randf_range(2.0, 4.5) if is_smoke else rng.randf_range(1.5, 3.2),
		"color": (
			Color(0.12, 0.15, 0.16, rng.randf_range(0.35, 0.58))
			if is_smoke
			else Color("ff6b1a") if rng.randf() < 0.55 else Color("ffd35a")
		),
	})


func _draw() -> void:
	for particle in particles:
		var life_ratio := clampf(
			float(particle["life"]) / float(particle["max_life"]),
			0.0,
			1.0
		)
		var position_value: Vector2 = particle["position"]
		var color: Color = particle["color"]
		color.a *= life_ratio
		if particle["kind"] == &"smoke":
			var smoke_radius := float(particle["size"]) * lerpf(0.7, 1.8, 1.0 - life_ratio)
			draw_circle(position_value, smoke_radius, color)
		else:
			var flame_size := float(particle["size"]) * lerpf(0.45, 1.0, life_ratio)
			var flame := PackedVector2Array([
				position_value + Vector2(0.0, -flame_size * 1.8),
				position_value + Vector2(flame_size, flame_size),
				position_value + Vector2(-flame_size, flame_size),
			])
			draw_colored_polygon(flame, color)
